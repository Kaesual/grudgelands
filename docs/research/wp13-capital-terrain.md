# WP13 round 3, lane 1: capital terrain — step bands and race ground

What shipped on `wp13-r3-terrain`, 2026-09-15, against the two playtest findings
the user raised after round 2:

1. **The capital terraces were walls.** WP40 quantises a capital's 512-node
   fitting onto a lattice of the race's terrace step — 2 for the human, 3 for
   elf, undead and troll, 4 for dwarf and orc — and the risers between the
   plateaus were vertical. Jump height is one node, so the user could not climb
   from one Highcourt terrace to the next, and Dur Brannoc's four-node walls
   were absurd.
2. **All six capitals were the same stone slab.** A capital fitting publishes
   its whole graded envelope as `land_grade`, the R5 planner turns that into
   `ROLE_PATH_SURFACE`, and the content projection resolves that role to
   `default:stone` everywhere. A capital therefore sat in a 704 × 704 square of
   bare stone with no topsoil, no dust and nothing growing on it.

Both are terrain, both are WP40's, and both are fixed here.

## 1. The step band

`mods/MAPGEN/grug_mapgen/wp40/height.lua`, `fitting_grids.band` and the new
seventh argument of `capital_terrace_value`.

### What it is

For a capital column the terrace lattice value `T` is still
`reference + step * round((incoming - reference) / step)`, exactly as before.
What changed is that the value handed on is no longer `T(x, z)` but the
arithmetic **middle of `T`'s morphological erosion and dilation** over a
Chebyshev disc:

    erosion(x)  = min over the disc of  T(x') + chebyshev(x, x')
    dilation(x) = max over the disc of  T(x') - chebyshev(x, x')
    banded(x)   = round((erosion(x) + dilation(x)) / 2)

Erosion and dilation of any field are 1-Lipschitz under the Chebyshev metric,
so their middle changes by at most one node between neighbouring columns —
which is the jump height. A vertical riser of `step` becomes a flight of
one-block ground steps. No stair nodes, no built steps: the ground itself
steps, which is the user's ruling.

### Where the band sits: centred

Erosion alone would cut the band out of the **upper** terrace, dilation alone
would fill it onto the **lower** one; either way one plateau loses `step`
columns of flat ground and the other keeps all of its own. The middle is
**centred on the old riser**: both plateaus give up about `step / 2` columns,
the band's mean height is the old riser's, and a plot's reference column
therefore moves by at most half of what a one-sided band would move it. That is
the constraint the brief set — plot-carrying ground as flat as possible — and it
is what the measured plot legality below shows.

### Two things that had to be added after measuring

* **The disc is limited to one step.** An unlimited middle also averages away
  NATURAL cliffs, where the lattice jumps several steps at once. Measured on
  Dur Brannoc's crag at world (-1902, -1533) it cut and filled up to 13 nodes
  and turned an 8-node natural wall into a 12-node one. A neighbour whose
  terrace is more than one `step` from the centre's is therefore not in the
  disc: the band never moves a column further than `step` from the terrace it
  had, and an isolated riser sees exactly the same disc as before.
* **The disc is shifted onto the caller's own surface.** The band needs a
  neighbour's terrace, and a neighbour's `incoming` is not something
  `fitting_grade_at`'s caller holds — `incoming` at the `composed_land_values_at`
  seam already carries the road and coastal grades. The band reads the
  pre-grade relief (`fitting_grids.band.relief_at`) as a SHAPE and shifts every
  column of the disc by the centre column's own `incoming - relief`, so the
  centre keeps exactly the terrace it had. Without the shift the terrace follows
  the ungraded relief and drops away from a graded shoulder: measured on Dur
  Brannoc's north-west road shoulder, where the grade lifts the ground 10 nodes,
  the unshifted band cut 13 of them back out.

### The radius: `step - 1`

`CAPITAL_BAND_RADIUS = {[2] = 1, [3] = 2, [4] = 3}`. An isolated riser only
needs `ceil(step / 2)`, but a capital envelope's risers are not isolated: where
the ground under the fitting is steep, two terrace levels stand two or three
columns apart and a disc that spans one riser leaves the pair a wall. Measured
over Dur Brannoc's ±250 envelope, unclimbable land columns per thousand
(seed 8675309 / seed 531802985935182545):

| disc | per mille unclimbable |
| --- | --- |
| none (vertical risers, `main`) | 79 / 76 |
| radius 2 | 32 / 34 |
| radius 3 (shipped) | **27 / 29** |
| the same envelope's UNGRADED relief | 26 / 28 |

A wider disc buys almost nothing more and every column of radius costs a
quadratic number of relief queries.

### Cost

