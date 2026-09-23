# Round 18 held-light preflight — deferred

Date: 2026-09-23. Assessor: root Astra, following the user's required preflight.
No production code, asset, lighting experiment or runtime benchmark was created.

The user clarified that this is the least important, entirely optional package;
other players need not see the light and it should be omitted unless simple.
The lane is therefore **deferred before implementation** under that instruction.

## Evidence inspected

Read-only `git show` of the locally available VoxeLibre object
`33df8cf5c6187a35a9a556a5532fe6f22a01193c`,
`mods/PLAYER/vl_wieldlight/init.lua` (newer than our pinned checkout).
The pinned reference remains `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`;
no submodule checkout, fetch, media import or pin change occurred.

The implementation reads old/new local VoxelManip regions and light banks,
performs explicit light-removal and spreading breadth-first traversals, restores
registered static light sources, handles separate regions after teleports, writes
light data without ordinary lighting recomputation, and calls fix_light on leave
and shutdown. This is not a periodic fake torch node or a small entity effect.

Adopting it responsibly requires proving that overlapping moving sources,
existing static light, unloading/restart and node mutation remain correct. The
registered static-source cache is not an authoritative registry of other dynamic
player lights. That is a verification/ownership risk, not a claim that an upstream
multiplayer bug has been reproduced. No reproduction was attempted.

Allowing other players' light to be invisible does not remove this issue for
that approach: map light data is shared server state. A private visual overlay
would be a different approximation and is not an authorized replacement for a
local world-light radius. Given the user's low priority and simplicity condition,
this complexity does not justify beginning implementation in Round 18.

Future work may revisit supported engine dynamic lighting or a bounded proven
upstream implementation. It does not block any other Round 18 lane.
