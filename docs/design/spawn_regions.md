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
   bay is no shortcut) from the recipe's sources (`d_from`: the cells of its
   `from` anchors and its land cells bordering the `from` zones) and to the
   land cells bordering its `to` zones (`d_to`); progress = d_from ÷ (d_from
   + d_to): 0 at the entry, 1 at the exit. With `to` core, progress is the
   rank of d_from alone (d_from ÷ the largest d_from), so the cells farthest
   from every source are the top belt. Without `to` (one belt) it is 0
   everywhere. Cells cut off over land take the progress of the nearest
   reachable cell.
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
   share most edges with: same belt first, then a neighbour of another belt
   only when its belt keeps the fragment within one belt of all its other
   neighbours; a fragment no neighbour can take that way stays a small region
   of its own. So **adjacent regions (eight neighbours) are never more than
   one belt apart**: the step-down pass of step 3 makes it true of the cells,
   camps (step 7) and merges keep it, and the renderer's stats report the
   largest belt difference as the check (at most 1 on every seed). Regions over 40
   cells split into ⌈size ÷ 25⌉ compact parts
   (farthest-point seeds grown together, three Lloyd rounds). On Dawnmere
   regions are 3–40 cells, median 12–19 (about 100–200 m across); a lone
   islet cell with no land neighbour stays a region of its own.
6. **Population.** A belt maps each type to a **kind**: a name, a day and a
   night roster and a density class. A type without its own entry uses the
   belt's `open` kind (the explicit parent rule). A role's levels in a region
   are the belt's levels ∩ the role's catalogue levels. **Coverage:** every
   zone runs to its round level (a start zone 1–10, the next zone 11–20, …),
   so the next zone starts at the next round level. A kind's roster covers
   its whole belt at each clock (its roles' ranges leave no gap and reach
   from the belt's bottom to its top), a camp's roster has no gap and reaches
   its belt's top (it may start higher: bandits L9–10 in an L8–10 belt), and
   the last belt ends at the top of the zone's band. The game refuses a
   recipe that breaks this at load; `validate.py` reports `E-recipe-cover`.
7. **Camps.** Camps on a POI come first: the centre is the POI's anchor
   (fitted per seed), the camp's region the zone's land cells within the
   camp radius (40 nodes, box distance to the cell), its belt and levels
   the camp's stated `belt` (checked at load like any camp's, so the camp
   stands on every seed and its quest levels are exact). The belt the POI's
   cell lies in differs per seed (Goldmead's bandit camp lies in L14–16 on
   seed 42, in L17–20 on seed 7); the renderer's stats name it per camp and
   add a WARNING when it lies more than one belt from the stated one (the
   game logs the same). Each camp claims its POI's own cell before the
   cells round it, so two close POIs both keep a region (two POIs in one
   cell: the second is a build problem). The region keeps the 40-node
   footprint (no ambient spawns there), but the members stand within 24
   nodes of the POI, near its tents: a POI may lie close to a road or an
   outpost. A camp's cells take its belt, so a cell round the POI joins the
   camp only where its neighbours outside the camp lie within one belt of it
   (the POI's own cell always joins; a stated belt more than one from the
   land beside it is a WARNING). Then the generated camps: candidates are
   cells of the camp's belt whose 3 × 3 block is land of the zone, outside
   other camps, unprotected, outside the drift band, at least 48 nodes from
   roads, mean slope ≤ 0.35, at least `apart` cells from the other camps
   (POI camps included), and whose block's neighbours lie within one belt of
   the camp's. Score: 2 for a forest edge (forest within two
   cells, but not all round), 1 for highland in the block, then flatness
   and road distance; ties to the first cell in grid order. The 3 × 3 block
   is the camp's own region; members stand within 40 nodes of its centre.
   An aggressive camp member, like an ambient spawn, never stands in the
   drift band.
   No candidate is logged as a problem; the camp is then missing (its leader
   still stands, step 8).
