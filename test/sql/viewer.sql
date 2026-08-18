-- viewer.sql : test dist_emaj data access and functions calls by a dist_emaj_viewer role
--

-- do not display DETAIL and CONTEXT outputs when an error is raised (\errverbose can be used to debug a statement)
\set VERBOSITY terse

--
-- Prepare the test context
--

-- set sequence restart value
select public.handle_dist_emaj_sequences(5000);

set session_authorization to _regress_dist_emaj_viewer;

-----------------------------
-- authorized table or view accesses
-----------------------------
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_hist) as t;
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_all_param) as t;
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_hist) as t;
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_time_stamp) as t;
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_cluster) as t;
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_cluster_group) as t;
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_mark) as t;
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_mark_group) as t;
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_rlbk) as t;
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_rlbk_database) as t;

-----------------------------
-- forbiden table accesses (just test 1 delete)
-----------------------------
delete from dist_emaj.dist_emaj_hist;

-----------------------------
-- dist_emaj_database specific case
-----------------------------

-- authorized
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_database) as t;
select db_name, db_rlbk_parallel_session from dist_emaj.dist_emaj_database order by 1;
select clst_name, db_name, db_rlbk_parallel_session, db_groups_array from dist_emaj.dist_emaj_database_aggregates order by 1, 2;

-- forbidden
select * from dist_emaj.dist_emaj_database;
delete from dist_emaj.dist_emaj_database;
select * from dist_emaj.dist_emaj_database_aggregates;

-----------------------------
-- authorized functions
-----------------------------

select dist_emaj.dist_emaj_get_version();

-----------------------------
-- forbiden functions (just test 1)
-----------------------------
select dist_emaj.dist_emaj_verify_cluster('my_cluster');

--
reset session_authorization;
