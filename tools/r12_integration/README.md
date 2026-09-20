# Round12 integrated checks

Final sources at integration commit `1a4b5c58` plus the reviewed fixture updates.
No production changes followed the recorded native probes. The static source
manifest identifies exact final Lua bytes; the runtime manifest identifies all
1,961 shipped files, including media.

- `evidence/combat.log`: real core/ability settlement regression PASS.
- `evidence/skills.log`: real catalog, normalization, mounts, guards and cooldown PASS.
- `evidence/layout.log`, `talent-ui.log`: shared geometry and purchase/respec PASS.
- `evidence/x3-native.log`: 110 assertions through actual loaded consumers PASS.
- `evidence/catalog-native.log`: 596 Basics, 63 starter routes, 57 foods, four
  Bronze armor starters; bag discovery, Cooking authority, universal T6 craft,
  shared UI, Skills and all four new abilities PASS.
- `evidence/static-summary.log`: 351-file plain-5.1 parser, SETGLOBAL, five sweeps,
  diff check and thirteen unchanged reference pins PASS. Globals are declared
  owning mod tables or standalone fixture environments. Sweep hits are comments,
  string data and frozen manifest records, not prohibited executable syntax.

Reproduction: `luajit tools/wp39/combat_integration_test.lua .`,
`luajit tools/r12_skills/behavior.lua .`; the UI fixtures return runner functions
which take an absolute repository path. `tools/wp11/run_x3.sh 40` is the bounded
native talent runner. The catalog probe is staged with
`KEEP=1 PROBE=<absolute tools/r12_integration/probe_round12> tools/luanti_headless.sh 35`.
Require the explicit `ROUND12 RESULT PASS` marker in addition to startup success.
Both probes disable start-area preloading and use disposable worlds. Native
LuaJIT is verified in each log; no GUI or fallback-engine execution is claimed.

Initial integrated fixture failures were missing neutral class/window/absorb
API mocks and a relative path passed to the geometry fixture. Those dependencies
were corrected; all existing assertions remain. The independent Astra integration
recheck approved them. No PUC runtime, seed fleet or broad mapgen/PERF suite ran.
