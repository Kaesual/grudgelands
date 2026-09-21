# Round 14 world integration review

Independent read-only review, 2026-09-21. Implementer: native Sol; reviewer:
native Astra, fresh context, no production authorship. Initial verdict:
**changes required**. Initial findings: 0 Critical, 2 High, 3 Medium.
Elapsed wall time: unknown. One initial correction round is in progress.

**Focused re-review verdict: PASS for the reviewed production changes.** All
five initial findings are closed after one correction round. POI corrective
implementation: native Astra, reviewed independently by this original reviewer
who authored none of the production changes. Native integration, final
interpreter parity and user runtime gates below remain separate and pending.

## Findings

1. **High — atlas markers use the wrong engine coordinate metric (closed).**
   `mods/PLAYER/grug_map/page.lua:87–97` projects marker positions using the
   image dimensions, while its actual `sfinv.make_formspec` wrapper in
   `mods/PLAYER/grug_inventory/ui.lua:26–38` leaves legacy coordinates active.
   Engine `reference_projects/luanti/src/gui/guiFormSpecMenu.cpp:803–812`
   multiplies image geometry by `imgsize`, whereas element positions use
   `spacing`; `:3330–3340` defines that spacing as 5/4 horizontally and 15/13
   vertically. Markers consequently drift across the image, up to 25%/15.4%
   of its extent, rather than indicating the fitted anchor or player location.
   The page fixture stubs away this wrapper and only checks the same incorrect
   numerical transform. Fix the page-local coordinate mode and verify the real
   wrapper ordering and page bounds. The author subsequently prepended
   `real_coordinates[true]` to page content. Focused independent re-review
   confirmed that the real wrapper appends this after navigation, and that
   both image and button handlers then use `imgsize` for positions and sizes
   (`guiFormSpecMenu.cpp:803–806,1000–1005`). The image and buttons remain
   inside the available page. This High is closed; GUI checking remains a
   user runtime gate.

2. **High — POI footprint exceeds the guaranteed terrain core (closed).**
   `mods/MAPGEN/grug_mapgen/wp40/r14_poi_blueprint.lua:38–46,55–60,77`
   writes a 47×47 plane at anchor height and puts buildings/towers outside
   the flat core, but supplies no foundations below that plane.
   `docs/design/world_zones.md:538–546` guarantees only 24×24 for villages and
   home camps, 16×16 for outposts. Actual implementation in
   `wp40/height.lua:2755–2800` blends exterior columns toward natural height;
   it does not flatten the larger fitting envelope. Thus every such building
   relies on an absent terrain guarantee: a lower exterior column leaves a
   floating floor; a higher exterior column produces a cut edge. This is a
   structural contract violation established from the real height consumer,
   not a claim that an unrun seed population was measured. Recommended bounded
   fix: village/camp cells within x,z=-12..11; outpost cells within -8..7.
   A captive at (10,10) remains outside the 12-node hostile spawn disk.
   Keep the existing anchors, grading and road authority unchanged.

3. **Medium — protected loot displays are ordinary collectible blocks (closed).**
   `r14_poi_blueprint.lua:73–76` claims a hard POI envelope but writes ordinary
   palette accents, including copper blocks and emberglass lamps. The actual
   `wp40/r7_zone_overlay.lua:33–39` protects only each functional root column;
   `source/simple_map.lua:1095–1130` adds no village/camp display envelope.
   The home-faction branch in `wp40/zones.lua:1396–1413` permits ordinary
   home-territory alteration. A home player can therefore mine these displays
   for valuable materials. Use bounded protected display definitions/seams,
   without introducing blanket POI protection; correct the misleading record.

4. **Medium — the four camp tents are ground slabs (closed).**
   `r14_poi_blueprint.lua:68–70` places roofs and posts entirely at y=1,
   directly above the ground at y=0, leaving no shelter volume or recognizable
   tent silhouette. Confirmed in the actual-texture Starbough camp gallery.
   Raise the roof and supports while retaining clear entries and the existing
   spawn root. Root accepted this visual correction with the footprint fix.

5. **Medium — world labels overlap and clip (closed during review).**
   The original renderer centered every zone name on its hub without collision
   or edge handling. The world PNG visibly merged adjacent capital/frontier
   labels and clipped both island names. The correction in
   `tools/r14_map/render_atlas.lua:93–120` uses nine overview labels, retains
   local labels in regional views, and clamps island labels inward. Independently
   re-inspected the regenerated world PNG: labels are now readable and inside
   the frame. This finding is closed; the coordinate finding remains separate.

## Scope and evidence

Read the model policy, WP review checklist and Lua 5.1 test strategy, current
Round 14 execution/POI/MAP records, settlement/world-zone/world-atlas contracts,
the changed roster, shared builder and thin source adapters, and relevant real
R7 preparation/lazy construction/palette/placement and NPC lifecycle consumers.
The initial shared builder SHA-256 was
`37e5ebcdb6b406d6251775081399fe72fb016fe0a39e55c6fc7ed28bd7557a44`;
the corrected page SHA-256 is
`1d06690f04ace48dd8aea767c6d711a212c9d8ef397aabe06353016f869f9b0e`.

