Managing Distributed Marks
===========================

Principles
----------

Distributed marks are created by the two clients: :doc:`distEmaj<distEmajClient>` and :doc:`distEmajRollback<distEmajRollbackClient>` (for marks framing logged distributed rollbacks).

The function :ref:`dist_emaj_delete_before_mark_cluster()<dist_emaj_delete_before_mark_cluster>` allows you to delete the oldest distributed marks.

In the E-Maj environments of the *databases*, the "distributed" nature of a mark is not known: nothing distinguishes a mark corresponding to a distributed mark from other marks. Thus, a mark corresponding to a distributed mark of a *cluster* can be renamed or deleted.

**Renaming a mark** corresponding to a distributed mark does not prevent its potential use as a target for a distributed rollback.

However, **deleting a mark** corresponding to a distributed mark invalidates that distributed mark for the entire *cluster* concerned.

The function :ref:`dist_emaj_sync_marks_cluster()<dist_emaj_sync_marks_cluster>` allows you to synchronize distributed marks between *databases* and *dist_emaj*. It is automatically called by the two clients :doc:`distEmaj<distEmajClient>` and :doc:`distEmajRollback<distEmajRollbackClient>`. However, it can also be called on demand.

----

.. _dist_emaj_delete_before_mark_cluster:

Deleting the Oldest Marks of a *Cluster*
----------------------------------------

To delete the distributed marks of a *cluster* that are older than a given mark, execute the following SQL query::

   SELECT dist_emaj.dist_emaj_delete_before_mark_cluster(p_cluster, p_mark);

**Input Parameters**

- ``p_cluster`` (*TEXT*): **Name of the cluster**.
- ``p_mark`` (*TEXT*): **Name of the distributed mark** becoming the oldest known mark.

**Returned Data**

The function returns the number of distributed marks deleted.

**Notes**

The function accesses all *databases* involved in the *cluster* to delete all local marks prior to the specified mark (including non-distributed marks).

----

.. _dist_emaj_sync_marks_cluster:

Synchronizing the Marks of a *Cluster*
---------------------------------------

To resynchronize the distributed marks of a *cluster*, execute the following SQL query::

   SELECT dist_emaj.dist_emaj_sync_marks_cluster(p_cluster);

**Input Parameters**

- ``p_cluster`` (*TEXT*): **Name of the cluster** to resynchronize.

**Returned Data**

The function returns the number of distributed marks deleted.

**Notes**

The function accesses all *databases* involved in the *cluster* to examine the state of the table groups and existing marks.

If a table group is inactive, all distributed marks of the *cluster* are deleted.

All distributed marks prior to the most recent start of a table group are also deleted.

If a local mark corresponding to a distributed mark has been deleted, that distributed mark is deleted.
