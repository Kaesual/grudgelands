# Round 67 follow-up EMBLEM — delivery

**Recommendation: pair A, Wing & Tusk.** Open the
[offline preview](preview/index.html) or the [compact contact sheet](preview/contact.png).
All three pairs are proposals awaiting the user's pick.

## Variants

| Pair | The Accord | The Throng | Assessment |
|---|---|---|---|
| **A — Wing & Tusk** | **Oathwing:** two broad wings join around one keystone, expressing a pact held together. | **Oathjaw:** two rising tusks share one heavy jaw, expressing collective defiance and unbought oaths. | Recommended: a broad, descending centre against an open, rising bowl; the clearest contrast at 24 px and recognisable colour shapes at 16 px. |
| **B — Root & Horn** | **Threefold Root:** three boughs share one rooted trunk. | **Gathering Horn:** one sweeping rally horn calls scattered strength together. | More organic and tied to homeland/assembly; the root tips and horn's taper are less robust at the smallest size than A. |
| **C — Lance & Maul** | **Crossed Lances:** two lances interlock around a common centre. | **Breaker Maul:** a broad war maul puts collective force behind one edge. | Most explicitly martial, but closer to equipment and class iconography; the narrow shafts lose more weight at 16 px. |

Each pair uses the same unframed, bold geometry and two-colour facet
treatment. The UI's main colour is exactly **#3f6fce** for The Accord and
**#c41e3a** for The Throng, with a pale blue/pink facet; antialiasing adds
only edge blends. Banners use the same motif outline in ivory **#f3e7ce**
on faction-coloured cloth, with a darker outer edge and a simple hem.
No text, glyphs or source-image motifs enter the candidates.

The proposals draw on the pact/collective-force distinction in
[world.md](../../docs/design/world.md), the factions' equal standing as
rival war powers in [pvp.md](../../docs/design/pvp.md), and the old war,
pride and independent oaths in [story.md](../../docs/design/story.md).
They are proposed symbols, not new canon or a change to the factions'
roles. The open depth/Nether design files do not block this art package.

## Files and UV contract

There are **12 candidate PNGs**, all RGBA:

- Six `candidates/emblem_{accord,throng}_{a,b,c}.png`: **100 × 100**,
  transparent outside the silhouette, drawn at 6× and reduced with Lanczos.
- Six `candidates/banner_{accord,throng}_{a,b,c}.png`: **128 × 256**,
  with the shipped cloth alpha channel preserved **byte for byte**.

The existing model was inspected both through its Round 63 generator and
directly through its binary B3D chunks. Its first material buffer is a
double-sided rectangular cloth, **0.96 × 2 nodes**, with the front vertices:

| Position, in nodes | UV |
|---|---|
| `(-0.48, 0.50, -0.52)` | `(0, 0)` |
| `( 0.48, 0.50, -0.52)` | `(1, 0)` |
| `( 0.48,-1.50, -0.52)` | `(1, 1)` |
| `(-0.48,-1.50, -0.52)` | `(0, 1)` |

V increases downward without a flip. The full texture is mapped onto this
rectangle; its alpha defines the pointed cloth, not the mesh. The shipped
alpha bounding box is `(7, 29, 121, 227)`, with exclusive maximum bounds.
The original SVG's centred viewBox maps to texture pixels as
`x = 1.28u`, `y = 1.28v + 25.6`. This padding, cut, top attachment and
UV layout remain unchanged. The rod and straps are the other two material
buffers and are not part of the candidate texture.

The six new and two current projections read this same B3D mesh at rest,
including its rod and straps. A plain support pole and beam provide
illustrative context. All use a shared perspective camera approximately
5 m away, treating a node as a metre. The asymmetric horn was checked
against its flat image to confirm projection handedness. These are offline
illustrations, not engine screenshots.

[manifest.json](manifest.json) records source/model hashes, measured
vertices/UVs and candidate hashes. [LICENSE-media.md](LICENSE-media.md)
documents original **CC0-1.0** artwork, the retained CC0 cloth alpha and
the copied comparison assets.

## Preview and verification

`preview/index.html` is self-contained with its images beside it and
relative paths only. There are no scripts, external URLs or fetched fonts.
For every variant and the current art it shows:

- UI icons at **16, 24, 32 and 64 px**, on **#181e28**.
- Both inventory headers with **54 px** emblems.
- Three example player rows per faction, with **26 px** faction icons,
  names, shipped class/race icons and levels; all six races are represented.
- Flat banner textures and projections using the existing model.

From the repository root:

```sh
python3 tools/r67_emblem/generate.py
python3 tools/r67_emblem/generate.py --check
```

Dependencies: Python 3, Pillow and numpy; verified with **Python 3.14.8,
Pillow 12.3.0 and numpy 2.4.6**. The script writes only this tool directory;
`preview_page.py` owns its static HTML template.

The check regenerated and byte-compared **49 outputs**: 12 candidates,
12 matching preview copies, 14 current/reference images, eight
projections, one contact sheet, one HTML page and one manifest. It checked
RGBA/dimensions, transparent icon edges, exact preserved banner alpha,
candidate/preview equality, local HTML references and unexpected output
files. Python syntax, provenance links and the exact faction base colours
were checked separately. `git diff --check` passed. The contact sheet,
all motif pairs on the projected banners, and a separate 54 px header /
26 px player-row composite with shipped class/race icons were visually
inspected. Browser rendering was not exercised.

**Upgrade classification: compatible.** Development artwork only;
no Lua, game assets, model, saved state, map generation, version or upgrade
declaration changes. Nothing under `mods/` changed. No fixtures, game
server, engine boot, sync, merge or push were run.

## Handoff

After the user's pick, the coordinator copies the chosen emblem/banner
files to the existing runtime paths and records their provenance. A mixed
pick is possible; a matched pair keeps the strongest visual consistency.

Integration must also reconcile `tools/r63_camp_art/build.py`: its
`svg_text()` still generates the old symbols, so its current rebuild
would overwrite a newly selected runtime image and its `--check` would
reject it. That generator and all runtime files are outside this lane.

The independent lane review belongs to the coordinator before integration.
This implementer did not launch a reviewer or claim review acceptance.
The user's desktop **and** web GUI checklist after integration:

1. Inventory headers and Social rows at normal UI size, including alongside
   all class/race icons; verify faction colour, clarity and transparency.
2. Banners from both sides, near and several metres away, in daylight and
   normal interior lighting; verify orientation, cloth tip and attachment.
3. All factions' banner instances use the selected motif and no old emblem
   is regenerated by the owning asset tool.

## Commit receipt

- `0c69ca6f`: original motifs, candidates, generator, UV/hash evidence and licence.
- **Final art/preview commit:**
  `37becd54067b2f999176b0b997b76f0ec70e1e33`.
  At this complete-art checkpoint, **`git status --porcelain` was empty**.
- This report is the following documentation-only commit. Its final branch
  hash and the post-report clean-tree check are included in the final
  handoff, which the runner saves as `last.md`. A tracked report cannot
  embed its own commit hash without changing that hash; resolve its final
  commit locally with `git log -1 --format=%H -- tools/r67_emblem/REPORT.md`.

Every lane commit ends with
`Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.
