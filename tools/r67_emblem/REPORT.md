# Round 67 follow-up EMBLEM — delivery

**Pass 2 recommendation: A, Hart & Boar.** Open the
[offline preview](preview/index.html) or the
[contact sheet with the current art](preview/contact.png).
All three pairs remain proposals awaiting the user's pick.

## Pass 2 — fantasy heraldry, 2026-10-31

Pass 1 (`db3e12e8`) was rejected for its modern, flat construction and
saturated colours. All twelve candidate PNGs and their preview copies have
been replaced. Pass 1 survives only in git history; the comparison assets
are the current shipped game art, not the rejected proposals.

The new construction uses a cloth-faced heraldic shield in the UI, with a
large ivory charge and a narrow tarnished-gold border. Small stitches,
matte pigment variation and thread marks suggest old craft without making
the silhouette depend on decoration. The banners carry the same charge
without a second shield: gold corner vines and a small leaf spray frame
it, over a fine weave with uneven dye, faded edges and a rubbed hem.
Nothing is glossy, and no text or letters enter a candidate.

| Pair | The Accord | The Throng | Assessment |
|---|---|---|---|
| **A — Hart & Boar** | **The Oathhart:** a front-facing hart with branching antlers, suggesting unlike homelands held in one proud pact. | **The Unbowed Boar:** a bristled head in profile with a rising tusk, suggesting collective resolve. | **Recommended.** The branching, upright silhouette contrasts with the broad, forward-facing snout; the pair reads as old war heraldry at banner scale and remains distinct in the small UI strip. |
| **B — Oak & Horn** | **The Bound Oak:** three rounded boughs, one trunk and shared roots. | **The Gathering Horn:** a broad, curved rally horn with worn bindings. | The strongest homeland/assembly pair. Deliberately revisits the tree and horn ideas from Pass 1: new organic contours, lobed leaves and bound-horn details gain the fantasy treatment, replacing the angular root and faceted horn. |
| **C — Falcon & Serpent** | **The Vigil Falcon:** a folded-wing bird keeping watch. | **The Unbroken Coil:** an open coil with a raised head, expressing defiance. | A quieter pair of heraldic creatures. The compact bird and open coil differ clearly at 24 px; the bird has less breadth than A and the serpent relies more on its inner gap. |

At 16 px the field and principal light shape carry identity; stitches,
eyes and ornament are expected to disappear. At 24 px the main motifs
remain readable without those details. These are visual observations
from the offline composites, not desktop/web GUI acceptance.

The interpretation draws on the pact/collective-force distinction in
[world.md](../../docs/design/world.md), the rival war factions in
[pvp.md](../../docs/design/pvp.md), and the old conflict and independent
oaths in [story.md](../../docs/design/story.md). These proposed symbols
add no canonical faction history or new creature association. The open
depth and Nether TODO files do not block this art package.

### Palette

The generator samples the **most frequent fully opaque RGB** in each
shipped banner. The measured cloth bases are:

| Material | Colour |
|---|---|
| The Accord cloth and UI shield | **#344b5a**, muted slate blue |
| The Throng cloth and UI shield | **#683e39**, muted wine/rust red |
| Main charge | **#d6c59b**, old ivory |
| Border, bindings and ornament | **#aa9164**, tarnished gold |

Each emblem has three material tones: faction cloth, ivory and gold.
Weave, thread, wear and antialiasing introduce subtle tonal variation.
The cloth bases retain the shipped family; the saturated Pass 1 blue/red
are no longer used. No source RGB pixel regions are copied into candidates.
The cloth alpha is the only retained source image channel.

## Files and UV contract

There are **12 candidate PNGs**, all RGBA:

- Six `candidates/emblem_{accord,throng}_{a,b,c}.png`: **100 × 100**,
  transparent outside the shield; drawn at 6× and reduced with Lanczos.
- Six `candidates/banner_{accord,throng}_{a,b,c}.png`: **128 × 256**,
  with the shipped alpha channel preserved **byte for byte**.

The existing B3D is read directly by the generator, with checked rest
transforms and UVs. Its first material buffer is a double-sided rectangular
cloth, **0.96 × 2 nodes**, with these front vertices:

| Position, in nodes | UV |
|---|---|
| `(-0.48, 0.50, -0.52)` | `(0, 0)` |
| `( 0.48, 0.50, -0.52)` | `(1, 0)` |
| `( 0.48,-1.50, -0.52)` | `(1, 1)` |
| `(-0.48,-1.50, -0.52)` | `(0, 1)` |

