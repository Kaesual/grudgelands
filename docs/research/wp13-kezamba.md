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

## 8. Wave 3, 2026-09-16: the unnatural plateau, and the fields that grew stone

Second increment, written on the wave-2 merge `f37a0c5b` ("Freeze the Dur
Brannoc corner digest on the gate seed"). Branch `wp13-w3-kezamba-terrain`.
Evidence: `tools/wp13/evidence/20260916-kezamba-terrain/`.

**It went through an independent review and a fix round on the same day**, and
the numbers below are the fix round's. What the review changed: the safety
argument for the apron was a theorem that did not survive its own measurement,
so the apron's lake cone was rebuilt on a form that is 1-Lipschitz by
construction and BOTH halves of the claim are now gated rather than asserted
(§8.3b, §8.9); the Lane S rebase list grew from one frozen digest to four
(§8.11.3); the vineyards grow a crop instead of wild grass (§8.8); and
`refreeze_avenue.sh` stamps the merge base rather than the branch head. One
review finding is deliberately not acted on: `tools/wp13/capital_terrain_fixture.lua`
is a shared file and rode in a lane commit (`57bb3d8b`) rather than its own, and
that commit is published history the coordinator has already reviewed. The fix
round changed nothing in it -- the rebuilt cone left `per_mille` at exactly the
77 and 95 the re-taken ceilings were taken against -- so there is no honest new
commit to put it in. It stays as it is, named here.

It answers the two findings the user raised about this capital in playtest 5
(2026-09-16, screenshots 10-12), verbatim:

> "The capital core in Kezamba stands on an unnatural plateau, the terrain has
> no natural course there."

> "Fields in Kezamba grow 'Mossy Stone'? That cannot be right."

### 8.1 The wall, measured before anything was changed

Nothing in the tree measured the thing the user saw.
`tools/wp13/capital_terrain_fixture.lua` measures CLIMBS -- the share of a
capital's ground with a land neighbour more than a jump up -- which is the right
instrument for a terrace riser and the wrong one for a face: a pad that ends in
a twenty-node wall has exactly one unclimbable column per edge column and
disappears into a per-mille figure. So the first thing this lane did was build
the instrument: `tools/wp13/kezamba_water.lua --walls`, which reports two
numbers over the +-250 envelope on all nine fixture seeds (and, since the fix
round, three more that gate the apron's own safety argument -- §8.9).

* **`perimeter`** -- the step between a column on the civic core's own edge and
  the column one outside it, over all 384 of them. The core is flat at the
  fitted reference by contract, so this IS the height of the pad's own face.
* **`land_land`** -- the worst fall between any two 4-adjacent LAND columns in
  the envelope.

On `f37a0c5b`:

| seed | pad face (max) | pad face (mean) | worst land wall | columns over the step |
| --- | --- | --- | --- | --- |
| `531802985935182545` | **17** | 7.9 | **29** | 505 |
| `8675309` | **21** | 10.0 | **27** | 895 |
| `15912857179583385436` | **19** | 9.2 | **29** | 702 |
| `0` | **28** | 15.0 | **39** | 2 678 |
| `1` | **23** | 9.7 | **35** | 996 |
| `2` | **27** | 11.9 | **38** | 2 096 |
| `42` | **19** | 9.9 | **27** | 575 |
| `12345` | **18** | 8.6 | **34** | 936 |
| `999999999` | **19** | 9.9 | **31** | 874 |

**Kezamba is the only capital this happens to, and that is a measurement.** The
same instrument on the gate seed gives a civic perimeter face of **0 on all 384
columns** for Highcourt, Dur Brannoc, Nhal Veyr and Gor Drazhak, and 0 on 376
of 384 for Lethariel. Their fitted reference is a median of their own core's
natural ground, so the ground just outside the core is already within the fill
budget of it.

### 8.2 Why, and it is two faces with one cause

`wp40/height.lua`'s `capital_terrace_value` applies the profile's cut/fill clamp
OUTSIDE the civic core and not inside it:

```lua
if civic_outside == 0 then
    shaped = reference                                   -- no clamp
...
if civic_outside > 0 then
    shaped = clamp(shaped, incoming - max_cut, incoming + max_fill)
end
```

Kezamba's civic reference is not a median of anything. It is raised to clear
WP40's authored `hydro_kezamba_cenote` -- the rule
`capital_natural_core_minimax_water_min`, §1 -- and that lake's surface stands
at y 65 while the wetland delta around the capital lies at y 36 to 45. So the
last core column is 66 and the first column outside it is `natural + 16`, which
on the gate seed is 55: **an eleven-node face, and up to twenty-eight over the
nine seeds.**

The same twenty-nine nodes appear a second time around the lake itself, and
there the mechanism is `water_banks.protect`: it lifts every land column within
two Manhattan steps of planned water to the water floor, so the cenote had a
two-column rim at y 65 with graded delta at 37 one column beyond it. The
measured worst 4-neighbour fall in the envelope, 27 to 39 nodes, is that rim and
not the pad. A lake standing twenty-nine nodes above the jungle on a
two-column kerb is the "no natural course" of the user's sentence as much as the
pad is.

### 8.3 The apron: one rule, shape-guarded, in `wp40/height.lua`

    the graded land of this capital may not stand more than one TERRACE STEP
    below the civic reference per column of distance from the civic core, nor
    more than one terrace step below the lake's own dry rim per column of
    distance from the lake's edge.

Two cones, `constant - step * distance`, and the shaped value is their MAXIMUM
with the clamped terrace. Each cone dies where it falls below the ground it is
drawn over, which is what makes it a SKIRT of about `fall / step` columns and
not a plateau: the fall is 20 to 30 nodes, so the skirt is ten to fifteen
columns wide. `max` of fields steps by at most the worst of them, so an apron
whose cones are `step`-Lipschitz adds no face of its own beyond `step`.

**AND THAT LAST SENTENCE IS WHERE THE FIRST TWO VERSIONS OF THIS PACKAGE WERE
WRONG.** The independent review of 2026-09-16 took the claim apart and it did
not survive; §8.3b is the whole of that story, because a stated theorem that is
the safety argument for a change to the shared height field is worth more space
than the change itself.

It is **shape-guarded**: `capital_terrace_value` takes `apron` as an eighth
OPTIONAL argument, exactly as it takes `banded` as a seventh, and
`fitting_grade_at` computes one only for `profile.shape == "cenote_terrace"`.
The five other capital shapes and the frozen scalar cases of
`module.quality_geometry_micro_kat` pass nothing, reach none of the new code and
keep their answer to the byte (§8.6). The review proved that independently by
mutation: changing the one string to `"terraced_grove"` moves Lethariel's field
and reverts Kezamba's to main's value, and nothing else.

### 8.3b The lake cone, three times, and the theorem it took to get one

The civic cone was never in doubt: `half_open_square_excess` is a Chebyshev
excess and is exactly 1-Lipschitz. The LAKE cone had to measure "how far outside
the lake is this column", and the first two answers to that were both wrong in
ways only a measurement finds.

**One: the nearest centreline is not the nearest edge.** The first version asked
`nearest_hydrology_segment`, which answers with the segment whose CENTRELINE is
closest. At (1864, 1634), five columns off this cenote's south shore, that is the
narrow first segment 62 columns away behind a half-width of 49 -- thirteen
columns outside it -- while the wide second segment is 72 away behind a
half-width of 70, two columns outside, which is where the water actually is. The
lake rim kept its 29-node wall, and the `--walls` measurement is what caught it.

**Two: the minimum over the candidate segments fixed that and left two faults of
its own**, and the independent review is what caught these. `simple_map.lua`'s
`bay_member` is the UNION of the segment capsules, so the distance outside it is
the MINIMUM over the segments -- correct as far as it goes. But:

* a segment leaves the candidate set at `max(half_width) + bank_blend_width` of
  its centreline, and at the WIDE end of a tapered segment that cut-off still
  sits nine columns outside the water, so the cone **fell off a cliff of its
  own** whenever a segment was pruned;
* `hydrology_half_width` interpolates along the segment, so the distance carries
  the reach's own taper gradient -- measured at **0.460** on this cenote's first
  segment and **0.401** on its third -- on top of the distance's own 1, and the
  cone therefore moved up to 1.46 x 3 = 4.4 nodes a column.

Measured exhaustively over the window the cone can reach, its own worst
4-neighbour step was **54 nodes**, eighteen terrace steps. Most of that was
invisible because the apron is a `max` floor and the cone was far below the
ground where it was roughest, but it leaked into the shipped field as up to a
**6-node face (9 on seed 0)** where the ground had had none -- one of them
seventeen nodes east of the very shore §8.11 sends the user to stand on.

**Three: a distance to a disc is a real distance.** `isqrt(dx*dx + dz*dz) - r`
is 1-Lipschitz on the integer lattice (the true distance is, and an integer
floor of a 1-Lipschitz function moves by at most one); the MINIMUM of finitely
many 1-Lipschitz functions is 1-Lipschitz; `max(0, D - hold)` and a
multiplication by `step` keep it so. So the cone measures its distance to the
reach's **sample discs**, all of them, with no interpolation to carry a gradient
-- and it is exactly `step`-Lipschitz by CONSTRUCTION rather than by assertion.

**The discs are densified until they cover the mask, and that number is
measured too.** The mask is the authored sample discs UNION the tapered capsules
between them, and on this cenote's four authored samples alone the capsules add
a sliver of 291 of the mask's 30 354 columns (0.96 %) that no disc covers. That
sliver is small, but it is enough to push the SHORE HOLD up: `water_banks.protect`
lifts every land column within two Manhattan steps of planned water to the water
floor whatever the apron says, so the cone must be at or above that floor on
every column `protect` can touch, and on four discs the worst such column stands
6 outside them -- a hold of 6 and four more columns of flat rim than the water
needs, which measured three district lots out of legality. Interpolating extra
samples along each segment closes the gap, and an interpolated disc is as much a
disc as an authored one:

| spacing | authored only | 32 | **16** | 8 | 4 |
| --- | --- | --- | --- | --- | --- |
| worst distance from a MASK column to the nearest disc | 5 | 1 | **0** | 0 | 0 |
| the same for a land column in `protect`'s ring | 6 | 3 | **2** | 2 | 2 |

Sixteen is the coarsest spacing at which the discs cover the mask completely and
the hold can stay at `protect`'s own two. It turns four authored samples into
fourteen discs.

**And the one window that remains is provably inert.** A disc stops being asked
at `half_width + 64`, where its cone stands 186 nodes below the lake's rim --
y -120 for this capital, below `WATER_LEVEL - 24`, which is the value the height
session itself returns for a column outside the map. A disc that far away can
never be the maximum of anything. That is exactly the guarantee the
`maximum_half + bank_blend_width` window did NOT give, and `--walls` gates it as
`live_prune_edges`: the count of columns that lose their last disc while the
cone still stands above that floor, which must be zero.

Measured the same way as the two formulations before it:

| formulation | cone's own worst 4-neighbour step | worst land wall in the envelope (gate seed) | lots the terrain refused |
| --- | --- | --- | --- |
| nearest segment | (the rim kept its 29-node wall) | 29 | -- |
| minimum over candidate segments | **54** | 8 | 1 |
| minimum over four authored discs, hold 6 | 3 | 6 | 3, one of them unrepairable |
| minimum over fourteen densified discs, hold 2 | **3** | **8** | **1** |

and `tools/wp13/kezamba_water.lua --walls` gates the cone's own step with a
ceiling that is the terrace step and is not a tuning knob.

### 8.4 What the apron did, on nine seeds

| seed | pad face | worst land wall | columns over the step | faces the apron is the high side of |
| --- | --- | --- | --- | --- |
| `531802985935182545` | 17 -> **3** | 29 -> **8** | 505 -> **53** | **0** |
| `8675309` | 21 -> **3** | 27 -> **9** | 895 -> **223** | **0** |
| `15912857179583385436` | 19 -> **3** | 29 -> **8** | 702 -> **142** | **0** |
| `0` | 28 -> **3** | 39 -> **8** | 2 678 -> **900** | **0** |
| `1` | 23 -> **3** | 35 -> **8** | 996 -> **380** | **0** |
| `2` | 27 -> **3** | 38 -> **8** | 2 096 -> **746** | **0** |
| `42` | 19 -> **3** | 27 -> **8** | 575 -> **49** | **0** |
| `12345` | 18 -> **3** | 34 -> **11** | 936 -> **274** | **0** |
| `999999999` | 19 -> **3** | 31 -> **8** | 874 -> **208** | **0** |

**The pad's face is the terrace step on every one of the nine seeds**, which is
the user's ruling as a number, and `--walls` is the gate that holds it. The last
column is the fix round's answer to the independent review: with the cone built
on the reach's densified sample discs, **the apron is the binding constraint on
the high side of no over-step face at all**, on any seed. The over-step columns
that remain are wild ground the apron never touched -- the review measured five
sixths of them that way on its own instruments, out in rings 75 to 200 from the
pad. The west
pad edge on the anchor's own row, seed 531802985935182545, before and after:

```
x -52 -51 -50 -49 -48 -47
    55  55  55  55  66  66      before -- 11 nodes in one column
    55  57  60  63  66  66      after  -- a flight at the race's own step
```

and the lake's south shore, which was the taller of the two walls:

```
before   ... 39 39 39 39 | 65 65 65 65 ~~~      (a two-column kerb at the water)
after    ... 39 42 45 48 | 51 54 57 60 63 66 ~~~
```

`measurements/lake-rim-before.txt` and `lake-rim-after.txt` carry both windows
whole; `renders/pad-edge-west.png` is the section a reader can count the steps
in and `renders/terraces-plan.png` the plateau from above, before beside after.
In the plan the change is one thing: where the pad and the lake each ended in a
single hard edge, both now carry a ring of concentric contour bands -- the
skirt.

### 8.5 What it costs, in the metric that goes the other way

The apron deliberately REPLACES gentle wild ground with terrace risers of
exactly 3, and `capital_terrain_fixture.lua` counts every one of those as
unclimbable. On the two gate seeds, in that fixture's own +-128 window:

| | seed 5318... | seed 8675309 |
| --- | --- | --- |
| `climb3` (a riser of exactly the step) | 731 -> **1 771** | 1 014 -> **2 357** |
| `climb5plus` (a wall no terrace explains) | 272 -> **17** | 300 -> **39** |
| `max` (the tallest riser anywhere) | 17 -> **8** | 21 -> **8** |
| `per_mille` | 59 -> **77** | 71 -> **95** |

The number that went up is the one that counts terraces; the numbers that went
down are the ones that count walls. Kezamba's ceiling in that fixture was
re-taken to 85 and 105 and the header records the trade. **The fix round's
rebuilt cone did not move the ceiling again**: it left `per_mille` at exactly 77
and 95 while pushing `climb5plus` down further (23 -> 17 and 45 -> 39) and the
tallest riser on the second gate seed from 10 to 8, so the committed ceilings
still hold with the headroom they were taken with. **Two rows of that
fixture's header were already stale before this lane** and are left alone: Dur
Brannoc measures 77 and 61 on `f37a0c5b` against the 81 and 66 it records, and
Kezamba 59 and 71 against 62 and 74. Something between 2026-09-15 and that
commit improved both and re-took neither ceiling.

### 8.6 The other five capitals are byte-identical

A SHA-256 over the final terrain height AND the land/water class of every one of
the 251 001 columns within +-250 of each capital anchor, on three seeds (both
gate seeds and the user's):

```
luajit tools/wp13/evidence/20260916-kezamba-terrain/capital_fields.lua <repo> <seed>
```

**Fifteen of the eighteen rows are unchanged to the byte** and the three that
move are Kezamba's own. `measurements/capital-fields-before.txt` and
`-after.txt` carry them. With it:

* the six start identity digests: SHA-256 of
  `start_identity.lua`'s output is `0bbf87a7253deadca55951752adde73e82c31cd10878dc64ef6d44af91ad1f5f`,
  the value wave 1 recorded;
* `tools/wp13/highcourt_identities.lua` output identical;
* `tools/wp40/quality_geometry_micro_kat.lua` byte-identical -- the frozen
  scalar cases keep their answers, which is what proves the apron changed where
  the terrace lattice is READ and not how the civic core, the civic blend or the
  cut/fill clamp behave;
* `bash tools/wp40/r7/run.sh unit` byte-identical, PASS;
* the WP13 interpreter pair: `WP13 final micro PASS` under LuaJIT and under the
  engine's bundled PUC 5.1 with the SAME `output_sha256`,
  `1c33cb5d0aeb3b7ff251f8f73b94fbfb7422283528cf3745eec44c1926e5deb3`. The
  digest moved from `41ed5eb2...` because this lane's own KAT row moved -- the
  Kezamba row gained a `crops/` section and its plot-cell count fell with
  `totem_f2`'s smaller yard -- and for no other reason;
* `tools/wp13/capital_terrain_fixture.lua`: ten of its twelve rows byte-identical
  (five capitals x two gate seeds), the two Kezamba rows moved as §8.5 records.

**`tools/wp40/quality/final_micro.lua` WAS ALREADY RED ON MAIN, and this lane
did not touch what it fails on.** It stops at
`tools/wp40/r7/node_semantics_fixture.lua`'s `missing override target
default:shovel_wood`, which is `grug_materials` overriding an item the
node-semantics harness never registers; run against the untouched `f37a0c5b`
checkout it stops at the same assertion with the same message. Every data line
the two runs print before that point is identical
(`kat/wp40-quality-final-micro-main.txt` and `-branch.txt`; the "main" file's
tracebacks name the user's main CHECKOUT, which at the time stood at
`f37a0c5b` with nothing merged into it -- the independent review re-took the
same comparison on a clean `git archive f37a0c5b` extract and got the same
assertion and the same data lines, which is the stronger form of the claim). The part of that
runner a CAPITAL TERRAIN CHANGE moves -- `quality_geometry_micro_kat.lua`, which
it calls last -- runs standalone and is byte-identical, which is the check that
matters here. The same fixture passes on its own
(`dofile("tools/wp43/fresh_server_fixture.lua")(<absolute repo>)` -> `result
pass`), so the defect is in-process ordering inside that runner and belongs to
the lane that owns it.

### 8.7 The one lot the terrain moved, and why `repair` and not `pack`

`kezamba_lots.lua check` went red on exactly one of the 52: `totem_f2`, reach 11
at (66, 154) on the lake's north bank, which now looks up a 33-node slope inside
its own cleared airspace. Re-running `pack` would have re-invented the whole
layout for one lot, which is the mistake the Highcourt lane recorded
(`wp13-capital-terrain.md` §3). `tools/wp13/kezamba_lots.lua` therefore grew a
`repair` mode with the Highcourt rule: keep every legal lot, move only an
illegal one, to the nearest legal centre that clashes with none of the other 51.

    luajit tools/wp13/kezamba_lots.lua <repo> repair

**And a reach ladder, because the first version could not repair it at all.**
Over the whole totem band on the packer's own lattice exactly TWELVE reach-11
centres are legal, all of them in the far north-east corner 150 nodes from the
district's spine -- and **the same twelve, in the same corner, on the tree
WITHOUT the apron.** The shortage is the lake's, not this change's. At a reach of
8 there are 39, several of them ten nodes from where the lot already stood. So
`repair` drops a fill lot to the next smaller size before it gives up, and
prefers a smaller lot in its own quarter to a full-sized one in someone else's.

**A BUILDING plot never shrinks, and that rule was written after it mattered.**
A fill lot's yard IS its reach, so a smaller reach is a smaller yard and nothing
else; a building plot has a part projected into it, and `kezamba_kat.lua`
already refuses a composition "wider than the lot it was measured on". While the
fix round was trying a wider shore hold, three lots went illegal at once and one
of them was the reach-13 `totem_6`; the ladder would have shrunk it. It now
offers a smaller size to `kind == "fill"` only, and a building plot moves or the
repair says out loud that it could not.

Two rounds of `repair`, both recorded:

```
2026-09-16  kezamba_repair_move  totem_f2  66 154 -> 60 158  moved 10  reach 11->8
   fix round  kezamba_repair_move  totem_f2  60 158 -> 60 158  moved 0   reach 8->5
              kezamba_repair       52  moved 1  unrepairable 0
```

Afterwards, on all nine seeds: `check` 52 of 52 legal, `walk` PASS (worst kerb
face 3 against a skirt of 6, worst approach 3 a column), `gates` PASS (step 0
and 0 floating cells at all 36 gate-seed pairs, and `kezamba_ramp` still rebuilds
nothing). Fifty-one of the fifty-two lots are exactly where the packer put them.

### 8.8 The fields that grew stone

Two different plots read as stone and each for its own reason, which is why the
KAT now counts each of the five separately rather than averaging them.

**The three CROP FIELDS grew nothing at all.** `dressing.crop_rows` falls back
to `ground_patch` and `planter_soil` for a race that binds neither `crop_soil`
nor `crop`, and for the troll palette BOTH of those are `grug_nodes:mud`: the
fields were a rectangle of bare mud, and §5 of this note argued that was "what a
field in a flooded basin is". It is not; a field has to read as a field.
`wp13/troll_palette.lua` gained an `M.CROP` handle and `kezamba_plot.lua` the
`handle = "crop"` that carries it, on those three plots and on nothing else --
binding `crop` everywhere would change `dressing.plant`, which reads
`flower or crop or grass_tuft`, and put reeds in every grove and pasture.

* `crop` is **`default:papyrus`**: a reed, which is what a troll basin grows. It
  is registered by `default`, it is already one of `wp40/r7_content.lua`'s
  accepted content rows so the content channel resolves it without a new name,
  and its only callback is `after_dig_node`, which runs on dig -- none of the
  `META_FIELDS` a VoxelManip-written cell cannot serve.
* `crop_soil` is **`grug_nodes:tilled_soil`**, for the reason the human palette
  records and one this race adds. The first: it carries no `spreading_dirt_type`
  and default's "Grass spread" ABM does not name it, so a field stays a field.
  The second: default's "Grow papyrus" ABM lifts a reed to four nodes only when
  the node UNDER it is one of six `default:dirt*` surfaces
  (`default/functions.lua`, `grow_papyrus`) -- tilled soil is not one of them, so
  these rows stay the one course the blueprint drew and the field the KAT
  measured is the field the player walks past a week later.

**The two VINEYARDS were literally paved.** `dressing.planter` kerbs the
PERIMETER of the rectangle it is given in the `planter` role -- for this race
`default:mossycobble` -- and fills the INTERIOR with soil and a tuft.
`kezamba_districts.lua` was asking it for rectangles of DEPTH ONE (`z, z`), in
which every cell is perimeter and none is interior: seven solid rows of mossy
cobble across each vineyard, 145 cells of stone and 0 plants. Two beds nine rows
deep fill the same yard with the same two long kerbs each: **110 cells of stone
and 268 planted.**

**And they grow a crop, not a lawn.** The first version of this round stopped at
the bed geometry, and `dressing.planter` fills an interior from two fixed roles
-- `fern` for one cell in three and `grass_tuft` for the rest -- which for this
race are `default:fern_1` and `default:grass_1`. The independent review called
that "the weaker half of the crop answer": the stone was gone and a plot named a
vineyard was a weed patch. `wp13/troll_palette.lua`'s `M.VINE` rebinds both
roles to `default:junglegrass` -- the tall leafy growth this race's own palette
already binds `undergrowth` to, so the KAT's `tend` and `forage` feature sets
accept it unchanged -- and `kezamba_plot.lua`'s `handle = "vine"` carries it to
those two plots and nothing else. BOTH roles and not one: a bed of a single crop
reads as cultivation, and the alternation between two wild species is the weed
patch. The fields keep papyrus, so the two kinds of planted ground still read
apart. `renders/field-shore-vineyard-before.png` and `-after.png` are seven grey
ridges and two deep green beds.

Measured on the composition itself, and reported by the KAT as its own section:

```
crops/default:papyrus/grug_nodes:tilled_soil/
  shore_gardens=189/0, shore_vineyard=268/110, vine_common=189/0,
  vine_kitchen=27/0, vine_terraces=268/110        (grown/paved cells)
```

405 papyrus cells over the three fields, where there were none.
`renders/field-shore-gardens-before.png` and `-after.png` are the same field
drawn with the real node textures -- a flat mud rectangle, then rows of reeds on
tilled furrows -- and `renders/field-shore-vineyard-before.png` is the finding
itself: seven solid ridges of mossy cobblestone in a plot called a vineyard.

### 8.9 Verification

**The gates that turn red if this breaks.** Every one was run against a mutant
tree built by symlink from this branch, with one thing broken on purpose
(`tools/wp13/evidence/20260916-kezamba-terrain/mutations.txt`):

| the mutation | the gate, and what it says |
| --- | --- |
| the three fields lose `handle = "crop"` | `kezamba_kat`: "the work socket shore_gardens_work_garden_a does farm but faces no farm feature within three nodes" |
| a raised bed is one row deep again | `kezamba_kat`: "the garden shore_vineyard lays 145 cells of the palette's `planter` (default:mossycobble) against 2 planted ones, which is a field of stone" |
| `M.CROP` binds nothing | `kezamba_kat`: "wp13/troll_palette.lua's M.CROP binds no crop and no crop_soil, so dressing.crop_rows falls back to the mud pair and the fields grow nothing" |
| the apron is gone (main's own `height.lua`) | `kezamba_water --walls`: **36 FAIL lines over the nine seeds** -- the pad's face, the land wall, the apron-face count and the drift check all fire at once |
| the lake cone goes back to interpolated capsules | `kezamba_water --walls`: "the lake cone's own worst 4-neighbour step is 54 against the terrace step of 3, so wp40/height.lua's Lipschitz claim is false" |
| `height.lua` stops densifying the discs while the gate keeps its own copy | `kezamba_water --walls`: "1 420 column(s) on 531802985935182545 stand below this file's copy of the apron floor, which a `max` cannot do: the copy has drifted from wp40/height.lua" -- the drift detector, on every seed |
| the disc window shrinks from 64 to 8, so pruning bites while the cone still matters | `kezamba_water --walls`: **three gates at once** -- "659 column(s) lose their last disc while the cone still stands above -23, which is a pruning cliff and not an inert window", `apron_faces` 0 -> **129** against its ceiling of 9, and a 15-node land wall against a ceiling of 14 |

That last row is also what says the `apron_faces` ceiling is a LIVE gate and not
a dead number: it separates the shipped 0 from a broken 129.

**And the theorem is a number now.** `--walls` reports three things the first
version of this package only asserted, all of them on every one of the nine
seeds:

| | measured | ceiling |
| --- | --- | --- |
| `cone_step` -- the lake cone's own worst 4-neighbour step, over 77 397 columns, from the authored geometry alone | **3** | 3, the terrace step, which is the theorem and not a tuning knob |
| `live_prune_edges` -- columns that lose their last disc while the cone still stands above the floor the height session returns outside the map, which is the pruning cliff the review found, back again | **0** | 0 |
| `apron_faces` -- over-step falls in the SHIPPED field where the apron is the binding constraint on the HIGHER column, i.e. a face the apron made or deepened | **0 on all nine seeds** | 9 (the coordinator's, from the fix round; the measurement is far under it and it can be tightened whenever they want) |
| `apron_below` -- columns standing below the apron floor, which a `max` cannot do and which is the cross-check that `--walls`'s copy of the cone has not drifted from `height.lua`'s | **0 on all nine seeds** | 0 |

**The engine.** `tools/wp13/run_capital.sh`, port block 31100-31199, one
headless server at a time, every boot under `nice -n 19`, and every one of them
under two minutes wall clock on a workstation carrying seven WP13 lanes.

Three `full` boots -- both gate seeds and the user's world seed -- and one
`field` boot:

| seed | chunks | steady mean | Lethariel control | ratio | worst plot fall | submerged | sockets | ERROR | ModError | audit findings |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `531802985935182545` | 66 | **0.482 s** | 2.280 s | 4.7x | 5 | 0 | 262 | 0 | 0 | 0 |
| `8675309` | 64 | **0.495 s** | 2.493 s | 5.0x | 6 | 0 | 262 | 0 | 0 | 0 |
| `15912857179583385436` | 66 | **0.449 s** | 2.139 s | 4.8x | 5 | 0 | 262 | 0 | 0 | 0 (1 Highcourt's, below) |

`guards 18/18 flair 163/163 vendor 7/7 quest 1/1 pending 0 spare 11 residents
163 walkers 21` on all three, and `WP13 capital pass PASS: kezamba full` on all
three.

**One load-time terrain-audit finding on the user's seed, and it is
HIGHCOURT'S.** `WP13 highcourt: the plot martial_wood_yard at offset -196,-212
... rise 10 against a clear of 8` -- which is, word for word, the round-1
playtest finding `tools/wp13/capital_lots.lua`'s own header records as the
reason that tool exists. It cannot be this lane's: Highcourt's whole +-250
terrain field is byte-identical on that seed (§8.6), and the apron is guarded on
`cenote_terrace`. Kezamba's own count is **0 on all three seeds**, and it is
carried here because a warning in this lane's log deserves a sentence rather
than a filter.

**THE BUILT CORE DID NOT MOVE, and that is the strongest single number in this
section.** `core_road_digest` -- the probe's SHA-256 over the 6 611 road cells
it reads back out of the finished map inside the civic core -- is
`eafdce922db68f98366c0da49823bfe9bb1e81d63328b6d2315a748af0203056` on all three
seeds, which is exactly the value §6d recorded before this lane existed. The
apron never touches a column with `civic_outside == 0`, so the pad is the same
pad and the city on it is the same city, to the byte, in the built map.

**The avenue digest DID move, and is re-frozen from the pass that moved it**
(`tools/wp13/evidence/20260915-capital-terrain/kezamba/avenue-digest-531802985935182545.txt`,
`4f2fb544...` -> `cdadbafc...` -> `96307e93...` over the same 1 993 overlay
cells -- the second move is the fix round rebuilding the cone, and the value
was written by `refreeze_avenue.sh`'s own boot, not copied out of a log). The road walks
the surface the seam hands it, and the surface outside the core is what this
lane changed. The other two seeds measured `6fd30564...` (3 475 cells) and
`3b900110...` (2 607 cells) and are recorded rather than frozen. Re-taking the
frozen one is one command, so the coordinator can re-take it again after the
Lane S rebase without reading a log:

    bash tools/wp13/evidence/20260916-kezamba-terrain/refreeze_avenue.sh [SEED]

which boots, refuses anything but `event=complete` with zero ERROR, zero
ModError and zero terrain-audit findings, and writes the file from the probe's
own line. It takes its port from `WP13_CAPITAL_PORT` (Lane K's block is only
the default) and stamps `main=` with the MERGE BASE rather than the branch head,
which is what that field means in the older digest files and what the next
reader needs -- both corrections from the independent review.

`field` mode on the gate seed is the check no offline fixture can make of
itself, and it makes a second one this round:

```
kezamba_field reach=250 core_wet=2645 core_disagreements=0
  envelope_wet_engine=30354 envelope_wet_mask=30354 envelope_disagreements=0
  dry_y=66..66 wet_y=53..55 reference_y=66 water_surface_y=65
kezamba_field PASS: the engine's own field agrees with the committed mask on
  every one of the 251001 columns it covers
```

so the wet mask, the civic reference and the water surface did NOT move --
`wp13/kezamba_lagoon.lua` needed no re-emit and `--verify` is green on all nine
seeds. And the engine's own height field over those 251 001 columns is
**byte-identical to the offline planner's** (`36ed1258...`), which is what makes
every offline number in this section the running server's answer too.

### 8.10 What a review should look at

1. **`fitting_grids.apron.value`'s loop over the reach's sample DISCS, and why
   it is not a loop over segments.** §8.3b carries all three formulations and
   what each measured; the short version is that a distance to a disc is a real
   distance and therefore 1-Lipschitz, while a distance to a tapered capsule
   computed as `axis - interpolated half-width` is neither 1-Lipschitz nor
   continuous across the candidate-set boundary. Both earlier versions looked
   more correct than this one and measured worse. The gate is
   `kezamba_water --walls`'s `cone_step`.
2. **The shape guard.** `profile.shape == CAPITAL_APRON.shape` is the whole of
   what keeps the other five capitals byte-identical, and §8.6 is the proof
   (the review proved it again by mutation: point the guard at
   `"terraced_grove"` and Lethariel's field moves while Kezamba's reverts).
   There is no second place where the apron can leak in: `capital_terrace_value`
   ignores a nil `apron` on exactly the path it took before.
3. **The apron can raise a land column above `max_fill`, on purpose.** At the
   pad's edge it fills up to 30 nodes over the natural ground where the profile
   budgets 16 (the review measured the 30). That is the point -- the budget is
   what built the face -- but it is a deliberate departure from the profile row
   and belongs in a reviewer's head. What it never does is CUT: the review
   measured `apron_lowered_columns = 0` and `raised_above_reference = 0` on all
   nine seeds, so every column the apron touches it lifts, and never past the
   civic reference.
4. **The crop and vine handles are narrow on purpose.** `dressing.plant` reads
   `flower or crop or grass_tuft`; binding `crop` on the base troll palette
   would change every grove, pasture and terrace socket's feature cell, and
   rebinding `fern`/`grass_tuft` there would change every one of them again.
   Both handles reach exactly the plots that are a field or a garden.
   `CAPITAL_APRON` is one table and not four module locals for a duller reason:
   `construct` sits at Lua 5.1's 60-UPVALUE ceiling as well as its 200-local
   one, and four constants named from inside it would not compile.
5. **`totem_f2` is smaller now, not moved far.** §8.7 carries the measurement
   that says there was nowhere else for it at reach 11, on this tree and on
   main's. The rule that a BUILDING plot may not shrink was written in the fix
   round, after a wider shore hold briefly made three lots illegal at once and
   one of them was a reach-13 plot the ladder would happily have shrunk.
6. **`--walls`'s copy of the cone.** The gate measures a function that lives
   inside `wp40/height.lua`'s construction closure, so it has a copy of it, and
   a copy can drift. `apron_below` is what turns a drift red: the shipped
   ground may never stand below the apron floor, because the apron is a `max`.
   It is 0 on all nine seeds; if a future edit changes the cone in `height.lua`
   and not in the tool, it stops being 0.

### 8.11 What is open

1. **THE CENOTE'S BED IS STILL A TWELVE-NODE WALL, under the water.**
   `hydrology_scalar_at` gives a wet column `water_y - varied_depth(depth)`, so
   `deep_cenote` is a flat-bottomed bowl with vertical sides: the land-to-water
   fall measured 14 to 16 nodes before this change and measures 14 to 16 after
   it. It is not the `cenote_terrace` SHAPE, it is the `deep_cenote` HYDRO
   PROFILE, and every reach in the world goes through the same function -- so it
   is not this lane's to change under the brief it was given, and it is entirely
   below the water surface, which is why it is not the wall the user saw. The
   shape of the fix is the same cone: bed = `water_y - min(depth, step * distance
   inside the mask)`, guarded on `mask_semantic_id == "hydro_deep_cenote_v1"`,
   which would make the basin the "broad stepped central cenote" that
   `docs/design/world_zones.md` §9 already calls it. `--walls` reports the
   number and deliberately does not gate it.
2. **The residue is the step band on mixed ground, as before.** 49 to 900
   columns of the envelope still fall more than the terrace step to a
   4-neighbour, worst 8 to 11, and **not one of them is a face the apron is the
   high side of** (`apron_faces` = 0 on all nine seeds, §8.9). The independent
   review measured the same thing from the other side on the user's seed: of
   217 over-step pairs, 182 were wild ground the lane never touched, out in
   rings 75 to 200 from the pad, and the worst single fall was 150 to 200 nodes
   away from it. `wp13-capital-terrain.md` §"What is open" carries the operator
   that would close the band's own residue and the cost it would have to be
   measured against.
3. **THE LANE S REBASE MOVES FOUR FROZEN THINGS, NOT ONE**, and the independent
   review of 2026-09-16 is what found the other three. Lane S builds piers and
   rails for every capital's water crossings, and Kezamba's two avenues cross
   315 columns of open cenote, so everything downstream of `avenue.lua` over
   this ground moves with it. Nothing in this lane's SOURCE depends on Lane S --
   K touches `wp40/height.lua`, four `wp13/kezamba_*`/`troll_palette` files and
   four tools, and S owns none of them -- the whole coupling is frozen digests:

   | what moves | how it is re-taken |
   | --- | --- |
   | `evidence/20260915-capital-terrain/kezamba/avenue-digest-531802985935182545.txt` | `bash tools/wp13/evidence/20260916-kezamba-terrain/refreeze_avenue.sh` (one engine pass, refuses anything but a clean one) |
   | `evidence/20260916-kezamba-terrain/kat/kezamba-kat-luajit.txt` and `-puc51.txt` | the KAT's `overlay/…/3369caec…` row is built from `avenue.lua` over the ground; re-run it under both interpreters and compare |
   | `evidence/20260916-kezamba-terrain/kat/micro-output.tsv` and `micro-pair.sha256` | `tools/wp13/final_micro.lua` concatenates that KAT row, so `1c33cb5d…` moves with it. **`final_micro.lua`'s rows are in Lane S's declared ownership**, which makes this a live cross-lane collision rather than a K-side chore |
   | `measurements/lots-gates-after.txt` | `luajit tools/wp13/kezamba_lots.lua . gates` reads where the avenue arrives, and `kezamba_ramp` is Lane S's file |

   Only the gate seed has a committed avenue digest; the second gate seed's is
   recorded in `engine/full-8675309/overlay-digests.txt` rather than frozen.
   The fix round is itself the rehearsal for that checklist: rebuilding the lake
   cone moved the ground, and the avenue digest, both KAT outputs, the micro
   pair and the `gates` measurement all moved with it and were all re-taken the
   way the table says.
4. **NOBODY HAS LOOKED AT THE NEW SHORE FROM EYE HEIGHT.** Every render in this
   package is planner-drawn -- a contour plan and a block section -- which is
   the right picture for geometry and the wrong one for the complaint, which was
   about a look. The independent review said so and it is right. It also names
   the thing that will be most visible once the land around it stops being
   unnatural: the cenote begins as a sheer eleven-node pit at the waterline
   (open point 1), and Luanti water is translucent.
5. **A 3-node riser is not walkable, and the pad edge is now made of them.** The
   player steps up one node, so the new skirt is scenery rather than a stair;
   the ways up remain the avenues and the four gates, which `kezamba_lots.lua
   gates` holds at step 0 on all 36 gate-seed pairs. The brief authorised step 3
   verbatim ("terraced (step 3, the race's own step)") so this is inside the
   ruling, but the review is right that it reads differently under the feet than
   on a contour plan, and it is worth asking the user at playtest 6 whether
   "steps you cannot climb" is what they meant by terrain that runs naturally.
6. **The user has not walked the new ground.** The place to stand is the west
   gate approach at about (1745, 55, 1500) looking east: the pad edge that was a
   wall is the flight of four steps in front of you, and the independent review
   measured that frame clean -- **0 over-step pairs within 30 nodes in every
   direction, against 61 with a worst of 17 before**. The lake's south shore, at
   about (1866, 40, 1640) looking north, is the taller one: ten steps up to the
   water, and in the same frame 14 over-step pairs with a worst of 7 where there
   were 100 with a worst of 29.
