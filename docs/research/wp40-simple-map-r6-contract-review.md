# WP40 Simple Map R6 Contract Review Record

Status: accepted 2026-08-30; exact R6 contract has Implementation GO
Branch: `wp40-simple-map-r6`
Base commit: `0d0f44e78ec7c32454cedae124551edb4155c7ab`

## 1. Reviewed package

The coordinator prepared the exact disabled R6 contract and the standing
repository-wide Anthropic sharing authorization in `AGENTS.md`. No Lua,
callback, build, test or world mutation belongs to this contract package.

The initial Task-D target was the uncommitted contract with complete-file
SHA-256
`c286ec98914a9b10ff59538433c08ab3cf1b4cc6b1bfb196655b5e5e201465e8`.
The only other worktree edit at launch was `AGENTS.md`. The reviewer received
the exact R6 worktree rather than another checkout.

## 2. Fable Task D hard-lens

The user specifically authorized Fable Task D and transmission of the bounded
repository snapshot to Anthropic on 2026-08-30. The review ran read-only via
Claude Code 2.1.228 as `claude-fable-5`, effort `xhigh`, with only
`Read,Grep,Glob`; shell, writes, delegation, web, MCP and session persistence
were disabled. The foreground wrapper completed with exit status zero, one
final successful `type="result"`, empty stderr and no disallowed tool call.

| Item | SHA-256 |
|---|---|
| Prompt | `08c71376c1a9b86c67d041bd0e8e68928ce01ae0f3888ea72c0f869e9ed7911f` |
| Complete JSONL | `7e1b1bb73c30f43ce8aa12fe8d38f1e4888a180a7af43e2be310f59ad849d931` |
| Byte-identical report | `9c5aaa99ace6b3b9ce9af3ac7d721f7d82f733b1002c2e6b4e5eae6348b3a0bb` |
| CLI version capture | `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157` |
| CLI help capture | `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6` |

Verdict: **REVISE — 1 Critical / 3 High / 4 Medium / 7 Low**. The complete
report is
[`wp40-simple-map-r6-fable-task-d-report.md`](wp40-simple-map-r6-fable-task-d-report.md).

## 3. Coordinator disposition

| Finding | Disposition in corrected contract |
|---|---|
| C1 evidence population/overflow | Accepted. Section 11.2 now fixes the complete 32-seed horizontal population, a 48-x/z-cell/eight-depth resource census, exact varying substrate proxy, row aggregation, workload and an exact `2^53` upper bound. |
| H1 wrong 48,000 KAT | Accepted. Corrected to `15615`. |
| H2 zone tier vs depth tier | Accepted. All eligibility, grouping, hashes and ledgers now use the WP43 depth tier at y. |
| H3 region denominator/vein attribution | Accepted. H requires the exact race region; each vein belongs to its root's region. |
| M1 cross-slice P7/P9 | Accepted. Global P7 spans clip analytically and out-of-owner support is derived without a VM-halo read. |
| M2 missing candidate array | Accepted. The public handle now includes the exact 14-cell candidate stride and ordering. |
| M3 digest extraction | Accepted in substance. Rotation uses the high two bits of byte one. Gravewood uses byte-one modulo 3 and discloses its correct 86/85/85 finite distribution; the report's incidental 86/86/84 count is not copied into authority. |
| M4 missing access ledgers | Accepted without deferral. Exact native/opposing/deep/island/cultural witness gates remain R6-owned. |
| L1 P7 class/policy wording | Accepted and strengthened. R5 class IDs remain unchanged; R6 target kinds are separate, and filler uses a new exact successor policy rather than reinterpreting R5 `SURFACE_EXACT`. |
| L2 surface-y alias | Accepted; it is exactly `terrain_y`. |
| L3 P7 feature ref | Accepted; both refs are zero. |
| L4 dungeon provenance | Accepted; only analytic pinned volumes are exclusions. |
| L5 inert neighbor halo | Accepted; it is explicitly diagnostic-only under 16/80 nesting and owner clipping. |
| L6 missing identities/variant IDs | Accepted; `grug_trees`, all 15 MTS inputs and exact range expansion are pinned. |
| L7 rejection ledger ambiguity | Accepted; first-match reason ownership is closed. |

