# R9-PERF fixed-corpus measurement evidence

All six successful runs use seed 0, one emerge thread, the same corrected
`2acaa9a7` profiler tooling, full generated-owner verification, `LC_ALL=C`,
`nice -n 19 chrt --idle 0 ionice -c3`, and the included isolated launcher.
No personal Luanti directory was used. Runtime was Luanti 5.17.0 with LuaJIT
2.1.1784272936; Flatpak commit recorded after the runs was
`c4cf75ca3f44a3743c6f7908913059e3cb9dbd12184810950f8222e838973e3c`
(runtime `org.freedesktop.Platform/x86_64/26.08`). No update occurred.

| Execution order | Result directory | Game revision | Cold/disk ports |
| --- | --- | --- | --- |
| 1 | step1-before-run3 | 3da26ac5109fe977648e3e8ac6139cda0b3e8002 | 32610/32611 |
| 2 | step1-after | 99c34e8c75a9dc866576db67d5f14c27e799e3ab | 32612/32613 |
| 3 | step2-after | d49ce8ec964cff4df65cf6ee62f173cf3b7e4708 | 32614/32615 |
| 4 | step2-before | 99c34e8c75a9dc866576db67d5f14c27e799e3ab | 32616/32617 |
| 5 | step3-before | d49ce8ec964cff4df65cf6ee62f173cf3b7e4708 | 32618/32619 |
| 6 | step3-after | 2acaa9a75372b5274c683f40ace4052f08dc90d2 | 32620/32621 |

The tooling-only first revision has baseline production bytes from `2a308891`.
Game archives were produced with `git archive REV game.conf minetest.conf
settingtypes.txt mods menu`; their SHA256s are in `inputs.sha256`. Archives
remain in the session scratch directory. Per-run snapshot manifests bind the
actual patched engine inputs. `harness.sha256` binds identical comparison,
patch and probe tools (absolute names differ, ordered hashes do not).

Each invocation set `WP40_PROFILE_GAME_ARCHIVE`, `WP40_PROFILE_OUTPUT`,
`WP40_PROFILE_FULL_DIGEST=1`, `WP40_PROFILE_STAGES=0`,
`WP40_PROFILE_SEED=0`, `WP40_PROFILE_PORT_BASE` as above, and
`WP40_PROFILE_TIMEOUT=1100`, then ran `bash tools/wp40/profile/run.sh`
with the included launcher. `invocation.txt` records each result directory.
Runs were sequential; each completed cold/disk phases without orphan servers.
The first two baseline attempts failed before generation (sandbox Flatpak
instance allocation, then missing explicit result-directory mount); they are
excluded. No host-before sidecar was captured for the successful first run.

All twelve cold/disk summaries agree on 97 generated owners / 49,664,000
voxels, sample digest, vocabulary and full content/param2/light digest:
`4bc7438edfe1ecfa871fdc39c2ada49d7c59b57769e037fd7d6c3fa627812a9a`.
Disk phases generated zero callbacks. Diagnostic hashing happens after the
timed interval, one owner/channel at a time. It is included separately in each
summary. The ten explicit corpus owners and 87 startup/other owners are
spatial callback populations within a fresh start; this is not a separately
quiescent exploration experiment.

| Step | All callback total change | Writer change | Fresh-start elapsed change |
| --- | ---: | ---: | ---: |
| 1: liquid short-circuit | -13.90% | -29.24% | -9.84% |
| 2: coast retention/cache | -15.52% | -1.45% | -8.74% |
| 3: inner lighting delegation | -2.29% | -11.83% | -1.53% |
| Sequence endpoints | -27.47% | -34.90% | -17.26% |

These are three alternating single pairs, not replicated statistical
estimates. Step 2 planner time fell 26.17%; step 3 planner time varied +6.91%.
Endpoint comparison reuses runs 1 and 6; it is not a fourth fresh pair and
cannot distinguish time drift. Baseline/final measured fresh-start elapsed
was 77.572800/64.187408 seconds. Explicit-corpus callback totals were
14.799624/8.514990 seconds (-42.46%). These are soft performance observations,
not changed gameplay limits or a claim about 100-player performance.

Reproduce comparisons using `python3 tools/wp40/profile/compare.py
--pair-labels before after before=RESULT before/after assignments...`;
`step2` was executed after then before (preserve that order when supplying its
labeled paths). The committed comparison TSVs contain every population and
metric. Portable writer fixture outputs bind data, param2, light, intent and
trace equivalence; lighting fixture covers standalone versus composed calls
and validation before setters. Full gates and independent review are tracked
in the external session report, not implied by this measurement evidence.
