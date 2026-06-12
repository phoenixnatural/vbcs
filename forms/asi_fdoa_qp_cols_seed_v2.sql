SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR CONTINUE

DECLARE
  l_cnt NUMBER;
BEGIN
  UPDATE fnd_lookup_values
     SET enabled_flag = 'N'
   WHERE lookup_type = 'ASI_FDOA_QP_APPROVER_COLS_LK'
     AND lookup_code LIKE 'AIRTEL_CSS_%';
  l_cnt := SQL%ROWCOUNT;
  IF l_cnt > 0 THEN
    DBMS_OUTPUT.PUT_LINE('OK - disabled '||l_cnt||' v1 (view-column) manifest rows');
  ELSE
    DBMS_OUTPUT.PUT_LINE('OK - no v1 manifest rows to disable');
  END IF;
END;
/

DECLARE
  l_cnt NUMBER;
  l_ok  NUMBER := 0;
  TYPE t_v2t IS TABLE OF VARCHAR2(40) INDEX BY PLS_INTEGER;
  l_id t_v2t; l_nm t_v2t;
BEGIN
  l_id(1) := 'CHARACTER11'; l_nm(1) := 'CHARACTER12';
  l_id(2) := 'CHARACTER13'; l_nm(2) := 'CHARACTER14';
  l_id(3) := 'CHARACTER15'; l_nm(3) := 'CHARACTER16';
  l_id(4) := 'CHARACTER17'; l_nm(4) := 'CHARACTER18';
  l_id(5) := 'CHARACTER19'; l_nm(5) := 'CHARACTER20';
  FOR i IN 1..5 LOOP
    SELECT COUNT(*) INTO l_cnt FROM all_tab_columns
     WHERE owner = 'APPS' AND table_name = 'QA_RESULTS'
       AND column_name IN (l_id(i), l_nm(i));
    IF l_cnt = 2 THEN
      l_ok := l_ok + 1;
      DBMS_OUTPUT.PUT_LINE('OK - QA_RESULTS column pair verified: '||l_id(i)||' / '||l_nm(i));
    ELSE
      DBMS_OUTPUT.PUT_LINE('FAIL - QA_RESULTS column pair missing: '||l_id(i)||' (found '||l_cnt||' of 2) - DO NOT SEED');
    END IF;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('VERIFY - column pairs OK (expect 5): '||l_ok);
END;
/

DECLARE
  l_cnt     NUMBER;
  l_tmpl    NUMBER;
  l_who_usr NUMBER := NVL(fnd_global.user_id, 0);
  l_who_log NUMBER := NVL(fnd_global.login_id, -1);
  TYPE t_v2t IS TABLE OF VARCHAR2(40) INDEX BY PLS_INTEGER;
  l_id t_v2t; l_nm t_v2t;
BEGIN
  SELECT COUNT(*) INTO l_tmpl FROM fnd_lookup_values
   WHERE lookup_type = 'ASI_FDOA_DOC_TYPE_LK';
  IF l_tmpl = 0 THEN
    DBMS_OUTPUT.PUT_LINE('FAIL - template lookup ASI_FDOA_DOC_TYPE_LK not found');
    RETURN;
  END IF;
  l_id(1) := 'CHARACTER11'; l_nm(1) := 'CHARACTER12';
  l_id(2) := 'CHARACTER13'; l_nm(2) := 'CHARACTER14';
  l_id(3) := 'CHARACTER15'; l_nm(3) := 'CHARACTER16';
  l_id(4) := 'CHARACTER17'; l_nm(4) := 'CHARACTER18';
  l_id(5) := 'CHARACTER19'; l_nm(5) := 'CHARACTER20';
  FOR i IN 1..5 LOOP
    SELECT COUNT(*) INTO l_cnt FROM fnd_lookup_values
     WHERE lookup_type = 'ASI_FDOA_QP_APPROVER_COLS_LK'
       AND lookup_code = l_id(i);
    IF l_cnt = 0 THEN
      INSERT INTO fnd_lookup_values
        (lookup_type, security_group_id, view_application_id, lookup_code,
         tag, enabled_flag, start_date_active,
         meaning, description, language, source_lang,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      SELECT 'ASI_FDOA_QP_APPROVER_COLS_LK', t.security_group_id, t.view_application_id, l_id(i),
             l_nm(i), 'Y', TRUNC(SYSDATE),
             'QP Approver '||i||' person_id column (QA_RESULTS)',
             'CR# 2026-02-0585 - approver person_id column on QA_RESULTS for plan AIRTEL AP CSS DOA MAPPING; paired display-name column in TAG',
             t.language, t.source_lang,
             SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log
        FROM fnd_lookup_values t
       WHERE t.lookup_type = 'ASI_FDOA_DOC_TYPE_LK'
         AND t.lookup_code = (SELECT MIN(lookup_code) FROM fnd_lookup_values
                               WHERE lookup_type = 'ASI_FDOA_DOC_TYPE_LK');
      DBMS_OUTPUT.PUT_LINE('OK - seeded '||l_id(i)||' (TAG '||l_nm(i)||', '||SQL%ROWCOUNT||' language rows)');
    ELSE
      UPDATE fnd_lookup_values
         SET enabled_flag = 'Y', tag = l_nm(i)
       WHERE lookup_type = 'ASI_FDOA_QP_APPROVER_COLS_LK'
         AND lookup_code = l_id(i);
      DBMS_OUTPUT.PUT_LINE('OK - already seeded (re-enabled/TAG refreshed): '||l_id(i));
    END IF;
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('FAIL - lookup seed: '||SQLERRM);
END;
/

COMMIT;

DECLARE
  l_cnt NUMBER;
BEGIN
  SELECT COUNT(DISTINCT lookup_code) INTO l_cnt
    FROM fnd_lookup_values
   WHERE lookup_type = 'ASI_FDOA_QP_APPROVER_COLS_LK'
     AND enabled_flag = 'Y';
  DBMS_OUTPUT.PUT_LINE('VERIFY - enabled manifest rows (expect 5): '||l_cnt);
  SELECT COUNT(*) INTO l_cnt FROM fnd_lookup_values
   WHERE lookup_type = 'ASI_FDOA_QP_APPROVER_COLS_LK'
     AND enabled_flag = 'Y'
     AND lookup_code NOT LIKE 'CHARACTER%';
  DBMS_OUTPUT.PUT_LINE('VERIFY - enabled non-CHARACTER rows (expect 0): '||l_cnt);
  SELECT COUNT(*) INTO l_cnt FROM apps.qa_plans
   WHERE name = 'AIRTEL AP CSS DOA MAPPING';
  DBMS_OUTPUT.PUT_LINE('VERIFY - QP plan present (expect 1): '||l_cnt);
END;
/
