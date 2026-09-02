# WP33 / WP40 R7 Contract Candidate Review

Status: **CLEAN — 0 Critical / 0 High / 0 Medium / 0 Low**

Date: 2026-08-31 (Europe/Berlin)

Final reviewed commit:
`acf16c156416ad47df70c8ff3278211fcbd3978c`

Reviewed files:

- `docs/research/wp33-gathering-contract-candidate.md` — 547 lines,
  SHA-256
  `1e5b32cff812768f1ae92df31a935bb80b340833d9fe63f4329b97e963374ef1`;
- `docs/research/wp40-r7-native-contract-candidate.md` — 691 lines,
  SHA-256
  `7a357b64db4aae2fddf8cc3491ced4cad19815b4a15b09796d2cf5f330f901b8`.

The user ratified every recommended WP33 decision D1--D6 on 2026-08-31. The
follow-on authoritative fold records those decisions in design and backlog;
this review establishes that the detailed technical contracts presented for
ratification were internally coherent. It does not implement R7.

## 1. Independence and method

This was a non-trivial contract review under
`docs/process/wp-workflow.md` and `docs/process/agent-model-policy.md`.
Independent reviewers did not author either candidate or any correction. They
reviewed the actual repository sources, accepted R5/R6 contracts and artifacts,
authoritative design and backlog, current mod registrations/dependencies and
the pinned Luanti engine. Ignored coordinator state under `.claude/`, `.codex/`,
`.kilo/` and `tools/wp40/results/` was excluded from project authority.

All review passes were read-only. No reviewer edited a repository file, ran a
build or test, or claimed runtime evidence. The final reviewed checkout had no
tracked modification; `git status --porcelain` contained only `?? .codex/`, the
explicitly excluded local worktree container.

The first two review passes used Claude Opus before the user's later instruction
to conserve the remaining weekly Opus credits. All subsequent review and the
final acceptance gate used a fresh GPT-5.6 Sol reviewer as explicitly directed
by the user. No Opus call was started after that instruction.

## 2. Review provenance

### 2.1 Full Opus hard-lens review

- Reviewed commit: `e5def747c1f2315d549aa90f573b9c42826525da`.
- Model/effort: Claude Opus 5, `xhigh`.
- CLI: `2.1.228 (Claude Code)`.
- CLI help SHA-256:
  `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`.
- Prompt SHA-256:
  `690f98971cb7aa118afec0ebb87b5f622317e83b49dd0629bc106fb5c73809df`.
- JSONL SHA-256:
  `be2f6e1fb02d8225760dc644e6737082b4399ab670d7ecd147be722af6620173`.
- stderr SHA-256:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
  (empty).
- Exit/result: status 0, exactly one final `type="result"`, subtype
  `success`, no permission denial.
- Verdict: **NOT CLEAN — 1 Critical / 3 High / 3 Medium / 4 Low**.

Verified clean in this pass were the zero-Lua-biome native fallback, cave
liquid and dungeon fallbacks, complete disposition of 20 legacy biomes, 22
scatter ores and 47 engine decorations, the dirt-blob unrestricted fallback
trap, six retained native ore records, the P9G settlement seam, all six R6
Cultural registrations, the 12/8/6 source population, Alchemist mapping,
parity formula, query/dependency direction and interpreter schedule.

### 2.2 Focused Opus re-review

- Reviewed commit: `fa75c87881d42dd68efd3df6abfd780dad0b55dc`.
- Model/effort: Claude Opus 5, `xhigh`.
- CLI: `2.1.228 (Claude Code)`.
- CLI help SHA-256:
  `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`.
- Prompt SHA-256:
  `739f602d123bc62e400ee6a5582bd796da9cf10d152784f8dfb4c09d316bf10d`.
- JSONL SHA-256:
  `f7ff44f6ae64b99d1941802a09ba379b3a1cfeb03cd7c0abaa4f18f98b6ef475`.
- stderr SHA-256:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
  (empty).
- Exit/result: status 0, exactly one final `type="result"`, subtype
  `success`, no permission denial.
- Verdict: **NOT CLEAN — 1 Critical / 0 High / 1 Medium / 3 Low**.

This pass confirmed the capability-8 solution itself, binary32 NoiseParams
readback, `open_sea_at(position)`, the 26-row manifest, dependency direction,
root/support convention, Oak log, D1--D6 boundary and WP29 obligation. It found
that mixing twelve P9G node names into R6's ASCII content table would renumber
later refs and change `aux`, runs, checksums and artifact keys.

### 2.3 Fresh GPT-5.6 Sol independent review

- Reviewed commit: `f5324a60947f968bf7bc755464a29dfad5d2982e`.
- Model/effort: GPT-5.6 Sol, `xhigh`.
- Execution: fresh independent in-session reviewer
  `/root/r7_contract_sol_review`; no inherited implementation context and no
  repository writes.
- Verdict: **NOT CLEAN — 0 Critical / 1 High / 1 Medium / 0 Low**.

This pass confirmed that the separate P9G suffix was technically viable, then
found the remaining predecessor distinction: accepted R6 evidence has 77
ASCII content rows and uses `grug_nodes:bone_pile` at ref 68/mask 24 as the
synthetic compatible target for all six Cultural fixtures. The six real
`grug_gathering:*` Cultural targets necessarily create a different production
content table even before P9G. It also found that dead clay/brick and
silver-sandstone families lacked a durable backlog owner.

### 2.4 Focused GPT-5.6 Sol acceptance re-review

