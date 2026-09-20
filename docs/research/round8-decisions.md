# Round 8 historical decisions

> **Historical archive:** This file preserves the Round-8 rulings and execution
> plan as written. Current authority lives in `docs/design/`, BACKLOG and the
> active execution record. Old lane, model, CLI, approval and gate instructions
> below are not current process instructions.

Rough plan of 2026-09-18 (morning), rewritten as a proposal in the evening
after Round 7 delivered its plans, and **decided with the user on
2026-09-18 (late evening)**: the lane cut is the orchestrator's, the open
questions of the proposal are ruled below. Goal: Cooking and Alchemy exist
in a first complete version on a world whose plants, soils and shores
support them, plus the first mob wave; the foundations are built so that
play-evening feedback becomes data changes, not rework. Feedback on the
creative details comes from the user after playtests, not before.

**Closed 2026-09-19.** Round 8 delivered MISC (`fbcf8ed2`), PROF
(`e1bdb6af`), TAGS (`12886ada`), MOB1 (`8bc5c7e2`), COOK (`817b6c4e`),
HEDGE (`17a56f7c`), FIXTURE (`974a2660`), ALCH (`b69eeb64`) and MAP-A
(`1e165a0a`). MAP-B moved unchanged to Round 9; the Bog Witch was deferred
because its candidate mesh has unusable animation frames, and Sovereign's
Flask remains pending. Review follow-ups carried forward are a real
`r7_manifest.new` receipt in the resource micro-fixture and the one-voxel cave
writer exactness deviation; the proposed foreign-mod profession registrar was
explicitly not added under the decided ownership rule. These and the remaining
content work are tracked in the orchestrator's
[Round 9 record](round9-decisions.md).

Inputs: `docs/research/cooking-alchemy-plan.md`,
`docs/research/mob-worlds-plan.md`,
`docs/research/plants-and-potions-reference.md`,
`docs/research/mob-candidates-evidence.md`, `docs/reference_projects.md`
(`x_farming` and `farming` with its deny-list).

Working rules as in rounds 5–7 (Codex GPT-5.6 Sol implements and reviews,
the orchestrator runs every gate, `--no-ff` merges, sync only through
`tools/sync_to_luanti.sh`, push only on the user's word; mechanics and
pitfalls in `docs/process/cross-cli-orchestration.md`).

## 1. User rulings of 2026-09-18 that shape this round

- **R8.1 Reference projects.** `x_farming` (pinned `ac5f69d5`) and
  `farming` (pinned `1a918c7a`, deny-list in `docs/reference_projects.md`)
  are reference submodules. Assets are imported only with a per-file
  allow-list row in `LICENSE-media.md`.
- **R8.2 Recipe books are UI, not items.** Learning a profession at a
  trainer unlocks its book; the book takes no inventory slot. It is shown
  as a button in the player's crafting UI (VoxeLibre-style book icon) and
  inside every station UI. `items_crafting.md` §2.2's "one book item per
  profession" is superseded.
- **R8.3 Book open from the start, gated by profession level.** A learned
  book shows all its recipes at once; a recipe is craftable when the
  profession level reaches its tier. A recipe of tier N uses at least one
  tier-N ingredient and may use lower-tier ingredients. Recipes grow
  stronger with the profession level. **Profession level v1:** a fixed
  number of crafts of the current tier opens the next tier, capped by the
  character's tier band (`items_crafting.md` §3.0.1). This replaces the
  keystone unlock of §2.3 and the ingredient unlock of §3.7 for every
  profession (the catalogs of the other professions follow in Round 9 on
  the same rule).
- **R8.4 Item level gates stay separate.** Crafting and consuming are two
  gates: a level-19 cook may craft level-20–30 food but cannot eat it; the
  consumable's `_grug_ilvl` (R7.4) is the use gate because of the heal and
  buff strength.
- **R8.5 Book slots and profession classes.** Primary professions
  (Blacksmith, Alchemist, Tailor, Leatherworker, Woodcarver, Goldsmith):
  exactly two per character. Secondary professions (today only Cooking):
  every player may learn all of them. The crafting UI shows **two primary
  book slots** (empty until learned) and **one secondary book slot per
  existing secondary profession** (empty until learned), plus a **general
  recipe book** for everything not profession-bound, open from the start.
