# Independent Round 10 final evidence review

Date: 2026-09-20  
Reviewer: native Sol (`/root/playtest_professions`)  
Final source: `35432bdf232e88a6d633e861b84571fc3411e404`  
Runtime production source: `8dd1c8e463a13ccc356cdade123875471b398707`

## Verdict

**CLEAN — the immutable final evidence gates are internally consistent and bind the same production bytes.** Final GUI playtesting remains the user gate and is outside this evidence verdict.

`35432bdf...` changes only evidence, review documents, attribution helpers and the reviewed current capital oracle relative to `8dd1c8e...`; there is no diff under `mods/`, `game.conf`, `minetest.conf` or `settingtypes.txt`. The six-capital and six-start engine witnesses therefore exercised the same production game bytes covered by the final parity pair.

## Final compact interpreter pair

- The frozen snapshot identifies candidate `35432bdf232e88a6d633e861b84571fc3411e404` and records the reference pins.
- `inputs.sha256` and `input-paths.txt` each contain exactly 7,888 resolved entries. `inputs-check.txt` confirms every entry after both processes; SHA-256 `c1a4d0543fc8b777d772cabf04c4636f472e2897f4172dd3d608cd6ee00e93da`.
- The PUC 5.1 and LuaJIT result TSVs are each 80,495 bytes, are byte-identical, and share SHA-256 `7a45a740503855b654015428ca801ecee1fa3a874b4ae33cb60f5cfba1fe3579`.
- The LuaJIT WP13 pre-step reports PASS. Its TSV SHA-256 is `6ef56940d7bc3959a90e13098a44194918638a76035ca9cc03604ed6adb0ce7b`.
- Interpreter identities are bound as PUC `lua51` SHA-256 `a1a427f3...` and `/usr/bin/luajit` SHA-256 `4fd1f507...`.
- No duplicate interpreter or engine run was performed by this reviewer.

## Static and helper coverage

The reviewed v3 static artifact covers 185 Lua files with parser/sweeps clean and a clean fresh-server audit. Its two diff-check findings are preserved documentation/evidence/log whitespace and do not touch production Lua.

The later attribution commit adds two Lua helpers outside that 185-file snapshot. I compiled both with the repository's plain Lua 5.1 compiler and inspected their disassembly. Neither contains `SETGLOBAL`:

- `project_mask.lua` disassembly SHA-256 `245f669ec990fc2015db24f1f9b29dde1026c226571b1e3d02cac77717724c3e`
- `height_columns.lua` disassembly SHA-256 `074b5ffe2707ac3f4f914ea666ac644b207edf629febf7ef3ea704426274ce15`

The committed helper-static receipt independently records parser PASS and all five sweeps without hits.

## Engine and geometry composition

- Six capital engine subprocesses completed with exit 0, zero errors, exact requested/completed owner counts, zero ignored/unheld/emerge/retry sums, all service/precinct/Alchemy witnesses passing, 23 service rows and seven displays per capital. The machine-extracted completion counts are Dur Brannoc 120, Gor Drazhak 74, Highcourt 105, Kezamba 78, Lethariel 112 and Nhal Veyr 91; Lethariel has three authored gates, each other capital four.
- The independent 18-region attribution review is CLEAN: seven changed historical regions are fully explained coordinate-by-coordinate, eleven regions match, and zero coordinates remain unexplained. Manifest SHA-256 is `8659fa48b5758133a49029a3b7865651e099166525703e859556c0d96a1e9f37`; summary SHA-256 is `66df371f1018a2f948ea145a4373eb348eb0f28bf7652552b74cbdb5121bf08e`.
- The reviewed current baseline contains all 18 current values, changes exactly the six avenues plus Highcourt rampart, preserves the historical oracle, and retains fail-closed behavior. The unchanged v3 readbacks match it 18/18; an engine rerun is neither claimed nor needed for this oracle-only metadata update.
- Forward/reverse cold and same-world disk reload provide four clean six-start phases. All four canonicalize to `27ab0ba785073e61c6a8f83249f5da08e675cdb1066dbe983347063acddcc96f`; exit statuses and error logs are clean.

## Calibration

- Findings in this final evidence pass: **0 High / 0 Medium / 0 Low**.
- Fix rounds requested in this pass: **0**.
- Earlier capital geometry condition: closed by the independently reviewed attribution and 18/18 current-baseline validation.
- Remaining non-automated gate: user GUI playtest.

