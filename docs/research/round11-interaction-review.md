# Independent review — Round 11 interaction follow-ups

Date: 2026-09-20  
Baseline: `cca8b7ce`  
Branch: `wp11-interaction-followups`  
Reviewer: native GPT-5.6 Sol (`vegetation_review`), read-only and independent of implementation

## Verdict

**CLEAN — no open Critical, High, Medium, or Low findings.**

The frozen implementation correctly addresses all three interaction defects.

### Ability-item loot pickup

Cast and swing ability items now share one server-authoritative 4 m eye ray. The cast path treats the client object reference only as an indication that the click targeted a builtin drop, then reacquires the physically first visible result. Nodes and non-item objects remain blockers, blocker ties beat a drop, range talents cannot extend pickup reach, and a loot click does not cast. The shared helper still invokes the builtin item entity's `on_punch`, preserving the engine pickup callback/inventory/removal path.

The helper is assigned before `kits.lua` and `scout.lua` register runtime ability callbacks, so the forward local is initialized before any item use. The bounded ray replaces duplicated authority without adding a globalstep or proximity scan.

### Mount movement

Land and flight controllers now derive forward/backward and strafe input from camera yaw. Cardinal W and A/D retain full tier speed, S retains the existing 35% backpedal speed, and mixed input is normalized with the dominant axis as its speed scale. W+A/W+D cannot gain diagonal speed. Both controller paths apply the returned scale; the pre-freeze flight omission was corrected, and focused coverage now includes flight and land backpedal, strafe, and forward diagonal cases.

The existing land acceleration, jump, gravity, flight ceiling, vertical flight controls, attachment orientation, warning probes, and lifecycle paths remain unchanged.

### Mount item versus NPC right-click

Pinned Luanti `src/network/serverpackethandler.cpp:1189-1215` invokes the wielded item's `on_secondary_use` for an object click and then invokes the surviving object's `rightClick`. The new mount secondary callback therefore defers when the pointed Lua entity exposes `on_rightclick`; mobs_redo copies the authored callback onto its live entity. The NPC/trainer receives the same click while the held mount stays inactive. Air/non-interactive use continues through the existing owner and tier checks. The server has already rejected a gone object before this callback, and it checks again before object dispatch.

## Evidence reviewed

- All six frozen production/fixture hashes in `/tmp/grug-interaction-final.sha256` and `tools/r11_interaction/evidence/source-inputs.sha256` match the checkout.
- Runtime-and-fixture diff SHA-256 is `c0c1359ffff469cba7d237126c964e01ab77a64773f9de4bfd5a8cb687f98953` and matches the reviewed baseline diff.
- Focused LuaJIT receipts pass for pickup authority, mount/NPC interaction and movement, plus the repaired broad combat integration fixture.
- The broad fixture failures encountered during review were stale harness seams: armor percentage versus current rating, missing mock `get_hp`, and adjacent animation/inventory globals. The fixture-only corrections restore current production contracts; the final log ends `combat_integration_test: ok`.
- Static evidence reports 328 Lua files parsed by `tools/bin/luac51 -p`; production `SETGLOBAL` contains only the declared `grug_abilities` mod table; tool globals are harness scaffolding. All five sweeps were inspected with no prohibited live construct. `git diff --check` passes and all 13 reference pins are unchanged.

No PUC runtime or broad unrelated suite was run, following the session's explicit test budget. Remaining acceptance is visual/runtime: verify Smite and another long-range cast pick up visible drops only within 4 m; confirm walls/objects block pickup; ride land and flying mounts with A/D, W+A/W+D, and S; and right-click a trainer while holding a mount to confirm the UI opens without mounting.
