# WP40 R7 Implementation Contract

Status: **ratified and implementation-ready; production writer still disabled**

Decision date: 2026-08-31 (Europe/Berlin)  
Reviewed technical source: `acf16c156416ad47df70c8ff3278211fcbd3978c`

This document is the coordinator's execution contract for R7. The complete
field-level rules remain in:

- `wp33-gathering-contract-candidate.md`, whose recommended D1--D6 decisions
  the user ratified on 2026-08-31;
- `wp40-r7-native-contract-candidate.md`, the native/input/cutover contract;
- `wp40-r7-cutover-preflight.md`, the writer and consumer inventory; and
- `wp33-r7-contract-candidate-review.md`, the clean independent review record.

The authoritative player-visible rules are folded into
`docs/design/biomes_mobs.md` Section 2.2,
`docs/design/world_zones.md` Sections 11 and 13.1, and
`docs/design/items_crafting.md` Section 4.1. `BACKLOG.md` owns the WP28, WP29,
WP33 and WP40 delivery boundaries. If this summary and a detailed contract
differ, implementation stops for contract correction; it does not choose a
convenient interpretation.

## 1. R7 outcome

R7 makes the accepted R0--R6 world pipeline production-active in one reviewed
cutover and adds WP33 gathering through the same transaction. The resulting
system has:

- one mapgen-environment callback and one VoxelManip transaction;
- R6 P2--P9 followed by the reject-only P9G successor in the same private
  buffers, run derivation, replay and commit;
- zero Lua biomes, exactly one retained native gravel blob, five retained
  strata and zero engine decorations;
- one stable public `grug_zones` authority and one fail-closed protection
  policy; and
- no legacy ocean, healer, structure, capital-repair, biome, ore or decoration
  writer path.

R7 acceptance is offline and mocked-engine evidence. It does not claim a real
Luanti world, a visual pass or production performance; those are R8 gates.

## 2. Frozen identities

The implementation must keep these identities separate and authenticated:

1. the accepted R6 evidence table with exactly 77 ASCII-ordered content rows
   and six synthetic Cultural targets at `grug_nodes:bone_pile`;
2. `grug_wp40_r7_production_r6_content_v1`, exactly those 77 names plus the six
   real Cultural source nodes, for 83 ASCII-ordered rows using the normal R6
   capability-16 resolver;
3. `grug_wp40_r7_p9g_content_v1`, exactly twelve ASCII-ordered P9G target rows
   with local refs 1..12, capability 8 and successor run refs 84..95; and
4. `grug_wp33_gathering_catalog_v1`, exactly 12 `new_p9g_source`, 8
   `reuse_r6_source` and 6 `r6_cultural_slot` records.

Stage A removes the complete P9G delta from private buffers and proves equality
with a direct authenticated 83-row production-R6 run. Stage B maps the 83-row
run by node name to the accepted 77-row evidence namespace, permits the six
real-to-synthetic substitutions only on matching Cultural operations, then
rederives refs, CIDs, aux values, runs, checksums and evidence. Any other
difference reopens R6 and stops R7.

## 3. Ratified WP33 content

Every accepted P9G source is one low, hand-gathered cell, preserves P7 and
drops exactly one raw item. The exact opportunity densities are:

| Denominator | Sources |
|---:|---|
| 256 | Potato, Corn |
| 384 | Sunleaf, Mushroom |
| 512 | Gravemoss, Marshbloom, Melon |
| 768 | Dragonweed |
| 1024 | Crimson Lotus, Stormkelp, Wild Cocoa, Rock Salt |

The exact zone and host sets are the closed tables in `world_zones.md` Section
11. In particular, Marshbloom uses Ossuary Reach instead of Mournfen for the
paired level-21--30 roster; Stormkelp uses cardinal dry-shore adjacency without
requiring `grug_beach`; Rock Salt additionally requires beach/sand.

The six Cultural sources retain one item per node. Ordinary density is 1/4096
and concentrated density 1/1024. Concentrated tool families are Gravesalt and
Runeslate `pick`, Moonresin/Spirit Resin/Sunwax `axe`, and Red Ochre `shovel`,
all at tier 4 or higher. `grug_materials.tool_tier_for_stack` is the sole
family/tier resolver. Missing WP29 axe/shovel/pick tier authority fails harvest
closed and does not block deterministic placement.

WP33 owns one single-registration healing-herb authorizer. Before WP10, herbs
are visible scenery and cannot be removed. Later only `grug_jobs` supplies
profession/book authorization. WP33 never duplicates profession state.

## 4. Implementation sequence

Intermediate commits may keep new code disabled, but no intermediate shipped
state may enable two writers or partially remove the old authority.