8. **Leaders** stand on every seed (Round 28 S2c). A camp leader stands at
   its camp's centre. A kind leader stands on the best cell (farthest from
   roads, then deepest inside its region) of the largest region of its kind;
   where the kind has no region on the seed, the chain goes on to the belt's
   `open` kind and then to every region of the belt, largest first (a camp
   leader whose camp found no site takes that chain in the camp's belt; the
   stats name the fallback kind). The chain never leaves the belt, so the
   leader's fixed level (the top of its belt within its role's levels) stays
   inside its region. Two leaders stand at least 32 nodes apart: camp
   leaders first, then the others in recipe order, each on the first cell of
   its chain far enough from those placed (the next-best cell, then the
   next region).
   In the game a zombie-family leader steps to the nearest blight-dirt column
   within 16 nodes of its spot, where it is sunproof (biomes_mobs.md §4.2).

Unchanged by regions: underground and water spawns, the Rift Spawn's
surface row (on its host ground at night, in the four zones whose palette
had it: Gravesalt, Skyglass and both islands), rares, vendors, guards, the
mapgen.

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

- `from`: `{"anchor": <slot or anchor id>}` (or a list: every anchor is a
  source), `{"border": <zone id or list>}`: the zone's land cells bordering
  those zones are the sources, so levels in a home zone rise from where the
  player enters (Round 28 S2), or both, `{"anchor": …, "border": …}`: the
  anchors' cells and the border cells are all sources (a capital zone: the
  city and the border with its race's home zone, Round 28 W1). `to`:
  `{"border": <zone id or list>}`, the exit, or `{"core": true}`: the cells
  farthest from every source are the top belt (a zone with no higher
  neighbour: Gravesalt Escarpment and The Skyglass Canopy, harder toward their
  middle). Which borders are entry and exit follows the border rule below. An
  entry border cannot also be the exit. A recipe with exactly
  one belt may omit `to` (islands: L60 throughout) and then also `from`.
- `belts`: shares in percent adding up to 100; `levels` inside the zone's
  band; optional `max_from`; `kinds` keyed by type, `open` required.
