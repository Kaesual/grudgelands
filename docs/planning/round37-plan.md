# Round 37 — Audit fixes: round plan

Coordinator: Claude (Opus 5.5), planned 2026-10-05 from the
[October 2026 audit](../audit-2026-10/README.md). Status: **approved by the
user on 2026-10-05 ("go")**.

A large fix round. It works through the audit's code packages P1–P5, the
cheapest mapgen win (MGT-02) and the mapgen robustness package P7, the sound
question of P9, and the documentation packages A–F. The audit documents are
the input: every lane reads its findings there (evidence, **Impact**,
**Better**, the `Verification (phase 2)` line) and the brief only adds what
this plan decides. Routing as in the last rounds: Claude orchestrates, Opus
implements and reviews (an independent Opus review per lane); no Astra lane
this round.

Starts on the user's go. The user's Round 36 GUI test is still under way;
its findings join lane F (§4.8) or the lane they belong to.

Not in this round: P6 beyond MGT-02 (the emerge memory of MGS-01/W13-01,
W13-02, MGT-04/05, MGS-03); P8 (the wp13/wp40 merge, mobs_redo as an owned
fork, `mod.conf` coupling, tooltip writers); the MGT-03 tree fix; most Low
findings; the Nether (V2).

## 1. Lanes and waves

| Lane | Wave | Kind | Content | Audit |
|---|---|---|---|---|
| **CB** Combat hot path | 1 | code | durability as its own cheap event, mount and use-hold on the max-HP clamp, PvP Strike fallback, knockback, then the dead WP38 path | P1 |
| **MB** Mob behaviour | 1 | code | retaliation through threat, swing animation, wind-up, `follow`, staticdata | P2 |
| **IX** Interaction bugs | 1 | code | right-click with seeds/bucket/rod, tall-crop tops, furnace form, grass and moss in protected ground, water-guard loop | P4 (without MOC-05) |
| **PO** Per-player polling | 1 | code | minimap, Claim Stone placement, inventory polling, quest markers | P5 |
| **MG** Mapgen | 1 | mapgen + tools | decoration halo off; seed fleet runs the per-chunk path; one runtime assembly for the tools; the tree bands documented | MGT-02, P7 |
| **SN** Sound | 1 | page, then code | a listening page for the three repurposed cues, the user picks, then wiring | P9, MOC-07 |
| **DA** Status sync | 1 | docs | push state, Round 36 late lanes, `findings.md`, acceptance, the open questions into BACKLOG | docs A |
| **MP** Mob persistence and bosses | 2 | code | rare duplicates, authored actors and the cap, restart, Bone Call, royal guards, breath and volley, breath patches | P3, MOC-04, MOC-05 |
| **DB** Agent context | 2 | docs | one owner per fact, AGENTS.md slimmed, `round-workflow.md`, ownership map, memory rules and templates into the repo | docs B |
| **DC** README | 2 | docs + small code | player README, CHANGELOG.md, the mapgen warning and `game.conf`, a visible version | docs C |
| **DD** World design docs | 2 | docs | capital zones, `biomes_mobs.md` split with a generated placement table, `world_zones.md` cleanup | docs D |
| **DE** Player design docs | 2 | docs | `skill_trees.md` split, naming cleanup, respec price, `sound.md` inherited set | docs E |
| **DF** Item docs | 2 | docs | one owner per item fact, the redirect, the DI Mediums | docs F |
| **F** Round 36 GUI findings | 1–2 | code | whatever the user's Round 36 test finds (empty until then) | — |
| **D** Round documentation | 3 | docs | completion, GUI checklist, status after the last merge | — |

Wave 1 starts together. MP starts when MB is merged (both work in
`mobs/api.lua` and `grug_mobs`). DB, DC, DD, DE and DF start when DA is
merged; DE also waits for CB and MB (both change `combat_stats.md`). SN's
wiring waits for the user's picks. D runs after the last merge.

## 2. User rulings (2026-10-05)

