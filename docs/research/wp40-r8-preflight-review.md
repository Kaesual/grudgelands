# WP40 R8 Preflight Review

**Status:** The corrected G2 pilot and the one final frozen-byte PUC/LuaJIT
micro-KAT pair pass. Exact G3 candidate
`4ca1c6564382c1e4ab726fd60a38c3b4461dba05` generated nearly the full corpus
without a mapgen error but correctly failed at its exact two-hour boundary.
The user-approved four-worker sharding and three-hour safety correction has
focused independent acceptance at exact candidate
`d20bcf58b751be256e3b96fe14df4b5dc901e6eb`; the replacement G3 may run.

## Scope and independence

A fresh independent GPT-5.6 Sol context at xhigh effort reviewed the R8
contract, runner/probe scaffold, candidate/corpus inputs and GUI itinerary
read-only. The reviewer did not implement any reviewed byte. Sol was used
instead of Opus under the user's explicit session instruction because Opus
credits were unavailable.

The package is classified **non-trivial** because it defines release evidence,
executes a real engine against generated worlds and can accept or reject the
WP40 production cutover.

## Initial verdict

**REJECT: 1 Critical / 2 High / 3 Medium / 0 Low.**

1. **Critical — invalid VoxelArea construction.**
   `probe/init.lua` passed two vectors to `VoxelArea:new`, although that method
   accepts one `{MinEdge, MaxEdge}` definition. The first negative-coordinate
   snapshot would use invalid strides and fail.
2. **High — native preservation was not a gate.**
   Cave, dungeon, stratum and native-ore evidence was optional, allowing the
   release smoke to pass even if the production writer erased it.
3. **High — mutable Git revision expression.**
   `WP40_CHECKOUT_SHA` accepted a branch, tag or abbreviated name and resolved
   it again for each archive, permitting two different snapshots under one
   capture identity if the reference moved.
4. **Medium — feature checks were mapchunk-wide.**
   Any same-named node in 80 cubed voxels could satisfy the capital, channel or
   resource claim instead of the source-bound location or envelope.
5. **Medium — the exact ruby witness was Seed-0-only.**
   The runner also admitted Seeds 1 and 42 without candidate-specific resource
   provenance.
6. **Medium — runtime engine identity was under-gated.**
   The Flatpak identity was captured only before execution and the two
   in-process engine records were not required to match.

The reviewer additionally verified from the pinned engine source that the
minimal native-event correction is technically valid: request generation
notifications before generation, then read `gennotify` from the main
`register_on_generated` callback after native v7 and the production mapgen
script have run. Random-walk caves emit begin/end notifications; v7 noise
intersection caves and caverns do not, so the correction must not interpret
missing notifications as absence of every cave form.

## Correction boundary

The correction is tools/docs-only and does not modify production Lua or
invalidate R6/R7 evidence. It will:

- fix the VoxelArea call;
- resolve one immutable full commit ID and gate unchanged Flatpak/in-process
  engine identities;
- add one predeclared bounded deep native-witness grid to both exact reverse
  schedules;
- require real dungeon and random-walk-cave events, every retained stratum and
  the native gravel blob in the final smoke;
- replace mapchunk-wide feature existence with exact or source-bound envelope
  checks; and
- keep Seed 0 as the only initially automatable candidate until another seed
  has its own accepted resource witness.

The grid is fixed before runtime and cannot grow until a random event appears.
If it happens to contain no required event, the result remains evidence and
the coordinator stops for a reviewed scope decision rather than silently
searching farther.

Critical and High corrections require a focused independent re-review before
the first real-engine pilot.

## Focused re-review of the first correction

The same independent context reviewed exact commit
`a1dc04b89d6e54945fb3507bf92967c4d6c0a86c` read-only and returned **ACCEPT
for the sequential pilot: 0 Critical / 0 High / 3 Medium / 1 Low**. It verified
the corrected VoxelArea call, immutable Git resolution, exact corpus
populations and reversal, Seed-0 gate, native notification mechanism and hard
native/content/startup/shutdown comparisons.

