# TODO — Round 8 (proposal for the user's ruling): mapgen iteration, profession framework, Cooking and Alchemy v1, mob wave 1

Rough plan of 2026-09-18 (morning) rewritten on 2026-09-18 (evening) after
Round 7 delivered its plans (`docs/research/cooking-alchemy-plan.md`,
`docs/research/mob-worlds-plan.md`, `docs/research/plants-and-potions-reference.md`)
and the user answered with the rulings in §1. **This is a proposal; the user
rules before the first lane starts.** Goal of Round 8 stays: Cooking and
Alchemy exist in a first complete version on a world whose plants, soils
and shores support them, plus the first mob wave; the foundations are
built so that play-evening feedback becomes data changes, not rework.

Working rules as in rounds 5–7 (Codex GPT-5.6 Sol implements and reviews,
the orchestrator runs every gate, `--no-ff` merges, sync only through
`tools/sync_to_luanti.sh`, push only on the user's word; mechanics and
pitfalls in `docs/process/cross-cli-orchestration.md`).

## 1. User rulings of 2026-09-18 (evening) that shape this round

- **R8.1 Reference projects.** `x_farming` (pinned `ac5f69d5`) and
  `farming` (pinned `1a918c7a`, with the deny-list in
  `docs/reference_projects.md`) are reference submodules. Assets are
  imported only with a per-file allow-list row in `LICENSE-media.md`.
- **R8.2 Recipe books are UI, not items.** Learning a profession at a
  trainer unlocks its book; the book takes no inventory slot. It is shown
  as a button in the player's crafting UI (VoxeLibre-style book icon) and
  inside every station UI. `items_crafting.md` §2.2's "one book item per
  profession" is superseded.
- **R8.3 The book is open from the start**; recipes are gated by
  profession level, and a recipe of tier N uses at least one tier-N
  ingredient and may use lower-tier ingredients. Recipes grow stronger
  with the profession level. (The ingredient-based tier unlock of
  `items_crafting.md` §3.7 and the keystone unlock of §2.3 are superseded
  for Cooking; §4 below asks how far this reaches for the other
  professions.)
- **R8.4 Trainers.** Every start town has exactly one profession trainer
  (Cooking). Every capital has one trainer per profession. Learning a
  profession unlocks its book.
- **R8.5 Where recipes are made.** Cooking recipes are crafted in the
  normal crafting UI (grid) with the cooking book beside it. Some steps are
  station-only: the furnace refines raw ingredients (raw meat → cooked
  meat), and the book lists such recipes with a "furnace" hint. The
  reverse pattern (an assembled raw dish that must be cooked in the
  furnace and is inedible raw) is allowed too. The same model serves the
  other professions later: a Blacksmith crafts most items in the grid
  (sharpened sword = sword + 2 flint), ingots come from the furnace or
  dual furnace.
- **R8.6 Alchemy** uses a VoxeLibre-style brewing stand: trainer and stand
  stand in every capital; the player can craft the stand later for
  housing.
- **R8.7 Mapgen wishes.** Sand mainly near water; more block variety
  below the surface (today mostly stone); the land-to-ocean transition
  mixed (cliffs and sand beaches instead of cliffs everywhere); cliffs not
  always vertical; the Highcourt centre hedge/wall must not be broken by
  placed centre content (all capitals checked).
- **R8.8 Creative details** of the cooking, alchemy and mob plans are the
  orchestrator's call; the user gives feedback after the playtest. Speed
  and clean foundations over perfection.

## 2. Orchestrator choices on the open plan decisions (R8.8)

Taken as the plans' defaults unless the user objects: instant HP and
dish regeneration per tier as in the cooking plan §2; three role lines
(Hearty = tank, Caster, Hunter); mana regeneration **option A** (in-combat
floor 0.25 %/s of the pool); the plant list of cooking plan §3.2 in full;
Greater potions with a 45 s cooldown; potions stay at the decided 30 %;
**raw tier = the level band of the lowest zone where the item grows**
(apple T1, mushroom T3, melon T1) so raw finds are edible where found;
night density 1.25×; Giant Rat as the universal band-1 night family;
dragons Ice Dragon → Wyrmglass, Jungle Wyvern → Stormscale; the repo-wide
MIT reading for animalia and draconis as already used for Stag and Gull;
mob packages 1–5 as the round's goal, 6–8 rolling.

