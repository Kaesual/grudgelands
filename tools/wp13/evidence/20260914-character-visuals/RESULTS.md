# Results — WP13 character visuals

Candidate: see `candidate.txt`. Base: `main` at `9026d89`.
Second pass, after the coordinator's review verdict.

## Gates

| Gate | Result |
| --- | --- |
| `character_visuals_kat.lua` + `visuals_order_kat.lua`, LuaJIT vs `tools/bin/lua51` | identical, `sha256 85db85ab80ce74848dbb0ae431509958272a78c1c99d6339514b2e57ae2914ec`, `wp13_cv_result PASS 0` and `wp13_order_result PASS 0` |
| `luac51 -p`, every changed file | PASS |
| `luac51 -p`, all of `mods/*/grug_*` and `tools` | PASS |
| `SETGLOBAL` | one per mod table (`grug_visuals`, `grug_classes`, `grug_gear`, `grug_mobs`), zero in `compose.lua`, `apply.lua`, `levels.lua`, the three mob defs, `vendors.lua` and the KAT |
| five plain-5.1 sweeps, scoped and tree-wide | zero hits outside prose (design-doc table rows with `\|`, and one comment naming `\u{}` in order to forbid it) |
| `tools/check_fresh_server.py` | `Fresh-server source audit: PASS` |
| `LICENSE-media.md` row per shipped PNG | 14/14, none missing |
| art regenerates byte-identically | `3a513139d90a9dbcab964214acb1584a3707e16cd6badabc7d2932d72dcdb203` before and after |
| per-face overlay coverage | PASS, no complaints; both chest overlays cover all six torso faces at 100% |
| headless boot, `tools/luanti_headless.sh 180` | `headless boot: PASS`, 0 `ERROR`/`ModError` |

## KAT rows

```
wp13_cv_inputs     6 races, 2 lines, 4 slots, 6 brackets
wp13_cv_index      48 armor pieces: cloth=24 metal=24; chest/feet/head/legs 12 each
wp13_cv_matrix     366 compositions, 365 new cache entries, digest 0760993141
wp13_cv_textures   14 distinct textures named, 0 missing on disk
wp13_cv_shapecheck 4 malformed strings rejected, each with its own reason
wp13_cv_stature    0.85..1.12; dwarf 1.10/0.88/1.10 … troll 1.10/1.12/1.10
wp13_cv_fallback   unknown race -> human, exactly 1 warning; skin-only keeps its skin, no stature
wp13_cv_weapon     bare -> nil; passthrough; weapon_family at level 55 -> grug_gear:sword_b6
wp13_cv_result     PASS 0
wp13_order_graph   31 mods, 0 cyclic; grug_visuals 27 < grug_inventory 28
wp13_order_callbacks grug_visuals,grug_inventory_page
wp13_order_result  PASS 0
```

(`kat-luajit.txt` is the authority; the block above is a reading of it.)

## Engine boot

57 WARNING lines in the whole boot, every one of them pre-existing: the
`No craft recipe …` chatter of the vendored `default` items and the deprecated
mod-storage-backend notice. None from `grug_visuals`, `grug_mobs` or
`grug_traders`. Zero ERROR/ModError.

The probe spawned one of each humanoid and read back what the engine holds:

| Entity | Textures the server holds | Wield |
| --- | --- | --- |
| `grug_mobs:guard_accord` | `grug_visuals_skin_human.png` + the four metal overlays at `#d8cc9a` | `grug_gear:sword_b4` |
| `grug_mobs:guard_throng` | `grug_visuals_skin_orc.png` + the same four | `grug_gear:sword_b4` |
| `grug_mobs:bandit` | `grug_visuals_skin_human.png` + the four cloth overlays | `grug_gear:dagger_b4` |
| `grug_mobs:mirefolk` | `grug_mobs_mirefolk.png` | none |
| `grug_traders:vendor_general_accord` | `grug_visuals_skin_human.png` | none |
| `grug_traders:vendor_race_dwarf` | `grug_visuals_skin_dwarf.png` | none |

Bracket 4 is what the guard field gives at the probe position `(0, 80, 0)`; the
level-to-bracket mapping is `grug_gear.bracket_for_level`, so an elite guard at
60+ lands on bracket 6.

`pgrep -f '^luanti.bin'` was empty before the run and empty after it, and the
scratch directory was removed. The user's personal Luanti folder was never
touched.

## Not a regression, but worth reporting

`tools/wp40/r7/micro_kat_fixture.lua` does not run on this branch, and did not
before this increment either: its default `expected_changed_count` is 77 while
`tools/wp40/r7/changed_production_lua.txt` has 142 rows, and forcing the count
past that check fails inside
`mods/MAPGEN/grug_mapgen/wp40/r7_runtime.lua:144` (`roster` nil) — neither file
is touched here. That fixture executes `grug_mobs/init.lua` and
`grug_traders/vendors.lua` in stub environments; both additions in this
increment are registration-time table writes with no engine call, and the
vendor's `core.global_exists` sits inside `after_activate`, which that fixture
never invokes.

The existing WP13 fixtures (`library_kat`, `blueprint_kat`,
`integration_fixture`) were re-run and are unchanged.
