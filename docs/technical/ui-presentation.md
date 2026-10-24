# UI presentation toolkit

Implemented in the isolated [UI branch](../planning/ui-modernization-plan.md);
release integration and desktop/web visual acceptance are still pending.

`grug_core.ui` (`mods/CORE/grug_core/ui.lua`) builds deterministic formspec
fragments. `grug_core/init.lua` installs the shared prepend on join after
`default` and `grug_sounds`: translucent nine-slice frame, list colors, button
hover/focus/pressed images and the existing click sound styles. Creation opts
out of the prepend and explicitly requests the opaque variant.

- `styles()` returns control defaults without a background or send.
- `prepend(opaque)` returns background, defaults and existing click styles.
- `panel(x, y, w, h)` returns a nine-slice panel in the caller's coordinate mode.
  Emit it outside scroll containers: the engine parents backgrounds to the
  form, so a panel inside a scroll container would neither scroll nor clip.
- `heading(x, y, text)` escapes and colors an existing heading.
- `button_style(name, role)` styles one existing field (`normal`, `selected`,
  `danger`). Names are single fields, not comma-separated selector lists.
- `frame(w, h, title, opaque)` opens a version-6 real-coordinate form; optional
  title at 0.4,0.45. It does not offset content or close a container.

No helper sends forms, schedules work, rewrites finished formspec strings,
adds fields to transactions, or owns inventory lists. Existing mods keep
validation, session identity, persistence, timers, animation and dirty-state
comparison. Native inventory slots and scrollbars stay native.

`grug_inventory/navigation.lua` renders the allowed sfinv pages as buttons
(up to seven per row). It keeps the rendered id mapping in its context and
revalidates permission at input time. It chains the existing `handle_scroll`
hook; ordinary actions still reach their page, pure inventory scrolling sends
nothing, and sfinv still runs `on_leave`/`on_enter`. The optional
`on_navigation_denied` hook is refusal-only: Admin Mail uses its existing
refusal logger and cleanup, never an authorized operation. A build following
revocation also leaves a restricted page. Character-creation suspension stays
in sfinv's existing receive/write gates.

The shared inventory body remains 13.5 by 13.673 units, with a fixed 2.2-unit
header added above it (one common outer frame for all non-map tabs). The
body is in a real-coordinate container. Its pages, including Help's Sound
controls, keep real coordinates throughout their content. Do not switch an
inherited container offset to legacy units: the engine multiplies that offset
by legacy spacing (X: 5/4, Y: 15/13) instead of the real slot size, and also
adds legacy padding (`guiFormSpecMenu.cpp`, `getElementBasePos` versus
`getRealCoordinateBasePos`). A standalone legacy form must keep its own
explicit coordinate contract. Full/short/station views still show
seven/two/three rows and the original slot sizes.
The map retains its responsive body and adds the same header above it. Its
own session keeps a separate tab mapping; switching to an allowed inventory
tab cancels pending map sends before sfinv displays the target. The deferred
home reset cannot overwrite that target, and the existing shown-form backstop,
quiet period, send gap and party-marker budget remain.

Theme assets are original 32-by-32 RGBA geometric images, reproducible with
`python3 tools/ui_theme/build.py` (`--check`). The check compares PNG bytes;
reproduction depends on the Pillow and zlib versions used to generate them.
Their license is in
`mods/CORE/grug_core/LICENSE-media.md`. Native client fonts are used; the
browser study's CSS effects are not runtime dependencies.

Verification includes `tools/ui_navigation`, the existing page/session/focus
fixtures, the crafting queue and furnace animation fixtures and a disposable
engine boot. [Traffic comparisons](../../tools/ui_theme/measurements.md) report
payload differences separately from send frequency. Final geometry, font
readability and actual client input remain on the desktop/web GUI checklist.
