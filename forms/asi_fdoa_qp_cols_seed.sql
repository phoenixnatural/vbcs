SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR CONTINUE

DECLARE
  l_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM all_synonyms
   WHERE owner = 'APPS' AND synonym_name = 'ASI_AP_CSS_DOA_MAPPING_QP';
  IF l_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE SYNONYM asi_ap_css_doa_mapping_qp FOR apps.q_airtel_ap_css_doa_mapping_v';
    DBMS_OUTPUT.PUT_LINE('OK - synonym ASI_AP_CSS_DOA_MAPPING_QP -> Q_AIRTEL_AP_CSS_DOA_MAPPING_V created');
  ELSE
    DBMS_OUTPUT.PUT_LINE('OK - synonym ASI_AP_CSS_DOA_MAPPING_QP already exists');
  END IF;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('FAIL - synonym: '||SQLERRM);
END;
/

DECLARE
  l_cnt NUMBER;
  l_ok  NUMBER := 0;
  TYPE t_v2t IS TABLE OF VARCHAR2(40) INDEX BY PLS_INTEGER;
  l_col t_v2t;
BEGIN
  l_col(1) := 'AIRTEL_CSS_APPROVER1'; l_col(2) := 'AIRTEL_CSS_APPROVER2';
  l_col(3) := 'AIRTEL_CSS_APPROVER3'; l_col(4) := 'AIRTEL_CSS_APPROVER4';
  l_col(5) := 'AIRTEL_CSS_APPROVER5';
  FOR i IN 1..5 LOOP
    SELECT COUNT(*) INTO l_cnt FROM all_tab_columns
     WHERE owner = 'APPS'
       AND table_name = 'Q_AIRTEL_AP_CSS_DOA_MAPPING_V'
       AND column_name IN (l_col(i), l_col(i)||'_NAME');
    IF l_cnt = 2 THEN
      l_ok := l_ok + 1;
      DBMS_OUTPUT.PUT_LINE('OK - column pair verified: '||l_col(i)||' / '||l_col(i)||'_NAME');
    ELSE
      DBMS_OUTPUT.PUT_LINE('FAIL - column pair missing on view: '||l_col(i)||' (found '||l_cnt||' of 2) - DO NOT SEED');
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
  l_col t_v2t;
BEGIN
  SELECT COUNT(*) INTO l_tmpl FROM fnd_lookup_values
   WHERE lookup_type = 'ASI_FDOA_DOC_TYPE_LK';
  IF l_tmpl = 0 THEN
    DBMS_OUTPUT.PUT_LINE('FAIL - template lookup ASI_FDOA_DOC_TYPE_LK not found - cannot derive view_application_id/security_group_id');
    RETURN;
  END IF;
  l_col(1) := 'AIRTEL_CSS_APPROVER1'; l_col(2) := 'AIRTEL_CSS_APPROVER2';
  l_col(3) := 'AIRTEL_CSS_APPROVER3'; l_col(4) := 'AIRTEL_CSS_APPROVER4';
  l_col(5) := 'AIRTEL_CSS_APPROVER5';
  FOR i IN 1..5 LOOP
    SELECT COUNT(*) INTO l_cnt FROM fnd_lookup_values
     WHERE lookup_type = 'ASI_FDOA_QP_APPROVER_COLS_LK'
       AND lookup_code = l_col(i);
    IF l_cnt = 0 THEN
      INSERT INTO fnd_lookup_values
        (lookup_type, security_group_id, view_application_id, lookup_code,
         tag, enabled_flag, start_date_active,
         meaning, description, language, source_lang,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      SELECT 'ASI_FDOA_QP_APPROVER_COLS_LK', t.security_group_id, t.view_application_id, l_col(i),
             l_col(i)||'_NAME', 'Y', TRUNC(SYSDATE),
             'QP Approver '||i||' person_id column',
             'CR# 2026-02-0585 - approver person_id column on Q_AIRTEL_AP_CSS_DOA_MAPPING_V; paired display-name column held in TAG',
             t.language, t.source_lang,
             SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log
        FROM fnd_lookup_values t
       WHERE t.lookup_type = 'ASI_FDOA_DOC_TYPE_LK'
         AND t.lookup_code = (SELECT MIN(lookup_code) FROM fnd_lookup_values
                               WHERE lookup_type = 'ASI_FDOA_DOC_TYPE_LK');
      DBMS_OUTPUT.PUT_LINE('OK - seeded '||l_col(i)||' ('||SQL%ROWCOUNT||' language rows)');
    ELSE
      DBMS_OUTPUT.PUT_LINE('OK - already seeded: '||l_col(i));
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
  DBMS_OUTPUT.PUT_LINE('VERIFY - enabled QP approver columns (expect 5): '||l_cnt);
  SELECT COUNT(*) INTO l_cnt FROM all_synonyms
   WHERE owner = 'APPS' AND synonym_name = 'ASI_AP_CSS_DOA_MAPPING_QP';
  DBMS_OUTPUT.PUT_LINE('VERIFY - synonym in place (expect 1): '||l_cnt);
END;
/
