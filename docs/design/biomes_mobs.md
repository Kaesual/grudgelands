# Biomes & Mobs — Catalog

**Decided spec** (authored + approved 2026-08-06, incl. the flagged open
points — resolutions in §8; WP6 outcomes folded in 2026-08-07). This is
the implementation spec for
**WP18** (biome/mapgen registrations) and **WP6** (mob rosters & spawn
parameters).

## 0. Decided framework (recap, binding)

- Ring model (world.md §1/§8): settled race biomes in safe core + inner
  ring, wild nature variants outward; flank/back coasts 45–60; **war
  coast stays capped 20–30**; strait beaches 1–5 neutral wildlife.
- Mob level ALWAYS from `grug_core.mob_level_at(pos)` (radial field +
  depth axis, combat_stats.md §3). Biome level bands in this catalog are
  *descriptive* (where the biome sits in the rings), never hand-set per
  mob. Where older drafts said e.g. "bone-forest 40–60", the radial
  field wins (bone forest spans the west outer ring → 25–60).
- Stats derived, never hand-rolled: **HP = 15+5L, dmg = 2+0.4L,
  XP = 10L**; elite armor 80 (×3 HP, ×1.8 dmg, ×4 XP), rare armor 70
  (×5 / ×2.2 / ×6). Speeds: aggressive 4.4, heartland hunters 4.6
  (partly `dogshoot`), critters 3.4. One behavior verb per family;
  elites **and rares** telegraph (2 s wind-up, combat_stats §3); named
  rares broadcast.
- **Player-tag drop rule** (combat_stats §3) applies to every drop
  table below; the tag carries professions → **Leatherworker ×5** on
  every mob flagged `[leather]`.
- Identical base drops cross-continent: universal biomes are literally
  shared; race-flavored mirror biomes share drop tables ("same loot,
  different look" via trees/woods/tints — §3.2 lists the pairs). "Shared
  table" means the **base materials** (meat, the leather tier, the cloth
  tier) are the same item and the same chance on both sides; the **third
  slot is family-flavored** by design (§3.2).
- Nature mobs aggro on sight vs players AND NPCs; density target ~1
  visible mob per 15–20 m of wilderness travel.
- Patch model: race biomes recur as patches across their band; patches
  outside the core have a high chance of a small village, lower chance
  of an outpost. Elves live in tree-integrated settlements.

Stats quick reference (normal tier; compute, don't copy):

| L | HP | Dmg | XP | | L | HP | Dmg | XP |
|---|----|-----|----|---|---|----|-----|----|
| 5 | 40 | 4 | 50 | | 30 | 165 | 14 | 300 |
| 10 | 65 | 6 | 100 | | 45 | 240 | 20 | 450 |
| 20 | 115 | 10 | 200 | | 60 | 315 | 26 | 600 |

## 1. World biome map

### 1.1 Geometry anchors (from grug_core / world.md §1)

Per continent (Kragmar coordinates; Elandor = z mirrored): rectangle
x −1500..1500, z 100..1700; capital ~(0, 900); safe core ≈ x ±645,
z 600..1132 (implemented field, see below); inner ring ≤ ~550 radial
from capital (front side exact); outer ring beyond;
war coast z 100..300. Race bands (fixed compass): west x ≤ −500,
center −700..700, east ≥ 500 — Accord W/C/E = Dwarf/Human/Elf, Throng
W/C/E = Undead/Orc/Troll.

The radial level field is **z-asymmetric** (WP18): the strait-facing
front uses the wider scale 1000, the back side 775, so the approach to
the capped war coast stays low-level instead of peaking above it —
measured core belt ≈ x ±645, z 600..1132. The guard field is floored
at 60 inside the core (hard step at the core edge — a deliberate
guarded perimeter, not a continuity bug).

**`_grug_spawn_zones` names (WP18 replaced borderland/starter/
midlands):** `strait` (beach z 0..±100), `war_coast` (±100..±300),
`core`, `inner`, `outer`, `coast` (last ~150 nodes before shoreline at
flanks/back), `underground` (y < −40).

### 1.2 Biome list

Continent column: **A** = Elandor (Accord, south), **T** = Kragmar
(Throng, north), *both* = shared.

| # | Biome | Continent | Role | Rings | Eff. levels |
|---|-------|-----------|------|-------|-------------|
| 1 | grug_meadows | A | Human settled | core+inner (+war coast) | 1–25 |
| 2 | grug_deep_forest | A | universal forest (Human/Elf wild) | outer, center-back + east | 25–60 |
| 3 | grug_pine_hills | A | Dwarf settled | west core+inner | 1–25 |
| 4 | grug_crags | A | Dwarf wild, band-specific | west outer | 25–60 |
| 5 | grug_elf_forest | A | Elf settled | east core+inner | 1–25 |
| 6 | grug_jungle_fringe | A | universal jungle (Accord side) | east flank strip | 38–60 |
| 7 | grug_savanna | T | Orc settled | core+inner (+war coast) | 1–25 |
| 8 | grug_badlands | T | Orc wild, band-specific | center-back outer | 25–60 |
| 9 | grug_blight | T | Undead settled | west core+inner | 1–25 |
| 10 | grug_bone_forest | T | universal forest, Throng look | west outer | 25–60 |
| 11 | grug_jungle_edge | T | Troll settled | east core+inner | 1–25 |
| 12 | grug_deep_jungle | T | universal jungle (Throng side) | east outer | 25–60 |
| 13 | grug_swamp | both | universal, low terrain pockets | outer (y ≤ 6) | 25–45 |
| 14 | grug_beach | both | universal shoreline fringe | everywhere (y 1..4) | by position |
| 15 | grug_ocean | both | sand-bottom ocean | y < 1 | — |
| 16 | grug_underground | both | caves (existing) | y ≤ −256 | depth axis |

`grug_crags` additionally registers an alpine sibling
**`grug_crags_snowy`** (same cuboid and climate point, y ≥ 80, snowblock
top — §1.3), so the world holds **17 biome registrations**.

War coast is **not** its own biome (decided 2026-08-06): it uses the
local band's settled biome plus a battlefield decoration set (§2,
war-coast row).

