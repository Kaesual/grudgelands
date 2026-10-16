# Keeping player housing at a map reset (study, 0.49.1 lane HKEEP)

Study for [plan 0.49.1](../planning/fix-0.49.1-plan.md) ruling 11 and §4
HKEEP, 2026-10-16. Nothing under `mods/` changes. The question: can a map
reset keep every mapchunk (80 × 80 × 80 nodes at `chunksize = 5`, corners
at −32 + 80k) that holds a player claim, while the rest of the world is
generated again?

Evidence tags:

- **[measured]**: the headless experiment in [§7](#7-the-experiment).
- **[engine]**: read in `reference_projects/luanti` (Luanti 5.17.0-dev,
  `df048790`). Paths are relative to `reference_projects/luanti/src/`.
- **[code]**: read in this repository at `acfd84d4`.
- **[inferred]**: worked out from the above, not run.

## Verdict

**Possible, with conditions.** Five points decide it:

- **The engine keeps kept blocks.** It never regenerates a generated block. In
  the experiment, neighbour generation changed **0 nodes** in the kept
  surface layers (y −32..127). That held with an unchanged layout, and with a
  completely new terrain and layout all around. [measured]
- **Most of the work is in the game.** The platform needs one `DELETE` with a
  rule on block x/z. The game has to keep the listed claims instead of
  clearing them, re-check them against the new layout, and drop the ones that
  conflict. [code, inferred]
- **The seam is the real cost when terrain changes.** A kept column is a
  piece of the old world. On a terrain-changing reset, the stand-in run (a new
  seed) gave a step of **16 to 42 nodes on every one of the 320 border
  columns**. On a reset that keeps the terrain (placement or content changes
  only), the step is 0 to 1 nodes. [measured]
- **The seam can be predicted.** The layout's terrain height
  (`planner_source.column_values_at`) matched the generated ground on all 320
  border columns, in all three boots. So a tool can measure the step before
  anything is generated. [measured]
- **Kept chunks are larger than claims.** A claim is 101 × 101 nodes. Its
  chunk columns cover 2.5 to 5.6 times that area. Kept chunks therefore also
  keep pieces of the old layout outside the claim square: roads, edges of
  villages, possibly an old waystone or mailbox that cannot be dug.
  [code, inferred]

Worth building if map resets stay frequent (0.46.0, 0.47.0, 0.48.0 and 0.49.0
were all resets) and the user accepts visible seams on terrain-changing
resets. Not worth it if future resets will mostly change the terrain and
seams are unacceptable. The decisions are listed in [§6.4](#64-what-the-user-decides).

## 1. Engine: are kept chunks safe from regenerated neighbours?

### 1.1 Kept blocks are never generated again

- **Generation only starts for blocks that are not generated.**
  `EmergeThread::getBlockOrStartGen` first loads a block from memory or disk.
  It returns `EMERGE_FROM_MEMORY` or `EMERGE_FROM_DISK` when `isGenerated()`
  is true, and starts generation only otherwise (`emerge.cpp:551-584`).
  [engine]
- **The flag lives in the block.** It is part of the block's serialized data
  (flag `0x08`, `mapblock.cpp:407-408` and `:533`). It is set only for the
  chunk's own blocks, never for its border blocks (`servermap.cpp:325-344`).
  [engine]
- **So a block kept in the database stays as it is**, as long as no generation
  overwrites it as a border block (§1.2).
- **Measured:** in boots 2 and 3, every block of the kept column K came back
  `from_disk` or `from_memory`, never `generated`. The chest kept its meta and
  inventory, and the item entity was still there (static objects are part of
  the block). [measured]

### 1.2 The one-block overgeneration shell and `blitBackAll`

- **Generation works on a padded area.** A chunk is generated in a VoxelManip
  over the chunk plus a one-block shell (`EMERGE_EXTRA_BORDER {1,1,1}`,
  `servermap.h:175`). [engine]
- **Existing neighbour blocks are copied in.** `initBlockMake` loads every
  existing block of that area from disk (`emergeBlock(p, false)`). The
  VoxelManip then copies each existing block's nodes
  (`servermap.cpp:229-251`, `map.cpp:771-822`). [engine]
- **The whole area is written back.** `finishBlockMake` calls
  `blitBackAll(changed_blocks)` with `overwrite_generated = true`, the
  default (`servermap.cpp:290`, `map.h:334-335`, `map.cpp:860-897`). The shell
  blocks of a kept neighbour are therefore always written back. [engine]
- **Unchanged nodes come back unchanged.** The write-back holds whatever the
  VoxelManip holds. A shell node that no generation step touched returns as
  it was. `copyFrom` copies only node data (content, light, param2), never
  metadata, timers or objects (`mapblock.cpp:224-234`). [engine]

Which generation steps can change a node in a kept neighbour's border block:

| Step | Reaches the shell? | Our settings | Effect on kept blocks |
|---|---|---|---|
| v7 base terrain | y ±1 only, and only where the node is `CONTENT_IGNORE` (`mapgen_v7.cpp:539-545`) | — | none: kept nodes are never ignore [engine] |
| Biome top and filler, dust | Biomes: own columns only (`mapgen.cpp:633-634`). Dust can fall from the chunk above (`mapgen.cpp:769-830`) | **zero** engine biomes (`default/mapgen.lua:2492-2498`, GRUG PATCH), so no dust | none [code] |
| Noise caves and caverns | own area (`mapgen.cpp:833-887`) | on | none [engine] |
| Random-walk caves | **yes**: they carve every ground-content node inside the VoxelManip and can flood with water or lava (`cavegen.cpp:569-590`) | v7 defaults: no small caves; 0–2 large caves per chunk, only in chunks whose top is at or below y −33 (`mapgen_v7.h:31-35`, `mapgen.cpp:861-873`) | **carves and floods the side blocks of kept chunks at y ≤ −33**, up to 16 nodes deep. Player nodes with `is_ground_content = false` (cobble, chests, …) are spared [measured, §7] |
| Dungeons | the full area (`mapgen.cpp:952`) | y ≤ −193 only (`minetest.conf:33-34`) | possible only in deep kept chunks [engine] |
| Ores | own area (`mapgen_v7.cpp:355`) | native | none [engine] |
| Engine decorations | a simple decoration may place one node into air or ignore in the shell (`mg_decoration.cpp:351-362`) | only two cave-floor plants (`r7_native.lua:672-680`) | at most a plant in a cave of a kept chunk [code] |
| Liquids | the transform queue covers the full area (`mapgen_v7.cpp:370`, `servermap.cpp:299`) | — | **water can flow into kept air at the border** [measured] |
| Light | in the shell | our writer relights up to 15 nodes into the halo (`r6_settlement.lua:1358-1371`) | light (param1) only, solved again from the content [code] |

### 1.3 Our Lua writers

- **One writer.** The only content writer is the R7 `register_on_generated`
  (`r7_mapgen.lua:112`, `refine` at `:95-105`). [code]
- **It writes only inside its own chunk.** It receives the 16-node halo
  (`r6_settlement.lua:2292-2295`) but writes content only inside the chunk
  ("owner"):
  - `write_intent` fails on any write outside it (`:2386-2391`);
  - the halo bytes are copied unchanged into the buffer it writes back
    (`:2319-2324`, `:3478-3487`). [code]
- **Decorations and trees stay in their own chunk.** A footprint that crosses
  the chunk border is rejected (`clipped_owner`, `r6_settlement.lua:2001-2010`;
  the "treeless bands" of the
  [R6 contract §8.2](wp40-simple-map-r6-contract.md)). A neighbour's tree
  never grows into a kept chunk. [code]
- **No deferred writes.** There is no `set_node`, `place_schematic` or
  `emerge_area` in the pipeline, and nothing is queued for later chunks.
  [code]
- **It reads the halo in two places.** Both relate to vertical neighbours:
  - a kept chunk below a new one counts as "the committed result of the
    preceding slice" (`r6_settlement.lua:2434-2441`);
  - R5 reads the content directly above and below its own columns
    (`map_adapter.lua:1249-1265`).

  With whole columns kept (§1.4), no new chunk is ever stacked on old content
  in the same column, except chunks of that column that were never generated
  (§3.3). [code, inferred]
- **Measured:** with the same seed and code, the neighbours regenerated next
  to K were byte-identical to the original, except where K's own generation
  had once carved caves into them (§7). [measured]

### 1.4 Whole column, or only the claim's heights?

**The two answers are the same.** A claim covers every y from −100 upward
with no upper limit (`registry.lua:33-34`; housing.md §1). So "the chunks the
claim's height reaches" are all chunks of the column from layer −112..−33
upward. That is everything ever generated there, up to the flight ceiling in
full-preparation worlds.

**Recommended: whole chunk columns at every height**, including the deeper
blocks and the border blocks that were never generated. Reasons:

- the rule needs only block x and z (one SQL predicate, §5.2);
- no horizontal seam inside a column;
- the writer never builds a new chunk on old content in the same column
  (§1.3).

**Claim footprint in chunks.** 101 nodes span 2 chunks per axis, or 3 when
`(x − 50 + 32) mod 80 ≥ 60` (one in four). So a claim keeps 4 columns (9/16
of claims), 6 (6/16) or 9 (1/16): 5.1 on average, which is 25,600 to 57,600
m² for a 10,201 m² claim. [inferred, arithmetic]

**What remains across a column's sides:**

- deep random-walk caves cutting into the column below y −33, possibly
  flooded;
- water flowing in;
- a player's edit inside the outer 16 nodes of the column that lands while a
  neighbour chunk is being generated is lost. Generation runs without the
  environment lock between `getBlockOrStartGen` and `finishGen`
  (`emerge.cpp:545-584`, `:588-600`, `:729-753`), and `blitBackAll` then writes the old
  copy back. This is ordinary engine behaviour at every map frontier. It is
  only more likely right after such a reset, because every kept column then
  borders ungenerated land. [engine, inferred]

## 2. Layout conflicts

### 2.1 What can fall into a kept chunk

Everything in the layout is a pure function of the seed and the Lua code:

- terrain is "a pure function of (seed, x, z)" (`terrain_field.lua:3`);
- water (`water_layout.lua:14-23`);
- placement (SHA-256 of seed and anchor id, `placement.lua:37-48`);
- roads and capital layouts (`r7_runtime.lua:120-124`). [code]

A reset is declared because the code changed, so the new layout can put
anything onto an old base:

| Feature | Placed by | Fixed or per seed |
|---|---|---|
| starts, capitals, dragon arenas, apex mines | `simple_map.lua` anchor rows (`:252-378`) | fixed x/z; y from the terrain fit |
| villages, outposts, bandit camps, mines, mirefolk, clashes, rare routes, PvP fortresses and the 16 PvP camps | `placement.lua`, anchors marked `placed` (`simple_map.lua:360-377`) | per seed |
| dragon islands | fixed polygons (`simple_map.lua:150-152`, landings `:226-231`) | fixed |
| roads, trails | road layout (`road_layout`) | per seed |
| rivers, lakes, sea | water layout | per seed |
| waystones, mailboxes | written by the settlement writer at waypoint pads (`world_nodes.lua:45-102`) | with their settlement |
| quest "use at a place" | runtime objects at a clash site or a region-map spot; "nothing is written to the map" (`grug_quests/use.lua:1-12`) | per seed |

### 2.2 Computable before generation: yes

At load, every one of these exists before any chunk is generated. One kept
column can be checked column by column, exactly like the mgprof probe's
"ordinary column" test (`tools/mgprof/grug_probe_mgprof/init.lua`,
`column_report`). The checks:

- `grug_mapgen.wp40.planner_source.column_values_at(x, z)`: water class,
  terrain height, river id, functional feature, hard foundation;
- `road_column_at(x, z)`;
- `grug_zones.hard_protection_kind_at`;
- `grug_core.world_feature_boxes_in` (`zone_authority.lua:490-537`);
- the blueprint boxes of `preparation_source.lua:23-81` (`tile_bounds`).

[code]

**Offline**, `tools/seed_fleet/runtime.lua` builds the same runtime without an
engine, so a portable LuaJIT tool can do the same for a seed and a commit.
[code]

**The test needs the kept columns' area, not the claim square.** Placement
validation checks the 101 × 101 square plus a 16-node margin
(`registry.lua:551-576`, `api.lua:378-385`). A new village 20 nodes outside
the square can still lie inside a kept chunk. It would then be cut off at the
chunk border, missing NPC sockets, a waystone or its mailbox. [inferred]

**Fallback for a conflicting claim: today's behaviour.**

- The claim goes (`needs_stone`) and its owner gets a letter.
- Its columns are deleted again (`core.delete_area` deletes blocks from the
  database, `l_env.cpp:1159-1188`, `servermap.cpp:804-822`), unless a kept
  neighbour claim shares them, so the new layout is generated there.
- **Timing:** the environment exists only after the mods have loaded
  (`server.cpp:534` vs `:566`), so the delete must run on the first server
  step, before the world preparation sends its first emerge. [engine,
  inferred]

**Protection decides the same way.** World protection is asked before the
claim (`grug_housing/protection.lua:42-48`). A kept claim that overlaps a new
town or feature box would silently lose its protection there. The re-check
therefore has to include hard protection and the feature boxes. [code]

## 3. Seams

### 3.1 Measured

Every seam measurement compares the ground height in K's edge column with the
ground height in the column just outside. Ground is the highest walkable
node that is not a trunk or leaf. This covers 4 sides × 80 columns.
[measured]

| Run | Height step across the border | Predicted vs found outside |
|---|---|---|
| boot 1, original world | 0: 224, 1: 82, 2–3: 3, 4–7: 11 (the 4–7 are the probe's own trench) | equal on all 320 |
| boot 2, reset, same seed and code | identical to boot 1 | equal on all 320 |
| boot 3, reset, new seed (stand-in for a terrain change) | **16 or more on all 320**, worst −42 (inside y 64, outside 22) | equal on all 320 |

**Below the surface, with the new seed:**

- K's deep layer (y −112..−33) changed 7,278 nodes;
- 7,247 of them lie within 16 nodes of K's sides;
- the main changes were 3,316 stone → air and 1,956 stone → water source:
  the new neighbours' large caves carved into K and flooded it.

The surface layers changed 0 nodes. [measured]

### 3.2 What a seam looks like

- **The kept column stands as an island of the old world.** It sits as a
  plateau or a pit with vertical walls of up to the full height difference,
  on all sides, 160 to 240 nodes wide. [measured, boot 3]
- **Water spills over unwalled sides.** Where the new terrain is water (sea,
  river, lake) against a lower kept side, water pours into the column (§1.2,
  liquids). [inferred]
- **Roads and rivers of the new layout end at the column wall.** Old roads
  inside the column lead nowhere. [inferred]
- **The world map shows the new terrain over a kept base.** It renders from
  the layout (`terrain_height_at`), not from the map
  (`grug_map/base.lua:14`, `:233`). [code]

### 3.3 A seam that is not at the sides

**Possible cause: a column chunk that was never generated.** A column chunk
above the kept ones (for example y 128..207) may never have been generated.
It is generated later from the new layout. If the new terrain there is
higher than 127, the writer fills it with new ground above the old base. The
result would be a slab over the kept terrain. Not measured. [inferred]

**Proposed fix.** The preview below flags it: the new terrain height inside
the column compared with the column's highest kept layer.

### 3.4 Can a tool tell the admin beforehand? Yes

**The new side needs only the layout.** It is the new layout's
`column_values_at` terrain height and water class, which matched the
generated ground exactly in every run. [measured]

**The old side has three sources:**

- **From the kept blocks.**
  - In the game: read with a VoxelManip after the deletion, at the reset
    load.
  - Offline: needs MapBlock decoding, which is the platform's
    not-yet-built "deferred map part" (upgrade contract §5.2).
- **From the old commit's layout.** Exact for terrain the players did not
  change; boot 1 shows predicted equals found.

**The preview per claim:**

- the largest step on each side;
- the share of border columns over a threshold;
- new water against the column;
- new features inside the columns (§2.2);
- new ground above the column's top (§3.3).

All of it is computable with code that exists (`seed_fleet/runtime.lua` for
both commits).

**Recommended: a portable preview run before the release**, from the old and
the new commit and the claim list. Real gate data would be a step threshold
the user picks. [inferred]

## 4. Map-bound state

| State | Today at a reset | With "keep housing" |
|---|---|---|
| Claim registry `claim:<id>`, `player:<name>` (`registry.lua:207-220`, cleared through `api.lua:25`) | every claim goes; a placed owner becomes `needs_stone` | listed claims stay `placed`; a claim that fails the re-check (§2.2) falls back to today. Needs a change to `map_reset`. [code] |
| The stone node | goes with the map | stays; the 5 s check finds it (`stone.lua:230-258`). A dropped claim whose stone stands in a column shared with a kept claim leaves an undiggable orphan (fuelled stones: `can_dig = false`, `stone.lua:132`), so the drop must also remove the stone node. [code] |
| Player meta `grug_home:claim` (travel home) | cleared at the relocation (`claim_home.lua:132`) | kept for kept claims. The join check `deliver` (`:104-118`) then sends no "gone" notice. [code] |
| Character position | moved to the race start (`grug_core/map_reset.lua`, `grug_classes/selection.lua:584-621`) | unchanged (recommended): positions elsewhere are on the new map, and the owner travels home. [inferred] |
| Travel home | — | works once the arrival cube is clear (`travel.lua:64-68`, fallback innkeeper `:202-215`). [code] |
| `grug_mobs` records (`grug_mobs/map_reset.lua:11-20`) | cleared, `live_gen:` kept | unchanged. Rares and dragons in kept blocks are removed as stale by their liveness generation on activation (`liveness.lua:89-99`, `:145-154`). [code] |
| Static objects in kept blocks | gone | **stay** [measured: the item entity]. Wild mobs saved near a player come back [inferred]. An old-layout **settlement NPC** in a kept chunk would stay for good: NPCs are never culled (`mobs/api.lua:3495-3498`), and `start_npc_claim` (`start_npcs.lua:549`) does not check that its settlement still exists. Needs a small guard [code, inferred]. Mounts and markers are `static_save = false` (`grug_mounts/entity.lua:573`). [code] |
| Node meta, inventories, timers | gone | stay [measured: chest meta and items]. Workspaces, crops and hearths are re-armed by run-at-every-load LBMs (`workspaces.lua:454`, `grug_farming/init.lua:127`, `:548`). [code] |
| World preparation (`starts_preload.lua:7-13`) | restarts from zero | unchanged. Kept blocks count as done (`FROM_DISK` accepted, `:149-157`). [code; measured: preparation finished in boots 2 and 3] |
| Protection | the town and feature layers come from the new layout | the same. They win over a kept claim (§2.2), hence the re-check. [code] |
| Old-layout nodes inside kept chunks beyond the claim square | gone | stay: old roads, edges of villages. Old waystones and mailboxes cannot be dug (`world_nodes.lua:49-102`). Whether a stale waystone's right-click handles a missing socket gracefully is not checked. [inferred] |
| Items or nodes a release removes | gone with the map | remain in kept chests and builds as unknown items or unknown nodes. A step cannot reach them until the deferred map part exists (upgrade contract §5.2). [code, inferred] |

## 5. Platform

### 5.1 Today

The platform does three things (upgrade contract §1, §3.1):

1. stops the server;
2. empties the map table and raises `grug_reset_world`;
3. starts the server.

The seed and `map_meta.txt` survive. With a migration, the order is: empty
the map, run the tool, raise the setting. Production keeps the map in
PostgreSQL (`blocks(posX, posY, posZ smallint, data bytea)`,
`database/database-postgresql.cpp:164-170`) and mod storage in SQLite.
[engine, code]

Neither the repository nor the platform task files hold any code that reads
or writes map blocks. The migration tool handles player, auth and mod
storage only (`tools/migration/world.py:40`). [code]

### 5.2 Proposal: the reset mode "map reset, keep housing"

**Where the admin chooses.** The admin picks the mode when the platform
offers a map reset. The version declaration (`upgrade.json`) stays as it is:
"keep housing" is an option of the map-reset outcome, not a new outcome.

**Steps:**

1. **Stop and back up**, as for a migration.
2. **Plan.** A repo tool, `tools/keep_housing.py`, Python standard library on
   the existing world API (`tools/migration/world.py`, `data.py`), run from
   the target commit like the migration tool:
   - reads `grug_housing` mod storage: `claim:<id>` = `v2|owner|x|y|z|…`
     (`registry.lua:19-25`);
   - takes the activated claims (`activated_at > 0`; drafts never);
   - computes their chunk columns. The column index of a block is
     `floor((b + 2) / 5)` (`emerge.cpp:339-345`);
   - prints the report: claim, owner, columns, blocks kept.
3. **Apply.** The tool:
   - writes the kept claim ids into `grug_housing` mod storage, for example
     a key `reset_keep`;
   - deletes every block outside the kept columns.

   On PostgreSQL that is one statement:

   ```sql
   DELETE FROM blocks
   WHERE (floor((posx + 2) / 5.0)::int, floor((posz + 2) / 5.0)::int)
         NOT IN (SELECT cx, cz FROM keep_columns);
   ```

   On SQLite it is the same rule over `x`, `z`
   (`tools/r491_hkeep/keep_columns.py` is the study's version).
4. **Raise `grug_reset_world` and start.** The game finishes, then reports
   the kept and dropped bases to the admin (log and a letter or ticket):
   - it keeps the `reset_keep` claims and clears the others as today;
   - it re-checks each kept claim against the new layout over its columns;
   - it drops the claims that fail, deletes their columns on the first
     server step and writes to their owners;
   - it keeps the home of each kept claim at the relocation;
   - it removes the key.

**Speed.** The deletion is one statement over the primary key's columns. The
experiment's SQLite version over 21,641 blocks was not timed but did not
show up in the run's wall time. [inferred]

**Combined with a migration.** The order stays: map, tool, setting. Steps
still never touch the map. Items that a step removes survive in kept chests
(§4, last row).

## 6. Proposal

### 6.1 Lanes

| Lane | Content | Rough size |
|---|---|---|
| **KH-GAME** | `grug_core.map_reset` gains the kept-claims input. `grug_housing.map_reset` keeps the listed claims and re-checks each one over its columns: the zone and territory rules of `M.validate`, the feature boxes, hard protection, functional features and settlements, with roads and rivers as decided in §6.4. A dropped claim gets `delete_area` on the first step (before the preparation dispatches), its stone removed and a letter. `grug_home` keeps the home of kept claims. A `grug_mobs` guard removes a settlement NPC whose settlement key is not in the new roster. Admin report. Fixtures; the engine test extends `tools/r41_up/engine.sh` with a kept column, like this study's probe. Contract §3 and housing.md. | medium, about Round 41 lane UP |
| **KH-TOOL** | `tools/keep_housing.py plan\|apply` on SQLite and PostgreSQL, with a test (SQLite plus PostgreSQL, as `tools/r45_ms`). The platform task file gets the new option. | small to medium |
| **KH-PREVIEW** (optional) | Portable LuaJIT preview from the old and the new commit and a claim list: steps per side, new water and features in the columns, new ground above the column (§3.4). | small to medium |

**Runtime cost.** Work happens only in the reset boot: about 6,400 to 57,600
column checks per claim. Not measured; with `column_values_at` at a few to
tens of µs, that is estimated at well under a few seconds per claim. Nothing
changes in normal play. [inferred]

### 6.2 Risks

1. **Seams on terrain-changing resets**: cliffs of 16 or more nodes on
   every side in the stand-in run, and water spilling over. [measured]
2. **Deep side damage**: new large caves carve into the column's sides at
   y ≤ −33 and flood them (7,278 nodes in one chunk). Player mines near a
   column side can flood. [measured]
3. **Old-layout fragments** in the kept chunks beyond the claim square: old
   roads, parts of old villages, undiggable old waystones or mailboxes, and an
   old settlement NPC without the guard. [inferred]
4. **New ground above a kept column** whose top layer was never generated.
   [inferred]
5. **Removed items or nodes** remain in kept builds as unknown items or
   unknown nodes. [code]
6. **Lost player edits** at a column side while a neighbour generates.
   Low risk. [engine]
7. **The world map and spawn regions** describe the new terrain at kept
   places. [code; spawn regions inferred]

### 6.3 Why not something smaller

- **Keeping only the claim square** needs the deferred map part and a node
  merge, against "whole chunks are enough" (ruling 11).
- **Keeping only the stone's chunk** loses most bases. A claim always spans
  at least 2 × 2 columns.
- **A per-version "keep allowed" flag** can follow later, if needed.

### 6.4 What the user decides

1. **Build it at all.** Recommended: yes, if resets stay frequent and seams
   are acceptable. Otherwise park it.
2. **Whole columns at every height** (recommended), or only the layers from
   −112 upward. Same result for the claim.
3. **Which claims.** Activated claims, including those whose fuel ran out but
   whose stone still stands (recommended). Drafts never.
4. **Conflict rule.** Drop on new settlements, POIs, PvP sites, towns,
   landmarks, hard protection, or a zone outside the claim rules
   (recommended). For new roads and rivers: drop as well, or keep and accept
   the truncation (recommended: keep, list in the report).
5. **Seam rule.** Admin decides per claim from the preview (recommended), an
   automatic drop above a step threshold, or no check.
6. **Old fragments.** Accept them (recommended for a first version), or have
   the reset load remove authored nodes such as waystones and mailboxes
   inside kept columns.
7. **Removed items with a migration.** Accept unknown items in kept chests,
   or refuse "keep" on releases whose step removes items until the deferred
   map part exists.
8. **Where the preview runs.** The coordinator on the workstation, from an
   exported claim list (recommended), or the platform (which would need
   LuaJIT or a test realm).

## 7. The experiment

**Files:**

- `tools/r491_hkeep/run.sh OUT`: three boots through `luanti_headless.sh` and
  the shared Lua queue, about 3.5 minutes in all;
- `grug_probe_hkeep/`: a disposable probe, staged only;
- `keep_columns.py`;
- receipts in `tools/r491_hkeep/evidence/`.

**Setup:**

- seed 12345;
- kept column K: chunk corner x 368, z −2352 (meadow land, terrain y 34–65,
  pinned by `tools/mgprof`);
- region: 3 × 3 chunk columns × 3 layers (y −112, −32, 48), so 27 chunks.

**The boots:**

1. **Boot 1 (fresh world).** The world preparation runs, then the probe emerges
   the region in 5.4 s. It places markers on K's west edge:
   - a cobble pillar;
   - a trench 4 deep against the neighbour;
   - a chest with meta and 5 apples;
   - an air pocket at y −100;
   - an item entity in K's middle.

   It then snapshots node names and param2 of all 27 chunks.
2. **Between the boots.** `keep_columns.py` deletes every block outside K's
   column: 21,216 of 21,641 deleted, 425 kept (5 × 5 × 17 blocks).
   `grug_reset_world = 1` is raised, as in `tools/r41_up/engine.sh`. A copy of
   the world gets the seed 4242 in `map_meta.txt`.
3. **Boot 2 (same seed).** Reset applied (claims, mob records and preparation
   cleared). The region emerges in 4.9 s.
   - K's blocks came only from disk or memory.
   - K's layers at y −32 and 48: **0 changed nodes**.
   - K's layer at −112: 61 changed, all water flowing on in a flooded cave
     next to the pocket.
   - Markers: pillar, trench and chest intact, item entity present. The pocket
     had filled with water before the boot-1 snapshot.
   - Neighbours: 24 of 26 chunks identical. The two different ones,
     c−1_0 and c−1_1 at −112, differ only within 16 nodes of K: stone where
     K's own generation in boot 1 had carved its caves into them.
4. **Boot 3 (seed 4242).** The layout caches were rebuilt for the new seed.
   - K's layers at −32 and 48: **0 changed nodes**.
   - Layer −112: 7,278 changed, 7,247 of them within 16 nodes of K's sides
     (caves and flooding from the new neighbours).
   - Markers intact.
   - Seam: all 320 border columns step by 16 or more, worst 42.

**In all three boots:**

- the layout's predicted terrain height outside K equalled the generated
  ground on all 320 border columns;
- no `[GRUG-SEVERE]` or ERROR lines;
- every boot shut down normally.

**Limits:**

- **One column, one place, one terrain type.** A seed change is a stronger
  terrain change than a typical code-driven reset.
- **Not covered:** the vertical case of §3.3, a kept column next to sea or a
  river, and a real claim (the reset cleared it, as today's code does).
