# WP40 R8 terrain-life polish

Status: implementation and independent review in progress, 2026-09-13.
Fresh worlds only; Rehearsal remains reserved for the kaesual-stack agent.
The reference seed is the exact string `4655649881628627392`.
Reported camera positions are (189.5, 200.9, 643), (343.9, 110, 56.9),
(102.1, 102, 58.4), (−207.6, 50.3, 104.6), and (−632, 50.1, −1346.3).
These are camera positions, not asserted POI centers.

## Accepted scope

- Predominantly bare, bent and forked Gravewood with only scattered grey dead
  leaves. Two original schematics feed both mapgen and sapling growth; wood
  remains connected when every optional leaf is omitted. Keep existing biome
  densities, wood recipes, and harvesting rules.
- Fit ordinary POIs to natural terrain, flatten only a necessary building core,
  and grade a natural collar. Full multi-height city structures remain WP13.
- Balance existing broad/detail relief fields without adding a noise pass;
  retain regional elevation identity. Vary inland/coastal beds and material,
  preserve crossings, containment, deep ocean and dragon channels.
- Give air fliers a bounded gentle near-ground tendency; purposeful native
  movement owns combat and escape. Unknown terrain never commands blind descent.

The exact geometry contract is in
[terrain-life geometry](wp40-terrain-life-geometry.md), and the controller
contract is in [flight nudge](wp40-flight-nudge.md). Decided user-facing rules
are folded into `docs/design/world_zones.md` and `docs/design/biomes_mobs.md`.
There is no old-world reader, migration, compatibility alias or cleanup pass.

## Ownership and gates

The coordinator implements Gravewood/catalog integration and final evidence.
A separate GPT-5.6 Sol context implements terrain/POI/water; another implements
flight. Independent strong-agent reviews cover each production scope and the
integrated fixtures. Every High/Critical correction receives focused review.

LuaJIT owns development and geometry measurement. Inputs stay immutable during
runs, outputs are separate, and local interpreter concurrency never exceeds
seven (idle scheduling). Plain 5.1 owns parser/SETGLOBAL/five static sweeps and
one final compact runtime process, paired once with LuaJIT on identical frozen
bytes and compared by canonical digest. No intermediate PUC runtime or VM use.
Actual GUI appearance, mob combat feel and fallback-engine runtime remain the
user's local runtime gate; offline geometry timings are not a real-engine FPS
or complete chunk-generation benchmark.

## Historical evidence boundary

The immutable R6/R7 77/83-node artifacts describe the accepted pre-polish
catalog. `tools/wp40/r7/runtime_adapter.lua` reconstructs that historical
Stage-A/B comparison and must be run only with its complete recorded source snapshot;
it is not a current-candidate acceptance lane after Gravewood adds a node.
Its frozen binding and historical artifacts are not rewritten or projected
through a compatibility map. Current acceptance uses actual production modules
in the compact R7 seam fixture plus the focused Gravewood writer/growth fixtures.
The closed live catalog is now 78 base / 84 production nodes, followed by the
12 P9G nodes (refs 85–96) and 2 anchor nodes (refs 97–98).

## Review record

Flight: implementer and reviewer GPT-5.6 Sol; initial 0 Critical / 1 High;
first fix exposed 1 Medium, second fix clean. Two fix rounds; elapsed unknown.
The final independent verdict covers `c9990a4`; integration cherry-picks are
`bc655bf`, `0be8e6b`, `6c181d9`.

Gravewood: coordinator implementation plus GPT-5.6 Sol fixture assistance;
independent reviewer configured GPT-5.6 Sol. Initial 0 Critical / 1 High
(stale current anchor oracle); a subsequent Medium required the actual MTS
writer path rather than a separate synthetic reconstruction. Two focused fix
rounds; final `fc47fe6` accepted clean; elapsed unknown. Portable and real MTS
writer modes agree on digest
`ec55f014e48c91a148e26714d12a5ad95b602c88cb6ec2c605819acb4624de89`.

Terrain: implementation and independent review configured GPT-5.6 Sol.
Initial 0 Critical / 2 High (ford authority and mismatched measurement files).
Both corrected; focused review found one Low missing baseline provenance.
Exact patches/hashes close that finding. Two evidence-correction rounds;
geometry integration also addressed the coordinator's all-water anchor
fallback and final composed-axis regression. Elapsed unknown.

