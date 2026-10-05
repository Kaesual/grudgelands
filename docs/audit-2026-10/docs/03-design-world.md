# D3 — World design documents vs mapgen and mob code

**Scope.** The documents checked are:

- In `docs/design/`: `world.md`, `world_zones.md`, `world_map.md`, `world_preparation.md`, `spawn_regions.md`, `settlements.md`, `biomes_mobs.md`, `story.md`, `scout.md`, `boats.md`, `mounts.md` and `home_travel.md`.
- In the repository root: `TODO-design-depth.md` and `TODO-design-nether.md`, only where they claim a current state.

**Baseline.** `0f169898` (main).

**Method.** Read-only. I read each document and pulled out its checkable claims: numbers, names, file and function references, and "exists / is absent" statements. I checked each claim against the live code.

**Which mapgen is live.** `mods/MAPGEN/grug_mapgen/init.lua:12` loads only `wp40/r7_loader.lua`. **wp40 is the live mapgen.** `wp13/` is **still live as a building library**:

- `wp40/r7_wp13_library.lua` and `wp40/r20_poi_blueprint.lua:36` call it for the start towns, the capital districts, `city_edge.lua`, `dressing.lua` and the Round 36 `decor_kit.lua`.
- `wp13` is therefore not dead code. The six start waypoint pads in `wp13/{hearthpine,dawnmere,silverleaf,stillgrave,sunscar,kapok}.lua` match `settlements.md` exactly.

**Mob comparison.** The mob checks compare the docs' zone tables with the 38 spawn recipes (`mods/ENTITIES/grug_mobs/data/zones/*.spawns.json`), resolved to base mobs through `data/subtypes.json`. The comparison table is in the appendix.

**Known gaps.** `docs/maintenance/findings.md` (2026-09-29) and `BACKLOG.md` are the reference list of known gaps. They are not re-reported here; where findings.md itself is now stale, that is noted.

**Work split.** Three helper passes did parts of the work:

- mounts, boats, home travel and scout;
- world map, preparation, story and the TODO files;
- `world_zones.md` against wp40.

The lane owner spot-checked their key findings before including them.

## Verdict

| Document | Verdict |
|---|---|
| `world.md` | **mostly current**. The numbers in §1–§6 match the code (day/night, light floor, tier rock, road corridors, respawn slots, dragon arena, rift, waypoints, deep ore bonus). Stale: capital-zone hostility, the capital band after Round 36 W3, the WP13 status, a few §7 notes. |
| `world_zones.md` | **mostly current**. All 38 zones (ids, hubs, bands, biome weights, relief ids), the 118 anchors, PvP POI positions and spacing, road widths, `C_STEP` 0.5, the capital and start bands and the Round 36 W3 cover match. Stale: about a dozen pre-cutover passages ("target … until Phases 3–5 land", the 600×500 start core, native-ore count, sea depths, the R7 cutover text, slot vocabulary, a dead relief table, race "terraces"), capital-zone hostility (DW-01) and the §8 mob notes (DW-04, DW-16). |
| `world_map.md` | **mostly current**: one internal refresh-rate contradiction, a stale river-width paragraph |
| `world_preparation.md` | **current** |
| `spawn_regions.md` | **current** (every constant checked: cell 32, sub-grid 4, camp radius 40/24, leader spacing 32, place spacing 64, cache format v2, key files, the four quest places) |
| `settlements.md` | **mostly current**. The Round 36 decor pass, benches and band ground cover are reflected. Stale: "100-anchor roster" and the WP13 roster note. |
| `biomes_mobs.md` | **partly stale**. §0, §2, §4.2 and the Round 28 sub-type sections are current (counts 205/49/10/12/120/24 verified). The zone-placement tables from the palette era (§0 Round 18 table, §3.1 placement words, Round 8 "Zones" columns) no longer describe the recipes. Bog Witch is called absent. Capitals are called empty. |
| `story.md` | **mostly current**. §2a matches. The older §1–§3 bullets describe a main line at level 30 and V1 "breaches" that do not exist. |
| `scout.md` | **mostly current**: one stale crit number, one wrong HUD label, many drifted line references |
| `boats.md` | **current** |
| `mounts.md` | **mostly current**: one self-contradiction, drifted vendored line references |
| `home_travel.md` | **current** (one small omission) |
| `TODO-design-depth.md` | **current**: the pulse is unbuilt and WP34 is open |
| `TODO-design-nether.md` | **mostly current**: nothing claims Nether content in V1 or in code; one phase contradiction |

Summary:

- **Biggest mismatch: capital zones.** Six places across three docs say a capital zone has "no hostile ambient enemies" or "empty palettes". Since Round 28 every capital zone has a spawn recipe with night zombies, bandits, a camp and a named leader outside the city. Only the city footprint is spawn-protected.
- **The Round 36 world changes reached the docs, with one miss.** The treeless-band ground cover (W3), the road `C_STEP` 0.05 → 0.5 change and the decor pass/benches are reflected in `settlements.md` and `world_zones.md`. `world.md` §3 still says the capital band "carries no trees and no ground cover".
- **The palette-era mob placement tables in `biomes_mobs.md` are out of date.** The Round 28 recipes decide placement now. Examples: the Husk is in 13 zones, not 3; the War Construct is no ambient mob, only two leaders; Stone Mite sub-types live on the surface; Mesa Golem never appears on the surface.
- **`biomes_mobs.md` says the Bog Witch is deferred and absent.** It has shipped since Round 9 and has five recipe roles in three zones. The same doc lists it as a current family elsewhere.
- **The WP13 status is stale in three places.** They still say "BACKLOG WP13 tracks the remaining roster", but WP13 is delivered (`BACKLOG.md:175`). `world.md` §9 still says only 6 villages, 6 outposts and 6 bandit camps are delivered.
- **findings.md D4 is stale.** The Kraken has view range 40 and its deep-ocean pursuit has been in the code since Round 29.
- **`story.md` §1–§3 predate the V1 main line.** They describe a level-30 main-story gate and "breaches / twisted vegetation" in V1. The main line runs 41–60 and the only V1 corruption is the rift crack plus ten ember-tinted sub-types.
- **Small numeric drift:**
  - `scout.md` gives 17.8 % crit at level 60; the code gives 11.4 % after the Dex→Crit halving.
  - `world_map.md` gives two different refresh rates.
  - Several line references in `biomes_mobs.md`, `scout.md` and `mounts.md` point at moved code.
- **No document places Nether content in V1 or in code.** `grep -ri nether mods --include=*.lua` finds no Nether content.

## Mismatch table

