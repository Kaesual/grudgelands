# Round 12 full farming family pass

Planning date: 2026-09-20  
Status: implementation plan only; no repository or runtime edits are authorized by this document.

## Outcome and boundary

Round 12 should replace the current one-shape-fits-all cultivated crop presentation with a complete family pass over all 17 shipped crops. It should preserve the current catalog, seed IDs, four logical stages, 200-second stage time, wet-soil pause/resume, ingredient economy, wild-source geography, and slow wild renewal. The package may give families different shapes and cultivated harvest cycles; it does not add new crops, seasons, fertilizer, random yield, pests, crossbreeding, light requirements, soil affinities, or farming progression.

The user has approved the family-specific cultivation model for the full
17-family pass:

- annual roots/grain are dug and replanted;
- fruiting bushes/vines regress and regrow after a non-destructive harvest;
- cane/bamboo retain a base while upper growth is harvested; and
- slow wild renewal remains separate and unchanged.

The matrix below is therefore authoritative planning scope, not a corn pilot or
a visual-only fallback.

No further player ruling is needed for source selection, exact nodeboxes within
the silhouettes below, or whether an internal helper is represented as a table
or function. Those are implementation and art-review choices. The recommended
interaction and reset behavior below implements the approved family categories
rather than creating seventeen further questions.

## Frozen invariants

These are existing accepted behavior or explicit Round 12 constraints:

- The stable identities remain `grug_farming:seed_<key>` and `grug_farming:<key>_1` through `_4` for the rooted/base node (`docs/design/world_zones.md:1699-1706`). Helper/upper nodes may be new internal IDs and must be hidden from Creative.
- Every planted crop starts at logical stage 1 and reaches stage 4 after three 200-second advances while its root soil is wet. Dry soil pauses exact partial progress and wet soil resumes it (`mods/ITEMS/grug_farming/init.lua:14-16,37-61,150-175`).
- **Immature destructive harvest remains deterministic and seed-only:** digging a stage-1/2/3 cultivated crop yields exactly one corresponding seed and no ingredient. This applies to the whole cultivated organism, including a blocked or partially formed tall plant. It is intentionally more forgiving than early Lord of the Test corn, which drops nothing (`reference_projects/Lord-of-the-Test/mods/lottfarming/corn.lua:14-69`).
- A mature annual destructive harvest returns exactly one ingredient plus one seed. The pass does not increase yield.
- For recommended regrowing crops, a normal mature harvest returns exactly one ingredient, keeps the rooted plant, resets it to the row's stated regrowth stage, and starts the same wet-soil timer. Digging the rooted plant remains the explicit removal path and returns one seed; if mature, it also returns the same one ingredient. No interaction duplicates a seed or ingredient.
- For stacked crops, the bottom node owns stage, timer, metadata, protection decisions, and drops. Upper nodes are non-owning helpers. Destructive segment removal resolves the whole organism once; the explicit
  mature upper-harvest action for retained cane/bamboo instead preserves the root. Placement, growth, harvest, and cleanup check every changed position for protection and loaded/replaceable state before mutating any node.
- A blocked next stage waits without consuming progress or damaging the blocker. It retries only through the owning node's ordinary bounded timer. It never forces emergence and never writes into unloaded space.
- Cultivated regrowth is not wild renewal. `grug_farming/ecology.lua` retains its current 4–8 real-hour observed-depletion replacement, per-cell debt, and global budgets (`docs/design/farming.md:32-63`). Cultivated/player-placed nodes never create renewal debt.
- Natural wild sources remain independent, single-position mapgen nodes with their existing one-item drops and habitat rules. The cultivated silhouette pass must not turn a wild source into a multi-node structure or change its density (`mods/MAPGEN/grug_mapgen/world_nodes.lua:1-23`; `docs/design/world_zones.md:1714-1739`).
- The separately approved food duration change is **180 to 300 seconds for every food status**, owned by the food/consumables lane. Farming tests should consume that public duration only if needed; farming must not duplicate food timing logic.

## Proposed 17-family matrix

