#! /usr/bin/perl -w
#
# distEmajRollback.pl
# This perl module belongs to the Distributed E-Maj extension.
#
# This software is distributed under the GNU General Public License.
#
# It performs distributed parallel rollback on tables groups located on several postgres databases in a consistent way.
# The processed tables groups are members of a predefined "groups cluster".
# The target mark is a distributed mark set by distEmaj.pl
# The number of sessions used on each database is defined at the distributed emaj cluster level

use warnings;
use strict;

use Getopt::Long;

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types :async);
use POSIX qw(strftime);
use Data::Dumper;

STDOUT->autoflush(1);

use vars qw($VERSION $PROGRAM $APPNAME);

$VERSION = '<devel>';
$PROGRAM = 'distEmajRollback.pl';
$APPNAME = 'distEmajRollback';

# Variables for dist_emaj database access.
my $dbh;
my $dbh2;
my $sth;
my $sthTrace;
my $sthUpdateStatus;
my $sthRecordRlbkId;
my $connectionString = "application_name=$APPNAME;";

# Structure counters.
my $nbdatabase = 0;
my $nbSession = 0;
my $nbGroup = 0;

# Hash and array structures.

my $databasesArray;                       # Reference to the array representing databases read from the dist_emaj configuration

# Variables for E-Maj foreign databases accesses.
my @dbh = undef;
my @sth = undef;

#
# Global variables.
#
# Initialize parameters with their default values.
my $dbname = undef;						# -d PostgreSQL database name hosting the dist_emaj extension
my $host = undef;						# -h PostgreSQL database host name
my $port = undef;						# -p PostgreSQL database ip port
my $username = undef;					# -U user name for the connection to PostgreSQL database
my $password = undef;					# -W user password
my $askHelp = 0;						# --help option
my $askVersion = 0;						# --version option
my $action = undef;						# --action action (mandatory)
my $cluster = undef;					# --cluster groups cluster (mandatory)
my $targetMark = undef;					# --mark E-maj target mark name
my $comment = undef;					# --comment comment given to the rollback operation (optional, unlogged rollback by default)
my $isLogged = 0;						# --is_logged : flag for logged rollback mode (optional)
my $isAlterGroupAllowed = 0;			# --is_alter_group_allowed : flag to allow the rollback to reach a mark set before alter group operations (optional)
my $regressTest = 0;					# --regression-test flag (to only display stable data when testing)
my $verbose = 0;						# --verbose flag for verbose mode

# Other global variables.
my $sql;
my $targetMarkTimeId;
my $globalTimeId;
my $globalEndTimeId;
my $distRlbkId;
my $msgRlbk;

###############################################################################
# Initialization phase.
###############################################################################

# Print the header.
print (" Distributed E-Maj Rollback (version $VERSION)\n");
print ("--------------------------------------------\n");

# Collect and prepare options.

# Get supplied options.
GetOptions(
# connection parameters
	"d=s" => sub { $dbname = $_[1]; $connectionString .= "dbname=$dbname;"; },
	"h=s" => sub { $host = $_[1]; $connectionString .= "host=$host;"; },
	"p=i" => sub { $port = $_[1]; $connectionString .= "port=$port;"; },
	"U=s" => \$username,
	"W=s" => \$password,
# other options
	"alter-groups-allowed|aga" => \$isAlterGroupAllowed,
	"cluster:s" => \$cluster,
	"comment:s" => \$comment,
	"help|?" => \$askHelp,
	"logged" => \$isLogged,
	"mark:s" => \$targetMark,
	"regression-test|rt" => \$regressTest,
	"verbose"   => \$verbose,
	"version" => \$askVersion,
	)
	or printHelp();

# Just asking for help.
if ($askHelp) {
	printHelp();
}

# Just asking for version.
if ($askVersion) {
	printVersion();
}

traceIfVerbose("Initialisation...");

# Check options.

# Check the cluster name has been set.
if (!defined $cluster) {
	traceDie("Error: A cluster name must be supplied with the --cluster option !\n");
}

# Check the mark has been supplied.
if (!defined $targetMark) {
	traceDie("Error: A rollback target mark must be supplied with the --mark option !\n");
}

