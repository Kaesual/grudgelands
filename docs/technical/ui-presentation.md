# UI presentation toolkit

Merged in 0.60.1 ([UI plan](../planning/ui-modernization-plan.md)); the
desktop/web GUI acceptance is part of the joint GUI test.

`grug_core.ui` (`mods/CORE/grug_core/ui.lua`) builds deterministic formspec
fragments. `grug_core/init.lua` installs the shared prepend on join after
`default` and `grug_sounds`: translucent nine-slice frame, list colors, button
hover/focus/pressed images and the existing click sound styles. Creation opts
out of the prepend and explicitly requests the opaque variant.

- `styles()` returns control defaults without a background or send.
- `text_scale(player)` compensates dense fixed-layout summaries when the client
  shrinks the form but retains GUI-scaled fonts. It uses available height /
  inventory window height, capped at 1 and floored by 1 / real GUI scaling;
  display density alone must not halve text. It reads window information at
  build time only; no polling or saved setting.
- `prepend(opaque)` returns background, defaults and existing click styles.
- `panel(x, y, w, h)` returns a nine-slice panel in the caller's coordinate mode.
  Emit it outside scroll containers: the engine parents backgrounds to the
  form, so a panel inside a scroll container would neither scroll nor clip.
- `heading(x, y, text)` escapes an existing heading and scopes its gold, small
  bold style; `title(x, y, text, scale)` scopes a larger normal title (optional scale).
- `button_style(name, role)` styles one existing field (`normal`, `selected`,
  `danger`). Names are single fields, not comma-separated selector lists.
- `frame(w, h, title, opaque)` opens a version-6 real-coordinate form; optional
  title at 0.4,0.45. It does not offset content or close a container.

No helper sends forms, schedules work, rewrites finished formspec strings,
adds fields to transactions, or owns inventory lists. Existing mods keep
validation, session identity, persistence, timers, animation and dirty-state
comparison. Native inventory slots and scrollbars stay native.

`grug_inventory/navigation.lua` renders the allowed sfinv pages as buttons
(up to seven per row, four when GUI scaling exceeds 1.2 on windows narrower
than 1500 pixels). Icons, text and an active underline replace filled tabs.
`navigation_layout(player, context, width, info)` returns the visible pages
and required height; `navigation` optionally accepts that layout and returns
the fragment and height. It keeps the rendered id mapping in its context and
revalidates permission at input time. It chains the existing `handle_scroll`
hook; ordinary actions still reach their page, pure inventory scrolling sends
nothing, and sfinv still runs `on_leave`/`on_enter`. The optional
`on_navigation_denied` hook is refusal-only: Admin Mail uses its existing
refusal logger and cleanup, never an authorized operation. A build following
revocation also leaves a restricted page. Character-creation suspension stays
in sfinv's existing receive/write gates.

The shared X button retains scroll position but forwards only `quit` through
the prior hook and the current page's handler. Native `button_exit` submits
editable values too; stripping those values prevents accidental dropdown
actions while preserving the same cleanup as Escape.

The shared inventory body remains 13.5 by 13.673 units, with a compact 1.5-unit
header plus 0.54 per additional navigation row. For the same window and
permissions all non-map tabs share one outer frame. The header shows the
emblem, faction, character name and level; its layout height is ephemeral
context, never player meta. The
body is in a real-coordinate container. Its pages, including Help's Sound
controls, keep real coordinates throughout their content. Do not switch an
inherited container offset to legacy units: the engine multiplies that offset
by legacy spacing (X: 5/4, Y: 15/13) instead of the real slot size, and also
adds legacy padding (`guiFormSpecMenu.cpp`, `getElementBasePos` versus
`getRealCoordinateBasePos`). A standalone legacy form must keep its own
explicit coordinate contract. Full/short/station views still show
seven/two/three rows and the original slot sizes.
The map reserves the same header **inside** its responsive whole-window
budget. `window_size(info, header_h)` optionally returns the remaining body;
without the second argument it retains the whole-window result. The existing
minimum-size floor remains. Its
own session keeps a separate tab mapping; switching to an allowed inventory
tab cancels pending map sends before sfinv displays the target. The deferred
home reset cannot overwrite that target, and the existing shown-form backstop,
quiet period, send gap and party-marker budget remain.

Theme assets are 18 original 32-by-32 RGBA geometric images (seven frame/
control states, one clear image, ten line icons), reproducible with
`python3 tools/ui_theme/build.py` (`--check`). The check compares PNG bytes;
reproduction depends on the Pillow and zlib versions used to generate them.
Their license is in
`mods/CORE/grug_core/LICENSE-media.md`. Native client fonts are used; the
browser study's CSS effects are not runtime dependencies. Panels use alpha
94/255 and thin light borders; normal buttons are ghost surfaces (9/255),
with client-side hover/focus/pressed and gold selected states. The outer
window retains alpha 231/255 for readability on bright terrain. Nine-slice
button padding cancels four of the six inset pixels, avoiding clipped text.
Talent icon buttons use a two-pixel inset. Native checkboxes cannot style
font size: the crowded Crafting filters use shorter captions and full
tooltips at enlarged GUI scales. `professions_formspec(rows, area, player)`
adds an optional player argument solely for dense-text sizing.

Verification includes `tools/ui_navigation`, the existing page/session/focus
fixtures, the crafting queue and furnace animation fixtures and a disposable
engine boot. [Traffic comparisons](../../tools/ui_theme/measurements.md) report
payload differences separately from send frequency. Final geometry, font
readability and actual client input remain on the desktop/web GUI checklist.
