# WP40 Simple Map R6 Consolidated Preflight

Status: current preparatory record; not an accepted R6 contract and not an
implementation GO
Branch: `wp40-simple-map-r6`
Snapshot date: 2026-08-29 (Europe/Berlin)

## 1. Outcome

R5 is accepted and integrated, so the old external preflight's hard dependency
is closed. R6 is nevertheless **NO-GO for implementation** until the five
sections and ten separately amendable choices in
[`TODO-design-wp40-r6-contract.md`](../../TODO-design-wp40-r6-contract.md) are
decided and the resulting successor schema, arithmetic, artifact format and
evidence contract pass independent review.

This record replaces the external scratch directory
`/home/jan/projects/grudgelands-wp40-r6-preflight`. It keeps the approved parts
of its 2026-08-28 D1-D6 packet, corrects claims invalidated by the final R5
seam or by source inspection, and records all supplementary Fable findings
which affect R6. The three external Markdown drafts are not copied wholesale:
they described a moving R5 checkout and contained contradictions now resolved
here.

No R6 Lua, mapgen callback, build, test or world mutation belongs to this
preflight step.

## 2. Accepted lineage

The R6 branch starts at merge commit
`e6fe00a4fdf52ad2c10e02128d8b367fda73f662`, whose second parent is the R5
closeout `212f822d3bef8e87a48958ee2286adf00e525e87`. The reviewed R5 runtime
candidate is `6e66cb30f0a17a8a4257c0f0d66ab0ef12e33b09`.

| Input | Accepted identity |
|---|---|
| R2 artifact body / file | `1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b` / `ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b` |
| R3 artifact body / file | `09b4ac762b9e6dc7d088d5f39c306d0dc80b9769d3bf8b6c35ea8a8a6bc282d2` / `c1090c5a9169c9fe449ad1b0f560b9a5b5b4a486c744445083ee05fbaa219e65` |
| R4 accepted implementation | `948689138c15c291544fe10927683da4183bfd8e` |
| R4 historical artifact file | `23a05d2115fb6d3a1b286e09a17847793e23fc0a23817ade8ce8b812875d1b3c` |
| R4 accepted targeted KAT body / file | `72b9bd0e2d21cb82c4b1627031434eda1b83a2d8b8223fae22eb8f0e377ab5de` / `14463a99810351439fdf5d65a02436e367db69df1c2efebaeb8bc1b495a90b39` |
| R4 review file / verdict | `f0a8a59e43a678d388e92528f9d3bf4b3db49fa659548880ab094a5602070eab` / `bd67757f881b3a2e1952214870f60b71ab3907022153edd26f99f23a0528f130` |
| R5 contract file | `30d4c267986e43f3f6abeec7cd27abc0f4d44565a0439f5df26f567f849a8fda` |
| R5 artifact body / file | `a0e7241dabf71833c490d574cbbf4702cdd2c63289277bcc3f49255039a78e1b` / `0ffd8cd5c0133645c330703b8e4ea581a21fe6e5891ddcd987236b26a7d07ca0` |
| R5 immutable input manifest | `8eaef1d05557655552d845f4a281bf65d0066ceda562eb7736b995c3c174237a` |
| R5 review file | `21cd9494e0ac717340b9d041efd2aff22cead8c16003f25e15de814e0085c863` |

R5 remains disabled and writes no world. R6 may define a reviewed successor
plan schema for P7-P9, but it may not reinterpret an R5 opcode, role, priority,
conflict rule, replacement policy, owner slice or transaction boundary.

## 3. Authority order

The final R6 contract must consume these authorities in order:

1. `docs/design/world_zones.md` §§7-14 for world, water, resource, parity,
   access, housing and rollout requirements.
2. `docs/design/biomes_mobs.md` §2 for target surface and decoration content.
   Its §1.3 top-node table is an explicit WP18 migration baseline which awaits
   option-A approval rather than silently becoming target authority.
3. `docs/design/items_crafting.md` §§3.0 and 4.1 for depth, resources and
   cultural ownership.
