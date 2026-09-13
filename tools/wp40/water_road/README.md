# Water-bank and road follow-up

The user witness is seed `531802985935182545`, camera `(1862,72,1477)`.
The nearby leaking dry shore includes `(1862,65,1492)` and lies in Kezamba.

Run the real height authority with LuaJIT (choose the interpreter via
`WP40_LUA_BIN`, default `luajit`; full geometry must not run under PUC):

```sh
chrt --idle 0 ionice -c3 "${WP40_LUA_BIN:-luajit}" \
  tools/wp40/water_road/measure.lua "$PWD" "$PWD" /tmp/shore.tsv \
  531802985935182545 sealed
```

The second repository argument may point to a frozen baseline game source.
Omit `sealed` for its negative comparison. The script uses the actual checked
runtime height constructor, including complete route-axis validation, and tests
all cardinal wet/dry contacts in x1600..2050, z1300..1700. Output rows identify
uncontained water; a final corrected run requires zero. Seed 0 is an additional
constructor/shore regression. The geometry witness does not simulate liquids.

`cases.lua` drives nine adjacent basin mapchunks and one deep chunk through the
actual engine. Set `WP40_PROFILE_SEED=531802985935182545`,
`WP40_PROFILE_CASES="$PWD/tools/wp40/water_road/cases.lua"` and
`WP40_PROFILE_FULL_DIGEST=1` when invoking `tools/wp40/profile/run.sh` with the
local dedicated-engine launcher. Four fixed shore voxels must be stone; the
baseline fails with flowing river water. Disk reload must preserve the generated
output with zero generation callbacks. The compact standard quality micro also
checks the real bank-neighbor and ford helpers plus banner UV coverage.

Road preference evidence uses `tools/wp40/road_polish/measure.lua`. The isolated
road comparison holds all exact pins and water constraints fixed. Integration
of the water repair deliberately changes Kezamba's unsafe civic reference and
shore-related road bounds; do not claim its entire old pin digest is preserved.
The reported small road pits have no separate smoothing change.

Ordinary bank floors use a bounded 4,096-slot coordinate cache per seed.
Exact coordinate tags reject collisions; dry results are cached. Authored ford
paths bypass it because their approach cap depends on path and run. The compact
quality helper regression covers these cases without constructing full worlds.
