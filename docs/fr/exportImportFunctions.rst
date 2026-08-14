Exporter et importer la configuration Distributed E-Maj
=======================================================

Une configuration Distributed E-Maj comprend l’ensemble des :ref:`paramètres Distributed E-Maj<dist_emaj_param>` et la configuration des clusters.

Des fonctions permettent de les importer ou de les exporter sur un support externe, sous la forme de **structure JSON**. Elles peuvent être utiles notamment pour :

* déployer un jeu standardisé de configuration de paramètres et/ou clusters sur plusieurs bases de données ;
* changer de version Distrbuted E-Maj par désinstallation et réinstallation complète de l’extension.

Structures JSON
---------------

.. _clusters_json:

Structure JSON décrivant des clusters
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

La structure JSON décrivant des clusters se compose de deux attributs de type tableaux : ``servers`` décrit les serveurs hébergeant les groupes de tables, ``clusters`` décrit les clusters avec les groupes de tables qui lui sont rattachés. Elle ressemble à : ::

   {
      "servers": [
         {
            "server": "sss",
            "connect_string": "ccc",
            "rollback_parallel_sessions": n
         },
         {
         ...
         }
      ],
      "clusters": [
         {
            "cluster": "cccc",
            "groups": [
                {
                "server": "sss",
                "group": "ggg"
                },
                {
                ...
                }
            ],
         },
         ...
         }
      ]
   }

.. _parameters_json:

Structure JSON décrivant des paramètres
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

La structure JSON décrivant des paramètres est un attribut nommé ``parameters`` de type tableau, et contenant des sous-structures avec les attributs ``key`` et ``value`` : ::

   {
     "parameters": [
       {
          "key": "...",
          "value": "..."
       },
       {
          ...
       }
     ]
   }

Les paramètres non décrits dans la structure gardent leur valeur par défaut.

----

.. _export_clusters_conf:

Exporter une configuration de clusters
--------------------------------------

La fonction ``emaj_export_clusters_configuration()`` exporte une description d’un ou plusieurs clusters sous forme de structure *JSON*. Elle existe en deux variantes.

On peut écrire une configuration de groupes de clusters dans un **fichier plat** par : ::

   SELECT emaj_export_clusters_configuration(p_location, p_clusters);

Si le nom du **fichier de sortie est omis** ou est *NULL*, la fonction retourne directement la **structure JSON** contenant la configuration des clusters : ::

   SELECT emaj_export_clusters_configuration(p_clusters);

**Paramètres en entrée**

- ``p_location`` (*TEXT*, optionnel) : Emplacement du **fichier de sortie**.
- ``p_clusters`` (*TEXT[]*, optionnel) : Tableau des **clusters** à exporter. Si le paramètre est absent ou *NULL*, tous les clusters sont exportés.

**Données retournées**

Quand la fonction écrit dans un fichier, elle retourne le nombre de clusters exportés.

Sinon, elle retourne la structure *JSON* contenant la configuration des clusters.

**Notes**

Si le paramètre ``p_location`` est fourni, le chemin du fichier de sortie doit être accessible en écriture par l’instance PostgreSQL.

Si le paramètre ``p_clusters`` est valorisé, seuls les serveurs hébergeant les groupes de tables des clusters sélectionnés sont décrits dans la structure "servers".

La seconde variante permet de visualiser la structure ou de la stocker dans une colonne de table relationnelle. Par exemple : ::

   INSERT INTO ma_table (mes_clusters_json)
       VALUES ( emaj_export_clusters_configuration() );

La structure *JSON* exportée comprent les attributs :ref:`"servers" et "clusters"<clusters_json>` décrits ci-dessus, précédé d’un attribut ``_comment`` : ::

   {
   	   "_comment": "Generated on database <db> with Distributed E-Maj version <version> at <date_heure>, including ...",
   	   "servers": [
          ...
   	   ]
   	   "clusters": [
          ...
   	   ]
   }

----

.. _export_param_conf:

Exporter une configuration de paramètres Distributed E-Maj
----------------------------------------------------------

La fonction ``dist_emaj_export_parameters_configuration()`` exporte l’ensemble des paramètres de l'extension sous forme de structure *JSON*. Elle existe en deux variantes.

