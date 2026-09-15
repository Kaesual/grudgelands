# WP13: Highcourt's wall ring, its fill and its trades

Increment record, 2026-09-15, written on `main` at `19abee02` (playtest round 3,
lane 4). Evidence: `tools/wp13/evidence/20260915-highcourt-fill/`.

What the user said after playtest round 3, and what this package is:

> Highcourt is huge and empty. Fill grade: loose, with fields and gardens.
> Activity variety: traders with fitting houses, a butcher with a butcher's
> shop, a smith at a forge, a small pond where citizens fish with a fishmonger
> beside it, citizens at workplaces with activity animations. And the capitals
> are interchangeable: same building library, only the palette differs.

Three answers, in the order they were built: the **wall ring** that gives the
human capital a silhouette of its own, the **fill** between the plots, and the
**trades** that put somebody at a counter or an anvil instead of a doorstep.

Contracts implemented:
[wp13-capitals-pois-contract.md](wp13-capitals-pois-contract.md) §2.4 (the human
capital's "orchards inside the wall ring"), §4 (amended today: Highcourt is
walled), §2.3 (the 400 000-cell budget), and
[wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md) §8 in full — the
`work` role, the closed activity vocabulary, the 80/20 rule's structure-lane
half and the profession vendors. The seam it is carried by,
[wp13-seam-generalisation.md](wp13-seam-generalisation.md), is untouched: a
capital source hands the seam a plot list, and this package hands it 52 plots
where it used to hand it 36.

## 1. What shipped

| File | Change |
| --- | --- |
| `wp13/highcourt.lua` | the curtain wall's four runs and their authored plan, the overlay seam (`overlay_runs`/`overlay_names`/`overlay_run`), avenues to 261 |
| `wp13/highcourt_quadrants.lua` | **`FILL`** (the fill-lot envelope), **`FILL_AUTHORED`** (four slots with their own reaches) and **`FILL_LOTS`** (four per quadrant, derived) |
| `wp13/highcourt_plot.lua` | the **yard**: a plot with no part in the middle of it; a row's own lot reach; the `work` and `vendor` socket helpers; `activity`/`kind` carried through both socket paths |
| `wp13/highcourt_districts.lua` | resolves the four fill plots of each district onto the quadrant's fill lots, after its nine building plots |
| `wp13/highcourt_district.lua` | the smithy, the tailor's and the butcher's; the market district's four dressings, including the pond |
| `wp13/highcourt_district_martial.lua` | the muster field, the remount pasture, the wood yard, the guard green |
| `wp13/highcourt_district_lore.lua` | the chapel yard with its graveyard, the physic field, the sexton's garden, the quiet green |
| `wp13/highcourt_district_homes.lua` | the bakehouse becomes the baker's; the common field, the goose green, the lane park, the kitchen garden |
| `wp13/dressing.lua` | **`pond`** (a lined basin) and **`counter`** (a trestle shopfront) |
| `wp13/palette.lua` | the optional `water` role; the human palette binds `default:river_water_source` |
| `wp40/r7_highcourt_blueprint.lua` | one overlay carrying sixteen runs instead of fifteen, and the composition's own dispatcher |
| `tools/wp13/highcourt_kat.lua` | the five wall rules, the 16 fill lots, the 52 plots, §8.1 in full including the feature-under-`dir` check, the capital-wide vendor family rule and the §8.3 resident ratio |
| `tools/wp13/highcourt_plots.lua` | the fill lots verified and `--derive-fill`; the curtain added to the runs no lot may stand on |
| `tools/wp13/highcourt_probe/init.lua` | four named dumps (pond, orchard, chapel yard, smithy) plus the curtain and the gatehouse; **and the world's quadrant seam instead of the canonical assignment** (§6bis) |
| `tools/wp13/highcourt_identities.lua` | picks Highcourt by KEY: since Dur Brannoc joined the roster it had been printing Dur Brannoc's identities under a Highcourt name |
| `tools/wp13/run_highcourt.sh` | the new dumps, and the avenue-digest expectation moves to this package |
| `tools/wp13/dump_highcourt.lua` | the capital plan draws the whole overlay, wall included |
| `docs/research/wp13-capitals-pois-contract.md` | §4 amended with the user's round-3 ruling |

Not touched: `avenue.lua`, `wall.lua`, `capitals.lua`, `buildings.lua`,
`parts.lua`, `height.lua`, the six start compositions, `mods/ENTITIES/*`,
`blueprint_kat.lua`.

