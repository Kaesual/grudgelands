# Independent ENGINE-gates source review

## Verdict

**CLEAN SOURCE — 0 Critical, 0 High, 0 Medium, 0 Low remaining.**

- Final candidate `59b98f38aa397c2fe5046d898d52661134cf99d2`
- Initial candidate `925f765fae09088f8258bacb5c6ade91516449d2`; correction rounds `1fcceaae65c9ee6dd84d88f3180068aa6c17d70f` and `59b98f38aa397c2fe5046d898d52661134cf99d2`
- Base `4491c996`
- Independent native GPT-5.6 Sol review. I authored the earlier read-only preflight recommendations, not this implementation.
- Full six-file diff inspected. No engine or interpreter run was repeated. Root's six-capital fleet after MAP-B remains pending.


## Initial Medium — production socket IDs use `/`, so every service count is zero (closed)

`service_witness.lua:57-60` recognizes an owning plot only when the socket id starts with `plot_id .. "_"`. The real projection prefixes reference-plot sockets with `descriptor.plot_id .. "/"` (`mods/MAPGEN/grug_mapgen/wp40/r7_settlement.lua:942-962`). Therefore no real service socket has an owning box, `selected` remains empty, and the exact-total check at lines 109-111 fails every capital before any service evidence can be produced. Use the production `/` separator and bind it to an explicit projected-id assertion.

## Initial Medium — unloaded node result is discarded (closed)

`validate_node` returns `false, "unloaded:..."` for `nil`/`ignore` at lines 134-137, but the retry loop at line 297 discards every return value. If the corresponding entities are already visible, the helper can immediately validate them, write a PASS report and record `ignore` as the station/node value. Treat any unloaded node as a retry condition; after the bounded attempts it must fail, and no report may be written until every selected node is loaded and validated.

## Initial Medium — exact Lua-double comparison is not valid for engine round-tripped visual size (closed)

`same_pair` at lines 119-121 compares `ObjectRef:get_properties().visual_size` using exact `==`. The engine stores these values in `v3f` and pushes the float values back to Lua, so decimal catalog values such as 1.45, 1.55, 1.7 and 4.2 need a tight numeric tolerance. Exact double equality can false-fail a correct live display. Use a small documented epsilon for both components while retaining exact mesh/texture identity.

## Initial Medium — “exact” service census silently ignores out-of-premise sockets and entities (closed)

`tools/wp13/capital_probe/service_witness.lua:70-108` only enters its counting branch when `owning_plot(socket)` returned one of the eight expected service plots. A relevant `trainer`, `public_station`, `riding_trainer`, `mount_display` or `gear_display` socket elsewhere in the capital is silently ignored. Therefore restoring one of the retired core trainer/station rows, or accidentally emitting a duplicate service socket in a ninth plot, still leaves the selected totals at 7/8/1/4/3 and passes. This fails the CAP contract's “no capital-core duplicate services remain” condition and the runner's claim of exact per-capital totals.

The entity scan has the corresponding blind spot at lines 181-203: it records only objects whose socket id is already in `expected_entities`. An extra capital service/display entity with the same `_grug_start` but an unexpected socket id is ignored rather than counted or rejected. The TSV's fixed 23 rows and `run_capital.sh` role counts are derived from the already-filtered set, so they cannot close either hole.

**Required bounded correction:** classify every capital socket first. For each of the five relevant roles, require an owning one of the eight mapped plots; fail any relevant socket outside them, then apply the exact counts/tags. During the bounded eight-box object census, reject any entity for this capital whose `_grug_socket_role` is one of the service roles but whose socket id is not expected. Also validate trainer/Riding entity identity against the capital's expected race villager, not only its profession/name fields. For display objects, include the live intrinsic properties central to the contract (`physical=false`, `pointable=false`, zero/non-colliding collision behavior and immortal armor group if exposed by the API) alongside the existing mesh/item and absolute-grounding checks.

This is an evidence defect, not a verified production defect. One focused source correction/re-review is sufficient before the real fleet.

## Initial Low — handoff README gives the runner arguments in the wrong order (closed)

