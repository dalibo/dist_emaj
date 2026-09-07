-- create_drop.sql : non regression tests for Distributed E-Maj objects creation and drop.
-- It tests in particular:
--   Dist_emaj_create_database(), dist_emaj_drop_database(),
--   Dist_emaj_create_cluster(), dist_emaj_drop_cluster(),
--   Dist_emaj_assign_group(), dist_emaj_remove_group(),
--   Dist_emaj_export_clusters_configuration(), dist_emaj_import_clusters_configuration().
--
-- Prepare the test context.
--

-- Set sequence restart value.
SELECT public.handle_dist_emaj_sequences(1000);

-- Define and create the temp file directory to be used by the script.
\setenv EMAJTESTTMPDIR '/tmp/emaj_'`echo $PGVER`'/create_drop'
\set EMAJTESTTMPDIR `echo $EMAJTESTTMPDIR`
\! mkdir -p $EMAJTESTTMPDIR

--
-- Test dist_emaj_create_database().
--

-- Illegal value.
SELECT dist_emaj.dist_emaj_create_database(NULL, 'a connect string', 2);
SELECT dist_emaj.dist_emaj_create_database('first_database', NULL, 2);
SELECT dist_emaj.dist_emaj_create_database('first_database', 'a connect string', NULL);
SELECT dist_emaj.dist_emaj_create_database('first_database', 'a connect string', 0);

-- Ok.
SELECT dist_emaj.dist_emaj_create_database('first_database', 'a connect string', 2);
SELECT * FROM dist_emaj.dist_emaj_database WHERE db_name = 'first_database';
-- Already created.
SELECT dist_emaj.dist_emaj_create_database('first_database', 'another connect string', 3);
SELECT dist_emaj.dist_emaj_create_database('first_database', 'another connect string', 3, TRUE);
SELECT * FROM dist_emaj.dist_emaj_database WHERE db_name = 'first_database';

--
-- Test dist_emaj_drop_database().
--

-- Database does not exist.
SELECT dist_emaj.dist_emaj_drop_database('dummy_database');
SELECT dist_emaj.dist_emaj_drop_database('dummy_database', TRUE);

-- An assigned group.
INSERT INTO dist_emaj.dist_emaj_cluster (clst_name) VALUES ('a_cluster');
INSERT INTO dist_emaj.dist_emaj_cluster_group VALUES ('a_cluster', 'first_database', 'a group');
-- But CASCADE is not allowed.
SELECT dist_emaj.dist_emaj_drop_database('first_database');
-- Ok, CASCADE is now allowed.
SELECT dist_emaj.dist_emaj_drop_database('first_database', FALSE, TRUE);

DELETE FROM dist_emaj.dist_emaj_cluster WHERE clst_name = 'a_cluster';

--
-- Test dist_emaj_create_cluster().
--

-- Illegal value.
SELECT dist_emaj.dist_emaj_create_cluster(NULL);
-- Ok.
SELECT dist_emaj.dist_emaj_create_cluster('first_cluster');
-- Already created.
SELECT dist_emaj.dist_emaj_create_cluster('first_cluster');
SELECT dist_emaj.dist_emaj_create_cluster('first_cluster', TRUE);

--
-- Test dist_emaj_drop_cluster().
--

-- Cluster does not exist.
SELECT dist_emaj.dist_emaj_drop_cluster('dummy_cluster');
SELECT dist_emaj.dist_emaj_drop_cluster('dummy_cluster', TRUE);

-- An assigned group.
INSERT INTO dist_emaj.dist_emaj_database (db_name, db_connect_string, db_rlbk_parallel_session) VALUES ('a_database', 'a connect string', 1);
INSERT INTO dist_emaj.dist_emaj_cluster_group VALUES ('first_cluster', 'a_database', 'a group');
-- But CASCADE is not allowed.
SELECT dist_emaj.dist_emaj_drop_cluster('first_cluster');
-- Ok, CASCADE is now allowed.
SELECT dist_emaj.dist_emaj_drop_cluster('first_cluster', FALSE, TRUE);

DELETE FROM dist_emaj.dist_emaj_database WHERE db_name = 'a_database';

--
-- Test dist_emaj_assign_group().
--

INSERT INTO dist_emaj.dist_emaj_cluster (clst_name) VALUES ('a_cluster');
INSERT INTO dist_emaj.dist_emaj_database (db_name, db_connect_string, db_rlbk_parallel_session) VALUES ('a_database', 'a connect string', 1);

-- Invalid values.
SELECT dist_emaj.dist_emaj_assign_group('dummy_cluster', 'dummy_database', 'dummy_group');
SELECT dist_emaj.dist_emaj_assign_group('a_cluster', 'dummy_database', 'dummy_group');

-- Ok.
SELECT dist_emaj.dist_emaj_assign_group('a_cluster', 'a_database', 'a_group');

-- Already assigned.
SELECT dist_emaj.dist_emaj_assign_group('a_cluster', 'a_database', 'a_group');
SELECT dist_emaj.dist_emaj_assign_group('a_cluster', 'a_database', 'a_group', TRUE);

