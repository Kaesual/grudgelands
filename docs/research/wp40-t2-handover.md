# WP40 T2 factual handover

Snapshot basis: commits `9a6ad8f` (R19 Source/Reality freeze) and `44c2739`
(unfinished compiler-integration checkpoint). The checkpoint is not a freeze.

## 1. GREEN TODAY

These are the retained green gates on the current bytes. A command omitted from
this table is not claimed green.

| Command | What it proves | Observed wall time | Runtime |
|---|---|---:|---|
| `tools/wp40/run_t2_source_fast.sh` | Complete current R19 Source/Reality harness, including the retained Source oracles and rollback mutations (`tools/wp40/t2_source_test.lua:1`). | 90.75 s measured on this snapshot | LuaJIT |
| `tools/wp40/t2_source_audit.sh .` | Source syntax, static authority pins, five Lua sweeps, and the same full Source harness (`tools/wp40/t2_source_audit.sh:1`). | Several minutes in the retained final chain; exact wall time was not recorded | PUC 5.1 |
| `tools/wp40/run_t2_schema_core.sh` | Compiled transport schema/trust-boundary gate plus Source audit, T1, T0, and WP43 (`tools/wp40/run_t2_schema_core.sh:1`). It does not prove compiled geometry. | Source-audit dominated; exact wall time was not recorded | PUC 5.1 |
| `tools/wp40/run_t1.sh` | Deterministic hashing, canonical encoding, IPC, and index foundation. | 0.17 s measured on this snapshot | PUC 5.1 |
| `tools/wp40/run_t0.sh` | Material/vocabulary handoff and T0 projection; headless capture remains opt-in. | 0.05 s measured on this snapshot | PUC 5.1 |
| `tools/wp43/source_audit.sh .` | Current WP43 material vocabulary consumed by T0/T2. | 0.02 s measured on this snapshot | PUC 5.1 |
| `tools/bin/lua51 tools/wp40/t2_partition_test.lua "$PWD" <safe-scratch> selected_stage2_historical` | Immutable pre-R18 failure provenance only; it explicitly performs no current compile (`tools/wp40/t2_partition_test.lua:457-682`). | Passed on the current test bytes; exact wall time was not retained and it was not rerun for this handover | PUC 5.1 |
| `tools/bin/luac51 -p <owned Lua files>` plus the SETGLOBAL/five-sweep and `bash -n` gates | Plain-5.1 syntax and the repository's static Lua/shell restrictions. | Seconds | PUC 5.1 syntax/static |
| `git diff --check` and the submodule-marker check | No whitespace error and no moved reference-project pin. | Below 1 s | N/A |

## 2. BLOCKING THE T2 FREEZE