| ID | Sev | Category | Direction | Doc location | Short description |
|---|---|---|---|---|---|
| DW-01 | High | Outdated / Contradiction | doc stale → fix doc | world.md:96; world_zones.md:169-172, :969/974/979/990/995/1000, :1465-1467; biomes_mobs.md:877-878 | Capital zones are called hostile-free with empty palettes. Since Round 28 all six have hostile recipe populations outside the city. |
| DW-02 | Medium | Contradiction | doc stale → fix doc | biomes_mobs.md:709-713 | Bog Witch is called "deferred … absent"; it has shipped since Round 9 and has 5 recipe roles in 3 zones |
| DW-03 | Medium | Outdated | doc stale → fix doc | world.md:416-419 | The capital band "carries no trees and no ground cover"; Round 36 W3 grows ground cover there |
| DW-04 | Medium | Outdated | doc stale → fix doc | biomes_mobs.md:82-88, :660-664, :670-707; world_zones.md:1017-1018 | Palette-era zone/family placement tables contradict the Round 28 recipes (Husk, War Construct, Stone Mite, Mesa Golem, Skeleton Archer, Crow) |
| DW-05 | Medium | Outdated | doc stale → fix doc | world.md:6-8, :1027-1031, :989-990; settlements.md:33-34 | "BACKLOG WP13 tracks the remaining roster" and "6 villages/6 outposts/6 camps delivered"; WP13 is delivered |
| DW-06 | Medium | Outdated | doc stale → fix doc | findings.md:15 (D4) | Says the Kraken has view_range 20 and no pursuit; the code has had 40 and the deep-ocean pursuit since Round 29 |
| DW-07 | Medium | Outdated | doc stale → fix doc | story.md:39-46 | The main line starts "local and mundane" and puts a main-story gate at level 30; the code's main line is 41–60 |
| DW-08 | Medium | Unclear/Agent-trap | unclear → Jan decides | story.md:27-28, :129-134 | V1 "scorched breaches, twisted vegetation" and "Nether corruption"; none exist, V1 has the rift only |
| DW-09 | Medium | Outdated | doc stale → fix doc | scout.md:46-48 | Scout crit at L60 is given as 17.8 %; the current formula gives 11.4 % |
| DW-10 | Medium | Contradiction | doc stale → fix doc | world_map.md:42 vs :126-127 | Live refresh "twice per second" vs "every 2 seconds" (the code uses 2 s) |
| DW-11 | Medium | Contradiction | doc stale → fix doc | TODO-design-nether.md:61-62 | The Nether dragon lord is called a "Phase 3 capstone"; world.md and ROADMAP say V2 / Phase 2 |
| DW-12 | Low | Contradiction | doc stale → fix doc | world.md:469 | Outposts are a "graveyard/respawn point"; V1 respawn is innkeepers only |
| DW-13 | Low | Outdated | doc stale → fix doc | world.md:968-969 | The human quest-XP bonus is called a "latent hook"; it is active |
| DW-14 | Low | Outdated | doc stale → fix doc | world.md:986 | "only 3 classes"; there are four (Scout) |
| DW-15 | Low | Outdated | doc stale → fix doc | settlements.md:640 | "The 100-anchor roster"; the roster is 118 anchors since Round 31 |
| DW-16 | Low | Outdated | doc stale → fix doc | world_zones.md:1019 (§8.3 Skyglass row) | The Rift Spawn surface row also runs in The Skyglass Canopy; the zone row omits it |
| DW-17 | Low | Unclear/Agent-trap | doc stale → fix doc | world.md:766-771, :521-524 | Unbuilt T6 lava lakes and war-front squads are written in the present tense |
| DW-18 | Low | Bloat/Outdated | doc stale → fix doc | biomes_mobs.md:180-182, :571, :581, :593, :625, :637, :660; world.md:496-499 | Ring vocabulary (core/inner/outer/coast/war coast) and the "24 ring outposts" note no longer exist in the code |
| DW-19 | Low | Outdated | doc stale → fix doc | biomes_mobs.md:37, :477 | `levels.lua:89-95` → the predicate is now at :101-103; the formula is at :131 |
| DW-20 | Low | Contradiction | doc stale → fix doc | mounts.md:92 | The level is "both the visibility and purchase gate"; the same doc and the code list every tier, greyed |
| DW-21 | Low | Wrong | doc stale → fix doc | scout.md:288 | HUD label `Sprint (+50% Speed)` does not exist; the code has "Sprint" / "+50% movement speed" |
| DW-22 | Low | Unclear/Agent-trap | doc stale → fix doc | scout.md:116-118 | Present-tense "bowyer sells arrows … no bracket tab" contradicts :361 and stock.lua (the bowyer sells the T1 bow) |
| DW-23 | Low | Missing | doc stale → fix doc | scout.md §2/§6.2; mounts.md §3 | Undocumented: the ×0.5 move stance while drawing a bow; a stun dismounts |
| DW-24 | Low | Outdated | doc stale → fix doc | world_map.md:18-21, :40-45, :127-131 | River stroke widths, "selected view" wording and the live-signature list are behind the code |
| DW-25 | Low | Outdated | doc stale → fix doc | story.md:48 | Reference "ROADMAP 1.5" does not exist |
| DW-26 | Low | Unclear/Agent-trap | unclear → Jan decides | TODO-design-nether.md:51-52 | A proposed "Rift-Touched" state collides with V1's rift and Rift Spawn |
| DW-27 | Low | Outdated | doc stale → fix doc | home_travel.md:20-21 | The innkeeper map markers are own-faction only (and there is a "Your Claim Stone" marker) |
| DW-28 | Low | Outdated (line refs) | doc stale → fix doc | scout.md:70,76,77,117,271,440,470,475,528,544; mounts.md:217,257,433-440 | Line references into `kits.lua`, `stats.lua`, `stock.lua`, `mobs/api.lua`, `mobs/mount.lua` and `guard.lua` have drifted |

| DW-29 | Medium | Outdated | doc stale → fix doc | world_zones.md:16-17, :263-266, :540-542, :1105-1106 | "The text describes the target; the running mapgen follows as Round 22 Phases 3–5 land": the target is live (R7 cutover) |
| DW-30 | Medium | Outdated / Contradiction | doc stale → fix doc | world_zones.md:345-346, :376, :407; world.md:159-161 | The "600 by 500 dry start core" does not exist; the code has a 152-node in-zone town square plus a ~300-node water keep-out |
| DW-31 | Medium | Contradiction | doc stale → fix doc | world_zones.md:1667-1669 vs :906-910 | Native registration "one gravel blob + five strata" omits the three Round 24 decorative-nest blobs (9 native ores) |
| DW-32 | Medium | Outdated / Bloat | doc stale → fix doc | world_zones.md:1694-1697 | "remain disabled until one atomic production cutover": the cutover happened |
| DW-33 | Medium | Wrong | doc stale → fix doc | world_zones.md:581-583 | Bays "6–10 deep", deep ocean and channels "24 deep"; the code has one shelf profile down to ~33 below sea level; 24 is only the outside-bounds floor |
| DW-34 | Medium | Outdated | doc stale → fix doc | world_zones.md:1759-1762 | The slot vocabulary lacks the Round 31 `pvp_fortress`, `pvp_accord_low/high` and `pvp_throng_low/high` slots |
| DW-35 | Low | Missing | doc stale → fix doc | world_zones.md:1703-1708 | Public `grug_zones` methods lack `hard_protection_kind_at` and `hard_footprint_in` |
| DW-36 | Low | Unclear/Agent-trap | doc stale → fix doc | world_zones.md:683-694 | The relief table mirrors `source.relief_profiles`, which has zero readers; the live presets are in `terrain_data.lua:16-29` |
| DW-37 | Low | Outdated | doc stale → fix doc | world_zones.md:1588-1591, :631, :543 | Per-race capital "terrace" forms; the same doc (:1477-1478) says "no terraces", and the `shape` field is unread |
| DW-38 | Low | Contradiction | doc stale → fix doc | world_zones.md:1015, :1020 vs :237 | "dragon hoard" vs "no hoard chest (E11)" |
| DW-39 | Low | Missing | doc stale → fix doc | world_zones.md §7.4 :429-448 | No numbers for the 80-node shelf band or the bay-mouth deep-ocean cut at z = ±3000 |
| DW-40 | Low | Unclear/Agent-trap | unclear → Jan decides | world_zones.md:139-142, :1728-1733 | "never overlaid" / `surface_mob_level_at`: `grug_core.surface_mob_level_at` returns the region overlay; only `grug_zones.*` is the pure field |
| DW-41 | Low | Wrong | doc stale → fix doc | world_zones.md:1042, :1071 | `stillgrave_ringbarrows` is called a "ridge band"; the code type is `ring`, which is missing from the §8.4 type list |
| DW-42 | Low | Outdated (citations) | doc stale → fix doc | research docs citing world_zones §15.1/§15.4/§15.5 | The retired §15 subsections are still cited (`post-wp40-planning-review.md:50,64`; `wp41-engineering-brief.md:52,80,89,168`); every other § reference resolves |

