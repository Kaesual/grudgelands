# WP40 tree slice correction and real-engine performance follow-up

Status: independently accepted on `wp40-mapgen-profile-tree-fix`, 2026-09-13.
Baseline: `ddf4d6e67057d92852031ebb3e9688b31f5a5e59`.
Classification: non-trivial correctness and performance change.

## Authorized scope

The user reported missing trunk layers in freshly generated conifers and
authorized autonomous real-engine profiling followed by optimization on the
kaesual Rehearsal VM. Use disposable worlds and the existing Luanti 5.17.0
LuaJIT image; do not alter managed realms or Production. Browser/GUI acceptance
remains on the user's workstation. Existing malformed trees are not repaired
by a generator fix; no world reset is authorized by this package.

## Correctness contract

Native schematic placement (`reference_projects/luanti/src/mapgen/mg_schematic.cpp`,
`Schematic::blitToVManip`, lines 150–190) increments destination Y only for an
included schematic slice. R6 currently leaves rejected slices at their original
height, creating holes. Correct both the evidence and live decoration settlement
paths in `r6_settlement.lua`. Preserve `template_probability_v1`, all original
source coordinates used for probability hashes, rotation, node probabilities,
root selection, and conservative full-template collision/owner bounds. Whole
rejected slices compress subsequent included slices; individual rejected nodes
do not. Compute each slice decision once per candidate, shared across X/Z.
This section amends R6 contract section 8.3 with the native asset meaning.
Keep the frozen R6 contract file unchanged: its exact bytes are the historical
fixture identity, and current follow-up rules live here.

Required regression: deterministic middle-slice omission in a multi-layer
template produces contiguous output in both live and evidence paths. Require a
shipped pine asset witness with a rejected interior slice in both paths, checking
original source coordinates in probability trials and compressed destination Y.
No expectation that pre-fix tree
digests remain equal; distinguish the correctness baseline from later byte-
preserving performance changes. Preserve all historical evidence unchanged.

## Measurement and optimization contract

`tools/wp40/profile/` owns a disposable-snapshot harness. Measure native v7,
Grudgelands planning/writing, and end-to-end emerge separately. Test fresh
generation and disk loading after a clean restart of the same world, recording
emerge action counts. Add mixed loading/generation if the harness permits a
bounded meaningful comparison. Keep profiler artifact hashing and private evidence
capture out of timing intervals; all production probability, rotation and other
mapgen hashes remain unchanged inside planning/writing and end-to-end timings.
Freeze snapshot and engine identity for every result; report VM hardware,
interpreter, cache state, corpus and limitations. A native-only comparison is a
diagnostic control and never a playable alternate game.

Choose the optimization from the measured dominant cost. Preserve corrected
content, param2, lighting, liquid scheduling, placement order and one emerge
thread. First prefer omitted redundant work, cached immutable calculations and
buffer reuse. A larger transaction rewrite requires a focused brief and review
before implementation. Engine concurrency changes and a world-format redesign
are outside scope. Report absolute timings and before/after ratios without
claiming that headless timings establish browser latency.

## Verification and review

Read `docs/research/luanti-lua.md` interpreter strategy. Development and engine
runs use LuaJIT. Run at most one engine process on the 4-CPU/7-GiB Rehearsal VM;
independent workstation LuaJIT checks may run concurrently under the global
seven-process cap with idle CPU/I/O priority and separate output paths.
Every changed Lua file receives the PUC parser, SETGLOBAL inspection and all
five source sweeps (tool Lua explicitly included). Run bounded relevant R7/R8
regressions and corrected-output parity for optimizations. Frozen final bytes
receive one compact PUC-5.1 micro-KAT and the same LuaJIT fixture with identical
canonical output; no intermediate PUC runtime. Reviewers inspect that evidence.

Independent strong-agent review is required before merge; High/Critical fixes
receive focused re-review. Preserve calibration and review evidence here.
Update BACKLOG and README together if package status changes; do not mark all
of WP40 complete on this follow-up's evidence. After a clean review, merge to
main and sync the workstation game. Final user test: new pine forest, fresh
exploration, reconnect to the same area, and return while new terrain loads.

## Initial engine measurements

