# Round 49 — Mapgen performance (native first) and gameplay polish

Coordinator: Claude (Opus 5.5), drafted 2026-10-15 from two partial plans the
user accepted the same day. Status: **complete on main** (2026-10-16, not
pushed; GUI test open; [completion](#completion-2026-10-16)).

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
- **Version:** done by the coordinator before the worktrees, so every lane
  starts from it: `game.conf` 0.49.0, 0.49.0 in `map_reset` of
  `tools/web_data/upgrade.json`, the CHANGELOG placeholder.

## Completion (2026-10-16)

Every planned lane is merged on main; this lane D (this section and the
status owners) follows on main `aea065a8` (MEAS2, merged last). **0.49.0
is a map reset, no migration step:** world generation changed (native
ores, gems and cave plants, the fill-ore pass, the integer placement
hash, the v7 flag `nomountains`, the protection depth), character state
reads as it is. The game forces `mgv7_spflags` over the world's
`map_meta.txt` (V7A's fix), so the production world needs only the map
reset. **Push:** not pushed; origin/main stays at `1ef11b5e` (0.48.1)
until the user's word.

### Lanes

Main's first-parent merges from `f8f2d134` (the version bump: `game.conf`
0.49.0, 0.49.0 in `map_reset`, the CHANGELOG placeholder), in order:

| Lane | Merge (follow-ups) | What | Review |
|---|---|---|---|
| MEAS | `f020db33` | the fresh-world first-start baseline (one boot, `summarize.py --first-start`) | coordinator check against the evidence |
| MOB | `bdc9ea31` | kill XP −10 % per level below, gray at 10 below; the rare tier (HP ×2.5, damage ×1.4, XP ×2, armor 90); ledger, target frame, Help | MERGE (two stale texts fixed by the coordinator, `f6589863`) |
| UI | `ecb3d317` | postage charged at Send with the rule shown; item tooltips on the Sell rows; `tools/r49_ui` capture | MERGE (a usage line fixed by the coordinator) |
| NAV | `da74476e` | phase 1: the short-range chase probe and its diagnosis (tools only) | coordinator check against the evidence |
| VIS | `b3a47caa` | node items at 70 % in the third-person hand; the onion's stages 3 and 4 half buried (`install_picks`) | MERGE |
| INV | `c22d0d95` | the Claim Stone in `main` and every bag; the Steward's button by `can_receive_stone`; apples on hotbar 7, torches on 8; a granted skill makes room | MERGE (a stale comment fixed by the coordinator) |
| ORE | `69c72903` | 84 native scatter rows and two cave decorations from the density table; P8 replaced by a flat fill-ore pass; no ore exclusion under towns or deep water | MERGE (three stale comments fixed by the coordinator, `44ecb46d`) |
| PROT | `dcc621df` | the protection depth 80 under towns; the preparation bottom reaches the fill floor −37 | MERGE (the engine probe's stale depth fixed by the coordinator) |
| NAV2 | `6fe88bd4` | path repair, padding escalation 6/12/16 per stuck episode, ground ranged mobs walking to regain sight | MERGE AFTER FIXES (Medium: the elf, undead and troll kings drifted off their seat on regaining sight), fixed (`4c3a99d9`, only mobs with a ranged phase); delta MERGE |
| SKIP | `1b965ec4` | no Lua for chunks below every writer (`deep_skip`); the air test reads the owner first; `ore_floor_at` removed | MERGE (the verify script's check fixed by the coordinator, `3f18a084`) |
| JIT | `e43c886b` | one compilable R5 adapter pass with a classification memo, the replay folded in; the zones lookup without `unpack` and with integer keys; output byte-identical | MERGE |
| V7 | `c169785d` | `nomountains` and `noridges` measured one at a time (tools and evidence only) | coordinator check against the evidence |
| CACHE | `5c32c47e` | the P9G result per column; the mapgen column cache 3× (196,608); output byte-identical | MERGE |
| HASH | `62123545` | an integer placement hash instead of SHA-256 for R6 candidates, P9G and P9 | MERGE, then a coordinator-ordered fix round (the first mix was periodic and point-mirrored), fixed (`cf039f44`, a cube mix fed coordinate by coordinate); delta MERGE |
| V7A | `ad9c4bfc` (`495e22a6`) | the v7 flag `nomountains` adopted; then forced with `override_meta`; the AGENTS and round-workflow rule on forced scalars | MERGE AFTER FIXES (High: the old flags in `map_meta.txt` would have stopped the production world after the reset), fixed by the user's option (a) (`e3471244`); delta MERGE |
| P8 | `2c5c0191` | follow-up: the fill-ore cube decisions kept per chunk (output byte-identical) | MERGE |
| MEAS2 | `aea065a8` | before/after: the corpus, chunks per second, the native ore count, the first start | coordinator check (`--first-start` and `--census` reproduce) |
| D | this section | CHANGELOG, status owners, BACKLOG (WP48, carry-overs), the tools index, the partial plans' status lines, the Round 42 note | — |

Main has 197 portable fixtures (8 new: `r49_vis`, `r49_inv`, `r49_ore`,
`r49_prot`, `r49_skip`, `r49_jit`, `r49_hash`, `r49_cache`; among the
extended ones `r48_mail`, `r48_sell`, `r46_xp`, `r42_nv1`, `r24_fill`,
`r24_protection_depth`); `mods/` +1,716 −1,353 lines in 47 files, no new
Lua file.

### Decisions during the round

The user's decisions of 2026-10-15, one line each (the coordinator log is
outside the repository):

1. **NAV's questions:** path repair yes (changes Round 42 ruling 19);
   padding escalation with the cap 16 yes (changes the value of ruling
   18); the giant rat keeps its 1.28 width (no 0.98 box); INV's question:
   no feed line naming the item a skill moved.
2. **The protection depth 80** (PROT's measurement: 30 + 34 + 16).
3. **The v7 flags:** adopt `nomountains`, not `noridges` (V7A).
4. **V7A's High:** option (a), the game forces the flag over
   `map_meta.txt` with `override_meta` and 0.49.0 stays a map reset
   (instead of a new server).
5. **The P8 follow-up lane** after HASH's slower fill pass.
6. **The kings' volley** without a line-of-sight check goes to the
   backlog (a balance question).
7. **A standing merge OK** for this round after a passed review and the
   sync.

The coordinator decided, one line each:

- **The version bump before the worktrees,** so every lane started from
  0.49.0 and the map reset was declared from the start.
- **The column cache at 3×** (+41 MiB measured by the lane, +31 MiB by the
  review) instead of 4× (+62 MiB), inside the user's +50–60 MB.
- **HASH's fix round instead of a backlog note:** the reviewer's periodic
  and mirrored streams would have shown as patterns in the world.
- **NAV2's questions 1–3 at their defaults:** escalation also on fixed
  walks, repair also on settlement routes, "near the next" as built.
- **Small text findings** of the reviews (stale comments, a usage line, a
  probe constant, a setter message) fixed by the coordinator before the
  merge; `ore_floor_at`'s removal moved from ORE to SKIP.

### Deviations from the plan

- **PROT:** the depth is 80, not "about 50": the deepest place a player
  stands in a town is 34 below its placement height (a river bed inside a
  capital) and the city edge's reach needs room; the formula's minimum was
  75. The preparation bottom changed no tile on eight seeds (kept as a
  guarantee).
- **JIT** also skips re-resolving liquid neighbours already validated
  (about 35 ms in A_S1; beyond the brief, accepted by the review).
- **SKIP** did not cap the T1 rows' `y_max` (no exact bound of the kept
  ground exists); the air check's 12 ms were the reach ring, not the
  heightmap.
- **HASH** needed a fix round, and its cube mix made the fill-ore pass
  26 % slower; the **P8 follow-up** (not in the plan) took it to 541 ms
  per corpus boot (796 with the cube mix, 633 before HASH).
- **V7A** needed the forced flag and a rule change: a validated
  world-creation scalar the game forces over `map_meta.txt` is a map
  reset (AGENTS.md, round workflow, upgrade contract §1).
- **NAV2** limits the walk for sight to mobs with a ranged phase; the
  kings keep their old branch.
- **VIS:** the onion generator did not write the shipped files; the lane
  added `install_picks`.
- **MEAS2** refreshed `tools/mgprof/stages.patch` (it applied only with
  fuzz after CACHE and P8) and counts cave floors only inside a plant's
  range.

### Numbers worth keeping

Comparisons on one machine, not targets; details in the
[research doc](../research/mapgen-chunk-profile-2026-10.md#round-49-beforeafter-lane-meas2).
**Before** is the MGPROF corpus (six stage boots on `1ef11b5e`) and MEAS's
first start; **after** is MEAS2 on `2c5c0191` (two stage boots, one
first start; a seed fleet ran beside them).

- **The corpus** (seed 12345, callback ms per chunk, stage boots):

  | ms | warm-up | A_S1 | A_S2 | A_B | A_U1 | A_U3 | A_U6 | B_U6 | B_U1 | B_B |
  |---|---|---|---|---|---|---|---|---|---|---|
  | callback before | 463 | 648 | 229 | 382 | 393 | 426 | 463 | 735 | 379 | 384 |
  | callback after | 150 | 304 | 88 | 54 | 0 | 0 | 0 | 0 | 0 | 139 |
  | P8 resources | 294 → 0 | 237 → 12 | 71 → 1 | 325 → 1 | 348 → 0 | 381 → 0 | 417 → 0 | 463 → 0 | 330 → 0 | 331 → 0 |
  | `makeChunk` | 21 → 15 | 29 → 23 | 24 → 18 | 20 → 15 | 21 → 15 | 29 → 22 | 30 → 23 | 30 → 23 | 21 → 14 | 21 → 13 |
  | request-to-done wall | 561 → 165 | 679 → 325 | 254 → 108 | 403 → 78 | 410 → 18 | 452 → 29 | 491 → 27 | 742 → 25 | 403 → 18 | 431 → 150 |

  Wholly underground chunks are `deep_skip` (0.05 ms of Lua). B_B is now
  column B's first chunk with Lua work and pays the cold planner (about
  97 ms), then changes nothing. The cold planner (93–102 ms) is the
  largest surface cost left; A_S1 spreads 275–333 ms between boots
  (before 530–831).
- **Chunks per second of one emerge thread:** surface, first chunk of a
  column 1.5 → 3.1; surface, warm 3.9 → 9.3; fill floor −112..−33 cold
  1.8 → 6.4, warm 2.4 → 12.9; wholly underground 1.3 (cold) and 2.3
  (warm) → 40.0 (writer skipped); air above the surface 38.1 (after only).
- **Native ores and gems** (29 chunks; host rock against the density
  table): T1 4.94 % (expected 5.07), T2 3.84 (3.93), T3 3.42 (3.47), T4
  3.77 (3.92), T5 3.68 (3.75), T6 3.38 (3.47): 0.96–0.99 of the table per
  band, 0.90–1.02 per resource. Gems 59 % singles and 31 % pairs (ORE's
  fixture). Cave Cap 8 plants on 14,013 in-range floors (1 / 1,752,
  target 1 / 1,536), Ember Moss 11 on 31,781 (1 / 2,889, target
  1 / 2,048), about one standard deviation from the targets.
- **The first start** (starts-only preparation, 84 surface chunks):

  | | before (MEAS) | after (MEAS2) |
  |---|---|---|
  | preparation complete, s from launch | 79 | **66** |
  | preparation wall from the first step | 36.7 s | 22.1 s |
  | preparation Lua (sum / mean) | 29,866 / 356 ms | 15,317 / 182 ms |
  | engine `makeChunk` mean | 30 ms | 22 ms |
  | chunks per second | 2.29 | 3.80 |
  | before the first step: layouts / map render / spawn regions | 23.1 / 9.2 / 8.1 s | 24.1 / 9.5 / 8.3 s |

- **Per lane:** JIT S1 594 → 499 ms (R5 resolve and validate 67 → 43,
  replay 12.6 → 0); HASH R6 candidates A_S1 106 → 29 ms, SHA-256 calls per
  chunk 115 k → 0, densities 1.00–1.03 of before (the cube mix); CACHE
  P9G on a column's second chunk 61 → 0.1 ms, the planner's later-chunk
  column cost with
  two players 600 apart 1,661 → 942 ms, memory +31–41 MiB; V7
  `nomountains` deep `makeChunk` 21–30 → 14–23 ms, deep chunks per second
  +33 %; SKIP A_S2's air check 10.8 → 0.2 ms; P8 541 ms per corpus boot
  (633 before HASH).
- **PROT:** the deepest place a player stands in a town 34 below its
  placement height (Lethariel's river bed, seed 1106439485595573225; 78 of
  100 seeds at most 20; 48 further seeds at most 35); depth 80 = 30 (tag
  range) + 34 + 16.
- **NAV2** (seed 12345, reached without give-up, before → after): archer
  main scenes 2 → 17 of 17, zombie natural 21 → 26 of 28, rat natural
  20 → 27 of 28; no shot without sight; largest search 426–430 µs.
- **MOB** (L30, kill XP by level difference −10 / −9 / −3 / 0 / +3 / +6):
  0 / 17 / 122 / 175 / 227 / 262; a rare 0 / 35 / 245 / 350 / 455 / 525;
  a rare at L30 1,910 HP (normal 764, elite 2,292).
- **VIS:** a held dirt block's wield scale 0.32 → 0.224, a pickaxe 0.32.
- **Seed fleets:** `quick` 100/100 for ORE + PROT (11 min 36 s), SKIP,
  HASH (twice), V7A (7 min 39 s); JIT and CACHE byte-identical over the
  quick seeds' 502 chunks (and 202 with moved ground).

### Classification

- **Map reset:** ORE (native ores, gems and cave plants; the fill-ore
  pass), PROT (the protection depth and the preparation bottom), HASH (the
  placement draws), V7A (`nomountains`, forced over `map_meta.txt`).
- **Compatible:** JIT, CACHE, SKIP and P8 (output byte-identical), UI,
  INV, MOB, NAV2, VIS; MEAS, NAV, V7 and MEAS2 tools only. Saved state
  read differently: none (the Claim Stone in `main` stays valid, the
  starter kit's `META_KIT` is unchanged so existing characters get no
  second kit, a rare's tier and level persist and its stats follow the
  tier at activation; the preparation plan in mod storage is not re-read
  after a map reset).
- **The declaration:**
  `{"schema": 2, "version": "0.49.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0"]}`.

### Open notes

The reviews' and reports' backlog notes are in the
[BACKLOG](../../BACKLOG.md#round-49-carry-overs); what remains of WP48
(several emerge threads after Luanti #9357, the cold planner, the
first-start pre-step) is in
[WP48](../../BACKLOG.md#wp48--mapgen-writer-performance-and-parallel-emerge).

### GUI checklist (Round 49)

Desktop and the web build, on a new world after the map reset; an
existing 0.48 character for the update items. Built from §6 with every
lane's and review's GUI items. Points marked **(decide)** are for the
user's judgement.

**The update:**

1. A 0.48 world taken to 0.49.0 with the map reset starts without a
   mapgen flag error; Help → About shows 0.49.0; the characters keep
   level, gear, bags, money and quests.
2. The first start is ready in about a minute (the progress window).

**World generation:**

3. Mining at several depths finds ores and gems roughly as often as
   before; gems mostly single nodes or pairs, coal and ores in clumps.
4. Mountains built by the fill still hold ores.
5. Cave plants grow on cave floors in their depth bands (Cave Cap
   −500..−100, Ember Moss −1000..−700), also under towns.
6. Town plinths and foundations can show ore that cannot be dug (the
   protected ground) **(decide)**.
7. A town's surface cannot be broken through; digging beside and under a
   town works from 80 below the town's height; no name tag under the town
   shows from inside it, also from a capital's lake or river bed.
8. Walking, riding and flying over prepared land trigger no visible
   generation; going deep underground generates almost at once.
9. A second player far away: generation for the first player is not
   noticeably slower.
10. The relief looks as before; fewer caves open in the top tens of
    blocks under hills and highlands.
11. Forests and meadows as dense as before; tree shapes and rotations
    vary; no rows, grids or diagonals of trees or plants.

**Mail and selling:**

12. Mail: type the text, drag a stack into a slot, Send once: the letter
    goes, the text is not lost, the line names the postage paid ("Postage
    paid: 35c" for one stack); the Write tab shows the rule and "Paid when
    you send.".
13. Merchant Sell tab: hover an item; a quality item shows its quality,
    stats and enchants.

**Claim Stone, starter kit and skills:**

14. Claim Stone: drag it into each bag, sort the inventory (it stays in
    the bag), try a chest, the mail slots, the crafting slots and the
    potion belt (refused).
15. Housing Steward with a carried stone, a stone in a bag, a placed
    stone, below level 20: no button and the reason; with no stone: the
    button; with a full inventory: the button, and the click refuses in
    red.
16. New character: apples on hotbar 7, torches on 8; a skill a talent
    unlocks on a full hotbar takes the rightmost slot that holds no
    skill, the item moves into the inventory (no feed line names it).

**XP and the rare tier:**

17. Target frame: a mob 9 below is green-ish with XP, 10 below gray "(no
    XP)"; a kill 3 below pays 70 %; Help → Levels and zones says so.
18. A rare: the same size and tint, visibly tougher than a normal, weaker
    than an elite, the "!!" wind-up as before.

**Creatures:**

19. Chase: zombies reach you behind bushes, also one or two blocks
    higher; giant rats go round trunks.
20. An archer behind a bush or trunk walks round until it sees you, then
    stops and shoots; it never shoots into cover. An ember wisp as before.
21. An elf, undead or troll king that loses sight of you does not drift
    off; after the fight he returns to his seat. His volley signature
    still fires without sight (unchanged, backlog) **(decide)**.

**Looks:**

22. Third-person view (F7) and another player's view: a held dirt block
    is smaller, a pickaxe, a torch and a sapling unchanged; first person
    unchanged; an NPC holding a block shows it smaller.
23. The wild onion and the field onion (stages 3 and 4) sit half in the
    ground; stage 3 shows about two thirds of the bulb **(decide)**; the
    Wild Onion node's inventory image (creative or admin only) is the
    half-buried tile **(decide)**.

### Round-end gates

**Round-end gates** (coordinator, 2026-10-16): on main `2c5c0191` (every
world-generation lane merged; later merges are tools and docs only) the
full fixtures 197/197 and the full seed fleet 304/304 (33 min 8 s); on
main `aea065a8` `check_upgrade.py` (0.49.0 against origin/main),
`check_fresh_server.py`, `validate.py --game` (0 errors),
`income.py --check`, `web_data/export.lua --check`,
`r33_ds/build_doc.py --check`, `r48_artp/generate.py --check` and a smoke
boot (120 s) PASS, no server left.
Lane D's own checks on its branch: `tools/r37_dc` and `check_upgrade.py`
(0.49.0 against origin/main `1ef11b5e`) PASS.