| Open item | What must run | What a pass would prove | Estimated wall cost | User decision needed? |
|---|---|---|---:|---|
| R19 compiler integration | `tools/wp40/run_t2_partition_c2_selected.sh` | All four non-promotable witness seeds compile, and their independent edge, Bank, Face, and Whole checks pass (`tools/wp40/t2_partition_test.lua:5458-5650`). | About 10–20 min LuaJIT; the prior run did not retain a complete timing | No policy decision; execution is barred by this pause |
| Current checkpoint reds | The same four-seed diagnostic | Slot 29 no longer dies before the Stillgrave Bank, and Slot 30 no longer fails its incomplete Starbough witness literal (`tools/wp40/t2_partition_test.lua:5596-5611`). | Included above | No |
| Seed-zero/max partition regression | `WP40_LUA_BIN=/usr/bin/luajit tools/wp40/run_t2_partition.sh` | Existing Seed-zero/max edge, Bank, Coast, Face, and Whole results remain green after R19 compiler integration. | Estimated 6–10 min | No |
| Plain-5.1 partition acceptance | The T2-final PUC partition groups governed by `tools/wp40/run_t2_partition.sh` | LuaJIT evidence is reproducible under fallback-language semantics. | The last complete pre-C2 serial PUC run took about 53 min; current cost is unmeasured | Run authorization only; no unresolved policy decision recorded |
| Production compiler payload | A production/offline compiled-geometry acceptance gate; none exists yet | `compiler.lua` returns the typed compiled payload instead of `compiled_geometry_unavailable` (`mods/MAPGEN/grug_mapgen/wp40/compiler.lua:89-149`). | Implementation cost unknown; gate runtime unmeasured | No design decision recorded |
| Fields, selector, and layers | No materialization acceptance command exists yet | Non-empty logical-biome, nearest-feature, housing-center, spatial-index, and coverage results satisfy the compiled schema (`mods/MAPGEN/grug_mapgen/wp40/compiled_schema.lua:14-110`). | Unknown | Ambiguity: no implementation estimate or peak-memory measurement exists |
| Fresh post-R19 scalar pool | `tools/wp40/run_t2_extreme_shards.sh`, then the PUC merge | Exactly eight verified shards cover all candidates and produce a new scalar-only pool/ranking on post-R19 Source and Partition pins. | 100 min 51 s observed for the prior eight-way LuaJIT pool, plus a short merge | Yes: this phase explicitly stops before another costly run |
| Selected-four conformance | `tools/wp40/run_t2_extreme_conformance.sh` | Exact retained-row rescoring and all four PUC full-partition gates pass without fallback. | Prior attempt: 249 s for 20 rescores, then about 74 min before the selected barrier failed | Run authorization only |
| Final T2 corpus/freeze review | The final 31 promoted entries plus staging entry through the complete geometry suite, then independent review | T2's corpus, staging, schema, Source, Partition, selector, and release-fixture claims agree on one immutable snapshot (`docs/research/wp40-engineering-brief.md:4949-4951`). | Not measured; necessarily over 10 min | No new design decision is recorded; execution authorization remains external |

## 3. THE R-SERIES

- **R7** — closed incomplete boundary-displacement/scalar-identity staging; found during the T2b pass and review against the earlier T2a Source (`docs/research/wp40-engineering-brief.md:3959-3977`).
- **R8** — closed exterior/land/channel precedence ambiguity; found by review of the draft classifier and harness (`docs/research/wp40-engineering-brief.md:3978-3986`).
- **R9** — closed incomplete coast-source roster and exact-tie authority; found by independent review (`docs/research/wp40-engineering-brief.md:3987-3995`).
- **R10** — closed record-level raster topology failure after local clipping (`docs/research/wp40-engineering-brief.md:730-745`). The retained brief does not state the exact seed or scan that first exposed it; it entered with the seed-zero geometry freeze.
- **R11** — closed the assumption that Bay-water masks were ordered shore polygons; found by the first T2b face compiler (`docs/research/wp40-engineering-brief.md:4074-4205`).
- **R12** — closed start-anchor and converging-branch trace assumptions; found by the first retained T2b materialization on the Hearthpine component (`docs/research/wp40-engineering-brief.md:4207-4243`).
- **R13** — closed digital shared-prefix junction overlap; found by the first Ashenward face failure and the complete Seed-zero junction-pair scan (`docs/research/wp40-engineering-brief.md:4245-4293`).
- **R14** — closed pre-partition versus post-partition junction-stage conflation; found by the first post-clipping topology gate (`docs/research/wp40-engineering-brief.md:4294-4320`).
- **R15** — closed structurally valid Wing tails whose enclosed wedge was not all water; found by an exploratory eight-Wing PUC scan before repository compiler reproduction (`docs/research/wp40-engineering-brief.md:4322-4386`).
- **R16** — closed a final dry Bay-edge endpoint that was not a valid Bank terminal; found by fixed extreme slot 19 during compiler reproduction (`docs/research/wp40-engineering-brief.md:4451-4549`).
- **R17** — closed raw-mask degree-one dry notches; found by the first max-u64 full Whole pass after R16 (`docs/research/wp40-engineering-brief.md:4551-4654`).
- **R18** — closed an aperture shoulder case and a multiple-dry-run edge case; found by the first selected-four C1 PUC attempt in slots 29 and 30 (`docs/research/wp40-engineering-brief.md:4663-4805`).
- **R19** — closed a direct edge terminal with no complete pair of incident Banks; found by the subsequent targeted Slot-29 compiler diagnostic against frozen R18 Source (`docs/research/wp40-engineering-brief.md:4807-4927`).

