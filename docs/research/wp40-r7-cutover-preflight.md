# WP40 R7 Atomic Cutover Preflight

Status: supplementary, non-authoritative implementation preflight, verified
2026-08-31 against commit `d6002a289aa079fba4fe1d943a00dc50f777f30a`.
The accepted design, R0-R6 contracts and their review records remain authority.
This file records the durable R7 audit and the remaining decisions; it does not
activate mapgen or change a work-package status.

Labels used below:

- **Historically recorded** means a claim preserved from an accepted document
  or commit.
- **Currently verified** means the cited production source was inspected again
  at the baseline commit above.
- **Recommended** means a preflight proposal that still needs to be frozen in
  the reviewed R7 contract before implementation.

## 1. Provenance and earlier-agent search

The suspected earlier R7 cutover-matrix work does exist, but not as a separate
agent scratch file:

- **Historically recorded:** the accepted R0 result explicitly required an
  `rg`-backed legacy geography/height API-to-consumer matrix
  (`docs/research/wp40-simple-map-rebase-plan.md:408`). Its independent Fable
  review and clean focused rereview are recorded at
  `docs/research/wp40-simple-map-rebase-plan.md:427`.
- **Currently verified:** the durable result is
  `docs/research/wp40-engineering-brief.md:310` through section 4.4, introduced
  by commit `58a16f5ef2d7b009d4e283d6ee3d50a77cd8d3d8` on 2026-08-25. It contains the
  legacy query-consumer matrix, hidden-coordinate inventory, four-writer
  inventory and removal gates (`docs/research/wp40-engineering-brief.md:310`,
  `:330`, `:346`, `:371`).
- **Currently verified:** all reachable refs, reflogs, worktree metadata, the
  commit history for the engineering brief and unreachable Git objects were
  searched. No second Simple-map R7 matrix or missing durable agent report was
  found. The surviving dirty Claude worktree is based on the superseded exact-T2
  line; its R7 mentions refer to the old T2 delivery stages, not the current
  Simple-map R7 atomic cutover. No `/tmp` evidence is required for this result.

This file re-verifies and extends that accepted snapshot. In particular, it
adds the post-R6 WP33 gathering boundary that was not closed when R0 was written.

## 2. R7 entry state and hard GO blockers

**Currently verified:** R0-R6 remain non-writing. The WP40 public loader still
publishes `enabled = false` and says publication waits for R7
(`mods/MAPGEN/grug_mapgen/wp40/init.lua:13`). R5 accepts only
`offline_fixture`/`engine_fixture` call modes
(`mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua:693`), while R6 accepts only
`fixture`/`replay_fixture` (`mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:1101`).
R6 is independently accepted but still disabled
(`docs/research/wp40-simple-map-rebase-plan.md:961`).

R7 is not ready to activate until all of these are frozen and present in the
same reviewed commit:

1. **Accepted WP33 registrations.** The R6 constructor must receive the exact
   six cultural records and digests; zero or six is the only accepted population
   and R7 must refuse zero (`docs/research/wp40-simple-map-r6-contract.md:625`,
   `mods/MAPGEN/grug_mapgen/wp40/r6.lua:253`).
2. **The WP33 non-cultural gathering delta.** R6 deliberately excludes herbs,
   spices, crops and found-only foods (`docs/design/biomes_mobs.md:760`), while
   WP33 owns all of them (`BACKLOG.md:56`). Section 7 below defines the bounded
   extension required before activation.
3. **A closed native-registration allowlist.** Legacy surface biomes, scatter
   resources and decorations cannot coexist with R6 output
   (`docs/research/wp40-engineering-brief.md:361`). The exact substrate-only
   registrations that remain must be named in the R7 contract.
4. **A live engine-content projection.** Every node, CID, role mask, param2,
   schematic/template and WP43 projection used by R5/R6/WP33 must validate before
   the writer is registered. Unknown content is a startup failure, never a
   skipped placement.
5. **An exact live mapgen manifest.** Production must read effective settings
   and compare every manifest field before registering its mapgen script. The
   frozen values include v7, water level 1, chunksize 5, mapgen limit 31007,
   one emerge thread and the exact flag sets
   (`mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua:30`). `game.conf` already
   restricts the game to v7 (`game.conf:6`), but that alone does not validate a
   world's effective settings.

