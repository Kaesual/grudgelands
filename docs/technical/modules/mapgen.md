# Mapgen and world preparation

Part of the [module implementation guide](../module-guide.md), which indexes every
area. The WP40 R7 world generation pipeline, world preparation and the frozen R7 audit roster. Implementation seams and engine pitfalls only; the
[design docs](../../design/README.md) own the game rules. Source paths in code
spans are repository-relative.

Sections: [Mapgen and biomes](#mapgen-and-biomes), [Preparation](#preparation), [R7 audit boundary](#r7-audit-boundary).

## Mapgen and biomes

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- Test mapgen work on a fresh world.
- A `fail()` on the per-chunk path fails the seed fleet and the fixtures, so it must pass
  `quick`; on a live server it does not stop the server: the chunk keeps the engine's
  terrain and is reported through `grug_core.severe` (`wp40/degrade.lua`).

### The R7 pipeline, the only mapgen owner

- **Mapgen/biomes.** The **WP40 R7 pipeline is the only mapgen owner** since
  the production cutover: `mods/MAPGEN/grug_mapgen/init.lua` registers the protected POI display
  palette, then loads `wp40/r7_loader.lua`, whose header says it plainly — "Legacy
  biome/ore/decoration/ocean/structure loaders are deliberately absent".
  `grug_mapgen/biomes.lua`, `ores.lua`, `decorations.lua`, `geometry.lua`,
  `ocean_mask.lua`, `ocean_mask_mapgen.lua` and `structures.lua` **no longer
  exist**, and neither do `register_mirrored`, `column_cap`, `clean_shell`,
  `_grug_spawn_zones` or the `grug_core.*camp_platform*` family. Do not write
  code or a brief against them; `docs/design/world_zones.md` §§8–14 (with
  §§7, 9 and 14 describing the Round 22 target, not yet the code) and
  `docs/research/wp40-completion.md` are the current contract, and
  `docs/design/biomes_mobs.md` §1/§4 keep the retired WP18/WP36 tables as a
  labelled historical record only.
  What R7 registers, and what that costs you: **zero Lua biomes**. One
  mapgen script (`core.register_mapgen_script`, `wp40/r7_mapgen.lua`), one
  `register_on_generated` VM transaction, and the closed native allowlist in
  `wp40/r7_native.lua`: the gravel blob, five strata, three decorative nests
  and (Round 49) one scatter row per resource, tier band and deep band plus
  two biome-less `all_floors` cave decorations (Cave Cap, Ember Moss), all
  derived from the resource table and pinned by `NATIVE_DIGEST`. `game.conf` pins
  `allowed_mapgens = v7`; `default`'s own `register_biomes/ores/decorations`
  stay uncalled (GRUG PATCH at the tail of `mods/BASE/default/mapgen.lua`),
  because an ore or decoration whose `biomes` names do not resolve is silently
  unrestricted world-wide. The v7 terrain and climate noise params are
  overridden from `r7_native.lua` (`core.set_mapgen_setting_noiseparams`) —
  **test mapgen work on a FRESH world**, an existing one gets seams. The v7
  flags come from `minetest.conf` (`nomountains` since Round 49: no v7
  mountain stone for the writer to clear) and are checked at load in both
  environments (`r7_runtime.lua`, the R5 manifest's `caverns,ridges`).

### Registration order and the strata

  **Registration order is still a tool, not trivia**: in mgv7 a mapchunk runs
  caves (`mapgen_v7.cpp:335`) → ores (`:355`) → dungeons (`:359`), and inside
  the ore stage the ores run in **registration order**, each converting only
  nodes that still match its `wherein`. That is the whole mechanism behind the
  rock strata, which now live as five native `ore_type = "stratum"` records in
  `wp40/r7_native.lua` (the tier rocks `grug_materials:t2_stone` … `t6_stone` under
  `default:stone`'s own band): registered last against `default:stone`, they
  take exactly the nodes no other ore claimed, and — running after the caves —
  they convert the already-carved cave walls too, so those inherit their
  stratum for free. (Dungeons run after the ores, so dungeon walls are *not*
  stratum rock — accepted.) The scatter ores are registered after the strata
  and nests, so each lands in its band's tier rock.

### No default:stone below -100

  **Landmine since WP25: `default:stone` no longer exists below −100.**
  Every node whitelist, every `wherein`/`place_on` and every mob spawn
  `nodes` list that means "underground rock" has to carry
  `group:grug_stratum` as well, or it silently narrows to the −1…−100
  sliver (−40…−100 until Round 46). WP25 repaired exactly that on four cave spawn rows (zombie,
  giant spider, stone + mesa golem); `default:stone` itself carries
  `grug_stratum = 1`, so the group alone is the complete predicate.

### Two Lua environments

  **Two Lua environments, and the split is the rule, not a detail**: a pass
  that only needs the chunk belongs in the **mapgen env**
  (`core.register_mapgen_script`), a pass that needs `grug_core`, mod storage
  or the settlement/socket registries cannot go there at all and stays in
  `register_on_generated` in the main env. Constants cross via `core.ipc_set`;
  never copy them. **One lesson from the retired ocean mask is worth keeping
  for the next VM pass:** a pass that writes near the top of a mapchunk must
  reach **`emax.y`**, not `maxp.y`, because the engine places decorations up to
  the emerged top edge (`mg_decoration.cpp:424`) — clamping to `maxp.y` is what
  once left floating tree crowns over the water.

### One layout assembly, owner-only decorations

  **One layout assembly** (Round 37): inland water, roads, the start towns'
  ground, the capital planning and joins, and the horizontal and height
  factories live in `wp40/world_assembly.lua`, which `r7_runtime.lua` and
  every portable tool and the seed fleet build on (`tools/seed_fleet/
  runtime.lua` runs the real runtime and its per-chunk path against a fake
  VoxelManip); a tool never copies that wiring. **Decorations are
  owner-only**: a tree whose rotated footprint leaves its root's 80-node
  chunk is dropped, so tall trees thin out in height bands and along chunk
  borders (`docs/research/wp40-simple-map-r6-contract.md` §8.2, "Treeless
  bands"). A tree's roots lie inside its footprint, so a root run is
  written with its tree or not at all.

### Untouched chunks

  **Untouched chunks** (`wp40/air_chunks.lua`): `r7_mapgen.lua` returns
  before planning when the transaction provably changes nothing — native
  air above the writer's surface/content envelope (the engine heightmap plus
  that envelope, Round 23) or rock more than a mapblock below the authored
  floor y −37 and every fitted settlement, POI and anchor box (Round 49). A
  new pass that writes above that envelope, or below y −37 outside a fitted
  box, must extend the envelope or that file's argument first, or its chunks
  are silently skipped (`tools/r49_skip` checks the writer's result on
  skipped chunks) — unless it is a step of its own outside the refinement,
  like the guild rooms below.

### The Miner's Guild rooms

  **The Miner's Guild rooms** (Round 58, lane ROOMS): one room per lift
  level of every camp with a lift, around the camp's lift column at its
  tier's floor (−50, −250, −450, −650, −950, −1050). `wp40/guild_rooms.lua`
  (pure, loaded in both environments) builds them from the camps
  (`index(camps, floors)`: `list`, `rooms_for_camp`, the allocation-free
  `room_at`, `rooms_in`; a room is `{camp_id, tier, floor_y, minp, maxp,
  arrival, lift_cell}`, `floor_y` the open layer the feet stand in, `arrival`
  a position for `grug_home/travel.lua`'s safe arrival) and owns the shape
  (`cell_at_offset`: a 7 × 4 × 7 open room, three 1 × 2 exits ending at the
  box face in a plug one node past it (`room_plug_t1` … `_t6`: the host rock's
  look, digs and drops like it, non-ground-content, outside the protected
  box), the floor, four wall lamps, a 3-node mantle; a 13 × 10 × 13
  box; CAMPS' lift node `grug_mapgen:guild_lift` at the centre, param2 2,
  its front toward the arrival). `lift_camps(wp40, placement_layout)` is the
  one seam to the camp list (`r58_camps.lua` `camps` and `ROOM_FLOOR_Y`:
  36 camps, 148 rooms), read from the placement layout text in both
  environments (no IPC field); both log the room count and digest. The room step
  (`wp40/guild_room_writer.lua`) runs in `r7_mapgen.lua`'s callback after
  `refine_or_degrade` and outside it, with its own degrade
  (`[GRUG-SEVERE]`, key `mapgen_room:<chunk>`): every chunk writes the part
  of each room box and its plugs (`write_minp`/`write_maxp`, the box one
  node wider in x and z) inside its own minp..maxp (`set_node_at`, then
  `calc_lighting` on that part), so the early-out chunks and a chunk whose
  refinement failed get their rooms too, and a split room is the same in any
  chunk order. Every node it writes is non-ground-content
  (`guild_room_nodes.lua`: the airlike fill — walkable, floodable,
  buildable_to, pointable and diggable false, light passing — the floor, the
  mantle per tier in its host rock's look, the lamp), since a
  neighbouring chunk's caves, flooded caves and dungeons reach about 16
  nodes past its edge, sideways too, and spare only such nodes; the fill
  lets no liquid in. Main wraps the zone session once more
  (`wp40/guild_room_protection.lua`, beside the zone overlay, whose schema
  stays): inside a box `territory_rule_at` is `hard_protected`,
  `hard_protection_kind_at` `guild_room` (hint "Miner's Guild – protected")
  and the faction policy protects for
  everyone; the PvP rule and `hard_footprint_in` stay the session's. The
  rooms are public as `grug_mapgen.guild_rooms`; the ambient underground
  spawns (`spawn_policy.lua`) refuse a room box through `room_at`, the depth
  pulse through `hard_protection_kind_at`. Fixture `tools/r58_rooms`.

### Per-column caches

  **Per-column caches of the emerge environment** (the session's own,
  first in first out; every value is a pure function of x/z and the world,
  so a hit equals a miss): the planner column tuples (`zones.lua`
  `column_cache_limit`: 196,608 for the mapgen planner, `cache_purpose`
  "mapgen" from `r5.lua`; the main environment's sources keep 65,536), the
  R6 decoration candidates per 16-node cell (`r6_planner.lua`, 4,096 cells)
  and P9G's ranked roots per chunk column (`r7_p9g.lua`
  `COLUMN_CACHE_LIMIT`, 256 columns, production only), which the second
  surface chunk of a column settles instead of scanning again. The engine
  generates a column's chunks in its distance-shell order around every
  player, not bottom-up, so the sizes follow the Round 49 shell-order probe
  (`tools/r49_cache`, research doc
  [mapgen-chunk-profile-2026-10.md](../../research/mapgen-chunk-profile-2026-10.md)).
  A change that lets one of these values depend on the chunk's y range, its
  voxels or anything else outside its key re-keys or drops that cache in
  the same change (`tools/r49_cache` checks hit against miss).

### Trees

  **Trees come from the seeded generator** (Round 47): `wp40/treegen.lua`
  (pure, the port of the approved concept) and `wp40/tree_templates.lua`
  (the species table, the template seeds, the sparse variants). A
  `treegen:<species>` decoration row is expanded by `r6_templates.lua` into
  this world's variants at every construction, in main and emerge from the
  same seed string, so the two environments build identical templates (the
  manifest publishes their roll-up, `r6_generated_templates_sha256`, and
  both environments log it); its settlement class is computed, never pinned.
  The writer turns a variant per placement and places its roots
  (`kept_root_runs`) with a two-read ground test per cell; a generated tree
  reserves only its wood (occupancy -1) and leaf cells (-4), so crowns
  interleave, and `TREE_SPACING` (roots apart, Chebyshev) is the one
  forest density parameter. Saplings
  (`grug_trees/growth.lua`) and the town trees (`wp13/dressing.lua`) use the
  same generator. A change to the generator or the species table moves the
  sample pins of `tools/r47_tc/portable_test.lua`. Hanging kinds
  (`tree_templates.lua` `HANGING`, Round 51): a cell of such a kind with one
  of its kind right below takes the species' strand node, the lowest the end
  node, in the variants and the grown trees alike; `grug_trees/hanging.lua`
  keeps a dug run whole.

### The land kit

  **The land kit** (Round 51 lane LK, [biomes_mobs.md](../../design/biomes_mobs.md)
  §2.1): `wp40/kit_templates.lua` (pure) builds the kit's structures with
  the shape of the tree module (species table, template seeds under their
  own SHA domain `kit_template_seed_v1`, packed variants), and a
  `kitgen:<key>` row is expanded by `r6_templates.lua` like a tree row
  (`generated.kit`, records flagged `kit`). A kit variant is runs (no tree
  cells but the dead pine's): the writer (`row.generated_kit`) gives each
  run its columns' common ground offset (0, +1 or -1 against the root's
  level, kit ground `kit_ground_names`), places it where every moved cell
  is free (a cell below the level takes its column's dry surface top, never
  the wet bed), and
  rejects the structure when a `required` run cannot stand; no
  `TREE_SPACING`, no box reservation, only its cells. Kit rows are class
  cover without a factor (`r6_planner.lua` `decoration_kit`, snow
  included); renewal skips them and counts only their props as natural.
  The prop nodes are `grug_nodes/props.lua` (data `props_data.lua`,
  written by `tools/r51_lk/gen_props.py`); `tools/r51_lk` checks them all.

### Placement draws

  **Placement draws** (Round 49): the R6 decoration candidates (rank,
  thinning, cell budget remainder), the P9 rotations, heights, variants and
  template trials, the P9G ranks and remainders and the P8 fill ores draw
  from one integer hash, `r6_hash.lua` `placement(full_seed)`: `mix(a, b, c,
  salt)`, one cube round modulo a prime per input and a final one (no
  lattice period, no point mirror), with one salt per stream (domain, row
  id, seed), exact doubles, so LuaJIT and Lua 5.1 agree (`tools/r49_hash`). SHA-256 stays for identities
  (manifests, pins, cache keys) and the tree template seeds.

### Swamp pools and wrecks

  **The swamp's pools** (Round 47 lane SW, `tools/r47_sw/DESIGN.md`):
  `wp40/swamp_pools.lua` (pure, per column, from the seed and the planner
  source's analytic values) decides the pools by the user's rule: gentle
  ground only, at most one node levelled, never a lower neighbour pool, so
  no water flows. One object per seed (`content.swamp_pools`) is read by the
  surface selector (mud under a pool, mottled mud round it), the planner (no
  decoration root in a pool), the writer's surface skin (no opening at or
  beside a pool) and the swamp pass `wp40/swamp_writer.lua`, which the R7
  successor runs right after the road dressing (water, waterlilies, rooted
  and bank reeds, cattails, carpets, through `write_road`). **The wreck
  pass** (Round 51 lane WRECK) `wp40/wreck_writer.lua` runs right after it,
  before P9G and the world content (so kelp and coral grow round a wreck):
  a pure placement per 256-node cell from the seed, the water query
  (`water_query_at`), the planner source's seabed height and the horizontal
  world's claim exclusions (`lowest_exclusion_value_at` over the non-water
  kinds), capped at 4 wrecks a zone (the lowest cell hashes kept), for which
  the first ask lays out the whole world once per Lua state (about 0.5-0.65
  s, the same result whatever chunk asks first); every chunk writes the part of each wreck inside its own owner
  (no owner clipping), plain nodes through `write_road`, only over sea
  water, the natural seabed or a bed plant of the seabed growth (replaced
  whole; one rooted under a wreck cell goes back to sand, so no stem runs
  through a wreck). The shapes are data
  (`wp40/wreck_shapes.lua`, generated by `tools/r51_wreck/to_lua.py` from
  the design's shape files); fixture `tools/r51_wreck`, world counts
  `tools/r51_wreck/count.lua`.

### Seed-dependent POI placement

  **Seed-dependent POI placement** (Round 46, `world_zones.md` §8.5):
  `A.source` is the authored source, whose placed anchors
  (`placement_mode = "placed"`) carry no position; `W.place()` returns the
  world's source (`W.source`, every anchor with its position and its claim
  exclusions rebuilt by `source.claim_exclusions_of`), and every session
  factory of the world (`W.horizontal_factory`, `W.height_factory`,
  `W.zones`) runs on it. `W.place` builds the placement session on
  `placement.fixed_view(source)` (a roadless height session that also lays
  out the inland water) and calls `placement.place`, or parses the
  placement text (emerge, a layout-cache hit; `r7_runtime.lua`'s
  `placement_layout_text`, the `ipc_set` field `placement_layout`, the cache
  section `placement`, and `layouts_digest`). Only `source.fixed_anchors`
  feed `zone_field.keypoints`, the terrain field's bowls and the water
  inputs; a world's height sessions share one terrain field
  (`terrain_cache`). The kinds' rules are data (`placement_rules.lua`); the
  activation roster, the consumer payload and the road trails (`trail` on
  the fitting profile) find their anchors by kind, never by index. Tools read
  anchor positions from `W.source` or the zones session, never from the
  authored source (`tools/r46_pl/portable_test.lua`).

### Zone and level queries

  **Current zone/level queries** (published by `grug_core/zone_authority.lua`,
  which is also the sole publisher of the `grug_zones` global — it refuses to
  install if something else already published it) — this is the whole
  `grug_core` surface, not a sample: `territory_at`, `zone_at`, `mob_level_at`,
  `guard_level_at`, `open_sea_at`, `surface_level_at`, `start_position`,
  `start_anchor`, `start_identities`, `capital_anchor`, `outpost_at`,
  `outpost_patrol_target`, `outpost_position`, `rare_route` and
  `world_protected_for_faction`. `grug_core.difficulty_at` is **gone** — the
  difficulty field survives only inside WP40's own compatibility layer.
  Gameplay consumers read the richer surface off `grug_zones` directly
  (`biome_at`, `id_at`, `faction_at`, `race_region_at`, `pvp_rule_at`,
  `water_class_at`, `territory_rule_at`, `surface_mob_level_at`) and **never**
  the engine biomemap, because the authored surface pass — not climate
  competition — owns logical biome identity.

### The water query

  **The water query (Round 51 T2)** is `grug_zones.water_query_at(x, z,
  inland_distance)` (the
  zones session, `wp40/zones.lua`; the same function in the mapgen and the
  main environment). One column, no allocation; it returns six values:
  `class` (`"lake"`, `"river"`, `"bay"`, `"belt"`, `"channel"` or
  `"open_sea"`; a swamp pool reads `"lake"`, a bay's shore strip of the belt
  `"bay"`, as `water_class_at` reads it `planned_water` (Round 57 FIX56,
  `simple_map.lua` `bay_shore_at`; the mapgen's column tuple keeps
  `coastal_shelf`); on dry land it returns `nil`
  alone), the owning `zone id` (a channel's island's; `nil` for the open
  sea), the zone's analytic surface `mob level` (`nil` for the open sea),
  the `distance` to dry land in nodes (for the sea's classes the true coast
  distance of `simple_map.lua` `coast_distance_at`, the terrain field's
  16-node chamfer grid read through a spline; for lakes, rivers and pools
  only when the third argument is true, else `nil`: the nearest dry column,
  searched in rings up to 16 nodes, so a farther one answers 16),
  the `depth` (water nodes over the floor) and `protected` (immutable water,
  sea plan ruling 8: the open sea, and bay, belt and channel water 24 or more
  nodes off the coast). Outside the world's bounds it answers `"open_sea"`.
  **Cost** (seed 12345, LuaJIT, warm, measured over the columns of each
  class within 30 nodes of a spot): without the inland distance 0.1-0.7 us
  per call for every class, so a per-pixel map render or a spawn check calls
  it plainly; with it a lake column costs about 20 us on average and up to
  about 250 us (the ring search tests up to about 1,000 columns), so only a
  caller that needs the distance to a lake's or river's shore (the
  amphibians "near land") asks for it, once per decision.
  MOBS's water bands and MAP's water colours read it; the swamp pools are
  attached by `r6.lua` (`attach_swamp_pools`). The internal water classes
  (`water_class_at`: `planned_water`, `coastal_shelf` for the belt,
  `deep_ocean`, `immutable_dragon_channel`) keep their names.

### The difficulty seam

  **R7.6 difficulty seam (2026-09-18):** `simple_map.lua` derives straight
  z-axis progression extents from authored hub rows and the fixed
  Battlegrounds edges, splits each published zone range into three rational
  thirds, and serves an integer staircase through
  `difficulty_for_macro_at`; `zones.lua` applies the 100/150-node start safety
  override afterward. Accord runs toward +z, Throng toward -z, front zones
  toward z=0 and the two summits are flat 60. The compatibility method
  `difficulty_lattice_digest()` authenticates the profiles, raw-x midpoint
  selector results and complete integer staircases despite its historical
  name; there is no difficulty lattice or hub-target smoothing. Difficulty
  lateral selection is warp- and bias-free even though political ownership is
  not.
  The unchanged underground term already supplies three integer threshold
  steps per uncapped 50-node window, and `mob_level_at` remains
  `max(surface, depth)`.

### Near-water materials

  **Near-water materials (Round 22 D27):** the R8-MAP-A coast runs and
  profiles are retired. `height.lua` derives `coast_material_at` (sand,
  gravel, stone or nil) from the final terrain and exposes the same rule as
  `bank_material_at(x, z, water_y, distance)` for Phase 5 banks.
  `r6_content.lua` maps it to surface rows and is the only source of dry
  near-water sand; ordinary wet-bed sand remains unchanged. The one exception
  is the four dragon-island landing beaches (Round 30, `boats.md` §7.1):
  `height.lua` grades them (`landing_graded_at` decides which columns, also
  for the sand override) and `road_writer.lua` builds the pier from the same
  shore point (fixture `tools/r30_l/portable_test.lua`, engine probe
  `tools/r30_l/engine.sh`).

### PvP places and dragon arenas in the map

  **Round 31 mapgen:** the PvP POIs are anchors 101–118 of
  `source/simple_map.lua` (fitting profiles `pvp_fortress`, `pvp_camp_low`,
  `pvp_camp_high`); `r31_pvp_catalog.lua` names them as rules (zone, slot,
  kind, faction, band; `camp_levels`, `camp_race` through the blueprint
  options' `raw_sha256` seam, the same in main and emerge, `SEAT_RACE`),
  `r7_settlement.lua` binds every row to its anchor (all or none) and the
  gate turn (by faction; since Round 46 the placement keeps the fortress on
  its side of the middle road), and `r31_pvp_poi_blueprint.lua` is the pure cell builder
  (sockets as landmarks; `landmarks.race`/`faction` name what the
  settlement registers as). `road_layout.lua` routes a fortress's gate trail
  (`GATE_STRETCH`) and every road round the PvP POIs' reserves (since Round
  46 the POIs are placed before the roads are routed, so every road bends
  round them). `world_protection.lua` grows a PvP
  slot's box by `PVP_MARGIN` (10), kinds `fortress` and `war_camp`. The
  dragon arenas: the `dragon` profile carries `arena_radius` 40 and
  `bowl_core_width` 32; `height.lua` grades the round floor;
  `arena_layout.lua` (pure, shared with `grug_mobs`) and `arena_writer.lua`
  (the last pass of the R7 successor settle) place the hazards, registered
  in `world_nodes.lua`. Contested depth is one constant,
  `CONTESTED_DEPTH_Y = −501` in `zones.lua` (PvP and territory). Fixtures
  `tools/r31_s`, `tools/r31_m` (incl. `spacing_check.lua` over six seeds,
  `engine.sh`), `tools/r31_da2`, `tools/r24_protection_depth`.

### Mining camps

  **Round 58 camps** (the Miner's Guild): anchors 119–144 of
  `source/simple_map.lua` (pass 2; fitting profiles `mining_camp`, with a
  trail, and `camp_construction`), rules `r58_camp_catalog.lua` (the 20
  mining camps and 6 camps under construction by zone, faction and race,
  the lift offsets `LIFT` per composition kind, `ROOM_FLOOR_Y`, `tier_of`),
  bound by `r7_settlement.camp_profiles` (turned by
  `r31_pvp_catalog.gate_turns`, the war camps' rule) and built by
  `r58_camp_blueprint.lua` (a camp under construction from the templates
  `camp_site_<race>.tpl`; `camp_rewrite.lua` with `wp40/r69_camp_sites.lua`
  is the migration 0.69.0's box rewrite, upgrade contract §5.9); the war camp blueprint gains the lift,
  `quest_foreman` and `vendor_camp` sockets. The lift node
  `grug_mapgen:guild_lift` (`world_nodes.lua`, `4dir`, written facing its
  camp's gate and turned with it: `wp13/parts.lua`) is settlement palette
  content like the waystone (no class of its own in `r7_content.lua`). Its
  static fields that the class row digests (paramtype, paramtype2,
  light_source, sunlight_propagates, floodable, the liquid fields, the
  groups grug_natural and grug_air) change only in `world_nodes.lua`, in a
  map reset round: main computes the settlement semantic digest before the
  other mods load and emerge after, so LIFT's override from grug_guild
  changes only the right-click (the picked look, node box and selection box
  are static fields there). The camp vendor is
  `grug_traders:vendor_camp` ("Camp Vendor", a profession-style vendor
  without a shelf: its Buy mode is CAMPNPC's reputation page). **The camp module** `r58_camps.lua` (pure, main and
  mapgen environment, from the `placement_layout` text or parsed
  positions): `camps(layout[, seams])` (the 36 camps with a lift sorted by
  id: `{id, kind, faction, race, zone_id, tier, anchor, lift, levels, label,
  anchor_id}`; `seams = {raw_sha256, full_seed}` rolls a war camp's race),
  `under_construction(layout)`, `ROOM_FLOOR_Y` and `index(layout, seams)`,
  published in main as `grug_mapgen.mining_camps` (`camps`,
  `under_construction`, `get(id)`, `near(pos[, radius])`). The camps carry
  no activation node, so `r7_anchor_roster.lua` and the zone overlay keep 42
  rows and 36 columns. Classification: `world_protection.settlement_kind`
  (`mining_camp`; a camp under construction `war_camp` with the PvP margin),
  `grug_map/settlement_icons.lua` (category: mine or war camp;
  both maps use `MARKER`/`marker(slot)` for the dedicated
  `grug_map_mining_camp.png`, `grug_map_camp_construction.png`),
  `spawn_policy.protected_spawn_surface` and `roam_avoid` (`mining_camp`),
  `grug_core/settlement_sockets.lua` (role `lift`, vendor kind `camp`),
  `grug_mobs/pvp_garrison.lua` (third argument the camp catalogue: a mining
  camp is settlement kind `mining_camp` without garrison, a camp under
  construction a `pvp_camp`). The socket contract:
  [settlements.md](../../design/settlements.md) "Round 58 mining camps and
  camps under construction". Fixture `tools/r58_camps`; the seed fleet
  checks every camp per seed.

### The decor pass

  **Round 36 mapgen (decor pass):** `wp13/decor_kit.lua` (pure) owns the
  pieces (`M.piece` in the race's palette), the whole-or-error placement of
  an authored row (`M.place`: open ground only, never a path, built cell,
  socket or the cell before it, a door's approach, the central actor
  clearance or before a window) and the house touches (`M.dress_house`,
  `M.houses_from`, `decor_kit.dress_rooms` in Hearthpine; in the other five
  start towns and every capital the touches are template content since
  Round 56). The Round 20 catalogue's `props` rows and the Round 14
  builder's `DECOR` table are kit pieces; the four rift candidates keep
  their four `props` positions (`rift_core.lua` reads them) and carry the
  rest as `decor`. Fixture `tools/r36_w` (every composition's bounds,
  airspace and sockets against `baseline.tsv`, windows, headroom, ways,
  benches); `tools/r36_w2` (which way every bench of every composition
  looks: a seat looks away from its stair's raised half, along facedir
  param2 + 2, never at a wall it could have its back to; `engine.sh`
  measures the raised half of Highcourt's seats in the engine); renders
  `tools/r36_w/render.py`, the whole roster `tools/r36_p`.

### Building templates: the start towns

  **Round 56 (building templates):** the six start towns build their
  buildings from text templates
  ([building-template-format.md](../building-template-format.md)):
  `building_templates/templates/*.tpl` and one
  `building_templates/layouts/<town>.layout` each, read at load by
  `wp13/templates.lua` (a malformed file stops the load with file, line and
  reason; `templates.town(id)` parses a town's layout and templates once,
  `town.part(place)` fills a part for the placement's palettes and
  `parts.stamp` places it as before; `templates.sockets` places a town socket
  that names its `building` from that template's `sockets` point). The
  templates hold what the towns used to write into a building after stamping
  it (belfries, the shrine spire, market lanterns, gable lights, wheels,
  indoor crates, cressets, deck braziers, room and apron decor); the streets,
  terrain, podiums, parapets, outer stairs, deck ropes and lanterns, trees,
  the pane pass and Hearthpine's decor stay town code
  (`tools/building_templates/freeze_report.txt`). The templates are the
  source of truth; the generators the start towns alone used are gone
  (`buildings.barn`, the inn, barn, carver, lodge and smoker kits).

### Building templates: the capitals

  **The six capitals** followed in the same round (lane FREEZE-CAPITALS): their
  core buildings and every district plot's building are templates too, but
  their placement stays algorithmic (the core's composition, the plot
  planner), so each capital has a ROSTER instead of a layout
  (`building_templates/layouts/<capital>.roster`: its named palettes and one
  `use` line per template and palette combination with its count).
  `templates.capital(id)` parses the roster and every template it lists at
  load; the core's `PLOTS` rows and the district rosters name each
  placement's `template` and roster palettes, `capital.part(template, id,
  main, roof)` builds it (only a combination the roster lists) and counts it.
  The templates hold the hall floor bands, braziers and hangings, Highcourt's
  chapel belfry, Gor Drazhak's deck breastworks, the room decor and the temple
  elders' doorsteps (the door-tagged sockets: a template `sockets` point
  without a role is a town entry's position, `templates.collect_sockets` and
  `templates.stamped_point`); the plot builders read the part's `extent` and
  `top` meta where they measured the generator's part. The capital services
  (`capital_services.decorate`), the plot dressing, lamps, gardens, paving,
  the city edge and the trees stay code (`freeze_report_capitals.txt`).

### Planted templates and the template gate

  **Planted templates** (lane TREES, format doc §4.2): the groves, orchards
  and copses and the Lethariel boughs hold their cells before planting, their
  stems as `trees` points (planter and height, in planting order),
  `plant_spacing` and `undergrowth` meta and the cells written after planting
  as `late` legend entries; `templates.part` plants at the stems with the
  live tree generator (`dressing.lua`, the placement's main palette, in the
  part's frame), scatters the undergrowth and then writes the late cells, so
  a change of the tree generator reaches every tree (fixture
  `tools/r56_trees`). The
  building generators are gone (`buildings.lua`, `capitals.lua`,
  `roofs.lua`, `interiors.lua`, `elf_parts.lua`, `troll_parts.lua`,
  `undead_parts.lua`); `troll_palette.lua` stays for the tools (the game
  reads the Kezamba roster). Gate:
  `python3 tools/building_templates/check.py` (structure always, the editor
  palette, reachability and the entrance only for cells edited against the
  commit `building_templates/BASELINE` names; `--self-test` runs every rule);
  the gate also runs the game's own loader over the files and builds every
  town and capital from them (`loader_check.lua`), holding each roster's
  counts to the build;
  `tools/check_upgrade.py` wants a map reset whenever what the towns build
  changes against the pushed commit (`tools/building_templates/town_identity.lua`:
  the start towns' identities and point digests, the capitals' identity,
  point and build digests). The world-folder layout cache digests the `.tpl`,
  `.layout` and `.roster` files with the mapgen sources. Exporter
  `tools/building_templates/export.py` (the record of the freeze from the
  pre-freeze generators, `export.lua` for the start towns,
  `export_capitals.lua` for the capitals; its `--check` is retired since the
  first deliberate template edit, Round 58), fixtures `tools/r56_freeze_towns`
  and `tools/r56_freeze_capitals`.

### Strata bands and caves

  `r6_settlement.lua` owns shallow filler/stone-only strata and the final cave
  transaction. A surface row may carry `bands` (seven content refs by
  `y % 7 + 1`) and `band_depth` (Round 51 T4, the badlands' clay bands from
  `r6_content.lua`): the strata pass then lays that cycle from one node below
  the top down `band_depth - 1` nodes, over the column's stone and its own
  filler only (never a resource ore, a cave or water; a native gravel blob
  under a gravel-filled band row may take a band), and its ordinary strata
  below. `zones.lua` publishes 80-node owner-local cave candidates but
  never an offline cut; the writer carves only after immutable native-v7 air
  beneath a three-node roof is witnessed within 24 vertical and (for a
  sinkhole) 24 horizontal nodes in the same mapchunk, then validates the exact
  path against natural input and every surface exclusion. A commit additionally
  requires at least 24 unchanged native-air nodes outside the lumen, continuation
  to the boundary of a radius-12 proof box and no native-surface/sky contact in
  that bounded component. Closed and isolated pockets are rejected. Do not move cave
  connection decisions into the planner or infer them from emerge order.

### Spawn rows and fixed bosses

  LotT trick: biome signature nodes drive mob spawns via a node whitelist —
  those tops live in `grug_nodes` (blight_dirt, bone/forest/silver litter,
  mesa_clay, mud) and exist FOR the trick; the generic `_grug_spawn_check`
  and `grug_mobs/spawn_policy.lua` do the gating on top, against `grug_zones`.
  `register_spawn_role` also owns each family's `clock`; its spawn wrapper
  stamps the mobs_redo light/day convention and the night `aoc`, while
  underground rows (top at or below `grug_mobs.UNDERGROUND_TOP` = −1, Round
  46; −40 before) remain light-only and get the underground `on_spawn`
  (`underground_spawned`: the sight and the elite roll, `skip_elite` for a
  caller with its own spawn rule). Never hand-maintain those fields on
  a new surface row. Since Round 30 (P2) a surface row no zone keeps
  registers no ABM at all (`spawn_policy.lua` `spawn_row_kept`; the spawn
  regions own every zone's surface), and every remaining row goes through
  `mobs.register_spawn_abm` into one of three merged ABMs
  (`grug_mobs/spawn_abms.lua`: underground, water, surface). A merged ABM
  picks at most one row per triggered node with the probability that keeps
  that row's chance × interval rate, then runs the row's own unchanged
  `spawn_action`; a new row needs nothing beyond `mobs:spawn`. The Round 24
  per-point palette budget is gone; the zone budget of `grug_mobs/density.lua`
  is what the region spawner shares out.
  Fixed bosses do not register ambient rows: `grug_mobs/bosses.lua` owns the
  two authenticated island `dragon` anchors, while the six kings and their
  four-guard groups consume the capital `king`/royal `guard_post` sockets via
  `start_npcs.lua`. Their respawn timestamps are absolute `os.time()` values;
  never route them through the ambient spawn clock or gametime respawn path.

### The world contract

  **The WP40 world contract is SHIPPED** (decided 2026-08-11, delivered
  2026-09-13): exactly **38** land zones in
  `docs/design/world_zones.md` §§8–9, each with one `race_region`; six
  start/home/capital chains, every ordinary level-31–60 zone contested, and
  two level-60 dragon endpoints. The hybrid-v7
  pass and `grug_zones` API are §13; acceptance is §14 (Round 22 minimal
  policy).
  Race region, territory and PvP rule are independent fields. Every ordinary
  level-31–60 land zone is contested and editable by both factions. Roads
  (corridor segments) and POI, village and camp building cores (boxes) are
  world-protected in the 128-node candidate grid (`world.md` §2 R1b, Round
  25); bounded functional anchors keep their hard protection; the remaining camp shells, tents, fences and battlefield
  dressing are mutable.
  Material design owns the complete `race_region` mapping of
  signature wood (gems are depth-tiered, not
  regional); map code stores only the
  region identity and placement data needed to consume that mapping. Each
  endpoint apex camp has no renewable sockets (renewable ores are removed,
  2026-09-29); its small functional anchor and building-core box are
  protected, while the rest of the camp shell remains mutable.

### Boundaries that tests must cross

- **Mapgen boundaries that tests must cross** (moved from AGENTS.md,
  2026-10-05): a change to the R7 content projection or the planner column
  tuple is tested through the real consumers, `r7_manifest.new` and the
  planner's `plan_slice` (`wp40/r7_manifest.lua`, `wp40/planner.lua`); a
  self-built receipt passed to `validate`, or a fixture of the source tuple
  alone, does not prove them. Resource roots: `docs/design/world_zones.md`
  §11 (demand-driven sampling, adopted by the user on 2026-09-13) is the
  root-selection rule of both the VM writer and the resource census; the
  per-host root SHA ranking in the frozen R6 contract and artifacts is
  historical evidence, not an output oracle, and is not restored.

## Preparation

- **Preparation (Round 14):** `grug_core` freezes starts/full mode in world
  storage on first boot. A stable aligned plan has one in-flight chunk and a
  success-only cursor; dispatch occurs in throttled globalstep, not callbacks.
  Full mode includes a 320-node ocean margin and replaces starts preparation.
  Round 16 resolves one conservative surface envelope at a time, counts completed
  horizontal tiles and persists the inner Y-chunk cursor. Its authority identity
  binds stable seed/content and bounded terrain-source bytes, never runtime CIDs.
  No full-world height prepass, exact savings run or ETA retuning.
  Preparation precedes character selection. Bounded scan-time/small-batch
  selection dispatches available work immediately while retaining one in-flight
  request. Waiting may be dismissed without releasing safety gates; nothing
  reopens it (a failure updates the hint and the inventory formspec, which
  keeps the retry form). Both creation and reconnect use
  the shared waiting/stasis gate. Native tests
  use isolated tiny bounds; never run production full generation as a test.

## R7 audit boundary

- **R7 audit boundary**: the 157-file R7 source-audit roster is frozen
  historical evidence and is not a current-source gate. Its audit script was
  retired in Round 22 and WP49, the planned replacement, is canceled
  (2026-09-29); never refresh or cite the old baseline-derived list as current
  certification.
