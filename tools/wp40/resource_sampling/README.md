# Resource-root sampling fixtures

This directory tests the adopted deterministic resource-root draw stream and
the writer's lazy Fisher-Yates selection through the actual settlement and
census code, using a mocked VM without an engine process. It checks canonical seed framing, Park-Miller draws, rejection sampling, closure
isolation, bounds, unique exhaustion, and a deliberately broad statistical
smoke check. The smoke result can expose gross wiring or bias defects; it is
not evidence for whole-world ore distribution.

The repository-wide quality micro-KAT loads the deterministic sampler KATs and
the compact actual writer fixture once. The local compact driver offers the
same resource-focused checks and omits the 16,384-seed statistical population:

```sh
tools/wp40/resource_sampling/run.sh
```

The expanded driver adds the statistical smoke population and expanded writer
case. It is a LuaJIT development check and must not be run under PUC:

```sh
WP40_LUA_BIN=luajit tools/wp40/resource_sampling/run.sh expanded
```

Pass another production checkout as the second argument. `WP40_LUA_BIN`
selects an interpreter. The final repository-wide PUC/LuaJIT pair remains a
separate frozen-byte gate run by the integrating agent.

`primitives.lua` retains compact generic hash/framing/budget checks previously
kept under `resource_rank/`. The retired per-host rank fixture and its separate
final-micro entrypoint are removed. Run the one complete frozen-byte gate via
`tools/wp40/quality/final_micro.sh /tmp/ABSENT_OUTPUT` only after finalization.