No partially satisfied state may register a callback, publish `grug_zones` or
fall back to a legacy writer.

## 3. Exact current writer and registration inventory

### 3.1 Active geography writes

All four rows below are **currently verified** and must disappear together:

| Legacy path | Current trigger and write | R7 disposition |
|---|---|---|
| Ocean mapgen writer | `ocean_mask.lua` publishes legacy rectangle IPC and registers `ocean_mask_mapgen.lua` (`mods/MAPGEN/grug_mapgen/ocean_mask.lua:46`); its mapgen-environment callback mutates the VM, updates liquids and lighting (`mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua:515`, `:543`, `:547`, `:629`) | Remove loader, IPC key and callback; the one WP40 production mapgen script owns water/terrain in its single transaction. |
| Ocean healing LBM | `grug_mapgen:ocean_mask_heal` runs on every load and performs air/water `bulk_set_node` writes (`mods/MAPGEN/grug_mapgen/ocean_mask.lua:577`, `:606`) | Remove. WP40 is fresh-world-only and cannot retain an old-geometry runtime healer. |
| Structures callback | Main-environment `register_on_generated` builds capital platforms, outposts and bandit fires, then calls `set_data`, liquids, lighting and `write_to_map` (`mods/MAPGEN/grug_mapgen/structures.lua:776`, `:854`, `:875`, `:887`) | Remove callback. Migrate every still-required fixed feature to stable R4 anchors and the consolidated transaction; do not retain a main-environment second pass. |
| Capital repair | `grug_core.ensure_camp_platform_built` is overridden by `structures.lua`; it reads and writes a non-mapgen VoxelManip (`mods/MAPGEN/grug_mapgen/structures.lua:291`, `:336`, `:365`, `:387`) | Remove the repair implementation and its old persistence/emerge state machine. A final capital anchor/height is analytic and never repaired after generation. |

`grug_mapgen/init.lua` currently loads old biomes, ores, decorations, ocean mask
and structures after the disabled WP40 foundation
(`mods/MAPGEN/grug_mapgen/init.lua:93`). That five-file transition sequence is
the atomic edit boundary.

`grug_mobs.place_camp` uses `core.set_node` as an explicit runtime placement API
(`mods/ENTITIES/grug_mobs/camps.lua:768`, `:804`), and its two LBMs initialize
metadata/timers rather than generate geography (`mods/ENTITIES/grug_mobs/camps.lua:733`,
`:755`). These are not a competing terrain writer. They may remain only for
later runtime placement/activation of an already-authored camp node; R7 must not
call `place_camp` to realize fixed mapgen anchors.

### 3.2 Engine registrations

**Currently verified:** `default` does not register its v7 biome/ore/decoration
set; the vendored patch delegates that ownership to `grug_mapgen`
(`mods/BASE/default/mapgen.lua:2486`). The active legacy registrations are:

| Registration family | Current source | R7 rule |
|---|---|---|
| Surface biome cuboids | old biome registrations in `mods/MAPGEN/grug_mapgen/biomes.lua:125` and the universal rows beginning at `:502` | Zero legacy surface-biome authority. Use only a new, closed substrate-native allowlist if engine cave/dungeon material defaults require it. No logical WP40 biome is selected by engine climate. |
| Four native blob definitions | literal blob registrations at `mods/MAPGEN/grug_mapgen/ores.lua:39`, `:58`, `:77`, `:116` | Recommended retained-native candidates, subject to content-classification and R8 native-preservation fixtures. Name each retained row explicitly. |
| WP43 scatter resources | generated scatter registrations at `mods/MAPGEN/grug_mapgen/ores.lua:217` | Remove all. R6 P8 is the sole resource placement authority. |
| Five non-T1 strata | the T2-T6 loop at `mods/MAPGEN/grug_mapgen/ores.lua:233` | Retain as the required native WP43 substrate, unless R7 replaces them with byte-equivalent explicit registrations. T1 remains `default:stone` and has no registration. |
| Legacy trees/ground cover | all `register_tree`/`register_plant` calls backed by `core.register_decoration` (`mods/MAPGEN/grug_mapgen/decorations.lua:83`, `:104`) | Remove all engine decoration registrations. R6 owns the closed 48-ID deterministic set (`docs/design/biomes_mobs.md:723`). |

