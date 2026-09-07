-- check.sql: Perform various checks on the installed E-Maj components.
--            Also appreciate the regression test coverage.
--

-----------------------------
-- Count all functions in emaj schema and functions callable by users (dist_emaj_xxx).
-----------------------------
SELECT count(*) as all_functions FROM pg_proc, pg_namespace
  WHERE pg_namespace.oid=pronamespace AND nspname = 'dist_emaj' AND (proname LIKE E'dist\\_emaj\\_%' OR proname LIKE E'\\_%');

SELECT count(*) as user_callable_functions FROM pg_proc, pg_namespace
  WHERE pg_namespace.oid=pronamespace AND nspname = 'dist_emaj' AND proname LIKE E'dist\\_emaj\\_%';

-----------------------------
-- Check that no function has kept its default rights to public.
-----------------------------
-- Should return no row.
SELECT proname, proacl FROM pg_proc, pg_namespace
  WHERE pg_namespace.oid=pronamespace
    AND nspname = 'dist_emaj'
    AND proacl is NULL;

-----------------------------
-- Check that no user function has the default comment.
-----------------------------
-- Should return no row.
SELECT pg_proc.proname
  FROM pg_proc
    join pg_namespace on (pronamespace=pg_namespace.oid)
    left outer join pg_description on (pg_description.objoid = pg_proc.oid
                     AND classoid = (SELECT oid FROM pg_class WHERE relname = 'pg_proc')
                     AND objsubid=0)
  WHERE nspname = 'dist_emaj' AND proname LIKE E'dist\\_emaj\\_%' AND
        pg_description.description = 'Distributed E-Maj internal function';

-----------------------------
-- Get test coverage data just before cleanup.
-----------------------------
-- Look at pg_stat_activity to force the statistics collector aggregate the latest stats.
SELECT 0 FROM pg_stat_activity LIMIT 1;

-- Display dist_emaj functions that are not called by any regression test script.
-- Some functions are excluded:
--   _dist_emaj_param_before_stmt_fnct and _dist_emaj_default_param_before_stmt_fnct are called by triggers but always raise an exception.
--       (and thus are not listed in pg_stat_user_functions for PG14- versions),
--   Dist_emaj_drop_extension() is not called by the standart test scenarios.
SELECT proname FROM pg_proc, pg_namespace
  WHERE pronamespace = pg_namespace.oid
    AND nspname = 'dist_emaj' AND (proname LIKE E'dist\\_emaj\\_%' OR proname LIKE E'\\_%')
    AND proname NOT in ('_dist_emaj_default_param_before_stmt_fnct', '_dist_emaj_param_before_stmt_fnct',
                        'dist_emaj_drop_extension')
EXCEPT
SELECT funcname FROM pg_stat_user_functions
  WHERE schemaname = 'dist_emaj' AND (funcname LIKE E'dist\\_emaj\\_%' OR funcname LIKE E'\\_%')
ORDER BY 1;

-- Display the number of calls for each dist_emaj function.
SELECT funcname, calls FROM pg_stat_user_functions
  WHERE schemaname = 'dist_emaj' AND (funcname LIKE E'dist\\_emaj\\_%' OR funcname LIKE E'\\_%')
  ORDER BY funcname, funcid;

-- Count the total number of user-callable function calls (those who failed are not counted).
SELECT sum(calls) FROM pg_stat_user_functions WHERE funcname LIKE E'dist\\_emaj\\_%';

-----------------------------
-- Execute the perl script that checks the code.
-----------------------------

\! perl ${DIST_EMAJ_DIR}/tools/check_code.pl | grep -P '^WARNING:|^ERROR:'