# Open 2 connections on the dist_emaj database.
# The first handles most dist_emaj accesses.
# The second will be used at the end of the rollback operation to insert or delete distributed marks in the same distributed
#   transaction as emaj databases accesses.
# Connection parameters are optional. If not supplied, the environment variables and PostgreSQL default values are used.
$dbh = DBI->connect('dbi:Pg:' . $connectionString, $username, $password, {AutoCommit => 1, RaiseError => 0, PrintError => 0})
	or traceDie("Error at first dist_emaj database connection.\n$DBI::errstr\n\n");
$dbh2 = DBI->connect('dbi:Pg:' . $connectionString, $username, $password, {AutoCommit => 1, RaiseError => 0, PrintError => 0})
	or traceDie("Error at second dist_emaj database connection.\n$DBI::errstr\n\n");

# Check that the dist_emaj extension exists in the database.
$sql = qq(
	SELECT 1
		FROM pg_catalog.pg_extension
		WHERE extname = 'dist_emaj'
	);
$dbh->selectrow_array($sql)
	or traceDie("Error: the dist_emaj extension does not exist in the " . $dbh->{pg_db} . " database.\n");

# Check that the user has the proper privileges, by verifying he is allowed to write into the dist_emaj_hist table.
$sql = qq(
	SELECT CASE WHEN pg_catalog.has_schema_privilege('dist_emaj', 'USAGE')
					AND pg_catalog.has_table_privilege('dist_emaj.dist_emaj_hist', 'INSERT')
					THEN 1 ELSE 0 END AS has_privileges
	);
my ($hasPrivileges) = $dbh->selectrow_array($sql)
	or traceDie("Error while checking the user privileges on dist_emaj.\n$DBI::errstr\n\n");
if (!$hasPrivileges) {
	traceDie("Error: the user is not allowed to access the dist_emaj database.\n");
}

# Check the supplied cluster.
$sql = qq(
	SELECT dist_emaj.dist_emaj_verify_cluster(?, TRUE)
	);
$dbh->do($sql, undef, $cluster)
	or traceDie("Error while checking the cluster.\n$DBI::errstr\n\n");

# Check the supplied distributed mark name.
$sql = qq(
	SELECT dist_emaj._check_dist_mark( ?, ? )
	);
($targetMarkTimeId) = $dbh->selectrow_array($sql, undef, $cluster, $targetMark)
	or traceDie("Error while checking the distributed rollback target mark name.\n$DBI::errstr\n\n");
traceIfVerbose("Cluster and distributed rollback target mark checked.");

# The conditions to start the operation are met.
# Prepare 3 statements that will be executed several times on dist_emaj tables.
$sql = qq(
    INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
		VALUES (?, ?, ?, ?)
    );
$sthTrace = $dbh->prepare($sql)
	or traceDie("Error while preparing the INSERT into dist_emaj_hist statement.\n$DBI::errstr\n\n");

# Update the distributed rollback status in dist_emaj_rlbk.
$sql = qq(
	UPDATE dist_emaj.dist_emaj_rlbk
		SET rlbk_status = ?
		WHERE rlbk_id = ?
	);
$sthUpdateStatus = $dbh->prepare($sql)
	or traceDie("Error while preparing the UPDATE dist_emaj_rlbk statement.\n$DBI::errstr\n\n");

$sql = qq(
    INSERT INTO dist_emaj.dist_emaj_rlbk_database (rlbd_rlbk_id, rlbd_database, rlbd_local_rlbk_id)
		VALUES (?, ?, ?)
    );
$sthRecordRlbkId = $dbh->prepare($sql)
	or traceDie("Error while preparing the INSERT INTO dist_emaj_rlbk_database statement.\n$DBI::errstr\n\n");

# Trace the operation start.
$msgRlbk = $isLogged ? 'Logged rollback' : 'Rollback';
$sthTrace->execute('ROLLBACK_GROUPS', 'BEGIN', $cluster, "$msgRlbk to mark $targetMark")
	or traceDie("Error while inserting the operation start trace into dist_emaj_hist.\n$DBI::errstr\n\n");