## Details

### DW-01 Capital zones have hostile ambient mobs outside the city

**Doc says**:

- `world.md:96` (difficulty table): "Capital city zones | no hostile ambient enemies".
- `world_zones.md:169-170`: "A capital zone is a peaceful, safe civic hub with **no hostile ambient enemies**".
- All six capital rows of `world_zones.md` §8 (:969, :974, :979, :990, :995, :1000) say "no ambient hostiles".
- `world_zones.md:1465-1467`: "Hostile ambient spawning is disabled (the capital zones' mob palettes are empty)".
- `biomes_mobs.md:877-878`: "Capitals retain empty palettes and never receive a fallback".

**Code does**:

- Every capital zone has a spawn recipe with 20–30 belts. Example: `mods/ENTITIES/grug_mobs/data/zones/elandor_dur_brannoc.spawns.json` has:
  - night `debtbound_zombie`, `stubborn_zombie`, `toll_bandit` and `toll_bandit_archer`;
  - the camp `goblin_camp` (belt l28_30);
  - the leader `ore_factor_brakk`.
- The other five capital zones have night zombies and bandits, a bandit or poacher camp, and a named leader. See the appendix.
- Only the capital **city** is refused, as protected spawn surface (`spawn_policy.lua:212-213`, `grug_mobs.protected_spawn_surface`).
- The zone record flag `civic_no_hostiles` (`wp40/source/simple_map.lua:48`) is read only by `grug_housing/registry.lua:423` (claim exclusion). No spawn code reads it.
- This was decided in Round 28: `docs/planning/round28-questing-leveling-plan.md:405`, "capital zones get areas outside the city". `spawn_regions.md:306` documents it ("Capital 20–30 | the capital city and the border…").

**Impact.** An agent following the docs believes the capital zones are hostile-free. It could:

- write quests or texts that send low-level players "safely" through them;
- "fix" the recipes by emptying them;
- read the `civic_no_hostiles` flag as a spawn gate.

Three design docs contradict `spawn_regions.md`.

**Suggested fix.** Replace each phrase with: "The capital **city** (inside the wall line and its band) has no hostile ambient spawns; the rest of the capital zone carries a 20–30 spawn recipe ([spawn_regions.md](spawn_regions.md))."

- Delete the "palettes are empty" clauses at `world_zones.md:1466` and `biomes_mobs.md:877-878`.
- Change `world.md:96` to "Capital cities".
- Consider renaming or commenting `civic_no_hostiles` in code (code lane).
- **Verification (phase 2):** Confirmed — all quoted lines hold (world.md:96, world_zones.md:169-170, :969, :1466, biomes_mobs.md:877), every capital zone loads a 20–30 recipe via spawn_regions.lua:1191 (e.g. kragmar_nhal_veyr.spawns.json belts l20_23/l24_27 with debtbound/stubborn zombies and toll_bandit at night; added c4c9decc, Round 28 B1), and `civic_no_hostiles` is read only by grug_housing/registry.lua:423. Add one more stale spot: the code comment mods/ENTITIES/grug_mobs/spawn_policy.lua:209-210 also says the capital zones' "mob palettes are empty".

### DW-02 Bog Witch called absent, but shipped

**Doc says**: `biomes_mobs.md:709-713`: "Bog Witch is deferred from this wave … It remains absent until a licensed mesh … is pinned. The package KAT keeps `blocked=bog_witch` as the regression record."

**Code does**:

- `mods/ENTITIES/grug_mobs/bog_witch.lua:1-4` is a retint of the shipped skeleton humanoid, with real shoot and die clips, loaded at `init.lua:1098`. It was added in commit `7ab846cc` ("Add Round 9 mob packages 6 through 8").
- Five recipe roles use it:
  - `reed_hex_witch`;
  - `salt_hex_witch`;
  - the leaders `storm_bottle_witch`, `bottle_keeper_zek` and `salt_counter_witch`.
- They spawn in Thunderroot Wilds, Gravesalt Escarpment and Stormscale Summit.
- The Round 36 corrupted sub-type `kiln_whisper_hexer` also uses it.
- The same doc lists Bog Witch as a current aggressive family (`biomes_mobs.md:1407`) and as a corrupted base (:1507). `world_zones.md:1003/1016/1020` name it per zone.
- `grep blocked=bog_witch` finds nothing in mods or tools.

**Impact.** The doc contradicts itself. An agent may think the witch is missing and re-implement it, or remove it as unlicensed.

**Suggested fix.** Replace the paragraph with: "Bog Witch shipped in Round 9 on the skeleton humanoid mesh (keyed shoot 70..90, die 160..170), not the VoxeLibre witch mesh; its hex bottle is a homing arrow with poison or slow."

### DW-03 `world.md` §3 capital band: "no ground cover" is stale after Round 36 W3

**Doc says**: `world.md:416-419`: the band "carries no trees and no ground cover, so players see where the protection ends".

**Code does**:

- `wp40/capital_protection.lua:34-37`: "since Round 36 W3 a share of it grows the zone's ground cover, thinning toward the wall" (`shape.distance2`, `edge_reach` 9, `band` 12).
- `wp40/vegetation_density.lua` uses the new `"cover"` exclusion (merge `9883782a`).
- W3 updated `world_zones.md:1449-1453`, `:1481-1483` and `settlements.md:93-101`. In `world.md` it changed only the wording at :149/:152 ("bare" → "treeless") and missed §3.

**Impact.** The docs disagree with each other on a feature the user asked for in a playtest. An agent could "restore" a bare band.

**Suggested fix.** At `world.md:416-419`, write: "…that carries no trees; beyond the edge's reach (9 nodes from the wall line) a seeded share of its columns grows the zone's one-node ground cover, rising from a third to all toward its outer edge (Round 36 W3, `world_zones.md` §12)".

### DW-04 Palette-era mob placement tables vs the Round 28 recipes

**Doc says**:

- The `biomes_mobs.md:82-88` table is headed "Current zone selection":
  - "Husk in Sunscar, Redtusk and Shattered Line; Zombie elsewhere";
  - "Archer in other eligible forest/mountain zones".
- Round 8 tables at `biomes_mobs.md:670-707`:
  - Stone Mite "any (cave) | y ≤ −700";
  - Sun-Dried Husk "Redtusk and Shattered Line; Sunscar from band 2".
- `biomes_mobs.md:660-664`: Carrion Crow is "the whole daytime population of the war coast (20–30)".
- `biomes_mobs.md:593-600` places the Mesa Golem in the "Mountain pair … (outer, 25–60)".
- `world_zones.md:1017-1018` (§8.3): "24 h War Construct" in The Broken Causeway and The Shattered Line.

**Code does** (recipes resolved to base mobs; see the appendix):

- **Husk.** `sun_dried_husk` roles spawn in **13** zones: Sunscar, Redtusk, Mournfen, Nhal Veyr, Gor Drazhak, Bannerbreak, Blackwind, Broken Causeway, Shattered Line, Gravesalt, Skyglass, Stormscale and Wyrmglass.
- **War Construct.** It appears **only as the leaders** `last_toll_construct` and `siege_engine_nine`.
  - Its surface ABM row (`war_construct.lua:30-34`) registers no ABM since Round 30, because every zone has a recipe (`spawn_policy.lua` `spawn_row_kept`).
  - The sub-types `causeway_construct` and `siege_war_construct` ("Optional ambient elite, cap 1") are referenced by no recipe.