## 2. The wall ring

The 2026-09-14 ruling put Highcourt among the three OPEN capitals. Round 3
reversed it for this one capital, and the contract's own §2.4 line for the human
capital had always said "orchards inside the wall ring". §4 of the contract now
records the amendment; the split is four walled and two open, and Lethariel (a
grove city) and Kezamba (a stilt city) keep the variation the original ruling
wanted.

**Nothing new was written to build it.** Dur Brannoc landed the answer that a
curtain wall is an OVERLAY sharing its capital's one overlay blueprint with the
avenues ([wp13-dur-brannoc.md](wp13-dur-brannoc.md)), and this is that module in
Highcourt's palette: `grug_decor:castle_stonewall` faces over a rubble core,
brick string courses and brick merlon caps, `grug_decor:castle_arrowslit_stonebrick`
loopholes. Four runs on the ±256 envelope edge, six turrets a side plus the four
corner ones on the two z-runs, one gatehouse per side on the avenue.

Two numbers moved with it:

- **the avenues run to 261, not 256.** The gate tunnel is seven nodes thick and
  a road that stopped at the centre line would stop inside the gate.
- **the overlay carries sixteen runs, not fifteen**, and it is still ONE
  overlay, because the successor's first-run-wins arbitration — which is what
  lets the road win every cell of the passage — only exists within one overlay.
  The avenues are first in the list, so the four gates are walkable.

### 2.1 Does Highcourt's core identity move?

**No.** The core blueprint is untouched and its digest is the value the playtest
round froze:
`187f79e0ba52103818eba53f7ed9c3beadc631682648918301287fa4a7200499`.
The wall is an overlay and an overlay has no cells until a surface is handed to
it, so it contributes nothing to any blueprint identity. What DOES move is the
avenue overlay's **built** geometry — the digest `run_highcourt.sh` gates on —
for two reasons stated in the runner: the four avenues are five nodes longer,
and the curtain's vocabulary joined the overlay's palette, so the gatehouse
masonry inside the avenue's dump region is now digested with the road it lets
through. The new expectations are committed here (§6). The thirty-six district
plot digests move where the roster changed them (§4.3), and **the six start
identities do not move** (§6).

## 3. The fill

### 3.1 A dressing is a plot

A field laid flat across a two-node terrace is a field with a step through it,
so a dressing gets exactly what a building gets: a reference column, a
foundation skirt to −6 and a cleared airspace. `highcourt_plot.lua` grew the
**yard** — a roster row carrying `yard` instead of `module`/`make` builds the
same ground course, skirt, clear volume, gate path, lamps and sockets with no
part in the middle of it — and the whole of the fill is sixteen such rows plus
one building (the chapel yard).

### 3.2 Fill lots, and why they are not district lots

A fill lot obeys the district-lot rule for the district-lot reason: the four
districts move between the quadrants with the world seed, and a district's own
fill moves with it, so every fill lot has to carry any district's dressing.
Two things differ, both deliberate:

- **each slot carries its own reach** — 11, 11, 8, 5. A district lot is one size
  because any of 36 plots may stand on it; four fill slots of one size would be
  a capital of nothing but 23-node squares, which is as repetitive as a capital
  of nothing but houses. Slot *k* has the same reach in all four quadrants,
  which is all the interchange needs.
- **the lane is 4, not 8.** Eight nodes is what a street between two building
  lots needs; a garden between two cottages is four nodes of grass, and four is
  also what keeps the user's "loose" visible on the ground.

**Why four slots and not six.** The cell budget, measured rather than guessed:
the capital had 88 517 of its 400 000 cells left after the four districts, and
four dressings per quadrant spend 64 791 of them (§5.1). Six would not fit.

### 3.3 Where they stand, measured on both gate seeds

`highcourt_plots.lua --derive-fill` rotates the authored four-slot layout into
the quadrant, slides it as a whole to the translation that needs the least
correction, and gives every slot that still does not stand the nearest position
that does — the same search, the same ranking (worst move, then total, then the
translation) and the same two committed terrain fields as the district grids.

| Quadrant | Shift | Worst move | Fill lots |
| --- | --- | --- | --- |
| south-east | dz −24 | 0 | (208,−128) (104,−232) (200,−224) (94,−184) |
| north-east | dx −4, dz 28 | 28 | (76,204) (180,76) (172,224) (140,84) |
| north-west | dx −28, dz 28 | 28 | (−180,48) (−76,180) (−172,196) (−80,132) |
| south-west | dx 12, dz 4 | 16 | (−88,−220) (−220,−116) (−196,−212) (−144,−104) |

