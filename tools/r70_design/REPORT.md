# Round 70 DESIGN — pass 2

Date: 2026-11-07. Branch: `r70-design`. Base game code:
`55aa7708a2d6b28fbd3c87ad3e47b72cfea24a0d`; pass 1: `3a715b08`.

The [self-contained page](page.html) now addresses the completed Opus check,
whose verdict on pass 1 was **FIX FIRST**. Its complete report is preserved in
[data/design-check.md](data/design-check.md). This revision is for the
coordinator's delta review and the user's land-use decision; it does not claim
independent acceptance of its own corrections.

Only `tools/r70_design/` changes. Classification: **compatible, tools only**.
Implementing these layouts is a **map reset**, as the Round 70 plan declares.
No game code, server, world, other worktree, merge, push or other agent was used.

## Footprint and recommendation

**45 × 35 holds; radius 56 remains the recommendation.** The shared castle still
reserves 1,575 nodes², versus today's royal footprints of 837 in five capitals
and 529 in Kezamba. All six castle placements and the original planner numbers
remain unchanged. The twelve recommended layouts retain their original town
centre and waystone reservation sizes.

The throne-room reservation grows from pass 1's **345** to **805 nodes² (35 × 23)**
in every castle. The checker measured today's reachable hall floor as **684**
in five capitals and **402** in Kezamba. The new target gains **121 / 17.7%** and
**403 / 100.2%**, respectively. These baseline flood-fill measurements are
attributed to the checker; this pass did not reproduce that floor probe. The
comparison is explicit in all six capital sections and in one shared table.

The land budget is now explicit: two-node outer wall band **304**, hall
floor reservation **805**, one-node hall wall ring **120**, foyer/service/stair/circulation
space **346**; sum **1,575**. Inside the outer band is 41 × 31; the hall including
its own walls is 37 × 25. In the south-facing version the foyer is five rows deep,
with two-node side strips and a rear strip. This reserves a compact castle
centred on its hall, without promising a separate ground-floor courtyard. The
future architecture must keep the room reservation and exceed today’s reachable
floor after furnishing. The 805 is a floor reservation before the throne and
ornaments, not a measured furnished result. It must
also stay below **y max 40**; today's highest core top is 31 (Kezamba 30).

The castles at Dur Brannoc, Highcourt, Gor Drazhak and Nhal Veyr already fit in
**today's ±49**. The increase 48 → 56 chiefly serves their moved neighbours,
forecourt and bypass. The page now shows a concrete **48 alternative** for each:

- Same castle at (−22,4)…(22,38), six nodes south of the recommended placement.
- Existing gates remain; approach width 9 → 5 and bypass width 5 → 3.
- Only z=3 remains between the crossing and the great door: a doorstep, not a
  gathering forecourt. Eastern work buildings move six nodes, not eight;
  Highcourt's yard also moves one north. Markets and colonnades keep their
  existing tight spacing.
- Highcourt moves its chapel eight west and retires `north_house` and
  `chapel_house`. This is an explicit loss of two houses, not hidden crowding.

These four alternatives pass footprint, door-exit and full-width street checks
inside ±49. They are **land alternatives, without a second socket/furniture
schedule**. The user would need that schedule before choosing them for a build.
Lethariel and Kezamba's current proposed castle boxes reach beyond ±49; a 48
option there requires a different placement. A mixed choice would avoid the
four cities' radius-induced district cost, but growing the other two could
still change rivers world-wide.

I recommend **56**, because it provides the civic space requested around the
larger hall. This is a design tradeoff, not a geometric necessity for those four
castles. The unchanged nominal-square gain is **3,328 nodes² / 36.1%**; the outer
512-node capital reservation does not grow. The larger river keep-out is
**99.9 → 111.2 nodes** (`48*sqrt(2)+32` versus `56*sqrt(2)+32`): changing it changes
river planning throughout the world.

## Findings checked and corrections

All substantive findings were accepted after source inspection. One additional
Highcourt move was necessary: moving the chapel eight west alone makes its eave
columns touch `chapel_house`. Moving the chapel south instead conflicts with the
well court. The recommendation therefore moves **chapel, north_house and
chapel_house eight west**. `chapel_quest` follows from (−22,27) to (−30,27), the
east doors clear the castle, and the five-node bypass at x=−27 clears the chapel.
Highcourt now moves **14**, not 11, templates.

The generated schedule includes **all 659 exported sockets**, including the
three adapter cooking points in each town. Nothing is filtered out: before/after
coordinates, role, origin and nearby affected footprints are shown. The schedule
is also committed as [data/socket-schedules.json](data/socket-schedules.json).
Template points follow their host; generated gate watches and booth aliases
follow their gate/market; other nearby loose points follow the nearest host
within two nodes unless explicitly placed. That is a proposed furniture
attachment, not a claim about a runtime ownership API. The schedule includes:

