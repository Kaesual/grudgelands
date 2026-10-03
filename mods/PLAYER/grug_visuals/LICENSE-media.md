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

### Character look layers (Round 31)

Every humanoid of a race is drawn from these layers (round31-plan.md §2.1):
a white mask the engine colours with `^[multiply:<colour>` plus a detail layer
with the shading and the fixed-colour pixels (the technique of VoxeLibre's
`mcl_skins`; none of its art), the race's one dress in its body file, and the
royal tabard and crown of kings and their guards. The option tables and royal
colours that name these files are `looks.lua`.

| File | Author | License | Notes |
|------|--------|---------|-------|
| `grug_visuals_crown.png` | Grudgelands project | CC0 1.0 | generator, a king's gold crown on the hat layer, above the eyes (the Round 8 crown's colours) |
| `grug_visuals_tabard.png` | Grudgelands project | CC0 1.0 | generator, royal tabard detail: darker hem and a gold emblem |
| `grug_visuals_tabard_mask.png` | Grudgelands project | CC0 1.0 | generator, royal tabard panels front and back, white mask coloured with the race's royal cloth colour |
| `grug_visuals_tabard_trim_mask.png` | Grudgelands project | CC0 1.0 | generator, royal tabard trim band round the waist, white mask coloured with the race's royal trim colour |
| `grug_visuals_dwarf_body.png` | Grudgelands project | CC0 1.0 | generator, palette `dwarf`: face, skin shading and the race dress, drawn over the toned skin mask |
| `grug_visuals_dwarf_feature_braided_mask.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `braided` of the dwarf, white mask coloured in the engine |
| `grug_visuals_dwarf_feature_braided.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `braided` of the dwarf: shading and fixed-colour detail |
| `grug_visuals_dwarf_feature_forked_mask.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `forked` of the dwarf, white mask coloured in the engine |
| `grug_visuals_dwarf_feature_forked.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `forked` of the dwarf: shading and fixed-colour detail |
| `grug_visuals_dwarf_feature_full_mask.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `full` of the dwarf, white mask coloured in the engine |
| `grug_visuals_dwarf_feature_full.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `full` of the dwarf: shading and fixed-colour detail |
| `grug_visuals_dwarf_feature_short_mask.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `short` of the dwarf, white mask coloured in the engine |
| `grug_visuals_dwarf_feature_short.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `short` of the dwarf: shading and fixed-colour detail |
| `grug_visuals_dwarf_hair_braid_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `braid` of the dwarf, white mask coloured in the engine |
| `grug_visuals_dwarf_hair_braid.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `braid` of the dwarf: shading and fixed-colour detail |
| `grug_visuals_dwarf_hair_crown_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `crown` of the dwarf, white mask coloured in the engine |
| `grug_visuals_dwarf_hair_crown.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `crown` of the dwarf: shading and fixed-colour detail |
| `grug_visuals_dwarf_hair_full_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `full` of the dwarf, white mask coloured in the engine |
| `grug_visuals_dwarf_hair_full.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `full` of the dwarf: shading and fixed-colour detail |
| `grug_visuals_elf_body.png` | Grudgelands project | CC0 1.0 | generator, palette `elf`: face, skin shading and the race dress, drawn over the toned skin mask |
| `grug_visuals_elf_feature_marked_mask.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `marked` of the elf, white mask coloured in the engine |
| `grug_visuals_elf_feature_marked.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `marked` of the elf: shading and fixed-colour detail |
| `grug_visuals_elf_feature_pointed_mask.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `pointed` of the elf, white mask coloured in the engine |
| `grug_visuals_elf_feature_pointed.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `pointed` of the elf: shading and fixed-colour detail |
| `grug_visuals_elf_feature_swept_mask.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `swept` of the elf, white mask coloured in the engine |
| `grug_visuals_elf_feature_swept.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `swept` of the elf: shading and fixed-colour detail |
| `grug_visuals_elf_hair_braid_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `braid` of the elf, white mask coloured in the engine |
| `grug_visuals_elf_hair_braid.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `braid` of the elf: shading and fixed-colour detail |
| `grug_visuals_elf_hair_long_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `long` of the elf, white mask coloured in the engine |
| `grug_visuals_elf_hair_long.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `long` of the elf: shading and fixed-colour detail |
| `grug_visuals_elf_hair_short_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `short` of the elf, white mask coloured in the engine |
| `grug_visuals_elf_hair_short.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `short` of the elf: shading and fixed-colour detail |
| `grug_visuals_elf_hair_tail_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `tail` of the elf, white mask coloured in the engine |
| `grug_visuals_elf_hair_tail.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `tail` of the elf: shading and fixed-colour detail |
| `grug_visuals_eyes_mask.png` | Grudgelands project | CC0 1.0 | generator, white iris mask, coloured with the chosen eye colour |
| `grug_visuals_eyes_undead_mask.png` | Grudgelands project | CC0 1.0 | generator, white glow mask of the undead eyes, coloured with the chosen glow colour |
| `grug_visuals_helmet_window.png` | Grudgelands project | CC0 1.0 | generator, `[mask` cutting the shared face window (hat front, columns 1-6, rows 3-7) out of every helmet overlay |
| `grug_visuals_human_body.png` | Grudgelands project | CC0 1.0 | generator, palette `human`: face, skin shading and the race dress, drawn over the toned skin mask |
| `grug_visuals_human_feature_beard_mask.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `beard` of the human, white mask coloured in the engine |
| `grug_visuals_human_feature_beard.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `beard` of the human: shading and fixed-colour detail |
| `grug_visuals_human_feature_moustache_mask.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `moustache` of the human, white mask coloured in the engine |
| `grug_visuals_human_feature_moustache.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `moustache` of the human: shading and fixed-colour detail |
| `grug_visuals_human_feature_stubble_mask.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `stubble` of the human, white mask coloured in the engine |
| `grug_visuals_human_feature_stubble.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `stubble` of the human: shading and fixed-colour detail |
| `grug_visuals_human_hair_crop_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `crop` of the human, white mask coloured in the engine |
| `grug_visuals_human_hair_crop.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `crop` of the human: shading and fixed-colour detail |
| `grug_visuals_human_hair_long_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `long` of the human, white mask coloured in the engine |
| `grug_visuals_human_hair_long.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `long` of the human: shading and fixed-colour detail |
| `grug_visuals_human_hair_swept_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `swept` of the human, white mask coloured in the engine |
| `grug_visuals_human_hair_swept.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `swept` of the human: shading and fixed-colour detail |
| `grug_visuals_human_hair_tail_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `tail` of the human, white mask coloured in the engine |
| `grug_visuals_human_hair_tail.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `tail` of the human: shading and fixed-colour detail |
| `grug_visuals_orc_body.png` | Grudgelands project | CC0 1.0 | generator, palette `orc`: face, skin shading and the race dress, drawn over the toned skin mask |
| `grug_visuals_orc_feature_tusks_broken.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `tusks_broken` of the orc: shading and fixed-colour detail |
| `grug_visuals_orc_feature_tusks_large.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `tusks_large` of the orc: shading and fixed-colour detail |
| `grug_visuals_orc_feature_tusks_small.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `tusks_small` of the orc: shading and fixed-colour detail |
| `grug_visuals_orc_feature_warpaint.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `warpaint` of the orc: shading and fixed-colour detail |
| `grug_visuals_orc_hair_braids_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `braids` of the orc, white mask coloured in the engine |
| `grug_visuals_orc_hair_braids.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `braids` of the orc: shading and fixed-colour detail |
| `grug_visuals_orc_hair_mohawk_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `mohawk` of the orc, white mask coloured in the engine |
| `grug_visuals_orc_hair_mohawk.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `mohawk` of the orc: shading and fixed-colour detail |
| `grug_visuals_orc_hair_shaved_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `shaved` of the orc, white mask coloured in the engine |
| `grug_visuals_orc_hair_shaved.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `shaved` of the orc: shading and fixed-colour detail |
| `grug_visuals_orc_hair_topknot_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `topknot` of the orc, white mask coloured in the engine |
| `grug_visuals_orc_hair_topknot.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `topknot` of the orc: shading and fixed-colour detail |
| `grug_visuals_skin_mask.png` | Grudgelands project | CC0 1.0 | generator, white mask of the whole base body, coloured with the chosen skin tone |
| `grug_visuals_troll_body.png` | Grudgelands project | CC0 1.0 | generator, palette `troll`: face, skin shading and the race dress, drawn over the toned skin mask |
| `grug_visuals_troll_feature_tusks_huge.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `tusks_huge` of the troll: shading and fixed-colour detail |
| `grug_visuals_troll_feature_tusks_large.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `tusks_large` of the troll: shading and fixed-colour detail |
| `grug_visuals_troll_feature_tusks_small.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `tusks_small` of the troll: shading and fixed-colour detail |
| `grug_visuals_troll_hair_crest_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `crest` of the troll, white mask coloured in the engine |
| `grug_visuals_troll_hair_crest.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `crest` of the troll: shading and fixed-colour detail |
| `grug_visuals_troll_hair_mane_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `mane` of the troll, white mask coloured in the engine |
| `grug_visuals_troll_hair_mane.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `mane` of the troll: shading and fixed-colour detail |
| `grug_visuals_troll_hair_swept_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `swept` of the troll, white mask coloured in the engine |
| `grug_visuals_troll_hair_swept.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `swept` of the troll: shading and fixed-colour detail |
| `grug_visuals_troll_hair_twintails_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `twintails` of the troll, white mask coloured in the engine |
| `grug_visuals_troll_hair_twintails.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `twintails` of the troll: shading and fixed-colour detail |
| `grug_visuals_undead_body.png` | Grudgelands project | CC0 1.0 | generator, palette `undead`: face, skin shading and the race dress, drawn over the toned skin mask |
| `grug_visuals_undead_feature_jaw.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `jaw` of the undead: shading and fixed-colour detail |
| `grug_visuals_undead_feature_nose.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `nose` of the undead: shading and fixed-colour detail |
| `grug_visuals_undead_feature_stitches.png` | Grudgelands project | CC0 1.0 | generator, lower-face feature `stitches` of the undead: shading and fixed-colour detail |
| `grug_visuals_undead_hair_bald_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `bald` of the undead, white mask coloured in the engine |
| `grug_visuals_undead_hair_bald.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `bald` of the undead: shading and fixed-colour detail |
| `grug_visuals_undead_hair_patchy_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `patchy` of the undead, white mask coloured in the engine |
| `grug_visuals_undead_hair_patchy.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `patchy` of the undead: shading and fixed-colour detail |
| `grug_visuals_undead_hair_stringy_mask.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `stringy` of the undead, white mask coloured in the engine |
| `grug_visuals_undead_hair_stringy.png` | Grudgelands project | CC0 1.0 | generator, hairstyle `stringy` of the undead: shading and fixed-colour detail |