## 4. FREEZE CIRCULARITY

| Correction | Triggered by compiler reproduction against already-frozen Source? |
|---|---|
| R7 | Yes: the next T2b implementation pass followed the frozen T2a Source. |
| R8 | Yes; the same pass/review exposed it. |
| R9 | Yes; the same pass/review exposed it. |
| R10 | Ambiguous: the brief records the correction but not its first trigger. |
| R11 | Yes: first T2b face compiler. |
| R12 | Yes: first retained materialization after R11. |
| R13 | Yes: face/junction reproduction after R12. |
| R14 | Yes: post-clipping gate after R13. |
| R15 | No: the defect was found by a focused exploratory PUC Wing scan; compiler reproduction came afterward. |
| R16 | Yes: compiler gate against the post-H55 Source. |
| R17 | Yes: max-u64 Whole reproduction after R16. |
| R18 | Yes: selected-four reproduction after R17 Source/Partition freeze. |
| R19 | Yes: targeted compiler reproduction after R18 Source freeze. |

Current dependency, in exact order:

1. Source reaches reviewed edit-stop and receives immutable pins.
2. The compiler reproduces Source against exactly those pins.
3. A compiler mismatch is either a compiler defect or evidence that frozen Source was false.
4. The latter case reopens Source, invalidates the pending compiler freeze, and returns to step 1.
5. Only a matching compiler snapshot may become the Partition input to corpus measurement.
6. This overall process is **not acyclic today**; R11, R12, R13, R14, R16, R17, R18, and R19 demonstrate the feedback edge from compiler reproduction back to Source.

## 5. CONVERGENCE

There is no evidence that R19 is the last correction, and no formal bound on the
set of possible degeneracy classes. The series therefore cannot currently be
called converged.

Closed classes: source displacement and scalar identity (R7); horizontal
precedence (R8); coast-source roster/ties (R9); per-record raster topology
(R10); coordinate-free Bank components and Wing-terminal pairing (R11);
directed trace starts/branches (R12); pre-partition digital junction separation
(R13); post-partition junction categories (R14); Wing dry-wedge validity (R15);
diagonal Bay-edge terminal recovery (R16); single-pass raw-mask notches (R17);
aperture shoulders and incidence-complete edge intervals (R18); and joint
Bank-complete transition terminals (R19).

Still unscanned across the full candidate universe: all 61-edge interval-count
and ambiguity cases; all R19 candidate-tuple cardinalities; all Bank dead-end,
branch, repeat, crossing, and bound-exhaustion cases; all aperture direct/tail
modes; all Wing candidate/tail/wedge alternatives; all notch-fill patterns;
all displaced junction pair interactions; all attachment endpoint/run cases;
all final perimeter/equality/coast ties; and all 38-Face closure, orientation,
simplicity, raw-owner, gap, and overlap outcomes. This is the known list, not a
bound on unknown classes.

## 6. EXHAUSTIVE DETECTION

The 6-seed by 61-edge inventory rebuilds each seed's R7 edge stations, maximal
final-dry intervals, selected interval, retained authored control indices,
final edge bytes, topology ceiling, and scalar-sample identity, and compares
all 61 compiled edge payloads to an independent reconstruction
(`tools/wp40/t2_partition_test.lua:2441-2767`). It covered Seed zero, max-u64,
and the four pre-R18 provisional winner seeds; the four-seed launcher is
`tools/wp40/run_t2_partition_c2_selected.sh:1-78`.

It does not enumerate R19 joint terminal tuples, every Bank-search state, all
R15/R17 candidate sets, every attachment/perimeter tie, or every Face/Whole
failure as separate inventory classes. Some of those are downstream assertions
for the six tested seeds, not inventory dimensions. Slot 29 currently stops
before completing the WIP diagnostic, so the post-R19 six-seed inventory is not
green.

