# World design historical extracts

Archived 2026-09-23 during documentation cleanup. Source snapshot: `d6937b31`.
These extracts preserve earlier decisions, experiments and implementation
narratives; their present-tense claims apply only to their original period.
They are not current design, release gates or permission to restore retired
behavior. Current authority is `docs/design/world_zones.md`,
`docs/design/biomes_mobs.md`, `docs/design/world.md` and the open depth questions
in `TODO-design-depth.md`. Existing evidence files and hashes are unchanged.

## Source: docs/design/world.md, historical capital-anchor subsection

### Historical: the WP18/WP36 capital anchors (retired 2026-09-13)

**None of this is running code any more.** WP40 R7 replaced it: the six
capitals sit in their own named zones, spawns come from
`grug_core.start_position`, and `grug_mapgen/structures.lua` -- the file that
built the placeholder platforms -- no longer exists. The block below is kept
because the biome-guarantee argument is worth re-reading before anyone
re-proposes climate tuning, not because it describes the map. It placed six
platforms at x = 0/±550, z = ±900 and used them as spawn points.

**"In the race's own biome" is a guarantee, not a hope (decided
2026-08-08).** It used to be neither enforced nor true: on a random
seed the intended biome won at the anchor in 22–63 % of cases at four
of the six capitals — the human capital came up deep forest, the dwarf
capital meadows, undead and troll savanna. What ships now:

- **Guaranteed radius R = 200.** In the whole ±200 box around every one
  of the six anchors, exactly **one** biome is registered — the race's
  own. Verified over 200 random seeds at 100 %.
- **How**: geometry, not climate tuning. The engine filters biome
  cuboids on the raw integer position *before* it reads heat/humidity
  (`BiomeGenOriginal::calcBiomeFromNoise`), so a containment argument is
  seed-proof, while the climate at a capital is effectively a coin flip
  of the seed (spread 1000 over a 3000×1600 continent leaves only ~5
  independent large-octave samples per continent — even collapsing every
  settled point onto the noise mean scored 0 % at four capitals, and the
  engine's `weight` knob tops out at 56–94 % while distorting shares
  everywhere else).
- **The carve box** (§1) pushes the four wild side bands out to
  |x| ≥ 801, moves the badlands/deep-forest back country to |z| ≥ 1201,
  narrows the centre band to |x| ≤ 349 over its whole z range, and lets
  the side settled bands reach in to |x| ≥ 201.
  R = min(800 − 550, 550 − 350) = 200; the theoretical maximum is 274,
  because two neighbouring capitals are only 550 apart. Registration
  detail and the resulting biome table: `biomes_mobs.md` §1.3.
  The centre band first shipped as three slabs (a narrow belt inside the
  box, full-width front and back slabs outside it) to keep the wide
  centre↔side overlaps; that was **rolled back the same day** because the
  slabs' four new cuboid faces cost 1 500 nodes of straight ground border
  — three quarters of the whole regression the carve caused. Only the
  deep forest still needs slabs, because only it needs a hole in the
  middle of its cuboid. See the D4 note in `biomes_mobs.md` §1.3 before
  re-proposing them.
- **No coverage hole**: the narrowed centre band without the side-band
  extension to |x| ≥ 201 would leave 5 % of the land with no eligible
  biome at all, which generates as bare stone (measured negative control:
  478 799 land columns). Verified on the shipped registrations: **0** land
  columns without a biome, at every y from 4 to 31000.
- **Accepted residual (D5)**: `grug_swamp` (y 1..6) and `grug_beach`
  (y 1..4) are universal, x/z-unlimited and are **not** carved. A
  capital whose terrain surface lands at y ≤ 6 can therefore still come
  up swamp or beach — measured at ~30 % of the box at y 5–6 and ~75 % at
  y 4. Accepted rather than split both into z-slabs as well: the camp
  platform sits at the engine spawn level and our terrain baseline is
  lifted ~6–10 nodes above sea level, so a capital that low is a corner
  case, and the cost would be six more registrations plus their deco
  lists.


## Source: docs/design/biomes_mobs.md, former section 1

