# Round 49 — Mapgen performance (native first) and gameplay polish

Coordinator: Claude (Opus 5.5), drafted 2026-10-15 from two partial plans the
user accepted the same day. Status: **planned; starts on the user's "go"**.

The round folds two partial plans into one round. They stay the detailed
specification of their lanes; this plan sets the lanes, the waves, the
process budget and the shared files. **Where this plan and a partial plan
differ, this plan wins** (e.g. the lane cut and the MEAS baseline):

- [mapgen-native-plan.md](mapgen-native-plan.md): ores, gems and cave plants
  from native v7, a simple Lua pass only for the terrain fill, no Lua for
  chunks without Lua work, JIT-friendly hot code, an integer hash instead of
  SHA-256, per-column caches, a smaller protection depth under towns, the
  preparation bottom for high massifs, a v7 flag measurement. Evidence:
  [mapgen-chunk-profile-2026-10.md](../research/mapgen-chunk-profile-2026-10.md),
  `tools/mgprof/`.
- [round49-gameplay-draft.md](round49-gameplay-draft.md): postage at Send,
  Sell tooltips, the Claim Stone in any carried list, the Housing Steward's
  button, starter kit on the hotbar, kill XP below the player's level, a
  rare tier, the short-range chase diagnosis and fix, ranged mobs regaining
  line of sight, smaller node items in the third-person hand, the half-buried
  onion.

Release **0.49.0**: a **map reset** (world generation changes: native ores,
cave plants, integer-hash decoration placement, the protection depth); no
migration step. Push only on the user's word.

Routing (the user, 2026-10-15, as in Round 48): Claude coordinates; Opus
implements and reviews. No Astra lane: the onion texture comes from the
existing generator (`tools/r48_artp/generate.py`).

## 1. Lanes and waves

| Lane | What | Wave | Kind | Spec | Merge waits for |
|---|---|---|---|---|---|
| ORE | Native ores, gems and cave plants; fill ores by a flat integer-hash pass; no ore exclusion under towns or deep water | 1 | world generation | mapgen §4.1 | — |
| JIT | Compilable hot code: R5 adapter (`resolve_voxel`, `classify`), replay pass folded, `zones.lua` column lookup; output byte-identical | 1 | world generation, refactor | mapgen §4.2 | — |
| PROT | Protection depth under towns (one constant, about 50 after measuring the deepest town surface) and the preparation bottom rule for high massifs | 1 | world generation + preparation | mapgen §4.4 | — |
| UI | Postage at Send; tooltips on the merchant's Sell rows | 1 | code + UI | gameplay §2.1–2, §4 UI | — |
| INV | Claim Stone in any carried list; the steward's button; starter kit on hotbar 7/8; a granted skill makes room | 1 | code + UI | gameplay §2.3–4, §2.10, §4 INV | — |
| MOB | Kill XP −10 % per level below; the rare tier | 1 | code + data | gameplay §2.5–6, §4 MOB | — |
| NAV | Phase 1: diagnose the short-range chase failures (report, no game change) | 1 | diagnosis | gameplay §2.7, §4 NAV | — |
| VIS | Node items at 70 % in the third-person hand; the half-buried onion | 1 | code + art generator | gameplay §2.8–9, §4 VIS | — |
| MEAS | Baseline: the first start of a fresh world (starts-only), one boot; the MGPROF boots are the per-chunk baseline | 1 | measurement | mapgen §4.7 | — |
| SKIP | No Lua for chunks without Lua work; the air check from planner data | 2 | world generation | mapgen §4.3 | ORE |
| HASH | Integer hash for the remaining digests (R6 candidates, P9G, P9) | 2 | world generation | mapgen §4.5 | ORE, JIT |
| CACHE | P9G 2-D result per column; column cache after a runtime-order probe | 2 | world generation | mapgen §4.6 | JIT |
| V7 | Measure `nomountains` and `noridges` one at a time (report, no change) | 2 | measurement | mapgen §4.8 | ORE, JIT |
| NAV2 | Phase 2: the fix the diagnosis supports; ranged ground mobs path to regain line of sight | 2 | code | gameplay §2.7, §4 NAV | NAV report (shown to the user first when it changes a Round 42 ruling) |
| V7A | Adopt a v7 flag, only on the user's word after V7 | 3 | world generation | mapgen §4.8 | V7, the user |
| MEAS2 | After: the mgprof corpus, the native ore count per tier, the fresh-world first start | 3 | measurement | mapgen §4.7 | the last world-generation merge |
| D | CHANGELOG, STATUS, README, BACKLOG (WP48), the plan's completion and GUI checklist | 3 | docs | §4 D here | the last merge |

