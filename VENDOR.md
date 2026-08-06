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
| `mods/ENTITIES/mobs` | [mobs_redo](https://codeberg.org/tenplus1/mobs_redo) | `646ba60` | MIT | `api.lua` `general_attack()`: `_grug_ignore_player` per-entity player-target veto hook (WP19 undead night truce, WP6 same-faction/factionless players — filtering during acquisition lets the mob pick the next-closest player). `api.lua` `do_states()` attack branch: soft de-aggro — walk speed instead of run speed beyond 25 m from the target (WP6, combat_stats §3; opt-out `_grug_soft_deaggro = false`). `api.lua` `item_drop()`: player-tag drop rule + profession drop hooks — one call-out to `grug_mobs._item_drop_filter` for mobs carrying `_grug_drop_rule`, all logic lives in `grug_mobs/aggro.lua` (WP6, combat_stats §3). Also wrapped by `grug_mobs`; `mobs:spawn_abm_check` is overridden there — a documented upstream extension hook, not a patch |
| `mods/BASE/default` | [minetest_game](https://github.com/luanti-org/minetest_game) `mods/default` | `b5243f3` | LGPL-2.1+ / media CC BY-SA | `mapgen.lua` tail: biome/ore/decoration registration for biome-based mapgens disabled — grug_mapgen owns them (WP2) |
| `mods/BASE/creative` | minetest_game `mods/creative` | `b5243f3` | LGPL-2.1+ | none |
| `mods/BASE/sfinv` | minetest_game `mods/sfinv` | `b5243f3` | LGPL-2.1+ | none |
| `mods/BASE/stairs` | minetest_game `mods/stairs` | `b5243f3` | LGPL-2.1+ | none |
| `mods/BASE/player_api` | minetest_game `mods/player_api` | `b5243f3` | LGPL-2.1+ | none |
