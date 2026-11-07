# The Last Mint — levels 60–69 Expedition

**Revised draft, 2026-11-07; four players.** Build in Round 72 after the
Round 71 GUI test. [Concept §9](round71-expeditions-concept.md#9-after-the-build-three-expeditions-user-2026-11-07)
and the [built rules](../design/expeditions.md) set the frame. Applies the
Opus review and the user's decisions of 2026-11-07; room dressing is a
Round 72 build target. **Compatible:** documents and drawing tool only.

## Story and place

A survey crew followed stolen battlefield pay into a buried branding works.
Its furnace is a lava lake; masonry pillars are the only crossing to the
press. The soot factors withdrew, leaving **Duewarden** guarding the machine
that burns the Tithe-Brand into stolen coin.

**The Accord's** Charter of Stone wants the owners accounted for; **The
Throng's** Oathdelvers want the buying of names stopped. Each acts independently.
This closes **one workshop feeding the Undertithe**. Ordinary money stays
ordinary; branded stock is scenery. No earlier Expedition or story chapter
is required, and no path beyond the overworld opens.

A **static block-built press** bears the broken-circle-and-two-hooks brand:
a **node mosaic** of Iron Blocks on pale Stone Blocks. Kill its guard so
the guild can dismantle it. First, cross the furnace that feeds it.

## Character and decoration

The borrowed room envelopes are **mirrored on z**, then shaped as masonry
works. Existing nodes from the [catalogue](../../tools/building_templates/nodes.json):

| Room | What the player sees on entering; palette |
|---|---|
| **0** | A bent receiving recess, thick jambs and a closed side arch. **Stone Brick, Stone Block, Iron Bars, closed barrels.** |
| **1** | Deep bin pockets, one crushed corner and rails ending at stacked pay bins. **Stone Brick, Cobblestone, Mine Rail, Ore Cart, Iron Blocks.** |
| **2** | A low furnace vault; black ribs frame the bright crossing mouth. **Basalt Brick, Desert Stone Brick, Iron Bars, Hanging Lanterns.** |
| **L** | Clipped landings open onto a tall furnace throat; five piers rise from the glow. **Basalt Brick, Stone Block, Lava Source.** |
| **3** | A chamfered, low-roofed cooling recess; empty wall racks frame the regrouping floor. **Stone Brick, Slate Tile, Iron Bars.** |
| **4** | A cross-shaped vestibule, heavy buttresses, low ribs and recessed anvils. **Basalt Brick, Iron Blocks, Display Anvils.** |
| **5** | A chamfered hall: Duewarden on a one-node dais, black press behind, pale brand overhead. **Basalt Brick, Steel Blocks, Iron Blocks, Stone Blocks.** |
| **6** | A clipped-corner strongroom; mineral niches around chest and waystone. **Stone Brick, wood planks, Iron Bars, Hanging Lanterns.** |

Props remain wall-side, capped into the masonry where they could become
perches. No floor holes outside the lake; the dais has a one-node step all
round, reachable by mobs. Six-node routes stay clear. In wisp rooms **2/3/4**,
ceiling ribs alternate clear tops **y=37/38**, at most seven air nodes;
geometry limits flight height without new flight behaviour. Exact dressing
is Round 72 work; the silhouettes and solid separating walls stay.

## Route and encounters

**0 → 1 → 2 → L → 3 → 4 → 5 → 6**; target **10–20 minutes at 60**,
measured in the build. Balance for **Warrior, Priest and two others**,
no particular talent build. Enemies and
gear use **60–69**, **T6 throughout**; players cap at 60, making 61–69 hard.
Entry is `min(run level − 2, 60)`; fewer players do not reduce encounters.

Existing **Lava Seep** (`lava_flan`), **Ember Wisp**, **Bedrock Sentinel**
(`land_guard`) families all exist at 60; Expedition levelling extends them
through 69. Reuse their attacks; wisps shoot and close in beneath the low ceilings.

| Room | Encounter | Role and movement task |
|---|---|---|
| **0 · Arrival** | Start waystone; no mobs/resources. | Gather and prepare. |
| **1 · Salvage bins** | **a:** 4 normal Lava Seeps. | Warrior gathers; others focus one; Priest heals sustained melee pressure. Ore beyond the pack. |
| **2 · Furnace room** | **b:** 2 normal Seeps, 1 elite Seep, 1 normal Wisp; 2 floor traps. | Warrior holds the elite on clear floor; others close on the wisp; Priest moves between heals. Finish before crossing. |
| **L · Lava crossing** | Five pillars, 2 wall projectiles, **no mobs**. | Everyone times their jumps; watch a shot pass, then jump. Heal on solid tops, one step back from the edge. No movement talent needed. |
| **3 · Cooling room** | **c:** 2 normal Seeps, 1 elite Seep, 1 normal Wisp. | Regroup on the landing, then pull. Warrior holds well inside; others focus wisp; Priest restores the party. Gem beyond the pack. |
| **4 · Press vestibule** | **d:** 1 elite Sentinel, 2 normal Wisps; 2 floor traps. | Warrior turns the warned slam away; others finish wisps; Priest keeps sight while moving out of rings. |
| **5 · Press floor** | **Duewarden**, one elite boss, alone; 2 floor traps. | Keep melee pressure, avoid the slam, shift the fight when a ring appears. |
| **6 · Store** | Personal chest inventory, six mining places, end waystone. | Loot, mine and leave without recrossing. |

**Starting roster: 8 normal Seeps, 2 elite Seeps, 4 normal Wisps,
1 elite Sentinel, 1 boss.** The build's `balance.py` at **four players** sets
final counts: add one normal per pack before raising HP. The elite Seeps in
**b/c** get the existing wind-up. Packs pull whole,
never give up, refill after a wipe; fully dead packs stay dead. Death returns
to room 0 with the normal penalty: cross the lake again. The return route
stays open; no checkpoint. Sealed box far under the sea; no building, riding
or flying. Only marked ore and gems can be dug.

## Traps and the lava lake

Traps ignore mobs, including projectile collision. Choose uniformly without
replacement within each listed group, once per creation; preserve choices
and revealed marks after wipes. Same shared tuning as
[The Second Shift](round72-second-shift.md#traps-and-the-boss).

- **Floor:** **6 of 12**, two each in rooms 2/4/5. Invisible foot trigger;
  muted red ring for **1.5 s**, strong damage; rearm **10 s after firing**,
  visible **from their first firing** for the run. Propose radius
  **0.6 trigger / 2 damage**, damage **45% of the run level's neutral HP pool**
  before ordinary mitigation.
  Move the fight instead of trying to heal through repeated stamps.
- **Wall:** **2 of 4** sockets: one over **P1–P2 or P2–P3's gap**, one over
  **P3–P4 or P4–P5's gap**. Every **6 s**, always; speed **8 nodes/s**,
  fixed directions in the plan. First group
  begins on readiness, second 3 s later. Fireballs cross the basin at
  **y=32.5**, about 1.5 s from muzzle to pillar line. Stone stops them; a
  player hit bursts in radius 2 for the proposed trap damage. No knockback,
  terrain or mob damage. **Every top is clear of shot lines.** Wait one step
  back from the edge, watch a shot pass, then jump; cross separately.

The lake lies **between packs b and c**, before the boss rooms. Only its
basin/rim needs modelling. Two landings and five **4 × 4** pillar tops give
six **2-node gaps**, **height change 0**. Four-node runways permit ordinary
walking jumps. No sprint or class skill required. A miss drops **24 nodes
to lava**, which takes **20% of actual max HP each second**, bypassing shields:
five ticks kill an unhealed full-health player. Vertical sides give no
shelf, ladder or climb; tops are beyond a single Blink from the lava.
No mining or enemy waits below. **Return Home refuses while standing in lava
inside an Expedition**; ordinary out-of-combat logout/login is unchanged.

## Duewarden

Reuse the **Sentinel's body, melee and signalled frontal slam**. Warrior
faces it away; Priest and damage dealers leave floor rings. The static press
and placed traps need **no new boss behaviour**; traps cannot hurt Duewarden.

Its **solid, connected room inside a 32 × 32 envelope is its range**;
no pits or safe ledges.
It cannot pursue into passages or the lake. A wipe or **15 s without an
attack** resets it at full health; traps do not refresh that timer. Death
opens the store, gives damage/healing participation credit and no ground loot.

## Ore and rewards

**Eight shared places:** ore after a, gem after c, then four ore and two gems
in the store. Preparation fills **ore/gem markers at T6** for all 60–69;
an ore place holds Abyssal Crystal, a gem place Diamond (user, 2026-11-07).
All places have dry footing and solid backing; none on pillars or lake walls. The Expedition
filter removes mineral drops inherited from seeps, wisps and Sentinel.
Neither mobs nor chest provide raw ore/gems.

One chest behind Duewarden gives separate inventories, including to eligible
members entering after the kill. Proposed baseline: **1 Uncommon item, 25%
chance of 1 Rare item, a Bag of Coins worth ten kill bags, 3–5 Stone Core
(T6), 1–2 Slime Gel** from the Seeps as flavour. Gear uses run level and T6;
check income/XP before fixing amounts. Mining must stay clearly below the same time of
ordinary T6 mining per player. End waystone beside it; both waystones return
to the departure capital. Waystones and Return Home refuse combat.

## Optional quest: Party: The Last Mint

**Level 60**, opens at 58; once per character, free, group-marked; no
prerequisite, follow-up or `story` flag. **Kill Duewarden (1)** at any run
level. Proposed level-60 XP/copper, weight 4; no reputation or essential
item. Repeat runs need no quest.

Guild-house givers/turn-ins: **Alis Cartwright, Hadrin Beamset, Caelir
Veinward** for The Accord; **Drava Flintshoulder, Iven Lastshift, Ombali
Ropekeeper** for The Throng. Six capital variants of one quest, two faction
texts; return to the giver. The registrar handles entry.

**The Accord — offer**

> Branded coin has to come from somewhere, and our crew found where: a buried works that burns the Tithe-Brand into pay stripped from the battlefield dead. Every coin it strikes enters another name on the Undertithe's roll, and the Undertithe reads that roll as a deed. Duewarden guards the press, past a furnace that is now a lava lake with pillars for a bridge. Ask this guild house's registrar for The Last Mint Expedition, take three companions, and kill Duewarden. Watch the fireballs before you jump. There is no ledge below.

**The Accord — completion**

> Duewarden is dead, and the last mint has struck its last coin. The Charter of Stone will take the press apart and enter every piece in the record. The branded stock goes under seal, uncounted and unspent; nobody draws wages from that chest. It was one workshop among however many there are. Today there is one fewer, and the roll got no new names from it.

**The Throng — offer**

> The soot factors have a mint. They buried it behind a furnace they let run to a lava lake, and its press burns their mark into coin from the graves of both armies, ours among them. Every coin it strikes buys the Undertithe another name. Duewarden guards the press. Ask this guild house's registrar for The Last Mint Expedition, take three companions, and kill Duewarden. Let the fireballs pass before you jump; the lake gives nobody back.

**The Throng — completion**

> Duewarden is down, and the press with it. Our crew will pull it apart bolt by bolt before anyone feeds it another purse. The branded coin stays out of every wage box we own; the dead it was struck from owe nothing to anyone. There will be other furnaces. This one buys no more names.

## Cost and open questions

The base reuses The Stilled Seam's arrival, first two rooms, court and store
envelopes. Beyond the two shared traps, all work is **small**: mirror on z,
shape/dress rooms and basin, lower wisp ceilings; static press and
node mosaic; roster, quest and loot. No custom boss behaviour or medium/large
mechanic. Room boundaries and the 15 s reset are shared Round 72 boss work.

- **Travel decision:** Return Home is refused while the player stands in
  lava inside an Expedition: **one refusal beside the combat check in
  `grug_home/travel.lua`**, small. Out-of-combat logout is no escape while the
  run exists: login returns the player to the lava. No basin logout-as-death
  rule or new persistence. Forced ownership exits and run expiry keep the
  framework rules.
- **Build defaults:** level two-node gaps and shared trap/chest values.
  Model 60/69 with four level-60 players; set counts before HP. Movement
  fallback: wider tops/shorter gaps, keeping fatal falls and required jumps.
- **Round 72 lane D:** clarify [Expeditions §7](../design/expeditions.md#7-the-rules-inside)
  to “players place no liquids”; template lava is allowed.
- **GUI, desktop/web:** six jumps both ways, shot timing with safe waits on
  every top, lava travel refusal/login, low wisps, reachable dais, separate
  pulls, wipe/reset/death return, mining and personal chests. The user's tests.

## Floor plan and build coordinates

Build constraints: game logic runs only on the server, with standard desktop
and web clients. Every cue works silently; no new sound. Budget the shared
traps at 16 particles per warning, 8 per impact, at most 8 live tail particles
per fireball. Persistent marks use the shared trap visual, not dense repeated
spawners; no lake-wide mist. Keep the complete encounter, player spells
included, in the hundreds of simultaneous particles.

![The Last Mint: lake before the boss, four packs, traps and reward room](round72-expeditions/last-mint-plan.png)

Local node indices; rectangles `[x0,z0,x1,z1)` exclude upper bounds, as in the
[built template](../../tools/expedition_templates/sources/stilled_seam.py).
Box **128 × 64 × 128**; ordinary floor at y=31, first air cell **y=32**;
rooms 0/1/6 clear through y=43, wisp rooms 2/3/4 through **y=38** (ribs 37),
boss through y=47, passages through y=37. Keep six clear nodes in passages.
The image labels room envelopes; the generator's `cuts` are full-height
masonry within them. Coordinates below already include **z → 127 − z**
(exclusive bounds `[z0,z1) → [128−z1,128−z0)`).

<!-- floorplan-coordinates:start -->
| Places | Coordinates (x,z), in listed order |
|---|---|
| Pack anchors a / b / c / d; boss | (60,99), (108,99), (108,11), (64,59); (64,23) |
| F1–F4; pick 2 | (100,107), (116,107), (100,95), (116,95) |
| F5–F8; pick 2 | (52,67), (76,67), (52,51), (76,51) |
| F9–F12; pick 2 | (56,31), (72,31), (56,15), (72,15) |
| W1 / W2; pick 1 | (96,68.5) → (120,68.5), +x / (120,62.5) → (96,62.5), −x |
| W3 / W4; pick 1 | (96,56.5) → (120,56.5), +x / (120,50.5) → (96,50.5), −x |
| Ore / gem on route | (79,91), (119,11) |
| Store ore / gems | (8,31), (31,35), (31,27), (8,11) / (8,19), (31,11) |
| Start / arrival / chest / end | (20,99), (20,103), (20,23), (20,15) |
| Reward door | x=44, z=16–23, y=32–37; marker (44,34,19) |
| Passages, in route order | [32,104,48,112), [80,104,96,112), [104,80,112,88), [104,32,112,40), [92,16,96,24), [84,16,92,64), [80,56,84,64), [60,40,68,48), [32,16,48,24) |
| Boss dais; top node y | [60,20,68,28); y=32 (one step) |
| Basin; approach / exit landing | [96,44,120,76); [96,76,120,80) / [96,40,120,44) |
| P1–P5, in crossing order | [106,70,110,74), [106,64,110,68), [106,58,110,62), [106,52,110,56), [106,46,110,50) |
| Pack c: 2 normal Seeps / elite Seep / Wisp | (106,11), (110,11), (108,13), (108,9) |
| Static press recess | [58,8,70,12) |
<!-- floorplan-coordinates:end -->

Spread pack members 2–3 nodes around their anchors. Pack c's listed starting
positions are over 26 nodes from the exit landing; keep that regrouping space
when adding members. Mining at y=33 has plinths and immediate hull backing;
chest/waystones at y=32, Duewarden at y=33 on the dais. The rock strip
**x=80–83, z=8–39** seals the return passage from the boss room.

<!-- floorplan-grid:start -->
```text
################################
################################
##o6...g#####5###.#######3.c.g##
##...E..####..f...f.####......##
##g........D........#.........##
##...C.........^B...#.........##
##.....o####...^^...#..##...####
##o.....####..f...f.#..##...####
##.....o#####.....###..###..####
####...######.....###..###..####
###############..####..#.L....##
###############..####..#~~p~~~##
#############f4....f#..#~~~~~~w#
############........#..#~~p~~~##
############....d......#w~p~~~##
############...........#~~~~~~w#
############.f.....f####~~p~~~##
#############......#####w~p~~~##
########################~~~~~~##
#########################....###
##########################..####
##########################..####
###############1...o#####2..####
##############......####.f...f##
###0.S..####...a....####...b..##
##......####........####......##
##.......................f...f##
##............................##
####....######....#######...####
####...#######....#######...####
################################
################################
```
<!-- floorplan-grid:end -->

One cell is **4 × 4 nodes**, a coarse sample, not jump geometry. `#` rock,
`.` floor, `~` lava, `p` pillar, `0–6/L` rooms, `a–d` packs, `f/w` candidates,
`o/g` mining, `B` boss, `^` one-node dais, `D` door, `C` chest, `S/E` waystones.

### Lake section: the full 64-node height

![The Last Mint: equal-scale section with all six jumps and the lethal drop](round72-expeditions/last-mint-section.png)

The table gives basin, landings and pillars **in crossing order (decreasing
z)**. All five pillars are **4 × 4**, solid from the bed through **node y=31**;
six gaps of two empty node columns, **height change 0** both ways. No walkable
rim joins the landings: basin sides meet full-height walls. All four candidate
shots pass through gaps, leaving every pillar top available for waiting.

Node centres y=0–63 occupy physical faces −0.5–63.5: exactly **64 nodes**.
Bottom rock y=0–1; lava source nodes y=2–7 outside the pillars; lava surface
**7.5**. Tops/rim surface **31.5**, 24 nodes above it; clear air to y=59;
sealed roof y=60–63. Muzzles sit just inside the basin face, at x=95.6 or
119.4, y=32.5; the diagram's x=96/120 identifies the corresponding wall.
The bottom's detailed look does not matter; do not add islands or escape shelves.

At the pinned engine source `df04879066de6eb94ca43996822a6dfacc74feca`,
`src/defaultsettings.cpp:520–528` gives walk speed **4** and jump speed **6.5**;
`src/client/clientenvironment.cpp:133` doubles gravity **9.81**. With ordinary
movement overrides, a level jump therefore has ideal rise
`6.5² / (2 × 19.62) ≈ 1.08`, flight `2 × 6.5 / 19.62 ≈ 0.663 s`, and travel
`4 × 0.663 ≈ 2.65 nodes`. Approach near the edge at walking speed; two-node
gaps leave a margin and four-node tops provide runway. This is a calculation,
not a measured client jump. Source: the pinned [Luanti reference](../reference_projects.md).
The game's [movement owner](../../mods/CORE/grug_core/movement.lua)
and [environmental damage](../../mods/CORE/grug_core/environment_damage.lua)
supply overrides and the 20% lava rule.

Regenerate with `python3 tools/r72_rework/floorplan.py` (tables/grids too);
`--grid` prints both grids, `--check` verifies all generated content. Python 3/Pillow.
Grounding: [guild](../design/miners_guild.md), [story](../design/story.md),
[story bible](round36/story-bible.md), [mobs](../design/biomes_mobs.md),
[classes](../design/classes.md), [quests](../design/quests.md).