# Get data about each database of the cluster.
$sql = qq(
    SELECT db_name AS name, db_connect_string AS connect_string, db_rlbk_parallel_session AS nb_session,
           db_groups_array AS groups_array, db_groups_list AS groups_list, db_nb_group AS nb_group,
           mkdb_local_time_id AS mark_local_time_id
		FROM dist_emaj.dist_emaj_database_aggregates
          JOIN dist_emaj.dist_emaj_mark_database ON (mkdb_time_id = ? AND mkdb_database = db_name)
		WHERE clst_name = ?
		ORDER BY db_name;
	);

$databasesArray = $dbh->selectall_arrayref($sql, { Slice => {} }, $targetMarkTimeId, $cluster)
	or traceDie("Error while reading the cluster configuration from dist_emaj.\n$DBI::errstr\n\n");

# Build the sessions structure.
foreach my $db (@$databasesArray) {
	$nbdatabase++;
	$nbGroup += $db->{nb_group};
	$db->{first_session} = $nbSession + 1;
	$db->{last_session} = $nbSession + $db->{nb_session};
	$nbSession += $db->{nb_session};
}

# Open the necessary sessions for each database.
# The initial cluster check has already verified for each database that:
#   - emaj exists in the database, with a proper version,
#   - the user has adminstration capabilities,
#   - and the PG instance is configured to allow distributed operations,
#   - all tables groups assigned to the cluster exist.
foreach my $db (@$databasesArray) {

# Open all sessions for the database.
	for (my $i = $db->{first_session} ; $i <= $db->{last_session}; $i++) {
		traceIfVerbose("database $db->{name}: open session #$i...");

		$dbh[$i] = DBI->connect('dbi:Pg:'.$db->{connect_string}, '', '', {AutoCommit => 1, RaiseError => 0, PrintError => 0})
			or traceDie("Opening the session #$i (on database $db->{name}) failed.\n$DBI::errstr\n\n");
	}
}

# Get a global time stamp on dist_emaj.
$sql = qq(
	SELECT dist_emaj._set_time_stamp(?, 'R')
	);
($globalTimeId) = $dbh->selectrow_array($sql, undef, 'ROLLBACK_GROUPS')
	or traceDie("Error while setting the global time _id.\n$DBI::errstr\n\n");

# Insert the distributed rollback into dist_emaj_rlbk and get the distributed rollback identifier.
$sql = qq(
	INSERT INTO dist_emaj.dist_emaj_rlbk(rlbk_cluster, rlbk_mark, rlbk_mark_time_id, rlbk_time_id,
										 rlbk_is_logged, rlbk_is_alter_group_allowed, rlbk_comment, rlbk_status)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		RETURNING rlbk_id AS dist_rlbk_id
	);
($distRlbkId) = $dbh->selectrow_array($sql, undef, $cluster, $targetMark, $targetMarkTimeId, $globalTimeId,
									$isLogged ? 'TRUE' : 'FALSE', $isAlterGroupAllowed ? 'TRUE' : 'FALSE', $comment, 'PLANNING')
	or traceDie("Error while inserting into dist_emaj_dlbk.\n$DBI::errstr\n\n");

traceIfVerbose("Distributed rollback id = $distRlbkId ; Global time id = $globalTimeId ; Rollback target mark time id = $targetMarkTimeId.");

# For each session, start a transaction.
for (my $i = 1 ; $i <= $nbSession; $i++) {
	traceIfVerbose("Start transaction on session #$i...");
	$dbh[$i]->begin_work()
		or traceDie("Begin transaction #$i failed.\n$DBI::errstr\n\n");
}

###############################################################################
# Rollback phase 1. (init)
###############################################################################

