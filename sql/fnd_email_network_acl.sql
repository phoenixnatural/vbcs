--------------------------------------------------------------------------------
-- Network ACL for FND_EMAIL  (Oracle DB 12c/19c -- required by EBS R12.2.14)
--------------------------------------------------------------------------------
-- Without this, UTL_SMTP fails with:
--    ORA-24247: network access denied by access control list (ACL)
--
-- Run as a DBA (e.g. SYSTEM / SYS). Grant the APPS schema permission to open a
-- TCP connection to your SMTP host on the mailer port.
--
-- Replace the host/port below with YOUR Workflow Mailer Outbound Server. To find
-- it, run as APPS:   SELECT fnd_email.get_outbound_server FROM dual;
--------------------------------------------------------------------------------

BEGIN
   dbms_network_acl_admin.append_host_ace(
      host       => 'your.smtp.server.com',        -- <-- your SMTP host (or '*' )
      lower_port => 25,
      upper_port => 25,
      ace        => xs$ace_type(
                       privilege_list => xs$name_list('connect', 'resolve'),
                       principal_name => 'APPS',           -- must be UPPERCASE
                       principal_type => xs_acl.ptype_db));
   COMMIT;
END;
/

-- Verify the ACL is in place:
SELECT host, lower_port, upper_port, principal, privilege, status
  FROM dba_host_aces
 WHERE principal = 'APPS'
 ORDER BY host;
