# WP13 start NPCs: the evidence of the 2026-09-14 socket increment

The increment itself is recorded in
[docs/research/wp13-start-npcs.md](../../../../docs/research/wp13-start-npcs.md).
Everything here is measured on the frozen bytes that record describes; the
previous WP13 record is `../20260914-round-a-blueprints/`.

## Reproduce

| Script | What it proves |
| --- | --- |
| `kat.sh` | `library_kat` + `blueprint_kat` + `integration_fixture` + `settlement_sockets_kat` in one process under LuaJIT and under `tools/bin/lua51`, byte-identical (`kat-luajit.txt`, `kat-puc51.txt`), plus the atmosphere pair |
| `final-micro.sh` | the single bounded final-byte pair, with its input set hashed before and after both runs (`final-micro/`) |
| `dump.sh` | the per-start blueprint dump SHA-256 (`dumps.txt`) — the identity check for "this start's cells did not move" |
| `static.sh` | `luac51 -p`, the SETGLOBAL count, the five plain-5.1 sweeps, the unchanged dumps and `check_fresh_server.py` (`static.txt`) |
| `engine.sh` | two headless boots on ONE world, seed 531802985935182545, and a census of the static objects the first boot left on disk (`engine-boot1.log`, `engine-boot2.log`, `engine-errors.txt`, `engine-census.txt`) |
| `files.sha256.sh` | the frozen-byte manifest (`files.sha256`) |

## The three numbers to read first

- **`dumps.txt` is identical to the round-A record.** Sockets are landmarks, not
  cells, so no settlement identity byte moved. The six identity SHA-256s in the
  `wp13_integration` row of `final-micro/micro-*.tsv` say the same thing from
  the other side.
- **`engine-boot1.log`**: six starts ready, then per start
  `guards 3/3 flair 4/4 vendor 1/1 quest 1/1 new 9 pending 0` — 54 NPCs placed
  the moment each prepared area was loaded, with no player in the world.
- **`engine-boot2.log`**: the same six lines with `new 0 pending 0`, and
  `engine-census.txt` counts exactly 54 static objects in the kept world's
  `map.sqlite` afterwards. A static object in a loaded but inactive mapblock is
  invisible to every Lua query, which is why the census exists: it is the only
  way to see that the roster survived the restart AND was not doubled.

## Note on the first, discarded boot

The first headless boot of this lane was thrown away and re-run. Its presence
scan matched by entity NAME inside an 8-node radius, so at Hearthpine it saw the
guard of the post next door — the two gate posts are eight nodes apart and carry
the same faction guard — "restored" a marker nobody had lost and left that post
empty: three guards became one. `socket_occupied` now matches the socket, and
that measurement is in its comment. The boots recorded here are from after the
fix.
