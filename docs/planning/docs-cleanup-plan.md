# Documentation cleanup plan (2026-11)

Agreed with the user on 2026-11-16. Goal: an agent that starts in this
repository finds its way quickly and reads little. Today the mandatory
session start (AGENTS.md plus docs/STATUS.md) costs about 263 KB; the target
is about 28 KB. No game code changes, no new game version.

This plan is self-contained: it carries the findings of the audit of
2026-11-16 (five read-only audits at commit `4f6b20b7`), because those
reports exist nowhere else. Line numbers refer to that commit and shift as
the work proceeds; treat every finding as a hypothesis and check it at the
cited place before acting.

## 1. The user's decisions (2026-11-16)

1. **Scope:** all eight steps below. Steps 1–5 first; show the user the
   result before steps 6–8 start.
2. **No repository split.** One repository stays. Dead evidence moves out of
   the working tree (step 8); `tools/` is not touched.
3. **Production runs 0.78.0.**
4. **GUI acceptance is not tracked.** Every GUI test recorded as open
   (Rounds 36–79) counts as done. The user tests little; the community tests.
   The acceptance ledger is dropped, not rescued.
5. **Human tests on demand:** a round no longer has to end with a GUI
   checklist. An agent proposes a human test when it is unsure whether
   something works as planned, or when a human test is otherwise sensible,
   important or helpful.
6. **Model policy:** the Sol/Terra and Codex-coordinator material goes to the
   archive. A Fable run still needs the user's approval per lane, with a
   short reason why Fable instead of Opus. Opus implements and reviews where
   possible. A session that itself runs on Fable passes Fable on to
   subagents started without a model override: that counts as a Fable lane.
7. **No size guard.** The changed round-end rule (step 1) must be enough.
8. **Order with Round 80:** another agent writes
   `docs/planning/round80-plan.md` now. This cleanup lands first; Round 80
   is implemented afterwards. The cleanup does not edit the Round 80 plan,
   and Round 80 then follows the new round-end rule.

## 2. Diagnosis

The specification is mostly sound. The problem is the retelling of rounds:
each round is entered in up to eight files at its end and nothing is ever
replaced. The audit of October 2026 cut AGENTS.md to 28 KB; six weeks later
it is 71 KB again. The cause is the round-end procedure
(`docs/process/round-workflow.md` L185–197, lane D), so step 1 changes it
before anything is cut.

| File or area | Size | Needed today | Finding |
|---|---|---|---|
| AGENTS.md | 71 KB | ~25 KB | "Current state" (L15–276) is 19.4 KB of round history; "Project conventions" (L519–1020) is 32.7 KB, 80–85 % of it has a second home |
| docs/STATUS.md | 192 KB | ~3 KB | one heading, 2,732 lines; 13 false "not pushed" claims in the first 230 lines; five different production versions; two frozen "current" snapshots (L556–594, L2592–2726) |
| BACKLOG.md | 303 KB | ~30 KB | ~10 % explicit open work, 28 % delivered receipts, 60 % per-round residual notes; no index of what is open; "Readiness" (L806–1083) names Round 48 as the latest delivery |
| ROADMAP.md | 64 KB | ~20 KB | "Delivered foundation" (L310–813, 34 KB) has 50 done bullets and no open one; "Next priorities" L99–166 are delivered notes |
| README.md | 33 KB | ~16 KB | "Current state" (L99–394, 18 KB) is a second changelog |
| CHANGELOG.md | 157 KB | all | correct owner, clean; no cut |
| docs/technical/module-guide.md | 280 KB | content needed | 45 `##` sections, no `###`; sections up to 41 KB; up to 29 % round history woven into the seam text |
| docs/design/ | 1.75 MB | mostly | three factual errors, appended round sections, several owners per topic; `README.md` is 24 KB, 21.6 KB of it round status in table cells |
| docs/process/ | 82 KB | ~45 KB | the fixture rule contradicts itself in five places; large parts serve a Codex coordinator not used since Round 24 |
| docs/research/ | 156 MB | ~5 MB | ~146 MB of artifacts and logs that neither code nor live docs read |

