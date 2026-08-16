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

- [x] **#1133** Damage taken is reduced in Conflict — `80b8584` — **MISSING** ⚠️ *(flagged important)*
      Eden adds `HandleConflictDamage`: `if isInConflict() dmg *= 1 - dmg/4000` in 5 damage-taken paths. No equivalent in our `battleutils.cpp`. Players take full damage in our Ballista.
- [x] **#4304** Increased resist trait in conflict — `671541f` — **MISSING**
      Eden: `if target:isInConflict() then effectres = effectres * 1.5`. Our resist path (`combat/magic_hit_rate.lua`) has **no `isInConflict()` call anywhere in scripts/**.
- [x] **#2785** Conflict — restore mp to 50% on reraise if lower — `c3634e5` — **MISSING**
      Our `CCharEntity::OnRaise` has no MP-restore / conflict branch; conflict auto-raise (`conflict_player.cpp:365`) doesn't top MP to 50%.
- [x] **#2561** Sharpshot bypasses auto miss (conflict ranged) — `c1709be` — **MISSING**
      Our `GetRangedHitRate` unconditionally returns 0 past 25 yalms; no PC-in-conflict case, no Sharpshot bypass (Sharpshot never consulted in hit-rate).
- [x] **#4526** Re-apply level restriction after raise — `6c0ba80` — **PARTIAL** ⚠️
      No `resetCharToLevel`; no `CRaiseState` (raise = `death_state.cpp`, no level re-cap). **AND `charutils::SetLevelRestriction` is an EMPTY STUB (charutils.cpp:5859)** — so our Ballista level caps likely don't apply at all. See Findings.
- [x] **#2775** Base pet conflict effects (closed PR) — **MISSING (our tree)** / PARTIAL (Eden mainline)
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
4. ✅ **DONE — #4304** 1.5x status resist. Added a Lua `isInConflict()` binding and, in `combat/magic_hit_rate.lua` `calculateResistanceFactor`, divide the landing factor by 1.5 for status effects on conflict targets.
5. ✅ **DONE — #2561** Sharpshot/ranged conflict auto-miss. Ported Eden's exact condition to `GetRangedHitRate`: the >25-yalm auto-miss now applies to mobs and conflict PCs and is bypassed by Sharpshot (our code was previously *stricter* — auto-missing everyone past 25).

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
