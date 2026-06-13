import docx
from docx import Document
from docx.shared import Pt, Inches, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

ACCENT = RGBColor(0xC0, 0x00, 0x00)  # Airtel red-ish
GREY   = "D9D9D9"

def shade(cell, color=GREY):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd'); shd.set(qn('w:val'),'clear'); shd.set(qn('w:fill'),color)
    tcPr.append(shd)

def style_doc(d):
    st = d.styles['Normal']; st.font.name='Calibri'; st.font.size=Pt(10.5)
    for i,(sz,col) in enumerate([(16,ACCENT),(13,ACCENT),(11.5,RGBColor(0,0,0))],1):
        h = d.styles[f'Heading {i}']; h.font.name='Calibri'; h.font.size=Pt(sz); h.font.color.rgb=col; h.font.bold=True

def footer(d, text):
    sec = d.sections[0]
    p = sec.footer.paragraphs[0]; p.text = text + "    |    Page "
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run()
    f1=OxmlElement('w:fldChar'); f1.set(qn('w:fldCharType'),'begin')
    it=OxmlElement('w:instrText'); it.set(qn('xml:space'),'preserve'); it.text='PAGE'
    f2=OxmlElement('w:fldChar'); f2.set(qn('w:fldCharType'),'end')
    run._r.append(f1); run._r.append(it); run._r.append(f2)
    for r in p.runs: r.font.size=Pt(8.5)
    hp = sec.header.paragraphs[0]
    hp.text="Airtel Africa  |  CR# 2026-02-0585  Exit and Movement of Employee"
    hp.alignment=WD_ALIGN_PARAGRAPH.RIGHT
    for r in hp.runs: r.font.size=Pt(8.5); r.font.color.rgb=RGBColor(0x80,0x80,0x80)

def table(d, headers, rows, widths=None):
    t = d.add_table(rows=1, cols=len(headers)); t.style='Table Grid'; t.alignment=WD_TABLE_ALIGNMENT.CENTER
    for i,h in enumerate(headers):
        c=t.rows[0].cells[i]; c.text=h; shade(c)
        for p in c.paragraphs:
            for r in p.runs: r.font.bold=True; r.font.size=Pt(9.5)
    for row in rows:
        cells=t.add_row().cells
        for i,v in enumerate(row):
            cells[i].text=str(v)
            for p in cells[i].paragraphs:
                for r in p.runs: r.font.size=Pt(9.5)
    if widths:
        for i,w in enumerate(widths):
            for row in t.rows: row.cells[i].width=Inches(w)
    d.add_paragraph()
    return t

def para(d, text, bold=False, italic=False, size=10.5):
    p=d.add_paragraph(); r=p.add_run(text); r.font.bold=bold; r.font.italic=italic; r.font.size=Pt(size); return p

def bullets(d, items):
    for it in items: d.add_paragraph(it, style='List Bullet')

def code(d, text):
    p=d.add_paragraph()
    r=p.add_run(text); r.font.name='Consolas'; r.font.size=Pt(8.5)
    p.paragraph_format.left_indent=Inches(0.25)

def cover(d, doctype, subtitle):
    for _ in range(6): d.add_paragraph()
    p=d.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p.add_run("Airtel Africa — Oracle E-Business Suite R12.2"); r.font.size=Pt(13); r.font.color.rgb=RGBColor(0x60,0x60,0x60)
    p=d.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p.add_run(doctype); r.font.size=Pt(26); r.font.bold=True; r.font.color.rgb=ACCENT
    p=d.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p.add_run("Exit and Movement of Employee"); r.font.size=Pt(18); r.font.bold=True
    p=d.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p.add_run("CR# 2026-02-0585"); r.font.size=Pt(14)
    p=d.add_paragraph(); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p.add_run(subtitle); r.font.size=Pt(11); r.font.italic=True
    for _ in range(4): d.add_paragraph()
    t=table(d, ["",""], [
        ["Document Version","1.0"],
        ["Status","Draft for Review"],
        ["Date","11-Jun-2026"],
        ["Instance","FINUAT (UAT)"],
        ["Custom Application","BTVL (data schema) / APPS (code)  —  object prefix ASI_FDOA_"],
        ["Prepared By","Sourav Sengupta"],
        ["Reviewed By",""],
        ["Approved By",""]], widths=[2.0,4.2])
    d.add_page_break()

