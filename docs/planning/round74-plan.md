# Round 74 — the way home, the queued cast, the coast

Planned with the user on 2026-11-10 after their play of 0.73.1. Routing (user's
standing rule): one coordinator, lanes as subagents of the session model, independent
review of every lane with game logic. Version **0.74.0**, expected **compatible**: no map
reset, no saved format changes beyond two new player-meta keys (§4 MOUNT).

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A **proposal** or **finding** is not a
  ruling until the user says so; a coordinator default is marked as such.
- Name functions rather than line numbers.

## Why

The user's notes after 0.73.1 (2026-11-10): an evading mob, above all in an Expedition,
sticks at walls and ledges on its way home; Ruination and Hold Ground do not fire
reliably with a mob in the crosshair; the Expedition's closing countdown, the Deserter's
Mark and the wall trap interval are too long; flight should reach the coast; and a rider
who logged out in the air falls to death at the next login.

## 1. Lanes and order

Start state: main at this plan's commit (0.73.1). Integration branch `round74`; every
lane branches from it. **One wave, all five lanes in parallel.**

| Lane | Goal (§4) | Merge order | Review |
|---|---|---|---|
| QUICK | Closing 30 s, Deserter's Mark 2 min, wall traps every 2 s | 1 | coordinator (constants, template rebuild) |
| CAST | A self skill refused for "busy" or "interval" waits and fires | 2 | independent |
| MOUNT | Flight over friendly and contested coast; the ride restored at login | 3 | independent |
| TRAIL | Overworld: the evader walks home along its own trail | 4 | independent |
| NAV | Expeditions: a precomputed walk grid for every mob path | 5 | independent, thorough |
| D | Docs, completion, GUI checklist | after every merge | coordinator |

Shared files are few (§3.3). TRAIL and NAV both touch the evade run; TRAIL merges first
and owns the seam both use (§3.1), NAV merges `round74` in before its review.

The full fixture run happens **once, at the round's end**, by the coordinator (§7).

## 2. The user's rulings

- 2026-11-10: a finished **and** a cancelled Expedition close after **30 s** (was 60 s).
- 2026-11-10: the **Deserter's Mark lasts 2 minutes** (was 5).
- 2026-11-10: the Expeditions' **wall traps fire every 2 s**.
- 2026-11-10: Ruination and Hold Ground must fire when pressed with a mob in the
  crosshair (the warrior surrounded by mobs needs them most). Clicking several times did
  not fire them either; the user suspects the Strike fallback fired first each time
  (CAST checks it, §4).
- 2026-11-10: **flying is allowed over coastal water and bays** in front of contested and
  the own faction's home land; the coast in front of enemy land stays a no-fly zone, the
  deep ocean too.
- 2026-11-10: the ride a player logged out on (flying mount, ground mount, boat) is
  **restored at login**; the logout itself keeps dismounting (an old crash).
- 2026-11-10: Expeditions get a **precomputed path structure** per template, loaded once,
  that makes pathfinding in the whole Expedition cheap; it must be **checked thoroughly**.
- 2026-11-10: the overworld gets the better way home too (the user leans to yes); the
  coordinator's proposal, accepted for planning: the mob's own **trail of waypoints**
  rather than one long search.
- 2026-11-10: **LuaJIT runs sparingly and aimed** (standing rule, §7).

## 3. Shared conventions

### 3.1 The evade seam (TRAIL builds it, NAV plugs in)

`grug_mobs` (aggro.lua) gets one ordered list of **evade guides**. A guide is
`fn(self, pos, home) -> point | nil`: the next point to walk to, or nil when it has no
answer for this mob. `evade_tick` asks, in order:

1. the registered guides (`grug_mobs.register_evade_guide(fn)`); NAV registers the
   Expedition guide, which answers only for a mob with `_grug_expedition`;
2. the mob's own trail (TRAIL, overworld and anywhere else);
3. today's walk: straight home, the local search when stuck (EVADE_SEARCH), the 40 s
   teleport as the last safety net (kept unchanged).

The arrival rule, the evade speed, invulnerability and the timeout stay as they are.
TRAIL writes the seam with an empty guide list and a fixture guide; NAV only registers.

### 3.2 The walk grid (NAV)

**Finding (coordinator, 2026-11-10):** the shared template proof
(`tools/expedition_templates/proofs.lua`, rules `surface` and `relief`) already enforces
**one walking surface per column** and neighbours within one node, with a stair at every
change. The user's premise holds exactly: the Expedition floor is a 2D height map, not
2.5D.

- **One copy per template, in memory once.** A run places its template unrotated at its
  slot's minimum corner (`preparation.lua`), so every run of a template uses the same
  grid; a world position becomes a cell by subtracting the slot's corner. Nothing per run
  but that offset.
