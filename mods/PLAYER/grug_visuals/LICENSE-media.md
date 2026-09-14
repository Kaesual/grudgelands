# Media Origin & Licenses (grug_visuals)

## Own pixel art — CC0 1.0

Original 64×32 art of this project, **not** derived from any vendored or
third-party asset — in particular **not** from `player_api`'s `character.png`
(CC BY-SA 3.0, MirceaKitsune/Jordach et al.), which was read only to confirm
the UV layout and is not a source of a single pixel here.

Every file is authored as palettes plus box-painting code in
**`tools/wp13/gen_character_visuals.py`** and generated deterministically
(seed 20260914) — re-running

```sh
python3 tools/wp13/gen_character_visuals.py
```

reproduces every PNG byte for byte, so this table names a generator rather than
a hand-edited file. That is the same discipline `grug_gear` and the mirefolk
skin already use.

**License: CC0 1.0 Universal**
(<https://creativecommons.org/publicdomain/zero/1.0/>).

CC0 rather than CC BY-SA 4.0 deliberately: every other mod in this tree that
ships its own generated art (`grug_gear`, `grug_mobs`, `grug_inventory`,
`grug_decor`) licenses it CC0 1.0, and one project-wide answer to "what licence
is our own art" is worth more than a second one here.

### UV layout

The classic 64×32 Minecraft-1.7 skin layout, which is what
`mods/BASE/player_api/models/character.b3d` uses. Head `(0,0)–(31,15)`, hat/hair
overlay `(32,0)–(63,15)`, right leg `(0,16)–(15,31)`, torso `(16,16)–(39,31)`,
right arm `(40,16)–(55,31)`. Left limbs reuse the right UVs. Verified twice for
this increment: against the opaque regions of `character.png`, and by parsing
the mesh's own bone tree (`Body / Head / Arm_Left / Arm_Right / Leg_Right /
Leg_Left`).

### Race skins

Full-body base layers. Face, hair mass and dress differ per race so a character
is readable before the stature scale is applied.

| File | Author | License | Notes |
|------|--------|---------|-------|
| `grug_visuals_skin_human.png` | Grudgelands project | CC0 1.0 | generator, palette `human`: tan skin, brown crop, blue-grey tunic, leather boots |
| `grug_visuals_skin_dwarf.png` | Grudgelands project | CC0 1.0 | generator, palette `dwarf`: ruddy skin, ginger beard painted into the hat layer, green tunic, brass belt |
| `grug_visuals_skin_elf.png` | Grudgelands project | CC0 1.0 | generator, palette `elf`: ivory skin, long pale hair over the whole hat layer, pointed ears, silver-green dress |
| `grug_visuals_skin_undead.png` | Grudgelands project | CC0 1.0 | generator, palette `undead`: grey-green pallor, sunken sockets with a sickly glow colour, ribs showing through a torn violet wrap, patchy scalp |
| `grug_visuals_skin_orc.png` | Grudgelands project | CC0 1.0 | generator, palette `orc`: green skin, tusks, black topknot, bare chest under a leather harness, bone armbands |
| `grug_visuals_skin_troll.png` | Grudgelands project | CC0 1.0 | generator, palette `troll`: blue-grey hide, tusks, dark blue mane, ochre wraps |

### Armor overlays

Transparent except where the piece sits. Drawn in the **bracket-6 ("Grand")**
colour, because `^[multiply:#ffffff` is a no-op: the six brackets are one
`^[multiply` away from the same PNG, exactly the way `grug_gear` tints its item
images, and the tint values come from `grug_gear.BRACKET_TINT` rather than a
copy.

| File | Author | License | Notes |
|------|--------|---------|-------|
| `grug_visuals_metal_head.png` | Grudgelands project | CC0 1.0 | generator, line `metal`: helm on the hat layer — brow band, nasal bar, open face, brass trim |
| `grug_visuals_metal_chest.png` | Grudgelands project | CC0 1.0 | generator, line `metal`: breastplate with a centre ridge and waist band, pauldrons on the upper arms |
| `grug_visuals_metal_legs.png` | Grudgelands project | CC0 1.0 | generator, line `metal`: greaves with a knee plate, a shade darker than the chest so the pieces read apart under one tint |
| `grug_visuals_metal_feet.png` | Grudgelands project | CC0 1.0 | generator, line `metal`: sabatons plus the sole face |
| `grug_visuals_cloth_head.png` | Grudgelands project | CC0 1.0 | generator, line `cloth`: cowl on the hat layer — brim over the brow, open face, longer at the back |
| `grug_visuals_cloth_chest.png` | Grudgelands project | CC0 1.0 | generator, line `cloth`: robe with a yoke, girdle and long sleeves |
| `grug_visuals_cloth_legs.png` | Grudgelands project | CC0 1.0 | generator, line `cloth`: leggings |
| `grug_visuals_cloth_feet.png` | Grudgelands project | CC0 1.0 | generator, line `cloth`: slippers plus the sole face |

## Media this mod uses but does not ship

| File | Lives in | Used for |
|------|----------|----------|
| `character.b3d` | `mods/BASE/player_api/models` | the mesh every composed skin is painted for; referenced by bare name (Luanti's media namespace is flat) and never copied |
| `grug_mobs_mirefolk.png` | `mods/ENTITIES/grug_mobs/textures` | the mirefolk name their own skin as a composition base instead of a race (CC0 1.0, `grug_mobs/LICENSE-media.md` §6) |
| every `grug_gear_item_*.png` | `mods/ITEMS/grug_gear/textures` | the visible weapon is an attached `visual = "wielditem"` entity, which renders the item's own inventory image — no texture of this mod is involved |
