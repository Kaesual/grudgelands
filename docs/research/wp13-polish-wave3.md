# WP13 wave 3, Lane P: polish and carried-over items

Branch `wp13-w3-polish`, rebased onto main `ed11781f` ("Merge WP26: the dual
furnace and the universal alloy chain", which touches no WP13 file); written
against `f37a0c5b`, the wave-2 merge with six capitals, and every digest
comparison below is against that tree. Six small, independent items, one commit
each, plus a fix round. Written 2026-09-16.

Everything below is measured. A claim with no number beside it is marked
unmeasured.

**The fix round (2026-09-16, after the independent review)** did five things,
and each is recorded where it belongs rather than in a changelog: it closed
Highcourt's gate on the second gate seed (§4.2); it reverted the basalt roof
and rewrote its KAT section to gate the library fix instead (§2.1); it
corrected six wrong seed attributions and one wrong cascade neighbour in §3.4
and in two source comments; it restated the NPC-load claim as a spread rather
than a single-run coincidence (§5); and it gave `highcourt.lua` the roster's own
quadrant instance instead of a second `dofile` of it (§3.2). The review's own
measurements are cited where they are used.

---

## 1. The bough house's flight was mirrored (`c37c4948`)

Playtest 5, screenshot 8: "the stair treads at the tree house / raised watch
post are rotated 180 degrees".

They were. `wp13/elf_parts.lua`'s `M.tree_platform` builds one straight flight
up the `x+` face of the silverwood standard. Its treads climb towards `z-` --
each step moves one column in `-z` and one course up -- and every tread was
written at param2 0.

**The rule**, and it is already written down twice in this repository: a stair's
raised half lies toward `facedir_to_dir(param2)` (`wp13/parts.lua`'s header),
and `facedir 0` points at `+Z` (the engine's own table). The nodebox in
`mods/BASE/stairs/init.lua` is where both were read off: at param2 0 the raised
box spans `z 0..0.5`. A flight climbing towards `z-` therefore needs param2 2.
At 0, every tread's riser stood on the side the walker came from, so the
staircase read as a descent laid over an ascending plinth.

The four flights of `M.shrine` in the same file were always right and are the
cross-check: each is raised toward its own podium, which is the same rule.

**Measured.** Seven cells move per bough house and nothing else; every
blueprint's cell count is unchanged. `integration_fixture` moves exactly three
digests:

| blueprint | before | after | cells |
|---|---|---|---|
| `lethariel` / `lethariel_core` | `999a22c9…` | `25ad47a8…` | 91332, unchanged |
| `lethariel_martial_bough` | `fb9d6cdd…` | `b95e0142…` | 3776, unchanged |
| `lethariel_homes_bough` | `80f3df82…` | `b93bc678…` | 3551, unchanged |

No other settlement digest moves; the six start identities stay
`0bbf87a7253deadca55951752adde73e82c31cd10878dc64ef6d44af91ad1f5f`.

**The gate** is `lethariel_kat` section 8. It builds the part at both authored
deck heights and all four rotations and asserts the PROPERTY rather than the
constant: from one tread to the next the walker moves one column horizontally
and one course up, so every tread must be raised toward the next tread's
column (`parts.step_facedir(dx, dz)`). That holds at every rotation and
survives a re-authored flight. Mutation run: put back at param2 0 it fails on
the first tread ("the bough house's tread 1 at turn 0 carries param2 0 and is
raised away from the climb").

Renders: `tools/wp13/evidence/20260916-polish/renders/bough-{before,after}.png`.
The difference is not subtle -- the flight goes from a flush face to a visible
staircase.

---

## 2. The basalt roof corners of Kezamba's civic pair (`bb689ba8`, `f6a5e8b1`, and the fix round's revert)

**Outcome first, because the item ended somewhere other than where it started.**
The LIBRARY GAP is closed and stays closed: `wp13/parts.lua` now lets a part
write the basalt inner and outer stairs, so a basalt roof CAN be bound. The
capital does not bind one: the variant was built, rendered and read the same way
by the lane and by the independent review -- an undifferentiated dark mass with
no silhouette -- and the capitals contract's troll row names the wood outright,
so the roof stays junglewood and the fix round reverted the five `roof_*` lines.
The castle-role rebinding of `f6a5e8b1` stays. It is one table away and the
cost is written down below; the renders are in the evidence for the user.

The wave-2 Kezamba lane wrote the reason down in `wp13/troll_palette.lua`
itself: `roofs.raster` turns a hip with `roof_stair_outer` and a valley with
`roof_stair_inner`, and `wp13/parts.lua`'s SHAPED table -- the library's one
written-down list of the nodes it may give a facedir to -- carried the straight
basalt stair and the basalt slab but not the two corners. Binding the basalt
roof family therefore failed at construction time with "has no paramtype2", so
the king's hall of the basalt capital stood under a junglewood roof.

`grug_decor` had registered all four basalt shapes since the darkage import:
`mods/ITEMS/grug_decor/darkage.lua` runs every name of its `shaped` list
through `grug_decor.register_shapes`, which registers stair, inner stair, outer
stair and slab, each `paramtype2 = "facedir"` and each in `group:stair`. Only
the library's list was short.

**Two commits, because one of the files is shared.** `bb689ba8` adds the two
names to SHAPED, append-only and alone; `f6a5e8b1` binds the family on the
BASALT handle.

**Measured on the part** (`capitals.king_hall`, 23 x 23, rise 6, this handle),
22937 cells before and after:

| node | before | after |
|---|---|---|
| `stairs:stair_junglewood` | 606 | 6 (the six are `seat`, furniture) |
| `stairs:slab_junglewood` | 27 | 0 |
| `stairs:stair_outer_junglewood` | 12 | 0 |
| `grug_decor:darkage_basalt_stair` | 47 | 647 |
| `grug_decor:darkage_basalt_slab` | 132 | 159 |
| `grug_decor:darkage_basalt_stair_outer` | 0 | 12 |

Over the whole capital plan (`dump_capital_plan kezamba`, gate seed, 580913
cells, unchanged): 684 straight stairs, 36 slabs and 12 outer stairs move from
junglewood to basalt. The moot house is the other 84 + 9. Everything outside
the handle is untouched, and the twelve `stairs:stair_inner_junglewood`
elsewhere in the city stay put. This hall's roof has no valley and no flat cap,
so `roof_stair_inner` and `roof_ridge` are bound and not emitted by it.

**Digests, while the basalt roof was bound**: `kezamba` / `kezamba_core`
`dc32c0d2…` -> `ef258e33…` (69559 cells, unchanged), and the integration
fixture's shared R7 content channel grows from 212 to 213 names because
`grug_decor:darkage_basalt_stair_outer` is then written by a composition. The
engine pass registered it without complaint (errors=0), which is the evidence
that the two node names are real and reach every mapchunk.

With the SHAPED entry ALONE and nothing else, `integration_fixture` is
byte-identical -- which is what "append-only" means here.

### 2.1 The roof is timber again, and the decision is recorded rather than hidden

Both renders were made (`renders/kings-hall-{before,after}.png`) and both the
lane and the independent review of 2026-09-16 read them the same way:
`kings-hall-after.png` puts roof, walls, turrets, podium and plinth in one
basalt texture and the building loses its silhouette; `kings-hall-before.png`
reads as a building -- dark stone body, brown roof, legible ridge and eaves. The
capitals contract's troll row names the material outright ("stilt halls on
basalt platforms, **junglewood** walkways, totem posts, cauldron courts,
emergent trees kept", section 2.4), so the timber roof is what the contract asks
for rather than a compromise. **The fix round therefore reverted the five
`roof_*` lines of `troll_palette.BASALT` and kept everything else.**

With that revert, Kezamba's digest returns to main's `dc32c0d2…` and the content
channel to 212 names, so **the only settlement digests this lane moves are the
three Lethariel ones of section 1.** Measured after the revert:
`integration_fixture` is byte-identical to the tree that carried item 1 alone.

**THE HONEST COST OF TURNING IT ON**, because the first version of this note
said "one table" and the review measured that to be wrong: it is the five lines
in `troll_palette.BASALT` **and** `kezamba_kat` section 6, which would have to
go back to asserting an all-basalt roof, **and** the comment beside the table.
The Kezamba core digest moves to `ef258e33…`. The `parts.lua` SHAPED entries
stay either way -- they close a real library gap and, on their own, move
nothing.

**The gate** is `kezamba_kat` section 6, rewritten in the fix round to assert
what holds for EITHER binding, in three parts that fail for three different
regressions:

* **(a) the library gap is closed** -- all four `grug_decor:darkage_basalt_*`
  shapes are registered, carry `paramtype2 = "facedir"` and `group:stair`/`slab`,
  and `parts.shaped` agrees with the registry about each in both directions.
  This is the only gate the two new SHAPED entries have: `library_kat` proves
  that equality only for names a composition EMITS, and this capital no longer
  emits them. Dropping either corner from SHAPED fails here.
* **(b) the bound family is complete** -- all five roof roles resolve, the four
  shaped ones are shapes the library may turn, and all five reduce to ONE
  material (the `stairs` mod puts the shape in front of the material and
  `grug_decor` behind it, and the full cube carries none, so the check
  normalises all three spellings). Half a family bound is the defect, and a
  partial basalt binding is exactly that defect.
* **(c) the corners are actually written** -- the finished core emits the corner
  pieces of whichever family is bound (24 `stairs:stair_outer_junglewood` today),
  so a roof that stopped rastering hips goes red.

Mutations run and red: dropping `darkage_basalt_stair_outer` from SHAPED (a);
binding `roof_stair_outer` to a name from another family (b).

---

## 3. Thirteen Highcourt lots that nine worlds refuse (`460ab861`, `3440f493`, `418c7fa2`)

### 3.1 Re-measured first, and the numbers differ from the log

The wave-2 coordinator's log recorded "Highcourt 11, Dur Brannoc 1 lot(s)
illegal on at least one of the nine seeds". Re-measured on this tree with
`tools/wp13/capital_lots.lua` against nine field dumps
(`tools/wp13/capital_anchor_fixture.lua`'s seed set, one
`run_capital.sh … field <seed>` per seed, 38-48 s each):

* **Highcourt: 12** of its 52 lots -- 6 of the 36 district lots and 6 of the 16
  fill lots. Every one of them is legal on the two gate seeds this table was
  ever verified against, and every one fails on one of the other seven.
* **Dur Brannoc: 0.** "every lot and every fill lot of dur_brannoc is dry,
  inside the skirt and under its own roof on all 9 worlds". The log's "1" does
  not reproduce; nothing there is moved.

**And the engine agrees, independently.** `r7_settlement.audit_terrain` runs at
load and walks every plot against the world's real column authority. Nine cold
boots on the nine seeds, before the repair, report **eleven findings on six of
the nine seeds**, all Highcourt, all on the lots below -- including "perimeter
fall 14 against a skirt of 6" for `martial_wood_yard` on seed 999999999. After
the repair: **zero on all nine**. (That eleven is very likely what the wave-2
log's "11" was; it is a different count from the twelve illegal lots, because a
lot is refused once and a plot is warned about per seed.)

### 3.2 Why the pilot capital could only be asked two worlds at a time

`capital_lots.lua` takes as many field dumps as it is given and refuses a
capital whose composition does not publish its quadrants module. Dur Brannoc,
Gor Drazhak, Nhal Veyr and Kezamba all publish it; **Highcourt never did**, so
it was the one capital restricted to `tools/wp13/highcourt_plots.lua`, which
takes exactly two. That is the gap wave 1 had already found the hard way and
then left open for this capital.

`460ab861` publishes it, mirroring `wp13/dur_brannoc.lua`. Its first version
`dofile`d `highcourt_quadrants.lua` a second time, so `highcourt.quadrants` and
`highcourt_districts.quadrants` were two separate tables of the same data --
harmless while every consumer reads them, and the independent review was right
to flag it. The fix round takes the ROSTER's instance instead
(`local districts = dofile(".../highcourt_districts.lua")(directory)`), which is
exactly `dur_brannoc.lua`'s shape and **removes** a duplicate rather than adding
one: `highcourt_district.lua` used to be loaded once in `highcourt.lua` and once
inside the roster, and `M.district` is now the roster's own market district --
the same table it always was, `districts.districts[1]`, whose role the roster
asserts at load.

Digest-neutral either way, measured: `integration_fixture`,
`highcourt_identities` and the six start identities are byte-identical across
both versions of this change.

### 3.3 `--repair` had to learn the fill grid

`--repair` repaired the 36 district lots and stopped. Six of the twelve
Highcourt positions are FILL lots, and `--derive-fill` is the wrong instrument
for them for the reason the file's own header gives about `--derive`: it slides
a whole quadrant's grid to the best translation, which is right when a grid is
being invented and wrong when the ground under a finished city has moved by a
node. `3440f493` adds the fill pass, AFTER the district pass and against the
district lots as they now stand -- which is not a detail: one of the seven fill
moves happens only because the district lot beside it moved first.

### 3.4 What moved

Thirty of thirty-six district lots and nine of sixteen fill lots keep the
position they were authored at.

**The seed column is a RESOLVED INDEX, and the first version of this table got
six of the thirteen rows wrong.** `capital_lots.lua` reports
`ILLEGAL <n>:<rule>:<value>`, and `<n>` is the position of the field dump in
the argument list -- which is the order of `tools/wp13/capital_anchor_fixture.lua`'s
`SEEDS = {531802985935182545, 8675309, 15912857179583385436, 0, 1, 2, 42,
12345, 999999999}`. So 4 is seed 0, 7 is 42, 8 is 12345, 9 is 999999999. Those
indices were first written down as if they were seeds. The independent review
of 2026-09-16 caught it, and this lane's own `audit-terrain-before.txt`
contradicts the old table on two of the six rows -- it records
`homes_kitchen_garden at -144,-104` under **seed 0** and `martial_barracks at
132,108` under **seed 42**. The counts, the moves and the repair were always
right; only the seed column was wrong, and it was wrong in two source comments
as well, which is why it mattered.

| kind | lot | from | to | why |
|---|---|---|---|---|
| district | southeast 5 | 116,-116 | 112,-116 | rise 8 on seed 0 |
| district | northeast 1 | 132,108 | 132,112 | fall 8 on seed 42 |
| district | northwest 1 | -132,80 | -132,84 | rise 7 on seed 999999999 |
| district | northwest 2 | -176,80 | -176,76 | rise 7 on seed 42 |
| district | northwest 8 | -180,168 | -180,164 | rise 8 on seed 12345 |
| district | southwest 6 | -84,-188 | -84,-196 | rise 7 on seed 0 |
| fill | northeast 4 | 140,84 | 144,84 | fall 12 on seed 999999999 |
| fill | northwest 1 | -180,48 | -180,44 | cascade: lane to the moved district lot **2** |
| fill | northwest 4 | -80,132 | -84,132 | fall 10 on seed 999999999 |
| fill | southwest 1 | -88,-220 | -68,-228 | fall 7 on seed 2 (move 28) |
| fill | southwest 2 | -220,-116 | -224,-116 | fall 10 on seed 999999999 |
| fill | southwest 3 | -196,-212 | -196,-220 | rise 9 on the user's seed |
| fill | southwest 4 | -144,-104 | -116,-60 | fall 8 on seed 0 (move 72) |

**The cascade is north-west district lot 2, not lot 3.** Lot 2 moved from
`-176,80` to `-176,76` -- toward the fill lot -- and north-west fill 1 at
`-180,48` (reach 11) then stood inside its four-node lane: the blocking band of
a reach-13 district lot at z 76 is z 59..93, and the fill lot's own band reaches
z 59, so they touch. At the old z 80 the band was 63..97 and they did not. Lot
3 sits at `-220,80` and its x band (-237..-203) never reaches the fill lot's
(-191..-169), so it could not have been the cause. Put the fill lot back on the
repaired grid and the predicate says `ILLEGAL lot:northwest/2`.

**South-west fill 4 walked 72 nodes** and a reviewer should look at it. It is
the garden strip inside the lot grid, the smallest of the four slots, in the
one quadrant both rivers run through; with the nine repaired district lots
standing and a four-node lane round each, that is the nearest column carrying a
five-reach pad on all nine worlds. It is still a garden in the same quarter; it
is no longer between the same two columns of the grid.

**No digest moves.** A lot is a POSITION: a plot's identity is its own cells
projected from its own reference column, and the offsets live in the source's
plot list. `integration_fixture` and `highcourt_identities` are byte-identical
to main `f37a0c5b`. The only two rows that move anywhere are
`highcourt_kat`'s `highcourt_lot_grid` and `highcourt_fill_grid`, which are the
tables themselves.

---

## 4. Corner digests, and the capitals that have none (`309b890b`)

Lane U added `wall.lua`'s corner reconciliation and the `<key>-corner.tsv`
region that gates it. Dur Brannoc and Nhal Veyr were frozen; the rest were not.

* **Gor Drazhak publishes one.** Its rampart is a stake palisade on an earth
  bank rather than masonry, but it authors the same four `wall_*` overlay runs,
  so the probe adds rampart, gate and corner. Frozen from a green pass on the
  gate seed (exit=0, errors=0, complete=1, 129 s), in which the three committed
  digests all matched:
  `9d30229d372804d2a87440b73f1da5cbe2b24345e9f9c3a4a43dcde32834b7a1`,
  10798 cells.
* **Kezamba has no corner gate, and that is correct.** It is one of the two
  capitals the user's ruling of 2026-09-14 left OPEN and authors no `wall_` run
  at all: its twelve overlay runs are four avenues, four ring sides and four
  gate THRESHOLDS (`wp13/kezamba_gate.lua`). The runner says "this capital
  publishes no such overlay region" three times rather than failing. Its pass
  is green with the avenue digest matching -- which is also what says the
  basalt roof moved no street cell. Lethariel is the same case with `edge_*`
  runs.

### 4.1 Highcourt's own pass was red on main, and is now closed

Found while checking the other two. `run_capital.sh <out> highcourt full`
failed with "the built avenue moved". The cause is a stale expectation:

* `highcourt/avenue-digest-531802985935182545.txt` was frozen on main
  `658b6763` (package `20260915-capital-terrain`);
* `d7eb5383` "Give Highcourt the wall ring of the capitals contract" is **not**
  an ancestor of `658b6763` -- it landed afterwards;
* the avenue dump region runs to `x = anchor + 260`, `z = anchor ± 12`, so it
  contains the east curtain and the east gatehouse. Giving this capital a wall
  necessarily moved the digest, and no Highcourt full pass has been run since.

Not this lane's doing, and measured rather than argued: `highcourt_kat`'s
`highcourt_wall` row (`dc08f3e7…`) and every overlay row of it are
byte-identical between the pristine `f37a0c5b` tree and this branch.

All four Highcourt regions are therefore frozen from one green pass rather than
leaving the capital's own gate red: avenue `0619c8eb…` (3656 cells, was
`99f48984…`/1610 pre-wall), rampart `2f2f4fce…` (9103), corner `44adce15…`
(7378), gate `1a010165…` (2479).

### 4.2 And the second seed, closed in the fix round

`highcourt/avenue-digest-8675309.txt` was stale for exactly the same pre-wall
reason (`8383b298… main=658b6763`, 1609 cells) and the first pass of this lane
left the gate red on that seed. The fix round closed it with its own engine
pass on port 31310 (exit=0, errors=0, complete=1):

| region | frozen value | cells |
|---|---|---|
| avenue | `fde348c9d5855952604dcd0cfd7c3b9e4758742994692d69ea910e3ccea5a6c4` | 3300 |
| rampart | `17bb7223e853c79dd2ed3844d5cf27f2aa91811f8ddf19114116efba65628a06` | 9059 |
| corner | `cc6da1b72127eb8bd0eaeedb0b9f7fa5eeb713379b01cce8510e695237c8bb12` | 7127 |
| gate | `65ed2219c2f06c00fbc2f238b003d280c5382a5a81158b0a26f1f13073e94c8b` | 2429 |

**Three independent engine passes agree on the avenue value.** `fde348c9…` was
already committed on main a day earlier in the OTHER Highcourt expectation
directory, `20260915-highcourt-fill/highcourt/avenue-digest-8675309.txt`
(`main=922bfd92 package=20260915-route-gates`); the independent review measured
it again; and this lane measured it a third time on its own port. A second pass
after the freeze is green on all four regions
(`engine/highcourt-8675309/run-green-after-freeze.txt`).

**A structural defect this uncovers, and it is nobody's lane**: Highcourt's
avenue digest has TWO expectation files under two paths, read by two different
runners -- `run_capital.sh` reads `20260915-capital-terrain/highcourt/`,
`run_highcourt.sh` reads `20260915-highcourt-fill/highcourt/`. That duplication
is exactly how one copy sat a day out of date while the other was correct, on
both seeds, and it will happen again after Lane S. One path, or one runner,
would be better.

---

## 5. A capital subject for the NPC load probe (`4197cb5f`)

`tools/wp13/npc_load_probe` walked the six starts and reported what a populated
START costs the server. It now takes an optional CAPITAL and measures it last,
by the same clock, so its numbers read against the wave-1 start numbers of
[wp13-npc-work.md](wp13-npc-work.md) §7.1 with no correction. Three things
differ: what is held (every socket's own mapblock, deduplicated, instead of a
64-node grid -- Highcourt: 256 sockets, 133 blocks), when the window opens (a
capital has no preload, so the phase waits for `marked == roster` and gives up
on a 60 s STALL rather than a total), and what is asserted (the walker rules
yes; the zero-pathfinder rule reported, not asserted, because it was
established on a start's population).

The key reaches the probe as a staged `subject.lua`, because
`tools/luanti_headless.sh` passes no environment into the Flatpak -- the
mechanism `run_npc_probe.sh` already uses. Without the argument the run is
byte-for-byte the programme every earlier record was taken with.

**Measured**, seed 531802985935182545, one boot, seven windows.

The six starts reproduce wave 1 and are the control: 11 active mobs, 6
residents, 1 walker (16.7 %), zero `find_path`, mean step 90.26-90.30 ms, tick
11.80-30.70 µs per settlement-second and 1.07-2.79 µs per ticking NPC over 11
of them. Wave 1 recorded 14.95-28.70 and 1.36-2.61 over the same 11.

Highcourt, the first capital measured this way:

| | start (six) | Highcourt |
|---|---|---|
| this settlement's NPCs | 11 | 165 |
| guards / vendors / residents | 3 / 1 / 6 | 20 / 7 / 136 |
| work / static idle / walkers | 2 / 3 / 1 | 31 / 84 / 21 |
| walker share | 16.7 % | 15.4 % |
| mean server step | 90.26-90.30 ms | 90.53 ms |
| worst server step | ~91.0 ms | 91.07 ms |
| tick, per settlement-second | 11.80-30.70 µs | 459.40 µs |
| tick, per ticking NPC | 1.07-2.79 µs | 2.78 µs |
| `find_path` in 30 s | 0 | 30 |

**THE CLAIM, RESTATED AFTER THE REVIEW, because one run is not a measurement.**
The first version of this section concluded "the per-NPC cost is a start's:
2.78 µs against a start's worst of 2.79". That pairing is a coincidence of a
single run on a shared host. The independent review ran the same programme twice
more -- once on the branch, once with this lane's harness staged into a pristine
`f37a0c5b` tree -- and measured **1.58 µs** and **4.10 µs** per ticking NPC for
Highcourt, with one start in its main run at **10.65 µs**. Across the three runs
the starts span roughly 1.07-10.65 µs and Highcourt 1.58-4.10 µs.

So the defensible finding is that **the per-NPC tick cost stays WITHIN THE
SPREAD of a start's rather than growing with population**, while the settlement
total scales with the population because the work is per NPC. What reproduces
across all three runs, and is the real result:

* the **server step does not move** -- 90.51-90.57 ms mean and 91.05-91.07 ms
  worst for Highcourt, against ~90.3 / ~91.0 for a start. That is also what it
  always says: a dedicated server runs a fixed 0.09 s step and only exceeds it
  once it cannot keep up;
* the **walker share holds** -- 15.0-15.4 % against a start's 16.7 %, inside the
  sockets contract's 10-30 %;
* `marked == roster` (181/181) every time, so the window measures a fully
  populated capital.

The single-run µs numbers should be read as an order of magnitude and nothing
finer; the host was carrying six other wave-3 lanes throughout.

### 5.1 Two findings the run was not looking for, and BOTH ARE PRE-EXISTING

The review settled the ownership question by staging this lane's harness into a
pristine `f37a0c5b` tree and running it there: **both findings reproduce on
unmodified main**, so neither is caused by the lot moves.

1. **`min_walker_ring=1` at Highcourt**, on main and on the branch. At least one
   of its 21 walkers was handed a wander ring of ONE spot, and a ring of one is
   a walker that never moves (`next_spot` returns the index it was given). That
   is the Stillgrave defect of round 3, in a capital, and `bounded_spots` in
   `mods/ENTITIES/grug_mobs/start_npcs.lua` tops a ring up to `WALK_MIN_RING`
   only when its shortfall is non-empty -- a ring of 1 means the composition
   offers exactly one eligible spot, which moving a lot cannot change. The probe
   fails the run on it, which is why the runner reports FAILED with errors=1 --
   the probe doing its job. It belongs to whoever owns the socket placement.
2. **A non-zero `find_path` in a quiet window**: 30 in this lane's run (59.18 a
   minute), 21 in each of the review's two (41.4 a minute), including the one on
   unmodified main. A start's is zero. The finding is "of the order of 40-60 a
   minute", not a specific count. The only caller a settlement has is
   `patrol.lua`'s stuck rescue, so something in a capital's twenty guards is
   getting stuck.

---

## 6. The tree census (`8a5f626e`)

The wave-2 open item: after generation, how many trees stand inside what the
composition built?

**Where the nodes are read**: the timing phase already walks every mapchunk the
capital touches, one at a time, and a mapchunk is in memory exactly when its
emerge callback fires. The census rides along on that walk, after the timing is
taken. Each `find_nodes_in_area` is clipped to the mapchunk and is therefore
bounded by construction (80³) rather than by an engine constant. It adds no
emerge and no measurable time.

**The discriminator is the whole problem, and the first version got it wrong.**
A raw `group:tree` count is useless: a settlement's own posts, beams, piles and
lamp standards are `default:tree` and `default:jungletree` too, and the first
run reported 4388 "trees" inside Gor Drazhak's 52 plots -- the orc capital's own
timber. So:

* a **plot** knows exactly what it wrote. `plot.composition` is the built
  blueprint and the probe holds it, so every trunk is checked against the cell
  the blueprint authored at that column and course, projected from the same
  reference height the writer uses. Not authored = WILD.
* a **street** has no cells to compare against, so the discriminator is the
  CANOPY: a trunk with a `group:leaves` node in its own column within three
  courses above. A lamp standard carries a torch; none of the settlement's
  timber carries leaves. It is a heuristic, reported as one, and it reads with
  `get_node_or_nil`, so the street number is a floor.
* `wall_` and `edge_` runs are skipped: a curtain is not a street, and an open
  capital's grove edge is a PLANTED BELT (the first Lethariel run reported 4269
  canopied trunks along its four `edge_` runs, every one its own silverwood).

**The numbers**, gate seed 531802985935182545, both passes green:

| | plots | trunks | leaves | **wild** | streets | trunks |
|---|---|---|---|---|---|---|
| Highcourt | 52 | 4954 | 4153 | **0** | 4 avenue + 4 ring + 7 lane | **0** |
| Lethariel | 44 | 3286 | 5454 | **0** | 4 avenue + 4 ring + 7 lane | **0** |

So on this seed neither capital has a single mapgen tree inside a plot or a
street, and the ~8000 trunks the two carry are all theirs: orchards, groves and
the timber they are built from. The count of authored trunks is also what says
the discriminator works -- a broken one would have called them all wild.

Fixing what this finds is not this lane's work, and on this evidence there is
nothing to fix; the probe exists so a capital or a seed that does have the
problem says so.

---

## 7. What the review should look at, and what is open

**For the USER, and it is the only decision in this lane that is not a
measurement:** the basalt-roof render pair, `renders/kings-hall-{before,after}.png`
(§2.1). The lane and the independent review both preferred the timber roof and
the contract names junglewood, so the shipped state is timber; §2.1 records
exactly what turning basalt on costs.

**Look at:**

1. **South-west fill 4's 72-node move** (§3.4). The repair rule is "nearest
   legal position" and that is what nine worlds leave; whether a garden that
   far from its authored gap is still the right piece is a design call.
2. **Highcourt's re-frozen digests on both seeds** (§4.1, §4.2). This lane
   re-froze expectations it did not author, because the alternative was leaving
   the pilot capital's engine gate red on both gate seeds. Independently
   confirmed: the review reproduced all four gate-seed values on a pristine
   `f37a0c5b` tree, and the 8675309 avenue value was already committed under
   another path a day earlier.
3. The **census discriminators** (§6), which are the whole value of the tool.

**Open, and not this lane's:**

* **Lane S will move most of what this lane froze.** It owns `avenue.lua`, so
  Highcourt's `avenue` (both seeds) and almost certainly `gate` move again, and
  `rampart` should be re-measured; the two `corner` files are the ones that
  should survive and that would actually catch a wall-seam regression.
* **Highcourt's avenue digest lives in two files under two paths** (§4.2), read
  by two different runners. That is how both copies went stale.
* **`min_walker_ring=1` and a non-zero `find_path`** at Highcourt (§5.1), both
  reproduced on unmodified main by the independent review.
* `lethariel_kat`'s own `lethariel_core` identity row does not carry param2, so
  the ENGINE identity moved with item 1 while that KAT row did not. Section 8 of
  that KAT is currently the only guard against a facing regression.
* `capital_lots.lua`'s district REPAIR pass pushes `{id, x, z}` into `placed`
  while the VERIFY pass pushes `{…, reach, lane}`, so the two use different lane
  gaps. Pre-existing; this lane's new fill pass uses the verify shape.
* The census's street band samples the bounding box's diagonal rather than the
  run. Harmless for a road, not what the comment says.
* Nothing in this lane touched `avenue.lua`, bridges, lamps, Kezamba terrain or
  crops, or `grug_mobs`.

**Two files this lane changed that its brief did not list**, named here because
the common brief asks for it: `wp13/troll_palette.lua` (the brief said
`troll_parts.lua`; the roof and castle bindings live here and in no other
wave-3 lane's ownership) and `wp13/highcourt.lua` (one functional line, its own
commit). Both are digest-neutral in the shipped state.

**A host condition worth recording.** `/tmp` on this workstation is a 30 GB
tmpfs mounted with `usrquota`, and the user's hard quota is 23966 MB. With
seven wave-3 lanes running in parallel it was exhausted twice during this
lane's engine work: the headless server then aborts with
`"Failed to commit SQLite3 transaction: disk I/O error"` or `"Failed to save
block: disk I/O error"` and `run_capital.sh` reports `exit=134 errors=3
complete=0`. That is what it looks like, and it is not a code defect. This lane
freed its own scratch and re-ran; it cost the 8675309 pass, which the fix round
then took (§4.2).

---

## 8. Reproducing every claim

From the repository root, `LC_ALL=C` throughout:

```
tools/wp13/evidence/20260916-polish/static.sh      # parser, SETGLOBAL, five sweeps, fresh-server
tools/wp13/evidence/20260916-polish/kat.sh         # 12 KATs x 2 interpreters, byte-compared
tools/wp13/evidence/20260916-polish/identity.sh    # start identities, every settlement digest
tools/wp13/evidence/20260916-polish/final-micro.sh # the final micro-KAT pair
```

The engine passes, one server at a time on ports 31300-31399:

```
WP13_CAPITAL_PORT=31310 tools/wp13/run_capital.sh /tmp/<out> <key> field <seed>
WP13_CAPITAL_PORT=31310 tools/wp13/run_capital.sh /tmp/<out> <key> full  531802985935182545
PORT=31320 tools/wp13/run_npc_load.sh /tmp/<out> 531802985935182545 highcourt
```

and the lot predicate, given the nine field dumps:

```
luajit tools/wp13/capital_lots.lua . highcourt <nine field.tsv>            # verify
luajit tools/wp13/capital_lots.lua . highcourt <nine field.tsv> --repair   # repair
```

The evidence directory is `tools/wp13/evidence/20260916-polish/`.