def doc_control(d):
    d.add_heading("Document Control",1)
    para(d,"Revision History",bold=True)
    table(d,["Version","Date","Author","Description"],
      [["1.0","11-Jun-2026","Sourav Sengupta","Initial version — as-built for FINUAT"]],
      widths=[0.8,1.1,1.6,3.0])
    para(d,"References",bold=True)
    table(d,["#","Document","Notes"],[
      ["1","SSD — CR 2026-02-0585 Exit and Movement of Employee","Solution/System Design (functional)"],
      ["2","HLD — Airtel Africa F-DOA","High-level design; India replication callouts"],
      ["3","deploy_btvl_clean.sql / deploy_apps_clean.sql","Authoritative DDL & code (build/99_deploy)"],
      ["4","ASIFDOAN.wft","Workflow definition (build/12_workflow)"],
      ["5","ASI_FDOA_{EXIT,MOVEMENT,SUPERUSER}_FMB.xml","Form sources (build/13_forms)"],
      ["6","asi_fdoa_aol_access.sql","AOL registration (build/14_responsibilities)"]],
      widths=[0.4,3.1,3.0])
    d.add_page_break()

# ====================== LLD ======================
d = Document(); style_doc(d); footer(d, "CR# 2026-02-0585  —  Low Level Design  v1.0")
cover(d, "Low Level Design (LLD)", "Technical Design — As Built")
doc_control(d)

d.add_heading("1. Introduction",1)
d.add_heading("1.1 Purpose",2)
para(d,"This document describes the as-built technical design of CR# 2026-02-0585 'Exit and Movement of Employee' for Airtel Africa on Oracle EBS R12.2.14. It covers all custom database objects, PL/SQL packages, Oracle Workflow components, custom Forms, AOL registrations, concurrent programs, deployment and rollback procedures as implemented in FINUAT.")
d.add_heading("1.2 Business Summary",2)
para(d,"The solution monitors HRMS for employee Exit (termination) and Movement (ORG_ID / cost-centre Segment-3 change) events, notifies the Reporting Manager (RM) at scheduled intervals to provide a replacement employee, auto-defaults the RM as replacement when no input is received within the window, and propagates the replacement to open Purchase Requisitions, Purchase Orders, the AP CSS DOA Mapping Quality Plan, and pending Workflow notifications.")
d.add_heading("1.3 Scope",2)
bullets(d,[
 "In scope: detection, FYI notifications, 3 replacement forms, propagation engine (PR/PO/QP/WF), 2 replacement reports, BCP integration switch, staggered OU enablement.",
 "Out of scope: AME rule changes (approval logic untouched), Fusion-to-EBS sync (existing interface reused), Workflow Mailer infrastructure."])

d.add_heading("2. Solution Architecture",1)
d.add_heading("2.1 Logical Layers",2)
table(d,["Layer","Component","Implementation"],[
 ["1. Source","HRMS tables","PER_ALL_PEOPLE_F, PER_ALL_ASSIGNMENTS_F, PER_PERIODS_OF_SERVICE (read-only)"],
 ["2. Detection","Exit/Movement detector","ASI_FDOA_DETECTOR_PKG over ASI_FDOA_EXIT_EMPLOYEES_V / ASI_FDOA_MOVEMENT_EMP_V"],
 ["3. Staging","Replacement capture","BTVL.ASI_FDOA_REPLACEMENT_HDR_TBL / _DTL_TBL (+ APPS synonyms)"],
 ["4. Notification","Oracle Workflow FYI","Item type ASIFDOAN, formatted HTML via DOCUMENT attribute"],
 ["5. UI","3 custom Forms","ASI_FDOA_EXIT_FMB, ASI_FDOA_MOVEMENT_FMB, ASI_FDOA_SUPERUSER_FMB"],
 ["6. Propagation","PR/PO/QP/WF update engine","ASI_FDOA_PROPAGATION_PKG"],
 ["7. Reporting","2 replacement reports","Pipe-delimited TEXT concurrent programs (ASIFDOAMGRRPT, ASIFDOASURPT)"]],
 widths=[1.1,1.8,3.6])
d.add_heading("2.2 Process Flow",2)
bullets(d,[
 "Daily 12:00 — ASIFDOANOTIF: detector identifies employees in exit window (actual_termination_date −15..+15 days) and movement window (ORG_ID or Segment-3 change, +1..+15 days); workflow notifies RM (CC DOA Superuser group on Exit DAY_5 / Movement DAY_10_AFTER).",
 "RM enters replacement via Exit / Movement form; Superuser may override (EXIT only, within the 15-day pre-termination window).",
 "No input by last working day (Exit) / Day-16 cut-off (Movement) — RM auto-defaulted as replacement (FALLBACK).",
 "Daily 00:30 ASIFDOAPRPO and 00:35 ASIFDOAQP (after the 00:00 Fusion sync): propagate replacement to open PR lines, PO distributions / blanket header, QP approver columns; reassign pending WF notifications to the replacement."])
