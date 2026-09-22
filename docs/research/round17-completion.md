# Round 17 completion record

Date: 2026-09-22. Status: delivered on main, locally synchronized and pushed; GUI acceptance pending.
Contract: [round17-plan.md](round17-plan.md).
Execution: [round17-execution.md](round17-execution.md).
GUI checklist: [round17-playtest.md](round17-playtest.md).

## Scope

Twelve innkeeper homes and persistent return/respawn; shared release-target
homing missiles; configurable global non-player damage scale (default 1.5);
fixed ambient dispositions; six configurable colored nametag categories and
optional injured-mob/guard HP sprites; personal party class colors.
No new buildings, spawn-weight changes, waypoints, client modifications or
old-world migrations. Whole-WP counts remain 27/53.

## Reviewed identities

Base: `2c0f444668e78f9d8904d53f751440536ade31f4`.
Integration branch: `wp17-home-combat-feedback`.

| Lane | Author candidate | Integration | Review |
|---|---|---|---|
| HOME | `52600557` | `1858c469` | [MERGE](round17-home-review.md) |
| COMBAT | `7bcac7c1`, correction `6de2a68b` | `4cc9d126`, `d4853fa2` | [Initial](round17-combat-review.md), [MERGE correction](round17-combat-fix-review.md) |
| DISPOSITION | `0a36bca7` | `148d2a4d` | [C/D/E review](round17-ui-review.md) |
| DISPLAY | `002cbc53` | `0f1d3293` | [C/D/E review](round17-ui-review.md) |
| PARTY | `31467b13`, test correction `f9a8d357` | `5a085d06`, `3deb8057` | [Initial](round17-ui-review.md), [MERGE correction](round17-ui-fix-review.md) |

The COMBAT review corrected attached-target motion being mistaken for a
teleport, and a minimum-one cone hit at damage scale zero. The PARTY correction
adds actual production UI receive-fields coverage; production UI was unchanged.
The separate Astra [documentation audit](round17-docs-drift-review.md) found
three stale descriptions; [focused re-review](round17-docs-drift-fix-review.md)
closed all three. No independent reviewer authored the reviewed scope.
All final reviews have zero open findings.

## Final technical evidence

Evidence directory: `tools/r17_final/evidence/`.

- `static.txt`: plain Lua 5.1 parser PASS on 48 changed/new Lua files, including
  tools. SETGLOBAL inventory reviewed: production has only the six expected
  mod-table declarations; fixture globals are explicit engine/test stubs.
  All five compatibility sweeps reviewed; matches are comments or strings,
  with no executable incompatible construct.
- One final integrated process per interpreter, five isolated fixtures:
  HOME/actual source sockets/NPC lifecycle, COMBAT, DISPOSITION, DISPLAY, PARTY.
  PUC 5.1 **2.890 s**, LuaJIT **1.246 s**, both exit 0 and byte-identical output.
  Canonical SHA-256:
  `10be3620f41cc2b6e1116b103f7f73a0e84de5353910180afdc22bbf7e53be3e`.
  See `puc51.txt`, `luajit.txt`, `parity.json`, final Lua `source.sha256`.
  No intermediate PUC runtime, full-world population or PERF campaign was run.
- Isolated native Luanti registration gate PASS, exit 0, no ERROR log:
  12 homes, 12 home atlas markers, 12 neutral / 64 aggressive / 11 critter
  registered definitions (these counts include non-ambient variants).
  Probe checks faction/sockets and default damage scaling as well.
  `native.log` and compressed production/executed snapshot manifests record
  exact inputs. All **2060** production snapshot files match final checkout.
  The scratch-only scheduling flag prevents generation requests; this gate
  establishes real registration/integration, not generated-terrain/GUI behavior.
- Fresh-server source audit PASS, diff whitespace check PASS, read-only
  reference submodule pins unchanged.

## Calibration

| Scope | Implementer | Independent reviewer | Initial C/H/M/L | Fix rounds | Elapsed |
|---|---|---|---|---|---|
| HOME | native Astra | native Astra, fresh HOME reviewer | 0/0/0/0 | 0 | unknown |
| COMBAT | native Astra | native Astra, HOME author (no COMBAT authorship) | 0/0/2/0 | 1 | unknown |
| DISPOSITION | native Sol | native Sol, fresh C/D/E reviewer | 0/0/0/0 | 0 | unknown |
| DISPLAY | native Sol | native Sol, fresh C/D/E reviewer | 0/0/0/0 | 0 | unknown |
| PARTY | native Sol | native Sol, fresh C/D/E reviewer | 0/0/0/1 | 1 | unknown |
| Living docs | root native Astra | native Astra, fresh docs reviewer | 0/0/2/1 | 1 | unknown |

Routing follows the user-approved session policy; no provider CLI, Claude,
client-fork dependency or unapproved scope expansion was used.

## Limits and next runtime gate

GUI acceptance is deliberately user-run and remains pending: twelve innkeeper
placements/arrivals, Map controls, mounted and grouped ranged fights, tags/HP
bar readability and party dropdown appearance. Portable fixture parity is not
an actual fallback-engine GUI test. Prior legacy ballistic assertions are
explicitly retired; the historical mount fixture's old automatic item-insertion
expectation is not a current acceptance gate. Current mount-motion regression
is exercised by COMBAT's final fixture.

Restart the server and use a fresh world; follow the linked playtest checklist.

## Delivery receipt

- Final reviewed integration/evidence commit: `bbf56f6b`.
- Main merge: `5b91418e65c9a4d6f38aee997eef03a36f23f16f`.
- `tools/sync_to_luanti.sh` ran successfully from main. Installed target:
  `/home/jan/.var/app/org.luanti.luanti/.minetest/games/grudgelands`.
  All 2060 reviewed production-manifest files match; complete mods/menu file
  sets and contents match checkout, including deletion of the retired collider.
- `git push origin main` succeeded to `github.com/Kaesual/grudgelands`,
  advancing `2c0f4446` to `5b91418e`. The subsequent receipt-only commit
  records this delivery and leaves installed production bytes unchanged.
- No personal world or player data was changed; restart and fresh-world GUI
  acceptance remain the user's next step.
