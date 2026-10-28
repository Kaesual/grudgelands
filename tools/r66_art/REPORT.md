# Round 66 ART — priest symbols

Delivered on `r66-art`. **Hammer A is picked; Book C is recommended.**
Open [the local preview](preview/index.html) or the
[contact sheet](preview/contact-sheet.png).

## Pass 2 — an open book for Censure (2026-10-28)

The user picked Hammer A for Smite and Final Word and rejected both
side-view books. Censure now has two symmetric open-book proposals facing
the viewer, with the spine in the middle and both pages fully visible.
The frontal pose suits the camera-facing sprite throughout its 6 m fall.

| Texture | Idea | Status |
|---|---|---|
| [Hammer A](candidates/smite_hammer_a.png) | Broad flat head, straight narrow handle, head down. | Picked, byte-identical to pass 1. |
| [Book C](candidates/censure_book_c.png) | Broad, flat ivory spread with a shallow central fold and a restrained gold cover edge. | Recommended: the quieter shape reads most clearly as an open book at 16 px. |
| [Book D](candidates/censure_book_d.png) | Taller white pages with a gentle, symmetric lift and visible lower page edges. | Alternative with more curvature in the spread. |

Both books are **64 × 64 RGBA PNGs**, exactly mirror-symmetric about the
centre of the image. They use bright white, ivory and pale gold, opaque
cores, transparent borders and a tight light halo. The central gutter
uses transparency, not dark ink. Pages are blank: no letters, text-like
strokes, flames or trails. The 64 px source leaves room for the central
fold and smooth edges at Censure's larger size while retaining simple
shapes at 16 px.

The rejected Book A/B PNGs are removed from `candidates/` and `preview/`,
and their geometry and references are removed from the generator, page
and contact sheet. Their pass-1 versions remain in git history. Hammer B
remains byte-identical and reproducible in the package as pass-1
provenance, but is absent from the active page and contact sheet.

### Preview

The recommendation is at the top. Hammer A has one compact **Picked**
section with its unchanged hero, 16/32/64 px views, five grounds and
plain/additive treatments. The two books have the same views on night,
cave, snow, sky and sand. The context strips both use Hammer A for Smite
and Final Word, with Book C or D for Censure, beside the original figure
one node wide and two nodes tall.

The sprite squares keep the pass-1 sizes of 0.5 / 1.2 / 1.6 nodes, from
the existing catalogue's preview conversion (size units 5 / 12 / 16;
`tools/r52_pfx/template.html`). Transparent margins make the visible
objects smaller than those squares. No fall, timing or column simulation
was added. The page uses CSS `plus-lighter`, with the existing labelled
`screen` fallback. All image paths are local; **there are no download
links**, scripts or external requests.

Additive light still washes the interior tones toward white on bright
ground. At 16 px the centre division also loses contrast on snow. The
preview exposes this directly; tint, timing and the final engine look
remain part of the user's desktop/web check after FX integration.

### Generation and verification

From the repository root:

```sh
python3 tools/r66_art/generate.py
python3 tools/r66_art/generate.py --check
```

The generator writes ten outputs: four candidates (including archived
Hammer B), four identical preview copies, the HTML page and the contact
sheet. `--check` regenerates in memory and compares every output byte for
byte. Both modes also check the books' exact symmetry and reject
unexpected PNGs left in the generated directories. Drawing is authored
in `generate.py`; layout is in `preview.html.in`. Dependencies remain
Python 3, Pillow and numpy.

Completed checks:

- `generate.py --check`: all ten outputs match; no retired PNGs remain.
- Both Hammer A files equal the pass-1 bytes at
  `4374dc8eb4dec8f354dde80cc4306df96a1a3437`. Their SHA-256 is
  `9b845bdb31a73327daf94e034ab040f0f815cb0ad290660be170b890892dfe9b`.
- All four generated candidates: 64 × 64 RGBA, opaque cores, fully
  transparent borders, bright RGB on every visible pixel, byte-identical
  preview copies. Both new books have exact horizontal pixel symmetry.
- HTML audit: 101 image instances with alt text and integer dimensions,
  15 ground rows, all local paths and fragments resolve; no downloads,
  scripts, remote resources, rejected books or unexpanded template tokens.
  Both context strips use the picked Hammer A.
- Visual inspection of the contact sheet and both books at native
  16/32/64 px, plain and simulated additive on all five grounds.
- Python source parses with the Python 3.9 grammar; `git diff --check`
  passes. Nothing under `mods/` changed.

No game, server, Lua fixtures or browser was run. Page markup and the
raster composites were checked; browser layout and in-game acceptance
remain with the user.

### Handoff and receipt

**Upgrade classification: compatible.** Development art and preview only;
no runtime behavior, world generation, saved state, version declaration or
migration changes. The [media ledger](LICENSE-media.md) records the new
CC0 candidates. FX copies the picked Hammer A and the user's eventual
Book C/D choice to the owning mod and records their runtime provenance.
The book choice is still pending. Independent review stays with the
coordinator before integration; this implementer did not launch agents.
No merge, push or Luanti sync was performed.

Art, generator and preview commit:
`9d18530f43822ebaee4533d9b8765598f07eceee`.
The following report commit contains this file and the requested
[final report](../../last.md). Its final hash is returned in the delivery
message and can be resolved without a self-referential hash in this file:

```sh
git log -1 --format=%H -- last.md
git status --porcelain
```

The handoff status output is empty. Both pass-2 commit messages end with
`Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.

GUI checklist after FX integration, on desktop and web:

1. Read the picked small Hammer A during repeated Smite hits and its ring
   at impact.
2. Read the same larger hammer inside Final Word's white column.
3. Read the chosen frontal open book during Censure's 6 m fall after the
   warning ring, at ordinary combat distance on dark and bright terrain;
   check the applied tint, timing and impact.

## Pass 1 — historical receipt

Art commit `358aff5339e6cbfa17ffd93307fe7e663e186554`, report commit
`4374dc8eb4dec8f354dde80cc4306df96a1a3437`. Pass 1 offered Hammer A/B and
two side-view books with an A/A recommendation. The user's pass-2 ruling
supersedes that recommendation: Hammer A picked, both books rejected.
The original report and removed images remain in those commits.

## Blockers / questions

None for this delivery. The user chooses Book C or D before FX integration;
Book C is the artist's recommendation, not an accepted pick.
