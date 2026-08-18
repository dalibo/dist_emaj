Client des opérations distribuées
=================================

Le client ``distEmaj`` permet de démarrer et arrêter un *cluster* et de poser des *marques distribuées* de **manière consistante**. C'est un client externe qui se lance en ligne de commande.

Préalables
----------

L’outil est codé en *Perl*. Il nécessite que le logiciel **Perl** avec les modules *DBI* et *DBD::Pg* soient installés sur le serveur qui exécute cette commande.

----

Syntaxe
-------

La syntaxe de la commande est la suivante : ::

   distEmaj.pl --action <start|stop|set_mark> --cluster <cluster name> --mark <mark_name> [OPTION]...

**Paramètres obligatoires** :

- ``action`` : **Action** à exécuter, pouvant prendre l'une des 3 valeurs :

   - ``start`` : démarre le *cluster* et pose une marque distribuée initiale,
   - ``stop`` : arrête le *cluster* et pose une marque distribuée finale,
   - ``set_mark`` : pose une marque distribuée.
- ``cluster`` : Nom du **cluster**.
- ``mark`` : Nom de la **marque distribuée** posée.

**Options générales** :

- ``--help`` : affiche juste l'**aide** en ligne.
- ``--version`` : affiche juste les informations sur la **version** du client.

**Options communnes à toutes les actions** :

- ``--comment <commentaire>`` : définit un **commentaire** décrivant la marque distribuée posée (optionnel).
- ``--verbose`` : affiche davantage de **détails** sur l'exécution de l'action demandée.

**Options spécifiques au démarrage d'un cluster** :

- ``--keep-logs`` ou ``--kl``: **conserve les logs** (mises à jour et marques) des groupes de tables (par défaut, les logs sont effacés).
- ``--logging-groups-allowed`` ou ``--lga`` : autorise le démarrage de groupes de tables en **état actif** (par défaut, un groupe déjà démarré génère une erreur).

**Options spécifiques à l'arrêt d'un cluster** :

- ``--idle-groups-allowed`` ou  ``--iga``: autorise l'arrêt de groupes de tables en **état inactif** (par défaut, un groupe déjà arrêté génère une erreur).
- ``--reset-logs`` ou ``--rl`` : **supprime les logs** (mises à jour et marques) des groupes de tables (par défaut, les logs sont conservés).

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

   distEmaj.pl -h localhost -p 5432 -d myDb -U distemajadmin --action start --cluster monCluster --mark Marque_début

démarre le *cluster* 'monCluster' (en effaçant les logs existants) et pose une marque initiale 'Marque_début'.

La commande : ::

   distEmaj.pl -d myDb -U distemajadmin --action set_mark --cluster monCluster --mark Nouvelle_marque --comment "Ceci est une nouvelle marque"

pose une marque distribuée nommée 'Nouvelle_marque' sur le *cluster* 'monCluster', en y associant un commentaire.

----

Notes
-----

L'action est effectuée au sein d'une **transaction globale** et les groupes de tables sont **verrouillés** pour l'occasion. Ceci garantit ainsi :

- que l'action est correctement réalisée pour **tous les groupes de tables** des différentes databases ou qu'elle n'est réalisée pour aucun des groupes, en cas d'anomalie,
- la marque distribuée posée représente **un même point dans le temps** et **un mếme état stable** pour toutes les groupes de tables du *cluster*.

**Déroulement**

L'outil contrôle d'abord les paramètres et options saisis, puis ouvre une connexion et démarre une transaction sur chacune des *databases* hébergeant les groupes de tables concernés.

Ensuite, pour chacune des trois actions possibles, l'opération est découpée en 4 étapes :

- **initialisation** : chaque *database* est accédée en séquence, pour vérifier sa capacité à exécuter l'opération demandée (état des groupes, validité du nom de la nouvelle marque, etc). En cas d'anomalie, l'opération est arrêtée.
- **verrouillage** : un verrou est posé sur les groupes de tables de chaque *database*. Des appels asynchrones permettent de paralléliser cette action.
- **exécution** : une fois tous les verrous posés, chaque *database* est à nouveau sollicitée pour l'exécution de l'action proprement dite, là aussi de manière asynchrone.
- **validation** : une fois toutes les étapes d'exécution terminées, la transaction globale est validée par un *COMMIT à deux phases*.

Les marques distribuées sont enregistrées dans la base de l'extension *dist_emaj*. L'opération est également tracée dans la table dist_emaj.dist_emaj_hist.

Les extensions *emaj* des *databases* n'ont pas connaissance du caractère distribué des actions effectuées. Les fonctions E-Maj exécutées sont les mêmes que celles utilisées en contexte "non distribué". En conséquence, les mêmes contrôles et les mêmes opérations élémentaires sont réalisés ; la même tracabilité est assurée.
