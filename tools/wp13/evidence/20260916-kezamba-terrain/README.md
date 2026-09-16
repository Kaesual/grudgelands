# WP13 wave 3, Lane K: Kezamba terrain and crops

Branch `wp13-w3-kezamba-terrain`, rebased onto `1f5a2c32` (the Lane S merge,
which also carries P, F and C); written against the wave-2 merge `f37a0c5b`
and re-verified whole on the merged tree -- section 8.12 of the research note
says what the rebase moved and what it did not. The package
is written up in **`docs/research/wp13-kezamba.md` section 8**; this directory
is the evidence behind every number in it, re-taken after the independent review
and the fix round of 2026-09-16 (§8.3b: the apron's lake cone was rebuilt on the
reach's densified sample discs, which is 1-Lipschitz by construction where the
first two formulations only claimed to be).

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
| `measurements/walls-after-9-seeds.txt` | the same tool on this branch: the lake cone's own worst 4-neighbour step **3** with **0** live prune edges, pad face **3** on all nine seeds, worst land wall 8 to 11, and **0** over-step faces the apron is the high side of, on every seed. PASS |
| `measurements/cone-formulations.txt` | the three forms the lake cone took and what each measured, which is the fix round's own before/after |
| `measurements/lake-rim-before.txt` / `-after.txt` | a 29 x 25 window on the cenote's south shore, node by node: a two-column rim at 65 over ground at 37, then a flight of ten three-node steps |
| `measurements/capital-fields-before.txt` / `-after.txt` | one SHA-256 per capital over its whole +-250 terrain-and-water field, three seeds. **15 of the 18 rows are byte-identical**; the three that move are Kezamba's |
| `measurements/capital-terrain-fixture-after.txt` | the walkability fixture, all six capitals, both gate seeds. Ten of twelve rows byte-identical; Kezamba's two moved and its ceiling was re-taken |
| `measurements/lots-check-after.txt` | 52 of 52 lots legal on nine seeds |
| `measurements/lots-walk-after.txt` | every lot reachable on nine seeds, worst kerb face 3 against a skirt of 6 |
| `measurements/lots-gates-after.txt` | all four gates on nine seeds: step 0, nothing floating, `kezamba_ramp` rebuilds nothing |
| `measurements/lots-repair.txt` | the one lot the terrain moved, and where `repair` put it, both rounds |
| `measurements/totem-f2-candidates-*.txt` | why it had to shrink: twelve legal reach-11 centres in the whole totem band, the same twelve before the apron, 39 at reach 8 |
| `mutations.txt` | the three crop mutations, each with the assertion that fires; the fourth (the apron itself) is `measurements/walls-before-9-seeds.txt` |
| `kat/` | the KAT under both interpreters (identical), the `--walls` run, the interpreter pair |
| `engine/full-<seed>/` | three `full` boots: both gate seeds and the user's world seed |
| `measurements/capital-fields-base-1f5a2c32.txt` | the same six digests on the rebase target itself, which is what says neither P nor S moved any capital's terrain |
| `renders/` | the plateau from above before beside after, the west pad edge in section, and the two fields with their real node textures |
| `static/static.txt` | parser, SETGLOBAL, the five plain-5.1 sweeps, the fresh-server audit |
| `measurements/capital-lots-refusal.txt` | `tools/wp13/capital_lots.lua` refuses this capital by design -- "the composition of kezamba publishes no quadrants module", because its districts are pinned to the ground rather than permuted with the seed. `kezamba_lots.lua` is its predicate and asks the same four questions on nine seeds instead of two |
| `measurements/plot-footprints.txt` | every plot's built extent against its own lot, tightest last -- the check `totem_f2` (reach 5, carrying `totem_posts`) has to pass after two repairs |
| `renders/cenote-crossing-with-lane-s-streets.png` | the crossing over the cenote with Lane S's carriageway and junction plateau in place of the boardwalk this lane shipped |
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

These are the boots of the LANE S REBASE round, on the merged tree. The earlier
rounds' boots are superseded and their directories are gone with them; the note
carries their numbers.

| seed | mode | chunks | steady mean | control | worst plot fall | sockets | ERROR | ModError | audit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `531802985935182545` | full | 66 | 0.491 s | 2.283 s | 5 | 262 | 0 | 0 | 0 |
| `15912857179583385436` | full | 66 | 0.471 s | 2.402 s | 5 | 262 | 0 | 0 | 0 |

The gate-seed boot IS the re-freeze: it was run through
`refreeze_avenue.sh`, which is also how that script's own two fix-round
corrections were checked -- it took its port from `WP13_CAPITAL_PORT` and
stamped `main=1f5a2c32`, the merge base.

**The Highcourt terrain-audit warning is gone.** The user's-seed boot of the fix
round logged `WP13 highcourt: the plot martial_wood_yard ... rise 10 against a
clear of 8`; on the merged tree that boot logs no finding at all, because Lane P
moved Highcourt's thirteen lots that nine worlds refuse. It was never this
lane's and it is now nobody's.

`engine/full-15912857179583385436/findings.txt` carries the one load-time
terrain-audit warning any of these boots produced, and it is HIGHCOURT'S
`martial_wood_yard` -- the round-1 playtest finding
`tools/wp13/capital_lots.lua`'s own header records, on the seed it was found on.
Highcourt's whole terrain field is byte-identical on that seed
(`measurements/capital-fields-*.txt`), so it is not this lane's. Kezamba's own
count is 0 on all three.

`core_road_digest = 525b6eb54b7ea5c09f52ce7fd7faed187dd315bb9579ea0959e42c3f6a2e9c57`
on both. It read `eafdce92...` -- the value section 6d recorded before this lane
existed -- on every boot of this lane's own two apron versions, which is what
says **the built civic core did not move for the apron**; what moved it is Lane
S rebuilding the streets that cross the core, since the digest reads back ROAD
cells. The avenue digest did, because the road walks the ground, and is
re-frozen at
`tools/wp13/evidence/20260915-capital-terrain/kezamba/avenue-digest-531802985935182545.txt`.

`engine/field-531802985935182545/engine-vs-planner.txt` carries the other check
the field boot is for: the running server's own height field over all 251 001
columns is byte-identical to the offline planner's, so every offline number in
this directory is the engine's answer too.
