# Biomes & Mobs — Catalog

**Decided spec** (authored + approved 2026-08-06, incl. the flagged open
points — resolutions in §8; WP6 outcomes folded in 2026-08-07). This is
the implementation spec for
**WP18** (biome/mapgen registrations) and **WP6** (mob rosters & spawn
parameters).

## 0. Decided framework (recap, binding)

- Ring model (world.md §1/§8): settled race biomes in safe core + inner
  ring, wild nature variants outward; flank/back coasts 45–60; **war
  coast stays capped 20–30**; strait beaches 1–5 neutral wildlife.
- Mob level ALWAYS from `grug_core.mob_level_at(pos)` (radial field +
  depth axis, combat_stats.md §3). Biome level bands in this catalog are
  *descriptive* (where the biome sits in the rings), never hand-set per
  mob. Where older drafts said e.g. "bone-forest 40–60", the radial
  field wins (bone forest spans the west outer ring → 25–60).
- Stats derived, never hand-rolled: **HP = 15+5L, dmg = 2+0.4L,
  XP = 10L**; elite armor 80 (×3 HP, ×1.8 dmg, ×4 XP), rare armor 70
  (×5 / ×2.2 / ×6). Speeds: aggressive 4.4, heartland hunters 4.6
  (partly `dogshoot`), critters 3.4. One behavior verb per family;
  elites **and rares** telegraph (2 s wind-up, combat_stats §3); named
  rares broadcast.
- **Player-tag drop rule** (combat_stats §3) applies to every drop
  table below; the tag carries professions → **Leatherworker ×5** on
  every mob flagged `[leather]`.
- Identical base drops cross-continent: universal biomes are literally
  shared; race-flavored mirror biomes share drop tables ("same loot,
  different look" via trees/woods/tints — §3.2 lists the pairs). "Shared
  table" means the **base materials** (meat, the leather tier, the cloth
  tier) are the same item and the same chance on both sides; the **third
  slot is family-flavored** by design (§3.2).
- Nature mobs aggro on sight vs players AND NPCs; density target ~1
  visible mob per 15–20 m of wilderness travel.
- Patch model: race biomes recur as patches across their band; patches
  outside the core have a high chance of a small village, lower chance
  of an outpost. Elves live in tree-integrated settlements.

Stats quick reference (normal tier; compute, don't copy):

| L | HP | Dmg | XP | | L | HP | Dmg | XP |
|---|----|-----|----|---|---|----|-----|----|
| 5 | 40 | 4 | 50 | | 30 | 165 | 14 | 300 |
| 10 | 65 | 6 | 100 | | 45 | 240 | 20 | 450 |
| 20 | 115 | 10 | 200 | | 60 | 315 | 26 | 600 |

## 1. World biome map

### 1.1 Geometry anchors (from grug_core / world.md §1)

Per continent (Kragmar coordinates; Elandor = z mirrored): rectangle
x −1500..1500, z 100..1700; capital ~(0, 900); safe core ≈ x ±645,
z 600..1132 (implemented field, see below); inner ring ≤ ~550 radial
from capital (front side exact); outer ring beyond;
war coast z 100..300. Race bands (fixed compass): west x ≤ −500,
center −700..700, east ≥ 500 — Accord W/C/E = Dwarf/Human/Elf, Throng
W/C/E = Undead/Orc/Troll. These are *narrative* band bounds from the WP2 draft (the fixed compass
layout itself is world.md §7; the `grug_core.REGION_*` constants that
used to spell these four numbers out had no readers and were deleted on
2026-08-08 — the biome cuboids of §1.3 are the single source of the band
geometry). The biome cuboids that
actually generate the ground are §1.3 and no longer line up with them —
the capital carve moved the settled bands' inner edges to |x| ≥ 201, the
wild ones to |x| ≥ 801 and the centre band to |x| ≤ 349.

The radial level field is **z-asymmetric** (WP18): the strait-facing
front uses the wider scale 1000, the back side 775, so the approach to
the capped war coast stays low-level instead of peaking above it —
measured core belt ≈ x ±645, z 600..1132. The guard field is floored
at 60 inside the core (hard step at the core edge — a deliberate
guarded perimeter, not a continuity bug).

**`_grug_spawn_zones` names (WP18 replaced borderland/starter/
midlands):** `strait` (beach z 0..±100), `war_coast` (±100..±300),
`core`, `inner`, `outer`, `coast` (last ~150 nodes before shoreline at
flanks/back), `underground` (y < −40).

### 1.2 Biome list

Continent column: **A** = Elandor (Accord, south), **T** = Kragmar
(Throng, north), *both* = shared.

| # | Biome | Continent | Role | Rings | Eff. levels |
|---|-------|-----------|------|-------|-------------|
| 1 | grug_meadows | A | Human settled | core+inner (+war coast, thin tail to the back coast) | 1–25 (patches out there follow the field, up to 60) |
| 2 | grug_deep_forest | A | universal forest (Human/Elf wild) | outer, center-back + east | 25–60 |
| 3 | grug_pine_hills | A | Dwarf settled | west core+inner | 1–25 |
| 4 | grug_crags | A | Dwarf wild, band-specific | west outer | 25–60 |
| 5 | grug_elf_forest | A | Elf settled | east core+inner | 1–25 |
| 6 | grug_jungle_fringe | A | universal jungle (Accord side) | east flank strip | 38–60 |
| 7 | grug_savanna | T | Orc settled | core+inner (+war coast, thin tail to the back coast) | 1–25 (patches out there follow the field, up to 60) |
| 8 | grug_badlands | T | Orc wild (+ Troll east wing) | center-back outer + east | 25–60 |
| 9 | grug_blight | T | Undead settled | west core+inner | 1–25 |
| 10 | grug_bone_forest | T | universal forest, Throng look | west outer | 25–60 |
| 11 | grug_jungle_edge | T | Troll settled | east core+inner | 1–25 |
| 12 | grug_deep_jungle | T | universal jungle (Throng side) | east outer | 25–60 |
| 12a | grug_badlands_east | T | slab of #8 — the Troll band's second wild | east inner (to \|x\| ≈ 932), outer, back coast, war coast — **not** core | 25–60 |
| 13 | grug_swamp | both | universal, low terrain pockets | outer (y ≤ 6) | 25–45 |
| 14 | grug_beach | both | universal shoreline fringe | everywhere (y 1..4) | by position |
| 15 | grug_ocean | both | sand-bottom ocean | y < 1 | — |
| 16 | grug_underground | both | caves (existing) | y ≤ −256 | depth axis |

The table lists **bands**, not registrations. Three bands ship as several
registrations each, because a cuboid cannot express what they need:

- `grug_crags` has the alpine sibling **`grug_crags_snowy`** (same cuboid
  and climate point, y ≥ 80, snowblock top — §1.3).
- `grug_deep_forest` is the only band whose cuboid needs a **hole in the
  middle** (the capital carve box of §1.3 sits inside it on all four
  sides), so it ships as **`grug_deep_forest`** (back), **`_front`** and
  **`_east`**.
- `grug_badlands` has the east wing **`grug_badlands_east`** (WP36,
  x 801..1250, full z) — the Throng mirror of `grug_deep_forest_east`.
  **This is the 2026-08-08 delta**: the badlands used to be described here
  and in §2 as "band-specific / Orc area only", the same words `grug_crags`
  still carries. It is not band-specific any more, for the same reason
  `grug_deep_forest` never was — a centre-back wild that also covers the
  neighbouring band's wild ring. See §1.3 for the measurement that chose
  it over a `grug_bone_forest_east`.

So the world holds **20 biome registrations**. Every slab of a band
carries the *same* `node_top`, climate point, flora and mob roster as its
parent — the split is pure geometry. That is also the landmine: a
decoration or ore def that names only the parent silently loses the other
slabs (the name it *does* list resolves, so nothing warns), which is why
`grug_mapgen/decorations.lua` keeps one `DEEP_FOREST` and one `BADLANDS`
list and `ores.lua` names all eleven dirt biomes. The reverse bites too:
the centre band was split the same way on 2026-08-08 and collapsed back on
the same day (§1.3, D4), and its `_front`/`_back` names had to leave both
lists again.

War coast is **not** its own biome (decided 2026-08-06): it uses the
local band's settled biome plus a battlefield decoration set (§2,
war-coast row).

### 1.3 Engine registration table (mapgen v7, min_pos/max_pos cuboids)

All values Throng (z positive); the Accord half of a row registers the
same cuboid mirrored (z → −z) under its own name and climate point —
and a pair MAY share a point, because the two continents never overlap.
Overlaps between settled and wild cuboids are deliberately WIDE (101–450
nodes in x, up to 500 in z): inside an overlap the heat/humidity voronoi
decides per position → recurring patches (the patch model, §1.4).
`y_max = 31000`, `y_min = 4` unless noted.

| Biome | x range | z range | y | heat | humidity | node_top |
|-------|---------|---------|---|------|----------|----------|
| grug_savanna / grug_meadows | −349..349 | 100..1700 | ≥4 | 85 / 50 | 35 / 40 | dry_dirt_with_dry_grass / dirt_with_grass |
| grug_badlands / grug_deep_forest* | −700..700 (*A: −900..1250) | 1201..1700 | ≥4 | 75 / 60 | 20 / 75 | grug_nodes:mesa_clay / grug_nodes:dirt_with_forest_litter |
| grug_deep_forest_front (A only) | −900..1250 | 100..599 | ≥4 | 60 | 75 | ” |
| grug_badlands_east / grug_deep_forest_east | 801..1250 | 100..1700 | ≥4 | 75 / 60 | 20 / 75 | grug_nodes:mesa_clay / grug_nodes:dirt_with_forest_litter |
| grug_blight / grug_pine_hills | −1250..−201 | 100..1700 | ≥4 | 25 / 30 | 20 / 60 | grug_nodes:blight_dirt / dirt_with_coniferous_litter |
| grug_bone_forest / grug_crags | −1500..−801 | 100..1700 | ≥4 (crags 4..79) | 15 / 25 | 45 / 35 | grug_nodes:dirt_with_bone_litter / default:gravel |
| grug_crags_snowy (A only) | −1500..−801 | 100..1700 | ≥80 | 25 | 35 | default:snowblock (dust: default:snow) |
| grug_jungle_edge / grug_elf_forest | 201..1250 | 100..1700 | ≥4 | 80 / 70 | 70 / 60 | dirt_with_rainforest_litter / grug_nodes:dirt_with_silver_litter |
| grug_deep_jungle / grug_jungle_fringe | 801..1500 (A: 1150..1500) | 100..1700 | ≥4 | 80 / 85 | 88 / 85 | grug_nodes:dirt_with_canopy_litter / dirt_with_rainforest_litter |
| grug_swamp † | full | −1700..1700 | 1..6 | 60 | 95 | grug_nodes:mud |
| grug_beach † | full | −1700..1700 | 1..4 | 50 | 55 | default:sand |
| grug_ocean † | unlimited | unlimited | −255..3 | 50 | 50 | default:sand |

Land bands start at |z| = **100**, not 160: the war coast (|z| 100..300)
carries real land above y = 4 wherever the coast-noise inset is small,
and a band starting at 160 would leave that strip without ANY biome —
bare stone, no decorations, no spawn surface.

**The carve box (decided 2026-08-08; the guarantee itself is
`world.md` §3).** Everything above that looks asymmetric — the narrow
±349 centre band, the deep-forest hole, the −201/−801 inner edges,
badlands starting at z 1201 — exists so that inside
|x| ≤ 800, 600 ≤ |z| ≤ 1200 **only the band that owns the capital in
that part of the box is eligible at all**. The engine filters the
cuboids on the raw integer position *before* it reads any climate noise
(`BiomeGenOriginal::calcBiomeFromNoise`, `mg_biome.cpp:238-244`), so
containment is a proof, not a probability. Verified: 100 % of a
±200 box around each of the six anchors, over 200 random seeds
(4 034 400 sampled columns, 0 wrong), and 0 land columns anywhere with no
eligible biome.

