---
name: ebs-headless-forms-xml
description: Build Oracle EBS R12.2 custom Forms (.fmb/.fmx) entirely headless on the app tier — no Forms Builder client — by authoring/repairing Forms-XML and converting with frmxml2f + frmcmp_batch. Use when Forms Builder is unavailable (corporate laptop restrictions, 19c ORA-28040 connect issues) and a custom form must be delivered on an EBS R12.2 instance. Covers the proven failure modes (Jdapi NPE on template-subclassed forms, FRM-30049 record-group columns, XML-24535 schema rejects) and their fixes.
---

# Headless Oracle EBS Forms build via Forms-XML (R12.2 / Forms 10.1.2)

Proven end-to-end on EBS R12.2.14, Forms 10.1.2.3.0, 19c DB (FINUAT, CR-2026-02-0585):
hand-maintained Forms-XML → `frmxml2f.sh` → `.fmb` → `frmcmp_batch` → `.fmx`,
with zero Forms Builder involvement.

## Hard constraints (do not relitigate — each cost a failed round)

1. **`frmxml2f` CANNOT rebuild an EBS TEMPLATE/APPSTAND-subclassed form.**
   It dies with `ERROR - an exception has been encountered: null` (swallowed Jdapi
   NPE, no stack trace). Decisive proof: the *pristine, unedited* XML that
   `frmf2xml` produces from `TEMPLATE.fmb` itself fails the same way.
   `FORMS_API_TK_BYPASS=TRUE` does NOT fix it. **Only standalone
   (non-template) forms work headless.** Consequence: no standard EBS
   toolbar/menu/calendar/folder behavior — flag this in the CR if a standards
   review applies.
2. **Query-type record groups get ZERO columns when converted headless.**
   The converter needs a DB session to describe the query
   (`No database connection, Record Group Column X not found`), ignores any
   declared columns on Query groups, and the compile later fails with
   `FRM-30049: Unable to build column mapping` on the LOV. Fix in §4 step 5.
3. The converter validates against the Forms XML schema strictly
   (`XML-24535: Attribute 'X' not expected`). Known offenders are listed in §4.

## 1. Environment (app tier, run edition, all in one session)

```sh
export O_JDK_HOME=$ORACLE_HOME/jdk        # default inside frmf2xml/frmxml2f may be a clone leftover path
export FORMS_API_TK_BYPASS=TRUE
export FORMS_PATH=$AU_TOP/forms/US:$FORMS_PATH
```

Tools used: `$ORACLE_HOME/bin/frmf2xml.sh`, `frmxml2f.sh`, `frmcmp_batch`.

## 2. Probe first (always, ~1 minute)

Before authoring anything, prove the converter works on this install with a
minimal standalone form. If THIS fails, the route is dead on that node — stop.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Module version="101020002" xmlns="http://xmlns.oracle.com/Forms">
<FormModule Name="PROBE_FMB">
<Coordinate CharacterCellWidth="9" CharacterCellHeight="18" CoordinateSystem="Real" RealUnit="Point"/>
<Window Name="WIN1" Width="400" Height="200"/>
<Canvas Name="CVS1" WindowName="WIN1" CanvasType="Content" Width="400" Height="200"/>
<Block Name="CTRL" DatabaseBlock="false">
<Item Name="TXT1" ItemType="Text Item" DataType="Char" MaximumLength="30" CanvasName="CVS1" XPosition="20" YPosition="20" Width="120" Height="18"/>
</Block>
</FormModule>
</Module>
```

```sh
frmxml2f.sh OVERWRITE=YES PROBE_FMB.xml          # expect: Module saved as PROBE_FMB.fmb
frmcmp_batch module=PROBE_FMB.fmb userid=apps/<pwd> \
  output_file=PROBE_FMB.fmx module_type=form compile_all=special
```

## 3. Authoring rules for the XML (write it clean; don't repair later)

- Root: `<Module version="101020002" xmlns="http://xmlns.oracle.com/Forms">`.
- One element per line (keeps every later grep/sed line-based and safe).
- **Never include:** `Parent*` attributes (ParentModule/ParentName/…),
  `ObjectGroup`/`ObjectGroupChild` elements, anything with
  `SubclassObjectGroup="true"` (CALENDAR/PROGRESS_INDICATOR blocks+canvases,
  TOOLBAR/STANDARD_DAYS_LABELS/ARABIC_DAYS_LABELS canvases, POPUP/POPUP_FOLDER
  menus, APPCORE_* module parameters, CALENDAR_* visual attributes,
  CALENDAR_CELL property class, APPCORE_TO_CALENDAR trigger).
- **LOVs:** no `AutomaticDisplay/AutomaticRefresh/AutomaticSelect/
  AutomaticPosition/AutomaticColumnWidth` attributes (schema reject XML-24535).
  `LOVColumnMapping Name=` must match a record-group column name exactly;
  `DisplayWidth="0"` hides a return-only column; `ReturnItem="BLOCK.ITEM"`.
- **Record groups — the headless pattern:**
  - `RecordGroupType="Static"` with explicit columns:
    `<RecordGroupColumn Name="PERSON_ID" ColumnDataType="Number"/>`
    `<RecordGroupColumn Name="EMP_DISP" ColumnDataType="Character" MaximumLength="240"/>`
    (`ColumnDataType` ∈ Character|Number|Date — NOT `DataType`, NOT `Char`).
  - Populate at runtime in KEY-LISTVAL, then invoke the standard event:
    ```
    DECLARE n NUMBER; BEGIN
      n := POPULATE_GROUP_WITH_QUERY('RG_X',
           'SELECT ... FROM apps.my_view WHERE key = ' || :BLK.CONTEXT_ITEM
           || ' ORDER BY 2');
      APP_STANDARD.EVENT('KEY-LISTVAL');
    END;
    ```
    Build the query by **concatenation**, not `:item` binds, and double the
    single quotes for SQL literals inside the PL/SQL string.
    This re-queries on every LOV open — same behavior as a design-time
    query record group.
- Trigger PL/SQL goes in `TriggerText="..."` attributes; encode newlines as
  `&amp;#10;` or write single-line PL/SQL. Server-side calls
  (`FND_GLOBAL`, custom APPS packages) compile fine because `frmcmp_batch`
  runs with `userid=apps/...`.

