# D2 — Agent context and project-status documents

**Scope (documents checked):** `CLAUDE.md`, `AGENTS.md` (910 lines, 56 KB),
`ROADMAP.md`, `BACKLOG.md`, `docs/README.md`, `docs/STATUS.md`,
`docs/design/README.md`, the three root `TODO-design-*.md`, `docs/process/*.md`
(agent-model-policy, claude-cli-review, cross-cli-orchestration, documentation,
wp-workflow), `docs/technical/module-guide.md`,
`docs/technical/upstream-workarounds.md`, `docs/maintenance/*.md`,
`docs/reference_projects.md`, `VENDOR.md` and `CREDITS.md` (currency only),
`minetest.conf`. Sources (not subjects): `docs/planning/round35-plan.md`,
`round36-plan.md`, `docs/planning/wp-audit-2026-09-29.md`, git history and
reflog.

**Baseline:** `0f169898` (main; `origin/main` is the same commit).

**Method:**
- Scripted extraction of every Markdown link and every code-span path
  (`*.lua/.py/.sh/.md/.json/.txt/.tsv/.conf` or containing `/`) in the scoped
  docs, resolved against the repo (direct, link-relative, and by basename under
  `mods/`, `tools/`, `docs/`). Every unresolved hit was inspected by hand.
  Nearly all were placeholders (`tools/r36_<lane>/`), engine-source paths
  inside `reference_projects/luanti`, or files the doc itself calls retired.
- Scripted extraction of all 169 `grug_*.<name>` and `core.*` identifiers in
  AGENTS.md, the module guide and upstream-workarounds.md, grepped in `mods/`.
  All of them exist. The one apparent miss, `grug_core.difficulty_at`, is
  documented as "gone".
- Checked by hand: every `tools/rNN_<lane>` folder AGENTS.md lists, the seed
  fleet, fixture runner, headless launcher, `check_lua.sh`, `sync_to_luanti.sh`
  and `minetest.conf`. Also compared VENDOR.md with the `GRUG PATCH` counts
  and CREDITS.md with the `LICENSE-media.md` diffs since Round 34. Compared the
  push state with `git reflog refs/remotes/origin/main` and the merge history
  with the claims in the status documents.
- Not re-reported: the design/code gaps that `docs/maintenance/findings.md`
  and BACKLOG carry-overs already list. CTX-13 covers findings.md itself
  being stale.

## Verdict

- **The conventions in AGENTS.md are accurate.** Every API, seam, data
  file and tool path in the "since Round 28–36" convention sections exists as
  described: `grug_core.aim_raycast`, `grug_quests.register_on_turn_in`,
  `grug_items.enchant_value`, `grug_sounds.EVENTS/HOOKS`, `grug_mobs/dawn.lua`,
  `tools/seed_fleet/run.sh` and the others. An agent following those rules
  writes correct code.
- **The status is stale on the day it was written.** Round 36 was pushed
  (reflog: `1e8a975d` at 18:47 and `0f169898` at 21:19 on 2026-10-05).
  AGENTS, STATUS, ROADMAP, BACKLOG and README all still say "not pushed" or
  "Round 35 is the latest pushed state". Four lanes merged after the Round 36
  completion (F2, W2, W3, RD) appear in no status document.
- **The rules contradict each other on two binding points.** First, the
  parallel-interpreter cap: AGENTS says seven and forbids an eighth, while
  AGENTS, the seed fleet and the tools README use eight. Second, the PUC
  final micro-KAT: AGENTS and wp-workflow make it mandatory per package,
  BACKLOG, ROADMAP and audit E9 make it optional, no tool exists for it, and
  no round since Round 22 has run it.
- **The documented workflow is not the one in use.** AGENTS and wp-workflow
  describe "one WP per session on a `wp<NN>-<slug>` branch". Since
  2026-09-20 the project runs rounds with lanes on `r<NN>-<lane>` branches in
  `.claude/worktrees`, with briefs and handover logs in
  `~/projects/grudgelands-orchestration`, outside the repo. The real gate set
  per lane and per round appears only in each round plan's §5/§6.
- **AGENTS.md is far too large for an always-loaded file.** About 23 %
  (lines 65–271) is round history that is copied four times (AGENTS, STATUS,
  ROADMAP, BACKLOG, plus README). About 33 % (544–842) is per-round sections,
  half of which are lane-folder inventories. This breaks the project's own
  rule (`documentation.md`: "not an ever-growing mandatory startup file").
- **The module guide is current but cannot be navigated.** It has 1,491
  lines with a single heading. One bullet ("Combat/classes") runs for 280
  lines. There is no map of which mod owns which concern, and `grug_artisans`
  and `grug_trees` are not mentioned.
- **Several working rules exist only in Claude's private memory.** Examples:
  the particle budget for the web build, the faction-name rule, the mapgen
  engine-run budget and the review scope. Codex/Astra agents and fresh
  contexts never see them.
- **These documents are current:** VENDOR.md (all 13 vendored mods, marker
  counts match), CREDITS.md (nothing CC BY added since Round 34),
  upstream-workarounds.md (both entries match the code) and the BACKLOG WP
  arithmetic (47/3/4 of 54, the same in README). findings.md and the
  maintenance records are stale.

## Mismatch table