No equivalent all-seed/all-class runner or memory measurement exists. Using
the observed selected-seed LuaJIT Whole cost as the only available basis, a
4,096-seed eight-worker run would be on the order of 2–4 days; a PUC-5.1
equivalent would be on the order of weeks. Peak RSS and output size are unknown.
Measuring them requires a run longer than ten minutes and was not done here.

## 7. THE 4,096 POOL

The retained run executes eight immutable LuaJIT shards of 512 candidates and emits one scalar-measurement row per candidate; PUC 5.1 then exact-covers, parses, ranks, and writes the merged candidate artifact and manifest (`tools/wp40/run_t2_extreme_shards.sh:1-129`, `tools/wp40/t2_extreme_merge.lua:98-277`). It freezes only the R7 scalar-measurement pool and ranking input, explicitly not Partition, Whole, selected-four acceptance, or T2 (`tools/wp40/README.md:181-220`). The observed run took 100 min 51 s on eight LuaJIT workers; eight shards plus merged artifact and manifest occupy 3,786,042 bytes. Before launch, the immutable commit/tree, Source checksum, boundary-policy checksum, Partition file, authority DAG, reviewed launcher/worker bytes, full-scan gate, and exact LuaJIT binary must agree (`tools/wp40/t2_extreme_authority.lua:1-477`). The checked-in pre-R19 pool is historical and unpromotable.

## 8. DESIGN-DOC CONTAMINATION

Classification: **(a)** game/later-WP contract, **(b)** compiler/raster
algorithm or acceptance evidence, **(c)** mixed.

| Current `world_zones.md` lines | R-series content | Class |
|---:|---|:---:|
| 279–301 | R17 final Bay-mask correction and its payload/scan contract | (c) |
| 302–311 | R11 Bank-component authority | (b) |
| 312–332 | R18 aperture-terminal correction | (b) |
| 333–364 | R16 transition authority plus R17/R19 ordering and pool status | (b) |
| 365–398 | R11/R12 trace-anchor, successor, and bound rules as later amended | (b) |
| 399–432 | R11/R15 Wing endpoint, tail-pair, and wedge rules | (b) |
| 538–548 | R8 horizontal land/water/channel precedence | (c) |
| 549–558 | R9 coast-source inheritance and tie rule | (c) |
| 680–718 | R18 interval, obligation, control, excluded-fragment, and reversal rules | (b) |
| 719–754 | R19 joint-terminal candidate/probe/Bank-completeness rules | (b) |
| 867–879 | R7 visible displacement limits plus damping contract | (c) |
| 880–905 | R7 canonical station metadata, normal/scalar, and local clipping | (b) |
| 906–922 | R10 record-wide topology ceiling | (b) |
| 923–958 | R7 final reraster and later fixed-closure correction | (b) |
| 959–986 | R13 junction-departure and pre-partition pair gate | (b) |
| 987–999 | R14 post-partition topology categories | (b) |
| 1000–1015 | R7/R18 scalar-only extreme-selector input boundary | (b) |
| 1595–1598 | R9 public coast-source query contract | (a) |
| 1719–1727 | R17 retained acceptance evidence | (b) |
| 1756–1768 | R15 retained Wing-pair evidence and limitations | (b) |
| 1769–1784 | R13/R14/R18 Source-versus-compiled acceptance staging | (b) |

## 9. OWNERSHIP MAP

### Source

- `docs/design/world_zones.md` — 2,002 LOC; binding world/design contract.
- `mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua` — 3,055 LOC; sole literal and coordinate-free Source records and policy strings.
- `mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua` — 4,753 LOC; closed Stage-1 schema, projections, diagnostics, and Source checksum validation.
- `tools/wp40/t2_source_test.lua` — 6,258 LOC; independent Source/Reality oracles and mutation KATs.
- `tools/wp40/t2_source_audit.sh` — 386 LOC; static Source gate and PUC harness entry.
- `docs/research/wp40-engineering-brief.md` — 4,988 LOC; evidence history and citations, not production authority.

### Compiler + partition

