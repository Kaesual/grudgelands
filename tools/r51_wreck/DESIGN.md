# Round 51 lane WRECK — shipwreck design

The design step of lane WRECK ([round plan](../../docs/planning/round51-plan.md)
§1, [sea plan](../../docs/planning/round51-sea-plan.md) ruling 20 and §5a):
four wreck shapes of our own, the node list, the masts against the water
depth, and a placement sketch for the build step. Nothing here ships; the
user picks on the preview page, then the build step (nodes, schematics,
placement) runs in the same worktree.

```sh
python3 -I tools/r51_wreck/shapes.py           # write shapes/*.json (--check, --print)
python3 -I tools/r51_wreck/build.py            # write wreck.html (+ wreck_local.html for file://)
python3 -I tools/r51_wreck/build.py --check    # fail if wreck.html is stale
```

`wreck.html` is the page content for the publisher (no document tags);
`wreck_local.html` wraps it for `file://` and is not committed. The page
inlines the shapes, ARTS's textures (`tools/r51_sea`) and the default sand,
water, mossy cobble and player skin; three.js r147 comes from jsdelivr, as
in `tools/r47_sw`. Its mesher is a copy of `tools/r47_sw/view.js`'s.

## 1. Engine facts (re-checked in `reference_projects/luanti`, Luanti 5.17)

| Fact §5a relies on | Result | Where |
|---|---|---|
| Water draws a side face against every neighbour but the same liquid or a neighbour of solidness 2 | confirmed | `src/client/content_mapblock.cpp` `drawLiquidSides` (`neighbor_features.visuals->solidness == 2` skips) |
| Solidness 2 only for `normal` and `plantlike_rooted` (and `allfaces_optional` under the opaque leaves style, drawn as normal) | confirmed | `src/client/node_visuals.cpp` `ContentFeatures::updateTextures`, the drawtype switch |
| `plantlike_rooted` = the base cube plus a plantlike extension in the node above, no air pocket | confirmed | `content_mapblock.cpp` `drawPlantlikeRootedNode` (`drawSolidNode`, then `drawPlantlike(tile, true)` one node up); `doc/lua_api.md` "plantlike_rooted" |
| With `paramtype2 = "leveled"` the extension is `param2 / 16` nodes high, the full param2 range (≤ 15.94) | confirmed, **refined**: the height is `visual_scale * param2 / 16` | `drawPlantlike` (`CPT2_LEVELED`: `plant_height = param2 / 16`), `drawPlantlikeQuad` (top at `-BS/2 + 2 * scale * plant_height`, `scale = BS/2 * visual_scale`); `lua_api.md` "Can use the full param2 range" |
| The texture repeats upward like kelp | confirmed: tiled `plant_height` times (v from 0 at the top to `plant_height` at the bottom), so the top of the texture is at the top and a fractional height cuts the bottom tile | `drawQuad(..., vertical_tiling)` called with `plant_height` |
| A rooted extension above the water surface draws in the air | confirmed: drawn regardless of the nodes it passes ("visually passes through any nodes above the base cube"); the block mesh's culling sphere comes from its vertices, so a tall mast is not culled early | `lua_api.md`; `src/client/meshgen/collector.cpp` (bounding radius from vertices), `clientmap.cpp` |
| Two crossed quads (an X from above) | confirmed: quads at 46° and -44° (`PLANT_STYLE_CROSS`); `meshoptions` styles are not available together with `leveled` | `drawPlantlike` |
| Sideways only one node long | confirmed: `wallmounted` moves the extension to a side (`DWM_XN/XP/ZN/ZP`) or below (`DWM_YP`, hanging), height 1, and excludes `leveled` (one `paramtype2`) | `drawPlantlike` (`is_rooted` block) |
| No collision, not dug on its own | as §5a (the extension is mesh only; the node is the base) | — |

