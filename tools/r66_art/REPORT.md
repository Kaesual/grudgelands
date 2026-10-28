# Round 66 ART — priest symbols

Delivered on `r66-art`. **Hammer C is picked; Book G is recommended.**
The book choice awaits the user. Open [the local preview](preview/index.html)
or the [contact sheet](preview/contact-sheet.png).

## Pass 4 — thick hardcover tomes (2026-10-28)

The user picked Hammer C for Smite and Final Word. The user preferred
Book F's stronger backward tilt but found the binding bent, requesting a
thick open hardcover with visible rigid boards, a substantial page block
and a straight central spine. Smite's preview size increases from 5 to 7.
These instructions supersede the pass-3 recommendation and the round
plan's earlier Smite size default for this preview and the FX handoff.

| Texture | Idea | Status |
|---|---|---|
| [Hammer C](candidates/smite_hammer_c.png) | Crowned head, flared striking faces, diamond seal and ringed grip. | Picked; candidate and preview copy remain byte-identical to pass 3. |
| [Book G](candidates/censure_book_g.png) | Thick square gold boards beneath a broad ivory page block, with a firm straight spine. | Recommended: the substantial board edge makes the hardcover construction clearest. |
| [Book H](candidates/censure_book_h.png) | A deeper page block on slimmer gold boards with clipped outer corners. | Alternative: more page depth, less board weight, the same reclined pose. |

Both books preserve F's perspective projection: far scale 0.56, far y 25,
near y 48, a 23-pixel projected reference depth. Each page is now a straight
quadrilateral. The covers and page block have distinct top, side and near
faces; the boards protrude around the page edges. G has 4 pixels of page
block depth and 2.5 pixels of board depth; H has 6 and 1.25 respectively,
measured as vertical extrusion in the source sprite. The near board edges
are straight, with parallel lower edges. A narrow luminous strip runs
straight through the middle, flanked by translucent hinge channels;
there is no curved lower lip or splayed foot at the spine.

All three textures are **64 × 64 RGBA PNGs**, in white, ivory and pale
gold with a small gold accent. Bright source RGB, opaque page cores,
translucent cut faces and transparent gaps separate the volumes under
additive light. The borders are transparent and the halo stays tight.
The pages have no text or markings; two light divisions on the cut face
suggest stacked leaves. The 64 px source gives the larger fall room for
the board and page thickness while retaining a simple small silhouette.

### Preview and retired candidates

The top recommendation distinguishes the picked Hammer C from the open
book choice. Hammer C occupies a compact section; a native HTML disclosure
opens its unchanged 16/32/64 px ground comparisons. Each book shows the
same enlarged hero, 16/32/64 px samples and night/cave/snow/sky/sand rows,
plain alpha and additive light side by side.

Two context strips pair Hammer C with G and H. Each shows **Smite 7,
Final Word 12, Censure 16**, beside the established figure one node wide
and two nodes tall. The catalogue preview conversion remains one size
unit = 0.1 node (`tools/r52_pfx/template.html`): sprite squares of
0.7 / 1.2 / 1.6 nodes, or 44.8 / 76.8 / 102.4 CSS px. Transparent margins
make the visible objects smaller. The page uses `plus-lighter` with a
labelled `screen` fallback. There are no download links, scripts or
external requests.

Hammer D and Book E/F are removed from `candidates/`, `preview/`, the
generator, page template, generated page and contact sheet. Their images
remain in git history only. The [media ledger](LICENSE-media.md) records
the three current textures and their matching preview copies.

### Generation and verification

From the repository root:

```sh
python3 tools/r66_art/generate.py
python3 tools/r66_art/generate.py --check
```

Dependencies remain Python 3, Pillow and numpy. Eight outputs are written:
three candidates, three identical preview copies, the page and contact
sheet. `--check` regenerates in memory and compares every output byte for
byte. Both modes verify RGBA dimensions, transparent borders and exact
book symmetry, and reject unexpected generated PNGs.

Completed checks:

