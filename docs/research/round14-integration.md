# Round 14 bounded native integration

Status: PASS on the frozen visual-polish candidate, 2026-09-21.

`tools/r14_integration/run_native.py` stages an immutable game snapshot under
`/tmp/grug-r14-integration-*`, hashes every production file before instrumentation
and every executed file afterward, and runs Flatpak Luanti with isolated user,
world and XDG directories. The seed is 8675309. This does not synchronize or
access the user's worlds. The process has a 150-second external deadline and
the probe a 110-second runtime deadline; no PUC interpreter runtime is used.

Only the staged preparation scheduler's local `stopped` initial value changes
from false to true. Its initialization and public APIs remain installed, but it
cannot start a world/start population. Two staged, observation-only log calls
record entry into actual `r7_manifest.new` and `planner.plan_slice`. All content,
terrain, writer, NPC and quest behavior remains the production implementation.

The probe validates the complete live quest registry (66 quests, 24 NPCs), then
chooses one village, one outpost and one camp whose authored cells fit entirely
inside one native mapchunk each. It emerges exactly these three mapchunks,
compares every authored node name except each reserved functional root, verifies
the expected guard banner/camp fire survives, checks socket air/support, and
force-loads only socket blocks in the scratch world to verify live NPC roster
counts and catalog-derived quest NPC titles. The exact authored-cell comparisons
also reject ground burial or incorrect vertical placement inside these samples.

This gate does not certify all seeds, every POI's native placement, full-world
preparation, real player UI interaction or the engine's PUC fallback build.
The portable final interpreter parity belongs to the coordinator's separate
final-byte gate. The GUI runtime check remains user-operated.

Harness checks: Python compilation, plain Lua 5.1 parser, no `SETGLOBAL` writes,
and all five Lua source sweeps passed for `probe.lua`.

## Frozen native result

The successful isolated run is `/tmp/grug-r14-integration-aau_zxlw`.
Production manifest identity:
`32bf97f4f7734c0d21cce5dad27ecda3c29e57346afcd7b33ad7e93abc20c023`.
The frozen POI builder SHA-256 is
`9ec5a39106ed94b55f2dab0ba4d718acd4c2c0686ba3f9231153020a988c1c6b`.
Every production snapshot file still matched the checkout after completion.

| Sample | Fitted anchor | Authored cells checked | Functional root | Live NPCs |
| --- | --- | ---: | --- | ---: |
| Starbough village | (1900,102,-2020) | 5,184 | no reserved root | 2/2 |
| Copperfell outpost | (-2100,133,-2100) | 2,303 | `grug_nodes:guard_banner` | 1/1 |
| Copperfell bandit camp | (-1568,70,-2066) | 5,183 | `grug_nodes:camp_fire` | 1/1 |

All node names, applicable directional orientations, socket air/support and
catalog-derived quest NPC titles passed. The real manifest constructor was
entered in both main and emerge environments; the real planner was entered
exactly three times. Complete registry validation passed with 66 quests and
24 NPCs. The server shut down normally after the probe's success marker; no
error was logged. Startup and test completed in approximately 44 seconds.

Durable evidence is under `tools/r14_integration/evidence/`: the complete
native log, deterministic gzip copies of both file-hash manifests, and their
SHA-256 index. The first sandboxed Flatpak launch failed before engine startup
with `Unable to allocate instance id`; the successful run used the approved
sandbox escalation, with the same isolated paths and bounded probe. Ordinary
startup recipe-removal and missing apple/stick vendor-price warnings remain
visible in the full log; they did not cause a registry or placement failure.

User runtime plan: in a fresh world, inspect a village, outpost and bandit camp,
confirm roof/door access and named quest NPCs, then accept and advance a starter
quest and complete its handoff to the corresponding home-region NPC.