- **Stone Mite.** The sub-types `marrow_weevil` (21–40, Ossuary/Blackwind) and `salt_boring_weevil` (51–59, Gravesalt) put `stone_mite` on the **surface**, by day.
- **Mesa Golem.** It is in no recipe, so on the surface it exists only underground (`spawn_policy.lua` UNDERGROUND_MOBS). `stone_golem` appears only as two leaders.
- **Skeleton Archer.** The base appears only in Ossuary Reach. Raider tints cover the front zones.
- **Carrion Crow.** It spawns in the 31–60 zones (Ashenward, Bannerbreak, all four Battlegrounds zones and both islands).

**Impact.** An agent writing quests or texts from these tables names the wrong zone. One balancing ambient density could add "missing" ambient War Constructs. §4 already says the surface rows are "history", but these tables are still labelled current.

**Suggested fix**:

- Head the §0 Round 18 table and the "Zones / level band" columns of the Round 8 tables as **palette-era (before Round 28), superseded by the recipes**. Better, delete those columns.
- Point to `data/zones/*.spawns.json` and `docs/planning/round28/zones/index.md` as the placement authority.
- Optionally generate a zone→families table from the recipes.
- In `world_zones.md` §8.3, change "24 h War Construct" to "War Construct leader".
- Code lane: decide on the two unused construct sub-types.

### DW-05 WP13 status stale in world.md and settlements.md

**Doc says**:

- `world.md:6-8`: "Structure delivery and outstanding content are tracked in BACKLOG WP13".
- `world.md:1029-1031`: "The delivered regional structure subset is six villages, six outposts and six bandit camps; BACKLOG WP13 tracks the remaining roster."
- `world.md:989-990`: "Small race villages … content for WP13 after WP40 fixes their slots."
- `settlements.md:33-34`: "The remaining village, outpost and camp roster is tracked in BACKLOG WP13."

**Code / BACKLOG**:

- `BACKLOG.md:175`: WP13 **Delivered** with Round 36.
- The roster is complete: `wp40/r7_anchor_roster.lua:77-82` fixes 6 capitals, 24 outposts and 12 bandit camps. `settlements.md:640-646` itself lists the 70 Round 20 places (6 villages, 18 outposts, 6 frontier camps, 6 mines, 4 mirefolk camps, 16 clash sites, 2 arenas, 2 apex camps, 10 rare pads).

**Impact.** It suggests open structure work that is done, and `world.md` §9 gives the wrong delivered count.

**Suggested fix.** Replace the sentences with "WP13 delivered (Round 20 roster art, Round 36 decor pass); the full roster is in `settlements.md` 'Round 20 authored regional places'". Drop the `world.md:989-990` bullet or mark it as done.

### DW-06 findings.md D4 (Kraken) is stale

**Doc says**: `docs/maintenance/findings.md:15`: "Still open: `view_range` is 20 against a target of 40 and the position-dependent pursuit is not built."

**Code does**:

- `kraken.lua:78` sets `view_range = 40`.
- `kraken.lua:12-14` and `:148` set run speed 10 in deep ocean and 5 elsewhere, switched once a second. Outside deep ocean it drops its target.
- This landed in Round 29 (commit `38d9764a`). `world.md` §2b, `biomes_mobs.md:749-770` and `boats.md` §7 describe this correctly.
- `findings.md:24-26` also still lists "the level-41–60 story and the war-front encounters" as unimplemented. WP9 was delivered in Round 36 (`BACKLOG.md:168`); only the war-front encounters (WP42) remain.

**Impact.** An agent trusting the known-gap list may "implement" what exists.

**Suggested fix.** Close D4 ("fixed in Round 29, `38d9764a`") and remove "the level-41–60 story" from the list at :24-26.

### DW-07 story.md: the main line's early shape and its level-30 gate

**Doc says**:

- `story.md:39-42`: "early quests are local and mundane (boars, bandits, guard duty), then signs of corruption appear".
- `:43-46`: "e.g. only at level 30 comes the order to kill a corrupted outpost leader that advances the main story".

**Code does**:

- The main line starts at 41: `accord_main_impounded` (`grug_quests/data/zones/elandor_ashenward_march.quests.json`) and `throng_main_01` (`kragmar_bannerbreak_mesa.quests.json`).
- Chapters open at 41/46/53 and the finale at 60.
- No main-line quest exists at 30. `story.md:122-125` itself says the 11–30 traces are optional foreshadowing.

**Impact.** A content lane could add a level-30 main-line beat.

**Suggested fix.** Rewrite the bullets as "main line 41–60 (§2a); 11–30 chains only foreshadow". Use 41/46/53/60 as the gate example.

### DW-08 story.md: V1 "breaches" and "Nether corruption"

**Doc says**:

- `story.md:27-28`: "In V1, scorched breaches, twisted vegetation and corruption set pieces foreshadow a connection from below".
- `:129-131`: "Corruption visuals at overworld breaches".
- `:134`: "the Nether corruption".

**Code does**:

- V1 has one rift crack at one clash site (`rift_core.lua:32` `M.SITE = "r20_anchor_077"`, `rift.lua`) and ten ember-tinted corrupted sub-types.
- No breach, scorched-ground or twisted-vegetation code exists. "scorch" occurs only for dragon breath.
- `docs/planning/round36/story-bible.md:10-11` says V1 has no Nether content. BACKLOG lists no breach work.

**Impact.** An agent may build "breaches" as V1 scope, or label V1 content "Nether".

**Suggested fix (Jan decides).** Either mark the breaches and vegetation as V2/future, or reword them to "the rift's crack and the ember-tinted corrupted creatures". Avoid "Nether corruption" for V1.

### DW-09 scout.md: crit at level 60

**Doc says**: `scout.md:46-48`: "the Scout at **17.8 % crit** and **12.8 % dodge** from attributes alone".

**Code does**: `grug_classes/stats.lua:142` computes crit as `0.05 + 0.0005 × dex`. At Dex 128 that is **11.4 %**. Dodge is 12.8 %, which is correct. The Dex→Crit halving is the user ruling of 2026-10-04 (`item_tiers.md:38-40`).

**Suggested fix.** Write 11.4 %. "Highest of any class" still holds (the Warrior gets 8.45 %). Cite `item_tiers.md` §1.0 for the formula.

### DW-10 world_map.md: two refresh rates

**Doc says**: `world_map.md:42`: "Refresh at most twice per second". `:126-127`: "at most every 2 seconds (Round 30 ruling)".

**Code does**: `grug_map/page.lua:65` has `REBUILD_US = 2000000`, and `:72` has a pass of 0.1 s with 8 checks and 2 builds.

**Suggested fix.** Change line 42 to "at most every 2 s (see Atlas navigation)".

### DW-11 TODO-design-nether.md: the dragon lord's phase

**Doc says**: `TODO-design-nether.md:61-62`: "the **Nether dragon lord** is the Phase 3 capstone boss (world.md §4b)".

**Other docs**:

- `world.md:710`: "V2 — the Nether dragon lord as part of the first large post-V1 content update".
- `ROADMAP.md:354-356` puts the Nether in Phase 2; Phase 3 is Polish (`:360`).

**Suggested fix.** Change it to "the V2 capstone boss".

### DW-12 world.md §4: outposts as graveyard/respawn point

**Doc says**: `world.md:469`: outposts' roles include "graveyard/respawn point for the own faction".

**Code / other docs**:

