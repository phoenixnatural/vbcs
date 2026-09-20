/*==========================================================================
|| CR         : CR2025-10-0449 - Chad OPCO Salary Advance
|| Object     : FND lookup type XXBTVL_SA_CATEGORY (new)
|| Purpose    : Single source of truth for the fixed advance categories and
||              their frozen recovery durations.
||
||                 Code | Meaning          | Tag (= recovery months)
||                 -----+------------------+-----------------------
||                   1  | 1 Month Salary   | 4
||                   2  | 2 Months Salary  | 8
||                   3  | 3 Months Salary  | 12
||
||              The TAG column carries the recovery duration so Payroll /
||              Config can change the mapping from the standard Application
||              Utilities -> Lookups screen with no code change (HLD s.4).
|| Script     : 02 of 07 - run as APPS.
||
|| Lookup is seeded as ACCESS_LEVEL 'U' (user) so that it remains editable
|| from the Lookups form and is not overwritten by patching.
||========================================================================*/

SET DEFINE OFF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

DECLARE
   -- TODO(CR2025-10-0449): confirm the registered custom application short
   --                       name with the DBA. 'XXBTVL' is assumed; the
   --                       script fails loudly rather than silently seeding
   --                       the lookup under the wrong application.
   c_appl_short_name   CONSTANT VARCHAR2 (50) := 'XXBTVL';
   c_lookup_type       CONSTANT VARCHAR2 (30) := 'XXBTVL_SA_CATEGORY';

   l_application_id             NUMBER;
   l_user_id                    NUMBER := NVL (fnd_global.user_id, 1);
   l_login_id                   NUMBER := NVL (fnd_global.login_id, -1);

   TYPE t_value_rec IS RECORD (
      lookup_code    VARCHAR2 (30),
      meaning        VARCHAR2 (80),
      description    VARCHAR2 (240),
      tag            VARCHAR2 (150)
   );

   TYPE t_value_tbl IS TABLE OF t_value_rec INDEX BY PLS_INTEGER;

   l_values                     t_value_tbl;

   -- Scalars used inside the MERGE: PL/SQL record fields of a local
   -- collection element cannot be referenced directly from a SQL statement.
   l_code                       VARCHAR2 (30);
   l_meaning                    VARCHAR2 (80);
   l_description                VARCHAR2 (240);
   l_tag                        VARCHAR2 (150);
