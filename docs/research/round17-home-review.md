# Round 17 HOME independent review

Verdict: **MERGE**, subject to the coordinator's integrated final-byte gates.
Critical: **0**. High: **0**. Medium: **0**. Low: **0**.
Fix round: **0**. Reviewer: native Astra, independent of the implementation.
Elapsed review time: not reliably recorded. No GUI acceptance is claimed.

Reviewed immutable HOME candidate `52600557` against `3d7b80cb` in
`/tmp/grug-r17-home`, under Round 17 plan section A, AGENTS.md,
`wp-workflow.md`, `agent-model-policy.md` and `luanti-lua.md`.
No production files were changed. No subagents, CLI agents, PUC runtime,
world population or broad terrain suites were used.

## Findings

No actionable defect confirmed in the reviewed scope.

## Reviewed boundaries and evidence

- The twelve catalog entries select actual inhabited sockets in the six starts
  and six capitals. Reservation happens after mapgen registry construction and
  before mods-loaded NPC roster construction. Selected capital plots use the
  production terrain-relative socket projector. Dawnmere and Silverleaf diffs
  change socket metadata only; their cell-building code is unchanged.
- Innkeepers reuse villager placement, persistent socket claims and activation
  machinery. Their role installs the service name and stationary behavior,
  excludes the socket from idle wander rings, and routes right-click to HOME.
  Binding rechecks the live entity, socket/location identity, faction, life and
  both player/NPC and NPC/authored-position distances. Dialog identity and
  join/leave/death cleanup reject stale submissions.
- Bound IDs and absolute wall-clock cooldown deadlines are player metadata.
  Binding and respawn do not reset the deadline. Successful return verifies
  the resulting position before charging. Requests recheck session, pending
  identity, destination, faction/race, life, combat and cooldown after emergence;
  timeout, duplicate callbacks, death, rejoin and changed binding cannot settle
  stale HOME work.
- Arrival validation requires loaded safe support and headroom at the fixed
  registry position. Respawn first validates a disk-loaded racial-start pocket,
  then asynchronously attempts the bound destination. Failed home emergence
  leaves the player at that fallback. The explicitly retained faction path
  owns failures to validate the racial pocket. Independently inspected the
  actual six start compositions at the fallback column: all have full ground
  and two air cells. This is source evidence, not an engine-world test.
- Teleports dismount and invalidate combat identity before moving. Inspected
  the integration seam in the coordinator's `grug_core/homing.lua`; its
  generation change invalidates existing homing locks. Engine reference
  `src/server/player_sao.cpp` confirms HP restoration before respawn callbacks
  and rejection of `setPos` while attached. The reference respawn callback
  dispatcher combines results with OR.
- Map providers derive all twelve markers and the selected home from HOME's
  registry. The button shows destination, cooldown or pending state. Existing
  sfinv dispatch routes inventory fields to the current page; Map refresh is
  throttled, bounded to active page sessions, and cleaned up on leave/death.
  Layout, marker overlap and actual click behavior still require GUI acceptance.
- No old-world migration, alias or cleanup mechanism was introduced. No new
  globalstep, per-tick inventory mutation or mapblock scan was added by HOME.

Independent bounded LuaJIT execution of `tools/round17/home_final.lua` passed:
all twelve authored source/arrival checks, HOME runtime scenarios, real
faction respawn callback, registry-backed Map output and extended NPC lifecycle
fixture including innkeeper claim/name/stationary/right-click behavior.
The HOME runtime harness uses simulated engine objects and emergence, so this
does not establish real client or engine-fallback acceptance.

Independently parsed all **17 changed Lua files** with the project's plain
`luac51 -l -p`, including tools. SETGLOBAL output contains only the expected
`grug_home` and `grug_factions` declarations. Five compatibility sweeps over
those changed files found only the existing faction-command parameter string
`throng|accord`; no executable incompatible construct was found.

## Remaining integration and runtime gates

The coordinator must freeze integrated bytes, include HOME with COMBAT's
identity seam, and record the single final PUC/LuaJIT micro-KAT parity pair.
That evidence was pending during this lane review and was not duplicated.

User runtime plan: visit friendly and enemy innkeepers, bind a friendly
capital, return using Map, reconnect and confirm the countdown, then die and
confirm bound-home respawn without resetting it. Check innkeeper presence and
Map label/button layout for all twelve locations. Real fallback-engine
acceptance remains separate.
