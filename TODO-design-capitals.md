# TODO — Capitals as an authored mapgen pass, and how much of the landscape we author

Opened 2026-08-08 from the runtime test: the **undead spawn platform came
out in the middle of the ocean**, with the first land in sight but not
underfoot. The platforms *are* the capital anchors (`grug_core` capitals
table, x = 0 / ±550, z = ±900) — WP13 builds the real capitals exactly
there — so this is not cosmetic. It is the future capital in the water.

The owner's direction (2026-08-08): **author the capitals with their own
mapgen pass** — a small city centre with a king's hall and a few
reproducible districts around it (e.g. a mage quarter, a warrior quarter)
with fixed NPC types, randomised within a fixed skeleton for replay value.

## 1. The cost question, answered

**An own pass is "expensive once per capital region", not "expensive
everywhere".** `core.register_on_generated` fires for every mapchunk, but
the pass's first act is arithmetic: is this chunk within the capital's
footprint? Everything else returns immediately. This is exactly the shape
the shipped code already uses — the ocean mask's chunk-box fast path and
`build_camp`'s anchor test (`mods/MAPGEN/grug_mapgen/structures.lua`), and
the same reason the depth pass in WP34 is specced with a "chunk-box fast
path so it costs nothing above −1000".

So the runtime cost is: **6 capital regions × once per world.** The real
cost of the idea is authoring effort (schematics, district layout, NPC
placement), not generation time.

## 2. Why the same pass also fixes the ocean problem

A capital needs **guaranteed ground**, and today nothing guarantees it: the
platform height is resolved from the terrain (`grug_core.get_camp_platform_y`)
*after* mgv7 and the ocean mask have already decided whether that column is
land. An authored capital pass inverts the order — it **shapes its own
terrain** (raise/flatten a plateau, force the ocean mask to keep land
inside the footprint, carve a harbour edge instead of a coastline that
happens to fall there). That removes a whole class of bugs permanently
rather than patching each one:

