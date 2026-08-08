# WP6 spawn budget — per-biome aoc sums and the density math

Written in WP6-T10 (the pathfinding/performance quality pass). This is the
audit trail behind two claims that `docs/design/biomes_mobs.md` §4 makes but
does not compute:

1. the per-biome `active_object_count` (aoc) day sum stays at ~14,
2. the resulting population hits world.md §8's target of **~1 visible mob per
   15–20 m of wilderness travel**.

Short answer, revised in the WP6 review: (1) holds within ~15 %, (2) holds *at
the peak cells* and does not hold in the ordinary or the thin ones — see §3,
which now states all three and names the calibration knobs instead of rounding
the result up.

Runtime verification is impossible from here (Luanti runs in the user's
Flatpak); everything below is arithmetic against the implemented spawn rows
and the engine/mobs_redo source. Where the implementation disagreed with §4 it
was changed — §4's numbers are the spec and were not touched.

**Correction of 2026-08-07 (after commit 51c5d4e, "close 37 dead biome × zone
spawn cells").** §2 below was rewritten. Two defects, one of them the same
mistake the commit fixed in the code:

1. *The cell inventory was derived from the biome's intended RING.* Cells were
   printed as `–` with the legend "the biome's top node does not occur in that
   ring". That legend was **wrong**. Biome cuboids are axis-aligned x/z boxes
   (`grug_mapgen/biomes.lua`), zones are a radial field plus three band tests
   (`grug_core.zone_at`), and §1.4's patch model puts the wild biomes' boxes
   right through core and inner on purpose. Every one of those `–` cells was
   geometrically reachable, i.e. a place a player can stand — which is exactly
   why 37 of them had no wildlife at all until 51c5d4e. The inventory is now
   derived from cuboid ∩ `zone_at` and from nothing else.
2. *25 per-cell sums were stale*, because 51c5d4e added wild/universal top
   nodes to several spawn rows (see the per-cell change list in §2.3).

Neither peak moved: 16 day / 12 night, same as before — a third cell
(deep forest/inner) joined the day peak, but no cell exceeds it, so §3's
arithmetic is untouched and §3 says why. What the correction *does* change in
§3 is the median, downward — §2.2 counted 66 live biome × ring cells against
the old table's 38 (both excluding the single underground cell), and most of
the ones it adds are thin.

**Second correction, 2026-08-08 (WP36 and the D4 rollback).** §2.2 was
re-derived a second time, mechanically: the cell geometry from the shipped
`min_pos`/`max_pos` cuboids against `grug_core.zone_at`, the Σaoc from the
shipped `mobs:spawn` rows and `_grug_spawn_zones` of `grug_mobs/*.lua`. Every
cell the two mapgen changes did not touch came out identical to the table
below's previous revision, which is the check that the re-derivation is sound.
Five groups of cells moved, and the inventory is now **67 live / 8
impossible** (was 66 / 9):

1. **`grug_deep_jungle` carries `grug_nodes:dirt_with_canopy_litter`** since
   WP36, so the old "deep jungle" row is a *new* row on a *new* top, and two
   of its cells differ from the rainforest row it split off from
   (inner 15 → **10**, no Parrot and no Hare on canopy litter; war_coast
   10 → **7** at night, because the Skeleton Archer's war-coast node list is
   the five *settled* tops and canopy litter is not one).
2. **`grug_meadows × coast` and `grug_savanna × coast` are live** (2 / 4).
   They were printed `–` with an arithmetic that described the *pre-carve*
   centre band; the shipped cuboid is x ±349, z 100..1700 and does reach the
   back-coast band. They were the two dead cells WP36 repaired.
3. **`meadows × outer` and `savanna × outer` 8 / 5 → 10 / 9**, the same WP36
   edit seen from the other side: Bear + Giant Spider gained
   `default:dirt_with_grass`, Plaguehide Bear + Pale Spider gained
   `default:dry_dirt_with_dry_grass`.
4. **`badlands × war_coast` is live** (2 / 7), because `grug_badlands_east`
   (WP36) spans z 100..1700 while its parent starts at z 1201.
5. **`deep forest × core` and `badlands × core` are now impossible** — this
   one is the *capital carve* of 2026-08-08, not WP36, and it is the one
   change that makes the inventory smaller. Both had a live number in the
   previous revision, from before the carve cut the capital belt out of them.

**Third correction, 2026-08-08 (the critter round, `biomes_mobs.md` §3.0).**
§2.2 moved again, and this time only by ADDITION — four new critter names, no
row removed, no zone or node list of an existing family touched. The
affected cells and the reasoning are §2.5; the short version is that the
underground cell goes **9 / 9 → 12 / 12** (deliberately, to the night peak
and not past it), fifteen surface cells gain 2 in the DAY column only, and
**neither peak moves**: 16 day, 12 night. §3's density math is therefore
unchanged again, for the same reason it was unchanged in 2026-08-07 — it is
driven by the peak.

## 1. What `aoc` actually caps

`mobs:spawn{active_object_count = N}` reaches `spawn_action` in
`mods/ENTITIES/mobs/api.lua`, which calls `count_mobs(pos, name)`
(api.lua:3405ff):

```lua
local objs = core.get_objects_inside_radius(pos, aoc_range * 2)
```

with `aoc_range = active_block_range * 16`. So:

- the cap is **per entity NAME**, not per family — two rows of the same name
  (e.g. the Skeleton Archer's two node lists, the golems' surface + cave rows)
  share one budget, two different names do not;
- it counts inside a sphere of `aoc_range * 2` around the candidate node;
- a spawn additionally requires a player within that sphere (`is_pla`), and
  never happens within `mob_nospawn_range = 12` of one.

**The radius is client-configurable, not a constant.** `active_block_range`
defaults to **4** (= 64 nodes, so the counting sphere is 128) on desktop and to
**2** (= 32 / 64) on Android (builtin/settingtypes.txt), and a server operator
may set anything. Everything below is computed at the desktop default; on a
server whose operator lowers it, the same aoc numbers describe a *smaller*
bubble and therefore a *denser* world. If we ever ship a dedicated server
config, `active_block_range = 4` belongs in it — the density numbers here are
only meaningful together with that value.

Spawning itself only happens in ACTIVE mapblocks, i.e. within
`active_block_range` = 4 mapblocks = **64 nodes** of a player. The 128-node
counting sphere therefore encloses the whole active bubble: the biome's aoc
sum is, in practice, *the number of mobs that can exist around one traveller*.

## 2. Per-biome sums (implemented rows, re-derived 2026-08-07)

### 2.1 How a cell is decided — cuboid ∩ zone, never "biome role"

A cell (biome × zone) is **real iff the biome's registration cuboid contains
at least one position for which `grug_core.zone_at` answers that zone.** Two
independent pieces of geometry, and nothing else decides:

- the cuboid is `min_pos`/`max_pos` of `core.register_biome` in
  `mods/MAPGEN/grug_mapgen/biomes.lua` — an axis-aligned **box** in x/z
  (`register_mirrored` mirrors the Throng box to Accord at z = 0, and
  `zone_at` reads |x| and |z|, so one box covers both continents);
- the zone is `grug_core.zone_at` in `mods/CORE/grug_core/init.lua` — a
  **radial field** `n = √((max(|x|−300,0)/1150)² + (||z|−900|/f)²)`, f = 1000
  toward the strait and 775 behind the seat, thresholded at n ≤ 0.30 core and
  n ≤ 0.55 inner, else outer — preceded by three band tests in this order:
  `|z| ≤ 100` strait, `|z| ≤ 300` war_coast, `1500 − |x| ≤ 150` or
  `1700 − |z| ≤ 150` coast. Depth wins over all of it (`y < −40`
  underground).

**Do not derive cells from the biome's intended ring.** That is what the
previous revision of this section did, and it was wrong in both directions:
§1.3 assigns each biome a role ("settled" / "wild back-country") and §1.4 then
deliberately breaks the identity role = ring by overlapping the boxes 400–500
nodes so the voronoi produces a patch mosaic. A wild top node is therefore
reachable *inside* core and inner, every box that reaches |z| ≤ 300 has a war
coast, and every box that reaches |x| ≥ 1350 or |z| ≥ 1550 has a coast — no
matter what the biome is "for". The 37 dead cells 51c5d4e closed are precisely
the cells this section had declared non-existent.

The `–` in the table below therefore means one thing only: **the biome's
cuboid and the zone are geometrically disjoint — no position in the world is
in both.** Every other cell is a place a player can stand, and its number is
what actually spawns there. A live cell may legitimately be `0`.

Counting rule per cell: sum `active_object_count` over the distinct entity
**NAMES** whose spawn row lists that biome's top node and whose
`_grug_spawn_zones` (and `_grug_spawn_check`) admit that zone (§1: the cap is
per name, so two rows of one name — the Skeleton Archer's, the Zombie's, the
golems' — contribute their aoc once). DAY counts rows with `min_light 10` or
no light gate; NIGHT counts rows with `max_light 5` or no light gate; a 24 h
row (Wolf, Hyena, Bog Ooze, Crocodile, golems, the blight Zombie) counts in
both. Two `_grug_spawn_check` continent gates matter for the counts: the
universal swamp/beach cuboids exist on both continents, but `territory_at`
admits exactly one of Rabbit/Hare there (3, not 6), and exactly one of
Stone/Mesa Golem underground (1, not 2).

### 2.2 The table

Cells are **day / night**. `–` = geometrically impossible (§2.1).

A row is a **band**, i.e. a `node_top`: siblings that share a top are folded
(`grug_deep_forest{,_front,_east}`, `grug_badlands{,_east}`,
`grug_crags{,_snowy}`), because the spawn gate is `node_top × zone` and never
a biome name. The one pair that is *not* folded is jungle edge / jungle
fringe: they share `default:dirt_with_rainforest_litter` but sit on different
continents (§1.3 of the catalog), so they are two places, not one.

| Biome (top node) | core | inner | outer | coast | war_coast |
|---|---|---|---|---|---|
| meadows (`dirt_with_grass`) | 8 / 4 | **16** / 9 | 10 / 9 | 2 / 4 | 2 / 10 |
| savanna (`dry_dirt_with_dry_grass`) | 8 / 4 | **16** / 9 | 10 / 9 | 2 / 4 | 2 / 10 |
| pine hills (`dirt_with_coniferous_litter`) | 8 / 4 | 13 / 9 | 7 / 9 | 2 / 4 | 2 / 10 |
| elf forest (`dirt_with_silver_litter`) | 8 / 4 | 8 / 4 | 2 / 4 | 2 / 4 | 2 / 10 |
| jungle edge (`dirt_with_rainforest_litter`) | 10 / 4 | 15 / 4 | 11 / 8 | 6 / 8 | 2 / 10 |
| blight (`blight_dirt`) | 14 / 4 | 14 / 4 | 4 / 7 | 4 / 4 | 8 / 10 |
| deep forest (`dirt_with_forest_litter`, 3 slabs) | – | **16** / 9 | 10 / 9 | 2 / 4 | 2 / 7 |
| bone forest (`dirt_with_bone_litter`) | – | 10 / 5 | 12 / **12** | 4 / 4 | 4 / 6 |
| badlands (`mesa_clay`, + `_east`) | – | 10 / 9 | 9 / 6 | 4 / 1 | 2 / 7 |
| crags (`gravel`, y ≤ 79) | – | 8 / 4 | 6 / 1 | 4 / 1 | 2 / 7 |
| crags snowy (`snowblock`, y ≥ 80) | – | 8 / 4 | 6 / 1 | 4 / 1 | 2 / 7 |
| deep jungle (`dirt_with_canopy_litter`) | – | 10 / 4 | 11 / 8 | 6 / 8 | 2 / 7 |
| jungle fringe (`dirt_with_rainforest_litter`) | – | – | 11 / 8 | 6 / 8 | 2 / 10 |
| swamp (`mud`) | 10 / 4 | 10 / 4 | 12 / 6 | 6 / 0 | 4 / 7 |
| beach (`sand`) | 8 / 4 | 8 / 4 | 2 / 0 | 2 / 0 | 2 / 7 |
| underground (`stone`, y ≤ −41) | *one cell, all x/z:* | **12 / 12** | | | |

**67 live cells, 8 impossible ones**, and every one of the eight is a
core-or-inner cell of a *wild* band — no band is missing an outer, coast or
war-coast cell any more. The arithmetic that makes each empty (all in the
constants of §2.1):

- **deep forest/core** and **badlands/core** — the **capital carve** of
  2026-08-08, and it is exact rather than lucky. The core belt at |x| ≤ 300
  is |z| 600..1132 (n ≤ 0.30 needs dz ≤ 0.30 · 1000 = 300 toward the strait,
  dz ≤ 0.30 · 775 = 232 behind the seat). `grug_deep_forest_front` stops at
  |z| = 599 — one node short, by construction — the back slab starts at
  |z| = 1201 (dz/f = 301/775 = 0.388), and both east wings start at
  |x| = 801 (dx/1150 = 0.436). Same three numbers for the badlands and its
  wing. The carve box IS the core belt plus slack, so this is the guarantee
  of `world.md` §3 showing up in the spawn inventory.
- **bone forest/core**, **crags/core**, **crags snowy/core**,
  **deep jungle/core** — all four boxes lie entirely at |x| ≥ 801, so
  dx ≥ 501 and n ≥ 501/1150 = 0.436 > 0.30 everywhere inside them.
- **jungle fringe/core** and **jungle fringe/inner** — that box starts at
  |x| = 1150, so dx ≥ 850 and n ≥ 0.739 > 0.55: it is outer or coast, never
  anything nearer.

Three cells the previous revision printed as impossible are **live**:
`meadows × coast` and `savanna × coast` (the centre band is x ±349,
z 100..**1700**, so it does reach the |z| ≥ 1550 back-coast band — the
"x ∈ [−700, 700] … z stops at 1500" arithmetic quoted here described the
pre-carve band), and `badlands × war_coast` (`grug_badlands_east` spans
z 100..1700 while its parent starts at z 1201).

Three zones are not columns. `underground` is the last row: depth wins in
`zone_at`, so it is one cell for the whole world — Zombie 4 + Giant Spider 4 +
one golem 1 + **Cave Bat 2 + Cave Crawler 1** = 12, printed 12/12 because all
four `max_light 5` cave rows carry no `day_toggle` on purpose (zombie.lua:
"it is always night down there"), so the surface clock does not gate them and
the cave's own darkness always passes. The 2 + 1 split of the two critters is
what keeps this cell level with the night peak instead of one over it — see
§2.5.
`ocean` is outside every land cuboid (the Kraken's cell, aoc 1). `strait` is
an artifact and is discussed in the footnote below.

Notes on the table:

- *Two rainforest rows, not three, since WP36.* `grug_jungle_edge` (Kragmar)
  and `grug_jungle_fringe` (Elandor) still both top with
  `default:dirt_with_rainforest_litter`, so a spawn row cannot tell them
  apart — they differ **only** in which zones their boxes reach, and in the
  continent, which matters for the two continent-gated families (the Hare
  reaches the jungle edge's core/inner, the Rabbit does not reach the
  fringe's — but the fringe has no core or inner cell anyway, so the two
  rows come out identical everywhere they overlap). `grug_deep_jungle`
  **left that group**: it carries `grug_nodes:dirt_with_canopy_litter` since
  WP36 and is its own row above. That top being the only land top present on
  *both* continents is also why the outer/coast filler slot deliberately does
  not list it (catalog §4, §1.5).
  `grug_crags` / `grug_crags_snowy` are still one roster twice: every row
  that lists
  `default:gravel` also lists `default:snowblock` after 51c5d4e, so the snow
  cap is the gravel cell one more time. (Above y = 200 the snow cap loses the
  `max_height = 200` families — Boar, Rabbit, Zombie, Carrion Crow, Skeleton
  Raider — and keeps only Crag Eagle / Mountain Ram / Stone Golem, which run
  to 300. With the terrain noise of `grug_mapgen/init.lua` that is a rare
  peak, not a band, so it is not given its own row.)
- *Three live cells are empty at night*: swamp/coast, beach/outer,
  beach/coast. Not dead cells — they have day wildlife (Serpent 4, Gull 2) —
  but nothing nocturnal reaches sand or mud outside the rings that Zombie and
  Skeleton Raider cover. §6 keeps this as a runtime question.
- *`grug_crags_snowy` had no spawn row at all* between WP18 and 51c5d4e: it is
  a separate biome registration, and `default:snowblock` was on nobody's node
  list. It is a full row here for the first time.

**Footnote on zone `strait`, deliberately not a column.** Every land cuboid
starts at `z_min = grug_core.CONTINENT_Z_MIN = 100`, and `zone_at` answers
`strait` for `|z| <= 100` — so the *single plane* |z| = 100 formally makes
`strait` reachable for 14 of the 16 band registrations (all but
`grug_badlands` and `grug_deep_forest`, whose boxes start at |z| = 1201).
It is an artifact, not a cell: that
plane is the outer edge of the continent rectangle, the ocean mask insets the
visible shoreline 0..150 nodes further INWARD (`grug_mapgen` INSET_MAX), and
grug_core states the rule outright — "strait: |z| < 100 is always water". The
two universal cuboids (swamp, beach) do span the whole strait band, because
they are registered once for the world at |z| ∈ [0, 1700], and the same
answer applies: it is water, so their sand/mud is seabed with no `air`
neighbour, and `mobs:spawn` defaults the ABM's neighbour list to `{"air"}`
(§5). The Gull's `strait` zone therefore buys nothing on the strait itself; it
matters on the beach band the mask carves inside the rectangle, which
`zone_at` already answers as war_coast/coast/outer.

**Peaks: 16 day, 12 night** — re-confirmed from this table, and both unmoved
by 51c5d4e (§2.4) or by the critter round (§2.5). Day 16 in three cells:
**meadows/inner** and
**deep forest/inner** = Boar 5 + Rabbit 3 + Stag 3 + Wolf 5;
**savanna/inner** = Boar 5 + Hare 3 + Hyena 5 + Zebra 3. Night 12 in **two**
cells since the critter round: **bone forest/outer** = Skeleton Archer 3 +
Pale Spider 4 + Blightfang Wolf 5 (the wolf row has no light gate, so it
counts in both columns), and **underground** = Zombie 4 + Giant Spider 4 +
one golem 1 + Cave Bat 2 + Cave Crawler 1. Both are *at* the peak, neither is
above it.

### 2.3 What 51c5d4e changed, cell by cell

**Read this subsection as history, against the world of 2026-08-07.** Four of
the cells it names were overtaken the next day and §2.2 above is the current
inventory: `deep forest/core 8` and `badlands/core 5` were removed by the
capital carve, `badlands/war_coast` ("the badlands have no war coast at all")
was created by `grug_badlands_east`, and the "old single jungle row is now
three" is two rainforest rows plus a canopy-litter row since WP36. Nothing
below is *wrong about what 51c5d4e did*; it simply predates two mapgen passes.

The previous revision printed one DAY sum per cell plus a single night PEAK
per biome, so only the day column is directly comparable. **25 day cells
changed: 21 from a wrongly-printed `–` to a live number, 4 numerically.**
24 of them are the spawn rows 51c5d4e edited, grouped below by the edit that
caused them; the 25th, **swamp/coast 4**, is a pure documentation fix — the
Serpent has `grug_nodes:mud` with zones outer+coast and has had it since T6,
so that cell was always live and only ever mis-printed here.

- **Boar + Rabbit/Hare + Zombie got the wild/universal tops** (`forest_litter`,
  `mesa_clay`, `gravel`, `snowblock`, `mud`, `sand`; Zombie all but
  `bone_litter`), all three zoned core+inner (Zombie also war_coast). Every
  core/inner cell of a wild or universal biome exists because of this:
  deep forest/core 8, deep forest/inner 8→**16**,
  badlands/core 5, badlands/inner 5→**10**,
  crags/inner 8, crags snowy/inner 8,
  swamp/core 8, swamp/inner 8, beach/core 8, beach/inner 8.
- **Bear + Spider got silver / coniferous / blight litter.** pine hills/outer
  5→**7**, pine hills/coast 2, elf forest/outer 2, elf forest/coast 2,
  blight/outer 0→**2**, blight/coast 2.
- **Carrion Crow (day) and Skeleton Raider (night) got the full land-top
  set.** Both are war_coast-exclusive, so this is what makes the war coast of
  a *wild* band inhabited: deep forest/war_coast 2, bone forest/war_coast 2,
  crags/war_coast 2, crags snowy/war_coast 2, swamp/war_coast 2 (the badlands
  have no war coast at all, §2.2). The Zombie filler above lands in four of
  those five at night — not bone forest, whose `bone_litter` is the one land
  top the Zombie's list still does not carry.
- **Gull extended to zone `outer`.** beach/outer 2 (the inland lake shores
  and river banks of the outer ring; `grug_beach` is registered once for the
  whole world at y 1..4, so "beach" is not only the shoreline).
- **`default:snowblock` added to the crags families.** The whole crags snowy
  row — four live cells (inner 8, outer 6, coast 4, war_coast 2), and that
  biome's first spawn rows ever. Its inner and war_coast cells are the two
  already listed above; outer 6 and coast 4 are the two the snow cap adds.

Two more corrections that are not cell-value changes:

- *The old single "jungle" row is now three.* `grug_jungle_edge`,
  `grug_deep_jungle` and `grug_jungle_fringe` share the rainforest top node,
  so their day sums are identical where a cell exists — but their boxes are
  not, and the old row credited deep jungle with a core cell and jungle
  fringe with a core and an inner cell that neither biome can reach.
- *Three of the old per-biome night peaks were stale as well* (they predate
  spawn rows added after that revision): blight 7 → **10** (war coast),
  beach 3 → **7** (war coast), crags 1 → **7** (war coast). The other nine
  night peaks re-derive unchanged, including the overall peak of 12.

Cells whose day sum did **not** change: all of meadows, savanna and jungle
edge, bone forest inner+outer+coast, blight core+inner+war_coast, badlands
outer+coast, crags outer+coast, swamp/outer, elf forest core+inner, beach
coast+war_coast, deep forest outer+coast, pine hills core+inner+war_coast,
elf forest war_coast, and the underground cell.

### 2.4 Verdict against §4's "~14 day / 11 night"

- The day peak of **16** (three cells) and the night peak of **12** are
  produced by §4's OWN row numbers, not by implementation drift — Boar 5 /
  Rabbit 3 / Wolf 5 / Stag 3 all sit in §4's table with those exact zones and
  nodes. Per the T10 brief the spec numbers stay as written; this is recorded
  as a known ~15 % overshoot of §4's own soft cap in the three settled-inner
  cells and the bone-forest night cell. §4 says "capped at ~14", not "≤ 14",
  and §3 below shows these cells are the ones that actually MEET the §8 travel
  target — they are the peak, not the problem.
- **51c5d4e did not raise either peak**, and could not have: `aoc` is counted
  per entity NAME (§1), so putting a filler node on an existing row gives an
  already-budgeted family more *places* to spawn, never a second budget in the
  cell it was already budgeted in. The two cells that define the day peak
  (meadows/inner, savanna/inner) and the one that defines the night peak
  (bone forest/outer) have rosters the commit did not touch at all.
- What the commit *did* do is put a **third** cell at the day peak:
  **deep forest/inner** went 8 → 16, because Boar and Rabbit gained
  `grug_nodes:dirt_with_forest_litter` and joined the Stag/Wolf pair that was
  already there. Equal to the peak, not above it — the roster is Boar 5 +
  Rabbit 3 + Stag 3 + Wolf 5, the same four families and the same four aoc
  values as meadows/inner, which is the point: a deep-forest patch inside the
  inner ring is a meadow-ring cell with different scenery. Every other cell
  the commit changed lands at 10 or below.
- **One real implementation deviation was found and fixed**: the Gaunt Stag
  also listed `default:dry_dirt_with_dry_grass`, so the savanna carried both
  Gaunt Stag (3) and Zebra (3) although §4 prices *Stag/Gaunt Stag/Zebra* as
  a single row of aoc 3. That put savanna/inner at 19. Dry grass now belongs
  to the Zebra alone (§3.1 "Savanna extras … Zebra"), the Gaunt Stag keeps
  bone litter (`grug_mobs/stag.lua`).
- **Two families are priced by the implementation, not by §4**, because §3.1
  names them and §4 forgot to give them a row: the **Parrot** (jungle edge
  critter, aoc 2 → jungle edge/inner 15 instead of §4's 13) and the **Carrion
  Crow** (war coast, aoc 2 → the only daytime presence on the war coast).
  Both were given the Gull's numbers, the other "flees" bird §4 does price
  (interval 20 / chance 2500 / aoc 2). Neither creates a new peak.
- The Skeleton Raider likewise has no §4 row (it is a §3.1 war-coast family)
  and reuses the Skeleton Archer's numbers.
- Shore Crab and Reef Lurker are absent by decision (§8.3, no licensed model);
  their aoc 3 / 1 are therefore missing from the beach cells.

### 2.5 The critter round (2026-08-08, `biomes_mobs.md` §3.0)

Four new entity names, all `critter` tier, all at `interval 20 / chance 2200`
and `aoc` 2 — except one, and that exception is the whole point of this
subsection. Counted the same way as every other cell: sum `aoc` over the
distinct entity NAMES whose spawn row lists the cell's top node and whose
zone gate admits the zone.

**The two cave critters, and why the second is `aoc` 1.** Both spawn on
`default:stone` + `group:grug_stratum` with `max_light 5`, no `day_toggle`,
`min_height −31000 / max_height −40` and `_grug_spawn_zones = {underground}` —
i.e. the canonical cave row of `zombie.lua`, so both count in the day AND the
night column:

```
underground before          Zombie 4 + Giant Spider 4 + one Golem 1  =  9 / 9
+ Cave Bat        aoc 2                                             = 11 / 11
+ Cave Crawler    aoc 2                                             = 13 / 13   <- one over
+ Cave Crawler    aoc 1                                             = 12 / 12   <- ships
```

The world night peak is 12 (bone forest/outer), so shipping both at 2 would
have made the underground the new peak — for two harmless 1 HP animals.
`aoc` is per entity NAME inside a 128-node sphere (§1), so the two critters
are two independent budgets and there is no way to share one; the second row
takes 1. `chance` stays 2200 on both, so the smaller budget still fills at
the same rate (§4: the equilibrium is set by the cap, not by the roll).

**The two surface critters** are day-only (`min_light 10`), so no night
column moves at all:

| Row | Nodes | Cells it lands in (day) |
|---|---|---|
| Bog Fowl, `aoc` 2 | `grug_nodes:mud`, no zone gate | swamp core 8→**10**, inner 8→**10**, outer 10→**12**, coast 4→**6**, war_coast 2→**4** |
| Bone Weevil, `aoc` 2 | `grug_nodes:dirt_with_bone_litter` **and** `grug_nodes:blight_dirt`, two rows, no zone gate | bone forest inner 8→**10**, outer 10→**12**, coast 2→**4**, war_coast 2→**4**; blight core 12→**14**, inner 12→**14**, outer 2→**4**, coast 2→**4**, war_coast 6→**8** |

The Bone Weevil is **one entity name with two spawn rows**, exactly like the
Skeleton Archer's two node lists: the bone forest and the blight therefore
share ONE budget of 2, and each row stamps its own tint through `on_spawn`
instead of buying a second registration (which would have been a second
budget in both cells). Highest cell reached anywhere in this round is
**14** (blight core/inner) against the day peak of **16**.

**Coverage is unaffected in principle** — this round only ever ADDS a name to
a cell that already had rows, so no cell can lose day or night spawns and no
new `biome × zone` column exists (no new top node: `mud`, `bone_litter`,
`blight_dirt` and the cave rock were all already spawn nodes). The three
documented day-only cells stay exactly those three: swamp/coast (now 6 / 0),
beach/outer (2 / 0) and beach/coast (2 / 0) — a DAY critter cannot change a
night column.

**Nothing else in the critter round touches a spawn number.** The Carrion
Crow's move to passive prey is a behaviour and a visual change on the same
row (same `aoc` 2, same zones, same nodes); the drop-table edits (food-only
critters, feather to the bird-of-prey table) are loot, not density.

## 3. Density math

**Unchanged by the 2026-08-07 re-derivation, and the reason is worth stating
once**: this section is driven by the PEAK, and the peak did not move —
16 day / 12 night, re-confirmed against §2.2's table. `active_object_count`
is counted per entity NAME (§1), so the filler nodes 51c5d4e added put
already-budgeted families on more top nodes; that raises the number of cells
in which a family can appear, never the ceiling inside one cell. The only
figure below that the corrected inventory does move is the *median*, and it
moves DOWN — see the second block.

Take the day peak, Σaoc = 16 mobs inside the active bubble of radius 64 m
(§1). Treating them as a Poisson field over that disc:

```
area   A = π · 64²            ≈ 12 868 m²
density λ = 16 / A            ≈ 1.24 · 10⁻³ mobs/m²
mean nearest-neighbour distance = 1 / (2·√λ) ≈ 14.2 m
```

For the *travel* reading of the target — one mob noticed per 15–20 m walked —
the swept-corridor model gives, for one encounter every `d` metres with a
detection half-width `w`:

```
2 · w · d · λ = 1   →   w = 1 / (2 · λ · d)
d = 17.5 m  →  w ≈ 23 m
```

i.e. at the peak the target is met as long as a player notices mobs out to
roughly 23 m to either side.

**That 23 m is an assumption, not a measurement**, and the conclusion has to be
stated with it rather than around it. Redoing the same arithmetic away from
the peak: over §2.2's 67 live day cells the distribution is bimodal, 25 cells
at Σaoc 2, 12 at 8, the rest spread between — median **6**, mean 6.4. So two
blocks, the ordinary cell (8: elf forest core/inner, the crags, swamp and
beach core/inner, most of the outer ring outside the peaks) and the thin one
(2: every war coast whose only day family is the Carrion Crow, the beach, the
bear-only coasts):

```
Σaoc = 8   λ = 8 / 12 868   ≈ 6.2 · 10⁻⁴ mobs/m²
           nearest-neighbour ≈ 20 m
           at w = 23 m →  d = 1 / (2 · λ · w) ≈ 35 m
           at w = 30 m →  d ≈ 27 m

Σaoc = 2   λ = 2 / 12 868   ≈ 1.6 · 10⁻⁴ mobs/m²
           nearest-neighbour ≈ 40 m
           at w = 23 m →  d ≈ 140 m
```

(The oldest revision quoted "median ≈ 8". That was the median of a table which
had wrongly deleted most of the thin cells. With the corrected inventory 8 is
the UPPER mode of a bimodal distribution — the lower mode is 2, with 25 of the
67 cells in it — and the median sits between them at 6. The 8-block is still
the right block to reason about for "walking through a biome"; the 2-block is
what a war coast or a shoreline strip feels like.)

**Conclusion, honestly: the §8 target of one mob per 15–20 m is met AT THE
HOTSPOTS (Σaoc 14–16 → d ≈ 17–20 m at w = 23 m). The ordinary cell lands at
roughly 28–35 m, i.e. noticeably sparser than §8 asks for, and the thin cells
at ~140 m are not "sparse" but "empty-feeling".** That is partly intended (the
safe village belt and the bare crags *should* feel empty) and partly just
where §4's row numbers land; it is documented here rather than papered over,
because the arithmetic cannot settle which of the two it is — only walking the
world can. The thin cells are the honest new finding of the 2026-08-07
re-derivation: 51c5d4e made 37 dead cells live, but a live cell at Σaoc 2 is
still a long walk between mobs, and it is the DAY half of the war coast and
the coasts (Carrion Crow alone, Bear alone, Gull alone) that sits there.

The calibration knobs, in the order they should be reached for, are per row and
not global: **`chance`** (lower = more spawn attempts, moves the equilibrium up
to the cap faster; safe, the cap still bounds it) and then **`aoc`** (raises the
ceiling itself; this is what actually changes density and what §4 makes
conditional on this pass). §6 lists the cells to look at first.

## 4. Is the cap actually reached? (spawn reliability)

§4 argues the density "is delivered by SPAWN RELIABILITY rather than raw
counts". Checked:

- The ABM's active area is a 9×9×9 mapblock cube around the player = 144³
  nodes, so ~20 000 surface columns, of which the biome's signature top node
  covers most inside its own patch. Call it 10 000 matching nodes.
- ABM `chance = 1500` means p = 1/1500 per node per `interval` = 20 s
  (lua_api.md:10234), i.e. ≈ **7 attempts per 20 s** for a common family
  before any of the gates run — orders of magnitude more than the 5 mobs the
  cap allows. The rarest row (golem, interval 30 / chance 9000) still gets
  ≈ 1 attempt per 30 s for a cap of 1.
- So the equilibrium is set by aoc and by the gates (zone, light, height,
  12 m player distance, headroom, protection), never by the roll. Raising
  density means raising aoc, and §4 makes that conditional on this pass.

## 5. Cost side (the reason the numbers are allowed to stand)

- `catch_up = false` is already set on every spawn ABM by mobs_redo itself
  (api.lua:3712) — no patch needed; verified rather than assumed.
- Every spawn row is whitelisted on biome signature top nodes, and
  `mobs:spawn` defaults the ABM `neighbors` list to `{"air"}` (api.lua:3729),
  so `default:stone` rows (golem surface + the three cave rows) only ever
  consider rock with air beside it, not solid stone volume. Argued at the
  rows in `zombie.lua` (canonical) and `golem.lua`.
- `mobs:spawn_abm_check` is overridden in `grug_mobs/init.lua` and runs per
  surviving candidate. Its work is a table lookup plus
  `grug_core.zone_at(pos)` / `territory_at(pos)` — pure arithmetic on the
  radial field, no map access. Its actual place in `spawn_action` (api.lua),
  re-read in the WP6 review because the T10 note had it backwards:
  `max_per_block` → entity exists → `at_limit()` (`mob_active_limit`) →
  **`spawn_abm_check`** → `count_mobs` (the active-object count) → day_toggle →
  repellent → height → light → protection → player distance → headroom.
  So it runs BEFORE the active-object count, not after it — which is the good
  direction: `count_mobs` is a `get_objects_inside_radius` over a 128-node
  sphere, and a candidate in the wrong ring is now rejected by two
  subtractions before that scan ever happens.
- The global backstop for 100 players is `mob_active_limit = 600` in the
  game's `minetest.conf` (§4's own requirement). The per-biome sums above
  bound the population around ONE player; 600 bounds the whole server.

## 6. Open items for the runtime test

- Confirm that the three settled-inner cells at 16 (meadows/inner,
  savanna/inner, deep forest/inner) feel right rather than crowded; if not,
  the lever is the Wolf/Stag pair's `inner` zone, not the cap.
- **Walk an ordinary cell** (elf-forest core, crags, a plain stretch of the
  outer ring — Σaoc 8) and count encounters per 100 m. §3 predicts ~3 there
  against §8's ~6; if it reads as empty, lower `chance` on the two or three
  families that actually live in that cell before touching any `aoc`.
- **New after the 2026-08-07 re-derivation: walk a thin cell** (Σaoc 2 —
  a war coast by day, an elf-forest or blight coast, a beach outside the
  settled rings). §3 predicts ~140 m between encounters. These are the cells
  51c5d4e brought from 0 to 2, and 2 may not be enough; the fix would be a
  second family per cell, not a bigger `aoc` on the one that is there.
- Three live cells have **nothing at night**: swamp/coast, beach/outer,
  beach/coast (§2.2). Decide whether that is intended coastal quiet or the
  next dead-cell fix.
- Confirm the beach cells are not too empty now that the Shore Crab is
  deferred (in core/inner the Boar/Rabbit filler now covers sand; in outer
  and on the coast it is the Gull alone, aoc 2, day only).
- Profile `core.find_path`; `mob_pathfinding_searchdistance = 24` is the one
  setting in `minetest.conf` chosen without measurement.
