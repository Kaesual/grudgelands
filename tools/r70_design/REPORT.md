# Round 70 DESIGN — pass 5

**User decision, 2026-11-07: the page stands; radius 56 for all six capitals
and every per-place recommendation is accepted.** This pass corrects only the
Kezamba and Lethariel lake amendments after the independent pass-4 check.
The other ten places keep their accepted layouts.

Historical note: radius 48 was considered and not selected; its compact
alternatives are retired.

Branch: `r70-design`; starting commit: `4146eb8b`.
Game-code base: `55aa7708a2d6b28fbd3c87ad3e47b72cfea24a0d`.
The [page](page.html), [claims ledger](claims.md), and generated schedules are
updated. The two amendments still need the user’s decision and the coordinator’s
independent re-check; the earlier acceptance is not acceptance of these additions.

Only `tools/r70_design/` changes. Classification: **compatible, tools only**.
Implementation changes world generation and joins Round 70’s declared **map
reset**. No game source, version, world, server, other worktree, merge or push was
changed. No other agent was used in this pass. The
[pass-4 checker findings](data/design-check-pass4.md) were checked at their
source; its planner measurements were reused, not rerun.

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

The distances are small relative to the nominal 112-node width: 14/112 =
**12.5%** and 18/112 = **16.1%**. The change in the water share is large:
Lethariel's wet core columns fall **2,331 → 1,072 (−54.0%)**, Kezamba's
**3,945 → 2,609 (−33.9%)**, at the same ±57 boundary. The complete capsule
chains keep their radii and lengths; less water lies inside the core. The outer warp still
applies, so no unchanged total area of the final warped lake is claimed.

The [candidate measurements](data/lake-metrics.json) show why these shifts
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
quay outside the one-node shore margin. The current quay loop steps inward into
the shore margin, so only its first column passes `dry()`; the proposed
three-column band must be written outward instead.

**There is no north crossing today or in this proposal.** `lethariel.lua:108`
`pad()` leaves the seven-node band empty. `r7_capitals.lua:195` `core_landing`
finds no landing, so `capital_planner.lua:1395–1420` starts that avenue on dry
shore. On seed 12345 the starts round to **(−28,80) today**, **(−30,86) in
lake0**, **(−42,62) shifted**. All three paired exports show the same mechanism.
The pass-4 crossing line and deck reservation are removed from the drawing.
The `CAUSEWAY` comments in `lethariel.lua:99–107`, the causeway comment in
`water_authored.lua:201`, and `settlements.md:400` are stale; the later CAPITALS
lane must correct them rather than treating them as built geometry.

The page asks about a **separate new crossing**, not included in the plan.
It would need a deck and a new landing scan, a core/planner seam and a bank
connection: at least **34 nodes west to shore on z=57**, or **131 along the
north axis**. These are geometric lower bounds from the water function, not a
measured build, route or cost estimate; the north-axis distance includes the
outer warped shore. There is no promise of a walkable connection.

**The mere precinct drifts inland.** The real planner keeps the `mere` district
pin toward `lethariel_crown_lake` (`r7_capitals.lua:178–184`), but does not fix
its distance from shore. The checker reports plot centres **19–32 → 32–44
nodes** off shore on two seeds. A separate spot check against the nearest
integer wet column of the complete water function (outer warp included) gives:

| Seed | lake0: three plot centres, distance range | lake_shift: distance range |
|---|---:|---:|
| `12345` | 25.5–31.2 | 38.0–46.4 |
| `3684797457838814663` | 17.7–34.7 | 37.6–44.6 |

The [per-plot receipt and method](data/shore-check.json) retain this spot check.
It excludes the two dressings; it uses existing exported plot centres and
water-indicator samples, no new planner run. The checker does not record its
distance estimator or seed pair; this explicit spot check confirms the drift
(about **18–35 → 38–46** here).
The page shows both and asks whether the farther-inland precinct is acceptable.
The pin is **not tuned** in this pass.

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
boardwalk and the moot-house piers. **The east boardwalk is lost:** avenues over water fall **two → one**.
`settlements.md:438–440` explicitly describes two. Today's composition contains
**627 non-template deck, rail and pier cells over water**, comprising 386 timber
deck, 133 fence and 108 basalt cells; **263** of those are on the east avenue.
627 is the total for both avenues, not the east-only loss. The shifted east
avenue becomes ground paving, a character cost now stated in its question.
For about 12 nodes north or more, the lake misses the entire five-wide east
avenue; at 18 even its axis has no wet column inside the core (today water
starts at x=18 on z=0).

A **four-node shift** retains water under both avenues (east axis from x=28).
It returns **300** dry core columns, **1,036 fewer** than the 18-node proposal.
At the proposed stable position **101** written columns remain wet (**131**
with its buffer). Keeping both boardwalks therefore means finding another
stable site and revising the layout; the five-template-move result is not
certified for the smaller shift. The page makes that alternative explicit.
The lake remains a substantial north-eastern part of the core, with a quay and fishing places.

