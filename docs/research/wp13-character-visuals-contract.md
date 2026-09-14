# WP13: character visuals — contract

Status: decided by the coordinator on 2026-09-14 (Claude Fable) as the shared
seam between the visuals lane and the NPC lane. Player and humanoid mob
appearance is composed by one function so the two never fight over the
`character.b3d` texture list.

## 1. Scope

- Race base skins (skin tone, hair, dress) for the six races on the
  engine/MTG `character.b3d` model that players, guards, bandits, skeleton
  raiders and vendors already use.
- Stature per race as a **visual-only** scale: `visual_size` in the range
  0.85..1.12, the collision box and eye height unchanged, so every race walks
  through the two-node doors of its own houses. Dwarves and orcs broader and
  lower, elves and trolls taller, humans 1.0.
- Visible armor: one transparent overlay texture per armor line × slot
  (`grug_gear`: two lines, four slots), tinted per bracket with the same
  bracket colours the item images use.
- Visible weapon: one attached `wielditem` entity on the right hand bone,
  updated when the equipped weapon changes; offhand later.

## 2. Interface

New mod `mods/PLAYER/grug_visuals` (depends on `player_api`, `grug_classes`,
`grug_gear`; optional `grug_inventory`):

```lua
grug_visuals.compose{race = "dwarf",
	armor = {head = itemname_or_nil, torso = ..., legs = ..., feet = ...},
	weapon = itemname_or_nil}
-- -> {textures = {...}, visual_size = {x=,y=,z=}, weapon = itemname_or_nil}
```

Pure, deterministic, cached by its key string. Unknown race falls back to
`human` with a warning once.

- **Players**: `grug_visuals.apply(player)` reads race (`grug_classes`),
  armor and weapon (`grug_core.get_equipped_*` accessors), then calls
  `player_api.set_textures` and `set_properties{visual_size}` and syncs the
  wield entity. Triggers: join after the model is set, race chosen, class
  changed, equipment changed (`grug_inventory` hooks; polling only as a
  throttled fallback).
- **Mobs**: a mob definition field
  `_grug_visual = {race = "orc", armor = {...} or armor_line = "metal",
  bracket = 3, weapon = itemname}` that `grug_mobs` resolves through
  `grug_visuals.compose` when the entity activates (`on_spawn` /
  `after_activate`), including the wield entity. Mobs without the field keep
  their textures. Until the visuals lane merges, the NPC lane sets the field
  and keeps the guard skin; the field is inert then.

## 3. Assets and rules

- Base skins: `grug_visuals_skin_<race>.png` in the `character.png` layout
  shipped by `player_api`; overlays `grug_visuals_<line>_<slot>.png`.
  First version is pixel art by the lane; LICENSE-media.md per file.
- Composition uses texture modifiers only (`^`, `^[colorize`,
  `^[multiply`); no per-frame updates, one attached entity per character.
- Web target: nothing here is heavier than what `grug_abilities` skins do.
