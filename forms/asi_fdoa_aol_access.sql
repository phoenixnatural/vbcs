SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR CONTINUE

DECLARE
  l_user  NUMBER;
  l_resp  NUMBER;
  l_app   NUMBER;
BEGIN
  BEGIN
    SELECT user_id INTO l_user FROM fnd_user WHERE user_name = 'SYSADMIN';
    SELECT responsibility_id, application_id INTO l_resp, l_app
      FROM fnd_responsibility WHERE responsibility_key = 'SYSTEM_ADMINISTRATOR';
    fnd_global.apps_initialize(l_user, l_resp, l_app);
    DBMS_OUTPUT.PUT_LINE('OK - apps_initialize SYSADMIN/SYSTEM_ADMINISTRATOR');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('OK - apps_initialize skipped ('||SQLERRM||') - WHO columns fall back to 0/-1');
  END;
END;
/

DECLARE
  l_app_id   NUMBER;
  l_form_id  NUMBER;
  l_cnt      NUMBER;
  l_who_usr  NUMBER := NVL(fnd_global.user_id, 0);
  l_who_log  NUMBER := NVL(fnd_global.login_id, -1);
  TYPE t_v2t IS TABLE OF VARCHAR2(240) INDEX BY PLS_INTEGER;
  l_form  t_v2t; l_uname t_v2t;