d.add_heading("2.3 Key Design Decisions",2)
table(d,["#","Decision","Rationale"],[
 ["1","Notification CP separated from propagation CPs","Propagation runs after the 00:00 Fusion-to-ERP sync to avoid race on actual_termination_date"],
 ["2","Oracle Workflow FYI (not direct email)","EBS standard, audit trail, CC support; HTML via DOCUMENT attribute (v1.3) to avoid WF token escaping"],
 ["3","Replacement staged in custom tables","Audit trail, override window support, backdated/cancelled scenario handling"],
 ["4","Person_ID used in QP (not AUUID)","Explicit HLD callout for AP CSS DOA Mapping"],
 ["5","RM is source of truth; SU override narrow (EXIT only)","Manager accountability with DOA correction capability"],
 ["6","Skip-level escalation for inactive RM","ASI_FDOA_HIERARCHY_PKG walks SUPERVISOR_ID chain"],
 ["7","Forms built standalone via headless Forms-XML pipeline","Forms Builder unavailable; frmxml2f + frmcmp_batch on app tier (see §9.1)"]],
 widths=[0.4,2.8,3.3])

d.add_heading("3. Database Objects — BTVL Schema (data pass)",1)
para(d,"Deployed by deploy_btvl_clean.sql, run as BTVL. No TABLESPACE/PCTFREE/STORAGE clauses (site directive). Grants are issued by BTVL; synonyms are created in the APPS pass (BTVL lacks CREATE ANY SYNONYM).")
d.add_heading("3.1 Sequences",2)
table(d,["Sequence","Purpose"],[
 ["ASI_FDOA_REPLACEMENT_S","Primary key for replacement header"],
 ["ASI_FDOA_NOTIF_LOG_S","Primary key for notification log"]],widths=[2.6,3.9])
d.add_heading("3.2 Tables",2)
table(d,["Table","Purpose","Key Columns (logical)"],[
 ["ASI_FDOA_REPLACEMENT_HDR_TBL","Header capturing replacement entries by RM or Superuser","REPLACEMENT_ID (PK), DOC_TYPE, OLD_PERSON_ID, NEW_PERSON_ID, ENTERED_BY_ROLE (RM/SU), REMARKS, ORG_ID, WHO columns"],
 ["ASI_FDOA_REPLACEMENT_DTL_TBL","Audit detail of overrides and processing status","DETAIL_ID (PK), REPLACEMENT_ID (FK), ACTION_TYPE, PROCESSED_FLAG, PROCESSED_DATE, ERROR_MSG"],
 ["ASI_FDOA_NOTIFICATION_LOG_TBL","Per-notification log; idempotency key (person + doc type + interval + key date)","LOG_ID, PERSON_ID, DOC_TYPE, NOTIF_INTERVAL, KEY_DATE, SENT_DATE, RECIPIENT, STATUS"],
 ["ASI_FDOA_PROCESSING_LOG_TBL","Run statistics of propagation batches","RUN_ID, RUN_DATE, RECORDS_PROCESSED, RECORDS_UPDATED, ERROR_COUNT"]],
 widths=[2.0,2.2,2.3])
para(d,"Authoritative column-level DDL: deploy_btvl_clean.sql.",italic=True,size=9)
d.add_heading("3.3 Indexes and Grants",2)
bullets(d,[
 "6 indexes total: 4 PK-backing + ASI_FDOA_REPLACEMENT_HDR_N1_IDX + ASI_FDOA_NOTIF_LOG_N1_IDX (post-install check expects 6).",
 "Grants to APPS: SELECT on both sequences; SELECT, INSERT, UPDATE, DELETE on all four tables (regrant_btvl.sql repairs grants).",
 "Trigger ASI_FDOA_REPLACEMENT_HDR_BIU_TRG (owned in APPS pass) maintains defaults/WHO on the header table."])