- **Written by `build.py`** as a new section of the `.exp` (format doc updated): per column
  the walking height (one byte, a sentinel for no floor), per cell an 8-bit neighbour mask
  (straight moves; a diagonal only when both straight neighbours are open, so no corner
  is cut), and a clearance byte (distance to the nearest wall) for wide mobs. Cells that
  change in a run are flagged, not baked: the door (passable only while open, read live)
  and diggable ore (treated as solid; a dug cell only offers a shortcut the grid ignores).
- **Two queries:** `path(from, to, clearance)`: A* over the grid with a binary heap;
  `field(goal)`: a full breadth-first distance field to one cell, computed on first use
  and kept for the server's life (template plus goal cell is the key, shared by every run).
  The evade guide walks the field's gradient; chases use `path`.
- **Line test:** whether the straight line between two cells is walkable, rastered over
  the neighbour masks, without reading a node.
- **Off-grid:** a mob in the air, knocked into a wall or in water snaps to the nearest
  walking cell within two nodes, else the guide answers nil (fallback §3.1).

### 3.3 Shared files

| File | Lanes | Rule |
|---|---|---|
| `grug_mobs/aggro.lua` | TRAIL, NAV | TRAIL owns the evade seam; NAV only registers its guide from `grug_expeditions` |
| `mobs/grug_nav.lua` | NAV (TRAIL only if a crumb hook is unavoidable) | NAV adds the Expedition backend behind `nav.search` and the line test; TRAIL reports a needed hook to the coordinator first |
| `docs/design/expeditions.md` | QUICK, NAV | each its own section |
| `grug_expeditions/catalogue.lua` | QUICK | only QUICK |
| `CHANGELOG.md`, `docs/STATUS.md`, `game.conf`, `upgrade.json` | D | only D, at the round's end |

## 4. Lane goals

### QUICK

- `CLOSING_SECONDS` 60 → 30 for Finish and Cancel; `CLOSED_SECONDS` stays 10.
- `DESERTER_SECONDS` 300 → 120.
- Wall traps every 2 s: the template sources (`last_mint.py` SHOT_PERIOD 6 → 2, its
  second group's offset 3 → 1; `second_shift.py` 8 → 2; `test_vault.py` stays the probe),
  the `.exp` rebuilt, `build.py --check` and the template proofs green.
- Every text and doc naming the old numbers (grep for them: 60 s, "a minute", 5 minutes,
  the trap periods) brought in line; fixtures pinning them updated.
- No engine run.

### CAST

- **Finding (coordinator, 2026-11-10, to be reproduced first):** a self skill pressed
  with a hostile in the crosshair gets one try at key-down (`input.lua` `activate`). In
  melee the action clock is busy most of the time (a swing holds casts back one weapon
  interval), so the try is refused "You are still busy." and the rest of the hold strikes
  instead (the held fallback). At air the warrior is rarely mid-swing, so it works.
- **Repeated clicks (user, 2026-11-10):** clicking several times did not fire them
  either. The coordinator's reading supports the user's suspicion: a click lasts more
  than one input step; its first step tries the cast (refused "busy"), its later steps
  are a held press, whose self-skill branch calls the Strike fallback without a refusal
  reason, so the fallback swings; that swing makes the clock busy for the next click
  again. Every click thus ends in a Strike and no click ever finds the clock free. The
  lane confirms or refutes this by the fixture, and the fix must cover it.
- First a fixture that reproduces both failures on 0.73.1 (held Strike on a mob,
  Ruination pressed mid-swing: refused, never cast; and a series of short clicks on
  Ruination at a mob: only Strikes, never the cast).
- Then the queue: a fresh press of a self or support skill refused for "busy" or
  "interval" is kept and fires at the first step its clock allows, before the next swing
  of the hold (the held fallback does not swing while a cast waits). It is dropped after
  one weapon interval plus a grace (lane proposes the number), on a hotbar switch, on
  death, or when another refusal (cost, cooldown, lock) appears. One queued cast at a
  time; a new press replaces it. Cost and cooldown refusals stay immediate and loud.
- **Coordinator default:** the queue serves every class's self and support skills (Ice
  Nova, Blink, heals as well), not only the warrior's; the lane checks each self skill of
  every class for a reason it must not wait (a movement skill firing late) and reports.
- While a self skill's cast waits, or its press was refused for "busy" or "interval", no
  fallback swing of the same press fires before the cast did (or the wait was dropped).
- Fixtures: the new one; the input and warrior fixtures that test the press decision
  (`r53_warrior`, the K8 fallback, `r36_*` input fixtures the lane identifies by reading).

### MOUNT