“Regress” means a mature non-destructive harvest replaces stage 4 with the stated logical stage, preserves the root position, clears obsolete upper helpers atomically, and resumes growth only while wet. “Remove” means the existing dig/replant loop.

| Family | Cultivated silhouette across four stages | Approved mature cultivation behavior | Primary reference and adaptation |
|---|---|---|---|
| **Wild Grain** | Low shoots → denser upright blades → headed stalks → full waist-high grain clump; one node, crossed plant planes, stage-specific selection height. | **Remove/replant.** Dig gives 1 Wild Grain + 1 seed. | VoxeLibre wheat supplies the readable seedling-to-headed-grain progression and seed-only premature principle (`mcl_farming/wheat.lua:17-108`). Current licensed `x_farming` barley stages remain the first asset candidate. |
| **Carrot** | Tiny paired leaves → fuller low leaves → dense crown → mature leafy crown with only a restrained orange shoulder at soil level; one node. | **Remove/replant.** Root harvest should not remain visibly hanging above ground. | VoxeLibre carrot stages are the mechanics/shape reference (`mcl_farming/carrots.lua:20-127`); Hades parsnip/crop art is an additional low-root silhouette candidate. |
| **Cassava** | Sparse palmate sprout → taller leafy stem → branched waist-high plant → broad mature palmate canopy; one tall node, no visible inventory-root sprite. | **Remove/replant.** | Use the already cleared `x_farming` potato-derived stages only if they can be reworked into a palmate canopy; otherwise author project-owned stage art. Hades root crops do not specifically model cassava. |
| **Wild Onion** | Thin shoots → clustered leaves → bulb-leaf fan → dense fan with a small bulb shoulder; one low node. | **Remove/replant.** | Hades spice/parsnip and VoxeLibre root-crop silhouettes are conceptual references; current onion stages come from cleared `x_farming` beetroot treatment. Do not import a harvest icon as the world plant. |
| **Fire Pepper** | Small leafy sprout → branched bush → flowering/green-fruit bush → red-fruited bush; one node with increasingly broad selection box. | **Regrow.** Harvest stage 4 in place for 1 Fire Pepper, regress to stage 2. Digging removes the plant under the invariant above. | Hades Bell Pepper is the closest direct family reference (`hades_farming/register.lua:213-232` in release 0.20.2); current project-owned Fire Pepper harvest art stays distinct. |
| **Pumpkin** | Ground sprout → spreading vine → flowering vine → vine plus one substantial ground pumpkin occupying the rooted node's footprint; one nodebox/mesh, not an adjacent random fruit. | **Regrow.** Harvest the mature fruit, regress to stage 2. | VoxeLibre uses an 8-stage persistent stem that later produces adjacent fruit (`mcl_farming/pumpkin.lua:15-190`). Adopt the persistent-vine idea but keep the fruit inside one rooted footprint to avoid random-neighbor ownership and field expansion. LotT melon shows readable growing nodeboxes (`lottfarming/melon.lua:9-76`). |
| **Blightberry** | Low thorny/dark bush → leafy bush → sparse berries → dense dark berries; one bush node. | **Regrow.** Harvest stage 4, regress to stage 2. | VoxeLibre sweet berries explicitly harvest berries while keeping the bush and reset it to an earlier stage (`mcl_farming/sweet_berry.lua:5-21,36-77`). Use current color-graded berry stages or project-owned refinements. |
| **Sunberry** | Low dry-climate shrub → rounded bush → gold buds → bright mature berries; one bush node, warmer and more open than Blightberry. | **Regrow.** Harvest stage 4, regress to stage 2. | Same VoxeLibre retained-bush mechanic; distinct silhouette/color treatment is required so the three berries do not read as palette swaps. Hades Strawberry provides a separate compact-bush art candidate (`hades_farming/register.lua:192-211`). |
| **Jungle Berry** | Broad low leaves → lush bush → hanging green fruit → hanging saturated fruit; one wider bush node. | **Regrow.** Harvest stage 4, regress to stage 2. | Same retained-bush mechanic; use a broader tropical silhouette. Current `x_farming` strawberry-derived stages may seed the art pass but should not remain the sole geometry shared by all berries. |
| **Frost Melon** | Frost-tinted sprout → ground vine → flowering/frosted vine → squat icy melon nodebox within the root footprint. | **Regrow.** Harvest stage 4, regress to stage 2. | VoxeLibre melon/pumpkin persistent stems and LotT's expanding melon nodeboxes are the references. Keep one rooted footprint and deterministic one-fruit output; no adjacent-fruit search or random direction. |
| **Sugar Cane** | Root tuft → root + one upper segment → root + two upper segments → root + three upper segments; narrow upright helper nodes, maximum total height 4 nodes including root. | **Retained base.** Harvesting any upper segment of mature cane removes all harvestable uppers, returns exactly 1 Sugar Cane, and resets the root to stage 1. Digging the root removes the whole plant and returns the seed; mature root removal additionally returns 1 Sugar Cane. | VoxeLibre bamboo demonstrates top-only vertical growth and clearance (`mcl_bamboo/globals.lua:99-155`); existing papyrus-derived licensed art remains usable. This is cane behavior authored for Grudgelands, not copied from VoxeLibre. |
| **Bamboo Shoot** | Small shoot → taller shoot → two-node young stalk → three-node leafy stalk; maximum total height 3 nodes including root, visibly thicker/leafier than cane. | **Retained base.** Mature upper harvest returns exactly 1 Bamboo Shoot and resets the rooted shoot to stage 1; whole-root removal follows the invariant. | VoxeLibre bamboo is the direct vertical/top-growth reference (`mcl_bamboo/globals.lua:99-155`). We should reuse concepts and separately verify exact media if importing any asset; existing local papyrus-derived bamboo art is already licensed. |
| **Cave Cap** | Tiny cap → two-cap cluster → broad cluster → prominent multi-cap mushroom patch; one low node with family-specific selection box. | **Regrow.** Pick the mature caps for 1 Cave Cap, regress to stage 2; the underground mycelial base remains. | Current four authored Goblins mushroom textures are already cleared (`mods/ITEMS/grug_farming/LICENSE-media.md:13`). No extra darkness/stone rule is added to cultivation; those conditions remain wild-source geography only. |
| **Salt Crust** | Shallow brine/film → first crystals → clustered crystals → full crystalline crust; existing animated nodebox progression. It is explicitly not forced into a plant silhouette. | **Regrow special.** Scrape 1 Salt Crust from stage 4 and reset the same basin/crust to stage 1. Root removal returns its seed item; immature removal remains seed-only. | The current nodeboxes and `x_farming` salt media are already cleared (`grug_nodes/crop_visual.lua:11-28`; `grug_farming/LICENSE-media.md:10-11`). `x_farming:salt` confirms the evaporation-pool/crystal concept (`x_farming/salt.lua:21-152`). Keep Grudgelands wet-soil timing; do not import sunlight/random retry rules. |
| **Ember Moss** | Sparse glowing flecks → small mat → branching ember-red mat → broad luminous mat hugging the surface; one low plantlike/nodebox hybrid. | **Regrow.** Gather 1 Ember Moss, regress to stage 2. | Project-owned/cleared `x_farming`-derived stages are available. No Hades/VoxeLibre crop is a direct match. Cultivated moss remains ordinary wet-soil growth; emberrock/depth belongs only to the wild source. |
| **Potato** | Sparse leaves → compact foliage → flowering foliage → full low plant with subtle soil mound; one node. | **Remove/replant.** | VoxeLibre potato has eight logical stages but four visible silhouettes, a good model for a low root crop (`mcl_farming/potatoes.lua:3-105`). Hades Potato is another three-stage art candidate (`hades_farming/register.lua:171-190`). |
| **Corn** | Seedling → knee-high stalk → two-node stalk → three-node mature stalk with the cob visually concentrated in the upper/middle foliage; root plus owned helper nodes. | **Remove/replant.** Digging any segment resolves the whole mature plant once for 1 Corn + 1 seed. Immature whole-plant removal returns only 1 seed. | Lord of the Test is the actual pinned stacked-corn reference: it grows from one to two and then three nodes (`lottfarming/corn.lua:153-225`). `x_farming` is the source of current corn stage art and uses tall `visual_scale=2` single nodes (`x_farming/corn.lua:21-88`). VoxeLibre has no corn in the pinned checkout. |

