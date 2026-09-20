# Round 11 interaction followups

Date: 2026-09-20. Baseline: `cca8b7ce`; branch: `wp11-interaction-followups`.
State: delivered on main (merge `955d7221`), synchronized; push follows the
completion record commit. Implementation: `b2f2d39f`.

## Delivered behavior

- Cast and swing ability clicks share a server-authoritative 4 m pickup ray.
  Skill/race/talent range cannot extend loot reach. The first visible node or
  other object blocks pickup; builtin item callbacks remain authoritative.
- Ground and flying mounts support camera-relative A/D strafing. Horizontal
  diagonals cannot exceed tier speed; reverse alone remains 35%. Existing
  orientation, ascent/descent, land stepping and lifecycle behavior remain.
- An interactive NPC/entity owns a right-click while the mount item is held;
  the same click no longer summons or dismisses the mount as well.

No new recipe, food, crop, talent or art implementation belongs to this fix.
The approved Basics visibility rule is in living design; implementation and
other next-round proposals remain in `TODO-round12-planning.md`.

## Evidence and review

[Independent native Sol review](round11-interaction-review.md): CLEAN, no open
Critical/High/Medium/Low findings. Source hashes, runtime/fixture diff hash,
three passing LuaJIT receipts, parser/SETGLOBAL/five-sweep logs and reference
pins are archived in `tools/r11_interaction/evidence/`.

The final parser checks 328 Lua files, including changed tool fixtures.
Production SETGLOBAL declares only the owning `grug_abilities` table; tool
SETGLOBAL entries are harness scaffolding. Sweep hits are comments, UI strings
and the frozen manifest's string data, not prohibited executable constructs.
All 13 reference pins remain unchanged. No PUC runtime, seed fleet, mapgen or
performance suite was run under the session's explicit test-budget override.

The combat integration fixture needed current-contract scaffolding repairs:
armor rating replaces the removed percentage accessor, mob mocks expose
`get_hp`, and adjacent animation/inventory dependencies have minimal stubs.
Its existing combat expectations remain, and cast pickup now queues the real
server-ray fixture. The final integration log passes.

Calibration: native GPT-5.6 Sol implementer and independent native GPT-5.6 Sol
reviewer; root GPT-6 Astra coordination, fixture repairs and documentation.
Final Critical/High counts: 0/0; Medium/Low: 0/0. One pre-freeze movement
correction restored flight reverse scaling; one fixture-repair cycle resolved
stale harness dependencies, with several targeted diagnostic runs. Observed
elapsed wall time: unknown. No Claude or same-provider CLI delegation.

## User runtime acceptance

After restarting Luanti:

1. With Smite and another ability, click dropped items inside and outside 4 m;
   only nearby visible items are collected. A wall must block the pickup.
2. Test A/D, W+A/W+D and S on ground and flying mounts. Sideways travel works,
   horizontal diagonals do not gain speed, and reverse stays slower.
3. Right-click a trainer while holding a mount: only the NPC UI opens. Close it
   and use the mount in the air to confirm ordinary summoning still works.

The vegetation chase correction was separately accepted by the user in GUI.
New interaction visual/GUI acceptance remains pending; no user world is edited.

Delivery verification: all 1,900 installed runtime files match main
byte-for-byte. Workers are finished. The next action is the focused user
playtest above and discussion of the next-round scope.
