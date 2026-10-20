# Round 52 — Ambience and the class rework foundation

Coordinator: Claude (Opus 5.5), drafted 2026-10-19 with the user while
Round 51 runs, revised the same day after an independent review
(`r52/plan-review.md`: 1 High, 9 Medium, 14 Low, all addressed). Status:
**complete** 2026-10-20, version 0.52.0, compatible
([completion](#completion-2026-10-20)); started 2026-10-19 (the user's
"go"; main after R51 and its follow-up, 0.51.0 pushed). D5's height is
confirmed as 5.5 units (part B §1).

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

## Completion (2026-10-20)

Every planned lane and the added lane PFX are merged on main; this lane D
(this section and the status owners) follows on main `260402b9` (GRAPH's
art step, merged last). **0.52.0 is compatible, no migration step:**
nothing in world generation changes, nothing writes world nodes, no item is
removed and no saved state is read differently. **Push:** not pushed;
origin/main stays at `dea1d163` (0.51.0) until the user's word.

Where this plan and a partial plan differed, the partial plan's amendments
won: the eight overlay families of part B's C7 (this plan's lane table
still says "6 overlay strips" for ARTA) and D5's 13 × 5.5. Inside part B,
WFX followed C7's second amendment over the older wording of part B §3
(see the deviations).

### Lanes

Main's first-parent merges from `7813165e` (the three plans), in order.
Every code lane was reviewed independently by Opus; the data steps had a
short review or the coordinator's check; art, sound and page lanes were
picked by the user.

| Lane | Merge (lane tip) | What | Review |
|---|---|---|---|
| SPLIT | `e2ab497f` (`570a420f`) | `kits_warrior/mage/priest.lua`, `talents_warrior/mage/priest.lua`, the window runtime in `talent_windows.lua`; the registration dump identical to main | MERGE (a stale comment, fixed on main `5e54f1cc`) |
| SND | `07c7c1bc` (`4471d8f5`) | 15 beds and 8 calls cut from the picks, staged under `tools/r52_snd/`, the listening page | the user: all 23 "keep" |
| CORE-B | `78895157` (`7578c257`) | `grug_core/area.lua` (ground anchor, area query, delayed area, group helper), the readiness windows, three area effects, the probe | MERGE (a low for round K; a nit fixed on main `4cdba3f2`) |
| GRAPH | `0fd6d6f5` (`b6d0ea48`) | the graph registry and audit, the eight trees as preview data, the new page and `/talent_preview`, the scrolling skill row | MERGE (lows: a doc bullet, done here; three for round K) |
| AMB | `a0d3c032` (`7e3a0ac0`) | biome groups, three layers by the height relative to the terrain, the cave probe, the relative underground band, calls by sound key, `/ambience debug` | MERGE |
| CORE-A | `13b579b3` (`13bcb2a8`) | the action clock in three directions, the transformation field and the class basic attack, Mend on the status system, the PvE bench | MERGE (backlog notes for round K) |
| AMB file step | `87a4970c` (`f3e8925d`) | the 23 approved cuts shipped, six beds dropped, the deep-cave band, the debug line's off state | MERGE (a question for the GUI check) |
| WFX | `890b977e` (`a3961e3c`) | `WEAPON_FX`, an animation per family, the skin pass's strip per weapon type and draw stage, 30 strips from drop 03; a third-person still built and reverted | MERGE (backlog notes) |
| ARTA | `f18b2db2` (`f0546ff0`) | staged art: 24 background drafts, the overlay passes 2–4 (tools only) | coordinator check; picked |
| ARTB | `a23cf211` (`e1145e31`) | staged icons: the style sample, 118 icons in style A, 5 redraws (tools only) | coordinator check; picked |
| PFX | `120dd0b3` (`76c241e3`) | the particle design of the 44 skills: 65 cards, a cost model, the preview page (tools only) | MERGE AFTER FIXES (Medium: the area warnings' colours), fix checked by the coordinator; picked |
| WFX data step | `d0ad6c7d` (`6b58a29d`) | the 30 strips replaced by their opaque rework (drop 04) | coordinator check (images and licence rows only) |
| GRAPH art step | `260402b9` (`b1f91828`) | 8 tree backgrounds, 74 talent icons, the 19 shipped skill icons redrawn | MERGE |
| D | this section | version, upgrade declaration, CHANGELOG, the module guide and design docs, the status owners, BACKLOG | independent docs review |

Main has 221 portable fixtures (6 new: `r52_split`, `r52_amb`,
`r52_bench`, `r52_core`, `r52_graph`, `r52_wfx`); `mods/` +4,509 −1,566
lines in 31 text files, 11 new Lua files, and 160 media files: 23 sounds
added and 6 removed, 30 overlay strips, 8 backgrounds and 74 talent icons
added, 19 skill icons replaced.

### Decisions during the round

The user's decisions (2026-10-19 and 20), one line each (the coordinator
log is outside the repository):

