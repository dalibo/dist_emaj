Liste des fonctions Distributed E-Maj
=====================================

Les fonctions *Distributed E-Maj* disponibles pour les utilisateurs sont listées ci-dessous par ordre alphabétique.

Toutes ces fonctions sont appelables par les rôles disposant des privilèges *dist_emaj_adm*.

+--------------------------------------------------+-------------------------------+---------------------------------------+
| Fonctions                                        | Paramètres en entrée          | Données restituées                    |
+==================================================+===============================+=======================================+
| :ref:`dist_emaj_assign_group                     | | p_cluster TEXT              | nb.groupe.assigné (0/1) INT           |
| <dist_emaj_assign_group>`                        | | p_server TEXT               |                                       |
|                                                  | | p_group TEXT                |                                       |
|                                                  | | [ p_ifNotExists BOOLEAN ]   |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_create_cluster                   | | p_cluster TEXT              | nb.cluster.créé (0/1) INT             |
| <dist_emaj_create_cluster>`                      | | [ p_ifNotExists BOOLEAN ]   |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_create_server                    | | p_server TEXT               | nb.server.créé (0/1) INT              |
| <dist_emaj_create_server>`                       | | p_connectString TEXT        |                                       |
|                                                  | | p_rollbackParallelSession   |                                       |
|                                                  | |                         INT |                                       |
|                                                  | | [ p_ifNotExists BOOLEAN ]   |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_delete_before_mark_cluster       | | p_cluster TEXT              | nb.marques.supprimées INT             |
| <dist_emaj_delete_before_mark_cluster>`          | | p_mark TEXT                 |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_drop_cluster                     | | p_cluster TEXT              | nb.cluster.supprimé (0/1) INT         |
| <dist_emaj_drop_cluster>`                        | | [ p_ifExists BOOLEAN ]      |                                       |
|                                                  | | [ p_cascade BOOLEAN ]       |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_drop_extension                   |                               |                                       |
| <dist_emaj_drop_extension>`                      |                               |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_drop_server                      | | p_server TEXT               | nb.server.supprimé (0/1) INT          |
| <dist_emaj_drop_server>`                         | | [ p_ifExists BOOLEAN ]      |                                       |
|                                                  | | [ p_cascade BOOLEAN ]       |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_purge_histories                  | [ p_retentionDelay INTERVAL ] | bilan TEXT                            |
| <dist_emaj_purge_histories>`                     |                               |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_remove_group                     | | p_cluster TEXT              | nb.groupe.retiré (0/1) INT            |
| <dist_emaj_remove_group>`                        | | p_server TEXT               |                                       |
|                                                  | | p_group TEXT                |                                       |
|                                                  | | [ p_ifAssigned BOOLEAN ]    |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_set_param                        | | p_key TEXT                  | nb.paramètre.modifié (0/1) INT        |
| <dist_emaj_set_param>`                           | | p_value TEXT                |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_sync_marks_cluster               | | p_cluster TEXT              | nb.marques.supprimées INT             |
| <dist_emaj_sync_marks_cluster>`                  |                               |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_verify_all                       |                               | SETOF message TEXT                    |
| <dist_emaj_verify_all>`                          |                               |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
| :ref:`dist_emaj_verify_cluster                   | | p_cluster TEXT              |                                       |
| <dist_emaj_verify_cluster>`                      | | [ p_checkEmptyCluster       |                                       |
|                                                  | |                   BOOLEAN ] |                                       |
+--------------------------------------------------+-------------------------------+---------------------------------------+
