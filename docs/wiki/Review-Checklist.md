# Review Checklist

These are the points maintainers raise most often in review. Check your change against them before you open a PR. CI catches formatting and the [Development Guide](Development-Guide) covers style. This page covers what only a reviewer catches.

- [Before review](#before-review)
- [Sources and values](#sources-and-values)
- [Where code belongs](#where-code-belongs)
- [Lua](#lua)
- [Quests and NPCs](#quests-and-npcs)
- [Mobs](#mobs)
- [C++](#c)
- [SQL and data](#sql-and-data)
- [Modules](#modules)
- [Tests](#tests)
- [Comments](#comments)

## Before review

- CI is green. PRs that fail the sanity checks don't get read.
- Rebase on the latest `base` whenever there are conflicts.
- Amend and force-push to address review. Don't add "address comments" commits, close and reopen the PR, or stack PRs on unmerged work.
- One commit per logical change. A commit that bundles unrelated edits gets sent back.
- Fill in the PR template and tick its boxes. Don't delete it.
- Say what you tested and how. Untested PRs go back to draft.
- Leave review conversations for the reviewer to resolve. You don't need to reply to every comment, or re-request review after every push.
- Keep to the scope of the PR. Anything big should start as a draft.
- Report security problems to a maintainer privately, never in a public issue or PR.

## Sources and values

- Every behaviour change needs a source: a retail capture, an event dump, a timestamped video or the Japanese wiki. Expect "Where did you get this from?" for any number without one.
- A wiki alone is never enough for a number. Earlier LSB or DarkStar code isn't evidence either.
- Credit the capture if it isn't yours.
- Mark a guessed value with `TODO: Capture needed`: `-- TODO: Capture needed` in Lua and SQL, `# TODO: Capture needed` in YAML. Older rows use `Capture needed` without the `TODO:`, so search for `Capture needed`.
- Don't assume LSB is wrong because your source disagrees. Find out why.
- Use captured positions verbatim. Never round them.
- When the source is unclear, pick the value that is harder on players: shorter buffs, smaller bonuses, the fixed value over a wide random range.
- Check the units on both sides of any time arithmetic. The code mixes seconds, milliseconds, Vana'diel time and ticks.

## Where code belongs

- Mob behaviour goes in the mob script or a mixin, never in a mob skill script.
- Quest and mission logic goes in `scripts/quests` or `scripts/missions`, never in NPC, mob or zone scripts.
- Zone scripts and `IDs.lua` hold no logic. Battlefield mechanics go in the battlefield script.
- Shared logic goes in a global that everyone calls. One entity's script doesn't reach into another's.
- Entity iteration and target selection belong in C++, not Lua.
- Bindings go in `src/map/lua`. They look things up and prepare values. They don't change state.
- Don't add a binding, setting or enum entry without a use in the same PR.
- A helper used by one system lives in that system's file. `scripts/utils` is for code many systems use.
- `scripts/globals/magic.lua` takes removals only, no additions.
- Custom or server-specific features belong in a [module](Module-Guide), not upstream.
- Delete a setting that stood in for a missing mechanic once the mechanic exists, with its uses and tests.

## Lua

Functions:

- No one-line helper functions. Inline them at each call site.
- No function used in exactly one place. Put the logic where it's used.
- A helper is fine when it hides real complexity, such as bit packing or a loop.
- No functions defined inside functions.
- A function used only in its own file is a `local function`.
- A function returns one type. Use a sentinel such as `xi.keyItem.NONE`, not a value-or-nil.
- No naked boolean parameters. Use an enum or a table with named fields.
- Delete empty callbacks and files with no logic, except doors.

Conditions:

- Return early instead of nesting. Put the cheapest guard first, before fetching values it doesn't need.
- Write `if not mob then`, not `== nil`.
- Don't nil-check values that always exist. Unset vars are `0`, not `nil`.
- Drop a guard when the next expression already fails for that case. `math.randomInt(1, 100) <= chance` needs no `chance > 0` in front of it.
- Check settings explicitly (`== 1`, `== true`). `0` is truthy in Lua.
- `cond and a or b` is the ternary. It only works when `a` can't be `false` or `nil`.

Values:

- Use enums, never magic numbers: `xi.item`, `xi.keyItem`, `xi.zone`, `xi.effect`, `xi.mod`, `xi.element`, and message ids from `IDs.lua`.
- Use a table instead of an `if`/`elseif` chain. If the file already has a table, extend it. Define tables at file scope.
- Store a call you repeat in a function (`getID()`, `getZoneID()`) in a local.
- Don't make a local for a value used once. Use it inline.
- Use `string.format`, not `..`.
- Use `math.random(min, max)` with both bounds, or `math.randomInt`. Never bare `math.random()`.
- Use `utils.clamp`, `utils.randomEntry` and `GetSystemTime()` instead of hand-rolled versions or `os.time()`.
- `math.floor` any value that must be an integer.
- No unneeded parentheses and no `.0` float literals.
- Names say what they hold: `currentTime`, not `now`. Use `itemId` and `zoneId` when the value is an id.

## Quests and NPCs

- `quest:event()` for filler and reminder events. `quest:progressEvent()` only when the event changes quest state.
- `replaceDefault()` only when the event really replaces the zone default. Otherwise use `DefaultActions.lua`.
- Every section checks the quest status. Sections must be mutually exclusive.
- Check that the player has the currency, or a free inventory slot, before the cutscene.
- Use `npcUtil.tradeHasExactly()` for trades that consume items. Confirm the trade in `onEventFinish`.
- `onTrade` comes before `onTrigger`. `onEventFinish` cases go in event id order.
- `IDs.lua` text comments are exact copies of the client string. Entries are in alphabetical order.
- Find entities by name or position, not by hard-coded id. Ids shift with retail updates.

## Mobs

- Keep `onMobFight` and `onMobRoam` small. They run every tick.
- Set immunities and resistances in `onMobInitialize`, and per-spawn values in `onMobSpawn`. Use `setMod` over `addMod` on spawn, since `addMod` stacks across spawns.
- Put modifiers on the effect (`effect:addMod`), so nothing needs cleaning up when the effect wears off.
- `onMobDeath` runs once per player on the enmity list. Guard one-off work with `if optParams.isKiller or optParams.noKiller then`. `player` can be `nil` there.
- Prefer the `entity.onMob*` functions to listeners. A listener needs a specific name and must use the mob it's passed, not a captured one.
- Order callbacks: `onMobInitialize`, `onMobSpawn`, `onMobRoam`, `onMobEngage`, `onMobFight`, `onMobDisengage`, then death and despawn.
- No wide random ranges on mob skill effect durations. Use the balanced value and let resistances do the rest.

## C++

- No raw owning pointers and no raw `new`. Use `Box` (`std::unique_ptr`), or a value member.
- `dynamic_cast` entity pointers and check the result straight away.
- `Maybe<T>` for a value that might not exist. Name it `maybeThing`.
- `enum class` over raw ints and naked bools. For a yes/no parameter, use `Flag<Tag>` so every call site is explicit.
- Watch signedness and width across a getter, setter and member. An unsigned value is never `< 0`.
- Use `!c.empty()`, structured bindings, `std::ranges` algorithms and `std::erase_if` over hand-rolled code.
- `FlatHashMap` invalidates every iterator and reference on insert.
- Put constants and lookup maps in an anonymous namespace at the top of the `.cpp`.
- All database access goes through `db::preparedStmt`. Read columns by name.
- Don't prefix log messages with the function name. The logger adds it.
- Send IPC to the process that needs it, not to every process.
- Name a function that iterates a whole zone so callers know it's expensive.
- Use `#pragma once` and write floats as `100.0f`.
- Fix the model instead of adding a workaround around it.

## SQL and data

- Check how many mobs or items share a row before you change it. Per-mob values go in the mob script.
- Never change the binary names that came from captures.
- Update a row's trailing comment when you change its value.
- Don't split one mob's skills or spells between SQL and Lua.
- A new player-data table goes in the `player_data` list in `tools/dbtool.py`. Static tables must not.
- New mods go in `data/enums/mod.yaml`. Update its `SPARE IDs` comment.
- Drop weights are out of 10000 per group and must add up to it.

## Modules

- A module is a set of overrides (`m:addOverride`, calling `super()` where needed). Code that overwrites a global in the file body only works by luck of load order.
- Era modules live in `modules/era/<expansion>/`. The header says which era, the patch date and a source. Name settings for what they do (`USE_PRE_WOTG_EXP_LOSS_TIERS`, not `ERA_EXP_LOSS`).

## Tests

- New behaviour in C++ or shared Lua comes with an `xi_test` case. See [Testing](Testing).
- Don't test random outcomes. A flaky test is worse than none.
- Assert with enums, not raw ids.

## Comments

- Put a comment above the code it describes, never inside or below the block.
- Delete comments that repeat the code. Keep sources, reasons and capture notes.
- `-- ` with a space for comments. `---` is for LuaLS annotations.
- No line numbers, references to earlier implementations, or links to other projects' issue trackers. Git history covers that.
- Remove debug `print` output.
- A `TODO:` is fine. A PR that only adds TODOs isn't.
