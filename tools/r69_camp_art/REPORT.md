# Round 69 CAMPART delivery

Delivered 2026-11-04 on branch `r69-campart`, in the assigned worktree only.
**Compatible tooling only.** No game files, version, upgrade declaration or
saved state changed. Lane CAMP owns integration and the live-world migration.

## Variants and recommendation

| Variant | Construction idea | Assessment |
|---|---|---|
| **A — Wallwright** (`wallwright`) | A finished west wall, an east working scaffold and successive bays of panels, first courses, footings and survey stakes. | The clearest wall-building sequence and the most enclosed layout. |
| **B — First Lift** (`first_lift`) | One upper headframe portal above a complete lower ring and working deck; a rope hoist, covered shaft collar and staked rear perimeter. | **Recommended:** the strongest distant silhouette, and an immediately recognizable earlier stage of a mining camp. |
| **C — Panel Yard** (`panel_yard`) | Two long worker tents, three assembled wall bays in racks, cut timber and masonry stacks, and marked foundations. | The strongest sense of organized construction; lower and broader, with less emphasis on the future mine. |

All three have the finished roofed gate, faction banners with supports,
central command tent and five fixed guard/captain positions. No new nodes or
textures are proposed. No placeholders are needed.

## Deliverables

- [Single-file pick page](index.html): 24 interactive scenes, today's camp
  beside the three proposals; faction and race selectors, five linked camera
  presets, orbit/zoom/pan, block inspection and optional socket markers.
  Everything needed for display is embedded, including the JavaScript library
  and the still overview. No external requests or repository file links.
- [Overview PNG](renders/overview.png): all variants, gate quarter / far side /
  plan, in Human and Orc materials. Eighteen separate 1200 × 900 PNGs also
  live in `renders/`. These use the shared viewer's actual geometry.
- Eighteen ordinary templates in `candidates/<variant>/camp_site_<race>.tpl`,
  generated from one race-neutral composition per variant by [build.py](build.py).
- [Rebuild instructions and export details](README.md), [render.py](render.py),
  and the exact resolved [node inventory](nodes.json).

The source claim was confirmed: the shipped construction blueprint uses wool
roofs and uneven palisade posts; the finished camps use the newer canvas,
stockade, cap, ridge and banner pieces. The three proposals use those shipped
pieces and the existing race palette roles.

## Verification

**All six races pass every candidate's parser checks:** Dwarf, Human, Elf,
Orc, Undead and Troll. Both existing Python parsers and the existing game Lua
parser accept all 18 files. The game's loader/resolver and `parts.stamp`
successfully build all four quarter turns for each template: **72 stamps**.

Every candidate has:

- `origin -11 0 -11`, `size 23 10 23`, extent `[-11,-11,11,11]`;
  5290 explicit cells, including force-air cells, with no unchanged cells;
- a solid 23 × 23 ground layer and a clear central 5 × 5 × 3 yard;
- the exact five requested `camp_points`, including faces, open at y=1 and
  y=2 with solid support; flat, two-cell-high routes from the gate;
- orientable canvas, panels, caps, banners, slabs and ladders; all rendered
  geometry, including mesh overhangs, within the physical cell box;
- no containers, inventories, timers, fire, liquids, construction callbacks
  or working lift node.

`python3 tools/r69_camp_art/build.py --check` **PASS**:

```text
Offline comparison: 24 scenes, 79 node types; no missing textures or meshes.
Round 69 CAMPART: 18 templates verified; both Python parsers and the game Lua parser PASS; 72 native rotated stamps PASS; box, floor, yard, sockets and flat routes PASS.
```

The byte comparison covers the templates, node inventory and generated HTML.
The still images are regenerated with `render.py`, then embedded by `build.py`.
Additional checks passed: JavaScript parsing for every embedded script, all
24 shared-renderer geometry exports, all 18 candidate mesh bounds, all 19 PNGs
decoding, standalone HTML resource references, changed documentation links
and `git diff --check`. Human and Orc overview views were inspected, plus
First Lift in the other four palettes.

No fixture suite, game Lua changes or server runs were made, as requested.
The full template integration gate remains lane CAMP's responsibility.

## Node list per variant

[**nodes.json**](nodes.json) is the complete literal list for each variant,
then each of the six races; `air` is excluded from its counts. The compact
construction vocabulary is:

| Variant | Resolved union across six races | Additional nodes beyond the common vocabulary |
|---|---:|---|
| Wallwright | 63 | `default:ladder_wood` |
| First Lift | 65 | `default:ladder_wood`, `grug_decor:darkage_iron_grille`, `grug_decor:xdecor_rope` |
| Panel Yard | 62 | None |

Common fixed nodes/families (suffixes resolve to the template's race/faction):

```text
grug_decor:cottages_straw_mat
grug_decor:cottages_table
grug_mapgen:camp_canvas
grug_mapgen:camp_ridge
grug_mapgen:camp_stockade_<race>
grug_mapgen:camp_wall_cap_<race>
grug_mapgen:camp_trim_<faction>
grug_mapgen:faction_banner_<faction>
```

Common palette roles, resolved by the game's `wp13/palette.lua`:

```text
beam  fence  floor  foundation  ground  ground_bare
path  post  roof_slab  tree_log
```

The complete lists include their literal ground, timber, masonry and slab
node names. Distinct node counts per race:

| Variant | Dwarf | Human | Elf | Orc | Undead | Troll |
|---|---:|---:|---:|---:|---:|---:|
| Wallwright | 17 | 16 | 17 | 17 | 17 | 17 |
| First Lift | 19 | 18 | 19 | 19 | 19 | 19 |
| Panel Yard | 16 | 15 | 16 | 16 | 16 | 16 |

## Blockers / questions

The user's pick is pending. No art-production blocker remains.

**Could not perform a real browser interaction check:** Chromium was rejected
by the environment before loading the page (denied socket operations). The
page and its controls were built, its scripts parse, and its geometry/media
were checked; browser rendering, touch and interaction still need a check
outside this sandbox. The delivered PNGs were rendered without Chromium.
No desktop/web game runtime acceptance is claimed.

The shared viewer's static B3D export initially magnified the animated camp
meshes by ten and collapsed the banner's three buffers into one. The local
export adapter corrects scale and buffer ordering using the shipped art
writer's format. No shared viewer or game source was changed. The adapter,
Three.js r147 color-property bridge and software-render limitations are
explained in the README. Terrain, NPCs and engine lighting are not simulated.

Independent review belongs to the coordinator and has not been claimed as
complete by this art lane. Nothing was merged or pushed.

## Commits and working tree

- `f5c5e984`: template generator, 18 candidates and resolved node lists.
- **Final art commit: `89faf9aa0c45d19d1f9de64eefa39d80e9b4fe43`**:
  offline page, renders, controls and rebuild documentation.
- The final report receipt is the commit containing this file. Its exact hash
  is returned in the handoff message and can be resolved with
  `git log -1 --format=%H -- tools/r69_camp_art/REPORT.md`.

All commits end with the requested GPT-6 Astra co-author trailer. Changes are
confined to `tools/r69_camp_art/` and one added line in `tools/README.md`.
The pre-receipt working tree was clean; the final handoff checks
`git status --porcelain` after committing this receipt and reports its result.
