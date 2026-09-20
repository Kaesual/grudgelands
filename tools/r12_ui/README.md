# Round 12 shared inventory UI

The game-owned sfinv theme in `grug_inventory/ui.lua` provides a 10.4×11.1
legacy-coordinate form and one common inventory boundary. Character has
separate preview, live-stat/derivation and equipment columns; Talents retains
its existing two-click purchase and confirmed respec paths in wider controls,
with a taller description area and word-wrapped tooltips. Help begins with a
playable first-session route. Creative Food derives from `grug_food` groups
and uses Creative's existing search/paging and bound-inventory guard paths.

Focused checks load the real builders/model and parse generated geometry:

- `tools/ui/page_layout_kat.lua`: original classes at levels 1/60; all text and
  inventory geometry in bounds and nonoverlapping; preserves status derivation.
- `tools/wp11/talent_ui_kat.lua`: selection, purchase, gates, respec, notices and
  effective tooltip values. Mocks updated for current Scout/rating APIs rather
  than claiming the pre-Round11 harness already worked.

Both pass under LuaJIT; parser, SETGLOBAL and all five source sweeps passed.
Sweep matches are comments and string data, no live forbidden syntax/API.
No PUC runtime under the session override. GUI rendering/localization is a
separate user playtest, not proven by the conservative geometry model.
