# vbcs

## CR2025-10-0449 — Chad OPCO Salary Advance

Oracle EBS 12.2.14 / Internet Expenses extension implementing the HLD
*"Change the Salary Advance Configuration for Chad opco"* for operating
units **7107** (Tchad GSM) and **7108** (Tchad AM).

### What changes

| | |
|---|---|
| Fixed categories | 1 / 2 / 3 months of salary |
| Frozen recovery duration | 4 / 8 / 12 months — derived, not typed |
| Amount cap | `category × monthly basic salary`; a lower amount is allowed |
| Mandatory attachment | signed approval document |
| Cooling-off | 2 months after the previous advance reaches a zero balance |
| Retained | existing 2 advances per calendar year |

Unchanged: repayment schedule generation, approval workflow, the Fusion
salary derivation, and every other operating unit.

### Layout

```
docs/
  MD70-CR2025-10-0449-Chad-Salary-Advance.md   technical design
  HLD-gap-analysis.md                          gaps + assumptions, for the BA
  OAF-personalization-BTVLAdvanceCreUpdPG.md   page changes
  test-plan.md                                 unit / regression / UAT
db/
  install.sql                                  master installer
  ddl/01_...                                   new column + index
  seed/02_... 03_... 04_...                    lookups + messages
  plsql/05_... 06_...                          BTVL_OIE_SA_RULES_PKG
  patch/07_...                                 hooks for btvl_oie_adv_pkg
  rollback/rollback.sql
```

### Install

```sh
sqlplus apps/<pwd>@<sid> @db/install.sql
```

Then, separately: apply `db/patch/07` to the live `btvl_oie_adv_pkg` body,
apply the page personalization, and set expense template 11408 attachment to
Yes.

**Rollback** is one step: end-date the rows in `XXBTVL_SA_ENABLED_ORGS`.
Every new rule sits behind that guard.

### Status

Not compiled against a database — no EBS instance was available. The code is
written against the data-model assumptions in MD70 §4, all isolated in four
adapter functions at the bottom of the package body. Every point needing
reconciliation with the live objects is marked `TODO(CR2025-10-0449)`.

Three open questions change behaviour if the assumption is wrong — GAP-01
(cooling-off formula), GAP-02 (which date counts as full repayment) and
GAP-05 (when the attachment check can run). See the gap analysis.