--
-- Test dist_emaj_remove_group().
--

-- Invalid values.
SELECT dist_emaj.dist_emaj_remove_group('dummy_cluster', 'dummy_database', 'dummy_group');
SELECT dist_emaj.dist_emaj_remove_group('a_cluster', 'dummy_database', 'dummy_group');

-- Ok.
SELECT dist_emaj.dist_emaj_remove_group('a_cluster', 'a_database', 'a_group');
-- Not assigned group.
SELECT dist_emaj.dist_emaj_remove_group('a_cluster', 'a_database', 'a_group');
SELECT dist_emaj.dist_emaj_remove_group('a_cluster', 'a_database', 'a_group', TRUE);


DELETE FROM dist_emaj.dist_emaj_database WHERE db_name = 'a_database';
DELETE FROM dist_emaj.dist_emaj_cluster WHERE clst_name = 'a_cluster';

--
-- Prepare the clusters configuration for the next script.
--

SELECT dist_emaj.dist_emaj_create_database('emaj_1', 'host=localhost port=' || pg_catalog.current_setting('port') || ' dbname=regression_1 user=_regress_emaj_adm password=adm', 2);
SELECT dist_emaj.dist_emaj_create_database('emaj_2', 'postgresql://_regress_emaj_adm:adm@localhost:' || pg_catalog.current_setting('port') || '/regression_2', 2);

SELECT dist_emaj.dist_emaj_create_cluster('my_cluster');
SELECT dist_emaj.dist_emaj_create_cluster('empty_cluster');

SELECT dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_1', 'myGroup1');
SELECT dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_1', 'myGroup2');
SELECT dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_2', 'phil''s group#3",');
SELECT dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_2', 'myGroup4');
SELECT dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_2', 'myGroup5');
SELECT dist_emaj.dist_emaj_assign_group('my_cluster', 'emaj_2', 'myGroup6');

--
-- Test dist_emaj_verify_cluster.
-- (Note that the distributed rollback states cleanup is tested in the rollback.sql script).
--

-- Unknown cluster.
SELECT dist_emaj.dist_emaj_verify_cluster('dummy');
-- Empty cluster.
SELECT dist_emaj.dist_emaj_verify_cluster('empty_cluster');
SELECT dist_emaj.dist_emaj_verify_cluster('empty_cluster', TRUE);
-- emaj is missing in a database.
CREATE DATABASE regression_no_emaj;
SELECT dist_emaj.dist_emaj_create_database('no_emaj', 'host=localhost port=' || pg_catalog.current_setting('port') || ' dbname=regression_no_emaj user=_regress_emaj_adm password=adm', 1);
BEGIN;
  SELECT dist_emaj.dist_emaj_create_cluster('buggy_cluster');
  SELECT dist_emaj.dist_emaj_assign_group('buggy_cluster', 'no_emaj', 'myGroup1');
  SELECT dist_emaj.dist_emaj_verify_cluster('buggy_cluster');
ROLLBACK;
-- Keep the database and the database for dist_emaj_verify_all() tests in misc.sql.

-- Should be OK.
SELECT dist_emaj.dist_emaj_verify_cluster('my_cluster');

--
-- Check dist_emaj tables content.
--
SELECT hist_id, hist_function, hist_event, hist_object, regexp_replace(hist_wording, E'\\d\\d\.\\d\\d\\.\\d\\d\\.\\d\\d\\d\\d', '%', 'g'), hist_user
  FROM dist_emaj.dist_emaj_hist WHERE hist_id >= 1000 ORDER BY 1;
SELECT * FROM dist_emaj.dist_emaj_cluster ORDER BY 1;
SELECT * FROM dist_emaj.dist_emaj_database ORDER BY 1;
SELECT * FROM dist_emaj.dist_emaj_cluster_group ORDER BY 1,2,3;

