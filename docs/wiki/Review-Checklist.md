# Review Checklist

What maintainers keep pointing out in review. CI handles formatting, the [Development Guide](Development-Guide) handles style, and its [Conventions](Development-Guide#conventions) say which tool to use for trades, rewards, pathing and the like. This is the stuff only a person catches, so run your change past it before you open a PR.

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

- CI is green. We don't read PRs that fail the sanity checks.
- Rebase on the latest `base` whenever there are conflicts.
- Address review by amending and force-pushing. No "address comments" commits, no closing and reopening the PR, no stacking PRs on unmerged work.
- One commit per logical change. A commit that bundles unrelated edits gets sent back.
- Fill in the PR template and tick its boxes. Don't delete it.
- Say what you tested and how. Untested PRs go back to draft.
- The reviewer resolves review conversations, not you. You don't have to reply to every comment or re-request review after every push.
- Stay in scope. Anything big starts as a draft.
- Security problems go to a maintainer, privately. The fix never names the problem, and never ships with public repro steps or a test that reproduces it. See [Security Fixes](https://github.com/LandSandBoat/server/blob/base/CONTRIBUTING.md#security-fixes).

## Sources and values

- Every behaviour change needs a source: a retail capture, an event dump, a timestamped video or the Japanese wiki. A number without one gets "Where did you get this from?"
- A wiki on its own is never enough for a number. Neither is earlier LSB or DarkStar code.
- Credit the capture if it isn't yours.
- Guessed value? Mark it `TODO: Capture needed` (`--` in Lua and SQL, `#` in YAML). Older rows say `Capture needed` without the `TODO:`, so search for that.
- Your source disagreeing with LSB doesn't make LSB wrong. Find out why.
- Captured positions go in verbatim. Never round them.
- Unclear source? Pick the value that's harder on players: shorter buffs, smaller bonuses, a fixed value over a wide random range.
- Check the units on both sides of any time maths. The code mixes seconds, milliseconds, Vana'diel time and ticks.

## Where code belongs

- Mob behaviour lives in the mob script or a mixin, never a mob skill script.
- Quest and mission logic lives in `scripts/quests` or `scripts/missions`. Not NPC, mob or zone scripts.
- Zone scripts and `IDs.lua` hold no logic. Battlefield mechanics go in the battlefield script.
- Shared logic goes in a global everyone calls. One entity's script doesn't reach into another's.
- Entity iteration and target selection are C++ jobs, not Lua.
- Bindings go in `src/map/lua`. They look things up and prepare values. They don't change state.
- No binding, setting or enum entry without a use in the same PR.
- A helper only one system uses lives in that system's file. `scripts/utils` is for code lots of systems share.
- `scripts/globals/magic.lua` only shrinks. No additions.
- Custom or server-specific features go in a [module](Module-Guide), not upstream.
- Once a mechanic exists, delete the setting that stood in for it, along with its uses and tests.

## Lua

Functions:

- No one-line helpers. Inline them.
- No function with exactly one caller. Put the logic where it's used.
- A helper that hides real complexity, like bit packing or a loop, is fine.
- No functions defined inside functions.
- Only used in its own file? `local function`.
- One return type per function. Use a sentinel like `xi.keyItem.NONE` instead of value-or-nil.
- No naked boolean parameters. Use an enum, or a table with named fields.
- Delete empty callbacks and files with no logic. Doors are the exception.

Conditions:

- Return early instead of nesting, with the cheapest guard first, before you fetch values it doesn't need.
- `if not mob then`, not `== nil`.
- Don't nil-check things that always exist. Unset vars are `0`, not `nil`.
- Drop a guard when the next expression already fails for that case. `math.randomInt(1, 100) <= chance` doesn't need `chance > 0` in front of it.
- Check settings explicitly (`== 1`, `== true`). `0` is truthy in Lua.
- `cond and a or b` is the ternary. It breaks if `a` can be `false` or `nil`.

Values:

- Enums, never magic numbers: `xi.item`, `xi.keyItem`, `xi.zone`, `xi.effect`, `xi.mod`, `xi.element`, and message ids from `IDs.lua`.
- A table beats an `if`/`elseif` chain. Extend the file's existing table if it has one, and define tables at file scope.
- Repeated calls (`getID()`, `getZoneID()`) go in a local.
- A value used once doesn't get a local. Use it inline.
- `string.format`, not `..`.
- `math.random(min, max)` with both bounds, or `math.randomInt`. Never bare `math.random()`.
- `utils.clamp`, `utils.randomEntry` and `GetSystemTime()` over hand-rolled versions or `os.time()`.
- `math.floor` anything that has to be an integer.
- No unneeded parentheses and no `.0` float literals.
- Names say what they hold: `currentTime`, not `now`. `itemId` and `zoneId` when it's an id.

## Quests and NPCs

- `quest:event()` for filler and reminders. `quest:progressEvent()` only when the event changes quest state.
- `replaceDefault()` only when the event really does replace the zone default. Otherwise, `DefaultActions.lua`.
- Every section checks the quest status, and sections are mutually exclusive.
- Check the player has the currency, or a free inventory slot, _before_ the cutscene.
- Trades that consume items use `npcUtil.tradeHasExactly()`, and get confirmed in `onEventFinish`.
- `onTrade` before `onTrigger`. `onEventFinish` cases in event id order.
- `IDs.lua` text comments are exact copies of the client string, and entries are alphabetical.
- Find entities by name or position, not a hard-coded id. Ids shift with retail updates.

## Mobs

- Keep `onMobFight` and `onMobRoam` small. They run every tick.
- Immunities and resistances in `onMobInitialize`, per-spawn values in `onMobSpawn`. Use `setMod` on spawn, since `addMod` stacks across spawns.
- Put modifiers on the effect (`effect:addMod`) and there's nothing to clean up when it wears off.
- `onMobDeath` runs once per player on the enmity list. Guard one-off work with `if optParams.isKiller or optParams.noKiller then`. `player` can be `nil` there.
- Prefer the `entity.onMob*` functions to listeners. A listener needs a specific name, and has to use the mob it's passed, not a captured one.
- Callback order: `onMobInitialize`, `onMobSpawn`, `onMobRoam`, `onMobEngage`, `onMobFight`, `onMobDisengage`, then death and despawn.
- No wide random ranges on mob skill effect durations. Use the balanced value and let resistances do the rest.

## C++

- No raw owning pointers and no raw `new`. `Box` (`std::unique_ptr`) or a value member.
- `dynamic_cast` entity pointers and check the result straight away.
- `Maybe<T>` for a value that might not be there. Call it `maybeThing`.
- `enum class` over raw ints and naked bools. Yes/no parameters take a `Flag<Tag>`, so every call site says what it means.
- Watch signedness and width across a getter, setter and member. An unsigned value is never `< 0`.
- `!c.empty()`, structured bindings, `std::ranges` algorithms and `std::erase_if` over hand-rolled loops.
- `FlatHashMap` invalidates every iterator and reference on insert.
- Constants and lookup maps go in an anonymous namespace at the top of the `.cpp`.
- All database access goes through `db::preparedStmt` with a literal or `constexpr` query. No query text built at runtime. Read columns by name.
- Clamp or cut values to their column's width before writing. Strict mode fails the statement otherwise.
- Writes that must land together go in `db::transaction`, with every statement's result checked.
- Nothing off the main thread touches Lua, entities or zones. Don't block the main thread waiting on a worker.
- Client strings come in through `asStringFromUntrustedSource(ptr, size)` and go out to the log as `{:?}`.
- Don't prefix log messages with the function name. The logger already does.
- Send IPC to the process that needs it, not to all of them.
- If a function iterates a whole zone, its name should say so. Callers need to know it's expensive.
- `#pragma once`, and floats as `100.0f`.
- Fix the model. Don't build a workaround around it.

## SQL and data

- Check how many mobs or items share a row before you change it. Per-mob values go in the mob script.
- Binary names from captures never change.
- Change a row's value, update its trailing comment.
- One mob's skills or spells live in SQL or Lua, not split across both.
- New player-data tables go in the `player_data` list in `tools/dbtool.py`. Static tables must not.
- New mods go in `data/enums/mod.yaml`. Update its `SPARE IDs` comment.
- Drop weights are out of 10000 per group and must add up to it.

## Modules

- A module is a set of overrides (`m:addOverride`, calling `super()` where needed). Overwriting a global in the file body only works by luck of load order.
- Era modules live in `modules/era/<expansion>/`, with a header giving the era, the patch date and a source. Name settings for what they do (`USE_PRE_WOTG_EXP_LOSS_TIERS`, not `ERA_EXP_LOSS`).

## Tests

- New behaviour in C++ or shared Lua comes with an `xi_test` case. See [Testing](Testing).
- Don't test random outcomes. A flaky test is worse than no test.
- Assert with enums, not raw ids.

## Comments

- Comments go above the code they describe. Not inside the block, not below it.
- Delete comments that repeat the code. Keep sources, reasons and capture notes.
- `--` with a space for comments. `---` is for LuaLS annotations.
- No line numbers, references to old implementations, or links to other projects' issue trackers. That's what git history is for.
- Take out your debug `print`s.
- A `TODO:` is fine. A PR that's nothing but TODOs isn't.
