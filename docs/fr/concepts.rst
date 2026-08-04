Concepts
========

Les 3 principaux concepts d'E-Maj sont : le « *groupe de tables* », la « *marque* » et le « *rollback E-Maj* ».

*Distributed E-Maj* introduit 4 nouveaux concepts.

Serveur
-------

Un « **serveur E-Maj** » (*E-Maj server*) représente une **base de données PostgreSQL contenant une extension emaj** et hébergeant un ou plusieurs groupes de tables.

Il est identifié par un nom unique.

Cluster
-------

Un « **cluster de groupes E-Maj** » (*E-Maj groups cluster*) est un ensemble de **groupes de tables répartis dans plusieurs serveurs** E-Maj.

Le *cluster* est l’entité sur laquelle s’effectuent les opérations distribuées. Il est identifié par un nom unique.

Marque distribuée
-----------------

Une « **marque distribuée** » (*distributed mark*) représente un **point dans le temps commun à tous les groupes de tables d’un cluster**.

Elle est identifiée par un nom unique au sein du *cluster*.

Rollback E-Maj distribué
------------------------

Une opération de « **rollback distribué** » (*distributed E-Maj rollback*) consiste à **remettre toutes les tables et séquences** contenues dans tous les groupes de tables **du cluster à l'état d'une marque distribuée** posée précédemment.

Comme pour les *rollbacks E-Maj*, un *rolblack distribué* peut être **tracé** (*logged*) ou **non tracé** (*unlogged*).
