# Round 56 — playtest fixes, clear enchants, the hood and the quest survey (0.56.0)

Coordinator: Claude, 2026-10-22. Status: **in progress** (the user's go 2026-10-22).

The source is the user's playtest with many players on 2026-10-21 and the discussion of its feedback on 2026-10-22.
This round takes the fixes that need no map reset, the enchant display, the cloth/leather hood, two quest lanes
that prepare the quest rework and, in parallel, the town buildings as editable templates with a local editor. The
larger topics of the same discussion (the crafting window, the town fixes, the mining camps, the quest rework
itself) are decided in principle and recorded in [§8](#8-decided-for-later-rounds) for their own rounds.

Start state: main `c4778a13` (0.55.1 plus docs, pushed 2026-10-21).

## 1. Lanes and waves

| Wave | Lane | Who | Goal (one line) | Waits for |
|---|---|---|---|---|
| 0 | TPLFORMAT | coordinator | The template format (layer grids, legend, roles, points, town layouts) and the validation rules | the user's go |
| 0 | HOODPAGE | coordinator | The polygon-part schema for the armor catalog and a preview page where the user shapes the hood | the user's go |
| 1 | MOBAI | Opus | Ranged mobs close in to their shot range; level-scaled aggro radius; the hit alert centred on the hit mob | the user's go |
| 1 | MOUNT | Opus | Land mounts fall like players, jump just over 2 nodes, get +5 nodes of fall tolerance and are not thrown off by a fall | the user's go |
| 1 | SMALL | Opus | The sell list takes the inactive hotbar; Quartermasters serve the whole faction; everyone may eat mana food | the user's go |
| 1 | FLOAT | Opus | Items in water rise to the surface and stay there | the user's go |
| 1 | AFFIX | Opus | Tooltips name prefix and suffix; the enchanting station names the enchant it replaces | the user's go |
| 1 | QUESTMAP | Opus | A generated overview page of every quest and its chains | the user's go |
| 1 | HOOD | Opus | Polygon parts in the armor pipeline, the hood part on the head slot, the chin-strip rule | HOODPAGE's schema |
| 1 | FREEZE-TOWNS | Opus | Loader, exporter and the shared validator; the six start towns' buildings frozen into templates, byte-identical | TPLFORMAT |
| 1 | VIEWER | Opus | The town viewer from branch `town-viewer` onto main as a reusable renderer, with noclip flight and a gallery of all templates (the gallery on real templates after FREEZE-TOWNS merged) | TPLFORMAT |
| 2 | QUESTIDEAS | Astra | An idea report: strategies to make quests exciting and less repetitive | QUESTMAP merged |
| 2 | HOODART | Astra | Hood faces for every cloth and leather head piece (finish step, §7) | the user's hood values, HOOD merged |
| 2 | FREEZE-CAPITALS | Opus | The six capitals' buildings (plots and core buildings) frozen the same way | FREEZE-TOWNS merged |
| 2 | EDITOR | Opus | The local template editor: 3D view and layer grid, the edit rules, validation before saving | VIEWER and FREEZE-TOWNS merged |
| 3 | D | Opus | Docs, CHANGELOG, version 0.56.0, STATUS, GUI checklist | everything else (not the hood finish step) |

Every non-trivial code lane gets an independent Opus review. QUESTIDEAS is a report, not a change: the coordinator
reads it and hands it to the user, without a review.

## 2. The user's rulings (2026-10-22)

**Mobs**
1. **Aggro radius by level gap** (gap = player level − mob level): the full `view_range` up to a gap of 5, then 20 %
   less per level: 6 → 80 %, 7 → 60 %, 8 → 40 %, 9 → 20 %, 10 and more → 0 %. Always at least 1 m:
   `radius = max(view_range × clamp(1 − 0.2 × (gap − 5), 0, 1), 1)`. It applies to a mob picking a **player** target
   by itself; a mob that is hit still fights back, and monsters targeting NPCs are unchanged.
2. **The hit alert** is centred on the mob that was hit, not on the hitter (a bug today). It does **not cascade**:
   only the mob that was really hit calls its kin; alerted mobs call nobody. `camp_swarm` stays as it is (its chain
   stays inside one camp).
3. **Ranged mobs** walk closer when the target is beyond their shot range, instead of standing and "shooting"
   arrows that are deleted on spawn. The shot range becomes its own value, separate from `view_range`.

**Mounts (land)**
4. Land mounts fall with the player's gravity (19.62 instead of 9.81). No ground snap.
5. The jump impulse is raised so a mount jumps just over 2 nodes (about 9.3 instead of 6.5).
6. **+5 nodes of fall tolerance** while riding, and otherwise the same formula: the drop is reduced by 5 before the
   damage is computed (11 nodes → 5 %, 13 → 20 %, 20 → 50 %).
7. Fall damage never dismounts. Damage from mobs and players still does.

**Trade, food, items**
8. The vendor's sell list includes the inactive hotbar, with no marker (the active hotbar has none either). This
   replaces Round 50 ruling 3.
9. Quartermasters trade with every player of their faction. The 10 % discount stays for their own race only. This
   replaces the race-exclusive vendor of [world.md §7](../design/world.md).
10. Warriors (any class without mana) may eat mana food; the mana part does nothing. The mana line is hidden in the
    eater's **status effect** text but **stays in the item tooltip** (a Warrior should see that the food suits a Mage
    friend). Mana potions stay refused for classes without mana (answered "ja", 2026-10-22).
11. Every dropped or thrown item in water rises to the surface and stays there (lava excepted).

**Enchants**
12. The tooltip marks which line is the prefix and which the suffix (`Prefix: +5 Strength (T2)` /
    `Suffix: …`, prefix first), and the enchanting station shows what a new enchant replaces.

**The hood**
13. The cloth head piece gets a hood shape: wedges on top of and behind the head (flat at the front and bottom,
    higher and narrower towards the back and top), joined at the back. The user shapes it on a preview page.
14. "Boxes only" in the armor tools is a tool convention, not a ruling; it is lifted. The goal is **low poly**, and
    triangles and wedges are welcome (they can save polygons).
15. The hood is a part of the **head slot in the shared armor atlas**, like the shoulder spikes: every head piece
    paints it or leaves it transparent. Metal leaves it transparent; cloth and leather paint it. No new texture slot.
16. Clipping in the few head poses where the hood could touch the shoulders is accepted; no head-versus-body check.
17. The **chin strip** (the helm front face's bottom row) becomes transparent on every cloth head piece and on the
    leather pieces without a veil (T1–T5). Leather T6 (the veil) and metal stay as they are.
18. The cloth head icon stays the pointed hat.

**Quests (this round prepares the rework, §8)**
19. An overview page of all quests and their dependencies (QUESTMAP), and an idea report from Astra (QUESTIDEAS):
    ideas only, no implementation. New POIs and new quest types ("visit place X", "find NPC <name> in <zone> and
    bring them this item") are explicitly allowed, limited to types that are easy to build.

**Building templates and the editor** (the user, 2026-10-22)
20. The user wants to edit the town **buildings** themselves. Streets, plazas, walls, the city edge, trees, terrain
    fitting, plot approaches, capital plot placement and the terrace podiums stay algorithmic. (Podiums are not part
    of a template: they depend on the town's ground and lift and would add complexity; the podium stair's
    off-by-one is fixed in code, §8.)
21. Every building becomes a **building template** (the name keeps it apart from wp40's POI, kit and tree
    templates; its own directory): today's part (its local cells, fixed `w × d × h`, its points) saved as a
    file. Identical parts become one template.
22. **Race-specific blocks are palette roles**, in every template, not only in shared ones:
    - A legend entry is either a **role** (wall, floor, roof …, also shape variants such as `roof:stair`), which is
      replaced per race through the existing palette when the town stamps the template, or a **fixed node**,
      which is the same for every race (torch, glass …).
    - The roles are found by building each part with all six race palettes plus one **probe palette** that gives
      every role a distinct node of the same kind: a cell that follows a role is a role cell, a cell that follows
      none is a fixed node. Roles that are identical in all six palettes today (floor/ceiling,
      fence/railing/table_leg, light_indoor/light_wall, post/tree_log/window_frame) and race-invariant roles (bed,
      storage, shelf, hearth, castle_paving …) are still recorded as roles; where only the probe can tell them apart,
      a group may map to one canonical role, which is byte-identical today.
    - **Orientation, not raw param2:** the legend stores an orientation; the stamp resolves it per resolved node
      (`param2_kind`, `canonical_param2`), because the same cell can be a pane at param2 3 for one race and bars at
      0 for another. Per-position flora that picks a different role per race becomes a per-race variant.
    - **Optional roles** (`palette.maybe`: flower pots and the like; a race without one degrades) are stored with
      their fallback, which the stamp uses when the race lacks the role. Where a race builds a different shape,
      not only a different material, the template keeps one variant per race, and the lane reports how often.
    - **Palette overrides per placement** (Silverleaf's pale roofs, Highcourt's white and slate) belong in the
      town layout, not in the template.
    - In the editor, roles come first in the item list, drawn in the previewed race's material and marked as roles
      in the grid. Painting a role is the normal case; a fixed node in a template several races use is flagged.
    - The validator refuses a role that a race placing the template does not define (optional roles excepted).
    - **New roles** (for example a faction banner) are added in `palette.lua` by a lane, never in the editor.
23. After the freeze the **templates are the source of truth**; the building generators leave the game, so nothing
    regenerates over an edit. Materials still change through the palettes.
24. The freeze itself is **byte-identical** (proven by the settlement identity hashes): compatible, no map reset.
    No template is edited in this round.
25. **The empty-cell policy** per cell: "force air" (the part writes air today) or "leave unchanged" (the part writes
    nothing). The editor shows both, in the 3D view and in the grid.
26. **The editor is a local tool** (a small server bound to localhost only, writing template files into the working
    tree), not an artifact. A read-only gallery may additionally be published.
27. **Fixed size:** the editor never changes a template's bounding box. The box includes what a part writes outside
    its `w × d` footprint (eave overhang, apron, foundation skirt); the rotation pivot (`w`, `d`) and the part's
    metadata (`peak` and the like) are stored separately.
28. **Points** (NPC posts, idle points, patrol points, doors, quest sockets) are shown and may only be **moved**;
    ids, kinds and patrol orders stay. Town-wide points (street patrols, waystone) belong to the town layout, not
    to a building.
29. **Multi-cell objects reserve their cells:** a door takes its cell and the one above it (the upper cell is
    locked); a bed takes two cells in its facing direction. They are placed only where all their cells are free and
    removed as a whole.
30. **Undo, redo and reset** (back to the saved file). The editor **saves only on completion**: an explicit save that
    writes only when validation has no errors (warnings need a confirmation), atomically. A crash keeps a local draft
    in the browser, never in the repository.
31. The 3D view can **fly through a building with noclip** (free flight, no collision).
32. **A building template holds everything inside its box** (the user, 2026-10-22, on plan review B2): the freeze
    cuts each building out of the *finished* town, so what the town writes into a building after stamping it (hall
    inlays, braziers and hangings in Highcourt and Dur Brannoc, belfries on Dawnmere's and Highcourt's roofs, room
    and apron decor) becomes template content, and the asserts that guarded those writes (`inlay_floor`) leave the
    load path. Building-bound points that the towns place in town coordinates (the `door`-tagged hall quest givers
    in Hearthpine and the capitals) become points of the template and move with it. Only what lies outside the
    buildings stays algorithmic.
33. **Validator: structure hard, content per edited cell** (the user, 2026-10-22, on plan review B1):
    - always hard: bounds and legend, known nodes, complete multi-cell objects, every point placed as its kind
      requires (a door point in the door cell, a room corner at floor height, a standing point on a floor with two
      free cells above);
    - hard only for cells changed in the editor: the curated palette and reachability. Existing cells outside the
      palette (river water in a fountain, farm soil and crops, stations with inventories) stay valid; they just
      cannot be painted anew;
    - known defects of the frozen state (the Lethariel bough stair) are a listed baseline, reported as warnings
      until fixed;
    - so `tools/building_templates/check.py` is a hard gate from this round on.

**Answered defaults** (2026-10-22):
- D1. The shot range may be a little **larger** than `view_range`: a player can stand inside a mob's shot range
  without drawing its aggro. Coordinator default for the size: `view_range + 4` (16 → 20). The mob closes in to a
  little inside its shot range so that it does not hover at the edge.
- D2. Rule 1 covers monsters (wild mobs, elites, rares, bosses). It does not cover guards and other faction NPCs;
  their targets stay as they are (confirmed).
- D3. The QUESTIDEAS report is written in German for the user, with game names and ids in English (confirmed). It
  lives in the private orchestration folder, not in the repository.

## 3. Shared conventions

- **Upgrade classification:** every lane of this round is expected to be **compatible**. A lane that finds
  otherwise stops and reports before building it.
- **Fixtures:** `tools/r56_<lane>/portable_test.lua` for new logic. A fixture that asserts an old ruling or stubs
  the old call (the sell list case in `tools/r50_hotbar`, `carried_lists` stubbed in `tools/r48_sell`, the race
  vendor in `tools/r31_n`, the mana food refusal) is changed to the new
  ruling in the same lane, and the report names it.
- **Design docs are the spec:** each lane updates the section its ruling changes (combat_stats.md for aggro and
  ranged mobs, mounts.md, inventory_equipment.md, world.md §7, items_crafting.md, the enchant section,
  armor-format.md). Stale "race perk" fall-damage comments (`grug_core/combat.lua`, `grug_mounts/entity.lua`,
  mounts.md) go with MOUNT.
- **No existing game is named** as a reference anywhere (repo, code, briefs, reports).

## 4. Lane goals (briefs add file facts)

**HOODPAGE (coordinator).** Write the schema of a polygon part in the armor catalog frame (skin pixels; the head
bone's frame): convex faces given by their vertices, each with its UVs on a sheet in the free armor atlas rows
(42–63), front and back faces, and zones A and B. Then build a private preview page (an artifact, like Round 55's offhand workshop page): the head with the current
helm shell; the hood's wedges shaped by a few clear parameters (height and width at the front and at the back, depth,
the joining piece) and, where the parameters are not enough, by moving single vertices; the head's nod range (−50° to
+60°) to look at; and an export in the schema's format. The schema is
committed before HOOD starts. The page's values are the user's to set; HOOD starts from the page's defaults.

**MOBAI.** Rulings 1–3.
- **Ranged mobs:** a separate shot range per mob, by default `view_range + 4` (D1). When the target is beyond it, a ranged mob takes the path a ground
  mob already takes without sight (walks closer) instead of the stand-and-shoot branch. The projectile lock uses the
  same shot range and the same eye geometry as the sight check, so a mob that "sees" its target does not fizzle at
  short range either. Ranged kings close in too.
- The Bandit Archer gets a shoot clip (the poacher's punch clip is the precedent).
- **Aggro:** the level-scaled radius inside the existing target filter, before the line-of-sight raycast, so it
  costs a comparison and saves raycasts.
- **Alert:** centred on the hit mob, with the hit mob's `view_range`, not cascading.
- Report numbers for comparison (objects scanned, raycasts per scan) on the same probe before and after.

**MOUNT.** Rulings 4–7 in `grug_mounts`: gravity, jump impulse, the +5 tolerance in the mount's fall formula, and
the dismount callback skipping `reason.type == "fall"`. Water and flying mounts keep their own physics (confirmed
2026-10-22). The
fixture covers the damage table above and the no-dismount rule.

**SMALL.** Rulings 8–10.
- The sell list and lot selling walk the same lists crafting uses (including the hidden hotbar layout).
- The Quartermaster's race check goes; the discount check stays.
- The mana food refusal goes; the status text filters the mana parts by the eater's mana pool, the item tooltip
  stays unchanged; the mana potion refusal stays.

**FLOAT.** Ruling 11 in the existing `__builtin:item` override: an item inside water rises, holds at the surface
and drifts no further than the water lets it; outside water it falls normally again. The resting position is sent to
clients once it settles (the 0.49.1 resync only fires on collisions). Merging of floating items is not needed.
Cost: report the per-step cost for items in water and confirm items on land pay nothing new.

**AFFIX.** Ruling 12: the tooltip's affix lines carry `Prefix:` and `Suffix:` in a fixed order (prefix first). The
enchant box shows `Replaces: <the line it replaces>` when the target already has an enchant in the recipe's channel,
alongside the existing higher-tier warning. Found items keep their channels; only the display changes.

**QUESTMAP.** A tool (`tools/r56_questmap/`) that reads the shipped quest data (`grug_quests/data/zones/`, the
givers, hubs and names) and writes one self-contained HTML page. The page shows, per zone and hub:
- every quest with its level, giver, objective types, rewards and prerequisites;
- the chains as readable trees or a graph;
- flags for what the rework needs to see: the same quest in several start towns, a reward that equals the requested
  items (the wooden axe and pickaxe), long kill-only chains, quests behind many prerequisites;
- counts per zone and per objective type.

Copper rewards are computed at load (`Q.quest_copper` in the quest loader); the tool reuses that formula.

The coordinator publishes it as a private page for the user. The tool is regenerable (`--check` not needed); nothing
ships in `mods/`.

**HOOD.** Rulings 13–18.
- The armor pipeline learns the polygon part from HOODPAGE's schema: catalog, export, atlas, the checks, the z-fight
  check and the renders. The model generator emits it into the armor buffer on the head bone.
- The hood part with the page's values. Placeholder art exists only in the tools (shots, test-only mod); the shipped
  head textures leave the hood transparent until the user's pick.
- The chin-strip rule in the opacity check, and in the cloth and leather painters.
- Regenerated models (player and NPC), the `.glb` and its checks; the format doc (armor-format.md) and its budget.

**QUESTIDEAS (Astra, effort `xhigh`).** An idea report, not an implementation. The brief carries the user's
feedback in their own words:
- the quests feel repetitive and boring;
- a story thread through the game, at the latest when the player reaches the capital (about level 15–20);
- story quests set apart from pure kill quests, and marked in the game (for example another marker and list colour);
- more story, fewer repetitive quests and fewer dependencies between quests (above all between kill quests);
- quest families, so that a quest done in one start town is not offered again in another;
- rewards that do not look like the requested items.

The brief also gives:
- the inputs: [quests.md](../design/quests.md), the QUESTMAP page, the zones, the existing objective types, the POI
  and NPC systems, the planned mining camps (§8);
- the limits: new POIs and new quest types are welcome when they are easy to build ("visit place X", "find NPC
  <name> in <zone> and bring them this item"); no code, no finished quest texts; no existing game named as a
  reference.

The report offers three or four distinct strategies. Each has the player's experience, the systems and new quest
types it needs (with rough effort), its risks, and a few example quest ideas. It ends with quick wins and a
recommended combination.

**HOOD-FINISH and HOODART (finish step).** The user accepted the page's first shape unchanged (2026-10-22), so
HOOD builds with the final values and no regeneration step is needed. Then a small Astra art lane: Astra paints the hood faces for every cloth and
leather head piece (and the transparent chin strip) in the existing tier palettes and zones. The brief gives design
goals, not per-tier permission lists. The user picks on a pick page as in Round 54; the bake runs the pick into
`mods/`.

**TPLFORMAT (coordinator).** The format doc ([building-template-format.md](../technical/building-template-format.md)):
- one text file per template: name, bounds, a legend (character → role or node, param2), one character grid per
  y layer (`.` force air, space leave unchanged), and a points section; a template that needs more legend entries
  than single characters allow uses two characters per cell;
- one layout file per town: the template, position, turns, lift and palette overrides (ruling 22);
- multi-cell objects and the editor's palette rules;
- the validation rules (below), written once and used by both the editor and the gate.

**FREEZE-TOWNS.**
- An exporter that builds each start town and cuts every building out of the finished town (ruling 32), with its
  points, and writes the templates, merging identical ones. The roles of
  every template are found as ruling 22 says (every race palette, cell by cell); cells that stay ambiguous keep
  their node and are listed.
- The loader in the mapgen: the towns stamp templates instead of calling the generators. A malformed template
  stops the server at load with a clear message, never mid-generation.
- **The validator** (`tools/building_templates/check.py`, a hard gate; which rules are hard is ruling 33):
  - bounds and legend;
  - known nodes (against the refreshed node registry);
  - multi-cell objects complete;
  - every point placed as its kind requires;
  - standing points reachable from the entrance in a simple grid walk (steps of at most one, doors passable);
  - the entrance still on the footprint edge;
  - no "leave unchanged" cells in a floor inside the walls (warning);
  - only nodes from the editor palette in edited cells;
  - the baseline list of known defects.
- **The release check:** `check_upgrade.py` learns that a change of what the towns build requires a declared map
  reset. It compares the generated settlement identities (and the point digest below) with the previous release,
  not the template files, so this round (which adds every file while building the same) passes, and palette or
  layout changes count too.
- **Proof:** the identity hashes of all six towns unchanged, and a digest of everything the identity bytes leave
  out (landmarks, sockets, doorways, rooms, inside points, `peak`) equal before and after, before/after load numbers, the seed fleet `quick`
  (the world writer's input changes), the full fixtures.

**VIEWER.**
- The viewer from branch `town-viewer` (one commit on 0.50.0) onto main, as a renderer the editor reuses. The node
  registry (`viewer_nodes.json`, from 0.50.0) is refreshed with the headless dump; it is also the validator's named
  source of known nodes.
- Free noclip flight next to the existing walk mode.
- A gallery: every template once in a 3D grid, grouped by town or race and labelled, with its "used N× in …" list.
  It starts on a fixture template and switches to the real ones once FREEZE-TOWNS has merged (main merged into the
  lane).
- The diff and workshop tools come along unchanged and wait for a later use.

**FREEZE-CAPITALS.** The same for the six capitals: the plots and the core buildings (king hall, gatehouses, market,
barracks, temple and the rest; the towers on the city wall belong to the city edge and stay algorithmic). The core's composition and the plot planner stay algorithmic. Same
proof.

**EDITOR.** The local tool, rulings 25–31:
- the 3D view and the layer grid side by side; the layer picked by buttons or the wheel; the layers above shown
  transparent or hidden;
- tools: paint, picker, force air, leave unchanged, rotate (only where the node supports it);
- the multi-cell objects (doors, beds, and any other node whose box reaches into a second cell; the lane lists
  them from the node registry), and fences and panes connecting as in the game;
- an orientation marker for the street side and the entrance (the template is shown in its own frame, the town
  turns it);
- the item list: roles in the previewed race's colours first, then the editor palette with search;
- the points as markers, move only;
- undo, redo, reset; a changed-since-commit highlight;
- save only through the shared validator.

**The editor palette is curated**, which is the main guard against accidental bugs. It holds:
- full blocks, stairs and slabs, glass and panes, fences, doors, beds, lights and decor.

It holds no:
- liquids;
- falling nodes;
- plants that need soil;
- nodes with inventories or text unless the game fills them;
- nodes whose function depends on where they stand (crafting stations and the like) unless the template already
  has one.

A shared template shows "used N× in …" before every save, and a literal node painted into a multi-race template is
flagged.

**D.** Docs, CHANGELOG, version 0.56.0, the upgrade declaration (compatible), STATUS, the GUI checklist (§6),
ROADMAP and BACKLOG, and §8 carried into ROADMAP and BACKLOG.

## 5. Rules

The usual ones ([round workflow](../process/round-workflow.md)): one worktree and branch per lane; an independent
Opus review per non-trivial lane and a delta review for logic changes in a fix; the Lua queue at most 8 at once; no
pushes, merges or syncs by lanes; the sync to the user's Luanti only after the round. Fixtures: each lane runs only
its own fixture plus the fixtures that test the behaviour it changes, and the full run once before its report.
Nothing unpicked ships (the hood stays transparent everywhere until the user's art pick).

## 6. Verification

- **Gates:** the full fixtures, `check_fresh_server.py`, `check_upgrade.py`; for HOOD the topic checks AGENTS.md
  names: `r54_armor` (`export.py`/`atlas.py --check`, `zfight.py`, `bake.py --check`), `r54_art`
  (`assemble.py`/`ghosts.py --check`), `r40_an/make_poses.py --check`, `r55_model/test_frames.py`, the model
  `--check`, `build_glb.py --check`, `check_glb.py`, and `web_data/export.lua --check` when textures change;
  `r28_design/validate.py --game` if MOBAI adds a field to mob definitions; `tools/building_templates/check.py`, the
  seed fleet `full` (owed by the freeze), one boot.
- **Headless shots** (HOOD): the cloth and leather head pieces at T1, T3 and T6 and one metal helm, from the front,
  the side and the back, with the head nodding up and down.
- **Templates:** the identity hashes and the point digests of all towns and capitals unchanged; `tools/building_templates/check.py` on every
  template; one fresh-world boot with a start town and a capital visited headless.
- **GUI checklist** (D):
  - a mob 7 levels below you notices you only at about 60 % of its usual range; one 10 or more below only when you
    touch it; a hit mob still fights back;
  - pull a pack mob from range: its kin around **it** join, and they pull nobody further;
  - an Elf Mage at full range (23 m) against an archer, poacher or skeleton archer: the mob walks closer and its
    arrows arrive;
  - ride a horse down a normal slope: no damage; jump a 2-node step; fall about 11 nodes: a little damage and you
    stay mounted; a mob's hit still throws you off;
  - the sell window lists items from the inactive hotbar, and selling them works;
  - kill a mob in a lake, and drop an item into water: both rise to the surface;
  - a Warrior eats mana food: it is eaten, the status shows no mana line, the tooltip still shows it; a mana potion
    is still refused;
  - a friendly player of another race trades with your race's Quartermaster without the discount; you get 10 %;
  - an enchanted item's tooltip names prefix and suffix (items in chests update once carried); the station shows
    "Replaces: …";
  - the template editor: open the gallery, open a building, fly through it with noclip, edit a few cells on two
    layers (a door locks the cell above it, a bed takes two cells), undo, reset, try to save an invalid change
    (refused), save a valid one and see it in `git diff`; revert it;
  - a new world's start town and capital look exactly as before;
  - the hood on cloth and leather head pieces (after the art pick), the chin strip see-through on cloth and leather
    T1–T5, metal unchanged, the website's model.

## 7. Orchestration notes

- **Merge order:** HOODPAGE's schema → HOOD; MOBAI, MOUNT, SMALL, FLOAT, AFFIX and QUESTMAP in any order; QUESTIDEAS
  after QUESTMAP; TPLFORMAT → FREEZE-TOWNS and VIEWER → FREEZE-CAPITALS and EDITOR; D last. The lanes share no code
  file; each design doc has one owner in this round, except items_crafting.md (SMALL: mana food; AFFIX: the
  enchant section), merged one after the other.
- **Template edits** (the user's, after this round) change what new worlds build: a release with a template
  change declares a map reset; FREEZE-TOWNS teaches `check_upgrade.py` to enforce it.
- **Size:** 16 lanes with the template half; the coordinator staggers the starts within the process budget.
- **Shared docs:** CHANGELOG, STATUS and the version only in D.
- **Decided during the round:** the hood's shape (the user, on the page: the first shape, unchanged, 2026-10-22); the hood art pick; the QUESTMAP page's
  look (the user's first look, small fixes then).
- **The finish step** (the user's hood values, HOODART, the pick) may come after the round end as 0.56.1, as in
  Round 55.
- Every lane launch prompt carries the fixture sentence of the lane-start checklist. The freeze lanes keep to the
  mapgen engine-run budget (a few runs of at most about 5 minutes, a region, never the whole world).
- **Plan review:** a fresh Opus read this plan against the code before the user's go (2026-10-22); its findings
  are folded in.
- **The coordinator's own deliverables** (TPLFORMAT's format and validation rules, HOODPAGE's schema) get an
  independent Opus review before FREEZE-TOWNS, VIEWER and HOOD start on them.

## 8. Decided for later rounds

These were decided with the user on 2026-10-22; each becomes its own round, in an order the user sets after this one.

**Crafting window.**
- **Layout C:**
  - the right column goes and the middle box widens;
  - the Craft/Queue button sits right-aligned next to "Max";
  - the progress bar sits at the bottom with a small stop button;
  - exactly one line below the bar names the current job ("Aspen Wood Planks ×40"). It shows **no countdown**: the
    bar is a client animation and the formspec is not refreshed every second;
  - "View Queue [N]" sits at the bottom right;
  - the output slots show only while filled;
  - the big button reads "Craft ×N" while nothing runs and "Queue ×N" while a job runs.
- The bar, the stop button and "View Queue" stay when the player picks another recipe, and on the details page.
- [Wireframes](https://claude.ai/artifact/DPCAU1Ynp26U52cNSNHLcN) (private).
- **Queue:**
  - crafts, enchants and upgrades are alike as queue items;
  - ingredients (and an enchant's target item) are taken when queued, and cancelling an entry returns them;
  - **no reordering**;
  - at most 5 entries for a start (the user, 2026-10-22);
  - **no automatic crafting of missing ingredients** (dropped: cancelling dependencies and races are risks; the
    details page is enough).
- **Recipe details:**
  - a page per recipe, enchant and upgrade;
  - one box per ingredient, with its source generated from the data (recipe, vendors, drops with level bands, herb
    zones);
  - item tooltips;
  - navigation only on this page ("Open ▸", "◂ Back"); a "select this recipe" button only for recipes the player
    knows;
  - group ingredients open a page of their kinds.
- **Unlocks:** unlocking a profession tier also unlocks, recursively, every Basic recipe that the tier's recipes
  need (Thread, then Patch Bolt).
- **Favorites:** a "Favorites only" checkbox next to "Craftable only" (both on shows craftable favorites only), and
  a bookmark icon at the top right of the recipe box (not on the details page); saved in player meta.
- **First step:** an automatic report of the recipe chain depth per recipe, to see where to simplify.

**Towns** (needs a map reset).
- **Lethariel, bough platforms:** remove the beam over the stair and the deck rail (on the deck-6 platforms the
  stair is impassable today, and the rail blocks the hall door).
- **Lethariel, royal guards:** no free wander; posts beside the king, at most 5 m away.
- **Core gatehouses** (five capitals, all but Kezamba):
  - a new inner stair from the ground to the first floor, in the chamber on the side where the roof stair does not
    end (the right side seen from outside), with a landing in its turn and never corner steps;
  - the doors move one node towards the passage, and the idle posts follow;
  - the deck opening grows from 3 to 4 nodes;
  - the two first-floor wall openings close.
- **Gate guards:** two counter-rotating rectangle patrols on the city side; the tower guard becomes a post
  (confirmed 2026-10-22).
- **Terrace stair off-by-one** in `dressing.terrace` (one tread short; every terrace with lift ≥ 2).
- **Waystone and mailbox** at the town centre next to the Quartermaster in the start towns. The capitals keep
  theirs in the core, which is enough (the user, 2026-10-22).
- The building fixes above (bough platforms, gatehouses) are made **in the templates** after this round, by the
  user in the editor or by a lane; the behaviour and algorithm fixes (royal guards, patrols, the terrace stair) in
  code.
- **The town workshop evening** with players stays a later idea (the tools come to main with VIEWER).
- **NPCs using doors** more visibly (goals inside buildings) is a candidate.

**Mining camps** (needs a map reset).
- **Placement:**
  - one camp in every T2, T3 and T4 zone except the capital zones: 20 camps (6 T2, 8 T3, 6 T4);
  - placed per seed by the placement rules, in the part of the zone whose level fits the room's depth.
- **Lift and room:**
  - a teleport lift with no shaft;
  - the room lies at the tier's lowest y + 50: −250 (T2), −450 (T3), −650 (T4); the mob levels there are about 15,
    27 and 39;
  - the room is written by the world generator (a deep-chunk hook before the rock-below early-out), never stamped at
    first use;
  - the room is protected, with exits into unprotected rock and no mob spawns inside.
- **Quest:** a fetch quest only ("go down and bring <tier material>"), no kill quest for now.
- **Factions** (the user, 2026-10-22): every camp belongs to a faction. A T4 camp in a contested zone belongs to
  the faction whose half of the continent it lies on (nearer that faction's capitals).
- **Lift access:** the lift works for members of the camp's faction only.
- **Guards:** a camp may spawn a few faction guards at the top level of its zone (40 in a 31–40 zone).
- **PvP:** the T4 room may lie in the PvP depth.

**Quest rework** (after QUESTMAP and QUESTIDEAS). The user's points, to plan from:
- a story thread from the capital on (level 15–20 at the latest);
- story quests marked apart from kill quests (marker and list colour);
- more story, less repetition, fewer dependencies (above all between kill quests);
- quest families across start towns;
- rewards that are not the requested items.