- Every `door_guard_*`, `hall_idle_*`, `hall_waypoint`, Lethariel's four removed
  colonnade idle points, the four moving markets' booth points, and displaced
  `citadel_walk_north`, `precinct_walk_north`, `core_spare_*`, `forecourt_idle`.
- Gor Drazhak's `court_idle_wain` → (45,31), `court_idle_store` → (44,20),
  `court_work_fire` → (45,19), `precinct_walk_court` → (42,29). The spar points
  move to (38,25)/(39,25) to avoid an existing tree; their work features follow.
- Hearthpine's `watch_plaza_west` → (−17,0), between the fence at x=−18 and the
  stone furniture at x=−16. `hall_quest` **stays (−28,26)**. Its workyard now moves
  (−7,+1), leaving two clear rows before the hall and clearing the three-node
  walk. The western/eastern cross-street endpoints stop before the houses.
- Kezamba's western walk goes around the moved shore house and the moot house;
  its watch crossing moves off `trade_shed`, and the castle approach ends outside
  the future door.
- Lethariel's two vendors remain unchanged. Sunscar's new arrival pocket
  displaces **all eight drill posts**, as well as the acacia feature; the new
  ranks are at x=−31/−29/−27/−25, z=5/8. `BREASTWORKS` is a separate authored
  coordinate table that must follow its moved hall and armoury.

**Guards:** commit `494a6073` deliberately removed the door posts from the royal
binding, with an explicit assertion and 2 × 6 census. The historical evidence is
in [data/royal-binding.txt](data/royal-binding.txt). Two royal guards stay beside
the throne; two ordinary guards stay at the great door, visibly distinguished on
the page. No spare guards or encounter-count decision remains.

Later lanes must correct the stale statements at `docs/design/world.md:497–498`,
`docs/design/world_zones.md:1869`, `:1876` (five-NPC group), `:1886–1888`, `:1898`,
`docs/design/biomes_mobs.md:849` and the comment in
`mods/ENTITIES/grug_mobs/start_npcs.lua:921`. This lane does not edit those owners.

**Combat:** C008 now says plainly that no mechanism confines combat to the room.
The king's 30-node leash measures from the chase anchor, not the throne. The
60-node rule is reward participation around the death position. Neither changes.
C033, C059 and C081 have the vendor, unchanged quest point and drill-post fixes;
C021/28/35/42/49/56 now explicitly say **mask only**.

## Honest implementation scope

Counts derive from the actual export. “Lua sockets” means points outside template
ownership, including generated gate-watch loops. They all need review, not all
need translation. Each core also contains its streets, furniture and boundary.

| Capital | Templates moved | Lua sockets | All exported sockets | Composition lines |
|---|---:|---:|---:|---:|
| Dur Brannoc | 11 | 50 | 85 | 799 |
| Highcourt | 14 | 57 | 95 | 844 |
| Lethariel | 3, plus 2 retired | 60 | 98 | 945 |
| Gor Drazhak | 11 | 63 | 99 | 1,005 |
| Nhal Veyr | 12 | 61 | 96 | 1,005 |
| Kezamba | 6 | 22 | 54 | 963 |

C003 enumerates the coordinated edits: six `civic_width` profiles; planner
48/49/52 → 56/57/60; each composition's `RADIUS=49`; `precinct_ring.RADIUS=48`;
the ±47 corner towers in Dur Brannoc, Gor Drazhak and Nhal Veyr;
`city_green.CORE_HALF=49`; height fitting/collar and road exclusion;
`BOUNDS.capital_core`; the separate ±49 plot-collar exclusion;
`r7_capitals.core_landing` 46…49, its `built=96*96` statistic; and the river
keep-out formula. Gate watches, service bindings, in-memory route caches and
lake/deck constraints remain on the page.

C088 adds the **template gate**. New castle templates and roster `use` entries
are needed; format §6.1 freezes old box/pivot and point ids/groups/order/faces.
The later lane must plan a coordinator-approved **BASELINE** move under §6.2,
run the whole template gate and update `tools/r58_townfix/portable_test.lua`'s
`HALLS` table. Height cap and duplicate 96×96 documentation are in C089:
`settlements.md`, `world_zones.md:721/810/1741/1765` and the wording at 1865.

## Evidence retained and added

The original three-seed comparison is unchanged: exact seeds `12345`,
`3684797457838814663`, `17713522922938657774`; real planner, **mask only**,
CORE/GATE/KEEP 56/57/60 but **civic_width=96 and today's terrain/cores**.

