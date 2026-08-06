Architecture and Operating Principles
=====================================

.. raw:: html

    <style>
      img.screenshot {
        margin-bottom: 10px;
        border: 1px solid grey;
        box-shadow: 3px 3px 6px rgba(0, 0, 0, 0.4);
      }
    </style>

Architecture
------------

The E-Maj Extensions
^^^^^^^^^^^^^^^^^^^^

Each *E-Maj server* has its own *emaj* extension, where its table groups are created and configured.

The dist_emaj Extension
^^^^^^^^^^^^^^^^^^^^^^^

A **dist_emaj** extension must be created in any PostgreSQL database on the network. This database can itself host an *emaj* extension.

The *dist_emaj* extension contains some technical tables and functions that enable its usage.

The functions allow, in particular, the **configuration** of *clusters* (with their attached table groups) and *servers* (with their network access parameters).

----

Operating Principles
--------------------

Global Consistency
^^^^^^^^^^^^^^^^^^

To ensure the consistency of operations, particularly *distributed rollbacks*, all operations on clusters are performed within **single and global transactions**, validated by **two-phase commit**.

Implementing global transactions requires that the concerned operations be initiated outside of PostgreSQL. To achieve this, **two Perl clients** are provided:

- ``distEmaj.pl``:

   - **Starts** a *cluster*, meaning it starts all the table groups attached to it,
   - **Stops** a *cluster*, meaning it stops all the table groups attached to it,
   - **Sets** a *distributed mark* on all table groups attached to the *cluster*.

- ``distEmajRollback.pl``: Performs a **distributed rollback** targeting a *distributed mark* for a *cluster*.

Parallelization
^^^^^^^^^^^^^^^

The longest steps of the operations are **executed in parallel** across all *servers* in the *cluster*.

Additionally, the main steps of a **rollback** on a *server* can themselves be distributed across **multiple sessions**. The number of *rollback sessions* to use is one of the configuration parameters of a server.

Independence Between E-Maj and Dist-Emaj
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**The E-Maj extensions are not aware of the dist_emaj extensions** that reference them.

Thus, for a given *server*:

- Starting or stopping a *cluster* locally translates to the "simple" starting or stopping of the table groups hosted by the *server*,
- Setting a *distributed mark* locally translates to setting a simple *mark* on the table groups,
- Executing a *distributed rollback* locally proceeds like a standard rollback of the table groups.

**A table group can be referenced by multiple clusters** in one or more *dist_emaj* extensions.

----

Configuration Examples
----------------------

Simple Configuration of a Cluster
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. figure:: images/cluster_simple_configuration_en.png
   :align: center
   :class: screenshot

   Figure 1 – Configuration of a *cluster*.

Here, 1 *cluster* includes 4 table groups distributed across 3 different *servers*, with "grp_A" and "grp_B" located on the same database.

Complex Configuration of Multiple Clusters
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. figure:: images/cluster_complex_configuration_en.png
   :align: center
   :class: screenshot

   Figure 2 – Complex configuration.

This example includes:

- 3 *clusters* distributed across 2 *dist_emaj* extensions,
- Both *dist_emaj* and *emaj* extensions coexist on the *server* "srv_4",
- On server "srv_3", the table group "grp_H" is not associated with any *cluster*.
