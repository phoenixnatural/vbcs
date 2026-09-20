CREATE OR REPLACE PACKAGE BODY btvl_oie_sa_rules_pkg
AS
/*==========================================================================
|| Package    : BTVL_OIE_SA_RULES_PKG (body)
|| CR         : CR2025-10-0449 - Chad OPCO Salary Advance
||
|| Data model assumptions
|| ----------------------
|| Everything this package needs to know about the EXISTING BTVL data model
|| is confined to the four adapter functions in the ADAPTERS section at the
|| bottom of this body. The rule logic never reads a base table directly.
|| If a table or column name differs from the assumption recorded in
|| docs/MD70-CR2025-10-0449-Chad-Salary-Advance.md section 4, change the
|| adapter and nothing else.
||
||   A-01  BTVLOIE_ADV_REQUESTS (REQUEST_ID, PERSON_ID, ORG_ID, REQUEST_DATE,
||         ADVANCE_AMOUNT, LOAN_DURATION, SALARY_ADV_CATEGORY, STATUS_CODE)
||   A-02  BTVLOIE_ADV_RECOVERY (REQUEST_ID, RECOVERY_DATE, RECOVERED_AMOUNT,
||         BALANCE_AMOUNT) - the existing repayment schedule / history.
||   A-03  BTVL_FUSION_EMP_SALARY_V (PERSON_ID, ANNUAL_BASIC_SALARY,
||         EFFECTIVE_START_DATE, EFFECTIVE_END_DATE) - the existing Fusion
||         salary feed. No new interface is built (HLD s.7).
||   A-04  Attachments are held in FND_ATTACHED_DOCUMENTS with
||         ENTITY_NAME = g_attach_entity and PK1_VALUE = REQUEST_ID.
||========================================================================*/

   ----------------------------------------------------------------------
   -- Private constants
   ----------------------------------------------------------------------
   c_module          CONSTANT VARCHAR2 (60) := 'btvl.plsql.btvl_oie_sa_rules_pkg';
   c_yes             CONSTANT VARCHAR2 (1)  := 'Y';
   c_no              CONSTANT VARCHAR2 (1)  := 'N';
   c_date_fmt        CONSTANT VARCHAR2 (20) := 'DD-MON-YYYY';
   c_amount_fmt      CONSTANT VARCHAR2 (40) := 'FM999G999G999G990D00';

   -- Request statuses that do NOT represent a live advance.
   -- TODO(CR2025-10-0449): reconcile with the status codes actually used by
   --                       BTVLOIE_ADV_REQUESTS.STATUS_CODE.
   c_sts_cancelled   CONSTANT VARCHAR2 (30) := 'CANCELLED';
   c_sts_rejected    CONSTANT VARCHAR2 (30) := 'REJECTED';
   c_sts_withdrawn   CONSTANT VARCHAR2 (30) := 'WITHDRAWN';

   ----------------------------------------------------------------------
   -- Session caches. The validation runs on every save and the lookup data
   -- is static, so each lookup row is read at most once per session.
   ----------------------------------------------------------------------
   TYPE t_num_cache IS TABLE OF NUMBER INDEX BY VARCHAR2 (30);
   TYPE t_vc_cache  IS TABLE OF VARCHAR2 (240) INDEX BY VARCHAR2 (30);

   g_recovery_cache  t_num_cache;
   g_months_cache    t_num_cache;
   g_meaning_cache   t_vc_cache;
   g_org_cache       t_vc_cache;

   ----------------------------------------------------------------------
   -- ADAPTERS - forward declarations (defined at the bottom of this body)
   ----------------------------------------------------------------------
   FUNCTION adp_annual_basic_salary (p_person_id      IN NUMBER,
                                     p_effective_date IN DATE)
      RETURN NUMBER;

   FUNCTION adp_open_advance_count (p_person_id          IN NUMBER,
                                    p_org_id             IN NUMBER,
                                    p_exclude_request_id IN NUMBER)
      RETURN NUMBER;

   FUNCTION adp_last_zero_balance_date (p_person_id IN NUMBER,
                                        p_org_id    IN NUMBER)
      RETURN DATE;

   FUNCTION adp_request_count_in_year (p_person_id          IN NUMBER,
                                       p_org_id             IN NUMBER,
                                       p_year_start         IN DATE,
                                       p_year_end           IN DATE,
                                       p_exclude_request_id IN NUMBER)
      RETURN NUMBER;

   ----------------------------------------------------------------------
   -- Private helpers
   ----------------------------------------------------------------------
   PROCEDURE log_debug (p_routine IN VARCHAR2, p_text IN VARCHAR2)
   IS
   BEGIN
      IF fnd_log.level_statement >= fnd_log.g_current_runtime_level
      THEN
         fnd_log.STRING (fnd_log.level_statement,
                         c_module || '.' || p_routine,
                         SUBSTR (p_text, 1, 4000));
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         NULL;                          -- logging must never break the flow
   END log_debug;

   /*
   || Builds a translated, tokenised message from FND_NEW_MESSAGES so the
   || wording lives in the Messages form, not in this body.
   */
   FUNCTION get_message (p_message_name IN VARCHAR2,
                         p_token1_name  IN VARCHAR2 DEFAULT NULL,
                         p_token1_value IN VARCHAR2 DEFAULT NULL,
                         p_token2_name  IN VARCHAR2 DEFAULT NULL,
                         p_token2_value IN VARCHAR2 DEFAULT NULL)
      RETURN VARCHAR2
   IS
   BEGIN
      fnd_message.set_name (g_msg_appl, p_message_name);

      IF p_token1_name IS NOT NULL
      THEN
         fnd_message.set_token (p_token1_name, p_token1_value);
      END IF;

      IF p_token2_name IS NOT NULL
      THEN
         fnd_message.set_token (p_token2_name, p_token2_value);
      END IF;

      RETURN fnd_message.GET;
   END get_message;

   PROCEDURE add_error (x_errors       IN OUT NOCOPY t_error_tbl,
                        p_rule_id      IN            VARCHAR2,
                        p_message_name IN            VARCHAR2,
                        p_token1_name  IN            VARCHAR2 DEFAULT NULL,
                        p_token1_value IN            VARCHAR2 DEFAULT NULL,
                        p_token2_name  IN            VARCHAR2 DEFAULT NULL,
                        p_token2_value IN            VARCHAR2 DEFAULT NULL)
   IS
      l_idx   PLS_INTEGER := x_errors.COUNT + 1;
   BEGIN
      x_errors (l_idx).rule_id      := p_rule_id;
      x_errors (l_idx).message_name := p_message_name;
      x_errors (l_idx).message_text :=
         get_message (p_message_name,
                      p_token1_name, p_token1_value,
                      p_token2_name, p_token2_value);

      log_debug ('add_error', p_rule_id || ' - ' || x_errors (l_idx).message_text);
   END add_error;

   ----------------------------------------------------------------------
   -- Scope
   ----------------------------------------------------------------------
   FUNCTION is_rules_enabled (p_org_id IN NUMBER)
      RETURN VARCHAR2
   IS
      l_key     VARCHAR2 (30) := TO_CHAR (p_org_id);
      l_count   PLS_INTEGER;
   BEGIN
      IF p_org_id IS NULL
      THEN
         RETURN c_no;
      END IF;

      IF g_org_cache.EXISTS (l_key)
      THEN
         RETURN g_org_cache (l_key);
      END IF;

      SELECT COUNT (*)
        INTO l_count
        FROM fnd_lookup_values
       WHERE lookup_type   = g_lkp_enabled_orgs
         AND lookup_code   = l_key
         AND LANGUAGE      = USERENV ('LANG')
         AND enabled_flag  = c_yes
         AND TRUNC (SYSDATE) BETWEEN NVL (start_date_active, TRUNC (SYSDATE))
                                 AND NVL (end_date_active, TRUNC (SYSDATE));

      g_org_cache (l_key) := CASE WHEN l_count > 0 THEN c_yes ELSE c_no END;

      RETURN g_org_cache (l_key);
   EXCEPTION
      WHEN OTHERS
      THEN
         -- Fail closed to "not enabled": an unreadable configuration must
         -- never silently switch the new rules on for another OPCO.
         log_debug ('is_rules_enabled', 'org ' || l_key || ' : ' || SQLERRM);
         RETURN c_no;
   END is_rules_enabled;

   ----------------------------------------------------------------------
   -- Category / duration derivation
   ----------------------------------------------------------------------
   FUNCTION get_category_months (p_category_code IN VARCHAR2)
      RETURN NUMBER
   IS
      l_months   NUMBER;
   BEGIN
      IF p_category_code IS NULL
      THEN
         RETURN NULL;
      END IF;

      IF g_months_cache.EXISTS (p_category_code)
      THEN
         RETURN g_months_cache (p_category_code);
      END IF;

      -- The lookup CODE is the number of months of salary (1 / 2 / 3); the
      -- SELECT also proves the code is a currently enabled category.
      SELECT TO_NUMBER (lookup_code)
        INTO l_months
        FROM fnd_lookup_values
       WHERE lookup_type   = g_lkp_category
         AND lookup_code   = p_category_code
         AND LANGUAGE      = USERENV ('LANG')
         AND enabled_flag  = c_yes
         AND TRUNC (SYSDATE) BETWEEN NVL (start_date_active, TRUNC (SYSDATE))
                                 AND NVL (end_date_active, TRUNC (SYSDATE));

      g_months_cache (p_category_code) := l_months;

      RETURN l_months;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN NULL;                    -- unknown / disabled category
      WHEN VALUE_ERROR
      THEN
         log_debug ('get_category_months',
                    'non-numeric lookup_code ' || p_category_code);
         RETURN NULL;
   END get_category_months;

   FUNCTION derive_recovery_months (p_category_code IN VARCHAR2)
      RETURN NUMBER
   IS
      l_months   NUMBER;
   BEGIN
      IF p_category_code IS NULL
      THEN
         RETURN NULL;
      END IF;

      IF g_recovery_cache.EXISTS (p_category_code)
      THEN
         RETURN g_recovery_cache (p_category_code);
      END IF;

      -- TAG carries the frozen recovery duration (HLD s.4), so Config can
      -- change 4 / 8 / 12 from the Lookups form with no code change.
      SELECT TO_NUMBER (tag)
        INTO l_months
        FROM fnd_lookup_values
       WHERE lookup_type   = g_lkp_category
         AND lookup_code   = p_category_code
         AND LANGUAGE      = USERENV ('LANG')
         AND enabled_flag  = c_yes
         AND TRUNC (SYSDATE) BETWEEN NVL (start_date_active, TRUNC (SYSDATE))
                                 AND NVL (end_date_active, TRUNC (SYSDATE));

      g_recovery_cache (p_category_code) := l_months;

      RETURN l_months;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN NULL;
      WHEN VALUE_ERROR
      THEN
         -- A blank or non-numeric TAG is a configuration error. Returning
         -- NULL makes validate_request raise VAL-01 rather than defaulting
         -- the employee into an arbitrary repayment period.
         log_debug ('derive_recovery_months',
                    'non-numeric TAG on category ' || p_category_code);
         RETURN NULL;
   END derive_recovery_months;

   FUNCTION get_category_meaning (p_category_code IN VARCHAR2)
      RETURN VARCHAR2
   IS
      l_meaning   VARCHAR2 (240);
   BEGIN
      IF p_category_code IS NULL
      THEN
         RETURN NULL;
      END IF;

      IF g_meaning_cache.EXISTS (p_category_code)
      THEN
         RETURN g_meaning_cache (p_category_code);
      END IF;

      SELECT meaning
        INTO l_meaning
        FROM fnd_lookup_values
       WHERE lookup_type   = g_lkp_category
         AND lookup_code   = p_category_code
         AND LANGUAGE      = USERENV ('LANG')
         AND enabled_flag  = c_yes;

      g_meaning_cache (p_category_code) := l_meaning;

      RETURN l_meaning;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN p_category_code;
   END get_category_meaning;

   ----------------------------------------------------------------------
   -- Salary / cap
   ----------------------------------------------------------------------
   FUNCTION get_monthly_basic_salary (p_person_id      IN NUMBER,
                                      p_effective_date IN DATE DEFAULT SYSDATE)
      RETURN NUMBER
   IS
      l_annual   NUMBER;
   BEGIN
      l_annual := adp_annual_basic_salary (p_person_id, NVL (p_effective_date, SYSDATE));

      IF l_annual IS NULL OR l_annual <= 0
      THEN
         RETURN NULL;
      END IF;

      -- HLD note: "Basic salary means monthly (annual / 12) ... existing
      -- functionality, we are not changing".
      RETURN ROUND (l_annual / 12, 2);
   END get_monthly_basic_salary;

   FUNCTION get_max_advance_amount (p_person_id      IN NUMBER,
                                    p_category_code  IN VARCHAR2,
                                    p_effective_date IN DATE DEFAULT SYSDATE)
      RETURN NUMBER
   IS
      l_monthly   NUMBER;
      l_months    NUMBER;
   BEGIN
      l_months  := get_category_months (p_category_code);
      l_monthly := get_monthly_basic_salary (p_person_id, p_effective_date);

      IF l_months IS NULL OR l_monthly IS NULL
      THEN
         RETURN NULL;
      END IF;

      RETURN ROUND (l_monthly * l_months, 2);
   END get_max_advance_amount;

   ----------------------------------------------------------------------
   -- Eligibility
   ----------------------------------------------------------------------
   FUNCTION has_open_advance (p_person_id          IN NUMBER,
                              p_org_id             IN NUMBER,
                              p_exclude_request_id IN NUMBER DEFAULT NULL)
      RETURN VARCHAR2
   IS
      l_count   NUMBER;
   BEGIN
      l_count := adp_open_advance_count (p_person_id, p_org_id, p_exclude_request_id);

      RETURN CASE WHEN NVL (l_count, 0) > 0 THEN c_yes ELSE c_no END;
   END has_open_advance;

   FUNCTION get_last_repayment_date (p_person_id IN NUMBER,
                                     p_org_id    IN NUMBER)
      RETURN DATE
   IS
   BEGIN
      RETURN adp_last_zero_balance_date (p_person_id, p_org_id);
   END get_last_repayment_date;

   FUNCTION get_earliest_submission_date (p_person_id IN NUMBER,
                                          p_org_id    IN NUMBER)
      RETURN DATE
   IS
      l_last_repayment   DATE;
   BEGIN
      l_last_repayment := get_last_repayment_date (p_person_id, p_org_id);

      IF l_last_repayment IS NULL
      THEN
         RETURN NULL;                    -- no prior advance - eligible now
      END IF;

      -- HLD: "a mandatory 2-month cooling-off period following the full
      -- repayment". ADD_MONTHS keeps month-end semantics (31-Jan + 2 =
      -- 31-Mar, 31-Dec + 2 = 28/29-Feb), which is what the policy means by
      -- "two months later".
      RETURN TRUNC (ADD_MONTHS (l_last_repayment, g_cooling_off_months));
   END get_earliest_submission_date;

   FUNCTION get_advance_count_ytd (p_person_id          IN NUMBER,
                                   p_org_id             IN NUMBER,
                                   p_effective_date     IN DATE DEFAULT SYSDATE,
                                   p_exclude_request_id IN NUMBER DEFAULT NULL)
      RETURN NUMBER
   IS
      l_date         DATE := NVL (p_effective_date, SYSDATE);
      l_year_start   DATE := TRUNC (l_date, 'YYYY');
      l_year_end     DATE := ADD_MONTHS (TRUNC (l_date, 'YYYY'), 12) - 1;
   BEGIN
      RETURN NVL (adp_request_count_in_year (p_person_id,
                                             p_org_id,
                                             l_year_start,
                                             l_year_end,
                                             p_exclude_request_id),
                  0);
   END get_advance_count_ytd;

   FUNCTION has_attachment (p_request_id IN NUMBER)
      RETURN VARCHAR2
   IS
      l_exists   VARCHAR2 (1);
   BEGIN
      IF p_request_id IS NULL
      THEN
         RETURN c_no;
      END IF;

      SELECT c_yes
        INTO l_exists
        FROM DUAL
       WHERE EXISTS
                (SELECT 1
                   FROM fnd_attached_documents
                  WHERE entity_name = g_attach_entity
                    AND pk1_value   = TO_CHAR (p_request_id));

      RETURN l_exists;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN c_no;
   END has_attachment;

   ----------------------------------------------------------------------
   -- Validation entry points
   ----------------------------------------------------------------------
   PROCEDURE validate_request (
      p_request_id          IN     NUMBER,
      p_person_id           IN     NUMBER,
      p_org_id              IN     NUMBER,
      p_category_code       IN     VARCHAR2,
      p_requested_amount    IN     NUMBER,
      p_loan_duration       IN     NUMBER DEFAULT NULL,
      p_effective_date      IN     DATE DEFAULT SYSDATE,
      p_validate_attachment IN     VARCHAR2 DEFAULT 'Y',
      x_errors                 OUT NOCOPY t_error_tbl,
      x_return_status          OUT NOCOPY VARCHAR2)
   IS
      l_empty              t_error_tbl;
      l_effective_date     DATE   := NVL (p_effective_date, SYSDATE);
      l_cat_months         NUMBER;
      l_recovery_months    NUMBER;
      l_monthly_salary     NUMBER;
      l_max_amount         NUMBER;
      l_earliest_date      DATE;
      l_ytd_count          NUMBER;
   BEGIN
      x_errors        := l_empty;
      x_return_status := g_ret_sts_success;

      ------------------------------------------------------------------
      -- Scope guard. Every other OPCO keeps its current behaviour.
      ------------------------------------------------------------------
      IF is_rules_enabled (p_org_id) = c_no
      THEN
         log_debug ('validate_request',
                    'org ' || p_org_id || ' not enabled - rules skipped');
         RETURN;
      END IF;

      log_debug ('validate_request',
                    'person=' || p_person_id
                 || ' org='   || p_org_id
                 || ' cat='   || p_category_code
                 || ' amt='   || p_requested_amount
                 || ' dur='   || p_loan_duration);

      ------------------------------------------------------------------
      -- VAL-01  Salary advance category must be selected (and valid)
      ------------------------------------------------------------------
      l_cat_months := get_category_months (p_category_code);

      IF l_cat_months IS NULL
      THEN
         add_error (x_errors, 'VAL-01', 'XXBTVL_SA_VAL01');
      ELSE
         l_recovery_months := derive_recovery_months (p_category_code);

         IF l_recovery_months IS NULL
         THEN
            -- Category exists but its TAG is unusable: treat as an invalid
            -- selection rather than defaulting a repayment period.
            add_error (x_errors, 'VAL-01', 'XXBTVL_SA_VAL01');
         END IF;
      END IF;

      ------------------------------------------------------------------
      -- VAL-02  Requested amount must be entered
      ------------------------------------------------------------------
      IF NVL (p_requested_amount, 0) <= 0
      THEN
         add_error (x_errors, 'VAL-02', 'XXBTVL_SA_VAL02');
      END IF;

      ------------------------------------------------------------------
      -- VAL-03  Requested amount must not exceed the category cap
      -- VAL-09  (implementation-added) salary must be known
      ------------------------------------------------------------------
      IF l_cat_months IS NOT NULL AND NVL (p_requested_amount, 0) > 0
      THEN
         l_monthly_salary := get_monthly_basic_salary (p_person_id, l_effective_date);

         IF l_monthly_salary IS NULL
         THEN
            add_error (x_errors, 'VAL-09', 'XXBTVL_SA_VAL09');
         ELSE
            l_max_amount := ROUND (l_monthly_salary * l_cat_months, 2);

            IF ROUND (p_requested_amount, 2) > l_max_amount
            THEN
               add_error (x_errors,
                          'VAL-03',
                          'XXBTVL_SA_VAL03',
                          'CATEGORY', get_category_meaning (p_category_code),
                          'LIMIT',    TO_CHAR (l_max_amount, c_amount_fmt));
            END IF;
         END IF;
      END IF;

      ------------------------------------------------------------------
      -- VAL-05  Defensive duration check.
      -- The page defaults the duration and renders it read-only, so this
      -- can only fire for a payload that did not come from the page.
      ------------------------------------------------------------------
      IF     l_recovery_months IS NOT NULL
         AND p_loan_duration   IS NOT NULL
         AND p_loan_duration  <> l_recovery_months
      THEN
         add_error (x_errors,
                    'VAL-05',
                    'XXBTVL_SA_VAL05',
                    'CATEGORY', get_category_meaning (p_category_code),
                    'MONTHS',   TO_CHAR (l_recovery_months));
      END IF;

      ------------------------------------------------------------------
      -- VAL-06  Signed approval document is mandatory
      ------------------------------------------------------------------
      IF     NVL (p_validate_attachment, c_yes) = c_yes
         AND has_attachment (p_request_id) = c_no
      THEN
         add_error (x_errors, 'VAL-06', 'XXBTVL_SA_VAL06');
      END IF;

      ------------------------------------------------------------------
      -- VAL-07  Previous advance must be fully repaid
      -- VAL-08  Two-month cooling-off period
      --
      -- VAL-08 is only evaluated when there is no open advance: an employee
      -- who still owes money gets the single actionable message (VAL-07)
      -- rather than two overlapping ones.
      ------------------------------------------------------------------
      IF has_open_advance (p_person_id, p_org_id, p_request_id) = c_yes
      THEN
         add_error (x_errors, 'VAL-07', 'XXBTVL_SA_VAL07');
      ELSE
         l_earliest_date := get_earliest_submission_date (p_person_id, p_org_id);

         IF     l_earliest_date IS NOT NULL
            AND TRUNC (l_effective_date) < l_earliest_date
         THEN
            add_error (x_errors,
                       'VAL-08',
                       'XXBTVL_SA_VAL08',
                       'DATE', TO_CHAR (l_earliest_date, c_date_fmt));
         END IF;
      END IF;

      ------------------------------------------------------------------
      -- VAL-10  Existing limit of 2 advances per calendar year (retained)
      ------------------------------------------------------------------
      l_ytd_count := get_advance_count_ytd (p_person_id,
                                            p_org_id,
                                            l_effective_date,
                                            p_request_id);

      IF l_ytd_count >= g_max_adv_per_year
      THEN
         add_error (x_errors,
                    'VAL-10',
                    'XXBTVL_SA_VAL10',
                    'LIMIT', TO_CHAR (g_max_adv_per_year));
      END IF;

      ------------------------------------------------------------------
      IF x_errors.COUNT > 0
      THEN
         x_return_status := g_ret_sts_error;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         x_return_status := g_ret_sts_unexp_error;
         x_errors := l_empty;
         x_errors (1).rule_id      := 'UNEXP';
         x_errors (1).message_name := NULL;
         x_errors (1).message_text :=
            SUBSTR ('btvl_oie_sa_rules_pkg.validate_request: ' || SQLERRM, 1, 2000);

         log_debug ('validate_request',
                    SQLERRM || ' - ' || DBMS_UTILITY.format_error_backtrace);
   END validate_request;

   FUNCTION get_first_error (
      p_request_id          IN NUMBER,
      p_person_id           IN NUMBER,
      p_org_id              IN NUMBER,
      p_category_code       IN VARCHAR2,
      p_requested_amount    IN NUMBER,
      p_loan_duration       IN NUMBER DEFAULT NULL,
      p_effective_date      IN DATE DEFAULT SYSDATE,
      p_validate_attachment IN VARCHAR2 DEFAULT 'Y')
      RETURN VARCHAR2
   IS
      l_errors   t_error_tbl;
      l_status   VARCHAR2 (1);
   BEGIN
      validate_request (p_request_id          => p_request_id,
                        p_person_id           => p_person_id,
                        p_org_id              => p_org_id,
                        p_category_code       => p_category_code,
                        p_requested_amount    => p_requested_amount,
                        p_loan_duration       => p_loan_duration,
                        p_effective_date      => p_effective_date,
                        p_validate_attachment => p_validate_attachment,
                        x_errors              => l_errors,
                        x_return_status       => l_status);

      IF l_status = g_ret_sts_success OR l_errors.COUNT = 0
      THEN
         RETURN NULL;
      END IF;

      -- validate_request stacks the errors in policy order, so the first
      -- entry is the one the employee should act on first.
      RETURN l_errors (1).message_text;
   END get_first_error;