# For each database, get and check the real mark name the rollback has to reach and call the initialization function on the first corridor.
foreach my $db (@$databasesArray) {

# Check the mark name on the emaj database.
	$sql = qq(
		SELECT ? - count(*) AS nb_missing_mark, count(DISTINCT mark_name) AS nb_distinct_mark_name, string_agg(DISTINCT mark_name, ', ') AS mark_names_list
			FROM (
			SELECT mark_group, mark_name
				FROM emaj.emaj_mark
				WHERE mark_time_id = ?
				  AND mark_group = ANY (?)
			) AS t
		);
	$sth[$db->{first_session}] = $dbh[$db->{first_session}]->prepare($sql)
		or traceDie("Error while preparing the call to _rlbk_init() for database $db->{name}.\n$DBI::errstr\n\n");

	$sth[$db->{first_session}]->bind_param(1, $db->{nb_group}, { pg_type => PG_INT4 });
	$sth[$db->{first_session}]->bind_param(2, $db->{mark_local_time_id}, { pg_type => PG_INT8 });
	$sth[$db->{first_session}]->bind_param(3, $db->{groups_array}, { pg_type => PG_TEXTARRAY });
	$sth[$db->{first_session}]->execute()
		or traceDie("Error while checking the target mark for database $db->{name}.\n$DBI::errstr\n\n");

	my ($nbMissingMark, $nbDistinctMarkName, $markNamesList) = $sth[$db->{first_session}]->fetchrow_array()
		or traceDie("Error while getting results of the target mark check for database $db->{name}.\n$DBI::errstr\n\n");
	$sth[$db->{first_session}]->finish();

	if ($nbMissingMark > 0) {
		traceDie("Error: the target mark is missing (or has not the expected time_id) for $nbMissingMark tables groups on database $db->{name} (time_id $db->{mark_local_time_id}).\n");
	}
	if ($nbDistinctMarkName > 1) {
		traceDie("Error: the target mark is known with $nbDistinctMarkName different names ($markNamesList) on database $db->{name}.\n");
	}
	$db->{realMarkName} = $markNamesList;		# The list has a single element

# Call the _rlbk_init() function. This rechecks the groups and mark, and prepares the parallel rollback by creating well balanced corridors.
# This is a synchronous call that returns the local rollback id.
	traceIfVerbose("database $db->{name}: call _rlbk_init()...");

	$sql = qq(
		SELECT emaj._rlbk_init(?, ?, ?, ?, TRUE, ?, ?)
		);
	$sth[$db->{first_session}] = $dbh[$db->{first_session}]->prepare($sql)
		or traceDie("Error while preparing the call to _rlbk_init() for database $db->{name}.\n$DBI::errstr\n\n");

	$sth[$db->{first_session}]->bind_param(1, $db->{groups_array}, { pg_type => PG_TEXTARRAY });
	$sth[$db->{first_session}]->bind_param(2, $db->{realMarkName}, { pg_type => PG_TEXT });
	$sth[$db->{first_session}]->bind_param(3, $isLogged ? 'TRUE' : 'FALSE', { pg_type => PG_BOOL });
	$sth[$db->{first_session}]->bind_param(4, $db->{nb_session}, { pg_type => PG_INT4 });
	$sth[$db->{first_session}]->bind_param(5, $isAlterGroupAllowed ? 'TRUE' : 'FALSE', { pg_type => PG_BOOL });
	$sth[$db->{first_session}]->bind_param(6, $comment, { pg_type => PG_TEXT });
	$sth[$db->{first_session}]->execute()
		or traceDie("Error while calling the _rlbk_init() function for database $db->{name}.\n$DBI::errstr\n\n");
	($db->{rlbk_id}) = $sth[$db->{first_session}]->fetchrow_array()
		or traceDie("Error while getting the results of the _rlbk_init() call for database $db->{name}.\n$DBI::errstr\n\n");
	$sth[$db->{first_session}]->finish();

	$sthTrace->execute('ROLLBACK_GROUPS', 'INIT', $db->{name}, "Mark name = $db->{realMarkName} ; Rollback Id = $db->{rlbk_id}")
		or traceDie("Error while inserting an operation init step into dist_emaj_hist.\n$DBI::errstr\n\n");
	$sthRecordRlbkId->execute($distRlbkId, $db->{name}, $db->{rlbk_id})
		or traceDie("Error while recording a local rollback id.\n$DBI::errstr\n\n");
	print ("On database '$db->{name}', $msgRlbk of tables groups $db->{groups_list} to mark '$db->{realMarkName}' is now in progress,");
	print (" using $db->{nb_session} corridors, with local rollback identifier $db->{rlbk_id}.\n");
}

###############################################################################
# Rollback phase 2. (lock)
###############################################################################

# Update the distributed rollback status in dist_emaj_rlbk.
$sthUpdateStatus->execute('LOCKING', $distRlbkId)
	or traceDie("Error while updating the distributed rollback status to LOCKING.\n$DBI::errstr\n\n");

