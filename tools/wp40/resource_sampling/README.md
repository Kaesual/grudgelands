# Resource-root sampling prototype fixture

This directory tests the proposed deterministic resource-root draw stream and
the writer's lazy Fisher-Yates selection independently of mapgen and a VM. It
checks canonical seed framing, Park-Miller draws, rejection sampling, closure
isolation, bounds, unique exhaustion, and a deliberately broad statistical
smoke check. The smoke result can expose gross wiring or bias defects; it is
not evidence for whole-world ore distribution.

The compact driver runs the deterministic sampler KATs and the compact writer
fixture once. It omits the 16,384-seed statistical population and is suitable
for the single frozen-byte PUC/LuaJIT comparison:

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
