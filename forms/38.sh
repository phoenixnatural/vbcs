cd /home/appluat
export O_JDK_HOME=$ORACLE_HOME/jdk
export FORMS_API_TK_BYPASS=TRUE
export FORMS_PATH=$AU_TOP/forms/US:$FORMS_PATH

echo "=== GROUND TRUTH: how TEMPLATE_fmb.xml expresses item colors ==="
grep -o -E '[A-Za-z]*[Cc]olor="[^"]*"' TEMPLATE_fmb.xml | sort | uniq -c | head -20
echo "=== (if nothing above, colors are via VisualAttribute - show one) ==="
grep -i -o -E '<VisualAttribute[^>]*>' TEMPLATE_fmb.xml | head -3
echo "==============================================================="

for f in ASI_FDOA_EXIT_FMB ASI_FDOA_MOVEMENT_FMB ASI_FDOA_SUPERUSER_FMB
do
  echo "----- $f -----"
  sed -i -E 's/ (BackgroundColor|ForegroundColor)="[^"]*"//g' $f.xml
  frmxml2f.sh OVERWRITE=YES $f.xml
  frmcmp_batch module=$f.fmb userid=apps/CHANGEME output_file=$f.fmx module_type=form compile_all=special 2>&1 | tail -3
done
echo "=== built .fmx ==="
ls -l ASI_FDOA_EXIT_FMB.fmx ASI_FDOA_MOVEMENT_FMB.fmx ASI_FDOA_SUPERUSER_FMB.fmx
cp ASI_FDOA_EXIT_FMB.fmx ASI_FDOA_MOVEMENT_FMB.fmx ASI_FDOA_SUPERUSER_FMB.fmx $BTVL_TOP/forms/US/
echo "=== staged ==="
ls -l $BTVL_TOP/forms/US/ASI_FDOA_*.fmx