**Recommended simplification:** create a small R7 native-substrate registration
module instead of conditionally loading pieces of the old `biomes.lua` and
`ores.lua`. It should contain only the contract-listed cave/dungeon substrate,
four accepted blob definitions and five strata. This makes the removal gate a
file-level fact and prevents a future legacy surface row from becoming active
because it shares a loader with a retained stratum. The R7 contract must first
prove which minimal biome records native dungeons/cave liquids require; that
choice is not silently delegated to the old surface catalog.

## 4. Legacy query consumer matrix

Every row is **currently verified** at the baseline. The target API already
exists privately in R4 (`mods/MAPGEN/grug_mapgen/wp40/zones.lua:912`) and the
public surface is fixed by `docs/design/world_zones.md:1052`.

| Legacy helper | Complete current productive consumers | R7 migration |
|---|---|---|
| `grug_core.surface_level_at` | capital platform state in `grug_core` (`mods/CORE/grug_core/init.lua:587`, `:604`); old structure placement (`mods/MAPGEN/grug_mapgen/structures.lua:539`); runtime probe | Keep one explicit compatibility function whose only implementation is `grug_zones.terrain_height_at(x,z)`. Remove every `core.get_spawn_level` fallback. |
| `grug_core.territory_at` | internal legacy zone/mob/guard logic; central protection (`mods/CORE/grug_core/protection.lua:204`); golem, rabbit, camp, rare gates (`mods/ENTITIES/grug_mobs/golem.lua:39`, `rabbit.lua:31`, `camps.lua:658`, `rares.lua:196`) | Use `faction_at` for culture/faction identity and `territory_rule_at` for construction policy. A temporary adapter may return faction or `ocean`, exactly as the R4 compatibility seam does (`mods/MAPGEN/grug_mapgen/wp40/zones.lua:1139`). |
| `grug_core.zone_at` | central `_grug_spawn_zones` dispatcher (`mods/ENTITIES/grug_mobs/init.lua:118`), plus `bandit.lua:104`, `skeleton_archer.lua:45`, legacy guard floor and runtime probe | Install the one reviewed coarse-bucket adapter already defined at `mods/MAPGEN/grug_mapgen/wp40/zones.lua:1142`; migrate the 27 definitions in 26 mob files to stable named-zone/palette results when the R7 contract requires exact identity. No second bucket formula. |
| `grug_core.mob_level_at` | mob/guard stat derivation (`mods/ENTITIES/grug_mobs/levels.lua:414`), legacy guard/difficulty internals and runtime probe | Direct adapter to `grug_zones.mob_level_at`. |
| `grug_core.guard_level_at` | guard branch in `mods/ENTITIES/grug_mobs/levels.lua:412` | Direct adapter to `grug_zones.guard_level_at`. |
| `grug_core.difficulty_at` | no productive caller beyond its definition (`mods/CORE/grug_core/init.lua:1200`) | Prefer deletion after a final all-repo audit; otherwise keep only the R4 compatibility formula (`mods/MAPGEN/grug_mapgen/wp40/zones.lua:1131`). |
| `grug_core.open_sea_at` | Kraken leash/captured spawn check (`mods/ENTITIES/grug_mobs/kraken.lua:20`) and runtime probe | Replace with `water_class_at(x,z) == "deep_ocean"`; do not retain rectangle distance. |
| Central protection | `grug_core/protection.lua`; callers delegate through `core.is_protected` | One policy path over `territory_rule_at`, player faction and hard volumes. Preserve bypass, empty-name and prior-handler delegation. Required boundary KATs are already enumerated at `docs/research/wp40-engineering-brief.md:323`. |

The compatibility table in R4 is private implementation support, not a second
public registry (`mods/MAPGEN/grug_mapgen/wp40/zones.lua:1117`). R7 publishes
exactly one `grug_zones` table and installs only the named `grug_core` adapters.

## 5. Hidden coordinate and anchor consumers

