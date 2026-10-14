Installing Distributed E-Maj in a Database
==========================================

Distributed E-Maj is installed in a database as an *EXTENSION* (in the PostgreSQL sense). To do this, the user must have **SUPERUSER** privileges.

Creating the dist_emaj Extension
--------------------------------

To create the *dist_emaj* extension in the database, execute the following SQL statement::

   CREATE EXTENSION dist_emaj CASCADE;

After verifying that the PostgreSQL version is compatible with this version of Distributed E-Maj, the installation script creates the *dist_emaj* schema with its technical tables, functions, and a few other objects.

.. caution::

   The **dist_emaj** schema must contain **only objects related to Distributed E-Maj**.

The *dblink* extension is created if it does not already exist.

If they do not already exist, the two roles *dist_emaj_adm* and *dist_emaj_viewer* are also created.

----

.. _postgres_conf_changes:

Changes in the PostgreSQL Instances Configuration
-------------------------------------------------

The PostgreSQL instances that host *emaj databases* and the database containing the *dist_emaj* extension must support distributed transactions (with two-phase commit).

Concretely, the ``max_prepared_transactions`` parameter value of each instance must be at least equal to the sum of parallel opened sessions for all databases of the instance when executing :doc:`distributed rollbacks<distEmajRollbackClient>`. Default value, 0, disables prepared transactions.

.. note::
   Modifying this parameter requires a **PostgreSQL instances restart**.

----

Configuring Distributed E-Maj
-----------------------------

A :ref:`parameter<dist_emaj_param>` influences the operation of Distributed E-Maj.

This step of setting the parameter is **optional**. Its default value allows for correct operation.
