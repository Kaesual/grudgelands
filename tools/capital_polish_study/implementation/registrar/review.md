# Independent Registrar relocation review — 2026-11-10

Reviewer: `tables_study`, independent of the coordinator's implementation.
Verdict: **MERGE**. No blocking findings. **Map reset** is the correct
classification for changing the authored core socket census and relocating its
resident. This review does not approve an online migration or replace native
client acceptance.

## Scope and findings

Reviewed the six `wp13/<capital>.lua` additions, the narrow
`grug_expeditions/registrar.lua` binding change, the registry comment, and the
`r70_cap`/`r71_ui` fixture updates. The capital diffs add only one inhabited idle
socket each; they make no node writes or layout changes for the Registrar.

| Capital | Local position | Authored facing | Horizontal distance to waystone |
| --- | --- | --- | --- |
| Highcourt | (12,1,-12) | 2 / -Z | 14.14 nodes |
| Dur Brannoc | (12,1,-12) | 2 / -Z | 12.21 nodes |
| Gor Drazhak | (12,1,-12) | 2 / -Z | 12.21 nodes |
| Nhal Veyr | (12,1,-12) | 2 / -Z | 12.21 nodes |
| Lethariel | (28,1,-25) | 0 / +Z | 11.40 nodes |
| Kezamba | (-36,1,-33) | 0 / +Z | 9.22 nodes |

Distances independently computed from each composition's `PLAZA` midpoint.
All six points lie outside the entire authored plaza (including its boundary
kerb), not merely outside the inner `waypoint_plaza` landmark. The four common
positions are one cell west of the plaza edge; Elf/Troll positions are five and
three cells south of their plaza edge respectively. Their facing points along
an accessible approach, rather than into a wall.

The final fixture's existing T/W checks cover the actual generated standing
surface and the route from the crossing. New E checks additionally ensure the
front neighbour is reached, the Registrar is outside the pad including kerb,
within 15 nodes of the waystone, and at least two horizontal nodes from every
other core socket. These checks run for all six completed cores. The player body
model is 1.7 nodes tall; this is a geometry/reachability fixture, not execution
of the live NPC pathfinder.

## Service routing and spawn

- Core sockets keep unprefixed IDs in `r7_settlement.lua:M.sockets`; only district
  plots receive a `<plot>/` prefix. Therefore `expedition_registrar` is the right
  registry ID for the new location.
- Every addition is an `idle` socket, omits `spawn=false`, and carries `work`.
  `settlement_sockets.lua:assign_service_socket` requires exactly that inhabited
  idle shape and takes it over for the Registrar role. Duplicate IDs are already
  rejected by registry compilation.
- All six existing capital keys are registered in sorted order. The service
  resolver still returns the capital's own villager race.
- Capital boundary conversion uses `parts.facedir_step` (0=+Z, 2=-Z); the
  corresponding fixture table matches it. `socket_face_yaw` only reverses the
  `door` tag; these `work` sockets retain the authored facing.
- Existing `start_npcs.lua` service setup gives the resident its Registrar name
  and `_grug_walker=false`. Existing right-click handling, own-faction checks,
  reach limit, UI state and Expedition rules are unchanged.
- The former `miners_guild/miners_guild_clerk` is no longer assigned a service
  role, so it remains an ordinary resident. The UI fixture explicitly checks
  that the clerk and sorter stay idle, while only the dedicated socket gets the
  service role. No stale `registrar.CLERK` consumer remains in Lua.
- `grug_expeditions` already depends on mapgen/mobs/core; no load-order dependency
  was introduced. No unrelated current-main Expedition UI code was imported.

## Validation evidence reviewed

Read the completed coordinator-run logs without repeating either run:

- `core-check.log`: **R70 CAP PORTABLE PASS checks=3291**.
- `ui-check.log`: **R71 UI PORTABLE PASS checks=127**.

The new socket's exclusion from the old Round 70 study schedule comparison is
narrow: only `expedition_registrar` is exempt; existing socket rows still have
their normal location checks. New E assertions cover its actual placement.
The UI test exercises the real socket registry and existing dialog behavior.

Release metadata, broader docs, full Lua/template gates and desktop/web
acceptance are coordinator-owned and outside this bounded review. No production
file was changed by the reviewer and no duplicate tests were run.

## Appendix — final release metadata and documentation review

Verdict: **MERGE**, no blocking findings in the reviewed additions.
Reviewed only the new capital-polish/release passages, not the earlier character
creation documentation work.

- `game.conf`, the newest changelog heading and `upgrade.json` consistently name
  provisional **0.72.3**. Its unreleased, unmerged worktree status is explicit in
  the changelog, README and STATUS; integration must retain current main's work
  and reconcile the patch number if main advances.
- Compared the declaration read-only with main's **0.72.2** declaration. Every
  existing map-reset and migration entry is retained. The only added reset is
  0.72.3; no unsupported migration or new-server requirement is introduced.
- Map reset covers changed authored buildings and the Registrar socket census;
  the text correctly distinguishes that from the creation UI's presentation
  change and declares no bespoke migration step.
- The settlements additions agree with the implemented throne, joined piers,
  lowered ridge, filled gable gaps, five gate corrections and six thin-table
  replacements. Preserved sockets/footprints and pending native chase acceptance
  are described without claiming a live pathfinding test.
- The dedicated Registrar location and ordinary guild clerk now agree between
  settlements and expeditions. Old Round 71 history is identified as historical;
  STATUS explicitly warns integration to retain main's newer Expedition UI.
- Reviewed `r70_cap`'s final failure-path adjustment: replacing `print` +
  `os.exit(1)` with `error(message, 0)` retains a nonzero process failure and the
  complete diagnostic while satisfying the Lua sweep. Success behavior is
  unchanged.
- Read existing coordinator evidence, without rerunning gates:
  `../upgrade.log` PASS, `../version-check.log` 974 PASS, and `../lua-check.log`
  all ten changed Lua parsers plus six sweeps PASS.

Minor editorial suggestions were sent to the coordinator: update STATUS's old
header date; call the arch pieces inverted stairs at upper passage corners
(rather than wording that could imply the distinct `stair_inner` node shape);
remove one extra blank line in README. These do not affect implementation.
The linked overall implementation README was still being authored by the
coordinator at review time; final link existence/checklist consolidation remains
with that author. No global tests were rerun and no production/docs file was
edited by the reviewer.
