# C1b repeatable contracts

A bounty is a short, reliable reason to revisit a useful place. It uses
the existing quest system: `repeatable: {"cooldown": seconds}`, ordinary
objectives and existing quest NPCs. No daily reset, board node, random
rotation, reputation currency or new objective type is needed.

## Capacity and progression

Author **one repeatable tail per line**, at most **two bounties per giver**
when both of that giver's two lines have reached their tails. The normal
default is one. A bounty requires its line's last one-time quest. Never
place two independently repeatable quests on the same named line: a
prerequisite checks first completion, so it does not retire the earlier
bounty. A cooldown is not a spare line slot.

Start zones need no repeatables to reach their 90% target; a small surplus
order may be a tail after the lesson is complete. From 11–40 repeatables
remain optional and are excluded from the baseline 80% ledger. A hub
still has at most two givers, two lines each and four active quests in
total. Start elders retain `hunt`/`tools`, cooks `pantry`/`kitchen`.

## Compatible bundles

| Contract | Typical request | Reward relative to a comparable one-time quest | Cooldown after turn-in |
|---|---|---|---|
| Hunting | 6–8 ordinary enemies in one reachable area; 5 for a scarce species | 50%; usually 2–3 KE, 3–3.5 on the late front | 900–1800 s (15–30 min) |
| Material recovery | A small generic-loot request, 4–8 ordinary ore/bar units, or 3–5 quest-only recovered pieces from the same outing | 40–60%; usually 2–3 KE, up to 3.5 at T6 | 1200–2400 s (20–40 min) |
| Optional elite work, L31+ | One fixed elite leader; at most a small ordinary escort objective | 50%; usually 3–4 KE; the elite's own ×4 kill XP is separate | 2700–3600 s (45–60 min) |
| Island salvage, L60 | Small normal-enemy/material contract; elite work separately labelled | 0 XP weight at the cap; coin rule in calibration | 3600 s (60 min) |

Choose a fixed cooldown from the range for each authored quest; do not
roll it each time. It starts when the reward is received at **turn-in**,
not on acceptance or the last kill. Abandoning or logging out cannot
shorten it. A ready contract may simply wait; there is no missed-day debt.

A bundle means two compatible contracts that already fit the givers'
declared lines, or one contract with multiple objectives. Examples: a
hunt with meat recovery, a mine approach with ore collection, a camp
clearance with recovered supplies. One hunt plus one recovery order is
enough. Keep each contract's reward below its one-time counterpart and
the combined outing below the reward for two separate full outings.
Do not charge the same kill twice in the route XP budget. Quest-only
drops roll per participant; ordinary recovery materials are required
separately from each player.

Apply the [catalogue consumption budget](README.md#supply-and-consumption):
recovery bounties never consume the common stat-loot ingredients. Use a
claimed regional signature or real surplus, reserving the own-material
feedstock (cloth, silk, hide and thread) for the player's planned enchants.
An item being generic does not make its supply unlimited.

Use daytime material work alongside a night hunt. Never force waiting
for an elite, a rare or dawn to fill the solo route. Rares, critters,
self-destructing Rift Spawn and bosses are not bounty kill targets.
Elite work is optional, marked `optional: true`; use `group: true` and
the visible **Group** label whenever the solo promise cannot be met.
Its prerequisite is a solo quest, and no required solo quest depends on it.

## Front dispatch without front towns

Front one-time quests and bounties are written by C3g in
`zones/<host_zone>.front.quests.json`, with `line: "front"`. The host's
own quest file declares that reservation but does not fill it. Giver and
turn-in are the same existing capital or 31–40 outpost NPC; the actual
kill/drop area is in the front destination. No front NPC, road or POI is
added. Glassroot and Thunderroot's lone givers remain exempt from the
outpost reservation.

Each reserved `front` line has **one permanent repeatable tail**. Allocate
different bands to different hosts instead of giving every host a T5,
T6 and island repeatable. The format has no upper acceptance level or
quest replacement rule; this arrangement respects the two-line limit
without inventing either feature.

There are seven required front reservations per faction: the four
outpost quest NPCs in the two non-exempt contested zones, plus one giver
in each of the three capitals. A useful allocation for C3g is:

| Reserved host slots per faction | Assignment |
|---|---|
| Two outposts | Lower and upper Shattered Line hunting, T5 |
| Two outposts | Gravesalt and Skyglass hunting, T6 |
| One capital | T5 material recovery |
| One capital | T6 material recovery |
| One capital | L60 island salvage, with the second island available through a multi-objective contract if sensible |

This is a capacity-safe allocation, not an NPC assignment by C1b. C3g
may exchange a slot for optional elite work only after showing a solo
route still reaches its target. Keep that optional work at the end of
its allocated line, with no required quest behind it. A solo named normal
leader is another possible endpoint and preserves the main route's
difficulty promise.

Both factions receive equivalent solo access and budgets, with their own
voices and return journeys. At 41–60 the target is about **70% questing,
35% rewards including a finite, stated number of repeat completions**.
Use the ledger with the selected host route, `--lines front`, the band
entry level and `--repeat N`; publish N (Round 29 published N = 2,
`quests.md`). Never count all available hosts' bounties in every player's
baseline. At 60 the islands are reached by boat only (flight is forbidden
over the ocean, the channels and the islands; WP17); island rewards are
coin/material incentives and contribute nothing to the leveling budget.

## Labels and scheduling

The dialog, quest log and HUD all say **Repeatable**. Titles can carry
`Optional` or `Group` when appropriate; text states the destination,
day/night window, return giver and cooldown after turn-in. For example:
“Skeleton patrols gather by the western clash site after dark. Recover
their orders and return here; the next contract opens twenty minutes
after you hand these in.” The actual area must exist in the zone data.

Do not repeat travel-only handoffs for XP. A repeatable gathering order
must pass a buy-and-turn-in audit before porting: buying all inputs from
the cheapest applicable vendor must cost more than the copper plus the
vendor value of reward items. Prefer generic loot or active-quest recovery
pieces where a bought-material XP shortcut would replace the outing.

Two 20-minute hunting cooldowns can support three paired trips with
roughly 40 minutes of cooldown spacing between the first and third
turn-ins. Travel, fighting and one-time quests occupy that interval;
do not tell the player to stand at an NPC. If a real route cannot fit its
budgeted repeats naturally, lower the required repeat count and move
that XP into one-time content. Cooldowns are not simulated by the ledger.
