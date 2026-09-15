# WP13 increment: character visuals

Lane: character visuals. Contract:
[wp13-character-visuals-contract.md](wp13-character-visuals-contract.md)
(binding). Design record: [character_visuals.md](../design/character_visuals.md).
Evidence: `tools/wp13/evidence/20260914-character-visuals/`.

Base: `main` at `9026d89`.

## What shipped

A new mod **`mods/PLAYER/grug_visuals`** and its four consumers.

### The seam

```lua
grug_visuals.compose{race = "dwarf",
	armor = {head = itemname, chest = itemname, legs = itemname,
		feet = itemname},
	weapon = itemname}
-- -> {textures = {"<one composed string>"},
--     visual_size = {x=, y=, z=} or nil,
--     weapon = itemname or nil,
--     key = "<the cache key it was composed from>"}
```

Pure, deterministic, cached by `key`; the returned table **is** the cache entry
and callers must treat it as read-only. Beyond the contract's three fields the
spec also accepts `skin` (an explicit base texture for a humanoid that is
nobody's race), `armor_line` + `bracket` (a whole line at one bracket, for an
NPC with no inventory), `level` (resolved through `grug_gear.bracket_for_level`)
and `weapon_family` (resolved to `grug_gear:<family>_b<bracket>`). Every one of
them is normalized *before* the key is built, so two specs that mean the same
thing share one entry. `armor.torso` is accepted as a spelling of `armor.chest`.

Players:

- `grug_visuals.player_spec(player)` — race, the four armor lists, the weapon
  slot, in compose's vocabulary.
- `grug_visuals.apply(player)` — compose, then `player_api.set_textures` plus
  `set_properties{visual_size}` **only when the key changed**, then the wield
  entity. Idempotent and cheap by construction: an unchanged character writes
  nothing at all.

Entities:

- `grug_visuals.mob_visual(entity, cfg)` — resolves a `_grug_visual` field that
  is either a spec table or a `function(self)`.
- `grug_visuals.apply_entity(entity, cfg, write_textures)` — composes, installs
  the skin once per entity (`_grug_visual_skin`, a plain string field, so a
  reactivated mob does nothing) and syncs its wield entity. `write_textures` is
  the optional writer grug_mobs passes so the composed list becomes the
  *pristine* list its tier tint is layered on.

Armor art is resolved from the real item registry at `mods_loaded`
(`grug_visuals.index_armor`), off the `grug_equip_<slot>` and
`grug_armor_class` groups and `_grug_bracket` — not by parsing item names, so a
later WP's armor shows up without an edit here.

### Hooks