/*==========================================================================
||                              A D A P T E R S
||
|| The only routines that touch the existing BTVL data model. Reconcile the
|| SQL below with the live objects before the first compile; nothing above
|| this line needs to change if a name differs.
||========================================================================*/

   FUNCTION adp_annual_basic_salary (p_person_id      IN NUMBER,
                                     p_effective_date IN DATE)
      RETURN NUMBER
   IS
      l_annual   NUMBER;
   BEGIN
      -- TODO(CR2025-10-0449): A-03. Replace with the routine btvl_oie_adv_pkg
      --   already uses to read the Fusion salary, if one exists - HLD s.7
      --   requires the existing integration to be reused, not duplicated.
      SELECT annual_basic_salary
        INTO l_annual
        FROM btvl_fusion_emp_salary_v
       WHERE person_id = p_person_id
         AND TRUNC (p_effective_date)
                BETWEEN TRUNC (effective_start_date)
                    AND NVL (TRUNC (effective_end_date), TRUNC (p_effective_date));

      RETURN l_annual;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         log_debug ('adp_annual_basic_salary',
                    'no salary row for person ' || p_person_id);
         RETURN NULL;
      WHEN TOO_MANY_ROWS
      THEN
         -- Overlapping salary records are a data problem. Blocking with
         -- VAL-09 is safer than picking one row arbitrarily.
         log_debug ('adp_annual_basic_salary',
                    'multiple salary rows for person ' || p_person_id);
         RETURN NULL;
   END adp_annual_basic_salary;

   FUNCTION adp_open_advance_count (p_person_id          IN NUMBER,
                                    p_org_id             IN NUMBER,
                                    p_exclude_request_id IN NUMBER)
      RETURN NUMBER
   IS
      l_count   NUMBER;
   BEGIN
      -- TODO(CR2025-10-0449): A-01 / A-02. An advance is "open" until its
      --   balance has reached 0.00. The lowest balance ever reached is used
      --   rather than the balance on the latest row, so an advance settled
      --   early is correctly treated as closed; a request with no recovery
      --   rows yet falls back to its full amount and so counts as open.
      SELECT COUNT (*)
        INTO l_count
        FROM btvloie_adv_requests r
       WHERE r.person_id    = p_person_id
         AND r.org_id       = p_org_id
         AND r.status_code NOT IN (c_sts_cancelled, c_sts_rejected, c_sts_withdrawn)
         AND (p_exclude_request_id IS NULL OR r.request_id <> p_exclude_request_id)
         AND NVL (
                (SELECT MIN (v.balance_amount)
                   FROM btvloie_adv_recovery v
                  WHERE v.request_id = r.request_id),
                r.advance_amount) > 0;

      RETURN l_count;
   END adp_open_advance_count;

   FUNCTION adp_last_zero_balance_date (p_person_id IN NUMBER,
                                        p_org_id    IN NUMBER)
      RETURN DATE
   IS
      l_date   DATE;
   BEGIN
      -- TODO(CR2025-10-0449): A-02. Last_Repayment_Date is the date the
      --   balance of the previous advance reached 0.00 (HLD "System Rules &
      --   Logic"), i.e. the recovery row that cleared the advance - NOT the
      --   scheduled end of the repayment period, which can differ when an
      --   employee settles early.
      SELECT MAX (v.recovery_date)
        INTO l_date
        FROM btvloie_adv_recovery v
             JOIN btvloie_adv_requests r ON r.request_id = v.request_id
       WHERE r.person_id    = p_person_id
         AND r.org_id       = p_org_id
         AND r.status_code NOT IN (c_sts_cancelled, c_sts_rejected, c_sts_withdrawn)
         AND v.balance_amount = 0;

      RETURN l_date;
   END adp_last_zero_balance_date;

   FUNCTION adp_request_count_in_year (p_person_id          IN NUMBER,
                                       p_org_id             IN NUMBER,
                                       p_year_start         IN DATE,
                                       p_year_end           IN DATE,
                                       p_exclude_request_id IN NUMBER)
      RETURN NUMBER
   IS
      l_count   NUMBER;
   BEGIN
      -- TODO(CR2025-10-0449): A-01. If the existing package already counts
      --   advances per year, call that routine here instead so the two
      --   cannot drift apart. See GAP-06 in the gap analysis.
      SELECT COUNT (*)
        INTO l_count
        FROM btvloie_adv_requests r
       WHERE r.person_id    = p_person_id
         AND r.org_id       = p_org_id
         AND r.status_code NOT IN (c_sts_cancelled, c_sts_rejected, c_sts_withdrawn)
         AND (p_exclude_request_id IS NULL OR r.request_id <> p_exclude_request_id)
         AND TRUNC (r.request_date) BETWEEN p_year_start AND p_year_end;

      RETURN l_count;
   END adp_request_count_in_year;

END btvl_oie_sa_rules_pkg;
/
SHOW ERRORS PACKAGE BODY btvl_oie_sa_rules_pkg