### 1.3 Engine registration table (mapgen v7, min_pos/max_pos cuboids)

All values Throng (z positive); the Accord half of a row registers the
same cuboid mirrored (z → −z) under its own name and climate point —
and a pair MAY share a point, because the two continents never overlap.
Overlaps
between settled and wild cuboids are deliberately WIDE (~400–500
nodes): inside an overlap the heat/humidity voronoi decides per
position → recurring patches (the patch model, §1.4). `y_max = 31000`,
`y_min = 4` unless noted.

| Biome | x range | z range | y | heat | humidity | node_top |
|-------|---------|---------|---|------|----------|----------|
| grug_savanna / grug_meadows | −700..700 | 100..1500 | ≥4 | 85 / 50 | 35 / 40 | dry_dirt_with_dry_grass / dirt_with_grass |
| grug_badlands / grug_deep_forest* | −700..700 (*A: −900..1500) | 1100..1700 (*A: 100..1700) | ≥4 | 95 / 60 | 15 / 75 | grug_nodes:mesa_clay / grug_nodes:dirt_with_forest_litter |
| grug_blight / grug_pine_hills | −1250..−500 | 100..1700 | ≥4 | 25 / 30 | 20 / 60 | grug_nodes:blight_dirt / dirt_with_coniferous_litter |
| grug_bone_forest / grug_crags | −1500..−750 | 100..1700 | ≥4 (crags 4..79) | 15 / 10 | 45 / 30 | grug_nodes:dirt_with_bone_litter / default:gravel |
| grug_crags_snowy (A only) | −1500..−750 | 100..1700 | ≥80 | 10 | 30 | default:snowblock (dust: default:snow) |
| grug_jungle_edge / grug_elf_forest | 500..1250 | 100..1700 | ≥4 | 80 / 70 | 70 / 60 | dirt_with_rainforest_litter / grug_nodes:dirt_with_silver_litter |
| grug_deep_jungle / grug_jungle_fringe | 750..1500 (A: 1150..1500) | 100..1700 | ≥4 | 90 / 85 | 90 / 85 | dirt_with_rainforest_litter / dirt_with_rainforest_litter |
| grug_swamp † | full | −1700..1700 | 1..6 | 60 | 95 | grug_nodes:mud |
| grug_beach † | full | −1700..1700 | 1..4 | 50 | 55 | default:sand |
| grug_ocean † | unlimited | unlimited | −255..3 | 50 | 50 | default:sand |

Land bands start at |z| = **100**, not 160: the war coast (|z| 100..300)
carries real land above y = 4 wherever the coast-noise inset is small,
and a band starting at 160 would leave that strip without ANY biome —
bare stone, no decorations, no spawn surface.

† The three universal biomes are registered **once**, not as a mirrored
pair — a biome name may exist only once in the engine. Swamp and beach
therefore use a z-symmetric cuboid, and `grug_ocean` is x/z-**unlimited**:
the strait, the coastal ocean and the open sea all lie outside every land
cuboid, and without an unlimited ocean they would have no biome at all
(no seabed filler, no dungeon nodes, no cave liquid).

Notes:
- grug_deep_forest (Accord) is ONE biome with a wide cuboid spanning
  the human back-country AND the elf band — its point loses to the
  settled points in core/inner (their cuboids end at z 1500 / x 1250),
  and wins uncontested beyond → settled inner, patchy middle, wild
  outer, no hard seams.
- Extreme points (95/15, 10/30, 90/90) need the climate noise to
  actually reach them: WP18 sets `mg_biome_np_heat`/`np_humidity` to
  offset 50 / scale 35 (engine defaults otherwise; the `eased` flag has
  to be passed explicitly or a Lua noiseparams table drops it), so all
  points are reachable. Verify in a test world before tuning shares.
- The single shared `grug_ocean` above replaces the per-biome
  sand-bottom `_ocean` siblings of the WP2 mapgen (decided with WP18 —
  one ocean is simpler and the only way to cover the open sea).
- **Where the beaches really are**: the ocean mask carves the coastline
  0..150 nodes INSIDE the rectangle, so the strait-facing shoreline sits
  at |z| ≈ 100..250 — i.e. inside the **war_coast** zone (|z| ≤ 300),
  not in `strait`. The `strait` zone is open water plus the last nodes
  of beach; the flank/back beaches fall into `coast`. Shoreline wildlife
  must therefore list `war_coast` among its zones (§4).
- **Landmine reminder** (AGENTS.md): never register ores/decos against
  biome names that might not resolve.
- New signature top nodes (all cheap retints of MTG textures,
  CC BY-SA 3.0, in a new `grug_nodes` mod): `blight_dirt` (grey-violet
  dirt), `dirt_with_bone_litter` (ash-grey litter), `dirt_with_forest_
  litter` (dark green), `dirt_with_silver_litter` (pale), `mesa_clay`
  (red-orange), `mud` (swamp, slows walking slightly via groups). These
  exist FOR the LotT spawn-whitelist trick — precise per-biome spawn
  gating with zero runtime cost (§4).

