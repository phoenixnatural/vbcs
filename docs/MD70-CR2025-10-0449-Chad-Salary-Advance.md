# MD70 — Technical Design

**CR2025-10-0449 — Change the Salary Advance Configuration for Chad OPCO**

| | |
|---|---|
| Source document | HLD - CR2025-10-0449, v1.0 (Debjit Karar / Lavanya Pandiyan) |
| Application | Oracle E-Business Suite 12.2.14 — Internet Expenses |
| Operating units | 7107 (Tchad GSM), 7108 (Tchad AM) |
| CEMLI type | Extension to an existing custom program |
| Related docs | `HLD-gap-analysis.md`, `OAF-personalization-BTVLAdvanceCreUpdPG.md`, `test-plan.md` |

---

## 1. Scope

Six behaviours change, for Chad only:

1. The employee picks a **fixed category** — 1, 2 or 3 months of salary.
2. The **recovery duration is derived and frozen** — 4, 8 or 12 months. It
   can no longer be typed.
3. The **requested amount is capped** at `category × monthly basic salary`;
   a lower amount is allowed.
4. A **signed approval document must be attached**.
5. A **two-month cooling-off period** applies after the previous advance is
   fully repaid.
6. The existing **two-advances-per-calendar-year** limit is retained.

Explicitly unchanged: repayment schedule generation, the approval workflow,
the Fusion salary derivation, and every other operating unit.

---

## 2. Design decision — a separate rules package

All new logic lives in a **new package `BTVL_OIE_SA_RULES_PKG`**, not inside
`btvl_oie_adv_pkg`.

`btvl_oie_adv_pkg` is shared by every OPCO. Putting Chad-specific rules into
its salary block would mean a large diff on a multi-country program, a wide
regression surface, and a re-test of every OPCO. Instead `btvl_oie_adv_pkg`
gains only:

- one `is_rules_enabled` guard plus a `derive_recovery_months` assignment,
- one `validate_request` call at its existing validation point,
- `salary_adv_category` added to its existing INSERT/UPDATE.

Everything else is new, isolated, and independently testable. Rollback is a
lookup update (see §9).

---

## 3. Objects

### New

| Object | Type | Script |
|---|---|---|
| `BTVL_OIE_SA_RULES_PKG` | Package spec + body | `db/plsql/05`, `db/plsql/06` |
| `XXBTVL_SA_CATEGORY` | FND lookup | `db/seed/02` |
| `XXBTVL_SA_ENABLED_ORGS` | FND lookup | `db/seed/03` |
| `XXBTVL_SA_VAL01…VAL10` | FND messages | `db/seed/04` |
| `BTVLOIE_ADV_REQUESTS.SALARY_ADV_CATEGORY` | Column | `db/ddl/01` |
| `BTVLOIE_ADV_REQUESTS_N90` | Index (PERSON_ID, ORG_ID) | `db/ddl/01` |

### Changed

| Object | Type | Change |
|---|---|---|
| `BTVL_OIE_ADV_PKG` | Package body | Salary block — guard, derive, validate, persist (`db/patch/07`) |
| `BTVLAdvanceCreUpdPG` | OAF page | New category dropdown; Loan Duration read-only |
| Expense template **11408** | Config | Attachment = Yes |

### Not created

No new table for the category→duration mapping, and no new Quality Plan.
Three rows of static data belong in a lookup that Payroll/Config can
maintain from the standard Lookups form (HLD s.4).

---

## 4. Data model assumptions

The package reads the existing model through **four adapter functions** at
the bottom of the body. Everything assumed is confined to those four; the
rule logic never touches a base table. If a name differs on the instance,
change the adapter and nothing else.

| Ref | Object | Columns used |
|---|---|---|
| A-01 | `BTVLOIE_ADV_REQUESTS` | `REQUEST_ID, PERSON_ID, ORG_ID, REQUEST_DATE, ADVANCE_AMOUNT, LOAN_DURATION, STATUS_CODE` + new `SALARY_ADV_CATEGORY` |
| A-02 | `BTVLOIE_ADV_RECOVERY` | `REQUEST_ID, RECOVERY_DATE, RECOVERED_AMOUNT, BALANCE_AMOUNT` |
| A-03 | `BTVL_FUSION_EMP_SALARY_V` | `PERSON_ID, ANNUAL_BASIC_SALARY, EFFECTIVE_START_DATE, EFFECTIVE_END_DATE` |
| A-04 | `FND_ATTACHED_DOCUMENTS` | `ENTITY_NAME = 'BTVLOIE_ADV_REQUESTS'`, `PK1_VALUE = REQUEST_ID` |

Statuses treated as "not a live advance": `CANCELLED`, `REJECTED`,
`WITHDRAWN` — reconcile with the real `STATUS_CODE` domain.

---

## 5. Category and duration

