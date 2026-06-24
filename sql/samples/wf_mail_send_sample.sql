--------------------------------------------------------------------------------
-- Sample: sending e-mail via WF_MAIL.SEND  (Oracle Workflow, EBS R12.2.x)
--------------------------------------------------------------------------------
-- WHAT WF_MAIL.SEND ACTUALLY DOES
--   WF_MAIL is an INTERNAL package used by the Workflow Notification Mailer.
--   WF_MAIL.SEND takes an EXISTING notification id (nid) and hands that
--   notification's e-mail to the mailer -- it is NOT a "send arbitrary text"
--   call. So you always need a notification first (sections 1-2 below).
--
-- PREREQUISITES
--   * The Workflow Notification Mailer service component must be configured and
--     running (its Outbound Server is the SMTP relay that actually sends).
--   * WF_MAIL is internal/undocumented; confirm its real signature (section 0).
--   * Run connected as APPS. If you hit role/context errors, initialise an apps
--     context first (section 3).
--
-- SUPPORTED ALTERNATIVE
--   The supported public API is WF_NOTIFICATION.SEND (section 4): it creates a
--   notification and the mailer e-mails it automatically -- usually you do NOT
--   need to call WF_MAIL.SEND yourself at all.
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- (0) Confirm the real signature / overloads of WF_MAIL.SEND in THIS instance
--------------------------------------------------------------------------------
SELECT overload,
       position,
       argument_name,
       data_type,
       in_out,
       defaulted
  FROM all_arguments
 WHERE owner        = 'APPS'
   AND package_name = 'WF_MAIL'
   AND object_name  = 'SEND'
 ORDER BY overload NULLS FIRST, position;

-- Typical signature (confirm against the output above):
--   WF_MAIL.SEND(nid    IN NUMBER,
--                role   IN VARCHAR2 DEFAULT NULL,
--                node   IN VARCHAR2 DEFAULT NULL,
--                mailto IN VARCHAR2 DEFAULT NULL);


--------------------------------------------------------------------------------
-- (1) Find an existing notification id (nid) to send / re-send
--------------------------------------------------------------------------------
-- mail_status: MAIL = queued for mailing, SENT = already mailed, NULL = no mail.
SELECT notification_id,
       recipient_role,
       subject,
       status,            -- OPEN / CLOSED / CANCELED
       mail_status,
       begin_date
  FROM wf_notifications
 WHERE status = 'OPEN'
 ORDER BY begin_date DESC
 FETCH FIRST 10 ROWS ONLY;


--------------------------------------------------------------------------------
-- (2) Send / re-send the e-mail for an existing notification via WF_MAIL.SEND
--------------------------------------------------------------------------------
-- The core call you asked for. Emails notification :l_nid to its recipient role.
DECLARE
   l_nid NUMBER := &notification_id;     -- paste an id from section (1)
BEGIN
   wf_mail.send(nid => l_nid);
   COMMIT;
   dbms_output.put_line('WF_MAIL.SEND issued for nid ' || l_nid);
END;
/

-- Override the target role and/or destination address (e.g. resend to a person):
DECLARE
   l_nid NUMBER := &notification_id;
BEGIN
   wf_mail.send(nid    => l_nid,
                role   => 'SYSADMIN',                 -- WF role / FND user
                mailto => 'jane.doe@example.com');    -- explicit recipient
   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      dbms_output.put_line('WF_MAIL.SEND failed: ' || sqlerrm);
      RAISE;
END;
/


--------------------------------------------------------------------------------
-- (3) (Optional) initialise an apps context if you get role/security errors
--------------------------------------------------------------------------------
-- Find ids for a responsibility that can run Workflow (e.g. System Administrator):
--   SELECT fu.user_id, fr.responsibility_id, fr.application_id, fr.responsibility_name
--     FROM fnd_user fu, fnd_responsibility_tl fr
--    WHERE fu.user_name = 'SYSADMIN'
--      AND fr.responsibility_name = 'System Administrator';
--
-- BEGIN
--    fnd_global.apps_initialize(user_id      => 0,        -- SYSADMIN
--                               resp_id      => 20420,    -- from query above
--                               resp_appl_id => 1);
-- END;
-- /


--------------------------------------------------------------------------------
-- (4) RECOMMENDED supported path: WF_NOTIFICATION.SEND (mailer e-mails it)
--------------------------------------------------------------------------------
-- Creates a notification from a message DEFINED in the Workflow dictionary; the
-- running Notification Mailer then sends the e-mail automatically. Replace the
-- item type / message with one that exists in your instance (or a custom one
-- built in Workflow Builder with &SUBJECT / &BODY attributes).
DECLARE
   l_nid NUMBER;
BEGIN
   l_nid := wf_notification.send(
               role     => 'SYSADMIN',          -- recipient WF role
               msg_type => 'XXCUST',            -- your item type
               msg_name => 'XX_ADHOC_EMAIL');   -- your message

   -- Populate message attributes the message template references, e.g.:
   -- wf_notification.setattrtext(l_nid, 'SUBJECT', 'Hello from Workflow');
   -- wf_notification.setattrtext(l_nid, 'BODY',    'This was sent via the mailer.');

   COMMIT;   -- the mailer picks it up (mail_status = MAIL) and sends it
   dbms_output.put_line('Notification created, nid = ' || l_nid);
END;
/
