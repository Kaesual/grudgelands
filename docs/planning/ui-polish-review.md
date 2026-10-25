# UI polish review — 2026-10-25

Status: browser proposals for user review, not approved implementation.
Classification: documentation/artifact only; no persistence or runtime change.

The user requested a critique of every current UI page, one improved graphical
layout per page and an explanation of the benefit and limitations, before
another implementation decision. The review uses the completed dialog UI at
`a849d18f88f169ac6e28e2b055117cccacc62705`, before its merge-review fixes.
Those fixes are a separate change and do not authorize implementation of these
new proposals.

## Deliverable

Local browser entry:
`/home/jan/projects/grudgelands-orchestration/ui-polish-review-2026-10-25/index.html`.

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
clear item/price/action alignment. Help's local topics become a side list.
Simple containers receive small alignment changes rather than new mechanics.
These remain proposals until the user selects them.

## Evidence and limitations

The census is [ui-modernization-surfaces.md](ui-modernization-surfaces.md).
The immutable capture source is the `dialogs-2026-10-25/final/` archive under
`~/projects/grudgelands-orchestration/ui-modernization/`.
The page labels its snapshot and does not claim to track main. Native map art
still contains the old labels; the user's latest single-line-label decision is
stated alongside the proposal.

All 69 HTML layouts were rendered and visually inspected. Broken-image and
canvas/control clipping checks passed. A separate read-only source review
checked conditional controls and mechanics; its findings were corrected.
Browser interactions and responsive layouts were checked separately. This is
not approval of native font metrics or web-client behavior: a later approved
implementation still needs actual Luanti captures and the normal runtime gates.
