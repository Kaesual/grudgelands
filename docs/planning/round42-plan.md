# Round 42 — Mob navigation: getting unstuck

Coordinator: Claude (Opus 5.5), drafted 2026-10-07 from the user's
playtest reports (a bodyguard caught on a door frame, villagers and
roaming guards in the start town walking into walls "forever", pigs stuck
behind trees in combat), three read-only research passes (the existing
pathing code, the settlement walking data, the engine pathfinder) and the
user's answers of the same day; revised after an independent Opus review
(verdict "ready after fixes", every finding checked at the cited lines).
Status: **running** (the user's go 2026-10-07 after Round 41; NV0 merged,
calibration ruled 2026-10-08, rulings 18–20).

The user calls this a high-risk topic: navigation has to feel good
without a hard hit on server performance. The round replaces today's
patchwork of stuck handling with one rule set built on the engine's own
pathfinder, used rarely, locally and only where it matters: in combat, on
fixed walks (patrols, posts, royal guards, villagers, evade) and through
doors. Free roaming stays as it is. Routing default (agent model policy,
the user decides per session): Claude coordinates, Opus implements and
reviews; no Astra lane.

## 1. Lanes and waves

| Lane | What | Wave | Kind | Waits for |
|---|---|---|---|---|
| NV0 | Navigation test scene (engine probe), before-numbers, calibration | 1 | probe (tools only) | Round 41 merged |
| NV1 | Navigation core and combat: stuck detector, local search, path checks and smoothing, follower; replaces the old combat stuck logic | 2 | code | NV0, the user's calibration answer |
| NV2 | Fixed walks: patrols, posts, royal follow, evade, rift boss, named rares on the shared follower | 3 | code | NV1 merged |
| NV3 | Settlement walkers and routes: route cache in start towns and capitals, capital patrols over streets, all villager walkers on the follower, the one-spot walkers | 4 | code | NV2 merged |
| DR | Doors: NPCs open, pass and close doors on settlement routes | 5 | code | NV3 merged |
| PT | The user's playtest of NV1–DR | 6 | GUI | DR merged |
| CL | Cleanup: dead code, settings, fixtures and leftover docs of the old stuck logic | 6 | code + docs | PT |
| D | Round documentation, version 0.42.0 | 7 | docs | last merge |

The code lanes touch the same movement files and run one after another.
Each lane replaces the old logic of what it takes over in place
(ruling 17); CL only sweeps up what is then dead.

Estimates (unmeasured, for planning only): NV0 4–6 h, NV1 8–12 h, NV2
4–6 h, NV3 8–12 h, DR 4–6 h, CL 3–5 h, D 2 h; each code lane plus its
review. NV1 and NV3 are the large lanes.

## 2. Rulings

The user (2026-10-07). Numbers marked *guide* are guide values that NV0
calibrates and the user confirms (round workflow: rough targets, not hard
conditions); the user asked for numbers with a basis, not guesses.

1. **Three stages, no custom pathfinder.** Stage 1 is today's cheap
   straight walk. Stage 2 is the engine's `core.find_path`, used locally
   and rarely. A pathfinder of our own in Lua is not built: a smarter use
   of the engine's search is expected to suffice.
2. **Stuck detection:** a mob that *wants* to move but moved itself less
   than it should for its current speed over the window is stuck (*guide*
   threshold about 30 % of the expected distance). The window is **0.5 s in
   combat** (mobs and guards) and **1 s otherwise**. Not stuck by
   definition: frozen, rooted, stunned; striking in reach; wind-up,
   telegraph, cast; knockback; every intentional stop. "Wants to move"
   uses the speed the mob currently has (slows, evade speed). Progress
   toward the target is not the measure: a target that runs away faster
   than the mob is no stuck mob.
3. **Free roaming is not watched.** A wild mob idling on open ground is
   uncritical; no detection there. That includes the camp roam cap, the
   wander leash and the walk back to shore (`aggro.lua:536-684`), which keep
   today's straight walk.
4. **Combat: a short, local detour, never a long fixed path.** When stuck:
   - target close (*guide* about 16 nodes): search directly to the
     target with a small padding;
   - target further: pick an intermediate point toward the target first
     (a fan of candidates in the target's direction, *guide* a first ring
     at about 10 nodes and a second at about 16 if the first fails;
     within about ±2–3 nodes of height; standable, with headroom for the
     mob) and search to it;
   - follow the path; leave it as soon as (a) the intermediate point is
     reached, (b) the target moved too far from the planned end, or (c)
     the straight line to the target is walkable again; then back to
     stage 1. The walkable-line test (c) runs regularly while following,
     not only at waypoints (*guide* about every 0.5 s).
