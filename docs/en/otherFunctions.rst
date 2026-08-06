Other Functions
===============

.. _dist_emaj_verify_cluster:

Verifying the State of a Cluster
--------------------------------

Once a *cluster* is created and populated with table groups, you can verify its state by executing the following SQL query::

   SELECT dist_emaj.dist_emaj_verify_cluster(p_cluster, p_checkEmptyCluster);

**Input Parameters**

- ``p_cluster`` (*TEXT*): **Name of the cluster** to verify.
- ``p_checkEmptyCluster`` (*BOOLEAN*):

   - *FALSE*, default value: The *cluster* may contain no table groups.
   - *TRUE*: If the *cluster* contains no table groups, the function generates an error.

**Returned Data**

The function does not return any data.

**Notes**

The function checks that:

- The cluster exists,
- The cluster has at least one assigned table group (checked on demand),
- All servers accessed by the *cluster* are accessible via *dblink*, contain the *emaj* extension, and can handle global transactions,
- All table groups assigned to the *cluster* exist.

The function also updates the state of *distributed rollback* operations that are reputed to be in progress.

This function is called by the two clients: :doc:`distEmaj.pl<distEmajClient>` and :doc:`distEmajRollback.pl<distEmajRollbackClient>`. However, it can also be called manually, particularly right after configuring the *cluster*.

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

- All *servers*:

   - Are accessible via *dblink*,
   - Contain a valid version of the *emaj* extension,
   - Can handle global transactions,
- All table groups assigned to the cluster exist.

If no anomalies are detected, the function returns a single row containing the message::

   'No error detected'

Additionally, the function generates a warning message for any *cluster* with no assigned table groups and for any *server* with no table groups referencing it.

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
