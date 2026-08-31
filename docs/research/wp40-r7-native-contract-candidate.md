# WP40 R7 Native/Input/Cutover Contract Candidate

Status: **ratified technical contract input, not production-active**

Baseline: `dd1e192b8efa7afe865b5628b937a83a283433f6`

Pinned engine: Luanti `df04879066de6eb94ca43996822a6dfacc74feca`

This contract closes the technical R7 decisions delegated to this lane: the
native registration allowlist, the six retained v7 NoiseParams inputs, the
single-writer cutover, the P9G insertion boundary, protection/query migration,
and the offline/R8 evidence split. It does not implement R7 and it does not
replace the separately reviewed WP33 source manifest.

The user has already decided three governing rules:

1. retain all six current NoiseParams exactly and authenticate them in both the
   main and mapgen environments;
2. run P9G strictly after accepted R6 P9, reject-only and non-overwriting, in
   the same private-buffer/VM commit; and
3. keep the healing-herb authorizer fail-closed.

No player-facing or game-design choice is invented below. The user ratified
the WP33 decisions referenced by Section 9 on 2026-08-31.

## 1. Sources and engine facts

This candidate follows `AGENTS.md`, WP40/WP33 in `BACKLOG.md`,
`docs/process/wp-workflow.md`, `docs/process/agent-model-policy.md`, the
interpreter strategy in `docs/research/luanti-lua.md`, the current R7/WP33
preflights and independent review, R7 sections 4.1--4.4 of the engineering
brief, the R7 rebase plan, and the accepted R5/R6 contracts and manifests.
Production sources were audited at the baseline above; engine behavior was
checked against the pinned Luanti checkout.

The native decision depends on these engine facts:

- `BiomeManager` creates built-in biome ID 0, `default`, before any Lua biome
  registration (`src/mapgen/mg_biome.cpp:18-43`). With no custom biome,
  `BiomeGenOriginal::calcBiomeFromNoise` returns that record
  (`mg_biome.cpp:231-278`). Its substrate resolves through the normal
  `mapgen_stone`, water and river-water aliases (`mg_biome.cpp:318-331`), which
  the game supplies in `mods/BASE/default/mapgen.lua:7-37`. Consequently R7
  needs **no Lua biome registration** to retain native v7 stone/water substrate.
- The default biome's absent cave-liquid nodes are `ignore`. Cavegen then uses
  its existing water/lava fallback (`src/mapgen/cavegen.cpp:323-339,522-535`).
  Its absent dungeon node similarly falls back to `mapgen_cobble`
  (`src/mapgen/mapgen.cpp:925-949`). A synthetic Lua biome would add no required
  preservation behavior and would reintroduce a logical-biome competitor.
- An unresolved ore `biomes` entry is discarded while parsing the list; if all
  names are unresolved, the stored set is empty
  (`src/script/lua_api/l_mapgen.cpp:412-457`). Ore generation applies a biome
  restriction only when that set is nonempty (`src/mapgen/mg_ore.cpp:154-159`).
  Therefore retaining the old dirt blob after removing its eleven named legacy
  biomes would make it **world-wide**, not disabled. This is a mandatory removal
  gate, not merely a cleanup preference.
- Native v7 order is terrain, heightmap, biomes, caves, ores, dungeons,
  decorations, dust, liquids and light (`src/mapgen/mapgen_v7.cpp:320-379`).
  The retained strata therefore still run after caves and the R7 Lua writer
  still receives the native ore/dungeon substrate before its one transaction.
- `core.get_mapgen_setting_noiseparams` reads the effective
  `MapSettingsManager` value (`src/script/lua_api/l_mapgen.cpp:909-923`) and is
  registered in both main and emerge environments (`l_mapgen.cpp:2060-2129`).
  `push_noiseparams` returns both `persist` and `persistence`, the normalized
  flags string, and the spread table (`src/script/common/c_content.cpp:2082-2099`).

## 2. Closed native registration allowlist

R7 replaces the legacy `biomes.lua`, `ores.lua` and `decorations.lua` loading
with one small native-substrate module. That module contains exactly **zero Lua
biomes, six ores and zero engine decorations**. The six ores are one gravel
blob followed by five strata in the order below. No active loader may execute
another `core.register_biome`, `core.register_ore` or
`core.register_decoration` path for geography/content generation. The dormant
`default.register_biomes`, `default.register_ores` and
`default.register_decorations` function bodies may remain vendored, but nothing
may call them; their invocation count is zero.

### 2.1 Exact retained records

The implementation tables are exact. A field shown as absent must remain
absent; normalized defaults shown only in the canonical manifest are validation
facts, not permission to add unrelated definition fields.