The remaining findings did not block the pilot, but do block G3: native events
must be scoped to the 25 owner-grid rows rather than the seven census slices;
the channel witness must measure the promised bounded envelope; and parallel
interruption must retain live diagnostics and terminate descendant processes.
The Low finding asks the runner to reject noncanonical spellings such as `00`
and `-0`. The current correction addresses all four before another frozen
candidate is used.

## First real-engine pilot attempt

The accepted exact `a1dc04b...` candidate was started sequentially on
2026-09-02. The forward engine stopped before any mapchunk generation; the
reverse order was consequently not started. Luanti reported:

```text
WP40 R7 native: noise readback mgv7_np_terrain_base spread has a metatable
```

This is a real-engine compatibility finding, not a failed world-content gate.
Pinned engine source shows `get_mapgen_setting_noiseparams` calling
`push_noiseparams`, which emits `spread` through `push_v3f` as a builtin vector.
The correction admits only that exact `vector.metatable` for readback spreads;
setter definitions and unrelated metatables remain rejected. It also adds the
real engine shape to the native-input KAT and final micro-KAT fixture.

The abandoned capture ID is
`981cf1169e5565128cb1bf50613182e016787835b9da779d8e89c7dd6ad83883`.
Its retained forward `console.log` and `server.log` SHA-256 values are
`14938afdb49a6a669c8d3107106802ea565c6e17358a58e06ee7ca7873c1f222` and
`c785edab6bdf4247b7729b5803bfd9f128ddee95c08609d3f480bab954a8b2bb`.
No event, digest, timing, RSS or shutdown acceptance claim is derived from it.

## Focused review of the real-engine correction

A new independent GPT-5.6 Sol context reviewed exact commit
`972b139f8fd5056870fb0f21c71af660a190f186` read-only and returned **REJECT:
0 Critical / 1 High / 1 Medium / 0 Low**. It accepted the production
NoiseParams fix, its two fixtures, the narrowed native-event scope, channel
envelope and canonical-seed gate. It also confirmed that R6/R7 semantic
evidence remains valid and only the replacement final micro-KAT pair is
required.

The High finding was that live events now target the durable result directory
but `write_event` still used Mod Security's restricted global `io.open`; the
correction uses the already-acquired trusted `insecure.io.open`. The Medium
finding was a late-PGID publication race in parallel cleanup; after stopping
and waiting for both wrapper processes, cleanup now performs a second engine-
group termination pass before removing scratch worlds. Both fixes are harness-
only and require focused re-review before execution.

Exact follow-up commit `2cbe52748eaaa8bba1efbae83b2700bc1231c480`
received **ACCEPT for a fresh sequential pilot: 0 Critical / 0 High / 0 Medium
/ 0 Low** from another fresh independent context. The rerun then found a
second pre-generation production compatibility issue: real `core.settings`
has Lua type `userdata`, although its effective `num_emerge_threads` value and
the mapgen readback were both the required string `1`. The runtime validator
had accepted only the table-shaped fixture seam. The narrow correction admits
table or userdata, still requires the exact `get` method/value, and models the
real boundary in the final micro-KAT fixture. It requires another focused
review before the next pilot.

## Review of the Settings correction and engine vectors

A fresh independent GPT-5.6 Sol context reviewed exact commit
`354a01a024f6e7f965657a7108adadf3f972a1ec` read-only. It accepted the
Settings userdata correction but returned a composite **REJECT: 0 Critical /
3 High / 0 Medium / 0 Low** after an immediate supplemental engine-shape
hard-lens. The blockers were:

1. `core.read_schematic()` returns `size` as a builtin vector while the pure
   R6 template parser requires a plain table.
2. `register_on_generated` supplies vector-shaped `minp`/`maxp` to the strict
   planner boundary.
