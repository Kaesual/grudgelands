# Round 19 safe idle-health recovery — independent review

Final verdict: **PASS after one focused correction round**; no unresolved
findings. Reviewed immutable implementation commit
`edabd948b8a40bf2678f02bac020275c3cf992b3` and focused correction
`87423283c3c75864494666230deab0c82f8103b5`, plus the frozen harness correction
`033d894f1c14b7ed145ec88de767c809b2e2e059`, against pursuit baseline
`ecec014acb4fc78f40805042808a134bd22e049e` and the additional approved scope
in `docs/research/round19-pursuit-followup.md`. Read-only review; I authored no
production, fixture or repository-documentation bytes.

## Initial High — group target acquisition could race peer recovery

The initial candidate published shared boss activity from one-second health
sampling and the common punch wrapper, but not immediately from `do_attack`.
Because the grug `do_custom` wrapper runs its maintenance before mobs_redo's
one-second `general_attack`, a royal guard or boss summon could acquire a target
just after its t=29 sample. If its damaged calm king/dragon ticked first at
t=30, the shared activity timestamp was expired and the leader could full-reset
the encounter before the attacking member published its new state.

Concrete failure: a player enters sight after a royal guard's t=29 custom
sample. Native `general_attack` calls `do_attack`. At t=30 the wounded king
ticks before that guard, sees no recent shared activity, calls `leash_reset`,
and `royal_encounter_reset` removes/rebuilds the retinue during active combat.

## Focused correction closure

**High closed.** `init.lua:809-820` installs one prototype-level `do_attack`
wrapper immediately after every grug registration. It publishes boss-group
activity before forwarding the exact `self`, target and force arguments and
the native return value. The prototype seam covers native sight acquisition,
group alerts and explicit attack calls, including calls before the first custom
tick. It writes no pursuit damage/contact clock.

The real registration fixture now samples both group members at t=29, invokes
the registered prototype's actual `do_attack`, then ticks the calm peer first at
t=30. The peer remains damaged and `grug_damage_at` remains nil. This directly
covers the original ordering defect rather than simulating a timestamp call.

The first combined PUC attempt exposed a harness-only environment split before
completion: vendor `api.lua` populated `api_env.mobs`, while the init wrapper's
intentional registration stub resolved `env.mobs` with an empty mock class, so
the new prototype wrapper captured nil. Harness commit `033d894f` now asserts
the real vendor `native.do_attack` and mirrors it into that registration
environment before fixture registration. It also makes both boundary actors
damaged and asserts shared activity at t=29 and t=30. This matches production's
inherited method while preserving fixture isolation. The earlier claimed
standalone PASS is withdrawn; only replacement evidence on `033d894f` counts.

## Other verified behavior

- Every registered actor uses the existing one-second leash cadence. A fresh
  activation seeds a local 30-second quiet window; all clocks and samples stay
  under runtime state.
- Authoritative HP decrease restarts quiet time regardless of source. A target,
  attack state, runaway/flop/death state, evade, royal cast or dragon action
  blocks recovery. Only a living damaged actor in stand/walk can reach reset,
  so the path cannot resurrect a dead actor.
- Local activation/post-heal grace is separate from actual encounter activity.
  The original activity timestamp is republished during its remaining window,
  so a 30-second local quiet period does not become a 60-second shared delay.
- `_grug_boss_id`, `_grug_boss_summon` and `_grug_royal_summon` map king,
  retinue and dragon summons to one bounded runtime activity table. Reward/XP
  participation is not consulted, so stale ledgers cannot make actors
  permanently unhealable.
- Recovery reuses `leash_reset`, including threat/target/tag cleanup, full HP
  plus `old_health` synchronization, boss action cancellation and authored
  encounter reset. Royal guards and boss summons do not independently reset
  encounter ownership.
- The compact idle fixture covers exact 30-second recovery, persistent combat,
  short target gaps, repeated targetless HP loss/DoT, death, fresh activation,
  exact shared expiry, king/retinue and dragon/summon activity, and the absence
  of a reward-ledger veto. It now loads real `bosses.lua` and verifies
  `boss_attempt_reset` clears the production activity store.
- The combined roster meaningfully loads the real registration wrapper,
  vendored mob API, aggro/reset, idle-health and boss lifecycle modules. No
  search, globalstep, proximity scan, pathfinding, persistence or migration was
  added.
- The earlier pursuit implementation remains semantically unchanged: outgoing
  attacks and the new activity seams never refresh its incoming-damage clock.
  Design and AGENTS wording match the implementation.

No runtime process, PUC, LuaJIT, native-engine or performance run was duplicated.
The coordinator retains final static gates, the single frozen PUC/LuaJIT pair,
status/completion wording and local sync. The documented GUI checklist remains
the runtime acceptance gate.

## Frozen hashes at production `87423283` / harness `033d894f`

- `mods/ENTITIES/grug_mobs/idle_health.lua`:
  `64e38a8c4c5ca5ecdc70c2e45949631fd140986868d866f427e183cbf96778d0`
- `mods/ENTITIES/grug_mobs/init.lua`:
  `db8d8214700c824584f3f52295dd788e9f9b110283f47003a55cd45075290d11`
- `mods/ENTITIES/grug_mobs/aggro.lua`:
  `c20c479cdec3818da6db4cf45ca79ad9706fc93574330a0b9271ca39775f8976`
- `mods/ENTITIES/grug_mobs/bosses.lua`:
  `dd98bfbab60a42cd7b64382a0c3f02eee406430596c66127b558ab2eb0961f5e`
- `tools/r18_evade/micro.lua`:
  `5e9b8e5c01c716e9fe148dfce2007557821b6bf158d68404a5ac373f16dbdc4c`
- `tools/r19_idle_health/micro.lua`:
  `9f66265c899805572b75b15c55c4dc63f6faed1342a1af1d6a88936412883660`
- `tools/r19_pursuit/micro.lua`:
  `eb69c9b5ba62f0f5068ed6452531468c3794999e2f7f13d494a527c318f8ee4e`
- `tools/r19_pursuit/fixtures.txt`:
  `52d10b2330d2135d7463fe5d34b564a2b3202f2cabe3fa26e0df84e69a0ca388`

## Calibration

Implementing model: native GPT-5.6 Sol. Reviewing model: native GPT-5.6 Sol,
independent context. Classification: non-trivial combat recovery behavior.
Initial C/H/M/L: 0/1/0/0. Final unresolved C/H/M/L: 0/0/0/0. Fix rounds: 1.
Observed elapsed wall time: unknown. Coordination overhead: moderate; one
pre-freeze boundary correction plus one review finding and focused re-review.
