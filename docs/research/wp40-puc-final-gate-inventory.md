# WP40 PUC final-gate inventory

Status: **SUPERSEDED 2026-08-25 for live WP40 scheduling. Immutable historical
measurement/evidence for the retired exact T2 schema; its PCC/F1/F2 definition
is not a simple-map R0-R8 gate.**

Historical status before supersession: **PUC-1 accepted and implemented for review on 2026-08-23.** Sections
2--15 preserve the pre-ruling inventory/recommendation basis. Section 16 is
the later measured closeout and takes precedence wherever those historical
sections say projected, incomplete, unresolved or not in force.

Baseline: commit `1b38943` on branch `wp40-puc-final-gate-inventory`, a
worktree of `wp40-named-zone-world-foundation`. Every `path:line` below was
opened at that commit. Numbers carry an explicit **MEASURED** or
**PROJECTED** label; a number without one is an identifier, not a cost.

## 1. Purpose, standing, and what does not change

### 1.1 What this document is

Originally an outcome-neutral inventory of every WP40 obligation that executed,
or was read as executing, plain PUC Lua 5.1 at T2-final or T9-final: what each one
costs, what semantic risk each one covers, and what a bounded replacement
would have to contain to cover the same ground. It existed to put a user
ruling on a measured basis. It was the deliverable that
[wp40-acceleration-and-delivery-plan.md](wp40-acceleration-and-delivery-plan.md):700-711
asks for.

### 1.2 What this document is not

