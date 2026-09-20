# Independent MAP-B review

## Verdict

**CLEAN SOURCE + BOUNDED ENGINE EVIDENCE — 0 Critical, 0 High, 0 Medium,
0 Low remaining.**

- Final candidate `02f37ec0318386fdf43525f4935dbbb8682f17b7`;
  production checkpoint `2bc6f33cc2572dee674def710f49b2f67057965c`;
  focused fix `55634810`; original integration base `4491c996`.
- Independent native GPT-5.6 Sol review. The reviewer supplied an earlier
  read-only dependency-seam recommendation but authored none of this candidate.
- The merged FARM candidate `806b0c0f` was already independently CLEAN. Root's
  six shared-fixture changes at `0c03af16` were separately independently CLEAN;
  their conclusions were checked for consistency here rather than treated as a
  substitute for reviewing the complete MAP-B composition.
- No Lua interpreter, PUC process or engine was run. The committed source hashes
  were verified against all 52 rows in `source-checkpoint/inputs.sha256`.

## Initial Medium — the frozen regression runner still has a real failing job (closed)

The candidate's own regression runner includes
`tools/wp40/r6/micro_kat.lua` as a required job
(`tools/r10_map_b/regressions.lua:9`) and asserts that every listed job passes
(`:23`). The frozen evidence instead records
`fail_content_ignore: required light context is ignore` after the fixture was
updated to include the production writer's required `default:stone` host
(`tools/r10_map_b/evidence/source-checkpoint/regressions-corrected-1.log:1`).
The checkpoint README accurately labels this failure as still under diagnosis
and does not claim it passed.

This is currently an unresolved acceptance/evidence defect. It may be a stale
synthetic light-context setup rather than a production bug, but that distinction
has not yet been proved on the frozen bytes. The narrow correction is to trace
the fixture's required-light halo and either repair its engine-shaped input with
an explicit negative mutation, or fix production if the same ignore context is
reachable there. Freeze one replacement LuaJIT regression record in which the
required job actually passes; do not remove the job, weaken the ignore guard or
relabel the preserved failure as success.

## Production and contract review

The load-order seam is coherent and cycle-free. `grug_nodes` registers the two
complete soil definitions and owns a fail-loud, bind-once callback closure before
synchronous R7 content construction. FARM binds real construct/timer callbacks
during ordinary mod loading, before engine callbacks can execute. Mapgen depends
on the lower registration owners and does not acquire a mapgen-to-FARM edge;
FARM's existing Cooking/Mobs/Mapgen chain is therefore not made cyclic. No
deferred R7 authority build, placeholder runtime callback or compatibility alias
was added. The one current-version every-load LBM remains the sole VM-soil timer
activation path.

The shared crop visual function returns fresh tables, preserves the 17-family / 
68-stage ART bindings and gives wild nodes only their independent drop, groups
and gathering authorization. Wild nodes do not inherit crop timers, growing or
attached-node groups, crop metadata, replaceability or flooding. Every harvest
item converts to two seeds through the existing universal FARM path; Ember Moss
alone retains the approved Alchemist authorizer. Salt Crust, Rock Salt, Frost
Melon and gathering Melon remain distinct identities. The accepted Mushroom and
Stormkelp endpoint additions are narrow and the original twelve P9G identities
remain in place.

The fifteen-row pure world catalog agrees with the design's named zones, level
or depth bands, logical biomes, actual supports, shore predicates and densities.
The writer uses exact-double-safe bounded integer mixing and scans cave Y only
when the current mapchunk intersects one of the two depth ranges. Surface writes
require final air, zero occupancy/opcode, authenticated support, level/zone and
shore conditions. Cave writes require actual original and final native air,
actual stone support, current owner bounds and the purpose-specific skin/
functional/foundation/housing guards. Reefs require actual coastal sea water,
depth 2–10, eligible natural bed, clear water-family cells and complete owner
containment; kelp alone requires sand and receives its bounded rooted-node
param2. There is no second VM commit, globalstep, ABM or global census.

