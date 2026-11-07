# Round 70 DESIGN — pass 4

**User decision, 2026-11-07: the page stands; radius 56 for all six capitals
and every per-place recommendation is accepted.** This pass proposes only the
Kezamba and Lethariel lake amendments. The other ten places keep their accepted
layouts.

Historical note: radius 48 was considered and not selected; its compact
alternatives are retired.

Branch: `r70-design`; starting commit: `c3612f30` (including the coordinator’s
small page-text fix). Game-code base: `55aa7708a2d6b28fbd3c87ad3e47b72cfea24a0d`.
The [page](page.html), [claims ledger](claims.md), and generated schedules are
updated. The two amendments still need the user’s decision and the coordinator’s
independent review; the earlier acceptance is not acceptance of these additions.

Only `tools/r70_design/` changes. Classification: **compatible, tools only**.
Implementation changes world generation and joins Round 70’s declared **map
reset**. No game source, version, world, server, other worktree, merge or push was
changed. No other agent was used in this pass.

## Recommendation and return

Move the **lake chains north**, keeping both city anchors fixed. This is
geometrically a core moving south relative to its lake, without moving the city’s
world origin. Water height stays two nodes below the civic reference. Capsule
radii, depths, ids and the whole chain remain; neither lake is shrunk or filled.

| Capital | Lake displacement | Dry columns at the same expanded boundary, before → after | Returned land | Building consequences versus the accepted plan |
|---|---|---:|---:|---|
| Lethariel | (0,+14), north | 10,894 → 12,153 | **+1,259** | Six templates move: three gates, both colonnades and the mere shrine. Both colonnades survive instead of being retired; this does **not** reduce relocation work. |
| Kezamba | (0,+18), north | 9,280 → 10,616 | **+1,336** | **Five instead of six** templates move, including the moot house. Both western houses and the original waystone plaza stay. |

These counts use the inclusive authored boundary **±57 = 115×115 = 13,225
columns**, not the nominal 112-node profile width. Today’s inclusive ±49 has
8,236 dry columns in Lethariel and 6,913 in Kezamba. Comparing the same expanded
boundary isolates the lake contribution from the already accepted core growth.
“Dry” includes streets and occupied land; it does not mean free building plots.
The counts agree exactly between the authored-water function and fitted terrain
on all three measured seeds. They depend on an **unbuilt lake change**.

The [candidate measurements](data/lake-metrics.json) show why these modest shifts
were chosen. At 13 north, Lethariel’s colonnades are dry but 11 cells in their
one-node surrounding buffer touch water; at 14, none do. At 16 north, Kezamba’s
new stable is dry but four buffer cells touch water; at 17, one does; at 18,
none do. Smaller 8/12-node candidates still put written building columns over
water. These are minimum integer north shifts **for these placements and this
one-node buffer**, not a global optimum across every possible layout.

## Lethariel

The accepted east-facing castle remains at **(−52,−51)…(−18,−7)**. Its court
remains south-west of the crossing. Both colonnades move **51 north**, to anchors
(−9,20) and (6,20), framing the northern approach. The mere shrine moves **14
north**, to (16,26), with its keeper and shrine sockets. The star hall and sacred
grove stay. The three gates retain their accepted eight-node outward moves.

The crown-lake tip moves from **(0,22) to (0,36)**. Recut `MERE` through ±57,
including `MERE_FIRST=36`; move `CAUSEWAY_FROM` to 36, and the quay head from
z=18…21 to **32…35**. The head narrows from x=−6…6 to **−3…3**, because its former
width would cut the relocated colonnades. The page reserves a three-node marble
quay outside the one-node shore margin; its north avenue continues as a
seven-node bridge band. The current quay loop steps inward into the shore margin,
so only its first column passes `dry()`; the proposed three-column band must be
written outward instead. This is a small writer change in addition to the mask
and coordinate changes. The real planner continues to pin the `mere` district
toward `lethariel_crown_lake`. The core apron and planner continuation must form
a complete north crossing to the far shore without duplicate writes; today’s
core cells and landing detector do not certify this future connection.