1. **Sounds:** all 23 cuts of the SND page kept.
2. **Backgrounds:** Ember v3, Rime v1, Bulwark v3, Ruin v1, Mercy v1,
   Reckoning v1, Quarry v1, Veil v3.
3. **Overlays, three passes:** the first drafts were too generic, so one
   strip per class and weapon type (C7 amended); the second pass was still
   generic, too fast and rotating, so one family per talent tree (eight,
   Bulwark's steel new), each with its own tempo, small accents and no
   rotation (C7 amended again); all 24 combinations picked from drop 03
   (30 strips with the bow's draw stages); the opaque rework (drop 04)
   accepted on 2026-10-20.
4. **Icons:** style A "Painted embers"; of the 118 icons 113 accepted and
   five redrawn and picked (Bladecraft v3, Flourish v1, Loose v1, Parry v2,
   Measured Breath v2).
5. **The fire and water search underground stays** (about 40 % more per
   search than on the surface).
6. **Third person:** "check briefly; others may see the skill type, only
   if simple and cheap". The engine cannot animate it there, so a still was
   built; the user then dropped it, and C7's "third person is unaffected"
   stands.
7. **Wave 3 started early;** WFX built the mechanism with the overlay off.
8. **A new lane PFX:** the particle design of the 44 skills of the rework,
   all 65 cards picked, with the lane's three recommendations (Loose
   without a trail, the readiness windows reuse the proc ring, Mighty Blow
   keeps its extra blood and Broadstroke drops it). Round K wires them.

The coordinator decided, one line each:

- **AMB:** the peak wind starts at y 215 (the pine hills, at most 157, stay
  below it); the wolves reach the pine hills through a biome row; the
  dragon channels, owned since Round 51, keep their island's mood and
  count from the water surface; `water_query_at` alone, without a
  `water_class_at` gate (swamp pools read "land").
- **CORE-B:** the ground search counts 3 m from the aimed point; the group
  cap counts the caster.
- **GRAPH:** unlock nodes show the shipped skill icons before any pick; no
  single-rank refund (the read path's refund and the full reset only); the
  live talent text shrinks from 1.15 to 1.0 high for the raised row.
- **CORE-A:** "You are still busy." stays until round K sets the values.
- **SND:** a redo would be a new candidate `<stem>-r2`; none was needed.
- **D7:** the 19 shipped skill icons are replaced live; the 25 icons of
  skills that do not exist yet stay under `tools/r52_art/artb/`.

### Deviations from the plan

- **GRAPH:** the new registry lives in its own files
  (`talent_graph.lua`, `talent_graph_preview.lua`, `talent_graph_ui.lua`,
  dofiled from `grug_classes/init.lua`), not inside `talents.lua` (§3), so
  SPLIT's dump stayed identical and no old fixture loads it.
- **SPLIT:** the talent data files and `talent_windows.lua` are plain
  chunks like `scout_talents.lua`, not closures (they use no shared
  local); the leave and death handlers stay in `talents.lua` and call
  `clear_talent_windows`.
- **CORE-A:** `normalize_kit`'s unchanged-output proof is `r52_bench`
  section N against a frozen copy of main's functions, not an extension of
  `r50_hotbar`.
- **CORE-B:** the delayed area runs on `core.after`, so it adds no
  per-step work.
- **AMB:** the column memo is keyed by the node column; the depth counts
  from the surface node's top face (standing = 0); a band of ±2 around
  y −500 for the deep cave bed (review); the debug line reads "ambience:
  off" while the ambience is off.
- **WFX:** C7's second amendment (each family its own tempo) replaces the
  first (8 frames, 0.96 s for all); part B §3's "the stack meta keeps only
  the weapon image" and "the Scout's draw stages are unaffected" predate
  the per-weapon ruling: the meta carries the strip's name as well, and
  the overlay follows the draw stage (the draw images are unchanged). The
  engine draws a wielded overlay's pixels below alpha 0.5 not at all and
  the rest opaque, so the picked strips were reworked opaque (drop 04).
- **ARTA/ARTB:** C11's six overlay families became eight (C7); ARTB ran
  three passes (style sample, the full set, five redraws).
- **PFX** is a lane the plan did not have (tools only).

### Numbers worth keeping

- **AMB** (measured, seed 12345, 16 stand-ins, 45 s per phase; per player,
  atmosphere and ambience, µs per second, before → after): surface 34.6 →
  49.0, mine 13.2 → 53.2, tower 21.4 → 31.8, a fast flight 27.9 → 74.3.
  The column memo serves 50 % of the depth calls while moving (every one
  while standing); a column costs 41 µs on the surface, 22 in the mine, 17
  on the tower and 108 in flight (360 cold columns in 45 s for 16 flyers
  at 20 nodes/s). The fire and water search underground: 34.4 µs and 6.3
  positions per search in a busy mine, 24.7 µs on the surface. The cave
  probe: 6.7 µs in the walk; 3.4 µs against 10.1 µs for a 9 × 5 × 9
  `find_nodes_in_area` in the calibration. Calibration (4,502 standable
  spots in natural caves 6–150 deep): natural p05 0.23, median 0.43, 97 %
  at 0.20 or more; a dug 1 × 2 tunnel 0.05–0.09, a 3 × 3 corridor
  0.07–0.11 (0.19 at a hall's mouth), a large dug hall 0.24–0.67 →
  threshold 0.20. Peak tops (the highest sample per 256-node cell): snowy
  crags median 230, p90 463, max 527; crags median 125, max 478; pine hills
  median 21, max 157 → peak wind from y 215. The mine walk starts about 27
  sounds per player-minute, mostly water loops (review).
- **CORE-A** (measured): the bench's per-action records are identical in
  every class (37/35/34/35 actions), the largest time difference 0.098 s
  (one server step); Mend's ticks after the cast 0.18/3.25/6.33/9.40 s on
  main and 3.16/6.14/9.12/12.10 s now, the same amounts. The `r31_pvp`
  micro run within noise (the combat ray 13.6 → 11.9 µs).
- **CORE-B** (measured): the engine probe 23/23 (stairs, stacked floors, a
  cave, shallow and deep water, a flying mob, a dead caster, the group
  heal); 96 particles per area cast at scale 1 (20 + 6 at the cast, 70 at
  the impact).
- **GRAPH** (measured): the live Talents & Skills page 7,051 → 7,138
  bytes; the preview 4,486–5,116 bytes per tree with its icons; the eight
  trees load and pass the audit in about 4 ms; the backgrounds are
  177–208 KB each, 1.50 MB together, the 93 icons 752 KB, about 2.2 MB
  more media at the first join (19 of the icons replace files of similar
  size).
- **WFX:** about 15–45 bytes of meta per skill stack (estimated), written
  once (`SKIN_VERSION` 5); in the drop-03 strips 633 of 1,035 effect pixels
  fell below alpha 0.5 (measured), hence drop 04.
- **PFX** (estimated, its deterministic model at full pace, per
  receiver): 20 players 8.6 KB/s and 265 particles alive at the peak, 50
  players 20.3 KB/s and 527 (33.1 KB/s and 745 with today's effects at the
  four frequent moments).
- **Repository:** `tools/r52_art` holds about 40 MB (539 files) and
  `tools/r52_snd` about 9 MB (its listening page 5.1 MB with the audio
  inlined).

### Classification

Every lane reported **compatible** and every review confirmed it; 0.52.0
declares no step:
`{"schema": 3, "version": "0.52.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0"], "map_reset_pass": "0.50.0"}`.
Saved state: `grug_classes:talents`, `grug_classes:talent_ready:*` and
every other player-meta key are read and written as before (the preview
never writes); the skill stacks gain the `wield_overlay` meta and the skin
token `5|<src>|<overlay>`, written once by the normal skin pass. The
readiness windows' ICDs, the action clock, the depth memo and the debug
line live in memory.

### Open notes

The reviews' and reports' notes, the parked sounds and round K's open
points are in the [Round 52 carry-overs](../../BACKLOG.md#round-52-carry-overs).
Part B §5 lists round K's points from the node list; the
[delivery plan](class-redesign/delivery-plan.md) marks round F done.

### GUI checklist (Round 52)

Desktop and the web build, on the synced game. **Ambience** (part A §7,
with what the round added):

1. Walk meadow → deep forest → elf forest → pine hills: one continuous
   bed, no switch.
2. Savanna, jungle, badlands, swamp, crags, snowy crags, blight, beach:
   each group's bed by day and at night (`/time`); the crags silent at
   night, the snowy crags' snow bed day and night. The two short crag
   bird loops: does the loop show (part A §6.3: then they leave the pool)?
3. A Battleground: "Abandoned Fields"; crows now and then.
4. Dig straight down: the bed fades out by −15, then silence in the shaft.
5. Break into a natural cave: the quiet cave bed fades in; back in the dug
   tunnel it fades out. Below y −500 the crystal bed.
6. Build or fly up: the bed fades from +10 to +60, the wind from +30,
   still in the background at +100.
7. Stand on a high snowy peak (above y 215): a light wind under the bed.
   The snowy crags get no hawks or wolves (the calls name `crags` only):
   add them? (one line of data).
8. Sky and fog: underground only when more than 20 below the terrain, also
   in the mountains; a long level tunnel does not make them flicker.
9. Swim or take a boat on the coast and on a lake: the bed stays, no wind.
10. A burning furnace in a mine is audible; do the water loops in a mine
    feel too busy?
11. Capital with music on: no bed and no wind; music off: the half-gain
    bed.
12. `/ambience debug` shows biome, group, depth, cave share and levels;
    "ambience: off" while the ambience is off.
13. The calls (owls, hawks, wolves, crows): their level and how often
    (one per 90–240 s at most).
14. The quiet sources raised by 28–34 dB (the crags' mountain air and
    birds, the snowy afternoon, the quiet badlands, the rainforest night):
    any hiss?

**Class foundation** (part B §4, with what the round added):

1. Each class fights a normal mob as before: same cadence, same skills,
   same damage feel. Holding a skill still mixes in Strike; an A/B switch
   keeps the cooldown overlay.
2. Mend heals four times, 3 s after the cast and then every 3 s; its
   status icon shows for the 12 s.
3. Talents & Skills (live): today's trees work as before, the text under
   them a little shorter; the skill row scrolls horizontally once it holds
   more than eight skills (no shipped class has more yet); the 19 redrawn
   skill icons beside Cinderfall, Glacial Ward and Pinning Shot in the old
   style; Hold Ground, Unbroken and Ruination still show and end as before.
4. The admin preview `/talent_preview mage|warrior|priest|scout`, desktop
   and web: one tab per tree; the picked background; readable connection
   lines (Veil: Opening → Turn the Blade crosses Parry → Close Dance);
   talent icons, text on the skills of round K; the sample build's node
   states (a selected node looks almost like a maxed one; open nodes say
   "No talent points left.", because the two sample builds share one
   table); Esc or the inventory key closes it.
5. The weapon overlay: the selected skill shows its family's accent on the
   held weapon type at the family's tempo; the bow's follows the draw;
   Strike and an empty slot show none; third person (F7) and other players
   show none. Are the accents visible enough?
6. Desktop and the web client, a few players nearby: no visible load; the
   first join downloads about 2.2 MB more media.

### Round-end gates

On main `260402b9` after the last merge (coordinator): the full
`run_fixtures.sh` 221 passed, 0 failed; `check_fresh_server.py` PASS;
synced to Luanti. This lane: `check_upgrade.py` PASS (0.52.0, compatible,
against origin/main `dea1d163`). On main `fc37636d` (lane D merged): the full
`run_fixtures.sh` 221 passed, 0 failed; `check_upgrade.py` and
`check_fresh_server.py` PASS; one headless boot of main PASS (150 s); synced
to Luanti. The user's GUI check (2026-10-20): both checklists pass; the
snowy crags stay without hawks and wolves. Two ambience wishes from the
check go to 0.52.1: at the coast and over the sea the bed blends into the
surf (not over inland lakes; ordinary-water lakes and pools trigger the sea
bed today, and its 7-node probe misses high coasts), and diving gets an
underwater bed of its own (picked on a listening page; today silence).

### Addendum 0.52.1 (2026-10-20)

The user's GUI check of 0.52.0 passed; three ambience wishes became
0.52.1 (compatible), two Opus lanes from main `89131375`:

- **COAST** (`e55da56b`, review fix `6bb66df2`, round 3 `6f21c249`, the
  coordinator's G1 value `68aff344`): sea or not comes from the map's water
  query (`bay`, `belt`, `channel`, `open_sea`), sampled on 49 columns on a
  4-node grid within 16 nodes and memoised for all players; a fourth layer
  `sea` takes share ÷ 0.5 of the surface level, capped, the region bed the
  rest; only the surf on sea columns; the beach biome is neutral (the
  user, 2026-10-20: "okay"); a neutral biome drops an override key; calls
  follow the region level. Underwater: `D.beds.underwater`, the user's two
  picks as one pool. Start towns: `D.town_looks` by race from the race
  palette's ground node, the nearest start anchor within 103 nodes while in
  a town and not a capital. Independent review MERGE AFTER FIXES (F1), delta
  MERGE, second delta MERGE AFTER FIXES (G1: reach 80 → 103, applied by the
  coordinator as the reviewer specified). Measured pass cost on seed 12345,
  16 walking stand-ins, fresh ground every pass: inland 35 → 71 µs, coast
  33 → 70 µs (comparison only).
- **UW** (`7df00d7c`): eight CC0 underwater beds on a listening page; the
  user picked #2 (DCSFX, 366159) and #4 (Tim_Verberne, 482167)
  ([picks](../../tools/r52_uw/picks.md)).

**GUI checklist (0.52.1):**

1. Walk from inland to the coast: the surf rises over the last ~16 nodes,
   full at the water line; on a cliff top above the sea it is still heard;
   flying high it fades with the bed.
2. A boat or swimming on the sea: only the surf. On an inland lake, a
   pond or a swamp pool: the landscape's bed, no surf.
3. Dive: only the underwater bed; `/ambience debug` names which of the two
   files plays; surfacing brings the bed back.
4. The human start town (and Sunscar, the orc town): the look's bed
   everywhere inside, corners included; outside the town the landscape's
   bed. Hearthpine at night: the pine-hills look makes the wolf call
   eligible there.

Gates on main `d30d812f` (0.52.1): full fixtures 221/0, `check_upgrade.py`
(0.52.1 against origin/main) and `check_fresh_server.py` PASS, one headless
boot PASS (150 s); synced.
