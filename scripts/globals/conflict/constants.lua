xi = xi or {}
xi.conflict = xi.conflict or {}

-- Maps the sum of the two competing nations (1 = San d'Oria, 2 = Bastok,
-- 3 = Windurst) to the message offset used for nation-specific Herald lines.
xi.conflict.teamsOffsetLookup =
{
    [1] = 2, -- (would be San d'Oria + ?, kept from retail data)
    [3] = 3, -- San d'Oria (1) + Bastok (2)
    [2] = 4,
}