5. **Fixed targets follow the path to its end:** patrol waypoints, posts,
   villager spots, an evading mob's home, and a royal guard's leader while
   the leader is idle at its seat (Round 41 ruling 2). A leader that moves
   in a fight is a moving target: the guard's follow then uses ruling 4's
   tracking (leave the path when the leader moved too far from its end). A
   mob more than about 2 nodes off its route (*guide*) searches locally
   back to the next route point ahead.
6. **Path checks after the engine search:** headroom for the mob's height,
   and width for mobs wider than one node. Unknown or unloaded nodes count
   as blocked.
7. **Diagonals:** the engine's path moves in four directions only. The
   follower smooths it: where the geometry allows, the mob goes straight to
   a later waypoint. A diagonal step needs both corner cells free from feet
   to head and ground under them; the walkable-line test of ruling 4 (c)
   accepts steps up to the mob's step height and drops up to its fear
   height, so it works on natural, stepped ground.
8. **Cost control:** the expensive search is locked for a mob for a while
   after each attempt (short in combat, longer otherwise), and every
   search runs inside the existing per-step A* budget and negative cache
   (AGENTS.md).
9. **Giving up in combat:** after repeated failed searches (three, as
   today) a mob gives its target up **also when it can see it** (this
   reverses the Round 30 rule "visible is never given up"). Giving up stays
   the leash reset with its heal, but the "ignore this player" veto lasts
   longer: until the player moved about 8 nodes or about 15 s passed
   (*guide*), so a mob behind a fence cannot loop give-up and heal every
   few seconds.
