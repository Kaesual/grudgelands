# UI presentation toolkit

Merged in 0.60.1 ([UI plan](../planning/ui-modernization-plan.md)); the
service-dialog helpers (`service_header`, `prose`) came with 0.61.1
([dialog review](../planning/ui-dialog-review.md)). The desktop/web GUI
acceptance is part of the joint GUI test.

`grug_core.ui` (`mods/CORE/grug_core/ui.lua`) builds deterministic formspec
fragments. `grug_core/init.lua` installs the shared prepend on join after
`default` and `grug_sounds`: translucent nine-slice frame, list colors, button
hover/focus/pressed images and the existing click sound styles. Creation opts
out of the prepend and explicitly requests the opaque variant.

- `styles()` returns control defaults without a background or send.
- `text_scale(player)` compensates dense fixed-layout summaries when the client
  shrinks the form but retains GUI-scaled fonts. It uses available height /
  inventory window height on the Full-HD ceiling, capped at 1 and floored by
  1 / real GUI scaling (display density alone must not halve text), times
  `text_growth(player)`. It reads window information at build time only; no
  polling or saved setting.
- `text_growth(player, w, h)` (Round 66) is how much larger a `w` by `h` form
  (default the inventory window) is drawn under the grown viewport ceiling
  than under the Full-HD one, from the engine's fitting equations
  (`form_growth(info, w, h)` in `ui_window.lua`). Form text is multiplied by
  it, so text keeps its 1080p proportion to the slots: font pixels follow
  only GUI scaling and display density (`fontengine.cpp` `getFontSize`,
  `StyleSpec.h` `*` sizes), slot pixels follow the viewport. It is exactly 1
  on screens up to 1620 px high, where every form string stays as before,
  and also where the form does not grow (a width-bound portrait window, the
  fixed image-size floor on a high-density display).
- `font_size(factor, growth)` returns a `font_size` value for a literal size:
  at growth 1 the literal itself (`*0.85`, `*1`, empty for the client
  default), otherwise `factor * growth`. Forms write their literal sizes and
  resets through it.
- `prepend(opaque)` returns background, defaults and existing click styles.
- `panel(x, y, w, h)` returns a nine-slice panel in the caller's coordinate mode.
  Emit it outside scroll containers: the engine parents backgrounds to the
  form, so a panel inside a scroll container would neither scroll nor clip.
- `heading(x, y, text, scale)` escapes an existing heading and scopes its gold, small
  bold style; `title(x, y, text, scale, reset)` scopes a larger normal title
  (optional scale) and restores labels to `reset` (default 1).
- `prose(x, y, w, h, text, muted, restore_font_scale, font_scale)` emits
  escaped, read-only body text at the normal client font by default. An
  explicit body scale can distinguish a title or reading text; otherwise it
  uses the caller's restoration scale (default 1). Its anonymous textarea
  restores `border=true` and that scale so later editable fields retain the
  owning form's typography.
- `service_header(w, title, subtitle, icon, scale)` draws a service window's head
  for a form `w` wide: an icon (default the emblem), the title, an escaped
  muted subtitle and a thin gold rule at y 1.35; the owner's content starts
  below it.
- `button_style(name, role, scale)` styles one existing field (`normal`, `selected`,
  `danger`). Names are single fields, not comma-separated selector lists.
- `frame(w, h, title, opaque, player)` opens a version-6 real-coordinate form;
  optional title at 0.4,0.45. The player supplies the current viewport report
  for the viewport ceiling. On a grown ceiling the frame also scopes the
  native text defaults (`fonts`) and its title to the form's `text_growth`.
  It does not offset content or close a container.

`fonts(scale)` scopes native control text sizes within a form. Party, quests
and Mail pass the existing `text_scale(player)` through scoped heading, button,
prose and service-header helpers, so a large GUI font cannot overrun the fixed
form after native fitting. This changes neither frame geometry nor refresh
cadence. Main and mailbox navigation uses 1.1× text; selectable quest/mail
row titles use 1× and secondary text 0.9×; reading text 1.05×; section headings
0.9× bold. At GUI scale 1 ordinary body/action text is not reduced to 0.8–0.85×.

