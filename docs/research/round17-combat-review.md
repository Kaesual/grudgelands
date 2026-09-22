# Round 17 COMBAT independent review

Verdict: **FIX FIRST**.

Reviewed frozen candidate `7bcac7c1fc4dfe07d6c3e0dc01e37a0320b11a3b`
against `3d7b80cb` in `/tmp/grug-r17-combat`, under Round 17 plan B and the
`wp-workflow.md` review checklist. Reviewer: native Astra. Elapsed: unknown.
Findings: Critical **0**, High **0**, Medium **2**, Low **0**. Fix rounds: 0.

Independence: this reviewer authored HOME, not COMBAT, and did not author the
reviewed combat implementation or its contested semantics. HOME only consumes
the fixed combat-identity invalidation API. HOME implementation, its tests and
its acceptance are excluded from this verdict. The coordinator reused the
native thread because of the native-thread limit; this is not self-review of
COMBAT.

## Findings

### M1 — Normal mounted movement is mistaken for a teleport

`mods/CORE/grug_core/homing.lua:49–54` reads the targeted player's own velocity
when calculating the allowed displacement. Luanti's attached local player has
its speed set to zero (`reference_projects/luanti/src/client/localplayer.cpp:544–547`);
`ObjectRef:get_velocity()` for a player returns that player's speed, not the
attachment parent's speed (`src/script/lua_api/l_object.cpp:1267–1270`). T4 flight
moves the mount at 12 nodes/s (`mods/PLAYER/grug_mounts/catalog.lua:22`).

Concrete failure: during a 0.75-second interval a targeted mounted player moves
nine nodes normally, while their reported player velocity remains zero. The
lock rejects this displacement because its threshold is eight nodes. A valid
shot is canceled instead of following the moving rider, contrary to the
explicit normal-movement/out-of-range contract. This can occur during delayed
updates and applies to player and mob shots through their shared lock.

Verified with a read-only LuaJIT reproduction loading the actual `homing.lua`:
lock duration one second, live original target, unchanged identities, rider
velocity zero, attached parent velocity 12, displacement nine over 0.75 seconds;
`homing_step` returns nil.

Correction: use the authenticated current mount/attachment movement when
estimating target motion, retaining explicit teleport generation invalidation.
Add a compact regression with a zero-speed rider on a moving parent and require
successful pursuit/impact, plus a genuine teleport cancellation case. A change
must not add postlaunch range or terrain refusal.

### M2 — The accepted zero multiplier still allows elite cone damage

`mods/ENTITIES/grug_mobs/levels.lua:109–125` and `settingtypes.txt:51` accept
`grug_mob_damage_scale = 0`, yielding `self.damage = 0`. The existing authored
cone in `mods/ENTITIES/grug_mobs/telegraph.lua:94` then computes
`math.max(1, math.floor(self.damage * 3 + 0.5))`, reviving the result to one.
Its punch at lines 130–133 therefore still deals damage with a zero global
attack multiplier. This is an integration defect in the newly introduced
setting despite the cone file itself being unchanged in the candidate.

Verified with a read-only LuaJIT reproduction loading actual `telegraph.lua`:
an elite resolves an in-range/in-cone/LOS-approved wind-up with `damage = 0`;
the target receives `damage_groups.fleshy = 1`.

Correction: preserve zero through the cone calculation and avoid its damaging
punch when the scaled amount is zero. Keep positive-value rounding and existing
cone/LOS behavior. Add this boundary to the compact scale fixture, alongside
1.0 and 1.5, rather than introducing a broad population suite.

## Other reviewed paths and evidence

The existing compact LuaJIT fixture was run once and passed:
`r17_combat PASS homing lifecycle walls range batch actors scale scout fireball`.
It does not cover either finding above. No PUC runtime, full-world generation,
capital suite, engine session, personal-world access, code edit or commit was
performed by this reviewer.

Source inspection covered:

- Player release acquisition uses `combat_ray` and its physically ordered
  current eye/look result, rejecting no target, walls and peaceful NPCs before
  staging a shot. No enemy-memory aim path was introduced.
- Scout batch staging/rollback still precedes ammo commit; Fireball refusal
  returns false before `try_cast` spends resources. Both keep existing action
  receipts and impact callbacks.
- Flight settles once by the fixed launch duration, retains one target identity,
  and does not perform later terrain/interception or launch-range checks.
  Player lifecycle generation and explicit game-teleport seams are present;
  the mounted-motion exception is M1.
- Engine ObjectRefs are cached by object identity, supporting the weak-key
  generation design (`src/script/cpp_api/s_base.cpp:427–519`). Removed object
  lookups, `set_pos` and arrow registration contracts were checked in the pinned
  sources. `mobs:register_arrow` honors the supplied `on_step`, nonphysical
  properties and `static_save = false`.
- All shipped generic ranged families use `stamp_arrow_damage`. Royal volleys,
  witch bottles and dragon breath reach the same homing controller. Dragon
  action validation requires its current attack target before execution.
- Impact still reaches the existing player ability damage or mob punch paths.
  Production `combat.lua` retains dodge, armor, absorb and level pressure;
  the mob accepted-hit seam still owns player attribution, threat, XP and
  once-per-action settlement. This is source review, not native runtime proof.
- The scale helper multiplies derived damage once; generic arrows consume that
  scaled value. Fixed poison/aura/scorch paths call the helper, and boss
  coefficients consume `self.damage`. Player/environmental paths are unchanged.
  M2 is the identified uncovered zero boundary.
- Smite and ground/area targeting semantics were not converted into homing.

After correction, require focused independent review of M1/M2 and their
regressions. Root still owns the single final integrated PUC/LuaJIT parity pair
on final bytes and the separate user GUI acceptance gate.
