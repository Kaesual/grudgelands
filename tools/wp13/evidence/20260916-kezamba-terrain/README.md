# WP13 wave 3, Lane K: Kezamba terrain and crops

Branch `wp13-w3-kezamba-terrain`, on the wave-2 merge `f37a0c5b`. The package
is written up in **`docs/research/wp13-kezamba.md` section 8**; this directory
is the evidence behind every number in it.

It answers two findings from playtest 5 (2026-09-16), the user's words:

> "The capital core in Kezamba stands on an unnatural plateau, the terrain has
> no natural course there."

> "Fields in Kezamba grow 'Mossy Stone'? That cannot be right."

## What to run

```sh
# the terrain property, nine seeds, and the gate that owns the playtest finding
luajit tools/wp13/kezamba_water.lua . --walls

# the wet mask, the civic reference and the water surface, nine seeds
luajit tools/wp13/kezamba_water.lua . --verify

# the 52 lots: legality, walkability, the gate ramps -- nine seeds each
luajit tools/wp13/kezamba_lots.lua . check
luajit tools/wp13/kezamba_lots.lua . walk
luajit tools/wp13/kezamba_lots.lua . gates
luajit tools/wp13/kezamba_lots.lua . repair     # keeps every legal lot

# the composition, under both interpreters, byte-identical
luajit      -e 'io.write(dofile("tools/wp13/kezamba_kat.lua")("."))'
tools/bin/lua51 -e 'io.write(dofile("tools/wp13/kezamba_kat.lua")("."))'

# the walkability ceilings of all six capitals
luajit tools/wp13/capital_terrain_fixture.lua .

# the identity of every capital's whole terrain field, per seed
luajit tools/wp13/evidence/20260916-kezamba-terrain/capital_fields.lua . <seed>

# the interpreter pair
luajit          tools/wp13/final_micro.lua . <out.tsv> luajit
tools/bin/lua51 tools/wp13/final_micro.lua . <out.tsv> puc51

# the static gates
bash tools/wp13/evidence/20260916-kezamba-terrain/static.sh

# the engine, port block 31100-31199, one server at a time
WP13_CAPITAL_PORT=31100 nice -n 19 bash tools/wp13/run_capital.sh \
    /tmp/grug-w3-K-full-<seed> kezamba full <seed>
WP13_CAPITAL_PORT=31100 nice -n 19 bash tools/wp13/run_capital.sh \
    /tmp/grug-w3-K-field-<seed> kezamba field <seed>

# re-freeze the avenue digest from a real pass (the coordinator, after the
# Lane S rebase)
bash tools/wp13/evidence/20260916-kezamba-terrain/refreeze_avenue.sh [SEED]
```

## What is here

| path | what it is |
| --- | --- |
| `measurements/walls-before-9-seeds.txt` | `--walls` on **main's own `height.lua`**: the pad's face is 17 to 28 nodes and the worst land wall 27 to 39, FAIL on all nine seeds. It is both the BEFORE measurement and the mutation test for the apron -- the tool is this branch's, the terrain is `f37a0c5b`'s |
| `measurements/walls-after-9-seeds.txt` | the same tool on this branch: pad face **3** on all nine, worst land wall 8 to 11, PASS |
| `measurements/lake-rim-before.txt` / `-after.txt` | a 29 x 25 window on the cenote's south shore, node by node: a two-column rim at 65 over ground at 37, then a flight of ten three-node steps |
| `measurements/capital-fields-before.txt` / `-after.txt` | one SHA-256 per capital over its whole +-250 terrain-and-water field, three seeds. **15 of the 18 rows are byte-identical**; the three that move are Kezamba's |
| `measurements/capital-terrain-fixture-after.txt` | the walkability fixture, all six capitals, both gate seeds. Ten of twelve rows byte-identical; Kezamba's two moved and its ceiling was re-taken |
| `measurements/lots-check-after.txt` | 52 of 52 lots legal on nine seeds |
| `measurements/lots-walk-after.txt` | every lot reachable on nine seeds, worst kerb face 3 against a skirt of 6 |
| `measurements/lots-gates-after.txt` | all four gates on nine seeds: step 0, nothing floating, `kezamba_ramp` rebuilds nothing |
| `measurements/lots-repair.txt` | the one lot the terrain moved, and where `repair` put it |
| `measurements/totem-f2-candidates-*.txt` | why it had to shrink: twelve legal reach-11 centres in the whole totem band, the same twelve before the apron, 39 at reach 8 |
| `mutations.txt` | the three crop mutations, each with the assertion that fires; the fourth (the apron itself) is `measurements/walls-before-9-seeds.txt` |
| `kat/` | the KAT under both interpreters (identical), the `--walls` run, the interpreter pair |
| `engine/full-<seed>/` | three `full` boots: both gate seeds and the user's world seed |
| `engine/field-<seed>/` | the two `field` boots, the committed mask cross-check, and the proof that the engine's own height field equals the offline planner's to the byte |
| `renders/` | the plateau from above before beside after, the west pad edge in section, and the two fields with their real node textures |
| `static/static.txt` | parser, SETGLOBAL, the five plain-5.1 sweeps, the fresh-server audit |
| `measurements/capital-lots-refusal.txt` | `tools/wp13/capital_lots.lua` refuses this capital by design -- "the composition of kezamba publishes no quadrants module", because its districts are pinned to the ground rather than permuted with the seed. `kezamba_lots.lua` is its predicate and asks the same four questions on nine seeds instead of two |
| `capital_fields.lua` | the per-capital field digest tool (see above) |
| `refreeze_avenue.sh` | one command that re-takes the avenue digest from a clean engine pass |
| `static.sh` | the static gates |
| `files.sha256` | the sources this package changed |

## The engine passes

Port block 31100-31199, one headless server at a time, every boot under
`nice -n 19`, each under two minutes wall clock with seven WP13 lanes on the
box. Projection before the first one: the committed wave-2 evidence records
`full` boots of 58-67 capital mapchunks at a steady mean near 0.5 s plus a ~24 s
warm-up, so 3-8 minutes each was projected and 2 minutes was measured; nothing
came near the runner's own 1500 s timeout. `pgrep -af 'luanti.bin --server'`
showed no process on this block after every one.

| seed | mode | chunks | steady mean | control | worst plot fall | sockets | ERROR | ModError | audit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `531802985935182545` | full | 66 | 0.474 s | 2.494 s | 5 | 262 | 0 | 0 | 0 |
| `8675309` | full | 64 | 0.516 s | 2.599 s | 6 | 262 | 0 | 0 | 0 |
| `15912857179583385436` | full | 66 | 0.453 s | 2.349 s | 5 | 262 | 0 | 0 | 0 |
| `531802985935182545` | field | - | - | - | - | - | 0 | 0 | - |
| `8675309` | field | - | - | - | - | - | 0 | 0 | - |

`core_road_digest = eafdce922db68f98366c0da49823bfe9bb1e81d63328b6d2315a748af0203056`
on all three, which is the value section 6d of the research note recorded before
this lane: **the built civic core did not move.** The avenue digest did, because
the road walks the ground, and is re-frozen at
`tools/wp13/evidence/20260915-capital-terrain/kezamba/avenue-digest-531802985935182545.txt`.