| Order | Name | Exact registration definition |
|---:|---|---|
| 1 | `grug_mapgen:native_gravel_blob_v1` | `ore_type="blob"`; `ore="default:gravel"`; `wherein={"default:stone"}`; `clust_scarcity=4096`; `clust_size=5`; `y_min=-31000`; `y_max=31000`; `noise_threshold=0.0`; `noise_params={offset=0.5,scale=0.2,spread={x=5,y=5,z=5},seed=766,octaves=1,persist=0.0}`. `biomes` is absent. |
| 2 | `grug_mapgen:native_stratum_iron_v1` | `ore_type="stratum"`; `ore="grug_materials:slate"`; `wherein="default:stone"`; `clust_scarcity=1`; `y_min=-300`; `y_max=-101`. Both noise tables are absent. |
| 3 | `grug_mapgen:native_stratum_steel_v1` | Same fields as order 2; `ore="grug_materials:basalt"`; `y_min=-500`; `y_max=-301`. |
| 4 | `grug_mapgen:native_stratum_silversteel_v1` | Same fields as order 2; `ore="grug_materials:granite"`; `y_min=-700`; `y_max=-501`. |
| 5 | `grug_mapgen:native_stratum_embersteel_v1` | Same fields as order 2; `ore="grug_materials:emberrock"`; `y_min=-1000`; `y_max=-701`. |
| 6 | `grug_mapgen:native_stratum_abyssal_steel_v1` | Same fields as order 2; `ore="grug_materials:abyssal_rock"`; `y_min=-31000`; `y_max=-1001`. |

The names are new audit identities; the generation fields preserve the one
accepted gravel blob and the current T2--T6 strata. T1 remains
`default:stone` and has no redundant registration. Strata remain last so they
replace only `default:stone` left after native caves and earlier ores.

Gravel is retained as the one accepted non-surface blob this lane chooses to
preserve; R7 P7 is the sole surface authority and R6 P8 is the sole resource
authority. Clay depends on the removed legacy sand-surface authority, silver
sand is compatible with stone but remains inherited non-required variation,
and dirt would trigger the world-wide unresolved-biome trap. No authoritative
design row requires clay or silver sand. Ratifying this allowlist also accepts
that the vendored clay-lump/brick and silver-sandstone recipe families have no
in-world source; the ratified backlog fold assigns their removal or replacement
to WP28 rather than leaving the consequence in research prose or expanding
WP26 beyond Universalbars.

The normalized allowlist canonical bytes are ASCII, have no BOM or CR, use the
rows and field order below, and end every row including the last with LF:

```text
grug_wp40_r7_native_allowlist_v1
blob|grug_mapgen:native_gravel_blob_v1|ore=default:gravel|wherein=default:stone|clust_scarcity=4096|clust_num_ores=1|clust_size=5|y_min=-31000|y_max=31000|noise_threshold=0|noise=0.5,0.2,5,5,5,766,1,0,2,defaults
stratum|grug_mapgen:native_stratum_iron_v1|ore=grug_materials:slate|wherein=default:stone|clust_scarcity=1|y_min=-300|y_max=-101
stratum|grug_mapgen:native_stratum_steel_v1|ore=grug_materials:basalt|wherein=default:stone|clust_scarcity=1|y_min=-500|y_max=-301
stratum|grug_mapgen:native_stratum_silversteel_v1|ore=grug_materials:granite|wherein=default:stone|clust_scarcity=1|y_min=-700|y_max=-501
stratum|grug_mapgen:native_stratum_embersteel_v1|ore=grug_materials:emberrock|wherein=default:stone|clust_scarcity=1|y_min=-1000|y_max=-701
stratum|grug_mapgen:native_stratum_abyssal_steel_v1|ore=grug_materials:abyssal_rock|wherein=default:stone|clust_scarcity=1|y_min=-31000|y_max=-1001
```

SHA-256: `d1fe4ac1c7cbe5525af65bde48cc4309870c01e4d474785f2cf0cda3d2639480`.
The blob's canonical row includes engine-normalized defaults
`clust_num_ores=1`, lacunarity `2` and flags `defaults`; the implementation
validator must derive them rather than trusting a second handwritten copy.

### 2.2 Complete disposition of current registrations

Every current registration has one disposition:

- Remove all 20 Lua biomes: `grug_savanna`, `grug_meadows`,
  `grug_badlands`, `grug_deep_forest`, `grug_deep_forest_front`,
  `grug_badlands_east`, `grug_deep_forest_east`, `grug_blight`,
  `grug_pine_hills`, `grug_bone_forest`, `grug_crags`,
  `grug_crags_snowy`, `grug_jungle_edge`, `grug_elf_forest`,
  `grug_deep_jungle`, `grug_jungle_fringe`, `grug_swamp`, `grug_beach`,
  `grug_ocean` and `grug_underground`. Replace them with zero Lua biome
  definitions; built-in biome ID 0 is the native substrate fallback, while
  `grug_zones.biome_at` plus P7 own logical/surface identity.
- Remove clay, silver-sand and dirt blobs. Replace only the old gravel row with
  exact allowlist order 1. The dirt row's eleven former biome names must not
  appear in any retained ore definition.
- Remove all 22 generated scatter registrations: coal (3), tin (3), copper
  (3), iron (4), gold (3), emberglass (2), diamond (1), quartz (1), silver
  (1) and garnet (1). R6 P8 replaces all of them.
