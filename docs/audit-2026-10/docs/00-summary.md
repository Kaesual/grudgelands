# Documentation audit summary (October 2026)

Check of the current documentation against the code at baseline `0f169898`
(2026-10-05, Round 36 pushed). Five lanes; every High item and the
`findings.md` claims were re-checked in a verification pass. Historical
documents (`docs/archive/`, older `docs/planning/roundNN-*`, `docs/research/`)
were sources, not subjects. Read-only: no documentation was changed.

## At a glance

| Lane | Document | Scope | High | Medium | Low |
|---|---|---|---:|---:|---:|
| D1 | [01-readme-player.md](01-readme-player.md) | README.md, game.conf, settingtypes.txt, menu/ | 1 | 6 | 12 |
| D2 | [02-agent-context.md](02-agent-context.md) | AGENTS, CLAUDE, ROADMAP, BACKLOG, STATUS, TODO-design-*, docs/process, docs/technical, docs/maintenance, VENDOR, CREDITS | 2 | 12 | 14 |
| D3 | [03-design-world.md](03-design-world.md) | world*, settlements, spawn_regions, biomes_mobs, story, scout, boats, mounts, home_travel | 1 | 16 | 25 |
| D4 | [04-design-player.md](04-design-player.md) | classes, skill_trees, combat_stats, progression, parties, pvp, quests, housing, character_visuals, sound | 0 | 5 | 15 |
| D5 | [05-design-items.md](05-design-items.md) | items_crafting, item_tiers, crafting_equipment_revision, durability_repair, economy, farming, professions, inventory_equipment | 0 | 14 | 13 |
| | **Total** | | **4** | **53** | **79** |

## Verdict

- **The numbers are in very good shape.** Every ability, all 64 talent rows,
  the XP curve, the 540 quests, PvP, housing, party and looks constants,
  every price, buy-back, durability, repair, crown, respec, mount, enchant,
  upgrade, alchemy, drop and bag number that was compared matches the code.
  The world level bands match in all 38 zones. AGENTS.md's 169 code
  identifiers and its tool paths all exist; VENDOR.md, CREDITS.md and
  `upstream-workarounds.md` are current.
- **What drifts is status and prose, not numbers.** Status documents lag the
  last day of work. Design documents keep superseded history labelled
  "current" or "binding". Line-number citations rot.
- **The README pitch is accurate** (classes, level 60, towns and capitals,
  540 quests, professions, parties, PvP button; Nether only as a later
  expansion; no references to existing games). But 212 of its 403 lines are a round
  changelog, and there is no getting-started or controls section.
- **AGENTS.md (≈56 KB, loaded into every agent) describes a workflow that
  ended on 2026-09-20.** About a quarter of it is round history repeated in
  four other files.
- **`docs/maintenance/findings.md` is itself stale.** All four items there
  that other docs treat as open are fixed in code (D2 greyed recipes, D4
  Kraken range and pursuit, WP44 5 % buy-back, the level 41–60 story).

## The four High items

1. **RDM-01: the install steps don't warn against changing the New World
   mapgen options.** Changing Caves, Dungeons, Decorations or the v7
   Mountains/"Rivers"/Caverns/Floatlands boxes aborts world construction
   (`r7_runtime.lua:85-111`). A `disallowed_mapgen_settings` line in
   `game.conf` would hide the checkboxes, but the dialog still writes the
   player's saved flags, and chunksize, water_level and mapgen_limit are not
   in that dialog. So the line reduces the trap but does not remove it. Fix:
   README warning now; the game.conf line and maybe a clearer error are
   Jan's call.
2. **CTX-03: the PUC rule contradicts itself.** AGENTS.md, `wp-workflow.md`
   and `luanti-lua.md` make a per-package PUC/LuaJIT micro-KAT mandatory.
   BACKLOG, ROADMAP and the Round 22/29 rulings make it optional, no tool for
   it exists, and nothing has run it since Round 22. Jan's later ruling
   (ignore PUC during development; an optional crash smoke test at the end)
   should replace the mandatory text.
3. **CTX-04: the documented workflow is obsolete.** AGENTS.md and
   `wp-workflow.md` describe "one WP per session on a `wp<NN>-<slug>`
   branch". Since 2026-09-20 every merge is a round lane (`r<NN>-<lane>`)
   in `.claude/worktrees`, and the briefs and handover log live outside the
   repo. The real per-lane and round-end gates exist only in each round
   plan's §5/§6 (CTX-05).
4. **DW-01: capital zones are described as hostile-free.** `world.md`,
   `world_zones.md` and `biomes_mobs.md` say so. Since Round 28, each of the
   six capital zones has a 20–30 spawn recipe with night zombies and bandits,
   a camp and a named leader. Only the city itself is spawn-protected. The
   comment at `spawn_policy.lua:209-210` is stale in the same way.

