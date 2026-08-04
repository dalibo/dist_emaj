Gérer les marques distribuées
=============================

Principes
---------

Les marques distribuées sont créées par les deux clients :doc:`distEmaj<distEmajClient>` et :doc:`distEmajRollback<distEmajRollbackClient>` (pour les marques encadrant les rollbacks distribués tracés).

La fonction :ref:`dist_emaj_delete_before_mark_cluster()<dist_emaj_delete_before_mark_cluster>` permet de supprimer les marques distribuées les plus anciennes.

Sur les environnements E-Maj des *serveurs*, le caractère "distribué" d'une marque n'est pas connu : rien ne distingue une marque correspondant à une marque distribuée des autres marques. Aussi une marque correspondant à une marque distribuée d'un *cluster* peut être renommée ou supprimée.

Le **renommage d'une marque** correspondant à une marque distribuée n'empêche pas un éventuelle utilisation comme cible d'un rollback distribué.

En revanche, la **suppression d'une marque** correspondant à une marque distribuée rend caduque cette marque distribuée pour l'ensemble du *cluster* concerné.

La fonction :ref:`dist_emaj_sync_marks_cluster()<dist_emaj_sync_marks_cluster>` permet de synchroniser les marques distribuées entre les *serveurs* et *dist_emaj*. Elle est appelée automatiquement par les deux clients :doc:`distEmaj<distEmajClient>` et :doc:`distEmajRollback<distEmajRollbackClient>`. Mais elle peut également être appelée à la demande.

----

.. _dist_emaj_delete_before_mark_cluster:

Supprimer les marques les plus anciennes d'un *cluster*
-------------------------------------------------------

Pour supprimer les marques distribuées d'un *cluster*, antérieures à une marque donnée, exécuter la requête SQL : ::

   SELECT dist_emaj.dist_emaj_delete_before_mark_cluster(p_cluster, p_mark);

**Paramètres en entrée**

- ``p_cluster`` (*TEXT*) : **Nom du cluster**.
- ``p_mark`` (*TEXT*) : **Nom de la marque** distribuée devenant la plus ancienne marque connue.

**Données retournées**

La fonction retourne le nombre de marques distribuées supprimées.

**Notes**

La fonction accède à tous les *serveurs* concernés par le *cluster* pour supprimer toutes les marques locales antérieures à la marque citée (y compris les marques non distribuées).

----

.. _dist_emaj_sync_marks_cluster:

Synchroniser les marques d'un *cluster*
---------------------------------------

Pour resynchroniser les marques distribuées d'un *cluster*, exécuter la requête SQL : ::

   SELECT dist_emaj.dist_emaj_sync_marks_cluster(p_cluster);

**Paramètres en entrée**

- ``p_cluster`` (*TEXT*) : **Nom du cluster** à resynchroniser.

**Données retournées**

La fonction retourne le nombre de marques distribuées supprimées.

**Notes**

La fonction accède à tous les *serveurs* concernés par le *cluster* pour examiner l'état des groupes de tables et les marques existantes.

Si un groupe de tables est inactif, toutes les marques distribuées du *cluster* sont supprimées.

Toutes les marques distribuées antérieures au plus récent démarrage de groupe de tables sont supprimées également.

Si une marque locale correspondant à une marque distribuée a été supprimée, cette marque distribuée est supprimée.
