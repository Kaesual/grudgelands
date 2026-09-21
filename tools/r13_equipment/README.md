# Round 13 equipment verification

Native Astra root implementation; independent Astra review and repair recheck:
[review](../../docs/research/round13-reviews/equipment.md),
[recheck](../../docs/research/round13-reviews/equipment-recheck.md).

Focused LuaJIT checks passed on the integrated production files:

- `luajit tools/r13_equipment/runtime_kat.lua .`: all six combat budgets,
  eight exact gathering budgets, one incoming candidate, main-only outgoing,
  accepted-action identity, delayed settlement, Creative and broken exclusion.
- `luajit tools/r13_equipment/repair_caps_kat.lua .`: real repair service and
  Money transaction retain active capability overrides on partial repair and
  restore the saved override after breakage.
- `luajit tools/wp39/combat_integration_test.lua .`: existing combat boundaries
  pass with the new gathering-tool PvP veto. The only fixture adaptation is the
  missing `get_item_group` engine stub; assertions were not removed.

`static.sh` covers every changed/new Lua file since Round13's baseline,
including tools, with the plain-5.1 parser and SETGLOBAL plus all five sweeps.
`evidence/integrated-static.log` is the integrated run. Production global writes
are owning mod tables; fixture globals are deliberate test adapters. Sweep hits
are comments, quoted separators/patterns and the existing long-string frozen
manifest, not forbidden syntax or calls. No PUC runtime was run.

The integration probe additionally checks registered real equipment, level-1
Bronze eligibility, concrete ilvl75 plate/shield aggregation and Protection,
and broken quiver behavior. Unit fixtures alone are not GUI acceptance.