- Replace the T2--T6 loop with exact named allowlist orders 2--6. This is a
  behavior-preserving explicit form, not a new placement family.
- Remove all 47 engine decorations. Their exact registered IDs are:
  `grug_mapgen:meadows_apple_tree`, `grug_mapgen:meadows_bush`,
  `grug_mapgen:meadows_grass_1` through `_5`;
  `grug_mapgen:pine_hills_pine_tree`,
  `grug_mapgen:pine_hills_small_pine_tree`,
  `grug_mapgen:pine_hills_pine_bush`,
  `grug_mapgen:pine_hills_blueberry_bush`, and
  `grug_mapgen:pine_hills_fern_1` through `_3`;
  `grug_mapgen:elf_forest_silverwood`,
  `grug_mapgen:elf_forest_apple_tree`, and
  `grug_mapgen:elf_forest_grass_1` through `_3`;
  `grug_mapgen:deep_forest_apple_tree`,
  `grug_mapgen:deep_forest_aspen_tree`,
  `grug_mapgen:deep_forest_apple_log`, and
  `grug_mapgen:deep_forest_fern_1` through `_3`;
  `grug_mapgen:crags_snowy_pine_tree`;
  `grug_mapgen:savanna_acacia_tree`,
  `grug_mapgen:savanna_acacia_bush`, and
  `grug_mapgen:savanna_dry_grass_1` through `_5`;
  `grug_mapgen:badlands_large_cactus`,
  `grug_mapgen:badlands_dry_shrub`;
  `grug_mapgen:blight_gravewood`, `grug_mapgen:blight_dry_shrub`,
  `grug_mapgen:blight_bone_pile`;
  `grug_mapgen:bone_forest_gravewood`,
  `grug_mapgen:bone_forest_bone_pile`;
  `grug_mapgen:jungle_edge_jungle_tree`,
  `grug_mapgen:jungle_edge_junglegrass`;
  `grug_mapgen:jungle_tree`, `grug_mapgen:emergent_jungle_tree`,
  `grug_mapgen:jungle_junglegrass`;
  `grug_mapgen:swamp_papyrus`, and
  `grug_mapgen:swamp_dry_shrub`. R6 P9 replaces this population with its
  closed 48-ID deterministic catalog; accepted WP33 P9G adds its separate
  twelve-row gathering delta.

`mg_flags` remains the accepted R5 value
`biomes,caves,decorations,dungeons,light,ores`. Empty Lua biome/decoration
registries do not authorize an alternate surface/content source: the flags
retain native engine phases and the built-in biome, while the explicit raw
registration gate above closes the Lua population.

## 3. Six retained NoiseParams: exact encoding and authentication

### 3.1 Expected effective values

The only allowed mapgen-setting mutations under `mods/` are six
`core.set_mapgen_setting_noiseparams(name, table, true)` calls in one R7 native
input module, in this order:

| Order | Setting | offset | scale | spread x/y/z | seed | octaves | persist | lacunarity | flags |
|---:|---|---:|---:|---|---:|---:|---:|---:|---|
| 1 | `mgv7_np_terrain_base` | 14 | 70 | 600/600/600 | 82341 | 5 | 0.6 | 2.0 | omitted in setter; normalized `defaults` |
| 2 | `mgv7_np_terrain_alt` | 10 | 25 | 600/600/600 | 5934 | 5 | 0.6 | 2.0 | omitted in setter; normalized `defaults` |
| 3 | `mg_biome_np_heat` | 50 | 35 | 1000/1000/1000 | 5349 | 3 | 0.5 | 2.0 | `eased` |
| 4 | `mg_biome_np_humidity` | 50 | 35 | 1000/1000/1000 | 842 | 3 | 0.5 | 2.0 | `eased` |
| 5 | `mg_biome_np_heat_blend` | 0 | 4 | 32/32/32 | 13 | 2 | 1.0 | 2.0 | `eased` |
| 6 | `mg_biome_np_humidity_blend` | 0 | 4 | 32/32/32 | 90003 | 2 | 1.0 | 2.0 | `eased` |

The climate quartet remains authenticated native input even though it no
longer chooses a Grudgelands logical biome. R7 deliberately does not combine
writer cutover with a second native-terrain experiment.

### 3.2 Strict normalized table validator

For each setting, call `core.get_mapgen_setting_noiseparams` in the table order
above. Nil, an engine error or any mismatch is fatal. An accepted readback is a
plain table with exactly these nine keys:

`offset`, `scale`, `persist`, `persistence`, `lacunarity`, `seed`, `octaves`,
`flags`, `spread`.

`spread` is a plain table with exactly `x`, `y`, `z`. All numeric fields are
finite numbers; `seed` and `octaves` are safe integers. `persist` and
`persistence` must both exist and have identical numeric values. Luanti stores
NoiseParams members as binary32 floats before pushing them as Lua numbers, so
numeric comparison is against the exact binary32 rounding of each contract
decimal. In particular, the two lexical `0.6` setter/canonical values must
read back as the exactly representable Lua double
`0.60000002384185791015625`; direct comparison with the Lua literal `0.6` is
forbidden. The other listed numbers are exactly representable in binary32.
No metatable, unknown key, numeric array entry, string coercion or default
substitution is accepted. `flags` is exactly `defaults` or `eased` as listed;
no equivalent alias/order is accepted. Validation compares these normalized
numeric values, then emits only the fixed lexical forms in the canonical
encoding.

