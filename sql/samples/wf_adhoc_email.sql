--------------------------------------------------------------------------------
-- Sample: ad-hoc e-mail via Oracle Workflow  (EBS R12.2.x)
--------------------------------------------------------------------------------
-- Sends a free-form subject/body e-mail through the Notification Mailer using the
-- custom XXADHOC / XX_ADHOC_MSG message.
--
-- PREREQUISITES
--   1. Create the XXADHOC item type + XX_ADHOC_MSG message once:
--        see docs/wf_adhoc_email_setup.md
--   2. The Workflow Notification Mailer must be configured and running.
--   3. Run connected as APPS.
--
-- HOW IT WORKS
--   WF_NOTIFICATION.SEND creates a notification from the message and returns its
--   nid. We set the SUBJECT / BODY / HTMLBODY send-attributes, COMMIT, and the
--   mailer e-mails it asynchronously. WF_MAIL.SEND(nid) optionally forces it out
--   immediately instead of waiting for the next mailer cycle.
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON


--------------------------------------------------------------------------------
-- (A) Send to an existing Workflow role / FND user (e.g. SYSADMIN)
--------------------------------------------------------------------------------
-- The role must have an e-mail address and a mail notification preference.
DECLARE
   l_nid NUMBER;
BEGIN
   l_nid := wf_notification.send(
               role     => 'SYSADMIN',          -- existing WF_ROLES role
               msg_type => 'XXADHOC',
               msg_name => 'XX_ADHOC_MSG');

   wf_notification.setattrtext(l_nid, 'SUBJECT',  'EBS test e-mail (existing role)');
   wf_notification.setattrtext(l_nid, 'BODY',     'Sent via the Notification Mailer from XX_ADHOC_MSG.');
   wf_notification.setattrtext(l_nid, 'HTMLBODY', '<p>Sent via the <b>Notification Mailer</b> from XX_ADHOC_MSG.</p>');

   COMMIT;   -- mailer now picks it up (mail_status = MAIL)
   dbms_output.put_line('Notification sent to SYSADMIN, nid = ' || l_nid);

   -- Optional: push it out now instead of waiting for the mailer cycle.
   -- wf_mail.send(nid => l_nid);
   -- COMMIT;
END;
/


--------------------------------------------------------------------------------
-- (B) Send to an ARBITRARY external e-mail address (ad-hoc user/role)
--------------------------------------------------------------------------------
-- WF only mails to roles, so for a one-off address we first create an ad-hoc user
-- (a transient WF role) carrying that address + a mail preference, then notify it.
DECLARE
   l_user    VARCHAR2(320);
   l_display VARCHAR2(360) := 'Jane Doe (ad hoc)';
   l_nid     NUMBER;
BEGIN
   -- name is IN OUT: pass NULL and Workflow returns a generated unique role name.
   l_user := NULL;
   wf_directory.createadhocuser(
      name                    => l_user,
      display_name            => l_display,
      notification_preference => 'MAILHTML',                 -- MAILTEXT for plain
      email_address           => 'jane.doe@example.com');    -- <-- target address

   l_nid := wf_notification.send(
               role     => l_user,
               msg_type => 'XXADHOC',
               msg_name => 'XX_ADHOC_MSG');

   wf_notification.setattrtext(l_nid, 'SUBJECT',  'EBS test e-mail (ad-hoc recipient)');
   wf_notification.setattrtext(l_nid, 'BODY',     'This went to an arbitrary address via an ad-hoc WF user.');
   wf_notification.setattrtext(l_nid, 'HTMLBODY', '<p>This went to an arbitrary address via an <b>ad-hoc WF user</b>.</p>');

   COMMIT;
   dbms_output.put_line('Ad-hoc user ' || l_user || ' created; notification nid = ' || l_nid);

   -- Optional immediate push:
   -- wf_mail.send(nid => l_nid);
   -- COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      dbms_output.put_line('Ad-hoc send failed: ' || sqlerrm);
      RAISE;
END;
/


--------------------------------------------------------------------------------
-- (C) Check delivery status
--------------------------------------------------------------------------------
-- mail_status: MAIL = queued, SENT = mailer has sent it, NULL = not for mail.
SELECT notification_id, recipient_role, subject, status, mail_status, begin_date
  FROM wf_notifications
 WHERE message_type = 'XXADHOC'
 ORDER BY begin_date DESC
 FETCH FIRST 20 ROWS ONLY;
