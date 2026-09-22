# Round 17 B — Combat implementation

Status: implementation complete; independent review and integrated final parity
remain root-owned. Author: native Astra. Date: 2026-09-22. Elapsed implementation
time: unknown. No Claude, delegated agents, PUC runtime, sync or push used.

## Implementation

`grug_core/homing.lua` owns exact owner/target runtime identity, player lifecycle
generations, explicit teleport invalidation and bounded visual convergence.
Flight duration is launch distance/speed clamped to 0.05–2 seconds; the cap prevents
near-zero partial bow draws from creating long pursuit. Runtime collision-box
center is the visual destination, including scaled creatures. No postlaunch
terrain/object ray, range expiry or retarget exists. A discontinuity exceeding
`max(8, 2 * effective_target_speed * elapsed + 2)` cancels external/admin teleports; known
game teleports explicitly invalidate even short moves. Effective speed includes the engine-owned live attachment parent, because mounted
players can report zero own velocity. Normal velocity-based movement beyond
launch range remains valid. Shots have no persistent state.

Player shots acquire through the existing authoritative combat ray at release,
reject noncombatants and preserve transactional spawn-batch rollback. Scout arrows
retain reflected mesh/yaw/roll orientation and launch-speed scaling; Fireball
retains its sprite and damage/talent settlement. Both honor racial range bonus.
Smite is unchanged. The old swept collision module is removed.

Mob arrows reuse their existing hit callbacks via `register_homing_arrow`, retaining
level attribution, mitigation and creature-specific effects. Generic mobs use the
existing `arrow_override` launch seam, validate current `mob.attack` plus initial
range/terrain LOS, and immediately remove a staged arrow when invalid. King's
volley uses current attack at execution; dragon breath uses current target position
instead of its wind-up position. Both use the same lock/controller as ordinary
mob missiles. Ground attacks retain their authored behavior.

`grug_mob_damage_scale` is a startup float, default 1.5, accepted range 0–10.
Invalid/NaN/out-of-range values use 1.5. Formula-derived damage is multiplied once
after its existing one-decimal rounding. Current-world entity activation also
reasserts derived damage, so a server restart applies the newly configured scale.
Existing coefficients on arrows, elite cones, royal attacks and dragon attacks
consume scaled `self.damage` without another scale. Fixed poison, aura and dragon
scorch paths explicitly use the same helper. Player, fall and ordinary node damage
paths are unchanged; dragon scorch is an authored attack despite using node damage.

Teleport integrations in this lane: player Charge/Blink, character selection spawn and Oerkki/Wisp blink.
HOME owns home travel/respawn/faction spawn seams. Identity
state uses weak ObjectRef keys; ephemeral missile state never enters mob staticdata.
Pinned engine `l_object.cpp:35–45,103–117,1215–1227` confirms removed/gone objects
fail ObjectRef lookup and velocity writes safely return without mutating them.

## Evidence

- `tools/r17_combat/micro.lua` passes under LuaJIT. Loads production ray, homing,
  player projectile foundation, levels, verbs, changed actor definition files,
  Scout and kits. Exercises no aim/blocked release, moving target beyond range
  behind cover, once-only hit, respawn/replacement/teleport/evade cancellation,
  batch capacity/commit rollback, real Scout payment, Fireball success/refusal,
  actual royal volley and dragon breath launch, generic mob missile scaling,
  default/base derived and fixed aura/poison/scorch damage, invalid settings.
- Parser and SETGLOBAL inspected for every changed/new Lua, including tools.
  Production writes only the existing `grug_core`/`grug_projectiles` module globals.
  New portable fixture has zero SETGLOBAL instructions. Existing mount harness
  owns 15 intentional mock globals; its obsolete collision mock was removed.
- All five sweeps ran across own mods plus changed tool Lua. Sweeps 1/2/3/5 have
  no non-comment findings. Sweep 4 matches existing string delimiters and the
  frozen long-string manifest, no operator syntax.
- Historical WP39 ballistic/cast and R11 gravity fixtures are explicitly retired
  in their adjacent README files; current runner is `tools/r17_combat/micro.lua`.
- The historical full mount fixture still fails its already-obsolete automatic
  purchased-item insertion assertion at line 364 (Skills now owns recovery).
  Its deleted collision-file dependency is removed. This failure is outside B.

The fixture stubs engine settlement rather than claiming to reproduce native
armor/dodge/absorb/PvP/XP/durability. Those unchanged production callbacks remain
subject to independent source review and the real GUI playtest. Root must invoke
this compact function in its one integrated final PUC/JIT parity pair.

## Review calibration

Author model: native Astra. Independent reviewer: native Astra (HOME author,
independent of COMBAT). Original candidate `7bcac7c1` review: 0 Critical,
0 High, 2 Medium, 0 Low; FIX FIRST. Fix round 1 corrects both findings below.
Focused rereview pending. Review elapsed time: unknown. Final parity/native
smoke: root-owned.
No completion claim for the entire round or GUI acceptance.

## Independent review corrections — fix round 1

Original reviewer reproduction evidence and candidate `7bcac7c1` remain unchanged.
M1 now derives its permitted displacement from the greater of target velocity
and the current live attachment parent's velocity, obtained through the engine's
`get_attach()` link. No client-supplied identity or speculative attachment search
is used. The compact fixture verifies a zero-speed rider moves nine nodes in
0.75 seconds on a 12-node/s parent, continues pursuit and receives one fixed-time
impact after another three nodes in 0.25 seconds. Explicit short teleports and
large external teleports still cancel while attached.

M2 keeps the elite cone's existing positive rounding but returns before the
punch loop when its scaled base damage is zero. The portable fixture loads the
actual `telegraph.lua` consumer and verifies scale 0 makes no punch, while scale
1.0 and 1.5 preserve rounded elite cone damage of 30 and 45 at level 10.

LuaJIT compact regression, plain-5.1 parser, SETGLOBAL and five static sweeps
pass on the correction. No PUC runtime was executed; final parity stays with
root. These are narrow corrections without changes to range, LOS, impact
settlement or the configured setting range.

## User runtime plan

With Scout/Mage, verify empty crosshair/wall consumes no ammo/mana, then fire at a
moving enemy and cross behind cover after release: one impact, correct visuals and
one-action wear. Teleport/kill/respawn the target during flight: no stale hit.
Compare generic archers, elf royal volley and dragon breath against moving targets.
Restart with damage scale 1.0 and 1.5; compare melee, poison, aura and scorch while
checking ordinary environmental damage remains unchanged. Check PvP dodge/armor/
absorb, mob evade, XP/threat and mounted target interactions in the normal client.