- **Coast:** `grug_mounts.flight_rule` allows coastal water whose owning zone allows
  flight: the water classes the zone query gives an owner (belt and bay,
  `grug_zones.water_query_at`) take that zone's rule (contested or the faction's home:
  yes; enemy home or a dragon island: no). Open sea and the dragon channels stay
  forbidden. The minimap overlay follows by itself (same rule; this file's source is in
  its cache key). The lane measures and reports how far the flyable coastal strip
  reaches from the shore (a few sample coasts) and the rule's cost per call.
- **Login:** at logout (and at shutdown, same path) the ride's mode (`fly`, `ground`,
  `water`) and nothing else is saved in the player's meta; the tier is already there. At
  join the player is held (no gravity, no movement) until the block is active, the mount
  of that mode and tier is summoned and the player seated, then released. When the ride
  is not allowed there (flight rule, ceiling, an enemy town, a boat off water) or does
  not appear within a few seconds, the player is set down on the ground below without
  fall damage (a flying one) or simply released (on the ground). The meta key is cleared
  in every outcome. The logout keeps its teardown dismount.
- Fixtures: the flight rule's and the overlay's (`r531_flight`, `r72_mounts`, others the
  lane finds), `r56_mount`, a new one for save, restore and each fallback.
- One engine run if a client join can be scripted headless; else the fixture plus the
  GUI checklist, and the lane says so.

### TRAIL

- The evade seam (§3.1) in `aggro.lua`, with a fixture guide.
- The trail: while a mob chases (from the moment it leaves its post or wander area), it
  drops a waypoint about every 8–10 nodes of real movement, and one wherever its
  navigation had to take a detour; at most about 10, runtime only (`self.temp`), cleared
  on arrival, death and unload. A new waypoint near an older one (about 6 nodes) cuts the
  loop between them, so kiting round and back leaves the short thread. Waypoints are
  recorded on the ground only (not mid-jump, mid-fall or swimming).
- The evade walks the trail backwards, straight from point to point; today's local
  search still handles a blocked leg, the 40 s teleport stays the net. A waypoint below a
  drop the mob cannot climb is skipped once the leg fails.
- The lane's numbers stay proposals until measured; it reports what it chose and why.
- Fixtures: a new one (spacing, the loop cut, the cap, ground-only, the backward walk
  with a fake world); the evade and nav fixtures that test the run home (`r42_nv*`,
  `r72_guardnav`). One engine run: mobs pulled round a few obstacles in a chosen region,
  evade arrivals and teleports counted against the same script on main.

### NAV

Goal: every mob path inside an Expedition goes over the precomputed grid (§3.2), so no
mob sticks at a wall or a ledge there.

- `build.py` writes the grid; `template.lua` reads it; a runtime module in
  `grug_expeditions` holds one grid per template and answers `path`, `field`, the line
  test and the cell of a world position.
- **Evade:** the Expedition guide (§3.1) walks the field of the mob's home.
- **Chase:** for a mob of an Expedition, `nav.search` (grug_nav.lua) uses the grid instead
  of the engine's `core.find_path`, and the line test replaces the node-reading line
  check. Because a search costs little, every Expedition mob searches as soon as its line
  is blocked (the strict rule's timing), not only after it got stuck; the stuck detector
  stays as the net. Replanning on target drift as today.
- **Wide mobs:** the clearance byte keeps a mob off cells narrower than its body; the lane
  reports which Expedition mobs are wider than one node.
- **Perf, numbers only:** A* typical and worst over every template, field build time, the
  grid's bytes per template; reported as comparisons, no targets.

**Verification (thorough, but aimed; user 2026-11-10):**

1. *Offline, Python (cheap, in `build.py --check`):* the grid of every template agrees
   with the proof's own height map; the neighbour masks are symmetric; every encounter,
   ambush, place, waystone and the chest reachable from the arrival over the grid (door
   open).
2. *One LuaJIT fixture `r74_nav`, run as few times as possible:*
   - an **independent derivation**: the grid read from each written `.exp` against
     `proofs.lua`'s height map from the same file, cell by cell, all four templates;
   - **A\* against breadth-first search**: for a few thousand random pairs per template,
     the path length equals the BFS distance, every step a legal move (height change at
     most one, free height, no cut corner), no path where BFS finds none;
   - **every field, exhaustively**: from every walking cell, the gradient walk reaches
     each home of the template;
   - the **offset**: the same answers translated for two slots;
   - **off-grid** starts (in the air, in a wall corner, in water), the **door** shut and
     open, **clearance** for a wide mob;
   - the timing numbers above.
3. *Engine runs, one per Expedition (three), plus one baseline:* in a prepared run, every
   pack's mobs dragged to points spread over the Expedition (behind corners, across
   stairs, on the far side of the lake), evade started; counted: arrivals, time, the 40 s
   teleport firing (target: never, reported as a number). And a chase: a probe player
   placed behind walls and round corners from each pack, counted: the mob reaching
   strike range, time. The baseline runs the evade half of the same script on 0.73.1
   (one run, the Expedition the lane picks as the worst today) for the comparison.