d.add_heading("4. APPS Layer (code pass)",1)
para(d,"Deployed by deploy_apps_clean.sql, run as APPS, on the same database as the BTVL pass. Contains v1.1 + v1.2 + v1.3 patch content.")
d.add_heading("4.1 Synonyms",2)
para(d,"6 synonyms APPS -> BTVL (2 sequences + 4 tables).")
d.add_heading("4.2 Views",2)
table(d,["View","Purpose / Notable implementation detail"],[
 ["ASI_FDOA_EXIT_EMPLOYEES_V","Employees with actual_termination_date within the −15..+15 day window; backs Exit form LOV. Cost-centre via pay_cost_allocation_keyflex.segment3 join (pay_cost_allocations_f has no SEGMENT3)."],
 ["ASI_FDOA_MOVEMENT_EMP_V","Employees whose latest assignment shows ORG_ID or Segment-3 change (+1..+15 days); backs Movement form LOV; exposes old/new segment3 and old_rm_supervisor_id."],
 ["ASI_FDOA_RM_DIRECT_REPORTS_V","RM direct reports at effective date (SUPERVISOR_ID); backs the replacement LOV for RM forms."],
 ["ASI_FDOA_OPEN_PR_LINES_V","Open PR lines: Approved, Pending Approval/In Process, On Hold, Requires Reapproval."],
 ["ASI_FDOA_OPEN_PO_LINES_V","Open Standard & Blanket PO lines; exposes PO_DISTRIBUTION_ID (PO requester = po_distributions_all.deliver_to_person_id; po_line_locations_all has no requester_id)."],
 ["ASI_FDOA_DOA_CC_GROUP_V","DOA Superuser group from QP; drives CC list at runtime (not hardcoded)."]],
 widths=[2.2,4.3])
d.add_heading("4.3 PL/SQL Packages",2)
table(d,["Package","Responsibility","Key Public Routines"],[
 ["ASI_FDOA_UTIL_PKG","Common helpers; OU gate","IS_OU_ENABLED (gates detector via ASI_FDOA_OU_ENABLE_LK), logging, lookup access"],
 ["ASI_FDOA_HIERARCHY_PKG","RM resolution & escalation","GET_NEXT_ACTIVE_MANAGER (skip-level via SUPERVISOR_ID), active-status checks"],
 ["ASI_FDOA_DETECTOR_PKG","Identify exit/movement candidates for run date","Exit/movement candidate cursors, backdated detection"],
 ["ASI_FDOA_NOTIFICATION_PKG","Interval evaluation + WF launch + content","LAUNCH_WORKFLOW, GET_RECIPIENT (selector), SET_EMAIL_CONTENT_EXIT/_MOVEMENT/_FALLBACK (v1.1), GEN_EMAIL_BODY_DOC (v1.3 DOCUMENT generator)"],
 ["ASI_FDOA_REPLACEMENT_PKG","Validate & persist form entries","VALIDATE_REPLACEMENT, INSERT_REPLACEMENT, OVERRIDE_BY_SUPERUSER (EXIT-only, 15-day window check; error code SU_OUTSIDE_OVERRIDE_WINDOW)"],
 ["ASI_FDOA_PROPAGATION_PKG","Apply replacement to PR/PO/QP/WF","UPDATE_PR/PO_REQUESTOR (distributions for STANDARD, header agent_id for BLANKET), UPDATE_QP_APPROVER (dynamic UPDATE over ASI_FDOA_QP_APPROVER_COLS_LK), REASSIGN_OPEN_NOTIFICATIONS (WF_NOTIFICATION.TRANSFER, v1.2)"],
 ["ASI_FDOA_MGR_REPORT_PKG","Manager replacement report (TEXT)","Report driver"],
 ["ASI_FDOA_SU_REPORT_PKG","Superuser replacement report (TEXT)","Report driver"]],
 widths=[1.7,1.9,2.9])
