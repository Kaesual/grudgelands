# Media Origin & Licenses (grug_materials)

**This mod ships no media files of its own.** It has no `textures/` or
`sounds/` directory. Its registrations either use vendored minetest_game media
unchanged, generate a tinted derivative at runtime with Luanti texture
modifiers, or copy a vendored node definition under a canonical name.

This is therefore an attribution inventory for runtime registrations, not a
file inventory.

## Source and license

All originals live in `mods/BASE/default`, vendored from
minetest_game <https://github.com/luanti-org/minetest_game> at commit
`b5243f3`; see [VENDOR.md](../../../VENDOR.md).

The texture originals referenced in the tables are **CC BY-SA 3.0 Unported**;
the runtime derivatives remain under that license. License text:
<http://creativecommons.org/licenses/by-sa/3.0/>.

The copied node definitions also retain references to minetest_game's sound
set. That set is covered by the CC BY-SA 3.0, CC BY 3.0 and CC0 notices and
attributions in `mods/BASE/default/license.txt`; no sound is copied, modified
or relicensed here.

**Author/copyright:** © 2010–2023 the minetest_game contributors listed in
`mods/BASE/default/license.txt` (celeron55, Cisoun, VanessaE, Calinou,
PilzAdam, paramat, sofar, Gambit, TumeniNodes, et al.; minetest_game does not
attribute these media per file).

## 1. Rock strata

| Runtime node | Vendored original | Runtime modifier |
|---|---|---|
| `grug_materials:slate` | `default_stone.png` | `^[colorize:#4a5a6e:70` |
| `grug_materials:basalt` | `default_stone.png` | `^[colorize:#2a2a2e:90` |
| `grug_materials:granite` | `default_stone.png` | `^[colorize:#8a5a52:60` |
| `grug_materials:emberrock` | `default_stone.png` | `^[colorize:#7a2a10:90` |
| `grug_materials:abyssal_rock` | `default_stone.png` | `^[colorize:#241830:150` |

## 2. Natural resource nodes

Every tile keeps an unmodified `default_stone.png` background and applies the
listed colorizer only to the mineral overlay.

| Runtime node | Overlay original | Overlay modifier |
|---|---|---|
| `grug_materials:stone_with_quartz` | `default_mineral_diamond.png` | `^[colorize:#eaf6ff:120` |
| `grug_materials:stone_with_silver` | `default_mineral_iron.png` | `^[colorize:#e8edf2:200` |
| `grug_materials:stone_with_citrine` | `default_mineral_diamond.png` | `^[colorize:#d9a21b:190` |
| `grug_materials:stone_with_garnet` | `default_mineral_diamond.png` | `^[colorize:#9e1526:210` |
| `grug_materials:stone_with_jade` | `default_mineral_diamond.png` | `^[colorize:#3d9b65:190` |
| `grug_materials:stone_with_emberglass` | `default_mineral_mese.png` | `^[colorize:#ff7a2e:65` |
| `grug_materials:stone_with_diamond` | `default_mineral_diamond.png` | `^[colorize:#ffffff:20` |
| `grug_materials:stone_with_sapphire` | `default_mineral_diamond.png` | `^[colorize:#235ac7:190` |
| `grug_materials:stone_with_ruby` | `default_mineral_diamond.png` | `^[colorize:#c51d35:195` |
| `grug_materials:abyssal_crystal_ore` | `default_mineral_diamond.png` | `^[colorize:#3a1f6e:210` |

The five upstream natural ores retain their vendored textures under their
upstream IDs: `default:stone_with_coal`, `default:stone_with_copper`,
`default:stone_with_tin`, `default:stone_with_iron` and
`default:stone_with_gold`. WP43 changes their groups and descriptions, not
their media.

## 3. Raw, cut and resource-storage forms

`Cut` forms append `^[brighten` to the listed raw-item chain. Resource block
tiles use the raw-item chain without `^[brighten`.