The original baseline was run on the local Rehearsal VM using the existing
rootless Luanti image
`afec763ab3efa150171f4a024b036145bab419cf9ee6921a3cd0c76432c1f780`:
Luanti 5.17.0, LuaJIT 2.1.1787165859, Release build. The VM has four CPUs and
7,424 MiB RAM. The disposable container was limited to 2.5 CPUs and 3 GiB,
with no network and only task scratch directories mounted. Managed services
remained running, so these are shared-VM observations, not isolated CPU
benchmarks. One engine and one emerge worker ran at a time.

The ten-owner seed-0 corpus generated ten chunks (125 mapblocks per chunk).
A clean process restart loaded all 1,250 blocks from disk with zero mapgen
callbacks and the same sampled node/param2 digest. Initial emerge latency
includes construction of the emerge Lua environment: the first disk request
took 4.55 s, whereas the following nine took approximately 4–5 ms each.

Selected original callback timings, seconds (one observation per owner):

| Owner | Planning | Writer | Combined callback |
|---|---:|---:|---:|
| Hearthpine centre | 0.373 | 0.208 | 0.581 |
| Hearthpine south | 0.257 | 0.286 | 0.543 |
| Whitebridge | 0.382 | 2.809 | 3.191 |
| Deep resource slice | 0.444 | 13.753 | 14.197 |

The deep callback had zero R5 runs and approximately 15 ms of measured native
VoxelManip methods. Whitebridge's native methods took approximately 34 ms.
Engine `Mapgen::makeChunk` was around 25 ms. These results locate the main
cost in game Lua; they do not yet distinguish P8 root ranking from other Lua
stages. The first two Hearthpine owners had zero decoration candidates, so
logical biome membership alone is not an adequate tree regression witness.

The original snapshot manifest digest is
`606731cb9610d220d010623682034c4475ba4fa70d46a1e3231de924a176d38b`;
the sampled output digest is
`52227df5b48d18b88ee6dae78b4e3bec30957b83493f6ce338352202ae7eaa88`.
Full owner content/param2/light parity will be measured against the corrected
tree baseline before accepting any performance change. Historical R8 mocked
VM timings are not a substitute: their deep input does not contain the native
stone population that triggers this measured resource workload.

## Focused performance implementation brief

Supplemental coarse-stage instrumentation found 9.918 s in P8 of the deep
writer's 9.940 s. That owner computes 5,390,506 root-rank hashes and performs
1,375 full root sorts (1.461 s). Whitebridge computes 1,117,880 root hashes;
P8 takes 2.107 s, including 0.261 s root sorting. The sparse 1/1024 hash timer
supports investigating hash preparation, but its estimate is not an additive
CPU profile. Instrumentation changes LuaJIT traces; use uninstrumented-stage
callback runs for final before/after comparisons.

Two bounded runtime changes are selected:

1. Prepare the canonical seven-field resource/cell/segment hash prefix once,
   then append the same framed x/y/z for each eligible coordinate. A new
   internal `r6_hash.prepare_digest3` closure validates and freezes the prefix;
   its suffix preserves canonical framing and SHA-256. Prefix count is 0..29
   (production uses 7), with the counted interface allowing stale tail keys;
   no mutable prefix table is retained. Test prefix-only and combined heap
   changes separately against the corrected baseline before final acceptance. Keep existing hash APIs
   and ordinary/evidence settlement on the full framing path as the oracle.
   No changed domain, hash bytes, SHA count, probability or random order.
2. Build a min-heap over the identical eligible coordinate records, then pop
   exactly the ascending prefix consumed by the existing planned-vein loop.
   Keep full sorting for ordinary/evidence/capture construction. Each planned
   slot finds its first unclaimed root or records its existing no-root
   rejection/shortfall, even after earlier short frontiers or heap exhaustion.
   Preserve foreign-claim collision counting and same-resource claim skipping.
   Never overwrite popped record fields; rebuild only the next group's active
   scratch prefix. Frontier sorting and all placement/commit logic stay intact.

The focused independent Sol assessment accepted the heap candidate with these
conditions. Verification includes exact prefix-hash input comparisons, malformed
input rejection, all-byte/tied coordinate ordering, prefix exhaustion and scratch
reuse, resource full-sort/runtime differential output, and complete real-engine
owner content/param2/light parity against the frozen corrected tree baseline.

