# Independent integration micro-fix review

- Candidate HEAD before the two uncommitted edits: `d323c4df11bea02e474e9d4d8b639a9ddbe1d636`
- Reviewer: GPT-5.6 Sol, native agent; did not author either edit
- Scope: `tools/wp40/quality/banner_fixture.lua` and the comment-only correction in `mods/ITEMS/grug_gear/init.lua`
- Result: **CLEAN**
- Findings: 0 Critical, 0 High, 0 Medium, 0 Low
- Runtime repeated by reviewer: none

## Reviewed bytes and supplied evidence

- `tools/wp40/quality/banner_fixture.lua`: `c574818ec3e82ff4c0077ba17abf422ba02ded240187151704be814e9ce82a04`
- `mods/ITEMS/grug_gear/init.lua`: `64e92d2194df29091f22e1df1d56aa803a4176191ab9984c22bfdff21497ffb3`
- `/tmp/grudgelands-r10/banner-fixture-static.txt`: `a6dc019737dfa387d7ea5b0ead3a4cbd1d3bb76e299bef151293fb06b540a378`
- successful aggregate TSV: `c632ed6e4ae0f0130013d252dfa4efe4e5431f1d84caf0159ae1478ba56e5d17`
- successful aggregate log: `245609a78114f86925c563c74d5a9180523f84fc9d474ab9742ab27f3f6b3427`

The banner fixture loads the real `grug_nodes/init.lua`. That production file
now initializes the crop-visual seam and loads `crop_soil.lua` through
`core.get_modpath("grug_nodes")`; the strict stub supplies exactly that path and
rejects any unexpected mod request. `crop_soil.lua` intentionally registers
override names with a leading colon. Normalizing only the leading colon mirrors
Luanti's registration name handling and lets the fixture retain its lookup by
canonical `grug_nodes:guard_banner`. The fixture still checks the real banner
definition and authored atlas. The supplied aggregate completed through MAP-B,
FARM, CAP, ART, EQUIP and GAME fixtures and ends in `PASS`.

The gear edit changes no executable token. It removes the stale statement that
leather armor is inactive and accurately describes the integrated universal
base armor plus Leatherworker refinement split.

Static evidence reports plain-5.1 parser PASS for both files, the expected one
`grug_gear` global assignment, and no five-sweep findings requiring action.

## Prepared engine launchers

- `/tmp/grudgelands-r10/run_final_capitals.py`: `ee4106f36efa179ba18eb2d8a62f79ede50babee572c3ff56fa90dbb4013bdb1`
- `/tmp/grudgelands-r10/final-six-start-launcher.sh`: `e7c48e56bf39a39d4686137e785e42a7504556bb9970fb8710b864d6520bd28b`

No launch blocker was found. The capital launcher uses six distinct reserved
ports (31940–31945), idle CPU/I/O scheduling, absent-output and clean-worktree
guards, records the immutable HEAD, and checks that HEAD after all runs. Its
clean-worktree guard will intentionally refuse the present two-file dirty state;
commit/stage the reviewed edits and freeze the final candidate first.

The six-start wrapper is compatible with `tools/wp13/run_engine.sh`: that runner
creates the absent `.../six-starts/{forward,reverse}` output before the profile
launcher preflight, so both the wrapper's `realpath -e` and exact parent checks
are satisfied. The profile scratch user path also exists before `--version`.
The caller must continue to supply a separate valid `WP13_PORT_BASE` and invoke
the wrapper through `run_engine.sh`; the wrapper is not a standalone fleet
driver. Hash-bind both temporary launcher files in the final evidence.

One expected operational result is not a blocker: final capital runs can exit
nonzero when the old frozen avenue digest detects the accepted inner-ring
geometry change. The strengthened runner writes the service/precinct reports and
`overlay-delta.tsv` before that failure. Treat such exits as pending constrained
delta review, not as permission to rebaseline and not as a failed launch.