## 1. Current WP18 world biome map (WP40 migration baseline)

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
   The shipped WP36 `grug_jungle_fringe` keeps
   `default:dirt_with_rainforest_litter`; every legacy number in this
   section was measured against it. The named-zone target decided 2026-08-11
   instead pairs the Skyglass fringe with `grug_deep_jungle` and therefore
   uses `grug_nodes:dirt_with_canopy_litter`. WP40 makes that swap while
   replacing the old registrations and re-derives its logical spawn cells.
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
   **Named-zone decision 2026-08-11:** retain this family as the ochre
   outcrop component of Thunderroot Wilds and Stormscale Summit. It is
   Troll-region geology there, not a claim that the whole Orc badlands family
   belongs to Trolls.
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
`grug_mapgen/biomes.lua` carried the same numbers (file retired with WP40 R7).

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

What the table actually shows is **one shipped WP36 legacy gap repeated once
per band, not an east/west asymmetry**: wherever a band's settled cuboid, its
wild partner and the flank strip do not all overlap, the leftover strip has a
single eligible registration. The old cuboid layout therefore lacks a Throng
equivalent of `grug_deep_forest_front` and the deep forest's x −900..1250 back
slab (`grug_badlands` is only x −700..700, z 1201..1700). WP40 replaces these
registrations with authoritative named-zone palettes and must prove the final
coverage; extending the obsolete cuboids is not target work.

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
- **Target coastal habitat**: the nominal band where
  `expanded_land_at(80) and not land_at` holds around authored positive
  mainland or dragon-island shapes carries coral, kelp, fish and
  harmless-to-low-level shore wildlife, distinct from immutable deep ocean.
  Planned bays/lakes/rivers remain zone water and receive their logical-biome
  dressing instead. Shore Crab and Reef Lurker remain deferred for want of a
  licensed model (§8.3).
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

**Retired target, retained as a shipped-map record.** WP13 must not implement
this ring/band settlement pass. WP40 first replaces it with the named-zone POI
slots and adjacency graph from `world_zones.md` §§8–11; the probabilities
below remain useful calibration data, not future placement authority.

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

This verifies the current WP18/WP36 map. WP40 must produce the equivalent
continuity and spawn-coverage proof for every named-zone boundary before it
removes any old spawn cell.

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


## Source: TODO-design-depth.md, pre-cleanup decision history

The two genuinely open questions are retained in the root TODO. Statements
below that call WP34 mechanics shipped or retain `difficulty_at` are historical
claims, not verified current state.

# TODO — Depth: danger, spawn pressure and where resources come from

Opened 2026-08-08, out of the WP25 runtime test. WP25 shipped the six rock
strata, so depth is now a real gate for the first time — and testing it
surfaced a set of coupled questions the existing docs answered either not
at all or in a way the owner has since overturned.

**The settled depth rules were folded into `docs/design/`.** What remains here
is their reasoning plus the two unresolved spawn/content details below
(AGENTS.md "Documentation layers").

**Two small remainders are still open**, both content rather than mechanics:
the pulse's placement geometry (A2) and the servant roster below −1000
(A2/D10).

Groups: **A** the depth curve and spawn pressure · **B** renewable
resources · **D** the T6 band as endgame content.

---

## A. The depth curve and spawn pressure

### A1 — The depth level curve

**Decision:** decided 2026-08-08 → **landed in `combat_stats.md` §3**
(with the anchors and the crossover points; `world.md` §1 and §4c and
`biomes_mobs.md` §1.5 cite it).

The model is unchanged and was already correct: `mob_level_at =
max(surface_level(x,z), depth_level(y))`, cap 60. Only the *rate* is
recalibrated, so that the two anchors the owner set fall exactly on
stratum boundaries.

Why `max()` and not an additive term, since the question came up: depth danger
is absolute in y, while natural-resource placement and minimum harvest tier are
separate contracts. An additive depth term would make the same y position a
different game depending on where the player stands horizontally, would make
the newbie zone the safest place to pursue deep resources, and would blow the
level cap. `max()` binds danger to depth, which is what makes mining the
"alternative progression path" that `combat_stats.md` §3 already claims it is.

### A2 — Spawn pressure by depth: the phase-in

**Decision:** decided 2026-08-08 → **landed in `biomes_mobs.md` §4.1**
(mechanism, curve, concurrent cap, the sealed-room rule with its
telegraph, and the staged roster); `combat_stats.md` §3 and `world.md`
§4c link to it with a sentence each.