3. `VoxelManip:get_emerged_area()` supplies two vectors to the strict
   settlement boundary.

The reviewer checked the pinned C++ and builtin Lua implementations and found
no further analogous vector-shape blocker in the immediate R8 pilot path. The
correction normalizes the exact builtin vector representation at all three
boundaries while continuing to reject foreign metatables and unexpected
fields. The final micro fixture exercises all three real shapes. This is an
engine-adapter compatibility correction, not a placement-policy change, so
the accepted R6/R7 semantic evidence remains valid. Static R7 gates and an
intermediate LuaJIT micro-KAT pass; the replacement final PUC/LuaJIT pair is
deferred until the corrected bytes pass focused review.

Exact correction commit `bc6386080cb14edbc34211e5108801fa2441f3df`
received **ACCEPT for a fresh sequential pilot: 0 Critical / 0 High / 0 Medium
/ 0 Low**. The ensuing engine attempt crossed all three corrected vector
boundaries and then stopped at the frozen source-projection manifest.

The retained capture and a separate diagnostic proved that only the WP43
projection digest differed. Production's `wp43_handoff.project()` includes the
complete validated registry surface, while `tools/wp40/r7/runtime_fixture.lua`
had substituted R6's smaller placement-only projection. All placement-consumed
subgraphs and the other five source-projection components retained their exact
accepted digests. The correction makes R7 tooling execute the production
handoff, checks its `6/23/15/12/2/6/6/6/2` population in the final micro
fixture and updates the closed manifest to the independently reproduced real
projection digest. This model-drift correction requires focused review before
another pilot.

A targeted LuaJIT owner-VM integration rerun passed. Its durable
[receipt](wp40-r8-projection-integration-receipt.tsv) differs from R7's
accepted receipt only in the manifest SHA-256 row; every placement/content/VM
evidence row is byte-identical. This is direct evidence that the correction
changes the authenticated projection envelope, not generated semantics.

## Contested-outpost correction and review

The next construction attempt proved that ten frontier outposts legitimately
stand in contested zones with no political `faction_at` result. The source race
region and authenticated race-to-garrison mapping remain defined. Exact commit
`f2599f8af974e66705981139c3b270c92e341643` therefore validates outposts
against `race_region_at`, and guard banners prefer the authenticated outpost
faction before falling back to surrounding territory for non-outpost banners.

A fresh independent GPT-5.6 Sol review returned **ACCEPT for a sequential
pilot: 0 Critical / 0 High / 0 Medium / 1 Low**. It accepted the production
logic and contested Accord/Throng regressions. The Low finding was stale
territory-only wording in comments and one warning message.

## Fresh-engine halo hard-lens

The pilot of `f2599f8...` passed construction and entered the first production
mapgen callback, then failed because both inherited lighting transactions
required the expanded read-only halo to contain no `CONTENT_IGNORE`. A new
independent GPT-5.6 Sol context classified the systematic fresh-surface blocker
as **1 Critical** and the unrepresentative offline-fixture/evidence gap as
**1 High**, with no Medium or Low findings.

Pinned engine code confirms that fresh border MapBlocks begin as ignore, v7
materializes only the central mapchunk in x/z, and native light spreading skips
ignore. The reviewer rejected a runner-size workaround and required the same
narrow correction in `map_adapter.lua` and `r6_settlement.lua`: owner ignore
still fails; read-only halo ignore is accepted and all halo content, `param2`
and light bytes are preserved. Required regression evidence covers the pure R5
adapter, consolidated production writer, central rejection and existing
materialized-neighbor cases. A fresh sequential real-engine pilot follows only
after static gates and focused review of an exact commit.

The strengthened LuaJIT micro-KAT and prefreeze source audit pass. The complete
production-shaped R5/R6/R7 owner-VM integration also passes, and its canonical
receipt remains byte-identical to the retained R8 projection receipt
(`1fc22c764be500726f6f777b0eabd7a03a2434e23895aad6132c7c7e1ca78010`).
This directly constrains the correction to the fresh read-only halo rather than
accepted owner geometry or settlement semantics. An exact-SHA focused review
is the remaining prerequisite for the next pilot.