The fishmonger, quay stall, two anglers and southern shore points move 18 north.
`cenote_fish_3` instead goes to **(−8,41)**, facing east into water at
**(−7,41)** at reach one. The pass-4 position (−10,44) looked through
`cenote_fish_2` at (−9,44), the same near-obstacle fault documented in
`kezamba.lua:755–758`. The new row clears the other anglers and the moved
moot-house template, including rope/pier cells. Validation now checks each
forward ray to water, including sockets and template obstacles; proximity to
water alone was insufficient. A regression rejects the former position. Northern quay idles use the moot house’s 15-node move or the explicit end of the new walk.
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

The lake bounds translate too: the POI exclusion loop in
`placement.lua:365–369` reads those bounds. Fixed city anchors do **not** imply
fixed exclusion boxes. The old Kezamba mask generator is deleted, as
`kezamba_lagoon.lua:4` records. Implementation needs a **new generator against
the current water function**, including the mask's shore/pad helpers; an old
static-hydrology generator is not an existing recut command.

Implementation must change these together:

- The two water chains, their calm/warp and bank-suppression extents, `MERE` and
  `kezamba_lagoon`. The old masks agree **column for column at ±47** with the
  source water (1,393 / 2,645 wet columns); the exporter asserts this. The new
  [wet masks](data/lakes.json) come from that source function through the larger
  boundary, not an extrapolated finite table.
- `capital_planner.lua`’s fitted samples, shore distance and district pinning,
  the outer wall runs/ends at water, avenues, bridges and quays. The real planner
  already reads the new water in the experiment. The future core’s changed
  boundary, Kezamba north deck and dry east landing must also reach
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
The original six exports and original civic-width-only 40-seed receipt remain
historical evidence. A **separate 40-seed lake comparison** from the pass-4
checker is now retained in [checker-lake-fleet.json](data/checker-lake-fleet.json),
with compact per-seed results and hashes of the original outputs.

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
`17713522922938657774`. The existing `ring1/q1 ring2/q1` labels remain.
The original three-seed result thus had Lethariel **1 new, 1 gone**, plots
**+0.33 mean (−1…+1)**; Kezamba **1 new, 0 gone**, plots **−0.33 mean (−2…+1)**.

**The checker's 40 seeds are the better figure.** These compare `lake0` with
`lake_shift` under the same 112/56/57/60 and calm-half=57 settings:

| Capital | Unrouted cases new | Gone | Mean plot change | Range |
|---|---:|---:|---:|---:|
| Lethariel | 9 | 1 | −0.15 | −3…+3 |
| Kezamba | 3 | 5 | +1 | −8…+6 |

A case is one changed street label on a capital/seed, not a whole failed
capital. Every required plot was placed, no load failed, and the other four
capitals' complete planner exports are identical between variants. The
aggregates were recomputed from all 80 existing checker outputs; the fleet was
not rerun. The page displays this table beside the three-seed evidence and
distinguishes it from the older, unshifted-lake civic-width table.

**Still unbuilt:** the new core cell lists, masks in the game, new landing scan,
castle architecture, piers, quays, final bank geometry, headroom and route seams.
The real planner study deliberately uses today’s authored core cells and landing
detector. Consequently its plot counts are measured sensitivity results, not
final-build certification. The dry-area counts and dry castle footprints are
fully measured in that terrain; final walkability is not.

In pass 4, an exploratory 17-node Kezamba run was rejected after the buffer check; its
scratch outputs are in `/tmp/r70-lake17`, not inputs to the delivered page. Only
the three changed-water runs were repeated for the 18-node proposal; the paired
unshifted runs were reused. The queue used at most two idle LuaJIT workers, each
with its own output; no server or voxel generation was run. No performance claim
is made.

## Verification and next gates

- `python3 tools/r70_design/build.py` and `verify.py`: 12 plans, 24 equal-scale
  SVGs, 659 socket rows, eight retained geometry regressions and one fishing-ray
  regression, 93 claim links, room/wall budgets, three paired lake seeds, exact
  mask/terrain counts, dry
  template envelopes, shore buffers, moot-house landing and unobstructed forward
  fishing rays; both 40-seed receipts recomputed.
- No repository Lua file changes in pass 5. The bounded water-function spot
  probe ran with LuaJIT under idle scheduling; no runtime fixtures or planner
  runs were needed. The prior pass’s Lua syntax checks remain historical.
- Light/dark SVG rendering with `inspect_svg.py`; the two changed pairs were
  visually inspected. The other ten places’ layout definitions, 20 SVGs and
  socket rows are compared against `4146eb8b` and remain unchanged.
- Local Markdown links, Python/JavaScript syntax, embedded data, numbered ledger
  wording and `git diff --check` checked. No runtime fixture, engine boot or
  full fleet is claimed for this tools-only amendment.

Browser layout/events and phone behaviour remain unverified (the earlier browser
sandbox limitation remains); desktop/web runtime tests belong to the user. Before
implementation is accepted: coordinator review, the two lake decisions, the full
building-template gate and **`tools/seed_fleet/run.sh full`**, then the user’s
GUI checks for every arrival side/mailbox, public services, shore fishing,
quay/deck/stair access, dry wall ends, Lethariel’s shore-starting avenue (or a
separately commissioned crossing), the mere precinct’s shore distance, Kezamba’s
single remaining boardwalk if accepted, all patrols, and throne-room
combat/chase/reward behaviour on desktop and web. Preserve the accepted shared
45×35 footprint, 35×23 hall reservation, y≤40 cap and existing encounter rules.