| Material | Raw runtime item | Cut runtime item | Block runtime node | Vendored original and raw modifier |
|---|---|---|---|---|
| Quartz | `grug_materials:quartz` | `grug_materials:cut_quartz` | — | `default_diamond.png^[colorize:#eaf6ff:120` |
| Silver | `grug_materials:silver_lump` | — | — | `default_iron_lump.png^[colorize:#e8edf2:200` |
| Citrine | `grug_materials:rough_citrine` | `grug_materials:cut_citrine` | `grug_materials:citrine_block` | `default_diamond.png^[colorize:#d9a21b:190` |
| Garnet | `grug_materials:rough_garnet` | `grug_materials:cut_garnet` | `grug_materials:garnet_block` | `default_diamond.png^[colorize:#9e1526:210` |
| Jade | `grug_materials:rough_jade` | `grug_materials:cut_jade` | `grug_materials:jade_block` | `default_diamond.png^[colorize:#3d9b65:190` |
| Emberglass | `grug_materials:emberglass` | — | `grug_materials:emberglass_block` | `default_mese_crystal.png^[colorize:#ff7a2e:45` |
| Diamond | `grug_materials:rough_diamond` | `grug_materials:cut_diamond` | `grug_materials:diamond_block` | `default_diamond.png^[colorize:#ffffff:20` |
| Sapphire | `grug_materials:rough_sapphire` | `grug_materials:cut_sapphire` | `grug_materials:sapphire_block` | `default_diamond.png^[colorize:#235ac7:190` |
| Ruby | `grug_materials:rough_ruby` | `grug_materials:cut_ruby` | `grug_materials:ruby_block` | `default_diamond.png^[colorize:#c51d35:195` |
| Abyssal Crystal | `grug_materials:abyssal_crystal` | — | `grug_materials:abyssal_crystal_block` | `default_diamond.png^[colorize:#3a1f6e:210` |

`grug_materials:emberglass_shard` uses
`default_mese_crystal_fragment.png^[colorize:#ff7a2e:45`.

## 4. Processed bars and storage blocks

| Material | Bar runtime item | Block runtime node | Vendored originals and modifier |
|---|---|---|---|
| Copper | `grug_materials:copper_bar` | `grug_materials:copper_block` | unmodified `default_copper_ingot.png`, `default_copper_block.png` |
| Tin | `grug_materials:tin_bar` | `grug_materials:tin_block` | unmodified `default_tin_ingot.png`, `default_tin_block.png` |
| Bronze | `grug_materials:bronze_bar` | `grug_materials:bronze_block` | unmodified `default_bronze_ingot.png`, `default_bronze_block.png` |
| Iron | `grug_materials:iron_bar` | `grug_materials:iron_block` | unmodified `default_steel_ingot.png`, `default_steel_block.png` |
| Steel | `grug_materials:steel_bar` | `grug_materials:steel_block` | default Steel images `^[colorize:#34404a:75` |
| Silver | `grug_materials:silver_bar` | `grug_materials:silver_block` | default Tin images `^[colorize:#f4f6fa:90` |
| Silversteel | `grug_materials:silversteel_bar` | `grug_materials:silversteel_block` | default Steel images `^[colorize:#b7c9df:95` |
| Embersteel | `grug_materials:embersteel_bar` | `grug_materials:embersteel_block` | default Steel images `^[colorize:#b94b24:110` |
| Abyssal Steel | `grug_materials:abyssal_steel_bar` | `grug_materials:abyssal_steel_block` | default Steel images `^[colorize:#3a245d:135` |
| Gold | `grug_materials:gold_bar` | `grug_materials:gold_block` | unmodified `default_gold_ingot.png`, `default_gold_block.png` |

Emberglass and Abyssal Crystal are the other two entries in the 12-row
processed-material registry; their resource and block media are already listed
in §3.

## 5. Cultural materials