Exact follow-up `ded5a30eba299e1367980c5e07f3c6222c7f0376` resolved both
non-blocking wording findings and received **ACCEPT: 0 Critical / 0 High / 0
Medium / 0 Low** for the sequential pilot. The pilot then completed all three
feature requests and two same-depth adjacent native-grid requests without a
Lua or mapgen error, but the forward schedule reached the fixed timeout before
the remaining three redundant native-prefix cells. A one-row native pilot
still exercises the identical notification path; the full 32-row G3 corpus is
unchanged. This measured G2-only reduction requires focused independent review
before rerun.

## One-row pilot reduction review and Attempt-7 hard lenses

A fresh independent GPT-5.6 Sol context reviewed exact commit
`230925ada8bbb4c332d590f54d40811f9d379ad6` and returned **ACCEPT for a
sequential pilot: 0 Critical / 0 High / 0 Medium / 0 Low**. It verified that
the three feature cases retain the distinct capital, channel and deep-resource
risk classes; the single native row is the exact first row of the unchanged
32-row final corpus; and the notification, final census and complete-run gates
were not weakened.

Attempt 7 then completed both schedules and produced two focused read-only
diagnoses from separate fresh GPT-5.6 Sol contexts:

- The sunlight lens traced a real writer defect to v7's pre-callback light
  pass and the inherited `propagate_shadow = true` call after WP40 replaces the
  geometry. It recommends false only for light boxes ending above the fixed
  water level, true below it, unchanged halo restoration, and a real packed
  15/0 sunlight witness in authored air.
- The mismatch lens showed that the sole order difference is raw `param2` in
  a chunk containing 724 flowing-lava and 150 flowing-water nodes. The runner
  snapshots the complete schedule after unequal aging under the default
  one-second periodic liquid tick. It recommends setting the test-owned
  periodic interval beyond the host timeout rather than snapshotting each case
  early: immediate `finishBlockMake` processing remains authentic, while later
  requests can still invalidate earlier chunks before the final comparison.

Neither lens changed files or executed tests. Their correction set requires
static/fixture evidence and a focused independent review of one exact commit
before another real-engine pilot.

## Surface/light-boundary correction verification

The correction candidate passes the following pre-review evidence:

- all changed Lua parses under the repository's PUC Lua 5.1 compiler; the
  changed production files have no `SETGLOBAL`, the R8 probe has exactly its
  declared `grug_wp40_r8_probe` global, and all five Lua/sandbox source sweeps
  have no code finding;
- the R7 unit and static suites pass, including the one-loader/one-callback/
  one-writer audit over 900 inputs with source-set SHA-256
  `618e0003b0291c5438551e345dc1776ec6ae18e51d477cb62c8c9244b0064e07`;
- the full production-shaped R7 integration KAT passes and is byte-identical
  to the durable R8 projection receipt, SHA-256
  `1fc22c764be500726f6f777b0eabd7a03a2434e23895aad6132c7c7e1ca78010`;
- the intermediate LuaJIT R7 micro-KAT passes with canonical output digest
  `3c977dc6fe7d4b5f2300116176a44504e0a45991a493b765c3b920f1952414f7`;
  this is development evidence, not the final frozen-byte PUC/LuaJIT pair; and
- an isolated exact-R5 snapshot with only the corrected adapter and validator
  overlaid passes its LuaJIT quick suite: input-manifest
  `6091f17bba31ddc7ab5e57015153345e56b68674111bdba56ece7215afbdcdf6`,
  matrix shard
  `5011194db1b799ba8e80634b92e13c5199fda0ab28bbe74a1f045561d8b3878f`
  and native-heightmap shard
  `a446ad1283fc7fc99f51a3a5c2f089176c9d413e09b23b6ebc84effee5b06b4f`.

