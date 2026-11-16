# Expeditions

Part of the [module implementation guide](../module-guide.md), which indexes every
area. The Expeditions runtime (`grug_expeditions`). Implementation seams and engine pitfalls only; the
[design docs](../../design/README.md) own the game rules. Source paths in code
spans are repository-relative.

Sections: [Expeditions](#expeditions).

## Expeditions

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- No saved run state beyond the meta keys listed below.
- Every Expedition mob spawns through `packs.lua`'s spawn, which sets the mark
  `_grug_expedition`; a summon outside it needs the mark in its staticdata (lava immunity
  and the critter tier hang on it).
- Every Expedition mob path goes over the template's walk grid (`navigation.lua`), never
  `core.find_path`.
- A new template carries the places `boss_room_min` and `boss_room_max` and writes floor
  stairs only through `relief.py` and light only through `light.py`.
- A new Expedition's fight needs a real test ([expeditions.md](../../design/expeditions.md) §9).

Rules: [expeditions.md](../../design/expeditions.md). `mods/PLAYER/grug_expeditions/`, files
in the [mod map](../mod-map.md); **the public interface is the header of `init.lua`**, and a
`run` row is read-only for other mods.

### Run state

- **Nothing about a run is saved.** `runs.lua` holds the runs in memory, so a restart ends
  them all. Two player meta keys outlive a run: `grug_expeditions:origin` (the waystone id
  of the last way in, a capital's at the registrar, any network stone's since Round 72's
  Expeditions tab; for a login or respawn in a box whose run is gone) and
  `grug_expeditions:logout_death` (a pending death, set at the leave, spent at the next
  join). Since Round 72.1 a third: `grug_expeditions:deserter_until`, the end of a
  Deserter's Mark in `os.time()` (wall clock, so it runs through a logout and a restart),
  read into `runs.lua`'s table at a join and cleared at a join once spent; the rules ask
  that table, never the meta. Mob fields sit in box blocks, which preparation wipes. None of
  the keys is map-bound.
  Credit goes out under the stable `expedition:<catalogue id>`, never a per-run id:
  `grug_achievements` keeps a saved counter per id.

### Inside and outside

- **No per-tick pass over players.** "Inside" follows `grug_home.register_on_teleport` and
  the leave and join callbacks (every player teleport ends in `travel.lua`); the release
  clock is one `core.after` per empty stretch; a closing run (Finish or Cancel, Round 72.1)
  one `core.after` a second for its minute, the countdown through `grug_core.banner` to those
  inside; `encounters.lua`'s one-second pass runs only
  while a player is inside and a room waits, `packs.lua`'s tick only while a pack is pulled; `traps.lua`'s pass (5 a second) only while a run with traps has a player inside (since Round 73 it also tests an armed ambush: a segment from each player's last position against the zone, nothing once it fired), and its fireballs are entities that are never saved; `particles.lua` (Round 73) adds one endless spawner per `particles` line and player inside, sent to that player alone, deleted when they leave and at the end;
  preparation's `core.after(0)` chain only while one is under way; the respawn lock (Round
  78, `respawn_lock.lua`) one `core.after` a second per locked dead player, stopped by the
  lock's end and the logout. An admin `/teleport` out
  is not noticed: the player counts as inside until logout.

### Preparing a slot

- **Preparation** (`preparation.lua`, its header has the order and why): objects out,
  `delete_area` mapblock by mapblock
  ([workaround 9](../upstream-workarounds.md#9-coredelete_area-commits-each-mapblock-on-its-own)),
  box ± 16 generated one chunk at a time, the gate, the clearing pass, the template. The
  clearing pass is not optional: slices opening air beside natural cave water leave
  `grug_core:water_barrier` nodes. VoxelManip writes no meta or timers, so
  `register_on_ready` sets them. Every chunk holding a box block must have its centre in
  the box (`catalogue.chunks_of`; the fixture holds this for all 100 slots).

### Seams in other mods

- **Seams in other mods** (each a small hook; Expedition logic stays here):
  `grug_core.register_world_exception` (`protection.lua`: only places the world rule
  refused ask; `interaction_protected`, `world_alterable` and `ground_effect_protected` do
  not), `grug_mounts.register_summon_guard`, `grug_home.register_respawn_home` (asked on
  every look at the home, so a row must survive the look on arrival, outside the box:
  `guard.lua`'s `to_capital`), `grug_home.register_on_teleport`, `trip.fallback`,
  `grug_home.waystone_pos`, `waystone_arrival`, `grug_home.register_expedition_tab` and
  `show_waystones` (Round 72, `entry.lua`: the Expeditions tab and the stones inside; its
  `actions` and `act` since Round 72.1), `grug_core.register_status_source` (Round 72.1,
  `registrar.lua`: the Deserter's Mark, a source so a death does not clear it),
  `grug_home.register_return_guard` and `grug_core.register_lava_hold` (Round 72,
  `guard.lua`: Return Home refused in or over lava in a box; every box holds its lava),
  `core.show_death_screen` overridden (Round 78, `respawn_lock.lua`: its own form
  `grug_expeditions:death` while locked, else the builtin screen; builtin
  `death_screen.lua` calls it at a death, a join with hp 0 and any other form closed while
  dead, so Esc and a relog come back through it, and the server ignores the legacy
  respawn packet),
  `grug_mobs.set_spawn_free_field` (first
  check of `spawn_policy_allows`), `grug_parties.register_on_member_left` (it can tell a
  leaver from the last member, which `register_on_change` cannot),
  `grug_parties.invitation_warning`, `settle_boss`'s `credit_as` (`bosses.lua`),
  `roll_mob_gear`'s lift on `_grug_expedition` and `grug_items.roll_gear_item`
  (`grug_quality`). The registrar's role is one `SERVICE_ROLES` entry on its own core socket
  `expedition_registrar` (0.73.1; before that the guild clerk's socket); `start_npc_claim`
  still removes an NPC whose saved role differs from its socket's, for every socket.

### Expedition mobs

- **Mobs** spawn through `core.add_entity` (`packs.lua`), not `mobs:add_mob`, which the
  active-mob limit can refuse. Everything sits in the first staticdata (`encounters.lua`'s header):
  `_grug_spawn_level`, `_grug_expedition`, `_grug_authored`, `_grug_pack`, and a lifetimer
  above 20000 so `remove_far_mobs` leaves a skipped pack alone. Not `static_save = false`:
  such a mob goes with its block. `add_entity` skips a definition's `on_spawn`: spider
  and golem have none, but bear, ape, zombie and weevil set state there, so check them
  before a roster uses them. A boss is an elite with a ledger id, never the flat `boss`
  tier of `levels.lua`. `encounters.lua` wraps `grug_mobs.settle_mob_death` and
  `_item_drop_filter`, so `grug_mobs` holds no Expedition code. Removal loops skip attached
  objects: they are a player's tag and wield.

### Ambush and trap seams

- **Round 73 seams:** the ambush is a trap kind (`traps.lua`, chosen with the groups at
  readiness) that hands its room to `encounters.lua`'s `M._spring_room(run, room, player)`;
  such a room is never placed by proximity. A `critter` room is placed by proximity but is no
  pack (`packs.add_critter`: no pull, no `engage_mob`, no drop), and `settle_mob_death` in
  `grug_mobs/init.lua` settles nothing for a `_grug_scenery` mob. Lava immunity is
  `lava_damage = 0` at spawn, in `add_critter` and again on every activation of a
  `_grug_expedition` mob (`packs.lua`, `live_claim`), since the definition's value comes back
  with each activation; lava stays a boundary through `is_node_dangerous`'s `node_damage`,
  so `grug_nav`, the walk-edge probe and the boss floor are unchanged. A spread spawn spot
  needs a floor, and a pack's jump to a player in lava lands on the basin's rim.

### Packs

- **Packs** (`packs.lua`, its header proves that nobody is held with nothing able to reach
  them). `_grug_pack` is the one field `grug_mobs` reads: leash, evade and give-up in
  `aggro.lua`, stuck and dawn cleanup through `mob_bound`, every accepted `do_attack` in
  `init.lua`. It wraps `grug_core.engage_mob`, `settle_mob_death`, `live_claim` and
  `core.calculate_knockback`: a pack's hit pushes level, because a pack swings as one and
  the downward pushes of one step add up to a fall. Jumps stand on the feet's cell,
  `floor(y + 0.5)`: `math.round` takes a floor below y 0 into the floor's own cell.

### The walk grid

- **The walk grid** (Round 74): `build.py` writes each template's grid
  (`tools/expedition_templates/walkgrid.py`, [format](../expedition-template-format.md));
  `template.lua` reads it, `navigation.lua` makes one `walkgrid.lua` grid per template at
  load (`tpl.walkgrid`) and installs grug_nav's Expedition backend `mobs.grug_nav.grid`
  (`view(self)`: the grid of the mob's live run, by `_grug_expedition` and its home;
  `path`; `line`) and the evade guide through `grug_mobs.register_evade_guide`. A world
  position becomes a cell by subtracting the run's `minp`; the door is read live at its
  place. Fields are kept per template, home cell, body class and door state for the
  server's life (16 KB each). A failed grid search counts its reason in
  `mobs.grug_nav.counters` (`grid_off_start`, `grid_off_goal`, `grid_no_way`). The
  guide's instant way home (no grid way) is `grug_mobs.place_on_ground` with the
  velocity stopped and `nav.forget`, as `packs.lua`'s jump. A template change rebuilds
  its grid with `build.py`; `tools/r74_nav` proves it.

### Adding an Expedition

- **Adding an Expedition:** a source in `tools/expedition_templates/sources/` and
  `build.py` ([format](../expedition-template-format.md); `t.dig` for ore, written with the
  T2 ore and gem: a run's tier swaps them, `catalogue.TIERS`); a catalogue row with its
  level range (`level`, `max_level`); a `loot.TABLES` row with material rows by mob band
  (`level = {lo, hi}`; the load stops without a table, and refuses one naming an ore or
  gem); the boss's definition with `_grug_hp_scale` and a fixed name in a world slot of
  `data/names.json` (`world/<boss>/L<lo>-<hi>`, plus `tools/r38_names`, `disposition.lua`
  and `grug_achievements/creatures.lua`, and a row in `docs/planning/round28/items/existing.json`
  for the design validator); its quest with a row in `EXPEDITION_TARGETS` in
  **both** validators (`grug_quests/validate.lua`, `tools/r28_design/validate.py`) and
  `tools/r60_capitals/build_structure.py`'s `optional` and `group`. A wall sign's text goes
  in the catalogue row's `signs` (place name -> text, written on ready by `encounters.lua`;
  The Second Shift's shift board). A boss's marked spot goes through
  `grug_mobs.expedition_mark(self, pos)` and `expedition_unmark(handle)` (`traps.lua`, the
  strike helper; Auditor Nemm in `skeleton_raider.lua`). Sight counts as a pull,
  so keep a template's arrival beyond a pack's view range + 8. On a slab floor a jump lands
  on the player's own cell. Lava a template writes stays put: every box holds it
  (`grug_core/lava_guard.lua`), and a template's lava has nothing beside or below it to
  flow into (the shared proof's `lava` rule). `income.py --check` has no Expedition term, so its pass says nothing about a chest.
  Since Round 73 a source is written with the authoring helpers (relief, passages, light,
  dressing, hazards: [format](../expedition-template-format.md#authoring-helpers-round-73)), its
  fixture runs the shared proof `tools/expedition_templates/proofs.lua` with every rule on
  (a `report` switch per rule only for a template not yet built for it, and `mouths`, the
  passages' mouths, whenever there is lava), and `preview.py` draws its rooms for the user's look.

### Expedition fixtures and probes

- **Fixtures and probes:** `tools/README.md`, "Round 71". The fixtures' stubs need
  `get_attach` on objects and meta on players. `r71_frame` stubs the party seam: the real
  `remove_member` is in `r67_social`, the real respawn path in `r69_home`.
