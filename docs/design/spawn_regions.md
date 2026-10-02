# Spawn regions

How a zone's surface mobs are placed: a **recipe** of rules per zone, turned
into **regions** on the zone's own terrain for whatever seed the world has.
Decided with the user on 2026-10-02 (Round 28 Lane S1); the runtime rules
(spawner, light, protected ground, density, camps, leaders) are in
[biomes_mobs.md §4.2](biomes_mobs.md#42-spawn-regions-round-28-rulings-3-34-37-38-lane-s1).

## Why

- **The world differs per seed.** A coordinate picked on one seed's map is
  wrong on most others, so zone data holds rules, never coordinates.
- **Populations follow the terrain.** Beaches, woods, open fields, swamps
  and hills, with levels rising smoothly from the start town toward the
  zone's exit, instead of circles and rectangles placed by hand.
- **The images Jan reviews are what spawns.** One pure Lua module
  (`mods/ENTITIES/grug_mobs/spawn_regions_core.lua`) builds the region map in
  the game and in the offline renderer (`tools/r28_regions/run.sh`), from the
  same analytic world the mapgen builds terrain from.
- **No empty land, no dominating fallback.** Every land cell of the zone
  belongs to exactly one region.

## How a region map is built

The game builds a zone's map on first need (a spawn attempt, a level or
direction query) and keeps it for the session; Dawnmere Fields takes about
0.4 s and holds 0.4–0.7 MB. Same seed and recipe, same map: no random numbers, no dependence on
table order.

1. **Cells.** The zone on a grid of 32 × 32-node cells aligned to world
   multiples of 32, each sampled on a 4 × 4 sub-grid (8-node pitch; an 8 × 8
   sub-grid moves 0.5 % of the cells in or out of the land and changes the
   type of 1.6 %, at 2.7 times the cost). A cell belongs to the zone owning
   most of its samples; with fewer than half land samples it is water. Per
   land cell: majority biome, mean height, slope (mean height step per node
   between neighbouring samples), the shares of its land samples within 16
   nodes of sea water (shore) and of river or lake water (bank), within 16
   nodes of a road, village or start town / capital (the drift band of Round
   28 ruling 2), and on protected ground; its distance to the nearest road.
2. **Progress.** Graph distances over the land cells (eight neighbours, so a
   bay is no shortcut) from the recipe's `from` anchor (`d_from`) and to the
   land cells bordering its `to` zone (`d_to`); progress = d_from ÷ (d_from +
   d_to): 0 at the town, 1 at the exit. Cells cut off over land take the
   progress of the nearest reachable cell.
3. **Belts.** The cells sorted by progress are cut by area share (e.g. 10 /
   30 / 30 / 30 %), so every belt has its share on every seed. A belt's
   `max_from` (nodes of graph distance from `from`) moves cells beyond it
   to the next belt; that belt then ends smaller. Where the exit lies close
   to the start, progress climbs faster than a belt is wide, so a final pass
   steps cells down until no cell is more than one belt above a neighbour.
