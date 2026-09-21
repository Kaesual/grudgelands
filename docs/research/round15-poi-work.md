# Round 15 POI composition work

Date: 2026-09-21. Implementer: native Astra. Status: implemented; independent
review and coordinator final integration gates pending. Scope: the existing six
villages, six outposts and six camps. No new anchors, terrain rules or professions.

## Authored compositions

| Region | Village | Outpost | Camp |
| --- | --- | --- | --- |
| Copperfell | Long west workshop, transverse south dwelling, north workyard | Low masonry lookout and long guard shelter | Occupied broken workshop, open stolen-tool cache |
| Goldmead | Slate/loam granary with brick chimney, turned dwelling, straw work shed and fenced garden | Roofed tower and side office | Broad barn beside an L-shaped ruin, separate patched stores |
| Starbough | Unequal narrow steep-roof houses facing the communal walk | Slender raised lookout and open stores | Long poacher shelter, shallow hide awning and processing rack |
| Mournfen | South wax workshop, north dwelling and candle-tended memorial | Low flat watchhouse, observation niche | Single command canopy within broken enclosure, open raised stores |
| Redtusk | Broad east house, low north annex and west cooking court | Timber lookout, staggered palisade and guard stores | One broad caravan shade roof, gathered freight and sleeping places |
| Raincall | Raised north communal house/veranda, turned southwest dwelling | Roofed lookout and dry equipment niche | Long main canopy with two staggered small sleeping shelters |

Every village adds `quest_local` at **(-2,1,-2)**, role `quest`. Existing
`quest_steward`, `quest_scout` and `quest_captive` IDs and coordinates remain
unchanged. Captive corners are open enclosures, not another repeated pavilion.
The resident work socket moves one node to clear the larger Goldmead hall.

The builder retains its existing file and adapter identities. All cells,
overhangs, supports and clearances remain inside the original **24×24** or
**16×16** footprint and **y=0..8** authorized volume. Existing functional roots
remain empty at y=1..3; the writer still owns them and their protections. Camp
captives remain at (10,1,10), outside the existing 12-node hostile spawn disk.
Current core fitting, world anchors, roads and immutable functional protection
are unchanged. Ordinary building materials remain ordinarily mutable.

## Visual evidence

[All 18 locations](../../tools/r15_poi/gallery/all18.png) and the individual
region PNGs show actual blueprint cells with the WP13 texture renderer.
The pilot sheets include [Goldmead arrival/workyard/interior](../../tools/r15_poi/gallery/goldmead_village-eyes.png),
[Redtusk arrival/stores](../../tools/r15_poi/gallery/redtusk_outpost-eyes.png), and
[Mournfen arrival/ruin/captive corner](../../tools/r15_poi/gallery/mournfen_bandit_camp-eyes.png).
The implementer inspected the rendered contact sheet and all pilot sheets.
The coordinator requested and assessed material/interior polish and a second
composition pass, then approved the visual direction for independent review.

Eye views use Blender, the existing WP13 texture/shape machinery and actual
registered fixed decor nodeboxes. No walls or roofs are removed. Lighting is an
approximation at the authored lamp positions. Runtime NPCs, functional camp
fires/banners and surrounding terrain are omitted: these are source geometry
views, not native-engine screenshots. Non-cubic overview furniture remains the
WP13 renderer's approximation. Temporary textures and geometry exports live in
`/tmp/grug-r15-poi-render`, never in committed evidence.

Reproduce from the repo root:

```sh
python3 tools/r15_poi/render_gallery.py
blender -b -noaudio -t 2 -P tools/r15_poi/render_eyes.py
python3 tools/r15_poi/render_gallery.py --eye-sheets
```

## Bounded validation

- `tools/r15_poi/poi_micro_kat.lua`: all 18 actual settlement adapter/prepare
  consumers, registered node names, exact fitted bounds, canonical cells,
  material-independent shape distinction, varied structure dimensions,
  root support/clearance, all four core-edge approaches, reachable NPC sockets,
  house interiors including raised entrances, canopy entry headroom, ladder
  support/continuity, lamp support, and captive spawn separation.
- `tools/r15_poi/evidence/development.tsv`: final development LuaJIT result.
- `tools/r15_poi/evidence/static.log`: plain 5.1 parser, SETGLOBAL inspection
  and all five source sweeps on the changed production and tool Lua files.
  The only global write is the harness's explicit `core` stub.
- `tools/r15_poi/evidence/source.sha256`: frozen production/fixture identity.

No intermediate PUC execution, seed fleet or native-engine run was performed
by this lane. The coordinator owns the single final PUC/LuaJIT parity process
and the bounded actual manifest/planner/native integration gate. This fixture
proves core-edge access; actual outside spur terrain is checked by that existing
integration boundary, not by inventing a terrain model here.

## Handoff and runtime check

Independent review must assess actual compositions and walkable arrival/interior
paths as well as the code. The final completion record and calibration fields
belong to the coordinator after review; implementation did not self-approve.

Runtime plan: visit the three pilots in a fresh world, enter the Goldmead hall
and shed, climb Redtusk's lookout, inspect Mournfen's ruin and captive corner,
and speak to both village quest givers. Verify camp combat/fire and outpost
banner behavior, ordinary shell digging, lighting and approach continuity.
Check Raincall's raised entrances and one remaining village for cultural contrast.

## Final raised-landing correction

Final inspection and independent Sol follow-up confirmed two Medium access
issues: roof crossbeams blocked the head cell on four roofed outpost lookouts,
and Copperfell's overlapping ruin arch blocked its landing foot cell. The
roof beams now occupy the existing roof course one node higher; Copperfell's
front arch is omitted while side/rear ruin walls remain. Mournfen, villages,
camps, world anchors and terrain rules are unchanged.

The bounded fixture now inspects every topmost ladder's inward landing for
solid support and two free standing cells. Final canonical output is
`r15_poi_v1 18 76032 972310740`; source hashes, affected outpost views, the
contact sheet and Redtusk eye view are refreshed. Independent follow-up and
native three-chunk integration passed; see round15-poi-review.md and
round15-integration.md. No broad world population or extra PUC suite ran.
