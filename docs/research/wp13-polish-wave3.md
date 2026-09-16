# WP13 wave 3, Lane P: polish and carried-over items

Branch `wp13-w3-polish`, base main `f37a0c5b` ("Freeze the Dur Brannoc corner
digest on the gate seed", the wave-2 merge with six capitals). Six small,
independent items, one commit each. Written 2026-09-16.

Everything below is measured. A claim with no number beside it is marked
unmeasured.

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

## 2. The basalt roof of Kezamba's civic pair (`bb689ba8`, `f6a5e8b1`)

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

**Digests that move**: `kezamba` / `kezamba_core` `dc32c0d2…` -> `ef258e33…`
(69559 cells, unchanged), and the integration fixture's shared R7 content
channel grows from 212 to 213 names because
`grug_decor:darkage_basalt_stair_outer` is now written by a composition. The
engine pass then registered it without complaint (errors=0).

With the SHAPED entry ALONE and nothing else, `integration_fixture` is
byte-identical -- which is what "append-only" means here.

**The gate** is `kezamba_kat` section 6, and it fails for two different
regressions. The ROLES half asserts all five roof roles of the handle resolve
to basalt and that each of the four shaped ones is a name `parts.shaped` will
let a part turn, so dropping either corner out of SHAPED fails before anything
is built. The CELLS half asserts the finished core writes basalt corner pieces,
which only a rastered basalt roof can produce. Both mutations were run and both
go red.

**FOR THE USER, and this is a look-and-feel call rather than a measurement.**
The renders are
`renders/kings-hall-{before,after}.png`. The all-basalt hall reads as one dark
mass where the timber roof gave it a second material. The change is one table
in `troll_palette.lua` and is trivially reversible if the brown roof was the
better building.

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

`460ab861` publishes it -- one line, mirroring `wp13/dur_brannoc.lua`, of a
pure module `highcourt_districts.lua` already loads. `integration_fixture`,
`highcourt_identities` and the start identities are byte-identical across it.

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

| kind | lot | from | to | why |
|---|---|---|---|---|
| district | southeast 5 | 116,-116 | 112,-116 | rise 8 on seed 42 |
| district | northeast 1 | 132,108 | 132,112 | fall 8 on seed 12345 |
| district | northwest 1 | -132,80 | -132,84 | rise 7 on seed 999999999 |
| district | northwest 2 | -176,80 | -176,76 | rise 7 on seed 12345 |
| district | northwest 8 | -180,168 | -180,164 | rise 8 on seed 999999999 |
| district | southwest 6 | -84,-188 | -84,-196 | rise 7 on seed 42 |
| fill | northeast 4 | 140,84 | 144,84 | fall 12 on seed 999999999 |
| fill | northwest 1 | -180,48 | -180,44 | cascade: lane to the moved lot 3 |
| fill | northwest 4 | -80,132 | -84,132 | fall 10 on seed 999999999 |
| fill | southwest 1 | -88,-220 | -68,-228 | fall 7 on seed 2 (move 28) |
| fill | southwest 2 | -220,-116 | -224,-116 | fall 10 on seed 999999999 |
| fill | southwest 3 | -196,-212 | -196,-220 | rise 9 on the user's seed |
| fill | southwest 4 | -144,-104 | -116,-60 | fall 8 on seed 42 (move 72) |

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

**Still open**: `highcourt/avenue-digest-8675309.txt` is stale for the same
reason and is NOT re-frozen -- this lane took no pass on that seed (see §7).

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
| tick, per ticking NPC | 1.07-2.79 µs | **2.78 µs** |
| `find_path` in 30 s | 0 | **30** |

**The answer is that the tick is linear and the per-NPC cost is a start's**:
2.78 µs against a start's worst of 2.79, with the settlement total fifteen
times a start's because the population is. The server step does not move, which
is what it always says -- a dedicated server runs a fixed 0.09 s step.

### 5.1 Two findings the run was not looking for, neither this lane's to fix

1. **`min_walker_ring=1` at Highcourt.** At least one of its 21 walkers was
   handed a wander ring of ONE spot, and a ring of one is a walker that never
   moves (`next_spot` returns the index it was given). That is the Stillgrave
   defect of round 3, in a capital. The probe fails the run on it, which is why
   the runner reports FAILED with errors=1 -- the probe doing its job. It
   belongs to whoever owns the socket placement.
2. **`find_path=30` in a quiet 30.4 s window** (59.18 a minute). A start's is
   zero. The only caller a settlement has is `patrol.lua`'s stuck rescue, so
   something in a capital's twenty guards is getting stuck.

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

**Look at:**

1. The **`troll_palette` basalt roof** (§2). It is a look-and-feel decision the
   brief asked for, the renders are in the evidence, and reverting it is one
   table.
2. **South-west fill 4's 72-node move** (§3.4). The repair rule is "nearest
   legal position" and that is what nine worlds leave; whether a garden that
   far from its authored gap is still the right piece is a design call.
3. **Highcourt's re-frozen avenue digest** (§4.1). This lane re-froze an
   expectation it did not own, because the alternative was leaving the pilot
   capital's engine gate red. The provenance argument is in the commit message
   and is checkable with two `git merge-base` calls.
4. The **census discriminators** (§6), which are the whole value of the tool.

**Open, and not this lane's:**

* `highcourt/avenue-digest-8675309.txt` is stale (§4.1). The next Highcourt
  pass on that seed fails until somebody re-freezes it.
* `min_walker_ring=1` and `find_path=30` at Highcourt (§5.1).
* Nothing in this lane touched `avenue.lua`, bridges, lamps, Kezamba terrain or
  crops, or `grug_mobs`.

**A host condition worth recording.** `/tmp` on this workstation is a 30 GB
tmpfs mounted with `usrquota`, and the user's hard quota is 23966 MB. With
seven wave-3 lanes running in parallel it was exhausted twice during this
lane's engine work: the headless server then aborts with
`"Failed to commit SQLite3 transaction: disk I/O error"` or `"Failed to save
block: disk I/O error"` and `run_capital.sh` reports `exit=134 errors=3
complete=0`. That is what it looks like, and it is not a code defect. This lane
freed its own scratch and re-ran; the second Highcourt seed (§4.1) is the one
measurement it cost.

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
