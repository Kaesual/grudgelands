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
visual scale those anchors become attachment offsets 6.25/5.0 engine attachment
units. Their child billboard visual sizes remain 3.0 by 0.25 because Irrlicht
constructs billboard vertices in world space and does not apply the parent's
scale to their dimensions. Empty-bone attachment inherits the parent transform
for position only.

The generic path for ordinary mobs, guards and whelps remains numerically
unchanged: it still emits `0.8 / sx` by `0.1 / sy` and the existing
selection-box-derived anchor. The unit-scale fixture therefore remains 0.8 by
0.1, but this report makes no world-size-invariance claim for scaled generic
entities. A broader generic retune is outside this focused correction.
Injured-only creation, HP fraction, observer filtering, 25/30-node hysteresis,
perspective behavior and cleanup remain on the existing tag-carrier path.

## Validation

`tools/r19_hud/fixture.lua` returns one canonical function and loads the real
party accessor, Group preference API, HUD layout, status implementation, Scout
ability registration, dragon definitions and tag-carrier adapter. LuaJIT
returned:

```text
r19-hud	PASS	checks=16	party=by-class	status=top-centre	sprint=authoritative	dragon=5x3x0.25	ordinary=legacy-unit-scale
```

The fixture covers absent and explicit party preferences; the production
top-center anchor; Sprint start, expiry, explicit movement removal, death and
reconnect; both real dragon metadata records through the registered-prototype
adapter; inherited attachment-position conversion; direct billboard dimensions;
and unchanged ordinary unit-scale geometry.

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

## Focused attachment-size correction

Independent review found that the original implementation incorrectly treated
billboard dimensions like attachment translation. Native client code sets the
billboard size directly from `visual_size`, then constructs world-space vertices
and renders them with the identity world matrix. The focused correction keeps
the parent-scale division for attachment height, removes it from explicit
billboard width/height, and updates the fixture expectations. The legacy generic
inverse-size compensation remains unchanged by scope. No native GUI claim is
added; focused independent re-review remains required.