This matrix deliberately gives mechanically similar rows a shared implementation profile. It does not require seventeen bespoke state machines:

- `annual_low`: Wild Grain, Carrot, Cassava, Wild Onion, Potato;
- `regrow_bush`: Fire Pepper, the three berries, Cave Cap, Ember Moss;
- `regrow_ground_fruit`: Pumpkin, Frost Melon;
- `regrow_special`: Salt Crust;
- `vertical_retained`: Sugar Cane, Bamboo Shoot;
- `vertical_annual`: Corn.

## Interaction contract

Use one consistent player action: right-click on a mature regrowing or retained-base crop invokes its node harvest callback. Verify item/node dispatch against the pinned engine; items that consume right-click themselves keep their existing action, and must not also trigger harvest. Sneak-right-click bypasses crop harvest and preserves ordinary held-item/node interaction. Destructive dig remains whole-plant removal. This matches the legibility of VoxeLibre berry picking without importing its thorn/liquid tricks (`mcl_farming/sweet_berry.lua:70-83`).

Destructive root/helper removal uses a custom `on_dig` transaction (or an
engine-verified equivalent pre-dig gate). `after_dig_node` is too late: the
clicked segment would already be gone before root protection is checked.
Helper nodes have no independent engine drop. Test an unprotected upper segment
whose root is protected: neither node nor any inventory/drop may change.

