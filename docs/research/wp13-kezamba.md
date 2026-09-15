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
flat at the fitted reference height". At Kezamba that is true of **6 192 of its
9 025 columns and false of the other 2 833**, and the first thing this lane did
was measure it rather than discover it in a render.

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
| dry core columns at the reference | 6 192 – 6 327 depending on seed |
| dry core columns BELOW it | **53 (seed 531802985935182545) to 188 (seed 0)**, reaching 8 to 26 nodes down |

The lake is WP40's own `hydro_kezamba_cenote`, a `deep_cenote` of four basins at
**fixed world coordinates** (`wp40/source/simple_map.lua`), and the reason its
surface sits one node under the pad is the water-correction package of
2026-09-13 ([wp40-water-road-polish.md](wp40-water-road-polish.md)): "the civic
water minimum is now applied as a hard floor after that compromise". The
off-reference dry columns are one narrow **ravine** running into the pad from its
south-west edge; its footprint is the same in every world and only its depth
moves.

The engine's own terrain probe agrees with the offline reading: nine
`run_capital.sh … terrain` boots produce nine **identical wet masks** over the
envelope grid and report the anchor at (1800, 66, 1500) in every one.

**Both masks are therefore committed**, as `wp13/kezamba_lagoon.lua` — generated
by `kezamba_water.lua --emit`, re-checked column for column against the planner
on nine seeds by `--verify`, and asserted by the KAT. A capital core is a fixed
cell list in anchor-relative coordinates; it may be authored around a lake only
if the lake is in the same place in every world, and that is now a measurement
and not an assumption.

## 2. What shipped

| File | Change |
| --- | --- |
| `wp13/kezamba_lagoon.lua` | **new, generated**: the cenote and the ravine as inclusive x runs per z, with the reference height and the water surface |
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
| `tools/wp13/kezamba_water.lua` | **new**: the nine-seed water and pad survey, and the mask generator |
| `tools/wp13/kezamba_lots.lua` | **new**: `capital_plots.lua`'s four rules asked of the planner on nine seeds, before a composition exists |
| `tools/wp13/kezamba_kat.lua` | **new**: acceptance for the masks, the core, every plot, the sockets and the overlay |
| `tools/wp13/final_micro.lua` | the new KAT joins the interpreter pair |
| `docs/design/settlements.md` | the open capital, the threshold, and the capital with a lake in it |

Not touched: the six start compositions, `highcourt*.lua`, `dur_brannoc*.lua`,
`avenue.lua`, `wall.lua`, `capitals.lua`, `buildings.lua`, `parts.lua`,
`palette.lua`, `dressing.lua`, `layout.lua`, `interiors.lua`, `roofs.lua`, and
every WP40 file but the roster row. §6(b) carries the proof.

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
| South-east of the crossing | the **king's hall**, the library's basilica on its podium with its great door on the throne approach. It is east of the axis and not on it, because the RAVINE takes the ground west of the approach from z −47 to z −21 |
| The lake's west bank | the **moot house**: a stilt hall whose flight stands on the shore, whose platform stands half on the bank and half on piers over the water, and whose walkway runs on out over the cenote. This is the contract's troll row built out of the terrain rather than on top of it |
| The quay | the waterline from z 6 to z 44, kerbed in basalt; the fishmonger's counter, three drying racks and the three anglers on the shore columns |
| South-west | the **cauldron court** — this capital's market cross is four pots on a basalt hearth ring with a fire between them — and the carvers' yard |
| North-west | the **shaman's shrine** on its basalt platform, which carries the capital's one quest shell |
| The gorge | railed along its rim on a two-node rhythm and crossed by one plank footbridge where it is narrowest |
| The boundary | no wall and no parapet: totem posts at the gate mouths, and jungle |