The load-bearing decision of this file, and the constraint that decided
it belongs here as well as in the design doc: `mobs:spawn` registers a
**static** ABM whose `chance` and `active_object_count` are fixed at
registration time, and **`aoc` counts per entity NAME in a 128-node
sphere, shared by every row of that name** (AGENTS.md; measured in
`docs/research/wp6_spawn_budget.md`). A depth-continuous spawn rate is
not expressible in the ABM model at all. A **player-centric pulse in a
throttled globalstep** was chosen because it is the only option that
yields a continuous curve, it scales with player presence rather than
with how much air the mapgen happened to carve, and it is the only one
that can ignore light on purpose.

Rejected:

- **One "deep" entity name per mob** (`grug_mobs:zombie_deep`, …) to buy
  each band its own `aoc` budget. Works inside the shipped model, but it
  doubles the roster and `aoc` still cannot vary *within* a band.
- **Raising `chance`/`aoc` globally on the existing cave rows.** One
  number and no new machinery, but it raises the pressure at −120 as much
  as at −1800 and it spends the budget the WP6 audit measured.

Also settled while deciding: the pulse's shallow half reuses the existing
cave families, so **the depth work package ships without a single new
mob**, and the ABM cave rows stay untouched as ambient cave life.

**Still open** (content, blocks nothing that has started):

- **Placement geometry** — the distance band from the player, the
  line-of-sight rule, whether the target must be a solid-adjacent air
  node, and what happens when no legal position exists (skip, or widen
  the search).
- **The servant roster below −1000** — see D10, which is the same list.

### A3 — Surface spawn rate, slightly up

**Decision:** decided 2026-08-08 → **landed in `biomes_mobs.md` §4**
(the factor, the two mechanism-driven exclusions, and the multiplied
`chance` column).

`chance` is the safe knob because `aoc` — the ceiling
`docs/research/wp6_spawn_budget.md` calibrated against the 100-player
target — still bounds the outcome: more attempts fill the same budget
faster, they do not raise it. Rejected: **raising `aoc`**, which moves
the ceiling itself and re-opens the budget audit rather than merely
re-running it.

### A4 — Does anything scale past level 60?

**Decision:** decided 2026-08-08 → no design-doc change needed; the
existing rule stands.

**60 stays the cap for regular mobs.** Depth beyond −1000 buys
*frequency*, not stats. The existing exceptions are untouched: elite
guards via `guard_level_at`, and fixed-level bosses via
`_grug_fixed_level` (the Kraken at 100).

This is what keeps `grug_core.difficulty_at`'s 0..1 contract intact — it is
normalised as `(level−1)/59` and read by several consumers, so a level 80
mob would have broken it. It also keeps the XP curve out of the balance
question: a level 60 player farming the deep band is paid in materials, not
experience, which is the intended shape. The consequence — that "too
dangerous even for a perfectly equipped level 60" has to come from the
**rate of arrival** — is what A2 then delivered.

---

## B. Renewable resources

### B5 — Ore respawn is removed

**Decision:** decided 2026-08-08 → **landed in `world.md` §2 R4**
(rewritten), with §4 and the README pulled along.

R4 existed so "a persistent world doesn't run dry". The depth economy of
group A solves that better: an effectively unbounded supply priced in
**danger and travel** instead of in waiting. Renewable ore actively worked
against the design — it caps the value of every mined material at the
respawn timer and turns mining into a rotation rather than an expedition.

The sole renewable exception is the bounded hard-protected mining-camp socket
mechanism in B6. Its surrounding camp construction remains mutable.

Implementation note, so nobody deletes the wrong thing: the machinery in
`mods/ITEMS/grug_nodes/ore_respawn.lua` is **re-scoped, not removed** — the
depleted-vein node and the `register_on_dignode` hook are what B6 needs.
The hook already carries a marker for exactly this kind of zone check.

**Known deviation until then**: the shipped code still runs the old
world-wide respawn, so it now contradicts the design docs (which are the
spec); re-hanging it onto mining camps belongs to **WP34**, and the same
note sits in `BACKLOG.md`'s readiness section.

### B6 — Renewable nodes use hard-protected functional sockets

