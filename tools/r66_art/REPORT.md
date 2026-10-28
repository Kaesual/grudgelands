# Round 66 ART — priest symbols

Delivered on `r66-art`, based on `5e50b4f48a01e1a121786d551a2d1ee73c10b15d`.
**Recommendation: Hammer A + Book A.** The user may pick each independently.
Open [the local preview](preview/index.html) or the
[contact sheet](preview/contact-sheet.png).

## Proposals

| Texture | Idea | Recommendation |
|---|---|---|
| [Hammer A](candidates/smite_hammer_a.png) | Broad flat head, straight narrow handle, restrained bevels; head points down. | Recommended: the simplest silhouette at 16 px, suitable for the once-per-second Smite and the larger Final Word. |
| [Hammer B](candidates/smite_hammer_b.png) | Stepped end caps and a shorter grip; head points down. | A more ceremonial alternative with a wider head and stronger edge shaping. |
| [Book A](candidates/censure_book_a.png) | Closed thick folio in an oblique side view, lower edge first; page block between gold covers. | Recommended: the compact closed volume reads most consistently at small sizes. |
| [Book B](candidates/censure_book_b.png) | Side view of a closing volume, with a lifted cover and one fanned leaf. | More movement in the silhouette; its transparent opening survives additive blending. |

All four candidates are **64 × 64 RGBA PNGs**. At 16 px they keep the broad
object shape; 64 px gives the large effects smoother edges and enough room
for the page block. The three authored tones are white, ivory and pale
gold, with antialiasing and a tight alpha halo. There are no dark outlines,
letters, flames or trails. Transparent page divisions carry the book's
structure without relying on dark ink. All border pixels are transparent.

The preview shows every candidate at 16, 32 and 64 CSS px on night, cave,
snow, sky and sand, with plain alpha beside CSS `plus-lighter` addition
(`screen` fallback, labelled when active). Two context strips show the
planned Smite / Final Word / Censure sizes 5 / 12 / 16 beside figures one
node wide and two nodes tall. This follows the existing catalogue's
`size * 0.1` node conversion in `tools/r52_pfx/template.html:356`.
The page is static, uses relative local image paths and needs no server,
network access or JavaScript. Preview PNGs are byte-identical to candidates.

**Bright-ground observation:** addition washes the interior tones toward
white on snow, sky and sand. The silhouette remains visible against the
selected backgrounds, but pure white ground cannot gain contrast from
white additive light. The page shows that limitation directly. The
browser study is untinted and does not claim engine rendering, column
occlusion, tint, fall timing or GUI acceptance.

## Generation and verification

From the repository root:

```sh
python3 tools/r66_art/generate.py
python3 tools/r66_art/generate.py --check
```

The first command writes four candidates, four preview copies, the HTML
page and a contact sheet. The second regenerates in memory and compares
all ten outputs byte for byte without writing. Drawing is authored in
`generate.py`; page presentation is in `preview.html.in`. Dependencies:
Python 3, Pillow and numpy. Verified with Pillow 12.3.0 and numpy 2.4.6;
the Python source also parses with the Python 3.9 grammar.

Completed checks:

- `generate.py --check`: all ten generated outputs match.
- Image inspection: all four candidates are 64 × 64 RGBA PNGs with opaque
  cores, transparent borders, bright RGB on every visible pixel and
  byte-identical preview copies.
- Local HTML audit: all 132 image instances have alt text and valid integer
  dimensions; every image, download and fragment link resolves; no remote
  resources, scripts or unexpanded template tokens.
- Visual inspection of the contact sheet at large and native 16/32/64 px,
  including additive composites on all five grounds. The book B leaf was
  refined to make the closing pose read more clearly as paper.
- `git diff --check`: clean.

No game server, Lua fixtures or runtime tools were run, as requested for
this art-only lane. No files under `mods/` changed. Browser layout and
in-game acceptance remain for the user; the page markup and links were
checked without a browser run.

## Handoff

**Upgrade classification: compatible.** This package adds development
art and a preview only; no runtime behavior, world generation, saved state,
version declaration or migration changes.

The base-code claims are confirmed in
`mods/CORE/grug_core/particle_effects.lua`: `lit()` sets additive blending
and glow 14 (lines 24–29); Smite is five motes plus eight ring particles
(lines 478–487); Censure is one size-16 mote from a default 6 m in the
0.75 s warning window (lines 494–504); Final Word is a column and a ring
(lines 509–515). Particle textures and animation integration belong to FX.
The uninitialized engine reference submodule was not modified; this lane
uses the existing catalogue's preview scale, not a new engine claim.
The open depth and expansion TODOs do not block this work.

The FX lane copies only the two picked candidates into the owning mod,
uses the same hammer for Smite and Final Word, applies the chosen tint,
additive blend and glow 14, and keeps the existing rings and column.
Media provenance is in [LICENSE-media.md](LICENSE-media.md); the FX lane
adds the picked runtime filenames to the owning mod's media ledger.

Independent review remains with the coordinator under the round workflow;
this implementer did not launch agents. The user's picks are pending.
No merge, push or Luanti sync was performed.

GUI checklist after FX integration, on desktop and web:

1. Read Smite's head-down hammer during repeated hits at ordinary combat
   distance, including the gold ring at impact.
2. Read the larger same hammer inside Final Word's white column.
3. Read Censure's book after the warning ring, on dark terrain and bright
   snow/sky/sand; check fall and impact timing and the applied tint.

## Commit receipt

Final art, generator and preview commit:
`358aff5339e6cbfa17ffd93307fe7e663e186554`.
A separate report-only commit follows. Resolve that final commit with:

```sh
git log -1 --format=%H -- tools/r66_art/REPORT.md
git status --porcelain
```

The final status output is empty. The runner's `last.md` records the full
final branch commit hash after this report is committed; a tracked report
cannot embed its own resulting commit hash. Both commit messages end with
`Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.

## Blockers / questions

None for the art delivery. The user chooses Hammer A/B and Book A/B before
FX integration; recommendation A/A is a proposal, not an accepted pick.
