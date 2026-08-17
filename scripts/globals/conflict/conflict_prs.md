# Conflict (Ballista) — Eden PR review checklist

Every Eden PR that mentions "ballista", resolved to its commit in the local Eden clone
(`C:\ffxi\eden`). Each is checked against this branch. Anything still outstanding is marked so.

View any commit with: `git -C C:/ffxi/eden show <hash>` (add `--stat` for just the file list).

Note: our port was taken from **Eden HEAD** (the modernized `src/game/conflict_*` +
`scripts/globals/conflict`), so Tier 1 core logic is largely folded in already — the highest-risk
gaps are **Tier 2** (PVP combat-balance changes that live in general combat files, *not* the
conflict_* files, so a conflict-focused port can easily miss them) and the **quests** in Tier 1.

---

## Tier 1 — Core Conflict engine / content — REVIEWED

- [x] **#1121** Base Conflict and Ballista implementation — `87ca66d` — baseline (superseded by the Eden-HEAD port).
- [x] **#2102** Initialize conflicts after NPCs and mobs — `87b8695` — **PRESENT** (`map_engine.cpp:231` Initialize() after zoneutils::Initialize + weather).
- [x] **#2595** Keep conflictEntry after leaving match — `1c1d4ba` — **PRESENT + FIXED**. Persistence was there (`oldEntries`/`HasActiveEntry`/`TryRejoinPlayer`); the gap (0x01a Quarry/Sprint/Scout checked bare `conflictEntry`) is now guarded with `HasActiveEntry()` in `0x01a_action.cpp`.
- [x] **#1162** Fix Ballista cancellation refund — `f458eb5` — **PRESENT** (herald.lua:181 `state > ACTIVE`, reward 4 = cancelled; refund in conflict_instance.cpp).
- [x] **#3264** Upper bound option check for exchanging items — `dbf4b29` — **PRESENT** (core.lua:81 byte-identical bound check).
- [x] **#5430** [Garrison] ballista blocker — `69d65d0` — **DONE**. `xi.garrison.isBallistaActive(zone)` asks the match its state rather than inferring it from the Herald's display status, and the gate sits before `confirmTrade()` so a refused Garrison does not eat the traded items.
- [x] **#949** Ballista License quests — `3e6d4c3` — **DONE**. `scripts/quests/hiddenQuests/Ballista_License.lua`, rewritten onto the interaction framework as three stage-gated sections rather than Eden's nine per-nation ones, so the progression logic is written once. The letter key items are mapped by id: the names differ between the two servers and the suffixes do not correspond.

## Tier 2 — PVP combat mechanics used in Conflict — REVIEWED 2026-06-28

Verdicts from a per-commit diff vs our tree. **3 PRESENT / 4 PARTIAL / 8 MISSING.** LSB's combat is
heavily refactored into Lua modules (`scripts/globals/combat/*`) + new C++ states, so several Eden
mechanics exist via different APIs. The genuinely conflict-relevant gaps to consider porting:

- [x] **#1133** Damage taken is reduced in Conflict — `80b8584` — **PORTED since this review, see Finding 2.**
      Eden adds `HandleConflictDamage`: `if isInConflict() dmg *= 1 - dmg/4000` in 5 damage-taken paths. No equivalent in our `battleutils.cpp`. Players take full damage in our Ballista.
