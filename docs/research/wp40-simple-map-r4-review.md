# WP40 Simple Map R4 Review

**Status:** accepted 2026-08-27. The first complete geography/policy payload
and its canonical exhaustive artifact passed independent review. R5 is next;
R4 remains disabled and no Luanti writer, materialized world or runtime
integration is accepted here.

**Reviewed base:** `3a7afc978733be0d16f04ad02073992a5beaea55`

**Reviewed 16-file manifest SHA-256:**
`f090f2da954f50ae83b74b5cf2664156da99b0bddb21659fa36d4cbdafd7ace0`

The exact `git status --porcelain` snapshot captured after the reviewed
candidate was complete and before this record/status closeout was added was:

```text
 M docs/design/world_zones.md
 M docs/research/mapgen-control.md
 M docs/research/wp40-simple-map-r4-contract.md
 M mods/MAPGEN/grug_mapgen/wp40/index128.lua
 M mods/MAPGEN/grug_mapgen/wp40/init.lua
 M tools/wp40/t1_foundation_test.lua
 M tools/wp40/t2_schema_core_test.lua
?? docs/research/wp40-simple-map-r4-artifact.tsv
?? mods/MAPGEN/grug_mapgen/wp40/zones.lua
?? tools/wp40/run_simple_map_r4.sh
?? tools/wp40/simple_map_r4_artifact.lua
?? tools/wp40/simple_map_r4_common.lua
?? tools/wp40/simple_map_r4_kat.lua
?? tools/wp40/simple_map_r4_offline.lua
?? tools/wp40/simple_map_r4_selftest.lua
?? tools/wp40/simple_map_r4_validate.lua
```

The complete snapshot SHA-256 was
`3e49e539793a072965ac436cd235da165e42a945d15f5ff711003d05fc4b87f9`.
The reviewed contract file SHA-256 was
`6f9763b97a230dc875e8b038e21c797b9f0f68d3e5dd86caedb4b67833c2063b`.
This review record and the mechanical status closeout were added only after
the final green verdict.

## Reviewed candidate

The immutable review manifest comprised:

- the R4 contract, the logical-biome design authority and its research
  clarification;
- the production `zones.lua`, `index128.lua` and disabled foundation loader;
- the common/offline/validator/artifact/KAT/selftest/runner toolchain;
- the two extended foundation/schema tests; and
- the canonical R4 artifact.

The implementation preserves the accepted R2 horizontal and R3 vertical
authorities. It publishes a private, still-disabled 38-zone payload with exact
scalar policy precedence, logical-biome palette selection, public anchors,
hard protection, compatibility adapters and bounded sparse route, hydrology
and footprint indexes. It registers no callback and writes no world data.

## Full-run evidence

The authoritative full run used the repository's seven-process cap and idle
scheduling. Two independent seven-shard LuaJIT fleets each scanned all
49,980,561 columns, merged canonically and produced byte-identical artifacts.
Four targeted seed shards were compared byte-for-byte between LuaJIT and PUC
5.1. Promotion occurred only after all gates and the immutable-input recheck.

- Canonical artifact body/file SHA-256:
  `bb19948d6bcb2c9976eddc6358955407f8b4a3c4cd54fb7dce1165e22ed8edca` /
  `23a05d2115fb6d3a1b286e09a17847793e23fc0a23817ade8ce8b812875d1b3c`.
- Targeted KAT body/file SHA-256:
  `72b9bd0e2d21cb82c4b1627031434eda1b83a2d8b8223fae22eb8f0e377ab5de` /
  `14463a99810351439fdf5d65a02436e367db69df1c2efebaeb8bc1b495a90b39`.
- Immutable input-state SHA-256 before and after:
  `7ab21a34a39c01b7b1fb244f46d4685c9fc5f4e3fdba45fdac50c70330109790`.
- Full-run log SHA-256:
  `9feeb509897753f52fbf5df5c5752b395f5df32bc0c6db83095e0c9faf59bbd5`.
- Full-run wall time: 3,766 seconds.

The body SHA was independently recomputed from the promoted file, and all 35
embedded `input_sha256` rows were independently matched against the checkout.
The accepted R2 and R3 artifact file SHA-256 values remained
`ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b`
and
`c1090c5a9169c9fe449ad1b0f560b9a5b5b4a486c744445083ee05fbaa219e65`.

## Logical-biome correction review

The first full fleet correctly rejected an invalid model assumption: authored
palette weights had been treated as guaranteed per-zone realized area shares.
The design and R4 contract now define them as exact positive partitions of the
unbiased roll domain 0..99. The exhaustive population still proves owner
palette membership, no foreign result and global coverage of all 16 ids, and
records deterministic per-zone counts and exact count/zone-total ratios. R4
neither rerolls nor quota-repairs results. Two legacy R2 share-audit metadata
fields remain byte-bound but are explicitly non-operative and unread by
production R4.

A fresh focused Claude Opus context at `xhigh` effort reviewed this correction
through the repository's read-only `Read,Grep,Glob` profile. It returned
**START**, with 0 Critical, 0 High, 0 Medium and one dispositioned Low requiring
this durable review record.