| ID | Sev | Category | Direction | Doc location | Short description |
|---|---|---|---|---|---|
| CTX-01 | Medium | Outdated | doc stale → fix doc | AGENTS.md:67; docs/STATUS.md:9, 504-506, 555-556; ROADMAP.md:300-301; BACKLOG.md:25; README.md:72, 232; round36-plan.md:4, 628 | Round 36 is called "not pushed / local only"; it was pushed twice on 2026-10-05 |
| CTX-02 | Medium | Contradiction | unclear → Jan decides | AGENTS.md:431-443 vs AGENTS.md:897, tools/README.md:30, docs/design/spawn_regions.md:386 | Seven-process cap ("does not authorize an eighth") vs seed fleet and docs using 8 |
| CTX-03 | High | Contradiction | unclear → Jan decides | AGENTS.md:420-457; docs/process/wp-workflow.md:62-71, 88-94; docs/research/luanti-lua.md:7-16 vs BACKLOG.md:1286-1299, ROADMAP.md:331-337 | Mandatory per-package PUC/LuaJIT micro-KAT vs "PUC run optional" (E9); no tool exists; not run since Round 22 |
| CTX-04 | High | Outdated | doc stale → fix doc | AGENTS.md:316-335; docs/process/wp-workflow.md:47-48, 6-35 | "One WP per session, branch `wp<NN>-<slug>`, pick next open WP" vs. rounds/lanes/worktrees since 2026-09-20; orchestration state lives outside the repo |
| CTX-05 | Medium | Missing | doc stale → fix doc | AGENTS.md (whole); docs/process/cross-cli-orchestration.md:233-245 | Per-lane and round-end gates (check_fresh_server.py, validate.py --game, income.py --check, run_fixtures, smoke boot, seed fleet) only in round plans; cross-cli §2.6 describes a retired round end |
| CTX-06 | Medium | Missing | doc stale → fix doc | round36-plan.md:625ff; docs/STATUS.md:5-48; BACKLOG.md:992-1077; AGENTS.md:831-842 | Lanes F2, W2, W3, RD merged after the completion (incl. terrain/placement changes) are recorded nowhere in status docs |
| CTX-07 | Low | Outdated | doc stale → fix doc | docs/STATUS.md:46-47; BACKLOG.md:1074-1077; round36-plan.md:643-645 | "Second text review in progress" / "catalogue stale" — both landed (`6794af6e`, `1e8a975d`) |
| CTX-08 | Medium | Unclear/Agent-trap | unclear → Jan decides | AGENTS.md:151-152, 166, 197; BACKLOG.md:79-80, 85-94, WP24/WP32/WP41/WP50 rows; ROADMAP.md:161, 210, 228, 245 | GUI-acceptance state of Rounds 25–32 still "open/under way" though later rounds were played |
| CTX-09 | Medium | Bloat | doc stale → fix doc | AGENTS.md:65-271, 544-842; ROADMAP.md:144-303; BACKLOG.md:22-150; docs/STATUS.md (566 lines) | Round history is copied 4-5 times; AGENTS at 56 KB breaks documentation.md:20-21 |
| CTX-10 | Medium | Outdated / Agent-trap | doc stale → fix doc | AGENTS.md:227-283 | Historical lines read as current: "no remote push", "await GUI feedback. No Claude tasks", "Root Astra coordinates…", the "local-development Go" sentence, resource-root authority |
| CTX-11 | Medium | Missing | unclear → Jan decides | AGENTS.md (absent); ROADMAP.md:368 | Rules only in Claude memory: web-build particle budget, web build as target, faction-name / no-WoW rule, mapgen engine-run budget, review "happy path", alias/send-front engine traps |
| CTX-12 | Medium | Missing / Unclear | doc stale → fix doc | docs/technical/module-guide.md:1-1491; AGENTS.md:522-523, 555 | No mod ownership map; guide has no headings; grug_artisans/grug_trees absent; "one global per mod" vs `grug_items`/`grug_zones` |
| CTX-13 | Medium | Outdated | doc stale → fix doc | docs/maintenance/findings.md:13, 16, 18-23, 66-70; docs/README.md:10; docs/STATUS.md:502-503 | D2 and D4 are resolved in code; "approved-but-unimplemented" list and WP counts from before Rounds 27–36 |
| CTX-14 | Medium | Unclear/Agent-trap | unclear → Jan decides | docs/process/agent-model-policy.md:44-47, 69-87, 188-212, 280-292 | Defaults (Sol coordinates, cross-model review) and calibration records not followed for 13 rounds |
| CTX-15 | Low | Contradiction | doc stale → fix doc | CLAUDE.md:12; AGENTS.md:316-318; docs/README.md:7 | Three different "where is current status" entry points (ROADMAP / BACKLOG / STATUS) |
| CTX-16 | Low | Contradiction | doc stale → fix doc | AGENTS.md:391-392, 409-412, 448-451; docs/process/documentation.md:24-25; docs/README.md:12-13 | Binding Lua rules live in `docs/research/`, which the docs define as non-authoritative |
| CTX-17 | Low | Unclear | doc stale → fix doc | AGENTS.md:413-419 | Says sweeps are "scoped to `mods/*/grug_*`" so tools/ Lua needs explicit runs; check_lua.sh sweeps whatever files it is given |
| CTX-18 | Low | Wrong | doc stale → fix doc | AGENTS.md:593-598 | `r29_t` listed as `quest_targets.py`; the folder holds `test_quest_targets.py`, the tool is `tools/r28_regions/quest_targets.py` |
| CTX-19 | Low | Outdated | doc stale → fix doc | AGENTS.md:352, 478-480, 511, 862-863 | Small stale facts: future `games/<gameid>/` layout, "quality final runner", BASE as the only vendored modpack, "add CREDITS.md when…" |
| CTX-20 | Low | Outdated | doc stale → fix doc | docs/technical/upstream-workarounds.md:83-84 | Removal list names 4 fixtures stubbing `aim_raycast`; 7 do now (+r35_t, r36_e, r36_f, r36_f2) |
| CTX-21 | Low | Outdated | doc stale → fix doc | docs/reference_projects.md:88 | "mobs_redo … 32 GRUG PATCH sites"; VENDOR.md:531 and the tree count 135 |
| CTX-22 | Low | Outdated | doc stale → fix doc | minetest.conf (Pathfinding block header) | Points at `AGENTS.md "Mobs"` for the pathfinding-quality rule; it now lives in module-guide.md:482 |
| CTX-23 | Low | Contradiction / Bloat | doc stale → fix doc | ROADMAP.md:3 vs 144-303, 305-332 | "Not a chronological diary" header over a 160-line round diary; "Remaining work" holds `[x]` items and an unchecked note |
| CTX-24 | Medium | Bloat | doc stale → fix doc | BACKLOG.md:155-1077, 338-410 | "Phase 1 (MVP)" heading holds every round section; carry-over lists keep "Done" and fresh-server-moot items |
| CTX-25 | Low | Bloat | doc stale → fix doc | docs/maintenance/review.md, documentation-round.md; docs/STATUS.md:501-503, 514-522 | Closed 2026-09-23 consolidation records and old preparation receipts sit in living locations |
| CTX-26 | Low | Unclear | unclear → Jan decides | TODO-design-crafting-rework.md:1-48; TODO-design-nether.md:35-61 | Crafting TODO holds only an ocean-survival question; Nether TODO holds a "Decided" section against the TODO rule |
| CTX-27 | Low | Outdated | doc stale → fix doc | docs/design/README.md:29; docs/technical/module-guide.md:1189-1191 | "skill trees follow with WP11" (delivered); "§§7, 9, 14 describe the Round 22 target, not yet the code" (Round 22 shipped) |
| CTX-28 | Low | Wrong | doc stale → fix doc | docs/README.md:12 | "unresolved audit findings below" — nothing below |

