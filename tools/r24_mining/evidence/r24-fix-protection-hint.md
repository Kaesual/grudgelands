# Round 24 playtest fix: protection hint (evidence)

Branch `r24-fix-protection-hint`, fix commit `241ab6f4` (probe included).

## Engine run (2026-09-29)

```sh
PROBE=tools/r24_mining/grug_probe_hint KEEP=1 tools/luanti_headless.sh 240
```

- Isolated headless server (`LC_ALL=C`, temp user path), seed
  9016290885205110008; boot PASS, 0 ERROR lines; the probe ends the server.
- Orc start town anchor (0,36,2550); probe diggers of the Throng faction (the
  town's own faction: start towns are hard-protected for everyone).
- Real registered callbacks: each node's `on_punch` and `on_dig` (as wrapped
  by grug_abilities), builtin `node_dig` / `item_place_node`, the
  grug_materials dig wrapper and its protection-violation handler.
- Matrix: dirt, torch (on stone support), tree, wood, slate, dirt with
  grass and the town ground node under the anchor (dry dirt) x bare hand,
  bronze pick, apple, bronze shovel and a skill (`grug_abilities:strike`);
  plus place attempts with dirt, wood, torch and slate.
- Result: every case refused, node kept, exactly one flash
  "Town – protected" in the notice colour; `RESULT PASS checks=118
  failures=0`. Per-case lines: `r24-fix-protection-hint-probe.log`.
- Skill rows: `dig=nil` is grug_abilities' `on_dig` wrapper refusing the
  protected node (it records the violation); the punch path ran without
  error. "not attempted" means neither the wield nor the hand can dig the
  node (slate), so the client never completes a dig; the punch line covers it.
- The first run of the same probe (before the probe fix) failed only on probe
  artifacts: the fake player lacked `get_hp` (skill path) and an unsupported
  torch fell when punched (builtin falling.lua).

## Portable

- `luajit tools/r24_mining/fixture.lua "$PWD"`: PASS, 1347 checks (node x
  wield protection matrix, places, offline/non-player silence, rate limit).
- `luajit tools/r24_density_xp/tool_gate_fixture.lua "$PWD"`: PASS, 465.
- `luajit tools/r24_protection_depth/fixture.lua "$PWD"`: PASS.