The exact canonical bytes are:

```text
grug_wp40_r7_noiseparams_v1
mgv7_np_terrain_base|offset=14|scale=70|spread=600,600,600|seed=82341|octaves=5|persist=0.6|lacunarity=2|flags=defaults
mgv7_np_terrain_alt|offset=10|scale=25|spread=600,600,600|seed=5934|octaves=5|persist=0.6|lacunarity=2|flags=defaults
mg_biome_np_heat|offset=50|scale=35|spread=1000,1000,1000|seed=5349|octaves=3|persist=0.5|lacunarity=2|flags=eased
mg_biome_np_humidity|offset=50|scale=35|spread=1000,1000,1000|seed=842|octaves=3|persist=0.5|lacunarity=2|flags=eased
mg_biome_np_heat_blend|offset=0|scale=4|spread=32,32,32|seed=13|octaves=2|persist=1|lacunarity=2|flags=eased
mg_biome_np_humidity_blend|offset=0|scale=4|spread=32,32,32|seed=90003|octaves=2|persist=1|lacunarity=2|flags=eased
```

Encoding rules are identical to section 2: ASCII, LF only, terminal LF, no
whitespace beyond the displayed bytes. SHA-256:
`5a1183a0db4dcbf7c2fce382e907660bfd26e53325d370f62a2d9e78c04d8738`.

### 3.3 R7 manifest extension and environment order

R7 creates a new `grug_wp40_r7_mapgen_manifest_v1`; it does not mutate or
reinterpret the accepted R5 manifest. Its ordered identity consists of:

1. every R5 scalar field in the existing R5 `FIELD_ORDER`, with schema recorded
   as predecessor `grug_wp40_r5_mapgen_manifest_v1` and the validated R5
   canonical digest;
2. `noise_schema=grug_wp40_r7_noiseparams_v1` and the exact noise digest above;
3. `native_schema=grug_wp40_r7_native_allowlist_v1` and the exact native digest
   above;
4. the accepted R6 schema/artifact/catalog/content/template/WP43 predecessor
   digests without reinterpretation;
5. `gathering_schema=grug_wp33_gathering_catalog_v1` and its one canonical
   digest over all 26 rows (12 `new_p9g_source`, 8 `reuse_r6_source`, 6
   `r6_cultural_slot`),
   `production_r6_content_schema=grug_wp40_r7_production_r6_content_v1` and its
   digest over exactly 83 ASCII-ordered rows (the 77-row accepted evidence
   population plus six real Cultural target nodes), the six real R6-validator
   Cultural registration digests,
   `p9g_content_schema=grug_wp40_r7_p9g_content_v1` and its digest over the
   separate twelve-row P9G target table carrying the compatible decoration
   capability 8, plus the P9G delta schema/digest; and
6. `writer_schema=grug_wp40_r7_single_vm_writer_v1`,
   `p9g_order=after_r6_p9_before_run_derivation`,
   `p9g_overwrite=false`, and `production_enabled=true`.

All fields are closed and ordered. Unknown/missing/duplicate fields, a changed
predecessor digest, a zero/missing WP33 digest or a metatable fail validation.
The full R7 digest cannot be frozen in this lane because the accepted WP33
manifest does not yet exist; implementation must insert only the independently
accepted exact digests and then freeze/review the resulting full encoding.

Main-environment order is exact:

1. load pure validators/factories without publishing a global or registering a
   callback/writer;
2. apply the six setters in table order;
3. read the six effective values back in the same order, strictly validate
   them, emit the canonical block, and verify its fixed digest;
4. validate the R5/R6/WP33/native inputs, live node/CID/param2/template and WP43
   projection, full world seed and complete R7 manifest;
5. construct the final immutable R5+R6+P9G session, stable `grug_zones`
   session, anchor payload, adapters and protection policy off-global;
6. only after all checks succeed, register the six closed native ores, publish
   the bounded immutable IPC payload, call exactly one
   `core.register_mapgen_script`, then install the already-validated public
   registry/adapters/policy with assignment-only operations that cannot fail.

The mapgen script's first operations are exact: load only pure R7 modules, read
the six settings in table order, validate the normalized bytes and fixed digest,
fetch the IPC payload, validate the full R7 manifest/digest and reconstruct the
same immutable session. Only then may it call exactly one
`core.register_on_generated`. The emerge environment has no setter and no
fallback. Main/emerge canonical noise bytes and full manifest digest must be
identical.

Any failure aborts startup before the affected environment registers its
callback. There is no warning-only mode, engine-default substitution, legacy
loader, old-world compatibility path or runtime enable switch.

## 4. Single writer and P9G successor boundary

