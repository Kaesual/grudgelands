# Independent Review: WP33 Gathering / WP40 R7 Cutover Preflights

Date: 2026-08-31 (Europe/Berlin)

Review base: `d6002a289aa079fba4fe1d943a00dc50f777f30a`

Reviewed commits: `37c72feaca9d8d30a58a3ab77b810e330a6ee64c`,
`6b0ddcf3b63de773c0350d23ce1c5f5980509fdf`

Classification: non-trivial documentation review (architecture, acceptance
boundary, migration gates and future player-visible behavior)

Verdict: **not clean — 0 Critical / 1 High / 2 Medium / 1 Low**

No production files were changed and no builds or tests were run. The review
read both candidate documents in full and checked the relevant accepted R4-R6
contracts, design documents, production consumers and engine-registration
sources at the stated base.

## High

### H1 — R7 neither closes nor validates the active legacy v7 noise-setting mutations

**Files:** `docs/research/wp40-r7-cutover-preflight.md:98-101,175-195,315-358`;
`mods/MAPGEN/grug_mapgen/init.lua:24-31,44-52,82-90`;
`mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua:8-28,30-50`

The preflight calls only the five post-foundation `dofile` modules the atomic
edit boundary and requires production to read "every effective mapgen setting",
but it never inventories or decides the three legacy `set_mapgen_setting_noiseparams`
families executed earlier in the same loader. The exact R5 manifest cannot
close that omission: its field list contains mapgen name, flags, water,
chunksize, limits and dungeon bounds, but no terrain or climate noise
parameters. The mechanical gates likewise contain no settings-mutation search.
This contradicts the accepted R7 requirement to prove that no uncovered
loader/callback/settings path survives (`docs/research/wp40-simple-map-rebase-plan.md:970-986`)
and the accepted inventory that explicitly identifies the legacy v7
terrain/climate overrides (`docs/research/wp40-engineering-brief.md:346-350`).

**Failure scenario:** an implementation follows the stated five-file boundary,
removes the old biomes/writers and passes every listed gate, while the old
WP18 terrain/climate overrides still mutate v7 before the new writer is
registered. Native v7 heightmap, caves and preserved substrate then depend on
unvalidated legacy settings; a configuration/default drift can change the
native input and final world while the R7 manifest still validates. R7 can no
longer claim an exact atomic native-input cutover or deterministic R8 baseline.

**Required correction:** inventory every `core.set_mapgen_setting*` and
`core.set_mapgen_params` production path. Freeze whether each legacy noise
override is removed or deliberately retained; any retained value must become
an exact live-manifest field/input and mapgen-environment validation input. Add
a zero-or-explicit-allowlist static gate for settings mutation and include this
loader prefix in the atomic edit boundary.

## Medium

### M1 — The claimed complete anchor/protection migration gate omits live capital consumers in `grug_core`

**Files:** `docs/research/wp40-r7-cutover-preflight.md:139-167,347-350`;
`mods/CORE/grug_core/protection.lua:121-130,174-183`

The hidden-consumer table mentions the capital literals and central protection
separately, but it does not enumerate the two productive protection functions
that directly iterate `grug_core.capitals` and call the old platform-height
state machine. More importantly, the purported old-coordinate/protection gate
searches only `mods/ENTITIES`, `mods/ITEMS`, `mods/MAPGEN` and `mods/PLAYER`, so
both live `mods/CORE/grug_core/protection.lua` consumers are outside its scope.
The pattern also does not search the old protection helpers or
`get_camp_platform_y`. Thus the gate can report zero while legacy capital
geometry remains authoritative in the central protection path.

**Failure scenario:** R7 publishes stable capital anchors and migrates spawn,
traders and mapgen, but leaves `in_capital_zone` or
`protected_zone_in_box` unchanged. If `grug_core.capitals` is deleted, every
relevant protection evaluation can error at `pairs(nil)`; if the legacy table
is retained for compatibility, capital protection continues to use stale x/z
and persisted/fallback platform y, protecting the wrong volume while the new
capital can be modified. The listed static gate still passes.

**Required correction:** add both protection functions to the consumer matrix
and make the static audit repository-wide (or explicitly include
`mods/CORE/grug_core`). Gate `grug_core.capitals`,
`get_camp_platform_y`, `in_capital_zone`, `protected_zone_in_box` and the old
platform constants/state outside the one reviewed adapter/policy module.

### M2 — The proposed universal T4-pick gate invents the tool family for cultural harvesting

**Files:** `docs/research/wp33-gathering-cultural-preflight.md:313-327`;
`docs/design/items_crafting.md:1185-1201`;
`mods/ITEMS/grug_materials/mining.lua:103-109`