After prefix preparation and lazy root selection, the first uninstrumented
writer measurement fell from 18.065 to 6.989 s in the deep owner. A focused
independent Sol assessment approved one further measured candidate: a private
numeric-frame cache owned by each prepared-prefix closure, capped at 64 entries.
Validate every numeric value before lookup; cache only its complete unchanged
canonical frame. Non-numeric inputs keep the original framing path. The cache
is released with the cell/segment closure, has no world-lifetime storage, and
falls back to ordinary framing after saturation. Test cap exhaustion/revisit
orders and preserve all hash inputs and errors. Accept only after a further
real-engine A/B demonstrates improvement and complete owner/persistence parity.

## Final measured result and verification

The final candidate retains all three optimizations. Three independent fresh
world/process runs per variant used the same frozen harness, image, seed, corpus
and container limits; variants were interleaved during the two repeat rounds.
Medians below include planning plus writer, in seconds:

| Owner | Corrected trees, original ranking | Prepared prefix + heap | Final, with bounded frame cache |
|---|---:|---:|---:|
| Whitebridge | 4.212 | 2.312 | 2.103 |
| Deep resource slice | 18.432 | 10.116 | 7.006 |

The final callbacks are approximately 50% and 62% shorter, respectively.
Deep-owner ranges were 14.841–18.516 s before and 6.950–7.530 s after. These
are bounded shared-VM observations, not a whole-map percentile or browser
benchmark. The original illustrative pre-correction measurement was 14.197 s;
it is kept separately and is not substituted for the corrected A/B population.
Other cases remain recorded individually; owners without eligible resources
cannot benefit from resource ranking changes. Initial emerge-environment
construction and the single-worker disk/generation queue remain separate costs.
No mixed request-queue latency claim is made by this sequential corpus.

Every full comparison (including prefix-only and each repeated run) has the
same complete content/param2/light digest for all 5,120,000 owner voxels:
`cf1d61f5cfd6355988bccd93a5c98ea8dbb8379a456fc3efe7872903c5e6466d`.
Each clean restart loads 1,250 blocks from disk, invokes zero generation
callbacks and reproduces that digest. The final game sources are exactly the
`final` variant; the `optimized` diagnostic variant predates the added
runtime-constructor seam check as well as the frame cache.

The actual shipped pine fixture fails on the original source and passes with
source slices `1100001110111111`, compressed destination Y 5..15, unchanged
400-cell reservation and a separate individual-node gap control. The resource
fixture compares ordinary full-sort and optimized runtime output and VM traces,
including exhausted foreign claims, own-frontier claims and shortfall. The
primitive fixture checks full/prepared SHA inputs, malformed fields, immutable
prefixes, interleaving, cache saturation, full binary ranks, ties and scratch
reuse. LuaJIT forward/reverse R8 output remains equal on the corrected map.

All changed Lua passes the plain-5.1 parser, SETGLOBAL inspection and five
source sweeps; the existing complete production sweeps also pass. The one
frozen-final PUC micro-KAT and the same LuaJIT fixture produce byte-identical
output SHA-256:
`aaf9b5005e9fd089c83c548108aac15e995c54ea713b867b2213fa6197bff95f`.
This does not replace the separate real fallback-engine runtime gate.

Durable evidence and reconstruction instructions:
[profile evidence](../../tools/wp40/profile/evidence/20260913/README.md).
Historical R6 contracts/artifacts are unchanged. No managed VM realm or
Production world was changed, and no saved tree was retroactively repaired.

## Review and integration record

Implementation: Codex coordinator with GPT-5.6 Sol delegates for tree
correction/regressions, resource differential and profiling harness. Focused
independent Sol brief reviews accepted the frozen slice, prepared-prefix,
heap and bounded-cache contracts. Final independent reviewer: GPT-5.6 Sol, fresh context `/root/final_review`.
Verdict: ACCEPT; 0 Critical / 0 High / 0 Medium / 0 Low; zero fix rounds.
The preferred Opus CLI attempt exited with HTTP 403 before processing any
review input because the organization disabled Claude subscription access for
Claude Code; the policy-authorized independent Sol review supplied the gate.
Observed total delivery wall time: unknown. WP40 remains in progress; this
follow-up does not satisfy its remaining real-world/visual/fallback gates.

User runtime test after integration: generate a new pine forest, inspect
continuous trunks and natural canopy height, explore fresh terrain, reconnect
into that same area, then return to it while nearby new terrain is requested.
Already generated broken trees remain saved; use new terrain for the fix check.
