# Battlefield Framework

A battlefield is any content where players are warped from an entrance point into a special area and receive a Battlefield effect. The goal with the Battlefield Framework is to simplify the creation of battlefield content. This new solution attempts to achieve this by reducing repeated code and unifying battlefield details into a single file. This document covers how to use the new battlefield framework as well as how to implement new battlefield content.

See the following for a [Full Battlefield Example](Full-Battlefield-Example).

## How to Use

The Battlefield Framework is based on the [Interaction Framework](Interaction-Framework-Documentation) and consequently having an understanding of that system is beneficial but not strictly necessary.

### Battlefield Setup

A battlefield is defined by using `Battlefield:new()` or one of the subclasses such as `BattlefieldMission:new()`. The majority of Battlefield details are provided at this time. For a full list of options see [Battlefield Parameters](#battlefield-parameters)

```lua
local content = Battlefield:new({
    zoneId           = xi.zone.BEARCLAW_PINNACLE,
    battlefieldId    = xi.battlefield.id.BROTHERS,
    maxPlayers       = 18,
    levelCap         = 75,
    timeLimit        = utils.minutes(30),
    index            = 3,
    entryNpc         = 'Wind_Pillar_4',
    exitNpc          = 'Wind_Pillar_Exit',
    requiredKeyItems = { xi.keyItem.ZEPHYR_FAN, message = ID.text.ZEPHYR_RIPS },
    grantXP          = 3500,
})
```

Once a Battlefield has been initially defined there are additional aspects that need to be provided.

### Battlefield Groups

Monsters in a battlefield are defined within groups. Each group is a set of monsters that share some commonality between them. A group can have some settings, modifiers and helpful callback handlers attached. For a full list of options see [Battlefield Group Parameters](#battlefield-group-parameters).

This example and the pathing one below are lifted from the legacy Limbus scripts in `docs/limbus/Apollyon/battlefields/se_apollyon.lua`.

```lua
content.groups =
{
    {
        mobs       = { 'Ghost_Clot' },
        stationary = true,
        mods =
        {
            [xi.mod.IMPACT_SDT] = 0,
            [xi.mod.HTH_SDT   ] = 0,
            [xi.mod.SLASH_SDT ] = 1250,
        },

        death = function(battlefield, mob, count)
            content:openDoor(mob:getBattlefield(), 1)
        end,
    },
}
```

Many Battlefields follow the same pattern with all monsters being spawned, stationary, superlink, and required to kill in order to spawn the Armoury Crate. This can easily be achieved with something such as the following:

```lua
content:addEssentialMobs({ 'Eldertaur', 'Mindertaur' })
```

### Battlefield Loot

Upon victory Battlefields spawn an Armoury Crate which will grant loot once opened. Loot is defined within groups where each group will only drop a single item unless a different `quantity` is specified. Each item has a `weight`, which only means something relative to the other weights in its group.

```lua
content.loot =
{
    {
        { itemId = xi.item.NONE,                     weight = 9750 },
        { itemId = xi.item.CLOUD_EVOKER,             weight =  250 },
    },

    {
        { itemId = xi.item.NONE,                     weight = 2500 },
        { itemId = xi.item.PIECE_OF_CASSIA_LUMBER,   weight = 2500 },
        { itemId = xi.item.SQUARE_OF_ELTORO_LEATHER, weight = 2500 },
        { itemId = xi.item.DRAGON_BONE,              weight = 2500 },
    },

    {
        quantity = 2,
        { itemId = xi.item.NONE,                     weight = 5500 },
        { itemId = xi.item.SCOUTERS_ROPE,            weight =  800 },
        { itemId = xi.item.HEDGEHOG_BOMB,            weight =  700 },
        { itemId = xi.item.MARTIAL_ANELACE,          weight =  800 },
        { itemId = xi.item.MARTIAL_LANCE,            weight =  800 },
        { itemId = xi.item.SCROLL_OF_RAISE_III,      weight = 1400 },
    },
}
```

### Monster Pathing

Some battlefields such as Limbus will have monsters patrolling a specific path rather than being stationary. In order to simplify this `paths` can be set which is a table of mob ID to a table of a path to patrol.

```lua
content.paths =
{
    [ID.mob.SE_TIEHOLTSODI] =
    {
        { x = 151.0, y = 0.0, z = -528.0,  wait = 10000 },
        { x = 147.0, y = 0.0, z = -468.05, wait = 10000 },
    },

    [ID.mob.SE_ADAMANTSHELL_OFFSET] =
    {
        { x = 138.0, y = -2.0,  z = -496.0, wait = 2500 },
        { x = 142.0, y = -1.11, z = -500.0, wait = 2500 },
    },

    -- ...
}
```

### Overriding Battlefield Logic

Nearly all of Battlefield logic can be overridden by providing a function override for the created content. For a full list of functions that can be overridden check out `scripts/globals/battlefield.lua`.

```lua
function content:checkRequirements(player, npc, isRegistrant, trade)
    -- Always allow entry into the battlefield
    return true
end
```

### Battlefield Parameters

- **zoneId**: Which zone this battlefield exists within (required)
- **battlefieldId**: Battlefield ID used in the database (required)
- **maxPlayers**: Maximum number of players allowed to enter (required)
- **timeLimit**: Time in seconds allotted to complete the battlefield before being ejected. (required)
- **index**: The index of the battlefield within the zone. This is used to communicate with the client on which menu item this battlefield is. (required)
- **levelCap**: Level cap imposed upon the battlefield. Defaults to 0 - no level cap. (optional)
- **area**: Some battlefields have multiple areas (Burning Circles) while others have fixed areas (Apollyon). Set to have a fixed area. (optional)
- **entryNpc**: The name of the NPC used for entering (required)
- **exitNpc**: The name of the NPC used for exiting (optional)
- **exitNpcs**: The names of the NPCs used for exiting (optional)
- **allowSubjob**: Determines if character subjobs are enabled or disabled upon entry. Defaults to true. (optional)
- **hasWipeGrace**: Grants players a 3 minute grace period on a full wipe before ejecting them. Defaults to true. (optional)
- **canLoseExp**: Determines if a character loses experience points upon death while inside the battlefield. Defaults to true. (optional)
- **cleanupDebuffs**: Removes negative status effects from players upon victory. Defaults to false. (optional)
- **showTimer**: Shows the time remaining in the battlefield in the player's UI. Defaults to true. (optional)
- **delayToExit**: Amount of time to wait before exiting the battlefield. Defaults to 5 seconds. (optional)
- **requiredItems**: Items required to be traded to enter the battlefield. Needs to be in the format of `{ itemid, quantity, useMessage = ID.text.*, wearMessage = ID.text.*, wornMessage = ID.text.* }`. (optional)
- **requiredKeyItems**: Key items required to be able to enter the battlefield. These are removed upon entry unless `keep = true`. Set `onlyInitiator = true` to only require them from the initiator. (optional)
- **title**: Title given to players upon victory (optional)
- **grantXP**: Amount of XP to grant upon victory (optional)
- **grantXPLockout**: If true, players can only receive `grantXP` once per day, resetting at JST midnight. (optional)
- **lossEventParams**: Parameters given to the loss event (32002). Defaults to none. (optional)

#### BattlefieldMission Parameters

- **missionArea**: The mission area this battlefield is associated with (optional)
- **mission**: The mission this battlefield is associated with (optional)
- **missionStatusArea**: The mission area to retrieve the mission status from. Will default to using the player's nation (optional)
- **missionStatus**: The optional extra status information xi.mission.status (optional)
- **requiredMissionStatus**: The required mission status to enter
- **skipMissionStatus**: The required mission status to skip the cutscene. Defaults to the required mission status.
- **canLoseExp**: As above, but defaults to false.

### Battlefield Group Parameters

- **mobs**: A list of monster names to associate with the group.
- **mobIds**: A list of mob IDs to associate with the group. In multiple arena battlefields such as BCNMs this needs to be a list of lists of mob IDs for each arena which is typically 3.
- **spawned**: Determines if monsters in this group will be spawned. Defaults to true.
- **superlink**: Determines if monsters in this group will superlink with each other. Defaults to false.
- **stationary**: Determines if monsters in this group will not roam. Defaults to true.
- **mods**: A table mapping `xi.mod.*` to a value which will be set for every monster in the group.
- **mobMods**: A table mapping `xi.mobMod.*` to a value which will be set for every monster in the group.
- **setup**: A callback `function(battlefield, mobs)` is called after initializing the group.
- **death**: A callback `function(battlefield, mob, count)` is called whenever a monster in the group dies. `count` is the number of the group's monsters that have died so far.
- **allDeath**: A callback `function(battlefield, mob)` is called whenever all monsters in the group die. The `mob` parameter is the last monster to have died.
- **randomDeath**: A callback `function(battlefield, mob)` called whenever a chosen random monster, determined during initialization, in the group dies.

## Battlefield Creation

Creating a new battlefield is much more streamlined than it was previously. Nearly all data pertaining to the battlefield is contained within the single battlefield script. New battlefields belong in `scripts/battlefields/<zone>/<name>.lua`. The only other place battlefield data exists is the `bcnm_records` table in `sql/bcnm_info.sql`, where the following values are needed: `bcnmId`, `zoneId`, `name`, `fastestName`, `fastestPartySize`, `fastestTime`. All other values are made redundant with this new solution.

Here is a checklist of things to do when creating a battlefield.

- Create a new script file within `scripts/battlefields/<zone>/<name>.lua`
- A new `xi.battlefield.id` entry needs to be made for the battlefield.
- Determine the proper Battlefield `index` which is used for communicating with the client.
- Properly [setup](#battlefield-setup) the battlefield with the appropriate [parameters](#battlefield-parameters).
- Provide the [monster groups](#battlefield-groups). Often this can be solved with something such as `content:addEssentialMobs({ 'Apis' })`.
- Implement the monster scripts if they need any unique behavior/logic that cannot be handled within monster groups. (not covered)
- Implement any missing mobskills (not covered)
- Provide a [loot table](#battlefield-loot) using `xi.item.*` and `weight`
- Be sure to include a `return content:register()` at the bottom of the script
- Ensure the following `ID.text.*` values are available in the zone's `scripts/zones/<zone>/IDs.lua`

```lua
PARTY_MEMBERS_ARE_ENGAGED
NO_BATTLEFIELD_ENTRY
TIME_IN_THE_BATTLEFIELD_IS_UP
PARTY_MEMBERS_HAVE_FALLEN
ENTERING_THE_BATTLEFIELD_FOR
MEMBERS_OF_YOUR_ALLIANCE
MEMBERS_OF_YOUR_PARTY
TIME_LIMIT_FOR_THIS_BATTLE_IS
THE_PARTY_WILL_BE_REMOVED
MEMBERS_LEVELS_ARE_RESTRICTED
GIL_OBTAINED
```

In order to simplify mission battlefields there is a `BattlefieldMission` subclass that has several [additional parameters](#battlefieldmission-parameters) that it can take.

## Unimplemented Battlefields

Every implemented battlefield uses this framework now. A few zones still have commented-out loot tables in `scripts/zones/<zone>/npcs/Armoury_Crate.lua` for battlefields nobody has written yet. Those use raw `droprate` values, so convert them to `weight` when you get round to it.

## Battlefield Modules

Writing lua modules to override behavior of battlefields is easily done with this new framework. Every battlefield can be accessed easily with the following method.

```lua
local content = xi.battlefield.contents[xi.battlefield.id.BROTHERS]
```

With the `content` object you can change any existing variables such as the `levelCap` or `grantXP`. Additionally it is possible to override behavior by following [Overriding Battlefield Logic](#overriding-battlefield-logic).

```lua
content.levelCap = 75

function content:checkRequirements(player, npc, isRegistrant, trade)
    -- Always allow entry into the battlefield
    return true
end
```