### R7-A -- WP33 registration and behavior

- Add the `grug_gathering` owner mod and its eighteen new nodes: six Cultural
  targets followed by twelve P9G targets after all existing target-owner mods.
- Add the immutable 26-row manifest, twelve P9G records, eight reuse audits and
  six exact R6 Cultural registration records/digests.
- Implement one-item harvest, exact source groups, the fail-closed herb
  authorizer and the `grug_materials` tool-family resolver seam.
- Register no decoration, mapgen callback, LBM, `set_node` or VoxelManip writer.

### R7-B -- native inputs and successor settlement

- Add the one native-input module with the exact six retained NoiseParams and
  the closed six-record native ore allowlist from the native contract.
- Validate identical effective NoiseParams in main and emerge environments
  before publication or callback registration.
- Build/authenticate the 83-row production-R6 resolver and the separate
  twelve-row P9G resolver; add P9G-only opcode, class, policy, ledger and
  metrics branches without changing any existing R6 opcode semantics.
- Execute P9G after R6 P9 and before shared run derivation/replay/commit.

### R7-C -- atomic loader and consumer cutover

- Remove the ocean-mapgen IPC/callback, ocean-healing LBM, structures
  `register_on_generated` writer and capital repair/persistence state machine.
- Stop loading the legacy biome/ore/decoration registrations and load only the
  closed native-input module.
- Enable exactly one production mapgen script/callback after every manifest,
  content, node, CID, param2, template and NoiseParams check passes.
- Publish one immutable `grug_zones` session and redirect terrain height,
  difficulty, open-sea, spawn, protection, mob, Kraken, rare, gathering, map,
  mount, housing and travel consumers to its stable queries and anchors.
- Preserve `grug_core.surface_level_at(x,z)` as terrain-height compatibility;
  no compatibility helper may recompute old geometry or consult old platform
  state.

### R7-D -- evidence and promotion

- Prove closed manifest populations/digests, exact native registration counts,
  one loader/callback/writer/transaction and zero legacy paths.
- Exercise every P9G source and rejection reason, both R6 projections,
  ownership/support boundaries, protection/query adapters, replay and
  fail-closed initialization.
- Run the changed R7 resource/content delta over the frozen 32-seed corpus;
  preserve accepted R6 decisions under Stage B and record separate P9G supply,
  collision, parity and access ledgers.
- Promote canonical artifacts, run receipts, logs and hashes to
  `docs/research/`; no acceptance evidence may remain only under `/tmp`.

## 5. Verification schedule

LuaJIT owns development, mocked-engine integration, fixed-layout checks and the
32-seed delta fleet. PUC 5.1 owns syntax/static checks and, only after all
relevant Lua bytes freeze, one compact runtime micro-KAT also run once under
LuaJIT with byte-identical canonical output. A relevant byte change replaces
that pair. There is no intermediate PUC runtime suite or PUC fleet.

Independent workers use immutable inputs, separate scratch/output paths,
idle scheduling and at most seven simultaneous Lua processes workstation-wide.
A deterministic finalizer orders and checks every result.

Before any long 32-seed fleet, run one representative LuaJIT pilot, record its
input/roster hashes, elapsed time, peak RSS, output/scratch bytes and projected
fleet cost, then stop unconditionally. The fleet starts only after the user
approves that exact measured SHA-256 projection. An earlier R6 fleet approval
does not silently approve a changed R7 projection.

## 6. Review and stop conditions

The final R7 diff and immutable evidence require a full independent strong-agent
review under `docs/process/wp-workflow.md`; any Critical or High fix receives a
focused re-review. During this session GPT-5.6 Sol is the reviewer, following
the user's instruction not to spend further Opus credits.

Stop and escalate instead of guessing if implementation would:

- change an accepted R0--R6 geometry, height, biome, surface, resource or
  settlement decision outside the two explicit projections;
- change a ratified D1--D6 density, zone/host roster, yield, tool family,
  resolver owner or one-cell placement;
- require a second writer/transaction, native decoration, Lua biome, repair
  LBM, retry/refill or live-VM halo authority;
- leave any required target node, manifest, NoiseParams or content identity
  unauthenticated; or
- require an intermediate/exhaustive PUC runtime or more than seven concurrent
  Lua processes without a new concrete compatibility finding and user ruling.

## 7. R8 handoff

After R7 is independently accepted, R8 generates the first real fresh v7
world that the user can inspect in Luanti. It validates native caves, dungeons,
strata, liquids, lighting, mapchunk order, one-writer behavior, representative
content/access, visual quality, generation time and RSS, followed by the
separate user-run fallback-engine/runtime checklist. R7 itself does not make a
visual or runtime acceptance claim.
