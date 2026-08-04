#!/bin/bash
# Distributed E-Maj
# Regression tests

#---------------------------------------------#
#            Parameters definition            #
#---------------------------------------------#

# Source emaj_tools.profile
. `dirname ${0}`/dist_emaj_tools.profile

# DIST_EMAJ_REGTEST_STANDART            : Contains the sequence of sql scripts of the "standart" regression test
# DIST_EMAJ_REGTEST_STANDART_PGVER      : Contains the PostgreSQL versions on which the "standart" regression test can be run
# DIST_EMAJ_REGTEST_UNINSTALL           : Contains the sequence of sql scripts of the "uninstall" regression test
# DIST_EMAJ_REGTEST_MENU_ACTIONS        : Contains the functions to be executed according to the regression test and the PostgreSQL version (do not fill this array)
# DIST_EMAJ_REGTEST_MENU                : Contains the menu's entries (do not fill this array)
typeset -r DIST_EMAJ_REGTEST_STANDART=('install' 'setup' 'create_drop' 'start_stop' 'rollback' 'misc' 'viewer' 'adm' 'check' 'cleanup')
typeset -r DIST_EMAJ_REGTEST_STANDART_PGVER='14 17 18 19'
typeset -r DIST_EMAJ_REGTEST_UNINSTALL=('install' 'setup' 'before_uninstall' 'uninstall' 'install' 'cleanup')
typeset -r DIST_EMAJ_REGTEST_UNINSTALL_PGVER=(18)

declare -A DIST_EMAJ_REGTEST_MENU_ACTIONS
declare -A DIST_EMAJ_REGTEST_MENU

#---------------------------------------------#
#            Functions definition             #
#---------------------------------------------#

