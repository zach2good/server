-----------------------------------
-- Per-zone data for the Conflict (Ballista) system.
--
-- Ported from Eden. The NPC ids are this server's own, verified against npc_list; positions,
-- event ids and the message offsets are shared with Eden because both read the same client DAT.
--
-- Each zone's text table is filled from zones[zoneId].text.BALLISTA_OFFSET plus the offsets in
-- `messages` below. A zone whose IDs.lua does not define that offset yet gets an empty text
-- table, so a lookup returns nil instead of resolving to the wrong string.
-----------------------------------
require('scripts/globals/conflict/constants')

xi = xi or {}
xi.conflict = xi.conflict or {}

local messages =
{
    basic =
    {
        ACHIEVES_GATE_BREACH = 124,
        EQUIPMENT_CHANGE     = 130, -- p1 = 159 (penalized)
        NO_LONGER            = 204, -- p1 = 160 (preparing for battle)
    },
    system =
    {
        YOU_HAVE_TO_WAIT_LONGER = 38, -- p1 = <seconds>
        CANT_PERFORM_WITH_PETRA = 209,
        LOST_GATE_BREACH        = 212, -- when scoring
        RECOVERY_IN             = 213, -- p1 = <seconds>
        LOST_PETRAS             = 211,
    },
    text =
    {
        -- Pre-game
        BALLISTA_ANNOUNCEMENT      = 0,
        TAKE_PART                  = 1,
        NEXT_MATCH_INFO            = 5,
        NEXT_MATCH_ENTRY           = 6,
        NEXT_MATCH_START           = 7,
        MINIMUM_NOT_MET            = 8,
        GLOBAL_MATCH_DRAW          = 9,
        GLOBAL_MATCH_WIN           = 10,
        NOW_ACCEPTING_OFFSET       = 11,
        ENTRY_INFLUX_OFFSET        = 14,
        NOW_ACCEPTING_TEMP         = 17,
        MAX_ENTRIES_OFFSET         = 18,
        NOW_ACCEPTING_GUEST_OFFSET = 21,

        NO_LONGER_MEMBER    = 72,
        DISCHARGED          = 73,
        ENTRY_CANCELLATION  = 74,
        DISCHARGE_DENIED    = 75,
        SECONDS_UNTIL_START = 96,

        -- Line-up speech
        LINE_UP                  = 97,
        I_WILL_BE_SERVING        = 98,
        LEVEL_RESTRICTION        = 99,
        ALL_LINKSHELLS_UNEQUIPPED = 100,
        TODAYS_MATCH_WILL_PIT    = 101,
        IF_IS_VICTORIOUS         = 102,
        RULES_OF_BALLISTA        = 105,
        DO_NOT_FORGET            = 106,
        OATH_OF_FAIR_PLAY        = 107,
        READ_NATION_OATH         = 108,
        REMEMBER_BALLISTA_EXERCISE = 109,
        MAY_THE_BEST_SIDE_WIN    = 110,
        PLAYER_INVISIBLE_SNEAK   = 111,
        WE_HAVE_GATHERED         = 112,

        LET_THE_GAMES_BEGIN = 113,
        MATCH_ENDS_AT       = 117,
        MATCH_X_BEGINS_AT   = 118,
        MATCH_X_ENDS_AT     = 119,

        -- Game
        END_MATCH_DRAW_HS       = 120,
        END_MATCH_DRAW_DOMINANT = 121,
        IS_VICTORIOUS_OFFSET    = 125,
        FINAL_SCORE_WIN         = 130,
        FINAL_SCORE_WIN_DIO     = 131,
        FINAL_SCORE_LOSE        = 132,
        FINAL_SCORE_LOSE_DIO    = 133,
        FINAL_SCORE_DRAW        = 134,
        USE_QUARRY_FOR_PETRA    = 137,
        GET_GATE_BREACH         = 138,
        THROW_PETRAS_INTO_ROOK  = 139,
        ROOKS_MOVE_IN           = 140,
        ROOKS_MOVED             = 141,
        SCORE_PETRA             = 142,
        SCORE_PETRA_DIO         = 143,
        SCORE_PETRA_DIO_2       = 144,
        HIGHSCORER              = 145,
        HIGHSCORER_DIO          = 146,
        CURRENT_SCORES_DIO      = 147,
        SCORE_PETRA_HANDICAP    = 148,
        DISENGAGING_GATE_BREACH = 149,
        GATE_BREACH_WILL_LAST   = 150,
        DISENGAGE_GATE_BREACH_IN_X = 151,
        MUST_WAIT_SCORE         = 152,
        CANNOT_THROW_PETRA      = 153,
        CANNOT_CARRY_PETRA      = 154,
        POSSESS_NO_PETRA        = 155,
        OBTAIN_PETRA            = 156,
        FIND_AND_USE            = 157,
        FIND_NOTHING            = 158,
        CANNOT_QUARRY           = 159,
        ROOK_OPEN               = 160,
        ROOK_CLOSE              = 161,
        NEED_GATE_BREACH        = 162,
        ROOK_DESCRIPTION        = 163,
        UNABLE_TO_COMPLETE_THROW = 164,
        TIME_HAS_EXPIRED        = 166,

        MEMBERS_LINE_UP = 167,
        SALUTE          = 168,
        VICTORY_CRY     = 170,
        PONDER_DEFEAT   = 171,
        NO_VICTOR       = 172,
        REFLECT_STRATEGY = 173,
        BRING_US_TOGETHER = 174,
        DISMISSED       = 175,

        PARTING_GIFT_CANCELLED = 176,
        PARTING_GIFT_DRAW      = 177,
        PARTING_GIFT_WIN       = 178,

        ENTRY_PERIOD_ENDS_SOON = 183,
        YOUR_NATION_REWARD     = 186,
        DRAW_REWARD            = 190,
        CANCELLATION_REFUND    = 188,
        TODAYS_HIGHSCORER      = 199,
        LET_GAME_X_BEGIN       = 205,
        END_MATCH_SCORE_1P     = 206,
        END_MATCH_SCORE_1P_DIO = 207,
        END_MATCH_SCORE_2P     = 208,
        END_MATCH_SCORE_2P_DIO = 209,
        END_MATCH_SCORE_0P     = 210,
        MATCH_TOTAL            = 211,
        MATCH_TOTAL_DIO        = 212,
        FINAL_MATCH_TOTAL      = 213,
        GAIN_INVISIBLE         = 236,
        GAIN_SNEAK             = 237,
        CANT_CARRY_MORE_TEMP_ITEMS  = 243,
        CAN_ONLY_CARRY_ONE_TEMP_ITEM = 244,
        THROW_AWAY_PETRA       = 246,
        OBTAIN_TEMP_ITEM       = 249,
        THROW_AWAY_ITEM        = 250,
        REPLACE_ITEM           = 251,
        FIND_BUT_THROW         = 252,

        PRESENTED_WITH_TEMP_ITEMS = 254,
        A_NEW_PARTICIPANT         = 258,
    },
}