The real content/manifest/writer arithmetic is closed: 84 accepted R6 rows plus
six cultural rows give 90 production names; 12 old P9G sources plus 22 new world
nodes give 34 successor names. Manifest, writer and anchor activation agree on
P9G 91–124, anchors 125–126 and settlement content 127+. Anchor base 124 is
derived from the live content table. Strict source pins include the complete
25-node natural-ground projection and world-rules digest. The decoded-template
tool proves the 692 shifted numeric references normalize to the prior 21-MTS /
84-rotation graph, so the name insertion is not presented as changed geometry.
The historical 157-file source roster remains unchanged and is covered by its
existing real-module execution receipt.

Authored fields now use real dry farming soil. The production FARM lifecycle
checks both touched positions before hydration or placement, preserves elapsed
wet progress through dry/reload transitions and activates VM-created soil via
the existing idempotent LBM. New ash and moss ground use already shipped media;
the updated media ledger identifies their original files, authorship chain and
licenses. No new bitmap or reference pin is introduced by MAP-B.

## Evidence assessed

- Registration evidence executes real shared definitions, FARM registration,
  all 17 lifecycle rows and all 15 wild definitions.
- Placement evidence executes the actual R7 content resolver and production
  world tail for 15 plants, seven reef variants and protection/host/band/shore/
  liquid/replay negatives.
- Writer evidence reaches the real R6 private transaction for both cave rows,
  including native-air/support preservation, functional/protection negatives,
  final setter count and deterministic replay.
- Shared R7 micro evidence reaches real manifest construction and reports
  84/90/34 populations, `91/124/125/125/127/127` successor refs, strict current
  identities and all 157 executed historical modules.
- Parser checks cover 47 changed Lua files. The four expected one-global-per-mod
  `SETGLOBAL` rows are visible; all five compatibility sweeps pass.
- The dependency graph reports all 44 shipped mods without a missing dependency
  or cycle.

## Focused fix rereview

The sole Medium is closed in final candidate `02f37ec0`. The only regression
fixture change fills the synthetic below-surface native region with the newly
declared `default:stone` CID. This prevents unrelated surface-skin/light repair
writes while retaining the intended byte-equal support, explicit ignore target,
`content_ignore` rejection assertion and `noop_equal_content` assertion. No
production writer or ignore guard changed. The bound baseline diagnostic applies
the corrected synthetic contract to exact base `4491c996` and reproduces the
former light-context failure, confirming that it was fixture context rather than
a MAP-B production regression.

The replacement `regressions-final.log` records exactly 13 BEGIN and 13 PASS
rows with no FAIL: registration, placement, private writer, template refs, FARM,
ART, corrected R6 micro, both R8 jobs and all four WP13 jobs. The two changed
executable inputs match `changed-inputs.sha256`; all sixteen addendum artifacts
match `outputs.sha256`. The addendum static record also covers the changed
fixture and probe. I inspected these immutable artifacts without rerunning Lua
or the engine.

The bounded engine evidence is non-vacuous and correctly scoped. A fresh world
contains 3,267 actual VM-authored soils; four held blocks select 28. The initial
sample has no natural nearby water and makes no hydration claim. The revised
probe explicitly records one scratch-only water stimulus over an authored soil;
after the ordinary timer path it records 12 wet, 16 dry, 28 active timers and 12
near-water soils. A third same-world boot reads 12 wet soils before its timer
settlement and ends with the identical 12/16/28/12 result. Its six non-field
digests exactly match the hydration boot. The corrected second-boot provenance
points to the unique `server.2.log`, and the final reload is bound to its own
server/launcher/TSV hashes.

The engine samples also prove actual positives for Carrot 19, Fire Pepper 2,
Pumpkin 2, Wild Grain 1, ash ground 376, Cave Cap 1, Ember Moss 2 and four coral
variants. The report explicitly avoids claiming an all-fifteen natural census;
exhaustive row/reef coverage remains the deterministic real-tail fixtures.

Calibration: initial independent review found **1 Medium**. One focused fix
round closed it. Final reviewed hash is `02f37ec0318386fdf43525f4935dbbb8682f17b7`.

## Remaining integration gates

1. Root's one final integrated PUC/LuaJIT byte-parity pair, six-capital fleet and
   six-start forward/reverse cold/reload gate.