The two edges that carry the guarantee are one node tighter than they
look, and both numbers are load-bearing:

- the centre band stops at **±349**, one node short of the side
  capitals' boxes (550 − 200 = 350);
- the side settled bands stop at **∓201**, one node short of the centre
  capital's box (0 + 200).

They therefore **overlap by 149 nodes** instead of meeting at a line.
Making them merely contiguous at ±350 would satisfy the guarantee just as
well and would draw a brand-new ruler-straight 1 601-node cuboid face per
side per continent between the capitals — the one place every player
walks. Measured, the 149-node overlap is worth ~4 700 nodes of extra
*organic* (wandering) border and ~150 fewer straight ones. 149 is the
widest the guarantee allows; only a smaller `CAPITAL_R` could buy more.

**Climate points moved 2026-08-08** (`grug_badlands` 95/15 → **75/20**,
`grug_crags`/`grug_crags_snowy` 10/30 → **25/35**). Over the land
columns the climate field's mean is a **per-seed draw**: measured over 30
seeds it is ~50 / 51 with a per-seed spread of ±8.8 and a range of 26..67,
while the within-seed σ is ~16 / 15. (An earlier revision quoted
"mean 60.9 / 48.8" as a property of the field — that was one seed's value,
and every "N units from the field mean" argument derived from it is
therefore seed-local, not robust. Two continents of the same seed can differ
by 10 units on average and 27 at worst.) So
both old points sat 2–3.5 σ out: they never won inside their overlaps
and the border collapsed onto a cuboid face as a straight line (the
crags ↔ pine hills face at x = −1250 was the single worst line in the
world, 1 132 nodes). The new points sit 32 and 38.5 climate units from
the mean and split their overlaps roughly evenly. **Floor: 18.0 units
of separation between any two points that share a cuboid** — the
distance of the tightest pre-existing pair (elf forest 70/60 ↔ deep
forest 60/75); badlands sits exactly at it against savanna 85/35.
`grug_bone_forest` 15/45 and `grug_blight` 25/20 were deliberately left
alone: they are ~46 units from the mean *both*, i.e. the one pair that
already contests its overlap symmetrically.

**Climate BLEND noise** (`mg_biome_np_heat_blend` /
`mg_biome_np_humidity_blend`, set in `grug_mapgen/init.lua`): offset 0,
**scale 4, spread 32**, octaves 2, persist 1.0, lacunarity 2.0, engine
seeds 13 / 90003. The engine adds these on top of the heat/humidity
fields and they are the only knob that softens a *voronoi* border; they
cannot touch a cuboid face, which is tested before the climate is read.
The engine defaults (1.5 / 8) were a per-node dither; 4 / 32 gives
~45-node fingering in ~32-node lobes. **Hard ceiling scale 6** — above
that the displacement exceeds half the 18.0-unit point floor and
borders salt-and-pepper. All four climate noises are computed for every
mapchunk anyway, so this costs nothing at runtime. **Needs a fresh
world** (`override_meta` rewrites `map_meta.txt`).

**`grug_jungle_fringe` fixed 2026-08-08 (was 0.08 % of the land).** All
three deep-forest registrations used to reach x 1500 and thereby contained
the fringe cuboid whole; 60/75 sits 12 climate units from the field mean
against the fringe's 43, so the Accord east flank generated as deep
forest — no **crimson lotus T3** source on the Accord side at all (§2/§6)
and Silkfang (§3.3) patrolling outside its named habitat. No climate point
that is still a rainforest can beat 60/75, so the fix is geometric: the
deep forest is now capped at **x 1250**, the outer edge the settled bands
already had, which hands the **east flank strip x 1251..1500** to the
fringe *uncontested* — exactly mirroring `grug_deep_jungle` on the Throng
side. `x_min` stays at 1150, so x 1150..1250 remains a contested
101-node overlap and the inner border stays a mosaic. Measured over 8
seeds: fringe **0.08 % → 2.71 %** of the land (deep jungle, its mirror:
3.13 %), deep forest 9.9 % → 8.1 %, **T3 lotus supply 3.21 % → 5.84 %**
(§6). Silkfang's three route points went from 0 of 50 seeds in the fringe
to a containment guarantee (exactly one eligible registration). The cap
costs 393 nodes of straight border. **Accord-only** — `grug_deep_forest`
has no Throng mirror; the Throng centre-back wild is `grug_badlands`.

**The Throng biome monopoly, fixed 2026-08-08 (WP36).** `grug_jungle_edge`
(x 201..1250) and `grug_deep_jungle` (x 801..1500) both shipped
`default:dirt_with_rainforest_litter`, and outside |z| 1201..1700 nothing
else reached x 350..1500 at all. Measured with `tools/biomecheck`:
**41.1 % of Throng land had exactly ONE eligible `node_top`**, against
29.5 % on the Accord side, whose mirror position carries
`grug_deep_forest_east` with a different top. The share table hides this —
folded onto the visible top, the two registrations look like one biome.
Three changes, all of them on the Throng side:

1. **`grug_deep_jungle` got its own top**,
   `grug_nodes:dirt_with_canopy_litter` (the shaded floor under the closed
   canopy; retint recipe and licence row in `grug_nodes/LICENSE-media.md`).
   **`grug_jungle_fringe` keeps `default:dirt_with_rainforest_litter`** —
   that is what ships and what every number in this section was measured
   against. Which of the two Troll jungle biomes §8.4's "the fringe reuses
   the troll jungle nodes 1:1" binds the fringe to is **not settled by this
   document**: see **[TODO-design-jungle-fringe.md](../../TODO-design-jungle-fringe.md)**.
   Either way both continents end up with three distinct eastern tops, and
   deep jungle / fringe — until WP36 the only mirrored pair in the world
   whose halves shared a look — no longer share one.
2. **`grug_badlands_east`** fills the empty Throng half of the
   `grug_deep_forest_east` row: the centre-back wild reaching into the
   neighbouring band's wild ring, which is what the Accord has shipped
   since the carve. The alternative reading — a `grug_bone_forest_east`,
   since §3.2 pairs the deep forest with the bone forest — was **measured
   and rejected**: a slab must carry its parent's climate point, and
   15/45 is so much closer to the field mean than `grug_jungle_edge`'s
   80/70 that over 12 seeds it takes **62.4 %** of the x 801..1250 strip
   and pushes the jungle edge to 29.3 %, i.e. it would flip the whole
   Troll east into a grey dead forest. `grug_badlands`' 75/20 measures
   35.6 % against the jungle edge's 52.5 % — within a point of the Accord
   mirror (deep-forest slabs 36.1 %, elf forest 54.3 %).
3. **`grug_deep_jungle` 90/90 → 80/88.** 90/90 was +1.8 / +2.2 σ out and
   over 12 seeds only **0.1 %** of the biome's own land sat inside
   x ≤ 1250 — i.e. it was its uncontested flank strip and nothing else
   (it took **0.0 %** of the contested strip against the jungle edge).
   With 80/88 that rises to **6.9 %** / 2.7 %, and the biome's total land
   share from **5.30 % to 5.84 %**. 80/88 keeps exactly
   **18.0** units from `grug_jungle_edge` (80/70), the floor above; 21.2
   from `grug_swamp` (60/95, shares y 4..6), 44.6 from `grug_beach`
   (50/55, shares y = 4) and 68.2 from `grug_badlands_east` (75/20). The
   border against the jungle edge is therefore the single line
   humidity = 79, which the blend noise (≤ 8 units of displacement per
   axis, under half the floor) frays into a mosaic.

Every "12 seeds" figure in this section and in §1.4 was **re-measured
2026-08-08** over one set — this world's seed plus the first eleven of the
deterministic list in `tools/biomecheck/crossseed.py`, Throng land, step 20 —
because three different post-values for the deep jungle had been written into
three places. The set above is the one that holds;
`grug_mapgen/biomes.lua` carries the same numbers.

Result, this world's seed (`tools/biomecheck`, step 10): eligible-visual
monopoly **60.9 % → 42.8 %** of Throng land, rainforest-litter-only
**41.1 % → 18.8 %**, columns with three eligible visuals 4.3 % → 22.3 %.
Over **30 seeds** the Throng's largest single visible top falls from a mean
of **35.0 % to 27.4 %** (max 49.3 % → 42.8 % — a *different* 42.8 from the
monopoly figure, and a coincidence), i.e. below the Accord's 29.7 %, and the
node that dominates most often changes from rainforest litter in 24 of 30
seeds to 14 of 30 spread over five different tops.

**Where the residual 42.8 pp sits** (re-measured 2026-08-08 with
`tools/biomecheck`, this world's seed, step 10, land columns with exactly one
eligible visual). The five groups are disjoint and sum to the 42.83 pp:

| the one visual those columns have | where they are | pp of Throng land |
|---|---|---|
| `default:dirt_with_rainforest_litter` — `grug_jungle_edge` alone | x 201..800 | **18.77** |
| `default:dry_dirt_with_dry_grass` — `grug_savanna` alone | x −200..200 | 8.90 |
| `grug_nodes:dirt_with_bone_litter` — `grug_bone_forest` alone | x ≤ −801 | 5.94 |
| `grug_nodes:blight_dirt` — `grug_blight` alone | x −800..−201 | 4.95 |
| `grug_nodes:dirt_with_canopy_litter` — `grug_deep_jungle` alone | x ≥ 801 | 4.27 |

So **the largest single block of the residual is in the east after all**:
x 201..800 is the Troll settled band's own strip, which only
`grug_jungle_edge` reaches, and its 18.77 pp is numerically the same figure
as the "rainforest-litter-only 18.8 %" above — they are the same columns.
(An earlier revision of this paragraph named x −800..−351 and x −200..200 as
the residual; those two are 13.75 pp together, a third of it.)

What the table actually shows is **one defect repeated once per band, not an
east/west asymmetry**: wherever a band's settled cuboid, its wild partner and
the flank strip do not all overlap, the leftover strip has a single eligible
registration. Closing it is a geometry question — a further registration
whose cuboid covers x 201..800, and the mirrored gaps in the centre and the
west, where the Throng still has no equivalent of `grug_deep_forest_front`
or of the deep forest's x −900..1250 back slab (`grug_badlands` is only
x −700..700, z 1201..1700). **Still open**, deliberately not fixed in WP36.

† The three universal biomes are registered **once**, not as a mirrored
pair — a biome name may exist only once in the engine. Swamp and beach
therefore use a z-symmetric cuboid, and `grug_ocean` is x/z-**unlimited**:
the strait, the coastal ocean and the open sea all lie outside every land
cuboid, and without an unlimited ocean they would have no biome at all
(no seabed filler, no dungeon nodes, no cave liquid).

Notes:
- grug_deep_forest (Accord) is the wide back-country/elf-band forest —
  its point loses to the settled points in core/inner and wins
  uncontested beyond → settled inner, patchy middle, wild outer, no hard
  seams. Since the carve it is three registrations with the capital belt
  cut out of the middle; a single cuboid cannot express a hole. Its
  x_max is 1250, not 1500 — see the jungle-fringe note above.
- The outermost points need the climate noise to actually reach them. As
  of WP36 they are `grug_jungle_fringe` **85/85**, `grug_deep_jungle`
  **80/88**, `grug_swamp` **60/95** and `grug_bone_forest` **15/45**; the
  three that used to be quoted here are retired — 95/15 and 10/30 with D2,
  90/90 with WP36's deep-jungle move (all three lost every contested
  column, see above). WP18 sets `mg_biome_np_heat`/`np_humidity` to
  offset 50 / scale 35 (engine defaults otherwise; the `eased` flag is
  spelled out for readability — a Lua noiseparams table without `flags`
  gets `NOISE_FLAG_DEFAULTS`, which 2D noise already treats as eased,
  so only 3D noise really needs it), so all points are reachable.
  Verify in a test world before tuning shares.
- **Straight borders are a property of the cuboids, not of the points**
  (measured 2026-08-08). Moving a point only decides *which* cuboid
  face the border collapses onto — the total barely moves, because the
  climate field (spread 1000) is nearly constant across a 450-node
  overlap. What point tuning does buy is a flatter distribution: the
  world's worst single line went 1 665 → 1 551 nodes and the western
  band stopped being one 1 400-node ruler.
