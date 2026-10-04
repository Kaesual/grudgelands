# Media Origin & Licenses (grug_materials)

**Thirty stored files: twelve tool sprites since WP13's round-2 tool ladder
(§0 below) and eighteen rock and mineral textures since Round 24 (§9);
everything else is a runtime registration.** Apart from those, the mod's
registrations use vendored minetest_game media unchanged, generate a tinted
derivative at runtime with Luanti texture modifiers, or copy a vendored node
definition under a canonical name.

This is therefore an attribution inventory for runtime registrations plus two
small file inventories, not a pure file inventory.

## 0. Stored tool sprites — CC BY-SA 3.0 Unported

The four metal tiers `default` never had (`tools.lua`) need their own icons.
Each is `default_tool_steel<family>.png` with its grey ramp mapped through a
per-material lookup table and its wooden handle pixels copied unchanged --
exactly the recolouring minetest_game itself used to turn its steel sword into
its bronze one (`tools/wp13/gen_weapon_ladder.py` reproduces
`default_tool_bronzesword.png` byte for byte as its own self-check).

They are therefore **derivative works of minetest_game's CC BY-SA 3.0 tool art
and stay under that licence**, with the same attribution as the rest of this
file. Regenerate with `python3 tools/wp13/gen_weapon_ladder.py`.

| File(s) | Source original | Modification |
|---|---|---|
| `grug_materials_tool_ironpick.png`, `..._ironaxe.png`, `..._ironshovel.png` | `default_tool_steelpick/axe/shovel.png` | grey ramp -> dark, dull grey, clearly below Steel |
| `grug_materials_tool_silversteelpick.png`, `..._silversteelaxe.png`, `..._silversteelshovel.png` | same three | grey ramp -> pale blue silver |
| `grug_materials_tool_embersteelpick.png`, `..._embersteelaxe.png`, `..._embersteelshovel.png` | same three | grey ramp -> near-black red body with a bright ember core |
| `grug_materials_tool_abyssal_steelpick.png`, `..._abyssal_steelaxe.png`, `..._abyssal_steelshovel.png` | same three | grey ramp -> deep violet with cold sheen |

## Source and license

Except for the Round 24 stored textures, whose origin, author and license
(CC BY-SA 3.0 or CC BY-SA 4.0 per file) are listed in §9, all originals live
in `mods/BASE/default`, vendored from
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

## 1. Rocks

Tier rocks T2-T6 and the three decorative rocks (Round 24) each use one
stored texture unmodified, set in one table (`ROCK_TILES` in `init.lua`).
Origin, modification and licence of each file are in §9.

| Runtime node | Stored texture | Origin and licence |
|---|---|---|
| `grug_materials:t2_stone` | `grug_materials_t2_stone.png` | §9.1, minetest_game derivative, CC BY-SA 3.0 |
| `grug_materials:t3_stone` | `grug_materials_t3_stone.png` | §9.1, minetest_game derivative, CC BY-SA 3.0 |
| `grug_materials:t4_stone` | `grug_materials_t4_stone.png` | §9.1, minetest_game derivative, CC BY-SA 3.0 |
| `grug_materials:t5_stone` | `grug_materials_t5_stone.png` | §9.1, minetest_game derivative, CC BY-SA 3.0 |
| `grug_materials:t6_stone` | `grug_materials_t6_stone.png` | §9.1, minetest_game derivative, CC BY-SA 3.0 |
| `grug_materials:slate` | `grug_materials_slate.png` | §9.2, VoxeLibre derivative, CC BY-SA 4.0 |
| `grug_materials:basalt` | `grug_materials_basalt.png` | §9.2, VoxeLibre (Lifora) derivative, CC BY-SA 3.0 |
| `grug_materials:granite` | `grug_materials_granite.png` | §9.2, VoxeLibre derivative, CC BY-SA 4.0 |

## 2. Natural resource nodes

Every tile is the unmodified `default_stone.png` with the node's stored mineral
overlay from §9.3 drawn over it at runtime
(`default_stone.png^grug_materials_mineral_<key>.png`). The same node, and so
the same light stone background, is used at every depth (Round 24 ruling 17).

