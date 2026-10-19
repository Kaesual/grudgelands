# Media Origin & Licenses (grug_nodes)

Five groups, listed in their own tables below:

1. **Biome signature tops (WP18)** — derived works of minetest_game
   textures, CC BY-SA 3.0.
2. **Own pixel art (WP6)** — original, CC0 1.0.
3. **Swamp set (Round 47)** — original, CC0 1.0, by GPT-6 Astra.
4. **Land grounds (Round 51)** — original, CC0 1.0, by GPT-6 Astra and
   Claude; they replace several files of groups 1 and 3 under the same
   names.
5. **Land kit props (Round 51)** — original, CC0 1.0, by GPT-6 Astra.
6. **Land plants (Round 51)** — original, CC0 1.0, by GPT-6 Astra.

## 1. Biome signature tops — derived from minetest_game

All textures in this section are **derived works** of minetest_game media
(`mods/BASE/default/textures`, vendored from
<https://github.com/luanti-org/minetest_game> at `b5243f3`, see VENDOR.md).

**License: CC BY-SA 3.0 Unported** — unchanged from the originals, and the
derivatives are distributed under the same license (ShareAlike).

**Author/copyright:** © 2010–2023 the minetest_game contributors listed in
`mods/BASE/default/license.txt` (celeron55, Cisoun, VanessaE, Calinou,
PilzAdam, paramat, sofar, Gambit, TumeniNodes, et al.; minetest_game does
not attribute its textures per file).
License text: <http://creativecommons.org/licenses/by-sa/3.0/>

**Modification:** recolored via ImageMagick — desaturate to the grayscale
structure of the original, gamma-normalize the mean luminance to the target
color's luma, then `-tint 100` with the target color (`-sigmoidal-contrast`
restores local contrast after a strong gamma lift). Alpha channels are
preserved.

| File | Derived from | Author | License | Modifications |
|------|--------------|--------|---------|---------------|
| `grug_nodes_bone_litter_side.png` | `default_coniferous_litter_side.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (ash grey `#9c988c`, alpha kept) |
| `grug_nodes_forest_litter.png` | `default_coniferous_litter.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (deep green `#34502a`) |
| `grug_nodes_forest_litter_side.png` | `default_coniferous_litter_side.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (deep green `#34502a`, alpha kept) |
| `grug_nodes_silver_litter_side.png` | `default_coniferous_litter_side.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (pale ivory-green `#c3caae`, alpha kept) |
| `grug_nodes_canopy_litter_side.png` | `default_coniferous_litter_side.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (deep shade emerald `#1d4433`); exact command: `magick default_coniferous_litter_side.png -colorspace Gray -gamma 0.693 -fill '#1d4433' -tint 100 grug_nodes_canopy_litter_side.png` (the gamma pulls the source's grayscale mean onto the target's Rec709 luma, per the recipe above), alpha kept |
| `grug_nodes_bone_pile.png` | `default_coral_skeleton.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (bone white `#ddd8c9`) and masked down to a 16×16 heap silhouette (own alpha mask); no node uses it since Round 51 (the bone pile is the land kit's scattered bones, section 5), kept for the land viewer's "today" side (`tools/r47_sw/land.js`) |

### 1b. Nodes that carry no media of their own

