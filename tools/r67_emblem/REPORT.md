# Round 67 follow-up EMBLEM — delivery

**Pass 4 recommendation: H1 + K1, the painted livery pair.**
Open the [offline preview](preview/index.html), the
[300 px drawing board](preview/heads.png) or the
[usage contact sheet](preview/contact.png). All six heads are new frontal
proposals. **Picked by the user (2026-10-31): H1 + K1** (see "The user's
pick" at the end).

## Pass 4 — frontal heads, 2026-10-31

The user chose Pass 3's frontal hart A1 and boar B3 as the direction,
while asking for stronger drawing. Pass 4 replaces every candidate with
an explicitly authored frontal head. Each number is a coherent pair:
the two animals share their contour treatment, detail weight, materials,
shield and finish. Individual choices can also be combined.

| Pair | The Accord | The Throng | Treatment and recommendation |
|---|---|---|---|
| **H1 + K1** | **The Broadbrow Hart:** a broad brow, sideways leaf-shaped ears and an open branching rack. | **The Tuskguard Boar:** a bristled wedge, pointed ears, a long snout and large external tusks. | **Recommended.** Painted ivory with the fewest interior marks; the eyes, ears and tusks have the clearest separation at Social-row size. |
| **H2 + K2** | **The Highbough Hart:** taller swept beams, level ears and a more tapered face. | **The Flinttusk Boar:** swept ears, longer tusks and a more angular face. | Cut ivory with restrained 1.35-unit gold engraving following brow and cheek planes. More detail for headers and close viewing. |
| **H3 + K3** | **The Leafear Hart:** upward ears and a fuller muzzle under a branching rack. | **The Bristleback Boar:** a full bristled brow and stout upturned tusks. | Needlework: fine gold contour stitches and a subtle thread texture; ornament deliberately softens at small sizes. |

The hart's forehead now widens before tapering into its muzzle. Dark eye
and ear openings are deliberate enclosed shapes; the painted pair has
no vertical face engraving. Each side of the rack has four tips: a
terminal, two outward branches and one inward branch. Beams and branches
taper independently, with open field between them.

The boar's long bridge terminates in a narrow angular nose, rather than
a circular disk. Curved ivory tusks stand beside it across a generous
field-coloured gap. Pointed ears, a bristled crest and descending cheek
tufts establish the head above the snout. The tusks fit inside the shield
rim. All six silhouette and detail masks are exactly mirrored; texture
variation is seeded and intentionally subtler than the drawing.

The 24 px samples retain the branching hart and tusked boar; small eye
and engraving marks soften. At 16 px, the main animal shape and faction
field remain, while fine tines and stitches merge. This is an offline
visual assessment, not desktop or web GUI acceptance.

The proud rival factions and old conflict in
[world.md](../../docs/design/world.md), [pvp.md](../../docs/design/pvp.md)
and [story.md](../../docs/design/story.md) inform the art. The labels and
symbolic interpretations here are proposals, not new faction history.
The depth and Nether TODO files do not block this lane.

### Palette and finish

| Material | Base colour |
|---|---|
| The Accord cloth and shield | **#344b5a**, muted slate blue |
| The Throng cloth and shield | **#683e39**, muted wine/rust red |
| Main animal | **#d6c59b**, old ivory |
| Rim, engraving and ornament | **#aa9164**, tarnished gold |

The cloth colours are sampled as the most frequent fully opaque RGB in
the shipped banners. Pass 4 preserves Pass 2/3's subtle weave, uneven dye,
faded edges, worn hem and gold vinework. Each emblem has three material
tones: faction field, ivory and gold. Surface variation and antialiasing
add intermediate shades. There are no saturated primaries.

## Pass 3 — retained reference, superseded drawings

Pass 3's art commit is
`cf2e454a748e15bc0d5da7bda9376a4a3dd8565c`, followed by report commit
`0d3cf530`. Its **A1 hart and B3 boar** are retained byte for byte as the
four `preview/ref_pass3_{emblem,banner}_{accord,throng}.png` inputs.
The generator checks their fixed SHA-256 values. The comparison also
shows their model projections and all UI usage mocks. The other four
Pass 3 candidates survive only in git history.

## Pass 2 — retained palette and heraldic direction

Pass 2's A pair established the selected muted cloth, old ivory,
tarnished gold and shield construction. Its art commit is
`55ea1695a69ed56541f44166461d9325a2e8219d`. Its drawings were superseded
by Pass 3 and now Pass 4. All Pass 1/2 candidates and comparison PNGs
are absent from the current tree; git history retains them.

## Files and UV contract

There are **12 candidate PNGs**, all RGBA:

- `candidates/emblem_accord_{1,2,3}.png` and
  `candidates/emblem_throng_{1,2,3}.png`: **100 × 100**, transparent outside
  the shield, drawn at 6× and reduced with Lanczos.
- `candidates/banner_accord_{1,2,3}.png` and
  `candidates/banner_throng_{1,2,3}.png`: **128 × 256**, retaining each
  corresponding shipped alpha channel **byte for byte**.

`accord_1` maps to H1, `throng_1` to K1, and so on. No old letter-suffixed
candidate filenames remain. The banner carries the same animal without
a second shield, between the existing gold corner vines and leaf spray.

The generator reads the existing B3D, verifies its rest transforms and
UVs, and projects its three material buffers. The double-sided cloth is
**0.96 × 2 nodes**. Its front vertices are:

| Position, in nodes | UV |
|---|---|
| `(-0.48, 0.50, -0.52)` | `(0, 0)` |
| `( 0.48, 0.50, -0.52)` | `(1, 0)` |
| `( 0.48,-1.50, -0.52)` | `(1, 1)` |
| `(-0.48,-1.50, -0.52)` | `(0, 1)` |

V increases downward. The whole texture maps onto the rectangle; alpha
defines the pointed hem. Its bounding box remains `(7, 29, 121, 227)`
with exclusive maxima. Cloth cut, padding, attachment and orientation
are unchanged. The other two buffers are rod and straps.

All ten projections use this actual mesh at rest with a shared camera
approximately 5 m away, treating a node as a metre. A simple support pole
and beam provide context. They are offline illustrations, not engine
screenshots.

[manifest.json](manifest.json) records Pass 4, all labels, paired
treatments, recommendation, palette, measured mesh data and source/candidate
hashes. [LICENSE-media.md](LICENSE-media.md) records the original
**CC0-1.0** artwork and retained comparison, geometry and alpha provenance.
No external image, font symbol or generated bitmap source enters a candidate.

## Preview and reproduction

`preview/index.html` shows **H1 + K1**, **H2 + K2**, and **H3 + K3** as
side-by-side pairs, followed by Pass 3 A1/B3 and the unchanged shipped art.
Each candidate has a **300 × 300** drawing study reduced directly from the
same 600 px master. Every candidate and reference also shows:

- Actual delivered UI icons scaled to **16, 24, 32 and 64 px** on **#181e28**.
- An inventory header with a **54 px** icon and the faction name.
- Three Social rows with **26 px** faction icons, names, shipped class/race
  icons and levels; all six races appear in each pair.
- The flat **128 × 256** banner and its projection on the existing model.

The recommendation is at the top. Narrow windows scroll each pair
horizontally. All images are beside the HTML, using relative paths and
no scripts, remote fonts or external URLs.

From the repository root:

```sh
python3 tools/r67_emblem/generate.py
python3 tools/r67_emblem/generate.py --check
```

Dependencies: Python 3, Pillow and numpy. `heraldry.py` owns the contours
and finish, `generate.py` owns sampling and outputs, and `preview_page.py`
owns the static HTML. The four `ref_pass3_*.png` files are tracked,
immutable generator inputs. They are not disposable build products.

## Verification and handoff

`--check` passed for **62 byte-reproduced outputs**: 12 candidates,
12 matching preview copies, 18 references, ten projections, six enlarged
views, two contact sheets, one HTML page and one manifest. Its artifact
checks cover RGBA/dimensions, transparent icon edges, exact banner alpha,
matching preview copies and local image links.

Additional artifact checks passed: Python syntax, `git diff --check`,
all 18 references against their original source bytes (Pass 3 against
its committed blobs), exact symmetry of all six silhouette/detail masks,
all six animal silhouettes fitting inside the inner shield, six 300 px
views, unique HTML IDs and resolving navigation anchors, removal of
Pass 2 references and lane-only change scope.

The drawing board, contact sheet, projected banners, and an offline
54 px header / 26 px Social-row composite beside the shipped class/race
icons were visually inspected. Browser rendering was not exercised.

**Upgrade classification: compatible.** Development art only.
`git diff 0d3cf530 -- mods/` is empty. No Lua, runtime asset, model,
saved state, generation, game version or upgrade declaration changed.
No fixture, game server, engine boot, sync, merge or push ran. The changes
are confined to `tools/r67_emblem/` and its single `tools/README.md` entry.

After selection, the coordinator copies the four chosen files to the
existing runtime paths and records provenance in the receiving media
ledgers. The coordinator must also reconcile
`tools/r63_camp_art/build.py`: its `svg_text()` still creates the old
symbols, so rebuilding it would overwrite the selection and its `--check`
would reject the new artwork. That generator, runtime files and the
authoritative heraldry description in `docs/design/settlements.md` are
outside this lane.

The independent lane review belongs to the coordinator before integration;
this artist does not claim independent review acceptance. After integration,
the user's **desktop and web** GUI checklist is:

1. Inspect headers and Social rows at normal UI sizes beside every
   class/race icon: colour, silhouettes, tusk/ear separation and transparency.
2. Inspect both sides of banners near and several metres away, in daylight
   and interior lighting: orientation, attachment, cloth cut and pointed hem.
3. Confirm all banner instances use the selected heads and the owning
   generator preserves them when rebuilt.

## Commit receipt

- **Final Pass 4 art/preview commit:** `8fdd5ec501560b15f232dc3c28ae7e50a5837314`.
  All six drawings, 12 candidates, comparison assets, generator, preview,
  provenance and this report were complete at this checkpoint.
  **`git status --porcelain` was empty.**
- The following documentation-only commit adds this receipt. Its final
  branch hash and post-report clean-tree result are in the final response,
  saved as `last.md` by the runner. A tracked report cannot embed its own
  commit hash without changing that hash; resolve the final report commit
  with `git log -1 --format=%H -- tools/r67_emblem/REPORT.md`.

Both Pass 4 commit messages end with
`Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.
No runner-owned `last.md` is added to the branch.

## The user's pick (2026-10-31)

**H1 + K1** (Pass 4, the painted pair). The coordinator copied
`emblem_accord_1.png` / `emblem_throng_1.png` to
`mods/PLAYER/grug_inventory/textures/grug_inventory_faction_{accord,throng}.png`
and `banner_accord_1.png` / `banner_throng_1.png` to
`mods/MAPGEN/grug_mapgen/textures/grug_mapgen_faction_banner_{accord,throng}.png`;
`tools/r63_camp_art/build.py` no longer generates those four files.
