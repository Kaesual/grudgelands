# WP13: Kezamba, the troll capital, and the one built round a lake

Increment record, 2026-09-15, written on `main` at `922bfd92` ("Extend the
socket vocabulary for the wave-2 capitals"). It is the third of the capitals
contract's section 3 step 3, "the other five capitals, one lane each", after
Highcourt (the pilot) and Dur Brannoc (the first walled one), and it is the
first **open** capital and the first one whose own civic core is not flat
ground.

Contracts implemented:
[wp13-capitals-pois-contract.md](wp13-capitals-pois-contract.md) (§2.1 what a
capital is, §2.3 the budgets, §2.4 the troll row of the race table, §4 the
rulings on the king's hall, the sockets and the walls) and
[wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md) §8 in full,
wave-2 vocabulary included. The seam it plugs into is
[wp13-seam-generalisation.md](wp13-seam-generalisation.md); the standard it is
measured against is [wp13-highcourt-fill.md](wp13-highcourt-fill.md); the recipe
it follows is [wp13-dur-brannoc.md](wp13-dur-brannoc.md).

Evidence: `tools/wp13/evidence/20260915-kezamba/`.

## 1. The measurement this package exists because of

The capitals contract's §1 says of every capital that "the 96 × 96 civic core is
flat at the fitted reference height". At Kezamba that is true of **6 380 of its
9 025 columns and false of the other 2 645**, and the first thing this lane did
was measure it rather than discover it in a render.

**Those numbers moved once, and the move is the second finding of this package.**
Until WP40's routes were taught to end at the capital gates (main `f5583e13`),
the pad was flat over only 6 192 columns: one graded route corridor cut a
diagonal trench up to 26 nodes deep into it, this fixture measured the trench as
a ravine, and this composition was built around it as a gorge with a rail and a
footbridge. The trench is gone, `--verify` is what caught it, and §3d is what
happened next.

`tools/wp13/kezamba_water.lua` reads the planner directly — the same
`terrain_height_at` / `water_class_at` / `water_surface_at` the engine's world
authority publishes and `r7_settlement.lua` builds an overlay's surface from —
over the whole 512 envelope, on the **nine seeds** of
`tools/wp13/capital_anchor_fixture.lua`. What it finds:

| | |
| --- | --- |
| anchor | **(1800, 66, 1500) on all nine seeds** — Kezamba's civic reference is authored-fixed and does not move with the world |
| wet columns in the envelope | **30 354 of 263 169 (11.5 %)**, the same mask on all nine seeds (one SHA-256 over 66 049 sampled columns, zero mismatches) |
| wet columns in the 95 × 95 core | **2 645 of 9 025 (29.3 %)** |
| water surface | **y = 65, everywhere, on every seed** — exactly one node below the pad |
| dry core columns at the reference | **6 380 — all of them — on all nine seeds** (on the pre-`f5583e13` terrain: 6 192 to 6 327) |
| dry core columns BELOW it | **0 on all nine seeds** (before: 53 on seed 531802985935182545, 188 on seed 0, reaching 8 to 26 nodes down) |

The lake is WP40's own `hydro_kezamba_cenote`, a `deep_cenote` of four basins at
**fixed world coordinates** (`wp40/source/simple_map.lua`), and the reason its
surface sits one node under the pad is the water-correction package of
2026-09-13 ([wp40-water-road-polish.md](wp40-water-road-polish.md)): "the civic
water minimum is now applied as a hard floor after that compromise". The
off-reference dry columns were one narrow **ravine** running into the pad from
its south-west edge, with the same footprint in every world and only its depth
moving — which is exactly the signature of a graded route corridor, and is what
it turned out to be (§3d).

The engine's own terrain probe agrees with the offline reading: nine
`run_capital.sh … terrain` boots produce nine **identical wet masks** over the
envelope grid and report the anchor at (1800, 66, 1500) in every one. So does
the engine's `field` mode at node resolution over 251 001 columns, against the
committed mask, with zero disagreements (§6 d2) — and the planner and the engine
agree on the height of every one of the 9 025 core columns to the node.

**Both masks are therefore committed**, as `wp13/kezamba_lagoon.lua` — generated
by `kezamba_water.lua --emit`, re-checked column for column against the planner
on nine seeds by `--verify`, and asserted by the KAT. A capital core is a fixed
cell list in anchor-relative coordinates; it may be authored around a lake only
if the lake is in the same place in every world, and that is now a measurement
and not an assumption.

## 2. What shipped

| File | Change |
| --- | --- |
| `wp13/kezamba_lagoon.lua` | **new, generated**: the cenote (and the now-empty ravine) as inclusive x runs per z, with the reference height and the water surface |
| `wp13/kezamba.lua` | **new**: the 96 × 96 civic core built round both masks, the avenue/ring/threshold run specifications, the overlay dispatch and the lake and causeway rail |
| `wp13/kezamba_lots.lua` | **new**: the 52 searched lot positions and the four district definitions |
| `wp13/kezamba_plot.lua` | **new**: one district plot from a roster row, in the troll palette |
| `wp13/kezamba_districts.lua` | **new**: the four district rosters and the resolve seam |
| `wp13/kezamba_gate.lua` | **new**: the gate THRESHOLD an open capital has where a walled one has a gatehouse, as an overlay run |
| `wp13/troll_parts.lua` | **new**: the stilt hall, the cauldron court, the carvers' yard and the shaman's shrine |
| `tools/wp13/evidence/20260915-kezamba/` | the KAT under both interpreters, the micro pair, the six start identities, the static gates, the nine-seed measurements, the engine passes and the renders |
| `wp13/troll_palette.lua` | **new**: the basalt and water rebindings, as `palettes.new` overrides rather than an edit to the shared palette |
| `wp40/r7_kezamba_blueprint.lua` | **new**: the capital source the seam reads — core, 52 plots, one overlay of twelve runs |
| `wp40/r7_settlement.lua` | one roster row, appended last; nothing else |
| `wp13/kezamba_ramp.lua` | **new**: the gate ramp that brings each avenue down to the height Lane R's route ends at, and the guard that keeps it there |
| `tools/wp13/kezamba_water.lua` | **new**: the nine-seed water and pad survey, the mask generator, and `--field`, which reads the ENGINE's own terrain field back against the committed mask |
| `tools/wp13/kezamba_lots.lua` | **new**: `capital_plots.lua`'s four rules asked of the planner on nine seeds, before a composition exists |
| `tools/wp13/kezamba_kat.lua` | **new**: acceptance for the masks, the core, every plot, the sockets and the overlay |
| `tools/wp13/final_micro.lua` | the new KAT joins the interpreter pair |
| `docs/design/settlements.md` | the open capital, the threshold, and the capital with a lake in it |

`wp13/kezamba.lua` also publishes `M.districts.resolve`, loaded lazily, so Lane
D's generic `tools/wp13/dump_capital_plan.lua` can draw this capital whole from
the one file (`evidence/…/renders/plan-whole-capital-ne.png`).

Not touched: the six start compositions, `highcourt*.lua`, `dur_brannoc*.lua`,
`avenue.lua`, `wall.lua`, `capitals.lua`, `buildings.lua`, `parts.lua`,
`palette.lua`, `dressing.lua`, `layout.lua`, `interiors.lua`, `roofs.lua`,
`run_capital.sh`, `capital_probe/`, and every WP40 file but the roster row.
§6(b) carries the proof.

## 3. The core, and the three rules the lake imposes

96 × 96, bounds x/z [−47, 47] and y [−2, 30] inside the contract's [−2, 40].

The city stands on the dry south-west of its own pad, the cenote is its
north-east quarter, and the composition **lays no ground in either mask**. Three
rules follow, and all three are in the KAT:

1. **Nothing of the composition stands in a masked column but the boardwalk, its
   piers, its rail and the moot house.** The one that is easy to get wrong is
   AIR: the settlement writer writes a blueprint's air exactly as it writes its
   stone, so an air cell over the cenote is a hole in the lake. `buf` has no
   delete, so the composition keeps a register of every cell it deliberately
   puts over the water and drops everything else in a masked column when it
   builds its canonical list — 70 cells on the current layout, all of them
   ground cover and lamp scatter that landed where they were told.
2. **Every carriageway column over the water carries a deck.** The east and
   north avenues leave the crossing and cross **315 columns** of open cenote
   inside the core alone; all 315 are decked, on basalt piers every third edge
   column, with a junglewood rail on both verges.
3. **The three anglers face the lake.** §8.1's `fish` rule wants "a water node"
   under `dir` within three nodes and reads BLUEPRINT cells for it, which at
   Kezamba is the wrong question — the water is WP40's and no blueprint cell can
   be it. The KAT answers the same claim against the committed mask instead,
   which is a stronger test than the contract's own: the mask was measured on
   nine seeds and a blueprint cell is measured on none.

| Quarter | What stands there |
| --- | --- |
| South-east of the crossing | the **king's hall**, the library's basilica on its podium with its great door on the throne approach. It is east of the axis and not on it, because the RAVINE took the ground west of the approach from z −47 to z −21; the gorge is gone (§3d) and the hall stays where it put it |
| The lake's west bank | the **moot house**: a stilt hall whose flight stands on the shore, whose platform stands half on the bank and half on piers over the water, and whose walkway runs on out over the cenote. This is the contract's troll row built out of the terrain rather than on top of it |
| The quay | the waterline from z 6 to z 44, kerbed in basalt; the fishmonger's counter, three drying racks and the three anglers on the shore columns |
| South-west | the **cauldron court** — this capital's market cross is four pots on a basalt hearth ring with a fire between them — and the carvers' yard |
| North-west | the **shaman's shrine** on its basalt platform, which carries the capital's one quest shell |
| The boundary | no wall and no parapet: totem posts at the gate mouths, and jungle |

Measured populations of the finished core: 6 380 pad columns, 2 645 lagoon,
**0 ravine**, 367 boardwalk cells, 53 piers, 80 quay stones, 0 bridge cells,
0 gorge-rim rails, 4 totem posts, **7 emergent kapoks and 7 jungle trees**,
54 sockets, 69 559 cells. The six numbers that moved are §3d.

### 3d. The gorge that was a road

**What happened.** The first version of this package measured 273 columns of the
civic pad standing up to 26 nodes below the fitted reference — a narrow diagonal
band entering from the south-west — committed them as `kezamba_lagoon.lua`'s
RAVINE mask, and built the core around them: no pad in those columns, a
rope-and-post rail on 25 even columns along the rim, one five-lane plank
footbridge at z = −22 where the band is narrowest, the king's hall pushed east
off its own axis, and the market walk held at z −20..−16 so no lane would hang
over the gap.

On the rebase onto main `f5583e13`, `tools/wp13/kezamba_water.lua --verify`
went red: **273 disagreements, every one of them a ravine column**. The lagoon
half still agreed to the column on all nine seeds. Re-measured, the pad is flat
at y = 66 over every one of its 6 380 dry columns on all nine seeds, and the
engine's own `field` boot says the same at node resolution.

**What it was.** A graded ROUTE CORRIDOR. WP40's wave-2 route lane (main
`0518a01b`) taught every route to end at a capital's gate points instead of
grading on through the envelope; the trench that cut this pad was a road being
laid across it. The direction fits — in from the south-west edge, diagonal, one
band wide — and so does the depth moving with the seed while the footprint does
not.

**What changed here.** The mask was re-emitted (0 ravine columns), the footbridge
and the rim rail are gone — a bridge over flat ground is worse than no bridge —
and the 273 columns now take the pad like any other, which is where the +1 531
core cells and the two extra emergent kapoks come from. **Everything that
REFUSES stays**: a lane that crosses a ravine column, a stilt that stands in one,
a plot that reaches one, and now a loud error if the core ever finds a ravine
column at all. The mask, the counters and the KAT's rules stay with them.

**And the gate that was missing is in.** Nothing that runs on every change had
ever asked the planner about the ravine half of the mask: the KAT asserts the
module against itself, and `kezamba_lots.lua check` verified only the lagoon.
`check` now verifies both — a dry core column below the reference must be a mask
column, a committed ravine no seed has is a failure — so the next terrain package
that cuts or heals this pad turns a gate red instead of shipping a fence round
nothing.

### 3a. "Emergent trees kept", and what that can honestly mean here

The contract's troll row ends "emergent trees kept" and the brief asks for the
count inside the envelope **before and after**. The after is a count; the before
is an estimate from a control band of untouched ground in the same built world,
because nothing in this tree censuses nodes in a world the capital is absent
from. The independent review of 2026-09-16 was right to call the first version of
this paragraph a different claim from the one the contract makes.

* **What the composition writes on.** The core lays ground on 6 380 of its 9 025
  columns and leaves 2 645 to the lake; the 52 plots' ground rectangles are
  32 116 columns; the overlay's eight seven-lane bands are 11 256. That is
  **49 752 of the envelope's 263 169 columns, 18.9 %**, and it is an upper
  bound, because the bands overlap the core and each other. **At least 81.1 % of
  the envelope is never touched, and WP40's own emergents there stand exactly as
  the mapgen placed them.** That is the whole of what "kept" can mean for a
  settlement that writes cells.
* **What the composition plants.** Inside its own footprint it puts back 5
  emergent kapoks and 7 jungle trees in the core (7 kapoks since the gorge
  healed, §3d) — a floor of 4 emergents is a
  build error, which is the number the KAT holds — plus the groves and totem rows
  of the fill lots. The built core carries **3 000 tree cells**, 1 708
  `default:jungletree` and 1 292 `default:jungleleaves`, read back out of the
  finished map.
* **The control, which is the nearest thing to a "before" this tree can take.**
  `measurements/emergent-trees.txt`. The `full` boot's east-avenue dump reaches
  from x 40 to x 260, so the band x 60..260, z -12..12 — **5 025 columns of the
  envelope that carry no core, no plot and no dressing** — is WP40's own ground
  in the finished world. It carries **52 tree columns, 10.3 per thousand**. At
  that density the core's 9 025 columns would have held **about 93 trees**. The
  core as built carries **585 tree columns and 3 000 tree cells** (1 708
  `default:jungletree`, 1 292 `default:jungleleaves`). The settlement therefore
  leaves the pad with **roughly six times the tree columns the wild ground it
  replaced would have had**, which is the strongest form the contract's "kept"
  can take for a capital that also clears a terrace. The band's dump is clipped
  to the road's deck ±6, so its CELL count is a floor and only its COLUMN count
  is used.
* **`field` mode does not answer this, and the previous version of this
  paragraph said it would.** Lane D shipped `run_capital.sh <out> <key> field
  <seed>` on 2026-09-15 and it is a TERRAIN field — the final height and the
  land/water class of every column within ±250, from `grug_zones` — not a node
  census. It cannot see a tree. A true before/after needs a node census of the
  same region in a world whose roster does NOT carry the capital, which is one
  region and one loop in `tools/wp13/capital_probe` (a `census` mode taking a
  region and counting node names, runnable in `ground_only` mode where the
  roster need not carry the key). That probe is Lane D's and the change is not
  this lane's to make; the number above is what this lane can take without it.

## 3c. The gate ramp: how the avenues come down to the ground Lane R hands them

`wp13/kezamba_ramp.lua`, and it is this package's second blocker fix.

**What was wrong.** `avenue.lua` walks its road at the ONE-LIPSCHITZ UPPER
ENVELOPE of the surface over a forty-column look-around. Outside Kezamba's
envelope the terrain climbs fast — 40 nodes in 32 columns beyond the east gate on
seed 531802985935182545 — so the envelope lifted the road INSIDE the envelope to
meet ground OUTSIDE it, and the run then stopped at the gate point. The
independent review of 2026-09-16 measured all four gates on all nine seeds: the
road arrived up to **26 nodes above the terrain**, as a sheer face with nothing
beyond it, and the threshold's posts and kerbs floated on the same level. The
first version of this note reported that for one gate on one seed and called it
the road module working; it was four gates on nine seeds, and the west gate was
as bad on the user's own world.

**The ruling** (coordinator, 2026-09-16): the avenue arrives at each gate point
at the terrain height there — where Lane R ends its route — descending inside the
envelope at most a node a column, with nothing floating.

**The rule**, and it is one line:

    T(p) = min( D(p), g + |p - gate| )

`D(p)` is the road's own deck at column `p`, read back off the piece `avenue.run`
just returned rather than re-derived; `g` is the terrain at the gate point's
centre column. `T` is the minimum of two functions that each change by at most a
node per column, so `T` does too, and it is nowhere above the road the module
built. Where `T < D` the column is REBUILT: air from `T` upward so nothing of the
old road is left hanging, basalt from the column's own terrain up to `T` so
nothing of the ramp floats, a tread where the level steps, a rail on both kerbs,
and the verge standards carried down to the road they light — which also takes
care of the review's note N5, the standards that stood fifteen nodes under the
carriageway.

It reads nothing but the piece and the surface callback the seam already hands
over, so a piece of a run is still exactly that stretch of the whole run, and the
KAT's cut-at-every-column union test proves it. A drop deeper than the
forty-column look-around would be a ramp a piece could not compute and is refused
rather than silently stepped.

**`avenue.lua` was not touched.** It is Lane R's and the shared road of three
capitals, and the same instrument gives Highcourt at most +4 and Dur Brannoc +2
over the same seeds — this is Kezamba's terrain, not the road's defect.

### The measurement: four gates, nine seeds, against Lane R's route ends

    luajit tools/wp13/kezamba_lots.lua <repo> gates
    luajit tools/wp13/route_gates.lua  <repo> <seed> --strict

Two instruments, one number each. `kezamba_lots.lua gates` builds the
composition's own avenue for a seed and reports, per gate, the step between the
road's last deck and the terrain, the number of columns `kezamba_ramp` had to
rebuild, the depth of that descent and the count of cells resting on nothing.
`route_gates.lua` is Lane R's, reads the OTHER side of the junction — the height
its route arrives at the same gate point with — and is the authority on what the
city lane must meet.

| seed | gate | R route end | ramp `gate_level` | step | ramp columns | floating |
| --- | --- | --- | --- | --- | --- | --- |
| `531802985935182545` | W / E / S / N | 37 / 44 / 76 / 90 | 37 / 44 / 76 / 90 | 0 | 0 | 0 |
| `8675309` | W / E / S / N | 33 / 33 / 90 / 72 | 33 / 33 / 90 / 72 | 0 | 0 | 0 |
| `15912857179583385436` | W / E / S / N | 37 / 44 / 75 / 74 | 37 / 44 / 75 / 74 | 0 | 0 | 0 |
| `0` | W / E / S / N | 27 / 21 / 72 / 52 | 27 / 21 / 72 / 52 | 0 | 0 | 0 |
| `1` | W / E / S / N | 33 / 39 / 72 / 71 | 33 / 39 / 72 / 71 | 0 | 0 | 0 |
| `2` | W / E / S / N | 36 / 28 / 58 / 59 | 36 / 28 / 58 / 59 | 0 | 0 | 0 |
| `42` | W / E / S / N | 39 / 43 / 84 / 80 | 39 / 43 / 84 / 80 | 0 | 0 | 0 |
| `12345` | W / E / S / N | 41 / 39 / 96 / 73 | 41 / 39 / 96 / 73 | 0 | 0 | 0 |
| `999999999` | W / E / S / N | 27 / 34 / 69 / 75 | 27 / 34 / 69 / 75 | 0 | 0 | 0 |

**The two readings agree on 36 of 36**: the height `kezamba_ramp.gate_level`
reads at a gate point is, to the node, the height Lane R's route ends at there,
so `gate_level` needed no adaptation when the routes landed. The step is 0 on 36
of 36 and nothing floats on 36 of 36 (`measurements/gate-vs-route-ends.txt`
carries the full table, `measurements/route-gates-531802985935182545.txt` Lane
R's own strict output for the gate seed).

**The ramp now rebuilds nothing, and that is the point of the number.** On the
terrain this lane measured before Lane R landed, `avenue.run`'s one-Lipschitz
upper envelope arrived up to 27 nodes high and the ramp rebuilt between 1 and 14
columns per gate (the previous version of this table). Lane R's routes now stop
AT the gate point at free-terrain height instead of grading through the envelope,
so the ground the road walks no longer climbs away beyond the gate and the
envelope no longer lifts: 0 rebuilt columns on all nine seeds. `kezamba_ramp` is
therefore a standing GUARD rather than an active correction — it costs one
comparison per column and fires the moment a future terrain change puts the
approach back above the ground. The KAT keeps its rules for exactly that reason,
and the two counts the measurement reports beside `floating` stay as they were:
`on_water`, the causeway over the cenote, which the seam hands the road the
water's surface for on purpose, and `on_deck`, a column a WP40 route bridge spans
and `avenue.lua`'s crossing rule deliberately does not fill up to.

## 3b. The gate threshold: what an open capital has instead of a gatehouse

`wp13/kezamba_gate.lua`, and it is the first of its kind in the tree. WP40 pins a
gate station at (ax ± 256, az) and (ax, az ± 256) of every capital, and the
wave-2 route lane ends every long-distance route on exactly those four columns;
a walled capital greets the traveller with a gatehouse and an open one has, so
far, greeted them with nothing. Kezamba's answer is two totem posts on the
verges, a junglewood lintel across the carriageway between them, a torch on the
inner face of each and one marker course of basalt laid flush into the road.

It is an OVERLAY run, for the three reasons the curtain wall is one
([wp13-dur-brannoc.md](wp13-dur-brannoc.md) §2): an anchor blueprint is bounded
at ±47 and the gate stands 256 nodes out; a reference plot is projected from one
column and the threshold spans the road; and an overlay is a pure function of the
column surface, which is what a gate on terraced ground is. It shares the
capital's one overlay with the avenues, and the avenues run FIRST, because the
successor's cross-run arbitration is what lets the road keep the cells of its own
carriageway under the lintel. Every cell stays inside the seam's `at ± (half + 1)`
activation band: the posts stand on lanes ±3 and nothing reaches further.

**It writes no ground, and that is a correction with a render behind it.** The
first version took the highest ground over the gate point plus six columns either
way and carried every column of its seven-lane band up to it, so where the road
descends — which at Kezamba's east gate it does, steeply, off WP40's blend to the
terraces — the "threshold" came out as a solid wall of masonry across the road
with the posts buried in it. A gate a traveller cannot see through is not a gate.
The base is still taken over the gate point's own seven lanes, which lie inside
every piece's look-around, so the lintel is still level; what changed is that
nothing is filled up to it. Four runs of 728 cells became four of 168.

## 4. Where the fifty-two plots stand, and why they are not a grid

Highcourt authors one nine-lot grid, rotates it into each quadrant and lets the
world seed permute which district takes which quadrant. Kezamba cannot: the lake
fills one quadrant in **every** world, so a permutation would put a district in
the water three times out of four. Its districts are pinned to the ground that
exists, and the positions were **searched** rather than authored and corrected:

    luajit tools/wp13/kezamba_lots.lua <repo> pack     # the search
    luajit tools/wp13/kezamba_lots.lua <repo> check    # the committed gate

`kezamba_lots.lua` asks `tools/wp13/capital_plots.lua`'s own four questions —
dry, inside the foundation skirt, under its own cleared airspace, off the core,
the gate corridors, the avenues and the ring street — against the planner on
**nine seeds instead of two**, which is the right instrument for a capital whose
dominant constraint is the same in every world. It is a pre-flight and not a
replacement: the engine scan and `capital_plots.lua` stay the authority.

| District | Role (contract §2.1) | Where | Plots | Fill |
| --- | --- | --- | --- | --- |
| `shore` | market and professions | south-east | 9 | 4 |
| `vine` | residential and cultural | south-west | 9 | 4 |
| `canopy` | martial and garrison | west and north-west | 11 | 4 |
| `totem` | lore and spiritual | the lake's far bank | 7 | 4 |

**Thirty-six building plots and sixteen fill lots, the Highcourt standard**, and
the one place Kezamba departs from four-times-nine is the split: the packer finds
only seven legal reach-13 centres north of the lake that are not a hundred and
seventy nodes from their own district, and the west strip has room for the two
that are left over. That is a measurement, not a preference.

## 4b. Nine seeds, not three

The coordinator's wave-2 update of 2026-09-15, after the first two capital
reviews found a four-node step and twenty-one illegal lots on seeds a lane had
skipped: lot legality, the load-time terrain audit and walkway continuity are
measured on **all nine** seeds of `capital_anchor_fixture.lua`. For Kezamba all
three are:

| measurement | tool | result |
| --- | --- | --- |
| the wet mask and the water surface | `kezamba_water.lua --verify` | one mask, surface y = 65, nine of nine |
| lot legality (dry, skirt, clear, off the core/corridors/streets, one node clear of each other) | `kezamba_lots.lua check` | **52 of 52 legal, nine of nine** |
| can a player walk up to every plot | `kezamba_lots.lua walk` | **PASS on nine of nine**: every lot has a side whose kerb face is at most 3 (against a skirt of 6) and whose sixteen-column approach steps at most **1 terrace step (3) a column**; the worst face measured is 3 (`shore_4`) and the worst approach 3 (`shore_7`) |
| `audit_terrain` findings at load | nine `run_capital.sh full` boots | **0 on nine of nine**, with 0 ERROR and 0 ModError lines and 0 submerged plots |

**Why the core needs no per-seed continuity check and the plots do.** The civic
core is ANCHOR-RELATIVE and Kezamba's anchor is authored-fixed at y = 66 in every
world (§1), so the core's own boardwalks, its stilt-hall flight and its quay are
the same cells at the same heights in every world — the engine's
own read-back digest says so (`core_road_digest` identical on four seeds, §6d).
A district plot is projected from a reference column whose height the world
decides, so the step between it and the ground beside it is a per-seed question,
and that is what `walk` asks.

## 5. Against the Highcourt standard

| measure | Highcourt (wave 1) | Kezamba |
| --- | --- | --- |
| districts / plots / fill lots | 4 / 36 / 16 | 4 / 36 / 16 |
| cells | 376 274 of 400 000 | **319 499 of 400 000** (core 69 559, plots 249 940) |
| largest single plot | 10 451 of 12 000 | **11 820** (`totem_shrine`) of 12 000 |
| sockets | 256 | **262** |
| work sockets | 36, over 9 activities | **62**, over **13** activities |
| vendors | 7 kinds, one each | **7 kinds, one each** (race, general, fishmonger, brewer, butcher, herbalist, tailor) |
| residents / walkers | 144 / 22 (15.3 %) | **163 / 21 (12.9 %)** |
| idle spawn ≥ work (§8.3) | 108 ≥ 36 | **101 ≥ 62** |
| spare spots | 10 core + 8 district | **11** |
| patrol loops | one per district plus the ring | **5**, walked 1..n with no gap (9, 14, 14, 17, 11) |

The 13 activities: `brew` 8, `carve` 13, `chop` 7, `farm` 5, `fish` 3,
`forage` 3, `mourn` 1, `pray` 2, `sit` 10, `smith` 1, `spar` 2, `stall` 2,
`tend` 5. **52 of the 62 name a feature the KAT can measure**, and every one of
those 52 faces it within three nodes with nothing solid in between; the other
ten are `sit`, which the contract says sits on the ground it stands on.

Two activities are the honest reading rather than the obvious one, and both
follow the precedent the Highcourt fill set with its baker:

- **the smokehouse keeps a `stall`.** The closed vocabulary has no word for
  curing fish. `tend`'s feature is a plant and a drying rack is not one; `chop`'s
  is a log, and a rack IS posts and a beam, so a `chop` socket there would pass
  its own rule while naming a man with an axe at a fish rack. `stall` is "a
  counter at waist height", the smokehouse has one, and that is true of what
  stands there.
- **`farm` reads the troll palette's mud furrow.** The troll palette binds
  neither `crop` nor `crop_soil`, so `dressing.crop_rows` falls back to
  `ground_patch` and `planter_soil` — which is what a field in a flooded basin
  is. The KAT's feature sets are built from the palette's own roles, which is
  what lets the rule say so instead of refusing a field for not being wheat.

## 6. Verification

### (a) The KAT, both interpreters

`tools/wp13/kezamba_kat.lua` is byte-identical under LuaJIT and PUC 5.1 and its
row reads

```
wp13_kezamba budget/69559/249940/319499/400000
  core/69559/50/54/6380/2645/0/367/53/80/0/7/2182/315
  mask/30354/0/120/66/65
  overlay/12/11/…/3369caec589539d4955d190198890b154639230e91e238170189d9c3adc5bf07
  plots/52/249940/11820/totem_shrine/canopy=15,shore=13,totem=11,vine=13
  roster/anchor_012/12/kragmar_kezamba/capital_core/capital_plot
  sockets/…/163/21/12.9/52/brewer,butcher,fishmonger,general,herbalist,race,tailor/…
```

Its six sections: the two masks against their own published counts and against
each other; the core (envelope, budget, canonical unique cells, byte-sorted
palette, the three lake rules, the reserved anchor root, the four gate mouths,
the empty travel plaza, the emergent floor); every one of the 52 plots
(schema, envelope, budget, reference column, skirt to −6, published `clear_to`,
the lot rules that need no terrain); the capital's socket arithmetic (one
throne, one quest shell, one waypoint, at most one vendor per kind, every loop
1..n with no gap, §8.1 in full for every workplace, §8.3's ratio and band); the
budget; and the overlay, where every run is **cut at every column and the union
compared with the whole, cell for cell** — which is the property the lake rail
could break and does not.

The whole WP13 fixture set in one process under each interpreter:

```
WP13 final micro PASS interpreter=luajit output_sha256=41ed5eb2…
WP13 final micro PASS interpreter=puc51  output_sha256=41ed5eb2…
```

The digest has moved five times and each move is accounted for. `46b4dea6…` was
the pre-rebase value; `a15f5630…` is what the rebase onto Lane N (`c8050057`, the
wave-2 NPC vocabulary) produced, and **that delta is Lane N's, not this lane's**
— the independent review measured the branch's TSV against an archive of
`c8050057` and found it differs only by the three Kezamba rows. `f9e8976d…` is
the fix round of 2026-09-16: the KAT gained the avenue-obstruction rule, the
occlusion half of the `fish` test and a tighter `smith` set, so its own row
changed. `9e36e83c…` is the rebase onto `f5583e13`, which brought Lane R's route gates
and the Dur Brannoc upgrade into the fixture set with rows of their own, and
this lane's own row did not move across that rebase. `41ed5eb2…` is the gorge
round of §3d: the core gained 1 531 cells and the mask lost 273 columns, so the
Kezamba row moved and nothing else did.

### (b) The six starts are byte-identical

`luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua .` prints
the six start identity digests, and the SHA-256 of that output is
`0bbf87a7253deadca55951752adde73e82c31cd10878dc64ef6d44af91ad1f5f` — the value
wave 1 recorded, unchanged. This lane edited no shared module: the only file it
touched outside its own is `r7_settlement.lua`, and only to append one roster
row.

`seam_kat.lua` passes with the new row in the roster and reports the roster as
`… highcourt:capital, dur_brannoc:capital, kezamba:capital`, 54 blueprints
(52 reference, one anchor, one overlay) and a manifest field order derived from
it. The manifest needs no hand edit: since the seam generalisation its field
order is built from the roster in roster order.

### (c) Static gates

`static.sh` / `static.txt`: `tools/bin/luac51 -p` and the SETGLOBAL count on
every file this package touched (all PASS, **all zero globals**), the whole
`mods` and `tools` trees parse under plain 5.1, and the five plain-5.1 sweeps
scoped first to the touched files and then to `mods/*/grug_*` and `tools`. The
only sweep hits this package contributes are `os.exit` in `kezamba_lots.lua` and
`kezamba_water.lua` — the standalone-CLI pattern `capital_plots.lua` and
`highcourt_plots.lua` have carried since the renderer landed, neither ever loaded
by the engine — and three comment lines whose prose contains a `|` or a `//`.
`check_fresh_server.py` PASS.

### (d) Engine

`tools/wp13/run_capital.sh <out> kezamba terrain|field|full <seed>`, port block
31500-31599, one headless server at a time, every boot under `nice -n 19`.
**Nine `terrain` boots (§1) and nine `full` ones**, one per fixture seed, each a
cold world, plus — after the rebase onto `f5583e13` — one `full` and one `field`
boot on the gate seed against Lane D's fixed runner.

**The runner now reports PASS.** Lane D fixed the open-capital digest loop in its
round (`run_capital.sh`, "AN OPEN CAPITAL PUBLISHES NO RAMPART AND NO GATE, and
that is not a failure"), so the `full` pass on `f5583e13` ends with

```
exit=0 errors=0 complete=1
avenue overlay digest recorded (no committed value for seed 531802985935182545 yet)
rampart: this capital publishes no such overlay region
gate: this capital publishes no such overlay region
WP13 capital pass PASS: kezamba full
```

(`engine/f5583e13-full-531802985935182545/`). The nine-seed tables below were
taken before that fix and were read from their logs, which is what §7.8 records;
nothing in them changed, and the one seed re-run on the fixed runner agrees with
its row. Each boot is read from its log in any case: the ERROR and ModError
counts, the `event=complete` line, the terrain-audit lines and the NPC roster.

| seed | chunks | steady mean | worst | Lethariel control | worst plot fall | submerged | sockets | ERROR lines | audit findings |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `531802985935182545` | 66 | **0.523 s** | 0.951 s | 2.417 s | 5 | 0 | 262 | 0 | 0 |
| `8675309` | 64 | **0.499 s** | 1.160 s | 2.278 s | 6 | 0 | 262 | 0 | 0 |
| `15912857179583385436` | 66 | **0.448 s** | 0.825 s | 2.232 s | 5 | 0 | 262 | 0 | 0 |
| `0` | 58 | **0.637 s** | 1.299 s | 2.720 s | 5 | 0 | 262 | 0 | 0 |
| `1` | 63 | **0.495 s** | 1.386 s | 4.718 s | 6 | 0 | 262 | 0 | 0 |
| `2` | 60 | **0.490 s** | 0.861 s | 2.678 s | 5 | 0 | 262 | 0 | 0 |
| `42` | 67 | **0.521 s** | 0.966 s | 2.792 s | 5 | 0 | 262 | 0 | 0 |
| `12345` | 66 | **0.563 s** | 0.996 s | 2.501 s | 6 | 0 | 262 | 0 | 0 |
| `999999999` | 60 | **0.553 s** | 1.112 s | 2.340 s | 6 | 0 | 262 | 0 | 0 |


steady mean over the nine: 0.448 .. 0.637 s (mean 0.525), against the contract's "no more than 2x the ~0.5 s Dawnmere
chunk". Lethariel is the honest control -- WP40 fits, flattens, terraces and
protects it exactly like Kezamba and it has no WP13 blueprints at all -- and
**Kezamba's mapchunks are four to nine times cheaper than it**. The warm-up
mapchunk carries the emerge environment's one-time R7 construction (~24 s) and
is emerged first and not counted.

**Zero ERROR lines, zero ModError lines and zero terrain-audit findings on all
nine seeds**, and **zero submerged plots on all nine**, with the worst plot
perimeter fall 5 or 6 against a foundation skirt of 6. The NPC roster is complete
on every one:

```
start npcs troll kezamba: guards 18/18 flair 163/163 vendor 7/7 quest 1/1
  new ... pending 0 spare 11 residents 163 walkers 21
```

on seven of the nine; on seeds `42` and `12345` the last line reads
`flair 161/163 ... pending 2`, which is the same thing Dur Brannoc recorded: the
split between "placed at readiness" and "pending" depends on which mapblocks the
emerge sequence had loaded when the probe shut the server down, and is not a
gate. Every seed places all 18 guards, all 7 vendors and the quest shell.

All seven vendor kinds resolve since this lane was rebased onto Lane N
(`c8050057`, the wave-2 NPC vocabulary). Before that rebase `brewer` and
`herbalist` had no entity and the log carried the two error lines §8.4 says it
should ("an error line at placement and an empty socket, never a load failure").

**Build time in the engine**, from the probe's own `build_us`: module load
17.2 ms, the core 116.4 ms, the 52 plots 230 ms together with `totem_shrine`
the slowest at 10.6 ms. "Builds in a few seconds under LuaJIT when first
touched" is 0.36 s for the whole capital.

**Read the absolute numbers against their own control and not against another
lane's.** These passes ran on a workstation carrying seven WP13 lanes at once.
The two seeds re-run after the causeway rail landed (§6e) measured 0.618 s and
0.612 s against a Lethariel control that had risen from 2.36 s to 2.70 s in the
same window: the RATIO held at 4.4 – 4.5×, and it is the ratio that says what
this settlement costs.

The `full` boot on the fixed runner (`f5583e13`, seed `531802985935182545`,
after the gorge round of §3d) reports the same roster, 66 capital mapchunks, a
steady mean of **0.504 s** against a Lethariel control of 2.244 s (4.5×),
`worst_plot_fall=5`, `sockets=262`, `errors=0`, `complete=1`, and **zero ERROR
or ModError lines in the whole log**:

```
start npcs troll kezamba: guards 18/18 flair 163/163 vendor 7/7 quest 1/1
  new 3 pending 0 spare 11 residents 163 walkers 21
WP13 capital pass PASS: kezamba full
```

The built core moved with the pad, as it must: `core_road_digest` is now
`eafdce92…` over 6 611 read-back cells (it was `0d6e6eea…`), and the avenue's
`4f2fb544…`/1 993 is unchanged by the gorge round, which touched no street.

### (d2) The engine's own field against the committed mask

`run_capital.sh <out> kezamba field <seed>` (Lane D's new mode) writes
`kezamba-field.tsv`: the final height and the land/water class of **every column
within ±250 of the anchor**, read from `grug_zones` inside the boot.
`kezamba_water.lua --field <that file>` compares it, column by column, with the
lagoon mask this package committed:

```
kezamba_field reach=250 core_wet=2645 core_disagreements=0
  envelope_wet_engine=30354 envelope_wet_mask=30354 envelope_disagreements=0
  dry_y=66..66 ravine_y=66..66 wet_y=53..55 reference_y=66 water_surface_y=65
kezamba_field PASS: the engine's own field agrees with the committed mask on
  every one of the 251001 columns it covers
```

This is the one check the offline fixture cannot make of itself. `kezamba_lagoon.lua`
was generated from the PLANNER; here the running server answers the same question
and gives the same 30 354 wet columns, the same 2 645 inside the core, and not one
column of disagreement. It also shows what §1 measured from the other side: the
height authority reports **66 for every dry column of the core** — the pad is
flat at the fitted reference, exactly as the contract says — while
the water class marks 2 645 of those columns as the cenote, whose bed the field
puts at 53..55 under a surface at 65. And it is the reading that closes §3d: on
the terrain this package was first written against, the same probe would have
answered 58..65 for 53 of those columns.

### (e) What the engine reads back, and what is invariant across the seeds

The probe digests what it reads back out of the finished map. From the committed
evidence (`engine/full-<seed>/probe.txt`) over the nine seeds:

| | value |
| --- | --- |
| `core_road_digest` | one value on all nine seeds |
| `plot_road_digest` | **seven distinct values over nine seeds** |
| `avenue_road_digest` | one per seed |

At the head of this branch, on seed `531802985935182545`:
`core_road_digest = eafdce922db68f98366c0da49823bfe9bb1e81d63328b6d2315a748af0203056`
over 6 611 read-back cells, and
`avenue_road_digest = 4f2fb544ff4f514aeb078053278f21bb88284f855b2e06554f0e053e9cdf9fbe`
with **1 993 overlay cells in the dumped region**. The core digest moved with the
gorge round of §3d (it read `0d6e6eea…` while the pad had a hole in it). The nine-seed table of §6d was
taken before the fix round of 2026-09-16 and its timings and counts still hold —
the core moved by the six cells B1's rail change took out of it and the avenue by
the gate ramp — but the three digests it recorded belong to the pre-fix tree and
are superseded by these.

**The avenue digest moved again on the rebase onto `f5583e13`, and Lane R's
routes are why.** Before the rebase the same seed read
`f91542cc…`/2 274 overlay cells; after it, `4f2fb544…`/1 993. The difference is
the 281 cells the gate ramp used to rebuild at the east gate: the routes now stop
at the gate point instead of grading through the envelope, the road no longer
arrives above the ground, and the ramp writes nothing (§3c). Nothing in this
lane's own code changed between the two readings.

**The CORE builds to the same bytes on every seed; the plots follow the world,
as they must.** The core is anchor-relative and Kezamba's civic reference is
authored-fixed at y = 66 in every world (§1), so its cells land at the same
heights everywhere — which is also why its boardwalks, its stilt-hall flight and
its quay need no per-seed continuity check. A district plot is
projected from a reference column whose height the world decides, so its
read-back digest moves with the world; that is the reference-projection working.
An earlier version of this note claimed both were invariant and the independent
review of 2026-09-16 refuted it from this package's own evidence.

That review also found the earlier §6e quoting avenue numbers
(`ffbae1b7…`/110 753 → `c7aef663…`/110 793) that appear in no committed log and
do not reproduce. They were taken from a scratch run that the causeway-rail
commit then superseded and never re-recorded. The values above are the committed
ones, and the review reproduced them independently.

### (f) The fix round of 2026-09-16, proved in the built map

One full engine pass on `531802985935182545` at this branch's head:
`exit=0 errors=0 complete=1`, **0 ERROR, 0 ModError, 0 terrain-audit findings**,
`worst_plot_fall=5 worst_plot_submerged=0`, `sockets=262`, steady mean
**0.467 s** against a Lethariel control of 2.390 s (5.1x), roster
`guards 18/18 flair 163/163 vendor 7/7 quest 1/1 pending 0 spare 11`.

`evidence/20260915-kezamba/engine/built-map-proof.txt` reads the two blockers
out of that pass's own dumps:

```
== B1: the east and north avenue ends, the two courses a walker occupies
  east  x=47 lane -2  y1..2 = [(1, 'default:fence_junglewood')]  clear
  east  x=47 lane -1  y1..2 = (nothing)                          clear
  east  x=47 lane +0  y1..2 = (nothing)                          clear
  east  x=47 lane +1  y1..2 = (nothing)                          clear
  east  x=47 lane +2  y1..2 = [(1, 'default:fence_junglewood')]  clear
  ... the north end reads the same ...
  centre three lanes obstructed: 0

== B2: the east gate, from the avenue dump
  x=248 z=0  top solid y=-14  castle_stonewall_stair
  x=249 z=0  top solid y=-15  castle_stonewall_stair
  ...one node a column...
  x=256 z=0  top solid y=-22  castle_pavement_brick     <- the gate point
  x=258 z=0  top solid y=-21  dirt_with_canopy_litter   <- free terrain

  the verge at z=+3, where the threshold's post stands:
  x=253 -19   x=254 -20   x=255 -21   x=256 -22   (it comes down with the road)
```

Before the fix the same columns read a fence across all five lanes at `x = 47`,
a road at `y = -6` and terrain at `y = -21` one column outside it, and the
verge's kerbs and posts at `-6` with nothing between them and the ground.

## 7. Open points

1. **Kezamba has no chunk-edge seed.** The wave-2 brief asks every capital lane
   for an engine pass on a seed where its anchor root lands on a mapchunk edge.
   `capital_anchor_fixture.lua` says Kezamba has none: its anchor is at y = 66 on
   all nine seeds, so its root is at 67 and a chunk edge is 48 mod 80. The case
   the fixture exists for (Highcourt on the user's seed, anchor y 47, root 48)
   cannot arise here, and a fourth seed was run in its place. If a WP40 change
   ever moves this capital's authored reference to 47 or 127, the fixture's own
   `capital_anchor_edge_cases` row is what will say so.
2. **The piers stop at y = −2 and the cenote's bed is ten or more nodes lower.**
   The contract's core envelope is y [−2, 40], so a stilt leg reaching the bed
   would leave the authorized volume. What the player sees is a leg going into
   the water, which is what a stilt is; what a diver sees is a leg that ends.
   Deepening it is a change to `M.BOUNDS.capital_core`, which is the seam's and
   not this lane's.
3. **CLOSED: the gorge, and with it the footbridge that had no piers.** The
   trench was a graded route corridor and WP40's wave-2 route lane removed it
   (§3d). The bridge and the rim rail are gone with it; the mask, the refusals
   and a new planner-backed gate in `kezamba_lots.lua check` stay.
4. **The core lays two courses and not a terrace.** Like Highcourt's and Dur
   Brannoc's, the pad is subsoil and ground; where WP40's pad is already flat at
   the fitted height that is exactly right, and at Kezamba the measurement now
   says **all 6 380** dry columns are (§3d); before the routes moved, 188 of
   them were not.
5. **THE KING'S HALL IS THE WEAKEST THING IN THE RENDERS.** The independent
   review read it as "a red-brick manor with a timber roof" rather than a troll
   hall, and it was right: `capitals.king_hall` dresses itself in the CAPITAL
   vocabulary (`castle_paving`, `castle_wall`, `signature`), so the basalt handle
   rebinding `wall` alone changed nothing the eye sees. Four more rebindings now
   put the hall, its turrets and its podium in the same rock its platform is made
   of — `castle_wall`, `castle_wall_stair`, `castle_wall_slab` and
   `castle_paving` to the `darkage_basalt` family, all of them shapes
   `wp13/parts.lua`'s `SHAPED` table carries. What is still timber is the ROOF,
   and that is the gap below.
6. **The basalt roof family is unreachable.** `grug_decor` registers the full
   four-shape family for basalt, but `wp13/parts.lua`'s `SHAPED` table — the
   library's one list of the nodes that may carry a facedir — carries only
   `darkage_basalt_stair` and `darkage_basalt_slab`, not the inner and outer
   corners the roof rasteriser needs. Binding the basalt roof fails at
   construction time with "has no paramtype2". `parts.lua` is the shared library
   and not this lane's, so Kezamba's civic buildings wear basalt walls under
   their own timber roofs, which is the better building anyway (§2.4 is a
   statement about what a hall stands ON). Two names in `SHAPED` would open it.
7. **The four districts do not move with the world seed**, unlike Highcourt's.
   §4 above says why. A later package that wants variation here has the room for
   it: the lots are searched and could be re-searched per seed, at the cost of
   a per-seed lot derivation the manifest would have to be independent of.
8. **CLOSED on the rebase onto `f5583e13`: the gate ramp now rebuilds nothing.**
   The open point was that this lane could not check its `gate_level` against
   Lane R's actual route ends. It can now: `route_gates.lua --strict` prints the
   height R's route arrives at, and it equals the terrain height `gate_level`
   reads at all 36 gate-seed pairs (§3c). With the routes no longer grading
   through the envelope, `avenue.run` already arrives on the ground and
   `kezamba_ramp` rebuilds 0 columns on all nine seeds. It stays in the tree as
   a guard with a KAT rule behind it, and `M.gate_level` is still the one
   function to change if a future terrain package lifts the approach again.
9. **CLOSED by Lane D: `run_capital.sh` no longer aborts in `full` mode for an
   OPEN capital.** The full-mode digest gate used to grep the log for three
   labels — avenue, rampart, gate — and two of the three find nothing where
   there is no curtain wall; under `set -euo pipefail` that ended the script
   after a boot that had reported `exit=0 errors=0 complete=1`. Lane E met the
   same thing independently and Lane D fixed it in its round: each lookup is now
   explicitly allowed to find nothing and a label with no digest is skipped with
   a line saying so. The `full` pass on `f5583e13` prints
   `WP13 capital pass PASS: kezamba full` (§6d). The nine-seed tables of §6d
   predate the fix and were read from their logs. (This lane patched the runner
   itself with `|| true` and then reverted that on the coordinator's ruling; both
   commits were skipped on the rebase because the fix landed upstream.)

10. **No committed overlay digest yet.** `run_capital.sh` compares the built road
   against `tools/wp13/evidence/20260915-capital-terrain/<key>/<label>-digest-
   <seed>.txt`, and Kezamba has none, so its passes say "recorded (no committed
   value for seed … yet)". Freezing one is a decision with a number attached and
   belongs with the coordinator's merge, because the avenue digest moves with
   Lane R's route ends; the KAT's own overlay digest is the gate meanwhile.
11. **The user has not walked Kezamba.** Nothing here is accepted until they have.
   On seed 531802985935182545 the crossing of the two great avenues — the
   `arrival` landmark, with the guard banner on it — is at **(1800, 67, 1500)**.
   Walk EAST from it: the avenue runs eighteen nodes of boardwalk-on-pad and then
   out over the open cenote on piers, which is the thing this package exists for.
   The king's hall is south-east of the crossing, the cauldron court in the
   south-west corner of the pad, the moot house on the lake's west bank at about
   (1776, 71, 1530), and the quay with its anglers runs north along x ≈ 1782.
