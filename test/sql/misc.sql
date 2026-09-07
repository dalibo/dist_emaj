-- misc.sql : test miscellaneous functions.
--   Dist_emaj_set_param(),
--   Dist_emaj_verify_all(),
--   Dist_emaj_delete_before_mark_cluster(),
--   Dist_emaj_import_parameters_configuration() and dist_emaj_export_parameters_configuration(),
--   Dist_emaj_purge_histories().
--

-- Do not display DETAIL and CONTEXT outputs when an error is raised (\errverbose can be used to debug a statement).
\set VERBOSITY terse

--
-- Prepare the test context.
--

-- Set sequence restart value.
SELECT public.handle_dist_emaj_sequences(4000);

-- Define and create the temp file directory to be used by the script.
\setenv EMAJTESTTMPDIR '/tmp/emaj_'`echo $PGVER`'/misc'
\set EMAJTESTTMPDIR `echo $EMAJTESTTMPDIR`
\! mkdir -p $EMAJTESTTMPDIR

-----------------------------
-- Test dist_emaj_set_param().
-----------------------------
-- Invalid key.
SELECT dist_emaj.dist_emaj_set_param('a key', 'a value');
-- Invalid interval format.
SELECT dist_emaj.dist_emaj_set_param('history_retention', 'NOT an interval value');

-- Update a key with a real value change resulting in an INSERT into dist_emaj_param.
SELECT dist_emaj.dist_emaj_set_param('history_retention', '1 MONTH');
-- Update a key with the same value.
SELECT dist_emaj.dist_emaj_set_param('history_retention', '1 MONTH');
-- Update a key with a real value change resulting in an UPDATE in dist_emaj_param.
SELECT dist_emaj.dist_emaj_set_param('history_retention', '2 MONTHS');
-- Reset a key (here in upper case) to its default value.
SELECT dist_emaj.dist_emaj_set_param('HISTORY_RETENTION', NULL);
-- Reset a key with no change.
SELECT dist_emaj.dist_emaj_set_param('history_retention', NULL);

SELECT * FROM dist_emaj.dist_emaj_all_param ORDER BY param_rank;
SELECT hist_id, hist_function, hist_event, hist_object, hist_wording FROM dist_emaj.dist_emaj_hist WHERE hist_id >= 4000 ORDER BY 1;

-----------------------------
-- Try forbiden actions on parameters tables.
-----------------------------
TRUNCATE dist_emaj.dist_emaj_param;
TRUNCATE dist_emaj.dist_emaj_default_param;

-----------------------------
-- Test dist_emaj_verify_all().
-----------------------------

-- Add missing groups.
BEGIN;
  SELECT dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_1', 'extraGroup_1');
  SELECT dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_1', 'extraGroup_2');
-- Add non emaj adm user.
  UPDATE dist_emaj.dist_emaj_database
    SET db_connect_string = replace(db_connect_string, '_regress_emaj_adm:adm', '_regress_dist_emaj_anonym:anonym')
    WHERE db_name = 'emaj_2';
  SELECT * FROM dist_emaj.dist_emaj_verify_all();
ROLLBACK;
-- Clean up errors and recheck.
SELECT dist_emaj.dist_emaj_drop_database('no_emaj');
DROP DATABASE regression_no_emaj;

SELECT * FROM dist_emaj.dist_emaj_verify_all();

-----------------------------
-- Dist_emaj_delete_before_mark_cluster() tests.
-----------------------------
-- Errors in input parameters.
SELECT dist_emaj.dist_emaj_delete_before_mark_cluster('dummy_cluster', 'dummy_mark');
SELECT dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'dummy_mark');

-- Should be OK.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM1
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM2
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action set_mark --cluster my_cluster --mark DM3

SELECT dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'START');
SELECT dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'DM1');
SELECT dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'DM1');
SELECT * FROM dist_emaj.dist_emaj_mark ORDER BY mark_time_id;

-- Local mark deletion for a group and renaming for another.
\c regression_1
SELECT emaj.emaj_delete_mark_group('myGroup1', 'DM2');
SELECT emaj.emaj_rename_mark_group('myGroup2', 'DM3', 'Renamed_DM3');

\c regression
-- Fails if the missing mark is the new first mark.
SELECT dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'DM2');

-- Ok if the missing mark is an intermediate mark or if the new first mark has been renamed.
SELECT dist_emaj.dist_emaj_delete_before_mark_cluster('my_cluster', 'DM3');

SELECT * FROM dist_emaj.dist_emaj_mark ORDER BY mark_time_id;
SELECT hist_id, hist_function, hist_event, hist_object, hist_wording
  FROM dist_emaj.dist_emaj_hist
  WHERE hist_id >= 4000 AND hist_function in ('DELETE_BEFORE_MARK_CLUSTER', 'SYNC_MARKS_CLUSTER', 'PURGE_HISTORIES')
  ORDER BY 1;

-----------------------------
-- Dist_emaj_export_parameters_configuration() and dist_emaj_import_parameters_configuration() tests.
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

SELECT hist_id, hist_function, hist_event, hist_wording FROM dist_emaj.dist_emaj_hist WHERE hist_id >= 4000 AND hist_function LIKE '%PARAM%' ORDER BY hist_id;

-----------------------------
-- Dist_emaj_purge_histories() tests.
-----------------------------
-- Use the default 1 YEAR retention delay. There is nothing to purge.
SELECT dist_emaj.dist_emaj_purge_histories(NULL);

-- Use a 100 YEARS retention delay that disables the historyies purge.
SELECT dist_emaj.dist_emaj_purge_histories('100 YEARS');

-- Set a 1 second delay. It removes all traces prior the most recent cluster stop (no rollback is deleted).
SELECT dist_emaj.dist_emaj_set_param('history_retention', '1 second');
SELECT dist_emaj.dist_emaj_purge_histories();
SELECT dist_emaj.dist_emaj_set_param('history_retention', NULL);

-- Purge with no delay after having stopped and restarted the cluster.
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action stop --cluster my_cluster --mark STOP
\! ${DIST_EMAJ_DIR}/client/distEmaj.pl -d regression -U postgres --action start --cluster my_cluster --mark START
SELECT dist_emaj.dist_emaj_purge_histories('0 SECOND');

--
-- Final checks.
--
\c regression

-- Check dist_emaj tables content.
SELECT hist_id, hist_function, hist_wording FROM dist_emaj.dist_emaj_hist WHERE hist_id >= 4000 AND hist_function = 'PURGE_HISTORIES' ORDER BY hist_id;
SELECT rlbk_id, rlbk_time_id FROM dist_emaj.dist_emaj_rlbk ORDER BY rlbk_id;
SELECT min(time_id) FROM dist_emaj.dist_emaj_time_stamp;

--
RESET session_authorization;

-- Remove the temp directory.
\! rm -R $EMAJTESTTMPDIR
