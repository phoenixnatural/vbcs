/*==========================================================================
|| CR         : CR2025-10-0449 - Chad OPCO Salary Advance
|| Object     : FND lookup type XXBTVL_SA_ENABLED_ORGS (new)
|| Purpose    : Drives WHICH operating units the new Chad rules apply to.
||
||                 Code | Meaning              | Description
||                 -----+----------------------+------------------
||                 7107 | TD MO IEXPENSE USER  | Tchad GSM
||                 7108 | TD MMB IEXPENSE USER | Tchad AM
||
|| DEVIATION FROM HLD (see docs/HLD-gap-analysis.md, GAP-07):
||   The HLD lists one new lookup only and implies ORG_IDs 7107 / 7108 are
||   set in code. They are seeded here instead, for the same reason the HLD
||   gives for XXBTVL_SA_CATEGORY: the data is tiny and fixed, and adding or
||   removing an OPCO later must not require a package change and a CEMLI
||   re-deployment. btvl_oie_sa_rules_pkg.is_rules_enabled reads this lookup;
||   every other OPCO continues to behave exactly as before (HLD s.9).
|| Script     : 03 of 07 - run as APPS.
||========================================================================*/

SET DEFINE OFF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

DECLARE
   -- TODO(CR2025-10-0449): confirm with the DBA - must match script 02.
   c_appl_short_name   CONSTANT VARCHAR2 (50) := 'XXBTVL';
   c_lookup_type       CONSTANT VARCHAR2 (30) := 'XXBTVL_SA_ENABLED_ORGS';

   l_application_id             NUMBER;
   l_user_id                    NUMBER := NVL (fnd_global.user_id, 1);
   l_login_id                   NUMBER := NVL (fnd_global.login_id, -1);

   l_code                       VARCHAR2 (30);
   l_meaning                    VARCHAR2 (80);
   l_description                VARCHAR2 (240);

   TYPE t_code_tbl IS TABLE OF VARCHAR2 (30) INDEX BY PLS_INTEGER;
   TYPE t_text_tbl IS TABLE OF VARCHAR2 (240) INDEX BY PLS_INTEGER;

   l_codes                      t_code_tbl;
   l_meanings                   t_text_tbl;
   l_descriptions               t_text_tbl;
BEGIN
   SELECT application_id
     INTO l_application_id
     FROM fnd_application
    WHERE application_short_name = c_appl_short_name;

   MERGE INTO fnd_lookup_types t
      USING (SELECT c_lookup_type AS lookup_type, l_application_id AS application_id
               FROM DUAL) s
      ON (t.lookup_type = s.lookup_type AND t.view_application_id = s.application_id)
   WHEN MATCHED THEN
      UPDATE SET t.last_update_date = SYSDATE, t.last_updated_by = l_user_id
   WHEN NOT MATCHED THEN
      INSERT (lookup_type, security_group_id, view_application_id, application_id,
              customization_level, created_by, creation_date,
              last_updated_by, last_update_date, last_update_login)
      VALUES (c_lookup_type, 0, l_application_id, l_application_id,
              'U', l_user_id, SYSDATE, l_user_id, SYSDATE, l_login_id);

   MERGE INTO fnd_lookup_types_tl t
      USING (SELECT c_lookup_type AS lookup_type, l_application_id AS application_id,
                    l.language_code AS lang, USERENV ('LANG') AS src_lang
               FROM fnd_languages l
              WHERE l.installed_flag IN ('B', 'I')) s
      ON (    t.lookup_type         = s.lookup_type
          AND t.view_application_id = s.application_id
          AND t.LANGUAGE            = s.lang)
   WHEN MATCHED THEN
      UPDATE SET t.meaning          = 'BTVL Salary Advance - Enabled Operating Units',
                 t.last_update_date = SYSDATE,
                 t.last_updated_by  = l_user_id
   WHEN NOT MATCHED THEN
      INSERT (lookup_type, security_group_id, view_application_id, LANGUAGE,
              meaning, description, source_lang, created_by, creation_date,
              last_updated_by, last_update_date, last_update_login)
      VALUES (s.lookup_type, 0, s.application_id, s.lang,
              'BTVL Salary Advance - Enabled Operating Units',
              'CR2025-10-0449. Operating units where the fixed category / frozen duration / cooling-off rules apply. Lookup code = ORG_ID.',
              s.src_lang, l_user_id, SYSDATE, l_user_id, SYSDATE, l_login_id);

   l_codes (1)        := '7107';
   l_meanings (1)     := 'TD MO IEXPENSE USER';
   l_descriptions (1) := 'Tchad OPCO - GSM line of business.';

   l_codes (2)        := '7108';
   l_meanings (2)     := 'TD MMB IEXPENSE USER';
   l_descriptions (2) := 'Tchad OPCO - AM line of business.';

   FOR i IN 1 .. l_codes.COUNT
   LOOP
      l_code        := l_codes (i);
      l_meaning     := l_meanings (i);
      l_description := l_descriptions (i);

      MERGE INTO fnd_lookup_values v
         USING (SELECT c_lookup_type    AS lookup_type,
                       l_code           AS lookup_code,
                       l_meaning        AS meaning,
                       l_description    AS description,
                       l_application_id AS application_id,
                       l.language_code  AS lang,
                       USERENV ('LANG') AS src_lang
                  FROM fnd_languages l
                 WHERE l.installed_flag IN ('B', 'I')) s
         ON (    v.lookup_type         = s.lookup_type
             AND v.lookup_code         = s.lookup_code
             AND v.view_application_id = s.application_id
             AND v.LANGUAGE            = s.lang)
      WHEN MATCHED THEN
         UPDATE SET v.meaning          = s.meaning,
                    v.description      = s.description,
                    v.enabled_flag     = 'Y',
                    v.end_date_active  = NULL,
                    v.last_update_date = SYSDATE,
                    v.last_updated_by  = l_user_id
      WHEN NOT MATCHED THEN
         INSERT (lookup_type, security_group_id, view_application_id, lookup_code,
                 LANGUAGE, meaning, description, enabled_flag,
                 start_date_active, end_date_active, source_lang,
                 created_by, creation_date, last_updated_by, last_update_date,
                 last_update_login)
         VALUES (s.lookup_type, 0, s.application_id, s.lookup_code,
                 s.lang, s.meaning, s.description, 'Y',
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
         'Custom application ' || c_appl_short_name || ' is not registered.');
END;
/