- **D4: the centre-band front/back slabs — tried, measured, ROLLED BACK
  (both on 2026-08-08). Do not re-propose them.** The carve only needs
  the centre band to be narrow *inside* the box, so the band first
  shipped as three slabs: a ±349 belt slab for |z| 600..1200 plus a
  `_front` (|z| 100..599) and a `_back` (|z| 1201..1500) slab that kept
  the band's original ±700 and therefore a 499-node centre↔side overlap
  outside the box. It bought those wider mosaics with four brand-new
  ruler-straight cuboid faces at |z| = 599 and |z| = 1200, straight
  across the middle of both continents. Measured over 5 seeds at y 20,
  everything else held equal, the slabs cost **1 500 nodes of straight
  ground border (13 834 → 12 334) plus 1 592 nodes of deco-only border**
  — about three quarters of the whole regression the carve had
  introduced, against a complaint ("boring straight lines") that was the
  reason for the rework. The band is **one cuboid** again, x ±349,
  z 100..1700, and the centre↔side overlap is 149 nodes everywhere.
  Registration count 23 → **19** (→ **20** with WP36's
  `grug_badlands_east`, see the monopoly note above).
- **z_max 1700, not 1500** (same pass). The pre-rework centre band
  stopped at |z| 1500, which left the back-country band the strip
  |z| 1501..1700 uncontested and made the face at z = 1501 a 733-node
  straight line. Running the band to Z_MAX lets it contest the whole back
  country against badlands / deep forest — which is what the patch model
  of §1.4 asks for anyway — and removes **910 straight nodes**
  (12 334 → 11 424). It costs the badlands nothing measurable: 0.81 % of
  the land before the rework, 1.95 % now.
- **Where the straight-border total ended up** (5 seeds, y 20, ground
  nodes, both continents): pre-rework **11 343** → carve with the D4
  slabs **13 441** → carve without them **11 424**, i.e. +81 over the
  pre-rework world for a capital guarantee that used to be a coin flip.
  393 of those 11 424 are the jungle-fringe fix above, so the carve
  itself is now border-neutral. 21.4 % of all ground-node border on the
  land surface sits on a cuboid face; the other 41 418 nodes wander.
- The single shared `grug_ocean` above replaces the per-biome
  sand-bottom `_ocean` siblings of the WP2 mapgen (decided with WP18 —
  one ocean is simpler and the only way to cover the open sea).
- **Reef band — decided 2026-08-07, not yet catalogued**: the coastal
  sea around the continents *and* around every housing isle
  (world.md §2b: 1500 / 150 nodes) becomes a real biome with coral,
  kelp, fish and harmless-to-low-level shore wildlife, distinct from the
  bare `grug_ocean` sand bottom that carries the strait and the open
  sea. It is the counterpart to the deep sea's lethality: pretty and
  inhabited near land, deadly away from it. The registration, the flora
  and the mob rows are open work for the ocean-content WP — including
  whether Shore Crab and Reef Lurker (§8.3, deferred for want of a
  licensed model) come back with it.
- **Where the beaches really are**: the ocean mask carves the coastline
  0..150 nodes INSIDE the rectangle, so the strait-facing shoreline sits
  at |z| ≈ 100..250 — i.e. inside the **war_coast** zone (|z| ≤ 300),
  not in `strait`. The `strait` zone is open water plus the last nodes
  of beach; the flank/back beaches fall into `coast`. Shoreline wildlife
  must therefore list `war_coast` among its zones (§4).
- **Landmine reminder** (AGENTS.md): never register ores/decos against
  biome names that might not resolve.
- New signature top nodes (all cheap retints of MTG textures,
  CC BY-SA 3.0, in a new `grug_nodes` mod): `blight_dirt` (grey-violet
  dirt), `dirt_with_bone_litter` (ash-grey litter), `dirt_with_forest_
  litter` (dark green), `dirt_with_silver_litter` (pale), `mesa_clay`
  (red-orange), `mud` (swamp, slows walking slightly via groups) and
  `dirt_with_canopy_litter` (deep shade emerald, WP36 — the deep jungle
  floor). These exist FOR the LotT spawn-whitelist trick — precise
  per-biome spawn gating with zero runtime cost (§4). **A new one is a new
  set of `biome × zone` spawn cells** — see the §1.5 warning before adding
  the next.

### 1.4 Patch model & settlements

- **Patches**: the wide cuboid overlaps (§1.3) make each band a voronoi
  mosaic: settled patches deep in the wild zone and wild patches near
  the core, pure only at the extremes. No extra noise machinery needed
  — this is exactly how the current biomes.lua overlap works, widened.
  **Exception since the carve**: inside the ±200 box around a capital
  there is no mosaic at all, by construction (§1.3, `world.md` §3).
- **Land shares after the carve** (mean over 8 seeds, both continents,
  slabs folded back onto their band). The carve moves the settled/wild
  balance of §1.4 noticeably in favour of the *side* settled bands,
  which is what the civilization gradient of `world.md` §1 asks for:

  Land shares over 8 seeds, all three columns at blend 4/32 so only the
  geometry differs. "carve" is the 23-registration version with the D4
  slabs, "now" the shipped 19 (§1.3):

  | band | pre | carve | now | | band | pre | carve | now |
  |---|---|---|---|---|---|---|---|
  | savanna | 19.8 % | 10.7 % | 8.8 % | | blight | 6.0 % | 10.5 % | 11.4 % |
  | meadows | 15.1 % | 12.0 % | 8.9 % | | pine hills | 7.2 % | 10.1 % | 10.7 % |
  | deep forest | 15.4 % | 9.9 % | 8.1 % | | elf forest | 8.5 % | 12.1 % | 13.7 % |
  | bone forest | 8.1 % | 7.4 % | 7.4 % | | jungle edge | 12.0 % | 16.4 % | 17.1 % |
  | crags | 4.0 % | 6.1 % | 6.1 % | | deep jungle | 3.1 % | 3.1 % | 3.1 % |
  | badlands | 0.8 % | 1.7 % | 2.0 % | | jungle fringe | 0.08 % | 0.08 % | 2.71 % |

  Effect on the §2 gathering split (a herb is bound to its biomes):

  | tier (source biomes) | pre | carve | now |
  |---|---|---|---|
  | healing **T1** gravemoss (pine hills, blight) | 13.2 % | 20.6 % | 22.1 % |
  | healing **T2** dragonweed (crags, badlands, deep forest, bone forest) | 28.3 % | 25.0 % | 23.5 % |
  | healing **T3** crimson lotus (deep jungle, jungle fringe) | 3.2 % | 3.2 % | 5.8 % |
  | spice **T1** sunleaf (meadows, savanna, elf forest, jungle edge) | 55.3 % | 51.2 % | 48.5 % |

  **Not yet folded into that table: WP36 (2026-08-08).** It changes the
  Throng east only (12 seeds, both changes together): `grug_jungle_edge`
  29.98 % → **23.69 %** of the Throng land and 90.4 % → **52.5 %** of the
  x 801..1250 strip, `grug_badlands_east` **5.87 %** of the land and
  **35.6 %** of that strip, `grug_deep_jungle` 5.30 % → **5.84 %**.
  Effect on §2 gathering:
  the Throng's dragonweed **T2** supply grows with the badlands wing, the
  crimson-lotus **T3** supply grows slightly with the deep jungle, the
  sunleaf **T1** supply shrinks with the jungle edge. Nothing changes on
  the Accord side. Re-measure the whole table on the next mapgen pass
  rather than patching single cells.

  T1 healing is the one tier that moves by more than a third, and it is
  the *carve* that moves it (+75 % with the old climate points; the D2
  point moves pull it back to +57 %, the D4 rollback to +67 %). T3
  healing nearly doubles because the fringe fix finally gives the Accord
  side a lotus source of its own — before, the whole 3.2 % was Throng
  deep jungle. Nothing gets rarer by more than 17 %.
- **Settlement pass** (WP13 structure pass, deterministic from world
  seed): candidate points on a jittered grid (~300 ± 100 m) across each
  band. At each candidate, read the biome:
  - settled race biome patch, outside the safe core → roll **60% small
    village** (4–8 NPCs: trader, quest board, 1–2 guards matching
    `guard_level_at`), else **25% military outpost**, else nothing.
  - wild/nature biome → 10% outpost, 5% humanoid camp (§3, bandit /
    mirefolk camps), else nothing.
  - Min spacing 250 m between any two settlements; cap +3 villages and
    +3 outposts per band beyond the guaranteed POI budget of world.md
    §9 (which stays the deterministic minimum: 1 race village in core,
    1 flavor camp inner, 1 outpost per ring, 1 apex lair outer).
- **Elven treehouses**: the elf village/settlement schematics are
  tree-integrated — each is a single .mts containing a **great
  silverwood** (custom giant tree, trunk 2×2, height 14–18) with a
  platform at 8–10 m, hut, ladder/rope down, lanterns. Ground level
  gets only fences/lamps. Placement needs a flat-ish 12×12 pad (reuse
  the WP-platform median-height logic). Same schematics serve core
  village and patch villages (patch = 1–2 trees, core village = 4–5).
- Guards/NPCs in patch settlements level with the local field
  (`guard_level_at`) — an outer-ring patch village is a level-40
  settlement by itself.

### 1.5 Level-continuity check (no holes, no >5 jumps)

Walking from the village belt (core, L1–10) in any direction:

| Walk | Sequence | Check |
|------|----------|-------|
| Dwarf/Undead village → flank coast (west) | core 1–10 → inner pine-hills/blight 10–25 (x −500..−850) → crags/bone-forest 25–45 (−850..−1400) → coast 45–60 | continuous |
| Human/Orc village → back coast | core 1–10 → inner meadows/savanna 10–25 → deep-forest/badlands 25–45 (z 1250..1550) → coast 45–60 | continuous |
| Elf/Troll village → flank coast (east) | core 1–10 → inner elf-forest/jungle-edge 10–25 → deep-forest+fringe/deep-jungle 25–45 → jungle coast 45–60 | continuous |
| any village → strait | core 1–10 (z 900..600) → inner 10–25 (z 600..350) → war coast 28–30→20, falling toward the strait (cap ramp 600..100) → strait beach 1–5 neutral | continuous down to z 100; the strait step is a DESIGNED break (neutral wildlife, not a difficulty ramp) |
| lateral (band to band) | same radial field on both sides of a band border | no jump by construction |
| swamp pockets | low terrain inside outer ring → 25–45 by position | inside band |
| depth | caves 3 levels per 50 nodes below y=0 | combat_stats §3 |

**Dead zones — what is actually guaranteed.** This section used to
claim "every ring×band cell has registered spawns (§4) — no dead
zones". That was FALSE and stayed false through WP6: the claim was
never derived, and a level walk is not a spawn check. The real gate is
`biome top node × _grug_spawn_zones`, and because §4 assigned node
whitelists by biome ROLE while the zones gate by RING, every biome
patch that landed in the "wrong" ring (§1.4 makes those the rule, not
the exception) was a cell with no eligible mob at all — 37 of them,
found by re-deriving the matrix after a runtime report of a wildlife-
free `grug_deep_forest` patch on the human capital.

What is guaranteed now, and how:

- The guarantee is **mob-side node coverage**, not biome placement.
  Nothing constrains where a patch may appear; instead §4's filler
  slots (see the "role is not ring" note there) give the core/inner,
  outer/coast and war-coast rosters the tops of the *other* role, so
  every `biome × zone` cell a patch can reach has at least one row.
- Verified by deriving the full matrix from the shipped rows against
  `grug_core.zone_at` and the `min_pos`/`max_pos` cuboids of §1.3 —
  **every land cell now has day AND night spawns**, at unchanged
  density peaks (16 day / 12 night, wp6_spawn_budget.md §2).