### 1.4 Patch model & settlements

- **Patches**: the wide cuboid overlaps (§1.3) make each band a voronoi
  mosaic: settled patches deep in the wild zone and wild patches near
  the core, pure only at the extremes. No extra noise machinery needed
  — this is exactly how the current biomes.lua overlap works, widened.
- **Settlement pass** (WP13 structure pass, deterministic from world
  seed): candidate points on a jittered grid (~300 ± 100 m) across each
  band. At each candidate, read the biome:
  - settled race biome patch, outside the safe core → roll **60% small
    village** (4–8 NPCs: trader, quest board, 1–2 guards matching
    `guard_level_at`), else **25% military outpost**, else nothing.
  - wild/nature biome → 10% outpost, 5% humanoid camp (§3, bandit /
    mirefolk camps), else nothing.
  - Min spacing 250 m between any two settlements; cap +3 villages and
    +3 outposts per band beyond the guaranteed POI budget of world.md
    §9 (which stays the deterministic minimum: 1 race village in core,
    1 flavor camp inner, 1 outpost per ring, 1 apex lair outer).
- **Elven treehouses**: the elf village/settlement schematics are
  tree-integrated — each is a single .mts containing a **great
  silverwood** (custom giant tree, trunk 2×2, height 14–18) with a
  platform at 8–10 m, hut, ladder/rope down, lanterns. Ground level
  gets only fences/lamps. Placement needs a flat-ish 12×12 pad (reuse
  the WP-platform median-height logic). Same schematics serve core
  village and patch villages (patch = 1–2 trees, core village = 4–5).
- Guards/NPCs in patch settlements level with the local field
  (`guard_level_at`) — an outer-ring patch village is a level-40
  settlement by itself.

### 1.5 Level-continuity check (no holes, no >5 jumps)

Walking from the village belt (core, L1–10) in any direction:

| Walk | Sequence | Check |
|------|----------|-------|
| Dwarf/Undead village → flank coast (west) | core 1–10 → inner pine-hills/blight 10–25 (x −500..−850) → crags/bone-forest 25–45 (−850..−1400) → coast 45–60 | continuous |
| Human/Orc village → back coast | core 1–10 → inner meadows/savanna 10–25 → deep-forest/badlands 25–45 (z 1250..1550) → coast 45–60 | continuous |
| Elf/Troll village → flank coast (east) | core 1–10 → inner elf-forest/jungle-edge 10–25 → deep-forest+fringe/deep-jungle 25–45 → jungle coast 45–60 | continuous |
| any village → strait | core 1–10 (z 900..600) → inner 10–25 (z 600..350) → war coast 28–30→20, falling toward the strait (cap ramp 600..100) → strait beach 1–5 neutral | continuous down to z 100; the strait step is a DESIGNED break (neutral wildlife, not a difficulty ramp) |
| lateral (band to band) | same radial field on both sides of a band border | no jump by construction |
| swamp pockets | low terrain inside outer ring → 25–45 by position | inside band |
| depth | caves +1 level per 20 nodes below y=0 | combat_stats §3 |

Every ring×band cell has registered spawns (§4) — no dead zones.

## 2. Per-biome specs (surface, flora, gathering)

Gathering split (professions.md): `[food]` = gatherable by everyone;
`[herb Tn]` = Herbalism only, alchemy tier n. Herb tiers tie to rings:
T1 inner (10–25), T2 outer (25–45), T3 coast/deep (45–60).

| Biome | Trees / schematics | Ground cover & gathering | Notes |
|-------|--------------------|--------------------------|-------|
| grug_meadows | apple_tree.mts sparse (fill 0.0015), bush | grass 1–5, flowers; wild potato + corn patches `[food]`, apples `[food]`; sunleaf `[herb T1]` | fields/roads near settlements (WP13) |
| grug_pine_hills | pine_tree.mts + small_pine (fill 0.006) | ferns; wild berries (blueberry bush) `[food]`; gravemoss on stone `[herb T1]` | scattered boulders (deco) |
| grug_elf_forest | silverwood (retinted aspen_tree.mts) + apple mix (fill 0.007) | pale grass, white flowers; wild berries `[food]`; sunleaf `[herb T1]` | great-silverwood only via settlement schematics |
| grug_deep_forest | apple + aspen dense (fill 0.02), fallen logs (apple_log.mts) | ferns, mushrooms `[food]`; dragonweed edge `[herb T2]` | dark, high tree density |
| grug_crags | snowy_pine above y 60, else bare | gravel/stone tops, snow above y 80; dragonweed `[herb T2]`, frost lichen deco | band-specific nature biome (Dwarf area only) |
| grug_savanna | acacia_tree.mts sparse (0.002), dry shrubs | dry grass 1–5; wild corn patches `[food]`; sunleaf `[herb T1]` | waterhole ponds (deco) |
| grug_badlands | large_cactus, dead shrub | mesa clay banding (stratum deco optional); dragonweed `[herb T2]` | band-specific nature biome (Orc area only) |
| grug_blight | gravewood (custom dead tree, no leaves) sparse | grey grass tufts, bone piles (deco); gravemoss `[herb T1]` | fireflies/wisp particles optional |
| grug_bone_forest | gravewood dense (fill 0.015), bone piles | mushrooms `[food]`; dragonweed `[herb T2]` | shares deep-forest drop tables (§3.2) |
| grug_jungle_edge | jungle_tree.mts (0.008) | jungle grass; wild bananas? → wild melon `[food]` (BASE-compatible); sunleaf `[herb T1]` | |
| grug_deep_jungle / grug_jungle_fringe | jungle + emergent_jungle (0.025); papyrus lives in the adjacent swamp/shore band (v7 has no water above sea level, so the jungle cuboids at y ≥ 4 cannot host waterside papyrus) | vines/lianas (asset list); crimson lotus `[herb T3]`; wild melon `[food]` | fringe = same nodes/roster, Accord side |
| grug_swamp | papyrus_on_dirt, dead bush; willow-ish gravewood retint optional | reeds, waterlilies; marshbloom `[herb T2]`; mushrooms `[food]` | shallow water pools (mud floor) |
| grug_beach | — | shells (deco); stormkelp on coast-zone beaches only `[herb T3]` | |
| war-coast overlay | local band biome | battlefield decos: broken carts, bone piles, burnt patches (schematic decos) | no separate biome (decided); decoration set ships with WP13's schematic pass |

