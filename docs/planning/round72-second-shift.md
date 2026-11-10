# The Second Shift — levels 40–69 Expedition

**Revised draft, 2026-11-07; four players.** Build in Round 72 after the
Round 71 GUI test. [Concept §9](round71-expeditions-concept.md#9-after-the-build-three-expeditions-user-2026-11-07)
and the [built rules](../design/expeditions.md) set the frame. Applies the
Opus review and the user's decisions of 2026-11-07; room dressing is a
Round 72 build target. **Compatible:** documents and drawing tool only.

## Story and place

A guild crew found a working mine whose entire shift was dead. **Auditor
Nemm** pays the workers in branded battlefield coin; each payment renews
their duty. The crew withdrew before accepting wages.

**The Accord's** Charter of Stone wants the workers' names freed from a
fraudulent account; **The Throng's** Oathdelvers want the dead's promises
freed. Each guild acts independently. The broken circle and two hooks appear,
but their creditor stays unnamed. This stolen workforce is separate from the
Undead people's old blight. No earlier Expedition or story chapter is needed.

One board reads **“SECOND SHIFT / SAME NAMES / STILL DUE”**. No new item,
model or story tunnel.

## Character and decoration

The route borrows The Stilled Seam's envelopes, **mirrored on x**; the drawing
cuts them into a rough-hewn mine. Existing nodes only, from the
[Seam palette](../../tools/expedition_templates/sources/stilled_seam.py) and
[node catalogue](../../tools/building_templates/nodes.json):

| Room | What the player sees on entering; palette |
|---|---|
| **0** | A bent refuge, boarded collapse and low beams around the waystone. **Stone, Cobblestone, Reinforced Wood, Pine Wood Planks, log posts, benches.** |
| **1** | A desk niche and lit shift board; a cart siding ends in crushed rock. **Stone, Gravel, tables, Wooden Sign, Mine Rail, Ore Cart.** |
| **2** | A jagged cutting, tally alcoves and roof ribs; broken beams lie flush underfoot. **Stone, Cobblestone, log posts, Pine Wood Planks.** |
| **3** | Unequal pay bays fold round the rock screen; benches and lanterns disappear behind the bend. **Stone, Gravel, tables, benches, closed barrels.** |
| **4** | A stepped-edge cavern opens around Nemm's one-node dais; high roof ribs converge above it. **Stone, Cobblestone, Pine Wood Planks, Hanging Lanterns.** |
| **5** | A pocket store, mineral alcoves and a timber-lined chest recess. **Stone, wood planks, closed barrels, Hanging Lanterns.** |

Lanterns on ropes light all bays; broken timber and gravel are floor inlays.
Wall props stay outside the six-node clear routes, with no climbable safe
perch. Floors have no holes; the dais has a broad one-node step on every
side, reachable by mobs. Roof ribs vary height above clear headroom.
Exact dressing is Round 72 work; the drawn rock cuts and pack screen stay.

## Route and encounters

**0 → 1 → 2 → 3 → 4 → 5**, one main floor; target **10–20 minutes at 40**,
measured in the build. Balance for **Warrior, Priest and two others** at the selected level, without requiring
particular talents. Players cap at 60; 61–69 is deliberately hard. Entry is
`min(run level − 2, 60)`; fewer players do not reduce encounters.

Use existing **Skeleton Raider** guards and **zombie/Buried Miner** workers;
Expedition levelling carries them through 69. Add **world name slots for
`skeleton_raider` at 40–49 / 50–59 / 60–69**, through the naming gate; cover
miners through 69 too. Nemm keeps his name. Raiders shoot and strike up close.
**Expedition mobs ignore the Undead truce** (user, 2026-11-07): an encounter
flag and one check in `grug_mobs`' `truce_active`, small build work.

| Room | Encounter | Role and movement task |
|---|---|---|
| **0 · Arrival** | Start waystone; no mobs or resources. | Prepare together. |
| **1 · Timekeeper's desk** | **a:** 2 normal raiders, 2 normal miners. | Warrior gathers miners; others focus one bow; Priest keeps a clear healing line. Ore beyond the pack. |
| **2 · Marking floor** | **b:** 2 normal raiders, 1 elite miner; 2 floor traps. | Warrior holds the elite; others clear bows; Priest moves between heals. Everyone leaves red rings. Gem at the far wall. |
| **3 · Wage room** | **c/d:** each 2 normal raiders, 1 elite miner, 1 floor trap. Rock screen between bays. | Pull one bay at a time. Warrior turns the elite slam away; Priest keeps sight; others leave the screen's bypass clear. |
| **4 · Audit court** | **Auditor Nemm**, one elite boss, alone; 2 floor traps. | Tank keeps Nemm close; healer follows in sight; others avoid the last marked spot. |
| **5 · Store** | Personal chest inventory, six mining places, end waystone. | Share mining, loot and return. |

**Starting roster: 8 normal raiders, 2 normal miners, 3 elite miners, 1 boss.**
The build's `balance.py` at **four players** sets final counts: add one normal
per pack before raising HP. Packs pull whole and never give up; a wipe
restores an unfinished pack, fully dead
packs stay dead. Death returns to room 0 with the normal penalty; the walk
back stays open. Sealed box far under the sea, no building/riding/flying;
only marked ore and gems can be dug.

## Traps and the boss

Traps **never notice or hurt mobs**. Choose candidates once per creation,
without replacement within each group; choices and revealed marks survive
wipes. Unchosen floor candidates are ordinary floor.

- **Floor:** **6 of 12**, grouped in the plan. Invisible trigger, muted red
  ring for **1.5 s**, strong damage, rearm **10 s after firing**; visible
  **from its first firing** for the run. Propose radius **0.6 trigger / 2 damage**,
  damage **45% of the run level's neutral HP pool** before ordinary mitigation. In occupied rooms,
  move the fight onto known clear floor instead of circling blindly.
- **Wall:** **1 of W1–W2**, every **8 s**, always, **+z** across the room 1–2
  passage. Visible fireball: speed **8**, height **y=8.5**, radius-2 burst on
  hitting a player, same proposed damage; stone stops it. No knockback or
  terrain damage. Wait in the cleared room, watch a shot pass, cross its line;
  do not bunch there. First shot on readiness, no targeting.

**Auditor Nemm** reuses the raider's body, bow and attacks, plus the existing
elite wind-up. Every **12 s of combat**, mark the current target's floor
position once and use the floor trap's **same 1.5 s ring and damage** there.
The Warrior keeps melee pressure as the group leaves the old spot clear:
**one position, one delayed hit**.

This boss attack uses the trap helper; its ring ends with the hit, cancelled
on reset/death. Placed traps retain their rearm and persistent marks.

The **solid, connected court inside its 32 × 32 envelope is Nemm's range**.
No passage pursuit or safe ledge. A wipe or **15 s without an attack** heals and resets Nemm;
room traps cannot refresh that timer. His death opens the store, gives
participation credit through damage/healing and no ground loot.

## Ore and rewards

**Eight shared places:** ore after a, gem after b; four ore and two gems in
the store, all reachable from dry floor with solid backing. Preparation fills
**ore/gem markers** at **T4 for 40–49, T5 for 50–59, T6 for 60–69**; no named
mineral baked into the template. At T6 an ore place holds Abyssal Crystal and a gem place Diamond (user, 2026-11-07).
Mobs/chest supply no raw ore or gems; retain the Expedition drop filter.

The chest behind Nemm gives a separate inventory to each eligible player,
including a member entering after the kill. Proposed starting payout follows
The Stilled Seam: **1 Uncommon item, 25% chance of 1 Rare item, a Bag of Coins
worth ten kill bags**, plus **3–5 bone and 1–2 flesh** by band:
**T4 Drilled Bone + Leathery Flesh; T5 Siege Bone + Scorched Flesh;
T6 Unquiet Bone + Salt-Cured Flesh**. Gear uses run level and tier;
the build checks income/XP before fixing amounts. Mining must stay clearly
below the same time of ordinary mining per player. End waystone
beside the chest; both waystones return to the departure capital. Return
Home follows its usual rules; both travel methods refuse combat.

## Optional quest: Party: The Second Shift

**Level 40**, opens at 38; once per character, free, group-marked; no
prerequisite, follow-up or `story` flag. **Kill Auditor Nemm (1)** at any run
level. Proposed level-40 XP/copper, weight 4; no reputation or essential item.
Entry/repeat runs need no quest.

Guild-house givers/turn-ins: **Alis Cartwright, Hadrin Beamset, Caelir
Veinward** for The Accord; **Drava Flintshoulder, Iven Lastshift, Ombali
Ropekeeper** for The Throng. Six capital variants of one quest, two faction
texts; return to the giver. The registrar handles entry.

*0.73.1: "this guild house's registrar" became "the Expedition Registrar" in both offers, since the
Registrar moved to the waystone plaza.*

**The Accord — offer**

> Our crew opened an old working and found the shift still on: lamps trimmed, benches full, and every miner on the board long dead. Auditor Nemm walks the rows and pays each of them in coin burned with a broken circle and two hooks, and every payment signs them on for another shift. The Charter of Stone has audited that payroll and found one entry too many: his. Ask the Expedition Registrar for The Second Shift Expedition, take three companions, and kill Auditor Nemm.

**The Accord — completion**

> Auditor Nemm is struck from the books, the only entry of his the Charter means to honour. The crew will copy the shift board onto a memorial stone, and nobody touches the branded pay: a coin you cannot put down is not a wage. Someone asked whether the lost shifts count as unpaid leave. I told them to write down the names and stop counting the hours.

**The Throng — offer**

> The crew found miners working who should have been resting in their graves. Auditor Nemm pays them with burned coin, and every payment buys another shift. The Oathdelvers never sold those names. Ask the Expedition Registrar for The Second Shift Expedition, take three companions, and kill Auditor Nemm. No paymaster decides how long our dead must work.

**The Throng — completion**

> Auditor Nemm will call no more shifts. We are taking the names off his board and cutting them into the guild hall's stone, beside the living, where they belong. Leave the burned pay where it lies; a coin that will not let go of your hand is no wage. The crew have asked to finish the old working themselves, and this time everyone comes home when the shift is done.

## Cost and open questions

Beyond the two shared traps, all work is **small**: mirror The Stilled Seam's
route on x, carve its silhouettes and dress it; roster/world names, quest and
banded loot; Nemm's one-coordinate delayed hit; the truce flag/check.
The **shift board** needs a named `place` and a `register_on_ready` callback
writing its text to node metadata. Room boundaries and the 15 s reset are
shared Round 72 boss work. No custom art or medium/large mechanic.

- **Recommended build defaults:** the single remembered hit, shared trap
  values and eight mining places. Fallback: omit Nemm's adapter, retain the
  placed traps. Simplify wall dressing if needed, keeping room silhouettes.
- **Tuning:** model 40/49/50/59/60/69 with four players; set pack counts
  before HP. Keep 61–69 hard. Durations and payout remain unmeasured.
- **GUI, desktop/web:** silent cues, mobs reaching every floor position and
  the dais, separate pulls, both factions' truce behaviour, wipe/reset/death
  return and separate chest inventories. These are the user's tests.

## Floor plan and build coordinates

Build constraints: game logic runs only on the server, with standard desktop
and web clients. Every cue works silently; no new sound. Budget the shared
traps at 16 particles per warning, 8 per impact, at most 8 live tail particles
per fireball. Persistent marks use the shared trap visual, not dense repeated
spawners; no lake-wide mist. Keep the complete encounter, player spells
included, in the hundreds of simultaneous particles.

![The Second Shift: rooms, packs, trap candidates, mining and rewards](round72-expeditions/second-shift-plan.png)

All coordinates are **local node indices**; rectangles `[x0,z0,x1,z1)` exclude
upper bounds, as in the [built source](../../tools/expedition_templates/sources/stilled_seam.py).
Box `128 × 64 × 128`; first air cell **y=8**, solid floor at y=7; rooms clear
through y=18, court through y=22, passages through y=13; roof ribs may
lower room ceilings by one node. Keep passages at least six nodes clear.
The screen leaves an eight-node bypass in room 3. Room envelopes are printed
on the image; the generator's `cuts` are solid full-height rock within them.
All coordinates below already include **x → 127 − x** (exclusive rectangle
bounds transform as `[x0,x1) → [128−x1,128−x0)`).

<!-- floorplan-coordinates:start -->
| Places | Coordinates (x,z), in listed order |
|---|---|
| Pack anchors a / b / c / d; boss | (67,28), (19,28), (19,72), (19,108); (63,104) |
| F1–F4; pick 2 | (27,20), (11,20), (27,32), (11,32) |
| F5–F6; pick 1; F7–F8; pick 1 | (27,76), (11,80); (27,104), (11,112) |
| F9–F12; pick 2 | (71,96), (55,96), (71,112), (55,112) |
| W1 / W2; pick 1 | (43,15) → (43,24), +z / (35,15) → (35,24), +z |
| Ore / gem on route | (48,36), (8,36) |
| Store ore / gems | (119,96), (96,92), (96,100), (119,116) / (119,108), (96,116) |
| Start / arrival / chest / end | (107,28), (107,24), (107,104), (107,112) |
| Reward door | x=83, z=104–111, y=8–13; marker (83,10,108) |
| Passages, in route order | [80,16,96,24), [32,16,48,24), [16,40,24,64), [32,104,48,112), [80,104,96,112) |
| Boss dais; top node y | [60,100,68,108); y=8 (one step) |
| Full-height rock screen | [8,88,24,96) |
<!-- floorplan-coordinates:end -->

Wall muzzles sit just inside the passage at z=15.6, y=8.5; the socket
coordinates identify the wall, not a projectile spawned inside stone.

Pack anchors are centres, not piles of mobs: place the members 2–3 nodes
apart inside their bay, with clear headroom and no contact with the next
pack. Mining nodes at y=9 have a plinth below and the hull immediately behind;
waystones/chest stand at y=8, Nemm at y=9 on the dais.

<!-- floorplan-grid:start -->
```text
################################
################################
###2..########1...#######0..####
##......w#w#........####....####
##............................##
##f...f.......................##
##......####........####......##
##..b...####....a...####..S..###
##f...f.####......##############
##g....#####o....###############
####..##########################
####..##########################
####..##########################
####..##########################
####..##########################
####..##########################
###3...#########################
##......########################
##..c...########################
##....f.########################
##f.....########################
###.....########################
######..######4...######.5..####
######..#####......#####o.....##
##......####.f...f..####.....o##
##......####...^^...####o.....##
##....f........B^.........C...##
##..d...............D........g##
##f.....#####f...f.#####..E...##
###...########....######g....o##
################################
################################
```
<!-- floorplan-grid:end -->

One grid cell is **4 × 4 nodes**, sampled coarsely. `#` rock, `.` floor,
`0–5` rooms, `a–d` packs, `f/w` trap candidates, `o/g` mining places,
`B` boss, `^` one-node dais, `D` door, `C` chest, `S/E` waystones.
Image and coordinate table resolve exact positions.

Regenerate both plans and the lake section with
`python3 tools/r72_rework/floorplan.py` (also updates tables and grids);
`--grid` prints both grids; `--check` compares all generated content. Python 3 and Pillow.
Grounding: [guild](../design/miners_guild.md), [story](../design/story.md),
[story bible](round36/story-bible.md), [mobs](../design/biomes_mobs.md),
[classes](../design/classes.md), [quests](../design/quests.md).
