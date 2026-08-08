# biomecheck — audit a world's biome distribution without starting Luanti

Built 2026-08-08 during the runtime test that found the Throng continent
was 49.6 % one visual. Runs in **~0.4 s of CPU**, needs no engine, no world
load and takes no world lock (`map.sqlite` is opened read-only).

The point of this tool is that **the share table alone does not explain
"one biome everywhere"** — `diagnose.py`'s *eligible-visual monopoly count*
does. Use both.

## Files

| file | job | runtime |
|---|---|---|
| `noiselib.py` | `noise2d` / `noise2d_value` / `NoiseFractal2D` in float32 numpy, bit-exact against `src/noise.cpp` | — |
| `ref.c` | the same math compiled straight from the engine source; run once to prove bit-exactness (`gcc -o ref ref.c -lm`) | instant |
| `dump_biomes.lua` | luajit engine stub → loads the **real** `grug_core/init.lua` + `grug_mapgen/biomes.lua`, writes `biomes.csv` in registration order | 0.00 s |
| `model.py` | mgv7 base terrain + heat/humidity **incl. the blend noises** + `calcBiomeFromNoise` + the real ocean mask from `structures.lua` | — |
| `analyse.py` | shares per registration / per visible `node_top` / per band / per ring, x-strip overlap winners, flood-fill largest contiguous region, both continents | 0.37 s |
| `diagnose.py` | climate-point distance from the seed's field mean in units and σ, plus the **eligible-registration and eligible-visual counts per column** | ~0.4 s |
| `crossseed.py` | N seeds × 2 continents → share distribution, i.e. "bad luck vs. systematic" | 11 s / 30 seeds |
| `validate.py` | decodes real mapblocks from `map.sqlite` (SELECT only, v29/zstd) and compares surface `node_top` + height against the model | 0.30 s / 220 stacks |

## Procedure for a world

1. Read the seed and the four `mg_biome_np_*` blocks out of
   `<world>/map_meta.txt`; paste them into `model.py`'s `NP(...)` lines and
   set `WORLD_SEED_U64`. **The engine truncates the seed to `s32`** —
   `1181064378178512398` → `1580377614`.
2. `luajit dump_biomes.lua > biomes.csv` — always re-run; it reads the live
   `biomes.lua`, so a cuboid or climate-point edit is picked up for free.
   Run it **from this directory**: `biomes.csv` is a build artefact and the
   scripts look for it (and for each other) next to themselves. They used to
   carry absolute paths into the scratchpad of the session that wrote them,
   which died with it — fixed in WP36; do not reintroduce an absolute path.
3. `python3 analyse.py` — shares + largest contiguous region.
4. `python3 diagnose.py` — *why*: point distances and the monopoly count.
5. `python3 crossseed.py` — is it this seed or the design?
6. Only if you doubt the model: `python3 validate.py` against a real
   `map.sqlite`. Expect ~99 % on non-decoration ground tops; a lower number
   means a mod changed something the model does not know about.

Requirements: `luajit`, `python3` + `numpy`; optional `zstandard` (step 6)
and `gcc` (the bit-exactness proof).

## Gotchas — keep these in mind or the numbers lie

- The engine picks the biome at the **unmasked** mapgen heightmap y, not at
  the post-mask surface. Model the ocean mask only for "is this column
  land" and for the sand re-dress, **never** for the biome lookup.
- **`node_top` share ≠ registration share.** Fold siblings that share a top
  (`grug_deep_forest{,_front,_east}`, `grug_crags{,_snowy}`, and
  `grug_jungle_edge` / `grug_deep_jungle` / `grug_jungle_fringe`, which all
  three ship `default:dirt_with_rainforest_litter`) or the numbers will hide
  exactly the problem you are looking for.
- The **3D mountain noise is not modelled**: ~25 % of columns come out 3–15
  nodes too low, which loses `grug_crags_snowy` (needs y ≥ 80) and slightly
  over-counts swamp (y ≤ 6). Add it only if a y-threshold biome is the
  subject.
- Field statistics are **per seed**. Never write "the field mean is X" into
  a design doc without saying how many seeds it came from — that mistake is
  what this tool found in `biomes_mobs.md` §1.3.
