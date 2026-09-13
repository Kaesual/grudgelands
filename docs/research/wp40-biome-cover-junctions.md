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

## Implementation and local evidence

Vegetation commit `9af4618` replaces the former one-host equality rule with
one precomputed biome/substrate cover table used by planning and prospective
settlement. The live writer still requires the actual predecessor content and
intent to match the allowed prospective surface; adjacent-owner roots retain
the analytic path. Existing schematic omission, collision, exclusion, cave,
water and height rules remain in place. Gravel thinning consumes the existing
candidate digest and adds no extra hash pass. Surface palettes allocate their
rows at construction, not per column.

The local actual-catalog surface fixture covers 266,256 samples; its digest is
`330b8f774cf2e9a26d5038aabce043f521e7619af1a0e55fc4e529147bec92c2`.
The expanded cover fixture performs 236,544 checks and produces 325 template
candidates and 1,514 simple candidates on alternate soils, with 4,236 gravel
roots excluded by thinning. These are planner candidates, not a claim that
all survive later collision/placement rules. The compact variant has 225,024
checks and 14/66 alternate-soil candidates. The actual tree-writer fixture
uses an allowed variant soil whose name differs from the decoration's base
host and verifies both prospective and live placement, including continuous
trunks and slice omission. Its output is retained separately.

Junction commit `aa4de5e` is the integration of independently implemented
`ba759cd`; [junction rules](wp40-quality-junctions.md) describe the fixed
island graph and station bounds. The full bounded fixture covers seed `0`
and the reported string seed `13191094842853985814`. Per seed it checks 48
junctions (25 free, 23 fixed, 32 multiply connected) and finds every free node
strictly closer to local prepath terrain than the former zone pin. Fixed
connections still require local deviations; the largest free-node deviations
are 35 and 51 nodes respectively. This is not a universal cut/fill guarantee.

The implementer reported the older two-seed geometry fixture passing but did
not retain its output files. The coordinator reran only the current bounded
junction fixture to obtain durable evidence on integrated bytes; that rerun
was required by the missing artifact, not a duplicate historical acceptance
suite. The combined final fixture also loads the actual R7 runtime and its
73-module roster.

An additional historical R6 settlement fixture stops at its hardcoded
short-vein resource witness. Repeating that diagnostic with the exact baseline
`6a39f7c` fixture and settlement produces the identical failure. Its old
resource expectation predates the accepted resource-ranking revision; it is
not a vegetation regression and is not claimed as a passing current gate.
The active differential resource fixture in the combined suite passes. Both
failure logs are retained rather than silently changing the historical oracle.

## Independent review and calibration

Both changes are non-trivial. `cover_review` independently reviewed
`6a39f7c..9af4618`; `junction_review` independently reviewed `ba759cd` and the
identical integration `aa4de5e`. Neither reviewer implemented its reviewed
scope. Both verdicts are **ACCEPT**, with 0 Critical / 0 High / 0 Medium /
0 Low findings and zero review fix rounds. Both reviewers subsequently
inspected the final frozen receipts and confirmed **unconditional ACCEPT**
for `d3951a8`, including unchanged cover bytes, the integrated junction
fixture, input/binary hashes and byte-identical interpreter output. The coordinator made the integration decision
and did not self-approve either change.

Configured delegation and independent-review route: GPT-5.6 Sol; coordinator:
Codex. Reviewer self-descriptions of underlying model labels are not used to
infer a different configured route. Observed elapsed delivery time: `unknown`.
The independent reviews checked the mandatory workflow checklist, actual
support/predecessor checks, palette/biome authority, deterministic grade
constraints, source ordering, tests and static Lua gates. No reviewer reran
PUC or a known-passing seed suite. The review notes that island interval
propagation is appropriate to the fixed two-star topology, not a general
simultaneous graph projection.

## Final frozen receipt

Candidate `d3951a8` passes the one final PUC 5.1/LuaJIT pair. Both processes
produce 9,138 byte-identical bytes, SHA-256
`4de2e7f0e703a1263d5da8307b216a25d33b10f870913e9cbe9480de03518f6a`. All 1,756 bound inputs pass the unchanged-hash check.
Interpreter binaries and versions are recorded with the outputs. The final
parser checks all 12 changed Lua files, changed production files emit no
SETGLOBAL, and all five sweeps have no changed-file hits. The broader sweep
contains only existing comments, strings and manifest data. The R8 performance
static gate and fresh-server audit pass.

[Evidence and final input/output receipts](wp40-biome-cover-evidence/SHA256SUMS)
include surface and cover populations, actual tree-writer results, integrated
junction checks, static logs and the diagnosed historical fixture failures.
No real-engine or performance-speedup claim is made for this package: the
Rehearsal VM was reserved for other work, and the user's GUI is the visual gate.

## Runtime test plan

Restart local Luanti after synchronization and create a fresh world. Inspect
pine/elf/ordinary forest and savanna or blight surfaces: patches should retain
native plants and trees, gravel should have sparse low cover, and exposed
stone can remain bare. Inspect a free road junction from above and walk
through it; incident roads must meet at one height near the surrounding land.
Fixed buildings/landings still require ramps. Keep an eye on continuous tree
trunks, cave mouths and water containment. Report a remaining problem with
seed and position when available. The Rehearsal VM was not used, and visual
appearance and a real fallback-engine run remain user runtime checks.