- **R8.6 Trainers.** Every start town has exactly one profession trainer
  (Cooking). Every capital has one trainer per profession (the Alchemist
  trainer stands next to the capital brewing stand).
- **R8.7 Where recipes are made.** Profession recipes are crafted in the
  normal crafting grid with the book beside it; there is no Cooking Fire.
  The furnace is a refinement station: raw ingredients become cooked
  ingredients there (raw meat → cooked meat), and the book lists such
  recipes with a "furnace" hint. The reverse pattern is wanted too: a raw
  assembled dish (vegetables + raw meat, inedible) that must be cooked in
  the furnace to become the edible dish. The same model serves the other
  professions later (Blacksmith: most items in the grid, ingots in the
  furnace or dual furnace).
- **R8.8 Alchemy** uses a VoxeLibre-style brewing stand: trainer and stand
  in every capital; the player can craft the stand later for housing.
- **R8.9 Fishing is not a profession.** Everyone fishes; fish loot tables
  may depend on the zone level. Fishing works on any water surface, salt
  or fresh; every zone palette has ponds or rivers and the outer zone
  columns border the sea, so every level band reaches water.
- **R8.10 Mapgen wishes.** Sand mainly near water; more block variety
  below the surface; land-to-ocean transitions mixed (cliffs and beaches);
  cliffs not always vertical; the capital centre hedge/wall must not be
  broken by placed centre content (seen in Highcourt); **caves must reach
  the surface more often**: today entrances are sparse hillside tubes
  (`world_zones.md` §7.6: 192-node cells, quarter gate, uphill rise ≥ 6,
  closed ends allowed, no guaranteed connection to native caves), so the
  surface needs more holes, on hillsides and as pits on flat ground, that
  connect to the existing caves.
- **R8.11 Creative details** of the cooking, alchemy and mob plans are the
  orchestrator's; the §2 choices stand. Speed and clean foundations over
  perfection.

## 2. Orchestrator choices on the plans' open decisions (approved)

Instant HP and dish regeneration per tier as in the cooking plan §2; three
role lines (Hearty = tank, Caster, Hunter); mana regeneration option A
(in-combat floor 0.25 %/s of the pool); the plant list of cooking plan §3.2
in full; Greater potions with a 45 s cooldown; potions stay at the decided
30 %; raw tier = the level band of the lowest zone where the item grows
(apple T1, mushroom T3, melon T1); night density 1.25×; Giant Rat as the
universal band-1 night family; dragons Ice Dragon → Wyrmglass, Jungle
Wyvern → Stormscale; the repo-wide MIT reading for animalia and draconis as
already used for Stag and Gull; mob packages 1–5 as the round's goal, 6–8
rolling; the four coast profiles and their mix of §3.

## 3. Lanes, in dependency order (lane cut: orchestrator's decision)

Merge order (re-cut 2026-09-18): PROF, then COOK, ALCH, MOB1, TAGS, MISC,
HEDGE in parallel; MAP-A, then MAP-B (or Round 9); DOCS last. Every lane: own
worktree under `.claude/worktrees/r8-<lane>`, own port block, KAT plus
mutation for every behavioural change, independent review, orchestrator
gates; mapgen lanes additionally the final micro pair, the six-start gate
and the six capitals after the merge.

### R8-MAP-A — terrain: coast profiles, sand, subsurface, cave mouths

`mods/MAPGEN/grug_mapgen/wp40/` (deterministic, integer).

1. **Coast profiles.** Each coast segment (deterministic per shore run,
   seeded from zone id + segment index) gets one of four profiles:
   *beach* (sand slope 1:4 to 1:8 down to `water_y`, sand band 4–10 nodes),
   *bluff* (steep slope 1:1 to 2:1, gravel/stone with a dirt lip),
   *cliff* (vertical, with an irregular top edge and occasional ledges),
   *terraced cliff* (two or three 3–5-node steps). Target mix on ordinary
   sea coast about 40 % beach, 25 % bluff, 20 % cliff, 15 % terraced;
   freshwater shores beach or bluff only. Functional edges (bridges,
   causeways, fords, route decks, culverts) and the Round 6 bank rule
   (bank at `water_y`) stay exempt and unchanged.
