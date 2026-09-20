# Capital display placement crash review

## Scope

- Frozen candidate: `561a9c2b23954947c7dabf09ec409739786610af`, parent integration `2d3702d4627b215ea6782d10dc87e5d3b887c866`.
- Reviewed the complete two-file delta: `mods/ENTITIES/grug_mobs/start_npcs.lua` and `tools/wp13/start_npcs_kat.lua`.
- Reviewed the immutable LuaJIT fixture report `/tmp/grudgelands-r10/display-fix-start-npcs.tsv`; SHA-256 is `c9cf28fd726e1396ebaf9d46ece06dba30736c236de53900942325301195b47b`, matching the handoff.
- No runtime was started and no candidate file was changed.

## Finding and correction

The final integration gate found **one High**: every real capital server boot reached generic settlement placement for `grug_mobs:capital_display`, then called `grug_mobs.face_yaw`. That helper is intentionally mobs_redo-specific and dispatches `self:set_yaw`; a plain registered entity has only `ObjectRef:set_yaw`, so placement raised a fatal Lua error.

The correction is narrowly placed after the common `place_on_ground` and `install` transaction. `install` still writes the socket identity, placement time, authored yaw, role and display metadata, then calls the existing `configure_capital_display`. That production function applies the model/item properties, grounding, animation, immortality and authored yaw through `self.object:set_yaw`. Only the subsequent mob-only facing, retag and restyler block is skipped for an entity carrying the definition-owned `_grug_capital_display` marker. Socket claiming still executes for displays.

This preserves ordinary settlement behavior: mobs_redo entities still pass through `face_yaw`, cancel the activation-time pending yaw by updating `target_yaw`, receive retag/restyle hooks, and claim their socket exactly as before. Display reload continues through its existing saved-field validation, claim and configure path; duplicate removal still uses the display-specific `ObjectRef:remove` branch.

## Regression quality

The expanded real-code KAT registers a capital `mount_display` socket and resolves it to `grug_mobs:capital_display`. Its returned luaentity deliberately stops before the fixture installs any mobs_redo methods, while its ObjectRef retains `set_yaw`. Assertions prove:

- the plain display is placed and configured exactly once;
- the fixture did not accidentally invent `luaentity:set_yaw`;
- the authored yaw reaches the ObjectRef;
- an ordinary guard still receives the pending-yaw update; and
- the existing cold/restart/lost-entity/death/claim/census/roaming and activity report remains present.

The canonical LuaJIT report contains the new `capital_display plain_entity objectref_yaw configured_once mob_pending_yaw_preserved` row and the established lifecycle rows. The source diff is whitespace-clean.

## Bound real-engine evidence

The focused Highcourt process under `/tmp/r10-displayfix` subsequently completed with server exit 0, `error-count.txt = 0` and `moderror-count.txt = 0`. Its server log SHA-256 is `97e9648d4b00efb7db3f9f2b8f0bb9a411399e82b766bf9adfeb70b4be9e6bf1`.

The actual placement log contains all seven Highcourt displays: four mount displays and the weapon, armor and jewel gear displays. The service witness reports `status=PASS` with 8 profession trainers, 1 Riding Trainer, 7 stations, 4 mount displays and 3 gear displays across 8 owning plots; `highcourt-services.tsv` hashes to `2a0110f297809003aeab697fe4d322797fca164bde3e4cba370f9caa2d4787f0`. The full probe reached `event=complete` for all 105 requested chunks. The precinct witness separately reports `status=PASS`; its TSV hashes to `a92413801686d6df7dbb7b1dff4d2d52c3dd893ab366661554e61f2d8a97c301`.

This closes the engine condition attached to the display-placement finding. It is deliberately **not** an overall wrapper PASS: the wrapper also compared avenue, rampart and gate outputs with older geometry hashes and returned nonzero for those mismatches. Their corners match and their attribution is a separate world/geometry investigation; they neither reproduce the display crash nor invalidate the focused placement/service/precinct evidence above.

## Verdict and calibration

**CLEAN.** The source correction and bound actual-engine witness close the identified dispatch defect without weakening ordinary mob placement or display ownership/lifecycle.

- Initial integration findings: 1 High.
- Remaining source findings after this correction: 0 High, 0 Medium, 0 Low.
- Fix rounds: 1.
- Focused Highcourt engine condition: closed on the artifacts above.
- Remaining aggregate gates: the coordinator's replacement final pair and required engine fleets on the new integrated bytes. The separate geometry-hash attribution is not declared resolved by this report.
