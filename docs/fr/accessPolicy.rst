Mettre en place la politique d'accès à Distributed E-Maj
========================================================

Une mauvaise utilisation de Distributed E-Maj peut mettre en cause l'intégrité des bases de données. Aussi est-il recommendé de n'autoriser son usage qu'à des utilisateurs qualifiés et clairement identifiés comme tels.

Les rôles Distributed E-Maj
---------------------------

Pour utiliser Distributed E-Maj, on peut se connecter en tant que *SUPERUSER*. Mais pour des raisons de sécurité, il est préférable de tirer profit des deux rôles créés par la procédure d'installation :

* ``dist_emaj_adm`` : le rôle d'administration de Distributed E-Maj.

   * Il le propriétaire du schéma ``dist_emaj`` et de tout ce qu'il contient (à l'exception des fonctions).
   * Il peut exécuter toutes les fonctions de Distributed E-Maj.
* ``dist_emaj_viewer`` : le rôle pour des accès en lecture seule.

   * Il accède, en lecture uniquement, à toutes les tables du schéma *dist_emaj*, à l'exception de la colonne de la table *dist_emaj_database* qui contient les chaînes de connexion aux *databases*.

A leur création, ces deux rôles ne possèdent **pas de capacité de connexion** (option *NOLOGIN* et aucun mot de passe). Il est recommandé de NE PAS leur attribuer cette capacité de connexion. A la place, il suffit d'attribuer les droits qu'ils possèdent à d'autres rôles par des requêtes SQL de type *GRANT*.

----

Attribution des droits Distributed E-Maj
----------------------------------------

Pour attribuer à un rôle donné tous les droits associés à l'un des deux rôles *dist_emaj_adm* ou *dist_emaj_viewer*, et une fois connecté en tant que *SUPERUSER*, il suffit d'exécuter l'une des commandes suivantes ::

  GRANT dist_emaj_adm TO <mon.rôle.administrateur>;
  GRANT dist_emaj_viewer TO <mon.rôle.de.consultation;
