-- adm.sql : test dist_emaj data access and functions calls by a dist_emaj_adm role.
--

-- Do not display DETAIL and CONTEXT outputs when an error is raised (\errverbose can be used to debug a statement).
\set VERBOSITY terse

--
-- Prepare the test context.
--

-- Set sequence restart value.
SELECT public.handle_dist_emaj_sequences(6000);

SET session_authorization TO _regress_dist_emaj_adm;
--

--
-- Handle parameters.
--

-- Try to directly update a parameter.
UPDATE dist_emaj.dist_emaj_param set param_value = '1 MONTHS' WHERE param_key = 'history_retention';
-- Update a parameter key.
SELECT dist_emaj.dist_emaj_set_param('history_retention', '1 MONTHS');
-- List all existing keys.
SELECT * FROM dist_emaj.dist_emaj_all_param ORDER BY param_rank;

--
-- Build a new cluster configuration
--

\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U _regress_dist_emaj_adm -W adm --action stop --cluster my_cluster --mark 'STOP'
SELECT clst_name, dist_emaj.dist_emaj_drop_cluster(clst_name) FROM dist_emaj.dist_emaj_cluster ORDER BY clst_name;

SELECT dist_emaj.dist_emaj_create_cluster('cluster_1');
SELECT dist_emaj.dist_emaj_create_cluster('cluster_2');

SELECT dist_emaj.dist_emaj_assign_group('cluster_1', 'emaj', 'myGroup');
SELECT dist_emaj.dist_emaj_assign_group('cluster_1', 'emaj_1', 'myGroup1');
SELECT dist_emaj.dist_emaj_assign_group('cluster_1', 'emaj_1', 'myGroup4');
SELECT dist_emaj.dist_emaj_assign_group('cluster_1', 'emaj_2', 'myGroup4');

SELECT dist_emaj.dist_emaj_assign_group('cluster_2', 'emaj_1', 'myGroup1');
SELECT dist_emaj.dist_emaj_assign_group('cluster_2', 'emaj_2', 'phil''s group#3",');

--
-- Start all clusters.
--

\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U _regress_dist_emaj_adm -W adm --action start --cluster cluster_1 --mark '1_START'
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U _regress_dist_emaj_adm -W adm --action start --cluster cluster_2 --mark '2_START' --logging-groups-allowed

--
-- Perform data changes, with intermediate distributed marks on cluster_1.
--
RESET session_authorization;

INSERT INTO mySchema.myTblP (col1, col2, col3) VALUES (1, 'A', 'aaaaa'), (-1, 'A', 'aaaaa'), (2, 'B', 'bbbbb'), (-2, 'B', 'bbbbb');
INSERT INTO mySchema.myTbl2 VALUES (1, 'First row', DATE '2030-01-01');

SET session_authorization TO _regress_dist_emaj_adm;
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U _regress_dist_emaj_adm -W adm --action set_mark --cluster cluster_1 --mark '1_M1'
RESET session_authorization;

INSERT INTO mySchema.myTblP (col1, col2, col3) VALUES (3, 'C', 'ccccc'), (-3, 'C', 'ccccc');
INSERT INTO mySchema.myTbl2 VALUES (2, 'Second row', DATE '2030-01-02');

SET session_authorization TO _regress_dist_emaj_adm;
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U _regress_dist_emaj_adm -W adm --action set_mark --cluster cluster_1 --mark '1_M2'
RESET session_authorization;

UPDATE mySchema.myTblP SET col3 = 'a a a' WHERE col2 = 'A';
UPDATE mySchema.myTbl2 SET col23 = col23 + INTERVAL '1 MONTHS';

--
-- Perform a distributed logged rollback on cluster_1 to an intermediate mark.
--

SET session_authorization TO _regress_dist_emaj_adm;
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U _regress_dist_emaj_adm -W adm --cluster cluster_1 --mark '1_M2' --logged
RESET session_authorization;

--
-- Final checks.
--
\c regression

-- Check dist_emaj tables content.
SELECT hist_function, hist_event, hist_object, hist_wording FROM dist_emaj.dist_emaj_hist WHERE hist_id >= 6000 ORDER BY hist_id;

--
RESET session_authorization;
