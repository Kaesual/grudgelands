# Round 11 live planner source integration fix

Author: native GPT-6 Astra. Root worktree patch, uncommitted by instruction.

The live FARM ecology bridge adds four functions directly to the planner source from `zones.lua`. `planner.lua` rejected all four because its exact source-field schema had not been updated. This is a current contract mismatch, not a saved-world compatibility issue. The corrected schema requires all four functions and rejects missing, wrong-type and unrelated extra fields. No planner output or geometry algorithm changes.

Owned patch files:
- `mods/MAPGEN/grug_mapgen/wp40/planner.lua`
- `tools/r11_integration/planner_source_kat.lua` (new)
- `tools/wp40/r7/hydrology_depth_fixture.lua`
- `tools/wp40/planner_throughput/r5_fixture.lua`
- `tools/r9_perf/writer_equivalence.lua`

The three existing synthetic sources used by actual R5 planner constructors gain the four explicit current callbacks. No performance runner was executed. The historical `tools/wp40/simple_map_r5_validate.lua` oracle already omits earlier current coast fields; it is outside this narrow current-runtime fix and was not refreshed as a current certification.

## Test evidence

`luajit -e 'io.write(dofile("tools/r11_integration/planner_source_kat.lua")("."))'`

Before the production change, the new fixture failed with the exact engine error: `fail_source: planner source has unexpected field hard_row_at`, through actual `r5.new_runtime` -> `planner.new`.

After the change, the same fixture printed the following stdout (copied from the captured execution result to `/tmp/grudgelands-r11-planner-source.log`):

```text
r11_planner_source	live_constructor	one_column	four_required_methods	PASS
```

The fixture builds actual bounded runtime zones, the real R5 relational lookup and planner constructor, runs a real one-column `planner:plan_slice`, exercises all four real ecology bridge methods, and adversarially rejects each missing/wrong-type bridge method plus an unknown extra. Only the unrelated VM adapter is stubbed. One seed, one column, no world, VM, R7 content population, performance suite, or PUC runtime.

`luajit -e 'io.write(dofile("tools/wp40/r7/hydrology_depth_fixture.lua")("."))'` also passed; its exact output is `/tmp/grudgelands-r11-planner-hydrology.log`.

All five changed/new Lua files passed `tools/bin/luac51 -p`; the production planner has no SETGLOBAL. All five mandated sweeps ran over `mods/*/grug_*` and the changed tool files. Matches were comments, existing quoted separators or the frozen R7 manifest data; no prohibited live syntax/API. Full sweep observations: `/tmp/grudgelands-r11-planner-static.log`. The focused diff check passed.

## Frozen patch hashes

```text
f5b275c610bc7f4fb61fd608680018ad642be9648742aac7deba973a54c1a44a  mods/MAPGEN/grug_mapgen/wp40/planner.lua
8aad93c848b0388eb6f3721993f9397a1199416086b045cb8153f8d9686bdc6c  tools/r11_integration/planner_source_kat.lua
095dd4b76af207694cd49fecd1f1c197979930e8966dc369b3c78c841e0a1a91  tools/wp40/r7/hydrology_depth_fixture.lua
63b1af8735625b7fc04110a50ca4aed64b6de427c58cea0b488bd34fbd3b8b77  tools/wp40/planner_throughput/r5_fixture.lua
24d79225027d957d7d4531a404f4d0e95091b7903135ccfef6e1e076426a0c1b  tools/r9_perf/writer_equivalence.lua
```

Independent review and coordinator engine-probe rerun remain the next gates. No unrelated root documentation was edited, and no commit, sync or push was performed.
