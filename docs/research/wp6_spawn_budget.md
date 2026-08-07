# WP6 spawn budget — per-biome aoc sums and the density math

Written in WP6-T10 (the pathfinding/performance quality pass). This is the
audit trail behind two claims that `docs/design/biomes_mobs.md` §4 makes but
does not compute:

1. the per-biome `active_object_count` (aoc) day sum stays at ~14,
2. the resulting population hits world.md §8's target of **~1 visible mob per
   15–20 m of wilderness travel**.

Runtime verification is impossible from here (Luanti runs in the user's
Flatpak); everything below is arithmetic against the implemented spawn rows
and the engine/mobs_redo source. Where the implementation disagreed with §4 it
was changed — §4's numbers are the spec and were not touched.

## 1. What `aoc` actually caps

`mobs:spawn{active_object_count = N}` reaches `spawn_action` in
`mods/ENTITIES/mobs/api.lua`, which calls `count_mobs(pos, name)`
(api.lua:3405ff):

```lua
local objs = core.get_objects_inside_radius(pos, aoc_range * 2)
```

with `aoc_range = active_block_range * 16` and the engine default
`active_block_range = 4` (builtin/settingtypes.txt:2327). So:

- the cap is **per entity NAME**, not per family — two rows of the same name
  (e.g. the Skeleton Archer's two node lists, the golems' surface + cave rows)
  share one budget, two different names do not;
- it counts inside a sphere of **128 nodes** around the candidate node;
- a spawn additionally requires a player within those 128 nodes
  (`is_pla`), and never happens within `mob_nospawn_range = 12` of one.

Spawning itself only happens in ACTIVE mapblocks, i.e. within
`active_block_range` = 4 mapblocks = **64 nodes** of a player. The 128-node
counting sphere therefore encloses the whole active bubble: the biome's aoc
sum is, in practice, *the number of mobs that can exist around one traveller*.

## 2. Per-biome sums (implemented rows, after the T10 fix)

Columns are the `_grug_spawn_zones` rings. DAY counts rows with
`min_light 10` or no light gate; NIGHT counts rows with `max_light 5` or no
light gate (a 24 h row counts in both). Empty cells = the biome's top node
does not occur in that ring, or nothing is registered there.

| Biome (top node) | core | inner | outer | coast | war_coast | night peak |
|---|---|---|---|---|---|---|
| meadows (`dirt_with_grass`) | 8 | **16** | 8 | – | 2 | 10 (war coast) |
| pine hills (`dirt_with_coniferous_litter`) | 8 | 13 | 5 | – | 2 | 10 (war coast) |
| elf forest (`dirt_with_silver_litter`) | 8 | 8 | – | – | 2 | 10 (war coast) |
| savanna (`dry_dirt_with_dry_grass`) | 8 | **16** | 8 | – | 2 | 10 (war coast) |
| blight (`blight_dirt`) | 12 | 12 | 0 | – | 6 | 7 (war coast) |
| jungle (`dirt_with_rainforest_litter`) | 10 | 15 | 11 | 6 | 2 | 10 (war coast) |
| deep forest (`dirt_with_forest_litter`) | – | 8 | 10 | 2 | – | 9 (outer) |
| bone forest (`dirt_with_bone_litter`) | – | 8 | 10 | 2 | – | **12** (outer) |
| crags (`gravel`) | – | – | 6 | 4 | – | 1 |
| badlands (`mesa_clay`) | – | 5 | 9 | 4 | – | 6 (outer) |
| swamp (`mud`) | – | – | 10 | – | – | 6 |
| beach (`sand`) | – | – | – | 2 | 2 | 3 (war coast) |
| underground (`stone`, y ≤ −41) | — one cell — | | 9 | | | 9 |

Worked example, **meadows/inner (the joint day peak, 16)**: Boar 5 + Rabbit 3
+ Wolf 5 + Stag 3. **savanna/inner**: Boar 5 + Hare 3 + Hyena 5 + Zebra 3.
**bone forest/outer at night (12)**: Pale Spider 4 + Skeleton Archer 3 +
Blightfang Wolf 5 (the wolf row has no light gate, so it counts twice).

### Verdict against §4's "~14 day / 11 night"

- The two day peaks of **16** and the night peak of **12** are produced by
  §4's OWN row numbers, not by implementation drift — Boar 5 / Rabbit 3 /
  Wolf 5 / Stag 3 all sit in §4's table with those exact zones and nodes.
  Per the T10 brief the spec numbers stay as written; this is recorded as a
  known ~15 % overshoot of §4's own soft cap in the two settled-inner cells
  and the bone-forest night cell. §4 says "capped at ~14", not "≤ 14", and
  §1 below shows the target is met at these numbers rather than broken by
  them.
- **One real implementation deviation was found and fixed**: the Gaunt Stag
  also listed `default:dry_dirt_with_dry_grass`, so the savanna carried both
  Gaunt Stag (3) and Zebra (3) although §4 prices *Stag/Gaunt Stag/Zebra* as
  a single row of aoc 3. That put savanna/inner at 19. Dry grass now belongs
  to the Zebra alone (§3.1 "Savanna extras … Zebra"), the Gaunt Stag keeps
  bone litter (`grug_mobs/stag.lua`).
- **Two families are priced by the implementation, not by §4**, because §3.1
  names them and §4 forgot to give them a row: the **Parrot** (jungle edge
  critter, aoc 2 → jungle/inner 15 instead of §4's 13) and the **Carrion
  Crow** (war coast, aoc 2 → the only daytime presence on the war coast).
  Both were given the Gull's numbers, the other "flees" bird §4 does price
  (interval 20 / chance 2500 / aoc 2). Neither creates a new peak.
- The Skeleton Raider likewise has no §4 row (it is a §3.1 war-coast family)
  and reuses the Skeleton Archer's numbers.
- Shore Crab and Reef Lurker are absent by decision (§8.3, no licensed model);
  their aoc 3 / 1 are therefore missing from the beach cells.

## 3. Density math

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

i.e. the target is met as long as a player notices mobs out to roughly 23 m
to either side, which is a conservative effective sight range in wooded voxel
terrain. **Conclusion: Σaoc 14–16 lands the §8 target; it is not too sparse,
and the "~14" cap is what keeps it from becoming too dense.** A lower ring
(e.g. the elf-forest core at 8) yields ≈ 20 m spacing, i.e. the sparse end of
the same band — which is correct, that is the safe village belt.

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
  radial field, no map access. It sits AFTER the active-object count and the
  `mob_active_limit` test and BEFORE the light/space/player queries, i.e. in
  the right place in api.lua's ordering.
- The global backstop for 100 players is `mob_active_limit = 600` in the
  game's `minetest.conf` (§4's own requirement). The per-biome sums above
  bound the population around ONE player; 600 bounds the whole server.

## 6. Open items for the runtime test

- Confirm that the settled-inner cells (16) feel right rather than crowded;
  if not, the lever is the Wolf/Stag pair's `inner` zone, not the cap.
- Confirm the beach cells are not too empty now that the Shore Crab is
  deferred (Gull alone, aoc 2).
- Profile `core.find_path`; `mob_pathfinding_searchdistance = 24` is the one
  setting in `minetest.conf` chosen without measurement.
