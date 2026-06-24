# Minimal Workflow item type + message for ad-hoc e-mail (EBS R12.2.x)

`WF_MAIL.SEND` / `WF_NOTIFICATION.SEND` can only send a **notification built from a
message that exists in the Workflow dictionary**. This sets up the smallest such
message — a no-response (FYI) message whose subject and body are supplied by the
caller — so `sql/samples/wf_adhoc_email.sql` works end to end.

You create it **once** (per environment). After that, sending is just the PL/SQL.

---

## Objects to create

| Object | Internal name | Notes |
|--------|---------------|-------|
| Item type | `XXADHOC` | Persistence **Temporary, 0 days** |
| Message | `XX_ADHOC_MSG` | FYI (no Respond attributes) |
| Message attribute | `SUBJECT` | Type Text, **Source = Send** |
| Message attribute | `BODY` | Type Text, **Source = Send** |
| Message attribute | `HTMLBODY` | Type Text, **Source = Send** (optional, for HTML) |

---

## Build it in Oracle Workflow Builder (~5 min)

1. Open **Workflow Builder**, connect with **Store = Database** to the EBS DB
   (or Store = File to save a `.wft` you later load with `WFLOAD`).
2. **New Item Type**
   - Internal Name: `XXADHOC`
   - Display Name: `XX Ad-hoc Email`
   - Persistence: **Temporary**, **0** days
3. Right-click `XXADHOC` → **New Message**
   - Internal Name: `XX_ADHOC_MSG`
   - Display Name: `Ad-hoc Email Message`
   - Priority: Normal
4. Right-click the message → **New Attribute** (repeat for each):
   - `SUBJECT`  — Type **Text**, Source **Send**
   - `BODY`     — Type **Text**, Source **Send**
   - `HTMLBODY` — Type **Text**, Source **Send**  *(optional)*
5. Open the message's **Body** tab and reference the attributes by token:
   - Subject: `&SUBJECT`
   - Plain-text body: `&BODY`
   - HTML body: `&HTMLBODY`  *(if you added it)*
   - Do **not** add any Respond attributes — that keeps it an FYI notification the
     mailer sends and then auto-closes.
6. **File → Save** (uploads to the dictionary). If you used Store = File, save the
   `.wft` and load it: `WFLOAD apps/<apps_pwd>@<tns> 0 Y UPLOAD xxadhoc_email.wft`

---

## Verify it loaded

```sql
-- Message exists?
SELECT type, name, display_name
  FROM wf_messages_vl
 WHERE type = 'XXADHOC';

-- Its send attributes?
SELECT name, type, subtype, format
  FROM wf_message_attributes
 WHERE message_type = 'XXADHOC'
   AND message_name = 'XX_ADHOC_MSG';
```

You should see `XX_ADHOC_MSG` and the `SUBJECT` / `BODY` / `HTMLBODY` attributes.

---

## Then send

Run `sql/samples/wf_adhoc_email.sql` (as `APPS`). It creates a notification from
this message, sets the subject/body, and lets the **Notification Mailer** e-mail it
(or pushes it immediately with `WF_MAIL.SEND`). The mailer must be configured and
running for the e-mail to actually leave the system.
