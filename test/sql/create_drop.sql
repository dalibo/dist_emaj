-- create_drop.sql : non regression tests for Distributed E-Maj objects creation and drop
-- It tests in particular:
--   dist_emaj_create_database(), dist_emaj_drop_database(),
--   dist_emaj_create_cluster(), dist_emaj_drop_cluster(),
--   dist_emaj_assign_group(), dist_emaj_remove_group(),
--   dist_emaj_export_clusters_configuration(), dist_emaj_import_clusters_configuration()
--
-- Prepare the test context
--

-- set sequence restart value
select public.handle_dist_emaj_sequences(1000);

-- Define and create the temp file directory to be used by the script.
\setenv EMAJTESTTMPDIR '/tmp/emaj_'`echo $PGVER`'/create_drop'
\set EMAJTESTTMPDIR `echo $EMAJTESTTMPDIR`
\! mkdir -p $EMAJTESTTMPDIR

--
-- Test dist_emaj_create_database()
--

-- illegal value
select dist_emaj.dist_emaj_create_database(null, 'a connect string', 2);
select dist_emaj.dist_emaj_create_database('first_database', null, 2);
select dist_emaj.dist_emaj_create_database('first_database', 'a connect string', null);
select dist_emaj.dist_emaj_create_database('first_database', 'a connect string', 0);

-- ok
select dist_emaj.dist_emaj_create_database('first_database', 'a connect string', 2);
select * from dist_emaj.dist_emaj_database where db_name = 'first_database';
-- already created
select dist_emaj.dist_emaj_create_database('first_database', 'another connect string', 3);
select dist_emaj.dist_emaj_create_database('first_database', 'another connect string', 3, true);
select * from dist_emaj.dist_emaj_database where db_name = 'first_database';

--
-- Test dist_emaj_drop_database()
--

-- database does not exist.
select dist_emaj.dist_emaj_drop_database('dummy_database');
select dist_emaj.dist_emaj_drop_database('dummy_database', true);

-- an assigned group
insert into dist_emaj.dist_emaj_cluster (clst_name) values ('a_cluster');
insert into dist_emaj.dist_emaj_cluster_group values ('a_cluster', 'first_database', 'a group');
-- but CASCADE is not allowed
select dist_emaj.dist_emaj_drop_database('first_database');
-- ok, CASCADE is now allowed
select dist_emaj.dist_emaj_drop_database('first_database', false, true);

delete from dist_emaj.dist_emaj_cluster where clst_name = 'a_cluster';

--
-- Test dist_emaj_create_cluster()
--

-- illegal value
select dist_emaj.dist_emaj_create_cluster(null);
-- ok
select dist_emaj.dist_emaj_create_cluster('first_cluster');
-- already created
select dist_emaj.dist_emaj_create_cluster('first_cluster');
select dist_emaj.dist_emaj_create_cluster('first_cluster', true);

--
-- Test dist_emaj_drop_cluster()
--

-- cluster does not exist.
select dist_emaj.dist_emaj_drop_cluster('dummy_cluster');
select dist_emaj.dist_emaj_drop_cluster('dummy_cluster', true);

-- an assigned group
insert into dist_emaj.dist_emaj_database (db_name, db_connect_string, db_rlbk_parallel_session) values ('a_database', 'a connect string', 1);
insert into dist_emaj.dist_emaj_cluster_group values ('first_cluster', 'a_database', 'a group');
-- but CASCADE is not allowed
select dist_emaj.dist_emaj_drop_cluster('first_cluster');
-- ok, CASCADE is now allowed
select dist_emaj.dist_emaj_drop_cluster('first_cluster', false, true);

delete from dist_emaj.dist_emaj_database where db_name = 'a_database';

--
-- Test dist_emaj_assign_group()
--

insert into dist_emaj.dist_emaj_cluster (clst_name) values ('a_cluster');
insert into dist_emaj.dist_emaj_database (db_name, db_connect_string, db_rlbk_parallel_session) values ('a_database', 'a connect string', 1);

