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

## 4. Related bug found in the same test (not a design question)

The troll capital platform resolved to **y = 8** in one session and
**y = 36** in the next, same world, same anchor (550, 900) — from the
`grwasd` debug log. That is the generation-order-dependence class WP18
already fixed once for the platform height
(`grug_core.get_camp_platform_y` persists per race in mod storage, and the
height is supposed to come from `core.get_spawn_level` first with a
heightmap median as fallback). Needs its own investigation: either the
persistence is not being read, or the fallback path is order-dependent
again. Filed here because the capital pass would supersede it — but it
should be fixed before then, since it affects where players spawn today.
