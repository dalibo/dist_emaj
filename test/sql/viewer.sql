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
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_rlbk_server) as t;

-----------------------------
-- forbiden table accesses (just test 1 delete)
-----------------------------
delete from dist_emaj.dist_emaj_hist;

-----------------------------
-- dist_emaj_server specific case
-----------------------------

-- authorized
select 'select ok' as result from (select count(*) from dist_emaj.dist_emaj_server) as t;
select srv_name, srv_rlbk_parallel_session from dist_emaj.dist_emaj_server order by 1;
select clst_name, srv_name, srv_rlbk_parallel_session, srv_groups_array from dist_emaj.dist_emaj_server_aggregates order by 1, 2;

-- forbidden
select * from dist_emaj.dist_emaj_server;
delete from dist_emaj.dist_emaj_server;
select * from dist_emaj.dist_emaj_server_aggregates;

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
