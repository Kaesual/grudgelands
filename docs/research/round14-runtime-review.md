# Round 14 runtime package independent review

Date: 2026-09-21  
Reviewer: native GPT-5.6 Sol, fresh independent read-only context  
Implementers: PREGEN — GPT-6 Astra; waiting UI and FISH — root GPT-6 Astra;
FIX — GPT-5.6 Sol  
Review iterations: 1  
Elapsed review time: approximately 25 minutes

## Scope and result

Reviewed the frozen PREGEN scheduler and plan, character-selection waiting
integration, fishing candidate, notification export, profession diagnostics and
mount flight-policy fix. The review used the checklist in
`docs/process/wp-workflow.md`, the routing and independence requirements in
`docs/process/agent-model-policy.md`, the Lua 5.1 strategy, the relevant living
design documents, the three Round 14 work records and the bounded PREGEN native
evidence. Quest/Group UI and POI work were outside this review.

**Result: PASS for the reviewed code candidate.** No confirmed Critical, High
or Medium defect was found. No production file was changed and no native,
PUC-runtime or full-world test was rerun.

## Technical review

### PREGEN and waiting state

- `preparation_plan.lua` derives the engine mapchunk origin with the negative-
  coordinate-safe floor formula, stores resolved geometry and deterministic
  `z-y-x` traversal state, deduplicates starts, and maps every index to one
  aligned mapchunk. The documented default bounds and count (99 x 89 x 8 =
  70,488) agree with the implementation and evidence.
- `starts_preload.lua` binds the selected mode in mod storage before anchor
  resolution or native work. A restart uses the stored plan, visibly ignores a
  changed setting, validates cursor/order/geometry and skips dispatch when the
  completed prefix reaches the total.
- Exactly one request is pending. Its callback accepts only generated,
  memory or disk outcomes, counts each expected mapblock once and advances the
  contiguous cursor only when the complete expected set succeeded. Any bad
  outcome prevents advancement; retries are bounded at three and explicit UI
  retry preserves the plan and cursor. The next request is issued only by the
  throttled server globalstep, never by an emerge callback.
- The native evidence supports the shutdown contract. The isolated stop probe
  shows the server stop request preceding worker settlement and no callback-
  driven redispatch. Production-snapshot logs show starts progress 0 -> 1 -> 2
  -> 3 across restarts, full progress 0 -> 1 -> 2, and zero dispatches on the
  completed third full boot. Candidate hashes for the scheduler, plan and
  faction boundary match the reviewed bytes. The evidence does not claim
  power-loss atomicity or a full-world benchmark.
- Existing complete characters are frozen in a preparation-only session and
  released without a position write, preserving their reconnect position.
  Incomplete characters retain the two gates: shared preparation, then a fresh
  arrival-area emerge before the final teleport/class commit. The faction kit
  remains protected by its persistent one-time metadata flag, so reconnecting
  while waiting does not grant another kit.

### Fishing and notification

- Both native item callbacks return the resulting `ItemStack`. A successful
  reel clears the cast before reward settlement, adds exactly one catch, applies
  wear to the callback stack and returns that worn stack, avoiding the usual
  ItemStack-copy/writeback loss. Early or late reeling removes the cast without
  reward; the throttled pass turns an expired bite into a later retry window.
- Bite windows are finite and server-clock based. One 0.2-second globalstep
  pass iterates active casts only. Death, disconnect, shutdown, invalid bobber,
  water loss, range loss and wielding a non-rod all remove the ephemeral,
  non-static bobber and cast state.
- `grug_abilities.notify` reuses the existing skill-name HUD record. Its token
  check prevents an older expiry callback from clearing a newer catch or skill
  message. The explicit fishing dependency closes the load-order requirement
  without a cycle in the reviewed dependency set.

### Small fixes

- Flight first rejects ocean classes, then rejects both exact dragon-island
  zone identities, then allows `contested_land`, `holy_grounds` and the
  rider's own home territory. This matches the living mount/world-zone policy
  for both factions; enemy home territory remains forbidden.
- Trainer changes add bounded action diagnostics around the existing
  per-player session and metadata calls. They do not guess at or alter the
  unresolved Cooking report. The callback-level two-player evidence supports
  isolation, while the documented two-client native probe remains the correct
  next diagnostic if the report recurs.

## Remaining gates

These are acceptance gates, not code findings:

1. The root-coordinated final compact PUC 5.1/LuaJIT micro-KAT pair is still
   pending for frozen final Lua bytes. Any relevant byte change requires a
   replacement pair under the project interpreter policy.
2. An integrated native boot and visual playtest remain pending for the waiting
   UI, fishing bobber/bite interaction and cross-mod load order. The intended
   absence of an hours-long full-world generation test is consistent with the
   design contract.
3. Cooking isolation has no demonstrated production defect. If it recurs, run
   the specified two-client native metadata/log probe before changing behavior.

