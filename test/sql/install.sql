-- install.sql : install Distributed E-Maj as an extension
--

-----------------------------
-- drop and create the test databases
-----------------------------

DROP DATABASE IF EXISTS regression_1;
DROP DATABASE IF EXISTS regression_2;

CREATE DATABASE regression_1 TEMPLATE=template0 LC_COLLATE='C' LC_CTYPE='C';
ALTER DATABASE regression_1 SET lc_messages TO 'C';
ALTER DATABASE regression_1 SET lc_monetary TO 'C';    
ALTER DATABASE regression_1 SET lc_numeric TO 'C';     
ALTER DATABASE regression_1 SET lc_time TO 'C';        
ALTER DATABASE regression_1 SET bytea_output TO 'hex'; 
ALTER DATABASE regression_1 SET timezone_abbreviations TO 'Default';

CREATE DATABASE regression_2 TEMPLATE=template0 LC_COLLATE='C' LC_CTYPE='C';
ALTER DATABASE regression_2 SET lc_messages TO 'C';
ALTER DATABASE regression_2 SET lc_monetary TO 'C';    
ALTER DATABASE regression_2 SET lc_numeric TO 'C';     
ALTER DATABASE regression_2 SET lc_time TO 'C';        
ALTER DATABASE regression_2 SET bytea_output TO 'hex'; 
ALTER DATABASE regression_2 SET timezone_abbreviations TO 'Default';

-----------------------------
-- create the emaj extension into regression_1 and regression_2
-----------------------------

\c regression_1
CREATE EXTENSION emaj VERSION 'devel' CASCADE;

\c regression_2
CREATE EXTENSION emaj VERSION 'devel' CASCADE;

-----------------------------
-- create the dist_emaj extension into regression
-----------------------------
\c regression

-- the bad way
\set ECHO none
\i sql/dist_emaj--devel.sql
\set ECHO all

-- the good way
CREATE EXTENSION dist_emaj VERSION 'devel' CASCADE;

-----------------------------
-- check installation
-----------------------------
-- check impact in catalog
select extname, extversion from pg_extension where extname = 'dist_emaj';
select relname from pg_catalog.pg_class, 
                    (select unnest(extconfig) as oid from pg_catalog.pg_extension where extname = 'dist_emaj') as t 
  where t.oid = pg_class.oid
  order by 1;

-- check version and history
select dist_emaj.dist_emaj_get_version();
select hist_id, hist_function, hist_event, hist_object, hist_wording, hist_user from dist_emaj.dist_emaj_hist order by hist_id;

-- reset function calls statistics (so the check.sql output is stable with all installation paths)
-- wait during half a second to let the statistics collector aggregate the latest stats
select pg_sleep(1.2);
with reset as (select funcid, pg_stat_reset_single_function_counters(funcid) from pg_stat_user_functions
                 where (funcname like E'dist\\_%' or funcname like E'\\_%') )
  select * from reset where funcid is null;