The band asks for the pre-grade relief of `(2r+1)^2` columns — 9 for step 2, 49
for step 4 — and 24 or 48 of them are asked for again by the neighbouring
column. `fitting_grids.band` therefore carries a **128 × 128 direct-mapped tile
cache**, one key array and one value array, 16384 entries: slot
`(x mod 128, z mod 128)`. Two columns collide only if they are 128 apart on an
axis, which no band ever spans, and the cache is pure memoisation of a pure
function — a hit and a miss return the same number, so no digest depends on it.

Measured offline, the cost of reading the pure final height of a whole ±250
envelope (251001 columns), LuaJIT, one process:

| capital | before | after |
| --- | --- | --- |
| Highcourt (step 2, radius 1) | 2.4 s | 7.7 s |
| Dur Brannoc (step 4, radius 3) | 2.4 s | 15.4 s |

That is the worst case for the band and the best case for everything else: a
pure height sweep is nothing but the thing the band made more expensive. The
per-mapchunk figures the engine passes record are in the evidence.

## 2. Race ground and vegetation

`r6_planner.lua`, `r6_settlement.lua` (three sites) and `simple_map.lua`.

The mechanism already existed and already did exactly this job for the six
starts: `dry_start_grade`. A start's own dry grade keeps its **biome** surface
instead of the path-surface stone, and that surface is also what a biome
decoration needs under it. The capitals joined it — the predicate is now
`anchor_001`..`anchor_012` instead of `anchor_001`..`anchor_006`, in all three
places that carry it (the planner's decoration-host predicate, the analytic P7
material reference and the P7 surface/filler write).

No new role, no new opcode, no `aux` channel, no change to the R5 candidate
tuple, no new node in the production palette. The zone biome palettes already
say what each race's ground is, and they say the contract's §2.4 intent:

| Capital | Race | Zone biomes | Surface |
| --- | --- | --- | --- |
| Highcourt | human | meadows, deep forest | `default:dirt_with_grass` — the grass plateau |
| Dur Brannoc | dwarf | pine hills, crags | `default:dirt_with_coniferous_litter`, `default:gravel` |
| Lethariel | elf | elf forest, deep forest | `grug_nodes:dirt_with_silver_litter` — the grove |
| Nhal Veyr | undead | blight, bone forest | `grug_nodes:blight_dirt`, `grug_nodes:dirt_with_bone_litter` |
| Gor Drazhak | orc | savanna, badlands | `default:dry_dirt_with_dry_grass`, `grug_nodes:mesa_clay` |
| Kezamba | troll | jungle edge, deep jungle, swamp | `default:dirt_with_rainforest_litter`, `grug_nodes:dirt_with_canopy_litter` |

### Where vegetation may root, and where it may not

The surface material is written over the WHOLE graded envelope: the P7 write is
not claim-gated, exactly as for a start.

The decoration HOST is claim-gated, and the gate is unchanged in shape: the
`"vegetation"` purpose now skips a capital's 704-node blend exclusion the way it
skips a start's, and the capital's own **532-node hard build square**
(`exclude:active:hard_capital_build_plus_apron_v1`) is a separate shape in the
same bucket and keeps answering. So:

* the 532 square where WP13 stamps the core, the plots, the avenues and the
  curtain wall stays **host-free** — no WP40 tree, bush or grass tuft is ever
  written inside a capital's build square, which is why a tree cannot be left
  standing in a plot footprint;
* the collar between 532 and 704, which is terrain and not settlement ground,
  grows its biome again instead of being bare stone.

**This is deliberately narrower than the user's ruling 2**, which asks for
vegetation on the plateau itself wherever no plot or avenue claims the ground.
WP40 cannot decide that: the plot and avenue layout is WP13's and is not visible
to the claim compiler. Planting inside the walls belongs to the lane that owns
the district fill, where "no plot claims this" is a fact and not a guess. See
"What is open".

## 3. Measurements

Unclimbable land columns (a land neighbour more than one node up) per thousand
land columns, both gate seeds, before → after. `natural` is the same window
measured with the capital terracing switched off, i.e. the ground's own relief.

### The whole ±250 envelope

| capital | seed | before | after | natural |
| --- | --- | --- | --- | --- |
| Highcourt | 8675309 | 113 | **12** | 7 |
| Highcourt | 531802985935182545 | 109 | **8** | 7 |
| Dur Brannoc | 8675309 | 79 | **27** | 26 |
| Dur Brannoc | 531802985935182545 | 76 | **29** | 28 |

### The ±128 district ring, all six capitals

`tools/wp13/capital_terrain_fixture.lua`, seed 531802985935182545 / 8675309:

| capital | step | before | after | ceiling |
| --- | --- | --- | --- | --- |
| Dur Brannoc | 4 | 116 / 109 | **78 / 65** | 85 / 75 |
| Highcourt | 2 | 60 / 75 | **5 / 11** | 15 / 20 |
| Lethariel | 3 | 42 / 50 | **3 / 8** | 15 / 20 |
| Nhal Veyr | 3 | 42 / 52 | **2 / 5** | 15 / 20 |
| Gor Drazhak | 4 | 31 / 39 | **2 / 3** | 15 / 20 |
| Kezamba | 3 | 91 / 97 | **56 / 68** | 65 / 80 |

