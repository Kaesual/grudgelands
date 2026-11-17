# DD1 — Design documents, world, against the code (verified)

- Finder model: claude-opus-5-5
- Verifier model: claude-opus-5-5
- Files read in full: 8 of 9 (world.md, world_zones.md, world_map.md, world_preparation.md, spawn_regions.md, biomes_mobs.md, zone_mobs.md, story.md); skimmed: settlements.md (read 1–250 and 500–1296 in full, 250–500 read; the architecture prose of §"Ordinary town facades" and the capital descriptions checked only where they state numbers); not reached: none
- Summary: The world documents are in good shape where the numbers are tables backed by code: all 38 zone hubs, levels, races, relief ids and biome roll weights of `world_zones.md` §7.1/§8 match `wp40/source/simple_map.lua` row by row, as do the resource density table (96 cells), the twelve WP33 herb/crop zone sets, the placement-rule kinds, the road constants, the spawn-region constants and all 27 quest places of `spawn_regions.md`. The defects are staleness after later rounds: the Round 46 per-world POI placement is contradicted by three surviving "fixed x/z" statements (world_zones §7.1, §7.5, world.md §9); deep-band gem/crystal statements predate Round 46 (Abyssal Crystal "1 per 2048", "Diamond the only gem below −1000"); the Round 58 camps are missing from the §8 catalog and the slot vocabulary; two capital tower spacings in settlements.md predate Round 26. Several design files still carry open questions or "open to correction" wording, which AGENTS.md "Documentation layers" forbids. No dead links or anchors were found. No further Round 51 staleness of the M1 kind (§13.3) was found in these nine files; the other documents already describe belt and channel levels correctly.
- Verifier note: all 25 findings checked against the code at `4cb49044e`. In every finding the document is the wrong side; the code is consistent with the newer rounds' rulings. Where two design files disagree, the code follows `world_zones.md` (DD1-02, -03, -20), `world_preparation.md` (DD1-08), `settlements.md:364-366` / `world_zones.md:1932-1934` (DD1-13, -14) and `biomes_mobs.md:245` (DD1-15, -16). Two severities lowered (DD1-02, DD1-03: Medium → Low).

Values checked per document (approximate counts): world_zones.md ≈ 700 (38 hubs × 2 coordinates; 38 catalog rows × level, race, PvP, 2–4 biome weights, POI letters; 38 relief ids in §8.4; relief table 24; resource table 96; 12 source zone sets ≈ 110 ids; placement kinds ≈ 25; road/network constants ≈ 15; capital targets/waves 12; public API list 17; counts of anchors 119–144, 36/42 roster); biomes_mobs.md ≈ 220 (decoration table §2.1 every row ≈ 60 fractions; land kit 20; WP33 densities 12; disposition table ≈ 75 names; catalogue counts 6; water families 10; herb bands 8; material-map herb rows 12; rares 9 rows); spawn_regions.md ≈ 50 (27 places with kind and belt, ≈ 20 builder constants); world.md ≈ 50; settlements.md ≈ 30; world_preparation.md ≈ 12; world_map.md ≈ 12; story.md ≈ 6; zone_mobs.md: **sampled** — zone 1 (Hearthpine Vale) day/night/camp/critter columns rebuilt by hand from `data/zones/elandor_hearthpine_vale.spawns.json`, the Rift Spawn row against `spawn_policy.lua:156-160`; the rest relies on the generator's `--check` fixture, and `git log` shows no roster change in `data/zones/` since the file was last regenerated (3c1b1c0ef; the later commits 843cea2dc and 564a564c5 add `places` and flip `quest_target` only).

## Findings

### DD1-01 | Medium | docs | world_zones §7.1 still says every anchor has a fixed x/z that no seed moves

- **Verdict:** CONFIRMED — `world_zones.md:353-354` reads "Every anchor slot keeps its stable id and fixed x/z position. No world seed selects, moves or rejects a 2D anchor"; the same file says the opposite at :25-29 and :265-272, and `simple_map.lua:270-282` documents FIXED rows (starts, capitals, dragon arenas, apex mines, four rift sites) versus PLACED rows with no coordinates (e.g. :296). The doc is wrong. Medium kept: it is phrased as an invariant an implementer would rely on (hard-coding anchor positions).
- **Where:** `docs/design/world_zones.md:353-354`; code `mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua:270-282, 296-441`, `wp40/placement.lua`, `wp40/placement_rules.lua:1-47`
- **What:** "Every anchor slot keeps its stable id and fixed x/z position. No world seed selects, moves or rejects a 2D anchor." Since Round 46 every anchor except starts, capitals, dragon arenas, apex mines and the four rift sites is `"placed"` per world (no coordinates in the row). The same file says so in §1 (L27-29), §7.1 (L265-272) and §8.5 (L1289-1296), so the document contradicts itself.
- **Evidence:** `simple_map.lua:271-277` "A PLACED row carries none … `placement.lua` places it on every world by its kind's rules"; rows such as `{2,"village_1","village","placed","mid"}` (L296) carry no x/z.
- **Proposal:** Restrict the sentence to the fixed anchors (starts, capitals, dragon arenas, apex mines, rift sites) and point to §8.5 for the rest. The doc is the wrong side.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-02 | Low | docs | world.md §2b/§4c: Diamond "the only gem below −1000"; Ruby and Sapphire also lie there

