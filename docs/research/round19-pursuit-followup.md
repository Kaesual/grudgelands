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

Status: implementation and independent review PASS at `033d894f` (production `87423283`) after one
idle-recovery fix round. Technical evidence is recorded below; local integration
and GUI acceptance are tracked separately.

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

## Final technical evidence and review

- Pursuit author native Sol; independent native Sol review at `ecec014a`:
  0 Critical / 0 High / 0 Medium / 0 Low, no fix rounds.
- Idle recovery author native Sol; independent native Sol review:
  one High (post-sample target acquisition could let a peer reset), corrected
  at `87423283` and focused re-review PASS; one production fix round plus one final-harness correction, no open findings.
- Root native Astra coordinated and updated living docs; no provider CLI.
  Observed elapsed wall time: unknown. Pre-review clock propagation fixes
  separated actual group activity from local activation/post-heal grace.
- Review records: [pursuit](round19-pursuit-review.md),
  [idle recovery](round19-idle-health-review.md).
- Plain Lua 5.1 parser, expected SETGLOBAL inventory and all five static sweeps
  PASS on changed Lua. The two compact fixtures load actual registration,
  vendored attack/damage paths, pursuit/reset, idle recovery and boss lifecycle.
- The first final PUC attempt failed on a test-environment binding error before
  parity comparison. Corrected fixture `033d894f` supplies the real inherited
  attack method and damaged peer setup; prior standalone PASS claims are withdrawn.
  One replacement frozen PUC-5.1/LuaJIT pair PASS with byte-identical output:
  SHA256 `cf8a99b5aaec803e92c723248fa9991bf3bb102f992712522e3e366236e14c53`. Timings 0.008284/0.011987 seconds.
  Evidence and source hashes: `tools/r19_pursuit/evidence/`.
  No headless world, performance campaign or broad population tests were run.

## Local installation receipt

Merged to local main as `ebe221fed232f209f8ed8e330c7a26b1d56e6e79` and synchronized with
`tools/sync_to_luanti.sh` on 2026-09-23. Complete installed mods/menu trees and
game configuration files match checkout by content. No personal world changed;
this follow-up was not pushed. Independent reviewer verified all 11 final input
hashes and matching output files without duplicating runtime tests. GUI acceptance
remains the user checklist above.
