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
`reference + step * quantise(incoming - reference)`. What changed is that the
value handed on is no longer `T(x, z)` but the arithmetic **middle of `T`'s
morphological erosion and dilation** over a Chebyshev disc:

    erosion(x)  = min over the disc of  T(x') + chebyshev(x, x')
    dilation(x) = max over the disc of  T(x') - chebyshev(x, x')
    banded(x)   = round((erosion(x) + dilation(x)) / 2)

A vertical riser of `step` becomes a flight of one-block ground steps. No stair
nodes, no built steps: the ground itself steps, which is the user's ruling.

### Where the band sits: centred

Erosion alone would cut the band out of the **upper** terrace, dilation alone
would fill it onto the **lower** one; either way one plateau loses `step`
columns of flat ground and the other keeps all of its own. The middle is
**centred on the old riser**: both plateaus give up about `step / 2` columns,
the band's mean height is the old riser's, and a plot's reference column
therefore moves by at most half of what a one-sided band would move it.

### THE PROPERTY, and the two claims that were wrong

The first version of this package claimed that "erosion and dilation of any
field are each 1-Lipschitz, so their middle changes by at most one node between
neighbouring columns". **That was not a proof and it was not true.** Two
separate things break it, both found in review, both reproduced here before
being fixed:

1. **The quantiser was not translation invariant.** `deterministic.round_ratio`
   rounds half AWAY FROM ZERO, so for an even divisor the bin it puts around
   zero is one node narrower than every other bin: for step 4 it maps -1, 0 and
   1 to one level while every other level owns four values. A lattice with one
   short bin is not shift invariant, and the band built on it is not
   1-Lipschitz even on perfectly gentle ground. Witness: a plain
   one-node-per-column ramp crossing the reference emits a **two-node** band
   step for step 2 and step 4 (step 3 is spared, because an odd divisor's zero
   bin is already the right width). Widening the disc does not help; only the
   lattice does. Fixed by `terrace_bin` (round half up everywhere) and
   `terrace_middle` (the same rounding for the erosion/dilation midpoint, which
   has the identical defect at a capital below y = 0).
2. **A truncated erosion is not 1-Lipschitz anyway.** The minimiser for one
   column can sit at exactly the rim of its disc and outside the neighbour's,
   so the textbook argument does not survive the truncation the cost budget
   forces. The operator's real bound has to be measured, not asserted.

### The bound that IS proved

Two adjacent band outputs are decided by `2 * radius + 2` columns of relief, so
for `radius = step - 1` **every** relief profile over that window with a bounded
per-column move can be enumerated. That is an exhaustive worst case in one
dimension, not a sample. Worst output step between two adjacent columns, for the
shipped variant (translation-invariant quantiser, one-step disc limit):

| relief moves at most | step 2 | step 3 | step 4 |
| --- | --- | --- | --- |
| 1 node per column | **1** | **1** | **1** |
| 2 nodes per column | 2 | 2 | 3 |
| 5 nodes per column (the steepest a capital envelope carries) | 2 | 3 | 4 |

The first row is the property the playtest is about and it is exact: **where the
whole disc is ground a player could already walk, the band is 1-Lipschitz.**
The same sweep on the OLD quantiser answers 2, 2, 2 in that row — which is the
defect, in one number.

Two dimensions are not covered by a one-dimensional sweep; the real capitals are
the acceptance, and section 3 gives them.

### The one-step limit, re-examined

A neighbour whose terrace is more than one `step` from the centre's is not in
the disc. The review's counterexample is real: relief `140,140,140,140,144,148`
at step 4 gives a 2- and a 3-node step with the limit and a worst of 2 without
it, and the quantiser fix does not change that case. It is kept anyway, because
on every population larger than that one profile it is strictly better:

* exhaustive 1-D, relief up to 5 nodes per column, worst output step where the
  relief step is at most 1: **2 / 3 / 4** with the limit against **5 / 6 / 8**
  without it (steps 2 / 3 / 4);
* the real Dur Brannoc envelope (±200, seed 8675309), unclimbable columns among
  those whose relief is itself walkable: **25 per mille** with the limit,
  **33 per mille** without.

The limit also makes the disc radius almost inert on steep ground — it excludes
whatever a wider disc would have added — which is why raising
`CAPITAL_BAND_RADIUS` to `{2, 3, 5}` and re-dumping the whole Dur Brannoc
envelope produced a **byte-identical** field. `step - 1` is therefore not a
tuning knob that was left too low; it is the point past which the limit decides.

### Cost

The band asks for the pre-grade relief of `(2r+1)^2` columns — 9 for step 2, 49
for step 4 — and all but one of them are asked for again by the neighbouring
column, so `fitting_grids.band` carries a **128 × 128 direct-mapped tile cache**
(16384 entries, slot `(x mod 128, z mod 128)`). The reviewer measured its hit
rate at 98 % and its answers identical over five evaluation orders; it is pure
memoisation of a pure function, so no digest depends on it.

