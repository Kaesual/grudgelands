# Vendored Third-Party Code

Policy (decided 2026-08-06): third-party mods are **vendored** (copied into
the repo), NOT git submodules. Rationale: a standalone Luanti game must
bundle everything it ships; we patch vendored code in place where needed
(submodules would force fork repos and non-atomic commits); upstream
coupling is kept through this file plus the nine read-only checkouts in
`reference_projects/`, pinned as git submodules and never shipped as part of
the game.

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

Media in the seven building-material mods vendored on 2026-09-14 (`doors`,
`xpanes`, `beds`, `wool`, `dye`, `vessels`, `walls`) is licensed **per that
mod's own `license.txt`**, which is vendored unchanged and carries the
complete per-file provenance (CC BY-SA 3.0 / CC BY-SA 4.0 / CC BY 3.0 /
CC0 1.0 as listed there). Two upstream files are deliberately NOT vendored:
`doors/models/door.blend` (426 KiB Blender editing source, never loaded at
runtime) and `vessels/textures/vessels_steel_bottle.png` (the node it
belonged to is removed). No vendored media file is modified, so no
`LICENSE-media.md` row is needed for them.

WP38 review note for the `mobs_redo` row below: its historical `(k)` wording
names the former combined `melee_crit` helper. The current patch resolves the
same multiplier through pure `roll_melee_crit`, snapshots the target position,
and emits the one crit burst only at `(r)` after both `do_punch` and CMI accept.
The 2026-08-10 held-soft-target runtime correction adds marker `(s)`: native
swing-item combat packets call the Core acquisition/input seam and return
before mobs_redo damage or side effects; only a server-owned full swing whose
opaque token matches the exact attacker/target and is claimed once continues
through `(p)`/`(q)`. The combat marker inventory remains 32; the fresh-server
cleanup below adds seven sites, WP13 playtest round 2 (2026-09-15) adds the
40th (a per-TARGET non-combatant veto in `general_attack()`'s candidate
filter), and the mob-pressure round (2026-09-16) adds the 41st to 43rd, the
attack-cadence patch of the section below.

## WP13 playtest round 2 — the non-combatant veto (2026-09-15)

