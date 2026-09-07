Distributed Rollback Client
============================

The ``distEmajRollback`` client is a tool dedicated to submitting **distributed E-Maj rollbacks**. It allows you to restore a **cluster of table groups** to the state of a **distributed mark** in a **consistent and efficient** manner. It is an external client that runs from the command line.

Prerequisites
-------------

The tool is written in *Perl*. It requires that **Perl** software with the *DBI* and *DBD::Pg* modules be installed on the server executing this command.

----

Syntax
------

The command syntax is as follows::

   distEmajRollback.pl --cluster <cluster> --mark <target_mark> [OPTION]...

**Generic Program Information**:

- ``--help``: Output the **help** message and exit.
- ``--version``: Output the **version** information of the client and exit.

**Mandatory Parameters**:

- ``cluster``: Name of the **cluster**.
- ``target_mark``: Name of the **target distributed mark** for the rollback.

**Other Options**:

- ``--alter-groups-allowed`` or ``--aga``: Allows a rollback to a mark prior to a change in the structure of a table group (by default, any attempt to roll back to a mark prior to a structural change in one of the table groups in the *cluster* is prohibited).
- ``--comment <comment>``: Defines a **comment** describing the distributed mark being set (optional).
- ``--logged``: The rollbacks of the table groups in the *cluster* are **logged** (*logged rollbacks*) (by default, rollbacks are unlogged).
- ``--verbose``: Display more **details** about the execution of the rollback.

**Options for Connecting to the Database Hosting the dist_emaj Extension**

- ``-d <database>``: **Database** to connect to.
- ``-h <host>``: **Host** to connect to.
- ``-p <IP>``: **IP port** to use.
- ``-U <role>``: **Connection role**.
- ``-W <password>``: **Password** associated with the connection role, if required.

To replace all or part of the connection parameters, the usual environment variables *PGDATABASE*, *PGPORT*, *PGHOST*, and/or *PGUSER* can also be used.

The provided connection role must have *dist_emaj_adm* privileges.

For security reasons, it is not recommended to use the ``-W`` option to provide a password. It is preferable to use the *.pgpass* file (see PostgreSQL documentation).

----

Command Examples
----------------

The command::

   distEmajRollback.pl -h localhost -p 5432 -d myDb -U distemajadmin --cluster myCluster --mark Before_Processing_Start

executes an unlogged rollback of the *cluster* 'myCluster', targeting the distributed mark 'Before_Processing_Start'.

The command::

   distEmajRollback.pl -d myDb -U distemajadmin --cluster myCluster --mark Before_Processing_Start --logged --alter-groups-allowed --comment "Logged rollback before program abort"

executes a logged rollback of the *cluster* 'myCluster', targeting the distributed mark 'Before_Processing_Start', allowing intermediate structural changes in the table groups, and associating a comment with it.

----

Notes
-----

The rollback of the *cluster* is performed within a **global transaction**, and the table groups are **locked** for the occasion. This ensures:

- That the rollback is correctly performed for **all table groups** across the different *databases*, or not performed for any of the groups in case of an anomaly,
- That at the end of the rollback, all table groups in the *cluster* are in a **consistent state**, corresponding to the targeted distributed mark.

The target mark for the rollback must correspond to the same point in time for all table groups in the *cluster*. The mark name must match the one specified when setting the mark with ``distEmaj.pl``. However, this mark may have been renamed locally for one of the table groups.

If the distributed rollback is logged, two distributed marks frame the operation.

**Process**

The tool first checks the entered parameters and options. Then, on each of the *databases* hosting the relevant table groups, it opens as many connections as indicated by the ``p_rollbackParallelSession`` parameter provided in the call to the :ref:`dist_emaj_create_database()<dist_emaj_create_database>` function that created the *database* in the Distributed E-Maj configuration. It then starts a transaction on each opened connection.

The rollback operation is then divided into **6 steps**:

1. **Initialization**: Each *database* is accessed sequentially on its first opened connection to verify its ability to execute the rollback (state of the groups, validity of the target mark name, etc.) and to schedule the elementary rollback operations. If there is an anomaly, the operation is stopped.
2. **Locking**: A lock is placed on the table groups of each *database*. Asynchronous calls on all opened connections allow this action to be parallelized.
3. **Starting**: Each *database* is accessed sequentially on its first opened connection to record the effective start of the operation. If the rollback is logged, the rollback start mark is set.
4. **Execution**: Each *database* is again requested to execute the scheduled elementary actions, also asynchronously and across all opened connections.
5. **Finalization**: Each *database* is accessed sequentially on its first opened connection to finalize its rollback. If the rollback is logged, the rollback end mark is set.
6. **Validation**: Once all finalization steps are completed, any distributed marks are recorded, and the global transaction is committed using a **two-phase COMMIT**.

During the execution of a *distributed rollback*, any other operation on the concerned *cluster* (configuration change, mark set, etc) is postponed until the *distributed rollback* completion.

Distributed rollbacks are recorded in the database of the *dist_emaj* extension. The operation is also traced in the ``dist_emaj.dist_emaj_hist`` table.

The *emaj* extensions on the *databases* are not aware of the distributed nature of the rollbacks performed. The E-Maj functions executed are the same as those used in a "non-distributed" context. Consequently, the same checks and the same elementary operations are performed; the same traceability is ensured.
