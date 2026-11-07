# Round 70 — spawns, Stonewright, castles, start towns, death penalty

Planned with the user on 2026-11-07 from player reports and the user's notes;
started on the user's "go" the same day. Routing (user, 2026-11-07): Opus 5.5
coordinates, implements and reviews; GPT-6 Astra makes the art proposals, the quest
texts and the 2D drafts of the new capital cores.
**Complete on 2026-11-07:** all lanes merged, then this documentation lane D; main
`c998ea93`: 313 of 313 fixtures, boot PASS, full seed fleet 302 of 304 with both
failures fixed and those seeds rerun OK. The user's picks: Thread A, Grinder B,
Furnace A, all stones A, castle form A. **Not pushed; the GUI test is
[open](#gui-checklist-desktop-and-web)** ([completion](#completion-2026-11-07)).
Version **0.70.0**, classification **map reset**. §2 is the current ruling; what
changed from the first plan is under
[decisions](#decisions-during-the-round). Delivery state:
[STATUS](../STATUS.md).

[Round 71](round71-plan.md) runs beside this round (§7).

## Why

Rock Salt and Stormkelp hardly exist in a world, so quests and recipes that need
them cannot be done. Players asked for block conversion, decorative plants and
potions that reach the belt. The kings' buildings and the start towns' centres
look too small or squeezed. Dying costs nothing. A map reset is due anyway, so
the changes that need one come together here.

## 1. Lanes and order

| Wave | Lane | Who | Goal | Waits for |
|---|---|---|---|---|
| 1 | SPAWN | Opus | Source rules and densities (§2.1), renewal chance (§2.2), the first map-reset declaration | go |
| 1 | PLANTS | Opus | Decorative plants drop themselves and can be placed (§2.3) | go |
| 1 | FARMFIX | Opus | Varied crop growth (§2.2), hoe, corn, potion belt (§2.5) | go |
| 1 | DEATH | Opus | Death penalty, PvP exemption, HUD hints (§2.9) | go |
| 1 | LEVELS | Opus | Kings, crown, dragons, rift boss, T7 rule (§2.10) | go |
| 1 | ART | Astra | Thread icon, grinder, smelting furnace, five ornamented stones, on a pick page | go |
| 1 | DESIGN | Astra, Opus check | 2D land use of the six capital cores and six start towns, on a review page | go |
| 2 | GUILD | Opus | The Stonewright, its recipes and blocks, the removed rule (§2.6) | the user's ART pick |
| 2 | CASTLE | Astra | The castle's shared basic form and the throne, on a pick page | the user's DESIGN review |
| 3 | CAPITALS | Opus | Civic cores, castles and throne rooms (§2.7) | CASTLE pick, GUILD merged |
| 3 | TOWNS | Opus | Start town layouts and waystones (§2.8), mapgen wayposts (§2.4) | the user's DESIGN review |
| 4 | D | Opus | Docs, completion, GUI checklist | every merge |

## 2. The user's rulings (2026-11-07)

Everything here is ruled unless it is marked as a proposal, "to check" or a
first reading.

### 2.1 Spawns (needs the map reset)

Measured 2026-11-07 with the real planner and writer in the seed-fleet harness
(`tools/seed_fleet/runtime.lua`). Spawn counts are initial nodes per world.
All densities below are effective, meaning after
`habitat.initial_denominator`, which doubles the catalogue value for everything
except the two salts. "Today" is counted nodes, "expected after" is eligible
columns times density.

| Source | Today (per world) | Ruled change | Expected after |
|---|---|---|---|
| Rock Salt | 0–1 | whole `grug_beach` biome of the three zones, on sand, gravel or stone, **no water contact**; density stays 1/1024 | about 170–240 |
| Stormkelp | 0–1 | up to 10 nodes from water with a height limit (user, 2026-11-07, replacing 3 nodes without one), on sand, gravel or stone, all five zones; density set so the count stays | about 170–205 |
| Frost Melon | 5–13 | four times the density; check the hosts in Frostbarrow and Ossuary Reach | about 53–56 |
| Wild Cocoa | about 110–130 | effective 1/1024, no halving | about 230 |
| Bamboo Shoot | about 16–33 | effective 1/64 | about 200–260 |
| Sugar Cane | about 85–110 | effective 1/128 | about 370–445 |

- **Why they fall short:** density counts per eligible column, and the shore
  predicates leave a few hundred to about a thousand columns per world. Raising
  density alone only crowds the same short stretches.
- **Consumers at risk today:** quest `ashveil_rock_salt` (6 Rock Salt, level
  53), a level 48 Stormvault Heights quest (8 Stormkelp), `frostbarrow_melons`
  (5 Frost Melons, level 21), a level 53 Lethariel quest (6 Wild Cocoa).
- **Frost Melon hosts:** Ossuary Reach had 0 eligible columns on both measured
  seeds, Frostbarrow 109–177 (0–2 melons), although the quest is there. Cause
  not diagnosed yet.
- **Stormkelp:** Stormscale Summit had 0 eligible columns on both seeds (its
  shore is stone and gravel). The Shattered Line loses its swamp-mud-only rule.
- **Rock Salt shares:** Gravesalt about 117–179, Wyrmglass 32–50, Stormscale
  14–24.
- **Renewal must follow every predicate change:** `vegetation_density.lua`
  and `grug_farming/renewal.lua` read the same rules as the writers. Rock Salt
  stops being a shore row there too.
- **Code that pins the rules:** `r7_p9g.lua` accepts only the shore predicates
  `none`, `dry_cardinal` and `salt_cardinal`, and `shore_matches` reads only the
  four neighbours, so "up to 3 nodes" and "no water contact" need new writer
  logic. `renewal.lua` `SHORE_BAND = 2` assumes a 2-wide band. The gathering
  digest in `wp40/r7_manifest.lua` fails on any catalogue change. Wild Cocoa
  needs either `FULL_INITIAL_DENSITY` or a new catalogue value; the plan picks.
- **Fixtures that pin them:** `tools/r51_terrain`, `tools/r48_farm`.
- **Docs to update:** `biomes_mobs.md` §2.2, `world_zones.md` §11, `farming.md`.
  `world.md` R4 keeps its salt exception.
- **The rest was checked and stays:** every other surface source yields about
  290 to 5,000 per world. Ores and gems are 3-D, without biome or shore
  filters, and were read from the table, not measured. Cave Cap and Ember Moss
  are native decorations the harness cannot measure; check them in a real run.

### 2.2 Wild renewal and farming (no reset needed)

- **Higher renewal chance for shore sources** (user, 2026-11-07). Applies to
  the rows that keep a shore rule, starting at four times the resource chance
  (0.05, `renewal.lua` `CHANCE`). Calculated, not measured: about 1–2 hours per
  Bamboo plant for one player at a good shore at the new density, before this
  factor.
- **Varied crop growth** (user, 2026-11-07). Today every stage takes exactly
  200 seconds (`grug_farming/init.lua` `STAGE_SECONDS`), so a field ripens at
  once. Make it 160–240 seconds per stage, same average. The stored progress
  and the pause and resume path must use the same interval. The salt pan stays
  as it is, although `salt_pan.lua` reads the same constant. `farming.md` states
  the 200 seconds; `tools/r48_farm` fires at 200 seconds.

### 2.3 Decorative plants drop themselves (no reset needed)

Reverses the Round 51 rule "decoration drops nothing" (land plan ruling 11,
`grug_nodes/plants.lua`) for these plants (user, 2026-11-07):

- **Ground plants:** Ruby Fan, Ember Star, Violet Fan, Blush Star, Lilac Bells,
  Cream Cups, Alpine Cushion, Alpine Windshrub, Lichen (both variants), Fern,
  Marram Grass.
- **Foliage:** Jungle Bush Leaves, Withered Bush Leaves, Gravewood Dead Leaves,
  Swamp Leaves.
- **Freshwater Waterlily:** needs its own placement, because it sits in the air
  node above source water.
- **Seagrass, Liana and Hanging Moss:** need their own placement too. Seagrass is
  rooted in the sand bed under water; Liana and Hanging Moss are multi-node
  plants with strands.

- **Brown and Orange Coral** drop themselves instead of Coral Skeleton, like Cyan,
  Green and Pink Coral. A one-value change in `default/nodes.lua`.
- **Freshwater Waterweed** drops itself instead of sand. It needs its own
  placement, because it is rooted in the sand bed under water.

The old rule had two reasons: players should not mistake these for gathering
sources or carry stacks of them. The plan needs an answer to both, starting
with the tooltip. `biomes_mobs.md` §1.3 and §2.1 state the current rule;
`tools/r51_lp` and `tools/r47_sw` pin `drop == ""`. Plants that can now be
carried need a price class and a tier (AGENTS.md "Economy and travel").

### 2.4 Waiting for a map reset

- **Mapgen wayposts** (BACKLOG, Round 67 and 68 carry-overs): the generator
  places them at road junctions with the next change that needs a map reset.
  `grug_signs:waypost` is the node to place.

### 2.5 Fixes from player feedback (no reset needed)

All from the user, 2026-11-07. Causes are first readings; the lanes re-check
them.

- **Thread icon:** Thread needs its own icon, for example a spool of yarn.
  Today it is tinted paper (`grug_professions/init.lua`, line 59). Art: GPT-6
  Astra.
- **Corn floats when grown:** the grown plant's texture has no connection to
  the ground. Check the segmented tiles from stage 3 on (`crop_visual.lua`) and
  whether wild corn shows it too.
- **A hoe cannot pick up items:** first reading: `hoe_on_use` replaces the
  punch and returns on anything but a node (`grug_farming/hoes.lua`), so a
  punched item stays on the ground. Other tools with `on_use` may share this;
  check them.
- **Potions do not go into the Potion Belt:** crafted or picked-up potions go to
  the `grug_potion_belt` list first, into a matching stack or a free slot. Only
  what does not fit goes to the bags.

### 2.6 The Stonewright: block recipes at a guild NPC (user, 2026-11-07)

Several players asked for a way to turn Cobblestone into Gravel and Gravel into
Sand. A Miner's Guild NPC offers this as a service. The capital Mason is ruled
out as the place: it stands only in Dur Brannoc, so The Throng would have none.
The guild house stands in all six capitals with the same sockets.

**Ruling (user, 2026-11-07):** low guild ranks unlock convenience recipes, high
ranks unlock new decorative blocks, for example stone with metal ornaments of
the different tiers.

**Ruling (user, 2026-11-07):** the rule "no copper route into reputation" is
removed. Buying items that give reputation is explicitly allowed; copper is
limited too. Update `AGENTS.md`, `miners_guild.md` §4 and §5, `economy.md`, the
comment in `grug_traders/stock.lua` and the check `tools/r58_guildspec`.

**Rulings on the details (user, 2026-11-07):**

- **Name:** the NPC is the **Stonewright**.
- **Cost:** convenience recipes take a small copper fee, decorative blocks take
  metal bars, Cobblestone and a fee. The amounts are the plan's.
- **Mason:** stays as it is; it does not sell Cobblestone or Gravel again.
- **Shapes:** decorative blocks start as full blocks only, no stairs or slabs.

**Fees (user, 2026-11-07):** as the lane proposed (`grug_guild/catalog.lua`,
`stonewright`): 10 → 10 for 1–2c; ornamented stones 8 Cobblestone + 1 bar → 8 for
5c, 10c, 25c, 60c and 1s 50c.

**Art (GPT-6 Astra):** a grinder and a smelting furnace behind the Stonewright,
and the decorative blocks.

**Unlocks (user, 2026-11-07):**

| Rank | Unlocks |
|---|---|
| 1 | Cobblestone → Gravel |
| 2 | Gravel → Sand, Cobblestone → Sand |
| 3 | Cobblestone → T1 Stone (`default:stone`) |
| 4–8 | one ornamented stone per metal tier: Iron, Steel, Silversteel, Embersteel, Abyssal Steel |
| 9–10 | no recipes; the cloak at rank 10 is the reward |

- **Rank pace:** rank n is earned by mining at tier min(n, 6), so high ranks
  arrive late. This is why decorative blocks start at rank 4.
- **Place (proposal):** the `miners_guild_sorter` socket at the sample table could
  become the service role, as `miners_guild_exchange` did. Round 71 proposes the
  clerk's socket for its registrar, so the two do not collide. The grinder and furnace
  would stand in the ore yard or the hall; they change the six templates
  (`tools/r58_halls/make_halls.py`), which joins the map reset.
- **Window:** reuse the Trade-in window's lots (1 / 5 / 10 / All), with rows
  locked by rank like the reputation page.

### 2.7 Capitals (user, 2026-11-07; needs the map reset)

- **The kings' building becomes a castle:** larger, more powerful, a complete
  rework. The civic core is reworked and grows somewhat too.
- **Lane DESIGN first:** it works out a 2D proposal of the land use for the
  user's review. The castle itself is designed only once the land use is fixed.
- **Throne room:** more impressive, with carpet and ornaments. The throne is
  larger and built from several blocks. Selected Stonewright blocks from §2.6
  may be used, so they must exist first.

**For the plan to check:** the rule "the civic core stays exactly as authored"
(`settlements.md`) ends with this. The six cores have different boundaries, and
a larger core affects the capital planner per seed, gatehouses, patrol loops,
route caches, guard sockets and the kings' encounter rules (`world.md`), whose
bindings hang on sockets.

**Ruling (user, 2026-11-07):** one shared basic form for the castles, not six
individual designs.

**Rulings on the DESIGN review (user, 2026-11-07):** the land-use proposal
(`tools/r70_design`) stands, with its per-place recommendations. The civic core
grows from radius 48 to **56** in all six capitals. Kezamba and Lethariel may move
the core a little away from their lake, so the buildings there have more room.
Lethariel: the crown lake moves 14 nodes north, no new crossing. Kezamba: the
cenote moves 18 nodes north, and the east boardwalk goes, leaving one avenue over
water. The castle is form A, Crownward (`tools/r70_castle`), with a smaller throne.

### 2.8 Start towns (user, 2026-11-07; needs the map reset)

- Rework the layout of the six start towns. The waystone looks squeezed in.
- The waystone no longer has to stand beside the Quartermaster, only near the
  town's centre. This replaces the ruling of 2026-10-22
  (`settlements.md`, the waypoint pad table).
- The town centre may grow a little. The total area does not grow.

Lane DESIGN covers this as a second 2D page.

### 2.9 Death penalty (user, 2026-11-07; no reset needed)

- **Rule:** a death lowers every equipped item that wears by 10% of its maximum
  durability, down to 0. It can break an item. Weapons, shields, spellbooks and
  the four armor slots wear; **trinkets do not** (`durability_repair.md`), so
  they are unaffected. This reverses "no extra durability-on-death" and "no
  replacement penalty" (`progression.md`, Round 18). No XP loss and no item drop
  stay. `durability_repair.md` owns the wear events and gets the new one.
- **PvP deaths cost nothing:** a death counts as PvP when an enemy player dealt
  damage in a fixed window before it, for example 30 seconds. `grug_pvp` keeps
  the time of each attacker's last landed hit per victim, privately. The check
  must run before `settle_death` clears that record and must cover a logout
  death, which is settled at logout and only happens at the next join. The
  existing kill credit window is a separate value (15 seconds, `rules.lua`).
- **HUD hint:** a permanent hint while a broken item is equipped, and another
  while an equipped item is below 15% durability. Small and unobtrusive, but
  clearly visible.
- `tools/r29_e4/income.py --check` runs, because repairs affect income.

### 2.10 Boss levels and item levels (user, 2026-11-07; no reset needed)

[Round 71](round71-plan.md) builds on these. Today: Kings fixed level 65, Fallen Crown raises an
item to its tier's top + 5, dragons fixed level 70 with 18,000 HP (the flat boss
tier in `levels.lua`), `grug_quality` item levels king 65, general 65, dragon 70,
rift 65.

- **Kings** rise to level 70, and so do their item drops. Generals share
  `king_def` (`bosses.lua`), so the 65 there must split.
- **The Fallen Crown** raises an item to its tier's top + 10, at most 70: a T5 item
  to 60, a T6 item to 70, an item at 61–69 to 70. It applies only to items below
  level 70, so it refuses a King's or a dragon's level 70 drop.
  Today a boss drop takes an enchant-only crown at equal level; that ends.
- **Dragons** stay at level 70 and item level 70 and rise to **30,000 HP** (the
  user finds them too easy; changed 2026-11-07 after the level malus numbers, no
  item level 75). Their loot stays as it is, although they now match the Kings'
  item level: Kings have their own challenge, the fight through the capital.
  **Enchants stay limited to T7.**
- **Level malus** (user, 2026-11-07): replaces "free up to 5 levels, then 10
  points per level, floor 10%". A player deals 5 points less per level the mob is
  above them, from the first level, with a floor of 25% at 15 levels:
  `max(0.25, 1 − 0.05 × gap)`. Applies to every mob. Generals at 65 cost level-60
  players 25% of their damage, Kings and dragons at 70 cost 50%. Everyday
  levelling feels this at 1–3 levels above; measured in the GUI test, not modelled.
- **T7** (61–70) stops being "boss drops and crowned items only": instance mobs
  at 61–69 drop it too. `roll_mob_gear` caps every non-boss mob at item level 60
  (`grug_quality/init.lua`), and that cap keeps the level 70 Abyssal Shark out of
  T7. Lift it for instance mobs only; that code change belongs to Round 71.

**Stays:** Generals keep level 65 and item level 65.

**Rift boss:** it stays a level 60 elite and now drops item level 60, not 65
(`grug_quality` `BOSS_DROPS`).

The crown's other effect stays: every enchant gains one tier.

**Docs and pins:** `item_tiers.md` (§4 and more), `combat_stats.md`,
`biomes_mobs.md`, `world.md`, `world_zones.md`, `items_crafting.md`,
`world_map.md`, the `levels.lua` header, the crown comments in
`grug_traders/crown.lua` and `grug_quality`. Fixtures: `tools/r33_c1`,
`tools/r33_c4`, `tools/r45_eu`, `tools/r31_g` (Generals).

Fixtures and docs of the malus: `grug_core/combat.lua`, `combat_stats.md`,
`tools/r36_k`, `tools/r36_r`.

## 3. Shared conventions

- Durability, item levels and prices follow one owner each: `durability_repair.md`,
  `item_tiers.md` and `economy.md`. A lane that changes a rule updates its owner.
- New player-facing strings follow the existing tooltip and UI rules.
- Decorative blocks are ordinary registered nodes with a price class and a tier.
- Anything that changes what towns build goes through the building templates and
  `tools/building_templates/check.py`.

## 4. Lane goals

### SPAWN — sources and renewal

Make the six sources reach the §2.1 counts with the ruled habitats, including
renewal, which must read the same rules as the writers. Diagnose why Frost Melon
has no eligible columns in Ossuary Reach and so few in Frostbarrow, and fix the
hosts. Measure counts per world on at least two seeds with the method of §2.1 and
report them. Owns the version and the map-reset declaration.

### PLANTS — decorative plants

Every plant of §2.3 drops itself and can be placed where it naturally stands. Give
carried plants a price class and tier, and answer the old rule's two reasons
(mistaken for a gathering source, stacks) in the tooltip. Round 51's rule ends in
the design docs.

### FARMFIX — growth and small fixes

Stage times vary as ruled, with an unchanged average, through every path: pause,
resume, offline catch-up. Fix the hoe, the floating corn and the potion belt; re-check
each first reading of §2.5 before changing code. If corn needs new art, report it.

### DEATH — the death penalty

The rule, the PvP exemption and the HUD hints of §2.9. Default window: 30 seconds.
The hints are small and permanent, and they follow equip, repair and wear changes.

### LEVELS — bosses and items

The numbers of §2.10. Generals stay at 65 while Kings rise. The new level malus
applies to every mob. Kings at 70 stay fair: report what the encounter needs.

### ART — pick page

Thread icon (32 and 16 px readable), grinder, smelting furnace, five ornamented
stones, one per metal tier, in the project's art rules. The user picks.

### DESIGN — land use

One 2D proposal per capital core and start town, on a review page. Goals: a more
powerful castle in a somewhat larger core; a start town whose waystone sits near a
slightly larger centre, without growing the town. Show what moves, what a larger
core costs the capital planner, gatehouses, patrols and the kings' sockets. Astra
drafts; the coordinator or an Opus lane checks those costs against the code before
the page reaches the user. Builds nothing. The user reviews and decides.

### GUILD — the Stonewright

The NPC in all six guild houses, the service window with rank-locked rows, the
recipes of §2.6, the picked blocks, grinder and furnace in the six templates
(`tools/r58_halls/make_halls.py`). Remove the rule from every place §2.6 names.
Fee and recipe amounts are the lane's proposal, for the user's decision.

### CASTLE — the shared form

One basic castle form and the multi-block throne, on the reviewed land use, with
room for each culture's look. The user picks.

### CAPITALS — cores, castles, throne rooms

Build the reviewed cores, the picked castle in each culture's palette and the
throne rooms with carpet and ornaments, using selected Stonewright blocks. Every
socket, patrol, gate and king encounter keeps working on every seed.

### TOWNS — start towns and wayposts

Build the reviewed layouts in the six start towns; the waystone table in
`settlements.md` follows. Place wayposts at road junctions in world generation.

### D — docs

The completion section, the GUI checklist, STATUS, BACKLOG, CHANGELOG and the
owners each lane did not reach.

## 5. Rules

- Round workflow and `AGENTS.md` apply; every non-trivial lane gets an independent
  review.
- No lane pushes. Only the user pushes.
- Terrain and POIs stay protected; no sound enters the game without a pick.
- A case the rulings do not decide stops that path and goes to the coordinator.
- Every launch prompt carries the fixture sentence of the lane start checklist.

## 6. Verification

Round workflow §3. World lanes run the `quick` seed fleet, the round ends with
`full`. `tools/r29_e4/income.py --check` for DEATH, LEVELS, GUILD and SPAWN if
prices change. Round end: one smoke boot of main, sync, then the user's test.

### GUI checklist (desktop and web)

Written by lane D from the lanes' excerpts and the reviewers' notes. Each item on
the desktop client and on the web client. Items marked *look* ask for the user's
verdict on a first-look default. Start on a world built by the map reset (item 1).

**What no run has touched yet (first)**

1. **The map reset on a real world.** Run the release's map reset on a world with
   characters: characters, gear, money, quests, professions and waypoints stay;
   the map regenerates; the first boot logs no `[GRUG-SEVERE]`. Lanes booted fresh
   worlds only.
2. **The real king fight in each capital.** In all six (Dur Brannoc, Highcourt,
   Gor Drazhak, Nhal Veyr, Lethariel, Kezamba): pull the King, chase him to the
   great door, cross the leash (30 from where the chase began; the door is 27.3
   from the seat), he walks home up the dais and the two royal guards follow. Lanes
   proved this on a body model and an engine path only.
3. **A real right-click on the Stonewright over the desk** in each of the six
   guild houses, from the front of the waist-height desk. Captures opened the
   window from a script.
4. **The furnace:** one audible loop at the Stonewright's smelting furnace, no
   doubling beside it, fading with distance; the fire reads in a dim hall. No
   capture has sound, and the guild "night" shots look barely darker.
5. **The "1" button at 1024 wide, GUI scale 2:** on the Abyssal Steel row the cost
   line runs into the button and Embersteel's touches it. Click it on both rows.
6. **Hoe and potion at a drop:** click a dropped item with a hoe in hand: it is
   picked up (a broken hoe too); on dirt it still tills. With a potion in hand a
   click picks up and does not drink; with a completely full inventory it drinks
   and the drop stays.
7. **Sale from the belt:** sell a belt potion at a vendor, with no marker on the
   row. Read in code, never run (`r48_sell` stubs the lists).
8. **Waypost arrows** at a road junction: names readable on both sides, each arrow
   points the way its road really goes. The direction is computed; nobody has
   checked it by eye. Long names keep their first word ("Last" for Last Hedge
   Redoubt).

**Level malus and bosses (LEVELS)**

9. **Everyday levelling** with mobs 1–3 levels above you: the ruled 5 points per
   level is felt here; the model says about 18% longer fights and 18% more HP lost
   at +3 at every level. Is it too much?
10. **A level 10 player against a mob 3 levels up:** one kill costs about 1.10 of
    your own pool before armor (modelled). Survivable with normal play?
11. **Elite group quests** at their usual levels with a group: still fair.
12. **Generals** (level 65, item level 65): level-60 players lose 25% of their
    damage; model 16 s and 1.7 pools with three players.
13. **Kings** at level 70: malus 50%; model 27 s and 3.2 pools with three players.
    The malus halves damage threat but **not heal threat**: does a healer lose the
    King to their own healing?
14. **Dragons:** Lv 70, 30,000 HP, model 59 s and 3.7 pools with three players
    (ground fight only, no dive, whelps or hazards).
15. **Drops:** King, General, dragon and rift boss give item level 70, 65, 70 and
    60, "Requires level 60".
16. **Crownbinder:** T5 to 60, T6 to 70, a General's 65 to 70, a 61–69 item to 70;
    a King's and a dragon's 70 refused with "The crown works only on items below
    item level 70."; Help reads "top + 10, 70 at most".

**Capitals (CAP0 and the five capital lanes)**

Each capital: south gate up the approach, forecourt, stairs, hall, dais; the bypass
round the castle to the north gate; the north watch behind the castle; booths,
travel plaza, waystone and mailbox.

17. *Look:* hall and throne by night in each capital: enough light? The computed
    median is 7, the king's head 12; shots are software-rendered.
18. **Dur Brannoc:** forge court, booths; the travel plaza narrowed to 13 wide.
19. **Highcourt:** the bypass west between chapel and castle; chapel doors open
    east, the elder on the doorstep; market walk to the west gate; service court and
    well. *Look:* the orchard belt inside the wall: too dense? **Frame rate:** leaves
    4,840 → 7,121 (+47%), watch it on a weak client and the web.
20. **Gor Drazhak:** the fighting platform beside the door (east stair, breastwork,
    view of the approach); muster court with booths, drill posts, racks, shed.
    *Look:* does the castle's front read right behind the platform?
21. **Nhal Veyr:** the processional walk to the north gate; the vigil hall reads as
    public and apart; ossuary court; the watch's walk through the graves, the leg
    of 48 corners, stele clearance. *Look:* **graves 114 → 529** (the lane's gut
    version; the field list trims it in one line) and 29 gravewood stands.
22. **Lethariel:** the south avenue, court, great door: does the court read as an
    arrival? **The north promenade between the colonnades to the quay's head, and
    the quay both ways, wall ends at the water: no shot shows these, and the shots
    predate the quay's last fix.** Shrine, then the lane to the quay; real fishing
    and the NPCs on the quay; the mere precinct's distance (26–51 off shore, was
    18–35); the north avenue starting at the shore; no crossing.