## Themes

**Status drift** (CTX-01, RDM-02, CTX-06, CTX-08, CTX-13, DI-01, DW-06).
- Round 36 is called "not pushed" in about ten places, although it was
  pushed twice on 2026-10-05.
- Lanes F2, W2, W3 and RD merged after the Round 36 docs lane and are
  recorded nowhere. The private handover shows quick seed-fleet runs for W3
  and RD, but a round-end `full` run is still owed.
- GUI acceptance of Rounds 25–32 still reads "open".
- Root cause: the D lane runs before the last merges and the push. Add a
  post-merge status step to the round checklist.

**Agent context** (CTX-02 … CTX-14, CTX-24).
- The two rule contradictions: the parallel cap (seven vs eight Lua
  processes) and the PUC rule.
- Round history is copied four to five times.
- There is no mod ownership map, and the module guide has no headings.
- Some rules exist only in Claude's memory, so Codex/Astra never see them:
  the particle budget, faction names / no references to existing games, the mapgen engine-run budget
  and review scope.
- The model-routing defaults in `agent-model-policy.md` have not been
  followed for 13 rounds.
- D2 proposes one owner per fact and an AGENTS.md of about 350–400 lines
  (see its "Proposed structure changes").

**Design documents carrying history as current** (DW-02/04/05/29/30/32,
DI-02/03/05/06, DP-02/03).
- `biomes_mobs.md` placement tables predate the Round 28 recipes. The Bog
  Witch is called absent but has shipped since Round 9, and the Husk spawns
  in 13 zones, not 3.
- `world_zones.md` still calls itself a "target" and cites a 600×500 start
  core that does not exist.
- `items_crafting.md` §3.8 keeps about 100 lines of the retired vendor floor
  marked "Binding".
- About 228 `file:line` citations in `skill_trees.md` and `combat_stats.md`
  are pinned to an old commit and now point at unrelated lines.

**Naming rule** (DP-04, D1 note). Rule (Jan, 2026-10-05): no explicit reference to any
existing game, in docs, code comments, ids, briefs or chat. The current IP rule in AGENTS.md only
covers one title and should be generalized. Living docs still quote another game's ability names
("Power Word: Shield", "Battle Shout"), `skill_trees.md` §2.11 quotes a full name list, and the
sound id `cast_frost_nova` is in code. `ROADMAP.md:349` plans the future classes "Paladin, Rogue,
Warlock and Shaman": generic terms, but as a set they mirror one existing game's roster.

**Sound gate** (DP-05, code MOC-07). `sound.md` says no unapproved file
ships, but about 95 inherited minetest_game, doors, xpanes and mobs_redo
sounds ship unlisted. `mobs_spell` and two Rift Spawn sounds play outside
`grug_sounds`.

## Proposed documentation packages

- **A — Status sync** (S, do first).
  - Push state everywhere.
  - Round 36 late lanes into STATUS.
  - Refresh or archive `findings.md`.
  - Add the post-merge status step to the D-lane checklist.