- `home_travel.md:4`, `:69` and `settlements.md:568` say respawn happens only at the twelve innkeeper homes ("No other V1 home points exist").
- `grug_home/locations.lua` lists 12 locations.
- No outpost respawn code exists.

**Suggested fix.** Drop "graveyard/respawn point", or mark it as a later idea.

### DW-13 world.md §7: the human quest-XP hook is active

**Doc says**: `world.md:968-969`: "The human bonus is a latent hook … that activates when WP8's quests tag their XP with source="quest"."

**Code does**: `grug_quests/state.lua:454` passes `"quest"`, and `grug_xp/init.lua:155` applies `get_xp_bonus`. The bonus is live.

**Suggested fix.** Write "The human +10 % applies to quest rewards (`grug_xp.add_xp(…, "quest")`)".

### DW-14 world.md §7: "only 3 classes"

**Doc says**: `world.md:986` "(only 3 classes — locks would frustrate …)".

**Code does**: there are four classes. `grug_classes/scout.lua` adds the Scout (Round 11).

**Suggested fix.** Write "only four classes".

### DW-15 settlements.md: "The 100-anchor roster"

**Doc says**: `settlements.md:640`: "The 100-anchor roster retains its six starts, six capitals and eighteen earlier regional compositions."

**Code does**:

- `wp40/r7_anchor_roster.lua:23` requires `#source.anchors == 118`.
- Anchors 101–118 are the Round 31 PvP fortresses and camps (`settlements.md:756` says so itself).

**Suggested fix.** Write "The roster's first 100 anchors (the Round 31 PvP anchors 101–118 follow below) …".

### DW-16 world_zones.md §8.3: Skyglass also keeps the Rift Spawn row

**Doc says**:

- The `world_zones.md:1019` Skyglass row names no Rift Spawn.
- The Wyrmglass, Gravesalt and Stormscale rows do.
- `spawn_regions.md:145-147` and `biomes_mobs.md:1124-1126` say four zones including Skyglass.

**Code does**: `spawn_policy.lua:150-153` `RECIPE_ZONE_ROWS` includes `front_skyglass_canopy`.

**Suggested fix.** Add "night Rift Spawn" to the Skyglass row.

### DW-17 Unbuilt content written in the present tense

**Doc says**:

- `world.md:768-771`: "Flat connected lava lakes with an air dome and a usable shore are the authored environment example".
- `world.md:521-524`: "War-front squads use fixed population caps, place-bound respawn slots and fixed clash points."

**Code / BACKLOG**:

- There is no lava-lake pass in mapgen (no hit for `lava_lake`). `BACKLOG.md:147-148` says "the T6 lava lakes … stay planned (E3) with no scheduled owner".
- War-front units are WP42, "After V1 … no war-unit runtime" (`BACKLOG.md:204`).
- The header at `world.md:9-10` disclaims this only in general.

**Suggested fix.** Add "(planned, BACKLOG E3)" and "(WP42, after V1)" inline.

### DW-18 Ring vocabulary and old ring notes

**Doc says**:

- `biomes_mobs.md:180-182`: "ring tiers: T1 inner (10–25), T2 outer (25–45), T3 coast/deep (45–60)".
- `biomes_mobs.md` §3.1 group headings use "(core + inner, L1–25)", "(outer, 25–60)", "(outer/coast, 38–60)", "(universal, 25–45)" and "War coast (20–30)".
- `world.md:496-499`: "The old fixed minimum of 24 ring outposts is not a target budget; the complete zone catalog must replace it … before any old anchor is removed."

**Code does**: there are no ring zones. Levels come from named zones and regions. The 24 outposts are authored anchors (`r7_anchor_roster.lua:78`).

**Impact.** Confusing, but harmless if read as history.

**Suggested fix.** Replace the ring words with the named-zone bands, or label them "(ring-era wording)". Delete the `world.md:496-499` sentence (the catalog has been in place since R7).

### DW-19 biomes_mobs.md line references into levels.lua

**Doc says**: `biomes_mobs.md:37` cites `levels.lua:70-118`; `:477` cites `levels.lua:89-95` for the telegraph predicate.

**Code does**: `TIERS` is at `levels.lua:70`. `tier_telegraphs` is at `:101`. The HP formula is at `:131`.

**Suggested fix.** Cite the function names (`TIERS`, `grug_mobs.tier_telegraphs`) instead of line numbers.

### DW-20 mounts.md:92: visibility gate

**Doc says**: `mounts.md:92` "Each exact character-level anchor is both the visibility and purchase gate."

**Code does**: the doc's own `:49-53` (Round 28 ruling 19) and the code list every tier, greyed "Requires level N": `grug_mounts/trainer.lua:186-211` and `state.lua:97-104`.

**Suggested fix.** "…is the purchase gate; below it the tier is listed greyed."

### DW-21 scout.md:288: the Sprint HUD label

**Doc says**: "Sprint appears in the central status HUD as `Sprint (+50% Speed)`".

**Code does**:

- `grug_core/status_icons.lua:82` registers `scout_sprint` with name "Sprint" and detail "+50% movement speed".
- The HUD shows the icon and a countdown (`grug_abilities/scout.lua:531-534`).
- "50% Speed" occurs nowhere in mods.

**Suggested fix.** Describe it as the Sprint icon with a 10 s countdown, and "Sprint / +50% movement speed" on the Effects tab.

### DW-22 scout.md:116-118: the bowyer shelf

**Doc says**: "The bowyer shelf therefore sells arrows, sticks and feathers (`stock.lua:474-479`) and gets no bracket tab".

**Code does**:

- `grug_traders/stock.lua:115` (`bowyer = "bow"`) and `:168-170` give the bowyer a T1 gear tab.
- The goods shelf is at `:271-278`.
- `scout.md:361` itself says "the bowyer shelf exposes the T1 bow".

**Suggested fix.** Mark the passage as the pre-Round-11 state, or delete it.

### DW-23 Undocumented behaviour (scout draw stance, stun dismount)

**Code does**:

- `grug_abilities/scout.lua:13-15` and `:400` apply a ×0.5 movement stance while the Scout draws a bow. It is documented in `skill_trees.md:1189-1197` but not in `scout.md`.
- `grug_core/movement.lua:423-430` (`set_stun`) dismounts a mounted player. `mounts.md` §3/§3.1 lists only damage, zones, death, logout and shutdown as dismount causes.

**Suggested fix.** Add one line each.

### DW-24 world_map.md: river widths, "view" wording, live signature

**Doc says**:

- `world_map.md:18-21`: rivers are "3–25 nodes wide … three pixels from 11 nodes".
- `:40-45` refers to the "selected / current view".
- `:127-131` gives the live signature parts.

**Code does**:

- The stroke follows the water width, with 3 px from `RIVER_WIDE = 18` (`grug_map/base.lua:166-170`, `:377-382`). The water width is 7.5–30 (`wp40/terrain_data.lua:226`, `:233-235`). `world_map.md:176-178` already states the newer rule.
- There is one view only (`atlas.lua:74-76`).
- The live signature also includes the viewer's faction (`page.lua:174-176`).

**Suggested fix.** Update the numbers and wording.

### DW-25 story.md:48: "ROADMAP 1.5"

**Doc says**: "elite kill in hostile territory — ROADMAP 1.5".

**Other docs**: ROADMAP.md has no section 1.5.

**Suggested fix.** Point to `quests.md` (the main line, the PvP fortress quests), or drop the reference.

### DW-26 TODO-design-nether.md: "Rift-Touched"

**Doc says**: `TODO-design-nether.md:51-52` proposes a PvP state "Rift-Touched".

**Code does**: "rift" now names V1 content: the Round 36 rift (`rift.lua`, `rift_core.lua`) and the Rift Spawn (`rift_spawn.lua`).

