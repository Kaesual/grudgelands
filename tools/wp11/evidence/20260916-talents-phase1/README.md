# WP11 talents, phase 1 — evidence (2026-09-16)

Round 4, lane W1. Branch `wp11-r4-talents-phase1`, based on main `dfb32cd5`.
Scope: lanes X1 and X2 of `docs/design/skill_trees.md` §4, plus the code halves
of rulings 19, 20 and 25 and of §7 task 5. What shipped and what is open:
`docs/research/wp11-talents-phase1.md`.

## Files here

| File | What it is |
|---|---|
| `files.sha256` | the sources this increment changed, at the bytes every result below was produced from |
| `kat-luajit.txt` | `tools/wp11/talent_tree_kat.lua` under LuaJIT |
| `kat-puc.txt` | the same fixture under `tools/bin/lua51` — **byte-identical** |
| `mutations.txt` | `tools/wp11/mutations.sh`: the clean baseline, then eight deliberate breaks, each one going red, each file restored from a byte copy afterwards |
| `static.txt` | `tools/wp11/static.sh`: parser + SETGLOBAL per changed file and tree-wide, the five plain-5.1 sweeps scoped and tree-wide, `check_fresh_server.py`, `tools/wp40/r7/run.sh unit`, and the KAT under both interpreters |
| `engine-server.log` | the headless boot on port 31114 with `tools/wp11/probe_talents` staged; the probe's own lines are the `WP11PROBE` rows |
| `engine-boot.txt` | what `tools/luanti_headless.sh` reported for that boot |
| `timings.txt` | wall-clock of every check above (`tools/wp11/timings.sh`); the headless boot is not in it because the launcher owns its own `timeout` — it passed inside 150 s |

## Headline results

- KAT: `wp11_talents_result PASS 0`, identical under both interpreters,
  digest `83c7a9b11ff41d02c09f7d2f9f83265da77785b004fd5ce251a2a1d642998a02`.
- Engine probe: `WP11PROBE RESULT PASS 0`, boot PASS on port 31112, no
  `ERROR`/`ModError` line in the log.
- `bash tools/wp40/r7/run.sh unit` PASS; `python3 tools/check_fresh_server.py`
  PASS; parser and SETGLOBAL clean on all nine changed files and tree-wide.
- `tools/wp13/final_micro.lua` pair, run on this branch AND on main
  `dfb32cd5`: all four runs
  `4d41e72a8980389f6dad96341bb20443f9ddc903eb1450930149c63ac9952484`. This
  lane touches no mapgen file and no frozen digest under
  `tools/wp13/evidence/20260915-*/` moves.

## The counts, as the KAT prints them

```
talents 48    trees 6    ranks per tree 28    ranks per class 56
points at level 60 30    first point level 2
a capstone 21 in-tree points = level 42;  two would be 42 > 30
a whole tree 28 points = level 56, two points left over
effect keys 46 declared, 24 read by a consumer, 22 pending lane X3
base kit per class after ruling 19: warrior=4 mage=4 priest=4
rage before 12 / 4 / 2  ->  after 8 / 3 / 5
  swings to a full bar   9 -> 13
  seconds 100 to empty  50 -> 20
  swings per Mighty Blow 3 -> 4
```

## The ports this lane used

31110 and 31112, both inside lane W1's block 31100–31199. Both run
directories were removed after their logs were copied here; `pgrep -af
'luanti.bin --server'` shows no process of this lane's.
