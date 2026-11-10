# All-building table inventory — 2026-11-10

Read-only investigation, performed before the all-building table batch. No shipped
file is changed by this inventory. It reads the **284 current templates**, all
actual start layouts/capital rosters and their palette bindings. The previously
approved six guild-house fixes are already present and excluded from the remaining
pair count. `inventory.py` is reproducible; `inventory.json` preserves coordinates,
source hashes, uses and exceptions; `candidates.tsv` is the complete compact list.
A post-implementation rerun would describe the new state, not preserve this audit.

## Implementation and review

The coordinator has installed all 153 candidate templates after validating the
whole batch. `install.py`, `save-report.json` and `before/` retain the complete
change and exact source snapshots. Independent review: **MERGE**, no findings
([batch review](review.md), [runtime review](review-runtime.md)).

Open [index.html](index.html) for six receipt-checked before/after comparisons
from actual templates; [the bed gallery](../beds/index.html) shows the separate
Dawnmere correction. The implementation updates the active runtime builders as
well ([runtime report](runtime.md)). The earlier investigation below remains a
record of the pre-change inventory.

Integration checks: six start towns **2149 PASS**, six capital cores **3291 PASS**,
NPC facing **43 PASS**, runtime table construction **342 PASS**, complete `r36_w`
decoration fixture **8985 PASS**, Lua 5.1 parsing/sweeps and upgrade declaration
PASS. The shared pre-save candidate gate has **0 errors, 59 warnings**; 30 of
those warnings identify a fixed existing wood material in shared templates.

The final gallery passes **7 browser checks** at 1600/760px: all 12 images
decode, all six comparison headings exist, no horizontal overflow and no
JavaScript errors (`browser-check.json`, `gallery-1600.png`, `gallery-760.png`).

The optional older `r36_w2` seat heuristic reports two Kezamba roof stairs as
benches, at world (11,19,-50)/(43,19,-50). The exact pre-follow-up comparison has
the same two findings. Inspection of `kezamba_kings_hall.tpl` identifies local
(6,19,32)/(38,19,32) as `role roof_stair channel=roof`, facedir 1/3. No bench or
these roof cells were changed, and no test assertion was suppressed. Both logs
are retained (`benches.log`, `benches-before.log`).

## Safe remaining candidates

**575 tabletop cells in 153 templates** are all exact, vertically aligned pairs:
`role table_leg` at `(x,y-1,z)` and normal `role table_top` at `(x,y,z)`. There are
**zero orphan tops, zero orphan legs and zero rotated tops** among these roles.
Replace both cells as a unit: existing complete thin table at the old leg position,
air at the old slab position. Preserve every other cell, all points and bounds.
These are table/counter assemblies, not arbitrary material matches.

| Template family | Candidate files |
| --- | ---: |
| Highcourt | 26 |
| Dur Brannoc | 24 |
| Gor Drazhak | 18 |
| Kezamba | 17 |
| Nhal Veyr | 14 |
| Lethariel | 12 |
| Hearthpine | 9 |
| Sunscar | 9 |
| Silverleaf | 8 |
| Kapok | 7 |
| Dawnmere | 6 |
| Stillgrave | 3 |

Counts are unique template files, not copies of a building in generated worlds.
575 counts table-width cells; a long table/counter consists of several cells.
The tallest list entries (16 cells each) include the Deep Scriptorium, Forge Guild
House, Masons' Guild, Totem Scriptorium and the three elf feast/weaver/lore halls.

Most tops are at y=2 (**554 cells**). The raised buildings have another **18 at
y=6** and **3 at y=4**: `kapok_elder_stilt`, `kapok_fish_smoker`,
`kapok_reed_stilt`, `kapok_river_stilt`, `kapok_weaver_stilt`,
`kezamba_moot_house`. Use relative y−1, never assume all legs stand at y=1.