-- invalid values
select dist_emaj.dist_emaj_assign_group('dummy_cluster', 'dummy_database', 'dummy_group');
select dist_emaj.dist_emaj_assign_group('a_cluster', 'dummy_database', 'dummy_group');

-- ok
select dist_emaj.dist_emaj_assign_group('a_cluster', 'a_database', 'a_group');

-- already assigned
select dist_emaj.dist_emaj_assign_group('a_cluster', 'a_database', 'a_group');
select dist_emaj.dist_emaj_assign_group('a_cluster', 'a_database', 'a_group', true);

--
-- Test dist_emaj_remove_group()
--

-- invalid values
select dist_emaj.dist_emaj_remove_group('dummy_cluster', 'dummy_database', 'dummy_group');
select dist_emaj.dist_emaj_remove_group('a_cluster', 'dummy_database', 'dummy_group');

-- ok
select dist_emaj.dist_emaj_remove_group('a_cluster', 'a_database', 'a_group');
-- not assigned group
select dist_emaj.dist_emaj_remove_group('a_cluster', 'a_database', 'a_group');
select dist_emaj.dist_emaj_remove_group('a_cluster', 'a_database', 'a_group', true);


delete from dist_emaj.dist_emaj_database where db_name = 'a_database';
delete from dist_emaj.dist_emaj_cluster where clst_name = 'a_cluster';

--
-- prepare the clusters configuration for the next script.
--

select dist_emaj.dist_emaj_create_database('emaj_1', 'host=localhost port=' || pg_catalog.current_setting('port') || ' dbname=regression_1 user=_regress_emaj_adm password=adm', 2);
select dist_emaj.dist_emaj_create_database('emaj_2', 'postgresql://_regress_emaj_adm:adm@localhost:' || pg_catalog.current_setting('port') || '/regression_2', 2);

select dist_emaj.dist_emaj_create_cluster('my_cluster');
select dist_emaj.dist_emaj_create_cluster('empty_cluster');

select dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_1', 'myGroup1');
select dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_1', 'myGroup2');
select dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_2', 'phil''s group#3",');
select dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_2', 'myGroup4');
select dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_2', 'myGroup5');
select dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_2', 'myGroup6');

--
-- Test dist_emaj_verify_cluster
-- (Note that the distributed rollback states cleanup is tested in the rollback.sql script)
--

-- unknown cluster
select dist_emaj.dist_emaj_verify_cluster('dummy');
-- empty cluster
select dist_emaj.dist_emaj_verify_cluster('empty_cluster');
select dist_emaj.dist_emaj_verify_cluster('empty_cluster', TRUE);
-- emaj is missing in a database
create database regression_no_emaj;
select dist_emaj.dist_emaj_create_database('no_emaj', 'host=localhost port=' || pg_catalog.current_setting('port') || ' dbname=regression_no_emaj user=_regress_emaj_adm password=adm', 1);
begin;
  select dist_emaj.dist_emaj_create_cluster('buggy_cluster');
  select dist_emaj.dist_emaj_assign_group('buggy_cluster', 'no_emaj', 'myGroup1');
  select dist_emaj.dist_emaj_verify_cluster('buggy_cluster');
rollback;
-- keep the database and the database for dist_emaj_verify_all() tests in misc.sql

-- should be OK
select dist_emaj.dist_emaj_verify_cluster('my_cluster');