The implementation must call `core.is_protected` for every node it will change. It computes a complete mutation plan first, refuses on any protected, unloaded, occupied, or foreign helper position, then applies the plan. Drops are emitted only after the mutation succeeds. Creative suppresses inventory drops/seed consumption consistently with existing planting behavior.

For multi-node plants, helper definitions carry root offset and family/stage metadata but no timer and no independent drop. A helper interaction resolves and validates the root. Missing or mismatched helpers never cause unrelated nodes to be removed. Because fresh-server mode forbids legacy cleanup, only current-version integrity handling is allowed: normal activation may reconstruct missing expected helpers only into loaded, unprotected, replaceable positions; otherwise it leaves the owner at the last complete stage or safely regresses it. No broad LBM scan is introduced.

## Reference findings and source policy

### Pinned local sources

- **VoxeLibre `c2dbc520...`**: useful for wheat/root stage readability, retained berry picking, persistent melon/pumpkin stems, cocoa attachment, and vertical bamboo clearance. Its pinned tree has no corn/maize implementation. Code is GPL-3.0-or-later in the farming area and media defaults are CC BY-SA with per-file verification required; current repository research records the relevant scope at `docs/research/plants-and-potions-reference.md:353-367`.
- **Lord of the Test `f1641401...`**: the direct true stacked-corn reference. Its early corn nodes have empty drops, while mature upper nodes probabilistically drop corn and seeds; copy neither drop policy nor its ABM structure. Its shipped reference license/media facts must be checked per selected asset before import.
- **x_farming `ac5f69d5...`**: current source for most of the 68 cultivated stage textures and all current corn stages. Its code headers are LGPL-2.1-or-later and the already imported media is recorded as CC BY-SA 4.0 with per-file exceptions in `mods/ITEMS/grug_farming/LICENSE-media.md`. It provides the salt evaporation/crystal nodebox concept and tall single-node corn.
- **Goblins `ce27b15f...`**: current source for the four Cave Cap mushroom stages, already recorded as CC BY-SA 3.0.

### Hades Revisited external research