Counts: High 2, Medium 13, Low 13 (after phase-2 verification; originally High 4, Medium 11).

## Details

### CTX-01 Round 36 is reported as not pushed

**Doc says:** AGENTS.md:67 "**Round 36 complete locally, 2026-10-05 (not
pushed).**". docs/STATUS.md:9 "not pushed". STATUS.md:505 "Round 35 is the
latest pushed state". STATUS.md:555-556 "Rounds 30–35 are pushed (origin/main
`7c4cad0a` …); Round 36 is local only". ROADMAP.md:301 "Local, not pushed".
BACKLOG.md:25 "not pushed". README.md:72 "complete locally". README.md:232
"Round 35 is the latest pushed state". round36-plan.md:4 and :628 say the same.
**Code/reality:** `git log origin/main..main` is empty. `git reflog
refs/remotes/origin/main` shows `1e8a975d … 2026-10-05 18:47:21 update by
push` and `0f169898 … 21:19:04 update by push`. Claude's auto-memory
(`project-state.md`) has the same stale claim.
**Impact:** an agent may "push Round 36", hold back work as "unpushed", or
tell Jan wrong facts. Seven files repeat the same status, so they will drift
again.
**Suggested fix:** mark Round 36 as pushed (`0f169898`) in all seven places
and update the memory. Structurally, keep the push and acceptance state in
**one** place (STATUS.md) and have the others link to it (see Proposed
structure).
- **Verification (phase 2):** Confirmed, severity changed to Medium — every listed location holds (AGENTS.md:67, docs/STATUS.md:9/505/556, ROADMAP.md:301, BACKLOG.md:25, README.md:72/232, round36-plan.md:4/628), plus docs/STATUS.md:5 "delivered locally"; `git log origin/main..main` is empty and the origin/main reflog shows pushes 1e8a975d (18:47) and 0f169898 (21:19). Medium, not High: `git status` refutes the claim at once and a repeated push is a no-op, so the harm is wrong status talk, not wrong work.

### CTX-02 Parallel-interpreter cap: seven or eight

**Doc says:** AGENTS.md:431-443: "at most seven independent LuaJIT or PUC 5.1
processes may run concurrently … Historical records of eight-worker WP40
measurements … do not authorize an eighth process now. A rerun obeys the
current seven-process cap". wp-workflow.md:76-78 points to "the workstation-
wide parallel-execution cap in AGENTS.md".
**Code/reality:** AGENTS.md:897 itself: the seed fleet runs "8 in parallel".
`tools/seed_fleet/run.sh:9,18` defaults to `JOBS=8`. tools/README.md:30 says
"eight at a time". docs/design/spawn_regions.md:386 says "up to eight
processes". Claude's memory (`parallel-lua-runs.md`) records Jan's ruling of
up to 8 (8 physical cores).
**Impact:** a reviewer following AGENTS literally flags every seed-fleet run as
a rule violation. An implementer may also throttle to 7 while another agent
runs 8, so the combined load exceeds both rules.
**Suggested fix:** replace AGENTS.md:431-443 with one sentence: "At most 8 Lua
interpreter processes across all agents, under `chrt --idle 0`/`ionice -c3`,
each with its own output; never a wall-clock kill." Delete the
eighth-process history (CTX-09). Update wp-workflow.md:76-78 to match.
- **Verification (phase 2):** Confirmed, severity changed to Medium — AGENTS.md:431-443 (seven, "do not authorize an eighth") vs AGENTS.md:897 ("8 in parallel"), tools/seed_fleet/run.sh:9,18 (`JOBS` default 8), tools/README.md:30, spawn_regions.md:386 and round28-questing-leveling-plan.md:715 ("at most eight"). Medium: one process either way changes nothing on an 8-core idle-scheduled fleet; the cost is a spurious review flag.

### CTX-03 PUC final micro-KAT: mandatory, optional or retired?

**Doc says:** AGENTS.md:422-430: for all non-mapgen work, "On frozen final
bytes, run one compact PUC-5.1 micro-KAT process and the same fixture once
under LuaJIT, requiring a byte-identical canonical digest". AGENTS.md:452-457:
a plan without this is "a planning defect". wp-workflow.md:62-71 (step 4) and
88-94 (step 5) say the same, as does luanti-lua.md:7-16.
**Code/reality:**
- BACKLOG.md:1286-1299 and ROADMAP.md:331-337 (audit E9): "The PUC Lua 5.1
  run is **optional** … at most one crash smoke test".
  wp-audit-2026-09-29.md:561 cites R22 §5: "Dropped: KATs, digests … PUC
  parity".
