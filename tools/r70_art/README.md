# Round 70 ART — Thread and the Stonewright

**Confirmed picks: Thread A, Grinder B, Smelting furnace A, and A for Iron,
Steel, Silversteel, Embersteel and Abyssal Steel.** Furnace A now always burns.
All 24 proposals remain available. This lane prepares media; it installs nothing.

Open [page.html](page.html) directly, or publish that file alone. All images,
CSS, JavaScript and media notices are inline; no external request is needed.
The page shows the picks at the top and beside each proposal, and preserves
the pass 1 recommendations. Old browser choices cannot override the confirmed
selection. The only persisted preference is the colour theme. Copying the
summary has a selected-text fallback if the Clipboard API is unavailable.

The furnace runs in three views: front, hall corner and a dim version of the
same corner. All retain pass 1's camera, scale and 1.8-node wooden figure.
Pause is available; reduced motion shows the first frame and stops updates,
including when the preference changes while the page is open. Hidden tabs
stop the animation. With JavaScript off, every proposal, pick and the first
fire frame remains visible.

[Installation handoff](INSTALL.md) · [Final folder](candidates/final/) ·
[Report](REPORT.md) · [Overview](previews/overview.png) ·
[Per-file licences](LICENSE-media.md) · [Source hashes](source_manifest.json)

## Rebuild

From the repository root, with Python 3, Pillow and numpy:

```sh
python3 tools/r70_art/build.py
python3 tools/r70_art/build.py --check
node --check tools/r70_art/picks.js
```

The generator authors pixels on the game's native **16 × 16 RGBA** grid.
The animated sheets contain eight such frames stacked vertically, **16 × 128**.
There is no image-generation service, bitmap tracing, antialiasing, random
input, timestamp or downloaded dependency. Shipped active furnace sheets
are read and hashed for their dimensions; their pixels are not copied.

`--check` generates in memory, validates and byte-compares **230 outputs**:
29 proposal textures, six proposal geometry files, 128 final files,
14 context images, 47 preview images, the page, INSTALL, two manifests,
audit JSON and the media inventory. It also rejects unexpected files in the
candidate/context/preview folders. It writes nothing, including no Python
bytecode. The authored sources are `build.py`, `installation.py`,
`style.css`, `picks.js`, this README and the report.

`manifest.json` hashes generated files except itself. `source_manifest.json`
hashes the consumed repository images, media notice and furnace definitions.
The original pass used Pillow 12.3.0 and numpy 2.4.6; PNG byte encoding depends
on Pillow/zlib, so use the same environment for byte-identical reproduction.
Pixel drawing, geometry and nearest texture sampling are deterministic.

## Candidate and final layout

- `candidates/thread/<a|b|c>/thread.png`: three binary-alpha icons.
- `candidates/stone/<a|b|c>/<metal>.png`: fifteen opaque full-block faces.
  One image covers all six faces. No stairs, slabs or connected-texture rules.
- `candidates/machines/textures/`: ten original static material faces and
  the new original `hearth_fire.png` vertical sheet.
- `candidates/machines/<grinder|furnace>_<a|b|c>/geometry.json`: six authored
  compositions, dimensions, occupied cells and material references. Origin
  is lower front left; +x right, +y up, +z rear, front −z.
- **`candidates/final/`**: exactly the selected set, **126 PNGs + two JSONs**.
  Six PNGs are Thread and the five stones. The machines have 120 prepared
  cell-face files (six per occupied cell); four of them animate. The JSONs
  supply exact local node boxes, proposed names and ordered tile definitions.
- `previews/`: front elevations, hall studies, stones, walls, overview,
  and the furnace's front/hall/dim eight-frame preview sheets.
- `context/`: shipped comparison textures and today's tinted-paper Thread;
  none is included in the final folder.

