-- start_stop.sql : non regression tests for Distributed E-Maj distributed groups starts, groups stops and mark set
-- It mainly tests the distEmaj.pl client.
--

--
-- Prepare the test context
--

-- set sequence restart value
select public.handle_dist_emaj_sequences(2000);

--
-- Test the distEmaj.pl client
--

-- A few detected errors in options
--   illegal action
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action dummy
--   missing cluster
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start
--   missing mark
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster
--   unauthorized user
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U _regress_dist_emaj_anonym -W anonym --action start --cluster my_cluster --mark START

--
-- Start and stop tests
--

-- Errors on a database
--   missing groups (simulated from dist_emaj)
insert into dist_emaj.dist_emaj_cluster_group values
  ('my_cluster', 'emaj_1', 'extraGroup_1'),
  ('my_cluster', 'emaj_1', 'extraGroup_2');
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START'
delete from dist_emaj.dist_emaj_cluster_group where clgrp_cluster = 'my_cluster' and clgrp_database = 'emaj_1' and clgrp_group like 'extraGroup%';

-- Start a cluster (with a comment and useless --reset-logs and --idle-groups-allowed)
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START' --comment "Comment on start mark" --verbose --regression-test --rl --iga

-- Try to restart the cluster without --logging-groups-allowed
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START_ko'

-- Try to restart the cluster with the same mark and without logs reset
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START' --logging-groups-allowed --keep-logs

-- Stop a cluster (with a comment and useless --keep-logs and --logging-groups-allowed)
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark 'STOP' --comment "Comment on stop mark" --kl --lga

-- Re-stop a cluster without --idle-groups-allowed
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark 'STOP_ko' --comment "Comment on stop mark"

-- Restart with an existing mark but no log reset
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START' --keep-logs

-- Stop the cluster with logs reset (and a useless comment and mark name)
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark 'START' --idle-groups-allowed --reset-logs --comment 'useless comment'

--
-- Set mark tests
--

\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'RESTART'

-- illegal mark name
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark EMAJ_LAST_MARK

-- various mark names
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark 'Fixed_Mark_Name' --comment "Comment on mark set" --verbose --regression-test
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark --comment "Comment on generated mark name"
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark --comment "Comment on generated mark name"

--
-- Marks synchronization tests
--

select dist_emaj.dist_emaj_sync_marks_cluster('dummy');
select dist_emaj.dist_emaj_sync_marks_cluster('empty_cluster');
-- no mark to synchronize
select dist_emaj.dist_emaj_sync_marks_cluster('my_cluster');

-- marks have been locally deleted
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM1
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM2
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM3
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM4
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM5

\c regression_1
select emaj.emaj_delete_mark_group('myGroup1', 'DM2');
select emaj.emaj_delete_mark_group('myGroup1', 'DM4');
\c regression_2
select emaj.emaj_delete_before_mark_group('phil''s group#3",', 'DM3');

\c regression
select dist_emaj.dist_emaj_sync_marks_cluster('my_cluster');
select mark_name from dist_emaj.dist_emaj_mark where mark_cluster = 'my_cluster' and mark_name like 'DM%' order by 1;

-- a group has been locally stopped
\c regression_1
select emaj.emaj_stop_group('myGroup1');

\c regression
select dist_emaj.dist_emaj_sync_marks_cluster('my_cluster');

-- a group has been locally stopped and restarted
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark --idle-groups-allowed
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark DM1
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM2

\c regression_1
select emaj.emaj_stop_group('myGroup1');
select emaj.emaj_start_group('myGroup1');

\c regression
-- resynchronize marks by stopping the cluster
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark 'resync_and_STOP' --verbose --rt

-- a group has been locally started
\c regression_1
select emaj.emaj_start_group('myGroup1', 'Local_Start');

\c regression
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark DM1
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark DM1 --logging-groups-allowed

-- Final stop
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark 'STOP'

--
-- Final checks
--

-- Check dist_emaj tables content

select hist_id, hist_function, hist_event, hist_object, regexp_replace(hist_wording, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d', '%', 'g'), hist_user
  from dist_emaj.dist_emaj_hist where hist_id >= 2000 order by 1;
select mark_cluster, regexp_replace(mark_name,E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d', '%', 'g'), mark_time_id
  from dist_emaj.dist_emaj_mark order by 1, 3;
select mkdb_time_id, mkdb_database, mkdb_local_time_id
  from dist_emaj.dist_emaj_mark_database order by 1, 2, 3;

-- Check emaj tables
\c regression_1

select mark_group, regexp_replace(mark_name, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d','%','g'), mark_time_id, mark_is_rlbk_protected, mark_comment,
  mark_log_rows_before_next, mark_logged_rlbk_target_mark
  from emaj.emaj_mark order by mark_time_id, mark_group;
select hist_id, hist_function, hist_event, hist_object, 
  regexp_replace(regexp_replace(hist_wording, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d','%','g'),E'\\[.+\\]', '(timestamp)', 'g'), hist_user
  from emaj.emaj_hist order by hist_id;

\c regression