The corrected candidate sent to the mandatory independent review has
complete-file SHA-256
`89c2f6870598f7289cc0e7790a28ab7cd36b3a9feff7ec461ba36f8a86e66e2a`,
`AGENTS.md` SHA-256
`fc26b162522753e20fb2ca05fece4215bd463e2c0b487cc89ae58775986b2ea3`,
and a clean `git diff --check`. No builds or tests were run.

## 4. Mandatory independent full review

The mandatory reviewer examined the complete corrected contract, standing
authorization rule, Task-D report, coordinator disposition record and the
repository authorities available in the exact worktree. It ran read-only via
Claude Code 2.1.228 as Claude Opus at effort `xhigh`, with only
`Read,Grep,Glob`; shell, writes, builds, tests, Lua execution, delegation, web,
MCP and session persistence were disabled. The foreground wrapper completed
with exit status zero, exactly one final successful `type="result"`, empty
stderr and no disallowed tool call. The session took 1,410,728 ms over 74
turns.

| Item | SHA-256 |
|---|---|
| Prompt | `db6e68f0552fd4833f03c5af90a403a4e5016fab9cc7035e3a27933948336c11` |
| Complete JSONL | `50686b8a7a80b80fd0fd4464112050fca297d0ba2826982cd42efc3b07cb65ca` |
| Extracted complete result | `cd4185631ff98e6eb5e3076e146cce8409d47a459e680d4d1c2e998f0a3eaf7b` |
| CLI version capture | `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157` |
| CLI help capture | `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6` |

Verdict: **REVISE — 0 Critical / 2 High / 4 Medium / 8 Low**.
Implementation remains NO-GO.

## 5. Independent-review disposition

| Finding | Coordinator disposition |
|---|---|
| H1 single target kind | Accepted. `content_kind_masks` now carries combinable P7-material/dust/resource/decoration/cultural bits. Exact `air` is the sole non-emitting manifest exception and can never be a written target. |
| H2 mixed parity populations | Accepted. With the user's 2026-08-30 approval, sampled natural-vein density and exact ordinary-camp equality are separate gates; no full-world constant enters a census denominator. |
| M1 native-dungeon volume | Accepted. The nonexistent geometric exclusion is removed; retained R5 exact-host equality excludes native dungeon content. |
| M2 open ledger rows | Accepted. One common 23-column TSV schema now closes every family's keys, payload, aggregation, ordering, row/byte bounds and body-hash trailer. Resource vein/node rows are per-sub-band aggregates, never per instance. |
| M3 rotation hash field | Accepted. The field is exactly rotation index 0..3. |
| M4 uncosted long population | Accepted. A full-work single-seed seven-shard pilot, projection record and unconditional user-approval stop now precede the 32-seed fleet. |
| L1 five ranges | Accepted; both ordinary and deep-forest fern ranges are named. |
| L2 same-zone census | Accepted; all 256 columns must share one exact zone. |
| L3 water sentinel | Accepted; the exact integer is `-31007`. |
| L4 R6 shore trigger | Accepted; the dry-beach trigger is explicitly R6-owned. |
| L5 access in gate list | Accepted; all five access witnesses are mandatory. |
| L6 owner clipping magnitude | Accepted; exact cultural geometric eligibility and expected material large-template loss are stated and measured counts/ratios are required. |
| L7 bounded Anthropic scope | Accepted; `AGENTS.md` now uses the unconditional process wording. |
| L8 support pattern | Accepted; the rule now names the parsed cell's exact `force_place = true` field and required P7-material bit. |

### H2 design-authority ruling

The bounded synthetic census can prove deterministic natural-vein opportunity
density and the fixed camps can prove exact six-race equality, but adding the
full-world camp constant to a sample-only host denominator is dimensionally
wrong. The user approved the simpler correction on 2026-08-30: R6 gates exact
sampled natural rate `V_r/H_r` under the same 5%-over-lowest rule and separately
requires exactly 384 ordinary-camp sockets for every race. No combined rate is
deferred to R8 and no exhaustive native-world census is invented. Matching
edits now live in `docs/design/world_zones.md`, the R6 decisions, the rebase
plan and the exact contract. A focused independent review is required before
implementation GO.

