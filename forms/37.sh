cd /home/appluat
export O_JDK_HOME=$ORACLE_HOME/jdk
export FORMS_API_TK_BYPASS=TRUE
export FORMS_PATH=$AU_TOP/forms/US:$FORMS_PATH
for f in ASI_FDOA_EXIT_FMB ASI_FDOA_MOVEMENT_FMB ASI_FDOA_SUPERUSER_FMB
do
  frmxml2f.sh OVERWRITE=YES $f.xml
  frmcmp_batch module=$f.fmb userid=apps/CHANGEME output_file=$f.fmx module_type=form compile_all=special 2>&1 | tail -4
done
ls -l ASI_FDOA_EXIT_FMB.fmx ASI_FDOA_MOVEMENT_FMB.fmx ASI_FDOA_SUPERUSER_FMB.fmx
cp ASI_FDOA_EXIT_FMB.fmx ASI_FDOA_MOVEMENT_FMB.fmx ASI_FDOA_SUPERUSER_FMB.fmx $BTVL_TOP/forms/US/
echo "staged:"
ls -l $BTVL_TOP/forms/US/ASI_FDOA_*.fmx
