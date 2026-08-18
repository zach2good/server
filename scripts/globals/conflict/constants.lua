xi = xi or {}
xi.conflict = xi.conflict or {}

-- Maps the sum of the two competing nations (xi.nation: San d'Oria 0, Bastok 1, Windurst 2) to the
-- message offset used for nation-specific Herald lines. Each sum is unique because the three
-- pairings add to 1, 2 and 3. The offsets are read from the Jugner strings against BALLISTA_OFFSET
-- 7253: 7255 "Bastok against San d'Oria", 7256 "Bastok against Windurst", 7257 "Windurst against
-- San d'Oria".
xi.conflict.teamsOffsetLookup =
{
    [1] = 2, -- San d'Oria (0) + Bastok (1)
    [3] = 3, -- Bastok (1) + Windurst (2)
    [2] = 4, -- San d'Oria (0) + Windurst (2)
}