The fixture explicitly distinguishes three boundaries: stale dark v7 overtop
above water no longer owns the final sky decision, the same boundary remains
shadow-propagating at/below water level, and an opaque node inside the
recalculated box prevents direct sunlight. The runner continues to take every
snapshot only after the complete schedule while authenticating the deferred
periodic-liquid setting in both engine startup records.

## Surface/liquid correction review

A fresh independent GPT-5.6 Sol context reviewed exact commit
`fa5f7365f7040d6350d330ede8e254684f53efcd` read-only and returned **REJECT:
0 Critical / 0 High / 1 Medium / 1 Low**. It confirmed the engine water
boundary, in-box blocker and halo semantics; the exact 15/0 authored-air
witness; complete-schedule snapshots; independent immediate and periodic
liquid paths; and strict startup/comparison gates.

The Medium finding was confined to harness input validation: the runner
accepted an arbitrarily long decimal timeout before Bash signed arithmetic, so
a crafted value could overflow `timeout + 31` to a negative `liquid_update`
while leaving `timeout + 30` positive. The Low finding was this document's
obsolete top-level status. The correction caps the already internal fixed-run
override at 86,400 seconds using a length check before numeric comparison;
therefore both later additions are bounded and retain their required one-second
ordering.

The same independent reviewer then inspected exact correction commit
`2c08f756c899bcc90a60f441c2d05c68b5f7aae4` and returned **ACCEPT: 0 Critical
/ 0 High / 0 Medium / 0 Low**. The canonical positive-integer check precedes
the length bound, the numeric comparison can see at most five digits, and both
later additions are bounded to 86,430 and 86,431. Default pilot values remain
host timeout 930 and periodic-liquid interval 931. Only validation and review
status changed, so the earlier accepted light, halo, full-schedule snapshot,
immediate-liquid and strict-comparison conclusions remain intact.

## Attempt-8 result and vertical-ignore correction

Attempt 8 ran exact accepted candidate
`2c08f756c899bcc90a60f441c2d05c68b5f7aae4` through both sequential orders.
All eight requests completed, both engines exited zero and shut down cleanly,
and the full snapshot comparison returned `equal = true`. The formerly
different deep `param2` bytes now have the same digest in both orders, directly
confirming the periodic-liquid correction. Only the two surface direct-sun
semantic witnesses remain false.

A fresh independent GPT-5.6 Sol source lens traced that result to the vertical
fresh halo. The false propagation flag bypasses only the old overtop-shadow
check; the engine then starts scanning at the supplied calculation maximum.
The enlarged light box can end in `CONTENT_IGNORE`, which does not propagate
sunlight, so the scan terminates before reaching authored owner nodes.

The narrower candidate keeps the enlarged zero/spread/restore box and caps
only the surface `calc_lighting` maximum y at the owner maximum. Deep boxes
retain their old maximum and true propagation. The independent fixture records
separate set/calc maxima, demonstrates direct sun below a fresh ignore halo,
keeps a real opaque in-owner blocker dark and requires the ignored halo's
content, `param2` and light bytes to be restored exactly.

The corrected candidate passes the PUC Lua 5.1 parser, R7 unit/static gates
and all source sweeps. The updated static source-set SHA-256 is
`436382004e6c88a728641c334b24b6570fcd57404b261cf2a1c012bccdae64c0`.
An intermediate LuaJIT micro-KAT passes with internal output digest
`3e2e21bf640498652abc1a68dce6c2957b520406e6b415e6f708cf22af706482`
and output-file SHA-256
`3e4e7e3a7914b6c5c9cf2348c3ff8f7626989f14e82f43b38d55bc90fe95bcb6`.
This remains development evidence, not the final frozen PUC/LuaJIT pair.