Measured populations of the finished core: 6 107 pad columns, 2 645 lagoon,
273 ravine, 367 boardwalk cells, 53 piers, 80 quay stones, 60 bridge cells,
4 totem posts, **5 emergent kapoks and 7 jungle trees** (the contract's "emergent
trees kept" as a number the KAT holds a floor under), 54 sockets, 68 038 cells.

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
world (§1), so the core's own boardwalks, its stilt-hall flight, its quay and its
gorge bridge are the same cells at the same heights in every world — the engine's
own read-back digest says so (`core_road_digest` identical on four seeds, §6d).
A district plot is projected from a reference column whose height the world
decides, so the step between it and the ground beside it is a per-seed question,
and that is what `walk` asks.

## 5. Against the Highcourt standard

| measure | Highcourt (wave 1) | Kezamba |
| --- | --- | --- |
| districts / plots / fill lots | 4 / 36 / 16 | 4 / 36 / 16 |
| cells | 376 274 of 400 000 | **317 978 of 400 000** (core 68 038, plots 249 940) |
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
wp13_kezamba budget/68038/249940/317978/400000
  core/68038/51/54/6107/2645/273/367/53/80/60/5/2230/315
  mask/30354/273/120/66/65
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
WP13 final micro PASS interpreter=luajit output_sha256=46b4dea6…
WP13 final micro PASS interpreter=puc51  output_sha256=46b4dea6…
```

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

`tools/wp13/run_capital.sh <out> kezamba terrain|full <seed>`, port block
31500-31599, one headless server at a time, every boot under `nice -n 19`.
**Nine `terrain` boots (§1) and nine `full` ones**, one per fixture seed, each a
cold world. The runner's own verdict is not the gate here -- it aborts in `full`
mode for an OPEN capital before printing PASS (§7.8) -- so each boot is read from
its log: the ERROR and ModError counts, the `event=complete` line, the
terrain-audit lines and the NPC roster.

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

The NPC roster is complete on every seed:

```
start npcs troll kezamba: guards 18/18 flair 163/163 vendor 7/7 quest 1/1
  new … pending 0 spare 11 residents 163 walkers 21
```

All seven vendor kinds resolve since this lane was rebased onto Lane N
(`c8050057`, the wave-2 NPC vocabulary): before that rebase `brewer` and
`herbalist` had no entity and the log carried the two error lines §8.4 says it
should ("an error line at placement and an empty socket, never a load failure").
The passes after the rebase carry **zero** errors.

**Build time in the engine**, from the probe's own `build_us`: module load
17.2 ms, the core 116.4 ms, the 52 plots 230 ms together with `totem_shrine`
the slowest at 10.6 ms. "Builds in a few seconds under LuaJIT when first
touched" is 0.36 s for the whole capital.

### (e) The causeway rail moved forty cells and nothing else

The rail of §5 landed after the four passes above, so the two gate/user seeds
were re-run on the final tree. What moved is exactly what should have:

| | before | after |
| --- | --- | --- |
| `core_road_digest` | `0dd25587…` | `0dd25587…` |
| `plot_road_digest` | `3d54b4a6…` | `3d54b4a6…` |
| `avenue_road_digest` | `ffbae1b7…` | `c7aef663…` |
| avenue cells read back | 110 753 | **110 793** |

Forty cells, all of them railing on kerb columns the road had to fill by three
courses or more — the embankment where the east avenue leaves the cenote and
runs down WP40's blend to the terraces. The core and the 52 plots are untouched,
which is what an overlay-only change has to look like.

**The core and every plot build to the same bytes on every seed.** The probe
digests what it reads back out of the finished map, and
`core_road_digest = 0dd25587…` and `plot_road_digest = 3d54b4a6…` are identical
on all four worlds. That is not luck: Kezamba's civic reference is
authored-fixed at y = 66 in every world (§1), so its anchor-relative core lands
at the same height, and the lake it is built round is the same mask. The
AVENUE digest does move between seeds, because the road follows the terraces
outside the envelope and those are the world's.

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
3. **The gorge's footbridge has no piers either**, for the same reason and with
   the same visible consequence: a six-node plank span with nothing under it.
   It is connected at both ends, so no rule this tree has calls it an island.
4. **The core lays two courses and not a terrace.** Like Highcourt's and Dur
   Brannoc's, the pad is subsoil and ground; where WP40's pad is already flat at
   the fitted height that is exactly right, and at Kezamba the measurement says
   6 192 of 6 380 dry columns are. The other 188 are the ravine, which the
   composition leaves alone.
5. **The basalt roof family is unreachable.** `grug_decor` registers the full
   four-shape family for basalt, but `wp13/parts.lua`'s `SHAPED` table — the
   library's one list of the nodes that may carry a facedir — carries only
   `darkage_basalt_stair` and `darkage_basalt_slab`, not the inner and outer
   corners the roof rasteriser needs. Binding the basalt roof fails at
   construction time with "has no paramtype2". `parts.lua` is the shared library
   and not this lane's, so Kezamba's civic buildings wear basalt walls under
   their own timber roofs, which is the better building anyway (§2.4 is a
   statement about what a hall stands ON). Two names in `SHAPED` would open it.
6. **The four districts do not move with the world seed**, unlike Highcourt's.
   §4 above says why. A later package that wants variation here has the room for
   it: the lots are searched and could be re-searched per seed, at the cost of
   a per-seed lot derivation the manifest would have to be independent of.
7. **The east avenue arrives at its gate sixteen nodes above the ground, and
   that is `avenue.lua` working.** The road walks at the one-Lipschitz upper
   envelope of the surface, and outside Kezamba's envelope the terrain climbs
   40 nodes in 32 columns (y 44 at x = +256, y 84 at x = +288, seed
   531802985935182545), which the module's 40-column look-around reads. So the
   road starts the hill inside the envelope and reaches the gate point on an
   embankment. The causeway rail of §5 is what such a stretch needs and now has,
   and the gate threshold reads the same envelope so it stands over the road
   rather than under it — but the embankment's FLANKS are still bare cut
   ground, and whether the WP40 route on the far side meets that deck cleanly is
   Lane R's question and not one this lane could answer from inside the
   envelope. Worth a look on the user's first walk.
8. **`run_capital.sh` aborts in `full` mode for an OPEN capital**, and its
   verdict on Kezamba is that abort and not a failure of this capital. The
   full-mode digest gate greps the log for three labels — avenue, rampart,
   gate — and two of the three find nothing where there is no curtain wall;
   under `set -euo pipefail` a command substitution whose pipeline failed is a
   failed assignment, so the runner exits before its own
   `[[ -n "$digest" ]] || continue` can act, after a boot that reported
   `exit=0 errors=0 complete=1`. Lane E met the same thing independently. The
   runner is lane D's and lands there; **this lane's engine evidence is judged
   from the LOG** — the ERROR and ModError counts, the `event=complete` line,
   the terrain-audit lines and the NPC roster — which is what §6d tabulates.
   (This lane did patch it with `|| true` on the two substitutions and then
   reverted that on the coordinator's ruling; the revert commit carries the
   diagnosis for whoever lands it.)
9. **No committed overlay digest yet.** `run_capital.sh` compares the built road
   against `tools/wp13/evidence/20260915-capital-terrain/<key>/<label>-digest-
   <seed>.txt`, and Kezamba has none, so its passes say "recorded (no committed
   value for seed … yet)". Freezing one is a decision with a number attached and
   belongs with the coordinator's merge, because the avenue digest moves with
   Lane R's route ends; the KAT's own overlay digest is the gate meanwhile.
10. **The user has not walked Kezamba.** Nothing here is accepted until they have.
   On seed 531802985935182545 the crossing of the two great avenues — the
   `arrival` landmark, with the guard banner on it — is at **(1800, 67, 1500)**.
   Walk EAST from it: the avenue runs eighteen nodes of boardwalk-on-pad and then
   out over the open cenote on piers, which is the thing this package exists for.
   The king's hall is south-east of the crossing, the cauldron court in the
   south-west corner of the pad, the moot house on the lake's west bank at about
   (1776, 71, 1530), and the quay with its anglers runs north along x ≈ 1782.
