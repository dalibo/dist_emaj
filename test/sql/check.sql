-- check.sql: Perform various checks on the installed E-Maj components.
--            Also appreciate the regression test coverage.
--

-----------------------------
-- count all functions in emaj schema and functions callable by users (dist_emaj_xxx)
-----------------------------
select count(*) as all_functions from pg_proc, pg_namespace 
  where pg_namespace.oid=pronamespace and nspname = 'dist_emaj' and (proname like E'dist\\_emaj\\_%' or proname like E'\\_%');

select count(*) as user_callable_functions from pg_proc, pg_namespace 
  where pg_namespace.oid=pronamespace and nspname = 'dist_emaj' and proname like E'dist\\_emaj\\_%';

-----------------------------
-- check that no function has kept its default rights to public
-----------------------------
-- should return no row
select proname, proacl from pg_proc, pg_namespace 
  where pg_namespace.oid=pronamespace
    and nspname = 'dist_emaj'
    and proacl is null;

-----------------------------
-- check that no user function has the default comment
-----------------------------
-- should return no row
select pg_proc.proname
  from pg_proc
    join pg_namespace on (pronamespace=pg_namespace.oid)
    left outer join pg_description on (pg_description.objoid = pg_proc.oid 
                     and classoid = (select oid from pg_class where relname = 'pg_proc')
                     and objsubid=0)
  where nspname = 'dist_emaj' and proname like E'dist\\_emaj\\_%' and 
        pg_description.description = 'Distributed E-Maj internal function';

-----------------------------
-- get test coverage data just before cleanup
-----------------------------
-- look at pg_stat_activity to force the statistics collector aggregate the latest stats
select 0 from pg_stat_activity limit 1;

-- display dist_emaj functions that are not called by any regression test script
-- some functions are excluded:
--   dist_emaj_drop_extension() is not called by the standart test scenarios.
select proname from pg_proc, pg_namespace
  where pronamespace = pg_namespace.oid
    and nspname = 'dist_emaj' and (proname like E'dist\\_emaj\\_%' or proname like E'\\_%')
    and proname not in ('dist_emaj_drop_extension')
except
select funcname from pg_stat_user_functions
  where schemaname = 'dist_emaj' and (funcname like E'dist\\_emaj\\_%' or funcname like E'\\_%')
order by 1;

-- display the number of calls for each dist_emaj function
select funcname, calls from pg_stat_user_functions
  where schemaname = 'dist_emaj' and (funcname like E'dist\\_emaj\\_%' or funcname like E'\\_%')
  order by funcname, funcid;

-- count the total number of user-callable function calls (those who failed are not counted)
select sum(calls) from pg_stat_user_functions where funcname like E'dist\\_emaj\\_%';

-----------------------------
-- execute the perl script that checks the code
-----------------------------

\! perl ${DIST_EMAJ_DIR}/tools/check_code.pl | grep -P '^WARNING:|^ERROR:'
