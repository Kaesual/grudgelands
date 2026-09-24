# Round 20 combat presentation and reset audit

Author: root GPT-6 Astra. Date: 2026-09-24.
Status: code prepared; independent review and final runtime gate pending.

## Changes

Accepted stuns create one bounded golden-star particle burst above the target,
at the shared player and mob stun seams. Dead/immune targets emit none. Charge's
old unconditional smoke burst is removed so one accepted stun has one effect.
No duration, immunity, damage or movement rules change. Stars use a procedural
texture; no new media license or entity lifecycle is needed.

Shore Crab and its shared Reef Lurker definition no longer supply the two-second
death clip. The existing mobs_redo ordinary death/removal path still owns loot,
XP and kill credit (`mods/ENTITIES/mobs/api.lua:845`).

## Investigated reports and limits

Bandits have no healing skill/custom combat callback. They are camp-owned and
retain the approved 25-node chase-anchor leash and 15-second contact timeout.
An authoritative leash reset heals immediately, even during a fight if the
camp boundary is crossed. Ordinary idle recovery needs 30 seconds with no
attack target/state or HP loss; a brief missing target is insufficient. All
accepted player hits, including ability hits, update the camp contact clock.
No confirmed implementation defect was found in these paths. Do not silently
remove camp bounds to mask a report that may describe their intended reset.
The final fixture covers sustained contact, a short target gap and a genuine
boundary reset. GUI reproduction remains useful for the reported midfight heal.

Registered mobs already have `collide_with_objects=false`
(`mods/ENTITIES/mobs/api.lua:4044`). Luanti only adds actor collision boxes when
that flag is enabled (`reference_projects/luanti/src/collision.cpp:471`). No
wrapper/visual update was found restoring it. Ordinary physics cannot therefore
support one such mob on another; terrain differences, jumps and overlapping
rendered bodies can look stacked. No unproven collision toggle, broad separation
AI or pathfinding redesign is added. The visual report remains unconfirmed and
needs a concrete in-game case to distinguish those mechanisms.

## Verification

All changed Lua parsed with Lua 5.1. SETGLOBAL retains only the existing
`grug_mobs` declaration. Five sweeps reviewed: the single bitwise-like match is
an existing type-list comment in init.lua; no executable finding. No runtime
executed during implementation. `tools/r20/combat_micro.lua` is prepared for
the single final interpreter pair and loads the real movement/mob/aggro/idle
modules with bounded engine doubles.

GUI acceptance: Charge a susceptible mob, guard and enemy player; verify one
visible effect and unchanged stun duration. Verify immune bosses have none.
Kill a crab and check ordinary removal/loot. Fight a bandit within its camp,
then deliberately pull beyond its leash and distinguish reset behavior. Report
coordinates/species for any persistent actor stack or in-bounds instant heal.
