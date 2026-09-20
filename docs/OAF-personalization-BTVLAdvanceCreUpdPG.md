# BTVLAdvanceCreUpdPG — page changes

**CR2025-10-0449 — Chad OPCO Salary Advance**

Covers the Salary section of `BTVLAdvanceCreUpdPG`: the new category
dropdown, the read-only recovery duration, and the mandatory attachment.

---

## 1. Items to add / change

| # | Item | Type | Change |
|---|------|------|--------|
| 1 | `SalaryAdvCategory` | messageChoice | **New.** Prompt "Salary Advance Category". Required = Yes. Picklist from lookup `XXBTVL_SA_CATEGORY` (code → meaning). Action Type = `firePartialAction`, Event = `sacatChange`, Submit = True. |
| 2 | `LoanDuration` (existing) | messageTextInput → messageStyledText | **Changed.** No longer typed by the employee. Rendered read-only, value derived from the category. |
| 3 | `MaxAllowedAmount` | messageStyledText | **New, optional but recommended.** Shows the cap for the picked category so the employee sees the limit before hitting VAL-03. |
| 4 | Attachments region | — | Made mandatory — see §4. |

The picklist is best built as a `fnd_lookup_type`-backed VO
(`select lookup_code, meaning from fnd_lookup_values where lookup_type =
'XXBTVL_SA_CATEGORY' and language = userenv('LANG') and enabled_flag = 'Y'`)
so adding a category later needs no page change, matching the HLD's own
rationale for using a lookup.

---

## 2. The HLD says "no controller re-wiring" — that is only half true

> HLD s.3: *"No controller re-wiring – the page already calls the program
> that holds the rules."*

That is correct for **enforcement**: the hard stop happens server-side in
`btvl_oie_adv_pkg` → `btvl_oie_sa_rules_pkg.validate_request`, and that call
path already exists.

It is **not** correct for the **on-screen default**. Making Loan Duration
change from blank to 4 / 8 / 12 the moment the employee picks a category
needs a partial page refresh, and something has to handle that PPR event.
Personalization can add the item and set `firePartialAction`, but it cannot
run code when the event fires. There are two ways to close that gap:

### Option A — extend the controller (recommended)

Extend `BTVLAdvanceCreUpdCO` (or the existing CO for the salary region) and
handle the event in `processFormRequest`:

```java
public void processFormRequest(OAPageContext pageContext, OAWebBean webBean)
{
  super.processFormRequest(pageContext, webBean);

  if ("sacatChange".equals(pageContext.getParameter(EVENT_PARAM)))
  {
    OAApplicationModule am = pageContext.getApplicationModule(webBean);
    String category = pageContext.getParameter("SalaryAdvCategory");

    // Single derivation point - the same function the server-side
    // validation uses, so the screen and the hard stop cannot disagree.
    Serializable[] params = { category };
    Number months = (Number) am.invokeMethod("deriveRecoveryMonths", params);

    OAMessageStyledTextBean duration =
        (OAMessageStyledTextBean) webBean.findChildRecursive("LoanDuration");
    if (duration != null && months != null)
    {
      duration.setValue(pageContext, months.toString());
    }
  }
}
```

with the AM method calling the package:

```java
public Number deriveRecoveryMonths(String categoryCode)
{
  // one SQL: select btvl_oie_sa_rules_pkg.derive_recovery_months(:1) from dual
  ...
}
```

**Do not** re-implement the 1→4 / 2→8 / 3→12 mapping in Java. If the page
hard-codes it and Config later edits the lookup TAG, the screen and the
server-side validation silently disagree.

### Option B — personalization only, no PPR

Leave Loan Duration blank on entry, show a static hint ("Recovery duration
is set automatically from the selected category"), and let the derived value
appear after save. Zero custom Java, but the employee does not see the
repayment period before committing — which is the number they most want to
see. Acceptable only if a CO extension is out of scope for this release.

**Recommendation: Option A.** The extra effort is one small CO plus one AM
method, and it is what makes the screen match the policy the CR is about.

---

## 3. Making Loan Duration read-only

Personalization path:

*Functional Administrator → Personalization → Document: `/btvl/oracle/apps/.../webui/BTVLAdvanceCreUpdPG`*

At **Responsibility** level for `TD MO IEXPENSE USER` and
`TD MMB IEXPENSE USER` (not Site level — other OPCOs must keep the typed
field):

| Property | Value |
|----------|-------|
| Read Only | True |
| Required | False (the value is derived, never typed) |

Read-only alone is not protection — a crafted POST can still carry a
duration. That is why `validate_request` keeps the defensive VAL-05 check.

---

## 4. Mandatory attachment (VAL-06)

Two layers, both needed:

1. **Config** — expense template **11408**, Attachment = **Yes** (currently
   No). This is what surfaces the attachment region on the page.
2. **Code** — `btvl_oie_sa_rules_pkg.has_attachment` is checked on submit.
   Config alone makes attachment *available*, not *mandatory*; only the
   server-side check blocks the save.

The check reads `FND_ATTACHED_DOCUMENTS` on
`ENTITY_NAME = 'BTVLOIE_ADV_REQUESTS'`, `PK1_VALUE = REQUEST_ID`.

> **Confirm before build:** the real `ENTITY_NAME` used by the page's
> attachment region, and whether the request row exists (has a `REQUEST_ID`)
> at the point the validation runs. If it does not, VAL-06 must be evaluated
> on submit only — the `p_validate_attachment` parameter exists for exactly
> this. See GAP-05 in the gap analysis.

---

## 5. Responsibilities in scope

| Responsibility | LOB | ORG_ID |
|----------------|-----|--------|
| TD MO IEXPENSE USER | GSM | 7107 |
| TD MMB IEXPENSE USER | AM | 7108 |

Personalizations are applied at Responsibility level for these two only.
Server-side, the guard is lookup `XXBTVL_SA_ENABLED_ORGS`, so the two
mechanisms agree and adding an OPCO later is a lookup row plus a
personalization — no code change.
