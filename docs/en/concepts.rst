Concepts
========

E-Maj has 3 main concepts: the "*table group*", the "*mark*", and the "*E-Maj rollback*".
*Distributed E-Maj* introduces 4 new concepts.

Database
--------

An "**E-Maj database**" represents a **PostgreSQL database containing an *emaj* extension** and hosting one or more table groups.

It is identified by a unique name.

Cluster
-------

An "**E-Maj groups cluster**" is a **set of table groups distributed across multiple E-Maj databases**.

The *cluster* is the entity on which distributed operations are performed. It is identified by a unique name.

Distributed Mark
----------------

A "**distributed mark**" represents a **point in time common to all table groups in a cluster**.

It is identified by a unique name within the *cluster*.

Distributed E-Maj Rollback
--------------------------

A "**distributed rollback**" operation consists of **restoring all tables and sequences** contained in all table groups **of the cluster to the state of a previously set distributed mark**.

Like *E-Maj rollbacks*, a *distributed rollback* can be **logged** or **unlogged**.
