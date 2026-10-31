Install the Distributed E-Maj Software
======================================

Download Sources
----------------

Distributed E-Maj is available for download from the following sources:

- **PGXN (PostgreSQL Extension Network)**: `https://pgxn.org/dist/dist_emaj/ <https://pgxn.org/dist/dist_emaj/>`_
- **GitHub repositories**: `https://github.com/dalibo/dist_emaj <https://github.com/dalibo/dist_emaj>`_

.. caution::
   Installing Distributed E-Maj directly from the **GitHub** repository will create the extension in its **development version** ("devel"), even if you download a tagged release. In this case, future updates via PostgreSQL's extension mechanism will not be possible. For stable use, it is **strongly recommended** to use the packages available from **PGXN**.

----

Standard Installation on Linux
------------------------------

With the pgxn Client
^^^^^^^^^^^^^^^^^^^^

If the *pgxn* client is installed, run the following command::

  pgxn install dist_emaj --sudo

Without the pgxn Client
^^^^^^^^^^^^^^^^^^^^^^^

1. Download the latest Distributed E-Maj version. For example, using *wget*::

     wget https://api.pgxn.org/dist/dist_emaj/<version>/dist_emaj-<version>.zip

2. Extract the archive and install the components::

     unzip dist_emaj-<version>.zip
     cd dist_emaj-<version>/
     sudo make install

Component Localization
^^^^^^^^^^^^^^^^^^^^^^

In both cases, Distributed E-Maj components are installed in the standard PostgreSQL directories:

- **SQL scripts**: ``<SHAREDIR>/dist_emaj/``
- **CLI clients**: ``<BINDIR>`` (alongside other PostgreSQL clients)
- **Documentation**: ``<DOCDIR>/dist_emaj/``

To locate the *SHAREDIR*, *BINDIR*, and *DOCDIR* directories, use the ``pg_config`` command.

----

Manual Installation on Linux
----------------------------

1. Download the latest Distributed E-Maj version from *pgxn.org*. For example, using *wget*::

     wget https://api.pgxn.org/dist/dist_emaj/<version>/dist_emaj-<version>.zip

2. Extract the archive::

     unzip dist_emaj-<version>.zip
     cd dist_emaj-<version>/

3. Edit the **dist_emaj.control** file to set the ``directory`` parameter to the absolute path of the Distributed E-Maj SQL scripts directory (e.g., */path/to/dist_emaj-<version>/sql*).

4. Locate the *SHAREDIR* directory. You can use the following command::

     pg_config --sharedir

   If this does not return the correct path, check typical locations such as: */usr/share/postgresql/<pg_version>/* (Debian/Ubuntu) or */usr/pgsql-<pg_version>/share/* (RedHat/CentOS)

5. Copy the modified *dist_emaj.control* file to the PostgreSQL extension directory. As a superuser or using *sudo*, run::

     cp dist_emaj.control <SHAREDIR>/extension/.

The latest Distributed E-Maj version is now installed and recognized by PostgreSQL. The ``dist_emaj-<version>`` directory contains the file structure :doc:`described here <content>`.

----

Installation on Windows
-----------------------

To install Distributed E-Maj on Windows:

1. **Download** the extension from the `PGXN website <https://pgxn.org/dist/dist_emaj/>`_.
2. **Extract** the contents of the downloaded ZIP file.
3. **Copy** the following files to the PostgreSQL installation directory (typically ``C:\Program Files\PostgreSQL\<postgres_version>\share\``):

   - The ``dist_emaj.control`` file to the ``\extension\`` subdirectory.
   - The SQL files (``sql\dist_emaj--*.sql``) to a new ``\dist_emaj\`` subdirectory.

----

Once the software is installed on the server, the *dist_emaj* :doc:`extension can be created<setup>` into databases.