Herb summary (both continents can gather every tier — see §6):
sunleaf T1 (meadows, savanna, elf forest, jungle edge), gravemoss T1
(pine hills, blight), dragonweed T2 (crags, badlands, deep forest,
bone forest), marshbloom T2 (swamp), crimson lotus T3 (deep jungle,
jungle fringe), stormkelp T3 (coast-zone beaches).

## 3. Mob roster

Per family: ONE verb, level = `mob_level_at(spawn)`, stats from
formulas, speed per combat_stats. `[leather]` = Leatherworker ×5 hook.
Drop chances in mobs_redo format (chance N = 1/N). Working item names —
final naming in items_crafting.md. All aggressive mobs:
`pathfinding = 1`, `group_attack` per verb, soft de-aggro 25 m (WP6).

### 3.1 Families by biome group

**Settled biomes, all six (core + inner, L1–25):**

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Boar (exists; per-biome tint: Plague Boar in blight, Jungle Boar east) | charges — a mid-range **rush**: the stalker impulse flattened horizontally, triggered at 4–10 m with an 8 s cooldown | day | 4.4 (WP6 retune) | meat 1/1 ×1–2; light leather 1/2 `[leather]`; tusk 1/3 | grug_mobs_boar.b3d (have) |
| Rabbit/Hare (tints) | flees (critter) | day | 3.4 | meat 1/1; light leather 1/3 `[leather]` | mobs_mc_rabbit |
| Zombie (exists) | never leashes | night (in grug_blight: 24 h — Undead identity) | 4.2 | zombie flesh 1/1; linen scrap 1/2; steel ingot 1/10 | mobs_mc_zombie (have) |
| Bandit (camp humanoid; camps placed by §1.4, inner+outer, both continents) | defends camp (leashes to camp, group) | 24 h | 4.4 | linen cloth 1/1 ×1–2 (inner camps) / heavy cloth (outer camps); copper coins | character.b3d + bandit skins (LotT-derived) |

**Forest pair — grug_deep_forest (A) ↔ grug_bone_forest (T)** (outer,
25–60; Throng names in parentheses, same drop tables):

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Wolf (Blightfang Wolf) — also inner pine-hills/meadows patches from L10 | hunts in packs; flees low, returns with pack | 24 h | 4.4 | meat 1/1; leather 1/2 `[leather]`; fang 1/3 | mobs_mc_wolf (+tint) |
| Bear (Plaguehide Bear) — elite variant "Elder" ×1.6 scale, rolled **1 in 10 at spawn** | territorial (guards radius ~20 m, short chase) | day | 4.4 | meat 1/1 ×2; heavy leather 1/2 `[leather]`; bear claw 1/4 | mobs_mc_polarbear retexture |
| Giant Spider (tints per biome; also jungle, caves) | webs (hit applies 40% slow 3 s) | night | 4.4 | spider silk 1/1 ×1–2; venom gland 1/6 | mobs_monster spider |
| Stag (Gaunt Stag) | flees (critter) | day | 3.4 | meat 1/1 ×2; leather 1/2 `[leather]` | animalia reindeer (asset harvest) |
| Skeleton Archer — bone forest + war coast only | dogshoot (ranged) | night | 4.0 walk | bone 1/1; linen scrap 1/2; arrows | mobs_mc_skeleton |

