# Round 47 — Trees, mining progression and crafting feedback

Coordinator: Claude (Opus 5.5), drafted 2026-10-13 from the user's decisions
of the same day. Status: **in progress** (the user's "go", 2026-10-13).

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

1. **Leaf counts and forest density** (incl. dense groves): after TD.

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
greened by the same rule (the user, 2026-10-13).

**Trunk quarters, inner faces (the user, 2026-10-13):** the two faces
towards the trunk axis are closed with the trunk's end-grain (top)
texture, so a partly felled thick trunk shows cut wood, not a see-through
or hollow shell.