**Suggested fix (Jan decides).** Rename the placeholder, or add a note about the collision.

### DW-27 home_travel.md:20-21: innkeeper markers

**Doc says**: "The Map tab's innkeeper markers label the locations and identify the current home."

**Code does**: `grug_map/providers.lua:142-160` shows only the player's own faction's innkeepers (Round 31 ruling 13) and adds a separate "Your Claim Stone" marker.

**Suggested fix.** Add "(own faction only; a claim home shows its own marker)".

### DW-28 Drifted line references (scout.md, mounts.md)

| Reference | Doc location | Now at |
|---|---|---|
| `kits.lua:288-310` (Strike) | scout.md:70 | `:267` |
| `kits.lua:421-430` (Hamstring) | scout.md:76 | `:416` |
| `stats.lua:128-140` (dodge) | scout.md:77 | `:164-167` |
| `stock.lua:474-479` (bowyer goods) | scout.md:117 | `:271-278` |
| `mounts.md:128-133` (physics-owner count) | scout.md:271 | `mounts.md:203-209` (those lines are now the price table) |
| `api.lua:1259-1265` (`is_invisible`) | scout.md:440 | `:1417-1423` |
| `api.lua:4085` (`ignore_invisibility`) | scout.md:470, :544 | `:4456` |
| "the 62" GRUG PATCHes | scout.md:475 | there are 122 |
| `guard.lua:181/205` | scout.md:528 | `:191/:215` |
| `mount.lua:183-198` (`mobs.detach`) | mounts.md:217 | `mount.lua:192` |
| `mount.lua:107-120` (`find_free_pos`) | mounts.md:217 | `:116` |
| `api.lua:2793-2798` (`self.attack:get_attach() or self.attack`) | mounts.md:257 | `api.lua:3045` |

mounts.md:433-440 has more drifted mount.lua references:

- `attach` is at `:142`, `detach` at `:192`, `drive` at `:211` and `fly` at `:348`.
- `force_detach` and the leave/shutdown/die handlers are at `:47-105`.
- `max_speed_forward` is at `:322-323`.
- The real `mobs.fly` signature is `(entity, dtime, speed, moving_anim, stand_anim)`.

**Suggested fix.** Cite function names. For the "verbatim" §8 of scout.md, add a line saying "line references as of 2026-09-16".

### DW-29 world_zones.md still says "target, not yet running"

**Doc says**:

- `world_zones.md:16-17`: "The rewritten text describes the **target**; the running mapgen follows as Round 22 Phases 3–5 land."
- `:263-266`: "Until Round 22 Phases 3–5 land, the running mapgen still implements the WP40 model".
- `:540-542`: plots in water are "allowed until the capital planner (plan D60) builds the capital around its water". This contradicts `:1563` "Plots never stand in water".
- `:1105-1106`: "adjusted when the new mapgen lands".

**Code does**: the roads (`road_layout.lua:84`, the Round 36 `C_STEP`), the water layout and the capital planner are all live through `r7_loader.lua`. `grug_mapgen/init.lua:1-3` reads "WP40 R7 production cutover".

**Impact.** An agent may treat the described rules as aspirational, or search for an "old" model.

**Suggested fix.** State once that §7–§14 describe the running mapgen, and drop the "until/when … lands" clauses.

### DW-30 The "600 × 500 start core"

**Doc says**:

- `world_zones.md:345-346`: "Each owns a centred **600 by 500 start core** wholly inside its starting zone, dry except for explicitly authored civic water". Also `:376` and `:407`.
- `world.md:159-161`: "by construction of `world_zones.md` §7's 600×500 dry start core … an enclosed or flooded start cannot generate".

**Code does**:

- No 600×500 object exists.
- The zone field keeps the 152-node town square in-zone (`zone_field.lua:299-308`, `hard_start_town_v1` bound 152).
- Dryness comes from a water keep-out of radius about 300 (`terrain_data.lua:285` `start_keepout = 300`).
- `docs/research/round22-stale-rules.md:100` (D9) recorded this, but the fix was never applied.

**Suggested fix.** In both docs: "the 152-node start town lies in its zone; no planned river or lake within about 300 nodes except its civic pond".

### DW-31 Native ore registration count

**Doc says**: `world_zones.md:1667-1669`: "native registration is closed at zero Lua biomes, one retained gravel blob and the five T2–T6 strata, with zero engine decorations". `:906-910` (Round 24) adds decorative nests.

**Code does**: `r7_native.lua:363-365` registers slate, granite and basalt blobs. `:516` has `NATIVE_COUNT = 6 + #DECOR_EXPECTED`, so 9 native ores.

**Suggested fix.** Add "and the three decorative-nest blobs (Round 24)".

### DW-32 §13.1 cutover text

**Doc says**: `world_zones.md:1694-1697`: "The new evaluator, compatibility adapters and consolidated VoxelManip callback remain disabled until one atomic production cutover removes both legacy WP18 geography writers."

**Code does**: the cutover is done (`init.lua:1-3`; no legacy loaders). `round22-stale-rules.md` D18 already recommended dropping it.

**Suggested fix.** Delete it, or rewrite it in the past tense. Archive the §13.1 cutover bullets.

### DW-33 Sea and bay depths

**Doc says**: `world_zones.md:581-583`: "continental bays are 6–10 nodes deep; … deep ocean and dragon channels are 24 nodes deep".

**Code does**:

- One sea-floor profile serves sea, bay and channel water (`terrain_field.lua:785-805`). It runs from a shallow shelf down to about 32 below y 0, about 33 nodes under `WATER_LEVEL` 1 (`height.lua:80`).
- 24 is only `OUTSIDE_FLOOR = WATER_LEVEL − 24` (`height.lua:83`) and `zones.lua:1210` `-23`, both outside the query bounds.

**Suggested fix.** Describe the shelf profile (Round 22 D35): shallow at the shore, about 30 nodes at depth, the same for bays and channels.

### DW-34 Slot vocabulary lacks the PvP slots

**Doc says**: `world_zones.md:1759-1762` lists the slots `start`, `capital`, `village_<n>` … `rare_<id>`.

**Code does**: `source/simple_map.lua:354-371` defines `pvp_fortress`, `pvp_accord_low|high` and `pvp_throng_low|high`. `world_protection.lua:90-91` keys protection on them.

**Suggested fix.** Add the five slot names with a pointer to §16.

### DW-35 Public grug_zones methods

**Doc says**: `world_zones.md:1703-1708` lists the public methods.

**Code does**: `grug_core/zone_authority.lua:5-22` `PUBLIC_METHODS` also has `hard_protection_kind_at` and `hard_footprint_in` (`zones.lua:1153-1159`).

**Suggested fix.** Add both.

### DW-36 The relief table describes dead data

**Doc says**: `world_zones.md:683-694`, a relief table (e.g. `lowland` +8..+56, `mountain` +160..+360).

**Code does**: these equal `source.relief_profiles` (`source/simple_map.lua:392-424`), which nothing reads. The live presets are `terrain_data.lua:16-29` (`data.relief`: base 10/30/52/72/100/130 plus hill, ridge and race accents).

**Impact.** An agent tuning relief through the documented rows changes nothing.

**Suggested fix.** Point the table at `terrain_data.lua` and re-state its values. Code lane: remove the dead `relief_profiles` and `anchor_profiles.shape`.

### DW-37 Per-race capital "terraces"

**Doc says**:

- `world_zones.md:1588-1591`: "Dur Brannoc is a granite terrace, Highcourt a gentle river plateau … Kezamba a drained/stilted cenote terrace".
- `:631` mentions a "terrace contract" and `:543` "terrace grading".
- `:1477-1478` says "there are no terraces".