- No tool exists. `tools/wp40/quality/` holds only `build_gravewood.py`, and
  cross-cli-orchestration.md:243 confirms `final_micro.sh` was retired in
  Round 22. The only `micro.lua` files (`tools/r23_full_column`,
  `tools/r24_fill`) are LuaJIT fixtures run by `run_fixtures.sh`.
- The Round 30–36 completions record no PUC run. round36-plan.md §6 lists
  fixtures, `check_fresh_server.py`, a smoke boot and the seed fleet.
- Claude's memory records Jan's ruling to ignore PUC during development.
**Impact:** a strict agent schedules a PUC run with no harness, or rejects a
lane. A careful planner wastes time reconciling three rules. Opposite rules
both carry "binding" wording.
**Suggested fix (Jan decides):** most likely the rule becomes: "Plain-5.1
*syntax* stays a hard rule (`check_lua.sh`); no PUC runtime runs during
development; one optional PUC crash smoke test before a public release." Then
delete AGENTS.md:420-457 except the syntax rule, wp-workflow steps 4/5's KAT
sentences and the luanti-lua.md planning note.
- **Verification (phase 2):** Confirmed — AGENTS.md:420-457 exempts only mapgen and still requires a final PUC micro-KAT for all other work ("planning defect" otherwise), as do wp-workflow.md:66-71/88-94 and luanti-lua.md:7-16; against that BACKLOG.md:1287-1288/1297-1299, ROADMAP.md:339-341, round22-natural-world-plan.md:130/315 and round29-plan.md:127 ("PUC ignored during development") make it optional, no micro-KAT tool exists (only build_gravewood.py in tools/wp40/quality/), and the last PUC run recorded is the Round 22 crash smoke (round22-natural-world-plan.md:1270). High stays: binding wording in the entry document every lane brief reads.

### CTX-04 The documented workflow is not the one in use

**Doc says:** AGENTS.md:316-323: "Session start: read BACKLOG.md, pick the
next open WP … One WP per session is the norm … WPs run autonomously on their
own branch (`wp<NN>-<slug>`)". wp-workflow.md:47-48 (step 2) is the same, and
step 1 calls the BACKLOG row "the acceptance contract".
**Code/reality:** the last `wp<NN>` merges are on 2026-09-20
(`wp11-r11-integration`). Every merge since then is `r<NN>-<lane>`
(`git log --merges`: r36-f, r36-e, … r36-rd). Rounds are planned with Jan in
`docs/planning/roundNN-plan.md` with lanes and waves. Each plan's §7
"Orchestration notes" (round36-plan.md:511-520) holds the real mechanics:
worktrees in `.claude/worktrees/r36-<lane>`, `tools/bin/` copied in, briefs
from `~/projects/grudgelands-orchestration/r35/common-brief.md`,
`run_astra.sh 36 <lane>`, log in `r28/HANDOVER.md`. None of this is in the
repo, although AGENTS.md:287 says "All durable project state belongs in the
repo" and :343-344 says "Anything future sessions need to know goes into
AGENTS.md/docs".
**Impact:** a fresh agent (or Codex) following AGENTS picks "the next open WP"
from BACKLOG (only WP34/42/46/48 remain, all deferred) and opens a
`wp34-…` branch, or cannot reconstruct how a round runs.
**Suggested fix:** rewrite wp-workflow.md as "Round workflow". Cover: plan
with Jan → lanes and waves → branch `r<NN>-<lane>` in a worktree (copy
`tools/bin/`) → lane gates (CTX-05) → independent review → merge → round-end
gates → D lane updates status docs → Jan's GUI test. Move the common brief and
review template from the orchestration folder into `docs/process/` (or say
explicitly that they are private, with what they contain). Reduce AGENTS.md
"Working method" to five lines pointing there.
- **Verification (phase 2):** Confirmed — AGENTS.md:316-326 and wp-workflow.md:39-48 prescribe "pick the next open WP", "one WP per session" and `wp<NN>-<slug>`; the last `wp*` branch merges are 2026-09-20 (`wp29-r11-art` etc. into `wp11-r11-integration`) and every later merge is `r<NN>-<lane>`; round36-plan.md:511-520 points to briefs, `run_astra.sh` and HANDOVER under ~/projects/grudgelands-orchestration, outside the repo, against AGENTS.md:286 "All durable project state belongs in the repo".

### CTX-05 Lane and round-end gates are not documented in one place

**Doc says:** AGENTS.md lists `check_lua.sh`, `run_fixtures.sh` and the seed
fleet in different sections. `check_fresh_server.py`, `validate.py --game`
(only as a quest check at :585) and a smoke boot are not presented as gates;
`check_fresh_server.py` appears 0 times. cross-cli-orchestration.md:233-245
§2.6 "Round-end engine validation" describes capital and start checks with
retired tools.
**Code/reality:** round36-plan.md:465-479 (§5 "As Round 35", §6): "Each code
lane: its fixture and `tools/run_fixtures.sh`, `python3
tools/check_fresh_server.py`, one smoke boot, an independent Opus review …
Lane W: `seed_fleet quick`. End: `seed_fleet full`, one boot of main,
`tools/sync_to_luanti.sh`". The completion (round36-plan.md:635-640) also ran
`validate.py --game` and `income.py --check`.
**Impact:** the gate set lives only in round plans, which the docs call
historical once a round closes, and is copied forward "as Round 35".
**Suggested fix:** add a short "Gates" table to the new round workflow
(CTX-04) with columns per Lua change / per lane / round end / docs-only.
Replace cross-cli §2.6 with a pointer to it.

### CTX-06 Four Round 36 lanes are missing from the status documents

**Doc says:** round36-plan.md "Completion" and STATUS/BACKLOG/ROADMAP/AGENTS
describe lanes S, E, R, P, K, F, G, Q0, Q-A, Q-T, T, A, W and D.
AGENTS.md:831-842 lists the Round 36 tool folders without `r36_f2`, `r36_w2`
and `r36_w3`.
**Code/reality:** merged after the D lane (`25f686ff`, 18:23):
- `4b224ccd` r36-f2: held LMB survives a hotbar switch.
- `4b53dec8` r36-w2: bench facing.
- `9883782a` r36-w3: ground cover in the treeless band round start towns
  and capitals; touches `simple_map.lua`, `r6_planner.lua`,
  `capital_protection.lua`.
