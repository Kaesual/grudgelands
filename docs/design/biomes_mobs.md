# Biomes & Mobs — Catalog

**Living content catalog.** Named-zone geography is defined in
[world_zones.md](world_zones.md); biome properties, mobs, gathering, woods and
materials are specified below. Historical radial geometry is archived rather
than used as current placement authority. Future depth-pulse and deferred
content requirements remain explicitly separate from delivered behavior.

## 0. Decided framework (recap, binding)

- Target surface model (`world_zones.md`): every named zone owns a fixed
  allowed-biome list and level range; outer race starts are 1–10, home zones
  11–20, heartland 21–30 and every frontier/contact zone 31–60. The complete
  38-zone palette is `world_zones.md` §8. No biome outside a zone's list may
  win there.
- Mob level comes from `grug_core.mob_level_at(pos)`: named-zone surface
  level plus the independent depth axis (`combat_stats.md` §3). Biome labels
  never hand-set a mob's level. **Exception (Round 28 ruling 34, Lane S1):**
  in a zone with a spawn recipe, a surface mob takes a level in its role's
  range of its spawn region and a named leader the top of its region (§4.2);
  `grug_core.mob_level_at` returns the region's level there (the level
  overlay, [spawn_regions.md](spawn_regions.md)).
- Current spawn eligibility consumes `grug_zones.*` through the named-zone
  policy. Retired radial buckets have no compatibility path. Section 1 links
  the historical map evidence and the current geography/coverage authorities.
- Stats derived, never hand-rolled: **HP = 20+5L+0.66L²,
  raw dmg = 2+0.3L+0.005L², XP = 25+5L** (one kill equivalent, Round 28
  ruling 30; no further kill multiplier); Round 17 applies the startup
  `grug_mob_damage_scale` (default 1.5) exactly once to non-player damage.
  `combat_stats.md` owns settlement and exceptions. Elite armor 80
  (×3 HP, ×1.8 dmg, ×4 XP), rare armor 70 (×5 / ×2.2 / ×6), and the
  boss tier has a flat 18,000 HP (normal damage, XP and armor). Speeds: aggressive **4.6**
  (4.4 until 2026-09-16,
  user ruling 2), heartland hunters 4.6
  (partly `dogshoot`), critters 3.4. One behavior verb per family;
  elites **and rares** telegraph (2 s wind-up, combat_stats §3); named
  rares broadcast. Implementation: `mods/ENTITIES/grug_mobs/levels.lua:70-118`.
- **Player-tag drop rule** (combat_stats §3) applies to every drop
  table below; the tag carries professions → **Leatherworker ×5** on
  every mob flagged `[leather]`.
- Identical base drops cross-continent: universal biomes are literally
  shared; race-flavored mirror biomes share drop tables ("same loot,
  different look" via trees/woods/tints — §3.2 lists the pairs). "Shared
  table" means the **base materials** (meat, the leather tier, the cloth
  tier) are the same item and the same chance on both sides; the **third
  slot is family-flavored** by design (§3.2).
- Aggressive nature mobs aggro on sight vs players AND NPCs; neutral families
  follow the fixed disposition contract below. Density target ~1
  visible mob per 15–20 m of wilderness travel.
- **Density is a per-zone budget** (Round 24 ruling 27, 2026-09-29;
  `mods/ENTITIES/grug_mobs/density.lua`): the zone budget is **15 by day,
  23 by night** (1.5 × the pre-Round-24 median area population of 10 / 15),
  times an optional per-zone multiplier `grug_mobs.ZONE_DENSITY` for later
  tuning. Since Round 28 the region spawner is what spends it: each kind's
  density class scales it, and the roster's roles share it (§4.2 Spawn
  regions, [spawn_regions.md](spawn_regions.md)). The Round 24
  per-point budget of the zone *palettes* (species sharing the budget by
  their row caps around an ABM spawn point) applied to no zone after the
  spawn recipes replaced the palettes (0 of 38 zones, its fixture retired),
  and Round 30 removed it with the surface ABM rows it governed (§4).
  Critters, underground rows, the Kraken and Reed Angelfish, NPCs, authored
  guards, camps, patrols, kings, dragons, summoned/encounter adds, bosses and
  named rares are neither counted nor limited. An ordinary (non-critter) ABM
  row above y = −40, today the Kraken's, keeps the Round 16 rule (1.3x
  attempt frequency and a nearest-integer 1.3x species cap); the Rift
  Spawn's surface row states its final numbers (§4).
- Target patch model: logical biomes vary only inside their zone-owned
  weighted palette. Fixed village/outpost/camp slots come from
  `world_zones.md` §§8/11; Elves keep tree-integrated settlements.

### Round 18 surface eligibility and regional identities

Ordinary surface spawns require their natural minimum level to fit the actual
local difficulty query. The level field still rises toward the warfront on both
continents; a species cannot clamp itself upward into an easier band. This gate
does not change depth populations or authored encounters. Settlement spawn
protection is unchanged and does not prevent an already spawned mob from
walking into a town.

A named zone selects one interchangeable regional wildlife tint. Host nodes and
day/night clocks remain additional requirements, not alternative authorities.

| Family | Current zone selection |
|---|---|
| Boar | Base in the nine Accord/Orc settled zones (including Whitebridge); Plague in Stillgrave/Mournfen; Jungle in Kapok/Raincall |
| Zombie / Husk | Husk in Sunscar, Redtusk and Shattered Line; Zombie elsewhere |
| Spider | Jungle in Glassroot, Thunderroot, Skyglass and Stormscale; existing faction forest tint on its exclusive hosts elsewhere |
| Lynx / Panther / Snow Leopard | Panther in those four mixed/high-jungle zones; Lynx in jungle-edge start/home zones at L4+ (band 2 of Kapok, Round 24); Snow Leopard in its named mountain zones |
| Skeleton archer tints | Raider in war zones; Frost Stray in Wyrmglass; Archer in other eligible forest/mountain zones |

Distinct combat roles such as Goblin melee/ranged members and Bog Witch remain
separate creatures. The same imported mesh does not by itself equate differently
shaped/scaled bird species or visibly different combat roles. NPC/guard model
reuse is unrestricted. Existing spawn caps/rates, dispositions and drop tables
remain; this revision does not add a density multiplier.

