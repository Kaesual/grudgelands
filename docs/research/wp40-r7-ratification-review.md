# WP40 R7 Ratification Fold Review

Status: **CLEAN -- 0 Critical / 0 High / 0 Medium / 0 Low**

Date: 2026-08-31 (Europe/Berlin)

Final reviewed commit:
`40717aa4d9f2da57ef85698595b86f113f099636`

The review covers the authoritative fold of the user's accepted WP33 decisions
D1--D6, the WP28/WP29/WP33/WP40 backlog consequences, the R7 execution
contract, derived README/ROADMAP status and the ratified status transition of
the two detailed contract candidates. It does not review production code or
claim R7 implementation, build, test or runtime evidence.

## 1. Independence and method

The reviewer was GPT-5.6 Sol at the session's high reasoning setting, working
as the independent read-only agent `/root/r7_contract_sol_review`. It had not
authored the ratification fold or its correction commit. The model selection
followed the user's instruction to conserve Opus credits and use GPT-5.6 Sol
for further review in this session.

The full pass checked the exact aggregate diff from
`2139b5e7753cdf269a288548e52818c647b3f29e` through
`0f68428f122a3353dc6ac32dea8bfaea77d25657` against:

- the detailed WP33 and R7 candidates previously accepted clean at
  `acf16c156416ad47df70c8ff3278211fcbd3978c`;
- accepted R6 content/resolver/settlement/evidence authority;
- the authoritative design, backlog, roadmap and README layers;
- the R7 cutover preflight and actual live consumer/mod graph; and
- the repository's interpreter, pilot, review and R7/R8 workflow rules.

No reviewer changed a file or ran a build, Lua process, test or runtime gate.

## 2. Full-review verdict at `0f68428`

Verdict: **NOT CLEAN -- 0 Critical / 1 High / 3 Medium / 0 Low**.

| Severity | Finding | Correction in `40717aa` |
|---|---|---|
| High | Three older `biomes_mobs.md` passages still restricted Stormkelp to beach/sand, contradicting the ratified cardinal dry-shore predicate and emptying Skyglass supply. | Stormkelp now uses the exact cross-biome dry-shore rule; beach/sand remains specific to Rock Salt. |
| Medium | `items_crafting.md` permitted a concentrated Cultural source "in or beneath" a frontier although the accepted registration is one surface cell at `(0,1,0)`. | The authoritative wording now requires a concentrated surface source. |
| Medium | BACKLOG modeled WP33 as depending on WP40 R7 while R7 depended on WP33, and presented WP29 tier groups as an R7 completion blocker. | WP33 depends only on WP40 R6 and WP43; R7 consumes the accepted WP33 manifest; WP29 remains the durable harvest owner but not a placement/R7 blocker. |
| Medium | The execution contract told R7 to migrate map/mount/housing/travel consumers that do not exist yet. | R7 migrates existing consumers and only publishes the stable API for those future WPs. |

The same pass explicitly found the following seams clean:

1. accepted 77-row R6 evidence, 83-row production-R6 content and separate
   twelve-row P9G content with successor refs 84..95;
2. Stage A/B normalization, Cultural substitutions, aux/run/replay/checksum
   rederivation and CID registration order;
3. the native allowlist, six NoiseParams and one-writer boundary;
4. WP28 ownership and removal of any WP26 fallback;
5. the R7/R8, pilot-approval, LuaJIT/PUC and independent-review boundaries; and
6. ROADMAP/README and status/hash provenance.

## 3. Focused re-review at `40717aa`

The same still-independent reviewer inspected only its one High and three
Medium corrections against the surrounding contract. Final verdict:
**CLEAN -- 0 Critical / 0 High / 0 Medium / 0 Low**.

The re-review confirmed all four corrections and found no regression within
their scope. No further correction round was required.

## 4. Final reviewed hashes

| File | SHA-256 at `40717aa` |
|---|---|
| `BACKLOG.md` | `f23248bf83ea7b1d6daeebbcdba1884347c21383cb7496d695ff7d63dace93f2` |
| `ROADMAP.md` | `2f8bb36cc2dc6c19a3bc19d246ec6550869906079db8453a9b723cd11c77f153` |
| `README.md` | `b313b5a0e838cd936917d0f9a9aee367c329295ea4ea378e6bc3dbf5a4096400` |
| `docs/design/biomes_mobs.md` | `4a590da4dd8884a68656cd4cfe6409f9f72ddcced47aa3114b5fdb5dfe68db37` |
| `docs/design/items_crafting.md` | `404bf88f9c0b2d86b91e3969674c96ebd4a5c2646e5748a42567e87fbf77aca2` |
| `docs/design/world_zones.md` | `2a8cff38b7cdf32521e56eb6e057cb6b9daa1b348b85e95b0ec24a7418cdf55a` |
| `docs/research/wp33-gathering-cultural-preflight.md` | `6a32f3e6077e97c6d38d68e2ece840ff34b63a831290623cca0e7725f25bb846` |
| `docs/research/wp33-gathering-contract-candidate.md` | `0375a28f97b3932417436dfa3938340a5ffe05d09d2a5d7e879988b84b61f7ce` |
| `docs/research/wp33-r7-contract-candidate-review.md` | `530aa16bded6e42f94d6a88e1314f5c12a32ec8cab3653f3b0562f9008ff466d` |
| `docs/research/wp40-r7-native-contract-candidate.md` | `a390959fcd7a1437a94741988fd8890ea643bc3cb5c501c1e62bf4ce20646b68` |
| `docs/research/wp40-r7-implementation-contract.md` | `735580417171cc0cd596937d255d1d5706f15cfb98c2dc1c9172eb577e35b089` |
| `docs/research/wp40-simple-map-rebase-plan.md` | `6e14b65745f9cb6318e12de2ead57b61a09fef5c78b4bc0f5c874fde5f6184a2` |

## 5. Calibration record

- Classification: non-trivial contract ratification and execution-plan fold.
- Implementing model: GPT-5.6 Sol coordinator.
- Reviewing model: independent GPT-5.6 Sol.
- Initial Critical/High count: 0 Critical / 1 High.
- Fix rounds: 1.
- Final verdict: CLEAN, 0/0/0/0.

R7 is now contract-ready, not implemented. Its production files, offline
evidence, final micro-KAT pair and independent code review remain future R7
work; its real Luanti world, visual and performance gates remain R8.