- Two deliberate exceptions, both pre-existing and both day-only by
  design: **`grug_beach`** outside the war coast (the Gull is the
  entire beach roster since Shore Crab and Reef Lurker were deferred,
  §8.3) and **`grug_swamp` × coast** (Crocodile and Bog Ooze are
  `outer`-zoned per §4). Neither is empty — they have no *night* row.
- This guarantee has to be re-derived whenever a biome is registered
  or a `nodes`/zone list changes. `grug_crags_snowy` is the warning:
  it was added in WP18 and no spawn row ever listed
  `default:snowblock`, so an entire biome was mob-free until this fix.
- **The one test that decides whether a new registration costs mob work**:
  the gate is `node_top × zone`, so a registration is free **iff every zone
  its cuboid reaches already has rows for the top it carries**. Two things
  can break that, and they are independent: a **new top** (a whole new
  column of cells, all empty), and a cuboid that **reaches a zone the top
  has never reached before**. Sharing the parent's top only settles the
  first. The biome names in `grug_mobs/*.lua` are comments only — the spawn
  rows gate on `nodes`, never on a biome name.
- The carve siblings of §1.3 (`grug_deep_forest_front` / `_east` today; the
  six of them at the time of the carve, before D4 took the centre-band slabs
  back out) passed that test
  without any check being needed, and for a reason that is specific to a
  *carve*: cutting a hole into a band can only ever make it reach **fewer**
  places, never more, so no new cell can appear. **Do not reuse that
  shortcut for a registration that is not a carve piece.**
- `grug_badlands_east` (WP36) is exactly such a case and **the shortcut
  would have been wrong on it**: it is a new cuboid, not a slice of the
  parent's, and it extends the band's reach in z — `grug_badlands` is
  z 1201..1700 (zones coast/inner/outer), the wing is z 100..1700 and
  therefore **adds `war_coast`** (plus the formal |z| = 100 strait plane,
  the artifact of `wp6_spawn_budget.md` §2.2's footnote). So the new cell
  had to be derived rather than assumed. It came out **live at 2 day /
  7 night** — Carrion Crow by day, Skeleton Raider + Zombie by night —
  because §4's war-coast filler slot hands both war-coast-exclusive
  families *every* land top, `grug_nodes:mesa_clay` included. Nothing had
  to be added; but `mesa_clay × war_coast` had been printed as
  geometrically impossible in `wp6_spawn_budget.md` §2.2 and is corrected
  there.
- `grug_nodes:dirt_with_canopy_litter` (WP36) is the other failure mode:
  a **new top** is a brand-new column of `biome × zone` cells with
  no rows in it at all, exactly like `default:snowblock` in WP18. The
  cuboid x 801..1500 never reaches zone `core` (the radial field puts
  |x| ≥ 801 at n ≥ 0.44), so four cells had to be filled —
  `inner`/`outer`/`coast`/`war_coast`, day and night:

  | cell | day rows (Σaoc) | night rows (Σaoc) |
  |---|---|---|
  | canopy × inner | Jungle Boar, Jungle Lynx (10) | Zombie settled row (4) |
  | canopy × outer | Jungle Ape, Jungle Lynx, Serpent (11) | Jungle Spider, Panther (8) |
  | canopy × coast | Jungle Ape, Serpent (6) | Jungle Spider, Panther (8) |
  | canopy × war_coast | Carrion Crow (2) | Skeleton Raider, Zombie (7) |

  The deep jungle deliberately gets **no critter** (the Hare's list was
  left alone) — same rule as the badlands, §3.1. The full matrix was
  re-derived from the shipped rows against `grug_core.zone_at` and the
  §1.3 cuboids: **every land cell still has day AND night spawns**, the
  density peaks are unchanged at **16 day / 12 night**, and the only
  day-only cells are the three documented exceptions (`grug_beach` ×
  outer and × coast, `grug_swamp` × coast).
- **Two dead cells found by that re-derivation and repaired in the same
  round** — not caused by WP36, caused by the **D4 rollback**. Before
  2026-08-08 the centre band stopped at |z| 1500 and could not reach the
  back-coast band (|z| ≥ 1550); extending it to Z_MAX created
  `grug_meadows × coast` and `grug_savanna × coast`, which had **no mob
  at all, day or night**. §4's outer/coast filler slot says Bear + Giant
  Spider (A) / Plaguehide Bear + Pale Spider (T) carry "the settled tops
  of their side", and `default:dirt_with_grass` /
  `default:dry_dirt_with_dry_grass` were simply missing from those four
  lists. Added. The jungle edge's rainforest litter is deliberately *not*
  added to the Throng pair, and the reason is **continent leakage, not the
  budget**: `default:dirt_with_rainforest_litter` is the only band top that
  exists on *both* continents (`grug_jungle_edge` on the Throng,
  `grug_jungle_fringe` on the Accord, §1.3), and neither Plaguehide Bear nor
  Pale Spider carries a `_grug_spawn_check`, so listing it would put two
  Throng-tinted families into Elandor's jungle fringe. (An earlier revision
  gave the budget as the reason — "Σaoc 15 at night, past the peak of 12".
  That arithmetic was wrong: `rainforest litter × outer` and `× coast` are
  Panther 4 + Jungle Spider 4 = **8** at night, so the Pale Spider's 4 would
  reach **12**, which *ties* the peak instead of passing it. The decision
  stands on the leakage argument alone.)