**New, changes the look (not the design): the light.** The whole extension
is lit with the light of the node just above its base
(`drawPlantlikeRootedNode`: `getInteriorLight(ntop)`, or the smooth-light
frame of that node, clamped by `SMOOTH_LIGHTING_OVERSIZE` in `blendLight`).
Under water the daylight falls one level per node (`voxelalgorithms.cpp`:
`spread - 1`; `default:water_source` has no `sunlight_propagates`), so a
mast standing on a deck 10 nodes under the surface is drawn at light 5
(about 29 % brightness on Luanti's default light curve, `light.cpp`) over its
whole height, also the part in the air. Its in-air part is a dark pole. The
same light rule makes the seabed below about 12 nodes nearly black by day
(light 3 and less). The page shows both ("Luanti light").

## 2. The shapes

All four come from `shapes.py` (second version, after the user's first look
on 2026-10-19: masts clearly shorter, less blocky). The hull, bow and stern
are cut from one hull form, a small single-masted coastal ship of our own:

- **Silhouette:** the form narrows toward the bow (a pointed stem with a post
  one node over the bow), toward the rounded stern and toward the keel (the
  half-width grows with the height to the power 0.7, a V-to-U section), with
  sheer and a rising bow, a stern deck one node higher.
- **One block of planking:** only the cells of the form with an open face
  are built (the shell, the deck, a one-block rail); inside is water.
- **Keel and ribs:** a log keel along the bottom; a rib every third station
  that shows as a log only where the planking beside it is gone, a deck beam
  across the deck where the deck is gone; under whole planking it stays a
  plank.
- **Damage in patches:** smooth noise takes planking away in irregular
  holes (shell regions per shape), most of the deck down to its beams and
  half the rail; the bow and stern parts break raggedly, ribs and keel
  reaching two nodes past the break.
- **Sunk unevenly:** heeled about the long axis and pitched along it, then
  the lowest two layers go into the sand, so one end and one side lie
  deeper.
- **Around it:** loose planks (some flush in the sand) and short timbers
  within three nodes of the wreck; algae planks on about 40 % of the open
  planks, algae tufts, ropes and sail tatters on open planks.

The debris field is laid out by hand plus the same scatter. Damage comes
from a fixed integer hash; pieces that hang in the water are removed.

| Key | Shape | Size x × y × z | In the sand | Over the sand | Masts and details |
|---|---|---|---|---|---|
| `wreck.hull` | whole hull, listing 16°, stern deeper (pitch 4°) | 22 × 10 × 11 | 2 layers | 8 | broken main mast 6 (param2 96), 2 ropes, 2 sail tatters, 4 algae tufts, 32 algae planks |
| `wreck.bow` | front half on its side (40°), nose dug in, broken behind the main mast | 14 × 8 × 12 | 2 | 6 | rope, 3 algae tufts |
| `wreck.stern` | back half with the stern deck, listing the other way (-18°), broken end deep in the sand | 15 × 10 × 11 | 2 | 8 | main mast stump 4.5, 2 sail tatters, rope, 3 algae tufts |
| `wreck.debris` | keel piece with an uneven rib cage, fallen mast of logs, flat hull panel, loose planks and timbers, ballast heap | 15 × 4 × 15 | 1 | 3 | sail tatters, 4 algae tufts |

Only the whole hull is longer than 16 (22 with its loose planks, 20 the
hull itself); the template bound question stays open (§5).

**Shape files** (`shapes/<name>.json`, schema `grug_r51_wreck_shape_v1`):
`size`, `seabed` (the number of layers below the top of the sand; layer
`seabed` is the first above it), `palette` (one letter → `{name, param2}`;
`.` keeps what the world has there: water, or sand below the seabed) and
`layers` from the bottom up, each a list of rows (z) of letters (x). x runs
along the ship (bow at +x), z across, y up. Logs carry facedir (0 upright,
4 along z, 12 along x); the mast carries its height as leveled param2. A
schematic follows mechanically: `.` → `air` with probability 0 (a WP40
template's `air` emits nothing, `r6_templates.lua` and contract §8.3), every
other letter → its node and param2, probability 254; the sunk layers
`force_place` (§5).

## 3. Node list

Proposed in `grug_nodes` (the build step may pick another grug mod); every
block drops an ordinary block (round plan §4.1). Textures are ARTS's
(`tools/r51_sea`, CC0, merged 101f2091).

| Key | Node | Drawtype, paramtype2 | Tiles | Drops |
|---|---|---|---|---|
| `wreck.planks` | `grug_nodes:wreck_planks` "Waterlogged Planks" | normal | `wreck_planks` | `default:wood` |
| `wreck.planks_algae` | `grug_nodes:wreck_planks_algae` "Waterlogged Planks with Algae" | normal | `wreck_planks_algae` | `default:wood` |
| `wreck.log` | `grug_nodes:wreck_log` "Waterlogged Log" | normal, facedir | `wreck_log_top` (ends), `wreck_log` | `default:tree` |
| `wreck.mast` | `grug_nodes:wreck_mast` (base: waterlogged planks) | plantlike_rooted, leveled, waving 0 | base `wreck_planks`, special `wreck_mast` (tileable vertical) | `default:wood` |
| `wreck.rope` | `grug_nodes:wreck_rope` (base: waterlogged planks) | plantlike_rooted, none (1 node), waving 1 | base `wreck_planks`, special `wreck_rope` | `default:wood` |
| `wreck.sail` | `grug_nodes:wreck_sail` (base: waterlogged planks) | plantlike_rooted, none, waving 1 | base `wreck_planks`, special `wreck_sail` | `default:wood` |
| `wreck.algae` | `grug_nodes:wreck_algae` (base: algae planks) | plantlike_rooted, none, waving 1 | base `wreck_planks_algae`, special `wreck_algae` | `default:wood` |
| `wreck.ballast` | `default:mossycobble` (exists) | normal | default | itself |

Seven new nodes. The log is new on ARTS's recommendation (default bark with
a pale sawn end looks new beside the wreck wood); `default:pine_tree` is the
existing fallback. The details are one node high (their textures touch the
bottom edge); only the mast is leveled. All new nodes join the closed roster
in `r7_content.lua` and the decoration role (round plan §4.6).

## 4. Masts and the water depth

| Shape | Mast | Deck over the sand | Top over the sand | Reaches the surface at depths up to (visual_scale 1 / 1.5 / 2) |
|---|---|---|---|---|
| whole hull | broken main mast 6 (default) | 4 | 10 | 9 / 12 / 15 |
| whole hull | option: 8 | 4 | 12 | 11 / 15 / 19 |
| whole hull | option: whole 15.9 (first version) | 4 | 19.9 | 19 / 27 / 35 |
| stern | main mast stump 4.5 | 4 | 8.5 | 8 / 10 / 12 |
| bow, debris | none (the bow's foremast is gone; the debris's mast lies as logs) | | | |

(Depth = nodes of water above the sand. A mast reaches the surface when its
top is above the surface: `top = base_y + 0.5 + visual_scale * param2 / 16`
in node coordinates with the sand's top at -0.5, reaches up to depth
`ceil(top + 0.5) - 1`.)

**The band the design needs: a seabed 8 to 14 nodes deep** (bow from 6,
debris from 3), **8 to 12 at its best** — unchanged in its reasons: at 8
the whole hull (8 over the sand) lies just under the surface, so boats pass
over it; below about 12 the sand is nearly black by day (light ≤ 3) and the
wreck is hard to see.

**The goal changes from "a mast above the water" to "a mast near the
surface".** The user found the full mast clearly too long; a broken mast of
6 ends a few nodes above the deck, so it just breaks the surface (by 1–2
nodes) only where the seabed is 8–9 deep and ends 1–4 nodes under it at
10–13 — a dark pole seen from a boat, or a stump a swimmer finds. Keeping
"above the water" everywhere would need the long mast back or a shallower
band, where the hull itself would break the surface. Mast options for the
user (key `wreck.mast_height`, the page's mast control): broken 6 (default),
8, the whole 15.9, visual_scale 1.5 or 2, or the build step sets the main
mast's param2 from the depth at placement so its top just reaches the
surface (1 node above) wherever it can.

## 5. Placement sketch (for the build step)

- **Where:** the seabed of the coastal belt and the bays, inside the
  protected water (S8: 24 nodes or more from the coast, so nobody digs the
  wrecks for wood), seabed depth 8–14 (bow 6–14, debris 3–14). Not in the
  dragon channels (boats need their 9–11 nodes) and not in the open sea.
- **How many:** a few per coast: one candidate per 256 × 256-node cell of
  belt or bay water, the root the lowest-hash column of the cell that passes
  every test, accepted with a chance so a zone's coast holds about two to
  four; shape by hash (hull, bow, stern, debris about evenly), a quarter turn
  by hash.
- **Clear of settlements, POIs and roads:** the protected-water test keeps
  them off the shore; in addition the whole footprint plus 16 nodes must be
  free of every settlement, POI and route exclusion the decoration rows
  already test (`exclusion_reason`, `static_exclusion_reason` in
  `r6_settlement.lua`), and the footprint must not reach a column that is
  not protected water.
- **On the seabed:** the seabed under the footprint varies by at most one
  node; the template's `seabed` layer sits on the lowest sand column of the
  footprint; the sunk layers and any cell that meets sand replace the sand
  (`force_place`); every other cell replaces water; `.` keeps.
- **Mechanism:** a WP40 decoration row with a schematic, as the land kit
  will, with three extensions the current rows lack (re-check each in the
  build step):
  1. a **seabed root**: rows count only columns with `surface_y >= 1`
     (contract §8.2; `r7_p9g.lua` the same for plant rows), and a cell over
     anything but air or natural vegetation is refused unless
     `force_place` (`r6_settlement.lua`, the clearance loop near
     `decoration_support_ref`) — water must count as clearance for wreck
     rows, and the host is sand (or gravel) under water;
  2. the **template bound**: templates are at most 16 × 64 × 16
     (`r6_templates.lua` `read_source`; contract §8.3); the whole hull is
     22 long with its loose planks (20 the hull), so either the bound is
     raised for wreck rows (to 24) or the hull is shortened to 16
     (Questions); bow (14), stern (15) and debris (15) fit;
  3. the **owner cube**: a footprint must lie inside one 80³ owner
     (contract §8.2, "Treeless bands"); a 22-node hull is clipped more
     often, which only thins out the few candidates.
- **From T2** (round plan §2): the water query per column — class (belt or
  bay), protected or not, depth and distance to dry land — and the depth
  profile of the belt, to confirm that enough belt and bay seabed lies at
  8–14.
- **Cost:** one candidate per 256² cell, a footprint check and at most ~350
  cell writes per accepted wreck; the build step reports mapgen time before
  and after. The placement is part of the one map reset.
- **First in-game test:** a mast on a test wreck (§5a).
