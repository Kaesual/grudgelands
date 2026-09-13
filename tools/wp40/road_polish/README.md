# Road cut preference witness

`measure.lua` constructs the real full horizontal and height authority, including
its route solver and evidence checks. It records each path's maximum cut/fill,
step limit, exact-pin digest and water-bound digest, followed by small samples
around the reported camera positions. Camera positions are not necessarily the
roads visible in the distance; these samples are context, not a visual oracle.

Run it with LuaJIT (the override is for another compatible LuaJIT executable):

```sh
WP40_LUA_BIN=${WP40_LUA_BIN:-luajit}
chrt --idle 0 ionice -c3 "$WP40_LUA_BIN" tools/wp40/road_polish/measure.lua \
  "$PWD" 531802985935182545 /tmp/road-polish.tsv
```

A baseline must use an immutable source snapshot as the first argument, including
`mods/MAPGEN/grug_mapgen/wp40/` and `tools/wp40/r6/common.lua`. Each concurrent
process needs a distinct output file. This is a geometry comparison, not a
performance benchmark; its full artifact construction is much more expensive
than production runtime construction.

The compact portable final check is part of `quality_geometry_micro_kat()` in
`height.lua`, invoked by `tools/wp40/quality/final_micro.lua`. Do not run the
full measure under PUC 5.1.
