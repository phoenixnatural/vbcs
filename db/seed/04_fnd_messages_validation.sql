/*==========================================================================
|| CR         : CR2025-10-0449 - Chad OPCO Salary Advance
|| Object     : FND_NEW_MESSAGES (new custom messages)
|| Purpose    : Seed the validation messages VAL-01 .. VAL-09 from the HLD
||              so the text is translatable and maintainable from the
||              Messages form, not hard-coded in the package body.
|| Script     : 04 of 07 - run as APPS.
||
|| Message name convention : XXBTVL_SA_<RULE>
|| Tokens                  : &AMOUNT, &LIMIT, &MONTHS, &DATE - set with
||                           fnd_message.set_token in the rules package.
||
|| VAL-04 and VAL-05 from the HLD are deliberately NOT seeded: the HLD marks
|| both "Not Required as recovery duration will be auto-defaulted". The
|| duration is derived server-side and the field is read-only, so neither
|| condition is reachable from the UI. A defensive equivalent of VAL-05 is
|| still raised by the package if a tampered / API-sourced payload carries a
|| duration that does not match the category - it uses XXBTVL_SA_VAL05.
|| See docs/HLD-gap-analysis.md GAP-03.
||========================================================================*/

SET DEFINE OFF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

DECLARE
   -- TODO(CR2025-10-0449): confirm with the DBA - must match scripts 02/03.
   c_appl_short_name   CONSTANT VARCHAR2 (50) := 'XXBTVL';

   l_application_id             NUMBER;
   l_user_id                    NUMBER := NVL (fnd_global.user_id, 1);
   l_login_id                   NUMBER := NVL (fnd_global.login_id, -1);

   TYPE t_msg_rec IS RECORD (
      message_name   VARCHAR2 (30),
      message_text   VARCHAR2 (2000),
      description    VARCHAR2 (240)
   );

   TYPE t_msg_tbl IS TABLE OF t_msg_rec INDEX BY PLS_INTEGER;

   l_msgs                       t_msg_tbl;

   l_name                       VARCHAR2 (30);
   l_text                       VARCHAR2 (2000);
   l_desc                       VARCHAR2 (240);
BEGIN
   SELECT application_id
     INTO l_application_id
     FROM fnd_application
    WHERE application_short_name = c_appl_short_name;

   l_msgs (1).message_name := 'XXBTVL_SA_VAL01';
   l_msgs (1).message_text := 'Please select salary advance category.';
   l_msgs (1).description  := 'VAL-01 No salary advance category selected.';

   l_msgs (2).message_name := 'XXBTVL_SA_VAL02';
   l_msgs (2).message_text := 'Please enter the requested salary advance amount.';
   l_msgs (2).description  := 'VAL-02 Requested amount is blank or zero.';

   l_msgs (3).message_name := 'XXBTVL_SA_VAL03';
   l_msgs (3).message_text := 'Requested amount exceeds the allowed limit for selected salary advance category. The maximum for &CATEGORY is &LIMIT.';
   l_msgs (3).description  := 'VAL-03 Amount exceeds the category cap.';

   l_msgs (4).message_name := 'XXBTVL_SA_VAL05';
   l_msgs (4).message_text := 'The selected recovery duration does not match the salary advance category. The recovery duration for &CATEGORY is &MONTHS months.';
   l_msgs (4).description  := 'VAL-05 Defensive check only - duration is auto-defaulted and read-only on the page.';

   l_msgs (5).message_name := 'XXBTVL_SA_VAL06';
   l_msgs (5).message_text := 'Please attach the signed salary advance approval document before submitting the request.';
   l_msgs (5).description  := 'VAL-06 Mandatory attachment missing.';

   l_msgs (6).message_name := 'XXBTVL_SA_VAL07';
   l_msgs (6).message_text := 'You cannot apply for a new salary advance until the previous advance is fully repaid.';
   l_msgs (6).description  := 'VAL-07 An open advance with a non-zero balance exists.';

   l_msgs (7).message_name := 'XXBTVL_SA_VAL08';
   l_msgs (7).message_text := 'You are not eligible for a new Salary Advance. A new application can only be submitted two months after the completion of the previous Salary Advance repayment. You may apply on or after &DATE.';
   l_msgs (7).description  := 'VAL-08 Two-month cooling-off period not yet completed.';

   -- Existing rule, restated here so the message is owned by this CEMLI.
   l_msgs (8).message_name := 'XXBTVL_SA_VAL10';
   l_msgs (8).message_text := 'You have reached the maximum of &LIMIT salary advance requests for the calendar year.';
   l_msgs (8).description  := 'VAL-10 Existing 2-per-calendar-year limit (retained by this CR).';

   -- Added by implementation - no salary on file means the cap cannot be
   -- evaluated, so the request must be blocked rather than allowed through.
   l_msgs (9).message_name := 'XXBTVL_SA_VAL09';
   l_msgs (9).message_text := 'Your monthly basic salary could not be determined. Please contact HR before submitting a salary advance request.';
   l_msgs (9).description  := 'VAL-09 Implementation-added. Salary not found in the Fusion feed.';

   FOR i IN 1 .. l_msgs.COUNT
   LOOP
      l_name := l_msgs (i).message_name;
      l_text := l_msgs (i).message_text;
      l_desc := l_msgs (i).description;

      MERGE INTO fnd_new_messages m
         USING (SELECT l_application_id AS application_id,
                       l_name           AS message_name,
                       l_text           AS message_text,
                       l_desc           AS description,
                       l.language_code  AS lang
                  FROM fnd_languages l
                 WHERE l.installed_flag IN ('B', 'I')) s
         ON (    m.application_id = s.application_id
             AND m.message_name   = s.message_name
             AND m.LANGUAGE_CODE  = s.lang)
      WHEN MATCHED THEN
         UPDATE SET m.message_text     = s.message_text,
                    m.description      = s.description,
                    m.last_update_date = SYSDATE,
                    m.last_updated_by  = l_user_id
      WHEN NOT MATCHED THEN
         INSERT (application_id, message_name, language_code, message_number,
                 message_text, description, type, max_length,
                 created_by, creation_date, last_updated_by, last_update_date,
                 last_update_login)
         VALUES (s.application_id, s.message_name, s.lang, NULL,
                 s.message_text, s.description, 'ERROR', 2000,
                 l_user_id, SYSDATE, l_user_id, SYSDATE, l_login_id);
   END LOOP;

   COMMIT;
   DBMS_OUTPUT.put_line (l_msgs.COUNT || ' messages seeded / refreshed.');
EXCEPTION
   WHEN NO_DATA_FOUND
   THEN
      ROLLBACK;
      raise_application_error (
         -20001,
         'Custom application ' || c_appl_short_name || ' is not registered.');
END;
/