- **Verdict:** CORRECTED — the claim holds (`world.md:897-899`; `r6_content.lua:127-128` ruby 1/1024 and sapphire 1/2048 in T6; `registry.lua:328-332` "Diamond, Ruby and Sapphire reach the deep bands through T6"; the deep bands are applied to every resource row in `r7_native.lua:596-618`), and `world_zones.md:1559-1564` states it correctly, so the code follows world_zones.md and world.md is wrong. Severity lowered to Low: one parenthetical in a summary paragraph, while the authoritative table is right; no code or player effect.
- **Where:** `docs/design/world.md:897-900`; code `mods/ITEMS/grug_materials/registry.lua:328-341`, `mods/MAPGEN/grug_mapgen/wp40/r6_content.lua:127-128`
- **What:** The deep-density paragraph names "Diamond (the only gem below −1000)". Ruby is placed in T6 at 1/1024 and Sapphire at 1/2048, and the code comment says "Diamond, Ruby and Sapphire reach the deep bands through T6". This also contradicts `world_zones.md:1563-1564` (deep multipliers apply to Diamond, Ruby, Sapphire).
- **Evidence:** `r6_content.lua:127` `ruby = {5, 2, {false, false, false, false, 512, 1024}}`, `:128` `sapphire = {4, 2, {…, 512, 1024, 2048}}`; `registry.lua:331-332`.
- **Proposal:** Change the text to "the T6 gems (Diamond, and thinner Ruby and Sapphire)". The doc is the wrong side; the code follows Round 46 ruling 3.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-03 | Low | docs | biomes_mobs §6: Abyssal Crystal "one per 2,048 host nodes through T5/T6"

- **Verdict:** CORRECTED — the claim holds: `biomes_mobs.md:1556-1558` says 1/2048; `registry.lua:334-337` sets `{[5] = 512, [6] = 256}` and `r6_content.lua:115` checks the same with T5 limited to its lower half; `world_zones.md:1589` ("512 ½ | 256") matches the code, so the code follows world_zones.md and biomes_mobs.md is wrong. Severity lowered to Low: a stale number in prose whose authoritative table is correct.
- **Where:** `docs/design/biomes_mobs.md:1556-1558`; code `mods/ITEMS/grug_materials/registry.lua:334-337`, `mods/MAPGEN/grug_mapgen/wp40/r6_content.lua:115`
- **What:** The doc gives "approximately one crystal per 2,048 eligible host nodes through T5/T6". The code places 1/512 in the lower half of T5 and 1/256 in T6, which is also what `world_zones.md:1589` states. The two design files disagree; the biomes_mobs sentence predates Round 46/47.
- **Evidence:** `registry.lua:334-337` `abyssal_crystal = {first_tier = 5, host_nodes_per_ore = {[5] = 512, [6] = 256}}`; `r6_content.lua:115` `{5, 2, {…, 512, 256}, 5}`.
- **Proposal:** Replace the number with a pointer to `world_zones.md` §11's table (512 ½ in T5, 256 in T6). Doc is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-04 | Low | docs | world_zones §7.5: "Every other anchor keeps its x/z"

- **Verdict:** CONFIRMED — `world_zones.md:769-770` reads as cited; placed anchors have no x/z to keep (`simple_map.lua:270-282`). Doc is wrong.
- **Where:** `docs/design/world_zones.md:769-770`; code `wp40/source/simple_map.lua:270-282`
- **What:** "POIs sit in the terrain … Every other anchor keeps its x/z, and its height comes from the terrain". Placed anchors get their x/z per world (§8.5), so "keeps its x/z" is the pre-Round-46 wording. The height rule itself is right.
- **Evidence:** as DD1-01.
- **Proposal:** "Every other anchor keeps the x/z it was given (fixed, or placed per world, §8.5)". Doc is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-05 | Low | docs | world.md §9: outpost and bandit positions "come from the authored anchor layout"