The design fixes only that a concentrated cultural source requires "T4
harvesting" and explicitly says ordinary sources retain their natural
axe/shovel/hand behavior. It does not choose one tool family for all six very
different presentations. The preflight correctly identifies this as an open
tool-family decision, but then recommends `pick_tier_for_stack >= 4` merely
because that is the only tier accessor already shipped. Existing API
availability is not player-visible design authority, and the model policy
forbids an implementer from filling that semantic gap. The R7 preflight's
generic `tier`/`access class` manifest fields do not resolve the contradiction.

**Failure scenario:** a player brings a T4 axe to a concentrated waxcomb or
resin-root source and is denied, while a T4 mining pick harvests waxcomb,
resin and roots. That behavior follows neither the source presentations nor
the design's explicit natural axe/shovel/hand split; it becomes an accidental
rule chosen by the currently available API.

**Required correction:** keep the concentrated tool-family/tool-tier behavior
explicitly unresolved until the user freezes it, or define a reviewed
tool-family-neutral harvest-tier seam (with exact eligible families per source)
before the WP33 contract. Do not promote the pick-only recommendation into an
implementation contract without that design ruling.

## Low

### L1 — Two R7 registration/writer citations do not point to the operations claimed

**File:** `docs/research/wp40-r7-cutover-preflight.md:91-96,116-122`

The structures row cites `structures.lua:887` while claiming the cited set
covers liquid update, lighting and `write_to_map`; line 887 is only
`update_liquids`, while lighting and the write are at
`mods/MAPGEN/grug_mapgen/structures.lua:889-890`. The decoration row cites
`mods/MAPGEN/grug_mapgen/decorations.lua:83,104`; line 83 is an error-message
continuation and line 104 is only the `register_plant` helper declaration,
whereas the actual registration calls are at lines 101 and 120.

**Failure scenario:** a focused reviewer follows only the claimed locations
and does not see the final lighting/write or both registration calls, weakening
the source-backed removal audit even though the high-level inventory is
otherwise correct.

**Required correction:** cite `structures.lua:875,887,889-890` and
`decorations.lua:78-101,104-120` (or the exact registration-call lines).

## Verified clean boundaries

- The two preflights agree on a closed WP33 placement population: twelve new
  P9G one-cell sources, six R6 cultural-slot registrations, and reuse of the
  two existing food plus six signature-wood feature families. This matches
  `docs/design/biomes_mobs.md:658-707,760-801`; no accepted R6 decoration has
  to be displaced.
- The single Alchemist-authorizer ownership split is sound at preflight level:
  WP33 owns the dig decision, WP10 alone owns profession/book state, and a
  missing or malformed provider fails closed without inventing a player-meta
  key. The grade-to-book-group mapping follows
  `docs/design/items_crafting.md:319-330,845-854`.
- P9G is feasible as a **successor settlement**, not as an external pass. The
  present R6 API exposes setters only through final `apply_fixture`
  (`mods/MAPGEN/grug_mapgen/wp40/r6.lua:323-343`), while the private settlement
  holds `final_data`, `final_param2`, occupancy and intent buffers until run
  derivation and setters (`mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:1171-1243,1753-1765,2030-2094`).
  A post-P9, reject-only P9G insertion before canonical run derivation can
  therefore share the one VM transaction.
- The stated R6 evidence boundary is appropriately conditional: existing R6
  evidence remains predecessor evidence only if P9G cannot alter R6 candidate
  acceptance or existing intents, uses separate stable references/ledger
  identity, and projection removes the delta byte-exactly. The required
  32-seed LuaJIT delta ledger, mapchunk/order fixtures and final single
  PUC/LuaJIT micro-KAT pair are correctly assigned.

## Residual risks after the findings are fixed

- The exact native biome/blob/stratum allowlist remains intentionally open.
  In particular, retaining the current dirt-blob definition unchanged would
  retain legacy biome names (`mods/MAPGEN/grug_mapgen/ores.lua:77-114`) after
  those biomes are removed; the accepted R7 contract must prove the behavior
  and must not let an unresolved biome restriction become world-wide.
- P9G densities, exact ordinary-food/Dragonweed zone rows, and the Stormkelp
  shore predicate remain real design/contract decisions. They are correctly
  identified as blockers and must be frozen before implementation.
- R8 still owns real-engine cave/ore/dungeon/stratum preservation,
  owner-slice/mapchunk behavior, lighting/liquids, performance/RSS and visual
  inspection. No offline result should be relabeled as that runtime evidence.

## Focused re-review — 2026-08-31

Correction commits reviewed:
`f1376e40ced967d5786f64d6014a6b888eaf3717` (WP33) and
`84dabb78ff453bc4a8638468e8fb50b55584057a` (R7).

Focused verdict: **clean — 0 Critical / 0 High / 0 Medium / 0 Low**.

