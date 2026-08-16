
# Notes

## Rough ToDos

* Schedule
* Rankings
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