4. **Terrain types**, first match: `shore` (at least 25 % of the cell's land
   within 16 nodes of the sea), `bank` (the same for rivers and lakes),
   `swamp` (majority biome swamp), `forest` (majority biome deep_forest,
   elf_forest, pine_hills, bone_forest, deep_jungle, jungle_edge or
   jungle_fringe), `highland` (slope ≥ 0.5, or a mean height at or above
   both the zone's 90th height percentile and its median + 16), `open`.
5. **Regions.** Connected cells (eight neighbours) of one kind, the kind
   each belt gives each type (step 6). Fragments under 8 cells (3 for shore
   kinds: a narrow beach stays a region) join the neighbour region they
   share most edges with: same belt first, then a neighbour whose belt keeps
   the fragment within one belt of all its other neighbours (preferred, not
   forced). The step-down pass of step 3 is what keeps neighbours within one
   belt; the renderer's stats report the largest belt difference between
   adjacent regions as the check (1 on every Dawnmere seed). Regions over 40
   cells split into ⌈size ÷ 25⌉ compact parts
   (farthest-point seeds grown together, three Lloyd rounds). On Dawnmere
   regions are 3–40 cells, median 12–19 (about 100–200 m across); a lone
   islet cell with no land neighbour stays a region of its own.
6. **Population.** A belt maps each type to a **kind**: a name, a day and a
   night roster and a density class. A type without its own entry uses the
   belt's `open` kind (the explicit parent rule). A role's levels in a region
   are the belt's levels ∩ the role's catalogue levels.
7. **Camps.** Candidates are cells of the camp's belt whose 3 × 3 block is
   land of the zone, unprotected, outside the drift band, at least 48 nodes
   from roads, mean slope ≤ 0.35, and at least `apart` cells from the other
   camps. Score: 2 for a forest edge (forest within two cells, but not all
   round), 1 for highland in the block, then flatness and road distance;
   ties to the first cell in grid order. The 3 × 3 block is the camp's own
   region; members stand within 40 nodes of its centre. No candidate is
   logged as a problem; the camp and its leader are then missing.
8. **Leaders** stand at a camp centre, or on the cell farthest from roads in
   the largest region of a kind; their level is the top of their region.

Unchanged by regions: underground and water spawns, rares, vendors, guards,
the mapgen.

## The recipe

`mods/ENTITIES/grug_mobs/data/zones/<zone_id>.spawns.json` holds
`{"zone", "recipe"}`; a zone without a recipe holds `{"zone", "palette"}`
(today's spawning). Every load error names the zone and the path.

```json
"recipe": {
  "from": {"anchor": "start"},
  "to": {"border": "elandor_goldmead_vale"},
  "belts": [
    {"id": "l1_2", "share": 10, "levels": [1, 2], "max_from": 180,
     "kinds": {"open": {"id": "home_fields", "name": "Dawnmere Home Fields",
       "day": [{"role": "small_boar", "weight": 1}],
       "night": [{"role": "large_rat", "weight": 1}], "density": "normal"}}},
    {"id": "l3_4", "share": 30, "levels": [3, 4], "kinds": {
       "open": {"id": "meadows", "...": "..."},
       "swamp": {"id": "reedbeds", "name": "Dawnmere Reedbeds", "day": "open",
         "night": [{"role": "braindead_zombie", "weight": 1}], "density": "sparse"}}}
  ],
  "camps": [{"id": "bandit_camp", "name": "Dawnmere Bandit Camp", "belt": "l8_10",
    "roster": [{"role": "confused_bandit", "weight": 1}], "slots": 6,
    "respawn": [30, 60], "min_player_distance": 16, "apart": 8}],
  "leaders": [{"role": "confused_bandit_chief", "at": {"camp": "bandit_camp"},
    "respawn": 300}],
  "critters": ["rabbit", "wild_turkey"]
}
```

- `from`: an anchor slot or anchor id of the zone; `to`: `border` = the
  neighbour zone (or a list) whose land border is the exit.
- `belts`: shares in percent adding up to 100; `levels` inside the zone's
  band; optional `max_from`; `kinds` keyed by type, `open` required.
- A kind: `id` (unique among the zone's kinds and camps), `name`, `day` and
  `night` (a roster, or `"open"`: the belt's open roster for that clock),
  `density` `sparse` / `normal` / `dense` (0.5 / 0.75 / 1 of the zone's
  density budget, never above it).
- A roster: one main role and at most one minor role of at most 25 % of the
  weight. Every role must meet its belt's levels (load error otherwise).
- `camps`: `belt`, `roster`, `slots`, `respawn` [min, max] seconds,
  `min_player_distance`, `apart` (cells between camps).
- `leaders`: a catalogue role marked `"leader": true`, `at` `{"camp": id}`
  or `{"kind": id, "pick": "farthest_from_roads"}`, `respawn` seconds.
- `critters`: ambient critters that keep their ABM rows in the zone.

## Quests

A quest's kill objective or quest drop limited to an area names
`<zone>/<kind id>` (or a camp id): it credits by the mob's `_grug_area` tag,
so it works on every seed however many patches the kind has. Its levels for
the quest checks are the kind's (the union over its roles). A leader is
named by its role, without an area.

## Directions

Quest texts may name directions derived from the real placement of the
seed (`grug_mobs.spawn_regions.describe(zone, target, mode, ref)`):

- target: a leader role (its spot), a camp id (its centre) or a kind id —
  the centroid of the kind's **largest** region, in every phrasing, so two
  placeholders of one quest never point at different patches;
- `"of"`, ref = a settlement key or anchor id (name from the settlement
  roster) or `{x, z, name}`: "southeast of Highcourt"; within 80 nodes:
  "near Highcourt";
- `"from"`, ref = the speaker's position (the giver): "southeast from here";
  within 80 nodes: "nearby";
- `"zone"`: the target against the zone's land centre, measured in shares of
  the zone's half extent so a long zone's east end reads east: "in the
  southeast of Dawnmere Fields"; within 30 % of the half extent: "in the
  heart of Dawnmere Fields".

Eight directions (north, northeast, east, … northwest; +z is north). The
result carries `dir`, `distance` (nodes), `phrase_key` (`dir_of`, `near`,
`dir_from_here`, `nearby`, `zone_dir`, `zone_heart`) and `phrase`, for
placeholders such as `{dir_from_giver:<kind>}`, `{dir_of:<place>:<kind>}`
and `{zone_area:<kind>}`. A kind with patches all round its giver (on
Dawnmere the meadows, pastures and borderlands) is pointed at by its largest
patch only; the per-seed stats under `docs/planning/round28/regions/` list
how many patches lie in another direction.

## One level truth

In a zone with a recipe the gameplay level of a surface column is its
region's level (the middle of its belt): `grug_core.mob_level_at` and
`grug_core.surface_mob_level_at` consult the region overlay, so mob levels,
the fishing band and the bandit loot level match the mob map. The analytic
level field (`grug_zones.*_level_at`) stays the mapgen's own and is never
overlaid; below y = 0 the depth term applies unchanged. ABM spawn gates that
read the analytic field only run in zones without a recipe.

## Review images

`tools/r28_regions/run.sh [ZONE] [OUT_DIR] [SEED ...]` renders a zone's
regions for several seeds (base map, regions by kind, belt borders and level
labels, camps, leaders, legend with rosters, describe phrases) and writes a
stats file per seed. Dawnmere: `docs/planning/round28/regions/dawnmere/`.
