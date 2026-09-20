# HLD gap analysis — CR2025-10-0449

Source: *HLD - CR2025-10-0449 - Change the Salary Advance Configuration for
Chad opco*, v1.0, 27-Aug-26.

Points where the HLD is incomplete, self-contradictory, or where the build
had to make a decision. Each gap says what was assumed so the build could
proceed, and what needs a decision from the BA. **Nothing here blocks the
code — every gap has a working default — but GAP-01, GAP-02 and GAP-05
change behaviour if the answer differs from the assumption.**

---

### GAP-01 — The cooling-off formula is missing (blocking if wrong)

The HLD has a heading *"Eligibility Window Calculation:"* with **no content
underneath**, and the next bullet reads:

> "Submission Hard-Block: If Current_Date  Earliest_Submission_Date, the
> system shall prevent form submission"

The comparison operator has been lost in the document.

**Assumed:** `Earliest_Submission_Date = ADD_MONTHS(Last_Repayment_Date, 2)`,
block when `TRUNC(SYSDATE) < Earliest_Submission_Date`, allow **on** that
date (consistent with "On or after Earliest_Submission_Date … automatically
lift the restriction").

**Needs confirming:** month-end behaviour. `ADD_MONTHS` gives 31-Dec + 2
months = 28-Feb. If the policy means "60 days", the code changes to
`Last_Repayment_Date + 60`. These differ by up to three days.

---

### GAP-02 — "Last_Repayment_Date" has two possible meanings

The HLD defines it as *"the date when the balance of the previous Salary
Advance reaches zero (0.00)"* but the Assumptions section says *"Waiting
period starts from the date the final repayment instalment is recovered."*
Those are the same date **only** when the advance runs to its scheduled end.
They differ when an employee settles early or a deduction is missed.

**Assumed:** the actual date the balance hit 0.00 (the HLD's own rule text),
read from the recovery history, not the scheduled schedule end.

---

### GAP-03 — VAL-04 and VAL-05 contradict the design

The validation table lists both rules and then annotates each with *"Not
Required as recovery duration will be auto-defaulted."*

**Built as:** VAL-04 dropped entirely (unreachable — the duration is always
derived). VAL-05 kept as a **defensive server-side check only**, for a
payload that did not come from the page. It is not reachable from the UI and
its message is seeded but should never be seen.

---

### GAP-04 — "Amount must correspond to the category" is stated two ways

The Detailed Requirement says the system *"checks whether the amount
corresponds to the selected salary advance category"* (reads as an exact
match), but the worked example allows a 5,000 request against a 10,000
salary under the 1-month category — i.e. a **cap**, not an exact match.

**Built as:** a cap. `amount <= category_months × monthly_basic`. This
follows the example and the VAL-03 wording ("exceeds the allowed limit").

---

### GAP-05 — When is the attachment check evaluated? (blocking if wrong)

An attachment in EBS is stored against a primary key. If the request row is
created only at save, there is nothing to attach a document to when the
first save runs — making VAL-06 fire on every new request and the form
unusable.

**Built as:** `validate_request` takes `p_validate_attachment`. Pass `'N'`
on the initial save of a new request and `'Y'` on submit. If the page
creates the request row up front (draft), pass `'Y'` throughout.

**Needs confirming:** the page's actual save/submit flow, and the real
`FND_ATTACHED_DOCUMENTS.ENTITY_NAME`.

---

### GAP-06 — "2 per year" is marked "to be confirmed"

The HLD keeps the existing limit (*"This stays along with the new 2-month
cooling-off rule"*) but the Approach section says *"Advances per year –
existing limit of 2 per year is kept (to be confirmed)"*.

**Built as:** kept, as VAL-10, counting on **calendar year of request
date**, excluding cancelled/rejected/withdrawn requests.

**Risk:** if the existing package already enforces this, the employee will
see the message twice. The adapter `adp_request_count_in_year` is the single
place to swap in the existing routine — do that during code reconciliation.

Also unstated: does a **cancelled** request consume one of the two? Assumed
no.

---

### GAP-07 — ORG_IDs 7107 / 7108 in code vs configuration

The HLD implies the two ORG_IDs are set in the package. They are seeded into
lookup `XXBTVL_SA_ENABLED_ORGS` instead, so adding or removing an OPCO is a
lookup row rather than a code change and a CEMLI re-deployment — the same
argument the HLD makes for `XXBTVL_SA_CATEGORY`. Behaviour is identical for
the two Chad OPCOs and for every other OPCO.

This is the one deliberate deviation from the HLD. Flag it at design review.

---

### GAP-08 — No rule for an employee with no salary on file

If the Fusion feed has no salary row, the cap cannot be computed. The HLD is
silent, so the build added **VAL-09** ("Your monthly basic salary could not
be determined…") and blocks. Allowing the request through would let an
employee bypass the cap entirely.

---

### GAP-09 — Currency is not mentioned

The advance amount and the salary are assumed to be in the same currency.
If the Fusion feed can return a currency different from the request
currency, a conversion step is missing from the HLD and from the build.

---

### GAP-10 — In-flight advances at go-live

The HLD does not say what happens to advances already running under the old
6-month schedule when this goes live.

**Assumed:** untouched. The new rules apply only to requests raised after
go-live; `SALARY_ADV_CATEGORY` stays NULL on historic rows. Note that those
employees still face the new cooling-off rule once their old advance clears
— confirm the business accepts that.

---

### GAP-11 — "No controller re-wiring" is not achievable for the UI default

See `OAF-personalization-BTVLAdvanceCreUpdPG.md` §2. Enforcement needs no
re-wiring; auto-defaulting Loan Duration on screen does need a PPR handler,
which personalization alone cannot provide. Two options are documented, with
a recommendation.

---

### GAP-12 — Document housekeeping

Minor, but worth correcting in v1.1 of the HLD:

- Creation/Last Updated dates read **21-Aug-26 / 27-Aug-26** — a 2026 date
  on a CR numbered 2025-10.
- "2 Monthe Salary" / "3 Monthe Salary" typo in the field description; the
  seeded meanings use "2 Months Salary" / "3 Months Salary".
- The Current Situation bullet *"Submit a new Salary Advance request even if
  only the annual limit has been met"* reads as the opposite of what is
  meant (presumably "even if the previous advance is not repaid").
