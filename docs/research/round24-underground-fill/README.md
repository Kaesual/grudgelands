# Round 24 Lane B — underground fill: engine evidence

Contract: [Round 24 plan](../../planning/round24-mining-underground-mobs-plan.md),
rulings 9–15. Rule text: `docs/design/world_zones.md` §7 ("Terrain fill",
"Decorative nests"). Tooling and logs: `tools/r24_fill/` (portable fixture,
`engine/` probe and scripts, `evidence/`).

All runs used `tools/luanti_headless.sh` (isolated user path, `LC_ALL=C`,
idle scheduling), one emerge thread, normal shutdown by the probe. "Before" is
main at 7d74c3e5 (Lane A merged, no Lane B); "after" is branch
`r24-lane-b-fill`. The before run reproduces the archived baseline
(`~/projects/grudgelands-orchestration/r24/coal-probe/`, runs 2 and 3) exactly.

## Coal near the Orc start

Region x −256…256, z 2294…2806, y −112…surface, columns outside towns; ore
per its denominator relative to host rock (stone plus the five T1 ores), by
depth below the actual ground top (archived `analyze.py` arithmetic,
`tools/r24_fill/engine/coal_table.py`). Target 1.0.

| Seed | Run | 1–4 | 5–8 | 9–16 | 17–32 | 33–64 | 65+ |
|---|---|---|---|---|---|---|---|
| 10536739806879207652 | before | 0.23 | 0.37 | 0.26 | 0.49 | 0.85 | 1.00 |
| 10536739806879207652 | after | 0.83 | **1.05** | **0.90** | 0.94 | 0.96 | 1.00 |
| 4242424242 | before (archived) | 0.06 | 0.12 | 0.10 | 0.20 | 0.70 | 0.99 |
| 4242424242 | after | 0.86 | **1.00** | **0.92** | 0.94 | 0.97 | 0.99 |

Iron, copper, tin and quartz follow coal (`evidence/coal.txt`). The small
remaining gap near the surface is probably stone that stays no host by the
unchanged rules (surface skin, road and anchor-grade fill); not measured
separately.

Tunnel simulation (2000 random 1×2×50 tunnels, floor depth 3–10, open
columns): coal dug per tunnel 0.35 → 0.88 (flat) and 0.39 → 1.08 (following
the ground), seed 1; 0.12 → 0.89 and 0.17 → 1.07, seed 2. Share of tunnels
that dig no coal 84 % → 64 % and 83 % → 56 % (seed 1), 94 % → 63 % and
92 % → 56 % (seed 2); with the exposed faces counted, a tunnel sees 3.4–4.3
coal on average (before 1.4–1.5 and 0.5–0.6).

## Mountain interior

Blackwind Rise (blight / bone forest), x −1420…−1180, z 1052…1067: surface
up to y 220, native v7 at most y 45 in these chunks (heightmap in the
`[r24t]` lines), so everything above is fill. Interior (above y 45 and 41+
below the column top) of the section dump:

| | stone | T1 ores | granite | basalt | slate | desert stone / sandstone | dirt / gravel |
|---|---|---|---|---|---|---|---|
| before | 100 % | 0 | 0 | 0 | 0 | 0 | 0 |
| after | 80.7 % | 4.4 % | 6.1 % | 4.9 % | 3.1 % | 0.5 % | 0.35 % |

(The synthetic fixture mountain measured 88.7 % stone; the real one draws a
few more slabs with layers. The desert stone and sandstone come from a
savanna column group inside the section.)

## Mapgen time

Lua planner slice + writer per chunk (`[r24t]`, CPU time of the emerge
process), the same chunks before and after (`evidence/timing.txt`):

| Chunks | Before | After | Change |
|---|---|---|---|
| Orc start region, 147 | 78.97 s | 78.26 s | −0.9 % |
| Mountain boxes, 52 | 24.22 s | 29.16 s | **+20.4 %** |
| of which the all-fill layer y 48…127, 11 | 4.65 s | 8.75 s | **+88 %** |

**Mountain chunks whose volume is mostly fill are clearly slower.** Such a
chunk now costs 0.80 s instead of 0.42 s, close to a chunk of native stone
(0.69 s at y −112 in the same run), because the resource pass now has hosts
in the fill (ruling 10). The layer pass itself is small: the portable
fixture measures 56 ns per interior fill voxel, about 30 ms for an all-fill
chunk. Chunks with shallow fill (the Orc region) are unchanged.