# Asynchronously call the _rlbk_session_lock() function for each corridor of each database.
foreach my $db (@$databasesArray) {

	for (my $i = $db->{first_session} ; $i <= $db->{last_session}; $i++) {
		my $corridor = $i - $db->{first_session} + 1;

		traceIfVerbose("database $db->{name} - corridor #$corridor: call _rlbk_lock() asynchronously...");

		$sql = qq(
			SELECT emaj._rlbk_session_lock($db->{rlbk_id}, $corridor)
			);

		$sth[$i] = $dbh[$i]->prepare($sql, {pg_async => PG_ASYNC})
			or traceDie("Error while preparing the lock step for session $i (database $db->{name}).\n$DBI::errstr\n\n");
		$sth[$i]->execute()
			or traceDie("Error while calling the lock step for session $i (database $db->{name}).\n$DBI::errstr\n\n");
	}
}

# For each database, get the result of the previous _rlbk_lock() function call.
foreach my $db (@$databasesArray) {

	for (my $i = $db->{first_session} ; $i <= $db->{last_session}; $i++) {
		my $corridor = $i - $db->{first_session} + 1;

		traceIfVerbose("database $db->{name} - corridor #$corridor: get results of the _rlbk_lock() call...");

		$sth[$i]->pg_result()
			or traceDie("Error while waiting for the result of the lock step for database $db->{name}.\n$DBI::errstr\n\n");
		$sth[$i]->finish;

		$sthTrace->execute('ROLLBACK_GROUPS', 'LOCK', $db->{name}, 'Corridor: ' . $corridor)
			or traceDie("Error while inserting an operation lock step into dist_emaj_hist.\n$DBI::errstr\n\n");
	}
}

###############################################################################
# Rollback phase 3. (start)
###############################################################################

# For each database, synchronously call the _rlbk_start() function on the first corridor.
# This sets a rollback start mark if logged rollback.

foreach my $db (@$databasesArray) {

	traceIfVerbose("database $db->{name}: call _rlbk_start()...");

	$sql = qq(
		SELECT emaj._rlbk_start(?, ?)
		);
	$sth[$db->{first_session}] = $dbh[$db->{first_session}]->prepare($sql)
		or traceDie("Error while preparing the call to _rlbk_start() for database $db->{name}.\n$DBI::errstr\n\n");

	$sth[$db->{first_session}]->bind_param(1, $db->{rlbk_id}, { pg_type => PG_INT4 });
	$sth[$db->{first_session}]->bind_param(2, $db->{multiGroup}, { pg_type => PG_BOOL });
	$sth[$db->{first_session}]->execute()
		or traceDie("Error while calling the _rlbk_start() function for database $db->{name}.\n$DBI::errstr\n\n");
	$sth[$db->{first_session}]->finish();

	$sthTrace->execute('ROLLBACK_GROUPS', 'START', $db->{name}, undef)
		or traceDie("Error while inserting an operation start step into dist_emaj_hist.\n$DBI::errstr\n\n");
}

###############################################################################
# Rollback phase 4. (exec)
###############################################################################

# Update the distributed rollback status in dist_emaj_rlbk.
$sthUpdateStatus->execute('EXECUTING', $distRlbkId)
	or traceDie("Error while updating the distributed rollback status to EXECUTING.\n$DBI::errstr\n\n");

# Asynchronously call the _rlbk_session_exec() function for each corridor of each database.
foreach my $db (@$databasesArray) {

	for (my $i = $db->{first_session} ; $i <= $db->{last_session}; $i++) {
		my $corridor = $i - $db->{first_session} + 1;

		traceIfVerbose("database $db->{name} - corridor #$corridor: call _rlbk_session_exec() asynchronously...");

		$sql = qq(
			SELECT emaj._rlbk_session_exec($db->{rlbk_id}, $corridor)
			);

		$sth[$i] = $dbh[$i]->prepare($sql, {pg_async => PG_ASYNC})
			or traceDie("Error while preparing the exec step for session $i (database $db->{name}).\n$DBI::errstr\n\n");
		$sth[$i]->execute()
			or traceDie("Error while calling the exec step for session $i (database $db->{name}).\n$DBI::errstr\n\n");
	}
}

