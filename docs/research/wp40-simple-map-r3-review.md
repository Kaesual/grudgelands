# WP40 Simple Map R3 Review

**Status:** accepted 2026-08-27. The pure vertical implementation and its
canonical exhaustive artifact passed independent review. R4 remains next; no
Luanti writer, materialized world or runtime integration is accepted here.

**Reviewed base:** `24bbc33ecb78f11c70bc07ba620d8d784588cd87`

**Reviewed candidate patch SHA-256:**
`34d3fc040f6ddf5c64fcdb980c9bd1871e710d433918f44ed5832fb6db833e57`

The exact `git status --porcelain` snapshot captured after the reviewed
candidate was complete and before this record/status closeout was added was:

```text
 M docs/research/wp40-simple-map-r3-contract.md
 M docs/research/wp40-simple-map-v1e-r3-preflight.tsv
 M mods/MAPGEN/grug_mapgen/wp40/height.lua
 M tools/wp40/README.md
 M tools/wp40/run_simple_map_r3.sh
 M tools/wp40/simple_map_r3_validate.lua
?? docs/research/wp40-simple-map-r3-artifact.tsv
```

The complete snapshot SHA-256 was
`071cb3d4bc37d82ee852e008560baa0e242a0928dd5bc629a56e44ef58a48aa3`.

The reviewed candidate comprised the R3 contract and harness documentation,
the height implementation, the exhaustive validator and runner, the refreshed
four-seed preflight, and the new canonical R3 artifact. This review record and
the mechanical status closeout were added only after the final green verdict.

## Independent review

A fresh Claude Opus context at `xhigh` effort reviewed the complete candidate
through the repository's read-only Claude CLI profile. It could use only
`Read`, `Grep` and `Glob`; shell, writes, delegation, MCP, browser and network
tools were unavailable. Claude Code was version `2.1.228`; the captured
`claude --help` SHA-256 was
`71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`.
Both successful review invocations exited zero with empty stderr.

The initial review returned **REJECTED**, with 0 Critical, 0 High, 0 Medium
and 3 Low findings:

1. three zero-valued ownership/overlap evidence fields were asserted rather
   than measured through the production composition paths;
2. the runner's `os.execute` sweep omitted six R3 tool-Lua files; and
3. rapid and cardinal-waterfall interpolation lacked an exhaustive formula
   gate.

Its immutable evidence hashes were:

- prompt:
  `5b395f3cb33b0503585fd84176f50cc0e703418bcc08af3bea6bfd48094de864`;
- JSONL:
  `e7beaf6424de10916d75f67269c7c95afdbe256efb494b6850e81501021bd4ab`;
  and
- extracted verdict:
  `e3b76d9b2012adf1cf0757e6cd88e07993711ab1e5e12f0d3c275a39fb74290a`.

One fix round replaced the literal evidence with exhaustive measurements,
extended the sandbox sweep to every gated R3 Lua file, and added independent
transition interpolation checks. The bed check deliberately excludes only
solid causeway, ford and anchor-platform surfaces whose final scalar is
already checked against their functional surface; it still checks beds under
bridges and tunnels.

The final rereview returned **ACCEPTED**, with 0 Critical, 0 High, 0 Medium
and 0 Low findings. It independently verified all three closures, the complete
artifact population and hashes, R2 authority reuse, route and operation
reconstruction, zero query-time hashing/lattice construction, deterministic
parallelism, Lua 5.1 coverage and the disabled R3 scope. Its immutable evidence
was:

- prompt:
  `15f284f69d5ce7aead719855622ee997eb34ddca182b7d4f6c8c8f2a084a0b64`;
- JSONL:
  `54080964c813c4376c22c4d9046cc3108aea471223f2f4166d35c2e409a8537a`;
- extracted verdict:
  `9ebfe667a692322ca6ba8b4ff90c933d6cec8a241bb2c3bb5c01921a80da9ad9`;
- CLI-version capture:
  `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157`;
  and
- empty stderr:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

## Authority closeout review