The reviewed artifact is ContentDB **Hades Revisited 0.20.2**, release 35045, dated 2026-02-16, downloaded read-only to `/tmp`; archive SHA-256 `332108fbedea5ea74f226c3bdae0ebfe2087d80f6252b06a63c6b2cc0bfa2d6e`. The project website and archive license state code **LGPL-2.1-or-later** and general media **CC BY-SA 3.0**, with exceptions listed by mod. The archive's `LICENSE.txt:14-20,28-42` is the local evidence; the public project page is `https://wuzzy.codeberg.page/Hades_Revisited/`.

Its farming catalog includes Wheat, Rice, Cotton, Cabbage, Parsnip, Tomato, Potato, Strawberry, Bell Pepper, and Spice, each registered as a generic three-step plant (`mods/hades_farming/register.lua` in that archive). `register_plant` builds plantlike stages with probabilistic seed/harvest drops and runs one ABM per family with wet-soil, light, and season checks (`mods/hades_farming/api.lua:136-231,265-345`). This is not a stronger runtime basis than Grudgelands' current exact node timers and pause/resume metadata.

**Recommendation:** use Hades as a visual/reference candidate for Carrot/Onion/root foliage, Fire Pepper, berry shrubs, and possibly Wild Grain. Do not import its farming API, seasonal death, ABMs, random yields, or food rules. Do not add it to `reference_projects/` merely because it was inspected. If implementation selects even one Hades code/media file, first add a deliberately pinned read-only Hades Revisited reference under the project procedure, list it in `docs/reference_projects.md`, verify the exact file's author/license rather than relying only on the game's general license, and record every shipped derivative in the owning `LICENSE-media.md`. If no Hades bytes are selected, cite the release only in the Round 12 research/evidence note and add no permanent submodule.

## Implementation architecture and ownership

One coherent farming package should own these files:

- `mods/ITEMS/grug_farming/init.lua`: family profile consumption, owner/helper lifecycle, harvest interaction, atomic mutation planning, drops, and existing timer integration.
- `mods/ITEMS/grug_farming/crop_profiles.lua` (new, recommended): pure 17-row gameplay profile table with one of the six profile kinds above, height per stage, regrowth stage, and helper layout. It must not contain world/mapgen geography.
- `mods/ITEMS/grug_nodes/crop_visual.lua`: pure visual builder extended to consume a family geometry profile or context without learning timers/drops/protection.
- `mods/MAPGEN/grug_mapgen/world_nodes.lua`: adapt only the call boundary needed to request a **wild single-node** mature visual; no population or drop changes.
- `mods/ITEMS/grug_farming/textures/` and `LICENSE-media.md`: only selected/reworked stage/helper assets and exact provenance.
- `tools/r12_farming/`: focused pure fixtures and visual sheet scripts. Reuse shared mocks from `tools/r10_farm` where practical; do not rewrite the old oracle around the new implementation.
- `docs/design/farming.md`: record the approved family profile/harvest rules. `docs/design/world_zones.md` changes only if its current identity wording needs the helper-node clarification; geography remains byte-stable.
- `docs/research/round12-farming-evidence.md`: source pins, chosen assets, visual plates, test evidence, model/review calibration.

Frozen public interfaces:

- Preserve `grug_farming.CROPS`, each row's `key`, `seed`, `stages`, `stage_count`, `stage_seconds`, `harvest_item`, and `seed_source` fields for existing consumers and tests.
- Preserve `grug_nodes.crop_visual(key, stage, sounds)` for existing callers or extend it with one optional final context argument whose omitted behavior remains the current single-node form. The preferred explicit calls are `context = "cultivated"` and `context = "wild"`; wild must always return one self-contained definition.
- Keep `grug_mapgen:<key>_source` identities and wild drops unchanged.
- Do not change `grug_cooking.PLANTS`, ingredient tiers, recipes, seed conversion recipes, or ecology storage schema.

The food-duration edit belongs in `mods/ITEMS/grug_food/init.lua` and its focused tests/docs, preferably as a separate small commit/lane because it does not depend on crop topology. Its accepted value is `grug_food.DURATION = 300`.

## Acceptance criteria

