# Round 16 B — Combat and control

Status: implemented; independent review and coordinator final-byte PUC/LuaJIT
pair pending. Native Astra implementation; reviewer, findings and fix rounds
pending; elapsed wall time unknown. Base: `9a387332`, branch `wp16-combat`.
No merge, sync, push, GUI test, PUC execution or performance campaign in this lane.

## Threat audit and corrections

The numerical rules remain unchanged: damage threat accumulates, effective
healing contributes 0.5 times healing (less the existing talent adjustment),
tank damage adds the existing bonus-only multiplier, switching requires a rival
above 120% of a valid current target, and Taunt grants three seconds of forced
targeting with top threat times 1.1. The proposed five-second/top-plus-one tuning
was not implemented. There is no threat decay.

Three concrete defects were corrected:

- `combat.lua:check_switch` cleared the trailing-switch flag before returning
  during Taunt's force window. A rival's final hit could be lost indefinitely
  unless another hit caused reevaluation. Keep the flag pending through the
  window; the existing one-second `aggro.lua:leash_tick` drains it afterward.
- The hysteresis comparison accepted a dead/disconnected/out-of-range current
  target's threat even when the rival was valid. Apply hysteresis only when the
  current player passes the existing validity predicate.
- Taunt forced a target before checking evade state; `aggro.lua:evade_tick`
  repaired the forced target only on its next one-second pass. The shared Taunt
  seam now refuses active evade before the ability forces the target. Shared
  player threat refuses evade as well, so no new ledger survives this bypass.

Audit boundaries: base threat is written once by `run_player_hit_mob` after the
mob's accepted-punch hook; `deal_ability_damage` adds only multiplier-minus-one
bonus after acceptance. `add_heal_threat` attributes effective healing to the
healer. Native retaliation and group alerts call `do_attack` without force;
`mobs/api.lua:do_attack` preserves an existing attack target. The Taunt ability
and hysteresis switch deliberately force their accepted target. Leash reset
clears threat/force state. No speculative targeting rewrite was made.

## Control and feedback

Charge retains teleport movement, damage, rage and cooldown. Accepted damage
applies a 1.5-second stun; kings/dragons refuse it. Player stun is an independent
hard movement flag in the existing aggregator, preserving gravity and overlapping
root/slow/immunity lifetimes. Movement immunity does not grant stun immunity.
A mounted player dismounts through the existing shared public API.

The stun event immediately cancels pending swing input and bow draws. New casts,
held swings, native player attacks and release-time bow checks consult the same
server state. A whole stun interval between server samples still cancels pending
input. Already launched projectiles keep their normal settlement path.

Mob stun cancels an elite/rare wind-up and resets native attack timers. The
marked vendored `on_step` guard runs before jumping and the knockback pause,
continues gravity/environmental damage and advances root/slow clocks, and skips
custom/native attack execution. Ordinary mob control resumes after expiry without
replaying a backlog. Current-version mob control counters remain serializable.

Nova uses `set_root` for players and preserves its slow plus movement immunity.
Its baseline is `(baseline_weapon_damage(level) + spell_power) / 4`; Rimebite adds
its existing `5 + floor(spell_power / 2)` once. The assembled spell value uses
existing spell-percent rounding and the central damage scaling once; Fireball's
specific talent/window additions do not leak into Nova. Only accepted hits apply
control; death, refusal and PvP rejection do not leave a root.

Four small procedural crystal particles per 0.3-second emission follow the live
rooted body. They stop on root expiry, immunity, death/removal; a finite emission
and particle tail is below one second. No media import or decorative entity.
The engine documents generated/overlaid `[fill` textures at
`reference_projects/luanti/doc/lua_api.md:892`.

## Ibex evidence

The actual animated `grug_mobs_ibex.b3d` was evaluated using the existing bounded
`tools/r10_cap/b3d_pose.py` utility. Engine mesh scale is applied directly in
`reference_projects/luanti/src/client/content_cao.cpp:705`; the world unit is ten
mesh units. Standing/walking sample frames 1, 100, 200, 250, 300 and 399 span
approximately x ±0.42, y -0.013 to 1.793, z -0.703 to 0.955 nodes. The former
selection fallback ended at y 0.5. The Ibex alone now has a selection box
`{-0.43, -0.02, -0.72, 0.43, 1.80, 0.97}`; its locomotion collision is unchanged.
Frame 350 extends the attacking head forward to z 1.712; this is intentionally
not a universal animated-envelope box. The bounded body/horn box fixes ordinary
aiming without a large permanent empty frontal target region. The vendored
registration already supports separate selection/collision boxes.

## Verification and integration handoff