BEGIN
   SELECT application_id
     INTO l_application_id
     FROM fnd_application
    WHERE application_short_name = c_appl_short_name;

   ----------------------------------------------------------------------
   -- Lookup type header
   ----------------------------------------------------------------------
   MERGE INTO fnd_lookup_types t
      USING (SELECT c_lookup_type AS lookup_type, l_application_id AS application_id
               FROM DUAL) s
      ON (t.lookup_type = s.lookup_type AND t.view_application_id = s.application_id)
   WHEN MATCHED THEN
      UPDATE SET t.last_update_date  = SYSDATE,
                 t.last_updated_by   = l_user_id,
                 t.last_update_login = l_login_id
   WHEN NOT MATCHED THEN
      INSERT (lookup_type, security_group_id, view_application_id, application_id,
              customization_level, created_by, creation_date,
              last_updated_by, last_update_date, last_update_login)
      VALUES (c_lookup_type, 0, l_application_id, l_application_id,
              'U', l_user_id, SYSDATE,
              l_user_id, SYSDATE, l_login_id);

   MERGE INTO fnd_lookup_types_tl t
      USING (SELECT c_lookup_type AS lookup_type, l_application_id AS application_id,
                    l.language_code AS lang, USERENV ('LANG') AS src_lang
               FROM fnd_languages l
              WHERE l.installed_flag IN ('B', 'I')) s
      ON (    t.lookup_type         = s.lookup_type
          AND t.view_application_id = s.application_id
          AND t.LANGUAGE            = s.lang)
   WHEN MATCHED THEN
      UPDATE SET t.meaning          = 'BTVL Salary Advance Category',
                 t.description      = 'CR2025-10-0449. Fixed Chad salary advance categories. TAG holds the frozen recovery duration in months.',
                 t.last_update_date = SYSDATE,
                 t.last_updated_by  = l_user_id
   WHEN NOT MATCHED THEN
      INSERT (lookup_type, security_group_id, view_application_id, LANGUAGE,
              meaning, description, source_lang,
              created_by, creation_date, last_updated_by, last_update_date,
              last_update_login)
      VALUES (s.lookup_type, 0, s.application_id, s.lang,
              'BTVL Salary Advance Category',
              'CR2025-10-0449. Fixed Chad salary advance categories. TAG holds the frozen recovery duration in months.',
              s.src_lang,
              l_user_id, SYSDATE, l_user_id, SYSDATE, l_login_id);

   ----------------------------------------------------------------------
   -- Lookup values
   ----------------------------------------------------------------------
   l_values (1).lookup_code := '1';
   l_values (1).meaning     := '1 Month Salary';
   l_values (1).description := 'Advance capped at 1 month basic salary. Recovered over 4 months.';
   l_values (1).tag         := '4';

   l_values (2).lookup_code := '2';
   l_values (2).meaning     := '2 Months Salary';
   l_values (2).description := 'Advance capped at 2 months basic salary. Recovered over 8 months.';
   l_values (2).tag         := '8';

   l_values (3).lookup_code := '3';
   l_values (3).meaning     := '3 Months Salary';
   l_values (3).description := 'Advance capped at 3 months basic salary. Recovered over 12 months.';
   l_values (3).tag         := '12';

   FOR i IN 1 .. l_values.COUNT
   LOOP
      l_code        := l_values (i).lookup_code;
      l_meaning     := l_values (i).meaning;
      l_description := l_values (i).description;
      l_tag         := l_values (i).tag;

      MERGE INTO fnd_lookup_values v
         USING (SELECT c_lookup_type              AS lookup_type,
                       l_code                     AS lookup_code,
                       l_meaning                  AS meaning,
                       l_description              AS description,
                       l_tag                      AS tag,
                       l_application_id           AS application_id,
                       l.language_code            AS lang,
                       USERENV ('LANG')           AS src_lang
                  FROM fnd_languages l
                 WHERE l.installed_flag IN ('B', 'I')) s
         ON (    v.lookup_type         = s.lookup_type
             AND v.lookup_code         = s.lookup_code
             AND v.view_application_id = s.application_id
             AND v.LANGUAGE            = s.lang)
      WHEN MATCHED THEN
         UPDATE SET v.meaning           = s.meaning,
                    v.description       = s.description,
                    v.tag               = s.tag,
                    v.enabled_flag      = 'Y',
                    v.end_date_active   = NULL,
                    v.last_update_date  = SYSDATE,
                    v.last_updated_by   = l_user_id,
                    v.last_update_login = l_login_id
      WHEN NOT MATCHED THEN
         INSERT (lookup_type, security_group_id, view_application_id, lookup_code,
                 LANGUAGE, meaning, description, tag, enabled_flag,
                 start_date_active, end_date_active, source_lang,
                 created_by, creation_date, last_updated_by, last_update_date,
                 last_update_login)
         VALUES (s.lookup_type, 0, s.application_id, s.lookup_code,
                 s.lang, s.meaning, s.description, s.tag, 'Y',
                 TRUNC (SYSDATE), NULL, s.src_lang,
                 l_user_id, SYSDATE, l_user_id, SYSDATE, l_login_id);
   END LOOP;

   COMMIT;
   DBMS_OUTPUT.put_line ('Lookup ' || c_lookup_type || ' seeded / refreshed.');
EXCEPTION
   WHEN NO_DATA_FOUND
   THEN
      ROLLBACK;
      raise_application_error (
         -20001,
         'Custom application ' || c_appl_short_name || ' is not registered. '
         || 'Register it (or correct c_appl_short_name) before running this script.');
END;
/
