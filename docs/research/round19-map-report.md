# Round 19 — Atlas lane implementation

Approved contract: round19-plan.md, lane A. Implementer: native GPT-6 Astra.
Independent review: pending coordinator assignment. Critical/High findings and
fix rounds: pending review. Elapsed wall time: unknown.

## Delivered candidate

- Whole-world atlas only, zoom stops 1/2/4, 9:8 viewport at 10.08 by 8.96 real
  units. The entire 10.65 by 11.20 wrapper uses real coordinates; controls and
  stable scrollbar gutters sit outside the clipped canvas.
- Horizontal outer clipper and full-scaled-width vertical inner clipper retain
  all corners. Background and fixed-size marker buttons share both clippers.
- Both scrollbar axes use 1000 units per unzoomed viewport, with integer clamp
  and center-preserving zoom. CHG and VAL inputs are validated before actions.
- Actual entry resets zoom/scroll/selection. Home and marker detail use sfinv's
  refresh function without on_leave/on_enter. Close/death return to Character.
- Render signatures exclude scrollbar starting values and focus. Only a form
  actually delivered advances the signature. Scroll events never recompute it.
  Active CHG input defers live redraw until the next quiet polling interval;
  pending movement/heading/marker removal is then sent normally.
- Focus stays on the most recently moved scrollbar, outside the canvas, to
  prevent native autoScroll from relocating the viewport to a focused marker
  during regeneration. Native formspec regeneration still replaces widgets:
  a stationary held thumb overlapping a later live update requires GUI testing.
  The client provides no drag-end field to the server.
- One 2700x2400 atlas replaces the 900x800 world texture and six unused regional
  PNGs. Offline authored geometry only; no mapgen/runtime sampling.

## Engine boundaries inspected

References are relative to reference_projects/luanti:

- doc/lua_api.md:3169: nested scroll containers, clipping and factors.
- src/gui/guiFormSpecMenu.cpp:341: separate clipper and mover parent hierarchy;
  positive form factors become negative pixel displacement. The inner clipper
  therefore spans the scaled content width, not just the viewport width.
- src/gui/guiFormSpecMenu.cpp:645: scrollbar integer range and thumb conversion.
  Thumb units are `(range + 1) / zoom`, giving half/quarter-track thumbs.
- src/gui/guiFormSpecMenu.cpp:3939: autoScroll acts on focused descendants,
  including first focus after regeneration; external scrollbar focus avoids it.
- src/gui/guiFormSpecMenu.cpp:4296: changed scrollbars send CHG, button submissions
  send VAL. doc/lua_api.md:3733 confirms forced focus supports scrollbars.
- mods/BASE/sfinv/api.lua: set_page always leaves/enters; its inventory refresh
  function does neither. The Map lane does not modify vendored sfinv.

## Validation and reproduction

`tools/r19_map/micro.lua` returns a function accepting the repository root and
returning one canonical string. It loads both changed production Lua files in
an isolated environment. LuaJIT PASS: bounds/corners, 1/2/4 center preservation,
edge clamps, fixed marker size, nested hitbox ancestry, external action controls,
invalid scroll/unknown click input, scroll-only no-send, unsent movement and
heading surviving CHG/quiet period, selection removal, home view preservation,
close/reentry/death/leave. No PUC runtime was run: root owns the final shared pair.

Plain tools/bin/luac51 parser PASS for all three changed Lua files. SETGLOBAL:
none in all three. All five mandatory source sweeps: no hits (including tools).

Texture reproduction (existing renderer, no changes to its authored geometry):

```sh
luajit tools/r14_map/render_atlas.lua . /tmp/r19-atlas.svg world
convert -background none -density 288 /tmp/r19-atlas.svg mods/PLAYER/grug_map/textures/grug_map_atlas_world.png
luajit -e 'print(dofile("tools/r19_map/micro.lua")("."))'
```

Runtime acceptance remains user-run: check overview fills the page; all corners
at 2x/4x; marker sizes/headings/tooltips while panning; selected details and Home
retain scroll; clipped markers do not intercept controls; sustained scrollbar
drag while party markers move; close/reentry resets. Check normal and smaller
windows. Offline fixtures verify the formspec structure, not client pixels.
