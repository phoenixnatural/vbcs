--------------------------------------------------------------------------------
-- FND_EMAIL  -  custom e-mail utility for Oracle E-Business Suite R12.2.x
--------------------------------------------------------------------------------
-- NOTE: FND_EMAIL is NOT a seeded EBS object. EBS itself sends mail through the
--       Workflow Notification Mailer (WF_NOTIFICATION / wf_mail_util). This is a
--       lightweight custom wrapper over UTL_SMTP so application/PL-SQL code can
--       send ad-hoc e-mail with a simple FND_EMAIL.SEND(...) call.
--
-- Install as:  APPS   (run from SQL*Plus connected to the APPS schema)
-- Requires  :  EXECUTE on UTL_SMTP, UTL_TCP  (APPS already has these)
--              A network ACL allowing APPS -> SMTP host:port
--              (see fnd_email_network_acl.sql -- mandatory on 12c/19c DB)
--
-- R12.2 online patching note: this is a custom object. Per Oracle's EBS
-- customization standards the preferred home is a CUSTOM schema (e.g. XXEN)
-- with a grant + synonym into APPS, created via an ADOP patch cycle. Creating
-- directly in APPS (below) is the quick path and is fine for a utility, but do
-- it during downtime / a patch edition, not blindly on a live run edition.
--------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE fnd_email AS

   -- Returns the SMTP host configured for the Workflow Notification Mailer,
   -- so callers don't have to hard-code it. NULL if it can't be determined.
   FUNCTION get_outbound_server RETURN VARCHAR2;

   -- Send an e-mail.
   --   p_to / p_cc / p_bcc  : one or more addresses, separated by ',' or ';'
   --   p_body               : plain-text body (always include one for HTML mail too)
   --   p_body_html          : optional HTML body -> sends multipart/alternative
   --   p_smtp_host          : override; NULL = look up the Workflow Mailer server
   PROCEDURE send(
      p_from      IN VARCHAR2,
      p_to        IN VARCHAR2,
      p_subject   IN VARCHAR2,
      p_body      IN CLOB,
      p_cc        IN VARCHAR2    DEFAULT NULL,
      p_bcc       IN VARCHAR2    DEFAULT NULL,
      p_body_html IN CLOB        DEFAULT NULL,
      p_smtp_host IN VARCHAR2    DEFAULT NULL,
      p_smtp_port IN PLS_INTEGER DEFAULT 25
   );

END fnd_email;
/
SHOW ERRORS PACKAGE fnd_email


