# Round 10 final v3 artifact review

Date: 2026-09-20  
Reviewer: independent native Sol review (`/root/playtest_professions`)  
Source: `8dd1c8e463a13ccc356cdade123875471b398707`  
Scope: immutable runtime/static artifacts only; no Lua interpreter or engine process was run

## Verdict

**CONDITIONAL CLEAN for the reviewed runtime and static semantics. This is not an overall final-gate PASS.**

The six capital engine processes, the four six-start phases, and the static source checks are clean for the source above. The capital wrapper exits remain `1` because seven frozen historical overlay comparisons are unresolved: every capital's avenue plus Highcourt's rampart. The four published gate digests, four published corner digests, and the other three published rampart digests match. Those seven historical deltas require the separate attribution already in progress. The final PUC/LuaJIT parity pair has not been run for this source and remains a separate final gate.

## Machine extraction

The capital facts below were parsed afresh from each v3 `server.log`, `probe.txt`, runner log, service TSV, and overlay-delta TSV. They were not copied from an earlier review table.

- `final-v3-capital-extraction.tsv`: SHA-256 `ed3dc5cdfc3fc38fc1eb352c18ce46b60ff8a00ee31c7584a5d07d3838cede14`
- `final-v3-six-start-extraction.tsv`: SHA-256 `d0dc73ce734fd9f7e7af7414222a2f99ba0b59d4b2fb7af96fb6ea11a328fe83`
- Sidecar `.sha256` files accompany both artifacts.

| Capital | Completed | Engine/errors | Services | Displays | Gates | Matching frozen overlays | Unresolved historical overlays |
|---|---:|---|---|---:|---:|---|---|
| Dur Brannoc | 120/120 | 0 / 0 | PASS, 23 rows | 7 | 4 | rampart, corner, gate | avenue |
| Gor Drazhak | 74/74 | 0 / 0 | PASS, 23 rows | 7 | 4 | rampart, corner, gate | avenue |
| Highcourt | 105/105 | 0 / 0 | PASS, 23 rows | 7 | 4 | corner, gate | avenue, rampart |
| Kezamba | 78/78 | 0 / 0 | PASS, 23 rows | 7 | 4 | none published beyond avenue | avenue |
| Lethariel | 112/112 | 0 / 0 | PASS, 23 rows | 7 | **3** | none published beyond avenue | avenue |
| Nhal Veyr | 91/91 | 0 / 0 | PASS, 23 rows | 7 | 4 | rampart, corner, gate | avenue |

For every capital, both error counters are zero; summed `ignored`, `unheld`, `emerge_trouble`, and retry counts are zero. The service witness reports 8 plots, 7 stations, 8 profession trainers, 1 Riding trainer, 4 mount displays, and 3 gear displays. Precinct status is PASS. The Alchemy witness learned the profession, brewed 10 healing potions, and observed profession level 2. The runner-level engine subprocess tuple is `exit=0 errors=0 complete=1` in all six cases. The outer wrapper exits are therefore kept distinct from the successful engine process: they are `1` solely because the historical overlay oracle refuses the seven changed labels.

## Six-start evidence

Forward and reverse cold starts and their same-world disk reloads all have exit status zero and empty `errors.log` files. All four published TSVs canonicalize to digest `27ab0ba785073e61c6a8f83249f5da08e675cdb1066dbe983347063acddcc96f`.

Forward cold generated 3 blocks with 92 mapgen callbacks; reverse cold generated 5 with 92 callbacks. Both disk reloads loaded 5,500 blocks and invoked zero mapgen callbacks. The distinct forward/reverse sample and snapshot digests are recorded in the extraction TSV; agreement is asserted at the canonical result layer rather than by pretending those order-dependent inputs are identical.

The forward and reverse harness manifests bind the profile scripts to the exact bytes obtained from source `8dd1c8e...`; their listed hashes were independently reproduced with `git show`. The top-level harness also binds `tools/wp13/engine_cases.lua` to `8886fb6a...` and `tools/wp13/run_engine.sh` to `fef01866...`.

## Static evidence

`/tmp/grudgelands-r10-final-static-v3/result.json` binds candidate `8dd1c8e...` and reports 185 parsed Lua files, parser/sweep result 0, fresh-server result 0, and diff-check result 2. The input manifest verifies byte-for-byte.

The semantic inspection found no new source defect:

- Production `SETGLOBAL` entries are the declared mod globals (plus the existing `grug_items` quality seam); tool entries are fixture stubs.
- Sweeps 1 through 3 are empty. Sweep 4 hits are comments or string data. Sweep 5 contains tool-side process exits and the pre-existing vendored `minetest.is_protected` alias.
- The two diff-check findings are whitespace in preserved Markdown/evidence/log/TSV artifacts. The large profiler-log portion is captured engine output. No production Lua source is implicated, and the hashed evidence was correctly left byte-preserved.
- The fresh-server audit reports PASS.

## Remaining gates

1. Attribute and accept or correct the six avenue deltas and Highcourt rampart delta against the actual phase change. Until that proof exists, the capital suite is not an overall PASS.
2. Run the one final compact PUC 5.1/LuaJIT parity pair on the eventual immutable final source. No such final PUC result exists for `8dd1c8e...` in this review.