xi.conflict.messages = messages

local zoneInfos =
{
    [xi.zone.JUGNER_FOREST] =
    {
        events =
        {
            ROOK_THROW      = 21,
            HERALD          = 22,
            PURSUIVANT      = 23,
            LINE_UP         = 24,
            KEEP_TEMP_ITEM  = 25,
            KEEP_FIRST_PETRA = 28,
        },
        text   = {}, -- Filled automatically from zones[zoneId].text.BALLISTA_OFFSET
        herald =
        {
            pos = { x = 45.258, y = 0.260, z = -9.622, rot = 127 },
        },
        camps =
        {
            { 74.783, -0.685, -149.189 },
            { 86.707, 0.527, 143.952 },
        },
        pursuivants =
        {
            names =
            {
                'San_dOrian_Pursuivant',
                'Bastokan_Pursuivant',
                'Windurstian_Pursuivant',
            },
            pos =
            {
                { 74.883, -0.25, -153.554, 184 },
                { 84.071, 0.555, 146.283, 254 },
            },
        },
        rooks =
        {
            {
                pos =
                {
                    { 102.672, -2.505, -11.482, 160 },
                    { 85.240, -0.438, -80.676, 192 },
                    { 134.478, 0.180, 42.012, 96 },
                    { 152.689, -0.104, 6.770, 128 },
                    { 149.503, -1.0, -42.807, 192 },
                    { 120.310, -0.425, -114.185, 192 },
                },
            },
            {
                pos =
                {
                    { 27.674, 0.123, -5.063, 192 },
                    { -88.046, -0.94, 72.148, 0 },
                    { 41.459, -0.131, 53.602, 64 },
                    { -45.412, -0.732, 72.284, 0 },
                    { -35.989, -0.568, 127.975, 64 },
                    { -15.477, 0.248, 36.693, 192 },
                },
            },
            { pos = { { 34.537, -0.383, 229.024, 0 } } },
            { pos = { { 275.623, -0.55, 79.153, 192 } } },
            { pos = { { 277.566, 0.0, 223.837, 192 } } },
            { pos = { { -119.845, -0.5, -163.392, 128 } } },
            { pos = { { -186.314, -0.55, 107.873, 128 } } },
        },
    },

    [xi.zone.MERIPHATAUD_MOUNTAINS] =
    {
        events =
        {
            ROOK_THROW      = 36,
            HERALD          = 37,
            PURSUIVANT      = 38,
            LINE_UP         = 39,
            KEEP_TEMP_ITEM  = 40,
            KEEP_FIRST_PETRA = 43,
        },
        text   = {},
        herald =
        {
            pos = { x = -46.60, y = -15.98, z = 203.07, rot = 61 },
        },
        camps =
        {
            { 97.159, -15.789, 329.944 },  -- North
            { -305.091, 7.118, -57.820 },  -- South
        },
        pursuivants =
        {
            names =
            {
                'San_dOrian_Pursuivant',
                'Bastokan_Pursuivant',
                'Windurstian_Pursuivant',
            },
            pos =
            {
                { 94.924, -15.708, 322.449, 209 },
                { -301.189, 6.967, -60.096, 157 },
            },
        },
        rooks =
        {
            {
                pos =
                {
                    { 11.470, -22.724, 232.266, 83 },
                    { -180.720, -15.877, 127.210, 110 },
                    { -83.01, -15.27, 175.37, 105 },
                    { -158.90, 8.00, 39.37, 239 },
                    { -244.64, 4.63, 57.79, 131 },
                    { -38.70, -9.23, 129.62, 167 },
                },
            },
            {
                pos =
                {
                    { -83.621, 0.94, 18.827, 149 },
                    { 39.817, -7.999, 116.8, 153 },
                    { -98.124, 3.062, 91.283, 214 },
                    { -151.541, 7.615, -11.38, 174 },
                },
            },
            { pos = { { -175.812, 8.278, -84.393, 100 } } },
            { pos = { { 213.932, -16.5, 153.012, 0 } } },
            { pos = { { 59.47, -12.0, 315.004, 192 } } },
            { pos = { { -324.186, -0.5, -202.569, 224 } } },
            { pos = { { 277.964, -9.0, -85.711, 192 } } },
        },
    },

    [xi.zone.PASHHOW_MARSHLANDS] =
    {
        events =
        {
            ROOK_THROW      = 17,
            HERALD          = 18,
            PURSUIVANT      = 19,
            LINE_UP         = 20,
            KEEP_TEMP_ITEM  = 23,
            KEEP_FIRST_PETRA = 26,
        },
        text   = {},
        herald =
        {
            pos = { x = 117.104, y = 24.648, z = 156.788, rot = 37 },
        },
        camps =
        {
            { 103.76, 25.00, 402.11 },   -- North
            { 266.888, 25.2, -48.26 },   -- South
        },
        pursuivants =
        {
            names =
            {
                'San_dOrian_Pursuivant',
                'Bastokan_Pursuivant',
                'Windurstian_Pursuivant',
            },
            pos =
            {
                { 104.622, 24.999, 406.586, 69 },
                { 270.282, 24.208, -54.678, 184 },
            },
        },
        rooks =
        {
            {
                pos =
                {
                    { 187.257, 24.835, 114.832, 119 },
                    { 208.23, 24.338, 51.774, 127 },
                    { 140.041, 25.189, 159.466, 67 },
                    { 87.994, 24.999, 282.09, 123 },
                    { 107.043, 24.999, 210.024, 0 },
                    { 218.889, 24.0, 193.066, 0 },
                },
            },
            {
                pos =
                {
                    { 105.248, 24.999, 100.926, 113 },
                    { 23.655, 24.999, 286.098, 62 },
                    { 44.866, 24.999, 163.547, 201 },
                    { 11.898, 24.999, 59.33, 242 },
                    { 147.801, 24.648, 31.942, 249 },
                },
            },
            { pos = { { 169.012, 24.5, 384.709, 32 } } },
            { pos = { { 318.294, 24.0, -1.061, 0 } } },
            { pos = { { 256.28, 24.5, -224.734, 128 } } },
            { pos = { { -3.443, 24.5, 60.515, 0 } } },
            { pos = { { -179.502, 24.0, -225.535, 96 } } },
        },
    },
}

