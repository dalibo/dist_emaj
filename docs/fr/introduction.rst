Introduction
============

Licence
-------

Le logiciel "*Distributed E-Maj*" et toute la documentation qui l'accompagne sont distribués sous licence **GNU - General Public License** (GPL).

----

Objectifs de "Distributed E-Maj"
--------------------------------

La solution E-Maj permet d'enregistrer et d'éventuellement annuler les mises à jour effectuées sur des tables d'une base de données PostgreSQL, de manière fiable et efficace, avec une granularité correspondant à des ensembles cohérents de tables et séquences, appelés *groupes de tables*.

*Distributed E-Maj* (*E-Maj distribué*) est un complément d'E-Maj permettant de **gérer de manière consistante des groupes de tables répartis sur plusieurs bases de données**. Il permet de :

- démarrer et arrêter les groupes de tables,
- poser des marques sur les groupes de tables,
- remettre les groupes de tables à l’état d’une marque commune (*rollback E-Maj*).

Ainsi, en cas d'annulation de mises à jour (*rollback E-Maj*), *Distributed E-Maj* garantit la cohérence des groupes de tables réparties sur plusieurs bases de bases de données.

Ces bases de données peuvent être :

- reliées par de la réplication logique,
- reliées par des *Foreign Data Wrapper*,
- indépendantes.

----

Principaux composants
---------------------

**Distributed E-Maj** se compose de :

* une **extension** PostgreSQL, créée dans chaque base de données, nommée *dist_emaj* et contenant quelques tables, fonctions, etc,
* deux **clients externes** appelables en ligne de commande.
