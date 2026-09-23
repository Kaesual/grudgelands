# Round 19 UI follow-up — shared Map window and talent affordance

2026-09-23. User explicitly authorized both fixes. Root native Astra; independent
native Sol review. A native Sol author owns talent presentation, root owns Map.
Branch: `fix/r19-map-window-consistency`; baseline `6a4636a7`.

## Contract

- Map must use the same outer dimensions AND legacy engine scaling as ordinary
  inventory tabs. Fit the atlas inside that window; never resize the window to
  suit the map. Preserve 9:8 aspect, zoom/scroll, fixed-size markers and Home.
  Normal display sizes are a design guideline, not a resolution test matrix.
- Align text consistently across buyable, locked and maximum-rank talents.
  Buyable talents need a clear button background/border. Preserve hover reasons,
  rank labels, first-click purchase and all authoritative checks. Tree selection
  styling is outside this correction.

## Map cause and correction

The original Round 19 page supplied a real-coordinate 10.65x11.20 wrapper, while
normal tabs use legacy 10.4x11.1. Both outer extent and engine fit scaling differ.
Use shared `grug_inventory.UI` dimensions and `real_coordinates[false]` directly
after `size`, before navigation; switch only the map content back to real units.
Formspec v4 remains necessary for native scroll containers. Compute available
content from the engine's legacy spacing/padding and fit the map within it.
Controls follow the resulting viewport. No resolution polling or custom scaler.

Engine evidence: `reference_projects/luanti/src/gui/guiFormSpecMenu.cpp`
initial coordinate-mode parsing, legacy size calculation and `calculateImgsize`.
Existing map fixture now loads the real shared inventory theme and compares the
page size, while retaining zoom/scroll/lifecycle checks. No new resolution suite.

## Status and validation

Implementation and independent review in progress. Root will run parser,
SETGLOBAL and five static sweeps on touched Lua, followed by one bounded final
interpreter pair using the existing map/UI fixtures. No headless world run or
GUI automation is needed for these presentation-only changes. Sync locally
after review; runtime acceptance is a quick user tab switch and talent glance.
