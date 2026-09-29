# Round 24 Lane B — underground fill

Contract: [Round 24 plan](../../docs/planning/round24-mining-underground-mobs-plan.md),
rulings 9–15. Design text: `docs/design/world_zones.md` §7 ("Terrain fill",
"Decorative nests").

## Portable fixture (main correctness proof)

```sh
luajit tools/r24_fill/micro.lua "$PWD"
```

`fixture.lua` loads the production seams of `wp40/r6_settlement.lua` and
`wp40/r7_native.lua` (fake `core`, LuaJIT only; mapgen work runs no PUC) and
checks:

1. the fill predicate `r24_fill_stone` (R5 opcode-27 stone written into
   native void and untouched since; skin, filler, anchor-grade and
   foundation fills, native stone and ores are not fill);
2. the P8 resource-host base rule `r24_resource_host_base` (native hosts keep
   the former rule; fill stone hosts only the `default:stone` tier; claimed
   voxels keep their base; layer rock is no host);
3. the shallow strata in fill: a column whose first 40 nodes are fill gets
   exactly the bands it gets over native stone; steep and excluded columns
   stay bare; the former native-only rule leaves fill bare;
4. the mountain-interior layers: writes only to fill 41+ below the surface,
   only palette rock, gravel or dirt; interior stone share (measured
   88.7 %); smooth column offset (neighbour step ≤ 1, range ±5); identical
   result for 4 horizontal and 2 vertical owner splits; horizontal
   continuity; pockets inside their 16³ cell; seed and zone dependence; a
   known-answer digest of the layer writes of one synthetic mountain owner;
5. the native allowlist: nine ores in registration order (gravel blob, five
   tier strata, three decorative nests), nest hosts taken from the stratum
   rows, the first seven canonical rows byte-identical to the former digest
   `c29c9c6c…` (after the Lane A rename), and the new pinned digest.

`R24_PRINT_KAT=1` prints the layer digest without enforcing it (use after a
deliberate rule change, then update `LAYER_KAT`).

## Engine runs (`engine/`)

Receipt with the numbers and renders:
[round24-underground-fill](../../docs/research/round24-underground-fill/README.md).

```sh
GAME_REPO=<tree> SEED=10536739806879207652 OUT=<dir> \
  BOXES="time1:-1360:1000:-1201:1159:-40:239;cliff:-1470:1050:-1400:1120:120:215;section:-1420:1052:-1180:1067:-40:225" \
  tools/r24_fill/engine/run.sh 256 290 900
python3 tools/r24_fill/engine/coal_table.py after <dir>/server.log
python3 tools/r24_fill/engine/timing.py <before>/server.log <after>/server.log
tools/r24_fill/engine/render.sh <dir> after <png dir>
```

- `probe/coalprobe` is the archived Round 24 coal probe
  (`~/projects/grudgelands-orchestration/r24/coal-probe/`) plus an optional
  planner scan for high terrain and steep drops (`SCAN=true`) and a stage that
  emerges and dumps the `BOXES` (`name:x0:z0:x1:z1:y0:y1`; names starting
  with `time` are emerged only) after the coal analysis.
- `make_patch.py <tree>` is the archived disposable instrumentation patch plus
  one `[r24t]` line per generated chunk: wall and process-CPU microseconds of
  planner slice + writer and the native-v7 heightmap range.
- `GAME_REPO` selects the staged game: the branch, or `git archive main` in a
  scratch directory for the before run. The launcher is that tree's
  `tools/luanti_headless.sh`.
- `analyze.py` is the archived full report; `coal_table.py` the short table;
  `interior_share.py` the mountain-interior shares of a dump.
- `evidence/`: gzipped server logs of the before run (main 7d74c3e5, seed 1),
  the final after run (seed 1) and the seed-2 after run, `coal.txt`,
  `timing.txt`.

### Round 24 B2 additions

- The fixture also checks the cliff rules (native and fill cliff: layers in
  the top 40 of steep columns only, rock nests in ordinary columns, nothing in
  excluded columns, no loose pockets near the surface, ores and bands
  untouched; known answer `CLIFF_KAT`) and the output identity of the P8
  speedups (frontier minimum against the heap sort; old and new vein growth
  on a replica of the P8 loop with the real digests and budget).
- `make_patch.py` also logs `[r24d]`: a content digest (node names and param2)
  of every generated owner after the writer; `digests.py A B` compares two
  runs chunk by chunk.
- `face_share.py DUMP` gives the material shares of exposed side faces;
  `native_cliff.lua` builds a synthetic native cliff through the production
  passes; `render_cliffs.sh` renders the B2 cliff pairs.
- `evidence/b2.txt` and `evidence/b2-*.server.log.gz`: the three B2 runs
  (main a14a9dc6, speedups 950eb26e, cliffs ffbd097d).
