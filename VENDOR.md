# Vendored Third-Party Code

Policy (decided 2026-08-06): third-party mods are **vendored** (copied into
the repo), NOT git submodules. Rationale: a standalone Luanti game must
bundle everything it ships; we patch vendored code in place where needed
(submodules would force fork repos and non-atomic commits); upstream
coupling is kept through this file plus the read-only checkouts in
`reference_projects/` (git-ignored).

Rules:

1. Every vendored tree gets a row below: path, upstream, the upstream
   commit it was taken from, license, and a **complete list of local
   patches**.
2. Every in-place change to vendored code is marked with a
   `-- GRUG PATCH: <why>` comment at the change site.
3. Prefer wrapper mods (e.g. `grug_mobs` wraps `mobs`) over in-place edits —
   keep the patch surface minimal.
4. Updating a vendored tree = copy the new upstream version over, then
   re-apply the patches listed here (find them via the markers /
   `git log -- <path>`), then update the commit hash here.
5. Media files copied from other projects are NOT tracked here — they are
   documented per mod in `LICENSE-media.md` (see AGENTS.md "Licenses").
   Those per-mod tables carry the same provenance data as the rows below:
   upstream project, the **commit the assets were harvested at**, license,
   and any local modification (retint, rescale, rename).

| Path | Upstream | Vendored commit | License | Local patches |
|------|----------|-----------------|---------|---------------|
| `mods/ENTITIES/mobs` | [mobs_redo](https://codeberg.org/tenplus1/mobs_redo) | `646ba60` | MIT | `api.lua` `general_attack()`: `_grug_ignore_player` per-entity player-target veto hook (WP19 undead night truce, WP6 same-faction/factionless players — filtering during acquisition lets the mob pick the next-closest player). `api.lua` `do_states()` attack branch: soft de-aggro — walk speed instead of run speed beyond 25 m from the target (WP6, combat_stats §3; opt-out `_grug_soft_deaggro = false`). `api.lua` `item_drop()`: player-tag drop rule + profession drop hooks — one call-out to `grug_mobs._item_drop_filter` for mobs carrying `_grug_drop_rule`, all logic lives in `grug_mobs/aggro.lua` (WP6, combat_stats §3). **WP6-T10 pathfinding quality pass** (four patches, all in `api.lua`): (a) `path_height_blocked()` — nil guard on `core.registered_nodes[node]`, unknown/`ignore` (unloaded blocks) now counts as blocked instead of crashing the mob's step; (b) `apply_path()`/`smart_mobs()`/`do_states()` — `self.path.stuck` is now SET, not only read and reset (upstream dead code, same in the mcl_mobs fork): true only while the mob is wedged with NO usable path, cleared when a path is found, when line of sight returns and on both path-abandon exits; (c) `smart_mobs()` — `mob_pathfinding_stuck_path_timeout` is finally used (upstream read the setting and never referenced it): a mob already following a path gets that longer no-progress patience before the path is thrown away and re-planned, matching VoxeLibre `mcl_mobs/combat.lua:90-106`; (d) `do_states()` attack branch — `core.find_path` is no longer run for `attack_type == "dogshoot"` mobs, whose paths the consumption block right above already discards. Settings for all of this live in the game's `minetest.conf`. **WP6 review fixes** (four more `api.lua` sites): (e) `stop_attack()` + `do_attack()` + `do_states()` — `self.path.stuck` / `.following` / `.stuck_timer` are now reset on de-aggro, on a target CHANGE, and whenever the attack branch's already-computed `line_of_sight` comes back true. T10's patch (b) set the flag but every clear site it added is unreachable for a mob that is MOVING (`smart_mobs` zeroes `stuck_timer` above 0.5 m/s, so its timeout gate never opens), so one wedged moment became a permanent walk-speed crawl that also leaked across chases and target switches; (f) `do_states()` attack branch — the give-up distance is `self._grug_chase_range or self.view_range` instead of `view_range` outright (`_grug_chase_range = 45` is installed on every grug mob by `grug_mobs/aggro.lua`; vanilla mobs are untouched). Without it `dist` could never exceed the ≤ 16 m `view_range` of a ground mob, which made patch (b)'s own 25 m soft de-aggro dead code and made combat_stats §3/§4's chase model — chase persists, slows past 25 m, the 40 m/15 s leash resets — impossible; (g) `mob_activate()` — the `static_save = false` clear for untamed monsters now also requires `lifetimer < 20000`, the same predicate `mob_staticdata()` already used. `get_staticdata` is never called for an object with `static_save = false`, so the documented lifetimer exemption (named rares, `lifetimer = 30000`) could never be read and every rare was deleted on the first mapblock unload; (h) `path_height_blocked()` — `"ignore"` now counts as blocked too. It IS a registered node with `walkable = false` (builtin `register.lua`), so patch (a)'s nil guard let unloaded volume read as verified clearance; the comment there is corrected accordingly (unknown OR unloaded ⇒ blocked; only a removed mod's node ever caused the crash it claimed). Also wrapped by `grug_mobs`; `mobs:spawn_abm_check` is overridden there — a documented upstream extension hook, not a patch |
| `mods/BASE/default` | [minetest_game](https://github.com/luanti-org/minetest_game) `mods/default` | `b5243f3` | LGPL-2.1+ / media CC BY-SA | `mapgen.lua` tail: biome/ore/decoration registration for biome-based mapgens disabled — grug_mapgen owns them (WP2) |
| `mods/BASE/creative` | minetest_game `mods/creative` | `b5243f3` | LGPL-2.1+ | none |
| `mods/BASE/sfinv` | minetest_game `mods/sfinv` | `b5243f3` | LGPL-2.1+ | none |
| `mods/BASE/stairs` | minetest_game `mods/stairs` | `b5243f3` | LGPL-2.1+ | none |
| `mods/BASE/player_api` | minetest_game `mods/player_api` | `b5243f3` | LGPL-2.1+ | none |
