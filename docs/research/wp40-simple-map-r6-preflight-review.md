# WP40 Simple Map R6 Preflight Review

Status: **ACCEPT** for a preparatory, implementation-NO-GO documentation
commit only
Review date: 2026-08-29 (Europe/Berlin)
Branch: `wp40-simple-map-r6`
Reviewed base commit: `e6fe00a4fdf52ad2c10e02128d8b367fda73f662`

## 1. Scope and classification

This was classified as non-trivial before review because it changes design
choice presentation, process gates, evidence authority and pinned provenance.
It contains no Lua, build, test, callback or world mutation. The reviewed
worktree state was two modified tracked files (`BACKLOG.md`, `README.md`) and
the twelve new files listed in the manifest below. The review record itself is
a derived post-review provenance file and adds no R6 contract decision.

The canonical reviewed-byte manifest is the following ordered
`sha256sum` output. SHA-256 of these fourteen manifest lines, including their
two-space separator and trailing newlines, is
`318d4f685ce0ddcb56b7b145e84b67f291dfe9e96f6046b24fab68c5af6a94f1`.

| Path | SHA-256 |
|---|---|
| `BACKLOG.md` | `cbc8b947369b96eb67c8709973f7105ef0120375e4069722e82a1c6ef57a8d71` |
| `README.md` | `d742bcf7651311f475b2f1015c617c7ad16eabeb92c131f7c1c3f30c6226ec10` |
| `TODO-design-wp40-r6-contract.md` | `6762bec749310fe92af58379f220a1261e8c5661e996a3e42c99fd15c834b1a0` |
| `docs/research/wp40-simple-map-r5-fable-task-c-report.md` | `5df5c7b8bc12b0f0d6c555d26861ae7602f91daef331683031e3b011ed8a6d67` |
| `docs/research/wp40-simple-map-r6-cultural-opportunities.tsv` | `a398970fda8ecf0324ba807218aff1d2632910d85be6e68a4f4afa4e00a7967e` |
| `docs/research/wp40-simple-map-r6-decoration-draft.tsv` | `87167c0ad64e347387a36465270b5e87f215d6fe04f13eff2e68fa01c9037b6b` |
| `docs/research/wp40-simple-map-r6-fable-task-a-report.md` | `792e8088210d91bf992466b8f95e907283917cecd0663ca0b9b13d75f92c2ba6` |
| `docs/research/wp40-simple-map-r6-preflight.md` | `080f33293b52e5b2c274049907a033b7e11a9ca3c913a3e1f6fd9a11452043a3` |
| `docs/research/wp40-simple-map-r6-resource-density.tsv` | `31e616e0686d9099777de2304b6c21ba5294393444ec7ab1ef1cac1360443394` |
| `docs/research/wp40-simple-map-r6-seed-corpus.tsv` | `c055c7910e97f6062111f33f15365c5d85694c51c0b474b0ffa378ba14e65c37` |
| `docs/research/wp40-simple-map-r6-shore-bed.tsv` | `e12b30e5d43f71108e6d21894b1fac3e2762696e90b745f3e849cd86f4b31d83` |
| `docs/research/wp40-simple-map-r6-surface-content.tsv` | `085e3a3e3cefb8ea36bac101e8f801175cd5e8f2b32f9bad280eefe45412e5e4` |
| `docs/research/wp44-fable-task-b-report.md` | `1846a73d315926b970e3053d520495f0b05d8083437c8ac56f8956679fb6e8be` |
| `docs/research/wp44-income-ledger-preflight.md` | `793fb2c08629ff14d6502a8e4d7995284a81cf2f1da7523bf6dcb3ec5c21819e` |

The three preserved Fable reports are byte-identical to their final temporary
reports. Their identities are therefore both content hashes and preservation
checks. Prompt and JSONL identities remain in the corresponding preflight
records.

## 2. Independent review execution

All six review contexts were fresh `claude-opus-5` contexts requested through
the `opus` alias at `xhigh` effort. They used only `Read`, `Grep` and `Glob`,
with shell, writes, delegation, network and MCP additions denied. Every run
used the exact R6 worktree, returned process exit 0, empty stderr, and a final
`type="result"`, `subtype="success"`, `is_error=false` record.

Claude Code version was `2.1.228`; captured version-file SHA-256
`6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157`
and help-file SHA-256
`71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`
were identical in every run. Result hashes below are SHA-256 of the exact
UTF-8 `.result` string extracted without an added newline.

