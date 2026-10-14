# Round 47 — Trees, mining progression and crafting feedback

Coordinator: Claude (Opus 5.5), drafted 2026-10-13 from the user's decisions
of the same day. Status: **complete** (2026-10-14, version 0.47.0, **map
reset** plus the migration step 0.47.0; [completion](#completion-2026-10-14)).

The main focus is the **tree rework**: the concept approved in Round 46
([handoff](tree-rework-handoff.md)) is built into the game, and every world
gets its own trees from its seed. The other items answer the user's own
play and the players' feedback:

- **Mining progression:**
  - the next tier's ore lies only in the lower half of the band before;
  - Iron needs a Bronze pick;
  - **Anthracite** replaces Coal from T3 and makes Steel.
- **Furnaces:**
  - the Dual Furnace sounds like the furnace;
  - both furnaces are quieter and fall silent at once when dug;
  - alloys take as long as bars.
- **Crafting:**
  - finished items go into the inventory, and the output area is only an
    overflow;
  - Basic recipes unlock again when every ingredient has been held once.
- **Towns and zones:**
  - NPCs no longer face walls;
  - the zone banner stays 4 s;
  - entering a zone for the first time gives XP.
- **Swamp:** varied ground, pools, plants and swamp trees. It goes through a
  browser concept first.

Release **0.47.0** with a **map reset**. 0.46.0 is not deployed on its own
(the user, 2026-10-13). The production server goes from 0.45.1 to 0.47.0
in one step, with one map reset. Push only on the user's word.

Routing (the user, 2026-10-13):
- Claude coordinates.
- Opus implements and reviews.
- Astra makes art only, with no fixtures.

The hotbar rework (prepared, not scheduled) and the class rework
([continuation plan](class-redesign/continuation.md)) stay parked.

## 1. Lanes and waves

| Lane | What | Wave | Kind | Waits for |
|---|---|---|---|---|
| TA | Tree nodes: 28 shape nodes, mesh quarter, connects and overrides, drops, leaf decay, jungle bark M, the four engine checks | 1 | nodes + art wiring | — |
| TB | Lua port of `treegen.js` (1:1), JSON-equality fixture, Lua timing per tree | 1 | pure Lua | — |
| TC | Trees in the world: templates generated from the seed at load, roots pass, saplings, town trees, markers, pins, seed fleet | 2 | mapgen | TA, TB merged; OR, AN merged (shared pins) |
| TD | Forest render cost, desktop and web, today vs new | 3 | measurement | TC merged |
| OR | Lower-half rule for next-tier ores; Iron behind a Bronze pick (level scale shift, dig times kept) | 1 | data + mapgen pins | — |
| AN | Anthracite: ore, item, Steel, torch, fuel, claim stone, enchants, help; Coal ends at T3; alloy times | 1 | data + code + mapgen pins | merges after OR |
| FS | Furnace sound: own ambience class at 60 %, the Dual Furnace too, stop on dig | 1 | code | — |
| CR | Crafting: delivery into the inventory with overflow; Basic recipe unlock by touched ingredients | 1 | code + UI | — |
| NZ | NPC facing check and data fixes; zone banner 4 s; first-entry zone XP and sound | 1 | code + data | — |
| ART | Astra: swamp texture set first (for SW's concept), then the Anthracite set | 1 | art | — |
| SW | Swamp: a three.js concept (ground, pools, plants, swamp trees) for the user's pick, then the build | 1 (concept), 2 (build) | concept, then mapgen | build: the user's pick, TC merged |
| ML | Map window marker layers: one layer at a time, every marker named, party names, no icons baked into the world map ([work package](round47-map-layers.md), added 2026-10-13) | 2 | code + UI | — |
| D | Documentation, version 0.47.0, the upgrade declaration, gate list | 3 | docs | last merge |

The user's GUI test of 0.46.0 is still open. Its findings join this round
as a fix lane FX, sized when they arrive.

Estimates (unmeasured, for planning only), each lane plus its review:

| Lane | Hours |
|---|---|
| TA | 6–8 |
| TB | 5–7 |
| TC | 16–24 |
| TD | 3–4 |
| OR | 6–9 |
| AN | 10–14 |
| FS | 2–3 |
| CR | 12–16 |
| NZ | 6–8 |
| ART | 3–5 |
| SW | 4–6 concept + 10–14 build |
| ML | 8–12 |
| D | 3 |

TC is the largest and riskiest lane. AN touches the most files.

## 2. Rulings (the user, 2026-10-13)

**Trees** (on top of the handoff's binding decisions, §2 there):
1. **32 templates per species, 16 for kapok.**
2. **Generated from the world seed** at every server start, in both Lua
   environments. There is no file in the world folder, so every world has
   its own trees.
3. **Town trees** use the generator too (the handoff's recommendation,
   accepted with the user's "go").
4. **Leaf cost:** decided on TD's measured numbers, not before.
5. **Swamp trees**, alike in spirit to gravewood: their own species in the
   generator, built from gravewood's wood nodes.

**Ores and picks:**

6. **Lower-half rule:** an ore that belongs to the next tier lies only in
   the lower half of the band before it (table in §3). In T1 that means
   y −50 to −100.
7. **Iron needs a Bronze pick.** Wood and Stone picks no longer dig it.

**Anthracite:**

8. **New ore, Anthracite.** It starts in the lower half of T2 (mixed with
   Coal) and replaces Coal from T3 down. Below y −300 there is no Coal ore.
9. **Steel** = Iron Bar + Anthracite in the Dual Furnace, and only that.
   Anthracite is **not** in `group:coal`; it is named explicitly wherever
   it is accepted.
10. **Anthracite torch:** 10 from 1 Anthracite + 1 stick, light 14.
11. **Fuel:** Anthracite burns 120 s in the furnaces (Coal 80 s).
12. **Claim stone:** the fill cap is counted in time (99 lumps' worth,
    about 30 days), not in items. Anthracite counts 1.5 lumps. A piece goes
    in only if its whole time fits. The pick-up refund stays as today (the
    remaining time in Charcoal).
13. **Enchants:** the T2 Coal inputs become `group:coal` (Charcoal works).
    The T3 inputs become Anthracite.
    **Unchanged:** the Coal torch (any `group:coal`), black dye, the Coal
    block, the Coal quests (levels 3 and 12–15, where Coal still lies) and
    Coal and Charcoal as fuel.

**Furnaces:**

14. **The Dual Furnace** plays the furnace's sound.
15. **Both furnaces** play at 60 % of today's gain. Campfires keep theirs.
16. **The sound stops** when a furnace is dug.
17. **Alloys take as long as bars:** 10 s each.

**Crafting:**

18. **Delivery (option b):**
    - Finished items go into the player's inventory.
    - A craft starts only if the result fits once the ingredients are
      taken; otherwise "Not enough room in inventory".
    - If the inventory has filled up meanwhile, the rest goes to the output
      slots. They show only when they hold something, and they empty
      themselves into the inventory as soon as there is room.
    - A craft with a quantity above 1 delivers each item as it finishes,
      not all at the end.
19. **Basic recipe unlock:**
    - A Basic recipe is listed once the player has held every ingredient at
      least once. A group ingredient counts when any member was held.
    - Detection is the scan of all player lists, as in Round 37: on every
      inventory action plus a 10 s sweep.
    - "New recipe: X" tells the player when a recipe is unlocked.
    - Sticks and the wooden tools are known from the start.
    - Existing characters are scanned once at their first login after the
      update.
    - Professions keep the tier rule: each tier unlocks its whole catalog.

**Towns and zones:**

20. **NPC facing:** NPCs face away from walls, not into them.
21. **Zone banner:** shown for 4 s.
22. **First-entry XP:**
    - The first time a character enters a zone, it gets about a quarter of
      a quest reward at the zone's level.
    - The level-up sound plays with it, once even if the XP also levels the
      character up.
    - Only real zones count, not towns or the open sea.

**Swamp:**

23. **Concept first** in the browser, the build after the user's pick.
    **Picked (2026-10-13):** the concept page with lane ART's swamp
    textures as shown; swamp-tree leaves olive (a new leaves node, painted
    by ART); pools keep the default water.
    **Pools on slopes (the user):** a pool never makes flowing water. On
    gentle slopes the ground may be levelled slightly for a small pool; on
    steep slopes there are no pools, the ground mix, plants and trees are
    enough there. Levelling never touches towns, POIs or protected ground.
    The build's questions (the user): swamp trees stay at their row
    density; moss soil joins the swamp-only mob lists.

**Coordinator choices** (details the user did not rule on; a lane may
propose otherwise in its report):
- Zone XP uses `min(zone level_min, character level)`, so a low character
  gains no large bonus by walking into high zones.
- Existing characters get their current zone marked as visited, silently,
  at their first login after the update.
- Jungle bark M is wired through tile overrides with own texture names,
  not by patching the vendored texture.
- Saplings grow through the generator too (handoff §5).
- Anthracite needs an Iron pick (`level 2`), as its band does anyway.

## 3. The ore table (lanes OR and AN)

One host-rock ore per N nodes, by band (T1 y ≥ −100, T2 −101…−300, T3
−301…−500, T4 −501…−700, T5 −701…−1000, T6 below −1000). "½" means only the
lower half of that band, with the same denominator, so the band's total
halves.

| Ore | T1 | T2 | T3 | T4 | T5 | T6 | Change |
|---|---|---|---|---|---|---|---|
| Coal | 64 | 128 | – | – | – | – | none from T3 (was 96 / 128 …) |
| Anthracite | – | 256 ½ | 96 | 128 | 128 | 128 | new |
| Iron | 128 ½ | 96 | 128 | 384 | 384 | 384 | lower half of T1 |
| Silver | – | – | 256 ½ | 128 | 256 | 512 | lower half of T3 |
| Emberglass | – | – | – | 256 ½ | 128 | 256 | lower half of T4 |
| Abyssal Crystal | – | – | – | – | 512 ½ | 256 | lower half of T5 |

Copper, Tin, Quartz, Gold and the gems are unchanged.

**Why Anthracite is never short:**
- Every alloy bar from T3 to T6 holds exactly one Steel bar, so exactly one
  Anthracite, as it holds one Iron Bar.
- From T3 down, Anthracite is at least as common as Coal was and never
  rarer than Iron.
- Iron stays the bottleneck it already is. Proof: AN's per-band census.

**Picks after OR (the level scale shifts by one):**
- Wood and Stone picks: `maxlevel 0`.
- A metal pick of tier t: `maxlevel t` (Bronze 1, Iron 2, … Abyssal 6).
- A node that needs a tier-t metal pick: `level t`.
- Iron ore: `level 1` (Bronze).
- Coal, Copper, Tin, Quartz and Citrine stay at `level 0`.
- Rock of band T(n) needs the pick of its band, as today.
- Anthracite: `level 2` (Iron pick).
- Dig times per pick and node stay as they are today. The engine divides
  by the level difference, so the times tables compensate for the shift.

## 4. Lanes (goals; the briefs add file facts)

Every lane:
- classifies its change: compatible, map reset, or would need a step on a
  kept world;
- updates the design documents whose rules it changes.

### 4.1 TA — tree nodes
**Goal:** the shape set of the [handoff](tree-rework-handoff.md) §3:
- 7 wood types × 4 shapes = 28 nodes;
- the quarter as an octagon mesh;
- base, branch and twig as connected nodeboxes;
- bark grain by facedir.

What comes with it:
- the leaf `connect_sides = {"bottom"}` and ground `connect_sides =
  {"top"}` overrides, ground including swamp mud;
- every shape drops its trunk item;
- leaf decay keeps working with the new wood;
- placement refusal as the handoff says.

**Jungle bark M:** set through tile overrides of the jungle tree nodes from
a grug mod with its own texture names. There is no patch of the vendored
texture.

**Engine checks (handoff §4):**
- the bark grain on connected boxes;
- mesh lighting, seams and mirroring;
- template rotation of facedir.

**Proof:** the node fixture (drops, groups, connects, leaf decay,
placement), and engine captures of a test patch, desktop.

### 4.2 TB — Lua port
**Goal:** `treegen.js` ported 1:1 as pure Lua (no engine calls).
- **Equality:** the JSON node list for a few hundred seeds per species
  equals the JS output.
- **Timing:** the time per tree per species in Lua, reported as a
  comparison for TC.

The swamp species joins later through SW's build, which keeps both sides
equal.

### 4.3 TC — trees in the world
**Goal:** wild trees come from the generator.

**Templates:**
- The R6 template expander gets the full seed and generates N templates
  per species at load (32, kapok 16), in the main and the mapgen
  environment alike. No world-folder file.
- Every generated template passes the existing checks: bounds, vocabulary
  and decoration role. The settlement class is computed, not pinned per
  row.
- The frozen `decoded_templates` pin and the fixed template count become:
  - a fixture with fixed digests for a few sample seeds;
  - a count derived from the species table.
- The other pins that move are renewed.

**The rest of the world:**
- **Roots:** the R7 writer, as in handoff §5, with the ground test per
  cell.
- **Saplings:** grow through the generator with the position-hash seed,
  plus roots via `get_node`. Apples keep param2 0, so they regrow.
- **Town trees:** `wp13/dressing.lua` uses the generator.
- **Markers:** `vegetation_density.lua` follows the new templates.

**Proof:**
- the sample-seed fixture;
- the `quick` seed fleet, which now checks each seed's generated templates;
- the chunk-border losses, measured;
- the load time with and without the generator, reported;
- engine captures of a forest per species.

### 4.4 TD — forest render cost
Desktop and web client, a forest per species, today vs new: draw calls,
frame time, memory, reported as comparisons. The user decides on the leaf
counts from these numbers.

### 4.5 OR — lower-half rule and the Bronze gate
**Goal:**
- the lower-half field in the resource rows and the §3 rows for Iron,
  Silver, Emberglass and Abyssal Crystal;
- the level scale of §3 in `grug_materials`, its audit and the pick
  profiles, with dig times kept;
- Iron behind Bronze;
- every pin and check that encodes the old tables follows them;
- `items_crafting.md` ("Iron needs only a T1 pick") and `world_zones.md`
  §11 updated.

**Proof:**
- the per-band census (`tools/r46_or`) shows the halves;
- a dig-time table per pick and node, before and after;
- the mining fixtures (r24) follow the new gate.

### 4.6 AN — Anthracite
**Goal:** rulings 8–13 and 17.
- **Ore:** the item and its ore nodes, the §3 rows, and Coal out of
  T3–T6.
- **Steel:** the recipe and the startup audit of the alloy table; all
  alloys at 10 s, and the stale "3 s" comment fixed.
- **Torch:** the Anthracite torch as a floor, wall and ceiling node triple
  (light 14, `torch=1`, its own drops and flood handling) plus its Basic
  recipe row through the recipe generator.
- **Fuel and claim stone:** the furnace fuel row and the claim stone's
  time-based cap with per-item seconds.
- **The rest:** the enchant inputs, and the help texts (Coal depth, Steel,
  the Anthracite torch's wider safe radius).
- **Textures:** placeholders until ART delivers.

**Proof:**
- the per-band census: Anthracite is never rarer than Iron from T3 down;
- a fixture for the Steel recipe, the claim stone cap and refund, and the
  torch nodes;
- `income.py --check` if it reads fuel or torches.

### 4.7 FS — furnace sound
**Goal:** rulings 14–16.
- An own ambience class for both active furnace nodes at 60 % of today's
  fire gain. Campfires and other fire emitters are unchanged.
- Digging or destroying a furnace stops its loop for every listener at
  once, with a short fade.
- The station-sound fixture (r45_pt8), which asserts today's fire loop,
  follows.

**Proof:** the fixture, and a headless check that the handle stops on dig.

### 4.8 CR — crafting delivery and Basic unlock
**Delivery (ruling 18):**
- The start check simulates the inventory after the ingredients are taken.
- Delivery goes through `grug_inventory.give`.
- The overflow uses the existing output list. It is drawn only when
  non-empty and drained by a cheap poll for players who have overflow.
- The drop-at-feet fallback stays for the overflow's own overflow.
- Each item of a multi-item craft is delivered as it finishes.
- Offline completion delivers at join.

**Unlock (ruling 19):**
- A per-character seen set in player meta, under a new key.
- The scan as in Round 37 (`c232bdea`; the removed `discovery.lua` is in
  git at `1911670e^`).
- A starter set: sticks and every wooden tool.
- One "New recipe" line per scan, which names the count when several
  unlock at once.
- The first-login scan for existing characters.
- Search and "Craftable only" stay.
- The fixture that asserts "Basic shows every recipe" (r45_ui) is turned
  round.
- `professions.md` and the crafting plan's ruling 33 are updated.

**Proof:**
- fixtures for the start check, the overflow and its drain, the unlock
  with groups, the starter set and the first-login scan;
- the UI probe.

### 4.9 NZ — NPC facing and zones
**NPC facing (ruling 20):**
- A check over every blueprint with NPC sockets: start towns, capitals,
  and the Round 14 POI villages per race. It fails when a solid wall node
  lies within two nodes in front of an NPC and no work feature is there.
- The data is fixed where the check finds a wall. Known cases:
  - Silverleaf: the bowyer and the market stall;
  - the R14 villages: one socket set for every race's houses, so the
    sockets become per race.
- Sockets are not in the map digests.

**Zones (rulings 21–22):**
- The banner duration becomes 4 s.
- A per-character visited set in player meta. The start zone is marked
  silently at the first join, and for existing characters their current
  zone at their first login after the update.
- The XP is `quest_reward` at `min(zone level_min, character level)`,
  quarter weight, so walking into high zones is no XP farm.
- The level-up sound plays once.

**Proof:** the facing check in the fixture set, and a fixture for the
visited set, the XP and the single sound.

### 4.10 ART — Astra textures
16 × 16, CC0, a generator committed, no fixtures (no Lua and nothing under
`mods/` changes). Each set ships with a preview page.

1. **Swamp set, first, for SW's concept:**
   - two mud variants (lighter, mottled);
   - wet grass;
   - a moss carpet;
   - reeds;
   - cattails;
   - hanging moss.
2. **Anthracite set:** ore overlay, lump and torch.

### 4.11 SW — swamp
**Concept** (a three.js page in the style of the tree viewer, using ART's
textures as they arrive):
- a swamp patch with shallow pools (1–2 deep, waterlilies);
- mixed ground: mud, its variants, mossy dirt and wet grass;
- reeds, cattails, ferns, tall grass and moss carpets;
- swamp trees as a new species in `treegen.js`: gravewood wood, low,
  crooked, wide, sparse leaves, short stilt roots into the mud, hanging
  moss.

The user's iteration style applies: a first version by gut feeling, then
the user's fixes.

**Build** (after the pick; the trees after TC):
- the biome's ground mix and pools in the WP40 pipeline;
- the decoration rows;
- the new nodes;
- the swamp species in both generators with the equality fixture;
- its templates through TC's mechanism.

**Proof:** engine captures of a swamp on two seeds, and the `quick` seed
fleet.

### 4.12 D — documentation
- Version 0.47.0.
- The upgrade declaration (`tools/web_data/upgrade.json`) with the
  0.47.0 map reset; the deploy goes from 0.45.1.
- CHANGELOG, STATUS, README's current state, BACKLOG carry-overs.
- The plan's completion with the GUI checklist.
- The handoff marked done.

## 5. Rules

- **Clients and budgets:**
  - stock clients only; plain Lua 5.1; the web build is a target;
  - particle totals stay in the hundreds;
  - numbers are comparisons, never targets;
  - a lane that gets noticeably slower or more complex reports to the
    coordinator, who asks the user.
- **Release mode:** 0.47.0 is a map reset.
  - Character-state changes (seen recipes, visited zones, claim fuel)
    must be readable by the new code without a step, or the lane records
    what a kept world would need.
  - No compatibility code for the old map.
- **Sounds:** only the existing furnace and level-up sounds, by the user's
  rulings. Nothing new without a pick on a listening page.
- **Look and feel:** concepts in the browser first (three.js), then in
  Luanti.
- **Reviews:**
  - review scope with judgment: theoretical concerns become backlog notes;
  - every fix delta that changes game logic gets an independent review;
  - text, colour and display deltas the coordinator checks itself.
- **Mapgen test runs:** small during development, full runs only at the
  end.

## 6. Verification

Per lane the gates of the [round workflow](../process/round-workflow.md#3-gates).

- **Fixtures (every brief):** own fixture plus the fixtures that test the
  changed behaviour during development; the full run once before the
  report.
- **Seed fleet:** `quick` before merging OR, AN, TC and SW; `full` once at
  the round end on main.
- **The per-band census** after OR and after AN.
- **Economy:** `income.py --check` after AN.

**GUI checklist** (desktop and web, a new world):
- **Trees:**
  - each species in the wild on two seeds, and the trees differ between
    them;
  - octagon trunks, limb joins, twigs into leaves, roots only on ground;
  - jungle bark M;
  - a sapling grows a generated tree with apples that regrow;
  - town trees match;
  - frame rate in a dense forest, desktop and web.
- **Mining:**
  - no Iron above y −50;
  - a Stone pick fails on Iron and a Bronze pick digs it;
  - Anthracite from y −200 down, no Coal below −300;
  - Steel only from Anthracite;
  - an Anthracite torch lights wider and keeps spawns further away.
- **Claim stone:**
  - Anthracite counts 1.5;
  - a full stone refuses a piece that does not fit;
  - pick-up refunds Charcoal.
- **Furnaces:**
  - the Dual Furnace sounds;
  - both are quieter;
  - silence at once on dig;
  - a Bronze bar in 10 s.
- **Crafting:**
  - a craft lands in the inventory;
  - a full inventory refuses the start;
  - filling up mid-craft puts the rest in the overflow, which empties
    when a slot frees;
  - a fresh character sees only sticks, wooden tools and what it has held;
  - "New recipe" appears on pick-up.
- **Towns and zones:**
  - Silverleaf's NPCs and a village of each race face away from walls;
  - the zone banner stays 4 s;
  - XP and the level-up sound on a first entry, not on the second.
- **Swamp:** pools, mixed ground, plants and swamp trees on two seeds.

## 7. Orchestration notes

**Start state:** main after this plan's commit (on top of `18befb9b`).

**Before every lane start:**
- the lane-start checklist (`grudgelands-orchestration/LANE-START-CHECKLIST.md`);
- the fixture sentence in every Opus launch prompt;
- Astra briefs say "no fixtures";
- at most 8 Lua processes through the shared queue;
- engine runs only through `tools/luanti_headless.sh` with `LC_ALL=C`;
- never the user's Luanti folder.

**File ownership (the briefs list exact files):**

| Lane | Files |
|---|---|
| TA | a tree-shape mod under `mods/ITEMS`, leaf and ground overrides, the bark texture, `grug_trees` drops and leaf decay |
| TB | the Lua generator module, its fixture, the JS reference JSON |
| TC | `wp40` template source and expander, `r7_manifest.lua` template pins, the R7 writer's roots pass, `grug_trees` saplings, `wp13/dressing.lua`, `vegetation_density.lua` |
| OR | `wp40` resource rows and their checks, `grug_materials` registry, mining and audit, pick profiles, `tools/r24_mining`, `items_crafting.md`, `world_zones.md` §11 |
| AN | `grug_materials` Anthracite rows, `grug_smelting/recipes.lua`, `grug_jobs/automatic.lua` fuels, the torch nodes, `tools/r45_rg/edits.lua` and `basic_recipes.lua`, `grug_housing` fuel, `enchants.json`, help texts |
| FS | `grug_ambience` data, furnace dig and destruct hooks, `tools/r45_pt8` |
| CR | `grug_jobs` jobs, ui and state, a discovery module, `tools/r45_ui`, `tools/r45_jb` |
| NZ | blueprint sockets (`wp13`, `r14_poi_blueprint.lua`), `grug_map/location*`, a zone-discovery module, `grug_xp` calls |
| SW | the concept under `tools/`; the build: `wp40` swamp rows, new swamp nodes, the swamp species in both generators |
| ML | `grug_map` window, providers, bake/base (world map variants only), settlement icons, quest box, textures, a zone-placement module, `tools/r44_mq`, `docs/design/world_map.md` |

**Merge order:**
- OR before AN: both edit resource rows and `grug_materials`.
- TA and TB before TC.
- TC after OR and AN: the pins move in all three, and the later lane
  rebases and renews them.
- SW's build after TC.
- TD after TC.
- D last.
- **Shared files:**
  - Help texts: AN owns the mining lines, CR the crafting lines.
  - `basic_recipes.lua`: AN adds the torch row through the generator; CR
    changes visibility only. The second to merge rebases.

**The user's touchpoints:**
- the swamp concept (a page);
- the map layers' screenshots (icon size, zone labels, the §8 defaults of the work package);
- ART's texture picks;
- TD's numbers (the leaf decision);
- the GUI test of 0.46.0, if not done before;
- the round's GUI test.

After merges: `tools/sync_to_luanti.sh`.

## 8. Open questions for the user

1. ~~Leaf counts and forest density~~ — **settled (the user,
   2026-10-14):** no web client measurement; TD's desktop numbers are
   accepted as they come out, the game keeps full leaves and today's
   density (`TREE_SPACING = 4`); a marked regression is flagged for the
   user's GUI test, not changed in this round. After TD the coordinator
   runs lane D and the full seed fleet and closes the round without
   another check-in; push only on the user's word.

Settled: lane ART's Anthracite set (lump, ore, torch) as painted (the
user, 2026-10-13); town trees use the generator (ruling 3); the swamp concept and
its textures (ruling 23); the furnace-sound questions (camp fires keep
fading on the next pass; the furnace kind keeps its own loop limit);
the lanes' questions as recommended (AN: claim activation stays Coal or
Charcoal, the Steel quest texts name Anthracite; CR: silent first scan,
only Basic ingredient tokens stored, no "Take all", orders capped by room,
enchant and upgrade results into the inventory; NZ: quarter weight 0.75,
capital zones and feet-height nodes do not count).

**Forest density (the user, 2026-10-13, on lane TC's questions):** town
trees stay the same in every world, unplantable town spots stay treeless,
the crags pine needs no snow. The forests' density (about 30 % fewer trees
than today, because larger trees reserve larger boxes) is decided with
TD's numbers, together with the leaf counts; **small dense groves are
welcome** (e.g. crowns allowed to interleave in places). Town groves
are never left empty: their trees stand denser, crowns interleaving,
the smallest fitting variant where room is tight (the user, after the TC
review counted 801 → 527 town trees and 8 empty named groves). The wild
forests too come back to roughly today's tree count per area (the user
found the ~33 % loss too much): only wood cells are reserved, crowns
interleave; the density is one parameter, and TD measures its cost. **Town
greening** (the user): capitals and start towns get generated trees on
free areas — small groups and single trees on edges, courtyards and open
grass, never on roads, plazas, doors, NPC sockets, waypoints, quest
targets or stations; a first version by gut feeling, the user's fixes
after captures; TD adds a capital view. The dense groves are
accepted as built; the capitals' open grass between the districts is
greened by the same rule (the user, 2026-10-13). The city-ground
trees differ per world with each world's capital layout (accepted); plot
collars stay unplanted; the one-node stone kerb around every capital plot
is removed (purely decorative; plaza, court and avenue edges stay).

**Trunk quarters, inner faces (the user, 2026-10-13):** the two faces
towards the trunk axis are closed with the trunk's end-grain (top)
texture, so a partly felled thick trunk shows cut wood, not a see-through
or hollow shell.

## Completion (2026-10-14)

Every build lane is merged on main; this lane D (this section and the
status owners) follows on main `5493c37c` (lane TD's measurement, merged
last: desktop only, software rendering, so only its ratios count; the user
accepted them as they are). **0.47.0 is a map reset plus a
migration step:** world generation changed (trees, the swamp, the ore
rows, town compositions), and the pick level scale moved, so the tool
capabilities that crafted and broken tools keep in item meta are rebuilt
at each character's next join (step 0.47.0). The production world
(0.45.1) moves to 0.47.0 in one update and crosses both map resets
(0.46.0 was never deployed on its own). **Push:** the user pushed main at
`b3a30ab0` as a backup (2026-10-14), then, after working through the GUI
checklist below (everything works), at `6a8afb9f` with this closing
documentation. Production runs 0.45.1.

### Lanes

Main's first-parent merges from `18befb9b`, in order (the plan's own
updates `6a9b6775`, `28ea4193`, `047c4456`, `4d02b3c8`, `d7c78d6c`,
`82bf56ec`, `e65bf60a`, `67c679fc`, `e4323194`, `df37d6cb`, `e14b270b`,
`f44ca99a`, `b109b9c1` and `b3a30ab0` lie between them):

| Lane | Merge (follow-ups) | What | Review |
|---|---|---|---|
| FS | `0860dd28` | the `furnace` ambience kind at 0.3 (60 % of fire) for both furnaces, the Dual Furnace sounds, the loop stops on dig with a 0.25 s fade | MERGE |
| TB | `7e1b46a9` | `wp40/treegen.lua`, a pure 1:1 port of `treegen.js`, equal on 4,800 trees under LuaJIT and Lua 5.1 | MERGE |
| ART | `3cbb9f40` | GPT-6 Astra's swamp set, the olive swamp leaves and the Anthracite set (CC0, generators committed; tools only) | the user's picks |
| TA | `89b7f99a` (`b201d0f8`, `a497a1f0`, `8ffa1274`) | 28 shape nodes (octagon quarter mesh, limb base, branch, twig) for seven woods, leaf and ground connect sides, jungle bark M, leaf decay radius 3; the swamp names required; the quarter's inner faces closed, then as the end grain's centre strip | MERGE; delta MERGE; the face deltas checked by the coordinator |
| SW 1 | `51291dce` | the swamp species in both generators, the swamp nodes (nothing placed) | MERGE |
| NZ | `3cc5cd1f` (`279b45e2`) | the facing check over 454 compositions (230 failing sockets → 0), the banner 4 s, first-entry zone XP | MERGE AFTER FIXES (a doc line; no chime at the level cap), fixed; delta MERGE |
| CR | `352da411` | delivery into the inventory item by item with a self-draining overflow; the Basic unlock by held ingredients | MERGE (two minors fixed before the merge) |
| OR | `9b83d3f8` (`102b05a5`) | the lower-half field, Iron behind Bronze (level scale +1, dig times kept), the step 0.47.0; merged with the 0.47.0 declaration and the CHANGELOG placeholder | MERGE |
| AN | `973dc446` | Anthracite (T2 lower half, replaces Coal from T3), Steel from Anthracite only, alloys 10 s, the torch, fuel 120 s, the claim stone's time cap, enchant inputs | MERGE; delta MERGE (after OR) |
| ML | `6758e98e` | the map window's marker layers, quest mode, every marker named, party names every 2 s, one-line zone labels, world images without baked icons | MERGE (the zone-label delta checked by the coordinator) |
| TC | `b6d4888e` (`046d1699`), `4075b4bc`, `6747152d`, `00d0c13b` (`bbf8d707`, `62d7460e`) | trees from the seeded generator in the wild, saplings and towns; then dense groves, town greening and the wild density back (per-cell reservation, `TREE_SPACING`); capital greening; the fix round (city trees released on idle, cut trees newest first, plot kerbs removed) | MERGE (town trees 801 → 527 put to the user); deltas MERGE ×3 |
| SW 2 | `6cb71e25` | the swamp in the world: ground mix, pools that never flow, plants, swamp trees on stilts, mobs and gathering on the new grounds | MERGE (two Lows fixed); delta MERGE |
| TD | `5493c37c` | forest and capital render cost, desktop (llvmpipe; tools only, no fixture): quads per tree, vertices, draw calls, frame time and memory, today → new, trimmed crowns, a dense grove, Highcourt | — (tools only, no game change) |
| D | this section | CHANGELOG, status owners, BACKLOG carry-overs, the tools index, the gate list | — |

Main has 181 portable fixtures (10 new: `r47_ta`, `tb`, `or`, `ms`, `an`,
`fs`, `cr`, `nz`, `sw`, `tc`; lane ML extended `r44_mq`); `mods/` +7,154
−1,256 lines in 180 files, twelve new Lua files (`grug_trees/shapes.lua`
and `growth.lua`, `grug_materials/torch.lua`, `wp40/treegen.lua`,
`tree_templates.lua`, `swamp_pools.lua` and `swamp_writer.lua`,
`wp13/city_green.lua`, `grug_jobs/basic_unlock.lua`, `grug_map/layers.lua`,
`zone_labels.lua` and `zone_discovery.lua`).

### Decisions during the round

The user's decisions of 2026-10-13 and 2026-10-14, one line each (the
coordinator log is outside the repository):

1. **Swamp concept** picked with ART's textures as shown; swamp leaves
   olive (a new node, painted by ART); pools keep the default water.
2. **Anthracite set** (lump, ore, torch) as painted.
3. **Swamp pools on slopes:** never flowing water; gentle slopes levelled
   slightly for a small pool, steep slopes without pools.
4. **FS:** camp fires keep fading on the next pass; the furnace kind
   keeps its own loop limit.
5. **AN:** claim activation stays Coal or Charcoal; the Steel quest texts
   name Anthracite. **CR:** the five questions as built (silent first
   scan, only Basic tokens stored, no Take all, orders capped by room,
   enchant and upgrade results into the inventory). **NZ:** weight 0.75,
   capital zones and feet-height nodes do not count.
6. **Trunk quarter inner faces:** closed with the end grain, then the
   user's idea: a one-pixel centre strip of the top texture stretched
   down the face, so the cut reads as a longitudinal section.
7. **Map layers** as lane ML (the user's work package); its questions as
   recommended: icons 0.34, the rift boss with the clash icon, the §8
   defaults, zone labels on one line ("Name 1–10") over a smaller box.
8. **TC:** town tree seeds the same in every world, the crags pine
   without snow, forest density and leaves with TD; small dense groves
   welcome.
9. **Town groves** never empty: denser, crowns interleaving, the
   narrowest fitting variant where room is tight (after the review
   counted 801 → 527 town trees).
10. **Wild forests** back near today's count: only wood cells reserved,
    crowns interleave, one density parameter (`TREE_SPACING`).
11. **Town greening** on free areas; the dense groves accepted; the
    capitals' open grass between the districts greened by the same rule.
12. **Capital city trees** differ per world (accepted); plot collars stay
    unplanted; the stone kerb round every capital plot removed.
13. **Swamp build:** swamp trees keep their row density (1/120); moss
    soil joins the swamp-only mob lists.
14. **No web client measurement**; TD's desktop numbers accepted as they
    come, full leaves and `TREE_SPACING = 4` stay, a marked regression
    goes to the GUI test, not a change.
15. **Push:** the user pushed main as a backup (`b3a30ab0`); further
    pushes only on the user's word.

The coordinator decided as recommended: OR's step (crafted tools keep
stored capabilities, so characters need a step across the map reset),
declared together with OR's merge to keep main green; the hint "Requires
a Bronze pick"; the centre strip built byte-identical to the variant the
user saw; SW's node name `mud_with_wet_grass`; ML's button threshold
(two rows below 1.25 units of spare height).

### Deviations from the plan

- **Lane ML** joined in wave 2 (the user's work package, 2026-10-13).
- **The step 0.47.0** was not foreseen: §4.12 planned a map reset only;
  lane OR found the stored tool capabilities and built the step, and the
  coordinator declared 0.47.0 with OR's merge instead of lane D.
- **Forest density:** TC's first build lost about a third of the wild
  trees (bigger trees reserved bigger boxes); the per-cell reservation
  brought them back above today's count.
- **Town trees** grew three steps beyond the plan (groves, town greening,
  capital greening). The capitals' open grass lies in no planner slot,
  so it is greened by the city overlay in the R7 settlement successor
  (`wp13/city_green.lua`), per world, instead of fixed compositions in
  unused slots.
- **Swamp:** stilt cells are optional like leaves, and a `stilt_ground`
  rule keeps swamp trees off pool edges and downslopes; the writer's
  surface-skin openings are suppressed at pools; lilies and rooted reeds
  come from the swamp pass, not a decoration row.
- **TD** measured the desktop client only (the user, 2026-10-14).
- **Lane FX** (the 0.46.0 GUI test's findings) did not start: the GUI test
  of 0.46.0 is still open and folds into this round's.
- **AN:** the Anthracite torch goes out silently in a flood (the vendored
  hiss is a raw `sound_play`); two load checks needed a small
  `grug_jobs.token_registered` for group tokens.
- **TA** moved no WP40 pin; the quarter mesh draws with back-face culling
  on (mesh tiles default to off).

### Numbers worth keeping

Comparisons, not targets.

- **Town trees** (compositions, the same in every world): 801 before the
  round → 527 after TC → 938 with the dense groves → 1,095 with town
  greening; after the capital greening and the kerb removal the capitals'
  compositions hold Highcourt 83, Dur Brannoc 62, Gor Drazhak 35,
  Lethariel 141, Kezamba 37 and Nhal Veyr 70. **City trees** on seed
  12345: about 1,560 (Highcourt 300, Dur Brannoc 261, Gor Drazhak 284,
  Lethariel 313, Kezamba 197, Nhal Veyr 204).
- **Wild forests** (22 forest chunks, today → TC → now): seed 12345 321
  → 198 → 339 trees, seed 17713522922938657774 281 → 182 → 322; owner
  clips 30.0 → 31.5 % and 21.4 → 26.8 % of the candidates.
- **Swamp** (seed 12345): ground mud 54 %, wet grass 15 %, lighter mud
  13 %, mottled 10 %, moss soil 9 %; in-engine pool checks on two seeds,
  0 flowing nodes and 0 open sides; swamp trunk nodes in 12 probe chunks
  183 → 103 after the stilt rule (about 44 % fewer trees); swamp tops in
  the swamp mob lists 91 → 100 % with moss soil.
- **Per-band census** (seed 12345): Iron in T1 6,204 → 2,336, Silver in T3
  4,777 → 2,405, Emberglass in T4 4,534 → 2,176, Abyssal Crystal in T5
  1,543 → 700, each upper half 0; Anthracite in T2 2,364, all in the lower
  half; Anthracite against Iron from T3 down 12,739 / 9,553, 9,068 /
  3,021, 6,161 / 2,064, 12,150 / 4,042; band shares T1–T6 4.91 / 3.94 /
  3.47 / 3.85 / 3.75 / 3.47 %; no Coal below −300.
- **Dig times:** the engine matrix of every tool over 689 nodes, 17,225
  pairs: 2 differ (Iron Ore with the Wood and the Stone pick, now refused).
- **Compositions CPU** (contended runs): 2.52 s before the round → 3.88 s
  after TC → 4.39 s with the groves → 5.48 s with town greening; the
  capital greening's own step 4.08 → 4.79 s.
- **Chunk writes round the capitals:** 150 chunks round the six capitals
  35.22 → 38.20 s (+8 %); deciding a capital's city trees 0.23–0.42 s
  CPU; the city trees' memos, 5.5–19.8 MB per capital, now go at idle.
- **Generator:** a template set of 240 trees 194 ms (LuaJIT) / 633 ms
  (Lua 5.1); with the swamp 234 ms for 272 trees; at load the variants
  take 0.18–0.26 s in the main and 0.30–0.38 s in the emerge environment.
  A trunk quarter is 16 triangles (12 before its inner faces closed).
- **Zone discovery XP** at the zone's own level: L1 23, L11 60, L21 98,
  L31 135, L41 173, L51 210, L60 244; all 32 zones at level 60 3,738 XP
  (1.9 % of the way to 60).
- **Map window** (seed 42, 1920 × 1080): 2.9 (None) to 8.5 KB (Towns) a
  layer, quest mode 3.9 KB; world image icons 124 → 0; party sends per
  minute while walking 12 → 30; zone label overlaps at 1x 3 → 0 pairs at
  1080p and 79 → 46 at 1035 × 696.
- **Crafting:** a character that held 300 items stores at most 211
  tokens (4,658 B); a scan about 16 µs for 109 slots; the Basic page
  3,172 B, 4,469 B with the overflow shown.
- **Render cost (TD, desktop, 1280 × 720, software rendering (llvmpipe),
  so only the ratios count; seed 12345, a 128 × 128 test forest at about
  each world's density):**
  - quads per tree, today → new: apple 454 → 2,292, jungle 574 → 1,224,
    kapok 1,585 → 5,122, acacia 514 → 1,130, pine 402 → 1,072, aspen 559
    → 853, silverwood 551 → 2,139, gravewood 110 → 839 (1.5–7.6×);
  - frame time over the empty platform, today → new: apple ×1.37 → ×2.15,
    jungle 1.81 → 2.30, pine 1.31 → 1.97, silverwood 1.35 → 2.09, aspen
    1.17 → 1.78, kapok 1.27 → 1.73; acacia and gravewood stay cheap;
  - draw calls rise only 0–50 %, far less than vertices;
  - crowns trimmed to 50 % leaves save about 25–30 % of the added
    vertices and frame time (75 % about half that); not built;
  - a dense grove holds about 1.5–2.7× the vertices of the whole new
    scene where it stands;
  - Highcourt, today → with the capital greening: +83 % vertices (634 k
    → 1,157 k), about +35 % frame time, draw calls 379 → 488, the largest
    single step measured;
  - the swamp tree is not measured (it has no "today" to compare).

  **The user's ruling (2026-10-14):** accepted as is; full leaves and
  `TREE_SPACING = 4` stay, and the user checks on a real GPU. TD's two
  questions are settled by it: the leaf counts (full crowns) and the
  capital greening (kept).

### Classification

- **Map reset:** TA (connect overrides), TC, SW, OR and AN (world
  generation, town compositions, ore rows), NZ's Kezamba bench. The world
  map image and the layout caches rebuild once.
- **Migrate:** OR's step 0.47.0 (stored tool capabilities rebuilt at
  join; offline only markers).
- **Compatible:** TB, FS, CR, NZ, ML. Saved state the new code reads
  differently: the new player meta `grug_jobs:held` (missing = a silent
  first scan) and `grug_map:visited_zones` (the current zone marked
  silently at the first login; after the reset that is the start zone);
  new optional job fields `delivered` and `picks` (jobs from before finish
  as before); an old output-area stack drains into the inventory at the
  first join; claim stones' `paid_until` is read unchanged.
- **The declaration:**
  `{"schema": 2, "version": "0.47.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0"]}`.

### Open notes

The reviews' and reports' backlog notes are in the
[BACKLOG](../../BACKLOG.md#round-47-carry-overs).

### GUI checklist (Round 47)

Desktop (GUI scale 1 and 2) and the web build (about 1280 × 720), on new
worlds; Round 46's [checklist](round46-plan.md#gui-checklist-round-46) is
still open and is tested on the same build.

**Check first:**

1. Frame rate on a real GPU in an apple, a jungle and a silverwood forest,
   in a dense grove (Lethariel or Highcourt) and in Highcourt's square (or
   another capital: the capital greening is the largest single step),
   desktop and web. TD (software rendering, ratios only): new trees draw
   1.5–7.6× the quads of today's, a forest's frame time over an empty
   view rises from about 1.3–1.8× to 2.0–2.3×, a dense grove holds
   1.5–2.7× the vertices of the new scene, Highcourt +83 % vertices and
   about +35 % frame time; half leaves would save about 25–30 % of the
   added cost.

**Trees:**

2. Every species in the wild on two seeds; the trees differ between them;
   forests about as dense as before, crowns interleaving in places, no
   half crowns at chunk borders.
3. Octagon trunks, limb joins, twigs into the leaves, roots only on
   ground; on the web client the quarter mesh draws.
4. Jungle trees, their log and the kapok town trees show bark M.
5. Dig one quarter out of a 2×2 trunk: the gap shows cut wood (the end
   grain's centre strip), not a hollow shell.
6. Leaves of every tree, the swamp leaves and the hanging moss decay
   after felling; the shapes are not in the creative inventory, and
   placing a `/give`n twig does nothing.
7. A sapling of each species grows a generated tree; picked apples
   regrow. The crags pine has no snow.

**Towns and capitals:**

8. Town trees in Dawnmere, Hearthpine, Kapok, Silverleaf, Stillgrave,
   Sunscar and Kezamba; the named groves (Highcourt's market and lore
   groves, Lethariel's groves, Nhal Veyr's copses) dense, none empty.
9. The capitals' open grass and yards greened; no tree on a street,
   square, door or NPC; no stone kerb round a plot; 1–6 stems per capital
   stand on street side slopes (judge them). Town, capital and forest
   density as a whole.

**The swamp:**

10. On two seeds: the mixed ground, pools one or two deep with lilies and
    reeds, plants, swamp trees on stilts with hanging moss; about 44 %
    fewer swamp trees than before the stilt rule (none beside a pool or on
    a downslope): judge the density.
11. Dig a bank block next to a pool: water flows only from your opening.
    Crocodiles, bog oozes and bog fowl spawn, also on moss soil.

**Mining:**

12. No Iron above y −50; a Stone pick on Iron says "Requires a Bronze
    pick", a Bronze pick digs it at the old speed; T2–T6 rock digs as fast
    as in 0.45 with the stone sound.
13. Silver only below −400 in T3, Emberglass below −600, Abyssal Crystal
    below −850.
14. Anthracite from y −200 down and no Coal below −300; a Stone or Bronze
    pick fails on Anthracite, an Iron pick digs it.
15. The Anthracite torch on floor, wall and ceiling, brighter; cave
    spawns stay about 6 nodes away.

**Steel, furnaces and the Claim Stone:**

16. Steel only from Anthracite; a Bronze bar in 10 s.
17. A burning town hearth and a personal furnace are clearly quieter than
    a camp fire; a burning Dual Furnace plays the loop; dig one: silence
    within about a quarter second, also for a second player; a
    furnace out of fuel fades within a few seconds; fire loops near camps
    and furnaces together (up to 2 + 2) do not pile up badly.
18. The Claim Stone takes Anthracite as 1.5 lumps, refuses a piece that
    does not fit, and its label ("Lump 7 h 16 min, Anthracite 10 h 54
    min; …") fits on the web; pick-up refunds Charcoal; T2 armour enchants
    accept Charcoal.

**Crafting:**

19. A craft lands in the inventory item by item; a full inventory refuses
    the start ("Not enough room in inventory"), Max shows the room.
20. Filling up mid-craft puts the rest in Overflow, which empties about
    1 s after a slot frees; Stop keeps the finished items; enchant and
    upgrade results land in the inventory.
21. A fresh character sees only Stick and the wooden tools; a dug tree
    gives "New recipe: Apple Wood Planks" within half a second, a pickup
    within 10 s.

**NPCs and zones:**

22. Silverleaf's bowyer and market keeper, Dawnmere's barn and smithy
    residents and its green sitter, a village of each race, a capital
    hall's service resident and the PvP camp gate guards face away from
    walls, and a stable's gate resident faces into the stable; the two stall keepers (Silverleaf's market, Lethariel's armoury
    counter) now face the street, not their counter: judge them.
23. The zone banner stays about 4 s.
24. A new character: nothing in its start zone; the next zone "+N XP" and
    the level-up chime; again nothing; a capital zone or the open sea
    nothing; an existing character gets no XP at login.

**The map window:**

25. The layer buttons: one row at 1080p, two at small windows; the active
    one highlighted; every layer shows only its markers, each with a
    tooltip; selecting a quest shows its targets with the objective lines
    and the hand-in NPC; a layer button deselects; a party member's arrow
    has the name and moves about every 2 s; the world map has no baked
    icons, the minimap is unchanged; zone labels on one line, readable on
    the web, though they crowd in small windows (46 overlapping pairs at
    1035 × 696); a ring's tooltip covers its whole square.
26. At 16:9 a gap of about 0.85 units under the map at 1080p; POI
    tooltips repeat the kind ("Bandit camp: Goldmead Bandit Camp"); at
    720p a quest text that overflows its box resets its scroll about three
    times as often in a moving party.

**The update:**

27. A 0.45.1 world taken to 0.47.0 with the map reset and the step: an
    old Iron pick digs T2 rock again after the join, a broken tool stays
    broken; Help → About shows 0.47.0.

### Round-end gates

**Round-end gates** (coordinator, 2026-10-14, on main `c8e1ca12`): full
fixtures 181/181, the full seed fleet 304/304 (34 min 40 s),
`check_upgrade.py` (0.47.0 against origin/main `b3a30ab0`),
`check_fresh_server.py`, `r28_design/validate.py --game` (0 errors),
`income.py --check`, `build_doc.py --check`, the names checks, the bat,
enchant-mask, cloak and web-data checks and a smoke boot PASS; synced. On
lane D's branch: `tools/r37_dc` and `check_upgrade.py` (0.47.0
against origin/main) PASS.
