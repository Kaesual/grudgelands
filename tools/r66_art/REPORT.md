# Round 66 ART — priest symbols

Delivered on `r66-art`. **Hammer C is picked; J is the user's favourite;
Book P is the recommended refinement.** The user chooses the final degree
from O/P/Q. Open [the local preview](preview/index.html) or the
[contact sheet](preview/contact-sheet.png).

## Pass 6 — Book J, refined (2026-10-28)

The user preferred J's gentle dome and curved writing, asking for a
slightly flatter dome and minimally wider pages. This pass changes only
those two dimensions in three close steps. J stays byte-identical as the
reference labelled **J, pass 5**. Hammer C stays picked and byte-identical.

| Texture | Dome amplitude | Width factor | Change from J |
|---|---:|---:|---|
| [J, pass 5](candidates/censure_book_j.png) | 5.0 | 1.000 | Unchanged reference. |
| [Book O](candidates/censure_book_o.png) | 4.6 | 1.025 | Smallest change: dome −8%, width +2.5%. |
| [Book P](candidates/censure_book_p.png) | 4.2 | 1.050 | Middle step: dome −16%, width +5%. **Recommended.** |
| [Book Q](candidates/censure_book_q.png) | 3.8 | 1.075 | Largest change: dome −24%, width +7.5%. |

Dome amplitudes are source-pixel parameters before perspective scaling;
width factors multiply the outer page and board spans about the centre.
The hinge positions stay fixed. These are geometric parameters, not
measurements of the antialiased pixel bounds.

**Recommendation: P.** Its slightly broader spread and softer crown make
J calmer while keeping the upward bow out of the gutter clear. O is the
closest to J; Q offers the next small step toward a flatter spread. This
is an artist's recommendation; the user's refinement choice is open.

### Preserved construction and palette

The reclining projection stays at far scale 0.56, far y 25 and near y 48.
The page depth stays 4.5 and the board depth 0.9. Square gold boards keep
straight edges beneath the layered leaves. Five thin contours suggest the
stacked page edges; the gutter stays narrow and straight. Lowering the
dome does not flatten it entirely: every half still rises out of the
gutter and rolls down toward the outer edge.

All four books carry J's four quiet curved lines per page, with the same
margins, shorter final line, stroke width and pale-gold colour. They are
drawn on the page surface itself, so they follow each flatter curve. No
letters, glyphs or readable text are added.

All five textures are **64 × 64 RGBA**, white, ivory and pale gold, with
bright source RGB, transparent borders and the existing tight halo. No
dark outline is used. The 64 px source preserves smooth contours and
layered edges in the larger effect; the silhouette remains recognisable
at 16 px, where the writing blends into the page.

The art remains original authored geometry, CC0-1.0; the generator is
GPL-3.0-or-later. The [media ledger](LICENSE-media.md) lists the active
candidates and matching preview copies. No imported image is added.

### Preview and retired candidates

The recommendation is at the top. Hammer C remains compact, with its
five-ground comparisons in a disclosure. **J/O/P/Q are side by side** in
one aligned comparison, horizontally scrollable on narrow windows. Every
book shows an enlarged view and actual **16/32/64 px** samples on night,
cave, snow, sky and sand, in plain alpha and additive light. The contact
sheet also places J/O/P/Q in one row.

Each refinement has its own context strip: Hammer C at **Smite 7** and
**Final Word 12**, then O, P or Q at **Censure 16**. The established scale
is one size unit = 0.1 node, with one node = 64 CSS px: sprite squares of
44.8 / 76.8 / 102.4 CSS px beside a one-node-wide, two-node-tall figure.
The page retains `plus-lighter` and the labelled `screen` fallback. It has
no download links, scripts or external requests.

Book I/K/L/M/N are removed from `candidates/`, `preview/`, the generator,
page and contact sheet. Their art and full pass-5 receipt remain in git
history. Retired shape options are removed from the generator. The
inspection scratch image was removed before committing.