- Reviewed correction diff SHA-256:
  `96fdf4b7de206997e8fca7f062a98a55ef095c7b249648993bff4559df0f74c6`.
- Prompt SHA-256:
  `454fe102ecaab9484b06a7d56ae24186bb2826aced05bf5c8f9a6f3f11aa5b23`.
- JSONL SHA-256:
  `5254bd55c9ee094724eb462a019b5831dd316ad4f5f43365713ea04d642068ea`.
- Extracted verdict SHA-256:
  `b69ea262540c76e2e9bb4a0db63c7834791d1bc1dbf5f5628aa2beb1e0bb064a`.

## Independent implementation review

A second fresh Claude Opus context at `xhigh` effort reviewed the complete
candidate, canonical artifact and successful full-run log with the same
read-only tool profile. Shell, writes, delegation, MCP, browser and network
tools were unavailable. Claude Code was version `2.1.228`; the captured
`claude --help` SHA-256 was
`71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`.
The process exited zero with empty stderr and returned **ACCEPT**, with 0
Critical, 0 High, 0 Medium and 3 dispositioned Low findings.

- Prompt SHA-256:
  `78963ceae6f430545fcb072118a37139382397a6f478d4f0656c8367d8d5d0bb`.
- JSONL SHA-256:
  `6b5dc3de749206862e801ac99f9a164b5f337e9bb915bd7da92aa6eb00a695b1`.
- Extracted verdict SHA-256:
  `bd67757f881b3a2e1952214870f60b71ab3907022153edd26f99f23a0528f130`.
- CLI-version capture SHA-256:
  `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157`.
- Empty stderr SHA-256:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The three Low findings are explicitly dispositioned:

1. Two query-cost evidence fields are literals rather than independent
   instruments. No corresponding query path exists, and the exhaustive
   nearest metrics independently exclude a catalog fallback.
2. Five foundation/T2 negative-test dependencies are outside the 35-file
   artifact manifest. None participates in the private R4 payload, while the
   accepted golden tests bind their observable behavior. R5 should consider
   this when defining its own transitive test manifest.
3. One unused local `sorted_keys` helper has no execution path.

Changing an artifact-bound file only to remove these inert findings would
invalidate the reviewed bytes and require another full run without changing a
produced R4 value. They are retained as reviewed. R5/R7 planning also carries
the review observation that the complete 42-footprint construction proof needs
a measured engine world-load budget.

## Authority closeout review

A third fresh Claude Opus context at `xhigh` effort reviewed this durable
record and the mechanical R4 status closeout through the same read-only tool
profile. It exited zero with empty stderr and returned **REJECT**, with 0
Critical, 0 High, 1 Medium and 0 Low findings. It independently confirmed that
WP40 remains in progress and unshipped, the README shipped count and ROADMAP
checkbox are unchanged, R4 remains disabled, all artifact/review hashes and
links are accurate, all three implementation Lows are retained rather than
misrepresented as fixed, and R5 is named only as the next disabled stage.

The sole finding was a stale live status line in
`wp40-engineering-brief.md`: the document identified itself as current
engineering authority but still said “R4 is next.” The one correction round
advanced that line to R4 accepted / R5 next and added the R4 contract pointer;
it changed no reviewed implementation, artifact or §§1-14 contract semantics.
Project policy requires focused rereview for Critical or High fixes, so this
mechanical Medium correction does not trigger another invocation.

Closeout-review evidence:

- prompt SHA-256:
  `79668363394b1bd7759fb3fcc29f71d6f66bc3108fc13f7146474c6837522841`;
- JSONL SHA-256:
  `b69f5ad53e1419e87a062418fbee42032c80310b7fc62f76444417bdf1fed990`;
- extracted verdict SHA-256:
  `d2c5c020ebccb05e65c1b37b57e4d0d9b484769357ab7969c02a5885cc2369c8`;
- CLI-version capture SHA-256:
  `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157`;
- Claude Code version `2.1.228` and help SHA-256
  `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`;
  and
- empty stderr SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

## Calibration record

- Classification: non-trivial deterministic map-generation implementation,
  exhaustive evidence and acceptance update.
- Implementing/coordinating model: GPT-5.6 Sol with delegated implementation
  and audit lanes.
- Reviewing model: Claude Opus at `xhigh` effort in fresh read-only contexts.
- Initial/final Critical and High findings: 0/0.
- Final complete-review severity counts: 0 Critical / 0 High / 0 Medium / 3
  dispositioned Low.
- Final implementation-review fix rounds: 0.
- Authority-closeout severity counts: 0 Critical / 0 High / 1 Medium / 0
  Low.
- Authority-closeout fix rounds: 1.
- Observed package elapsed wall time: `unknown` (multi-session package).
- Canonical full runner wall time: 3,766 seconds.

R4 is an accepted, private geography/policy payload. It remains deliberately
disabled, registers no mapgen callback and does not materialize terrain,
water, structures or content. R5 is the next delivery stage.
