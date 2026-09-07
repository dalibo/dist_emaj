-- install.sql : install Distributed E-Maj as an extension.
--

-----------------------------
-- Drop and create the test databases.
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
-- Create the emaj extension into regression_1 and regression_2.
-----------------------------

\c regression_1
CREATE EXTENSION emaj VERSION 'devel' CASCADE;

\c regression_2
CREATE EXTENSION emaj VERSION 'devel' CASCADE;

-----------------------------
-- Create the dist_emaj extension into regression.
-----------------------------
\c regression

-- The bad way.
\set ECHO none
\i sql/dist_emaj--devel.sql
\set ECHO all

-- The good way.
CREATE EXTENSION dist_emaj VERSION 'devel' CASCADE;

-----------------------------
-- Check installation.
-----------------------------
-- Check impact in catalog.
SELECT extname, extversion FROM pg_extension WHERE extname = 'dist_emaj';
SELECT relname FROM pg_catalog.pg_class,
                    (SELECT unnest(extconfig) AS oid FROM pg_catalog.pg_extension WHERE extname = 'dist_emaj') AS t
  WHERE t.oid = pg_class.oid
  ORDER BY 1;

-- Check version and history.
SELECT dist_emaj.dist_emaj_get_version();
SELECT hist_id, hist_function, hist_event, hist_object, hist_wording, hist_user FROM dist_emaj.dist_emaj_hist ORDER BY hist_id;

-- Reset function calls statistics (so the check.sql output is stable with all installation paths).
-- Wait during half a second to let the statistics collector aggregate the latest stats.
SELECT pg_sleep(1.2);
WITH RESET AS (SELECT funcid, pg_stat_reset_single_function_counters(funcid) FROM pg_stat_user_functions
                 WHERE (funcname LIKE E'dist\\_%' OR funcname LIKE E'\\_%') )
  SELECT * FROM RESET WHERE funcid is NULL;