- `fef94a6a` r36-rd: road `C_STEP` 0.05 → 0.5.
Design docs and the module guide were updated for F2/W2 only. W3 and RD
change terrain and placement, which under AGENTS.md:899-906 need a seed-fleet
run.
**Impact:** the GUI test checklist misses the hotbar-hold, bench, ground-cover
and road changes. An agent cannot tell whether `seed_fleet full` ran after W3
and RD.
**Suggested fix:** add a "Follow-up lanes (2026-10-05 evening)" block to the
round36-plan completion, STATUS and BACKLOG Round 36, plus GUI-checklist
items. Add `f2`, `w2` and `w3` to the AGENTS Round 36 tool list (or drop the
list, see CTX-09). Record the seed-fleet result.
- **Verification (phase 2):** Confirmed — merges 4b224ccd (f2, 20:28), 4b53dec8 (w2), 9883782a (w3), fef94a6a (rd, 21:06) all follow the D lane 25f686ff (18:23); no status doc or the AGENTS tool list (AGENTS.md:831-842) names f2/w2/w3/rd though tools/r36_f2, r36_w2, r36_w3 exist, and no commit body records a seed fleet. Refinement: the private log does record it (~/projects/grudgelands-orchestration/r28/HANDOVER.md:1192 W3 quick 100/100, :1206 RD quick 100/100), but the last `full` (303/303, :1169) ran on 25f686ff before W3/RD, so under AGENTS.md:905-906 a round-end `full` is still owed.

### CTX-07 "In progress" items that already landed

**Doc says:** STATUS.md:46-47 and round36-plan.md:643-645: "A second text
review … is in progress". BACKLOG.md:1074-1077: the generated catalogue
"makes them stale again until the next dump".
**Code/reality:** `6794af6e` "Quest text review round 2: Opus's 136
suggestions … all accepted" and `1e8a975d` "Item and quest catalogue
regenerated after the text review round 2".
**Suggested fix:** mark both as done with the commit ids. Drop the carry-over.

### CTX-08 GUI-acceptance status of Rounds 25–32