CREATE OR REPLACE PACKAGE BODY fnd_email AS

   g_charset CONSTANT VARCHAR2(30) := 'UTF-8';
   crlf      CONSTANT VARCHAR2(2)  := utl_tcp.crlf;          -- CHR(13)||CHR(10)

   ----------------------------------------------------------------------------
   -- Extract the bare address-spec (a@b.com) from a header value that may be
   -- "Display Name <a@b.com>".  Used for the SMTP envelope (MAIL/RCPT).
   ----------------------------------------------------------------------------
   FUNCTION addr_spec(p_addr IN VARCHAR2) RETURN VARCHAR2 IS
      l_addr VARCHAR2(4000) := TRIM(p_addr);
   BEGIN
      IF INSTR(l_addr, '<') > 0 THEN
         l_addr := TRIM(SUBSTR(l_addr,
                               INSTR(l_addr, '<') + 1,
                               INSTR(l_addr, '>') - INSTR(l_addr, '<') - 1));
      END IF;
      RETURN l_addr;
   END addr_spec;

   ----------------------------------------------------------------------------
   FUNCTION get_outbound_server RETURN VARCHAR2 IS
      l_server VARCHAR2(4000);
   BEGIN
      -- Outbound SMTP server name from the Workflow Notification Mailer config.
      SELECT MAX(pv.parameter_value)
        INTO l_server
        FROM fnd_svc_components       sc,
             fnd_svc_comp_params_b    pb,
             fnd_svc_comp_param_vals  pv
       WHERE sc.component_type = 'WF_MAILER'
         AND pv.component_id   = sc.component_id
         AND pb.parameter_id   = pv.parameter_id
         AND pb.parameter_name = 'OUTBOUND_SERVER';

      -- Value can be 'host' or 'host:port:...'; keep just the host portion.
      IF l_server IS NOT NULL AND INSTR(l_server, ':') > 0 THEN
         l_server := SUBSTR(l_server, 1, INSTR(l_server, ':') - 1);
      END IF;

      RETURN l_server;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END get_outbound_server;

   ----------------------------------------------------------------------------
   -- Add every address in a ','/';'-separated list to the SMTP envelope.
   ----------------------------------------------------------------------------
   PROCEDURE add_recipients(p_conn IN OUT NOCOPY utl_smtp.connection,
                            p_addr IN            VARCHAR2) IS
      l_list VARCHAR2(32767);
      l_one  VARCHAR2(4000);
      l_pos  PLS_INTEGER;
   BEGIN
      IF p_addr IS NULL THEN
         RETURN;
      END IF;

      l_list := REPLACE(p_addr, ';', ',') || ',';   -- trailing comma => simple loop
      LOOP
         l_pos := INSTR(l_list, ',');
         EXIT WHEN l_pos = 0;
         l_one  := addr_spec(SUBSTR(l_list, 1, l_pos - 1));
         IF l_one IS NOT NULL THEN
            utl_smtp.rcpt(p_conn, l_one);
         END IF;
         l_list := SUBSTR(l_list, l_pos + 1);
      END LOOP;
   END add_recipients;

   ----------------------------------------------------------------------------
   -- Stream a CLOB to the open DATA section in chunks (handles large bodies).
   ----------------------------------------------------------------------------
   PROCEDURE write_clob(p_conn IN OUT NOCOPY utl_smtp.connection,
                        p_clob IN            CLOB) IS
      l_len    PLS_INTEGER;
      l_offset PLS_INTEGER := 1;
      l_chunk  CONSTANT PLS_INTEGER := 1900;
   BEGIN
      IF p_clob IS NULL THEN
         RETURN;
      END IF;
      l_len := dbms_lob.getlength(p_clob);
      WHILE l_offset <= l_len LOOP
         utl_smtp.write_data(p_conn, dbms_lob.substr(p_clob, l_chunk, l_offset));
         l_offset := l_offset + l_chunk;
      END LOOP;
   END write_clob;

   ----------------------------------------------------------------------------
   PROCEDURE send(
      p_from      IN VARCHAR2,
      p_to        IN VARCHAR2,
      p_subject   IN VARCHAR2,
      p_body      IN CLOB,
      p_cc        IN VARCHAR2    DEFAULT NULL,
      p_bcc       IN VARCHAR2    DEFAULT NULL,
      p_body_html IN CLOB        DEFAULT NULL,
      p_smtp_host IN VARCHAR2    DEFAULT NULL,
      p_smtp_port IN PLS_INTEGER DEFAULT 25
   ) IS
      l_conn     utl_smtp.connection;
      l_host     VARCHAR2(256) := NVL(p_smtp_host, get_outbound_server);
      l_domain   VARCHAR2(256);
      l_boundary CONSTANT VARCHAR2(70) :=
                    '=_fnd_email_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISSFF3');
   BEGIN
      IF p_from IS NULL OR p_to IS NULL THEN
         raise_application_error(-20802, 'FND_EMAIL.SEND: p_from and p_to are required.');
      END IF;
      IF l_host IS NULL THEN
         raise_application_error(-20801,
            'FND_EMAIL.SEND: no SMTP host. Pass p_smtp_host or configure the '
            || 'Workflow Notification Mailer Outbound Server.');
      END IF;

      l_domain := SUBSTR(p_from, INSTR(p_from, '@') + 1);

      -- ----- SMTP envelope ----------------------------------------------------
      l_conn := utl_smtp.open_connection(l_host, p_smtp_port);
      utl_smtp.helo(l_conn, NVL(l_domain, l_host));
      utl_smtp.mail(l_conn, addr_spec(p_from));
      add_recipients(l_conn, p_to);
      add_recipients(l_conn, p_cc);
      add_recipients(l_conn, p_bcc);     -- Bcc: envelope only, no header

      -- ----- DATA: headers ----------------------------------------------------
      utl_smtp.open_data(l_conn);
      utl_smtp.write_data(l_conn,
         'Date: ' || TO_CHAR(SYSTIMESTAMP,
                             'Dy, DD Mon YYYY HH24:MI:SS TZHTZM',
                             'NLS_DATE_LANGUAGE=AMERICAN') || crlf);
      utl_smtp.write_data(l_conn, 'From: '    || p_from    || crlf);
      utl_smtp.write_data(l_conn, 'To: '      || p_to      || crlf);
      IF p_cc IS NOT NULL THEN
         utl_smtp.write_data(l_conn, 'Cc: '   || p_cc      || crlf);
      END IF;
      utl_smtp.write_data(l_conn, 'Subject: ' || p_subject || crlf);
      utl_smtp.write_data(l_conn, 'MIME-Version: 1.0' || crlf);

      -- ----- DATA: body -------------------------------------------------------
      IF p_body_html IS NULL THEN
         utl_smtp.write_data(l_conn,
            'Content-Type: text/plain; charset="' || g_charset || '"' || crlf || crlf);
         write_clob(l_conn, p_body);
         utl_smtp.write_data(l_conn, crlf);
      ELSE
         utl_smtp.write_data(l_conn,
            'Content-Type: multipart/alternative; boundary="' || l_boundary || '"'
            || crlf || crlf);

         -- text/plain alternative (fallback for non-HTML clients)
         utl_smtp.write_data(l_conn, '--' || l_boundary || crlf);
         utl_smtp.write_data(l_conn,
            'Content-Type: text/plain; charset="' || g_charset || '"' || crlf || crlf);
         write_clob(l_conn,
            NVL(p_body, TO_CLOB('Please view this message in an HTML-capable client.')));
         utl_smtp.write_data(l_conn, crlf);

         -- text/html alternative
         utl_smtp.write_data(l_conn, '--' || l_boundary || crlf);
         utl_smtp.write_data(l_conn,
            'Content-Type: text/html; charset="' || g_charset || '"' || crlf || crlf);
         write_clob(l_conn, p_body_html);
         utl_smtp.write_data(l_conn, crlf);

         -- closing boundary
         utl_smtp.write_data(l_conn, '--' || l_boundary || '--' || crlf);
      END IF;

      utl_smtp.close_data(l_conn);
      utl_smtp.quit(l_conn);
   EXCEPTION
      WHEN OTHERS THEN
         BEGIN
            utl_smtp.quit(l_conn);     -- best-effort cleanup
         EXCEPTION
            WHEN OTHERS THEN NULL;
         END;
         RAISE;
   END send;

END fnd_email;
/
SHOW ERRORS PACKAGE BODY fnd_email
