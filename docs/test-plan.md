# Test plan — CR2025-10-0449

Worked examples use a monthly basic salary of **10,000** (annual 120,000),
matching the HLD's example employee.

---

## 1. Category → duration (unit)

| # | Category | Expected duration | Expected cap |
|---|---|---|---|
| T-01 | 1 | 4 | 10,000 |
| T-02 | 2 | 8 | 20,000 |
| T-03 | 3 | 12 | 30,000 |
| T-04 | null | null | — (VAL-01) |
| T-05 | `'9'` (not a lookup code) | null | — (VAL-01) |
| T-06 | 1, lookup end-dated | null | — (VAL-01) |
| T-07 | 1, TAG blanked in Lookups form | null | — (VAL-01, not a default) |

`SELECT btvl_oie_sa_rules_pkg.derive_recovery_months('1') FROM dual;` → 4

---

## 2. Amount cap (VAL-03)

| # | Category | Amount | Result |
|---|---|---|---|
| T-10 | 1 | 10,000 | Pass — exactly at cap |
| T-11 | 1 | 5,000 | Pass — HLD's worked example; duration still 4 |
| T-12 | 1 | 10,000.01 | **VAL-03** |
| T-13 | 2 | 20,000 | Pass |
| T-14 | 3 | 30,000.01 | **VAL-03** |
| T-15 | 1 | 0 / null | **VAL-02** (cap not evaluated) |
| T-16 | 1 | −500 | **VAL-02** |

Rounding: salary 10,000.005/12 rounds to 2dp on both sides before
comparison, so a half-cent cannot produce a spurious VAL-03.

---

## 3. Cooling-off (VAL-08) — the highest-risk rule

Previous advance balance reached 0.00 on **15-Jan-2026**, so the earliest
submission date is **15-Mar-2026**.

| # | Current date | Result |
|---|---|---|
| T-20 | 14-Mar-2026 | **VAL-08**, message names 15-MAR-2026 |
| T-21 | 15-Mar-2026 | Pass — boundary is inclusive |
| T-22 | 16-Mar-2026 | Pass |
| T-23 | No prior advance at all | Pass |
| T-24 | Prior advance still has balance > 0 | **VAL-07** only, not VAL-08 |

Month-end boundaries (GAP-01 — confirm the intent before sign-off):

| # | Balance zero on | Earliest submission | Note |
|---|---|---|---|
| T-25 | 31-Dec-2025 | 28-Feb-2026 | `ADD_MONTHS` clamps to month end |
| T-26 | 31-Dec-2027 | 29-Feb-2028 | leap year |
| T-27 | 30-Jan-2026 | 30-Mar-2026 | |
| T-28 | 31-Jan-2026 | 31-Mar-2026 | |

If the policy means "60 days", T-25 becomes 01-Mar-2026 — a three-day
difference that will be noticed by employees.

---

## 4. Open advance (VAL-07)

| # | Scenario | Result |
|---|---|---|
| T-30 | Advance raised, no recovery rows yet | **VAL-07** |
| T-31 | Balance 1,000 outstanding | **VAL-07** |
| T-32 | Balance reached 0.00 last month | VAL-08 (not VAL-07) |
| T-33 | Settled early — balance hit 0.00 before the scheduled end | Treated as closed; cooling-off runs from the actual zero date |
| T-34 | Previous request CANCELLED | Ignored — not an open advance |
| T-35 | Editing the current request itself | Not counted — excluded by `p_request_id` |

---

## 5. Attachment (VAL-06)

| # | Scenario | Result |
|---|---|---|
| T-40 | Submit with no document | **VAL-06** |
| T-41 | Submit with one document | Pass |
| T-42 | First save of a new request, `p_validate_attachment = 'N'` | VAL-06 not raised |
| T-43 | Template 11408 attachment = Yes | Attachment region visible on the page |

---

## 6. Annual limit (VAL-10)

| # | Requests already raised this calendar year | Result |
|---|---|---|
| T-50 | 0 | Pass |
| T-51 | 1 | Pass |
| T-52 | 2 | **VAL-10** |
| T-53 | 2, but both in the previous calendar year | Pass |
| T-54 | 2, one of them cancelled | Pass — cancelled does not consume (GAP-06) |

---

## 7. Scope isolation — must pass before go-live

| # | Scenario | Expected |
|---|---|---|
| T-60 | ORG_ID 7107 | All new rules apply |
| T-61 | ORG_ID 7108 | All new rules apply |
| T-62 | Any other ORG_ID | **Zero behaviour change.** No category required, duration typed as today, no cooling-off, no mandatory attachment |
| T-63 | `XXBTVL_SA_ENABLED_ORGS` end-dated | Chad reverts to pre-CR behaviour — the rollback path |
| T-64 | Lookup dropped / unreadable | Fails closed to 'N'; no OPCO gets the new rules |

T-62 is the regression test that protects every other country. Run it on at
least one high-volume OPCO before sign-off.

---

## 8. Schedule generation — unchanged (regression)

| # | Category | Amount | Expected schedule |
|---|---|---|---|
| T-70 | 1 | 10,000 | 4 deductions of 2,500 |
| T-71 | 1 | 5,000 | 4 deductions of 1,250 |
| T-72 | 2 | 20,000 | 8 deductions of 2,500 |
| T-73 | 3 | 30,000 | 12 deductions of 2,500 |
| T-74 | 3 | 10,000 | 12 deductions of 833.33 + rounding on the final instalment |

In every case: total recovered = advance amount, and the schedule is
produced by the **existing** code from `LOAN_DURATION`. T-74 exercises the
existing rounding behaviour — record what it does today and assert it is
unchanged, do not "fix" it in this CR.

---

## 9. Data / edge cases

| # | Scenario | Result |
|---|---|---|
| T-80 | No Fusion salary row | **VAL-09**, request blocked |
| T-81 | Two overlapping salary rows | **VAL-09** — safer than picking one arbitrarily; raise the data issue with HR |
| T-82 | Salary changes between save and approval | Cap evaluated at save time; approval uses the existing flow |
| T-83 | Multiple rules fail at once | All messages returned in one pass, in policy order |
| T-84 | Duration tampered via a non-page payload | **VAL-05** |
| T-85 | Advance raised before go-live (`SALARY_ADV_CATEGORY` null) | Untouched; its schedule runs as before (GAP-10) |

---

## 10. UAT script (business sign-off)

1. Log in as a Chad GSM employee (`TD MO IEXPENSE USER`).
2. Create a salary advance — confirm the **Salary Advance Category**
   dropdown shows exactly three values.
3. Pick "1 Month Salary" — confirm Loan Duration shows **4** and is
   **not editable**.
4. Enter an amount above one month's salary — confirm the submission is
   blocked with the VAL-03 message.
5. Enter a lower amount (the HLD example: 5,000 against 10,000) — confirm it
   is accepted and the duration stays 4.
6. Submit with no attachment — confirm the VAL-06 message.
7. Attach the signed document and submit — confirm it goes to the existing
   approver.
8. Using an employee who cleared an advance less than two months ago,
   attempt a new request — confirm the VAL-08 message and the date it names.
9. Repeat steps 2–7 as a Chad AM employee (`TD MMB IEXPENSE USER`).
10. Repeat step 2 as a **non-Chad** employee — confirm the page is exactly
    as it was before the change.