BEGIN
  SELECT application_id INTO l_app_id FROM fnd_application WHERE application_short_name = 'BTVL';
  l_form(1) := 'ASI_FDOA_EXIT_FMB';      l_uname(1) := 'ASI FDOA Exit Replacement Form';
  l_form(2) := 'ASI_FDOA_MOVEMENT_FMB';  l_uname(2) := 'ASI FDOA Movement Replacement Form';
  l_form(3) := 'ASI_FDOA_SUPERUSER_FMB'; l_uname(3) := 'ASI FDOA Superuser Replacement Form';
  FOR i IN 1..3 LOOP
    SELECT COUNT(*) INTO l_cnt FROM fnd_form
     WHERE form_name = l_form(i) AND application_id = l_app_id;
    IF l_cnt = 0 THEN
      SELECT fnd_form_s.NEXTVAL INTO l_form_id FROM dual;
      INSERT INTO fnd_form
        (application_id, form_id, form_name, audit_enabled_flag,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      VALUES
        (l_app_id, l_form_id, l_form(i), 'N',
         SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log);
      INSERT INTO fnd_form_tl
        (application_id, form_id, language, user_form_name, description, source_lang,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      SELECT l_app_id, l_form_id, lng.language_code, l_uname(i),
             'CR# 2026-02-0585 Exit and Movement of Employee', USERENV('LANG'),
             SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log
        FROM fnd_languages lng
       WHERE lng.installed_flag IN ('I','B');
      DBMS_OUTPUT.PUT_LINE('OK - form registered: '||l_form(i)||' (form_id '||l_form_id||')');
    ELSE
      DBMS_OUTPUT.PUT_LINE('OK - form already exists: '||l_form(i));
    END IF;
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('FAIL - form registration: '||SQLERRM);
END;
/

DECLARE
  l_app_id  NUMBER;
  l_form_id NUMBER;
  l_func_id NUMBER;
  l_cnt     NUMBER;
  l_who_usr NUMBER := NVL(fnd_global.user_id, 0);
  l_who_log NUMBER := NVL(fnd_global.login_id, -1);
  TYPE t_v2t IS TABLE OF VARCHAR2(240) INDEX BY PLS_INTEGER;
  l_fn t_v2t; l_fnu t_v2t; l_frm t_v2t;
BEGIN
  SELECT application_id INTO l_app_id FROM fnd_application WHERE application_short_name = 'BTVL';
  l_fn(1) := 'ASI_FDOA_EXIT_FN';      l_fnu(1) := 'ASI FDOA Exit Replacement';      l_frm(1) := 'ASI_FDOA_EXIT_FMB';
  l_fn(2) := 'ASI_FDOA_MOVEMENT_FN';  l_fnu(2) := 'ASI FDOA Movement Replacement';  l_frm(2) := 'ASI_FDOA_MOVEMENT_FMB';
  l_fn(3) := 'ASI_FDOA_SUPERUSER_FN'; l_fnu(3) := 'ASI FDOA Superuser Replacement'; l_frm(3) := 'ASI_FDOA_SUPERUSER_FMB';
  FOR i IN 1..3 LOOP
    SELECT COUNT(*) INTO l_cnt FROM fnd_form_functions WHERE function_name = l_fn(i);
    IF l_cnt = 0 THEN
      SELECT form_id INTO l_form_id FROM fnd_form
       WHERE form_name = l_frm(i) AND application_id = l_app_id;
      SELECT fnd_form_functions_s.NEXTVAL INTO l_func_id FROM dual;
      INSERT INTO fnd_form_functions
        (function_id, function_name, application_id, form_id, type,
         maintenance_mode_support, context_dependence,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      VALUES
        (l_func_id, l_fn(i), l_app_id, l_form_id, 'FORM',
         'NONE', 'RESP',
         SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log);
      INSERT INTO fnd_form_functions_tl
        (function_id, language, user_function_name, description, source_lang,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      SELECT l_func_id, lng.language_code, l_fnu(i),
             'CR# 2026-02-0585 Exit and Movement of Employee', USERENV('LANG'),
             SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log
        FROM fnd_languages lng
       WHERE lng.installed_flag IN ('I','B');
      DBMS_OUTPUT.PUT_LINE('OK - function registered: '||l_fn(i)||' (function_id '||l_func_id||')');
    ELSE
      DBMS_OUTPUT.PUT_LINE('OK - function already exists: '||l_fn(i));
    END IF;
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('FAIL - function registration: '||SQLERRM);
END;
/

DECLARE
  l_menu_id NUMBER;
  l_cnt     NUMBER;
  l_who_usr NUMBER := NVL(fnd_global.user_id, 0);
  l_who_log NUMBER := NVL(fnd_global.login_id, -1);
  TYPE t_v2t IS TABLE OF VARCHAR2(240) INDEX BY PLS_INTEGER;
  l_mn t_v2t; l_mnu t_v2t;
BEGIN
  l_mn(1) := 'ASI_FDOA_MGR_MN'; l_mnu(1) := 'ASI FDOA Manager Menu';
  l_mn(2) := 'ASI_FDOA_SU_MN';  l_mnu(2) := 'ASI FDOA Superuser Menu';
  FOR i IN 1..2 LOOP
    SELECT COUNT(*) INTO l_cnt FROM fnd_menus WHERE menu_name = l_mn(i);
    IF l_cnt = 0 THEN
      SELECT fnd_menus_s.NEXTVAL INTO l_menu_id FROM dual;
      INSERT INTO fnd_menus
        (menu_id, menu_name, menu_type,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      VALUES
        (l_menu_id, l_mn(i), 'STANDARD',
         SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log);
      INSERT INTO fnd_menus_tl
        (menu_id, language, user_menu_name, description, source_lang,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      SELECT l_menu_id, lng.language_code, l_mnu(i),
             'CR# 2026-02-0585 Exit and Movement of Employee', USERENV('LANG'),
             SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log
        FROM fnd_languages lng
       WHERE lng.installed_flag IN ('I','B');
      DBMS_OUTPUT.PUT_LINE('OK - menu created: '||l_mn(i)||' (menu_id '||l_menu_id||')');
    ELSE
      DBMS_OUTPUT.PUT_LINE('OK - menu already exists: '||l_mn(i));
    END IF;
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('FAIL - menu creation: '||SQLERRM);
END;
/

DECLARE
  l_menu_id NUMBER;
  l_func_id NUMBER;
  l_seq     NUMBER;
  l_cnt     NUMBER;
  l_who_usr NUMBER := NVL(fnd_global.user_id, 0);
  l_who_log NUMBER := NVL(fnd_global.login_id, -1);
  PROCEDURE add_func (p_menu VARCHAR2, p_func VARCHAR2, p_prompt VARCHAR2) IS
  BEGIN
    SELECT menu_id INTO l_menu_id FROM fnd_menus WHERE menu_name = p_menu;
    SELECT function_id INTO l_func_id FROM fnd_form_functions WHERE function_name = p_func;
    SELECT COUNT(*) INTO l_cnt FROM fnd_menu_entries
     WHERE menu_id = l_menu_id AND function_id = l_func_id;
    IF l_cnt = 0 THEN
      SELECT NVL(MAX(entry_sequence),0) + 1 INTO l_seq
        FROM fnd_menu_entries WHERE menu_id = l_menu_id;
      INSERT INTO fnd_menu_entries
        (menu_id, entry_sequence, function_id, grant_flag,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      VALUES
        (l_menu_id, l_seq, l_func_id, 'Y',
         SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log);
      INSERT INTO fnd_menu_entries_tl
        (menu_id, entry_sequence, language, prompt, description, source_lang,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      SELECT l_menu_id, l_seq, lng.language_code, p_prompt,
             'CR# 2026-02-0585', USERENV('LANG'),
             SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log
        FROM fnd_languages lng
       WHERE lng.installed_flag IN ('I','B');
      DBMS_OUTPUT.PUT_LINE('OK - menu entry: '||p_menu||' seq '||l_seq||' -> '||p_func);
    ELSE
      DBMS_OUTPUT.PUT_LINE('OK - menu entry already exists: '||p_menu||' -> '||p_func);
    END IF;
  END;
BEGIN
  add_func('ASI_FDOA_MGR_MN', 'ASI_FDOA_EXIT_FN',      'Exit Replacement');
  add_func('ASI_FDOA_MGR_MN', 'ASI_FDOA_MOVEMENT_FN',  'Movement Replacement');
  add_func('ASI_FDOA_SU_MN',  'ASI_FDOA_SUPERUSER_FN', 'Superuser Replacement');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('FAIL - menu entries: '||SQLERRM);
END;
/

DECLARE
  l_root_menu NUMBER;
  l_sub_menu  NUMBER;
  l_seq       NUMBER;
  l_cnt       NUMBER;
  l_who_usr   NUMBER := NVL(fnd_global.user_id, 0);
  l_who_log   NUMBER := NVL(fnd_global.login_id, -1);
  PROCEDURE attach (p_resp_key VARCHAR2, p_sub_menu VARCHAR2, p_prompt VARCHAR2) IS
  BEGIN
    SELECT menu_id INTO l_root_menu FROM fnd_responsibility
     WHERE responsibility_key = p_resp_key;
    SELECT menu_id INTO l_sub_menu FROM fnd_menus WHERE menu_name = p_sub_menu;
    SELECT COUNT(*) INTO l_cnt FROM fnd_menu_entries
     WHERE menu_id = l_root_menu AND sub_menu_id = l_sub_menu;
    IF l_cnt = 0 THEN
      SELECT NVL(MAX(entry_sequence),0) + 1 INTO l_seq
        FROM fnd_menu_entries WHERE menu_id = l_root_menu;
      INSERT INTO fnd_menu_entries
        (menu_id, entry_sequence, sub_menu_id, grant_flag,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      VALUES
        (l_root_menu, l_seq, l_sub_menu, 'Y',
         SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log);
      INSERT INTO fnd_menu_entries_tl
        (menu_id, entry_sequence, language, prompt, description, source_lang,
         creation_date, created_by, last_update_date, last_updated_by, last_update_login)
      SELECT l_root_menu, l_seq, lng.language_code, p_prompt,
             'CR# 2026-02-0585', USERENV('LANG'),
             SYSDATE, l_who_usr, SYSDATE, l_who_usr, l_who_log
        FROM fnd_languages lng
       WHERE lng.installed_flag IN ('I','B');
      DBMS_OUTPUT.PUT_LINE('OK - attached '||p_sub_menu||' to resp '||p_resp_key||' (root menu '||l_root_menu||' seq '||l_seq||')');
    ELSE
      DBMS_OUTPUT.PUT_LINE('OK - already attached: '||p_sub_menu||' on '||p_resp_key);
    END IF;
  END;
BEGIN
  attach('ASI MGR APPROVALS', 'ASI_FDOA_MGR_MN', 'ASI FDOA Replacement');
  attach('DOAMAPPINGACCESS',  'ASI_FDOA_SU_MN',  'ASI FDOA Replacement');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('FAIL - responsibility attach: '||SQLERRM);
END;
/

COMMIT;

DECLARE
  l_req NUMBER;
BEGIN
  l_req := fnd_request.submit_request('FND', 'FNDSCMPI', NULL, NULL, FALSE, 'Y');
  COMMIT;
  IF l_req > 0 THEN
    DBMS_OUTPUT.PUT_LINE('OK - Compile Security submitted, request_id '||l_req);
  ELSE
    DBMS_OUTPUT.PUT_LINE('OK - Compile Security NOT submitted - run it from SRS (System Administrator > Requests > Compile Security, Everything=Yes)');
  END IF;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('OK - Compile Security NOT submitted ('||SQLERRM||') - run it from SRS (Everything=Yes)');
END;
/

DECLARE
  l_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_cnt FROM fnd_form f, fnd_application a
   WHERE a.application_short_name = 'BTVL' AND f.application_id = a.application_id
     AND f.form_name IN ('ASI_FDOA_EXIT_FMB','ASI_FDOA_MOVEMENT_FMB','ASI_FDOA_SUPERUSER_FMB');
  DBMS_OUTPUT.PUT_LINE('VERIFY - forms registered (expect 3): '||l_cnt);
  SELECT COUNT(*) INTO l_cnt FROM fnd_form_functions
   WHERE function_name IN ('ASI_FDOA_EXIT_FN','ASI_FDOA_MOVEMENT_FN','ASI_FDOA_SUPERUSER_FN');
  DBMS_OUTPUT.PUT_LINE('VERIFY - functions (expect 3): '||l_cnt);
  SELECT COUNT(*) INTO l_cnt FROM fnd_menus
   WHERE menu_name IN ('ASI_FDOA_MGR_MN','ASI_FDOA_SU_MN');
  DBMS_OUTPUT.PUT_LINE('VERIFY - menus (expect 2): '||l_cnt);
  SELECT COUNT(*) INTO l_cnt FROM fnd_menu_entries me, fnd_menus m
   WHERE m.menu_name IN ('ASI_FDOA_MGR_MN','ASI_FDOA_SU_MN') AND me.menu_id = m.menu_id;
  DBMS_OUTPUT.PUT_LINE('VERIFY - function entries (expect 3): '||l_cnt);
  SELECT COUNT(*) INTO l_cnt
    FROM fnd_menu_entries me, fnd_responsibility r, fnd_menus m
   WHERE r.responsibility_key IN ('ASI MGR APPROVALS','DOAMAPPINGACCESS')
     AND me.menu_id = r.menu_id
     AND me.sub_menu_id = m.menu_id
     AND m.menu_name IN ('ASI_FDOA_MGR_MN','ASI_FDOA_SU_MN');
  DBMS_OUTPUT.PUT_LINE('VERIFY - responsibility attachments (expect 2): '||l_cnt);
END;
/
