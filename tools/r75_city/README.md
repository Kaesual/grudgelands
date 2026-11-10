# Round 75 CITY implementation report

The CITY lane adds an explicit, restrained dressing pass to the finished
settlement blueprints. It covers all 515 entries of the approved decoration
study: 51 start-town buildings, 416 capital cores/plots/spaces and 48 buildings
in the twelve peaceful regional villages. Camps, mines, outposts, city gates,
ruins, drill yards, colonnade passages and deliberately open green/fill spaces
receive no additions.

The generated catalog contains 770 exact substitutions in 338 entries. The
Round 75 baseline had 649 substitutions; `report.json` records both counts and
the delta for every building. Twenty-nine large residential buildings receive
one additional spaced detail, all 42 buildings whose authored area contains a
profession-trainer socket receive one to three, and the six royal halls replace
their floor displays with four spaced wall-art/heraldry accents. Smaller homes
and buildings without a trainer remain at the restrained baseline. The 177
zero-addition rows carry an explicit reason. Decorations use only the static,
drop-less `city_*` nodes:
table details stand in the existing air cell directly above an actual
`xdecor_table` or `cottages_table`; wall details and one-node paintings replace
an air cell beside their exact authored wall support. Existing thin tables are
unchanged.

`city_decor.lua` runs after each complete blueprint builder and before the
settlement identity is prepared. It performs no room-name or geometry inference.
If a future source differs from the catalog's expected target/support, game
construction keeps the undressed blueprint whole; the strict offline audit
fails with the building identity and coordinate.

Regenerate and audit from the repository root:

```sh
sh tools/r75_city/generate.sh
sh tools/r75_city/run.sh
GRUG_LUA51_PARSER=/home/jan/projects/grudgelands/tools/bin/luac51 \
  bash tools/check_lua.sh mods/MAPGEN/grug_mapgen/wp40/city_decor.lua \
  mods/MAPGEN/grug_mapgen/wp40/city_decor_catalog.lua \
  mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua \
  tools/r75_city/export.lua tools/r75_city/audit.lua tools/r75_city/lazy_test.lua
luajit tools/r36_w/portable_test.lua "$PWD"
luajit tools/r31_s/portable_test.lua "$PWD"
```

`report.json` is the complete per-building before/after count and omission ledger.
`scene_samples.json` gives one concrete coordinate-and-node scene for every
profile (and the explicit zero scene for profiles that remain quiet), so the
visual review can render each authored family without inferring rooms again.

Validation on 2026-11-10: all 24 finished builders passed the strict source
audit; the catalog reported 515 rows and 770 placements each time. The real
lazy bind/settle fixture rebuilt Copperfell once and wrote 5,184 cells. Its
capital-plot cases also rotated a tool board and a painting together with their
wall support through non-zero district turns. The Lua
5.1 parser and six sweeps passed. The existing decoration/access fixture passed
8,985 checks, including preservation of all previously reachable walkable
cells within its allowed detour. The PvP fixture passed 5,694 checks, confirming
that excluded fortresses and war camps remain unchanged. The integration refreshes the Round 56 settlement identity goldens for this
authorized map-reset change. Raw source blueprint point/build digests remain
unchanged. Every city clone now has an explicit rotation classification;
real lazy district tests cover a turned toolboard and a turned painting.

Classification: **map reset**, no migration step. Runtime desktop/web visual
acceptance remains open.