The user answered the planning questions on 2026-10-05, all as recommended
unless noted. Earlier rulings of the same day are in the audit's
[docs summary](../audit-2026-10/docs/00-summary.md#decisions-for-jan)
(memory rules into the repo, inherited sounds accepted).

### 2.1 Combat and mobs

1. **MOB-01, retaliation:** only through threat. A hit adds threat; the
   target changes only through `check_switch` (the 120 % hysteresis and the
   taunt lock). A mob without a target takes its first attacker. A mob or
   NPC hitter still draws retaliation; group alert stays.
2. **Durability (PLY-01, CORE-01, CMB-02, ITM-01):** exact but cheap. Wear
   is written per hit and the tooltip line "Durability: N / M" stays exact,
   but the tooltip is written once, and pure wear no longer fires the
   equipment-change fan-out (stats, look, abilities, Character page). Break,
   repair and an item swap still do.
3. **CMB-04, knockback on players:** only player melee in PvP and mob hits
   push. A refused or suppressed punch pushes 0; casts, arrows and ability
   damage push 0.
4. **MOB-07, the wind-up:** the facing freezes at the start of the wind-up
   and the ordinary melee swings pause until it resolves
   (`combat_stats.md` §3, "stop").
5. **MOC-04, breath fan and King volley:** the middle projectile homes, the
   two side projectiles fly straight and can hit bystanders; the breath's
   ground patch (`hit_node`) works again. The locked target takes one hit,
   not three; the boss numbers are re-checked.
6. **P3 defaults, all four accepted:** the Undead King's Bone Call gets a
   cap, the King's faction and despawns on the encounter reset (MOC-02);
   royal guards killed outside a King fight return after about 15 minutes
   (MOC-06); authored actors (dragons, Kings, rares, traders, leaders, the
   rift boss) do not count against `mob_active_limit` and are never deleted
   by it (MOB-03); a server shutdown no longer makes the despawn decision,
   so a restart keeps the world's mobs (MOB-06).

### 2.2 World and mapgen

1. **X-02:** grass spread and moss stop in towns, capitals, POIs and on
   roads (one GRUG PATCH with the existing territory rule); outside they
   run as before.
2. **MGT-01/MGS-02:** a failed per-chunk check still stops the server. The
   seed fleet also plans and writes a sample of chunks per seed (about
   +1–2 s per seed is fine), and the wrappers keep the traceback.
3. **MGT-03, trees at chunk borders:** later. This round only documents the
   bands (AGENTS.md mapgen section and the R6 contract) and adds a BACKLOG
   entry.
4. **DW-01:** the capital zones' hostile recipes are intended. The docs
   follow the code: only the city itself is spawn-protected.

### 2.3 README, sound and documentation

1. **RDM-01:** `game.conf` gets `disallowed_mapgen_settings` and the README
   warns anyway (the dialog still writes saved flags; chunksize, water level
   and mapgen limit are not in it).
2. **README:** the round log moves into a new player-facing `CHANGELOG.md`;
   `docs/STATUS.md` stays the agents' status. The game gets a visible
   version (in `game.conf` and Help → About).
3. **MOC-07, repurposed sounds:** a listening page this round (lane SN) for
   the dragon-return warning (`mobs_spell` today, gain 1.0 out to 160 m) and
   the Rift Spawn fuse and burst. Each cue offers "silent" as a choice.
4. **CTX-04:** the common lane brief, the review template and the Astra
   starter move into the repo; the handover log and the round briefs stay
   private.
5. **CTX-08:** Rounds 25–35 count as GUI-accepted; Round 36 (with F2, W2,
   W3 and RD) is open.
6. **DP-04, names:** `skill_trees.md` §2.11 moves to the archive in neutral
   wording; ROADMAP names the future classes as "further classes, names
   open"; the sound id `cast_frost_nova` gets a neutral name.

### 2.4 Coordinator defaults (the user may overrule)

Questions the audit raised that block a fix in this round, settled by the
coordinator in the direction the audit recommends:

- PLY-02: a max-HP clamp from an expiring buff or a gear swap leaves the
  rider mounted and the quest use-hold running; real damage still
  dismounts. CMB-06 (the clamp eats shield points) has the same cause and
  joins lane CB.
- CMB-03: the unreachable WP38 tool/fist path goes, including its GRUG
  PATCH blocks in `mobs/api.lua` (VENDOR.md updated).
- MOC-05: the rime and scorch patches are placed only into air; snow,
  plants and water stay.
- CORE-02: lane IX may run a short isolated headless probe that counts
  water-guard reverts at one capital edge and one coast.
- CORE-05: measure the minimap's client texture growth and report; the
  cell size changes only with the user.
- PLY-04: the cheap refusals (cube, overlap) are checked first; the
  messages keep their order.
- ITM-02: crops stay `buildable_to`; only the orphaned upper nodes are
  fixed.
- Design questions that block no fix (for example DW-04, DW-08, DI-14,
  DI-17, DI-27, CMB-10, Blink into claims, the fishing rod, fuels, rift
  void and shields, DP-10, DP-18): the docs describe the code as it is;
  lane DA collects them in BACKLOG under "Audit 2026-10 open questions".

## 3. Shared conventions

- **Re-check first.** Each lane's first step re-checks its findings against
  the code at its base commit and reports each ID as confirmed, changed or
  refuted. PLY-05 … PLY-09 and most Lows were never independently verified.
- Fresh-server mode: no migrations, aliases or compatibility code. A
  persistence change (MP) may drop old staticdata fields.
- Numbers are comparisons, never targets: before and after on the same seed
  and method. If a fix turns out clearly more complex or noticeably slower
  than planned, stop and report.
- Lows on the same code path may join a lane when they are size S and do
  not widen the review; the lane lists them. No other scope creep.
- World generation changes only in lane MG: `tools/seed_fleet/run.sh quick`
  before its merge, `full` once at the end of the round. Engine runs for
  mapgen follow the budget: a few runs of at most about 5 minutes, one
  final run of about 15 minutes over a chosen region, never the whole world.
- Mob and combat changes keep the terrain-damage guard (towns and POIs are
  never damaged; MOC-05's patches respect it).
- No sound ships without the user's pick on a listening page; lane SN only
  wires what the user picked or silences.
- Vendored code (`mods/BASE` and the mobs_redo fork in
  `mods/ENTITIES/mobs`): every change carries a `GRUG PATCH` marker and a
  VENDOR.md entry (X-02, CMB-03, MOB-01, MOB-04, MOB-07, MOB-02, MOB-05,
  MOB-03, MOB-06).
- Docs: English; one owner per fact once lane DB has set the owners; no
  explicit reference to any existing game; the factions are The Accord and
  The Throng.

## 4. Lanes (goals; the briefs add file facts)

### 4.1 CB Combat hot path (wave 1)

Durability as its own event (§2.1.2): the tooltip is written once per wear
event, the armour and enchant caches stay valid, and consumers that do not
depend on durability no longer run on it (or the seam is not called for
pure wear); break, repair and swap still fire the full change. Measure the
cost per hit in the engine before and after (one headless probe; a
comparison, not a target). The max-HP clamp (§2.4) in the mount handler,
the quest use-hold and the shield (CMB-06). CMB-01: the PvP Strike fallback
takes the current path (`melee_damage_add`, wear, trinket proc). CMB-04: one
`core.calculate_knockback` override per §2.1.3, keeping the existing
wrappers (riders, the dragon slam); `combat_stats.md`'s knockback section
says what pushes players. Then CMB-03: delete the WP38 machinery (about 300
lines) and its comments, as a separate last commit (§7: its `mobs/api.lua`
part merges after MP). PLY-11 (a Scout shot rebuilds the Character page)
may join. Fixture cases for each item.

### 4.2 MB Mob behaviour (wave 1)

MOB-01 per §2.1.1, with a portable test: a second player hits a tank-held
mob and the target holds; a taunt holds against other hits; a mob hit by a
mob still turns. MOB-04: the punch animation is held through the swing
(one GUI look in the checklist). MOB-07 per §2.1.4. MOB-02: the one-line
`follow` fix. MOB-05: `get_staticdata` no longer changes the live mob.
MOB-16 (pathfinding switch) may join. `combat_stats.md` §3/§4 stay true or
get corrected.

### 4.3 MP Mob persistence and bosses (wave 2, after MB)

MOC-01: rare liveness persisted, a duplicate removes itself on activation,
absence counts only while players are in range. MOB-03/MOC-03 per §2.1.6,
with a liveness check on the dragon's `alive` flag (also Isquarre's spawn
and the mob cap from the Round 36 carry-overs). MOB-06 per §2.1.6, with one
isolated headless restart test. MOC-02 and MOC-06 per §2.1.6. MOC-04 per
§2.1.5: re-check `tools/r36_r/numbers.py` and add the breath, and correct
the docs that describe the fan. MOC-05 per §2.4. Merge after MB; rebase on
its `mobs/api.lua` changes.

### 4.4 IX Interaction bugs (wave 1)

ITM-03: with seeds, a bucket or the fishing rod in hand, a right-click on a
node with `on_rightclick` (doors, chests, stations, regrowing crops) reaches
that node first. ITM-02 per §2.4. PLY-03/X-01: the furnace workspace no
longer re-shows its form over the recipe book or any other form. X-02 per
§2.2.1 (VENDOR.md entry). CORE-02: probe per §2.4 before and after, then
stop the flow/revert loop. ITM-10 (slab on slab loses the item) may join.

### 4.5 PO Per-player polling (wave 1)

CORE-04: the minimap updates a player only when something they see changed.
CORE-05: measure and report (§2.4). PLY-04 per §2.4. PLY-05: quest-tracker
holdings and discovery from inventory events instead of fixed polls, or a
cheaper poll. PLY-06: quest markers recomputed only when quest state or
level changes. PLY-16/X-13 (the 10 Hz weapon-hint poll) may join. Before
and after with the Round 32 perf study's method
([perf-review-2026-10-r32](../research/perf-review-2026-10-r32.md)), same stand-in count.

### 4.6 MG Mapgen (wave 1)

MGT-02: the decoration halo is 0 in runtime mode. Prove the output is
unchanged (byte-identical decoration candidates and written chunks on the
audit's sample of chunk columns, plus one engine pair on one region) and
report planner time before and after. P7 per §2.2.2: the seed fleet runs
`plan_slice` and the writer on a sample of chunks per seed; the wrappers
keep the traceback; the six tool copies of the runtime assembly become one
shared module the seed fleet and the other harnesses load (MGT-07, MGS-10).
MGT-03 per §2.2.3. Baseline: this round's opening `full` run (§7, the
roster hash per seed); the rosters must not change. `seed_fleet quick`
before the merge.

### 4.7 SN Sound (wave 1, wiring after the picks)

A private listening page (German, like Round 34's) for three cues: the
dragon-return warning, the Rift Spawn fuse, the Rift Spawn burst. Per cue:
the current file, a few candidates and "silent". Candidates first from the
existing downloads (`r32/r2-evidence/dl`, `r34/listen`, `r34/originals`;
copy, never move or delete), Freesound only through the serial lock
(`r34/fs_run.sh`), HQ previews only. After the user's picks: the cues play
through `grug_sounds`, the files are in `approved.txt` with credits, and
`cast_frost_nova` gets a neutral id (§2.3.6).

### 4.8 F Round 36 GUI findings (wave 1–2)

The findings of the user's Round 36 GUI test, filled in when they arrive;
the coordinator assigns each to F or the lane it belongs to. Fixture cases
for each item.

### 4.9 DA Status sync (wave 1, merges first)

Push state everywhere (Round 36 was pushed on 2026-10-05); the late Round
36 lanes F2, W2, W3 and RD in STATUS and the Round 36 completion; this
round's opening `full` run; acceptance per §2.3.5; `findings.md` refreshed
or archived (the four items fixed in code); BACKLOG "Audit 2026-10 open
questions" per §2.4.

### 4.10 DB Agent context (wave 2)

The audit's D2 proposal: one owner per fact, AGENTS.md slimmed to working
rules (about 350–400 lines; the round history lives in STATUS and the
round plans), `docs/process/round-workflow.md` replacing `wp-workflow.md`
with the real per-lane and round-end gates (CTX-05) and a post-merge status
step for lane D, a mod ownership map (CTX-12). Into the repo: the rules
that lived only in Claude's memory (the web-build particle budget and the
web target, the naming rule generalized to any existing game, the mapgen
engine-run budget, the review "happy path" scope, the node-alias and
send-front engine traps; CTX-11), the templates of §2.3.4, the PUC ruling
(ignored during development, an optional crash smoke test at the end;
CTX-03), the cap of 8 Lua processes (CTX-02), the routing practice (the
user decides per session; CTX-14), the `pairs` order rule in
`luanti-lua.md` (MGS-11), and the binding Lua rules out of `docs/research/`
(CTX-16).

### 4.11 DC README (wave 2)

The audit's D1 outline: what you can play, getting started and controls
(with the in-game Help tab), a short current state, install with the
mapgen warning and the first-start wait. The round log moves to
`CHANGELOG.md`. Small code: `disallowed_mapgen_settings` in `game.conf` and
the visible version (§2.3.1–2), checked with one smoke boot and a look at
the New World dialog in the GUI checklist. The main-menu setting
descriptions without code internals (RDM-16).

### 4.12 DD World design docs (wave 2)

DW-01 per §2.2.4 (with the stale comment at `spawn_policy.lua:209-210`);
`biomes_mobs.md` split into family specs and a placement table generated
from the recipes (the audit's 38-zone appendix as the first cut, the
generator under `tools/`); `world_zones.md` cleanup (DW-29, DW-30, DW-32 and
the other DW Mediums). The recipes are the placement authority.

### 4.13 DE Player design docs (wave 2, after CB and MB)

`skill_trees.md` split: delivery history and the citations pinned to an
old commit go to the archive (DP-02, DP-19); §2.11 per §2.3.6; the living
docs lose the other game's ability names (DP-04); respec price (DP-01);
`sound.md` gets the inherited-set paragraph (lane SN adds its cues);
DP-03, DP-07 and the Lows.

### 4.14 DF Item docs (wave 2)

The audit's D5 ownership proposal: `item_tiers.md` owns the numbers,
`items_crafting.md` the rules, `professions.md` absorbs §2.1–§2.3, and
`crafting_equipment_revision.md` becomes a redirect; the DI Mediums; the
crafting TODO dissolves (D18 to BACKLOG).

### 4.15 D Round documentation (wave 3)

After the last merge: the completion section here with numbers and the GUI
checklist, BACKLOG, ROADMAP, STATUS, CHANGELOG, and the status line of the
audit README.

## 5. Rules

As Round 36: AGENTS.md; `tools/check_lua.sh` (via bash) on every changed
Lua file; headless only through `LC_ALL=C chrt --idle 0
tools/luanti_headless.sh`, never the user's Luanti folder, kill and clean up
after; at most 8 Lua processes workstation-wide, fleets under idle
scheduling, never a wall-clock kill; agents never push. Engine workarounds
are listed in `docs/technical/upstream-workarounds.md`; the coordinator
checks it at the start of the round.

## 6. Verification

Each code lane: the re-check report (§3), its fixture and
`tools/run_fixtures.sh`, `python3 tools/check_fresh_server.py`,
`tools/r28_design/validate.py --game`, one smoke boot, an independent Opus review. Docs
lanes: an Opus review against the code (no number or rule changes without
a code source). Lane MG: `seed_fleet quick`. End: `seed_fleet full`, one
boot of main, `tools/sync_to_luanti.sh`, the user's GUI check (desktop and
web build; two clients for 1 and 6). No fresh world is needed for this
round's changes (MGT-02 leaves the output unchanged); Round 36 already
needs one.

