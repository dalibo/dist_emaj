Setting Up Distributed E-Maj Access Policy
==========================================

Improper use of Distributed E-Maj can compromise the integrity of databases. Therefore, it is recommended to restrict its usage to qualified and clearly identified users.

Distributed E-Maj Roles
-----------------------

To use Distributed E-Maj, you can connect as a *SUPERUSER*. However, for security reasons, it is preferable to use the two roles created during the installation process:

* ``dist_emaj_adm``: The Distributed E-Maj administration role:

   * It can execute all functions and access all tables in the *dist_emaj* schema, both for reading and updating.

* ``dist_emaj_viewer``: The read-only access role:

   * It can read all tables in the *dist_emaj* schema, except for the column in the *dist_emaj_database* table that contains the database connection strings.

All rights granted to *dist_emaj_viewer* are also granted to *dist_emaj_adm*.

When created, these two roles were not granted login capabilities (no password and *NOLOGIN* option specified). It is **recommended NOT to grant them login capabilities**. Instead, you can assign their permissions to other roles using SQL *GRANT* commands.

----

Granting Distributed E-Maj Rights
----------------------------------

To grant a specific role all the permissions associated with either *dist_emaj_adm* or *dist_emaj_viewer*, and once connected as a *SUPERUSER*, simply execute one of the following commands::

   GRANT dist_emaj_adm TO <my.admin.role>;
   GRANT dist_emaj_viewer TO <my.readonly.role>;
