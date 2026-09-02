# WP40 R8 Preflight Review

**Status:** initial review rejected exact candidate
`aa1188be9f1b217d8607d984f0ff359d441bff2f`; its focused correction at
`a1dc04b89d6e54945fb3507bf92967c4d6c0a86c` was accepted for the sequential
pilot. A second correction is pending focused review before a fresh pilot and
the final smoke.

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

## Calibration so far

- Implementing/coordinating model: GPT-5.6 Sol with two bounded parallel
  implementation lanes.
- Reviewing model: fresh independent GPT-5.6 Sol.
- Initial findings: 1 Critical / 2 High / 3 Medium / 0 Low.
- Review-fix rounds started: 2.
- Observed elapsed wall time: pending package completion.
