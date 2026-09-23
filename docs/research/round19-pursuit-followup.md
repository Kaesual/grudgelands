# Round 19 follow-up — movement-gated ambient return

2026-09-23. User-approved implementation, baseline `afca15a2`.
Branch `fix/ambient-pursuit-movement`. Root native Astra orchestrates; native Sol
implements aggro.lua and the existing compact pursuit fixture; a separate native
Sol reviews code and living-document consistency. No provider CLI.

## Approved behavior

Only ordinary ambient combat mobs change. Existing initial-aggro grace and
effective incoming HP damage from any player or eligible guard govern the
15-second clock. Mob outgoing attacks/hits, taunt and threat alone do not reset
it. Once expired, a live current target must move noticeably horizontally before
the mob returns home. Standing still never resets the clock; sideways/circular
motion counts, and moving after a long standstill can immediately cause return.
No direction/radial distance test: a mob can be faster than its fleeing target.

Use the existing one-second leash check and squared X/Z displacement of the
target, threshold 0.25 nodes per sample. First sample/target switch only seed
the comparison. Keep data in runtime temp; clear at encounter reset/death/loss.
Dead/unavailable targets and expired abandoned no-target encounters retain
cleanup, including temporary pack flight. No new searches, pathfinding, terrain
loads, global loops, square roots or saved-state migration.
Bosses, guards, camps, location-bound rares and bespoke actors keep their rules.

## Validation and delivery

Update existing `tools/r18_evade/micro.lua` to exercise stationary targets beyond
15 seconds, movement afterward, incoming damage from another player/guard,
vertical-only/jitter motion, target switch, long pulls, return cleanup and the
unchanged authored-encounter bounds. Preserve actual vendor damage settlement
coverage. LuaJIT development only; changed Lua parser/SETGLOBAL/five sweeps.
After independent review, one compact final PUC/LuaJIT pair with identical
canonical output. No native world, performance campaign or broad test fleet.

Status: implementation in progress. Main merge/local sync after independent
review and final gates. User runtime checks: let a melee and ranged mob attack
while standing still for over 15 seconds; then move without dealing damage;
repeat while another player periodically damages the mob.
