# Round 67 follow-up EMBLEM — delivery

**Pass 3 recommendation: A1 for The Accord, B1 for The Throng.**
Open the [offline preview](preview/index.html) or the
[contact sheet](preview/contact.png). The three harts and three boars are
independent choices: every hart fits every boar in palette, framing and
finish. These remain proposals awaiting the user's selection.

## Pass 3 — deliberate animal heraldry, 2026-10-31

The user selected Pass 2's Hart & Boar direction but rejected the drawings:
the hart's antlers were heavy and the boar's anatomy unclear. All six
Pass 3 drawings are new, authored explicitly as contours in `heraldry.py`.
They use tapered antler branches, deliberate negative-space cuts, consistent
1.3-unit engraved details and a restrained three-material palette. The
front-facing animals' silhouette and detail masks are exactly mirrored.
There are no generated bitmap sources, traced images or font symbols.

Pass 2's cloth-faced shields, fine gold rims, muted cloth and weathering
remain. The animal fills a larger area in the recommended head variants;
the full-body alternatives have smaller heads to keep their feet inside
the heraldic field. On banners, the same animal appears without a second
shield, between the retained corner vines and leaf spray.

| Choice | Animal and treatment | Assessment |
|---|---|---|
| **A1 — The Watchful Hart** | Front-facing head, long narrow face, open ears and slender mirrored antlers. | **Recommended for The Accord.** The broad branching top and narrow face make a strong upright silhouette; the face remains central and the antlers have open space between their tines. |
| **A2 — The Standing Hart** | Full hart statant in profile, upright neck, level back and four fine legs. | The most complete animal heraldry. Its smaller head and antlers trade close-up detail for the full-body pose. |
| **A3 — The Oathhart** | Hart head couped in profile, elongated neck and two swept branching antlers. | A more directional livery silhouette; its long neck and lateral muzzle contrast with A1's symmetry. |
| **B1 — The Ironwood Boar** | Boar head couped in profile, blunt long snout, distinct ear, rising lower tusk and bristled nape. | **Recommended for The Throng.** The heavy forward profile contrasts with A1's upright branches; a field-coloured separation makes the tusk distinct from the cheek. |
| **B2 — The Marching Boar** | Full boar passant, low snout, heavy shoulder, bristled back, four stout legs and a hooked tail. | The most physical, marching alternative. The face and tusk are necessarily smaller at row size. |
| **B3 — The Defiant Boar** | Front-facing boar head, broad ears, blunt nose disk, paired tusks and a symmetrical bristled mane. | A compact frontal counterpart to A1, with a broad face and no antlers; nose and tusk detail is clearest at header/banner size. |

At **24 px**, judge the branching hart, profile snout or full-body outline;
the engraving is subordinate. At **16 px**, tines and small facial details
soften, while the principal light shape and faction field remain. These
are observations of offline raster comparisons, not GUI acceptance.

The art follows the proud rival factions and old conflict described in
[world.md](../../docs/design/world.md), [pvp.md](../../docs/design/pvp.md)
and [story.md](../../docs/design/story.md). The names and symbolic
interpretations here are proposals, not new canonical faction history.
The depth and Nether TODO files do not block this art lane.

### Palette and finish

| Material | Base colour |
|---|---|
| The Accord cloth and shield | **#344b5a**, muted slate blue |
| The Throng cloth and shield | **#683e39**, muted wine/rust red |
| Main animal | **#d6c59b**, old ivory |
| Rim, engraving and ornament | **#aa9164**, tarnished gold |

The cloth bases are sampled from the most frequent fully opaque RGB in
the shipped banners. Pass 3 keeps Pass 2's subtle weave, uneven dye,
faded edges, worn hem and matte pigment/thread treatment. Each emblem
has three material tones: faction field, ivory and gold; surface variation
and antialiasing add intermediate shades. Saturated primaries are absent.

## Pass 2 — retained direction and comparison

Pass 2 was delivered in art commit
`55ea1695a69ed56541f44166461d9325a2e8219d`, with report commit
`c0c2a4a1`. Its A pair established the accepted muted palette, weathered
cloth and heraldic shields. Its drawings have now been replaced.

The four A-pair candidate images are preserved **byte for byte** only as
`preview/ref_pass2_{emblem,banner}_{accord,throng}.png`; their fixed hashes
are checked by the generator. Their two model projections also reproduce
the old views exactly. The preview includes this pair with every usage
mock, alongside unchanged shipped art. Pass 2 B/C and all Pass 1 candidates
remain only in git history. No letter-suffixed candidate files remain.

## Files and UV contract

There are **12 candidate PNGs**, all RGBA:

- `candidates/emblem_accord_{1,2,3}.png` and
  `candidates/emblem_throng_{1,2,3}.png`: **100 × 100**, transparent outside
  the shield, drawn at 6× and reduced with Lanczos.
- `candidates/banner_accord_{1,2,3}.png` and
  `candidates/banner_throng_{1,2,3}.png`: **128 × 256**, retaining the
  corresponding shipped alpha channel **byte for byte**.

