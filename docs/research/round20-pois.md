# Round 20 authored POI implementation

Date: 2026-09-24. Status: implementation candidate; independent review and the
coordinator's consolidated final runtime gate are pending. No main merge,
synchronization or remote push is claimed here.

Creative authority: [70 scene cards](../planning/round20-content-cards.md) and
[stable content interfaces](../planning/round20-content-cards.json).

## Delivered candidate scope

All70 remaining anchor art slots are registered through the existing
`r7_settlement.roster`, bringing its total to100 existing world anchors. No new
anchor, camp spawner, guard roster, rare, dragon or resource root is introduced.
The42 inhabited scenes contain105 actual buildings/work shelters: six villages
with four or five varied premises,18 outposts, six frontier bandit camps, six
peaceful mines, four Mirefolk camps and two apex camps. The28 open compositions
are16 battlefield remains, two dragon surrounds and ten named-rare scenes.
Captain Bonerattle's two cards remain two scenes on the same existing migration.

`r20_poi_catalog.lua` names every anchor, individually places each building
footprint and selects its local narrative props. Layout coordinates are authored
per site, with differing footprints, roof heights, entry sides and service
forms. `r20_poi_blueprint.lua` shares structural parts (gabled/flat/shed roofs,
roofed work areas, braced mine mouths, furniture and small scenery), not whole
village layouts. Troll premises have a raised floor and two-node entry steps.
Shipwright shelters contain fixed hulls with a usable side aisle; no travel,
vehicle spawning or teaching service is added.

The existing18 regional compositions stay untouched. Existing starts receive
only a distinct cook standing place and its own public oven beside the Cooking
trainer; each capital receives a separate cook at its existing Cooking service
plot. Existing capital quest shells remain at their existing sockets and Q3
binds their envoy identities. All30 new regional peaceful hosts use the frozen
`r20_anchor_NNN/quest_host` interface. The NPC placement consumer recognizes
that role identity and ignores actor-free scenery records.

## Projection and protection

The original production sequence in `r7_successor.lua` remains P9G, world
content, anchor activation, then authored settlements. New cells therefore
reach the same opcode37 writer after terrain/anchor content, with normal owner
clipping and lazy identity-checked reconstruction. No second mapgen callback,
ABM, LBM, timer or terrain pipeline was introduced. Each blueprint exports a
sorted unique cell stream and complete sorted used-node palette.

All buildings, roofs, props and clearance cells stay inside the actual current
core: village24, outpost/frontier-bandit/Mirefolk/clash16, peaceful mine20,
dragon/apex32, rare12. The existing fitted foundation at y0 is retained; art
never excavates below it. The central5×5 area has three nodes of actor clearance.
Every new profile preserves the existing root at local(0,1,0); hostile camps
keep their existing local standable-position spawner. Apex resource offsets
begin45 nodes from the anchor, outside the32-node art core. No resource socket,
road anchor, fitting width, blend width, protection recipe or claim reservation
is changed. Mine/adit scenery provides a roofed workplace, not new underground
excavation or renewable resources.

The documented frontier-bandit24/core16 discrepancy remains open deliberately:
two real buildings fit the current16-node core. Completing these art slots does
not settle the separate larger-envelope design discrepancy.

Start cook ovens publish `cook_oven` as `role=public_station`, tagged `furnace`,
so the existing public station consumer supplies normal current-version
activation and interaction. The regional decorative bakehouse has a masonry
baking niche, avoiding a bulk-placed uninitialized interactive furnace.

## Validation performed and pending

Performed: source/footprint inspection, plain Lua5.1 parser on all eight changed
Lua files (including the tool fixture), explicit `SETGLOBAL` inspection and all
five required sweeps, with no hits; `git diff --check` clean. Static footprint
inspection caught a mine corner intruding into central clearance and nine prop
bounding-box contacts; these were corrected before candidate freeze. Furniture
now follows each doorway's facing, and adit rear walls stand opposite their
entry. No Lua runtime, engine, world generation or historical suite was run in
this lane before the consolidated freeze.