## 3. Lanes, in dependency order

### R8-MAP-A — terrain: coast profiles, sand, subsurface (first, riskiest)

`mods/MAPGEN/grug_mapgen/wp40/` (R5/R6/R7 passes; deterministic, integer).

1. **Coast profiles.** Each coast segment (deterministic per shore run,
   seeded from zone id + segment index) gets one of four profiles:
   *beach* (sand slope 1:4 to 1:8 down to `water_y`, sand band 4–10 nodes),
   *bluff* (steep slope 1:1 to 2:1, gravel/stone with dirt lip),
   *cliff* (vertical, as today, but with an irregular top edge and
   occasional ledges), *terraced cliff* (two or three 3–5-node steps).
   Target mix on ordinary coast: about 40 % beach, 25 % bluff, 20 % cliff,
   15 % terraced; functional edges (bridges, causeways, fords, route decks,
   culverts) and the Round 6 bank rule (bank at `water_y`) stay exempt and
   unchanged. Freshwater shores (lakes, rivers) get beach or bluff only.
2. **Sand near water.** Sand (with sandstone under it) along every dry
   shore in the beach band, thin sand lips on freshwater; no sand away
   from water except the existing `grug_beach` palette. Sand is the
   furnace's glass input.
3. **Subsurface variance.** Below the top soil, per-zone strata in the
   first 40 nodes: dirt pockets, gravel lenses, clay under wetlands, a
   secondary stone per palette (e.g. sandstone under savanna, basalt
   seams under badlands, limestone under meadows, slate under pine hills,
   mossy stone under jungle), placed as deterministic blobs and bands.
   Ores, the depth strata (Basalt −301 …) and cave carving are untouched.
4. Contract updates (`world_zones.md` §7.4/§7.6 coast rules), fixture
   refresh, the final micro pair, the six-start gate and the six capitals
   after the merge.

### R8-MAP-B — surface content: soils, plants, reeds, settlement rings

1. **Plant placement P9G-2**: version the P9G tail from the closed
   twelve-name schema to an open manifest (`r7_p9g.lua` schema bump), add a
   cave-air host mode, and place the cooking plan's plants: wild grain,
   carrot/cassava, wild onion/fire pepper, pumpkin, the three Throng berry
   bushes, frost melon, sugar cane (shore sand, all palettes), bamboo
   (jungle-edge/deep-jungle/swamp shores), cave cap (−100 … −500), ember
   moss (≤ −701), salt crust and stormkelp in The Shattered Line, mushroom
   in Speargrass Reach. Assets from the allow-lists (VoxeLibre,
   `x_farming`, `farming` minus deny-list), each with a `LICENSE-media.md`
   row.
2. **Second soil per zone** and tilled crop soil at village fields
   (scenery until WP32).
3. **Settlement ring continuity**: the capital centre hedge/wall is a
   protected ring; placed centre content (houses, sockets, decor) must not
   cut it. Fix the placement order or the conflict rule, verify all six
   capitals and the six starts (the user saw the gap in Highcourt).
4. Contract, fixtures, final micro, six-start gate, six capitals.

### R8-PROF — profession framework (the foundation the user asked for)

`mods/PLAYER/grug_jobs` (new or extended) plus UI:

1. **Recipe registry**: `grug_jobs.register_recipe{profession, tier,
   station = "grid" | "furnace" | "dual_furnace" | "brewing_stand", inputs,
   output, hint}`; a tier-N recipe must name one tier-N ingredient
   (validated at load). Station recipes are registered with the engine
   (`core.register_craft` cooking) and mirrored in the book with the hint.