An isolated exact-R5 snapshot with the candidate adapter and validator also
passes its LuaJIT quick suite: input-manifest
`8673e347e9a2a89f8af83f508a6fd03d01a592315927d13c34c512dab13da8f9`,
matrix shard
`23b694b3aee264628c80278ec01bffff1f42de5154633cd2110432a3538a09a1`
and native-heightmap shard
`165d573a16af69d12ad514d93a374d741a7b316115f770ddc796ec2c6e4245f5`.
The complete production-shaped integration KAT passes and produces bytes
identical to the durable R8 projection receipt, SHA-256
`1fc22c764be500726f6f777b0eabd7a03a2434e23895aad6132c7c7e1ca78010`.

R8 deliberately supersedes the historical R6 surface light bytes. Therefore
the production-shaped Stage-B comparison remains exact for frozen R6 material
bytes, while current Stage A remains exact for content, `param2` and light and
the dedicated R8 fixtures own the changed lighting boundary. This narrowly
scoped oracle change is part of the focused review boundary; it must not be
accepted if it removes any current-light comparison.

## Owner-top correction review

A fresh independent GPT-5.6 Sol context reviewed exact commit
`050ae36bed447c873f7df1ef43f04e73517d89bf` read-only and returned **ACCEPT:
0 Critical / 0 High / 0 Medium / 0 Low**. It confirmed against pinned Luanti
5.17 source that the surface calculation now begins at authored owner content,
while the full-VM light spread, enlarged set box, deep path and byte-exact halo
restoration remain unchanged.

The reviewer also accepted the Stage-B historical-light supersession as
narrow: current Stage A still compares all content, `param2` and light bytes;
Stage B retains exact material, private-tuple and run comparison with frozen
R6; and the independent current-light fixtures cover the changed engine
boundary. It found no Lua 5.1, global, performance, documentation or release
gate regression. The exact commit is accepted for the next fresh engine pilot;
the pilot and eventual frozen PUC/LuaJIT micro-KAT pair remain open gates.

## Accepted G2 rerun

The sequential pilot of exact reviewed commit
`050ae36bed447c873f7df1ef43f04e73517d89bf` completed both orders in 12:29.78
and 12:24.78 wall time with no engine error, clean shutdown and peak
in-process RSS below 3.87 GB. Comparison, semantic, identity, reversal, native
and completion gates all pass.

The capital and Wyrmglass surface snapshots now contain respectively 70,916
and 294,400 authored-air voxels with packed direct sunlight 15/0. Their exact
light digests match across order. Content and `param2` also match throughout,
including the deep liquid-bearing case. Capture
`73da938db983ef34147733882648f7e5523a8f4d649a8b6428f6209f7ab9e944`
is permanent under `tools/wp40/results/r8/`; its comparison SHA-256 is
`88b33d4d378a8471b43450634aa6b976eaf8c6677d956e350a43f08e95597ceb`.
This closes G2 and authorizes final-byte freeze plus the complete G3 corpus.

## Frozen-byte interpreter gate

No production Lua, probe byte or final-micro input changed between the
accepted G2 candidate and this interpreter pair. The one required final
compact PUC 5.1/LuaJIT micro-KAT pair ran on that frozen input set and produced
byte-identical canonical output. Its
[versioned evidence directory](wp40-r8-final-micro-evidence/) contains the
receipt, canonical output and both interpreter logs.

- Receipt SHA-256:
  `2f8e04cca1f034194bf6c45ed1980a01020c0631e2886646557d34026e9b249a`
- Canonical output SHA-256:
  `3e4e7e3a7914b6c5c9cf2348c3ff8f7626989f14e82f43b38d55bc90fe95bcb6`
- Input-set SHA-256/population:
  `eb2ce545a3d8ad33d7e207cc1eb7cd40e9d1ea4354d632fb0ef149b95b4eb834`
  / 100
- Executed production-module population: 71
- LuaJIT and PUC exit status: 0 / 0
- `byte_identical`: true