**Decision:** decided 2026-08-08 → **landed in `world.md` §2 R4** (the
exception, with the counts, the tier rule and the interval) **and §4**
(the camp's role and the fact that the structure does not exist yet).

Renewable resources exist only in bounded hard-protected functional sockets.
The socket mechanism and its small functional anchor are immutable; the
surrounding camp walls, tents, fences and dressing remain ordinary mutable,
claim-excluded terrain. The POI/protection registry (`grug_core.add_poi`,
`world.md` §2 R1) records those two envelopes separately, so renewable nodes
cannot be privatized without turning the whole camp shell indestructible.

Scoped to **mining camps only** in the MVP. Rejected: opening the
exception to every POI kind at once — the owner's own later idea (a gem
block on a jungle-temple altar) is exactly the sort of thing that should
wait until one structure has proven the shape. The long respawn window
was chosen against the shipped 15–30 min because a handful of nodes at a
guarded destination is a different object from a vein under every hill: a
camp should be worth a trip every few sessions, never a rotation.

Mining camps still have to be **built** — `world.md` §4 had named them
only as a *role* an outpost can carry. WP13 owns the mutable structure,
garrison and bounded functional-anchor/socket footprints; WP34 owns the
respawn mechanic that runs inside those sockets.

---

## D. The T6 band as endgame content

### D10 — What is down there below −1000: the roster and the environments

**Decision:** decided 2026-08-08 → **landed in `world.md` §4c** (the
band's role, the lava-lake mechanism, and no apex boss in the MVP) and
**`items_crafting.md` §5** (no drop layer of its own), recorded in §10.3
D16.

**Lava lakes** are a `register_on_generated` VoxelManip pass in
`grug_mapgen/structures.lua` plus cheap `ore_type = "blob"` lava pockets
for ambience. Rejected: a **deep biome** — the six strata are stratum
ores registered last and convert `default:stone` wholesale, so a biome's
own `node_stone` would be overwritten and only its cave/deco layer would
survive; **blobs alone** — no shape control, so pockets rather than lakes
with a surface and a shore; **schematics** — the right tool for anything
with walls, and still the right tool later, but not for terrain.

**No apex boss of its own in the MVP.** §4b's apex bosses are
deliberately *visible* outdoor carrots — the Mountain Wyrm is seen at
level 8 and fought at 50 — and a boss behind a T6 pickaxe is the exact
opposite of that, so it is not the same design object under a different
sky. Authoring the zone and its boss at once would mean inventing both
against nothing; the lair/hoard/arena tech is generic and waits.

**No gear drops.** The depth pays in raw materials only, which keeps §0's
promise that the best items come from crafting and hard bosses intact.

**Still open**: the **servant roster** below −1000 — which families live
down there, their models and their drop tables. A2 already decided that
they are the pulse's own set (one mechanism, one accounting) rather than
a second place-bound spawn source, and that the shallow half of the pulse
reuses existing mobs, so this is content on top of a shipped mechanic
rather than a blocker underneath it.

---

## Status summary

| # | Question | State |
|---|---|---|
| A1 | Depth level curve | ~~open~~ decided 2026-08-08 → `combat_stats.md` §3 |
| A2 | Phase-in spawn pressure | ~~open~~ decided 2026-08-08 → `biomes_mobs.md` §4.1; **placement geometry + servant roster still open** |
| A3 | Surface spawn rate | ~~open~~ decided 2026-08-08 → `biomes_mobs.md` §4 |
| A4 | Anything past level 60? | ~~open~~ decided 2026-08-08 (no; depth buys frequency, not stats) |
| B5 | Ore respawn removed | ~~open~~ decided 2026-08-08 → `world.md` §2 R4 |
| B6 | Renewable nodes: scope, counts, interval | ~~open~~ decided 2026-08-08 → `world.md` §2 R4 / §4 (camps only; the structure is WP13's) |
| D10 | The T6 band's content | ~~open~~ decided 2026-08-08 → `world.md` §4c, `items_crafting.md` §5; **the servant roster still open** |

**Implementation**: `BACKLOG.md` **WP34 — Depth economy** carries the
mechanics half of A2/A3/B5/B6/D10; WP13 owns the mining camps as a
structure.

## Source: docs/design/biomes_mobs.md, former section 4 calibration

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
**[docs/research/wp6_spawn_budget.md](../../research/wp6_spawn_budget.md)**.

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

