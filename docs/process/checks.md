# Which check to run after which change

The one table of topic checks: when a lane changes the thing in the first
column, it runs the checks in the second, from the repository root. The
gates every lane and every round end run (`check_lua.sh`, the fresh-server
check, the upgrade check, the fixture rule, the seed fleet, the smoke boot)
are in the [round workflow §3](round-workflow.md#3-gates); the fixture folders
per round in [tools/README.md](../../tools/README.md). A fixture named here
runs through `tools/run_fixtures.sh <folder>` under the fixture rule of the
round workflow (only the strictly needed ones). Commands marked "through the
queue" run LuaJIT for a while and go through the shared Lua queue
(`~/projects/grudgelands-orchestration/r45/lua_run.sh`).

| Changed | Run |
|---|---|
| Any Lua file (Lua under `tools/` too) | `bash tools/check_lua.sh <files>` |
| UI theme textures or their generator | `python3 tools/ui_theme/build.py --check` |
| A zone's spawn recipe | `tools/r28_regions/run.sh <zones>` and `tools/r28_world/run.sh` (border rule `tools/r28_world/border_rule.py`); show the images when the user decides a distribution |
| Design data: quests, mobs, the item catalogue | `python3 tools/r28_design/validate.py --game` (also a round-end gate) |
| The design files under `docs/planning/round28/` | `python3 tools/r28_design/validate.py` |
| Mob names (`grug_mobs/data/names.json`) | `python3 tools/r38_b1/gen_names.py --check` (the builder; `--proposals FILE...` adds the name proposals); `python3 tools/r38_names/check_rules.py --shipped` (the naming rules); `python3 tools/r38_names/guarantee.py --check` (every quest kill target is a shown name) |
| Loot, repair, quest copper or a price | `python3 tools/r29_e4/income.py --check` (mount, boat and respec prices, the crown fee; also a round-end gate) |
| Quest files | `python3 tools/r28_design/validate.py --game`; `python3 tools/r28_regions/quest_targets.py` (region stats of three seeds); `python3 tools/r28_design/ledger.py --track <race>`; `python3 tools/r28_regions/quest_kinds.py --check`; for the reworked bands and the capitals `python3 tools/<dir>/build_structure.py --check` with `<dir>` = `r59_bandquests`, `r59_storyquests`, `r60_bandquests`, `r60_capitals`, `r61_bandquests`, `r62_frontquests` (structure only; without `--check` it writes placeholder texts back); the guild quests' `python3 tools/r58_guildquests/build_structure.py --check --ids` (ids and hubs only; without `--ids` it is no gate, and a run without `--check` writes the placeholders back); the fixtures `r59_qsys3`, `r59_bandquests`, `r59_storyquests`, `r60_bandquests`, `r60_capitals`, `r61_bandquests`, `r62_frontquests`, and `r36_qa`, `r36_qt` (the main line's spine) |
| A quest overview page for the user | `luajit tools/r56_questmap/questmap.lua --out FILE` (`--data DIR` reads a draft's `DIR/data/zones`) |
| Shipped quest art | `python3 tools/r59_storyart/paint_art.py --check`, `python3 tools/r60_storyart/paint_art.py --check`, `python3 tools/r61_storyart/paint_art.py --check` (byte for byte) |
| The Miner's Guild catalogue or spec | `luajit tools/r58_guildspec/write_doc.lua . --check` (the spec's generated tables) |
| The Miner's Guild's shipped art | `python3 tools/r58_consume/art/ship.py --check` (drop 01: icons, status icons, Remains overlay); `python3 tools/r58_lift/art/ship.py --check` (drop 02: lift faces, reputation icon, map markers) |
| The Miner's Guild houses | `python3 tools/r58_halls/make_halls.py --check` (edit the script, never the six `<capital>_miners_guild.tpl` files) |
| An Expedition template or its source | `python3 tools/expedition_templates/build.py --check` (it also rebuilds the walk grid), the template's fixture with the shared proof `tools/expedition_templates/proofs.lua`, and the fixture `r74_nav`; `tools/expedition_templates/preview.py` draws the rooms for the user |
| The combat path | the PvE micro run `tools/r31_pvp/run.sh`, before and after |
| Character look art | regenerate with `tools/wp13/gen_character_visuals.py` (no check mode); enchant masks of weapons, bows and the old shared spellbook image: `python3 tools/r31_b/gen_enchant_masks.py --check` |
| Armor art, catalog or models | in `tools/r54_armor/`: `export.py --check` (also every polygon part's schema file, the hood's `hood.json`), `atlas.py --check`, `zfight.py`, `check.py --art tools/r54_art/art`, `bake.py --icons-out mods/ITEMS/grug_gear/textures --check`; `python3 tools/r54_art/assemble.py --check` and `ghosts.py --check`; `python3 tools/r33_c3/gen_cloak_model.py --check`; `python3 tools/r40_an/make_poses.py --check`; the fixture `r56_hood` |
| Account reward art (donor cloaks) or the emote icons | `python3 tools/r80_art/assemble.py --check` (the donor cloaks and their wings, pixels); `python3 tools/r80_emote/icons.py --check` (the quickbar's emote icons, renders of the player model: rerun after a model change) |
| Offhand art, params or models | `python3 tools/r55_offhand/offhand.py --check`, `bake.py --icons-out mods/ITEMS/grug_gear/textures --check`, `test_bake.py` and `test_render.py` there; `python3 tools/r55_art/assemble.py --check`; `python3 tools/r33_c3/gen_cloak_model.py --check`; `tools/r55_model/test_frames.py`; the web model checks (next rows); on a dev machine `tools/r55_offhand/templates.py --check` (it depends on Pillow's default font) |
| The player or NPC model, a cloak, its bones or animations | `python3 tools/r33_c3/gen_cloak_model.py --check`; `python3 tools/web_data/model/build_glb.py --check` and `check_glb.py` |
| Items, factions, classes, races or textures the website reads | `tools/web_data/export.lua --check` (regenerates `tools/web_data/web_data.json`; [tools/web_data/README.md](../../tools/web_data/README.md)) |
| The ridden bats' models | `python3 tools/r451_mc/gen_bat_ride_mesh.py --check` (also a round-end gate) |
| Item numbers or their generator | `python3 tools/r33_ds/build_doc.py --check` (the generated tables of `item_tiers.md`; change data or the script, never a generated table) |
| A recipe | `tools/r57_chains/run.sh OUT_DIR` (one boot through the queue; the depth per recipe) |
| Bag sizes | the fixtures `r48_bags` (it runs the 0.48.0 step under its own sizes), `r44_ih`, `r33_c1`; `tools/r62_bags/capture.sh` shows the Inventory page with four 20-slot bags (one boot) |
| The gathering catalogue (herbs) | the fixture `r60_herbs` (`luajit tools/r60_herbs/portable_test.lua . --table` prints the reach and the mob-loot gaps) |
| Building templates, layouts, rosters, palettes or their loader (`wp13/templates.lua`) | `python3 tools/building_templates/check.py` (the hard gate; it runs the game's loader and builds every town and capital; also a round-end gate; it warns about 11 unreachable points, checker false positives that `tools/r62_templatefix` walks in the built towns, and the known-defects list is empty) and `check.py --self-test`; `python3 tools/building_templates/viewer/test_templates.py` (the viewer's reader); `python3 tools/r56_editor/test_editor.py` (the editor; LuaJIT inside, about 1.5 minutes, through the queue); `python3 tools/check_upgrade.py` (a template change needs a declared map reset). `building_templates/export.py --check` is retired and prints RETIRED |
| Decor rows or a composition's bounds | the fixture `r36_w` (every composition against `baseline.tsv`) |
| World generation: terrain, placement, footprints, the world writer | the seed fleet `tools/seed_fleet/run.sh quick` ([round workflow §3](round-workflow.md#3-gates)); a change that only places, swaps or turns nodes needs no run |
| `tools/migrate.py` or `tools/migration/` | the test of every declared step in the `debian:trixie` container and the unit tests, `tools/r43_mt/container_test.sh` ([round workflow §3](round-workflow.md#3-gates)) |
