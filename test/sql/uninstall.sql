-- uninstall.sql : test of the emaj EXTENSION drop
--

-- Try to DROP the dist_emaj schema
drop schema dist_emaj cascade;

-- Try to DROP EXTENSION
drop extension dist_emaj;

-- Call the dist_emaj_drop_extension function
select dist_emaj.dist_emaj_drop_extension();

-- Check that the extension and the dist_emaj schema are not known anymore
\dx dist_emaj
\dn dist_emaj

-- Drop the extra extensions to get a stable re-install test
drop extension dblink;
