DROP TABLE IF EXISTS `conflict_entries`;
CREATE TABLE IF NOT EXISTS `conflict_entries` (
    `instanceid` int(10)     unsigned NOT NULL,
    `charid`     int(10)     unsigned NOT NULL,
    `allegiance` tinyint(3)  unsigned NOT NULL DEFAULT 0, -- xi.allegiance, 2 to 6
    `type`       tinyint(3)  unsigned NOT NULL DEFAULT 0, -- ConflictEntryType
    `job`        tinyint(3)  unsigned NOT NULL DEFAULT 0, -- Main job when the character entered
    `points`     int(10)     unsigned NOT NULL DEFAULT 0, -- Ballista points earned, capped by CAP_CURRENCY_BALLISTA
    `score`      smallint(5) unsigned NOT NULL DEFAULT 0, -- Petras scored this round, reset between rounds
    `total_score` smallint(5) unsigned NOT NULL DEFAULT 0, -- Petras scored across the whole match
    PRIMARY KEY (`instanceid`, `charid`),
    CONSTRAINT `fk_conflict_entries_instanceid` FOREIGN KEY (`instanceid`) REFERENCES `conflict_instances` (`instanceid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