Wave 1 runs nine lanes (four world-generation or measurement lanes, five
gameplay lanes); wave 2 starts each lane as soon as the lanes it waits for
have merged.

## 2. Rulings

The rulings of the two partial plans hold unchanged:
[mapgen plan §2](mapgen-native-plan.md#2-rulings-the-user-2026-10-15) (1–9) and
its answers in §9, and the
[gameplay draft §2](round49-gameplay-draft.md#2-rulings-the-user-2026-10-15)
(1–10, coordinator defaults marked there). Added while merging them
(coordinator choices, the user may overrule):

1. **The MGPROF boots are the per-chunk baseline.** Nothing under `mods/`
   changed between their base (`1ef11b5e`) and the round's start, so MEAS
   only adds the fresh-world first-start baseline.
2. **Each lane owns the design and technical docs its rules change** (as in
   Round 48); lane D only writes CHANGELOG, STATUS, README, BACKLOG and the
   plan's completion.
3. **The mapgen plan's D package** (§4.9) is split accordingly: ORE writes the
   resource and cave-plant sections of `world_zones.md`; PROT the protection
   depth in `world.md`, `world_zones.md`, `combat_stats.md`, `farming.md` and
   the preparation bottom in `world_preparation.md`; SKIP the skipped chunks
   in `world_preparation.md`; lane D the BACKLOG WP48 update and the
   pointer from `tools/wp40/profile` to `tools/mgprof/`.

## 3. Shared conventions

- Every number a lane changes is changed in the game, the Python ledger
  (`tools/r28_design/r28common.py` and what reads it), the tests that pin it
  and the design docs, in the same lane (gameplay draft §3).
- Ore and gem frequencies are rough targets (mapgen ruling 2): tests that pin
  exact ore or gem counts become rough ranges; no new exact pins.
- World-generation lanes report the mgprof stage numbers of the chunks they
  change (comparisons, never targets).

## 4. Lanes (goals; the briefs add file facts)

- **ORE, JIT, PROT, SKIP, HASH, CACHE, V7, V7A, MEAS, MEAS2:** as in the
  mapgen plan §4.1–4.8; PROT covers §4.4 both parts.
- **UI, INV, MOB, NAV, NAV2, VIS:** as in the gameplay draft §4; NAV is phase
  1, NAV2 phase 2.
- **D:** CHANGELOG 0.49.0 (map reset), STATUS, README (first-start note if
  the preparation time changes noticeably), BACKLOG (WP48: what this round
  did, what remains: several emerge threads after Luanti #9357), the plan's
  completion with the merged GUI checklist and the numbers worth keeping
  (the MEAS/MEAS2 table).

## 5. Rules

- The partial plans' rules hold for their lanes (mapgen plan §6, gameplay
  draft §5).
- **Clients and budgets:** stock clients only; plain Lua 5.1 compatible;
  the web build is a target; no new globalstep and no new per-tick work over
  all players or objects; numbers are comparisons, never targets; a lane
  that gets noticeably slower or more complex reports to the coordinator,
  who asks the user.
- **Engine runs (world generation and measurement):** few runs of at most
  about 5 minutes, only chosen chunks or a small region, never the whole
  world; more goes to the user first. Through the shared queue with
  `LC_ALL=C`; never the user's Luanti folder.
- **Release mode:** 0.49.0 is a map reset; no compatibility code for the old
  map. Character state stays readable without a step.
- **Reviews:** every code lane gets an independent Opus review; fix deltas
  with game logic are reviewed again; text, colour and display deltas the
  coordinator checks itself; measurement lanes (MEAS, MEAS2, V7, NAV) are
  checked by the coordinator against their evidence. Theoretical concerns
  become backlog notes.
- **Push** only on the user's word.

## 6. Verification

Per lane the gates of the [round workflow](../process/round-workflow.md#3-gates).

- **Fixtures (every brief):** own fixture plus the fixtures that test the
  changed behaviour during development; the full run once before the
  report. Measurement lanes without a change under `mods/` run none.
- **Seed fleet:** `quick` before merging each world-generation lane (ORE,
  JIT, PROT, SKIP, HASH, CACHE, V7A); `full` once at the round end. JIT and
  CACHE must be byte-identical; the others change output by design. The
  fleet's fake VoxelManip has no native ores or decorations: MEAS2's engine
  count checks native placement.
- **Upgrade:** `check_upgrade.py` after the version bump (0.49.0, map reset)
  and at the round end; `check_fresh_server.py`.
- **Data:** `validate.py --game` after MOB (mob data); `income.py --check`
  after MOB (XP/loot) and UI (postage); `web_data/export.lua --check` after
  VIS (textures) and at the round end.
- **Smoke boot** of main at the round end.

**GUI checklist** (desktop and web, a new world after the map reset):
1. Mining at several depths finds ores and gems roughly as often as before;
   gems mostly single nodes or pairs, coal and ores in clumps.
2. Mountains built by the fill still hold ores.
3. Cave plants grow on cave floors in their depth bands.
4. A town's surface cannot be broken through; digging beside and under a
   town works below the new floor; no name tag under the town shows from
   inside it.
5. Walking, riding and flying over prepared land trigger no visible
   generation; going deep underground generates quickly.
6. Mail: drag a stack into a slot after typing the text, Send once: the
   letter goes, the text is not lost, the line names the postage paid.
7. Merchant Sell tab: hover an item; a quality item shows its quality.
8. Claim Stone: drag it into each bag, sort the inventory (it stays in the
   bag), try a chest and the mail slots (refused). Steward with a carried
   stone, a stone in a bag, a placed stone, below level 20: no button and
   the reason; with no stone: the button.
9. New character: apples in hotbar 7, torches in 8; a granted skill on a
   full hotbar takes a slot, the item moves into the inventory.
10. Target frame: a mob 9 below is green-ish with XP, 10 below gray "no XP".
11. A rare: visibly tougher than a normal, weaker than an elite.
12. Chase: zombies and rats reach the player behind bushes and trees; an
    archer walks around a wall to shoot.
13. Third-person view and another player's view: a held dirt block is
    smaller, a pickaxe unchanged; first person unchanged.
14. Wild onion and field onion half in the ground.

## 7. Orchestration notes

- **Start state:** main at the commit that adds this plan (0.48.1 plus the
  MGPROF tools and both partial plans; not pushed). Lanes branch from main
  at the round start; worktrees `.claude/worktrees/r49-<lane>`; briefs,
  reports and the handover log in `~/projects/grudgelands-orchestration/r49/`.
  The MGPROF lane's notes stay in `~/projects/grudgelands-orchestration/mgprof/`.
- **Process budget:** at most 8 Lua processes workstation-wide through the
  shared queue (`r45/lua_run.sh`), at most two measuring engine runs at once
  (`r45/engine_run.sh`). Wave 1 has four lanes with engine runs (ORE, PROT,
  MEAS, NAV); waiting in the queue is normal.
- **Shared files:**
  - `docs/design/combat_stats.md`: MOB (XP, rare tier), NAV2 (chase), PROT
    (protection floor): different sections; later merges take main first.
  - `docs/design/world_preparation.md`: PROT (bottom rule), SKIP (skipped
    chunks).
  - `r6_settlement.lua`: ORE (P8), JIT (R5 adapter call site), HASH (P9);
    `r7_p9g.lua`: HASH, CACHE; `zones.lua`: JIT, CACHE. Wave 2 lanes start
    from main after their predecessors merged.
  - `CHANGELOG.md`, `docs/STATUS.md`: coordinator after merges, lane D.
- **Merge order:** wave 1 in any order (main merged into a lane before its
  review when a shared file moved); wave 2 per the table; NAV2 last among
  the gameplay lanes; V7A only on the user's word; MEAS2 after the last
  world-generation merge; D last.
- **Decided during the round:** the protection depth value (PROT measures);
  the column cache size (CACHE's probe; up to about +50–60 MB accepted); a
  v7 flag (the user, after V7); NAV2's scope (the user, when the diagnosis
  changes a Round 42 ruling).
- **Version:** the coordinator bumps `game.conf` to 0.49.0 and declares the
  map reset in `tools/web_data/upgrade.json` at the start of wave 1.