- **B — Agent context restructure** (M).
  - One owner per fact (D2's table).
  - AGENTS.md slimmed to working rules.
  - `round-workflow.md` replacing `wp-workflow.md`, with the real gates.
  - A mod ownership map.
  - The memory-only rules Jan promotes into the repo.
- **C — README for players** (S–M). D1's outline: what you can play,
  getting started and controls (with the in-game Help tab), a short current
  state, install with the mapgen warning and the first-start wait.
- **D — World design docs** (M). Capital zones, `biomes_mobs.md` split into
  family specs plus a placement table generated from the recipes (D3's
  38-zone appendix is a first cut), `world_zones.md` cleanup.
- **E — Player design docs** (S–M). Split `skill_trees.md` (archive the
  delivery history and the pinned citations), respec price, naming cleanup,
  sound.md inherited set.
- **F — Item docs ownership** (M). `item_tiers.md` owns numbers,
  `items_crafting.md` owns rules, `professions.md` absorbs the profession
  rules, `crafting_equipment_revision.md` becomes a redirect.

## Decisions for Jan

Collected from the lanes. Each lane document has its full list under "Open
questions for Jan".

**Decided by Jan on 2026-10-05** (after the audit):

- **Memory-only rules move into the repo** (CTX-11): the web-build particle
  budget and web target, the naming rule (faction names; no explicit
  reference to any existing game, generalized from the earlier single-title
  rule), the mapgen engine-run budget, the review "happy path" scope, and the
  two engine traps. Owner: documentation package B.
- **The inherited sounds are accepted as they are** (DP-05): minetest_game,
  doors, xpanes and mobs_redo files and the old eat/drink cues. `sound.md`
  gets an "inherited set" paragraph saying so. Still to confirm: whether
  inherited files *repurposed* for new cues count too (`mobs_spell` as the
  dragon-return warning, gain 1.0 out to 160 m; the Rift Spawn fuse and burst,
  MOC-07).
- **Next steps run in a fresh session:** the owed full seed-fleet run after
  Round 36 W3/RD (it also gives the baseline for MGT-02), the remaining
  decisions below, then the Round 37 plan.

- **Already ruled earlier, confirm and write down:**
  - parallel cap of 8 (CTX-02);
  - PUC ignored during development, optional crash smoke test at the end
    (CTX-03).
- **Repo rules:** which memory-only rules become repo rules (CTX-11). Should
  the orchestration templates live in the repo (CTX-04)?
- **README:**
  - `disallowed_mapgen_settings` in game.conf (RDM-01).
  - Where the round changelog goes: STATUS or a new CHANGELOG.
  - A visible game version.
- **World:**
  - Capital zones with hostile recipes as intended (DW-01, probably yes per
    `round28-questing-leveling-plan.md:405`).
  - V1 "breaches / twisted vegetation" (DW-08).
  - The unused War Construct sub-types (DW-04).
  - Recipes as the only placement authority.
- **Naming:** archive `skill_trees.md` §2.11 in neutral wording; the future
  class names in ROADMAP.
- **Sound:** accept the inherited set as is? What happens to the dragon-return
  cue?
- **Items:**
  - Can the Armorsmith craft a Forge (DI-17)?
  - Ungated Ember Moss farming (DI-27).
  - Mastery bands vs profession tiers.
  - Spellbook gates (DI-14).

## Full index

All documentation findings, sorted by severity.

| ID | Sev | Category | Direction | Short description | Lane |
|---|---|---|---|---|---|
| RDM-01 | High | Missing | doc stale → fix doc (code option → Jan) | Local install omits "leave the New World mapgen options at their defaults"; any changed checkbox makes the world fail to load | [01](01-readme-player.md) |
| CTX-03 | High | Contradiction | unclear → Jan decides | Mandatory per-package PUC/LuaJIT micro-KAT vs "PUC run optional" (E9); no tool exists; not run since Round 22 | [02](02-agent-context.md) |
| CTX-04 | High | Outdated | doc stale → fix doc | "One WP per session, branch `wp<NN>-<slug>`, pick next open WP" vs. rounds/lanes/worktrees since 2026-09-20; orchestration state lives outside the repo | [02](02-agent-context.md) |
| DW-01 | High | Outdated / Contradiction | doc stale → fix doc | Capital zones are called hostile-free with empty palettes. Since Round 28 all six have hostile recipe populations outside the city. | [03](03-design-world.md) |
| RDM-02 | Medium | Outdated | doc stale → fix doc | Round 36 called "complete locally"/"merged locally", Round 35 "latest pushed"; R36 was pushed 2026-10-05 | [01](01-readme-player.md) |
| RDM-03 | Medium | Bloat | doc stale → fix doc | 212-line round-by-round changelog plus WP counts and checklist links bury the current state and duplicate STATUS.md | [01](01-readme-player.md) |
| RDM-04 | Medium | Missing | doc stale → fix doc | No getting-started or controls section; the in-game Help tab is never mentioned | [01](01-readme-player.md) |
| RDM-05 | Medium | Missing | doc stale → fix doc | Claim Stone housing is missing from "What you can play today" (appears only in the Round 25/26 history) | [01](01-readme-player.md) |
| RDM-06 | Medium | Missing | doc stale → fix doc | Flying mounts (levels 45/60) and the mount/boat levels are not mentioned | [01](01-readme-player.md) |
| RDM-07 | Medium | Missing | doc stale → fix doc | First start of a new world waits for "Preparing the world"; not mentioned | [01](01-readme-player.md) |
| CTX-01 | Medium | Outdated | doc stale → fix doc | Round 36 is called "not pushed / local only"; it was pushed twice on 2026-10-05 | [02](02-agent-context.md) |
| CTX-02 | Medium | Contradiction | unclear → Jan decides | Seven-process cap ("does not authorize an eighth") vs seed fleet and docs using 8 | [02](02-agent-context.md) |
| CTX-05 | Medium | Missing | doc stale → fix doc | Per-lane and round-end gates (check_fresh_server.py, validate.py --game, income.py --check, run_fixtures, smoke boot, seed fleet) only in round plans; cross-cli §2.6 describes a retired round end | [02](02-agent-context.md) |
| CTX-06 | Medium | Missing | doc stale → fix doc | Lanes F2, W2, W3, RD merged after the completion (incl. terrain/placement changes) are recorded nowhere in status docs | [02](02-agent-context.md) |
| CTX-08 | Medium | Unclear/Agent-trap | unclear → Jan decides | GUI-acceptance state of Rounds 25–32 still "open/under way" though later rounds were played | [02](02-agent-context.md) |
| CTX-09 | Medium | Bloat | doc stale → fix doc | Round history is copied 4-5 times; AGENTS at 56 KB breaks documentation.md:20-21 | [02](02-agent-context.md) |
| CTX-10 | Medium | Outdated / Agent-trap | doc stale → fix doc | Historical lines read as current: "no remote push", "await GUI feedback. No Claude tasks", "Root Astra coordinates…", the "local-development Go" sentence, resource-root authority | [02](02-agent-context.md) |
| CTX-11 | Medium | Missing | unclear → Jan decides | Rules only in Claude memory: web-build particle budget, web build as target, faction-name / no-WoW rule, mapgen engine-run budget, review "happy path", alias/send-front engine traps | [02](02-agent-context.md) |
| CTX-12 | Medium | Missing / Unclear | doc stale → fix doc | No mod ownership map; guide has no headings; grug_artisans/grug_trees absent; "one global per mod" vs `grug_items`/`grug_zones` | [02](02-agent-context.md) |
| CTX-13 | Medium | Outdated | doc stale → fix doc | D2 and D4 are resolved in code; "approved-but-unimplemented" list and WP counts from before Rounds 27–36 | [02](02-agent-context.md) |
| CTX-14 | Medium | Unclear/Agent-trap | unclear → Jan decides | Defaults (Sol coordinates, cross-model review) and calibration records not followed for 13 rounds | [02](02-agent-context.md) |
| CTX-24 | Medium | Bloat | doc stale → fix doc | "Phase 1 (MVP)" heading holds every round section; carry-over lists keep "Done" and fresh-server-moot items | [02](02-agent-context.md) |
| DW-02 | Medium | Contradiction | doc stale → fix doc | Bog Witch is called "deferred … absent"; it has shipped since Round 9 and has 5 recipe roles in 3 zones | [03](03-design-world.md) |
| DW-03 | Medium | Outdated | doc stale → fix doc | The capital band "carries no trees and no ground cover"; Round 36 W3 grows ground cover there | [03](03-design-world.md) |
| DW-04 | Medium | Outdated | doc stale → fix doc | Palette-era zone/family placement tables contradict the Round 28 recipes (Husk, War Construct, Stone Mite, Mesa Golem, Skeleton Archer, Crow) | [03](03-design-world.md) |
| DW-05 | Medium | Outdated | doc stale → fix doc | "BACKLOG WP13 tracks the remaining roster" and "6 villages/6 outposts/6 camps delivered"; WP13 is delivered | [03](03-design-world.md) |
| DW-06 | Medium | Outdated | doc stale → fix doc | Says the Kraken has view_range 20 and no pursuit; the code has had 40 and the deep-ocean pursuit since Round 29 | [03](03-design-world.md) |
| DW-07 | Medium | Outdated | doc stale → fix doc | The main line starts "local and mundane" and puts a main-story gate at level 30; the code's main line is 41–60 | [03](03-design-world.md) |
| DW-08 | Medium | Unclear/Agent-trap | unclear → Jan decides | V1 "scorched breaches, twisted vegetation" and "Nether corruption"; none exist, V1 has the rift only | [03](03-design-world.md) |
| DW-09 | Medium | Outdated | doc stale → fix doc | Scout crit at L60 is given as 17.8 %; the current formula gives 11.4 % | [03](03-design-world.md) |
| DW-10 | Medium | Contradiction | doc stale → fix doc | Live refresh "twice per second" vs "every 2 seconds" (the code uses 2 s) | [03](03-design-world.md) |
| DW-11 | Medium | Contradiction | doc stale → fix doc | The Nether dragon lord is called a "Phase 3 capstone"; world.md and ROADMAP say V2 / Phase 2 | [03](03-design-world.md) |
| DW-29 | Medium | Outdated | doc stale → fix doc | "The text describes the target; the running mapgen follows as Round 22 Phases 3–5 land": the target is live (R7 cutover) | [03](03-design-world.md) |
| DW-30 | Medium | Outdated / Contradiction | doc stale → fix doc | The "600 by 500 dry start core" does not exist; the code has a 152-node in-zone town square plus a ~300-node water keep-out | [03](03-design-world.md) |
| DW-31 | Medium | Contradiction | doc stale → fix doc | Native registration "one gravel blob + five strata" omits the three Round 24 decorative-nest blobs (9 native ores) | [03](03-design-world.md) |
| DW-32 | Medium | Outdated / Bloat | doc stale → fix doc | "remain disabled until one atomic production cutover": the cutover happened | [03](03-design-world.md) |
| DW-33 | Medium | Wrong | doc stale → fix doc | Bays "6–10 deep", deep ocean and channels "24 deep"; the code has one shelf profile down to ~33 below sea level; 24 is only the outside-bounds floor | [03](03-design-world.md) |
| DW-34 | Medium | Outdated | doc stale → fix doc | The slot vocabulary lacks the Round 31 `pvp_fortress`, `pvp_accord_low/high` and `pvp_throng_low/high` slots | [03](03-design-world.md) |
| DP-01 | Medium | Outdated / Contradiction | doc stale → fix doc | 51–60 respec is "6s"; code and economy.md say 525c (5s25c) | [04](04-design-player.md) |
| DP-02 | Medium | Unclear/Agent-trap | doc stale → fix doc | `file:line` citations pinned to `70dda602` point at unrelated lines today | [04](04-design-player.md) |
| DP-03 | Medium | Outdated / Agent-trap | doc stale → fix doc | "Tasks" and "remaining Holy sites" listed as open are done | [04](04-design-player.md) |
| DP-04 | Medium | Wrong (project rule) | doc stale → fix doc (§2.11: Jan decides) | WoW names in living docs (Power Word: Shield, Battle Shout, the §2.11 MMO name list); code id `cast_frost_nova` | [04](04-design-player.md) |
| DP-05 | Medium | Unclear/Agent-trap | unclear → Jan decides | The gate says no unapproved file ships; ~95 inherited files ship unlisted; `mobs_spell` used as an uncatalogued dragon-return cue | [04](04-design-player.md) |
| DI-01 | Medium | Outdated | doc stale → fix doc | D2 greyed recipes fixed in Round 28; WP44 "25 % vs 5 %" cut over in Round 29 | [05](05-design-items.md) |
| DI-02 | Medium | Unclear/Agent-trap, Bloat | doc stale → fix doc | Superseded bracket tabs, 13-item floor, hourly rotation and 1-in-5 Uncommon still written as binding rules | [05](05-design-items.md) |
| DI-03 | Medium | Contradiction | doc stale → fix doc | Material chains framed as profession progression; code and professions.md:192-193 make them universal Basics | [05](05-design-items.md) |
| DI-04 | Medium | Outdated | doc stale → fix doc | "Vendor supply: flux" — no flux item exists | [05](05-design-items.md) |
| DI-05 | Medium | Wrong / Contradiction | doc stale → fix doc | Weapon table lists mace, 1H axe and warhammer and a "physical 2H" bow; code has none of those and a 1H bow | [05](05-design-items.md) |
| DI-06 | Medium | Outdated | doc stale → fix doc | "WP44 target price table is future behavior until its cutover" — delivered in Round 29 | [05](05-design-items.md) |
| DI-07 | Medium | Contradiction | doc stale → fix doc | "existing deeper-mining penalties … remain" vs no depth penalty (durability_repair.md:256-258, mining.lua:9) | [05](05-design-items.md) |
| DI-17 | Medium | Missing | unclear → Jan decides | Station recipes are T3 and owned by one profession each; the Forge belongs to the Weaponsmith only, so an Armorsmith cannot craft one | [05](05-design-items.md) |
| DI-18 | Medium | Missing | doc stale → fix doc | Third craft gate (`mastery_required`, i.e. character-level band) not in the rule | [05](05-design-items.md) |
| DI-19 | Medium | Outdated / Agent-trap | doc stale → fix doc | Herb gate described as "Alchemy's own book group"; code authorizes all four gated herbs with one learned profession | [05](05-design-items.md) |
| DI-20 | Medium | Unclear/Agent-trap | doc stale → fix doc | "Never sell an enchant input" reads as including own materials; shelves sell bronze bars and light leather | [05](05-design-items.md) |
| DI-21 | Medium | Contradiction | doc stale → fix doc | Column "Makes, enchants and upgrades" — plain weapons and armour are Basics; professions make only spellbooks, trinkets and bags | [05](05-design-items.md) |
| DI-22 | Medium | Missing | doc stale → fix doc | Seed recipe (1 harvest item → 2 seeds, Basics) documented nowhere | [05](05-design-items.md) |
| DI-23 | Medium | Contradiction | doc stale → fix doc | Salt Crust "never renews" but is a cultivable regrowing crop | [05](05-design-items.md) |
| RDM-08 | Low | Missing | doc stale → fix doc | Peoples, capitals, continents and racial passives are never named | [01](01-readme-player.md) |
| RDM-09 | Low | Missing | doc stale → fix doc | Bosses (island dragons, capital kings, Generals, rift boss) absent from the feature list | [01](01-readme-player.md) |
| RDM-10 | Low | Missing | doc stale → fix doc | Player chat commands undocumented; "volume settings" doesn't say where they are (`/music`, `/ambience`, Help → Sound) | [01](01-readme-player.md) |
| RDM-11 | Low | Outdated | doc stale → fix doc | "the 200-arrow Basics recipe" — one craft now makes 100 arrows | [01](01-readme-player.md) |
| RDM-12 | Low | Unclear/Agent-trap | doc stale → fix doc | "Round 20 supplies 240 quests" next to "more than 500 quests" (line 29) reads like a contradiction | [01](01-readme-player.md) |
| RDM-13 | Low | Wrong | doc stale → fix doc | "Development uses Luanti 5.17.0-dev" mixes up the reference checkout with the test client (Flatpak 5.17.0) | [01](01-readme-player.md) |
| RDM-14 | Low | Unclear/Agent-trap | unclear → Jan decides | Asks bug reporters for "your game version", but the game has no version a player can see | [01](01-readme-player.md) |
| RDM-15 | Low | Missing | doc stale → fix doc | Host-facing facts are missing: the game's settings (map quality, full-world prep, mob damage ×1.5, tree regrowth, atmosphere), and that damage is always on with creative off | [01](01-readme-player.md) |
| RDM-16 | Low | Unclear/Agent-trap | doc stale → fix doc | Main-menu setting descriptions show code internals (function names, globalstep, "observer-managed") | [01](01-readme-player.md) |
| RDM-17 | Low | Contradiction | doc stale → fix doc | "combined game is GPL-3.0" vs "GPL-3.0-only" | [01](01-readme-player.md) |
| RDM-18 | Low | Unclear/Agent-trap | doc stale → fix doc | "a war commander guards two enemy camps": in fact there are two commanders, one per faction's camp | [01](01-readme-player.md) |
| RDM-19 | Low | Bloat | doc stale → fix doc | Development notes (music tab idea, POI placement, Cooking feedback, guard healing, "Round 18 decisions" routing row) in a player document | [01](01-readme-player.md) |
| CTX-07 | Low | Outdated | doc stale → fix doc | "Second text review in progress" / "catalogue stale" — both landed (`6794af6e`, `1e8a975d`) | [02](02-agent-context.md) |
| CTX-15 | Low | Contradiction | doc stale → fix doc | Three different "where is current status" entry points (ROADMAP / BACKLOG / STATUS) | [02](02-agent-context.md) |
| CTX-16 | Low | Contradiction | doc stale → fix doc | Binding Lua rules live in `docs/research/`, which the docs define as non-authoritative | [02](02-agent-context.md) |
| CTX-17 | Low | Unclear | doc stale → fix doc | Says sweeps are "scoped to `mods/*/grug_*`" so tools/ Lua needs explicit runs; check_lua.sh sweeps whatever files it is given | [02](02-agent-context.md) |
| CTX-18 | Low | Wrong | doc stale → fix doc | `r29_t` listed as `quest_targets.py`; the folder holds `test_quest_targets.py`, the tool is `tools/r28_regions/quest_targets.py` | [02](02-agent-context.md) |
| CTX-19 | Low | Outdated | doc stale → fix doc | Small stale facts: future `games/<gameid>/` layout, "quality final runner", BASE as the only vendored modpack, "add CREDITS.md when…" | [02](02-agent-context.md) |
| CTX-20 | Low | Outdated | doc stale → fix doc | Removal list names 4 fixtures stubbing `aim_raycast`; 7 do now (+r35_t, r36_e, r36_f, r36_f2) | [02](02-agent-context.md) |
| CTX-21 | Low | Outdated | doc stale → fix doc | "mobs_redo … 32 GRUG PATCH sites"; VENDOR.md:531 and the tree count 135 | [02](02-agent-context.md) |
| CTX-22 | Low | Outdated | doc stale → fix doc | Points at `AGENTS.md "Mobs"` for the pathfinding-quality rule; it now lives in module-guide.md:482 | [02](02-agent-context.md) |
| CTX-23 | Low | Contradiction / Bloat | doc stale → fix doc | "Not a chronological diary" header over a 160-line round diary; "Remaining work" holds `[x]` items and an unchecked note | [02](02-agent-context.md) |
| CTX-25 | Low | Bloat | doc stale → fix doc | Closed 2026-09-23 consolidation records and old preparation receipts sit in living locations | [02](02-agent-context.md) |
| CTX-26 | Low | Unclear | unclear → Jan decides | Crafting TODO holds only an ocean-survival question; Nether TODO holds a "Decided" section against the TODO rule | [02](02-agent-context.md) |
| CTX-27 | Low | Outdated | doc stale → fix doc | "skill trees follow with WP11" (delivered); "§§7, 9, 14 describe the Round 22 target, not yet the code" (Round 22 shipped) | [02](02-agent-context.md) |
| CTX-28 | Low | Wrong | doc stale → fix doc | "unresolved audit findings below" — nothing below | [02](02-agent-context.md) |
| DW-12 | Low | Contradiction | doc stale → fix doc | Outposts are a "graveyard/respawn point"; V1 respawn is innkeepers only | [03](03-design-world.md) |
| DW-13 | Low | Outdated | doc stale → fix doc | The human quest-XP bonus is called a "latent hook"; it is active | [03](03-design-world.md) |
| DW-14 | Low | Outdated | doc stale → fix doc | "only 3 classes"; there are four (Scout) | [03](03-design-world.md) |
| DW-15 | Low | Outdated | doc stale → fix doc | "The 100-anchor roster"; the roster is 118 anchors since Round 31 | [03](03-design-world.md) |
| DW-16 | Low | Outdated | doc stale → fix doc | The Rift Spawn surface row also runs in The Skyglass Canopy; the zone row omits it | [03](03-design-world.md) |
| DW-17 | Low | Unclear/Agent-trap | doc stale → fix doc | Unbuilt T6 lava lakes and war-front squads are written in the present tense | [03](03-design-world.md) |
| DW-18 | Low | Bloat/Outdated | doc stale → fix doc | Ring vocabulary (core/inner/outer/coast/war coast) and the "24 ring outposts" note no longer exist in the code | [03](03-design-world.md) |
| DW-19 | Low | Outdated | doc stale → fix doc | `levels.lua:89-95` → the predicate is now at :101-103; the formula is at :131 | [03](03-design-world.md) |
| DW-20 | Low | Contradiction | doc stale → fix doc | The level is "both the visibility and purchase gate"; the same doc and the code list every tier, greyed | [03](03-design-world.md) |
| DW-21 | Low | Wrong | doc stale → fix doc | HUD label `Sprint (+50% Speed)` does not exist; the code has "Sprint" / "+50% movement speed" | [03](03-design-world.md) |
| DW-22 | Low | Unclear/Agent-trap | doc stale → fix doc | Present-tense "bowyer sells arrows … no bracket tab" contradicts :361 and stock.lua (the bowyer sells the T1 bow) | [03](03-design-world.md) |
| DW-23 | Low | Missing | doc stale → fix doc | Undocumented: the ×0.5 move stance while drawing a bow; a stun dismounts | [03](03-design-world.md) |
| DW-24 | Low | Outdated | doc stale → fix doc | River stroke widths, "selected view" wording and the live-signature list are behind the code | [03](03-design-world.md) |
| DW-25 | Low | Outdated | doc stale → fix doc | Reference "ROADMAP 1.5" does not exist | [03](03-design-world.md) |
| DW-26 | Low | Unclear/Agent-trap | unclear → Jan decides | A proposed "Rift-Touched" state collides with V1's rift and Rift Spawn | [03](03-design-world.md) |
| DW-27 | Low | Outdated | doc stale → fix doc | The innkeeper map markers are own-faction only (and there is a "Your Claim Stone" marker) | [03](03-design-world.md) |
| DW-28 | Low | Outdated (line refs) | doc stale → fix doc | Line references into `kits.lua`, `stats.lua`, `stock.lua`, `mobs/api.lua`, `mobs/mount.lua` and `guard.lua` have drifted | [03](03-design-world.md) |
| DW-35 | Low | Missing | doc stale → fix doc | Public `grug_zones` methods lack `hard_protection_kind_at` and `hard_footprint_in` | [03](03-design-world.md) |
| DW-36 | Low | Unclear/Agent-trap | doc stale → fix doc | The relief table mirrors `source.relief_profiles`, which has zero readers; the live presets are in `terrain_data.lua:16-29` | [03](03-design-world.md) |
| DW-37 | Low | Outdated | doc stale → fix doc | Per-race capital "terrace" forms; the same doc (:1477-1478) says "no terraces", and the `shape` field is unread | [03](03-design-world.md) |
| DW-38 | Low | Contradiction | doc stale → fix doc | "dragon hoard" vs "no hoard chest (E11)" | [03](03-design-world.md) |
| DW-39 | Low | Missing | doc stale → fix doc | No numbers for the 80-node shelf band or the bay-mouth deep-ocean cut at z = ±3000 | [03](03-design-world.md) |
| DW-40 | Low | Unclear/Agent-trap | unclear → Jan decides | "never overlaid" / `surface_mob_level_at`: `grug_core.surface_mob_level_at` returns the region overlay; only `grug_zones.*` is the pure field | [03](03-design-world.md) |
| DW-41 | Low | Wrong | doc stale → fix doc | `stillgrave_ringbarrows` is called a "ridge band"; the code type is `ring`, which is missing from the §8.4 type list | [03](03-design-world.md) |
| DW-42 | Low | Outdated (citations) | doc stale → fix doc | The retired §15 subsections are still cited (`post-wp40-planning-review.md:50,64`; `wp41-engineering-brief.md:52,80,89,168`); every other § reference resolves | [03](03-design-world.md) |
| DP-06 | Low | Unclear | unclear → Jan decides | An open "question for the user" sits in a design doc that should hold decided rules only | [04](04-design-player.md) |
| DP-07 | Low | Outdated / Contradiction | doc stale → fix doc | Charge said to deal "3 damage"; it is 12 % of a base hit since Round 35 | [04](04-design-player.md) |
| DP-08 | Low | Wrong | doc stale → fix doc | "`/xp` can lower a level": `/xp` only grants a positive amount | [04](04-design-player.md) |
| DP-09 | Low | Outdated | doc stale → fix doc | "Stubs until WP6", "until WP20 ships parties": both delivered; the heal-threat group is still healer + target | [04](04-design-player.md) |
| DP-10 | Low | Unclear | unclear → Jan decides | "Warrior shield abilities → after WP14": WP14 is delivered and no such ability exists or is scheduled | [04](04-design-player.md) |
| DP-11 | Low | Missing | doc stale → fix doc | Trinket rage, regen, heal and kill effects are missing from the "ledger" sections | [04](04-design-player.md) |
| DP-12 | Low | Missing | doc stale → fix doc | No Scout growth or HP factor in §1/§2; code uses an implicit fallback of 1.0 | [04](04-design-player.md) |
| DP-13 | Low | Outdated | doc stale → fix doc | "we build `grug_offhand` (list "offhand" + HUD slot)": it is a list in `grug_inventory`, not a mod | [04](04-design-player.md) |
| DP-14 | Low | Outdated | doc stale → fix doc | "Enable PvP button" and "PvP off": the button is "Flag me for PvP" and there is no unflag | [04](04-design-player.md) |
| DP-15 | Low | Missing | doc stale → fix doc | The minimap (WP50) also shows party members; only the atlas is named | [04](04-design-player.md) |
| DP-16 | Low | Outdated | doc stale → fix doc | "one data file per zone": 32 zone files plus 10 `.front` files | [04](04-design-player.md) |
| DP-17 | Low | Outdated | doc stale → fix doc | Stale status prose ("X3 not authorized", "no code exists yet", "skill trees follow with WP11") | [04](04-design-player.md) |
| DP-18 | Low | Unclear | unclear → Jan decides | "Last Word" is both an achievement and the Priest capstone | [04](04-design-player.md) |
| DP-19 | Low | Bloat | doc stale → archive | About 900 lines of implementation plan, KAT, lane cut, rulings and supersession history inside the design doc | [04](04-design-player.md) |
| DP-20 | Low | Bloat | doc stale → archive | A pure link index, no rules | [04](04-design-player.md) |
| DI-08 | Low | Outdated | doc stale → fix doc | "Housing craft stations gain the same universal service later" — claim-station repair shipped | [05](05-design-items.md) |
| DI-09 | Low | Unclear | doc stale → fix doc | Incoming-wear rule omits "never a weapon carried in the offhand" (code and durability_repair.md have it) | [05](05-design-items.md) |
| DI-10 | Low | Outdated | unclear → Jan decides | "WP5 still owes the loot/economy audit" — WP5 delivered in Round 33 | [05](05-design-items.md) |
| DI-11 | Low | Outdated | doc stale → fix doc | Retired ring vocabulary, a pending WP40 translation, and a "dragon refill" in the gem audit | [05](05-design-items.md) |
| DI-12 | Low | Bloat | doc stale → fix doc | Crafting TODO holds only the ocean question D18; should be dissolved | [05](05-design-items.md) |
| DI-13 | Low | Contradiction (duplicate) | doc stale → fix doc | Alchemy table duplicated; item_tiers.md:24-27 claims it replaces §3.6 | [05](05-design-items.md) |
| DI-14 | Low | Unclear | unclear → Jan decides | Spellbooks need Journeyman mastery (level 16+) at every tier, so the T1 spellbook never counts as T1 progress | [05](05-design-items.md) |
| DI-15 | Low | Wrong (wording) | doc stale → fix doc | "Gold Ingots" — the item is "Gold Bar" (`grug_materials:gold_bar`) | [05](05-design-items.md) |
| DI-16 | Low | Unclear (structure) | doc stale → fix doc | Two different sections are both numbered "## 5." | [05](05-design-items.md) |
| DI-24 | Low | Wrong / Missing | doc stale → fix doc | Food/cooking details: eat-sound timing, mana-food refusal, source bands (Salt Crust 44–50), meat blocks | [05](05-design-items.md) |
| DI-25 | Low | Unclear | doc stale → fix doc | Cane/bamboo harvest wording, renewal guard name, bucket refusals, "claimed positions" water guard | [05](05-design-items.md) |
| DI-26 | Low | Agent-trap / format | doc stale → fix doc | Alchemy id is `alchemist`; broken table row, no Cooking row; "Consumables are Alchemy's alone"; Goldsmith chain simplified | [05](05-design-items.md) |
| DI-27 | Low | Unclear | unclear → Jan decides | Cultivated Ember Moss (seed recipe, crop) is not Alchemy-gated, only the wild source is | [05](05-design-items.md) |
