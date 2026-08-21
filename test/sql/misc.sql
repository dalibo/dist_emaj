-- misc.sql : test miscellaneous functions
--   dist_emaj_set_param(),
--   dist_emaj_verify_all(),
--   dist_emaj_delete_before_mark_cluster(),
--   dist_emaj_import_parameters_configuration() and dist_emaj_export_parameters_configuration(),
--   dist_emaj_purge_histories().
--

-- do not display DETAIL and CONTEXT outputs when an error is raised (\errverbose can be used to debug a statement)
\set VERBOSITY terse

--
-- Prepare the test context
--

-- set sequence restart value
select public.handle_dist_emaj_sequences(4000);

-- Define and create the temp file directory to be used by the script.
\setenv EMAJTESTTMPDIR '/tmp/emaj_'`echo $PGVER`'/misc'
\set EMAJTESTTMPDIR `echo $EMAJTESTTMPDIR`
\! mkdir -p $EMAJTESTTMPDIR

-----------------------------
-- Test dist_emaj_set_param()
-----------------------------
-- invalid key
select dist_emaj.dist_emaj_set_param('a key', 'a value');
-- invalid interval format
select dist_emaj.dist_emaj_set_param('history_retention', 'not an interval value');

-- update a key with a real value change resulting in an INSERT into dist_emaj_param
select dist_emaj.dist_emaj_set_param('history_retention', '1 MONTH');
-- update a key with the same value
select dist_emaj.dist_emaj_set_param('history_retention', '1 MONTH');
-- update a key with a real value change resulting in an UPDATE in dist_emaj_param
select dist_emaj.dist_emaj_set_param('history_retention', '2 MONTHS');
-- reset a key (here in upper case) to its default value
select dist_emaj.dist_emaj_set_param('HISTORY_RETENTION', NULL);
-- reset a key with no change
select dist_emaj.dist_emaj_set_param('history_retention', NULL);

select * from dist_emaj.dist_emaj_all_param order by param_rank;
select hist_id, hist_function, hist_event, hist_object, hist_wording from dist_emaj.dist_emaj_hist where hist_id >= 4000 order by 1;

-----------------------------
-- try forbiden actions on parameters tables
-----------------------------
truncate dist_emaj.dist_emaj_param;
truncate dist_emaj.dist_emaj_default_param;

-----------------------------
-- Test dist_emaj_verify_all()
-----------------------------

-- add missing groups
begin;
  select dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_1', 'extraGroup_1');
  select dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_1', 'extraGroup_2');
-- add non emaj adm user
  update dist_emaj.dist_emaj_database
    set db_connect_string = replace(db_connect_string, '_regress_emaj_adm:adm', '_regress_dist_emaj_anonym:anonym')
    where db_name = 'emaj_2';
  select * from dist_emaj.dist_emaj_verify_all();
rollback;
-- clean up errors and recheck
select dist_emaj.dist_emaj_drop_database('no_emaj');
drop database regression_no_emaj;

select * from dist_emaj.dist_emaj_verify_all();

-----------------------------
-- dist_emaj_delete_before_mark_cluster() tests
-----------------------------
-- errors in input parameters
select dist_emaj.dist_emaj_delete_before_mark_cluster('dummy_cluster', 'dummy_mark');
select dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'dummy_mark');

-- should be OK
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM1
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM2
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM3

select dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'START');
select dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'DM1');
select dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'DM1');
select * from dist_emaj.dist_emaj_mark order by mark_time_id;

-- local mark deletion for a group and renaming for another
\c regression_1
select emaj.emaj_delete_mark_group('myGroup1', 'DM2');
select emaj.emaj_rename_mark_group('myGroup2', 'DM3', 'Renamed_DM3');

\c regression
-- fails if the missing mark is the new first mark
select dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'DM2');

-- ok if the missing mark is an intermediate mark or if the new first mark has been renamed
select dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'DM3');

select * from dist_emaj.dist_emaj_mark order by mark_time_id;
select hist_id, hist_function, hist_event, hist_object, hist_wording
  from dist_emaj.dist_emaj_hist
  where hist_id >= 4000 and hist_function in ('DELETE_BEFORE_MARK_CLUSTER', 'SYNC_MARKS_CLUSTER', 'PURGE_HISTORIES')
  order by 1;

-----------------------------
-- dist_emaj_export_parameters_configuration() and dist_emaj_import_parameters_configuration() tests.
-----------------------------

-- Direct export.
--   OK.
SELECT json_array_length(dist_emaj.dist_emaj_export_parameters_configuration()->'parameters');
SELECT json_array_length(dist_emaj.dist_emaj_export_parameters_configuration(TRUE)->'parameters');
SELECT dist_emaj.dist_emaj_set_param('history_retention', '2 days');
SELECT dist_emaj.dist_emaj_export_parameters_configuration()->'parameters';