Troll early Lynx kill objectives use Tapir, while the later Raincall outpost Lynx
objective remains. The Orc chain's night patrol hunts Husks; the Husk spawns
in Sunscar from band 2 of the start-zone gradient (L4+, Round 24), so that
quest is level 5 with the level-5 reward of 180 XP (`progression.md` §4; the
other races' Zombie patrols stay level 4 at 140 XP: the Zombie spawns from L3).
Counts and copper rewards are unchanged.

Stats quick reference (normal tier; compute, don't copy):

| L | HP | Dmg | XP | | L | HP | Dmg | XP |
|---|----|-----|----|---|---|----|-----|----|
| 5 | 62 | 3.6 | 50 | | 30 | 764 | 15.5 | 300 |
| 10 | 136 | 5.5 | 100 | | 45 | 1582 | 25.6 | 450 |
| 20 | 384 | 10.0 | 200 | | 60 | 2696 | 38.0 | 600 |

## 1. Named-zone biome placement

The current horizontal map, zone palettes and difficulty bands are defined in
[world_zones.md](world_zones.md) §§2/7/8. Logical biome properties live in §2
below; spawn eligibility also uses the current disposition, local-level and
regional-family rules in §0/§3/§4.

### 1.1 Geometry anchors

Use the fixed named-zone hubs and authored POI anchors in `world_zones.md`
§§7/8/12. No radial ring, mirrored rectangle or climate-selected capital anchor
is current placement authority.

### 1.2 Biome list

The zone catalog in `world_zones.md` §8 assigns the allowed logical-biome
palette. The material and vegetation catalog is §2 below. A logical biome may
occur in several zones without sharing their difficulty or settlement policy.

### 1.3 Surface projection

Section 2.1 owns the logical-biome surface projection; `world_zones.md` §§7/11
owns shore, hydrology and resource placement. Both deep-jungle and jungle-fringe
use canopy litter. `grug_badlands_east` remains the ochre component of the Troll
frontier and Stormscale palettes, not a transfer of Orc cultural ownership.

The coastal habitat follows the authored shelf; planned inland water keeps its
zone classification. Coral, kelp and wild-source details follow
`world_zones.md`'s Round 10 source/reef rules. Shore Crab and Reef Lurker live
on sandy sea shore near water (§3.1, §4). Registered node/biome names
must resolve before they are used by ore or decoration definitions.

### 1.4 Settlements

Settlement positions use the fixed POI slots in `world_zones.md` §§8/11;
architecture and current composition are in [settlements.md](settlements.md).
The former jittered-grid settlement probabilities are retired.

The approved elven village direction remains tree-integrated: great silverwood
with a 2×2 trunk, 14–18-node height, platform at 8–10 nodes, hut, ladder/rope
and lanterns; ground-level fences and lamps. The original 12×12 fitting pad and
one-to-two/four-to-five-tree composition examples are preserved in the archive
for future village authoring, subject to the current fixed slot/envelope rules.

### 1.5 Coverage and evidence

Biome hosts, named-zone eligibility, local level and day/night roles must be
checked together when changing a spawn roster. A shared top node alone proves
neither regional tint correctness nor complete spawn coverage. Historical
ring-cell measurements do not certify current named-zone density or coverage.
Current map acceptance requirements remain in `world_zones.md` §14.

The retired cuboid registrations, carve experiments, climate measurements and
ring coverage matrices are preserved in
[the world-design archive](../archive/design/world-historical.md). They are
historical evidence, not instructions to restore the old map.

## 2. Per-biome specs (surface, flora, gathering)

Gathering split (professions.md §2), **revised 2026-08-07 — the herbs
split in two**:

| Marker | Who may gather it | Farmable later |
|---|---|---|
| `[food]` | everyone | yes — becomes a crop with the farming package |
| `[food found-only]` | everyone | **never** — found in the world, never grown |
| `[herb Tn]` | **healing herb** — Alchemist only, tier n | **never** |
| `[spice Tn]` | **spice**, tier n — everyone gathers it, *used* by the Alchemist **and** by Cooking | yes |

Both plant lines keep the same ring tiers: T1 inner (10–25), T2 outer
(25–45), T3 coast/deep (45–60), and each line has exactly one plant per
tier, reachable on both continents.

**Where the line runs**: healing herbs grow on ground no plough will
ever touch — bare stone, gravel and mesa clay, dead wood, the deep
jungle floor — while spices grow on the soft, workable ground of
meadow, marsh and shore. The split is readable off the biome itself, it
keeps every healing herb bound to a journey into its own biome, and it
gives Cooking a supply line that farming can later take over without
ever touching alchemy's.

**Farming and claims**: inside an active Claim Stone claim (`housing.md`;
world integration summary in `world.md` §5) only the owner and players with
the Everything permission can dig or harvest a crop; harvesting counts as
digging. Only cooking ingredients are cultivated: the
`[food]` and `[spice Tn]` lines of this section, never a `[herb Tn]`, cultural
resource or `[food found-only]`. The "Farmable later" column above is therefore
also the cultivated plant set.

The table describes biome vegetation identity. Exact gathering sources and
the seventeen cultivated families follow §2.2 and `world_zones.md` §11 plus
its Round 10 source rules; farming and Cooking are no longer a future-only
placeholder.

| Biome | Trees / schematics | Ground cover & gathering | Notes |
|-------|--------------------|--------------------------|-------|
| grug_meadows | apple_tree.mts sparse (fill 0.0015), bush | grass 1–5, flowers; wild potato + corn patches `[food]`, apples `[food]`; sunleaf `[spice T1]` | fields/roads near settlements (WP13) |
| grug_pine_hills | pine_tree.mts + small_pine (fill 0.006) | ferns; wild berries (blueberry bush) `[food]`; gravemoss on stone `[herb T1]` | scattered boulders (deco) |
| grug_elf_forest | silverwood (retinted aspen_tree.mts) + apple mix (fill 0.007) | pale grass, white flowers; wild berries `[food]`; sunleaf `[spice T1]` | great-silverwood only via settlement schematics |
| grug_deep_forest | apple + aspen dense (fill 0.02), fallen logs (apple_log.mts) | ferns, mushrooms `[food found-only]`; dragonweed edge `[herb T2]` | dark, high tree density |
| grug_crags | snowy_pine above y 60, else bare | gravel/stone tops, snow above y 80; dragonweed `[herb T2]`, frost lichen deco | band-specific nature biome (Dwarf area only) |
| grug_savanna | acacia_tree.mts sparse (0.002), dry shrubs | dry grass 1–5; wild corn patches `[food]`; sunleaf `[spice T1]` | waterhole ponds (deco) |
| grug_badlands (+ `_east`) | large_cactus, dead shrub | mesa clay banding (stratum deco optional); dragonweed `[herb T2]` | Orc back country **plus the Troll east wing** since WP36 (§1.3) — the mirror of the deep forest's east wing, not a band-specific biome any more |
| grug_blight | gravewood (knotted dead branches, sparse grey leaf remnants) sparse | grey grass tufts, bone piles (deco); gravemoss `[herb T1]` | fireflies/wisp particles optional |
| grug_bone_forest | gravewood dense (fill 0.015), bone piles | mushrooms `[food found-only]`; dragonweed `[herb T2]` | shares deep-forest drop tables (§3.2) |
| grug_jungle_edge | jungle_tree.mts (0.008) | jungle grass; wild bananas? → wild melon `[food]` (BASE-compatible); sunleaf `[spice T1]` | |
| grug_deep_jungle / grug_jungle_fringe | jungle + emergent_jungle (0.025; emergent trees everywhere except zones of mountain relief); papyrus lives at the water in the swamp (§2.1) | vines/lianas (asset list); crimson lotus `[herb T3]`; wild cocoa `[food found-only]` — **level-51–60 zones only** (§2 tightening 2026-08-13); wild melon `[food]` | same flora, roster and ground: `grug_nodes:dirt_with_canopy_litter`, shipped as the fringe's top node by WP40 R7 (`r7_r6_manifest.lua`); only `grug_jungle_edge` still uses rainforest litter |
| grug_swamp | papyrus_on_dirt, dead bush; willow-ish gravewood retint optional | reeds, waterlilies; marshbloom `[spice T2]`; mushrooms `[food found-only]` | shallow water pools (mud floor) |
| grug_beach | — | shells (deco); rock salt crust on coast-zone beaches `[found-only salt, inedible]` | Stormkelp uses the cross-biome dry-shore predicate below, not a beach-only row. |
| war-coast overlay | local band biome | battlefield decos: broken carts, bone piles, burnt patches (schematic decos) | no separate biome (decided); decoration set ships with WP13's schematic pass |

### 2.1 WP40 surface and deterministic decoration projection

The following table is the binding WP40 surface projection. It promotes the
normalized preflight table's WP18 migration-baseline top/filler values and
depths into target parameters, including its target-confirmed canopy-litter
correction for both deep-jungle logical IDs. Shore and bed spans remain owned
by the accepted R3/R5 vertical operations; the table chooses their material
only.
`grug_crags_snowy` adds `default:snow` as dust on an exposed dry top; every
other biome gets a snow cap and a patchy dust band only near and above the
snow line ([world_zones.md](world_zones.md) §7.6).
Planned hydrology uses `default:river_water_source`; all other authored water
uses `default:water_source`. A logical biome not in this complete table is a
contract error rather than a fallback to an engine biome.

| Logical biome | Top / depth | Filler / depth | Shore and bed | Deterministic R6 decorations (`fill_numerator/fill_denominator`) |
|---|---|---|---|---|
| `grug_meadows` | `default:dirt_with_grass` / 1 | `default:dirt` / 3 | `default:sand` | apple tree `3/2000`; bush `1/250`; each grass 1–5 `3/50` |
| `grug_pine_hills` | `default:dirt_with_coniferous_litter` / 1 | `default:dirt` / 3 | `default:gravel` | pine tree `1/250`; small pine `1/500`; pine bush `3/500`; blueberry bush `1/1000`; each fern 1–3 `1/50` |
| `grug_crags` | `default:gravel` / 1 | `default:gravel` / 2 | `default:gravel` | snowy pine `1/500`, only at `surface_y >= 60`; pine bush `3/500` on gravel, shrub band only |
| `grug_crags_snowy` | `default:snowblock` / 1 | `default:gravel` / 2 | `default:gravel` | none |
| `grug_elf_forest` | `grug_nodes:dirt_with_silver_litter` / 1 | `default:dirt` / 3 | `default:sand` | silverwood via replaced aspen tree `1/200`; apple tree `1/500`; bush `1/250`, shrub band only; each grass 1–3 `1/50` |
| `grug_deep_forest` | `grug_nodes:dirt_with_forest_litter` / 1 | `default:dirt` / 3 | `default:sand` | apple tree `3/250`; aspen tree `1/125`; fallen apple log `1/1000`; bush `1/250`, shrub band only; each fern 1–3 `1/50` |
| `grug_swamp` | `grug_nodes:mud` / 1 | `grug_nodes:mud` / 2 | `grug_nodes:mud` | papyrus `1/50`, only on a dry mud or sand root beside standing water: a wet column (sea, bay, lake or river) within two nodes whose surface lies 0–3 below the root's ground (Round 22 Phase 5), so a swamp grows reeds wherever it has water and none where it has none; replacing template `default:dirt` with `grug_nodes:mud`; dry shrub `1/250` |
| `grug_savanna` | `default:dry_dirt_with_dry_grass` / 1 | `default:dry_dirt` / 3 | `default:sand` | acacia tree `1/500`; acacia bush `1/250`; dry shrub `1/250`; each dry grass 1–5 `3/50` |
| `grug_badlands` | `grug_nodes:mesa_clay` / 1 | `grug_nodes:mesa_clay` / 3 | `default:gravel` | large cactus `1/1000`; dry shrub `1/125` |
| `grug_badlands_east` | `grug_nodes:mesa_clay` / 1 | `grug_nodes:mesa_clay` / 3 | `default:gravel` | large cactus `1/1000`; dry shrub `1/125` |
| `grug_blight` | `grug_nodes:blight_dirt` / 1 | `default:dirt` / 3 | `default:gravel` | gravewood `3/2000`; dry shrub `3/200`; bone pile `1/500` |
| `grug_bone_forest` | `grug_nodes:dirt_with_bone_litter` / 1 | `default:dirt` / 3 | `default:gravel` | gravewood `3/200`; dry shrub `3/200`, shrub band only; bone pile `1/250` |
| `grug_jungle_edge` | `default:dirt_with_rainforest_litter` / 1 | `default:dirt` / 3 | `default:sand` | jungle tree `1/125`; junglegrass `1/25` |
| `grug_deep_jungle` | `grug_nodes:dirt_with_canopy_litter` / 1 | `default:dirt` / 3 | `default:sand` | jungle tree `1/50`; emergent jungle tree `1/200`; junglegrass `1/20` |
| `grug_jungle_fringe` | `grug_nodes:dirt_with_canopy_litter` / 1 | `default:dirt` / 3 | `default:sand` | jungle tree `1/50`; emergent jungle tree `1/200`; junglegrass `1/20` |
| `grug_beach` | `default:sand` / 1 | `default:sand` / 2 | `default:sand` | none |

Every decoration root requires `surface_y >= 1`. Every density above is the
catalog density; altitude, snow and the forest field scale it per column
(Round 23 Phase 2, [world_zones.md](world_zones.md) §7.6: tree line, shrub
band, snow line, groves and clearings, deep forest and deep jungle trees
×1.5). The four "shrub band only" rows grow nothing below the tree start. Template schematics are
centred in x/z and rotate by a domain-separated choice among 0/90/180/270
degrees. The blueberry bush and fallen apple log use y offset +1; the log is
centred only in x and replaces its unavailable brown mushroom with `air`. The
emergent jungle tree uses y offset −4 and grows everywhere except in zones of
mountain relief (Round 22 D37; the natural jungle spans y 0–400), and all
other template offsets are zero. The manifest still names these two site
rules by their flat-world tokens (`surface_y_at_most_32`, `surface_y_1_to_4`),
which the r6_catalog digest pin freezes; `r6_planner.lua` reads them as the
rules above. Silverwood applies the accepted aspen-node
replacement. Every dry shrub has exact `param2 = 4`. Gravewood uses original
7×7×7 (Blight) and 7×9×7 (Bone Forest) schematics with 17/23 face-connected
wood cells and only 5/8 optional dead-leaf cells (MTS probability value 96 each; mapgen inclusion 3/8).
Every wood cell and vertical slice is mandatory, preserving connected branches.
Leaves have a grey tint, decay within radius 3 of wood, and drop nothing.
Saplings choose either size and a quarter-turn rotation, using these same assets;
obstructed or unloaded growth volumes retry without removing the sapling. Simple variant ranges above mean one independently
settled entry per named variant at the displayed fill.

Candidate cells are globally anchored 16-column squares. Deterministic
per-world placement and rotation, with a neighbor halo large enough for
rotated footprints, replace engine randomness and the legacy emergent-tree
`sidelen = 80`; the code specifies the hashing and ranking. Cultural
reservations settle first, followed by emergent/other large templates,
ordinary trees, simple multi-node trunks and ground cover. Wrong hosts,
exclusions, clearance or collisions reject without movement, retry or
fallback placement.

R6 emits no placeholder for meadow flowers, Elf white flowers, Pine Hills
boulders, Blight grey-grass tufts or optional Swamp willow/gravewood retint.
It also does not add herbs, spices, crops, found-only foods, battlefield
dressing or any other optional decoration; their owning packages remain
unchanged.

### 2.2 WP33 gathering-source contract (decided 2026-08-31)

WP33 adds exactly twelve one-cell natural sources through WP40's `P9G` tail.
P9G runs after R6 P9 in the same private buffers and single VoxelManip commit.
It never overwrites, moves, retries or refills a rejected root. Every accepted
source is a low hand-gathered node and drops exactly one stable raw item; the
three healing herbs first pass the fail-closed Alchemist authorization below.
The exact named-zone and host rosters are `world_zones.md` Section 11; density
is over eligible root columns, not all map columns.
Rock Salt retains exactly Gravesalt, Stormscale and Wyrmglass. Its dry cardinal
shore roots require logical Beach: sand in Gravesalt, stone or gravel on the
two mountain islands. The final P7 support must match the zone-specific host;
mountain beach sand is not retained to make the resource placeable. No other
gathering source set, density or harvest rule changes.

| Source | Exact opportunity density | Classification | Farmable in WP32 |
|---|---:|---|---|
| Potato | 1/256 | universal food | yes |
| Corn | 1/256 | universal food | yes |
| Sunleaf | 1/384 | universal spice T1 | yes |
| Mushroom | 1/384 | universal found-only food | no |
| Gravemoss | 1/512 | healing herb T1 | no |
| Marshbloom | 1/512 | universal spice T2 | yes |
| Melon | 1/512 | universal food | yes |
| Dragonweed | 1/768 | healing herb T2 | no |
| Crimson Lotus | 1/1024 | healing herb T3 | no |
| Stormkelp | 1/1024 | universal spice T3 | yes |
| Wild Cocoa | 1/1024 | universal found-only food | no |
| Rock Salt | 1/1024 | universal found-only food | no |

The complete gathering population is closed at **26 identities**: these twelve
new P9G sources, eight existing R6 sources (Apple, Blueberries, Oak, Mountain
Pine, Silverwood, Spikethorn Acacia, Kapok and Gravewood), and the six R6
cultural slots in `items_crafting.md` Section 4.1. A reused tree or bush is not
placed a second time.

`grug_gathering` owns exactly one registration seam for healing herbs. Before
WP10 provides it, all three herbs are visible but cannot be removed or yield an
item. Later only `grug_jobs` may register the authorizer and read profession or
recipe-book state. Missing, throwing or malformed authorization fails closed;
spices, foods and cultural sources never call this seam.

**Healing herbs** (Alchemist only, never farmable; both continents reach
every tier — see §6): **gravemoss T1** (pine hills, blight),
**dragonweed T2** (crags, badlands, deep forest, bone forest),
**crimson lotus T3** (deep jungle, jungle fringe). All three sit on
stone, gravel, mesa clay, dead-wood litter or jungle floor.

The lotus source is the one that had to be repaired: until 2026-08-08 the
Accord's `grug_jungle_fringe` generated at 0.08 % of the land because the
deep forest contained its cuboid, so in practice **only the Throng had a
T3 healing herb**. Biomes now follow the zone palettes of `world_zones.md`
§8, and the fringe's lotus comes from The Skyglass Canopy (`world_zones.md`
§11).

**Spices** (gathered by everyone, used by both the Alchemist and
Cooking — which costs no main slot — and farmable once farming ships):
**sunleaf T1** (meadows, savanna, elf forest, jungle edge),
**marshbloom T2** (swamp), **stormkelp T3** (the exact cardinal dry-shore
predicate in `world_zones.md` §11). Sunleaf and Marshbloom sit on workable
grass/mud; Stormkelp's natural source may use any accepted P7 dry support in
its four named high/endpoint zones and does not require `grug_beach` or sand.

**Cooking supply, checked against the cooking tiers** (cooking keeps its
own recipe book with T1–T6 groups, `items_crafting.md`; the tiers tie to
the region an ingredient comes from):

- Low and middle tiers come out of the settled rings and the swamp:
  potato, corn, apples, berries, melon, mushrooms, sunleaf, marshbloom,
  plus meat and fish from anywhere.
- **T6 needs ingredients from level 50+ ground, and the coast/outer
  rows do carry them**: **wild cocoa places only in the level-51–60
  jungle-palette zones** (tightened 2026-08-13 so the T6 gate claim is
  literally true — today exactly The Skyglass Canopy on the shared
  contested front, both factions on foot, plus Stormscale Summit as the
  island bonus; the WP40 authored surface pass owns the zone binding),
  **stormkelp** and **rock salt** on the coast-zone beaches
  (45–60), and the meat of the outer/coast families (bear, jungle ape,
  panther, crocodile), whose level comes from `mob_level_at` and is
  45–60 out there. Every one of them is reachable by both factions
  (§6) — every level-41+ zone is contested and shared — so neither
  faction is cut off from the top of the cooking ladder.
- **Deliberately found-only** (never a crop): mushrooms, wild cocoa and
  inedible rock salt. That keeps the top of the cooking ladder a reason to
  travel, and it keeps a tier unlock ("find cocoa in the jungle") usable
  as a quest goal.

## 3. Mob roster

Per family: ONE verb, level = `mob_level_at(spawn)`, stats from
formulas, speed per combat_stats. `[leather]` = Leatherworker ×5 hook.
Drop chances in mobs_redo format (chance N = 1/N). Working item names —
final naming in items_crafting.md. All aggressive mobs:
`pathfinding = 1`, `group_attack` per verb. Disengagement follows
`combat_stats.md` §4: free-roaming mobs use the ambient pursuit policy (a
15-second incoming-damage clock plus target movement, then the run home;
no distance give-up, no soft de-aggro), while camp members, guards, rares and
other bound actors keep the 25 m soft de-aggro, the 45 m give-up and their
leash. Idle, a free-roaming mob wanders within 32 nodes of its spawn point
and roams at a calm walk (Round 24); an idle aggressive one also probes
every 4–5 seconds eight points on a ring at its view range and walks away
from roads, bridges, villages, start towns and capital cities among them
(Round 28 ruling 2, `combat_stats.md` "Road and town push"), never during a
fight.

**Natural spawn and unload distances:** an ordinary `mobs:spawn` row refuses
positions within **24 nodes** of any connected player. An unload-eligible mob
within **48 nodes** of any player never despawns. At **128 nodes** or farther it
despawns on unload; between 48 and 128 nodes the unload chance rises linearly
from 0 to 1. Distance is three-dimensional and the nearest player wins. NPCs,
tamed mobs, attacking mobs and mobs with `lifetimer >= 20000` retain their
existing exemptions. `remove_far_mobs = true` owns this distance policy;
`mob_expire()` does not run in that mode. The distance model follows the pinned
VoxeLibre boundaries: its natural-spawn shell is 24–128 nodes
(`reference_projects/VoxeLibre/mods/ENTITIES/mcl_mobs/spawning.lua:60-64,394-453`)
and its nearby-player lifetime refresh uses 47 nodes
(`reference_projects/VoxeLibre/mods/ENTITIES/mcl_mobs/api.lua:451-460`).

### 3.0 Critters vs. passive prey vs. enemies (decided 2026-08-08)

Idle and freely roaming ground mobs and NPCs choose only motion whose existing
bounded forward probe finds a descent of at most one node. This cheap local
guard keeps ambient populations out of ravines without adding wide scans or
full pathfinding. Combat, fleeing, authored patrols and scripted return routes
retain their separate movement contracts.

Ground-support checks pass through harmless non-walkable vegetation and require
actual walkable support within the allowed descent. Plants themselves are
neither support nor a cliff; vegetation over a deep drop remains unsafe.
Unknown/unloaded nodes and dangerous ground remain unsafe. The same rule
applies to combat pursuit and the bounded lateral escape probe.

Three behaviour classes, not two. The split is by **size and role**, not by
who runs away:

**Critters** — *small* animals only: **rabbit, hare, parrot, gull**, plus
the four additions the 2026-08-08 asset survey found on disk: **Cave Bat**
and a **cave crawler** (both `underground` — the caves had no critter at
all), **Bone Weevil** (bone forest + blight, the "creepy" biomes, day) and
**Bog Fowl** (swamp, day). The **Carrion Crow is deliberately NOT a
critter** — it is the last feather source and the entire daytime population
of the war coast, so it moves to the passive-prey class below instead
(same mesh, ~1.0 nodes tall, level 20–30 there). They are scenery with a
use, not content:

- **Always level 1, always 1 HP**, whatever the level field says at their
  position. This is the second documented exception to §0's "stats derived,
  never hand-rolled" rule (after the Kraken's fixed L100) and it is
  implemented as a **`critter` tier** in the level engine, not as a
  hand-set stat in a def.
- **0 XP.** Critters are food-bearing scenery, never an XP farm.
- **They drop FOOD only** — meat, nothing else. No leather, no feather, no
  crafting ingredient of any kind. Rationale: a food item is a welcome
  snack on the road but never a farm target, so a player with a full larder
  stops killing them automatically. This is what fixes their loot-table
  "value as an enemy".
- **No fall damage.** At 1 HP any 7-node fall is lethal (mobs_redo
  charges `d − 6`), which would quietly delete the population in exactly
  the hilly terrain where a travelling player wants a snack. They drop
  nothing without a player tag anyway, so there is no exploit either way.
  **The field must be written `false`, not `0`** — mobs_redo tests
  `if self.fall_damage` (`mods/ENTITIES/mobs/api.lua:2874-2923`) and every
  number is truthy in Lua, so `fall_damage = 0` is a silent no-op. Earlier
  revisions of this section printed `0`; the tier writes `false`.
- **Never elite or rare.** The level engine's telegraph gate must be a
  *positive* elite/rare test — a `tier ~= "normal"` test would give a
  rabbit a 2 s wind-up and a ×3 cone hit.

**How the tier is expressed** (WP36, `grug_mobs/levels.lua`): the `TIERS`
table gains a `critter` row that opts out of the multiplier model with FLAT
values (`hp_flat = 1`, `xp_flat = 0`) plus a fixed `level = 1`, so
`normal`/`elite`/`rare`/`boss` use the shared formulas — a flat
value replaces the formula for one stat and leaves the other two alone.
Damage stays formula-derived even for a critter: it never attacks, so the
number is never read, and a third exception would be noise. `fall_damage`
is normalized into the def at registration time, next to `armor` and for the
same reason (mobs_redo copies an explicit def-field whitelist, and a nil
there falls through to its default of `true`). The telegraph gate is a
positive `telegraph = true` flag on the elite and rare rows, asked through
one predicate (`mods/ENTITIES/grug_mobs/levels.lua:89-95`) that both the
`do_custom` gate and `telegraph_tick` call, and `set_tier` refuses to promote a
critter at all.

**Passive prey** — the *large* grazers: stag, gaunt stag, zebra, mountain
ram, **plus the Carrion Crow**. They are ordinary mobs in every mechanical
respect — **level from the field, HP and XP from the formulas, leather drops
kept** — with one behavioural difference from the aggressive families:
**they never attack on sight, but they fight back when attacked.** That is
what makes them worth the swing, and it keeps the leather tiers gated by a
real fight rather than by travel.

mobs_redo already expresses exactly this, so it is **four def fields and no
new aggro system** (`grug_mobs.passive_prey` in `verbs.lua` sets them in one
place): `passive = false` is what makes retaliation exist at all (on_punch's
tail calls `do_attack(hitter)` only for a non-passive mob, api.lua:3506-3515),
`attack_players = false` (with `attack_npcs = false`) is what removes aggro
on sight — it is read in exactly one place, `general_attack`'s candidate
filter (api.lua:1853-2017), and nothing in the attack *state* consults it —
`runaway` must be **off**, because on_punch's runaway block sets
`state = "runaway"` a dozen lines before the retaliation block resets it, so
the two cannot both be true — and **`attack_type = "dogfight"`** is what
makes the retaliation actually *fight*. That last one is necessary, not
decoration: `do_states`' attack branch dispatches on `explode` /
`dogfight`-`dogshoot` / `shoot`-`dogshoot` with **no else**
(api.lua:2176-2864) and `mobs.mob_class` defaults it to nil, so a
`passive = false` mob without an attack type holds a target reference and
does nothing with it — no damage, no punch clip, not even a `set_velocity`,
which leaves it coasting on the knockback until the leash drops it. It was
missing from the first WP36 cut and made a punched grazer *easier* to kill
than the 3 s `runaway` flee it replaced; `dogfight` is the melee family and
the right one, since prey carries no `arrow`. Two further systems read
`attack_type` as "can this fight at all" and were silent no-ops on prey
until it was set: the threat-driven target switch and the Taunt ability.
Setting it does **not** let prey initiate — acquisition on sight lives in
`general_attack` alone, which never reads the field.

A fifth field follows from the fourth, and it is the one place where prey
is not "four def fields and nothing else": **the four GROUND prey mobs
(stag, gaunt stag, zebra, mountain ram) carry `pathfinding = 1`.** §3's
"all aggressive mobs: `pathfinding = 1`" does not reach prey by its own
wording — prey never initiates — but once retaliation exists, a punched
grazer runs the ordinary ambient pursuit (`combat_stats.md` "Ambient
pursuit policy": it fights on while incoming damage sustains the fight and
runs home once the 15-second clock has expired and its target moves), and
`core.find_path` is what keeps that chase from ending at the first ledge.
Without it "worth the swing" is defeated by terrain and the leather tiers
go back to being gated by travel. It costs nothing at rest: mobs_redo
calls A* only from the attack branch, which prey reaches only after a
player punch. **The Carrion Crow is the exception and stays unset** — it
is a flier, `core.find_path` is a ground search, and every other flier in
the roster (crag eagle, vulture, gull, parrot, Kraken Guard) follows the
same rule.

The Carrion Crow's three decided changes, all zero-cost: `visual_size`
10 → **14** (~1.0 nodes tall — a target you can see and click), the
collisionbox scaled by that same 1.4 (`0.4 → 0.6` high, `0.2 → 0.3` wide),
and `punch` **aliased onto the fly clip** of the shared gull mesh so the
retaliation reads. Same mesh, same texture, same spawn row, same `aoc`.

**Aggressive families** follow the fixed Round 17 disposition matrix.
The earlier prey list does not make every unlisted family aggressive: Boar,
Plague Boar and Jungle Boar also retaliate only after being attacked.
Their attack verbs remain defined in §3.1.

Consequence for the material map (§6): plain **feather** loses its critter
source and moves to the **bird-of-prey table** (crag eagle / vulture), so
arrow fletching stays behind a real fight. Meat stays universal. The Carrion
Crow **keeps** its feather — it is prey, not a critter, and that drop is
what makes the war coast worth walking by day.

### 3.1 Families by biome group

**View range follows the attack type** (decided 2026-09-16, user ruling 3:
"more ranged mobs, with a larger view range than melee mobs, so ranged players
and the Mage take damage sooner"):

- a **`dogshoot` family sees 16 m** — it shoots, so it needs to see further
  than a brawler. Skeleton Archer, Skeleton Raider, Stone/Mesa Golem and the
  Bandit Archer all carry it.
- a **melee family sees 10–14 m by habitat** — 14 in the open (bandit, guard,
  hyena, jungle lynx, wolf, zebra, zombie), 12 where cover or a late-noticing
  temperament says so (bear, panther, mirefolk, stag, spider, jungle ape), 10
  low to the ground or at the village belt (boar and its tints, bog ooze, ram,
  serpent). The critters see 8; the Crocodile's 6 and the Crag Eagle's 16 keep
  their own documented reasons, and the aquatic Kraken's 40 is outside the
  comparison.
- **16 is the CEILING for a land mob, not a direction of travel.** Bound
  actors (camps, guards, rares) give up a chase at 45 m and leash at 40
  (`combat_stats.md` §4), and both rules exist because the mob keeps a target
  it can no longer see; a `view_range` above 16 starts eating into them.
  Free-roaming mobs end a fight by the ambient pursuit clock instead, so for
  them a longer sight only means pulls from further away.

**Settled biomes, all six (core + inner, L1–25):**

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Boar (exists; per-biome tint: Plague Boar in blight, Jungle Boar east) | charges — a mid-range **rush**: the stalker impulse flattened horizontally, triggered at 4–10 m with an 8 s cooldown | day | 4.6 (WP6 retune to 4.4, band raise 2026-09-16) | meat 1/1 ×1–2; light leather 1/2 `[leather]`; tusk 1/3 | grug_mobs_boar.b3d (have) |
| Rabbit/Hare (tints) | flees (**critter**, §3.0) | day | 3.4 | meat 1/1 — food only | mobs_mc_rabbit |
| Zombie (exists) | damage-sustained pursuit; 15 s without incoming damage plus moving target | night (in grug_blight: 24 h — Undead identity) | 4.6 | the zombie band table (Round 28, "Loot by band"): rotting flesh 1/2; linen scrap 1/2; the band's flesh 1/2 (T3+ also its tooth 1/3) and cloth (linen cloth from band 2, heavy cloth from band 3) 1/2; the band's tier bar 1/50. Static fallback, unused while the table covers every band: zombie flesh 1/1; linen scrap 1/2; iron bar 1/10 | mobs_mc_zombie (have) |
| Bandit (camp humanoid; two fixed camps per race region) | defends camp (leashes to camp, group) | 24 h | 4.6 | linen cloth 1/1 ×1–2 (home camp) / heavy cloth (frontier camp); copper coins | character.b3d + bandit skins (LotT-derived) |
| **Bandit Archer** (added 2026-09-16, ruling 3) — the same camp, one slot in three | dogshoot (ranged); view range **16** | 24 h | **4.0** in combat, like the Skeleton Archer (no soft de-aggro); roams at the Bandit's calm walk 1 (Round 24) | the Bandit's table **plus arrows 1/3** | character.b3d + the same bandit skins; the Skeleton Archer's arrow entity, no new art |

**Forest pair — grug_deep_forest (A) ↔ grug_bone_forest (T)** (outer,
25–60; Throng names in parentheses, same drop tables):

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Wolf (Blightfang Wolf) — also inner pine-hills/meadows patches from L10 | hunts in packs; flees low, returns with pack | 24 h | 4.6 | meat 1/1; leather 1/2 `[leather]`; fang 1/3 | mobs_mc_wolf (+tint) |
| Bear (Plaguehide Bear) — elite variant "Elder" ×1.4 scale, rolled **1 in 10 at spawn** | territorial (guards radius ~20 m, short chase) | day | 4.6 | meat 1/1 ×2; heavy leather 1/2 `[leather]`; bear claw 1/4 | mobs_mc_polarbear retexture |
| Giant Spider (tints per biome; also jungle, caves) | webs (hit applies 40% slow 3 s) | night | 4.6 | raw silk 1/1 ×1–2; venom gland 1/6 | mobs_monster spider |
| Stag (Gaunt Stag) | grazes (**passive prey**, §3.0: no aggro, retaliates) | day | 4.6 | meat 1/1 ×2; leather 1/2 `[leather]` | animalia reindeer (asset harvest) |
| Skeleton Archer — bone forest + war coast only | dogshoot (ranged) | night | 4.0 in combat, roams at 1 | bone 1/1; linen scrap 1/2; arrows | mobs_mc_skeleton |
| **Bone Weevil** — bone forest **and blight** (the two "creepy" biomes; one entity name, one `aoc` budget, per-biome tint stamped at spawn) | flees (**critter**, §3.0) | day | 3.4 | meat 1/1 — food only | mobs_mc_silverfish, bone-pale + blight tints |

**Mountain pair — grug_crags (A) ↔ grug_badlands (T)** (outer, 25–60):

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Crag Eagle (Vulture) | dive-bombs — a real **flier** (`fly` in air) on `dogfight`, whose vertical tracking drives it down onto a grounded target and back up: that IS the swoop, and it needs no projectile asset | day | 4.6 heartland | sharp feather 1/1 ×1–2; meat 1/2 | animalworld eagle (+tint) |
| Stone Golem (Mesa Golem) — **elite** (armor 80, telegraphed slam) | hurls rocks (dogshoot) | 24 h | 4.6 | stone core 1/1; iron lump 1/2; gem 1/8 | mobs_monster stone monster |
| Mountain Ram | grazes (**passive prey**, §3.0) | day | 4.6 | meat 1/1; **heavy** leather 1/4 `[leather]` — the ram is the crags' heavy-leather source, which is why it is prey and not a critter | mobs_mc sheepfur retexture |
| Hyena — savanna+badlands (Throng's wolf-mirror, wolf drop table) | hunts in packs | 24 h | 4.6 | wolf table | animalworld hyena |

The Ram's Throng mirror, the **Dust Hare**, is not a badlands critter of
its own: it is the dust-tinted variant of the settled Rabbit/Hare row
above (dry grass, blight, rainforest litter) and shares that row's
numbers and drops. The badlands therefore carry no critter — Hyena,
Vulture and Mesa Golem only.

Air fliers have a gentle near-ground tendency outside attack, runaway,
following, evade and root steering. A staggered 0.75-second probe checks at
most 12 nodes below the collision-box bottom, treating solid ground and liquid
surfaces as boundaries. The comfort band is 2–4 nodes; the additive vertical
bias tends toward −0.65 nodes/s above it and +0.55 below it, limited to
0.8 nodes/s². Twelve loaded air nodes request the same gentle descent, so a
ravine crossing loses height gradually. Unknown/unloaded ground yields no new
ground-relative bias. Purposeful steering removes only an identifiable owned
bias and clears the terrain cache; existing combat targeting owns pursuit.
Water fliers and ground mobs are excluded.


**Savanna extras (grug_savanna inner, L10–25):** Hyena (above, from
L10); Zebra — grazes (**passive prey**, §3.0, exactly like the Stag it
mirrors), meat ×2 + leather 1/2 `[leather]`, animalworld zebra (Accord
mirror = Stag in meadows-adjacent forest patches: same table).

**Jungle group — grug_deep_jungle (T) ↔ grug_jungle_fringe (A)** (outer/
coast, 38–60) + grug_jungle_edge inner (10–25):

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| **Jungle Lynx** (the Raptor slot) — jungle_edge from L4 (Kapok band 2, Round 24; was L10), deep jungle | hunts in packs (wolf drop table) | day | 4.6 | meat 1/1; leather 1/2 `[leather]`; Small Cat Claw 1/3 (`raptor_claw` item id kept) | big-cat retint of the panther mesh — the §8.2 fallback was **executed**: the paleotest velociraptor's media license could not be verified per file |
| Panther | stalks (silent approach, pounce burst) | night | 4.6 heartland | meat 1/1; leather 1/2 `[leather]`; sleek pelt 1/4 | animalworld leopard retint |
| Serpent | poisons (hit applies 1 dmg/2 s, 6 s) | day | 4.6 | scaled hide 1/2 `[leather]`; venom sac 1/3 (alchemy reagent) | animalworld cobra |
| Jungle Ape — elite variant "Silverback" (bear-mirror: bear drop table), rolled **1 in 10 at spawn** | territorial (radius ~20 m) | day | 4.6 | meat ×2; heavy leather 1/2 `[leather]`; ape hair 1/4 | animalworld monkey upscaled |
| Giant Spider (jungle tint) | webs | night | 4.6 | spider table | mobs_monster spider |
| Parrot — jungle_edge critter | flees (**critter**, §3.0) | day | 3.4 | meat 1/1 — food only (feather moved to the bird-of-prey table) | mobs_mc_parrot |

**grug_swamp (universal, 25–45):**

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Crocodile | ambushes (lurks still, burst on approach) | 24 h | **4.6, one speed** — the water bonus is dropped (see §4) | scaled hide 1/1 `[leather]`; meat; croc tooth 1/3 | animalworld crocodile |
| Bog Ooze | engulfs (slow tank: touch damage aura, **flat 2 damage**, radius 2 — the one hand-written damage number in the roster; its melee is level-scaled as usual) | 24 h | 2.6 | slime gel 1/1 ×1–2 (alchemy reagent); vendor trash | mobs_mc_slime retint |
| Mirefolk (fish-folk humanoid, camps at swamp pools; the "murloc memory") | swarms (camp group aggro, all rush at once) | 24 h | 4.6 | linen cloth 1/2; fish 1/1; shiny scale 1/4 | character.b3d small scale + custom skin (2D work) — decided: include |
| **Bog Fowl** — the swamp critter; universal biome, so the one new critter both continents share | flees (**critter**, §3.0) | day | 3.4 | meat 1/1 — food only (**not** its upstream's feather) | mobs_mc_chicken, marsh tint |

**Sandy sea shore (neutral — attack only when provoked):**

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Shore Crab | retaliates (pinches when punched) | 24 h | 3.4 | meat 1/1; scaled hide 1/2 | `grug_mobs_shore_crab.b3d` |
| Gull | flees (**critter**, §3.0) | day | 3.4 fly | meat 1/1 — food only | animalia song bird retexture |

Crabs spawn on dry `default:sand` at y 0–20 with water at or below the sea
surface (y ≤ 1) within 6 nodes, so the wide coastal sand band and inland
sand, lake and river shores above sea level included, stay crab-free
(Round 22 D36).
The local level splits every such shore: the Shore Crab below level 45, and
from 45 to 60 the **elite** "Reef Lurker" (same model, ×3 drops).

**War coast (20–30, both continents):** local settled-biome roster
continues; plus Skeleton Raider (dogshoot, night — battlefield dead;
skeleton table + heavy cloth 1/3) and Carrion Crow (**passive prey**,
§3.0 — grazes/scavenges, no aggro, retaliates; feather 1/1, and it is the
whole daytime population of the war coast).
Faction NPC outposts/guards are WP6, not part of this catalog.

**Round 8 zero-asset variants:** these families reuse shipped animated meshes
and apply texture modifiers at runtime; they add no media file.

| Mob | Verb | Clock | Zones / level band | Drops | Visual source |
|-----|------|-------|--------------------|-------|---------------|
| Poacher | dogshoot, roaming | night | Goldmead, Whitebridge, Ashenward, Starbough, Moonfall; Silverleaf band 3 and Lorindor | Bandit table + arrows 1/3 | Bandit Archer / dark skin modifier |
| Frost Stray | dogshoot | night | Stormvault and Wyrmglass, L31–60 | Skeleton table | Skeleton Archer / ice-blue modifier |
| Sun-Dried Husk | damage-sustained pursuit; 15 s without incoming damage plus moving target | night | Redtusk and Shattered Line; Sunscar from band 2, L4–50 | Zombie table | Zombie / sand-gold modifier |
| Song Bird | flees (**critter**) | day | Silverleaf, L1 fixed | meat 1/1 — food only | Gull / blue modifier, ×0.8 |
| Spiderling | weak web (20% slow, 2 s) | any (cave) | y −40…−100, L3–6 | raw silk 1/2 | Giant Spider / stone-brown modifier, ×0.5 |
| Blood Bat | swarm dive | any (cave) | y −101…−300, L6–18 | meat 1/1 | Cave Bat / blood-red modifier, ×1.25 |
| Stone Mite | swarms | any (cave) | y ≤ −700, L42–60 | stone core 1/8 | Cave Crawler / stone-grey modifier, ×1.33 |

**Round 8 start-zone families:** family rows are closed named-zone routes,
not biome-wide grants. In a start zone, a band-2 family begins at L4 and
continues through band 3; a band-1 family is present through the full start
zone. Giant Rat also occupies the entrance and middle caves from y −40 to
−300, where the surface clock is ignored.

| Mob | Verb | Clock | Zones / level band | Drops | Visual source |
|-----|------|-------|--------------------|-------|---------------|
| Fox | darts; a landed bite triggers a 6 m/s retreat with a 4 s lockout | day | Hearthpine, Dawnmere and Silverleaf from L4; Copperfell, Goldmead, Starbough | wolf table | animalia fox, MIT |
| Ibex | grazes (**passive prey**) | day | Hearthpine from L4; Copperfell, Frostbarrow, Stormvault | stag table | animalworld ibex, MIT |
| Wild Turkey | flees (**critter**) | day | Dawnmere and Goldmead, L1 fixed | meat 1/1 — food only | animalia turkey, MIT |
| Plains Runner | grazes (**passive prey**: fights back when attacked; Round 24, was a critter) | day | Sunscar, zone level | meat 1/1 | animalworld nandu, MIT |
| Tapir | grazes (**passive prey**) | day | Kapok from L4; Raincall, Whispering Reedlands, Totemwater | stag table | animalworld tapir, MIT |
| Giant Rat | swarms; one pull calls nearby rats | night on surface; any in caves | all six starts; caves y −40…−300 | meat 1/1 | animalworld rat ×1.6, MIT |
| Scorpion | poisons (1 damage / 2 s for 6 s) | night; 24 h in Sunscar (Round 24) | Sunscar from L4; Redtusk, Speargrass, Bannerbreak, Shattered Line | scaled hide 1/2; venom sac 1/3 | animalworld scorpion, MIT |
| Viper | poisons (1 damage / 2 s for 6 s) | night; 24 h in Kapok (Round 24) | Kapok from L4; Raincall | scaled hide 1/2; venom sac 1/3 | animalworld viper, MIT |

**Round 8 level-11+ night families:** Goblin Raider Hounds are members of
the Goblin Raider family, not an independent zone cast. The raider group is
leashless and alerts nearby members; one ranged Slinger and one hound row
give it mixed silhouettes. Wisp blink destinations must have two open nodes.

| Mob | Verb | Clock | Zones / level band | Drops | Visual source |
|-----|------|-------|--------------------|-------|---------------|
| Goblin Raider / Slinger / Raider Hound | group raid, leashless; Slinger dogshoots the Golem stone; hound rushes | night | Copperfell, Frostbarrow, Stormvault, Speargrass, Bannerbreak | linen scrap; purse or arrows; hound meat | goblins goblin + gobdog, CC BY-SA 3.0 |
| Snow Leopard | stalks (silent approach, pounce) | night | Frostbarrow, Stormvault, Wyrmglass | panther table | animalworld Snowleopard mesh and original skin, MIT |
| Wisp | flying melee; blinks up to 2.5 m toward a distant target every 4 s | night | Whitebridge, Ashenward, Lorindor, Moonfall, Glassroot, Mournfen, Whispering Reedlands, Totemwater | none | VoxeLibre vex, GPLv3 model / CC BY-SA 4.0 texture |
| Ashen Treant / Gravewood Treant | roots aura: 30% slow inside 3 m, refreshed once/s | night | Ashenward / Ossuary and Blackwind | apple 1/4 | mobs_monster tree monster, WTFPL, two runtime tints |

Bog Witch is deferred from this wave. The pinned VoxeLibre witch mesh has
keyed frames only in 1..41, while its required shooting and death behaviours
name frames 50..82 and 145; shipping it would violate the animated-mesh rule.
It remains absent until a licensed mesh with the required keyed behaviours is
pinned. The package KAT keeps `blocked=bog_witch` as the regression record.

**Round 8 fixed bosses:** these are authored encounters and have no ambient
spawn row or palette membership.

| Boss family | Clock | Location / level | Encounter | Visual source |
|-------------|-------|------------------|-----------|---------------|
| Wyrmglass Ice Dragon | any | Wyrmglass dragon anchor, fixed L70 boss | three-perch arena; 2 s breath-line / ground-slam telegraphs; persistent 30 min wall-clock respawn with 60 s warning | draconis ice dragon, sapphire, MIT |
| Stormscale Jungle Wyvern | any | Stormscale dragon anchor, fixed L70 boss | same shared encounter chassis, storm breath variant | draconis jungle wyvern, jade, MIT |
| Six race Kings | any | authored `king` socket in each capital, fixed L65 elite | one race-specific signature each; four fixed L60 elite royal guards; group reset and persistent 15 min wall-clock respawn | `character.b3d` + six generated royal skins |

The current gear catalogue has sword, dagger, greataxe and staff visuals only;
bosses do not create a second weapon-art system. The encounter kits remain the
authority, while the closest shipped wield silhouette is:

| King | Decided kit | Visible shipped item | Deliberate visual deviation |
|------|-------------|----------------------|-----------------------------|
| Dwarf | hammer; Ground Shatter | greataxe | no hammer visual; closest heavy two-handed weapon |
| Human | sword and shield; Rally | sword | no shield/offhand visual |
| Elf | bow; Volley | staff | no bow visual; closest long two-handed ranged silhouette |
| Undead | lich staff; Bone Call | staff | none |
| Orc | great axe; Cleave | greataxe | none |
| Troll | totem; Regrowth | staff | no totem visual; closest caster silhouette |

**Deep sea (world.md §2b):** Kraken Guard, L100 fixed (hand-set — the
one exception, it is a deterrent not content): mobs_mc_squid at
visual_size ×6, verb: drags under (pulls target down, heavy melee),
spawns only in open sea beyond the coastal ocean. No drops.

Three fields carry the boat contract of `boats.md`; the travel plan's ruling
7 (user, 2026-10-02) sets the first two:

- **`run_velocity` 10 inside a deep-ocean column, 5 everywhere else.** The
  existing once-per-second `do_custom` tick switches it at the guard's own
  position. Ten is above the improved boat's 8 nodes/s (`boats.md` §5), and
  one hit ejects a boat's rider, so a guard that sees a boat in deep ocean
  ends the trip. While a root or slow runs, the switch writes the saved base
  speed, so the effect engine stays the one owner of the live field.
- **`view_range` 40**, the same 40 m that is the threat-validity and leash
  radius of `combat_stats.md` §4, so the guard notices a boat before the boat
  is past it.
- **`reach` 4 is unchanged.** It remains above the ordinary roster's 3 because
  the model is ×6 and mobs_redo measures centre to centre
  (`mods/ENTITIES/mobs/api.lua:298-305`); the reason a fleeing target used to
  be nearly unhittable was the attack cadence, not the reach, and that is
  fixed once for every mob in `combat_stats.md` §4.

The guard's pursuit rules are owned by `world.md` §2b: the generic leash and
soft de-aggro stay off (`_grug_no_leash = true`, `_grug_soft_deaggro =
false`), and its own water-class leash in `do_custom` drops the target and
holds position as soon as the guard is outside deep ocean, so shelf water and
the dragon channels are never pursued into. Its `_grug_spawn_check` is
`in_deep_ocean` (`grug_zones.water_class_at(...) == "deep_ocean"`), so
deep-ocean-only spawning needs no separate mechanism.

**Caves (depth axis, WP6 note):** reuse Zombie, Giant Spider, Stone
Golem with `underground` zone gating; levels come from the depth term
of `mob_level_at`. **Two cave-only critters since 2026-08-08** (§3.0 —
before them every single thing that moved underground wanted the player
dead): **Cave Bat** (flier, `mobs_mc_bat`, no retint) and **Cave
Crawler** (`mobs_mc_silverfish`, no retint). Both are `critter`-tier, so
the depth term never touches them — a level-60 bat is not a thing.

| Mob | Verb | Day/Night | Speed | Drops | Model |
|-----|------|-----------|-------|-------|-------|
| Cave Bat | flees (**critter**, §3.0), flier | any (cave dark) | 3.4 fly | meat 1/1 — food only | mobs_mc_bat |
| Cave Crawler | flees (**critter**, §3.0) | any (cave dark) | 3.4 | meat 1/1 — food only | mobs_mc_silverfish |

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

Spawned by a scheduled spawner (not ABM): respawn 2–4 h after kill, patrol
route between 2–3 fixed zone anchors. They inherit their base family's drop
table (×6 XP and the rare multipliers are the reward WP6 ships); special loot
rolls ride on WP5's item/enchantment tables.

| Name | Base family | Named-zone route | ~L |
|------|-------------|------------------|----|
| Grimtusk | Boar | Goldmead Vale | 12 |
| Old Whitefang | Wolf | Ashenward March | 36 |
| Korgan's Bane | Stone Golem | Stormvault Heights | 40 |
| Silkfang | Giant Spider | The Skyglass Canopy | 55 |
| Marrowclaw | Plaguehide Bear | Blackwind Rise | 35 |
| Dustwing | Vulture | Bannerbreak Mesa | 38 |
| Emerald Coil | Serpent | Stormscale Summit approach | 60 |
| Ashmaw | Boar (plague) | Redtusk Savanna | 12 |
| Captain Bonerattle (×2) | Skeleton Raider | The Broken Causeway / The Shattered Line (41–50: the spawn region's level at the spot) | zone |

## 4. Spawn parameter table

Mechanism: mobs_redo `mobs:spawn` plus the named-zone spawn policy. In a
zone with a spawn recipe the surface rows other than the recipe's critters
are refused and the spawn regions of §4.2 spawn instead.
**Retired and merged rows (Round 30, the user's ruling on perf review
2026-10 #11):** a surface row that no zone can use registers no ABM
(`spawn_policy.lua` `spawn_row_kept`): every zone has a recipe, and the only
land outside every zone is dragon-channel floor under water, so on the
surface only the recipes' critters and the Rift Spawn's surface row stay.
The surface tables below are therefore history for every other family. The
remaining rows run through three merged ABMs, one per node set: underground
(stone and strata, y ≤ −40), water (Kraken, Reed Angelfish) and surface
(`grug_mobs/spawn_abms.lua`). A merged ABM takes its rows' shortest interval
and the largest chance that keeps every row's own rate; its dispatcher runs a
row only on that row's nodes, in its y range, with its neighbours and with
probability `C × I / (c × i)` (`c`, `i` the row's chance and interval, `C`,
`I` the merged ABM's), so each row keeps its chance × interval rate,
and everything after the trigger (light, clock, cap, players, policy) is the
row's own unchanged code. The engine scanned an active block for some spawn
ABM nearly every second before (88 ABMs on independent timers); now three
ABMs do it every 20–30 s.
Host nodes, authored zone palettes, regional identity and local level must all
admit the family. The retired `_grug_spawn_zones` field is not a current gate. `min_height 0, max_height 600` (the flight
ceiling) on all surface entries, since the natural terrain reaches past
y 500 and the zone palettes already gate the habitat (Round 22 D37). Only
water-bound rows keep a low cap, for a gameplay reason: the Kraken at 4
(sea surface) and the Shore Crab and Reef Lurker at 20 (sea shore). The
Reed Angelfish uses the flight ceiling too; its height rule is relative to
the water body (above the column's natural bed, Round 22 Phase 5).
Every family declares one spawn role, `clock = "day" | "night" | "any"`;
Zombie uses the palette-keyed form (`settled`/`war` night, `blight` any), and
a `"zone:<zone id>"` key sets the clock in one named zone ahead of the palette
keys (Scorpion in Sunscar, Viper in Kapok: `any`, Round 24). `grug_mobs`
stamps day rows with `min_light = 10` plus `day_toggle = true` (so torch light
at night never opens a day row), night rows with `max_light = 5` plus
`day_toggle = false`, and leaves any-time rows ungated.
Rows wholly below y = -40 are the exception: their family clock is ignored,
they retain only their explicit light filter, and they never receive a
`day_toggle`. Night rows receive `ceil(day aoc × 1.25)` while their interval
and chance stay unchanged; the Rift Spawn's surface row states its final
chance 4000 and cap 3 (the effective numbers of its Round 24 palette budget,
gone in Round 30). If a named zone exposes fewer than two explicit
night-role families, the policy admits its palette fallback: Zombie for
settled/war, Skeleton Archer for forest/mountain, Jungle Spider for jungle,
or Bog Ooze for swamp. Capitals retain empty palettes and never receive a
fallback; mobs already alive at a clock boundary are not despawned.

**`aoc` is per entity NAME, not per family** (mobs_redo counts objects
of that one name inside a 128-node sphere). Two spawn rows of the same
name — the Skeleton Archer's two node lists, a family's surface + cave
rows — share ONE budget; the per-biome tints are separate entities and
each carries the full row of its family. Until Round 30 the row `aoc` of
the species under the palette density budget (§0) was the species' weight
within its zone's budget; every row still running is its own cap.

Historical ring/filler calibration and its 16-day/12-night peak estimates are
preserved in [the archive](../archive/design/world-historical.md). They do not
bound the current roster or replace the Round 24 density rule in §0.

### WP37 closed; table interpretation

WP37 is closed (user decision 2026-09-29,
[WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
C1/C6). The original 2026-08-08 decision to cut surface density to 0.75 is
superseded by the Round 16 fightable-only change and the Round 24 ruling 27
per-zone density budget (§0), which raise density instead. Only the two
surface critter rows keep the old cut: **Bone Weevil** (both rows) and
**Bog Fowl** go from `chance` 2200 to **2933**, `aoc` unchanged (Round 26
Lane R). mobs_redo's `chance` is one spawn per N tries, so 0.75 × density
means `chance ÷ 0.75`; the old wording "multiply `chance` by 0.75" was
inverted and would have raised density. Cave rows (Giant Spider, Stone/Mesa
Golem, Cave Bat, Cave Crawler) and the Kraken Guard were never part of it.

The `chance` column below still prints the never-shipped values of
2026-08-08 for the other rows, computed with that inverted multiplication. It
is historical, not the runtime table; the shipped row values are in
`mods/ENTITIES/grug_mobs/*.lua` (their `-- §4 row` comments quote them).

| Mob | nodes (spawn on) | interval | chance | aoc | light | zones |
|-----|------------------|----------|--------|-----|-------|-------|
| Boar (all tints) | all six settled tops **+ forest litter, mesa_clay, gravel, snowblock, mud, sand** (core/inner filler); the **Jungle Boar** additionally carries **canopy litter** — deep-jungle patches in `inner` (§1.5) | 20 | 1125 | 5 | min 10 | core, inner |
| Rabbit/Hare | settled tops **+ the filler tops of its own continent** — Rabbit: forest litter, gravel, snowblock, mud, sand; Hare: mud, sand (no mesa_clay, §3.1 "the badlands carry no critter"). Split by a `territory_at` check | 20 | 1350 | 3 | min 10 | core, inner |
| Zombie | settled tops **+ forest litter, canopy litter, mesa_clay, gravel, snowblock, mud, sand** (night filler) | 20 | 1200 | 4 | max 5 (blight: any) | core, inner, war_coast |
| Wolf/Blightfang | coniferous litter, forest litter, bone litter, grass | 20 | 1125 | 5 | any | inner, outer |
| Hyena | dry grass, mesa_clay | 20 | 1125 | 5 | any | inner, outer |
| Jungle Lynx (Raptor slot) | rainforest litter **+ canopy litter** | 20 | 1125 | 5 | min 10 | inner, outer |
| Bear/Plaguehide | forest litter **+ silver litter, coniferous litter, grass** (Bear) / bone litter **+ blight_dirt, dry grass** (Plaguehide) | 20 | 2100 | 2 | min 10 | outer, coast |
| Jungle Ape | rainforest litter **+ canopy litter** | 20 | 2100 | 2 | min 10 | outer, coast |
| Giant Spider (all) | forest litter **+ silver litter, coniferous litter, grass** (Giant) / bone litter **+ blight_dirt, dry grass** (Pale) / rainforest litter **+ canopy litter** (Jungle) | 20 | 1800 | 4 | max 5 | outer, coast, underground |
| Stag/Gaunt Stag/Zebra | forest litter, bone litter, grass, dry grass | 20 | 1350 | 3 | min 10 | inner, outer |
| Skeleton Archer | bone litter, blight_dirt, settled tops (war coast) | 20 | 1500 | 3 | max 5 | outer, war_coast |
| Skeleton Raider | **every land top** + sand (war_coast-exclusive) | 20 | 1500 | 3 | max 5 | war_coast |
| Crag Eagle/Vulture | gravel, **snowblock**, mesa_clay | 20 | 1500 | 3 | min 10 | outer, coast |
| Stone/Mesa Golem (elite) | gravel, **snowblock**, stone, mesa_clay | 30 | 9000 (Stone Golem above y 300: 12000, Round 22 Phase 6 — bare high crags offer ~1.3× the hosts per area) | 1 | any | outer, coast, underground |
| Ram | gravel, **snowblock** | 20 | 1650 | 2 | min 10 | outer |
| Panther | rainforest litter **+ canopy litter** | 20 | 1350 | 4 | max 5 | outer, coast |
| Serpent | rainforest litter **+ canopy litter**, mud | 20 | 1350 | 4 | min 10 | outer, coast |
| Crocodile | mud (only) | 20 | 1350 | 3 | any | outer |
| Bog Ooze | mud | 20 | 1500 | 3 | any | outer |
| Parrot | rainforest litter | 20 | 1875 | 2 | min 10 | core, inner |
| Carrion Crow | **every land top** except sand (the Gull holds that slot); war_coast-exclusive | 20 | 1875 | 2 | min 10 | war_coast |
| Shore Crab | sand within 6 nodes of sea-level water, y 0–20 | 20 | 300 | 3 | any | level below 45 (§3.1) |
| Gull | sand | 20 | 1875 | 2 | min 10 | strait, war_coast, coast, **outer** |
| **Cave Bat** (critter) | stone **+ `group:grug_stratum`** | 20 | 2200 | 2 | max 5 | underground |
| **Cave Crawler** (critter) | stone **+ `group:grug_stratum`** | 20 | 2200 | **1** | max 5 | underground |
| **Bone Weevil** (critter) | bone litter / blight_dirt — **two rows, one entity name, one budget**; the row stamps the tint | 20 | 2933 | 2 | min 10 | (none — the node gates) |
| **Bog Fowl** (critter) | mud (only) | 20 | 2933 | 2 | min 10 | (none — the node gates) |
| **Poacher** | grass, forest litter, silver litter | 20 | 2200 | **4 at night** (base 3 ×1.25, ceiling) | night | exact named-zone palette |
| **Frost Stray** | gravel, snowblock | 20 | 2400 | **4 at night** (base 3 ×1.25, ceiling) | night | exact named-zone palette |
| **Sun-Dried Husk** | dry grass, mesa clay | 20 | 2000 | **5 at night** (base 4 ×1.25) | night | exact named-zone palette |
| **Song Bird** (critter) | silver litter | 20 | 2200 | 2 | day | Silverleaf exact family row |
| **Spiderling** | stone + `group:grug_stratum`, y −40…−100 | 20 | 2400 | 3 | max 5, clock ignored | underground |
| **Blood Bat** | stone + `group:grug_stratum`, y −101…−300 | 20 | 2200 | 4 | max 5, clock ignored | underground |
| **Stone Mite** | `group:grug_stratum`, y ≤ −700 | 20 | 2000 | 5 | max 5, clock ignored | underground |
| **Fox** | grass, coniferous litter, silver litter | 20 | 1900 | 3 | day | exact named-zone routes; L4 start gate |
| **Ibex** | coniferous litter, gravel, snowblock | 20 | 1900 | 3 | day | Dwarf column; L4 start gate |
| **Wild Turkey** (critter) | grass | 20 | 2100 | 2 | day | Dawnmere, Goldmead |
| **Plains Runner** (passive prey) | dry grass | 20 | 2100 | 2 | day | Sunscar |
| **Tapir** | rainforest litter, canopy litter | 20 | 1900 | 3 | day | Troll column; L4 start gate |
| **Giant Rat** | six settled tops / stone + `group:grug_stratum` | 20 | 1600 surface / 1800 cave | **5 at night** surface (base 4 ×1.25) / 4 cave | night surface; max 5 underground | all starts / y −40…−300 |
| **Scorpion** | dry grass, mesa clay | 20 | 1800 | **5 at night** (base 4 ×1.25) | night; plus a daylight row (min light 10, day toggle) with the same values, admitted only in Sunscar by the zone clock (Round 24) | Orc column and Shattered Line; L4 start gate |
| **Viper** | rainforest litter | 20 | 1800 | **5 at night** (base 4 ×1.25) | night; plus a daylight row (min light 10, day toggle) with the same values, admitted only in Kapok by the zone clock (Round 24) | Kapok and Raincall; L4 start gate |
| **Goblin Raider** | coniferous litter, gravel, snowblock, dry grass, mesa clay | 20 | 2400 | **3 at night** (base 2 ×1.25, ceiling) | night | exact Goblin-Raid palettes |
| **Goblin Slinger / Raider Hound** | same Goblin-Raid tops | 20 | 2400 | **2 each at night** (base 1 ×1.25, ceiling) | night | exact Goblin-Raid palettes |
| **Snow Leopard** | gravel, snowblock | 20 | 2100 | **4 at night** (base 3 ×1.25, ceiling) | night | Frostbarrow, Stormvault, Wyrmglass |
| **Wisp** | mud, silver/forest/bone/canopy/rainforest litter | 20 | 2200 | **4 at night** (base 3 ×1.25, ceiling) | night | exact named-zone routes |
| **Ashen / Gravewood Treant** | forest litter / bone litter | 20 | 2600 | **3 each at night** (base 2 ×1.25, ceiling) | night | exact tint-specific routes |
| Reef Lurker (elite crab) | sand within 6 nodes of sea-level water, y 0–20 | 30 | 1100 | 1 | any | level 45–60 (§3.1) |
| Kraken Guard | ocean water surface, open sea only (own check) | 60 | 12000 | 1 | any | (outside continents) |
| Bandits / Mirefolk | **no ABM** — camp anchor with **respawn slots** (world.md §4a): max 3–5, one refill per 30–60 s (Round 28 ruling 37), dormant catch-up; in a zone with a spawn recipe a recipe camp (§4.2) replaces the fire | — | — | 3–5 per camp | — | camp pos |
| Named rares | **no ABM** — scheduled spawner, 2–4 h respawn, broadcast | — | — | 1 | — | fixed routes |

**The Bandit Archer costs no spawn budget** (2026-09-16). It has no row of its
own: the bandit camp's slot roll picks it **1 in 3** per slot, so the camp is
still the 3–5 of the Bandits/Mirefolk row above and simply not all of one
kind. Both families count against that one head count
(`grug_mobs/camps.lua`), which is why an archer can never make a camp grow.
It is also why ruling 3's "more ranged mobs" reaches the INNER ring, where the
four pre-existing ranged mobs — Skeleton Archer, Skeleton Raider, Stone Golem,
Mesa Golem — never went: before this, a player met no ranged enemy at all
below roughly level 25.

Row notes:
- **Crocodile spawns on mud only.** "Water at mud" is not expressible:
  the spawn ABM's `nodes` list is the node it spawns ON and `neighbors`
  is an OR set, so "water AND mud" cannot be written. The lurking-in-
  water half of the verb is delivered by `floats` instead — the croc
  spawns on the mud bank and drifts into the pool.
- The **Skeleton Raider** reuses the Skeleton Archer's numbers
  (20 / 1500 / 3, night); it is the war-coast family, so its
  `war_coast`-only zone does all the gating and it needs no extra
  check. Its table is the skeleton table **plus heavy cloth 1/3**.
- **Parrot** and **Carrion Crow** are priced like the Gull, the other
  "flees" bird: 20 / 1875 / 2. Neither creates a new peak. The Crow's
  move to passive prey (§3.0) changed **no** spawn number — same row,
  same `aoc`, same zone.
- **The four critters of §3.0** (added 2026-08-08) were all authored at
  the WP6-style **interval 20 / chance 2200 / aoc 2**. The table above
  prints them **split by zone**, because the 0.75 density cut is a
  *surface* rule: the two surface rows (**Bone Weevil**, **Bog Fowl** — day,
  `min 10`, y 0…200) ship at **2933** since Round 26 (2200 ÷ 0.75), while
  the two `underground`-only rows (**Cave Bat**, **Cave Crawler**) keep their
  shipped **2200**, since they are excluded from the cut for the same reason the Giant Spider and
  the Golems are (see the header: cave pressure belongs to §4.1's depth
  pulse). There is also **one exception that is pure arithmetic**: the
  **Cave Crawler ships at `aoc` 1**. The underground cell was
  Zombie 4 + Giant Spider 4 + one Golem 1 = **9 / 9**; two cave critters
  at 2 each would make it 13 / 13, one over the world night peak of 12,
  so 2 + 1 lands it exactly on **12 / 12**. The two surface critters
  raise no cell above 14 against the day peak of 16
  (`wp6_spawn_budget.md` §2.2). The **Bone Weevil is deliberately ONE
  entity name with two spawn rows** — `aoc` counts per name, so the bone
  forest and the blight share its budget of 2 the way the Skeleton
  Archer's two node lists share theirs, while an `on_spawn` stamp still
  gives each biome its own tint. Two registrations would have been two
  budgets.

Current spawn budgeting retains per-entity-name local caps, throttled spawn
work (the three merged spawn ABMs above) and separate authored camp/rare
mechanisms. Round 16 expressly authorized
the fightable surface rate/cap increase without a new PERF campaign; old WP6
ring measurements cannot be promoted into fresh acceptance evidence.

### 4.1 The depth phase-in pulse (decided 2026-08-08)

**Approved future WP34 scope** (kept, for later; WP audit E5). Placement
geometry and the below-−1000 servant roster remain open in
`TODO-design-depth.md`; the pulse is not current runtime behavior. Existing
cave rows remain separate (since Round 30 merged into the one underground
spawn ABM, §4). The Land Guard and the Rift Spawn's deep row, which ship today
as ordinary rows below −1000 (`grug_mobs/land_guard.lua`, `rift_spawn.lua`),
join the pulse when it ships (WP audit E4); the Rift Spawn's surface row
stays.

Depth is a danger axis, not only a material axis (`combat_stats.md` §3,
`world.md` §4c). Because regular mobs cap at level 60, everything past
that cap has to be bought with **frequency**: a trickle that never lets
a miner finish clearing the room, so deep mining happens under permanent
pressure. This section owns that trickle.

**Mechanism: a player-centric pulse in a throttled
`register_globalstep`, never an ABM.** The reason belongs here, because
it is the constraint that rules out the obvious answer and it will be
re-discovered otherwise: `mobs:spawn` registers a **static** ABM whose
`chance` and `active_object_count` are fixed at registration time, and
**`aoc` counts per entity NAME inside a 128-node sphere, shared by every
row of that name** (see the note above §4's table). A second, deeper row
for an existing mob therefore cannot carry a larger budget than the
shallow one, and a rate that varies continuously *within* a band is not
expressible in the ABM model at all. A pulse also scales with player
presence instead of with how much air the mapgen happened to carve,
which is the right cost model at the 100-player target.

**The arrival curve** — one formula, safe by construction:

`arrivals_per_minute = min(R_MAX, max(0, (−y − Y0) · R_MAX / SPAN))`
with **Y0 = 300**, **R_MAX = 6/min**, **SPAN = 1700**.

| Depth | Arrivals/min |
|---|---|
| above −300 | 0 — the pulse does not exist here |
| −1000 | ~2.5 |
| −1500 | ~4.2 |
| −2000 and below | 6 (the ceiling) |

The `min()` is what makes the formula hold below −2000 instead of
growing without bound; the `max(0, …)` is what keeps the overworld free
of it. These are starting values, calibrated in a runtime test the way
`docs/research/wp6_spawn_budget.md` calibrated the ABM rows.

**Concurrent cap: 6 phase-in mobs per player.** This is the real safety
valve and the number the 100-player target actually cares about — it is
checked first in the runtime test. A modest concurrent cap with a high
arrival rate is also far cheaper than a swarm, and it is the shape the
design wants anyway: pressure, not a wall of bodies.

**Light-independent, and it may place a mob inside a sealed room.**
Wherever the pulse is active it ignores light entirely, and it is
allowed to put an arrival into a chamber the player dug out and walled
up. That is deliberate and it is the whole mechanic: dropping `max_light`
alone would only kill the *lit* cave, never the 3×3 bunker, because a
sealed room offers no spawn position at all — "there are no safe places
down here" has to be literally true or it is decoration. Every arrival
carries a **~2 s telegraph** (particle burst + sound) before it exists,
on the pattern of the elite wind-up of `combat_stats.md` §3, so the
player is warned by the world rather than ambushed by a rule.

**The roster is staged, and it needs no new mob to ship:**

- **−300 … −1000: the existing cave families** (§3.1's cave note —
  Zombie, Giant Spider, Stone Golem), levelled by `mob_level_at` like
  everything else. The fiction reads as the local dead being drawn
  upward from below rather than as an invasion, which is exactly what
  this band is.
- **below −1000: the deep band's own servants**, not local wildlife. The
  dedicated content roster plugs into this same pulse and accounting model;
  the ordinary surface/cave ABM rows do not become a second deep-spawn source.

The consequence is worth stating: because the shallow half reuses rows
that already exist, **the depth work can ship without a single new
mob**, and the servant roster becomes content that lands on top rather
than a blocker underneath.

**The ABM cave rows are untouched.** They stay exactly as §4's table
registers them (merged into one dispatching ABM since Round 30, rates
unchanged) and remain the ambient cave life; the pulse is a second,
independent source layered over them, and it is the only one that scales
with depth.

### 4.2 Spawn regions (Round 28 rulings 3, 34, 37, 38; Lane S1)

Zones are closed units with planned progression: spawn regions with fixed
levels, built by rule from the terrain, replace the continuous level field
for surface mobs. How the regions are built from a zone's recipe, and the
recipe format: [spawn_regions.md](spawn_regions.md). Implementation:
`mods/ENTITIES/grug_mobs/spawn_regions_core.lua` (the builder, shared with
the offline renderer), `spawn_regions.lua` (data, spawner, leaders, seams),
`camps.lua` (camp slots), `density.lua` (budget), `spawn_policy.lua` (ABM
gate, protected surface).

- **One data file per zone**, `mods/ENTITIES/grug_mobs/data/zones/<zone_id>.spawns.json`:
  either `palette` (the zone's named-zone palette of §4 /
  `world_zones.md` §8 as data: `families`, Lorindor's `exact_mobs` and
  `night_fallback`, the zone's `boar` tint and its `lookalikes` per family)
  or `recipe` (belts, kinds, camps, leaders, critters). A missing file means
  no palette and no recipe; a file without a recipe needs its palette (the
  load fails otherwise).
- **Trigger:** a zone without a recipe keeps its palette and the level field
  exactly as before. A zone with a recipe spawns its surface mobs only from
  its regions: its ABM rows keep only the recipe's critters (the Gull with
  its beach host) and, in Gravesalt, Skyglass and both islands (the zones
  whose palette had it), the Rift Spawn's surface row with its host ground
  and night clock (the catalogue keeps its spawning, Round 28 S2c); shore crabs
  and every other surface row are refused there, and since Round 30 a
  surface row no zone keeps registers no ABM at all (§4).
  Unchanged everywhere: underground rows and their depth level, water rows
  and swimmers (Kraken, Reed Angelfish), named rares, vendors, guards and
  guard posts, and the mapgen content. Since Round 28 (S2, W1) every one of
  the 38 zones has a recipe.
- **Ambient spawner.** Once a second per player (the players spread over
  the second in four slices), one random column in the ring 24–64 nodes
  around the player (24 = `mob_nospawn_range`) in a zone with a recipe: the
  highest natural ground node with air above within ±48 of the player (biome
  surfaces and their fertile and exposed variants; never leaves, wood or
  water), the region there (spawn_regions.md), one role of its kind's roster
  for the current clock (weighted), then the gates below; the mob stands on
  the ground node if its box fits. Camp regions spawn only through their
  slots. Crab roles keep the Shore Crab's host (dry `default:sand` within 6
  nodes of sea water). **Light** keeps the ABM rows' behaviour: the spot's
  natural light at noon must be at least 10 (no cave floor and no roofed
  room even under a lamp, while ground under a leaf canopy counts), a day
  pick needs light ≥ 10, and at night a hostile pick needs light ≤ 5, so
  torch-lit ground stays safe. **Blight ground** (Round 28 S2b): a
  zombie-family role set on `grug_nodes:blight_dirt` is sunproof
  (`light_damage = 0`, the legacy blight row's rule; one helper,
  `grug_mobs.blight_sunproof`), and by day a role that burns in daylight
  spawns only there, so a day roster may hold blight-ground zombies
  (Stillgrave). No per-mob row gate, domain or spawn check
  applies to a region spawn (the recipe is the authority). Every region mob
  carries `_grug_area = "<zone_id>/<kind id>"` and `_grug_spawn_clock`
  (both persisted) and a level rolled uniformly in its role's range (the
  belt's levels ∩ the role's catalogue levels), handed over right after the
  spawn (`grug_mobs.relevel`, `levels.lua`): a mob that has not levelled yet
  takes it on its first tick instead of the level field, the def floor and
  the cap; a mob that already levelled while activating (families with a
  composed look, such as bandits) has its level, stats and composed look
  re-derived at once. The tier never changes. Its wander leash is the
  ordinary one: 32 nodes around its spawn point (`combat_stats.md`).
- **Drift band.** No aggressive role spawns within 16 nodes of a road,
  bridge, village, start town or capital city (the spot and two rings of
  eight probes at 8 and 16 nodes, the same probe as the idle push of
  ruling 2); neutral roles and critters may.
- **Protected surface (ruling 3).** No ambient non-critter spawn — ABM row
  or region — on a road corridor or bridge (half width + 1, ±5 vertical), a
  village's building core, a start town's footprint or a capital city
  (asked only in zones whose zone session publishes a `capital` anchor).
  Camps and other POIs are not refused; critters may still appear in towns.
  An active housing claim refuses hostile spawns as before.
- **Density.** The §0 budget keeps its species-aware refill over the
  region's roster for the clock: point budget = the zone budget (15 by day,
  23 by night, × `ZONE_DENSITY`) × the kind's density class (`sparse` 0.5,
  `normal` 0.75, `dense` 1; rounded, never above the zone budget); a role's
  share = budget × its weight ÷ the roster's weight (rounded, at least 1);
  below share ÷ 1.5 (rounded up) a role always refills, up to its share only
  while fewer than the budget of free region mobs spawned at the current
  clock stand within the 128-node counting radius (day animals still about
  at dusk do not block the night), never above its share. Camp members,
  leaders, rares and bosses are not counted.
- **Camps (ruling 37)** — bandits, poachers and mirefolk of a recipe camp at
  the spot its region map picked by rule, or on the camp POI its recipe
  names (Round 28 S2; in its stated belt): `slots` members, each death
  refilled after a roll in `respawn` (30–60 s), a spot within 40 nodes of the
  camp centre and at least `min_player_distance` (16) from every player.
  Members roam free under the normal wander leash and carry the camp's tag
  and levels. The first look after a server start, once a player is within
  64 nodes of the centre, fills what is missing at once; later refills
  follow the slot queue with dormant catch-up (world.md §4a). In a zone with
  a recipe the bandit camp fires stay scenery (so a recipe camp on a POI is
  its only population); guard posts keep spawning.
- **Leaders (ruling 38)** at their rule-placed spot on every seed (a camp
  centre, or the cell farthest from roads of the largest region of a kind,
  with a fallback chain inside the belt and 32 nodes between leaders,
  [spawn_regions.md](spawn_regions.md) step 8; snapped to the
  nearest standable column within 4 nodes), with the level at the top of
  their region; `_grug_leader = true`, no area tag. A zombie-family leader
  stands on the nearest blight-dirt column within 16 nodes of its spot when
  there is one (a cell is typed by its majority biome, so the spot's own
  column may be another's), and any leader set on blight dirt is sunproof:
  Mortuary-Clerk Hush survives the day (Round 28 S2b). Every leader sub-type is
  1.15× the base model's size (whatever the catalogue's `size`) with 1.5×
  the HP of its level and tier (`grug_mobs.LEADER`, `subtypes.lua`). A
  leader spawns when a player is within 48 nodes of its spot (inside the
  player's active blocks: `active_block_range` − 1 mapblocks, so the unsaved
  leader is never dropped and re-added), none within 24, and its timer has
  run out; it is never saved with the map. A kill
  starts its `respawn` (300 s, game time, mod storage); a leader that
  vanished with its unloaded block returns on the next visit.
- **Seams** for other systems (`grug_mobs.spawn_regions`):
  `zone_has_recipe`, `get_area(zone, id)` and `area_roles(zone, id)` (an
  area a quest names is a kind or a camp), `zone_area_ids(zone)`,
  `leader(role)` (zone, level, respawn), `leader_pos(role)`, `map(zone)`,
  `region_at(x, z)`, `level_at(x, z)`, `describe(zone, target, mode, ref)` and
  `direction(zone, target, from_pos)` (spawn_regions.md, Directions).

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
| Elf | Silverwood | aspen_tree.mts node-substituted (**new** silverwood variant) + **new** great_silverwood.mts (treehouse base, §1.4) | grug_trees:silverwood_{tree,wood,leaves,sapling} — pale bark/leaf retint of aspen | silverwood planks, grug_nodes:marble (white stone retint; sold by dwarven vendors — trade hook) | elf forest only (the deep forest grows real aspen, §2) |
| Orc | Spikethorn Acacia | BASE acacia_tree.mts | default acacia | acacia planks, grug_nodes:adobe (dry-dirt+straw craft), bone block | savanna, badlands edge |
| Troll | Kapok | BASE jungle_tree.mts + emergent | default junglewood | jungle planks, mossycobble, grug_nodes:carved_totem (deco) | jungle edge, deep jungle |
| Undead | Gravewood | two original dead-tree .mts files (bent, forked wood with scattered grey dead leaves) | grug_trees:gravewood_{tree,wood,leaves,sapling} — blackened apple-log retint | gravewood planks, grug_nodes:cursed_cobble (mossycobble retint), bone block | blight, bone forest, swamp variant |

Missing assets summary: silverwood + gravewood textures (retints),
great_silverwood.mts treehouse schematic (WP13; the ordinary Gravewood schematics are shipped), adobe/
marble/carved_granite/thatch/bone block/cursed_cobble/carved_totem
node textures (retints). All 2D retints of MTG media (CC BY-SA 3.0) —
license-clean, keep attribution.

## 6. Base-material map (both continents feed all base recipes)

The universal metal/pick spine is available on both faction sides and never
requires a gem or cultural material: Bronze (Copper + Tin), Iron,
Steel (Iron Bar + mined Coal), Silversteel (Steel + Silver), Embersteel
(Silversteel + Emberglass) and Abyssal Steel (Embersteel + Abyssal Crystal).
Quartz is the universal T1 jewelry mineral. Emberglass and Abyssal Crystal are
universal fantastic progression resources rather than gems.

Gems are depth-tiered and the same in every region (Round 29,
`items_crafting.md` §3.0.1): T1 Citrine, T2 Jade, T3 Garnet, T4 Sapphire,
T5 Ruby, T6 Diamond, each only in its own tier rock, about one per 512 host
nodes there. Cultural material and signature wood follow the owning
`race_region` column:

| Faction | Race region | Cultural material | Signature wood |
|---|---|---|---|
| Accord | Human | Sunwax | Oak |
| Accord | Dwarf | Runeslate | Mountain Pine |
| Accord | Elf | Moonresin | Silverwood |
| Throng | Orc | Red Ochre | Spikethorn Acacia |
| Throng | Troll | Spirit Resin | Kapok |
| Throng | Undead | Gravesalt | Gravewood |

- Every culture has an ordinary home-region surface source sufficient for
  architecture, decoration, quests and trade. A concentrated T4 source also
  exists in its contested level-31+ zones or projected deep column. Foreign
  cultural material is optional PvP-counter input, never base progression.
- At y = −701 and below, territory is contested but the surface race region
  continues to select cultural deposits. Players can mine through
  opposing deep columns without gaining ownership of the surface above.
- Abyssal Crystal begins in T5 on both sides before a T6 pick is required. The
  initial density target is approximately one crystal per 2,048 eligible host
  nodes through T5/T6. Ordinary ores, Diamond and Abyssal Crystal receive +25%
  density at y = −1500..−1999 and +50% at y ≤ −2000, capped and implemented as
  placement rather than respawn.
- The Wyrmglass Crown and Stormscale Summit apex camps have no renewable gem
  sockets: renewable ores are removed entirely, camps included (user decision
  2026-09-29, WP audit E5).

| Material | Tier | Accord sources | Throng sources |
|----------|------|------------------|---------------|
| Light leather `[leather]` | 1–15 | boars | plague boars |
| Feather (fletching) | 20–60 | crag eagles, carrion crows | vultures, carrion crows |
| Leather `[leather]` | 10–45 | wolves, stags | hyenas, jungle lynxes, blightfang wolves, zebras, panthers* (*fringe gives A access too) |
| Heavy leather `[leather]` | 25–60 | bears, elder bears, rams | plaguehide bears, jungle apes |
| Scaled hide `[leather]` | 25–60 | crocodiles (swamp), serpents (fringe) | crocodiles, serpents |
| Sleek pelt (Leatherworker T5/T6 input) | 38–60 | panthers (jungle fringe) | panthers (deep jungle) |
| Linen **scrap** (trash tier, sells; not the cloth) | 1–30 | zombies, skeletons | same |
| Linen cloth | 10–30 | home-zone **bandit camps**, mirefolk | same |
| Heavy cloth | 25–45 | frontier bandit camps, war-front raiders | same |
| Raw silk (`grug_mobs:spider_silk`; Tailor T3+ — silkweave, silk and stormweave bolts) | 25–60 | deep-forest/fringe spiders | bone-forest/jungle spiders |
| Food plants (everyone, farmable later) | all | potatoes/corn (meadows), berries (hills, elf forest), apples, melon (fringe), meat/fish everywhere | corn (savanna), melon (jungle), berries via forest patches, meat/fish |
| Food plants, **found-only** (everyone, never farmable) | 25–60 (wild cocoa 51–60) | mushrooms (deep forest/swamp), wild cocoa (The Skyglass Canopy — shared contested front, §2), rock salt (coast beaches) | mushrooms (bone forest/swamp), wild cocoa (The Skyglass Canopy — shared contested front; Stormscale Summit — offshore island bonus, §2), rock salt (coast beaches) |
| Healing herbs T1 (Alchemist) | 10–25 | gravemoss (pine hills) | gravemoss (blight) |
| Healing herbs T2 | 25–45 | dragonweed (crags, deep forest) | dragonweed (badlands, bone forest) |
| Healing herbs T3 | 45–60 | crimson lotus (jungle fringe, The Skyglass Canopy) | crimson lotus (deep jungle) |
| Spices T1 (everyone gathers; Alchemist + Cooking use) | 10–25 | sunleaf (meadows, elf forest) | sunleaf (savanna, jungle edge) |
| Spices T2 | 25–45 | marshbloom (swamp) | marshbloom (swamp) |
| Spices T3 (stormkelp also weaves the Tailor's T6 stormweave bolt, `items_crafting.md` §3.5) | 45–60 | stormkelp (coast) | stormkelp (coast) |
| Alchemy reagents (mob) | 25–60 | venom gland/sac, slime gel, bear claw | identical (shared tables) |
| Woods | all | oak, pine, silverwood (+jungle at fringe) | acacia, kapok, gravewood — all `group:wood` |
| Universal ores/progression crystals | depth axis | own-side continental underground + applicable generic drops | same base density |
| Gems | depth axis (one per tier rock) | all six, each in its own tier rock | same |
| Cultural materials | surface + contested concentration | Sunwax, Runeslate, Moonresin | Red Ochre, Spirit Resin, Gravesalt |

Every row has at least one source per continent. Race woods are
deliberately asymmetric (identity); base recipes accept `group:wood`.

**Two rows moved with the critter rework of §3.0 (2026-08-08).** *Light
leather* lost rabbits and hares — critters drop food only — and the row's
"rams" entry was stale anyway (§3.1 gives the Mountain Ram **heavy**
leather, which is why that family is prey and not a critter). The Boar
carries the tier alone now, and it exists on both continents, so the
"one source per continent" rule holds. *Feather* is a row for the first
time: it used to fall off the Gull and the Parrot, i.e. off two 1 HP
critters, and now comes off the **bird-of-prey table** (§3.2) plus the
Carrion Crow, which is prey rather than a critter — so arrow fletching
is behind a fight on both sides.

**Cloth supply, precisely** (resolved in WP6): zombies and skeletons
drop **linen scrap**, which is vendor trash, *not* the tailoring
material. The cloth line comes from **humanoids** — home bandit camps for
linen, frontier bandit camps for heavy cloth, and mirefolk camps for linen.
The camp supply is therefore the whole cloth economy, and WP6 ships **12
deterministic bandit camps**. WP40 migrates them to the catalog's exact two
per race region: one home-zone linen camp and one frontier heavy-cloth camp
(`world_zones.md` §8). The
patch-driven camps of §1.4 — the ones rolled per settlement candidate —
land with WP13's structure pass and thicken that supply; they do not
create it.

## 7. Asset shopping list (models; licenses per docs/research/assets/mobs_animals.md — re-verify in source repo before import, AGENTS.md rule)

| Mob(s) | Source | License (code/media) | Work needed |
|--------|--------|----------------------|-------------|
| Boar, Zombie | already vendored | GPLv3 / CC BY-SA 4.0 | retints only |
| Rabbit, Parrot, Skeleton, Wolf, Slime→Ooze, Squid→Kraken, Polar bear→Bear, Sheep→Ram, **Bat→Cave Bat, Silverfish→Cave Crawler/Bone Weevil, Chicken→Bog Fowl** | VoxeLibre mobs_mc | GPLv3 / CC BY-SA 4.0 | mcl_mobs→mobs_redo port (pattern known), retextures; the four critters of §3.0 are **zero-download** — the meshes were already on disk |
| Spider, Stone Golem | mobs_monster (TenPlus1) | MIT / CC BY 3.0 | drop-in mobs_redo, retint |
| Hyena, Zebra, Eagle/Vulture, Leopard→Panther, Cobra→Serpent, Crocodile, Monkey→Ape | animalworld (mt-mods) | MIT / MIT (**sounds: verify per file, freesound CC**) | mobs_redo-native; texture pass toward 16px style |
| Reindeer→Stag, Song bird→Gull/Crow | animalia (ElCeejo) | MIT / MIT | asset harvest, re-register on mobs_redo, remap anim frames |
| ~~Raptor~~ → **Jungle Lynx** | paleotest media unverifiable per file → big-cat retint of the panther mesh (animalworld, MIT) | MIT / MIT | fallback executed in WP6, retint only |
| Bandit, Mirefolk | character.b3d + skins | LGPL 2.1 mesh; LotT skins CC BY-SA 3.0 | 2D skin work (mirefolk fully custom) |
| Shore Crab / Reef Lurker | Liil/Wilhelmine crab (`grug_mobs` LICENSE-media §9) | MIT / MIT | shipped; spawn rule §3.1/§4 |
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
3. **Mirefolk is in** (custom 2D skin work). The Shore Crab was first
   deferred until a licensed model was sourced; it has since shipped with
   the MIT Liil/Wilhelmine crab model, together with its elite Reef
   Lurker, under the §3.1/§4 rows.
4. **Jungle fringe reuses the deep Troll jungle nodes 1:1** on the Accord
   side (max drop symmetry, zero new assets). Since 2026-08-11 this names
   `grug_deep_jungle` explicitly: target top
   `grug_nodes:dirt_with_canopy_litter`. **Done with WP40 R7**: the manifest row
   `grug_jungle_fringe|grug_nodes:dirt_with_canopy_litter`
   (`grug_mapgen/wp40/r7_r6_manifest.lua`) is the shipped ground, and the
   fringe's jungle trees and junglegrass place on it.
5. **The boar's "charges"** is implemented as a **mid-range rush**, not
   a wind-up gallop: the same impulse the panther's pounce uses,
   flattened horizontally, fired at 4–10 m with an 8 s cooldown. One
   verb helper serves both families, and the boar reads as a charger
   without a second state machine.

## Round 17 disposition contract

Creature families (or explicitly named variants) have fixed aggressive,
neutral or critter dispositions. Neutral creatures do not initiate player
combat, but retaliate; ordinary starter Boars are neutral. Fightable Rats are
aggressive, while true harmless critters retain their behavior. Grazer/prey
families remain plausible neutral wildlife; hostile humanoids/undead/monsters
are aggressive. Higher-level areas predominantly contain aggressive species,
without changing a family's temperament by location or imposing exact ratios.
No total-density/range/HP/per-family-damage increase is part of this roster
change. The global non-player damage scale is specified in `combat_stats.md`.

The current family classification is:

| Disposition | Existing families and named variants |
|---|---|
| Neutral | Boar, Plague Boar, Jungle Boar; Ibex, Tapir, Plains Runner; Stag, Gaunt Stag, Zebra; Mountain Ram; Carrion Crow; Shore Crab, Reef Lurker |
| Aggressive | Fox; Giant Rat; Bear, Plaguehide Bear; Wolf, Blightfang Wolf; Hyena; Jungle Lynx, Panther, Snow Leopard, Speargrass Tiger; Crag Eagle, Vulture; Crocodile; Jungle Ape; Giant Spider, Jungle Spider, Pale Spider, Spiderling; Serpent, Viper, Scorpion; Blood Bat; Goblin Raider, Goblin Slinger, Goblin Hound, Goblin Miner, Goblin Miner Slinger; Bandit, Bandit Archer, Poacher; Mirefolk; Skeleton Archer, Skeleton Raider, Zombie, Frost Stray, Sun-Dried Husk; Stone Golem, Mesa Golem, Stone Mite, War Construct; Ashen Treant, Gravewood Treant; Bog Ooze, Bog Witch; Wisp, Glowwing, Ember Wisp; Crystal Shard, Lava Flan; Oerkki, Rift Spawn, Dungeon Master; Kraken; Ice Dragon, Jungle Wyvern, Ice Whelp, Storm Whelp; kings |
| Critter | Rabbit, Hare; Wild Turkey; Parrot, Gull, Song Bird; Cave Bat, Cave Crawler; Bone Weevil, Bog Fowl; Reed Angelfish |
| Independent role | Accord/Throng guards, land guards, royal guards and peaceful settlement NPCs |


## Round 21 targeting and freshwater life

Boars retain their existing physical collision box and movement behavior. Their
yaw-rotated targeting box is separately padded to cover the visible body:
`{-0.62, -0.06, -0.76, 0.62, 1.04, 0.76}`. The base, plague and jungle boars
share this correction. Other families are adjusted from specific playtest reports.

Reed Angelfish are passive freshwater critters, with no XP or quality loot; a
kill drops exactly one ordinary Raw Fish (better fish only from fishing). Like
the Kraken Guard they never leave the water: no climbing onto a bank, shore
plants and waterlilies do not count as water, and a swimmer displaced out of
the water swims back if water is adjacent or otherwise flops in place. Their
habitat is planned natural inland water, with source water at the spawn
position and above it, next to a sand bed, above the column's natural bed:
lakes (and bays) at any altitude, not rivers, whose river water is another
liquid, and not cave pools. They use the existing critter spawn machinery:
interval 30s, chance 1/4000, local active-object cap 2, no fixed height cap
(y -30 to the 600 flight ceiling; Round 22 Phase 5). They add ambient
movement, not a fishing-resource system.

## Round 28 sub-types and loot by band

Rulings 35 and 36 (`docs/planning/round28-questing-leveling-plan.md`); data
formats in the design frame §4.1–§4.3. All of it is data in
`mods/ENTITIES/grug_mobs/data/` (`subtypes.json`, `tints.json`,
`items.json`, `drops.json`), loaded by `grug_mobs/subtypes.lua` after every
mob file. A missing or empty file means no data, and without data every mob
behaves as before. The shipped files are copies of the reviewed design
catalogue (`docs/planning/round28/design/catalog/`; Lane E1): 188 sub-types
(49 leaders), 9 tints, 119 items (94 signatures, of which 89 new, and 25
existing generic materials) and 24 drop families. The catalogue is the
source; edit both together.

**Sub-types.** Each record registers `grug_mobs:<role>` as a copy of its
`base` registration's original definition: same mesh, animations, verbs,
speeds and senses, and the base's static drops as the fallback. A role must
not collide with an existing entity name, and the base must be an ambient
mob (not a sub-type, guard, king, dragon or other fixed-level actor), and an
aggressive sub-type needs a base with an attack (an aggressive copy of a
critter would chase players and never strike); a violation stops the load.
Everything else of the base comes along, including its sun burn (zombie
sub-types burn like the Zombie).

- **Size:** `size` multiplies `visual_size` and the collision and selection
  boxes together (a rotated selection box stays rotated). An elite sub-type
  then gets the elite ×1.4 on top, like any elite.
- **Disposition:** `neutral`, `aggressive` or `critter`, added to the
  disposition table under the new name (an existing name is an error); the
  disposition forces its fields as for every mob (neutral: no acquisition,
  no group alert; critter: the critter tier).
- **Tier, name and leader are authored.** `tier` (`normal`/`elite`) is
  fixed: no spawn roll of the base family may promote a sub-type (the
  1-in-10 Elder Bear and Silverback rolls only apply to the base names), and
  the display name is put back if a roll renamed it. `leader: true` marks a
  named leader (normal tier in 1–30).
- **Names (user, 2026-10-02):** words that announce size, age, strength,
  temperament or wits appear only on start-zone roles (levels 1–10), as one
  ladder shared by all six starts: Small/Young for neutral animals,
  Large → Aggressive → Monstrous for hostile animals, Braindead → Sluggish →
  Monstrous for zombies and husks, Confused for outlaws and the start
  chiefs. Everywhere else every display name (including `display_by_zone`
  variants) belongs to one role, avoids base-mob and rare names, has at most
  three words (named leaders excepted) and describes the creature in its
  place; roles of one family sharing a zone differ in more than their first
  word. The name tag colour shows disposition. Full rule and ladder:
  [Round 28 design frame §5](../planning/round28-design-frame.md#5-naming);
  `tools/r28_names/build_review.py --check` enforces it on the data.
- **Levels:** `levels` [lo, hi] clamps the level the mob gets at its first
  step (the floor is also the fallback where the level field has no value);
  a spawn region's belt narrows it further (§4.2).
- **Zone name and tint:** `display_by_zone` and `tint_by_zone` are read from
  the zone of the spawn position on the first activation; the zone is
  persisted with the mob. A tint id from `tints.json` is either a baked
  texture that replaces the body texture (every material slot carrying the
  mesh's first non-blank texture; blank overlay and held-item slots keep
  theirs) or a texture modifier appended to it. Elite and rare tints layer
  on top. The entity name stays the role, so quest kill matching, density
  weights and spawn palettes stay per role.

**Families.** A sub-type belongs to its `family`; an existing mob's family is
its own role (`zombie`, `giant_rat`, `boar` …), so a design puts sub-types
next to an existing mob by naming that role as the family. Group alert, the
pack call and the camp swarm answer the same entity name as before and, in
addition, mobs of the same family when both take part in group alerts
(`group_attack`). A neutral mob never answers or calls anyone, not even its
own name (a neutral sub-type of a pack or swarm family stays a single pull;
`combat_stats.md` §4).

**Loot items.** `items.json` entries of kind `signature` and `quest` whose id
is not registered yet become craft items (`grug_mobs:` ids; an id in another
mod's namespace must be registered by that mod). Description = the name plus
the flavour line; the inventory image is the item's own icon
`<mod>_<name>.png` when `grug_mobs/textures/` ships one (all 89 new catalogue
items do, the Round 28 art set recorded in `docs/planning/round28/art/`),
otherwise a tinted placeholder; the `icon` brief stays on the item as
`_grug_icon_brief`.
Signature items are mob materials (`grug_material`); their catalogue `tier`
(1–6) is both their vendor price in copper and their ingredient tier
(registered by `grug_professions`, so recipe books show it and no enchant
takes one above its own tier). Quest items have no price and no tier. The
trader drop audit covers the band tables too. `generic` items are
existing ones; `reagent` items belong to `grug_professions`. Any other kind is
a load error.

**Loot by band.** A mob's drop family is its sub-type's `drops` (default its
family), else its role. The band is `floor((level − 1) / 10) + 1` (1–10 → 1,
… 51–60 → 6). Where `drops.json` has rows for the family and band, those rows
replace the mob's static drops (chance 1 in N, `min`/`max`); a leader (the
sub-type's `leader` flag or a placed leader's `_grug_leader`) adds the
family's `leader_bonus`. A family without a table, or without rows for that
band (missing or an empty list), keeps the definition's static drops (a
sub-type's are its base's). The player-tag rule, the
profession drop hooks and quality loot apply unchanged; a table can give
drops to a mob that has no static drops.

Seven drop families are named after existing roles, so those existing mobs
(not only their sub-types) use the band tables in the bands listed, and their
static rows above apply only outside them:

- **Boar** (bands 1–3): meat 1/1 ×1 (was ×1–2), light leather 1/2, the band's
  tusk 1/3 (Boar Tusk, Ridged, Gnarled).
- **Zombie** (all bands): see its row above; the guaranteed flesh becomes 1/2
  and the bar 1/10 becomes the band's tier bar at 1/50.
- **Fox** (bands 1–3): meat 1/1, leather 1/3 (was 1/2), Fang 1/3 kept in bands
  1–2 (quests ask for it), the band's tail 1/3 (Fox Tail, Brush, Silver-Tip).
- **Bear** (bands 3, 4, 6): meat 1/1 ×1 (was ×2), heavy leather 1/3 (was
  1/2), Bear Claw 1/3 (was 1/4), from band 4 also the band's claw 1/3.
- **Crocodile** (bands 2–3): meat 1/1, Crocodile Tooth 1/3 and the band's
  tooth 1/3; no guaranteed Scaled Hide any more.
- **Wisp** (bands 2–4): the band's mote 1/3 (it had no drops).
- **Mirefolk** (bands 2–3): linen cloth (band 2) or heavy cloth (band 3) 1/2,
  the band's reed pearl 1/3, Shiny Scale 1/4; no Raw Fish any more.

**Quest-only drops** (ruling 41) use
`grug_mobs.register_participant_drop_hook(fn)`: once per kill with at least
one participant eligible for kill credit, `fn(self, names, death_pos)`
receives the sorted names of the players the quest kill credit receives
(online, within 40 m, not of the mob's own faction) and gives items itself.

Code seams for other lanes: `grug_mobs.family_of(name_or_role)`,
`grug_mobs.subtype(name_or_role)` (the parsed record or nil),
`grug_mobs.level_band(level)`, `grug_mobs.read_data_json(file)`.