- Reviewed commit: `acf16c156416ad47df70c8ff3278211fcbd3978c`.
- Model/effort: GPT-5.6 Sol, `xhigh`.
- Reviewer: the same still-independent reviewer as Section 2.3, used for the
  required focused re-review of its High fix.
- Verdict: **CLEAN — 0 Critical / 0 High / 0 Medium / 0 Low**.

The reviewer re-read both corrected candidates completely and verified the
83-row production-R6 table, six real validator digests, normal capability-16
Cultural resolver, separate capability-8 P9G suffix, both projections,
registration order and WP28 assignment against the actual code and artifacts.

## 3. Finding resolution

| Finding | Resolution in final candidate | Final status |
|---|---|---|
| New role bit 32 exceeded R6's 1..31 bound | P9G uses compatible write-capability 8 while retaining distinct opcode/class/policy/schema identity. | Resolved |
| Adding P9G names would renumber R6 refs | P9G uses separate `grug_wp40_r7_p9g_content_v1`, local refs 1..12 and successor refs `N+1..N+12`; neither resolver accepts the other namespace. | Resolved |
| Six real Cultural nodes differ from synthetic R6 evidence | The 77-row accepted evidence artifact remains immutable; R7 authenticates an explicit 83-row production-R6 table containing the six real targets and no longer claims raw table byte identity. | Resolved |
| Production/evidence equivalence was underspecified | Stage A removes P9G byte-for-byte against the 83-row production run. Stage B maps by name, restricts six target substitutions to Cultural opcode/feature, maps them to evidence `bone_pile`, and rederives refs, CIDs, aux, runs, checksums and affected evidence before comparing the accepted artifact. | Resolved |
| New P9G opcode fell through existing class/policy defaults | The contract explicitly requires P9G-only opcode-to-class/policy branches and proves no change for existing opcodes. | Resolved |
| Noise `persist=0.6` compared as a Lua binary64 literal | Readback comparison uses exact binary32 normalization; canonical lexical bytes remain `0.6`. | Resolved |
| `open_sea_at` used the wrong argument shape | Adapter keeps `open_sea_at(position)` and delegates `position.x/position.z`. | Resolved |
| Marshbloom recommendation failed per-bracket parity and misstated authority | D2 names the current four `W` zones, recommends an explicit Mournfen-to-Ossuary amendment for a paired 21--30 bracket, and states the exact consequence of retaining the existing roster. | Resolved |
| Manifest identities differed across candidates | R7 authenticates one 26-row WP33 catalog digest, the six real Cultural digests, 83-row production-R6 content, twelve-row P9G content and P9G delta separately. | Resolved |
| `grug_mapgen` could load before `grug_gathering` | Required dependency and acyclic inverse constraints are explicit; target-owner registration order and existing-CID preservation are gates. | Resolved |
| P9G root/support conventions differed | Both documents use root `(x,surface_y+1,z)`, cell `(0,0,0)`, exact P7 air predecessor, settled in-owner support and analytic adjacent-lower-owner support. | Resolved |
| Oak reuse omitted `deep_forest_apple_log` | Added to the Oak feature set. | Resolved |
| GO lists differed | R7 references exact WP33 decisions D1--D6 and marks D6 as a one-cell placement blocker. | Resolved |
| Gravel rationale and dead recipe consequences were inaccurate/incomplete | Rationale now distinguishes retained gravel from optional stone-compatible silver sand; ratification must assign clay/brick and silver-sandstone removal or replacement to WP28. WP26 remains Universalbars-only. | Resolved |
| Axe/shovel tier authority had no durable owner | Ratification must amend WP29 to own `grug_axe_tier` and `grug_shovel_tier` before R7 GO. | Resolved |

## 4. Final verified contract boundaries

The final clean review verified:

1. zero Lua biomes is a valid native-v7 substrate closure with built-in biome
   0, cave-liquid and dungeon fallbacks;
2. the native allowlist is exactly one gravel blob plus five T2--T6 strata,
   with all other legacy blobs/scatters/decorations closed and the dirt-blob
   trap prevented;
3. the six retained NoiseParams are complete, available in main and emerge,
   and compared using satisfiable binary32-normalized values;
4. one R7 writer performs R6 P2--P9, then P9G, then shared run/replay/VM commit;
5. accepted 77-row R6 evidence, 83-row production-R6 content and twelve-row
   P9G content are distinct authenticated identities with closed projections;
6. the complete WP33 population remains exactly 12 new P9G + 8 reused R6 + 6
   Cultural rows;
7. root ownership, conditional support authority, non-overwrite/no-retry and
   P9G opcode/class/policy isolation are implementable in the existing private
   arrays;
8. manifest, dependency, CID/ref ordering, public query, protection and
   Alchemist seams are fail-closed and acyclic; and
9. LuaJIT owns exhaustive/fleet work, PUC 5.1 owns syntax/static checks and one
   final paired micro-KAT, with the workstation-wide seven-process cap.

## 5. Calibration record

- Classification: non-trivial contract/acceptance authority.
- Implementing models: GPT-5.6 Sol candidate agents and GPT-5.6 Sol
  coordinator integration/fixes.
- Reviewing models: Claude Opus 5 (`xhigh`) for the initial full and first
  focused reviews; fresh GPT-5.6 Sol (`xhigh`) for the final independent and
  focused acceptance reviews, following the user's credit-conservation
  instruction.
- Initial Critical/High count: 1 Critical / 3 High.
- Fix rounds: 3.
- Observed elapsed wall time: unknown.
- Final verdict: CLEAN, 0/0/0/0.

No Lua process, build or test was run for this documentation-only contract
package. The runtime and population commands remain future R7 implementation
gates, not evidence claimed by this review.
