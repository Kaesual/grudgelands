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
| HUD | The hotbar shows the action clock's block on skills without a cooldown; the waiting cast marked | 6 | independent; screenshots to the user before the merge |
| D | Docs, completion, GUI checklist | after every merge | coordinator |

Shared files are few (§3.3). TRAIL and NAV both touch the evade run; TRAIL merges first
and owns the seam both use (§3.1), NAV merges `round74` in before its review.

HUD was added at C1 (user's go, 2026-11-10); it branches from `round74` after CAST's merge
and runs in parallel with NAV's fix round.

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
- 2026-11-10 (at C1): an Expedition mob whose home the grid cannot reach (dragged across
  the Last Mint lake, which mobs cannot jump back over) is **set home at once**, as a pack
  jump does, instead of waiting for the 40 s teleport.
- 2026-11-10 (at C1): NAV may make **a fifth engine run** (Last Mint, after its fix round).
- 2026-11-10 (at C1): a new lane **HUD**: for a skill without a running cooldown of its
  own, the hotbar shows the block of the action clock or the cast interval as a **lighter
  cover without a number**, with few frames (HUD load); a running cooldown takes
  precedence; the **waiting cast** (CAST) gets a marker on its slot; screenshots go to the
  user before the merge.
- 2026-11-10 (after the HUD screenshots): the clock cover **may look exactly like the
  cooldown's** (50 % black): for the player a block is a block; it must above all be
  plainly visible (a lighter cover was barely visible on the dark icons). Still without a
  number and with few frames.
- 2026-11-10 (at the round's end): the flyable coast stays **variant A**, the whole coastal
  belt in front of the own and contested land (about 250–350 nodes off the shore), as
  MOUNT built it; no cap at the shallow shelf.
- 2026-11-10 (at the round's end): the clock cover keeps **4 steps** (`CLOCK_FRAMES = 4`);
  the constant is the knob if the GUI test asks for a smoother cover.

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

**Fix round (at C1, 2026-11-10),** before the review: narrow down by reading the three
open engine findings (Last Mint's chase found a path in only 36 of 122 searches; a Lava
Flan standing 40 s in the flue at a cell the grid calls walkable; the Flintback teleport
in the Stilled Seam); a mob with no grid way home is set home at once (§2); then one
Last Mint run (the fifth) with chase cells inside 32 nodes and off the lake, the wall
tolerance `W.BRUSH` in, answering the three findings.

### HUD

Goal: the player sees when the next cast can start. Files: `grug_abilities/cooldown_hud.lua`
(and `cooldown_math.lua` for new frames), a read-only seam from `init.lua` for the time
until the action clock or the skill's cast interval lets a cast start (the existing
`cast_wait`, `cast_refusal` or the clock itself; a small new export is fine, named), the
waiting state from `input.lua` (`s.waiting`, read through a small accessor).

- A skill in a hotbar slot with **no running cooldown or charge** of its own, whose cast
  the clock holds back ("busy" or "interval"), gets the cooldown's cover (50 % black,
  ruling after the screenshots), clearing like it, **without a number**, with **few frames** (lane proposes the
  count; HUD writes per second per player in a held melee fight reported before and
  after).
- A running cooldown or charge **takes precedence** over the clock cover in its slot.
- The **waiting cast** (CAST's `s.waiting`) gets a marker on its slot while it waits,
  gone when it fires or drops.
- No new globalstep: the existing pass of the overlay carries it; players without a block
  or a wait cost nothing more than today.
- Skills that do not use the action clock (gather mode, items that are not skills) show
  nothing new.
- **Screenshots** (`tools/r48_hud/capture.sh` method, one queue run): a melee hold with the
  clock cover on the free skills and a real cooldown beside it, the marker on a waiting
  skill; desktop and web scaling. They go to the user before the merge.
- Fixture: extend the overlay's own fixture or a new `tools/r74_hud/`; the CAST fixture
  only if the accessor touches the input state.

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
one full run at the end by the coordinator. Engine runs: NAV three plus one baseline plus
one Last Mint run after its fix round, HUD one screenshot capture,
TRAIL one, MOUNT at most one; QUICK and CAST none.

Release check at the round's end: compatible (no map reset; templates are written at
each preparation, a restart ends every run; the new meta keys need no migration).

### GUI checklist (desktop and web)

Completed by lane D from the lanes' reports. Every item on the desktop and on the web
client. *(not proven)*: no engine run showed it (fixtures only); *(only you)*: a look or a
feel only the user can judge.

1. Finish an Expedition: the banner counts down from 30; members outside get "… It ends in
   30 seconds."; entering is refused for the last 10 s. Cancel one with someone inside: the
   question says "… for 2 minutes.", the same 30 s countdown, entry closed at once.
   *(not proven)*
2. Cancel: the Deserter's Mark shows 2:00 in the refusal, the status row and the Effects
   tab, and counts down. *(not proven)*
3. The Last Mint's lake: a wall fireball every 2 s per armed line, the second line 1 s
   later; waiting on a top is safe and a timed jump still crosses. The Second Shift's
   gallery: a fireball every 2 s, still passable with timing. *(not proven; only you: still
   fair at 2 s?)*
4. Warrior surrounded, holding Strike on a mob, then Ruination pressed (also with the button
   held across the number key): it casts within one swing, with no "You are still busy."
   and no Strike before it. The same for Hold Ground, and for another class's self skill
   (Ice Nova after a Fiery Spark). *(not proven)*
5. Short clicks on Ruination at a mob while fighting: the first click once the clock allows
   casts it (no endless Strikes). *(not proven)*
6. Ruination with too little rage: "Not enough rage." at once, no waiting, and Strike
   swings. *(not proven)*
7. Fly out from your own or a contested coast over the bay and the coastal belt: no
   warning until about 40 nodes before the open sea (250–350 nodes out), then the dismount
   at the open sea as before. *(not proven; only you: the wide airspace, ruled variant A)*
8. Fly towards the enemy's coast over water: the warning, then the dismount at their coastal
   belt. *(not proven)*
9. Minimap on a flyer: the own and contested belt clear; the enemy's belt, the dragon
   islands' and the open sea red. *(not proven)*
10. Log out in flight, log in: seated on the flying mount in the air, no fall (engine-proven
    on the desktop client). The same on a ground mount and in a boat, and on the web client
    *(not proven)*.
11. Log out in flight, then (as admin) move the player over an enemy area, log in: set down
    on the ground below, no damage, one feed line (engine-proven with the rule forced to
    refuse).
12. Server restart while riding: the ride is back after the restart. *(not proven)*
13. Overworld: pull a mob round a house or a long wall until it evades: it walks back the
    way it came, turning at the corners, no sticking, no teleport. Kite one in a circle and
    away: it takes the short way back, not the circle. (Proven in the probe's arena; the
    real world *only you*.)
14. Expedition: pull a pack far through passages and stairs and let it wipe: every mob walks
    home without sticking or teleporting; elites in The Last Mint's passages too, at their
    speed. *(elites not proven)*
15. Expedition: stand behind a pillar or round a corner from a mob: it comes round, does not
    run into the wall.
16. The Last Mint: drag a mob across the lake until it evades: it is back home at once; one
    that fell into the lava, about 5 s after.
17. Hold Strike on a mob: Bellow, Ruination, Hold Ground and Unbroken get the cooldown's dark
    cover, restarting with each swing and clearing in 4 steps, no number; Charge on its own
    cooldown keeps its cover and number; Strike, Mighty Blow and Hamstring (swing skills)
    show no clock cover. *(only you: the 50 % cover live, plainly visible? the 4 steps
    smooth enough? swing skills without a cover right? The screenshots showed 25 % and
    38 % only.)*
18. Press Ruination mid-swing: a gold frame sits on its slot until it fires; a slot switch
    removes it at once. *(only you: the look)*
19. Mage: a Fiery Spark, then at once Blink: it fires when the 1 s ends, in the direction
    you look then. *(not proven; only you: Blink waiting, the coordinator's default)*
20. Priest: a Smite, then Heal pressed at an ally: it heals that ally when the clock allows;
    turn away from the ally before it fires: no heal, not on you either. *(not proven)*
21. Overworld: pull a mob off a high ledge it came up by stairs: it may stand at the face and
    teleport home after 40 s (unchanged, known; BACKLOG).
22. The Last Mint: drag a Lava Flan into an ambush alcove of the flue and let it evade: it
    walks out and home, no back and forth between the alcoves. The Stilled Seam: pull
    Flintback round his room until he evades: he walks home, no teleport. *(not proven: the
    fix and the hypothesis are fixture-only)*

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
  - **C2** after NAV's and HUD's merges, the full run and D, before the squash merge to main and the
    GUI test.
- **Landing:** one squash commit on main, tag `round-74` on the round branch's tip, the
  branch and its worktrees removed, `tools/sync_to_luanti.sh`, no push.

## 8. Open questions

None blocking. Decided during the round: the queue's grace (CAST), the trail's spacing
and loop distance (TRAIL), the grid's exact byte layout (NAV); each reported with why.

## Completion (2026-11-10)

Every lane is merged into `round74` at `a9dcc9ed`; this lane D runs on it. **Nothing is on
main and nothing is pushed:** `round74` lands on main as one squash commit (0.74.0, tag
`round-74`) after C2 and the user's word. CAST, MOUNT, TRAIL, NAV and HUD had an independent
review; QUICK the coordinator's.

**0.74.0 is compatible:** no step, no map reset. Every lane report says compatible (QUICK,
CAST, MOUNT, TRAIL, NAV, HUD) and lane D's reading agrees: nothing touches world generation,
the `.exp` templates (now with the walk grid) are written at every preparation and are not
saved state, a restart ends every run. Saved state: one new player meta key,
`grug_mounts:logout_ride` (the ridden tier id, written at logout and shutdown while riding,
cleared at the next join; a 0.73.1 world has none, which reads as no ride). A Deserter's
Mark set under 0.73.1 keeps its saved 5-minute end. `check_upgrade.py --base 4b6a91fc`
(0.73.1) passes.

### Lanes

`round74`'s first-parent merges from the plan `4b6a91fc` (lane tip in brackets):

| Lane | Commit | What | Review |
|---|---|---|---|
| QUICK | `d2411aec` (`fb5b288c`) | Closing 30 s, Deserter's Mark 2 min, wall traps every 2 s | coordinator |
| CAST | `835ddb88` (`06f2650f`) | A self or support skill refused for "busy" or "interval" waits and fires | MERGE AFTER FIXES (3), delta MERGE ×2 |
| TRAIL | `53c3b2c8` (`f4297595`) | The evade seam; the overworld evader walks home along its trail | MERGE (1 Low fixed), delta MERGE |
| MOUNT | `6b7854d5` (`83ebc4e6`) | Flight over the own and contested coastal belt; the ride restored at login | MERGE AFTER FIXES, delta MERGE AFTER FIXES (1 Major), delta MERGE |
| plan | `278e4459` | The user's C1 rulings: instant home, a fifth Mint run, lane HUD | — |
| NAV | `52f02e97` (`f3367e5a`) | The Expedition walk grid for every mob path, the instant way home | MERGE (1 Low: the docs' off-grid time, fixed by D) |
| plan | `3da62fc7` | The clock cover looks like the cooldown's | — |
| HUD | `a9dcc9ed` (`5c54721e`) | The action clock on the hotbar, the waiting cast marked | MERGE (2 Low) |

TRAIL merged before MOUNT (no shared files) while MOUNT's second fix round ran.

### What shipped, with numbers

Measured unless marked estimated; fixture numbers on the fixture's fake engine.

- **QUICK:** `CLOSING_SECONDS` 60 → 30, `DESERTER_SECONDS` 300 → 120 (every text reads the
  constants); The Last Mint's `SHOT_PERIOD` 6 → 2 (second group's offset 3 → 1), The Second
  Shift's gallery 8 → 2. The rebuilt `.exp` differ only in the trap lines (cells and param2
  byte-identical); `tools/r72_shift/balance.py`'s run lengths unchanged after rounding.
  Estimated: about 4 live balls over the lake at most (was 2).
- **CAST:** before (old `input.lua`): Ruination and Hold Ground pressed mid-swing were never
  cast (held, carried, clicked once); of 385 click series (weapons 1.0–3.0 s, 7 click
  patterns, 5 phases) 49 cast on the first click, on average on click 4.0, 24 never in 12
  clicks, 91 swung before the cast; Ice Nova or Blink after a Fiery Spark and Heal after a
  Smite never cast. After: every case casts at the first pass the clock allows (0 later than
  one 0.09 s pass), no swing before it; a held press swings on 0.35 s after the cast. The
  wait expires after `max(weapon interval, cast_wait) + 0.25 s` (the `init.lua` seam
  `cast_wait`, from the review); a waiting heal keeps its recipient. `r74_cast`: 53 checks.
- **MOUNT:** the flyable belt, along 64 rays from the centre (seeds 12345 / 42): min 7 / 12,
  median 338 / 329, max 548 / 693 nodes (oblique rays measure longer). The rule per call,
  old → new: belt 0.78 → 1.18 / 0.85 → 1.33 µs (one more `id_at`), land, planned water and
  the open sea unchanged within noise; the warning sweep at most about 50 µs/s more per rider
  over the belt (estimated). Restore engine run (seed 42, a real client): a flyer 40 up
  seated again after 0.18 s, lowest y 76.5 (was 76.5), hp 31 → 31; refused: set down at y 36.5,
  no damage, released after 0.27 s. The set-down searches the emerged column in 128-node
  stages to 512 below, never into lava (the nearest safe column within 4), last resort 30 s.
  `r74_mount`: 141 checks.
- **TRAIL:** waypoint every 8 nodes walked, every 3 during a detour, at most 10, loop cut
  within 6 (2 in height) to a point 18+ nodes earlier, reach 2, a leg's own search within
  16. Engine (seed 42, one probe, branch against base): wall 15.1 s home against 28.2 s, pen
  9.4 / 13.8, house 8.2 / 8.2, ridge 13.1 / 11.0, kite 10.3 / 9.2, ledge teleport 40.2 / 40.2;
  10 of 12 home against 9 of 11. Cost estimated: per chasing mob once a second a position
  read and a few sums, no node read. `r74_trail`: 44 checks.
- **NAV:** grid section 577 B (test vault) to 4.2 KB per template, 9–64 KB in memory, a field
  16 KB. A* median over random pairs 26 / 221 / 189 / 442 µs (test vault, Seam, Shift, Mint),
  10–13 µs within 24 nodes, worst 0.5–1.2 ms; a field build 0.3–1.3 ms, once per key. Engine
  runs (seed 42): baseline Seam on 0.73.1, corner wave 3 of 12 walked, 9 teleports, 313 s
  stood; Seam NAV 12 of 14 (2 teleports, Flintback and a spider sharing a home cell), stairs
  12 / 12, chase 12 / 12 (median about 5 s); Shift 18 / 18, 17 / 17, chase 13 / 13; Mint 18 / 19,
  15 / 17 (1 teleport, the flue). The fifth run (Mint, after the fix round): corner 20 / 20
  (median 8.0 s), stairs 17 of 19 (1 teleport, the flue flan before the fix; 1 reference lost
  at a block reload), lake 3 / 3 set home at once; chase 14 of 16 walked, 2 pack jumps; 28 of
  28 grid searches found a path (the first runs' 36 of 122 was the probe). Wider than one
  node: Giant Spider 2.1 (elite 2.94 in the test vault), Lava Flan, Land Guard and Duewarden at
  1.4 as elite or boss. `r74_nav`: 10,351 checks in 6.2 s.
- **HUD:** HUD writes per second per player in a held melee fight, 8 skill slots, today →
  4 steps: dagger 14.3 → 38.1, sword 14.2 → 30.9, two-hander 14.3 → 26.1 (all `hud_change`; the
  12 elements stay through the fight). The cover is the cooldown's (`CLOCK_OPACITY` 255, the
  coordinator after the user's ruling, `5c54721e`), 4 steps; the marker a 3 px gold frame.
  Two capture runs (desktop and web; the first's web crop failed). `r74_hud`, `r74_cast` and
  14 fixtures of the swing and cast paths green.

Round-end full run: 341 passed, 0 failed (coordinator, once, on `round74` a9dcc9ed with every code lane merged; lane D after it changed docs, release files and one comment only).

### The user's rulings during the round

All in §2: at C1 the instant way home (no grid way, or off the grid), NAV's fifth engine run
and the new lane HUD; after the HUD screenshots the clock cover like the cooldown's (50 %
black); at the round's end the coast width variant A (the whole belt) and 4 steps for the
cover.

### Coordinator defaults the lanes built

- CAST's grace 0.25 s after the weapon interval (or the real clock, after the review).
- Blink, the cone and the ground skills wait too and fire along the look at that moment (the
  user was told; excluding Blink by id is the alternative).
- TRAIL's spacing 8, detour 3, cap 10, loop cut 6 / 18 (the lane's proposals, kept).
- The coast width A, the whole belt (later the user's ruling).
- The ledge teleport kept: a mob pulled off a ledge it came up by stairs teleports after 40 s
  (BACKLOG).
- HUD's 4 steps (later the user's ruling) and the marker as a gold frame.

### Deviations

- HUD hooks `init.lua` beyond a read-only export: `occupy_casts` and `arm_cast_interval` call
  `cooldown_hud.block`, so the pass need not poll every player; reviewed, no behaviour change.
- NAV made a fifth engine run (the user's go at C1); its flue fix and the Flintback hypothesis
  are still fixture-only (GUI item 22).
- MOUNT saves one meta key, the ridden tier id, not the planned two (mode and tier): a tier
  gives its mode, and a Master owner may ride the Expert. Bays were already flyable since Round
  57; only the belt is new.
- CAST added the `cast_wait` seam to `init.lua` (review fix); NAV touched the `SISTERS` lists of
  `r71_frame`, `r721_finish` and `r72_waytab` (navigation.lua needs `mobs`).
- QUICK made no smoke boot (the plan's "no engine run" outranked the common brief).
- Merge order: TRAIL before MOUNT.

### Open for the user

- The [GUI checklist](#gui-checklist-desktop-and-web), 22 items.
- *Look* questions: the 50 % clock cover live, swing skills without it (item 17); the wall
  traps at 2 s (item 3); Blink firing late (item 19).
- Backlog: [BACKLOG](../../BACKLOG.md#round-74--the-way-home-the-waiting-cast-the-coast-gui-acceptance-pending).