-- Export in file.
--   Error.
SELECT dist_emaj.dist_emaj_export_parameters_configuration('/tmp/dummy/location/file');
--   OK.
SELECT dist_emaj.dist_emaj_export_parameters_configuration(:'EMAJTESTTMPDIR' || '/orig_param_config');
\! wc -l $EMAJTESTTMPDIR/orig_param_config
\! grep -v ', at ' $EMAJTESTTMPDIR/orig_param_config

-- Direct import.
--   Error.
--     No "parameters" array.
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "dummy_json": null }'::JSON);
--     Unknown attributes.
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ { "key": "history_retention", "unknown_attribute_1": null, "unknown_attribute_2": null} ] }'::JSON);
--     Missing or null "key" attributes.
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ { "value": "no_key"} ] }'::JSON);
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ { "key": null} ] }'::JSON);
--     Invalid key.
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ { "key": "unknown_param" } ] }'::JSON);
--     Duplicate key.
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ { "key": "history_retention" }, { "key": "history_retention" } ] }'::JSON);
--     Bad interval format.
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ { "key": "history_retention", "value": "NOT an interval" } ] }'::JSON);

--   Ok.
--     New local value.
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ { "key": "history_retention", "value": "1 day"} ] }'::JSON);
--     Modified local value.
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ { "key": "history_retention", "value": "2 days"} ] }'::JSON);
--     "null" "value" attribute.
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ { "key": "history_retention", "value": null} ] }'::JSON);
--     Missing "value" attribute.
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ { "key": "history_retention"} ] }'::JSON);
SELECT json_array_length(dist_emaj.dist_emaj_export_parameters_configuration()->'parameters');
--   Reset other parameters.
SELECT dist_emaj.dist_emaj_set_param('history_retention', '1 day');
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ ] }'::JSON, FALSE);
SELECT * FROM dist_emaj.dist_emaj_param WHERE param_key = 'history_retention';
SELECT dist_emaj.dist_emaj_import_parameters_configuration('{ "parameters": [ ] }'::JSON, TRUE);
SELECT * FROM dist_emaj.dist_emaj_param WHERE param_key = 'history_retention';

-- Import from file.
--   Error.
SELECT dist_emaj.dist_emaj_import_parameters_configuration('/tmp/dummy/location/file');
\! echo 'not a json content' >$EMAJTESTTMPDIR/bad_param_config
SELECT dist_emaj.dist_emaj_import_parameters_configuration(:'EMAJTESTTMPDIR' || '/bad_param_config');
\! echo '{ "dummy_json": null }' >$EMAJTESTTMPDIR/bad_param_config
SELECT dist_emaj.dist_emaj_import_parameters_configuration(:'EMAJTESTTMPDIR' || '/bad_param_config');
\! echo '{ "parameters": [ { "key": "bad_key", "value": null} ] }' >$EMAJTESTTMPDIR/bad_param_config
SELECT dist_emaj.dist_emaj_import_parameters_configuration(:'EMAJTESTTMPDIR' || '/bad_param_config');

--   Ok.
SELECT dist_emaj.dist_emaj_import_parameters_configuration(:'EMAJTESTTMPDIR' || '/orig_param_config', TRUE);
SELECT json_array_length(dist_emaj.dist_emaj_export_parameters_configuration()->'parameters');

SELECT dist_emaj.dist_emaj_import_parameters_configuration(:'EMAJTESTTMPDIR' || '/orig_param_config', FALSE);

select hist_id, hist_function, hist_wording from dist_emaj.dist_emaj_hist where hist_id >= 4000 and hist_function like '%PARAM%' order by hist_id;

-----------------------------
-- dist_emaj_purge_histories() tests
-----------------------------
-- Use the default 1 YEAR retention delay. There is nothing to purge.
select dist_emaj.dist_emaj_purge_histories(NULL);

-- Use a 100 YEARS retention delay that disables the historyies purge.
select dist_emaj.dist_emaj_purge_histories('100 YEARS');

-- Set a 1 second delay. It removes all traces prior the most recent cluster stop (no rollback is deleted)
select dist_emaj.dist_emaj_set_param('history_retention', '1 second');
select dist_emaj.dist_emaj_purge_histories();
select dist_emaj.dist_emaj_set_param('history_retention', NULL);

-- Purge with no delay after having stopped and restarted the cluster.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark STOP
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark START
select dist_emaj.dist_emaj_purge_histories('0 SECOND');

--
-- Final checks
--
\c regression

-- Check dist_emaj tables content
select hist_id, hist_function, hist_wording from dist_emaj.dist_emaj_hist where hist_id >= 4000 and hist_function = 'PURGE_HISTORIES' order by hist_id;
select rlbk_id, rlbk_time_id from dist_emaj.dist_emaj_rlbk order by rlbk_id;
select min(time_id) from dist_emaj.dist_emaj_time_stamp;

--
reset session_authorization;

-- Remove the temp directory.
\! rm -R $EMAJTESTTMPDIR