**Code does**:

- The `shape` values in `source/simple_map.lua:452-457` are never read.
- Race differences come only from `data.capital_target` and `capital_wave` (`terrain_data.lua:51-60`), the flat 96 core and the 40-node collar.

**Suggested fix.** Reword it as the calm bowl with a per-race target band and wave.

### DW-38 "dragon hoard"

**Doc says**: `world_zones.md:1015` and `:1020` say "dragon hoard". `:237` says "no hoard chest, WP audit E11".

**Suggested fix.** Use "dragon lair".

### DW-39 Shelf and bay-mouth numbers missing from §7.4

**Code does**:

- The coastal shelf is an 80-node band (`source/simple_map.lua:22`, `simple_map.lua:360`).
- Bay water beyond the mouth cut at z = ±3000 is `deep_ocean`, immutable (`source/simple_map.lua:144-147` `deep_ocean_cut_z`).

`world.md:238-242` has both; `world_zones.md` §7.4 (:429-448) has neither.

**Suggested fix.** Add one sentence each, or a link to `world.md` §2 R3.

### DW-40 Which `surface_mob_level_at`

**Doc says**: `world_zones.md:139-142` and `:1728-1733` say the level field "is never overlaid", and use `surface_mob_level_at` to mean the zone field.

**Code does**: `grug_core.surface_mob_level_at` returns the spawn-region overlay (`zone_authority.lua:447-455`). Only `grug_zones.surface_mob_level_at` is the pure field. `spawn_regions.md` "One level truth" states this correctly.

**Suggested fix.** Name both functions explicitly.

### DW-41 `stillgrave_ringbarrows` type

**Doc says**: `world_zones.md:1071` calls it a "(ridge band)". The §8.4 type list at `:1042` has no "ring".

**Code does**: `terrain_data.lua:152` has `type = "ring"`, and the type list at `:126` includes ring.

**Suggested fix.** Add `ring` to the list and correct the row.

### DW-42 Citations of the retired §15 subsections

**Doc says**: `docs/research/post-wp40-planning-review.md:50,64` and `wp41-engineering-brief.md:52,80,89,168` cite `world_zones.md` §15.1, §15.4 and §15.5, which no longer exist.

Every other § reference into `world_zones.md` resolves (§2, §7, §7.1–7.6, §8, §8.1–8.4, §9, §9.1, §10–§13.4, §16), and so do its outbound references.

**Suggested fix.** Research docs are evidence, so either leave them or add a one-line "§15 retired" note.

## Proposed structure changes

- **`biomes_mobs.md`: split the family specs from the placement data.**
  - Keep §3 as the family spec (verb, speed, drops, model).
  - Move every "which zone / which band" statement to the recipes, or to a generated `docs/design/zone_mobs.md` produced from `data/zones/*.spawns.json` (the appendix below is a first cut).
  - Archive the palette-era tables (§0 "Round 18", the §4 parameter table, the Round 8 "Zones" columns) to `docs/archive/design/`.
  - This removes about 300 lines of history labelled as current and the main source of DW-04.
- **`world_zones.md` §8 identity columns.** The free-text mob mentions ("day Fox/Ibex, night Goblin Raid") duplicate the recipes and drift. Either drop them or point each row to its recipe file.
- **`world_zones.md` archive candidates**:
  - the Round 22 rewrite banner (:12-18);
  - the §13.1 R7 cutover bullets (:1667-1673, :1694-1697);
  - "Round 21 natural-surface iteration" (:2043-2074), whose :2055-2064 is explicitly superseded; its live waterweed, lily and angelfish rules belong in §7.4.

  Move the "Round 10 Cooking wild sources" block (:1966-2033), which is live but sits after §16, into §11. Move the §12 king encounter rules (:1592-1633) to `world.md` §3 or an encounter doc.
- **Side findings outside the lane's documents** (for the code or process lanes):
  - `settingtypes.txt:58-59` says "Deep mining, ocean depths and arbitrary flight are not prepared". This contradicts `world_preparation.md` and `preparation_source.lua:86-89`, which prepare the sea, lake and river beds and flight up to the ceiling.
  - The comment at `grug_mounts/shipwright.lua:266-267` ("until [the socket is published], no Shipwright stands anywhere") is stale: the socket is published in `wp13/capital_services.lua:84`.
- **`world.md` §4b.** It carries the full dragon-arena and rift specs, roughly 170 lines. They are encounter rules, not world geography. Consider moving them to a `bosses.md`, or into `biomes_mobs.md`'s bosses table, and keeping a short summary plus a link in `world.md`.
- **`scout.md` §8 and `mounts.md` §8 / vendored-patch sections.** These keep line-numbered analysis of `mods/ENTITIES/mobs`. Archive them, or freeze them with a date, so they stop producing drift findings.
- **`settlements.md` capital history.** The per-capital narrative (Lethariel, Gor Drazhak, Kezamba, Nhal Veyr, 2026-09-15/16, including "For a while there was a second hole in that pad") is design history. It could move to the archive, leaving the "as built" capital planner rules.

## Open questions for Jan

1. **Capital zones (DW-01).** Is the Round 28 state, with hostile 20–30 recipes outside the capital city, the intended design? If yes, the docs are simply fixed. If the zone should be hostile-free, the recipes are wrong. The 2026-10-02 decision in `round28-questing-leveling-plan.md:405` points to the former.
2. **V1 corruption visuals (DW-08).** Should "scorched breaches / twisted vegetation" stay as a V1 wish, move to V2, or be dropped in favour of the rift alone?
3. **Ambient War Construct (DW-04).** `subtypes.json` still carries `causeway_construct` and `siege_war_construct` as "optional ambient elite, cap 1", unused by any recipe. Should they be added to the two zones' recipes, as `world_zones.md` §8.3 says, or should the docs and the dead sub-types be dropped?
4. **Placement authority.** Should `biomes_mobs.md` keep any per-zone mob lists at all, or should the recipes (plus a generated table) be the only source?

## Appendix: zone level bands and recipe populations (code, baseline 0f169898)

The zone band comes from `wp40/source/simple_map.lua:53-90`. The belt range comes from the recipe and matches the band in all 38 zones; the `world_zones.md` §8 level column also matches in all 38. Columns D and N are the base mobs of the day and night rosters. C is the camp roster bases, L the leader roles and Cr the ABM critters.

