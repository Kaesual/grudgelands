# Round 41 — Playtest fixes, the production crash and the upgrade contract

Coordinator: Claude (Opus 5.5), drafted 2026-10-07 from the user's Round 40
playtest findings, a read-only research pass (four topics, every claim
checked at the cited lines) and the user's answers of the same day;
revised after an independent Opus review (verdict "ready after fixes",
every finding checked at the cited lines); extended the same day by the
production mapgen crash (lane CR) and the hosting platform's upgrade
contract (lane UP). Status: **complete** (2026-10-07,
[completion](#completion-2026-10-07)); not pushed.

The round ships as **0.41.0**, the first release under the upgrade contract;
after it the user's production server is migrated to it with a map reset
(§2.10). It holds seven playtest findings, each with a known cause and an
agreed fix, the fix of a crash loop on the production server, and the
contract that lets worlds survive upgrades from now on. The larger topic that came out of the same
discussion — mobs and NPCs that get stuck — is its own round
([Round 42, mob navigation](round42-plan.md)); this round only removes the
two causes that are pure bugs (the missing walk animation, the wandering
Generals and kings). Routing default (agent model policy, the user decides
per session): Claude coordinates, Opus implements and reviews; no Astra
lane.

## 1. Lanes and waves

| Lane | What | Wave | Kind | Waits for |
|---|---|---|---|---|
| MOB | Walk animation on scripted walks; kings and Generals stay at their seat | 1 | code | — |
| MAP | World map: remove stale tiles, crash-safe cache key | 1 | code | — |
| SC | Scout: missed bow release, quiver count overlay | 1 | code | — |
| UI | Recipe book: Close and Repair return to the station; slots that accept several items | 1 | code | — |
| CR | Production mapgen crash: diagnostics, root cause, no server stop on a mapgen failure, severe-error helper | 1 | mapgen + code | — |
| UP | Upgrade contract: release mode, `upgrade.json` and its check, map reset (`grug_reset_world`), robustness against unknown ids, version 0.41.0 | 1 | code + docs | — |
| D | Round documentation, CHANGELOG 0.41.0 | 2 | docs | last merge |

All six code lanes run in parallel. MOB, MAP, SC, UI and CR share no file;
UP touches several mods to clear their map-bound state and overlaps with
MOB (`grug_mobs`), MAP (`settingtypes.txt`) and CR (`grug_mapgen`) (§7).
Merge order MOB, MAP, SC, UI, CR, UP, then D; each later lane merges main
before its review.

Estimates (unmeasured, for planning only): MOB 2–3 h, MAP 1–2 h, SC 3–4 h,
UI 4–6 h, CR 4–8 h (bounded by its run budget, §2.8), UP 6–10 h, D 1–2 h;
each code lane plus its review.

## 2. Rulings

The user (2026-10-07):

1. **Walk animation (MOB):** fix it both centrally and locally.
   `grug_mobs.walk_toward` sets the walk animation itself, and the royal
   guards' follow re-asserts it on every step while the follow is active
   (§3.1).
2. **Kings and Generals do not wander.** They stay fixed at their place
   and return there after a fight. That is more dignified and also takes
   away the cause of the bodyguard case (§3.1). Royal guards and
   bodyguards keep following their leader.
3. **Recipe book Close returns to where the book was opened:** opened from
   a station → back to that station's form; opened from the inventory →
   the inventory crafting page as today. **The station's "Repair equipment"
   form returns to the station the same way.**
4. **Slots that accept several items** (group ingredients) show the
   alternatives as small icons inside the one slot:
   - 2 items: two icons; 3 items: three icons; 4 items: four icons (2×2);
     more than 4: three icons and a "+N" marker in the fourth place.
   - No animation, no cycling.
   - Each icon that stands for a real item is clickable on its own, and
     only when that item has a recipe the player knows (today's rule for a
     slot: an unknown recipe does nothing on click). The "+N" marker is
     never clickable.
   - **Every icon of a slot shows the same tooltip**, which lists all
     allowed ingredients (not only four). It need not be one technical
     tooltip element, only the same content.
5. **Bow, missed release (SC):** a new right-click while an arrow is drawn
   fires that arrow at once, with the draw time it has. If the button is
   then held, a new arrow is drawn within the same hold. A draw started
   this way that is released within about **0.2 s** is cancelled silently
   (no arrow, no ammunition used), so one quick tap never fires two arrows.
   A tap from rest behaves as today.
6. **Quiver count (SC):** above 100 arrows the quiver slot shows the true
   total (for example 181) in the slot, as an overlay over the engine's
   count; taking from the slot still takes at most one stack of 100.
   Accepted cosmetic limits: the overlay's background matches the slot
   background only approximately, and the corner under the overlay shows
   no hover highlight.
7. **Map quality (MAP):** changing `grug_map_quality` between server
   starts already re-renders the map (Round 27). This round adds the two
   missing pieces: stale tiles of the other quality are deleted, and a
   crash in the middle of a render can never leave mixed tiles that pass
   as current.
8. **Production crash (CR):** the kaesual.com production realm (0.40.0,
   seed `3684797457838814663`) stops with `fail_replace_policy` in
   `grug_mapgen`'s `on_generated` whenever a player comes near one
   ungenerated chunk (§3.7).
   - **A mapgen failure never stops the server again.** The failing chunk
     is written without the refinement that failed (engine terrain there;
     a visible seam is accepted).
   - The failure is reported loudly: in the server log at error level with
     the literal prefix **`[GRUG-SEVERE]`** (the kaesual-stack admin log
     view highlights it) plus chunk `minp`/`maxp`, voxel position, node
     name, class, policy, opcode and feature id; and in the game as a
     **red chat message every player sees**, once per failing chunk, not
     per retry. Both come from one small shared helper that later severe
     errors use too; AGENTS.md names it. The failure happens in the
     separate mapgen environment (`on_generated` is a mapgen script,
     `wp40/r7_loader.lua:370`), which has no `grug_core` global and no chat
     API: the log line is written there by a file both environments load,
     and the chat message reaches the main thread through gen_notify.
   - **Run budget** (the lane must not lose hours generating worlds and
     seeds): only the report's seed and candidate chunks, no seed search,
     no widening of the area on the lane's own initiative; at most **6
     engine runs of at most about 5 minutes each** for diagnosis and
     reproduction, each with its purpose stated beforehand, preferring
     the single chunk (or the chunk with its saved neighbours) over a world
     run. **Stop rule:** reproduced → stop generating and analyse;
     not reproduced within the budget → stop and report with findings and
     hypotheses (including whether the cause can depend on runtime state
     such as player-built nodes or flowed liquid). Never "one more run".
     After the fix: the report's chunks, the seed fleet `quick` and one
     final run of at most about 15 minutes over a region named in advance;
     anything wider only with a projection and the coordinator's approval,
     never the whole world. Long runs run detached, report progress and
     are never killed by a wall-clock timeout.
9. **Upgrade contract (UP):** the platform's contract
   (`~/projects/kaesual-stack/.local/grudgelands-upgrade-contract-task.md`)
   is implemented as written. The contract was revised on 2026-10-07 to
   carry the user's clarifications below; if the two ever disagree, these
   clarifications take precedence:
   - **Release mode starts with 0.41.0.** Fresh-server development mode
     ends; AGENTS.md and the design docs say that worlds survive upgrades
     through the contract (compatible, map reset, new server).
   - **No backward compatibility and no history work.** There is exactly
     one existing server: the user's production server on 0.40.0. No world
     of 0.37–0.39 exists anywhere. Nothing checks, audits or supports older
     versions.
   - **Exactly one migration is due:** the production server moves to
     0.41.0 with a map reset. Only if this round needed a new server would
     it be a new server instead.
   - **"New server" always wins** over a map reset when an upgrade crosses
     both.
   - **"A compatible version boots every world of the earlier version" is
     a statement of intent, best effort.** No saved test worlds, no
     compatibility test suite.
   - **The home claim is map-bound.** A map reset clears it; the Claim
     Stone does not come back into the inventory. The player picks up a new
     one from the Housing Steward, as after losing it (`housing.md:88`,
     `:102`).
   - **Keep it minimal:** no mechanism for a case that does not occur.
10. **Upgrade classification is a round gate from now on.** Every lane
    states in its report whether its change is compatible, needs a map
    reset or needs a new server; the reviewer checks the statement, and
    the round's declaration follows from it. The declaration's check tool
    runs at the round end. UP adds both to the round workflow's gates.

Coordinator defaults (the user may overrule them):

- Kings and Generals face their authored direction at their seat.
- Esc on the book or the repair form closes everything, as today. If the
  station cannot be reopened (dug, too far, no access, dead player), Close
  falls back to the inventory.
- A group with a single member keeps today's single icon; the small icons
  follow the tooltip's order.
- The selected enchant operation is not kept across the book (§3.2).
- The first declaration is exactly the contract's example,
  `{"schema": 1, "version": "0.41.0", "map_reset": ["0.40.1"], "new_server": []}`:
  the only existing world (0.40.0) crosses 0.40.1 and gets its map reset,
  which also covers this round's own generation change (CR) for that world
  (a 0.40.1 world would need a `0.41.0` entry, but none exists);
  `new_server` stays empty unless a lane of this round reports a
  new-server change.
- UP bumps `game.conf` to 0.41.0 together with the declaration (the check
  compares both) and writes the `## 0.41.0` CHANGELOG heading in the same
  commit, so `tools/r37_dc` check C (newest CHANGELOG entry = `game.conf`
  version) holds on main after every merge; D completes the entry for the
  whole round.

## 3. Research results (2026-10-07, verified at the cited lines)

### 3.1 Bodyguard walking without moving its legs

- `grug_mobs.walk_toward` (`grug_mobs/patrol.lua:48-53`) sets yaw, state
  `walk` and velocity, but no animation; its header (`:30-35`) relies on
  mobs_redo's `do_states` running "in the same step".
- `do_states` outside combat runs only once a second on mobs_redo's own
  timer (`mobs/api.lua:4261-4275`), which is not in step with the callers'
  1 Hz nudges. Every mob that `walk_toward` starts from standing can
  therefore glide up to about a second in its stand animation.
- The royal guards' follow (`grug_mobs/bosses.lua:660-720`) returns `false`
  from `do_custom` while it is active, so `do_states` never runs at all; a
  dropped fight forces the stand animation first
  (`royal_guard_drop_attack` → `stop_attack`, `mobs/api.lua:2463`). The
  guard glides to its leader in the stand pose until it is within 5 nodes.
  The swing lock (`grug_punch_until`, `mobs/api.lua:604-611`) can swallow a
  single non-forced walk write for up to 0.3 s, hence the per-step
  re-assert.
- Resident villagers walking home and sweeping already set the walk
  animation themselves after `walk_toward` (`start_villagers.lua:777-778`,
  `:810-811`); the idle walkers' amble (`:631`) does not and relies on
  `do_states` like the other callers.
- The playtest case: the Accord General walked out of his keep's open
  doorway; his bodyguard, spawned offset, caught on the door frame and,
  once out, was more than 5 nodes behind. Kings and Generals have no idle
  tether: royal slots get no post fields (`start_npcs.lua:1309`) and
  `free_roamer` excludes them (`aggro.lua:589-595`), so mobs_redo's random
  walk carries them anywhere. The door frame itself is Round 42's topic.

### 3.2 Recipe book Close

- Close (`grug_jobs/ui.lua:964-970`) always sets the crafting page and shows
  the inventory. The station's book button (`grug_jobs/workspaces.lua:362-366`)
  detaches the station session and calls `open_book(player, "station",
  ctx.station)`: the station's position is lost.
- Affected: every workspace station (furnace, dual furnace, brewing stand,
  forge, tanning rack, tailor, carving and jeweller's benches; all through
  `workspaces.lua` `install_node`). Not affected: the inventory's book
  slots.
- The station form is no node-meta formspec; returning means calling
  `grug_jobs.workspaces.open(pos, player)` again, which already re-checks
  node, station id, distance, HP and protection (`workspaces.lua:28-38`) and
  rebuilds dynamic parts (fire, progress, operation). Its result is not
  returned today (`:332`, `:337`, `:353`).
- The book's view state (`state.book`, `state.station`) changes during
  ingredient navigation (`show_ingredient`, `go_back`), so the origin must
  be stored separately. `refresh_open_book` (discovery) re-opens without an
  origin and must not drop it.
- The repair button (`workspaces.lua:368-375`) detaches and calls
  `grug_repair.open_station` (`grug_repair/providers.lua:117`); that form's
  Close is a `button_exit` named `close` (`providers.lua:99`), so Close and
  Esc can be told apart through `fields.close`. The repair form also opens
  from other providers, which keep today's behaviour.
- One small loss on return: the selected enchant operation is not kept and
  falls back to "Craft from inputs" (coordinator default; keeping it would
  need the operation stored with the origin).

### 3.3 Slots that accept several items

- A slot draws one `item_image` of the alphabetically first group member
  (`display_item`, `grug_jobs/ui.lua:539-560`); "Corn or Potato" is only the
  tooltip, which lists at most 4 names plus "+N more" (`:660-683`). The
  click overlay is one invisible `image_button` per cell (`:647-657`),
  handled by `fields[CELL_FIELD..index]` over `state.cell_items` with
  `pairs` (`:999-1000`). The book is `formspec_version[4]`.
- Alternatives exist only as `group:` tokens. Measured over all 1376 book
  records (a read-only engine probe, seed 42): 175 slots accept more than
  one item, in 11 groups: 2 items (staple, root, early spice, vessel; 11
  slots), 4 (berry 3 slots, sand 1), 5 (fruit 1), 7 (tree 1, wood 124), 12
  (stone 19), 15 (wool 15). The cooking book itself has at most 5 (fruit).
- Formspec v4 draws `item_image` at any size; node items render as sharp
  3D cubes at small size; 16 px craftitems are near native size at about
  0.4 units.
- Side finding, not in this round: the probe counted
  `grug_mapgen:freshwater_waterweed` as a member of `group:sand` (§8).

### 3.4 Bow release

- The draw releases when the server's control state shows the right button
  up (`grug_abilities/scout.lua:479-480`), with no minimum draw time; the
  engine applies the control bits of every position packet unconditionally
  (`reference_projects/luanti/src/network/serverpackethandler.cpp:461`).
  No Lua path keeps a draw after the server has seen the button up.
- The client sends its controls about every 0.09 s; a release and a new
  press between two snapshots are invisible to the server
  (`docs/design/classes.md:398-405`). A new press pointing at nothing or at
  an object reaches the item callbacks once, on the press edge (reliable
  packet; `game.cpp:2803-2804`, `:3249-3251`); a held button does not
  repeat it (only node pointing repeats, and the drawn bow points at
  nothing through `hold_range`). So a second native call during a live draw
  proves a new press. Food uses exactly this rule (`grug_abilities/input.lua:638-651`).
- Loose has no cooldown (`scout.lua`, `cooldown = 0`), so drawing again at
  once is possible.
- A second, unproven cause — a release snapshot lost on a lossy link — is
  not addressed by this fix (§8).

### 3.5 Quiver count

- The quiver is the real list `grug_quiver_content` with 5 stacks of up to
  100 (`grug_inventory/bags.lua:89-102`); `normalize_quiver` keeps cell 1 at
  `min(total, 100)` and the page draws only cell 1
  (`grug_inventory/pages.lua:132-153`), so the slot can never show more
  than 100.
- Formspec elements drawn after a `list[]` lie on top of it and let clicks
  through (positional click detection); `item_image` reads the count in its
  item string and draws it with the list's own font and position
  (`reference_projects/luanti/src/gui/guiItemImage.cpp:30-35`). Rejected
  options: one oversized stack (the cursor would pick up 181), the
  `count_meta` item meta (the count travels with the stack into other
  inventories and blocks stack merging).

### 3.6 Map quality

- The quality is part of the cache key (`grug_map/base.lua:629-649`); a
  changed quality re-renders at the next start (normal about 10 s, high
  about 56 s, measured in Round 27, `docs/design/world_map.md:156-164`),
  during mod loading, before the server accepts players.
- `prepare()` never deletes anything: after high → normal, 50 base tiles
  and 6 minimap tiles (about 7 MB) stay in the world folder (never sent to
  clients). Normal → high leaves nothing stale.
- The key is written last, but tile names are shared across qualities: a
  crash after the first new tile, then switching back to the old quality,
  passes mixed tiles as current.
- The game's `minetest.conf` only gives the default; a value set in the
  main menu (the global config) wins.

### 3.7 Production crash (report of 2026-10-07)

- Report: `~/projects/kaesual-stack/.local/grudgelands-mapgen-crash-2026-10-07.md`
  (0.40.0 `8036a293`, stock Luanti 5.17.0, v7, chunksize 5; 9 crashes, each
  when the character Grimbold came near; position about (1853, −2, −2457);
  candidate chunks `minp (1728,-112,-2592)` and `(1888,-112,-2592)`, not
  verified).
- Path: `r7_mapgen` → `r6_settlement.apply` → the R5 adapter's liquid
  neighbour scan → `resolve_voxel` → `fail("fail_replace_policy")`
  (`grug_mapgen/wp40/map_adapter.lua:907-909`). The message carries no
  position or node. The failed chunk is never saved, so every approach
  fails again.
- `map_adapter.lua` and `r7_content.lua` are unchanged on main since
  `8036a293` (lane ORE changed other mapgen files: `r6_settlement.lua`,
  `planner.lua`, `r7_p9g.lua`, `vegetation_density.lua`,
  `world_content.lua`, `zones.lua`): main is presumably affected.
- Whether the cause is deterministic (a node world generation itself
  places) or depends on runtime state of an already saved neighbour is
  open; the lane finds out (§2.8).

### 3.8 Upgrade contract

- The contract (`~/projects/kaesual-stack/.local/grudgelands-upgrade-contract-task.md`)
  defines three outcomes per upgrade (compatible, map reset, new server),
  the declaration `tools/web_data/upgrade.json` with a check tool in the
  round gate, the map reset through the platform-owned int setting
  `grug_reset_world` (world record in mod storage, character record in
  player meta, map-bound mod storage cleared during load, characters
  relocated to their race start on join, new characters recorded without
  relocation), robustness against unknown ids in saved state (today a
  removed active quest crashes), and a final summary for the platform.
- The platform empties the map table itself while the server is stopped;
  the seed and `map_meta.txt` survive.
- Existing pieces: `tools/check_fresh_server.py` (adapted to release mode),
  `grug_core.player_in_creation_stasis` (`grug_classes/selection.lua:478`;
  the contract forbids using it to decide whether a character is new).

## 4. Lanes (goals; the briefs add file facts)

### 4.1 MOB — walk animation and stationary leaders

- `walk_toward` sets the walk animation; the royal follow keeps it on
  every step while active (ruling 1). Check every `walk_toward` caller for
  a mob whose walk should look different (a definition without a walk
  clip, a flier, a swimmer) and report what the change does there.
- Kings and Generals stand at their seat (ruling 2): no idle walking,
  authored facing, return to the seat after a fight or a leash reset. Their
  guards keep following the (now stationary) leader. The encounter rules
  (leash, evade, give-up "drop only", boss reset, respawn) are unchanged.
- Fixture: the walk animation after `walk_toward` (including a villager
  walker's amble) and through a royal follow (including the swing lock
  case); a king or General that is pushed or fought away returns to its
  seat and faces the authored way.
- The design docs that describe the royal encounters (`world.md` around
  `:470-475` for the kings, `pvp.md` for the Generals) say that kings and
  Generals hold their seat.

### 4.2 MAP — stale tiles and a crash-safe key

- On the render path the cache key is invalidated before the first tile is
  written and written last, as today (ruling 7).
- After a render or a cache hit, world-map tiles in the world folder that
  the current quality does not use are deleted; the count is logged;
  a failed delete is a warning, never an error.
- Fixture: extend the virtual world folder of `tools/r37_f` (high → normal
  removes the extra base and minimap tiles; normal → high removes nothing;
  a crash after the first tile write, then the old quality again, renders).
- `world_map.md` and, if its wording no longer fits, `settingtypes.txt`
  say that stale tiles are removed.

### 4.3 SC — bow release and quiver count

- The missed-release rule of ruling 5, built into the existing input state
  machine next to the food rule: the first native call after a draw starts
  belongs to the starting press; a later object or empty-air call during
  a live draw is a new press; node calls never count.
- Quiver: ruling 6. The overlay only appears above 100. If a new texture is
  needed for the cover, it gets its `LICENSE-media.md` row. The count in an
  `item_image` item string is undocumented engine behaviour: an entry in
  `docs/technical/upstream-workarounds.md`.
- Fixtures: extend the input fixtures (a second native call during a draw
  fires once, a held button draws again, a release within the grace
  cancels without using ammunition, a node repeat never counts; a tap from
  rest unchanged) and the existing bow probe
  (`tools/pt_fixes/lane_a/grug_probe_food_input`) with the same case; the
  quiver form at 100, 101 and 500 arrows.
- `classes.md` §"Cancellation and native-client limits" (`:396-406`) says
  today that very fast air clicks may be lost; it describes the new bow
  rule instead.

### 4.4 UI — recipe book

- Close and Repair return to the station (ruling 3), with the fallback;
  Esc unchanged. The origin survives ingredient navigation, Back and the
  discovery refresh; an inventory opening never inherits a station origin.
  `workspaces.open` reports success so the fallback can work.
- Multi-item slots (ruling 4): the 2 / 3 / 4 / 3+N layouts inside the 0.82
  cell, one click target per real-item icon with today's known-recipe rule,
  the same complete tooltip on every icon of the slot. Icon order follows
  the tooltip's order (coordinator default). The ingredient navigation and Back history keep
  working from a sub-icon.
- Fixtures: extend `tools/r37_ix` section F (Close returns to the furnace;
  Close after walking away or after the station was dug falls back; Esc
  closes everything; Repair Close returns; the section stubs
  `grug_jobs.open_book` today, so the Close cases need the real `ui.lua`)
  and the book-content tests (`tools/r28_a6_ui`, the formspec probe in
  `tools/pt_fixes/lane_d`) for 2, 3, 4 and more-than-4 slots, clickability
  and the tooltip.
- `professions.md` (the recipe book, `:137-186`) says where Close and
  Repair lead and how multi-item slots look.

### 4.5 CR — production mapgen crash

Ruling 8. Goals, in order:

- The diagnostics first (every `fail(...)` reachable from `on_generated`
  names its location), through the shared severe-error helper (log prefix
  `[GRUG-SEVERE]`, red chat message to all players once per chunk); they
  also help to reproduce.
- Reproduce with the report's seed and chunks within the run budget.
- Fix the root cause.
- The failure mode: a failing refinement never stops the server; the chunk
  is written without it and reported. **Only the live server degrades:** a
  degraded chunk still fails the seed fleet and the fixtures (the fleet
  sees a failure only when `writer.apply` raises,
  `tools/seed_fleet/runtime.lua:277`), so `quick` and `full` keep testing
  something.
- The location details are gathered only on the failure branch; the
  fleet's per-chunk time before and after is reported as a comparison (the
  writer is a hot path).
- The report's seed and area in the seed fleet; `quick` fleet before the
  merge (a world-generation change: upgrade classification "map reset",
  covered by the 0.40.1 entry).
- Fixtures for the failure mode and the helper. AGENTS.md names the helper
  and rewrites its mapgen sentence "a `fail()` on the per-chunk path still
  stops the server" (`AGENTS.md:426`).
- A forced failure for the engine check comes from a probe mod under
  `tools/` started through `tools/luanti_headless.sh`, never from a shipped
  setting.

### 4.6 UP — upgrade contract

Ruling 9 and the contract (§3.8), with the user's clarifications taking
precedence. Goals:

- Release mode in AGENTS.md and the design docs; `tools/check_fresh_server.py`
  adapted (stable ids; a renamed item may use `register_alias`).
- `tools/web_data/upgrade.json` (the first declaration, §2 defaults), its
  check tool against the last pushed commit (a missing earlier declaration
  is accepted once), `game.conf` 0.41.0 with the `## 0.41.0` CHANGELOG
  heading; both gates of ruling 10 in the round workflow. `tools/r37_dc`
  (checks C and D: the CHANGELOG heading and the pinned settingtypes list)
  is updated for the new version and `grug_reset_world`.
- The map reset: `grug_reset_world` in `settingtypes.txt` (platform-owned),
  the world and character records, the per-mod clears of map-bound state
  (idempotent, monotonic counters kept, preparation mode kept, a failing
  clear stops the load with a clear error), the relocation on join with
  its hold and retry, new characters recorded without relocation. The lane
  decides which state is map-bound and lists it; the home claim is
  (ruling 9).
- Robustness: unknown quest, item, achievement and waypoint ids in saved
  state are ignored or dropped, never a crash.
- Fixtures for the records, the trigger, idempotent clears, relocation and
  the new-character rule, and for unknown ids; one engine test on a test
  world that does what the platform does: stop the server, delete the map
  database (keep `map_meta.txt` and the rest of the world folder), raise
  the setting, start, join with an old and a new character; the start
  areas are prepared again and the old claim node is gone.
- The final summary of the contract's requirement 6 for the platform (the
  setting name, the map-bound state, the declaration, the decisions taken),
  in the lane report and the plan's completion.