10. **Evade:** an evading mob or guard that does not get closer to its
    home for 1 s makes a small local search to a better point toward home
    (*guide* radius 4–6, ±2–3 height; the point is chosen before the
    search, in home's direction). The 40 s evade snap stays, also while
    watched; with the local search it should almost never fire.
11. **Snaps:** "teleport only when unwatched" stays; the royal guard snap
    and the evade snap stay its two exceptions. Nothing changes here unless
    the playtest shows a need.
12. **Villagers may use the pathfinder** (this reverses
    `settlements.md:533` "a static resident asks the pathfinder nothing at
    all" for the walkers; residents that never leave their spot still ask
    nothing). Planned for cost: routes are cached where they repeat.
13. **Cached routes only in start towns and capitals** (hard-protected,
    unchanging terrain), where many fixed point pairs repeat. A route
    between two fixed points is computed once on first use, smoothed,
    stored as corner points and reused. Villages (one walker with two spots
    each on seed 42, §3.3), camps and the fortress (post guards only) get
    no cache; their fixed walks use the shared follower of ruling 5.
14. **Capital patrols run over street sections.** The planner knows the
    streets, and the carriageway is kept free (furniture stands on the
    verge). Only the short stretches into plots and gate towers use cached
    paths.
15. **Doors (DR):** NPCs on settlement routes open a door, pass and close
    it again (variant b). **NPCs may open and close doors in settlements:**
    the second recorded exception to the terrain-damage guard besides the
    rift's crack (AGENTS.md; DR adds it there). NPC door use plays the
    doors' existing open and close sounds; no sound approval needed.
16. **One-spot walkers** (2–6 per capital) are fixed: a walker always has
    more than one destination (`settlements.md`: "a walker with one
    destination is a walker that never moves").
17. **Replace, don't add.** The new detector replaces the old short stuck
    triggers in the same lane that takes a mover over: mobs_redo's stuck
    timer, the blocked-LOS trigger, the sidestep and the crawl in NV1;
    `stall_clock` → `path_nudge` on patrols, posts and the royal follow in
    NV2; the villagers' stall handling in NV3. Two detectors never run side
    by side. The later stages that exist today (skip a patrol waypoint,
    pick the next villager spot, the unwatched snap) stay as later stages
    fed by the new detector. CL, after the playtest, only removes what is
    then dead.
18. **Calibration (the user, 2026-10-08, after NV0's report;
    `tools/r42_nv0/evidence/before/`).** Every NV0 proposal is taken; they
    stay guide values:
    - stuck threshold 30 % of the expected self-movement, measured against
      the speed the mob really has (after the water slowdown);
    - target "close" 16 nodes; candidate rings 10, then 16; height band ±3;
      head room ceil(mob height) cells;
    - the walkable-line test every 0.5 s in combat, every 1 s on fixed walks;
    - "off route" 2 nodes;
    - the give-up veto 8 nodes or 15 s;
    - the evade local search radius 6, ±2;
    - search padding 6 and **never below 2** (an engine crash below,
      `docs/technical/upstream-workarounds.md` §5); no leg longer than 32
      nodes in one piece;
    - lockout per mob 1 s in combat, 5 s otherwise (the existing no-path
      waits on top); a global cap of 20 searches per second, provisional —
      NV1 reports the real demand.
19. **Wide mobs** (NV0 finding F3): the engine's search cannot produce a
    route for a mob wider than one node. Where the width check rejects
    every path, the mob gives up like any other (a rejected path counts as
    a failed search; ruling 9); no extra mechanism.
20. **Tall mobs** (NV0 finding F4): mobs taller than 2 nodes (elites and
    royal guards 2.38, the bog ooze 2.03) get a physics collision height
    just under 2, so they pass 2-high doorways; their look and their
    selection box stay (the head clips through a lintel while passing).
    NV1 builds it.

Coordinator defaults (the user may overrule them):

- **A global cap on searches per second**, counted as a number of searches
  (never a time budget, AGENTS.md), on top of the per-mob lockout of
  ruling 8.
- **Every search has a bounded box** (*guide* padding about 4; no leg
  longer than about 32 nodes, *guide*, goes to the engine in one piece):
  the per-step A* budget only decides whether a search may start, not how
  long it runs, and a long leg measured 13–25 ms (§3.3). Long legs are
  split at intermediate points or run over streets (ruling 14).
- **Fallback for doors:** if DR fails, indoor spots behind doors leave the
  walkers' rings (variant a).
- **Mobs meeting head-on** need no special rule: actors pass through each
  other since 2026-09-17 (`mobs/api.lua:4315-4317`,
  `grug_mobs/separation.lua:4`). The user asked for a small fallback for
  NPCs blocking each other; with pass-through there is nothing to block. If
  the overlap looks bad in the playtest, a cosmetic "one waits briefly" can
  follow.
- **Counting failures for the give-up:** failed searches in a row against
  the same target within one stuck episode count, whether they aimed at the
  target or at an intermediate point and however the target moved;
  progress resets the count. Today's count ("three failures against a
  target whose node did not change") would never give up a visible target
  that keeps moving.
- **Named rares' patrol routes** (no stuck handling today,
  `rares.lua:323`) use the follower too: they are patrols.
- **The technical details** of rulings 6 and 7 (unknown or unloaded nodes
  count as blocked; the corner and step rules of smoothing and the
  walkable-line test) specify the user's rulings and are the coordinator's.

## 3. Research results (2026-10-07, verified at the cited lines)

### 3.1 Why mobs get stuck today

- **Combat** (`mobs/api.lua:1906-2089`): mobs_redo's stuck timer counts
  only below 0.5 m/s for 2 s (3 s while following a path), and A* runs
  only while the target-LOS ray is blocked (`:1939-1957`). A pig behind a
  trunk sees the player past the trunk while its wider body is blocked: it
  never searches. Round 30 made this a rule ("a visible target is never
  given up", `combat_stats.md:919-944`). A path is left only on
  reach-and-visible, above 60 nodes or at its end (`:2883-2918`); nobody
  compares the target's movement with the planned end.
- **Fixed walks** (patrol, post, royal follow): `stall_clock`
  (`grug_mobs/patrol.lua:130-152`) resets its yardstick whenever the target
  position changes, so a guard following a moving leader never accumulates
  stall time; small slides reset both clocks. `path_nudge` (`:232-258`)
  steers at the first path node only and forgets the path. Snaps are
  refused while any player is within 48 nodes, so a stuck guard in plain
  view stays stuck.
- **Villagers** never ask the pathfinder (contract); an idle walker skips
  to its next spot after 15 s and has no snap stage
  (`start_villagers.lua:584-632`), so one in a pocket cycles forever.
- **Evade, roam cap, shore** walk straight with no stall handling (evade
  snaps after 40 s).
- **Kings and Generals** chase within their leash of 30 (`bosses.lua:586`),
  so their guards follow a moving leader in a fight.

### 3.2 The engine pathfinder

- `reference_projects/luanti/src/pathfinder.cpp` (about 1400 lines): grid
  A*, four cardinal directions, one waypoint per node. It checks that a
  cell is not walkable and stands on walkable ground; it checks neither
  headroom nor width, and treats every walkable node as solid: **a wooden
  door is a wall, open or closed** (`doors/init.lua:87`, `:426`).
- `searchdistance` is a padding around the box of start and goal, not a
  range (`lua_api.md` `core.find_path`). A failed search explores every
  reachable cell in that box, so its cost grows with the box. Today's
  padding of 24 makes a box of over 2300 ground columns; a local search
  with padding 4 to a point 12 nodes away about 160 (computed, not
  measured).
- Measured costs (Round 30 perf review, workstation): a found path 14–211
  µs, a failed search at padding 24 2–3 ms (`combat_stats.md:906-911`). The
  A* budget is about 3 ms per server step, but it only gates the start of a
  search (`mobs/grug_obstacle.lua:203`, `:219`); a started search runs to
  its end.

### 3.3 Settlement walking (read-only engine probe, seed 42, 2026-10-07)

- Walkers walk a ring of fixed spots in authored order; patrols walk fixed
  loops; post guards wander and return. Static residents never move. Each
  of the six villages has one walker with two spots.
- Distinct point pairs: 60 in all six start towns together, 100–170 per
  capital, about 945 in the world. Villager legs median 11–13 m, max
  27–36 m; capital patrol legs median 44–69 m, max 169–281 m.
- Straight line blocked (collision walk test, pessimistic): start towns 22
  of 30 villager legs and 15 of 30 patrol legs, mostly by **tree trunks**;
  capitals 45–63 % of villager legs and 79–85 % of patrol legs (trees,
  walls, pillars, doors).
- One engine search per leg: start towns all 60 legs found, 4.3 ms in
  total; capitals 80–160 ms per capital, 19–26 legs without a path (mostly
  indoor spots behind doors, raised halls, a few endpoints the engine
  rejects), long patrol legs 13–25 ms each. Smoothed corner points: 1–2
  per leg typical, up to 12. RAM for all cached routes about 0.25 MiB per
  world (noisy measurement).
- These numbers come from a throwaway probe outside the repository; NV0
  re-measures what the lanes rely on.

### 3.4 The existing code (audit, line counts measured)

- In scope: 2066 lines (1240 code) in `mobs/grug_obstacle.lua`, the pathing
  parts of `mobs/api.lua` and the `grug_mobs` movement callers.
- Stays: the per-step A* budget with its queue and tokens, the negative
  cache, `fit_path_ends`, the collision-box cache, the one LOS ray per step
  and the punch gate, the contact run, evade, give-up and its veto, the
  snaps, roaming, separation.
- Replaced or removed (about 760 lines): the 1 s blocked-LOS trigger and
  the sidestep (ruling R3 of 2026-09-17), the walk-speed crawl of
  `path.stuck`, mobs_redo's stuck timer and the two stuck timeout settings,
  `keep_path`, `path_height_blocked`, `path_nudge`, rift `go_home`'s own
  route code, the dead dig branch of `apply_path`. New code is estimated at
  300–450 lines: a net reduction.
- **None of the replaced combat pieces has a fixture**; the new rules need
  their own.

## 4. Lanes (goals; the briefs add file facts)

Every lane updates the design docs whose rules it changes in the same
lane (round workflow §5.4: the docs are the spec its reviewer checks).

### 4.1 Wave 1 — NV0, test scene and calibration

An engine probe under `tools/r42_nv0/` that builds a test area and drives
real mobs through it: a single trunk, a row of trees, a wall with a
doorway, an L-corner, a fence (visible but not walkable), a pillar, a
ditch and a step, a two-node-high gap for a tall mob, a pond (a floating
mob crosses harmless water, Round 34), a wooden door (closed and open). It
reports per scene: reached or not, time to the goal, searches started and
their cost.

- Before-numbers on today's code: the scenes, the PvE micro run
  (`tools/r31_pvp/run.sh`) and Round 30's 40-blocked-chasers probe (kept
  outside the repository, in the orchestration folder under
  `r32/r1-evidence/probes/grug_probe_perf_a`; bring it in or rebuild it).
- Calibration of every *guide* value of §2 against the scenes, as a
  proposal to the user. NV1 starts after the user's answer.
- The probe stays in the repository: NV1–DR run it before and after.

### 4.2 Wave 2 — NV1, navigation core and combat

- One navigation module with: the stuck detector (ruling 2), the candidate
  fan and standability check (ruling 4), the local, bounded search through
  the existing budget and negative cache (ruling 8 and the defaults), the
  path checks (ruling 6), smoothing and the walkable-line test (ruling 7)
  and a follower with the abort rules (rulings 4 and 5).
- Combat uses it in place of mobs_redo's stuck timer, the blocked-LOS
  trigger, the sidestep and the crawl (ruling 17); the give-up rule, the
  failure count and the longer veto (ruling 9). The exclusions stay: no A*
  for dogshoot mobs and fliers, dragons and whelps never give up, kings and
  no-leash actors only drop their target.
- The walkable-line test treats harmless water as walkable for a mob that
  floats.
- `combat_stats.md` (§4, the close-cover ruling R3, the crawl, the give-up
  at `:919-944`) describes the new rules.
- Fixtures for the detector (moving target, stops that are not stuck),
  candidate choice, the follower's abort rules, lockout and cap, give-up,
  failure count and veto. Before/after numbers on NV0's probe and the PvE
  micro run.

### 4.3 Wave 3 — NV2, fixed walks

- Patrols, posts, the royal follow (rulings 5 and 4 for a fighting leader),
  the kings' and Generals' walk back to their seat (Round 41 ruling 2,
  however Round 41 built it), the evade run home (ruling 10), the rift
  boss's way home and the named rares' routes use NV1's detector and
  follower. `stall_clock` →
  `path_nudge` is replaced on these callers in this lane (ruling 17); the
  waypoint skip and the snaps stay as later stages (ruling 11).
- The docs describe the new rules: `world.md` §4a (guards and camps) and
  §4b (the rift boss's way home, around `:779`), `settlements.md:485-487`
  (a guard that cannot reach its waypoint), and the A* paragraph of
  `docs/technical/module-guide.md:650-656`, which names `path_nudge` as the
  pattern to copy.
- Fixtures for each caller; before/after numbers on NV0's probe.

### 4.4 Wave 4 — NV3, settlement walkers and routes

- A route cache per start town and capital for walkers and patrols
  (ruling 13): computed on first use within the A* budget, every search
  bounded (§2 defaults), smoothed, corner points only, kept in memory (not
  in the world folder unless measurement says it is worth it).
- Capital patrol legs over street sections (ruling 14). If the street
  geometry is not available at runtime at reasonable cost, the lane stops
  and reports with options.
- All villager walkers, in villages too, move with the follower: on cached
  routes in start towns and capitals, with plain fixed-target following
  elsewhere. Their old stall handling is replaced in this lane (ruling 17);
  picking the next spot stays as a later stage. The return to a route
  (ruling 5) and the one-spot walkers (ruling 16).
- `settlements.md` (the contract at `:533`, the walkers) describes the new
  rules.
- Fixtures; before/after numbers in a start town, a village and one
  capital (searches per minute; the capital measured about 40–60
  `find_path` calls a minute before, `docs/research/wp13-polish-wave3.md:464-465`).

### 4.5 Wave 5 — DR, doors

- Routes that end behind a door are built as "to the door", "through the
  door", "from the door"; the NPC opens the door, passes and closes it if it
  opened it and no other NPC is right behind (ruling 15). A door left open
  by an unloaded or dead NPC stays open.
- `doors.get(pos):open()` without a player skips the interaction check, so
  NPCs open doors in protected settlements. Settlements also contain fence
  gates (`doors:gate_*`), which `doors.get` does not handle; the lane says
  what NPCs do at a gate (open it the same way, or route round it).
- NPC door use plays the doors' existing open and close sounds (ruling 15).
- The door exception is recorded everywhere the rift's crack is called the
  only one: AGENTS.md's terrain-damage guard (`:226-229`) and its rift line
  (`:396-397`), and `world.md:227-229` (ruling 15).
- Fixtures; NV0's door scene; the capitals' no-path legs re-counted.

### 4.6 Wave 6 — PT and CL

- PT: the user plays with the new navigation (checklist §6).
- CL: removes what the new rules left dead (the stuck settings and their
  `minetest.conf` block, the dig branch of `apply_path`, the negative-cache
  and lockout merge where it simplifies, any leftover helper), updates
  VENDOR.md's patch list and any doc line the lanes left, and the fixtures
  that pinned the old behaviour.

### 4.7 Wave 7 — D, documentation

The plan's completion section with the GUI checklist; STATUS, the AGENTS
pointer, ROADMAP, BACKLOG, README, `CHANGELOG.md` (0.42.0), `game.conf`'s
version and the `version` of `tools/web_data/upgrade.json` (the
declaration check requires both to match; Round 41 ruling 10).

## 5. Rules

- Stock clients only; all logic server-side.
- AGENTS.md performance rules: A* only inside the per-step budget; no
  `get_properties()` in per-step code; no wall-clock budgets in code; no
  pass handles every mob in one step. Performance numbers are before/after
  comparisons on NV0's probe, never targets; every lane reports the
  largest single search it measured; a lane that makes navigation
  noticeably more expensive stops and reports.
- A combat-path change reports the PvE micro run before and after
  (`tools/r31_pvp/run.sh`).
- Release mode (from 0.41.0, Round 41 rulings 9 and 10): every lane
  classifies its change as compatible, map reset or new server; this round
  is expected to be compatible (navigation is runtime behaviour, the route
  cache lives in memory). No backward compatibility beyond the contract.
- No world-generation change is planned: no seed fleet. If NV3 or DR needs
  data the mapgen must write (for example door or street records), that is
  a world-generation change and goes to the user first.
- Rulings this round reverses are rewritten where they live in the lane
  that reverses them: `combat_stats.md` (visible give-up, R3 close-cover,
  the crawl; NV1), `settlements.md:533` (NV3).

## 6. Verification

Per lane the gates of the [round workflow](../process/round-workflow.md#3-gates),
plus before/after numbers on NV0's probe for NV1–DR.

GUI checklist (desktop and web):

- Combat: a pig or wolf behind a single tree and behind a row of trees
  comes round; a mob behind a wall with a doorway finds it; a mob behind a
  fence gives up after a few seconds and does not come back at once; a
  fleeing player is not chased along an old path; ranged attackers at 25 m
  and more.
- The Accord and Throng fortresses: bodyguards stay with their General;
  push one out of the keep and watch it come back through the doorway;
  fight the General and watch his guards keep up.
- Start town: walkers and the patrol make their rounds without walking
  into trunks; post guards return to their posts.
- A village: its walker moves between its spots.
- A capital: walkers enter and leave buildings through doors (DR) and close
  them; patrols walk the streets; no walker stands frozen on one spot.
- Evade: drag a mob to its leash limit across rough ground; it walks home.
- Server feel with several fights at once (no hitches).

## 7. Orchestration notes

- Start state: main after Round 41's last merge.
- Process budget: at most 8 Lua processes at once (AGENTS.md); engine runs
  only through `tools/luanti_headless.sh`, at most two measuring runs at
  once.
- Files per lane (lanes run one after another; each later lane merges main
  before its review):
  - NV1: `mobs/api.lua`, `mobs/grug_obstacle.lua`, a new navigation module,
    `grug_mobs/aggro.lua` (give-up and veto), `combat_stats.md`.
  - NV2: `grug_mobs/patrol.lua`, `bosses.lua`, `start_npcs.lua`,
    `aggro.lua` (evade), `rift.lua`, `rares.lua`; `world.md`,
    `settlements.md` (the patrol rule), `module-guide.md`.
  - NV3: `start_villagers.lua`, `start_npcs.lua`, `patrol.lua`, the street
    data reader; `settlements.md` (the walkers and the contract).
  - DR: `start_villagers.lua`, the route cache, the door helper; AGENTS.md,
    `world.md`.
  - CL: everything above plus `minetest.conf` and VENDOR.md.
- Decided during the round: the calibrated *guide* values (the user, after
  NV0's report); whether the route cache persists in the world folder
  (NV3's measurement); PT's findings.

## 8. Open questions for the user

None before the start; both door questions were answered on 2026-10-07
(ruling 15). NV0's calibration report comes to the user before NV1
starts.
