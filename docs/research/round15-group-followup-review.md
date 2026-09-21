# Round 15 Group roster — independent review

Date: 2026-09-21. Implementer: native Sol. Reviewer: independent native Astra;
no authorship of this Group UI or fixture. Initial frozen commit:
`c920e54258e9c9879ccf0ed5889501c617c1242a`, reviewed in
`/tmp/grug-r15-group-roster`. Scope: Group UI, bounded fixture and author report;
unchanged party core and engine/wrapper contracts were read as dependencies.
No runtime tests were executed by this reviewer.

## Initial finding (closed)

**Medium — disappearing selected recipient silently changes the invite target.**
`mods/PLAYER/grug_parties/ui.lua:43` falls back to `rows[1]` when the selected
name is absent. The coordinator identified this during integration inspection;
the reviewer confirmed it against the frozen implementation. A selected peer
can disconnect, then a Refresh or event-driven Group refresh replaces that
selection with a different player; the next Invite sends to that unintended
replacement. Preserve no selection when a previously selected name disappears
and render selected index zero; require explicit selection before inviting.
The initial fixture currently expects the fallback, so its regression assertion
must change. Preserve selected names through reorder when they remain online.

## Reviewed contracts

- The connected-player snapshot excludes the viewer and other factions, sorts
  names, escapes labels and exposes current invitation/party status as hints.
  No new background polling is installed. Page entry, explicit Refresh and
  existing action/change refreshes rebuild the snapshot.
- `sfinv.set_page` invokes `on_enter` even for the current page
  (`mods/BASE/sfinv/api.lua:130–142`); the fixture models this important contract.
  Receive-fields routes through the active page and viewer context
  (`:159–186`). Roster row clicks resolve the stored rendered name snapshot;
  invitation execution calls the unchanged authoritative core.
- `grug_parties/init.lua:161–218` revalidates online status, self/recipient
  membership, opt-out, same faction, current sender leadership, ten-member
  capacity and the one-second sender throttle. Acceptance revalidates these
  eligibility rules. Transfer/kick still use the leader-target gate at
  `:239–259`; leave, pending accept/decline and both preference controls retain
  their existing API dispatch. No party persistence or combat-credit changes.
- The shared inventory wrapper emits legacy navigation/inventory before the
  Group content; the latter switches to real coordinates. Engine positions
  use image units for real coordinates and spacing/padding for legacy ones
  (`src/gui/guiFormSpecMenu.cpp:257–276,3340`). The Group controls end at real
  y=6.73; inventory starts below legacy y=7.2, leaving clearance. Roster and
  pending lists occupy separate columns; members/actions and notices occupy
  the lower area. Textlist is a native scrollable table
  (`:1261–1335`, `doc/lua_api.md:3506–3524`). Native font/scale acceptance
  remains a user GUI check, not a claim from source rectangles.
- The roster rebuild is bounded by connected players with a maximum-ten-member
  party view per candidate. It performs no world search, recurring timer,
  globalstep, inventory mutation or new persistence. Lua uses plain 5.1 syntax
  and introduces no mod globals.

## Evidence boundary

Initial hashes match the author's freeze: UI
`4774aff38d3179dba931ffa2db092379ba6e889e938f3ec88b0e7557777a24dc`, fixture
`2a1a2d2cc5089d1f6ee3704fc0fbccd1f3e729aa24860794825acfb98fe65f0d`.
The fixture exercises ungrouped roster sorting/filtering/escaping/status hints,
layout bounds and a mocked stale-offline refusal. It does not load the actual
party core or simulate grouped management, pending actions, opt-out or cooldown
settlement; these were source-reviewed rather than claimed as fixture coverage.
Final interpreter parity/static evidence is coordinator-owned.

**Final status: clean after the focused corrections recorded below.**

## First focused correction

Commit `07ea19802ebf65bda157d82208dfd0f00d4f608f` fixes the unintended-target
fallback: only the initial snapshot defaults to the first name; losing an
existing selection leaves nil and Invite refuses without a core call. The
updated fixture checks this path. Its hashes were verified against the author.

**Low — index zero preserves a misleading client highlight.** The corrected
server uses no selection, but emits textlist selected index zero. On same-form
refresh, `guiFormSpecMenu.cpp:3135–3142` preserves table dynamic data, and
`:1322–1327` restores the old selection while skipping `setSelected` for the
literal zero. Thus a different row can remain highlighted despite the nil
server selection. Emit an explicit negative no-selection index: the engine
parses it, and `guiTable.cpp:539–553` clears selection before returning for a
negative index. This does not bypass the newly corrected server invite guard;
it makes the visible state agree. A focused follow-up is pending.

## Final focused disposition

Final freeze `8114597c927ed257c5d88b59de81f4f0bb6e8b01` was inspected directly.
UI SHA256 `9c25fdd1876d7febb6cb995f0674eab2568755f6c65d534df567eeecef69c85e`
and fixture SHA256
`e2b3d2a54e6b99cb8148a3d1ebbc294697d884a542516a97b2115a32493b319f`
match the author handoff. Explicit -1 now clears the preserved client highlight
when the server selection is nil. The fixture inserts an earlier-sorting new
player, moving the retained selected target from row four to five, then checks
disappearance, emitted no-selection index and refusal without calling invite.
Both the Medium target-substitution finding and Low highlight finding are closed.

**PASS for this bounded source/UI package: no remaining confirmed Critical,
High, Medium or Low finding.** Calibration: native Sol author, independent
native Astra reviewer; one Medium and one Low corrected in two focused passes;
review duration not measured. The author reports LuaJIT, parser, SETGLOBAL and
sweep success through tool output, without archived log files. The reviewer
verified source/hashes and fixture assertions, not an independently executed
runtime result. The coordinator must record final frozen static/parity gates.

User runtime check: open Group with several online same-faction players,
scroll/select/invite; add a player before the selected name in sort order and
Refresh; disconnect the selected target and Refresh, checking that no substitute
is highlighted or invited. Also exercise accept/decline, leader transfer/kick,
leave and the two preferences, with controls clear of the inventory.