### 4.7 D — documentation

The plan's completion section with the GUI checklist and UP's final
summary; STATUS, the AGENTS pointer, ROADMAP, BACKLOG, README and the
`CHANGELOG.md` 0.41.0 entry under UP's heading (the whole round, including
that the release needs a map reset of existing worlds).

## 5. Rules

- Stock clients only; all logic server-side.
- World generation changes only in CR (the fix and the failure mode): the
  seed fleet `quick` runs before CR's merge and `full` at the round end.
- Release mode from this round on (ruling 9): every lane classifies its
  change (ruling 10); no lane writes migration code beyond the contract's
  map reset.
- No pass visits every player or every mob in one step; the walk-animation
  writes are no-ops when the animation is already playing.
- A new texture gets its `LICENSE-media.md` row; a new engine workaround
  its entry in `docs/technical/upstream-workarounds.md`.
- Round 42 rewrites the mob movement code: MOB keeps its change small and
  does not refactor `patrol.lua`, `bosses.lua` or `start_npcs.lua` beyond
  its goal.

## 6. Verification

Per lane the gates of the [round workflow](../process/round-workflow.md#3-gates).
Hot paths: the animation write (a no-op when unchanged) and CR's writer
change (details only on the failure branch; the fleet's per-chunk time
before and after).

GUI checklist (desktop and web):

- A royal guard or bodyguard that follows its leader walks with moving
  legs; a mob that starts walking home or to its post shows the walk
  animation at once.
- The kings and both Generals stay at their seat while idle, face their
  authored direction and walk back after a fight.
- Recipe book from a furnace, from the dual furnace and from a bench:
  Close returns to that station, with the fire and progress still updating;
  Esc closes everything; walking away with the book open, then Close, lands
  in the inventory. Repair equipment → Close returns to the station.
- Cooking book: "Corn or Potato" shows both icons; berry preserve (4),
  fruit glazed roast (5, three icons and "+2"); a Basics recipe with wood
  (7) and stone (12). Clicking an icon whose recipe you know opens it;
  "+N" does nothing; every icon shows the full list in its tooltip.
- Bow: shoot repeatedly at a mob by release and immediate re-press; no
  stuck drawn arrow; a quick tap fires the drawn arrow and no second weak
  one; holding on draws the next arrow.
- Quiver with more than 100 arrows shows the total in the slot; taking
  from it takes 100; check at a normal and a large GUI scale.
- Map quality: switch normal → high → normal between starts; the Map tab
  shows the right resolution; the world folder holds only the current
  tiles.
- Map reset on a copy of a test world: stop the server, delete the map
  database (keep `map_meta.txt`), raise `grug_reset_world`, start;
  an existing character arrives at its race start without the welcome,
  keeps level, inventory, quests and waypoints, its home claim is gone and
  the Housing Steward hands out a new Claim Stone; a new character starts
  normally.
- A forced mapgen failure (CR's probe mod) leaves the server running, the
  log shows one `[GRUG-SEVERE]` line with the location, and every player
  sees the red chat message once.

## 7. Orchestration notes

- Start state: main `7d8b79d9` (Round 40 and the ORE follow-up lane,
  0.40.1; ORE merged, not pushed). Only the user pushes.
- Process budget: at most 8 Lua processes at once across all lanes and
  reviews (AGENTS.md); engine runs only through `tools/luanti_headless.sh`
  with its isolation; CR's run budget (ruling 8).
- Files per lane:
  - MOB: `grug_mobs/patrol.lua`, `bosses.lua`, `start_npcs.lua` (and the
    royal slot data if the seat facing needs it); `world.md`, `pvp.md`.
  - MAP: `grug_map/base.lua`, `world_map.md`, `settingtypes.txt`.
  - SC: `grug_abilities/input.lua`, `scout.lua`, `init.lua` (the native item
    callbacks), `grug_inventory/pages.lua`; `classes.md`.
  - UI: `grug_jobs/ui.lua`, `workspaces.lua`, `grug_repair/providers.lua`;
    `professions.md`.
  - CR: `grug_mapgen` (`wp40/map_adapter.lua`, `r6_settlement.lua`,
    `r7_content.lua`, `r7_mapgen.lua`), the severe-error helper (a file
    loaded by both environments, plus its main-thread chat part in
    `grug_core`), `tools/seed_fleet/`, a probe mod under `tools/`,
    AGENTS.md (the helper and the mapgen `fail()` sentence).
  - UP: `tools/web_data/upgrade.json` and its check tool,
    `tools/check_fresh_server.py`, `settingtypes.txt`, `game.conf`, the
    mods whose map-bound state it clears (among them `grug_mobs`,
    `grug_mapgen`, `grug_core`, the housing mod), the quest, item,
    achievement and waypoint loaders for robustness, AGENTS.md, the design
    docs, `docs/process/round-workflow.md` (gates), `CHANGELOG.md` (the
    0.41.0 heading), `tools/r37_dc/portable_test.lua`.
  - D: the status owners, the `CHANGELOG.md` entry.
  - Overlaps: UP with MOB (`grug_mobs`), MAP (`settingtypes.txt`), CR
    (`grug_mapgen`, `grug_core`, AGENTS.md); resolved by the merge order
    (UP after CR).
- After the round: the user pushes 0.41.0; the platform migrates the
  production server with a map reset (ruling 9). Nothing in this round
  touches that server.
- Decided during the round: the CR checkpoint, the waterweed lane WW and
  the multi-item tooltip ([completion](#decisions-during-the-round)).

## 8. Open questions and notes for the user

- **Bow, second cause:** if the bow still stays drawn after this round,
  three answers tell the causes apart: desktop or web, local or over a
  network, and whether moving the mouse alone fires the stuck arrow. A
  lost release packet would need an engine workaround (for example a
  slight zoom while drawing that makes the client send fresh snapshots);
  only with the user's ruling.
- **Waterweed in `group:sand`:** the read-only probe counted
  `grug_mapgen:freshwater_waterweed` among the glass recipe's sand. Where
  the group comes from was not traced. A candidate for a later fix lane or
  a BACKLOG note. **Fixed in this round** (lane WW, the user's call): the
  bed's own definition carried `sand = 1`.

## Completion (2026-10-07)

Every lane is merged on main; lane D (this section and the status
documents) follows. Nothing of Round 41 is pushed: origin/main is
`7d8b79d9` (0.40.1, pushed by the user on 2026-10-07), the production
server runs 0.40.0. Main's first-parent line from the plan (`0172a15b`):
MOB (`927f7c89`), MAP (`02ce860f`), SC (`782fe25f`), UI (`125aa6b0`), WW
(`b31a9f78`), CR (`157b391b`), UP (`a3790e65`).

Reviews, each by an independent Opus: MOB MERGE (one Low, fixed by the
coordinator in `8e8ac582`); MAP MERGE; SC MERGE AFTER FIXES (one Medium,
the quiver cover placed in the wrong formspec unit, fixed by the lane in
`80f90fa0`); UI MERGE (no findings; two notes for the user, one ruled
below, one became lane WW); CR MERGE (one Low, a missing sentence break in
the chat message, fixed by the coordinator in `46728591`); UP MERGE (no
findings). WW is the coordinator's one-line fix after the user's ruling
(no lane report). Every code lane ended with a smoke boot (PASS) and a
full fixture run (119–122 before its merge); main's tree has **123
portable fixtures** (119 at the start; new `r41_mob`, `r41_sc`, `r41_cr`,
`r41_up`; MAP and UI extended `r37_f`, `r37_ix` and `r28_a6_ui`).

Round end on main: `run_fixtures.sh` 123/123, the smoke boots PASS,
`check_upgrade.py` PASS. Seed fleet `full`
(after CR's world-generation change): 304 of 304 seeds build, 0 failed
(18 min 16 s).

### Shipped, by lane

- **MOB walk animation and stationary leaders** (`927f7c89`;
  [world.md](../design/world.md), [pvp.md](../design/pvp.md)):
  `grug_mobs.walk_animation` sets the clip `do_states` would pick (fly for
  a flier off the ground or in water, else walk) whenever `walk_toward`
  starts a walk, no write when it already plays; the royal follow keeps it
  on every active step and, after a hit, walks on toward the leader at
  once (`stop_attack` also zeroed the velocity). Kings and Generals get a
  seat (`_grug_post_x/_z/_yaw` from the throne or General socket's
  authored facing) and the post guard's idle tick: back to the seat beyond
  2 nodes after a fight or a leash reset, then face the hall door or keep
  entrance; no random walk (`_grug_no_wander`, a GRUG PATCH in mobs_redo's
  `do_states`, VENDOR.md "Round 41 MOB") and no random turn. Leash, evade,
  give-up, boss reset and respawn unchanged. Fixture `r41_mob` 87 checks
  (each change removed fails its section, mutation-checked by the review).
  Numbers (LuaJIT `-joff`, stubbed engine): a nudge on a walking mob about
  98 → 117 ns and 0 engine writes both; from standing 0 → 1 write (the
  fix).
- **MAP stale tiles and a crash-safe key** (`02ce860f`;
  [world_map.md](../design/world_map.md#map-quality-and-relief)): the key
  is cleared before the first tile write and written last; after a render
  or a cache hit, world-map tiles the current quality does not use are
  deleted (`removed N stale world map tiles` in the log; a failed delete
  is a warning; only the two tile name patterns). `r37_f` section Q (41
  checks): high → normal removes the 50 extra base and 6 minimap tiles
  (about 7 MB), normal → high removes nothing, a crash after the first
  tile then the old quality re-renders. Engine (seed 42): a normal render
  9.67 s (Round 27: about 10 s); a second boot with five planted stale
  tiles removed exactly those five.
- **SC bow and quiver** (`782fe25f`;
  [classes.md](../design/classes.md#cancellation-and-native-client-limits),
  [inventory_equipment.md](../design/inventory_equipment.md)): a second
  native call during a live draw (an object or empty-air press, never a
  node repeat) fires the drawn arrow with its draw time and starts a new
  draw; released within 0.2 s (`RENEW_GRACE_US`, measured to the last step
  that saw the button down) it is cancelled silently with no arrow used;
  a tap from rest unchanged. Its probe found that the engine wrote a skill
  item's pre-call stack back into the wield slot and undid a draw started
  in a native call; `wielded_now` returns the stack as it is after the
  call. The quiver slot shows the true total above 100 as an
  `item_image` over the list with a small `[fill` cover over the engine's
  count, sized from the window information in legacy formspec units
  (upstream-workarounds §4); taking still takes one stack of 100. Fixtures
  `r41_sc` 35 checks, `r28_a6_ui` 197 (the cover checked in pixels at
  three windows), probe `pt_fixes/lane_a` 410/410. No hot path changed.
- **UI recipe book** (`125aa6b0`;
  [professions.md §1.2](../design/professions.md#12-recipe-books-are-ui-revised-2026-09-18)):
  Close of a book opened from a station and Close of its Repair form
  return to that station (`grug_jobs.close_to_origin`;
  `workspaces.open(pos, player, id)` reports success and now also checks
  the expected station id); dug, replaced, more than 8 nodes away,
  protected or dead falls back to the crafting page; Esc closes everything.
  The origin survives ingredient navigation, Back and the discovery
  refresh. Multi-item slots draw 2, 3, 4 or three icons and "+N" inside the
  0.82 cell, each real-item icon clickable when its recipe is known, every
  icon with the complete ingredient list; group members cached per token.
  Fixtures `r37_ix` F41 (49 new checks, the real `ui.lua` and repair
  providers) and `r28_a6_ui` section 9 (51); the probe `pt_fixes/lane_d`
  51/0 with 1,708 book routes identical to the base outside multi-item
  slots; 6,792 cells, 1,550 small icons (909 clickable).
- **WW waterweed** (`b31a9f78`): the waterweed bed
  (`grug_mapgen:freshwater_waterweed`) no longer carries `group:sand`, so
  the glass recipe's sand slot no longer offers it (plan §8, made visible
  by UI's icons).
- **CR production crash** (`157b391b`;
  [world.md](../design/world.md), [luanti-lua.md](../technical/luanti-lua.md)):
  the R5 fill-void band of the report's chunk (22,−1,−32) reaches y −33,
  the chunk's top layer, which the chunk above writes first; there the
  water guard had turned flooded air into `grug_core:water_barrier`, which
  the writer classed foreign and refused (`fail_replace_policy`). Fix (a):
  the barrier carries `grug_air` and gets air's class row. The whole R7
  transaction of a chunk runs under `pcall` (`wp40/degrade.lua`): on a
  failure the chunk keeps the engine's terrain (R6 restores content,
  param2 and light after a late failure) and `grug_core.severe.report`
  writes one `[GRUG-SEVERE]` error line (chunk, voxel, content id, node,
  class, policy, opcode, role, feature) and a red chat line to every
  player once per chunk, from the mapgen environment through gen_notify;
  the details are built only on the failure branch. The seed fleet and the
  fixtures still fail on a writer error. Runs: 5 of 6 diagnosis runs (run
  5 reproduced the production signature with barriers in rock); after the
  fix the report's chunks and a forced failure (~65 s; the server went on)
  and the final region (cx 21..25, cz −33..−28, two layers: 59 chunks
  generated, 0 errors, mean 1.31 s per chunk at cy 0 and 0.59 s at cy −1,
  max 4.35 s). The production seed and its chunks are in the seed fleet;
  `quick` 100/100. Per chunk (fleet `quick`, same 99 seeds, CPU) 0.519 →
  0.540 s, the median per seed +3.4 % and the whole seed +3.2 % with the
  build part unchanged: machine drift, no measurable cost. Fixture
  `r41_cr` 21 checks (fails with the production error when the fix is
  reverted).
- **UP upgrade contract** (`a3790e65`;
  [upgrade-contract.md](../technical/upgrade-contract.md),
  [AGENTS.md "Release mode"](../../AGENTS.md#release-mode)): release mode
  in AGENTS.md, the design docs and both ruling-10 gates in the round
  workflow; `tools/web_data/upgrade.json` and `tools/check_upgrade.py`
  (against `origin/main`, its rules' self-test first), `game.conf` 0.41.0;
  the map reset (`grug_core.map_reset`, the per-mod clears, the relocation
  through creation's hold, new characters recorded without a move);
  unknown quest ids in saved state are dropped (a removed active quest
  crashed the journal), waypoints, achievements and items were already
  safe; `check_fresh_server.py` allows `register_alias`. Fixture `r41_up`
  107 checks plus `--self-test`; engine test `tools/r41_up/engine.sh`
  (evidence in `tools/r41_up/evidence/`): 67 start-NPC markers and a Claim
  Stone, then the map database deleted and the setting raised; the clears
  and the record in the log, the starts prepared again (84/84), the old
  character held and moved once to the human start without the arrival,
  its claim gone, XP and class kept; the new character recorded and never
  moved; the claim node air; seed 42 kept.
- **D** (this lane): this section, STATUS, the AGENTS.md pointer, ROADMAP,
  BACKLOG, README and the CHANGELOG 0.41.0 entry.

### Upgrade classification and the declaration

| Lane | Outcome | Reason |
|---|---|---|
| MOB | compatible | no saved format changes; a 0.40 king or General stops wandering at once and gets its seat when re-placed |
| MAP | compatible | no saved state; the first start re-renders once and removes leftovers |
| SC | compatible | input logic and formspec drawing only |
| UI | compatible | origins and sessions live in memory |
| WW | compatible | a node group, no saved state |
| CR | map reset | world generation changes for chunks that hold a water barrier |
| UP | compatible | with `grug_reset_world` at 0 nothing is cleared or moved |

The round's declaration, as the plan's default:
`{"schema": 1, "version": "0.41.0", "map_reset": ["0.40.1"], "new_server": []}`.
The production server (0.40.0) crosses 0.40.1 and gets the map reset,
which covers CR's change for it too; no lane needs a new server. A 0.40.1
world would count as compatible although CR changed generation; none
exists (upgrade-contract §2).

### UP's final summary for the platform

The contract's requirement 6
([upgrade-contract.md §3](../technical/upgrade-contract.md#3-the-map-reset)
holds the full tables):

- **Setting:** `grug_reset_world` (int, default 0, min 0, platform-owned,
  section *Hosting platform*). The world record is mod storage
  `grug_core` `reset_world`, the character record player meta
  `grug_core:reset_world`; missing records count as 0; a setting above
  the record triggers, one below it does nothing.
- **Map-bound mod storage, cleared:** `grug_core` `world_preparation` (the
  plan and its progress; the mode is kept); `grug_mobs` everything but
  `live_gen:<key>` (start-NPC markers and respawn times, rares, dragons,
  leader timers, the rift crack and its boss timer, liveness positions and
  absences); `grug_housing` every `claim:<id>`, a placed stone's owner
  becomes `needs_stone`.
- **Kept:** the counters `next_id`, `live_gen:` and `item_serial`;
  `grug_home` `claim_lost:` (pending notices), parties and the world
  record.
- **Map-bound player meta:** the position (moved to the race start),
  `grug_home:claim` (cleared); `grug_pvp:loc` is sampled again. Level,
  XP, money, inventory, talents, quests, achievements, professions, mounts
  and waypoints are kept.
- **Declaration:**
  `{"schema": 1, "version": "0.41.0", "map_reset": ["0.40.1"], "new_server": []}`.
- **Where Grudgelands decided:** map-bound is everything that describes the
  old map's contents or actors, their respawn timers included, so the
  world fills as a fresh one; monotonic counters and the preparation mode
  are kept. A placed stone's owner gets a new stone from the Housing
  Steward; a carried stone stays. The hold reuses creation's preparation
  session (frozen, immortal, the waiting screen). An unfinished arrival
  counts as the move. A failed relocation logs, disconnects ("…Please join
  again.") and writes no record; the next join retries.

### Decisions during the round

1. **CR checkpoint** (the coordinator, confirmed by the user on
   2026-10-07, after the reproduction): fix (a) only, the water barrier
   counts as air for the writer. Option (b), keeping foreign or unknown
   pre-existing content instead of the writer's veto, is declined: such
   content degrades the chunk and is reported (ruling 8).
2. **Waterweed** (the user): fixed in this round as lane WW, not left for a
   later lane (§8).
3. **Multi-item tooltip** (the user): stays as built: every icon shows the
   same complete list; "Click to view recipe" appears only on clickable
   icons (the UI review's note).
4. **Review fixes:** MOB's (the seat tick waits out a signature cast) and
   CR's (the chat sentence break) applied by the coordinator; SC's (the
   quiver cover in legacy formspec units) by the lane.

### Deviations from the plan

- **Merge order:** WW merged between UI and CR (plan §1: MOB, MAP, SC, UI,
  CR, UP); CR and UP merged main before their reviews.
- **MOB:** `walk_chance = 0` was not used (mobs_redo's `do_jump` reads it
  as a jumping mob and would hop leaders through fights); the GRUG PATCH
  `_grug_no_wander` in the vendored `do_states` instead. The follow's
  walk-on after a hit goes beyond §3.1 (`stop_attack` zeroes the velocity).
- **SC:** the engine's write-back of the pre-call stack (above) was not in
  §3.4; the fix touches every skill item's native callbacks (a no-op write
  for the others).
- **UI:** `workspaces.open` also checks the expected id (§3.2 assumed its
  checks were enough); the Repair Close falls back to the crafting page
  like the book; existing fixtures extended instead of a `tools/r41_ui`;
  the probe's catalogue assumptions refreshed (five stale failures on the
  base).
- **CR:** the cause is runtime state, not generation alone: a guard
  barrier in a layer saved before its chunk existed. Of the report's
  candidates (unverified there), (22,−1,−32), entirely on hard-protected
  ground, is the likely one; (24,−1,−32) generates normally. With the production seed in `quick`, seed
  2688922133946307 drops out of `quick` (it stays in `full`).
- **UP:** §3.8's mod-storage list was partly refuted: `grug_classes`,
  `grug_abilities/kits.lua` and `grug_factions` keep none, `grug_mapgen`
  none (its world-folder caches are keyed by the world key and stay
  valid).

### Open notes

The reviews' backlog notes are in the
[BACKLOG](../../BACKLOG.md#round-41-carry-overs); none blocks the GUI
test or the migration. The bow's second, unproven cause (§8) stays open.

### GUI playtest checklist

Desktop and the web build, on the synced game. Every item works in a world
made on 0.41.0; items 1–2 and 9 want new placements or generation (a new
world, or the production server after its map reset). Use a second client
for what others see. Say what looks wrong.

1. **Walk animation:** a royal guard or bodyguard following its leader
   walks with moving legs, also right after being hit; a mob that starts
   walking home or to its post (a guard post, a villager's amble, a camp
   roam) shows the walk at once; a gull or crow flying home shows its
   flight loop.
2. **Kings and Generals** stand at their seat while idle, face the hall
   door or the keep entrance, and walk back after a fight and after a
   leash reset; their guards keep following.
3. **Recipe book Close:** from a furnace, the dual furnace and a bench,
   Close returns to that station with the fire and progress still
   updating, also after an ingredient jump and Back; Esc closes
   everything; walking away with the book open, then Close, lands on the
   crafting page. At a station inside an active claim: Repair equipment →
   Close returns to the station; Esc closes.
4. **Multi-item slots:** in the cooking book "Corn or Potato" shows both
   icons, berry preserve 2×2, fruit glazed roast three icons and "+2"; in
   Basics the stick (wood, three and "+4") and the stone pickaxe (three
   and "+9"). An icon whose recipe you know opens it; "+N" does nothing;
   every icon shows the full list. "+N" fits its corner and block icons
   read well at a normal and a large GUI scale. The glass recipe's sand
   slot no longer shows the waterweed bed.
5. **Bow:** shoot repeatedly at a mob by release and an immediate
   re-press: no stuck drawn arrow; a quick tap fires the drawn arrow and
   no second weak one; holding on draws the next arrow. If a draw still
   sticks, answer §8's three questions.
6. **Quiver** with more than 100 arrows shows the total in its slot;
   taking from it takes 100. At a normal and a large GUI scale the cover
   hides the engine's "100" and ends at the slot's corner; hovering the
   slot keeps its highlight outside the cover's corner and shows the item
   tooltip.
7. **Map quality:** switch normal → high → normal between starts; the Map
   tab shows the right resolution; the world folder holds only the current
   tiles (the log names how many were removed).
8. **Map reset** on a copy of a test world: stop the server, delete the
   map database (keep `map_meta.txt`), raise `grug_reset_world`, start; an
   existing character waits on the preparation screen, then arrives at its
   race start without the welcome, keeps level, inventory, quests and
   waypoints; its home claim is gone and the Housing Steward hands out a
   new Claim Stone; a new character starts normally. After the push the
   platform does the same with the production server.
9. **Mapgen failure:** CR's probe mod (`tools/r41_cr`) forces one; the
   server keeps running, the log shows one `[GRUG-SEVERE]` line with the
   location, every player sees the red chat line once and the chunk shows
   plain engine terrain. On the production server after its reset, the
   area round (1853, −2, −2457) generates without a crash.
