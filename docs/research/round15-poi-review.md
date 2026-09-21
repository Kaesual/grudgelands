# Round 15 POI composition — independent review

Date: 2026-09-21. Reviewer: native Sol. Reviewed implementation commit
`f36b57c6` (integrated as `4dc4f842`), independently of the Astra author.

## Focused landing-path follow-up

The POI author's later self-audit reopened two concrete Medium findings in the
shared `r14_poi_blueprint.lua` lookout path. Focused independent review has now
verified both corrections.

- A roofed height-4 lookout calls `canopy(..., h + 2)`. Its front beam is then
  placed at y=6, directly in the second clearance cell above the y=4 deck at
  the inward ladder landing. The top ladder step can therefore reach a landing
  with only one node of standing space. Moving that beam to the existing y=7
  roof course restores two-node clearance without changing the footprint.
- Copperfell Outpost overlays `lookout(-4, 3, 2, 3, false)` and
  `ruin(-4, 3, 2, 2)`. The ruin's front arch occupies y=4 at x=-5..-4,z=1,
  including the lookout ladder's inward landing at x=-4,y=4,z=1. The landing
  is blocked even though the generic three-dimensional walk does not require
  lookout-deck reachability.

The focused KAT fix inspects the top of every ladder run and requires a solid
deck below the inward landing plus air at both the feet and head cells. That
single geometric invariant catches both defects and covers every roofed and
unroofed lookout, rather than pinning assertions only to Copperfell or one
height.

The frozen correction implements that invariant for every topmost ladder cell.
Roofed-lookout crossbeams move into the already occupied roof course at h+1;
the four affected outpost footprints and roof profiles remain unchanged.
Copperfell's coincident ruin uses an open front, removing the arch cells that
crossed its height-3 landing while retaining its side and rear broken walls.
The refreshed Copperfell overview and all-18 contact sheet show the open,
legible ladder approach. Development evidence records
`r15_poi_v1 18 76032 972310740`.

Focused frozen hashes:

- `r14_poi_blueprint.lua`: `f150055275f8d35fdd3bc7ef2ed68263bc201beccec2fad640b37cf8a7dca5a5`.
- `poi_micro_kat.lua`: `bac3fb700100182041a79d9a63950b4c462d471eb648227c9b6ca517f874ead0`.

## Final evidence acceptance

The frozen final evidence retains both reviewed hashes above. Its 17-file Lua
5.1 parser/static gate passes, and the four-fixture PUC/LuaJIT outputs have the
same canonical SHA-256
`8de2aaf7c4080ad0d423f36177318a338c66cae5f72f8992cbc3bc14ab509f46`;
the POI digest remains `r15_poi_v1 18 76032 972310740`.

The isolated native evidence uses the actual manifest and exactly three actual
planner calls for exactly three generated chunks. It checks 12,670 authored
cells across Starbough Village, Copperfell Outpost and Copperfell Bandit Camp,
preserves the outpost/camp root nodes, and observes five live NPCs. Starbough's
three include the existing giver and the new `quest_local` giver, so the new
village-giver socket-to-runtime seam is exercised rather than inferred from a
fixture registry. Its complete 2,045-file production snapshot matches the
final repository payload. This satisfies the required native three-chunk and
new-giver integration boundary; the GUI/terrain limits below remain.

## Initial frozen-candidate review

Clean after focused correction review. Calibration: the original review found
0 Critical / 0 High / 0 Medium / 0 Low; the follow-up found 0 Critical / 0 High
/ 2 Medium / 0 Low, and both Medium findings are resolved. No findings remain.

The review covered the production change in
`mods/MAPGEN/grug_mapgen/wp40/r14_poi_blueprint.lua`, its bounded fixture and
static evidence, all 18 individual overview renders, the 18-location contact
sheet, and the three required eye-level pilot sheets. At that initial freeze, production and
fixture hashes matched its source receipt; the initial
LuaJIT result was `r15_poi_v1 18 76032 961696073`.

## Visual and design assessment

All 18 POIs have materially different occupied-cell compositions, readable
arrival space and a dominant local feature. The villages use unequal buildings
and off-centre work areas rather than the former four-hut symmetry. Outposts
have one practical lookout/watchhouse plus stores or shelter. Camps read as
occupied work, farm, ruin, freight or sleeping sites and retain a legible open
captive corner instead of another pavilion.

The six cultures differ in silhouette as well as palette: Copperfell is low,
heavy workshop masonry; Goldmead uses broad loam/slate work buildings and a
garden edge; Starbough uses narrow steep roofs and covered walks; Mournfen uses
flat dark buildings, ruins and raised stores; Redtusk uses broad low courts and
strong timber/masonry frames; Raincall uses raised jungle structures and long
canopies. The three pilot sheets confirm useful eye-level spaces: Goldmead's
arrival, workyard and furnished hall; Redtusk's climbable tower and dry store;
Mournfen's accessible ruin and open captive corner. Renderer limitations are
stated accurately: authored cells and real textures/nodeboxes are shown, while
runtime NPCs, functional roots and surrounding fitted terrain are absent.

## Technical assessment

- Every authored cell stays in the existing half-open fitted core: 24 by 24
  for villages/camps, 16 by 16 for outposts, and y=0..8. No anchor, fitting,
  terrain, road or protection contract changed.
- The actual `r7_settlement.prepare` consumer validates the canonical cells,
  bounds and palettes for all 18 adapters. The registry fixture rejects
  unregistered node names, including the six existing POI display nodes.
- The reserved outpost/camp anchor root remains solid at y=0 and clear at
  y=1..3. The production writer therefore preserves the existing banner/fire
  written at y=1. Broad open ground remains inside the camp's 12-node spawn
  radius; structures do not seal the camp fire or the random standable-spot
  search area.
- Four-way ground reachability proves that any existing fitted-core spur side
  connects to the arrival. A separate bounded three-dimensional walk reaches
  every house interior, including the Raincall stilt entrances. Canopy entry,
  ladder continuity/support and authored light support receive direct checks.
- Existing `quest_steward`, `quest_scout` and `quest_captive` identities remain
  present. Each village adds reachable `quest_local` with role `quest`.
  Captives remain at (10,1,10), outside the hostile spawn disk.
- The 18 material-independent occupied-cell silhouette digests are unique, and
  every location contains at least two recorded structure dimensions. Visual
  inspection confirms that these numeric distinctions correspond to useful
  layouts rather than incidental decoration differences.
- Plain Lua 5.1 parsing, `SETGLOBAL` inspection and five source sweeps are
  recorded for the frozen production and fixture bytes. Production has no
  global write; the fixture's sole write is its declared `core` stub. No new
  callback, persistence, hot-loop, protection or player-data path is present.

## Remaining runtime gate

The committed renders and bounded fixture cannot show final terrain blending,
engine node lighting, NPC occupancy, camp spawn choices or in-client climbing.
After the coordinator's actual manifest/planner/native integration gate, the
fresh-world GUI check should enter Goldmead's hall and shed, climb Redtusk's
lookout, inspect Mournfen's ruin/captive corner, speak to both village quest
givers, observe a populated camp, and verify one Raincall raised entrance.
