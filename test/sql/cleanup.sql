-- cleanup.sql: Clean up the regression test environment, in particular roles 
--              (all components inside the regression database will be deleted with the regression database)

-----------------------------
-- drop the function that checks and sets the last_value of emaj technical sequences
-----------------------------
DROP FUNCTION public.handle_dist_emaj_sequences(INT);

-----------------------------
-- drop roles used for tests
-----------------------------
drop role _regress_dist_emaj_adm;
drop role _regress_dist_emaj_viewer;
drop role _regress_dist_emaj_anonym;

drop role _regress_emaj_adm;