**Doc says:** AGENTS.md:166 (R30) "Next: fresh world and GUI test (still
open)" and :151-152 (R31) "Round 30's is still open". BACKLOG.md:85, 94: "GUI
test open/still open" for R30–R32. WP24 row: "User playtest under way"
(since 2026-09-29). WP32, WP41, WP50: "GUI acceptance pending" or "Playtest
pending". ROADMAP "Next: short playtest" (R27) and others. STATUS.md:509:
"Round 24 the latest formally accepted one".
**Code/reality:** the docs themselves say Jan tested Round 33 ("findings fed
Round 34"), 34 and 35. Each later build contains R25–R32.
**Impact:** agents cannot tell which acceptance tests are still owed. Old
"Next:" lines create phantom open work.
**Suggested fix (Jan decides):** one acceptance table in STATUS (round →
tested on/by → open items). Delete the per-round "Next:" lines everywhere
else.

### CTX-09 AGENTS.md size and the copied round history

**Doc says:** documentation.md:20-21: "AGENTS.md / docs/process/: working
instructions and gates. Module details belong in technical references, not
an ever-growing mandatory startup file."
**Code/reality:**
- AGENTS.md is 910 lines and 56,485 bytes (about 14k tokens) and is loaded
  into every agent.
- Lines 65-271 (207 lines) are round summaries R20–R36. The same summaries
  appear in STATUS.md:5-500, ROADMAP.md:144-303, BACKLOG.md:22-150 and
  README.md:65-240.
- Lines 544-842 (299 lines) are "since Round NN" sections. Their conventions
  are valuable. About a third, however, are lane-folder inventories
  (`tools/r31_<lane>/` (`pvp` …, `p2` …, …)) that belong in tools/README or
  the module guide.
- Lines 409-457 (49 lines) are mostly interpreter history (CTX-02/03).
**Impact:** every agent pays the context cost. Current rules are hidden
between delivery narratives, and stale lines (CTX-10) read as instructions.
**Suggested fix:** keep in AGENTS only the following:
- standing rulings (fresh-server, execution channel, repository sharing);
- a 3-line "current state" pointer to STATUS;
- the working method (pointer to the round workflow);
- Lua rules (condensed);
- project conventions;
- the conventions from each "since Round NN" section, stated as rules by
  topic (Zone data, Economy, Performance, PvP, Input, Items, Sound, Quests,
  Mapgen/decor) without the round label;
- testing.
Move the lane-folder inventories to tools/README.md. Delete the round history
(STATUS owns it). Target: under 400 lines.

### CTX-10 Historical lines in AGENTS that read as current instructions

**Doc says (examples):**
- AGENTS.md:233 "no remote push. Next: user preparation of a fresh
  production world".
- :243-244 "No remote push. Await user GUI acceptance."
- :251-252 "No implementation agent is still running; await user GUI
  feedback. No Claude tasks."
- :255-259 "Root Astra coordinates native Astra implementation/measurement
  and independent Sol review."
- :267-269 "The current local-development Go does not authorize a remote push
  or bypass a recorded automatic approval-review rejection."
- :273-283 "Current resource-root authority" (WP40 R6 SHA history).
- :475-480 "Mapgen integration boundaries … The quality final runner
  keeps …".
**Code/reality:** all of Rounds 20–36 are on origin/main. Claude coordinates.
The "quality final runner" is retired (CTX-19).
**Impact:** an agent reading top-down sees "No Claude tasks", "Root Astra
coordinates" and "does not authorize a remote push" as standing rules.
**Suggested fix:** delete these blocks. The two still-valid mapgen facts
(world_zones.md §11 is the root-selection rule; the `r7_manifest.new` /
`planner.plan_slice` boundary) belong in the module guide's mapgen section.

### CTX-11 Rules that exist only in Claude's private memory

**Doc says:**
- AGENTS.md is silent on the particle budget. ROADMAP.md:368 mentions
  "particles within the web budget", but no repo doc defines that budget.
- The web build appears only as a test target (AGENTS.md:79; BACKLOG.md:1119).
- The faction-name / no-WoW rule appears only in round36-plan.md:469-470.
  AGENTS.md:870-872 has only the generic IP rule.
**Code/reality (memory files, user rulings):**
- `particle-budget-web.md` (2026-09-19: hundreds of particles, never
  thousands; the web build is a target system).
- `faction-names-no-wow.md` (2026-10-03).
- `mapgen-test-run-budget.md` (2026-09-28: a few engine runs ≤ ~5 min, no
  full-world runs, the reviewer does not rerun).
- `review-scope-happy-path.md` (2026-09-18: no fix rounds against
  hypothetical foreign-mod conflicts).
- `luanti-node-alias-trap.md` (`pairs(core.registered_nodes)` skips aliases;
  `default:goldblock` is one).
- `luanti-send-front-stall.md` (lowering `max_block_generate_distance`
  freezes loading).
**Impact:** Codex/Astra lanes, Claude CLI reviewers and any fresh context
without this memory can break these rules. Reviewers cannot check them.
**Suggested fix (Jan decides which are project rules):**
- Into AGENTS: particle budget, web-build target, faction names, mapgen
  run budget.
- Into wp-workflow (review checklist): review scope.
- Into docs/research/luanti-lua.md or the module guide: the two engine traps.

### CTX-12 No mod ownership map; module guide cannot be navigated

**Doc says:** module-guide.md:3-4: "Read only the relevant module section."
AGENTS.md:846-848: "Read the relevant section … when touching a module."
**Code/reality:**
- module-guide.md has exactly one heading (`# Module implementation guide`).
  The rest is about 40 top-level bullets. "Combat/classes" runs from line 190
  to 472, and "Mobs" from 473 to 640.
- `grug_artisans` (Woodcarver/Goldsmith catalogs) and `grug_trees` (race
  trees) are mentioned 0 times. Several ITEMS mods only once.
- AGENTS.md:522 says "Exactly one global table per mod (`grug_xp = {}`)", but
  `grug_quality` publishes `grug_items` (grug_quality/init.lua:24) and
  `grug_core` publishes `grug_zones` (grug_core/zone_authority.lua:391).
  AGENTS.md:555 "served by `grug_zones`" reads like a mod name.
**Impact:** agents grep instead of reading. A brief writer cannot find the
owning mod for a concern. The global-table rule looks broken to a reviewer.
**Suggested fix:**
- Add a table at the top of the module guide (or a new
  `docs/technical/mod-map.md`): mod → modpack → owns → global(s) → key
  files → design doc. Include the two documented exceptions (`grug_items`,
  `grug_zones`).
- Turn each top-level bullet into a `##` heading so sections can be linked.
- Add short entries for `grug_artisans`, `grug_trees` and the other
  one-mention ITEMS mods.

### CTX-13 findings.md is stale

**Doc says:**
- findings.md:13 D2: "Profession books should show higher-tier recipes
  greyed, but runtime omits them".
- :16 D4: "Still open: `view_range` is 20 against a target of 40".
- :18-23: "Existing approved-but-unimplemented systems remain in BACKLOG: WP44
  economy (current 25% versus target 5% buy-back) … boats and waypoints,
  geographic PvP, the level-41–60 story".
- :66-70: "39 delivered, 3 canceled, 12 open of 54".
**Code/reality:**
- `grug_jobs/ui.lua:292` lists "locked recipes included (greyed)" and
  :601-619 has the lock line (since `01700592`, Round 28 A6).
- `grug_mobs/kraken.lua:78` has `view_range = 40` (`38d9764a`, Round 29).
- WP44, WP17, WP41 and WP9 were delivered in Rounds 29, 31 and 36.
- BACKLOG counts 47/3/4.
- A stale comment remains in `grug_mobs/aggro.lua:126` ("its view_range is
  20"), for the code lanes.
**Impact:** docs/README.md:10 and STATUS.md:502-503 send agents here for
"remaining decisions and code/design discrepancies". They find closed items.
**Suggested fix:** close D2 and D4 with the commits. Delete the
"approved-but-unimplemented" paragraph and the README handoff, or archive
findings.md and let BACKLOG own the open discrepancies.

### CTX-14 Model policy defaults and calibration are not what is practised

**Doc says:**
- agent-model-policy.md:44-47 and §2.1: Sol is "the default long-lived
  project coordinator", and "A different project coordinator is an explicit
  user decision".
- §3 table: "Independent review of Opus implementation | Prefer Sol".
- §5: cross-model review is "the default preference".
- §7:282-292: each reviewed package records implementing/reviewing model,
  Critical/High count, fix-round count and wall time.
**Code/reality:**
- Rounds 24–36: Claude coordinates, Opus implements and Opus reviews, and
  Astra does art and texts (round36-plan.md:625-635; Claude memory
  `model-routing-user-daily.md`).
- Round completions record verdicts ("MERGE AFTER FIXES") but not Critical/High
  counts, fix rounds or time.
- The last calibration entry is 2026-10-01 (the Astra amendment). The policy
  asks for calibration "after roughly every six to ten" packages.
- cross-cli-orchestration.md:20-23 lists newer Sol slugs (`gpt-6.1-sol`),
  while the policy still names "GPT-5.6 Sol".
**Impact:** the per-session override clause makes this legal. But a Codex
coordinator, or a fresh Claude, reading the policy will route the opposite
way from what Jan runs every day. The calibration duty is silently skipped.
**Suggested fix (Jan decides):** either update the defaults to the current
practice (Claude coordinates, Opus implements and reviews, Astra for art and
texts, Sol on request) and drop or simplify §7, or keep the policy and add the
four calibration fields to the round completion template.

### CTX-15 Three entry points for "current status"

**Doc says:** CLAUDE.md:12 "Project goals and current status:
**[ROADMAP.md]**". AGENTS.md:316 "Session start: read BACKLOG.md".
docs/README.md:7 "What is the current game delivery? | [Project status]
(STATUS.md)".
**Suggested fix:** CLAUDE.md → "Current status: docs/STATUS.md; goals:
ROADMAP.md". AGENTS session start → STATUS, then the current round plan.

### CTX-16 Binding Lua rules live in a "research" folder

**Doc says:** AGENTS.md:391-392, 409-412 and 448-451 make
`docs/research/luanti-lua.md` binding (the do-not-write list, sweeps,
"Interpreter and test strategy"). documentation.md:24-25: "`docs/research/`
and `docs/archive/`: research, decision provenance and historic … may remain
useful without being authority". docs/README.md:12-13: "Research is not a
second mandatory specification".
**Suggested fix:** move it to `docs/technical/luanti-lua.md` (it is a
technical reference) and leave a stub. Update about 10 incoming links.

### CTX-17 Sweep scope wording in AGENTS

**Doc says:** AGENTS.md:413-416: "They are scoped to `mods/*/grug_*`, so Lua
under `tools/` is **not** covered by them and needs the check run explicitly.
And the harness scripts that run them require ripgrep: until 2026-08-15 a
missing `rg` made nine of them report success without running".
**Code/reality:** `tools/check_lua.sh:66-110` applies sweeps 1–5 to every
file passed. The `mods/*/grug_*` scope applies only to the hand-run grep form
(luanti-lua.md:368-381). The script fails fast without `rg` (line 3). The
"nine harness scripts" are retired.
**Suggested fix:** "Run `bash tools/check_lua.sh <files>` from the repo root
on every changed Lua file, including Lua under `tools/`; it needs ripgrep."

### CTX-18 Wrong tool attribution for r29_t

**Doc says:** AGENTS.md:597-598: "`t` `quest_targets.py`".
**Code/reality:** `tools/r29_t/` contains only `test_quest_targets.py`. The
tool is `tools/r28_regions/quest_targets.py` (AGENTS.md:557-558 has that
right).
**Suggested fix:** "`t` the tests of `quest_targets.py`", or drop it with the
lane inventories (CTX-09).

### CTX-19 Small stale facts in AGENTS

- AGENTS.md:351-352: "The game will eventually live in a layout like
  `games/<gameid>/`". The repo root is the game (`game.conf`, `menu/`, `mods/`,
  `settingtypes.txt` at the root; `sync_to_luanti.sh` copies it to
  `games/grudgelands`).
- AGENTS.md:478-480: "The quality final runner keeps real MTS/roster
  construction under LuaJIT and … the portable final micro-KAT". There is no
  such runner (`tools/wp40/quality/` = `build_gravewood.py`).
- AGENTS.md:511: "`BASE/` (vendored upstream mods)". `ENTITIES/mobs`
  (mobs_redo) is vendored too (VENDOR.md:531).
- AGENTS.md:862-863: "When we accumulate more sources, add a top-level
  `CREDITS.md`". It exists since Round 34 (`8a8c7a4d`) and AGENTS.md:740
  already uses it.
**Suggested fix:** reword or delete each line.

### CTX-20 Upstream-workaround removal list is incomplete

**Doc says:** upstream-workarounds.md:83-84: "drop … the `aim_raycast` stubs
in `tools/r28_a4`, `tools/r30_p4`, `tools/r31_pvp` and `tools/r32_f2`".
**Code/reality:** `grep -l aim_raycast tools/*/portable_test.lua` also finds
`r35_t`, `r36_e`, `r36_f` and `r36_f2`. The rest of the file matches the code:
`combat_ray.lua:292`, the four call sites, `minetest.conf:28`,
`mapgen_manifest.lua:42`.
**Suggested fix:** list all fixtures, or say "every fixture that stubs
`grug_core.aim_raycast` (`grep -l aim_raycast tools/*/portable_test.lua`)".

### CTX-21 reference_projects.md GRUG PATCH count

**Doc says:** docs/reference_projects.md:88: "`mods/ENTITIES/mobs`, 32 GRUG
PATCH sites".
**Code/reality:** 135 markers (`grep -rc 'GRUG PATCH' mods/ENTITIES/mobs`),
matching VENDOR.md:531 ("135 … counted 2026-10-04").
**Suggested fix:** "dozens of GRUG PATCH sites (count in VENDOR.md)".

### CTX-22 minetest.conf pointer to a removed AGENTS section

**Doc says:** `minetest.conf`, Pathfinding block: "## Pathfinding (AGENTS.md
"Mobs": pathfinding is a QUALITY criterion …".
**Code/reality:** AGENTS has no such rule. It lives in module-guide.md:482.
**Suggested fix:** point the comment at `docs/technical/module-guide.md`
("Mobs").

### CTX-23 ROADMAP contradicts its own purpose

**Doc says:** ROADMAP.md:3 "Goals and remaining milestones, not a
chronological implementation diary".
**Code/reality:** ROADMAP.md:144-303 is a round-by-round diary from Round 25
to Round 36. "Remaining work" (305-332) contains `[x]` WP9 and WP13 and an
unchecked Round 34 note.
**Suggested fix:** collapse "Delivered foundation" into about 10 capability
bullets (no round narratives; link STATUS). Keep only open items under
"Remaining work".

### CTX-24 BACKLOG structure and done carry-overs

**Doc says:** BACKLOG.md:155 `## Phase 1 (MVP)` contains the WP table and
then every "Round NN — …" and "Round NN carry-overs" section down to :1077.
The "Readiness" section (22-150) is another round diary.
**Code/reality:**
- Carry-over lists keep items marked "**Done in Round 26 Lane S**" or "**Done
  in Round 29**" (BACKLOG.md:355-374).
- Some items are moot under fresh-server mode (BACKLOG.md:347-348: tooltip
  "does not relabel tool stacks from older worlds").
- The Round 30–36 "— <title>" sections repeat each plan's completion.
**Impact:** 1,315 lines. Open work is scattered over 13 carry-over sections.
**Suggested fix:** BACKLOG = WP table + one "Open carry-overs" list grouped by
area (with source round) + release gates. Delete done and moot items. The
round sections move to (or already exist in) the plan completions.

### CTX-25 Closed records in living locations

**Doc says:** docs/maintenance/review.md and documentation-round.md (both
2026-09-23) and STATUS.md:501-503 and 514-522 (documentation consolidation,
preparation performance follow-up).
**Suggested fix:** move both maintenance records to `docs/archive/` and drop
the two STATUS bullets (or reduce them to one "older receipts" link line).
findings.md: see CTX-13.

### CTX-26 TODO files

**Doc says:** TODO-design-crafting-rework.md is titled "Crafting rework", but
"Group: **D** ocean survival" with only D18 (swimmer exhaustion, deferred) is
left. TODO-design-nether.md:35-61 has "## Decided 2026-08-06 (design
review)". AGENTS.md:292-295 and documentation.md:13-14 say a TODO holds only
open questions and decided parts fold into `docs/design/`.
**Suggested fix (Jan decides):** rename to `TODO-design-ocean-survival.md` (or
fold D18 into BACKLOG as a deferred note and delete the file). For the Nether,
either accept "V2 design draft" as a TODO exception (say so in AGENTS) or
move the decided part into a `docs/design/nether.md` labelled "V2, not
implemented".