4. *Review:* independent, with the walk model against the engine's collision (stairs,
   slabs, the door, ore) as its first question.

### D

STATUS, CHANGELOG 0.74.0, README paragraph, `AGENTS.md` current state, design docs
(`expeditions.md` closing, Deserter's Mark, trap interval, the grid; `mounts.md` §4 the
coast, the restore; `combat_stats.md` §4 the evade guides and the trail;
`ability_targeting.md` or `classes.md` the queued cast), the template format doc, the
GUI checklist (§6) completed from the lanes' excerpts, the completion section.

## 5. Rules

- "Expedition", never "instance", in code, docs, briefs and reports.
- No new node, sound or texture.
- No change to the templates' rooms, packs, traps or proofs beyond the trap periods
  (QUICK) and the grid section (NAV).
- No saved format change but the two meta keys of MOUNT; the `.exp` is not saved state.
- Perf numbers are comparisons, not targets; markedly slower or more complex goes to the
  user.

## 6. Verification

Fixtures: each lane's own and those that test the behaviour it changes (§4); the round's
one full run at the end by the coordinator. Engine runs: NAV three plus one baseline,
TRAIL one, MOUNT at most one; QUICK and CAST none.

Release check at the round's end: compatible (no map reset; templates are written at
each preparation, a restart ends every run; the new meta keys need no migration).

### GUI checklist (desktop and web)

Drafted here, completed by D. *(not proven)* marks what no engine run showed.

1. Finish an Expedition: the countdown starts at 30. Cancel one: 30 as well, entry closed
   at once.
2. Cancel: the Deserter's Mark shows 2:00 and counts down.
3. Last Mint and Second Shift: a wall fireball every 2 s, still passable with timing.
4. Warrior surrounded, holding Strike on a mob: Ruination and Hold Ground fire on a press,
   at most a swing later. The same for another class's self skill (Ice Nova).
5. Short clicks on Ruination at a mob while fighting: the first click that finds it
   ready casts it (no endless Strikes).
6. Ruination with too little rage: refused at once with the rage notice (no waiting).
7. Fly out from a friendly or contested coast over the bay and the coastal water: no
   warning, no dismount; further out over the open sea: warning and dismount as before.
8. Fly towards the enemy's coast over water: warning and dismount at its coastal strip.
9. Minimap: the no-fly overlay shows the flyable coast.
10. Log out in flight, log in: seated on the flying mount in the air, no fall. The same on
   a ground mount and in a boat.
11. Log out in flight, then (as admin) move the player over an enemy area, log in: set
    down on the ground, no damage.
12. Server restart while riding: the ride is back after the restart.
13. Overworld: pull a mob round a house or a rock ridge until it evades: it walks back the
    way it came, no sticking.
14. Expedition: pull a pack far through passages and stairs: every mob walks home without
    sticking or teleporting.
15. Expedition: stand behind a pillar or round a corner from a mob: it comes round, does
    not run into the wall.

## 7. Orchestration notes

- **Start state:** main at this plan's commit, 0.73.1.
- **Worktrees:** `.claude/worktrees/round74` for the integration branch, one per lane
  (`r74-<lane>`). The `character-creation` worktree and branch are not touched (the user
  has not decided yet).
- **CPU: LuaJIT runs sparingly and aimed** (user, 2026-11-08 and 2026-11-10). Launch
  prompts carry: "Fixtures: run only the fixtures that are strictly needed, your own and
  those that really test the behaviour you change, as few times as possible; no full run
  (the coordinator runs it once at the round's end); name what you ran and why." Shared
  queue `r45/lua_run.sh`, at most 8 Lua processes. NAV's thoroughness lives in one
  fixture with many cases and in Python checks, not in repeated runs. Engine runs only as
  listed in §6, each with its question. Reviewers repeat no run a lane reported. After a
  merge the coordinator runs only the merged lane's fixtures and those of a conflict's
  files.
- **Building templates** is Python and cheap; `build.py --check` belongs in QUICK's and
  NAV's reports.
- **Merge order:** QUICK, CAST, MOUNT, TRAIL, NAV (§1). A lane whose files an earlier
  merge touched merges `round74` in before its review.
- **Compaction checkpoints:**
  - **C0** before the start (this planning).
  - **C1** after QUICK, CAST, MOUNT and TRAIL are merged (NAV may still run).
  - **C2** after NAV's merge, the full run and D, before the squash merge to main and the
    GUI test.
- **Landing:** one squash commit on main, tag `round-74` on the round branch's tip, the
  branch and its worktrees removed, `tools/sync_to_luanti.sh`, no push.

## 8. Open questions

None blocking. Decided during the round: the queue's grace (CAST), the trail's spacing
and loop distance (TRAIL), the grid's exact byte layout (NAV); each reported with why.
