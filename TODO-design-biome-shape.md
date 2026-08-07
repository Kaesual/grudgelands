# TODO — Biome shape: capital biomes & natural transitions

Open design questions raised by the 2026-08-07 runtime test. Everything
below is **verified against the engine source and against 400 random world
seeds** (research pass 2026-08-07); what is missing is the decision.

Once decided: fold into `docs/design/world.md` §1/§3 and
`docs/design/biomes_mobs.md` §1.3, then delete this file.

## 1. The two problems

**P1 — a capital does not sit in its own race biome.** `world.md` §3 says
each capital sits "centrally in the race's own biome". Nothing enforces it.
On the tested seed: human → `grug_deep_forest`, dwarf → `grug_meadows`
(instead of pine hills), undead → `grug_savanna`, troll → `grug_savanna`.
Only orc and elf were correct. Measured over 400 seeds with the shipped
registrations, the intended biome wins at the anchor column in
60 / 22 / 19 / 100 / 48 / 61 % of seeds (human / dwarf / elf / orc /
undead / troll).

**P2 — many biome borders are dead-straight, axis-aligned lines.**
Measured: **~13 350 nodes** of straight border where the ground node
changes, plus ~1 340 nodes where only decorations change.

## 2. Verified mechanics (do not re-derive)

- **Cuboid faces are hard.** `BiomeGenOriginal::calcBiomeFromNoise`
  (`src/mapgen/mg_biome.cpp:238-244`) filters candidates by `min_pos`/
  `max_pos` on the raw integer position — no noise, no jitter, evaluated
  **before** the climate voronoi. `vertical_blend` softens only the y
  bound; there is no horizontal analogue. A cuboid face where the winner
  changes is therefore a single-node-sharp straight line, by construction.
- **Climate blend noise cannot touch a cuboid face**, because the cuboid
  test never reads heat/humidity. It only softens *voronoi* borders —
  which is ~20 % of our border length.
- **Blend noise is free.** All four climate noises are computed every
  chunk regardless (`mg_biome.cpp:181-194`); scale/spread change no work.
  Current values are engine defaults (scale 1.5, spread 8) — we never set
  them. Measured effect: fringe width ≈ 12.5 × scale nodes; `spread` sets
  the grain (8 = per-node dither, ≥24 = coherent fingers).
- **Why wide overlaps did not help.** §1.3 asks for 400–500 node overlaps
  and most pairs have them — but an overlap only produces a mosaic if
  **both** climate points are reachable by the local noise. Our field has
  mean 60.9 / 48.8 and σ 14.7 / 16.8, so outlier points never win where
  they compete and the border collapses onto the cuboid face. Worst case:
  `pine_hills` ↔ `crags` have the full 500-node overlap and still produce
  the single worst line in the world (1 435 nodes at x = −1250, 98.3 % of
  that face), because `crags` (10/30) is −3.5σ / −1.1σ from the mean.
  Same for `elf_forest` ↔ `deep_forest` (750 overlap, 1 172-node line).
- **The centre band overruns the side capitals.** `grug_meadows` /
  `grug_savanna` span x −700..700, i.e. 150 nodes past the side capitals
  at x = ±550. This — not a wild biome — is what beats dwarf, elf, undead
  and troll. Carving only the *wild* cuboids cannot fix those four.
- **Sibling registrations are legal and cheap.** Two biomes may share a
  climate point; only the NAME must be unique (`objdef.cpp:31-32`).
  Tie-break is registration order (`mg_biome.cpp:253` uses strict `<`).
  Landmine: `core.register_biome` returns nil **silently** on a duplicate
  name, and decoration/ore defs whose biome list does not resolve become
  world-wide (`l_mapgen.cpp:412-455`, `mg_decoration.cpp:193-197`) — every
  new sibling must be added to the deco lists in
  `mods/MAPGEN/grug_mapgen/decorations.lua` and to `ores.lua:66-68`.
- **Fresh world**: only the climate-noise change needs one (`override_meta`
  rewrites `map_meta.txt`, seams world-wide). Cuboid, climate-point,
  weight and new-biome edits take effect in newly generated chunks.

## 3. Verified solution for P1 (geometry, not point tuning)