One round is told six to eight times (traced: Round 76 in STATUS L49–74,
AGENTS L22–28, CHANGELOG, README L118–130, BACKLOG L85–110 and its plan;
Round 62 eight times).

## 3. Steps

Every step is one commit on the cleanup branch with an independent review
whose question is "was anything lost that has no other home?".

### Step 1: stop the regrowth

- Change `docs/process/round-workflow.md` (lane D and the post-merge status
  step, L185–197) and `docs/process/documentation.md` (the owners table) so
  that a round's end writes exactly three things: the CHANGELOG entry, the
  round plan's "Completion" section, and one replaced row in STATUS. Nothing
  is appended to AGENTS.md, ROADMAP.md, README.md or BACKLOG.md headings.
- README keeps a short current state that is replaced, not extended.
- BACKLOG headings stop carrying acceptance state.
- Replace "every round ends with a GUI checklist" (AGENTS.md "Working
  method", the round workflow, the templates) by decision 5.

### Step 2: one set of working rules

- **Fixture runs:** `round-workflow.md` L117–123 is the current rule (lanes
  run only the strictly needed fixtures; the coordinator runs the full set
  once at the round's end; a small follow-up round runs a targeted
  selection). Make it the single owner and fix the places that contradict
  it: AGENTS.md L1041–1046, the gates table at `round-workflow.md` L95,
  `templates/common-brief.md` L73–75, `templates/review-common.md` L45–47.
- **Rules that live only outside the repository** move into the round
  workflow: the mandatory launch sentence, the batch rule (one run on main
  after a batch of similar lanes, 2026-11-07) and "do not claim a sync that
  did not happen" from
  `~/projects/grudgelands-orchestration/LANE-START-CHECKLIST.md`; compaction
  checkpoints, "merge UI lanes only after the user's go" and "independent
  delta review for logic fixes" from the coordinator's memory. The
  out-of-repo checklist then becomes a pointer (the coordinator edits it;
  it is not part of the repository).
- **Other contradictions:** `cross-cli-orchestration.md` L51 (lanes branch
  from `main`; current: from `round<NN>`), L56–58 (orchestrator reruns
  fixtures; current: reviewers read receipts), L329 (a `reference_projects`
  submodule wording against AGENTS.md "never a submodule" for vendored
  code); `templates/common-brief.md` L85 (queue path; practice uses
  `r45/lua_run.sh`).
- **`agent-model-policy.md`** (17 KB → ~4 KB): the user routes per session;
  Opus implements and reviews where possible; the Fable rule of decision 6;
  independent review and the definition of "trivial"; the Astra role (art
  and quest texts); the execution-channel rule. Sol, Terra and the
  calibration records go to `docs/archive/process/`.
- **`cross-cli-orchestration.md` and `claude-cli-review.md`** (29.5 KB →
  ~8 KB): one note "Astra lanes through the Codex CLI" with launch, resume
  and the pitfalls table; the Codex-to-Claude direction is archived.
- **Templates:** resync `common-brief.md` and `review-common.md` with the
  practised Round 79 brief
  (`~/projects/grudgelands-orchestration/r79/`), add the lane-merge script.
- **Dead stubs:** delete `docs/process/wp-workflow.md`,
  `docs/maintenance/findings.md` and `docs/research/luanti-lua.md` after
  repointing their links and the message in `tools/check_lua.sh` L110 (and
  L21) to `docs/technical/luanti-lua.md`.
- `documentation.md`: drop the "preserve review calibration" clause (L68),
  add the cold-storage rule of step 8.

### Step 3: STATUS.md as a snapshot (≤ 3 KB)

- New content: a date and the hint to verify with `git status -sb`; the
  version and the main hash; production (0.78.0); work in progress
  (branches, worktrees, the next round's plan); open actions for the user
  that are not GUI tests (the end-to-end test on the rehearsal realm, the
  website's rate-limit confirmation, the E-key decision of Round 78; check
  each is still open); a table of the last five rounds (version, upgrade
  kind, pushed, completion link); pointers to CHANGELOG, BACKLOG and the
  archive. No lanes, fixtures, reviews or feature prose.
- Move the old file unchanged to `docs/archive/status-through-round-79.md`.
  No link points at a STATUS anchor.
- Before the move, note in the new file or the archive header: the
  production deploy history, and that these entries have no plan
  "Completion" to fall back on and are findable only in the archive: Rounds
  22, 23, 51, 52, 63 and the patch entries 0.75.3, 0.75.4, 0.66.1, 0.60.1,
  0.61.1.
- Known git fact for the snapshot: the tags `round-72.1` to `round-76.2`
  (13 tags) exist only locally; origin has `round-78`, `round-79` and
  `v0.68.0`. Pushing them is the user's.

### Step 4: AGENTS.md to about 25 KB

- "Current state" becomes a three-line pointer to STATUS.
- Keep: language rules, standing user rulings, release mode, the sharing
  authorization, documentation layers, working method, project structure,
  Lua and Luanti environment, anatomy, licences, testing.
- "Project conventions": keep the universal rules (the preamble L519–543,
  "Performance" L660–679, the sound approval gate and downloads L827–839,
  the engine-run budget L994–999, the word Expedition L627, the feed rule
  L773, the terrain-damage guard). Replace each topic subsection by one
  line: "touching X: read guide section Y and design file Z".
- Topic rules move to the top of their module-guide area as a short "Rules"
  block. Unique to AGENTS.md and to be kept somewhere: "Balance is for a
  Warrior and a Priest" (L656), `FOREMAN_TITLES` (L922), the `tools/r36_qa`
  and `tools/r36_qt` pins.
- Check commands move to one "changed → run" table. Proposed home:
  `tools/README.md`, with `round-workflow.md` L98 (which repeats the list
  in one table cell) linking to it. The mapping "change X, run Y" is the
  unique content; the commands' folders are already listed.
- Round history in the section is deleted where `docs/design/quests.md` or
  the round plans hold it (the quest rework narrative L869–893 duplicates
  quests.md).
- Stale items to fix on the way: `module-guide.md` L2789 lists six migration
  steps and omits 0.69.0.

### Step 5: BACKLOG, ROADMAP, README, TODO files

- **BACKLOG (→ ~30 KB):** keep the open inventory (WP46 remainder
  L1143–1186, WP48 L1187–1288, WP42; the first-public-release gates
  L4607–4645; the design reviews of 2026-10-11 L733–805; UI follow-ups
  L673–696; the open audit questions L4310–4413, 31 bullets of which 7 are
  answered; MGT-03, P6, P8 L4414–4434; weather L4500; capital wall
  follow-ups L4582–4606; the small clean-ups confirmed open in code: the
  "Minimum level" text L662, `mob_repellent` L1341, `BRACKET_TINT` L543,
  `dogswitch` L59).
- Per-round residual notes (181 KB; 18 top-level round sections L9–672 and
  42 "carry-overs" sections L1297–4233) move into each round's plan as a
  "Carry-overs" section beside "Completion"; bullets marked done are
  dropped.
- Delete the receipts: "Readiness" (L806–1083), the 24 `### Round N`
  sections, the done-titled sections (L4435–4581), "Decided for later"
  (L4234–4309, delivered in Rounds 57–62). The WP table (L1084–1142) goes
  to the archive except the rows of WP42, WP46 and WP48.
- Rescue before cutting: "decided, user" bullets buried in carry-overs
  (for example L211, L437, L643; check each is in design) and the
  "first-look defaults to tune" lists (L478, L523, L591).
- Link cost: 152 inbound `BACKLOG.md#…` links (ROADMAP 41, STATUS 32) need
  a rewrite pass.
- **ROADMAP (→ ~20 KB):** delete "Delivered foundation" (L310–813); strip
  round history from "Next priorities" to goal plus next step; drop L99–166
  and keep L167–172; rescue the user's direction at L162–166 if the Round 57
  plan does not hold it. Keep the headings that are link targets (§5).
- **README (→ ~16 KB):** "Current state" keeps the latest one or two
  versions, the paragraph on what comes next (L387–393) and the changelog
  link. It is the human-facing page: show the user the result.
- **TODO files:** delete `TODO-design-depth.md` (closed since Round 46;
  repoint its mentions in BACKLOG, `docs/design/world.md` and the Round 46,
  50 and 53 plans). `TODO-design-nether.md` keeps its three open questions;
  its decided rules move into `docs/design/world.md` as a labelled future
  system; the stale "Phase 3 option" line (built as Expeditions) goes.

**Checkpoint: show the user the result of steps 1–5 and wait for the go.**

### Step 6: the module guide by area

- Split along areas: combat and classes; mobs; items and professions;
  mapgen; player systems (quests, parties, mail, housing, travel, atlas);
  expeditions; UI and looks (UI, text, looks, cloaks, sound); platform
  contracts (player meta, performance lines, web bridge, accounts, world
  version).
- `module-guide.md` stays as the index: its 45 headings remain as stubs
  that link to the new files, so the 43 anchored links and the 5 code
  comments keep working.
- Add `###` sub-headings in the large sections; the "Rules" blocks of step
  4 sit at the top of each area.
- `upgrade-contract.md`: §2's per-release case history (~11.6 KB) moves to
  an appendix; §5.8 (the step table) and all section numbers stay.
- `mod-map.md`: trim round detail from the table cells. Gaps: `grug_displays`
  and `grug_keys` are in the mod map but not in the module guide.

### Step 7: design

- **Factual errors:** `economy.md` L297 says repair factor 1.00; the code
  (`grug_repair/service.lua` L20), `durability_repair.md` L102 and
  `item_tiers.md` L795 say 0.50; `item_tiers.md` L7 and the design README's
  economy row say ×1.0. `biomes_mobs.md` L1693–1696 says 222 sub-types and
  120 items; the data has 218 and 122. The quest total is 390
  (`quests.md` L225), 391 (`progression.md` L5) and 393 by count: establish
  one number and one owner.
- **`docs/design/README.md`:** the status column shrinks to one word plus
  the implementing round (24 KB → ~8 KB).
- **Stubs:** delete `crafting_equipment_revision.md` and
  `playtest_quality_revision.md` after repointing their 46 and 16 inbound
  links; remove the redirect stubs in `items_crafting.md` (§1, §2, §10) and
  `world_zones.md` §15.
- **Appended round sections fold into their topics:** `world_zones.md`
  L2289–2458 (it keeps superseded text at L2436–2440), `biomes_mobs.md`
  L1641–1973, the "Round N" sections of `settlements.md` and
  `inventory_equipment.md`; the change-narrative preambles of
  `items_crafting.md` L1–51, `world_zones.md` L1–19, `quests.md` L1–20 and
  L205–225, `progression.md` L5–20.
- **`quests.md`:** organised by round, not topic; L867–1382 (34 KB) records
  the quest content per band and duplicates the quest JSON. Restructure by
  topic as its own lane (largest link impact: AGENTS.md cites it 20 times,
  three anchors carry a round tag).
- **One owner per topic,** the others one link line: spawning and levels,
  capitals, PvP geography, the Reed Angelfish rule (verbatim in
  `world_zones.md` L2446–2458 and `biomes_mobs.md` L1671–1684).
- `miners_guild.md`: reword "Proposal" to decided. Unresolved: whether the
  flight section of `world_zones.md` (L2406–2413) should name the Round 74
  coastal-belt rule.
- Numbered sections stay in place; only narrative inside them is stripped.
  The audit read six files closely and judged the other thirty by headings,
  so each lane measures its own files first.

### Step 8: cold storage and the plan index

- Move out of the working tree to
  `~/projects/grudgelands-orchestration/archive/` (the user agreed): the
  `docs/research/wp40-*.tsv` files except the six small R6 content files
  that mod code names, the twelve `wp40-*-evidence/` folders, and
  `round23-tree-line/`, `round23-capital-walls/`,
  `round24-underground-fill/` (~146 MB, ~900 files, no code reads them).
  Leave a short index in `docs/research/README.md`. Verify per group that no
  tool or fixture reads it before moving.
- Research files that live docs treat as authority move to
  `docs/technical/` (or are linked as such): `wp40-simple-map-r6-contract.md`,
  `wp40-completion.md`, `wp6_spawn_budget.md`, `perf-review-2026-10.md`,
  `wp13-npc-sockets-contract.md`, `wp13-character-visuals-contract.md`,
  `hud-bars.md`, `mob-pressure.md`, `mapgen-chunk-profile-2026-10.md`.
  Weigh each move against its inbound references (the wp13 contracts are
  cited in 16+ mod comments); a pointer from `docs/technical/` may be
  cheaper than a move.
- Historical round plans stay at their paths (moving them breaks about 680
  citations). Add an index in `docs/planning/` that marks active against
  historical. Delete the seven orphans with no inbound reference: the five
  `round20-*` files and the two `round21-*` files (340 KB; recheck first).
- Rules that live only in a plan and are cited as the rule stay reachable
  and are named in the index: the story bible (`round36/`), the UI crafting
  spec §2.16–2.36, the class-redesign node list, the level 20 Expedition
  description, the economy shelves §2.3.

## 4. How the work runs

- Branch `docs-cleanup` in its own worktree; lanes branch from it and merge
  into it; one squash commit on main at the end; the tip is tagged before
  the branch is deleted. Only the user pushes.
- No game version, no CHANGELOG entry, no upgrade declaration: nothing the
  game ships changes. `tools/check_lua.sh` changes only a message.
- Lanes run on Opus. Before the first launch the coordinator tests whether
  the model override works; a lane that would run on Fable is asked for
  first, with the reason.
- Fixtures: lanes run only the fixtures that read the documents they change
  (found by grep). The coordinator runs the full set once at the end,
  because several fixtures read documents.
- Other sessions may touch STATUS.md, AGENTS.md or BACKLOG.md while this
  runs (the Round 80 plan is being written); check `git status` and the log
  on main before each merge.

## 5. Must not break

- `tools/r37_dc/portable_test.lua`: the first `## ` heading of CHANGELOG.md
  contains the `game.conf` version (L94–97); every relative link and anchor
  in README.md and CHANGELOG.md resolves (L176–190). Keep the headings
  `ROADMAP.md#next-priorities--deepening-the-playable-game`, `#v1-scope`,
  `#before-the-first-public-release`.
- `tools/r42_dr/portable_test.lua` L835–839: AGENTS.md contains "door" and
  not the old "one recorded exception" wording.
- `tools/r70_guild/portable_test.lua` L590: AGENTS.md, `miners_guild.md` and
  `economy.md` do not contain "no copper route" or "copper never buys".
- `tools/r70_design/build.py`: literal strings from `world.md`,
  `settlements.md`, `world_zones.md`; L686 matches the "### 6.1" heading of
  `building-template-format.md`.
- `tools/r38_names/inventory.py` L290 and `tools/r51_names/build.py` L275
  find the literal `**Names (Round 38` in `biomes_mobs.md`.
- Generated blocks: `item_tiers.md` (16 blocks, `tools/r33_ds/build_doc.py
  --check`), `zone_mobs.md` (whole file, `tools/r37_dd/zone_mobs.lua`), the
  `miners_guild.md` block (`tools/r58_guildspec/write_doc.lua --check`).
- Section numbers: code comments cite design sections about 430 times
  (combat_stats 78, biomes_mobs 72, world.md 68, world_zones 55) and the
  upgrade contract, armor, offhand and building-template formats by §.
- Ten anchors that AGENTS.md links into design files; update link and
  heading in the same commit when a heading loses its round tag.
- Path-bound planning data that tools read: `docs/planning/round28/`
  (`items/existing.json` in nine fixtures, `design/catalog/*.json`,
  `zones/*.json`, `mobs/names-proposal.json`; four tools write renders
  there), `round31/pvp-names.json`, `round36/story-bible.md`,
  `class-redesign/` (`node-list.md` is hashed by `tools/r52_art`),
  `round71-outline/`, `round71-l20-*`, `round72-expeditions/`,
  `round72-last-mint.md`, `round72-second-shift.md`, `map-icon-*.html`.
- `docs/research/r10-visuals/`, `round24-art/`, `assets/`, `licensing.md`:
  tools or licence provenance.
- `wp40/r6_content.lua` L33–46 and `r7_r6_manifest.lua` L5–18 list documents
  with frozen digests; nothing was found that recomputes them. Confirm with
  the mapgen fixtures before relying on it.

## 6. Open points

- Whether `docs/audit-2026-10/` can leave once BACKLOG stops citing it (42
  references today).
- Whether scout §8 (deferred stealth, 13.7 KB) moves to a TODO or planning
  file.
- `tools/README.md` names 347 of 472 tool folders; closing the gap is out of
  scope unless the "changed → run" table needs it.

## Completion (2026-11-16)

All eight steps landed in one squash commit; the branch tip is tagged
`docs-cleanup-2026-11`. Eleven lanes ran on Opus, each followed by an
independent Opus review that asked what was lost without another home; ten
reviews returned "merge after fixes", one "merge", and none found a lost
rule. The full fixture run on the merged state: 356 passed, 0 failed. The
link checker reports 174 broken links, all in historical files, the same
set as before the round. Game code is unchanged apart from four comment
lines that name `docs/technical/luanti-lua.md`.

| | before | after |
|---|---|---|
| Session start (AGENTS.md + docs/STATUS.md) | 263 KB | 32 KB |
| BACKLOG.md | 303 KB | 34 KB |
| ROADMAP.md | 64 KB | 16 KB |
| Module guide | one file, 288 KB | an 8.6 KB index and eight area files of 12–51 KB in `docs/technical/modules/` |
| docs/design/README.md | 24 KB | 10 KB |
| docs/research | 161 MB | 11 MB (913 files in `~/projects/grudgelands-orchestration/archive/docs-research/`) |

Changed against the plan:

- The "changed → run" table is `docs/process/checks.md`, not `tools/README.md`.
- Step 8 deleted no planning file: the eight `round20-*`/`round21-*` files
  have inbound links from historical records. None of the nine authority
  research files moved (mod comments, tools or frozen digest keys name
  them); `docs/technical/README.md` points at them.
- `quests.md` is organised by topic; its round layers are in
  `docs/archive/design/quests-history.md`. PvP geography is owned by
  `pvp.md` §1, the Reed Angelfish rule by `biomes_mobs.md`.
- Facts corrected against code and data: repair factor 0.50; 218 mob
  sub-types, 45 leaders, 122 items, 4 quest items; 393 quests; fortress
  quests at level 41 (open from 39); four main-line step levels.

## Carry-overs

- The Reed Angelfish spawns in lakes and bays (`planned_water`); the design
  calls it a freshwater fish. Whether bays are intended is the user's call.
- The generated income table of `item_tiers.md` §6.5 is still computed at
  repair factor 1.00 (`tools/r33_ds`); the prose says so.
- `tools/r70_design/build.py` is broken (in BACKLOG).
- About 200 short "since Round N" clauses remain inside design sections;
  the design README's round spans are rough outside the eight checked rows.
- Open points of §6 (`docs/audit-2026-10/`, scout §8, `tools/README.md`
  coverage) are unchanged.
