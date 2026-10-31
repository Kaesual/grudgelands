# Media licenses — Grudgelands additions to the vendored default mod

The vendored minetest_game media keep their record in `README.txt` and
`license.txt`. The files below were added by Grudgelands.

## Container tiers (Round 67)

Original scripted pixel art authored for Grudgelands by GPT-6 Astra on
2026-10-30 (the user's pick: Steel A strapped timber, Abyssal B metal plating), drawn by
`tools/r67_art/generate.py` with no source image pixels; provenance in
`tools/r67_art/LICENSE-media.md`. Copied unchanged under the names the
container tiers use (`default/containers.lua`); the open chest's model
`models/chest_open.obj` keeps its own licence.

| File | Source | License |
|---|---|---|
| `textures/default_chest_steel_{top,side,front,lock,inside}.png` | `tools/r67_art/candidates/chest_steel_{top,side,front,lock,inside}_a.png` | CC0-1.0 |
| `textures/default_chest_abyssal_{top,side,front,lock,inside}.png` | `tools/r67_art/candidates/chest_abyssal_{top,side,front,lock,inside}_b.png` | CC0-1.0 |
| `textures/default_bookshelf_steel.png` | `tools/r67_art/candidates/bookshelf_steel_a.png` | CC0-1.0 |
| `textures/default_bookshelf_abyssal.png` | `tools/r67_art/candidates/bookshelf_abyssal_b.png` | CC0-1.0 |
| `textures/default_shelf_steel_side.png` | `tools/r67_art/candidates/shelf_side_steel_a.png` | CC0-1.0 |
| `textures/default_shelf_abyssal_side.png` | `tools/r67_art/candidates/shelf_side_abyssal_b.png` | CC0-1.0 |

## Wall sign boards (Round 68)

Original scripted pixel art authored for Grudgelands by GPT-6 Astra on
2026-10-31 (the user's pick: a calm writing field for the text in the
world), drawn by `tools/r68_art/generate.py` (lane ART of Round 68) with no
source image pixels; provenance in `tools/r68_art/LICENSE-media.md`. They
**replace** the vendored files of the same names, so `README.txt`'s rows
for `default_sign_wall_wood.png` (and the steel sign's) describe the
upstream originals, not these. The iron sign
(`grug_materials:iron_sign_wall`, cloned from `default:sign_wall_steel`)
uses `default_sign_wall_steel.png`. The inventory and wield images
(`default_sign_wood.png`, `default_sign_steel.png`) are unchanged.

| File | Source | License |
|---|---|---|
| `textures/default_sign_wall_wood.png` | `tools/r68_art/candidates/sign_wall_wood.png` | CC0-1.0 |
| `textures/default_sign_wall_steel.png` | `tools/r68_art/candidates/sign_wall_iron.png` | CC0-1.0 |
