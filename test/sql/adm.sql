-- adm.sql : test dist_emaj data access and functions calls by a dist_emaj_adm role.
--

-- Do not display DETAIL and CONTEXT outputs when an error is raised (\errverbose can be used to debug a statement).
\set VERBOSITY terse

--
-- Prepare the test context.
--

-- Set sequence restart value.
SELECT public.handle_dist_emaj_sequences(6000);

SET session_authorization TO _regress_dist_emaj_adm;
--

--
-- Handle parameters.
--

-- Try to directly update a parameter.
UPDATE dist_emaj.dist_emaj_param set param_value = '1 MONTHS' WHERE param_key = 'history_retention';
-- Update a parameter key.
SELECT dist_emaj.dist_emaj_set_param('history_retention', '1 MONTHS');
-- List all existing keys.
SELECT * FROM dist_emaj.dist_emaj_all_param ORDER BY param_rank;

--
RESET session_authorization;
