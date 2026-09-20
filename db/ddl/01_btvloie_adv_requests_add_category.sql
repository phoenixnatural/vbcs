/*==========================================================================
|| CR         : CR2025-10-0449 - Change the Salary Advance Configuration
||              for Chad OPCO
|| Object     : BTVLOIE_ADV_REQUESTS (existing custom table)
|| Purpose    : Store the fixed Salary Advance Category picked by the
||              employee (1 / 2 / 3 months of salary).
|| Script     : 01 of 07  - run as the custom schema owner (APPS-granted).
||
|| NOTE       : The derived recovery duration (4 / 8 / 12) is NOT stored in a
||              new column. It is written into the EXISTING LOAN_DURATION
||              column so that the current repayment-schedule generation
||              continues to work unchanged (HLD s.5 / "schedule generation
||              must not change").
||
|| TODO(CR2025-10-0449): confirm the schema owner and the exact table name
||                       casing with the DBA before running in a shared
||                       instance. Replace &&custom_schema accordingly.
||========================================================================*/

SET DEFINE ON
DEFINE custom_schema = BTVL

WHENEVER SQLERROR EXIT FAILURE ROLLBACK

DECLARE
   l_count   PLS_INTEGER;
BEGIN
   ----------------------------------------------------------------------
   -- Add SALARY_ADV_CATEGORY (re-runnable)
   ----------------------------------------------------------------------
   SELECT COUNT (*)
     INTO l_count
     FROM all_tab_columns
    WHERE owner       = UPPER ('&&custom_schema')
      AND table_name  = 'BTVLOIE_ADV_REQUESTS'
      AND column_name = 'SALARY_ADV_CATEGORY';

   IF l_count = 0
   THEN
      EXECUTE IMMEDIATE
            'ALTER TABLE &&custom_schema..BTVLOIE_ADV_REQUESTS '
         || 'ADD (SALARY_ADV_CATEGORY VARCHAR2 (30))';

      DBMS_OUTPUT.put_line ('Column SALARY_ADV_CATEGORY added.');
   ELSE
      DBMS_OUTPUT.put_line ('Column SALARY_ADV_CATEGORY already present - skipped.');
   END IF;
END;
/

COMMENT ON COLUMN &&custom_schema..BTVLOIE_ADV_REQUESTS.SALARY_ADV_CATEGORY IS
   'CR2025-10-0449. Fixed salary advance category selected by the employee. Values are the lookup codes of FND lookup type XXBTVL_SA_CATEGORY (1 = 1 Month Salary, 2 = 2 Months Salary, 3 = 3 Months Salary). NULL for requests raised before this CR and for non-Chad operating units.';

----------------------------------------------------------------------
-- Supporting index for the cooling-off / open-advance lookups.
-- The cooling-off check reads the employee's previous advances on every
-- save, so PERSON_ID + ORG_ID must be indexed.
--
-- TODO(CR2025-10-0449): check USER_IND_COLUMNS first - an equivalent index
--                       may already exist under a different name, in which
--                       case drop this step rather than duplicating it.
----------------------------------------------------------------------
DECLARE
   l_count   PLS_INTEGER;
BEGIN
   SELECT COUNT (*)
     INTO l_count
     FROM all_indexes
    WHERE owner      = UPPER ('&&custom_schema')
      AND index_name = 'BTVLOIE_ADV_REQUESTS_N90';

   IF l_count = 0
   THEN
      EXECUTE IMMEDIATE
            'CREATE INDEX &&custom_schema..BTVLOIE_ADV_REQUESTS_N90 '
         || 'ON &&custom_schema..BTVLOIE_ADV_REQUESTS (PERSON_ID, ORG_ID) '
         || 'TABLESPACE APPS_TS_TX_IDX';

      DBMS_OUTPUT.put_line ('Index BTVLOIE_ADV_REQUESTS_N90 created.');
   ELSE
      DBMS_OUTPUT.put_line ('Index BTVLOIE_ADV_REQUESTS_N90 already present - skipped.');
   END IF;
END;
/

UNDEFINE custom_schema
