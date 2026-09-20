# Round 11 WORLD-CAP focused evidence

Use LuaJIT only for runtime checks in this round, per the final user amendment.
`tools/bin/luac51 -p`, SETGLOBAL inspection and all five source sweeps remain
required. No PUC pair, full city/census/seed suite or performance fleet is run.

From the repository root:

```sh
luajit -e 'io.write(dofile("tools/r11_world/capital_fixture.lua")("."))'
luajit -e 'io.write(dofile("tools/r11_world/socket_fixture.lua")("."))'
luajit -e 'io.write(dofile("tools/r11_world/coast_fixture.lua")("."))'
luajit tools/r11_world/beach_writer.lua "$PWD"
luajit tools/r11_world/beach_probe.lua "$PWD" 32
```

Run with `nice -n 19 chrt --idle 0 ionice -c3`; share the workstation-wide
seven-process budget. Each check is bounded. The writer uses the existing R6
fixture contract, actual R5 source/planner/adapter and two 80×23×80 owner slices
with synthetic native stone/soil/ore input. It proves real clearing, not native
v7 generation or the later complete R7 content tail. The probe exports two
65×65 source rectangles around the supplied seed/positions. Its read-only
instrumentation exposes pre-composition height; it changes no calculation.
The optional `cardinal` argument reproduces the diagnostic experiment and is
not needed against the corrected production source.

`capital_fixture.lua` constructs only the 48 owned service plots, not six full
cities. `socket_fixture.lua` exercises actual parts rotation and the settlement
registry with an explicit nonzero terrain datum. `coast_fixture.lua` exercises
the production orientation helper on diagonal/tie/absent-contact cases and
counts the strict 144-probe ceiling.

Motion evidence uses the existing pinned-loader B3D evaluator in
`tools/r10_cap/b3d_pose.py`, at each integer frame of the eight ground models'
current move clips (422 evaluations). `motion_clearance.py` compares full-yaw
sampled envelopes over authored endpoints against emitted shelter cells, resting
flyers, neighboring ground mounts and the public front aisle. Grounding must
use the minimum of each model's stand and move minima, from the absolute floor.
Fractional animation interpolation and perceived movement remain GUI acceptance;
this evidence does not claim mathematical extrema between sampled frames.

The three native textured views use the existing R10 pose loader plus
`prepare_views.py` and `render_views.py`: Highcourt shelter with roof omitted (all six posts retained),
forge and tailor with courses y>=4 omitted. Plain steles indicate actual trainer
positions and are not runtime NPC artwork. Product nodes use existing game item
textures; the render assets are diagnostic only. Source/node texture resolution
reported zero missing/modifier warnings. Two additional head-on frame views
use `R11_DETAIL=1`; negative-Z faces use the correct upright UV ordering. The full roof and all six racial
shelters are checked as emitted cells, not inferred from the cutaway.

The package record is `docs/research/round11-world-evidence.md`. Independent
review and integration are distinct gates; these files do not mark them passed.