--
-- Check dist_emaj tables content
--
select hist_id, hist_function, hist_event, hist_object, regexp_replace(hist_wording, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d', '%', 'g'), hist_user
  from dist_emaj.dist_emaj_hist where hist_id >= 1000 order by 1;
select * from dist_emaj.dist_emaj_cluster order by 1;
select * from dist_emaj.dist_emaj_database order by 1;
select * from dist_emaj.dist_emaj_cluster_group order by 1,2,3;

-----------------------------
-- dist_emaj_export_clusters_configuration() and dist_emaj_import_clusters_configuration() tests.
-----------------------------
--
-- Direct export.
--
--   Bad selected clusters array.
SELECT dist_emaj.dist_emaj_export_clusters_configuration(ARRAY['my_cluster', 'unknown1', 'unknown2']);

-- Ok.
SELECT json_array_length(dist_emaj.dist_emaj_export_clusters_configuration()->'clusters');
SELECT json_array_length(dist_emaj.dist_emaj_export_clusters_configuration()->'databases');
SELECT json_array_length(dist_emaj.dist_emaj_export_clusters_configuration(ARRAY['my_cluster', 'empty_cluster'])->'clusters');

--
-- Export to a file.
--
--   Error.
SELECT dist_emaj.dist_emaj_export_clusters_configuration('/tmp/dummy/location/file');

--   Ok.
SELECT dist_emaj.dist_emaj_export_clusters_configuration(:'EMAJTESTTMPDIR' || '/orig_clusters_config_all.json');
SELECT dist_emaj.dist_emaj_export_clusters_configuration(:'EMAJTESTTMPDIR' || '/orig_clusters_config_partial.json', ARRAY['my_cluster']);
\! wc -l $EMAJTESTTMPDIR/*.json
\! grep -v ', at ' $EMAJTESTTMPDIR/orig_clusters_config_all.json

--
-- Direct import.
--
--   Bad content.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "dummy_json": null }'::JSON);

-- databases checks.
--   Missing or null "database" attribute.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "unknown_attr1": null } ] }'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": null } ] }'::JSON);
--   Unknown and missing attributes.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "unknown1": 1, "unknown2": 2 } ] }'::JSON);
--   Null "connect_string" attribute.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "connect_string": null, "rollback_parallel_sessions": 1 } ] }'::JSON);
--   Null or not numeric "rollback_parallel_sessions" attribute.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "connect_string": "cnx1", "rollback_parallel_sessions": null} ] }'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "connect_string": "cnx1", "rollback_parallel_sessions": "?"} ] }'::JSON);

-- Clusters checks.
--   Missing or null "cluster" attribute.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ {  } ]}'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": null } ]}'::JSON);
--   Unknown attributes.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "unknown1": 1, "unknown2": 2 } ]}'::JSON);
--   Missing or invalid "group" attribute.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1" } ]}'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": "???" } ]}'::JSON);
--   In group, missing "database" or "group" attributes or invalid attributes.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ { } ] } ]}'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ { "database": "ssss"} ] } ]}'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ { "group": "gggg"} ] } ]}'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ { "database": "", "group": null, "unknown_attr1": null} ] } ]}'::JSON);

-- Databases or clusters referenced several times.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "connect_string": "c1", "rollback_parallel_sessions": 1},
                                                                         { "database": "db2", "connect_string": "c2", "rollback_parallel_sessions": 1},
                                                                         { "database": "db1", "connect_string": "c1", "rollback_parallel_sessions": 1} ] }'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ ] },
                                                                          { "cluster": "clst2", "groups": [ ] },
                                                                          { "cluster": "clst1", "groups": [ ] } ]}'::JSON);
-- Selected clusters not in the JSON structure.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ ] } ]}'::JSON, array['unknown_1', 'unknown_2']);
-- Selected clusters already exist.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "my_cluster", "groups": [ ] } ]}'::JSON, array['my_cluster'], NULL, FALSE);
-- Selected databases not in the JSON structure.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "connect_string": "c1", "rollback_parallel_sessions": 1} ] }'::JSON,
                                                         NULL, array['unknown_1', 'unknown_2']);
-- Selected databases already exist.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "emaj_1", "connect_string": "c1", "rollback_parallel_sessions": 1} ] }'::JSON,
                                                         NULL, array['emaj_1'], FALSE);
-- Database referenced by a cluster but does not exist and is no in the JSON configuration.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ 
          "databases": [ { "database": "db1", "connect_string": "cstr1", "rollback_parallel_sessions": 2 }, { "database": "db2", "connect_string": "cstr2", "rollback_parallel_sessions": 3 } ],
          "clusters": [ { "cluster": "clst1", "groups": [ {"database": "db1", "group": "g1"}, {"database": "db3", "group": "g2"} ] } ]
                                                          }'::JSON);
-- OK.
-- Nothing imported because of empty selected clusters and databases arrays.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ 
          "databases": [ { "database": "db1", "connect_string": "cstr1", "rollback_parallel_sessions": 2 } ],
          "clusters": [ { "cluster": "clst1", "groups": [ {"database": "db1", "group": "g1"}, {"database": "db1", "group": "g2"} ] } ]
                                                          }'::JSON, ARRAY[]::TEXT[], ARRAY[]::TEXT[]);
-- Create 2 new databases.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ 
          "databases": [ { "database": "new_db1", "connect_string": "cstr1", "rollback_parallel_sessions": 1 },
                         { "database": "new_db2", "connect_string": "cstr2", "rollback_parallel_sessions": 2 } ]
                                                          }'::JSON);
select db_name, db_connect_string, db_rlbk_parallel_session, db_creation_time_id, db_last_alter_time_id from dist_emaj.dist_emaj_database where db_name like 'new%';
-- Update both databases (one wit a modified connect string and the other with a modified rollback_parallel_sessions).
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{
          "databases": [ { "database": "new_db1", "connect_string": "modified_cstr1", "rollback_parallel_sessions": 2 },
                         { "database": "new_db2", "connect_string": "cstr2", "rollback_parallel_sessions": 5 } ] }'::JSON, NULL, NULL, TRUE);
select db_name, db_connect_string, db_rlbk_parallel_session, db_creation_time_id, db_last_alter_time_id from dist_emaj.dist_emaj_database where db_name like 'new%';

-- Create a cluster with a few groups.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{
          "clusters": [ { "cluster": "new_cluster", "groups": [ {"database": "new_db1", "group": "g1"}, {"database": "new_db2", "group": "g2"} ] } ]
                                                          }'::JSON);
select * from dist_emaj.dist_emaj_cluster where clst_name = 'new_cluster';
select * from dist_emaj.dist_emaj_cluster_group where clgrp_cluster = 'new_cluster' order by 1, 2, 3;
-- Update the cluster with 1 new group and 1 group removed.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{
          "clusters": [ { "cluster": "new_cluster", "groups": [ {"database": "new_db1", "group": "g1"}, {"database": "new_db2", "group": "g3"} ] } ]
                                                          }'::JSON, NULL, NULL, TRUE);
select * from dist_emaj.dist_emaj_cluster_group where clgrp_cluster = 'new_cluster' order by 1, 2, 3;

--
-- Import from file.
--
-- File does not exist.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('/tmp/dummy/location/file');
-- Not a JSON format.
\! echo 'not a JSON format' > $EMAJTESTTMPDIR/not_json
SELECT dist_emaj.dist_emaj_import_clusters_configuration(:'EMAJTESTTMPDIR' || '/not_json');
-- Import the original configuration. This drops the new_cluster, new_db1 and new_db2 objects.
SELECT dist_emaj.dist_emaj_import_clusters_configuration(:'EMAJTESTTMPDIR' || '/orig_clusters_config_all.json', NULL, NULL, TRUE, TRUE);

-----------------------------
-- Test end: global check.
-----------------------------

SELECT hist_function, hist_event, hist_object, hist_wording, hist_user
  FROM dist_emaj.dist_emaj_hist WHERE hist_id >= 1000 ORDER BY hist_id;
SELECT time_id, time_event FROM dist_emaj.dist_emaj_time_stamp ORDER BY time_id;

-- Remove the temp directory.
\! rm -R $EMAJTESTTMPDIR
