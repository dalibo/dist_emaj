Exporting and Importing the Distributed E-Maj Configuration
===========================================================

A Distributed E-Maj configuration includes the set of :ref:`Distributed E-Maj parameters <dist_emaj_param>` and the clusters configuration.

Several functions allow importing or exporting these configurations to or from an external source as a **JSON structure**. These functions are particularly useful for:

* Deploying a standardized clusters and parameter configuration set across multiple databases;
* Upgrading the *dist_emaj* extension with a full uninstall and reinstall.

JSON Structures
---------------

.. _clusters_json:

JSON Structure for Clusters
^^^^^^^^^^^^^^^^^^^^^^^^^^^

The JSON structure describing clusters is a set of two attributes of type array: ``databases`` describes the databases holding the tables groups, ``clusters`` describes the clusters with the table groups they own. It has the following format::

   {
      "databases": [
         {
            "database": "ddd",
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
                "database": "ddd",
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

JSON Structure for Parameters
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The JSON structure describing parameters is an array named ``parameters``, containing substructures with ``key`` and ``value`` attributes. ::

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

Parameters not described in the structure retain their default values.

----

.. _export_clusters_conf:

Exporting a Clusters Configuration
----------------------------------

The ``emaj_export_clusters_configuration()`` function exports the description of one or more clusters as a *JSON* structure. 2 variants exist.

A clusters configuration can be written to **a flat file** with::

   SELECT emaj_export_clusters_configuration(p_location, p_clusters);

If the **file path is omitted** or set to *NULL*, the function directly returns the **JSON structure** containing the configuration::

   SELECT emaj_export_clusters_configuration(p_clusters);

**Input Parameters**

- ``p_location`` (*TEXT*, optional): **Output file** location.
- ``p_clusters`` (*TEXT[]*, optional): Array of **clusters** to export. If omitted or set to *NULL*, the configuration of **all** clusters is exported.

**Returned data**

When the function writes the configuration into a flat file, it returns the number of exported clusters.

Otherwise, it returns the *JSON* structure containing the clusters configuration.

**Notes**

If present, the file path must be writable by the PostgreSQL instance.

If the ``p_clusters`` parameter is set, the "databases" structure only contains the databases holding table groups owned by the selected clusters.

The second variant allows visualization or storage in a relational table. For example::

   INSERT INTO my_table (my_clusters_json)
       VALUES (emaj_export_clusters_configuration());

The generated *JSON* structure contains the :ref:`"databases" and "clusters"<clusters_json>` attributes described above, preceded by a ``_comment`` attribute. ::

   {
   	   "_comment": "Generated on database <db> with Distributed E-Maj version <version> at <date_heure>, including ...",
   	   "databases": [
          ...
   	   ]
   	   "clusters": [
          ...
   	   ]
   }

----

.. _export_param_conf:

Exporting a Distributed E-Maj Parameters Configuration
------------------------------------------------------

The ``dist_emaj_export_parameters_configuration()`` function exports :ref:`Distributed E-Maj parameters <dist_emaj_param>` as a JSON structure. It has also 2 variants.

The parameters data can be written to a **flat file** with::

   SELECT dist_emaj.dist_emaj_export_parameters_configuration(p_location, p_includeDefault);

If the **file path** is **omitted** or set to *NULL*, the function directly returns the **JSON structure** containing the parameter values::

   SELECT dist_emaj.dist_emaj_export_parameters_configuration(p_includeDefault);

**Input Parameters**

- ``p_location`` (*TEXT*, optional): **Output file** location.
- ``p_includeDefault`` (*BOOLEAN*, optional):

   - **FALSE**, default: Only parameters with values different from their defaults are exported.
   - **TRUE**: All parameters are exported.

**Returned data**

When the function writes the configuration into a flat file, it returns the number of exported parameters.

Otherwise, it returns the JSON structure containing the parameters configuration.

**Notes**

If present, the file path must be writable by the PostgreSQL instance.

The second variant allows visualization or storage in a relational table. For example::

   INSERT INTO my_table (my_parameters_json)
       VALUES (dist_emaj.dist_emaj_export_parameters_configuration(TRUE));

The generated JSON structure contains the :ref:`"parameters" <parameters_json>` attribute described above, preceded by ``_comment`` and ``_help`` attributes. ::

   {
       "_comment": "Distributed E-Maj parameters, generated from the database <db> with E-Maj version <version> at <date_time>",
       "_help": "Known parameter keys: <list of known keys>",
       "parameters": [
           ...
       ]
   }

----

.. _import_param_conf:

Importing a Distributed E-Maj Parameters Configuration
------------------------------------------------------

The ``dist_emaj_import_parameters_configuration()`` function imports :ref:`Distributed E-Maj parameters <dist_emaj_param>` from a *JSON* structure.  It has 2 variants that just differ in its first parameter.

A **file** containing parameters to load can be read with::

   SELECT dist_emaj.dist_emaj_import_parameters_configuration(p_location, p_resetOtherParameters);

A **JSON description** of the parameters configuration can be directly loaded with::

   SELECT dist_emaj.dist_emaj_import_parameters_configuration(p_paramsJson, p_resetOtherParameters);

**Input Parameters**

- ``p_location`` (*TEXT*): **Input file** location containing the JSON parameters configuration.
- ``p_json`` (*JSON*): **JSON parameters configuration**.
- ``p_resetOtherParameters`` (*BOOLEAN*, optional):

   - **FALSE**, default: Parameters not present in the loaded configuration remain unchanged (**differential mode** load).
   - **TRUE**: Parameters not present in the loaded configuration are reset to their default value (**full mode** load).

**Returned data**

The function returns the number of imported parameters.

**Notes**

If the ``p_location`` parameter is set (first variant):

- The file path must be readable by the PostgreSQL instance.
- The file must contain a JSON structure with an attribute named :ref:`"parameters" <parameters_json>`, an array containing substructures with **"key"** and **"value"** attributes.
- The function can directly load a file generated by the :ref:`dist_emaj_export_parameters_configuration() <export_param_conf>` function.

If the ``p_json`` parameter is set (second variant):

- It must contain a JSON structure with an attribute named :ref:`"parameters" <parameters_json>`, an array containing substructures with **"key"** and **"value"** attributes.
- This structure can be read from a relational table::

   SELECT dist_emaj.dist_emaj_import_parameters_configuration(my_parameters_json, TRUE)
       FROM my_table;

If a parameter to import has no **"value"** attribute or if this attribute is set to *NULL*, the parameter is reset to its default value.
