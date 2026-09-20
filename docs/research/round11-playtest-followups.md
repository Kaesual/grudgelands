# Round 11 first playtest followups

Date: 2026-09-20. Baseline: `28b118c4` on main.
Branch: `wp11-playtest-followups`. Status: independently clean; final integration pending.
User explicitly authorized fixing these points while continuing the playtest.
No user world edits; existing fresh-server policy remains. Native Sol workers,
root orchestration and independent native Sol review; no Claude/own-provider CLI.
The session's minimal LuaJIT/no-PUC-runtime test override remains in force.

## User findings and accepted changes

1. Scout arrow flies as a camera-facing inventory sprite. Use a real directional
   projectile appearance with its tip following instantaneous flight velocity.
2. Held bow draw/release is correct, but its melee swing presentation is wrong.
   Read pinned VoxeLibre and Luanti sources, then implement an appropriate held
   draw presentation without changing LMB hold/release or authoritative gameplay.
3. Highcourt appears to lack Cooking and Woodcarver trainers. Trace actual
   sockets, spawn validation and current-world lifecycle; repair the underlying
   defect and check the same service path across all six capitals. The professions
   already exist; an empty house is not evidence that a profession is absent.
4. Leatherworker premises need a leather icon alongside their armor display.
5. T3 flying speed becomes +100% (8 nodes/s), T4 +200% (12 nodes/s), relative to
   ordinary 4 nodes/s walking. T1 +60% and T2 +100% remain unchanged. Derived
   mount status, velocity and item descriptions consume the shared catalog.

**User GUI acceptance:** the beach column/edge defects are fixed and look good.
The first-pass reported-defect checklist otherwise passed, except the potential
missing profession trainers. Remaining equipment/farming/Scout testing continues;
this is not blanket acceptance of those systems.

6. Subsequent user steering: Scout Sprint grants +50% movement speed, with
   matching skill description; retain 10s duration, 300s cooldown, 15% base-mana
   cost and the existing movement cap.

7. Subsequent user steering: player arrows stack to 200, and a newly created
   Scout receives 200. The arrow craft still yields 20; the four-stack quiver
   therefore holds up to 800 arrows.

## Ownership and gates

- Native Sol `r11_scout`: bow/arrow presentation and narrow projectile visual
  seam, reference media provenance, targeted actual-consumer checks.
- Native Sol `r11_repair_review`: trainer placement/spawn and Leatherworker
  exterior display, targeted shared-capital service checks.
- Root: mount catalog numbers, 200-arrow stacks/starter and quiver capacity,
  living design/status and integration.
- Independent native Sol `r11_followup_review`: read-only review of all frozen
  changes, with engine-contract and license checks.

Use the pinned reference sources, no speculative engine workaround. Preserve
current aim, projectile collision, damage, all Scout talents, atomic ammo and
settled wear semantics. Check parser, SETGLOBAL and all five static sweeps on
changed Lua including fixtures; use only the affected bounded LuaJIT fixtures.
No beach rerun, seed fleet, resource census, PERF run or PUC runtime. Final media
and bow feel remain user GUI checks. Merge/sync/push after a clean independent
review, then report which changes require restarting Luanti.

## Delivery checkpoint

All implementation slices are frozen and the [independent review](round11-followup-review.md)
is PASS with no open findings. Final focused LuaJIT/static gates pass. Main
merge, synchronization and push remain the final delivery step.

Calibration: implementers native GPT-5.6 Sol (bow/trainer) and root GPT-6 Astra
(catalog/ammo/integration); independent reviewer native GPT-5.6 Sol. Zero
confirmed production Critical/High findings; one working-fixture integration
failure was corrected before freeze, together with two Medium bow evidence/media
corrections and one derived-speed documentation correction. One final review
cycle with incremental corrections; observed total wall time unknown.

## Accepted slices

Mount numbers and the shared trainer/display correction have passed independent
native Sol review with no findings. The existing compact mount fixture passes
with T3 +100%; T4 uses the same catalog velocity/status consumers at 12 nodes/s.
The shared NPC placement gate previously required the core and each outer shop
block to be loaded simultaneously. Current-version readiness now latches from
the loaded anchor/any authored socket block, with persisted current-world socket
markers restoring it after restart; each individual NPC still waits for its own
loaded block. The actual-consumer regression covers core→outer, restart and
direct first outer arrival, and the real capital catalog verifies 48 trainer
sockets across all 6 capitals. Raw logs are under tools/r11_followup/evidence/.

Pinned VoxeLibre charges on RMB/zoom and swaps three visible bow stages. Luanti
client game.cpp:2809–2810 unconditionally starts the camera dig animation on a
fresh LMB press. Our accepted LMB hold/release remains; a brief initial native
first-person impulse cannot be suppressed server-side. The bow slice provides
held-draw presentation and third-person animation without claiming to remove
that engine behavior or adding a client mod.

## Final focused evidence

- [Bow implementation/reference report](round11-followup-bow.md), with frozen
  media/source hashes and the explicit first-person engine limitation.
- [Trainer/display implementation report](round11-followup-trainers.md).
- `tools/r11_followup/evidence/`: existing compact mount fixture, actual capital
  service construction and NPC lifecycle, projectile foundation, arrow/actor
  presentation, actual Scout talent/dispatcher consumer and ammo transactions.
  All focused LuaJIT checks pass. Quiver removal additionally proves that one
  empty destination accepts 200 arrows and refuses 201 without mutation.
- Final static gate: 332 Lua files parsed with plain-5.1 `luac51`; changed tools
  and vendor files included. SETGLOBAL contains only declared mod tables and
  intentional isolated fixture globals. Five sweeps have no forbidden code:
  matches are comments, string data, the frozen manifest and unchanged vendored
  `minetest` calls. Thirteen reference submodule pins are unchanged.
- No PUC runtime or new broad engine/mapgen suite. The earlier Round 11 native
  engine witness remains historical; these followups still need GUI confirmation.