# Function reg_test_version(): regression tests for one postgres version
# arguments: $1 pg major version
#            $2 emaj_sched suffix
reg_test_version()
{
# Get vars for a specific version of PostgreSQL and its cluster
  pg_getvars ${1}
# symbolic link will be used to call pgdump in cleanup.sql script
  ln -sfT ${PGBIN} ${DIST_EMAJ_DIR}/test/${1}/bin

# Regression test by itself - Fully inspired by pg_regress.c (in the PostgreSQL sources)
  echo
  echo "Run regression test on Postgres ${1}"
  echo '============== dropping database "regression"         =============='
  ${PGBIN}/psql -c "DROP DATABASE IF EXISTS regression;"
  echo '============== creating database "regression"         =============='
  ${PGBIN}/psql -c "CREATE DATABASE regression TEMPLATE=template0 LC_COLLATE='C' LC_CTYPE='C';"
  ${PGBIN}/psql -c "ALTER DATABASE regression SET lc_messages TO 'C';\
  ALTER DATABASE regression SET lc_monetary TO 'C';                  \
  ALTER DATABASE regression SET lc_numeric TO 'C';                   \
  ALTER DATABASE regression SET lc_time TO 'C';                      \
  ALTER DATABASE regression SET bytea_output TO 'hex';               \
  ALTER DATABASE regression SET timezone_abbreviations TO 'Default';"
  echo '============== running regression test queries        =============='
  DIFF_FILE="${DIST_EMAJ_DIR}/test/${1}/regression.diffs"
  OUT_FILE="${DIST_EMAJ_DIR}/test/${1}/regression.out"
  >${DIFF_FILE}
  >${OUT_FILE}
  CMP_FAILED=0
  CMP_REGTEST=0
  if [ ! -d "${DIST_EMAJ_DIR}/test/${1}/results" ]; then
    mkdir "${DIST_EMAJ_DIR}/test/${1}/results"
  fi
  eval DIST_EMAJ_REGTESTS='${DIST_EMAJ_REGTEST_'${2^^}'[@]}'
  unset LC_COLLATE LC_CTYPE LC_MONETARY LC_NUMERIC LC_TIME
  unset LANG LANGUAGE LC_ALL
  for REGTEST in ${DIST_EMAJ_REGTESTS}; do
    REGTEST_FILE="${DIST_EMAJ_DIR}/test/${1}/sql/${REGTEST}.sql"
    RESULTS_FILE="${DIST_EMAJ_DIR}/test/${1}/results/${REGTEST}.out"
    EXPECTED_FILE="${DIST_EMAJ_DIR}/test/${1}/expected/${REGTEST}.out"
    ALIGN="printf ' %.0s' {1.."$((25-${#REGTEST}))"}"
    echo -n "test ${REGTEST}$(eval ${ALIGN})... " | tee -a ${OUT_FILE}
    PGOPTIONS="-c intervalstyle=postgres_verbose" LC_MESSAGES='C' PGTZ='PST8PDT' PGDATESTYLE='Postgres, MDY' ${PGBIN}/psql regression -X -q --echo-all <${REGTEST_FILE} >${RESULTS_FILE} 2>&1
    let CMP_REGTEST++
    diff -C3 ${EXPECTED_FILE} ${RESULTS_FILE} >> ${DIFF_FILE}
    if [ $? -ne 0 ]; then
      REGTEST_STATUS='FAILED'
      let CMP_FAILED++
    else
      REGTEST_STATUS='ok'
    fi
    echo ${REGTEST_STATUS} | tee -a ${OUT_FILE}
  done
  echo
  echo '======================='
  echo " ${CMP_FAILED} of ${CMP_REGTEST} tests failed."
  echo '======================='
  echo
  echo "The differences that caused some tests to fail can be viewed in the"
  echo "file \"${DIFF_FILE}\".  A copy of the test summary that you see"
  echo "above is saved in the file \"${OUT_FILE}\"."

# end of the regression test
  rm ${DIST_EMAJ_DIR}/test/${1}/bin
  return 0
}

#---------------------------------------------#
#                  Script body                #
#---------------------------------------------#

# update the dist_emaj.control files with the proper emaj version
echo "Customizing dist_emaj.control files..."

for PGUSERVER in ${DIST_EMAJ_USER_PGVER[@]//.}; do
# Get PGSHARE for a specific version
  pg_getvar ${PGUSERVER} PGSHARE
  sudo cp ${DIST_EMAJ_DIR}/dist_emaj.control ${PGSHARE}/extension/.
  sudo sed -ri "s|^directory\s+= .*$|directory = '${DIST_EMAJ_DIR}/sql/'|" ${PGSHARE}/extension/dist_emaj.control
done

# choose a test
echo " "
echo "--- E-Maj regression tests ---"
echo " "
echo "Available tests:"
echo "----------------"

#---------------------#
# BUILD THE TEST MENU # 
#---------------------#
# Overlap of NENU_KEY* values are not controlled
# MENU_KEY_1STREGTEST_STANDART      : 1st letter attributed in the menu to execute a "standart" test for a specific PostgreSQL version
# MENU_KEY_ALLREGTEST_STANDART      : Letter attributed in the menu to execute the "standart" test foreach PostgreSQL versions
# MENU_KEY_1STREGTEST_DUMP_RESTORE  : 1st letter attributed in the menu to execute a "dump and restore" test for a specific PostgreSQL version
# MENU_KEY_1STREGTEST_PSQL          : 1st letter attributed in the menu to execute a "psql install" test for a specific PostgreSQL version
# MENU_KEY_1STREGTEST_NON_SUPERUSER : 1st letter attributed in the menu to execute a "psql non superuser install" test for a specific PostgreSQL version
# MENU_KEY_1STREGTEST_UNINSTALL     : 1st letter attributed in the menu to execute a "uninstall" test for a specific PostgreSQL version
# MENU_KEY_1STREGTEST_UNINST_PSQL   : 1st letter attributed in the menu to execute a "uninstall_psql" test for a specific PostgreSQL version
# MENU_KEY_1STREGTEST_PGUPGRADE     : 1st letter attributed in the menu to execute a "pg_upgrade" test for a specific PostgreSQL version
# MENU_KEY_1STREGTEST_UPGRADE       : 1st letter attributed in the menu to execute an "E-Maj upgrade" test for a specific PostgreSQL version
# MENU_KEY_ALLREGTEST_UPGRADE       : Letter attributed in the menu to execute the "E-Maj upgrade" test foreach PostgreSQL versions
# MENU_KEY_1STREGTEST_UPG_OLDEST    : 1st letter attributed in the menu to execute an "E-Maj upgrade from oldest version" test for a specific PostgreSQL version
# MENU_KEY_1STREGTEST_MIXED         : 1st letter attributed in the menu to execute a "mixed with E-Maj upgrade" test for a specific PostgreSQL version

MENU_KEY_1STREGTEST_STANDART='a'
MENU_KEY_ALLREGTEST_STANDART='t'
MENU_KEY_1STREGTEST_DUMP_RESTORE='m'
#MENU_KEY_1STREGTEST_PSQL='p'
#MENU_KEY_1STREGTEST_NON_SUPERUSER='q'
MENU_KEY_1STREGTEST_UNINSTALL='r'
#MENU_KEY_1STREGTEST_UNINST_PSQL='s'
#MENU_KEY_1STREGTEST_PGUPGRADE='u'
#MENU_KEY_1STREGTEST_UPGRADE='A'
#MENU_KEY_ALLREGTEST_UPGRADE='T'
#MENU_KEY_1STREGTEST_UPG_OLDEST='U'
#MENU_KEY_1STREGTEST_MIXED='V'

# STANDART TEST
# Convert the first letter in decimal number to facilitate the incrementations
nCHAR=`printf '%d' \'${MENU_KEY_1STREGTEST_STANDART}`
TODISPLAY=0
for PGMENUVER in ${DIST_EMAJ_REGTEST_STANDART_PGVER[@]}; do
  for PGUSERVER in ${DIST_EMAJ_USER_PGVER[@]//.}; do
    if [ "${PGMENUVER//.}" == "${PGUSERVER}" ]; then
      # decimal to ASCII char
      MENU_KEY=`printf '\'$(printf "%03o" ${nCHAR})`
      # store the menu's entry
      DIST_EMAJ_REGTEST_MENU[${MENU_KEY}]=$(printf "pg %s (port %d) standart test" ${PGMENUVER} $(pg_dspvar ${PGMENUVER//.} PGPORT))
      # store the associated function to execute
      DIST_EMAJ_REGTEST_MENU_ACTIONS[${MENU_KEY}]="reg_test_version ${PGMENUVER//.} standart"
      # idem for the "all tests" menu's entry
      DIST_EMAJ_REGTEST_MENU_ACTIONS[${MENU_KEY_ALLREGTEST_STANDART}]+=${DIST_EMAJ_REGTEST_MENU_ACTIONS[${MENU_KEY}]}'!'
      # the next decimal ASCII character
      let nCHAR++
      let TODISPLAY++
      continue 2
    fi
   done 
done
if [ ${TODISPLAY} -gt 1 ]; then
  # ALL STANDART TESTS
  # store the menu's entry
  MENU_KEY_LSTREGTEST_STANDART=`printf '\'$(printf '%03o' $((${nCHAR}-1)))`
  DIST_EMAJ_REGTEST_MENU[${MENU_KEY_ALLREGTEST_STANDART}]=$(printf "all tests, from %s to %s" ${MENU_KEY_1STREGTEST_STANDART} ${MENU_KEY_LSTREGTEST_STANDART})
fi

# EXTENSION UPGRADE
##nCHAR=`printf '%d' \'${MENU_KEY_1STREGTEST_UPGRADE}`
##TODISPLAY=0
##for PGMENUVER in ${DIST_EMAJ_REGTEST_UPGRADE_PGVER[@]}; do
##  for PGUSERVER in ${DIST_EMAJ_USER_PGVER[@]//.}; do
##    if [ "${PGMENUVER//.}" == "${PGUSERVER}" ]; then
##      MENU_KEY=`printf '\'$(printf "%03o" ${nCHAR})`
##      DIST_EMAJ_REGTEST_MENU[${MENU_KEY}]=$(printf "pg %s (port %d) starting with E-Maj upgrade" ${PGMENUVER} $(pg_dspvar ${PGMENUVER//.} PGPORT))
##      DIST_EMAJ_REGTEST_MENU_ACTIONS[${MENU_KEY}]="reg_test_version ${PGMENUVER//.} upgrade"
##      DIST_EMAJ_REGTEST_MENU_ACTIONS[${MENU_KEY_ALLREGTEST_UPGRADE}]+=${DIST_EMAJ_REGTEST_MENU_ACTIONS[${MENU_KEY}]}'!'
##      let nCHAR++
##      let TODISPLAY++
##      continue 2
##    fi
##  done
##done

# UNINSTALL
nCHAR=`printf '%d' \'${MENU_KEY_1STREGTEST_UNINSTALL}`
for PGMENUVER in ${DIST_EMAJ_REGTEST_UNINSTALL_PGVER[@]}; do
  for PGUSERVER in ${DIST_EMAJ_USER_PGVER[@]//.}; do
    if [ "${PGMENUVER//.}" == "${PGUSERVER}" ]; then
      # decimal to ASCII char
      MENU_KEY=`printf '\'$(printf "%03o" ${nCHAR})`
      # store the menu's entry
      DIST_EMAJ_REGTEST_MENU[${MENU_KEY}]=$(printf "pg %s (port %d) uninstall test" ${PGMENUVER} $(pg_dspvar ${PGMENUVER//.} PGPORT))
      # store the associated function to execute
      DIST_EMAJ_REGTEST_MENU_ACTIONS[${MENU_KEY}]="reg_test_version ${PGMENUVER//.} uninstall"
      # the next decimal ASCII character
      let nCHAR++
      let TODISPLAY++
      continue 2
    fi
   done 
done

# Tries to respect the order of appearance of the keys of the original menu (not an ASCII sort)
for ENTRY in "${!DIST_EMAJ_REGTEST_MENU[@]}"; do 
  nCHAR=`printf '%d' \'${ENTRY}`
  if [ ${nCHAR} -lt 97 ]; then
    # Here it should be an upper character
    DIST_EMAJ_REGTEST_MENU_SORTED[$((${nCHAR}%32+32))]="${ENTRY}- ${DIST_EMAJ_REGTEST_MENU[${ENTRY}]}"
  else
    # and here a lower character
    DIST_EMAJ_REGTEST_MENU_SORTED[$((${nCHAR}%32))]="${ENTRY}- ${DIST_EMAJ_REGTEST_MENU[${ENTRY}]}"
  fi
done

# Display the menu's entries
for ENTRY in ${!DIST_EMAJ_REGTEST_MENU_SORTED[@]}; do
  echo "  ${DIST_EMAJ_REGTEST_MENU_SORTED[${ENTRY}]}"
done

echo " "
echo "Test to run ?"

read ANSWER

#---------------------#
# CHECK ANSWER        #
#  AND                #
# EXECUTE FUNCTION(S) #
#---------------------#

if [ "${ANSWER}" == "" ]; then
  exit 0
fi

ANSWERISVALID=0
for KEY in "${!DIST_EMAJ_REGTEST_MENU_ACTIONS[@]}"; do
  if [ "${ANSWER}" == "${KEY}" ]; then
    ANSWERISVALID=1
    case ${KEY} in
      ${MENU_KEY_ALLREGTEST_STANDART}|${MENU_KEY_ALLREGTEST_UPGRADE})
        # RUNNING A SPECIFIC TEST FOREACH PG VERSIONS
        oIFS="${IFS}"
        IFS=!
        for FUNCREGTEST in ${DIST_EMAJ_REGTEST_MENU_ACTIONS[$KEY]}; do
          IFS=' ' eval ${FUNCREGTEST}
        done
        IFS="${oIFS}"
        ;;
      *) # RUNNING A SPECIFIC TEST FOR ONE PG VERSION
        ${DIST_EMAJ_REGTEST_MENU_ACTIONS[$KEY]}
        ;;
    esac
    break
  fi
done
if [ ${ANSWERISVALID} -ne 1 ]; then
  echo "Bad answer..."
  exit 2
fi

exit 0
