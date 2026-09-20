/*==========================================================================
|| CR2025-10-0449 - Chad OPCO Salary Advance :: ROLLBACK
||
|| Restores the pre-CR behaviour. Run top to bottom as APPS.
||
|| The fastest and safest rollback is step 1 alone: end-dating the two
|| operating units switches every new rule off, because every routine in
|| btvl_oie_sa_rules_pkg and every insertion into btvl_oie_adv_pkg is inside
|| the is_rules_enabled guard. Steps 2-4 are only needed for a full removal
|| of the CEMLI.
||
|| The SALARY_ADV_CATEGORY column is deliberately NOT dropped: it holds the
|| category picked on requests already raised, which is audit data. Drop it
|| only on an explicit instruction from the business.
||========================================================================*/

SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

PROMPT -- Step 1 : disable the rules (end-date the enabled operating units)
UPDATE fnd_lookup_values
   SET end_date_active  = TRUNC (SYSDATE),
       enabled_flag     = 'N',
       last_update_date = SYSDATE
 WHERE lookup_type = 'XXBTVL_SA_ENABLED_ORGS';
COMMIT;

PROMPT -- Step 2 : restore the previous btvl_oie_adv_pkg body
PROMPT --          (re-run the pre-CR source kept by the release process;
PROMPT --           this script cannot recreate code it never held)

PROMPT -- Step 3 : drop the rules package
DROP PACKAGE BODY btvl_oie_sa_rules_pkg;
DROP PACKAGE btvl_oie_sa_rules_pkg;

PROMPT -- Step 4 : remove the seeded configuration
DELETE FROM fnd_lookup_values
 WHERE lookup_type IN ('XXBTVL_SA_CATEGORY', 'XXBTVL_SA_ENABLED_ORGS');

DELETE FROM fnd_lookup_types_tl
 WHERE lookup_type IN ('XXBTVL_SA_CATEGORY', 'XXBTVL_SA_ENABLED_ORGS');

DELETE FROM fnd_lookup_types
 WHERE lookup_type IN ('XXBTVL_SA_CATEGORY', 'XXBTVL_SA_ENABLED_ORGS');

DELETE FROM fnd_new_messages
 WHERE message_name LIKE 'XXBTVL_SA_VAL%';

COMMIT;

PROMPT -- Step 5 : revert the page personalization and set template 11408
PROMPT --          attachment back to No (manual - see docs/)

PROMPT Rollback complete.
