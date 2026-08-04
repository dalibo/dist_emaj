Désinstaller Distributed E-Maj
==============================

Supprimer Distributed E-Maj d'une base de données
-------------------------------------------------

Pour supprimer Distributed E-Maj d'une base de données, l'utilisateur doit se connecter à cette base avec *psql*, en tant que **super-utilisateur**.

Si on souhaite **supprimer les rôles** *dist_emaj_adm* et *dist_emaj_viewer*, il faut au préalable retirer les droits donnés sur ces rôles à d'éventuels autres rôles, à l'aide de requêtes SQL *REVOKE*. ::

   REVOKE dist_emaj_adm FROM <role.ou.liste.de.rôles>;
   REVOKE dist_emaj_viewer FROM <role.ou.liste.de.rôles>;

.. _dist_emaj_drop_extension:

Si ces rôles *dist_emaj_adm* et *dist_emaj_viewer* possèdent des droits d'accès sur des tables ou autres objets relationnels applicatifs, il faut également supprimer ces droits **au préalable** à l'aide d'autres requêtes SQL *REVOKE*.

Bien qu'installée en standard avec une requête ``CREATE EXTENSION``, l’extension *dist_emaj* ne peut **pas** être supprimée par une simple requête ``DROP EXTENSION``. Un trigger sur événement bloque d'ailleurs l'exécution d'une telle requête.

Pour supprimer l'extension *dist_emaj*, il faut appeler la fonction **dist_emaj_drop_extension()** avec : ::

   SELECT dist_emaj.dist_emaj_drop_extension();

Cette fonction effectue les actions suivantes :

- elle supprime le trigger sur événement qui protège l'extension *dist_emaj*,
- elle supprime l'extension et le schéma principal *dist_emaj*,
- elle supprime les rôles *dist_emaj_adm* et *dist_emaj_viewer* s'ils ne sont pas associés à d'autres rôles ou à d'autres bases de données de l'instance et ne possèdent pas de droits sur d'autres tables.

----

Désinstaller le logiciel Distributed E-Maj
------------------------------------------

Le mode de désinstallation du logiciel E-Maj dépend de son mode d’installation.

- **Installation standard avec le client pgxn**

  Une seule commande est requise : ::

    pgxn uninstall E-Maj --sudo

- **Installation standard sans le client pgxn**

  Se placer dans le répertoire initial de la distribution Distributed E-Maj et taper ::

    sudo make uninstall