Quay idles, the sweep point, the two quay spare sockets and the quay patrol move
with the shore; the complete schedule records every point. Re-author their
benches and sweep ground, the quay head and the shore planting. The inland work
court remains; do not translate every north-side feature blindly.

**A better castle site?** A central northern box (−22,10)…(22,44), with a one-node
water buffer, needs the lake **24 north**, not 14. It also intersects the statue,
star hall, mere shrine and western bough house before adding its court. That
bounded land test gives no reason to spend the larger displacement and extra
public-quarter moves. Keep the accepted western castle.

## Kezamba

The accepted north-facing castle remains at **(5,−52)…(49,−18)**. New placements
are measured from today’s actual exported template anchors:

| Template | Today | Proposed | Displacement |
|---|---|---|---|
| stable | (35,−45) | (3,3) | (−32,+48) |
| granary | (6,−16) | (−29,4) | (−35,+20) |
| lane_house | (36,−24) | (36,−14) | (0,+10) |
| gate_house_south | (24,−16) | (−12,−29) | (−36,−13) |
| moot_house | (−24,30) | (−24,45) | (0,+15) |

`west_house` and `shore_house` now stay; `travel_waypoint` remains **(−38,−24)**
with its existing plaza and mailbox. The moot house still straddles the lake;
all four western stair-landing columns remain dry, and its written envelope ends
at z=55. The quay walk bends west to its landing instead of entering through its
southern rail. This is still a 2D route reservation, not a tested ascent.

Recut the entire lagoon mask and its shore/pad helpers from the shifted chain;
the ravine remains empty. The first water in the five-wide north avenue now
occurs at **z=30**, with the axis itself wet from **32**. Keep this northern
boardwalk and the moot-house piers. The east avenue becomes dry within the core:
replace its former deck stretches with ground paving there. The lake remains a
substantial north-eastern part of the core, with a quay and fishing places.

The fishmonger, quay stall, two anglers and southern shore points move 18 north.
`cenote_fish_3` instead goes to **(−10,44)**: a direct translation hits the moved
moot house’s rope. Its new spot is dry with water within two nodes. Northern
quay idles use the moot house’s 15-node move or the explicit end of the new walk.
The eastern crossing bench moves to (7,−4) to clear the stable. Every socket,
including unchanged ones, remains in the [schedule](data/socket-schedules.json).

**A better castle site?** A north-eastern box (5,5)…(49,39) needs the lake **49
north** to clear the footprint and its one-node buffer, before reserving a court.
The small displacement is useful for neighbours, not another castle position.
Keep the accepted southern terrace.

## What must stay coupled

`water_authored.lua` uses **fixed horizontal capsule points**. Its `anchor`
field supplies the fitted reference for **water height**, not a horizontal
parent transform. Therefore moving a capital anchor alone would not carry the
lake with it. Moving that anchor would also move fitting, road endpoints and the
district frame; offsetting only a civic core would introduce another origin in
its writer, bounds, sockets, avenues and planner sampling. Moving the chain is
the smaller honest change.

The tools transform the real water source in memory, moving only the chosen
capsule z coordinates and expanding each calm square from half=47 to **57**,
still centred on its unchanged city anchor. Both comparison runs expand that
square, so their difference isolates the displacement. Outside the square the
existing world-coordinate warp remains: not every distant shore cell is a rigid
translation. Lake height, depth, radius and ids stay unchanged. Exact old/new
chain points appear on the page.

Implementation must change these together:

- The two water chains, their calm/warp and bank-suppression extents, `MERE` and
  `kezamba_lagoon`. The old masks agree **column for column at ±47** with the
  source water (1,393 / 2,645 wet columns); the exporter asserts this. The new
  [wet masks](data/lakes.json) come from that source function through the larger
  boundary, not an extrapolated finite table.
- `capital_planner.lua`’s fitted samples, shore distance and district pinning,
  the outer wall runs/ends at water, avenues, bridges and quays. The real planner
  already reads the new water in the experiment. The future core’s changed
  boundary, north bridge/deck and dry east landing must also reach
  `r7_capitals.core_landing`; today’s 46…49 scan remains in this study.
- The core dry-edge curtain/palisade runs, deck posts, rails, marble/basalt quay,
  landing heights, fish/idle/work sockets and their furniture, patrol routes and
  the ordinary/royal guard distinction. Do not leave old quays inland or fill
  water to recover a walking route.