No additional defect found in appended stable anchor identities, palette union,
lazy rebuild identity checks, mapchunk clipping or functional-root reservation.
Outpost/camp roots use the existing writer and reserve their exact y+1 cell.
NPC rows recognize strict quest sockets, retain original socket claim/reload
handling, and obtain quest titles from the catalog rather than duplicating it.
The atlas providers read runtime anchor/player coordinates, keep markers separate
from art, and add no travel authority. Its authored control-geometry art makes
no exact generated-terrain claim. Existing node-timer and NPC heartbeat budgets
remain the owners; the new atlas does not add a globalstep.

The reported initial portable POI result was
`r14_poi_v1 / 18 / 516906 / 6751380`. It does not prove terrain fitting,
protection, engine coordinate units or native manifest/planner integration.
The reviewer did not duplicate native, heavy or PUC runtime tests. Historical
offline fixtures with outdated bed/door dependency assumptions were not patched
or treated as current acceptance gates.

## Remaining acceptance gates

- Native real manifest and planner run after story catalog activation and final
  content freeze; inspect actual sockets, root nodes and final footprints.
- Root's single bounded final PUC/LuaJIT pair and immutable hashes/logs on the
  corrected final production bytes, plus required parser/static gates.
- User GUI playtest: all seven atlas views, marker/anchor alignment and clicks;
  one village/outpost/camp, reachable quest NPCs, building entries, protected
  displays and ordinary mutable scenery, unload/reload without duplicate NPCs.

These outstanding gates are not additional confirmed bugs and do not authorize
duplicate interpreter populations or broad mapgen redesign.

## POI focused re-review closure

The corrected builder and roster now enforce the exact guaranteed flat cores:
village/camp -12..11 and outpost -8..7, including clearing, roof overhangs,
watch posts and sockets. No height rule, stable anchor or external road was
changed. The camp captive at (10,1,10) is reachable and outside the 12-node
spawn disk; the reserved root remains clear in the composition and is still
owned by the existing anchor writer. Four small village houses and the outpost
watch house retain usable three-wide entries. The fixture's BFS checks house
centres and all authored sockets while excluding the functional root.

`poi_displays.lua` supplies six bounded decorative node definitions with no
harvest groups, no recipes or inventories, empty drops, `diggable=false`,
`buildable_to=false` and `floodable=false`. `init.lua` registers them before
the real R7 loader resolves the palette. Luanti's actual dig path respects
`diggable=false` (`reference_projects/luanti/builtin/game/item.lua:495–503`).
Only these display nodes become immutable; ordinary scenery retains the
existing territory rules. The misleading blanket-protection claim was removed.

The camp roofs are now at y=3–4 with supports and two-node interior clearance.
Independently inspected all six regenerated actual-texture gallery images;
the shelters now have a recognizable raised silhouette and the compact
village/outpost compositions stay inside their pads. These are blueprint
renders, not evidence of live NPCs or separate root nodes.

Reviewed the revised portable fixture and reported LuaJIT result
`r14_poi_v2 / 18 / 76032 / 1649985962`; no runtime test was duplicated.
The fixture covers ordered cell coordinates/names/param2 in its digest, every
footprint, root reservation, house/socket reachability and roof height.
Production story records now name the same six village/outpost/camp settlement
keys as the roster and their three strict quest socket ids.

Corrected production SHA-256:

- Shared builder: `e8e0f1a75e43cc4d2955c1773bbc11c04d05c1d35d70c4859cbdbbd766415ea6`.
- Display definitions: `f5fed8d9e116a24a17ef307570d1b82fa89e83c4871debfb121203d0da3ac86e`.
- Mapgen init: `6492b261b734c3e48db38f8d1f8e7c61515b9966578087e8ddd9f6117ca8d642`.

No remaining confirmed Critical, High or Medium finding in this review scope.

## Final visual polish focused review

The subsequent bounded visual delta was independently reviewed from source and
all six regenerated gallery images. The builder adds connected alternating
slab/full-block gable courses, timber corners and headers, windows, small side
benches/work tables and raised watch platforms with rails. No authored
footprint, functional root or quest socket moved. The roof-course arithmetic
keeps the outpost roof below y=8 and all horizontal overhangs inside the
previously reviewed half-open cores; furnishings leave the central paths and
three-wide house entries clear. Camp roofs retain two-node clearance and the
captive's separate accessible corner. The renderings show continuous stepped
roofs rather than the former separated slabs.

Verdict remains **PASS**, with no new confirmed Critical/High/Medium findings.
Final shared-builder SHA-256 superseding the earlier corrected candidate:
`9ec5a39106ed94b55f2dab0ba4d718acd4c2c0686ba3f9231153020a988c1c6b`.
Reported final portable LuaJIT result:
`r14_poi_v2 / 18 / 76032 / 1859979146`. No interpreter/native execution was
duplicated for this review. Final native manifest/planner evidence and final
interpreter parity must refer to these final bytes.
