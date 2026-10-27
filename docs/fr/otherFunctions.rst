Autres fonctions
================

.. _dist_emaj_get_version:

Obtenir la version courante de l’extension dist_emaj
----------------------------------------------------

La fonction ``dist_emaj_get_version()`` retourne l’identifiant de la version courante de l’extension *dist_emaj* : ::

   SELECT dist_emaj.dist_emaj_get_version();

**Paramètres en entrée**

La fonction n'a pas de paramètre en entrée.

**Données retournées**

La fonction retourne une représentation textuelle de la version courante de l'extension *dist_emaj*.

----

.. _dist_emaj_verify_cluster:

Vérifier l'état d'un cluster
----------------------------

Une fois un *cluster* créé et garni de groupes de tables, il est possible d'en vérifier l'état en exécutant la requête SQL : ::

   SELECT dist_emaj.dist_emaj_verify_cluster(p_cluster);

**Paramètres en entrée**

- ``p_cluster`` (*TEXT*) : **Nom du cluster** à vérifier.

**Données retournées**

Si aucune anomalie n'est détectée, la fonction retourne le nombre de groupes de tables assignés au cluster.

**Notes**

La fonction vérifie que :

- le *cluster* existe,
- toutes les *databases* accédées par le *cluster* :

   - sont accessibles par dblink,
   - contiennent l'extension *emaj* dans une version compatible,
   - sont accédées par un rôle ayant les droits d'administration E-Maj,
- toutes les instances PostgreSQL hébergeant les *databases* ont un paramètre *max_prepared_transactions* suffisamment élevé pour gérer le nombre de sessions demandées dans les transactions globales,
- tous les groupes de tables assignés au *cluster* existent.

La fonction procède aussi à une mise à jour de l'état des opérations de *rollback distribués* réputés en cours.

----

.. _dist_emaj_verify_all:

Vérifier la consistance de l'installation Distributed E-Maj
-----------------------------------------------------------

Pour vérifier la consistance de l'environnement Distrbuted E-Maj, exécuter la requête suivante : ::

   SELECT * FROM dist_emaj.dist_emaj_verify_all();

**Paramètres en entrée**

La fonction n'a pas de paramètre en entrée.

**Données retournées**

La fonction retourne un ensemble de messages textuels qui décrivent les éventuelles anomalies rencontrées.

**Notes**

La fonction vérifie que :

- toutes les *databases* :

   - sont accessibles par *dblink*,
   - contiennent une extension *emaj* dans une version compatible,
   - sont accédées par un rôle ayant les droits d'administration E-Maj,
- toutes les instances PostgreSQL accédées ont un paramètre *max_prepared_transactions* suffisamment élevé pour gérer le nombre de sessions demandées dans les transactions globales,
- tous les groupes de tables assignés au *cluster* existent.

Si aucune anomalie n'est détectée, la fonction retourne une unique ligne contenant le message : ::

   'No error detected'

De plus, la fonction génère un message d'avertissement pour tout *cluster* n'ayant aucun groupe de tables assigné et pour toute *database* n'ayant aucun groupe de tables qui la référence.

La fonction procède aussi à une mise à jour de l'état des opérations de *rollback distribués* réputés en cours.

----

.. _dist_emaj_purge_histories:

Purger les historiques
----------------------

Distributed E-Maj historise certaines données : traces globales de fonctionnement, détail des rollbacks distribués (:ref:`plus de détails...<dist_emaj_hist>`). Les traces les plus anciennes sont automatiquement purgées par l’extension. Mais une fonction permet également de déclencher la purge de manière manuelle ::

   SELECT dist_emaj.dist_emaj_purge_histories(p_retentionDelay);

**Paramètres en entrée**

- ``p_retentionDelay`` (*INTERVAL*, optionnel) : **Délai de rétention** des historiques. S’il est présent, il surcharge le paramètre Distributed E-Maj *history_retention*.

**Données retournées**

La fonction retourne un message de synthèse des suppressions effectuées.