The retained filenames and receipt schema say R7 because R8 intentionally
executes the inherited final production micro-KAT rather than creating a
second semantic suite. The enclosing R8 evidence directory and input hashes
bind this replacement pair to the corrected frozen bytes. No additional PUC
runtime is authorized or required absent a concrete interpreter-specific
finding.

After this pair, the G2 timing projection reduced only the final feature
corpus and corrected the final-only launcher validation. Commit
`b7ab41ddfaf40995ad7d8e20147ac33ba9e7ac7c` makes final mode require parallel
orders and `WP40_R8_TIMEOUT=7170`, yielding the contractual 7200-second host
hard stop and 7201-second periodic-liquid boundary. Neither the corpus nor the
R8 runner is among the 100 final-micro inputs, and the probe and production Lua
remain unchanged. The later launcher change therefore does not retroactively
alter the accepted G2 capture or invalidate the frozen PUC/LuaJIT pair; it is
part of the separately reviewed G3 execution envelope.

## G3 corpus and budget review

The accepted G2 work projects the original 15+32 request set slightly beyond
the contractual two-hour wall envelope. Exact commit
`2ac965dc257747349796e6f5a3728d3500d70819` reduced only the feature corpus to
the already permitted 10-row lower bound. A fresh independent GPT-5.6 Sol
review rejected it **0 Critical / 1 High / 0 Medium / 0 Low** because the
normal final invocation still inherited the 900-second pilot default and final
mode did not enforce the two-hour ceiling.

Commit `b7ab41ddfaf40995ad7d8e20147ac33ba9e7ac7c` fixed that finding by requiring
`WP40_R8_TIMEOUT=7170` and parallel orders in final mode. The focused re-review
confirmed the High was closed but returned **0 Critical / 0 High / 1 Medium /
0 Low** for the stale frozen-byte wording corrected above. A second focused
review of exact follow-up `4ca1c6564382c1e4ab726fd60a38c3b4461dba05`
returned **ACCEPT: 0 Critical / 0 High / 0 Medium / 0 Low**.

The final reviewer verified the one-to-one 10-row provenance, unique combined
mapchunks, unchanged three-row G2 prefix, all three hard position witnesses,
all 32 native rows and every contracted risk class. The five removed engine
rows remain in the 15-point GUI route. It independently reproduced the roughly
117-minute point estimates and confirmed the exact 7200-second host/7201-second
liquid boundary. G2, production bytes, probe, native corpus and the final
interpreter pair remain valid. Exact `4ca1c65...` is accepted for G3.

## Combined G3 timeout and approved sharding correction

The reviewed combined pair reached its mechanical two-hour stop with 39/42
forward requests and 40/42 finalized reverse requests; a complete 41st reverse
request also survived in the partial stream. Every finalized emerge reported
one generated plus 124 in-memory actions and zero errored/cancelled actions.
The required snapshots, native aggregate, controlled shutdown and pair
comparison were not produced, so the attempt is retained as a budget failure,
not accepted by proximity. Exact hashes and scope are recorded in
`wp40-r8-pilot.md` Attempt 10.

The user approved two complete pair shards rather than another corpus
reduction: one has all ten feature cases, the other has all 32 native rows.
The contiguous native event grid and all stratum/ore census slices therefore
remain coupled. Each shard retains exact forward/reverse comparison; a new
deterministic aggregate requires 42 unique IDs and identical candidate,
checkout, engine and production manifests across all four fresh worlds. The
explicit residual risk is feature-to-native cross-shard mutation; R7's
accepted offline order evidence and owner-bounded production writes constrain
it.

