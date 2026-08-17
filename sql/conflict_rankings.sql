-- Rows outlive the conflict_instances row they came from, so they carry their own zone and time:
-- ranking runs over the last ten matches at a location, on the points earned in a single match.

DROP TABLE IF EXISTS `conflict_rankings`;
CREATE TABLE IF NOT EXISTS `conflict_rankings` (
    `instanceid` int(10)     unsigned NOT NULL,
    `charid`     int(10)     unsigned NOT NULL,
    `zoneid`     smallint(5) unsigned NOT NULL,
    `matchstart` int(10)     unsigned NOT NULL,           -- Vana'diel timestamp, orders the matches
    `points`     int(10)     unsigned NOT NULL DEFAULT 0, -- Ballista points earned in that match
    `job`        tinyint(3)  unsigned NOT NULL DEFAULT 0, -- Main job during the match
    `collected`  tinyint(1)  unsigned NOT NULL DEFAULT 0, -- Whether the assessment has been read
    PRIMARY KEY (`instanceid`, `charid`),
    KEY `zone_match` (`zoneid`, `matchstart`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