Lookup `XXBTVL_SA_CATEGORY` carries the mapping, with the recovery duration
in the **TAG** column:

| Code | Meaning | Tag |
|---|---|---|
| 1 | 1 Month Salary | 4 |
| 2 | 2 Months Salary | 8 |
| 3 | 3 Months Salary | 12 |

`derive_recovery_months` is the **single derivation point**, used by both
the page default and the server-side check, so the screen and the hard stop
cannot disagree. The derived value is written into the **existing
`LOAN_DURATION` column** — the repayment schedule generation reads exactly
what it reads today and needs no change.

A blank or non-numeric TAG is treated as an invalid category (VAL-01) rather
than defaulting the employee into an arbitrary repayment period.

---

## 6. Validation

`validate_request` returns **all** failures in one pass, in policy order, so
the employee fixes them in one go rather than one save at a time.
`get_first_error` is the convenience wrapper for the controller.

| Rule | Message | Condition |
|---|---|---|
| VAL-01 | `XXBTVL_SA_VAL01` | No category, or category not enabled, or unusable TAG |
| VAL-02 | `XXBTVL_SA_VAL02` | Amount blank or ≤ 0 |
| VAL-03 | `XXBTVL_SA_VAL03` | `amount > ROUND(monthly_basic × months, 2)` |
| VAL-05 | `XXBTVL_SA_VAL05` | Defensive only — duration ≠ derived value |
| VAL-06 | `XXBTVL_SA_VAL06` | No attached document (see GAP-05) |
| VAL-07 | `XXBTVL_SA_VAL07` | An advance with balance > 0 exists |
| VAL-08 | `XXBTVL_SA_VAL08` | `TRUNC(SYSDATE) < ADD_MONTHS(last_repayment, 2)` |
| VAL-09 | `XXBTVL_SA_VAL09` | **Added** — no salary on file (GAP-08) |
| VAL-10 | `XXBTVL_SA_VAL10` | ≥ 2 requests in the calendar year |

VAL-04 is not implemented — unreachable once the duration is derived.

VAL-08 is evaluated only when VAL-07 has not fired: an employee who still
owes money gets one actionable message, not two overlapping ones.

Message text lives in `FND_NEW_MESSAGES`, tokenised (`&CATEGORY`, `&LIMIT`,
`&MONTHS`, `&DATE`), so it is translatable and editable from the Messages
form without a code change.

---

## 7. Scope guard

Every public routine short-circuits when
`is_rules_enabled(p_org_id) = 'N'`, and every insertion into
`btvl_oie_adv_pkg` sits inside that guard. An operating unit not listed in
`XXBTVL_SA_ENABLED_ORGS` executes exactly the code path it executes today.

The guard **fails closed**: if the lookup cannot be read, it returns `'N'`,
so a configuration problem can never switch Chad rules on for another OPCO.

---

## 8. Performance

The validation runs on every save. Three mitigations:

- Lookup reads are cached per session (PL/SQL associative arrays) — each
  lookup row is read at most once per session.
- The eligibility queries are keyed on `PERSON_ID, ORG_ID` and backed by the
  new index `BTVLOIE_ADV_REQUESTS_N90`.
- No row-by-row processing; each check is a single aggregate query.

Expected cost per save: four short queries plus cached lookup reads.

---

## 9. Install and rollback

Install: `sqlplus apps/<pwd>@<sid> @db/install.sql` — numbered scripts in
sequence, each re-runnable, with a post-install check that fails loudly if
the object or seed counts are wrong.

Separate, manual: the `btvl_oie_adv_pkg` body change (`db/patch/07`), the
page personalization, and template 11408.

Rollback: **end-dating the rows in `XXBTVL_SA_ENABLED_ORGS` disables every
new rule immediately**, because everything is behind the guard. Full removal
is `db/rollback/rollback.sql`. The `SALARY_ADV_CATEGORY` column is not
dropped — it is audit data on requests already raised.

---

## 10. Open items

`HLD-gap-analysis.md` carries twelve. The three that change behaviour if the
assumption is wrong:

- **GAP-01** — the cooling-off comparison is missing from the HLD; assumed
  `ADD_MONTHS(last_repayment, 2)`, inclusive.
- **GAP-02** — "date balance reached 0.00" vs "date of final instalment";
  assumed the former.
- **GAP-05** — when VAL-06 can be evaluated without making the form
  unusable; `p_validate_attachment` exists to resolve it either way.

---

## 11. Build status

The SQL and PL/SQL in `db/` have **not been compiled against a database** —
no EBS instance was available. They are written against the assumptions in
§4 and every point needing reconciliation is marked
`TODO(CR2025-10-0449)`. First step on the instance: take the live
`btvl_oie_adv_pkg` source and the real table definitions, reconcile the four
adapters, then compile.
