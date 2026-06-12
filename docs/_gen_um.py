exec(open('_gen_lld.py').read().split("# ====================== LLD ======================")[0])

d = Document(); style_doc(d); footer(d, "CR# 2026-02-0585  —  User Manual  v1.0")
cover(d, "User Manual", "Exit & Movement Replacement — Reporting Managers and F-DOA Superusers")
doc_control(d)

d.add_heading("1. Introduction",1)
para(d,"When an employee exits the organisation or moves to another department/OpCo, their pending approvals (Purchase Requisitions, Purchase Orders and AP invoice approvals) must continue without interruption. This solution notifies the employee's Reporting Manager (RM) in advance, lets the RM nominate a replacement employee through a simple form, and then automatically transfers all open approval responsibilities to that replacement.")
d.add_heading("1.1 Who uses this solution",2)
table(d,["Role","What you do","Responsibility in EBS"],[
 ["Reporting Manager (RM)","Receive notifications; nominate a replacement for your exiting/moving direct report","Airtel Africa Manager Responsibility Approvals"],
 ["F-DOA Superuser","Correct/override an Exit replacement within the allowed window; run replacement reports","ASI Invoice DOA Access"]],
 widths=[1.6,3.0,1.9])
d.add_heading("1.2 Components at a glance — responsibilities and navigation",2)
table(d,["Component","Type","Responsibility","Navigation / Access"],[
 ["Exit Replacement","Form","Airtel Africa Manager Responsibility Approvals","ASI FDOA Replacement > Exit Replacement"],
 ["Movement Replacement","Form","Airtel Africa Manager Responsibility Approvals","ASI FDOA Replacement > Movement Replacement"],
 ["Superuser Replacement","Form","ASI Invoice DOA Access","ASI FDOA Replacement > Superuser Replacement"],
 ["Airtel FDOA Manager Replacement Report (ASIFDOAMGRRPT)","Concurrent Program (report)","ASI Invoice DOA Access","Requests > Submit a New Request"],
 ["Airtel FDOA Superuser Replacement Report (ASIFDOASURPT)","Concurrent Program (report)","ASI Invoice DOA Access","Requests > Submit a New Request"],
 ["Exit/Movement Notification engine (ASIFDOANOTIF)","Concurrent Program (scheduled)","Scheduled by IT — no user action","Runs daily 12:00"],
 ["PR/PO Requestor Update (ASIFDOAPRPO)","Concurrent Program (scheduled)","Scheduled by IT — no user action","Runs daily 00:30"],
 ["QP Approver Update (ASIFDOAQP)","Concurrent Program (scheduled)","Scheduled by IT — no user action","Runs daily 00:35"]],
 widths=[2.2,1.4,1.6,1.6])
d.add_heading("1.3 Before you start",2)
bullets(d,[
 "Your EBS user must be linked to your employee record. If not, the form shows: 'CR# 2026-02-0585 - This form requires an EBS user linked to an employee record.' — contact the System Administrator.",
 "You need the responsibility listed above. Managers receive theirs through the standard business process.",
 "Notifications arrive in your EBS Worklist and by e-mail (via the standard Workflow Mailer)."])

d.add_heading("2. How the Process Works",1)
d.add_heading("2.1 Notification timeline",2)
table(d,["Event","When you are notified","Who is copied"],[
 ["Employee EXIT (termination)","15, 10 and 5 days before, and on the last working day","DOA Superuser group copied on the 5-days-before notification"],
 ["Employee MOVEMENT (department/OpCo change)","1, 5, 10 and 15 days after the effective date","DOA Superuser group copied on the day-10 notification"]],
 widths=[2.1,2.5,1.9])
d.add_heading("2.2 What happens if you do nothing",2)
para(d,"If no replacement is entered by the last working day (Exit) or by the day-16 cut-off (Movement), YOU — the Reporting Manager — are automatically recorded as the replacement, and all the employee's open approvals route to you. You receive a final notification informing you of this.",bold=True)
d.add_heading("2.3 What happens after you save a replacement",2)
bullets(d,[
 "Notifications for that employee stop immediately.",
 "On the night after the employee's termination date (Exit) or the night after your submission (Movement), the system updates: open Purchase Requisitions (requester), open Purchase Orders (deliver-to person / blanket buyer reference), AP invoice approver mapping (DOA Quality Plan), and reassigns any approval notifications still sitting in the employee's worklist to the replacement.",
 "Approval flows are NOT restarted — only the person changes."])

