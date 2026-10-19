# Round 51 — Land zones and the sea

Coordinator: Claude (Opus 5.5), drafted 2026-10-19 from two partial plans and
revised the same day after an independent read. Status: **complete on main**
(2026-10-19, not pushed; GUI test open; [completion](#completion-2026-10-19)).

The round builds two partial plans together. The **rulings stay in those
plans** and are cited here by number:

- **L1–L19:** [land plan](round51-land-plan.md) §2, the land zones.
- **S1–S20:** [sea plan](round51-sea-plan.md) §3, the sea.
- **Wreck rulings:** sea plan §5a, cited as "§5a.1–3".

This file owns the lanes, waves, dependencies, file ownership, interfaces and
gates. Where it and a partial plan disagree, the partial plan's ruling wins,
and the coordinator fixes this file. Every lane brief quotes the rulings it
implements in full.

**In short:**
- **Land.** Every zone gets a few characteristic changes, picked by the user
  in a concept viewer first:
  - jungle: lianas, flowers, ferns, bushes, fallen logs;
  - undead: small graveyards, ruins, statues, varied bones;
  - dwarves: boulders, lichen, cairns, alpine plants, ice;
  - orcs: bones, withered bushes, clay bands;
  - elves: ruins, statues, pastel flowers, fallen logs;
  - calm 2 × 2 ground textures;
  - the papyrus fix, a little on the beaches.
- **Sea.**
  - a larger map with depth colouring;
  - a clean bay classification;
  - a wide coastal belt;
  - shallow organic dragon channels;
  - seabed growth with seagrass;
  - protected deeper water;
  - water mobs by water band, quest-ready;
  - shipwrecks as decoration.

Release **0.51.0** with **one map reset** for both parts (L3, sea plan
header). Push only on the user's word.

**Routing** (confirmed by the user, 2026-10-19, as in the last rounds):
- Claude coordinates.
- Opus implements and reviews.
- Astra makes art only, with no fixtures.

## 1. Lanes and waves

The round has a **design wave**, because the user picks before anything is
built (L1, S18, S20, sea plan §5a).

| Lane | What | Wave | Kind | Waits for |
|---|---|---|---|---|
| TERRAIN | The joint mapgen lane for terrain and surfaces, land and sea, in steps T1–T4 (§2) | 1–2 | mapgen | T3: ARTS's seagrass pick; T4: the land picks and LG merged |
| VIEW | The land concept viewer (land plan §5): zone switcher, today vs proposal, kit with drops, flowers and beach marram next to the gathering plants (L11), texture lab | 1 | concept (tools only) | — |
| ARTL | Astra, land (land plan §5): swamp moss, the 32 px grounds, structured silver litter, clay-band colours; plants; props | 1 | art | props: VIEW's prop format (§4.2) |
| ARTS | Astra, sea: seagrass, wreck textures (mast, rope, sail tatters, waterlogged planks), on a pick page | 1 | art | — |
| NAMES | Water families, level ladders and names, on a preview page (S17, S18, sea plan §5) | 1 | design | — |
| WRECK | Shipwreck design: 2–4 shapes on a preview page first (S20, §5a); then nodes and placement | 1 (design), 2 (build) | design, then nodes and mapgen | build: the user's pick, ARTS picks, T2 merged |
| LG | Land grounds and nodes: world-aligned tiles, the swamp set, the swamp moss node, forest moss, clay-band nodes, hanging-moss strand/end | 2 | nodes and textures | the land picks |
| LP | Land plants: lianas, flowers, ferns, bushes, lichen, alpine plants, beach plants and driftwood, their rows and regrowth, the papyrus fix | 2 | nodes and mapgen rows | the land picks; LG merged |
| LK | Land kit: prop nodes, skeleton set replacing `bone_pile`, boulders, cairns, ruins, statues, graveyards, fallen logs, dead pines; the towns' graveyards | 2 | nodes, schematics, rows | the land picks |
| MOBS | Water mob ports, spawns by water band, swimmer reset, Bay and Abyssal Shark, fish loot, the quest-ready contract (S10–S17, sea plan §4–§6) | 2 | mobs and data | NAMES accepted; spawn step: T2 merged |
| MAP | Depth colouring, the larger atlas, the map qualities (S1–S3) | 2 | map rendering | T1 and T2 merged |
| D | Documentation, version 0.51.0, the upgrade declaration with the map reset, gate list | 3 | docs | last merge |

The **user's picks** are the gate between the waves:
- the land concept viewer (zone by zone, the cairn form, the sand texture);
- ARTL and ARTS on their pick pages;
- the names page;
- the wreck page.

Rework goes back to the design lane in question. A zone the user has not
picked yet does not hold up the others: LG, LP and LK may start with the
picked zones and add the rest as follow-up steps.

**Out of scope this round:**
- new islets (S9);
- seals and cold coasts (S16);
- underwater POIs (S19);
- the sea turtle with flippers (S15, later art);
- glowing plants and decorative mushrooms, mushroom rings included (L10);
- copper-green ore stains, not even designed (L19).

**Estimates** (unmeasured, for planning only), each lane plus its review:

| Lane | Hours |
|---|---|
| TERRAIN | 26–38 (T1 6–10, T2 12–16, T3 4–6, T4 4–6) |
| VIEW | 8–12 |
| ARTL | 6–10 (two passes) |
| ARTS | 2–4 |
| NAMES | 4–6 |
| WRECK | 3–4 design + 6–8 build |
| LG | 6–10 |
| LP | 10–14 |
| LK | 14–18 |
| MOBS | 20–30 |
| MAP | 6–10 |
| D | 3–4 |

TERRAIN is the largest and riskiest lane: the world bounds are hard-coded in
about a dozen places (sea plan §2.5). MOBS touches the most data.

## 2. TERRAIN — the joint mapgen lane

One lane owns the terrain and surface changes of both parts, because they meet
in the same files. Sand above and below water is the clearest case (land plan
§4 "Sand", §8). The lane works in **steps**. Each step is merged after its
own review, so the lanes that build on it can start.

**T1 — world bounds (S2, sea plan §2.5).** Every bound grows by 450 nodes in x
and 400 in z. Land shapes use absolute coordinates, so no land moves.

| Bound | Today | Target |
|---|---|---|
| Zone bounds | ±3740 × ±3340 | ±4190 × ±3740 |
| Terrain grids (`terrain_data.lua:117`) | ±3808 × ±3424 | ±4258 × ±3824 |
| Atlas (MAP's, see below) | ±3600 × ±3200 | ±4050 × ±3600 |

The places T1 changes:
- `zones.lua`, `height.lua`, `simple_map.lua` (query bounds);
- `world_protection.lua`, `r6_planner.lua`, `r6_settlement.lua`, `r7_p9g.lua`;
- `terrain_data.lua`;
- `grug_core/preparation_plan.lua`;
- `tools/seed_fleet/seed.lua:35` (`X_LIMIT, Z_LIMIT`).

The atlas (`grug_map/atlas.lua`) and the qualities (`grug_map/base.lua`) are
MAP's: normal 1215 × 1080, high 3600 × 3200 (S3).

**T2 — the sea's shape** (S4, S5, S6, S8; the shapes live in
`source/simple_map.lua`, `terrain_field.lua`):
- **Bays:** the classification fix, with no open-sea specks at bay rims and
  an organic bay-to-open-sea edge instead of the straight cut (S4).
- **The coastal belt:** the open sea begins about 250–350 nodes off the coast
  (a rough target). The belt belongs to the zone on land: level, faction and
  PvP rule (S5).
  - T2 writes down the belt's **depth profile**. S7 wants coral to about 10
    nodes deep and kelp to about 20 across the belt.
  - T2 also gives WRECK a **depth band** where a mast can reach the surface.
- **Dragon channels:** organic, 9–11 nodes deep, with the mob level of their
  island (S6).
- **Protected water (S8, in full):** bay and belt water **24 nodes or more
  from the coast** is immutable like the open sea. No building, no mining
  (the seabed included) and no Claim Stones there. The shore stays
  alterable. The border uses the **coast distance, not the water depth**.
  - Coordinator's reading: channel water follows the same coast-distance rule
    as sea water. Lakes and rivers are not protected.
- **The water query.** T2 exposes one query per column, which MAP and MOBS
  only read:
  - the water class: lake, river, bay, belt, channel or open sea; swamp pools
    count as lake;
  - the zone and its mob level, for a channel its island's;
  - the distance to dry land and the depth;
  - whether the column is protected.

  MOBS's water bands (S10) and MAP's bay/lake colours (S1) come from it.

**T3 — seabed growth (S7).**
- Coral patches to about 10 nodes deep, kelp meadows to about 20, and the
  new seagrass node (T3's, with ARTS's texture). The deep sea stays bare.
- The soil lists and `M.reef` live in `world_content_catalog.lua`, the
  growth in `world_content.lua`.
- Stormkelp stays harvestable inside protected water (sea plan §6.2).
- Seagrass and kelp regrow like the land plants (L18; the user, 2026-10-19).
  Coral patches stay as generated.

**T4 — land surfaces, after the picks** (L5, L17, land plan §4):
- **The swamp's moss ground** moves to LG's new swamp moss node in every
  mapgen place that lists `grug_nodes:dirt_with_moss` for the swamp:
  - `r6_content.lua:659`, `:951` (host tables, ground mix);
  - `swamp_writer.lua:52-53`;
  - `r7_r6_manifest.lua:152-154` (swamp fern hosts);
  - `world_content_catalog.lua:21-22`;
  - `tree_templates.lua:95`.

  `dirt_with_moss` stays the elf-forest moss with its new texture (L5).
- **The orc clay bands:** LG's band nodes on steep badlands slopes.
- **Ice patches** (`default:ice`) in the snowy crags' surface mix.
- **Pebble patches** on the beach: `default:gravel` patches in the sand mix,
  with no new node.
- **Sand below water**, as the sea needs it (§3.1).

**Out of TERRAIN:**
- decoration rows (LP, LK, WRECK);
- node definitions and textures (LG, LP, LK, WRECK); the seagrass node is the
  one exception, T3's;
- mob spawning (MOBS);
- map rendering (MAP).

## 3. Decided by the coordinator (the user may overrule)

1. **Sand and beaches** (land plan §8, the user leaning to land):
   - Sand **above water** belongs to the land part: beach plants and driftwood
     in LP, pebble patches in T4.
   - Sand **below water** belongs to the sea part, through TERRAIN.
   - A 32 px sand, if picked, is a **retexture of `default:sand`** (LG), not a
     new node, because the crab's shore host is exactly `default:sand`
     (`spawn_regions.lua:667`). It shows above and below water, so VIEW also
     shows it as a pool bed.
2. **Two Astra lanes**, ARTL and ARTS, running in parallel: separate pick
   pages, no shared files.
3. **MAP waits for T2.** It needs the larger bounds and the water query.
4. **Freshwater:** the swamp pools and the freshwater plants stay in the land
   part (land plan §8). The lake and river **mobs** belong to MOBS (sea plan
   §4).
5. **All towns' graveyards** switch to the new gravestone blocks.
   - `wp13/dressing.lua` draws them all (the grave at `:708`, `M.graveyard`).
   - Its callers: Stillgrave, Nhal Veyr (three district files), Kezamba,
     Highcourt and Gor Drazhak.
6. **Plant drops:** decorative plants drop nothing, like today's hanging moss
   and `bone_pile`. That covers flowers, ferns, lianas, lichen, alpine and
   beach plants, and the withered bush. Driftwood drops wood or sticks.
   Blocks drop default blocks (L7).
7. **The migration step:** none needed beyond the map reset. No item is
   removed (`bone_pile` keeps its name, L9), so no inventory migration. D
   declares the reset in the upgrade declaration, as in 0.47.0.

## 4. Interfaces

1. **Default drops everywhere** (L7, §5a.1). Every decorative block of LK and
   WRECK drops an ordinary block (cobblestone, stone, wood…). The wreck planks
   drop ordinary wood. Plants follow §3.6.
2. **ARTL's prop format.** Before ARTL starts on props, VIEW fixes a small
   format and adds it as a section to the existing
   `tools/r51_land/README.md`: one PNG set plus a node-box list per prop, in
   Luanti's `fixed` box notation (sixteenths). LK later turns it into nodes.
   VIEW stays in `tools/r47_sw`, extended, with its art in `tools/r51_land`.
3. **The swamp moss node across lanes.**
   - LG defines it and adds it to the non-mapgen host lists:
     - `grug_gathering/catalog.lua:46, 59, 184`;
     - `grug_materials/registry.lua:122`;
     - the swamp mobs `bog_ooze.lua:95`, `bog_fowl.lua:99`, `crocodile.lua:130`;
     - `spawn_regions.lua`.
   - T4 swaps the mapgen places (§2 T4).
   - MOBS edits the same mob files and rebases after LG.
4. **Plant regrowth** (L18). LP registers every new land plant with the
   vegetation authority (`wp40/vegetation_density.lua`) and the renewal
   (`grug_farming/renewal.lua`). T3 does the same for seagrass and kelp
   (§8.1); coral does not regrow. The hanging plants (L18's last clause): LG says
   how hanging moss comes back, LP how lianas do.
5. **Protected water** (S8). WRECK's wrecks lie in it (no one digs them for
   wood). Driftwood on the beach (LP) lies on alterable shore.
6. **Shared files.** Whichever lane merges second rebases; each lane appends
   rows in its own block.
   - `r7_r6_manifest.lua`: T4 swaps hosts and surfaces; LP, LK and WRECK add
     decoration rows.
   - `r6_content.lua`: T4 changes the surface selector and swamp host tables;
     LP and LK add host tables.
   - `r7_content.lua`, the closed node roster (`ACCEPTED_R6_ROWS` with its
     count check, plus the P9G and settlement digests). Every lane that adds
     a natural node adds it there: T3, LG, LP, LK and WRECK. Round 47's lane
     SW did the same.
   - `world_content_catalog.lua`: T3 (reef, seagrass) and T4 (swamp moss).
   - `vegetation_density.lua` and `renewal.lua`: LP, and T3 for seagrass and
     kelp.
7. **Pins and digests.** T1 and T2 move the generator's pins (template, hash
   and cache digests). Every later mapgen lane rebases and renews its own
   pins, as in Round 47.

## 5. Rules

- **Clients and budgets:**
  - stock clients only; plain Lua 5.1; the web build is a target;
  - numbers are comparisons, never targets, and rough targets (S5's belt
    width, densities) stay rough;
  - mapgen time before and after for TERRAIN, LP, LK and WRECK, reported;
  - a lane that gets noticeably slower or more complex reports to the
    coordinator, who asks the user.
- **Release mode:** 0.51.0 is a map reset, with no compatibility code for the
  old map. Character state that new code reads must work without a step, or
  the lane records what a kept world would need.
- **World-aligned tiles** (L6): Luanti supports them on solid nodes and node
  boxes only, not on plantlike nodes. The scale must divide 16; 2 does
  (`reference_projects/luanti/doc/lua_api.md`, tile definition). LG checks
  the look in the engine once.
- **Art** (ARTL, ARTS): own work, CC0, generator committed, no Lua, nothing
  under `mods/`, no fixtures, no references to existing games.
- **Sounds:** none new without the user's pick on a listening page; water
  mobs stay silent until then (sea plan §4).
- **Look and feel:** browser concepts and pick pages first, then Luanti. The
  first version follows gut feeling, and the user proposes the fixes.
- **Terrain guard:** settlements and POIs are never damaged. The kit and the
  wrecks stay clear of settlements, roads and POIs.
- **Reviews:**
  - every lane and every fix delta that changes game logic gets an
    independent review;
  - text, colour and display deltas the coordinator checks itself;
  - theoretical concerns become backlog notes.
- **Mapgen test runs:** a few engine runs of at most ~5 min while
  developing; a closing run of ~15 min over a chosen region; never the full
  world.

## 6. Verification

Per lane, the gates of the [round workflow](../process/round-workflow.md#3-gates).

- **Fixtures (every launch prompt):** "Fixtures: run only your own fixture
  plus the fixtures that actually test the behaviour you change (not every
  fixture that loads a changed file); the full run once before your report;
  name what you ran and why." Art, design and viewer lanes run none.
- **Seed fleet** (round workflow §3):
  - `quick` before merging each TERRAIN step, LK (new placement) and WRECK;
  - none for LP's plain decoration rows;
  - `full` once at the round end on main.
- **Names:**
  - `tools/r38_names/check_rules.py --shipped`;
  - `tools/r38_names/guarantee.py --check`;
  - `tools/r38_b1/gen_names.py --check`.
- **Lane tests named by the partial plans:**
  - MOBS: amphibian navigation, whether frogs and otters chase cleanly
    through water onto the shore (sea plan §6.1);
  - WRECK: its first in-game test is a mast on a test wreck (§5a);
  - LG: the 2 × 2 look in the engine once (§5).

**GUI checklist** (desktop and web, a new world):
- **Map:**
  - depth colours: coast light, belt and bays middle, open sea dark;
  - the larger map;
  - both qualities.
- **Sea:**
  - no open-sea specks at bay rims;
  - organic channels a boat passes;
  - coral, kelp and seagrass;
  - from 24 nodes off the coast no building, no mining, no Claim Stone,
    while the shore stays alterable.
- **Water mobs:**
  - shore mobs follow ashore;
  - a swimmer resets when its target leaves the water;
  - Bay Shark L30 in a bay middle;
  - Kraken and Abyssal Shark only in the open sea;
  - fish loot.
- **Wrecks:** two or three on the belt, a mast above the water where the
  depth allows.
- **Land:**
  - each zone's picked changes on two seeds;
  - the 2 × 2 grounds without a visible grid;
  - hanging moss and lianas continuous, and the end moves up when the lowest
    piece is dug;
  - papyrus on the ground at the water;
  - every decorative block drops a default block, and decorative plants drop
    nothing;
  - bones rare;
  - the towns' graveyards built from the new blocks.
- **Regrowth:** a picked plant comes back near a player.

## 7. Orchestration notes

**Start state:**
1. main after this plan's commit, together with both partial plans.
2. The coordinator merges branch `r51-swart` (the texture lab and Astra's
   swamp grounds; tools only) into main before VIEW starts.

**Before every lane start:**
- the lane-start checklist (`grudgelands-orchestration/LANE-START-CHECKLIST.md`);
- the fixture sentence in every Opus launch prompt;
- Astra briefs say "no fixtures";
- at most 8 Lua processes through the shared queue;
- engine runs only through `tools/luanti_headless.sh` with `LC_ALL=C`;
- never the user's Luanti folder;
- orchestration folder `grudgelands-orchestration/r51/`.

**File ownership** (the briefs list exact files; shared files in §4.6):

| Lane | Files |
|---|---|
| TERRAIN | T1: the bound places in §2; T2: `source/simple_map.lua`, `simple_map.lua`, `terrain_field.lua`, `height.lua`, `world_protection.lua`; T3: `world_content.lua`, `world_content_catalog.lua`, the seagrass node; T4: the swamp moss places in §2, surface rows and the surface selector |
| VIEW | `tools/r47_sw`, and a section in `tools/r51_land/README.md` |
| ARTL, ARTS | `tools/r51_land/…`, `tools/r51_sea/…` (art only) |
| NAMES | a preview page and its data under `tools/` |
| WRECK | wreck nodes, schematics, wreck rows, its preview page |
| LG | `grug_nodes` ground and clay-band nodes and textures, `default:sand`'s texture if picked, `grug_trees` hanging moss, the swamp moss node and its non-mapgen host lists (§4.3) |
| LP | new plant nodes, decoration rows and host tables, `vegetation_density.lua`, `renewal.lua` registration, the papyrus row |
| LK | prop nodes, kit schematics and rows; the skeleton set with every `bone_pile` use: `wp13/decor_kit.lua:55`, `wp13/palette.lua:524`, `stillgrave.lua:698`, `vegetation_density.lua:115` and the decoration rows; `wp13/dressing.lua`'s graves and graveyard |
| MOBS | `grug_mobs` (new mobs, `aggro.lua`, `spawn_regions.lua`), `data/zones/*.spawns.json`, `subtypes.json`, `names.json`, drops |
| MAP | `grug_map/atlas.lua`, `grug_map/base.lua` (water colours, qualities) |

**Merge order:**
- T1 first; every mapgen lane rebases on it.
- T2 before MAP, before MOBS's spawn step and before WRECK's placement.
- ARTS's seagrass pick before T3.
- LG before T4, before LP, and before MOBS's host-list edits (or MOBS
  rebases).
- T3, T4, LP, LK and WRECK touch shared files (§4.6); the second to merge
  rebases.
- D last.

**The user's touchpoints:**
- the land viewer (picks per zone, cairn form, sand texture);
- ARTL and ARTS pick pages;
- the names page;
- the wreck page;
- the round's GUI test.

After merges: `tools/sync_to_luanti.sh`.

## 8. Questions settled (the user, 2026-10-19)

1. **Regrowth under water:** seagrass and kelp regrow like the land plants;
   coral patches stay as generated.
2. **Copper-green ore stains:** left out and not designed (L19).
3. **Routing:** as in the last rounds. Claude coordinates, Opus implements
   and reviews, Astra makes art only.

## Completion (2026-10-19)

Every planned lane is merged on main; this lane D (this section and the
status owners) follows on main `08163c89` (MOBS M2, merged last). **0.51.0
is a map reset, no migration step:** world generation changed (the world
bounds, the sea's shape, the seabed, the land surfaces, the kit, the
plants and the wrecks); no item is removed and no character state is read
differently. `map_reset_pass` stays 0.50.0, so a host's map reset packs
the claims' containers first. **Push:** not pushed; origin/main stays at
`fae056c5` (0.50.2) until the user's word.

No lane reported a disagreement between this plan and a partial plan.

### Lanes

Main's first-parent merges from `6c1b6139` (the three plans), in order.
Every code lane and every fix delta with game logic was reviewed
independently by Opus; art, design and page lanes were checked by the
coordinator and picked by the user.

| Lane | Merge (lane tip) | What | Review |
|---|---|---|---|
| SWART | `6fdaa1c2` (`d864dda4`) | the texture lab and Astra's calm swamp grounds (tools only) | coordinator check; picked 2026-10-18 |
| ARTS | `101f2091` (`56a358cb`) | 11 CC0 textures: seagrass and the wreck set (tools only) | coordinator check; picked |
| ARTL | `7bb1db93`, `d6b73c6a`, `e48c1251` | passes 1–3: 12 grounds, 13 plants, 15 props in VIEW's prop format, then the sparse lichen, the mourner statue and the fallen/sunken gravestones (tools only) | coordinator check; picked |
| T1 | `fe540a38` (`50b7f738`) | the larger world: bounds ±4190 × ±3740 through one `world_bounds`, grids ±4288 × ±3840 (whole cells), no land moved | MERGE (a low: two land-only old-bound clamps, kept) |
| NAMES | `228f2b8f` (`42925314`) | water families, level ladders and names on a page (tools only) | coordinator check; accepted |
| VIEW | `1ecb14d4` (`da21e7ad`) | the land viewer `tools/r47_sw/land.html`, the prop format, one rework | coordinator check; picked |
| WRECK design | `03d6b0c7` (`82b4cb54`) | four shapes, the preview page, v2 after the user's look (tools only) | coordinator check; picked |
| LG | `f4b1322c` (`c925eec7`) | world-aligned 32 px grounds, calm sides, the swamp moss, four clay bands, the 32 px sand, the hanging-moss strand and end | MERGE |
| MOBS M1 | `cb93b631` (`dc53c69d`) | tortoise, frog, stingray, Bay and Abyssal Shark, goby; the swimmer reset; fish loot; quest-ready data | MERGE |
| T2 | `5c8ac48e` (`4b3b6926`) | bays without specks, the belt, organic channels, protected water ≥ 24, `water_query_at` | MERGE AFTER FIXES (Medium: the inland distance cost 85–251 µs; made opt-in; a text), delta MERGE |
| MAP | `89bc91e3` (`cc4d6a31`; `e3d9e16a`) | the sea by depth with a soft edge, the atlas ±4050 × ±3600, 1215 × 1080 / 3600 × 3200, the cache key | MERGE (two stale comments, fixed by the coordinator) |
| LK | `a2dccc54` (`931dc5bf`) | 19 prop nodes and cairn B, 21 kit structures through `kitgen:` rows, 22 kit rows, the skeleton set in place of one bone pile, every town's graves, driftwood | MERGE AFTER FIXES (two lows: sunken cells on a wet bed; two plain bone-pile sites), plus the cores stepping ±1; delta MERGE |
| LP | `1d28d889` (`ee38d738`) | 6 flowers, 2 alpine plants, 2 lichen carpets, jungle and withered bushes, lianas in the tree templates, the papyrus fix, marram, regrowth | MERGE |
| T4 | `d7cebe4f` (`10bf1272`) | the swamp moss in every swamp mapgen place, clay bands on steep badlands faces, ice and pebble patches | MERGE (a doc reword and a tool fix) |
| T3 | `c3ee3922` (`64e3698d`) | `wp40/seabed.lua`: coral, kelp and three seagrass nodes; seagrass and kelp regrow in protected water | MERGE |
| WRECK build | `08df9bc9` (`60c3ecda`) | the wreck nodes and a successor pass in protected bay and belt water, at most 4 per zone | MERGE, a coordinator-ordered fix round (the cap), delta MERGE; after the main merge delta MERGE AFTER FIXES (a fixture check that could not fail), fixed |
| MOBS M2 | `08163c89` (`4859bfbe`) | water spawns by band, the shark and goby rows, 392 water kinds in the 38 recipes, 1,214 names | MERGE (lows: the water ABM cost, the tortoise's shores), a fix round (Abyssal rate), checked by the coordinator |
| D | this section | CHANGELOG, version, upgrade declaration, status owners, BACKLOG, tools index, the partial plans' status lines | — |

Main has 213 portable fixtures (8 new: `r51_terrain`, `r51_lg`, `r51_lk`,
`r51_lp`, `r51_t4`, `r51_map`, `r51_mobs`, `r51_wreck`); `mods/` +6,892
−606 lines in 118 text files, 14 new Lua files, 154 new textures and 5
models.

### Decisions during the round

The user's decisions of 2026-10-19, one line each (the coordinator log is
outside the repository):

1. **Grounds** very good, as picked in the texture lab and viewer.
2. **Lichen reworked:** it looked odd and far too frequent; v2 is sparse
   patches on gravel and stone only, with ARTL's pass-3 texture.
3. **Undead reworked:** more variety (mourner statue, fallen and sunken
   gravestones, ruin arch, column and corner, crypt, gravewood log and
   stump, grave mound, graveyards varied per seed).
4. **Wreck v2:** the mast was clearly too long and the hulls too blocky;
   v2 has four shapes, a broken mast 6 long and "a mast near the surface".
5. **Names accepted**, with the NAMES lane's five recommendations: the
   Abyssal Shark L70, the frog biting with its walk frames, the Salt Reef
   Lurker kept, the tortoise at lakes through T2's query, no frogs in the
   L1–2 home belts.
6. **The picks** ("Das passt jetzt alles"): every viewer v2 item at its
   guide density, both cairns, the 32 px sand as a retexture of
   `default:sand`, all three seagrass variants.
7. **Mud specks kept** on the wet-mud top (LG's close shot).
8. **The goby stays a critter** (0 XP, fish loot, never a kill target);
   ruling 14's "critter fish included" applies to the loot.

The coordinator decided, one line each:

- **T1:** both grids grow as planned (land differs by at most 8.5e-14
  nodes, no integer change) instead of a coast-grid-only growth.
- **T4 as its own lane,** in parallel to T2's fix round; T3 stayed with
  the TERRAIN lane.
- **Driftwood moved from LP to LK** (LK owns the prop nodes).
- **T2:** the water-plant regrowth exception in T3; channels keep no PvP
  rule; the inland distance capped at 16 and, after the review, opt-in;
  "Deep water – protected" for protected non-open-sea water.
- **Drops by VIEW's proposal:** clay bands give mesa clay, swamp moss mud,
  bone pieces nothing.
- **LK:** town bone counts kept for the GUI test; crypt and grave mound
  cores step ±1 (fix round); driftwood 1/360 of beach columns; the crypt
  stays rare (1/5) for the look of its lintel.
- **LP:** bushes do not regrow; ferns and marram drop nothing everywhere;
  papyrus in the warm zones, marram on every sand shore but the swamp;
  lianas on town trees too.
- **WRECK:** a successor pass instead of decoration rows (no template
  bound raised); a cap of 4 wrecks per zone (lowest hash wins); wrecks
  round the dragon islands kept.
- **MOBS:** M1's sizes kept; the Kraken keeps no reach veto; the Abyssal
  Shark at a tenth of the Kraken's rate (ruling 13, "as rares"); water
  kinds in every belt of a zone with that water.
- **MAP:** the middle step shades deeper toward 32; bay shores get the
  coast line.
- **T3:** the old-bound clamps in `r6_content.lua` stay (land only).
- **T4:** bands from a drop of 2 (the viewer's code); pebbles on every dry
  coast sand; review finding 1 reworded instead of a code change.
- **The merge order** for the shared roster and rows: LK → LP → T4 → T3 →
  WRECK → MOBS M2, each merging main and renewing its pins.

### Deviations from the plan

- **T1:** the grids grow to ±4288 × ±3840, not ±4258 × ±3824 (the smallest
  whole-cell growth); the drainage grid and the land-only `extent` kept.
- **T2:** the sea is protected through the `zones.lua` territory rule
  (`world_protection.lua` covers roads and settlement cores only); the
  belt uses the terrain field's chamfer coast distance (the zone field's
  is no distance at 250–350 nodes); "Stormkelp in protected water" was
  refuted (it grows on dry shore).
- **T3:** three seagrass nodes, not one (a rooted node has one special
  tile); the renewal needed its own seabed path; the coast and bay
  exclusions no longer keep the seabed bare.
- **T4:** nothing was needed for sand below water (64–83 % sand already);
  the clay bands were already in the spawn regions' ground (every
  badlands surface spawn row is retired at boot).
- **LG:** rooted beds honour world-aligned tiles (an engine fact the plan
  did not know); the swamp writer never placed hanging moss.
- **LP:** lianas come from the tree templates (a row cannot see leaves);
  renewal has no per-plant registry, plants come through the density
  authority; the swamp papyrus row is gone.
- **LK:** kit densities needed the denominator caps raised to 16,000;
  `default:cobble`, stonebrick, stone block, the silver sandstones and the
  junglewood fence count as natural to the writer; Dur Brannoc and
  Lethariel also have graves.
- **WRECK:** no roster rows (successor passes write their own nodes); its
  design question of the 16-node template bound fell away.
- **MOBS M2:** "tortoise on shores" reads as shallow water (the crab keeps
  the beach).
- **MAP:** the preview's build script was never committed; `layers.lua`'s
  hard-coded 1080 px now follows the normal quality.

### Numbers worth keeping

Comparisons on one machine, not targets; measured unless marked.

- **Bounds:** zones ±4190 × ±3740 (was ±3740 × ±3340), grids ±4288 ×
  ±3840, atlas ±4050 × ±3600. Preparation tiles 8,811 → 10,989 (all sea).
  Grid build 0.400 → 0.516 s CPU (+29 %, 26 % more cells); after T2 the
  field build 0.52–0.57 → 0.18–0.26 s (the coast grid built once); boot
  construction about 22.5 s before and after, heap 395 → 400 MiB.
- **Bays:** open-sea columns at the rims 389–1,154 per seed → 0 (four
  seeds); the seed fleet now fails a rim speck.
- **The belt:** the open sea begins at a coast distance of p5 262, median
  306–311, p75 331–334. Median depth by distance:

  | Distance | 25 | 100 | 150 | 200 | 250 | 300 | 350 | 400 |
  |---|---|---|---|---|---|---|---|---|
  | Depth | 3 | 8 | 11 | 13 | 16 | 18 | 22 | 30–32 |

  55–57 % of the belt's seabed lies ≤ 12 deep. The wreck band (protected
  seabed 8–14 deep) lies about 90–220 off the coast, 3.9–4.1 km² per world
  in 26–28 zones.