# For each database, get the result of the previous _rlbk_session_exec() function call.
foreach my $db (@$databasesArray) {

	for (my $i = $db->{first_session} ; $i <= $db->{last_session}; $i++) {
		my $corridor = $i - $db->{first_session} + 1;

		traceIfVerbose("database $db->{name} - corridor #$corridor: get results of the _rlbk_session_exec() call...");

		$sth[$i]->pg_result()
			or traceDie("Error while waiting for the result of the exec step for database $db->{name}.\n$DBI::errstr\n\n");
		$sth[$i]->finish;

		$sthTrace->execute('ROLLBACK_GROUPS', 'EXEC', $db->{name}, 'Corridor: ' . $corridor)
			or traceDie("Error while inserting an operation lock step into dist_emaj_hist.\n$DBI::errstr\n\n");
	}
}

###############################################################################
# Rollback phase 5. (end)
###############################################################################

# For each database, synchronously call the _rlbk_end() function on the first corridor.
# It sets a rollback end mark if logged rollback, and returns the execution report.

foreach my $db (@$databasesArray) {

	traceIfVerbose("database $db->{name}: call _rlbk_end()...");

	$sql = qq(
		SELECT * FROM emaj._rlbk_end(?, ?)
		);
	$sth[$db->{first_session}] = $dbh[$db->{first_session}]->prepare($sql)
		or traceDie("Error while preparing the call to _rlbk_end() for database $db->{name}.\n$DBI::errstr\n\n");

	$sth[$db->{first_session}]->bind_param(1, $db->{rlbk_id}, { pg_type => PG_INT4 });
	$sth[$db->{first_session}]->bind_param(2, $db->{multiGroup}, { pg_type => PG_BOOL });
	$sth[$db->{first_session}]->execute()
		or traceDie("Error while calling the _rlbk_end() function for database $db->{name}.\n$DBI::errstr\n\n");

	($db->{exec_report}) = $sth[$db->{first_session}]->fetchall_arrayref()
		or traceDie("Error while getting results of the _rlbk_end() call for database $db->{name}.\n$DBI::errstr\n\n");
	$sth[$db->{first_session}]->finish();

	$sthTrace->execute('ROLLBACK_GROUPS', 'END', $db->{name}, undef)
		or traceDie("Error while inserting an operation start step into dist_emaj_hist.\n$DBI::errstr\n\n");
}

###############################################################################
# Completion phase.
###############################################################################

# Start a transaction on the second dist_emaj connection to process distributed marks changes into the same distributed transaction.
$dbh2->begin_work()
	or traceDie("Begin transaction on the second dist_emaj connection failed.\n$DBI::errstr\n\n");

# When unlogged rollback, delete the distributed marks back to the target distributed mark on dist_emaj.
if (! $isLogged) {
	$sql = qq(
		DELETE FROM dist_emaj.dist_emaj_mark
			WHERE mark_cluster = ? AND mark_time_id > ?
	);
	$dbh2->do($sql, undef, $cluster, $targetMarkTimeId)
		or traceDie("Error while deleting old distributed marks.\n$DBI::errstr\n\n");
}