d.add_heading("3. RM Guide — Exit Replacement Form",1)
d.add_heading("3.1 Navigation",2)
para(d,"Responsibility: Airtel Africa Manager Responsibility Approvals  >  ASI FDOA Replacement  >  Exit Replacement")
d.add_heading("3.2 Screen fields",2)
table(d,["Field","Description","Entry"],[
 ["Document Type","Always EXIT on this form","Display only"],
 ["Exiting Employee","Your direct report who is exiting","Pick from List of Values (Ctrl+L)"],
 ["Termination Date","Employee's actual termination date","Filled automatically from the list"],
 ["Department","Employee's department (cost centre)","Filled automatically from the list"],
 ["Replacement Employee","The person taking over approvals","Pick from list — your direct reports plus '*** Self (RM) ***'"],
 ["Remarks","Optional free text (your remarks are not visible to the Superuser)","Optional"]],
 widths=[1.5,3.0,2.0])
d.add_heading("3.3 Step by step",2)
for s in ["Open the form from the menu path above.",
 "Place the cursor in 'Exiting Employee' and press Ctrl+L (or click the LOV button). The list shows only YOUR direct reports who are in the exit window. Select the employee — the termination date and department fill in automatically.",
 "Place the cursor in 'Replacement Employee' and press Ctrl+L. Select the replacement (you may select yourself — the '*** Self (RM) ***' entry).",
 "Optionally enter Remarks.",
 "Click Save. A confirmation appears: 'Replacement saved (ID nnnn)'. The form clears, ready for the next entry.",
 "Click Exit to close the form."]:
    d.add_paragraph(s, style='List Number')
d.add_heading("3.4 Validations on this form",2)
bullets(d,[
 "Old and New employee are mandatory; saving without them shows: 'Old Employee and New Employee are mandatory.'",
 "Replacement cannot be the same person: 'Old Employee and New Employee cannot be the same.'",
 "The exiting employee must be in the exit window: 'The selected employee is not in the Exit scope.'",
 "An already-saved record cannot be edited or re-entered by the RM — contact the F-DOA Superuser for corrections (Exit only, within the last 15 days)."])

d.add_heading("4. RM Guide — Movement Replacement Form",1)
para(d,"Navigation: Airtel Africa Manager Responsibility Approvals  >  ASI FDOA Replacement  >  Movement Replacement")
para(d,"The form works exactly like the Exit form. Differences:")
table(d,["Field","Description"],[
 ["Document Type","Always MOVEMENT"],
 ["Moving Employee","Your direct report whose department/OpCo changed (list shows employees moved in the last 15 days)"],
 ["Effective Date","Date the move took effect (automatic)"],
 ["Old / New Department","Before and after cost centres (automatic)"],
 ["Replacement Employee","Same list as the Exit form (direct reports + self)"]],
 widths=[1.7,4.8])
para(d,"Note: the Superuser cannot override Movement replacements — make sure your entry is correct before the day-16 cut-off. After day 16 with no entry, you are auto-defaulted as the replacement.")

d.add_heading("5. Superuser Guide — Combined Replacement Form",1)
para(d,"Navigation: ASI Invoice DOA Access  >  ASI FDOA Replacement  >  Superuser Replacement")
d.add_heading("5.1 Screen fields",2)
table(d,["Field","Description","Entry"],[
 ["Document Type","EXIT or MOVEMENT","Pick from list; defaults to EXIT. Changing it clears the employee fields"],
 ["Old Employee","Any employee org-wide in the selected document type's scope","Pick from list (org-wide — not restricted to direct reports)"],
 ["Term/Effective Date","Key date of the event","Automatic"],
 ["New Employee","Any ACTIVE employee org-wide","Pick from list"],
 ["Remarks","Optional; not visible to the RM","Optional"]],
 widths=[1.4,3.1,2.0])
d.add_heading("5.2 Override rules (important)",2)
bullets(d,[
 "Overrides are allowed for EXIT only, and only within the 15-day window before the termination date.",
 "A MOVEMENT override, or an EXIT override outside the window, is rejected by the system with error code SU_OUTSIDE_OVERRIDE_WINDOW.",
 "A Superuser override replaces the RM's entry for that employee — it becomes the value used by the nightly update."])
d.add_heading("5.3 Step by step",2)
for s in ["Open the form; Document Type defaults to EXIT (change it if needed — the employee fields clear when you do).",
 "Pick the Old Employee from the org-wide list (the key date fills automatically).",
 "Pick the New Employee (any active employee).",
 "Enter Remarks if required, then Save. Confirmation: 'Override saved (ID nnnn)'."]:
    d.add_paragraph(s, style='List Number')

