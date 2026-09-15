# WP13 round 3, NPC work lane — evidence

Branch `wp13-r3-npc-work`, based on main `19abee02`. The change is described in
`docs/research/wp13-npc-work.md`; this directory is the measurement.

## What is here

| file | what it is |
|---|---|
| `static.sh` | the static gate script: parser + SETGLOBAL per changed file and tree-wide, the five plain-5.1 sweeps, the fresh-server audit, the six start identities, both KATs under both interpreters, and the neighbouring fixtures |
| `static.txt` | its output |
| `files.sha256` | the sources this increment changed |
| `start_npcs_kat-luajit.txt`, `start_npcs_kat-puc51.txt` | the placement/behaviour KAT under both interpreters (identical) |
| `blueprint_kat-luajit.txt`, `blueprint_kat-puc51.txt` | the blueprint KAT under both interpreters (identical) |
| `load-before.txt`, `load-after.txt` | the engine load probe, on the tree before the change and on the finished tree |
| `npc-probe.txt` | the three-boot behaviour probe's own lines |
| `npc-probe-boot1.log`, `npc-probe-boot2.log`, `npc-probe-boot3.log` | its server logs |

## How to reproduce

```sh
cd <repo>
bash tools/wp13/evidence/20260915-npc-work/static.sh

# the load probe; run it once on this tree and once on 397ae840 (the probe's
# own first commit, whose mods are main 19abee02) for the before/after pair
PORT=31420 tools/wp13/run_npc_load.sh /abs/out/load-after

# the three-boot behaviour probe
PORT=31430 tools/wp13/run_npc_probe.sh /abs/out/npc-probe
```

Both engine scripts run through `tools/luanti_headless.sh`, which stages the
game into a fresh scratch directory under `/tmp`, points `LUANTI_USER_PATH` and
every XDG directory at it, kills only its own server and deletes the tree
afterwards. Nothing under the user's personal Flatpak folder is read or
written. Ports are this lane's block, 31400-31499.

## The load measurement

`tools/wp13/run_npc_load.sh` boots the game once and walks the six starts one
at a time: forceload the arrival, settle 8 s, measure 30 s, release. A forceload
activates blocks exactly as a player standing there would
(`ActiveBlockList::update` starts from the forceloaded set); what it cannot do
is make `core.get_connected_players()` answer, so the two player-gated paths in
the game — the vendor presence poll and the nametag gate — are idle during the
measurement and every number below is the floor.

Per start, before -> after:

| number | before | after |
|---|---|---|
| active mobs in the settlement | 9 | 11 |
| of which residents | 4 (all ambling) | 6 (2 work, 3 static idle, 1 walker) |
| walker share | n/a | 16.7 % |
| `core.find_path` calls in a 30 s window | 0 | 0 |
| mean server step | 90.24–90.33 ms | 90.36–90.44 ms |
| worst server step | 91.00–92.16 ms | 91.00–93.15 ms |

The mean server step is not by itself a measure of the NPCs: a dedicated server
runs a FIXED step (`dedicated_server_step`, 0.09 s) and only exceeds it once it
cannot keep up. It says there is headroom. What measures the NPCs is the
microbenchmark beside it — every settlement NPC's `do_custom` called once per
simulated second inside `core.get_us_time()`:

| | before (9 NPCs) | after (11 NPCs) |
|---|---|---|
| per settlement-second | 18.7–39.7 µs | 14.3–62.4 µs |
| per NPC-second | 2.7–5.7 µs | 1.3–5.7 µs |

Both runs are in the tens of microseconds per settlement per simulated second,
i.e. under a tenth of a percent of one 90 ms server step, and the spread within
a single run is wider than the difference between the runs — other lanes were
running their own headless servers during the "after" run (`uptime` load average
7.7 on 16 cores). The honest reading: **two more NPCs per start cost nothing
measurable, and no resident of any kind asks the pathfinder.**

`find_path_total` over a whole boot is 3 before and 7 after; those calls happen
outside every measured window, during the preload and the guard placement, and
`patrol.lua`'s stuck rescue is the only caller a settlement has.
