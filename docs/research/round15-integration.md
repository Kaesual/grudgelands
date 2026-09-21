# Round 15 isolated native integration

Status: PASS, 2026-09-21. Runner: `tools/r15_integration/run_native.py`.
Evidence: `tools/r15_integration/evidence/` (compressed original logs, complete
production/executed snapshot hashes, summary and index).

The installed Flatpak Luanti ran an isolated game/world snapshot in
`/tmp/grug-r15-integration-fsu8de6_`, seed 8675309, one emerge worker, loopback
port 32987. All 2,045 production snapshot files match the final repository
payload exactly. No user world was opened or changed.

Scratch-only differences: disable the preparation scheduler's dispatch while
retaining initialization; log entry into actual `r7_manifest.new` and
`planner.plan_slice`; add the integration probe (init and mod.conf). No mapgen,
blueprint, registry, NPC or terrain semantics were replaced. The test generated
exactly three mapchunks; the log records exactly three planner calls.

## Observed result

- Actual initialization validates 102 quests / 30 giver identities against all
  authored sockets, including all six new village `quest_local` sockets.
- Starbough village: 5,184 loaded authored cells; three of three NPCs alive.
- Copperfell outpost: 2,303 checked cells plus preserved guard-banner root;
  one of one NPC alive.
- Copperfell camp: 5,183 checked cells plus preserved camp-fire root;
  one of one NPC alive.
- Every checked cell matches its authored node; applicable orientations match.
  Sockets have support and free feet. Every authored quest giver in each selected
  POI is live with its exact registered title, including both village givers.
- Result: `PASS three_chunks=3 catalog=102/30`; clean requested shutdown, no
  server error. Native manifest identity:
  `f920b8c5fac373467a42123fa8fba0187611fbb179122adc43b5978dc163974e`.

This supplies actual manifest/planner and roster integration evidence rather
than treating copied test sockets as placed NPCs. All 18 compositions separately
pass the bounded geometry fixture, including every top-ladder landing's solid
support and two-node standing clearance. Its final digest is
`r15_poi_v1 18 76032 972310740`.

The native probe does not exercise multiplayer UI, actual player climbing,
external spur/collar walkability, final visual terrain blending or full-world
preparation. GUI acceptance remains in the Round 15 playtest. Full-world or
historical population tests were deliberately not run.
