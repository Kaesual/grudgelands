# Round 66 ART — priest symbols

Delivered on `r66-art`. **Hammer C is picked; Book L is recommended.**
The book choice awaits the user. Open [the local preview](preview/index.html)
or the [contact sheet](preview/contact-sheet.png).

## Pass 5 — bowed pages and curved writing (2026-10-28)

The user settled the backward tilt and hardcover construction in pass 4,
then requested bowed page halves, thin rigid boards and a narrow straight
gutter. The updated brief asks for four to six variants and welcomes quiet
stylised writing that follows the page curvature. This pass supplies six
books in three matched pairs; the second of each pair adds writing.

| Texture | Page shape and boards | Page markings |
|---|---|---|
| [Book I](candidates/censure_book_i.png) | Gentle arch, moderate page block, square boards. | Blank. |
| [Book J](candidates/censure_book_j.png) | Same geometry as I. | Four curved lines per half. |
| [Book K](candidates/censure_book_k.png) | Higher arch, deeper page block, clipped boards. | Blank. |
| [Book L](candidates/censure_book_l.png) | Same geometry as K. **Recommended.** | Four curved lines per half. |
| [Book M](candidates/censure_book_m.png) | Broader rounded crown, medium page block, square boards. | Blank. |
| [Book N](candidates/censure_book_n.png) | Same geometry as M. | Four curved lines per half. |

**Recommendation: L.** Its high arches and deeper layered edges make the
bowed paper clearest; the restrained writing adds character at larger
sizes and blends away at 16 px. K offers the same shape with blank pages.
This is an artist's recommendation, not an accepted user pick.

### Shape, palette and provenance

All books preserve pass 4's projection: far scale 0.56, far y 25,
near y 48, a 23-pixel projected reference depth. Each half rises smoothly
out of the central gutter, crowns above the page block, then rolls down
to its outer edge. Five thin light contours on the front cut face and
outer side suggest stacked leaves; lower leaves settle onto the rigid
boards. The centre stays straight and less than one source pixel wide.
The cover boards retain straight edges, with parallel lower edges.

The gentle pair uses dome amplitude 5, page depth 4.5 and board depth 0.9;
the high pair uses 7.5 / 6 / 1; the broad pair uses 6.2 / 5.2 / 0.9 with
fuller shoulders. These are generator parameters in source pixels before
the dome is scaled by perspective. Writing uses the page's own surface
projection: four continuous arcs with generous margins and a shorter last
line. There are no letters, glyphs or readable words. A fine pale-gold,
slightly translucent stroke keeps the writing secondary to the shape.

All seven textures are **64 × 64 RGBA**, white, ivory and pale gold, with
bright source RGB, transparent borders and a tight light halo. Opacity
separates the page layers under additive light; no dark outline is used.
The source resolution gives the large Censure symbol room for its curved
surface and layered edges while preserving a clear small silhouette.

The user's photo-illustration was viewed for orientation only. No part
was copied, traced, embedded or added to the repository. The geometry is
original; there is no ribbon, wear or torn paper. The [media ledger](LICENSE-media.md)
records all seven textures and their matching preview copies.

### Preview and retired candidates

The recommendation sits at the top. Hammer C remains compact and marked
picked, with its existing five-ground comparisons inside a native HTML
disclosure. All six books show enlarged heroes and native **16/32/64 px**
samples on **night, cave, snow, sky and sand**, in plain alpha and additive
light. The three pairs compare blank and written pages side by side;
internal links jump to each pair.

Six context strips pair each book with Hammer C at **Smite 7, Final Word
12, Censure 16**, beside the established one-node-wide, two-node-tall
figure. The catalogue conversion stays one size unit = 0.1 node
(`tools/r52_pfx/template.html`): sprite squares of 0.7 / 1.2 / 1.6 nodes,
or 44.8 / 76.8 / 102.4 CSS px. The page retains `plus-lighter` and its
labelled `screen` fallback; there are no download links, scripts or
external requests. The contact sheet shows all six books in three rows.

