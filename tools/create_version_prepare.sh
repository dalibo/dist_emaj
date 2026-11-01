#! /bin/bash
# create_version_prepare.sh
# create_version is a tool that creates a new Distributed E-Maj version from the devel dist_emaj environment.
# This create_version_prepare.sh script is the first step of the operation.
# It adjusts files content and name to replace the <devel> version by the final version name.
# Then a commit and a tag can be set, before running the second script, create_version_complete.sh.
#
# Usage: (assuming the Distributed E-Maj project root directory is ~/proj/dist_emaj)
# 	cd ~/proj
# 	./dist_emaj/tools/create_version_prepare.sh <new_version> <version_date>
#     (where for instance : <new_version> = '1.0.0' and <version_date> = '2026-Nov-15')
#
# If the operation has to be reverted (before the git commit):
#   git reset HEAD
#   git checkout -f
#   rm sql/*<new_vers>*
#   rm *.bak sql/*.bak test/sql/*.bak client/*.bak
#
	echo "Starting create_version_prepare.sh..."

# Checks
# ------

# Get and verify parameters
	if [ $# -ne 2 ]
	then
		echo "Expected syntax is: dist_emaj/tools/create_version_prepare.sh <new version> <version_date>"
		echo "For instance: sh dist_emaj/tools/create_version_prepare.sh '1.0.0' '2026-Nov-15'"
		exit 1
	fi
	NEW=$1
	DATE=$2

# Build directory names
	MAINDIR="dist_emaj"
	NEWDIR="dist_emaj-"$NEW

# Verify that the current emaj version is devel
	if [ ! -f $MAINDIR/sql/dist_emaj--devel.sql ]
	then
		echo "Can't find $MAINDIR/sql/dist_emaj--devel.sql."
		echo "The environement is probably not in <devel> state."
		exit 1
	fi

# Verify that the new version directory doesn't already exist
	if [ -d $NEWDIR ]
	then
		echo "A $NEWDIR directory already exists !"
		echo "Remove it with rm -Rf $NEWDIR before reruning this script."
		exit 1
	fi

# Automatic dist_emaj changes
# ---------------------------
	cd $MAINDIR

# Delete potential remaining temp files and tar files
	find -name "*~" -type f -exec rm '{}' \;
	rm -f *.tar*

# Stamp the CHANGES.md file
	sed -i "s/^devel$/\n${NEW} (${DATE})/" CHANGES.md

# Adapt and rename the migration script
	sed -i "s/<devel>/${NEW}/g" sql/dist_emaj--*--devel.sql
	for file in sql/dist_emaj--*-devel.sql; do
		git mv $file $(echo $file | sed -r "s/devel/${NEW}/")
	done

# Process sql directory: change version identifiers and rename scripts in development version
	find sql/*devel.sql -type f -exec sed -i.bak "s/<devel>/${NEW}/g" '{}' \;
	git mv sql/dist_emaj--devel.sql sql/dist_emaj--${NEW}.sql
#	git mv sql/dist_emaj-devel.sql sql/dist_emaj-${NEW}.sql

# Change version identifiers inside files from /client
	find client/dist_emaj.pl client/distEmajRollback.pl -type f -exec sed -i.bak "s/<devel>/${NEW}/g" '{}' \;

# Change version identifiers inside README.md
	sed -i.bak "s/<devel>/${NEW}/g" README.md

# Change version identifiers inside META.json
	sed -i.bak -e "s/\"devel\"/\"${NEW}\"/" -e "s/dist_emaj--devel.sql/dist_emaj--${NEW}.sql/" -e "s/Emaj.devel_doc/Emaj.${NEW}_doc/" META.json

# Change version identifiers inside dist_emaj.control
	sed -i.bak "s/devel/${NEW}/g" dist_emaj.control

# Change version identifiers inside tar.index
	sed -i.bak -e "s/^dist_emaj/dist_emaj-${NEW}/" -e "s/devel/${NEW}/g" tar.index

# Change version identifiers inside files from /test/sql
	sed -i.bak "s/'devel'/'${NEW}'/g" test/sql/install.sql
#	sed -i.bak "s/'devel'/'${NEW}'/g" test/sql/install_upgrade.sql
#	sed -i.bak "s/'devel'/'${NEW}'/g" test/sql/install_oldest.sql
#	sed -i.bak "s/'devel'/'${NEW}'/g" test/sql/upgrade_while_logging.sql
#	sed -i.bak "s/emaj-devel.sql/emaj-${NEW}.sql/" test/sql/install_psql.sql
#	sed -i.bak "s/emaj-devel.sql/emaj-${NEW}.sql/" test/sql/non_superuser_install.sql

	cd ..

# End of processing
# -----------------
	echo "The $MAINDIR directory has now files with a version tagged $NEW."
	echo "Check it and then execute:"
	echo "  git commit -am 'Setup the new $NEW version.'"
	echo "  git tag -a v$NEW -m 'Version $NEW.'"
	echo "before running the create_version_complete.sh script."
