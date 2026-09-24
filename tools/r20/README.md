# Round 20 final checks

Portable final micro-KAT, one process per interpreter on identical final inputs:

```sh
tools/bin/lua51 tools/r20/final_micro.lua "$PWD" > /tmp/r20-puc.log
luajit tools/r20/final_micro.lua "$PWD" > /tmp/r20-jit.log
cmp /tmp/r20-puc.log /tmp/r20-jit.log
sha256sum /tmp/r20-puc.log
```

`check_lua.sh` runs the plain-5.1 parser, displays SETGLOBAL writes and completes
all five sweeps even when comment/string matches need manual inspection. Its
nonzero match status must be explained, never reported as an automatic clean.

The real POI construction gate is described in `../r20_pois/README.md`. It uses
LuaJIT only and a five-minute ceiling. Generated schematics are geometry views,
not engine screenshots or a media/lighting test.

For the single isolated engine integration smoke, stage `probe/init.lua`,
`probe/mod.conf` and `content_server.lua` together into `/tmp/grug_r20_probe`, then
use `PROBE=/tmp/grug_r20_probe KEEP=1 tools/luanti_headless.sh 120`. The probe
checks actual ability/Scout/food registrations and real quest/entity/socket
registries, logs its receipts and immediately requests shutdown. Archive the
log, remove the disposable run folder, and verify no probe engine remains.
The game never includes this probe. A concrete failed gate may require a focused
corrected rerun; do not expand into full world generation or performance suites.
