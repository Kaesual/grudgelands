# UI polish review — browser study

This is a review artifact, not implemented or approved game design. It compares
69 captured UI states with exactly one proposed layout per state. Actual Luanti
screenshots are available at 1035×696, 1600×900 and 2560×1440. The snapshot is
`a849d18f88f169ac6e28e2b055117cccacc62705` on `ui-tab-hover`, before the subsequent
merge-review fixes; it is not a live view of main.

## Open and rebuild

Open `dist/index.html` directly in a browser. There is no server, account,
external request, font download or publication. Notes stay in the browser's
local storage and can be exported as JSON; file-URL storage support varies by
browser, so export notes before moving the bundle.

From the game root, with Python 3, Pillow and NumPy installed:

```sh
python3 tools/ui_polish_review/build.py
```

The default immutable capture archive is
`~/projects/grudgelands-orchestration/ui-modernization/dialogs-2026-10-25/final/`.
Use `--captures PATH` to supply a copy with the same three resolution folders,
`dark_NAME.png` images and `ui_capture_dark_NAME.txt` formspec evidence.
The generated `dist/` directory is ignored by git. Copy the entire directory to
move the review; `index.html` alone is insufficient.

- `content.py`: German criticism, rationale, mechanics and implementation limits.
- `src/`: standalone HTML/CSS/JavaScript and one renderer per UI family.
- `build.py`: lossless WebP packaging, focus crops and formspec evidence.
- `assets.py`: native artwork crops, game textures and captured merchant prices.

## Boundaries

The proposals reorganize existing actions and information. They do not implement
new mechanics, saved state, form ids, capacity changes, item previews, a cart,
new confirmations, timers or progress updates. Additional conditional states
are labelled arrangement sketches below the principal layout, not claimed
client captures or alternative design directions. The current-state census is
[UI surfaces](../../docs/planning/ui-modernization-surfaces.md).

HTML communicates hierarchy and proportions. CSS scaling is not a simulation
of Luanti GUI scaling, font metrics or HiDPI. Real-client validation remains
necessary after an approved implementation. Native maps, talent trees, models
and catalogue grids use regions from the actual screenshots. Text excerpts and
sample states are marked; a later implementation must retain complete text,
all offers, native slot behavior and existing routing. The map artwork predates
the user's return to single-line zone labels; the review explains this.

Screenshots and icons come from this game and its vendored assets. Original
licences and provenance remain in the repository's `LICENSE-media.md`,
`CREDITS.md` and `VENDOR.md`; no new external art was imported.

## Review

All 69 proposal canvases were rendered in isolated Firefox and visually inspected
in contact sheets. Browser checks cover missing images, controls extending
outside a canvas or a clipped panel, navigation, screenshot resolution switches,
focus/full-image modes, search, notes and narrow browser layouts. These are
browser-study checks, not a new desktop/web game acceptance claim.

A separate read-only review compared the proposed controls with the runtime
paths. It caught conditional mail actions, the upgrade target-only slot,
ready-only reward selection and direct admin send/delete behavior; those were
corrected before delivery. No runtime files are part of this artifact.
