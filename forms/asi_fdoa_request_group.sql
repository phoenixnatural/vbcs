SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR CONTINUE

DECLARE
  l_group_name fnd_request_groups.request_group_name%TYPE;
  l_group_app  fnd_application_tl.application_name%TYPE;
  l_prog_app   fnd_application_tl.application_name%TYPE;
  l_cnt        NUMBER;
  TYPE t_v2t IS TABLE OF VARCHAR2(40) INDEX BY PLS_INTEGER;
  l_cp t_v2t;
BEGIN
  BEGIN
    SELECT rg.request_group_name, atl.application_name
      INTO l_group_name, l_group_app
      FROM fnd_responsibility_vl r,
           fnd_request_groups    rg,
           fnd_application_tl    atl
     WHERE r.responsibility_name  = 'ASI Invoice DOA Access'
       AND rg.request_group_id    = r.request_group_id
       AND rg.application_id      = r.group_application_id
       AND atl.application_id     = rg.application_id
       AND atl.language           = USERENV('LANG');
    DBMS_OUTPUT.PUT_LINE('OK - target request group: "'||l_group_name||'" (app: '||l_group_app||')');
  EXCEPTION WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('FAIL - responsibility has no request group attached - report group/app and stop');
    RETURN;
  END;

  SELECT application_name INTO l_prog_app
    FROM fnd_application_vl
   WHERE application_short_name = 'BTVL';

  l_cp(1) := 'ASIFDOAMGRRPT';
  l_cp(2) := 'ASIFDOASURPT';
  l_cp(3) := 'ASIFDOANOTIF';
  l_cp(4) := 'ASIFDOAPRPO';
  l_cp(5) := 'ASIFDOAQP';

  FOR i IN 1..5 LOOP
    SELECT COUNT(*) INTO l_cnt
      FROM fnd_request_group_units u,
           fnd_request_groups      g,
           fnd_concurrent_programs p,
           fnd_application         a
     WHERE g.request_group_name = l_group_name
       AND u.request_group_id   = g.request_group_id
       AND u.application_id     = g.application_id
       AND u.request_unit_type  = 'P'
       AND p.concurrent_program_id = u.request_unit_id
       AND p.application_id        = u.unit_application_id
       AND p.concurrent_program_name = l_cp(i)
       AND a.application_id          = p.application_id
       AND a.application_short_name  = 'BTVL';
    IF l_cnt = 0 THEN
      BEGIN
        fnd_program.add_to_group
          ( program_short_name  => l_cp(i)
          , program_application => l_prog_app
          , request_group       => l_group_name
          , group_application   => l_group_app );
        DBMS_OUTPUT.PUT_LINE('OK - added '||l_cp(i)||' to "'||l_group_name||'"');
      EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FAIL - add '||l_cp(i)||': '||SQLERRM);
      END;
    ELSE
      DBMS_OUTPUT.PUT_LINE('OK - already in group: '||l_cp(i));
    END IF;
  END LOOP;
END;
/

COMMIT;

DECLARE
  l_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_cnt
    FROM fnd_request_group_units u,
         fnd_responsibility_vl   r,
         fnd_concurrent_programs p
   WHERE r.responsibility_name = 'ASI Invoice DOA Access'
     AND u.request_group_id    = r.request_group_id
     AND u.application_id      = r.group_application_id
     AND u.request_unit_type   = 'P'
     AND p.concurrent_program_id = u.request_unit_id
     AND p.concurrent_program_name LIKE 'ASIFDOA%';
  DBMS_OUTPUT.PUT_LINE('VERIFY - ASIFDOA% programs in DOA responsibility group (expect 5): '||l_cnt);
END;
/
