Uninstalling Distributed E-Maj
===============================

Removing Distributed E-Maj from a Database
------------------------------------------

To remove Distributed E-Maj from a database, the user must connect to this database using *psql* as a **SUPERUSER**.

If you want to **delete the roles** *dist_emaj_adm* and *dist_emaj_viewer*, you must first revoke the rights granted to these roles from any other roles using SQL *REVOKE* statements::

   REVOKE dist_emaj_adm FROM <role_or_list_of_roles>;
   REVOKE dist_emaj_viewer FROM <role_or_list_of_roles>;

.. _dist_emaj_drop_extension:

If these roles, *dist_emaj_adm* and *dist_emaj_viewer*, have access rights on tables or other application relational objects, you must also revoke these rights **in advance** using other SQL *REVOKE* statements.

Although installed by default with a ``CREATE EXTENSION`` statement, the *dist_emaj* extension **cannot** be removed with a simple ``DROP EXTENSION`` query. An event trigger actually blocks the execution of such a statement.

To remove the *dist_emaj* extension, you must call the **dist_emaj_drop_extension()** function with::

   SELECT dist_emaj.dist_emaj_drop_extension();

This function performs the following actions:

- It removes the event trigger that protects the *dist_emaj* extension,
- It removes the extension and the main *dist_emaj* schema,
- It removes the *dist_emaj_adm* and *dist_emaj_viewer* roles if they are not associated with other roles or other databases in the instance and do not have rights on other tables.

----

Uninstalling the Distributed E-Maj Software
-------------------------------------------

The method for uninstalling the Distributed E-Maj software depends on its installation method.

- **Standard installation with the pgxn client**

  Only one command is required::

     pgxn uninstall dist_emaj --sudo

- **Standard installation without the pgxn client**

  Go to the initial directory of the Distributed E-Maj distribution and type::

     sudo make uninstall
