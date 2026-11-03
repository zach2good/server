# Interaction Framework Migration & Verification Guide

## 1. Overview

We're moving old-style NPC scripts, with quest logic hardcoded in `onTrigger`, over to the **Interaction Framework (IF)**. Quest and mission logic ends up in one place, it's easier to read, and the NPC scripts shrink to stubs.

## 2. Where to find things

### Retail captures

Captures give you the exact event order, NPC positions and parameters. Use them. The [Retail Packet Captures Format Guide](retail-packet-captures.md) has the folder layout.

- `caplog` (chat logs): start here for the quest flow. The capturer's notes and the NPC dialogue tell you which event belongs to which step.
- `eventview/simple` (simplified events): maps packets straight to IF calls.
  - `CEventPacket` (`0x032`/`0x034`): `EventPara` is the event id. That's your `quest:progressEvent(id)` or `quest:event(id)`.
  - `CMessageSpecialPacket` (`0x02A`): `MessageNumber` is the text id. That's `quest:messageSpecial(id)`, often for system messages or odd bits of dialogue like checking a door or a sarcophagus.
  - `CMessageNamePacket` (`0x027`): `MesNum` is the normal chat dialogue id. Some loggers need a `& 0xFFFF` on it. It maps to `quest:messageName(id)` or a normal text lookup.
- `npclogger/database` (NPC data): the `.lua` files here give you NPC coordinates and properties for `data/zones/<zone>/npcs.yaml`, and what you need for the NPC script header.
- `packetviewer` (raw packets): for interactions `eventview` doesn't fully cover. Shows what the client sent and received.

### Game data

- NPC ids and positions: `data/zones/<zone>/npcs.yaml`. NPCs are keyed by their 8-digit id, with the position in `at: [x, y, z, rotation]`. Instanced zones still use `sql/npc_list.sql`.
- Item ids: `sql/item_basic.sql`. If the Lua enum is missing an item, take the id from here and either use it directly or add it to the enum.

### Lua enums

- Quest ids: `scripts/globals/quests.lua`.
- Mission ids: `scripts/globals/missions.lua`.
- Items: `scripts/enum/item.lua`.
- Key items: `data/enums/key_item.yaml`.
- Zones: `data/enums/zone.yaml` (generates `xi.zone`).

### Retail event dumps

`sruon/FFXI-EventsDump` is the source of truth for retail event ids and dialogue.

- If it's cloned next to this repo, look in `../FFXI-EventsDump/dumps/<Zone_Name>`.
- If not, fetch the raw markdown files from GitHub.
- Each zone folder has a `strings.txt`. Match the decimal or hex ids in the `.md` files against it to check the dialogue.

## 3. Migrating a quest

### Step 1: Research the wikis

1. Check the [Japanese wiki](https://wiki.ffo.jp), [BG-Wiki](https://www.bg-wiki.com) and [FFXIclopedia](https://ffxiclopedia.fandom.com). When they disagree, trust them in that order and say so.
2. Compare the steps, item requirements and what the NPCs say.
3. Look out for "wait until Japanese midnight" and "zone out and back in" requirements.

### Step 2: Write the IF file

Create it in `scripts/quests/`, `scripts/missions/` or `scripts/quests/hiddenQuests/`.

Pick the container class:

- Quests: `local quest = Quest:new(xi.questLog.LOG_NAME, xi.quest.id.area.QUEST_NAME)`
- Missions: `local mission = Mission:new(xi.mission.log_id.LOG_NAME, xi.mission.id.area.MISSION_NAME)`
- Hidden quests: `local quest = HiddenQuest:new('UniqueStringName')`, for content that isn't in a log, like Trust acquisitions or Mog House expansions.

They differ in two ways:

- Each class prefixes its variables (`Quest[1][2]Prog`, `Mission[4][10]Prog`, `UniqueStringNameProg`), so different kinds of content can't collide.
- `Quest` and `Mission` check their own log and status when deciding whether to run a section's `check` function. `HiddenQuest` relies entirely on your own variables.

The basic shape:

```lua
local quest = Quest:new(xi.questLog.LOG_NAME, xi.quest.id.area.QUEST_NAME)
quest.reward =
{
    fame = 30,
    gil  = 1000,
}

quest.sections =
{
    {
        check = function(player, status, vars)
            return status == xi.questStatus.QUEST_AVAILABLE
        end,

        [xi.zone.ZONE_ID] =
        {
            ['NPC_Name'] = quest:progressEvent(100),
        },
    },
}
```

- Trades: use `onTrade` inside the NPC block, always with `npcUtil.tradeHasExactly` or `npcUtil.tradeHas`.
- Zoning: `quest:setMustZone(player)` and `quest:getMustZone(player)`.
- Cutscenes you trigger by walking up to something: `onTriggerAreaEnter`.

### Step 3: Clean up the NPC script

1. Fix the header. See the [NPC Script Header Guide](npc-header-guide.md).
2. Strip out every quest `if`/`else` block.
3. If nothing but quest logic was there, cut it down to:

```lua
---@type TNpcEntity
local entity = {}

entity.onTrade = function(player, npc, trade)
end

entity.onTrigger = function(player, npc)
end

return entity
```

4. Keep patrol logic (`onSpawn`), Trust logic and any complex quests that haven't been migrated yet.

### Step 4: Default actions

If the NPC has a single default interaction (say `player:startEvent(200)`), move it to `scripts/zones/<Zone>/DefaultActions.lua`:

```lua
['NPC_Name'] = { event = 200 },
```

### Step 5: Mark the quest

Tag the quest in `scripts/globals/quests.lua` as a partial conversion:

```lua
QUEST_NAME = 123, -- + Partial conversion. TODO: This needs completing with retail caps
```

## 4. Other techniques

- `event` vs `progressEvent`: in `scripts/globals/interaction/container.lua`, `quest:progressEvent(id)` is just sugar for a base Event with a priority modifier (`Event:new(id):progress()`). Same for `quest:cutscene(id)` and `quest:replaceEvent(id)`. Use `progressEvent` for real quest progress so it beats the NPC's default behaviour.
- Multi-choice menus: `onEventUpdate`.
- Bitmasks: `quest:setVarBit(player, 'Prog', bit)` and `quest:isVarBitsSet(player, 'Prog', bit)`.
- Variables: prefer `quest:getVar` to `player:getCharVar`, so the framework manages them.
- Daily repeats: `quest:setTimedVar(player, 'Timer', JstMidnight())`.

## 5. Don't trust the old script

**Never assume existing logic is correct.** Old scripts often skip reminder dialogue and post-quest flavour text. Check `sruon/FFXI-EventsDump` for every NPC in the quest, so you cover all of the dialogue.
