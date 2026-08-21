# WP40 T5-0 engine-seam probe

A disposable, eleven-file probe that measures the Luanti mapgen VoxelManip seams
named in `docs/research/wp40-t5-0-engine-probe-contract.md`. That contract is the
authority for everything below; this README does not extend it, and where the
two disagree the contract wins.

- **Contract:** [`docs/research/wp40-t5-0-engine-probe-contract.md`](../../../docs/research/wp40-t5-0-engine-probe-contract.md)
- **Shape:** four engine invocations, strictly serial, three distinct measured
  mapchunks each — **4 runs x 3 chunks = 12** mapchunk generations in total.
- **Arms:** `A1` (mapgen script registered, callback performs zero VoxelManip
  calls) and `B` (the synthetic payload), each run under both chunk request
  orders `O1` = 8, 10, 11 and `O2` = 11, 10, 8.
- **Files:** **eleven**, all under `tools/wp40/t5_probe/` (contract section 8.1).
  The package creates no production file, no file under `mods/`, and no
  production registration.

---

## What this probe does not claim — section 3.2, verbatim

The thirteen non-claims below are reproduced word for word from contract
section 3.2. They are the register this package reports in, not a disclaimer
appended to it.

T5-0 does **not** prove, establish, validate, freeze or make any claim about:

1. the final T2 compiled payload, its records or its field names — T2 owns them
   (`wp40-engineering-brief.md:4088`, `:2247-2257`, `:2259-2261`);
2. the `grug_zones` public API — T3 owns it (`:4089`);
3. the closed typed resolver matrix, the four named resolver pairs, the
   per-voxel operation plan, the deferred-coverage extension, the
   exact-host-only deep resource type or the offline dungeon-guard oracle — T4
   owns them (`:4090`, `:2109-2113`);
