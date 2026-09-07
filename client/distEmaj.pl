#! /usr/bin/perl -w
#
# distEmaj.pl
# This perl module belongs to the Distributed E-Maj extension.
#
# This software is distributed under the GNU General Public License.
#
# It performs distributed actions on tables groups located on several postgres databases in a consistent way.
# Supported actions are: start and stop tables groups, set a mark on tables groups several tables groups at once.
# The processed tables groups are members of a predefined "group cluster".

use warnings;
use strict;

use Getopt::Long;

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types :async);
use POSIX qw(strftime);
use Data::Dumper;
#print Dumper($db);

STDOUT->autoflush(1);

use vars qw($VERSION $PROGRAM $APPNAME);

$VERSION = '<devel>';
$PROGRAM = 'distEmaj.pl';
$APPNAME = 'distEmaj';

# Variables for dist_emaj database access.
my $dbh;
my $sql_trace;
my $sth;
my $sth_trace;
my $conn_string = "application_name=$APPNAME;";

# Structure counters.
my $nbDatabase = 0;
my $nbSession = 0;
my $nbGroup = 0;

# Hash and array structures.
my $databasesArray;                     # Reference to the array representing databases read from the dist_emaj configuration

# Variables for E-Maj foreign databases accesses.
my @dbh = undef;
my @sth = undef;

#
# Global variables. 
#
# Initialize parameters with their default values.
my $dbname = undef;						# -d PostgreSQL database name hosting the dist_emaj extension
my $host = undef;						# -h PostgreSQL server host name
my $port = undef;						# -p PostgreSQL server ip port
my $username = undef;					# -U user name for the connection to Distributed E-Maj database
my $password = undef;					# -W user password
my $askHelp = 0;						# --help option
my $askVersion = 0;						# --version option
my $action = undef;						# --action action (mandatory)
my $cluster = undef;					# --cluster groups cluster (mandatory)
my $mark = undef;						# --mark E-maj mark name
my $comment = '';						# --comment comment
my $keepLogs = 0;						# --keep_logs
my $resetLogs = 0;						# --reset_logs
my $idleGroupsAllowed = 0;				# --idle-groups-allowed
my $loggingGroupsAllowed = 0;			# --logging-groups-allowed
my $regressTest = 0;					# --regression-test flag (to only display stable data when testing)
my $verbose = 0;						# --verbose flag for verbose mode

# Other global variables.
my $sql;
my $emajAction;
my $emajEvent;
my $realMarkName;
my $globalTimeId;
my $nbDeletedMark;
my $historiesPurgeMsg;

###############################################################################
# Initialization phase.
###############################################################################

# Print the header.
print (" Distributed E-Maj (version $VERSION) - launching parallel actions\n");
print ("----------------------------------------------------------------\n");

# Collect and prepare options.

