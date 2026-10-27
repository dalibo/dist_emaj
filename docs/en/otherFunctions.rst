Other Functions
===============

.. _dist_emaj_get_version:

Getting the Distributed E-Maj Extension Version
-----------------------------------------------

The ``dist_emaj_get_version()`` function returns the **current version** identifier of the *dist_emaj* extension. ::

   SELECT dist_emaj.dist_emaj_get_version();

**Input Parameters**

The function does not require any input parameter.

**Returned data**

The function returns a textual representation of the *dist_emaj* current version.

----

.. _dist_emaj_verify_cluster:

Verifying the State of a Cluster
--------------------------------

Once a *cluster* is created and populated with table groups, you can verify its state by executing the following SQL query::

   SELECT dist_emaj.dist_emaj_verify_cluster(p_cluster);

**Input Parameters**

- ``p_cluster`` (*TEXT*): **Name of the cluster** to verify.

**Returned Data**

If no error is encountered, the function returns the number of assigned table groups.

**Notes**

The function checks that:

- The *cluster* exists.
- All *databases* accessed by the *cluster*:

   - Are accessible via *dblink*.
   - Contain the *emaj* extension in a proper version.
   - Are accessed by a role having E-Maj administration rights.
- All PostgreSQL instances hosting *databases* have a *max_prepared_transactions* parameter large enough to support the number of requested sessions in global transactions.
- All table groups assigned to the *cluster* exist.

The function also updates the state of *distributed rollback* operations that are reputed to be in progress.

----

.. _dist_emaj_verify_all:

Verifying the Consistency of the Distributed E-Maj Installation
---------------------------------------------------------------

To verify the consistency of the Distributed E-Maj environment, execute the following query::

   SELECT * FROM dist_emaj.dist_emaj_verify_all();

**Input Parameters**

The function has no input parameters.

**Returned Data**

The function returns a set of text messages describing any detected anomalies.

**Notes**

The function checks that:

- All *databases*:

   - Are accessible via *dblink*.
   - Contain a compatible version of the *emaj* extension.
   - Are accessed by a role having E-Maj administration rights.
- All PostgreSQL instances hosting *databases* have a *max_prepared_transactions* parameter large enough to support the number of requested sessions in global transactions.
- All table groups assigned to the *cluster* exist.

If no error is detected, the function returns a single row containing the message::

   'No error detected'

Additionally, the function generates a warning message for any *cluster* with no assigned table groups and for any *database* with no table groups referencing it.

The function also updates the state of *distributed rollback* operations that are reputed to be in progress.

----

.. _dist_emaj_purge_histories:

Purging Histories
-----------------

Distributed E-Maj logs certain data: global operation traces, details of distributed rollbacks (:ref:`more details...<dist_emaj_hist>`). The oldest traces are automatically purged by the extension. However, a function also allows you to manually trigger the purge::

   SELECT dist_emaj.dist_emaj_purge_histories(p_retentionDelay);

**Input Parameters**

- ``p_retentionDelay`` (*INTERVAL*, optional): **Retention period** for histories. If provided, it overrides the Distributed E-Maj parameter *history_retention*.

**Returned Data**

The function returns a summary message of the deletions performed.
