# DT2 — Technical documents other than the module guide, against the code

- Finder model: claude-opus-5-5
- Files read in full: 12 of 12 documents (`upgrade-contract.md`, `upgrade-contract-history.md`, `web-bridge.md`, `web-accounts.md`, `luanti-lua.md`, `ui-presentation.md`, `upstream-workarounds.md`, `armor-format.md`, `offhand-format.md`, `building-template-format.md`, `expedition-template-format.md`, `README.md`); code read in full: `grug_core/world_version.lua`, `map_reset.lua`, `migrations.lua` (handlers skimmed), `ui.lua`, `grug_bridge/*` (5 files), `grug_accounts/init.lua`, `model.lua`, `flow.lua`, `tools/check_lua.sh`, `tools/web_data/upgrade.json`, `game.conf`; skimmed: `grug_accounts/page.lua`, `ui_window.lua`, `ui_rows.lua`, `wp13/templates.lua`, `grug_expeditions/template.lua`, the armor/offhand data JSON, the steps directory (listed, not read); not reached: `tools/migration/*.py` contents (only existence and the requirements file), the PNG alpha values `ui-presentation.md` states (no image tool allowed)
- Summary: The technical documents are in good shape against the code. The two fixed contracts with the hosting platform (`web-bridge.md`, `web-accounts.md`) match `grug_bridge` and `grug_accounts` in every field, limit, code and order checked; neither side is wrong. The upgrade contract matches the guard, the runner, the map reset and the declaration beyond what X5-01/X5-06 already report; its history additionally skips the map resets 0.49.0 and 0.63.0 inside its own range (DT2-01). `luanti-lua.md` carries three engine facts that went stale with the 5.18.0 checkout (the removed `secure.enable_security`, the LuaJIT age check now fatal, the send distance default 13) and overstates what `check_lua.sh` enforces (DT2-02 to DT2-04, DT2-07). `upstream-workarounds.md`'s entries all still exist at the named places; it misses one caller and one engine-driven fix (`door_click.lua`) and keeps a stale sentence about direct `find_path` callers (DT2-05, DT2-06). No dead link or anchor.

## Findings

### DT2-01 | Low | docs | The declared-releases history skips the map resets 0.49.0 and 0.63.0 inside its own range

