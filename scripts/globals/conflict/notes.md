
# Notes

## Event option values, confirmed from the client

Read out of the event bytecode in the `FFXI-EventsDump` tree, not from another server. Jugner,
Pashhow and Meriphataud were cross-checked and agree, so anything below is settled.

To read a dump: `Work_Zone[0]` is the menu selection, `Work_Zone[1]` is the value returned to the
server, and `Work_Zone[N]` is `params[N - 2]` for everything `startEvent` sent. `0x40000000` is
the client cancelling.

Herald, sign-up menu:

| Value | Meaning |
| --- | --- |
| 1 | Temporary entry |
| 2 | Let the Herald place you |
| 14, 15 | The first or second nation, by name |
| 16 | Fill a slot mid-match |

Herald, everything else: 3 and 4 discharge during or before the match, 5/8/7/6 collect for a win,
loss, draw or cancellation, 9 warps to homepoint for 100 points, and 10, 11 and 12 teleport to
Jugner, Pashhow and Meriphataud in that order.

Quarry, temp item: 0 keeps, 2 uses, 3 throws away, and an exchange returns the temp item index
plus 1000. Quarry, first petra: 1 keeps.

The line-up cutscene takes position as params 0 to 3. A petra count of `-1` suppresses the score
line, and a high scorer petra count of 0 suppresses the MVP line.

## The Marshal's event, read out of the client

Event 26 on the Marshal actor. Not wired yet; this is what a wiring needs.

Parameters, using `Work_Zone[N] = params[N - 2]`:

| Param | Meaning |
| --- | --- |
| 0 | Cumulative Ballista Points. The client caps the display at 2000 itself |
| 1 | Unread by the main flow |
| 2 | Read into a local the exchange list uses |
| 3 | Bit 0 and bit 1 set two flags; bit 0 is the "job does not match the record" case |
| 4 | Unread by the main flow |
| 5 | Points earned in the previous match. Zero takes the "you earned none" branch |
| 6 | Capability bits, below |
| 7 | Read into a local the ranking branch uses |

Param 6 decides which lines of menu 7524 are greyed out. The menu is: exchange points, view
the previous match MVPs, sign up for ranking, view the ranking, learn about points, learn about
ranking, nothing.

- Bit 0 clear disables sign up, view ranking and learn about ranking. Set, it disables the MVP
  line instead. So this is "the ranking section is what is on offer right now".
- Bit 1 gates sign up on its own. Clear, the Marshal says registration has concluded.
- Bits 2 and 3, both clear, disable the MVP line.
- Bit 6 disables the exchange.

Options the client returns, all as negative numbers arriving unsigned: -2, -4 and -6 in the
exchange flow, an item index plus 1000 to buy one, -5 to register for the ranking, -3 for the
board, -7 for the assessment.

**-3 is reused.** In the exchange flow it asks whether the Catholicon may be bought; in the
ranking flow it asks for the board. Nothing in the option value separates them, so a wiring has to
track which branch the conversation is in. That is the part that wants a live client.

## Rough ToDos

* Schedule — done
* Rankings — the board, registration, chevrons and expiry are done; the Marshal's own
  conversation and the MVP board are not, see conflict_prs.md
* NPC interaction and messages
  * Appear in right zone
  * Sign-up reminders
  * Team to join
* Modes
  * All or Nothing
  * Best of Three
* Rooks/Scoring
  * Move rook timer (every 3 game hours, starting move at X:57, has 30s and 15s warnings)
  * Rook positions (set positions for each Rook, need more players to capture rest of Rooks)
  * Rook amount/player
  * Ballista Status Packet
  * Gate Breach
* Quarry
  * Temp. items
  * Petra
  * Key Items (Petra Shovel, other thing)
* Battle
  * Attack range
  * Provoke
  * Steal/Mug
* Sprint

## System messages
Quarry: You have to wait longer = 38, p1 = <seconds?>
Sprint: You cannot perform that action while holding a Petra. = 209, p1 = 2
Gate Breach status has been disengaged. (upon scoring) = 212

## Misc