Per-lot terrain, worst of the two seeds: **perimeter fall 0 to 6 against a skirt
of 6, rise 0 to 6 against a clear of 8, and zero submerged columns on 16 of 16
lots on both worlds.** As built, the engine's own surface report says worst fall
6 (`homes_common_field`, user seed) and 4 (`market_workshop`, boundary seed),
zero submerged on both.

### 3.4 What the sixteen dressings are

Slot 1 of every quadrant is the outer-band lot between the grid and the curtain,
which is where the contract's "orchards inside the wall ring" stand. Slot 4 is
the garden-sized one and the only fill lot INSIDE the lot grid.

| District | 1 (reach 11) | 2 (reach 11) | 3 (reach 8) | 4 (reach 5) |
| --- | --- | --- | --- | --- |
| market | **the town pond** with the fishmonger | the orchard inside the wall ring | the market gardens | the green |
| martial | the muster field | the remount pasture | the wood yard | the guard green |
| lore | **the chapel with its graveyard** | the physic field | the sexton's garden | the quiet green |
| homes | the common field | the goose green | the lane park | the kitchen garden |

**Every dressing is laid out the same way, and the reason is the sockets.** The
three rows nearest the street (`z0` … `z0 + 2`) are the FORECOURT: the gate path,
the two lamps, the props a socket faces and the sockets themselves. Everything
from `z0 + 3` inwards is the FEATURE, and nothing authored there may land on a
standing position — ground cover is scattered by a position hash and a tuft of
grass in a socket's feet cell is a socket with no headroom. A work socket
therefore stands on `z0 + 2` and looks into `z0 + 3`.

### 3.5 The pond

`dressing.pond` digs a basin into the plot's own ground course and **lines it on
five sides**: the ring one node outside the water is carried down as subsoil
past the floor, and the floor under the water is subsoil too. Three courses of
water stand with their surface flush with the grass.

The lining is not decoration. Below y = −1 a reference plot sits on untouched
terrain, and on a terraced envelope "untouched terrain" is no promise of solid
rock at a given depth — a plot's interior column may be six nodes above its own
ground. A basin that trusted the ground would drain into the district below it.
The KAT proves the lining: every water cell's four horizontal neighbours and the
cell under it are cells of the same composition and are water or solid.

Two further rules the pond is held to:

- it is **`default:river_water_source`**, not ordinary water:
  `liquid_renewable = false`, `liquid_range = 2` (default/nodes.lua), which is
  default's own answer to "a pool on sloping ground must not flood the bank". If
  a player digs the liner out, river water spreads two nodes and stops.
- it stands in the **north half** of its lot, because z = 0 is the plot's
  reference column and has to be walkable ground. A pond over it would be a plot
  levelled to the bottom of its own water.

The KAT's blanket "no composition writes a liquid" becomes a DECLARATION plus
that containment proof (`PLOT_WATER`), so the rule that keeps a settlement from
being built into a river still holds for the other 51 plots.

### 3.6 The chapel yard

One fill row is a building: the small parish chapel of `buildings.chapel` in the
middle of the lot with the burial ground on the strip behind it inside a low
wall. It is not the core's chapel repeated — the core carries the great chapel
with the belfry — it is the one the district buries from, and it is where the
district's `pray` and graveyard-`tend` sockets are.

## 4. The trades

### 4.1 Profession houses

Five buildings got a **shopfront**: a four-node trestle counter on the street row
of their own plot ring, clear of the two corner lamps and the doorstep path,
with a vendor socket outside it looking at it and a work socket at the tool.

