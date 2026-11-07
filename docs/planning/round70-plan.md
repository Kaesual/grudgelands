# Round 70 — spawns, Stonewright, castles, start towns, death penalty

Planned with the user on 2026-11-07 from player reports and the user's notes.
**Not started:** the round starts on the user's "go". Routing (user, 2026-11-07):
Opus 5.5 coordinates, implements and reviews; GPT-6 Astra makes the art proposals,
the quest texts and the 2D drafts of the new capital cores. Version **0.70.0**,
classification **map reset**.

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

Lane D expands this list.

- Rock Salt, Stormkelp, Wild Cocoa, Frost Melon, Bamboo and Sugar Cane can be found
  where the rules say.
- A harvested shore plant returns while a player stays nearby.
- A crop field ripens spread out, not at once.
- Every plant of §2.3 can be picked up and placed; Waterlily, Seagrass, Liana,
  Hanging Moss and Waterweed sit correctly.
- Thread shows its new icon. Corn touches the ground. A hoe picks up items.
- Crafted and picked-up potions reach the belt first.
- Stonewright: each rank's recipes, lots, fee, the grinder and furnace, each block.
- Death lowers durability by 10%, can break an item, costs nothing after PvP; both
  HUD hints appear and clear.
- Kings at 70, dragons at 70 with 30,000 HP, the rift boss's item level, the crown's
  results and refusals.
- The new level malus: fights 1–3 levels above you, elite group quests, Generals.
- Each capital: core, castle, throne room, gates, patrols, king fight.
- Each start town: centre, waystone, a walk from spawn to the first quests.
- Wayposts at road junctions show readable town names.
- Web client: the new art and the HUD hints.

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