A second fresh Claude Opus context at `xhigh` effort reviewed only this durable
record and the mechanical R3 status switch. It used the same read-only tool
profile, Claude Code version and captured help bytes. The review exited zero
with empty stderr and returned **REJECTED**, with 0 Critical, 0 High, 0 Medium
and 1 Low finding: the candidate's exact `git status --porcelain` snapshot was
missing even though the reviewed patch hash was present. It independently
confirmed that every live status says R0-R3 accepted and R4 next, WP40 remains
open, the shipped count is unchanged, all evidence hashes and links are exact,
and no Luanti runtime/materialization claim was introduced.

Its immutable evidence hashes were:

- prompt:
  `303a802ffbad8fb6fb15f0bab9c30e86835834807642e7d31830c669cf1f2a74`;
- JSONL:
  `65bf2895d18f22ff4d3e86b92cb6d81b1f8a5e21f28da585ea15de58b9fca2a1`;
  and
- extracted verdict:
  `0274746db45d7e7882c1023839280998cafe1e656bf87406f3e0a6b6fca0066c`.

The one correction round added the exact snapshot and its SHA-256 above. The
review explicitly found no other issue and stated that this smallest Low fix
makes the closeout ready to commit. Project policy requires a focused rereview
only for Critical or High fixes, so no further review invocation was made.

## Bound evidence

- Accepted V1e R2 body/file SHA-256:
  `1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b` /
  `ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b`.
- Refreshed four-seed R3 preflight body/file SHA-256:
  `86846f9dd86750ccff122b39ee6432c7b9f6fb5ee3ad17dcc7e39b2befe9da56` /
  `fa646da36904db78f1a51d886a65da8115b00c1850bf4fc2da2bf6cba2db16fb`.
- Canonical full R3 artifact body/file SHA-256:
  `09b4ac762b9e6dc7d088d5f39c306d0dc80b9769d3bf8b6c35ea8a8a6bc282d2` /
  `c1090c5a9169c9fe449ad1b0f560b9a5b5b4a486c744445083ee05fbaa219e65`.
- Height/validator/runner SHA-256:
  `f69fcd006af40f2f473d592c412508c3d7043403b15c07bfedcb311fe6faee97` /
  `3478c5ac2e1161e8636197daaad7771914cf1e7adf152d497250356556c77ce4` /
  `ead8f997ef9062ba501697bc1f494f598299ec7a1c14f0ea5799399cf045f6fd`.
- Targeted LuaJIT/PUC 5.1 KAT digest and merged-file SHA-256:
  `c2fe576c24aed28bb3c416a2405de071b46b24889c713053c3ec99f35d388bca` /
  `2f7810f41d83c482412a2496de35e8071da448b099c40c747551131e48de17ce`.
- Artifact-regeneration immutable input-state SHA-256:
  `2c38101c0fdb01337212feec7d22599d91814bb9e5333a5381ab9e6508750c54`.
- Artifact-only regeneration log SHA-256:
  `43aa18a3f41e55d67a23a43011482dea05148f498ca4cd84b7fd130e1fae84c4`.

The artifact-only regeneration ran four independent LuaJIT preflight shards
and two independent full seed-0 artifact processes. Both full processes
produced the exact canonical body and file hashes above, and the preflight
reproduced byte-identically. At the user's direction, it did not duplicate the
LuaJIT/PUC parity leg: the same final implementation bytes had already passed
that targeted parity gate with the unchanged KAT digest recorded above.

## Calibration record

- Classification: non-trivial deterministic map-generation implementation,
  exhaustive evidence and acceptance update.
- Implementing/coordinating model: GPT-5.6 Sol.
- Reviewing model: Claude Opus at `xhigh` effort in a fresh read-only context.
- Initial Critical/High findings: 0/0.
- Initial full severity counts: 0 Critical / 0 High / 0 Medium / 3 Low.
- Implementation-review fix rounds: 1.
- Authority-closeout severity counts: 0 Critical / 0 High / 0 Medium / 1 Low.
- Authority-closeout fix rounds: 1.
- Final severity counts: 0 Critical / 0 High / 0 Medium / 0 Low.
- Observed package elapsed wall time: `unknown` (multi-session package).
- Final combined quick runner wall time: 1,188 seconds.

R3 is an accepted pure, engine-free vertical model and immutable payload. It
does not register callbacks, write VoxelManip data or materialize terrain,
water or structures. R4 is the next delivery stage.