Prepared [final JIT gate](../../tools/r20_pois/README.md): one real production
runtime/strict manifest construction with the current MTS and100-profile roster;
all70 emitted compositions, actual node registrations, building counts,
reachable interiors, two-node entrances, central/host clearance and perimeter
connection;12 cook positions and six existing envoy sockets. Nine representative
families each use two adjacent real planner slices, followed by the actual
settlement projection tail, comparing every cell and the reserved actor root.
The sink is captured: this is real planner/projection evidence, not full VM or
engine execution. Source inspection establishes its ordering after terrain.

The same runner exports15 selected actual voxel streams covering all nine
families and multiple cultures. The dependency-free Python renderer creates
SVG top-down/isometric views and a local HTML gallery. These are schematic
geometry views with node-name tooltips and material hints, not engine-textured
screenshots or a claim of GUI acceptance. The five-minute final gate cap and
single-final PUC/JIT micro-KAT policy remain unchanged; this large construction
fixture is JIT-only and is not appended to the portable PUC process.

Final evidence, any corrections and independent review results must be appended
before delivery. Quest catalog/reward/pacing implementation belongs to Q3 and
is not claimed by this art receipt.

## Calibration and user acceptance

Implementing model: GPT-6 Astra. Independent reviewer: pending. Critical/High
findings: not yet assessed. Corrective review rounds:0. Elapsed time: unknown.

User runtime plan after review/merge/sync: visit a second village, outpost,
frontier bandit camp, peaceful mine, Mirefolk camp, clash site, island arena/camp
and rare scene. Walk every doorway and work aisle; confirm actors and resource
access are unobstructed. Inspect Whitebridge/Whisperreed shipwright hulls. Speak
to separate cooks and trainers in a start and capital, use the cook's oven,
and follow the level10 capital introduction to the existing envoy.

## Construction corrections

The first central final construction exposed an anchor034 flower extending into
the central clearance; independent source review also found the missing anchor077
slab dispatcher. The flower pair now sits one cell west, and the tombroad scene
has its authored three-cell slab remnant. A specifically authorized builder-only
LuaJIT reproduction constructed all70 profiles successfully, exercising every
prop dispatch, emitted-cell envelope assertion and central5×5×3 clearance.
No manifest, planner, engine or PUC runtime was repeated in this correction.
Both changed Lua files pass the plain5.1 parser, SETGLOBAL and five sweeps.
Full integration and doorway evidence remain owned by the central final run.

The subsequent central construction reached anchor089 and exposed its sample
rack immediately outside both doorway cells. Moving the rack two cells east
keeps the authored assay detail while opening the entrance. A second authorized
builder-only LuaJIT check reused the exact final-runner open/reach/BFS assertions
and real registered node walkability across all70 profiles:105 interiors,
two-cell entrances, perimeter access, central clearance, registered names and
cell bounds passed, including the anchor090 counterpart. It loaded fixture node
definitions from the primary checkout because worktree reference submodules are
empty, and used the corrected worktree builders; no runtime.build or planner
was invoked. The changed catalog passes all static gates.

## Visual pathway correction

Coordinator review of the actual-cell gallery rejected the universal full-core
three-wide paving cross. The revised builder retains cultural ground throughout
open encounter scenes. In inhabited sites it places a small offset, clipped
court, narrow bent connections from the actual building thresholds and one
broken arrival trace toward the first workplace. Elf/troll/frontier camp paths
have deliberate grass breaks. Foundations and every above-ground cell remain
unchanged; no layout, socket, reservation or terrain envelope expands.
The specifically authorized pure-builder circulation check again passed all70
profiles and105 interiors/entrances with real walkability; parser, SETGLOBAL and
five sweeps are clean. Final planner construction and refreshed visual
acceptance remain with the coordinator.