Sections 2--15 are **not an authority**. They changed no rule, retired no gate,
and authorized no run. They are a research/planning record in the same class as
[wp40-t2-plan.md](wp40-t2-plan.md) and the acceleration plan, whose own
closing sentence says the same of itself
(acceleration-plan:730, "This draft remains a planning record; it does not
become a competing authority").

### 1.3 Historical standstill rule — satisfied 2026-08-23

> Until the inventory is reviewed, the final user ruling is recorded, and the
> authorities change atomically, the existing comprehensive T2-final/T9-final
> PUC rule continues to apply. If the replacement fails review, retain that
> rule and attach explicit wall-time and CPU budgets instead.
> — acceleration-plan:293-296

The user later accepted PUC-1 and Phase 0B implemented the coordinated atomic
fold on the ownership provider. The following list is retained only to show
which pre-ruling owners were protected by the standstill:

- `AGENTS.md`:136-140 and :144-150 stayed binding exactly as written;
- `docs/process/wp-workflow.md`:46-55 and :62-70 stayed binding;
- [luanti-lua.md](luanti-lua.md):336-342 and :359-362 stayed binding;
- `tools/wp40/README.md`:111-115 and :126-135 stayed binding; and
- [wp40-t2-contracts.md](wp40-t2-contracts.md):1582-1584 stayed binding in its
  then-ambiguous wording.

At that time nothing in sections 7, 8, 10 or 11 was in force; those sections
were proposals. Section 16 records their later disposition.

### 1.4 The one sentence that forces the decision

`wp40-t2-contracts.md`:1582-1584, verbatim:

> 5. The full-`W` re-census (schema v7 / artifacts v4) is **deferred to
>    T2-final** and rides its comprehensive PUC round; the targeted
>    re-run plus the winner invariance is this fix's acceptance evidence.

Two readings:

- **(a) scheduling.** The re-census is deferred to the T2-final milestone,
  which also happens to carry a comprehensive PUC round. The two are
  co-scheduled, not coupled.
- **(b) coupling.** The re-census population itself executes under standalone
  PUC as part of that round.

Section 5.2 prices reading (b) at 1,512-2,216 CPU-h. Section 4 (PUC-F5)
records the evidence that (b) was never intended.

## 2. Method and evidence rules

### 2.1 The sweep

A repository-wide sweep over `.md`, `.sh`, `.lua`, `.py`, `.conf` and `.txt`,
excluding `reference_projects/` and `.git/`, on these terms: `PUC`, `lua51`,
`luac51`, `lua5.1`, `LuaJIT`, `WP40_LUA_BIN`, `T2-final`, `T9-final`,
``full-`W` ``, `re-census`, `divergence`, `byte-identical`,
`digest-identical`, `fallback`, `dual-runtime`, `benchmark`, `pairs()`,
`interpreter`. Per-term file and hit counts are in Appendix B, so the
completeness claim is reproducible.

Every hit that names an executable obligation was then opened in its runner
or module and traced to the interpreter binding line. Documentation hits were
opened to classify them as authority, plan, or record.

### 2.2 Classification vocabulary

| label | meaning |
|---|---|
| **T2-FINAL** | binding at the T2 final gate and nowhere earlier |
| **T9-FINAL** | binding at the T9 final gate |
| **INTERMEDIATE** | binding at a milestone/package gate before T2-final |
| **EVERY-CHANGE-STATIC** | binding on every Lua change; no expensive execution |
| **RUNTIME-ENGINE-GATE** | requires the Luanti engine, not a standalone interpreter |

Interpreter binding is recorded as one of three states, always with the
`file:line` that decides it: **SELECTABLE** (honours `WP40_LUA_BIN`,
defaults to LuaJIT), **CONDITIONALLY PUC-FORCED** (a flag or env var flips
it), **HARDWIRED** (the path is a literal in the script).

### 2.3 MEASURED vs PROJECTED

Every cost is labelled. Projections state their derivation and their anchor.
The governing constraint on all of them is `wp40-t2-plan.md`:352-355:

> PUC-to-LuaJIT ratio is **not** a single number: measured 2.8x on
> validation-heavy paths, 16.2x on an exhaustive numeric sweep, and 26.5x on a
> full seed-0 compile (868/32.7). Any plan resting on one extrapolated ratio has
> been wrong before.

`tools/wp40/README.md`:436-437 repeats it. Consequently this memo never
carries a single ratio across workloads. It states which of the three
measured bands applies, and where a band does not exist it says so rather
than borrowing one. Section 5.3 records that the 16.2x figure has no retained
underlying measurement anywhere in the repository.

### 2.4 Similarly-named runners were traced, not assumed

Two families are easy to conflate, and both were resolved by opening the
scripts:

**The extreme family.** `run_t2_extreme.sh` is the Foundation harness and
defaults to LuaJIT (`run_t2_extreme.sh`:66-70); it forces PUC only when
`WP40_EXTREME_MERGE=1`. `run_t2_extreme_shard.sh` is HARDWIRED **LuaJIT**
(`:48`) with a build-identity pin at `:53-57`. `run_t2_extreme_shards.sh` is
the eight-shard launcher, which uses PUC only to verify and merge
(`:38`, `:59`, `:85`, `:147`). `run_t2_extreme_puc_kat.sh` is HARDWIRED PUC
(`:11`) and is the single-candidate selector KAT.
`run_t2_extreme_conformance.sh` is HARDWIRED PUC (`:12-13`) and is the C1
conformance round. Five scripts, four different interpreter policies.

**The census family.** `run_t2_census.sh` defaults to LuaJIT (`:61`) but
hardwires PUC for the merge publication half (`:197`).
`run_t2_census_gates.sh` defaults to LuaJIT (`:130`) and calls PUC for
exactly one comparison leg (`:418`). `run_t2_census_probe.sh` defaults to
LuaJIT (`:44`). Naming a "census PUC run" without naming the leg is
ambiguous by a factor of about 4,000 in cost.

**One selector clarification.** `tools/wp40/t2_phase_selector.lua` is *not*
the pipeline selector; its first line reads "Shared offline-harness phase
selector" and it parses `WP40_T2_ONLY`. The actual selector stage is
`mods/MAPGEN/grug_mapgen/wp40/geometry/extreme.lua` (`score_candidate`,
`candidate_shard`), exercised full-path under PUC by
`run_t2_extreme_puc_kat.sh` and against committed LuaJIT fixtures by
`run_t2_extreme_conformance.sh`.

## 3. Definitions: full-path witness, unit test, comparator-only check

These three are not interchangeable, and the difference decides what a
bounded gate can and cannot claim.

- A **FULL-PATH witness** executes production code under
  `mods/MAPGEN/grug_mapgen/wp40/` end-to-end for the stage it claims, through
  that stage's real production entry point, and emits an artifact or digest
  that is comparable byte-for-byte against the LuaJIT evidence.
- A **unit test** loads production modules but drives an internal function
  rather than the stage entry point. It proves that function agrees across
  interpreters; it proves nothing about the code that calls it.
- A **comparator-only check** drives a harness, oracle, fixture reader or
  ledger and never loads a production module at all. It proves that the
  *checker* is interpreter-stable.

### 3.1 Worked example — full-path

`tools/wp40/t2_correction_repro.lua`. Its header (`:1-3`) states "solo
compiles of the named witness seeds through the full compile path --
partition.compile, never the census projection". It loads the real production
chain: `canonical.lua`, `deterministic.lua`, `geometry/exact.lua`,
`geometry/raster.lua`, `source/catalog.lua`, `validation/t2_source.lua`,
`geometry/boundary.lua`, `geometry/partition.lua` (`:24-40`), then compiles.
`tools/wp40/t2_census_worker.lua` is the second: same load set at `:195-213`,
and it calls the production entry `partition.census_scan(seed, {scan4 =
seed_member})` at `:300`.

### 3.2 Worked example — comparator-only

`tools/wp40/t2_s11_acceptance_check.lua`. A `grep` for `dofile|require|
loadstring` over the whole 380-line file returns exactly one hit, and it is the
string "repository root required" at `:41`, not a call — no module load exists
in the file. Its own header
says what it is (`:1-11`): the committed proof that a given artifact set still
*is* the section-11 acceptance ledger. It reads six committed TSV/TXT
fixtures and counts rows against pins at `:48-77`. Running it under PUC
proves the ledger arithmetic is interpreter-stable. It cannot detect a
divergence in `partition.lua`, because it never loads it.

### 3.3 The instructive middle — trust-path exercise

`tools/wp40/t2_schema_core_test.lua` reaches `compiler.lua` and constructs
the offline adapter (`:411-414`), but every compile call it makes is wrapped
in `expect_error("compiled_geometry_unavailable", ...)` (`:415-417`,
`:453-455`), and that guard fires at
`mods/MAPGEN/grug_mapgen/wp40/compiler.lua`:148 before any geometry runs. It
is a **trust-path exercise**: the canonicalization and checksum path at
`compiler.lua`:144-147 does execute, so it is more than a comparator, but no
compile completes. It is not a full-path compiler witness.

### 3.4 A correction to a common misreading

`tools/wp40/t2_correction_kat_test.lua` loads the full production module
chain (`:20-36`) and therefore *looks* full-path, but it then binds only two
functions — `partition.joint_tuple_less_compile` and
`partition.joint_tuple_less_census` (`:38-40`) — and drives synthetic
descriptor pairs through them. It is a **unit test on production comparator
functions**, not a full-path witness. Contracts states this itself at
`:979-981`: "the synthetic KATs drive only the comparator under PUC, and the
new R19 enumeration path needs at least one end-to-end PUC exercise". That
sentence is exactly why contracts §8.6.2 added a separate full-compile-path
witness pair — see PUC-K13, which is the obligation no runner performs.

## 4. The inventory

### 4.1 Master table

Every gate has exactly one ID. Wall figures are single-process unless the
parallelism field says otherwise.

| ID | Command / obligation | Class | Interpreter binding | PUC wall | Label |
|---|---|---|---|---:|---|
| PUC-S1 | `tools/bin/luac51 -p` over changed Lua | EVERY-CHANGE-STATIC | HARDWIRED PUC (vendored tool) | seconds | MEASURED (handover:40) |
| PUC-S2 | `luac51 -l -p \| grep SETGLOBAL` | EVERY-CHANGE-STATIC | HARDWIRED PUC | seconds | MEASURED (handover:40) |
| PUC-S3 | the five grep sweeps | EVERY-CHANGE-STATIC | no interpreter (grep) | seconds | MEASURED (handover:40) |
| PUC-K1 | `tools/wp40/run_t0.sh` | INTERMEDIATE | HARDWIRED PUC `run_t0.sh:15` | 0.05 s | MEASURED (handover:37) |
| PUC-K2 | `tools/wp40/run_t1.sh` | INTERMEDIATE | HARDWIRED PUC `run_t1.sh:23` | 0.17 s | MEASURED (handover:36) |
| PUC-K3 | `tools/wp43/run.sh` | INTERMEDIATE | HARDWIRED PUC `tools/wp43/run.sh:7` | 1-10 s | PROJECTED |
| PUC-K4 | `tools/wp40/run_t2_schema_core.sh` | INTERMEDIATE | HARDWIRED PUC `run_t2_schema_core.sh:37` | 196-591 s | PROJECTED |
| PUC-K5 | `tools/wp40/t2_source_audit.sh .` (full) | INTERMEDIATE | full harness SELECTABLE, LuaJIT default; targeted PUC parity | targeted seconds; full path ~88 s LuaJIT | MEASURED, Phase 0B |
| PUC-K6 | `tools/wp40/run_dungeon_probe.sh` | INTERMEDIATE | HARDWIRED PUC `run_dungeon_probe.sh:5-6` | 5-60 s | PROJECTED |
| PUC-K7 | `tools/wp40/run_t2_correction_kat.sh` | INTERMEDIATE | PUC leg HARDWIRED `:28`, LuaJIT leg SELECTABLE `:27` | 20-111 s | PROJECTED |
| PUC-K8 | `tools/wp40/run_t2_s11_acceptance.sh` | INTERMEDIATE | PUC leg HARDWIRED `:23`, LuaJIT leg SELECTABLE `:22` | 1-10 s | PROJECTED |
| PUC-K9 | `run_t2_census_gates.sh` Scan-3b/4 KAT PUC leg | INTERMEDIATE | HARDWIRED PUC `run_t2_census_gates.sh:418` | 20-111 s | PROJECTED |
| PUC-K10 | `run_t2_census.sh --merge-kat` | INTERMEDIATE | LuaJIT worker + PUC merge half HARDWIRED | retained per-seed worker wall counters sum to 346 s; exact whole-leg wall unretained | MEASURED GREEN within 420 s cap, Phase 0B |
| PUC-K11 | `tools/wp40/run_t2_extreme_puc_kat.sh` | INTERMEDIATE | HARDWIRED PUC `:11` | 170-3,091 s | PROJECTED |
| PUC-K12 | PCC worker full-path pair | INTERMEDIATE / FINAL PCC | `run_t2_puc_core.sh --worker` | 2,325 s PUC; 2,457 s pair total | MEASURED, Phase 0B |
| PUC-K13 | PCC compiler full-path pair | INTERMEDIATE / FINAL PCC | `run_t2_puc_core.sh --compiler` | 1,734 s PUC; 1,803 s pair total | MEASURED, Phase 0B |
| PUC-K14 | `run_t2_census_probe.sh` PUC leg | INTERMEDIATE | SELECTABLE, LuaJIT default `:44` — no PUC leg today | n/a | NOT A PUC GATE |
| PUC-F1 | `WP40_FINAL=1 run_t2_partition.sh --no-cache --historical` | T2-FINAL | CONDITIONALLY PUC-FORCED `:91-95` | 53-62 min | MEASURED, conflicting |
| PUC-F2 | `tools/wp40/run_t2_extreme_conformance.sh` | T2/T9-FINAL | HARDWIRED PUC `:12-13` | ~99 min end to end | MEASURED, complete |
| PUC-F3 | `run_t2_census.sh --merge` PUC publication half | T2-FINAL | HARDWIRED PUC `:197` | 19 s-6 min | MEASURED, conflicting |
| PUC-F4 | `fixtures/t2_extreme_e0/README.md:22-29` pool obligation | T2-FINAL | prose obligation; realized by PUC-F2 | see PUC-F2 | — |
| PUC-F5 | full-`W` population under standalone PUC | none; reading (b) ruled out by PUC-1 | forbidden | n/a | CLOSED |
| PUC-F6 | T9-final standalone-PUC gate | same bounded PCC + retained F1/F2 as T2-final | defined by contracts §14.7 | same component budgets | CLOSED |
| ENG-1 | the real fallback-engine runtime gate | RUNTIME-ENGINE-GATE | Luanti built against bundled Lua 5.1 | unmeasured | GAP |
| ENG-2 | dual-runtime engine benchmarks | T9-FINAL / RUNTIME-ENGINE-GATE | both engine builds | unmeasured | GAP |

`pairs()` exposure, answered from the code, is carried per entry below.

### 4.2 PUC-S1 / PUC-S2 / PUC-S3 — the three static gates

**Command:** `find mods/*/grug_* -name '*.lua' | xargs tools/bin/luac51 -p`;
`tools/bin/luac51 -l -p <file> | grep SETGLOBAL`; the five sweeps at
luanti-lua.md:310-321. **Owner:** AGENTS.md:128-136; wp-workflow.md:46-49;
luanti-lua.md:348-350 (layer 1, "mandatory even when every executable test uses
LuaJIT"). **Trigger:** every Lua change, unconditionally. **Population:** all
owned Lua under `mods/*/grug_*` — note the scope trap at AGENTS.md:131-132
(Lua under `tools/` is **not** covered and needs the check run explicitly) and
the tooling trap at AGENTS.md:133-135 (a missing `ripgrep` made nine sweeps
report success without running until 2026-08-15). **Cost:** seconds,
MEASURED-qualitative (handover:40). **Risk covered:** plain-5.1 parse
acceptance; the `goto`/`::label::`, `\x`/`\u{}`/`\z`, 5.2/5.3-stdlib,
`//`/bitwise-operator and sandbox-namespace classes (luanti-lua.md:84-94,
:289-302); accidental global writes. **`pairs()`:** not applicable, static.
**Disposition A and B:** UNCHANGED. Both outcomes depend on them — they are
the only gates that catch the silent-escape class at all.

### 4.3 PUC-K1 `run_t0.sh`, PUC-K2 `run_t1.sh`, PUC-K3 `tools/wp43/run.sh`

**Interpreter:** all three HARDWIRED PUC — `run_t0.sh:15`, `run_t1.sh:23`,
`tools/wp43/run.sh:7`. **Cost:** 0.05 s and 0.17 s MEASURED (handover:37,
:36); README:455 re-measures `run_t1.sh` at 0.18 s; `tools/wp43/run.sh` is
unmeasured, its sibling `tools/wp43/source_audit.sh` is 0.02 s MEASURED
(handover:38), so 1-10 s PROJECTED. **Why the hardwiring is not a defect:**
luanti-lua.md:336-339 exempts runners "where the runtime is trivially short";
these qualify by two to four orders of magnitude. **Coverage:** T0
material/vocabulary projection; T1 deterministic hashing, canonical encoding,
IPC and index foundation; WP43 material vocabulary. **`pairs()`:** outputs are
pinned digests, so an order dependence would surface as a digest move.
**Trigger:** milestone. **Disposition A and B:** UNCHANGED; free.

### 4.4 PUC-K4 `run_t2_schema_core.sh`

**Interpreter:** HARDWIRED PUC at `run_t2_schema_core.sh:37`. **Coverage:**
compiled transport schema and trust-boundary gate plus the Source audit, T1,
T0 and WP43 (handover:35); it "does not prove compiled geometry".
**Classification of its compiler contact:** trust-path exercise, §3.3.
**Cost:** NOT MEASURED — handover:35, "Source-audit dominated; exact wall time
was not recorded"; PROJECTED 196-591 s by inheriting PUC-K5's band, since it
invokes the same Source harness. **A real duplication to note:** PUC-K4 and
PUC-K5 each run the full Source harness under PUC; running both back to back
pays it twice. **`pairs()`:** assertions are on typed schema shapes and error
names (`expect_error` at `t2_schema_core_test.lua`:415-417), not on emitted
order. **Disposition:** A unchanged; B retained as-is — it is a schema/trust
gate, not a population run.

### 4.5 PUC-K5 `t2_source_audit.sh` full mode

**Command:** `tools/wp40/t2_source_audit.sh .`; mode defaults to `full`
(`:5`), `--static-only` is the alternative. **Interpreter:** HARDWIRED PUC at
`:396` — `env -u WP40_T2_ONLY tools/bin/lua51 tools/wp40/t2_source_test.lua
"$repo" "$scratch"`. There is no `WP40_LUA_BIN` hook anywhere in the file.

**FLAG — latent defect candidate.** This is an executable full-suite run with
no interpreter selection, the exact shape luanti-lua.md:336-342 names a
defect: "every new harness with non-trivial runtime must support interpreter
selection (the `WP40_LUA_BIN` pattern) and must default to LuaJIT; an expensive
runner hardwired to PUC is a defect, not a conservative choice."
`run_t2_s1_authority.sh` was the previous live example, fixed the day the
principle was written (luanti-lua.md:343-344). Its runtime is not discoverable
from source, so whether it *is* a defect turns on a measurement nobody has
taken.

**Cost:** NOT MEASURED — handover:34, "Several minutes in the retained final
chain; exact wall time was not recorded". Two PROJECTIONS, both shown: the
floor is the stale PUC anchor 195.56 s (README:108); the scaled figure
accounts for the harness growing from 30.05 s to 90.81 s under LuaJIT
(README:108, :110, :456), giving 195.56 x (90.81 / 30.05) = **591 s**.
README:110 instructs "Plan with the later number." **Risk covered:** the
complete R19 Source/Reality harness including retained Source oracles and
rollback mutations, under the language contract. **`pairs()`:** not
established; the harness compares digests and error strings.
**Disposition:** A unchanged, budget 591 s; B retained, and flagged for the
interpreter-selection repair independently of the ruling.

### 4.6 PUC-K6 `run_dungeon_probe.sh`

**Interpreter:** HARDWIRED PUC at `:5-6`; four `luac51 -p` parses at `:20-23`,
the two audits at `:24-25`. **Population:** source audit, lattice audit, digest
audit, verify-log test; the Flatpak headless leg is opt-in (`:29`,
`WP40_DUNGEON_PROBE_HEADLESS=1`) and hard-bounded by `timeout 180` at `:106`.
**Cost:** NOT MEASURED; PROJECTED 5-60 s non-headless, plus at most 180 s by
construction for the headless leg. **`pairs()`:** not analysed.
**Disposition A and B:** UNCHANGED.

### 4.7 PUC-K7 `run_t2_correction_kat.sh`

**Mechanism:** LuaJIT leg at `:36-37` (SELECTABLE, `:27`), PUC leg at `:38-39`
(HARDWIRED, `:28`), stdout `cmp -s` at `:41` — byte comparison, not exit
status. **Owner:** contracts §8.6.2, cited in the test's own header
(`t2_correction_kat_test.lua`:9-10). **Population:** synthetic descriptor
pairs pinning D1 order keys 2-6, each case re-run under reversed authored
orientation (`t2_correction_kat_test.lua`:1-8); keys 2-6 "are reachable by no
measured configuration over the full `W`" (`:2-4`), which is why they need
synthetic cases at all. **Classification:** unit test on production comparator
functions (§3.4), **not** a full-path witness. **Cost:** NOT MEASURED;
PROJECTED 20-111 s for the PUC leg — the high anchored on
`run_t2_s1_authority.sh`'s MEASURED 111 s PUC (README:420), the only measured
cost of a validation-heavy production-module harness under PUC; the low
assumes module load dominates. **`pairs()`:** the comparators take explicit
descriptor pairs; no table iteration reaches the compared output.
**Disposition:** A unchanged; B retained inside the bounded gate as the
control-flow/ordering unit layer.

### 4.8 PUC-K8 `run_t2_s11_acceptance.sh`

**Mechanism:** `luac51 -p` and a SETGLOBAL check on the checker itself
(`:16-20`), the checker under LuaJIT (`:30`) and PUC (`:32`), then both a
stdout `cmp` (`:35`) **and** an exit-code compare (`:40-43`) — the strongest
comparison discipline of any runner in this inventory.
**Classification:** COMPARATOR-ONLY (§3.2). A `grep -n` for
`dofile|require|loadstring` over the 380-line checker returns exactly one hit,
`:41` `local repo = assert(arg[1], "repository root required")` — the word
"required", not a call. No module load exists in the file. **Population:** six committed
tables under `tools/wp40/fixtures/t2_census/`, byte-compared against
artifacts, plus the §11.11 numeric pins at `t2_s11_acceptance_check.lua`:48-77
(adoption 118 lines / 119 chains, family-B 105 stations, max join distance 12,
carriers 796). **Cost:** NOT MEASURED; PROJECTED 1-10 s per leg — fixture
reads and row counts, no module load. **`pairs()`:** deliberately excluded, and
the code says so at `:134` — "Deterministic: the caller supplies the key order,
never pairs()." **Disposition A and B:** UNCHANGED; cheap, and it is the
committed proof of the §11 ledger.

### 4.9 PUC-K9 the census-gates Scan-3b/4 synthetic classifier KAT

**Mechanism:** `run_t2_census_gates.sh`:408-425 — `luac51 -p` on the KAT
(`:408`), LuaJIT run (`:414-415`), PUC run (`:418-419`), `cmp -s` (`:423`),
then a non-zero check-count assertion (`:426-430`). **Rationale, verbatim from
`:401-403`:** "The comparison is on bytes rather than on exit status: two runs
that disagree about a classification would both still print 'passed' and exit
zero, which is the failure this suite exists to catch." **Owner:** contracts
§9.4, cited at `:398` and stated at contracts:1259-1260. **Population:**
synthetic classifier cases that "exist exactly where no measured configuration
reaches the branch" (`:399-400`). **Cost:** NOT MEASURED; PROJECTED 20-111 s
for the PUC leg, same derivation as PUC-K7. **`pairs()`:** the KAT drives the
classifier with explicit inputs; the ordering risk sits in the merge.
**Disposition:** A unchanged; B retained inside the bounded gate.

### 4.10 PUC-K10 `run_t2_census.sh --merge-kat`

**Mechanism:** `run_t2_census.sh`:746-761. The worker KAT runs first under the
selected interpreter (`:755-756`, LuaJIT by default), then `run_merge_pair`
folds those records twice — LuaJIT into scratch, PUC into scratch — and
byte-compares five artifacts (`:239-276`), followed by a pinned-digest gate at
`:759-760`.

**Population — CORRECTION.** The worker KAT roster is **seven** seeds, not
four: `0`, `2147483648`, `343674299183575008`, `1959553668008863006`,
`15219119262482319357`, `16178445837170081103`, `18446744073709551615`
(`t2_census_worker.lua`:92-93). The comment at
`run_t2_census_gates.sh`:468-469 still says "a four-seed worker KAT"; it is
stale relative to a roster that grew at M5, at the stage-reject package and
again with the Scan-3b/4 package (`t2_census_worker.lua`:84-91).

**Cost — CORRECTED.** The "about two and a half minutes" at
`run_t2_census_gates.sh`:468-470 is explicitly "of **scanning**", and the scan
it refers to runs under `"$lua_path"` (`run_t2_census.sh`:755), i.e. LuaJIT by
default. It is therefore **LuaJIT worker time, not PUC merge time**, and it
must not be used to price the PUC leg. The merge's own KAT-scale cost is on
record: contracts:706 names "the KAT's 0.06 s". The PUC merge half is therefore
PROJECTED at **0.1-2 s**, taking 0.06 s as the floor and allowing the full
census-band ratio on top. The whole `--merge-kat` command remains ~150 s,
MEASURED-qualitative, and that is what the PCC pays in §7.5.

**`pairs()` — THE LOAD-BEARING FACT.** Seven seeds is at or below
`free_seed_budget = 64` (`t2_census_authority.lua`:61), and the merge is
invoked in `--records` mode (`run_t2_census.sh`:758 ->
`t2_census_merge.lua`:67-69). The guard at `t2_census_merge.lua`:1521
(`if mode == "records" and #state.seeds <= authority.free_seed_budget then`)
is therefore **satisfied**, and the measured invariance half executes here.
This is the only place in the repository where it can execute — see §4.19 for
why the full-`W` reading cannot. Caveat, stated: the merge-KAT writes into
scratch and its divergence line lands in a manifest that is not covered by the
compared `artifacts_digest` (`t2_census_merge.lua`:1503-1505), so **no
retained artifact records that the measured half passed**. Every committed
manifest — `census-manifest-v1.tsv`:20, `-v2.tsv`:20, `-v3.tsv`:20 — records
`measured_invariance=not_run_above_free_budget`.

**Disposition:** A unchanged; B **promoted** — the measured half becomes
mandatory and its result becomes recorded evidence rather than transient
scratch.

### 4.11 PUC-K11 `run_t2_extreme_puc_kat.sh`

**Interpreter:** HARDWIRED PUC at `:11`, checked executable at `:12-13`,
echoed at `:31`. **Classification:** FULL-PATH for the **selector** stage — it
loads `geometry/extreme.lua` through `authority.load_module`
(`t2_extreme_puc_kat.lua`:168-171) and drives the production entry points.

**Population — exactly one candidate plus two scalars.** `session("0")`
(`:158`) and `session("18446744073709551615")` (`:159`), digest-asserted at
`:162-166`; `seed_corpus.extreme_candidate(0, raw_sha256)` (`:172`) with
constants at `:173-176` (`first8 == "2e0c0041e1bcc0ab"`,
`decimal == "3318027308425330859"`); `extreme.score_candidate(0)` (`:177`)
with `row.coast_n == 1972811` and the rest at `:178-182`;
`extreme.candidate_shard({row}, 0, 0, pins)` (`:202`) with
`rows_sha256 == "a1cf557c…"` asserted at `:206-208`.

**Cost:** NOT MEASURED. Two PROJECTIONS, both shown. Low: three scalar
sessions x 10.7 s LuaJIT (README:413, "S1 scalars, one seed") = 32.1 s LuaJIT,
at the **selector-scalar** ratio 5.3x (README:420) = **170 s**. The census
band is deliberately *not* borrowed here: §2.3 forbids carrying a ratio across
workloads, and this KAT is a selector-scalar workload, which is the same class
`run_t2_s1_authority.sh` measured. High: the closest measured PUC
anchor is "seed-0 + max-u64 + traversal, PUC, uncached | 3,091 s"
(README:416), which shares seed 0 and max-u64 with this KAT's two sessions;
whether the KAT's workload *is* that workload is **not determinable from
source**, so 3,091 s is carried as a conservative high rather than an asserted
identity. **`pairs()`:** neutralised by an explicit sort in the canonical
encoder at `:79-81`. **Disposition:** A unchanged; B **extended** — it becomes
the SELECTOR full-path witness, widened from candidate 0 to candidate 0,
candidate 4095 and the four winner slots (§7.2).

### 4.12 PUC-K12 the contracts §9.4 full-path witness per new tier

**Obligation, verbatim (contracts:1253-1261):** "PUC 5.1 is targeted KATs
byte-compared by digest, with **at least one full-path witness per new tier**:
one full v6 worker record for 2147483648 (Scan-3b plus the face tier through a
real non-simple classification) and one for winner 16178445837170081103
(Scan-3b plus green face and Whole tiers), LuaJIT/PUC digest-identical; the
synthetic classifier KATs run under both interpreters; the merge keeps its
LuaJIT/PUC artifact-identity gate. No comprehensive PUC round — that is
T2-final's."

**Classification:** FULL-PATH for the **worker** stage
(`t2_census_worker.lua`:300, `partition.census_scan`). **Runner:** none. It is
executed ad hoc by invoking the worker with an explicit seed list under
`WP40_LUA_BIN` pointed at `tools/bin/lua51` — a documented obligation with no
committed entry point, the same structural weakness as PUC-K13, though unlike
PUC-K13 it has actually been run and its results are recorded.

**Cost, MEASURED, three readings:** <=25 min/seed against a 66.5 CPU-s/seed
LuaJIT mean, i.e. <=22.6x
(`results/bay-transition-2c-stop-artifacts/stop-report.md`:135-140, :165-168);
22 min for a concurrent pair against 69.3 CPU-s/seed, 19.0x
(`results/bay-transition-package-final-artifacts/README.txt`:32); ~23 min each
against 49.8 CPU-s/seed, 27.7x
(`results/bay-transition-package-stop-artifacts/stop-report.md`:115).

**THE RATIO BAND THIS ESTABLISHES: 19-28x on the census-worker workload**
(19.0x, 22.6x and 27.7x — the third computed above from 23 min against
49.8 CPU-s/seed, 1,380 / 49.8 = 27.71).
It is the **only** measured PUC/LuaJIT band on the census workload and the only
band §5.2 may use. State loudly: the 5.3x reading from
`run_t2_s1_authority.sh` (111 s / 21 s, README:420) is a **validation and
selector-scalar** workload and must not be used to project the census.

**`pairs()`:** the worker emits sorted records; the ordering risk is
downstream in the merge. **Disposition:** A unchanged; B **retained and given a
runner** — it becomes the WORKER full-path witness of the bounded gate (§7.2).

### 4.13 PUC-K13 the contracts §8.6.2 full-compile-path witness pair — **UNCLOSED**

**Obligation, verbatim (contracts:970-984, point 2):** "…**and at least one
full-compile-path D1 witness pair (elbow witness 1959553668008863006 plus one
multi-complete edge witness) compiled solo under PUC and digest-compared
against LuaJIT** — byte-compared by digest between interpreters. The addition
is the gate-1.5 condition (2026-08-18): the synthetic KATs drive only the
comparator under PUC, and the new R19 enumeration path needs at least one
end-to-end PUC exercise against its `pairs()`-order risk. No comprehensive PUC
round (reserved for T2-final, per the interpreter split in the brief and
[luanti-lua.md](luanti-lua.md))."

**The driver exists.** `tools/wp40/t2_correction_repro.lua` is written for
exactly this; its header at `:1-13` says the interpreter split "byte-compares
this output between LuaJIT and PUC 5.1 for the gate-1.5 witness pair", and its
argv contract is at `:14-18` (repo, a scratch path matching
`^/tmp/grudgelands%-wp40%-t2%-census%.[A-Za-z0-9]+$`, then one or more witness
seeds). Classification: FULL-PATH for the **compiler** stage
(`partition.compile`, module chain at `:24-40`).

**THE GAP.** A repository-wide `grep -rn "t2_correction_repro"` excluding
`reference_projects/` and `.git/` returns **zero hits**. No `run_*.sh` invokes
it; no document references it. `run_t2_correction_kat.sh` compares a
*different* file (`t2_correction_kat_test.lua`, the synthetic comparator KAT).
**No runner performs the §8.6.2 byte-compare.** The obligation is written, the
tool is written, and nothing wires them together.

**A second defect in the same sentence.** contracts:983 points at "the
interpreter split in the brief". `grep -ci` over
`docs/research/wp40-engineering-brief.md` returns **0** for each of `PUC`,
`T2-final`, `T9-final` and `lua51`, across 4,126 lines. The cross-reference is
dangling; only the `luanti-lua.md` half of it resolves.

**Two further human-only entry points.** `tools/wp40/t2_face_ring_probe.lua`
and `tools/wp40/t2_whole_gap_probe.lua` are likewise referenced by no `.sh`
and no `.md`. Both are diagnosis tools, so their unreachability is not a gate
gap, but it is the same pattern.

**Cost:** UNMEASURED, because it has never run as a gate. Nearest anchor is
README:415, seed-0 compile PUC 868 s MEASURED; a two-seed pair is therefore
PROJECTED at roughly 1,700-3,000 s serial, or ~870-1,500 s with the two seeds
concurrent. **`pairs()`:** this is the obligation's stated purpose —
contracts:980-982, "the new R19 enumeration path needs at least one end-to-end
PUC exercise against its `pairs()`-order risk."
**Disposition:** A — **this gate is currently unmet and stays unmet** unless a
runner is written. B — **closed by construction**: the COMPILER witness of
§7.2 is exactly this pair, given a runner.

### 4.14 PUC-K14 `run_t2_census_probe.sh` — recorded for completeness, not a PUC gate

**Interpreter:** SELECTABLE, LuaJIT default (`:44`), path echoed at `:50`; it
has **no PUC leg**. **Population:** five probe seeds (`:63-64`) —
`0 2147483648 14069824983701673 1959553668008863006 16178445837170081103` —
justified individually at `:52-62`: seed 0 as control, the two F10
face-simplicity witnesses, the R19-heavy winner that pays a green Whole tier,
and the first non-member in `W` order as the marginal case. **Why it is
listed:** it is named in cost discussions and could be mistaken for a PUC
obligation. It is the contention and per-seed-cost probe that precedes a fleet
launch (contracts:936-938). **Disposition A and B:** UNCHANGED.

### 4.15 PUC-F1 `WP40_FINAL=1 run_t2_partition.sh --no-cache --historical`

**Command, stated as an instruction inside executable code** at
`tools/wp40/run_t2_partition.sh`:11-13:

> `# T2-final must use the fallback interpreter, bypass the payload cache, and`
> `# include the retained historical-provenance check:`
> `#   WP40_FINAL=1 tools/wp40/run_t2_partition.sh --no-cache --historical`

This is a live T2-final authority hit in a `.sh` file — the **only**
executable file in the repository containing the string `T2-final`
(Appendix B) — and it is absent from the acceleration plan's fold-in list at
:283-286 and :713-728.

**Interpreter:** CONDITIONALLY PUC-FORCED at `:91-95`:
`if [[ "$final" == 1 ]]; then lua_bin="$repo/tools/bin/lua51"; else
lua_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"; fi`.
**Gate semantics (README:126-135):** `WP40_FINAL=1` "is the plain-5.1
compatibility gate that `AGENTS.md` makes a hard requirement. It forces the
vendored PUC interpreter, bypasses the payload cache, runs every phase and
includes the historical block, and it rejects `WP40_T2_ONLY` so it cannot be
run partially. A bare invocation does **not** satisfy that requirement." The
rejection is enforced at `run_t2_partition.sh`:37-38.

**Parallelism — A CONFLICT TO REPORT, NOT RESOLVE.** The runner is strictly
serial: `:106-110` are two sequential single-process `"$lua_path"` invocations
and nothing else. It cannot shard itself, and `WP40_FINAL=1` rejects the only
phase selector it has. Yet README:418 records "full partition gate, PUC, 8-way
sharded | ~62 min wall" while handover:50 records "The last complete pre-C2
serial PUC run took about 53 min; current cost is unmeasured". A sharded run
reading *slower* than a serial one means one of the two is mis-scoped. Both are
MEASURED. This memo uses 53-62 min as a band and flags that the ~62 min
reading cannot be reproduced by the T2-final command as written.

**Resumability / abort:** none; it fails closed on any incomplete or invalid
seeded geometry (README:137-138). **Risk covered:** phase breadth —
exact/rational and raster regression fixtures, the private partition-family
construction, every phase, plus the retained historical-provenance block. No
seed-level witness reproduces phase breadth. **Artifacts:** pass/fail plus its
retained fixtures; no published digest artifact. **`pairs()`:** not established
for this runner. **Disposition:** A unchanged, budget 62 min; B (coordinator's
scoping) **RETAINED inside the bounded gate** — §11.

### 4.16 PUC-F2 `run_t2_extreme_conformance.sh` (the C1 conformance gate)

**Post-closeout correction.** The trace below described the pre-v3 chain at
the inventory baseline. Current F2 is the accepted C1-v3 chain: it reads
`candidates-luajit-v3.tsv` / `manifest-luajit-v3.tsv`, writes 20
`rescore-puc-v3-*` rows, four `selected-puc-v3-slot*` rows and final
`conformance-puc-v3.tsv`, and may reuse them only through its recorded-commit
closure proof. The population remains the same fixed 20 candidates and slots
28--31. It completed green at commit `5d770365`, final artifact SHA-256
`7ac6b7f9…`; timings are recorded below. Any unqualified pre-v3 filename in
the historical trace that follows is not a current path instruction.

**Interpreter:** HARDWIRED PUC at `:12-13`, with a hard guard at `:26-29`
("WP40 T2 C1 requires the vendored PUC Lua 5.1 tools"). **Prerequisite:** a
committed, independently reviewed immutable conformance commit — preflight at
`:30-35` binds commit, tree and DAG; `fixtures/t2_extreme_e0/README.md`:25-28
states that "Implementation bytes alone are not evidence: the C1 launcher may
run only from an independently reviewed immutable conformance commit…".

**Population, literal:** 20 rescore candidates at `:85-86` —
`0 511 512 1023 1024 1047 1535 1536 1713 2047 2048 2192 2559 2560 3071 3072
3438 3583 3584 4095` — and 4 selected slots at `:87` — `28 29 30 31`.
**Barriers:** hard 20/20 rescore barrier at `:196-199` with a re-verification
loop at `:200-203` before the selected phase may start; hard 4/4 selected
barrier at `:274-281`; final artifact written last at `:284-290`.
**Parallelism:** rescores in waves of 16 (`:139`), memory rationale at
`:137-138` ("One real retained C1 PUC rescore worker peaked at 455084 KiB;
sixteen stay below the 58 GiB host-memory limit"); the four selected workers
run concurrently (`:226-239`). **Resumability:** resumes verified existing
results (`:120-134`, `:209-223`), self-invalidates stale ones against the
current commit (`:127-129`, `:216-218`), short-circuits on a complete
`conformance-puc.tsv` (`:69-77`), publishes atomically cp -> cmp -> `mv -T`
(`:101-115`).

**Comparison basis — IMPORTANT.** PUC is compared against **committed LuaJIT
fixtures**, not a live LuaJIT run: `t2_extreme_rescore_worker.lua`:129-132 and
`t2_extreme_conformance_verify.lua`:136-139 both parse
`fixtures/t2_extreme_e0/candidates-luajit.tsv` and `manifest-luajit.tsv`, and
`t2_extreme_conformance.lua`:321-327 pins the eight
`shard-luajit-%04d-%04d.tsv` paths and their SHA-256s. This is a stronger
provenance discipline than a live pair and is why the round is reproducible
from an archive.

**Cost:** the historical failed attempt was incomplete. The completed C1-v3
acceptance measured 20 PUC rescores in 215 s, four parallel selected slots in
5,507 s, and approximately 99 minutes end to end. **Risk covered:** conformance
breadth over the ranked pool — exact retained-row rescoring under the language
contract plus four full-partition gates on the selected winners with no
fallback (README:486-498). No seed witness reproduces this.
**Artifacts:** `rescore-puc-*.tsv` (resume state, not evidence — README:326-331),
`selected-puc-slot*.tsv`, and `conformance-puc.tsv` written last.
**`pairs()`:** not established for this runner. **Disposition:** A unchanged;
B (coordinator's scoping) **RETAINED**.

### 4.17 PUC-F3 the census merge PUC publication leg

**Command:** `tools/wp40/run_t2_census.sh --merge` (`:762-785`).
**Interpreter:** HARDWIRED PUC at `:197`, justified at `:768-770` — "the merge
itself refuses to write there under anything but the vendored PUC, so the
LuaJIT half of the pair runs into scratch and is the comparison." This
hardwiring is **justified**, not a defect: only PUC may publish into the
committed fixtures.

**Mechanism (`run_merge_pair`, `:239-276`):** LuaJIT merge first (`:246-247`);
its `artifacts_digest` extracted from `census-manifest-v3.tsv` (`:249-250`);
PUC merge second, handed that digest up front via `--expect-artifacts-digest`
(`:255-256`) so it checks before it writes anything (rationale at `:193-196`);
then a five-artifact `cmp -s` (`:257-268`) over
`census-occupied-classes-v3.tsv`, `census-vacuous-branches-v3.tsv`,
`census-scan4-seed-set-v3.tsv`, `census-prefilter-discharge-v3.tsv` and
`census-histograms-v3.tsv`.

**Cost — A CONFLICT TO REPORT, NOT RESOLVE.** contracts:706-708 for run 4:
"The merge's own cost … is **about seven minutes**, the LuaJIT half under one"
— i.e. a PUC half of roughly six minutes, MEASURED. Run 6's merge was *larger*
(inputs=9 against run 4's inputs=8, and v6 records exceed v5's 96 MB per
contracts:1298), yet `results/merge6.log`:21 reads
`MERGE2_TIME wall=19.29s cpu_user=18.17s cpu_sys=0.63s maxrss=519984kB`. This
memo **could not determine what `MERGE2_TIME` brackets**: a
`grep -rn "MERGE2_TIME"` over the tracked tree returns nothing, so no emitter
is under version control. Planning uses the conservative ~6 min PUC-half
reading; 19.29 s is named as the optimistic one.

**Artifacts and authority:** the five v3 TSVs plus `census-manifest-v3.tsv`,
published into `tools/wp40/fixtures/t2_census/`; the manifest carries
`w_digest`, `w_derivation` and the divergence-test line (`:12`, `:14`, `:20`).
**`pairs()`:** this leg carries the divergence test's **probe and synthetic
halves only**. Its measured half cannot run here — 4,123 seeds is far above the
64-seed budget of `t2_census_merge.lua`:1521 — which is exactly why the
disposition below assigns the measured half to PUC-K10 (§4.20).
**Disposition:** A unchanged; B **retained unchanged as the population-merge
parity leg** — the five-artifact LuaJIT/PUC `cmp` over the full 4,123-seed
merge. It **cannot** carry the MERGE full-path witness or the mandatory
measured divergence half: `t2_census_merge.lua`:1521 gates the measured half at
`<= free_seed_budget` = 64, and 4,123 is not. Both of those belong to PUC-K10,
and §7.2/§7.3 assign them there. This is the same argument as §4.19's decisive
consequence, applied to the merge leg itself.

### 4.18 PUC-F4 the `fixtures/t2_extreme_e0/README.md` pool obligation

**Text, verbatim (`tools/wp40/fixtures/t2_extreme_e0/README.md`:22-29):**
"Once all retained shards exist, PUC Lua 5.1 must separately parse and rank
every row, rematerialize the deterministic shard endpoints plus the four
winners, and run the four selected full-partition gates. Implementation bytes
alone are not evidence: the C1 launcher may run only from an independently
reviewed immutable conformance commit, and no `rescore-puc-*`,
`selected-puc-*`, or `conformance-puc.tsv` file is evidence until every closed
gate records that commit. It does not claim a second 4096-row origin."
README:468-473 states the same obligation in the tools README.

This is a **live PUC obligation stated in a fixtures README** — a location the
acceleration plan's fold-in list does not cover. It is realized by PUC-F2, with
one wording gap worth naming: the README says PUC "must separately parse and
rank **every row**" (4,096) while the runner's rescore population is the 20
candidates at `:85-86`. The reconciliation is that parsing and ranking all
4,096 rows is the merge/rank step while *rescoring* is the 20; the README's
wording does not draw that distinction, and a reader could take it as a
4,096-candidate PUC rescore. **Disposition:** A unchanged; B retained, wording
clarified in the atomic fold-in (§12).

### 4.19 PUC-F5 the full-`W` population under standalone PUC — **THE DISPUTED READING**

**Source of the dispute:** contracts:1582-1584 (quoted in §1.4) — the **only
sentence in the repository** that couples the full-`W` re-census to a PUC
round.

**Nine unambiguous re-census sentences, each a pure scheduling statement with
no interpreter claim:** contracts:1595 ("the new measured truth over `W` lands
at T2-final's re-census"), :1703-1704, :1818-1819, :1876-1877, :1946,
:1996-1997 ("T2-final's full-`W` re-census re-verifies the pin over the whole
universe"), :2096-2097, :2237-2239, and acceleration-plan:106-107. All nine
were opened. Not one mentions an interpreter.

**Counter-evidence that reading (b) was never intended:** contracts:938, on the
§8.5 full-`W` fleet — "All under **LuaJIT** per the interpreter split";
acceleration-plan:461-462, which lists "the full-`W` re-census" and "the agreed
PUC conformance gate" as two **separate** items in the same sentence; and the
published manifest itself, which records `worker_interpreter_id luajit`
(`census-manifest-v3.tsv`:9) beside `merge_interpreter_id puc_lua51` (`:15`) —
the split is already in the committed evidence.

**Population:** |W| = 4,123, re-derived at run time rather than read from a
list — `t2_census_authority.lua`:1252 `derive_w(corpus, candidate_bytes,
hasher)` over 27 fixed corpus seeds (`seed_corpus.lua`:116,
`#corpus.fixed ~= 27`) plus 4,096 pool candidates (`seed_corpus.lua`:105-111),
duplicates = 0; committed at `census-manifest-v3.tsv`:13-14. Eight shards cover
`W` exactly once, asserted rather than assumed
(`t2_census_authority.lua`:1181-1192, "shard ranges do not cover W").
**Gating:** the GO token **is** the `W` digest (`:1322-1327`), so a worker can
check it against its own derivation; free runs without a token are capped at 64
seeds (`:1339-1341`).

**Cost:** §5.2 — PROJECTED 1,512-2,216 CPU-h; 7.9-11.5 days at a full width of
8; ~13-19 days elapsed on this host at the measured effective width.

**THE DECISIVE CONSEQUENCE.** Running the full-`W` population under standalone
PUC would **not** buy the measured `pairs()`-divergence check: the code refuses
it above 64 seeds (`t2_census_merge.lua`:1521; `free_seed_budget` = 64 at
`t2_census_authority.lua`:61). Only a **bounded** corpus can execute it. On
this axis the bounded gate is strictly **stronger** than the comprehensive
round, not weaker. **Disposition:** A — the ambiguity persists and must be
budgeted at the §5.2 figures. B — **ruled out explicitly** by the §8.1 wording.

### 4.20 The `pairs()`-order divergence gate — where it lives and what it has never done

Not a separate runner: a property of PUC-F3 and PUC-K10, and the sharpest
finding in this inventory.

**It lives in `tools/wp40/t2_census_merge.lua`, not in any shell script.**
Design note `:1118-1126`. Probe half `:1128-1145` — 64 probe keys, returns
`not sorted_already`. Fail-closed guard `:1500-1512` — a runtime whose
`pairs()` comes back sorted **aborts** the merge rather than passing vacuously
("a gate that cannot fail is the failure this branch has already shipped
twice"). Synthetic invariance half `:1513-1515`.

**The measured half is gated to a bounded seed set.** `:1516-1521`, comment
verbatim: "The measured half runs where the records fit in memory twice, which
is exactly the KAT case the M5 gate runs; a full-`W` set is folded once and
rests on the synthetic half"; then
`local record_invariance = "not_run_above_free_budget"` and
`if mode == "records" and #state.seeds <= authority.free_seed_budget then`.
The contract clause it implements is contracts:519 and :1296-1299.

**It has never run in measured form in any retained evidence.** Verbatim, four
times: `WP40 T2 census divergence test probe_unsorted=true synthetic=passed
measured=not_run_above_free_budget` at `results/merge4.log`:10 and `:19`, and
`results/merge6.log`:10 and `:19`. In-tree and therefore citable without the
gitignored results directory:
`tools/wp40/fixtures/t2_census/census-manifest-v3.tsv`:20 records
`measured_invariance=not_run_above_free_budget`, as do
`census-manifest-v1.tsv`:20 and `census-manifest-v2.tsv`:20. contracts:761-767
records the same and names the reason: "96 MB of records do not" fit twice. It
is structurally reachable today at PUC-K10's 7 seeds (§4.10), but that run's
evidence is scratch and its divergence line is not covered by the compared
digest (`:1503-1505`) — reachable, never recorded.

**Why it earns its keep.** contracts:508-524: on its first run it found a real
order dependence in the merge — a site can realize the same branch through more
than one row of one seed, and "the first such row" was an arrival-order choice.
The witness rule is now the least row of the least seed.

**Remaining unsorted `pairs()` on the merge path, both audited.**
`t2_census_merge.lua`:218 (`for name in pairs(authority.classes)`) builds a
membership **set** and is order-immune (`:214-223`); `:340`
(`for tag in pairs(rows)`) is reached only on an already-failing strict path
and can vary only the **error message**, not any artifact (`:335-345`).
Emission order is structurally sorted: `sorted_keys()` `:144-149`,
`sorted_seeds()` `:151-156`, and the rendering note at `:761-764` — "no float,
no clock and no iteration order reaches an artifact byte".

**The plan's own framing.** `wp40-t2-plan.md`:474-477 calls this test "the
cheap substitute for a full PUC gate at every stage freeze", because "the
canonical encoder sorts before emission, so serialisation is provably
runtime-independent; control flow that depends on iteration order is the
residual risk and can be tested directly."

### 4.21 PUC-F6 the T9-final comprehensive PUC round — **NO COMMAND IS DEFINED**

Exactly five files contain the string `T9-final`: `AGENTS.md`,
`docs/process/wp-workflow.md`, `docs/research/luanti-lua.md`, the acceleration
plan and `tools/wp40/README.md` (Appendix B). All five are policy statements of
the form "reserve comprehensive PUC rounds for T2-final and T9-final". **None
names a command, a population, an artifact or a budget.**

The only concrete T9 obligation in the repository touching the fallback
interpreter is not a standalone-PUC round at all: `tools/wp40/README.md`
:1147-1152 — "A bundled Lua 5.1 engine measurement and the full cold/warm
repetitions remain T9 gates; plain-5.1 source compatibility is checked
separately with `tools/bin/luac51`." That is an **engine** measurement
(ENG-2), and the sentence itself separates it from the static source check.

**Consequence for the ruling:** whatever the user decides about T2-final, "the
T9-final comprehensive PUC round" is at present an unspecified obligation.
Under A it must be specified before it can be budgeted; under B it is defined
by the same bounded gate. **Cost:** undefined, because the population is
undefined. No projection is offered; inventing one would be the error
`wp40-t2-plan.md`:352-355 warns against.

### 4.22 ENG-1 the real fallback-engine runtime gate

**Owner, four independent statements.** luanti-lua.md:369-371 (layer 6): "a
real fallback-engine runtime test remains a separate release/runtime gate.
Neither standalone interpreter has Luanti's `builtin/`, sandbox or `core.*`, so
offline equality cannot replace it." wp-workflow.md:79-80: "A real
fallback-engine run is a separate runtime gate and is never inferred from
standalone LuaJIT/PUC equality." AGENTS.md:142-143: "The real fallback-engine
runtime test is still a separate user-run gate." tools/wp40/README.md:115: "A
real fallback-engine runtime test remains a separate gate."

**Why it is separate, from the engine facts.** luanti-lua.md:63-69: the engine
prefers LuaJIT but does not require it; without LuaJIT the build silently falls
back to the bundled PUC Lua 5.1.5, patched with a custom `lua_atccall` hook so
C++ exceptions can cross the Lua stack. A standalone `tools/bin/lua51` has
neither that patch nor `builtin/`, the sandbox, or `core.*`. **Who runs it:**
the user — agents cannot run the Flatpak GUI (wp-workflow.md:75-78).
**Cost:** UNMEASURED. **Disposition:** **UNCHANGED AND UNWEAKENED under both A
and B.** No result in this inventory, and no result the bounded gate could
produce, satisfies it.

### 4.23 ENG-2 the dual-runtime engine benchmarks

**Origin.** `docs/research/mapgen-control.md`:1586-1590 requires each benchmark
result to record "engine commit, game commit, seed, mapgen settings,
chunksize, `num_emerge_threads`, **LuaJIT versus bundled Lua 5.1**, hardware,
and whether caches are warm", with p50/p95/max callback time, total chunk time,
chunks/s, peak memory/RSS, Lua allocation/GC, buffer counts, modified voxel
count, lighting/liquid calls and main-thread step latency.

**The brief's binding form.** `wp40-engineering-brief.md`:3306-3315 repeats the
manifest requirement and adds the gate — "The same relative gates are evaluated
against the corresponding baseline for **both Lua runtimes**"; :3465-3473 makes
the machine-readable samples, harness logs, environment manifest, exact
commands, summary tables, failures and SHA-256 checksums **mandatory
pre-integration outputs**; :4095 carries "microbenchmarks" in the T9 acceptance
row.

**Cost:** UNMEASURED. `tools/wp40/README.md`:1147-1152 records that the
bundled-Lua engine measurement and the full cold/warm repetitions remain T9
gates, and :1149-1150 records that the filesystem page cache is currently
uncontrolled, so T0 labels it unknown and makes no cold-cache claim.
**Disposition:** **UNCHANGED AND UNWEAKENED under both A and B.**

## 5. Cost

### 5.1 Table 1 — the current unambiguous minimum PUC cost

Every PUC leg binding today, **excluding** any full-`W` population run.
PUC-K12 and PUC-K13 are included: both are binding INTERMEDIATE obligations,
and §9.1 budgets both, so leaving them out would have understated the total.
Single-process serial wall seconds. Where a range is given, the low and high
readings are both carried.

| ID | leg | low (s) | high (s) | label | basis |
|---|---|---:|---:|---|---|
| PUC-S1..S3 | static gates | 10 | 30 | MEASURED-qualitative | handover:40 "Seconds" |
| PUC-K1 | `run_t0.sh` | 0.05 | 0.05 | MEASURED | handover:37 |
| PUC-K2 | `run_t1.sh` | 0.17 | 0.18 | MEASURED | handover:36, README:455 |
| PUC-K3 | `tools/wp43/run.sh` | 1 | 10 | PROJECTED | sibling `source_audit.sh` 0.02 s MEASURED, handover:38 |
| PUC-K4 | `run_t2_schema_core.sh` | 196 | 591 | PROJECTED | inherits PUC-K5's band (handover:35 "Source-audit dominated") |
| PUC-K5 | `t2_source_audit.sh` full | 196 | 591 | PROJECTED | floor README:108; scaled 195.56 x (90.81/30.05), README:108 and :110 |
| PUC-K6 | `run_dungeon_probe.sh` | 5 | 60 | PROJECTED | four `luac51 -p` + two audits; headless leg opt-in, `timeout 180` at :106 |
| PUC-K7 | `run_t2_correction_kat.sh` PUC leg | 20 | 111 | PROJECTED | high anchored on 111 s PUC, README:420 |
| PUC-K8 | `run_t2_s11_acceptance.sh` PUC leg | 1 | 10 | PROJECTED | no module load; fixture reads only |
| PUC-K9 | census-gates Scan-3b/4 PUC leg | 20 | 111 | PROJECTED | same anchor as PUC-K7 |
| PUC-K10 | `--merge-kat` PUC merge half | 0.1 | 2 | PROJECTED | contracts:706 "the KAT's 0.06 s" as the floor; the ~150 s is LuaJIT scan time (§4.10) |
| PUC-K11 | `run_t2_extreme_puc_kat.sh` | 170 | 3,091 | PROJECTED | low 3 x 10.7 s x **5.3** (selector-scalar, README:420); high README:416 |
| PUC-K12 | §9.4 worker witness pair, serial | 2,640 | 3,000 | MEASURED per-seed | 22-25 min/seed (§4.12); 1,320-1,500 s if the pair runs concurrently |
| PUC-K13 | §8.6.2 compiler witness pair, serial | 1,700 | 3,000 | PROJECTED | README:415 seed-0 compile PUC 868 s; ~870-1,500 s concurrent |
| PUC-F1 | `WP40_FINAL=1` partition gate | 3,180 | 3,720 | MEASURED | 53 min handover:50 / ~62 min README:418 |
| PUC-F2 | `run_t2_extreme_conformance.sh` | 4,440 | 5,700 | MEASURED / PROJECTED | 74 min to the failed barrier MEASURED (handover:54); 95 min complete PROJECTED |
| PUC-F3 | census merge PUC half | 19 | 360 | MEASURED, conflicting | merge6.log:21 / contracts:706-708 |
| | **total** | **12,598 s = 3.50 h** | **20,387 s = 5.66 h** | | |

Arithmetic, low: 10 + 0.22 + 1 + 196 + 196 + 5 + 20 + 1 + 20 + 0.1 + 170 +
2,640 + 1,700 + 3,180 + 4,440 + 19 = 12,598.32 s.
High: 30 + 0.23 + 10 + 591 + 591 + 60 + 111 + 10 + 111 + 2 + 3,091 + 3,000 +
3,000 + 3,720 + 5,700 + 360 = 20,387.23 s.

**Basis note, and why §9.3 restates it.** This table is priced
**serial**, per its caption: PUC-K12 and PUC-K13 are the two rows where that
choice is visible, since each is a *pair* of witness seeds and each pair can be
run concurrently. Nothing in outcome A forbids that — it is a modelling choice,
not a policy difference. §7.5 prices the same two obligations **concurrently**,
so the two sections are not on a common basis as written. §9.3 puts both
outcomes on one declared basis before comparing them, and any comparison drawn
straight from these two tables without that step is wrong by 2,150 s (low) and
3,000 s (high).

**CPU.** Every leg except PUC-F2 is single-process, so CPU ~ wall for them:
(12,598 - 4,440) / 3600 = **2.27 CPU-h** low and (20,387 - 5,700) / 3600 =
**4.08 CPU-h** high. PUC-F2 is the only fleet leg, and its CPU is derived, not
asserted: the 20 rescores run in two waves of 16 and 4
(`run_t2_extreme_conformance.sh`:139) inside a 249 s wall, so per-rescore CPU
is ~124.5 s and rescore CPU is 20 x 124.5 = 2,490 CPU-s = 0.69 CPU-h; the
selected phase runs 4 workers concurrently (`:226-239`) for the remaining
4,440 - 249 = 4,191 s (low) or 5,700 - 249 = 5,451 s (high), giving
4 x 4,191 = 16,764 CPU-s = 4.66 CPU-h and 4 x 5,451 = 21,804 CPU-s =
6.06 CPU-h. PUC-F2 total: **5.35 CPU-h low, 6.75 CPU-h high**. Programme
total: **7.61 CPU-h low to 10.83 CPU-h high**.

**Parallelized wall, qualified.** PUC-F1, PUC-F2, PUC-K5, PUC-K11, PUC-K12
and PUC-K13 are mutually independent, so in principle wall collapses to about
the longest leg. But PUC-F2 **on its own** launches waves of 16 workers
(`run_t2_extreme_conformance.sh`:139), which already exceeds the 8-process
guidance at README:439; the other legs therefore cannot be co-scheduled
alongside it under that cap. The realistic schedule is PUC-F2 alone (~95 min),
then the remaining legs across 8 workers (~62 min, PUC-F1 dominating), i.e.
**~2.6 h of wall**, not ~95 min. CPU is unchanged either way.

**Difference from the coordinator's arithmetic, stated.** The coordinator's
pre-brief estimate was 2.8 h (low) to 3.7 h (high) over a leg set that omitted
PUC-K12 and PUC-K13. This memo lands at **3.50 h to 5.66 h**. Three
divergences account for it, in order of size: adding the two witness-pair
obligations contributes +4,340 s low and +6,000 s high; re-pricing PUC-K10 off
the LuaJIT scan figure removes 75-148 s; re-pricing PUC-K11's low onto the
selector-scalar ratio removes a further 440 s. On the coordinator's own leg
set — that is, removing PUC-K12 and PUC-K13 again — this memo would read
12,598.32 - 4,340 = 8,258.32 s = **2.29 h** to 20,387.23 - 6,000 =
14,387.23 s = **4.00 h**, i.e. **above** the estimate at the top end and below
it at the bottom, not inside it. **The dominance claim also moves:** PUC-F1 and
PUC-F2 are now 60.5 % of the low total and 46.2 % of the high, not 87 % / 65 %
— the two witness pairs are a third of the programme once they are counted.

### 5.2 Table 2 — the ambiguous reading's additional cost (PUC-F5)

Base, MEASURED, run 6 (2026-08-19), 4,123 seeds, 8 workers:
`results/t2_census/cost-projection.txt` line 2 —
`cpu_seconds=36040 workers=8 budget_seconds=115.24 per_seed_cpu_seconds=69.84
completions=516 shards=8 observed_cpu_seconds=36040 verdict=passed`.

Fleet CPU = 4,123 x 69.84 = **287,950 CPU-s = 79.99 CPU-h** (MEASURED).
Cross-check: 36,040 CPU-s per worker x 8 = 288,320 CPU-s, agreeing to 0.13 %.
Wall was 36,884 s = **10 h 15 min** (line 1, MEASURED).

| # | derivation | arithmetic | CPU-h | wall at width 8 | label |
|---|---|---|---:|---:|---|
| 1 | direct measured per-seed PUC, low (22 min/seed) | 4,123 x 1,320 s = 5,442,360 CPU-s; / 8 = 680,295 s | 1,512 | 189.0 h = **7.88 d** | PROJECTED from MEASURED per-seed |
| 2 | direct measured per-seed PUC, high (25 min/seed) | 4,123 x 1,500 s = 6,184,500 CPU-s; / 8 = 773,062 s | 1,718 | 214.7 h = **8.95 d** | PROJECTED from MEASURED per-seed |
| 3 | ratio 19.0x on the measured fleet CPU | 287,950 x 19.0 = 5,471,056 CPU-s; / 8 = 683,882 s | 1,520 | 190.0 h = **7.92 d** | PROJECTED |
| 4 | ratio 22.6x | 287,950 x 22.6 = 6,507,677 CPU-s; / 8 = 813,460 s | 1,808 | 226.0 h = **9.41 d** | PROJECTED |
| 5 | ratio 27.7x (census worker, MEASURED — **the upper bound**) | 287,950 x 27.7 = 7,976,224 CPU-s; / 8 = 997,028 s | 2,216 | 277.0 h = **11.54 d** | PROJECTED from MEASURED ratio |
| 6 | ratio 26.5x (seed-0 compile — **wrong workload**, shown for contrast only) | 287,950 x 26.5 = 7,630,683 CPU-s; / 8 = 953,835 s | 2,120 | 264.9 h = **11.04 d** | PROJECTED, not used |

**Band: roughly 1,512-2,216 CPU-h and 7.9-11.5 days of wall at a full width
of 8.** The upper bound rests on derivation 5, the **measured** 27.7x
census-worker ratio (§4.12), not on the 26.5x seed-0-compile ratio this table
itself calls the wrong workload. Applying the measured 4.8/8 effective-width factor (x 1.667) gives
**~13.1 to ~19.2 days elapsed** on this host.

**Excluded ratios, explicitly.** The 5.3x reading (`run_t2_s1_authority.sh`,
111 s / 21 s, README:420) is a validation and selector-scalar workload and is
**not** applicable to the census. The 2.8x payload-cache-hit reading
(README:417) is a cache-hit path and measures nothing about a cold compile.

**What this independently reproduces.** handover:142-145 states, from a
different basis (the observed selected-seed LuaJIT Whole cost), that "a
4,096-seed eight-worker run would be on the order of 2-4 days; a PUC-5.1
equivalent would be on the order of weeks." This memo's 7.9-11.5 days at full
width, 13-19 elapsed, lands inside "weeks" and quantifies
acceleration-plan:256-260's "impractical".

### 5.3 Host and effective width

- AMD Ryzen 7 9800X3D, 8 physical cores / 16 logical, governor `performance`,
  62,825,226,240 bytes = 58.5 GiB RAM
  (`results/t0-baseline/<digest>/host.json`, schema
  `wp40_host_manifest_v1`). Kernel Linux 7.1.8-200.fc44.x86_64.
- README:439: "Up to 8 concurrent Lua processes are appropriate on this host."
- The census fleet is 8 workers **plus** 8 SHA responders on 8 physical cores,
  i.e. 16 runnable threads where the run steadily needs 8 (contracts:313-315).
- Workers run under `chrt --idle 0` plus `ionice -c3` (contracts:251-254), and
  there is **no automatic wall-kill** since 2026-08-18 (contracts:225-235): the
  hard abort moved entirely to the CPU domain.
- **Effective width, MEASURED and used throughout.** The §11 acceptance sweep
  delivered 22.5 CPU-h of records in 4.7 h wall
  (`results/bay-transition-package-final-artifacts/README.txt`:31-32), i.e.
  22.5 / 4.7 = **4.79 effective workers, not 8**. Stated openly: counting the
  9.2 CPU-h of analysis probes as well gives (22.5 + 9.2) / 4.7 = 6.74. This
  memo uses the conservative records-only 4.8/8 factor and names 6.7 as the
  optimistic alternative.
- **Why the projection discipline matters.** contracts:1574-1576 projected the
  same sweep at "projected ≈ 2.5–3 h wall at eight workers on the measured
  60–70 CPU-s/seed band, marked as a projection" — source bytes preserved,
  including the ≈ and the en-dashes. The arithmetic: 1,166 x 65 / 8 = 9,474 s
  = 2.63 h.
  The actual was 4.7 h — **1.79x over** — because the analysis probes were
  outside the projection and idle scheduling left the fleet unsaturated.

### 5.4 Open conflicts, named and not resolved

1. **Merge cost.** ~6 min PUC half (contracts:706-708, run 4) versus 19.29 s
   (`results/merge6.log`:21, run 6, on *larger* inputs). No emitter for
   `MERGE2_TIME` exists in the tracked tree, so what the token brackets could
   not be determined. Planning number: ~6 min.
2. **Partition acceptance gate.** ~53 min serial (handover:50, which also says
   "current cost is unmeasured") versus ~62 min 8-way sharded (README:418), on
   a runner that is strictly serial (`run_t2_partition.sh`:106-110) and that
   rejects its own phase selector under `WP40_FINAL=1` (`:37-38`). One of the
   two readings is mis-scoped.
3. **The 16.2x ratio.** Quoted in README:437 and t2-plan:353 as "16.2x on an
   exhaustive numeric sweep". **No retained underlying measurement exists
   anywhere in the repository.** It is a number without a record. It is not
   used in this memo.
4. **The 4,096-candidate pool wall time.** 91 min (README:419, t2-plan:265)
   versus "100 min 51 s observed" (handover:53, handover:155). Both are
   presented as observations of the same eight-way LuaJIT pool run.

## 6. Risk coverage: what each PUC obligation actually buys

| risk class | evidence of the class | which gate covers it |
|---|---|---|
| plain-5.1 **parser** acceptance | luanti-lua.md:285-287; `goto` fails loudly under `luac51` (:302) | PUC-S1 only |
| **silent-escape divergence** (`\x`, `\u{}`, `\z`) | luanti-lua.md:289-302: `"\x41"` is `A` under LuaJIT and `x41` under PUC 5.1.5; `"a\z  b"` is 2 bytes vs 5 | PUC-S3 (grep sweep 2) **only** — no executable gate detects it, because neither parser errors |
| **numeric behaviour** at +/-(2^53-1) and u64 decimal text | luanti-lua.md:112-115: no integer type, everything a C double, safe range +/-(2^53-1); LuaJIT's 64-bit `bit` cdata semantics do not exist in the fallback build | PUC-K11 (max-u64 scalar, `t2_extreme_puc_kat.lua`:159, :212), PUC-K12, PUC-K13, PUC-F1 |
| **canonical serialization** round-trips | `t2_census_merge.lua`:761-764, "no float, no clock and no iteration order reaches an artifact byte" | PUC-F3 five-artifact `cmp`, PUC-K10, PUC-K11 (`shard_blob`/`parse_shard_blob` round-trip at `:203-205`) |
| **`pairs()`-order-dependent control flow** | contracts:508-524, a real order dependence found on the first run | PUC-F3/PUC-K10 divergence test (§4.20) — probe + synthetic always, measured only at <=64 seeds |
| `string.format` / `tostring` formatting | canonical encoding is digest-pinned throughout | PUC-K2 (`run_t1.sh`, canonical encoding), PUC-F3 |
| the 32-bit `bit.*` surface | luanti-lua.md:102-106: built into LuaJIT, compiled from `lib/bitop` otherwise; operates on **32-bit** values | indirectly, via any full-path witness that hashes; no dedicated gate |
| **error messages and error paths** | `t2_census_merge.lua`:335-345, a strict-path error whose text can vary with `pairs()` | **No gate reaches this text.** PUC-K8 is comparator-only (§3.2) and PUC-K4 stops at `compiler.lua`:148; neither loads `t2_census_merge.lua`. What is covered is narrower: PUC-K8's exit-code discipline (`run_t2_s11_acceptance.sh`:40-43) covers the **checker** layer, and PUC-K4's typed error names (`expect_error` at `t2_schema_core_test.lua`:415-417) cover the **trust** layer. The merge strict path executes only when a merge fails, i.e. never in a green run |
| **phase breadth** across the partition pipeline | README:126-135, "runs every phase" | PUC-F1 **only** |
| **conformance breadth** over the ranked pool | README:486-498 | PUC-F2 **only** |

**What none of them covers.** The engine's `builtin/`, its sandbox and
`core.*` (luanti-lua.md:369-371). Also the `lua_atccall` patch that lets C++
exceptions cross the Lua stack, which is present only in the engine's bundled
build and is why system PUC Lua is rejected at configure time
(luanti-lua.md:66-69). Also engine-injected `string.pack`/`unpack`/`packsize`
(luanti-lua.md:107-110), which no standalone interpreter provides. These are
ENG-1's territory and no standalone-Lua equality result reaches them.

## 7. The bounded replacement candidate

**Name: the Pinned PUC Conformance Core (PCC).** Proposal only; not in force
(§1.3). It has four parts, all mandatory together. A partial adoption is not
this proposal.

### 7.1 Part 1 — the checksum-pinned semantic micro-corpus, five groups

**(a) Arithmetic and full-seed/seed-width extremes.**
`mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua`:6-16 **already is this ladder**
and needs no new fixture: `0, 1, 2, 42, 1013, 20260812, 2147483647 (2^31-1),
2147483648 (2^31), 2147483649 (2^31+1), 4294967295 (2^32-1), 4294967296
(2^32), 4294967297 (2^32+1), 6442450943, 6442450944, 8589934591 (2^33-1),
9007199254740991 (2^53-1), 9007199254740992 (2^53), 9007199254740993 (2^53+1),
18446744073709551615 (u64 max)`, then `1181064378178512398` and the seven
SHA-label-derived decimals, which live **in `corpus.fixed` itself** at `:12-15`
— `:18-26` is `corpus.sha_labels`, the table that derives and pins them. Twenty-seven entries in total, pinned by
`corpus.verify(raw_sha256)` at `:114-128`, which fails closed on
`#corpus.fixed ~= 27` (`:116`) and re-derives each SHA label's digest,
`first8` and decimal (`:117-126`). The 2^53 triple is exactly the boundary
luanti-lua.md:112-115 names.

**(b) Canonical formatting and serialization round-trips.** The existing
pattern is `t2_extreme_puc_kat.lua`:203-205 —
`extreme.shard_blob(parse_shard_blob(blob)) == blob` plus
`parsed.rows_sha256 == shard.rows_sha256`. Extend to the census record
encoding and the merge artifact rendering.

**(c) Interpreter-dependent control flow.** The `pairs()` probe
(`t2_census_merge.lua`:1128-1145) plus **both** invariance halves — synthetic
(`:1513-1515`) and measured (`:1516-1533`).

**(d) Boundary and negative cases, drawn from guards that already exist.**
`run_t2_extreme.sh`:80-91's two must-fail runs (a 4096-candidate benchmark
must be rejected; a range wider than 64 must be rejected); the index-4096
rejection at `t2_extreme_test.lua`:1126 and the index -1 rejection at `:1125`;
the GO-token 64-seed cap (`t2_census_authority.lua`:1339-1341); the
shard-coverage failure (`:1192`, "shard ranges do not cover W"); the
`stage_reject`-mixing guard (`t2_census_merge.lua`:335-345); and the merge's
own fail-closed sorted-probe abort (`:1502-1512`).

**(e) Silent-escape and error-path cases.** The three rows of
luanti-lua.md:295-299 as executable fixtures with their byte lengths
(`"\x41"` -> 1 vs 3, `"\u{41}"` -> 1 vs 5, `"a\z  b"` -> 2 vs 5), plus the
exit-code comparison discipline of `run_t2_s11_acceptance.sh`:40-43 applied to
every leg rather than to one.

### 7.2 Part 2 — four FULL-PATH carriers, three new and selector retained in F2

| stage | production entry point | driver | witness seeds | expected artifact | cost |
|---|---|---|---|---|---|
| **COMPILER** | `partition.compile` | `run_t2_puc_core.sh --compiler` / `t2_correction_repro.lua` | `1959553668008863006`, `2147483648` | complete stdout and compiled-graph SHA-256 per seed, byte-compared LuaJIT/PUC | 1,803 s total MEASURED |
| **WORKER** | `partition.census_scan` | `run_t2_puc_core.sh --worker` / `t2_census_worker.lua` | `2147483648`, `16178445837170081103` | complete v6 TSV, internal/external digest, canonical stdout and separated telemetry | 2,457 s total MEASURED |
| **MERGE** | `t2_census_merge.lua` via `run_merge_pair` | `run_t2_puc_core.sh --merge` | fixed 7 KAT seeds | five-artifact `cmp` + `artifacts_digest`, probe, synthetic and measured invariance | retained seven-seed worker walls sum to 346 s; exact total unretained; complete leg MEASURED GREEN within 420 s cap |
| **SELECTOR** | `extreme.score_candidate`, `extreme.candidate_shard`, selected compile | retained C1-v3 F2 | rescore roster includes 0/4095; slots 28-31 | retained rescore and selected artifacts | F2 ~99 min end to end MEASURED; no separate leg |

The COMPILER row closes the former PUC-K13 runner gap. F2 closes the proposed
selector carrier without the unmeasured widened six-candidate run.

Restated because it decides what the PCC may claim: a full-path witness is not
a unit test, and a comparator-only check is neither (§3). `PUC-K7` and `PUC-K9`
stay in the PCC as unit-layer evidence, and `PUC-K8` as comparator-layer
evidence, but neither is counted toward the four.

### 7.3 Part 3 — the explicit `pairs()`-order divergence gate

- The probe half, unchanged, with its **fail-closed abort** retained
  (`t2_census_merge.lua`:1502-1512): a runtime whose `pairs()` comes back
  sorted must abort, never record-and-continue.
- The synthetic invariance half, unchanged.
- **The measured invariance half becomes MANDATORY**, run at the merge-KAT's 7
  seeds, and its result becomes recorded evidence rather than transient
  scratch. This is affordable only here: at 4,123 seeds the code refuses it
  (`:1521`, `free_seed_budget` = 64). Today all three committed manifests read
  `measured_invariance=not_run_above_free_budget` (§4.20).

### 7.4 Part 4 — byte-identity, fixture identity, and the change rule

- **Byte-identity.** Every witness digest is compared against the
  corresponding **complete LuaJIT evidence's committed digest**, naming the
  artifact and the field: `artifacts_digest` in `census-manifest-v3.tsv`:49 for
  the merge (`:12` is `w_digest`, a different field); `rows_sha256` for the selector shard
  (`t2_extreme_puc_kat.lua`:206-208) and for the worker records; the
  compiled-graph SHA-256 for the compiler pair
  (`t2_correction_repro.lua`:1-4).
- **Fixture identity.** A manifest carrying a SHA-256 per fixture, in the shape
  `census-manifest-v3.tsv` already uses (`:8` `module_digest`, `:12`
  `w_digest`, `:14` `w_derivation`) and `conformance_gate.lua` already uses for
  the eight LuaJIT shards (`t2_extreme_conformance.lua`:321-327).
- **Frozen selection rule, stated in words.** The corpus is: the 27 pinned
  corpus seeds; the two §8.6.2 compiler witnesses; the two §9.4 worker
  witnesses; the 7 merge-KAT seeds; candidate 0, candidate 4095 and slots
  28-31. Selection is by rule, never by convenience.
- **Change ownership.** Any later change to the corpus, the witnesses or the
  digests is owned by a memo in `wp40-t2-contracts.md` and is never selected ad
  hoc. acceleration-plan:290-291, source bytes preserved including its curly
  quotes: “Representative” can never be selected ad hoc; fixture checksums, the
  deterministic selection rule, and a contracts memo own any later change.

### 7.5 Measured component cost of the accepted PCC

| part | retained component accounting | label |
|---|---:|---|
| micro, Source, unit/comparator and optional-load legs | <10 s | MEASURED component sum |
| COMPILER witness pair, serialized runtimes | 1,803 s | MEASURED |
| WORKER witness pair, serialized runtimes | 2,457 s | MEASURED |
| MERGE witness incl. measured divergence half | 346 s worker-phase sum + unretained merge/gate overhead | seven retained seed counters; exact whole-leg total unretained; complete leg MEASURED GREEN within 420 s cap |
| SELECTOR carrier | 0 s | supplied by retained F2; no duplicate PCC leg |
| **PCC component subtotal** | **at least 4,612 s + unretained merge/gate overhead** | retained component accounting; no synthetic end-to-end rerun |

The merge row does not claim a whole-command measurement: Phase 0B retained
the seven per-seed worker wall counters, whose sum is 346 s, but did not retain
the later dual-runtime merge and final-gate duration. The complete leg passed
its 420 s cap, so its exact headroom is not auditable from retained evidence.
Future captures emit a separate merge runtime TSV. The former selector
projection is removed because completed F2 already supplies the exact
endpoint/winner carrier. With retained F2 (~99 min) and F1's historical
53--62 min band, the two historical F1 endpoints yield 3.81 h and 3.96 h
respectively before adding the unretained positive merge/gate overhead;
full-`W` LuaJIT work and engine gates are separate.

Sections 5 and 9 retain the pre-ruling cost comparison and are superseded by
this measured component table where they differ. Static/intermediate gates are
not added again to the final-gate total merely because they also ran during
development.

## 8. Full-`W` and engine gates: accepted wording

### 8.1 Accepted replacement for contracts §11.4 acceptance point 5

Accepted by PUC-1 and made authoritative by contracts Section 14.7. The quote
below is retained as the ruling basis; the implemented selector carrier is F2,
not a separate widened run.

> 5. The full-`W` re-census (schema v7 / artifacts v4) is **deferred to
>    T2-final**. Its complete population of 4,123 seeds runs **under LuaJIT**,
>    per the standing interpreter split (Section 8.5, Section 8.6 and
>    Section 9.4). Its
>    merge runs as the LuaJIT/PUC pair of `run_merge_pair`, and the five
>    canonical artifacts must be byte-identical between the two interpreters
>    with the PUC half carrying the `pairs()`-order divergence test. T2-final's
>    standalone-PUC execution gate is the pinned bounded gate: the
>    checksum-pinned semantic micro-corpus, the four full-path witnesses
>    (compiler, worker, merge, selector), and these two bounded rounds:
>    `WP40_FINAL=1 tools/wp40/run_t2_partition.sh --no-cache --historical` and
>    `tools/wp40/run_t2_extreme_conformance.sh`. **No part of this contract requires the full-`W`
>    population, or any seed population above the free seed budget, to execute
>    under standalone PUC.** The targeted re-run plus the winner invariance
>    remains this fix's acceptance evidence.

The final sentence of the second-to-last clause is the operative one: it makes
reading (b) unavailable by construction rather than by interpretation.

**Why the two commands are spelled out.** `wp40-t2-contracts.md` contains
**zero** occurrences of `run_t2_partition.sh`, `run_t2_extreme_conformance.sh`
or `WP40_FINAL` (`grep -c` returns 0 for each). A clause reading "the bounded
rounds this contract names by command" would therefore name nothing, and the
§11 recommendation to retain PUC-F1 and PUC-F2 would not be implementable by
its own text. §12 carries the matching contracts EDIT row.

### 8.2 The two engine gates are NOT satisfied by any standalone Lua result

Stated separately and unweakened, under **both** outcomes:

- **ENG-1, the real fallback-engine runtime gate** — luanti-lua.md:369-371,
  wp-workflow.md:79-80, AGENTS.md:142-143, tools/wp40/README.md:115. Unchanged.
- **ENG-2, the dual-runtime engine benchmarks** —
  wp40-engineering-brief.md:3306-3315 and :3465-3473,
  mapgen-control.md:1586-1590, tools/wp40/README.md:1147-1152. Unchanged.

**Why they are distinct from each other.** ENG-1 asks a **correctness**
question about a **runtime**: does the game behave correctly when Luanti is
built against its bundled Lua 5.1.5 with the `lua_atccall` patch, inside the
sandbox, with `builtin/` and `core.*` present (luanti-lua.md:63-69, :369-371)?
It is a pass/fail runtime test the user performs on a real build. ENG-2 asks a
**performance** question about **both** runtimes: are the relative regression
gates met against the corresponding baseline for LuaJIT *and* for bundled Lua
5.1, with the full environment manifest and the p50/p95/max, chunks/s, RSS and
GC series recorded (engineering-brief:3306-3315, mapgen-control.md:1586-1590)?
Passing ENG-1 says nothing about ENG-2's thresholds, and a green ENG-2 series
on a LuaJIT build says nothing about ENG-1. Neither is inferable from a
standalone `tools/bin/lua51` digest match, because that binary has neither the
engine's Lua nor its API surface.

## 9. Outcome A — retain the current comprehensive rounds

This section is self-contained: a reader who rules "retain" needs nothing from
section 10. ENG-1 and ENG-2 are carried in the budget table for completeness,
though neither is a standalone-PUC leg and neither is budgetable from present
evidence (§4.22, §4.23).

### 9.1 Per-gate budgets to attach

acceleration-plan:295-296 requires that a retention ruling "attach explicit
wall-time and CPU budgets instead". Proposed:

| ID | gate | wall budget | CPU budget | basis |
|---|---|---:|---:|---|
| PUC-S1..S3 | static gates | 60 s | 60 s | MEASURED-qualitative |
| PUC-K1/K2/K3 | T0/T1/WP43 | 30 s | 30 s | MEASURED |
| PUC-K4 | schema core | 15 min | 15 min | PROJECTED, 591 s x 1.5 margin |
| PUC-K5 | source audit full | 15 min | 15 min | PROJECTED, same |
| PUC-K6 | dungeon probe | 5 min | 5 min | PROJECTED + `timeout 180` |
| PUC-K7/K8/K9 | KAT comparison legs | 10 min | 10 min | PROJECTED |
| PUC-K10 | merge-KAT | 5 min | 5 min | whole command ~2.5 min x 2 margin; its PUC half is 0.1-2 s (§4.10) |
| PUC-K11 | extreme PUC KAT | 60 min | 60 min | PROJECTED, 170-3,091 s band + margin on the 3,091 s anchor |
| PUC-K12 | §9.4 worker witnesses | 60 min | 2 CPU-h | MEASURED 22-25 min/seed |
| PUC-K13 | §8.6.2 compiler pair | 60 min | 2 CPU-h | PROJECTED |
| PUC-F1 | `WP40_FINAL=1` partition | 90 min | 90 min | MEASURED 53-62 min + margin |
| PUC-F2 | C1 conformance | 150 min | 8 CPU-h | MEASURED >=74 min; never completed |
| PUC-F3 | merge publication | 15 min | 15 min | MEASURED, conservative reading |
| **PUC-F5** | **full-`W` under PUC, if reading (b) is confirmed** | **19 days elapsed** | **2,216 CPU-h** | PROJECTED, §5.2 upper |
| PUC-F6 | T9 comprehensive round | **undefined** | **undefined** | no command exists (§4.21) |
| ENG-1 | fallback-engine runtime gate | user-run, not agent-budgeted | n/a | §4.22; no standalone-Lua budget applies |
| ENG-2 | dual-runtime engine benchmarks | **undefined** | **undefined** | §4.23; cold/warm repetition count not fixed |

### 9.2 Operational consequences on this host

- One designated benchmark host (the workstation described in §5.3), 8-worker
  cap (README:439), workers under `chrt --idle 0` + `ionice -c3`
  (contracts:251-254).
- **No automatic wall-kill** since 2026-08-18 (contracts:225-235). A run of
  the PUC-F5 length has no automatic stop; only the CPU intrinsic and liveness
  gates fire, and the honest residual at contracts:255-256 is that a worker
  blocked forever while consuming no CPU triggers nothing.
- The 4.8/8 effective width (§5.3) converts CPU-h to elapsed time by
  **dividing CPU-h by 4.8**, which is the same thing as multiplying the
  wall-at-full-width-8 figure by 1.667. §5.2 applies the second form. Do not
  apply both.
- User load is normal operation on this machine, not degradation
  (contracts:228-230). A multi-week run means multi-week degraded interactive
  use, or a multi-week embargo on interactive use.

### 9.3 Delivery cost and what A buys that B does not

Excluding PUC-F5, outcome A costs 3.50-5.66 h of serial wall (§5.1), ~2.6 h on
the realistic parallel schedule, 7.61-10.83 CPU-h. That is not the problem.
**The problem is PUC-F5**: if reading (b) stands, T2-final gains 13-19 elapsed
days on the critical path, and the T2 freeze cannot be scheduled without that
block.

**The cost comparison, on one declared basis.** The two outcomes must be
priced the same way before they can be compared. The basis used here: **witness
pairs run concurrently** (PUC-K12 and PUC-K13 at 1,320-1,500 s and
870-1,500 s), and **PUC-K10 priced as the whole `--merge-kat` command** in both
outcomes, since the command runs under either. Restating Table 1 on that basis
costs it 2,150 s (low) / 3,000 s (high) for the pairs and gains it 150 s / 198 s
for PUC-K10:

| | outcome A | outcome B-scoped | delta |
|---|---:|---:|---:|
| low | 10,598 s = **2.94 h** | 11,508 s = **3.20 h** | **B +0.25 h** |
| high | 17,585 s = **4.88 h** | 33,340 s = **9.26 h** | **B +4.38 h** |

**B-scoped costs more than outcome A across the whole band** — roughly +0.25 h
at the floor and +4.38 h at the ceiling. **The delta is basis-independent**,
because the pair-scheduling choice applies identically to both outcomes: on the
serial basis the same totals read A 12,748 s = 3.54 h / 20,585 s = 5.72 h
against B 13,658 s = 3.79 h / 36,340 s = 10.09 h — the same +0.25 h and
+4.38 h. There is no reading of the evidence on which the bounded gate is the
cheaper programme.

**Where B's cost sits.** About **55.6 %** of B's high total (18,546 s of
33,340 s) is the single widened SELECTOR witness, whose anchor is unmeasured
(§4.11). Even at that witness's floor B pays 1,020 s against outcome A's 170 s
for the same stage — six times the work, because the PCC widens the selector
from one candidate to six. Measuring `run_t2_extreme_puc_kat.sh` once would
collapse the ceiling, but it cannot make B cheaper than A: the floor gap of
+0.25 h stands regardless.

**Therefore: this memo does not recommend B on cost, and cost is an argument
against it.** The recommendation in §11 rests entirely on coverage — closing
PUC-K13, making the measured `pairs()` half reachable and recorded, and
removing the PUC-F5 exposure. A reader who weights delivery hours above those
three should rule A for everything except PUC-F5.

What A buys that B does not: nothing that this inventory could identify,
**except** the disputed PUC-F5 itself. Every other gate in A is also in B under
the coordinator's scoping. The comparison is therefore not "broad versus
narrow"; it is "with or without the population run", plus the definition
question for PUC-F6.

## 10. Outcome B — adopt the bounded checksum-pinned gate

### 10.1 Retained coverage

Every risk row of §6 keeps at least the carrier it has today, and two rows
improve. One row is honest about having no carrier in **either** outcome: the
merge strict-path error text of §6's error row is reached by no gate now and by
no gate under B, because it only executes when a merge fails. The two that
improve:

- **`pairs()`-order control flow** improves from probe+synthetic to
  probe+synthetic+**measured** (§7.3). This is the axis on which the
  comprehensive round has always silently failed to deliver (§4.20).
- **Compiler full-path coverage** improves from *nothing* to a
  digest-compared witness pair, because PUC-K13 is unclosed today (§4.13).

### 10.2 Residual risk, honest and specific

1. **PUC never executes the 4,096-candidate scoring pool.** True under B — and
   **also true today**: PUC-F2 rescores 20 of 4,096
   (`run_t2_extreme_conformance.sh`:85-86). B does not create this gap; it
   inherits it.
2. **PUC never executes the full-`W` population.** True under B. Also true in
   every run ever performed: `census-manifest-v3.tsv`:9 records
   `worker_interpreter_id luajit`. B makes the status quo explicit rather than
   changing it.
3. **Phase coverage narrows if PUC-F1 is dropped.** No seed-level witness
   reproduces "runs every phase" (README:128). This is why §11 recommends
   retaining PUC-F1 inside the gate.
4. **Conformance breadth narrows if PUC-F2 is dropped.** Same reasoning.
5. **A divergence in a code path no witness traverses** would be caught only by
   the static gates (PUC-S1..S3). ENG-1 does **not** back this up: it is a
   runtime test on a Luanti build, and the census, merge and conformance
   tooling never executes inside the engine — `compiler.lua`:148 still returns
   `compiled_geometry_unavailable` on the production path. ENG-1 covers only
   code the engine actually executes, which is none of the offline pipeline.
   For the silent-escape class this is already the situation (§6): no
   executable gate detects it in any outcome.
6. **The SELECTOR witness cost is unmeasured** (§7.5). If
   `run_t2_extreme_puc_kat.sh` really costs 3,091 s, the widened selector
   witness is the PCC's dominant expense and its scope may need re-cutting.

## 11. Recommendation

**Recommend outcome B, scoped.** This memo's reading of the evidence agrees
with the coordinator's position and adds no dissent.

**Facts** (each cited above): reading (b) is supported by one sentence and
contradicted by contracts:938 and acceleration-plan:461-462; nine other
re-census sentences are pure scheduling; the population has always run under
LuaJIT in the committed manifest; reading (b) costs 1,512-2,216 CPU-h and
13-19 elapsed days; the measured `pairs()` divergence half is *refused* above
64 seeds and has never been recorded; PUC-K13 is an unclosed obligation with no
runner.

**The recommendation, precisely:**

1. Adopt the PCC (§7) as the **definition** of the final standalone-PUC
   execution gate at T2-final and T9-final.
2. **Retain inside it**, unchanged, the two already-bounded rounds
   `WP40_FINAL=1 tools/wp40/run_t2_partition.sh --no-cache --historical`
   (PUC-F1, phase coverage, 53-62 min MEASURED) and
   `tools/wp40/run_t2_extreme_conformance.sh` (PUC-F2, the defined C1
   conformance gate, >=74 min MEASURED). Their coverage is phase and
   conformance **breadth**, which no seed witness reproduces, and their
   combined cost is under two hours.
3. **Rule out the population-under-PUC reading** via the §8.1 wording.
4. Leave ENG-1 and ENG-2 untouched (§8.2).

**On cost, stated against the recommendation.** Once PUC-F5 is excluded,
B-scoped is **more expensive than outcome A at both ends of the band** — on the
common basis of §9.3, 3.20-9.26 h against A's 2.94-4.88 h, i.e. **+0.25 h at
the floor and +4.38 h at the ceiling**. About 55.6 % of B's high total is the
one unmeasured selector anchor, and even at that anchor's floor B pays six
times A's selector cost. Measuring it narrows the ceiling; it does not close
the floor gap. **The recommendation below rests entirely on coverage** —
closing PUC-K13, making the measured `pairs()` half reachable and recorded, and
removing the PUC-F5 exposure — and cost argues against it.

**Why B-scoped is strictly stronger than the status quo on one axis.** Under
this scoping the measured `pairs()`-divergence half becomes reachable and
mandatory for the first time (§7.3). The comprehensive round cannot deliver it
at any budget, because the code refuses it above 64 seeds.

**Assumptions, separated.** That PUC-K11's true cost is nearer its 170 s floor
than its 3,091 s ceiling; that a runner for `t2_correction_repro.lua` is a
small piece of work; that the widened selector witness scales roughly linearly
in candidates.

**Unresolved evidence, separated.** The merge-cost conflict (§5.4.1); the
partition-gate 53-vs-62 min conflict (§5.4.2); the unsourced 16.2x (§5.4.3);
the pool 91-vs-100 min conflict (§5.4.4); PUC-F2 has never completed once, so
its complete cost is a projection; PUC-F6 has no definition at all.

**Stated plainly.** If the user wants the stronger simplification that **also**
drops PUC-F1 and PUC-F2, **equivalent risk coverage cannot be demonstrated
from the present evidence**, and the current rule should be retained for those
two.

## 12. Authority-hit list

The atomic update checklist. **EDIT** = wording must change under outcome B.
**MINIMAL EDIT** = one clause or cross-reference. **NO EDIT — CONFIRM
UNCHANGED** = must be re-read and confirmed unchanged so the package is
provably complete. Under outcome A, every EDIT row becomes "attach the §9.1
budget" instead.

| file | `path:line` | current wording, in brief | required change | why |
|---|---|---|---|---|
| `AGENTS.md` | :136-140 | "full expensive PUC rounds happen only at T2-final and T9-final" | **EDIT** | must name the PCC as what a comprehensive round *is* |
| `AGENTS.md` | :144-150 | planning-agents clause; "a plan that implies a comprehensive PUC round outside T2-final/T9-final is a planning defect" | **MINIMAL EDIT** | keep the defect rule; point it at the PCC definition |
| `AGENTS.md` | :142-143 | "The real fallback-engine runtime test is still a separate user-run gate" | **NO EDIT — CONFIRM UNCHANGED** | ENG-1 is unweakened (§8.2) |
| `docs/process/wp-workflow.md` | :46-55 | step-4 self-check; "reserve comprehensive PUC rounds for T2-final and T9-final" | **EDIT** | same substitution |
| `docs/process/wp-workflow.md` | :62-70 | step-5 reviewer clause; "it never authorizes another comprehensive PUC round" | **MINIMAL EDIT** | keep; align vocabulary |
| `docs/process/wp-workflow.md` | :79-80 | "A real fallback-engine run is a separate runtime gate" | **NO EDIT — CONFIRM UNCHANGED** | ENG-1 |
| `luanti-lua.md` | :7-13 | planning note; "reserves comprehensive PUC rounds for the defined final gates" | **MINIMAL EDIT** | "defined final gates" now has a definition to point at |
| `luanti-lua.md` | :336-342 | the operating principle; "an expensive runner hardwired to PUC is a defect" | **NO EDIT — CONFIRM UNCHANGED** | unchanged by either outcome; it is what flags PUC-K5 |
| `luanti-lua.md` | :343-344 | the `run_t2_s1_authority.sh` precedent | **NO EDIT — CONFIRM UNCHANGED** | the precedent still stands |
| `luanti-lua.md` | :348-350 | layer 1, static gates | **NO EDIT — CONFIRM UNCHANGED** | PUC-S1..S3 unchanged |
| `luanti-lua.md` | :351-353 | layer 2, LuaJIT owns exhaustive | **NO EDIT — CONFIRM UNCHANGED** | B strengthens this, does not change it |
| `luanti-lua.md` | :354-358 | layer 3, intermediate KATs | **MINIMAL EDIT** | the PCC is the milestone KAT set's superset |
| `luanti-lua.md` | :359-362 | layer 4, "reserve the full, expensive PUC suites for T2-final and T9-final" | **EDIT — the single most load-bearing sentence** | this is where the PCC is defined or not |
| `luanti-lua.md` | :363-368 | layer 5, review; carries the identical clause "it never authorizes another comprehensive PUC round" | **MINIMAL EDIT** | same verdict as wp-workflow.md:62-70, which carries that clause verbatim; the two must not diverge |
| `luanti-lua.md` | :369-371 | layer 6, engine fallback | **NO EDIT — CONFIRM UNCHANGED** | ENG-1 |
| `luanti-lua.md` | :373-377 | closing; "comprehensive executable rounds at the defined final gates" | **MINIMAL EDIT** | align with :359-362 |
| `tools/wp40/README.md` | :111-115 | "comprehensive parallelized WP40 PUC rounds are reserved for T2-final and T9-final" | **EDIT** | same substitution |
| `tools/wp40/README.md` | :126-135 | the `WP40_FINAL=1` gate; "reserve the parallelized comprehensive PUC round for T2-final" | **MINIMAL EDIT** | PUC-F1 is retained; only the surrounding sentence moves |
| `tools/wp40/README.md` | :413-437 | the cost-anchor table and the "not one number" paragraph | **MINIMAL EDIT** | add the 19-28x census-worker band (§4.12); mark the 16.2x as unsourced (§5.4.3) |
| `tools/wp40/README.md` | :468-473 | "PUC must parse and rank it without relabelling its origin, then rematerialize deterministic shard endpoints and the four winners" | **MINIMAL EDIT** | the same "every row" ambiguity flagged at §4.18 for the fixtures README; clarifying one copy and leaving the other is not an atomic package |
| `tools/wp40/README.md` | :1147-1152 | T9 bundled-Lua engine measurement | **NO EDIT — CONFIRM UNCHANGED** | ENG-2 |
| `wp40-t2-contracts.md` | :1582-1584 | §11.4 acceptance point 5 — **the ambiguity** | **EDIT — replace with §8.1** | the whole ruling turns on this |
| `wp40-t2-contracts.md` | :970-984 | §8.6 gate-2 point 2, the targeted PUC set | **MINIMAL EDIT** | fix the dangling "the brief" cross-reference at :983 (0 hits for PUC/T2-final/T9-final in the brief) and note that PUC-K13 has no runner |
| `wp40-t2-contracts.md` | §11.4, new sentence beside :1582-1584 | contracts names **no** runner: `grep -c` for `run_t2_partition.sh`, `run_t2_extreme_conformance.sh` and `WP40_FINAL` all return 0 | **EDIT — ADD** | without naming PUC-F1 and PUC-F2 by command, the §8.1 wording silently excludes the two rounds §11 retains, and the recommendation is not implementable by its own text |
| `wp40-t2-contracts.md` | :1253-1261 | §9.4 interpreter split, the existing prototype | **NO EDIT — CONFIRM UNCHANGED** | it is the model the PCC generalizes |
| `wp40-t2-contracts.md` | :352-355 | §6.6 point 5, "The PUC merge carries the `pairs()`-order divergence test" | **MINIMAL EDIT** | add that the measured half is mandatory at the KAT scale |
| `wp40-t2-contracts.md` | :938 | "All under **LuaJIT** per the interpreter split" | **NO EDIT — CONFIRM UNCHANGED** | primary counter-evidence to reading (b) |
| `wp40-t2-contracts.md` | :1595, :1703-1704, :1818-1819, :1876-1877, :1946, :1996-1997, :2096-2097, :2237-2239 | eight unambiguous re-census sentences | **NO EDIT — CONFIRM UNCHANGED (x8)** | they are already correct; confirming them is the proof that only :1582-1584 was ambiguous |
| `wp40-acceleration-and-delivery-plan.md` | :106-107 | the ninth unambiguous re-census sentence | **NO EDIT — CONFIRM UNCHANGED** | same |
| `wp40-t2-plan.md` | :474-477 | the divergence test as "the cheap substitute for a full PUC gate" | **MINIMAL EDIT** | it becomes part of the gate, not a substitute for one |
| `wp40-t2-plan.md` | :352-355 | "PUC-to-LuaJIT ratio is **not** a single number" | **MINIMAL EDIT** | add the census-worker band; flag the 16.2x |
| `wp40-engineering-brief.md` | :3306-3315 | "The same relative gates … for both Lua runtimes" | **NO EDIT — CONFIRM UNCHANGED** | ENG-2 |
| `wp40-engineering-brief.md` | :3465-3473 | mandatory pre-integration outputs | **NO EDIT — CONFIRM UNCHANGED** | ENG-2 |
| `wp40-engineering-brief.md` | :4095 | T9 acceptance row | **NO EDIT — CONFIRM UNCHANGED** | ENG-2 |
| `BACKLOG.md` | :63, the WP40 row | requires the 32-seed audits, capacity simulation and performance measurements | **NO EDIT — CONFIRM UNCHANGED** | verified: the row contains no occurrence of PUC, T2-final, T9-final, LuaJIT or interpreter. No interpreter policy lives here |
| `mapgen-control.md` | :1586-1590 | "LuaJIT versus bundled Lua 5.1" in every recorded result | **NO EDIT — CONFIRM UNCHANGED** | ENG-2's origin |

### 12.1 Sites the acceleration plan's fold-in list omits — additions

acceleration-plan:283-286 and :713-728 name `AGENTS.md`, `wp-workflow.md`,
`luanti-lua.md`, `tools/wp40/README.md`, the engineering brief, the T2 plan,
affected T2 contracts, `world_zones.md` §13, and the `BACKLOG.md` WP40 detail.
Four of the five sites below are **not** in that scope at all; the fifth is a
passage inside a file that is in scope but was never called out. All five must
be added:

| site | why it is an authority hit |
|---|---|
| `tools/wp40/run_t2_partition.sh`:11-13 | a T2-final instruction in **executable code**; the only `.sh` file in the repository containing the string `T2-final` |
| `tools/wp40/fixtures/t2_extreme_e0/README.md`:22-29 | a live PUC obligation stated in a fixtures README (PUC-F4), including the "every row" wording gap of §4.18 |
| `docs/research/wp40-t2-handover.md`:50 | the "Plain-5.1 partition acceptance" deferred-run row, carrying the 53 min reading and "current cost is unmeasured" |
| `tools/wp40/README.md`:1147-1152 | the file *is* in the plan's scope (:285, :718); this specific passage was never called out. It is the only concrete T9 obligation touching the fallback interpreter, and it is an **engine** measurement, not a PUC round |
| `docs/research/mapgen-control.md`:1586-1590 | the origin of the dual-runtime requirement that ENG-2 inherits |

**Historical package boundary:** the inventory commit did not edit
`docs/research/wp40-acceleration-and-delivery-plan.md` §5.2 or §15. Phase 0B
later folded the accepted ruling there atomically; Section 16 records that
closeout.

## 13. Historical questions resolved by PUC-1

Disposition: (1) scheduling reading (a); (2) PCC adopted; (3) F1/F2 retained;
(4) T9-final uses the same bounded PCC/F1/F2 definition; (5) compiler runner
implemented; (6) Source audit moved to LuaJIT-full plus targeted PUC parity;
(7) no widened selector run because completed F2 already supplies it; (8) the
bounded seven-seed merge retained seven worker wall counters summing to 346 s
and passed its 420 s cap, while its exact whole-leg wall is unretained and the
historical population-merge timing conflict remains a record only; (9) F1
retained with its 90-minute budget; (10) the unretained 16.2x ratio withdrawn.
The original questions remain below as the pre-ruling review record.

1. **Which reading of contracts:1582-1584 is correct — (a) scheduling or (b)
   coupling?** If (a): the §8.1 wording lands and nothing else changes. If (b):
   §9.1 must carry a 2,216 CPU-h / 19-elapsed-day budget for PUC-F5 and the T2
   freeze date moves by weeks.
2. **Is the PCC adopted as the definition of the final standalone-PUC gate?**
   If yes: §12's EDIT rows fire in one atomic package. If no: §12's EDIT rows
   become budget attachments per acceleration-plan:295-296.
3. **If the PCC is adopted, are PUC-F1 and PUC-F2 retained inside it?** This
   memo recommends yes (§11). Dropping them removes phase and conformance
   breadth for which no equivalent evidence exists. Cost of retaining: under
   two hours.
4. **What is PUC-F6, the T9-final comprehensive PUC round?** No command,
   population, artifact or budget exists anywhere (§4.21). It must be defined
   under either outcome, or explicitly declared to be the same gate as
   T2-final's.
5. **Is a runner written for `t2_correction_repro.lua` (PUC-K13)?** Today the
   §8.6.2 byte-compare is an unclosed obligation under **both** outcomes. If
   no runner is written, the compiler stage has no full-path PUC witness at
   all.
6. **Is `t2_source_audit.sh`:396 repaired to the `WP40_LUA_BIN` pattern?**
   This is independent of the ruling: it is a candidate defect under
   luanti-lua.md:336-342 whose status turns on a measurement nobody has taken.
   Measuring it decides it.
7. **Is `run_t2_extreme_puc_kat.sh` measured before the ruling?** Its cost band
   is 170-3,091 s, an **18x** spread that dominates the PCC's projected high
   and is about 55.6 % of outcome B's high total (§7.5, §9.3). One run resolves
   it. It cannot change the recommendation's direction — B costs more than A at
   the floor too — but it decides whether B costs +0.25 h or +4.38 h.
8. **Which merge-cost reading is authoritative** — ~6 min (contracts:706-708)
   or 19.29 s (`merge6.log`:21)? The answer changes PUC-F3's budget by a factor
   of 19 and requires finding or writing the `MERGE2_TIME` emitter.
9. **Is the "8-way sharded ~62 min" partition reading retracted or explained?**
   The runner is serial and rejects its phase selector under `WP40_FINAL=1`
   (§4.15). One of the two measured readings is mis-scoped.
10. **Should the unsourced 16.2x ratio be retracted from README:437 and
    t2-plan:353?** It has no retained measurement. Leaving it invites exactly
    the single-ratio extrapolation those same sentences forbid.

## 14. Appendix A — retained cost evidence, transcribed

`tools/wp40/results/` is gitignored (`.gitignore`:11) and exists only in the
main checkout at `/home/jan/projects/grudgelands`; these lines are transcribed
verbatim so the cost basis of sections 5 and 7 remains citable from inside the
tree.

```
# tools/wp40/results/t2_census/cost-projection.txt (run 6, 2026-08-19)
WP40 T2 census cost projection wall_seconds=36884 workers=8 per_seed_seconds=71.48 completions=516 shards=8 observed_wall_seconds=36884 verdict=advisory
WP40 T2 census cpu projection cpu_seconds=36040 workers=8 budget_seconds=115.24 per_seed_cpu_seconds=69.84 completions=516 shards=8 observed_cpu_seconds=36040 verdict=passed

# tools/wp40/results/merge4.log:2  (run 4, 2026-08-17)
WP40 T2 census merge seed_set=full_w seeds=4123 inputs=8 artifacts_digest=c754ad2c4b3d598b8c3df6f1e650af4ae51f16d3e2ee474f9cc83d7215476ace

# tools/wp40/results/merge4.log:10  and  merge4.log:19
WP40 T2 census divergence test probe_unsorted=true synthetic=passed measured=not_run_above_free_budget

# tools/wp40/results/merge4.log:20
WP40 T2 census merge LuaJIT/PUC artifacts identical digest=c754ad2c4b3d598b8c3df6f1e650af4ae51f16d3e2ee474f9cc83d7215476ace

# tools/wp40/results/merge6.log:2  (run 6, 2026-08-19)
WP40 T2 census merge seed_set=full_w seeds=4123 inputs=9 artifacts_digest=2433d6f6fcff4fae3fe49b5012c585cfd4de758aa2ab1202f59202dceb15c127

# tools/wp40/results/merge6.log:10  and  merge6.log:19
WP40 T2 census divergence test probe_unsorted=true synthetic=passed measured=not_run_above_free_budget

# tools/wp40/results/merge6.log:21
MERGE2_TIME wall=19.29s cpu_user=18.17s cpu_sys=0.63s maxrss=519984kB

# tools/wp40/results/bay-transition-package-final-artifacts/README.txt:31-32
# Sweep wall 10:00-14:42 (4.7 h vs 6 h pre-approval); records 22.5 CPU-h
# (69.3 s/seed), probes 9.2 CPU-h; PUC pair 22 min vs 90 min.

# tools/wp40/results/bay-transition-package-w11-stop-artifacts/README.txt:29-30
# Acceptance sweep (evidence mode, 2026-08-20 20:26 - 08-21 01:15, 4.8 h wall,
# records 22.0 CPU-h / probes 9.4 CPU-h, width <= 8, chrt --idle, ionice -c3):

# tools/wp40/results/bay-transition-package-stop-artifacts/stop-report.md:112-116
evidence-mode sweep 16:21–19:00 =
**2 h 39 min wall**, records 15.8 CPU-h over 1,142 completed runs
(mean 49.8 CPU-s/seed — under the 60–80 band; the 24 aborts die
early), adoption probes ≈2.3 CPU-h, PUC pair ≈23 min wall each
(concurrent), all under `chrt --idle`/`ionice -c3` at width ≤8.

# tools/wp40/results/bay-transition-2c-stop-artifacts/stop-report.md:137-140
- 2147483648: 770 rows,
  `77ecf84cb0f965d80b372212b0e722fa2b11a409f1d38b657dc454e46ea9f253`
  under both interpreters (PUC wall ≤ 25 min, inside the ≈40-min
  projection).

# tools/wp40/results/bay-transition-2c-stop-artifacts/stop-report.md:165-168
- Cost actuals vs projection: projected ≈6.3 CPU-h ≈ 50 min wall at
  eight workers; measured **6.91 CPU-h over 374 solo runs, mean
  66.5 s/seed** (in the measured 60–70 band; 374 = 370 + the four
  non-member seeds re-run forced).

# tools/wp40/results/t0-baseline/<manifest-digest>/host.json (schema wp40_host_manifest_v1)
"model": "AMD Ryzen 7 9800X3D 8-Core Processor", "physical_cores": 8,
"logical_cpus": 16, "governor": "performance", "total_bytes": 62825226240
```

**In-tree equivalents, for the claims that have one.** The divergence-test
state is also committed at
`tools/wp40/fixtures/t2_census/census-manifest-v3.tsv`:20 and in the v1/v2
manifests; the run-6 cost projection is committed at the same file's `:17`;
the interpreter split is committed at `:9` and `:15`.

## 15. Appendix B — search log

Sweep over `.md`, `.sh`, `.lua`, `.py`, `.conf`, `.txt`, excluding
`reference_projects/` and `.git/`, at commit `1b38943`.

| term | files | hits |
|---|---:|---:|
| `PUC` | 43 | 269 |
| `lua51` | 41 | 85 |
| `luac51` | 29 | 65 |
| `lua5.1` | 0 | 0 |
| `LuaJIT` | 37 | 183 |
| `WP40_LUA_BIN` | 14 | 27 |
| `T2-final` | 8 | 31 |
| `T9-final` | 5 | 11 |
| ``full-`W` `` | 12 | 72 |
| `re-census` | 2 | 14 |
| `divergence` | 17 | 69 |
| `byte-identical` | 28 | 82 |
| `digest-identical` | 1 | 6 |
| `fallback` | 67 | 221 |
| `dual-runtime` | 1 | 2 |
| `benchmark` | 10 | 68 |
| `pairs()` | 9 | 21 |
| `interpreter` | 48 | 446 |

The three narrow terms are the load-bearing ones and their file lists are
short enough to state in full:

- **`T2-final` (8 files):** `AGENTS.md`, `docs/process/wp-workflow.md`,
  `docs/research/luanti-lua.md`,
  `docs/research/wp40-acceleration-and-delivery-plan.md`,
  `docs/research/wp40-t2-contracts.md`, `docs/research/wp40-t2-handover.md`,
  `tools/wp40/README.md`, **`tools/wp40/run_t2_partition.sh`**. The last is the
  only executable one.
- **`T9-final` (5 files):** `AGENTS.md`, `docs/process/wp-workflow.md`,
  `docs/research/luanti-lua.md`, the acceleration plan, `tools/wp40/README.md`.
  No executable file, and no command defined in any of them (§4.21).
- **`dual-runtime` (1 file, 2 hits):** the acceleration plan at :282 and :705,
  both forward references. The substantive requirement lives under other
  wording in `wp40-engineering-brief.md`:3306-3315 and
  `mapgen-control.md`:1586-1590.
- **`re-census` (2 files, 14 hits):** `wp40-t2-contracts.md` (**9**) and the
  acceleration plan (**5**) — `grep -c` on each file. Every one of the fourteen
  was opened. Exactly one of the **nine contracts hits**, :1582-1584, carries an
  interpreter claim; the other eight are pure scheduling. The five plan hits are
  not independent authority — :106 is scheduling, and :258, :288 and :462 are
  this same open question being posed and answered directionally, which is why
  §4.19 cites :461-462 as counter-evidence rather than as a separate source.

Zero-hit checks, run to confirm absences claimed above:

- `grep -ci` over `docs/research/wp40-engineering-brief.md` (4,126 lines) for
  `PUC`, `T2-final`, `T9-final`, `lua51` — **0, 0, 0, 0**.
- `grep -rn "t2_correction_repro"` over the tree — **0 hits**.
- `grep -rn "t2_face_ring_probe\|t2_whole_gap_probe"` over `.sh` and `.md` —
  **0 hits**.
- `grep -rn "MERGE2_TIME"` over the tracked tree — **0 hits**; the only
  occurrence anywhere is `results/merge6.log`:21.
- The WP40 row of `BACKLOG.md`:63 for `PUC`, `T2-final`, `T9-final`, `LuaJIT`,
  `interpreter` — **0 for each**.

---

## 16. Accepted Phase-0B closeout

The former standstill is satisfied. The user accepted PUC-1 and Phase 0B
implemented its coordinated atomic authority fold on ownership-provider commit
`62afc64`. Contracts Section 14.7 is the normative memo; this document remains
the detailed research and cost record.

The fresh closeout sweep included `PUC`, `lua51`, `luac51`, `LuaJIT`,
`WP40_LUA_BIN`, `T2-final`, `T9-final`, full-`W`, re-census, divergence,
byte/digest identity, fallback, dual-runtime, benchmark, `pairs()` and
interpreter terms across Markdown, shell and Lua outside
`reference_projects/`. Actual policy/executable hits were folded in
`AGENTS.md`, `docs/process/wp-workflow.md`, `docs/research/luanti-lua.md`, the
T2 contracts/plan/acceleration plan, this inventory, the historical T2
handover, the T5-0 budget contract, `tools/wp40/README.md`, the F1 runner
comment and the C1-v3 fixture README. The engineering brief and mapgen-control
engine requirements were checked and intentionally left unchanged; BACKLOG
and design files contain no standalone-interpreter policy.

The executable closeout is `tools/wp40/run_t2_puc_core.sh` with immutable
fixtures in `tools/wp40/fixtures/t2_puc_core/` and calibration/raw telemetry in
`tools/wp40/evidence/t2-puc-core-v1/`. Measured Phase-0B results are compiler
1,803 s and worker 2,457 s. The merge's seven retained seed-wall counters sum
to 346 s; its exact whole-leg wall was not retained, and the complete leg
passed its 420 s cap. All canonical bytes/digests agree.
The completed C1-v3 F2 supplies selector evidence and measured 215 s rescore,
5,507 s selected and approximately 99 minutes end to end. F1/F2 were retained
but not rerun; full-`W`, C1 reacceptance and every PUC population were deferred.

**Standing, restated.** Exhaustive populations run under LuaJIT. T2-final and
T9-final use exactly the checksum-pinned PCC plus retained F1/F2; full-`W`
keeps its LuaJIT/PUC merge parity; the fallback-engine runtime and dual-engine
benchmarks remain separate. Any change requires a later user ruling and owning
contracts memo.
