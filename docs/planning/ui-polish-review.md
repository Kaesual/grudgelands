# UI polish review — 2026-10-25

Status: revision 03 (2026-10-26) after user feedback; browser proposals, not approved implementation.
Classification: documentation/artifact only; no persistence or runtime change.

The user requested a critique of every current UI page, one improved graphical
layout per page and an explanation of the benefit and limitations, before
another implementation decision. The review uses the completed dialog UI at
`a849d18f88f169ac6e28e2b055117cccacc62705`, before its merge-review fixes.
Those fixes are a separate change and do not authorize implementation of these
new proposals.

## Deliverable

Local browser entry:
`/home/jan/projects/grudgelands-orchestration/ui-polish-review-2026-10-26-v3/index.html`.

Reproducible source: [tools/ui_polish_review](../../tools/ui_polish_review/README.md).
The bundle contains 69 layouts, 207 actual client screenshots (three resolutions),
their saved formspec evidence, criticism and reasons, retained mechanics,
relative effort and implementation constraints. Related states share a family
layout. Conditional states without an actual capture are explicitly labelled
arrangement sketches. Search, previous/next, full-size comparison modes and
local notes help the user review it incrementally.

## Proposed direction

- Keep common inventory tabs at one window size and Map & Quests larger.
- Use consistent type, spacing and action placement, with restrained emphasis.
- Place actions beside the information they affect, with a clear list/detail
  relationship for crafting, quests, trade and mail.
- Use compact, consistent service-window sizes; keep native slot transfers,
  catalogue behavior, talent trees and current scroll mechanisms.
- Separate hazardous actions visually, preserving exactly the existing
  confirmation and validation behavior.
- Keep animation-based progress and current refresh cadence. No new per-tick
  updates, automatic previews or client-side game logic.

A one-column vendor list is an explicit tradeoff: more vertical scrolling for
clear item/price/action alignment. Sell and Trade-in use compact one-line rows.
Their new quantity buttons are explicitly proposed behavior, not an existing
feature; whole-lot rules stay. Help's local topics remain a side list. Containers
use more height for the player inventory. These remain proposals until selected.

## Evidence and limitations

The census is [ui-modernization-surfaces.md](ui-modernization-surfaces.md).
The immutable capture source is the `dialogs-2026-10-25/final/` archive under
`~/projects/grudgelands-orchestration/ui-modernization/`.
The page labels its snapshot and does not claim to track main. Revision 02's
zone proposal uses corrected single-line labels from the merge-fix formspec as
HTML over archived native base art (a disclosed older example world). This
illustrates independent text size and viewport use, not an exact current map.

All 69 HTML layouts and 25 additional selectable states were rendered and visually inspected. Broken-image and
canvas/control clipping checks passed. A separate read-only source review
checked conditional controls and mechanics; its findings were corrected.
Browser interactions and responsive layouts were checked separately. This is
not approval of native font metrics or web-client behavior: a later approved
implementation still needs actual Luanti captures and the normal runtime gates.

## Revision 02 — functional affordances and consistency

The user found revision 01 too willing to remove icons, counts, slot hints and
context. Those are functional affordances, not disposable decoration. The
revision keeps the approved direction for Help, creation, dark input fields,
wide windows and icon-free tabs, while restoring these signals:

- Shared Hotbar positioning and compact A/B controls; minimum two inventory
  rows on subpages, greater visible height in containers, selectable 24/88-slot
  examples; main inventory with money at its right.
- Equipment, coin-bag, bookshelf, vessel and quiver ghosts; framed mount icons
  including the active state; exact captured recipe icons and craftable counts.
- Compact trade rows, native block artwork, repair-all total on the action.
- One map toolbar (eight-layer dropdown, zoom, minimap), equal columns, separate
  quest list/detail areas, and full scrolling viewport above 1×.
- Selectable Party roles, mail/report/ticket states, running/blocked furnaces,
  travel, Book Read, Claim fuel/wait and preparation states, clearly illustrative.
- Admin Mail in the primary row; Creative has one main entry and five categories
  in the second row. Extra permissions can be shown across all shared tabs.

Checks: all 69 main canvases and 25 added states rendered without missing images
or elements outside the canvas; scroll content excluded from clipping checks.
Eleven semantic browser assertions cover capacity/reachability, inventory rows,
permissions/categories, recipe affordances, Party roles, map scroll and price.
An independent read-only source review checked conditional behavior and its
reported sample contradictions were fixed. Native font scaling and the complete
runtime state space remain implementation gates, not claimed browser coverage.
The original revision 01 bundle is preserved, including its local-notes origin.

## Revision 03 — proportions and navigation (2026-10-26)

Browser study only, compatible; no runtime, saved-state, world or server change.
Source comparisons against main `8eeddb0d` verified the relevant repair, quest,
skill, recovery and mount interfaces. Unlike the frozen captures, current main
has 8/12/16/20-slot bags: the board now defaults to 13 inventory rows (104 slots),
with historical 11-row and base 3-row examples still selectable.

- Inventory left; Bags, Potion Belt and Money stacked on the right, matching
  bottom edges. The Hotbar is independently centered below both columns.
- Smaller character preview, top-aligned effect/other empty states, active
  effect icons and achievement cloak images restored.
- Talent-tree menu on the left, original artwork filling its area, skills
  directly below without another panel. Only actual unlocked entries draw slots
  (two in the captured Warrior); existing horizontal scrolling and Respec stay.
- Unzoomed map vertically centered when shorter than its viewport; zoomed map
  keeps the entire scrollable viewport.
- Quest lists retain neutral titles and reuse existing status markers. Story
  remains an independent category and existing special marker, not a fifth
  status. The Story/other-state examples below the captured quest proposal are
  explicitly independent of Elian's actual offer list.
- Camp-vendor Repair shares Buy/Sell/Trade-in navigation and window dimensions.
  The current call ends the trader session, so this is a proposed routing change,
  preserving faction/range/provider checks and authoritative single-use quotes.
  Standalone repairs remain separate and keep Close. Ordinary traders gain no
  new capability. Trainer footers consistently put Close left, Learn/Unlearn
  right, keeping Unlearn's warning and confirmation.
- Riding/boat offers show existing faction/race-appropriate images. Belongings
  proposes drawing only populated recovery entries instead of rounded-up blank
  slots; its tab still disappears after the last take, returning to Claim Stone.
- Chests show four player-inventory rows, smaller shelves six, furnaces five;
  more rows scroll. Furnaces return to Input, Fuel/fire, process arrow, Output;
  the longer arrow retains existing animation semantics, no new update cadence.
  Creative uses the same slot dimensions as inventory and four inventory rows.

The [BACKLOG](../../BACKLOG.md#ui-review-follow-ups-2026-10-26) holds the separate
Shipwright venue idea and the 10,000-container recovery stress investigation.
Neither a building choice nor a limit/paging mechanism is decided here.

Validation: 69 primary canvases plus 29 additional states rendered; affected
families visually inspected. Thirty browser assertions cover geometry, slot
counts, scrolling, icons, navigation, original capture resolutions and page
widths. Two corrected states were re-rendered after the independent review:
Swiftness uses its valid existing short-time caption, and an empty recovery
store returns to the management tab. Existing client screenshots remain frozen;
there is no new Luanti runtime acceptance claim. Revisions 01 and 02 remain
archived separately.