1. Group fight: the tank holds the mob while a second player hits; a taunt
   holds.
2. An elite's wind-up: its facing freezes, stepping aside dodges, no
   swings during the wind-up.
3. A mob's melee swing animation plays.
4. On a flying mount, let a food or Vigor buff run out: you stay mounted;
   a quest use-hold continues; a shield keeps its points.
5. A long fight: the durability line counts down exactly; no stutter.
6. Knockback: punching an ally or an unflagged player pushes nothing; a
   PvP cast pushes nothing; PvP melee and mob hits still push.
7. Dragon breath and a King's volley: the side shots fly straight, the
   breath leaves ground patches, snow and water stay.
8. Undead King: Bone Call is capped and the summons vanish on reset; royal
   guards return after about 15 minutes.
9. Server restart: nearby mobs are still there; no second named rare.
10. Seeds, a bucket or the fishing rod in hand: right-click opens doors,
    chests and stations.
11. The furnace recipe book stays open.
12. Town dirt patches and roads by water stay as built.
13. The minimap is smooth; Claim Stone placement responds at once.
14. New World hides the mapgen options; Help → About shows the version.
15. The picked sounds play (dragon return, Rift Spawn), or stay silent.
16. Lane F's findings.

## 7. Orchestration notes (for the coordinator)