Exactly one main-environment `register_mapgen_script` loads exactly one mapgen
environment script. That script owns exactly one `register_on_generated`
callback. There is no main-environment geography callback.

For each callback, the production writer:

1. obtains the engine VM/emerged bounds/data/param2/light input once through the
   accepted R5/R6 adapter contract;
2. plans only the canonical owner slice and honors the existing native/foreign
   veto;
3. settles P2 foundations, P3 interfaces, P4 paths, P5 terrain, P6 water, P7
   surface, P8 resources and P9 cultural/decorations into the existing private
   shadow buffers;
4. executes P9G at the single insertion seam described below;
5. derives canonical successor runs, completes the existing deterministic
   replay, dirty-region/liquid/light analysis and calls the existing conditional
   VM setters; and
6. performs at most one final VM commit transaction, one required liquid update
   and one required bounded lighting calculation under the accepted R6 rules.

P9G is not an external `apply_fixture`, callback, engine decoration pass, LBM,
repair or second VM phase. Its only legal hook is in the R6 successor settlement
body **immediately after the complete four-class P9 decoration loop and before
the `-- Canonical run derivation` block** (current
`wp40/r6_settlement.lua:1599-1751`). The implementation should make that seam
an explicit reviewed successor-tail function rather than expose general
settlement internals.

The hook consumes the twelve-row `new_p9g_source` slice of the authenticated
26-row WP33 catalog in canonical catalog and candidate order. Every source has
one immutable cell at `(0,0,0)`, rooted at `(x, surface_y + 1, z)`, over the
exact P7 support at `(x, surface_y, z)`. The unique 3-D owner containing the
root settles it. If support is in that owner, validate the settled private
buffers: its `intent_opcode` is in `1..4` and `final_data` is the row's exact
host CID. Only when support is the immediately lower cell in the adjacent
vertical owner does the same analytic P7 authority replace that buffer check;
there is no VM-halo read or second-owner settlement. The six R6 cultural
records alone retain their existing support-rooted `(0,1,0)` convention. A
candidate may accept only if:

- its root/cell is inside the owner slice and original content is not `ignore`;
- the support is the exact allowed P7 content/param2 and remains unchanged;
- target clearance is exact accepted P7 air/clear output; natural-vegetation,
  including P7 dust, is not a P9G predecessor in schema v1;
- no hard/protected, route/water, engineering, R6 cultural, resource or
  decoration occupancy exists; and
- its accepted WP33 biome/zone/tier/access/density row matches.

On any failed predicate it records one canonical rejection reason and does
nothing. P9G never overwrites, clears, moves, retries, refills, falls back,
reassigns a candidate or alters occupancy for a rejected root. On acceptance it
records its own occupancy/opcode/feature identity and writes only through the
same `final_data`, `final_param2` and intent buffers used by R6. No P2--P9
candidate decision is recomputed after P9G.

The accepted R6 evidence artifact's 77-row content table is immutable evidence,
not the R7 production table: its six Cultural fixtures deliberately share
`grug_nodes:bone_pile`. R7 authenticates a new 83-row, fully ASCII-ordered
production-R6 table containing those 77 names plus the six real Cultural
targets. Cultural continues through the ordinary R6 capability-16 resolver;
the resulting production refs are allowed and expected to differ from the
evidence refs. Section 4.1 proves the bounded normalization explicitly instead
of asserting false raw byte identity.

The P9G opcode/class/policy identifiers must be new closed constants outside
the accepted R6 identity set, manifested and covered by run/replay parity. The
reviewed successor change explicitly extends the opcode-to-class/policy
derivation at the current `r6_settlement.lua:1766-1770` seam with P9G-only
branches; every R6 opcode must continue to derive the exact prior class and
policy. Content resolution uses a separate closed P9G resolver and the
compatible decoration capability 8. `grug_wp40_r7_p9g_content_v1` holds twelve
ASCII-ordered local refs `1..12`; with production-R6 count `N = 83`, P9G run
aux uses successor ref `N + p9g_ref` under the existing
`(ref - 1) * 256 + param2` encoding. Neither resolver accepts the other
namespace. The implementation may choose opcode/class numeric values only in
the reviewed code contract. That numeric assignment is a technical
implementation detail, not a player decision.

### 4.1 Required two-stage R6 normalization and P9G delta proof

The accepted R6 artifact remains immutable predecessor evidence, but its
synthetic 77-row content fixture must not be confused with R7's production
content identity. Every accepted R6 seed/fixture and every 32-seed R7 shard
therefore carries two closed projections.

**Stage A -- removable P9G delta.** Retain a canonical P9G operation ledger
containing source ID, root/cell, prior CID/param2, final CID/param2,
occupancy/opcode and acceptance or one rejection reason. Begin with final R7
private buffers before VM setters. For each accepted P9G row in canonical
coordinate/source order, require the final cell still equals its target and
restore recorded prior CID/param2 and prior intent/occupancy. Remove only P9G
schema/ledger/metrics rows, P9G-only runs and the twelve-row suffix. The result
must equal a direct run against the authenticated 83-row production-R6 table
byte-for-byte; no production-R6 ref is renumbered or rederived in this stage.