Book G/H are removed from `candidates/`, `preview/`, generator, page and
contact sheet; history keeps them. Hammer C and its preview copy remain
byte-identical to the picked pass-3 art. The interrupted run's inspection
scratch image was removed. The tools index now links to this report for
the current selection rather than repeating obsolete candidate names.

### Generation and verification

From the repository root:

```sh
python3 tools/r66_art/generate.py
python3 tools/r66_art/generate.py --check
```

Dependencies remain Python 3, Pillow and numpy. Sixteen outputs are
written: seven candidates, seven identical preview copies, the HTML page
and contact sheet. `--check` regenerates in memory and compares all bytes.
Both modes verify dimensions, transparent borders and book symmetry,
and reject unexpected generated PNGs.

Completed checks:

- `generate.py --check`: all 16 outputs match; retired PNGs are absent.
- Hammer C matches the pass-3 git blob and its preview copy byte for byte.
  SHA-256: `c76a35ea6d3221ab8ab51cb0aade0c24dcbc0b7491425bffa00ba64acc06b77d`.
- Pixel audit: seven distinct images, opaque cores, transparent borders,
  RGB at least (245, 218, 155) wherever alpha is nonzero, exact mirror
  symmetry for all six books and matching candidate/preview bytes.
- HTML audit: 237 image instances, 35 ground rows, six context pairings
  at 7/12/16; valid local paths, anchors, dimensions and alt text. No
  retired candidates, downloads, scripts or unresolved template tokens.
- Visual inspection of the contact sheet and native 16/32/64 px plain
  and additive composites of all six books on all five grounds. Writing
  merges into the paper at 16 px without changing the main silhouette.
- Python source parses with Python 3.9 grammar; `git diff --check` passes.
  Documentation links resolve. Nothing under `mods/` changed.

On near-white additive grounds the inner tones, gutter, writing and board
separation lose contrast, as the preview shows. The dark-ground silhouette
and page contours carry the small icon. Engine tint, fall timing and
combat readability still need the user's desktop/web acceptance after
FX integration. No browser, game, server or Lua fixture was run.

### Handoff and receipt

**Upgrade classification: compatible.** Development art and preview only;
no runtime behavior, saved state, world generation, version declaration or
migration changes. The coordinator's independent review and the user's
book pick precede FX integration. This implementer launched no agents and
performed no merge, push or Luanti sync.

Art, generator, preview and media ledger commit:
`8822f0c5e98bc9f7ff62e8c0ce12d33ca6a2838c`.
The following documentation commit contains this report, the tools-index
correction and the requested [final report](../../last.md). Its literal
hash is returned in the delivery message; resolve the receipt without a
self-referential hash in its own contents:

```sh
git log -1 --format=%H -- last.md
git status --porcelain
```

The handoff status output is empty. Both pass-5 commit messages end with
`Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.

GUI checklist after FX integration, on desktop and web:

1. Read Hammer C at size 7 during repeated Smite hits, with the ring at
   impact; confirm the straight, head-first fall and comfortable size.
2. Read the same hammer at size 12 inside Final Word's white column.
3. Read the picked book at size 16 during Censure's 6 m fall after its
   warning ring; check the upward page domes, narrow straight gutter,
   rigid boards and stacked edges on dark and bright terrain.
4. If a written variant is picked, confirm its lines follow the domes
   and stay quiet as the sprite shrinks with viewing distance; check
   tint, timing and impact in combat.

## Pass 4 — historical receipt

Art commit `ed47576ead9e35dc38667bc62161ddac630e0391`, report commit
`bc0f1a08` (the pass-5 base). Hammer C was picked and preserved; Book G/H
introduced thick hardcover construction with the preferred backward tilt
and straight spine. G was recommended. The user settled the perspective
and requested bowed pages, a narrower gutter and thinner boards for
pass 5. The full pass-4 report and retired images remain in those commits.

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

None for this delivery. The user chooses Book I–N before FX integration;
L is recommended. Hammer C is picked. Independent review remains with
the coordinator.
