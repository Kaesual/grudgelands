# Resource-root sampler adoption — 2026-09-13

The user approved production adoption and replacement of integration checks
after reviewing [the measured prototype](wp40-resource-sampling-prototype.md).
The branch is `wp40-resource-sampling-integration`, based on the prototype
`cfa5b1b` and production base `a87b58c`.

## Result and current authority

The VM writer and horizontal resource census use the same deterministic local
draw stream and lazy Fisher-Yates root selection. One SHA-256 seed per
positive-budget resource/cell/segment replaces per-host root hashes and the
root heap. The bounded transaction-local eligibility cache and early exits
from the prototype are retained. Unused prepared-root hashing, min-heap
helpers and the old root domain are removed; there is no legacy runtime path.

The decided rule lives in `docs/design/world_zones.md` §11. It supersedes
per-host root ranking in the frozen historical R6 contract without rewriting
its immutable lineage. Exact ore positions and growth-dependent shortfalls
may change. Resource precedence, eligibility, budgets, capped targets,
frontier growth and finite natural ore remain the same. The observed
50-owner/three-seed corpus preserved all 54,131 eligible/budget/planned rows
and all 100,417 planned and accepted veins; placements rose from 592,509 to
592,517. Non-ore content, param2 and light matched throughout that corpus.

Historical R6/R7 supply/access artifacts retain their original algorithm
identity. These measurements do not recertify the complete 32-seed supply or
regional access gates. R8 remains open, including that current-algorithm
release evidence, fresh-terrain GUI acceptance and real fallback-engine testing.

## Integration checks

The standard `tools/wp40/quality/final_micro.lua` runs generic hash/arithmetic
primitives plus the adopted sampler and actual writer/census fixtures. It no
longer executes per-host hash ranking or heap expectations. The resource
fixtures check rejection, unique exhaustion, interleaving, zero budgets,
ordinary/runtime parity, live claims, shortfall accounting, cache reset and
predecessor-free cache bypass. The optional stage-profiler patch is rebased
to the current writer and reports coarse phases without obsolete heap counts.

The [evidence directory](wp40-resource-sampling-integration-evidence/) contains:

- Plain-5.1 parsing for 137 production files and 11 changed Lua files,
  SETGLOBAL inspection and all five sweeps (only benign prose/string matches).
- Expanded LuaJIT sampler/writer checks, plus the complete R7 unit suite. Two
  stale unit fixtures now use the current 84-name count and required
  `coupled_grade` injection. No production validator is weakened.
- One final whole-quality PUC/LuaJIT pair: 237 byte-identical lines, including
  the actual writer and census. The input manifest was checked after both
  processes. The preceding actual R7 manifest-constructor KAT passes with
  21 decoded templates; the quality driver executes 75 production modules.
- Local headless Luanti 5.17.0/LuaJIT cold generation and disk reload of ten
  owners: all 5,120,000 voxels match the approved prototype, full digest
  `e0dc278549dfa58661a5127f2ec0b3e336839f573a1927696a4779a249136792`.
  All 1,250 disk blocks load with zero generation callbacks. Current
  uninstrumented production files match the captured engine snapshot.
- The optional coarse stage patch applies without fuzz and its resulting
  Lua parses under the 5.1 parser. The fresh-server audit passes and all
  reference-project pins remain unchanged.

The historical `tools/wp40/r7/run.sh integration` publisher is not this
package's current gate: its receipts already exist and the underlying adapter
still requires the pre-Gravewood 77-name R6 artifact/83-name production map.
A direct diagnostic invocation was stopped after identifying that stale
boundary; no PASS is claimed. Merely changing those counts would invent an
unreviewed mapping for `grug_trees:gravewood_leaves`. Current integration is
the standard quality driver plus real constructor/engine checks above, with
explicit sampler assertions. No compatibility mapping or historical artifact
rewrite is added. The release supply/access rebase remains an R8 obligation.

No Rehearsal VM or GUI is used by this package.

## Review and calibration

Classification: non-trivial (mapgen selection, performance and test authority).
Coordinator implementation: GPT-6 (session identity); bounded fixture
integration: configured GPT-5.6 Sol. Independent reviewer: configured
GPT-5.6 Sol, separate context with no implementation ownership. Initial
review: 0 Critical / 0 High / 0 Medium / 1 Low (stale adoption wording), fixed
in one documentation round. Final review: **0 Critical / 0 High / 0 Medium / 0 Low**, clean for adoption,
merge and local sync; the [receipt](wp40-resource-sampling-integration-evidence/review.md)
is retained in the evidence directory. Observed elapsed wall time: unknown.

## User runtime test

After syncing main, create a fresh disposable world, explore a surface route
and teleport underground (for example `0,-1000,0`). Check responsiveness and
ore presence, then restart the world and revisit the same area. Ore positions
need not match the previous generator. Report any new error from debug.txt.