## 4. Repairing an existing template-derived XML (sed sequence, in this order)

When inheriting an XML that was generated against TEMPLATE.fmb:

```sh
cp FORM.xml FORM.xml.bak
# 1. LOV Automatic* attrs (schema reject)
sed -i -E 's/ Automatic(Display|Refresh|Select|Position|ColumnWidth)="[^"]*"//g' FORM.xml
# 2. subclass linkage
sed -i -E 's/ Parent[A-Za-z]+="[^"]*"//g' FORM.xml
# 3. object groups (line-based; do NOT use /a,/b/d ranges on self-closing tags)
sed -i -E '/<\/?ObjectGroup(Child)?[ >/]/d' FORM.xml
# 4. subclassed furniture: self-closing sweep FIRST, then container ranges
sed -i '/SubclassObjectGroup="true"\/>/d' FORM.xml
sed -i '/<Block Name="CALENDAR"/,/<\/Block>/d' FORM.xml
sed -i '/<Block Name="PROGRESS_INDICATOR"/,/<\/Block>/d' FORM.xml
sed -i '/<Canvas Name="STANDARD_DAYS_LABELS"/,/<\/Canvas>/d' FORM.xml
sed -i '/<Canvas Name="ARABIC_DAYS_LABELS"/,/<\/Canvas>/d' FORM.xml
sed -i '/<Canvas Name="TOOLBAR"/,/<\/Canvas>/d' FORM.xml
sed -i '/<Canvas Name="PROGRESS_INDICATOR" SubclassObjectGroup/,/<\/Canvas>/d' FORM.xml
sed -i '/<Menu Name="POPUP" SubclassObjectGroup/,/<\/Menu>/d' FORM.xml
sed -i '/<Menu Name="POPUP_FOLDER" SubclassObjectGroup/,/<\/Menu>/d' FORM.xml
grep -c SubclassObjectGroup FORM.xml     # must be 0; grep -n any leftovers and range-delete them
# 5. record groups: Query -> Static (+ add RecordGroupColumn children per §3,
#    + rewrite KEY-LISTVAL to POPULATE_GROUP_WITH_QUERY per §3)
sed -i 's#RecordGroupType="Query" RecordGroupQuery="[^"]*"#RecordGroupType="Static"#' FORM.xml
```

Then convert + compile:

```sh
frmxml2f.sh OVERWRITE=YES FORM.xml
frmcmp_batch module=FORM.fmb userid=apps/<pwd> \
  output_file=FORM.fmx module_type=form compile_all=special
```

## 5. Reading the output

| Symptom | Meaning / action |
|---|---|
| `XML-24535 Attribute 'X' not expected` | Schema reject — remove/rename the attribute (see §3/§4). |
| `WARNING: Forms Object X ... subclassed from parent module` then `null` | Subclass remnant survived — find it (`grep -n SubclassObjectGroup`, `grep -n Parent`) and delete the whole element. |
| `ERROR - an exception ... null` with no warning | Unresolvable construct remains; bisect, or re-probe (§2) to confirm the tool itself. |
| `No database connection, Record Group Column X not found` | Informational on Query groups; if it persists after the Static conversion, the column names don't match the LOV mappings. |
| `FRM-30049 Unable to build column mapping` (compile) | Record group has no columns or names mismatch the `LOVColumnMapping`s — apply §3 record-group pattern. |
| `FRM-30085 Unable to adjust form for output` | Follows 30049; fix the root cause above it. |
| Triggers all `No compilation errors` but form not created | Structural (LOV/RG) problem, not PL/SQL — don't touch trigger code. |

## 6. Operational gotchas (user-side)

- Restricted bastion shells may reject heredocs/multi-line paste
  (`Multiline input command must end with a new line character`):
  build files with one `echo '…' >>` per line, or have the user `vi` a
  script and `sh` it.
- Never hand the user a literal `<pwd>`/`<placeholder>` inside a command —
  the shell parses `<pwd` as input redirection (`pwd: No such file or
  directory`). Say explicitly: replace including the angle brackets.
- In sed, use `#` as the substitution delimiter (SQL contains `||`); `&` is
  special in replacements; put long substitutions in a `fix.sed` file and run
  `sed -i -f fix.sed` to dodge shell quoting entirely — and tell the user
  fix.sed is a separate file to create.
- Self-closing vs container tags: never start a `/a/,/b/d` range on a pattern
  that can match a self-closing tag — it deletes to the next close tag or EOF.
  Sweep self-closing lines first.
- Back up (`cp FORM.xml FORM.xml.bakN`) before every sed round; copy the final
  working XML off the app tier — it is the source of truth for the form.
- Deploy: `.fmx` → `$CUSTOM_TOP/forms/US/`; register form/function/menu via
  AOL afterwards. Form source control: keep the XML, not just the fmb.
