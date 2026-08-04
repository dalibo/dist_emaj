Autres fonctions
================

.. _dist_emaj_verify_cluster:

Vérifier l'état d'un cluster
----------------------------

Une fois un *cluster* créé et garni de groupes de tables, il est possible d'en vérifier l'état en exécutant la requête SQL : ::

   SELECT dist_emaj.dist_emaj_verify_cluster(p_cluster, p_checkEmptyCluster);

**Paramètres en entrée**

- ``p_cluster`` (*TEXT*) : **Nom du cluster** à vérifier.
- ``p_checkEmptyCluster`` (*BOOLEAN*) :

   - *FALSE*, valeur par défaut : Le *cluster* peut ne contenir aucun groupe de tables.
   - *TRUE* : Si le *cluster* ne contient aucun groupe de tables, la fonction génère une erreur.

**Données retournées**

La fonction ne retourne aucune donnée.

**Notes**

La fonction vérifie que :

- le cluster existe,
- le cluster a au moins un groupe de table assigné (contrôle à la demande),
- tous les serveurs accédés par le *cluster* sont accessibles par dblink, contiennent l'extension *emaj* et peuvent gérer des transactions globales,
- tous les groupes de tables assignés au *cluster* existent.

La fonction procède aussi à une mise à jour de l'état des opérations de *rollback distribués* réputés en cours.

La fonction est appelée par les deux clients :doc:`distEmaj.pl<distEmajClient>` and :doc:`distEmajRollback.pl<distEmajRollbackClient>` clients. Mais elle peut aussi être appelée manuellement, notamment juste après le *cluster* configuré.

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

- tous les *serveurs* :

   - sont accessibles par *dblink*,
   - contiennent une extension *emaj* dans une version valide,
   - peuvent gérer des transactions globales,
- tous les groupes de tables assignés au cluster existent.

Si aucune anomalie n'est détectée, la fonction retourne une unique ligne contenant le message : ::

   'No error detected'

De plus, la fonction génère un message d'avertissement pour tout *cluster* n'ayant aucun groupe de tables assigné et pour tout *serveur* n'ayant aucun groupe de tables qui le référence.

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

