-- uninstall.sql : test of the emaj EXTENSION drop.
--

-- Try to DROP the dist_emaj schema.
DROP SCHEMA dist_emaj CASCADE;

-- Try to DROP EXTENSION.
DROP EXTENSION dist_emaj;

-- Call the dist_emaj_drop_extension function.
SELECT dist_emaj.dist_emaj_drop_extension();

-- Check that the extension and the dist_emaj schema are not known anymore.
\dx dist_emaj
\dn dist_emaj

-- Drop the extra extensions to get a stable re-install test.
DROP EXTENSION dblink;
