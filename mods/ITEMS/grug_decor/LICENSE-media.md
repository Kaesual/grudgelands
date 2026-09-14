# Media Origin & Licenses (grug_decor)

All media in this mod is a **verbatim copy** of an upstream file, **renamed** to
`grug_decor_<source>_<original>` so that nothing collides with another mod's
media namespace. No file is retinted, rescaled or otherwise edited; "rename
only" in the tables below is literal.

The four upstream projects and the **code** licence of each (the node
definitions harvested from them are documented in `../../../VENDOR.md`):

| Source prefix | Upstream | Harvested commit | Code license |
|---|---|---|---|
| `castle` | [castle_masonry](https://github.com/minetest-mods/castle_masonry) | `900d633d4ab8cf2350671208a4b93b614c4abba9` | MIT |
| `cottages` | [cottages](https://github.com/Sokomine/cottages) | `ab7f7e107afd175522459f10991c8c746dc95374` | GPL-3.0-only |
| `darkage` | [darkage](https://github.com/adrido/darkage) | `494f81c37593ec21f803bbcced70dcdc3e95a045` | MIT |
| `xdecor` | [xdecor-libre](https://codeberg.org/Wuzzy/xdecor-libre) | `43a77535eab1148937e4b2ea1263d2a60700e362` | BSD-3-Clause |

Because `cottages` is **GPL-3.0-only**, the **combined work is distributed
under GPL-3.0** (the project's own code is GPL-3.0-or-later, which combines to
GPL-3.0 here). MIT and BSD-3-Clause are GPL-compatible permissive licences;
their notices are preserved in this file. Each media file keeps its own
original licence, listed per table below.

License texts:
CC BY-SA 3.0 Unported <http://creativecommons.org/licenses/by-sa/3.0/> ·
CC BY-SA 2.0 Germany <https://creativecommons.org/licenses/by-sa/2.0/de/> ·
CC0 1.0 <https://creativecommons.org/publicdomain/zero/1.0/> ·
WTFPL <http://www.wtfpl.net/txt/copying/> ·
GPL-3.0 <https://www.gnu.org/licenses/gpl-3.0.html>

Two provenance caveats, both carried over from the
[2026-09-14 asset audit](../../../docs/research/assets/asset-audit-2026-09-14.md):

1. `castle_dungeon_stone.png` is **not** listed in castle_masonry's
   `textures/LICENSE.txt`, which names only the seven files attributed below to
   Philipner and Napiophelios. It is therefore covered by the repository's
   `LICENSE` (MIT) alone, with no per-file author statement upstream.
2. cottages' README media list names `models/cottages_wagonwheel_round.obj`
   (whosit, CC0); the file actually shipped at this commit is
   `models/cottages_wagonwheel_round_with_axle.obj`. We treat it as the same
   CC0 work under a later name. The five barrel/tub `.obj` models are in no
   upstream media list at all and are covered by the mod's GPLv3 only.

Nothing from cottages that uses `cottages_rope.png` was harvested -- that
texture's licence is stated as "CC" with no version or variant, i.e.
unverified. No NC or ND media is present.


## 1. castle_masonry -- CC BY-SA 3.0 Unported (Philipner)

16 px textures based on the Castle mod, original textures by Philipner; attributed in `textures/LICENSE.txt`.

| File | Derived from (upstream path @ commit) | Author | License | Modification |
|---|---|---|---|---|
| `grug_decor_castle_castle_corner_stonewall_tb.png` | `textures/castle_corner_stonewall_tb.png` @ `900d633` | Philipner | CC BY-SA 3.0 | rename only |
| `grug_decor_castle_castle_corner_stonewall1.png` | `textures/castle_corner_stonewall1.png` @ `900d633` | Philipner | CC BY-SA 3.0 | rename only |
| `grug_decor_castle_castle_corner_stonewall2.png` | `textures/castle_corner_stonewall2.png` @ `900d633` | Philipner | CC BY-SA 3.0 | rename only |

## 2. castle_masonry -- CC BY-SA 3.0 Unported (Napiophelios)

Attributed in `textures/LICENSE.txt`.

| File | Derived from (upstream path @ commit) | Author | License | Modification |
|---|---|---|---|---|
| `grug_decor_castle_castle_pavement_brick.png` | `textures/castle_pavement_brick.png` @ `900d633` | Napiophelios | CC BY-SA 3.0 | rename only |
| `grug_decor_castle_castle_rubble.png` | `textures/castle_rubble.png` @ `900d633` | Napiophelios | CC BY-SA 3.0 | rename only |
| `grug_decor_castle_castle_slate.png` | `textures/castle_slate.png` @ `900d633` | Napiophelios | CC BY-SA 3.0 | rename only |
| `grug_decor_castle_castle_stonewall.png` | `textures/castle_stonewall.png` @ `900d633` | Napiophelios | CC BY-SA 3.0 | rename only |

## 3. castle_masonry -- MIT (repository licence, no per-file entry)

See caveat 1 above.

| File | Derived from (upstream path @ commit) | Author | License | Modification |
|---|---|---|---|---|
| `grug_decor_castle_castle_dungeon_stone.png` | `textures/castle_dungeon_stone.png` @ `900d633` | castle_masonry contributors (Minetest Mods Team) | MIT (repo `LICENSE`; not in `textures/LICENSE.txt`) | rename only |

## 4. cottages -- CC BY-SA 3.0 Unported

Per the per-file media list in cottages' `README.md`.

| File | Derived from (upstream path @ commit) | Author | License | Modification |
|---|---|---|---|---|
| `grug_decor_cottages_cottages_homedecor_shingles_wood.png` | `textures/cottages_homedecor_shingles_wood.png` @ `ab7f7e1` | VanessaE | CC BY-SA 3.0 | rename only |
| `grug_decor_cottages_cottages_homedecor_shingles_terracotta.png` | `textures/cottages_homedecor_shingles_terracotta.png` @ `ab7f7e1` | VanessaE | CC BY-SA 3.0 | rename only |
| `grug_decor_cottages_cottages_wagonwheel.png` | `textures/cottages_wagonwheel.png` @ `ab7f7e1` | VanessaE | CC BY-SA 3.0 | rename only (README spells the source name `cottages_waonwheel.png`) |
| `grug_decor_cottages_cottages_barrel.png` | `textures/cottages_barrel.png` @ `ab7f7e1` | VanessaE | CC BY-SA 3.0 | rename only |
| `grug_decor_cottages_cottages_loam.png` | `textures/cottages_loam.png` @ `ab7f7e1` | Sokomine | CC BY-SA 3.0 | rename only |
| `grug_decor_cottages_cottages_glass_pane.png` | `textures/cottages_glass_pane.png` @ `ab7f7e1` | Sokomine | CC BY-SA 3.0 | rename only (upstream is itself a modification of `default_glass.png`) |
| `grug_decor_cottages_cottages_clay.png` | `textures/cottages_clay.png` @ `ab7f7e1` | celeron55 (Perttu Ahola) et al. | CC BY-SA 3.0 | rename only |
| `grug_decor_cottages_cottages_minimal_wood.png` | `textures/cottages_minimal_wood.png` @ `ab7f7e1` | celeron55 (Perttu Ahola) et al. | CC BY-SA 3.0 | rename only (upstream took it from the engine's minimal game) |

## 5. cottages -- CC BY-SA 2.0 Germany

| File | Derived from (upstream path @ commit) | Author | License | Modification |
|---|---|---|---|---|
| `grug_decor_cottages_cottages_slate.png` | `textures/cottages_slate.png` @ `ab7f7e1` | Stefanie Lindener (via cottages/Sokomine) | CC BY-SA 2.0 DE | rename only (upstream derives it from *Universal schema.jpg*, de.wikipedia.org) |

## 6. cottages -- WTFPL

| File | Derived from (upstream path @ commit) | Author | License | Modification |
|---|---|---|---|---|
| `grug_decor_cottages_cottages_darkage_straw.png` | `textures/cottages_darkage_straw.png` @ `ab7f7e1` | MasterGollum (darkage mod) | WTFPL | rename only |
| `grug_decor_cottages_cottages_darkage_straw_bale.png` | `textures/cottages_darkage_straw_bale.png` @ `ab7f7e1` | MasterGollum (darkage mod) | WTFPL | rename only |
| `grug_decor_cottages_cottages_reet.png` | `textures/cottages_reet.png` @ `ab7f7e1` | MasterGollum (darkage mod) | WTFPL | rename only (upstream recoloured the darkage straw texture) |
| `grug_decor_cottages_cottages_wool.png` | `textures/cottages_wool.png` @ `ab7f7e1` | Cisoun (Cisoun's texture pack) | WTFPL | rename only |
| `grug_decor_cottages_cottages_stone.png` | `textures/cottages_stone.png` @ `ab7f7e1` | Cisoun (Cisoun's texture pack) | WTFPL | rename only |

## 7. cottages -- CC0 1.0 (models)

| File | Derived from (upstream path @ commit) | Author | License | Modification |
|---|---|---|---|---|
| `grug_decor_cottages_cottages_wagonwheel_voxel_crimes.obj` | `models/cottages_wagonwheel_voxel_crimes.obj` @ `ab7f7e1` | whosit | CC0 1.0 | rename only |
| `grug_decor_cottages_cottages_wagonwheel_round_with_axle.obj` | `models/cottages_wagonwheel_round_with_axle.obj` @ `ab7f7e1` | whosit | CC0 1.0 | rename only (README lists it as `cottages_wagonwheel_round.obj`; see caveat 2) |

## 8. cottages -- GPL-3.0-only (models, no per-file media entry)

See caveat 2 above: these five meshes appear in no upstream media list, so the mod's own licence governs them.

| File | Derived from (upstream path @ commit) | Author | License | Modification |
|---|---|---|---|---|
| `grug_decor_cottages_cottages_barrel.obj` | `models/cottages_barrel.obj` @ `ab7f7e1` | Sokomine (cottages contributors) | GPL-3.0-only (mod `LICENSE`) | rename only |
| `grug_decor_cottages_cottages_barrel_closed.obj` | `models/cottages_barrel_closed.obj` @ `ab7f7e1` | Sokomine (cottages contributors) | GPL-3.0-only (mod `LICENSE`) | rename only |
| `grug_decor_cottages_cottages_barrel_lying.obj` | `models/cottages_barrel_lying.obj` @ `ab7f7e1` | Sokomine (cottages contributors) | GPL-3.0-only (mod `LICENSE`) | rename only |
| `grug_decor_cottages_cottages_barrel_closed_lying.obj` | `models/cottages_barrel_closed_lying.obj` @ `ab7f7e1` | Sokomine (cottages contributors) | GPL-3.0-only (mod `LICENSE`) | rename only |
| `grug_decor_cottages_cottages_tub.obj` | `models/cottages_tub.obj` @ `ab7f7e1` | Sokomine (cottages contributors) | GPL-3.0-only (mod `LICENSE`) | rename only |

## 9. darkage -- CC0 1.0

darkage's `README.md` states `Graphics: CC-0` for the whole tree, with no per-file exceptions; `glass.lua` additionally thanks Semmett9 (aka Infinatum) for the glass textures.

| File | Derived from (upstream path @ commit) | Author | License | Modification |
|---|---|---|---|---|
| `grug_decor_darkage_darkage_adobe.png` | `textures/darkage_adobe.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_basalt.png` | `textures/darkage_basalt.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_basalt_rubble.png` | `textures/darkage_basalt_rubble.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_basalt_brick.png` | `textures/darkage_basalt_brick.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_basalt_block.png` | `textures/darkage_basalt_block.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_chalk.png` | `textures/darkage_chalk.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_chalked_bricks.png` | `textures/darkage_chalked_bricks.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_marble.png` | `textures/darkage_marble.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_marble_tile.png` | `textures/darkage_marble_tile.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_ors.png` | `textures/darkage_ors.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_ors_rubble.png` | `textures/darkage_ors_rubble.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_ors_brick.png` | `textures/darkage_ors_brick.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_ors_block.png` | `textures/darkage_ors_block.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_serpentine.png` | `textures/darkage_serpentine.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_slate.png` | `textures/darkage_slate.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_slate_side.png` | `textures/darkage_slate_side.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_slate_rubble.png` | `textures/darkage_slate_rubble.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_slate_brick.png` | `textures/darkage_slate_brick.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_slate_block.png` | `textures/darkage_slate_block.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_slate_tile.png` | `textures/darkage_slate_tile.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_stone_brick.png` | `textures/darkage_stone_brick.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_mud.png` | `textures/darkage_mud.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_mud_up.png` | `textures/darkage_mud_up.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_straw_bale.png` | `textures/darkage_straw_bale.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_reinforce.png` | `textures/darkage_reinforce.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_reinforce_left.png` | `textures/darkage_reinforce_left.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_reinforce_right.png` | `textures/darkage_reinforce_right.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_reinforce_arrow.png` | `textures/darkage_reinforce_arrow.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_reinforce_bars.png` | `textures/darkage_reinforce_bars.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_glass.png` | `textures/darkage_glass.png` @ `494f81c` | Semmett9 (Infinatum), via darkage | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_glass_round.png` | `textures/darkage_glass_round.png` @ `494f81c` | Semmett9 (Infinatum), via darkage | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_glass_square.png` | `textures/darkage_glass_square.png` @ `494f81c` | Semmett9 (Infinatum), via darkage | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_wood_frame.png` | `textures/darkage_wood_frame.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_iron_bars.png` | `textures/darkage_iron_bars.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_iron_grille.png` | `textures/darkage_iron_grille.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_wood_bars.png` | `textures/darkage_wood_bars.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |
| `grug_decor_darkage_darkage_wood_grille.png` | `textures/darkage_wood_grille.png` @ `494f81c` | adrido / darkage contributors | CC0 1.0 | rename only |

## 10. xdecor-libre -- CC0 1.0

xdecor-libre's `LICENSE.txt` declares `Textures: CC0 (credits: Gambit, kilbith, Cisoun, Wuzzy)` and names three exceptions -- radio/speaker (CC BY 4.0), the chess notation icons (CC BY-SA 3.0) and three sounds (CC BY 3.0). **None of those are harvested here.** The hanging-candle texture is named separately in the same file as CC0 by Wuzzy.

| File | Derived from (upstream path @ commit) | Author | License | Modification |
|---|---|---|---|---|
| `grug_decor_xdecor_xdecor_barrel_top.png` | `textures/xdecor_barrel_top.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_barrel_sides.png` | `textures/xdecor_barrel_sides.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_wood.png` | `textures/xdecor_wood.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_cushion.png` | `textures/xdecor_cushion.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_curtain_open_overlay.png` | `textures/xdecor_curtain_open_overlay.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_curtain_open_overlay_top.png` | `textures/xdecor_curtain_open_overlay_top.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_curtain_open_overlay_bottom.png` | `textures/xdecor_curtain_open_overlay_bottom.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_lantern.png` | `textures/xdecor_lantern.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_lantern_inv.png` | `textures/xdecor_lantern_inv.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_lantern_hanging_overlay_inv.png` | `textures/xdecor_lantern_hanging_overlay_inv.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_candle_floor.png` | `textures/xdecor_candle_floor.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_candle_hanging.png` | `textures/xdecor_candle_hanging.png` @ `43a7753` | Wuzzy | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_candle_wall.png` | `textures/xdecor_candle_wall.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_candle_inv.png` | `textures/xdecor_candle_inv.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_candle_wield.png` | `textures/xdecor_candle_wield.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_dandelion_white_pot.png` | `textures/xdecor_dandelion_white_pot.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_dandelion_yellow_pot.png` | `textures/xdecor_dandelion_yellow_pot.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_geranium_pot.png` | `textures/xdecor_geranium_pot.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_rose_pot.png` | `textures/xdecor_rose_pot.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_tulip_pot.png` | `textures/xdecor_tulip_pot.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_viola_pot.png` | `textures/xdecor_viola_pot.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_tulip_black_pot.png` | `textures/xdecor_tulip_black_pot.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_chrysanthemum_green_pot.png` | `textures/xdecor_chrysanthemum_green_pot.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_painting_1.png` | `textures/xdecor_painting_1.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_painting_2.png` | `textures/xdecor_painting_2.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_painting_3.png` | `textures/xdecor_painting_3.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_painting_4.png` | `textures/xdecor_painting_4.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_painting_empty.png` | `textures/xdecor_painting_empty.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_woodframed_glass.png` | `textures/xdecor_woodframed_glass.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_woodframed_glass_detail.png` | `textures/xdecor_woodframed_glass_detail.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_ivy.png` | `textures/xdecor_ivy.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_cobweb.png` | `textures/xdecor_cobweb.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_itemframe.png` | `textures/xdecor_itemframe.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_rope.png` | `textures/xdecor_rope.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_rope_inv.png` | `textures/xdecor_rope_inv.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_workbench_top.png` | `textures/xdecor_workbench_top.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_workbench_bottom.png` | `textures/xdecor_workbench_bottom.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_workbench_sides.png` | `textures/xdecor_workbench_sides.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_workbench_front.png` | `textures/xdecor_workbench_front.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_cauldron_top_empty.png` | `textures/xdecor_cauldron_top_empty.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_cauldron_bottom.png` | `textures/xdecor_cauldron_bottom.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_cauldron_sides.png` | `textures/xdecor_cauldron_sides.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
| `grug_decor_xdecor_xdecor_empty_shelf.png` | `textures/xdecor_empty_shelf.png` @ `43a7753` | Gambit / kilbith / Cisoun / Wuzzy (xdecor-libre) | CC0 1.0 | rename only |