2. **Profession state**: learn at a trainer (two mains + universal
   Cooking); **profession level** per profession as a clean seam
   (`grug_jobs.profession_level`), v1 rule: rises with crafts of the
   current tier (n crafts of tier N open tier N+1, capped by the
   character's tier band `items_crafting.md` §3.0.1), stored in player
   meta; recipes above the profession level are greyed with the
   requirement.
3. **Book UI**: a book button in the player's crafting page (sfinv) and in
   every station formspec; tabs per profession the player knows; rows show
   ingredients, station hint, tier, level requirement.
4. **Trainers**: NPC role "profession trainer" (Cooking in every start
   town's trainer socket; one per profession in every capital, using the
   existing settlement sockets; the Alchemist trainer stands next to the
   capital brewing stand). Reuses `grug_traders`/start-villager NPC
   plumbing; no new mesh.
5. Docs: `items_crafting.md` §2.2/§2.3/§3.7, `professions.md` §1 rewritten
   for R8.2–R8.5; KATs for registry validation, level gating, book
   formspec geometry, trainer sockets.

### R8-COOK — Cooking v1 (after MAP-B and PROF)

The dish tables of `cooking-alchemy-plan.md` §4 as data: six tiers × three
role lines, furnace refinement recipes (raw meat/fish/grain → cooked
meat/fish/bread) listed with the furnace hint, one "raw dish → furnace"
recipe per tier as the reverse pattern, tooltips per the R7-FOOD format,
raw tiers per §2, Cooking Fire retired in favour of the grid (R8.5);
`grug_food` tier data and role modifiers filled; KAT rows per tier.

### R8-ALCH — Alchemy v1 (after PROF)

Brewing stand node and UI (fuel + reagent + vials, mechanics ours,
VoxeLibre as orientation), potions T1–T3 and elixirs T3–T6 from the plan
§5 as data, the herb authorizer hooked to the Alchemist profession, stand
craftable from a T3 recipe for housing, Alchemist trainer in every
capital; KATs for cooldown sharing, elixir exclusivity, stacking with food.

### R8-MOB1 — mob wave 1 (parallel to COOK/ALCH; packages of the mob plan §9)

1. Clock roles and fallbacks (no assets); 2. zero-asset variants; 3. start-
zone day and night families; 4. night families 11–40; 5. dragons and kings.
Rolling 6–8 (underground, deep, front and coast) as long as the round
runs. Each package: registrations, spawn rows, `LICENSE-media.md` rows,
KAT, headless boot.

### R8-DOCS — documentation alignment at the end, as in rounds 5–7.

## 4. Decisions for the user before the first lane

1. Lane cut and order as above (MAP-A, MAP-B, PROF, then COOK/ALCH/MOB1 in
   parallel, DOCS last), or MAP-A and MAP-B as one lane.
2. Profession level v1 rule (crafts of the current tier open the next,
   capped by the character band) or a simpler "profession level =
   character level".
3. R8.3's reach: the book-open-from-the-start rule and the profession-level
   gate replace keystones for **all** professions (then `items_crafting.md`
   §2.3 keystones retire), or only for Cooking now.
4. The furnace patterns: refine raw ingredients only, or also the reverse
   "raw dish → furnace" (the proposal ships one of each per tier).
5. The §2 defaults (any objection).
6. Coast profile mix and the four profile shapes (§3 MAP-A).
7. Which mob packages Round 8 must reach (proposal: 1–5).

## 5. Explicitly not in Round 8

Blacksmith, Tailor, Leatherworker, Woodcarver, Goldsmith recipes (the
framework is built, their catalogs follow in Round 9 using it), enchant
rolls (WP5), Scout, Nether content, farming as a player activity (WP32),
housing (WP24), mounts (WP31).

## 6. Playtest 11 (after Round 8, fresh world)

Walk one start zone to its capital: coast profiles, sand, subsurface
variety, plants; learn Cooking at the start trainer, open the book in the
crafting UI, cook one dish per reachable tier (grid and furnace); learn
Alchemy in the capital, brew a potion and an elixir; a night in a zone
with a new night family; a king fight; the buff list under food plus
elixir; the capital hedge ring intact.