para(d,"Form-facing API signatures (as built):",bold=True)
code(d,"PROCEDURE INSERT_REPLACEMENT\n  ( p_doc_type              IN  VARCHAR2   -- EXIT / MOVEMENT\n  , p_old_person_id         IN  NUMBER\n  , p_new_person_id         IN  NUMBER\n  , p_role                  IN  VARCHAR2   -- 'RM'\n  , p_entered_by_person_id  IN  NUMBER\n  , p_remarks               IN  VARCHAR2\n  , p_org_id                IN  NUMBER\n  , x_replacement_id        OUT NUMBER );\n\nPROCEDURE OVERRIDE_BY_SUPERUSER\n  ( p_doc_type              IN  VARCHAR2\n  , p_old_person_id         IN  NUMBER\n  , p_new_person_id         IN  NUMBER\n  , p_entered_by_person_id  IN  NUMBER\n  , p_remarks               IN  VARCHAR2\n  , p_org_id                IN  NUMBER\n  , x_replacement_id        OUT NUMBER );")
d.add_heading("4.4 Lookups and Value Sets",2)
table(d,["Object","Type","Purpose"],[
 ["ASI_FDOA_DOC_TYPE_LK","Lookup","EXIT / MOVEMENT — drives Superuser form Document Type LOV"],
 ["ASI_FDOA_NOTIF_INTERVAL_LK","Lookup","DAY_15, DAY_10, DAY_5, LAST_DAY, DAY_1_AFTER, DAY_5_AFTER, DAY_10_AFTER, DAY_15_AFTER"],
 ["ASI_FDOA_INTEG_SWITCH_LK","Lookup","BCP/DR integration switch: ON / FUSION_ONLY / OFF"],
 ["ASI_FDOA_OU_ENABLE_LK","Lookup","Staggered OU enablement: one enabled row per live ORG_ID (template row SAMPLE_ORG_ID disabled)"],
 ["ASI_FDOA_QP_APPROVER_COLS_LK","Lookup","Approver person_id column names of ASI_AP_CSS_DOA_MAPPING_QP (consumed by UPDATE_QP_APPROVER) — seeding open (item O1/#4)"],
 ["ASI_FDOA_DOC_TYPE_VS","Value Set","Independent set EXIT/MOVEMENT/BOTH (table-validated set rejected by instance dictionary — see §13)"],
 ["ASI_FDOA_DATE_VS / _YESNO_VS / _NUM_VS","Value Sets","CP parameter validation"]],
 widths=[2.1,0.9,3.5])

d.add_heading("5. Concurrent Programs",1)
table(d,["Program (short name)","Type","Schedule","Purpose"],[
 ["ASIFDOANOTIF","PL/SQL (ASI_FDOA_NOTIF_CP_PRC)","Daily 12:00","Master driver — detection + notification orchestration"],
 ["ASIFDOAPRPO","PL/SQL","Daily 00:30","PR/PO requestor propagation (after 00:00 Fusion sync)"],
 ["ASIFDOAQP","PL/SQL","Daily 00:35","QP AP CSS DOA Mapping approver update"],
 ["ASIFDOAMGRRPT","PL/SQL — TEXT output","On demand","Manager Replacement Report (pipe-delimited)"],
 ["ASIFDOASURPT","PL/SQL — TEXT output","On demand","Superuser Replacement Report (pipe-delimited; + Remarks)"]],
 widths=[1.5,1.6,1.0,2.4])
para(d,"12 parameters across the 5 programs (run date / doc type / debug / person filter / date from-to). Both reports are executed from the Superuser responsibility per HLD §22. Scheduling is performed via SRS (Periodically, every 1 day, apply from start of prior run).")

d.add_heading("6. Workflow Design — Item Type ASIFDOAN",1)
table(d,["Property","Value"],[
 ["Internal name","ASIFDOAN"],
 ["Persistence","Persistent (FYI history retained)"],
 ["Selector","ASI_FDOA_NOTIFICATION_PKG.GET_RECIPIENT"],
 ["Processes (runnable)","EXIT_NOTIFY_PROCESS, MOVEMENT_NOTIFY_PROCESS, FALLBACK_REASSIGN_PROCESS"],
 ["Messages / notifications","3 FYI messages / 3 notification activities"],
 ["Attributes","12 — context set per LAUNCH_WORKFLOW (doc type, interval, employee id/name/number, key date, RM id/username, CC e-mails, form URL) + content set EMAIL_SUBJECT, EMAIL_BODY_HTML, EMAIL_BODY_DOC"],
 ["HTML rendering","EMAIL_BODY_DOC is a DOCUMENT attribute resolving to PLSQL:ASI_FDOA_NOTIFICATION_PKG.GEN_EMAIL_BODY_DOC/<itemtype>:<itemkey> — returns text/html (and stripped text/plain); avoids WF's HTML-escaping of VARCHAR2 tokens (v1.3)"],
 ["Dedup","Item key derived from (doc_type, person_id, interval, key_date); duplicate launch raises ORA-20002"],
 ["Deployment","WFLOAD on app tier (run edition); DB-resident definition, not editioned; no service bounce; in-flight item keys retain their start revision"]],
 widths=[1.7,4.8])
d.add_heading("6.1 Notification Schedule and CC Rules",2)
table(d,["Doc Type","Intervals","To","CC (DOA Superuser group)"],[
 ["EXIT","DAY_15, DAY_10, DAY_5, LAST_DAY (T−15/−10/−5/0)","Reporting Manager","On DAY_5 only"],
 ["MOVEMENT","DAY_1/5/10/15_AFTER (effective date +1/+5/+10/+15)","Old RM","On DAY_10_AFTER only"],
 ["FALLBACK","Last working day (Exit) / Day-16 cut-off (Movement)","RM (informed of auto-default)","—"]],
 widths=[1.0,2.4,1.6,1.5])
