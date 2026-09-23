# Round 19 pursuit-motion follow-up — independent review

Final verdict: **PASS** with no findings. Reviewed immutable author commit
`ecec014acb4fc78f40805042808a134bd22e049e` against baseline
`afca15a2` and `docs/research/round19-pursuit-followup.md`. This was a
read-only review; I authored no implementation or repository documentation.

## Findings

No Critical, High, Medium or Low findings.

## Verified behavior and boundaries

- `aggro.lua:378-397` waits for both the expired 15-second incoming-damage
  clock and at least 0.25 nodes of current-target X/Z displacement between
  existing one-second leash samples. It uses squared distance and does not
  inspect direction, mob displacement, facing or vertical movement.
- `aggro.lua:398-408` keeps the target baseline current during the damage
  grace, clears it while there is no available target, and the expired branch
  seeds rather than releases on a first sample or target switch. Therefore a
  stationary target does not refresh the damage clock, while later horizontal
  movement can cause return on the next leash sample.
- `received_pursuit_damage` remains the sole post-initial-aggro clock refresh
  and accepts effective damage from any player or eligible guard. Outgoing mob
  attacks, taunt and threat-only updates do not write the clock.
- Runtime sample state lives only under `self.temp`. `leash_reset` clears both
  identity and position; death clears them without healing; unavailable/dead
  target reset and expired no-target/pack-flight cleanup retain their prior
  encounter teardown. Current-version activation starts with a fresh `temp`.
- The existing `damage_pursuit` exclusions leave bosses, guards, camps,
  location-bound rares, patrols and bespoke no-leash actors on their authored
  policies. No search, pathfinding, terrain load, global loop, persistence or
  migration path was added.
- The compact fixture covers a stationary live target through timeout and
  movement afterward, the exact 0.25 threshold, vertical motion and 0.24-node
  jitter, irrelevant mob movement, sideways motion, target-switch seeding,
  damage by another player and by an eligible guard, a 60-second sustained
  pull, pack-flight/no-target expiry, target death/unavailability, return
  cleanup/fallback, the existing authored-actor exclusions, and real vendored
  damage settlement.
- Living design, AGENTS and BACKLOG wording consistently distinguish the new
  ordinary ambient policy from retained bounded-actor behavior. The
  `afca15a2..ecec014a` diff passes `git diff --check`.

No Lua runtime, PUC, LuaJIT, native-engine or performance test was duplicated.
The coordinator retains the final static gates, frozen PUC/LuaJIT pair and
local sync. GUI behavior remains a user acceptance gate.

## Frozen hashes

- `mods/ENTITIES/grug_mobs/aggro.lua`:
  `596b749b5370a537a4aa21af54cf9048a07afb2750ab5a580b6586653e372b20`
- `tools/r18_evade/micro.lua`:
  `2c66f603a2e3c05afdf0fd2a537410b6d15ffc1acbc98d3c5f09321d28d2d970`
- `docs/research/round19-pursuit-followup.md`:
  `5d293a81d0dbf68d2a8736a8db53721ff91920c8eaaf01023e18696763862e3d`
- `docs/design/combat_stats.md`:
  `3214f554d56bb1c31260c44f22ef3cc9ea9a78c5ed9f85c90f477f50714feb88`

## Calibration

Implementing model: native GPT-5.6 Sol. Reviewing model: native GPT-5.6 Sol,
independent context. Classification: non-trivial behavior correction. Initial
C/H/M/L: 0/0/0/0. Unresolved C/H/M/L: 0/0/0/0. Fix rounds: 0. Observed elapsed
wall time: unknown. Coordination overhead: low; one bounded author handoff and
one immutable-commit review.