One new marker, in `general_attack()` beside the existing `_grug_ignore_player`
hook: a candidate whose luaentity carries `_grug_noncombatant` is dropped before
any distance or line-of-sight work. `attack_npcs` cannot express this — it is
one boolean over the whole `type = "npc"` family, and that family holds both the
guards a hostile MAY fight (the user's ruling) and the villagers, elders and
vendors it may never touch (they cancel every punch, so such a fight can never
end). The flag is installed at activation by `grug_mobs.noncombatant`
(`grug_mobs/verbs.lua`), because mobs_redo copies only its own def whitelist
onto an entity. Filtering here rather than with a `stop_attack` wrapper is what
lets the mob pick the next-closest viable target instead of re-acquiring the
vetoed one for ever — the same reason the player hook sits at this site.
**40 markers in `mobs/api.lua`.**

## Mob pressure — the attack cadence (2026-09-16)

Three new markers, all in `do_states()`'s dogfight branch, and together they
are one change: `combat_stats.md` §4's "Catching up must be enough to hit"
(decided 2026-08-13, restated as user ruling 1 on 2026-09-16), which upstream
mobs_redo contradicts in two lines that sit one apart.

- **The cadence advances during the chase.** `punch_timer` now accumulates at
  the top of the branch, above the `dist > reach` test, on every tick with a
  live target — upstream advanced it only inside the in-reach branch. The
  backlog is capped at one `punch_interval`, the same rule the player's own
  swing clock follows, so a ten-second chase lands one hit on arrival rather
  than ten.
- **The in-reach branch no longer freezes the mob.** Upstream's unconditional
  `set_velocity(0)` is replaced by a run down to a contact distance of
  `reach × 0.6`: a target that stands still is reached and the mob stops (its
  punch rate is unchanged, which is the control the decided text demands),
  while a target that recedes keeps the mob moving and therefore in reach.
  Deliberately a fixed distance and not a per-tick distance derivative, which
  would oscillate once per server step against a target only marginally
  slower than the mob.
- **The punch moved out of the branch.** It now sits after both branches and
  carries the in-reach and line-of-sight tests at the site of the punch; a
  cadence that comes due out of reach is not reset, so the hit lands on the
  first tick reach is regained. Everything from the timer reset down is
  upstream's own body, moved verbatim — `custom_attack` still consumes the
  cadence whether or not it continues, and a blocked line of sight still
  costs the swing.

`reach` itself is untouched: raising it cannot repair the defect (a stopped
mob always leaves its own radius), it would widen the elite/rare telegraph
cone of `reach + 1.5` and it would make `dogshoot` mobs switch to melee
earlier. Measured on a headless server (`tools/wp11/run_cadence_probe.sh`):
punches per 10 s against a target receding at walk speed 4.0 go from **1 to
10**, and against a standing target stay at **10**.
**43 markers in `mobs/api.lua`.**

## Fresh-server cleanup — 2026-09-13

The standing development mode in `AGENTS.md` removes support for earlier world
and entity formats. Reapply these local patches after an upstream update:

- **default:** delete `aliases.lua` and `legacy.lua` and their `init.lua`
  loaders; remove the old book empty-key metadata reader in `craftitems.lua`,
  chest-format upgrade LBMs in `chests.lua`, sapling ABM-to-timer LBM in
  `trees.lua`, and torch conversion LBM in `torch.lua`. Remove engine legacy
  mineral/facedir/wallmounted conversion flags in `nodes.lua`, `chests.lua`
  and `furnace.lua`. Keep current mapgen aliases, sapling growth timers and
  the normal opened-chest close-on-load behavior.
- **stairs:** remove old pine-name aliases, the upside-down placeholder
  registrations, the replacement setting and its conversion ABM.
- **player_api:** remove the obsolete wrappers around the four initialized-player
  APIs. Current join initialization and animation/appearance APIs remain.
- **creative:** remove the unused `creative.is_enabled_for` API shim.
- **mobs_redo:** delete `compatibility.lua`, its loader and registration-time
  check; remove legacy `drawtype`, old `nametag` adoption, flat texture-list
  adaptation, plural `attacks_monsters` spelling, and `alias_mob` entity conversion
  in `api.lua`. Remove the old magic-lasso alias in `crafts.lua`; its current
  admin reset tool preserves `_nametag` across reset and normal save/reload.
  Remove the corresponding `alias_mob` entry from `api.txt`. `mount.lua` retains `do_mount_action` and
  drops the obsolete arrow path and its two arguments to `mobs.fly` (no
  shipped callers). Current mob definitions use nested texture lists and
  boolean `floats`; Crocodile, Kraken and vendors are normalized accordingly.
  Same-version staticdata serialization, activation and spawning remain.

### Building-material mods — 2026-09-14

The seven mods vendored for the settlement builders (`doors`, `xpanes`,
`beds`, `wool`, `dye`, `vessels`, `walls`) came from the same pinned
`b5243f3` checkout and were cleaned to the same standing rule:

- **doors:** remove the `doors_owner` node-meta reader
  (`replace_old_owner_information`) and its four call sites, the per-door
  `:doors:replace_<name>` LBM that converted the old `<name>_b_1`/`_b_2`
  two-node door format, and the deprecated `doors.register_door()` API shim
  (including its `only_placer_can_open` translation and fallback tiledef).
  Keep open/close, the `doors.register`/`doors.register_trapdoor` API, the
  `core.is_protected` / `default.can_interact_with_node` checks, the locked
  door key hooks (kept for the same reason `default/chests.lua` keeps them)
  and the five wooden fence gates.
- **xpanes:** remove the 15 numbered old-name aliases registered per pane
  (`xpanes:<name>_1` … `_15`) and the one-shot `xpanes:gen2` LBM that
  re-derived their connection state. Keep `xpanes.register_pane`, the
  `register_on_placenode`/`register_on_dignode` updaters and pane
  connection.
- **beds:** delete `functions.lua` and `spawns.lua` and their `init.lua`
  loaders; remove `beds.on_rightclick`, `beds.can_dig`, the spawn/kick
  bookkeeping in `destruct_bed`, the `on_rotate` screwdriver hook, the two
  PilzAdam old-name aliases and the `<name>` → `<name>_bottom` alias (the
  recipe names the real node instead). Keep placement of both facedir
  halves, paired destruction, digging and the recipes.
- **wool:** remove the two jordach 16-colour aliases (`wool:dark_blue`,
  `wool:gold`).
- **walls:** remove the single-texture-string fallback in `walls.register`
  for callers written against the pre-table API.

Removed files (`beds/functions.lua`, `beds/spawns.lua`) are listed here
because they cannot retain in-file markers. Every other removal carries a
`-- GRUG PATCH` marker at its site.

Beyond the fresh-server rule these mods also drop code for dependencies
Grudgelands does not ship (`screwdriver`, `flowers`, `dungeon_loot`,
`spawn`, `player_monoids`, `pova`) and recipes whose inputs
`grug_materials/content_curation.lua` retires (`default:steel_ingot`); see
the per-mod rows below.

These deletions do not change upstream pins or licenses. Markers at the
remaining load/call/registration sites document removed code; removed files
are listed here because they cannot retain in-file markers.

The mobs_redo row's WP6-review patch **(g)** is superseded by Lane S's
distance-aware unload rule: ordinary mobs keep `static_save = true`, so
`mob_staticdata()` can protect the nearest-player radius instead of letting the
engine discard the entity before Lua runs. Its two replacement `GRUG PATCH`
sites apply a 48-node no-despawn radius, a 128-node hard radius and a linear
chance between them, then consume a terminal unload marker on activation
without double-debiting the active-mob count; the total is **44 markers**. The
older `(g)` wording inside the compact table row below records the replaced
implementation, not the current rule.

| Path | Upstream | Vendored commit | License | Local patches |
|------|----------|-----------------|---------|---------------|
| `mods/ENTITIES/mobs` | [mobs_redo](https://codeberg.org/tenplus1/mobs_redo) | `646ba60` | MIT | `api.lua` `general_attack()`: `_grug_ignore_player` per-entity player-target veto hook (WP19 undead night truce, WP6 same-faction/factionless players — filtering during acquisition lets the mob pick the next-closest player). `api.lua` `do_states()` attack branch: soft de-aggro — walk speed instead of run speed beyond 25 m from the target (WP6, combat_stats §3; opt-out `_grug_soft_deaggro = false`). `api.lua` `item_drop()`: player-tag drop rule + profession drop hooks — one call-out to `grug_mobs._item_drop_filter` for mobs carrying `_grug_drop_rule`, all logic lives in `grug_mobs/aggro.lua` (WP6, combat_stats §3). **WP6-T10 pathfinding quality pass** (four patches, all in `api.lua`): (a) `path_height_blocked()` — nil guard on `core.registered_nodes[node]`, unknown/`ignore` (unloaded blocks) now counts as blocked instead of crashing the mob's step; (b) `apply_path()`/`smart_mobs()`/`do_states()` — `self.path.stuck` is now SET, not only read and reset (upstream dead code, same in the mcl_mobs fork): true only while the mob is wedged with NO usable path, cleared when a path is found, when line of sight returns and on both path-abandon exits; (c) `smart_mobs()` — `mob_pathfinding_stuck_path_timeout` is finally used (upstream read the setting and never referenced it): a mob already following a path gets that longer no-progress patience before the path is thrown away and re-planned, matching VoxeLibre `mcl_mobs/combat.lua:90-106`; (d) `do_states()` attack branch — `core.find_path` is no longer run for `attack_type == "dogshoot"` mobs, whose paths the consumption block right above already discards. Settings for all of this live in the game's `minetest.conf`. **WP6 review fixes** (four more `api.lua` sites): (e) `stop_attack()` + `do_attack()` + `do_states()` — `self.path.stuck` / `.following` / `.stuck_timer` are now reset on de-aggro, on a target CHANGE, and whenever the attack branch's already-computed `line_of_sight` comes back true. T10's patch (b) set the flag but every clear site it added is unreachable for a mob that is MOVING (`smart_mobs` zeroes `stuck_timer` above 0.5 m/s, so its timeout gate never opens), so one wedged moment became a permanent walk-speed crawl that also leaked across chases and target switches; (f) `do_states()` attack branch — the give-up distance is `self._grug_chase_range or self.view_range` instead of `view_range` outright (`_grug_chase_range = 45` is installed on every grug mob by `grug_mobs/aggro.lua`; vanilla mobs are untouched). Without it `dist` could never exceed the ≤ 16 m `view_range` of a ground mob, which made patch (b)'s own 25 m soft de-aggro dead code and made combat_stats §3/§4's chase model — chase persists, slows past 25 m, the 40 m/15 s leash resets — impossible; (g) `mob_activate()` — the `static_save = false` clear for untamed monsters now also requires `lifetimer < 20000`, the same predicate `mob_staticdata()` already used. `get_staticdata` is never called for an object with `static_save = false`, so the documented lifetimer exemption (named rares, `lifetimer = 30000`) could never be read and every rare was deleted on the first mapblock unload; (h) `path_height_blocked()` — `"ignore"` now counts as blocked too. It IS a registered node with `walkable = false` (builtin `register.lua`), so patch (a)'s nil guard let unloaded volume read as verified clearance; the comment there is corrected accordingly (unknown OR unloaded ⇒ blocked; only a removed mod's node ever caused the crash it claimed). **Player melee damage in `on_punch`** (first landed 2026-08-07 as weapon-cadence auto-attacks; revised 2026-08-09 by WP38, combat_stats §2 "Melee timing" — the cadence gate of 2026-08-07 and the shared per-player swing clock of 2026-08-08 are deleted, no punch is discarded and damage is proportional; the gate's old (i) is removed, and `grug_mobs.registered_cadence` is kept as the mob registry the melee flag checks): (i) ~~cadence gate at the top of `on_punch` discarding early punches via `grug_core.accept_melee_swing`~~ — removed with WP38, `accept_melee_swing` deleted from `grug_core`; (j) the player-melee path adds the attacker's Strength bonus (`grug_core.get_melee_bonus`) to the `fleshy` group before the armor scaling — vanilla's `tflp / full_punch_interval` factor (`tmp`) is KEPT, because that factor IS the proportional model (`tflp` is pinned at 0.2 s by one punch packet per client step, so each held punch deals a fifth of a swing; the reason `tflp` can never be a clock); (k) a melee crit roll after the `immune_to` loop (`grug_core.melee_crit`, ×1.5 + the ability crit particles, unfloored since WP38 — placed after that loop and not after the damage loop because `immune_to` OVERWRITES damage, so an earlier roll was discarded while its particle burst had already fired on a 0-damage hit); (l) the knockback test knocks back on the melee path when the swing actually LANDS — the remainder accumulator committed at least 1 (`subtract >= 1`); non-melee punches keep vanilla's `tflp >= punch_interval` (ability punches carry `tflp == full_punch_interval == 1.4` from `grug_core.deal_ability_damage`, so they knock back exactly as before). Ability punches (`grug_core.in_ability_punch`), mob-vs-mob, arrows and vanilla mobs_redo mobs are untouched. **Auto-attack as a skill** (2026-08-08, WP35 T3, one more site in `on_punch`, weapon-slot design E): (m) the `hitter:set_wielded_item(weapon)` write-back at the end of the wear block runs only `if wear > 0 or use_tr or grug_wear_id_created` (the last term is WP38 review patch (o)'s one-time ItemMeta persistence). On a player that call is not a field assignment but a full inventory serialization plus packet (`SendInventory`, `src/script/lua_api/l_object.cpp:362-369`), and `weapon` is a copy whose `add_wear(0)` changed nothing — upstream re-sent the whole inventory to tell the client the item is what it already has. Ability punches carry `punch_attack_uses = 0`, so a swing ability never writes its wear through this path. Normal tool/weapon punches are unaffected (wear > 0), and the `use_tr` half keeps the write unconditional wherever toolranks is installed, because `new_afteruse` can rewrite the stack's description meta at wear 0. **WP38, fractional melee remainder accumulator** (T1, two more `on_punch` sites, combat_stats.md §2): on the player-melee path (the flag is `grug_melee` since WP38 T2 — formerly `grug_cadence`; `grug_mob_hit` covers ability punches too) the hit splits into feedback and subtraction — hit sound, blood, damage flash and the injured animation key off raw damage > 0, while the health subtraction and `check_for_death` run on the accumulated integer preview (passed directly to the post-cancellation `grug_mobs` accepted-hit hook as `applied`/`fraction` for its lethal check; `immune_to`-matched hits are excluded because that loop SETS damage). **WP38 review, wear per SWING** (two more `on_punch` sites, combat_stats.md §2): (n) `grug_fraction` — the punch's `clamp(tflp / full_punch_interval, 0, 1)`, computed once from the normalized `tflp` (the same number the damage loop derives as `tmp`); (o) the wear block asks `grug_core.melee_wear_due(hitter, weapon, grug_fraction)` and zeroes `wear` until that concrete stack's fractions add up to a whole swing. With the cadence gate gone this block runs on all ~5 punch packets/s, and spending a full swing's wear on each of them wears the tool `1/fraction` times faster than before WP38 (at fpi 1.0 a weapon dies after ~109 s of held attacking instead of ~546 s) while firing (m)'s `set_wielded_item` — a full inventory serialization plus packet — on every punch, ~500/s at the 100-player target. The helper assigns a persistent opaque `_grug_melee_wear_id` to a wear-capable ItemStack on first use and keys runtime fractions by player plus that id, so A→B cannot transfer A's remainder and returning to A resumes it; the caller writes a newly assigned id back once even when no wear is due, and clears the runtime entry if the stack breaks. The gate sits AFTER the item-type, creative and `punch_attack_uses == 0` adjustments and explicitly excludes creative punches; empty hands/non-tools and every other wear-free punch neither acquire an id nor consume the accumulator. **WP38 native-input correction (2026-08-10, two further `on_punch` sites):** (p) after the fraction is known, `grug_core.prepare_accumulated_melee` previews only an ordinary tool/fist hit's fractional damage remainder, while an exact authoritative token lets `grug_core.prepare_native_melee` attach a full ability swing's selected replacement delta before the one crit roll; (q) after both `do_punch` and CMI accept, the ordinary preview commits its remainder, whereas `finish_native_melee` settles only the authoritative proc's cost, charge and post-effect. A cancelled Mighty Blow therefore cannot consume rage/charge or apply its effect, and no recursive second punch is used. (r) the accepted-player-hit call-out runs provocation, loot tagging, threat/rage and lethal rare/XP work only after both cancellation gates, before health subtraction; a cancelled custom or CMI punch has no irreversible hit side effects. **43 `GRUG PATCH` markers total**, including seven fresh-server cleanup sites listed above, WP13 playtest round 2's per-target non-combatant veto in `general_attack()` and the mob-pressure round's three-site attack-cadence patch (2026-09-16, see the section above). Also wrapped by `grug_mobs`; `mobs:spawn_abm_check` is overridden there — a documented upstream extension hook, not a patch |
| `mods/BASE/default` | [minetest_game](https://github.com/luanti-org/minetest_game) `mods/default` | `b5243f3` | LGPL-2.1+ / media CC BY-SA | `mapgen.lua` tail: upstream biome/ore/decoration registration for biome-based mapgens is disabled. WP40 R7 owns the named-zone world through one VoxelManip transaction, registers zero Lua biomes/decorations and retains only its closed six-record native ore allowlist. **WP43 wrapper contract** (additional fresh-server removals are listed above): `grug_materials/overrides.lua` copies live `groups` before marking the explicit generated-ground inventory natural, assigning the five upstream ores their separate harvest groups/descriptions and removing the retired node `level`; it also strips `level` from obsidian/storage nodes. Wood/Stone/Bronze/Steel picks receive T1/T1/T1/T3 depth groups and rebuilt `cracky`/`grug_resource` capabilities with `maxlevel = 0`; their explicit WP25 ordinary values, `max_drop_level` and upstream `punch_attack_uses` are preserved. `derivatives.lua` copies the vendored Steel Sign/Ladder definitions into canonical Iron nodes and, when `stairs` is present, copies four shapes for each of Iron/Tin/Copper/Bronze/Gold into 20 canonical nodes; it removes natural/level groups, rewrites descriptions/drops and adds no recipes. `content_curation.lua` clears the surviving Steel-pick recipe, eight retired Mese/Diamond tool recipes, every legacy processed furnace/pack output, both rough-Diamond conversions, all legacy Mese storage/light/post outputs and the two mobs recipes before unregistering the retired vendored registrations; no saved-world aliases are installed. Current content uses canonical bars/blocks and the surviving tool ladder directly. On an upstream update, re-check the disabled registration tail, every named registration and the ordinary pick/punch-use baselines. See the fresh-server cleanup list for additional in-place removals. |
| `mods/BASE/creative` | minetest_game `mods/creative` | `b5243f3` | LGPL-2.1+ | Unused API compatibility wrapper removed; see fresh-server cleanup above. |
| `mods/BASE/sfinv` | minetest_game `mods/sfinv` | `b5243f3` | LGPL-2.1+ | none |
| `mods/BASE/stairs` | minetest_game `mods/stairs` | `b5243f3` | LGPL-2.1+ | Old-name aliases and upside-down conversion removed (see above). WP43's external `grug_materials/derivatives.lua` copies the four generated Steel/Tin/Copper/Bronze/Gold shapes into 20 canonical Iron/Tin/Copper/Bronze/Gold nodes with canonical drops and no recipes. `overrides.lua` separately removes inherited non-zero `level` from the four Obsidian/Obsidian Brick/Obsidian Block shapes (12 registrations), so crafted stairs cannot revive the retired engine gate |
| `mods/BASE/player_api` | minetest_game `mods/player_api` | `b5243f3` | LGPL-2.1+ | Obsolete offline-player API wrappers removed; see fresh-server cleanup above. |
| `mods/BASE/doors` | minetest_game `mods/doors` | `b5243f3` | MIT / media per `license.txt` (CC BY-SA 3.0, CC BY-SA 4.0, CC BY 3.0, CC0 1.0) | Fresh-server removals (old `doors_owner` meta reader + 4 call sites, per-door `:doors:replace_<name>` conversion LBM, deprecated `doors.register_door()` shim) — see cleanup above. `on_rotate` removed with the upstream `optional_depends = screwdriver` (mod not shipped). Steel Door and Steel Trapdoor **recipes** removed: they consumed `default:steel_ingot`, which `grug_materials/content_curation.lua` retires and unregisters; both nodes stay registered and placeable. `level = 2` dropped from the Steel Door and Steel Trapdoor node groups — `grug_materials/audit.lua` hard-fails startup on any node with a non-zero `level` group. `models/door.blend` not vendored. 13 `GRUG PATCH` markers (4 of them the removed `doors_owner` call sites) |
| `mods/BASE/xpanes` | minetest_game `mods/xpanes` | `b5243f3` | MIT / media per `license.txt` (CC BY-SA 3.0, CC0 1.0) | Fresh-server removals (15 numbered old-name aliases per pane, one-shot `xpanes:gen2` upgrade LBM) — see cleanup above. `doors` promoted from `optional_depends` to `depends` and its `core.get_modpath("doors")` guard removed (we ship `doors`). Steel Bars **recipe** removed (`default:steel_ingot`, retired); the pane stays registered. `level = 2` dropped from the Steel Bar Door and Steel Bar Trapdoor node groups (see the `doors` row). `xpanes.register_pane`'s `def.recipe` is now optional, because `core.register_craft` refuses a nil recipe outright. 7 `GRUG PATCH` markers Consequence: the retained Steel Bar Door/Trapdoor recipes consume `xpanes:bar_flat`, which no longer has a recipe, so they are unreachable until WP26/WP29 add an iron-bar source (review 2026-09-14). |
| `mods/BASE/beds` | minetest_game `mods/beds` | `b5243f3` | MIT / media per `license.txt` (CC BY-SA 3.0) | **Decoration only.** `functions.lua` and `spawns.lua` deleted with their loaders (sleeping, physics override, night skip, the in-bed formspec, respawn/die/leave callbacks and the `beds_spawns` world-file reader/writer incl. its old-format branch). Player spawn stays owned by `grug_core`. `beds.on_rightclick`, `beds.can_dig`, the spawn/kick bookkeeping in `destruct_bed` and the `on_rotate` screwdriver hook removed; the `<name>` → `<name>_bottom` alias and the two PilzAdam aliases removed (the recipe names the real node). `mod.conf` drops `spawn`, `player_monoids` and `pova`. A Grudgelands note is appended to `README.txt`, whose upstream text still describes the removed mechanic. Both halves still place (facedir), render and dig. 5 `GRUG PATCH` markers (1 in `init.lua`, 3 in `api.lua`, 1 in `beds.lua`) |
| `mods/BASE/wool` | minetest_game `mods/wool` | `b5243f3` | MIT / media per `license.txt` (CC BY-SA 3.0) | The two jordach 16-colour old-name aliases removed — see cleanup above. 1 `GRUG PATCH` marker |
| `mods/BASE/dye` | minetest_game `mods/dye` | `b5243f3` | MIT / media per `license.txt` (CC BY-SA 3.0) | The per-colour `group:flower,color_X` recipe removed: Grudgelands ships no `flowers` mod, so no node ever carries the `flower` group. Coal → black, blueberries → violet and the 19 mix recipes are unchanged. 1 `GRUG PATCH` marker |
| `mods/BASE/vessels` | minetest_game `mods/vessels` | `b5243f3` | LGPL-2.1+ / media per `license.txt` (CC BY-SA 3.0) | The `dungeon_loot` registration and its `optional_depends` removed (mod not shipped). The Heavy Steel Bottle node, its craft recipe, its cooking return and `textures/vessels_steel_bottle.png` removed: both recipes referenced `default:steel_ingot`, retired and unregistered by `grug_materials/content_curation.lua`. Shelf, glass bottle, drinking glass, glass fragments and the fragments → `default:glass` cooking recipe are unchanged. 2 `GRUG PATCH` markers |
| `mods/BASE/walls` | minetest_game `mods/walls` | `b5243f3` | LGPL-2.1+ (no media; uses `default` textures) | The single-texture-string fallback in `walls.register` for callers written against the pre-table API removed — see cleanup above. `walls.register` and the three cobblestone/mossy/desert walls are otherwise unchanged. 1 `GRUG PATCH` marker |
| `mods/ITEMS/grug_decor` (castle) | [castle_masonry](https://github.com/minetest-mods/castle_masonry) | `900d633` | MIT / textures CC-BY-SA 3.0 | **Curated copy, not a vendored tree** (see the note below the table). Harvested definitions: the `register_pillar` set (8 shapes), the `register_arrowslit` set (4) and the `register_murderhole` set (2) instantiated for 9 materials -- `castle` (upstream's castle-stone texture set) plus `default` stonebrick / stone_block / desert_stonebrick / desert_stone_block / sandstonebrick / silver_sandstone_brick / obsidianbrick / mossycobble -- 126 nodes; the six single nodes `stonewall`, `stonewall_corner`, `rubble`, `dungeon_stone`, `pavement_brick`, `roofslate`; and 4 stair/slab/inner/outer sets for stonewall / rubble / dungeon_stone / pavement_brick (16). **148 nodes.** Dropped: every `register_craft` (including the fuel recipes), the arrowslit param2-flip LBM, all `register_alias` calls, the `castle_masonry_*` settings, the `_mcl_*` fields and the `pickaxey`/`stonecuttable` MCL groups. Patched: the material table is spelled out instead of derived from `core.registered_nodes` at load time (load-order independence from `grug_materials`); `stone`/`level` groups are not copied; rubble loses `falling_node = 1` Every harvested node additionally sets `is_ground_content = false` (upstream leaves the engine default `true`), so mapgen cave carving cannot remove placed settlement nodes; applies to all four sources below (review 2026-09-14). |
| `mods/ITEMS/grug_decor` (cottages) | [cottages](https://github.com/Sokomine/cottages) | `ab7f7e1` | GPL-3.0-only / media per its README | **Curated copy.** Harvested definitions: `register_roof` (roof / roof_connector / roof_flat) for straw, reed, wood, slate, wood shingle and terracotta shingle (18); `slate_vertical`, `reet`, `straw`, `straw_mat`, `straw_bale`, `straw_ground`, `loam`, `glass_pane`, `glass_pane_side`, `wood_flat`, `wool_tent`, `wagon_wheel`, `wagon_wheel_road`, `wagon_load`, both window shutters, the four barrel meshes, `tub`, `bench`, `table`, `shelf`, `washing`, `anvil` (26); loam and clay stair/slab/inner/outer sets (8). **52 nodes.** Dropped: everything using `cottages_rope.png` (unverified licence, asset audit finding 8), the `feldweg` road mesh set, threshing floor, hand mill, chests, beds, sleeping mats, pitchfork, fences, the `wool` fallback node, every `register_craft`, the shutter day/night ABM and every `on_rightclick`/`on_punch` state machine. Patched: shutters and all four barrel states are STATIC and each separately placeable; `sleeping_mat`/`animates_player`/`hay` groups removed; `legacy_wallmounted` removed (fresh-server mode); per-roof `sounds` added (upstream sets none). The 2 `default_*` textures cottages expects but does not ship (`default_wood.png`, `default_tree.png`) are referenced from `mods/BASE/default/textures` Further group deviations: `dig_immediate = 2` became `oddly_breakable_by_hand = 2` on the two wagon wheels, and the barrel groups drop `tree`/`snappy` (review 2026-09-14). |
| `mods/ITEMS/grug_decor` (darkage) | [darkage](https://github.com/adrido/darkage) | `494f81c` | MIT / graphics CC0 | **Curated copy.** Harvested definitions: 22 blocks -- adobe, basalt (+rubble/brick/block), chalk, chalked_bricks, marble (+tile), ors (+rubble/brick/block), serpentine, slate (+rubble/brick/block/tile), stone_brick, mud, straw_bale; the `register_reinforce("Wood")` set (reinforced_wood + slope/arrow/bars, 4); the glass family -- glass, glass_round, glass_square, wood_frame, iron_bars, iron_grille, wood_bars, wood_grille (8); 4 connected walls (basalt_rubble, ors_rubble, stone_brick, slate_rubble); and the 16 stair/slab/inner/outer sets `stairs.lua` registers for the harvested materials (64). **102 nodes.** Dropped: `mapgen.lua` in full (no ores, no strata -- WP40 R7 owns the world), the four craftitems and every `register_craft`, `furniture.lua`'s box/shelves (formspecs) plus lamp/chain, the glow-glass family, the `unifieddyes`-gated milk glasses (unifieddyes is GPL-2.0-only), the tuff / rhyolitic tuff / gneiss / schist / shale / silt / darkdirt / dry_leaves nodes, the plaster-conversion LBM and the tuff weathering ABM. Patched: every `drop` removed with the crafts (they named removed craftitems and `farming:straw`); `not_cuttable`, `legacy_mineral` and `stone` groups removed. Upstream declares no `darkwood` or `mud_brick` node at this commit Sound deviation: mud uses plain dirt sounds instead of upstream's silent footstep (review 2026-09-14). |
| `mods/ITEMS/grug_decor` (xdecor) | [xdecor-libre](https://codeberg.org/Wuzzy/xdecor-libre) | `43a7753` | BSD-3-Clause / textures CC0 | **Curated copy.** Harvested definitions: barrel, chair, table, cushion, cushion_block, curtain + curtain_open, lantern, lantern_hanging, candle, 8 potted plants, 4 paintings, stonepath, woodframed_glass, ivy, cobweb, itemframe, rope, workbench, cauldron, empty_shelf. **31 nodes.** Dropped: chess, enchanting, cooking, mailbox, hive, mechanisms, enderchest, trampoline, tatami, the lightboxes, the hard-node tile family, the `xpanes` panes and the doors (neither `xpanes` nor `doors` is vendored), radio and speaker (their textures are the LICENSE.txt CC BY 4.0 exception), every `register_craft`, both LBMs, the `xdecor:f_item` entity and every behaviour hook (sitting, curtain toggling, lantern floor/ceiling placement, painting randomisation, item-frame handling, rope unrolling). Patched: `xdecor.register`'s derived `drawtype`/`paramtype`/`paramtype2`/`sunlight_propagates` are spelled out per node; the `sittable`/`plant`/`flower`/`potted_flower`/`cauldron`/`fall_damage_add_percent` groups and the cobweb's `move_resistance` are removed; every hidden state node (open curtain, hanging lantern, paintings 2-4) loses its `not_in_creative_inventory`/`drop` pair; the curtain's base texture is xdecor's own CC0 `xdecor_cushion` cloth instead of `wool_red.png` (the `wool` mod is not vendored) Sound deviations: potted plants use plain leaves sounds (upstream overrides place/dug with stone), rope uses leaves sounds instead of upstream's rope set (review 2026-09-14). |
| `mods/ITEMS/grug_smelting` | [Lord-of-the-Test](https://github.com/minetest-LOTR/Lord-of-the-Test) `mods/lottblocks/crafting.lua` | `f164140` | LGPL-2.1 (code only; **no media taken**) | **Curated code port, not a vendored tree** (see the note below the table). Ported: the dual-furnace STATION -- the node pair (`crafting.lua:201`), its two-material / two-output / one-fuel inventory (`:222-230`), the node-timer drive (`:84,220`), the either-order two-input matcher (`:55-73`), the `add_craft` registrar (`:31-34`) and the fuel-slot filter (`:239-268`). Dropped: `lottblocks`' own four `dualfurn` recipes (LotT materials), its `func` recipe hook (no WP26 recipe uses one), its steel-tier furnace craft recipe (`:271-277`, which would deadlock our ladder -- Steel is T3 here and needs the station), and every `lottblocks` texture (CC BY-SA 3.0; the two front faces are re-skinned from the vendored minetest_game fronts instead, `mods/ITEMS/grug_smelting/LICENSE-media.md`). Patched: recipes are a LIST keyed by the unordered input pair instead of upstream's output-keyed table (which silently overwrites a second recipe for the same output and forces a full walk per timer tick); the timer consumes the engine's `elapsed` instead of adding exactly 1 per call; `allow_metadata_inventory_*` ask `core.is_protected`; `can_dig`/`on_blast` cover all three lists and a leftover output is dropped rather than lost |

WP43 also clears the vendored `mobs:lasso` and `mobs:protector2` recipes from
the external `grug_materials/content_curation.lua` module because their Mese/Diamond
inputs are retired. This adds no `mobs_redo` in-place patch and does not change
the 43-marker inventory above.

## Curated code port -- `mods/ITEMS/grug_smelting` (WP26)

The `grug_smelting` row above is **not** a vendored tree either. No upstream
file is copied, no `lottblocks` global exists and no `lottblocks` media is
shipped; what is taken is one station's mechanism, re-implemented against the
`mods/BASE/default/furnace.lua` patterns this game already uses, with the
divergences listed in the row. Rule 4's update procedure applies per
mechanism: diff `lottblocks/crafting.lua` at the new commit against the ported
list above, re-apply the listed drops and patches, and update the commit hash
here. The `-- GRUG PATCH:`-equivalent markers are the numbered departures in
the header comment of `mods/ITEMS/grug_smelting/node.lua`, each citing the
upstream line it came from.

The recipe surface itself is enforced at every server start by
`grug_smelting`'s own audit (`recipes.lua`) and headlessly by
`tools/wp26/smelting_kat.lua`.

## Curated copies -- `mods/ITEMS/grug_decor` (WP13)

The four `grug_decor` rows above are **not** whole vendored trees. `grug_decor`
harvests individual **node definitions and media** from four upstream mods and
ships nothing else: no upstream file is copied verbatim, no upstream global
exists, and the mod registers no craft recipe, ABM, LBM, node timer, formspec
or inventory, and never writes a node at runtime. Media provenance for all 109
shipped files is in `mods/ITEMS/grug_decor/LICENSE-media.md`; because cottages
is GPL-3.0-only, the combined work is distributed under GPL-3.0.

Rule 4's update procedure applies **per definition**, not per file: to follow an
upstream change, diff the named upstream source file at the new commit against
the harvest list in the row, re-apply the listed drops and patches to the
affected definition only, and update the commit hash here and in
`LICENSE-media.md`. The `-- GRUG PATCH:` markers in
`mods/ITEMS/grug_decor/*.lua` name every deliberate divergence and cite the
upstream file it came from. `shapes.lua` is the one structural copy: the four
shape registrations of `mods/BASE/stairs/init.lua` re-namespaced to
`grug_decor:` and stripped of their recipes, because
`stairs.register_stair_and_slab` can only ever produce `stairs:stair_<subname>`
and every grug_decor node name must start with `grug_decor:`.

The registration contract is enforced by `tools/wp13/decor_registry_kat.lua`,
an engine-free smoke test that loads the mod against a stub `core` and asserts
the namespace, that every texture and mesh resolves, and that nothing
mechanical was registered.