The following **currently verified** state must migrate in R7 even where no
legacy query helper appears:

| Current authority/consumer | Current source | R7 target |
|---|---|---|
| Six capital literals and spawn/platform persistence | `mods/CORE/grug_core/init.lua:84`, `:575`, `:963` | Stable `capital`/`start` anchor records and project height. Delete platform-Y discovery, persistence, retry and repair. |
| 24 outpost and 12 bandit candidates | providers at `mods/CORE/grug_core/init.lua:295` and `:447`; old structure callback consumes them | Stable `outpost_<n>` and `bandit_<n>` anchors; no runtime candidate selection. |
| Join/respawn | `mods/PLAYER/grug_factions/init.lua:138`, `:150`, `:238` | Stable start/capital anchor plus exact authored height. |
| Capital traders | relative placement from `grug_core.capitals` at `mods/ENTITIES/grug_traders/vendors.lua:294`, `:310` | Local offsets may remain, but their origin must be the final capital anchor. |
| Outpost patrols/camps | comments and runtime logic rooted in old outpost anchors at `mods/ENTITIES/grug_mobs/camps.lua:311` | Stable outpost/camp anchor IDs. Runtime timers may remain after the nodes are authored by the one writer. |
| Rare patrol routes | raw legacy territory/routes in `mods/ENTITIES/grug_mobs/rares.lua:196` | Stable `rare_<stable_rare_id>` anchor/payload records; no raw replacement route invention. |
| Old rectangular biome identity | `mods/MAPGEN/grug_mapgen/biomes.lua:125` | `grug_zones.biome_at` and R6 P7 surface mapping only. |

Map, mounts, housing and travel are named in the R7 delivery wording
(`docs/research/wp40-simple-map-rebase-plan.md:983`), but their production mods
do not yet exist. Their R7 obligation is a stable public API, not invented
consumer code. The later packages remain ordered behind WP40 in `BACKLOG.md:220`
and `:225`.

## 6. Atomic activation contract

Recommended production order inside one reviewed R7 commit:

1. Load all pure R4-R6 modules and accepted artifacts without publishing or
   registering a writer.
2. Read the canonical full world seed and every effective mapgen setting; build
   and validate the exact R5 manifest (`mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua:8`).
3. Build the live content/CID/param2/template/WP43 projection. Validate the six
   accepted WP33 cultural digests and the complete non-cultural gathering
   extension from section 7.
4. Construct the final immutable session, protection policy and compatibility
   adapters. Any failure aborts mod load before an engine callback exists.
5. Publish exactly one `grug_zones` registry and the bounded immutable payload
   needed by the mapgen environment. The mapgen script independently validates
   the payload/digest before constructing the same session.
6. Register exactly one WP40 mapgen script. That script registers exactly one
   mapgen-environment `register_on_generated` callback and runs R5+R6+WP33 in one
   owner-slice transaction.
7. Load no legacy surface/writer module. There is no runtime setting, fallback,
   error handler or world age path that can activate the old pipeline.

“Exactly one writer” therefore means one main-environment
`register_mapgen_script` loader paired with one callback inside that separate
mapgen Lua state. A main-environment geography `register_on_generated` count of
one would be a defect, not a second acceptable interpretation.

The writer must preserve the accepted operation order: native/foreign veto,
P2 hard foundations, P3 interfaces, P4 paths, P5 terrain, P6 water, P7 surface,
P8 resources and P9 content (`docs/research/wp40-engineering-brief.md:221`). It
may add the bounded P9G gathering tail in section 7, but may not introduce a
second VM fetch/write, lighting pass or liquid update.

## 7. WP33 gathering integration gap and bounded extension

### 7.1 Verified gap

The cross-package gap is real:

- **Currently verified:** the closed R6 projection has exactly 48 ordinary
  decorations and explicitly excludes herbs, spices, crops and found-only foods
  (`docs/design/biomes_mobs.md:723`, `:760`).
- **Currently verified:** the binding design nevertheless requires three healing
  herbs, three spices and cooking/found-only sources
  (`docs/design/biomes_mobs.md:766`, `:779`, `:785`). WP33 owns their registration
  and gathering behavior (`BACKLOG.md:56`).
