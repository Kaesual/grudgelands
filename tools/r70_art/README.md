# Round 70 ART — Thread and the Stonewright

Three proposals for Thread, three grinders, three smelting furnaces and three
families of five ornamented stones. **24 choices, none selected.** Everything
is a proposal for the user's pick; this lane installs nothing.

Open [page.html](page.html) directly, or publish that file alone. It contains
all images, CSS, JavaScript and media notices. It makes no external requests.
The page follows the system theme and offers Light and Dark controls. Picks
are independent for Thread, Grinder, Smelting furnace and each of the five
metals. Browser storage is optional; copying the selection summary works with
a selected-text fallback when the Clipboard API is unavailable. No choice is
sent to a service. Every comparison is visible without JavaScript.

[Overview](previews/overview.png) · [Report](REPORT.md) ·
[Per-file licences](LICENSE-media.md) · [Source hashes](source_manifest.json)

## Recommendations

| Item | Pick | Reason |
|---|---|---|
| Thread | **A — Wooden spool** | Wooden flanges, pale winding and a free end read as Thread at 16 px. |
| Grinder | **A — Hand quern** | Exposed millstones explain the service; the low silhouette leaves the Stonewright visible. |
| Smelting furnace | **A — Banded shaft** | Shaft, cold grate and casting mould read clearly, with a compact footprint. |
| Iron stone | **A — Running inlay** | A restrained, dull iron ribbon connects across the wall. |
| Steel stone | **A — Running inlay** | Brighter steel follows the same route with a small return. |
| Silversteel stone | **A — Running inlay** | The pale blue metal remains distinct without framing every tile. |
| Embersteel stone | **A — Running inlay** | The copper-red body and sparse warm glints read as the shipped metal, without emissive pixels. |
| Abyssal Steel stone | **A — Running inlay** | Violet inlay gains the richest returns while keeping open stone between the ribbons. |

The alternatives are substantive: Thread B is a ball and C a tied skein;
Grinder B uses twin rollers and C hanging stamps; Furnace B is a low crucible
hearth and C a broad vaulted hearth with a mould bench. Stone B is a centred
quarry seal, C a rising sprig. The page gives the tradeoff of each.

## Rebuild

From the repository root, with Python 3, Pillow and numpy installed:

```sh
python3 tools/r70_art/build.py
python3 tools/r70_art/build.py --check
node --check tools/r70_art/picks.js
```

The generator authors pixels directly on the native **16 × 16 RGBA** grid.
That matches `default_stone.png`, the shipped bars and the current Thread's
paper source. The icons are displayed at 16, 32 and 64 px using nearest-neighbour
scaling, beside existing inventory items. There is no image-generation service,
bitmap tracing, antialiasing, random input, timestamp or downloaded dependency.

`--check` generates in memory, validates and byte-compares **96 outputs**:
28 candidate textures, six geometry files, fourteen context images, 43 preview
images, the page, two manifests, audit JSON and the per-file media inventory.
It rejects extra files inside the generated candidate/context/preview folders.
It writes nothing. `manifest.json` hashes all generated files except itself;
`source_manifest.json` hashes the consumed repository images and media notice.
The authored `build.py`, `style.css`, `picks.js`, README and report are source,
not generated outputs.

Build environment used: Python 3, Pillow 12.3.0, numpy 2.4.6. PNG encoding
depends on Pillow/zlib; use the same environment for byte-identical comparison
across machines. Pixel art, geometry and the integer texture sampling are
deterministic.

## Candidate layout

- `candidates/thread/<a|b|c>/thread.png`: three binary-alpha icons.
- `candidates/stone/<a|b|c>/<metal>.png`: fifteen opaque full-block faces.
  One identical texture is proposed on all six faces. No stairs, slabs,
  connected-texture rule, random tile choice or orientation logic is needed.
- `candidates/machines/textures/`: ten original opaque faces, shared between
  the machine proposals. All are 16 × 16; names and exact usage are in each
  geometry file and on the page.
- `candidates/machines/<grinder|furnace>_<a|b|c>/geometry.json`: the complete
  authored box composition, dimensions, occupied cells, texture mapping and
  runtime requirement. Coordinates are in node units: origin at the lower
  front left, +x right, +y up, +z rear, front −z.
- `previews/`: front elevations, hall studies, individual stone cubes, 5 × 5
  walls and an overview, all generated from those same candidates.
- `context/`: existing game textures and a reconstruction of the current
  tinted-paper Thread, for comparison only.

## Machine construction and space

