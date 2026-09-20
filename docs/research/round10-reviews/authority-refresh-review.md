# Independent AGENTS authority refresh review

## Verdict

**CLEAN — 0 findings.**

Read-only review of Root's uncommitted `AGENTS.md` delta in the Round-10
integration worktree. No runtime was executed and no source or documentation was
edited by the reviewer.

## Verified statements

- The trainer split matches production. `grug_jobs.open_trainer(player,
  profession, position)` is the generic trainer API and the registry contains
  seven `class="primary"` professions plus Cooking as the sole secondary.
  Riding is absent from that registry. `grug_mounts.open_trainer(player,
  entity)` independently authenticates a live `riding_trainer` socket, capital
  faction, NPC distance and socket position before opening its owner-bound
  session. The villager right-click dispatch uses exactly these two separate
  APIs.
- The crop-registration paragraph matches production ownership and load order.
  `grug_nodes` registers the complete `grug_farming:soil` and `soil_wet`
  definitions, exports the fresh-table `crop_visual` constructor and exposes a
  bind-once, fail-loud callback seam. FARM binds the real callbacks, owns all 17
  crop families and the sole current-version activation LBM. `grug_mapgen` has
  no hard FARM dependency and its synchronous authority construction remains in
  ordinary mod initialization.
- The public-station replacement is accurate. Capital service sockets are
  emitted inside rotated/fitted themed outer plots and exported at resolved
  world positions. `grug_jobs.register_public_position(station, pos)` owns the
  shared keyed registry. `grug_brewing.register_public_position(pos)` delegates
  to that factory with `brewing_stand`; Alchemy discovers the authored public
  socket rather than using a fixed core coordinate. The removed `(2,1,-12)`
  statement is therefore stale and no longer authoritative.

The text records public API and ownership boundaries without adding a new game
rule, migration path or implementation status claim.