The generator reads the existing B3D and checks its rest transforms and
UVs. The first material buffer is the double-sided rectangular cloth,
**0.96 × 2 nodes**. Its front vertices are:

| Position, in nodes | UV |
|---|---|
| `(-0.48, 0.50, -0.52)` | `(0, 0)` |
| `( 0.48, 0.50, -0.52)` | `(1, 0)` |
| `( 0.48,-1.50, -0.52)` | `(1, 1)` |
| `(-0.48,-1.50, -0.52)` | `(0, 1)` |

V increases downward and the whole texture maps onto the rectangle.
Alpha defines the pointed hem; its bounding box stays `(7, 29, 121, 227)`
with exclusive maxima. Padding, attachment, cloth cut and orientation are
unchanged. The other two material buffers are rod and straps.

All ten projections use this actual mesh at rest with a common camera
approximately 5 m away, treating a node as a metre. A simple support pole
and beam provide context. Projections are offline illustrations, not
engine screenshots; the profile animals keep the flat texture's direction.

[manifest.json](manifest.json) records Pass 3, variant labels, the
recommendation, palette, model hash, measured vertices/UVs, reference
provenance and candidate hashes. [LICENSE-media.md](LICENSE-media.md)
records the original **CC0-1.0** art and the retained comparison/alpha
attributions.

## Preview and reproduction

`preview/index.html` places all three harts side by side and all three
boars side by side. Narrow windows scroll each row horizontally. Every
candidate, Pass 2 A and current-art reference shows:

- UI icons at **16, 24, 32 and 64 px** on **#181e28**.
- An inventory header with a **54 px** icon and the faction name.
- Three online-player rows with **26 px** faction icons, names, shipped
  class/race icons and levels; all six races are represented.
- The flat banner texture and a projection on the existing model.

The recommendation appears at the top. All images are beside the page,
with relative paths, no scripts, external URLs or fetched fonts.

From the repository root:

```sh
python3 tools/r67_emblem/generate.py
python3 tools/r67_emblem/generate.py --check
```

Verified dependencies: **Python 3.14.8, Pillow 12.3.0, numpy 2.4.6**.
`heraldry.py` owns drawing and finish, `generate.py` sampling and outputs,
and `preview_page.py` the HTML. The four `ref_pass2_*.png` files are
tracked immutable generator inputs, not disposable build products.

## Verification and handoff

`--check` passed for **55 byte-reproduced outputs**: 12 candidates,
12 matching preview copies, 18 reference images, ten projections, one
contact sheet, one HTML page and one manifest. It checks RGBA/dimensions,
transparent icon edges, exact banner alpha, matching candidate copies,
local HTML references and unexpected output files.

Additional artifact checks passed: Python syntax, `git diff --check`,
exact correspondence of all 18 references to their source bytes (Pass 2
via its committed blobs), removal of the retired candidate filenames,
and exact geometry/detail symmetry for A1 and B3. The contact sheet,
projected banners, enlarged head drawings and an offline 54 px header /
26 px player-row composite with the shipped icons were visually inspected.
The final B1 tusk separation was additionally inspected enlarged.
Browser rendering was not exercised.

**Upgrade classification: compatible.** This package changes development
art only. `git diff c0c2a4a1 -- mods/` is empty. No Lua, runtime asset,
model, saved state, world generation, game version or upgrade declaration
changed. No fixtures, game server, engine boot, sync, merge or push ran.
Only `tools/r67_emblem/` and its single `tools/README.md` entry changed.

After the independent hart and boar selections, the coordinator copies
those four chosen PNGs to the existing runtime paths and records media
provenance. It must also reconcile `tools/r63_camp_art/build.py`, whose
`svg_text()` still generates the old symbols: rebuilding it would overwrite
the selection and its `--check` would reject the new art. That generator,
`docs/design/settlements.md` and runtime files are outside this lane.

The independent lane review belongs to the coordinator before integration;
this artist does not claim independent review acceptance. After integration,
the user's **desktop and web** GUI checklist is:

1. Inspect headers and Social rows at normal UI size alongside every
   class/race icon: colour, silhouettes and transparency.
2. Inspect banners from both sides, near and several metres away, in
   daylight and interior lighting: orientation, attachment and pointed hem.
3. Check that all banner instances use the selected animals and that the
   owning asset generator does not restore the old symbols.

## Commit receipt

- **Final Pass 3 art/preview commit:**
  `cf2e454a748e15bc0d5da7bda9376a4a3dd8565c`.
  At this complete-art checkpoint, **`git status --porcelain` was empty**.
- This report is the following documentation-only commit. Its final branch
  hash and post-report clean-tree result are in the final response, which
  the runner saves as `last.md`. A tracked report cannot embed its own
  commit hash without changing it; resolve that final commit with
  `git log -1 --format=%H -- tools/r67_emblem/REPORT.md`.

Both Pass 3 commit messages end with
`Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.
