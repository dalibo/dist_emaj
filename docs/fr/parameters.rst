Gérer les paramètres de Distributed E-Maj
=========================================

.. _dist_emaj_param:

Les paramètres
--------------

L'extension dispose de **1 paramètre**, modifiable par les administrateurs Distributed E-Maj.

+----------------------+---------------------------------------------------------+-------------------+
| Clé                  | Signification                                           | Valeur par défaut |
+======================+=========================================================+===================+
| history_retention    | Durée de rétention des lignes dans *dist_emaj_hist*     | 1 an              |
+----------------------+---------------------------------------------------------+-------------------+

**Notes**

Le contenu du paramètre ``history_retention`` doit être interprétable comme une donnée *INTERVAL* ; une valeur >= 100 ans désactive la :ref:`purge des historiques<dist_emaj_purge_histories>`.

----

.. _dist_emaj_set_param:

Modifier les paramètres
-----------------------

La fonction ``dist_emaj_set_param()`` permet aux administrateurs de modifier une valeur de paramètre : ::

   SELECT dist_emaj.dist_emaj_set_param(p_key, p_value);

**Paramètres en entrée**

- ``p_key`` (*TEXT*) : **Clé** du paramètre.
- ``p_value`` (*TEXT*) : **Valeur** du paramètre. *NULL* remet le paramètre à sa valeur par défaut.

**Données retournées**

La fonction retourne le nombre de paramètres modifiés (0 ou 1).

**Notes**

Les **clés** sont **insensibles à la casse**.

Les valeurs de paramètres sont des chaînes de caractères. Pour les paramètres représentant un intervalle de temps, la chaîne doit être une représentation valide d’une donnée *INTERVAL* (ex : *'3 us'* ou *'3 micro-seconds'*).

Toute modification de paramètre est tracée dans la :ref:`table dist_emaj_hist<dist_emaj_hist>`.

----

Voir les paramètres
-------------------

La vue ``dist_emaj.dist_emaj_all_param`` permet aux administrateurs de voir tous les paramètres, avec leur valeur par défaut et leur valeur courante.

La structure de la vue *dist_emaj_all_param* est la suivante :

+---------------+------+-----------------------------------------------------------------------------+
| Colonne       | Type | Description                                                                 |
+===============+======+=============================================================================+
| param_key     | TEXT | Mot-clé identifiant le paramètre                                            |
+---------------+------+-----------------------------------------------------------------------------+
| param_value   | TEXT | Valeur courante du paramètre                                                |
+---------------+------+-----------------------------------------------------------------------------+
| param_default | TEXT | Valeur par défaut du paramètre                                              |
+---------------+------+-----------------------------------------------------------------------------+
| param_cast    | TEXT | Format de données de la valeur du paramètre (NULL pour du TEXT ou INTERVAL) |
+---------------+------+-----------------------------------------------------------------------------+
| param_rank    | INT  | Rang d’affichage du paramètre                                               |
+---------------+------+-----------------------------------------------------------------------------+