### Armor overlays

The 72 worn overlays are separate 64x32 UV assets, generated by
`tools/r10_art/build_armor_assets.sh` from the same pinned source families and
licenses recorded in `grug_gear/LICENSE-media.md`: VoxeLibre metal/leather bases (XSSheep/Pixel Perfection chain, CC BY-SA 4.0), armor trims (Aeonix_Aeon, CC BY 4.0), plus Lord of the Test cloth (Amaz/Flipsels, CC BY-SA 3.0). Each tier has a baked source
silhouette/material treatment; no runtime tint supplies tier identity. The
proof in `docs/research/r10-visuals/worn-model-sheet.png` renders these UVs on
the shipped animated `character.b3d` from front/back/side and at all six race
statures.

Round 11 applies `^[hsl:0:-90:5` to the existing Silversteel worn overlays,
matching the neutral-bright inventory and weapon palette while retaining the
accepted diamond-derived silhouette and shading. This is a material correction,
not the source of tier identity; all six silhouettes remain their authored set.

## Media this mod uses but does not ship

| File | Lives in | Used for |
|------|----------|----------|
| `character.b3d` | `mods/BASE/player_api/models` | the mesh every composed skin is painted for; referenced by bare name (Luanti's media namespace is flat) and never copied |
| `grug_mobs_mirefolk.png` | `mods/ENTITIES/grug_mobs/textures` | the mirefolk name their own skin as a composition base instead of a race (CC0 1.0, `grug_mobs/LICENSE-media.md` §6) |
| every `grug_gear_item_*.png` | `mods/ITEMS/grug_gear/textures` | the visible weapon is an attached `visual = "wielditem"` entity, which renders the item's own inventory image — no texture of this mod is involved |

## Round 31 enchant masks — licence of their source

Each `grug_visuals_<line>_<slot>_<grade>_ench.png` (72 files) is a two-frame
greyscale mask that `tools/r31_b/gen_enchant_masks.py` derives
deterministically from the worn overlay of the same name (top frame group A,
bottom frame group B, with the overlay's own shading). A mask carries its
source's shapes and shading, so it keeps the **overlay's licence and
attribution** (see "Armor overlays" above and `grug_gear/LICENSE-media.md`):
metal and leather CC BY-SA 4.0 bases with CC BY 4.0 trims, cloth CC BY-SA 3.0.
The modification is "pixel-group mask derived by the generator".
