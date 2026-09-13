# R7 startup manifest repair — 2026-09-13

The first real GUI start after terrain-life polish failed on both fresh user
worlds (`test_mapgen` and `test_mapgen2`) at `r7_manifest.new`: the added
Gravewood node and two schematics changed the content graph while the live
constructor still required the old semantic digest, 19 templates and old
catalog/template/source projection hashes.

The earlier portable micro-KAT calculated current node semantics but assembled
its own receipt and called only `validate`. Its bounded runtime fixture also
stubbed the manifest constructor. Therefore the reported parity and earlier
clean reviews did not establish that the actual startup constructor accepted
the content. This follow-up closes that concrete coverage gap.

## Change

Update the six current production pins together: content semantics, template
count (21), R6 catalog, accepted content, decoded templates and their combined
source projection. The real engine supplied the diagnostic projection and
the independent real-source constructor test agrees. Every validation remains
active. No old-world reader, migration, alias or relaxed acceptance is added.

`manifest_constructor_kat.lua` uses actual registered node semantics, decoded
MTS through the production template adapter, catalogs, consumer payload and
calculated anchor roster, then calls `r7_manifest.new` and validates its receipt.
It also rejects altered semantics and a missing template. The normal quality
final runner now executes this LuaJIT-only regression before the compact
interpreter pair. The geometry constructor and FFI MTS decoder never run under
PUC; the portable receipt fixture retains its bounded validation purpose and
now carries the current projection values.

## Validation and review

Two disposable worlds under `/tmp` pass startup and a generated mapchunk with
Luanti 5.17.0 / LuaJIT: seeds `0` and `4655649881628627392`. The shipped game
files are byte-identical to the tested copies; a separate worldmod requests one
emerge area and shuts down after success. Both main-environment authority and
emerge-environment generation execute. This is an actual-engine regression,
not a GUI appearance or play-feel test. Existing unmatched-fuel-recipe warnings
remain outside this startup fix; both runs contain no ERROR lines.

Evidence: [engine logs, input hashes and static checks](wp40-startup-manifest-evidence/).
The diagnostic capture was made in a separate modified copy to report values;
passing smoke runs use unmodified production files with all checks enabled.

Classification: non-trivial startup integration regression. Coordinator owns
production; configured GPT-5.6 Sol owns the new test. Independent reviewer
configured GPT-5.6 Sol: initial 0 Critical / High / Medium / Low, clean;
fix rounds 0; elapsed unknown. Focused review of the normal-gate integration
also returned 0 Critical / High / Medium / Low.

The final gate passes the LuaJIT constructor test, then exactly one compact
PUC 5.1 process and the same fixture once under LuaJIT. The 219-line outputs
are byte-identical, SHA-256 `b08345fde4c238e1d497fb7d9d2034dc0d36be02cfe169be10ae421239bd0f23`. All bound inputs stayed unchanged.
The constructor receipt is `dc52427529d0d4a52b8fd5025895af962e84df04ff1b9d3c741ca1c818ddbe54`.
Parser, SETGLOBAL and five static sweeps pass; static matches are inspected
comments/strings or offline fixture hashing. No PUC population or GUI test
was run by the agent.

## User runtime check

The previously failing fresh worlds can be started again after synchronization;
they did not complete mapgen startup. Verify character creation reaches the
world and nearby terrain appears. No seed change or world cleanup is required.