The ten Moot House tabletop cells at x=2/8, y=6, z=7…11 have `role wall` directly
above them at y=7. Those are the sloping upper wall/roof, **not movable tabletop
props**. Lowering the table must not move or erase those wall cells. All other
candidate table columns have air directly above the old top. No decorative
object stack needs to be lowered with these candidate pairs.

## Similar-looking structures to preserve

The resolved material search finds **36 further slab-over-fence pairs**, exactly
six in each `camp_site_<race>.tpl`. Their entries are `role roof_slab
 o=facedir:20` above `role fence`, at x=8/10, y=4, z=2/5/8. They belong to the
**raised scaffold platform**, not furniture: `tools/r69_camp_art/build.py`,
`Camp.scaffold`, lines 164–179. Preserve all 36. There are no additional fixed-node
fence/slab furniture pairs outside the role-pair inventory.

Existing complete thin tables are already used broadly: the resolved scan finds
117 `cottages_table` cells and 114 `xdecor_table` cells (unique resolved
position/node per template, including optional `board_table` roles and the 60
already-fixed guild cells). These are not the two-node fence/slab problem.
`cottages_table`'s separate small support gap was reported previously; the
coordinator owns the general decor-node follow-up.

Benches use `seat`/stair or complete bench nodes. Their geometry and orientation
must remain untouched. Storage crates, roof slabs, slabs over posts, and raised
scaffolds cannot safely be classified from material names alone.

## Active builder owners

The frozen **153 `.tpl` files are authoritative**. Do not rerun the historical
Round 56 building export to regenerate them. That would overwrite deliberate
later template changes, including the inn-bed correction happening concurrently.
The current guild source `tools/r58_halls/make_halls.py` already emits thin tables
and has no remaining paired roles.

The active runtime furniture constructors also need the same complete-table fix:

- `mods/MAPGEN/grug_mapgen/wp13/parts.lua`, `M.table_cell`: the shared table cell.
- `wp13/dressing.lua`, `M.stall` and `M.counter`: live three-cell market booths
  and variable-length shopfront counters. They can delegate to the table helper.
  The capital and start compositions call stalls directly, and district roster
  `decorate` callbacks call counters after stamping the frozen building (e.g.
  `highcourt_plot.lua:M.build`, lines 187–301 and `highcourt_district.lua:shop_counter`).
  Updating templates alone would therefore miss many outdoor counters.
- `wp13/decor_kit.lua:P.craft` calls `parts.table_cell`; `P.counter` delegates to
  `dressing.counter`. Both run in current regional POI generation through
  `wp40/r14_poi_blueprint.lua` and `wp40/r20_poi_blueprint.lua` (`decor.place`).
  The catalogues contain active craft/counter pieces; these are not only old
  authoring tools.

**Do not globally replace the palette roles.** `decor_kit.lua:P.stores` uses
`table_top` as a board over a storage barrel. `P.rack` uses `table_leg` for weapon
shafts, and `P.lean_to` uses it as shelter supports. A blind role swap damages
those pieces. They should keep their slab/fence materials. The helper-level fix
covers real dynamic tables without changing these unrelated consumers.

## Suggested bounded installation

Build all 153 candidates from freshly read current templates. Use the editor's
`edited_text` canonical serialization, then the shared validator once with the
**whole replacement set** and `builds=True`. Only after zero errors and an
unchanged-source hash check should each candidate be written atomically. This
preserves validation while avoiding 153 repetitions of the complete town build.

The bed lane's `dawnmere_harvest_inn.tpl` correction is separate: that inn
already uses `board_table` and is **not** one of these 153 pair candidates.
An early precautionary message incorrectly treated it as an overlapping file;
the full inventory established there is no overlap. Its six bed/wall cells at
x=1/3, y=1, z=12…14 must remain untouched by the table batch.

Installation changes authored world generation and remains **map reset**. The
inventory itself only writes these evidence files. The coordinator owns mutation,
validation, renderer comparison and integration.
