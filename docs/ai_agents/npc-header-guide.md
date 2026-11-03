# NPC Script Header Guide

How to format the header of an NPC script, and where to find what goes in it.

## Header Format

Most NPC scripts carry only the zone and NPC name:

```lua
-----------------------------------
-- Area: Windurst Walls
--  NPC: Ambrosius
-----------------------------------
```

You may add the zone id and a `!pos` line, which a GM can paste to go to the NPC:

```lua
-----------------------------------
-- Area: Windurst Walls (239)
--  NPC: Ambrosius
-- !pos 65.175 -2.499 -63.231 239
-----------------------------------
```

The dividers are exactly 35 dashes. The Lua style check rejects any other length.

## Finding the Information

### Zone name and id

* **Zone name**: the folder name with spaces, e.g. `scripts/zones/Windurst_Walls/` is `Windurst Walls`.
* **Zone id**: in `data/enums/zone.yaml`, e.g. `windurst_walls: 239`. The Lua enum `xi.zone.WINDURST_WALLS` is generated from it.

### NPC name and position

NPCs live in `data/zones/<zone>/npcs.yaml`, keyed by NPC id:

```yaml
  17756197:
    script:       Ambrosius
    display_name: Ambrosius
    at:           [65.175, -2.499, -63.231, 76]
```

* Use `display_name` in the header. It's the name players see.
* `at` is `[x, y, z, rotation]`. The `!pos` line uses the first three, then the zone id.

Instanced and dynamic zones (Nyzul Isle, Ilrusi Atoll and similar) still keep their NPCs in `sql/npc_list.sql`.

Positions from a retail capture beat the ones in the repo. If they disagree, say so.

## Notes

A header may hold a `Notes:` line for context the code can't show. Never delete existing notes. Update them if your change alters what the NPC does.

```lua
-----------------------------------
-- Area: Windurst Walls (239)
--  NPC: Ambrosius
-- Notes: Part of "Crying Over Onions".
-- !pos 65.175 -2.499 -63.231 239
-----------------------------------
```
