# Media Origin & Licenses (grug_smelting)

**Two stored files.** Everything else this mod draws with is vendored
minetest_game media referenced unchanged by name.

The mod's code is a port of Lord of the Test's `lottblocks` dual furnace
(LGPL 2.1, GPL-3.0-or-later compatible — see [VENDOR.md](../../../VENDOR.md)).
**No `lottblocks` media is taken.** That mod's art is CC BY-SA 3.0 by Flipsels,
catninja and others (`reference_projects/Lord-of-the-Test/mods/lottblocks/license.txt`),
and the WP26 task card forbids copying it; the two front faces below are
re-skinned from the vendored minetest_game furnace fronts instead.

## 1. Stored front faces — CC BY-SA 3.0 Unported

Both files are **derivative works of minetest_game's CC BY-SA 3.0 furnace art
and stay under that licence**, exactly like `grug_materials`' stored tool
sprites. The edit is geometric and introduces no new colour: a two-pixel stone
pillar is set into the upper mouth of the front face, splitting the single arch
into the two openings the node's two material slots stand for. The pillar's two
columns are copied from the same pixel row's own inner arch edges (x = 12 and
x = 3), so the new openings carry the original artwork's edge shading. The
lower fire chamber — the animated part of the active strip — is byte-identical
to the original in all eight frames.

Regenerate with `python3 tools/wp26/gen_dual_furnace_textures.py`; the same
script verifies both properties (`--check` fails instead of writing).

| File | Source original | Modification |
|---|---|---|
| `grug_smelting_dual_furnace_front.png` | `default_furnace_front.png` | one arch split into two by a 2 px pillar (rows 3–6) |
| `grug_smelting_dual_furnace_front_active.png` | `default_furnace_front_active.png` | the same split applied to each of the eight animation frames; the fire chamber is unchanged |

## 2. Referenced, not stored

The node's other five faces and its formspec images name vendored
minetest_game files directly and modify none of them:
`default_furnace_top.png`, `default_furnace_bottom.png`,
`default_furnace_side.png`, `default_furnace_fire_bg.png`,
`default_furnace_fire_fg.png`, `gui_furnace_arrow_bg.png`,
`gui_furnace_arrow_fg.png`.

The node inherits `default.node_sound_stone_defaults()` and therefore refers to
the vendored `default_hard_footstep.*`, `default_dig_cracky.*`,
`default_dug_node.*` and `default_place_node_hard.*` files. No sound is copied,
modified or relicensed here.

## Source and license

All originals live in `mods/BASE/default`, vendored from minetest_game
<https://github.com/luanti-org/minetest_game> at commit `b5243f3`; see
[VENDOR.md](../../../VENDOR.md). The originals are **CC BY-SA 3.0 Unported**
and the derivatives remain under that license. License text:
<http://creativecommons.org/licenses/by-sa/3.0/>.

**Author/copyright:** © 2010–2023 the minetest_game contributors listed in
`mods/BASE/default/license.txt` (celeron55, Cisoun, VanessaE, Calinou,
PilzAdam, paramat, sofar, Gambit, TumeniNodes, et al.; minetest_game does not
attribute these media per file).