-----------------------------
-- Dist_emaj_export_clusters_configuration() and dist_emaj_import_clusters_configuration() tests.
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
SELECT dist_emaj.dist_emaj_export_clusters_configuration(:'EMAJTESTTMPDIR' || '/orig_clusters_config_all.JSON');
SELECT dist_emaj.dist_emaj_export_clusters_configuration(:'EMAJTESTTMPDIR' || '/orig_clusters_config_partial.JSON', ARRAY['my_cluster']);
\! wc -l $EMAJTESTTMPDIR/*.json
\! grep -v ', at ' $EMAJTESTTMPDIR/orig_clusters_config_all.json

--
-- Direct import.
--
--   Bad content.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "dummy_json": NULL }'::JSON);

-- Databases checks.
--   Missing or null "database" attribute.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "unknown_attr1": NULL } ] }'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": NULL } ] }'::JSON);
--   Unknown and missing attributes.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "unknown1": 1, "unknown2": 2 } ] }'::JSON);
--   Null "connect_string" attribute.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "connect_string": NULL, "rollback_parallel_sessions": 1 } ] }'::JSON);
--   Null or not numeric "rollback_parallel_sessions" attribute.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "connect_string": "cnx1", "rollback_parallel_sessions": NULL} ] }'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "connect_string": "cnx1", "rollback_parallel_sessions": "?"} ] }'::JSON);

-- Clusters checks.
--   Missing or null "cluster" attribute.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ {  } ]}'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": NULL } ]}'::JSON);
--   Unknown attributes.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "unknown1": 1, "unknown2": 2 } ]}'::JSON);
--   Missing or invalid "group" attribute.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1" } ]}'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": "???" } ]}'::JSON);
--   In group, missing "database" or "group" attributes or invalid attributes.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ { } ] } ]}'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ { "database": "ssss"} ] } ]}'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ { "group": "gggg"} ] } ]}'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ { "database": "", "group": NULL, "unknown_attr1": NULL} ] } ]}'::JSON);

-- Databases or clusters referenced several times.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "connect_string": "c1", "rollback_parallel_sessions": 1},
                                                                         { "database": "db2", "connect_string": "c2", "rollback_parallel_sessions": 1},
                                                                         { "database": "db1", "connect_string": "c1", "rollback_parallel_sessions": 1} ] }'::JSON);
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ ] },
                                                                          { "cluster": "clst2", "groups": [ ] },
                                                                          { "cluster": "clst1", "groups": [ ] } ]}'::JSON);
-- Selected clusters not in the JSON structure.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "clst1", "groups": [ ] } ]}'::JSON, ARRAY['unknown_1', 'unknown_2']);
-- Selected clusters already exist.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "clusters": [ { "cluster": "my_cluster", "groups": [ ] } ]}'::JSON, ARRAY['my_cluster'], NULL, FALSE);
-- Selected databases not in the JSON structure.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "db1", "connect_string": "c1", "rollback_parallel_sessions": 1} ] }'::JSON,
                                                         NULL, ARRAY['unknown_1', 'unknown_2']);
-- Selected databases already exist.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{ "databases": [ { "database": "emaj_1", "connect_string": "c1", "rollback_parallel_sessions": 1} ] }'::JSON,
                                                         NULL, ARRAY['emaj_1'], FALSE);
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
SELECT db_name, db_connect_string, db_rlbk_parallel_session, db_creation_time_id, db_last_alter_time_id FROM dist_emaj.dist_emaj_database WHERE db_name LIKE 'new%';
-- Update both databases (one wit a modified connect string and the other with a modified rollback_parallel_sessions).
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{
          "databases": [ { "database": "new_db1", "connect_string": "modified_cstr1", "rollback_parallel_sessions": 2 },
                         { "database": "new_db2", "connect_string": "cstr2", "rollback_parallel_sessions": 5 } ] }'::JSON, NULL, NULL, TRUE);
SELECT db_name, db_connect_string, db_rlbk_parallel_session, db_creation_time_id, db_last_alter_time_id FROM dist_emaj.dist_emaj_database WHERE db_name LIKE 'new%';

-- Create a cluster with a few groups.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{
          "clusters": [ { "cluster": "new_cluster", "groups": [ {"database": "new_db1", "group": "g1"}, {"database": "new_db2", "group": "g2"} ] } ]
                                                          }'::JSON);
SELECT * FROM dist_emaj.dist_emaj_cluster WHERE clst_name = 'new_cluster';
SELECT * FROM dist_emaj.dist_emaj_cluster_group WHERE clgrp_cluster = 'new_cluster' ORDER BY 1, 2, 3;
-- Update the cluster with 1 new group and 1 group removed.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('{
          "clusters": [ { "cluster": "new_cluster", "groups": [ {"database": "new_db1", "group": "g1"}, {"database": "new_db2", "group": "g3"} ] } ]
                                                          }'::JSON, NULL, NULL, TRUE);
SELECT * FROM dist_emaj.dist_emaj_cluster_group WHERE clgrp_cluster = 'new_cluster' ORDER BY 1, 2, 3;

--
-- Import from file.
--
-- File does not exist.
SELECT dist_emaj.dist_emaj_import_clusters_configuration('/tmp/dummy/location/file');
-- Not a JSON format.
\! echo 'not a JSON format' > $EMAJTESTTMPDIR/not_json
SELECT dist_emaj.dist_emaj_import_clusters_configuration(:'EMAJTESTTMPDIR' || '/not_json');
-- Import the original configuration. This drops the new_cluster, new_db1 and new_db2 objects.
SELECT dist_emaj.dist_emaj_import_clusters_configuration(:'EMAJTESTTMPDIR' || '/orig_clusters_config_all.JSON', NULL, NULL, TRUE, TRUE);

-----------------------------
-- Test end: global check.
-----------------------------

SELECT hist_function, hist_event, hist_object, hist_wording, hist_user
  FROM dist_emaj.dist_emaj_hist WHERE hist_id >= 1000 ORDER BY hist_id;
SELECT time_id, time_event FROM dist_emaj.dist_emaj_time_stamp ORDER BY time_id;

-- Remove the temp directory.
\! rm -R $EMAJTESTTMPDIR