**Stage B -- production-R6 to accepted-evidence normalization.** Use one
manifested, total name map. Each of the 77 accepted names maps to its accepted
evidence ref/CID/mask. Each of the six real Cultural target names maps only for
its Cultural opcode/feature to the accepted fixture target
`grug_nodes:bone_pile` (evidence ref 68, mask 24 and its evidence CID). Remove
the six production-only content rows, remap every affected content ref/CID,
rederive `aux`, canonical runs, checksums and affected Cultural registration/
content evidence, and encode with the accepted R6 encoder. The result must
match the immutable accepted R6 artifact while candidate coordinates,
eligibility, budgets, acceptance/rejection reasons, occupancy, opcodes and all
non-content P2-P9 decisions remain identical. The map cannot rewrite another
opcode or hide an added/removed Cultural decision.

Both stages assert unique accepted P9G cells and exact prior values. A mismatch
outside the six manifested Cultural target substitutions or the removed P9G
delta is an R6 semantic revision and returns to R6 contract/evidence review.
Only clean Stage A and Stage B proofs may proceed as R7; neither is reported as
raw byte identity between the 83-row production table and 77-row evidence
fixture.

## 5. Atomic removal of legacy writers and registrations

The R7 production commit removes all four active legacy write paths together:

- `ocean_mask.lua` loader, its `grug_mapgen:continent` IPC and
  `ocean_mask_mapgen.lua` callback;
- the `grug_mapgen:ocean_mask_heal` LBM and all bulk node healing;
- the `structures.lua` main-environment generated callback and its independent
  VM setters/write; and
- `ensure_camp_platform_built`'s non-mapgen repair, platform-Y persistence,
  emerge/retry state and fallback discovery.

It also removes legacy biome/ore/decoration loaders and loads only the closed
native module. `grug_mobs.place_camp` may remain solely as a later explicit
runtime activation API; R7 must never call it to realize a fixed map anchor.

No legacy file may be retained as an error fallback. The edit is atomic in one
production commit: a state with the R7 writer plus any old geography writer,
or with no R7 writer plus removed old writer, is not reviewable or mergeable.

## 6. Public queries, anchors and load-order cutover

R7 publishes exactly one `grug_zones` table backed by the validated R4 session.
It exposes the already-specified `get`, `at`, `neighbors`, `travel_links`,
`anchor`, `id_at`, `biome_at`, `race_region_at`, `faction_at`,
`territory_rule_at`, `pvp_rule_at`, `surface_mob_level_at`, `mob_level_at`,
`guard_level_at`, `terrain_height_at`, `water_class_at`, route/hydrology and
housing queries. It exposes no mutable source/session table.

The one adapter module installs only direct delegation to that session:

- `surface_level_at(x,z)` -> `terrain_height_at(x,z)`;
- `mob_level_at(position)` and `guard_level_at(position)` -> same-named stable
  queries;
- `open_sea_at(position)` ->
  `water_class_at(position.x, position.z) == "deep_ocean"`;
- `territory_at(position)` -> `faction_at(position) or "ocean"`;
- `zone_at(position)` -> the already-reviewed R4 compatibility formula, with no
  second bucket or rectangle authority; and
- `difficulty_at(position)`, if a final all-repo audit finds a live compatibility
  need, -> the already-reviewed R4 compatibility formula; otherwise delete it.

Productive consumers that require exact identity migrate to named stable
queries rather than using the coarse compatibility bucket. This includes the
central mob dispatcher and its 27 definitions, bandit/skeleton gates, golem,
rabbit, camp and rare gates, Kraken deep-ocean check, mob/guard levels and
faction/territory policy.

All coordinate consumers use stable R4 anchor records: six `start`, six
`capital`, 24 `outpost`, 12 `bandit` and 10 stable rare-route slots. Join and
respawn, traders, outpost patrols/camps and rare routes derive only from these
records and their authored y. Delete the six capital literals, candidate
providers, platform discovery/persistence/retry/repair and raw replacement
route invention. Future map/mount/housing/travel WPs consume the published API;
R7 does not invent absent production mods.

`grug_factions` and `grug_mobs` must declare `grug_mapgen` as a required
dependency before consuming installed adapters/anchors. Conversely,
`grug_mapgen` must declare the new `grug_gathering` mod as a required dependency
before authenticating its 26-row manifest. `grug_gathering` requires
`default`, `grug_core`, `grug_materials`, `grug_nodes` and `grug_trees`, which
puts its six R6 cultural and then twelve P9G node registrations after every
accepted R6 target-owner mod; it never depends on `grug_mapgen`. Adding the
new nodes leaves every previously registered engine CID unchanged. The six
Cultural names intentionally produce the separately authenticated 83-row
production-R6 ref table; only the later P9G suffix leaves that production table
unchanged.
This graph is acyclic.
The explicit consumer dependency is important because Kraken currently captures
`grug_core.open_sea_at` into its mob definition at load time. Indirect
best-effort load ordering is not accepted.

