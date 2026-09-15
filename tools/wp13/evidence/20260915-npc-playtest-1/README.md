# WP13 playtest round 1 — settlement NPC behaviour (2026-09-15)

Evidence for the eight defects the user found in the GUI on 2026-09-15. The
round itself is written up in
[docs/research/wp13-start-npcs.md](../../../../docs/research/wp13-start-npcs.md)
under "Playtest round 1"; this directory holds what the gates printed.

| file | what it is |
| --- | --- |
| `static.sh` / `static.txt` | `luac51 -p` per touched file and tree-wide, the SETGLOBAL count, the five plain-5.1 sweeps (touched files, `mods/*/grug_*`, `tools/wp13`), `check_fresh_server.py` |
| `final-micro.sh` / `final-micro/` | the one bounded final-byte process: every WP13 fixture in one interpreter, once under LuaJIT and once under `tools/bin/lua51`, with the input set hashed before and after both runs |
| `kat.txt` | the `start_npcs_kat` report on its own, which is the part of the micro TSV this round rewrote |
| `start-identities.txt` | the six start blueprint identity digests, to be diffed against `20260914-capital-parts/start-identity.txt` |
| `npc-probe/` | `tools/wp13/run_npc_probe.sh`: three boots on ONE world through `tools/luanti_headless.sh` with the disposable probe of `tools/wp13/npc_probe` |
| `highcourt/` | `tools/wp13/run_highcourt.sh` once, the capital's own pass |

## The gates

- **Final micro pair byte-identical**, output_sha256
  `1f2830bba4d40a33ace40075d6d12e82e7279c365fa589c6ae3d3caefd752730` from both
  interpreters. It was `871f0d2942f9e1dc73b6a437fa7fa6e86902075cf8f8fefe096538eddab4c4bf`
  at `70702d2`; the `start_npcs_kat` report is part of the hashed text and this
  round rewrote it.
- **Static**: clean, and every hit is pre-existing — but they are not all prose.
  The `\u{}` note in levels.lua and target_frame.lua and the `|` of §-table
  quotes and `|x|` notation are comments; sweep 5 over `tools/wp13` reports
  **fifteen real `os.exit` calls**, in `dump_blueprint.lua`, `dump_highcourt.lua`,
  `dump_capital_part.lua` and `highcourt_plots.lua`. Those are code. They are
  standalone command-line tools that never run inside the engine sandbox the
  sweep is about, and this round neither added nor touched one.
  `check_fresh_server.py` PASS.
- **Six-start identities**: byte-identical to the committed baseline. This round
  writes no mapgen cell.
- **Engine**: see `npc-probe/probe.txt` and `highcourt/`.

## What the probe proves, and how

The probe forceloads a 162-mapblock grid around Hearthpine's anchor instead of
impersonating a player. `ActiveBlockList::update` starts its new list from the
forceloaded set (`serverenvironment.cpp`), so a forceload activates mapblocks
exactly like a nearby player — and everything under test reads the map, never
`core.get_connected_players`. A fake PlayerSAO would also have been visible to
every other mod's globalstep.

The census counts this settlement's NPCs **by identity out of the map**
(`_grug_start` on an activated entity), not out of the placement log, and fails
loudly if it ever exceeds the roster.

Reading `npc-probe/probe.txt`:

- `event=census phase=… roster=9 marked=9 live=9 twins=0` is the item-1 line. It
  stays that way while all nine NPCs stand 40 nodes off their sockets.
- `phase=one_strike … live=8` and then `phase=refilled … live=9`, with exactly
  one `is marked but empty` warning in `npcs.txt`, is the other half: a marker
  whose NPC is really gone is freed — but only after three passes agree.
- `event=pos` is the item-3 trace.
- `event=hp` / `event=hp_heal` are item 8. The `watch_gate` guard reads `79/115`
  on both reboots: wounded by the wolf on boot 1, and the wound survives two
  reloads with its maximum intact, which is the state the defect turned into
  `79/10`.
- `event=hostile` is item 5: the wolf beside the villager keeps `target=nil` and
  65 HP, the wolf beside the guard is attacked by it and attacks back.
- The `ready` census can read `live=0`. It fires in the same globalstep as the
  forceload, and the engine's active-block management runs on its own two-second
  interval, so nothing is activated at that instant — which is also why the free
  path cannot misfire there: `compare_block_status` answers "loaded", not
  "active", until the pass that activates the block activates its objects.