### CTX-27 Two stale status phrases in the design index and module guide

- docs/design/README.md:29 (classes.md): "skill trees follow with WP11". WP11
  was delivered (BACKLOG WP11 row).
- module-guide.md:1189-1191: "`world_zones.md` §§8–14 (with §§7, 9 and 14
  describing the Round 22 target, not yet the code)". Round 22 was merged on
  2026-09-25 (`651e45e2`). Whether the phrase is still true belongs to the
  mapgen doc lane. As written, it is very likely stale.
**Suggested fix:** drop "follow with WP11". Re-check and drop or date the
"not yet the code" clause.

### CTX-28 docs/README points to a missing section

**Doc says:** docs/README.md:12: "Root `TODO-*.md` files; unresolved audit
findings below".
**Code/reality:** the file has no findings section.
**Suggested fix:** link `maintenance/findings.md` (if kept) or BACKLOG
carry-overs.

## Proposed structure changes

1. **Single owner per fact:**

   | Fact | Owner | Others |
   |---|---|---|
   | Push / acceptance / GUI-test state per round | `docs/STATUS.md` (one table) | link only |
   | What a round shipped (narrative) | `docs/planning/roundNN-plan.md#completion` | STATUS: 3–5 lines per round, last 3 rounds; older rounds one link line |
   | Open work | BACKLOG (WP table + one carry-over list) | ROADMAP links |
   | Goals / milestones | ROADMAP (no diary) | — |
   | Working rules and conventions | AGENTS (≤ 400 lines) | — |
   | Round workflow and gates | `docs/process/round-workflow.md` (replacing wp-workflow.md) | AGENTS 5-line pointer |
   | Lane tool folders | `tools/README.md` | — |
   | Mod ownership | module guide header table or `docs/technical/mod-map.md` | — |
   | Lua/engine rules | `docs/technical/luanti-lua.md` (moved from research) | — |