- **Verdict:** CONFIRMED — `world.md:1204-1206` as cited; `simple_map.lua` has exactly 24 `"outpost","placed"` and 12 `"bandit_home|bandit_frontier","placed"` rows; `world.md:555-558` already says positions are placed per world. Doc is wrong.
- **Where:** `docs/design/world.md:1204-1206`; code `wp40/source/simple_map.lua:308-343`
- **What:** "The 24 outpost anchors and 12 bandit camps are live, and since WP40 R7 … their positions come from the authored anchor layout". All 36 rows are `"placed"` since Round 46; the counts (24, 12) are right. `world.md:557-558` in the same file already says positions are placed per world.
- **Evidence:** `simple_map.lua:308` `{2,"outpost_1","outpost","placed","mid"}` … `:343`.
- **Proposal:** "their anchors come from the authored roster and are placed per world (`world_zones.md` §8.5)". Doc is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-06 | Low | docs | world_zones §7.3: Round 29 anchor moves and "|x| = 96" for two bandit camps

- **Verdict:** CONFIRMED — `world_zones.md:400-404` as cited; the bandit rows (`simple_map.lua:333-343`) are all `"placed"`, and the middle-road clearance is `R.CORRIDOR = {min = 80, reserve = 58, …}` (`placement_rules.lua:79-84`). Doc is wrong (history written as current data).
- **Where:** `docs/design/world_zones.md:400-404`; code `wp40/placement_rules.lua:79-84`, `wp40/source/simple_map.lua:333-343`
- **What:** The paragraph says outposts, frontier camps, clash sites and rares "moved about 120 nodes toward their home side" and "Coalbrand Yard and Sunderstrap Camp also moved to |x| = 96 so the middle road runs straight". Those anchors no longer have authored positions; the middle-road clearance is now the placement rule |x| ≥ max(80, core/2 + 58) (`R.CORRIDOR`), which §8.5 (L1315-1316) states. As written it reads as current position data.
- **Evidence:** `placement_rules.lua:82` `R.CORRIDOR = {min = 80, reserve = 58, zones = {…}}`; the two bandit rows `simple_map.lua:335,341` are `"placed"`.
- **Proposal:** Mark the sentence as Round 29 history or drop it, keeping the |z| ≈ 360 width rule. Doc is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-07 | Low | docs | Home neighbour band written "level 10–20" in three places

- **Verdict:** CONFIRMED — the three sentences (`world.md:118`, `:483`, `world_zones.md:174`) say 10–20; all six home zones are `11,20` in `simple_map.lua:65,70,75,81,86,91`. Doc is wrong.
- **Where:** `docs/design/world.md:118`, `docs/design/world.md:483`, `docs/design/world_zones.md:174`; code `wp40/source/simple_map.lua:65,70,75,81,86,91`
- **What:** The capital's outer neighbour is described as "a level-10–20 neighbor/zone/home territory". The home zones are 11–20 in the zone records and in every other table (world.md:93, world_zones.md:62).
- **Evidence:** `simple_map.lua:65` Copperfell `…,11,20,…`, likewise Goldmead, Starbough, Mournfen, Redtusk, Raincall.
- **Proposal:** Write 11–20. Doc is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-08 | Low | docs | settlements.md: starts-only preparation has "one aligned mapchunk request in flight"

- **Verdict:** CONFIRMED — `settlements.md:139-141` says one request; `world_preparation.md:95-96` says at most two, and the code follows world_preparation.md (`starts_preload.lua:35` `MAX_INFLIGHT = 2`, `:197`). settlements.md is wrong.
- **Where:** `docs/design/settlements.md:139-141`; code `mods/CORE/grug_core/starts_preload.lua:35,197`
- **What:** settlements.md says the preparation runs "with one aligned mapchunk request in flight". `world_preparation.md:95-96` and the code use at most two outstanding requests. Contradiction between two design files; settlements.md is stale.
- **Evidence:** `starts_preload.lua:35` `local NOTIFY_INTERVAL, MAX_INFLIGHT = 0.2, 2`; `:197` `while #queue < MAX_INFLIGHT …`.
- **Proposal:** Replace the clause with a plain pointer to world_preparation.md. settlements.md is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-09 | Low | docs | world_zones §8 catalog and its POI legend omit the Round 58 camps

