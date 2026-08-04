README.md
=========

License
-------

This software is distributed under the GNU General Public License.

Objectives
----------

**Distributed Emaj** is an extension of the E-Maj solution. (available on https://github.com/dalibo/emaj).

The main goals of E-Maj are:
* log changes performed on one or several sets of tables.
* cancel these updates if needed, and reset a tables set to a predefined stable state.

"Distributed E-Maj" adds distributed features to E-Maj. concretely, it allows to perform **distributed E-Maj rollbacks** on tables spread on distributed databases in a **consistent mannner**.

Distribution
------------

Distributed E-Maj is available via the PGXN platform (https://pgxn.org/dist/dist_emaj/). The main repository is available on GitHub (https://github.com/dalibo/dist_emaj).

Documentation
-------------

A detailed documentation can be found here, in [English](https://dist_emaj.readthedocs.io/en/latest/) and in [French](https://dist_emaj.readthedocs.io/fr/latest/).

How to install and use E-Maj
----------------------------

Distributed E-Maj can be installed using the usual method for postgres extensions (ie. CREATE EXTENSION dist_emaj CASCADE;).

The documentation contains all the [detailled information](https://dist_emaj.readthedocs.io/en/latest/install.html) needed to install and use Distributed E-Maj.

Support
-------

For additional support or bug report, please create an issue on the github repository or contact Philippe Beaudoin (phb <dot> emaj <at> free <dot> fr).

Any feedback is welcome, even to just notice you use E-Maj, Emaj_web or Distributed E-Maj ;-)
