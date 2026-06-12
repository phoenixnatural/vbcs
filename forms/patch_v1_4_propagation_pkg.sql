/*=====================================================
    Copyright (C) Airtel Africa Plc
    All Rights Reserved
  =====================================================
-- Module Name        : Oracle Foundation
-- File Name          : patch_v1_4_propagation_pkg.sql (body-only patch over 06_ASI_FDOA_PROPAGATION_PKG.pkb)
-- Procedure/Function : Package Body
-- Purpose            : Implementation of routines declared in
--                      ASI_FDOA_PROPAGATION_PKG spec.
--
-- Modification Log
-- Author             Date          Version    Reason
-- ------             ----------    -------    ------
-- Oracle Apps Tech   14-MAY-2026   1.0        CR# 2026-02-0585 - Initial
-- Oracle Apps Tech   12-JUN-2026   1.4        O1 closure: QP update re-targeted to
--                                             QA_RESULTS base table (plan_id filtered;
--                                             view NUMBER cols are TO_NUMBER expressions,
--                                             not updatable - ORA-01733/01779); paired
--                                             approver-name column sync (lookup TAG);
--                                             mark_processed moved out of PR/PO steps
--                                             into QP step so PO/QP see unprocessed rows
--
-- Notes:
--   - All updates wrapped in per-employee SAVEPOINTs so that
--     a single failed row does not abort the batch (SOP-FND-ERP201 sec.10).
--   - QP update is a no-op until O1 closes (no rows in the
--     approver-columns manifest lookup).
  =====================================================*/

