Client des rollbacks distribués
===============================

Le client ``distEmajRollback`` est un outil dédié à la soumission de **rollbacks E-Maj distribués**. Il permet de remettre un **cluster de groupes de tables** à l'état d'une **marque distribuée** de manière **consistante et efficace**. C'est un client externe qui se lance en ligne de commande.

Préalables
----------

L’outil est codé en *Perl*. Il nécessite que le logiciel **Perl** avec les modules *DBI* et *DBD::Pg* soient installés sur le serveur qui exécute cette commande.

----

Syntaxe
-------

La syntaxe de la commande est la suivante : ::

   distEmajRollback.pl --cluster <cluster> --mark <target_mark> [OPTION]...

**Informations générales sur le programme** :

- ``--help`` : affiche juste l'**aide** en ligne.
- ``--version`` : affiche juste les informations sur la **version** du client.

**Paramètres obligatoires** :

- ``cluster`` : Nom du **cluster**.
- ``target_mark`` : Nom de la **marque distribuée** cible du rollback.

**Autres options** :

- ``--alter-groups-allowed`` ou ``--aga`` : autorise un rollback à une marque antérieure à un changement de structure de groupe de tables (par défaut, toute tentative de rollback à une marque antérieure à un changement de structure de l'un des groupes de tables du *cluster* est interdite).
- ``--comment <commentaire>`` : définit un **commentaire** décrivant la marque distribuée posée (optionnel).
- ``--logged`` : les rollbacks des groupes de tables du *cluster* sont **tracés** (*logged rollbacks*) (par défaut, les rollbacks sont non tracés).
- ``--verbose`` : affiche davantage de **détails** sur l'exécution du rollback.

**Options de connexion à la base de données hébergeant l'extension dist_emaj**

- ``-d <database>`` : **base de données** à atteindre.
- ``-h <hôte>`` : **hôte** à atteindre.
- ``-p <IP>`` : **port** IP à utiliser.
- ``-U <rôle>`` : **rôle** de connexion.
- ``-W <mot de passe>`` : **mot de passe** associé au rôle de connexion, si nécessaire.

Pour remplacer tout ou partie des paramètres de connexion, les variables habituelles *PGDATABASE*, *PGPORT*, *PGHOST* et/ou *PGUSER* peuvent être également utilisées.

Le rôle de connexion fourni doit avoir les droits *dist_emaj_adm*.

Pour des raisons de sécurité, il n'est pas recommandé d'utiliser l'option ``-W`` pour fournir un mot de passe. Il est préférable d'utiliser le fichier *.pgpass* (voir la documentation de PostgreSQL).

----

Exemples de commande
--------------------

La commande : ::

   distEmajRollback.pl -h localhost -p 5432 -d myDb -U distemajadmin --cluster monCluster --mark Avant_début_traitement

exécute un rollback (non tracé) du *cluster* 'monCluster' en ciblant la marque distribuée 'Avant_début_traitement'.

La commande : ::

   distEmajRollback.pl -d myDb -U distemajadmin --cluster monCluster --mark Avant_début_traitement --logged --alter-groups-allowed --comment "Rollback tracé avant l'abort du programme"

exécute un rollback tracé du cluster 'monCluster' en ciblant la marque distribuée 'Avant_début_traitement', en y autorisant des changements intermédiaires de structure de groupe de tables, et en y associant un commentaire.

----

Notes
-----

Le rollback du *cluster* est effectué au sein d'une **transaction globale** et les groupes de tables sont **verrouillés** pour l'occasion. Ceci garantit ainsi :

- que le rollback est correctement réalisé pour **tous les groupes de tables** des différentes databases ou qu'il n'est réalisé pour aucun des groupes, en cas d'anomalie,
- en fin de rollback, tous les groupes de tables du *cluster* sont dans un **état cohérent**, correspondant à la marque distribuée ciblée.

La marque cible du rollback doit correspondre à un même point dans le temps pour l'ensemble des groupes de tables du *cluster*. Le nom de la marque doit correspondre à celui cité lors de la pose de la marque avec distEmaj.pl. Néanmoins, cette marque peut avoir été renommée localement pour l'un des groupes de tables.

Si le rollback distribué est tracé, deux marques distribuées encadrent l'opération.

**Déroulement**

L'outil contrôle d'abord les paramètres et options saisis. Puis, sur chacune des *databases* hébergeant les groupes de tables concernés, il ouvre autant de connexions qu'indiqué par le paramètre ``p_rollbackParallelSession`` fourni à l'appel de la :ref:`fonction dist_emaj_create_database()<dist_emaj_create_database>` qui a créé la *database* dans la configuration d'Emaj Distribué. Il démarre alors une transaction sur chaque connexion ouverte.

Ensuite, l'opération de rollback est découpée en **6 étapes** :

1. **initialisation** : chaque *database* est accédée en séquence sur sa première connexion ouverte, pour vérifier sa capacité à exécuter le rollback (état des groupes, validité du nom de la marque cible, etc) et qu'il planifie les opérations élémentaires du rollback. En cas d'anomalie, l'opération est arrêtée.
2. **verrouillage** : un verrou est posé sur les groupes de tables de chaque *database*. Des appels asynchrones sur toutes les connexions ouvertes permettent de paralléliser cette action.
3. **démarrage** : chaque *database* est accédée en séquence sur sa première connexion ouverte pour qu'il enregistre le démarrage effectif de l'opération. Si le rollback est tracé, la marque de début de rollback est posée.
4. **exécution** : chaque *database* est à nouveau sollicitée pour l'exécution des actions élémentaires planifiées, là aussi de manière asynchrone et sur l'ensemble des connexions ouvertes.
5. **finalisation** : chaque *database* est accédée en séquence sur sa première connexion ouverte pour qu'il finalise son rollback. Si le rollback est tracé, la marque de fin de rollback est posée.
6. **validation** : une fois toutes les étapes de finalisation terminées, les éventuelles marques distribuées sont enregistrées et la transaction globale est validée par un *COMMIT à deux phases*.

Durant l'exécution du *rollback distribué*, toute opération lancée en parallèle sur le *cluster* (modification de configuration, pose de marque, etc) est mise en attente jusqu'à la fin du *rollback distribué*.

Les rollback distribués sont enregistrés dans la base de l'extension *dist_emaj*. L'opération est également tracée dans la table dist_emaj.dist_emaj_hist.

Les extensions *emaj* des *databases* n'ont pas connaissance du caractère distribué des rollbacks effectuées. Les fonctions E-Maj exécutées sont les mêmes que celles utilisées en contexte "non distribué". En conséquence, les mêmes contrôles et les mêmes opérations élémentaires sont réalisés ; la même tracabilité est assurée.
