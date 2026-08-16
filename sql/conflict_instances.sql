DROP TABLE IF EXISTS `conflict_instances`;
CREATE TABLE IF NOT EXISTS `conflict_instances` (
    `instanceid`     int(10)      unsigned NOT NULL AUTO_INCREMENT,
    `zoneid`         smallint(5)  unsigned NOT NULL,
    `type`           tinyint(3)   unsigned NOT NULL,           -- xi.conflictType
    `start`          int(10)      unsigned NOT NULL,           -- Vana'diel timestamp of the match start
    `length`         int(10)      unsigned NOT NULL,           -- Match length in Vana'diel minutes
    `state`          tinyint(3)   unsigned NOT NULL DEFAULT 0, -- xi.conflictState
    `phase`          tinyint(3)   unsigned NOT NULL DEFAULT 0,
    `max_team_size`  tinyint(3)   unsigned NOT NULL DEFAULT 0,
    `rook_count`     tinyint(3)   unsigned NOT NULL DEFAULT 0,
    `combat_enabled` tinyint(1)   unsigned NOT NULL DEFAULT 0,
    `rounds_team1`   tinyint(3)   unsigned NOT NULL DEFAULT 0,
    `rounds_team2`   tinyint(3)   unsigned NOT NULL DEFAULT 0,
    PRIMARY KEY (`instanceid`)
) ENGINE=InnoDB AUTO_INCREMENT=100 DEFAULT CHARSET=utf8;