CREATE OR REPLACE PACKAGE BODY APPS.ASI_FDOA_PROPAGATION_PKG
AS

  ----------------------------------------------------------------
  -- Private: cursor over unprocessed replacements eligible today
  ----------------------------------------------------------------
  CURSOR c_due
  ( cp_run_date          DATE
  , cp_specific_person   NUMBER
  ) IS
    SELECT replacement_id
         , doc_type
         , old_person_id
         , new_person_id
         , effective_from_date
         , org_id
      FROM apps.asi_fdoa_replacement_hdr_tbl
     WHERE processed_flag        = 'N'
       AND effective_from_date  <= TRUNC(cp_run_date)
       AND ( cp_specific_person IS NULL OR old_person_id = cp_specific_person );

  ----------------------------------------------------------------
  -- Private: mark a header row processed (autonomous)
  ----------------------------------------------------------------
  PROCEDURE mark_processed
  ( p_replacement_id IN NUMBER
  , p_action_tag     IN VARCHAR2
  )
  IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_user NUMBER := NVL(apps.fnd_global.user_id,-1);
  BEGIN
    UPDATE apps.asi_fdoa_replacement_hdr_tbl
       SET processed_flag    = 'Y'
         , processed_date    = SYSDATE
         , last_update_date  = SYSDATE
         , last_updated_by   = l_user
     WHERE replacement_id    = p_replacement_id;

    apps.asi_fdoa_replacement_pkg.ADD_AUDIT_DTL
      ( p_replacement_id      => p_replacement_id
      , p_action_type         => p_action_tag
      , p_action_by_person_id => -1
      , p_processed_flag      => 'Y' );

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN ROLLBACK; RAISE;
  END mark_processed;

  ----------------------------------------------------------------
  -- Private: record per-row error in DTL without aborting batch
  ----------------------------------------------------------------
  PROCEDURE log_row_error
  ( p_replacement_id IN NUMBER
  , p_action_tag     IN VARCHAR2
  , p_err            IN VARCHAR2
  )
  IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    apps.asi_fdoa_replacement_pkg.ADD_AUDIT_DTL
      ( p_replacement_id      => p_replacement_id
      , p_action_type         => p_action_tag
      , p_action_by_person_id => -1
      , p_processed_flag      => 'N'
      , p_error_msg           => SUBSTR(p_err, 1, 4000) );
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN ROLLBACK;
  END log_row_error;

  ----------------------------------------------------------------
  -- UPDATE_PR_REQUESTOR
  ----------------------------------------------------------------
  PROCEDURE UPDATE_PR_REQUESTOR
  ( p_run_id             IN  NUMBER
  , p_run_date           IN  DATE
  , p_specific_person_id IN  NUMBER  DEFAULT NULL
  , p_debug_flag         IN  VARCHAR2 DEFAULT 'N'
  , x_records_read       OUT NUMBER
  , x_records_updated    OUT NUMBER
  , x_errors             OUT NUMBER
  )
  IS
    l_rows NUMBER;
    l_user NUMBER := NVL(apps.fnd_global.user_id,-1);
  BEGIN
    x_records_read    := 0;
    x_records_updated := 0;
    x_errors          := 0;

    FOR r IN c_due(p_run_date, p_specific_person_id) LOOP
      x_records_read := x_records_read + 1;
      SAVEPOINT sp_pr;
      BEGIN
        UPDATE apps.po_requisition_lines_all prl
           SET to_person_id     = r.new_person_id
             , last_updated_by  = l_user
             , last_update_date = SYSDATE
             , last_update_login = NVL(apps.fnd_global.login_id,-1)
         WHERE prl.to_person_id = r.old_person_id
           AND prl.requisition_line_id IN
                 ( SELECT req_line_id
                     FROM apps.asi_fdoa_open_pr_lines_v );

        l_rows := SQL%ROWCOUNT;
        x_records_updated := x_records_updated + l_rows;

        REASSIGN_OPEN_NOTIFICATIONS(r.old_person_id, r.new_person_id, l_rows);
        -- v1.4: row is marked processed in UPDATE_QP_APPROVER (final step)

        apps.asi_fdoa_util_pkg.LOG_MSG(
           p_run_id => p_run_id, p_program => 'ASIFDOAPRPO'
         , p_severity => apps.asi_fdoa_util_pkg.gc_sev_debug
         , p_message => 'PR updated rows=' || l_rows
                    || ' replacement_id=' || r.replacement_id
         , p_debug_flag => p_debug_flag);
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK TO sp_pr;
          x_errors := x_errors + 1;
          log_row_error(r.replacement_id, 'PROCESS_ERR', 'PR: ' || SQLERRM);
          apps.asi_fdoa_util_pkg.LOG_MSG(
             p_run_id => p_run_id, p_program => 'ASIFDOAPRPO'
           , p_severity => apps.asi_fdoa_util_pkg.gc_sev_error
           , p_message => 'PR error replacement_id=' || r.replacement_id || ' ' || SQLERRM);
      END;
    END LOOP;
  END UPDATE_PR_REQUESTOR;

  ----------------------------------------------------------------
  -- UPDATE_PO_REQUESTOR
  ----------------------------------------------------------------
  PROCEDURE UPDATE_PO_REQUESTOR
  ( p_run_id             IN  NUMBER
  , p_run_date           IN  DATE
  , p_specific_person_id IN  NUMBER  DEFAULT NULL
  , p_debug_flag         IN  VARCHAR2 DEFAULT 'N'
  , x_records_read       OUT NUMBER
  , x_records_updated    OUT NUMBER
  , x_errors             OUT NUMBER
  )
  IS
    l_rows  NUMBER;
    l_user  NUMBER := NVL(apps.fnd_global.user_id,-1);
  BEGIN
    x_records_read    := 0;
    x_records_updated := 0;
    x_errors          := 0;

    FOR r IN c_due(p_run_date, p_specific_person_id) LOOP
      x_records_read := x_records_read + 1;
      SAVEPOINT sp_po;
      BEGIN
        -- Standard PO -- requester (deliver-to) at distribution level
        UPDATE apps.po_distributions_all pod
           SET deliver_to_person_id = r.new_person_id
             , last_updated_by  = l_user
             , last_update_date = SYSDATE
             , last_update_login = NVL(apps.fnd_global.login_id,-1)
         WHERE pod.deliver_to_person_id = r.old_person_id
           AND pod.po_distribution_id IN
                 ( SELECT po_distribution_id
                     FROM apps.asi_fdoa_open_po_lines_v
                    WHERE po_type = 'STANDARD'
                      AND po_distribution_id IS NOT NULL );
        l_rows := SQL%ROWCOUNT;

        -- BPA -- buyer/agent at header
        UPDATE apps.po_headers_all poh
           SET agent_id         = r.new_person_id
             , last_updated_by  = l_user
             , last_update_date = SYSDATE
             , last_update_login = NVL(apps.fnd_global.login_id,-1)
         WHERE poh.agent_id     = r.old_person_id
           AND poh.po_header_id IN
                 ( SELECT po_header_id
                     FROM apps.asi_fdoa_open_po_lines_v
                    WHERE po_type = 'BLANKET' );
        l_rows := l_rows + SQL%ROWCOUNT;

        x_records_updated := x_records_updated + l_rows;
        REASSIGN_OPEN_NOTIFICATIONS(r.old_person_id, r.new_person_id, l_rows);
        -- v1.4: row is marked processed in UPDATE_QP_APPROVER (final step)
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK TO sp_po;
          x_errors := x_errors + 1;
          log_row_error(r.replacement_id, 'PROCESS_ERR', 'PO: ' || SQLERRM);
          apps.asi_fdoa_util_pkg.LOG_MSG(
             p_run_id => p_run_id, p_program => 'ASIFDOAPRPO'
           , p_severity => apps.asi_fdoa_util_pkg.gc_sev_error
           , p_message => 'PO error replacement_id=' || r.replacement_id || ' ' || SQLERRM);
      END;
    END LOOP;
  END UPDATE_PO_REQUESTOR;

  ----------------------------------------------------------------
  -- UPDATE_QP_APPROVER  (dynamic by manifest)
  ----------------------------------------------------------------
  PROCEDURE UPDATE_QP_APPROVER
  ( p_run_id             IN  NUMBER
  , p_run_date           IN  DATE
  , p_specific_person_id IN  NUMBER  DEFAULT NULL
  , p_debug_flag         IN  VARCHAR2 DEFAULT 'N'
  , x_records_read       OUT NUMBER
  , x_records_updated    OUT NUMBER
  , x_errors             OUT NUMBER
  )
  IS
    l_rows         NUMBER;
    l_total_cols   NUMBER := 0;
    l_plan_id      NUMBER;
    l_new_name     apps.per_all_people_f.full_name%TYPE;
    -- v1.4: QP rows live in QA_RESULTS; the generated results view exposes the
    -- approver columns as TO_NUMBER expressions (not updatable). Update the
    -- base table directly, filtered by plan_id of the named collection plan.
    c_plan_name    CONSTANT apps.qa_plans.name%TYPE := 'AIRTEL AP CSS DOA MAPPING';
  BEGIN
    x_records_read    := 0;
    x_records_updated := 0;
    x_errors          := 0;

    -- O1 closed 12-JUN-2026: manifest rows are QA_RESULTS column names
    -- (CHARACTER11/13/15/17/19); TAG carries the paired display-name column.
    SELECT COUNT(*) INTO l_total_cols
      FROM apps.fnd_lookup_values
     WHERE lookup_type  = 'ASI_FDOA_QP_APPROVER_COLS_LK'
       AND language     = USERENV('LANG')
       AND enabled_flag = 'Y';

    IF l_total_cols = 0 THEN
      apps.asi_fdoa_util_pkg.LOG_MSG(
         p_run_id => p_run_id, p_program => 'ASIFDOAQP'
       , p_severity => apps.asi_fdoa_util_pkg.gc_sev_warn
       , p_message => 'QP approver columns manifest empty - skipping QP update'
                   || ' (rows left unprocessed for retry)');
      RETURN;
    END IF;

    BEGIN
      SELECT plan_id INTO l_plan_id
        FROM apps.qa_plans
       WHERE name = c_plan_name;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        apps.asi_fdoa_util_pkg.LOG_MSG(
           p_run_id => p_run_id, p_program => 'ASIFDOAQP'
         , p_severity => apps.asi_fdoa_util_pkg.gc_sev_warn
         , p_message => 'QP collection plan not found: ' || c_plan_name
                     || ' - skipping QP update');
        RETURN;
    END;

    FOR r IN c_due(p_run_date, p_specific_person_id) LOOP
      x_records_read := x_records_read + 1;
      SAVEPOINT sp_qp;
      BEGIN
        BEGIN
          SELECT full_name INTO l_new_name
            FROM apps.per_all_people_f
           WHERE person_id = r.new_person_id
             AND TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date
             AND ROWNUM = 1;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN l_new_name := NULL;
        END;

        FOR col_rec IN ( SELECT lookup_code AS col_name
                              , tag         AS name_col
                           FROM apps.fnd_lookup_values
                          WHERE lookup_type  = 'ASI_FDOA_QP_APPROVER_COLS_LK'
                            AND language     = USERENV('LANG')
                            AND enabled_flag = 'Y' )
        LOOP
          IF col_rec.name_col IS NOT NULL AND l_new_name IS NOT NULL THEN
            EXECUTE IMMEDIATE
                 'UPDATE apps.qa_results '
              || '   SET ' || col_rec.col_name  || ' = :new_pid '
              || '     , ' || col_rec.name_col  || ' = :new_name '
              || '     , last_update_date = SYSDATE '
              || '     , last_updated_by  = :user_id '
              || ' WHERE plan_id = :plan_id '
              || '   AND ' || col_rec.col_name  || ' = :old_pid'
              USING TO_CHAR(r.new_person_id), l_new_name
                  , NVL(apps.fnd_global.user_id,-1)
                  , l_plan_id, TO_CHAR(r.old_person_id);
          ELSE
            EXECUTE IMMEDIATE
                 'UPDATE apps.qa_results '
              || '   SET ' || col_rec.col_name  || ' = :new_pid '
              || '     , last_update_date = SYSDATE '
              || '     , last_updated_by  = :user_id '
              || ' WHERE plan_id = :plan_id '
              || '   AND ' || col_rec.col_name  || ' = :old_pid'
              USING TO_CHAR(r.new_person_id)
                  , NVL(apps.fnd_global.user_id,-1)
                  , l_plan_id, TO_CHAR(r.old_person_id);
          END IF;
          x_records_updated := x_records_updated + SQL%ROWCOUNT;
        END LOOP;

        REASSIGN_OPEN_NOTIFICATIONS(r.old_person_id, r.new_person_id, l_rows);
        -- v1.4: single point of processed-marking (final propagation step)
        mark_processed(r.replacement_id, 'PROCESS_OK');
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK TO sp_qp;
          x_errors := x_errors + 1;
          log_row_error(r.replacement_id, 'PROCESS_ERR', 'QP: ' || SQLERRM);
      END;
    END LOOP;
  END UPDATE_QP_APPROVER;

  ----------------------------------------------------------------
  -- REASSIGN_OPEN_NOTIFICATIONS
  ----------------------------------------------------------------
  PROCEDURE REASSIGN_OPEN_NOTIFICATIONS
  ( p_old_person_id  IN  NUMBER
  , p_new_person_id  IN  NUMBER
  , x_reassigned     OUT NUMBER
  )
  IS
    l_old_user  VARCHAR2(100);
    l_new_user  VARCHAR2(100);
    l_open_cnt  NUMBER := 0;
    -- CR# 2026-02-0585 v1.2: FINUAT discovery (all_arguments) confirmed
    -- APPS.WF_NOTIFICATION.TRANSFER(nid, new_role, forward_comment, ...) exists.
    -- TRANSFER changes ownership of the open notification to the replacement
    -- (correct for an exiting / moved employee; FORWARD would only delegate).
    -- Called dynamically below with 3 binds (nid, new_role, comment); the
    -- remaining args (user, cnt, action_source) default. Reset to NULL to fall
    -- back to the logged no-op if a future instance lacks the API.
    c_reassign_api CONSTANT VARCHAR2(61) := 'WF_NOTIFICATION.TRANSFER';
  BEGIN
    x_reassigned := 0;
    IF p_old_person_id IS NULL OR p_new_person_id IS NULL THEN RETURN; END IF;

    SELECT MAX(user_name) INTO l_old_user
      FROM apps.fnd_user WHERE employee_id = p_old_person_id;
    SELECT MAX(user_name) INTO l_new_user
      FROM apps.fnd_user WHERE employee_id = p_new_person_id;

    IF l_old_user IS NULL OR l_new_user IS NULL THEN RETURN; END IF;

    SELECT COUNT(*) INTO l_open_cnt
      FROM apps.wf_notifications
     WHERE recipient_role = l_old_user AND status = 'OPEN';

    IF c_reassign_api IS NULL THEN
      -- API not yet confirmed for this instance: log and skip (no-op).
      apps.asi_fdoa_util_pkg.LOG_MSG(
         p_program  => 'ASIFDOAPRPO'
       , p_severity => apps.asi_fdoa_util_pkg.gc_sev_warn
       , p_message  => 'WF reassign pending API confirmation - ' || l_open_cnt
                    || ' open notif(s) for ' || l_old_user || ' NOT reassigned');
      RETURN;
    END IF;

    -- API confirmed: invoke dynamically per open notification (best-effort).
    FOR n IN ( SELECT notification_id
                 FROM apps.wf_notifications
                WHERE recipient_role = l_old_user
                  AND status         = 'OPEN' )
    LOOP
      BEGIN
        EXECUTE IMMEDIATE 'BEGIN apps.' || c_reassign_api
                          || '(:nid, :new_role, :cmt); END;'
          USING n.notification_id, l_new_user,
                'CR# 2026-02-0585 - FDOA propagation auto-reassign';
        x_reassigned := x_reassigned + 1;
      EXCEPTION
        WHEN OTHERS THEN NULL;          -- per-notif failure must not abort
      END;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      x_reassigned := 0;
  END REASSIGN_OPEN_NOTIFICATIONS;

  ----------------------------------------------------------------
  -- ENSURE_AUTO_DEFAULTS
  ----------------------------------------------------------------
  PROCEDURE ENSURE_AUTO_DEFAULTS
  ( p_run_id     IN  NUMBER
  , p_run_date   IN  DATE
  , p_org_id     IN  NUMBER   DEFAULT NULL
  , x_inserted   OUT NUMBER
  )
  IS
    l_id   NUMBER;
    l_cnt  NUMBER := 0;
  BEGIN
    x_inserted := 0;

    -- EXIT: cut-off = actual_term_date; no replacement row yet
    FOR r IN ( SELECT v.person_id, v.actual_termination_date AS key_date
                 FROM apps.asi_fdoa_exit_employees_v v
                WHERE TRUNC(v.actual_termination_date) <= TRUNC(p_run_date)
                  AND NOT EXISTS ( SELECT 1
                                     FROM apps.asi_fdoa_replacement_hdr_tbl h
                                    WHERE h.doc_type      = 'EXIT'
                                      AND h.old_person_id = v.person_id ) )
    LOOP
      BEGIN
        apps.asi_fdoa_replacement_pkg.AUTO_DEFAULT_RM(
            p_doc_type        => 'EXIT'
          , p_old_person_id   => r.person_id
          , p_key_date        => r.key_date
          , p_org_id          => p_org_id
          , x_replacement_id  => l_id);
        l_cnt := l_cnt + 1;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          apps.asi_fdoa_util_pkg.LOG_MSG(
             p_run_id => p_run_id, p_program => 'ASIFDOAPRPO'
           , p_severity => apps.asi_fdoa_util_pkg.gc_sev_error
           , p_message => 'AUTO_DEFAULT_RM EXIT failed person_id=' || r.person_id || ' ' || SQLERRM);
      END;
    END LOOP;

    -- MOVEMENT: cut-off = effective_date + 16
    FOR r IN ( SELECT v.person_id, v.effective_date AS key_date
                 FROM apps.asi_fdoa_movement_emp_v v
                WHERE TRUNC(p_run_date) >= TRUNC(v.effective_date) + 16
                  AND NOT EXISTS ( SELECT 1
                                     FROM apps.asi_fdoa_replacement_hdr_tbl h
                                    WHERE h.doc_type      = 'MOVEMENT'
                                      AND h.old_person_id = v.person_id ) )
    LOOP
      BEGIN
        apps.asi_fdoa_replacement_pkg.AUTO_DEFAULT_RM(
            p_doc_type        => 'MOVEMENT'
          , p_old_person_id   => r.person_id
          , p_key_date        => r.key_date
          , p_org_id          => p_org_id
          , x_replacement_id  => l_id);
        l_cnt := l_cnt + 1;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          apps.asi_fdoa_util_pkg.LOG_MSG(
             p_run_id => p_run_id, p_program => 'ASIFDOAPRPO'
           , p_severity => apps.asi_fdoa_util_pkg.gc_sev_error
           , p_message => 'AUTO_DEFAULT_RM MOVEMENT failed person_id=' || r.person_id || ' ' || SQLERRM);
      END;
    END LOOP;

    x_inserted := l_cnt;
  END ENSURE_AUTO_DEFAULTS;

  ----------------------------------------------------------------
  -- RUN_ALL  (CP entry point)
  ----------------------------------------------------------------
  PROCEDURE RUN_ALL
  ( errbuf       OUT VARCHAR2
  , retcode      OUT VARCHAR2
  , p_run_date   IN  VARCHAR2 DEFAULT NULL
  , p_person_id  IN  NUMBER   DEFAULT NULL
  , p_debug_flag IN  VARCHAR2 DEFAULT 'N'
  )
  IS
    l_run_id    NUMBER;
    l_run_date  DATE;
    l_switch    VARCHAR2(20);
    l_auto      NUMBER := 0;
    l_pr_read   NUMBER := 0;  l_pr_upd  NUMBER := 0;  l_pr_err  NUMBER := 0;
    l_po_read   NUMBER := 0;  l_po_upd  NUMBER := 0;  l_po_err  NUMBER := 0;
    l_qp_read   NUMBER := 0;  l_qp_upd  NUMBER := 0;  l_qp_err  NUMBER := 0;
    l_total_err NUMBER;
    l_status    VARCHAR2(20);
  BEGIN
    l_run_date := NVL(TO_DATE(p_run_date,'DD-MON-YYYY'), TRUNC(SYSDATE));
    l_run_id   := apps.asi_fdoa_util_pkg.OPEN_RUN_LOG('ASIFDOAPRPO', p_debug_flag);
    l_switch   := apps.asi_fdoa_util_pkg.GET_INTEG_SWITCH;

    apps.asi_fdoa_util_pkg.LOG_MSG(
       p_run_id => l_run_id, p_program => 'ASIFDOAPRPO'
     , p_severity => apps.asi_fdoa_util_pkg.gc_sev_info
     , p_message => 'RUN_ALL start run_date=' || TO_CHAR(l_run_date,'YYYY-MM-DD')
                || ' switch=' || l_switch);

    IF l_switch = apps.asi_fdoa_util_pkg.gc_switch_off THEN
      apps.asi_fdoa_util_pkg.CLOSE_RUN_LOG(
          l_run_id, 'ASIFDOAPRPO', apps.asi_fdoa_util_pkg.gc_status_warning
        , 'Integration switch OFF', NULL);
      errbuf  := 'Integration switch OFF';
      retcode := '1';
      RETURN;
    END IF;

    ENSURE_AUTO_DEFAULTS(l_run_id, l_run_date, NULL, l_auto);
    UPDATE_PR_REQUESTOR(l_run_id, l_run_date, p_person_id, p_debug_flag, l_pr_read, l_pr_upd, l_pr_err);
    UPDATE_PO_REQUESTOR(l_run_id, l_run_date, p_person_id, p_debug_flag, l_po_read, l_po_upd, l_po_err);
    UPDATE_QP_APPROVER (l_run_id, l_run_date, p_person_id, p_debug_flag, l_qp_read, l_qp_upd, l_qp_err);

    l_total_err := l_pr_err + l_po_err + l_qp_err;
    l_status := CASE WHEN l_total_err = 0 THEN apps.asi_fdoa_util_pkg.gc_status_success
                     ELSE apps.asi_fdoa_util_pkg.gc_status_warning END;

    apps.asi_fdoa_util_pkg.CLOSE_RUN_LOG(
        l_run_id, 'ASIFDOAPRPO', l_status, NULL
      , (l_pr_read + l_po_read + l_qp_read) || '|'
        || (l_pr_upd + l_po_upd + l_qp_upd) || '|'
        || (l_pr_upd + l_po_upd + l_qp_upd) || '||' || l_total_err);

    errbuf  := 'AUTO_DEFAULTS=' || l_auto
            || ' PR(read/upd/err)=' || l_pr_read || '/' || l_pr_upd || '/' || l_pr_err
            || ' PO=' || l_po_read || '/' || l_po_upd || '/' || l_po_err
            || ' QP=' || l_qp_read || '/' || l_qp_upd || '/' || l_qp_err;
    retcode := CASE WHEN l_total_err = 0 THEN '0' ELSE '1' END;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := SUBSTR(SQLERRM,1,240);
      retcode := '2';
      apps.asi_fdoa_util_pkg.LOG_MSG(
         p_run_id => l_run_id, p_program => 'ASIFDOAPRPO'
       , p_severity => apps.asi_fdoa_util_pkg.gc_sev_error
       , p_message => 'RUN_ALL fatal: ' || SQLERRM);
      IF l_run_id IS NOT NULL THEN
        apps.asi_fdoa_util_pkg.CLOSE_RUN_LOG(
            l_run_id, 'ASIFDOAPRPO', apps.asi_fdoa_util_pkg.gc_status_error
          , SUBSTR(SQLERRM,1,4000), NULL);
      END IF;
  END RUN_ALL;

END ASI_FDOA_PROPAGATION_PKG;
/

SHOW ERRORS;
-- End of file
