# Round 23 Lane B — habitat-driven vegetation renewal (receipt)

Branch `wp33-habitat-renewal`, contract
[round23-world-life-plan.md](../planning/round23-world-life-plan.md) Lane B
rulings 1–10. Implementer: Claude Opus 5.5 (native subagent). Independent
review: pending (coordinator). Design spec: [farming.md](../design/farming.md)
"Wild plant renewal".

## What changed

- **Removed** `grug_farming/ecology.lua`: the Round 11 world-sized registry,
  its `ecology_v1` mod-storage key, the `grug_player_placed_plant` mark (and
  its global `register_on_placenode`), the main-environment
  `register_on_generated` observer, the `observe_natural_sources` LBM and the
  apple/blueberry `after_destruct` overrides. Fresh-server mode: no cleanup.
- **New** `grug_farming/renewal.lua` (the service) wired in
  `grug_farming/init.lua` (one throttled globalstep, sapling/natural-node
  checks at `register_on_mods_loaded`). `grug_mapgen` moved from
  `optional_depends` to `depends` in `grug_farming/mod.conf` (review L2):
  renewal fails closed without the authority.
- **New** read-only authority `grug_mapgen/wp40/vegetation_density.lua`,
  built in the main environment by `r7_runtime.lua` (authority branch only)
  and exported by `r7_loader.lua` as `grug_mapgen.wp40.vegetation`.