d.add_heading("6.2 Suppression / Exception Rules",2)
bullets(d,[
 "Replacement already provided — no further notifications.",
 "Backdated Exit/Movement — no notifications; immediate auto-default to RM (prior RM submission honoured: Movement next day, Exit after termination date).",
 "Exit cancelled (date cleared) — notifications stop, replacement nullified.",
 "Postpone — fresh evaluation against new date; old cycle abandoned.",
 "Prepone into notice window — Last-Day notification fired immediately."])

d.add_heading("7. Propagation Engine",1)
d.add_heading("7.1 Documents in Scope",2)
table(d,["Document","Treated as Open","Excluded"],[
 ["Purchase Requisition","Approved, Pending Approval / In Process, On Hold, Requires Reapproval","Cancelled, Rejected, Returned"],
 ["Purchase Order (Standard, Blanket)","In Process, Approved, Requires Reapproval, On Hold, closure status Open","Closed, Finally Closed, Cancelled"]],
 widths=[1.6,2.8,2.1])
d.add_heading("7.2 Update Mechanics",2)
bullets(d,[
 "PR: po_requisition_lines_all.to_person_id = new person.",
 "PO Standard: po_distributions_all.deliver_to_person_id; PO Blanket: header agent_id.",
 "QP: dynamic UPDATE over ASI_AP_CSS_DOA_MAPPING_QP for every approver column listed in ASI_FDOA_QP_APPROVER_COLS_LK where value = old person_id; all occurrences updated; approved/cancelled/rejected invoices skipped.",
 "WF: pending notifications reassigned via WF_NOTIFICATION.TRANSFER (v1.2). Notification lookup path: wf_item_activity_statuses (wf_notifications has no item_type/item_key).",
 "Approval flows are NOT re-initiated; only the person identifier changes. Failures are isolated per employee; the batch continues."])
d.add_heading("7.3 Trigger Timing",2)
bullets(d,[
 "Exit — day after actual_termination_date (RM-provided, auto-default, or SU override value).",
 "Movement — day after RM submission; Day 17 (effective_date + 17) with RM default when no input."])

d.add_heading("8. BCP / Integration Switch and OU Enablement",1)
bullets(d,[
 "ASI_FDOA_INTEG_SWITCH_LK: ON (normal), FUSION_ONLY, OFF — consulted by the detector/propagation layer for DR scenarios.",
 "ASI_FDOA_OU_ENABLE_LK: detector processes only ORG_IDs with an enabled row (ASI_FDOA_UTIL_PKG.IS_OU_ENABLED); enables staggered OPCO go-live. Template row SAMPLE_ORG_ID ships disabled."])

d.add_heading("9. Custom Forms",1)
d.add_heading("9.1 Build Approach — Headless Forms-XML Pipeline",2)
para(d,"All three forms are standalone Forms 10.1.2 modules built without Forms Builder: hand-maintained Forms-XML converted on the application tier with frmxml2f.sh and compiled with frmcmp_batch (userid=apps). Known constraint: frmxml2f cannot rebuild TEMPLATE/APPSTAND-subclassed modules (Jdapi NPE), hence the standalone design — standard EBS toolbar/calendar/folder behaviour is not available; FND_STANDARD.FORM_INFO, APP_STANDARD events and APP_CUSTOM are wired in and the attached libraries (APPCORE, FNDSQF, CUSTOM, etc.) resolve at compile time via FORMS_PATH.")
code(d,"export O_JDK_HOME=$ORACLE_HOME/jdk\nexport FORMS_API_TK_BYPASS=TRUE\nexport FORMS_PATH=$AU_TOP/forms/US:$FORMS_PATH\nfrmxml2f.sh OVERWRITE=YES <FORM>.xml\nfrmcmp_batch module=<FORM>.fmb userid=apps/*** output_file=<FORM>.fmx \\\n  module_type=form compile_all=special")
para(d,"Design rules applied to all three modules: static record groups with explicit columns (query record groups lose their columns in headless conversion), repopulated on every LOV invocation in KEY-LISTVAL via POPULATE_GROUP_WITH_QUERY (values concatenated, not :item binds); LOV column mappings keyed to record-group column names; hidden _PERSON_ID return items; WHO/context from FND_GLOBAL.")
d.add_heading("9.2 ASI_FDOA_EXIT_FMB — RM Exit Replacement",2)
table(d,["Item","Type","Notes"],[
 ["DOC_TYPE_DISPLAY","Display (Char)","Fixed 'EXIT' at WHEN-NEW-FORM-INSTANCE"],
 ["OLD_EMPLOYEE_DISP","Text + LOV_OLD_EMP_EXIT","Exiting direct reports (supervisor_id = logged person); WVI validates person against ASI_FDOA_EXIT_EMPLOYEES_V"],
 ["ACTUAL_TERM_DATE / DEPARTMENT","Display","Returned by LOV"],
 ["NEW_EMPLOYEE_DISP","Text + LOV_NEW_EMP_RM","RM direct reports + '*** Self (RM) ***'; WVI blocks Old = New"],
 ["REMARKS","Text (2000, multiline)","Optional"],
 ["SAVE_BTN / EXIT_BTN","Buttons","Save calls INSERT_REPLACEMENT (p_doc_type='EXIT', p_role='RM'); commit; confirmation with replacement id; clear"]],
 widths=[1.7,1.7,3.1])
