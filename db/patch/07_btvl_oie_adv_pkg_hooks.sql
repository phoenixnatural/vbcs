/*==========================================================================
|| CR         : CR2025-10-0449 - Chad OPCO Salary Advance
|| Object     : BTVL_OIE_ADV_PKG (existing package body) - salary block
|| Script     : 07 of 07
||
|| *** THIS SCRIPT IS NOT RUNNABLE AS-IS. ***
||
|| The live source of btvl_oie_adv_pkg was not available when this CEMLI was
|| written, so the change to it is expressed here as the exact code to graft
|| into the existing salary block, with the surrounding context described.
|| Apply it to a copy of the current package body taken from the instance
|| (SELECT text FROM dba_source WHERE name = 'BTVL_OIE_ADV_PKG'), then
|| version the resulting full body in db/plsql/ and retire this file.
||
|| Design intent: btvl_oie_adv_pkg gains NO new business logic. It gains one
|| org-guarded call into btvl_oie_sa_rules_pkg plus the assignment of the
|| derived duration. Everything that CR2025-10-0449 changes stays in the new
|| package, so the shared multi-OPCO program remains easy to review and the
|| existing repayment schedule generation is untouched.
||========================================================================*/


/*--------------------------------------------------------------------------
|| STEP 1 - Spec: nothing to change.
||
|| btvl_oie_adv_pkg.btvl_oie_adv_proc keeps its current signature. The page
|| already calls it (HLD s.3 "No controller re-wiring"), so no new public
|| routine is exposed.
--------------------------------------------------------------------------*/


/*--------------------------------------------------------------------------
|| STEP 2 - Body, salary block: derive and freeze the recovery duration.
||
|| Insert immediately AFTER the point where the request record has been
|| populated from the page (p_category_code arrives in the new page item)
|| and BEFORE the existing repayment-schedule call. The derived value is
|| written into the EXISTING loan_duration variable/column, so the schedule
|| generation downstream sees exactly what it sees today.
--------------------------------------------------------------------------*/

--  <<< begin CR2025-10-0449 >>>
      IF btvl_oie_sa_rules_pkg.is_rules_enabled (l_org_id) = 'Y'
      THEN
         -- The employee cannot type a duration; it is always derived from
         -- the selected category (4 / 8 / 12 - lookup XXBTVL_SA_CATEGORY).
         l_loan_duration :=
            btvl_oie_sa_rules_pkg.derive_recovery_months (l_salary_adv_category);
      END IF;
--  <<< end CR2025-10-0449 >>>


/*--------------------------------------------------------------------------
|| STEP 3 - Body, salary block: hard-stop validation.
||
|| Insert at the existing validation point of the salary block - the same
|| place the current "advances per year" check raises its error - so the
|| behaviour on failure (message shown, transaction abandoned) is identical
|| to today.
||
|| p_validate_attachment: pass 'N' on the first save of a brand-new request
|| if the request row does not exist yet at this point in the flow, and 'Y'
|| on submit. Documents cannot be attached to a row that has no primary key,
|| so validating VAL-06 too early would make the form unusable. See GAP-05.
--------------------------------------------------------------------------*/

--  <<< begin CR2025-10-0449 >>>
      IF btvl_oie_sa_rules_pkg.is_rules_enabled (l_org_id) = 'Y'
      THEN
         DECLARE
            l_sa_errors   btvl_oie_sa_rules_pkg.t_error_tbl;
            l_sa_status   VARCHAR2 (1);
            l_sa_message  VARCHAR2 (4000);
         BEGIN
            btvl_oie_sa_rules_pkg.validate_request (
               p_request_id          => l_request_id,
               p_person_id           => l_person_id,
               p_org_id              => l_org_id,
               p_category_code       => l_salary_adv_category,
               p_requested_amount    => l_advance_amount,
               p_loan_duration       => l_loan_duration,
               p_effective_date      => SYSDATE,
               p_validate_attachment => l_validate_attachment,   -- 'Y' on submit
               x_errors              => l_sa_errors,
               x_return_status       => l_sa_status);

            IF l_sa_status <> btvl_oie_sa_rules_pkg.g_ret_sts_success
            THEN
               -- Every failed rule is reported at once, so the employee
               -- does not discover them one save at a time.
               FOR i IN 1 .. l_sa_errors.COUNT
               LOOP
                  l_sa_message :=
                        l_sa_message
                     || CASE WHEN i > 1 THEN CHR (10) END
                     || l_sa_errors (i).message_text;
               END LOOP;

               -- TODO(CR2025-10-0449): replace with whatever the existing
               --   salary block already uses to surface an error to the page
               --   (x_error_message OUT, fnd_message.set_name + raise, or
               --   app_exception). Do NOT introduce a second error channel.
               x_error_message := SUBSTR (l_sa_message, 1, 4000);
               x_return_status := 'E';
               RETURN;
            END IF;
         END;
      END IF;
--  <<< end CR2025-10-0449 >>>


/*--------------------------------------------------------------------------
|| STEP 4 - Body: persist the picked category.
||
|| Add SALARY_ADV_CATEGORY to the existing INSERT and UPDATE of
|| BTVLOIE_ADV_REQUESTS. No other column changes.
--------------------------------------------------------------------------*/

--  INSERT INTO btvloie_adv_requests
--       ( ... existing columns ...
--       , salary_adv_category                         -- << CR2025-10-0449
--       )
--  VALUES
--       ( ... existing values ...
--       , l_salary_adv_category                       -- << CR2025-10-0449
--       );

--  UPDATE btvloie_adv_requests
--     SET ... existing assignments ...
--       , salary_adv_category = l_salary_adv_category -- << CR2025-10-0449
--   WHERE request_id = l_request_id;


/*--------------------------------------------------------------------------
|| STEP 5 - What must NOT change.
||
||   * The repayment schedule generation. It keeps reading loan_duration and
||     spreading the advance equally across it (HLD: "Existing functionality
||     should not change").
||   * The approval workflow.
||   * The Fusion salary derivation. The new package reuses it through
||     adp_annual_basic_salary rather than re-implementing it.
||   * Any code path for an operating unit that is not listed in
||     XXBTVL_SA_ENABLED_ORGS - every insertion above is inside the
||     is_rules_enabled guard.
--------------------------------------------------------------------------*/