2. **Sand near water.** Sand with sandstone beneath along every dry shore
   in the beach band, thin sand lips on freshwater; no sand away from
   water beyond the existing `grug_beach` palette. Sand is the furnace's
   glass input.
3. **Subsurface variance.** Below the top soil, per-zone strata in the
   first 40 nodes: dirt pockets, gravel lenses, clay under wetlands, a
   secondary stone per palette (sandstone under savanna, basalt seams under
   badlands, limestone under meadows, slate under pine hills, mossy stone
   under jungle), as deterministic blobs and bands. Ores, the depth strata
   (Basalt −301 …) and cave carving stay untouched.
4. **Cave mouths.** Denser hillside entrances (smaller cells, higher
   candidate gate) plus **sinkholes on flat ground** (a shaft or funnel
   down to native cave air where a cave passes within a bounded depth
   below the surface), and every mouth **connects**: the tube extends
   until it meets native cave air or is rejected; closed ends are no
   longer valid. Start protection aprons, routes, settlements, water and
   functional surfaces stay excluded. A KAT counts mouths per zone and
   proves connection on the fixture seeds.
5. Contract updates (`world_zones.md` §7.4/§7.6), fixture refresh, final
   micro pair, six-start gate, six capitals after the merge.

### R8-MAP-B — surface content: plant placement, soils, crop soil (placement only; may slip to Round 9)

**Re-cut 2026-09-18 (user's green light):** MAP-B runs strictly after
MAP-A (both refresh the WP40 fixture pins). R8-COOK no longer waits for it:
COOK defines the new plants as items with tiers and recipes, MAP-B only
places them in the world (P9G-2), adds the second soils and the crop soil.
The Highcourt hedge-ring fix moved to its own mini-lane R8-HEDGE (WP13
code, runs in parallel now). **Decided 2026-09-18 evening: MAP-A's review demanded a large fix round,
so MAP-B moves to Round 9 unchanged**; Playtest 11 uses the new ingredients
from the creative inventory until then.


1. **Plant placement P9G-2**: version the P9G tail from the closed
   twelve-name schema to an open manifest (`r7_p9g.lua` schema bump,
   `:103-115`), add a cave-air host mode, and place the cooking plan's
   plants: wild grain, carrot/cassava, wild onion/fire pepper, pumpkin,
   the three Throng berry bushes, frost melon, sugar cane (shore sand,
   all palettes), bamboo (jungle-edge/deep-jungle/swamp shores), cave cap
   (−100 … −500), ember moss (≤ −701), salt crust and stormkelp in The
   Shattered Line, mushroom in Speargrass Reach. Assets from the
   allow-lists (VoxeLibre, `x_farming`, `farming` minus deny-list), each
   with a `LICENSE-media.md` row.
2. **Second soil per zone** and tilled crop soil at village fields
   (scenery until WP32).
3. ~~Settlement ring continuity~~ → moved to R8-HEDGE (below).
4. Contract, fixtures, final micro, six-start gate, six capitals.

### R8-PROF — profession framework (the foundation)

`mods/PLAYER/grug_jobs` (new or extended) plus UI.

1. **Recipe registry**: `grug_jobs.register_recipe{profession, tier,
   station = "grid" | "furnace" | "dual_furnace" | "brewing_stand", inputs,
   output, hint}`; a tier-N recipe must name one tier-N ingredient
   (validated at load); grid recipes are registered with the engine only
   for players whose book allows them (craft permission check in the
   crafting callback), station recipes are engine recipes mirrored in the
   book with the station hint. A general book collects every
   non-profession recipe.
2. **Profession state**: primary (two slots) and secondary (all) classes;
   learn at a trainer; **profession level** as a clean seam
   (`grug_jobs.profession_level`), v1 rule: n crafts of the current tier
   open tier N+1 (n per tier as a data table), capped by the character's
   tier band; stored in player meta; recipes above the level are greyed
   with the requirement; item use gates stay `_grug_ilvl` (R8.4).
3. **Book UI**: the crafting page shows two primary book slots, one slot
   per secondary profession and the general book; a slot opens the book
   view (rows: ingredients, station hint, tier, level requirement); every
   station formspec (furnace, dual furnace, brewing stand) carries the
   same button. Formspec-geometry KAT rows like Round 7's layout KAT.
4. **Trainers**: NPC role "profession trainer" on the existing settlement
   sockets (Cooking in every start town, one per profession in every
   capital); reuses `grug_traders`/start-villager NPC plumbing, no new
   mesh; learning a primary profession beyond two slots is refused with a
   message; unlearning per `professions.md` §1.
5. Docs: `items_crafting.md` §2.2/§2.3/§3.7, `professions.md` §1
   rewritten for R8.2–R8.7; KATs for registry validation, tier-ingredient
   rule, level gating, slot rules, book geometry, trainer sockets.

### R8-COOK — Cooking v1 (after PROF; decoupled from MAP-B on 2026-09-18)

COOK also registers the cooking plan's new plants as items (tier, texture
with licence row, food/raw rule) so the recipe ladder is data-complete
before MAP-B places them; it must not move any WP40 fixture pin.