Point tuning was tested and **rejected**: with spread 1000 over a
3000×1600 continent there are only ~5 independent large-octave samples per
continent, so the climate at a capital is effectively a coin flip of the
seed. The best case for tuning (all settled points collapsed onto the
noise mean) still scores **0 %** at four of six capitals. The engine's
`Biome::weight` knob tops out at 56–94 % and distorts shares everywhere
the biome is eligible. Geometry is a containment proof evaluated before
any noise is read, hence seed-robust.

The verified configuration ("carve + centre split"), **100 % at all six
capitals over 400 seeds, guaranteed over a radius R around each anchor**:

1. Push the four side wild cuboids out of the carve box:
   `bone_forest` / `crags` / `crags_snowy` `x_max` −750 → −801;
   `deep_jungle` `x_min` 750 → 801; `badlands` `z_min` 1100 → 1201.
2. Split `grug_deep_forest` into three registrations (back slab, front
   slab, east wing) — it is the only biome whose cuboid needs a hole in
   the *middle*, which one box cannot express. The east wing is what
   keeps the elf band covered.
3. Split the centre band: `grug_meadows` / `grug_savanna` x ±700 → ±349,
   and extend `pine_hills` / `blight` `x_max` −500 → −350 and
   `elf_forest` / `jungle_edge` `x_min` 500 → 350. **Mandatory together** —
   without the extension 3.01 % of the land has no eligible biome at all
   and generates as bare stone.

Guarantee radius: `R = min(CX − 550, 550 − S)` with CX = carve half-width,
S = centre split. Theoretical max is R = 274 (capitals are 550 apart).

| CX | S | R | carve box per continent | share of land |
|----|---|---|--------------------------|---------------|
| 800 | 350 | **200** | 1600 × 600 | ~20 % |
| 700 | 350 | 150 | 1400 × 600 | ~17 % |
| 645 | 350 | 95 | 1290 × 600 | ~16 % |

Note the "cost" is only a cost against `biomes_mobs.md` §1.4's *wild
patches near the core* flavour; it is exactly what `world.md` §1's
civilization gradient asks for ("safe core + inner ring carry the settled
race biomes"). The two documents disagree today; this decision settles it.

**Not covered by any carve**: `grug_swamp` (y 1..6) and `grug_beach`
(y 1..4) are universal, x/z-unlimited and would still win at a capital
whose terrain surface lands that low. A hard guarantee would need both
split into three z-slabs as well.

## 4. Options for P2 (natural transitions)

Priority order from the measurements:

1. **Move the outlier climate points inward** — the actual fix for the
   worst lines, because it lets the overlaps we already have become real
   mosaics. Candidates: `crags` (10,30) → ~(35,40), `badlands` (95,15) →
   ~(80,25); check `bone_forest` (15,45), `blight` (25,20),
   `deep_jungle` (90,90), `jungle_fringe` (85,85) too. Trade-off: the
   points were chosen for climate *character*; moving them changes biome
   shares and lets biomes contest terrain they currently never reach.
2. **Blend noise** `mg_biome_np_heat_blend` / `humidity_blend` =
   offset 0, **scale 4, spread 32**, octaves 2, persist 1.0 (keep seeds
   13 / 90003). Expected ~45-node fingering in ~32-node lobes, ~7.5 % of
   land reassigned near borders, no speckling, zero runtime cost.
   **Hard ceiling: scale 6** — the tightest same-continent point pair
   (`elf_forest` 70/60 ↔ `deep_forest` 60/75, separation 18.0) starts to
   salt-and-pepper above that. Requires a fresh world.
3. **Re-establish the wide centre↔side overlaps outside the carve box**
   by registering front/back slabs of `meadows` / `savanna` at the old
   x ±700 while the belt slab stays at ±349 (3 registrations each).
4. Low priority: `elf_forest` ↔ `jungle_fringe` (100-node overlap) and
   `deep_forest` ↔ `crags` (150) touch almost no land.

## 5. Decisions needed

- **D1** — carve half-width CX (and thus the guaranteed radius R).
- **D2** — move the outlier climate points inward? Which, how far?
- **D3** — blend noise scale/spread (accepting a fresh world).
- **D4** — front/back slabs for meadows/savanna to keep the wide overlaps
  outside the belt, or accept narrower overlaps there?
- **D5** — split swamp/beach as well, or accept that a low-lying capital
  can land in one?