| # | Zone | Band | D (day) | N (night) | C (camps) | L (leaders) | Cr |
|---|---|---|---|---|---|---|---|
| 1 | Hearthpine Vale | 1–10 | boar, fox, ibex, shore crab | giant rat, zombie | bandit | muddled_ore_chief | rabbit |
| 2 | Copperfell Foothills | 11–20 | boar, fox, ibex, shore crab | giant rat, goblin raider, zombie | bandit(+archer), goblin hound/slinger | foreman_nog | rabbit |
| 3 | **Dur Brannoc (capital)** | 20–30 | ibex, ram | **bandit(+archer), zombie** | **goblin raider/slinger** | **ore_factor_brakk** | – |
| 4 | Frostbarrow Shelf | 21–30 | crag eagle, ibex, ram, shore crab | goblin hound/raider/slinger, snow leopard | – | powder_counter_nib | – |
| 5 | Stormvault Heights | 31–40 | crag eagle, ibex, ram, shore crab | frost stray, snow leopard, zombie | bandit archer, goblin raider/slinger | bolt_chewer, split_seam_warden (golem) | gull |
| 6 | Dawnmere Fields | 1–10 | boar, fox, shore crab | giant rat, zombie | bandit | confused_bandit_chief | rabbit, wild turkey |
| 7 | Goldmead Vale | 11–20 | boar, fox, shore crab | giant rat, poacher, zombie | bandit(+archer) | requisitioner_hobb | rabbit, wild turkey |
| 8 | **Highcourt (capital)** | 20–30 | boar, fox, stag | **bandit(+archer), zombie** | **bandit archer** | **tollmaster_penn** | – |
| 9 | Whitebridge Shire | 21–30 | bear, boar, shore crab, stag | giant spider, poacher, wisp, wolf | mirefolk | basket_poacher_thorn, ferryman_murk | rabbit |
| 10 | Ashenward March | 31–40 | bear, carrion crow, stag, wolf | ashen treant, giant spider, skeleton raider, wisp, zombie | bandit(+archer), poacher | quartermaster_scrip, red_receipt_marshal | – |
| 11 | Silverleaf Glades | 1–10 | boar, fox, shore crab | giant rat, zombie | bandit, poacher | misguided_poacher_chief | rabbit, song bird |
| 12 | Starbough Vale | 11–20 | boar, fox, shore crab | giant rat, poacher, zombie | bandit(+archer) | snarekeeper_vetch | rabbit |
| 13 | **Lethariel (capital)** | 20–30 | fox, stag | **bandit, poacher, zombie** | **poacher** | **bough_counter_rusk** | – |
| 14 | Lorindor | 21–30 | shore crab, stag | poacher, wisp | mirefolk | pearl_counter_iss | – |
| 15 | Moonfall Wood | 21–30 | bear, shore crab, stag, wolf | giant spider, poacher, wisp, wolf | – | snarewarden_bracken | – |
| 16 | Glassroot Wilds | 31–40 | bear, jungle ape, serpent, shore crab, stag, wolf | bandit, jungle spider, panther, serpent, wisp, wolf, zombie | bandit archer | canopy_knuckle, basket_biter | – |
| 17 | Stillgrave Hollow | 1–10 | boar, shore crab, stag, zombie | giant rat, zombie | bandit | grave_robber_chief | hare |
| 18 | Mournfen | 11–20 | boar, bog ooze, crocodile, shore crab, husk | bandit, bog ooze, crocodile, giant rat, wisp, zombie | bandit archer, crocodile, mirefolk | reed_counter_silt | bog fowl, hare |
| 19 | **Nhal Veyr (capital)** | 20–30 | boar, stag, husk | **bandit, zombie** | – | **mortuary_clerk_hush** | – |
| 20 | Ossuary Reach | 21–30 | bear, shore crab, stag, **stone mite**, wolf | gravewood treant, pale spider, skeleton archer, wolf | – | marrow_archivist | bone weevil |
| 21 | Blackwind Rise | 31–40 | bear, shore crab, stag, **stone mite**, husk, wolf | gravewood treant, pale spider, skeleton raider, wolf, zombie | bandit(+archer) | grave_broker_mute, hollowbell_treant | bone weevil, gull |
| 22 | Sunscar Flats | 1–10 | boar, plains runner, scorpion, shore crab, husk | giant rat, scorpion, husk | bandit | water_thief_chief | hare |
| 23 | Redtusk Savanna | 11–20 | boar, hyena, shore crab, husk, zebra | bandit, giant rat, hyena, scorpion, husk | bandit archer | water_broker_korr | hare |
| 24 | **Gor Drazhak (capital)** | 20–30 | hyena, husk, zebra | **bandit, hyena, scorpion, husk** | **bandit archer** | **ration_broker_garr** | – |
| 25 | Speargrass Reach | 21–30 | hyena, shore crab, speargrass tiger, vulture, zebra | hyena, scorpion | goblin raider/slinger | banner_broker_rakk | – |
| 26 | Bannerbreak Mesa | 31–40 | carrion crow, hyena, speargrass tiger, husk, vulture | bandit, carrion crow, hyena, scorpion, skeleton raider, husk | bandit archer, goblin hound/raider/slinger | provisioner_rattle, banner_eater | – |
| 27 | Kapok Cradle | 1–10 | boar, jungle lynx, shore crab, tapir, viper | giant rat, viper, zombie | bandit | offering_thief_chief | hare, parrot |
| 28 | Raincall Basin | 11–20 | boar, jungle lynx, shore crab, tapir | bandit, giant rat, viper, zombie | bandit archer | tithe_keeper_vek | hare, parrot |
| 29 | **Kezamba (capital)** | 20–30 | boar, jungle lynx, tapir | **bandit, viper, zombie** | **bandit archer** | **offering_broker_takka** | – |
| 30 | Whispering Reedlands | 21–30 | bog ooze, crocodile, jungle lynx, shore crab, tapir | bog ooze, crocodile, wisp | mirefolk | tollkeeper_ush | bog fowl, parrot |
| 31 | Totemwater Reach | 21–30 | bog ooze, crocodile, jungle lynx, shore crab, tapir | bog ooze, crocodile, wisp | – | reed_maw_crocodile | bog fowl, parrot |
| 32 | Thunderroot Wilds | 31–40 | jungle ape, serpent, shore crab | bandit, **bog witch**, jungle spider, panther, serpent, zombie | bandit archer | storm_bottle_witch, bottle_keeper_zek (**bog witch**) | – |
| 33 | The Wyrmglass Crown | 60 | bandit archer, carrion crow, crag eagle, ram, husk | bandit archer, frost stray, snow leopard, zombie | – | rime_bell_warden (golem) | gull |
| 34 | Gravesalt Escarpment | 51–60 | bandit(+archer), blightfang wolf, carrion crow, gaunt stag, plaguehide bear, **stone mite**, husk | bandit(+archer), **bog witch**, pale spider, skeleton raider, zombie | – | watch_captain_huskell, salt_counter_witch (**bog witch**) | bone weevil, gull |
| 35 | The Broken Causeway | 41–50 | bandit(+archer), carrion crow, husk, viper | bandit(+archer), skeleton raider, viper, wolf, zombie | bandit(+archer) | toll_taker_senn, **last_toll_construct (War Construct)** | gull |
| 36 | The Shattered Line | 41–50 | bandit(+archer), carrion crow, hyena, speargrass tiger, husk, vulture | bandit, scorpion, skeleton raider, husk | – | standard_bearer_ninepins, **siege_engine_nine (War Construct)** | – |
| 37 | The Skyglass Canopy | 51–60 | bandit, carrion crow, jungle ape, serpent, husk | jungle spider, panther, serpent, skeleton raider, zombie | bandit archer | paymaster_chirr, glass_throat_serpent | – |
| 38 | Stormscale Summit | 60 | bandit archer, carrion crow, jungle ape, serpent, husk | bandit archer, **bog witch**, jungle spider, panther, skeleton raider, zombie | – | last_offering_ape | gull |

Not in the table (ABM rows outside the recipes): the Rift Spawn surface row in Gravesalt, Skyglass, Wyrmglass and Stormscale (`spawn_policy.lua:150-153`); every underground row; the Kraken and the Reed Angelfish.

**What the table confirms** against `world_zones.md` §8:

- Wisp zones (8): exact match.
- Treants: Ashenward / Ossuary and Blackwind, exact match.
- Snow Leopard: Frostbarrow, Stormvault and Wyrmglass, exact match.
- Frost Stray: Stormvault and Wyrmglass, exact match.
- The Goblin Raid zones match, plus Dur Brannoc.
- Jungle Spider and Panther in the four jungle zones match.

**What the table contradicts**: the capitals (DW-01), the Husk, War Construct, Stone Mite and Mesa Golem placement (DW-04), and Bog Witch "absent" (DW-02).
