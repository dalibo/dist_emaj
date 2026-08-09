List of Distributed E-Maj Functions
====================================

The available *Distributed E-Maj* functions for users are listed below in alphabetical order.

All these functions can be called by roles with *dist_emaj_adm* privileges. The chart also specifies those callable by **dist_emaj_viewer** roles (sign **(V)** behind the function name).

+--------------------------------------------------+-------------------------------+----------------------------------+
| Functions                                        | Input Parameters              | Returned Data                    |
+==================================================+===============================+==================================+
| :ref:`dist_emaj_assign_group                     | | p_cluster TEXT              | # groups assigned (0/1) INT      |
| <dist_emaj_assign_group>`                        | | p_server TEXT               |                                  |
|                                                  | | p_group TEXT                |                                  |
|                                                  | | [ p_ifNotExists BOOLEAN ]   |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_create_cluster                   | | p_cluster TEXT              | # clusters created (0/1) INT     |
| <dist_emaj_create_cluster>`                      | | [ p_ifNotExists BOOLEAN ]   |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_create_server                    | | p_server TEXT               | # servers created (0/1) INT      |
| <dist_emaj_create_server>`                       | | p_connectString TEXT        |                                  |
|                                                  | | p_rollbackParallelSession   |                                  |
|                                                  | | INT                         |                                  |
|                                                  | | [ p_ifNotExists BOOLEAN ]   |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_delete_before_mark_cluster       | | p_cluster TEXT              | # marks deleted INT              |
| <dist_emaj_delete_before_mark_cluster>`          | | p_mark TEXT                 |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_drop_cluster                     | | p_cluster TEXT              | # clusters deleted (0/1) INT     |
| <dist_emaj_drop_cluster>`                        | | [ p_ifExists BOOLEAN ]      |                                  |
|                                                  | | [ p_cascade BOOLEAN ]       |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_drop_extension                   |                               |                                  |
| <dist_emaj_drop_extension>`                      |                               |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_drop_server                      | | p_server TEXT               | # servers deleted (0/1) INT      |
| <dist_emaj_drop_server>`                         | | [ p_ifExists BOOLEAN ]      |                                  |
|                                                  | | [ p_cascade BOOLEAN ]       |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_export_parameters_configuration  | [ p_includeDefault BOOLEAN ]  | parameters JSON                  |
| <export_param_conf>`                             |                               |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_export_parameters_configuration  | | p_location TEXT             | # parameters INT                 |
| <export_param_conf>`                             | | [ p_includeDefault BOOLEAN ]|                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_get_version                      |                               | version TEXT                     |
| <dist_emaj_get_version>` (V)                     |                               |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_import_parameters_configuration  | | p_paramsJson JSON           | # parameters INT                 |
| <import_param_conf>`                             | | [ p_resetOtherParameters    |                                  |
|                                                  | |  BOOLEAN) ]                 |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_import_parameters_configuration  | | p_location TEXT             | # parameters INT                 |
| <import_param_conf>`                             | | [ p_resetOtherParameters    |                                  |
|                                                  | |  BOOLEAN)]                  |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_purge_histories                  | [ p_retentionDelay INTERVAL ] | Summary TEXT                     |
| <dist_emaj_purge_histories>`                     |                               |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_remove_group                     | | p_cluster TEXT              | # groups removed (0/1) INT       |
| <dist_emaj_remove_group>`                        | | p_server TEXT               |                                  |
|                                                  | | p_group TEXT                |                                  |
|                                                  | | [ p_ifAssigned BOOLEAN ]    |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_set_param                        | | p_key TEXT                  | # parameters modified (0/1) INT  |
| <dist_emaj_set_param>`                           | | p_value TEXT                |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_sync_marks_cluster               | | p_cluster TEXT              | # marks deleted INT              |
| <dist_emaj_sync_marks_cluster>`                  |                               |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_verify_all                       |                               | SETOF message TEXT               |
| <dist_emaj_verify_all>`                          |                               |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
| :ref:`dist_emaj_verify_cluster                   | | p_cluster TEXT              |                                  |
| <dist_emaj_verify_cluster>`                      | | [ p_checkEmptyCluster       |                                  |
|                                                  | | BOOLEAN ]                   |                                  |
+--------------------------------------------------+-------------------------------+----------------------------------+