| Capital | Plot totals in seed order | Moved surviving plots | Sampled eligible band removed |
|---|---|---|---:|
| Dur Brannoc | 48→50; 51→49; 51→52 | 48; 48; 51 | 3,648 |
| Highcourt | 49→47; 51→47; 53→48 | 47; 47; 47 | 3,648 |
| Lethariel | 45→45; 44→43; 40→41 | 45; 42; 39 | 2,752 |
| Gor Drazhak | 52→46; 51→47; 50→46 | 45; 47; 46 | 3,648 |
| Nhal Veyr | 49→47; 49→48; 48→47 | 45; 48; 46 | 3,648 |
| Kezamba | 51→49; 49→50; 51→49 | 49; 46; 47 | 2,464 |

The checker's **40 fleet seeds** also changed **civic_width to 112**, with the
same 56/57/60 planner parameters, **today's authored cores and landing detector**.
Its existing scratch exports were available: their 40 exact seed strings,
per-capital counts/failures, source JSON hashes and recomputed aggregates are
preserved in [data/checker-fleet.json](data/checker-fleet.json). No planner job
was rerun in this pass. The page lists all 40 seeds and the checker's rounded means.

| Capital | Mean plot change | Worst seed | New / removed unrouted cases | Infeasible seeds |
|---|---:|---:|---:|---:|
| Gor Drazhak | −2.1 | −5 | 0 / 0 | 2→0 |
| Highcourt | −1.9 | −6 | 2 / 0 | 0→0 |
| Kezamba | −1.2 | −8 | 3 / 1 | 3→3 |
| Nhal Veyr | −1.15 | −5 | 0 / 0 | 0→0 |
| Dur Brannoc | −1.1 | −5 | 2 / 0 | 0→0 |
| Lethariel | −0.1 | −4 | 0 / 2 | 0→2 |

Exact means before the report's rounding: Kezamba −1.225, Dur Brannoc −1.125,
Lethariel −0.075. All 240 proposed capitals place all required plots; no load
failure. Seven unrouted capital/seed cases appear, three disappear. The checker
also reports dry, flat castle samples on all 40 seeds; that terrain probe was
not rerun here. Individual seeds differ from mask only: seed 12345 yields
Dur Brannoc **50 versus 47**, Kezamba **49 versus 51**.

Neither experiment certifies the future cores. The implementing lane must run
**`tools/seed_fleet/run.sh full`**, including its usual acceptance checks, because
civic width affects every seed and world-wide river planning. Forty seeds are
supporting evidence, not a substitute for that gate.

## Verification and limits

- `build.py`: 12 recommended schedules; no template written-column overlap;
  bounds, arrival pockets, shared room/footprint, sampled existing water checked.
  New tests cover full-width streets against footprints, door exits against
  other template walls/castles, and every socket against foreign footprints,
  template solids and retained composition obstacles. Gate tunnels are checked
  against actual cells. Own indoor sockets remain legal if their cells are clear.
- `geometry.json` exports actual stamped template cells and composition cells as
  compact row runs, plus top heights. Solid-cell checking is conservative using
  the editor node registry (unknown nodes count solid); the documented non-solid
  grass/fern/junglegrass families are handled explicitly. The two-cell test is
  **not** a full entity collisionbox/headroom or engine path test.
- The loose-obstacle check excludes old template boxes that are re-authored,
  the future castle, old perimeter at |x| or |z| ≥47, and explicitly rebuilt
  waystone/cooking furniture. Final fencing, planting and moved furniture need
  the implementation's full geometry checks. No claim of a complete future
  voxel map is made.
- Four compact alternatives pass bounds/footprint/road/door checks. Their sockets
  and furniture are explicitly outside that alternative's validation scope.
- `verify.py`: **8 rejection regressions**, all 659 schedule rows, fixed cooking
  points, room/wall arithmetic, 40-seed aggregates, 91 claim links, 24 equal-scale
  main SVGs plus four compact SVGs, inline assets, internal links and syntax.
- `bash tools/check_lua.sh tools/r70_design/export.lua`: plain Lua 5.1 parser,
  globals and sweeps pass. Execution used LuaJIT, at most one process at a time
  in this pass; the reuse/export queue remains capped at two.
- Inline SVGs rendered with librsvg in light and dark themes for visual review.

Still unverified: browser layout/events and phone behaviour (browsers could not
start in the pass-1 sandbox); the castle's actual architecture; final terrain,
deck landings, furniture, entity headroom, walking/pathfinding, combat, and desktop
and web engine acceptance. No performance result is claimed. The user's layout
choice and the coordinator's independent delta review remain required.

Later checklist: run the template gate and **full** seed fleet; test every arrival
side and mailbox; quest/home/service standing and interactions; ordinary and royal
guard posts; all patrols, gates, stairs and deck approaches; then throne-room combat,
chase behaviour and reward participation on desktop and web.
