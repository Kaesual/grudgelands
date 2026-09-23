# Documentation cleanup — world lane

2026-09-23. Baseline `d6937b31`; implementation branch `docs20-world`.
Documentation only: no game code, settings, media, references, tests or evidence
artifacts changed. Author: native Astra. Independent review: pending coordinator
handoff; findings/fix rounds and elapsed wall time: pending / unknown.

## Scope inspected

- `world.md`: map introduction and identities, terrain/anchor authority,
  historical capitals, water/Kraken contract, nature and settlement roster.
- `world_zones.md`: introduction, current difficulty/geography headings,
  resource sampling/parity §11, consumer adapters §13, acceptance §14,
  PvP visitor rules §15 and Round 10/14 additions. No broad raw WP40 evidence
  reread; the approved demand-driven sampler and all release gates are retained.
- `biomes_mobs.md`: framework, entire old §1, current surface/gathering rules,
  roster and Kraken notes, §4 table/calibration, future depth pulse, materials
  and later disposition contract.
- `settlements.md`: starts/preparation, NPCs, capitals/loading, regional POIs
  and innkeepers. Architectural composition is preserved.
- `mounts.md`: acquisition, movement, lifecycle, pursuit and geographic bans.
- `boats.md` and `world_preparation.md`: full documents.
- `housing.md`: ownership/geography, tiers/claim return and final capacity
  requirements; remaining detailed future service/transaction scope retained.
- `TODO-design-depth.md` and `TODO-design-nether.md`: full documents.
- Bounded authority cross-checks: BACKLOG WP13/17/24/34/37 and readiness;
  Round 16/17/18 plans, Round 19 execution and pursuit-followup records;
  `combat_stats.md`, `home_travel.md`, current world-zone/settlement decisions.
- Read-only code cross-checks: `grug_mobs/spawn_policy.lua` density and clocks,
  `aggro.lua` pursuit sampling, `kraken.lua`, `grug_mounts/state.lua` purchase,
  `grug_core/zone_authority.lua` adapters and `starts_preload.lua` readiness.
  Code corroborates adopted decisions; it is not promoted into design authority.

## Corrected findings

1. World, zone and biome introductions still described WP18/WP36 as running.
   Replaced with current named-zone authority and preserved future WP scope.
   Removed the incorrect sign-of-z territory description. Source: WP40 delivery
   and the already-current `world_zones.md` §13.3 adapter contract.
2. Retired biome cuboids, carve experiments, old capital placement and radial
   coverage measurements occupied living design. Extracted them to
   [world-historical.md](../archive/design/world-historical.md), with source
   snapshot/section provenance and explicit historical status. Section-number
   pointers remain in the living biome document, with current authorities and
   the still-approved elven/coastal direction retained.
3. Settlement preparation still promised two concurrent start requests and
   creation before completion, and said capitals were never preloaded. Replaced
   by the adopted R16/R18 shared preparation modes/readiness contract. All
   stop/resume, source-identity, surface-envelope and runtime acceptance
   requirements in `world_preparation.md` remain.
4. Settlement prose still owed kings, used placeholder quest shells and denied
   profession services anywhere in settlements. Folded in delivered kings,
   quest services and the separate capital trainer/station contract; retained
   trade-shop versus crafting-trainer separation and outstanding POI roster.
5. Mount purchase contradicted its own later Skills rule by promising automatic
   insertion. Now consistently grants entitlement/manual Skills recovery.
   Ordinary pursuit now includes R19's movement-after-expiry requirement;
   authored actor exceptions remain. Removed obsolete speed quotation/history.
6. Biome framework omitted the R16 kill-XP and R17 non-player damage multipliers
   and described every nature mob as aggressive. Added the canonical multiplier
   references and fixed-disposition distinction. The flora introduction no
   longer describes delivered farming/Cooking as wholly future work.
7. World/boats claimed the Kraken outran an improved 8-nodes/s boat, although
   `biomes_mobs.md` §3.1 records the later owner ruling retaining speed 5.
   Corrected that rationale and kept deadly-sea design/acceptance and the
   unimplemented position-dependent pursuit prerequisite explicit.
8. Depth TODO retained completed decision essays and misleading claims that the
   pulse had shipped. Preserved that history in the archive; the TODO now owns
   only placement geometry and the deep servant roster. WP34 mechanics remain
   future scope, including its dependencies. Nether TODO now explicitly lists
   its unresolved enemy-exit interception rule and uses the current item design
   document instead of stale unnamed items-TODO sections.
9. Housing intro separates future claim-bound Home Stone scope from the
   delivered innkeeper return/respawn system. No claim, price, capacity,
   persistence, protection or acceptance requirement was removed.

## Unresolved findings and coordinator handoff

- **WP37 versus Round 16:** the original all-surface ×0.75 chance decision
  (including surface critters, no cap increase) differs from the delivered
  fightable-only ×1.3 rate/rounded-cap rule. R16 explicitly replaces its earlier
  +50% proposal, not explicitly WP37. The old decision remains marked outstanding;
  the mixed historical/pre-R16 table is explicitly not current effective runtime
  parameters. Do not stack the multipliers or silently cancel distinct critter
  scope. Coordinator should record the overlap in BACKLOG; final reconciliation
  needs an actual scope decision. The table's remaining historical row notes are
  a further archive candidate once that contract is reconciled.
- **BACKLOG WP17 Kraken speed:** its 8.8 target is superseded by the explicit
  2026-09-17 speed-5 ruling already in the living mob catalog. Update that row;
  retain future `view_range = 40` and position-dependent pursuit prerequisites.
  Whether the revised speed achieves intended deadly deep-ocean boat travel is
  still a future implementation/acceptance question, not proven by this edit.
- **BACKLOG depth wording:** if summarizing the archived TODO, retain A2 placement
  and A2/D10 servant roster as open and WP34 as unfinished. No WP completion or
  ROADMAP checkbox change is justified by this documentation cleanup.
- **Further archive candidates:** remaining incremental capital-construction
  stories in `settlements.md`, and the mixed old/new §4 spawn rows. Avoid moving
  their decided geometry/numeric constraints into history without an explicit
  current equivalent. No existing whole file was moved in this lane.

## Verification

- `git diff --check`: PASS before commit.
- Markdown file-target scan across all ten owned design/TODO documents plus the
  new archive: no missing local link targets.
- Exact text comparison against baseline proves `world_zones.md` §11 (including
  demand-driven sampling, strict parity, old-evidence limitation) and §14
  (acceptance gates) unchanged.
- No Lua interpreter, native world, performance or GUI run performed. Existing
  evidence hashes and historic supply/access limitations remain unchanged.
- No game runtime test is needed for these prose changes. Existing user-run
  acceptance checklists and release/resource evidence gates remain outstanding
  wherever their delivery records say so.