- **Currently verified:** R6 has only the six-key cultural registration API
  (`mods/MAPGEN/grug_mapgen/wp40/r6.lua:24`, `:209`). There is no external
  non-cultural gathering catalog or generic placement API elsewhere in
  production code. Existing R6 apple trees/blueberry bushes may be reused as
  sources, but they do not close the other source roster.

Therefore “six accepted cultural digests” is necessary but not sufficient for
R7 activation. Activating with only those six would omit decided WP33 surface
content, while using `core.register_decoration` later would create a second,
engine-random placement authority.

The parallel WP33 preflight and this R7 audit now agree on the following closed
population. This agreement remains preparatory until the reviewed WP33/R7
contracts freeze the records and digests:

- `reuse_r6_source`: the R6 apple-tree source (`default:apple`), blueberry-bush
  source (`default:blueberries`) and the six already placed signature woods;
- `r6_cultural_slot`: six separate `grug_gathering:<key>_source` definitions,
  one for each accepted R6 cultural reservation key; and
- `new_p9g_source`: exactly twelve new one-cell sources — the six healing-herb/
  spice nodes plus potato, corn, melon, mushroom, wild cocoa and rock salt.

No row in that population requires displacing an accepted R6 decoration.

### 7.2 Recommended bounded R7 extension

WP33 should publish one reviewed, immutable manifest that classifies every
non-cultural source as either:

- `reuse_r6_source`: an already-settled R6 node/template whose harvest behavior
  WP33 attaches without new geography; or
- `new_p9g_source`: a closed simple/template definition with exact node cells,
  param2, host/support policy, biome/zone allowlist, rational density, tier,
  access class and canonical digest.

The six `r6_cultural_slot` rows remain a third, disjoint class governed by the
existing R6 validator and reservation order; they are not counted among the
twelve P9G rows. WP33's runtime harvest authorization seam must also fail closed
until its owning WP10 profession service is available; that behavior seam does
not authorize a placement callback or change the immutable mapgen manifest.

R7 then extends the R6 settlement internally with **P9G after the accepted R6
P9 decorations**. A P9G root accepts only exact remaining P7 support/clearance,
rejects any R6 cultural/resource/decoration or engineering occupancy, never
moves/retries, and writes through the existing shadow buffer before its single
commit. This ordering is the simplest safe choice: it keeps every accepted R6
resource/cultural/decoration result byte-stable and makes the new gathering
surface a measured delta. If the WP33 contract instead requires gathering to
displace an R6 decoration, that is a semantic R6 change and must return to a
reviewed contract/evidence revision rather than being hidden in cutover code.

No WP33 source may call `core.register_decoration`, register a callback, use an
LBM to heal generation, or perform `set_node`/VoxelManip placement outside the
one WP40 transaction.

### 7.3 Required delta evidence

Before activation the bounded extension requires:

1. exact manifest population, ID and digest closure; all referenced nodes and
   template cells validate against the live content contract;
2. an explicit reuse/new-placement classification covering every WP33 source,
   with no source silently omitted because R6 already contains related scenery;
3. deterministic same-seed, shard-order, mapchunk-order and repeated-run bytes;
4. proof that all pre-existing R6 canonical rows/digests are unchanged, plus a
   separately versioned P9G ledger and digest;
5. actual accepted/rejected counts by source, biome, zone, tier and rejection
   reason over the accepted 32 seeds; nonzero access on both factions for every
   required tier and top-tier cooking source;
6. the design's paired-faction opportunity gate for healing herbs, spices and
   alchemy reagents (`docs/design/world_zones.md:917`), using exact integer
   cross-products rather than floating tolerance;
7. access-behavior KATs: Alchemist-only healing herbs, universally gathered
   spices/foods, and found-only sources not entering the future crop allowlist
   (`docs/design/biomes_mobs.md:663`);
8. one-transaction metrics proving no extra VM read/write, light calculation,
   liquid update, callback, native decoration or runtime healer; and
9. the normal R7 final-byte LuaJIT development gates followed by exactly one
   PUC-5.1/LuaJIT micro-KAT parity pair, not a PUC seed fleet
   (`docs/research/wp40-simple-map-rebase-plan.md:998`).

## 8. R7 versus R8 verification boundary