The authored field soil now belongs to `grug_farming`; this mod no longer
registers the interim tilled-soil node. Round-10 `grug_nodes:ash_ground` uses
`default_gravel.png` with runtime colorization `#45403e:145`. The vendored
README attributes that gravel to sofar (CC0 1.0), derived from Gambit's PixelBOX
light gravel. `grug_nodes:dirt_with_moss`'s bottom uses the unchanged shipped
`default_dirt.png` (its top and side are group 4's). These are
texture-name/modifier bindings; no new bitmap is shipped.

Since Round 51 the tops of blight dirt, bone, silver and canopy litter, mesa
clay and mud are group 4's files under the same names; the litter sides above
stay.

## 2. Own pixel art — CC0 1.0

Original 16×16 art of this project, **not** derived from any vendored or
third-party asset. Authored as ASCII maps plus a palette in
`tools/gen_mob_item_textures.py` (list `NODE_ICONS`) and generated
deterministically — re-running the script reproduces the PNG byte for byte.

**License: CC0 1.0 Universal** (<https://creativecommons.org/publicdomain/zero/1.0/>).

| File | Author | License | Notes |
|------|--------|---------|-------|
| `grug_nodes_guard_banner.png` | Grudgelands project | CC0 1.0 | generator, art `GUARD_BANNER`, weathered-wood + linen palette — tile of the nodebox `grug_nodes:guard_banner` (WP6/T8 guard post): columns 6–9 are the pole, columns 10–14 / rows 1–7 the flag board, the unused rest is transparent (`use_texture_alpha = "clip"`) |
| `grug_mobs_camp_fire.png` (served from `grug_mobs/textures`) | Grudgelands project | CC0 1.0 | generator, art `CAMP_FIRE`, ash/stone/ember palette — game-wide media used by the lower-layer node `grug_nodes:camp_fire`; behaviour is attached later by `grug_mobs` |

## 3. Swamp set (Round 47) — CC0 1.0

Original 16×16 RGBA textures made by **GPT-6 Astra** (2026-10-13) for
Grudgelands from independently authored pixel grids and palettes, no
downloaded or third-party pixels; the user picked them on the swamp concept
page (Round 47). Generator: `tools/r47_art/swamp/generate.py` (lane ART,
commit `3480a978`; provenance in `tools/r47_art/LICENSE-media.md`). Copied
byte for byte under this mod's texture prefix.

**License: CC0 1.0 Universal** (<https://creativecommons.org/publicdomain/zero/1.0/>).

| File | Source file | Author | License | Modifications |
|------|-------------|--------|---------|---------------|
| `grug_nodes_mud_dry_side.png` | `tools/r47_art/swamp/mud_dry_side.png` | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_moss_carpet_top.png` | `tools/r47_art/swamp/moss_carpet_top.png` | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_reeds.png` | `tools/r47_art/swamp/reeds.png` | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_cattails.png` | `tools/r47_art/swamp/cattails.png` | GPT-6 Astra | CC0 1.0 | renamed only |

`grug_nodes:mud_with_reeds` binds `grug_nodes_mud.png` (section 4) and
`grug_nodes_reeds.png`; no further bitmap. Round 51 replaced the dry mud's
top and the wet mud's and the wet grass's tops and sides with group 4's
files under the same names.

## 4. Land grounds (Round 51) — CC0 1.0

Original textures for Grudgelands, picked by the user in the Round 51 land
viewer (`tools/r47_sw/land.html`) and copied byte for byte from
`tools/r51_land` under this mod's names. No downloaded, traced or recoloured
third-party pixels. Every 32 × 32 file is drawn world-aligned over 2 × 2
nodes (`align_style = "world"`, `scale = 2`). Generators and per-file
records: `tools/r51_land/README.md` ("Media", "SWART", "ARTL pass 1"):
`swamp_calm.py` (Claude, Opus 5.5, 2026-10-18, from lane ART's CC0
palettes and hanging moss, commit `8dbeea8d`), `swamp_art.py` (GPT-6 Astra,
2026-10-18, commit `13c6272c`) and `land_art.py` (GPT-6 Astra, 2026-10-19,
commit `c16c6bcb`).

**License: CC0 1.0 Universal** (<https://creativecommons.org/publicdomain/zero/1.0/>).

| File | Source file | Author | License | Modifications |
|------|-------------|--------|---------|---------------|
| `grug_nodes_wet_grass_top.png` | `tools/r51_land/swamp/wet_grass_top_calm32.png` (`swamp_calm.py`) | Claude (Opus 5.5) | CC0 1.0 | renamed only |
| `grug_nodes_wet_grass_side.png` | `tools/r51_land/swamp/wet_grass_side_calm.png` (`swamp_calm.py`) | Claude (Opus 5.5) | CC0 1.0 | renamed only |
| `grug_nodes_mud_mottled_top.png` | `tools/r51_land/swamp/mud_mottled_top_calm32.png` (`swamp_calm.py`) | Claude (Opus 5.5) | CC0 1.0 | renamed only |
| `grug_nodes_mud_mottled_side.png` | `tools/r51_land/swamp/mud_mottled_side_calm.png` (`swamp_calm.py`) | Claude (Opus 5.5) | CC0 1.0 | renamed only |
| `grug_nodes_mud.png` | `tools/r51_land/swamp/mud_top_32.png` (`swamp_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_mud_dry_top.png` | `tools/r51_land/swamp/mud_dry_top_32.png` (`swamp_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_moss_soil_top.png` | `tools/r51_land/swamp/moss_soil_top_32.png` (`swamp_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_moss_soil_side.png` | `tools/r51_land/swamp/moss_soil_side.png` (`swamp_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_swamp_moss_top.png` | `tools/r51_land/grounds/swamp_moss_top_32.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_swamp_moss_side.png` | `tools/r51_land/grounds/swamp_moss_side.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_silver_litter.png` | `tools/r51_land/grounds/silver_litter_top_32.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_blight_dirt.png` | `tools/r51_land/grounds/blight_dirt_32.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_bone_litter.png` | `tools/r51_land/grounds/bone_litter_top_32.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_canopy_litter.png` | `tools/r51_land/grounds/canopy_litter_top_32.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_mesa_clay.png` | `tools/r51_land/grounds/mesa_clay_32.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_clay_band_ochre.png` | `tools/r51_land/grounds/clay_band_ochre_32.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_clay_band_sienna.png` | `tools/r51_land/grounds/clay_band_sienna_32.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_clay_band_chalk.png` | `tools/r51_land/grounds/clay_band_chalk_32.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_clay_band_umber.png` | `tools/r51_land/grounds/clay_band_umber_32.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_sand.png` | `tools/r51_land/grounds/sand_32.png` (`land_art.py`) | GPT-6 Astra | CC0 1.0 | renamed only; `default:sand`, `default:sand_with_kelp` and `grug_mapgen:freshwater_waterweed` bind it (the vendored `default_sand.png` stays unchanged) |

## 5. Land kit props (Round 51) — CC0 1.0

Original 16×16 RGBA textures made by **GPT-6 Astra** (2026-10-19, lane
ARTL passes 2 and 3) from blank canvases, no downloaded or third-party
pixels; the user picked them in the land viewer (2026-10-19). Generator:
`tools/r51_land/props_art.py` (provenance in `tools/r51_land/README.md`,
"ARTL pass 2 media" and "ARTL pass 3 media"). Copied byte for byte by
`tools/r51_lk/gen_props.py` (`--check`) under this mod's texture prefix,
six tiles per prop; the props `bones_scattered` and `gravestone_slab` are
the nodes `grug_nodes:bone_pile` and `grug_nodes:gravestone_stele`. The
stone cairn shapes (`grug_nodes:cairn_base`, `_branch`, `_twig`) bind the
shipped `default_stone.png` and carry no bitmap of their own.

**License: CC0 1.0 Universal** (<https://creativecommons.org/publicdomain/zero/1.0/>).

| File | Source file | Author | License | Modifications |
|------|-------------|--------|---------|---------------|
| `grug_nodes_bones_fragments_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/bones_fragments/bones_fragments_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Bones, broken jaw and splinters) |
| `grug_nodes_bone_pile_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/bones_scattered/bones_scattered_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Bones, scattered long bones) |
| `grug_nodes_cairn_cap_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/cairn_cap/cairn_cap_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Cairn, offset cap stones) |
| `grug_nodes_cairn_course_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/cairn_course/cairn_course_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Cairn, rough stone course) |
| `grug_nodes_driftwood_fork_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/driftwood_fork/driftwood_fork_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Driftwood, forked branch) |
| `grug_nodes_driftwood_log_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/driftwood_log/driftwood_log_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Driftwood, bleached log) |
| `grug_nodes_gravestone_cross_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/gravestone_cross/gravestone_cross_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Gravestone, chipped cross crown) |
| `grug_nodes_gravestone_fallen_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/gravestone_fallen/gravestone_fallen_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Gravestone, fallen split stele) |
| `grug_nodes_gravestone_stele_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/gravestone_slab/gravestone_slab_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Gravestone, weathered stele) |
| `grug_nodes_gravestone_sunken_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/gravestone_sunken/gravestone_sunken_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Gravestone, sunken leaning stele) |
| `grug_nodes_obelisk_broken_tip_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/obelisk_broken_tip/obelisk_broken_tip_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Obelisk, fractured stone tip) |
| `grug_nodes_ribcage_human_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/ribcage_human/ribcage_human_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Ribcage, humanoid) |
| `grug_nodes_skull_horned_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/skull_horned/skull_horned_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Skull, horned animal) |
| `grug_nodes_skull_human_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/skull_human/skull_human_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Skull, humanoid) |
| `grug_nodes_spine_animal_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/spine_animal/spine_animal_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Spine, small animal) |
| `grug_nodes_statue_broken_torso_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/statue_broken_torso/statue_broken_torso_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Statue, broken draped torso) |
| `grug_nodes_statue_mourner_base_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/statue_mourner_base/statue_mourner_base_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Mourner, kneeling robe and knees) |
| `grug_nodes_statue_mourner_upper_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/statue_mourner_upper/statue_mourner_upper_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Mourner, bowed hood and clasped hands) |
| `grug_nodes_statue_veiled_head_{top,bottom,right,left,back,front}.png` | `tools/r51_land/props/statue_veiled_head/statue_veiled_head_*.png` | GPT-6 Astra | CC0 1.0 | renamed only (Statue, worn veiled head) |

## 6. Land plants (Round 51) — CC0 1.0

Original textures for Grudgelands, picked by the user in the Round 51 land
viewer (`tools/r47_sw/land.html`) and copied byte for byte from
`tools/r51_land/plants` under this mod's names. No downloaded, traced or
recoloured third-party pixels. Generator and per-file records:
`tools/r51_land/README.md` ("ARTL pass 1", "ARTL pass 3"): `land_art.py`
(GPT-6 Astra, 2026-10-19; pass 1 commit `c16c6bcb`, the pass 3 lichen
commit `d799517e`). The flowers and alpine plants are plantlike, the bush
foliage allfaces, the lichen a carpet drawn with alpha clip.

**License: CC0 1.0 Universal** (<https://creativecommons.org/publicdomain/zero/1.0/>).

| File | Source file | Author | License | Modifications |
|------|-------------|--------|---------|---------------|
| `grug_nodes_flower_ruby_fan.png` | `tools/r51_land/plants/flower_ruby_fan.png` (`land_art.py`, pass 1) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_flower_ember_star.png` | `tools/r51_land/plants/flower_ember_star.png` (`land_art.py`, pass 1) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_flower_violet_fan.png` | `tools/r51_land/plants/flower_violet_fan.png` (`land_art.py`, pass 1) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_flower_blush_star.png` | `tools/r51_land/plants/flower_blush_star.png` (`land_art.py`, pass 1) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_flower_lilac_bells.png` | `tools/r51_land/plants/flower_lilac_bells.png` (`land_art.py`, pass 1) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_flower_cream_cups.png` | `tools/r51_land/plants/flower_cream_cups.png` (`land_art.py`, pass 1) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_alpine_cushion.png` | `tools/r51_land/plants/alpine_cushion.png` (`land_art.py`, pass 1) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_alpine_windshrub.png` | `tools/r51_land/plants/alpine_windshrub.png` (`land_art.py`, pass 1) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_jungle_bush_leaves.png` | `tools/r51_land/plants/jungle_bush_leaves.png` (`land_art.py`, pass 1) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_withered_bush_leaves.png` | `tools/r51_land/plants/withered_bush_leaves.png` (`land_art.py`, pass 1) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_lichen_carpet_top.png` | `tools/r51_land/plants/lichen_carpet_top.png` (`land_art.py`, pass 3) | GPT-6 Astra | CC0 1.0 | renamed only |
| `grug_nodes_lichen_carpet_top_b.png` | `tools/r51_land/plants/lichen_carpet_top_b.png` (`land_art.py`, pass 3) | GPT-6 Astra | CC0 1.0 | renamed only |
