# Round 70 capitals: from an old layout to a finished core

For the five capital lanes. Dur Brannoc is the worked example: read its diff in
`mods/MAPGEN/grug_mapgen/wp13/dur_brannoc.lua` beside this page. Inputs: the study
`tools/r70_design/` (`proposals.py` for your moves, `data/socket-schedules.json` for your rows,
the page), the castle `tools/r70_castle/INSTALL.md`, the checks
`~/projects/grudgelands-orchestration/r70/reports/design-check.md` and `castle-check.md`.

## What is already done (change none of it)

- **The core's size has one source:** `wp13/precinct_ring.lua`: `RADIUS` 56 (the ring), `PAD` 57
  (a composition's `RADIUS`), `CIVIC_WIDTH` 112, `CORNER` 55 (the corner towers). The compositions,
  `city_green.lua`, `capital_planner.lua` `DEFAULTS`, `r7_settlement.lua` `BOUNDS.capital_core` and the
  plot collar, `r7_capitals.lua` `core_landing` read it. `civic_width` in `wp40/source/simple_map.lua` is
  data; `r7_capitals.lua` fails the load if it differs.
- Your composition already reads `precinct_ring.PAD`, your north and east gates are on `RADIUS - 6`
  and your corner towers on `precinct_ring.CORNER`.
- **Your core still holds its old layout** at the old coordinates, inside a pad 8 wider on every side:
  the gates moved out alone, so an empty band lies between them and the old quarters. That builds, and
  it is not the design. Comments that say 96 × 96, ±47 or radius 48 are yours to correct.
- **Water:** both lakes' `keep.half` is 57, so the water is the plain chain inside the pad. Lethariel's
  `MERE` runs to z 57 and x ±57. Neither chain has moved yet.

## The steps, in the order that keeps the gate useful

1. **Install the castle.** Copy your `tools/r70_castle/candidates/crownward/castle_<race>.tpl` to the
   destination in INSTALL.md, set its `name`, change the roster's `use` line. Set the plot's `x`, `z`,
   `turns`, `palette` and `roof` in `PLOTS`; keep `drop = {waypoint = true}`. Odd turns occupy 35 × 45.
2. **Move `BASELINE` on your branch.** `check.py` now fails `box_baseline` and `point_baseline`, as
   expected. Commit, write that commit's full hash into `building_templates/BASELINE`, commit again
   (the format doc §6.2; the brief is the coordinator's approval). At the merge it is the coordinator's
   (below).
3. **Move the plots** by your study `shifts`. Every `x` or `z` literal of a shifted plot, and everything
   that was placed relative to it. Run `python3 tools/building_templates/check.py` after each batch: it
   builds every capital and names the prop or plot that broke (8 s).
4. **Rewrite `STREETS`, kerbs and forecourts** from your study `roads` (`[x0,z0,x1,z1], width`, or a
   polyline). Old flank lanes run through the castle: delete them. Any gate forecourt lane must cover the
   watch rectangle: `{-8, -(RADIUS - 7), 8, -(RADIUS - 12)}` and its three turns.
5. **The Lua furniture** is the real work; the study moved only template rows. In Dur Brannoc `COURT_X` moves
   a whole court with one number. Go through booths, stacks, crates, lamps, benches, planters, drums and trees:
   a prop refused with "the space is taken" is the good case, a lamp or tree silently skipped is not.
   `layout.street_lamps` stands at x ±3: on a nine-wide avenue that is the carriageway, write the lamps on
   the kerb at ±5. A bench or planter at the old avenue's edge stands in the new one.
6. **Sockets:** `CORNERS` and the composition's own `socket(...)` calls to your rows. A row that cannot hold
   goes into `MOVED` in `tools/r70_cap/portable_test.lua` with its reason, and into your report.
7. **Landmarks:** `avenue_*`, `main_street`, `throne_approach`, `forecourt` and every box written in literals.
   `nave_floor` is gone with the old hall: drop it. Header comments last.
8. **Add your capital** in its own rows of `DONE`, `CASTLE` and `MOVED` in `tools/r70_cap/portable_test.lua`
   (`plot` is your castle's landmark id: Gor Drazhak `warlord_hall`, Nhal Veyr `mausoleum`), then
   `luajit tools/r70_cap/portable_test.lua . <capital>`. It reads your king, door and dais from the sockets.
   On the old layouts the walk fails two ways your rework must clear: Highcourt's `chapel` inside point,
   Kezamba's `watch_south_east` (44,−44).

## Pitfalls we hit, or the checks predicted

- **Bench, lamp and tree positions next to a moved plot** do not fail: `outdoors` and `layout.free` skip them.
  Print the plan (`tools/r70_cap/portable_test.lua` walks it; a quick top view of `bp.cells` is worth writing).
- **The plaza's kerb** must clear a moved colonnade's eaves, and its centre decides `travel_waypoint`.
- **`gate_north`'s rectangle** lies at z 45–49 in the four north-facing castles: one free row between the castle
  and the bypass. Do not pave a bypass over z 45 without it, and keep trees off it.
- **A patrol leg over 32 nodes** first tries the streets, and core ground has none: the planner's roads begin
  outside the pad. It falls back to pieces of at most 24 on the straight line. `capture.sh` runs every leg
  through the real cache and logs each one: a logged leg with `none` needs a nearer corner. It logs patrol
  legs only; a `none` in the cache's totals from another walker is not a failure of your lane.
- **Nametags show through walls:** the two "Accord Guard" labels in the throne shot are the north gate's watch.
- **The castle's door:** `kings_hall_door` is the first `doors` point, now on the forecourt at y 1, not y 3.
- `PANE_CONNECTS` in `parts.lua` lacks the ornamented stones: add them only if a wall of yours puts one
  next to a pane. Dur Brannoc's does not.
- **Highcourt:** chapel, `north_house` and the chapel house move 8 west, with `chapel_quest`; the study's
  bypass passes between chapel and castle.
- **Gor Drazhak:** `court_idle_wain`, `court_work_fire`, `court_idle_store`, `precinct_walk_court` fall
  inside moved boxes; the schedule holds their new cells.
- **Nhal Veyr:** the close patrol round the mausoleum becomes a loop round the castle; `citadel_walk_north`,
  `precinct_walk_north` and `core_spare_*` have rows.
- **Lethariel:** the castle turns once and faces east. Move the chain 14 north in `water_authored.lua`, re-cut
  with `python3 tools/r70_cap/lake_table.py lethariel` (shifted is the default), and move `CAUSEWAY_FROM`
  and the quay head (the study's z 32–35, x ±3, written outward). No north crossing exists: the comments and
  `settlements.md` that say one does are yours. The mere's district pin drifts inland; report it.
- **Kezamba:** castle with turn 2, no gatehouses, no `gate_watch`. Move the chain 18 north, re-cut `LAGOON`
  with `lake_table.py kezamba` (it covers ±80, the composition reads the pad; the file's rows beyond stay
  moved with the chain or go, the planner never reads them). `cenote_fish_3` to (−8,41). The east boardwalk
  goes and that avenue becomes paving. `kezamba_lagoon.lua`'s `REACH` and comments follow.
- **`core_landing`** reads `PAD - 3 .. PAD`, y −1..1, ±3 across: a deck must reach that band or the avenue starts
  on the far shore. The lake's bounds move the POI exclusion by themselves (`placement.lua`).

## What every lane verifies

| Check | Command | Notes |
|---|---|---|
| Template gate | `python3 tools/building_templates/check.py` | hard gate, also `--self-test` |
| Shared test | `luajit tools/r70_cap/portable_test.lua . <capital>` | your capital in `DONE` |
| Pins, your capital's rows only | `tools/r36_w/baseline.tsv` (your `<capital>/core` line, through `baseline.lua`), `tools/r51_ft` `CAPITAL_TREES`, `tools/r56_freeze_capitals` `FROZEN`, `tools/r58_townfix` `HALLS` (add the roof channel) | run those four fixtures; no reason comment lines in shared headers (they conflict): the reason goes in your report |
| Planner | `lua_run.sh <label> 4 tools/r70_cap/plan_seeds.sh OUT_DIR` | six seeds; plots against the study's `today`, new unrouted streets. Fix those that cut off a required plot, report the rest |
| Engine | `XVFB=… CAPITAL=<capital> SEED=12345 lua_run.sh <label> 1 tools/r70_cap/capture.sh OUT_DIR` | **one** capture per capital; shots to `r70/shots/<lane>/`; read `probe.txt`: king and guards at their sockets, every leg, the seat's path to the door |
| Lethariel, Kezamba | `tools/r51_lk`, `tools/r34_f3` | the second of the two lanes re-pins `r34_f3` with both lakes moved, if it changes. `tools/r70_design/verify.py` has the fishing regression |

**No fleet and no full fixture run in a lane:** one of each runs on main after the batch (the user's rule).

## Merging (the coordinator's order)

Any capital order, one at a time: main into the lane, resolve `BASELINE`, commit M, write M's hash into
`BASELINE`, commit, `check.py` and `r70_cap`, `lane_merge.sh` (`--no-ff`). `BASELINE` and any hash pin in a
conflict are the coordinator's: a lane does not edit them on merge. `DONE`, `CASTLE`, `MOVED`, `FROZEN`,
`CAPITAL_TREES` and `HALLS` keep one row per capital with a comment line between rows, so parallel lanes do
not touch adjacent lines: keep those lines.

Docs: your capital's paragraph in `settlements.md`, the dry-edge table, and for the lakes the shore and quay
text and `world_zones.md` §7.4. The four-guard lines and the 96 × 96 rule are already fixed.