On peut écrire les données de paramétrage dans un **fichier plat** par : ::

   SELECT dist_emaj.dist_emaj_export_parameters_configuration(p_location, p_includeDefault);

Si le nom du **fichier de sortie est omis** ou est *NULL*, la fonction retourne directement la **structure JSON** contenant la valeur des paramètres : ::

   SELECT dist_emaj.dist_emaj_export_parameters_configuration(p_includeDefault);

**Paramètres en entrée**

- ``p_location`` (*TEXT*, optionnel) : Emplacement du **Fichier de sortie**.
- ``p_includeDefault`` (*BOOLEAN*, optionnel) :

   - **FALSE** (par défault) : Seuls les paramètres dont la valeur est différente de leur valeur par défaut sont exportés.
   - **TRUE** : Tous les paramètres sont exportés.

**Données retournées**

Quand la fonction écrit dans un fichier, elle retourne le nombre de paramètres exportés.

Sinon, elle retourne la structure *JSON* contenant la configuration des paramètres.

**Notes**

Si le paramètre ``p_location`` est fourni, le chemin du fichier de sortie doit être accessible en écriture par l’instance PostgreSQL.

La seconde variante permet de visualiser la structure ou de la stocker dans une colonne de table relationnelle. Par exemple : ::

   INSERT INTO ma_table (mes_parametres_json)
       VALUES ( dist_emaj.dist_emaj_export_parameters_configuration([<inclure.défaut?>]) );

La structure JSON exportée comprent l’attribut :ref:`"parameters"<parameters_json>` décrit ci-dessus, précédé de deux attributs ``_comment`` et ``_help`` : ::

   {
       "_comment": "Distrbuted E-Maj parameters, generated from the database <db> with Distributed E-Maj version <version> at <date_heure>",
           "_help": "Known parameter keys: <liste des clés connues>",
       "parameters": [
           ...
       ]
   }

----

.. _import_param_conf:

Importer une configuration de paramètres Distributed E-Maj
----------------------------------------------------------

La fonction ``dist_emaj_import_parameters_configuration()`` importe des :ref:`paramètres Distributed E-Maj<dist_emaj_param>` sous forme de structure *JSON*. Elle existe en deux variantes, qui diffèrent par leur premier paramètre.

On peut charger les paramètres depuis un **fichier plat** par : ::

   SELECT dist_emaj.dist_emaj_import_parameters_configuration(p_location, p_resetOtherParameters);

Une **description JSON** des paramètres peut être directement chargée par : ::

   SELECT dist_emaj.dist_emaj_import_parameters_configuration(p_paramsJson, p_resetOtherParameters);

**Paramètres en entrée**

- ``p_location`` (*TEXT*) : Emplacement du **Fichier** contenant la configuration des paramètres.
- ``p_paramsJson`` (*JSON*) : **Configuration JSON des paramètres**.
- ``p_resetOtherParameters`` (*BOOLEAN*, optionnel):

   - **FALSE** (par défaut) : Les paramètres absents de la configuration sont conservés en l'état (chargement en **mode différentiel**).
   - **TRUE** : Les paramètres absents de la configuration sont remis à leur valeur par défaut (chargement en **mode complet**).

**Données retournées**

La fonction retourne le nombre de paramètres importés.

**Notes**

Si le paramètres ``p_location`` est fourni (première variante) :

- le fichier doit être accessible en lecture par l’instance PostgreSQL,
- le fichier doit contenir une structure *JSON* ayant un attribut nommé :ref:`"parameters"<parameters_json>`, de type tableau, et contenant des sous-structures avec les attributs *"key"* et *"value"*,
- la fonction peut directement charger des fichiers générés par la fonction :ref:`dist_emaj_export_parameters_configuration()<export_param_conf>`.

Si le paramètres ``p_json`` est fourni (seconde variante) :

- il doit contenir une structure *JSON* ayant un attribut nommé :ref:`"parameters"<parameters_json>`, de type tableau, et contenant des sous-structures avec les attributs *"key"* et *"value"*,
- la structure peut provenir d’une colonne de table ralationnelle : ::

   SELECT dist_emaj.dist_emaj_import_parameters_configuration (mes_parametres_json, TRUE)
       FROM ma_table;

Si un paramètre n’a pas d’attribut *"value"* ou si cet attribut est valorisé à *NULL*, le paramètre est valorisé avec sa valeur par défaut.
