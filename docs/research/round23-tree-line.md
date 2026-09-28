# Round 23 Phase 2 — tree line, shrub band, snow, forests (receipt)

Branch `wp40-tree-line`, contract
[round23-world-life-plan.md](../planning/round23-world-life-plan.md) "Phase 2 —
vegetation and altitude" (user rulings 1–8, 2026-09-28) and "Engine run
budget". Implementer: Claude Opus 5.5 (native subagent). Independent review:
pending (coordinator). Design: [world_zones.md](../design/world_zones.md) §7.6
"Vegetation and altitude", [biomes_mobs.md](../design/biomes_mobs.md) §2.1,
[farming.md](../design/farming.md) "Wild plant renewal". Mapgen output
changes: fresh worlds only.

## What changed

- `wp40/habitat_registry.lua`: the one rule, `vegetation_rule(full_seed,
  land_zone_at)` — lines, jitter, warm offset, forest field with per-zone
  normalisation, five class factors, snow class — plus `decoration_class(row)`
  and `vegetation_factor(rule, class, values)`. Integer fixed point
  (ONE = 4096), no neighbour column, no `x ^ 2`.
- `wp40/r6_content.lua`: takes the habitat module (4th factory argument);
  `vegetation_rule(full_seed, planner_source)` builds the rule once per seed
  (planner, selector and the renewal authority share it); the surface
  selector takes the column's zone (6th argument) and returns snow-cap and
  dust rows; decoration population 48 → 52.
- `wp40/r6_planner.lua`: per-column class factors and snow flag in the cell
  scratch; a row's column is eligible with probability factor ÷ (class max ×
  ONE) by digest bytes 2–3, the cell budget multiplier is the class max
  (trees 5, shrubs 3, cover 1); columns with snow host no decoration.
- `wp40/r6_settlement.lua`: passes the zone to the selector (three calls).
- `wp40/zones.lua` + `wp40/planner.lua`: `planner_source.land_zone_at`
  (horizontal classification only) for the normalisation grid.
- `wp40/r7_r6_manifest.lua`: four band-only rows — `crags_pine_bush`
  (pine_bush.mts on gravel, 3/500), `deep_forest_bush` and `elf_forest_bush`
  (bush.mts, 1/250), `bone_forest_dry_shrub` (3/200). Ruling 4 names these
  shrubs for biomes that had none.
- `wp40/r7_manifest.lua`: decoded templates 21 → 24 and the pinned
  `decoded_templates` digest `b420d6c4…` (was `0f9c1230…`).
- `wp40/r6.lua`, `wp40/r7_runtime.lua`: plumbing (habitat dependency; the
  authority identity publishes `vegetation_rule` to `vegetation_density.lua`).
- `wp40/vegetation_density.lua`: trees and shrubs are separate classes
  (`TREES`, `SHRUBS`, markers per class); every species' density is its
  catalog weight × its class factor at the site; no decoration on a column
  with snow. `grug_farming/renewal.lua`: classes `tree` and `shrub` (chance 0.1
  each), both sapling-based and behind `grug_tree_regrowth`.

## The rule as built

Lines per column: start = 160 + s, line = 220 + s, snow = 280 + s, with
s = warm offset (40 for deep jungle, jungle edge, jungle fringe, savanna,
both badlands and every biome of the zone `front_skyglass_canopy`) + jitter.
Jitter = clamp(round((m − 512) × 54 / 1024), −15, 15), m = (3·N80 + N20)/4 of
the lattice noise (0..1023) of r6_content.lua with own salts; neighbour
columns differ by at most 2 nodes.

Class factors (ONE = catalog density), y = planned terrain height:

| Class | below start | start → line | line → line+20 | line+20 → line+40 | above |
|---|---|---|---|---|---|
| tree | F·D | F·D·(line−y)/60 | 0 | 0 | 0 |
| last_tree (crags snowy pine) | F | F until start+30, then F·(line−y)/30 | 0 | 0 | 0 |
| shrub | 1 | 1 + 2·(y−start)/60 | 3 | 3·(line+40−y)/20 | 0 |
| shrub_band | 0 | 3·(y−start)/60 | 3 | 3·(line+40−y)/20 | 0 |
| cover | 1 up to the snow line, 0 from it |||||

F = forest field, D = 1.5 in deep forest and deep jungle (tree class only),
clamped at 5. F = raw × count_zone / sum_zone, raw = grove × open, grove =
(N224 + 160)/672 (0.24–1.76), open = clamp((b − 250)/80, 0, 1) with
b = (3·N64 + N20)/4; count/sum of raw over the zone's land on a fixed 16-node
grid (x −3736…3736, z −3336…3336): every zone's mean is one. Construction
0.24 s under LuaJIT per environment.

