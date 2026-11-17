# DP1 — Top-level and process documents, and the October audit's open items

- Finder model: claude-opus-5-5
- Files read in full: 17 of 21 (AGENTS.md, CLAUDE.md, README.md, ROADMAP.md, BACKLOG.md, docs/STATUS.md, docs/README.md, docs/process/{agent-model-policy,checks,documentation,round-workflow}.md, docs/process/templates/{common-brief,review-common}.md, TODO-design-nether.md, game.conf, docs/audit-2026-10/README.md, docs/audit-2026-10/code/00-summary.md); skimmed: CHANGELOG.md (header and entries 0.76.0–0.80.1 read, older entries not), VENDOR.md (header, rules, the row table; patch sections not), CREDITS.md (music and the headings), tools/README.md (entry points read, the 1,500-line lane-folder list checked by grep only), docs/process/cross-cli-orchestration.md, docs/process/templates/*.sh, docs/maintenance/*.md, docs/audit-2026-10/docs/00-summary.md (index table), settingtypes.txt (headings and setting names); not reached: none
- Summary: The top-level documents are in good shape where they can be checked mechanically: `game.conf`, CHANGELOG's first heading, STATUS and `tools/web_data/upgrade.json` all say 0.80.1; every relative link and anchor in the package's files resolves (about 520 links, checked with a GitHub-slug resolver); every tool, script and flag that AGENTS.md, round-workflow.md and checks.md name exists; README's sampled feature numbers (393 quests, mount levels and speeds, Claim Stone level, five queued jobs, death wear 10 %, the 30 s PvP exemption, the setting defaults) match the code; STATUS is 2,770 bytes with five rows. The real problems are about reproducibility outside the user's workstation: the round tags `round-72.1` … `round-76.2` and the lane commits the Round 73–76 plans cite exist only on that workstation (this audit's checkout is a fresh clone and cannot resolve them), and the process documents hard-code `~/projects/grudgelands` and a private orchestration folder as if every checkout had them. Smaller items: README's "next" paragraph still announces the accounts phase 2 it already describes as shipped, ROADMAP annotates delivered versions, VENDOR.md counts nine reference checkouts (there are 14), tools/README lacks every Round 75 folder, and several October-audit Medium findings are still open in code but tracked nowhere.

## Findings

### DP1-01 | Medium | docs | The round tags 72.1–76.2 and the hashes the Round 73–76 plans cite exist only on the workstation

- **Where:** `docs/process/round-workflow.md:97-100`; `AGENTS.md:158-164`; `docs/planning/docs-cleanup-plan.md:140-142`; the cited hashes in `docs/planning/round73-plan.md`, `round74-plan.md`, `round75-plan.md`, `round76-plan.md:272-299`; `docs/STATUS.md:38-39` (rows linking those Completions)
- **What:** The workflow says the tag "keeps the detailed history and the hashes plans and reports cite" (round-workflow:94-96, AGENTS:161-163), and accepts that "the older round tags `round-72.1` to `round-76.2` stay local" (round-workflow:99-100). Since main receives one squash commit per round, those 13 tags are the only refs to the lane commits; a clone of `origin` (this audit's checkout, cloned 2026-11-17) has none of them, so the Completion sections of Rounds 72.1–76.2 cite commits that no other machine can resolve, and the history has a single copy.
- **Evidence:** `git tag -l` → `archive/wp40-mapgen-throughput round-78 round-79 round-80 round-80.1 v0.68.0`; `git reflog main` → `clone: from https://github.com/Kaesual/grudgelands.git`. Hashes in backticks that do not resolve (`git cat-file -e`): round73-plan 22 of 23, round74-plan 14 of 15, round75-plan 4 of 6; round76-plan:272 `16a93af3`, :279 `0d85b01c`, :281 `b32ef5e4` → "Not a valid object name". round72-plan: 0 of 49 missing (pre-squash era). docs-cleanup-plan:140-142 records the 13 tags as existing "only locally" and "Pushing them is the user's".
- **Proposal:** The user pushes the 13 tags (the plan already names this as the user's step); then round-workflow:99-100 drops the "stay local" clause. If they are not to be pushed, round-workflow says plainly that the cited hashes of Rounds 72.1–76.2 resolve only on the workstation clone, and no further round leaves its tag unpushed.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high (that the tags and objects are absent from a clone); medium (that they still exist on the workstation; not checkable from here)

### DP1-02 | Medium | docs | Process rules hard-code the workstation's paths; a fresh checkout has neither the repository path nor the orchestration folder

- **Where:** `AGENTS.md:241-242` (the one shared queue), `docs/process/checks.md:11-12`, `docs/process/round-workflow.md:58-62,405-409`, `docs/process/documentation.md:88-93` (cold storage), `docs/process/cross-cli-orchestration.md:21,89`, `docs/process/templates/common-brief.md:27,121,129,137,149`, `templates/review-common.md:9-11,18,31,50,71`, `templates/lane_merge.sh:13`, `templates/run_astra.sh:15-16`, `templates/engine_run.sh:3,8`, `templates/lua_run.sh:4,10`
- **What:** The 8-process cap is enforced only through `~/projects/grudgelands-orchestration/r45/lua_run.sh`; AGENTS.md states it as the mechanism every agent uses but never says the folder is workstation-local or how to install the queue elsewhere (only the template's comment "A fresh install keeps its locks beside the copy", lua_run.sh:6). The templates hard-code the repository at `/home/jan/projects/grudgelands` (review-common:9-11, common-brief:137, lane_merge.sh:13, cross-cli:89). On this audit machine the checkout is `/home/jan/grudgelands` and `/home/jan/projects` does not exist, so a brief instantiated from the templates points reviewers at a non-existent tree, and `lane_merge.sh` exits at its `cd`. round-workflow:58-59 does call the folder "private"; AGENTS.md and checks.md do not.
- **Evidence:** `ls -d /home/jan/projects/grudgelands /home/jan/projects/grudgelands-orchestration` → both "No such file or directory"; `git rev-parse --show-toplevel` of this checkout is `/home/jan/grudgelands`. `.gitignore` confirms `tools/bin/` is per checkout (built by `tools/build_lua51.sh`, documented in round-workflow:56-57), so that one is handled.
- **Proposal:** One sentence in AGENTS.md "Lua & Luanti environment" (and checks.md:11-12): the orchestration folder is the user's workstation folder; on another machine install `docs/process/templates/lua_run.sh` once and use that copy. In the templates replace the literal `/home/jan/projects/grudgelands` with a placeholder `<repo>` (or `${GRUG_REPO:-$(git rev-parse --show-toplevel)}` in the scripts, as run_astra.sh:15 already half does). Rules unchanged.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DP1-03 | Low | docs | README's "next" paragraph announces the accounts phase 2 that its own "Current state" calls shipped

- **Where:** `README.md:120-125` against `README.md:101-108` and `CHANGELOG.md:25-41`; `ROADMAP.md:25-29`
- **What:** "What I want to improve next: the second phase of website accounts, then …" (README:120) while README:101 says "**0.80.0** adds the second phase of website accounts". The "Current state" block also holds two version paragraphs (0.80.0 and 0.78.0, 0.79.0 absent), which the replace-not-extend rule (documentation.md:68-70, round-workflow:255-258) does not foresee.
- **Evidence:** README.md:101 and :120 quoted above; ROADMAP.md:25-26 "phase 2 … in 0.80.0".
- **Proposal:** Drop "the second phase of website accounts, then" from README:120 (ROADMAP:26-29 already names the next step: the end-to-end test and later phases); keep one current-state paragraph.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DP1-04 | Low | docs | ROADMAP annotates delivered versions instead of rewriting reached goals

- **Where:** `ROADMAP.md:25-26` ("Phase 1 shipped in 0.79.0, phase 2 … in 0.80.0"), `:35-36` ("The four-class rework has shipped"), `:42-43` ("First passes have shipped"), `:53-54` ("is complete from the start zones to the front"), `:189-190`, `:234-235`, `:240-242`; rule at `docs/process/round-workflow.md:272-273` and `docs/process/documentation.md:16-17,37`
- **What:** The round workflow says "ROADMAP holds goals and the next step; a reached goal is removed or rewritten, not annotated", and the owner table gives "what a round shipped" to CHANGELOG and the plan's Completion. ROADMAP carries version-level delivery records that CHANGELOG owns (0.79.0/0.80.0), which will drift on the next accounts round.
- **Evidence:** the quoted lines; CHANGELOG.md:25 and :61 own the same facts.
- **Proposal:** Rewrite the accounts bullet to its goal and next step without version numbers; leave "has shipped" sentences only where they frame the next step, without versions.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** medium (where "context for the next step" ends and "annotation" begins is a judgement)

### DP1-05 | Low | docs | VENDOR.md counts nine reference checkouts; there are 14 submodules

- **Where:** `VENDOR.md:12-17` ("plus the nine read-only checkouts in `reference_projects/`") against `.gitmodules` (14 `[submodule]` entries) and `docs/reference_projects.md:77` ("Three of the original nine")
- **What:** The count is stale since five further references were added (protector, draconis, goblins, x_farming, farming, character_anim are among the 14). reference_projects.md owns the list (documentation.md:53); VENDOR.md repeats a number of it.
- **Evidence:** `rg -c '^\[submodule' .gitmodules` → 14; `ls reference_projects` lists 14 folders. Related, outside this package: `docs/reference_projects.md:88` says the mobs fork has "32 GRUG PATCH sites" (the marker counts are E1-03).
- **Proposal:** "plus the read-only checkouts in `reference_projects/` ([list](docs/reference_projects.md))" without a number.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DP1-06 | Low | docs | tools/README.md, the owner of the fixture folders, lacks every Round 75 folder and the UI folders with fixtures

- **Where:** `tools/README.md:222-1725` ("Lane folders"); owner rule `docs/process/documentation.md:50`; brief rule `docs/process/templates/common-brief.md:72-73` ("A new tools folder gets one line in `tools/README.md`")
- **What:** Folders with a `portable_test.lua` that `run_fixtures.sh` runs have no line: `r75_art`, `r75_displays`, `r75_furnish`, `r75_5_architecture`, `ui_navigation`, `ui_window_cap`; without a fixture: `r75_city`, `r75_2_materials`, `ui_theme` (named in AGENTS.md:200 and checks.md:17), `ui_polish_review`, `map_icon_rework`, `branding`, and the architecture study folders. "Round 75" does not occur in tools/README at all.
- **Evidence:** for each name `rg -c -F <name> tools/README.md` → 0; `ls tools/r75_art/portable_test.lua tools/ui_navigation/portable_test.lua tools/ui_window_cap/portable_test.lua` exist.
- **Proposal:** One line per Round 75 lane folder and one per `ui_*` fixture folder; a short "Studies and generators" line for the non-round folders.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DP1-07 | Low | docs | October-audit Medium findings that are still open in code are tracked nowhere

- **Where:** `BACKLOG.md:106-121` ("Audit 2026-10 later fix packages") against `docs/audit-2026-10/README.md:171-175` ("Not done: P6 beyond MGT-02, P8, the MGT-03 tree fix and most Lows (BACKLOG …)")
- **What:** The audit README says the undone work lives in BACKLOG, but CORE-06 (status reads expire records and fire callbacks; unknown modifier keys refuse a status silently), PLY-08 (global monkeypatches depending on load order), ITM-05 (tool lifetimes in several tables, dead `uses`) and ITM-06 (ITEMS mods `dofile` grug_jobs files) appear in no BACKLOG line and no plan after Round 37; PLY-07 and PLY-09 are covered only by "and the other duplications" (BACKLOG:121). All six are still open in code (table in "Good to know").
- **Evidence:** `rg -l -F <id> docs/planning docs/technical docs/design BACKLOG.md mods` (audit folder excluded) → no hit for CORE-06, PLY-07, PLY-08, ITM-05, ITM-06; PLY-09 only in round37-plan.md:151 (as "not verified"). Code: `mods/CORE/grug_core/status.lua:143-146` (returns nil, no log), `:88-98` (`status_modifier_sum` → `each_status` expires); `mods/PLAYER/grug_housing/soulbound.lua:91-92` wraps `core.create_detached_inventory`; `grug_housing/soulbound.lua:32-49` and `grug_skills/bound_items.lua:71-102` the same three seams; `mods/ITEMS/grug_materials/tools.lua:79-88` dead `uses`; `mods/ITEMS/grug_professions/init.lua:76`, `mods/ITEMS/grug_brewing/node.lua:3` dofile grug_jobs files.
- **Proposal:** Name each of the six ids in the P8 BACKLOG item (one line each, or a list) so the next structure round finds them; the facts are in the audit lane files.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DP1-08 | Low | docs | CHANGELOG's header sends readers to STATUS for reviews, tests and acceptance, which STATUS no longer holds

- **Where:** `CHANGELOG.md:12-13` against `docs/process/documentation.md:35` (STATUS: "No lanes, fixtures, reviews or feature prose") and `docs/STATUS.md:23-24` ("GUI acceptance is not tracked")
- **What:** "The development record behind each round (reviews, tests, acceptance) is in the project status and the round plans." Since the 2026-11 cleanup the record is the plan's Completion; STATUS has one row per round.
- **Evidence:** the quoted lines.
- **Proposal:** "… is in each round's plan (section "Completion"), linked from the project status."
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DP1-09 | Low | docs | BACKLOG's carry-over index omits 0.80.1 and Round 75.5

- **Where:** `BACKLOG.md:540-556`
- **What:** The list of plans with a "Carry-overs" section names Rounds "… 76 and 78–80" and the ones that "left none" (50, 63, 64, 75, 75.2). `docs/planning/round80.1-plan.md:282` has a Carry-overs section (four items, one of them a `render.py --check` that turns red on any later texture change) and is not listed; `round75.5-plan.md` has no section and is in neither list.
- **Evidence:** `rg -n '^#+ Carry-overs' docs/planning/round80.1-plan.md` → 282; same for round75.5-plan.md → none.
- **Proposal:** Add "[80.1](docs/planning/round80.1-plan.md#carry-overs)" to the list and 75.5 to "left none"; consider a one-line BACKLOG item for the red-turning `render.py --check` if it is wanted work.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DP1-10 | Low | docs | The gate table's "Round end" column mixes checks before and after the squash

- **Where:** `docs/process/round-workflow.md:140` ("One smoke boot … Round end: one boot of main"), `:145` (sync "from main") against `:89-96` (step 8: round-end gates "on the round branch after lane D's merge", then the squash to main)
- **What:** Step 8 runs the round-end gates on the round branch and squashes afterwards; the table's round-end smoke boot is "of main", which only exists after the squash, and the sync is step 9. A reader cannot tell whether the boot gates the squash.
- **Evidence:** the quoted lines.
- **Proposal:** Table cell "one boot of the round branch (before the squash)"; mark the sync row "after the squash (§2 step 9)".
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** medium (the intended order may be a boot of main after the squash; either way one of the two places needs the change)

### DP1-11 | Low | docs | docs/README routes "the documentation cleanup" to the September record; docs/maintenance holds history outside the archive

- **Where:** `docs/README.md:28` → `docs/maintenance/documentation-round.md`; `docs/STATUS.md:15-16` (the 2026-11 cleanup, `planning/docs-cleanup-plan.md`); `docs/process/documentation.md:23-24`
- **What:** The guide's "What changed during documentation cleanup?" points only at the 2026-09-23 consolidation record, not at the 2026-11 cleanup that defined today's STATUS and AGENTS shape. `docs/maintenance/` keeps that historic plan (with delivery state: documentation-round.md:96-104 "Delivery: merged to local main", "Current game delivery remains Round 19"), its review (review.md, citing the deleted `docs/design/playtest_quality_revision.md` at :70) and `inventory-baseline.tsv`, while documentation.md:23-24 puts historic plans and reviews in `docs/archive/`.
- **Evidence:** the quoted lines; `ls docs/design/playtest_quality_revision.md` → missing.
- **Proposal:** Route the docs/README row to both records (2026-09 and 2026-11); move `docs/maintenance/` under `docs/archive/maintenance/` (where its findings.md already lives) after the incoming-link check documentation.md:81-86 asks for.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

## Backlog notes

- `docs/process/checks.md:5-6` lists "the upgrade check" among the gates "every lane and every round end run"; the gate table (round-workflow.md:130) runs it per lane only when the version or `upgrade.json` changed.
- `docs/process/templates/lua_run.sh:4` says the installed copy's locks are "fixed to r43/locks", while the template computes them beside itself (`:16`); the template is therefore not the installed script byte for byte (consistent with ":6 A fresh install keeps its locks beside the copy", but a reader may expect one copy).
- `README.md:154` "tested with Luanti 5.17.0" while the reference checkout is 5.18.0 (`AGENTS.md:243`, `reference_projects/luanti/CMakeLists.txt:16-18`); fine if 5.17 is what was tested, worth a check when the user next upgrades.
- `AGENTS.md` is 29,376 bytes; the 2026-11 cleanup plan aimed at "about 25 KB" (docs-cleanup-plan.md Step 4); no process rule sets a number.
- `BACKLOG.md:406-408` ("The class rework is built (Rounds 52 and 53 …)") and `:530-533` ("the PvP-POI part shipped in Round 31 …; clash anchors and art are delivered") are delivery notes inside open items; allowed by documentation.md:14-16 as "partially delivered" context, but they duplicate CHANGELOG facts.
- `docs/audit-2026-10/README.md:166` still says "Round 37 complete locally, not pushed": a dated status line in a historical document, harmless.
- `docs/process/round-workflow.md:412-414` and `agent-model-policy.md:16` name "GPT-6 Astra"; `cross-cli-orchestration.md:11-12` was last verified with codex-cli 0.159.3 (2026-10-01); re-check when next used (the doc says so itself).

## Good to know

- **Mechanically verified and in good shape:** `game.conf:8` = CHANGELOG.md:15 = STATUS:10 = `tools/web_data/upgrade.json` "version" = 0.80.1; STATUS 2,770 bytes, five rows, follow-up row widened (80–80.1) as documentation.md:35 asks; the last squash `73b142c4` and tag `round-80.1` match git. Every relative link and `#anchor` in AGENTS, CLAUDE, README, ROADMAP, BACKLOG, STATUS, docs/README, docs/process/*.md and templates, docs/maintenance, TODO-design-nether, CREDITS, VENDOR, tools/README and CHANGELOG 0.76–0.80.1 resolves (GitHub slug rules, em dashes giving `--`). Every tool path, script and flag named in AGENTS.md, round-workflow §3 and checks.md exists (about 90 paths, 45 flags grepped in the scripts; `tools/r57_chains/run.sh OUT_DIR` takes it positionally). The six modpacks and twelve BASE mods match AGENTS.md:263 and VENDOR's rows; the twelve `TOOL_ALIASES` (3 families × 4 grades, `grug_materials/tools.lua:24-30`) match AGENTS:105. Music in CREDITS: all 16 shipped tracks credited.
- **README sample against `mods/`:** 393 quests in `grug_quests/data/zones` ("390+"), 4 classes, 6 peoples, mounts 15/30/45/60 at 6.4/8 land and 8/12 flight (`grug_mounts/catalog.lua:31-40`), boats 4 → 8, Claim Stone from 20 (`grug_housing/manager.lua:90`), `QUEUE_MAX = 5` (`grug_jobs/jobs.lua:88`), death wear 10 % (`grug_repair/runtime.lua:178`) skipped for PvP deaths within 30 s (`grug_pvp/rules.lua:15`), home cooldown 1800 s, PvP contact 60 s and PvP combat 10 s (`grug_pvp/rules.lua:12-13`); settings defaults (1.5, 1.0, full world off, map quality normal) match `settingtypes.txt:75-116`; migrate.py exit codes and Python 3.13/psycopg 3 match `tools/migration/cli.py` and `requirements.txt`.
- **BACKLOG items sampled against code, all still open (correctly listed):** "Minimum level: N" (`grug_quests/registry.lua:151`), "1 sent letters" (`grug_mail/window.lua:396`), `grug_gear.BRACKET_TINT` (`grug_gear/init.lua:141`), `mobs:mob_repellent` in `tools/wp13/node_tiles.json:2840`, `dogswitch` (`mobs/api.lua:2092`), no "trap" death category, Heal's full-health refusal (`kits_priest.lua:172`). No BACKLOG item found that the code shows as delivered; no BACKLOG link points at a missing plan or section.
- **This checkout is a fresh clone** (`/home/jan/grudgelands`, cloned 2026-11-17): no `tools/bin/`, no orchestration folder, no tags before round-78. Later lanes that run the documented commands here need DP1-02's install step first.
- **October audit, sample of 38 High/Medium findings (28 code, 10 docs).** Fixed in code (code evidence): PLY-01/CORE-01/CMB-02/ITM-01 (durability as its own event; consumers return on the reason, `grug_inventory/equipment.lua:180-188`), PLY-02 (`grug_mounts/entity.lua:1009`, `grug_quests/use.lua:340`), MOB-01 (`mobs/api.lua:3611`), MOB-02 (`:2022-2027`), MOB-03 (`:283`), MOB-04 (`:606,:644`), MOB-05 (`:3749`), MOB-06 (`:306,:3725`), MOB-07 (`:548-562`), MOC-01/MOC-03 (`grug_mobs/liveness.lua`, `init.lua:1114`), MOC-02 (`bosses.lua:395-399`), MOC-05 (`boss_dragons.lua:236`), MOC-06 (`start_npcs.lua:1996`), MOC-07 (`rift_fuse` played through `grug_sounds` from `grug_mobs/rift_spawn.lua`), CORE-02 (`grug_core/water_guard.lua:52`), CORE-04 (`grug_map/minimap.lua:65`), CMB-01 (`grug_abilities/init.lua:2875`), CMB-04 (`grug_core.knockback_pushes`), PLY-03/X-01 (`default/node_formspec.lua:107`, `grug_jobs/workspaces.lua:186`), PLY-04 (`grug_housing/registry.lua`), PLY-05 (`grug_quests/state.lua:472`), PLY-06 (`:312`), ITM-02 (`grug_farming/init.lua:515`), ITM-03 (`grug_core/node_rightclick.lua`), X-02 (`grug_core.ground_growth_allowed`, GRUG PATCH in `default/functions.lua`); CORE-05 mitigated, not removed (round37-plan.md:576: 61.2 → 26.4 MB/h). Docs fixed: RDM-01 (README.md:164-176), CTX-02 (AGENTS.md:232), CTX-03 (AGENTS.md:228-231), CTX-04 (AGENTS.md:154-157), DW-01 (world.md:97), DW-06 (biomes_mobs.md:943), DW-09 (scout.md:45 "11.4 %"), DI-04 (no "flux" in docs/design), DI-05 (no mace or warhammer in items_crafting/item_tiers), DP-01 (no "6s" respec left).
- **October audit High/Medium findings still open** (mapgen MGT/MGS/W13 items, PLY-11 and X-11 already reported by other finders, not repeated):

| ID | Title | Status | Evidence |
|---|---|---|---|
| CORE-06 | Status reads expire records and fire callbacks; unknown modifier keys refuse a status silently; `dodge_percent` not a modifier key | open, untracked | `grug_core/status.lua:22-28` (five keys), `:88-98` (sum → `each_status` expires), `:143-146` (returns nil, no log) |
| PLY-07 | Soulbound guard and bound-skill guard implement the same three seams twice | open, only "other duplications" | `grug_housing/soulbound.lua:32-49,91-92`; `grug_skills/bound_items.lua:71-102` |
| PLY-08 | Global API monkeypatches that depend on mod load order | open, untracked | `grug_housing/soulbound.lua:91-92` replaces `core.create_detached_inventory` globally |
| PLY-09 | Five NPC-service session and permission implementations | open, only "other duplications" | `grug_mounts/trainer.lua`, `grug_housing/manager.lua`, `grug_home/innkeeper.lua` still separate; no shared service gate in `grug_core` (only `assign_service_socket`) |
| ITM-04 | Tooltip written by 3–4 writers that strip each other's lines | open, tracked | BACKLOG.md:121 (not re-read in code) |
| ITM-05 | Tool lifetimes in several places; dead `uses` | open, untracked | `grug_materials/tool_lifetimes.lua` still overwrites; dead `uses` at `grug_materials/tools.lua:79-88` |
| ITM-06 | ITEMS mods execute grug_jobs files | open, untracked | `grug_professions/init.lua:76`, `grug_brewing/node.lua:3` |
| MOB-08 / X-06 | mobs_redo is a hard fork with dead API | open, tracked | BACKLOG.md:120, :357 (`dogswitch` at `mobs/api.lua:2092` still present) |
| X-07 | `mod.conf` understates coupling | open, tracked | BACKLOG.md:120-121 (not re-counted) |
| CORE-05 | Minimap client textures never freed | mitigated | round37-plan.md:576 (growth reduced, not bounded) |
