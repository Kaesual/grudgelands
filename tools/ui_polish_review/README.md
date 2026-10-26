# UI polish review — browser study, revision 03

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
The asset builder additionally reads these local archived inputs (paths in
`revision_assets.py`):

- `ui-modernization/dialog-review-fixes-2026-10-25/1035x696/` under the same
  orchestration root: the single-line zone-label formspec and its screenshot.
- `r53/worlds/r53_ms_0.52.1/grug_map_base_<x>_<y>.png`: the nine native base
  tiles used only as illustrative background for the zone-label proposal.
  This older example world is disclosed; it is not a current-world capture.

The generated `dist/` directory is ignored by git. Copy the entire directory to
move the review; `index.html` alone is insufficient.

- `content.py`: German criticism, rationale, mechanics and implementation limits.
- `src/`: standalone HTML/CSS/JavaScript and one renderer per UI family.
- `build.py`: lossless WebP packaging, focus crops and formspec evidence.
- `assets.py`: native artwork crops, game textures and captured merchant prices.
- `revision_assets.py`: slot ghosts, class/mail/guild art, native item-image
  crops, exact recipe rows/counts and the independent zone-label overlay.
- `src/revision.js`: revised families and explicitly selectable example states.

## Boundaries

The proposals reorganize existing actions and information. They do not implement
saved state, form ids, capacity changes, item previews, a cart,
new confirmations, timers or progress updates. The requested 1/5/10/All
Sell/Trade-in controls are explicitly marked as a proposed behavior extension:
Sell currently offers 1/All for single goods, Trade-in only All. Any later
implementation needs validated quantity actions and must preserve whole-lot
and remainder rules. Additional conditional states
are labelled arrangement sketches below the principal layout, not claimed
client captures or alternative design directions. The current-state census is
[UI surfaces](../../docs/planning/ui-modernization-surfaces.md).

HTML communicates hierarchy and proportions. CSS scaling is not a simulation
of Luanti GUI scaling, font metrics or HiDPI. Real-client validation remains
necessary after an approved implementation. Native maps, talent trees, models
and catalogue grids use regions from the actual screenshots. Text excerpts and
sample states are marked; a later implementation must retain complete text,
all offers, native slot behavior and existing routing. The zone proposal uses
separate HTML labels from the corrected formspec over archived native map art,
so zoom does not enlarge baked text. It illustrates layout, not new engine
font metrics or an exact current world.

Screenshots and icons come from this game and its vendored assets. Original
licences and provenance remain in the repository's `LICENSE-media.md`,
`CREDITS.md` and `VENDOR.md`; no new external art was imported.

## Review

Revision 03 renders all 69 proposal canvases and 29 additional selectable states
in isolated Firefox; affected families were visually inspected in contact
sheets. Revision 02 had additionally inspected all main canvases. The revised study
also checks 104-slot scrolling, base capacity, the two-row minimum, all nine
main tabs, five Creative categories, recipe icons/counts, Party roles, map
scrolling and the repair-all price. Browser checks cover missing images, controls extending
outside a canvas or a clipped panel, navigation, screenshot resolution switches,
focus/full-image modes, search, notes and narrow browser layouts. These are
browser-study checks, not a new desktop/web game acceptance claim.

A separate read-only review compared the proposed controls with the runtime
paths. It caught conditional mail actions, the upgrade target-only slot,
ready-only reward selection and direct admin send/delete behavior; those were
corrected before delivery. No runtime files are part of this artifact.

## Revision 02 scope

The user's feedback retained the clearer Help/creation/navigation direction but
rejected lost affordances and inconsistent proportions. This revision restores
special-slot ghosts, native block/item art, craft counts, mail provenance and
conditional actions, repair pricing and separate furnace/fuel indicators.
Inventory and Hotbar share components; subpages show at least two rows, while
containers use spare height. Large-bag examples expose all eleven rows by
scrolling without changing capacity. Main inventory puts money beside a taller
grid. Map has equal columns, one compact layer selector and distinct quest list
and detail panels. Extra permissions, bag capacity and relevant example states
are selectable above the comparison.

The independent read-only delta review corrected Party role/selection samples,
mail list/detail pairing, ticket footer, active mount frame, furnace ingredients,
Innkeeper home, guild art/rank text and upgrade/quiver examples. Its final source
pass found no remaining blocker in that scope; this is not an exhaustive proof
of every runtime state. No runtime files changed and no new Luanti run occurred.

Revision 01 stays archived separately. The current standalone bundle is
`~/projects/grudgelands-orchestration/ui-polish-review-2026-10-26-v3/`; earlier
bundles remain unchanged.

## Revision 03 scope

Inventory has equal-height columns (grid left; Bags, Potion Belt, Money right)
and a separately centered Hotbar. Character art is smaller; cloaks and active
effect art are visible. Talent selection is a left menu, the full original tree
fills its area, and only unlocked skill slots appear below it. Empty messages
start at the top. Map centers at 1× and fills the scrolling area above it.

Camp-vendor Repair is proposed as a fourth service tab, while standalone repair
keeps its own closing action. This needs a deliberate validated routing change:
the current Repair call ends the vendor session. Quest status and Story use
existing marker assets with neutral titles and textual/category cues. Story is
independent of status. Trainer actions have fixed positions and mount/boat
images use the character's existing faction/race art.

Recovery displays actual occupied entries without rounding its visible final
row to eight; at zero its tab disappears as today. Containers show four to six
inventory rows, furnaces five with the existing slot order. Creative slots use
the same common dimensions, with four inventory rows. Current-main 20-slot bags
raise the maximum example to 13 rows; the 11-row historic option stays labelled.
The two world/scale follow-ups are backlog entries, not implementations.

Validation evidence is in the published bundle's `qa/`. The independent source
review's invalid Swiftness duration example and empty-recovery-tab discrepancy
were corrected and re-rendered. These checks do not simulate native GUI scaling,
web-client behavior or an arbitrary recovery-store size.
