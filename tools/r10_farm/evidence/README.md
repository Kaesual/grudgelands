# R10 farming frozen evidence

Development runtime: native LuaJIT only. Root owns the single integrated final
PUC/LuaJIT comparison after all Round-10 packages are merged.

From the repository root:

```sh
GRUG_FARM_ROOT="$PWD" chrt --idle 0 ionice -c3 /usr/bin/luajit -e 'local repo=assert(os.getenv("GRUG_FARM_ROOT")); io.write(assert(loadfile(repo.."/tools/r10_farm/final_micro.lua"))()(repo))'
```

`inputs.sha256` binds the changed production file, both portable fixtures and
the real Cooking roster consumed by the fixture. `interpreter.sha256` binds the
LuaJIT executable. `luajit.tsv` is the canonical output.