`tools/r16_combat/evidence/inputs.sha256` identifies the tested source bytes.
All executed runtime checks used LuaJIT:

- `control_kat.lua` loads real combat/movement, ability dispatcher/kits/scout,
  mob adapter, vendored API and Ibex registration against bounded engine doubles.
  It exercises two distinct player records against one mob: threat thresholds,
  healing ownership, forced-window expiry without another hit, invalid current
  target, reset and evading Taunt refusal. It also exercises stun cancellation,
  king/dragon immunity, native jump/custom/attack suppression, gravity, overlap,
  Nova scaling/control/rejection and ice emission cessation.
- The existing `tools/wp39/combat_integration_test.lua` full suite passes. Its
  reusable fixture now supplies player metadata and tracks its ability step
  without assuming it precedes the movement aggregator's step.
- `tools/wp11/move_aggregator_kat.lua` passes. Retired soft-root source-text replay
  was replaced by hard-root/slow overlap assertions; actual Nova casts are tested
  in the new real-code fixture instead of repeating the implementation.
- Parser/SETGLOBAL and all five source sweeps pass review. Production globals
  remain the declared mod tables; test globals are engine doubles. Sweeps 1/2/5
  find comments only, sweep 3 none, and sweep 4 finds comments or literal string
  separators/catalog data. The source sweeps include all `mods/*/grug_*` and
  changed tool Lua; vendored API is parsed separately. `git diff --check` passes.

Final portable micro-fixture for the coordinator's one frozen-byte pair:
`io.write(dofile("tools/r16_combat/control_kat.lua")(repo))`.
It performs no filesystem writes or interpreter launches. The adjacent
`aggro.lua` edit is comment-only. Existing test commands and source checks are
recorded in `tools/r16_combat/evidence/`; standalone checks do not constitute a
two-client engine test. Reference submodules were read through worktree symlinks
and are excluded from staging.

## User runtime plan

1. Two players attack one normal mob; Taunt, let the other player overtake threat
   during its three seconds, then stop attacking. Check target switching after
   expiry and clean reset after leash. Repeat Taunt against an evading mob.
2. Charge a normal mob during its attack; verify 1.5 seconds without movement or
   melee/special attacks, then normal recovery. Kings and dragons remain immune.
3. In permitted PvP, Charge a player holding a swing or bow draw. Try an instant
   skill during stun; release the bow; verify no queued shot or burst afterward.
4. Nova normal mobs and hostile players: small damage, complete movement/jump
   root, continuing pale crystals, then a 50% slow and clean expiry. Check
   movement immunity and that gravity still works.
5. Aim Strike/Fireball at the standing and walking Ibex's torso/head; verify
   reliable acquisition and unchanged movement through terrain.

## Independent review corrections

The independent B review found one High in native player braking and one Medium
in oriented Ibex targeting. Both were corrected after reading the pinned engine:

- `LocalPlayer::applyControl` (`src/client/localplayer.cpp:704-732`) multiplies
  acceleration by `physics_override.speed`; speed zero therefore leaves previous
  horizontal velocity unchanged in `accelerate` (`:784-824`). The aggregator now
  retains logical zero speed but sends physical speed one with all four locomotion
  multipliers zero. Its three acceleration multipliers become 1,000,000 during
  hard control, then return to one together with locomotion on release. This
  finite braking value also covers the minimum 0.001 slippery-node factor
  (`:1153-1167`). Airborne vertical acceleration remains zero (`:710`), preserving
  fall velocity and gravity. There are no velocity subtraction packets or position
  resets. Root, stun and existing exclusive holds use the same cached writer;
  its forced watchdog compares every owned physical field.
- `selectionbox.rotate` is parsed by `c_content.cpp:369`; default false would
  leave the elongated box world-aligned while the Ibex turns. Ibex now sets true,
  and the vendored scaling helper preserves that flag in temporary/permanent
  selection boxes. Registration and activation retain the base table.

Repeated LuaJIT control, movement and full combat integration fixtures pass.
The compact control fixture adds bounded native horizontal clamp calculations
for moving ground/air/fast cases at 200 fps, including minimum slip; it verifies
all physics restoration fields and root/stun/hold/watchdog overlap. It also
checks oriented head inclusion at four yaw angles and the real mobs scaling
helper. These checks inspect the production overrides and the pinned engine
formula; they do not replace a real moving-client runtime check. Parser,
SETGLOBAL and all five sweeps were repeated; no PUC runtime was run.

Additional user runtime checks: Nova/Charge a player already running, falling
and crossing slippery ground; horizontal motion stops while falling continues,
and normal controls resume at expiry. Target an Ibex head after quarter-turns.