The dish tables of `cooking-alchemy-plan.md` §4 as data: six tiers × three
role lines in the grid; furnace refinement recipes (raw meat/fish/grain →
cooked meat/fish/bread) listed with the furnace hint; one raw assembled
dish per tier that the furnace turns into the edible dish (R8.7 reverse
pattern); tooltips per the R7-FOOD format; raw tiers per §2; `grug_food`
tier data and role modifiers filled; **fish loot tables by zone level**
(the seam named in `docs/research/wp13-fishing.md`, everyone fishes);
KAT rows per tier and per pattern.

### R8-ALCH — Alchemy v1 (after PROF)

Brewing stand node and UI (fuel + reagents + vials, mechanics ours,
VoxeLibre as orientation), potions T1–T3 and elixirs T3–T6 from the plan
§5 as data, the herb authorizer hooked to the Alchemist profession, stand
craftable from a T3 recipe for housing, Alchemist trainer and stand in
every capital; KATs for cooldown sharing, elixir exclusivity, stacking
with food.

### R8-MOB1 — mob wave 1 (parallel to COOK/ALCH; packages of the mob plan §9)

1. Clock roles and fallbacks (no assets); 2. zero-asset variants; 3. start-
zone day and night families; 4. night families 11–40; 5. dragons and kings.
Rolling 6–8 (underground, deep, front and coast) as long as the round
runs. Each package: registrations, spawn rows, `LICENSE-media.md` rows,
KAT, headless boot.

### R8-HEDGE — capital hedge/wall ring continuity (mini-lane, WP13 code)

The capital centre hedge or wall is a protected ring; placed centre
content must not cut it (seen in Highcourt, Playtest 10). Find the cause
in `wp13/capitals.lua` / the district files, fix it for all six capitals,
KAT that walks every capital's ring in the generated buffer and finds no
gap except the gates; one capital run.

### R8-TAGS — per-viewer nametags (added 2026-09-18 on the user's finding; delivered 12886ada)

### R8-MISC — Strike tooltip resource gate (added 2026-09-18; delivered fbcf8ed2)

### R8-DOCS — documentation alignment at the end, as in rounds 5–7.

## 4. Decided (was the proposal's open list)

Lane cut as in §3; profession level v1 as in R8.3; the level-gate model
replaces keystones for all professions; both furnace patterns; the §2
choices; the coast profiles and mix; mob packages 1–5 as the goal. No open
decisions remain before the first lane.

## 5. Explicitly not in Round 8

Blacksmith, Tailor, Leatherworker, Woodcarver, Goldsmith recipe catalogs
(the framework is built; their catalogs follow in Round 9 on it), enchant
rolls (WP5), Scout, Nether content, farming as a player activity (WP32),
housing (WP24), mounts (WP31).

## 6. Playtest 11 (after Round 8, fresh world)

Use two clients to verify per-viewer player nametags and their 25/30-node
visibility boundary. At each class, inspect Strike's tooltip; then use a start
trainer and the profession-book UI. Walk a start zone by day and night to see
its new families, continue to its capital, verify the complete boundary ring,
and fight a king with its royal guards; visit or summon both dragon families.
Inspect the four coast profiles, sand, shallow strata and connected cave
mouths. Cook reachable dishes through both the grid and raw-assembly furnace
routes, fish in several level bands, and use a capital Alchemist trainer and
brewing stand for one potion and one elixir. The fifteen plant ingredients are
creative-inventory items in this round; world placement and crop soil are the
carried Round 9 MAP-B work.