# Get supplied options.
GetOptions(
# connection parameters
	"d=s" => sub { $dbname = $_[1]; $conn_string .= "dbname=$dbname;"; },
	"h=s" => sub { $host = $_[1]; $conn_string .= "host=$host;"; },
	"p=i" => sub { $port = $_[1]; $conn_string .= "port=$port;"; },
	"U=s" => \$username,
	"W=s" => \$password,
# other options
	"action:s" => \$action,
	"cluster:s" => \$cluster,
	"comment:s" => \$comment,
	"help|?" => \$askHelp,
	"idle-groups-allowed|iga" => \$idleGroupsAllowed,
	"keep-logs|kl" => \$keepLogs,
	"logging-groups-allowed|lga" => \$loggingGroupsAllowed,
	"mark:s" => \$mark,
	"regression-test|rt" => \$regressTest,
	"reset-logs|rl" => \$resetLogs,
	"verbose" => sub { $verbose = 1; },
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

# Check the action has been supplied with the proper value.
if (!defined $action) {
	die "Error: An action must be supplied with the --action start|stop|set_mark option !\n";
}
$action = lc($action);
if ($action eq 'start') {
	$emajAction = 'EMAJ_START_GROUPS';
	$emajEvent = 'S';
} elsif ($action eq 'set_mark') {
	$emajAction = 'EMAJ_SET_MARK_GROUPS';
	$emajEvent = 'M';
} elsif ($action eq 'stop') {
	$emajAction = 'EMAJ_STOP_GROUPS';
	$emajEvent = 'X';
} else {
	die "Error: The action '$action' is unknown (start|stop|set_mark expected) !\n";
}

# Check the cluster has been supplied.
if (!defined $cluster) {
	die "Error: A cluster name must be supplied with the --cluster option !\n";
}

# Check the mark has been supplied, unless the mark is useless.
if (!defined $mark && !($action eq 'stop' && $resetLogs)) {	
	die "Error: A mark must be supplied with the --mark option !\n";
}

# Check the --keep_logs option is only used with a start action.
if ($keepLogs && $action ne 'start') {
	warn("The --keep-logs option has no effect on $action action\n");
}

# Check the --reset_logs option is only used with a stop action.
if ($resetLogs && $action ne 'stop') {
	warn("The --reset-logs option has no effect on $action action\n");
}

# Check the --logging-groups-allowed option is only used with a start action.
if ($loggingGroupsAllowed && $action ne 'start') {
	warn("The --logging-groups-allowed option has no effect on $action action\n");
}

# Check the --idle-groups-allowed option is only used with a stop action.
if ($idleGroupsAllowed && $action ne 'stop') {
	warn("The --idle-groups-allowed option has no effect on $action action\n");
}

# Check the comment is useful.
if (defined($comment) && ($action eq 'stop' && $resetLogs)) {
	warn("The --comment option has no effect on stop operations with --reset-logs option\n");
}

# Log on the dist_emaj database.
# Connection parameters are optional. If not supplied, the environment variables and PostgreSQL default values are used.
$dbh = DBI->connect('dbi:Pg:' . $conn_string, $username, $password, {AutoCommit => 1, RaiseError => 0, PrintError => 0})
	or die "Error at dist_emaj database connection.\n$DBI::errstr\n";

# Check that the dist_emaj extension exists in the database.
$sql = qq(
	SELECT 1
		FROM pg_catalog.pg_extension
		WHERE extname = 'dist_emaj'
	);
$dbh->selectrow_array($sql)
	or die "Error: the dist_emaj extension does not exist in the " . $dbh->{pg_db} . " database.\n";

# Check that the user has the proper privileges, by verifying he is allowed to write into the dist_emaj_hist table.
$sql = qq(
	SELECT CASE WHEN pg_catalog.has_schema_privilege('dist_emaj', 'USAGE')
					AND pg_catalog.has_table_privilege('dist_emaj.dist_emaj_hist', 'INSERT')
					THEN 1 ELSE 0 END AS has_privileges
	);
my ($hasPrivileges) = $dbh->selectrow_array($sql)
	or die "Error while checking the user privileges on dist_emaj.\n$DBI::errstr\n\n";
if (!$hasPrivileges) {
	die "Error: the user is not allowed to access the dist_emaj database.\n";
}

# Check the cluster.
$sql = qq(
	SELECT dist_emaj.dist_emaj_verify_cluster(?, TRUE)
	);
$dbh->do($sql, undef, $cluster)
	or die "Error while checking the cluster.\n$DBI::errstr\n\n";

# For start action only, purge the oldest dist_emaj histories.
if ($action eq 'start') {
	traceIfVerbose("Purging dist_emaj histories...");
	$sql = qq(
		SELECT dist_emaj.dist_emaj_purge_histories()
		);
	($historiesPurgeMsg) = $dbh->selectrow_array($sql)
		or die "Error while purging histories.\n$DBI::errstr\n\n";
	if (defined($historiesPurgeMsg)) {
		traceIfVerbose("    => $historiesPurgeMsg.");
	}
}

# The conditions to start the operation are met.
# Prepare the statement to trace the operation into emaj_dist.
$sql_trace = qq(
    INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
		VALUES (?, ?, ?, ?)
	);
$sth_trace = $dbh->prepare($sql_trace)
	or die "Error while preparing the INSERT into dist_emaj_hist statement.\n$DBI::errstr\n\n";

# Start a transaction on the dist_emaj connection.
$dbh->begin_work()
		or die "Begin transaction dist_emaj failed.\n$DBI::errstr\n\n";

# Trace the operation start.
$sth_trace->execute('DIST_EMAJ', 'BEGIN', $cluster, "$action with mark $mark")
	or die "Error while inserting the operation start trace into dist_emaj_hist.\n$DBI::errstr\n\n";

# For set_mark action only, synchronize marks to report potential mark deletions in any server into distributed marks of the cluster.
# Note: For start action without --keep-logs, all distributed marks will be deleted at operation completion time.
#       For stop action, or start action with --keep-logs, the next operation will clean up distributed marks.
if ($action eq 'set_mark') {
	traceIfVerbose("Synchronizing marks...");
	$sql = qq(
		SELECT dist_emaj.dist_emaj_sync_marks_cluster(?)
		);
	($nbDeletedMark) = $dbh->selectrow_array($sql, undef, $cluster)
		or die "Error while synchronizing marks for the cluster.\n$DBI::errstr\n\n";
	if ($nbDeletedMark > 0) {
		traceIfVerbose("    => $nbDeletedMark distributed marks deleted.");
	}
}

# Get data about the requested cluster.
$sql = qq(
	SELECT db_name AS name, db_connect_string AS connect_string, db_groups_array AS groups_array, db_nb_group AS nb_group
		FROM dist_emaj.dist_emaj_database_aggregates
		WHERE clst_name = ?
		ORDER BY db_name;
	);

$databasesArray = $dbh->selectall_arrayref($sql, { Slice => {} }, $cluster)
	or die "Error while reading the cluster configuration from dist_emaj.\n$DBI::errstr\n\n";

# Count objects and build the sessions structure.
foreach my $db (@$databasesArray) {
	$nbDatabase++;
	$nbSession++;
	$nbGroup += $db->{nb_group};
	$db->{session} = $nbSession;
}

# Check and resolve the mark name supplied as option by calling the _check_new_dist_mark() function on the dist_emaj session.
if (!($action eq 'stop' && $resetLogs)) {
	$sql = qq(
		SELECT dist_emaj._check_new_dist_mark( ?, ?, ? ) AS real_mark_name
			);
	($realMarkName) = $dbh->selectrow_array($sql, undef, $cluster, $mark, ($action eq 'start' && !$keepLogs) ? 'FALSE' : 'TRUE')
		or die "Error while checking the mark name.\n$DBI::errstr\n\n";		
	traceIfVerbose("Mark name checked and resolved. Real mark name = '$realMarkName'.");
	if ($realMarkName ne $mark) {
		$sth_trace->execute('DIST_EMAJ', 'RESOLVE_MARK', $mark, $realMarkName)
			or die "Error while inserting the real mark name trace into dist_emaj_hist.\n$DBI::errstr\n\n";
	}
}

# Open a session for each database and perform preliminary checks.
# The initial cluster check has already verified for each database that:
#   - emaj exists in the database, with a proper version,
#   - the user has adminstration capabilities,
#   - and the PG instance is configured to allow distributed operations,
#   - all tables groups assigned to the cluster exist.
foreach my $db (@$databasesArray) {

# Open the session for the database.
	traceIfVerbose("Open session #$db->{session} (for database $db->{name})...");

	$dbh[$db->{session}] = DBI->connect('dbi:Pg:'.$db->{connect_string}, '', '', {AutoCommit => 1, RaiseError => 0, PrintError => 0})
		or die "Opening the session #$db->{session} (on database $db->{name}) failed.\n$DBI::errstr\n\n";
}

# Get a global time stamp on dist_emaj.
$sql = qq(
	SELECT dist_emaj._set_time_stamp(?, ?) AS real_mark_name
		);
($globalTimeId) = $dbh->selectrow_array($sql, undef, 'DIST_EMAJ', $emajEvent)
	or die "Error while setting the global time _id.\n$DBI::errstr\n\n";		
traceIfVerbose("Global time id = $globalTimeId.");

# For each session, start a transaction.
foreach my $db (@$databasesArray) {
	traceIfVerbose("Start transaction on session #$db->{session}...");
	$dbh[$db->{session}]->begin_work() 
		or die "Begin transaction #$db->{session} failed.\n$DBI::errstr\n\n";
}

###############################################################################
# Operation phase 1. (init)
###############################################################################

# Call the initialization function for each database.
# This is a synchronous call that returns the array of real tables groups to process.
foreach my $db (@$databasesArray) {

	traceIfVerbose("Action $action - Call the initial step for database $db->{name}...");
	if ($action eq 'start') {
		$sql = qq(
			SELECT p_groups, p_idleGroups, p_loggingGroups
				FROM emaj._start_groups_init(?, ?, TRUE, ?, ?)
			);
	} elsif ($action eq 'stop') {
		$sql = qq(
			SELECT p_groups, p_loggingGroups, p_idleGroups
				FROM emaj._stop_groups_init(?, ?, TRUE, FALSE, ?, ?)
			);
	} elsif ($action eq 'set_mark') {
		$sql = qq(
			SELECT p_groups
				FROM emaj._set_mark_groups_init(?, ?, TRUE)
			);
	}

	$sth[$db->{session}] = $dbh[$db->{session}]->prepare($sql)
		or die "Error while preparing the initial step for database $db->{name}.\n$DBI::errstr\n\n";

	$sth[$db->{session}]->bind_param(1, $db->{groups_array}, { pg_type => PG_TEXTARRAY });
	$sth[$db->{session}]->bind_param(2, $realMarkName, { pg_type => PG_TEXT });
	if ($action eq 'start') {
		$sth[$db->{session}]->bind_param(3, $keepLogs ? 'FALSE' : 'TRUE', { pg_type => PG_BOOL });
		$sth[$db->{session}]->bind_param(4, $loggingGroupsAllowed ? 'TRUE' : 'FALSE', { pg_type => PG_BOOL });
	}
	if ($action eq 'stop') {
		$sth[$db->{session}]->bind_param(3, $resetLogs ? 'TRUE' : 'FALSE', { pg_type => PG_BOOL });
		$sth[$db->{session}]->bind_param(4, $idleGroupsAllowed ? 'TRUE' : 'FALSE', { pg_type => PG_BOOL });
	}

	$sth[$db->{session}]->execute()
		or die "Error while executing the initial step for database $db->{name}.\n$DBI::errstr\n\n";

	if ($action eq 'start') {
		($db->{all_groups_array}, $db->{idle_groups_array}, $db->{logging_groups_array}) = $sth[$db->{session}]->fetchrow_array()
			or die "Error while getting the results of the start_groups initial step for database $db->{name}.\n$DBI::errstr\n\n";
	} elsif ($action eq 'stop') {
		($db->{all_groups_array}, $db->{logging_groups_array}, $db->{idle_groups_array}) = $sth[$db->{session}]->fetchrow_array()
			or die "Error while getting the results of the stop_groups initial step for database $db->{name}.\n$DBI::errstr\n\n";
	} elsif ($action eq 'set_mark') {
		($db->{all_groups_array}) = $sth[$db->{session}]->fetchrow_array()
			or die "Error while getting the results of the set_mark_groups initial step for database $db->{name}.\n$DBI::errstr\n\n";
	}

	$sth[$db->{session}]->finish;

	$sth_trace->execute($emajAction, 'INIT', $db->{name}, undef)
		or die "Error while inserting an operation init step into dist_emaj_hist.\n$DBI::errstr\n\n";
}

###############################################################################
# Operation phase 2. (lock)
###############################################################################

# Asynchronously call the lock function for each database.
# This returns the operation time id for the database.
foreach my $db (@$databasesArray) {

	if (defined($db->{all_groups_array})) {
		traceIfVerbose("Action $action - Asynchronously call the lock step for database $db->{name}...");

		if ($action eq 'start') {
			$sql = qq(
				SELECT emaj._start_groups_lock(?, ?, TRUE)
					);
			$sth[$db->{session}] = $dbh[$db->{session}]->prepare($sql, {pg_async => PG_ASYNC})
				or die "Error while preparing the start_groups lock step for database $db->{name}.\n$DBI::errstr\n\n";
			$sth[$db->{session}]->bind_param(1, $db->{idle_groups_array}, { pg_type => PG_TEXTARRAY });
			$sth[$db->{session}]->bind_param(2, $db->{logging_groups_array}, { pg_type => PG_TEXTARRAY });

		} elsif ($action eq 'stop') {
			$sql = qq(
				SELECT emaj._stop_groups_lock(?, ?, TRUE, FALSE)
					);
			$sth[$db->{session}] = $dbh[$db->{session}]->prepare($sql, {pg_async => PG_ASYNC})
				or die "Error while preparing the stop_groups lock step for database $db->{name}.\n$DBI::errstr\n\n";
			$sth[$db->{session}]->bind_param(1, $db->{logging_groups_array}, { pg_type => PG_TEXTARRAY });
			$sth[$db->{session}]->bind_param(2, $db->{idle_groups_array}, { pg_type => PG_TEXTARRAY });

		} elsif ($action eq 'set_mark') {
			$sql = qq(
				SELECT emaj._set_mark_groups_lock(?, TRUE)
					);
			$sth[$db->{session}] = $dbh[$db->{session}]->prepare($sql, {pg_async => PG_ASYNC})
				or die "Error while preparing the set_mark_groups lock step for database $db->{name}.\n$DBI::errstr\n\n";
			$sth[$db->{session}]->bind_param(1, $db->{all_groups_array}, { pg_type => PG_TEXTARRAY });
		}

		$sth[$db->{session}]->execute()
			or die "Error while calling the lock step for database $db->{name}.\n$DBI::errstr\n\n";
	} else {
		traceIfVerbose("Action $action - No group to process for database $db->{name}...");
		$sth_trace->execute($emajAction, 'LOCK', $db->{name}, 'No group to process')
			or die "Error while inserting an operation 'No group to process' trace.\n$DBI::errstr\n\n";
	}
}

# For each database, get the result of the previous lock function call.
foreach my $db (@$databasesArray) {

	if (defined($db->{all_groups_array})) {
		traceIfVerbose("Action $action - Get result of the lock function call for database $db->{name}...");

		$sth[$db->{session}]->pg_result()
			or die "Error while waiting for the result of the lock step for database $db->{name}.\n$DBI::errstr\n\n";

		($db->{time_id}) = $sth[$db->{session}]->fetchrow_array()
			or die "Error while getting the result of the lock step for database $db->{name}.\n$DBI::errstr\n\n";
		traceIfVerbose("    => time_id = $db->{time_id}");

		$sth[$db->{session}]->finish;
		$sth_trace->execute($emajAction, 'LOCK', $db->{name}, 'Time_id: ' . $db->{time_id})
			or die "Error while inserting an operation lock step into dist_emaj_hist.\n$DBI::errstr\n\n";
	}
}

###############################################################################
# Operation phase 3. (exec)
###############################################################################

# Asynchronously call the exec function for each database.
# This returns the number of processed tables and sequences for the database.
foreach my $db (@$databasesArray) {

	if (defined($db->{all_groups_array})) {
		traceIfVerbose("Action $action - Asynchronously call the exec step for database $db->{name}...");

		if ($action eq 'start') {
			$sql = qq(
				SELECT emaj._start_groups_exec(?, ?, ?, TRUE, ?, ?)
					)
		} elsif ($action eq 'stop') {
			$sql = qq(
				SELECT emaj._stop_groups_exec(?, ?, ?, TRUE, FALSE, ?, ?)
					)
		} elsif ($action eq 'set_mark') {
			$sql = qq(
				SELECT emaj._set_mark_groups_exec(?, ?, ?, TRUE, ?)
					)
		}

		$sth[$db->{session}] = $dbh[$db->{session}]->prepare($sql, {pg_async => PG_ASYNC})
			or die "Error while preparing the exec step for database $db->{name}.\n$DBI::errstr\n\n";

		$sth[$db->{session}]->bind_param(1, $db->{all_groups_array}, { pg_type => PG_TEXTARRAY });
		if ($action eq 'start') {
			$sth[$db->{session}]->bind_param(2, $db->{idle_groups_array}, { pg_type => PG_TEXTARRAY });
			$sth[$db->{session}]->bind_param(3, $realMarkName, { pg_type => PG_TEXT });
			$sth[$db->{session}]->bind_param(4, $keepLogs ? 'FALSE' : 'TRUE', { pg_type => PG_BOOL });
			$sth[$db->{session}]->bind_param(5, $db->{time_id}, { pg_type => PG_INT8 });
		} elsif ($action eq 'stop') {
			$sth[$db->{session}]->bind_param(2, $db->{logging_groups_array}, { pg_type => PG_TEXTARRAY });
			$sth[$db->{session}]->bind_param(3, $realMarkName, { pg_type => PG_TEXT });
			$sth[$db->{session}]->bind_param(4, $resetLogs ? 'TRUE' : 'FALSE', { pg_type => PG_BOOL });
			$sth[$db->{session}]->bind_param(5, $db->{time_id}, { pg_type => PG_INT8 });
		} elsif ($action eq 'set_mark') {
			$sth[$db->{session}]->bind_param(2, $realMarkName, { pg_type => PG_TEXT });
			$sth[$db->{session}]->bind_param(3, $comment, { pg_type => PG_TEXT });
			$sth[$db->{session}]->bind_param(4, $db->{time_id}, { pg_type => PG_INT8 });
		}

		$sth[$db->{session}]->execute()
			or die "Error while calling the exec step for database $db->{name}.\n$DBI::errstr\n\n";
	}
}

# For each database, get the result of the previous exec function call.
foreach my $db (@$databasesArray) {

	if (defined($db->{all_groups_array})) {
		traceIfVerbose("Action $action - Get result of the exec function call for database $db->{name}...");

		$sth[$db->{session}]->pg_result()
			or die "Error while waiting for the result of the exec step for database $db->{name}.\n$DBI::errstr\n\n";

		($db->{nb_tblseq}) = $sth[$db->{session}]->fetchrow_array()
			or die "Error while getting the result of the exec step for database $db->{name}.\n$DBI::errstr\n\n";
		traceIfVerbose("    => processed tables and sequences = $db->{nb_tblseq}");

		$sth[$db->{session}]->finish;
		$sth_trace->execute($emajAction, 'EXEC', $db->{name}, 'Processed tables and sequences: ' . $db->{nb_tblseq})
			or die "Error while inserting an operation end exec step into dist_emaj_hist.\n$DBI::errstr\n\n";
	}
}

###############################################################################
# Operation phase 4. (end)
###############################################################################

# Comment the marks set at start or stop time, if a comment has been supplied in options.
# (a comment for set_mark has been already registered)
if ($comment ne '' && ($action eq 'start' || ($action eq 'stop' && !$resetLogs))) {
	foreach my $db (@$databasesArray) {
		traceIfVerbose("Action $action - Comment the mark for database $db->{name}...");
		$sql = q(
			SELECT emaj.emaj_comment_mark_group(group_name, 'EMAJ_LAST_MARK', ?)
				FROM emaj.emaj_group
				WHERE group_name = ANY (?)
		);
		$sth[$db->{session}] = $dbh[$db->{session}]->prepare($sql)
			or die "Error while preparing the comment recording for database $db->{name}.\n$DBI::errstr\n\n";

		$sth[$db->{session}]->bind_param(1, $comment, { pg_type => PG_TEXT });
		$sth[$db->{session}]->bind_param(2, $db->{all_groups_array}, { pg_type => PG_TEXTARRAY });
		$sth[$db->{session}]->execute
			or die "Error while recording the comment for database $db->{name}.\n$DBI::errstr\n\n";
		$sth[$db->{session}]->finish;
	}
}

###############################################################################
# Completion phase.
###############################################################################

# Delete previous distributed marks when logs are reset.
# i.e. for either start operations without --keep-logs option or stop operations with --reset-logs option
if (($action eq 'start' && !$keepLogs) || ($action eq 'stop' && $resetLogs)) {
	traceIfVerbose("Action $action - Delete old marks in the distributed emaj database...");
	$sql = qq(
		DELETE FROM dist_emaj.dist_emaj_mark
			WHERE mark_cluster = ?
	);
	$dbh->do($sql, undef, $cluster)
		or die "Error while deleting old distributed marks.\n$DBI::errstr\n\n";
}

# Record the distributed mark on dist_emaj, if any.
if (!($action eq 'stop' && $resetLogs)) {
  traceIfVerbose("Action $action - Register the mark in the distributed emaj database...");
  $sql = qq(
      INSERT INTO dist_emaj.dist_emaj_mark (mark_cluster, mark_name, mark_time_id)
  		VALUES (?, ?, ?)
  );
  $dbh->do($sql, undef, $cluster, $realMarkName, $globalTimeId)
  	or die "Error while inserting the distributed mark.\n$DBI::errstr\n\n";

# Record the mark local time ids for databases on dist_emaj.
	$sql = qq(
		INSERT INTO dist_emaj.dist_emaj_mark_database (mkdb_time_id, mkdb_database, mkdb_local_time_id)
			VALUES (?, ?, ?)
	);
	$sth = $dbh->prepare($sql)
		or die "Error while preparing the INSERT into dist_emaj_mark_database statement.\n$DBI::errstr\n\n";

	$sth->bind_param(1, $globalTimeId, { pg_type => PG_INT8 });

	foreach my $db (@$databasesArray) {
		$sth->bind_param(2, $db->{name}, { pg_type => PG_TEXT });
		$sth->bind_param(3, $db->{time_id}, { pg_type => PG_INT8 });
		$sth->execute()
			or die "Error while inserting the mark local time id for database $db->{name}.\n$DBI::errstr\n\n";
	}
	$sth->finish;
}

# Trace the operation end.
$sth_trace->execute('DIST_EMAJ', 'END', $cluster, undef)
	or die "Error while inserting the operation end trace into dist_emaj_hist.\n$DBI::errstr\n\n";

# COMMIT transactions on all emaj databases and dist_emaj, with 2PC.
# This ensure that all sessions can either be commited or rolled back in a single transaction.
# Phase 1 : Prepare transaction
foreach my $db (@$databasesArray) {
	traceIfVerbose("Prepare transaction #$db->{session}...");
	$dbh[$db->{session}]->do("PREPARE TRANSACTION 'emajtx$db->{session}'")
		or die "Prepare transaction #$db->{session} failed.\n$DBI::errstr\n\n";
}
$dbh->do("PREPARE TRANSACTION 'distemajtx'")
	or die "Prepare transaction on dist_emaj failed.\n$DBI::errstr\n\n";

# Phase 2 : Commit
foreach my $db (@$databasesArray) {
	traceIfVerbose("Commit transaction #$db->{session}...");
	$dbh[$db->{session}]->do("COMMIT PREPARED 'emajtx$db->{session}'")
		or die "Commit prepared #$db->{session} failed.\n$DBI::errstr\n\n";
}
$dbh->do("COMMIT PREPARED 'distemajtx'")
	or die "Commit prepared on dist_emaj failed.\n$DBI::errstr\n\n";

# Close the sessions.
traceIfVerbose("Close all sessions...");
foreach my $db (@$databasesArray) {
	$dbh[$db->{session}]->disconnect
		or die "Disconnect for session #$db->{session} failed:\n$DBI::errstr\n\n";
}
$dbh->disconnect
	or die "Disconnect from dist_emaj failed:\n$DBI::errstr\n\n";

# Clean up on error.
END {
	if (defined($nbSession)) {
		foreach my $db (@$databasesArray) {
			$dbh[$db->{session}]->disconnect if ( ($dbh[$db->{session}]) && ($dbh[$db->{session}]->{Active}) )
		}
	}
	if ($dbh) {
		$dbh->disconnect;
	}
}

# Send the final message.
print ("The '$action' action on cluster '$cluster' is completed.\n");
print ("It has processed $nbGroup groups spread into $nbDatabase databases.\n");
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

sub printHelp {
	print qq{$PROGRAM belongs to the Distributed E-Maj extension (version $VERSION).
It performs consistent E-Maj operations for several tables groups located on several databases.

Usage:
  $PROGRAM --action <start|stop|set_mark> --cluster <groups cluster name> --mark <mark_name> [OPTION]...

Generic Program Information:
  -?, --help    Output a usage message and exit.
  --version     Output the program version number and exit.

Options:
  --comment     Comment describing the mark set for the operation (optional).
  --idle-groups-allowed
                Allows tables groups already in IDLE state to be stopped (default = false).
  --keep-logs   Do not reset logs content at groups start time (default = logs are deleted).
  --logging-groups-allowed
                Allows tables groups already in LOGGING state to be started (default = false).
  --reset-logs  Reset logs content at groups stop time (default = logs are not deleted).
  --verbose     Verbose mode.

Connection options:
  -d,           Distributed E-Maj database to connect to.
  -h,           Server host or socket directory.
  -p,           Server port.
  -U,           User name to connect as.
  -W,           Password associated to the user, if needed.
  
Examples:
  $PROGRAM -h localhost -p 5432 -d myDb -U distemajadmin --action start --cluster myCluster --mark Start_mark
  $PROGRAM -d myDb -U distemajadmin --action set_mark --cluster myCluster --mark New_mark --comment "This is a new mark"
};
	exit 0;
}

sub printVersion {
	print ("This version of $PROGRAM belongs to Distributed E-Maj version $VERSION.\n");
	print ("Type '$PROGRAM --help' to get usage information\n");
	exit 0;
}
