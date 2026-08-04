Tracabilité
===========

.. _dist_emaj_hist:

La table dist_emaj_hist
-----------------------

Toutes les opérations significatives réalisées par Distributed E-Maj sont tracées dans la table *dist_emaj_hist*.

Tout utilisateur disposant des droits *dist_emaj_adm* ou *dist_emaj_viewer* peut visualiser le contenu de la table *dist_emaj_hist*.

Structure de la table
^^^^^^^^^^^^^^^^^^^^^

La structure de la table **dist_emaj_hist** est la suivante.

+--------------+-------------+---------------------------------------------------------------------------+
|Colonne       | Type        | Description                                                               |
+==============+=============+===========================================================================+
|hist_id       | BIGSERIAL   | numéro de série identifiant une ligne dans cette table historique         |
+--------------+-------------+---------------------------------------------------------------------------+
|hist_datetime | TIMESTAMPTZ | date et heure d'enregistrement de la ligne                                |
+--------------+-------------+---------------------------------------------------------------------------+
|hist_function | TEXT        | fonction associée à l'événement                                           |
+--------------+-------------+---------------------------------------------------------------------------+
|hist_event    | TEXT        | type d'événement                                                          |
+--------------+-------------+---------------------------------------------------------------------------+
|hist_object   | TEXT        | nom de l'objet sur lequel porte l'événement (groupe, table, séquence,...) |
+--------------+-------------+---------------------------------------------------------------------------+
|hist_wording  | TEXT        | commentaires complémentaires                                              |
+--------------+-------------+---------------------------------------------------------------------------+
|hist_user     | TEXT        | rôle à l'origine de l'événement                                           |
+--------------+-------------+---------------------------------------------------------------------------+
|hist_txid     | BIGINT      | numéro de la transaction à l'origine de l'événement                       |
+--------------+-------------+---------------------------------------------------------------------------+

La colonne *hist_function*
^^^^^^^^^^^^^^^^^^^^^^^^^^

La colonne *hist_function* peut prendre les valeurs suivantes.

+----------------------------------+------------------------------------------------------------------------------------------+
| Valeur                           | Signification                                                                            |
+==================================+==========================================================================================+
| ASSIGN_GROUP                     | affectation d’un groupe à un cluster                                                     |
+----------------------------------+------------------------------------------------------------------------------------------+
| CREATE_CLUSTER                   | création d'un cluster                                                                    |
+----------------------------------+------------------------------------------------------------------------------------------+
| CREATE_SERVER                    | création d'un serveur                                                                    |
+----------------------------------+------------------------------------------------------------------------------------------+
| DELETE_BEFORE_MARK_CLUSTER       | suppression des marques distribuées antérieure à une marque pour un cluster              |
+----------------------------------+------------------------------------------------------------------------------------------+
| DIST_EMAJ                        | exécution d'une fonction distribuée (start, stop, set_mark) pour un cluster              |
+----------------------------------+------------------------------------------------------------------------------------------+
| DIST_EMAJ_INSTALL                | installation ou mise à jour de la version de Distributed E-Maj                           |
+----------------------------------+------------------------------------------------------------------------------------------+
| DROP_CLUSTER                     | suppression d'un cluster                                                                 |
+----------------------------------+------------------------------------------------------------------------------------------+
| DROP_SERVER                      | suppression d'un serveur                                                                 |
+----------------------------------+------------------------------------------------------------------------------------------+
| PURGE_HISTORIES                  | suppression de la table *dist_emaj_hist* des événements antérieurs au délai de rétention |
+----------------------------------+------------------------------------------------------------------------------------------+
| REMOVE_GROUP                     | suppression d’un groupe de tables de son cluster                                         |
+----------------------------------+------------------------------------------------------------------------------------------+
| ROLLBACK_GROUPS                  | exécution d'un rollback distribué pour un cluster                                        |
+----------------------------------+------------------------------------------------------------------------------------------+
| SET_PARAM                        | changement de valeur d’un paramètre Distributed E-Maj                                    |
+----------------------------------+------------------------------------------------------------------------------------------+
| SYNC_MARKS_CLUSTER               | synchronisation des marques locales des groupes de tables d'un cluster                   |
+----------------------------------+------------------------------------------------------------------------------------------+
| VERIFY_CLUSTER                   | vérification de l'état d'un cluster                                                      |
+----------------------------------+------------------------------------------------------------------------------------------+

La colonne *hist_event*
^^^^^^^^^^^^^^^^^^^^^^^

La colonne *hist_event* peut prendre les valeurs suivantes.

+------------------------------+------------------------------------------------------------------------+
| Valeur                       | Signification                                                          |
+==============================+========================================================================+
| BEGIN                        | début                                                                  |
+------------------------------+------------------------------------------------------------------------+
| DELETED PARAMETER            | paramètre supprimé dans *dist_emaj_param*                              |
+------------------------------+------------------------------------------------------------------------+
| CLEANUP_RLBK_STATE           | nettoyage de l'état des rollbacks                                      |
+------------------------------+------------------------------------------------------------------------+
| DELETED MARKS                | marques supprimées                                                     |
+------------------------------+------------------------------------------------------------------------+
| END                          | fin                                                                    |
+------------------------------+------------------------------------------------------------------------+
| EXEC                         | début de phase d'exécution d'une fonction distribuée                   |
+------------------------------+------------------------------------------------------------------------+
| INIT                         | début de phase d'initialisation d'une fonction distribuée              |
+------------------------------+------------------------------------------------------------------------+
| INSERTED PARAMETER           | paramètre inséré dans *dist_emaj_param*                                |
+------------------------------+------------------------------------------------------------------------+
| LOCK                         | début de phase de verrouilage d'une fonction distribuée                |
+------------------------------+------------------------------------------------------------------------+
| RESOLVE_MARK                 | résolution d'un nom de marque distribuée                               |
+------------------------------+------------------------------------------------------------------------+
| TIME STAMP SET               | empreinte temporelle interne enregistrée                               |
+------------------------------+------------------------------------------------------------------------+
| UPDATED PARAMETER            | paramètre modifié dans *dist_emaj_param*                               |
+------------------------------+------------------------------------------------------------------------+

----

Serveurs E-Maj
--------------

Chaque serveur E-Maj trace de son côté les opérations élémentaires qui le concernent. (Voir la documentation E-Maj).