V increases downward. The full texture maps onto this rectangle; alpha,
not the mesh, defines the pointed hem. The alpha bounding box remains
`(7, 29, 121, 227)`, with exclusive maximum bounds. The Round 63 source
viewBox maps to texture pixels as `x = 1.28u`, `y = 1.28v + 25.6`.
Padding, attachment, cut and orientation are unchanged. The other two
material buffers are the rod and straps; they are not painted by the
candidate texture.

All eight projections use this actual mesh at rest and a common camera
approximately 5 m away, treating a node as a metre. A simple support pole
and beam provide context. They are offline illustrations, not engine
screenshots. The asymmetric boar, horn and creatures face the same way
in the flat textures and projections.

[manifest.json](manifest.json) records Pass 2, the sampled palette,
source/model hashes, measured vertices/UVs and candidate hashes.
[LICENSE-media.md](LICENSE-media.md) records the original **CC0-1.0** art,
the retained CC0 alpha and the unchanged copied comparison assets.

## Preview and reproduction

`preview/index.html` uses relative paths with all images beside it,
no scripts, external URLs or fetched fonts. Every candidate pair and the
current art show:

- UI icons at **16, 24, 32 and 64 px** on **#181e28**.
- Both inventory header mocks, with **54 px** icons and faction names.
- Three online-player rows per faction, with **26 px** faction icons,
  names, shipped class/race icons and levels; all six races are represented.
- Flat banner textures and projections using the current model.

Each proposed faction also has a direct **32 px shipped → Pass 2** icon
comparison. The recommendation and its reason are at the top. The contact
sheet includes A/B/C and the unchanged shipped art at the same scales.

From the repository root:

```sh
python3 tools/r67_emblem/generate.py
python3 tools/r67_emblem/generate.py --check
```

Dependencies verified: **Python 3.14.8, Pillow 12.3.0, numpy 2.4.6**.
`heraldry.py` owns the original drawings and deterministic surface treatment;
`generate.py` owns palette sampling, mesh reading, projection and outputs;
`preview_page.py` owns the static HTML. Only this tool directory is written.

## Verification and handoff

`--check` passed for **49 byte-reproduced outputs**: 12 candidates,
12 matching preview copies, 14 current/reference images, eight projections,
one contact sheet, one HTML page and one manifest. It also checked
RGBA/dimensions, transparent icon edges, exact banner alpha, identical
candidate/preview copies, local HTML references and unexpected output files.

Python syntax and `git diff --check` passed. All twelve candidates differ
from Pass 1; no old candidate PNG is retained elsewhere in this package.
The contact sheet, projected banners and a separate 54 px header / 26 px
player-row composite with shipped class/race icons were visually inspected.
Browser rendering was not exercised.

**Upgrade classification: compatible.** This is a development-art proposal;
no Lua, model, runtime asset, saved state, world generation, game version
or upgrade declaration changed. `git diff db3e12e8 -- mods/` is empty.
No fixtures, game server, engine boot, sync, merge or push were run.

After the user's pick, the coordinator copies the selected candidates to
the existing runtime paths and records their provenance. It must also
reconcile `tools/r63_camp_art/build.py`: `svg_text()` still generates the
old symbols, so its rebuild would overwrite a selected image and its
`--check` would reject the new art. That generator, the owning design
record in `docs/design/settlements.md` and all runtime files are outside
this lane.

The independent lane review belongs to the coordinator before integration;
this implementer did not launch a reviewer or claim review acceptance.
The user's desktop **and** web GUI checklist after integration:

1. Check inventory headers and Social rows at normal UI size, alongside
   every class/race icon: colour separation, legibility and transparency.
2. Check banners from both sides, near and several metres away, in
   daylight and interior lighting: orientation, attachment and pointed hem.
3. Check that all banner instances use the chosen motifs and that the
   owning asset generator does not restore the old symbols.

## Commit receipt

- **Final Pass 2 art/preview commit:**
  `55ea1695a69ed56541f44166461d9325a2e8219d`.
  At this complete-art checkpoint, **`git status --porcelain` was empty**.
- This report is the following documentation-only commit. Its final branch
  hash and the post-report clean-tree check are in the final response,
  which the runner saves as `last.md`. A tracked report cannot embed its
  own commit hash without changing it; resolve its final commit with
  `git log -1 --format=%H -- tools/r67_emblem/REPORT.md`.

Both Pass 2 commits end with
`Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.
