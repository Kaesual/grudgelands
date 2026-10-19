# Round 51 — Land zones and the sea

Coordinator: Claude (Opus 5.5), drafted 2026-10-19 from two partial plans and
revised the same day after an independent read. Status: **ready**, the user's questions settled 2026-10-19;
it starts on the user's "go". No lane has started.

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