The final launcher fixes four concurrent engine workers on ports 32001--32004,
one emerge thread each and idle CPU/I/O priority. Observed timings project the
native pair at 101--106 minutes and the feature pair at 24--26 minutes. At the
user's direction, two hours is now an operational target rather than a kill
point: the replacement uses a 10,770-second probe timeout, 10,800-second host
safety stop and 10,801-second periodic-liquid boundary. Flatpak
`--die-with-parent` also closes the timeout teardown race exposed by Attempt
10. Production Lua and the probe are unchanged, so the frozen final
PUC/LuaJIT pair remains valid; the non-trivial harness/contract correction
still requires focused independent acceptance of its exact commit.

The first exact sharding candidate `04b9de6f7b8a761cae0f53db629c46aa49201512`
received independent **REJECT, 0 Critical / 2 High / 3 Medium / 0 Low** before
execution. The High findings were a non-executable documented coordinator and
post-run use of the live worktree JQ validator instead of the captured bytes.
The Medium findings were missing cross-shard in-process engine/Lua identity,
missing equality to the exact committed corpus IDs and non-gated timing/RSS
telemetry. The correction makes the new scripts executable, re-executes from
and persists one commit-derived input tree, uses that tree for both workers and
aggregation, and adds fail-closed fixture cases for every missing identity or
telemetry gate. It remained tools/docs-only and therefore received focused
re-review before G3.

Focused re-review of exact correction
`d20bcf58b751be256e3b96fe14df4b5dc901e6eb` returned **ACCEPT, 0 Critical / 0
High / 0 Medium / 0 Low**. It confirmed closure of all five findings, the real
start-event engine-object shape, bootstrap/source-repository resolution,
captured evidence paths, cleanup order and schemas. Bash syntax, ShellCheck,
the executable-mode/archive checks and the full fail-closed aggregate fixture
passed. The reviewer explicitly accepted this commit for G3 and confirmed
that unchanged production Lua/probe bytes do not require another final
PUC/LuaJIT pair.

## Completed sharded G3 and approved recovery policy

Exact candidate `d20bcf58b751be256e3b96fe14df4b5dc901e6eb` completed all
four fresh worlds without a timeout. The feature child passed. The native
child completed 32/32 requests in both orders, exited zero, retained clean
shutdowns and zero emerge errors, but correctly withheld its manifest and
checksums because the original native gate failed. The master therefore also
withheld its aggregate receipts. Capture details and hashes are recorded as
Attempt 11 in `wp40-r8-pilot.md`.

The failure exposed two oracle problems rather than a demonstrated production
map defect. First, the frozen 25-cell grid observed no dungeon notification in
either order; absence from a bounded stochastic search cannot prove that the
writer destroyed a dungeon. Second, exact equality of the complete diagnostic
Gennotify payload rejected two different nearby-air counts and one different
`large_cave_end` position even though both orders had 25/25 begin/end events,
16 preserved air witnesses, equal normalized totals, equal retained strata and
ore census, and equal inspected feature/census content.

The user approved the following narrow correction on 2026-09-03:

- cave event positions and local air counts are diagnostic; each order must
  still have complete begin/end pairs and at least one preserved air witness,
  and this capture's normalized counts and witness totals must match;
- zero dungeon notifications in both orders is `not_observed` and
  non-blocking; a one-sided notification blocks; notifications in both orders
  require at least one inspected preserved room in each; and
- a recovered result must say that dungeon generation was enabled but not
  observed. It must not claim that dungeon preservation was proven.

The original capture remains a formal failure and is never rewritten. A new
hash-bound `recovery_v1` validator and negative fixture require independent
review on an exact commit before they may produce a separate recovery receipt.
The recovery reuses the complete retained engine evidence and runs no engine,
build, PUC or LuaJIT process. Production and probe bytes are unchanged, so the
accepted final interpreter pair remains valid.

## Calibration so far

- Implementing/coordinating model: GPT-5.6 Sol with two bounded parallel
  implementation lanes.
- Reviewing model: fresh independent GPT-5.6 Sol.
- Initial findings: 1 Critical / 2 High / 3 Medium / 0 Low.
- Review-fix rounds started: 7.
- Observed elapsed wall time: pending package completion.