**Mountain pair — grug_crags (A) ↔ grug_badlands (T)** (outer, 25–60):

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Crag Eagle (Vulture) | dive-bombs — a real **flier** (`fly` in air) on `dogfight`, whose vertical tracking drives it down onto a grounded target and back up: that IS the swoop, and it needs no projectile asset | day | 4.6 heartland | sharp feather 1/1 ×1–2; meat 1/2 | animalworld eagle (+tint) |
| Stone Golem (Mesa Golem) — **elite** (armor 80, telegraphed slam) | hurls rocks (dogshoot) | 24 h | 3.0 | stone core 1/1; iron lump 1/2; gem 1/8 | mobs_monster stone monster |
| Mountain Ram | flees (critter) | day | 3.4 | meat 1/1; **heavy** leather 1/4 `[leather]` — a ram substitutes heavy leather for the critter's light leather, it has no light-leather slot | mobs_mc sheepfur retexture |
| Hyena — savanna+badlands (Throng's wolf-mirror, wolf drop table) | hunts in packs | 24 h | 4.4 | wolf table | animalworld hyena |

The Ram's Throng mirror, the **Dust Hare**, is not a badlands critter of
its own: it is the dust-tinted variant of the settled Rabbit/Hare row
above (dry grass, blight, rainforest litter) and shares that row's
numbers and drops. The badlands therefore carry no critter — Hyena,
Vulture and Mesa Golem only.

**Savanna extras (grug_savanna inner, L10–25):** Hyena (above, from
L10); Zebra — flees, meat ×2 + leather 1/2 `[leather]`, animalworld
zebra (Accord mirror = Stag in meadows-adjacent forest patches: same
table).

**Jungle group — grug_deep_jungle (T) ↔ grug_jungle_fringe (A)** (outer/
coast, 38–60) + grug_jungle_edge inner (10–25):

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| **Jungle Lynx** (the Raptor slot) — jungle_edge from L10, deep jungle | hunts in packs (wolf drop table) | day | 4.4 | meat 1/1; leather 1/2 `[leather]`; raptor claw 1/3 (item id kept) | big-cat retint of the panther mesh — the §8.2 fallback was **executed**: the paleotest velociraptor's media license could not be verified per file |
| Panther | stalks (silent approach, pounce burst) | night | 4.6 heartland | meat 1/1; leather 1/2 `[leather]`; sleek pelt 1/4 | animalworld leopard retint |
| Serpent | poisons (hit applies 1 dmg/2 s, 6 s) | day | 4.4 | scaled hide 1/2 `[leather]`; venom sac 1/3 (alchemy reagent) | animalworld cobra |
| Jungle Ape — elite variant "Silverback" (bear-mirror: bear drop table), rolled **1 in 10 at spawn** | territorial (radius ~20 m) | day | 4.4 | meat ×2; heavy leather 1/2 `[leather]`; ape hair 1/4 | animalworld monkey upscaled |
| Giant Spider (jungle tint) | webs | night | 4.4 | spider table | mobs_monster spider |
| Parrot — jungle_edge critter | flees | day | 3.4 | feather 1/1; meat 1/2 | mobs_mc_parrot |

**grug_swamp (universal, 25–45):**

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Crocodile | ambushes (lurks still, burst on approach) | 24 h | **4.4, one speed** — the water bonus is dropped (see §4) | scaled hide 1/1 `[leather]`; meat; croc tooth 1/3 | animalworld crocodile |
| Bog Ooze | engulfs (slow tank: touch damage aura, **flat 2 damage**, radius 2 — the one hand-written damage number in the roster; its melee is level-scaled as usual) | 24 h | 2.6 | slime gel 1/1 ×1–2 (alchemy reagent); vendor trash | mobs_mc_slime retint |
| Mirefolk (fish-folk humanoid, camps at swamp pools; the "murloc memory") | swarms (camp group aggro, all rush at once) | 24 h | 4.4 | linen cloth 1/2; fish 1/1; shiny scale 1/4 | character.b3d small scale + custom skin (2D work) — decided: include |

**grug_beach / strait (L1–5 neutral — attack only when provoked):**

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Shore Crab — **deferred (§8.3), not shipped** | retaliates (pinches when punched) | 24 h | 3.4 | crab meat 1/1; chitin 1/2 | deferred until a licensed model is sourced (decided); strait launches with Gull only |
| Gull | flees | day | 3.4 fly | feather 1/1 | animalia song bird retexture |

Coast-zone beaches (45–60) reuse Crab as an **elite** "Reef Lurker"
(scale ×1.6, armor 80) — same table ×3 quantity. **Deferred with the
Crab (§8.3)**: neither is registered, so the beach cells currently carry
the Gull alone.

**War coast (20–30, both continents):** local settled-biome roster
continues; plus Skeleton Raider (dogshoot, night — battlefield dead;
skeleton table + heavy cloth 1/3) and Carrion Crow (flees, feather).
Faction NPC outposts/guards are WP6, not part of this catalog.

**Deep sea (world.md §2b):** Kraken Guard, L100 fixed (hand-set — the
one exception, it is a deterrent not content): mobs_mc_squid at
visual_size ×6, verb: drags under (pulls target down, heavy melee),
spawns only in open sea beyond the coastal ocean. No drops.

**Caves (depth axis, WP6 note):** reuse Zombie, Giant Spider, Stone
Golem with `underground` zone gating; levels come from the depth term
of `mob_level_at`. No cave-only families in this catalog.

### 3.2 Cross-continent drop-table pairs (binding)

| Shared table | Accord family | Throng family |
|---|---|---|
| wolf table | Wolf (forest/hills) | Blightfang Wolf, Hyena, Jungle Lynx* |
| bear table | Bear/Elder Bear | Plaguehide Bear, Jungle Ape/Silverback |
| spider table | Giant Spider | Giant Spider (tints) |
| stag table | Stag, Zebra-mirror | Gaunt Stag, Zebra |
| golem table | Stone Golem | Mesa Golem |
| bird-of-prey table | Crag Eagle | Vulture |
| jungle tables (panther/serpent) | jungle fringe (east flank) | deep jungle |
| swamp/beach/boar/zombie/bandit/skeleton | identical biomes both sides | identical |

*The Jungle Lynx also exists Throng-side inner (jungle edge) — the
Accord inner pack hunter is the Wolf; base drops match via the shared
wolf table.

**What "shared table" binds** (resolved in WP6): the first two slots —
the food/meat drop and the leather tier with its chance — are identical
item-for-item across a pair. The **third slot carries the family's own
flavor**: wolf/hyena → *fang* 1/3, Jungle Lynx → *raptor claw* 1/3;
bear → *bear claw* 1/4, jungle ape → *ape hair* 1/4. The economic value
of the pair stays equal (same tier, same chance), the trophy does not —
"same loot, different look" applies to the trophy too, and a literally
identical third item would erase the flavor for no balance gain.

### 3.3 Named rares (rare tier: armor 70, ×5 HP, ×2.2 dmg, ×6 XP, ×2 scale + tint, faction-wide spawn broadcast)

One per band + one shared war-coast rare per continent. Spawned by a
scheduled spawner (not ABM): respawn 2–4 h after kill, patrol route
between 2–3 fixed points. They inherit their base family's drop table
(×6 XP and the rare multipliers are the reward WP6 ships); the special
loot ROLLS ride on WP5's item/enchantment tables.

| Name | Base family | Where (band, ring) | ~L |
|------|-------------|--------------------|----|
| Grimtusk | Boar | A-center meadows, inner | 12 |
| Old Whitefang | Wolf | A-center deep forest, outer | 32 |
| Korgan's Bane | Stone Golem | A-west crags, outer | 42 |
| Silkfang | Giant Spider | A-east jungle fringe, coast | 50 |
| Marrowclaw | Plaguehide Bear | H-west bone forest, outer | 35 |
| Dustwing | Vulture | H-center badlands, outer | 38 |
| Emerald Coil | Serpent | H-east deep jungle, coast | 48 |
| Ashmaw | Boar (plague) | H-center savanna, inner | 12 |
| Captain Bonerattle (×2, one per continent) | Skeleton Raider | war coast | 28 |

## 4. Spawn parameter table

Mechanism: mobs_redo `mobs:spawn` + our `spawn_abm_check` override
(`_grug_spawn_zones`). Spawn `nodes` = the biome signature tops of §1.3
(LotT whitelist trick) — this alone confines most families; zones do
the ring gating. `min_height 0, max_height 200` on all surface entries
(golems and the crags rows — Ram, Crag Eagle — 300; the **Vulture
shares that 300 exception**, its mesa-clay badlands run just as high).
Day mobs `min_light 10`; night mobs `max_light 5`
+ `day_toggle = false` where mobs_redo supports it.

**`aoc` is per entity NAME, not per family** (mobs_redo counts objects
of that one name inside a 128-node sphere). Two spawn rows of the same
name — the Skeleton Archer's two node lists, a family's surface + cave
rows — share ONE budget; the per-biome tints are separate entities and
each carries the full row of its family, so a jungle spider and a pale
spider are two budgets of 4, not one.

Calibration: current baseline boar interval 30 / chance 2000 / aoc 4
on 5 node types = "sparse-to-ok" → common mobs get roughly **2× the
attempt rate** (interval 20, chance 1500) on 1–2 node types. The
per-biome aoc SUM is a soft ~14 (day); the rows below actually **peak
at 16 by day** (meadows/inner and savanna/inner) **and 12 at night**
(bone forest/outer) — a deliberate ~15 % overshoot of the soft cap,
because those are precisely the cells that hit the ~1 mob per 15–20 m
target, while the median cell lands nearer 28–35 m. The full per-cell
arithmetic, the density model and the calibration knobs (reach for
`chance` before `aoc`) are the audit trail in
**[docs/research/wp6_spawn_budget.md](../research/wp6_spawn_budget.md)**.

| Mob | nodes (spawn on) | interval | chance | aoc | light | zones |
|-----|------------------|----------|--------|-----|-------|-------|
| Boar (all tints) | all six settled tops | 20 | 1500 | 5 | min 10 | core, inner |
| Rabbit/Hare | settled tops | 20 | 1800 | 3 | min 10 | core, inner |
| Zombie | settled tops | 20 | 1600 | 4 | max 5 (blight: any) | core, inner, war_coast |
| Wolf/Blightfang | coniferous litter, forest litter, bone litter, grass | 20 | 1500 | 5 | any | inner, outer |
| Hyena | dry grass, mesa_clay | 20 | 1500 | 5 | any | inner, outer |
| Jungle Lynx (Raptor slot) | rainforest litter | 20 | 1500 | 5 | min 10 | inner, outer |
| Bear/Plaguehide | forest litter, bone litter | 20 | 2800 | 2 | min 10 | outer, coast |
| Jungle Ape | rainforest litter | 20 | 2800 | 2 | min 10 | outer, coast |
| Giant Spider (all) | forest litter, bone litter, rainforest litter | 20 | 1800 | 4 | max 5 | outer, coast, underground |
| Stag/Gaunt Stag/Zebra | forest litter, bone litter, grass, dry grass | 20 | 1800 | 3 | min 10 | inner, outer |
| Skeleton Archer | bone litter, blight_dirt, settled tops (war coast) | 20 | 2000 | 3 | max 5 | outer, war_coast |
| Skeleton Raider | settled tops, blight_dirt, sand | 20 | 2000 | 3 | max 5 | war_coast |
| Crag Eagle/Vulture | gravel, mesa_clay | 20 | 2000 | 3 | min 10 | outer, coast |
| Stone/Mesa Golem (elite) | gravel, stone, mesa_clay | 30 | 9000 | 1 | any | outer, coast, underground |
| Ram | gravel | 20 | 2200 | 2 | min 10 | outer |
| Panther | rainforest litter | 20 | 1800 | 4 | max 5 | outer, coast |
| Serpent | rainforest litter, mud | 20 | 1800 | 4 | min 10 | outer, coast |
| Crocodile | mud (only) | 20 | 1800 | 3 | any | outer |
| Bog Ooze | mud | 20 | 2000 | 3 | any | outer |
| Parrot | rainforest litter | 20 | 2500 | 2 | min 10 | core, inner |
| Carrion Crow | settled tops, blight_dirt | 20 | 2500 | 2 | min 10 | war_coast |
| Shore Crab — *deferred (§8.3)* | sand | 20 | 2200 | 3 | any | strait, war_coast, coast |
| Gull | sand | 20 | 2500 | 2 | min 10 | strait, war_coast, coast |
| Reef Lurker (elite crab) — *deferred (§8.3)* | sand | 30 | 8000 | 1 | any | coast |
| Kraken Guard | ocean water surface, open sea only (own check) | 60 | 12000 | 1 | any | (outside continents) |
| Bandits / Mirefolk | **no ABM** — camp node timer respawns 120–300 s, anchored to camp | — | — | 3–5 per camp | — | camp pos |
| Named rares | **no ABM** — scheduled spawner, 2–4 h respawn, broadcast | — | — | 1 | — | fixed routes |

Row notes:
- **Crocodile spawns on mud only.** "Water at mud" is not expressible:
  the spawn ABM's `nodes` list is the node it spawns ON and `neighbors`
  is an OR set, so "water AND mud" cannot be written. The lurking-in-
  water half of the verb is delivered by `floats` instead — the croc
  spawns on the mud bank and drifts into the pool.
- The **Skeleton Raider** reuses the Skeleton Archer's numbers
  (20 / 2000 / 3, night); it is the war-coast family, so its
  `war_coast`-only zone does all the gating and it needs no extra
  check. Its table is the skeleton table **plus heavy cloth 1/3**.
- **Parrot** and **Carrion Crow** are priced like the Gull, the other
  "flees" bird: 20 / 2500 / 2. Neither creates a new peak.

Performance justification (AGENTS.md rules, 100-player scale):
- aoc caps are per mob NAME in the spawn area, so co-located players
  SHARE the local budget; measured worst case Σaoc = 16 day / 12 night
  per biome around a lone traveler (wp6_spawn_budget.md §2, against the
  ~14 the rows were sized for). 100 dispersed players ≈ low thousands
  of candidate checks but capped actives: additionally set mobs_redo
  `mob_active_limit = 600` (global hard cap) in game settings.
- interval ≥ 20 s keeps the spawn ABM cheap; signature-node whitelists
  shrink the candidate node set per ABM tick; `catch_up = false`.
- Camps/rares off the ABM entirely (node timers / scheduled) — zero
  idle cost.
- The density target is delivered by SPAWN RELIABILITY (every surface
  chunk has whitelisted nodes) rather than raw counts; WP6's
  pathfinding/perf pass remains the blocker before raising any aoc.

## 5. Per-race woods & build sets (LotT pattern)

Pattern from lottplants/lottblocks: per-race tree + wood + a small
build-material set; settlement schematics use ONLY their race's set →
instant visual identity, and "same loot, different look" between
mirrored biomes. Wood from all six trees is `group:wood` (base recipes
accept any; race woods matter for looks + settlement schematics).

| Race | Tree (name) | Schematic source | Nodes (new unless BASE) | Build-material set | Grows in |
|------|-------------|------------------|--------------------------|--------------------|----------|
| Human | Oak | BASE apple_tree.mts | default tree/wood (desc "Oak") | oak planks, cobble, brick, thatch (grug_nodes:thatch, straw retint) | meadows, deep forest |
| Dwarf | Mountain Pine | BASE pine_tree.mts (+snowy) | default pine | pine planks, stonebrick, grug_nodes:carved_granite (stone retint) | pine hills, crags edge |
| Elf | Silverwood | aspen_tree.mts node-substituted (**new** silverwood variant) + **new** great_silverwood.mts (treehouse base, §1.4) | grug_trees:silverwood_{tree,wood,leaves,sapling} — pale bark/leaf retint of aspen | silverwood planks, grug_nodes:marble (white stone retint; sold by dwarven vendors — trade hook) | elf forest, deep forest patches |
| Orc | Spikethorn Acacia | BASE acacia_tree.mts | default acacia | acacia planks, grug_nodes:adobe (dry-dirt+straw craft), bone block | savanna, badlands edge |
| Troll | Kapok | BASE jungle_tree.mts + emergent | default junglewood | jungle planks, mossycobble, grug_nodes:carved_totem (deco) | jungle edge, deep jungle |
| Undead | Gravewood | **new** dead-tree .mts (bare twisted trunk, no leaves; build in-world, save via schematic tool) | grug_trees:gravewood_{tree,wood,sapling} — blackened apple-log retint | gravewood planks, grug_nodes:cursed_cobble (mossycobble retint), bone block | blight, bone forest, swamp variant |

Missing assets summary: silverwood + gravewood textures (retints),
great_silverwood.mts + gravewood .mts schematics (hand-built), adobe/
marble/carved_granite/thatch/bone block/cursed_cobble/carved_totem
node textures (retints). All 2D retints of MTG media (CC BY-SA 3.0) —
license-clean, keep attribution.

## 6. Base-material map (both continents feed all base recipes)

| Material | Tier | Accord sources | Throng sources |
|----------|------|------------------|---------------|
| Light leather `[leather]` | 1–15 | boars, rabbits, rams | plague boars, hares |
| Leather `[leather]` | 10–45 | wolves, stags | hyenas, jungle lynxes, blightfang wolves, zebras, panthers* (*fringe gives A access too) |
| Heavy leather `[leather]` | 25–60 | bears, elder bears, rams | plaguehide bears, jungle apes |
| Scaled hide `[leather]` | 25–60 | crocodiles (swamp), serpents (fringe) | crocodiles, serpents |
| Linen **scrap** (trash tier, sells; not the cloth) | 1–30 | zombies, skeletons | same |
| Linen cloth | 10–30 | **bandit camps** (core/inner), mirefolk | same |
| Heavy cloth | 25–45 | outer bandit camps, war-coast raiders | same |
| Spider silk (Tailor T3) | 25–60 | deep-forest/fringe spiders | bone-forest/jungle spiders |
| Food plants (everyone) | all | potatoes/corn (meadows), berries (hills, elf forest), apples, mushrooms (forest/swamp), melon (fringe), meat/fish everywhere | corn (savanna), melon (jungle), mushrooms (bone forest/swamp), berries via forest patches, meat/fish |
| Herbs T1 (Herbalism) | 10–25 | sunleaf (meadows, elf forest), gravemoss (pine hills) | sunleaf (savanna, jungle edge), gravemoss (blight) |
| Herbs T2 | 25–45 | dragonweed (crags, deep forest), marshbloom (swamp) | dragonweed (badlands, bone forest), marshbloom (swamp) |
| Herbs T3 | 45–60 | crimson lotus (jungle fringe), stormkelp (coast) | crimson lotus (deep jungle), stormkelp (coast) |
| Alchemy reagents (mob) | 25–60 | venom gland/sac, slime gel, bear claw | identical (shared tables) |
| Woods | all | oak, pine, silverwood (+jungle at fringe) | acacia, kapok, gravewood — all `group:wood` |
| Ores/gems | depth axis | universal underground + golem drops | same |

Every row has at least one source per continent. Race woods are
deliberately asymmetric (identity); base recipes accept `group:wood`.

**Cloth supply, precisely** (resolved in WP6): zombies and skeletons
drop **linen scrap**, which is vendor trash, *not* the tailoring
material. The cloth line comes from **humanoids** — bandit camps for
linen (core/inner) and heavy cloth (everything further out), mirefolk
camps for linen. The camp supply is therefore the whole cloth economy,
and WP6 ships it as **12 deterministic bandit camps, two per race band**
(one inner at |z| ≈ 550, one outer at |z| ≈ 1350, offset from the
capital's x so they never collide with the outpost column). The
patch-driven camps of §1.4 — the ones rolled per settlement candidate —
land with WP13's structure pass and thicken that supply; they do not
create it.

## 7. Asset shopping list (models; licenses per docs/research/assets/mobs_animals.md — re-verify in source repo before import, AGENTS.md rule)

| Mob(s) | Source | License (code/media) | Work needed |
|--------|--------|----------------------|-------------|
| Boar, Zombie | already vendored | GPLv3 / CC BY-SA 4.0 | retints only |
| Rabbit, Parrot, Skeleton, Wolf, Slime→Ooze, Squid→Kraken, Polar bear→Bear, Sheep→Ram | VoxeLibre mobs_mc | GPLv3 / CC BY-SA 4.0 | mcl_mobs→mobs_redo port (pattern known), retextures |
| Spider, Stone Golem | mobs_monster (TenPlus1) | MIT / CC BY 3.0 | drop-in mobs_redo, retint |
| Hyena, Zebra, Eagle/Vulture, Leopard→Panther, Cobra→Serpent, Crocodile, Monkey→Ape | animalworld (mt-mods) | MIT / MIT (**sounds: verify per file, freesound CC**) | mobs_redo-native; texture pass toward 16px style |
| Reindeer→Stag, Song bird→Gull/Crow | animalia (ElCeejo) | MIT / MIT | asset harvest, re-register on mobs_redo, remap anim frames |
| ~~Raptor~~ → **Jungle Lynx** | paleotest media unverifiable per file → big-cat retint of the panther mesh (animalworld, MIT) | MIT / MIT | fallback executed in WP6, retint only |
| Bandit, Mirefolk | character.b3d + skins | LGPL 2.1 mesh; LotT skins CC BY-SA 3.0 | 2D skin work (mirefolk fully custom) |
| Shore Crab | no verified source yet (check marinara / nssm in-repo) | — | decided: deferred until sourced |
| Trees/nodes | MTG media retints + 2 hand-built schematics | CC BY-SA 3.0 | see §5 |

Never import without checking LICENSE in the source repo; document
every file in the mod's LICENSE-media.md.

## 8. Resolved decision points (2026-08-06)

All four flagged points were decided per recommendation; points 2, 3
and 5 record what WP6 then actually shipped.

1. **War coast** = local band biome + battlefield decoration overlay,
   no separate biome.
2. **Raptor**: verify the paleotest media license per file; on failure
   replace the family with "Jungle Lynx" (big-cat retint, same pack
   verb and drop table). **The fallback was executed** — the paleotest
   media could not be verified per file, so the family ships as the
   Jungle Lynx (same verb, same drops, `raptor_claw` item id kept).
3. **Mirefolk is in** (custom 2D skin work); **Shore Crab deferred**
   until a licensed model is sourced — the strait launches with Gull
   only. WP6 confirmed the deferral: neither Shore Crab nor its elite
   Reef Lurker is registered, and the §3.1/§4 rows for both stay in
   this catalog as the spec to implement once a model exists.
4. **Jungle fringe reuses the troll jungle nodes 1:1** on the Accord
   side (max drop symmetry, zero new assets).
5. **The boar's "charges"** is implemented as a **mid-range rush**, not
   a wind-up gallop: the same impulse the panther's pounce uses,
   flattened horizontally, fired at 4–10 m with an 8 s cooldown. One
   verb helper serves both families, and the boar reads as a charger
   without a second state machine.