## 6. First focused correction review

The first focused Opus correction review examined the seven exact target files
after the parity ruling and rechecked all prior H1-H2, M1-M4 and L1-L8
findings. It ran under the same read-only Claude Code 2.1.228 / Opus `xhigh`
profile with only `Read,Grep,Glob`. The foreground wrapper completed with exit
status zero, exactly one final successful `type="result"`, empty stderr and no
disallowed call. The session took 1,100,665 ms over 44 turns.

| Item | SHA-256 |
|---|---|
| Prompt | `905b6a878bae424475c114f7aab6fa91a8d8cd01294bfe252945b87103eff010` |
| Complete JSONL | `4d38234abe234a285369ba4a4aadfc73082cc54702f2d4d7e578b87c24148c04` |
| Extracted complete result | `85a514361590f6e8bc2bef053fa2ccb67450b6e06c41433e27a35d8dce4cd0b4` |
| CLI version capture | `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157` |
| CLI help capture | `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6` |

Verdict: **REVISE — 0 Critical / 1 High / 3 Medium / 7 Low**.
Implementation remains NO-GO pending a second focused review.

## 7. First focused-review disposition

| Finding | Coordinator disposition |
|---|---|
| N1 host denominator | Accepted. `H(r,s)` now counts only census voxels satisfying every Section 6.1 condition for at least one counted resource, once across resources. |
| N2 access keys | Accepted. k4 is an exact witness discriminator; cultural rate class and island socket ordinal make all 12/24 witnesses unique. |
| N3 pilot projection | Accepted. The pilot includes the resource census and conservatively projects fleet wall time by 35 while CPU/scratch retain factor 32. |
| N4 MTS probability | Accepted from pinned engine source. The exact reader call, even 0..254 return domain, `0x7f` mask, separate `0x80` force bit, dense all-slice requirement and deterministic `p/256` mapping are closed. |
| L-a resolver tuple | Accepted. The five scalars now separate R5 target kind from the R6 target-role mask. |
| L-b trailer sort | Accepted. Only data rows sort; the hash trailer is appended afterward. |
| L-c camp authority | Accepted. The gate hashes the exact `world.md`/`world_zones.md` inputs and six derived budget rows; it no longer claims nonexistent WP13/WP34 socket rosters. |
| L-d emergent size | Accepted. The unsupported bare count is removed; parsed rotated dimensions and measured clipping own the evidence. |
| L-e parity key names | Accepted; they are lowest-rate/highest-rate race IDs. |
| L-f digest text | Accepted; every digest field is lowercase 64-character ASCII hex. |
| L-g cultural validator | Accepted. Module-level validation is structural; construction owns injected-content validation. |

## 8. Second focused correction review

The second focused Opus review independently checked N1-N4 and L-a through L-g
against the exact corrected bytes and, unlike the prior worktree-local review,
also read the initialized Luanti source reference at gitlink
`df04879066de6eb94ca43996822a6dfacc74feca`. It ran under the same read-only
Claude Code 2.1.228 / Opus `xhigh` profile with only `Read,Grep,Glob`. The
foreground wrapper completed with exit status zero, exactly one final
successful `type="result"`, empty stderr and no disallowed call. The session
took 1,302,047 ms over 52 turns.

| Item | SHA-256 |
|---|---|
| Prompt | `c08ae7f3f2dcf7e96385f4e4f2e5f15eb20fa00265077cd02a1238dc5b5fed29` |
| Complete JSONL | `cad27c128f97d20b130450d668207123259b3041a903b4ca94313da68e9ae36e` |
| Extracted complete result | `65f24685b50f9f9c2a8d4afecb08a3c1ffcba30b3918a8da9cd8a5bd714ce842` |
| CLI version capture | `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157` |
| CLI help capture | `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6` |

Verdict: **ACCEPT — 0 Critical / 0 High / 0 Medium / 7 Low**;
**Implementation GO: YES** for the reviewed bytes.

## 9. Accepted-review Low cleanup

The seven Low findings had a normative answer elsewhere and did not block the
accepted GO. They are nevertheless folded into the exact contract to remove
implementation friction:

