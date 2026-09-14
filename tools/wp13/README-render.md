# Textured blueprint renderer (`tools/wp13/render_blueprint.py`)

Renders a settlement blueprint with the **real node textures** in a dimetric
2:1 isometric view, so an agent that cannot open the game GUI can still judge
whether a building *looks* right.

This complements `tools/wp13/preview.py`, which stays the fast symbolic-colour
overview for layout/footprint questions. Use `preview.py` to check *where*
things are, `render_blueprint.py` to check *how they look*.

## Parts

| File | Role |
| --- | --- |
| `render_blueprint.py` | the renderer (Python 3 + Pillow only) |
| `dump_blueprint.lua`  | plain Lua 5.1 dumper: blueprint → TSV of cells |
| `extract_tiles.py`    | static scanner of mod sources → `node_tiles.json` |
| `node_tiles.json`     | generated node → tiles/drawtype/shape map |

## Quick start

```sh
python3 tools/wp13/render_blueprint.py \
    mods/MAPGEN/grug_mapgen/wp40/r7_hearthpine_blueprint.lua \
    -o /tmp/hearthpine.png
```

A `.lua` input is piped through `dump_blueprint.lua` automatically (the first
of `luajit`, `tools/bin/lua51`, `lua5.1`, `lua` that exists; override with
`--lua`). A `.tsv` input is read directly and must carry one
`x<TAB>y<TAB>z<TAB>name<TAB>param2` per line — handy when rendering the same
blueprint many times:

```sh
luajit tools/wp13/dump_blueprint.lua <blueprint.lua> > /tmp/cells.tsv
python3 tools/wp13/render_blueprint.py /tmp/cells.tsv -o /tmp/out.png
```

`dump_blueprint.lua` needs no engine. It installs inert `core`/`minetest`/
`vector` stubs only as insurance: a blueprint that really calls the engine
fails loudly naming the entry point instead of emitting wrong geometry.
`r7_hearthpine_blueprint.lua` reads only `ipairs`, `pairs` and `table`, so no
stub is touched, and PUC 5.1 and LuaJIT produce byte-identical TSV.

## Options

| Option | Effect |
| --- | --- |
| `--view ne\|nw\|sw\|se` | rotate the model in 90° steps; `ne` (default) puts the camera over the `+x/+z` corner. Rotates `facedir` and `wallmounted` `param2` with it. |
| `--ymax N` | drop cells above local y = N — the interior cutaway |
| `--ymin N` | drop cells below local y = N |
| `--region X1 Z1 X2 Z2` | crop to a local x/z rectangle (applied before rotation, i.e. in blueprint coordinates) |
| `--scale N` | pixels per node, default 16 |
| `--max-pixels N` | auto-reduce `--scale` until neither side exceeds this (default 4000) |
| `--light` | night mode: darken everything, warm radial glow around light sources |
| `--background '#rrggbb'` | page colour |
| `--tiles PATH` | alternative `node_tiles.json` |
| `--texture-root DIR` | extra tree to search for `textures/` (repeatable) |

Useful recipes:

```sh
# interior cutaway of the whole village
python3 tools/wp13/render_blueprint.py <bp.lua> --ymax 6 -o /tmp/inside.png

# one building, large, from the back
python3 tools/wp13/render_blueprint.py <bp.lua> \
    --region -34 -8 -18 12 --view sw --scale 32 -o /tmp/hall.png

# lighting review
python3 tools/wp13/render_blueprint.py <bp.lua> --light -o /tmp/night.png
```

Statistics, unresolved node names and texture warnings go to **stderr**; only
the PNG is a product, so the tool is safe to pipe.

## Regenerating `node_tiles.json`

`extract_tiles.py` is a pragmatic static scanner, not a Lua interpreter. It
tokenises Lua well enough to find balanced call arguments and table literals,
and understands `register_node` (including a `local def = {...}` passed by
name), the `stairs.register_stair*/slab` family (stairs and slabs inherit the
base node's tiles), `default.register_fence[_rail]`, `doors.register`,
`doors.register_trapdoor`, `doors.register_fencegate`, `beds.register_bed`,
`xpanes.register_pane` and `walls.register` — plus local wrappers whose name
merely *ends* in one of those (`my_register_stair_and_slab`).

```sh
python3 tools/wp13/extract_tiles.py \
    --root mods \
    --root reference_projects/minetest_game/mods \
    --relative-to . \
    --out tools/wp13/node_tiles.json
```

Roots are scanned in priority order: the first definition of a node wins, so
`mods/` shadows the reference copy. The reference root is included because
`doors`, `beds`, `xpanes`, `wool`, `vessels` and `walls` are about to be
vendored; nothing is copied out of `reference_projects/`. In a git worktree
those submodules are usually unpopulated — run the extractor from the main
checkout with `--relative-to <main checkout>` so the stored paths stay
repo-relative, and render with
`--texture-root <main checkout>/reference_projects/minetest_game/mods`
(a `--texture-root` scan replaces any mapping whose file is not on disk, so
it repairs exactly the missing half).

Names that resolve to no texture fall back to `<mod>_<name>.png` in the mod's
`textures/` (this is what makes `wool:red` and other loop-registered nodes
work), then to a deterministic flat colour, and the name is listed under
`UNRESOLVED` on stderr. `MANUAL_OVERRIDES` at the bottom of `extract_tiles.py`
is the place for the handful of nodes static scanning cannot reach (the
torches, whose tiles are an animated mesh texture).

Supported texture modifiers: `^` overlay, `[transformR90/R180/R270/FX/FY`,
`[colorize`, `[multiply`, `[opacity`, `[verticalframe`, `[noalpha`,
`[brighten`, and `(...)` grouping. Anything else falls back to the base name
before the first `^` and is reported on stderr.

## What the renderer approximates

It is a reviewing aid, not the engine. Known, deliberate simplifications:

- **Shapes.** Full cubes, slabs (incl. upside-down `param2` 20–23), stairs as
  two boxes with `facedir` rotation, doors/beds/panes/trapdoors as thin
  rotated boxes, fences and walls as post + connecting rails (connection
  derived from neighbours, not from the engine's `connects_to`). Torches,
  plants and other sprite-like nodes are drawn as camera-facing billboards —
  at 16px art a 2/16-node-thick box samples almost nothing but transparent
  pixels and the node vanishes. Wall torches are offset toward their support.
- **Faces.** Only the three camera-facing faces (top, `+x`, `+z`) are drawn,
  each flat-shaded (1.00 / 0.80 / 0.62). No ambient occlusion, no smooth
  lighting, no backface detail through glass.
- **Glass** gets a faint translucent backing so the frame reads; the engine's
  `glasslike_framed` connection logic is not modelled.
- **`--light`** is a post-process over the finished image: the glow does not
  respect occlusion, so a torch inside a building still glows through its
  roof. It answers "is this area lit at all", not "how bright is this pixel".
- **Painter's order** is `x + y + z` ascending, which is exact for the
  `(1,1,1)` camera direction and axis-aligned boxes.
- **Culling.** A cell is skipped when its neighbours at `+x`, `+y` and `+z`
  are all opaque full cubes — exact for this projection, and it removes over
  half of a settlement's cells.

## Performance

Hearthpine (88 167 blueprint cells, 49 977 non-air) at `--scale 16`:
about **0.3 s** wall time end to end, 23 288 cells drawn after culling. Cost
is dominated by the per-cell paste, and every distinct `(name, param2,
connections)` combination is rasterised into a sprite exactly once (24 sprites
for the whole village).
