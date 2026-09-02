# WP40 R8 Preflight Review

**Status:** initial review rejected exact candidate
`aa1188be9f1b217d8607d984f0ff359d441bff2f`; correction and focused
re-review are pending. No Luanti world, build, LuaJIT run or PUC run was part
of this review.

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

## Calibration so far

- Implementing/coordinating model: GPT-5.6 Sol with two bounded parallel
  implementation lanes.
- Reviewing model: fresh independent GPT-5.6 Sol.
- Initial findings: 1 Critical / 2 High / 3 Medium / 0 Low.
- Review-fix rounds started: 1.
- Observed elapsed wall time: pending package completion.