## Renders (`tools/r24_fill/engine/render.sh`)

- `mountain-section-before.png` / `-after.png`: the mountain cut open along
  z = 1052 (sw view). Before: uniform stone above native v7. After: bands
  under the flanks, horizontal layers (granite, basalt, slate) through the
  interior, ore specks, pockets; native v7 below with its gravel blobs.
- `mountain-tunnel-before.png` / `-after.png`: a window of the interior
  (x −1350…−1250, y 80…150) with a 3×4 tunnel cut along x into its front
  face; the flat top is a horizontal cut at y 150.
- `fill-cliff-before.png` / `-after.png`: a 45-node fill cliff (x −1470…−1400,
  z 1050…1120, y 120…215; native v7 ≤ y 45 there), ne view. **The cliff face
  stays plain stone**: steep columns skip the bands (Round 22), and layers
  start 41 below each column's own top, deeper than this face reaches. The
  box's right-hand side is a cut, not terrain; bands show there because those
  columns are not steep. Whether cliffs should show layers is open for the
  user. (Decided afterwards: Round 24 B2 below.)

## Round 24 B2: cliffs, rock nests, speedups

User rulings after Lane B: layers break through steep faces; rare rock nests
join the lattice; three output-identical speedups from the independent review.
Rules: `docs/design/world_zones.md` §7 "Cliffs and near-surface nests". Three
engine runs, seed 10536739806879207652, the Lane B boxes plus the coastal
cliff box (x −600…−520, z 2470…2560); main a14a9dc6, speedups 950eb26e,
cliffs ffbd097d; numbers in `tools/r24_fill/evidence/b2.txt`.

**Speedups are output-identical.** (a) The frontier rank digest is memoized
per vein, (b) the next vein node is the linear minimum under the same strict
total order instead of the head of a heap sort, (c) the layer pass tests the
cheap fill condition before the layer material. Portable: the frontier
minimum equals the heap sort on 3000 random frontiers, and a replica of the
P8 loop with the real digests, budget and root draw gives identical
placement digests with the old and new vein growth on two owners (5766 and
3383 placements; rank digests 69339 → 20262); the layer known answer is
unchanged by (c). Engine: all 218 chunks generated by both runs have
identical content digests (node names and param2 of the owner after the
writer, `[r24d]` lines). The census copy of the P8 loop has no runner since
Round 22; it received the same change.

**Lua mapgen time** (process CPU, same chunks):

| Chunks | main | speedups | cliffs | main → cliffs |
|---|---|---|---|---|
| Orc start region, 147 | 81.24 s | 65.51 s | 65.06 s | −19.9 % |
| Mountain boxes, 52 | 31.96 s | 24.00 s | 25.16 s | −21.3 % |
| of which all-fill layer y 48…127, 11 | 9.36 s | 6.43 s | 7.23 s | −22.7 % |

The cliff rules cost about 5 % on the mountain chunks and nothing in the Orc
region; the speedups more than pay for them. Coal near the Orc start is
unchanged within noise (5–16 band 1.05 / 0.89 against 1.05 / 0.90).

**Cliff faces** (exposed side-face voxels at least 3 below their column top,
`engine/face_share.py`):

| Cliff | stone before | stone after | layer rock after |
|---|---|---|---|
| 45-node fill cliff (engine, x −1470…−1400) | 97.5 % (+2.5 % ores) | 91.5 % (+1.6 % ores) | 6.9 % (basalt, slate, granite) |
| 70-node native cliff (synthetic, `native_cliff.lua`) | 98.3 % (+1.7 % coal) | 93.5 % (+1.7 % coal) | 4.8 % (basalt, slate) |

Renders (real Lane C textures):

- `b2-fill-cliff-before.png` / `-after.png`: the same 45-node fill cliff as
  above; thin basalt and slate bands now cross the stepped face. The basalt
  texture is dark and reads with little contrast in this view.
- `b2-native-cliff-before.png` / `-after.png`: a synthetic native-stone cliff
  (pine hills, plateau y ~112 over ground y ~42, three steep columns wide)
  built by the production strata and layer passes (`native_cliff.lua`); the
  box's front cuts show the ordinary bands of the non-steep columns. The run
  budget did not leave room for a real native cliff: the coastal cliff box
  turned out not to be steep by the Round 22 rule (it exempts shores and
  the badlands), so its face keeps the ordinary depth-relative bands before
  and after.
