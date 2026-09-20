CREATE OR REPLACE PACKAGE btvl_oie_sa_rules_pkg
AS
/*==========================================================================
|| Package    : BTVL_OIE_SA_RULES_PKG (specification)
|| CR         : CR2025-10-0449 - Change the Salary Advance Configuration
||              for Chad OPCO
|| Author     : Oracle Apps Technical
|| Created    : 2026-09-20
||
|| Purpose
|| -------
|| Holds every NEW rule introduced by CR2025-10-0449 for the Chad operating
|| units (7107 GSM / 7108 AM):
||
||   * fixed salary advance categories        (1 / 2 / 3 months of salary)
||   * frozen recovery duration               (4 / 8 / 12 months)
||   * requested amount cap vs monthly basic salary
||   * mandatory signed-approval attachment
||   * two-month cooling-off after full repayment
||   * retained existing limit of 2 advances per calendar year
||
|| The package is deliberately SEPARATE from btvl_oie_adv_pkg. The existing
|| advance package is shared by every OPCO; keeping the new logic here means
|| the change to btvl_oie_adv_pkg is a small, reviewable, org-guarded call
|| (see db/patch/07_btvl_oie_adv_pkg_hooks.sql) and the existing repayment
|| schedule generation is untouched (HLD "existing functionality should not
|| change").
||
|| Callers
|| -------
||   * btvl_oie_adv_pkg.btvl_oie_adv_proc - salary block (server-side hard
||     stop; the authoritative enforcement point).
||   * BTVLAdvanceCreUpdPG controller / AM - derive_recovery_months for the
||     on-change default of Loan Duration, and get_first_error on Save.
||
|| Every routine is a no-op / pass-through for operating units that are not
|| enabled in lookup XXBTVL_SA_ENABLED_ORGS, so no other OPCO changes
|| behaviour (HLD s.9).
||========================================================================*/

   ---------------------------------------------------------------------
   -- Configuration handles (lookups / message application)
   ---------------------------------------------------------------------
   g_lkp_category        CONSTANT VARCHAR2 (30) := 'XXBTVL_SA_CATEGORY';
   g_lkp_enabled_orgs    CONSTANT VARCHAR2 (30) := 'XXBTVL_SA_ENABLED_ORGS';
   -- TODO(CR2025-10-0449): must match the application short name used by
   --                       db/seed/02..04. Confirm with the DBA.
   g_msg_appl            CONSTANT VARCHAR2 (30) := 'XXBTVL';

   ---------------------------------------------------------------------
   -- Policy constants
   ---------------------------------------------------------------------
   g_cooling_off_months  CONSTANT PLS_INTEGER   := 2;
   g_max_adv_per_year    CONSTANT PLS_INTEGER   := 2;

   -- Attachment entity. FND_ATTACHED_DOCUMENTS.ENTITY_NAME used by the
   -- advance request page.
   -- TODO(CR2025-10-0449): confirm against the live page definition.
   g_attach_entity       CONSTANT VARCHAR2 (40) := 'BTVLOIE_ADV_REQUESTS';

   ---------------------------------------------------------------------
   -- Return statuses (mirrors FND_API so callers can reuse their handling)
   ---------------------------------------------------------------------
   g_ret_sts_success     CONSTANT VARCHAR2 (1)  := 'S';
   g_ret_sts_error       CONSTANT VARCHAR2 (1)  := 'E';
   g_ret_sts_unexp_error CONSTANT VARCHAR2 (1)  := 'U';

   ---------------------------------------------------------------------
   -- Error stack
   ---------------------------------------------------------------------
   TYPE t_error_rec IS RECORD (
      rule_id        VARCHAR2 (10),      -- VAL-01 .. VAL-10
      message_name   VARCHAR2 (30),      -- FND message name
      message_text   VARCHAR2 (2000)     -- tokenised, translated text
   );

   TYPE t_error_tbl IS TABLE OF t_error_rec
      INDEX BY PLS_INTEGER;

   ---------------------------------------------------------------------
   -- Scope
   ---------------------------------------------------------------------
   -- 'Y' when the CR2025-10-0449 rules apply to p_org_id, else 'N'.
   FUNCTION is_rules_enabled (p_org_id IN NUMBER)
      RETURN VARCHAR2;

   ---------------------------------------------------------------------
   -- Category / duration derivation
   ---------------------------------------------------------------------
   -- Number of months of salary the category allows (1, 2 or 3).
   -- NULL when p_category_code is not an enabled lookup code.
   FUNCTION get_category_months (p_category_code IN VARCHAR2)
      RETURN NUMBER;

   -- Frozen recovery duration in months, read from the lookup TAG
   -- (1 -> 4, 2 -> 8, 3 -> 12). NULL when the category is invalid.
   -- This is the single derivation point used by both the page default and
   -- the server-side validation, so the two can never disagree.
   FUNCTION derive_recovery_months (p_category_code IN VARCHAR2)
      RETURN NUMBER;

   -- Translated category meaning, for message tokens.
   FUNCTION get_category_meaning (p_category_code IN VARCHAR2)
      RETURN VARCHAR2;

   ---------------------------------------------------------------------
   -- Salary / cap
   ---------------------------------------------------------------------
   -- Monthly basic salary = annual basic / 12, from the existing Fusion
   -- salary feed. NULL when the employee has no salary on file.
   FUNCTION get_monthly_basic_salary (p_person_id      IN NUMBER,
                                      p_effective_date IN DATE DEFAULT SYSDATE)
      RETURN NUMBER;

   -- Maximum requestable amount = monthly basic * category months.
   FUNCTION get_max_advance_amount (p_person_id      IN NUMBER,
                                    p_category_code  IN VARCHAR2,
                                    p_effective_date IN DATE DEFAULT SYSDATE)
      RETURN NUMBER;

   ---------------------------------------------------------------------
   -- Eligibility
   ---------------------------------------------------------------------
   -- 'Y' when the employee has an advance whose outstanding balance is
   -- still greater than zero.
   FUNCTION has_open_advance (p_person_id          IN NUMBER,
                              p_org_id             IN NUMBER,
                              p_exclude_request_id IN NUMBER DEFAULT NULL)
      RETURN VARCHAR2;

   -- Date on which the balance of the employee's most recent advance
   -- reached 0.00 (HLD "Last_Repayment_Date"). NULL when the employee has
   -- never held an advance.
   FUNCTION get_last_repayment_date (p_person_id IN NUMBER,
                                     p_org_id    IN NUMBER)
      RETURN DATE;

   -- First date on which a new request may be submitted
   -- (Last_Repayment_Date + 2 months). NULL when there is no prior advance,
   -- i.e. the employee is immediately eligible.
   FUNCTION get_earliest_submission_date (p_person_id IN NUMBER,
                                          p_org_id    IN NUMBER)
      RETURN DATE;

   -- Requests already raised by the employee in the calendar year of
   -- p_effective_date (cancelled / rejected requests excluded).
   FUNCTION get_advance_count_ytd (p_person_id          IN NUMBER,
                                   p_org_id             IN NUMBER,
                                   p_effective_date     IN DATE DEFAULT SYSDATE,
                                   p_exclude_request_id IN NUMBER DEFAULT NULL)
      RETURN NUMBER;

   -- 'Y' when at least one document is attached to the request.
   FUNCTION has_attachment (p_request_id IN NUMBER)
      RETURN VARCHAR2;

   ---------------------------------------------------------------------
   -- Validation entry points
   ---------------------------------------------------------------------
   /*
   || Runs every CR2025-10-0449 rule and returns ALL failures, so the user
   || can see and fix them in one pass rather than one save at a time.
   ||
   || p_validate_attachment lets the caller skip VAL-06 at the point in the
   || flow where the request row does not exist yet and no document can have
   || been attached to it (see the hook script, step 3).
   ||
   || x_return_status = 'S' valid, 'E' one or more rules failed,
   ||                   'U' unexpected error (x_errors carries the detail).
   */
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
      x_return_status          OUT NOCOPY VARCHAR2);

   /*
   || Convenience wrapper for the OAF controller and for quick server-side
   || guards: returns the highest-priority error message, or NULL when the
   || request passes every rule.
   */
   FUNCTION get_first_error (
      p_request_id          IN NUMBER,
      p_person_id           IN NUMBER,
      p_org_id              IN NUMBER,
      p_category_code       IN VARCHAR2,
      p_requested_amount    IN NUMBER,
      p_loan_duration       IN NUMBER DEFAULT NULL,
      p_effective_date      IN DATE DEFAULT SYSDATE,
      p_validate_attachment IN VARCHAR2 DEFAULT 'Y')
      RETURN VARCHAR2;

END btvl_oie_sa_rules_pkg;
/
SHOW ERRORS PACKAGE btvl_oie_sa_rules_pkg
