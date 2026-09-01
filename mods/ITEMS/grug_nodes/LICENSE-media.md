# Media Origin & Licenses (grug_nodes)

Two groups, listed in their own tables below:

1. **Biome signature tops (WP18)** — derived works of minetest_game
   textures, CC BY-SA 3.0.
2. **Own pixel art (WP6)** — original, CC0 1.0.

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
| `grug_nodes_blight_dirt.png` | `default_dirt.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (desaturated grey-violet `#5f5270`) |
| `grug_nodes_bone_litter.png` | `default_coniferous_litter.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (ash grey `#9c988c`) |
| `grug_nodes_bone_litter_side.png` | `default_coniferous_litter_side.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (ash grey `#9c988c`, alpha kept) |
| `grug_nodes_forest_litter.png` | `default_coniferous_litter.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (deep green `#34502a`) |
| `grug_nodes_forest_litter_side.png` | `default_coniferous_litter_side.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (deep green `#34502a`, alpha kept) |
| `grug_nodes_silver_litter.png` | `default_coniferous_litter.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (pale ivory-green `#c3caae`) |
| `grug_nodes_silver_litter_side.png` | `default_coniferous_litter_side.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (pale ivory-green `#c3caae`, alpha kept) |
| `grug_nodes_canopy_litter.png` | `default_coniferous_litter.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (deep shade emerald `#1d4433`); exact command: `magick default_coniferous_litter.png -colorspace Gray -gamma 0.693 -fill '#1d4433' -tint 100 grug_nodes_canopy_litter.png` — 0.693 is the gamma that pulls the source's grayscale mean (0.3568) onto the target's Rec709 luma (0.2293), per the recipe above; no `-sigmoidal-contrast` because the gamma is a darkening, not a lift |
| `grug_nodes_canopy_litter_side.png` | `default_coniferous_litter_side.png` | minetest_game contributors | CC BY-SA 3.0 | same command and same gamma 0.693 as the tile above (one material, one tint), alpha kept |
| `grug_nodes_mesa_clay.png` | `default_clay.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (terracotta `#a8563a`) |
| `grug_nodes_mud.png` | `default_dirt.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (dark brown-green `#3b3e2a`) |
| `grug_nodes_bone_pile.png` | `default_coral_skeleton.png` | minetest_game contributors | CC BY-SA 3.0 | recolored via ImageMagick (bone white `#ddd8c9`) and masked down to a 16×16 heap silhouette (own alpha mask) |

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
| `grug_nodes_depleted_vein.png` | Grudgelands project | CC0 1.0 | generator, art `DEPLETED_VEIN`, neutral-grey palette — **overlay only**: four hollow pockets plus a hairline crack on a fully transparent tile, composed over the vendored `default_stone.png` at runtime (`tiles = {"default_stone.png^grug_nodes_depleted_vein.png"}`, node `grug_nodes:depleted_vein`, WP6/T9 R4 ore respawn). The stone below it stays minetest_game media under its own license (`mods/BASE/default/license.txt`, CC BY-SA 3.0); this file adds no pixels of it |
