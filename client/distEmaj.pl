#! /usr/bin/perl -w
#
# distEmaj.pl
# This perl module belongs to the Distributed E-Maj extension.
#
# This software is distributed under the GNU General Public License.
#
# It performs distributed actions on tables groups located on several postgres servers in a consistent way.
# Supported actions are: start and stop tables groups, set a mark on tables groups several tables groups at once.
# The processed tables groups are members of a predefined "groups cluster".

use warnings;
use strict;

use Getopt::Long;

use DBI qw(:sql_types);
use DBD::Pg qw(:pg_types :async);
use POSIX qw(strftime);
use Data::Dumper;
#print Dumper($srv);

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
my $nbServer = 0;
my $nbSession = 0;
my $nbGroup = 0;

# Hash and array structures.
my $serversArray;                       # Reference to the array representing servers read from the dist_emaj configuration

# Variables for E-Maj foreign servers accesses.
my @dbh = undef;
my @sth = undef;

#
# Global variables. 
#
# Initialize parameters with their default values.
my $dbname = undef;						# -d PostgreSQL database name hosting the dist_emaj extension
my $host = undef;						# -h PostgreSQL server host name
my $port = undef;						# -p PostgreSQL server ip port
my $username = undef;					# -U user name for the connection to PostgreSQL database
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
	"verbose"   => sub { $verbose = 1; },
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
	SELECT srv_name AS name, srv_connect_string AS connect_string, srv_groups_array AS groups_array, srv_nb_group AS nb_group
		FROM dist_emaj.dist_emaj_server_aggregates
		WHERE clst_name = ?
		ORDER BY srv_name;
	);

$serversArray = $dbh->selectall_arrayref($sql, { Slice => {} }, $cluster)
	or die "Error while reading the cluster configuration from dist_emaj.\n$DBI::errstr\n\n";