- capital in the ocean (this report),
- capital on a slope with the platform half-buried (WP18's original bug),
- the coast noise cutting through a city district,
- `get_camp_platform_y` disagreeing between sessions (see §4).

## 3. Open questions

- **Q1 — Footprint and shape.** How large is a capital (city centre +
  N districts)? A square plateau, a terraced bowl, a coastal harbour town
  for the ones near a shore? Does the shape differ per race (elven
  treehouse settlement vs. dwarven hall cut into rock — `biomes_mobs.md`
  §1.4/§5 already ask for that)?
- **Q2 — Terrain authority.** Does the pass flatten to one y, or terrace?
  How does it blend into the surrounding terrain so the edge does not read
  as a box (the same problem the biome cuboids have — see the straight-line
  measurements in `biomes_mobs.md` §1.3)?
- **Q3 — District skeleton.** Which districts exist, and which are fixed
  vs. rolled? Fixed NPC types per district is the owner's requirement;
  the roll should be *which* district sits in *which* compass slot, and the
  building variants inside it.
- **Q4 — Interaction with the ocean mask.** The mask runs as a
  `register_on_generated` pass; the capital pass must run **after** it (or
  own the columns outright). Ordering between two Lua passes in the same
  callback is registration order — make it explicit, not accidental.
- **Q5 — Protection and POIs.** The capital footprint is already protected
  via the platform rule (`world.md` §2); an authored city needs the POI
  registry entry sized to the real footprint (`grug_core.add_poi`, half
  includes the ≥10-node surround).
- **Q6 — How far does authoring go beyond capitals?** The owner also asked
  whether we want to shape the continental geometry more generally. The
  three problems found on 2026-08-08 (floating trees, capital in the ocean,
  straight biome edges) share one root: **the engine mapgen places terrain,
  biomes and decorations in a single C++ call and we correct it from the
  outside afterwards.** Options, from cheap to structural:
  1. per-capital authored pass (this file's direction),
  2. authored "landmark" passes for other guaranteed POIs (mining camps,
     apex lairs, harbours),
  3. an authored coastline for the whole rectangle instead of a noise mask,
  4. a fully custom mapgen (`mg_flags` without decorations, everything from
     Lua) — solves all of it, and is a project of its own.
  **Decide 1 now, keep 2–4 as a documented ladder** so later work does not
  have to re-argue the premise.

## 4. Related bug found in the same test — RESOLVED (WP36, 2026-08-08)

**Report.** The troll capital platform resolved to **y = 8** in one session
and **y = 36** in the next, same anchor (550, 900).

**Diagnosis.** Not a persistence failure and not the mapgen fallback going
order-dependent again. There were simply **two deciders and only one of
them wrote anything down**:

- `grug_mapgen/structures.lua` measured the footprint heightmap median in
  the mapchunk it was generating and *persisted* the answer (36) through
  `grug_core.set_camp_platform_y`;
- `grug_core.get_spawn_pos` — and `protection.lua` — silently substituted
  the `CAMP_PLATFORM_Y` minimum (8) whenever `get_camp_platform_y`
  answered nil, and **persisted nothing**.

`get_camp_platform_y` answers nil exactly when `core.get_spawn_level`
does, and for mgv7 that nil is permanent, not transient: rivers, water,
and any terrain above `max(terrain offsets, water_level + 16)` = y 17 with
our offsets (`mapgen_v7.cpp:248-292`). The troll capital's terrain is at
36, so the engine never answered there in *any* session. Session 1 (in
which that mapchunk was never generated) therefore reported the unlogged,
unpersisted 8, session 2 generated the chunk and persisted 36.

The log confirms it: `set_camp_platform_y` logs only when it persists, and
in world `grwasd` there is exactly one troll line, `decided at y=36` at
12:40:05 in the *second* session — the 8 of the first session was never
logged because nothing decided it. 36 > 17 also proves the value came from
the heightmap fallback, i.e. that the engine spawn level was nil at that
column all along.

Two things in the report do not hold up and are recorded here rather than
smoothed over: the two numbers are **not** two log lines from one world
(`grwasd` logs only the 36; the `y=8` troll line at 12:31:40 belongs to the
earlier world `qrasdd`), and the load-time-zero path that
`grug_core/init.lua` warns about (`getSpawnLevelAtPoint` returning 0 before
`initMapgens`, `emerge.cpp:348-354`) was **not** involved — there is no
load-time caller in the tree, and no `capital platform decided` line in the
whole log comes from the `ServerStart` phase. The bug is reproducible
inside `grwasd` alone from the mechanism above.

**Fix.** One decider, and a caller that finds the platform undecided forces
the decision instead of inventing a height:

- `grug_core.request_camp_platform(race_id)` emerges the capital footprint,
  which runs the mapgen camp pass — the normal decider — and persists.
  `get_spawn_pos` calls it, and a staggered startup sweep calls it for all
  six capitals so an unvisited capital cannot stay undecided either.
- If the emerge still leaves it undecided, a map-side ground probe in
  `grug_core` decides from the finished terrain. That closes the one hole
  the heightmap median has and always had: a footprint whose surface sits
  exactly on a mapchunk y edge is unreportable through
  `Mapgen::findGroundLevel` (`mapgen.cpp:238-252`), and the platform then
  stayed undecided — and unbuilt — for the life of the world.
- `get_spawn_pos` now returns `pos, decided`. `decided = false` marks the
  provisional position that exists for the duration of one emerge and is
  never persisted; `grug_factions.teleport_to_spawn` already re-reads after
  the capital has emerged, which is why it moves nobody before then.

First-writer-wins is unchanged: a world that already has a platform height
keeps it, whichever of the two measurements got there first.

**Second round (same day, after the code review).** Four corrections, three
of them to claims made above:

- **"A session killed mid-emerge persists nothing" was only true for
  SIGKILL.** A *graceful* stop cancels the rest of the emerge queue and still
  runs every callback, with `EMERGE_CANCELLED` and a `calls_remaining` that
  counts down to 0 (`emerge.cpp:804` → `:494-508` → `l_env.cpp:141-158`),
  while the Lua env and the mod-storage database are both still alive
  (`server.cpp` `~Server`: `stopThreads()` at `:385` before `m_script.reset()`
  at `:426` and `endSave()` at `:435`; `content/mods.cpp:232-238` writes
  through). The old callback ignored `action`, so quitting mid-emerge made the
  probe measure a half-generated footprint and first-writer-wins made the
  result permanent — reproduced at a capital whose terrain is at y 90: the
  probe read the top of the generated mapchunk and persisted **47**. The
  callback now refuses on any `EMERGE_CANCELLED`/`EMERGE_ERRORED`, and the
  probe independently refuses on any `ignore` in a column above its ground
  node, so neither path can invent a height. **An uncertain probe persists
  nothing and retries later** (bounded at three emerges per capital per
  session).
- **A decided height was not a built platform.** `build_camp` only ever ran
  from `register_on_generated`, so in exactly the cases the probe exists for —
  the y-edge case on a *fresh* world as much as a legacy world whose capital
  chunks already exist — the chunks were on disk before the height was known
  and no platform was ever built, while every consumer of the height started
  behaving as if one were (spawn on raw terrain; `grug_traders/vendors.lua`
  placing vendors on the hillside, its `nil` guard having been the only
  brake). `grug_core.ensure_camp_platform_built` — a stub in `grug_core`,
  implemented in `grug_mapgen/structures.lua` — now builds it from the
  finished map, idempotently (the guard banner is the presence test), over the
  **whole camp volume** and never above the first y whose footprint still reads
  `ignore`. That `ignore` scan is the only bound; the *probe window* is not one
  (see the third round below, which is where the first version got this wrong).
- **A capital in deep water is now decidable.** `PROBE_BOTTOM = -16` sits far
  above the mgv7 terrain floor, so the ocean-floor capital of §1 produced no
  samples at all, a warning, and a session-long dead end. A column with no
  ground in the probe window now contributes `PROBE_BOTTOM` — which is not a
  guess: the true surface is then *below* the window, and every value below
  `CAMP_PLATFORM_Y` clamps to `CAMP_PLATFORM_Y` anyway, so every possible
  answer maps to the same height. Such a capital gets a platform island just
  above sea level instead of nothing.
- **"Exactly ONE decider" is precise about the height, not about every
  reader.** `protection.lua:127/180` still substitutes `CAMP_PLATFORM_Y` when
  the height is undecided. That is not a second decider: it persists nothing,
  and because `CAMP_PLATFORM_Y` is the *minimum* of the clamp the substitute
  always protects a superset of the real zone. It is a deliberate
  over-approximation, and it disappears on its own once the height is decided.

**Third round (same day, after the re-review of the fixes above).** Two
corrections to the repair build, one to a claim in the second round, and two
notes:

- **`calc_lighting()` on the repair build was a no-op that could kill the
  server.** The repair takes its VoxelManip from `core.get_voxel_manip()`, so
  `is_mapgen_vm` is false and `l_vmanip.cpp:208-215` only calls
  `log_deprecated()` and returns — the two lines had been copied from the
  mapchunk pass, which uses `core.get_mapgen_object("voxelmanip")` and *is* a
  mapgen VM. With the default `deprecated_lua_api_handling = log`
  (`defaultsettings.cpp:467`, `once = false`) that meant a warning plus a full
  Lua backtrace on every repair; with `= error` it raises a `LuaError`
  (`c_internal.cpp:169-187`) inside the emerge completion callback, where the
  engine turns it into `Server::setAsyncFatalError` (`s_env.cpp:328-332`) — the
  server aborts and the platform is never built. Removed. Lighting was never
  the call's doing anyway: `write_to_map` on a non-mapgen VM already takes the
  `blit_back_with_light` path (`l_vmanip.cpp:150`, `:164-168`).
  `update_liquids()` stays — `ModApiMapgen::update_liquids` handles the
  non-emerge case explicitly (`l_mapgen.cpp:1980-1998`).
- **"Inside the volume the emerge covered" was the wrong bound.** The camp
  volume runs `CAMP_CLEAR_HEIGHT` = 64 nodes above a height that may be
  `CAMP_PLATFORM_MAX_Y` = 100, i.e. up to y 164, while `CAMP_PROBE_TOP` is 120
  — so clamping the build to the probe window truncated the clearing for every
  capital above y 56 and left a rock/tree ceiling over the spawn. "The
  mapchunks above clear their own slice when they are generated" does not
  cover it: that holds for chunks generated *later*, and this build exists
  precisely for footprints whose chunks are already on disk. The build now
  takes the full volume, and the `ignore` scan alone decides how far up it
  gets. It scans only the footprint prism while the VoxelManip covers the
  block-rounded halo, which is sound because the rounding adds no *blocks*
  (`read_from_map` emerges exactly `getNodeBlockPos(p1)..getNodeBlockPos(p2)`,
  `l_vmanip.cpp:47-51`) and "un-generated" is a per-block property.
- **The self-heal was reachable only from the startup sweep.**
  `get_spawn_pos` returns the moment a height exists and never calls
  `request_camp_platform`, so a decided-but-unbuilt capital got exactly one
  repair attempt per session, at t = 60…135 s. A player joining later spawned
  on raw terrain every session. The decided branch now runs the built-check
  too; it is free once the platform is confirmed (session memo) and two node
  reads until then, with the VoxelManip behind it bounded at three tries per
  capital per session.
- **The repair is destructive by construction and now logs at `warning`.** A
  missing guard banner is read as "no platform", and the 25×25 footprint is
  then overwritten with no protection check. The re-review could not make that
  player-reachable (the footprint is `is_protected`, the banner has
  `drop = ""` and no recipe, no mob uses `pathfinding = 2`), so it is
  admin/legacy-only — but it is a destructive write and says so.
- **The "terrain reaches the top of the probe window" warning was
  tautological** (it formatted the constant, and the measured value can only
  ever *be* that constant). It now names the capital and says what the number
  means.

**Still true:** the authored capital pass of §1–§3 supersedes all of this by
shaping its own terrain, including the ocean case above, which the platform
island only makes survivable. The fixes above only keep today's spawns
consistent until then.
