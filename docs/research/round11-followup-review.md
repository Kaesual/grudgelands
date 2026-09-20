# Independent review — Round 11 playtest follow-ups

Reviewer: native Sol (`r11_followup_review`)
Baseline: `28b118c4`
Branch: `wp11-playtest-followups`
Disposition: **PASS — no open findings**

## Findings

No High, Medium, or Low findings remain in the frozen reviewed scope.

One documentation inconsistency found during review was corrected before this
disposition: `docs/design/skill_trees.md` now derives 6.0 nodes/s from the
amended +50% Scout Sprint instead of retaining the old 5.0 result. Editorial
spacing in the follow-up execution record was corrected at the same time.

## Contract review

- The Scout arrow uses a rigid imported OBJ and dedicated texture, with
  `visual_size.x = -1` and runtime velocity orientation matching the pinned
  VoxeLibre formula and Luanti's actual `core.dir_to_yaw` convention. Launch
  and gravity-updated orientation are covered by the focused visual fixture.
  Projectile collision, ownership, token settlement, damage, range, and
  ammunition transactions remain on the existing foundation.
- The bow draw keeps the accepted LMB hold/release input. Three draw stages
  ride the existing bounded 0.05-second update and compare-first stack writes.
  Release, cancellation, equipment replacement/breakage, death, leave, and
  reconnect paths clear draw state and restore the concrete equipped bow
  image. The vendored `player_api` hook only overrides the server-visible
  `mine`/`walk_mine` pose while an active draw exists. The documented initial
  first-person LMB camera impulse is an accurate client-engine limitation.
- Arrow OBJ and PNG licenses are distinguished correctly (CC BY-SA 3.0 and
  CC BY-SA 4.0 respectively); the three VoxeLibre draw sprites are attributed
  as unchanged CC BY-SA 4.0 copies. `VENDOR.md` and the in-place GRUG patch
  marker cover the `player_api` modification.
- Highcourt and the other five capitals share the corrected trainer placement
  path. Readiness can be established by a loaded anchor, a loaded authored
  socket block, or a persisted current-version socket marker, while each NPC
  still requires its own loaded node. This covers core-to-outer travel,
  restart beside an outer district, and direct first arrival without enabling
  placement in unloaded or unauthored terrain. All 48 profession sockets are
  present in the real six-capital service catalog.
- Each Leatherworker service has one interior armor display and one exterior
  combined leather/armor display, using the existing protected fixed-display
  contract.
- Mount T3/T4 catalog values are 8/12 nodes/s (+100%/+200%). Runtime movement,
  mount status, and descriptions consume those catalog values; T1/T2 remain
  6.4/8.
- Scout Sprint applies +50% for 10 seconds with a 300-second cooldown and the
  living docs consistently derive 6.0 nodes/s under the existing 1.5 cap.
- Arrow `stack_max`, Scout starter quantity, and living design are 200. Empty
  main-inventory capacity now asks the registered arrow ItemStack for its
  stack maximum. The focused boundary proves one empty slot accepts 200,
  rejects 201 atomically, and preserves full-inventory/refund behavior. Four
  quiver slots therefore hold 800 arrows; recipe output remains 20.

## Evidence inspected

- Frozen bow SHA-256 manifest: every listed file matched
  `../../tools/r11_followup/evidence/bow-inputs.sha256`.
- Frozen trainer hashes matched `round11-followup-trainers.md`.
- Retained focused receipts under `tools/r11_followup/evidence/`: arrow visual,
  actual Scout talent/dispatcher consumer, projectile regression, trainer
  lifecycle, six-capital services, mount consumer, and ammunition boundaries
  all pass.
- Final static receipt: `luac51 -p` passed 332 Lua files; SETGLOBAL output was
  limited to declared mod tables and isolated fixture globals; all five Lua
  sweeps were manually classified; `git diff --check` passed.
- All 13 initialized reference projects remain at their pinned commits with no
  `+`, `-`, or `U` submodule marker.

Per the session override, I did not run PUC runtime, broad mapgen/resource
populations, performance suites, or duplicate unchanged runtime gates. No user
world was accessed. Final pixel scale, arrow direction/appearance, draw-stage
colors, and feel remain the user's post-restart GUI playtest gate.
