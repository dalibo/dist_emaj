Mettre en place la politique d'accès à Distributed E-Maj
========================================================

Une mauvaise utilisation de Distributed E-Maj peut mettre en cause l'intégrité des bases de données. Aussi est-il recommendé de n'autoriser son usage qu'à des utilisateurs qualifiés et clairement identifiés comme tels.

Les rôles Distributed E-Maj
---------------------------

Pour utiliser Distributed E-Maj, on peut se connecter en tant que *SUPERUSER*. Mais pour des raisons de sécurité, il est préférable de tirer profit des deux rôles créés par la procédure d'installation :

* ``dist_emaj_adm`` : le rôle d'administration de Distributed E-Maj:

   * il peut exécuter toutes les fonctions  et accéder à toutes les tables du schéma *dist_emaj*, en lecture comme en mise à jour,
* ``dist_emaj_viewer`` : le rôle pour des accès en lecture seule:

   * il accède, en lecture uniquement, à toutes les tables du schéma *dist_emaj*, à l'exception de la colonne de la table *dist_emaj_database* qui contient les chaînes de connexion aux *databases*.

Tous les droits attribués à *dist_emaj_viewer* le sont aussi à *dist_emaj_adm*.

Lors de leur création, ces deux rôles ne se sont pas vus attribuer de capacité de connexion (aucun mot de passe et option *NOLOGIN* spécifiés). Il est recommandé de NE PAS leur attribuer cette capacité de connexion. A la place, il suffit d'attribuer les droits qu'ils possèdent à d'autres rôles par des requêtes SQL de type *GRANT*.

----

Attribution des droits Distributed E-Maj
----------------------------------------

Pour attribuer à un rôle donné tous les droits associés à l'un des deux rôles *dist_emaj_adm* ou *dist_emaj_viewer*, et une fois connecté en tant que *SUPERUSER*, il suffit d'exécuter l'une des commandes suivantes ::

  GRANT dist_emaj_adm TO <mon.rôle.administrateur>;
  GRANT dist_emaj_viewer TO <mon.rôle.de.consultation;
