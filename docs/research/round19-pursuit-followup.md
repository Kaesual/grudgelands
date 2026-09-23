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

Status: pursuit implementation/review PASS; idle recovery implementation frozen
at `edabd948`; independent review found an attack-acquisition ordering hole in
shared boss recovery. The author is fixing it before focused re-review.
Main merge/local sync after independent
review and final gates. User runtime checks: let a melee and ranged mob attack
while standing still for over 15 seconds; then move without dealing damage;
repeat while another player periodically damages the mob.

## Additional approved scope: safe idle full healing

The user additionally requested full recovery for idle mobs, guards and bosses,
explicitly warning against accidental immortality. Native Sol preflight found
that the participation ledger cannot safely define an active encounter, and
there is no common all-source damage clock. Implement HP sampling plus 30 seconds
of continuous calm at the existing maintenance cadence; use the normal reset
transaction only for living damaged actors. Any HP loss, attack target/state,
evade or pending attack prevents recovery. Share actual recent activity across
boss members, including summons/royal follow, without using a stale loot ledger
or scanning the world. This adds no outgoing-attack refresh to pursuit's separate
incoming-damage clock. Activation starts a fresh quiet period; no migration.

Native Sol author `idle_heal_preflight` owns this additional implementation;
separate native Sol reviewer follows. Existing pursuit correction at `ecec014a`
already independently PASS (zero findings), report round19-pursuit-review.md.
Final interpreter pair waits for both changes to be frozen, avoiding repeated
intermediate PUC runs. Add a compact real-module idle-health fixture for target
gaps, continuing combat, repeated environmental/DoT damage, dead actors and
shared boss activity. No native-world or performance campaign.

## User runtime acceptance

- Restart Luanti to load the installed code. Let a melee and ranged ambient mob
  attack a stationary character for more than 15 seconds without retaliation;
  neither should abandon that stationary target because of the damage timer.
- Start moving after that grace without damaging it: it should return home.
  Repeat while another player or eligible guard damages it periodically; those
  hits keep the pull alive. Authored guards/bosses keep their bounded policy.
- Observe an injured idle ordinary mob and guard for about 30 seconds: each
  returns to full health. Continued combat or repeated HP loss prevents this.
- In a boss encounter, engage a retinue member while the leader is wounded:
  the new idle recovery must not heal/reset the group during that fight.
  Check the group can recover after the whole encounter becomes quiet.
