Configuring Distributed E-Maj Clusters
======================================

To configure a *cluster*, you must follow these steps:

- Create a *cluster* object,
- Create *server* objects describing the databases hosting the table groups that are members of the *cluster*,
- Assign the table groups to the *cluster*, associated with their *server*.

A dedicated function exists for each of these steps. Symmetrically, functions allow you to:

- Remove a table group from its *cluster*,
- Delete a *server*,
- Delete a *cluster*.

----

.. _dist_emaj_create_cluster:

Creating a Cluster
------------------

To create a *cluster* of table groups, execute the following SQL query::

   SELECT dist_emaj.dist_emaj_create_cluster(p_cluster, p_ifNotExists);

**Input Parameters**

- ``p_cluster`` (*TEXT*): **Name of the cluster** to create.
- ``p_ifNotExists`` (*BOOLEAN*, optional):

   - *FALSE*, default value: If the cluster already exists, the function generates an **exception**.
   - *TRUE*: If the cluster already exists, the function completes without error.

**Returned Data**

The function returns the number of *clusters* created by the function (0 or 1).

**Notes**

The *cluster* is created empty. You must then assign table groups to it.

The ``p_ifNotExists`` parameter facilitates writing idempotent administration scripts.

----

.. _dist_emaj_create_server:

Creating or Modifying a Server
-------------------------------

The *server* object describes how to access a table group assigned to a cluster. It therefore represents a PostgreSQL database equipped with an *emaj* extension.

To create or modify a *server*, execute the following SQL query::

   SELECT dist_emaj.dist_emaj_create_server(p_server, p_connectString, p_rollbackParallelSession, p_ifNotExists);

**Input Parameters**

- ``p_server`` (*TEXT*): **Name of the server** to create.
- ``p_connectString`` (*TEXT*): **Connection string** to the *server*.
- ``p_rollbackParallelSession`` (*INT*): Number of **concurrent sessions** to use for this server in **distributed rollback** operations.
- ``p_ifNotExists`` (*BOOLEAN*, optional):

   - *FALSE*, default value: If the server already exists, the function generates an **exception**.
   - *TRUE*: If the server already exists, the function records the new connection parameters and completes without error.

**Returned Data**

The function returns the number of *servers* created (0 or 1).

**Notes**

The connection string provided by the ``p_connectString`` parameter is used by both the *Perl* clients and the *dblink* calls of the administration functions. It must be in *libpq* format (see PostgreSQL documentation). Some examples::

   'host=localhost port=5432 dbname=my_db user=my_emaj_adm_role password=my_password'
   'postgresql://my_emaj_adm_role:my_password@localhost:5432/my_db'
   'service=server_1'

.. caution::

   Prefer access configurations that avoid passwords in configuration strings (e.g., *.pgpass* files, services). If your *server* configuration scripts contain plaintext passwords, ensure you protect access to these scripts.

The role used to connect to a *server* must have the *emaj_adm* privilege on that *server*.

The function does not verify the validity of the *server* access parameters provided. To verify effective access to the *server*, you can use the functions :ref:`dist_emaj_verify_cluster()<dist_emaj_verify_cluster>` or :ref:`dist_emaj_verify_all()<dist_emaj_verify_all>`, once the table groups are assigned to the cluster.

The ``p_ifNotExists`` parameter facilitates writing idempotent administration scripts.

----

.. _dist_emaj_assign_group:

Assigning a Table Group to a Cluster
------------------------------------

To assign a table group to a *cluster*, execute the following SQL query::

   SELECT dist_emaj.dist_emaj_assign_group(p_cluster, p_server, p_group, p_ifNotExists);

**Input Parameters**

- ``p_cluster`` (*TEXT*): **Name of the cluster**.
- ``p_server`` (*TEXT*): **Name of the server** hosting the table group.
- ``p_group`` (*TEXT*): **Name of the table group**.
- ``p_ifNotExists`` (*BOOLEAN*, optional):

   - *FALSE*, default value: If the table group is already assigned to the *cluster*, the function generates an **exception**.
   - *TRUE*: If the table group is already assigned to the *cluster*, the function completes without error.

**Returned Data**

The function returns the number of table groups assigned by the function (0 or 1).

**Notes**

A table group can be assigned to **multiple different clusters**.

The ``p_ifNotExists`` parameter facilitates writing idempotent administration scripts.

----

.. _dist_emaj_remove_group:

Removing a Table Group from Its Cluster
---------------------------------------

To remove a table group from a *cluster*, execute the following SQL query::

   SELECT dist_emaj.dist_emaj_remove_group(p_cluster, p_server, p_group, p_ifAssigned);

**Input Parameters**

- ``p_cluster`` (*TEXT*): **Name of the cluster**.
- ``p_server`` (*TEXT*): **Name of the server** hosting the table group.
- ``p_group`` (*TEXT*): **Name of the table group**.
- ``p_ifAssigned`` (*BOOLEAN*, optional):

   - *FALSE*, default value: If the table group is not currently assigned to the cluster, the function generates an **exception**.
   - *TRUE*: If the table group is not currently assigned to the cluster, the function completes without error.

**Returned Data**

The function returns the number of table groups removed by the function (0 or 1).

**Notes**

The ``p_ifAssigned`` parameter facilitates writing idempotent administration scripts.

----

.. _dist_emaj_drop_server:

Deleting a Server
-----------------

To delete a *server*, execute the following SQL query::

   SELECT dist_emaj.dist_emaj_drop_server(p_server, p_ifExists, p_cascade);

**Input Parameters**

- ``p_server`` (*TEXT*): **Name of the server** to delete.
- ``p_ifExists`` (*BOOLEAN*, optional):

   - *FALSE*, default value: If the *server* does not exist, the function generates an **exception**.
   - *TRUE*: If the *server* does not exist, the function completes without error.
- ``p_cascade`` (*BOOLEAN*, optional):

   - *FALSE*, default value: If the *server* is referenced by assigned table groups, the function generates an **exception**.
   - *TRUE*: If the *server* is referenced by assigned table groups, these groups are automatically removed from their cluster, and the function completes without error.

**Returned Data**

The function returns the number of *servers* deleted by the function (0 or 1).

**Notes**

The ``p_ifExists`` parameter facilitates writing idempotent administration scripts.

----

.. _dist_emaj_drop_cluster:

Deleting a Cluster
------------------

To delete a *cluster* of table groups, execute the following SQL query::

   SELECT dist_emaj.dist_emaj_drop_cluster(p_cluster, p_ifExists, p_cascade);

**Input Parameters**

- ``p_cluster`` (*TEXT*): **Name of the cluster** to delete.
- ``p_ifExists`` (*BOOLEAN*, optional):

   - *FALSE*, default value: If the *cluster* does not exist, the function generates an **exception**.
   - *TRUE*: If the cluster does not exist, the function completes without error.
- ``p_cascade`` (*BOOLEAN*, optional):

   - *FALSE*, default value: If the *cluster* still has assigned table groups, the function generates an **exception**.
   - *TRUE*: If the cluster still has assigned table groups, these groups are automatically removed, and the function completes without error.

**Returned Data**

The function returns the number of *clusters* deleted by the function (0 or 1).

**Notes**

The ``p_ifExists`` parameter facilitates writing idempotent administration scripts.