| Runtime node | Stored overlay (§9.3) |
|---|---|
| `grug_materials:stone_with_quartz` | `grug_materials_mineral_quartz.png` |
| `grug_materials:stone_with_silver` | `grug_materials_mineral_silver.png` |
| `grug_materials:stone_with_citrine` | `grug_materials_mineral_citrine.png` |
| `grug_materials:stone_with_garnet` | `grug_materials_mineral_garnet.png` |
| `grug_materials:stone_with_jade` | `grug_materials_mineral_jade.png` |
| `grug_materials:stone_with_emberglass` | `grug_materials_mineral_emberglass.png` |
| `grug_materials:stone_with_diamond` | `grug_materials_mineral_diamond.png` |
| `grug_materials:stone_with_sapphire` | `grug_materials_mineral_sapphire.png` |
| `grug_materials:stone_with_ruby` | `grug_materials_mineral_ruby.png` |
| `grug_materials:abyssal_crystal_ore` | `grug_materials_mineral_abyssal_crystal.png` |

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
| Quartz | `grug_materials:quartz` | — | — | `default_diamond.png^[colorize:#eaf6ff:120` |
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

## 5. Emberglass lighting

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

The internal `default_mese*.png` filenames in §§3 and 5 are provenance
names of vendored assets. They are not player-facing legacy item/node IDs and
do not create a parallel Mese material.

## 6. Mining-failure feedback

Removed in Round 24: the under-tier resource shatter (and with it its
transient `default_stone.png^[colorize:#777777:180` particles and the
`default_dig_cracky.1-3.ogg` sound it played) no longer exists; a too-weak pick
cannot dig at all and the player gets a one-line text hint. No media file
became unused: this mod never stored its own particle texture or sound, and
`default_stone.png` and the `default_dig_cracky` sounds remain in use by the
vendored `default` mod (stone tiles, cracky dig sounds).

## 7. Canonical derivatives of vendored nodes

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

## 8. Round 24 stored rock and mineral textures

Eighteen files for Round 24 rulings 8, 16 and 17
(`docs/planning/round24-mining-underground-mobs-plan.md`). Regenerate with
`python3 tools/r24_art/build_rock_ore_textures.py --voxelibre <VoxeLibre checkout>`
(`--check` verifies the stored pixels, `--renders` rebuilds the comparison
sheets in `docs/research/round24-art/`). The script pins every input below by
SHA-256.