- **Where:** `docs/technical/upgrade-contract-history.md:3-5` (claims "why each release from 0.41.0 to 0.70.0 declared its map reset, step or neither"), `:30-38` (0.50.0 and 0.51.0 entries), `:123-130` (0.67.0 follows 0.62.0); `tools/web_data/upgrade.json` (`map_reset` holds `0.49.0` and `0.63.0`)
- **What:** The history numbers the map resets ("the sixth" for 0.51.0, "the thirteenth" for 0.70.0), and the count matches the declaration, but two of them have no entry: 0.49.0 (the fifth; only mentioned in passing in the 0.50.0 entry) and 0.63.0 (the twelfth; not mentioned at all). A reviewer who checks why 0.63.0 declared a reset finds nothing. This is inside the 0.41.0–0.70.0 range, so it is separate from X5-06 (the history stops at 0.70.0).
- **Evidence:** `rg -n "0\.63\.0|0\.49\.0" docs/technical/upgrade-contract-history.md` finds only `:33` ("across 0.49.0's map reset"). `CHANGELOG.md:731-735` "## 0.63.0 — fortified mining outposts ... **Map reset** needed: all 36 completed mining camps use new templates"; `CHANGELOG.md:1618` 0.49.0 (map reset, no step).
- **Proposal:** Add the two entries (0.49.0: native ores and faster generation; 0.63.0: the 36 mining camps' new templates and the banners), with the same "no step, `map_reset_pass` stays 0.50.0" closing as their neighbours. Doc side is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT2-02 | Low | docs | luanti-lua.md: `secure.enable_security` no longer exists in 5.18.0

- **Where:** `docs/technical/luanti-lua.md:206-208`
- **What:** The section is headed "Sandbox (`secure.enable_security`, default true)" and cites `builtin/settingtypes.txt:1936-1939` for the default. In the 5.18.0 checkout the setting is gone from `builtin/settingtypes.txt` (only `secure.trusted_mods` at `:1937` and `secure.http_mods` at `:1941` remain); the engine ignores the old key with a warning and the sandbox can only be switched off by the `--insecure-no-sandbox` command-line flag. The rules the doc draws (we always run sandboxed) stay right; the stated mechanism is stale.
- **Evidence:** `reference_projects/luanti/src/script/scripting_server.cpp:52-60` (`std::string old_name("secure.enable_security"); ... "was removed and is now ignored. Use the --insecure-no-sandbox CLI flag ..."`); `rg -n enable_security reference_projects/luanti/builtin/settingtypes.txt` finds nothing.
- **Proposal:** Retitle to "Sandbox (always on; `--insecure-no-sandbox` disables it)" and cite `scripting_server.cpp`. Doc side is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT2-03 | Low | docs | luanti-lua.md: an old LuaJIT is a configure error in 5.18.0, and system PUC Lua is never searched rather than "rejected"

- **Where:** `docs/technical/luanti-lua.md:67-73`
- **What:** The doc says "LuaJIT: anything older than ~March 2021 only warns (`src/CMakeLists.txt:890-906`)" and that "system-wide PUC Lua is rejected at configure time for that reason (`src/CMakeLists.txt:908-921`)". In 5.18.0 an old LuaJIT stops the configure with `FATAL_ERROR`, and nothing rejects a system PUC Lua: `FindLua.cmake` simply never looks for one and falls back to the bundled `lib/lua`. The practical rule (write plain 5.1) is unaffected.
- **Evidence:** `reference_projects/luanti/src/CMakeLists.txt:900-919` (`check_symbol_exists(luaopen_string_buffer ...)`, `message(FATAL_ERROR "You are using a LuaJIT version older than March 2021 ...")`); `cmake/Modules/FindLua.cmake:10-27` (`find_package(LuaJIT)`, else `"LuaJIT not found, using bundled Lua."`).
- **Proposal:** "An older LuaJIT is a configure error (`src/CMakeLists.txt` `HAVE_RECENT_LJ`); without LuaJIT the build always uses the bundled PUC 5.1.5 (`FindLua.cmake`)". Doc side is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT2-04 | Low | docs | luanti-lua.md: `max_block_send_distance` defaults to 13, not 12

- **Where:** `docs/technical/luanti-lua.md:374-375`
- **What:** The "block send front" trap gives the send distance as "`max_block_send_distance` (12)". The 5.18.0 default is 13. The reasoning ("a generate distance below the send distance minus 2 freezes loading") then sits right at the boundary with the default generate distance 10 (13 − 2 = 11 > 10), so the number matters; the game's `minetest.conf` sets neither key.
- **Evidence:** `reference_projects/luanti/src/defaultsettings.cpp:476` `settings->setDefault("max_block_send_distance", "13");`, `builtin/settingtypes.txt:2324` `int 13 1 65535`; `:537` generate distance `"10"`; `rg -n "max_block|block_send" minetest.conf` finds nothing.
- **Proposal:** Re-check the paragraph against 5.18.0's `clientiface.cpp` (`getNextBlocks`) and correct the number; if the "minus 2" rule holds, say whether the default pair 10/13 is affected. Doc side is wrong (stale against the bumped checkout).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** medium (the default is certain; whether the freeze claim applies at 10/13 was not traced)

### DT2-05 | Low | docs | upstream-workarounds §1 misses a caller of the raycast workaround, and the door-before-NPC fix is listed nowhere

- **Where:** `docs/technical/upstream-workarounds.md:57-62` (the callers), `:89-97` (what to remove), `:320-369` ("Checked and not listed"); `mods/ENTITIES/grug_mobs/door_click.lua:1-30,41`
- **What:** §1 says "Every server-side aiming ray uses it" and lists four users of `grug_core.aim_raycast`; there is a fifth, the door-before-NPC click (`door_click.lua:41`, since 0.49.1). The removal recipe ("put `core.raycast` back at its call sites") would miss it. Separately, `door_click.lua` exists only because of an engine behaviour (the raycast's `RaycastSort` counts an object one node² nearer than a node, `src/raycast.cpp` "Ease selection of entities behind nodes") and is neither an entry nor in "Checked and not listed", although the list exists to catch exactly such engine-driven code. The doc side is incomplete; the code is fine.
- **Evidence:** `rg -n "aim_raycast" mods` → `grug_abilities/init.lua:759`, `grug_abilities/input.lua:83`, `grug_mobs/target_frame.lua:162`, `grug_mobs/door_click.lua:41` (plus `combat_ray.lua` itself); `door_click.lua:4-9` ("THE CAUSE is the engine's pointing, not our code ... RaycastSort ... upstream since 2018").
- **Proposal:** Add `door_click.lua` to §1's caller list and its removal step; add a "Checked and not listed" line for the door click (engine design, not a bug; nothing to remove).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT2-06 | Low | docs | upstream-workarounds §5 still describes direct `find_path` callers that no longer exist

- **Where:** `docs/technical/upstream-workarounds.md:207-209`
- **What:** "The other callers search far above it (`grug_mobs/patrol.lua` 24, `grug_mobs/rift.lua` 40; Round 42 NV2 moves them onto the module)." The move has happened: the game calls `core.find_path` in exactly one place, `nav.search`, and patrol and rift steer through the navigation module (`nav.fixed_step`, `nav.steer`). The sentence now reads as if two unguarded callers remained, which matters for a reviewer deciding whether the floor of 2 covers every search.
- **Evidence:** `rg -n "find_path\(" mods -g '!mods/BASE/**'` → only `mods/ENTITIES/mobs/grug_nav.lua:576`; `grug_mobs/patrol.lua:192` `nav.fixed_step(...)`, `grug_mobs/rift.lua:64` `nav.steer(self)`.
- **Proposal:** Replace the sentence with "Every search goes through `nav.search` (the only `core.find_path` call in the game), so the floor covers all of them."
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DT2-07 | Low | docs | luanti-lua.md: the do-not-write list and the gate disagree on what is enforced

- **Where:** `docs/technical/luanti-lua.md:311-353` (the list), `:408-410` ("expect exactly one line, the mod table"), `:451-461`, `:470-474` ("This is the whole plain-5.1 gate"); `tools/check_lua.sh:14,67-73`
- **What:** The doc presents `check_lua.sh` as the plain-5.1 gate, but several list items are not swept and one check never fails: (a) item 3's `__len` and `__pairs` are in no sweep (sweep 3 covers `table.unpack/pack/move`, `rawlen`, `coroutine.isyieldable`, `math.type/tointeger`, `utf8.`); (b) item 6's "no bytecode loading" has no sweep (the sandbox refuses it at run time, so this one is harmless); (c) item 9 (one global per mod) is only the `SETGLOBAL` listing, which the script prints and never fails on (`rg SETGLOBAL || test "$?" -eq 1`), so "expect exactly one line" is a manual reading, not a gate. Items 7, 8, 10, 11, 14, 15 are review-only, which the doc does not claim otherwise. A reader of `:470-474` may believe items 3 and 9 are machine-checked. Today's tree has no `__len`/`__pairs` in our mods (`rg` finds none), so nothing slipped through.
- **Evidence:** `tools/check_lua.sh:67-73` (the five patterns), `:14` (the listing); `rg -n "__len|__pairs" mods/*/grug_*` → no hit.
- **Proposal:** Mark in the list which items the gate checks (1, 2, 3 except `__len`/`__pairs`, 4, 5, 6 except bytecode, 12, 13 under `mods/MAPGEN`) and which are review-only; either add `__len|__pairs` to sweep 3 or say it is review-only; say that the `SETGLOBAL` listing is read by hand. Docs or script; the doc is the cheaper side.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

## Backlog notes

- `docs/technical/luanti-lua.md` cites many engine lines from 5.17.0-dev that drifted in 5.18.0 (the doc says so at `:5-7`): `s_base.cpp:105-110` → `lua_atccall` now at `:137`; `:80-84` (bitop) → `:107`; `:87` (lstrpack) → `:112`; `s_security.cpp:1024-1028` (`require`) → `sl_g_require` at `:1073-1077`; `:657-666` (bytecode) → `:698-699`. Substance verified unchanged; refresh when the file is next touched.
- `docs/technical/upstream-workarounds.md:296` `servermap.cpp:254` (`initBlockMake`) is at `:200` in 5.18.0, `map.h:335` (`blitBackAll`) at `:337`; `:314` `l_env.cpp:1159` at `:1158`. Substance unchanged.
- `mods/ENTITIES/mobs/grug_nav.lua:91-92` still says "The box is exclusive on its positive edge" — the doc (`upstream-workarounds.md:214-217`) already notes this belongs to 5.17; the code comment could say so too.
- `docs/technical/web-bridge.md:81` calls `boot` "random"; the code makes it `core.sha1(os.time() .. ":" .. core.get_us_time()):sub(1, 16)` (`grug_bridge/init.lua:92`): unique per start, not random. Harmless for its purpose (a restart marker).
- `docs/technical/web-accounts.md:317-318` "The game compares names ignoring case" holds for the list (`model.lua:178,201`), but `flow.lua:251` compares `link_answer`'s `name` with the request's exactly (`name ~= args.name` → `invalid_args`). Only a website that re-cases the name from the event would hit it; §5.4 says to send "the character's name from the event".
- `mods/ITEMS/grug_gear/textures/grug_gear_spellbook_ench.png` is the mask of a texture that no longer exists (spellbook icons are per tier since Round 55, `offhand-format.md` §7); `rg "grug_gear_spellbook_ench|grug_gear_spellbook\.png" mods` finds no user. Dead file (not a docs item; for the dead-code lane).
- `docs/technical/building-template-format.md:243` / `:56-89`: the examples use `x=-5 y=0 z=-26` and `doors 5 1 0 face=2` for `hearthpine_forge_hall`; the shipped layout has `z=-30` (`layouts/hearthpine.layout`). Marked as "an abbreviated example", so not a finding.

## Good to know

**Statements checked per document** (each a concrete name, number, rule, path or engine claim compared with code or data):

| Document | Checked | Findings |
|---|---|---|
| `upgrade-contract.md` | ~45: setting and records (§3.1 against `map_reset.lua`, `settingtypes.txt:160`), the clears and keep-list of §3.2 (`grug_mobs/map_reset.lua`, `starts_preload.lua`, rift keys), the player part and waiting point (`selection.lua:160,178,448-477,578`), the record, guard texts, new-world rule and marker order (`world_version.lua` in full, `migrations.lua` in full), the step registry vs `upgrade.json`, every step file and test path named in §5.7, the engine claims of §3.5/§5.4 (`SER_FMT_VER_HIGHEST_WRITE = 29`, `mod_storage.lua`, `Server::~Server` committing mod storage via `endSave`) | none beyond X5-01/X5-06 |
| `upgrade-contract-history.md` | ~15: the reset ordinals against the declaration | DT2-01 |
| `web-bridge.md` | ~40: every constant (`link.lua:9-25`), the exchange order (banlist → accounts → resync → commands, `link.lua:258-274`), every command's limits and codes (`commands.lua` in full), bans (`bans.lua`), mirror events (`mirror.lua`), chat hook vs engine `shout` order (`server.cpp:3322,3330`), `kick_player` text (`builtin/game/misc.lua:8-15`) | none (code and contract agree) |
| `web-accounts.md` | ~35: id formats (`model.lua:83-99`), list rules (`model.lua:148-192,232-264`), index states and adoption (`:285-334`), code alphabet, length, attempt limit, timeouts, state table and refusal reasons (`flow.lua` in full), `set_password` checks and entry rule (`commands.lua:311-345`), notices, the catalogue (7 cloaks + `emote:cheer`) | none |
| `luanti-lua.md` | ~40 engine claims sampled (`builtin/init.lua`, `misc_helpers.lua`, `math.lua`, `serialize.lua`, `strict.lua`, `vector.lua`, `register.lua`, `s_security.cpp` whitelists, `FindLua.cmake`, `src/CMakeLists.txt`, `defaultsettings.cpp`, `scripting_server.cpp`) plus the six sweeps | DT2-02, DT2-03, DT2-04, DT2-07 |
| `ui-presentation.md` | ~25: every helper's signature and output (`ui.lua` in full, `ui_window.lua:1-70`), the 21 theme images, padding insets, inventory body and header sizes (`grug_inventory/ui.lua:13`, `navigation.lua:4-5,42`), map share 0.62 and 90 %, the named seams in `grug_map`, `grug_jobs`, `grug_mail`, the fixtures | none |
| `upstream-workarounds.md` | ~30: each entry's code site (combat_ray's 13 named locals, emerge pin and manifest, both epsilons, `MIN_PADDING`, the forced focus, `RESYNC_FIRST/LAST`, the read-back, `BLOCKS_PER_STEP`, `ENGINE_HP_MAX`), the 5.18.0 engine symbols, and a `rg` for workaround/engine-bug/upstream/FIXME wording | DT2-05, DT2-06 |
| `armor-format.md` | ~20 against `tools/r54_armor/data/catalog.json`, `atlas.json`, `palettes.json` and `grug_visuals/compose.lua`: 17 shapes / 28 boxes, every row of the box table (slot, bone, mirror, rotation, sheet), 704/896 vertices, hood at (0, 42) 64 × 12, 13 reference colours and 18 palettes (247 colour entries), 72 + 54 baked layers with 126 masks, file stems | none |
| `offhand-format.md` | ~12: setting default, back-card `[combine` strings, file names (6 grades × shield/book + icons + masks), atlas 64 × 64, slot orders | none |
| `building-template-format.md` | ~15: paths of §1, the three magic lines and header keywords in `wp13/templates.lua`, legend options (`variant`, `channel`, `o`, `else`, `late`), layout/roster keys, `BASELINE` present, `known_defects.txt` empty as stated | none |
| `expedition-template-format.md` | ~20: magic, size rule and box 128 × 64 × 128, particle styles and budget 300, critter roster, ambush rules and `AMBUSH_ABOVE = 3`, grid section parsing, door reach 8, every helper file named | none |
| `README.md` | ~10: each research record exists and is cited where the table says | none |

- **Links and anchors:** all 52 relative link targets in the 12 documents exist, and all 10 `#anchor` links resolve to a heading (checked by `rg` on the target headings). No dead link was found.
- **Engine checkout:** `reference_projects/luanti` is checked out at `e8f12bf` (5.18.0), so engine claims were read, not guessed. It also settles X5's open point: `Server::~Server` saves the players (`saveLoadedPlayers`) before it kicks them, and commits mod storage (`endSave`) after the environment is gone (`src/server.cpp:383-430`).
- The two hosting-platform contracts (`web-bridge.md`, `web-accounts.md`) match the code exactly in every field, limit and code checked; no side is wrong.
- `docs/README.md` (outside this package) indexes upgrade contract, web bridge/accounts, Lua rules, upstream workarounds, UI toolkit and building templates, but not `armor-format.md`, `offhand-format.md` or `expedition-template-format.md`.
