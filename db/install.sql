/*==========================================================================
|| CR2025-10-0449 - Change the Salary Advance Configuration for Chad OPCO
|| Master install script.
||
|| Usage  :  sqlplus apps/<pwd>@<sid> @install.sql
|| Order  :  scripts are numbered and must run in sequence - the package
||           body depends on the new column and on the seeded lookups being
||           present (it compiles without them, but the first call fails).
||
|| Pre-requisites
||   1. Custom application (default 'XXBTVL') registered in FND_APPLICATION.
||   2. db/patch/07_btvl_oie_adv_pkg_hooks.sql applied to a copy of the live
||      btvl_oie_adv_pkg body and that body compiled - it is NOT run here.
||   3. Config steps in docs/OAF-personalization-BTVLAdvanceCreUpdPG.md
||      (page personalization, template 11408 attachment = Yes) applied.
||========================================================================*/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK ON
SET TIMING ON
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

PROMPT ====================================================================
PROMPT  CR2025-10-0449 :: 01 - DDL  BTVLOIE_ADV_REQUESTS.SALARY_ADV_CATEGORY
PROMPT ====================================================================
@@ddl/01_btvloie_adv_requests_add_category.sql

PROMPT ====================================================================
PROMPT  CR2025-10-0449 :: 02 - Lookup XXBTVL_SA_CATEGORY
PROMPT ====================================================================
@@seed/02_lookup_xxbtvl_sa_category.sql

PROMPT ====================================================================
PROMPT  CR2025-10-0449 :: 03 - Lookup XXBTVL_SA_ENABLED_ORGS
PROMPT ====================================================================
@@seed/03_lookup_xxbtvl_sa_enabled_orgs.sql

PROMPT ====================================================================
PROMPT  CR2025-10-0449 :: 04 - Messages XXBTVL_SA_VAL01 .. VAL10
PROMPT ====================================================================
@@seed/04_fnd_messages_validation.sql

PROMPT ====================================================================
PROMPT  CR2025-10-0449 :: 05 - Package spec BTVL_OIE_SA_RULES_PKG
PROMPT ====================================================================
@@plsql/05_btvl_oie_sa_rules_pkg.pks

PROMPT ====================================================================
PROMPT  CR2025-10-0449 :: 06 - Package body BTVL_OIE_SA_RULES_PKG
PROMPT ====================================================================
@@plsql/06_btvl_oie_sa_rules_pkg.pkb

PROMPT ====================================================================
PROMPT  CR2025-10-0449 :: post-install check
PROMPT ====================================================================
SET SERVEROUTPUT ON
DECLARE
   l_invalid   PLS_INTEGER;
   l_cats      PLS_INTEGER;
   l_orgs      PLS_INTEGER;
   l_msgs      PLS_INTEGER;
BEGIN
   SELECT COUNT (*)
     INTO l_invalid
     FROM all_objects
    WHERE object_name = 'BTVL_OIE_SA_RULES_PKG'
      AND status     <> 'VALID';

   SELECT COUNT (*) INTO l_cats FROM fnd_lookup_values
    WHERE lookup_type = 'XXBTVL_SA_CATEGORY' AND LANGUAGE = USERENV ('LANG');

   SELECT COUNT (*) INTO l_orgs FROM fnd_lookup_values
    WHERE lookup_type = 'XXBTVL_SA_ENABLED_ORGS' AND LANGUAGE = USERENV ('LANG');

   SELECT COUNT (*) INTO l_msgs FROM fnd_new_messages
    WHERE message_name LIKE 'XXBTVL_SA_VAL%' AND language_code = USERENV ('LANG');

   DBMS_OUTPUT.put_line ('Invalid package objects : ' || l_invalid || '  (expected 0)');
   DBMS_OUTPUT.put_line ('Category lookup values  : ' || l_cats    || '  (expected 3)');
   DBMS_OUTPUT.put_line ('Enabled org values      : ' || l_orgs    || '  (expected 2)');
   DBMS_OUTPUT.put_line ('Validation messages     : ' || l_msgs    || '  (expected 9)');

   IF l_invalid > 0 OR l_cats <> 3 OR l_orgs <> 2 OR l_msgs <> 9
   THEN
      raise_application_error (-20002, 'CR2025-10-0449 post-install check FAILED.');
   END IF;

   DBMS_OUTPUT.put_line ('CR2025-10-0449 install completed successfully.');
END;
/

PROMPT Remember: apply db/patch/07_btvl_oie_adv_pkg_hooks.sql to the live
PROMPT btvl_oie_adv_pkg body, and the page / template config, separately.

EXIT