- **Channels:** 24+ off the coast 97 % is 9–11 deep; boat paths at 48+
  off the coast at least 10 deep (T1: 9).
- **The water query** (µs per column, warm): lake 0.32 (20.6 with the
  inland distance), river 0.71 (6.4), belt 0.69, open sea 0.13.
- **Seabed shares** of columns 2–20 deep (coral / kelp / seagrass): shelf
  2.9–3.0 / 2.1–2.7 / 12.6–13.6 %, belt beyond 0.6–0.8 / 2.5–2.9 /
  8.9–9.5 %, bays 0.7–1.4 / 3.1–4.3 / 11.4–17.3 %, channels 1.5–1.7 /
  2.1–2.8 / 11.5–13.4 %, open sea 0. Kelp deeper than 12 (dark by day):
  41–57 % of the belt's kelp, 20–81 % of the bays'.
- **Wrecks per world:** 54 (seed 12345) and 57 (seed 42) in 21–22 zones,
  1–4 per zone (65 and 69 before the cap); mostly 7–11 deep; hull 292,
  bow 140, stern 200 and debris 69 nodes.
- **Spawns per band** (production seed, 100 s by day, 7 stand-in
  players): lake 5, river 6, sea_shallows 14, sea_deep 38; Bay Shark 4 of
  27 attempts, Abyssal Shark 1 of 3, Kraken 5 of 31; the merged water ABM
  1.8 → 3.1 callbacks per second, 20 → 62 µs of Lua per second over 7
  areas. The stingray reset 0.3–0.4 s after the player stepped ashore.