### Generation and verification

From the repository root:

```sh
python3 tools/r66_art/generate.py
python3 tools/r66_art/generate.py --check
```

Dependencies remain Python 3, Pillow and numpy. Twelve outputs are
written: five candidates, five identical preview copies, the HTML page
and contact sheet. `--check` regenerates in memory and compares bytes.
Both modes check dimensions, transparent borders and book symmetry,
and reject unexpected generated PNGs.

Completed checks:

- `generate.py --check`: all 12 outputs match; retired PNGs are absent.
- Hammer C matches the picked pass-3 git blob and its preview copy.
  SHA-256: `c76a35ea6d3221ab8ab51cb0aade0c24dcbc0b7491425bffa00ba64acc06b77d`.
- J matches the pass-5 git blob and its preview copy.
  SHA-256: `83f02d702a414c59b60ca78a040ecb449dd9e9e7a7562df88979e715f48dc60e`.
- Pixel audit: five distinct images, opaque cores, transparent borders,
  RGB at least (245, 218, 155) wherever alpha is nonzero, exact mirror
  symmetry for all four books and matching candidate/preview bytes.
- HTML audit: 166 image instances, 25 ground rows, three context strips
  at 7/12/16; valid local paths, anchors, dimensions and alt text. No
  retired candidates, downloads, scripts or unresolved template tokens.
- Visual inspection of the contact sheet and native 16/32/64 px plain
  and additive composites of J/O/P/Q on all five grounds. The writing
  stays quiet at 16 px; the three changes remain deliberately close.
- Python source parses with Python 3.9 grammar; `git diff --check` and
  documentation links pass. Only `tools/r66_art/` and `last.md` changed.

Near-white additive grounds wash out interior tones and writing, as the
preview shows. Engine tint, fall timing and combat readability still need
the user's desktop/web acceptance after FX integration. No browser,
game, server or Lua fixture was run.

### Handoff and receipt

**Upgrade classification: compatible.** Development art and preview only;
no runtime behavior, saved state, world generation, version declaration or
migration changes. Nothing under `mods/` changed. The coordinator's
independent review and the user's refinement pick precede FX integration.
This implementer launched no agents and performed no merge, push or sync.

Art, generator, preview and media ledger commit:
`1a2745d1394eaf0f2b0cdf00d7a1c6eb1ae5a14b`.
The following documentation commit contains this report and the requested
[final report](../../last.md). Its literal hash is returned in the delivery
message; resolve that receipt and verify the empty handoff status:

```sh
git log -1 --format=%H -- last.md
git status --porcelain
```

Both pass-6 commit messages end with
`Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.

GUI checklist after FX integration, on desktop and web:

1. Read Hammer C at size 7 during repeated Smite hits, with the ring at
   impact; confirm the straight, head-first fall and comfortable size.
2. Read the same hammer at size 12 inside Final Word's white column.
3. Read the picked refinement at size 16 during Censure's 6 m fall after
   its warning ring; check the softer page dome, slightly broader spread,
   straight gutter, thin square boards and layered edges.
4. Confirm that the four curved lines stay quiet with viewing distance;
   check tint, timing and impact on dark and bright terrain in combat.

## Pass 5 — historical receipt

Art commit `8822f0c5e98bc9f7ff62e8c0ce12d33ca6a2838c`, report commit
`4ecbe69f21ca6426f9787097d08bf60608e00844`. Six bowed-page books I–N
compared gentle, high and broad domes, with and without curved writing.
L was recommended; the user preferred J and requested the small dome and
width refinements in pass 6. J survives unchanged as the reference;
I/K/L/M/N and the full pass-5 report remain in those commits.

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

None for this delivery. The user chooses the degree of refinement from
O/P/Q before FX integration; P is recommended. J is the favourite from
pass 5 and remains the reference. Hammer C is picked. Independent review
remains with the coordinator.
