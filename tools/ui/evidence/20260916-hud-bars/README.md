# Evidence — HUD bars (round 4, lane H, 2026-09-16)

Branch `ui-r4-hud-bars`, based on main `dfb32cd5`. What shipped, why, and
every number: **[docs/research/hud-bars.md](../../../../docs/research/hud-bars.md)**.
The user's ruling and the analysis it came from:
`docs/research/hud-bars-task-card.md`.

## Files

| File | What it is |
|---|---|
| `files.sha256` | the sources this lane changed, at the state everything below was taken from |
| `kat-luajit.txt`, `kat-puc51.txt` | `tools/ui/hud_bars_kat.lua` under both interpreters — byte-identical, `PASS 0` |
| `mutations.sh`, `mutations.txt` | the rule broken on purpose four times; the fixture goes red each time |
| `static.sh`, `static.txt` | parser + SETGLOBAL, the five plain-5.1 sweeps scoped and tree-wide, the fresh-server audit, the media-licence row and the texture regeneration |
| `engine.sh`, `engine-probe.log` | one headless boot (port 31307) of the real game with the disposable probe staged in |

## Reproducing

From the repository root, with `LC_ALL=C`:

```sh
luajit          -e 'io.write(dofile("tools/ui/hud_bars_kat.lua")("."))'
tools/bin/lua51 -e 'io.write(dofile("tools/ui/hud_bars_kat.lua")("."))'
bash tools/ui/evidence/20260916-hud-bars/mutations.sh
bash tools/ui/evidence/20260916-hud-bars/static.sh
bash tools/ui/evidence/20260916-hud-bars/engine.sh        # boots a server
```

Plus the two package-wide gates this lane leaves untouched:

```sh
bash tools/wp40/r7/run.sh unit                            # PASS
luajit          tools/wp13/final_micro.lua . /tmp/h-jit.tsv luajit
tools/bin/lua51 tools/wp13/final_micro.lua . /tmp/h-puc.tsv puc51
# both: 4d41e72a8980389f6dad96341bb20443f9ddc903eb1450930149c63ac9952484,
# identical to the same pair taken on dfb32cd5 before any edit
# (this lane touches no mapgen file)
```

## Headline numbers

- `hud_bars_resolution hp_max 325 at_324 178 at_1 2 full 180` — a 325 HP
  Warrior at 324 HP never reads full, at 1 HP never reads empty. The
  rejected statbar's step at the same maximum is 16.25 HP.
- `hud_bars_idle_packets 0 over 4 ticks` — an unchanged player costs nothing,
  although `hud_change` sends on every call
  (`src/script/lua_api/l_object.cpp:2026`).
- `hud_bars_one_point scale_writes 1 text_writes 1 total 2` — one lost hit
  point costs exactly two packets.
- Worst steady-state cadence (a level-60 Mage regenerating) is **4
  packets/s/player, the same as before**; see §4.2 of the research note.
- `HUDPROBE flags healthbar=false breathbar=false` and fourteen element
  definitions read back through `hud_get` inside the real engine.

A headless server has **no client**, so nothing here is a claim about how
the bars look. That part is the playtest, and §10 of the research note says
what to look at in a fresh world.