- **The critter round (§3.0) re-derived the same matrix a third time**, and
  it is the easy case of the test above: four new entity names, **no new top
  node and no new cuboid**, so not one `biome × zone` column or cell was
  created — every row lands on a top that already had rows (`grug_nodes:mud`,
  `grug_nodes:dirt_with_bone_litter`, `grug_nodes:blight_dirt`, and the cave
  rock `default:stone` + `group:grug_stratum`). The guarantee therefore
  cannot break by construction: this round only ever ADDS a name to a live
  cell. Re-derived anyway, because that is the rule: **every land cell still
  has day AND night spawns**, the day peak is unchanged at **16** (the
  highest cell this round touches is blight core/inner at 14) and the night
  peak is unchanged at **12** — the underground cell was taken to exactly 12
  and deliberately not past it, which is why the second cave critter ships at
  `aoc` 1 (§4's row note; full arithmetic in `wp6_spawn_budget.md` §2.5).
  The only day-only cells remain the three documented exceptions
  (`grug_beach` × outer and × coast, `grug_swamp` × coast) — a *day* critter
  cannot fill a night column, and the swamp's Bog Fowl does not try to.

## 2. Per-biome specs (surface, flora, gathering)

Gathering split (professions.md §2), **revised 2026-08-07 — the herbs
split in two**:

| Marker | Who may gather it | Farmable later |
|---|---|---|
| `[food]` | everyone | yes — becomes a crop with the farming package |
| `[food found-only]` | everyone | **never** — found in the world, never grown |
| `[herb Tn]` | **healing herb** — Alchemist only, tier n | **never** |
| `[spice Tn]` | **spice**, tier n — everyone gathers it, *used* by the Alchemist **and** by Cooking | yes |

Both plant lines keep the same ring tiers: T1 inner (10–25), T2 outer
(25–45), T3 coast/deep (45–60), and each line has exactly one plant per
tier, reachable on both continents.

**Where the line runs**: healing herbs grow on ground no plough will
ever touch — bare stone, gravel and mesa clay, dead wood, the deep
jungle floor — while spices grow on the soft, workable ground of
meadow, marsh and shore. The split is readable off the biome itself, it
keeps every healing herb bound to a journey into its own biome, and it
gives Cooking a supply line that farming can later take over without
ever touching alchemy's.

**Where farming happens** (decided 2026-08-08): on a player's **own
housing isle** (`world.md` §5.7) — protected ground, so a crop is safe
from another player's spade — and **only cooking ingredients grow
there**: the `[food]` and `[spice Tn]` lines of this section, never a
`[herb Tn]` and never a `[food found-only]`. The "Farmable later" column
above is therefore also the isle's permitted plant set.

**MVP scope**: only the plants listed below spawn — a handful of cooking
ingredients plus the six herbs. More herbs, more cooking recipes and the
farming system are one later package.

| Biome | Trees / schematics | Ground cover & gathering | Notes |
|-------|--------------------|--------------------------|-------|
| grug_meadows | apple_tree.mts sparse (fill 0.0015), bush | grass 1–5, flowers; wild potato + corn patches `[food]`, apples `[food]`; sunleaf `[spice T1]` | fields/roads near settlements (WP13) |
| grug_pine_hills | pine_tree.mts + small_pine (fill 0.006) | ferns; wild berries (blueberry bush) `[food]`; gravemoss on stone `[herb T1]` | scattered boulders (deco) |
| grug_elf_forest | silverwood (retinted aspen_tree.mts) + apple mix (fill 0.007) | pale grass, white flowers; wild berries `[food]`; sunleaf `[spice T1]` | great-silverwood only via settlement schematics |
| grug_deep_forest | apple + aspen dense (fill 0.02), fallen logs (apple_log.mts) | ferns, mushrooms `[food found-only]`; dragonweed edge `[herb T2]` | dark, high tree density |
| grug_crags | snowy_pine above y 60, else bare | gravel/stone tops, snow above y 80; dragonweed `[herb T2]`, frost lichen deco | band-specific nature biome (Dwarf area only) |
| grug_savanna | acacia_tree.mts sparse (0.002), dry shrubs | dry grass 1–5; wild corn patches `[food]`; sunleaf `[spice T1]` | waterhole ponds (deco) |
| grug_badlands (+ `_east`) | large_cactus, dead shrub | mesa clay banding (stratum deco optional); dragonweed `[herb T2]` | Orc back country **plus the Troll east wing** since WP36 (§1.3) — the mirror of the deep forest's east wing, not a band-specific biome any more |
| grug_blight | gravewood (custom dead tree, no leaves) sparse | grey grass tufts, bone piles (deco); gravemoss `[herb T1]` | fireflies/wisp particles optional |
| grug_bone_forest | gravewood dense (fill 0.015), bone piles | mushrooms `[food found-only]`; dragonweed `[herb T2]` | shares deep-forest drop tables (§3.2) |
| grug_jungle_edge | jungle_tree.mts (0.008) | jungle grass; wild bananas? → wild melon `[food]` (BASE-compatible); sunleaf `[spice T1]` | |
| grug_deep_jungle / grug_jungle_fringe | jungle + emergent_jungle (0.025); papyrus lives in the adjacent swamp/shore band (v7 has no water above sea level, so the jungle cuboids at y ≥ 4 cannot host waterside papyrus) | vines/lianas (asset list); crimson lotus `[herb T3]`; wild cocoa `[food found-only]`; wild melon `[food]` | same flora and roster on both sides, but **not the same ground node since WP36**: the deep jungle stands on `grug_nodes:dirt_with_canopy_litter`, the fringe still on `default:dirt_with_rainforest_litter` (which of the two the fringe *should* reuse under §8.4 is open — [TODO-design-jungle-fringe.md](../../TODO-design-jungle-fringe.md)). Every deco of this row therefore names **both** nodes in `place_on` — a `place_on` is as silent as a `biomes` list |
| grug_swamp | papyrus_on_dirt, dead bush; willow-ish gravewood retint optional | reeds, waterlilies; marshbloom `[spice T2]`; mushrooms `[food found-only]` | shallow water pools (mud floor) |
| grug_beach | — | shells (deco); stormkelp on coast-zone beaches only `[spice T3]`; rock salt crust on coast-zone beaches `[food found-only]` | |
| war-coast overlay | local band biome | battlefield decos: broken carts, bone piles, burnt patches (schematic decos) | no separate biome (decided); decoration set ships with WP13's schematic pass |

**Healing herbs** (Alchemist only, never farmable; both continents reach
every tier — see §6): **gravemoss T1** (pine hills, blight),
**dragonweed T2** (crags, badlands, deep forest, bone forest),
**crimson lotus T3** (deep jungle, jungle fringe). All three sit on
stone, gravel, mesa clay, dead-wood litter or jungle floor.

The lotus source is the one that had to be repaired: until 2026-08-08 the
Accord's `grug_jungle_fringe` generated at 0.08 % of the land because the
deep forest contained its cuboid, so in practice **only the Throng had a
T3 healing herb**. The deep forest is now capped at x 1250 and the fringe
owns the east flank strip uncontested — 2.71 % of the land, against deep
jungle's 3.13 % on the Throng side (§1.3).

**Spices** (gathered by everyone, used by both the Alchemist and
Cooking — which costs no main slot — and farmable once farming ships):
**sunleaf T1** (meadows, savanna, elf forest, jungle edge),
**marshbloom T2** (swamp), **stormkelp T3** (coast-zone beaches). All
three sit on grass, mud or sand — cultivable ground.

**Cooking supply, checked against the cooking tiers** (cooking keeps its
own recipe book with T1–T6 groups, `items_crafting.md`; the tiers tie to
the region an ingredient comes from):

- Low and middle tiers come out of the settled rings and the swamp:
  potato, corn, apples, berries, melon, mushrooms, sunleaf, marshbloom,
  plus meat and fish from anywhere.
- **T6 needs ingredients from level 50+ ground, and the coast/outer
  rows do carry them**: **wild cocoa** in deep jungle / jungle fringe
  (38–60), **stormkelp** and **rock salt** on the coast-zone beaches
  (45–60), and the meat of the outer/coast families (bear, jungle ape,
  panther, crocodile), whose level comes from `mob_level_at` and is
  45–60 out there. Every one of them exists on both continents (§6), so
  neither faction is cut off from the top of the cooking ladder.
- **Deliberately found-only** (never a crop): mushrooms, wild cocoa,
  rock salt. That keeps the top of the cooking ladder a reason to
  travel, and it keeps a tier unlock ("find cocoa in the jungle") usable
  as a quest goal.

## 3. Mob roster

Per family: ONE verb, level = `mob_level_at(spawn)`, stats from
formulas, speed per combat_stats. `[leather]` = Leatherworker ×5 hook.
Drop chances in mobs_redo format (chance N = 1/N). Working item names —
final naming in items_crafting.md. All aggressive mobs:
`pathfinding = 1`, `group_attack` per verb, soft de-aggro 25 m (WP6).

### 3.0 Critters vs. passive prey vs. enemies (decided 2026-08-08)

Three behaviour classes, not two. The split is by **size and role**, not by
who runs away:

**Critters** — *small* animals only: **rabbit, hare, parrot, gull**, plus
the four additions the 2026-08-08 asset survey found on disk: **Cave Bat**
and a **cave crawler** (both `underground` — the caves had no critter at
all), **Bone Weevil** (bone forest + blight, the "creepy" biomes, day) and
**Bog Fowl** (swamp, day). The **Carrion Crow is deliberately NOT a
critter** — it is the last feather source and the entire daytime population
of the war coast, so it moves to the passive-prey class below instead
(same mesh, ~1.0 nodes tall, level 20–30 there). They are scenery with a
use, not content:

- **Always level 1, always 1 HP**, whatever the level field says at their
  position. This is the second documented exception to §0's "stats derived,
  never hand-rolled" rule (after the Kraken's fixed L100) and it is
  implemented as a **`critter` tier** in the level engine, not as a
  hand-set stat in a def.
- **10 XP flat.** Deliberate starter-belt trickle; the gray-kill rule
  (combat_stats §3) zeroes it for anyone above level 11 on its own, so no
  extra rule is needed.
- **They drop FOOD only** — meat, nothing else. No leather, no feather, no
  crafting ingredient of any kind. Rationale: a food item is a welcome
  snack on the road but never a farm target, so a player with a full larder
  stops killing them automatically. This is what fixes their loot-table
  "value as an enemy".
- **No fall damage.** At 1 HP any 7-node fall is lethal (mobs_redo
  charges `d − 6`), which would quietly delete the population in exactly
  the hilly terrain where a travelling player wants a snack. They drop
  nothing without a player tag anyway, so there is no exploit either way.
  **The field must be written `false`, not `0`** — mobs_redo tests
  `if self.fall_damage` (`mods/ENTITIES/mobs/api.lua:2608`) and every
  number is truthy in Lua, so `fall_damage = 0` is a silent no-op. Earlier
  revisions of this section printed `0`; the tier writes `false`.
- **Never elite or rare.** The level engine's telegraph gate must be a
  *positive* elite/rare test — a `tier ~= "normal"` test would give a
  rabbit a 2 s wind-up and a ×3 cone hit.

**How the tier is expressed** (WP36, `grug_mobs/levels.lua`): the `TIERS`
table gains a `critter` row that opts out of the multiplier model with FLAT
values (`hp_flat = 1`, `xp_flat = 10`) plus a fixed `level = 1`, so
`normal`/`elite`/`rare` keep the exact arithmetic they always had — a flat
value replaces the formula for one stat and leaves the other two alone.
Damage stays formula-derived even for a critter: it never attacks, so the
number is never read, and a third exception would be noise. `fall_damage`
is normalized into the def at registration time, next to `armor` and for the
same reason (mobs_redo copies an explicit def-field whitelist, and a nil
there falls through to its default of `true`). The telegraph gate is a
positive `telegraph = true` flag on the elite and rare rows, asked through
one predicate that both the `do_custom` gate and `telegraph_tick` call, and
`set_tier` refuses to promote a critter at all.

**Passive prey** — the *large* grazers: stag, gaunt stag, zebra, mountain
ram, **plus the Carrion Crow**. They are ordinary mobs in every mechanical
respect — **level from the field, HP and XP from the formulas, leather drops
kept** — with one behavioural difference from the aggressive families:
**they never attack on sight, but they fight back when attacked.** That is
what makes them worth the swing, and it keeps the leather tiers gated by a
real fight rather than by travel.

mobs_redo already expresses exactly this, so it is **four def fields and no
new aggro system** (`grug_mobs.passive_prey` in `verbs.lua` sets them in one
place): `passive = false` is what makes retaliation exist at all (on_punch's
tail calls `do_attack(hitter)` only for a non-passive mob, api.lua:2979),
`attack_players = false` (with `attack_npcs = false`) is what removes aggro
on sight — it is read in exactly one place, `general_attack`'s candidate
filter (api.lua:1787), and nothing in the attack *state* consults it —
`runaway` must be **off**, because on_punch's runaway block sets
`state = "runaway"` a dozen lines before the retaliation block resets it, so
the two cannot both be true — and **`attack_type = "dogfight"`** is what
makes the retaliation actually *fight*. That last one is necessary, not
decoration: `do_states`' attack branch dispatches on `explode` /
`dogfight`-`dogshoot` / `shoot`-`dogshoot` with **no else** (api.lua:2214,
2277, 2360, 2539) and `mobs.mob_class` defaults it to nil, so a
`passive = false` mob without an attack type holds a target reference and
does nothing with it — no damage, no punch clip, not even a `set_velocity`,
which leaves it coasting on the knockback until the leash drops it. It was
missing from the first WP36 cut and made a punched grazer *easier* to kill
than the 3 s `runaway` flee it replaced; `dogfight` is the melee family and
the right one, since prey carries no `arrow`. Two further systems read
`attack_type` as "can this fight at all" and were silent no-ops on prey
until it was set: the threat-driven target switch and the Taunt ability.
Setting it does **not** let prey initiate — acquisition on sight lives in
`general_attack` alone, which never reads the field.

The Carrion Crow's three decided changes, all zero-cost: `visual_size`
10 → **14** (~1.0 nodes tall — a target you can see and click), the
collisionbox scaled by that same 1.4 (`0.4 → 0.6` high, `0.2 → 0.3` wide),
and `punch` **aliased onto the fly clip** of the shared gull mesh so the
retaliation reads. Same mesh, same texture, same spawn row, same `aoc`.

**Enemies** — everything else, unchanged (§3.1's verbs).

Consequence for the material map (§6): plain **feather** loses its critter
source and moves to the **bird-of-prey table** (crag eagle / vulture), so
arrow fletching stays behind a real fight. Meat stays universal. The Carrion
Crow **keeps** its feather — it is prey, not a critter, and that drop is
what makes the war coast worth walking by day.

### 3.1 Families by biome group

**Settled biomes, all six (core + inner, L1–25):**

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Boar (exists; per-biome tint: Plague Boar in blight, Jungle Boar east) | charges — a mid-range **rush**: the stalker impulse flattened horizontally, triggered at 4–10 m with an 8 s cooldown | day | 4.4 (WP6 retune) | meat 1/1 ×1–2; light leather 1/2 `[leather]`; tusk 1/3 | grug_mobs_boar.b3d (have) |
| Rabbit/Hare (tints) | flees (**critter**, §3.0) | day | 3.4 | meat 1/1 — food only | mobs_mc_rabbit |
| Zombie (exists) | never leashes | night (in grug_blight: 24 h — Undead identity) | 4.2 | zombie flesh 1/1; linen scrap 1/2; steel ingot 1/10 | mobs_mc_zombie (have) |
| Bandit (camp humanoid; camps placed by §1.4, inner+outer, both continents) | defends camp (leashes to camp, group) | 24 h | 4.4 | linen cloth 1/1 ×1–2 (inner camps) / heavy cloth (outer camps); copper coins | character.b3d + bandit skins (LotT-derived) |

**Forest pair — grug_deep_forest (A) ↔ grug_bone_forest (T)** (outer,
25–60; Throng names in parentheses, same drop tables):

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Wolf (Blightfang Wolf) — also inner pine-hills/meadows patches from L10 | hunts in packs; flees low, returns with pack | 24 h | 4.4 | meat 1/1; leather 1/2 `[leather]`; fang 1/3 | mobs_mc_wolf (+tint) |
| Bear (Plaguehide Bear) — elite variant "Elder" ×1.6 scale, rolled **1 in 10 at spawn** | territorial (guards radius ~20 m, short chase) | day | 4.4 | meat 1/1 ×2; heavy leather 1/2 `[leather]`; bear claw 1/4 | mobs_mc_polarbear retexture |
| Giant Spider (tints per biome; also jungle, caves) | webs (hit applies 40% slow 3 s) | night | 4.4 | spider silk 1/1 ×1–2; venom gland 1/6 | mobs_monster spider |
| Stag (Gaunt Stag) | grazes (**passive prey**, §3.0: no aggro, retaliates) | day | 3.4 | meat 1/1 ×2; leather 1/2 `[leather]` | animalia reindeer (asset harvest) |
| Skeleton Archer — bone forest + war coast only | dogshoot (ranged) | night | 4.0 walk | bone 1/1; linen scrap 1/2; arrows | mobs_mc_skeleton |
| **Bone Weevil** — bone forest **and blight** (the two "creepy" biomes; one entity name, one `aoc` budget, per-biome tint stamped at spawn) | flees (**critter**, §3.0) | day | 3.4 | meat 1/1 — food only | mobs_mc_silverfish, bone-pale + blight tints |

**Mountain pair — grug_crags (A) ↔ grug_badlands (T)** (outer, 25–60):

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Crag Eagle (Vulture) | dive-bombs — a real **flier** (`fly` in air) on `dogfight`, whose vertical tracking drives it down onto a grounded target and back up: that IS the swoop, and it needs no projectile asset | day | 4.6 heartland | sharp feather 1/1 ×1–2; meat 1/2 | animalworld eagle (+tint) |
| Stone Golem (Mesa Golem) — **elite** (armor 80, telegraphed slam) | hurls rocks (dogshoot) | 24 h | 3.0 | stone core 1/1; iron lump 1/2; gem 1/8 | mobs_monster stone monster |
| Mountain Ram | grazes (**passive prey**, §3.0) | day | 3.4 | meat 1/1; **heavy** leather 1/4 `[leather]` — the ram is the crags' heavy-leather source, which is why it is prey and not a critter | mobs_mc sheepfur retexture |
| Hyena — savanna+badlands (Throng's wolf-mirror, wolf drop table) | hunts in packs | 24 h | 4.4 | wolf table | animalworld hyena |

The Ram's Throng mirror, the **Dust Hare**, is not a badlands critter of
its own: it is the dust-tinted variant of the settled Rabbit/Hare row
above (dry grass, blight, rainforest litter) and shares that row's
numbers and drops. The badlands therefore carry no critter — Hyena,
Vulture and Mesa Golem only.

**Savanna extras (grug_savanna inner, L10–25):** Hyena (above, from
L10); Zebra — grazes (**passive prey**, §3.0, exactly like the Stag it
mirrors), meat ×2 + leather 1/2 `[leather]`, animalworld zebra (Accord
mirror = Stag in meadows-adjacent forest patches: same table).

**Jungle group — grug_deep_jungle (T) ↔ grug_jungle_fringe (A)** (outer/
coast, 38–60) + grug_jungle_edge inner (10–25):

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| **Jungle Lynx** (the Raptor slot) — jungle_edge from L10, deep jungle | hunts in packs (wolf drop table) | day | 4.4 | meat 1/1; leather 1/2 `[leather]`; raptor claw 1/3 (item id kept) | big-cat retint of the panther mesh — the §8.2 fallback was **executed**: the paleotest velociraptor's media license could not be verified per file |
| Panther | stalks (silent approach, pounce burst) | night | 4.6 heartland | meat 1/1; leather 1/2 `[leather]`; sleek pelt 1/4 | animalworld leopard retint |
| Serpent | poisons (hit applies 1 dmg/2 s, 6 s) | day | 4.4 | scaled hide 1/2 `[leather]`; venom sac 1/3 (alchemy reagent) | animalworld cobra |
| Jungle Ape — elite variant "Silverback" (bear-mirror: bear drop table), rolled **1 in 10 at spawn** | territorial (radius ~20 m) | day | 4.4 | meat ×2; heavy leather 1/2 `[leather]`; ape hair 1/4 | animalworld monkey upscaled |
| Giant Spider (jungle tint) | webs | night | 4.4 | spider table | mobs_monster spider |
| Parrot — jungle_edge critter | flees (**critter**, §3.0) | day | 3.4 | meat 1/1 — food only (feather moved to the bird-of-prey table) | mobs_mc_parrot |

**grug_swamp (universal, 25–45):**

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Crocodile | ambushes (lurks still, burst on approach) | 24 h | **4.4, one speed** — the water bonus is dropped (see §4) | scaled hide 1/1 `[leather]`; meat; croc tooth 1/3 | animalworld crocodile |
| Bog Ooze | engulfs (slow tank: touch damage aura, **flat 2 damage**, radius 2 — the one hand-written damage number in the roster; its melee is level-scaled as usual) | 24 h | 2.6 | slime gel 1/1 ×1–2 (alchemy reagent); vendor trash | mobs_mc_slime retint |
| Mirefolk (fish-folk humanoid, camps at swamp pools; the "murloc memory") | swarms (camp group aggro, all rush at once) | 24 h | 4.4 | linen cloth 1/2; fish 1/1; shiny scale 1/4 | character.b3d small scale + custom skin (2D work) — decided: include |
| **Bog Fowl** — the swamp critter; universal biome, so the one new critter both continents share | flees (**critter**, §3.0) | day | 3.4 | meat 1/1 — food only (**not** its upstream's feather) | mobs_mc_chicken, marsh tint |

**grug_beach / strait (L1–5 neutral — attack only when provoked):**

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Shore Crab — **deferred (§8.3), not shipped** | retaliates (pinches when punched) | 24 h | 3.4 | crab meat 1/1; chitin 1/2 | deferred until a licensed model is sourced (decided); strait launches with Gull only |
| Gull | flees (**critter**, §3.0) | day | 3.4 fly | meat 1/1 — food only | animalia song bird retexture |

Coast-zone beaches (45–60) reuse Crab as an **elite** "Reef Lurker"
(scale ×1.6, armor 80) — same table ×3 quantity. **Deferred with the
Crab (§8.3)**: neither is registered, so the beach cells currently carry
the Gull alone.

**War coast (20–30, both continents):** local settled-biome roster
continues; plus Skeleton Raider (dogshoot, night — battlefield dead;
skeleton table + heavy cloth 1/3) and Carrion Crow (**passive prey**,
§3.0 — grazes/scavenges, no aggro, retaliates; feather 1/1, and it is the
whole daytime population of the war coast).
Faction NPC outposts/guards are WP6, not part of this catalog.

**Deep sea (world.md §2b):** Kraken Guard, L100 fixed (hand-set — the
one exception, it is a deterrent not content): mobs_mc_squid at
visual_size ×6, verb: drags under (pulls target down, heavy melee),
spawns only in open sea beyond the coastal ocean. No drops.

**Caves (depth axis, WP6 note):** reuse Zombie, Giant Spider, Stone
Golem with `underground` zone gating; levels come from the depth term
of `mob_level_at`. **Two cave-only critters since 2026-08-08** (§3.0 —
before them every single thing that moved underground wanted the player
dead): **Cave Bat** (flier, `mobs_mc_bat`, no retint) and **Cave
Crawler** (`mobs_mc_silverfish`, no retint). Both are `critter`-tier, so
the depth term never touches them — a level-60 bat is not a thing.

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Cave Bat | flees (**critter**, §3.0), flier | any (cave dark) | 3.4 fly | meat 1/1 — food only | mobs_mc_bat |
| Cave Crawler | flees (**critter**, §3.0) | any (cave dark) | 3.4 | meat 1/1 — food only | mobs_mc_silverfish |

### 3.2 Cross-continent drop-table pairs (binding)

| Shared table | Accord family | Throng family |
|---|---|---|
| wolf table | Wolf (forest/hills) | Blightfang Wolf, Hyena, Jungle Lynx* |
| bear table | Bear/Elder Bear | Plaguehide Bear, Jungle Ape/Silverback |
| spider table | Giant Spider | Giant Spider (tints) |
| stag table | Stag, Zebra-mirror | Gaunt Stag, Zebra |
| golem table | Stone Golem | Mesa Golem |
| bird-of-prey table | Crag Eagle | Vulture |
| jungle tables (panther/serpent) | jungle fringe (east flank) | deep jungle |
| swamp/beach/boar/zombie/bandit/skeleton | identical biomes both sides | identical |

*The Jungle Lynx also exists Throng-side inner (jungle edge) — the
Accord inner pack hunter is the Wolf; base drops match via the shared
wolf table.

**What "shared table" binds** (resolved in WP6): the first two slots —
the food/meat drop and the leather tier with its chance — are identical
item-for-item across a pair. The **third slot carries the family's own
flavor**: wolf/hyena → *fang* 1/3, Jungle Lynx → *raptor claw* 1/3;
bear → *bear claw* 1/4, jungle ape → *ape hair* 1/4. The economic value
of the pair stays equal (same tier, same chance), the trophy does not —
"same loot, different look" applies to the trophy too, and a literally
identical third item would erase the flavor for no balance gain.

### 3.3 Named rares (rare tier: armor 70, ×5 HP, ×2.2 dmg, ×6 XP, ×2 scale + tint, faction-wide spawn broadcast)

One per band + one shared war-coast rare per continent. Spawned by a
scheduled spawner (not ABM): respawn 2–4 h after kill, patrol route
between 2–3 fixed points. They inherit their base family's drop table
(×6 XP and the rare multipliers are the reward WP6 ships); the special
loot ROLLS ride on WP5's item/enchantment tables.

| Name | Base family | Where (band, ring) | ~L |
|------|-------------|--------------------|----|
| Grimtusk | Boar | A-center meadows, inner | 12 |
| Old Whitefang | Wolf | A-center deep forest, outer | 32 |
| Korgan's Bane | Stone Golem | A-west crags, outer | 42 |
| Silkfang | Giant Spider | A-east jungle fringe, coast | 50 |
| Marrowclaw | Plaguehide Bear | H-west bone forest, outer | 35 |
| Dustwing | Vulture | H-center badlands, outer | 38 |
| Emerald Coil | Serpent | H-east deep jungle, coast | 48 |
| Ashmaw | Boar (plague) | H-center savanna, inner | 12 |
| Captain Bonerattle (×2, one per continent) | Skeleton Raider | war coast | 28 |

## 4. Spawn parameter table

Mechanism: mobs_redo `mobs:spawn` + our `spawn_abm_check` override
(`_grug_spawn_zones`). Spawn `nodes` = the biome signature tops of §1.3
(LotT whitelist trick) — this alone confines most families; zones do
the ring gating. `min_height 0, max_height 200` on all surface entries
(golems and the crags rows — Ram, Crag Eagle — 300; the **Vulture
shares that 300 exception**, its mesa-clay badlands run just as high).
Day mobs `min_light 10`; night mobs `max_light 5`
+ `day_toggle = false` where mobs_redo supports it.

**`aoc` is per entity NAME, not per family** (mobs_redo counts objects
of that one name inside a 128-node sphere). Two spawn rows of the same
name — the Skeleton Archer's two node lists, a family's surface + cave
rows — share ONE budget; the per-biome tints are separate entities and
each carries the full row of its family, so a jungle spider and a pale
spider are two budgets of 4, not one.

**ROLE IS NOT RING** (added 2026-08-07 after a runtime report: a
`grug_deep_forest` patch on the human capital had guards but no
wildlife at all, day or night). The `nodes` column below hands out
whitelists by biome **role** — "settled tops" to the core/inner
families, wild tops to the outer/coast ones — and thereby silently
assumes that a settled biome only ever occurs in the settled rings.
The patch model (§1.4) deliberately breaks that: the band cuboids
overlap by 400–500 nodes, so **wild patches occur inside core/inner
and settled patches far outside**, while `_grug_spawn_zones` gates on
the radial ring. Every such patch was a biome × ring cell with zero
eligible mobs — 37 cells in total, among them ~25.7 % of the Accord
core belt (deep forest), the whole `grug_crags_snowy` biome (no row
anywhere listed `default:snowblock`; the biome arrived in WP18 and
this table was never extended) and `grug_elf_forest` × outer/coast,
the single largest dead area at ~4.9 % of the land.

The fix is on the MOB side, not the biome side — zones are a radial
field and biomes are boxes, so no cuboid edit can align them. Four
**filler slots** carry the tops of the *other* role, and their zone
lists confine the effect to exactly the rings that were dead:

| Slot | Family | Zones | Carries |
|------|--------|-------|---------|
| core/inner day | Boar | core, inner | all wild + universal land tops |
| core/inner critter | Rabbit / Hare | core, inner | the wild + universal tops of **its own continent** |
| core/inner + war coast night | Zombie (settled row) | core, inner, war_coast | all wild + universal land tops |
| outer/coast day+night | Bear + Giant Spider (A), Plaguehide Bear + Pale Spider (T) | outer, coast | the settled tops of their side |
| war coast day / night | Carrion Crow / Skeleton Raider | war_coast | every land top (both are war_coast-exclusive) |

**"The settled tops of their side" was incomplete until WP36**: the
outer/coast row was missing `default:dirt_with_grass` (Bear + Giant
Spider) and `default:dry_dirt_with_dry_grass` (Plaguehide + Pale Spider),
which is why `grug_meadows × coast` and `grug_savanna × coast` were dead
day and night after the D4 rollback extended the centre band to Z_MAX
(§1.5). The jungle edge's rainforest litter stays out of the Throng pair on
purpose, **because that top is the one land top both continents carry**
(`grug_jungle_edge` T / `grug_jungle_fringe` A, §1.3) and neither Plaguehide
Bear nor Pale Spider has a `_grug_spawn_check` — the filler would tint the
Accord's jungle fringe Throng. It is *not* a budget argument: that cell is
Panther 4 + Jungle Spider 4 = 8 at night, so the Pale Spider would take it
to 12, level with the peak, not over it.

Two consequences worth stating: (a) no cell's Σaoc can rise from a
filler node, because the filler always lands on a family that already
inhabits that ring via its own tops and `aoc` counts per entity NAME —
a stray match (mgv7 riverbed sand, the world-wide gravel blob ore) adds
spawn *chances*, never a second budget; (b) Rabbit/Hare needed a
`_grug_spawn_check` continent gate (golem.lua's idiom), because swamp
and beach are registered once world-wide, so `mud`/`sand` are the only
two filler nodes that are not continent-derivable.

Calibration: current baseline boar interval 30 / chance 2000 / aoc 4
on 5 node types = "sparse-to-ok" → common mobs get roughly **2× the
attempt rate** (interval 20, chance 1500) on 1–2 node types. The
per-biome aoc SUM is a soft ~14 (day); the rows below actually **peak
at 16 by day** (meadows/inner, savanna/inner and — since the filler —
deep-forest/inner) **and 12 at night**
(bone forest/outer) — a deliberate ~15 % overshoot of the soft cap,
because those are precisely the cells that hit the ~1 mob per 15–20 m
target, while the median cell lands nearer 28–35 m. The full per-cell
arithmetic, the density model and the calibration knobs (reach for
`chance` before `aoc`) are the audit trail in
**[docs/research/wp6_spawn_budget.md](../research/wp6_spawn_budget.md)**.

**Surface density raised by 0.75 (decided 2026-08-08) — DECIDED, NOT YET
IMPLEMENTED.** The overworld is to feel a little busier, so **every
surface row's `chance` is multiplied by 0.75** — one third more spawn
attempts. **The `chance` column below is the DECIDED value, not the
shipped one**: `grug_mobs` still passes the pre-multiplication WP6 number
to every `mobs:spawn` row, i.e. **shipped `chance` = table value ÷ 0.75**
(Boar 1500 against the table's 1125, Rabbit 1800/1350, Stag 1800/1350,
Ram 2200/1650, and so on), and the three excluded rows below match code
exactly because they were never multiplied. Rolling the multiplication
out across the roster is implementation work, not an open design
question, and is tracked as **BACKLOG WP37**; **until it ships, a `chance`
in this table does not predict what a fresh world does**, and a code
comment in `mods/ENTITIES/grug_mobs/*.lua` that quotes "its §4 row" may
quote the shipped number instead of the one printed here — the same gap,
and the same WP re-syncs both. **`aoc` is untouched on
purpose**: it is the ceiling the budget audit calibrated against the
100-player target, it counts per entity NAME, and it therefore still
bounds the outcome — more attempts fill the same budget faster, they do
not raise it, so no cell's peak Σaoc moves. Two kinds of row are
excluded, and both exclusions follow from the mechanism rather than from
taste: the rows that also carry `underground` (Giant Spider, Stone/Mesa
Golem) are *one* row for surface and cave, so raising them would raise
cave pressure, which the phase-in pulse of §4.1 now owns; and the Kraken
Guard is a deterrent, not density. The budget audit is re-run against
the new values once the change ships.

| Mob | nodes (spawn on) | interval | chance | aoc | light | zones |
|-----|------------------|----------|--------|-----|-------|-------|
| Boar (all tints) | all six settled tops **+ forest litter, mesa_clay, gravel, snowblock, mud, sand** (core/inner filler); the **Jungle Boar** additionally carries **canopy litter** — deep-jungle patches in `inner` (§1.5) | 20 | 1125 | 5 | min 10 | core, inner |
| Rabbit/Hare | settled tops **+ the filler tops of its own continent** — Rabbit: forest litter, gravel, snowblock, mud, sand; Hare: mud, sand (no mesa_clay, §3.1 "the badlands carry no critter"). Split by a `territory_at` check | 20 | 1350 | 3 | min 10 | core, inner |
| Zombie | settled tops **+ forest litter, canopy litter, mesa_clay, gravel, snowblock, mud, sand** (night filler) | 20 | 1200 | 4 | max 5 (blight: any) | core, inner, war_coast |
| Wolf/Blightfang | coniferous litter, forest litter, bone litter, grass | 20 | 1125 | 5 | any | inner, outer |
| Hyena | dry grass, mesa_clay | 20 | 1125 | 5 | any | inner, outer |
| Jungle Lynx (Raptor slot) | rainforest litter **+ canopy litter** | 20 | 1125 | 5 | min 10 | inner, outer |
| Bear/Plaguehide | forest litter **+ silver litter, coniferous litter, grass** (Bear) / bone litter **+ blight_dirt, dry grass** (Plaguehide) | 20 | 2100 | 2 | min 10 | outer, coast |
| Jungle Ape | rainforest litter **+ canopy litter** | 20 | 2100 | 2 | min 10 | outer, coast |
| Giant Spider (all) | forest litter **+ silver litter, coniferous litter, grass** (Giant) / bone litter **+ blight_dirt, dry grass** (Pale) / rainforest litter **+ canopy litter** (Jungle) | 20 | 1800 | 4 | max 5 | outer, coast, underground |
| Stag/Gaunt Stag/Zebra | forest litter, bone litter, grass, dry grass | 20 | 1350 | 3 | min 10 | inner, outer |
| Skeleton Archer | bone litter, blight_dirt, settled tops (war coast) | 20 | 1500 | 3 | max 5 | outer, war_coast |
| Skeleton Raider | **every land top** + sand (war_coast-exclusive) | 20 | 1500 | 3 | max 5 | war_coast |
| Crag Eagle/Vulture | gravel, **snowblock**, mesa_clay | 20 | 1500 | 3 | min 10 | outer, coast |
| Stone/Mesa Golem (elite) | gravel, **snowblock**, stone, mesa_clay | 30 | 9000 | 1 | any | outer, coast, underground |
| Ram | gravel, **snowblock** | 20 | 1650 | 2 | min 10 | outer |
| Panther | rainforest litter **+ canopy litter** | 20 | 1350 | 4 | max 5 | outer, coast |
| Serpent | rainforest litter **+ canopy litter**, mud | 20 | 1350 | 4 | min 10 | outer, coast |
| Crocodile | mud (only) | 20 | 1350 | 3 | any | outer |
| Bog Ooze | mud | 20 | 1500 | 3 | any | outer |
| Parrot | rainforest litter | 20 | 1875 | 2 | min 10 | core, inner |
| Carrion Crow | **every land top** except sand (the Gull holds that slot); war_coast-exclusive | 20 | 1875 | 2 | min 10 | war_coast |
| Shore Crab — *deferred (§8.3)* | sand | 20 | 1650 | 3 | any | strait, war_coast, coast |
| Gull | sand | 20 | 1875 | 2 | min 10 | strait, war_coast, coast, **outer** |
| **Cave Bat** (critter) | stone **+ `group:grug_stratum`** | 20 | 1650 | 2 | max 5 | underground |
| **Cave Crawler** (critter) | stone **+ `group:grug_stratum`** | 20 | 1650 | **1** | max 5 | underground |
| **Bone Weevil** (critter) | bone litter / blight_dirt — **two rows, one entity name, one budget**; the row stamps the tint | 20 | 1650 | 2 | min 10 | (none — the node gates) |
| **Bog Fowl** (critter) | mud (only) | 20 | 1650 | 2 | min 10 | (none — the node gates) |
| Reef Lurker (elite crab) — *deferred (§8.3)* | sand | 30 | 6000 | 1 | any | coast |
| Kraken Guard | ocean water surface, open sea only (own check) | 60 | 12000 | 1 | any | (outside continents) |
| Bandits / Mirefolk | **no ABM** — camp anchor with **respawn slots** (world.md §4a): max 3–5, one refill per 120–300 s, dormant catch-up | — | — | 3–5 per camp | — | camp pos |
| Named rares | **no ABM** — scheduled spawner, 2–4 h respawn, broadcast | — | — | 1 | — | fixed routes |

Row notes:
- **Crocodile spawns on mud only.** "Water at mud" is not expressible:
  the spawn ABM's `nodes` list is the node it spawns ON and `neighbors`
  is an OR set, so "water AND mud" cannot be written. The lurking-in-
  water half of the verb is delivered by `floats` instead — the croc
  spawns on the mud bank and drifts into the pool.
- The **Skeleton Raider** reuses the Skeleton Archer's numbers
  (20 / 1500 / 3, night); it is the war-coast family, so its
  `war_coast`-only zone does all the gating and it needs no extra
  check. Its table is the skeleton table **plus heavy cloth 1/3**.
- **Parrot** and **Carrion Crow** are priced like the Gull, the other
  "flees" bird: 20 / 1875 / 2. Neither creates a new peak. The Crow's
  move to passive prey (§3.0) changed **no** spawn number — same row,
  same `aoc`, same zone.
- **The four critters of §3.0** (added 2026-08-08) all share
  20 / 1650 / 2 — they were authored at the WP6-style **2200** and ship at
  it, and 1650 is that number carried through the 0.75 rule above like
  every other surface row, so they read the same way as the rest of the
  table (decided here, still 2200 in `grug_mobs`) — with **one exception
  that is pure arithmetic**: the
  **Cave Crawler ships at `aoc` 1**. The underground cell was
  Zombie 4 + Giant Spider 4 + one Golem 1 = **9 / 9**; two cave critters
  at 2 each would make it 13 / 13, one over the world night peak of 12,
  so 2 + 1 lands it exactly on **12 / 12**. The two surface critters
  raise no cell above 14 against the day peak of 16
  (`wp6_spawn_budget.md` §2.2). The **Bone Weevil is deliberately ONE
  entity name with two spawn rows** — `aoc` counts per name, so the bone
  forest and the blight share its budget of 2 the way the Skeleton
  Archer's two node lists share theirs, while an `on_spawn` stamp still
  gives each biome its own tint. Two registrations would have been two
  budgets.

Performance justification (AGENTS.md rules, 100-player scale):
- aoc caps are per mob NAME in the spawn area, so co-located players
  SHARE the local budget; measured worst case Σaoc = 16 day / 12 night
  per biome around a lone traveler (wp6_spawn_budget.md §2, against the
  ~14 the rows were sized for). 100 dispersed players ≈ low thousands
  of candidate checks but capped actives: additionally set mobs_redo
  `mob_active_limit = 600` (global hard cap) in game settings.
- interval ≥ 20 s keeps the spawn ABM cheap; signature-node whitelists
  shrink the candidate node set per ABM tick; `catch_up = false`.
- Camps/rares off the ABM entirely (node timers / scheduled) — zero
  idle cost.
- The density target is delivered by SPAWN RELIABILITY (every surface
  chunk has whitelisted nodes) rather than raw counts; WP6's
  pathfinding/perf pass remains the blocker before raising any aoc.

### 4.1 The depth phase-in pulse (decided 2026-08-08)

Depth is a danger axis, not only a material axis (`combat_stats.md` §3,
`world.md` §4c). Because regular mobs cap at level 60, everything past
that cap has to be bought with **frequency**: a trickle that never lets
a miner finish clearing the room, so deep mining happens under permanent
pressure. This section owns that trickle.

**Mechanism: a player-centric pulse in a throttled
`register_globalstep`, never an ABM.** The reason belongs here, because
it is the constraint that rules out the obvious answer and it will be
re-discovered otherwise: `mobs:spawn` registers a **static** ABM whose
`chance` and `active_object_count` are fixed at registration time, and
**`aoc` counts per entity NAME inside a 128-node sphere, shared by every
row of that name** (see the note above §4's table). A second, deeper row
for an existing mob therefore cannot carry a larger budget than the
shallow one, and a rate that varies continuously *within* a band is not
expressible in the ABM model at all. A pulse also scales with player
presence instead of with how much air the mapgen happened to carve,
which is the right cost model at the 100-player target.

**The arrival curve** — one formula, safe by construction:

`arrivals_per_minute = min(R_MAX, max(0, (−y − Y0) · R_MAX / SPAN))`
with **Y0 = 300**, **R_MAX = 6/min**, **SPAN = 1700**.

| Depth | Arrivals/min |
|---|---|
| above −300 | 0 — the pulse does not exist here |
| −1000 | ~2.5 |
| −1500 | ~4.2 |
| −2000 and below | 6 (the ceiling) |

The `min()` is what makes the formula hold below −2000 instead of
growing without bound; the `max(0, …)` is what keeps the overworld free
of it. These are starting values, calibrated in a runtime test the way
`docs/research/wp6_spawn_budget.md` calibrated the ABM rows.

**Concurrent cap: 6 phase-in mobs per player.** This is the real safety
valve and the number the 100-player target actually cares about — it is
checked first in the runtime test. A modest concurrent cap with a high
arrival rate is also far cheaper than a swarm, and it is the shape the
design wants anyway: pressure, not a wall of bodies.

**Light-independent, and it may place a mob inside a sealed room.**
Wherever the pulse is active it ignores light entirely, and it is
allowed to put an arrival into a chamber the player dug out and walled
up. That is deliberate and it is the whole mechanic: dropping `max_light`
alone would only kill the *lit* cave, never the 3×3 bunker, because a
sealed room offers no spawn position at all — "there are no safe places
down here" has to be literally true or it is decoration. Every arrival
carries a **~2 s telegraph** (particle burst + sound) before it exists,
on the pattern of the elite wind-up of `combat_stats.md` §3, so the
player is warned by the world rather than ambushed by a rule.

**The roster is staged, and it needs no new mob to ship:**

- **−300 … −1000: the existing cave families** (§3.1's cave note —
  Zombie, Giant Spider, Stone Golem), levelled by `mob_level_at` like
  everything else. The fiction reads as the local dead being drawn
  upward from below rather than as an invasion, which is exactly what
  this band is.
- **below −1000: the deep band's own servants** (`story.md` §1 — the
  ancient thing below stretches its hands up; these are its household,
  not local wildlife). Their families are catalogued in §3 as they are
  authored.

The consequence is worth stating: because the shallow half reuses rows
that already exist, **the depth work can ship without a single new
mob**, and the servant roster becomes content that lands on top rather
than a blocker underneath.

**The ABM cave rows are untouched.** They stay exactly as §4's table
registers them and remain the ambient cave life; the pulse is a second,
independent source layered over them, and it is the only one that scales
with depth.

## 5. Per-race woods & build sets (LotT pattern)

Pattern from lottplants/lottblocks: per-race tree + wood + a small
build-material set; settlement schematics use ONLY their race's set →
instant visual identity, and "same loot, different look" between
mirrored biomes. Wood from all six trees is `group:wood` (base recipes
accept any; race woods matter for looks + settlement schematics).

| Race | Tree (name) | Schematic source | Nodes (new unless BASE) | Build-material set | Grows in |
|------|-------------|------------------|--------------------------|--------------------|----------|
| Human | Oak | BASE apple_tree.mts | default tree/wood (desc "Oak") | oak planks, cobble, brick, thatch (grug_nodes:thatch, straw retint) | meadows, deep forest |
| Dwarf | Mountain Pine | BASE pine_tree.mts (+snowy) | default pine | pine planks, stonebrick, grug_nodes:carved_granite (stone retint) | pine hills, crags edge |
| Elf | Silverwood | aspen_tree.mts node-substituted (**new** silverwood variant) + **new** great_silverwood.mts (treehouse base, §1.4) | grug_trees:silverwood_{tree,wood,leaves,sapling} — pale bark/leaf retint of aspen | silverwood planks, grug_nodes:marble (white stone retint; sold by dwarven vendors — trade hook) | elf forest only (the deep forest grows real aspen, §2) |
| Orc | Spikethorn Acacia | BASE acacia_tree.mts | default acacia | acacia planks, grug_nodes:adobe (dry-dirt+straw craft), bone block | savanna, badlands edge |
| Troll | Kapok | BASE jungle_tree.mts + emergent | default junglewood | jungle planks, mossycobble, grug_nodes:carved_totem (deco) | jungle edge, deep jungle |
| Undead | Gravewood | **new** dead-tree .mts (bare twisted trunk, no leaves; build in-world, save via schematic tool) | grug_trees:gravewood_{tree,wood,sapling} — blackened apple-log retint | gravewood planks, grug_nodes:cursed_cobble (mossycobble retint), bone block | blight, bone forest, swamp variant |

Missing assets summary: silverwood + gravewood textures (retints),
great_silverwood.mts + gravewood .mts schematics (hand-built), adobe/
marble/carved_granite/thatch/bone block/cursed_cobble/carved_totem
node textures (retints). All 2D retints of MTG media (CC BY-SA 3.0) —
license-clean, keep attribution.

## 6. Base-material map (both continents feed all base recipes)

| Material | Tier | Accord sources | Throng sources |
|----------|------|------------------|---------------|
| Light leather `[leather]` | 1–15 | boars | plague boars |
| Feather (fletching) | 20–60 | crag eagles, carrion crows | vultures, carrion crows |
| Leather `[leather]` | 10–45 | wolves, stags | hyenas, jungle lynxes, blightfang wolves, zebras, panthers* (*fringe gives A access too) |
| Heavy leather `[leather]` | 25–60 | bears, elder bears, rams | plaguehide bears, jungle apes |
| Scaled hide `[leather]` | 25–60 | crocodiles (swamp), serpents (fringe) | crocodiles, serpents |
| Linen **scrap** (trash tier, sells; not the cloth) | 1–30 | zombies, skeletons | same |
| Linen cloth | 10–30 | **bandit camps** (core/inner), mirefolk | same |
| Heavy cloth | 25–45 | outer bandit camps, war-coast raiders | same |
| Spider silk (Tailor T3) | 25–60 | deep-forest/fringe spiders | bone-forest/jungle spiders |
| Food plants (everyone, farmable later) | all | potatoes/corn (meadows), berries (hills, elf forest), apples, melon (fringe), meat/fish everywhere | corn (savanna), melon (jungle), berries via forest patches, meat/fish |
| Food plants, **found-only** (everyone, never farmable) | 25–60 | mushrooms (deep forest/swamp), wild cocoa (jungle fringe), rock salt (coast beaches) | mushrooms (bone forest/swamp), wild cocoa (deep jungle), rock salt (coast beaches) |
| Healing herbs T1 (Alchemist) | 10–25 | gravemoss (pine hills) | gravemoss (blight) |
| Healing herbs T2 | 25–45 | dragonweed (crags, deep forest) | dragonweed (badlands, bone forest) |
| Healing herbs T3 | 45–60 | crimson lotus (jungle fringe — the east flank strip x 1251..1500, which the fringe only got on 2026-08-08, §1.3) | crimson lotus (deep jungle) |
| Spices T1 (everyone gathers; Alchemist + Cooking use) | 10–25 | sunleaf (meadows, elf forest) | sunleaf (savanna, jungle edge) |
| Spices T2 | 25–45 | marshbloom (swamp) | marshbloom (swamp) |
| Spices T3 | 45–60 | stormkelp (coast) | stormkelp (coast) |
| Alchemy reagents (mob) | 25–60 | venom gland/sac, slime gel, bear claw | identical (shared tables) |
| Woods | all | oak, pine, silverwood (+jungle at fringe) | acacia, kapok, gravewood — all `group:wood` |
| Ores/gems | depth axis | universal underground + golem drops | same |

Every row has at least one source per continent. Race woods are
deliberately asymmetric (identity); base recipes accept `group:wood`.

**Two rows moved with the critter rework of §3.0 (2026-08-08).** *Light
leather* lost rabbits and hares — critters drop food only — and the row's
"rams" entry was stale anyway (§3.1 gives the Mountain Ram **heavy**
leather, which is why that family is prey and not a critter). The Boar
carries the tier alone now, and it exists on both continents, so the
"one source per continent" rule holds. *Feather* is a row for the first
time: it used to fall off the Gull and the Parrot, i.e. off two 1 HP
critters, and now comes off the **bird-of-prey table** (§3.2) plus the
Carrion Crow, which is prey rather than a critter — so arrow fletching
is behind a fight on both sides.

**Cloth supply, precisely** (resolved in WP6): zombies and skeletons
drop **linen scrap**, which is vendor trash, *not* the tailoring
material. The cloth line comes from **humanoids** — bandit camps for
linen (core/inner) and heavy cloth (everything further out), mirefolk
camps for linen. The camp supply is therefore the whole cloth economy,
and WP6 ships it as **12 deterministic bandit camps, two per race band**
(one inner at |z| ≈ 550, one outer at |z| ≈ 1350, offset from the
capital's x so they never collide with the outpost column). The
patch-driven camps of §1.4 — the ones rolled per settlement candidate —
land with WP13's structure pass and thicken that supply; they do not
create it.

## 7. Asset shopping list (models; licenses per docs/research/assets/mobs_animals.md — re-verify in source repo before import, AGENTS.md rule)

| Mob(s) | Source | License (code/media) | Work needed |
|--------|--------|----------------------|-------------|
| Boar, Zombie | already vendored | GPLv3 / CC BY-SA 4.0 | retints only |
| Rabbit, Parrot, Skeleton, Wolf, Slime→Ooze, Squid→Kraken, Polar bear→Bear, Sheep→Ram, **Bat→Cave Bat, Silverfish→Cave Crawler/Bone Weevil, Chicken→Bog Fowl** | VoxeLibre mobs_mc | GPLv3 / CC BY-SA 4.0 | mcl_mobs→mobs_redo port (pattern known), retextures; the four critters of §3.0 are **zero-download** — the meshes were already on disk |
| Spider, Stone Golem | mobs_monster (TenPlus1) | MIT / CC BY 3.0 | drop-in mobs_redo, retint |
| Hyena, Zebra, Eagle/Vulture, Leopard→Panther, Cobra→Serpent, Crocodile, Monkey→Ape | animalworld (mt-mods) | MIT / MIT (**sounds: verify per file, freesound CC**) | mobs_redo-native; texture pass toward 16px style |
| Reindeer→Stag, Song bird→Gull/Crow | animalia (ElCeejo) | MIT / MIT | asset harvest, re-register on mobs_redo, remap anim frames |
| ~~Raptor~~ → **Jungle Lynx** | paleotest media unverifiable per file → big-cat retint of the panther mesh (animalworld, MIT) | MIT / MIT | fallback executed in WP6, retint only |
| Bandit, Mirefolk | character.b3d + skins | LGPL 2.1 mesh; LotT skins CC BY-SA 3.0 | 2D skin work (mirefolk fully custom) |
| Shore Crab | no verified source yet (check marinara / nssm in-repo) | — | decided: deferred until sourced |
| Trees/nodes | MTG media retints + 2 hand-built schematics | CC BY-SA 3.0 | see §5 |

Never import without checking LICENSE in the source repo; document
every file in the mod's LICENSE-media.md.

## 8. Resolved decision points (2026-08-06)

All four flagged points were decided per recommendation; points 2, 3
and 5 record what WP6 then actually shipped.

1. **War coast** = local band biome + battlefield decoration overlay,
   no separate biome.
2. **Raptor**: verify the paleotest media license per file; on failure
   replace the family with "Jungle Lynx" (big-cat retint, same pack
   verb and drop table). **The fallback was executed** — the paleotest
   media could not be verified per file, so the family ships as the
   Jungle Lynx (same verb, same drops, `raptor_claw` item id kept).
3. **Mirefolk is in** (custom 2D skin work); **Shore Crab deferred**
   until a licensed model is sourced — the strait launches with Gull
   only. WP6 confirmed the deferral: neither Shore Crab nor its elite
   Reef Lurker is registered, and the §3.1/§4 rows for both stay in
   this catalog as the spec to implement once a model exists.
4. **Jungle fringe reuses the troll jungle nodes 1:1** on the Accord
   side (max drop symmetry, zero new assets). Until WP36 the Throng had
   only one jungle ground node, so "the troll jungle" named one thing;
   since `grug_deep_jungle` got a top of its own (§1.3) it names two, and
   **which one this point meant is not decided here**. What ships is the
   fringe on `default:dirt_with_rainforest_litter`, i.e. the
   `grug_jungle_edge` reading. The open question, both readings and what a
   change would cost:
   **[TODO-design-jungle-fringe.md](../../TODO-design-jungle-fringe.md)**.
5. **The boar's "charges"** is implemented as a **mid-range rush**, not
   a wind-up gallop: the same impulse the panther's pounce uses,
   flattened horizontally, fired at 4–10 m with an 8 s cooldown. One
   verb helper serves both families, and the boar reads as a charger
   without a second state machine.
