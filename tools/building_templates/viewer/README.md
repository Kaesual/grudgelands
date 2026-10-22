# Town viewer and template gallery (`tools/building_templates/viewer`)

Three.js pages that show Luanti nodes block for block from the real node
registry (`../nodes.json`): the **town viewer** (`town.html`, the start towns
from the settlement blueprints) and the **template gallery** (`gallery.html`,
every building template of
[building-template-format.md](../../../docs/technical/building-template-format.md)).
Both are viewers, not editors, and both are built on one shared node renderer
(`renderer.js`) that the template editor reuses. They exist to look at blocks
and placement with people who do not run Luanti (design feedback), without a
server boot per change. Moved here from branch `town-viewer` (0.50.0) in
Round 56.

## Parts

| File | Role |
| --- | --- |
| `renderer.js` | the shared node renderer (ES module): geometry for node cells (shapes, rotations, textures, node boxes, meshes), the orbit / walk / noclip cameras with a touch fallback, picking |
| `build_viewer.py` | builds the town viewer as one self-contained HTML page (Python 3 + Pillow); also the shared page helpers (node types, textures, meshes, `inline_renderer`, `write_page`) |
| `export_blueprint.lua` | plain LuaJIT exporter: cells plus named landmark boxes and points |
| `town.html` | the town page: town choice, labels, inspector, view codes, workshop diffs |
| `../nodes.json` | the real node registry (see `../README.md` for refreshing it) |

### The shared renderer

