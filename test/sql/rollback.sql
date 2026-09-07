-- rollback.sql : non regression tests for Distributed E-Maj distributed groups rollbacks.
-- It mainly tests the distEmajRollback.pl client.
--

--
-- Prepare the test context.
--

-- Set sequence restart value.
SELECT public.handle_dist_emaj_sequences(3000);

-- Restart the cluster (it has been stopped at the end of start_stop.sql).
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START'

-- Save a few identifiers.
SELECT set_config('dist_emaj.regress_start_mark_time_id', mark_time_id::TEXT, FALSE)
  FROM dist_emaj.dist_emaj_mark WHERE mark_cluster = 'my_cluster' AND mark_name = 'START';
SELECT set_config('dist_emaj.regress_start_mark_local_time_id', mkdb_local_time_id::TEXT, FALSE)
  FROM dist_emaj.dist_emaj_mark_database
  WHERE mkdb_time_id = (SELECT max(mark_time_id) FROM dist_emaj.dist_emaj_mark)
    AND mkdb_database = 'emaj_1';

-- Set a mark.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark 'A_Mark_Name';

--
-- Test the distEmajRollback.pl client.
--

-- A few detected errors in options.
--   Missing cluster.
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres
--   Missing mark.
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster
--   Unauthorized user.
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U _regress_dist_emaj_anonym -W anonym --cluster dummy --mark dummy

-- Empty cluster.
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster empty_cluster --mark dummy

-- Errors in rollback target mark.
--   Unknown mark.
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark dummy

-- Errors on a database.
--   Missing groups (simulated from dist_emaj).
INSERT INTO dist_emaj.dist_emaj_cluster_group VALUES
  ('my_cluster', 'emaj_1', 'extraGroup_1'),
  ('my_cluster', 'emaj_1', 'extraGroup_2');
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark START
DELETE FROM dist_emaj.dist_emaj_cluster_group WHERE clgrp_group LIKE 'extraGroup%';

\c regression_1
--   Renamed mark on emaj side.
SELECT emaj.emaj_rename_mark_group('myGroup1', 'A_Mark_Name', 'Renamed_mark');
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark A_Mark_Name
SELECT emaj.emaj_rename_mark_group('myGroup1', 'Renamed_mark', 'A_Mark_Name');
--   Mark not found on emaj side.
SELECT emaj.emaj_delete_mark_group('myGroup1', 'A_Mark_Name');
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark A_Mark_Name
--   Mark found but not with the same time_id.
SELECT emaj.emaj_set_mark_group('myGroup1', 'A_Mark_Name');
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark A_Mark_Name

-- Should be OK.

\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark START --logged --verbose --rt

\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark START

-- Rollback with a tables group structure change.
SELECT emaj.emaj_modify_table('myschema1', 'mytbl1', '{"priority":1}'::JSONB, 'Priority_changed');
--   --alter-groups-allowed option is missing.
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark START
--   Should be OK.
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark START --alter-groups-allowed

--
-- Test the rollback states cleanup.
--
\c regression

-- Simulate 2 distributed rollback operations: an aborted (an unknown pid) and an in-progress (our psql session).
INSERT INTO dist_emaj.dist_emaj_rlbk
         (rlbk_id, rlbk_cluster, rlbk_mark, rlbk_mark_time_id, rlbk_time_id, rlbk_is_logged, rlbk_is_alter_group_allowed, rlbk_backend_pid, rlbk_status)
  VALUES (-2, 'my_cluster', 'dummy_mark', 3001, 3002, FALSE, FALSE, 1, 'EXECUTING'),
         (-1, 'my_cluster', 'dummy_mark', 3001, 3002, FALSE, FALSE, pg_backend_pid(), 'LOCKING');

SET application_name = 'distEmajRollback';
SELECT dist_emaj.dist_emaj_verify_cluster('my_cluster');
RESET application_name;

SELECT rlbk_id, rlbk_status FROM dist_emaj.dist_emaj_rlbk WHERE rlbk_id < 0 ORDER BY rlbk_id;
DELETE FROM dist_emaj.dist_emaj_rlbk WHERE rlbk_id < 0;

--
-- Final checks.
--
\c regression

-- Check dist_emaj tables content.

SELECT hist_id, hist_function, hist_event, hist_object, regexp_replace(hist_wording, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d', '%', 'g'), hist_user
  FROM dist_emaj.dist_emaj_hist WHERE hist_id >= 3000 ORDER BY 1;
SELECT mark_cluster, regexp_replace(mark_name, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d', '%', 'g'), mark_time_id
  FROM dist_emaj.dist_emaj_mark ORDER BY 1, 3;
SELECT mkdb_time_id, mkdb_database, mkdb_local_time_id
  FROM dist_emaj.dist_emaj_mark_database ORDER BY 1, 2, 3;
SELECT rlbk_id, rlbk_cluster, rlbk_mark, rlbk_mark_time_id, rlbk_time_id, rlbk_is_logged, rlbk_is_alter_group_allowed, rlbk_comment, rlbk_status
  FROM dist_emaj.dist_emaj_rlbk ORDER BY 1;
SELECT rlbd_rlbk_id, rlbd_database, rlbd_local_rlbk_id FROM dist_emaj.dist_emaj_rlbk_database ORDER BY 1,2;