d.add_heading("6. Reports",1)
table(d,["Report","Run from","Parameters","Content"],[
 ["Airtel FDOA Manager Replacement Report (ASIFDOAMGRRPT)","ASI Invoice DOA Access (SRS)","Date From, Date To (both mandatory)","RM-entered replacements: Type, Old Employee Name/Number, Department, New Employee Name/Number, Updated By, Updated Date"],
 ["Airtel FDOA Superuser Replacement Report (ASIFDOASURPT)","ASI Invoice DOA Access (SRS)","Date From, Date To (both mandatory)","All replacements (RM + Superuser, Exit + Movement) — columns as above plus Remarks"]],
 widths=[2.0,1.4,1.4,2.5])
para(d,"Both reports produce pipe-delimited text output (open in Excel using '|' as the delimiter). Per policy, both are executed only from the Superuser responsibility.")

d.add_heading("7. Notifications Reference",1)
table(d,["You receive…","Why","Action expected"],[
 ["'Exit' notification (15/10/5 days before, last day)","Your direct report is exiting","Open the Exit Replacement form and nominate a replacement"],
 ["'Movement' notification (1/5/10/15 days after)","Your direct report moved department/OpCo","Open the Movement Replacement form and nominate a replacement"],
 ["'Fallback' notification","Window closed with no entry — you are now the replacement","No action required; approvals route to you. Contact F-DOA if this must be corrected (Exit only, in window)"]],
 widths=[2.1,2.1,2.3])
bullets(d,[
 "Notifications stop as soon as a replacement is saved.",
 "Backdated exits/movements do not generate notifications — the RM is defaulted immediately.",
 "If a termination is postponed, the cycle restarts against the new date; if preponed into the notice window, a Last-Day notification is sent immediately."])

d.add_heading("8. Error Messages and Troubleshooting",1)
table(d,["Message / Symptom","Meaning","What to do"],[
 ["This form requires an EBS user linked to an employee record.","Your FND user has no employee link","Raise with System Administrator"],
 ["The selected employee is not in the Exit scope. / …not in the Movement scope. / …not in the selected Document Type scope.","Person typed/picked is outside the detection window for that document type","Use the List of Values; verify the event exists in HRMS"],
 ["Old Employee and New Employee are mandatory. / Document Type, Old Employee and New Employee are mandatory.","Required fields empty at Save","Complete both employees (and Document Type on the Superuser form)"],
 ["Old Employee and New Employee cannot be the same.","Same person selected twice","Choose a different replacement"],
 ["Document Type must be EXIT or MOVEMENT.","Invalid value typed in Document Type","Pick from the list"],
 ["Error containing SU_OUTSIDE_OVERRIDE_WINDOW","Override attempted for MOVEMENT, or for EXIT outside the 15-day window","Overrides are EXIT-only within 15 days of termination"],
 ["Empty List of Values","No employees currently in the window for your hierarchy / selected type","Nothing to action; verify HRMS dates if an employee is expected"],
 ["Menu entry 'ASI FDOA Replacement' missing","Responsibility not assigned or security not compiled","Contact System Administrator"]],
 widths=[2.3,2.1,2.1])

d.add_heading("9. Frequently Asked Questions",1)
for q,a in [
 ("Can I nominate someone outside my team as the replacement?","As RM — no, the list is restricted to your direct reports (plus yourself). The F-DOA Superuser can select org-wide."),
 ("Can I change a replacement after saving?","RMs cannot re-enter a saved record. For Exit, the F-DOA Superuser can override within the 15-day pre-termination window. Movement entries cannot be overridden."),
 ("Do approvals restart when the replacement takes effect?","No. Only the approver/requester person changes; in-flight approvals continue."),
 ("When exactly does the replacement take effect?","Exit — the day after the actual termination date. Movement — the day after your submission (or day 17 with the RM default)."),
 ("I received a notification but the employee is not exiting.","Termination data comes from Fusion HCM via the standard sync. If the date is wrong in HRMS, raise it with HR; if the date is cleared, notifications stop and any replacement entry is nullified."),
 ("Does this work across OpCos?","Yes — cross-OpCo selection is allowed, and OpCos are enabled progressively at go-live.")]:
    para(d,"Q: "+q,bold=True); para(d,"A: "+a)

d.add_heading("10. Support",1)
table(d,["Level","Contact","Scope"],[
 ["1","IT Service Desk","Access, responsibility, navigation issues"],
 ["2","EBS Functional Support (F-DOA team)","Override requests, data corrections, report queries"],
 ["3","EBS Technical Support","Form errors, notification failures, propagation issues (quote CR# 2026-02-0585)"]],
 widths=[0.7,2.4,3.4])

d.save("User_Manual_CR2026020585_Exit_and_Movement_of_Employee.docx")
print("User Manual saved")