## 7. One fail-closed protection and gathering authorization boundary

R7 constructs one protection policy from stable hard volumes,
`territory_rule_at`, stable capital/start/anchor heights and player faction.
Only after the session is validated does it install that policy at the existing
central `core.is_protected` boundary. It preserves all three current outer
semantics: protection-bypass privilege, empty-name behavior and delegation to
the previously installed engine/mod handler. The previous handler is captured
exactly once before installation and is never recursively rediscovered.

Until installation, the R7-owned policy seam is fail-closed for protected
Grudgelands volumes. There is no old `in_capital_zone`,
`protected_zone_in_box`, rectangular territory or platform-Y fallback. Point
and box checks call the same policy, and the engineering-brief Battlegrounds
boundary KATs at y `-700/-701` must agree.

WP33's healing-herb behavior is a separate fail-closed runtime seam:

- `grug_gathering.register_herb_authorizer(fn)` accepts exactly one function;
  a non-function or second registration is a fatal contract error;
- before WP10 installs the profession service, the authorization result is
  always false, so healing-herb harvest does not yield its gathered item;
- the call re-fetches current player/profession state and treats nil, error or
  non-true as denial; only literal `true` authorizes;
- spices, foods, found-only sources and P9G placement never call this seam; and
- registering an authorizer does not mutate the immutable source/mapgen
  manifest and cannot register a callback or placement path.

This preserves the decided Alchemist-only herb rule without pretending WP10 is
already shipped.

## 8. Exact R7 verification gates

R7 is a non-trivial package and requires independent review under the model
policy after final bytes freeze. Review consumes the immutable artifacts/logs
and does not duplicate exhaustive runs.

### 8.1 Static/source gates

The completion record stores exact command output and a reviewed expected-count
file. Minimum expectations are:

- repository-wide mapgen setting mutation search: exactly six matches, all
  `set_mapgen_setting_noiseparams` in the one native-input module, with exact
  names/order/tables/`true`; zero `set_mapgen_setting`, `set_mapgen_params`,
  `set_noiseparams` or `minetest.*` aliases;
- under `mods/MAPGEN/grug_mapgen`, `register_biome`: zero;
  `register_decoration`: zero; `register_ore`: exactly six call sites/explicit
  definitions in the one native module, matching section 2 in order and digest.
  No generated loop or foreign wrapper may add rows; all calls to the dormant
  `default.register_biomes`, `default.register_ores` and
  `default.register_decorations` entry points remain zero;
- `register_mapgen_script`: exactly one in the main loader;
  `register_on_generated`: exactly one and only in the mapgen-environment
  script; zero main-environment geography callbacks;
- zero old ocean script/IPC/heal LBM/structure loader, zero mapgen
  `bulk_set_node` or runtime repair `write_to_map`, and zero legacy platform
  state/provider terms listed in the R7 preflight section 9;
- legacy query references are zero outside the one named adapter/policy module,
  with each remaining definition/delegation on an explicit line allowlist;
- WP33 contains zero `register_biome`, `register_ore`, `register_decoration`,
  `register_on_generated`, `register_mapgen_script`, LBM healer, `set_node`,
  `bulk_set_node` or VoxelManip write path; and
- dependency audit proves all load-time consumers require `grug_mapgen`,
  `grug_mapgen` requires `grug_gathering` before reading its manifest, and the
  mod graph is acyclic; exact node-registration-order and manifest gates prove
  that all new targets receive later CIDs without changing a previously
  registered CID, authenticate the expected 83-row production-R6 ref table,
  and keep the twelve P9G rows outside it.

Mechanical `rg` counts are necessary but not semantic proof. Review also parses
the six literal NoiseParams, six native definitions, loaders and aliases to
exclude computed/indirect registrations or mutation calls.

All final Lua receives `tools/bin/luac51 -p`, the explicit SETGLOBAL check and
all five `docs/research/luanti-lua.md` sweeps. Lua under `tools/` is checked
explicitly because mod-scoped sweeps do not cover it. `rg` availability is a
precondition; a missing command is failure, never an empty pass.

### 8.2 Offline/mocked-engine gates

LuaJIT owns development, exhaustive and population evidence:

1. main and mocked-emerge readback tests cover all six expected values and each
   one-field/type/key/flags/order/digest failure; callback/publication counts
   remain zero on failure;
2. native manifest tests cover exact six-row order and every remove/retain
   disposition, including a pinned-engine dirt-blob fixture proving all-stale
   biome names normalize to unrestricted and are therefore rejected;
3. same seed, repeated run, shuffled shard/mapchunk order and owner-slice tests
   prove byte identity and one transaction; cross-owner/foreign nodes remain
   unchanged;
4. complete stable query/anchor/consumer/protection KATs cover every named API,
   all six factions, boundary/vertical policy, bypass/empty name/prior handler,
   Kraken deep ocean and captured-load-order behavior;
