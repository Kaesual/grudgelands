# Audit October 2026: code and documentation

A read-only audit of Grudgelands at commit `0f169898` (2026-10-05, Round 36
pushed). It has two parts:

1. **Code:** a performance and bug review of all game Lua under `mods/`
   (about 177k lines). It looks for bugs, server hot paths, duplication,
   legacy decisions, and traps for agents.
2. **Documentation:** checks whether the README, the agent context and the
   design documents match the code today.

No code or documentation was changed. The findings here are the input for
later fix rounds.

## How to read this

- **New to the codebase?** Read [code/00-summary.md](code/00-summary.md) and
  [docs/00-summary.md](docs/00-summary.md) first. Each has the main findings,
  findings that several lanes reported for the same defect, proposed fix
  packages, and a sorted index of every finding.
- **Working on one area?** Read the lane document for that area. Each code
  lane document has:
  - a summary of how the area works;
  - every finding with evidence (`path:line`), **Impact** and **Better**
    (a recommendation with effort S/M/L);
  - a **hot-path inventory** (what runs per step, per chunk or per event, and
    what each costs);
  - a list of bug-prone areas;
  - open questions for Jan.
- **Planning a fix?** Check the finding's `Verification (phase 2)` line first.
  It says whether an independent second pass confirmed the claim, lowered its
  severity, or refuted part of it.

## Documents

| Code lane | Area |
|---|---|
| [code/00-summary.md](code/00-summary.md) | **Summary, fix packages, full index** |
| [code/01-mapgen-terrain.md](code/01-mapgen-terrain.md) | wp40 on_generated pipeline, terrain, decoration, ores, caves, emerge memory |
| [code/02-mapgen-settlements.md](code/02-mapgen-settlements.md) | Towns, capitals, POIs, roads, writers, placement |
| [code/03-mapgen-wp13.md](code/03-mapgen-wp13.md) | wp13 building library, what loads where, the wp13/wp40 merge plan |
| [code/04-mobs-runtime.md](code/04-mobs-runtime.md) | mobs_redo fork, AI loop, threat, spawning, staticdata and lifecycle |
| [code/05-mobs-content.md](code/05-mobs-content.md) | Mob definitions, rares, bosses, dragons, traders, projectiles |
| [code/06-core-hud-ambience.md](code/06-core-hud-ambience.md) | grug_core, globalsteps, HUD, ambience, visuals, minimap |
| [code/07-combat-progression.md](code/07-combat-progression.md) | Abilities, damage pipeline, classes, XP, PvP, parties, factions |
| [code/08-player-systems.md](code/08-player-systems.md) | Jobs and workspaces, quests, housing, home, mounts, inventory, money |
| [code/09-items.md](code/09-items.md) | Items, crafting, farming, durability, tooltips, stations |
| [code/10-cross-cutting.md](code/10-cross-cutting.md) | Repo-wide inventories (globalsteps, ABMs, callbacks, storage, overrides), dependency graph, vendored code, tools, agent pitfalls |

| Docs lane | Documents checked |
|---|---|
| [docs/00-summary.md](docs/00-summary.md) | **Summary, packages, decisions for Jan, full index** |
| [docs/01-readme-player.md](docs/01-readme-player.md) | README.md from a player's point of view; proposed outline |
| [docs/02-agent-context.md](docs/02-agent-context.md) | AGENTS, CLAUDE, ROADMAP, BACKLOG, STATUS, process and technical docs; single-owner proposal |
| [docs/03-design-world.md](docs/03-design-world.md) | World design docs vs mapgen and mob code; 38-zone spawn table |
| [docs/04-design-player.md](docs/04-design-player.md) | Player-system design docs vs code; ability, talent, XP and quest comparisons |
| [docs/05-design-items.md](docs/05-design-items.md) | Item, crafting, profession and economy docs vs code; ownership proposal |

## Results in one screen

**Code: 160 findings.** 8 High, 53 Medium, 99 Low, no Critical. Nothing found
crashes the server in normal play, loses player data or damages towns. Some
findings were reported by more than one lane; counted once, there are **five
High defects**:

- **Every hit runs the equipment-change fan-out.** Each hit triggers a full
  equipment-changed pass: tooltip rebuilds, stats, abilities, visuals, and the
  Character page. Estimated 0.25–0.5 ms of Lua per hit, scaling with
  players × hits.