2. **AGENTS.md diet:** delete lines 65-283 except a 3-line pointer. Condense
   409-457 to the decided interpreter rule (CTX-02/03). Rewrite 544-842 as
   topic sections without round labels and without lane inventories.
   Estimated result: 350–400 lines (about −55 %).
3. **Bring the orchestration templates into the repo** (common brief, review
   brief, Astra launcher usage) or document in `docs/process/` what lives
   outside and why.
4. **Archive** `docs/maintenance/review.md`, `documentation-round.md` and,
   after CTX-13, `findings.md`. Archive the closed BACKLOG "Round NN —"
   sections, which duplicate the plan completions.
5. **Add to the D-lane checklist** (round plan §4.x D): STATUS push line, AGENTS
   pointer, ROADMAP, BACKLOG, README, and any lane merged after the D lane.
   CTX-01 and CTX-06 happened because the D lane ran before the last merges
   and the push.

## Open questions for Jan

1. **Parallel cap:** 8 Lua processes workstation-wide (as the seed fleet and
   your 2026-08 ruling in memory), or 7 (AGENTS)? (CTX-02)
2. **PUC:** is the per-package PUC/LuaJIT micro-KAT abolished for all work,
   leaving only the optional pre-release crash smoke test? (CTX-03)
3. **Routing defaults:** should agent-model-policy.md reflect today's practice
   (Claude coordinates, Opus implements and reviews, Astra art and texts),
   and do you still want the §7 calibration records? (CTX-14)
4. **Memory-only rules:** which become repo rules: particle budget and web
   target, faction names / no WoW, mapgen engine-run budget, review "happy
   path", the two engine traps? (CTX-11)
5. **Acceptance:** which rounds count as GUI-accepted (R25–R33)? Is anything
   from R30–R32 still owed? (CTX-08)
6. **Round 36 follow-ups:** did `seed_fleet full` run after W3 (ground cover)
   and RD (roads), which both change terrain/placement? Should F2, W2, W3 and
   RD join the Round 36 GUI checklist? (CTX-06)
7. **Orchestration folder:** should the common brief, review template and
   `run_astra.sh` move into the repo, or stay private by design? (CTX-04)
8. **TODO files:** rename or retire the crafting TODO (only D18 left), and
   where do the decided Nether rules live? (CTX-26)
9. **Upstream issue:** has the rotated-selection-box issue been filed? The
   entry still says "to be filed by the user". (upstream-workarounds.md §1)