`rows(state, spec)` in `grug_core/ui_rows.lua` renders the quest giver, Map's
quest list and Mailbox letters/announcements as buttons in a native scroll
container. Each row has a title, secondary line and optional existing
state/provenance icon. Long titles wrap to two lines; ellipsis and full tooltips
cover overflow. Category headers are not selectable. `rows_event(state, name,
fields)` maps only rendered selectable indices, keeps scrollbar CHG/VAL values,
and returns a click index plus whether this was a scroll change. Owners retain
all id mapping, permissions and action validation. `rows_reset` clears transient
scroll on page/giver changes; redraws clamp it to the current range. Explicit
`reveal_selected` brings initial/automatic giver selections into view.

These are native buttons: mouse selection and Tab/Shift-Tab focus with Enter
activation replace table/textlist arrow-key selection. Scrolling is client-side;
a pure scrollbar event never sends the form. Map list dragging uses the existing
map quiet period to defer pending automatic refreshes. The helper adds no timer,
globalstep or saved state. It emits more formspec elements per rendered row;
Mailbox retains eight-row pages and the quest log retains its existing limit.
The responsive Map retains native text scale 1 for rows and surrounding labels;
its geometry already incorporates the GUI scale, so inventory-fit compensation
must not leak into its typography. On a grown ceiling its shared navigation
header and the labels after it follow `text_growth`, and so does its body
(Round 66 lane MAP): the "Current:" line, the quest rows (`rows` scale) and
texts and the zone labels (font and box) grow by the map form's own
`text_growth`, taken from the raw window report; up to a 1620 px high screen
the growth is 1 and the form's bytes are unchanged (`tools/r66_ui/bytes.lua
map`). Other native tables, including Admin Mail,
keep their own existing behavior.

Native frame fitting remains enabled, with a viewport ceiling
(`grug_core/ui_window.lua`). On each existing rebuild, `window_padding(player,
base, info)` limits the available viewport to a height of
`min(H, max(1080, 2/3 H))` and a width of `1920 · k` (at most W), `k` being
that height over 1080 (Round 66 ruling 4; Full HD before), retaining the
ordinary 5% padding (Map uses 0%). Up to a 1620 px high screen this is the
Full-HD ceiling, unchanged; a 3840×2160 screen lays out like 2560×1440 and
the inventory window fills about 60 % of its height (90 % at 1080p, 68 % at
1440p). The engine then applies its usual DPI, GUI-scale and form-size
calculation. This reproduces that same window's rendering on a screen of the
ceiling's size with the same client settings; it does not force GUI scale 1
or impose the same dimensions on every dialog. For a viewport within the
ceiling the regular frame is unchanged. Text grows with the ceiling
(`text_growth`); controls the engine draws in the client font cannot follow:
checkbox and dropdown captions, item counts, tooltips and the welcome
window's hypertext (Help's hypertext body gets a `<global size>` by the
growth). The vendored sign, book and mob dialogs keep their explicit sizes at
the client font as well.
Padding must follow `position[]` and `anchor[]` and precede `no_prepend[]`;
Quickbar therefore adds it after its existing left anchor.

`window_information(info, full_hd)` derives the matching virtual viewport and
maximum formspec size for responsive layouts and fitted typography (with
`full_hd`, the Full-HD-capped one that text sizes are measured against). A
derived report is marked `capped` and passes through unchanged, since the
ceiling follows the screen height. Map uses it both for its body budget and
zone-label metrics. The derivation retains the native fixed image-size floor
(`0.5555 * 96 * real_gui_scaling`); density is never assumed to equal the GUI
setting. The fixture `tools/ui_window_cap` compares native fitting equations
on small, Full-HD, WQHD, 4K, ultrawide and portrait windows, GUI 1/1.5,
density 1/2, real/legacy forms and resize rebuilds; `tools/r66_ui` checks the
grown ceiling, the text proportion and that every result up to 1620 px screen
height equals 0.65.0's (`bytes.lua` compares the inventory pages' and the map
window's strings with an older tree).

Reports can be absent at join and lag a resize. An absent report leaves native
fitting uncapped; a later existing rebuild applies the latest known cap.
While an already-open window is resized, its last reported padding remains
until such a rebuild. There is no immediate hard pixel guarantee during that
interval, no polling and no corrective resend. For forms built from the same stable report, opening
and changing tabs use the same cap. A cached initial inventory built before
the first report can still open uncapped until an existing action rebuilds it. Geometry is never reduced to create the
cap: only the available client viewport changes.

`navigation_style(name, selected, x, y, w, h, vertical, scale)` styles an existing
navigation field. Horizontal choices have an active underline; side menus have
a flat selection and left marker. The owning caller still emits the native
button and keeps its field route. Native button text remains centered. Actions
use translucent fills without outlines, selected actions use gold text/fill,
and hover, keyboard focus and press have distinct fills. Native input controls
and their focus handling are unchanged.

`input_background(x, y, w, h, name)` draws a slate backing and scopes borderless
styling to an existing native input. The input keeps its own name, focus,
editing, submission and validation behavior. Luanti edit boxes have no styled
fill color; disabling their native border also disables that native fill.

No helper sends forms, schedules work, rewrites finished formspec strings,
adds fields to transactions, or owns inventory lists. Existing mods keep
validation, session identity, persistence, timers, animation and dirty-state
comparison. Native inventory slots and scrollbars stay native.

`grug_inventory/navigation.lua` renders the allowed sfinv pages as text buttons
with caption-weighted widths and an active underline. Admin Mail stays in the
primary row. Creative has one primary entry and a separate category row,
drawn only while a Creative page is open (Round 67 ruling 9; every other page
keeps the one-row header). Full titles remain
in tooltips; permissions are never replaced by hidden navigation.
`navigation_layout(player, context, width, info[, selected])` returns the
visible pages and required height, the category row only when `selected` is
a `creative:*` page (the map window passes none); `navigation` optionally accepts that layout and returns
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

The shared inventory body is 20 by 13.5 units, with a compact 1.5-unit
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
explicit coordinate contract. Full/short views show eight/two rows with native 1-unit slots and 1.25 pitch.
The centered hotbar is shared across inventory tabs. Station callers can pass
an optional fifth `visible_rows` argument: chests four, shelves six, furnaces
five, Claim Stone management two and recovery three. Remaining bag contents
scroll without changing list capacity or inventory routes.
The map reserves the same header **inside** its responsive whole-window
budget. `window_size(info, header_h)` optionally returns the remaining body;
without the second argument it retains the whole-window result. The existing
minimum-size floor remains. Two equal columns hold the map viewport and separate quest-list/detail panels.
At 1× the undistorted map is centered within its viewport; enlarged zooms use
the available viewport. Scroll factors and thumb sizes account for the actual
image extent on each axis. Layer dropdown indices stay stable across quest
selection; unchanged dropdown echoes do not clear that selection. The map
session keeps a separate tab mapping; switching to an allowed inventory
tab cancels pending map sends before sfinv displays the target. The deferred
home reset cannot overwrite that target, and the existing shown-form backstop,
quiet period, send gap and party-marker budget remain.

Theme assets are 21 original 32-by-32 RGBA geometric images (ten frame/
control states, one clear image, ten line icons), reproducible with
`python3 tools/ui_theme/build.py` (`--check`). The check compares PNG bytes;
reproduction depends on the Pillow and zlib versions used to generate them.
Their license is in
`mods/CORE/grug_core/LICENSE-media.md`. Native client fonts are used; the
browser study's CSS effects are not runtime dependencies. Panels use alpha
94/255 and thin light borders; normal buttons are flat ghost surfaces (14/255) without outlines,
with client-side hover/focus/pressed and gold selected states. The outer
window retains alpha 231/255 for readability on bright terrain. Nine-slice
button padding cancels four of the six inset pixels, avoiding clipped text.
Main navigation stays transparent on hover and press, changing text color;
focus remains visible through its fill. Side menus use square flat fills and
a left active marker. Navigation cancels all six inset pixels so content
keeps its original position. The close mark inherits the flat action states.
Talent icon buttons use a two-pixel inset. Native checkboxes cannot style
font size: the crowded Crafting filters use shorter captions and full
tooltips at enlarged GUI scales. `professions_formspec(rows, area, player)`
adds an optional player argument solely for dense-text sizing.

Verification includes `tools/ui_navigation`, the existing page/session/focus
fixtures, the crafting queue and furnace animation fixtures and a disposable
engine boot. [Traffic comparisons](../../tools/ui_theme/measurements.md) report
payload differences separately from send frequency. Final geometry, font
readability and actual client input remain on the desktop/web GUI checklist.
