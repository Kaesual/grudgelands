# Round 15 UI playtest follow-up

Status: delivered on main, synchronized locally and pushed. Independent reviews
and final technical gates PASS; GUI acceptance remains with the user.
Base: main `8226cdff`. Branch: `wp15-ui-followups`.

## Scope and owners

- Root Astra: remove money HUD allocation/update/row, display current balance
  on Character, event-refresh its cached form on actual balance changes;
  leave trade money displays and transaction semantics intact. Fix Talent
  header/tree overlap by using explicit real coordinates for page content,
  retaining the shared legacy inventory geometry.
- Native Sol `r15_quests_impl`: Group's scrollable online same-faction roster,
  stable selected invite target, explicit refresh and separated management
  layout. Isolated branch `wp15-group-roster`, worktree
  `/tmp/grug-r15-group-roster`. Existing party authority remains unchanged.
- Independent Astra review of root money/Character/Talents and separate Astra
  review of Sol Group. Never certify an agent's own implementation.
- User could not currently reproduce Cooking either. No claimed fix; keep
  the existing diagnostics and focused two-player instructions available.

## Layout cause

Luanti formspecs have explicit positions, not CSS flow or an auto-growing
box model. In legacy mode, buttons use a fixed engine height rather than the
provided height, fields adjust padding and labels add an offset. See
`reference_projects/luanti/src/gui/guiFormSpecMenu.cpp` parseButton at976,
parseTextArea at1625 and parseLabel at1905; spacing at3340.
Real-coordinate page content makes the declared rectangles consistent without
changing inventory slot coordinates or the global wrapper.

## Validation budget

Changed Lua: plain-5.1 parser, SETGLOBAL and five sweeps (tools included).
Development: bounded LuaJIT real-consumer fixtures. Final frozen bytes: one
compact PUC/LuaJIT pair, identical canonical output. No mapgen/native world
probe, broad historical suites or GUI automation needed for this UI follow-up.
After independent review: commit, merge main, sync, verify installed bytes,
authorized push, update current-state docs and provide user GUI checks.

## Runtime checks after delivery

- No money text above the health bar; Character displays the same balance as
  `/money`, including after quest/vendor/repair transactions and reopening.
- Priest Talents: Crit/Dodge clear Mercy/Reckoning, rank buttons and description
  remain separate, tree selection and rank/respec actions still work.
- With same-faction and opposing-faction players online: Group roster shows
  only own-faction peers. Select/invite; test opt-out, offline targets, existing
  party restrictions and the Refresh button. Existing accept/decline, kick,
  transfer and HUD/invitation toggles remain usable.

## Completion and calibration

- Root Astra money/Character/Talents / independent native Astra review: clean,
  zero Critical/High/Medium/Low findings, no production correction round.
  Review: round15-ui-followup-review.md.
- Sol Group implementation / independent separate native Astra review: one
  Medium (vanished selection redirected to first remaining player) and one
  Low (Luanti index-zero retained a stale client highlight), both closed in
  two focused corrections. Review: round15-group-followup-review.md.
- Group commits c920e542,07ea1980,8114597c integrated as
  51abd33c,91a68889,af009588. Lost selection is nil server-side and explicit
  index -1 in the native textlist; selecting a different player remains a user
  action. Inserting a newly sorted name preserves the selected identity.
- No Claude or same-provider CLI agents; elapsed review time not recorded.

## Final technical evidence

`tools/r15_ui_followup/evidence/` records all eight changed/new Lua files
passing the 5.1 parser. The sole production global write is the owning
`grug_money` table. All five sweeps pass after inspecting literal string pipes
in the fixture and an existing comment ampersand. One bounded PUC process
and the same LuaJIT fixture both pass, canonical SHA-256:
`a9374c919240ac74034b46dd2fcc8d456000384815911d1492080cbbd2bb371f`.
Each process took approximately 0.0023 seconds; no intermediate PUC or native
world test ran.

The real-consumer fixtures cover money notifications/cache refresh, atomic
payment notification, talent coordinate mode/bounds, and roster filtering,
escaping, status display, changed sort order, stale target and cleared selection.
Existing party authority is source-reviewed; its implementation is unchanged.
These are technical checks, not a claimed in-client visual acceptance test.

## Delivery receipt

Candidate `f91afa99` merged without squash as `b9d96a8c`. The sync script
installed main; all 2,047 installed names/contents matched and all eight final
Lua hashes remained unchanged. Authorized `git push origin main` advanced
Kaesual/grudgelands from `8226cdff` to `b9d96a8c`. This documentation-only
receipt changes no tested game bytes. Restart the game/server for the GUI
checks above; these UI changes do not require a fresh world.