| Building | Vendor kind | Work activity | The feature it faces |
| --- | --- | --- | --- |
| `market_workshop` — the smithy | `smith` | `smith` | the anvil (`grug_decor:cottages_anvil`, the palette's `workbench`) on the apron |
| `market_store` — the butcher's | `butcher` | `chop` | the block, a `tree_log` |
| `market_counting_house` — the tailor's | `tailor` | `sit` | none; `sit` sits on the ground it stands on |
| `homes_bakehouse` — the baker's | `baker` | `stall` | his own counter |
| `market_pond` — the fishmonger | `fishmonger` | (the three `fish` stands beside him) | the counter at the pond gate |

**The baker's activity was a choice the contract asked to have written down**
(§8.1: "baker at the furnace as `stall` or `smith`, choose and document).
`stall` is chosen, because the other option names a feature this palette does not
have: the human palette binds no furnace — its `hearth` is
`grug_decor:xdecor_cauldron` and its `workbench` is an anvil — so a `smith`
socket at a bakehouse would have to face a blacksmith's anvil to satisfy its own
feature rule. The baker stands at the counter he has; the hammering loop stays
with the smith, who has an anvil.

The buildings did not move and their kits did not change. What changed is that
the smithy has an anvil in front of it and somebody standing at it.

### 4.2 The work sockets

Thirty-six, over nine activities:

| activity | count | where |
| --- | --- | --- |
| `tend` | 9 | orchards, physic beds, the sexton's garden, the kitchen garden, the chapel yard |
| `chop` | 7 | wood piles, the butcher's block, the orchard pile |
| `farm` | 7 | the three fields' furrows and the market gardens |
| `sit` | 5 | benches: the tailor and the four greens/parks |
| `fish` | 3 | the pond's south bank |
| `sweep` | 2 | the muster field and the lane park |
| `smith` | 1 | the anvil |
| `stall` | 1 | the bakehouse counter |
| `pray` | 1 | the chapel yard |

### 4.3 What the KAT now refuses

`highcourt_kat.lua` implements §8.1 in full. A `work` socket is held to every
rule an `idle` socket is (feet and head air, walkable ground, inside the
envelope, reachable) and then to three of its own:

1. it names an activity of the **closed vocabulary** (the registry's list,
   spelled here because this KAT has no engine);
2. it is a **spawn socket** — a workplace nobody works at is a spare with a
   hammer in its hand, and `spawn = false` belongs to `idle` alone;
3. **the feature the activity names stands where `dir` points, within three
   nodes.** The node sets are built from the PALETTE's own roles wherever the
   contract names a palette thing ("an anvil", "a log", "a crop"), so a palette
   rebinding moves the rule with it. `stall` is answered geometrically instead —
   "any solid node at waist height" is solidity at the socket's own feet course —
   and `sit` and `sweep` name no feature, which the contract says in as many
   words.

Rule 3 is the one that matters: it is what goes red when a piece of dressing
moves and leaves a smith hammering at air, and nothing else in the tree would
see that.

Two more rules are statements about the whole capital and are made once every
composition has been read:

- **at most one vendor per kind** (§8.4), over all 52 plots and the core, with
  `race` and `general` additionally pinned to the core, because `grug_traders`
  has exactly two such families and a third trader is what a district vendor of
  those kinds would produce;
- **at least one idle spawn socket per five residents** (§8.3). The NPC lane
  makes every fifth idle spawn socket a walker and asserts the resulting share is
  10–30 % of residents; a capital of nothing but workplaces would fail that, and
  this is the structure lane's half of the same rule.

## 5. Budgets and cost

### 5.1 Cells

| Subject | Cells | Budget |
| --- | --- | --- |
| civic core | 101 831 | 150 000 |
| market district, 9 plots + 4 dressings | 75 192 | — |
| martial district, 9 + 4 | 69 782 | — |
| lore district, 9 + 4 | 72 490 | — |
| residential district, 9 + 4 | 57 015 | — |
| largest single plot (`lore_shrine`) | 10 451 | 12 000 |
| largest dressing (`market_pond`) | 6 274 | 12 000 |
| **the whole capital** | **376 274** | **400 000** |

311 483 before this package, so the fill and the trades cost **64 791 cells** and
the capital keeps 23 726 in hand. The wall is an overlay and is computed per
mapchunk, so it is not in the total; over the KAT's synthetic terrace profile its
four runs write 137 580 cells across 2 056 columns, which is what a 512 ring of
seven-node masonry with fourteen turrets and four gatehouses costs when it is
all resident at once — and it never is.

### 5.2 Per-mapchunk cost

`probe.txt`, one boot per seed, every mapchunk emerged on its own in a fixed
order; the warm-up chunk carries the emerge environment's one-time R7
construction and is not counted.

| Kind | user seed | boundary seed |
| --- | --- | --- |
| Highcourt mapchunks | 95 | 86 |
| steady mean | **0.47 s** | **0.51 s** |
| worst single chunk | 1.02 s | 1.01 s |
| Lethariel (a capital with no WP13 cells) | 2.32 s | 2.67 s |
| open land / the Dawnmere start | 0.57 s | 0.36 s |

The contract's limit is "no more than 2× the ~0.5 s Dawnmere chunk". The
capital's steady mean is at or below the open-land control on both seeds and
under a fifth of the honest capital control's, which is WP40 fitting,
flattening, terracing and protecting a capital that has no WP13 blueprints at
all. The mapchunk count rose from 67 to 95 on the user seed, which is the wall
ring: the probe emerges every chunk an overlay run touches and the curtain runs
round the whole envelope.

## 6. Verification

### (a) The KATs, both interpreters

`highcourt_kat.lua` gained: the five wall rules Dur Brannoc's carries (the
activation band, no gap between footing and walk, a deck that changes by at most
a node per column, an open gate, a piece of a run being exactly that stretch of
the whole run), a digest of the built wall over a human-plateau terrace profile,
the rule that no lot may stand on the curtain; the 16 fill lots against the whole
geometric rule set independently of any assignment; the 52 plots, each against
the envelope of the lot it stands on; §8.1 in full; the pond's containment; four
spare wander spots per district; and the capital against the 400 000-cell budget.
Every plot still passes the pilot's own rules — palette, registry, panes,
attachment, islands, torches, lights, doorways, closed rooms, reachability,
reference column, skirt to −6 and cleared airspace.

Both interpreters produce byte-identical output, and the final micro pair over
every WP13 fixture agrees:

```
WP13 FINAL MICRO PAIR BYTE-IDENTICAL
0f5872e4c337b78d39ed31711efc7f3a3296e30afc3ee57853d0e11d53d3d2b3  micro-luajit.tsv
0f5872e4c337b78d39ed31711efc7f3a3296e30afc3ee57853d0e11d53d3d2b3  micro-puc51.tsv
```

### (b) Identity: what moved and what did not

- **The six start blueprint identities are unchanged**, byte for byte against
  the value the districts package recorded (`identity.txt`).
- **The Highcourt core digest is unchanged** at `187f79e0…`.
- **The avenue overlay's BUILT digest moved on both seeds**, by construction
  (§2.1). The new values are committed as this package's expectation and
  `run_highcourt.sh` now gates on them.
- **District plot digests move where the roster changed them**: the four
  profession houses gained a counter and a tool, and the identity of a plot is
  its cells. Twelve of the sixteen fill rows are new blueprints; the capital now
  publishes 54 blueprints where it published 38.

### (c) The engine, both gate seeds

`run_highcourt.sh <out> full <seed>`, ports 31311 and 31321, isolated scratch
`LUANTI_USER_PATH` under `/tmp`:

- `exit=0 errors=0 complete=1` on both;
- **zero `r7_settlement` `audit_terrain` warnings** on both — the seam's
  load-time diagnostic walks every reference plot's perimeter, its two-node
  margin and its interior on a stride of two, and found nothing to say about any
  of the 52;
- worst perimeter fall as built 6 (user seed) and 4 (boundary seed), **zero
  submerged columns** on both;
- the socket census the engine reports matches the KAT's exactly:
  `sockets=256 role_guard_patrol=56 role_guard_post=19 role_idle=134 role_king=1
  role_quest=2 role_vendor=7 role_waypoint=1 role_work=36`, nine patrol loops.

### (d) Socket populations

| | before | after |
| --- | --- | --- |
| sockets | 191 | **256** |
| `work` | 0 | **36** |
| `vendor` | 2 | **7** (race, general, butcher, smith, fishmonger, baker, tailor — one each) |
| `idle` | 110 | **134** |
| of which spare | 18 | **26** (10 core + 4 per district) |
| `guard_post` / `guard_patrol` | 19 / 56 | 19 / 56 |
| residents (idle spawn + work) | 92 | **144** |
| idle spawn sockets | 92 | **108** |

108 idle spawn sockets against 144 residents is one per 1.33, far inside §8.3's
one per five, so the NPC lane has room to reach its 10–30 % walker share.

## 6bis. A defect this package found in the probe, and fixed

`tools/wp13/highcourt_probe/init.lua` called the capital's blueprint source with
NO options:

```lua
local source = timed("module_load", function()
	local loaded = dofile(wp40 .. "/" .. profile.blueprint_file)
	return loaded()                       -- <- no seam
end)
```

A caller that passes neither `full_seed` nor `raw_sha256` is declaring itself
engine-free and gets the CANONICAL assignment — the four roles in authored
order. The probe has an engine, so what it got was a plot list labelled with the
districts the canonical permutation would have placed, while the map underneath
held the districts the SEED placed. The `event=districts` line said
`lore_spiritual=northwest` on every world, and the dump headed "district plot
lore_chapel_yard (highcourt_lore, northwest)" read back a region where the
garrison's muster field actually stands. It was found here because this package
is the first to dump a plot BY NAME: a per-district dump is right whichever
district the label claims, and the mislabelling had nothing to show it.

**The terrain numbers were never wrong.** A lot is a lot whichever district
takes it, and the SET of lot positions does not depend on the permutation, so
the surface audit covered exactly the 52 positions it should have. What was
wrong was every label on it, and the renders.

The fix is four lines: the probe reads `core.get_mapgen_setting("seed")` and
wraps `core.sha256(bytes, true)` exactly as `r7_runtime.lua` does, and hands
both to the source. Probe and world now agree about the permutation by
construction, which is the same argument `r7_highcourt_blueprint.lua` makes for
main and emerge.

It is confirmed by the thing that was wrong before. With the seam in place the
user seed logs

```
assignment=lore_spiritual=northeast,market_professions=southeast,
           martial_garrison=northwest,residential_cultural=southwest
```

which is the KAT's `1,3,2,4` and the table in section 3.4 of
[wp13-highcourt-districts.md](wp13-highcourt-districts.md), and which the
canonical assignment is not. So the engine, the KAT and the districts note agree
about the permutation, and always did; only the probe did not.

## 7. What the review should look at

1. **The pond's lining, and only the pond's.** `PLOT_WATER` is a one-row
   allowlist and the containment proof runs against every water cell; the
   question worth asking is whether a future dressing could add water without
   adding its row, and the answer should be no —
   `(#water_cells > 0) == (spec.water == true)` is asserted both ways.
2. **The forecourt rule is a convention, not a check.** The rosters keep ground
   cover out of `z0 … z0 + 2` by hand. The KAT catches a violation as "socket has
   no headroom", which is a good error, but it catches it only for cells a socket
   actually occupies. A reviewer who wants the rule enforced rather than obeyed
   should say so.
3. **The feature sets.** `tend` deliberately excludes `planter_soil`, because
   that role is `default:dirt_with_grass` for this palette and would make every
   patch of ground a valid `tend` feature. `pray` is a list of chapel-interior
   materials rather than a single altar node, for the same reason the contract
   phrases it loosely.
4. **The fill lots' lane of 4.** It is the number that makes "loose" visible and
   it is smaller than anything else in the capital; the south-east garden lot at
   (94, −184) is the tightest case.

## 8. What is open

- **Lane 1 (terraces) and lane 3 (route ramps) have not landed here.** This
  package is terrain-relative throughout and expects to be rebased onto lane 1's
  step bands; nothing in it reads a terrace height directly. The fill lots were
  derived against the CURRENT terrain fields, so after lane 1 lands
  `highcourt_plots.lua` should be re-run on fresh fields and `--derive-fill`
  re-checked. If lane 1 moves the plateau surface material, the dressings' ground
  role follows the palette and needs no edit.
- **The other five capitals are still interchangeable.** The user's second
  complaint is only half answered: Highcourt now has a wall ring, a pond, fields
  and trades that none of the others has, but the answer for Lethariel, Nhal
  Veyr, Gor Drazhak and Kezamba is each capital's own lane. The mechanism this
  package adds — fill lots, the yard plot, the work sockets — is generic and
  sits in `highcourt_*` files; a later lane that wants it for a second capital
  should lift the yard out of `highcourt_plot.lua` the way the plot builder was
  lifted out of the market district.
- **The committed engine evidence of the districts package carries the probe's
  old labels.** `tools/wp13/evidence/20260915-highcourt-districts/engine-*/probe.txt`
  says `lore_spiritual=northwest` for the user seed, which is the canonical
  assignment and not that world's. The terrain numbers in it are unaffected
  (§6bis), so nothing there has to be re-taken, but a reader comparing it with
  section 3.4 of that package's own note will find the two disagree. Re-running
  that evidence is the districts package's to do, not this one's.
- **The NPC lane owns what happens on these sockets.** Animations, wield items,
  walker selection and the profession stock tables are lane 5's
  (`grug_mobs`, `grug_traders`); this package places the positions and names the
  activities.
- **The wall has no sockets.** Dur Brannoc's gate towers keep two-waypoint
  watches published by the CORE's gatehouses, and Highcourt's core does the same
  for its precinct gates. The ring's four gatehouses and fourteen turrets are
  overlay geometry and an overlay publishes no landmarks, so nobody stands on the
  rampart. Giving the ring a garrison needs a socket source that is not a
  blueprint, which is a seam question and not this lane's.