Measured cost, reviewer's figures and this lane's re-measurement after the
quantiser fix:

| measurement | before | after |
| --- | --- | --- |
| Dur Brannoc `capital_steady_mean_us` (engine, three sequential pairs) | — | **+28 %** |
| Dur Brannoc worst single mapchunk | 0.87 s | 1.78 s (1.60× of control, limit 2×) |
| Highcourt engine mean | — | +27 % sequential, +15 % concurrent |
| offline, per column, step 4 (49-point disc) | 10.7 µs | 21.4 µs (2.0×) |
| offline, per column, step 2 (9-point disc) | 9.6 µs | 10.8 µs |
| offline, whole ±250 envelope, Dur Brannoc | 2.4 s | 13.8 s |
| offline, whole ±250 envelope, Highcourt | 2.4 s | 7.0 s |

The quantiser fix is arithmetic only and did not move the cost: `floor_div` on
two multiplications replaces `round_ratio` on one.

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

Unclimbable land columns — a land neighbour more than one node up, which is more
than the jump height — per thousand land columns, both gate seeds.

### The whole ±250 envelope

| capital | seed | before | after |
| --- | --- | --- | --- |
| Highcourt | 8675309 | 113 | **6** |
| Highcourt | 531802985935182545 | 109 | **6** |
| Dur Brannoc | 8675309 | 79 | **27** |
| Dur Brannoc | 531802985935182545 | 76 | **30** |

The worst single 4-neighbour rise at Highcourt is **4** on both seeds, the same
as on main. The first version of this package took it to 5; that was the
quantiser and it is gone.

### The ±128 district ring, all six capitals

`tools/wp13/capital_terrain_fixture.lua`, seed 531802985935182545 / 8675309,
four neighbours per column (the first version measured three — it never looked
at −z, and its ceilings were taken against that):

| capital | step | before | after | ceiling |
| --- | --- | --- | --- | --- |
| Dur Brannoc | 4 | 122 / 114 | **81 / 66** | 90 / 75 |
| Highcourt | 2 | 71 / 83 | **4 / 6** | 10 / 10 |
| Lethariel | 3 | 51 / 58 | **4 / 9** | 10 / 15 |
| Nhal Veyr | 3 | 49 / 58 | **3 / 6** | 10 / 10 |
| Gor Drazhak | 4 | 38 / 44 | **3 / 4** | 10 / 10 |
| Kezamba | 3 | 103 / 108 | **62 / 74** | 70 / 85 |

### What the residue is, and what it is NOT

The first version of this note said the residue was "the ground's own" rock,
and compared it against the ungraded relief of the whole envelope. **That
comparison was wrong**: it is an average over the envelope, and it hides where
the residue actually sits. Measured column by column against the ungraded
relief of the same envelope (±200, Dur Brannoc, seed 8675309), the residual
unclimbable columns sort by the relief's own steepest step there:

| the relief's own step | share of the residue |
| --- | --- |
| 0 | 3.3 % |
| 1 | 56.2 % |
| 2 | 36.7 % |
| 3 | 2.7 % |
| ≥ 4 | 1.1 % |

**59.5 % of it sits on ground a player could have walked before the fitting
touched it.** In that walkable-relief population alone the residue is 25 per
mille. It is not rock; it is the band on MIXED ground — a gentle pair of
columns inside a disc that is not gentle — which is exactly the second row of
the bound table in section 1.

### The lattice phase, and why it is not the tell it looks like

85 % of Dur Brannoc's residual unclimbable columns sit on one height class mod
4, against 17 % of the land. That looks like a quantiser artefact and the review
read it as one, but it survives the quantiser fix unchanged (85.1 % before,
85.1 % after) because it is a consequence of the shape, not of the arithmetic:
the terrace PLATEAUS sit on lattice multiples and are flat by construction, so
every column that can be unclimbable at all is a band column, and the band
columns are the off-lattice classes. The honest tell is the relief attribution
above, not the phase histogram.

What the quantiser fix DID move: Highcourt from 12 to 6 per mille over the
±250 envelope and its worst rise from 5 back to 4; Dur Brannoc's
walkable-relief residue from 26 to 25 per mille. The defect was real and
provable in one dimension, and on the real capitals it is worth a lot at
step 2 and very little at step 4, where mixed ground dominates.

### What the terrain change moved

Per column, `after - before`, over the ±250 envelope, seed 8675309: Highcourt
moved 11.5 % of its columns, every one of them UP by 1 to 3; Dur Brannoc moved
33.0 %, all within ±4, which is `step` — the bound the one-step disc limit
gives.

### Plot legality

