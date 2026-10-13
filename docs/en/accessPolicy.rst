Setting Up Distributed E-Maj Access Policy
==========================================

Improper use of Distributed E-Maj can compromise the integrity of databases. Therefore, it is recommended to restrict its usage to qualified and clearly identified users.

Distributed E-Maj Roles
-----------------------

To use Distributed E-Maj, you can connect as a *SUPERUSER*. However, for security reasons, it is preferable to use the two roles created during the installation process:

* ``dist_emaj_adm``: The Distributed E-Maj administration role.

   * It owns the ``dist_emaj`` schema and its content (except functions).
   * It can execute all Distributed E-Maj functions.

* ``dist_emaj_viewer``: The read-only access role.

   * It can read all tables in the *dist_emaj* schema, except for the column in the *dist_emaj_database* table that contains the database connection strings.

At creation time, these roles have **no login capability** (*NOLOGIN* attribute and no password). It is **recommended NOT to grant them login capabilities**. Instead, grant the privileges they own to other roles using SQL *GRANT* commands.

----

Granting Distributed E-Maj Rights
----------------------------------

To grant a specific role all the permissions associated with either *dist_emaj_adm* or *dist_emaj_viewer*, and once connected as a *SUPERUSER*, simply execute one of the following commands::

   GRANT dist_emaj_adm TO <my.admin.role>;
   GRANT dist_emaj_viewer TO <my.readonly.role>;
