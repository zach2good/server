import mariadb


def migration_name():
    return "Add the Conflict (Ballista) tables"


def check_preconditions(cur):
    return


def needs_to_run(cur):
    for table in ("conflict_instances", "conflict_entries", "conflict_rankings"):
        cur.execute("SHOW TABLES LIKE '{}'".format(table))
        if not cur.fetchone():
            return True

    return False


# Frozen copies of sql/conflict_*.sql as of this migration. A later schema change gets its own
# migration rather than editing these, so the two are expected to diverge over time.
#
# conflict_instances comes first: conflict_entries has a foreign key into it.
TABLES = [
    """
    CREATE TABLE IF NOT EXISTS `conflict_instances` (
        `instanceid`     int(10)      unsigned NOT NULL AUTO_INCREMENT,
        `zoneid`         smallint(5)  unsigned NOT NULL,
        `type`           tinyint(3)   unsigned NOT NULL,
        `start`          int(10)      unsigned NOT NULL,
        `length`         int(10)      unsigned NOT NULL,
        `state`          tinyint(3)   unsigned NOT NULL DEFAULT 0,
        `phase`          tinyint(3)   unsigned NOT NULL DEFAULT 0,
        `max_team_size`  tinyint(3)   unsigned NOT NULL DEFAULT 0,
        `rook_count`     tinyint(3)   unsigned NOT NULL DEFAULT 0,
        `combat_enabled` tinyint(1)   unsigned NOT NULL DEFAULT 0,
        `gil_on_herald`  int(10)      unsigned NOT NULL DEFAULT 0,
        `rounds_team1`   tinyint(3)   unsigned NOT NULL DEFAULT 0,
        `rounds_team2`   tinyint(3)   unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY (`instanceid`)
    ) ENGINE=InnoDB AUTO_INCREMENT=100 DEFAULT CHARSET=utf8;
    """,
    """
    CREATE TABLE IF NOT EXISTS `conflict_entries` (
        `instanceid`  int(10)     unsigned NOT NULL,
        `charid`      int(10)     unsigned NOT NULL,
        `allegiance`  tinyint(3)  unsigned NOT NULL DEFAULT 0,
        `type`        tinyint(3)  unsigned NOT NULL DEFAULT 0,
        `job`         tinyint(3)  unsigned NOT NULL DEFAULT 0,
        `points`      int(10)     unsigned NOT NULL DEFAULT 0,
        `score`       smallint(5) unsigned NOT NULL DEFAULT 0,
        `total_score` smallint(5) unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY (`instanceid`, `charid`),
        CONSTRAINT `fk_conflict_entries_instanceid` FOREIGN KEY (`instanceid`) REFERENCES `conflict_instances` (`instanceid`) ON DELETE CASCADE ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    """,
    """
    CREATE TABLE IF NOT EXISTS `conflict_rankings` (
        `instanceid` int(10)     unsigned NOT NULL,
        `charid`     int(10)     unsigned NOT NULL,
        `zoneid`     smallint(5) unsigned NOT NULL,
        `matchstart` int(10)     unsigned NOT NULL,
        `points`     int(10)     unsigned NOT NULL DEFAULT 0,
        `job`        tinyint(3)  unsigned NOT NULL DEFAULT 0,
        `collected`  tinyint(1)  unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY (`instanceid`, `charid`),
        KEY `zone_match` (`zoneid`, `matchstart`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    """,
]


def migrate(cur, db):
    try:
        for statement in TABLES:
            cur.execute(statement)

        db.commit()
    except mariadb.Error as err:
        print("Something went wrong: {}".format(err))
