-- adm.sql : test dist_emaj data access and functions calls by a dist_emaj_adm role
--

-- do not display DETAIL and CONTEXT outputs when an error is raised (\errverbose can be used to debug a statement)
\set VERBOSITY terse

--
-- Prepare the test context
--

-- set sequence restart value
select public.handle_dist_emaj_sequences(6000);

set session_authorization to _regress_dist_emaj_adm;
--

--
-- handle parameters
--

-- try to directly update a parameter
update dist_emaj.dist_emaj_param set param_value = '1 MONTHS' where param_key = 'history_retention';
-- update a parameter key
select dist_emaj.dist_emaj_set_param('history_retention', '1 MONTHS');
-- list all existing keys
select * from dist_emaj.dist_emaj_all_param order by param_rank;

--
reset session_authorization;
