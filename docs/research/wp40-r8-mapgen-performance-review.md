# WP40 R8 mapgen performance review

**Baseline:** `7e9284ffcd71b445efcdfde7cee39534bbf8ef35`

**Superseded candidate:** `f30b3ccac542364d0a78d399d200362a80989da1`

**Corrected frozen candidate:** `cb7467e4294faece8d0823f6d769dddfc51972b7`

## Initial independent reviews

A read-only Claude Fable hard lens reviewed implementation commit `24374e7`.
It accepted the code with no Critical or High correctness defect but blocked
merge on missing final evidence. Its evidence findings were one High (the
final PUC/LuaJIT pair was absent), two Medium (the final roster omitted
`r6_planner.lua` and `r6_templates.lua`; the runtime P9G accepted branch was
not exercised), and one Low (the exact baseline wrapper bytes were not
retained, limiting timing reproducibility). It also reported three optional
Low code observations: cache mutation preceded a potentially failing compute,
the trusted classifier duplicated its defensive body, and the R6 runtime
planner selector could fall back to the full constructor.

A fresh read-only GPT-5.6 Sol review independently rejected `24374e7` on the
same material gaps: two High findings for the absent final pair and incomplete
roster, and one Medium finding for the uncovered runtime P9G acceptance path.
It found no additional issue in cache eviction, classification, scratch reuse,
authority construction, anchors or Lua 5.1 syntax.

## Fix disposition

- `tools/wp40/r8/performance_changed_production_lua.txt` now derives exactly
  from the baseline diff and names all 15 changed production Lua modules.
  The performance micro-KAT binds 111 inputs and executes all 15 modules.
- The bounded fixture directly exercises `r6_templates.lua` runtime aliasing,
  probability digests, `r6_planner.lua.new_runtime`, the fail-closed R5/R6
  runtime constructor selection and one accepted ledger-free P9G write.
- The first PUC 5.1/LuaJIT pair is retained under
  `wp40-r8-performance-final-micro-evidence/` as a superseded audit trail. The
  corrected replacement under `replacement/` is byte-identical across the two
  interpreters and binds the final frozen bytes.
- Column values are now computed before cache insertion or eviction, and the
  R6 live planner selector fails closed when `new_runtime` is absent.
- The cache bound is 65,536 entries with hit/miss/eviction metrics. The warm
  vertical-pair measurement recorded zero misses and an 88--89% plan-time
  reduction for about 13--15 MB additional populated LuaJIT heap.
- The result record explicitly limits the old baseline timing to advisory use
  because the exact baseline wrapper bytes were not retained. No peak-RSS
  improvement is claimed from that comparison.

The duplicated trusted classifier is unchanged: removing it safely would
broaden the already successful tranche and its registered-CID construction
cross-check preserves the current trust boundary. The review's larger cold
tuple, shadow-light and packed-buffer candidates remain deferred by the
stop-before-rewrite decision.

## First focused re-review

The independent Sol reviewer verified that all three original evidence gaps
were closed and that all referenced hashes matched. It nevertheless rejected
evidence commit `9f87750` with 0 Critical / 0 High / 1 Medium / 0 Low: Lua's
`a and b or c` selection still fell back to the ordinary R5 or planner
constructor when a runtime constructor was absent, contradicting the intended
fail-closed boundary.

The second fix round replaces both selections with explicit `if/else`
branches. The micro fixture removes each runtime constructor in turn and
requires the exact fail-closed error, so the regression test cannot pass by
calling the ordinary constructor.

## Verification available to final review

- Plain Lua 5.1 parser, `SETGLOBAL` inspection and all five textual sweeps:
  pass; durable static receipt SHA-256
  `b7fe12eae1709660276cd88d24028aaf043dedd4a71a98331f04311b5aa27318`.
- R7 unit KATs: pass.
- The complete 61-case LuaJIT integration receipt is byte-identical to the
  retained R8 receipt, SHA-256
  `1fc22c764be500726f6f777b0eabd7a03a2434e23895aad6132c7c7e1ca78010`.
- Forward/reverse six-case canonical digest:
  `d058a5bcd517348c67eb83b9957422d2c3e43cdbf000dcb4981ee6ca668a5dd4`,
  unchanged from baseline.
- Replacement final PUC/LuaJIT canonical-output SHA-256:
  `a7c8be813d0bcf54038b8d19a6149c53a8ab185de98f983555aa3db6b452b7de`,
  byte-identical; receipt SHA-256
  `d3d9de965c52ddb5e437bbd499923e44b688e64dfad8b2237a4d863b988a7d61`.

## Calibration record

Classification: non-trivial performance-sensitive mapgen refactor.
Implementing model: GPT-5.6 Sol. Reviewing models: Claude Fable and an
independent fresh GPT-5.6 Sol context. Initial review totals across the two
independent reports: 0 Critical / 3 High (one duplicated concern) / 3 Medium
(one duplicated concern) / 1 evidence Low plus three optional code Lows. Fix
rounds before final re-review: two. Observed elapsed wall time: unknown.

## Final focused re-review

The same independent fresh Sol context performed a narrow read-only review of
corrected freeze `cb7467e` and evidence commit `9ac385b`. It verified both
explicit constructor branches, both missing-runtime negative tests, all
111 input hashes, the exact 15-module execution roster, distinct interpreter
binaries with zero exits and byte-identical output, unchanged post-freeze
production/harness inputs, and the static/integration bindings.

Final findings: **0 Critical / 0 High / 0 Medium / 0 Low. Verdict: ACCEPT.**