xi.conflict.zoneInfo = xi.conflict.zoneInfo or {}

local function setupZoneInfo(zoneId)
    local zoneInfo = zoneInfos[zoneId]
    if zoneInfo == nil then
        return nil
    end

    -- Resolve the per-zone message offsets into absolute string ids. A zone whose IDs.lua has no
    -- BALLISTA_OFFSET yet simply gets an empty text table, so lookups return nil rather than
    -- resolving to a wrong string.
    local zoneIDs = zones[zoneId]
    if
        zoneIDs and
        zoneIDs.text and
        zoneIDs.text.BALLISTA_OFFSET
    then
        for name, offset in pairs(messages.text) do
            zoneInfo.text[name] = zoneIDs.text.BALLISTA_OFFSET + offset
        end
    end

    xi.conflict.zoneInfo[zoneId] = zoneInfo
    return xi.conflict.zoneInfo[zoneId]
end

function xi.conflict.getZoneInfo(zoneId)
    return xi.conflict.zoneInfo[zoneId] or setupZoneInfo(zoneId)
end

function xi.conflict.getZoneInfoForEntity(entity)
    return xi.conflict.getZoneInfo(entity:getZoneID())
end

function xi.conflict.getZoneInfoForConflict(conflict)
    return xi.conflict.getZoneInfo(conflict:getZoneID())
