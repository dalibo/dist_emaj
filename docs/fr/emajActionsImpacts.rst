Impacts des actions E-Maj locales
=================================

Sur une *database* E-Maj, aucune information n'indique si un groupe de tables est assigné à un quelconque *cluster* Distributed E-Maj. Si un groupe de tables est assigné à un *cluster*, il est donc de la **responsabilité de l'administrateur** E-Maj de ne pas réaliser d'actions sur le groupe de tables pouvant empêcher ensuite la réalisation d'actions au niveau du *cluster*.

Les conséquences potentielles d'actions E-Maj locales sur un *cluster* sont décrites ci-dessous.

Arrêt d'un groupe de tables
---------------------------

Un groupe de tables peut être arrêté localement en exécutant une fonction *emaj_stop_group()* ou *emaj_stop_groups()*.

Si le groupe de tables arrêté est assigné à un *cluster* :

- le *cluster* pourra être arrêté, en spécifiant l'option ``--idle-groups-allowed`` dans la commande ``distEmaj.pl``,
- mais, le groupe de table arrêté ne pouvant plus être "rollbacké", aucun *rollback distribué* ne sera possible sur le *cluster*,
- la synchronisation des marques suivante supprimera toutes les *marques distribuées* du *cluster*.

----

Pose d'une marque
-----------------

Avec les fonctions *emaj_set_mark_group()* et *emaj_set_mark_groups()*, il est possible de poser localement une marque pour un groupe de tables.

Cette marque n'étant pas commune à tous les groupes de tables du *cluster*, un *rollback distribué* ciblant ce nom de marque ne sera pas possible, même si une marque de même nom est aussi posée localement sur les autres groupes de tables du *cluster*.

----

Suppression d'une marque
------------------------

Les fonctions *emaj_delete_mark_group()* et *emaj_delete_before_mark_group()* supprime localement une ou plusieurs marques pour un groupe de tables.

Si l'une de ces marques correspond à une *marque distribuée* de *cluster* : 

- la synchronisation suivante des marques pour le *cluster* supprimera la marque distribuée,
- en conséquence, un *rollback distribué* ciblant cette marque devient impossible sur le *cluster*.
- en revanche, la marque existera toujours pour les autres groupes de tables, autorisant un rollback local de ces groupes de tables.

----

Renommage d'une marque
----------------------

La fonction *emaj_rename_mark_group()* renomme localement une marque d'un groupe de tables.

Si cette marque correspond à une *marque distribuée* de *cluster* :

- le renommage de la marque ne change pas le nom de la *marque distribuée* associée,
- un *rollback distribué* ciblant cette *marque distribuée* reste possible :

   - si le groupe de tables est le seul de la *database* assigné au *cluster*,
   - ou si le même renommage est effectué pour **tous les groupes de tables de la database**.

----

Protection du groupe ou d'une marque
------------------------------------

Les fonctions *emaj_protect_group()* et *emaj_protect_mark_group()* permettent de protéger localement un groupe de tables ou une marque contre un rollback intempestif.

Si le groupe de tables concerné est assigné à un *cluster*, cette protection s'applique naturellement aux *rollback distribués* sur le *cluster*.