The focused review rechecked the correction diffs against H1, M1, M2 and L1,
then followed their claims back to the unchanged production and pinned-engine
sources. All four findings are resolved. No production files were changed and
no builds or tests were run.

### Resolution of H1 — complete six-mutation manifest boundary

**Resolved.** The R7 correction inventories exactly the six active production
mutations and their complete current tables
(`docs/research/wp40-r7-cutover-preflight.md:91-107`). Those rows match the two
terrain calls at `mods/MAPGEN/grug_mapgen/init.lua:24-31`, the two climate calls
at `:44-52` and the two blend calls at `:82-90`. A repository-wide source audit
found no additional `set_mapgen_setting*`, `set_mapgen_params` or
`set_noiseparams` call under `mods/`.

The corrected contract makes every retained normalized NoiseParams table,
including flags, and its digest part of the versioned R7 manifest. It requires
exact readback before publication in the main environment and independent
readback before session construction/callback registration in the mapgen
environment (`docs/research/wp40-r7-cutover-preflight.md:119-130,227-240`). This
is engine-feasible: `core.get_mapgen_setting_noiseparams` reads the active
`MapSettingsManager` value and returns the normalized table
(`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:909-923`), including
normalized flags and both persistence spellings
(`reference_projects/luanti/src/script/common/c_content.cpp:2054-2098`), and the
getter is registered in both environments
(`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:2060-2078,2104-2119`).
The zero-or-exact-allowlist settings gate is now explicit and repository-wide
(`docs/research/wp40-r7-cutover-preflight.md:377-381,412-421`). The original
failure scenario can no longer satisfy the corrected contract: an omitted,
defaulted or drifted noise input causes manifest validation to abort before the
writer is registered.

### Resolution of M1 — central protection and old-platform authority gated

**Resolved.** The consumer matrix now names both live protection paths, their
old capital/platform dependencies and the ocean healer caller
(`docs/research/wp40-r7-cutover-preflight.md:194`). The citations match
`mods/CORE/grug_core/protection.lua:121,127,174,180,213` and
`mods/MAPGEN/grug_mapgen/ocean_mask.lua:512`.

The replacement is one reviewed stable-anchor protection policy, and the
repository-wide gate covers the old capital/spawn/anchor providers, platform
height APIs and storage key, protection entry points, platform constants and
retry state (`docs/research/wp40-r7-cutover-preflight.md:404-419`). This is
complete for reachable legacy authority: retaining either old protection body
necessarily leaves gated references to `grug_core.capitals` and
`get_camp_platform_y`; retaining the discovery, persistence, retry or repair
flow necessarily leaves a gated public entry point, heightmap read, storage
key or state symbol. Local helper names such as `stored_platform_y` are not
individually enumerated, but they cannot preserve an active path after the
required expected-count audit reaches zero outside the one policy/adapter.
The earlier stale-volume/error scenario therefore cannot pass the corrected
gate.

### Resolution of M2 — cultural tool family remains honestly open

**Resolved.** WP33 now preserves ordinary source-specific hand/axe/shovel
behavior and explicitly forbids routing those sources through one tool family
(`docs/research/wp33-gathering-cultural-preflight.md:313-321`). It leaves the
concentrated-source family or families as an explicit user/design decision,
requires the exact family assignment before the contract freezes, and permits
a tier-neutral resolver only after that choice
(`docs/research/wp33-gathering-cultural-preflight.md:323-335`). It also states
that `grug_materials.pick_tier_for_stack` proves only the pick family, matching
`mods/ITEMS/grug_materials/mining.lua:103-109`. No universal-pick player
semantics remain in the recommendation.

### Resolution of L1 — source locations corrected

**Resolved.** The structures row now cites the callback, `set_data`, liquid,
lighting and final write locations at
`mods/MAPGEN/grug_mapgen/structures.lua:776,875,887,889-890`
(`docs/research/wp40-r7-cutover-preflight.md:140`). The decoration row now
covers both definition/helper blocks and their actual registration calls at
`mods/MAPGEN/grug_mapgen/decorations.lua:78-101,104-120`
(`docs/research/wp40-r7-cutover-preflight.md:168`). Both claims now lead a
reviewer to the operations that must be removed.

### Residual risks (not findings)

- The final native biome/blob/stratum allowlist, P9G densities/zone rows and
  concentrated cultural tool-family assignment remain deliberately open GO
  decisions. The corrected preflights identify them as blockers rather than
  choosing implementation defaults.
- The six-noise retention/removal disposition and canonical manifest encoding
  still have to be frozen in the reviewed R7 contract. The correction proves
  the complete population and a feasible validation path; it does not claim
  that the still-non-authoritative preflight has activated them.
- The mechanical searches remain review gates, not semantic parsers. R7 must
  preserve their exact outputs/counts and source-review any aliases or
  allowlisted adapters as the corrected text requires.