| Finding | Cleanup |
|---|---|
| F1 stale camp roster phrase | Replaced with the Section 10.3 frozen design-budget derivation. |
| F2 missing `grug_nodes` input | Added `mods/ITEMS/grug_nodes/init.lua` to the manifest. |
| F3 param2 rotation authority | Added pinned `src/mapnode.cpp`; unsupported 4dir/degrotate families now fail rather than rotate partially. |
| F4 denominator detail | Added per-seed/per-race/per-sub-band `region_host` union rows and an exact aggregate equation. |
| F5 memory projection | Added conservative per-worker peak-RSS factor 7. |
| F6 host-ledger wording | Distinguished the census union denominator from per-resource `resource_host`. |
| F7 gate vocabulary | Added the exact closed 20-ID gate list and completeness rule. |

Because these cleanups alter reviewed contract bytes, one final narrow
read-only consistency review is required before the package status becomes
accepted.

## 10. Final narrow Low-cleanup review

The final narrow Opus review checked only F1-F7 and their immediate
dependencies against the exact accepted contract hash
`814fbb7915c6c1590f65ec4d6c34b165543528a76c14db5f570cc8e9710a954f`.
It also read pinned `src/mapnode.cpp` from the initialized Luanti reference.
The run used the same read-only Claude Code 2.1.228 / Opus `xhigh` profile with
only `Read,Grep,Glob`. The foreground wrapper completed with exit status zero,
exactly one final successful `type="result"`, empty stderr and no disallowed
call. The session took 443,486 ms over 36 turns.

| Item | SHA-256 |
|---|---|
| Prompt | `c51347b105294099df38ad8d7fc133696651df74267816c80d1e623d4ce06e04` |
| Complete JSONL | `2096c249619852fe345aa46ece23804099ce0cd9fe80c9c93989bd0ce7888321` |
| Extracted complete result | `913236788a351875b5a716ae3db8236a77e9febb97091e260ff3a6aac57b1305` |
| CLI version capture | `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157` |
| CLI help capture | `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6` |

Final verdict: **ACCEPT — 0 Critical / 0 High / 0 Medium / 4 Low**;
**Implementation GO: YES**.

The four residual Low observations are non-blocking and introduce no unresolved
semantic choice: the `access` row uses an unprefixed witness name while the
`gate` family uses its explicit `access_...` ID; malformed wallmounted values
6/7 are not known in any frozen template; `default/nodes.lua` remains covered
by construction-time CID/classification validation; and the measured allocator
ceiling remains authoritative if an implementation retains more per-seed state
than the conservative RSS projection assumes. They do not alter the accepted
contract bytes. Any optional later wording hardening requires its own reviewed
contract revision rather than a silent implementation invention.

## 11. Accepted package

The exact contract and design-authority hashes accepted for implementation are:

| File | SHA-256 |
|---|---|
| `AGENTS.md` | `b12f55731dfee4e050f97ea0c221415fdffd9cef7ded5b0b8b7a3b5c16c4a53b` |
| `docs/design/world.md` | `3d99b9e32d64a271bb641b23d6a181850b3fb28cc6ae95bdb1c9a84a77a9ffb6` |
| `docs/design/world_zones.md` | `f8bf8e8639d03d0932b70b9177f96bcb3e8c3a5288e65be61250233dd9e670ec` |
| `docs/research/wp40-simple-map-r6-decisions.md` | `af0860e5d03239f9074510bca2247d9d46eabdce54cb425f0cd833f708ffcc58` |
| `docs/research/wp40-simple-map-rebase-plan.md` | `cf5e37e3a26ef108701af0acfd2dbf42b7235cd30077eedbdfa93f31a2fa9eb8` |
| `docs/research/wp40-simple-map-r6-contract.md` | `814fbb7915c6c1590f65ec4d6c34b165543528a76c14db5f570cc8e9710a954f` |
| `docs/research/wp40-simple-map-r6-fable-task-d-report.md` | `9c5aaa99ace6b3b9ce9af3ac7d721f7d82f733b1002c2e6b4e5eae6348b3a0bb` |

No Lua, build, test, mapgen callback or world mutation was run for this
contract package. R6 remains disabled. Its next implementation step begins
from this accepted contract; the mandatory cost pilot remains an unconditional
stop before the 32-seed fleet.