1. A machine-readable census reports exactly 17 root families, four logical stages each, and a declared profile kind for every row; no silent generic fallback exists.
2. Every stage has a family-appropriate effective geometry and selection box. An enlarged 17 x 4 plate plus in-world stage-1/stage-4 captures demonstrate that roots, grain, bushes, ground fruits, vertical crops, mushroom, salt, and moss are distinguishable without inventory labels.
3. All 17 preserve exact wet growth, dry pause, reload resume, seed planting, seed conversion, and protection checks.
4. Digging any immature organism at stages 1-3 returns exactly one seed and zero harvest items, including every partial height of Corn, Sugar Cane, and Bamboo.
5. Annual mature harvest returns exactly one ingredient and one seed and removes every owned segment exactly once.
6. Each regrowing/retained crop's mature harvest returns exactly one ingredient, no seed, resets to the specified stage, and resumes only on wet soil. Root removal remains deterministic and duplication-free.
7. Multi-node growth refuses blocked, unloaded, protected, or foreign-node space without consuming progress or partially mutating. Digging/harvesting any helper resolves the correct owner once. Missing or forged metadata cannot remove an unrelated node.
8. Wild source identities, positions, density predicates, one-item drops, ecology debt, and renewal budgets are unchanged. A digest/census over the source catalog proves this boundary.
9. Creative shows seeds and harvested ingredients but hides all stage/helper nodes. Inventory items and Cooking recipes remain unchanged.
10. The selected art has complete source hashes, author, license, transformation, and destination rows. No Hades asset ships without a permanent pinned reference and per-file verification.
11. `grug_food.DURATION` is 300 seconds in the separate food slice, with status replacement and 5-second tick cadence otherwise unchanged.
12. One focused user runtime walk checks all 17 mature forms, tall-plant obstruction/protection, regrowing harvest interaction, seed-only premature harvest, Creative visibility, and wild-source appearance.

## Test budget for this session

Planning and implementation must follow the explicit Round 12 session override: **no PUC runtime and no broad/exhaustive suites**. This does not relax Lua 5.1 source compatibility.

- Run `tools/bin/luac51 -p` on every changed Lua file.
- Run SETGLOBAL inspection and all five required static Lua 5.1 sweeps on the changed production scope.
- During development, run one focused LuaJIT family-lifecycle KAT covering the six shared profile kinds, then the exact 17-row census.
- On frozen bytes, run one targeted LuaJIT integration KAT covering all acceptance criteria that can be modeled without the engine. Do not run PUC runtime parity, fixed-layout populations, seed fleets, full VM populations, retired suites, or unrelated Round 10/11 gates under this session override.
- Run a cheap asset/provenance/hash check and generate the visual plates once after final art selection.
- Boot the game once for registration/startup errors if the package reaches implementation; the user's GUI runtime pass remains the visual and interaction acceptance gate.
- Obtain the mandatory independent strong-agent review of the final non-trivial diff. The reviewer inspects the frozen LuaJIT/static evidence and does not create a second test fleet.

The focused KAT should cover protection and transaction failure by mutation injection: reject second/third helper placement, fail a harvest mutation before commit, forged helper/root relation, blocker introduced between plan and commit, dry/wet timer transition, and repeated helper dig. These are the high-risk behaviors introduced by the full family pass.

## Recommended package order

1. Record the approved family-specific cultivation ruling in `docs/design/farming.md` and freeze this matrix.
2. Implement pure family profiles and visual geometry while preserving the current lifecycle; generate the first 17 x 4 review plate.
3. Add shared whole-organism ownership/atomic mutation helpers and vertical Corn/Cane/Bamboo.
4. Add shared regrowing harvest behavior for bushes, ground fruits, mushroom, moss, and salt.
5. Integrate final art/provenance, rerun the focused LuaJIT/static gates, and complete independent review.
6. User runtime-tests the 17-family field. Corrections stay within silhouettes, selection boxes, and the approved profile semantics.

The package should remain one farming WP because the visual profiles and lifecycle profiles share the same 17-row authority. Internally, art/geometry and lifecycle can be separate commits or non-overlapping implementation lanes, but one coordinator must integrate them before review so wild/cultivated context and helper ownership are assessed together.
