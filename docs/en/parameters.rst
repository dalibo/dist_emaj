Managing Distributed E-Maj Parameters
=====================================

.. _dist_emaj_param:

Parameters
----------

The extension has **1 parameter** that can be modified by Distributed E-Maj administrators.

+----------------------+---------------------------------------------------------+-------------------+
| Key                  | Meaning                                                 | Default Value     |
+======================+=========================================================+===================+
| history_retention    | Retention period for rows in *dist_emaj_hist*           | 1 year            |
+----------------------+---------------------------------------------------------+-------------------+

**Notes**

The content of the ``history_retention`` parameter must be interpretable as an *INTERVAL* data type. A value >= 100 years disables the :ref:`history purge<dist_emaj_purge_histories>`.

----

.. _dist_emaj_set_param:

Modifying Parameters
--------------------

The ``dist_emaj_set_param()`` function allows administrators to modify a parameter value::

   SELECT dist_emaj.dist_emaj_set_param(p_key, p_value);

**Input Parameters**

- ``p_key`` (*TEXT*): **Key** of the parameter.
- ``p_value`` (*TEXT*): **Value** of the parameter. *NULL* resets the parameter to its default value.

**Returned Data**

The function returns the number of parameters modified (0 or 1).

**Notes**

**Keys** are **case-insensitive**.

Parameter values are character strings. For parameters representing a time interval, the string must be a valid representation of an *INTERVAL* data type (e.g., *'30 days'*).

Any parameter modification is logged in the :ref:`dist_emaj_hist table<dist_emaj_hist>`.

----

Viewing Parameters
------------------

The ``dist_emaj.dist_emaj_all_param`` view allows administrators to see all parameters, along with their default and current values.

The structure of the *dist_emaj_all_param* view is as follows:

+---------------+------+--------------------------------------------------------------------------------+
| Column        | Type | Description                                                                    |
+===============+======+================================================================================+
| param_key     | TEXT | Keyword identifying the parameter                                              |
+---------------+------+--------------------------------------------------------------------------------+
| param_value   | TEXT | Current value of the parameter                                                 |
+---------------+------+--------------------------------------------------------------------------------+
| param_default | TEXT | Default value of the parameter                                                 |
+---------------+------+--------------------------------------------------------------------------------+
| param_cast    | TEXT | Data format of the parameter value (NULL for TEXT or INTERVAL)                 |
+---------------+------+--------------------------------------------------------------------------------+
| param_rank    | INT  | Display rank of the parameter                                                  |
+---------------+------+--------------------------------------------------------------------------------+