Every proposal remains. The selected machines' previews now use the final
cell tiles; alternatives retain the pass 1 material renders. The user's
Grinder B differs from the artist's pass 1 recommendation A. The other seven
choices match those recommendations; these historical badges are labelled.

## Construction and fire

All machines are static node boxes. The installation handoff is the owner of
the complete per-cell construction, file table, proposed names and hall
reservation. The key dimensions are:

| Machine | Width × depth × height | Occupied / reserved cells | Authored boxes |
|---|---|---|---:|
| Grinder A | 2 × 2 × 2 | 8 / 8 | 22 |
| **Grinder B (picked)** | **2 × 2 × 2** | **8 / 8** | **29** |
| Grinder C | 2 × 2 × 3 | 12 / 12 | 19 |
| **Furnace A (picked)** | **2 × 2 × 3** | **12 / 12** | **17** |
| Furnace B | 2 × 2 × 2 | 8 / 8 | 26 |
| Furnace C | 3 × 2 × 2 | 10 / 12 | 23 |

**Furnace A reverses pass 1's cold rule.** Fire behind the grate has eight
frames, nominally 0.1875 s each, with a 1.5 s loop. Four front hearth cell
faces animate and those cells propose `light_source = 8`, matching the
shipped active furnaces. The flame colours and moving tongues are original.
Jambs, lintel and nearby stone have painted warmth; a narrow dull-orange
channel in the pouring lip suggests retained heat. The casting stays solid.
Only the aperture and grate bounds align slightly to the 1/16-node grid;
the shaft, mould, footprint and the rest of the geometry remain as picked.

Furnace B/C and every grinder remain cold and static. Furnace A has no
particles, moving geometry or functional mechanism. Sound is the installation
lane's task, reusing the shipped loop once for the complete furnace.

The engine has six tiles per node, not a material per box. `installation.py`
clips the picked boxes by cell and bakes their visible materials to the six
correctly oriented native-size faces. No unimplemented material conversion
is left to the installing lane. Detailed UV, cell and light instructions
are in [INSTALL.md](INSTALL.md).

Hall studies use shipped stone, cobble and timber. They remain a generic
cropped corner, not a fitted template modification. The dim study uses
illustrative local illumination; it is not an engine lighting simulation.
The engine's propagated light is neutral; warm colour comes from the art.
The existing sorter socket has no room for a machine directly behind it;
the revised work bay or ore-yard placement belongs to lane GUILD.

## Licences

**All original candidate and final media and geometry: GPT-6 Astra, CC0-1.0.**
The five metal ramps match the shipped Round 68 A bars. No shipped texture
pixels enter a candidate or final asset. The final file table in INSTALL
includes the shipping licence rows.

Comparison sources retain their licences: stone by Cisoun; cobble by
Neuromancer, based on Brane praefect; wood and stick by BlockMen; sand by
VanessaE; paper by Gambit; stone brick by paramat — CC BY-SA 3.0. Gravel
is sofar's CC0-1.0 derivative of Gambit's light gravel; bars are GPT-6 Astra's
CC0 work. [LICENSE-media.md](LICENSE-media.md) lists every PNG separately.
Hall previews, including animated and dim views, and the overview retain
CC BY-SA 3.0 for their included comparison textures. The standalone page
includes the complete vendored notice.

Generator/page code is GPL-3.0-or-later under the repository
[licence](../../LICENSE.txt).

## Review limits

This is **compatible tooling/media only**. No version, saved state, Lua,
server, fixture, live template or `mods/` change is made. Hall installation
joins Round 70's map reset separately. The coordinator's independent review
is required before integration; no other agent, merge or push was started.

PNGs and animation frames were inspected locally. Chromium 151 again failed
before page load in this sandbox (`setsockopt: Operation not permitted`,
exit 133), so no browser screenshot or client acceptance is claimed.
The standalone HTML, decoded images, recorded picks and script behaviour
are checked locally. Desktop/web GUI checks belong to installation and are
listed in INSTALL.
