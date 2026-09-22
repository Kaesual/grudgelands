# Focused independent review — Round 16 B corrections

Verdict: **CLEAN**, subject to the coordinator's final integrated static/parity
gates and user runtime acceptance. Reviewed `9e84458c` atop `be2cc9b9` in
`/tmp/grug-r16-combat`. The original **High movement** and **Medium Ibex**
findings are both resolved; no new findings.

## Movement correction

The shared writer now distinguishes logical zero speed from the engine control
representation: physical `speed = 1`, zero walk/fast/crouch/climb targets, zero
jump, and finite strong acceleration. This removes the original zero-braking
failure without client velocity subtraction or position resets. Traced all
locomotion target branches in pinned `localplayer.cpp:570–695`, acceleration at
`:704–732`, clamped velocity adjustment at `:784–824`, and minimum slippery
factor at `:1153–1167`. The air branch retains `incV = 0`; gravity remains
unmodified for combat root/stun. The multiplier is carried as an ordinary finite
F32 in `player_sao.cpp:311–340`, not truncated through an integer wire field.

The seven owned fields are a deterministic function of logical speed, so the
ordinary existing speed/jump/gravity cache correctly covers them without seven
additional state keys. The forced watchdog compares every owned physical field
and repairs corruption. Expiry, root clearing, immunity, stun/root overlap,
exclusive hold release and death cleanup all return through the same writer;
locomotion and acceleration multipliers return to one. The repository has no
other `set_physics_override` writer. Join/leave still discard runtime state;
the engine's physics override fields are runtime player state with defaults of
one, not persisted character data. No old-world repair or migration was added.

The correction creates no per-frame API write loop: unchanged ordinary updates
return before constructing/sending the extended override. Existing forced holds
read and compare their owned fields and only write on mismatch.

## Ibex correction

The Ibex's selection box explicitly carries `rotate = true`; the engine parses
that table flag (`c_content.cpp:369`) and applies entity rotation to authoritative
ray-box intersection (`serverenvironment.cpp:1368`). The separate collision box
is unchanged. Mobs registration retains the table in both initial properties
and `base_selbox`; activation writes that base table back. The marked vendored
`scale_mob` change also retains the flag through temporary and permanent scaling.
Current-version staticdata preserves the base table and its boolean field.

## Evidence and limits

All 15 refreshed source hashes in `tools/r16_combat/evidence/inputs.sha256`
match the corrected tree. Read the updated bounded control fixture and recorded
LuaJIT control/movement/full-integration PASS evidence. New assertions use the
actual production overrides with the engine's horizontal clamp equation, include
200-fps moving ground/air/fast cases and minimum slip, verify restoration and
root/stun/hold/watchdog overlap, and exercise the real mob scaling function plus
oriented Ibex head inclusion. Read refreshed parser/SETGLOBAL/five-sweep evidence;
`git diff --check be2cc9b9 9e84458c` passes and tracked worktree status is clean.

No production edit, commit, PUC runtime, native server/world, GUI test or
duplicate runtime suite was performed by this reviewer. The bounded arithmetic
fixtures and source inspection do not prove client/network presentation; the
real moving-client check remains explicit. The coordinator's one final combined
PUC/LuaJIT pair must include these corrected bytes.

Calibration: implementing model native Astra; independent review agent
`/root/r16_review_combat` (launch model recorded by coordinator); original
**0 Critical / 1 High / 1 Medium**, now **0 unresolved findings** after **1 fix
round**; observed elapsed wall time **unknown**. The reviewer authored none of
the implementation or correction.

User runtime check: receive Nova/Charge while already running, falling and
crossing slippery ground; horizontal movement and jumping stop, airborne falling
continues, and controls recover at expiry. Repeat pending swing/bow cancellation.
Aim at an Ibex's head/horns after quarter-turns and check unchanged terrain
collision.
