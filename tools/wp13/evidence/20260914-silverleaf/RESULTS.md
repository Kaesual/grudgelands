# Silverleaf increment: results

## Static

`luac51 -p` PASS and `SETGLOBAL [0]` on all twelve changed Lua files, and
tree-wide over `mods/*/grug_*` and `tools`. The five plain-5.1 sweeps report
zero hits scoped to the changed Lua; tree-wide they report only the two
pre-existing `\u{}`-in-a-comment lines in `grug_mobs`.
`tools/check_fresh_server.py`: PASS. (`static.txt`)

## Fixtures

`library_kat`, `blueprint_kat` and `integration_fixture` are byte-identical
under LuaJIT and `tools/bin/lua51` (`kat-luajit.txt` = `kat-puc51.txt`).

| Start | `blueprint_kat` row | blueprint identity SHA-256 |
| --- | --- | --- |
| hearthpine | `61932 46389 41 74 1232 9 10 10 180 15588` | `e07ac54bec01e662f224c629d12c424ec67ca03ee3183c5389943b5100cf9ffb` |
| dawnmere | `66343 44863 52 98 1467 9 12 10 27 15411` | `66c7f8118b0b761d8e7c009f72753e9ec7578c1cb2b6d464f55ca97d54354f74` |
| silverleaf | `68712 50408 48 113 1349 9 11 10 109 15649` | `0419cc5e59bda7ca2cd7533f7e9b0d2da4cc956fef64ee9e402793dd5027a4ae` |

The first two rows and both identities are identical to
`20260914-dawnmere-fixes`. The columns are cells, non-air cells, materials,
lights, oriented nodes, destinations, doors, rooms, authored tree stems and
reachable standing cells.

Silverleaf: 68,712 cells, 50,408 of them not air, 48 materials, 113 lights,
1,349 oriented nodes, 9 reachable destinations, 11 doors, 10 rooms, 109
silverwood standards, 24 stepping stones, 20 barrels, and no bale, cart or
wheel. Bounds x/z `[-63, 63]`, y `[-1, 20]`.

## Final micro

LuaJIT and PUC 5.1.5 byte-identical at
`4d6b082e632c0b4092f45913bb15aba7bf3c8b08095b99d9ea78e449607c1840`.
`inputs-before.sha256` equals `inputs-after.sha256`.

## Engine

Headless Luanti 5.17.0, two seeds, each with two fresh worlds in opposite
owner orders and each of those followed by a disk-only reload: eight passes.

| Seed | Emerged owners | Fitted y: hearthpine / dawnmere / silverleaf | Combined digest |
| --- | --- | --- | --- |
| `531802985935182545` | 21 | 25 / 17 / **21** | `691180ff3f753405567c8627f2e7c274b2e1d2db6c7827414c41f4c74141221c` |
| `8675309` | 28 | 16 / 21 / **42** | `691180ff3f753405567c8627f2e7c274b2e1d2db6c7827414c41f4c74141221c` |

All eight combined digests are equal. The per-start architecture digests are

| Start | digest |
| --- | --- |
| hearthpine | `03311c95b8463c422371e78afabcba743ed70d4f56a013c16a362938ac00693c` |
| dawnmere | `cdbc03239c181f1f41caf1a4a2bd851753c17f2b04e2df95037d1e62893ef4f9` |
| silverleaf | `b9b35277e1b52a88bd25692de1b6b3d8e1f2cb41e1e295816da3bfe7ea611f62` |

on both seeds, in both owner orders, cold and after reload. The first two are
the accepted values of `20260914-dawnmere-fixes`; the digest is over authored
cell positions, names and param2 only, which is why it does not move with the
fitted y.

Every authored node name and param2 of all three settlements matches after
generation and after reload. All 74 Hearthpine, 98 Dawnmere and 113 Silverleaf
lights are lit at midnight -- for Silverleaf that is 93 candles, 11 hanging
lanterns and 9 emberglass lamps, the first start whose lights are not torches.
Every destination and every main-road foot of all three starts is lit and
walkable, the fitted apron carries actual biome soil outside the blueprints,
and the deliberate edit canary survives the reload. The boundary seed also
proves filler-only restoration at the vertical owner boundary at Stillgrave.

`WP40_PROFILE_TIMEOUT=540`, wall clock capped at 600 s per run by
`timeout --kill-after=30`; neither run came near either. No headless server
was left behind: `pgrep -c -f '^luanti.bin --server'` was 0 before and after
each run.