| Trigger | Site |
| --- | --- |
| join | `mods/PLAYER/grug_visuals/apply.lua:214` |
| respawn | `mods/PLAYER/grug_visuals/apply.lua:230` |
| race chosen | `mods/PLAYER/grug_visuals/apply.lua:236` (new `grug_classes.register_on_race_chosen`, `mods/PLAYER/grug_classes/init.lua:104`) |
| class changed | `mods/PLAYER/grug_visuals/apply.lua:240` |
| equipment changed | `mods/PLAYER/grug_visuals/apply.lua:254` (skips offhand and the two trinkets; registered **before** grug_inventory's page refresh — see "Ordering") |
| mob activation | `mods/ENTITIES/grug_mobs/init.lua:451` (the `after_activate` wrapper) via `apply_visual`, `mods/ENTITIES/grug_mobs/init.lua:333` |
| vendor activation | `mods/ENTITIES/grug_traders/vendors.lua:260` |

### Ordering

The Character page renders the player's **live object properties**
(`grug_inventory/pages.lua` `preview_model`), and AGENTS.md allows exactly one
equipment-driven page-refresh consumer. So the composed look has to be written
before that refresh runs, which is two orderings stacked:

- **Load order.** `grug_inventory` now carries `optional_depends =
  grug_visuals` and `grug_visuals` carries no dependency back (a mutual
  `optional_depends` is a cycle and the game would not load). That makes
  `grug_visuals` register its equipment consumer first.
- **Callback order.** `grug_core.notify_equipment_change` runs consumers in
  registration order (`ipairs` over the registry), so first registered is first
  run.

Both links are checked against the shipped sources by
`tools/wp13/visuals_order_kat.lua`, which builds the real mod.conf graph of the
whole game, topologically sorts it the way the engine does and then loads the
real `grug_core/combat.lua` and fires the seam. Reverting the two mod.conf
lines makes it fail with `grug_visuals does not load before grug_inventory`
(positions 28 vs 26) — the negative control for the finding it closes.

### Mob rosters

| Mob | `_grug_visual` |
| --- | --- |
| `grug_mobs:guard_accord` / `_throng` | human / orc, metal line at the bracket its own level buys, sword (`guard.lua:111`) |
| `grug_mobs:bandit` | one of four races rolled once per bandit and kept in staticdata, cloth line at its camp's level, dagger (`bandit.lua:79`) |
| `grug_mobs:mirefolk` | its own fish-folk skin, no armor, no weapon (`mirefolk.lua:55`) |
| the eight vendors | race dress, unarmed (`vendors.lua:179`) |

## Verification

| Gate | Result |
| --- | --- |
| `tools/wp13/character_visuals_kat.lua` under LuaJIT and `tools/bin/lua51` | byte-identical, `wp13_cv_result PASS 0` |
| `tools/wp13/visuals_order_kat.lua` under both | byte-identical, `wp13_order_result PASS 0` |
| `luac51 -p` + `SETGLOBAL` on every changed file, tree-wide parse | pass; one `SETGLOBAL` per mod table, none in the new non-init files |
| the five plain-5.1 sweeps, scoped and tree-wide | zero hits outside prose |
| `tools/check_fresh_server.py` | pass |
| every media file has a `LICENSE-media.md` row; the art regenerates byte-identically | pass |
| one headless boot (`tools/luanti_headless.sh 180`) | `PASS`, zero ERROR/ModError, zero warnings from this mod |

The KAT composes all 366 distinct looks (6 races bare, 6×2×6 full sets, 6×2×4×6
single pieces) and proves: purity and determinism, cache identity for equal
specs, well-formed modifier strings for the engine's splitter, that every
texture named exists on disk, that stature stays in 0.85..1.12 and never moves
with gear, the human fallback with exactly one warning, and that the real
`grug_gear` catalog indexes to 24 cloth + 24 metal pieces across the four slots.

The boot additionally spawned a guard of each faction, a bandit, a mirefolk and
two vendors through a temporary probe mod (archived, not merged:
`tools/wp13/evidence/20260914-character-visuals/probe/`) and logged the textures
the engine actually holds — the composed strings, with the guards at bracket 4
for the level of the probe position and their swords in hand.

## Behaviour notes worth knowing

- A mob carrying `_grug_visual` runs `grug_mobs.ensure_init` in
  `after_activate` instead of on its first `do_custom` tick, so a spec can read
  the mob's own level; the level sources are pure classification math and the
  health/armor it derives are set before anything reads them, so the earlier
  call changes nothing but the moment.
- `compose` returns the cache entry itself, and that table's `textures` list is
  aliased into `entity.base_texture`, `entity._grug_base_texture` and
  `player_api`'s stored texture list. Read-only by convention; no mutator of a
  composed result exists today, and the engine copies the list into the object
  properties rather than keeping it.
- The wield entity's orphan poll is one per-step callback per **armed**
  character — the same shape as mobs_redo's own per-entity step work; an
  unarmed character has no entity and therefore no callback.
- If `core.add_entity` fails at activation (no position yet, an entity budget),
  the weapon is simply not shown and is not retried until the block reloads or
  the character's weapon changes.

## Deviations from the contract, and why

1. **Media licence is CC0 1.0, not CC BY-SA 4.0.** The brief said "CC BY-SA 4.0
   like the rest of the project's own art, check what neighbouring mods use" —
   the check says otherwise: `grug_gear`, `grug_mobs`, `grug_inventory` and
   `grug_decor` all license their own generated art CC0 1.0. One project-wide
   answer beats a second one here. Reversible with a one-line edit if the user
   rules the other way.
2. **`armor.chest`, with `armor.torso` accepted.** The contract's §2 signature
   says `torso`; every slot, group, list and item name in the game says `chest`.
   Both work; the canonical key is `chest`.
3. **No stature for humanoid mobs.** The contract's stature bullet is applied to
   players only. mobs_redo owns a mob's scale through `base_size`, which it
   re-applies from staticdata on every activation and which `mobs:scale_mob`
   changes *relatively* for the elite/rare tiers — a `visual_size` write here
   would be silently reverted on the next reload and would desync the tier
   factor. The mirefolk's deliberate 0.85 and an elite guard's ×1.6 stay with
   the mob engine.
4. **Spec fields beyond `{race, armor, weapon}`** (`skin`, `armor_line`,
   `bracket`, `level`, `weapon_family`). `armor_line` and `bracket` are in the
   contract's own mob-field shape; the other three exist because an NPC's
   bracket follows its runtime level and because the mirefolk are not a race.
5. **`grug_gear.BRACKET_TINT` is now published** (it was a local). The contract
   asks for "the same bracket colours the item images use", and a copy would
   drift.
6. **`grug_classes.register_on_race_chosen` is new**, mirroring the existing
   `register_on_class_chosen`. The contract lists "race chosen" as a trigger and
   there was no hook for it.
7. **`grug_mobs.set_base_texture` is new** (`levels.lua`). The composed skin has
   to become the pristine texture list that `apply_tier_visuals` colorizes for
   an elite; writing `base_texture` from outside would either lose the gold tint
   or double-colorize on the next tier change.

## Playtest round 1 (2026-09-15)

Two defects from the user's GUI playtest, on `main` at `70702d2`. Evidence:
`tools/wp13/evidence/20260915-playtest-round-1/`.

### 1. The sword was held backwards

**What the user saw** (photograph of a guard from behind): the sword's TIP in
the middle of the hand, the HILT sticking straight out backwards. In third
person the player's own weapon looked the same way.

**Cause.** The 2026-09-14 numbers were the "Open points" entry below: eyeballed,
never seen in a client. They are `pos = {0, 5.5, -1.5}`, `rot = {-90, 180, 0}`,
and the entity's origin is the **centre** of the extruded sprite, so a z of
-1.5 put that centre 1.5 units *behind* the fist. The blade direction was
already right; the position and the roll were not.

**The derivation** now lives in a new pure-Lua file,
`mods/PLAYER/grug_visuals/wield_geometry.lua`, which is the single place the
numbers exist — `apply.lua` only reads `grug_visuals.WIELD`. It rests on five
measurements, none of them guessed:

| Fact | Where it is read |
| --- | --- |
| `Arm_Right`'s rest frame is `Ry(180)·Rx(180) = diag(-1, -1, 1)`, so bone +x/+y/+z are model -x/-y/+z | the `NODE` chunks of `character.b3d` (Body at (0, 6.3, 0) turned 180° about y, Arm_Right at (-3.15, 5.25, 0) turned 180° about x). Both factors are half turns and therefore symmetric matrices, so Irrlicht's transposed quaternion convention cannot change the answer |
| the shoulder joint is at model (3.15, 11.55, 0) and the arm reaches 5.25 units past it; the fist is the bottom 2.1 units, centre at bone y **4.2** | the mesh vertices weighted to `Arm_Right` (model y 6.3..12.6) and the 12 skin pixels that cover them |
| **model +z is forward** | the head quad whose UV rectangle is the skin's face (pixels 8..16 × 8..16 — the rectangle that carries the two eye pixels) has the geometric normal +z; the back-of-head quad (24..32) has -z |
| a `wielditem`'s image runs u along the entity's local +x and v along local **-y**, on an edge of `40 · visual_size / 2` model units | `createExtrusionMesh`, `src/client/wieldmesh.cpp:43`, and the `visual_size / 2` scale in `content_cao.cpp:756` |
| every grug_gear weapon sprite is handle-at-the-bottom, long axis vertical; row 13 of 16 is the middle of the sword's and the greataxe's grip | the four PNGs (sword grip rows 11–15 with the crossguard at 9–10, greataxe shaft 11–15, dagger grip 10–13, staff shaft to 15) |

`set_attach`'s rotation is Irrlicht Euler degrees applied as `Rz·Ry·Rx`,
right-handed about the **bone's** axes (`matrix4::setRotationRadians`, used by
`GenericCAO::updateAttachments`). Asking for blade = forward tilted `t` up,
guard = down-forward and flat = sideways gives the unique triple
`x = 90, y = -t, z = 90`; the position then follows from "the grip centre sits
in the fist" and is not free. With `t = 15`:

```
pos = {x = 0, y = 3.844, z = 1.328}    rot = {x = 90, y = -15, z = 90}
size = {x = 0.22, y = 0.22}            (unchanged)
```

**The printed check**, `tools/wp13/wield_transform_kat.lua` — it parses the real
`.b3d` itself (plain-5.1 byte arithmetic; `string.unpack` is engine-injected and
a standalone interpreter has none), loads the real `wield_geometry.lua`, and then
re-implements the engine's attachment maths independently:

```
wp13_wield_bone      Arm_Right  3.150,11.550,0.000  x->-1,0,0  y->0,-1,0  z->0,0,1
wp13_wield_arm       model_y 6.300..12.600  reach 5.250  fist_centre_bone_y 4.200
wp13_wield_face      uv 8..16x8..16  normal 0.000,0.000,1.000
wp13_wield_hanging   hilt-hand 0,-0.214,-0.797  grip-hand 0,0,0  tip-hand 0,0.925,3.453   blade 0,0.259,0.966  flat -1,0,0
wp13_wield_raised90  hilt-hand 0,-0.797, 0.214  grip-hand 0,0,0  tip-hand 0,3.453,-0.925  blade 0,0.966,-0.259 flat -1,0,0
```

and, as its **negative control**, the same maths on the numbers the user
photographed:

```
wp13_wield_old_hanging  hilt-hand 0,-1.300,-3.700  tip-hand 0,-1.300,0.700  flat 0,-1,0
```

— the hilt 3.7 units behind the fist with the tip sitting in it, which is the
picture. A fixture that cannot reproduce the reported defect has not modelled
the engine, so that row is what makes the fix trustworthy without a client.

The arm-raised case is not arbitrary either: both the walk and the mine
animation move this bone about its own local x (`character.b3d` `KEYS` for
`Arm_Right`: the walk frames sit ±32° off the hanging rest pose, mine frame 191
sits 109° off it), and a **positive** rotation about bone-local x raises the arm
forward. The grip stays in the fist through the whole swing because it is the
bone's frame that moves.

### 2. Right-click with a skill in hand did not open doors

**What the user saw**: with an empty hand or a normal item a door opens; with an
ability item wielded nothing happens.

**Cause, and it is not the one the report assumed.** No ability item has ever had
an `on_place` or an `on_secondary_use`, and casting lives on `on_use`/LMB — so
right-click never cast and nothing "consumed" it. It is the swing items' own
`pointabilities`: `doors:door_wood_*` carries `oddly_breakable_by_hand`, which
Strike, Mighty Blow and Hamstring declare `"blocking"` to stop the client
retargeting the ground after a mob dies. A blocking node makes the ray report
POINTEDTHING_NOTHING (`src/environment.cpp:276`), right-click on nothing sends
INTERACT_ACTIVATE (`src/client/game.cpp:2803`), and that lands in
`on_secondary_use` — never in `on_place`, where builtin's own
`on_rightclick` pass-through sits. The wooden trapdoor, every wooden fence gate,
chests and signs are in the same group; a **steel** door is only `cracky` and
therefore worked all along, which is why this reads as random.

**Why not simply un-block the interactive nodes**: the swing items have empty
groupcaps and the engine still falls back to the registered hand, so a pointable
door would be *chopped* by held LMB with Strike selected. The pointabilities stay
exactly as they are.

