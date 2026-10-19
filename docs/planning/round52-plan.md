# Round 52 — Ambience and the class rework foundation

Coordinator: Claude (Opus 5.5), drafted 2026-10-19 with the user while
Round 51 runs, revised the same day after an independent review
(`r52/plan-review.md`: 1 High, 9 Medium, 14 Low, all addressed). Status:
**started** 2026-10-19 (the user's "go"; main after R51 and its follow-up,
0.51.0 pushed). D5's height is confirmed as 5.5 units (part B §1).

The round joins two partial plans. **Their rulings stay in those plans**
and are cited here:

- **Part A:** the [ambience plan](round52-ambience-plan.md); rulings in its
  §1, settled questions in its §6.
- **Part B:** the [class foundation plan](round52-class-plan.md); rulings
  C1–C13 and coordinator decisions D1–D9 in its §1.

This file owns the lanes, waves, dependencies, file ownership, gates and the
joint lane D. Where it and a partial plan disagree, the partial plan's
ruling wins, and the coordinator fixes this file.

**In short:**
- **Ambience:**
  - beds follow the biome group;
  - surface, cave and wind loops follow the height relative to the terrain;
  - real caves are told apart from dug tunnels;
  - sparse animal calls;
  - the "underground" sky becomes relative to the terrain.
- **Class foundation:**
  - per-class kit and talent files;
  - every combat building block of the rework, tested but not yet used by
    a shipped class;
  - Mend as a status effect;
  - a new talent engine and Talents page with one tab per tree, which
    admins can preview;
  - a horizontally scrolling skill list;
  - the rework's art, drawn and picked;
  - an element overlay on the first-person weapon.
- **Release 0.52.0, compatible:** no map reset, no migration. Players keep
  today's classes and trees. Round K brings the new kits and the automatic
  talent reset.

