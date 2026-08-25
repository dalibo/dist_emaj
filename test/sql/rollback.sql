-- rollback.sql : non regression tests for Distributed E-Maj distributed groups rollbacks
-- It mainly tests the distEmajRollback.pl client.
--

--
-- Prepare the test context
--

-- set sequence restart value
select public.handle_dist_emaj_sequences(3000);

-- Restart the cluster (it has been stopped at the end of start_stop.sql)
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark 'START'

-- Save a few identifiers
select set_config('dist_emaj.regress_start_mark_time_id', mark_time_id::text, false)
  from dist_emaj.dist_emaj_mark where mark_cluster = 'my_cluster' and mark_name = 'START';
select set_config('dist_emaj.regress_start_mark_local_time_id', mkdb_local_time_id::text, false)
  from dist_emaj.dist_emaj_mark_database
  where mkdb_time_id = (select max(mark_time_id) from dist_emaj.dist_emaj_mark)
    and mkdb_database = 'emaj_1';

-- Set a mark
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark 'A_Mark_Name';

--
-- Test the distEmajRollback.pl client
--

-- A few detected errors in options
--   missing cluster
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres
--   missing mark
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster
--   unauthorized user
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U _regress_dist_emaj_anonym -W anonym --cluster dummy --mark dummy

-- Empty cluster
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster empty_cluster --mark dummy

-- Errors in rollback target mark
--   unknown mark
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark dummy

-- Errors on a database
--   missing groups (simulated from dist_emaj)
insert into dist_emaj.dist_emaj_cluster_group values
  ('my_cluster', 'emaj_1', 'extraGroup_1'),
  ('my_cluster', 'emaj_1', 'extraGroup_2');
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark START
delete from dist_emaj.dist_emaj_cluster_group where clgrp_group like 'extraGroup%';

\c regression_1
--   renamed mark on emaj side
select emaj.emaj_rename_mark_group('myGroup1', 'A_Mark_Name', 'Renamed_mark');
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark A_Mark_Name
select emaj.emaj_rename_mark_group('myGroup1', 'Renamed_mark', 'A_Mark_Name');
--   mark not found on emaj side
select emaj.emaj_delete_mark_group('myGroup1', 'A_Mark_Name');
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark A_Mark_Name
--   mark found but not with the same time_id
select emaj.emaj_set_mark_group('myGroup1', 'A_Mark_Name');
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark A_Mark_Name

-- Should be OK

\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark START --logged --verbose --rt

\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark START

-- Rollback with a tables group structure change
select emaj.emaj_modify_table('myschema1', 'mytbl1', '{"priority":1}'::jsonb, 'Priority_changed');
--   --alter-groups-allowed option is missing
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark START
--   should be OK
\! ${DIST_EMAJ_DIR}/client/distEmajRollback.pl -d regression -U postgres --cluster my_cluster --mark START --alter-groups-allowed

--
-- Test the rollback states cleanup
--
\c regression

-- simulate 2 distributed rollback operations: an aborted (an unknown pid) and an in-progress (our psql session)
insert into dist_emaj.dist_emaj_rlbk
         (rlbk_id, rlbk_cluster, rlbk_mark, rlbk_mark_time_id, rlbk_time_id, rlbk_is_logged, rlbk_is_alter_group_allowed, rlbk_backend_pid, rlbk_status)
  values (-2, 'my_cluster', 'dummy_mark', 3001, 3002, FALSE, FALSE, 1, 'EXECUTING'),
         (-1, 'my_cluster', 'dummy_mark', 3001, 3002, FALSE, FALSE, pg_backend_pid(), 'LOCKING');

set application_name = 'distEmajRollback';
select dist_emaj.dist_emaj_verify_cluster('my_cluster');
reset application_name;

select rlbk_id, rlbk_status from dist_emaj.dist_emaj_rlbk where rlbk_id < 0 order by rlbk_id;
delete from dist_emaj.dist_emaj_rlbk where rlbk_id < 0;

--
-- Final checks
--
\c regression

-- Check dist_emaj tables content

select hist_id, hist_function, hist_event, hist_object, regexp_replace(hist_wording, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d', '%', 'g'), hist_user
  from dist_emaj.dist_emaj_hist where hist_id >= 3000 order by 1;
select mark_cluster, regexp_replace(mark_name, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d', '%', 'g'), mark_time_id
  from dist_emaj.dist_emaj_mark order by 1, 3;
select mkdb_time_id, mkdb_database, mkdb_local_time_id
  from dist_emaj.dist_emaj_mark_database order by 1, 2, 3;
select rlbk_id, rlbk_cluster, rlbk_mark, rlbk_mark_time_id, rlbk_time_id, rlbk_is_logged, rlbk_is_alter_group_allowed, rlbk_comment, rlbk_status
  from dist_emaj.dist_emaj_rlbk order by 1;
select rlbd_rlbk_id, rlbd_database, rlbd_local_rlbk_id from dist_emaj.dist_emaj_rlbk_database order by 1,2;
