# Round 66 ART — priest symbols

Delivered on `r66-art`. **Pass 3 recommendation: Hammer C + Book E.**
Both choices await the user. Open [the local preview](preview/index.html)
or the [contact sheet](preview/contact-sheet.png).

## Pass 3 — shaped hammers and inclined books (2026-10-28)

The user retained Hammer A's head-down side view but requested a more
interesting silhouette. The user preferred the broad, quiet open Book C
and requested backward tilt: the upper edge recedes, the spread is
foreshortened, and the far edge is narrower than the near edge. This pass
supersedes the earlier hammer pick and book recommendation.

| Texture | Idea | Recommendation |
|---|---|---|
| [Hammer C](candidates/smite_hammer_c.png) | A broad crowned head with flared striking faces, a diamond seal, three grip rings and a diamond pommel. | Recommended: the shaped ends remain distinct at small sizes and give the fall weight. |
| [Hammer D](candidates/smite_hammer_d.png) | A broad chamfered face opposes a tapered ivory beak, beneath a wrapped grip and faceted pommel. | Alternative: a visibly asymmetric war hammer with a lighter back. |
| [Book E](candidates/censure_book_e.png) | The quiet spread tilts moderately backward, keeping broad blank pages and the central fold. | Recommended: the inclination is visible while more page area remains at 16 px. |
| [Book F](candidates/censure_book_f.png) | The same spread leans farther away, with a shorter depth and stronger convergence toward the top. | Alternative: the more reclined lectern pose. |

Both hammers keep a vertical handle above a horizontal head; no diagonal
rotation or trail suggests a different fall. Their outline carries the
identity. The grip, pale seal and face accents are secondary details that
can disappear when additive light saturates.

The books reuse the preferred spread's geometry through a perspective
projection, then mirror its left half about the exact image centre. Far
edge scale is 0.74 for E and 0.56 for F; the projected depth is 31 and 23
pixels respectively. The outer edges converge upward, the pages remain
blank, and the shallow central fold stays open above the joined binding.
There is no sideways rotation or asymmetric page lift.

All four candidates are **64 × 64 RGBA PNGs**. White, ivory and pale gold
form opaque cores, with a small gold accent, bright antialiased edges,
fully transparent borders and a tight halo. Transparency defines gaps;
there is no dark outline. The source size leaves room for the shaped
hammer heads and book folds at the larger effect sizes while preserving
simple silhouettes at 16 px.

### Preview and retired candidates

Each candidate has an idea sentence, enlarged hero and 16/32/64 px views
on night, cave, snow, sky and sand, with plain alpha and additive light
side by side. The top recommendation is C/E. All four pairings, C/E,
C/F, D/E and D/F, appear in context beside the established figure one
node wide and two nodes tall. Each pairing shows its hammer for Smite
and Final Word and its book for Censure.

The existing catalogue conversion stays at one size unit = 0.1 node
(`tools/r52_pfx/template.html`): sprite squares of 0.5 / 1.2 / 1.6 nodes
for sizes 5 / 12 / 16. Transparent margins make the visible objects
smaller. The page uses `plus-lighter` with a labelled `screen` fallback;
all assets are local, with no download links, scripts or external requests.
The contact sheet and [media ledger](LICENSE-media.md) show the four new
candidates only.

Superseded Hammer A/B and Book C/D PNGs are removed from `candidates/`
and `preview/`, and their candidates are removed from the generator,
page template, generated page and contact sheet. None is retained as an
archival output; their original images and reports remain in git history.

### Generation and verification

From the repository root:

```sh
python3 tools/r66_art/generate.py
python3 tools/r66_art/generate.py --check
```

Python 3, Pillow and numpy remain the dependencies. The generator writes
ten outputs: four candidates, four byte-identical preview copies, the
page and contact sheet. `--check` regenerates in memory and compares all
ten byte for byte. Both modes check dimensions, RGBA, transparent borders
and exact book symmetry, and reject unexpected generated PNGs.

Completed checks:

- `generate.py --check`: all ten outputs match, with no retired PNGs.
- Pixel audit: all four candidates have opaque cores, transparent borders
  and RGB at least (245, 218, 155) wherever alpha is nonzero; every preview
  copy matches its candidate byte for byte.
- Both books are exactly mirror-symmetric. At alpha >= 200, the span two
  rows below the first solid row versus four rows above the last is
  38/48 px for E and 30/46 px for F, confirming a narrower upper edge.
- HTML audit: 138 image instances with alt text and integer dimensions,
  20 ground rows, four context pairings; all local paths and fragments
  resolve, with no downloads, scripts, remote resources or template tokens.
- Visual inspection of the contact sheet and native 16/32/64 px raster
  composites, plain and additive on all five grounds.
- Python source parses with the Python 3.9 grammar; `git diff --check`
  passes. No file under `mods/` changed.

Bright additive light washes the interior tones toward white. At 16 px,
the book gutter and the small hammer accents lose contrast on snow; the
preview shows this limit. Engine tint, fall timing and combat readability
still require the user's desktop/web acceptance after FX integration.
No browser, game, server or Lua fixture was run for this art-only pass.

### Handoff and receipt

**Upgrade classification: compatible.** Development art and preview only;
no runtime behavior, saved state, world generation, version declaration
or migration changes. The user's hammer and book choices and the
coordinator's independent review precede FX integration. FX copies the
picked candidates into the owning mod and records their runtime media
provenance. This implementer launched no agents and performed no merge,
push or Luanti sync.

Art, generator and preview commit:
`c71c23c7be3fca84e43865179f5cf0f4fe60427f`.
The following documentation commit contains this report and the requested
[final report](../../last.md). Its literal hash is returned in the delivery
message; resolve it without a self-referential hash in its own contents:

```sh
git log -1 --format=%H -- last.md
git status --porcelain
```

The handoff status output is empty. Both pass-3 commit messages end with
`Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.

GUI checklist after FX integration, on desktop and web:

1. Read the selected small hammer during repeated Smite hits and its ring
   at impact; confirm a straight, head-first fall.
2. Read the same larger hammer inside Final Word's white column.
3. Read the selected inclined open book during Censure's 6 m fall after
   the warning ring, at ordinary combat distance on dark and bright
   terrain; check the central fold, tint, timing and impact.

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

None for this delivery. The user chooses Hammer C/D and Book E/F before
FX integration; C/E is the artist's recommendation, not an accepted pick.
