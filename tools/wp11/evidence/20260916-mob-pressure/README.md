# Mob pressure — evidence (round 4, 2026-09-16)

Branch `wp11-r4-mob-pressure`, base `dfb32cd5`. The implementation note is
[`docs/research/mob-pressure.md`](../../../../docs/research/mob-pressure.md);
this directory is what it cites.

## What is here

| path | what it is |
|---|---|
| `static.sh` / `static.txt` | parser + SETGLOBAL per changed file and tree-wide, the five plain-5.1 sweeps (scoped and tree-wide), the fresh-server audit, the WP40 R7 unit suite, and every census the note quotes |
| `kat.sh` / `kat.txt` | both KATs under LuaJIT **and** PUC 5.1 with a byte-identity check, the six mutations, the three suites this lane's files are loaded by, and the final-micro pair |
| `kat/` | the KAT outputs themselves, the mutation lines, `suites.txt`, and the final-micro TSVs with `micro-pair.sha256` |
| `engine/cadence-at-4.4/` | the runtime test of `combat_stats.md` §4, taken with the aggressive band still at 4.4 — the cadence patch **alone** |
| `engine/cadence-at-4.6/` | the same test on the shipped tree, with the band at 4.6 |
| `engine/ranged/` | the Bandit Archer boot: roster census, camp config, and the archer shooting |
| `files.sha256` | the sources this lane changed, as committed |

`files.sha256`, `static.txt`, `kat.txt` and the `cadence-at-4.6` boot all
record the tree **with** the speed commit applied. If that commit is dropped,
those rows describe a tree that no longer exists; the `cadence-at-4.4` boot is
the one that measures the cadence patch on its own.

Both engine directories hold, per boot, the launcher's `boot.log`, the
server's own `server.log`, the extracted `probe.txt` and an `errors.txt` that
is empty in every run. `runner.out` is the whole runner transcript including
the `api.lua` sha256 of each boot.

## Headline numbers

**`grep -rn "set_physics_override" mods/`** — three writers and seven call
sites before, **one call site** after (`grug_core/movement.lua:194`).

**Punches per 10 s, one level-1 boar (`reach` 2, `punch_interval` 1) against a
target receding at the engine's walk speed 4.0, and against a standing target
as the control.** 111 server steps per window, `dtime_max` 0.091 s in all of
them, `target_lost` 0:

| `run_velocity` | before, receding | after, receding | before, standing | after, standing |
|---|---|---|---|---|
| 4.4 | **1** | **10** | 10 | 10 |
| 4.6 | **1** | **10** | 10 | 10 |

Mob-to-target gap, receding: **2.31–2.70 m before** (outside its own reach of
2) against **1.49–1.87 m after**. The speed raise on its own changes the
receding rate by nothing, which is the measured case for treating it as a
separate question.

**Ranged roster:** `dogfight=42 dogshoot=5` across 55 registered `grug_mobs`
entities; every `dogshoot` family at `view_range` 16 and no melee family above
16 except the documented aquatic Kraken. Four registered ranged mobs of 43
before, **five of 44** after. One archer fired 3 arrows for 3 hits in a 15 s
window at 12 m.

**GRUG PATCH markers in `mods/ENTITIES/mobs/api.lua`:** 40 → **43**.

**`tools/wp13/final_micro.lua` pair:**
`4d41e72a8980389f6dad96341bb20443f9ddc903eb1450930149c63ac9952484` under both
interpreters — **byte-identical to the digest frozen by
`tools/wp13/evidence/20260916-kezamba-terrain/kat/micro-pair.sha256`**, i.e.
unchanged. This lane touches no mapgen file.

## Reproducing

```sh
bash tools/wp11/evidence/20260916-mob-pressure/static.sh
bash tools/wp11/evidence/20260916-mob-pressure/kat.sh

git show <base>:mods/ENTITIES/mobs/api.lua > /tmp/api.before.lua
PORT=<your block> TIMEOUT=420 nice -n 19 \
  bash tools/wp11/run_cadence_probe.sh /tmp/out /tmp/api.before.lua 15912857179583385436

PORT=<your block> KEEP=1 SEED=15912857179583385436 \
  PROBE="$PWD/tools/wp11/ranged_probe" nice -n 19 bash tools/luanti_headless.sh 420
```

`run_cadence_probe.sh` builds two throwaway mirrors of the game under `/tmp`
and swaps only `api.lua` in the "before" one; the repository is read and never
written. Timings recorded here: ~110 s per cadence boot (of which ~55 s is
`grug_core`'s six-start preload, which the probe waits out before measuring)
and ~100 s for the ranged boot. All engine work ran under `nice -n 19` on
ports 31201–31203, one server at a time, and `pgrep -af 'luanti.bin --server'`
showed nothing on that block afterwards.

## Two things the sweeps print that are not this lane's

- **SWEEP 4 and SWEEP 5 hit the vendored `mods/ENTITIES/mobs/api.lua`.** The
  `&` matches are upstream comment prose ("dig & drop a node"), and
  SWEEP 5's `api.lua:4416` is upstream's own `minetest.is_protected`. The
  AGENTS.md sweeps are scoped to `mods/*/grug_*`; `api.lua` is listed in this
  script's CHANGED set because this lane patched it, which surfaces those
  pre-existing upstream hits. None is new and none is in Grudgelands code.
- **SWEEP 4 also hits Markdown table pipes quoted inside Lua comments** and
  two `string.format` patterns in `grug_classes/selection.lua`, all
  pre-existing.