| Runtime item | Vendored original | Runtime modifier |
|---|---|---|
| `grug_materials:sunwax` | `default_mese_crystal_fragment.png` | `^[colorize:#f0c45a:120` |
| `grug_materials:runeslate` | `default_stone.png` | `^[colorize:#64758a:110` |
| `grug_materials:moonresin` | `default_mese_crystal_fragment.png` | `^[colorize:#a9c9ee:130` |
| `grug_materials:red_ochre` | `default_clay_lump.png` | `^[colorize:#a54122:150` |
| `grug_materials:spirit_resin` | `default_mese_crystal_fragment.png` | `^[colorize:#8ca833:130` |
| `grug_materials:gravesalt` | `default_mese_crystal_fragment.png` | `^[colorize:#ddd8c8:145` |

## 6. Emberglass lighting

`grug_materials:emberglass_lamp` uses
`default_meselamp.png^[colorize:#ff7a2e:25`.

The five post registrations use the listed fence texture together with the
vendored helper overlays `default_mese_post_light_side.png` and
`default_mese_post_light_side_dark.png`, each with `^[makealpha:0,0,0`:

| Runtime node | Fence texture |
|---|---|
| `grug_materials:emberglass_post_light` | `default_fence_wood.png` |
| `grug_materials:emberglass_post_light_acacia_wood` | `default_fence_acacia_wood.png` |
| `grug_materials:emberglass_post_light_junglewood` | `default_fence_junglewood.png` |
| `grug_materials:emberglass_post_light_pine_wood` | `default_fence_pine_wood.png` |
| `grug_materials:emberglass_post_light_aspen_wood` | `default_fence_aspen_wood.png` |

The internal `default_mese*.png` filenames in §§2, 3, 5 and 6 are provenance
names of vendored assets. They are not player-facing legacy item/node IDs and
do not create a parallel Mese material.

## 7. Mining-failure feedback

An under-tier resource shatter emits transient particles using
`default_stone.png^[colorize:#777777:180` and plays the vendored
`default_dig_cracky.1-3.ogg` sound family. No generated particle texture or
sound file is stored by this mod.

## 8. Canonical derivatives of vendored nodes

These registrations copy the complete vendored source definition, including
its unmodified textures and sounds, then replace the description, canonical
drop and material groups. They add no recipe.

| Canonical runtime node(s) | Vendored source node(s) | Unmodified texture media |
|---|---|---|
| `grug_materials:iron_sign_wall` | `default:sign_wall_steel` | `default_sign_wall_steel.png`, `default_sign_steel.png` |
| `grug_materials:iron_ladder` | `default:ladder_steel` | `default_ladder_steel.png` |
| `grug_materials:stair_iron_block`, `grug_materials:stair_inner_iron_block`, `grug_materials:stair_outer_iron_block`, `grug_materials:slab_iron_block` | matching `stairs:*steelblock` nodes | `default_steel_block.png` |
| `grug_materials:stair_tin_block`, `grug_materials:stair_inner_tin_block`, `grug_materials:stair_outer_tin_block`, `grug_materials:slab_tin_block` | matching `stairs:*tinblock` nodes | `default_tin_block.png` |
| `grug_materials:stair_copper_block`, `grug_materials:stair_inner_copper_block`, `grug_materials:stair_outer_copper_block`, `grug_materials:slab_copper_block` | matching `stairs:*copperblock` nodes | `default_copper_block.png` |
| `grug_materials:stair_bronze_block`, `grug_materials:stair_inner_bronze_block`, `grug_materials:stair_outer_bronze_block`, `grug_materials:slab_bronze_block` | matching `stairs:*bronzeblock` nodes | `default_bronze_block.png` |
| `grug_materials:stair_gold_block`, `grug_materials:stair_inner_gold_block`, `grug_materials:stair_outer_gold_block`, `grug_materials:slab_gold_block` | matching `stairs:*goldblock` nodes | `default_gold_block.png` |

All 22 derivatives inherit `default.node_sound_metal_defaults()` and therefore
refer to the vendored
`default_metal_footstep.1-3.ogg`, `default_dig_metal.ogg`,
`default_dug_metal.1-2.ogg` and `default_place_node_metal.1-2.ogg` files.
Other nodes registered by this mod use the vendored stone, glass or wood sound
defaults from the same minetest_game commit. The combined sound licenses and
attributions are the ones preserved in `mods/BASE/default/license.txt`.