`tools/r10_engine/README.md:6` documents `run_capital.sh <capital> full <output>`, while the runner contract is `run_capital.sh OUTPUT_DIR KEY [mode] [seed]`. Following the handoff command fails argument validation and cannot produce evidence. Correct the example to `run_capital.sh <output> <capital> full [seed]`.

## Verified clean portions

- Full mode retains existing completion/error and ignored-node rejection. A changed frozen overlay digest still sets failure status and exits nonzero; `overlay-delta.tsv` records old/new digest, cell count, package and candidate but does not authorize the change. Missing historical expectations remain explicitly `unfrozen`, as before.
- The probe retains `core_composition` from the real builder and reads authored ring-48 cells back from the actual world. The precinct helper checks name and `param2`, requires broad ring coverage, verifies walkable floor and two-node doorway clearance at authored radius-49 thresholds, and emits a deterministic digest. It does not normalize stale output to the new constants.
- The Alchemy witness now discovers the real outer `public_station` socket, verifies its real brewing node and same-room/range relationship to the Alchemist, then preserves the existing real trainer/book/brewing-adapter exercise.
- Service plots are resolved from production `capital_services.PLOTS`; actual terrain-fitted bounds are emerged. The helper holds every unique mapblock, fails on refused holds/emerge errors, validates station nodes plus socket ground/headroom, and releases holds on success and all explicit failure paths.
- Entity activation uses bounded asynchronous retries: immediate inspection followed by at most fifteen one-second callbacks. This spans the normal five-second settlement heartbeat without an arbitrary blocking sleep and remains inside the capital runner timeout.
- Existing mount display checks bind actual catalog mesh/textures/scale/name and independently calculate absolute posed-foot grounding. Gear displays bind actual registered item identities and position.
- Harness hashing already includes the whole `capital_probe` directory, so both new helpers are candidate-bound. The runner requires both machine reports, exact TSV row count and one service/precinct/alchemy marker.
- The stale Lethariel “no WP13 blueprints” control claim is corrected; it is now truthfully labelled a same-class timing reference rather than package-isolated cost evidence.

## Focused correction re-review

The final candidate closes all initial findings. The witness now uses the real
`plot_id .. "/" .. local_socket_id` projection, rejects relevant sockets outside
the eight mapped premises and rejects unexpected or duplicate service entities.
It requires the expected race-specific villager for all profession and Riding
trainers. Node validation feeds a `nodes_loaded` condition into the bounded
retry, so an unloaded station, floor or headroom cell cannot reach report
generation. Live vector values use a finite `1e-5` tolerance while names,
roles, mesh and item identities remain exact. The README now documents the
runner as `<output> <capital> full <seed>`.

Root's first-correction review found one additional Medium: the display
intrinsic check required a zero collision box for mounts even though production
`grug_mobs.configure_capital_display` copies `model.collisionbox`. Correction
round 2 now compares mount collision boxes to the selected real model with the
same tight numeric tolerance and reserves the zero-box rule for wield-item gear
displays. The development fixture loads and calls the real
`capital_displays.lua` configurator on its fake ObjectRefs instead of
self-constructing display properties. Its catalog IDs follow the same
T1/faction, race, expert/faction and master/faction selection as production;
the fixture's synthetic model values are only inputs to that real configurator.

The committed evidence provenance hashes match the final candidate for the
fixture (`21d42f...`), runner (`7689f6...`), production witness (`2de446...`)
and production display configurator (`afd93e...`). The bound LuaJIT log records
canonical slash IDs and the float, outside-socket, unexpected-entity,
unloaded-node, wrong-race, intrinsic-property and materially-wrong-scale
mutations. I inspected these immutable artifacts without rerunning an
interpreter or engine.

Calibration: the initial independent review found **4 Medium and 1 Low**.
Root's review of correction round 1 found **1 additional Medium**. Two focused
fix rounds were required; all **5 Medium and 1 Low** findings are closed in
`59b98f38`.

## Remaining integration gates

1. Six isolated capital `full` runs on final integrated MAP-B bytes, with zero errors, complete markers, reports and holds.
2. Review every old-to-new overlay digest and cell-count delta against the accepted ring/gate/service geometry. Rebaseline only explicitly justified labels; mismatches remain failures until then.
3. The unchanged six-start forward/reverse cold/reload gate and global final interpreter pair remain Root-owned integration gates.