- `generate.py --check`: all eight outputs match; no retired PNGs remain.
- Hammer C candidate matches the pass-3 git blob byte for byte; its preview
  copy matches too. SHA-256:
  `c76a35ea6d3221ab8ab51cb0aade0c24dcbc0b7491425bffa00ba64acc06b77d`.
- Pixel audit: all three images have opaque cores, fully transparent
  borders and RGB at least (245, 218, 155) wherever alpha is nonzero;
  both books are exactly mirror-symmetric.
- HTML audit: 101 image instances, 15 ground rows, two context pairings;
  image dimensions, alt text, local paths and anchors are valid. Context
  sizes are 7/12/16 in both strips; no downloads, remote resources,
  scripts, unresolved template tokens or retired candidates.
- Visual inspection of the contact sheet and native 16/32/64 px raster
  composites, plain and additive, on all five grounds. The temporary
  inspection composite was removed after inspection.
- Python source parses with Python 3.9 grammar; `git diff --check` passes.
  No file under `mods/` changed.

At 16 px the outer spread and central division do most of the work; the
fine page divisions are secondary. On near-white additive grounds,
interior tones, spine and board separation lose contrast. The preview
shows this limitation. Engine tint, fall timing and combat readability
still require the user's desktop/web acceptance after FX integration.
No browser, game, server or Lua fixture was run for this art-only pass.

### Handoff and receipt

**Upgrade classification: compatible.** Development art and preview only;
no runtime behavior, saved state, world generation, version declaration
or migration changes. The coordinator's independent review and the user's
book pick precede FX integration. FX uses Hammer C at Smite size 7 and
Final Word size 12, then the picked book at Censure size 16, and records
the runtime media provenance. This implementer launched no agents and
performed no merge, push or Luanti sync.

Art, generator and preview commit:
`ed47576ead9e35dc38667bc62161ddac630e0391`.
The following documentation commit contains this report and the requested
[final report](../../last.md). Its literal hash is returned in the delivery
message; resolve it without a self-referential hash in its own contents:

```sh
git log -1 --format=%H -- last.md
git status --porcelain
```

The handoff status output is empty. Both pass-4 commit messages end with
`Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.

GUI checklist after FX integration, on desktop and web:

1. Read Hammer C at size 7 during repeated Smite hits, with its ring at
   impact; confirm the straight, head-first fall and comfortable size.
2. Read the same hammer at size 12 inside Final Word's white column.
3. Read the picked thick open book at size 16 during Censure's 6 m fall
   after its warning ring; check the straight spine, hardcover thickness,
   tint, timing and impact on dark and bright terrain.

## Pass 3 — historical receipt

Art commit `c71c23c7be3fca84e43865179f5cf0f4fe60427f`, report commit
`1a318911d9b49745e8d94e030115b32fa5ae5e88`. Pass 3 offered shaped
Hammer C/D and inclined Book E/F, recommending C/E. The user subsequently
picked Hammer C and preferred F's stronger tilt. Pass 4 preserves those
choices and replaces both book candidates with thick hardcover versions.
The full pass-3 report and superseded images remain in those commits.

## Pass 2 — historical receipt

Art commit `9d18530f43822ebaee4533d9b8765598f07eceee`, report commit
`ea462169f530ff359577a96bdbc2175dd3ac2033`. Hammer A was picked and
preserved byte-identically; two symmetric frontal books replaced the
rejected side-view books. Book C was recommended for its broad, quiet
spread; Book D offered taller lifted pages. The full pass-2 report and
images remain in those commits. Pass 3 supersedes that choice set and
retains the preferred spread's character in the new inclined books.

## Pass 1 — historical receipt

Art commit `358aff5339e6cbfa17ffd93307fe7e663e186554`, report commit
`4374dc8eb4dec8f354dde80cc4306df96a1a3437`. Pass 1 offered Hammer A/B and
two side-view books with an A/A recommendation. Those images and the
original report remain in git history.

## Blockers / questions

None for this delivery. The user chooses Book G or H before FX integration;
G is the artist's recommendation, not an accepted pick. Hammer C is picked.