- **Verdict:** CONFIRMED — the legend (`world_zones.md:1115-1128`) has no letter for them (its **M** is the race's one peaceful `mine` slot); `simple_map.lua:416-441` has 20 `mining_camp` and 6 `camp_construction` rows; §8.5 (:1291, :1330-1335) describes them. The catalog is behind the code.
- **Where:** `docs/design/world_zones.md:1115-1128` (legend) and `:1141-1196` (POI column of §8.1–§8.3); code `wp40/source/simple_map.lua:409-441`
- **What:** The "reserved POIs" column claims to list each zone's POIs but has no letter for the 20 mining camps (one in every 11–40 non-capital zone) or the 6 camps under construction (every contested 31–40 zone). §8.5 (L1289-1292, L1329-1335) and settlements.md:1233-1256 describe them, so the catalog is incomplete, not contradictory. All other POI letters were checked row by row against the anchor rows and match (V, O×n, B, M, W, K×n, F, P×4, D/M6, R:name in 38 zones).
- **Evidence:** `simple_map.lua:416-441` (26 rows, zones 2,4,5,7,9,10,12,14,15,16,18,20,21,23,25,26,28,30,31,32).
- **Proposal:** Add two legend letters (e.g. **G** mining camp, **U** camp under construction) and the letters in the 20 resp. 6 rows. The doc is behind the code.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-10 | Low | docs | world_zones §13.3 slot vocabulary lacks `mining_camp` and `camp_construction`

- **Verdict:** CONFIRMED — `world_zones.md:2207-2212` lists the slots without them (`rg mining_camp docs/design/world_zones.md` finds nothing), while `simple_map.lua:416-441` uses both slot ids. Doc is behind.
- **Where:** `docs/design/world_zones.md:2207-2212`; code `wp40/source/simple_map.lua:416-441`
- **What:** "Slot vocabulary remains `start`, `capital`, … plus the Round 31 PvP slots". The Round 58 slots `mining_camp` and `camp_construction` are resolved through the same `anchor(zone_id, slot_id)` seam but are not listed.
- **Evidence:** `simple_map.lua:416` `{2,"mining_camp","mining_camp","placed","low",2}`, `:436` `{5,"camp_construction",…}`.
- **Proposal:** Add "and the Round 58 slots `mining_camp`, `camp_construction`". Doc is behind.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-11 | Low | docs | world_zones §13.2 public `grug_zones` surface omits `water_query_at`

- **Verdict:** CONFIRMED — `world_zones.md:2136-2148` ends with `hard_footprint_in` and names `PUBLIC_METHODS` as the list; `zone_authority.lua:5-26` has 18 entries, the last `water_query_at` (Round 51 T2). Doc is behind.
- **Where:** `docs/design/world_zones.md:2136-2148`; code `mods/CORE/grug_core/zone_authority.lua:5-26`
- **What:** The list of the final registry's methods ends with `hard_footprint_in`; `PUBLIC_METHODS` also has `water_query_at` (Round 51 T2), which world_map.md:598 and spawn_regions.md:366 use by name. The doc even names `PUBLIC_METHODS` as "the list".
- **Evidence:** `zone_authority.lua:23-25` "Round 51 T2: the water query … `water_query_at`".
- **Proposal:** Add `water_query_at` (class, zone, level, distance, depth, protected). Doc is behind.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-12 | Low | docs | biomes_mobs §2 table: crags "snow above y 80"

- **Verdict:** CONFIRMED — `biomes_mobs.md:276` says "snow above y 80"; the line constants are `TREE_START = 160, TREE_LINE = 220, SNOW_LINE = 280` (`habitat_registry.lua:54`), and the snowy crags are a separate biome (`grug_crags_snowy`, `r7_r6_manifest.lua:55`, a zone biome roll), not a y-80 rule. Doc is wrong. (The same row's "pine above y 60" was not checked.)
- **Where:** `docs/design/biomes_mobs.md:276`; code `mods/MAPGEN/grug_mapgen/wp40/habitat_registry.lua:54`
- **What:** The crags row says "gravel/stone tops, snow above y 80". The snow rule is the snow line y 280 (± field), with dust in the 20 nodes below (world_zones.md:977-986, and biomes_mobs.md:295-297 itself). No y-80 snow rule exists in the writer (`rg "snow.*80"` over `wp40/` finds none).
- **Evidence:** `habitat_registry.lua:54` `TREE_START = 160, TREE_LINE = 220, SNOW_LINE = 280`.
- **Proposal:** Drop "snow above y 80" or point to the snow line. Doc is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-13 | Low | docs | settlements.md: Lethariel turrets "about every 48 nodes"

- **Verdict:** CONFIRMED — `settlements.md:437-438` says 48; Lethariel's edge kind `stone_narrow` carries `TURRET_EVERY = 48` (`capital_planner.lua:160-162`), but `r7_capitals.lua:197-199` applies the edge opts first and the `M.STYLE` row last, so the style's `TURRET_EVERY = 96` (`capital_planner.lua:203`) wins. The code follows `settlements.md:364-366` and `world_zones.md:1932-1934`; the 48 is the overridden edge value. Doc is wrong.
- **Where:** `docs/design/settlements.md:437-438`; code `mods/MAPGEN/grug_mapgen/wp40/capital_planner.lua:197-203`
- **What:** The Lethariel curtain is described with "slim turrets about every 48 nodes". Since Round 26 the per-capital style sets `TURRET_EVERY = 96` for Lethariel (world_zones.md:1932-1934 "few towers"; settlements.md:364-366 itself says 64 to 96).
- **Evidence:** `capital_planner.lua:203` `BEND_GAP = 60, TURRET_EVERY = 96, …` (lethariel); merge order `r7_capitals.lua:197-199`.
- **Proposal:** "slim turrets on its own sparse rhythm (`M.STYLE`)". Doc is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-14 | Low | docs | settlements.md: Gor Drazhak "timber tower about every fifty-six nodes"

- **Verdict:** CONFIRMED — `settlements.md:462-463` says fifty-six, which is the `palisade` edge value (`capital_planner.lua:157-159`); the style row's `TURRET_EVERY = 84` (`:196`) overrides it (merge order `r7_capitals.lua:197-199`). Doc is wrong.
- **Where:** `docs/design/settlements.md:462-463`; code `mods/MAPGEN/grug_mapgen/wp40/capital_planner.lua:192-198`
- **What:** Gor Drazhak's palisade is said to carry "a timber tower about every fifty-six nodes"; its style row sets `TURRET_EVERY = 84` (Round 26).
- **Evidence:** `capital_planner.lua:196` `TURRET_EVERY = 84, RINGS = {0.34, 0.74}, …` (gor_drazhak).
- **Proposal:** Align with the style table or drop the number. Doc is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-15 | Low | docs | biomes_mobs §6: marshbloom tier band "25–45"

- **Verdict:** CONFIRMED — `biomes_mobs.md:1583` says 25–45; marshbloom's zones (`catalog.lua:190-192`: Lorindor, Whitebridge Shire, Ossuary Reach, Whispering Reedlands) are all `21,30` (`simple_map.lua:72,77,83,93`); `biomes_mobs.md:245` says 21–30. The code follows :245. Doc (:1583) is wrong.
- **Where:** `docs/design/biomes_mobs.md:1583`; code `mods/ITEMS/grug_gathering/catalog.lua:190-194`
- **What:** The material map gives Spices T2 (marshbloom) the band 25–45. Its four zones (Lorindor, Whitebridge Shire, Ossuary Reach, Whispering Reedlands) are all 21–30, which biomes_mobs.md:245 states ("marshbloom T2 (21–30)"). Internal contradiction.
- **Evidence:** `catalog.lua:190-192` zone list; `simple_map.lua:72,77,83,93` levels 21–30.
- **Proposal:** Write 21–30. Doc is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-16 | Low | docs | biomes_mobs: stormkelp / rock salt / found-only food band "45–60"

- **Verdict:** CONFIRMED — stormkelp's zones include `front_shattered_line` (41–50) (`catalog.lua:255-257`, `simple_map.lua:99`), so 41–60, as `biomes_mobs.md:245` says; rock salt's zones are Gravesalt (51–60), Stormscale and Wyrmglass (60) (`catalog.lua:243-245`), so 51–60, and with wild cocoa at 51–60 the found-only food row (:1578) is 51–60 too. Doc (:514, :1578, :1584) is wrong.
- **Where:** `docs/design/biomes_mobs.md:514`, `:1578`, `:1584`; code `mods/ITEMS/grug_gathering/catalog.lua:243-259`
- **What:** Three places give 45–60. Stormkelp grows in The Shattered Line (41–50) too, so its band is 41–60 (biomes_mobs.md:245 says so); Rock Salt's zones are Gravesalt (51–60) and the islands (60), so 51–60.
- **Evidence:** `catalog.lua:255-257` stormkelp zones include `front_shattered_line`; `:243-245` rock salt zones; `simple_map.lua:96-101` levels.
- **Proposal:** Stormkelp 41–60, rock salt (and the found-only food row) 51–60. Doc is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-17 | Low | docs | biomes_mobs §2.1: "fourteen tree rows … eight species" leaves out the swamp tree

- **Verdict:** CONFIRMED — `rg -o "\|treegen:[a-z_]+\|"` over `r7_r6_manifest.lua` gives 15 rows (apple ×3, aspen, gravewood ×2, jungle ×2, kapok, pine ×3, silverwood, acacia, swamp at :184), and `treegen.lua:1000` has a `swamp` species. `biomes_mobs.md:345-347` says fourteen rows and eight species; :283 itself calls the swamp tree generated. Doc is behind.
- **Where:** `docs/design/biomes_mobs.md:345-347`; code `mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua:104-184`
- **What:** The manifest has 15 `treegen:` tree rows over nine species: the swamp tree (`treegen:swamp`, Round 47) is a generated tree too (biomes_mobs.md:283 says so), but the count and species list omit it.
- **Evidence:** `r7_r6_manifest.lua:184` `swamp_tree|grug_swamp|template|treegen:swamp|…|1|120|…`.
- **Proposal:** "fifteen tree rows (… gravewood and the swamp tree)". Doc is behind.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-18 | Low | docs | biomes_mobs §3.0 disposition table misses Flintback and the rift boss

- **Verdict:** CONFIRMED — `disposition.lua:30-43` classifies `flintback` and `rift_boss` as aggressive; neither name is in the table at `biomes_mobs.md:716-721` (Flintback appears only in the Round 71 table at :910; the rift boss's texture is `grug_mobs_isquarre.png`, `rift.lua:40`). Doc is behind.
- **Where:** `docs/design/biomes_mobs.md:716-721`; code `mods/ENTITIES/grug_mobs/disposition.lua:30-45`
- **What:** The table is introduced as "the current family classification". `disposition.lua` classifies `flintback` and `rift_boss` as aggressive; neither appears in the table (Duewarden and Auditor Nemm do).
- **Evidence:** `disposition.lua:33` `"dungeon_master", "ember_wisp", "flintback", …`; `:40` `"rift_boss"`.
- **Proposal:** Add Flintback and Isquarre (rift boss) to the Aggressive row. Doc is behind.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-19 | Low | docs | biomes_mobs §3.3 rare levels "~L" disagree with the dens' placement bands

- **Verdict:** CONFIRMED — `placement.lua:23,330,387` places a row in its zone's level third (`band`, relaxed by `step.band`), and `rares.lua:11-12,388` makes the level a property of where the route runs. Korgan's Bane (zone 5, 31–40, mid), Grimtusk (7, 11–20, mid), Ashmaw (23, 11–20, mid) and Silkfang (37, 51–60, high) therefore cannot sit at ~40, ~12, ~12 and ~55 except after relaxation. Dustwing ~38 in a mid third of 31–40 is borderline for a "~" value. Doc looks wrong; exact per-seed levels were not computed (static audit), so confidence stays medium.
- **Where:** `docs/design/biomes_mobs.md:1090-1100`; code `wp40/source/simple_map.lua:374-383`, `wp40/placement_rules.lua:38`, `wp40/placement.lua:23,330,387`
- **What:** The rare dens are placed in the level third given on their anchor row; the rare's level is the level at its route (region level in a recipe zone). Rows: Korgan's Bane "~40" but placed "mid" in Stormvault 31–40 (34–36); Dustwing "~38", "mid" in Bannerbreak (34–36); Grimtusk and Ashmaw "~12", "mid" in their 11–20 zones (14–16); Silkfang "~55", "high" in Skyglass 51–60 (57–60). Old Whitefang, Marrowclaw and Emerald Coil fit.
- **Evidence:** `simple_map.lua:374` `{7,"rare_grimtusk","rare_route","placed","mid"}`, `:376` Korgan's Bane mid, `:377` Silkfang high, `:379` Dustwing mid, `:381` Ashmaw mid.
- **Proposal:** Either update the column from the seed fleet's region levels at the dens, or replace it with "the region level at its den (band: mid/high third)". Doc looks wrong (pre-Round-46 radial numbers; `rares.lua:340-470` comments are radial-era too).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** medium

### DD1-20 | Low | docs | biomes_mobs §6: deep multipliers named for "Ordinary ores, Diamond and Abyssal Crystal"

- **Verdict:** CONFIRMED — `biomes_mobs.md:1558-1560` as cited; the deep bands (`registry.lua:338-341`) are applied to every resource row (`r7_native.lua:596-618`), Ruby and Sapphire included; the code follows `world_zones.md:1563-1564`. biomes_mobs.md is wrong (same root as DD1-02; fix together).
- **Where:** `docs/design/biomes_mobs.md:1558-1560`; code `mods/ITEMS/grug_materials/registry.lua:331-341`
- **What:** The deep bands (+25 % / +50 %) apply to every T6 row, Ruby and Sapphire included (world_zones.md:1563-1564: "the deep multipliers apply to the T6 gems (Diamond, Ruby, Sapphire)"). The two design files disagree.
- **Evidence:** `registry.lua:331-332` "Diamond, Ruby and Sapphire reach the deep bands through T6"; `:338-341` `deep_bands`.
- **Proposal:** "Ordinary ores, the T6 gems and Abyssal Crystal". Doc is wrong.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-21 | Low | docs | world.md §10 (Nether) keeps an open question in the design file

- **Verdict:** CONFIRMED — `world.md:1263-1266` lists the three options and "which one is open"; AGENTS.md:126-128 ("no open questions, no discussion") and the options already stand in `TODO-design-nether.md:9-12`. The other two cited places (`:1015-1017`, `:1229-1230`) are plain pointers to the TODO file, the sanctioned pattern, and need no change.
- **Where:** `docs/design/world.md:1263-1266`
- **What:** "An enemy-side exit lands in a contested zone, forces a visible PvP state, or uses another explicitly authored interception rule; which one is open (`TODO-design-nether.md`)." AGENTS.md "Documentation layers" puts open questions in `TODO-<topic>.md` only; the design file should state only the decided requirement and point to the TODO file.
- **Evidence:** AGENTS.md:126-130.
- **Proposal:** Keep the gating requirement and a pointer; drop the three options (they are already in `TODO-design-nether.md:9-12`).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-22 | Low | docs | story.md carries an open question (DW-08) in its text

- **Verdict:** CONFIRMED — `story.md:29-30` and `:137-138` carry "open question … DW-08" parentheticals; DW-08 is in `BACKLOG.md:481`. AGENTS.md:126-127 rules this out for `docs/design/`.
- **Where:** `docs/design/story.md:29-30`, `:137-138`
- **What:** "Scorched breaches and twisted vegetation are not built (an open question, BACKLOG "Audit 2026-10 open questions", DW-08)" and "open question DW-08 in BACKLOG". A design file should say only what is decided (not built in V1); the open question belongs in the backlog or a TODO file.
- **Evidence:** AGENTS.md:126-130.
- **Proposal:** Drop the "open question" parentheticals; keep "not built in V1".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-23 | Low | docs | biomes_mobs §4 "Registered but placed nowhere (open questions …)"

- **Verdict:** CONFIRMED — `biomes_mobs.md:1197-1203` carries the "open questions" label with a BACKLOG link (DW-04, `BACKLOG.md:479`); outside `subtypes.json` the two sub-type ids appear only in `data/names.json` (a name table, not a recipe), so the stated fact holds.
- **Where:** `docs/design/biomes_mobs.md:1197-1203`
- **What:** The paragraph is labelled as open questions with a BACKLOG link (DW-04). The facts it states are correct (`causeway_construct`, `siege_war_construct` in `subtypes.json`, in no recipe; checked with rg over `data/zones/`), but the "open questions" framing does not belong in `docs/design/`.
- **Evidence:** AGENTS.md:126-130; `rg -c "causeway_construct|siege_war_construct" mods/ENTITIES/grug_mobs/data/zones` → no hits.
- **Proposal:** State the fact (registered, not placed) without the open-question label; the decision lives in BACKLOG.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-24 | Low | docs | settlements.md: Kezamba's layout "open to the user's correction like any other design"

- **Verdict:** CONFIRMED — `settlements.md:487-490` reads as cited; `:430` and `:457-458` each call a different capital (Lethariel, Gor Drazhak) "the third capital". (Whether :488's "third capital" means Kezamba or Lethariel is itself ambiguous, which supports dropping the ordinals.)
- **Where:** `docs/design/settlements.md:487-490`
- **What:** "How a capital with a lake in its core is laid out is the third capital's own lane, 2026-09-15/16, and is open to the user's correction like any other design." Process discussion in a decided-design file (AGENTS.md "no open questions, no discussion"). It also names Kezamba "the third capital" while L430-431 names Lethariel and L457-458 names Gor Drazhak "the third capital": three different "third capitals" in one section.
- **Evidence:** `settlements.md:430` "with the third capital, Lethariel"; `:457-458` "Added 2026-09-15 with the third capital, Gor Drazhak"; `:487-488`.
- **Proposal:** Drop the sentence and the ordinal history ("third capital"); keep the dates if wanted.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD1-25 | Low | docs | world_zones §8.1: Lorindor "southwest of Lethariel"

- **Verdict:** CONFIRMED — hubs are Lethariel (1800, −1500) and Lorindor (900, −1500) (`simple_map.lua` zone rows 13 and 14), due west; `zone_bias` (`simple_map.lua:219`) has no entry for zone 14. Doc is wrong.
- **Where:** `docs/design/world_zones.md:1156`; code `wp40/source/simple_map.lua:76-77`
- **What:** Lorindor's hub (900, −1500) lies due west of Lethariel's (1800, −1500) at the same z; nothing in the zone field biases it south (`zone_bias` has no entry for 14). "Southwest" is at best a per-seed accident.
- **Evidence:** `simple_map.lua:76` Lethariel `…,1800,-1500,…`; `:77` Lorindor `…,900,-1500,…`.
- **Proposal:** "west of Lethariel". Doc is wrong (flavour text, but it is the zone catalog).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

## Backlog notes

- world_map.md:879-880 calls 266 nodes "half the capital's reserved square"; world_zones.md:1847 defines the reserved square as 512 and 532 as the protection bound (`simple_map.lua:610` `bound_width=532`); the code comment `grug_map/location.lua:41-44` uses the same loose wording. Terminology only.
- `wp40/source/simple_map.lua:169-170`: the channel records' `warning_width=48` and `minimum_hard_width=104` are read nowhere (`rg warning_width|minimum_hard_width mods` → only these lines); the flight band is `grug_mounts.WARNING_WIDTH = 40` (`grug_mounts/catalog.lua:5`) and the strait check uses `zone_field.check.min_strait` (L234). Dead data fields (code lane).
- The palette spawning path (`grug_mobs/spawn_regions.lua:48,137-142,225`; `spawn_policy.lua:608-690` `night_fallback_allows` and the zone-palette gates) serves no zone: every `data/zones/*.spawns.json` has a recipe and none has `"palette"`. biomes_mobs.md:1322-1330 still documents it as a live alternative. Dead code candidate for the grug_mobs lane.
- `grug_mobs/rares.lua:340-470` comments describe the radial-era level field ("seat at (0, ±900)", "zone inner, radial 400-470 nodes"); stale comments.
- `grug_materials/registry.lua:346-349` `CURRENT_SCATTER_RESOURCES` ("the shipped resource roster") lists 10 of the 16 resources (no anthracite, jade, citrine, ruby, sapphire, abyssal crystal); not checked who reads it — for the items lane.
- biomes_mobs.md:719 calls the whelps "Ice Whelp, Storm Whelp" (entity ids), :907 "Ice Whelp, Wyvern Whelp" (display names, `data/names.json:686,694`); mixed naming, both correct in their sense.
- (Verifier) `capital_planner.lua:157-165`: the `TURRET_EVERY` values of the `palisade`, `stone_narrow` and `palisade_narrow` edge kinds (56, 48, 56) are always overridden, because every one of the six capitals has an `M.STYLE` row with its own `TURRET_EVERY` (:177, :183, :189, :196, :203, :209) and `r7_capitals.lua:197-199` applies the style after the edge. They are the source of DD1-13/-14's stale numbers. Dead values (mapgen lane); removing them changes no output.

## Good to know

- `world_zones.md` §7.1 hub table, §8.1–§8.3 rows (level, race, PvP, biome weights), §8.4 relief ids and §7.6 relief table match the code exactly for all 38 zones; §11's resource density table matches `r6_content.lua:114-131` cell for cell, including the ½ rows; the WP33 source zone sets match `grug_gathering/catalog.lua` for all 12 sources.
- `world_zones.md` §8.5 placement kinds, order, gaps and relaxation steps match `placement_rules.lua` exactly; §9.2 road constants match `road_layout.lua:55-110`; §12 capital target bands and waves match `terrain_data.lua:51-61`; §16 garrison respawns match `pvp_garrison.lua:64-68`.
- `spawn_regions.md` builder constants match `spawn_regions_core.lua:51-109`; all 27 quest places (ids, names, kinds, and the "34–37 open kind" claim for the four contested-zone places) match the recipes.
- biomes_mobs.md §2.1 decoration fractions match `r7_r6_manifest.lua` row for row; the Round 28 catalogue counts (218 sub-types, 45 leaders, 12 tints, 122 items, 27 drop families) match the data files; shark and angelfish numbers match `shark.lua` / `reed_angelfish.lua`.
- No dead file links or anchors in the nine documents (every relative link and `#anchor` resolved; backticked file names all exist except world-folder runtime files).
- M1's §13.3 Round 51 staleness: searched the other eight files for the same kind (belt/channel mob levels, old buckets); world.md §2b, spawn_regions.md, biomes_mobs.md and world_map.md already state the Round 51 rules correctly; nothing further found.
- story.md chapter gate levels (40/45/53/58) were not verified against the quest data (belongs to the quests package).
