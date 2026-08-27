Distributed Operations Client
=============================

The ``distEmaj`` client allows you to start and stop a *cluster* and set *distributed marks* in a **consistent manner**. It is an external client that runs from the command line.

Prerequisites
-------------

The tool is written in *Perl*. It requires that **Perl** software with the *DBI* and *DBD::Pg* modules be installed on the server executing this command.

----

Syntax
------

The command syntax is as follows::

   distEmaj.pl --action <start|stop|set_mark> --cluster <cluster name> --mark <mark_name> [OPTION]...

**Mandatory Parameters**:

- ``action``: **Action** to execute, which can take one of 3 values:

   - ``start``: starts the *cluster* and sets an initial distributed mark,
   - ``stop``: stops the *cluster* and sets a final distributed mark,
   - ``set_mark``: sets a distributed mark.
- ``cluster``: Name of the **cluster**.
- ``mark``: Name of the **distributed mark** to be set.

**General Options**:

- ``--help``: displays the **help** message.
- ``--version``: displays the **version** information of the client.

**Options Common to All Actions**:

- ``--comment <comment>``: defines a **comment** describing the distributed mark being set (optional).
- ``--verbose``: displays more **details** about the execution of the requested action.

**Options Specific to Starting a Cluster**:

- ``--keep-logs`` or ``--kl``: **keeps the logs** (updates and marks) of the table groups (by default, logs are deleted).
- ``--logging-groups-allowed`` or ``--lga``: allows starting table groups in an **active state** (by default, a group already started generates an error).

**Options Specific to Stopping a Cluster**:

- ``--idle-groups-allowed`` or ``--iga``: allows stopping table groups in an **inactive state** (by default, a group already stopped generates an error).
- ``--reset-logs`` or ``--rl``: **deletes the logs** (updates and marks) of the table groups (by default, logs are kept).

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

   distEmaj.pl -h localhost -p 5432 -d myDb -U distemajadmin --action start --cluster myCluster --mark Start_Mark

starts the *cluster* 'myCluster' (deleting existing logs) and sets an initial mark 'Start_Mark'.

The command::

   distEmaj.pl -d myDb -U distemajadmin --action set_mark --cluster myCluster --mark New_Mark --comment "This is a new mark"

sets a distributed mark named 'New_Mark' on the *cluster* 'myCluster', associating a comment with it.

----

Notes
-----

The action is performed within a **global transaction**, and the table groups are **locked** for the occasion. This ensures:

- That the action is correctly performed for **all table groups** across the different *databases*, or not performed for any of the groups in case of an anomaly,
- That the distributed mark set represents **the same point in time** and **the same stable state** for all table groups in the *cluster*.

**Process**

The tool first checks the entered parameters and options, then opens a connection and starts a transaction on each of the *databases* hosting the relevant table groups.

Then, for each of the three possible actions, the operation is divided into 4 steps:

1. **Initialization**: Each *database* is accessed sequentially to verify its ability to execute the requested operation (state of the groups, validity of the new mark name, etc.). If there is an anomaly, the operation is stopped.
2. **Locking**: A lock is placed on the table groups of each *database*. Asynchronous calls allow this action to be parallelized.
3. **Execution**: Once all locks are in place, each *database* is again requested to execute the action itself, also asynchronously.
4. **Validation**: Once all execution steps are completed, the global transaction is committed using a **two-phase COMMIT**.

Distributed marks are recorded in the database of the *dist_emaj* extension. The operation is also traced in the ``dist_emaj.dist_emaj_hist`` table.

The *emaj* extensions on the *databases* are not aware of the distributed nature of the actions performed. The E-Maj functions executed are the same as those used in a "non-distributed" context. Consequently, the same checks and the same elementary operations are performed; the same traceability is ensured.
