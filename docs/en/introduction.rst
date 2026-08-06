Introduction
============

License
-------

The "*Distributed E-Maj*" software and all accompanying documentation are distributed under the **GNU - General Public License (GPL)**.

----

Objectives of "Distributed E-Maj"
---------------------------------

The E-Maj solution allows recording and potentially rolling back updates made to tables in a PostgreSQL database in a reliable and efficient manner, with a granularity corresponding to coherent sets of tables and sequences, called *table groups*.

*Distributed E-Maj* is a complement to E-Maj that enables **consistent management of table groups distributed across multiple databases**. It allows you to:

- Start and stop table groups,
- Set marks on table groups,
- Roll back table groups to the state of a common mark (*E-Maj rollback*).

Thus, in the event of a rollback of updates (*E-Maj rollback*), *Distributed E-Maj* ensures the consistency of table groups distributed across multiple databases.

These databases can be:

- Connected via logical replication,
- Connected via *Foreign Data Wrappers*,
- Independent.

----

Main Components
---------------

**Distributed E-Maj** consists of:

- A **PostgreSQL extension**, created in each database, named *dist_emaj* and containing a few tables, functions, etc.,
- Two **external clients** that can be called from the command line.
