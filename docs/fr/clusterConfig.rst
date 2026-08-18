Configurer les clusters Distributed E-Maj
=========================================

Pour configurer un *cluster*, il faut procéder aux étapes suivantes :

- créer un objet *cluster*,
- créer les objets *database* décrivant les bases de données hébergeant les groupes de tables membres du *cluster*,
- assigner au *cluster* les groupes de tables associés à leur *database*.

Une fonction est dédiée à chacune de ces étapes. Symétriquement, des fonctions permettent de :

- retirer un groupe de tables de son *cluster*,
- supprimer une *database*,
- supprimer un *cluster*.

----

.. _dist_emaj_create_cluster:

Créer un cluster
----------------

Pour créer un *cluster* de groupes de tables, exécuter la requête SQL : ::

   SELECT dist_emaj.dist_emaj_create_cluster(p_cluster, p_ifNotExists);

**Paramètres en entrée**

- ``p_cluster`` (*TEXT*) : **Nom du cluster** à créer.
- ``p_ifNotExists`` (*BOOLEAN*, optionnel) :

   - *FALSE*, valeur par défaut : Si le cluster existe déjà, la fonction génère une **exception**.
   - *TRUE* : Si le cluster existe déjà, la fonction se termine sans erreur.

**Données retournées**

La fonction retourne le nombre de *cluster* créé par la fonction (0 ou 1).

**Notes**

Le *cluster* est créé vide. Il faut ensuite lui assigner les groupes de tables.

Le paramètre ``p_ifNotExists`` facilite l'écriture de scripts d'administration idempotents.

----

.. _dist_emaj_create_database:

Créer ou modifier une database
------------------------------

L'objet *database* décrit les moyens d'atteindre un groupe de tables assigné à un cluster. Il représente donc une base de données PostgreSQL munie d'une extension *emaj*.

Pour créer ou modifier une *database*, exécuter la requête SQL : ::

   SELECT dist_emaj.dist_emaj_create_database(p_database, p_connectString, p_rollbackParallelSession, p_ifNotExists);

**Paramètres en entrée**

- ``p_database`` (*TEXT*) : **Nom de la database** à créer.
- ``p_connectString`` (*TEXT*) : **Chaîne de connexion** à la *database*.
- ``p_rollbackParallelSession`` (*INT*) : Nombre de **sessions simultanées** à utiliser pour cette database par les opérations de **rollbacks distribués**.
- ``p_ifNotExists`` (*BOOLEAN*, optionnel) :

   - *FALSE*, valeur par défaut : Si la database existe déjà, la fonction génère une **exception**.
   - *TRUE* : Si la database existe déjà, la fonction enregistre les nouveaux attributs et se termine sans erreur.

**Données retournées**

La fonction retourne le nombre de *database* créée (0 ou 1).

**Notes**

La chaîne de connexion fournie par le paramètre ``p_connectString`` est utilisée à la fois par les clients *Perl* et par les appels *dblink* des fonctions d'administration. Elle doit être au format *libpq* (voir la documentation PostgreSQL). Quelques exemples : ::

   'host=localhost port=5432 dbname=ma_base user=mon_role_emaj_adm password=mot_de_passe'
   'postgresql://mon_role_emaj_adm:mot_de_passe@localhost:5432/ma_base'
   'service=database_1'

.. caution::

   Privilégiez les configurations d'accès qui évitent les mots de passe dans les chaînes de configuration (fichier *.pgpass*, services). Si toutefois vos scripts de configuration des *databases* contiennent des mots de passe en clair, prenez soin de protéger les accès à ces scripts.

Le rôle utilisé pour se connecter à une *database* doit disposer du droit *emaj_adm* sur cette *database*.

La fonction ne vérifie pas la validité des paramètres d'accès à la *database* fournis. Pour vérifier l'accès effectif à la *database*, on peut utiliser les fonctions :ref:`dist_emaj_verify_cluster()<dist_emaj_verify_cluster>` ou :ref:`dist_emaj_verify_all()<dist_emaj_verify_all>`, une fois les groupes de tables assignés au cluster.

Le paramètre ``p_ifNotExists`` facilite l'écriture de scripts d'administration idempotents.

----

.. _dist_emaj_assign_group:

Assigner un groupe de tables à un cluster
-----------------------------------------

Pour assigner un groupe de tables à un *cluster*, exécuter la requête SQL suivante : ::

   SELECT dist_emaj.dist_emaj_assign_group(p_cluster, p_database, p_group, p_ifNotExists);

**Paramètres en entrée**