- `settlements.md`: the core-size rule, the dry-edge boundary table, Lethariel’s
  lake/quay/north-avenue/mere-precinct text, and Kezamba’s non-flat core, stilt
  hall, anglers, quay and shore-market text. The `world_zones.md` duplicates and
  coordinated radius edits named in the existing ledger still apply. This
  design-only lane does not rewrite those runtime design owners in advance.

## Real planner evidence and its limits

The exporter **can run the real planner with shifted water**. Six final paired
runs use the exact existing fleet seeds below. Both sides set all six
`civic_width` profiles to **112**, planner CORE/GATE/KEEP to **56/57/60**, and both
lake calm squares to half=57. `lake0` retains the chains; `lake_shift` moves them.
The original six exports and 40-seed checker receipt are retained as historical
evidence. They do not validate the shifted lakes.

| Capital | Seed | Today | 56, lake unshifted | 56, lake shifted |
|---|---|---:|---:|---:|
| Lethariel | `12345` | 45 | 44 | 45 |
| Lethariel | `3684797457838814663` | 44 | 43 | 42 |
| Lethariel | `17713522922938657774` | 40 | 39 | 40 |
| Kezamba | `12345` | 51 | 50 | 48 |
| Kezamba | `3684797457838814663` | 49 | 49 | 49 |
| Kezamba | `17713522922938657774` | 51 | 49 | 50 |

All required plots are placed, with no load failure. **More core land does not
guarantee more district plots.** Against the unshifted 56 control, an unrouted
`ring2/q2` appears for Lethariel on `3684797457838814663` and Kezamba on
`17713522922938657774`; it disappears for Lethariel on
`17713522922938657774`. The existing `ring1/q1 ring2/q1` labels remain. The page
exposes all reported labels, including these costs.

**Still unbuilt:** the new core cell lists, masks in the game, new landing scan,
castle architecture, piers, quays, final bank geometry, headroom and route seams.
The real planner study deliberately uses today’s authored core cells and landing
detector. Consequently its plot counts are measured sensitivity results, not
final-build certification. The dry-area counts and dry castle footprints are
fully measured in that terrain; final walkability is not.

An exploratory 17-node Kezamba run was rejected after the buffer check; its
scratch outputs are in `/tmp/r70-lake17`, not inputs to the delivered page. Only
the three changed-water runs were repeated for the 18-node proposal; the paired
unshifted runs were reused. The queue used at most two idle LuaJIT workers, each
with its own output; no server or voxel generation was run. No performance claim
is made.

## Verification and next gates

- `python3 tools/r70_design/build.py` and `verify.py`: 12 plans, 24 equal-scale
  SVGs, 659 socket rows, eight retained collision regressions, 93 claim links,
  room/wall budgets, three paired lake seeds, exact mask/terrain counts, dry
  template envelopes, shore buffers, moot-house landing and fishing reach.
- `bash tools/check_lua.sh tools/r70_design/export.lua tools/r70_design/lake_variant.lua`:
  plain Lua 5.1 syntax, globals and sweeps pass; execution used LuaJIT.
- Light/dark SVG rendering with `inspect_svg.py`; the two changed pairs were
  visually inspected. The other ten places’ layout definitions, 20 SVGs and
  socket rows are compared against `c3612f30` and remain unchanged.
- Local Markdown links, Python/JavaScript syntax, embedded data, numbered ledger
  wording and `git diff --check` checked. No runtime fixture, engine boot or
  full fleet is claimed for this tools-only amendment.

Browser layout/events and phone behaviour remain unverified (the earlier browser
sandbox limitation remains); desktop/web runtime tests belong to the user. Before
implementation is accepted: coordinator review, the two lake decisions, the full
building-template gate and **`tools/seed_fleet/run.sh full`**, then the user’s
GUI checks for every arrival side/mailbox, public services, shore fishing,
quay/deck/stair access, dry wall ends, north crossing, all patrols, and throne-room
combat/chase/reward behaviour on desktop and web. Preserve the accepted shared
45×35 footprint, 35×23 hall reservation, y≤40 cap and existing encounter rules.