d.add_heading("9.3 ASI_FDOA_MOVEMENT_FMB — RM Movement Replacement",2)
para(d,"Structurally identical to the Exit form. Differences: DOC_TYPE_DISPLAY fixed 'MOVEMENT'; LOV_OLD_EMP_MOVE over ASI_FDOA_MOVEMENT_EMP_V (filter old_rm_supervisor_id = logged person) returning EFFECTIVE_DATE, OLD_DEPARTMENT and NEW_DEPARTMENT displays; save calls INSERT_REPLACEMENT with p_doc_type='MOVEMENT'.")
d.add_heading("9.4 ASI_FDOA_SUPERUSER_FMB — Combined Superuser Form",2)
table(d,["Item","Type","Notes"],[
 ["DOC_TYPE","Text + LOV_DOC_TYPE","LOV over ASI_FDOA_DOC_TYPE_LK (EXIT/MOVEMENT); defaults EXIT; WVI clears Old/New/Key Date on change"],
 ["OLD_EMPLOYEE_DISP","Text + LOV_OLD_EMP_SU","Org-wide; LOV branches on DOC_TYPE (exit view / movement view); returns KEY_DATE"],
 ["KEY_DATE","Display (Date)","Termination or effective date"],
 ["NEW_EMPLOYEE_DISP","Text + LOV_NEW_EMP_SU","All active employees org-wide (PER_ALL_PEOPLE_F / ASSIGNMENTS, ACTIVE_ASSIGN)"],
 ["REMARKS","Text (2000, multiline)","Optional; SU remarks not visible to RM and vice-versa (visibility rule §8.3 SSD)"],
 ["SAVE_BTN / EXIT_BTN","Buttons","Save calls OVERRIDE_BY_SUPERUSER; backend enforces EXIT-only within 15-day window (SU_OUTSIDE_OVERRIDE_WINDOW)"]],
 widths=[1.7,1.7,3.1])

d.add_heading("10. AOL Registration",1)
table(d,["Object","Name","Detail"],[
 ["Forms (3)","ASI_FDOA_{EXIT,MOVEMENT,SUPERUSER}_FMB","Application BTVL; .fmx in $BTVL_TOP/forms/US"],
 ["Functions (3)","ASI_FDOA_{EXIT,MOVEMENT,SUPERUSER}_FN","Type FORM; context dependence RESP"],
 ["Menu","ASI_FDOA_MGR_MN","Entries: Exit Replacement, Movement Replacement"],
 ["Menu","ASI_FDOA_SU_MN","Entry: Superuser Replacement"],
 ["Attach","Airtel Africa Manager Responsibility Approvals","Root menu += ASI_FDOA_MGR_MN, prompt 'ASI FDOA Replacement'"],
 ["Attach","ASI Invoice DOA Access","Root menu += ASI_FDOA_SU_MN, prompt 'ASI FDOA Replacement'"],
 ["Post-step","Compile Security (FNDSCMPI)","Submitted after attach"]],
 widths=[1.1,2.4,3.0])
para(d,"Registered via asi_fdoa_aol_access.sql (idempotent, self-reporting). Instance specifics: FND_MENUS has no MENU_TYPE column; responsibility lookup must use responsibility_name via FND_RESPONSIBILITY_VL.")

d.add_heading("11. Error Handling and Logging",1)
bullets(d,[
 "Concurrent programs: FND_FILE run-level summary; verbose per-employee lines in DEBUG mode.",
 "ASI_FDOA_PROCESSING_LOG_TBL: per-run statistics (candidates, notifications, updates, errors).",
 "ASI_FDOA_NOTIFICATION_LOG_TBL: per-notification record = idempotency key (no duplicate person+interval).",
 "Propagation failures isolated per employee; workflow errors via WF Background Engine retry.",
 "Forms: user errors raised via FND_MESSAGE with 'CR# 2026-02-0585' prefix; unexpected errors rolled back and surfaced from SQLERRM."])