**The rule** (`docs/design/classes.md` §2b, "Right-click with a skill in hand
opens the door"), implemented on both kinds of ability item:

- `on_place` — the node the client did point at: hand the click to its
  `on_rightclick`, unless sneaking. This is builtin's own rule
  (`builtin/game/item.lua:337-347`) written out, so it is one readable thing
  instead of an inherited default and a fixture can drive it.
- `on_secondary_use` — the client pointed at nothing, which includes the
  blocking case: one server ray from `grug_core.combat_eye_pos` along the look
  direction, **first node only** (reaching past the node in front of the player
  would be an exploit), then the same pass-through.
- **Sneak keeps the skill.** Sneak + right-click does what right-click did
  before, so a skill bound to it later still works while pointing at a door.
- **Hand reach, not skill range.** The ray is capped at 4 m, the engine's
  default item range (`lua_api.md:10455`) and exactly what every swing skill
  declares — a 20 m Fireball must not flip a lever across a courtyard.
- The cast path is untouched: `try_cast` is unreachable from either callback.

`tools/wp13/ability_rightclick_kat.lua` loads the **real**
`grug_abilities/init.lua` under a stub engine (`setfenv`, with `dofile` stubbed
so `kits.lua` is not pulled in), registers one swing and one cast ability through
the real `register_ability`, and drives the closures the engine would get through
nine cases each. The door definition is the **real** `doors:door_wood_a` from
`tools/wp13/stub_registry.lua` with only its `on_rightclick` swapped for a
recorder, and the stub ray hands its hits over **far-to-near** on purpose,
because the engine's Raycast order is not line-of-sight order either:

| case | on_rightclick | casts |
| --- | --- | --- |
| `on_place` door | 1 | 0 |
| `on_place` plain node | 0 | 0 |
| `on_place` door, sneaking | 0 | 0 |
| `on_secondary_use` door in front | 1 | 0 |
| `on_secondary_use` plain node in front | 0 | 0 |
| `on_secondary_use` door, sneaking | 0 | 0 |
| `on_secondary_use` nothing in front | 0 | 0 |
| `on_secondary_use` door at 6 m | 0 | 0 |
| `on_secondary_use` door behind a wall | 0 | 0 |
| `on_use` (LMB) on a plain node, cast item | — | 1 |

`wp13_rmb_blocking` is the mechanism row and the second negative control: it
matches the real door's real groups against the real pointabilities table and
names `oddly_breakable_by_hand`. Deleting the two `tool_def` lines makes the
fixture report `wp13_rmb_result FAIL 78`.

### Verification

| Gate | Result |
| --- | --- |
| `wield_transform_kat`, `ability_rightclick_kat`, `character_visuals_kat`, `visuals_order_kat` under LuaJIT and `tools/bin/lua51` | all `PASS 0`, byte-identical (`sha256 94034472…341f7a48`) |
| `luac51 -p` on every changed file and tree-wide; `SETGLOBAL` | pass; one `SETGLOBAL` per mod table, none in the new files |
| the five plain-5.1 sweeps, scoped and tree-wide | zero hits outside prose (the new ones are two `core::Transform::buildMatrix` C++ references) |
| `tools/check_fresh_server.py` | PASS |
| one headless boot, `tools/luanti_headless.sh 180` | PASS, 0 ERROR/ModError, 57 WARNING — every one pre-existing (mod-storage backend advice, and the vendored `stairs` metal-block fuel rows) |

### Still open after this round

- **The pose is derived, not seen.** Everything above is geometry; nobody in
  this lane can open a client. `TILT_UP` (15°) is the one taste value, and it is
  one constant in `wield_geometry.lua`.
- **The sprite is 4.4 model units long** (0.44 node) on a 17-unit character,
  i.e. shorter than the 6.3-unit arm. That is `visual_size` 0.22 unchanged from
  the first version, and it is a *length* as much as a size: raising it moves
  the position too, which is why `wield_geometry.lua` computes the position from
  it. If the sword reads as a dagger in the client, that constant is the fix.
- `classes.md` §2c still ends with "the weapon is **not** shown on the character
  model in third person" — WP13 shipped exactly that the day before, so the
  sentence is stale. Left for the owner of §2c rather than edited from this lane.

## Open points

- **The hand attachment is unverified.** ~~`WIELD_POS`/`WIELD_ROT` in
  `apply.lua` were authored against the mesh's own bone tree (`Arm_Right` sits
  at the shoulder, 6.3 units above the hand, with a bone rotation that flips y
  and z) but nobody in this lane can open a client. Expect one round of
  eyeballing; it is five numbers in one place.~~ **Closed by playtest round 1
  above**, which is the round of eyeballing this predicted: the numbers moved to
  `wield_geometry.lua`, are now derived rather than estimated, and carry a
  printed check with the old version as its negative control.
- **The art is a first version.** Generated by
  `tools/wp13/gen_character_visuals.py` (palettes + box painting, seed
  20260914), so iteration is a palette edit and a re-run, not a repaint. Review
  composites: `tools/wp13/evidence/20260914-character-visuals/renders/`.
- **Offhand is not drawn** (contract: "offhand later"). The equipment hook
  already treats `grug_offhand` as appearance-irrelevant; that entry is the one
  line to delete when shields arrive.
- **The stature is written on every apply**, not only when the composed key
  changes: `mobs/mount.lua`'s `force_detach` resets `visual_size` to `{1, 1}`
  on every dismount (and on leaveplayer), so a remembered scale would silently
  become human-sized for the rest of the session once mounts ship. The texture
  list — the expensive write — stays token-guarded.
- **The two bandit skins and the two guard skins in `grug_mobs/textures` are now
  the fallback path only** — what a build without `grug_visuals` shows. They are
  kept deliberately, because "inert when the mod is absent" is a contract
  requirement, not because anything migrates.
- **Leather borrows the cloth overlay.** `grug_gear` registers no leather piece
  (the Rogue is Phase 2); `grug_visuals.LINE_ART` is the single line to change.