- `habitat_registry.lua`: `natural_probability`, `host_names`,
  `vegetation_factor` (Phase 2 hook, returns 1), and `habitat_matches` now
  bands surface rows by zone level (as `world_content.lua` does; the old code
  compared the plant's y to the level band) and takes an explicit
  surface/cave mode.
- `r6.lua` authority identity: `decoration_cover(id, biome, support_name)`
  and the content name list. `zones.lua`: the planner's
  `static_exclusion_values_at` delegate forwards its `purpose` argument.
- `settingtypes.txt`: `grug_tree_regrowth` (bool, default true) in a new
  "World life" section. `minetest.conf` is not touched: the project pattern
  keeps runtime defaults in the `get_bool` call.

**Mapgen output is unchanged.** Every mapgen edit is an additive read-only
query in the main-environment authority branch; the emerge writer never
calls them, and `habitat_matches`/`compile_*` have no mapgen caller. The
edits do change the bytes that `preparation_identity.lua` and the layout
cache digest (`zones.lua`, `r6.lua`, `r7_runtime.lua`), so the first boot
after the merge rebuilds the layout cache — fresh worlds only, as any mapgen
code change.

## Density authority

No v7 decorations exist (the vendored `default` registers none; R7 owns the
surface). The authoritative sources are:

| Class | Source | Density per eligible support |
|---|---|---|
| resource (per species) | `world_content_catalog.plants` + gathering `p9g_sources()`, renewable rows | `1 / habitat.initial_denominator(key, denominator)` |
| cover (one total) | R6 `simple` decoration rows (`r7_r6_manifest.lua`), bone piles excluded | Σ `numerator / denominator / cover` over the biome's rows, `cover` = planner factor for the support (gravel 4) |
| woody | R6 `template` rows with a sapling | same, trunks counted as marker columns ÷ the template's own marker columns |

Site rules follow the planner (`surface_y_at_least_60`, mountain relief for
the emergent jungle tree, `terrain_y >= 1`), the resource rows follow their
writers (zone, logical biome, support, zone level or cave depth, shore on
planned water). Cover and woody densities pass through
`habitat_registry.vegetation_factor(class, values)`; the Phase 2 tree line and
forest noise go there (and into the planner), renewal code does not change.

## Rules as built

- Service: each connected player once per 5 s (round-robin over 0.5 s ticks),
  4 random spots in the ring 20–48 nodes horizontally from that player; the
  column is searched ±24 around the player's y (caves included), else ±8
  around the planned surface when that lies within 64.
- A spot: open support accepted by some habitat, air above, loaded, ≥ 20
  nodes (3-D) from every player, not farm soil; permitted by housing mask,
  hard rows and `grug_core.world_alterable` (plant and support); land column;
  per class the writer's claim exclusions (review M1/L1): resources the full
  territory rule (`static_exclusion_values_at(x, z)` then any overlay kind;
  shoreline rows ignore `exclude:water_bank`, P9G rows the two dry island
  coast envelopes on land outside a hard foundation), cover and woody the
  decoration rule (`"vegetation"` purpose plus road corridors; banks allowed),
  cave rows the `"cave"` purpose as a protection floor (their writer applies
  none); at the surface the writer's
  host rule (r6_planner `p7_support`, in the authority's `writer_bare`): no
  anchor platform, no land grade except a dry anchor grade outside the
  vegetation exclusion, no sealed river/lake column, no surface cave mouth
  (coordinator ruling 2026-09-28: only protected areas and farm soil are
  excluded; the target is what the writer places); above the
  planned surface natural noon light ≥ 10 (≥ 13 for woody), cave mode at
  `y <= terrain_y - 2`.
- One class (resource / cover / woody) is chosen uniformly among those
  present, then a species uniformly (resources) or the category (cover and
  woody pick the species by rate at placement).
- Counting box radius `ceil(sqrt(1.5 / p) / 2)` clamped 4–24, ±4 high (woody
  trunks −4…+12). Target = `p × (open supports + present)`, rounded by a fixed
  per-patch fraction; shoreline species cap supports at 2 × box width.
- Present ≥ target: nothing. Otherwise chance = class chance ×
  (target − present) / target.
- Sapling: support in `group:soil`, then no non-natural node within 10
  (21³ box; natural = air, liquids, `grug_natural`, tree/leaves/sapling/
  flora/leafdecay groups, every generator vegetation node; 766 of the
  registered node names are non-natural, `ignore` included). Saplings count
  as woody plants until they grow.

## Constants (`grug_farming/renewal.lua`, `grug_farming.RENEWAL`)

`STEP_SECONDS 5`, `TICK_SECONDS 0.5`, `SAMPLES_PER_PLAYER 4`,
`MIN_PLAYER_DISTANCE 20`, `MAX_SAMPLE_DISTANCE 48`, `SPOT_HALF_HEIGHT 24`,
`TERRAIN_HALF_HEIGHT 8`, `MAX_TERRAIN_OFFSET 64`, `BOX_MIN_RADIUS 4`,
`BOX_MAX_RADIUS 24`, `BOX_TARGET 1.5`, `BOX_HALF_HEIGHT 4`, `WOODY_DOWN 4`,
`WOODY_UP 12`, `SHORE_BAND 2`, `CHANCE {resource 0.05, cover 0.5,
woody 0.1}`, `SAPLING_GUARD_RADIUS 10`, `VOLUME_BUDGET 150000`.
Light thresholds are in the authority: `SURFACE_MIN_LIGHT 10`,
`WOODY_MIN_LIGHT 13`. All rates are first-version feel for playtest tuning.

## Cost bound

Per player and 5 s step: at most 4 samples; area-query node visits ≤
`VOLUME_BUDGET` + 4 × 68 (spot columns) = 150 272, checked before each
counting query; at most 4 `set_node`; planner column lookups ≤ 4 × (1 + 4
shore neighbours + 1). Independent of world size; no stored state. Measured in
the engine (run 4): 60 services mean 209 µs, worst 1128 µs, worst accounted
visits 52 681; a sapling attempt including the 766-name guard query ≈ 1.2 ms.
At 100 players that is 20 services/s ≈ 4–5 ms/s mean.

## Sapling species

| Decoration rows | Sapling | Probe growth |
|---|---|---|
| meadows / deep forest / elf forest apple tree | `default:sapling` | grows |
| deep forest aspen | `default:aspen_sapling` | grows |
| elf forest silverwood | `grug_trees:silverwood_sapling` | grows |
| jungle tree, jungle edge tree | `default:junglesapling` | grows |
| emergent jungle tree | `default:emergent_jungle_sapling` | grows |
| pine hills pine / small pine | `default:pine_sapling` | grows |
| savanna acacia tree | `default:acacia_sapling` | grows |
| blight / bone forest gravewood | `grug_trees:gravewood_sapling` | grows |
| meadows bush, pine bush, acacia bush | `default:bush_sapling`, `default:pine_bush_sapling`, `default:acacia_bush_sapling` | grow |
| pine hills blueberry bush | `default:blueberry_bush_sapling` | grows |

No working sapling: crags snowy pine (`default.can_grow` needs `group:soil`,
the crags are gravel), badlands large cactus (seedling needs `group:sand`,
badlands are mesa clay), fallen apple log (not a plant), swamp papyrus (reed
stand). They do not renew.

Apples and blueberries: the apple tree template's 4 apples all carry
`param2 = 0`; generated apples found in the probe box had `param2 = 0`; a
picked apple leaves a timed `apple_mark`, picked berry leaves start their
timer (vendored `default`).

## Evidence

- Portable fixture `tools/r23_renewal/fixture.lua` (shipped pure sources,
  synthetic world): authority numbers, placement, distance, exclusions
  (settlement, road, protected, farm soil, unloaded), caves, density cap,
  sapling guard, saplings stop at the tree target, setting off, per-service
  budget, the writer's functional-surface rule (dry anchor grade grows,
  other land grade, anchor platform and surface cave mouth stay bare) and the
  per-class claim exclusions (anchor-blend envelope: cover yes, resources no;
  dry island coast: only P9G rows; water bank: cover and trees, no non-shore
  resources). Final pair on frozen bytes after the review fixes: LuaJIT and
  PUC 5.1.5 output byte-identical, sha256 `f92376a8…3c8f`,
  `DIGEST 1349223435`,
  `RESULT PASS` (`tools/r23_renewal/evidence/fixture.txt`).
- Engine probe `tools/r23_renewal/run.sh` (isolated headless, fresh world):
  run 4 `RESULT PASS (30 checks, 0 failures)`
  (`tools/r23_renewal/evidence/probe.txt`). Four engine runs in total, each
  under 2 minutes; runs 1–3 failed only on probe site selection (ground under
  plants, a spot on the start's functional grade), fixed in the probe.
  Run 5 (after the functional-surface change, probe extended with a dry
  anchor grade and a writer-bare grade) stopped at its first check: no open
  ground found around the same site that passed in runs 2 and 4, so no test
  ran (`evidence/probe-run5-fail.txt`; the probe now logs the site column
  when this happens; cause not determined, it did not recur). Run 6, the
  coordinator-approved final run on the final bytes: `RESULT PASS (31 checks,
  0 failures)` (`evidence/probe.txt`; before the review fixes, which were
  approved without an engine run), including a dry anchor grade near the
  dwarf start growing cover; no alterable writer-bare functional surface was
  loaded, so that case rests on the fixture. Service cost: mean 191 µs, worst
  1055 µs, worst accounted visits 52 681. Six engine runs in total.
- `tools/check_lua.sh` on every changed Lua file: parser and sweeps 1–6 pass;
  SETGLOBAL only `grug_farming` in `init.lua`.

## Open gaps and conservative decisions

- Functional surfaces follow the writer (see "Rules as built"); the first
  version excluded them all, which left the natural skin around starts and
  capitals without renewal. Resource rows use the same surface host rule as
  the decorations.
- Aquatic plants (coral, kelp, waterlily, waterweed), papyrus, cactus, the
  crags pine and bone piles do not renew.
- Shoreline density is an estimate (two supports per box width).
- Cover is counted as a total across all cover nodes; eligible supports count
  every host of the biome while the density uses the spot's support class
  (gravel vs soil), so mixed gravel patches are approximate.
- Player-placed logs, leaves and saplings count as natural for the guard
  (same node names as generated ones).
- Plants only need the same node as their habitat support, so they also grow
  on player-placed ground of that node (ruling 3).
- No road corridor was loaded near the probe start; roads are covered by the
  fixture and the planner overlay query.
