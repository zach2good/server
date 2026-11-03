# Retail Packet Captures Format Guide

Captures usually arrive as a `.zip`. Unpacked, there's a folder named after the content, then a folder for the character, then the capture data.

## Folder Structure

`[Title Folder] / [Character Name] / [Addon Folders]`

### The addon folders

Each capture addon writes its own folder inside the character folder. Names and capitalisation vary a bit between logger versions.

#### 1. `eventview`/`EventView`

Cutscenes and events.

- `eventview/simple` (or `.log` files straight under the character folder): the one you'll use most. Simplified event data, usually one `.log` per zone. Use it to fill in mission and quest events when writing or migrating Interaction Framework (IF) scripts.
- `eventview/raw`: the same events in full, for when you need to dig deeper.

#### 2. `npclogger`/`NPCLogger`

NPC locations, behaviour and properties.

- `database` folder or `.db` files: depending on the capture, either a `database` folder with a `.lua` file per zone, or `.db` SQLite files directly in `NPCLogger`. Use it to add or update NPC details, positions and parameters in `data/zones/<zone>/npcs.yaml`.
- Other folders (`logs`, `tables`, `widescan`) hold more raw or parsed NPC data. Handy as a second reference.

#### 3. `caplog`/`CapLog`

The capturer's chat window, as `*.txt` or `*.log` files. Read it for notes the capturer left and for what the NPCs said. It's often the quickest way to work out which event is playing.

#### 4. `packetviewer`/`PacketLogger`

Raw packets. There are `incoming` and `outgoing` folders split by packet id (`0x034.log`, `0x0D3.log`), plus `full.log`, `incoming.log` and `outgoing.log`. Use it when you need the raw data to make sense of odd or unmapped client behaviour.

#### 5. Other folders

- `ActionView`: actions and events. Sometimes has its own `simple` folder, like `EventView`.
- `PathLog`: `.csv` files of PC and NPC movement. Good for recreating NPC patrols.
- `ShopStock`/`GuildStock`: `.db` files (`BuyList.db`, `SellList.db`) of shop and guild stock.
- `KITrack`: key item acquisitions.
- `HPTrack`: home point unlocks and interactions.
- `AttackDelay`: attack speed and delay logs.

## General Workflow

1. Read `caplog` to follow the capture, with the player's notes and the NPC dialogue for context.
2. Use the `eventview` simple logs to map out the steps, parameters and event ids for your IF script.
3. New NPCs, or existing ones missing data? Build their `npcs.yaml` entries from `npclogger`.
4. Only fall back to `packetviewer`/`PacketLogger` or `eventview/raw` when the simple logs don't explain a low-level interaction.