Coupled grade: separate GPT-5.6 Sol implementation and independent reviewer;
initial review was retracted after the coordinator found an invalid heap
comparator. Review then recorded 0 Critical / 2 High (comparator and constant
tunnel ownership); both corrected in `d7207a4`. One later High about measurement
versus integration hashes was closed by explicit, independently verified
provenance, not by relabeling runs. The final static gate also caught discarded
return assignments leaking `_`; localizing them preserves numeric behavior.
Two focused code rounds and one provenance round; final review clean with
0 Critical / High / Medium / Low. Elapsed unknown. Model labels here record
configured routes, not runtime model introspection.

## Integrated validation

[Terrain measurements](../../tools/wp40/quality/evidence/20260913-terrain-life/README.md)
record the exact baseline and measured-candidate revisions. On the user's seed,
the sum of 88 ordinary-POI worst cut/fill witnesses drops from 3,682 to 1,335;
the worst single witness falls from 146 to 111. Large remaining outliers are
possible at constrained positions; this is not a universal excavation bound.

The final integrated composed-axis check passes seeds `0`,
`4655649881628627392`, `13191094842853985814`, `1`, `42`, `8675309`,
`9223372036854775807`, and `18446744073709551615`. Eight independent LuaJIT
jobs used at most seven concurrent idle-scheduled processes. Logs and hashes
are in [integrated evidence](wp40-terrain-life-evidence/).
All 137 project-owned production Lua files plus 42 changed Lua files pass the
plain-5.1 parser. SETGLOBAL and five static sweeps pass; matches are inspected
comments/strings and intentional offline shell hashing. Fresh-server source
audit passes; all nine reference pins remain unchanged.

One final compact PUC 5.1 process and the same LuaJIT fixture pass with
byte-identical 219-line output, SHA-256 `7e3b294bc4f7dc9b46768126e71d352a00c15ce9a61326d888fa9580e69627c5`.
The integrated R7 seam executes all 74 required modules. No production, fixture
or bound design inputs changed during the pair. The [receipt](wp40-terrain-life-evidence/README.md)
records the frozen inputs and supporting focused results.

## Local runtime test plan

From synced main, create a fresh world with decimal seed string
`4655649881628627392`. Inspect Gravewood trunks/branches and sparse grey leaf
remnants; also grow a sapling near and away from obstacles. Revisit the POIs
near `(189,201,643)` and `(344,110,57)`, the relief near `(102,102,58)` and
`(-208,50,105)`, and the water/bridge near `(-632,50,-1346)`. Check routes through
junctions, variable lake/shelf beds, and retained crossings. Observe vultures
wandering over ordinary ground and ravines, then engage them in melee to test
that combat steering takes control. Appearance, play feel and a real fallback
engine remain runtime evidence; this offline follow-up does not close R8.

## Coupled route-axis grading

New natural POI elevations exposed a pre-existing composition defect: each
path was graded independently, so switching between overlapping path owners
could produce a multi-node step even though each individual profile had
one-node steps. Comparator swaps, blanket collars and seed-specific core-width
tuning are rejected; they do not establish the shared invariant.

The construction graph represents path/run heights and constant tunnel
surfaces. Existing adjacent-run constraints remain; additional unit edges
connect the actual visible compositor owners of every consecutive digital
axis sample, including projected-run skips. This proves the existing route-axis
travel guarantee, including its diagonal raster steps. It does not constrain
roadside banks or require all neighboring terrain columns to be walkable.
Existing exact pins and water lower bounds retain their authority; derived
bridge deck heights may follow the coupled grade.

Let graph distance be d. Lower and upper feasible envelopes are
Lo(u)=max_v(lower(v)−d(u,v)) and Up(u)=min_v(upper(v)+d(u,v)). Infeasible
intervals abort with a node witness. Clamp the existing one-dimensional grade
into Lo..Up to obtain p. Construct M(u)=max_v(p(v)−d(u,v)) and
m(u)=min_v(p(v)+d(u,v)), then choose floor((M+m)/2). Both envelopes remain
inside Lo..Up and differ by at most one across each unit edge; flooring their
mean preserves that bound and every exact singleton pin. Four deterministic
multi-source heap passes cost O((N+E) log N), in addition to indexed compositor
classification; all work and graph storage belong to construction, not column
queries. The coupled result must precede derived water records and evidence.

A separate Floyd-Warshall oracle tests small cyclic, disconnected, negative,
fixed and infeasible populations plus node/edge permutations and bounded
larger line/fan graphs. The existing final composed-axis scan remains unchanged
as the integrated geometry gate.

## Subsequent startup correction

The first user GUI start exposed stale live manifest pins that the portable
receipt validator did not cover. The [startup repair](wp40-startup-manifest-fix.md)
records the correction, actual-constructor regression and real-engine checks.
The original parity evidence remains historical evidence of its narrower scope.
