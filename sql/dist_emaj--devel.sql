--
-- Distributed E-Maj : add distributed features to the E-Maj solution : Version <devel>
--
-- This software is distributed under the GNU General Public License.
--
-- This script is automatically called by a "CREATE EXTENSION dist_emaj CASCADE;" statement.
--
-- This script must be executed by a role having SUPERUSER privileges.
--

-- Complain if this script is executed in psql, rather than via a CREATE EXTENSION statement.
\echo Use "CREATE EXTENSION dist_emaj CASCADE" to install the dist_emaj extension. \quit

----------------------------------------------------------------
--                                                            --
--                   Checks and roles                         --
--                                                            --
----------------------------------------------------------------

-- Perform some checks and create dist_emaj roles.
DO LANGUAGE plpgsql
$do$
  BEGIN
-- Check postgres version is >= 14.
    IF pg_catalog.current_setting('server_version_num')::INT < 140000 THEN
      RAISE EXCEPTION 'Distributed E-Maj installation: The current postgres version (%) is too old for this dist_emaj version. '
                      'It should be at least 14.', pg_catalog.current_setting('server_version');
    END IF;
-- Create both dist_emaj_adm and dist_emaj_viewer roles (NOLOGIN), if they do not exist.
    IF NOT EXISTS
         (SELECT 0
            FROM pg_catalog.pg_roles
            WHERE rolname = 'dist_emaj_adm'
         ) THEN
      CREATE ROLE dist_emaj_adm;
      COMMENT ON ROLE dist_emaj_adm IS
        $$This role may be granted to other roles in charge of Distributed E-Maj administration.$$;
    END IF;
    IF NOT EXISTS
         (SELECT 0
            FROM pg_catalog.pg_roles
            WHERE rolname = 'dist_emaj_viewer'
         ) THEN
      CREATE ROLE dist_emaj_viewer;
      COMMENT ON ROLE dist_emaj_viewer IS
        $$This role may be granted to other roles allowed to view Distributed E-Maj objects content.$$;
    END IF;
--
    RETURN;
  END;
$do$;

COMMENT ON SCHEMA dist_emaj IS
$$Contains all Distributed E-Maj related objects.$$;

----------------------------------------------------------------
--                                                            --
--                      Enumerated types                      --
--                                                            --
----------------------------------------------------------------

-- Enum of the possible values for the rollback status columns.
CREATE TYPE dist_emaj._rlbk_status_enum AS ENUM (
  'PLANNING',                -- the distributed emaj rollback is in the initial planning phase
  'LOCKING',                 -- the distributed emaj rollback is acquiring locks on tables
  'EXECUTING',               -- the distributed emaj rollback is in the main executing phase
  'COMPLETED',               -- the distributed emaj rollback is completed but not yet committed (or its transaction status is
                             --   not yet known)
  'COMMITTED',               -- the distributed emaj rollback transaction is known as committed
  'ABORTED'                  -- the distributed emaj rollback transaction is known as aborted
  );

----------------------------------------------------------------
--                                                            --
--                           Tables                           --
--                                                            --
----------------------------------------------------------------

