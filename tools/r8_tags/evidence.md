# R8-TAGS verification evidence

Recorded on 2026-09-18 from branch `r8-tags`. The three spawn samples use
the same fixed zone and the three one-minute windows produced by
`tools/spawn_probe/run_rate.sh`.

## Spawn budget

| Candidate | Window counts | Total | Rate/minute |
| --- | --- | ---: | ---: |
| Parent tags, before carriers | 19, 17, 12 | 48 | 16.000 |
| Carriers, uncompensated | 14, 17, 12 | 43 | 14.333 |
| Carriers, compensated | 22, 19, 14 | 55 | 18.333 |

The uncompensated carrier candidate reduced the measured rate by 10.4%.
The accepted candidate removes tag carriers from mobs_redo's wider active
object count only when the raw count has reached the row limit. Its measured
rate is 14.6% above the baseline. The raw logs and summaries are retained in
`tools/spawn_probe/evidence/r8-tags-{before,after,compensated}/`.

## Lifecycle census

Command:

```sh
KEEP=1 PORT=31621 PROBE="$PWD/tools/r8_tags/grug_tag_probe" \
  nice -n 19 bash tools/luanti_headless.sh 90
```

The probe observed exact equality before and after removing one tagged parent:

```text
before_remove parents=12 carriers=12 linked=12 orphans=0
after_remove  parents=11 carriers=11 linked=11 orphans=0
```

The carrier also removes itself on its next step when its attached parent is
gone; the offline lifecycle mutation proves that omitting this removal is
detected.

## Automated checks

- `bash tools/wp11/static.sh`: pass, including whole-tree Lua 5.1 parsing and
  the five source sweeps.
- All `tools/wp39/*.lua`, `tools/wp13/*_kat.lua`, `tools/wp45/*.lua`,
  `tools/r5_multiplayer_feel/kat.lua`,
  `tools/r5_progression/progression_kat.lua`, `tools/ui/*_kat.lua`, and both
  `tools/r8_tags/*_kat.lua`/`kat.lua` fixtures: pass under LuaJIT.
- The final compact fixture ran once under PUC Lua 5.1 and once under LuaJIT.
  Both 50-line outputs have SHA-256
  `3b76425459f201a0cfba1746f07a046215f966dc036da82aedefa46ab68a3236`.
- The headless lifecycle run and the final 60-second headless boot contained
  no `ERROR` or `ModError` lines.

## Mutation checks

The following deliberate mutations each failed the named KAT and were then
restored:

| Mutation | Detected rule |
| --- | --- |
| `tools/r8_tags/kat.lua`, `MUTATION=1` | 25/30 m per-viewer hysteresis |
| `tools/r8_tags/kat.lua`, `MUTATION=2` | player-owner exclusion |
| `tools/r8_tags/kat.lua`, `MUTATION=3` | prefix/HP text propagation |
| `tools/r8_tags/kat.lua`, `MUTATION=4` | orphan carrier removal |
| `tools/r8_tags/spawn_budget_kat.lua`, `MUTATION=1` | carrier-neutral AOC count |

## Manual runtime remainder

A headless server cannot establish two graphical client views. The remaining
runtime check is therefore two clients observing the same player, mob, NPC and
vendor while independently crossing 25 m and 30 m; it also checks unchanged
tag height, hidden self-tag, live HP/prefix text, and that combat rays still hit
the tagged parent rather than its non-pointable carrier.
