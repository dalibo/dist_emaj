-- viewer.sql : test dist_emaj data access and functions calls by a dist_emaj_viewer role.
--

-- Do not display DETAIL and CONTEXT outputs when an error is raised (\errverbose can be used to debug a statement).
\set VERBOSITY terse

--
-- Prepare the test context.
--

-- Set sequence restart value.
SELECT public.handle_dist_emaj_sequences(5000);

SET session_authorization TO _regress_dist_emaj_viewer;

-----------------------------
-- Authorized table or view accesses.
-----------------------------
SELECT 'SELECT ok' AS result FROM (SELECT count(*) FROM dist_emaj.dist_emaj_hist) AS t;
SELECT 'SELECT ok' AS result FROM (SELECT count(*) FROM dist_emaj.dist_emaj_all_param) AS t;
SELECT 'SELECT ok' AS result FROM (SELECT count(*) FROM dist_emaj.dist_emaj_hist) AS t;
SELECT 'SELECT ok' AS result FROM (SELECT count(*) FROM dist_emaj.dist_emaj_time_stamp) AS t;
SELECT 'SELECT ok' AS result FROM (SELECT count(*) FROM dist_emaj.dist_emaj_cluster) AS t;
SELECT 'SELECT ok' AS result FROM (SELECT count(*) FROM dist_emaj.dist_emaj_cluster_group) AS t;
SELECT 'SELECT ok' AS result FROM (SELECT count(*) FROM dist_emaj.dist_emaj_mark) AS t;
SELECT 'SELECT ok' AS result FROM (SELECT count(*) FROM dist_emaj.dist_emaj_mark_database) AS t;
SELECT 'SELECT ok' AS result FROM (SELECT count(*) FROM dist_emaj.dist_emaj_rlbk) AS t;
SELECT 'SELECT ok' AS result FROM (SELECT count(*) FROM dist_emaj.dist_emaj_rlbk_database) AS t;

-----------------------------
-- Forbiden table accesses (just test 1 delete).
-----------------------------
DELETE FROM dist_emaj.dist_emaj_hist;

-----------------------------
-- Dist_emaj_database specific case.
-----------------------------

-- Authorized.
SELECT 'SELECT ok' AS result FROM (SELECT count(*) FROM dist_emaj.dist_emaj_database) AS t;
SELECT db_name, db_rlbk_parallel_session FROM dist_emaj.dist_emaj_database ORDER BY 1;
SELECT clst_name, db_name, db_rlbk_parallel_session, db_groups_array FROM dist_emaj.dist_emaj_database_aggregates ORDER BY 1, 2;

-- Forbidden.
SELECT * FROM dist_emaj.dist_emaj_database;
DELETE FROM dist_emaj.dist_emaj_database;
SELECT * FROM dist_emaj.dist_emaj_database_aggregates;

-----------------------------
-- Authorized functions.
-----------------------------

SELECT dist_emaj.dist_emaj_get_version();

-----------------------------
-- Forbiden functions (just test 1).
-----------------------------
SELECT dist_emaj.dist_emaj_verify_cluster('my_cluster');

--
RESET session_authorization;