d.add_heading("12. Deployment and Rollback",1)
d.add_heading("12.1 Clean Install Order",2)
code(d,"STEP 1   as APPS   @teardown_apps.sql         (skip on clean schema)\nSTEP 2   as BTVL   @teardown_btvl.sql         (skip on clean schema)\nSTEP 3   as BTVL   @deploy_btvl_clean.sql     2 seq, 4 tbl, 2 idx, grants\nSTEP 3b  as BTVL   @regrant_btvl.sql\nSTEP 4   as APPS   @deploy_apps_clean.sql     synonyms, trigger, lookups, VS, views, pkgs, CPs\nSTEP 5   as APPS   @post_install_checks.sql   expect 0 invalid; counts as inventory\nSTEP 6   app tier  WFLOAD apps/*** 0 Y UPLOAD ASIFDOAN.wft\nSTEP 7   app tier  forms pipeline (see 9.1) x3 ; cp *.fmx $BTVL_TOP/forms/US/\nSTEP 8   as APPS   @asi_fdoa_aol_access.sql ; Compile Security\nSTEP 9   SRS       schedule ASIFDOANOTIF 12:00 / ASIFDOAPRPO 00:30 / ASIFDOAQP 00:35")
para(d,"All BTVL/APPS steps must run on the same database. Workflow definitions are DB-resident (not editioned): run-edition load or hotpatch when shipped inside a patch; no oacore/apache bounce; in-flight items keep their start revision.")
d.add_heading("12.2 Rollback",2)
bullets(d,[
 "DB: teardown_apps.sql + teardown_btvl.sql (full removal) or re-run prior deploy scripts.",
 "Workflow: reload the previously DOWNLOADed ASIFDOAN.wft (always capture current definition before load).",
 "Forms: remove .fmx from $BTVL_TOP/forms/US; AOL entries are idempotent rows that can be end-dated/deleted by reversing asi_fdoa_aol_access.sql inserts.",
 "CP schedules: cancel pending scheduled requests."])

d.add_heading("13. Environment Notes / Known Instance Quirks (FINUAT)",1)
bullets(d,[
 "SQL Developer Run Script (F5): scripts must be fully inline — no PROMPT, no @@ includes; WHENEVER SQLERROR CONTINUE; self-reporting OK-/FAIL- blocks.",
 "BTVL schema locked down: no user_objects/dba_objects access — checks use explicit object names.",
 "GRANT ... TO APPS must run as BTVL (ORA-01749 otherwise); no storage clauses anywhere.",
 "FND_LOOKUP_TYPES is base + _TL on this instance; value sets need PROTECTED_FLAG and SECURITY_ENABLED_FLAG; table-validated sets need COMPILED_ATTRIBUTE_COLUMN_NAME (hence independent ASI_FDOA_DOC_TYPE_VS).",
 "FND_PROGRAM.register: style=>/output_type=>, application => display name from fnd_application_vl; parameter token=>NULL; display_size <= value-set maximum_size.",
 "FND_MENUS has no MENU_TYPE column; responsibility attach via responsibility_name (FND_RESPONSIBILITY_VL).",
 "WF Builder 2.6.3 cannot connect to 19c (ORA-28040) — offline edits + WFLOAD only; VARCHAR2 attribute format cap 4000.",
 "frmxml2f cannot rebuild EBS-template (APPSTAND-subclassed) forms — standalone form design is mandatory for the headless pipeline."])

d.add_heading("14. Open Items",1)
table(d,["#","Item","Owner","Status"],[
 ["O1 / #4","Seed ASI_FDOA_QP_APPROVER_COLS_LK from actual ASI_AP_CSS_DOA_MAPPING_QP column names","Functional / Tech","Parked until QP object exists in instance"],
 ["#6","Execute SRS schedules (12:00 / 00:30 / 00:35)","DBA / Tech","Steps provided"],
 ["#7","Enable live ORG_IDs in ASI_FDOA_OU_ENABLE_LK","Business / Tech","At go-live"],
 ["O2","'Long leave' threshold for RM-inactive rule","Business","Open"],
 ["O3","Blanket Releases in scope for requestor update?","Business","Open"]],
 widths=[0.8,3.0,1.3,1.4])

d.save("LLD_CR2026020585_Exit_and_Movement_of_Employee.docx")
print("LLD saved:", len(d.paragraphs), "paragraphs")