23. **Kezamba:** east avenue to the forecourt and great door (the east gate on
    land); south avenue past the castle; north boardwalk to the pad's edge, the rail
    never crossing it; moot house flight from the quay walk; fishmonger, the three
    anglers' spots; stable and granary doors. *Look:* **lilies 31 → 9** on the one
    measured seed (only `r51_ft` counts them): enough?
24. **Rivers and POIs** near the moved lakes: nothing odd where the lake's new
    strip meets a POI (the reviewer's scan was inconclusive; the full fleet passed).

**Start towns and wayposts (TOWNS)**

25. **Each of the six towns:** centre and pocket: the waystone stands free in its
    13 × 13 pocket with only the mailbox, reachable from four sides; a walk from
    spawn to the first quests; patrols after a restart.
26. **Silverleaf's** terrace stairs; **Kapok's** stilt approaches, north bridge and
    terrace.
27. *Look:* wayposts at about nine stacks a world on secondary road junctions:
    enough, or also at trails (about 60 more)?

**The Stonewright (GUILD)**

28. **Each rank's rows:** rank 1 Gravel, 2 Sand twice, 3 Stone, 4–8 one ornamented
    stone each, locked rows above your rank; lots 1 / 5 / 10 / All; the fee taken;
    All with a full bag works from its own stacks; a refusal changes nothing.
29. *Look:* machine fronts and seams in each house, the grinder before the west
    window; the five stones alone and in walls; the throne's top row of the five.
30. Thread at 16 and 32 px in a bag and on a tooltip.

**Spawns and renewal (SPAWN)**

31. **Rock Salt** on the beaches of Gravesalt, Wyrmglass and Stormscale, never
    touching water; **Frost Melon** at river margins in Frostbarrow and Ossuary
    Reach; more Wild Cocoa, Bamboo Shoot and Sugar Cane where they grew.
32. **Stormkelp** on sand, gravel or stone in all five zones, a few nodes inland
    on low ground, none on a cliff top. *Look:* the spread inland: 26–35% stand at
    the first node, 28–39% four or more inland. Enough, or should it reach the
    biome's main ground (needs a lower density)?
33. **Quests:** `ashveil_rock_salt` (6, level 53), the Stormvault Heights one
    (8 Stormkelp, level 48), `frostbarrow_melons` (5, level 21; a world can start
    with 4 there, so it may lean on renewal), the Lethariel one (6 Wild Cocoa).
34. A harvested shore plant returns while you stay nearby: about 15–30 min per
    Bamboo plant at a good shore (calculated).

**Plants (PLANTS)**

35. Each plant of §2.3 digs into itself, shows the decoration line and sells at
    1c per 50. Felled tree: decaying leaves and hanging plants drop nothing.
36. **Lily** on a lake and a river, refused on ground and flowing water. **Web:
    pointing at water works.**
37. **Seagrass and Waterweed** on sand under water; dug, the sand stays; refused on
    dirt, and in water 1 deep for the weed.
38. **Liana and Hanging Moss** under leaves or stone; pointing at a run extends it
    at the bottom; dig the middle. Digging the ground under an attached plant throws
    it as an item.
39. Protected ground refuses with the usual hint. Seagrass and coral 24 or more
    nodes offshore cannot be dug (protected water): acceptable?

**Farming and the belt (FARMFIX)**

40. A field ripens spread out (a 9 × 9 field 495–696 s); leave and return: stages
    caught up. The salt pan stays at 200 s per stage.
41. Corn stages 3 and 4 touch the ground (*look:* the shorter plant); wild corn
    unchanged.
42. Crafted and picked-up potions go to the belt first, then the bags; with
    everything full the drop stays; the quickbar shows new potions; a quest reward
    potion lands on the belt.
43. Mail, purchases, loot and a chest shift-click put potions on the belt too (the
    coordinator's default): fine? Turn in Elixir of Precision I from the belt.

**Death (DEATH)**

44. Die to a mob: each equipped item shows 10% less, trinkets unchanged. Ten deaths
    on fresh gear: items break. Help and the README read right.
45. Hit by a flagged enemy, then fall within 30 s: nothing lost; after 31 s: 10%.
46. Hit, log out in PvP combat, rejoin: dead, nothing lost. Strike only, log out,
    rejoin: dead, 10% (the ruling read literally: does it stay?).
47. Below 15%: the amber "Gear almost broken"; a break: the red "Broken gear
    equipped"; repair or swap clears them, relog redraws them; readable on bright
    ground, web too. *Look:* no line in the feed says a death cost durability: leave
    it so? Repair per death costs an Uncommon set about 10–11 minutes of band income,
    a Rare one 19–23 (calculated).

**Web client**

48. The new art (machines, stones, Thread), the HUD hints and the join time with
    the new textures. No lane ran the web client.

## 7. Orchestration notes

- **Start state:** main `829be5dd` plus this plan, committed at the go.
- **Merge order:** wave by wave; SPAWN first in wave 1, because it owns the version;
  D last.
- **Shared files:** `game.conf`, `tools/web_data/upgrade.json` and
  `docs/technical/upgrade-contract.md` are SPAWN's until D. `bosses.lua` is
  LEVELS' until CAPITALS. `grug_inventory` belongs to FARMFIX. The hall templates
  are GUILD's.
- **Decided during the round:** the user's ART, DESIGN and CASTLE decisions, fees
  and recipe amounts.
- **Round 71 runs beside this one:** rules in
  [its plan](round71-plan.md#7-orchestration-notes). Main stays this round's. The
  limit of 8 Lua runs is shared, and the user's GUI test takes one round at a time.

## Completion (2026-11-07)

All lanes are merged on main; this lane D (completion, GUI checklist, status
owners) follows on main `c998ea93`. **0.70.0 is a map reset, the thirteenth**
(SPAWN's declaration, verified: `check_upgrade.py` passes,
[upgrade contract](../technical/upgrade-contract.md)). **By lane:** SPAWN, the GUILD
templates, TOWNS and the capitals (CAP0 and five lanes) are the map reset; PLANTS,
FARMFIX, DEATH and LEVELS are compatible on their own; ART, DESIGN and CASTLE touch
tools only. **Saved state:** no step and no new mod storage. `grug_pvp:logout_death`
gains the value `"wear"` (a 0.69.0 mark reads as a free death); generated wayposts
hold `text` in node meta, part of the map. **Push:** not pushed; origin/main is
`829be5dd` (0.69.0). **Production** runs 0.65.0; its update to 0.70.0 crosses this
one map reset and runs the steps 0.67.0 and 0.69.0. **GUI test:**
[open](#gui-checklist-desktop-and-web). **Sync:** by the coordinator after the
merges. [Round 71](round71-plan.md) goes on beside it on branch `round71`.

### Lanes

Main's first-parent merges from the plan `55aa7708` (lane tip in brackets), in
merge order. Reviews are independent Opus reviews; the Astra lanes had an Opus check
or the coordinator's.

| Lane | Commit | What | Review |
|---|---|---|---|
| ART | `0a7acf25` (`27bb5809`) | GPT-6 Astra's `tools/r70_art/`: pick page, then the picks; pass 2 the burning furnace (8 frames, 0.1875 s, light 8), 128 final files, `INSTALL.md` | coordinator: `--check` PASS twice |
| SPAWN | `cb4cc1b9` (`23a37c5c`) | Six source rows; `near_water` and `no_water` shared by writer and renewal; Rock Salt on whole beaches; Frost Melon gravel and sand hosts in the three river biomes; `SHORE_RESOURCE_FACTOR = 4`; version 0.70.0 and the map-reset declaration; `tools/r70_spawn/` census | MERGE (one stale line, fixed); the height note went to the user |
| PLANTS | `e9cfbb7b` (`ccf293db`) | 25 carried items drop themselves; `grug_decor_plant` (tier 1, 1c per 50), tooltip "Decoration: no recipe uses it."; own placement for lily, seagrass, weed, liana, moss; `tools/r70_plants` | MERGE, two Lows fixed; 400,000-operation conservation test, 0 violations |
| FARMFIX | `1b75812a` (`31f0c1b8`) | `stage_seconds` 160–240 by position hash; every `on_use` item picks up a pointed drop; corn lowered by `[combine`, no new art; potions to the belt first, quest rewards too; `consume_lists` ends with the belt | MERGE, then delta MERGE AFTER FIXES (a comment); fall-through for a drop that cannot be taken added on the review |
| DEATH | `8367943e` (`d734b9bb`) | `wear_death` 10%; `R.PVP_DEATH_SECONDS = 30`, `R.pvp_death`, `register_on_death`, the logout mark; `hints.lua`, the free anchor `gear_hints`; `tools/r70_death` | MERGE; five mutations caught |
| LEVELS | `c9b5a2b0` (`43be9c48`) | Kings 70, Generals 65, dragons 70 with 30,000 HP, `BOSS_DROPS` 70/65/70/60, `CROWN_CAP`, the malus in `level_malus`; `tools/r70_levels` | MERGE AFTER FIXES (text, by the coordinator) |
| DESIGN | `2b67b428` (`c3612f30`), `4139ee4d` (`ae03e821`) | GPT-6 Astra's land-use study `tools/r70_design`: six cores, six towns, 659 schedule rows; five passes | Opus check FIX FIRST on passes 1, 2 and 4, each fixed; `verify.py` PASS at the merge; the user's review |
| CASTLE | `935f18fc` (`a9145b2b`) | GPT-6 Astra's `tools/r70_castle`: three forms, the pick Crownward, the smaller throne, `INSTALL.md` | Opus check FIX FIRST (dark hall, door, stairs, gate), fixed; the user's pick |
| SPAWN2 | `ed320c96` (`a51ec60b`) | Stormkelp `SHORE_REACH = 10`, `SHORE_HEIGHT = 4`, density kept; `p9g_water_rule`; water in 8 × 8 blocks | MERGE AFTER FIXES (a doc line, by the coordinator); 470,450 determinism tests, 0 mismatches |
| GUILD | `14a18e61` (`cb62beaf`) | `grug_traders:stonewright` on the sorter socket, desk, grinder, furnace in six templates; `stonewright.lua`, `nodes.lua`, the Thread icon; the copper rule removed; `tools/r70_guild` | MERGE, no fixes |
| TOWNS | `9b08f88a` (`cad10849`) | Six towns on the study (132 rows), 13 × 13 pockets; `wp40/wayposts.lua`, main writes the text in `on_generated`; `tools/r70_towns` | MERGE after the lane's delta; merge conflict in the `r36_w` baseline resolved by the coordinator |
| CAP0 | `9b77b9ee` (`0d28ed4c`) | `precinct_ring.lua` one source (56, 57, 112, 55), Dur Brannoc complete, `tools/r70_cap` with the guide and shared test | MERGE AFTER FIXES (test, guide, merge rows, a hidden 48 in `atmosphere_zones.lua`, probe) |
| NHAL | `4d328259` (`3dbb2f69`) | Nhal Veyr: castle in crypt, plots on the study, precinct loop, burial ground | MERGE |
| HIGHCOURT | `d13b35a4` (`e21333be`) | Highcourt: castle in white slate, chapel moved 8 west, doors on the bypass, orchards | MERGE AFTER FIXES (a comment, by the coordinator) |
| GOR | `1336a1ce` (`26111311`) | Gor Drazhak: castle in `ors`, muster court 8 east, platform kept | MERGE, two items sent back and fixed |
| LETHARIEL | `90a3409d` (`23064736`) | Lethariel: castle at the west facing east, lake 14 north, quay three wide written outward, no crossing | MERGE AFTER FIXES (both quay arms were severed), delta MERGE |
| KEZAMBA | `ed771e28` (`f8ff7509`) | Kezamba: castle on the terrace at turn 2, cenote 18 north, mask regenerated, one boardwalk | MERGE AFTER FIXES (stilts, forecourt, a comment), fixed |
| ENDFIX | `c998ea93` (`dd3834c3`) | What the round-end gates caught: four NPC facings, one bench, `wayposts.lua` skips a stack in a reserved box (the road grid's circle missed the camp box's corners), `is_seat` in `r36_w2` | delta review approved; three notes in BACKLOG |
| D | this section | Completion, checklist, STATUS, AGENTS, BACKLOG, README, CHANGELOG, ROADMAP, the upgrade contract's Round 70 entry, Help's two lines, comments and design lines the reviews named | independent review |

Plan commits between them: `6d7629ec`, `975a75a0`, `a75b71e2`, `87821252`, `f936ae33`;
the CHANGELOG stub `3a6bc984`.

Main has **313** portable fixtures, seven new (`r70_spawn`, `r70_plants`,
`r70_death`, `r70_levels`, `r70_guild`, `r70_towns`, `r70_cap`); FARMFIX extended
owners' fixtures and has a capture. `mods/` against the plan commit (measured,
`git diff --shortstat 55aa7708 c998ea93 -- mods`): 230 files, +12614 −10033: 74 Lua
files, 126 PNG, 13 templates, 6 layouts, 5 rosters.

### Decisions during the round

**The user** (rulings of §2, then):

- **Art:** Thread A, Grinder B, Smelting furnace A, all five stones A. **The furnace
  always burns,** with animated fire and the shipped furnace loop (no new sound).
- **Dragons stay level 70** and item level 70 with 30,000 HP, loot unchanged, **no
  item level 75**. The first plan had level 75 and item level 75; the change came
  after the numbers of the old malus.
- **Level malus** `max(0.25, 1 − 0.05 × gap)`, every mob, replacing "free up to 5
  levels, then 10 points, floor 10%"; not in the first plan.
- **Land use:** the study stands with its per-place recommendations; civic radius
  **56** in all six; the first plan said only "grows somewhat".
- **Lakes:** Lethariel's lake 14 north, no crossing; Kezamba's cenote 18 north
  without the east boardwalk; neither in the first plan.
- **Castle form A,** Crownward, with a smaller throne (5 × 3 × 7, seat 3 × 2).
- **Stonewright fees** as proposed: 10 → 10 for 1–2c; 8 Cobblestone + 1 bar → 8 for
  5c, 10c, 25c, 60c, 1s 50c.
- **Stormkelp** up to 10 nodes from water with a height limit, replacing 3 nodes
  without one; target unchanged.
- **Frostbarrow as it is:** 4–10 melons.
- **CPU rule (2026-11-07):** no hours of CPU for repeats; no per-lane full run or
  fleet in the capital batch, one of each on main after it.

**The coordinator** (answers to lane questions; the user may overrule):

- FARMFIX: quest-reward potions land on the belt first (built); mail, purchases,
  loot and chest shift-click landing on the belt stay; the belt stays sellable and
  countable.
- PLANTS' three recommendations: tooltip and price on Cyan, Green and Pink Coral too;
  one item per fallen hanging piece; the creative-inventory flags.
- DEATH: a broken item shows only the broken hint; exactly 15% shows nothing; no
  feed line at a costly death until the playtest; a logout death with no enemy hit
  pays (the ruling read literally, for the user at the checklist).
- TOWNS: idle sockets move with their hosts (three schedule deviations); secondary
  roads only, about nine stacks a world.
- SPAWN: Rock Salt and Stormkelp stay under the plan's counts, for the playtest; the
  Stormkelp hosts stay sand, gravel and stone.
- Capitals: court sockets stay off their rows with their furniture (Dur Brannoc 3,
  Nhal Veyr 5, Gor Drazhak `court_work_rack`, Highcourt `court_idle_well`); Lethariel's
  patrol order and quay head stay; Nhal Veyr's 529 graves stay until the GUI test;
  `r51_ft`'s lily check is `>= 5`; no pin tuning for `mere_mourning`, an old outlier
  (the review); `is_seat` tightened instead of changing Kezamba's roof.

### Deviations from the plan

- **CAPITALS split** into CAP0 (shared values, Dur Brannoc, guide, shared test) and
  five lanes, one per capital: six capitals were too big for one context.
- **TOWNS started ahead of its wave,** with GUILD from `2b67b428`: it needed only the
  DESIGN review.
- **The CPU rule** ended the capital lanes' full runs and fleets; each lane ran its
  selection, main ran one full run and one full fleet after the batch.
- **ENDFIX is a new lane:** the round-end gates found what the capital lanes'
  selections did not (`r47_nz`, `r36_w2`, two fleet seeds).
- **Thread icon** was installed by GUILD; the plan named no lane.
- **SPAWN follow-up (SPAWN2):** the user's ruling on Stormkelp reopened a merged lane.
  Density stayed 1/256, against the brief's expectation: the height limit removes the
  cliff columns, so the eligible count hardly grew.
- **Wayposts' text:** the emerge environment has no `get_meta`; an LBM missed blocks
  that went active as empty shells (found by a capture), so main's `on_generated`
  writes the text.
- **Plan's and briefs' code facts:** no capital guild house has a lift; the planner
  turns plots; no Lethariel crossing exists today (`settlements.md` was stale); the
  study's castle rows are older than the picked form, so the built king is at
  (0,5,37), not (0,6,38), and eight castle rows are in `MOVED`; `BREASTWORKS` is a
  start town's.
- **Engine captures:** Highcourt, Gor Drazhak, Nhal Veyr and Kezamba ran two, one over
  budget: the shared probe joined as Accord and guards killed it in Throng capitals,
  and Highcourt's far legs stayed pending from the anchor. Each second run was also
  the lane's smoke boot.
- **The study's drawings,** changed by the lanes (each in its report): Silverleaf's
  lanes, Dawnmere's lanes and hedges, Hearthpine's cross street, Kapok's terrace,
  Highcourt's plaza, forecourt and chapel `inside`, plazas narrowed to 13 wide,
  Kezamba's wider forecourt.

### Numbers worth keeping

From the lanes' reports; measured unless marked.

**Sources, nodes written per world** (seeds 12345 / 3684797457838814663;
`tools/r70_spawn/census.lua`):

| Source | Before | After | Plan |
|---|---:|---:|---:|
| Rock Salt | 1 / 0 | **93 / 156** | 170–240 |
| Stormkelp, reach 10 | 1 / 0 | **176 / 163** | 170–205 |
| Frost Melon | 13 / 7 | **89 / 49** | 53–56 |
| Wild Cocoa | 143 / 97 | **257 / 195** | ~230 |
| Bamboo Shoot | 22 / 29 | **257 / 235** | 200–260 |
| Sugar Cane | 79 / 84 | **393 / 398** | 370–445 |

Rock Salt's miss is the world: seed 12345 has only 113,967 beach land columns.
Frost Melon in Frostbarrow 4 / 10, close to the quest's 5. The plan's "expected
after" counted all matching columns; claims and bare ground remove some. Writer in
the five zones about +12% (2.67–2.76 s → 3.01–3.09 s on 20 chunks), unchanged by
SPAWN2. Renewal: first test 6.5 ms median, 14 ms max; a walking player's worst case
18 ms median, 69 ms max per 5 s service (review). Stormkelp: 26–35% at the first
node, 28–39% at four or more, 90–91% at most 2 above water. Cave Cap and Ember Moss
match their densities (one engine run).

**Growth:** 270,000 stages in each of four regions, 160–240, mean 199.93–200.06
(review, five regions: 199.97–200.04); a row of nine carrots ripens over 545–688 s.

**Bosses (modelled, `tools/r70_levels/numbers.py`; level-60 players, three players,
time / tank damage in pools):** King 65 before 12 s / 1.2, King 70 **27 s / 3.2**;
General before 12 s / 1.2, now **16 s / 1.7**; dragon 18,000 HP 36 s / 2.2, 30,000 HP
**59 s / 3.7**, ground fight only. A normal mob at +3: about 18% longer and 18% more
HP lost at every level; a level 10 player 1.10 pools raw per kill.

**Death (calculated):** one death's repair, six-piece set: Common 13c at 1–10 to 950c
at 51–60, Uncommon 34c to 2850c, Rare 63c to 5700c; Uncommon about 10–11 minutes of
band income, Rare 19–23. A real death in the engine: chest 2000 → 1800.

**Capitals:** core cells and non-air (Dur Brannoc 99,649 → 129,674, non-air +35%;
Highcourt non-air +17%; Nhal Veyr +14%). King's seat to door 27.3 against leash 30 on
all six; Dur Brannoc's peak 33 ≤ 40. Plots against the study's today, 40 seeds on old cores
(CAP0): mean −0.17 to −2.10, worst −9, required missing 0; on the finished cores,
6 seeds: Highcourt −3.00, Gor Drazhak −1.67, Nhal Veyr −0.83, Lethariel −1.00,
Kezamba +1.17; every required plot reached. Core patrol legs ok: Dur Brannoc, Gor
Drazhak and Nhal Veyr 38 of 38, Highcourt 42, Lethariel 30, Kezamba 9 (seed 12345).
Cache `none` legs (1–2 per capital) are no core patrol, not traced. Dur Brannoc
`core()` 0.12 → 0.17 s, heap 25.1 → 32.6 MB (review). Highcourt leaves 4,840 → 7,121;
Nhal Veyr graves 114 → 529; Kezamba lilies 31 → 9 on one seed.

**Towns:** 132 schedule rows, three named deviations; 6–13 waypost stacks a world
over 98 seeds, typically 9; working them out 0.02 s per environment.

**Stonewright:** fees in §2.6; a stack costs about 10–20c, small against T1's 1s 72c
per hour (model); selling never recovers the cost (fixture).

### Checks

- SPAWN: `check_lua`, `check_fresh_server`, `check_upgrade`, `validate.py --game`,
  `income.py --check`; `r70_spawn`, `r48_farm`, `r51_terrain`, `r49_ore`, `r60_herbs`;
  full 305/2 (fixed; `r37_dc` waited for the CHANGELOG stub); fleet `quick` 100/100;
  boot. SPAWN2: full 310/0, fleet `quick` 100/100, boot.
- PLANTS: `r70_plants`, `r47_sw`, `r51_lg`, `r51_lp`, `r51_fw`, `r29_e1`, `r48_world`;
  full 305/2 fixed inside the selection; boot with 38 engine checks.
- FARMFIX: `r48_farm`, `r44_ih`, `r35_f`, `r50_hotbar`, `r56_small`, `r37_ix`,
  `r48_sell`; full 306/0; engine capture on real objects; boot.
- DEATH: `r70_death` (173), `r31_pvp`, `r37_cb`, `r35_f`; full 307/0;
  `income.py --check`; two capture boots; boot.
- LEVELS: `r70_levels`, `r36_k`, `r36_r`, `r33_c1`, `r33_c4`, `r33_c5`, `r45_eu`,
  `r31_g`; full 307/0; `income.py --check`; boot with a probe.
- GUILD: `r70_guild` (3,981), `r58_guildspec`, `r58_rep`, `r58_campnpc`, `r58_halls`,
  `r36_w`, `r34_s2`, `r45_pt8`, `r58_lift`; `check.py`, art `--check`, `write_doc
  --check`, `income.py --check`; full 310/1 (digest, fixed); boot; shots.
- TOWNS: `r70_towns` and 14 fixtures pinning layout, waystones or mail; `check.py`;
  full 309/2 fixed, then full 311/0 on `ab3ce2d8`; fleet `quick` 98/100, the bug
  fixed and both seeds rerun; capture with shots, refreshed; boot.
- CAP0: `check.py`, viewer 56, editor 656; `r70_cap` and the 29 fixtures that build
  the cores; full 311/1 (a river pin, fixed); fleet `quick` 100/100; four boots.
- Capital lanes: `r70_cap <capital>`, the pins `r36_w`, `r51_ft`,
  `r56_freeze_capitals`, `r58_townfix`, `check.py`, plus their own selections (each
  report names them); `plan_seeds` 6 seeds; capture, also the boot.
- ENDFIX: `r47_nz`, `r36_w2`, `r70_towns`, `r70_cap`, `r36_w`, `r56_freeze_capitals`,
  `check.py`, the two failed seeds through `tools/seed_fleet/seed.lua`, both OK. Review:
  rows, reservations and road text identical in main and emerge on one seed.
- **Round-end gates:** on `ed771e28` boot, `check.py`, fresh server, upgrade,
  validate and income green, full 311/2 (`r47_nz`, `r36_w2`), fleet `full` 302 of 304
  (a waypost in a mining camp's box, two seeds); both caught by ENDFIX, the two seeds
  rerun OK. On `c998ea93`: **full 313 of 313**, boot PASS, sync done. The fleet was not
  repeated (the CPU rule; ENDFIX's skip cannot put a stack inside a box).
- **This lane:** `check_upgrade.py`, `check_fresh_server`, `check_lua` on the six
  changed Lua files, `write_doc --check` PASS; `r37_dc` (CHANGELOG, README, version),
  `r70_guild` (reads AGENTS and the guild spec), `r58_guildspec` (the spec), `r41_up`
  (the upgrade contract's rules); the link and anchor check of the touched documents
  (1281 links, 0 bad). No fixture pins the two Help lines. No full run: the
  coordinator's.
- **Not run by anyone:** a real king fight, the web client, the map reset on a real
  world, audio.