4. `docs/research/wp40-simple-map-rebase-plan.md`, R6, for package scope.
5. The accepted R2-R5 artifacts, contracts and reviews for frozen geometry,
   height, policy, logical-biome selection and the one-transaction writer.
6. `docs/research/wp43_wp40_handoff.md` and the live WP43 registry for node
   identities, harvest tiers, published density inputs, deep multipliers,
   exact-host taxonomy and race-region assignments. The approved D2 packet
   owns placement-start tiers, universal/G1 density values and vein caps. R6
   validates every overlapping value against the live registry and does not
   own a second copy of WP43 data.
7. `docs/research/luanti-lua.md` and the repository seven-process rule for
   interpreter and execution ownership.

Legacy `biomes.lua`, `decorations.lua` and `ores.lua`, together with
`biomes_mobs.md` §1.3's explicitly labelled WP18 migration baseline, remain
migration inputs. They identify nodes, assets and behavior worth retaining but
never override a target design value or the WP43 registry.

## 4. Reconciled D1-D6 state

| Packet item | Current status | Binding preparation result |
|---|---|---|
| D1 cultural boundary | Partly decided | R6 owns deterministic opportunity slots and ledgers; WP33 registers and realizes content through the same writer without movement or retry. D1 approved both density denominators and four unchanged biome allowlists. Task A identified the dead Orc east-badlands entry; source inspection also identified the dead Troll fringe entry and missing live Troll east-badlands eligibility. The reservation envelope, rollout order, paired Orc/Troll correction and exact six T4 zones remain in the TODO. |
| D2 resources | Numeric projection retained | The approved R6-only placement-start tiers, universal/G1 calibration values and vein caps are distinguished from live WP43 registry inputs in `wp40-simple-map-r6-resource-density.tsv`. Published WP43 G2/Abyssal densities and deep multipliers come from the registry; every overlap is validated and a mismatch fails closed. Horizontal water-class eligibility and the ±5% camp/parity interpretation remain in the TODO. |
| D3 shore/bed | Decided | `wp40-simple-map-r6-shore-bed.tsv` maps the 16 logical biomes. R3/R5 remain the sole vertical-span authority; R6 adds no shore or bed depth. |
| D4 decorations | Model decided, catalog open | Global 16-column cells, domain-separated full-seed hashes, bounded footprints, deterministic conflict order, immutable parsed templates and direct expansion into the one VM transaction remain binding. Numeric fills and legacy parameters await approval of the draft table. |
| D5 32 seeds | Decided | `wp40-simple-map-r6-seed-corpus.tsv` is the ordered strings-only corpus. It was fixed independently of R6 output and contains the 27 inherited rows plus labels `-08` through `-12`. D5 explicitly supersedes `seed_corpus.lua`'s retired exact-T2 slots 28-31 and conditional T9 slot 32 rules; R6 implementation must update that module, its pending rows and its `#corpus.fixed == 27` verifier before consuming the 32-row corpus. |
| D6 evidence split | Corrected | Fixed inputs and identities are projected once. R3 detail height, R4 biome choice, native host substrate and R6 content vary legitimately by full seed. |

The normalized surface table is
`wp40-simple-map-r6-surface-content.tsv`. It joins the old inventory and
shore/bed draft, removes all `TBD` shore fields, gives both deep-jungle logical
IDs the target canopy litter, and names the WP33 gathering boundary explicitly.

## 5. Technical rules safe to freeze before implementation

### 5.1 P7-P9 successor boundary

R5 reserves `BIOME_TOP`, `BIOME_FILLER`, `BIOME_SHORE`, `BIOME_BED`,
`RESOURCE_EXACT_HOST` and `DECORATION`, with zero accepted production rows.
Those names do not by themselves define a legal R6 record. R6 must version a
successor schema and close every field, aux value, content role, footprint,
owner rule, conflict and replacement policy before emitting one.

Ordinary and river water are existing P6 operation roles whose final node/CID
mapping belongs to the R6 content contract; they are not new P7 records. Snow
dust and the simple/template decoration distinction likewise require explicit
successor representation rather than an assumed reserved token.