end

-- The Ballista NPCs are resolved by name, never by id. npc_list ordering is not a contract, so an
-- insertion anywhere above these rows would silently repoint every lookup.
--
-- The rooks share one name and are returned in spawn order, which is the order the per-rook
-- position tables above are written in, so the index is the rook's identity.
function xi.conflict.getRookEntities(zone)
    if zone == nil then
        return {}
    end

    return zone:queryEntitiesByName('Rook')
end

function xi.conflict.getHeraldEntity(zone)
    if zone == nil then
        return nil
    end

    return zone:queryEntitiesByName('Herald')[1]
end

-- The Pursuivant for one nation, indexed the way the scripts count nations: 0 San d'Oria,
-- 1 Bastok, 2 Windurst. Indexed directly rather than through the list above, so a Pursuivant
-- missing from a zone cannot shift the others.
function xi.conflict.getPursuivantEntity(zone, nationIndex)
    local zoneInfo = xi.conflict.getZoneInfo(zone:getID())
    if
        zoneInfo == nil or
        zoneInfo.pursuivants == nil
    then
        return nil
    end

    local name = zoneInfo.pursuivants.names[nationIndex + 1]
    if name == nil then
        return nil
    end

    return zone:queryEntitiesByName(name)[1]
end

-- Which of the three Pursuivants this is, counted the way the scripts count nations.
function xi.conflict.getPursuivantIndex(zoneInfo, npc)
    if
        zoneInfo == nil or
        zoneInfo.pursuivants == nil
    then
        return 0
    end

    for index, name in ipairs(zoneInfo.pursuivants.names) do
        if npc:getName() == name then
            return index - 1
        end
    end

    return 0
end

function xi.conflict.getPursuivantEntities(zone)
    local zoneInfo = xi.conflict.getZoneInfo(zone:getID())
    if
        zoneInfo == nil or
        zoneInfo.pursuivants == nil
    then
        return {}
    end

    local pursuivants = {}
    for _, name in ipairs(zoneInfo.pursuivants.names) do
        local found = zone:queryEntitiesByName(name)[1]
        if found ~= nil then
            table.insert(pursuivants, found)
        end
    end

    return pursuivants
end