VoxeLibre inputs come from its top-level `textures/` directory,
<https://git.minetest.land/VoxeLibre/VoxeLibre>, commit
`2373982f19f9b5d89cd2e3146ad7749876319e15` (the `reference_projects/VoxeLibre`
submodule pin). Upstream `LEGAL.md`, "License of media": textures are "based
on the Pixel Perfection resource pack for Minecraft 1.11, authored by
XSSheep", **CC BY-SA 4.0**
(<https://creativecommons.org/licenses/by-sa/4.0/>), with per-mod READMEs
naming exceptions; "No non-free licenses are used anywhere". The one
exception that applies here is noted in its row. (`mods/ITEMS/mcl_core/README.txt`
still carries a pre-move note about a "Faithful 1.11" texture set; `mcl_core`
no longer ships any textures, so it does not describe the top-level files.)

### 9.1 Tier rocks — CC BY-SA 3.0 Unported (minetest_game derivatives)

Derivatives of the vendored `default_stone.png` (§ "Source and license"
above), so they stay under CC BY-SA 3.0 with the same attribution. Each is the
original with its pixel contrast around the mean raised (up to ×1.35 at T6),
multiplied by a brightness factor and a cool tint (full strength R ×0.93,
G ×0.98, B ×1.06, scaled per tier), plus a tile-seamless set of mostly
horizontal hairline cracks (crack pixel ×0.68; from T4 a lit lip ×1.10 above
each crack). Deeper tiers keep the shallower tiers' cracks and add new ones.

| File | Brightness | Tint strength | Cracks | Mean luminance vs `default_stone` |
|---|---|---|---|---|
| `grug_materials_t2_stone.png` | ×0.935 | 0.2 | 2 | −8 % |
| `grug_materials_t3_stone.png` | ×0.86 | 0.4 | 4 | −17 % |
| `grug_materials_t4_stone.png` | ×0.785 | 0.6 | 6 | −25 % |
| `grug_materials_t5_stone.png` | ×0.71 | 0.8 | 8 | −32 % |
| `grug_materials_t6_stone.png` | ×0.635 | 1.0 | 10 | −40 % |

### 9.2 Decorative rocks — VoxeLibre derivatives

Each is the upstream 16×16 texture re-graded: its mean colour moved to the
listed target, its luminance pattern kept (scaled by the contrast factor) and
half of its own per-pixel hue variation kept.

| File | Upstream source | Author and licence | Modification |
|---|---|---|---|
| `grug_materials_slate.png` | `mcl_deepslate.png` (mod `mcl_deepslate` by NO11, "Textures are from Pixel Perfection!") | XSSheep / Pixel Perfection, VoxeLibre contributors — CC BY-SA 4.0 | re-graded to cool blue-grey mean `#56606b`, contrast ×1.1 |
| `grug_materials_basalt.png` | `mcl_blackstone_basalt_side.png` | **Lifora — CC BY-SA 3.0** (`mods/ITEMS/mcl_blackstone/README.md` lists this file by name), <https://creativecommons.org/licenses/by-sa/3.0/> | re-graded to near-black mean `#3b3a3d`; stays CC BY-SA 3.0 |
| `grug_materials_granite.png` | `mcl_core_granite.png` | XSSheep / Pixel Perfection, VoxeLibre contributors — CC BY-SA 4.0 | re-graded to mean `#94705f` |

### 9.3 Mineral overlays

Transparent 16×16 overlays, drawn over `default_stone.png` at runtime (§2).
For the VoxeLibre-derived ones the script cuts the mineral motif out of the
upstream ore by differencing it against VoxeLibre's own `default_stone.png`
(quartz: by selecting its pale pixels, since it sits on netherrack), maps the
mineral pixels' brightness onto a five-colour ramp per mineral, and redraws the
grey rim pixels VoxeLibre sets around a gem with the nearest grey of
minetest_game's `default_stone.png` palette (two darker steps added). Those
overlays are adaptations of CC BY-SA 4.0 art and are released under
**CC BY-SA 4.0**; the few borrowed stone greys are CC BY-SA 3.0 material,
which that licence allows in a CC BY-SA 4.0 adaptation.

| File | Upstream motif | Licence | Ramp (dark → highlight) |
|---|---|---|---|
| `grug_materials_mineral_citrine.png` | VoxeLibre `mcl_core_emerald_ore.png` | CC BY-SA 4.0 | `#5a3806` … `#fff3b8` |
| `grug_materials_mineral_garnet.png` | VoxeLibre `mcl_core_emerald_ore.png` | CC BY-SA 4.0 | `#34040e` … `#f09aa6` |
| `grug_materials_mineral_jade.png` | VoxeLibre `mcl_core_emerald_ore.png` | CC BY-SA 4.0 | `#0c3520` … `#c9f2d6` |
| `grug_materials_mineral_diamond.png` | VoxeLibre `mcl_core_diamond_ore.png` | CC BY-SA 4.0 | `#3f6f8a` … `#ffffff` |
| `grug_materials_mineral_sapphire.png` | VoxeLibre `mcl_core_diamond_ore.png` | CC BY-SA 4.0 | `#0b1d58` … `#c4d8ff` |
| `grug_materials_mineral_ruby.png` | VoxeLibre `mcl_core_diamond_ore.png` | CC BY-SA 4.0 | `#4e0412` … `#ffc6ce` |
| `grug_materials_mineral_emberglass.png` | VoxeLibre `mcl_core_redstone_ore.png` | CC BY-SA 4.0 | `#5c1504` … `#fff1a0` |
| `grug_materials_mineral_abyssal_crystal.png` | VoxeLibre `mcl_core_lapis_ore.png` | CC BY-SA 4.0 | `#1a0b33` … `#e2d0ff` |
| `grug_materials_mineral_quartz.png` | VoxeLibre `mcl_nether_quartz_ore.png` (pale flecks only) | CC BY-SA 4.0 | `#8d8480` … `#ffffff`, plus a one-pixel stone-grey shadow below/right of each fleck |
| `grug_materials_mineral_silver.png` | minetest_game `default_mineral_iron.png` (vendored, §"Source and license") | **CC BY-SA 3.0** | streaks mirrored left-right, brightness mapped to `#7d8a9c` … `#f4f8ff`, translucent `#2e3440` (alpha 120) shade under each streak |

Only the silver overlay stays in minetest_game's streak language, like the
vendored coal, copper, tin, iron and gold ores; gems and crystals use the
VoxeLibre gem motifs, so the two families read apart.