- A kind: `id` (unique among the zone's kinds and camps), `name`, `day` and
  `night` (a roster, or `"open"`: the belt's open roster for that clock),
  `density` `sparse` / `normal` / `dense` (0.5 / 0.75 / 1 of the zone's
  density budget, never above it).
- A roster: one main role and at most one minor role of at most 25 % of the
  weight. Every role must meet its belt's levels, and each roster covers
  its belt (coverage, step 6; load errors otherwise). The last belt ends at
  the zone band's top.
- `camps`: `belt`, `roster`, `slots`, `respawn` [min, max] seconds,
  `min_player_distance`, `apart` (cells between camps), and `site`:
  `"generate"` (the default, step 7's scoring) or `{"poi": "bandit" |
  "mirefolk", "name": <POI name>}`: the camp stands on that camp POI of the
  world model (the anchors whose template is `bandit_home`,
  `bandit_frontier` or `mirefolk`; their names are the settlement roster's
  labels, and the zone atlas lists them under `camps`). `name` is needed
  only where the zone has two POIs of the type. Every camp states its
  `belt`, a camp on a POI too (the coordinator, 2026-10-02: exact quest
  levels, never missing on a seed); `apart` is not allowed on a POI. A type
  the zone lacks, a guard post (`outpost`: guards, no mob camp) and two
  camps on one POI are load errors. In a recipe zone the POI's camp fire is
  scenery (camps.lua), so the recipe camp is the POI's only population.
- `leaders`: a catalogue role marked `"leader": true`, `at` `{"camp": id}`
  or `{"kind": id, "pick": "farthest_from_roads"}`, `respawn` seconds. Its
  level is fixed (ruling 38) and the same on every seed: its camp's stated
  belt, or its kind's belt.
- `critters`: ambient critters that keep their ABM rows in the zone.

## Entry and exit borders (the border rule)

Every recipe's `from` and `to` follow one rule per zone kind (the user,
2026-10-02, Round 28 W1), so that the levels on both sides of a zone border
fit wherever a player crosses it, not only along the zone's own main route.
A border is low (`from`, where players come in), high (`to`, where they move
on) or neutral (no condition):

| Zone kind | Low (`from`) | High (`to`) | Neutral |
|---|---|---|---|
| Start 1–10 | the start town | the border to the race's own home zone (11–20) | borders to heartlands |
| Home 11–20 | the border to its race's start zone | the borders to its race's capital zone and to every adjacent heartland | — |
| Capital 20–30 | the capital city and the border to its race's home zone | the borders to contested zones | borders to heartlands |
| Heartland 21–30 | every border to the faction's capital and home (11–20) zones, and to a start zone | the borders to contested zones (or a front zone) | other heartlands |
| Contested 31–40 | every border to the faction's 20–30 zones | the borders to front zones | other contested zones |
| Front 41–60 | every border to a lower-band neighbour | the borders to higher-band neighbours; none: the core | same-band fronts |
| Dragon islands | one belt, no `from` / `to` | | |

So The Broken Causeway and The Shattered Line (41–50) rise from their
contested borders toward Gravesalt Escarpment and The Skyglass Canopy (51–60),
which rise from their lower neighbours to their core; the Causeway | Shattered
Line border is neutral. A start zone's border to a heartland is a forced gap
(10 → 21): neutral on the start side, low on the heartland side, so a player
crossing from the start zone meets the heartland's lowest levels. The rule
names the neighbours of the zone atlas (seed 42); a contact another seed
creates is neutral. `tools/r28_world/border_rule.py` derives every zone's
`from` / `to` from the atlas (`--apply` writes them into the recipes) and
`tools/r28_world/run.sh` draws the level fit across every border.

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
`dir_from_here`, `nearby`, `zone_dir`, `zone_heart`) and `phrase`, which
fills the quest text placeholders `{dir_from_giver:<target>}`,
`{dir_of:<place>:<target>}` and `{zone_area:<target>}` (syntax and rules:
[quests.md](quests.md#for-content-lanes)). A kind with patches all round its giver (on
Dawnmere the meadows, pastures and borderlands) is pointed at by its largest
patch only; the per-seed stats under `docs/planning/round28/regions/` list
how many patches lie in another direction.

## One level truth

In a zone with a recipe the gameplay level of a surface column is its
region's level (the middle of its belt): `grug_core.mob_level_at` and
`grug_core.surface_mob_level_at` consult the region overlay, so mob levels,
the fishing band and the bandit loot level match the mob map. The analytic
level field (`grug_zones.*_level_at`) stays the mapgen's own and is never
overlaid; below y = 0 the depth term applies unchanged. A zone's band is the
gameplay band of its zone record: Gravesalt Escarpment and The Skyglass Canopy
play 51–60 (`grug_core/zone_bands.lua`) while their analytic field keeps the
mapgen's 51–59. ABM spawn gates that read the analytic field only run in
zones without a recipe.

## Review images

`tools/r28_regions/run.sh [ZONE ...] [--seeds "SEED ..."] [--out ROOT]`
renders zones' regions for several seeds (base map, regions by kind, belt
borders and level labels, camps, leaders, legend with rosters, describe
phrases) and writes a stats file per seed, to
`ROOT/<short>/seed_<seed>.png|md` (ROOT defaults to
`docs/planning/round28/regions`; `<short>` is the zone id without its region
prefix, first word only unless that word has three letters or fewer:
`dawnmere`, `goldmead`, `gor_drazhak`). One process per seed builds the world
once and renders every listed zone on it; up to eight processes (and
renders) run at once. Three zones on two seeds take about 25 s. Dawnmere:
`docs/planning/round28/regions/dawnmere/`.

Kill quests per seed: `tools/r28_regions/quest_targets.py` (run by
`run.sh` at its end) reads every quest file, the recipes and the region
stats of each seed and lists every kill objective without an area whose
targets are in its zone's recipe but form no region on some seed (the quest
has no targets there; the run fails), apart from the accepted ones whose
targets the recipe never spawns (the game's `W-recipe-target` warning).

`tools/r28_world/run.sh [--seeds "SEED ..."] [--out ROOT] [--variants "A [B]"]
[--before REF]` draws the whole mainland per seed (default 42, 7, 2026; ROOT
`docs/planning/round28/world`): every land cell coloured by its region's
level, each zone border coloured by the level fit across it (the gap between
the two regions' level ranges: green ≤ 1, yellow 2–5, red > 5, magenta where
the two zones' bands lie more than 5 apart), one image and stats file per
variant (`<variant>_seed_<s>`: `current` or `final` for this tree's recipes,
`proposed` for the copies `tools/r28_world/border_rule.py` writes by the
border rule, `before` for the tree of a git commit), two variants side by
side (`compare_seed_<s>`), and `border_rule.md` (every zone's `from` / `to`,
as shipped and by the rule). Shipped today: `before_seed_<s>` (main
`38e1da4b`, before the rule), `final_seed_<s>` and `compare_seed_<s>`.
