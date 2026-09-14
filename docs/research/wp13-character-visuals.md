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
| join | `mods/PLAYER/grug_visuals/apply.lua:217` |
| respawn | `mods/PLAYER/grug_visuals/apply.lua:233` |
| race chosen | `mods/PLAYER/grug_visuals/apply.lua:239` (new `grug_classes.register_on_race_chosen`, `mods/PLAYER/grug_classes/init.lua:104`) |
| class changed | `mods/PLAYER/grug_visuals/apply.lua:243` |
| equipment changed | `mods/PLAYER/grug_visuals/apply.lua:257` (skips offhand and the two trinkets; registered **before** grug_inventory's page refresh — see "Ordering") |
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

## Open points

- **The hand attachment is unverified.** `WIELD_POS`/`WIELD_ROT` in
  `apply.lua` were authored against the mesh's own bone tree (`Arm_Right` sits
  at the shoulder, 6.3 units above the hand, with a bone rotation that flips y
  and z) but nobody in this lane can open a client. Expect one round of
  eyeballing; it is five numbers in one place.
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
