# R10 world correctness fixtures

`cave_boundary_fixture.lua` and `material_salt_fixture.lua` return portable
function-style reports; `quality/final_micro.lua` includes them. Development uses
LuaJIT. `planner_integration.lua REPO` exercises actual source construction and
`planner.plan_slice` under LuaJIT; it is not an extra PUC population.

`engine_probe/` is a disposable mod for the isolated headless wrapper and seed
4151598227737528026. It samples five bounded regions; it does not mutate the world
or register resources. Native input comes from the existing
`R8_NATIVE_BASELINE=1` switch. Do not point the wrapper at personal storage.

Recheck committed actual-output evidence:

```sh
python3 tools/r10_world/check_engine.py \
  tools/r10_world/evidence/20260920/native.tsv \
  tools/r10_world/evidence/20260920/guarded-superseded.tsv \
  tools/r10_world/evidence/20260920/candidate-generated.tsv \
  --reload tools/r10_world/evidence/20260920/candidate-reloaded.tsv
sha256sum -c tools/r10_world/evidence/20260920/production.sha256
```

The guarded run is superseded acceptance evidence, retained only to establish
R5's preserved native air before the natural-landmark exclusion was corrected.
The native baseline's 21 channel-only rows have metadata coverage; corrected
reload telemetry includes their nodes. See
`docs/research/r10-world-corrections.md` for commands, limits, failures and pending
independent review/global final interpreter gates.