5. P9G tests cover every source, acceptance predicate and rejection reason,
   non-overwrite/no-retry behavior, canonical order, replay parity and both
   closed projections in section 4.1;
6. the accepted 32-seed corpus runs only the changed R7 P9G/resource-content
   population lane, reporting opportunities/accepted/rejections by source,
   biome, zone, tier and reason, paired-faction integer cross-product gates,
   a byte-identical 83-row production-R6 Stage-A result, the normalized
   accepted 77-row Stage-B artifact, and a separate P9G delta digest; and
7. transaction metrics require one VM fetch/settlement, at most one each of the
   accepted conditional data/param2/liquid/light operations, zero second
   callback/native decoration/healer, unchanged settlement/VM bounds, and only
   the explicitly versioned 83-row production-content plus P9G run/ledger
   capacities.

The accepted R2 fixed-layout and R6 32-seed artifacts remain immutable
predecessor evidence. Do not rerun retired T2 full-W/PCC/F1/F2 suites. A change
outside the six closed Cultural target normalizations or P9G delta stops and
reopens R6 rather than laundering the change through R7.

### 8.3 Process scheduling and final micro-KAT

At most seven LuaJIT/PUC processes may exist concurrently across all agents and
lanes. Independent LuaJIT seed/shard workers use at most seven processes, each
with immutable input and its own scratch/output path, under
`chrt --idle 0 ionice -c3`; one deterministic final process orders, combines
and checks their results. A rerun records its actual fleet width. Jobs sharing
mutable output or order-dependent state are never parallelized.

No intermediate PUC runtime suite, PUC seed fleet or exhaustive PUC population
is allowed without a concrete interpreter-specific finding. After all relevant
Lua bytes and fixtures are frozen, run exactly one compact PUC 5.1 micro-KAT
process and the same fixture once under LuaJIT. The two canonical byte streams
and SHA-256 digests must be identical. Any relevant final-byte change replaces,
rather than supplements, that final pair. PUC still owns parser/static gates.

The micro-KAT covers at minimum: six-noise canonicalization, R7 full-manifest
validation, one native allowlist digest, one accepted and one rejected P9G root,
both R6 projections, one owner-slice transaction/replay, representative stable
queries/anchors and fail-closed protection/herb authorization. It is bounded
representative parity evidence, not an exhaustive engine substitute.

## 9. Ratified decisions and GO boundary

This native/input/cutover lane introduces **no new player/design decision**.
Its technical choices are closed above. The user accepted every recommended
decision D1--D6 in `wp33-gathering-contract-candidate.md` Section 9 on
2026-08-31. That exact set covers densities; all zone/biome/shore rosters;
cultural tool families; concentrated yield; resolver ownership and its durable
WP29 obligation; and
the ordinary P9G one-cell interaction/yield. D6 is a direct GO blocker because
any multi-node option would invalidate Section 4's one-cell successor record.
The 12/8/6 classification and all six cultural registration digests remain
authenticated parts of the accepted 26-row manifest, not a separate or
silently mutable decision list.

The ratified fold also amends the WP28 `BACKLOG.md` row to own the deliberate
removal or replacement of the now-unreachable vendored clay/brick and
silver-sandstone recipe families. WP26 remains limited to Universalbars and is
not named as a fallback owner. This durable WP28 assignment is a technical GO
condition, not a license for R7 to invent replacement sources.

Those player-visible content/access choices are fixed and must not be changed
by the R7 implementer. Inserting their reviewed manifest's exact bytes/digests
into Section 3.3 is mechanical. Numeric allocation of a new
P9G opcode/feature identity, module/file names consistent with this contract,
and direct-adapter deletion where a final audit proves no caller are technical
implementation decisions reviewed with the code.

## 10. R8 release/runtime gates

R7 acceptance proves source closure and deterministic offline behavior. It does
not claim that a Luanti world has been generated. R8 must use the pinned real
engine and a fresh v7 world to prove:

- both environments authenticate the same effective six NoiseParams and R7
  manifest before the one callback becomes active;
- built-in biome ID 0 supplies correct native stone/water/cave-liquid/dungeon
  fallbacks with zero Lua biomes;
- the exact gravel blob and all five strata survive in representative owner and
  edge mapchunks, while clay/silver-sand/dirt blobs, all scatter resources and
  all engine decorations are absent;
- native caves, dungeons, ores/strata, liquids and lighting coexist with P2--P9G
  without a second writer, seam, overwrite or stale healer;
- owner-slice, repeated/emerge/mapchunk order behavior and foreign-node veto are
  correct under actual engine callbacks;
- representative seeds show designed biome/surface/content/resource/P9G access,
  capacity and paired-faction supply, and the map is visually inspectable in
  game;
- callback/VM transaction counts, generation time and RSS meet the measured R8
  release budget; and
- the user runs the separate fallback-engine runtime gate on an existing and a
  fresh v7 world according to the final completion plan.

Any real-engine mismatch is fail-closed. R8 may fix an integration defect under
review, but a native allowlist, six-noise value, P9G design row or R6 semantic
change returns to the owning reviewed contract rather than being waived at
release.
