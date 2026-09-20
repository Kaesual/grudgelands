# Independent WORLD-CAP review

Verdict: **CLEAN**. No substantive Critical, High, Medium, or Low findings.

Reviewed candidate `6270c80d392e4339426dd468f22e46331f5847eb` on
`wp40-r11-world-cap` against base `45fbc477d3f929945b3100ce523983194a8c5757`.
The review was read-only with respect to the repository. Implementer: native
Astra. Reviewer: independent native GPT-5.6 Sol context. The user-authorized Round 11
exception was followed: no PUC runtime, long LuaJIT suite, census, or flotilla
was run.

## Verified findings

- `mods/MAPGEN/grug_mapgen/wp40/height.lua:180-192,5338-5352,5414-5463`:
  the correction changes only fallback run orientation. It preserves the
  existing lattice-derived Euclidean distance, water level, freshwater flag,
  first 16-node cardinal lookup, profile/width formulas, functional precedence,
  and exclusion paths. The new lookup checks actual cardinal water contacts at
  distances 17 through 52, has deterministic direction-order ties, retains the
  old fallback when there is no contact, and is bounded by 144 calls into the
  existing 65,536-entry classification cache. Coordinates are world-absolute,
  so behavior does not depend on owner/chunk traversal order.
- `tools/r11_world/compare_beach.py:4-29` and bound evidence: both 65x65 witness
  rectangles contain 8,450 actual source columns. Classification, ownership,
  claims, cave claims, incoming height, water kind, functional identity,
  landmark state, and shore distance remain identical. The explicit thin-high-
  column count changes from 7 to 0 and 9 to 0. When run identity is unchanged,
  profile, width, coast target, and final height are unchanged. The writer log
  additionally exercises the real R5 source/planner/VM adapter and confirms
  corrected clearing of stone, grass soil, and coal ore in both witness areas.
- `mods/MAPGEN/grug_mapgen/wp13/capitals.lua:1115-1116`: exactly one additional
  gatehouse cell is cleared. No dedicated stair test was added, as required.
- `mods/MAPGEN/grug_mapgen/wp13/capitals.lua:1665-1687` and the six plot
  builders: all six riding plots instantiate the same 21x17 earth-floor open
  shelter, with a full flat roof, one-node fence and five-node entrance, exactly
  six posts, and generic furniture cleared before restamping.
- `mods/MAPGEN/grug_mapgen/wp13/capital_services.lua:55-75`: all 24 mount rest
  sockets remain present. The 12 ground mounts receive 12 bounded lanes and 24
  non-spawning waypoint endpoints; grounded flyers receive no walk endpoints.
  The focused socket consumer verifies actual part rotation, nonzero anchor and
  terrain offsets, all four orientations, registry lookup, and copy isolation.
- Cross-package interface check against accepted GAME commit `43c09f39`:
  `mods/ENTITIES/grug_mobs/capital_displays.lua:25-31,42-57` uses the measured
  move minimum and the same authored floor convention, `socket.y - 0.5`, for
  waypoint grounding. This agrees with CAP's same-y rest/endpoints and avoids
  repeated relative lift.
- `mods/MAPGEN/grug_mapgen/wp13/capital_services.lua:77-116` and
  `mods/ITEMS/grug_decor/capital.lua:7-16,58-80`: all 48 service plots retain
  public stations; the six shared forges keep separate Weaponsmith/Armorsmith
  products, while every other profession has exterior and interior product
  presentation. The eight fixed product nodes have no editable inventory,
  digging, pickup, punch/right-click action, or blast drop path.
- Geometry evidence covers six shelters, 24 posed displays and all eight ground
  model move clips (422 unique integer-frame evaluations). Swept full-yaw
  envelopes clear emitted nonair cells, neighboring mounts, grounded flyers,
  and the public aisle at the declared 0.01-node margin. The five actual-texture
  views were inspected: Riding, Forge and Tailor cutaways plus Forge and Tailor
  frame close-ups are legible and consistent with emitted geometry; no missing
  texture is reported.
- Both SHA-256 manifests pass in full, including the baseline source binding,
  production/tool inputs, models, evidence outputs, and five PNG views. The
  submodule pins are unchanged and clean. The retained Lua 5.1 parser,
  SETGLOBAL, and five static sweeps pass for all 18 changed/added Lua files.
  `git diff --check` passes.
- I independently reran only the three bounded LuaJIT consumer fixtures under
  idle scheduling. They pass: 48 real service plots / six shelters / 24 mounts /
  24 endpoints / 48 exterior frames; real four-rotation socket registry; and
  diagonal/tie/no-contact coast behavior with the 144-call ceiling.

## Residual GUI acceptance

Per the approved contract, visual movement interpolation, appearance with the
stable roof present, the two beach sightlines in the real engine, and ordinary
capital play remain fresh-world GUI acceptance items. The evidence states these
limits accurately; they are not review findings.

Calibration: initial0Critical/0High/0Medium/0Low, zero correction rounds; observed elapsed unknown.
