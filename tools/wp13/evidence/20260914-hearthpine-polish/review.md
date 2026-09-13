# Independent review: WP13 Hearthpine polish

Reviewed range: `5883195..fa39a23` on `wp13-hearthpine-polish`.

Reviewer: GPT-5.6 Sol, fresh independent context. Same-model review is used because the preferred Opus route was unavailable with `HTTP 403 oauth_org_not_allowed`. I did not implement any part of this change. Classification: non-trivial.

## Result

Clean after one review fix round. The initial review found 0 Critical, 0 High,
1 Medium and 0 Low defects; the final candidate has 0 remaining findings.

The Medium finding was unnecessary decoration-candidate hashing on
static-excluded dry start grades. Restoring their P7 surface eligibility also
made the planner rank candidates that settlement protection would later
reject, adding bounded but avoidable work during start generation. The fix
keeps P7 material restoration intact while suppressing candidate discovery
only for excluded dry start grades; ordinary candidate populations remain
unchanged. I focusedly re-reviewed that fix in `f8ff201` and its final coverage
in `fa39a23`; it is closed.

## Review coverage

- Read `AGENTS.md`, `docs/process/wp-workflow.md`, `docs/process/agent-model-policy.md`, `docs/research/luanti-lua.md`, `BACKLOG.md`, `docs/design/settlements.md`, the first Hearthpine brief and `docs/research/wp13-hearthpine-polish.md`.
- Reviewed the full production, fixture and documentation diff, including the late R6 dry-start surface restoration in `f8ff201` and its final native-boundary evidence changes in `fa39a23`.
- Checked height authority: all six starts use 81 deterministic samples over the 128-node envelope, the lower median, the common eight-node cut/fill interval where feasible, the water floor, explicit excess reporting and the same fitted reference for surface, spawn and road pins. The five-seed receipt contains all 30 start rows; feasible rows have zero excess and the one infeasible row reports excess 3.
- Checked architecture: 88,167 canonical unique cells remain below the 125,000 budget; bounds remain x/z `[-63,63]`, y `[-2,24]`; nine destinations are conservatively reachable; all 41 torches have authored supports; the watchpost has full-height masonry bearings below its roof; natural ground dominates; the five-wide route and spawn clearance remain explicit.
- Checked writer boundaries: the Hearthpine successor retains all-axis owner clipping, one shared VM transaction, deterministic order and edit-preserving reload. The R6 restoration accepts only dry `land_grade` columns owned by `anchor_001` through `anchor_006`, retains exact predecessor checks (top 22, filler 21), and does not alter platform, road/capital grade, ford, causeway, wet, hydrology-seal or cave precedence. Static-excluded start grades remain ineligible for decoration discovery, avoiding wasted rejected candidates while ordinary candidate behavior remains unchanged.
- Checked fresh-server and protection constraints: no migration, alias, cleanup callback or extra generation callback was introduced. Existing hard-protected aprons and the y=-701 contested override are exercised in the native harness. No player-count hot loop, globalstep, inventory write or persistent per-player work was added; the mapgen work is construction-time and bounded by existing owner/candidate limits.
- Checked Lua 5.1 hazards and strict globals in changed Lua. The final static artifact reports parser/SETGLOBAL and five-sweep success, including tool Lua; my source scan found no changed-code violation. Submodules have no `+`, `-` or `U` marker, and `git diff --check` is clean.

## Evidence inspected

- `/tmp/wp13-polish-static.txt`: final parser, SETGLOBAL and five source sweeps green; `tools/check_fresh_server.py` also passes.
- `/tmp/wp13-polish-terrain.tsv`: five seeds times six starts, including road/spawn coupling and the reported infeasible excess.
- `/tmp/grug-wp13-polish-final-micro`: immutable input checks match the final production and fixture hashes. PUC 5.1 and LuaJIT outputs are byte-identical at SHA-256 `f443cbb1971b857e9ff296f5802e6fcad1cf3f9414f0bc82e0869df52212806c`.
- `/tmp/grug-wp13-polish-engine-final` (seed `531802985935182545`) and `/tmp/grug-wp13-polish-engine-boundary` (seed `8675309`): forward/reverse cold generation and disk-only reload all pass. All eight architecture digests equal `bf4c0d5aa132bb972516f8f98c95ba556411501f41ada6cbeb2f01f2c43d76d0`; all 41 torches and the full route/interiors are lit, the edit canary persists, outside-blueprint soil is present, and the boundary seed proves filler-only restoration as `default:dirt` at y=47 below the y=48 Stillgrave surface. Harness hashes match the final committed harness files.

The stopped full-R6 capture is correctly documented as non-evidence and was not used for acceptance. The retained compact planner controls plus actual R7 native owner-boundary test cover the relevant consumer and vertical clipping behavior without adding an unverified expensive fixture.

## Residual runtime gate

The code-review gate is clean. The package still needs the planned focused user GUI playtest in a fresh dwarf world after merge/sync; that visual gate should inspect natural pad height and blending, all nine buildings, entrances and route readability, exterior lighting, the watchpost roof bearing, and leave/reload persistence.