### 5.2 Exact resource budget partition

Candidate cells use negative-safe `floor(coordinate / 16)` on every axis. A
whole cell is never assigned one tier or multiplier when it spans a boundary.
For each resource, partition it into canonical
`(resource, cell, WP43 stratum host, density tier, deep-multiplier band)`
sub-bands. Count exact eligible hosts and compute the rational node budget per
sub-band. Veins stay inside both the candidate cell and that sub-band.

The final contract must specify the floor/remainder arithmetic using integers
within the Lua 5.1 safe range, the digest-word reduction, its quantified finite
modulo bias, root order, budget-to-vein split, six-neighbor frontier order and
all KATs. It must also close the design's bounded/capped maximum after applying
the WP43 `5/4` or `3/2` deep node-budget multiplier. It must not describe a
direct modulus trial as perfectly unbiased. A rejected host or short vein is
counted and is never refilled from another cell, band or seed.

### 5.3 Deterministic decoration settlement

The approved ordering remains:

1. fixed/protected/route/water exclusions;
2. accepted cultural reservations;
3. emergent and other large templates;
4. ordinary tree templates;
5. simple multi-node trunks; and
6. ground cover.

Within a class, order by cell z, cell x, candidate rank and decoration ID.
Candidate discovery includes the exact neighbor-cell halo of the largest
rotated footprint. The R5 central-owner rule chooses the only emitting slice;
neighbors may inspect but never settle. Conflicts, wrong exact hosts, clipped
footprints, `CONTENT_IGNORE` and insufficient clearance reject without retry.
No R6 path may call `core.place_schematic`, `register_decoration` or a second
writer.

Every `.mts` is parsed once to a table, copied to a private immutable template,
subjected to its explicit replacements, validated and identified by canonical
digest. Rotation is one of 0/90/180/270 degrees from a domain-separated hash.
Simple height/param2 and placement offsets come from the approved catalog and
not from engine randomness.

All decoration roots require `surface_y >= 1`, preserving the legacy global
lower bound. The old emergent-tree `sidelen = 80` is not an R6 candidate-cell
rule; its purpose is replaced by the exact largest-footprint neighbor halo.

### 5.4 Fixed and varying evidence

Once-only fixed evidence comprises R2 topology, 100 anchor x/z identities, ten
housing masks and packing result, the 24 apex-socket identities and geometry,
and the accepted artifact/input digests. Every combined seed manifest must
carry those same identities.

Per-seed evidence legitimately varies:

- R3 `H(full_seed, x, z)` detail and all resulting surface heights;
- R4 logical-biome selection;
- native v7 cave/ore/dungeon/stratum host substrate and accessible host volume;
- R6 resource, cultural-slot and decoration candidates, conflicts and
  settlement; and
- all ledgers derived from those values.

The 24 apex sockets remain fixed positions/content assignments. Their geometry
and reachability proof runs once; every seed manifest checks that R6 did not
vary or overwrite them.

### 5.5 Evidence ownership

R6 owns node-density conformance; G1/G2/cultural access classifications;
eligible-host, candidate, vein, placed-node and rejection ledgers; exact
logical-biome/zone content coverage; and the chosen six-race ±5% metric. It
also exports reachable-area/host denominators for later consumers. It exports
R2's fixed-layout housing portfolio, bounds, packing witnesses and capacity
result for WP24 by exact projection, never by a per-seed rerun.

R6 owns none of the actual leather, cloth, silk, feather, healing-herb, spice
or alchemy-reagent opportunities. The ±10% paired ledger therefore has zero
R6-owned opportunity rows by design, not a vacuous success claim. WP6/WP33 and
their consuming packages must combine their own opportunities with the R6
denominators.

## 6. R5 supplementary hard-lens dispositions

Fable Task C accepted frozen R5 commit `212f822d` with
**0 Critical / 0 High / 0 Medium / 2 Low** after its bounded completion pass.
Neither Low changes R5 bytes or invalidates its artifact:

- R5's “all fatal validation before setters” wording is too broad because a
  non-conforming VM can still throw or return invalid post-setter light data.
  R6 distinguishes completed semantic prevalidation from defensive VM-contract
  failure; conforming-engine behavior is unchanged.
- R5 §11.2 orders light seed-plan construction before `get_light_data`, while
  §12.3 and the implementation correctly read original light before deriving
  seed membership. R6 uses the coherent §12.3 order.

Task C also established that the zero production population of all three P2
`FOUNDATION_*` opcodes is a legitimate accepted-layout zero: the required
`hard_foundation AND anchor_platform` intersection is empty. Adapter fixtures
still exercise all three opcodes. R6/R7 must treat the first layout change
which creates such an intersection as activation of previously zero production
behavior, not as an incidental count change.

The Task C briefing named a nonexistent R2 contract. Future briefings use
`docs/research/wp40-simple-map-v1e-refresh-contract.md` for the R2 contract
role.

## 7. Interpreter and execution plan

`AGENTS.md` and `docs/research/luanti-lua.md` are the current interpreter
authorities. They supersede the rebase plan's older §8 instruction to run
intermediate representative PUC KATs.

- LuaJIT owns long, exhaustive, fixed-layout, 32-seed and full VM runs.
- No intermediate exhaustive PUC 5.1 population is scheduled.
- After final bytes freeze, exactly one compact representative micro-KAT runs
  once under PUC 5.1 and once under LuaJIT; canonical bytes and digest must be
  identical. A final-byte change replaces that pair.
- Every Lua change receives `tools/bin/luac51 -p`, the changed-mod `SETGLOBAL`
  check, all five repository sweeps and explicit tool-Lua sweeps.
- At most seven Lua processes run across all agents and packages. Independent
  workers receive immutable inputs and separate outputs under `chrt --idle 0`
  and `ionice -c3`; one deterministic final step orders and combines them.
- The independent reviewer verifies the immutable artifacts, logs and hashes
  plus the final PUC/LuaJIT micro-KAT pair. It does not duplicate the long
  population.
- R6 remains disabled. Real-engine and GUI runtime evidence belongs to R8
  after the R7 atomic cutover.

## 8. Review and implementation gate

After the ten choices in the five TODO sections are decided:

1. fold them into the design documents where they narrow existing rules and
   delete the completed TODO file;
2. write the exact successor P7-P9 schema, allocation bounds, content manifest,
   hash arithmetic, ledger schemas and artifact ordering;
3. run a dedicated read-only hard-lens review of the arithmetic and
   representation, then the mandatory independent review of the complete
   contract. Both are routed under `docs/process/agent-model-policy.md`; a
   Fable route requires explicit authorization for that particular task;
4. correct and re-review every Critical/High and any affected lower finding;
5. only then implement on this branch, keeping the writer disabled;
6. run the LuaJIT evidence fleets, final PUC/LuaJIT micro-KAT pair, static
   gates, artifact promotion and independent implementation review; and
7. commit/push the accepted R6 milestone. R7 alone performs activation and
   consumer migration.

## 9. External preflight and Fable provenance

The replaced external directory contained eight files. Their preserved source
hashes are:

| External file | SHA-256 |
|---|---|
| `R6-PREFLIGHT.md` | `261205106225be4a8688950cb0a738d95e3492c619fe6a664c8b7c6fb96dfbea` |
| `R6-DECISION-PACKET.md` | `d90225077aa8526a0a79e5be7e12932d7c84a4faaa41e25977c6d6c05d6aca25` |
| `R6-CONTRACT-OUTLINE.md` | `6238e2b8c0a4b8bc50e2579e66af54ce7fbcbfee7fa74850676e3ad2dd08d742` |
| `biome-content-inventory.tsv` | `449f2c7ce2f68742986132882f04d8795d292f7ee4f773648591154d819da664` |
| `r6-cultural-opportunities.tsv` | `a076f1d92551dfc64ba9007f330a3c49abd1c079614625bdd00ad692947a809d` |
| `r6-resource-density.tsv` | `18878b739da87d9fce77d44377053e2d7606bec30fb7f8b39c081aed8e88e79f` |
| `r6-seed-corpus.tsv` | `c055c7910e97f6062111f33f15365c5d85694c51c0b474b0ffa378ba14e65c37` |
| `r6-shore-bed.tsv` | `e12b30e5d43f71108e6d21894b1fac3e2762696e90b745f3e849cd86f4b31d83` |