- `mods/MAPGEN/grug_mapgen/wp40/compiler.lua` — 197 LOC; fixed production/offline trust entry; geometry implementation is still absent.
- `mods/MAPGEN/grug_mapgen/wp40/compiled_schema.lua` — 291 LOC; typed compiled transport projection.
- `mods/MAPGEN/grug_mapgen/wp40/geometry/exact.lua` — 433 LOC; exact arithmetic and predicates.
- `mods/MAPGEN/grug_mapgen/wp40/geometry/raster.lua` — 506 LOC; canonical integer raster primitives and validation.
- `mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua` — 3,721 LOC; WIP analytic compiler/partition materializer and scalar export.
- `tools/wp40/t2_partition_oracle.lua` — 1,582 LOC; independent full Partition/Whole oracle.
- `tools/wp40/t2_partition_test.lua` — 5,800 LOC; Seed-zero/max, historical, C2, Bank/Face/Whole, and WIP compiler gates.
- `tools/wp40/run_t2_partition.sh` — 62 LOC; main partition runner and static checks.
- `tools/wp40/t2_partition_c2_selected.lua` — 91 LOC; closed four-seed diagnostic wrapper.
- `tools/wp40/run_t2_partition_c2_selected.sh` — 78 LOC; four-way LuaJIT diagnostic launcher; currently red.

### Fields + selector + layers

- `mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua` — 852 LOC; scalar candidate identity, scoring, shard schema, and ranking helpers.
- `tools/wp40/t2_extreme_test.lua` — 1,335 LOC; extreme-scalar and bounded-foundation tests.
- `mods/MAPGEN/grug_mapgen/wp40/index128.lua` — 308 LOC; generic 128-node spatial-index foundation.
- `mods/MAPGEN/grug_mapgen/wp40/compiled_schema.lua` — 291 LOC; reserves logical-biome, nearest-feature, housing-center, spatial-index, and coverage families.
- No file currently owns materialized logical-biome, nearest-feature, housing-center, or final compiled spatial-layer results; `compiler.lua:131-148` still creates empty trust data and fails closed.

### Corpus + fixtures

- `mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua` — 130 LOC; frozen slots 1–27 plus pending later slots.
- `tools/wp40/fixtures/t1_seed_corpus.tsv` — 30 LOC; canonical T1 corpus projection.
- `tools/wp40/t2_extreme_authority.lua` — 477 LOC; immutable measurement snapshot and provenance validation.
- `tools/wp40/t2_extreme_shard_worker.lua` — 408 LOC; one 512-candidate scalar shard.
- `tools/wp40/run_t2_extreme_shards.sh` — 129 LOC; exact eight-shard orchestration and live progress.
- `tools/wp40/t2_extreme_merge.lua` — 277 LOC; exact cover, PUC parse/rank, winners, staging, artifact, and manifest.
- `tools/wp40/t2_extreme_conformance.lua` — 606 LOC; retained row/result schemas and exact comparisons.
- `tools/wp40/t2_extreme_conformance_authority.lua` — 173 LOC; conformance snapshot/provenance binding.
- `tools/wp40/t2_extreme_conformance_test.lua` — 271 LOC; conformance corruption KATs.
- `tools/wp40/run_t2_extreme_conformance.sh` — 262 LOC; 20-row barrier, four selected workers, and finalizer orchestration.
- `tools/wp40/fixtures/t2_extreme_e0/full_scan_gate.lua` — 8 LOC; historical full-pool activation pins.
- `tools/wp40/fixtures/t2_extreme_e0/conformance_gate.lua` — 57 LOC; historical winner/provenance handoff, still pending selected-four conformance.
- `tools/wp40/fixtures/t2_extreme_e0/shard-luajit-*.tsv` — eight files, 530 LOC each; historical 512-row shards.
- `tools/wp40/fixtures/t2_extreme_e0/candidates-luajit.tsv` — 4,117 LOC; historical merged candidate pool.
- `tools/wp40/fixtures/t2_extreme_e0/manifest-luajit.tsv` — 27 LOC; historical pool manifest.
- `tools/wp40/fixtures/t2_extreme_e0/rescore-puc-*.tsv` — twenty files, 24 LOC each; retained successful PUC scalar-row rescoring evidence only.