Routing (the user's current setting): Claude coordinates, Opus implements
and reviews, Astra draws.

## 1. Lanes and waves

| Lane | Part | Wave | Implementer / reviewer | Depends on |
|---|---|---|---|---|
| **SND** | A | 1 | Opus / the user's listening page | the picks (A §4) |
| **AMB** | A | 1; file step after the user approves SND | Opus / Opus | SND for the file step |
| **SPLIT** | B | 1 | Opus / Opus | — |
| **ARTA** | B | 1 | Astra / the user's pick pages | node list, D5 geometry |
| **ARTB** | B | 1, may run into wave 3 | Astra / the user's pick pages | node list |
| **CORE-A** | B | 2 | Opus / Opus | SPLIT merged |
| **CORE-B** | B | 2 | Opus / Opus | SPLIT merged |
| **GRAPH** | B | 2; art step after the picks | Opus / Opus | SPLIT merged |
| **WFX** | B | 3 | Opus / Opus | CORE-A merged, ARTA's strip picks |
| **D** | A+B | last | Opus / Opus (docs review against the code) | every lane merged |

- Every reviewer works in a fresh context that wrote none of the change.
- **Picks:** the coordinator builds the private German pick pages with stored
  ratings and reads them back. Nothing ships unpicked: sounds by the sound
  gate, art by D7.
- **Data steps:** AMB's file step and GRAPH's art step are data deltas with
  their own short review.
- The coordinator checks only D's status, version and changelog lines
  itself.

**Merge order:**
1. SPLIT first.
2. AMB code whenever it is reviewed; it shares no file with part B.
3. CORE-A, CORE-B and GRAPH in whichever order they finish. Main is merged
   into each later one before its review.
4. AMB's file step and GRAPH's art step as the picks arrive.
5. WFX.
6. D.

## 2. Decided by the coordinator for the frame (the user may overrule)

1. **Version 0.52.0, compatible**, for both parts (A §3.4 points here).
2. **Engine runs** stay under the two-run cap (`engine_run.sh`), each a few
   minutes:
   - smoke boots;
   - AMB's cave calibration;
   - CORE-A's PvE bench and the `r31_pvp` micro run;
   - CORE-B's probe.

   No seed fleet: nothing in world generation changes.
3. **Astra** runs ARTA and ARTB through `run_astra.sh` (effort `xhigh`).
   ARTA comes first in its queue; ARTB's icons for new skills are only
   needed in round K.
4. **CORE is split by files** into CORE-A and CORE-B, so WFX waits only for
   CORE-A and the largest lane halves.

## 3. File ownership

| Files | Owner |
|---|---|
| `grug_ambience/*`, `grug_core/atmosphere_zones.lua`, `tools/r34_s2/approved.txt`, the ambience fixtures (A §3.2 step 10) | AMB |
| `tools/r52_snd/` (staged audio) | SND |
| `grug_abilities/kits*.lua`, `grug_classes/talents*.lua`, the new window-runtime file, the fixtures of facts §1.6 (not the Python files), `tools/r52_split/` | SPLIT (wave 1) |
| after SPLIT: `grug_abilities/init.lua`, `input.lua`, `strike_delay.lua`, `cooldown_hud.lua`, `kits_priest.lua` (Mend), `tools/r52_bench/`, the fixtures `r50_hotbar`, r28_a4, r32_f2, r36_f, r36_f2, r41_sc, r451_sc, r491_drop | CORE-A |
| after SPLIT: a new `grug_core` area module and its dofile in `grug_core/init.lua`, the window-runtime file, `grug_core/particle_effects.lua`, `grug_core/status_icons.lua`, `tools/r52_core/` (fixtures and probe), `tools/r26_status_icons` | CORE-B |
| after SPLIT: `grug_classes/talents.lua` (new registry beside today's), the new engine/page file(s) and their dofile, the preview data file and command, `talents_ui.lua`, `grug_skills/page.lua`, `grug_classes/textures/`, `grug_classes/LICENSE-media.md`, `tools/r44_ts`, `r44_fr`, `r451_kf`, `tools/r52_graph/` | GRAPH |
| `tools/r52_art/` (staged art) | ARTA, ARTB |
| after CORE-A: the overlay table and skin change in `grug_abilities/init.lua`, the overlay textures, `grug_abilities/LICENSE-media.md`, `tools/r52_wfx/` | WFX |
| docs, STATUS, CHANGELOG, BACKLOG, ROADMAP, README, the AGENTS.md status pointer, version, `upgrade.json` | D |

- `zone_authority.lua` is read-only for everyone.
- A stub-only edit in another wave-2 lane's fixture is allowed. The later
  lane resolves it when main is merged into it.
- Any other change to another lane's file goes to the coordinator.

## 4. Rules and gates

- **Round workflow §3** applies per lane:
  - `check_lua` on changed Lua;
  - `check_fresh_server`;
  - the lane fixture plus the fixtures that test the changed behaviour, and
    the full `run_fixtures.sh` once per lane;
  - one smoke boot;
  - the upgrade classification (compatible for every lane);
  - an independent review.
- **Fixture sentence** in every brief, from the lane-start checklist.
- **Behaviour proofs** (proportionate; reported, not tightened):
  - SPLIT: the registration dump and the moved-lines diff.
  - CORE-A: per-action records of the deterministic bench, identical except
    Mend's phase, plus the `normalize_kit` fixture.
  - CORE-B: fixtures and the five-case probe.
  - GRAPH:
    - today's registry and bonuses are unchanged;
    - the live page differs only by the scrolling row;
    - the new page's bytes are reported.
  - AMB: as in A §3.2 step 12.
- **Budgets named in the briefs:**
  - at most 8 Lua processes;
  - the particle budget (hundreds in total, never thousands);
  - the sound gate;
  - the terrain guard (untouched by this round).
- **Stop and report:** a lane that needs a mechanic outside the
  building-block list (C1), or a ruling the plans do not give, stops that
  path and reports.
- **Round end on main:**
  - `check_fresh_server`, `check_upgrade` and the full `run_fixtures.sh`;
  - one boot of main;
  - `sync_to_luanti`;
  - the user's GUI check (A §7 and B §4).

## 5. D — docs and release

As in round-workflow §4, for both parts:
- **Version:** 0.52.0 compatible in `game.conf` and
  `tools/web_data/upgrade.json`.
- **Ambience docs:** the model in the module guide (A §3.4).
- **Class docs:**
  - the action clock, the transformation field, the window runtime, the area
    query and the ground anchor in the module guide;
  - the graph talent format, the preview and the scrolling skill list in
    `skill_trees.md` and where the catalogue row is specified;
  - Mend's tick in `classes.md`.
- **Planning files:**
  - STATUS, CHANGELOG, BACKLOG (A §4 parked items), ROADMAP and README where
    they name sounds or talents;
  - the AGENTS.md status pointer;
  - the delivery plan's progress (round F done);
  - this plan's completion section with both GUI checklists.
- **Media:** every `LICENSE-media.md` row checked against the shipped files.

## 6. Orchestration notes

- **Before the merge of `class-plan`** (coordinator, docs only):
  - amend `delivery-plan.md` §4 to the decided shape: no 1:1 conversion, the
    preview, CORE split into A and B, the round-K reset;
  - add `node-list.md` to `docs/planning/class-redesign/`.
- **Start state:**
  - main after R51's merge and release;
  - `class-plan` merged;
  - the three round plans committed to `docs/planning/`;
  - then the worktrees.
- **Before the start:**
  - the ambience plan's §0 checks (biomes after R51, `terrain_height_at`,
    `water_query_at`);
  - the class file facts re-checked at the base commit;
  - D5's tab height confirmed;
  - the ARTA brief carries the geometry.
- **Calculator:** the [balance calculator](https://claude.ai/artifact/TAGi8NTRNGGuHoULXWwWCc)
  is not used in R52. Its stored values feed round K.
- **Notes for later rounds:**
  - the crackling fire c_bg3 as a sound idea for Fire Rain (A §4); the
    coordinator adds it to the class-redesign board;
  - part B §5 lists round K's open points.

## 7. Questions for the user

None open. The coordinator's defaults stand unless the user overrules them:
§2 here, and D1–D9 in part B. The user's most visible ones are listed in
the coordinator's chat summary.
