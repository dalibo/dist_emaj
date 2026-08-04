Installer Distributed E-Maj dans une base de données
====================================================

Distributed E-Maj s'installe dans une base de données comme une *EXTENSION* (au sens de PostgreSQL). Pour ce faire, l’utilisateur doit disposer des droits **SUPERUSER**.

Création de l’extension dist_emaj
---------------------------------

Pour créer l'extension *dist_emaj* dans la base de données, exécuter la requête SQL : ::

   CREATE EXTENSION dist_emaj CASCADE;

Après avoir vérifié que la version de PostgreSQL est compatible avec cette version de Distributed E-Maj, le script d'installation crée le schéma *dist_emaj* avec ses tables techniques, ses fonctions et quelques autres objets.

.. caution::

   Le schéma **dist_emaj** ne doit contenir **que des objets liés à Distributed E-Maj**.

L'extension *dblink* est créée, si elle ne l'est pas déjà.

S'ils n'existent pas déjà, les 2 rôles *dist_emaj_adm* et *dist_emaj_viewer* sont également créés.

----

Paramétrage de Distributed E-Maj
--------------------------------

Un :ref:`paramètre<dist_emaj_param>` influence le fonctionnement de Distributed E-Maj.

Cette étape de valorisation du paramètre est **optionnelle**. Sa valeur par défaut permet de fonctionner correctement.
