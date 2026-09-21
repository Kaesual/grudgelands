# Round 15 UI followup — independent Character and Talents review

Decision: **PASS for the reviewed production changes**, with no verified Critical,
High, Medium or Low findings. Final integrated static/parity evidence has been inspected and accepted below;
this review does not certify an unperformed GUI run.

Reviewed by independent native Astra on 2026-09-21, against `8226cdff` on
`wp15-ui-followups`. The reviewer did not author these changes. Scope: money
`init.lua`/`mod.conf`, inventory `pages.lua`/`mod.conf`, classes `talents_ui.lua`,
core `hud_layout.lua`, and `tools/r15_ui_followup/character.lua`. Group UI is
outside this review. Applied the workflow checklist, model policy, Lua interpreter
rules and current economy/Character design. No production edits were made.

## Verified behavior

- Money no longer allocates or changes a HUD element on join, ordinary ledger
  mutations, or atomic inventory purchases. The shared money row is removed.
  Both mutation paths notify after the committed balance, and the atomic path
  also commits its inventory first. Unchanged balances and refused withdrawals
  do not refresh the form.
- The Character page formats the current ledger balance. Its event callback
  updates only an existing Character context, using the existing sfinv setter;
  it does not create a context, navigate to Character, or reopen an inventory.
  `mods/BASE/sfinv/api.lua:125` rebuilds and caches the selected page. The engine
  receives that cache in `src/network/clientpackethandler.cpp:926`; its inventory
  form source reads it (`src/client/game_formspec.cpp:171`) and an already-open
  form regenerates on change (`src/gui/guiFormSpecMenu.cpp:3632`). All engine
  paths here are under `reference_projects/luanti/`.
- Inventory's explicit money dependency is acyclic: money depends only on core.
  Refreshes are event-driven and preserve the selected page. The Character detail
  textarea retains its former bottom edge after moving down for the balance.
- Talent content switches to real coordinates only after navigation and legacy
  inventory elements. Engine parsing is sequential (`guiFormSpecMenu.cpp:3422`),
  with the initial size established earlier (`3296–3355`). Legacy spacing is
  1.25 horizontally and 15/13 vertically, with 0.375 padding in slot units.
  The existing form is approximately 13.50 real units wide; talent content ends
  at x=12.60. Inventory begins at approximately y=8.683, while the description
  ends at y=8.10. Integer pixel rounding does not consume this gap at ordinary
  form scales.
- Real button rectangles use their authored width and height (`:998`), unlike
  the previous legacy button half-height rule. Four talent tiers occupy separate
  bands ending at y=6.40; description starts at 6.65. Tree/reset controls end
  at 2.70 and chain labels are centered at 3.00. Labels use vertical centers
  (`:1972`), and real textareas use explicit rectangular geometry (`:1650`).
  The two-chain registry constraint matches this layout. Named talent actions,
  tooltip regions and respec confirmation remain bound to their existing logic.
  Description text remains a wrapped, scrollable textarea (`:1519–1558`);
  this review verifies its container fits, not that every long description is
  simultaneously visible at every user-selected font size.

## Evidence and limits

One bounded LuaJIT execution of the real-consumer Character fixture passed:

```text
ui_character money=no-HUD event-refresh=pass atomic-payment=pass talents=real-content inventory=legacy
```

The fixture loads the actual money, Character, wrapper and talent code. It checks
HUD-call refusal, fresh cached values, unchanged/refused payments, other-page
isolation, atomic payment notification, legacy/real ordering, talent button
separation and confirmation controls. Its sfinv setter is a small test double;
the actual setter and live engine cache semantics were therefore inspected
separately above. Geometry review also covers the description and locked talent
rectangles beyond the fixture's button assertions. No PUC runtime or broad/native
test was repeated by this reviewer.

Reviewed SHA-256 values:

```text
f477e8503da7e95bacc2cad894959c27c6f3d5543e97b69da389cfca4fc204aa  mods/CORE/grug_core/hud_layout.lua
3961760ca219780ef26812a2b8d209bf62483685197bdf77417f3223ae9e355d  mods/PLAYER/grug_classes/talents_ui.lua
540d70a7a9a70b5bbdcbc627d2f6d4becd5e1e8849fd615dc26bd2a7875eb772  mods/PLAYER/grug_inventory/pages.lua
4dd8257908233e3b8c36d282fb0d38e265fa47d7b65d0baafdaf865f713e17b9  mods/PLAYER/grug_inventory/mod.conf
5b0d1939054a657fc8339d14f7f21f262f9ccd4f76139ede0ddcd5234772cb2a  mods/PLAYER/grug_money/init.lua
4a6227f6288ca648d2b2fb876d73d83d214c22171d2ed2cb946a6b8bcd1e7d1b  mods/PLAYER/grug_money/mod.conf
89355c81803ee559ef03251777ca2a190a2e94a28d5597752374f9a1e0c5f943  tools/r15_ui_followup/character.lua
```

User GUI check: change money with Character open and closed, switch to another
page before a transaction, and inspect both talent trees, locked/available tiers,
long descriptions and respec confirmation at the normal display configuration.

## Final evidence acceptance

Inspected the coordinator's frozen `tools/r15_ui_followup/evidence/` without
rerunning either interpreter. All eight recorded source hashes match current
files. Both output artifacts independently hash to
`a9374c919240ac74034b46dd2fcc8d456000384815911d1492080cbbd2bb371f`,
contain both passing fixtures, and have empty stderr artifacts. Static evidence
reports eight successful Lua 5.1 parses, only the declared owning `grug_money`
global assignment, and five clean sweeps after inspecting literal pipe strings
and the comment-only match. Group behavior remains the separate independent
reviewer's scope.

The only subsequent change to this review's production scope is the opening
HUD-layout comment, which now accurately names abilities/XP consumers and the
Character money display. Inspected that comment-only correction and updated its
SHA-256 above; the other reviewed production and Character fixture hashes are
unchanged. Final decision remains **PASS**. No additional execution or
production edits were needed.