# Count objects and build the sessions structure.
foreach my $srv (@$serversArray) {
	$nbServer++;
	$nbSession++;
	$nbGroup += $srv->{nb_group};
	$srv->{session} = $nbSession;
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

# Open a session for each server and perform preliminary checks.
# The initial cluster check has already verified for each server that:
#   - emaj exists in the database, with a proper version,
#   - the user has adminstration capabilities,
#   - and the PG instance is configured to allow distributed operations,
#   - all tables groups assigned to the cluster exist.
foreach my $srv (@$serversArray) {

# Open the session for the server.
	traceIfVerbose("Open session #$srv->{session} (for server $srv->{name})...");

	$dbh[$srv->{session}] = DBI->connect('dbi:Pg:'.$srv->{connect_string}, '', '', {AutoCommit => 1, RaiseError => 0, PrintError => 0})
		or die "Opening the session #$srv->{session} (on server $srv->{name}) failed.\n$DBI::errstr\n\n";
}

# Get a global time stamp on dist_emaj.
$sql = qq(
	SELECT dist_emaj._set_time_stamp(?, ?) AS real_mark_name
		);
($globalTimeId) = $dbh->selectrow_array($sql, undef, 'DIST_EMAJ', $emajEvent)
	or die "Error while setting the global time _id.\n$DBI::errstr\n\n";		
traceIfVerbose("Global time id = $globalTimeId.");

# For each session, start a transaction.
foreach my $srv (@$serversArray) {
	traceIfVerbose("Start transaction on session #$srv->{session}...");
	$dbh[$srv->{session}]->begin_work() 
		or die "Begin transaction #$srv->{session} failed.\n$DBI::errstr\n\n";
}

###############################################################################
# Operation phase 1. (init)
###############################################################################

# Call the initialization function for each server.
# This is a synchronous call that returns the array of real tables groups to process.
foreach my $srv (@$serversArray) {

	traceIfVerbose("Action $action - Call the initial step for server $srv->{name}...");
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

	$sth[$srv->{session}] = $dbh[$srv->{session}]->prepare($sql)
		or die "Error while preparing the initial step for server $srv->{name}.\n$DBI::errstr\n\n";

	$sth[$srv->{session}]->bind_param(1, $srv->{groups_array}, { pg_type => PG_TEXTARRAY });
	$sth[$srv->{session}]->bind_param(2, $realMarkName, { pg_type => PG_TEXT });
	if ($action eq 'start') {
		$sth[$srv->{session}]->bind_param(3, $keepLogs ? 'FALSE' : 'TRUE', { pg_type => PG_BOOL });
		$sth[$srv->{session}]->bind_param(4, $loggingGroupsAllowed ? 'TRUE' : 'FALSE', { pg_type => PG_BOOL });
	}
	if ($action eq 'stop') {
		$sth[$srv->{session}]->bind_param(3, $resetLogs ? 'TRUE' : 'FALSE', { pg_type => PG_BOOL });
		$sth[$srv->{session}]->bind_param(4, $idleGroupsAllowed ? 'TRUE' : 'FALSE', { pg_type => PG_BOOL });
	}

	$sth[$srv->{session}]->execute()
		or die "Error while executing the initial step for server $srv->{name}.\n$DBI::errstr\n\n";

	if ($action eq 'start') {
		($srv->{all_groups_array}, $srv->{idle_groups_array}, $srv->{logging_groups_array}) = $sth[$srv->{session}]->fetchrow_array()
			or die "Error while getting the results of the start_groups initial step for server $srv->{name}.\n$DBI::errstr\n\n";
	} elsif ($action eq 'stop') {
		($srv->{all_groups_array}, $srv->{logging_groups_array}, $srv->{idle_groups_array}) = $sth[$srv->{session}]->fetchrow_array()
			or die "Error while getting the results of the stop_groups initial step for server $srv->{name}.\n$DBI::errstr\n\n";
	} elsif ($action eq 'set_mark') {
		($srv->{all_groups_array}) = $sth[$srv->{session}]->fetchrow_array()
			or die "Error while getting the results of the set_mark_groups initial step for server $srv->{name}.\n$DBI::errstr\n\n";
	}

	$sth[$srv->{session}]->finish;

	$sth_trace->execute($emajAction, 'INIT', $srv->{name}, undef)
		or die "Error while inserting an operation init step into dist_emaj_hist.\n$DBI::errstr\n\n";
}

###############################################################################
# Operation phase 2. (lock)
###############################################################################

# Asynchronously call the lock function for each server.
# This returns the operation time id for the server.
foreach my $srv (@$serversArray) {

	if (defined($srv->{all_groups_array})) {
		traceIfVerbose("Action $action - Asynchronously call the lock step for server $srv->{name}...");

		if ($action eq 'start') {
			$sql = qq(
				SELECT emaj._start_groups_lock(?, ?, TRUE)
					);
			$sth[$srv->{session}] = $dbh[$srv->{session}]->prepare($sql, {pg_async => PG_ASYNC})
				or die "Error while preparing the start_groups lock step for server $srv->{name}.\n$DBI::errstr\n\n";
			$sth[$srv->{session}]->bind_param(1, $srv->{idle_groups_array}, { pg_type => PG_TEXTARRAY });
			$sth[$srv->{session}]->bind_param(2, $srv->{logging_groups_array}, { pg_type => PG_TEXTARRAY });

		} elsif ($action eq 'stop') {
			$sql = qq(
				SELECT emaj._stop_groups_lock(?, ?, TRUE, FALSE)
					);
			$sth[$srv->{session}] = $dbh[$srv->{session}]->prepare($sql, {pg_async => PG_ASYNC})
				or die "Error while preparing the stop_groups lock step for server $srv->{name}.\n$DBI::errstr\n\n";
			$sth[$srv->{session}]->bind_param(1, $srv->{logging_groups_array}, { pg_type => PG_TEXTARRAY });
			$sth[$srv->{session}]->bind_param(2, $srv->{idle_groups_array}, { pg_type => PG_TEXTARRAY });

		} elsif ($action eq 'set_mark') {
			$sql = qq(
				SELECT emaj._set_mark_groups_lock(?, TRUE)
					);
			$sth[$srv->{session}] = $dbh[$srv->{session}]->prepare($sql, {pg_async => PG_ASYNC})
				or die "Error while preparing the set_mark_groups lock step for server $srv->{name}.\n$DBI::errstr\n\n";
			$sth[$srv->{session}]->bind_param(1, $srv->{all_groups_array}, { pg_type => PG_TEXTARRAY });
		}

		$sth[$srv->{session}]->execute()
			or die "Error while calling the lock step for server $srv->{name}.\n$DBI::errstr\n\n";
	} else {
		traceIfVerbose("Action $action - No group to process for server $srv->{name}...");
		$sth_trace->execute($emajAction, 'LOCK', $srv->{name}, 'No group to process')
			or die "Error while inserting an operation 'No group to process' trace.\n$DBI::errstr\n\n";
	}
}

# For each server, get the result of the previous lock function call.
foreach my $srv (@$serversArray) {

	if (defined($srv->{all_groups_array})) {
		traceIfVerbose("Action $action - Get result of the lock function call for server $srv->{name}...");

		$sth[$srv->{session}]->pg_result()
			or die "Error while waiting for the result of the lock step for server $srv->{name}.\n$DBI::errstr\n\n";

		($srv->{time_id}) = $sth[$srv->{session}]->fetchrow_array()
			or die "Error while getting the result of the lock step for server $srv->{name}.\n$DBI::errstr\n\n";
		traceIfVerbose("    => time_id = $srv->{time_id}");

		$sth[$srv->{session}]->finish;
		$sth_trace->execute($emajAction, 'LOCK', $srv->{name}, 'Time_id: ' . $srv->{time_id})
			or die "Error while inserting an operation lock step into dist_emaj_hist.\n$DBI::errstr\n\n";
	}
}

###############################################################################
# Operation phase 3. (exec)
###############################################################################

# Asynchronously call the exec function for each server.
# This returns the number of processed tables and sequences for the server.
foreach my $srv (@$serversArray) {

	if (defined($srv->{all_groups_array})) {
		traceIfVerbose("Action $action - Asynchronously call the exec step for server $srv->{name}...");

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

		$sth[$srv->{session}] = $dbh[$srv->{session}]->prepare($sql, {pg_async => PG_ASYNC})
			or die "Error while preparing the exec step for server $srv->{name}.\n$DBI::errstr\n\n";

		$sth[$srv->{session}]->bind_param(1, $srv->{all_groups_array}, { pg_type => PG_TEXTARRAY });
		if ($action eq 'start') {
			$sth[$srv->{session}]->bind_param(2, $srv->{idle_groups_array}, { pg_type => PG_TEXTARRAY });
			$sth[$srv->{session}]->bind_param(3, $realMarkName, { pg_type => PG_TEXT });
			$sth[$srv->{session}]->bind_param(4, $keepLogs ? 'FALSE' : 'TRUE', { pg_type => PG_BOOL });
			$sth[$srv->{session}]->bind_param(5, $srv->{time_id}, { pg_type => PG_INT8 });
		} elsif ($action eq 'stop') {
			$sth[$srv->{session}]->bind_param(2, $srv->{logging_groups_array}, { pg_type => PG_TEXTARRAY });
			$sth[$srv->{session}]->bind_param(3, $realMarkName, { pg_type => PG_TEXT });
			$sth[$srv->{session}]->bind_param(4, $resetLogs ? 'TRUE' : 'FALSE', { pg_type => PG_BOOL });
			$sth[$srv->{session}]->bind_param(5, $srv->{time_id}, { pg_type => PG_INT8 });
		} elsif ($action eq 'set_mark') {
			$sth[$srv->{session}]->bind_param(2, $realMarkName, { pg_type => PG_TEXT });
			$sth[$srv->{session}]->bind_param(3, $comment, { pg_type => PG_TEXT });
			$sth[$srv->{session}]->bind_param(4, $srv->{time_id}, { pg_type => PG_INT8 });
		}

		$sth[$srv->{session}]->execute()
			or die "Error while calling the exec step for server $srv->{name}.\n$DBI::errstr\n\n";
	}
}

# For each server, get the result of the previous exec function call.
foreach my $srv (@$serversArray) {

	if (defined($srv->{all_groups_array})) {
		traceIfVerbose("Action $action - Get result of the exec function call for server $srv->{name}...");

		$sth[$srv->{session}]->pg_result()
			or die "Error while waiting for the result of the exec step for server $srv->{name}.\n$DBI::errstr\n\n";

		($srv->{nb_tblseq}) = $sth[$srv->{session}]->fetchrow_array()
			or die "Error while getting the result of the exec step for server $srv->{name}.\n$DBI::errstr\n\n";
		traceIfVerbose("    => processed tables and sequences = $srv->{nb_tblseq}");

		$sth[$srv->{session}]->finish;
		$sth_trace->execute($emajAction, 'EXEC', $srv->{name}, 'Processed tables and sequences: ' . $srv->{nb_tblseq})
			or die "Error while inserting an operation end exec step into dist_emaj_hist.\n$DBI::errstr\n\n";
	}
}

###############################################################################
# Operation phase 4. (end)
###############################################################################

# Comment the marks set at start or stop time, if a comment has been supplied in options.
# (a comment for set_mark has been already registered)
if ($comment ne '' && ($action eq 'start' || ($action eq 'stop' && !$resetLogs))) {
	foreach my $srv (@$serversArray) {
		traceIfVerbose("Action $action - Comment the mark for server $srv->{name}...");
		$sql = q(
			SELECT emaj.emaj_comment_mark_group(group_name, 'EMAJ_LAST_MARK', ?)
				FROM emaj.emaj_group
				WHERE group_name = ANY (?)
		);
		$sth[$srv->{session}] = $dbh[$srv->{session}]->prepare($sql)
			or die "Error while preparing the comment recording for server $srv->{name}.\n$DBI::errstr\n\n";

		$sth[$srv->{session}]->bind_param(1, $comment, { pg_type => PG_TEXT });
		$sth[$srv->{session}]->bind_param(2, $srv->{all_groups_array}, { pg_type => PG_TEXTARRAY });
		$sth[$srv->{session}]->execute
			or die "Error while recording the comment for server $srv->{name}.\n$DBI::errstr\n\n";
		$sth[$srv->{session}]->finish;
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

# Record the local mark attributes for each tables group on dist_emaj.
	$sql = qq(
		INSERT INTO dist_emaj.dist_emaj_mark_group (mark_time_id, mark_server, mark_group, mark_local_time_id)
			SELECT ?, ?, clgrp_group, ?
				FROM dist_emaj.dist_emaj_cluster_group
				WHERE clgrp_cluster = ? AND clgrp_server = ?
	);
	$sth = $dbh->prepare($sql)
		or die "Error while preparing the INSERT into dist_emaj_mark_group statement.\n$DBI::errstr\n\n";

	$sth->bind_param(1, $globalTimeId, { pg_type => PG_INT8 });
	$sth->bind_param(4, $cluster, { pg_type => PG_TEXT });

	foreach my $srv (@$serversArray) {
		$sth->bind_param(2, $srv->{name}, { pg_type => PG_TEXT });
		$sth->bind_param(3, $srv->{time_id}, { pg_type => PG_INT8 });
		$sth->bind_param(5, $srv->{name}, { pg_type => PG_TEXT });
		$sth->execute()
			or die "Error while inserting the operation distributed mark for server $srv->{name}.\n$DBI::errstr\n\n";
	}
	$sth->finish;
}

# Trace the operation end.
$sth_trace->execute('DIST_EMAJ', 'END', $cluster, undef)
	or die "Error while inserting the operation end trace into dist_emaj_hist.\n$DBI::errstr\n\n";

# COMMIT transactions on all emaj servers and dist_emaj, with 2PC.
# This ensure that all sessions can either be commited or rolled back in a single transaction.
# Phase 1 : Prepare transaction
foreach my $srv (@$serversArray) {
	traceIfVerbose("Prepare transaction #$srv->{session}...");
	$dbh[$srv->{session}]->do("PREPARE TRANSACTION 'emajtx$srv->{session}'")
		or die "Prepare transaction #$srv->{session} failed.\n$DBI::errstr\n\n";
}
$dbh->do("PREPARE TRANSACTION 'distemajtx'")
	or die "Prepare transaction on dist_emaj failed.\n$DBI::errstr\n\n";

# Phase 2 : Commit
foreach my $srv (@$serversArray) {
	traceIfVerbose("Commit transaction #$srv->{session}...");
	$dbh[$srv->{session}]->do("COMMIT PREPARED 'emajtx$srv->{session}'")
		or die "Commit prepared #$srv->{session} failed.\n$DBI::errstr\n\n";
}
$dbh->do("COMMIT PREPARED 'distemajtx'")
	or die "Commit prepared on dist_emaj failed.\n$DBI::errstr\n\n";

# Close the sessions.
traceIfVerbose("Close all sessions...");
foreach my $srv (@$serversArray) {
	$dbh[$srv->{session}]->disconnect
		or die "Disconnect for session #$srv->{session} failed:\n$DBI::errstr\n\n";
}
$dbh->disconnect
	or die "Disconnect from dist_emaj failed:\n$DBI::errstr\n\n";

# Clean up on error.
END {
	if (defined($nbSession)) {
		foreach my $srv (@$serversArray) {
			$dbh[$srv->{session}]->disconnect if ( ($dbh[$srv->{session}]) && ($dbh[$srv->{session}]->{Active}) )
		}
	}
	if ($dbh) {
		$dbh->disconnect;
	}
}

# Send the final message.
print ("The '$action' action on cluster '$cluster' is completed.\n");
print ("It has processed $nbGroup groups spread into $nbServer servers.\n");
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
It performs consistent E-Maj operations for several tables groups located on several servers.

Usage:
  $PROGRAM --action <start|stop|set_mark> --cluster <groups cluster name> --mark <mark_name> [OPTION]...

Options:
  --comment     comment describing the mark set for the operation (optional)
  --help        just displays this help
  --idle-groups-allowed
                allows tables groups already in IDLE state to be stopped (default = false)
  --keep-logs   do not reset logs content at groups start time (default = logs are deleted)
  --logging-groups-allowed
                allows tables groups already in LOGGING state to be started (default = false)
  --reset-logs  reset logs content at groups stop time (default = logs are not deleted)
  --verbose     verbose mode
  --version     just displays version information

Connection options:
  -d,           database to connect to
  -h,           database server host or socket directory
  -p,           database server port
  -U,           user name to connect as
  -W,           password associated to the user, if needed
  
Example:
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
