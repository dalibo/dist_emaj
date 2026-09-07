-- start_stop.sql : non regression tests for Distributed E-Maj distributed groups starts, groups stops and mark set.
-- It mainly tests the distEmaj.pl client.
--

--
-- Prepare the test context.
--

-- Set sequence restart value.
SELECT public.handle_dist_emaj_sequences(2000);

--
-- Test the distEmaj.pl client.
--

-- A few detected errors in options.
--   Illegal action.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action dummy
--   Missing cluster.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start
--   Missing mark.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster
--   Unauthorized user.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U _regress_dist_emaj_anonym -W anonym --action start --cluster my_cluster --mark START

--
-- Start and stop tests.
--

-- Errors on a database.
--   Missing groups (simulated from dist_emaj).
INSERT INTO dist_emaj.dist_emaj_cluster_group VALUES
  ('my_cluster', 'emaj_1', 'extraGroup_1'),
  ('my_cluster', 'emaj_1', 'extraGroup_2');
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START'
DELETE FROM dist_emaj.dist_emaj_cluster_group WHERE clgrp_cluster = 'my_cluster' AND clgrp_database = 'emaj_1' AND clgrp_group LIKE 'extraGroup%';

-- Start a cluster (with a comment and useless --reset-logs and --idle-groups-allowed).
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START' --comment "Comment on start mark" --verbose --regression-test --rl --iga

-- Try to restart the cluster without --logging-groups-allowed.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START_ko'

-- Try to restart the cluster with the same mark and without logs reset.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START' --logging-groups-allowed --keep-logs

-- Stop a cluster (with a comment and useless --keep-logs and --logging-groups-allowed).
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark 'STOP' --comment "Comment on stop mark" --kl --lga

-- Re-stop a cluster without --idle-groups-allowed.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark 'STOP_ko' --comment "Comment on stop mark"

-- Restart with an existing mark but no log reset.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START' --keep-logs

-- Stop the cluster with logs reset (and a useless comment and mark name).
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark 'START' --idle-groups-allowed --reset-logs --comment 'useless comment'

--
-- Set mark tests.
--

\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'RESTART'

-- Illegal mark name.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark EMAJ_LAST_MARK

-- Various mark names.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark 'Fixed_Mark_Name' --comment "Comment on mark set" --verbose --regression-test
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark --comment "Comment on generated mark name"
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark --comment "Comment on generated mark name"

--
-- Marks synchronization tests.
--

SELECT dist_emaj.dist_emaj_sync_marks_cluster('dummy');
SELECT dist_emaj.dist_emaj_sync_marks_cluster('empty_cluster');
-- No mark to synchronize.
SELECT dist_emaj.dist_emaj_sync_marks_cluster('my_cluster');

-- Marks have been locally deleted.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM1
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM2
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM3
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM4
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM5

\c regression_1
SELECT emaj.emaj_delete_mark_group('myGroup1', 'DM2');
SELECT emaj.emaj_delete_mark_group('myGroup1', 'DM4');
\c regression_2
SELECT emaj.emaj_delete_before_mark_group('phil''s group#3",', 'DM3');

\c regression
SELECT dist_emaj.dist_emaj_sync_marks_cluster('my_cluster');
SELECT mark_name FROM dist_emaj.dist_emaj_mark WHERE mark_cluster = 'my_cluster' AND mark_name LIKE 'DM%' ORDER BY 1;

-- A group has been locally stopped.
\c regression_1
SELECT emaj.emaj_stop_group('myGroup1');

\c regression
SELECT dist_emaj.dist_emaj_sync_marks_cluster('my_cluster');

-- A group has been locally stopped and restarted.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark --idle-groups-allowed
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark DM1
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM2

\c regression_1
SELECT emaj.emaj_stop_group('myGroup1');
SELECT emaj.emaj_start_group('myGroup1');

\c regression
-- Resynchronize marks by stopping the cluster.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark 'resync_and_STOP' --verbose --rt

-- A group has been locally started.
\c regression_1
SELECT emaj.emaj_start_group('myGroup1', 'Local_Start');

\c regression
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark DM1
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark DM1 --logging-groups-allowed

-- Final stop.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark 'STOP'

--
-- Final checks.
--

-- Check dist_emaj tables content.

SELECT hist_id, hist_function, hist_event, hist_object, regexp_replace(hist_wording, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d', '%', 'g'), hist_user
  FROM dist_emaj.dist_emaj_hist WHERE hist_id >= 2000 ORDER BY 1;
SELECT mark_cluster, regexp_replace(mark_name,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d', '%', 'g'), mark_time_id
  FROM dist_emaj.dist_emaj_mark ORDER BY 1, 3;
SELECT mkdb_time_id, mkdb_database, mkdb_local_time_id
  FROM dist_emaj.dist_emaj_mark_database ORDER BY 1, 2, 3;

-- Check emaj tables.
\c regression_1

SELECT mark_group, regexp_replace(mark_name, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d','%','g'), mark_time_id, mark_is_rlbk_protected, mark_comment,
  mark_log_rows_before_next, mark_logged_rlbk_target_mark
  FROM emaj.emaj_mark ORDER BY mark_time_id, mark_group;
SELECT hist_id, hist_function, hist_event, hist_object,
  regexp_replace(regexp_replace(hist_wording, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d','%','g'),E'\\[.+\\]', '(timestamp)', 'g'), hist_user
  FROM emaj.emaj_hist ORDER BY hist_id;

\c regression