- ``p_cluster`` (*TEXT*) : **Nom du cluster**.
- ``p_database`` (*TEXT*) : **Nom de la database** hébergeant le groupe de tables.
- ``p_group`` (*TEXT*) : **Nom du groupe** de tables.
- ``p_ifNotExists`` (*BOOLEAN*, optionnel) :

   - *FALSE*, valeur par défaut : Si le groupe de tables est déjà assigné au *cluster*, la fonction génère une **exception**.
   - *TRUE* : Si le groupe de tables est déjà assigné au *cluster*, la fonction se termine sans erreur.

**Données retournées**

La fonction retourne le nombre de groupe de tables assigné par la fonction (0 ou 1).

**Notes**

Un groupe de tables peut être assigné à **plusieurs clusters** différents.

Le paramètre ``p_ifNotExists`` facilite l'écriture de scripts d'administration idempotents.

----

.. _dist_emaj_remove_group:

Sortir un groupe de tables de son cluster
-----------------------------------------

Pour sortir un groupe de tables d'un *cluster*, exécuter la requête SQL suivante : ::

   SELECT dist_emaj.dist_emaj_remove_group(p_cluster, p_database, p_group, p_ifAssigned);

**Paramètres en entrée**

- ``p_cluster`` (*TEXT*) : **Nom du cluster**.
- ``p_database`` (*TEXT*) : **Nom de la database** hébergeant le groupe de tables.
- ``p_group`` (*TEXT*) : **Nom du groupe** de tables.
- ``p_ifAssigned`` (*BOOLEAN*, optionnel) :

   - *FALSE*, valeur par défaut : Si le groupe de tables n'est pas actuellement assigné au cluster, la fonction génère une **exception**.
   - *TRUE* : Si le groupe de tables n'est pas actuellement assigné au cluster, la fonction se termine sans erreur.

**Données retournées**

La fonction retourne le nombre de groupe de tables retiré par la fonction (0 ou 1).

**Notes**

Le paramètre ``p_ifAssigned`` facilite l'écriture de scripts d'administration idempotents.

----

.. _dist_emaj_drop_database:

Supprimer une database
----------------------

Pour supprimer une *database*, exécuter la requête SQL : ::

   SELECT dist_emaj.dist_emaj_drop_database(p_database, p_ifExists, p_cascade);

**Paramètres en entrée**

- ``p_database`` (*TEXT*) : **Nom de la database** à supprimer.
- ``p_ifExists`` (*BOOLEAN*, optionnel) :

   - *FALSE*, valeur par défaut : Si la *database* n'existe pas, la fonction génère une **exception**.
   - *TRUE* : Si la *database* n'existe pas, la fonction se termine sans erreur.
- ``p_cascade``  (*BOOLEAN*, optionnel) :

   - *FALSE*, valeur par défaut : Si la *database* est référencée par des groupes de tables assignés, la fonction génère une **exception**.
   - *TRUE* : Si la *database* est référencée par des groupes de tables assignés, ces groupes sont automatiquement retirés de leur cluster et la fonction se termine sans erreur.

**Données retournées**

La fonction retourne le nombre de *database* supprimée par la fonction (0 ou 1).

**Notes**

Le paramètre ``p_ifExists`` facilite l'écriture de scripts d'administration idempotents.

----

.. _dist_emaj_drop_cluster:

Supprimer un cluster
--------------------

Pour supprimer un *cluster* de groupes de tables, exécuter la requête SQL : ::

   SELECT dist_emaj.dist_emaj_drop_cluster(p_cluster, p_ifExists, p_cascade);

**Paramètres en entrée**

- ``p_cluster`` (*TEXT*) : **Nom du cluster** à supprimer.
- ``p_ifExists`` (*BOOLEAN*, optionnel) :

   - *FALSE*, valeur par défaut : Si le *cluster* n'existe pas, la fonction génère une **exception**.
   - *TRUE* : Si le cluster n'existe pas, la fonction se termine sans erreur.
- ``p_cascade``  (*BOOLEAN*, optionnel) :

   - *FALSE*, valeur par défaut : Si le *cluster* a toujours des groupes de tables assignés, la fonction génère une **exception**.
   - *TRUE* : Si le cluster a toujours des groupes de tables assignés, ces groupes sont automatiquement retirés et la fonction se termine sans erreur.

**Données retournées**

La fonction retourne le nombre de *cluster* supprimé par la fonction (0 ou 1).

**Notes**

Le paramètre ``p_ifExists`` facilite l'écriture de scripts d'administration idempotents.