4. final operation types or conflict rules of any kind;
5. the production T5 adapter or transaction (`:4106` "Only T5 owns the
   VoxelManip adapter and transaction.");
6. representative production performance. No threshold in `:3339-3358` is
   evaluated, approached or claimed, and the brief itself records that "No
   number in this section claims a successful measurement" (`:3471-3472`);
7. full dungeon, resource or biome behaviour; T5, T9 or release readiness;
8. logical-biome→content mappings, top/filler, decoration candidates, water
   normalization or the authored vein catalog — T6/T7 own them (`:4092-4093`);
9. **any statistical property of its own timings.** Every timing is `n = 1`:
   one run per (arm, order) cell, no warm-up, no repetition, no variance, no
   outlier rule. The summary carries `timings_are_golden: false` and
   `timing_replicates: 1`, and the cost projection is one unreplicated sample
   multiplied by **four** (section 14.3);
10. **a settled liquid state.** The `liquid_update = 86400` pin suppresses
    `Server::AsyncRunStep`'s periodic global drain
    (`reference_projects/luanti/src/server.cpp:781-792`) and **nothing else**:
    `finishBlockMake`'s `transformLiquidsLocal`
    (`reference_projects/luanti/src/servermap.cpp:300`) and a later neighbour's
    own local transform remain part of every O1/O2 result (section 10.15). What
    the probe compares is the **post-generation result after bounded local
    transform, before background settling**. It does not substitute for the
    brief's "frozen liquid-settling procedure" (`:3005`) or "frozen quiescence
    limit" (`:1405`), and it says nothing about a normally stepping server;
11. **whole-chunk byte identity.** Every byte comparison is evidenced on CORE
    and SEAM only: **388,096 distinct voxels** of the **1,536,000** central
    voxels the three measured chunks contain, or **25.3 %** (section 14.3). Per
    chunk, CORE is 110,592 of 512,000, or 21.6 %. A containment pass means "no
    difference in the compared regions", not "no difference in the chunk", and
    the summary says it in those words;
12. **that loading a mapgen script is byte-neutral.** Answering that needs a
    script-free control arm and this scope has none: `A1` — script registered,
    callback performs zero VoxelManip calls — is the paired control, so every
    comparison is `B − A1` inside a world that already loads the probe's mapgen
    script;
13. **a generic engine unfinished-slice overwrite bug.** Section 10.13 records
    why no deterministic controlled negative is constructible at this scope;
    micro-case 4 is a bounded paired-order persistence observation that reports
    order effects without attributing their cause.

It also does **not** move full T5 ahead of T3 and T4
(`wp40-acceleration-and-delivery-plan.md:477-479`).

---

## The register every number here is written in

Adopted by reference from contract section 3.3 and from
`tools/wp40/dungeon_probe/README.md:37-38`, `:60-63`:

> Every count, timing, digest and byte comparison this probe produces is a
> non-portable observation of one host, one engine build, one seed and one
> repository commit. Only the *relations* the gates assert — equality,
> inequality, exact operation counts, and emptiness of a named delta — are
> invariant, and only within a single run set.

A static-only PASS makes no installed-host claim, and host evidence corroborates
rather than replaces the pinned-source audit of contract section 7.

### The honest cache disclaimer

Copied from `tools/wp40/capture_t0_baseline.sh:239-241` and carried in-band as
the `cache` field of **every** run `summary.json` and of `capture.json`:

```json
"cache": {
  "process": "new_process_new_disposable_world",
  "filesystem_page_cache": "unknown_uncontrolled",
  "cold_cache_claim": false
}
```

`verify_log.sh` stage 3 emits it into the run summary and its re-parse gate
checks all three values, so a summary that dropped or emptied the disclaimer
fails its own gate instead of passing quietly.

Each capture is a new process against a fresh disposable world, and that is all.
Freshness is by construction only: nothing asserts `map.sqlite` was absent, the
filesystem page cache is uncontrolled and unmeasured, and **no timing here is a
cold-cache measurement**.

### The containment-scope sentence, carried rather than quoted

Non-claim 11 above ends "and the summary says it in those words". Quoting the
sentence inside the non-claim does not discharge it, so every run
`summary.json` and `capture.json` carry it as a field of its own,
`containment_scope_statement`:

```json
"containment_scope_statement": "A containment pass means 'no difference in the compared regions', not 'no difference in the chunk'."
```

The `verify_log.sh` stage-3 re-parse compares it against the same literal the
generator was handed, so the emitted sentence and the demanded sentence cannot
drift apart.

### What `first_diff` can and cannot say — the `flat_index: -1` marker

A SHA-256 says only **whether** two byte strings differ, never **how**, and
`compare_runs.sh` sees nothing but digests. **Digests cannot yield voxel-level
facts, and this package invents none.** `first_diff` records therefore come in
exactly two kinds, told apart in band by `flat_index`:

| `flat_index` | What it means |
| --- | --- |
| `>= 1` | **Localized to a named write box.** Some box of the compared region has differing `digest_incl` values; `pos` and `flat_index` are that box's minimum corner. A box, never a voxel. |
| `-1` | **Not localized.** `digest_incl` implicates no named box — either nothing named inside the compared region differs, or the lane is a light lane, which has no per-box `digest_incl` at all, so the box search never runs. `pos` falls back to the compared box minimum corner: well defined, but **never measured**. |

`value_a` and `value_b` are `-1` on **every** record, localized or not: a node
value is not resolvable from digest evidence.

The `-1` marker exists because a plausible integer coordinate does not announce
itself as a placeholder the way `value_a: -1` does. Contract 10.13 tells the
reader of a `no_stable_baseline` outcome to narrow the SEAM sub-box "from the
failing run's `first_diff`" — and **this run set produced exactly that
outcome**. Six of its eight `first_diff` records carry `flat_index: -1`,
including every light-lane record and both SEAM order pairs. Read plainly: this
run set supplies **no** narrowed sub-box for a follow-on run. A follow-on
planned from `{824, -16, 696}` would be planned from the corner of the compared
box, not from anything the probe measured.

### Engine identity — `version_match: false`

The pinned reference sources are **Luanti 5.17.0-dev `df04879`**; the installed
Flatpak that produced every capture is **5.16.1**. The mismatch is recorded, not
hidden: every run summary and `capture.json` carries

```json
"version_match": false
```

in the shape of `capture_t0_baseline.sh:231-234`, together with the raw
`--version` output and its digest. Every runtime observation in this evidence is
therefore an observation of 5.16.1 that **corroborates rather than replaces** the
pinned-source audit of contract section 7.

### The other in-band non-golden labels

| Label | Value | Meaning |
| --- | --- | --- |
| `timings_are_golden` | `false` | no timing here is an acceptance value |
| `timing_replicates` | `1` | one run per (arm, order) cell; no warm-up, no repetition, no variance, no outlier rule |
| `settling_is_probe_local` | `true` | the two-pass quiescence check is this probe's own, not the brief's frozen settling procedure |
| `version_match` | `false` | installed 5.16.1 vs pinned 5.17.0-dev `df04879` |

---

## Cost projection — one unreplicated sample multiplied by four

Contract section 14.3 folds the projection into the arm-`B` order-`O1` capture
instead of buying a fifth engine invocation, so the package costs **four**
invocations and not five.

**In words, because the words are the claim:** the figure below is **one
unreplicated sample multiplied by four**. It is not an estimate with a known
error, it has no variance, no median, no minimum and no maximum, and nothing in
this package computes any of those. A digest has no median and a single sample
has no spread.

### The measured projection

Folded in from the definitive four-capture run, manifest digest
`9ac056ffa4433c80364cc6535dfe6b4ff6ce8b30693248fcad4f834b430699c2`, on the
designated host under Luanti 5.16.1 / LuaJIT 2.1.1784272936. Every figure is
**one sample**. `timing_replicates: 1`, `timings_are_golden: false`.

| Quantity | Source | Value |
| --- | --- | --- |
| arm `B` order `O1` emerge-phase wall time | last `emerge_done` of `run-B-O1` | **0.365 s** (365,347 us) |
| margin against the **45 s** emerge deadline | contract 14.1 / 14.2 | 44.63 s unused; 0.8 % of the budget consumed |
| arm `B` order `O1` whole-run wall time | the `complete` record of `run-B-O1` | **3.018 s** (3,018,258 us) |
| margin against the **60 s** run deadline | contract 14.1 / 14.2 | 56.98 s unused; 5.0 % of the budget consumed |
| `projected_total_wall_s = 4 x observed_run_wall_s` | one unreplicated sample multiplied by four | **12.07 s** |
| observed in-server wall time of all four captures | the four `complete` records | **11.82 s** (3.018 + 2.931 + 2.932 + 2.935) |

The projection over-predicted the observed total by 0.26 s, because arm `B`
order `O1` is the more expensive arm and the projection deliberately multiplies
*it* rather than an average — contract 14.3 calls that "the honest basis". That
agreement is **not** a validation of the method: with one sample per cell there
is no spread to compare it against, and a single close call is not evidence of
predictive accuracy. It is recorded because it happened, not because it proves
anything.

All four runs met both in-run deadlines (`emerge_deadline_met: true`,
`run_deadline_met: true` on every `complete` record), so no run was invalidated
by abort `A-09`. The margins are large because the deadlines are set by the
external capital-sweep hazard of contract 14.2 — the first sweep fires at
t ~ 60 s — and not by the probe's own work.

The outer `timeout` is 180 s per invocation. It is a **ceiling, not an
expectation**: `4 x 180 s` must never be quoted as the expected cost. The
expected per-run in-server work is three mapchunk generations plus **at most 17**
full-volume buffer marshals in arm `B`, and fewer whenever the realized `c`, `p`
or `l` predicate is false.

### Volume literals (contract 14.3 — reproduced, never recomputed)

| Quantity | Value |
| --- | --- |
| engine invocations | 4 |
| distinct measured mapchunks | 3 |
| mapchunk generations, total | **12** (4 runs x 3 chunks) |
| CORE voxels per chunk | 110,592 |
| SEAM voxels | 76,800 |
| hashed nodes per run, per lane, per pass (`digest`) | **408,576** = 3 x 110,592 + 76,800 |
| distinct compared nodes per run | **388,096** (SEAM overlaps CORE(10) and CORE(11) by 10,240 voxels each, so 20,480 are hashed twice) |
| total hashing work per run | approximately 5,628,816 node-lane readings |
| offline negative-test rows exercised by `selftest.sh` | **43**, plus the two non-stream fixtures of contract section 16 |

---

## How to re-run

### The static and offline half — always safe, no engine

```sh
bash tools/wp40/t5_probe/run_t5_probe.sh
```

Preflight (`rg` and `jq` first and unconditionally, then the interpreters and
`bash -n` over the runner and all four sibling scripts), the static Lua gates
(`luac51 -p`, the `SETGLOBAL` budget, the five Lua 5.1 sweeps of
`docs/research/luanti-lua.md:310-321` run explicitly against this tree, and the
10.12 proxy-discipline sweep), the dual-interpreter coordinate audit, and
`selftest.sh` — all **43** negative rows of contract section 16 with their exact
abort fragments, the two non-stream fixtures, and the manifest-digest fixture.
None of it needs an engine capture. A missing or failing `selftest.sh` fails the
run; there is no tolerated absence.

### The four engine captures — opt in

```sh
WP40_T5_PROBE_HEADLESS=1 bash tools/wp40/t5_probe/run_t5_probe.sh
```

Skip-not-fail without the variable. Execution order is `B-O1`, `A1-O1`, `A1-O2`,
`B-O2`: arm `B` order `O1` runs first because contract 14.3 folds the cost
projection into that capture. The manifest-digest order is the 10.7 matrix order
`A1-O1`, `A1-O2`, `B-O1`, `B-O2`, because the digest names the experiment, not
the schedule.

Add `WP40_T5_PROBE_KEEP_WORLD=1` to keep the arm-`B` order-`O1` world for the
five-minute GUI pass of contract section 19; the runner then prints the world
path, the setup commands and the recorded `case_baseline` block.

### Environment

| Variable | Default | Effect |
| --- | --- | --- |
| `WP40_T5_PROBE_HEADLESS` | unset | `1` opts in to the four engine captures |
| `WP40_T5_PROBE_KEEP_WORLD` | unset | `1` keeps the arm-`B` order-`O1` world (19.1) |
| `WP40_T5_PROBE_ENGINE_PATTERN` | `^5[.]16[.][0-9]+$` | engine-version gate; its bytes are bound into the manifest digest |
| `WP40_T5_PROBE_LOG_SHAPE_REGEX` | the committed literal in `verify_log.sh` | stage-1 non-marker garbage gate; its bytes are bound into the manifest digest |
| `WP40_LUA_BIN` | `/usr/bin/luajit` | LuaJIT binary for the coordinate audit |
| `WP40_RESULTS_ROOT` | `tools/wp40/results/t5_probe` | parent of the result directory |
| `WP40_T5_PROBE_RESULT_PREFIX` | empty | prefix for the result directory name |
| `WP40_T5_PROBE_EVIDENCE_ROOT` | `tools/wp40/evidence` | destination root for `--promote` |

### What the manifest digest binds

`schema=wp40-t5-probe-manifest-v1`, then labelled `key=value` lines and one
`sha256sum` over the whole text — never a `sha256sum` **output** line, which
would embed a path:

`game_archive_commit_sha1`, `probe_payload_sha256`,
`engine_version_regex_sha256`, `log_shape_regex_sha256`, the
`config_content_sha256` of all **four** runs in matrix order,
`coordinate_set_sha256`, `case_write_extent_sha256`.

`log_shape_regex_sha256` is contract 12.5 stage 1's requirement that the
committed non-marker-garbage regex have "its bytes bound into the manifest
digest". Widening that regex re-admits ungated log content, so a run set produced
under a widened regex gets a different digest and therefore a different result
directory. The runner reads those bytes back out of `verify_log.sh
--print-log-shape-regex` and hands the same bytes to the gate, so what is bound
is what ran. `selftest.sh` proves the digest is path-insensitive and
change-sensitive against a throwaway fixture, in the shape of
`tools/wp40/dungeon_probe/digest_audit.sh:17-43`.

---

## Result and evidence layout

### Provenance of the committed evidence

The committed run set was captured from the **game archive base commit
`7f5fe9a`** (`7f5fe9a2107c865c0517757e725fd903b09e2d0e`), which is what
`capture.json.digests.game_archive_commit_sha1` records. That commit is one of
the inputs the manifest digest is computed over, so a later re-run at a
different `HEAD` legitimately produces a **different** manifest digest and
therefore a different result and evidence directory name. A digest that does
not match `9ac056ff…` is not by itself evidence that anything went wrong; it
first says the experiment was defined over different bytes.

Captures land in the gitignored scratch tree (`.gitignore:11`), named by the
manifest digest, and the runner **refuses to overwrite an existing result
directory** (exit 2):

```
tools/wp40/results/t5_probe/<manifest-digest>/
    run-A1-O1/  run-A1-O2/  run-B-O1/  run-B-O2/
        raw.log            the byte-for-byte server log
        summary.json       verify_log.sh stage-3 summary for that run
        minetest.conf      the exact configuration bytes bound into the digest
        world.mt
        map_meta.txt       the realized mapgen settings
        exit-status
        MANIFEST.sha256    self-excluding, per directory
    comparison.jsonl       the comparison stream: V-01..V-09 and first_diff
    capture.json           capture manifest: digests, matrix, engine identity,
                           cache disclaimer, in-band non-golden labels
    host.txt               host manifest (tools/wp40/collect_host.sh)
    engine-version.txt     raw --version output of the installed engine
    MANIFEST.sha256        self-excluding, whole tree
    world-B-O1/            only under WP40_T5_PROBE_KEEP_WORLD=1; never committed
```

### Promotion to committed evidence

Reviewed evidence lands at the exact path contract 13.3 and 17 item 10 require:

```sh
bash tools/wp40/t5_probe/run_t5_probe.sh \
     --promote tools/wp40/results/t5_probe/<manifest-digest>
```

```
tools/wp40/evidence/t5-probe-<manifest-digest>/
    run-A1-O1/  run-A1-O2/  run-B-O1/  run-B-O2/
        raw.log  summary.json  minetest.conf  world.mt  map_meta.txt
        exit-status  MANIFEST.sha256
    comparison.jsonl  capture.json  host.txt  engine-version.txt
    MANIFEST.sha256
```

Promotion runs **no engine invocation**. It reads the manifest digest out of the
source `capture.json`, requires the source directory name to agree with it,
verifies every byte against the capture's own self-excluding checksum manifests,
refuses to overwrite an existing evidence tree (exit 2), copies each artefact by
an explicit name so a missing one fails instead of producing a short tree, and
regenerates the per-directory and whole-tree self-excluding `MANIFEST.sha256`
files in the shape of `tools/wp40/capture_t0_baseline.sh:263-267`. The kept world
of 19.1 is deliberately left behind: contract section 20 keeps worlds under
`tools/wp40/results/`, and 19.1 permits the GUI to modify one, so its bytes are
not evidence.

**A deliberate, reported departure.** Contract 13.3 words promotion as "by
overriding `WP40_RESULTS_ROOT`". Doing that literally would re-run four more
captures — breaking the four-invocation ceiling of 14.1, and producing a
*different* run set from the one that was reviewed. `--promote` therefore copies
the reviewed bytes instead. The literal mechanism is still available for anyone
who wants a fresh capture written straight into the evidence tree:
`WP40_RESULTS_ROOT=tools/wp40/evidence WP40_T5_PROBE_RESULT_PREFIX=t5-probe-`.

`.gitattributes` carries exactly one appended line disabling Git's whitespace
diagnostic for this tree's raw logs only, exactly as its first line already does
for the dungeon probe:

```
tools/wp40/evidence/t5-probe-*/run-*/raw.log -whitespace
```

An engine banner therefore cannot make the commit gate rewrite raw evidence;
every authored file keeps normal whitespace checks.

---

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | pass |
| `1` | a gate failed |
| `2` | preflight failure, or refusal to overwrite an immutable result or evidence tree |
| `124` | the 180 s outer `timeout` fired on an engine invocation; always fails the capture |
| `127` | a required tool was missing (`rg`, `jq`, `sha256sum`, `git`, `tar`, `flatpak`, `timeout`, …) |

`127` is checked first and unconditionally for `rg` and `jq`, because exit status
127 inside an `if` condition reads exactly like "no match found"
(`AGENTS.md:133-136`).

---

## Two measured facts this README does state

Everything else is in `comparison.jsonl` and the per-run summaries. These two are
recorded outcomes and are stated here because a reader will otherwise reconstruct
them wrongly:

1. **`liquid_update = 86400` suppresses only the periodic global drain.** It
   suppresses `Server::AsyncRunStep`'s periodic global drain
   (`reference_projects/luanti/src/server.cpp:781-792`) and **not**
   `finishBlockMake`'s per-chunk `transformLiquidsLocal`
   (`reference_projects/luanti/src/servermap.cpp:300`), which — together with a
   later neighbour's own local transform — remains part of every `O1`/`O2`
   result. What is compared is the post-generation result after bounded local
   transform, before background settling.
2. **Micro-case 4 is a bounded paired-order persistence and seam observation that
   attributes no cause.** It reports whether the two halves of the gold bar
   across `x = 847 | 848` persist and whether the lanes differ between the two
   request orders. It attributes no cause to any difference it reports, and
   contract 10.13's cascade — with `inconclusive` as a first-class outcome — is
   applied verbatim to whatever it finds.

Two orders are two orders. They are **not** the nine-schedule gate of the
engineering brief's section 6.2; contract 10.14 records that scope reduction
plainly.

---

## One open observation, recorded and unexplained

This gates nothing, changes no verdict and is not a finding. It is recorded
because it was seen and is not understood, and burying it would be the
dishonest option.

**What was seen.** On the `bounded` micro-case chunk `kx = 8`, the pre-commit
light snapshot rollup `light_outside_box_snapshot_sha256` differs between the
two arm-`B` orders:

| Run | `kx` | `case` | `light_outside_box_snapshot_sha256` |
| --- | --- | --- | --- |
| `B-O1` | 8 | `bounded` | `42289cc6…` |
| `B-O2` | 8 | `bounded` | `a6465270…` |

Contract 6.3 says chunk 8 has **no generated neighbour in either order** —
`kx = 9` is the deliberate gap chunk — so there is no obvious reason for an
order to matter here.

**What was checked, and holds.**

- Within each run `light_outside_box_snapshot_sha256 ==
  light_outside_box_restored_sha256` and
  `restored_outside_dirty_mismatch_count == 0`, so the outside-the-box restore
  is sound in both runs and nothing unverified reached the map.
- The `CORE(8)` light lanes are **equal across all four runs** (one digest,
  `7c98d2da…`, in `A1-O1`, `A1-O2`, `B-O1` and `B-O2` alike), which is what
  `V-04` and `V-06` report. The rollup is taken over the whole emerged volume
  minus the light write box, and the part of that volume lying inside `CORE(8)`
  is therefore equal between the orders. The difference is confined to the
  emerged volume **outside `CORE(8)`** — the chunk's own rind, between `CORE`
  and the edge of its central slice, **plus** the emerged halo. It is outside
  every compared region and outside everything any verdict is computed from.
  The narrower phrasing "confined to the halo" would be an overreach: equality
  of `CORE(8)` licenses only "outside `CORE(8)`", and nothing here establishes
  that the difference lies outside chunk 8's own owner slice.

**The two readings, neither of which this package can decide between.**

1. Genuine order-dependent **native** lighting outside `CORE(8)`. If so it is,
   in the words of verdict `V-04`, a finding about mapgen-state carry-over
   rather than about anything the payload did.
2. The rollup hashes covering something other than what `payload/mapgen.lua`
   claims for them.

**It is unexplained.** Nothing here decides between those two, and nothing here
should be read as leaning toward either. For contrast and not as an
explanation: the same field also differs between the orders on `kx = 11`, and
`kx = 11` *does* have a generated neighbour in one order and not the other. The
probe tests neither case.

---

## The five-minute runtime pass — contract section 19.3

Carried here in full, so the package and the evidence tree hold the plan rather
than only a run of the harness under one optional environment variable. The
runner keeps its own condensed print of the same six steps — together with the
kept world's path and that run's recorded `case_baseline` block — when a capture
is taken with `WP40_T5_PROBE_KEEP_WORLD=1`. **This copy is the complete one**,
reproduced from contract 19.3; where the two differ, the table below is the plan.

Copy the kept `world-B-O1/` directory into
`~/.var/app/org.luanti.luanti/.minetest/worlds/` and open it with the installed
Grudgelands game. **Visual inspection only:** the world came from a git archive
of the base commit while the installed game is whatever was last synced, and the
healing LBM, mob ABMs and node timers run as soon as a player is present. **No
digest is ever recomputed from a world opened in the GUI.**

Expected, and **not** defects:

- unsettled liquid — the capture pinned `liquid_update = 86400`, so the world
  was saved before the periodic drain ever ran;
- an ungenerated column at `x` in `[688, 767]` — `k_x = 9` is the gap chunk and
  was never requested.

Setup:

```
/grantme fly, fast, noclip, teleport, settime
/time 12000
```

The five minutes — the complete contract 19.3 table, reproduced:

| Step | Where | What to look at | Red flag |
| --- | --- | --- | --- |
| 1 | `/teleport 848 4 715`, then `noclip` along `x` from 835 to 860 | the micro-case-4 **gold** bar crossing `x = 847 \| 848`: one continuous 16-node run of `default:goldblock`, 8 nodes each side, 8 x 8 in cross-section. `noclip` is required — `native_surface_y` will normally put the bar inside solid rock | the bar is 8 nodes long instead of 16, one half is missing, or the halves are offset. A reportable observation, not a display artefact — 10.13 says what may and may not be concluded from it |
| 2 | `/teleport 848 <native_surface_y + 3> 715` | lighting continuity across `x = 848` **at the surface**; underground light is uniformly 0, so a seam is not observable at the bar's own depth | a visible vertical light seam whose edge sits exactly at `x = 848`. If `native_surface_y` is `null` for both case-4 columns, skip this step and say so |
| 3 | `/teleport 648 4 715` (`noclip`), then east to 663 | the micro-case-3 cells: 8 x 8 x 8 of water at `x` in `[644, 651]`, `y` in `[0, 7]`, `z` in `[712, 719]`, and 8 nodes east 8 x 8 x 8 of cobblestone stairs at `x` in `[660, 667]`, all facing the same way | stairs with random rotations — the probe writes `param2 = 1` uniformly over that box and no `param2` at all elsewhere |
| 4 | `/teleport 631 4 715` (`noclip`) | the micro-case-2 cut/fill cell: an 8 x 8 x 8 air pocket at `y` in `[0, 7]` directly on an 8 x 8 x 8 stone block at `y` in `[-8, -1]`, at `x` in `[628, 635]`, `z` in `[712, 719]` | the pocket is filled, or the stone slab is missing — the transaction did not survive the blit |
| 5 | anywhere else in `x` in `[608, 687]` or `x` in `[768, 927]` at `z` in `[688, 767]` | ordinary untouched v7 Grudgelands terrain | **any** artificial-looking block, flat plane or hole outside the six declared write boxes. `V-01` should have caught it |
| 6 | anywhere in the three chunks | dig down a few nodes; look for unknown-node placeholders | a purple / `unknown node` block means a content-ID mismatch between the archive game and the installed game — record it and stop; the world is then not comparable |

Total flying distance is under 500 nodes. **This pass confirms no digest, no
timing, no operation count and no order comparison** — those come only from the
headless captures and their gates, and a GUI session corroborates but does not
replace them, in the sense of `tools/wp40/dungeon_probe/README.md:60-61`.

---

## Disposal and non-reuse — contract section 20

**Rule.** Probe code is discarded when the real T5 package is cut. It "never
becomes a parallel production path or production adapter foundation"
(`wp40-acceleration-and-delivery-plan.md:530-532`). The durable result is the
contract, this README and the committed evidence tree.

**Mechanics.** The first commit of the real T5 package deletes this tree entirely
(`git rm -r tools/wp40/t5_probe`). `tools/wp40/evidence/t5-probe-<digest>/` is
**retained** — committed, reviewed, immutable. Working notes, kept worlds and
unreviewed captures live under `tools/wp40/results/` (`.gitignore:11`) and are
left to be deleted.

**The disposal proof the T5 review runs.** Two commands, with their expected
output, so the later reviewer need not rediscover them. Run the `rg` preflight of
`tools/wp40/run_t1.sh:4-9` first — a missing `rg` exits 127 and would read as "no
matches" (`AGENTS.md:133-136`):

```
# (1) the probe tree no longer exists
test ! -d tools/wp40/t5_probe
```

Expected output: **nothing**, and exit status `0`. A non-zero status means the
tree is still present and disposal has not happened.

```
# (2) no probe identifier appears anywhere outside the evidence tree
rg -n 'grug_wp40_t5_probe|t5_probe' \
   mods/ tools/ docs/ game.conf minetest.conf \
   --glob '!tools/wp40/evidence/**' \
   --glob '!docs/research/wp40-t5-0-engine-probe-contract.md'
#   -> must print nothing (rg exits 1)
```

Expected output: **nothing**, and exit status `1` (`rg`'s "no matches"). Any
printed line is a surviving probe identifier outside the evidence tree and fails
disposal. Check (2) covers `docs/` as well, excluding only the contract, which
necessarily names the identifiers.

**Stated limitation.** Both are name-based checks and a rename defeats them. The
contract records that an earlier draft's committed per-file content-hash manifest
was dropped as disproportionate for an eleven-file probe whose deletion is a
single `git rm -r` visible in one diff. The residual risk is someone deliberately
copying a probe file into production and editing its identifiers, which a content
hash would also not survive, and which ordinary review of the T5 diff is the
right instrument for.
