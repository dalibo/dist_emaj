Impacts of Local E-Maj Actions
==============================

On an E-Maj *database*, there is no information indicating whether a table group is assigned to any *Distributed E-Maj cluster*. If a table group is assigned to a *cluster*, it is therefore the **responsibility of the E-Maj administrator** to avoid performing actions on the table group that could subsequently prevent actions from being carried out at the *cluster* level.

The potential consequences of local E-Maj actions on a *cluster* are described below.

Stopping a Table Group
----------------------

A table group can be stopped locally by executing the *emaj_stop_group()* or *emaj_stop_groups()* function.

If the stopped table group is assigned to a *cluster*:

- The *cluster* can still be stopped by specifying the ``--idle-groups-allowed`` option in the ``distEmaj.pl`` command,
- However, since the stopped table group can no longer be rolled back, no *distributed rollback* will be possible on the *cluster*,
- The next mark synchronization will delete all *distributed marks* of the *cluster*.

----

Setting a Mark
--------------

Using the *emaj_set_mark_group()* and *emaj_set_mark_groups()* functions, it is possible to locally set a mark for a table group.

Since this mark is not common to all table groups in the *cluster*, a *distributed rollback* targeting this mark name will not be possible, even if a mark with the same name is also set locally on the other table groups in the *cluster*.

----

Deleting a Mark
---------------

The *emaj_delete_mark_group()* and *emaj_delete_before_mark_group()* functions locally delete one or more marks for a table group.

If one of these marks corresponds to a *distributed mark* of the *cluster*:

- The next mark synchronization for the *cluster* will delete the distributed mark,
- Consequently, a *distributed rollback* targeting this mark will become impossible on the *cluster*,
- However, the mark will still exist for the other table groups, allowing a local rollback of these table groups.

----

Renaming a Mark
---------------

The *emaj_rename_mark_group()* function locally renames a mark of a table group.

If this mark corresponds to a *distributed mark* of the *cluster*:

- Renaming the mark does not change the name of the associated *distributed mark*,
- A *distributed rollback* targeting this *distributed mark* remains possible:

   - If the table group is the only one on the *database* assigned to the *cluster*,
   - Or if the same renaming is performed for **all table groups on the database**.

----

Protecting a Group or a Mark
----------------------------

The *emaj_protect_group()* and *emaj_protect_mark_group()* functions allow you to locally protect a table group or a mark against an unintended rollback.

If the table group in question is assigned to a *cluster*, this protection naturally applies to *distributed rollbacks* on the *cluster*.