Snow class: 2 (snowblock top + snow dust over the column's own filler) at
y ≥ snow; 1 (dust on the biome's top) in the 20 nodes below where
(N10 − 100)·20 < (20 − depth)·824; else 0. The selector asks only at
y ≥ 245 and never for steep rock faces (D77), shores, beaches, towns or wet
columns.

Row classes: trees = every template except the rows below; last_tree =
`crags_snowy_pine`; shrub = meadows bush, pine hills pine bush, savanna acacia
bush, blight dry shrub; shrub_band = the four new rows; cover = simple rows,
`swamp_papyrus`, `pine_hills_blueberry_bush`.

## Renewal

`vegetation_density.categories` returns `cover`, `tree` and `shrub` (plus
resources); each category's density is Σ catalog weight ÷ support cover ×
factor[class]/ONE from the same rule object the emerge planner uses (built
from the same seed and zone source); species are picked by those weights. A
column with `snow_class ≠ 0` grows no decoration. Differences from the
planner: renewal reads snow from the rule, the planner from the selected
surface, so a steep rock face inside the dust band is "snow" for renewal
(it hosts nothing there anyway).

## Measured shares (coarse analytic grid, 32 nodes, dry land, real zones)

`luajit tools/r23_tree_line/shares.lua <repo> 32 <seeds>`
(`tools/r23_tree_line/evidence/shares.txt`):

| seed | ≥ tree start | ≥ tree line (treeless) | ≥ line + 40 (no shrubs) | dust band | snow cap |
|---|---:|---:|---:|---:|---:|
| 4242 | 12.2 % | 4.9 % | 2.6 % | 0.3 % | 2.0 % |
| 10536739806879207652 | 11.8 % | 4.9 % | 2.5 % | 0.3 % | 1.9 % |
| 15140735923413111218 | 11.2 % | 4.8 % | 2.4 % | 0.4 % | 1.6 % |
| 1 | 13.5 % | 5.8 % | 2.9 % | 0.3 % | 2.1 % |
| all | 12.2 % | 5.1 % | 2.6 % | 0.3 % | 1.9 % |

Rulings target about 5 % treeless and about 2 % snowy.

## Evidence

- Portable fixture `luajit tools/r23_tree_line/fixture.lua "$PWD"` (real rule,
  real r6_content selector over a synthetic content contract, real r6_planner,
  real vegetation_density, real zones.lua planner source):
  `RESULT PASS`, 41 checks, `DIGEST 2072861016`
  (`tools/r23_tree_line/evidence/fixture.txt`). Covers jitter bounds and
  smoothness, determinism (two rules, 7 heights × 25 000 columns), another
  seed moves the lines, offsets (10 cold biomes, 6 warm, the Skyglass zone),
  every class curve against an independent float reference (worst 1.45/4096),
  the dust band (share 0.96/0.80/0.50/0.20/0.02 at 1/5/10/15/20 below the
  line), deep forests ×1.5; per-zone forest means on an independent grid,
  two seeds: 0.973–1.018 and 0.980–1.028 over 38 zones, world 0.997/1.002;
  the selector (cap rows, patchy band, no snow below it, bare rock faces,
  savanna 40 higher); the planner on a ramp (27 240 decorations: no tree at or
  above its line, no shrub beyond the band, none on snow, band-only shrubs and
  the crags pine present), chunk seams (the same cells from different
  planners and from two adjacent 80×80 slices: identical rows), realized trees
  vs catalog × factor on flat worlds (deep forest 1.002, deep jungle 1.005,
  pine hills 0.992, elf forest 0.997; ×1.51/1.52/1.00/1.01 against the
  catalog-only planner); renewal densities equal catalog × the planner's
  factors per class at 1 597 sites, nothing on snow; the real Stormvault peak
  area (seed 4242): 556 decorations, 75 trees, 30 of them in the thinning
  band, no violation.
- Renewal fixture `tools/r23_renewal/fixture.lua` updated to the tree/shrub
  split (rule from seed "1041", whose fixture area lies in groves): `RESULT
  PASS`, `DIGEST 1745745539`, including "trees at target, shrubs still below:
  bush sapling placed".
- `tools/check_lua.sh` on every changed Lua file: parser and sweeps 1–6 pass,
  no SETGLOBAL.
- No PUC run (mapgen exemption).

## Engine runs (budget about 4 × ≤ 5 min)

All through `tools/luanti_headless.sh` via `tools/r23_tree_line/run_dump.sh`
(fresh isolated user path, `LC_ALL=C`, `chrt --idle 0 ionice -c3`, seed 4242),
one at a time.

1. Failed at load (< 1 min): the pinned `decoded_templates` digest in
   r7_manifest.lua moved with the three new templates. Pin updated.
2. Failed in the emerge environment (< 1 min): the R5 planner checks the
   planner source's exact field set; `land_zone_at` added to it.
3. After, with the fast-path verify patch (`VERIFY_REGION`, the Round 23
   `make_patch.py --verify`) over the mountain box: 12 full tile columns
   prepared, 192 chunks, **67 fast-path chunks compared over the whole
   VoxelManip (content, param2, light, 1 404 928 nodes each), 0 differ**
   (`evidence/verify-summary.txt`, `verify-chunks.log.gz`); then both render
   boxes dumped; normal shutdown, about 2 min, no ERROR.
4. Before, the same dumps from an exported main tree (about 1.5 min, PASS).

Snow dust sits at terrain + 1, inside the preparation envelope's `above`
reach (≥ tallest template + 1), so `preparation_source.lua` and the fast-path
bounds needed no change; run 3 confirms it on a mountain above the snow line.
`pgrep -f '^luanti.bin'` is empty.

## Renders (`round23-tree-line/`, `tools/wp13/render_blueprint.py --view sw`)

- `mountain-before.png` / `mountain-after.png`: Stormvault Heights, x −1264…
  −1041, z −896…−673, y 93–442 (crags and snowy crags). Surface tops in the
  dump: before gravel 22 621 / stone 19 274 / snow dust 8 221 (snowy crags
  only); after snow 27 204 / gravel 13 061 / stone 9 860 (rock faces stay
  bare). Crags pine trunks 21 → 11.
- `forest-before.png` / `forest-after.png`: Ashenward March deep forest,
  x 240…463, z −768…−545, y 37–150. Trunk columns 1 276 → 1 552 (×1.22: the
  deep-forest ×1.5 times this box's local field mean, which contains a large
  clearing); visible groves and open ground.

## Choices by feel (the user tunes them)

Shrub peak ×3 and the 20-node hold; the crags pine's 30-node later onset;
jitter scale (54/1024, full ±15 at about the 5th/95th percentile) and periods
80/20; grove period 224 and range 0.24–1.76; clearing periods 64/20,
threshold 250, ramp 80; dust patch period 10; band-only row densities (equal
to the nearest existing row of the same shrub); snow caps cover outcrop
patches and scree too (only D77 rock faces stay bare); the blueberry bush and
the dry shrubs of badlands, savanna and swamp count as ground cover (they
reach the snow line); shrubs and cover do not follow the forest field.

## Findings and open points

- **Steep crags keep few shrubs.** In the mountain render box the planner
  places 72 crags pine bushes and 20 crags pines (portable planner, same
  seed), the writer keeps 1 bush and 11 pines: templates are rejected where a
  cell would replace natural ground (existing writer rule, e.g. a 3×3 bush on
  a slope). The shrub belt therefore shows mainly on gentler band ground
  (pine hills, bone forest, deep forest). A lower-profile shrub or a
  slope-tolerant placement would be a separate decision.
- The crags pine bush does not renew (sapling needs soil; crags are gravel).
- Realized density is still limited by template collisions; dense groves lose
  a few more trees to overlap than open woodland (not measured).
- The zone normalisation makes the forest factor step slightly at zone
  borders (per-zone scale about 1.0–1.7 of the raw field).
- The renewal engine probe (`tools/r23_renewal/grug_probe_renewal`) was
  updated to the tree class but not re-run.

## Runtime test plan (fresh world)

1. Fly over a high mountain (Stormvault Heights): trees thin out from about
   y 160 and stop by about 220, the line wavy; crags pines are the last trees;
   pine bushes above them on gentle ground; bare gravel and grass-free alpine
   ground, then patchy snow dust and a snowblock cap from about y 280; cliff
   faces stay grey stone.
2. A jungle or savanna mountain: the same pattern 40 nodes higher.
3. Walk through a deep forest: dense groves and 40–100-node clearings; the
   forest reads denser than before.
4. Walk on a snow cap: snow dust and snowblock, no grass or flowers on it.
5. Cut trees and bushes near the tree line and wait (renewal): saplings return
   only below the tree line; bush saplings return in the shrub band; nothing
   regrows on snow.