- [x] **#4304** Increased resist trait in conflict — `671541f` — **DROPPED since this review, see Finding 4.**
      Eden: `if target:isInConflict() then effectres = effectres * 1.5`. Our resist path (`combat/magic_hit_rate.lua`) has **no `isInConflict()` call anywhere in scripts/**.
- [x] **#2785** Conflict — restore mp to 50% on reraise if lower — `c3634e5` — **PORTED since this review, see Finding 6.**
      Our `CCharEntity::OnRaise` has no MP-restore / conflict branch; conflict auto-raise (`conflict_player.cpp:365`) doesn't top MP to 50%.
- [x] **#2561** Sharpshot bypasses auto miss (conflict ranged) — `c1709be` — **DROPPED since this review, see Finding 5.**
      Our `GetRangedHitRate` unconditionally returns 0 past 25 yalms; no PC-in-conflict case, no Sharpshot bypass (Sharpshot never consulted in hit-rate).
- [x] **#4526** Re-apply level restriction after raise — `6c0ba80` — **PORTED since this review, see Finding 1.**
      No `resetCharToLevel`; no `CRaiseState` (raise = `death_state.cpp`, no level re-cap). **AND `charutils::SetLevelRestriction` is an EMPTY STUB (charutils.cpp:5859)** — so our Ballista level caps likely don't apply at all. See Findings.
- [x] **#2775** Base pet conflict effects (closed PR) — **PORTED since this review, see Finding 3.**
      The deeper PR never merged anywhere. But Eden mainline `changeAllegiance` does `ClearMobEnmity()`, widens melee range 3→6 in conflict, and propagates allegiance to the pet — our `battle_entity.cpp:1659` `changeAllegiance` only flips allegiance + updatemask (the rest is our explicit TODO).
- [x] **#1124** Immortal shield fix + rampart for ballista — `dbfe3e1` — **PARTIAL**
      Rampart (SDT mods) + Immortal Shield exist in LSB but via different impl; the ballista MAGIC_SHIELD subPower HP-absorb-pool depletion is absent.
- [x] **#3875** Magic shield prevents tp/ws enfeebs — `179ead5` — **PARTIAL**
      LSB blocks enfeebs for **any** MAGIC_SHIELD power (`magic_hit_rate.lua:499`); Eden gates on FULL_SHIELD/MAGIC_IMMUNE tiers. Functionally close.
- [x] **#1843** Guard/parry/block bindings — `3b7cb46` — **PARTIAL**
      C++ `isParried/isGuarded/isBlocked` bindings absent, but Lua equivalents exist (`combat/physical_utilities.lua`) and are used. Capability covered, bindings not.
- [x] **#2012** Block/guard/parry weaponskills (incl. players) — `a861dc9` — **PRESENT**
      LSB `weaponskills.lua` already routes WS hits through `isParried/isBlocked/isGuarded` with PC-defender handling.
- [x] **#4516** Magical/breath monster tp at neutral resist — `0c871b2` — **PRESENT**
      Equivalent neutral-resist tier cap in `combat/magic_hit_rate.lua:508-533`.
- [x] **#2463** Bind checking speed instead of mod — `7a49c81` — **PRESENT (N/A)**
      LSB bind uses `setBaseSpeed(0)` design; the Eden bug doesn't exist here. No port needed.
- [x] **#4137** Standard ranged attacks anticipatable — `3392b00` — **MISSING** *(general PVP, not conflict-gated)*
      No `IsRangedAnticipated` / ranged anticipation in our `OnRangedAttack`. Third Eye doesn't evade ranged.
- [x] **#1161** Weaponskills anticipatable — `842b37e` — **MISSING** *(general PVP, not conflict-gated)*
      LSB `weaponskills.lua` has no third-eye/anticipate branch.
- [x] **#3694** Wipe third eye with phys blue aoe — `59f6c08` — **MISSING** *(general PVP, not conflict-gated)*
      Our `usePhysicalSpell` (bluemagic) never delStatusEffect THIRD_EYE on AoE.

### Findings / suggested port priority — PROGRESS

1. ✅ **DONE — BUG (independent of Eden):** `charutils::SetLevelRestriction` was an empty stub (Ballista level caps did nothing). Now applies the `LEVEL_RESTRICTION` status effect (same as level-capped zones/battlefields), which recaps via `levelRestriction()`. *Verify in a capped match on the client.*
2. ✅ **DONE — #1133** damage-reduction-in-conflict. Hooked once at `CBattleEntity::takeDamage` instead of `battleutils::HandleConflictDamage` (`isInConflict()` → `dmg * (1 - dmg/4000)`, positive-only, clamped). Eden hooks the five damage-taken funnels, but three of those are pure mitigation calculators that never decrement HP, two of them reachable from Lua on damage the script may discard, and the set misses skillchains, damage over time and mob skills. `CBattleEntity::takeDamage` is the single chokepoint every path already funnels through, next to the existing ROE hook. Eden's curve also reaches zero at 4000 damage and goes negative above it, turning a large hit into healing; the scale is clamped so the floor is 1.
3. ✅ **DONE — #2775 / changeAllegiance** — now clears nearby mobs' enmity (`ForEachMob` → `PEnmityContainer->Clear`), propagates allegiance to the pet, and `GetMeleeRange` widens by +3 (Eden 3→6) when `isInConflict()`.
4. ⬜ **DROPPED — #4304** 1.5x status resist. Reverted: retail resists repeated enfeebles with a per-effect resistance that accumulates and decays, plus a hard sleep-duration cap. A flat divisor is the wrong shape and touched both land rate and duration. Originally added a Lua `isInConflict()` binding and, in `combat/magic_hit_rate.lua` `calculateResistanceFactor`, divide the landing factor by 1.5 for status effects on conflict targets.
5. ⬜ **DROPPED — #2561** Sharpshot/ranged conflict auto-miss. Reverted after checking sources: the patch note Eden cites is about distance accuracy penalties generally, not about extending maximum range, and says nothing about Ballista. Originally ported Eden's exact condition to `GetRangedHitRate`: the >25-yalm auto-miss now applies to mobs and conflict PCs and is bypassed by Sharpshot (our code was previously *stricter* — auto-missing everyone past 25).

6. ✅ **DONE — #2785 / conflict death and reraise.**
   - On death in a live match: drop held petras + schedule reraise (`ConflictEntry::Tick`).
   - Reraise after 30s (+15s per prior RR, `autoRaiseCounter`): revive, HP full, **MP→50%** (#2785), Weakness; then `xi.conflict.reraiseAtCamp` teleports to the team camp + applies a 30s Invisible.
   - `CDeathState` no longer auto-homepoints players flagged `isInConflict()` — the match reraise drives.
   - No EXP loss on conflict death (`CCharEntity::OnDeath`).
   - Bridge: `luautils::ConflictReraise` → `xi.conflict.onReraise` (bindings.lua) → `reraiseAtCamp` (utils.lua). Test: scripts/tests/systems/conflict/death.lua (petra-drop + reraise w/ HP & MP). 18/18 conflict tests pass.
   - *Not yet ported (smaller follow-ups): the "Recovery in X seconds" countdown messages every 10s, and manual-homepoint suppression mid-match.*

7. 🟡 **General combat divergences — deliberately NOT force-ported.** These are *not* conflict-gated; LSB implements them differently (or not at all) in its refactored combat module. Porting Eden's isolated versions would change combat for **all** content for marginal/zero Ballista-specific benefit, and risk inconsistency with LSB's own model. Documented per item, left to a separate general-combat-parity effort if desired:
   - **#4137 / #1161** ranged & WS anticipation (Third Eye) — LSB has melee anticipation only; adding these touches core attack/WS paths broadly.
   - **#3694** third-eye wipe on phys blue AoE — an isolated piece of the same unimplemented Third Eye mechanic.
   - **#1124** Immortal Shield / Rampart HP-absorb pool — LSB models Rampart as SDT mods; different design.
   - **#3875** magic-shield power-tier gating — LSB already blocks enfeebs for any magic-shield power (functionally close).
   - **#1843** guard/parry/block C++ bindings — capability already present as `xi.combat.physical.isParried/isGuarded/isBlocked` (Lua); C++ bindings would be redundant.

## Tier 3 — Supporting systems Conflict depends on — REVIEWED

- [x] **#1141** Interruption text for events — `1fc7ad9` — **PRESENT** (`event_info.h interruptText`; `interrupt_text` startEvent option; already used by rook.lua:42).
- [x] **#1046** Non-inventory item usage — `2f47980` — **DONE (adapted)**. core.lua:80 calls `player:useItem(itemId)` which did NOT exist (would error). Rather than Eden's full non-inventory machinery, added a `CLuaBaseEntity::useItem(itemId)` binding that finds the item in LOC_TEMPITEMS (then inventory) and uses it via the existing `UseItem(targid, loc, slot)` path — temp items are real storage in LSB.
- [x] **#88** Prevent player actions while in event — `bfb2237` — **PRESENT** (LSB `BlockedState::InEvent` / `isInEvent()` per-packet validation).

## Tier 4 — Mention only — DISMISSED (not Ballista-relevant)

- [x] **#1249** Adding missing bard songs — `e230c9c` — incidental (bard song effects/spells).
- [x] **#494** Fixing feather tickle — `c3dd262` — incidental (Blue Magic enmity spell formula).

---

## Retail accuracy, checked 2026-08-17

Checked against the SE patch notes mirrored on Ffxiclopedia, the Japanese FFO wiki and the client
event dumps. **No Ballista packet capture exists on this machine**, so anything not covered by those
cannot be settled here.

Corrected:

- Temporary item slots were inverted. Pashhow, the zone where a player's own items are barred, is
  the one raised from ten to fifteen; the other two stay at ten.
- Guest entry opens at 16:00, not 16:30.
- The second rook was appearing on any imbalance at all, so nearly every match ran two. The
  threshold retail describes is a "significant difference", with no number given.
- Quarry is a three second dig on a thirteen second recast.
- The maximum member difference matched no source; the Japanese wiki gives four.

Verified correct and left alone: even-day scheduling, the six-day zone rotation, the seasonal nation
pairings, the level cap ladder and entry fees, the sign-up and line-up times, the three-per-side
minimum, the five-petra throw cap, the best-of-three round structure, and the hundred point teleport.

Still unknown, and marked TODO in code: every Ballista point award, the shape of the damage
reduction, and the quarry drop weights. The quarry roll also ignores the score and gate breach,
which retail uses as its catch-up mechanic.

---

## Found after the review above, against the client's own data

None of these are Eden PRs. They came out of the event bytecode in the `FFXI-EventsDump` tree and
the packet reference at `atom0s/XiPackets`, both of which settle things that looked like they
needed a live client.

Herald and events, cross-checked between the Jugner, Pashhow and Meriphataud dumps:

- The sign-up menu offers each nation by name, returned as options 14 and 15. **Neither was
  handled**, so choosing a side did nothing at all. Every other option value, the quarry temp item
  and petra menus, and the line-up cutscene params were confirmed correct.

Packet 0x00E6, checked field by field:

- Scout sent the position as X, Y, Z where the client reads **X, Z, Y**, so the compass pointed
  somewhere else, and the fourth slot that repeats the distance was zero.
- The client shows the distance as `sent * 0.914 + 0.5`, so the server has to send the inverse.
- The scoreboard set counter is displayed halved, so it goes out doubled. Sending the phase left
  the counter a set behind for the whole of every round.
- A cleared board needs `Flags` set. With `Flags = 0` the client's handler exits and the last score
  stays on screen.
- `Flammes` drives Brenner's indicators and belongs at zero in a Ballista match.

Engine correctness:

- A zone change cleared the entry's pointer to the character but not the character's pointer back,
  leaving a freed entry reachable once the match was reaped.
- A default-constructed `sol::protected_function_result` reports `valid()` with a null `lua_State`,
  so the Lua bridge's "script absent" path dereferenced null.
- Ballista points are paid by character id, so a participant who zoned out still collects. They
  were previously paid through the online character and lost everything they had earned.

Still unverified, and marked TODO in code:

- `Scoreboard[1]` selects a render mode, one of whose jobs is hiding the board outright. The code
  passes nation bits, which is certainly not that. XiPackets does not give the value table, so any
  value would be a guess. This is the one field that could leave a scoreboard invisible.
- The `/search` team colour bits. XiPackets has no search server coverage.
- The Marshal has no handler, so the Ballista Points shop, MVP board and ranking do not exist.
  Inherited: "Rankings" is on Eden's own TODO list at the top of `notes.md`.

---

## Built beyond Eden

Eden's own rough ToDo list at the top of `notes.md` includes "Rankings", which it never wrote.
These are new here rather than ported, and every value behind them is cited:

- **The Marshal's point exchange.** Twenty-three vouchers, each one bought with Ballista Points and
  spent at the start of the next match for one temporary item. The costs are read out of Marshal
  event 26, which carries the exchange table as twenty-three rows of item, voucher and price;
  Ffxiclopedia lists two further rows the client's table does not have. Ten vouchers may be held,
  one of each type, both numbers from the same event. The Catholicon needs a chevron.
- **Ballista Point Ranking.** `conflict_rankings` records a finished match against a location's
  board, which ranks the last ten matches held there on the points earned in a single one.
  Registration runs for four Vana'diel hours after a match, the board is unreadable until that
  closes and readable for four Vana'diel days after. A placing takes a chevron and its title, only
  one may be held, and it expires after an Earth week; the Herald's second cutscene takes it back.

**Not built.** The Marshal's conversation is not wired to any NPC, and the previous match MVP
board is not implemented. Both are blocked on the same thing: option -3 is reused between the
exchange and the ranking flows, so a wiring has to track which branch the conversation is in, and
the MVP display takes its data from the event's opening parameters rather than a round trip. The
parameter layout and capability bits are written up in `notes.md`; what is missing is a client to
check the branch handling against.

## Merging base in

`base` has moved on since this branch forked at `7b266449d9`, and it needs to come in before this
goes anywhere: among the 36 commits are a tick-hotpath series and the `GetPoints` column-select
change this branch does not have. A trial merge in a throwaway worktree conflicts in three files,
all small.

- `src/test/CMakeLists.txt`: both sides added a test source next to the same line. Keep both
  `timeline_tests.cpp` and `roam_region_tests.cpp`.
- `src/map/zone.cpp`: both sides added an accessor at the same spot. Keep both `CZone::scheduler`
  and `CZone::roamRegion`.
- `src/map/utils/charutils.cpp`: **the one that needs care.** Both sides extracted the same
  `char_points` column check. Base calls it `isCharPointsColumn`, which this branch has since
  adopted so only the body differs.

  Base's body fills a function-local static under a plain `empty()` check. That is a data race
  here, because a Ballista match end posts the point award to the worker pool while the main
  thread is calling the same function. **Keep this branch's body**, the immediately-invoked
  initialiser on a `static const`, and base's set of callers. Resolving in base's favour puts the
  race back.
