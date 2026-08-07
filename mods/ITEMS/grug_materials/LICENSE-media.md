# Media Origin & Licenses (grug_materials)

**This mod ships no media files of its own.** It has no `textures/` folder,
and not a single PNG was copied out of any other mod. Every texture listed
below is produced **at runtime by the engine's texture modifiers**
(`^[colorize:` and the `a.png^(b.png^[colorize:…)` overlay grouping,
`reference_projects/luanti/doc/lua_api.md`, section "Texture modifiers") from
files that already ship inside the vendored `mods/BASE/default`.

Because no file is copied and no file is written, this document is an
attribution record for **derived works generated on the fly**, not a file
inventory.

## Source of all originals

All source textures live in `mods/BASE/default/textures`, vendored from
minetest_game <https://github.com/luanti-org/minetest_game> at `b5243f3`
(see VENDOR.md).

**License: CC BY-SA 3.0 Unported** — unchanged from the originals, and the
derivatives are distributed under the same license (ShareAlike).
License text: <http://creativecommons.org/licenses/by-sa/3.0/>

**Author/copyright:** © 2010–2023 the minetest_game contributors listed in
`mods/BASE/default/license.txt` (celeron55, Cisoun, VanessaE, Calinou,
PilzAdam, paramat, sofar, Gambit, TumeniNodes, et al.; minetest_game does
not attribute its textures per file).

## 1. Rock strata (node tiles)

A single `[colorize:` pass over the vendored stone tile — the rock structure
is the original's, only the hue and its strength differ per layer.

| Node | Derived from | Author | License | Modifier chain applied at runtime |
|------|--------------|--------|---------|-----------------------------------|
| `grug_materials:slate` | `default_stone.png` | minetest_game contributors | CC BY-SA 3.0 | `default_stone.png^[colorize:#4a5a6e:70` |
| `grug_materials:basalt` | `default_stone.png` | minetest_game contributors | CC BY-SA 3.0 | `default_stone.png^[colorize:#2a2a2e:90` |
| `grug_materials:granite` | `default_stone.png` | minetest_game contributors | CC BY-SA 3.0 | `default_stone.png^[colorize:#8a5a52:60` |
| `grug_materials:emberrock` | `default_stone.png` | minetest_game contributors | CC BY-SA 3.0 | `default_stone.png^[colorize:#7a2a10:90` |
| `grug_materials:abyssal_rock` | `default_stone.png` | minetest_game contributors | CC BY-SA 3.0 | `default_stone.png^[colorize:#241830:150` |

## 2. Ore nodes (node tiles)

Two originals per tile: the untouched stone background plus a **recolored
mineral overlay**. The parentheses matter — they scope the `[colorize:` to
the overlay only, so the stone behind the vein keeps its original colors.

| Node | Derived from | Author | License | Modifier chain applied at runtime |
|------|--------------|--------|---------|-----------------------------------|
| `grug_materials:stone_with_quartz` | `default_stone.png`, `default_mineral_diamond.png` | minetest_game contributors | CC BY-SA 3.0 | `default_stone.png^(default_mineral_diamond.png^[colorize:#eaf6ff:120)` |
| `grug_materials:stone_with_silver` | `default_stone.png`, `default_mineral_iron.png` | minetest_game contributors | CC BY-SA 3.0 | `default_stone.png^(default_mineral_iron.png^[colorize:#e8edf2:200)` |
| `grug_materials:stone_with_garnet` | `default_stone.png`, `default_mineral_diamond.png` | minetest_game contributors | CC BY-SA 3.0 | `default_stone.png^(default_mineral_diamond.png^[colorize:#9e1526:210)` |
| `grug_materials:abyssal_crystal_ore` | `default_stone.png`, `default_mineral_diamond.png` | minetest_game contributors | CC BY-SA 3.0 | `default_stone.png^(default_mineral_diamond.png^[colorize:#3a1f6e:210)` |

## 3. Raw items (inventory images)

| Item | Derived from | Author | License | Modifier chain applied at runtime |
|------|--------------|--------|---------|-----------------------------------|
| `grug_materials:quartz_crystal` | `default_diamond.png` | minetest_game contributors | CC BY-SA 3.0 | `default_diamond.png^[colorize:#eaf6ff:120` |
| `grug_materials:silver_lump` | `default_iron_lump.png` | minetest_game contributors | CC BY-SA 3.0 | `default_iron_lump.png^[colorize:#e8edf2:200` |
| `grug_materials:garnet_crystal` | `default_diamond.png` | minetest_game contributors | CC BY-SA 3.0 | `default_diamond.png^[colorize:#9e1526:210` |
| `grug_materials:abyssal_crystal` | `default_diamond.png` | minetest_game contributors | CC BY-SA 3.0 | `default_diamond.png^[colorize:#3a1f6e:210` |

## 4. Items only re-described, not re-textured

`overrides.lua` renames a handful of vendored `default` items (Mese →
Emberstone, see `docs/design/items_crafting.md` §3.0.1). Those keep their
original minetest_game textures unchanged and unmodified — no derivative is
created, and their license is the one in `mods/BASE/default/license.txt`.
