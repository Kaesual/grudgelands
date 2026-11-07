# Round 70 CASTLE — the seat of the king

Three castle forms and one monumental throne, in all six capital palettes.
**A — Crownward is recommended.** Open [page.html](page.html) directly: it is a
single, self-contained file, including the shared building viewer, all textures,
24 scenes, floor plans and nine PNGs. No network requests are needed.

Compare today's hall with any proposal at the same scale. Switch culture and
form, use the approach, doorway, throne and cutaway cameras, or walk through
the selected hall at player eye height. The plans show the main floor, raised
dais and roof projection; socket numbers match their coordinate table.
The page follows the system theme and also has a light/dark switch.

The [report](REPORT.md) owns the recommendation, measurements, socket schedule,
integration instructions, provenance, publication state and verification limits.
These are proposals for the user's pick and the coordinator's independent review.

## Reproduce

From the repository root, with Python 3, Pillow, numpy, Node.js and LuaJIT:

```sh
python3 tools/r70_castle/build.py
python3 tools/r70_castle/render.py
python3 tools/r70_castle/build.py
python3 tools/r70_castle/build.py --check
python3 tools/r70_castle/verify.py
```

The first build supplies the scene payload. Rendering writes nine 1200 × 900
PNGs and a receipt per form; the second build embeds the images. `--check`
compares every generated template, palette profile, node inventory, metric and
HTML byte for byte. It also verifies the stills' input and output hashes.
`--templates-only` skips the viewer, baseline export and still checks.

`render.py --form crownward --race troll` can render another palette; the pick
page embeds the nine Human stills and offers all six cultures interactively.
Separate form/race jobs have distinct output files and can run independently.
`verify.py` checks the inline JavaScript, offline references, media decoding and
all 24 geometry exports, with at most two Node processes.

No game files, runtime fixtures, worlds or reference checkouts are changed.
All Lua execution calls the existing readers through LuaJIT, one at a time;
no Lua file is added. This tooling is compatible; installing a castle joins
Round 70's map reset.
