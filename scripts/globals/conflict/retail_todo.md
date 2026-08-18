# Conflict (Ballista): what still needs retail confirmation

Everything here is either unsourced, sourced only to a wiki, or contradicted between two sources.
The port is accurate to roughly the standard Eden set, and in several places past it, but none of
the below has been seen in a live client. Grouped by what it would take to settle.

## Needs a live client session

- **The Marshal has no NPC script.** `npc_list` has one in all three Ballista zones (Jugner
  17203827, Pashhow 17224305, Meriphataud 17265250) and the exchange, ranking and chevron logic in
  `marshal.lua` and `ranking.lua` is complete and tested, but nothing opens the event, so all of it
  is unreachable in game. Wiring it is blocked on one thing: the client reuses option `-3` between
  the voucher exchange and the ranking board with no server round trip in between to tell them
  apart. Watching one conversation resolves it. Eden ships a 26 line stub here, so this is not a
  regression against it.
- **Reraise offers a choice on retail.** Strings 7627/7628 describe reviving in place (full HP,
  half MP, half TP kept) or returning to camp (full HP and MP, all TP lost). Only the camp version
  is implemented, and the 5 minute Weakness has no source.
- **The scout packet's axis order.** The capture sends X, Y, Z. `0x0e6_ballista.cpp` writes X, Z, Y
  with a comment saying the swap was needed to make the compass point correctly, which reads like a
  live observation. Both cannot be right.
- **`Scoreboard[1]`.** Every scoreboard packet in the capture carries a constant `8`.
  `GetNationBits()` cannot produce 8 for any matchup. The nation-bit reading is a guess from the
  client binary and the one capture we have disagrees with it.
- **`padding06` and `padding0C`.** Retail puts the payload length in `padding06` (0x24 scoreboard,
  0x20 scout) and the rook's targid in `padding0C`. We send zero for both and the client did not
  appear to care, but that is untested.
- **`ToMatchSet` doubling.** Every capture packet has the match data zeroed, so the halving the
  client is said to do is unverified.
- **The scout distance transform** `(d - 0.5) / 0.91399997`. The sent values are known, the
  displayed ones are not.

## Needs a capture of a live match

- **Ballista point awards.** 60 to the winning side, 30 to the losing one, carried over from Eden
  under Eden's own `TODO: figure out actual points gain`.
- **Quarry drop weights and the distance curves.** Every base weight, the `min(petras * 3, 15)`
  Petra Eater chance, the static percentages, `missChance = min(8.5 + 1000/d^2, 18)` and the petra
  chance rising 2 per yalm past 15 to a 33.3 cap. All Eden's, none sourced.
- **The experience table** 300/350/400/450/500. Wiki only, and the wiki's bands disagree with the
  client's "over 30" wording about level 30 itself. "No EXP if the adventurer fails to actively
  take part" is not implemented at all.
- **Cooldowns and delays**: quarry 13s, sprint 45s, scout 5s, hint 3 min, reraise 30s plus 15s per
  earlier death. The gate breach durations of 90 and 180 Vana'diel minutes are wiki figures.
- **The melee reach bonus** of +3 yalms inside a match.
- **Damage is not scaled.** A capture shows a player killed by an unsoftened 1833 weaponskill,
  which rules out Eden's curve. It does not prove no curve exists, only that Eden's is wrong.
- **Team order for the remaining pairings.** The client's seasonal blurb names Bastok first for
  Jugner months 1-4 and Meriphataud months 5-8, which is now followed, but a static blurb is not a
  packet. Order decides which side is team index 0.

## Two sources disagree

- **Best of Three round length.** Ffxiclopedia says three 7 hour rounds with 90 minute intervals.
  `notes.md` records 40 minute intervals and 453 minute rounds. Both sum to a Vana'diel day; the
  code follows the second, and the second has no attribution.
- **Pashhow and Meriphataud rook and camp positions.** Ours match Eden exactly and disagree with
  `sql/npc_list.sql`. A patch note says the rooks and camps in exactly those two zones were moved,
  so one dataset predates the change and nothing on disk says which.
- **Whether Jugner restricts normal items.** The client's three match styles rule Meriphataud out
  but do not settle Jugner. Ffxiclopedia says Jugner and Pashhow both restrict; the 2005/02/24
  patch note names Pashhow alone, which is what the code follows.
- **The drawn-round message.** We always send "neither nation receives a match point" (7564). The
  client also carries 7474 and 7475, which award the point to the high scorer or to the dominant
  side. Which one retail picks is unknown.

## Unverified branches of the licence quest

The Bastokan and Windurstian paths are confirmed end to end from two captures. Not covered:
Excenmille taking a San d'Orian's letter (27), the Bastokan and Windurstian leaders receiving a
San d'Orian (828, 427), the San d'Orian leader receiving their own citizen (70), and which of
`signUp`/`signUpAgain` is the first-visit variant for Bastok and Windurst. A single San d'Orian
run closes all of them. The "rank 3 required" gate has no source anywhere local.

## Known gaps, no retail question attached

- The camp adjustment for matches under 40 participants is not implemented; only the rook count is.
- What a 40-or-more player match uses for rook count. "Reduced to two" implies a larger default.
- In-match enfeebling resistance is not modelled.
- A restart rebuilds the timeline with `ForceAdd::Yes`, so a recovered match replays the whole
  line-up ceremony and every rook move it already did.
- `highScorer` is not recovered from the database, so after a restart the first player to score is
  named regardless of totals.
- `ConflictState::Finished` forfeits every unclaimed fee. Only reachable from the GM command.
- The `FastQuarry` GM lever is never cleared once set on a character.
- `conflict_rankings.collected` is declared and never read or written.
- The three new tables have no migration under `tools/migrations/`, so an existing server gets them
  only through a full `player_data` import.