| Pass | Prompt SHA-256 | JSONL SHA-256 | Result SHA-256 | Verdict and counts | Duration |
|---|---|---|---|---|---:|
| Full review | `de26b9945378a3664651a781e17096228c162ec8ff4e8012f4268a3d2342cd33` | `727009f4358100a51d796f43d71dafab71981d12b0a089faf60bb4ad8378740f` | `6c073e115018d041a14ffee18cefaf10a77e05a38a1393882adf97e25c0aecec` | REJECT, 1C/1H/3M/9L | 1,104,014 ms |
| Correction 1 | `3d71a897cc22b377e9db824f51bc4122b0124bc4a459e7e073942a943e1ec00a` | `38f216f119939deeec82c170b369761b5ceb5b4f6f2bee2902f3469b1840ad44` | `e45ea57f11542dd2a945fd8d0dca4414b09383d6cd867368831ddc6e012a988b` | REJECT, 0C/0H/2M/9L | 994,821 ms |
| Correction 2 | `6197af24f5f1620822723d3fde5c09c34d465b07d28e73602f07de2439006938` | `6e3e33bfb6a1380b38d9991f5a7ab81b0998af65cbc433de93562b36f82f9ca0` | `c11653262991732918d88a38bfa590a799a7570d72cf178601d80180a026b46b` | REJECT, 0C/0H/1M/7L | 639,417 ms |
| Correction 3 | `de84ac744a2ecbacb69897035c8ec843bfdd88cd630b4d19d185d312e4508629` | `b7c7201c5dc044f95d8b1b25f922dbab72649ea1697fef802d89638fa685458e` | `c4936fb536c21925d4ad64d069a94dbbc47e9f81df256dd3c45dcef7ac936087` | ACCEPT, 0C/0H/0M/2L | 491,948 ms |
| Two-Low check | `ddb323d921d3556a31ae7b754cf4ba9a3130d282ec93d19ed8fa57ed354609a8` | `b4fde6236e1f4105cfc7b8b0ad65164ac5f482a0348b872f6546efe94e34a4c7` | `4837196815be9b28d185684f736b2211b2d32237aa2ed9f07e5428d89177f1f6` | ACCEPT, 0C/0H/0M/1L | 238,551 ms |
| Final clarity check | `5a2925fbae6a2341add379863d26567fcb84b2f413adda627395e3fae603ae19` | `70269b009b95e6fa38c35cf2be745e02650181b0b89d726f74798c553e3c9cde` | `e4ee2704e744eaaa4b11ae7376366a92b5a30ada1f3c9dd653d65dc2044abb1e` | ACCEPT, 0C/0H/0M/0L | 87,691 ms |

Total observed reviewer duration was 3,556,442 ms (59 min 16.442 s). The
reviewer remained independent of authorship and implementation throughout.

## 3. Finding disposition

The initial Critical was truncated external provenance; all eight exact
64-hex identities are now recorded. The initial High was a unit-incoherent
G1/G2-plus-metal-camp parity recommendation; the TODO now separates natural
scope, camp quantity, parity unit and comparison baseline and recommends the
strict exact pairwise gate `20 * hi <= 21 * lo`.

Successive Medium findings closed hidden cultural-density/allowlist authority,
the looser mean-relative interpretation, and the fact that both the Orc and
Troll D1 allowlists require explicit pending corrections. Lower findings
closed surface/decor authority, missing target deferrals, reservation/P7
wording, README/BACKLOG discoverability, Fable-report preservation,
interpreter supersession, the deep-budget cap, WP33/R7 ordering, seed-corpus
supersession, ledger conditionals and decision counting. The final clarity
check verified that all three section-A options share the explicitly pending
surface projection. Final accepted counts are **0C/0H/0M/0L**.

## 4. Coordinator verification and calibration

Coordinator checks after the final edit:

- `git diff --check`: pass;
- all six TSVs: every row has its header's field count;
- surface TSV: 17 rows and 12 fields, with the recorded SHA-256;
- three preserved Fable report hashes match their source result files;
- no build, automated test, Lua process or runtime test was run.

Calibration record: implementing/coordinating model GPT-5.6 Sol; independent
review model Claude Opus; initial Critical/High count 1/1; final
Critical/High count 0/0; five correction-review rounds after the full review;
coordinator elapsed wall time unknown; reviewer duration recorded above.

## 5. Acceptance boundary

This acceptance permits committing and pushing only the consolidated
preflight, preserved research and open decision packet. It is **not** an R6
contract, makes no choice in the TODO, authorizes no implementation, and does
not change R5's disabled runtime state. R6 implementation remains blocked
until all ten choices in the five TODO sections are decided, folded into the
design, and the exact successor contract passes its own independent review.
