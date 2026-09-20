# Final capital overlay attribution

The cadence correction is source-frozen at `ccd10d965c5ef5235f217f9b0312a03640d7bbcb`
and integrated for the final six-capital engine witnesses at
`8dd1c8e463a13ccc356cdade123875471b398707`. This addendum changes evidence and
analysis tools only. No historical expected hash has been replaced.

## Outcome

The fail-closed comparator reproduces all **18 historical SHA/count pairs**,
checks every current authored palette cell against the final engine, and
classifies every changed coordinate: **zero unexplained coordinates**.
All four outer gates and all four corners match the frozen expectations.
Three ramparts match; Highcourt's 267 changed rampart coordinates are an
independently reproduced, pre-CAP terrain change (9107→9063 palette cells).

| Region | Changed coordinates | Accepted inner change | Earlier world change |
| --- | ---: | ---: | ---: |
| Highcourt avenue | 863 | 522 | 341 |
| Highcourt rampart | 267 | 0 | 267 |
| Dur Brannoc avenue | 430 | 430 | 0 |
| Gor Drazhak avenue | 410 | 410 | 0 |
| Nhal Veyr avenue | 430 | 430 | 0 |
| Lethariel avenue | 983 | 356 | 627 |
| Kezamba avenue | 533 | 60 | 473 |

The other eleven regions have no changed coordinates. Exact old/new hashes,
counts and every coordinate/value/classification are committed under
`evidence/attribution/results/`. An old/new count is not used as a substitute
for node equality. R10 source differences against pre-CAP remain wholly inside
x41..49 of the east avenue (Keza46..49); all twelve authored outer regions
are byte-identical to pre-CAP. The phase fix preserves the outer curtain at 256,
accepted precinct 48, inner gate 49 and applicable avenue endpoint 50.

## Exact old source and source projection

The frozen expectation labels name `dfb32cd5`, but its source bytes predate
streets-r4. **All four production files actually listed** in that package's
retained `files.sha256` match `6cd971b025f68885336ce36cb9a126e9fcafac36`.
The receipt lists their exact hashes; it does not claim an unrecorded complete
historical source manifest existed. The actual historical game snapshot is
bound separately, including all shipped root configuration files.

`project.lua` invokes the real zones/height factory, capital builders,
settlement prepare/config and clipped settlement writer on the engine owner
grid, for the exact original dump boxes and scan order. Its historical rows
reproduce fourteen frozen labels directly. It supplies no native-v7 cells.
Gor and Lethariel palette names also occur in ground outside authored cells;
therefore their raw engine evidence is required rather than treating palette
membership as ownership.

The pre-CAP source is `7e2bc1f0cae985db65a02cdd85fc71d969017024`.
The earlier terrain changes are evaluated **before** the accepted CAP delta.
A controlled Highcourt replay holds the historical capital builders and
settlement adapter fixed while using pre-CAP world/terrain dependencies. It
exactly reproduces all four pre-CAP projections, including every one of the 267
rampart changes and the earlier avenue change. Construction: start from the
7e2 MAPGEN tree and `tools/wp40/r6/common.lua`; replace `wp13/` and
`wp40/r7_settlement.lua` with their 6cd counterparts; run `project.lua` unchanged.
Both source commits and the resulting four row sets are retained.

Lethariel's 627 earlier-world changes comprise 222 changes in the actual
historical→pre-CAP authored projection plus 405 silver-litter surface changes.
For every latter coordinate, the old and new node are checked against the
respective real `terrain_height_at` result at that column. Every old/new
surface height differs; every present node is exactly silver litter at that
height. `height_columns.lua` and its exact 5525-column input/outputs are bound.

Gor's 78 palette-background changes are not silently grouped with terrain:
full old/new writer masks and full engine rows prove 52 dry-dirt cells covered
by the moved non-palette castle-stone foundation and 26 uncovered cells. All
are in the accepted inner band. Every written foundation node is checked
against the engine; every uncovered counterpart is actual dry dirt.

## Historical engine witnesses and failed attempts

Two original 6cd full probes ran concurrently at idle priority, in fresh
scratch worlds with isolated user/XDG paths and a 900-second timeout. The first
staging attempt omitted tracked `minetest.conf` and correctly failed the
`mgv7_dungeon_ymax` authority check before generation. These failure logs remain
in the evidence. The retry supplied the exact 6cd file; all shipped root files
were checked byte-for-byte (menu/textures are absent in that commit).

The retries used ports 31872/31873, completed 72/112 requested owners, and both
returned exit 0/errors 0/complete 1. Every old overlay hash matched. Avenue
ignored/unheld/emerge-trouble/retries were all 0; held counts were 90/126.
Recorded chunk-work totals were 109.20/110.66 seconds respectively; these are
summed chunk timings, not elapsed-time or comparative-performance claims.
The slow first two cold chunks prompted a proposal to reduce the probe. Both
runs naturally finished before the guarded stop command could signal them.
**No process was signalled, no reduced harness was built or run, and no
production writer, terrain/cave policy or source pin was bypassed.**

A prior Python counterfactual using only current ground extras outside every
historical write (including air) reproduced Gor's two outer hashes, but failed
both avenue hashes. Those failures are preserved; the successful historical
engine rows supersede them for avenue attribution. No failed reconstruction is
used as the old side of the final comparison.

## Reproduction and gates

Run the committed comparator from the repository root:

```sh
python3 tools/r10_capital_phase/verify_attribution.py . \
  tools/r10_capital_phase/evidence/attribution /tmp/capital-attribution-check
```

It asserts all old hashes/counts, authored current cells, immutable outer
geometry, inner bounds, exact surface-height and non-palette foundation rules,
and the Highcourt controlled replay. It fails on any unclassified coordinate.
The current-engine row inputs are filtered copies of the coordinator's v3
readbacks; receipts bind the original full files and transformation. Historical
Gor/Lethariel full avenue readbacks are also retained. Deterministic gzip keeps
these immutable artifacts compact; `artifact-sha256.txt` binds all evidence and
helper bytes.

Source review for the correction was coordinator-reported CLEAN. Full WP13
LuaJIT and the final strengthened integration fixture passed; parser, SETGLOBAL
and five sweeps passed. No author PUC runtime was run. Independent review of
this attribution and the coordinator's final compact interpreter pair remain
pending at this evidence freeze. GUI playtesting is separate.
