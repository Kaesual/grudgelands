# R8-TAGS verification evidence

Recorded on 2026-09-18 from branch `r8-tags` after fix round 1.

## Engine AOC finding

The rejected compensation was removed completely. Luanti's
`ABMHandler::countObjects` sums each mapblock's static-object store
(`src/server/blockmodifier.cpp:110-125`), while
`ServerEnvironment::addActiveObjectRaw` adds an active object to that store
only when `isStaticAllowed()` is true (`src/serverenvironment.cpp:1451`). For a
Lua entity this is its `static_save` property
(`src/server/luaentity_sao.h:28`). Tag carriers have `static_save = false` and
therefore never enter the `active_object_count_wider` value consumed by
mobs_redo. `api.lua` now uses the unmodified upstream AOC comparison; there is
no helper, subtraction or compatibility path.

## Five-window spawn measurement

Both variants use seed `15912857179583385436`, the same fixed zone and five
one-minute windows from `tools/spawn_probe/run_rate.sh`. The no-carrier variant
is a staged probe-only patch over the final code; the shipped variant uses the
central 1 Hz carrier manager and no spawn-budget modification.

| Variant | Window counts | Mean/min | Sample stddev | Min-max |
| --- | --- | ---: | ---: | ---: |
| Carrier entities disabled | 17, 14, 16, 9, 11 | 13.400 | 3.362 | 9-17 |
| Central 1 Hz carriers | 19, 19, 14, 15, 18 | 17.000 | 2.345 | 14-19 |

The ranges overlap and the central-carrier mean is higher, so the earlier
three-window 16.000 to 14.333/min drop was not reproduced. It is treated as
short-run noise; no compensation is present. Raw logs and summaries live in
`tools/spawn_probe/evidence/r8-fix1-{no-carriers,central-carriers}-5/`.

## Lifecycle census

The committed canonical output and exact command are in
`tools/r8_tags/evidence/lifecycle.txt`. The engine run reported:

```text
before_remove parents=12 carriers=12 linked=12 orphans=0
after_remove  parents=11 carriers=11 linked=11 orphans=0
```

The carrier entity has no `on_step`. Explicit parent hooks remove ordinary
carriers immediately; the shared 1 Hz registry pass detects detached, invalid
or orphaned entries.

## Reproducible interpreter evidence

Run:

```sh
bash tools/r8_tags/run_evidence.sh "$PWD"
```

`tools/r8_tags/evidence/final/` contains the exact commands, input SHA-256
manifest, complete PUC 5.1 and LuaJIT outputs, and their output hashes. The
compact fixture includes the production-path R8 KAT, every `tools/wp11/*_kat.lua`,
all touched compatibility pins and the vendored current-version fixture.
Both 104-line outputs are byte-identical with SHA-256
`c964ec7ba40c8bb17af5988a6582f464cf1e20c808af201d778b192828f02cd2`.

`bash tools/wp11/static.sh` passes, including whole-tree Lua 5.1 parsing,
fresh-server audit, source sweeps, WP40's current unit suite and its existing
byte-identical talent pair. The wider WP39, WP13, WP45, R5 and UI regression
matrix passes under LuaJIT with at most seven concurrent processes.

## Mutation checks

Each mutation below was run under LuaJIT and failed before being restored:

| Mutation | Detected rule |
| --- | --- |
| `MUTATION=1` | per-viewer 25/30 m hysteresis |
| `MUTATION=2` | player-owner exclusion |
| `MUTATION=3` | real tier/telegraph/HP productive text call |
| `MUTATION=4` | central orphan removal |
| `MUTATION=5` | `static_save = false` |
| `MUTATION=6` | `pointable = false` |
| `MUTATION=7` | one carrier per parent |
| `MUTATION=8` | real vendor activation-time install |
| `MUTATION=9` | real villager activation-time install |
| `MUTATION=10` | forbidden visible parent writer |

## Manual runtime remainder

A headless server cannot establish two graphical client views. The remaining
runtime check is two clients observing the same player, mob, NPC and vendor
while independently crossing 25 m and 30 m. It also checks unchanged tag
height, hidden self-tag, live HP/prefix text, and that combat rays hit the
tagged parent rather than its non-pointable carrier.
