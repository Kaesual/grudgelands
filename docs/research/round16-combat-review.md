# Round 16 B independent review

Verdict: **FIX FIRST**. Reviewed `be2cc9b9` against `9a387332` in
`/tmp/grug-r16-combat`. Production sources were read only; no implementation,
commit, GUI/server run, PUC runtime or Lua worker fleet was performed.

## Findings

### High — moving players retain horizontal velocity through root and stun

Location: `mods/CORE/grug_core/movement.lua:138` and `:335` (also the existing
`set_root` path newly used by Nova at `mods/PLAYER/grug_abilities/kits.lua:650`).

The hard-control branch writes `speed = 0, jump = 0` without cancelling existing
horizontal velocity, so a player running when Charge/Nova lands continues
sliding across unobstructed ground for the control window. This is an actual
engine-contract defect, not merely an absent test: pinned
`reference_projects/luanti/src/client/localplayer.cpp:730` multiplies both target
speed and horizontal acceleration by `physics_override.speed`, and
`LocalPlayer::accelerate` at `:799` changes horizontal velocity only when that
acceleration is greater than zero. At speed zero it neither accelerates nor
decelerates. The new fixture only checks the assigned override numbers and
therefore accepts this failure.

Fix direction: make the shared hard-control transition stop existing voluntary
horizontal movement while preserving vertical gravity. Use the actual supported
player API or zero movement targets with effective deceleration. The engine's
`ObjectRef:set_velocity` is entity-only (`l_object.cpp:1215`); player
`add_velocity` is supported (`:1230`) but repeated subtraction of a stale
server-reported velocity can produce reverse motion and must be avoided.
Do not use continuous teleport correction. Add bounded moving-player boundary
coverage backed by these engine contracts, and require the user runtime test
while already running when control lands.

### Medium — Ibex selection box does not rotate with its elongated mesh

Location: `mods/ENTITIES/grug_mobs/start_zone_families.lua:87`.

The new asymmetric selection box omits `rotate = true`. At approximately
90-degree yaw, the standing head/horns extending to local z 0.955 rotate to
world x approximately 0.955, outside the fixed world-axis x bounds ±0.43;
aiming at those visible parts therefore still misses. The engine defaults
`rotate_selectionbox` to false (`src/object_properties.h:75`), reads its opt-in
from `selectionbox.rotate` (`src/script/common/c_content.cpp:369`), and uses
entity rotation in the authoritative ray only when that flag is true
(`src/serverenvironment.cpp:1368`).

Fix direction: opt the Ibex box into rotation, keeping collision unchanged;
confirm registration and activation preserve the flag, and cover a quarter-turn
orientation in the bounded geometry/registration check. The documented exclusion
of the extreme attack-animation envelope is reasonable and is not this finding.

## Reviewed contracts and evidence

- Read the workflow review checklist, Lua/interpreter rules, Round 16 B authority,
  implementation note and relevant decided design changes. No retuning of Taunt:
  three seconds/top × 1.1 remains. Pending checks survive force expiry, invalid
  current targets lose hysteresis, and shared Taunt/threat reject evade.
- Traced the existing one-second leash drain, accepted-punch threat ownership,
  effective-heal ownership, native retaliation and explicit forced target changes.
- Reviewed stun attack gates, immediate swing/bow cancellation, mob telegraph
  cancellation, pre-jump vendored guard, root/slow clocks, gravity/environment
  continuation, boss immunity and current-version serialized mob fields.
- Reviewed Nova's baseline/talent composition and accepted-hit/PvP control
  boundary. Movement immunity, independent stun lifetime and finite particle
  lifetime are preserved. No new global scan or per-tick inventory rewrite.
- Verified all 15 `tools/r16_combat/evidence/inputs.sha256` entries against the
  review tree. Read the recorded LuaJIT control, integration and movement PASS
  logs and their actual fixtures. Inspected parser/SETGLOBAL and five-sweep
  evidence; production globals remain the mod tables, tool globals are doubles.
  `git diff --check 9a387332 be2cc9b9` passed.
- Independently evaluated the actual animated Ibex mesh with the recorded
  `b3d_pose.py` utility at frames 1, 100, 200, 250, 300, 350 and 399. Verified
  17 ANIM/BONE/KEYS chunks each; sampled ordinary bounds agree with the note
  (approximately x ±0.42, y -0.013 to 1.793, z -0.703 to 0.955 nodes). Confirmed
  direct visual scale in `content_cao.cpp:705` and separate vendored selection
  registration. Mesh evidence supports the dimensions, but not missing rotation.

## Evidence limits and calibration

The standalone engine doubles do not emulate player acceleration or physical
ray-box rotation, which is why both findings escape their current assertions.
No two-client, real engine, fallback-engine or visual acceptance is claimed.
The coordinator's single combined final-byte PUC/LuaJIT pair remains pending
by explicit lane contract and must use corrected bytes. This review does not
duplicate that runtime gate. Worktree reference symlinks make plain `git status`
abort on a submodule-path check; source diff and hashes were still readable,
and reference contents were not modified.

Calibration: implementation model recorded as native Astra; independent native
review agent `/root/r16_review_combat` (coordinator records its launch model);
non-trivial combat/control scope; initial findings **0 Critical / 1 High /
1 Medium / 0 Low**; fix rounds observed **0**; elapsed wall time **unknown**.
The reviewer authored none of the reviewed implementation. Both findings were
reported promptly to the coordinator and implementer. High correction requires
focused independent re-review before integration.

## User runtime checks after fixes

1. Receive Charge and Nova while running in permitted PvP; verify movement and
   jump stop, falling still works, and motion resumes normally after expiry.
2. Charge during held swing/bow draw and attempt a cast while stunned; verify
   no pending attack or catch-up burst. Kings/dragons remain stun-immune.
3. Overtake threat during Taunt, stop attacking, and check switching after the
   unchanged three-second window; evading targets refuse Taunt.
4. Aim at standing/walking Ibex heads and horns at several orientations,
   especially a quarter-turn; terrain collision remains unchanged.