The repository resource-density, seed-corpus and shore/bed TSVs began as
byte-identical copies of their external counterparts. The cultural table and
surface-content inventory are normalized successors, and the decoration table
is new. The coordinator computed the current repository-file hashes after the
correction pass; they are deliberately separate from external-source
provenance:

| Repository TSV | SHA-256 |
|---|---|
| `wp40-simple-map-r6-cultural-opportunities.tsv` | `a398970fda8ecf0324ba807218aff1d2632910d85be6e68a4f4afa4e00a7967e` |
| `wp40-simple-map-r6-decoration-draft.tsv` | `87167c0ad64e347387a36465270b5e87f215d6fe04f13eff2e68fa01c9037b6b` |
| `wp40-simple-map-r6-resource-density.tsv` | `31e616e0686d9099777de2304b6c21ba5294393444ec7ab1ef1cac1360443394` |
| `wp40-simple-map-r6-seed-corpus.tsv` | `c055c7910e97f6062111f33f15365c5d85694c51c0b474b0ffa378ba14e65c37` |
| `wp40-simple-map-r6-shore-bed.tsv` | `e12b30e5d43f71108e6d21894b1fac3e2762696e90b745f3e849cd86f4b31d83` |
| `wp40-simple-map-r6-surface-content.tsv` | `085e3a3e3cefb8ea36bac101e8f801175cd5e8f2b32f9bad280eefe45412e5e4` |

Fable Task A was a supplementary adversarial review of those pre-R5 drafts. Its
byte-identical full report is preserved as
[`wp40-simple-map-r6-fable-task-a-report.md`](wp40-simple-map-r6-fable-task-a-report.md).
It returned **CONDITIONAL GO for contract preparation only**, with two High and
six Medium gaps. Its report SHA-256 is
`792e8088210d91bf992466b8f95e907283917cecd0663ca0b9b13d75f92c2ba6`;
JSONL `48e1bac2ff4aa16c3e2c47dc024f571fda2fd83e2f57d621906a9e4937689513`;
prompt `24656769b62ed1cc334ab86ac31936f3833aea68bae0ecbe63b85e5c49c4f248`.
Its useful findings were independently checked by the coordinator; its broad
source-coverage assertion is not used as acceptance evidence. In particular,
Task A Low 1 correctly identified the D1 Orc `grug_badlands_east` allowlist as
dead; the repository table removes it but marks that correction pending user
approval together with the related Troll correction.

Fable Task C's byte-identical accepted bounded completion report is preserved
as
[`wp40-simple-map-r5-fable-task-c-report.md`](wp40-simple-map-r5-fable-task-c-report.md).
Its SHA-256 is
`5df5c7b8bc12b0f0d6c555d26861ae7602f91daef331683031e3b011ed8a6d67`;
JSONL `ad99bd54fdb3e504165d3092a9ec5e33671386237a417a3b30a72ea42d988f5a`;
prompt `310254af4f96db7a8438d712f0b07b6b1712dce1e4dcb11044c6600bf5b8f3e8`.
It ran as `claude-fable-5` through Claude Code 2.1.228, exited zero with empty
stderr, and used only read/search tools. CLI-version and help captures hash to
`6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157`
and `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`.

Fable Task B's WP44 result is preserved separately in
[`wp44-fable-task-b-report.md`](wp44-fable-task-b-report.md) and summarized by
[`wp44-income-ledger-preflight.md`](wp44-income-ledger-preflight.md).

Once this repository record and the byte-identical reports are reviewed,
committed and pushed, the external preflight directory and the large Task A,
Task B and Task C snapshot/JSONL copies are redundant. Their later removal is a
separate user-authorized coordinator cleanup action, not an effect authorized
by this documentation commit.