# When logged rollback, record the distributed marks for each database and tables group on dist_emaj.
if ($isLogged) {

# Get a global time stamp on dist_emaj for the end mark.
	$sql = qq(
		SELECT dist_emaj._set_time_stamp(?, 'M')
		);
	($globalEndTimeId) = $dbh2->selectrow_array($sql, undef, 'ROLLBACK_GROUPS')
		or traceDie("Error while setting the end mark global time id.\n$DBI::errstr\n\n");

# Record both marks on dist_emaj.
	$sql = qq(
		INSERT INTO dist_emaj.dist_emaj_mark (mark_cluster, mark_name, mark_time_id)
			VALUES (?, ?, ?), (?, ?, ?)
	);
	$dbh2->do($sql, undef, $cluster, 'RLBK_' . $distRlbkId . '_START', $globalTimeId,
						  $cluster, 'RLBK_' . $distRlbkId . '_DONE', $globalEndTimeId)
		or traceDie("Error while inserting the both distributed marks.\n$DBI::errstr\n\n");

# For each database,
	foreach my $db (@$databasesArray) {
		traceIfVerbose("database $db->{name}: Register both marks...");

# Get both mark ids using the first group name.
		my $firstGroup = $db->{groups_array}[0];
		my $startMarkName = 'RLBK_' . $db->{rlbk_id} . '_START';
		my $doneMarkName = 'RLBK_' . $db->{rlbk_id} . '_DONE';
		$sql = qq(
			SELECT
				(SELECT mark_time_id FROM emaj.emaj_mark WHERE mark_group = ? AND mark_name = ?) AS start_mark_time_id,
				(SELECT mark_time_id FROM emaj.emaj_mark WHERE mark_group = ? AND mark_name = ?) AS done_mark_time_id
		);
		($db->{start_mark_time_id}, $db->{done_mark_time_id}) =
				$dbh[$db->{first_session}]->selectrow_array($sql, undef, $firstGroup, $startMarkName, $firstGroup, $doneMarkName)
			or traceDie("Error while retrieving the local mark time ids for database $db->{name}.\n$DBI::errstr\n\n");

# Record the marks into dist_emaj_mark_group.
		$sql = qq(
			INSERT INTO dist_emaj.dist_emaj_mark_database (mkdb_time_id, mkdb_database, mkdb_local_time_id)
				VALUES (?, ?, ?)
		);
		$sth = $dbh2->prepare($sql)
			or traceDie("Error while preparing the INSERT into dist_emaj_mark_database statement.\n$DBI::errstr\n\n");
		
		$sth->bind_param(1, $globalTimeId, { pg_type => PG_INT8 });
		$sth->bind_param(2, $db->{name}, { pg_type => PG_TEXT });
		$sth->bind_param(3, $db->{start_mark_time_id}, { pg_type => PG_INT8 });
		$sth->execute()
			or traceDie("Error while inserting the rollback start mark local time id for database $db->{name}.\n$DBI::errstr\n\n");
		$sth->bind_param(1, $globalEndTimeId, { pg_type => PG_INT8 });
		$sth->bind_param(3, $db->{done_mark_time_id}, { pg_type => PG_INT8 });
		$sth->execute()
			or traceDie("Error while inserting the rollback done mark local time id for database $db->{name}.\n$DBI::errstr\n\n");

		$sth->finish;
	}
}

# Update the distributed rollback status in dist_emaj_rlbk.
$sthUpdateStatus->execute('COMPLETED', $distRlbkId)
	or traceDie("Error while updating the distributed rollback status to COMPLETED.\n$DBI::errstr\n\n");

# COMMIT transactions on all emaj databases and the second dist_emaj connection, with 2PC to be sure that all sessions
#   can either commit or rollback in a single transaction.
# Phase 1 : Prepare transaction
for (my $i = 1 ; $i <= $nbSession; $i++) {
	traceIfVerbose("Prepare transaction on session #$i...");
	$dbh[$i]->do("PREPARE TRANSACTION 'emajtx$i'")
		or traceDie("Prepare transaction on session #$i failed.\n$DBI::errstr\n\n");
}
$dbh2->do("PREPARE TRANSACTION 'distemajtx'")
		or traceDie("Prepare transaction on dist_emaj session failed.\n$DBI::errstr\n\n");

# Phase 2 : Commit
for (my $i = 1 ; $i <= $nbSession; $i++) {
	traceIfVerbose("Commit transaction on session #$i...");
	$dbh[$i]->do("COMMIT PREPARED 'emajtx$i'")
		or traceDie("Commit prepared #$i failed.\n$DBI::errstr\n\n");
}
$dbh2->do("COMMIT PREPARED 'distemajtx'")
		or traceDie("Commit prepared on dist_emaj session failed.\n$DBI::errstr\n\n");

# Call the emaj_cleanup_rollback_state() function on each database to set the rollback event as committed.
foreach my $db (@$databasesArray) {
	traceIfVerbose("database $db->{name}: call emaj_cleanup_rollback_state()...");
	$dbh[$db->{first_session}]->do("SELECT emaj.emaj_cleanup_rollback_state()")
		or traceDie("Error while calling the emaj_cleanup_rollback_state() function for database $db->{name}.\n$DBI::errstr\n\n");
}

