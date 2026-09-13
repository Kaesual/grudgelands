# WP40 biome cover and road junction follow-up

Date: 2026-09-13. Baseline `6a39f7c`; branch `wp40-biome-cover-junctions`.
Classification: non-trivial terrain, content and vegetation eligibility change.
The user approved biome-specific surface/vegetation combinations and ordinary
road junctions following terrain after the previous local visual test.

## Contract and ownership

The decided surface palette and eligibility are in `world_zones.md` §7.6.
Existing assets, species, densities and biome ownership remain authoritative.
Fertile variants receive native vegetation; gravel thins low vegetation,
stone remains exposed, and soil pockets interrupt gentle outcrops. This does
not add harvest resources, migration code or runtime compatibility readers.
The source x/z route graph, fixed functional endpoints and water/grade safety
remain unchanged. Free road nodes should prefer local pre-road terrain, with
one shared feasible height across their incident routes. The junction record
contains the final graph-fitting details and evidence.

The coordinator owns `r6_content.lua`, `r6_planner.lua`, `r6_settlement.lua`,
related vegetation fixtures, final integration and the design-doc update.
`junction_fitting` owns height/source changes and bounded junction fixtures in
an isolated worktree. Each scope requires an independent strong-agent review
under `docs/process/wp-workflow.md`, including the engine callback, actual VM
predecessor and Lua 5.1 rules in `docs/research/luanti-lua.md`.

## Verification budget

Development and geometry/eligibility populations use local LuaJIT, with idle
scheduling and the workstation-wide seven-interpreter-process cap. Run the
plain-5.1 parser, SETGLOBAL inspection and five sweeps on changed code/tools.
On frozen final bytes, run one compact PUC process and the same fixture once
under LuaJIT, requiring identical canonical output and unchanged input hashes.
Do not duplicate historical full-W/T2 or PUC seed populations.

The user reserved Rehearsal exclusively for the kaesual-stack agent during
this task. Do not access that VM; these changes use local offline tests, and
actual client appearance remains a user GUI check. Merge only after clean
independent review, then synchronize from main to the local game install.