| R7 must close before merge | R8 remains the release/runtime gate |
|---|---|
| Accepted WP33 manifests/digests and the P9G delta; exact live content and mapgen manifest validation; one public `grug_zones`; complete query/anchor/protection migration; no legacy writer/registration path; deterministic offline and mocked-engine KATs; static/Lua 5.1 gates; independent review; final micro-KAT parity | Fresh real-engine v7 world generation; native cave/ore/dungeon/stratum preservation; owner-slice and mapchunk-order behavior under the engine; liquids/lighting; performance/RSS/transaction counts; representative seed biome/content/resource checks; capacity/supply inspection; visual in-game map; fallback-engine user runtime gate |

R7 may use the accepted R2 fixed-layout and R6 32-seed artifacts rather than
rerunning superseded exhaustive topology work. It must not relabel them as
real-engine evidence. A changed R5/R6 semantic byte returns to the owning
contract/evidence stage; a pure P9G extension gets the delta evidence above.
R8 is the first stage that may claim the map was actually generated and seen in
Luanti (`docs/research/wp40-simple-map-rebase-plan.md:988`).

## 9. Mechanical cutover gates

The R7 completion record should preserve the exact command output and expected
counts. At minimum:

```sh
# Legacy helpers: zero productive consumers outside the named adapter module.
rg -n --glob '*.lua' \
  'grug_core\.(surface_level_at|territory_at|zone_at|mob_level_at|guard_level_at|difficulty_at|open_sea_at)\b' \
  mods/ENTITIES mods/ITEMS mods/MAPGEN mods/PLAYER

# Old writers/loaders/healers: all zero.
rg -n 'ocean_mask_mapgen\.lua|grug_mapgen:continent|grug_mapgen:ocean_mask_heal' \
  mods/MAPGEN/grug_mapgen --glob '*.lua'
rg -n 'dofile\(path \.\. "/(ocean_mask|structures)\.lua"\)' \
  mods/MAPGEN/grug_mapgen/init.lua

# Old global height authority: zero.
rg -n --glob '*.lua' \
  'core\.get_spawn_level\s*\(|get_mapgen_object\s*\(\s*"heightmap"' \
  mods/CORE/grug_core mods/MAPGEN/grug_mapgen

# Exactly one production loader and exactly one mapgen-environment callback.
rg -n 'core\.register_mapgen_script\s*\(' mods/MAPGEN/grug_mapgen --glob '*.lua'
rg -n 'core\.register_on_generated\s*\(' mods/MAPGEN/grug_mapgen --glob '*.lua'

# Zero engine-random WP40/WP33 content placement; only explicit native allowlist ores.
rg -n 'core\.register_(biome|ore|decoration)\s*\(' \
  mods/MAPGEN/grug_mapgen --glob '*.lua'
rg -n 'core\.(bulk_set_node|set_node)\s*\(|[[:alnum:]_]+:write_to_map\s*\(' \
  mods/MAPGEN/grug_mapgen --glob '*.lua'

# Old coordinate providers/protection geometry: zero outside named adapters.
rg -n --glob '*.lua' \
  'grug_core\.(capitals|get_spawn_pos|outpost_anchors|bandit_camp_anchors)\b' \
  mods/ENTITIES mods/ITEMS mods/MAPGEN mods/PLAYER
```

The raw registration search is not itself a pass: every nonzero line must match
the R7 contract's explicit native-substrate allowlist. The callback search must
distinguish the one mapgen script callback from prohibited main-environment
callbacks. Add source-level assertions that WP33 contains zero writer/
decoration APIs and that all required accepted digests are embedded in or
derived from the reviewed immutable manifests.

## 10. Coordinator handoff

R7 implementation can begin after the WP33 lane supplies its accepted exact
manifest and resolves whether each gathering source is reused or new P9G
placement. Before code, freeze two short R7 decisions:

1. the exact minimal native biome/blob/stratum registration allowlist; and
2. the post-decoration P9G ordering and delta-evidence contract proposed here.

With those decisions accepted, the remaining work is implementation and
verification rather than game design. Without them, activating R7 would either
omit decided gathering content or force an implementer to invent a second
placement pipeline.