- **A food or Vigor buff expiring dismounts the rider.** On a flying mount, the
  rider falls.
- **Every hit retargets the mob to the hitter.** This overrides threat and
  taunt.
- **The mob melee swing animation is overwritten** one step after each punch.
- **The rare watchdog spawns duplicate named rares** on a long-running server.

The cheapest real win is in mapgen: a dead decoration halo (MGT-02). Turning it
off gives byte-identical output and saves 6–25 % of planner time per chunk
column.

**Docs: 136 mismatches.** 4 High, 53 Medium, 79 Low. The numbers are
excellent: prices, talents, XP, quests and zone bands all match the code. What
drifts is status and prose:

- Round 36 is called "not pushed" in about ten places.
- AGENTS.md describes the work-package-per-branch workflow that ended on
  2026-09-20.
- Capital zones are called hostile-free, but have had hostile spawn recipes
  since Round 28.
- The README's install steps don't warn that changing mapgen options breaks
  the world.
- `docs/maintenance/findings.md` lists four items as open that are fixed in
  code.

## Method

Fifteen review lanes ran in parallel: ten for code, five for docs. Each wrote
one document. A verification pass then tried to refute every High finding, the
bug-type Medium findings, and the documentation Highs, using the code and the
Luanti engine source in `reference_projects/luanti`. Of the code High and
Medium findings:

- 48 were confirmed;
- 7 were partly confirmed: a sub-claim was refuted, or a cost was overstated;
- none were refuted outright;
- 5 Medium findings (PLY-05 … PLY-09) were not verified.

Severities in all tables are the values after verification.

No Luanti engine ran. Costs come from LuaJIT runs of the real Lua files in
isolation and from reading the engine source. They are comparisons, not
targets. Where a cost is an estimate rather than a measurement, the finding
says so.

**Severity scale.**

| Severity | Meaning |
|---|---|
| Critical | Crash, data loss, world damage, or server-wide stall in normal play |
| High | Player-visible bug in normal play, or a hot path that scales badly |
| Medium | Bug in less common situations, notable avoidable cost, or duplication that invites bugs |
| Low | Cleanup or a minor cost |
| Noted | Theoretical only, listed without action |

For docs, High means the document leads a player or agent into a wrong action.

## Next steps (handover)

Agreed with Jan on 2026-10-05; a fresh session picks up from here.

1. Run the owed `seed_fleet full` after Round 36 W3/RD (AGENTS.md seed-fleet
   rule). It also serves as the baseline for the MGT-02 halo fix.
2. Settle the remaining decisions listed in
   [docs/00-summary.md](docs/00-summary.md#decisions-for-jan) and the open
   questions in the lane documents that block a fix. In particular: the mob
   retaliation policy (MOB-01), grass and moss on protected ground (X-02), and
   tree clipping at chunk borders (MGT-03).
3. Plan Round 37 as a large fix round:
   - Code packages P1–P5, plus MGT-02 and P7 in one mapgen lane with the seed
     fleet.
   - Documentation packages A–F in parallel lanes.
   - Keep P8 (the wp13/wp40 merge, the mobs fork) for a later round of its
     own.
   - P9 (sounds) waits for the open sound question.
4. Commit this folder as the round's first commit. Lanes work in git
   worktrees and cannot see untracked files.

Each fix lane re-checks its findings against the code as its first step.
PLY-05 … PLY-09 and most Low findings were not independently verified.
Four points need a runtime check inside their lane:
- MOB-04: a GUI look at the swing animation.
- MOB-06: a headless restart test.
- CORE-02: how often the water loop fires in a real world.
- The equipment fan-out: its cost measured in the engine.

**Status (2026-10-05, planning session):**

1. `seed_fleet full` on `0f169898`: 303 of 303 seeds build, 0 failed.
2. The user settled the blocking decisions; they are in the
   [Round 37 plan](../planning/round37-plan.md#2-user-rulings-2026-10-05)
   §2, with the coordinator's defaults in §2.4. The sound question was
   answered with a listening page this round, so P9 is lane SN.
3. Round 37 is planned in [round37-plan.md](../planning/round37-plan.md).
4. This folder was committed as Round 37's first commit.