- **Mapgen cost per lane** (before → after): T1 ring chunks 122 → 207 ms
  (now as ordinary deep sea); T2 within noise (land 759 → 755 ms, bay
  226 → 197); T3 +4 % CPU (626 → 649 ms over its chunk set); T4 within
  ±20 % noise; LP +6 % (4.66 → 4.95 s over 18 chunks); LK within noise per
  biome; WRECK at most +0.014 s per wreck chunk plus one whole-world layout
  of 0.47–0.65 s per Lua state.
- **Map render** (production seed): normal 1080 × 960 12.0 s → 1215 × 1080
  14.0 s (per pixel 11.6 → 10.7 µs); high 60.3 → 67.4 s; engine boots 12.5
  s (normal) and 66.3 s (high).
- **The node roster:** 122 → 128 (LG) → 156 (LK) → 173 (LP) → 174 (T4's
  ice); the P9G plant list 36 → 39 (T3's seagrass).
- **Land counts:** hanging moss over 64 swamp seeds 826 runs, 834 strand
  nodes; seed 12345 W1 131 liana runs, W4 233 papyrus and 107 marram; ice
  0.088 of snowblock tops, gravel 0.098 of dry sand; 6.2 % of badlands
  columns stand ≥ 2 above a neighbour; Stillgrave 545 kit nodes (162
  steles, 54 crosses, 208 bone piles, 76 skulls, ribcages and spines).
  Kit structures placed / tried (6 chunks per biome): boulder 119/178,
  cairn A 27/29, cairn B 31/32, dead pine 57/75, graveyard 5/5, crypt
  1/5, grave mound 4/5, arch 2/3, driftwood 14/32.
- **Names:** 20 new names (17 per tier, 3 world names), 291 zone slots
  after the two frog L1–2 slots left; `names.json` 1,214 names.
- **Seed fleets:** `quick` 100/100 before every TERRAIN step, LK, LP and
  WRECK merge (6 min 39 s – 9 min 22 s).

### Classification

- **Map reset:** T1 (the ring generates sea floor, caches rebuild), T2
  (the sea's shape and protection), T3 (seabed content, roster), T4
  (surfaces, roster), LG (six new natural nodes, strand writes), LP and LK
  (rows, templates, roster, pins), WRECK (world generation).
- **Compatible:** MOBS M1 and M2 (entities, data, spawning, names), MAP
  (caches rebuild through the key); the art, design and page lanes tools
  only. Saved state read differently: none. `bone_pile` keeps its name;
  ferns and marram already held stay valid items; old single-node hanging
  moss would still dig on a kept world.
- **The declaration:**
  `{"schema": 3, "version": "0.51.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0"], "map_reset_pass": "0.50.0"}`.

### Open notes

The reviews' and reports' backlog notes are in the
[BACKLOG](../../BACKLOG.md#round-51-carry-overs). MOBS M2's final smoke
boot logged two warnings specific to that random seed from the land part
(a kind fallback in Frostbarrow; Mournfen's bandit camp belt more than one
belt from the land beside its POI); the round-end gates look at them.

### GUI checklist (Round 51)

Desktop and the web build, on a new world after the map reset (seeds 12345
and 42 have the measured wreck counts); an existing 0.50 character for the
update items. Built from §6 with every lane's and review's GUI items.
Points marked **(decide)** are for the user's judgement.

**Check first:**

1. **The sea:** bay rims without specks of open sea and a natural mouth;
   the wide belt, then the darker open sea; both dragon channels by boat,
   9–11 deep, the boat passing everywhere.
2. **Protected water** from 24 nodes off the coast: no building, digging
   (the seabed too) or Claim Stone, the hint "Deep water – protected"; the
   shore nearer than 24 stays editable. Regrowth is tested inside that
   shore band: dig seagrass and kelp there and wait near them (protected
   water cannot be dug).
3. **The wrecks:** seed 12345 at about (1894, −8, −3102) a hull with its
   mast just above the water; two or three wrecks along a coast; no water
   walls or air pockets round them.
4. **The map at both qualities:** at 1x light coast, middle belt and bays,
   dark open sea, a soft edge; at 4x a bay, a channel and the belt's edge.
5. **The land zones on two seeds:** each zone's picked changes (the land
   points below).
6. **The town bones:** Stillgrave and Nhal Veyr show skulls, ribcages and
   spines among the bones: too busy? **(decide)**
7. **Kelp brightness:** kelp deeper than 12 nodes is nearly dark by day
   (about half the belt's kelp) **(decide)**.

**The update:**

8. A 0.50 world taken to 0.51.0 with the map reset starts; Help → About
   shows 0.51.0; characters keep level, gear, bags, money and quests; a
   claim's containers wait in the new stone's Belongings tab.
9. The first start renders the larger map (normal about 14 s, high about
   a minute); a full preparation covers about a quarter more tiles (sea).

**The world's edge:**

10. Past the old edge (x beyond ±3740 or z beyond ±3340): open sea, the
    location reads ocean, no level; digging and placing are refused. At
    ±4190 / ±3740 the seabed steps up (an old effect, backlog).
11. The land is the same as before on the same seed.

**The sea in detail:**

12. Seagrass meadows (three kinds) in shallow belt, bay and channel water;
    kelp to about 20 deep, never reaching the surface; coral to about 10;
    the open sea bare. Dug seagrass and kelp leave sand and come back near
    you; coral does not.
13. A Claim Stone reaching bay water more than 24 off the coast is refused
    with its deep-water message.
14. Sand under water shows the 32 px sand; kelp beds too.
15. Plants under the island-landing piers (a few columns, accepted).
16. Wreck blocks give ordinary wood or a log (only where an admin can dig
    them; protected otherwise); a wreck's mast has no collision for boats.
17. Wrecks also lie in the belt round the dragon islands **(decide)**.

**Water creatures:**

18. Frogs at lakes and rivers, tortoises in the coastal shallows and at
    lakes; no frog or stingray in a level 1–2 home belt.
19. A frog and a struck tortoise follow you through the water, ashore and
    back; the tortoise can be outwalked.
20. Stingrays at least 16 off the coast; they fight in the water and at a
    boat, reset when you step ashore and ignore you on the bank.
21. The Bay Shark (L30) in a bay's deep middle; the Kraken and the elite
    Abyssal Shark (L70, about 2.5 × size) only in the open sea; the
    Abyssal Shark rare **(decide** its rate, a tenth of the Kraken's**)**.
22. The Tide Goby under the sea's surface; L60 Wyrmwake Rays in the dragon
    channels.
23. Kills drop the band's fish (the Abyssal Shark Storm Tuna); no new
    sounds.

**The map:**

24. The minimap at a coast; its sea disc beyond the edge is dark.
25. Markers, waypoints and the claim mode line up at the new edges.
26. At 1x the zone names and icons draw about 11 % smaller; labels may
    overlap on small windows **(decide)**.

**The land:**

27. **Grounds:** swamp, elf forest, undead, jungle, badlands and beach
    grounds read as 2 × 2 with no node grid; inventory cubes of the 32 px
    grounds show the whole texture; the web build the same.
28. **Swamp:** muted swamp-moss patches with ferns on them, no neon moss;
    the elf forest keeps its moss soil; no papyrus pedestals; hanging moss
    continuous: digging the lowest piece leaves a tapered end one higher,
    digging a middle piece drops the pieces below.
29. **Jungle:** lianas hang from leaves (Kezamba's trees too); digging the
    end moves it up, chopping the tree decays them; flowers, ferns, bushes,
    kapok logs.
30. **Undead:** graveyards (steles, crosses, fallen and sunken stones,
    fences), ruins, the mourner, obelisks, logs and stumps, grave mounds,
    the rare crypt; bones rare and varied.
31. **Dwarves:** boulders, both cairns, dead pines on snow, sparse lichen
    patches on gravel and stone, alpine plants; small ice patches without
    snow in the snowy crags.
32. **Orcs:** steep slopes and mountains striped ochre, sienna, chalk and
    umber by height, flat ground mesa clay, thin 2–3-node stripes elsewhere
    **(decide** the threshold**)**; bones, withered bushes.
33. **Elves:** ruins, statues, logs, pastel flowers.
34. **Beaches and shores:** gravel patches in dry sand, also on lake and
    river banks **(decide)**; papyrus 2–4 directly on sand at the water in
    the warm zones; marram away from the water; driftwood.
35. **Town graveyards** are built from the new gravestones in every town.
36. **Drops:** every decorative block drops a default block (a clay band
    mesa clay, the swamp moss mud); decorative plants (ferns and marram
    included) and bones drop nothing.
37. **Regrowth:** a picked flower near a player comes back after some
    minutes.

### Round-end gates

**Round-end gates** (coordinator): *to be recorded* — full fixtures, the
full seed fleet, `check_upgrade.py`, `check_fresh_server.py`, the data
checks and a smoke boot from an empty cache on main.
Lane D's own checks on its branch: `tools/r37_dc` and `check_upgrade.py`
(0.51.0 against origin/main `fae056c5`) PASS.