- **Start state:** main with the audit folder committed (it is this
  round's first commit; worktrees cannot see untracked files) and this
  plan. Worktrees `.claude/worktrees/r37-<lane>` (`cb`, `mb`, `mp`, `ix`,
  `po`, `mg`, `sn`, `f`, `da`, `db`, `dc`, `dd`, `de`, `df`, `d`),
  `tools/bin/` copied. Briefs in
  `~/projects/grudgelands-orchestration/r37/` from `r36/common-brief.md`
  and `r36/review-common.md` (after DB, from the repo templates); log in
  `r28/HANDOVER.md` under "ROUND 37". Check
  `docs/technical/upstream-workarounds.md` at the start.
- **Opening seed fleet (2026-10-05):** the `full` run owed after Round 36
  W3/RD ran on `0f169898` before this plan was committed: **303 of 303
  seeds build, 0 failed** (12 min 29 s, 8 parallel). The roster hash per
  seed (lane MG's baseline) is in
  `~/projects/grudgelands-orchestration/r37/fleet-baseline-0f169898.txt`.
- **Process budget:** seven code lanes in wave 1 share the cap of 8 Lua
  processes; the coordinator staggers fixture runs and lane MG's fleet.
- **Decided during the round:** lane SN's picks (user, page); lane F's
  list; any finding a lane refutes or finds bigger than planned (user).

**Shared files and merge order:**

- `mods/ENTITIES/mobs/api.lua`: **MB, then MP**; MP rebases on MB. CB
  merges its fixes when ready (after MB, see below); its CMB-03 removal is
  a separate last commit that merges after MP, so CB is not held up.
- `grug_core/combat.lua`: MB (threat) and CB (knockback, CMB-01); MB first.
- `grug_mobs`: MB, then MP.
- `combat_stats.md`: CB, MB and MP edit their own sections; DE starts
  after CB and MB and rebases over MP's later change.
- `grug_sounds`, `approved.txt`: SN only. `sound.md`: DE writes the
  inherited-set paragraph, SN its cues; whichever merges second rebases.
- VENDOR.md: IX (X-02 in `mods/BASE/default`), MB, MP and CB (mobs_redo
  patches) each add their entries; conflicts are resolved at merge.
- Docs: **DA merges first**; DB, DC, DD, DE and DF then work in parallel
  and merge one after the other, each rebasing (BACKLOG, ROADMAP and STATUS
  are shared); D last.
- Pages: lane SN's listening page is published privately by the
  coordinator; picks in `~/projects/grudgelands-orchestration/r37/`.