* **Dur Brannoc**: all nine district plots stay legal on both seeds; the worst
  perimeter fall over the nine is 6 against a skirt of 6 and the worst rise 11
  against `forge_copse`'s own clear.
* **Highcourt**: **one** of the 36 lots fell outside its envelope —
  `northwest/8`, a perimeter fall of 7 against a skirt of 6 on the boundary
  seed. `tools/wp13/highcourt_plots.lua --repair`, which keeps every legal lot
  and moves only the illegal ones to the nearest legal position, moved it from
  (-176, 168) to (-180, 168), four nodes. The other 35 are untouched.
  (The first version of this package, before the quantiser fix, had to move
  three.) `--derive`, which re-runs the whole-quadrant translation search, would
  instead have slid the north-east grid 40 nodes and rearranged the south-west
  one — the right answer when a grid is being invented and the wrong one when
  the ground under a finished city has moved by a node.

* **For the Highcourt fill lane**: the margins of UNMOVED lots changed too, in
  both directions, and the fill lane builds against them. The full before/after
  table is `measurements/lot-margins.txt`; the ones that got tighter are

  | lot | fall before → after | rise before → after |
  | --- | --- | --- |
  | northeast 2 | 4 → 4 | 2 → 4 |
  | northeast 5 | 2 → 4 | 2 → 1 |
  | northeast 8 | 4 → 2 | 4 → 5 |
  | northwest 1 | 2 → 4 | 4 → 3 |
  | northwest 4 | 2 → 4 | 6 → 4 |
  | southeast 5 | 4 → 5 | 6 → 5 |
  | southeast 8 | 2 → 4 | 6 → 4 |
  | southwest 2 | 2 → 3 | 6 → 6 |
  | southwest 6 | 4 → 5 | 4 → 4 |

  Worst fall over all 36 is **6** against a skirt of 6 and worst rise **6**
  against a clear of 6: both are AT the limit, so a fill-lane change that adds
  a node of foundation or roof to one of those lots has no headroom left.

* **`r7_settlement.audit_terrain` at load: zero findings**, Highcourt and Dur
  Brannoc, both gate seeds.

## 4. What a review should look at

1. **`terrace_bin` and `terrace_middle`, not `round_ratio`.** The band's whole
   1-Lipschitz-on-gentle-ground property rests on the lattice being translation
   invariant. `round_ratio` is the tree's ordinary rounding and reaching for it
   here is the natural mistake; it is what the first version of this package
   did and it cost a node on every step-2 and step-4 capital. Any future change
   inside `fitting_grids.band.value` has to keep both.
2. **`fitting_grids.band.value`'s three guards** — the radius table, the
   one-step disc limit and the `shift`. Each is there because a measurement
   said so, and section 1 gives the measurement for each. Note that the limit
   makes the radius almost inert on steep ground: raising
   `CAPITAL_BAND_RADIUS` and re-dumping Dur Brannoc produced a byte-identical
   field, so a reviewer who expects the radius to be the tuning knob will be
   surprised.
3. **The 128-tile cache is pure memoisation.** If it were not — if a hit could
   return a different number from a miss — every digest in the tree would
   depend on query order. `relief_at` is `classified_values` plus
   `scalar_before_nonpath_grades`, both pure; check that nothing else was added.
4. **`capital_terrace_value`'s seventh argument is optional on purpose**, so the
   frozen scalar cases of `module.quality_geometry_micro_kat` keep calling it
   with six and keep their old answer. The geometry micro-KAT being
   byte-identical is what proves the band changed where the terrace lattice is
   READ and not how the civic core, the 32-node civic blend or the cut/fill
   clamp behave.
5. **The vegetation claim rule.** `shape.anchor_blend` is now true for capitals
   too. The thing to check is that the capital's 532 hard square really does
   still answer for the `"vegetation"` purpose — if it did not, WP40 would plant
   trees inside a capital's build envelope.
6. **The six starts.** Nothing in this package may touch them, and three
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
* **The mixed-ground residue.** 25 per mille of Dur Brannoc's walkable-relief
  columns are still unclimbable, and Kezamba's ±128 ring is 62 and 74 per mille.
  Both are the band on ground that is gentle at the centre and steep around it,
  which the operator cannot fix at this disc size and this cost: a wider disc
  changes nothing while the one-step limit stands, and dropping the limit makes
  it worse. Closing it needs a different operator — a real 1-Lipschitz envelope
  over the whole envelope, computed once per capital and cached — which is a
  package of its own and should be costed against the +28 % this one already
  spends.
* **The band is not free.** Section 1 carries the numbers: +28 % on Dur
  Brannoc's steady per-mapchunk mean, worst single mapchunk 1.60× of control
  against the contract's 2× limit. That is inside the budget with less headroom
  than anyone would like, and a later lane that widens the disc — or replaces
  the operator, as above — has to re-measure rather than assume.