`renderer.js` is one plain ES module with no framework. `createNodeView({stage,
types, textures, meshes, onPick, onFrame})` returns a view with `setData(cells)`
(cells from `cellData(X, Y, Z, T, P2)` or the build's `decodeCells`),
`rebuild()`, a `filter` (`cut`, `veg`), `setMode("orbit"|"walk"|"noclip")`,
`lookAt`, `walkFrom`, `pose`, `pick`, `select`, `start` and `step`. A page
served as files imports it directly (with the same importmap for `three`); the
self-contained pages get it inlined at `__RENDERER__` by
`build_viewer.inline_renderer`, which drops its import lines and `export`
keywords. Node types come from `build_viewer.build_types`.

## Build

```sh
# all six start towns, the page as published (no <html> wrapper)
python3 tools/building_templates/viewer/build_viewer.py -o /tmp/start-towns.html

# one town, or any blueprint chunk, as a file to open locally
python3 tools/building_templates/viewer/build_viewer.py dawnmere --standalone -o /tmp/dawnmere.html
python3 tools/building_templates/viewer/build_viewer.py path/to/r7_x_blueprint.lua --standalone -o /tmp/x.html
```

A build of all six towns takes about 1 s and writes about 4 MB (Round 56).
Unresolved textures, meshes and undrawn drawtypes go to stderr.

Local preview hooks (query string, ignored inside the artifact frame):
`?town=<key>`, `?view=<view code>`, `?walk=x,y,z,yaw`,
`?noclip=x,y,z,yaw,pitch` (feet position), `?cut=<y>`, `?veg=0`,
`?pick=<px>,<py>`. A headless screenshot:

```sh
chromium-browser --headless=new --use-angle=swiftshader --enable-unsafe-swiftshader \
  --user-data-dir=/tmp/viewer-profile --window-size=1400,900 \
  --virtual-time-budget=20000 --screenshot=/tmp/shot.png \
  "file:///tmp/dawnmere.html?view=dawnmere@30,12,-8>12,4,14"
```

Use one `--user-data-dir` per parallel Chromium; a shared profile makes the
second instance exit without a screenshot.

## Refreshing the node registry

The registry is `../nodes.json`, shared with the template validator; see
[`../README.md`](../README.md#refreshing-it). It only changes when node
definitions change; blueprint and template edits never need it.

## What the page approximates

- **Shapes** are exact for full cubes, fixed, connected and wallmounted node
  boxes, and `.obj`/`.b3d` meshes, with `facedir`/`4dir`/`wallmounted`
  rotation as Luanti applies it. Plantlike nodes are two crossed quads.
- **Light** is Luanti's per-face shading plus a simple per-vertex ambient
  occlusion on full cubes and leaves. There is no day/night, no light from
  torches and no smooth lighting on node boxes.
- **Textures**: the first frame of animated tiles; `world`-aligned tiles use
  world coordinates. Node colour palettes (`param2` colour) are ignored.
- **Walking**: collision uses the node boxes of walkable drawtypes; doors are
  passable, plants and torches are not solid. Step height 0.6, eye 1.625.
  `W` `A` `S` `D` walk, drag to look, `Space` jumps, `Shift` runs.
- **Noclip** flies through everything: `W` `A` `S` `D` along the look
  direction, drag to look, `Space` up, `Shift` down, hold `E` for faster (the
  game's fly keys). It starts where the camera is. On a touch screen walk and
  noclip show a move pad and Up/Down (or Jump) buttons; one finger drags to
  look while another holds a button.

## View codes and the inspector

"Copy" in the panel produces a view code such as
`dawnmere@30,12,-8>12,4,14`: town, camera position, look-at point, all in the
blueprint's local Luanti coordinates (x east, y up, z north). Clicking a block
shows its node name, `param2`, coordinates and the building whose landmark
box contains it; "Copy" there yields `dawnmere 12,3,-20 default:cobble
(harvest_inn)`. Both are meant to be pasted into feedback verbatim.

## Town workshop: rebuilding a town by hand

Carried over unchanged from branch `town-viewer` (only its paths moved); it
waits for a later use (the town workshop evening with players, Round 56 plan
§8) and was not rerun in Round 56. Once the template freeze (Round 56) has
merged, the town buildings are edited in the templates, so a ported diff goes
into the templates, not the Lua blueprint code.

For design passes done directly in Luanti. A designer rebuilds the town in a
local creative world, the result is diffed against the untouched town, and
the diff is ported into the Lua blueprint by hand (the blueprint is
procedural, so a cell diff is a specification, not a patch).

| File | Role |
| --- | --- |
| `make_workshop.sh` | builds a package from one git ref: that ref's game plus a world with the town generated and a baseline export |
| `grug_town_workshop/` | dev-only world mod (never in `mods/`): building rights, `/town_go`, `/town_export` |
| `diff_town.py` | places the blueprint in the world and diffs the designer's export against the baseline |

```sh
# 1. package for the designer, from the version they will play
tools/building_templates/viewer/make_workshop.sh -r main -t dawnmere      # ~1 min, ~90 MB
# 2. the designer works, then runs  /town_export dawnmere designer
# 3. diff and look at it
python3 tools/building_templates/viewer/diff_town.py dawnmere \
    --baseline <world>/town_exports/dawnmere-baseline.tsv \
    --after <world>/town_exports/dawnmere-designer.tsv --json /tmp/diff.json
python3 tools/building_templates/viewer/build_viewer.py dawnmere --standalone -o /tmp/cmp.html \
    --compare "dawnmere=<baseline.tsv>,<designer.tsv>,designer"
```

`make_workshop.sh` checks the ref out into a temporary detached worktree and
generates the world with that ref's `tools/luanti_headless.sh` (isolated,
nothing under the personal Luanti folder is touched). The seed is fixed
(20261016) so that a verification world built later from the changed
blueprint has the same terrain: after porting, build a package from the
branch and diff its baseline against the designer's export.

Diff rules worth knowing:

- Only `after` against `baseline` is compared, both from the same world, so
  mapgen's own fitting never shows. Without `--after` the tool reports how far
  the baseline already differs from the blueprint (Dawnmere at 0.50.0: none).
- The export window hangs off the ground height of the baseline export
  (stored in mod storage), so building at the anchor does not shift it. If
  two windows still differ, the summary says how much was not compared.
- World noise is listed separately with positions (`noise_cells` in the
  JSON), never dropped: crop growth (group `plant`), doors opening (a<->c,
  b<->d; a<->b is a hinge edit), gates opening, furnaces lighting, apples
  picked or regrown on trees (param2 0; a hand-placed apple has param2 1),
  grass under a new block turning to dirt, flowing water, soil getting wet.
  Grass spread is off in towns, so dirt -> grass is always an edit.
- `inside_blueprint: false` marks changes outside the start-town bounds
  contract (x/z [-63, 63], y [-2, 24]); they cannot be ported as they are.
