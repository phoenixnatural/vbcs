cd /home/appluat
export O_JDK_HOME=$ORACLE_HOME/jdk
export FORMS_API_TK_BYPASS=TRUE
export FORMS_PATH=$AU_TOP/forms/US:$FORMS_PATH

# Regenerate reference XMLs from the real EBS source forms
cp -f $AU_TOP/forms/US/TEMPLATE.fmb .
cp -f $AU_TOP/forms/US/APPSTAND.fmb .
frmf2xml.sh OVERWRITE=YES TEMPLATE.fmb 2>/dev/null
frmf2xml.sh OVERWRITE=YES APPSTAND.fmb 2>/dev/null

echo "===== 1. PROPERTY CLASSES available in APPSTAND ====="
grep -o -E '<PropertyClass Name="[^"]*"' APPSTAND_fmb.xml 2>/dev/null | sort -u

echo ""
echo "===== 2. ALL Subclass/Parent-style attribute NAMES used in TEMPLATE ====="
grep -o -E '(Subclass[A-Za-z]*|Parent[A-Za-z]*|Source[A-Za-z]*)="[^"]*"' TEMPLATE_fmb.xml 2>/dev/null | sed -E 's/="[^"]*"//' | sort | uniq -c

echo ""
echo "===== 3. SAMPLE: first 3 TEMPLATE Items that carry subclass/parent attrs ====="
grep -o -E '<Item [^>]*(Subclass|Parent|Source)[A-Za-z]*="[^>]*/?>' TEMPLATE_fmb.xml 2>/dev/null | head -3

echo ""
echo "===== 4. SAMPLE: a TEXT_ITEM / DISPLAY_ITEM property class definition (first 1) ====="
grep -o -E '<PropertyClass Name="(TEXT_ITEM|DISPLAY_ITEM|DATE|BUTTON)"[^>]*>' APPSTAND_fmb.xml 2>/dev/null | head -2
