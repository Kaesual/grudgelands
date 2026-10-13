# One hand-placed apple tree — ASTREE

Open [apple.html](apple.html) directly in a browser. Only its two pinned
three.js 0.147.0 scripts need a network connection; all five original 16 × 16
repository textures are embedded. Orbit with one pointer, zoom with the wheel
or a pinch, and pan with right-drag or two fingers. The figure is exactly two
nodes tall. The foliage switch also hides the apples to expose the skeleton.

This is a **compatible, browser-only concept artifact**. It changes no game
code, registrations, world generation, persisted state, or upgrade declaration.
The user's visual acceptance and the coordinator's independent review remain
open. No other agent was launched for this lane.

## Design

A stout, four-node-high, 2 × 2 bole establishes the slightly lollipop-like
silhouette. Three primary limbs begin together above it, then rise at different
positions: the west limb travels outward first, the southeast limb lifts a
larger cheek of foliage, and the north limb supplies the higher, slightly
off-centre crown. Thin terminal twigs support the crown's rim. There are no
root fins and no detached pieces of wood.

The canopy has a broad middle and a smaller, shifted upper dome, with an
uneven lower edge around the limb ends. The five apples are deliberately
placed beneath leaf nodes. This is one sculpture, not a procedural generator:
every occupied cell is authored in ten explicit, eight-by-eight layer drawings
in [build.py](build.py). Only the four identical trunk layers are repeated.

Bounds are **8 × 10 × 8 nodes** (x × y × z): node centres x/z −3…4 and y 0…9.
Ground is y = −0.5. The trunk's axis is (x,z) = (0.5,0.5).

| Kind | Nodes |
| --- | ---: |
| Full trunk | 0 |
| Quarter | 16 |
| Branch | 13 |
| Twig | 15 |
| Leaves | 126 |
| Fruit | 5 |
| **Total** | **175** |

There are 44 wood nodes and exactly **three wood shape definitions**.

## Exact shape definitions

All tuples below are `[x1,y1,z1,x2,y2,z2]`, in **sixteenths of one node**, with
the node centre at zero. Divide every number by 16 for Luanti. Every box is
axis-aligned and lies inside its cell.

### Quarter

Fixed node box, facedir 0–3. At rot 0 the inner corner is (+8,+8) in x/z.

```text
[-8,-8, 4, -4,8,8]
[-4,-8,-4,  4,8,8]
[ 4,-8,-8,  8,8,8]
```

The two outer seam faces are each **4/16 wide**. A rotated neighbour completes
each to a continuous **8/16 face across the node boundary**. Between these
half faces are four complete rectangular step faces. Four quarters make 20
complete exterior facets around the trunk: five per quarter when shared seam
faces are counted once. Three rectangular boxes produce the profile; there is
no diagonal chamfer or cylinder hidden behind it.

For each 90° facedir step, transform `(x,z)` to `(z,-x)` and reorder the box
minima and maxima. The trunk uses:

| Node x,z | rot |
| --- | ---: |
| 0,0 | 0 |
| 1,0 | 3 |
| 0,1 | 1 |
| 1,1 | 2 |

### Connected branch and twig

Use `node_box.type = "connected"`, **no facedir**, and a connection group shared
by every wood kind and its texture variants. Leaves and fruit do not connect.
All connected nodes in the JSON have `rot = 0`. A fixed core is always present;
each arm is present if and only if the corresponding face neighbour is wood.

| Box | Branch, 10/16 thick | Twig, 4/16 thick |
| --- | --- | --- |
| fixed | `[-5,-5,-5,5,5,5]` | `[-2,-2,-2,2,2,2]` |
| connect_top | `[-5,5,-5,5,8,5]` | `[-2,2,-2,2,8,2]` |
| connect_bottom | `[-5,-8,-5,5,-5,5]` | `[-2,-8,-2,2,-2,2]` |
| connect_front (−z) | `[-5,-5,-8,5,5,-5]` | `[-2,-2,-8,2,2,-2]` |
| connect_back (+z) | `[-5,-5,5,5,5,8]` | `[-2,-2,2,2,2,8]` |
| connect_left (−x) | `[-8,-5,-5,-5,5,5]` | `[-8,-2,-2,-2,2,2]` |
| connect_right (+x) | `[5,-5,-5,8,5,5]` | `[2,-2,-2,8,2,2]` |

Limbs climb as axis-aligned staircases. Thick-to-thin joins meet at the shared
cell face. Every wood node has a positive-area physical connection back to the
trunk, checked from its actual boxes, not just from cell adjacency.

### Textures, leaves and fruit

The quarter uses bark on its sides and `default_tree_top.png` on top/bottom;
the texture turns with facedir. Living branches and twigs use bark on all faces.
UVs are cropped to the box's position inside the node, not stretched to make
every little box carry a full 16-pixel image.

