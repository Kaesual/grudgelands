# WP40 R8 Preflight Review

**Status:** the initial contract/scaffold rejection and successive focused
corrections are retained below. Exact candidate
`f2599f8af974e66705981139c3b270c92e341643` was accepted for a sequential
pilot; that pilot reached the first generated mapchunk and exposed a systematic
fresh-engine halo blocker. Its narrow correction is under fixture validation
before a focused independent review.

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

## Calibration so far

- Implementing/coordinating model: GPT-5.6 Sol with two bounded parallel
  implementation lanes.
- Reviewing model: fresh independent GPT-5.6 Sol.
- Initial findings: 1 Critical / 2 High / 3 Medium / 0 Low.
- Review-fix rounds started: 7.
- Observed elapsed wall time: pending package completion.
