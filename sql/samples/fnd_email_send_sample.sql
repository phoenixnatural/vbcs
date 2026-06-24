--------------------------------------------------------------------------------
-- Sample: calling FND_EMAIL.SEND   (Oracle E-Business Suite R12.2.x)
--------------------------------------------------------------------------------
-- FND_EMAIL is NOT seeded by EBS -- if FND_EMAIL.SEND raises
--   PLS-00201: identifier 'FND_EMAIL.SEND' must be declared
-- the package isn't installed. Install it first:
--   1) sql/fnd_email_pkg.sql          (run as APPS  -- creates the package)
--   2) sql/fnd_email_network_acl.sql  (run as DBA   -- allows APPS -> SMTP host)
--
-- Then run the examples below from SQL*Plus / SQLcl connected as APPS.
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- (0) Confirm the real signature of FND_EMAIL.SEND in THIS database
--------------------------------------------------------------------------------
-- The procedure may be overloaded; this lists every argument of every overload
-- in call order. Match your named parameters to the ARGUMENT_NAME values shown.
SELECT overload,
       position,
       argument_name,
       data_type,
       in_out,
       defaulted
  FROM user_arguments
 WHERE package_name = 'FND_EMAIL'
   AND object_name  = 'SEND'
 ORDER BY overload NULLS FIRST, position;

-- In SQL*Plus / SQLcl you can also just describe it:
--   DESC FND_EMAIL


--------------------------------------------------------------------------------
-- (1) Minimal plain-text send (anonymous block)
--------------------------------------------------------------------------------
-- Uses named parameters so it keeps working even if the package adds optional
-- arguments later. Edit the parameter names if section (0) shows different ones.
BEGIN
   fnd_email.send(
      p_from    => 'no-reply@example.com',
      p_to      => 'jane.doe@example.com',
      p_subject => 'VBCS test message',
      p_body    => 'Hello Jane,' || chr(10) || chr(10) ||
                   'This is a plain-text email sent from the database.' || chr(10) ||
                   'Regards,' || chr(10) ||
                   'VBCS App'
   );

   COMMIT;  -- many FND_EMAIL implementations queue the mail and rely on a commit
   dbms_output.put_line('Email queued/sent OK.');
END;
/


--------------------------------------------------------------------------------
-- (2) Plain-text send with CC / BCC and error handling
--------------------------------------------------------------------------------
DECLARE
   l_to      VARCHAR2(4000) := 'jane.doe@example.com';
   l_cc      VARCHAR2(4000) := 'team-lead@example.com';
   l_bcc     VARCHAR2(4000) := 'audit@example.com';
   l_subject VARCHAR2(400)  := 'Order #' || 10045 || ' confirmed';
   l_body    CLOB;
BEGIN
   l_body := 'Hi Jane,' || chr(10) || chr(10) ||
             'Your order #10045 has been confirmed and will ship shortly.' || chr(10) ||
             'Thank you for your business.';

   fnd_email.send(
      p_from    => 'orders@example.com',
      p_to      => l_to,
      p_cc      => l_cc,
      p_bcc     => l_bcc,
      p_subject => l_subject,
      p_body    => l_body
   );

   COMMIT;
EXCEPTION
   WHEN OTHERS THEN
      ROLLBACK;
      -- Log and re-raise so the caller (e.g. a VBCS Business Rule / REST call) sees it
      dbms_output.put_line('FND_EMAIL.SEND failed: ' || sqlerrm);
      RAISE;
END;
/


--------------------------------------------------------------------------------
-- (3) HTML email (if the package supports an HTML body / mime parameter)
--------------------------------------------------------------------------------
-- Some FND_EMAIL versions expose p_body_html, others a p_mime_type flag.
-- Keep whichever matches section (0); delete the other.
DECLARE
   l_html CLOB;
BEGIN
   l_html := '<html><body>' ||
             '<h2>Welcome aboard</h2>' ||
             '<p>Your account is now <b>active</b>.</p>' ||
             '<p><a href="https://app.example.com">Sign in</a></p>' ||
             '</body></html>';

   -- Variant A: dedicated HTML parameter
   fnd_email.send(
      p_from      => 'no-reply@example.com',
      p_to        => 'jane.doe@example.com',
      p_subject   => 'Welcome',
      p_body      => 'Your account is now active. View this email in HTML.',  -- text fallback
      p_body_html => l_html
   );

   -- Variant B: single body + mime type (uncomment if your signature uses this)
   -- fnd_email.send(
   --    p_from      => 'no-reply@example.com',
   --    p_to        => 'jane.doe@example.com',
   --    p_subject   => 'Welcome',
   --    p_body      => l_html,
   --    p_mime_type => 'text/html'
   -- );

   COMMIT;
END;
/


--------------------------------------------------------------------------------
-- (4) Reusable wrapper procedure
--------------------------------------------------------------------------------
-- Centralizes the FND_EMAIL.SEND call so app code (and VBCS REST endpoints) have
-- one place to change if the underlying signature ever moves. Returns nothing;
-- raises on failure so callers can handle it.
CREATE OR REPLACE PROCEDURE app_send_email(
   p_to      IN VARCHAR2,
   p_subject IN VARCHAR2,
   p_body    IN CLOB,
   p_from    IN VARCHAR2 DEFAULT 'no-reply@example.com',
   p_cc      IN VARCHAR2 DEFAULT NULL,
   p_bcc     IN VARCHAR2 DEFAULT NULL
) AS
BEGIN
   IF p_to IS NULL THEN
      raise_application_error(-20001, 'Recipient (p_to) is required.');
   END IF;

   fnd_email.send(
      p_from    => p_from,
      p_to      => p_to,
      p_cc      => p_cc,
      p_bcc     => p_bcc,
      p_subject => p_subject,
      p_body    => p_body
   );
END app_send_email;
/

-- Example call of the wrapper:
BEGIN
   app_send_email(
      p_to      => 'jane.doe@example.com',
      p_subject => 'Hello from the wrapper',
      p_body    => 'This went through app_send_email -> fnd_email.send.'
   );
   COMMIT;
END;
/