# Close the sessions.
traceIfVerbose("Close all sessions...");
for (my $i = 1 ; $i <= $nbSession; $i++) {
	$dbh[$i]->disconnect
		or traceDie("Disconnection for session #$i failed:\n$DBI::errstr\n\n");
}
# Clean up on error.
END {
	if (defined($nbSession)) {
		for (my $i = 1 ; $i <= $nbSession; $i++) {
			$dbh[$i]->disconnect if ( ($dbh[$i]) && ($dbh[$i]->{Active}) )
		}
	}
	if ($dbh2) {
		$dbh2->disconnect;
	}
}

# Update the distributed rollback status in dist_emaj_rlbk.
$sthUpdateStatus->execute('COMMITTED', $distRlbkId)
	or traceDie("Error while updating the distributed rollback status to COMMITTED.\n$DBI::errstr\n\n");

# Trace the operation end.
$sthTrace->execute('DIST_EMAJ', 'END', $cluster, undef)
	or traceDie("Error while inserting the operation end trace into dist_emaj_hist.\n$DBI::errstr\n\n");

# Send the final message and the execution reports.
print ("$msgRlbk on cluster '$cluster' completed.\n");
print ("It has processed $nbGroup groups spread into $nbdatabase databases.\n");

foreach my $db (@$databasesArray) {
	print "  database '$db->{name}':\n";
	my $execReportRows = $db->{exec_report};
	foreach my $row ( @$execReportRows ) {
		print ("    " . @$row[0] . ": " . @$row[1]."\n");
	}
}

exit 0;

#------------------------------------------------------------------------------
#
# Sub-functions
#
#------------------------------------------------------------------------------
sub traceIfVerbose {
	my ($msg) = @_;

	if ($verbose) {
		if ($regressTest) {
			print ("dd/mm/yyyy - hh:mn:ss $msg\n");
		} else {
			print (strftime('%d/%m/%Y - %H:%M:%S',localtime) . " $msg\n");
		}
	}
	return;
}

sub traceDie {
	my ($errMsg) = @_;

	if ($dbh) {
# Record the trace into dist_emaj_hist if the connection is opened.
		if ($sthTrace) {
			my $msg = $errMsg; $msg =~ s/\n+$//;
			$sthTrace->execute('ROLLBACK_GROUPS', 'END', $cluster, $msg)
				or traceDie("Error while inserting the operation error trace into dist_emaj_hist.\n$DBI::errstr\n\n");
			$sthTrace->finish;
		}
# Set the distributed rollback status to ABORTED if it has been already recorded.
		if ($distRlbkId) {
			$sthUpdateStatus->execute('ABORTED', $distRlbkId)
				or traceDie("Error while updating the distributed rollback status to ABORTED.\n$DBI::errstr\n\n");
		}
# ... and close it properly before dying.
		$dbh->disconnect;
	}
	if ($dbh2) {
		$dbh2->disconnect;
	}

	die $errMsg;
}

sub printHelp {
	print qq{$PROGRAM belongs to the Distributed E-Maj extension (version $VERSION).
It performs consistent and parallel E-Maj rollbacks for several tables groups located on several databases.

Usage:
  $PROGRAM --cluster <groups cluster name> --mark <rollback target mark> [OPTION]...

Options:
  --alter-groups-allowed flag to allow the rollback to reach a mark set before alter group operations
  --comment              comment to describe the rollback operation (optional)
  --help                 shows this help, then exit
  --logged               logged rollback mode (i.e. 'rollbackable' rollback)
  --verbose              verbose mode
  --version              outputs version information, then exit

Connection options:
  -d,         database to connect to
  -h,         database database host or socket directory
  -p,         database database port
  -U,         user name to connect as
  -W,         password associated to the user, if needed

Example:
  $PROGRAM -h localhost -p 5432 -d myDb -U distemajadmin --cluster myCluster --mark Before-Prog-Start
  $PROGRAM -d myDb -U distemajadmin --cluster myCluster --mark Before-Prog-Start --logged --alter-groups-allowed --comment "Logged rollback before Prog abort"
};
	exit 0;
}

sub printVersion {
	print ("This version of $PROGRAM belongs to Distributed E-Maj version $VERSION.\n");
	print ("Type '$PROGRAM --help' to get usage information\n");
	exit 0;
}
