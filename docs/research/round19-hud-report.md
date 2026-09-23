# Round 19 party, status and dragon HUD implementation

Date: 2026-09-23. Implementer: native GPT-5.6 Sol. Scope: approved Round 19
lanes C and D. Independent review, the frozen PUC/LuaJIT parity pair and native
GUI acceptance remain with the coordinator.

## Lane C

Commit `db9d992796211ef16fcc7ec8a486fcab2a6eae40` makes `by_class` the
canonical fallback for an absent or invalid party health-color preference in
the accessor, Group dropdown and HUD adapter. An explicitly stored
`all_green` value remains unchanged and is not rewritten.

The shared status anchor is now top center at 20 HUD units of upper padding.
The existing eight-entry limit, one-second status refresh and left/right
party/quest columns are unchanged. Sprint registers one display-only status,
`Sprint (+50% Speed)`, for the existing ten-second movement modifier. Its
value callback suppresses the line whenever the authoritative
`scout_sprint` movement modifier is absent. The status owns no movement value,
expiry callback or additional polling loop; the existing movement and status
lifecycle handlers independently clear their runtime state on expiry, death
and disconnect.

## Lane D

Commit `d823b0ced8905aa58d9811f6385cce4eaab2f060` adds a small registered-entity
presentation adapter because mobs_redo copies a fixed definition field set.
The adapter validates and copies the presentation record onto the actual
registered Lua-entity prototype after `mobs:register_mob` returns.

The Wyrmglass Ice Dragon uses a world-space anchor of 5.0 nodes, matching its
combat eye height. Stormscale uses 4.0 nodes, matching its eye height. Both
bars are 3.0 nodes wide and 0.25 nodes high. With their current 8x parent
visual scale those values become attachment offsets 6.25/5.0 engine attachment
units and child visual sizes 0.375 by 0.03125; empty-bone attachment then
inherits the parent scale and restores the requested world dimensions.
Ordinary mobs, guards and whelps retain the generic 0.8 by 0.1-node bar and
selection-box-derived anchor. Injured-only creation, HP fraction, observer
filtering, 25/30-node hysteresis, perspective scaling and cleanup remain on the
existing tag-carrier path.

## Validation

`tools/r19_hud/fixture.lua` returns one canonical function and loads the real
party accessor, Group preference API, HUD layout, status implementation, Scout
ability registration, dragon definitions and tag-carrier adapter. LuaJIT
returned:

```text
r19-hud	PASS	checks=16	party=by-class	status=top-centre	sprint=authoritative	dragon=5x3x0.25	ordinary=0.8x0.1
```

The fixture covers absent and explicit party preferences; the production
top-center anchor; Sprint start, expiry, explicit movement removal, death and
reconnect; both real dragon metadata records through the registered-prototype
adapter; inherited attachment conversion; and unchanged ordinary geometry.

All nine changed Lua files parse with the repository's PUC 5.1 compiler. The
SETGLOBAL inventory contains only the established `grug_parties` and
`grug_mobs` mod tables. All five compatibility sweeps were run over the mod
scope and explicitly over the tool fixture; changed-file hits are the existing
comment describing tier alternatives and the ordinary `"|"` string delimiter,
not forbidden syntax. No PUC runtime, native world, sync, push or provider CLI
was run.

GUI acceptance should check the full eight-status block at common window sizes,
including party rows and transient center notices, and both injured dragons at
combat distance. The 3.0 by 0.25-node dragon size and eye-height anchors are a
bounded first pass; the fixture proves the engine-unit conversion, not screen
pixel readability or animated-mesh head tracking.