Every proposal uses **static node boxes**, with a solid block-shaped foundation
where appropriate. None needs a mesh. The cells below are counted by the union
of cells touched by the authored boxes, not a volume rounded by eye.

| Machine | Width × depth × height | Occupied / reserved cells | Authored boxes | New faces used |
|---|---|---|---:|---|
| Grinder A | 2 × 2 × 2 | 8 / 8 | 22 | dressed_stone, grindstone, iron, rubble, sand, timber |
| Grinder B | 2 × 2 × 2 | 8 / 8 | 29 | dressed_stone, grindstone, iron, rubble, sand, timber |
| Grinder C | 2 × 2 × 3 | 12 / 12 | 19 | dressed_stone, iron, rubble, sand, timber |
| Furnace A | 2 × 2 × 3 | 12 / 12 | 17 | dressed_stone, firebrick, iron, slag, soot |
| Furnace B | 2 × 2 × 2 | 8 / 8 | 26 | dressed_stone, firebrick, iron, leather, slag, soot, timber |
| Furnace C | 3 × 2 × 2 | 10 / 12 | 23 | dressed_stone, firebrick, iron, slag, soot |

For integration, split each box at integer cell boundaries, then translate
each cell's part to local node-box coordinates `[-0.5, 0.5]`. These JSON files
are geometry proposals, not engine registrations. The installation lane owns
node names, facedir, collision/selection boxes, face UV orientation, culling
and hall placement. Texture paths in a geometry file are relative to that
file. Front renders share a scale of 320 pixels per 3.5 nodes.

All machines are cold, static decoration. **No light source, glow, fire,
particles, sound, animation, node timers or functional interaction** is needed.
Gravel, sand and castings are visible static parts, not inventory contents.
The pouring lips use cold slag; orange light is not painted into any furnace.
The Stonewright service itself belongs to lane GUILD.

The hall studies use the existing `default:stone`, `default:cobble` and timber
textures. They echo the houses' two-course stone plinth, timber posts and
infill. A neutral 1.8-node wooden mannequin gives scale. This is a generic
cropped corner, **not a fitted modification of any of the six templates**.

`tools/r58_halls/make_halls.py` puts the sorter at `(1, 1, 10)`, facing east,
beside its sample table at `(2, *, 10)` and storage at `(1, 1, 11)`. The west
wall is x=0. There is no room to insert either 2-deep machine directly behind
that unchanged socket. Lane GUILD needs a revised work bay or an ore-yard
placement, with the NPC in front and the approach clear. Reserve each
machine's full box, even the two empty upper cells of Furnace C; no exact
placement or route clearance is claimed here. The six halls share their
geometry and sockets; their race palettes differ.

## Licences and provenance

**Original candidate media and geometry: GPT-6 Astra, CC0-1.0.** All candidate
pixels are drawn from original coordinates and simple integer grain. The
five metal ramps are exactly the shipped Round 68 A bar ramps; the generator
checks every opaque bar pixel against those colours. The stone grain is new,
low-contrast and borderless. No shipped texture pixels enter a candidate.

Existing comparison images retain their own licences. Stone is Cisoun's;
cobble is Neuromancer's, based on Brane praefect; wood and stick are BlockMen's;
sand is VanessaE's; paper is Gambit's; stone brick is paramat's. These are
CC BY-SA 3.0. Gravel is sofar's CC0-1.0 derivative of Gambit's light gravel.
The shipped bars are GPT-6 Astra's CC0 work. The page carries the complete
vendored notice and named credit, so publishing the one HTML preserves it.

[LICENSE-media.md](LICENSE-media.md) lists every image, author, source,
licence and transformation. Hall renders and the overview retain CC BY-SA 3.0
for the included default textures. Pure candidate renders stay CC0. Code is
GPL-3.0-or-later under the repository's [licence](../../LICENSE.txt).

## Review limits

This is **compatible tooling only**: no saved state, version or upgrade
declaration changes. The eventual hall-template installation joins Round 70's
map reset separately. No Lua, game server, fixture, live template or `mods/`
change is part of this lane.

The PNGs were inspected directly. Chromium could not start in the sandbox
(`setsockopt: Operation not permitted`, exit 133 before page load), so this is
not a browser or game-client acceptance record. The page's inline assets,
image decoding, links, radio groups and JavaScript are checked locally;
desktop/mobile browser appearance and the game’s desktop/web rendering remain
for the coordinator/user to inspect. Responsive layouts cover phone widths,
and theme tokens follow system preference or the explicit page control.

The coordinator's independent review and the user's picks are pending. No
other agent was started; nothing was merged or pushed.