Connected shapes cannot rotate. To implement the displayed grain exactly,
register **three material variants of each connected shape**, sharing the same
boxes and connection group. Count wood neighbours along each axis; the largest
count wins, ties y then x then z. This selects the material variant, not a
geometry rotation. For y, use the ordinary bark tiles. For x, quarter-turn
the top/bottom and front/back bark tiles. For z, quarter-turn the left/right
bark tiles. The exact UV transform is `(u,v) → (1−v,u)`; the page's `uvAt`
defines the base face mapping. All boxes of a node inherit the same six tiles;
there is no per-arm material trick that connected node boxes cannot reproduce.
These are three shapes total, not extra geometric variants. Future game
registration should make every variant drop the normal trunk item.

Leaves are full `[-8,-8,-8,8,8,8]` cubes with all six textured faces, alpha
test 0.5 and nearest filtering. Apples reproduce the existing `default:apple`
plantlike drawtype, visual scale 1: two double-sided unit quads at 46° and −44°.
They are the existing fruit drawing, not a fourth wood shape or a rotated wood
box. There is no leaf tint, random rotation, texture replacement or mesh asset.

Engine facts were checked read-only in the pinned reference available in the
main checkout: `src/mapnode.cpp` (`transformNodeBox`), and
`src/client/content_mapblock.cpp` (`generateCuboidTextureCoords`,
`drawNodeboxNode`, `drawAllfacesNode`, `drawPlantlike`). The existing fruit
definition is in `mods/BASE/default/nodes.lua`. The preview's daylight and
shadow shading illustrate the form; they do not simulate Luanti lighting.

## Files and reproduction

- [apple.html](apple.html): ready-to-open, self-contained viewer with pinned
  CDN scripts, embedded textures, counts, shape panel and JSON copy control.
- [apple-nodes.json](apple-nodes.json): the exact rendered node list,
  `{x,y,z,kind,rot}`, in layer/row/column order.
- [build.py](build.py): the hand-drawn layers, sole shape definitions, texture
  embedding and deterministic packer.
- [apple.template.html](apple.template.html): viewer source; both this file and
  `build.py` are needed to regenerate the HTML.
- [check_data.mjs](check_data.mjs): syntax, source equality, shape, physical
  connectivity, support, fruit and embedded-texture checks without a browser.
- [check.mjs](check.mjs): optional Chromium/DevTools browser checks and captures.
- [preview.py](preview.py): independent software rasterizer for inspecting the
  geometry when Chromium cannot start; requires installed NumPy and Pillow.
- [evidence/software-tree.png](evidence/software-tree.png) and
  [evidence/software-skeleton.png](evidence/software-skeleton.png): geometry
  inspections, **not browser screenshots**. They omit viewer UI, the scale
  figure and browser shadows.
- [LICENSE-media.md](LICENSE-media.md): source texture and preview attribution.

From the repository root:

```sh
python3 tools/r46_tree/astra/build.py
python3 tools/r46_tree/astra/build.py --check
node tools/r46_tree/astra/check_data.mjs
python3 tools/r46_tree/astra/preview.py
python3 tools/r46_tree/astra/preview.py --skeleton
```

On a host where Chromium may start:

```sh
node tools/r46_tree/astra/check.mjs --chrome /path/to/chromium
```

Optionally pass `--vendor /path/to/cache` containing `three.min.js` and
`OrbitControls.js` from the exact two 0.147.0 CDN URLs. This intercepts only
those requests during testing; it does not alter the distributed page. The
check verifies revision 147, rendered vertex counts, controls, camera presets,
320/390/760/1024/1440-pixel layouts, clipboard success/fallback, and browser
errors. It writes screenshots during the run and a receipt only on success,
under `evidence/`. Node 22+ is needed for its built-in WebSocket client.

## Verification in this lane

`build.py --check` and `check_data.mjs` pass: the JavaScript parses under Node,
the external JSON equals the page's actual data, all 44 wood nodes connect
physically, every leaf has nearby support, every apple has a leaf immediately
above it, and all five embedded PNGs exactly match their repository sources.
The software previews were inspected for silhouette and growth structure.

**Actual browser verification is open.** This session's sandbox prevents
Chromium from starting (`setsockopt` / `shutdown: Operation not permitted`).
The CDN is also unreachable from the shell. No successful WebGL, clipboard or
phone-layout run is claimed. The optional browser runner is supplied so the
coordinator can complete those checks on an unrestricted local host.

The release-mode source audit (`python3 tools/check_fresh_server.py`) passes.
The complete portable fixture run passes **172/172**;
receipt: [evidence/fixtures.log](evidence/fixtures.log).
No engine run or seed fleet is applicable to this standalone concept: no game
or mapgen file changed.