Periodic status messages every 30 ingame minutes with time remaining and top scorer (at least for Best of Three mode)
Occasionally also reminds to throw petras into rooks if possible

On death: send to camp and give 30s invisible

Line-up sequence starts at 22:00 ingame on day before

Best of Three:
- match 1 begins at 0:00 ingame
- match 1 ends at 7:33 ingame, 5 minute invisible
- match 2 begins at 8:13 ingame
- match 2 ends at 15:46 ingame
- match 3 starts at 16:26 ingame
- match 3 ends at 0:00 ingame

Rook models:
- 322 = SAN/WIN
- 323 = SAN/BAS
- 324 = BAS/WIN
- 325 = BLANK/BLANK

Death:
- Death timer: 30s, +15s for every RR, stays the same between matches in Bo3
- 30s invisible on RR
- "Recovery in X seconds" every 10s
- on normal raise, you get weakened and the RR timer doesn't increase
- lose all petras on RR or return to camp

Random:
- Attack range is increased to at least 5.8
- Sprint lasts 10s
- Quarry cooldown is 10s

## Note-worthy events

An entry canceled mid-fight (he just disappears): https://youtu.be/gLGzCIWWIec?t=565
3v6 after people leave: https://youtu.be/gLGzCIWWIec?t=575

Half-faded nation flags in search: https://youtu.be/gLGzCIWWIec?t=1339

"You were unable to complete your throw" https://youtu.be/AxFYdkzqUDw?t=663 Rook moves before throw ends?
Rook gate is still open: https://youtu.be/AxFYdkzqUDw?t=773

Steal: 05:38:37 in 1st Meri video
Full temporary item: 6:13:05 in 1st Meri video

# Rook data

Rook just appears immediately on next round in Bo3: https://youtu.be/uEjlaL9EGpc?t=2574
Rook positions:

Meri:

    https://youtu.be/uEjlaL9EGpc?t=379
    https://youtu.be/uEjlaL9EGpc?t=691
    https://youtu.be/uEjlaL9EGpc?t=1550
    https://youtu.be/uEjlaL9EGpc?t=2198
    https://youtu.be/uEjlaL9EGpc?t=2449
    https://youtu.be/uEjlaL9EGpc?t=3293 (possibly 1st?)
    (1st seems to be up entire fight as well, even though a player leaves: seen in distance here https://youtu.be/uEjlaL9EGpc?t=3147)

    Very strange fight where people leave and join a lot, but possibly 2 Rooks the entire time?
    https://youtu.be/gLGzCIWWIec?t=421
    https://youtu.be/gLGzCIWWIec?t=731
    https://youtu.be/gLGzCIWWIec?t=2075

Jugner:

    https://youtu.be/zIPgfK8vhOU?t=209
    https://youtu.be/zIPgfK8vhOU?t=325

    https://youtu.be/6Jg0X_KoDhk?t=190
    https://youtu.be/6Jg0X_KoDhk?t=490 (two rooks within sight-line of eachother)
    https://youtu.be/6Jg0X_KoDhk?t=602 Warping Rook?! A participant joins a bit later: https://youtu.be/6Jg0X_KoDhk?t=622 but still 2 Rooks
    https://youtu.be/6Jg0X_KoDhk?t=750 Rooks still on opposite sides of OP

Pashhow:

    https://youtu.be/AxFYdkzqUDw?t=881 both Rooks in sight-line, after teams have evened out

Rook count:

- 4v3 gave 2 Rooks: https://www.youtube.com/watch?v=AxFYdkzqUDw
- 4v3 gave 2 Rooks: https://youtu.be/uEjlaL9EGpc?t=255
- 5v5 seemingly gave 1 Rook: https://youtu.be/pBKOUie6jGE https://youtu.be/pBKOUie6jGE?t=244
- 6v5 gave 2 Rooks: https://youtu.be/gLGzCIWWIec?t=15
- 4v4 (but line-up looks like it was 5v4) gave 2 Rooks: https://youtu.be/ZqhTAWGcWGY?t=35
- 5v5 line-up gave 1 Rook: https://youtu.be/FvCxq_C6aCI?t=109 Weird that in line-up it's 3v5

# Timeline

12:00    | Herald appears and sign-ups begin for participating nations
every 30 | "Now accepting ... entries" x2, repeat every 30 ingame minutes
14:00    | Repeat info about upcoming match against
16:00    | Repeat info about upcoming match against
16:30    | "We have also begun accepting guest applications from [3rd nation] adventurers" is added to the 30 minute messages
18:00    | "We are now accepting temporary entries. Adventurers from any nation can submit an application." (replaces 30 min messages), and Repeat info about upcoming match against
20:00    | Repeat info about upcoming match against
21:35    | "The entry period for today's match will be ending shortly." repeat every 15 real seconds (it's 1 minute before start at 22:00 ingame)
22:00    | Begin start sequence (Herald starts walking forwards and lines up players)
         | Countdown begins 240 seconds before game start at: 240, 180, 120, 60, 30, 15 seconds before: "X seconds remaining until the commencement of today's match."

After speech, level restriction is applied

23:15    | "All players will now have Invisible and Sneak cast on them. Move into position and wait there until the starting signal."
         | 10 seconds after message: Invisible and Sneak is applied (5 minutes duration)
00:00    | Match begins. "Match 1 in the best of three series will conclude at XXX" every 30 ingame minutes, so :30 and :00
03:00    | Rooks move. (They start the submerge animation before, such that they are totally underground once 3:00 hits)
06:00    | Rooks move.
07:33    | [Bo3] Round ends, invis/sneak given
08:00    | "Match 2 in the best of three will begin at"
08:07    | "Match 2 in the best of three will begin at" (16 seconds later, and 16 seconds later again the next round starts)
08:13    | [Bo3] Round starts. The "Match 2 in the best of three" moves to every 30 ingame minutes after round starts, so :13 and :43
09:00    | Rooks move.
12:00    | Rooks move.
15:00    | Rooks move.
15:46    | [Bo3] Round ends, invis/sneak given.
16:13    | "Match 3 in the best of three will begin at"
16:20    | "Match 3 in the best of three will begin at" (16 seconds later, and 16 seconds later again the next round starts)
16:26    | [Bo3] Round starts. The "Match 3 in the best of three" moves to every 30 ingame minutes after round starts, so :26 and :56
18:00    | Rooks move.
21:00    | Rooks move.
00:00    | Game ends.

## What a retail capture settles

Source: a packet capture of the Ballista license quest and a private 2v2 match in Diorama
Abdhaljs-Ghelsba, 2019-12-15. The zone is retail's own private-match arena, reserved from the
Pursuivant in Ru'Lude Gardens, and the capture's zone list matches that flow.

Confirmed against the 0x0E6 implementation, from 13 scoreboard and 16 scout packets:

- `Flags` is 1 on every packet, and `Mode` is 2 for the scoreboard and 3 for the scout, matching
  the bitfield split of 6 and 10 bits.
- The payloads are 36 and 32 bytes, exactly the two `PacketData` layouts.
- `PetraCount` tracks petras held, climbing 0 to 5 and resetting.
- `Scoreboard[1]` is 8 in this match. The low three bits are the nations, and they are all clear
  here, which is right for a private match with no nations behind it. Bit 3 is set on top of that
  and is not accounted for.
- `Flammes` is 0x48 in every scoreboard packet, from the first update to the last, whatever the
  score. Meaning unknown.
- `FlammeFlg` is 8 exactly while a player holds Gate Breach, matched to the
  "achieves Gate Breach status!" message.
- The scout's `padding0C` is not padding: it holds the rook's target index, the low bits of the
  `RookUniqueNo` beside it. `RookPosition[3]` repeats `RookDistance`.

Damage is **not** scaled inside a match. One player kills another with a weaponskill for 1833,
which Eden's `damage * (1 - damage/4000)` cannot produce at all, since that formula peaks at 1000
for an input of 2000 and falls away after. No source supports a curve of any shape, so the
softening is gone rather than replaced.

Still unsourced: quarry drop weights and the Ballista point awards. Eden's award is 60 to the
winning side and 30 to the losing one under its own `TODO: figure out actual points gain`, so those
numbers carry no more authority than a guess.
