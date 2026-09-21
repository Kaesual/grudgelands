# Round 15 atlas independent review

Date: 2026-09-21. Implementer: root native Astra. The provider/rendering
checkpoint was reviewed by an independent native Astra agent that authored the
separate HUD package. The final lifecycle review was performed by independent
native Sol with no atlas authorship. Neither review certifies the HUD package.

**Final verdict after focused correction review: clean. Provider/rendering and
lifecycle checks have no remaining Critical, High, Medium or Low findings.**

## Final lifecycle findings

### Resolved Medium — selected moving marker remained visible as text

Corrected `page.lua:84-117` now resolves selected detail only inside the
successful `world_to_screen` branch, then clears both selected ID and detail
when the selected marker is absent or clipped. The focused fixture selects an
online party member in the Human region, moves it outside that region, and
requires the marker, selected ID, detail and `Selected:` label all to vanish.

### Resolved Low — lifecycle fixture overstated reconnect coverage

The fixture claim now says `disconnect=clean`, matching the exercised leave
callback and no-poll assertion. It no longer claims a reconnect simulation.

## Reviewed boundaries

Read `docs/process/wp-workflow.md`, the independent-review policy, Lua 5.1
rules, approved Round 15 atlas scope, real settlement registry/loader,
quest-state authority, party membership projection, formspec wrapper and
Luanti's actual heading/inventory APIs. No runtime suite was rerun.

- Heading sign is correct: `lua_api.md:9190–9194` defines yaw as counterclockwise
  from +z; north-up projection plus sprite frames 0/4/12 yields north/west/east.
  Inspected the actual gold-00, cyan-04 and gold-12 PNGs. Sixteen finite frames
  per colour avoid unbounded generated textures.
- `r7_loader.lua:57–99` publishes all authored sockets synchronously, before
  mods-loaded callbacks. The giver cache therefore works without emerging the
  corresponding capital or POI. Missing sockets fail loudly instead of making
  invented positions; actual POI integration remains a separate gate.
- Online members are resolved by current player objects, excluding self;
  offline membership has no fabricated position. The viewer's layer sorts last.
- Provider-prefixed full-byte hex field identities are injective and survive
  insertion, removal and changed sort order. A vanished target is ignored,
  rather than interpreting its old index as another marker.
- Quest states reuse `grug_quests.marker_state` and its race/faction/prerequisite
  and turn-in authority. Settlement grouping selects ready/available/active/
  locked precedence while preserving every relevant giver in tooltip text.
  No accept, turn-in, teleport or travel permission is exposed.
- Region filtering and x/z projection retain the existing world bounds;
  the page explicitly uses real coordinates inside the legacy sfinv wrapper.
  The current follow-up also stores selected marker identity and refreshes its
  detail text from current rows, rather than persisting stale quest status.
- Read-only collection is bounded by the current giver/party roster. It makes
  no world-object search or emerge request. `marker_state` loads a quest-state
  snapshot per NPC, so the final lifecycle must avoid collection for closed
  maps; no unmeasured performance defect is asserted here.

## Final lifecycle assessment

The explicit-session design closes the inventory ambiguity. `sfinv.set_page`
calls the old page's `on_leave`, then the new page's `on_enter`, then installs
the generated inventory formspec. An active Map tab therefore creates one
polling entry; tab switches and the approved `fields.quit` path remove it.
Luanti documents `fields.quit=true` for actively closed inventory formspecs and
documents that `set_inventory_formspec` updates an open inventory immediately
while also defining future opens. Setting Character during the close callback
therefore does not reopen the menu and ensures a later inventory open starts on
Character, so returning to Map is an explicit tab-entry event.

The shared globalstep is throttled to one pass per 0.5 seconds and never
replays a backlog. It rebuilds only active Map sessions and writes only when
the complete formspec changed. Same-page refreshes caused by marker/view clicks
run the normal leave/enter sequence, preserving context view and selected ID
while replacing the cached form. Stable field names prevent marker ordering
changes from redirecting a click. Selection is now restricted to the visible
projection and is cleared when its marker leaves the chosen view.

Disconnect removes the local active entry even before considering SFINV's own
context deletion. Death switches an active Map session to Character; the
builtin death screen uses a separate named formspec, so the inventory-form
update neither replaces nor closes it. A later respawn/inventory open therefore
does not resume hidden Map polling.

The final fixture was inspected, not executed again. Final parser/SETGLOBAL/
five-sweep evidence and the coordinator's single final PUC/LuaJIT pair must
refer to final bytes. User GUI acceptance remains required for marker
readability, overlapping players, moving/turning party members and clicks
while refreshing. In particular, a live formspec refresh can preserve stable
field identity in source yet still feel disruptive under the pointer; only the
fresh-world client test can accept that interaction.

Calibration: partial Astra checkpoint found 0 Critical / 0 High / 0 Medium.
Final Sol lifecycle review initially found 0 Critical / 0 High / 1 Medium / 1
Low; focused re-review verified both corrections. Remaining findings: 0
Critical / 0 High / 0 Medium / 0 Low.

## Focused correction hashes

- `mods/PLAYER/grug_map/page.lua`: `9e5bdceb0508f14f837ac3a14770a2c69d7d3e530b53c3bb9575b82cc2152cea`.
- `tools/r15_map/kat.lua`: `6ae4c4b187a9b6d7cc8043b536ab07eb0160cf0f197dcbd1f7735d581cfe0765`.

## Final evidence acceptance

The frozen final evidence retains both reviewed hashes above. Its 17-file Lua
5.1 parser/static gate passes, and all four bounded fixtures produce the same
canonical SHA-256
`8de2aaf7c4080ad0d423f36177318a338c66cae5f72f8992cbc3bc14ab509f46`
under PUC Lua 5.1 and LuaJIT. The atlas fixture specifically reports open-only
polling, Character reset on close, clean death/disconnect handling, stable
identity and clipped views. The 2,045-file native snapshot matches the final
repository payload. This accepts the frozen evidence without replacing the
remaining GUI interaction gate described above.

## Partial checkpoint hashes

- `mods/PLAYER/grug_map/atlas.lua`: `db952dad7128eaf88f1c0a08291eb5abed280528b88eec43ddd38903053af202`.
- `mods/PLAYER/grug_map/providers.lua`: `90cf6399a760df8aa29670e77d122f04303ab7f5770cad41dcc620aa0af92722`.
- `mods/PLAYER/grug_map/page.lua`: `bb96a58da423872a95aa9819c345d4f3212cf10c64eb32df718a2bf1feeb1dea`.
- `mods/PLAYER/grug_map/init.lua`: `28a28e75ea5db0c7d2036e30525cefd431d347bc9d5349286746c5b07b658e49`.
- `tools/r15_map/kat.lua`: `dae627c0def4e569d12520f6eb98ff240f27cd0d4e16b18773ca26d0e18dd437`.
- `tools/r15_map/render_headings.py`: `7b059cef60a8869a3b899ea887cfe54e2140ba529af9d8777e429b33f646ad36`.
