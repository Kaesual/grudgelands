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
| `highcourt/` | `tools/wp13/run_highcourt.sh` once, the capital's own pass: zero ERROR, the committed avenue digest, and `guards 19/19 flair 49/49 vendor 2/2 quest 1/1 new 15 pending 0` — 71 of 71 sockets filled with no player in the world. The `new`/`pending` split of a single run is not a gate; `pending 0` is the part that is |

## The gates

- **Final micro pair byte-identical**, output_sha256
  `4f2d2b769578c00bd9947a5904dd4f1635fae0e2503420f990a585f7841cbdf5` from both
  interpreters, rebased onto `d2538b9`. It was
  `871f0d2942f9e1dc73b6a437fa7fa6e86902075cf8f8fefe096538eddab4c4bf` at
  `70702d2`, and three groups of rows moved: the `start_npcs_kat` report, which
  is part of the hashed text and which this round rewrote, plus the
  `highcourt_throne` row and Highcourt's identity `187f79e0…`, which are main's
  throne lane and not this one's. The six start identities are unchanged in it,
  and `start-identities.txt` says so separately.
- **Static**: clean, and every hit is pre-existing — but they are not all prose,
  and this round added none of them. Five kinds, in full:
  1. the `\u{}` note in `levels.lua` and `target_frame.lua` (a comment about the
     escape, not an escape);
  2. `|` inside §-table quotes and `|x|` notation, all over `grug_mobs`
     (comments, read by sweep 4 as a bitwise or);
  3. `::Transform::` inside C++ symbol names in `grug_visuals/wield_geometry.lua`
     and `tools/wp13/wield_transform_kat.lua` (comments, read by sweep 1 as a
     `goto` label; they arrived with main's visuals lane);
  4. the file name `minetest.conf` in three `grug_core/atmosphere*.lua` comments
     (read by sweep 5 as the deprecated namespace);
  5. **fifteen real `os.exit` calls**, in `dump_blueprint.lua`,
     `dump_highcourt.lua`, `dump_capital_part.lua` and `highcourt_plots.lua`.
     Those are code, not prose. They are standalone command-line tools that never
     run inside the engine sandbox the sweep is about, and this round neither
     added nor touched one.

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
- `event=unload` … `socket_block_active=true npc_block_active=false`, then two
  censuses reading `marked=9 live=8` and a third reading `9/9` once the NPC's own
  block is forceloaded, is the review's finding: the socket's mapblock being
  active says nothing about the NPC's.
- `event=pos` is the item-3 trace.
- `event=hp` / `event=hp_heal` are item 8. Two guards read `109/115` and
  `111/115` on both reboots: wounded by the wolf on boot 1, and the wounds
  survive two reloads with the maximum intact. `hp_heal` is the injection that
  makes the defect's state on purpose and watches the activation path undo it.
- `event=hostile` is item 5: the wolf beside the villager keeps `target=nil` and
  65 HP, the wolf beside the guard is attacked by it and attacks back.
- The `ready` census can read `live=0`. It fires in the same globalstep as the
  forceload, and the engine's active-block management runs on its own two-second
  interval, so nothing is activated at that instant — which is also why the free
  path cannot misfire there: `compare_block_status` answers "loaded", not
  "active", until the pass that activates the block activates its objects.
