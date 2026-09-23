# Round 18 B — atlas and native minimap

Author: native Sol (`r18_map`), author commit `006defb6`, integrated `386f6216`.
Independent review remains a separate completion gate.

The atlas now uses six overlapping rectangles in a 3-column x 2-row cover of
[-3600,3600] x [-3200,3200]. Each inner edge extends 120 nodes across the seam.
The old internal view IDs remain, with directional labels appropriate to their
larger coverage. `grug_map/atlas.lua` owns the bounds used by both the renderer
and runtime projection. Each regional image uses its world aspect ratio and is
centered on the page; marker projection uses the identical display rectangle.

The native minimap cycle is surface/off, initially surface. Client settings and
the V toggle remain available. Players and entity initial properties set
`show_on_minimap=false`; their actual visibility and nametags are unaffected.
The local arrow is drawn independently: reference engine `content_cao.cpp`
1621–1622 already excludes the local object marker, while `client/minimap.cpp`
629–639 draws the local arrow before the active marker loop at 646. The selected
mode is zero-based (`l_object.cpp` 2801–2819 and client packet handler 1856–1880).

Author checks: bounded coverage/border/overlap and all six full capital envelopes;
projection, actual registration/join callbacks, existing page marker/click/live
behavior; all changed Lua parser/SETGLOBAL/five sweeps and diff whitespace.
Renderer replay produced identical stripped PNG bytes. Author visually inspected
the six-view atlas; root also inspected the expanded Human view. These are media
and source checks, not a client GUI test. Root's combined LuaJIT fixture run also
passed `r18_map/atlas_kat.lua`, `r18_map/minimap_kat.lua` and the updated
`r14_map/page_kat.lua`. No intermediate PUC execution occurred.

User GUI acceptance: all regions/islands/capitals are accessible, markers track
the correct points, default minimap has the own arrow but no remote dots, and V
continues to toggle it.