Dur Brannoc and Kezamba keep a residue because their envelopes cross real
crags and a cenote; both are within a few per mille of their own bare rock.

### What the terrain change moved

Per column, `after - before`, over the ±250 envelope:

* **Highcourt**, seed 8675309: 28753 of 251001 columns moved (11.5 %), every
  one of them UP, by 1 (28613), 2 (130) or 3 (10).
* **Dur Brannoc**, seed 8675309: 82848 of 251001 columns moved (33.0 %), all
  within ±4 — which is `step`, the bound the one-step disc limit gives.

### Plot legality

* **Dur Brannoc**: all nine district plots stay legal on both seeds, and three
  of them got BETTER ground (`forge_smithy` fall 0→2 but rise 8→7,
  `forge_quench_court` 4→3, `forge_copse` rise 12→10).
* **Highcourt**: three of the 36 lots fell one node outside their envelope —
  `northeast/9` and `northwest/8` a perimeter fall of 7 against a skirt of 6,
  `southwest/2` a rise of 7. They were moved with a new
  `tools/wp13/highcourt_plots.lua --repair` mode, which keeps every legal lot
  where it is and moves only the illegal ones to the nearest legal position:

  | lot | from | to | move |
  | --- | --- | --- | --- |
  | northeast 9 | 220, 196 | 216, 196 | 4 |
  | northwest 8 | -176, 168 | -180, 164 | 8 |
  | southwest 2 | -48, -132 | -48, -136 | 4 |

  The other 33 lots are untouched. `--derive`, which re-runs the whole-quadrant
  translation search, would instead have slid the north-east grid 40 nodes and
  rearranged the south-west one — the right answer when a grid is being
  invented and the wrong one when the ground under a finished city has moved by
  a node, which is why `--repair` exists.

* **`r7_settlement.audit_terrain` at load: zero findings**, Highcourt and Dur
  Brannoc, both gate seeds.

## 4. What a review should look at

1. **`fitting_grids.band.value`'s three guards** — the radius table, the
   one-step disc limit and the `shift`. Each of them is there because a
   measurement said so, and each of them is a place where a plausible
   simplification silently ruins a capital. The band KAT
   (`tools/wp13/capital_terrain_fixture.lua`) catches the first and the third;
   the second shows up as a taller `max` column, not as a ceiling breach.
2. **The 128-tile cache is pure memoisation.** If it were not — if a hit could
   return a different number from a miss — every digest in the tree would
   depend on query order. `relief_at` is `classified_values` plus
   `scalar_before_nonpath_grades`, both pure; check that nothing else was added.
3. **`capital_terrace_value`'s seventh argument is optional on purpose**, so the
   frozen scalar cases of `module.quality_geometry_micro_kat` keep calling it
   with six and keep their old answer. Verify that the geometry micro-KAT is
   byte-identical (it is, in the evidence) — that is what proves the band
   changed where the terrace lattice is READ and not how the civic core, the
   32-node civic blend or the cut/fill clamp behave.
4. **The vegetation claim rule.** `shape.start_blend` is now true for capitals
   too. The thing to check is that the capital's 532 hard square really does
   still answer for the `"vegetation"` purpose — if it did not, WP40 would plant
   trees inside a capital's build envelope.
5. **The six starts.** Nothing in this package may touch them, and three
   independent checks say it does not: the six start blueprint identities, the
   start terrain fixture over five seeds, and the WP13 micro pair.

## 5. What is open

* **Vegetation inside the walls.** As above: WP40 keeps the 532 build square
  host-free, so the plateau has race GROUND but no plants. Lethariel's "grove
  with the existing trees left standing" and Highcourt's orchards need the
  WP13 side to plant them, where the plot and avenue footprints are known.
* **`tools/wp40/quality/final_micro.lua` and the R3/R4/R5 artifact lineage.**
  A capital terrain change moves the seed-0 zones canonical KAT, because
  `height.lua`'s own KAT samples (-2049, -1537), which is inside Dur Brannoc's
  704 blend square. See the evidence README for which frozen values moved and
  which were already stale before this lane.
* **Kezamba's cenote.** 56 and 68 per mille unclimbable in the ±128 ring is the
  highest of the six and is mostly the natural terrain, not the terracing
  (before the bands it was 91 and 97). Whether a troll capital on stilts wants
  that ground flattened further is a design question for the Kezamba lane.
* **The band is not free.** A pure height sweep of a step-4 capital costs about
  6× what it did. The engine's per-mapchunk timings are in the evidence and stay
  inside the contract's budget, but a later lane that widens the disc should
  re-measure rather than assume.
