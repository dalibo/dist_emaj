Installer le logiciel Distributed E-Maj
=======================================

Sources de téléchargement
-------------------------

Distributed E-Maj est disponible en téléchargement depuis les sources suivantes : 

- **PGXN (PostgreSQL Extension Network)** : `https://pgxn.org/dist/dist_emaj/ <https://pgxn.org/dist/dist_emaj/>`_
- **Dépôts GitHub** : `https://github.com/dalibo/dist_emaj <https://github.com/dalibo/dist_emaj>`_

.. caution::
   Installer l’extension à partir du dépôt **GitHub** crée l’extension en **version de développement** ("devel"), même en téléchargeant une version 'taguée'. Il sera alors impossible de procéder à des mises à jour de l'extension dans le futur. Pour une utilisation dans la durée, il est **fortement recommandé** d’utiliser les paquets versionnés disponibles sur **PGXN**.

----

Installation standard sur Linux
-------------------------------

Avec le client pgxn
^^^^^^^^^^^^^^^^^^^

Si le client *pgxn* est installé, une simple commande suffit : ::

  pgxn install dist_emaj --sudo

Sans le client pgxn
^^^^^^^^^^^^^^^^^^^

1. Téléchargez la dernière version de Distributed Emaj depuis le site *pgxn.org*, par un moyen à votre convenance, par exemple avec la commande *wget* : ::
 
     wget https://api.pgxn.org/dist/dist_emaj/<version>/dist_emaj-<version>.zip

2. Décompressez l’archive et installer les composants : ::

     unzip dist_emaj-<version>.zip
     cd dist_emaj-<version>/
     sudo make install

Localisation des composants
^^^^^^^^^^^^^^^^^^^^^^^^^^^

Dans les deux cas de figure, les composants sont installés dans les répertoires usuels des composants PostgreSQL :

- les **scripts SQL** : ``<SHAREDIR>/dist_emaj/``,
- les **clients** en mode ligne de commande : ``<BINDIR>`` (avec les clients PostgreSQL),
- la **documentation** : ``<DOCDIR>/dist_emaj/``.

Pour connaitre la localisation des répertoires *SHAREDIR*, *BINDIR* et *DOCDIR* sur le système, utiliser la commande ``pg_config``.

----

Installation manuelle sur Linux
-------------------------------

1. Télécharger la dernière version de Distributed E-Maj depuis le site *pgxn.org*, par exemple avec la commande *wget* ::

     wget https://api.pgxn.org/dist/dist_emaj/<version>/dist_emaj-<version>.zip

2. Décompresser l’archive avec les commandes suivantes : ::

     unzip dist_emaj-<version>.zip
     cd dist_emaj-<version>/

3. Éditer le fichier **dist_emaj.control** pour valoriser la directive ``directory`` avec le répertoire contenant les scripts d’installation de Distributed E-Maj (chemin absolu du répertoire contenant *dist_emaj-<version>/sql*).

4. Identifier la localisation du répertoire *SHAREDIR*. Vous pouvez utiliser la commande : ::

     pg_config --sharedir

   En cas d'échec, recherchez les localisations typiques, telles que */usr/share/postgresql/<pg_version>* pour Debian ou Ubuntu ou */usr/pgsql-<pg_version>/share* pour RedHat ou CentOS.

5. Copier le fichier *dist_emaj.control* modifié dans le répertoire des extensions de la version de PostgreSQL souhaitée : en tant que super-utilisateur ou en préfixant les commandes avec *sudo*, taper : ::

	cp dist_emaj.control <répertoire_SHAREDIR>/extension/.

La dernière version de Distributed E-Maj est maintenant installée et référencée par PostgreSQL. Le répertoire ``dist_emaj-<version>`` contient l’arborescence :doc:`décrite ici <content>`.

----

Installation sous Windows
-------------------------

Pour installer Distributed E-Maj sous Windows, il faut :

1. **Télécharger** l’extension depuis le `site PGXN <https://pgxn.org/dist/dist_emaj/>`_,
2. **Extraire** l’arborescence du fichier zip reçu,
3. **Copier** dans le dossier *share* du dossier d’installation de la version de PostgreSQL (typiquement *c:\\Program_Files\\PostgreSQL\\<version_postgres>\\share*) :

   * le fichier ``dist_emaj.control`` dans ``\extension\``,
   * les fichiers ``sql\dist_emaj--*.sql`` dans un nouveau dossier ``\dist_emaj\``.

----

Une fois le logiciel installé sur le serveur, l'extension :doc:`dist_emaj peut être créée<setup>` dans les bases de données.