-- Table containing the history of installed Distributed E-Maj versions.
CREATE TABLE dist_emaj.dist_emaj_version_hist (
  verh_version                 TEXT        NOT NULL,       -- dist_emaj version name
  verh_time_range              TSTZRANGE   NOT NULL,       -- validity time stamps range (with inclusive bounds)
                                                           --   the lower bound corresponds to the installation/upgrade end time or the
                                                           --   latest database logical restore time
  PRIMARY KEY (verh_version)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_version_hist IS
$$Contains Distributed E-Maj versions history.$$;

-- Table containing Distributed E-maj default parameters.
CREATE TABLE dist_emaj.dist_emaj_default_param (
  param_key                    TEXT        NOT NULL,       -- parameter key
  param_default                TEXT,                       -- parameter default value
  param_cast                   TEXT,                       -- the data type the parameter will be casted to when used
                                                           --   (NULL if there is no need to cast the data)
  param_rank                   INT,                        -- display rank
  PRIMARY KEY (param_key)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_default_param IS
$$Contains Distributed E-Maj default parameters.$$;

-- Table containing modified Distributed E-maj parameters.
CREATE TABLE dist_emaj.dist_emaj_param (
  param_key                    TEXT        NOT NULL,       -- parameter key
  param_value                  TEXT,                       -- parameter value
  PRIMARY KEY (param_key)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_param IS
$$Contains modified Distributed E-Maj parameters.$$;

-- Table containing the history of all Distributed E-Maj events.
CREATE TABLE dist_emaj.dist_emaj_hist (
  hist_id                      BIGINT      NOT NULL        -- internal id
                                           GENERATED ALWAYS AS IDENTITY,
  hist_datetime                TIMESTAMPTZ NOT NULL
                               DEFAULT clock_timestamp(),  -- insertion time
  hist_function                TEXT        NOT NULL,       -- main Distributed E-Maj function generating the event
  hist_event                   TEXT,                       -- type of event (often BEGIN or END)
  hist_object                  TEXT,                       -- object supporting the event
  hist_wording                 TEXT,                       -- additional comment
  hist_user                    TEXT                        -- the user who calls the Distributed E-Maj function (the current_user would not
                               DEFAULT session_user,       --   report the real user in SECURITY DEFINER functions)
  hist_txid                    BIGINT
                               DEFAULT txid_current(),     -- and its tx_id
  PRIMARY KEY (hist_id)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_hist IS
$$Contains Distributed E-Maj events history.$$;

-- Table containing the time stamps of major Distributed E-Maj events.
-- These stamps, used as time references in other internal tables, are insensitive to system time fluctuations and transaction wrapaound.
CREATE TABLE dist_emaj.dist_emaj_time_stamp (
  time_id                      BIGINT      NOT NULL        -- internal id
                               GENERATED ALWAYS AS IDENTITY,
  time_clock_timestamp         TIMESTAMPTZ NOT NULL        -- insertion clock time
                               DEFAULT clock_timestamp(),
  time_stmt_timestamp          TIMESTAMPTZ NOT NULL        -- insertion statement start time
                               DEFAULT statement_timestamp(),
  time_tx_timestamp            TIMESTAMPTZ NOT NULL        -- insertion transaction start time
                               DEFAULT transaction_timestamp(),
  time_event                   CHAR(1),                    -- event type that has generated the time stamp
                                                           --   C(reate cluster), D(rop cluster), A(lter cluster), I(mport)
                                                           --   S(tart), M(ark setting), R(ollback start), X(stop)
  PRIMARY KEY (time_id)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_time_stamp IS
$$Contains the time stamps of major Distributed E-Maj events.$$;

-- Table containing the E-Maj servers characteristics.
CREATE TABLE dist_emaj.dist_emaj_server (
  srv_name                     TEXT NOT NULL,              -- server name
  srv_connect_string           TEXT NOT NULL,              -- libpq server connect string (may include ip address or unix socket, ip port,
                                                           --   database name, role and password, or a service name)
  srv_rlbk_parallel_session    SMALLINT NOT NULL           -- maximum number of sessions a rollback may use on this server
                               CHECK (srv_rlbk_parallel_session > 0),
  srv_creation_time_id         BIGINT,                     -- time stamp at server create time
  srv_last_alter_time_id       BIGINT,                     -- time stamp of the latest server properties change
                                                           --   (NULL at server creation time)
  PRIMARY KEY (srv_name)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_server IS
$$Contains the E-Maj servers characteristics.$$;

-- Table containing the E-Maj table groups clusters.
CREATE TABLE dist_emaj.dist_emaj_cluster (
  clst_name                    TEXT NOT NULL,              -- cluster name
  clst_creation_time_id        BIGINT,                     -- time stamp at cluster create time
  clst_last_alter_time_id      BIGINT,                     -- time stamp of the latest cluster structure change
                                                           --   (NULL at cluster creation time)
  PRIMARY KEY (clst_name)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_cluster IS
$$Contains the E-Maj table groups clusters.$$;

-- Table describing the relationship between clusters and E-Maj table groups.
CREATE TABLE dist_emaj.dist_emaj_cluster_group (
  clgrp_cluster                TEXT NOT NULL,              -- cluster name
  clgrp_server                 TEXT NOT NULL,              -- name of the server hosting the table group
  clgrp_group                  TEXT NOT NULL,              -- table group name on the foreign server
  clgrp_last_assign_time_id    BIGINT,                     -- time stamp of the latest group assignment to the cluster
  PRIMARY KEY (clgrp_cluster, clgrp_server, clgrp_group),
  FOREIGN KEY (clgrp_cluster) REFERENCES dist_emaj.dist_emaj_cluster (clst_name),
  FOREIGN KEY (clgrp_server) REFERENCES dist_emaj.dist_emaj_server (srv_name)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_cluster_group IS
$$Describes the relationship between clusters and E-Maj table groups.$$;

-- Table containing the distributed marks.
CREATE TABLE dist_emaj.dist_emaj_mark (
  mark_cluster                 TEXT NOT NULL,              -- cluster name
  mark_name                    TEXT NOT NULL,              -- distributed mark name
  mark_time_id                 BIGINT NOT NULL,            -- time stamp of the distributed mark
  PRIMARY KEY (mark_cluster, mark_name),
  FOREIGN KEY (mark_cluster) REFERENCES dist_emaj.dist_emaj_cluster (clst_name),
  FOREIGN KEY (mark_time_id) REFERENCES dist_emaj.dist_emaj_time_stamp (time_id)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_mark IS
$$Contains the distributed marks.$$;

CREATE UNIQUE INDEX dist_emaj_mark_idx1 ON dist_emaj.dist_emaj_mark(mark_time_id);

-- Table describing the relationship between distributed marks and E-Maj table groups.
CREATE TABLE dist_emaj.dist_emaj_mark_group (
  mark_time_id                 BIGINT NOT NULL,            -- time stamp of the distributed mark
  mark_server                  TEXT NOT NULL,              -- server hosting the table group
  mark_group                   TEXT NOT NULL,              -- table group name on the foreign server
  mark_local_time_id           BIGINT,                     -- local time stamp of the mark on the foreign server
  PRIMARY KEY (mark_time_id, mark_server, mark_group),
  FOREIGN KEY (mark_time_id) REFERENCES dist_emaj.dist_emaj_mark (mark_time_id) ON DELETE CASCADE,
  FOREIGN KEY (mark_server) REFERENCES dist_emaj.dist_emaj_server (srv_name)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_mark_group IS
$$Describes the relationship between distributed marks and E-Maj table groups.$$;

CREATE INDEX dist_emaj_mark_group_idx1 ON dist_emaj.dist_emaj_mark_group(mark_local_time_id);

-- Table containing distributed rollback operations.
CREATE TABLE dist_emaj.dist_emaj_rlbk (
  rlbk_id                      INT         NOT NULL        -- distributed rollback id
                               GENERATED BY DEFAULT AS IDENTITY,
  rlbk_cluster                 TEXT,                       -- cluster to rollback
  rlbk_mark                    TEXT,                       -- distributed mark to rollback to (the original value at rollback time)
  rlbk_mark_time_id            BIGINT,                     -- time stamp id of the distributed mark to rollback to
  rlbk_time_id                 BIGINT,                     -- time stamp id at the rollback exec start
  rlbk_is_logged               BOOLEAN,                    -- rollback type: true = logged rollback
  rlbk_is_alter_group_allowed  BOOLEAN,                    -- flag allowing to rollback to a mark set before alter group operations
  rlbk_comment                 TEXT,                       -- comment about this rollback
  rlbk_backend_pid             INT         NOT NULL        -- pid of the postgres backend that inserted the row,
                               DEFAULT pg_backend_pid(),   --   used to monitor the rollback status
  rlbk_status                  dist_emaj._rlbk_status_enum,-- rollback status
  PRIMARY KEY (rlbk_id),
  FOREIGN KEY (rlbk_time_id) REFERENCES dist_emaj.dist_emaj_time_stamp (time_id),
  FOREIGN KEY (rlbk_mark_time_id) REFERENCES dist_emaj.dist_emaj_time_stamp (time_id)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_rlbk IS
$$Contains description of distributed rollback operations.$$;
-- Partial index on emaj_rlbk targeting in progress rollbacks (not yet committed or marked as aborted).
CREATE INDEX dist_emaj_rlbk_idx1 ON dist_emaj.dist_emaj_rlbk (rlbk_status)
    WHERE rlbk_status IN ('PLANNING', 'LOCKING', 'EXECUTING', 'COMPLETED');

-- Table containing local rollback data linked to distributed rollback operations.
CREATE TABLE dist_emaj.dist_emaj_rlbk_server (
  rlbs_rlbk_id                 INT         NOT NULL,       -- distributed rollback id
  rlbs_server                  TEXT        NOT NULL,       -- server name
  rlbs_local_rlbk_id           INT,                        -- local rollback id
  PRIMARY KEY (rlbs_rlbk_id, rlbs_server),
  FOREIGN KEY (rlbs_rlbk_id) REFERENCES dist_emaj.dist_emaj_rlbk (rlbk_id) ON DELETE CASCADE,
  FOREIGN KEY (rlbs_server) REFERENCES dist_emaj.dist_emaj_server (srv_name)
  );
COMMENT ON TABLE dist_emaj.dist_emaj_rlbk_server IS
$$Contains local rollback data linked to distributed rollback operations.$$;

----------------------------------------------------------------
--                                                            --
--                            View                            --
--                                                            --
----------------------------------------------------------------

-- View that matches dist_emaj_default_param and dist_emaj_param tables to offer a global vision of parameters.
CREATE VIEW dist_emaj.dist_emaj_all_param AS
  SELECT dist_emaj_default_param.param_key, coalesce(param_value, param_default) AS param_value, param_default, param_cast, param_rank
  FROM dist_emaj.dist_emaj_default_param
       LEFT OUTER JOIN dist_emaj.dist_emaj_param ON (dist_emaj_default_param.param_key = dist_emaj_param.param_key);
COMMENT ON VIEW dist_emaj.dist_emaj_all_param IS
$$View on all parameters.$$;

-- View used by clients to get servers characteristics.
CREATE VIEW dist_emaj.dist_emaj_server_aggregates AS
  SELECT clgrp_cluster AS clst_name, srv_name, srv_connect_string, srv_rlbk_parallel_session,
         array_agg(clgrp_group ORDER BY clgrp_group) AS srv_groups_array,
         string_agg(quote_literal(clgrp_group), ', ' ORDER BY clgrp_group) AS srv_groups_list,
         count(*) AS srv_nb_group
    FROM dist_emaj.dist_emaj_cluster_group
         JOIN dist_emaj.dist_emaj_server ON (dist_emaj_server.srv_name = dist_emaj_cluster_group.clgrp_server)
    GROUP BY clst_name, srv_name, srv_connect_string;
COMMENT ON VIEW dist_emaj.dist_emaj_server_aggregates IS
$$View on servers characteristics.$$;

----------------------------------------------------------------
--                                                            --
--                Distributed E-Maj Parameters                --
--                                                            --
----------------------------------------------------------------

-- Insert all parameters with their default value.
INSERT INTO dist_emaj.dist_emaj_default_param(param_key, param_default, param_cast, param_rank) VALUES
  ('history_retention', '1 year', 'INTERVAL', 1)               -- Retention delay for historical internal tables content
;

----------------------------------------------------------------
--                                                            --
--                Triggers on internal tables                 --
--                                                            --
----------------------------------------------------------------

-- Triggers on dist_emaj_param.

-- The dist_emaj_default_param_before_stmt_trg trigger and the associated _dist_emaj_default_param_before_stmt_fnct() function
--   blocks any attempt to modify the dist_emaj_default_param table.

CREATE OR REPLACE FUNCTION dist_emaj._dist_emaj_default_param_before_stmt_fnct()
RETURNS TRIGGER LANGUAGE plpgsql AS
$_dist_emaj_default_param_before_stmt_fnct$
  BEGIN
    RAISE EXCEPTION 'dist_emaj_default_param_before_stmt_trg: Modifying the dist_emaj_default_param table is not allowed.';
  END;
$_dist_emaj_default_param_before_stmt_fnct$;

CREATE TRIGGER dist_emaj_default_param_before_stmt_trg
  BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE ON dist_emaj.dist_emaj_default_param
  FOR EACH STATEMENT EXECUTE PROCEDURE dist_emaj._dist_emaj_default_param_before_stmt_fnct();

-- The _dist_emaj_param_before_stmt_trg trigger and the associated _dist_emaj_param_before_stmt_fnct() function
--   blocks any attempt to direcly modify the dist_emaj_param table, forcing the use of the the dist_emaj_set_param() function instead.

CREATE OR REPLACE FUNCTION dist_emaj._dist_emaj_param_before_stmt_fnct()
RETURNS TRIGGER LANGUAGE plpgsql AS
$_dist_emaj_param_before_stmt_fnct$
  BEGIN
    RAISE EXCEPTION 'dist_emaj_param_before_stmt_trg: Modifying the dist_emaj_param table is not allowed. Use the dist_emaj_set_param()'
                    ' function instead.';
  END;
$_dist_emaj_param_before_stmt_fnct$;

CREATE TRIGGER dist_emaj_param_before_stmt_trg
  BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE ON dist_emaj.dist_emaj_param
  FOR EACH STATEMENT EXECUTE PROCEDURE dist_emaj._dist_emaj_param_before_stmt_fnct();

----------------------------------------------------------------
--                                                            --
--                    Low level Functions                     --
--                                                            --
----------------------------------------------------------------

CREATE OR REPLACE FUNCTION dist_emaj._set_time_stamp(p_function TEXT, p_timeEvent CHAR(1))
RETURNS BIGINT LANGUAGE SQL AS
$$
-- This function creates a new time stamp in the dist_emaj_time_stamp table, records it into the dist_emaj_hist table
--   and returns its identifier.
-- It is called by distEmaj.pl and distEmajRollback.pl clients.
WITH inserted_time_stamp AS (
  INSERT INTO dist_emaj.dist_emaj_time_stamp (time_event)
    VALUES (p_timeEvent)
    RETURNING time_id, time_clock_timestamp
  ), inserted_hist AS (
  INSERT INTO dist_emaj.dist_emaj_hist (hist_datetime, hist_function, hist_event, hist_object)
    SELECT time_clock_timestamp, p_function, 'TIME STAMP SET', time_id::TEXT
      FROM inserted_time_stamp
  )
  SELECT time_id FROM inserted_time_stamp;
$$;

CREATE OR REPLACE FUNCTION dist_emaj._check_new_dist_mark(p_cluster TEXT, p_mark TEXT, p_check_exists BOOLEAN DEFAULT TRUE)
RETURNS TEXT LANGUAGE plpgsql AS
$_check_new_dist_mark$
-- This function verifies that a new distributed mark name to set is valid.
-- It processes the possible NULL mark value and the replacement of % wild characters.
-- If requested it checks its uniqueness within the cluster.
-- The fuction is called by distEmaj.pl client.
-- Input: cluster name,
--        name of the mark to set
--        boolean indicating whether the mark name existence must be checked or not
-- Output: internal name of the mark
  DECLARE
    v_markName               TEXT = p_mark;
  BEGIN
-- Check the mark name is not 'EMAJ_LAST_MARK'.
    IF p_mark = 'EMAJ_LAST_MARK' THEN
      RAISE EXCEPTION '_check_new_dist_mark: "EMAJ_LAST_MARK" is not an allowed name for a new mark.';
    END IF;
-- Process null or empty supplied mark name.
    IF v_markName = '' OR v_markName IS NULL THEN
      v_markName = 'MARK_%';
    END IF;
-- Process % wild characters in mark name.
    v_markName = replace(v_markName, '%', substring(to_char(clock_timestamp(), 'HH24.MI.SS.US') from 1 for 13));
-- When requested, check that the mark does not exist for any groups of the cluster.
    IF p_check_exists THEN
      PERFORM 1
        FROM dist_emaj.dist_emaj_mark
        WHERE mark_cluster = p_cluster
          AND mark_name = v_markName;
      IF FOUND THEN
        RAISE EXCEPTION '_check_new_dist_mark: The cluster "%" already contains a mark named "%".', p_cluster, v_markName;
      END IF;
    END IF;
--
    RETURN v_markName;
  END;
$_check_new_dist_mark$;

CREATE OR REPLACE FUNCTION dist_emaj._check_dist_mark(p_cluster TEXT, p_mark TEXT)
RETURNS BIGINT LANGUAGE plpgsql AS
$_check_dist_mark$
-- This function checks that a distributed rollback target mark is valid for a cluster.
-- It is called by distEmajRollback.pl client.
-- Input: cluster name,
--        name of the rollback target mark
-- Output: distributed mark time id
  DECLARE
    v_markTimeId             BIGINT;
    v_errGroupsList          TEXT;
    v_errServersList         TEXT;
  BEGIN
-- Check that the cluster exists.
    PERFORM 0
      FROM dist_emaj.dist_emaj_cluster
      WHERE clst_name = p_cluster;
    IF NOT FOUND THEN
      RAISE EXCEPTION '_check_dist_mark: The cluster "%" is unknown.', p_cluster;
    END IF;
-- Check that the cluster has at least an assigned table group.
    PERFORM 0
      FROM dist_emaj.dist_emaj_cluster_group
      WHERE clgrp_cluster = p_cluster;
    IF NOT FOUND THEN
      RAISE EXCEPTION '_check_dist_mark: Cannot perform a distributed rollback for an empty cluster.';
    END IF;
-- Get the time id for the mark and the cluster.
    SELECT mark_time_id
      INTO v_markTimeId
      FROM dist_emaj.dist_emaj_mark
      WHERE mark_cluster = p_cluster
        AND mark_name = p_mark;
    IF v_markTimeId IS NULL THEN
      RAISE EXCEPTION '_check_dist_mark: The mark "%" is unknown within the cluster "%".', p_mark, p_cluster;
    END IF;
-- Verify that all table group of the cluster have a mark for this time_id.
    SELECT string_agg(group_id, ', ' ORDER BY group_id) FILTER (WHERE mark_local_time_id IS NULL)
      INTO v_errGroupsList
      FROM (
        SELECT clgrp_server || '.' || clgrp_group AS group_id, mark_local_time_id
          FROM dist_emaj.dist_emaj_cluster_group
               LEFT OUTER JOIN dist_emaj.dist_emaj_mark_group ON (mark_time_id = v_markTimeId AND mark_server = clgrp_server
                                                            AND mark_group = clgrp_group)
          WHERE clgrp_cluster = p_cluster
      ) AS t;
    IF v_errGroupsList IS NOT NULL THEN
      RAISE EXCEPTION '_check_dist_mark: The mark "%" is unknown for groups "%" (or has not the same timestamp).',
                      p_mark, v_errGroupsList;
    END IF;
-- Verify that all table groups of each server have the same local time id.
    SELECT string_agg(clgrp_server, ', ' ORDER BY clgrp_server) FILTER (WHERE  distinct_local_time_id > 1)
      INTO v_errServersList
      FROM (
        SELECT clgrp_server, count(DISTINCT mark_local_time_id) AS distinct_local_time_id
          FROM dist_emaj.dist_emaj_cluster_group
               JOIN dist_emaj.dist_emaj_mark_group ON (mark_time_id = v_markTimeId AND mark_server = clgrp_server
                                                 AND mark_group = clgrp_group)
          WHERE clgrp_cluster = p_cluster
          GROUP BY clgrp_server
      ) AS t;
    IF v_errServersList IS NOT NULL THEN
      RAISE EXCEPTION '_check_dist_mark: On servers %, the mark "%" does not represent the same timestamp for all groups.',
                      v_errServersList, p_mark;
    END IF;
-- Build and return the servers characteristics.
    RETURN v_markTimeId;
  END;
$_check_dist_mark$;

----------------------------------------------------------------
--                                                            --
--          Functions to manage servers and clusters          --
--                                                            --
----------------------------------------------------------------

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_create_server(p_server TEXT, p_connectString TEXT, p_rollbackParallelSession INT,
                                                             p_ifNotExists BOOLEAN DEFAULT FALSE)
RETURNS INT LANGUAGE plpgsql AS
$dist_emaj_create_server$
-- This function creates or modifies a server.
-- The function doesn't check that connection string is valid. But the dist_emaj_verify_cluster() function does.
-- Input: server name,
--        the connect string to establish connections to the server, in the libpq format,
--        the number of parallel sessions that could be opened for distributed rollback operations,
--        boolean indicating whether the function is allowed to update the server if it already exists.
-- Output: number of created or modified servers (0 or 1)
  DECLARE
    v_exist                  BOOLEAN;
    v_timeId                 BIGINT;
  BEGIN
-- Insert a BEGIN event into the history.
    INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object)
      VALUES ('CREATE_SERVER', 'BEGIN', p_server);
-- Check that the server name is valid.
    IF p_server IS NULL OR p_server = '' THEN
      RAISE EXCEPTION 'dist_emaj_create_server: The server name can''t be NULL or empty.';
    END IF;
-- Check that the connect string is not null.
    IF p_connectString IS NULL THEN
      RAISE EXCEPTION 'dist_emaj_create_server: The connect string can''t be NULL.';
    END IF;
-- Check that the p_rollbackParallelSession is valid.
    IF p_rollbackParallelSession IS NULL OR p_rollbackParallelSession <= 0 THEN
      RAISE EXCEPTION 'dist_emaj_create_server: The number of rollback parallel sessions must be greater than 0.';
    END IF;
-- Determine whether the server already exists in dist_emaj_server table.
    v_exist = EXISTS
                (SELECT 0
                   FROM dist_emaj.dist_emaj_server
                   WHERE srv_name = p_server
                );
-- Abort if the server already exists and it should not.
    IF v_exist AND NOT p_ifNotExists THEN
      RAISE EXCEPTION 'dist_emaj_create_server: The server "%" already exists.', p_server;
    END IF;
-- OK
    IF NOT v_exist THEN
-- The server doesn't exist yet. So create it.
-- Get the time stamp of the operation.
      SELECT dist_emaj._set_time_stamp('CREATE_SERVER', 'C') INTO v_timeId;
-- Insert the row describing the server into the dist_emaj_server table.
      INSERT INTO dist_emaj.dist_emaj_server (srv_name, srv_connect_string, srv_rlbk_parallel_session, srv_creation_time_id)
        VALUES (p_server, p_connectString, p_rollbackParallelSession, v_timeId);
-- Insert a END event into the history.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('CREATE_SERVER', 'END', p_server, 'Server created');
      RETURN 1;
    ELSE
-- The server already exists. So update it.
-- Get the time stamp of the operation.
      SELECT dist_emaj._set_time_stamp('CREATE_SERVER', 'A') INTO v_timeId;
-- Update the server in the dist_emaj_server table.
      UPDATE dist_emaj.dist_emaj_server
        SET srv_connect_string = p_connectString, srv_rlbk_parallel_session = p_rollbackParallelSession, srv_last_alter_time_id = v_timeId
        WHERE srv_name = p_server;
-- Insert a END event into the history.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('CREATE_SERVER', 'END', p_server, 'Server modified');
      RETURN 0;
    END IF;
  END;
$dist_emaj_create_server$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_create_server(TEXT, TEXT, INT, BOOLEAN) IS
$$Creates an E-Maj server.$$;

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_drop_server(p_server TEXT, p_ifExists BOOLEAN DEFAULT FALSE,
                                                           p_cascade BOOLEAN DEFAULT FALSE)
RETURNS INT LANGUAGE plpgsql AS
$dist_emaj_drop_server$
-- This function drops an existing E-Maj server.
-- Input: server name,
--        boolean indicating whether the function raises an exception if the server does not exist,
--        boolean indicating whether the function also removes groups assignments that reference the server.
-- Output: number of dropped servers (0 or 1).
  DECLARE
    v_exist                  BOOLEAN;
    v_nbGroup                INT;
  BEGIN
-- Insert a BEGIN event into the history.
    INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object)
      VALUES ('DROP_SERVER', 'BEGIN', p_server);
-- Determine whether the server exists in dist_emaj_server table.
    v_exist = EXISTS
                (SELECT 0
                   FROM dist_emaj.dist_emaj_server
                   WHERE srv_name = p_server
                );
-- Abort if the server does not exist and it should.
    IF NOT v_exist AND NOT p_ifExists THEN
      RAISE EXCEPTION 'dist_emaj_drop_server: The server "%" does not exist.', p_server;
    END IF;
-- OK
    IF v_exist THEN
-- The server exists.
-- Get the time stamp of the operation (as a counterpart of the time stamp set at create server time).
      PERFORM dist_emaj._set_time_stamp('DROP_SERVER', 'D');
-- Count groups currently assigned to the server.
      SELECT count(*)
        INTO v_nbGroup
        FROM dist_emaj.dist_emaj_cluster_group
        WHERE clgrp_server = p_server;
      IF v_nbGroup > 0 THEN
        IF NOT p_cascade THEN
-- Some groups assigned to existing cluster belong to the server but the function is not allowed to remove them.
          RAISE EXCEPTION 'dist_emaj_drop_server: The server "%" has % groups assigned to existing clusters.', p_server, v_nbGroup;
        ELSE
-- Delete assigned groups that belong to the server.
          DELETE FROM dist_emaj.dist_emaj_cluster_group
            WHERE clgrp_server = p_server;
        END IF;
      END IF;
-- Delete the row describing the server in the dist_emaj_server table.
      DELETE FROM dist_emaj.dist_emaj_server
        WHERE srv_name = p_server;
-- Insert a END event into the history.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('DROP_SERVER', 'END', p_server, 'Server dropped, ' || v_nbGroup || ' group assignments deleted');
      RETURN 1;
    ELSE
-- The server does not exist.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('DROP_SERVER', 'END', p_server, 'The server did not exist');
      RETURN 0;
    END IF;
  END;
$dist_emaj_drop_server$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_drop_server(TEXT, BOOLEAN, BOOLEAN) IS
$$Drops an E-Maj server.$$;

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_create_cluster(p_cluster TEXT, p_ifNotExists BOOLEAN DEFAULT FALSE)
RETURNS INT LANGUAGE plpgsql AS
$dist_emaj_create_cluster$
-- This function creates a cluster.
-- Input: cluster name,
--        boolean indicating whether the function raises an exception if the cluster already exists.
-- Output: number of created clusters (0 or 1)
  DECLARE
    v_exist                  BOOLEAN;
    v_timeId                 BIGINT;
  BEGIN
-- Insert a BEGIN event into the history.
    INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object)
      VALUES ('CREATE_CLUSTER', 'BEGIN', p_cluster);
-- Check that the cluster name is valid.
    IF p_cluster IS NULL OR p_cluster = '' THEN
      RAISE EXCEPTION 'dist_emaj_create_cluster: The cluster name can''t be NULL or empty.';
    END IF;
-- Determine whether the cluster already exists in dist_emaj_cluster table.
    v_exist = EXISTS
                (SELECT 0
                   FROM dist_emaj.dist_emaj_cluster
                   WHERE clst_name = p_cluster
                );
-- Abort if the cluster already exists and it should not.
    IF v_exist AND NOT p_ifNotExists THEN
      RAISE EXCEPTION 'dist_emaj_create_cluster: The cluster "%" already exists.', p_cluster;
    END IF;
-- OK
    IF NOT v_exist THEN
-- The cluster doesn't exist yet.
-- Get the time stamp of the operation.
      SELECT dist_emaj._set_time_stamp('CREATE_CLUSTER', 'C') INTO v_timeId;
-- Insert the row describing the cluster into the dist_emaj_cluster table.
      INSERT INTO dist_emaj.dist_emaj_cluster (clst_name, clst_creation_time_id)
        VALUES (p_cluster, v_timeId);
-- Insert a END event into the history.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('CREATE_CLUSTER', 'END', p_cluster, 'Cluster created');
      RETURN 1;
    ELSE
-- The cluster already exists.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('CREATE_CLUSTER', 'END', p_cluster, 'The cluster already existed');
      RETURN 0;
    END IF;
  END;
$dist_emaj_create_cluster$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_create_cluster(TEXT, BOOLEAN) IS
$$Creates a Distributed E-Maj cluster.$$;

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_drop_cluster(p_cluster TEXT, p_ifExists BOOLEAN DEFAULT FALSE,
                                                            p_cascade BOOLEAN DEFAULT FALSE)
RETURNS INT LANGUAGE plpgsql AS
$dist_emaj_drop_cluster$
-- This function drops an existing cluster.
-- Input: cluster name,
--        boolean indicating whether the function raises an exception if the cluster does not exist,
--        boolean indicating whether the function also removes groups assignments.
-- Output: number of dropped clusters (0 or 1).
  DECLARE
    v_exist                  BOOLEAN;
    v_nbGroup                INT;
  BEGIN
-- Insert a BEGIN event into the history.
    INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object)
      VALUES ('DROP_CLUSTER', 'BEGIN', p_cluster);
-- Determine whether the cluster exists in dist_emaj_cluster table.
    v_exist = EXISTS
                (SELECT 0
                   FROM dist_emaj.dist_emaj_cluster
                   WHERE clst_name = p_cluster
                );
-- Abort if the cluster does not exist and it should.
    IF NOT v_exist AND NOT p_ifExists THEN
      RAISE EXCEPTION 'dist_emaj_drop_cluster: The cluster "%" does not exist.', p_cluster;
    END IF;
-- OK
    IF v_exist THEN
-- The cluster exists.
-- Get the time stamp of the operation (as a counterpart of the time stamp set at create cluster time).
      PERFORM dist_emaj._set_time_stamp('DROP_CLUSTER', 'D');
-- Count groups currently assigned to the cluster.
      SELECT count(*)
        INTO v_nbGroup
        FROM dist_emaj.dist_emaj_cluster_group
        WHERE clgrp_cluster = p_cluster;
      IF v_nbGroup > 0 THEN
        IF NOT p_cascade THEN
-- Some groups are assigned to the cluster but the function is not allowed to remove them.
          RAISE EXCEPTION 'dist_emaj_drop_cluster: The cluster "%" has % groups assigned to it.', p_cluster, v_nbGroup;
        ELSE
-- Delete groups that were assigned to the cluster.
          DELETE FROM dist_emaj.dist_emaj_cluster_group
            WHERE clgrp_cluster = p_cluster;
        END IF;
      END IF;
-- Delete the row describing the cluster in the dist_emaj_cluster table.
      DELETE FROM dist_emaj.dist_emaj_cluster
        WHERE clst_name = p_cluster;
-- Insert a END event into the history.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('DROP_CLUSTER', 'END', p_cluster, 'Cluster dropped, ' || v_nbGroup || ' group assignments deleted');
      RETURN 1;
    ELSE
-- The cluster does not exist.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('DROP_CLUSTER', 'END', p_cluster, 'The cluster did not exist');
      RETURN 0;
    END IF;
  END;
$dist_emaj_drop_cluster$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_drop_cluster(TEXT, BOOLEAN, BOOLEAN) IS
$$Drops a Distributed E-Maj cluster.$$;

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_assign_group(p_cluster TEXT, p_server TEXT, p_group TEXT,
                                                            p_ifNotExists BOOLEAN DEFAULT FALSE)
RETURNS INT LANGUAGE plpgsql AS
$dist_emaj_assign_group$
-- This function assigns a table group of an E-Maj server to a cluster.
-- Input: cluster name, server name, group name,
--        boolean indicating whether the function raises an exception if the table group is already assigned to the cluster.
-- Output: number of assigned table group (0 or 1)
  DECLARE
    v_exist                  BOOLEAN;
    v_timeId                 BIGINT;
  BEGIN
-- Insert a BEGIN event into the history.
    INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
      VALUES ('ASSIGN_GROUP', 'BEGIN', p_server || '.' || p_group, 'To cluster ' || p_cluster);
-- Check that the cluster exists.
    v_exist = EXISTS
                (SELECT 0
                   FROM dist_emaj.dist_emaj_cluster
                   WHERE clst_name = p_cluster
                );
    IF NOT v_exist THEN
      RAISE EXCEPTION 'dist_emaj_assign_group: The cluster "%" does not exist.', p_cluster;
    END IF;
-- Check that the server exists.
    v_exist = EXISTS
                (SELECT 0
                   FROM dist_emaj.dist_emaj_server
                   WHERE srv_name = p_server
                );
    IF NOT v_exist THEN
      RAISE EXCEPTION 'dist_emaj_assign_group: The server "%" does not exist.', p_server;
    END IF;
-- Determine whether the table group is already assigned to the cluster.
    v_exist = EXISTS
                (SELECT 0
                   FROM dist_emaj.dist_emaj_cluster_group
                   WHERE clgrp_cluster = p_cluster
                     AND clgrp_server = p_server
                     AND clgrp_group = p_group
                );
-- Abort if the table group is already assigned to the cluster and it should not.
    IF v_exist AND NOT p_ifNotExists THEN
      RAISE EXCEPTION 'dist_emaj_assign_group: The table group "%" on server "%" is already assigned to the cluster "%".',
                      p_group, p_server, p_cluster;
    END IF;
-- OK
    IF NOT v_exist THEN
-- The table group is not already assigned to the cluster.
-- Get the time stamp of the operation.
      SELECT dist_emaj._set_time_stamp('ASSIGN_GROUP', 'A') INTO v_timeId;
-- Insert the row describing the assignment into the dist_emaj_cluster_group table.
      INSERT INTO dist_emaj.dist_emaj_cluster_group (clgrp_cluster, clgrp_server, clgrp_group, clgrp_last_assign_time_id)
        VALUES (p_cluster, p_server, p_group, v_timeId);
-- Update the cluster clst_last_alter_time_id column.
      UPDATE dist_emaj.dist_emaj_cluster
        SET clst_last_alter_time_id = v_timeId
        WHERE clst_name = p_cluster;
-- Insert a END event into the history.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('ASSIGN_GROUP', 'END', p_server || '.' || p_group, 'Group assigned to the cluster');
      RETURN 1;
    ELSE
-- The group is already assigned to the cluster.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('ASSIGN_GROUP', 'END', p_server || '.' || p_group, 'The group was already assigned to the cluster');
      RETURN 0;
    END IF;
  END;
$dist_emaj_assign_group$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_assign_group(TEXT, TEXT, TEXT, BOOLEAN) IS
$$Assigns a table group to a Distributed E-Maj cluster.$$;

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_remove_group(p_cluster TEXT, p_server TEXT, p_group TEXT,
                                                            p_ifAssigned BOOLEAN DEFAULT FALSE)
RETURNS INT LANGUAGE plpgsql AS
$dist_emaj_remove_group$
-- This function removes a table group from a cluster.
-- Input: cluster name, server name, group name,
--        boolean indicating whether the function raises an exception if the group is already assigned to the cluster.
-- Output: number of removed groups (0 or 1).
  DECLARE
    v_exist                  BOOLEAN;
    v_timeId                 BIGINT;
  BEGIN
-- Insert a BEGIN event into the history.
    INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
      VALUES ('REMOVE_GROUP', 'BEGIN', p_server || '.' || p_group, 'From cluster ' || p_cluster);
-- Check that the cluster exists.
    v_exist = EXISTS
                (SELECT 0
                   FROM dist_emaj.dist_emaj_cluster
                   WHERE clst_name = p_cluster
                );
    IF NOT v_exist THEN
      RAISE EXCEPTION 'dist_emaj_remove_group: The cluster "%" does not exist.', p_cluster;
    END IF;
-- Check that the server exists.
    v_exist = EXISTS
                (SELECT 0
                   FROM dist_emaj.dist_emaj_server
                   WHERE srv_name = p_server
                );
    IF NOT v_exist THEN
      RAISE EXCEPTION 'dist_emaj_remove_group: The server "%" does not exist.', p_server;
    END IF;
-- Determine whether the table group is already assigned to the cluster.
    v_exist = EXISTS
                (SELECT 0
                   FROM dist_emaj.dist_emaj_cluster_group
                   WHERE clgrp_cluster = p_cluster
                     AND clgrp_server = p_server
                     AND clgrp_group = p_group
                );
-- Abort if the group is not assigned to the cluster and it should.
    IF NOT v_exist AND NOT p_ifAssigned THEN
      RAISE EXCEPTION 'dist_emaj_remove_group: The table group "%" on server "%" is not currently assigned to the cluster "%".',
                      p_group, p_server, p_cluster;
    END IF;
-- OK
    IF v_exist THEN
-- The group is effectively assigned to the cluster.
-- Get the time stamp of the operation.
      SELECT dist_emaj._set_time_stamp('REMOVE_GROUP', 'A') INTO v_timeId;
-- Remove the group from the cluster.
      DELETE FROM dist_emaj.dist_emaj_cluster_group
        WHERE clgrp_cluster = p_cluster
          AND clgrp_server = p_server
          AND clgrp_group = p_group;
-- Update the cluster clst_last_alter_time_id column.
      UPDATE dist_emaj.dist_emaj_cluster
        SET clst_last_alter_time_id = v_timeId
        WHERE clst_name = p_cluster;
-- Insert a END event into the history.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('REMOVE_GROUP', 'END', p_server || '.' || p_group, 'Group removed from the cluster');
      RETURN 1;
    ELSE
-- The cluster does not exist.
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
        VALUES ('REMOVE_GROUP', 'END', p_server || '.' || p_group, 'The group was not assigned to the cluster');
      RETURN 0;
    END IF;
  END;
$dist_emaj_remove_group$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_remove_group(TEXT, TEXT, TEXT, BOOLEAN) IS
$$Removes a table group from a Distributed E-Maj cluster.$$;

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_delete_before_mark_cluster(p_cluster TEXT, p_mark TEXT)
RETURNS INT LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
$dist_emaj_delete_before_mark_cluster$
-- This function deletes all distributed marks set before a given mark.
-- It deletes all related marks for each group of the cluster, by calling the emaj_delete_before_mark_group() function.
-- Input: cluster name,
--        distributed mark name.
-- Output: number of deleted distributed marks.
-- The function is defined as SECURITY DEFINER to allow the function to use the dblink_connect() function.
  DECLARE
    v_markTimeId             BIGINT;
    v_dblinkSchema           TEXT;
    v_stmt                   TEXT;
    v_group                  TEXT;
    v_localTimeId            BIGINT;
    v_nbMark                 INT;
    v_nbLocalMark            INT = 0;
    v_nbDistMark             INT;
    r_server                 RECORD;
  BEGIN
-- Insert a BEGIN event into the history
    INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
      VALUES ('DELETE_BEFORE_MARK_CLUSTER', 'BEGIN', p_cluster, p_mark);
-- Check the cluster.
    PERFORM dist_emaj.dist_emaj_verify_cluster(p_cluster, TRUE);
-- Synchronize marks before checking the supplied mark (to detect a missing local mark to be set as first mark)
    PERFORM dist_emaj.dist_emaj_sync_marks_cluster(p_cluster);
-- Check the distributed mark name.
    v_markTimeId = dist_emaj._check_dist_mark(p_cluster, p_mark);
-- Look for the schema holding the dblink functions.
    SELECT nspname INTO v_dblinkSchema
      FROM pg_catalog.pg_proc
           JOIN pg_catalog.pg_namespace ON (pg_namespace.oid = pronamespace)
      WHERE proname = 'dblink_connect'
      LIMIT 1;
-- For each server involved in the cluster.
    FOR r_server IN
      SELECT srv_name, srv_connect_string,
             array_agg(clgrp_group ORDER BY clgrp_group) AS groups_array
        FROM dist_emaj.dist_emaj_cluster_group
             JOIN dist_emaj.dist_emaj_server ON (dist_emaj_server.srv_name = dist_emaj_cluster_group.clgrp_server)
        WHERE clgrp_cluster = p_cluster
        GROUP BY srv_name, srv_connect_string
        ORDER BY srv_name
    LOOP
-- Log on the server.
      EXECUTE format('SELECT %I.dblink_connect(%L)',
                     v_dblinkSchema, r_server.srv_connect_string);
-- Process each group of the server.
      FOREACH v_group IN ARRAY r_server.groups_array
      LOOP
-- Get the local time_id of the mark for the group.
        SELECT mark_local_time_id
          INTO v_localTimeId
          FROM dist_emaj.dist_emaj_mark_group
          WHERE mark_time_id = v_markTimeId
            AND mark_server = r_server.srv_name
            AND mark_group = v_group;
-- Execute the emaj_delete_before_mark_group() function.
        v_stmt = 'SELECT emaj.emaj_delete_before_mark_group(' || quote_literal(v_group) || ', mark_name) '
                   'FROM emaj.emaj_mark '
                   'WHERE mark_time_id = ' || v_localTimeId || ' '
                     'AND mark_group = ' || quote_literal(v_group);
        EXECUTE format('SELECT nb_mark FROM %I.dblink(%L) AS (nb_mark INT)',
                       v_dblinkSchema, v_stmt)
          INTO v_nbMark;
        v_nbLocalMark = v_nbLocalMark + v_nbMark;
      END LOOP;
    END LOOP;
-- Disconnect from the latest server, if any.
    BEGIN
      EXECUTE format('SELECT %I.dblink_disconnect()',
                     v_dblinkSchema);
      EXCEPTION WHEN OTHERS THEN NULL;
    END;
-- Delete the distributed marks in dist_emaj_mark.
    DELETE FROM dist_emaj.dist_emaj_mark
      WHERE mark_cluster = p_cluster
        AND mark_time_id < v_markTimeId;
    GET DIAGNOSTICS v_nbDistMark = ROW_COUNT;
-- Purge histories.
    PERFORM dist_emaj.dist_emaj_purge_histories();
-- Insert an END event into the history.
    INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
      VALUES ('DELETE_BEFORE_MARK_CLUSTER', 'END', p_cluster,
              v_nbDistMark || ' distributed marks deleted ; '|| v_nbLocalMark || ' local marks deleted');
--
    RETURN v_nbDistMark;
  END;
$dist_emaj_delete_before_mark_cluster$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_delete_before_mark_cluster(TEXT, TEXT) IS
$$Deletes all distributed marks set before a given mark.$$;

CREATE OR REPLACE FUNCTION dist_emaj._verify_server(p_server TEXT, p_connectString TEXT, p_groupsList TEXT,
                                                    p_dblinkSchema TEXT, p_onErrorStop BOOLEAN)
RETURNS SETOF TEXT LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
$_verify_server$
-- This function verifies a server health.
-- It checks that the server:
--   is reachable by dblink,
--   contains an emaj extension in a valid version
--   can handle global transactions,
--   effectively owns all assiged table groups.
-- Input: server name,
--        connect string to reach the server,
--        list of groups owned by the server,
--        schema holding the dblinnk extension,
--        flag indicating whether an error is reported as a warning or an exception.
-- Output: set of error messages
-- The function is defined as SECURITY DEFINER to allow the function to use the dblink_connect() function.
  DECLARE
    v_checkStep              INT = 0;
    v_msg                    TEXT;
    v_stmt                   TEXT;
    v_schemaExists           BOOLEAN;
    v_isEmajAdmin            BOOLEAN;
    v_getVersionExists       BOOLEAN;
    v_emajVersion            TEXT;
    v_emajVersionArray       TEXT[];
    v_emajVersionNum         INT;
    v_maxPreparedTx          INT;
    v_missingGroupsList      TEXT;
  BEGIN
-- Try to connect.
    BEGIN
      EXECUTE format('SELECT %I.dblink_connect(%L)',
                     p_dblinkSchema, p_connectString);
      v_checkStep = v_checkStep + 1;
    EXCEPTION WHEN OTHERS THEN
      v_msg = format('Error on server "%s", the dblink connection failed (SQLSTATE %s - %s).',
                     p_server, SQLSTATE, SQLERRM);
      IF p_onErrorStop THEN
        RAISE EXCEPTION '_verify_server (1): %', v_msg;
      END IF;
      RETURN NEXT v_msg;
    END;
-- If the dblink connection is OK, check that the emaj schema exists in the remote database.
    IF v_checkStep >= 1 THEN
      v_stmt = 'SELECT 1 AS schema_exists '
                 'FROM pg_catalog.pg_namespace '
                 'WHERE nspname = ''emaj''';
      EXECUTE format('SELECT schema_exists FROM %I.dblink(%L) AS (schema_exists BOOLEAN)',
                     p_dblinkSchema, v_stmt)
        INTO v_schemaExists;
      IF v_schemaExists IS NULL THEN
        v_msg = format('Error on server "%s", the emaj extension is not installed in the database.',
                       p_server);
        IF p_onErrorStop THEN
          EXECUTE format('SELECT %I.dblink_disconnect()', p_dblinkSchema);
          RAISE EXCEPTION '_verify_server (2): %', v_msg;
        END IF;
        RETURN NEXT v_msg;
      ELSE
        v_checkStep = v_checkStep + 1;
      END IF;
    END IF;
-- If emaj is installed in the database, check that the user has E-Maj administration rights, by verifying he is allowed to call
--   the emaj_drop_group() function (the function has a very stable API).
    IF v_checkStep >= 2 THEN
      v_stmt = 'SELECT pg_catalog.has_schema_privilege(''emaj'', ''USAGE'') '
                      'AND pg_catalog.has_function_privilege(''emaj.emaj_drop_group(TEXT)'',''EXECUTE'') '
                      'AS is_admin, '
                      'EXISTS ( '
                        'SELECT 1 FROM pg_catalog.pg_proc JOIN pg_catalog.pg_namespace n ON (pronamespace = n.oid) '
                           'WHERE nspname = ''emaj'' AND proname = ''emaj_get_version'') get_version_exists';
      EXECUTE format('SELECT is_admin, get_version_exists FROM %I.dblink(%L) AS (is_admin BOOLEAN, get_version_exists BOOLEAN)',
                     p_dblinkSchema, v_stmt)
        INTO v_isEmajAdmin, v_getVersionExists;
      IF NOT v_isEmajAdmin THEN
        v_msg = format('Error on server "%s", the configured user is not an E-Maj administrator.',
                       p_server);
        IF p_onErrorStop THEN
          EXECUTE format('SELECT %I.dblink_disconnect()', p_dblinkSchema);
          RAISE EXCEPTION '_verify_server (3): %', v_msg;
        END IF;
        RETURN NEXT v_msg;
      ELSE
        v_checkStep = v_checkStep + 1;
      END IF;
    END IF;
-- If the user has the proper rights, verify the emaj_get_version() exists.
    IF v_checkStep >= 3 THEN
      IF NOT v_getVersionExists THEN
        v_msg = format('Error on server "%s", the emaj.emaj_get_version() function is missing. The emaj version is '
                          'probably too old (a version 5.0+ is required).',
                       p_server);
        IF p_onErrorStop THEN
          EXECUTE format('SELECT %I.dblink_disconnect()', p_dblinkSchema);
          RAISE EXCEPTION '_verify_server (4): %', v_msg;
        END IF;
        RETURN NEXT v_msg;
      END IF;
    END IF;
-- Then check the emaj version installed on the server is >= 5.0.
    IF v_checkStep >= 3 THEN
      v_stmt = 'SELECT emaj.emaj_get_version() AS emaj_version';
      EXECUTE format('SELECT emaj_version FROM %I.dblink(%L) AS (emaj_version TEXT)',
                     p_dblinkSchema, v_stmt)
        INTO v_emajVersion;
      v_emajVersionArray = regexp_match(v_emajVersion, '(\d+)\.(\d+)\.(\d+)');
      IF v_emajVersionArray IS NOT NULL THEN
        v_emajVersionNum = v_emajVersionArray[1]::SMALLINT * 10000 +
                           v_emajVersionArray[2]::SMALLINT * 100 +
                           v_emajVersionArray[3]::SMALLINT;
        IF v_emajVersionNum < 50000 THEN
          v_msg = format('Error on server "%s", the emaj version (%s) is too old. It must be at least 5.0.0.',
                         p_server, v_emajVersion);
          IF p_onErrorStop THEN
            EXECUTE format('SELECT %I.dblink_disconnect()', p_dblinkSchema);
            RAISE EXCEPTION '_verify_server (5): %', v_msg;
          END IF;
          RETURN NEXT v_msg;
        END IF;
      END IF;
    END IF;
-- Then check that the max_prepared_transactions GUC has a nonzero value.
    IF v_checkStep >= 3 THEN
      v_stmt = 'SELECT pg_catalog.current_setting(''max_prepared_transactions'')::INT AS max_prepared_tx';
      EXECUTE format('SELECT max_prepared_tx FROM %I.dblink(%L) AS (max_prepared_tx INT)',
                     p_dblinkSchema, v_stmt)
        INTO v_maxPreparedTx;
      IF v_maxPreparedTx <= 1 THEN
        v_msg = format('Error on server "%s", the postgres instance max_prepared_transactions parameter (%s) is too low '
                          'to launch distributed operations.',
                          p_server, v_maxPreparedTx);
        IF p_onErrorStop THEN
          EXECUTE format('SELECT %I.dblink_disconnect()', p_dblinkSchema);
          RAISE EXCEPTION '_verify_server (6): %', v_msg;
        END IF;
        RETURN NEXT v_msg;
      END IF;
    END IF;
-- Annd check that the all groups assigned to the cluster exist.
    IF v_checkStep >= 3 THEN
      v_stmt = 'SELECT string_agg(grp, '', '') AS missing_groups_list '
                 'FROM ( '
                   'SELECT grp '
                     'FROM unnest(ARRAY[' || p_groupsList || ']) AS t1(grp) '
                     'WHERE NOT EXISTS (SELECT 1 FROM emaj.emaj_group WHERE group_name = grp) '
                   ') AS t2';
      EXECUTE format('SELECT missing_groups_list FROM %I.dblink(%L) AS (missing_groups_list TEXT)',
                     p_dblinkSchema, v_stmt)
        INTO v_missingGroupsList;
      IF v_missingGroupsList IS NOT NULL THEN
        v_msg = format('Error on server "%s", some table groups (%s) are missing.',
                          p_server, v_missingGroupsList);
        IF p_onErrorStop THEN
          EXECUTE format('SELECT %I.dblink_disconnect()', p_dblinkSchema);
          RAISE EXCEPTION '_verify_server (7): %', v_msg;
        END IF;
        RETURN NEXT v_msg;
      END IF;
    END IF;
-- Disconnect from the server.
    IF v_checkStep >= 1 THEN
      EXECUTE format('SELECT %I.dblink_disconnect()',
                     p_dblinkSchema);
    END IF;
--
    RETURN;
  END;
$_verify_server$;

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_verify_cluster(p_cluster TEXT, p_checkEmptyCluster BOOLEAN DEFAULT FALSE)
RETURNS VOID LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
$dist_emaj_verify_cluster$
-- This function verifies the cluster health.
-- It checks that:
--   the cluster exists,
--   the cluster has at least 1 assigned table group (on request),
--   all servers are reachable by dblink, contain a emaj extension in a valid version and can handle global transactions,
--   all table groups assigned to the cluster exist.
-- It also cleans up the state of rollback operations that are known as in-progress.
-- Input: cluster name.
--        flag indicating whether empty cluster has to be checked (no check by default),
-- The function is defined as SECURITY DEFINER to look at all PG processes in pg_stat_activity.
-- It is called by both distEmaj.pl and distEmajRollback.pl clients (with empty cluster detection).
-- It may also be called manualy.
  DECLARE
    v_dblinkSchema           TEXT;
    r_rlbk                   RECORD;
  BEGIN
-- Check that the cluster exists.
    PERFORM 0
      FROM dist_emaj.dist_emaj_cluster
      WHERE clst_name = p_cluster;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'dist_emaj_verify_cluster: The cluster "%" is unknown.', p_cluster;
    END IF;
-- If requested, check that the cluster has at least 1 assigned table group.
    IF p_checkEmptyCluster THEN
      PERFORM 0
        FROM dist_emaj.dist_emaj_cluster_group
        WHERE clgrp_cluster = p_cluster;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'dist_emaj_verify_cluster: The cluster "%" is empty.', p_cluster;
      END IF;
    END IF;
-- Look for the schema holding the dblink functions.
    SELECT nspname INTO v_dblinkSchema
      FROM pg_catalog.pg_proc
           JOIN pg_catalog.pg_namespace ON (pg_namespace.oid = pronamespace)
      WHERE proname = 'dblink_connect'
      LIMIT 1;
-- Check each server involved in the cluster, using the _verify_server() function.
    PERFORM dist_emaj._verify_server(srv_name, srv_connect_string, groups_list, v_dblinkSchema, TRUE)
      FROM (
        SELECT srv_name, srv_connect_string,
               string_agg(quote_literal(clgrp_group), ',' ORDER BY clgrp_group) AS groups_list
          FROM dist_emaj.dist_emaj_cluster_group
               JOIN dist_emaj.dist_emaj_server ON (dist_emaj_server.srv_name = dist_emaj_cluster_group.clgrp_server)
          WHERE clgrp_cluster = p_cluster
          GROUP BY srv_name, srv_connect_string
          ORDER BY srv_name
        ) AS servers;
-- Cleanup the rollback states.
-- Look at each distributed rollback operation known as in-progress, i.e. not yet commited or aborted.
    FOR r_rlbk IN
      SELECT rlbk_id, rlbk_status, rlbk_backend_pid
        FROM dist_emaj.dist_emaj_rlbk
        WHERE rlbk_status IN ('PLANNING', 'LOCKING', 'EXECUTING', 'COMPLETED')  -- only pending rollback events
        ORDER BY rlbk_id
      LOOP
-- Examine the in execution PG processes by exploring the pg_stat_activity view.
-- Filter also on the database and application names to be sure that the pid is the expected one.
      PERFORM *
        FROM pg_catalog.pg_stat_activity
        WHERE pid = r_rlbk.rlbk_backend_pid
          AND datname = current_database()
          AND application_name = 'distEmajRollback';
-- If the pid is visible, the rollback is still in progress.
-- Otherwise, set the rollback event in emaj_rlbk as "ABORTED".
      IF NOT FOUND THEN
        UPDATE dist_emaj.dist_emaj_rlbk
          SET rlbk_status = 'ABORTED'
          WHERE rlbk_id = r_rlbk.rlbk_id;
        INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
          VALUES ('VERIFY_CLUSTER', 'CLEANUP_RLBK_STATE', 'Rollback id ' || r_rlbk.rlbk_id, 'set to ABORTED');
      END IF;
    END LOOP;
  END;
$dist_emaj_verify_cluster$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_verify_cluster(TEXT, BOOLEAN) IS
$$Performs a health check for a cluster.$$;

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_sync_marks_cluster(p_cluster TEXT)
RETURNS INT LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
$dist_emaj_sync_marks_cluster$
-- This function synchronizes distributed marks with marks recorded on each local table groups.
-- It deletes marks that have been localy deleted:
--   either by a local group stop/start/reset
--   or by emaj_delete_mark_group() or emaj_delete_before_mark_group() functions calls.
-- Input: cluster name.
-- Output: Number of deleted distributed marks.
-- The function is defined as SECURITY DEFINER to allow it to use the dblink_connect() function.
-- It is called by both distEmaj.pl and distEmajRollback.pl clients before executing any operation.
-- It may also be called manually.
  DECLARE
    v_dblinkSchema           TEXT;
    v_stmt                   TEXT;
    v_nbDeletedMark          INT = 0;
    v_serverHistMsg          TEXT;
    v_mostRecentStart        BIGINT;
    v_nbGroup                INT;
    v_nbMark                 INT;
    v_timeIdList             TEXT;
    v_missingMarkTimeIdArray BIGINT[];
    v_localTimeId            BIGINT;
    r_server                 RECORD;
  BEGIN
-- Record the BEGIN event into dist_emaj_hist.
    INSERT INTO dist_emaj.dist_emaj_hist(hist_function, hist_event, hist_object)
      VALUES ('SYNC_MARKS_CLUSTER', 'BEGIN', p_cluster);
-- Check that the cluster exists.
    PERFORM 0
      FROM dist_emaj.dist_emaj_cluster
      WHERE clst_name = p_cluster;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'dist_emaj_sync_marks_cluster: The cluster "%" is unknown.', p_cluster;
    END IF;
-- Look for the schema holding the dblink functions.
    SELECT nspname INTO v_dblinkSchema
      FROM pg_catalog.pg_proc
           JOIN pg_catalog.pg_namespace ON (pg_namespace.oid = pronamespace)
      WHERE proname = 'dblink_connect'
      LIMIT 1;
-- Perform a first lookup on each server involved in the cluster, in order to delete all distributed marks older than the most recent
--   group start/reset.
    FOR r_server IN
      SELECT srv_name, srv_connect_string,
             array_agg(clgrp_group ORDER BY clgrp_group) AS groups_array,
             string_agg(quote_literal(clgrp_group), ',' ORDER BY clgrp_group) AS groups_list,
             count(*) AS nb_groups_in_cluster
        FROM dist_emaj.dist_emaj_cluster_group
             JOIN dist_emaj.dist_emaj_server ON (dist_emaj_server.srv_name = dist_emaj_cluster_group.clgrp_server)
        WHERE clgrp_cluster = p_cluster
        GROUP BY srv_name, srv_connect_string
        ORDER BY srv_name
    LOOP
-- Connect to the emaj server.
      EXECUTE format('SELECT %I.dblink_connect(%L)',
                     v_dblinkSchema, r_server.srv_connect_string);
-- Get the most recent groups start local time_id by looking at log sessions.
      v_stmt = 'SELECT max(lower(lses_time_range)) AS most_recent_start, count(*) AS nb_groups '
                 'FROM emaj.emaj_log_session '
                 'WHERE lses_group = ANY (ARRAY[' || r_server.groups_list || ']) '
                   'AND upper_inf(lses_time_range)';
      EXECUTE format('SELECT most_recent_start, nb_groups FROM %I.dblink(%L) AS (most_recent_start BIGINT, nb_groups INT)',
                     v_dblinkSchema, v_stmt)
        INTO v_mostRecentStart, v_nbGroup;
-- If any group is missing, it means that at least one group is in IDLE state, thus invalidating all distributed marks for the entire
--   cluster. So delete all distributed marks.
      IF v_nbGroup < r_server.nb_groups_in_cluster THEN
        DELETE FROM dist_emaj.dist_emaj_mark
          WHERE mark_cluster = p_cluster;
        GET DIAGNOSTICS v_nbMark = ROW_COUNT;
        v_nbDeletedMark = v_nbDeletedMark + v_nbMark;
        v_serverHistMsg = (r_server.nb_groups_in_cluster - v_nbGroup)::text || ' stopped groups => all distributed marks deleted';
        INSERT INTO dist_emaj.dist_emaj_hist(hist_function, hist_event, hist_object, hist_wording)
          VALUES ('SYNC_MARKS_CLUSTER', 'DELETED MARKS', r_server.srv_name, v_serverHistMsg);
        EXIT;
      END IF;
-- Otherwise, delete all distributed marks whose time id is older than the most recent group start.
      v_serverHistMsg = '';
      DELETE FROM dist_emaj.dist_emaj_mark
        WHERE mark_cluster = p_cluster
          AND mark_time_id <= (
              SELECT max(mark_time_id)
                FROM dist_emaj.dist_emaj_mark_group
                WHERE mark_server = r_server.srv_name
                  AND mark_group = ANY (r_server.groups_array)
                  AND mark_local_time_id < v_mostRecentStart
              );
      GET DIAGNOSTICS v_nbMark = ROW_COUNT;
      IF v_nbMark > 0 THEN
        v_nbDeletedMark = v_nbDeletedMark + v_nbMark;
        v_serverHistMsg = v_serverHistMsg || 'Some stopped and restarted groups => ' || v_nbMark || ' distributed marks deleted';
      END IF;
-- Build the list of remaining distributed marks local time ids.
      SELECT string_agg('(' || time_id::text || ')', ',')
        FROM (
          SELECT DISTINCT mark_local_time_id
            FROM dist_emaj.dist_emaj_mark_group
            WHERE mark_server = r_server.srv_name
              AND mark_group = ANY (r_server.groups_array)
            ORDER BY 1
          ) AS t(time_id)
        INTO v_timeIdList;
-- Detect the missing distributed marks on the server.
      v_stmt = 'SELECT array_agg(time_id) AS time_id_array FROM ( '
                 'SELECT time_id FROM (VALUES ' || v_timeIdList || ') AS t(time_id) '
                   'EXCEPT '
                 'SELECT mark_time_id '
                   'FROM emaj.emaj_mark '
                   'WHERE mark_group = ANY (ARRAY[' || r_server.groups_list || ']) '
                     'AND mark_time_id >= ' || v_mostRecentStart || ' '
                   'GROUP BY mark_time_id '
                   'HAVING count(mark_group) = ' || r_server.nb_groups_in_cluster || ' '
               ') AS t';
      EXECUTE format('SELECT time_id_array FROM %I.dblink(%L) AS (time_id_array BIGINT[])',
                     v_dblinkSchema, v_stmt)
        INTO v_missingMarkTimeIdArray;
-- Delete distributed marks corresponding to the missing local marks.
      IF v_missingMarkTimeIdArray IS NOT NULL THEN
        FOREACH v_localTimeId IN ARRAY v_missingMarkTimeIdArray
        LOOP
          DELETE FROM dist_emaj.dist_emaj_mark
            WHERE mark_cluster = p_cluster
              AND mark_time_id = (
                  SELECT mark_time_id
                    FROM dist_emaj.dist_emaj_mark_group
                    WHERE mark_server = r_server.srv_name
                      AND mark_group = ANY (r_server.groups_array)
                      AND mark_local_time_id = v_localTimeId
                    LIMIT 1
                  );
        END LOOP;
        v_nbMark = array_length(v_missingMarkTimeIdArray, 1);
        v_nbDeletedMark = v_nbDeletedMark + v_nbMark;
        v_serverHistMsg = v_serverHistMsg || 'Some deleted local marks => ' || v_nbMark || ' distributed marks deleted';
      END IF;
      IF v_serverHistMsg <> '' THEN
        INSERT INTO dist_emaj.dist_emaj_hist(hist_function, hist_event, hist_object, hist_wording)
          VALUES ('SYNC_MARKS_CLUSTER', 'DELETED MARKS', r_server.srv_name, v_serverHistMsg);
      END IF;
    END LOOP;
-- Disconnect from the latest server, if any.
    BEGIN
      EXECUTE format('SELECT %I.dblink_disconnect()',
                     v_dblinkSchema);
      EXCEPTION WHEN OTHERS THEN NULL;
    END;
-- Record the END event into dist_emaj_hist.
    INSERT INTO dist_emaj.dist_emaj_hist(hist_function, hist_event, hist_object, hist_wording)
      VALUES ('SYNC_MARKS_CLUSTER', 'END', p_cluster, v_nbDeletedMark::TEXT || ' distributed marks deleted');
--
    RETURN v_nbDeletedMark;
  END;
$dist_emaj_sync_marks_cluster$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_sync_marks_cluster(TEXT) IS
$$Synchronizes recorded distributed marks of a cluster with local marks on servers.$$;

----------------------------------------------------------------
--                                                            --
--                  Global purpose functions                  --
--                                                            --
----------------------------------------------------------------

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_get_version()
RETURNS TEXT LANGUAGE SQL STABLE AS
$$
-- This function returns the current dist_emaj extension version.
SELECT verh_version FROM dist_emaj.dist_emaj_version_hist WHERE upper_inf(verh_time_range);
$$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_get_version() IS
$$Returns the current dist_emaj version.$$;

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_set_param(p_key TEXT, p_value TEXT)
RETURNS INT LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
$dist_emaj_set_param$
-- This function changes a parameter value in the dist_emaj_param table.
-- If the supplied value is NULL, it resetss the key to its default value.
-- The supplied key is case insensitive, eventhough keys in emaj_param are in lower case.
-- Input: key and value.
-- Ouput: number of updated parameters (0 or 1).
-- The function is defined as SECURITY DEFINER to disable/enable the trigger on dist_emaj_param.
  DECLARE
    v_key                    TEXT;
    v_currentValue           TEXT;
    v_cast                   TEXT;
    v_defaultValue           TEXT;
    v_event                  TEXT;
  BEGIN
    v_key = lower(p_key);
-- Get the current and default parameter values and the type to cast.
    SELECT param_value, param_cast, param_default
      INTO v_currentValue, v_cast, v_defaultValue
      FROM dist_emaj.dist_emaj_all_param
      WHERE param_key = v_key;
-- Stop if the parameter key is unknown.
    IF NOT FOUND THEN
      RAISE EXCEPTION 'dist_emaj_set_param: The "%" key is unknown.', v_key;
    END IF;
-- If there is no change, exit directly.
    IF (p_value IS NULL AND v_currentValue = v_defaultValue) OR    -- no local value to reset
       (p_value IS NOT NULL AND p_value = v_currentValue) THEN     -- unchanged local value
      RETURN 0;
    END IF;
-- Otherwise, check that the value has a correct format.
    CASE
-- Check INTERVAL values.
      WHEN v_cast = 'INTERVAL' THEN
        BEGIN
          PERFORM p_value::INTERVAL;
        EXCEPTION WHEN OTHERS THEN
          RAISE EXCEPTION 'dist_emaj_set_param: The "%" value ("%") is not a valid time interval.', v_key, p_value;
        END;
      ELSE
    END CASE;
-- Disable the trigger on emaj_param.
    ALTER TABLE dist_emaj.dist_emaj_param DISABLE TRIGGER dist_emaj_param_before_stmt_trg;
-- Record the change in dist_emaj_param.
    IF p_value IS NULL THEN
-- The new parameter value is NULL, DELETE the existing row from dist_emaj_param.
      DELETE FROM dist_emaj.dist_emaj_param
        WHERE param_key = v_key;
      p_value = v_defaultValue;
      v_event = 'DELETED PARAMETER';
    ELSIF v_currentValue = v_defaultValue THEN
-- The parameter has currently its default value, INSERT a row into dist_emaj_param.
      INSERT INTO dist_emaj.dist_emaj_param (param_key, param_value)
        VALUES (v_key, p_value);
      v_event = 'INSERTED PARAMETER';
    ELSE
-- Otherwise UPDATE it.
      UPDATE dist_emaj.dist_emaj_param
         SET param_value = p_value
         WHERE param_key = v_key;
      v_event = 'UPDATED PARAMETER';
    END IF;
-- Re-enable the trigger on dist_emaj_param.
   ALTER TABLE dist_emaj.dist_emaj_param ENABLE TRIGGER dist_emaj_param_before_stmt_trg;
-- Trace the change into dist_emaj_hist.
    INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
      VALUES ('SET_PARAM', v_event, v_key, 'From: ' || v_currentValue || ' to: ' || p_value);
--
    RETURN 1;
  END;
$dist_emaj_set_param$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_set_param(TEXT, TEXT) IS
$$Updates a parameter recorded into the dist_emaj_param table.$$;

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_purge_histories(p_retentionDelay INTERVAL DEFAULT NULL)
RETURNS TEXT LANGUAGE plpgsql AS
$dist_emaj_purge_histories$
-- This function purges the dist_emaj histories by deleting all rows prior the 'history_retention' parameter, but
--   without deleting event traces neither after the oldest distributed mark or after the oldest not committed or aborted
--   distributed rollback operation.
-- It purges oldest rows from the following tables:
--    dist_emaj_hist, dist_emaj_rlbk, dist_emaj_rlbk_server and dist_emaj_time_stamp
-- The function is called by distEmaj.pl.
-- It may also be is directly called by administrators.
-- A retention delay >= 100 years means infinite.
-- Input: retention delay (if supplied, it overloads the history_retention parameter from the dist_emaj_param table).
-- Output: execution report message
  DECLARE
    v_delay                  INTERVAL;
    v_datetimeLimit          TIMESTAMPTZ;
    v_maxTimeId              BIGINT;
    v_maxRlbkId              BIGINT;
    v_nbDeletedRow           BIGINT;
    v_nbPurgedRlbk           BIGINT;
    v_report                 TEXT;
  BEGIN
-- Compute the retention delay to use.
    SELECT coalesce(p_retentionDelay,
                    (SELECT param_value::INTERVAL
                       FROM dist_emaj.dist_emaj_all_param
                       WHERE param_key = 'history_retention'
                    ))
      INTO v_delay;
-- Immediately exit if the delay is infinity.
    IF v_delay >= INTERVAL '100 years' THEN
      RETURN 'Histories purge is disabled';
    END IF;
-- Compute the timestamp limit.
    SELECT least(
                                         -- compute the timestamp limit from the retention delay value
        (SELECT current_timestamp - v_delay),
                                         -- get the transaction timestamp of the oldest known distributed mark
        (SELECT min(time_tx_timestamp)
           FROM dist_emaj.dist_emaj_mark
                JOIN dist_emaj.dist_emaj_time_stamp ON (time_id = mark_time_id)),
                                         -- get the transaction timestamp of the oldest non committed or aborted distributed rollback
        (SELECT min(time_tx_timestamp)
           FROM dist_emaj.dist_emaj_rlbk
                JOIN dist_emaj.dist_emaj_time_stamp ON (time_id = rlbk_time_id)
           WHERE rlbk_status IN ('PLANNING', 'LOCKING', 'EXECUTING', 'COMPLETED')))
      INTO v_datetimeLimit;
-- Get the greatest timestamp identifier corresponding to the timeframe to purge, if any.
    SELECT max(time_id) INTO v_maxTimeId
      FROM dist_emaj.dist_emaj_time_stamp
      WHERE time_tx_timestamp < v_datetimeLimit;
-- Delete oldest rows from emaj_hist.
    DELETE FROM dist_emaj.dist_emaj_hist
      WHERE hist_datetime < v_datetimeLimit;
    GET DIAGNOSTICS v_nbDeletedRow = ROW_COUNT;
    IF v_nbDeletedRow > 0 THEN
      v_report = coalesce(v_report || ' ; ', '') || v_nbDeletedRow || ' dist_emaj_hist rows deleted';
    END IF;
    IF v_maxTimeId IS NOT NULL THEN
-- Get the greatest rollback identifier to purge.
      SELECT max(rlbk_id) INTO v_maxRlbkId
        FROM dist_emaj.dist_emaj_rlbk
        WHERE rlbk_time_id <= v_maxTimeId;
-- Purge the dist_emaj_rlbk table.
-- This automatically purges the dist_emaj_rlbk_server table via the FK between both tables.
      IF v_maxRlbkId IS NOT NULL THEN
        DELETE FROM dist_emaj.dist_emaj_rlbk
          WHERE rlbk_id <= v_maxRlbkId;
        GET DIAGNOSTICS v_nbPurgedRlbk = ROW_COUNT;
        v_report = coalesce(v_report || ' ; ', '') || v_nbPurgedRlbk || ' distributed rollback events deleted';
      END IF;
-- Purge the dist_emaj_time_stamp table.
      DELETE FROM dist_emaj.dist_emaj_time_stamp
        WHERE time_id < v_maxTimeId;
    END IF;
-- Record the purge into the history if there are significant data.
    IF v_report IS NOT NULL THEN
      INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_wording)
        VALUES ('PURGE_HISTORIES', v_report);
    END IF;
--
    RETURN coalesce(v_report, 'Nothing to delete');
  END;
$dist_emaj_purge_histories$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_purge_histories(INTERVAL) IS
$$Purges histories from dist_emaj tables.$$;

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_verify_all()
RETURNS SETOF TEXT LANGUAGE plpgsql
SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS
$dist_emaj_verify_all$
-- This function checks the entire clusters and servers configuration.
-- It checks that:
--   each cluster and each server has at least 1 assigned table group,
--   all servers are reachable by dblink, contain a emaj extension in a valid version and can handle global transactions,
--   all table groups assigned to any cluster exist.
-- It also cleans up the state of rollback operations that are known as in-progress.
-- The function is defined as SECURITY DEFINER to look at all PG processes in pg_stat_activity.
  DECLARE
    v_dblinkSchema           TEXT;
    v_errorFound             BOOLEAN = FALSE;
    r_message                RECORD;
    r_rlbk                   RECORD;
  BEGIN
-- Report warning for clusters having no assigned table group.
    FOR r_message IN
      SELECT format('Warning: the cluster "%s" has no assigned table group.', clst_name) AS msg
        FROM (
          SELECT clst_name
            FROM dist_emaj.dist_emaj_cluster
            WHERE NOT EXISTS(
              SELECT 0
                FROM dist_emaj.dist_emaj_cluster_group
                WHERE clgrp_cluster = clst_name
              )
            ORDER BY clst_name
          ) AS clusters
    LOOP
      RETURN NEXT r_message.msg;
    END LOOP;
-- Report warning for servers having no assigned table group.
    FOR r_message IN
      SELECT format('Warning: the server "%s" has no assigned table group.', srv_name) AS msg
        FROM (
          SELECT srv_name
            FROM dist_emaj.dist_emaj_server
            WHERE NOT EXISTS(
              SELECT 0
                FROM dist_emaj.dist_emaj_cluster_group
                WHERE clgrp_server = srv_name
              )
            ORDER BY srv_name
          ) AS servers
    LOOP
      RETURN NEXT r_message.msg;
    END LOOP;
-- Look for the schema holding the dblink functions.
    SELECT nspname INTO v_dblinkSchema
      FROM pg_catalog.pg_proc
           JOIN pg_catalog.pg_namespace ON (pg_namespace.oid = pronamespace)
      WHERE proname = 'dblink_connect'
      LIMIT 1;
-- Check all configured servers, using the _verify_server() function.
    FOR r_message IN
      SELECT dist_emaj._verify_server(srv_name, srv_connect_string, groups_list, v_dblinkSchema, FALSE) AS msg
        FROM (
          SELECT srv_name, srv_connect_string,
                 string_agg(quote_literal(clgrp_group), ',' ORDER BY clgrp_group) AS groups_list
            FROM dist_emaj.dist_emaj_server
                 LEFT OUTER JOIN dist_emaj.dist_emaj_cluster_group ON (dist_emaj_cluster_group.clgrp_server = dist_emaj_server.srv_name)
            GROUP BY srv_name, srv_connect_string
            ORDER BY srv_name
          ) AS servers
    LOOP
      RETURN NEXT r_message.msg;
      IF r_message.msg LIKE 'Error%' THEN
        v_errorFound = TRUE;
      END IF;
    END LOOP;
-- Cleanup the rollback states.
-- Look at each distributed rollback operation known as in-progress, i.e. not yet commited or aborted.
    FOR r_rlbk IN
      SELECT rlbk_id, rlbk_status, rlbk_backend_pid
        FROM dist_emaj.dist_emaj_rlbk
        WHERE rlbk_status IN ('PLANNING', 'LOCKING', 'EXECUTING', 'COMPLETED')  -- only pending rollback events
        ORDER BY rlbk_id
      LOOP
-- Examine the in execution PG processes by exploring the pg_stat_activity view.
-- Filter also on the database and application names to be sure that the pid is the expected one.
      PERFORM *
        FROM pg_catalog.pg_stat_activity
        WHERE pid = r_rlbk.rlbk_backend_pid
          AND datname = current_database()
          AND application_name = 'distEmajRollback';
-- If the pid is visible, the rollback is still in progress.
-- Otherwise, set the rollback event in emaj_rlbk as "ABORTED".
      IF NOT FOUND THEN
        UPDATE dist_emaj.dist_emaj_rlbk
          SET rlbk_status = 'ABORTED'
          WHERE rlbk_id = r_rlbk.rlbk_id;
        INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_event, hist_object, hist_wording)
          VALUES ('VERIFY_CLUSTER', 'CLEANUP_RLBK_STATE', 'Rollback id ' || r_rlbk.rlbk_id, 'set to ABORTED');
      END IF;
    END LOOP;
-- Final message if no error has been yet detected.
    IF NOT v_errorFound THEN
      RETURN NEXT 'No error detected';
    END IF;
--
    RETURN;
  END;
$dist_emaj_verify_all$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_verify_all() IS
$$Performs a health check of the entire dist_emaj configuration.$$;

----------------------------------------------------------------
--                                                            --
--                  Extension drop function                   --
--                                                            --
----------------------------------------------------------------

CREATE OR REPLACE FUNCTION dist_emaj.dist_emaj_drop_extension()
RETURNS VOID LANGUAGE plpgsql AS
$dist_emaj_drop_extension$
-- This function drops dist_emaj from the current database.
  DECLARE
    v_isSuperuser            BOOLEAN;
  BEGIN
-- Check the current role is superuser.
    SELECT rolsuper INTO v_isSuperuser
      FROM pg_catalog.pg_roles
      WHERE rolname = current_user;
    IF NOT v_isSuperuser THEN
      RAISE EXCEPTION 'dist_emaj_drop_extension: The role executing this function must be a superuser.';
    END IF;
--
-- OK, perform the removal actions.
--
--
-- Drop the event trigger that protects the extension against unattempted drop and its function (they are external to the extension).
    DROP FUNCTION IF EXISTS public._dist_emaj_protection_event_trigger_fnct() CASCADE;

-- Drop the dist_emaj extension.
    DROP EXTENSION dist_emaj CASCADE;
--
-- Drop the primary schema.
    DROP SCHEMA IF EXISTS dist_emaj CASCADE;
--
-- Try to drop the dist_emaj_adm and dist_emaj_viewer roles.
-- This would fail for instance if some other databases contain a dist_emaj extension or if some roles have been granted these roles.
    BEGIN
      DROP ROLE dist_emaj_adm;
      RAISE NOTICE 'dist_emaj_drop_extension: The dist_emaj_adm role has been dropped.';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'dist_emaj_drop_extension: The dist_emaj_adm role has not been dropped (sqlstate %).', SQLSTATE;
    END;
    BEGIN
      DROP ROLE dist_emaj_viewer;
      RAISE NOTICE 'dist_emaj_drop_extension: The dist_emaj_viewer role has been dropped.';
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'dist_emaj_drop_extension: The dist_emaj_viewer role has not been dropped (sqlstate %).', SQLSTATE;
    END;
--
    RETURN;
  END;
$dist_emaj_drop_extension$;
COMMENT ON FUNCTION dist_emaj.dist_emaj_drop_extension() IS
$$Uninstalls the Distributed E-Maj components from the current database.$$;

----------------------------------------------------------------
--                                                            --
--              Event trigger related functions               --
--                                                            --
----------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._dist_emaj_protection_event_trigger_fnct()
RETURNS EVENT_TRIGGER LANGUAGE plpgsql AS
$_dist_emaj_protection_event_trigger_fnct$
-- This function is called by the dist_emaj_protection_trg event trigger.
-- The function only blocks any attempt to drop the dist_emaj schema or the dist_emaj extension.
-- It is located into the public schema to be able to detect the dist_emaj schema removal attempt.
-- It is also unlinked from the dist_emaj extension to be able to detect the dist_emaj extension removal attempt.
  DECLARE
    r_dropped                RECORD;
  BEGIN
-- Scan all dropped objects.
    FOR r_dropped IN
      SELECT object_type, object_name
        FROM pg_event_trigger_dropped_objects()
    LOOP
      IF r_dropped.object_type = 'schema' AND r_dropped.object_name = 'dist_emaj' THEN
-- Detecting an attempt to drop the dist_emaj object.
        RAISE EXCEPTION 'Distributed E-Maj event trigger: Attempting to drop the schema "emaj".'
                        ' Please execute the dist_emaj.dist_emaj_drop_extension() function if you really want to remove all'
                        ' Distributed E-Maj components.';
      END IF;
      IF r_dropped.object_type = 'extension' AND r_dropped.object_name = 'dist_emaj' THEN
-- Detecting an attempt to drop the dist_emaj extension.
        RAISE EXCEPTION 'Distributed E-Maj event trigger: Attempting to drop the emaj extension.'
                        ' Please execute the dist_emaj.dist_emaj_drop_extension() function if you really want to remove all'
                        ' Distributed E-Maj components.';
      END IF;
    END LOOP;
  END;
$_dist_emaj_protection_event_trigger_fnct$;
COMMENT ON FUNCTION public._dist_emaj_protection_event_trigger_fnct() IS
$$Distributed E-Maj extension: support of the dist_emaj_protection_trg event trigger.$$;

----------------------------------------------------------------
--                                                            --
--                       Event triggers                       --
--                                                            --
----------------------------------------------------------------

-- dist_emaj_protection_trg.
CREATE EVENT TRIGGER dist_emaj_protection_trg
  ON sql_drop
  WHEN TAG IN ('DROP EXTENSION', 'DROP SCHEMA')
  EXECUTE PROCEDURE public._dist_emaj_protection_event_trigger_fnct();
COMMENT ON EVENT TRIGGER dist_emaj_protection_trg IS
$$Blocks the removal of the dist_emaj extension or schema.$$;

-- remove both event trigger components from the extension, so that they can fire the "DROP EXTENSION emaj".
ALTER EXTENSION dist_emaj DROP FUNCTION public._dist_emaj_protection_event_trigger_fnct();
ALTER EXTENSION dist_emaj DROP EVENT TRIGGER dist_emaj_protection_trg;

----------------------------------------------------------------
--                                                            --
--                 Rights on emaj components                  --
--                                                            --
----------------------------------------------------------------

-- Global rights on functions.
--

-- Revoke all rights on all created functions from PUBLIC.
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA dist_emaj FROM PUBLIC;

-- Rights given to dist_emaj_adm.
--
-- dist_emaj_adm can execute all dist_emaj functions and access all dist_emaj tables without any restrictions.

GRANT ALL ON SCHEMA dist_emaj TO dist_emaj_adm;
GRANT ALL ON ALL TABLES IN SCHEMA dist_emaj TO dist_emaj_adm;
GRANT ALL ON ALL SEQUENCES IN SCHEMA dist_emaj TO dist_emaj_adm;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA dist_emaj TO dist_emaj_adm;

-- Rights given to dist_emaj_viewer.
--
-- dist_emaj_viewer can
-- ... examine all dist_emaj tables and sequences,
--     except the dist_emaj_server table that contains connection parameters to servers, including password.

GRANT USAGE ON SCHEMA dist_emaj TO dist_emaj_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA dist_emaj TO dist_emaj_viewer;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA dist_emaj TO dist_emaj_viewer;

REVOKE SELECT ON TABLE dist_emaj.dist_emaj_server FROM dist_emaj_viewer;
GRANT SELECT (srv_name, srv_rlbk_parallel_session, srv_creation_time_id, srv_last_alter_time_id) ON TABLE dist_emaj.dist_emaj_server
  TO dist_emaj_viewer;
REVOKE SELECT ON TABLE dist_emaj.dist_emaj_server_aggregates FROM dist_emaj_viewer;
GRANT SELECT (clst_name, srv_name, srv_rlbk_parallel_session, srv_groups_array, srv_groups_list, srv_nb_group)
  ON TABLE dist_emaj.dist_emaj_server_aggregates TO dist_emaj_viewer;

-- ... and execute a subset of dist_emaj functions for which rights are explicitely granted.

GRANT EXECUTE ON FUNCTION dist_emaj.dist_emaj_get_version() TO dist_emaj_viewer;

----------------------------------------------------------------
--                                                            --
--           Specific operations for the extension            --
--                                                            --
----------------------------------------------------------------

-- Register dist_emaj tables content as candidate for pg_dump.
SELECT pg_catalog.pg_extension_config_dump('dist_emaj_param', '');
SELECT pg_catalog.pg_extension_config_dump('dist_emaj_hist', 'WHERE hist_id > 1');
SELECT pg_catalog.pg_extension_config_dump('dist_emaj_time_stamp', '');
SELECT pg_catalog.pg_extension_config_dump('dist_emaj_server', '');
SELECT pg_catalog.pg_extension_config_dump('dist_emaj_cluster', '');
SELECT pg_catalog.pg_extension_config_dump('dist_emaj_cluster_group', '');
SELECT pg_catalog.pg_extension_config_dump('dist_emaj_mark', '');
SELECT pg_catalog.pg_extension_config_dump('dist_emaj_mark_group', '');
SELECT pg_catalog.pg_extension_config_dump('dist_emaj_rlbk', '');
SELECT pg_catalog.pg_extension_config_dump('dist_emaj_rlbk_server', '');
-- Register dist_sequences values as candidate for pg_dump.
SELECT pg_catalog.pg_extension_config_dump('dist_emaj.dist_emaj_hist_hist_id_seq', '');
SELECT pg_catalog.pg_extension_config_dump('dist_emaj.dist_emaj_time_stamp_time_id_seq', '');
SELECT pg_catalog.pg_extension_config_dump('dist_emaj.dist_emaj_rlbk_rlbk_id_seq', '');

-- Set comments for all internal functions, by directly inserting a row in the pg_description table for all emaj functions that do not
-- have yet a recorded comment.
INSERT INTO pg_catalog.pg_description (objoid, classoid, objsubid, description)
  SELECT pg_proc.oid, pg_class.oid, 0 , 'Distributed E-Maj internal function'
    FROM pg_catalog.pg_proc
         CROSS JOIN pg_catalog.pg_class
    WHERE pg_class.relname = 'pg_proc'
      AND pg_proc.oid IN               -- list all emaj functions that do not have yet a comment in pg_description
        (SELECT pg_proc.oid
           FROM pg_catalog.pg_proc
                JOIN pg_catalog.pg_namespace ON (pg_namespace.oid = pronamespace)
                LEFT OUTER JOIN pg_catalog.pg_description ON (pg_description.objoid = pg_proc.oid
                                      AND classoid =
                                           (SELECT oid
                                              FROM pg_catalog.pg_class
                                              WHERE relname = 'pg_proc'
                                           )
                                      AND objsubid = 0)
           WHERE nspname = 'dist_emaj'
             AND (proname LIKE E'dist\\_emaj\\_%' OR proname LIKE E'\\_%')
             AND pg_description.description IS NULL
        );
-- Register the dist_emaj version into the version history table.
INSERT INTO dist_emaj.dist_emaj_version_hist (verh_version, verh_time_range)
  SELECT '<devel>', TSTZRANGE(clock_timestamp(), null, '[]');
-- Insert the completion event into the operations history.
INSERT INTO dist_emaj.dist_emaj_hist (hist_function, hist_object, hist_wording)
  VALUES ('DIST_EMAJ_INSTALL', 'dist_emaj <devel>', 'Initialisation completed');
