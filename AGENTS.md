# AGENTS.md — Project Guide

MMO-inspired Luanti game, titled "Grudgelands". This file holds the working
rules; every fact has one owner and the others link to it
([owners](docs/process/documentation.md#one-owner-per-fact)): status, push and
acceptance in [docs/STATUS.md](docs/STATUS.md); goals in
[ROADMAP.md](ROADMAP.md); open work in [BACKLOG.md](BACKLOG.md); how a round
runs, its gates and the review checklist in the [round
workflow](docs/process/round-workflow.md); model routing in the [agent model
policy](docs/process/agent-model-policy.md); which mod owns what in the [mod
map](docs/technical/mod-map.md); Lua and engine rules in
[luanti-lua.md](docs/technical/luanti-lua.md); everything else from
[docs/README.md](docs/README.md).

**Current state:** 0.67.0, Round 67 from the group play session (the
Social tab with an online players table, favourites and an invitation box
on the HUD; the map window at 90 % with markers in place and smaller, flat
layer buttons, quest list and HUD story first; flight underground and the
vertical speed per tier; nametags only where they serve; wide mobs with
room; one crafting row per output, the metal rods and back-recipes
removed, a Materials help page, half fuel; chests with Sort, labels and
three tiers with Upgrade), merged locally; **not pushed**. **Migrate**:
step 0.67.0 refunds the metal rods as bars; GUI test pending, joining the
joint test of 0.57–0.66. Production runs **0.65.0** (user, 2026-10-31), so
its update to 0.67.0 crosses no map reset: only the 0.67.0 step
([completion and checklist](docs/planning/round67-plan.md#completion-2026-10-30)).
Previous: 0.66.1, the `[GRUG-PERF]` performance lines for the hosting
platform (`grug_perf`; **compatible**, no step; merged locally, not
pushed; [STATUS](docs/STATUS.md)), on 0.66.0.
Previous: 0.66.0, Round 66 polish (the two-handed shift-click
swap and blocked offhand, the fishing rod from the start, a Sent tab in the
mailbox, the viewport and text growing on tall screens, markers sized by
the drawn map, camps in faction colour, faction-coloured creation buttons,
hammer and book for the priest), merged locally; **not pushed**.
**Compatible**, no step (one new mail storage key, `sent:<name>`); GUI test
pending, joining the joint test of 0.57–0.65; one user question open
(desktop HUD scaling above 1 only caps the markers)
([completion and checklist](docs/planning/round66-plan.md#completion-2026-10-28)).
Previous: 0.65.0, Round 65 quest lists without locked rows
(acceptance at quest level − 2, one grey hint line, the silver "!" for a
quest in one or two levels) and a boxed quest HUD sorted by quest level,
**pushed** 2026-10-27 (origin/main `8609d4c2`, with 0.64.0). **Compatible**,
no step; GUI test pending, joining the joint test of 0.57–0.64; the PvP
fortress quests open at 39 like every quest (user, 2026-10-27)
([completion and checklist](docs/planning/round65-plan.md#completion-2026-10-27)).
Previous: 0.64.0, Round 64 shared 32px map icons and bounded
alpha-aware placement, synced to Luanti; **pushed** with 0.65.0.
Compatible presentation update; desktop/web GUI acceptance pending
([completion and checklist](docs/planning/round64-plan.md#completion-2026-10-27)).
Previous: 0.63.0, Round 63 mining-camp redesign and the
[UI polish](docs/planning/ui-polish-implementation.md), published on main
with the user's explicit merge-and-push authorization on 2026-10-27
([delivery status](docs/STATUS.md)). Local Luanti is synced.
Full GUI acceptance is not recorded. Map reset joins the planned deployment;
production remains 0.55.1. Previous: 0.62.0, Round 62 "The front 41–60 and the main
line's story layer" (**map reset**, no step;
[completion](docs/planning/round62-plan.md#completion-2026-10-25)): the
last round of the quest rework, which is now complete for levels 11–60;
the fourteen front files left (the ten `.front` files, the four
Battlegrounds files) rebuilt on the Round 57 quest system and flagged
reworked, so all 48 quest files are flagged (123 → 120 front quests, 390
shipped); the Round 36 main line is the story path (its 31 spine steps
`story`, chained only on themselves, with completions; the opener at 41
requires nothing; The Throng's Chirr after Huskell); ten shared front
quests on the hosts' line `border`, the two optional group quests at 50
shared by both factions, departures to Dorrin, Thorga, Eriath, Vaska and
Ossa, the Throng's island bounty pair (Krait, Last-Offering), T5/T6
reward choices with the reward budget per zone and level band, eight new
quest places, the free front at 25 % (The Accord) and 18 % (The Throng)
kill objectives; the Kezamba moot-house door and the Lethariel mere
shrines fixed in their templates; bags of 8 / 12 / 16 / 20 slots. **Not pushed**; it waits with 0.58.0–0.61.1 for the
user's joint GUI test, then the production deploy with one map reset.
Before it 0.61.1, the refreshed service dialogs (compatible;
[dialog review](docs/planning/ui-dialog-review.md)): the Atlas 03 vendor,
quest-giver, mail, trainer and service windows and the typography audit
on the shared presentation toolkit. Before it 0.61.0, Round 61 "The
story arc's third chapter and the quest rework of levels 31–40" (**map reset**, no step;
[completion](docs/planning/round61-plan.md#completion-2026-10-25)): the
six contested zones of levels 31–40 rebuilt on the Round 57 quest system
and flagged reworked, the two contested base files whole with their 15
main-line steps marked `story` (60 → 50 band quests, 393 shipped; kill
objectives 68 % → 25 %, 3–5 mob names per zone, five shared quests on the
hosts' line `border`, the reward pattern at item levels 31–40), chapter 3
of the story arc (A5 and T4 at 34/35 from Toren Waterbarrel and Drek
Rampbinder to the Ashenward and Bannerbreak mining camps' foremen Audra
Wainholt and Greda Stonehaul, A6 and T5 at 39/40 after the free camp raid
to Nella Hedgeward and Yarra Standardmender), one optional group quest per
zone, six new quest places, the Runner's Packet and the storm vessel with
their picked art. **Not pushed**; both wait with 0.58.0–0.60.1 for the
user's joint GUI test. Before it 0.60.1, the UI modernization (compatible;
[UI plan](docs/planning/ui-modernization-plan.md)): every window on the
shared theme and navigation of the presentation toolkit. Before it 0.60.0,
Round 60 "The story arc's second chapter and
the quest rework of levels 21–30" (**map reset**, no step;
[completion](docs/planning/round60-plan.md#completion-2026-10-24)): the
eight band zones of levels 21–30 and the six capitals rebuilt on the
Round 57 quest system and flagged reworked (84 → 71 and 64 → 47 quests,
403 shipped; kill objectives 50–62 % → 17–27 % per band zone, about three
mob names per zone, the reward pattern at item levels 21–30), chapter 2
of the story arc (A3 and T2a at 24 from the Frostbarrow and Ossuary
mining camps' foremen Brodd Deeppeg and Rellis Shalemark, A4 at 29 to
Dur Brannoc's guild leader, T3 at 29 at a town place on Nhal Veyr's guild
house), the mine leaders as guild members, an Alchemy quest at the first
capital visit, the Alchemy herbs by level band, soulbound quest-only
items and the seed fleet's quest-place check; four picked quest objects
and three quest item icons. **Not pushed**; both wait for the user's joint
GUI test of 0.57.0 to 0.61.1. Before it
0.59.0, Round 59 "The story arc's first chapter and
the quest rework of levels 11–20" (**map reset**, no step;
[completion](docs/planning/round59-plan.md#completion-2026-10-24)): the six
band zones of levels 11–20 rebuilt on the Round 57 quest system and flagged
reworked (83 → 59 quests, 13 per zone, all free play, three shared quests,
kill objectives 60 % → 21 %, three mob names per zone, the reward pattern),
chapter 1 of the story arc in the six capitals (the envoys at 19, the
Miner's Guild leaders' hubs, a town place per capital at 20), the town
place kind on settlement sockets, `E-free-follow-ups` per faction and the
quest log's variant zone; four picked quest objects. **Not pushed**; its
GUI test runs with Round 60's. Before it
0.58.0, Round 58 "The Miner's Guild and the town
fixes" (**map reset**, no step;
[completion](docs/planning/round58-plan.md#completion-2026-10-24)): one
Miner's Guild per faction (`grug_guild`; The Charter of Stone, The
Oathdelvers): 20 new mining camps and the 16 war camps as mining camps with
a faction-only teleport lift to 148 protected rooms at the ore tiers'
depths (their own generation step), six enemy camps under construction,
reputation with ranks 0–10 from a trade-in of raw mined goods, the camp
vendor's rank-locked page, Ore Sense and Treasure Hunt in their own effect
slot, the Miner's Remains, three cloaks, a guild house on a district plot in
each capital and 30 guild quests; the Round 56 town fixes. **Not pushed**;
its GUI test runs with Rounds 59 and 60. Before it
0.57.0, Round 57 "The crafting window, the quest
foundation and the new start zones" (**compatible**, no step;
[completion](docs/planning/round57-plan.md#completion-2026-10-23)): the
crafting queue (five jobs, crafts, enchants and upgrades alike, offline
too), layout C, recipe details pages with generated ingredient sources,
favourites and Basic recipes unlocked with the profession tier; the quest
foundation (shared quests with variants and several givers, choice rewards
with fixed enchants, story marking, completion texts, the free-play rules,
no repeatable quests); the six start zones rebuilt on it (92 → 30 quests);
flat alloys and wood grades, every dye craftable, no vendor selling
leather, cloth, ores or bars; bay shore water flying under its zone's rule
and the chin strip open underneath. **Pushed** 2026-10-23 (origin/main
`69481ed1`); its GUI test runs together with Rounds 58–60. Before it 0.56.1 and 0.56.0, Round 56 "Playtest fixes,
clear enchants, the hood and the quest survey" (**compatible**, no step;
[completion](docs/planning/round56-plan.md#completion-2026-10-22)): the
fixes from the playtest of 2026-10-21 (level-scaled aggro, the hit alert on
the hit mob, ranged mobs closing in, land mounts falling and jumping like
players, selling from the inactive hotbar, faction-wide Quartermasters,
mana food for every class, floating items), `Prefix:`/`Suffix:` in enchant
tooltips and "Replaces prefix: …" at the station, the hood as an armor
polygon part and the open chin strip, the town buildings frozen
byte-identically into building templates with a local editor, the quest
overview page; with 0.56.1, the picked hood art, GUI-accepted and
**pushed** on 2026-10-23 (origin/main `2b4a3228`). Before them 0.55.1, the profession debug command `/prof`
(**compatible**, no step;
[professions.md](docs/design/professions.md#16-the-prof-debug-command)), on
0.55.0, Round 55 "The offhand look" (**compatible**, no step;
[completion](docs/planning/round55-plan.md#completion-2026-10-21)): a
Warrior's shield (three sizes by tier) and a caster's open spellbook in the
left hand on two new bones under the left arm, the Scout's second weapon as
a card on the back (on the cloak when one is worn), cloak wings, manual
achievements (`/achievement grant|revoke`) with the Supporter Cloak, the
picked shield and spellbook art with one icon per tier, appearance version
3 and the setting `grug_offhand_visuals` (on by default; the off switch).
Both GUI-accepted and **pushed** on 2026-10-21 (origin/main `52996c44`);
0.55.1 runs in production. Before them, pushed together on 2026-10-21: 0.54.1, the
particle look pass (**compatible**; [STATUS](docs/STATUS.md)), 0.54.0,
Round 54 "The armor redesign in the game" (**compatible**;
[completion](docs/planning/round54-plan.md#completion-2026-10-21): armor
as low-poly boxes in the models with one atlas texture, appearance version
2), 0.53.1, the fix round of Round 53 (**compatible**;
[completion](docs/planning/round53-fix-plan.md#completion-2026-10-20)), and
0.53.0, Round 53 "The new classes" (round K of the class rework;
**migrate**, one step 0.53.0;
[completion](docs/planning/round53-plan.md#completion-2026-10-20): the
four new class kits and the eight talent graphs, the step resets every
character's talents). Before them 0.52.1 and 0.52.0, Round 52 "Ambience
and the class rework foundation" (**compatible**;
[completion](docs/planning/round52-plan.md#completion-2026-10-20)).
Earlier: 0.51.0, Round 51 "Land zones and the
sea" (**map reset**;
[completion](docs/planning/round51-plan.md#completion-2026-10-19)); 0.50.2
(compatible: the Claim Stone preview and claims on the minimap) on 0.50.1
and 0.50.0, Round 50 "Hotbar A/B, claim containers across map resets"
(compatible; the migration tool packs claim containers before every map
reset, declaration schema 3, `map_reset_pass`); 0.49.0, Round 49 "Mapgen
performance (native first) and gameplay polish" (**map reset**;
[completion](docs/planning/round49-plan.md#completion-2026-10-16)).
Rounds 25–35 count as GUI-accepted (the user, 2026-10-05), Round 39 too
(2026-10-06), Round 42's playtest was accepted (2026-10-08), Rounds 46 and
47 too (2026-10-14), Round 52 (0.52.0) on 2026-10-20, Rounds 53–55 with
0.53.1, 0.54.1 and 0.55.1 on 2026-10-21, Round 56 with 0.56.1 on 2026-10-23; the GUI tests of Rounds 36–38, 40,
41, 43–45, 48, 49 and 51 and of 0.45.1, 0.49.1, 0.50.0, 0.50.1 and 0.52.1
are not recorded as passed. Next: the joint GUI test of 0.57.0 to 0.62.0
([checklist](docs/planning/round60-plan.md#gui-checklist-rounds-57-58-59-60-61-62-the-ui-and-0611)),
joined by 0.63.0–0.66.0 (each round plan's checklist),
then the production deploy with one map reset (0.57.0 → 0.62.0; its
starting list in the [deploy plan](docs/planning/deploy-plan.md)), the
armor redesign and unique items ([ROADMAP](ROADMAP.md)).
Details: [STATUS](docs/STATUS.md).

## Language rules

- **All Markdown documentation in this repo is written in English.** Exception:
  `docs/research/` contains older German reference notes; they may stay German
  until substantially rewritten.
- Chat with the user is in **German**; code identifiers and code comments are in
  English.

## Standing user rulings

- **Naming (2026-10-03, generalised 2026-10-05):** the factions are **The
  Accord** and **The Throng**, in chat too, never translated. Never name an
  existing game as a reference — no titles, studios, or their faction, class,
  ability or place names — in docs, code comments, ids, briefs, pages or chat;
  describe mechanics in neutral words ("MMO-inspired"). Provenance is not a
  reference (user ruling 2026-10-06): code and licence provenance (VENDOR.md,
  LICENSE-media.md, CREDITS.md, `docs/reference_projects.md`, source
  citations) names the Luanti projects we vendor or read; the rule covers
  design inspiration.
- **The web build is a target system** next to desktop: both are tested, and
  effects keep the particle budget ("Performance").
- **Agent execution channel (2026-09-20):** models of the coordinator's own
  provider run as native subagents; CLI delegation only crosses providers
  (Claude may run Codex CLI, Codex may run Claude CLI when authorized). This
  changes mechanics, not authorization or review duties ([cross-CLI
  orchestration](docs/process/cross-cli-orchestration.md)).
- **Model routing:** the user decides per session which model coordinates,
  implements and reviews; the policy's roles are defaults. Independent review of
  every non-trivial change stays mandatory.
- **Version (user, 2026-10-05):** `game.conf`'s `version` counts
  `0.<round>.<patch>` (0.37.0 first); it is the one source Help → About
  and the newest [CHANGELOG](CHANGELOG.md) entry show (`tools/r37_dc`
  checks both).
- **Only the user pushes.** Agents never push.

## Release mode

- **The user's announcement (2026-10-07, Round 41 ruling 9):** fresh-server
  development mode ended with **0.41.0**. Worlds survive upgrades through the
  hosting platform's upgrade contract
  ([upgrade contract](docs/technical/upgrade-contract.md)): every upgrade is
  **compatible**, needs a **map reset**, a **migration** (since Round 43) or
  a **new server**, declared in `tools/web_data/upgrade.json` (schema 3) and
  checked by `python3 tools/check_upgrade.py`. New server wins; map reset
  and migrate combine. Exactly one real world existed then (the user's
  production server on 0.40.0); nothing checks, audits or supports older
  versions.
- **Migrations only through the tool, with a test.** A change the new code
  cannot read from saved state is declared: a map reset when the state is
  map-bound (or world generation changed), otherwise a migration (a removed
  item, restructured character state) or, when the round decides not to
  migrate, a new server; a validated world-creation scalar needs a new
  server unless the game forces it over `map_meta.txt` (then a map reset;
  upgrade contract §1). A migration is one step file
  `tools/migration/steps/vX_Y_Z.py` per `migrate` entry, run offline by
  `tools/migrate.py` on the stopped world, with its online part only through
  grug_core's runner (`grug_core.migrations`); never a conversion at load
  elsewhere. Each declared step has its end-to-end test
  ([round workflow](docs/process/round-workflow.md#3-gates)); a pushed step
  never changes (a fix is a later step).
- **The baseline rule:** a step relies only on what the previous step or
  map reset left plus what the versions in between write without a load;
  never on data a compatible version writes lazily at a load, never on an
  earlier step's online work having finished. An existing world without a
  version record is 0.41.0 (a new world takes the game's version). The map reset (`grug_reset_world`,
  `grug_core.map_reset`) stays the map's mechanism; new map-bound state gets
  its clear in the same change.
- **`origin/main` history is never rewritten** (contract R8): the platform
  fetches released commits to create test realms, restore backups and build
  its migration runner.
- **Stable ids:** items, achievements and waypoints keep their ids; quest
  ids change only for a good reason, and a reworked quest takes a new id
  (Round 57 ruling 21); a renamed item may keep its old name with
  `register_alias`. Unknown ids in saved state are ignored or dropped, never
  a crash.
- **Every lane classifies its change** (compatible, map reset, migrate, new
  server) in its report and the reviewer checks it; a new-server change is
  reported before it is built
  ([round workflow](docs/process/round-workflow.md#3-gates)).
- A compatible version should boot every world of the version before,
  full-preparation worlds included: best effort, without saved test worlds.
  Keep it minimal: no mechanism for a case that does not occur.
- Still no backward-compatibility branches, old-format readers,
  compatibility placeholders or cleanup LBMs for the development versions
  before 0.40.0; the twelve tool aliases `grug_materials.TOOL_ALIASES` (Round
  26 ruling 14) stay. Current-version persistence (saving and reloading the
  same world, reconnects, inventories, entity activation) remains required.

## Anthropic repository sharing authorization

**Standing user authorization, decided 2026-08-30:** every file in this
repository, including its read-only reference submodules and prepared snapshots,
may be sent to Anthropic when an authorized Claude Opus or Claude Fable task
needs it, without a separate confirmation. Keep each snapshot bounded to the
reviewed or delegated package; this permits no unrelated publication, no writes
by a read-only reviewer and no other side effect. Model/task authorization stays
separate: each new Fable task still needs the approval the [agent model
policy](docs/process/agent-model-policy.md) requires.

## Documentation layers

All durable project state belongs in the repo: what a future session needs goes
into AGENTS.md or `docs/`, not only the chat. Owners, archival and conflict
rules: [documentation maintenance](docs/process/documentation.md).

1. **`docs/design/`** — the *decided* game design (rules, numbers, lists; no
   open questions, no discussion).
2. **`TODO-<topic>.md`** (repo root) — *open* design questions. When every
   question in a file is decided, fold the results into `docs/design/` (and
   ROADMAP/BACKLOG where affected), then **delete the TODO file**.
3. **[BACKLOG.md](BACKLOG.md)** — work packages (WPs) and carry-overs; WPs
   reference `docs/design/` instead of inventing design.

**[README.md](README.md)** is the player-facing entry point, **derived, never
authoritative**; it keeps only a short "Current state". The round log is the
player changelog [CHANGELOG.md](CHANGELOG.md), one entry per round. At the end
of each round lane D writes the round's CHANGELOG entry and updates the README's
current state ([round
workflow](docs/process/round-workflow.md#4-lane-d-and-the-post-merge-status-step));
a design file added, removed or substantially changed also updates its design
tour; it never carries design or WP detail that does not already live in
`docs/design/`, ROADMAP or BACKLOG.

## Working method

- **Session start:** read [STATUS](docs/STATUS.md), then the current round plan
  (`docs/planning/round<NN>-plan.md`) or the task the user names; check for
  `TODO-*.md` files that block it.
- **Rounds and lanes:** work runs in rounds planned with the user, as lanes on
  `r<NN>-<lane>` branches in `.claude/worktrees/`, each independently reviewed
  and merged by the coordinator. Flow, gates, review checklist, brief rules and
  templates: [round workflow](docs/process/round-workflow.md).
- **Findings are hypotheses:** check a review finding, report claim or error
  message at the cited place before acting on it.
- **Rough targets, not hard gates:** new rules are guide values; checks only
  where gameplay would otherwise break; in doubt, ask the user.
- **Escalate** a fix that makes the design clearly more complex or world
  generation noticeably slower; do not solve or accept it alone.
- **Optional features and complexity (user, 2026-10-24):** ask before adding
  a complex interaction or workaround for an optional feature; offer omission
  or simplification as an alternative. Do not build the mechanism first.
- **Runtime tests are the user's** (Flatpak Luanti GUI, desktop and web build);
  every round ends with a GUI checklist.

## Project structure

- A **standalone game** (not a mod pack, not a fork of another Luanti
  game). The repository root is the game (`game.conf`, `menu/`, `mods/`,
  `settingtypes.txt`). **Standard unmodified Luanti clients are required:** no
  client or engine fork, no dependency on an upstream PR, no required client
  mod.
- **Third-party code is vendored, never a submodule** (2026-08-06):
  `mods/BASE/*` and the mobs_redo fork `mods/ENTITIES/mobs`, each in
  **[VENDOR.md](VENDOR.md)** (upstream, commit, license, patch list); in-place
  changes carry a `-- GRUG PATCH:` marker; prefer wrapper mods (`grug_mobs`
  pattern) over in-place edits.
- `reference_projects/` holds **read-only reference sources as git submodules**
  (WP36): not part of the build, but every engine claim, licence check and
  `file:line` citation points into them (`git submodule update --init
  --recursive --depth 1`). **Never move a pinned commit as a side effect** —
  `git submodule status` shows no `+`/`-`/`U`; deliberate updates and **every
  reference needed beyond one session** go through
  [docs/reference_projects.md](docs/reference_projects.md) (URL, purpose,
  licence; scratchpad clones die with the session).
- **UI theme assets** are generated by `tools/ui_theme/build.py`; after a theme
  texture or generator change run `python3 tools/ui_theme/build.py --check`
  ([presentation contract](docs/technical/ui-presentation.md)).
- **Imported meshes must be animated** (`ANIM`/`BONE`/`KEYS` chunks); a static
  mesh slides instead of moving.

## Lua & Luanti environment (IMPORTANT)

- **Plain Lua 5.1 is a HARD requirement** (2026-08-06): the engine prefers
  LuaJIT but silently falls back to bundled Lua 5.1.5, and our code runs on
  both. The do-not-write checklist and the engine facts:
  **[docs/technical/luanti-lua.md](docs/technical/luanti-lua.md)**. Key rules:
  - **No `goto`**, no `\u{...}`/`\x..`/`\z` escapes, no `//`, no bitwise
    operator syntax (use `bit.*`, 32-bit); `unpack`, never `table.unpack`; no
    `table.pack`/`rawlen`/`__len`/`__pairs`. Numbers are doubles (safe integers
    ±(2^53−1)).
  - **Deterministic code** (all of `mods/MAPGEN`, and anything that must agree
    across processes): `x * x`, never `x ^ 2` (check_lua sweep 6), and no
    `pairs` order over string keys in output — sort the keys first.
  - Compare positions with `vector.equals`, never `==`.
  - `pairs(core.registered_nodes)` never yields alias names; resolve known names
    directly (`core.registered_nodes[name]`, `core.get_content_id`).
- **Check every changed Lua file** with `bash tools/check_lua.sh <files>` from
  the repository root, Lua under `tools/` included: the plain-5.1 parser
  (`tools/bin/luac51`, built once by `tools/build_lua51.sh` — **not** `luajit`,
  which accepts what the fallback rejects), the `SETGLOBAL` listing and six
  sweeps. It needs ripgrep and fails fast without it.
- **PUC is ignored during development** (user ruling 2026-09-25, Round 22 D1;
  every lane's rule since Round 29): all executable runs use LuaJIT; no PUC
  fixture, parity digest or gate; at most one optional PUC crash smoke test at
  the end, once the mapgen is finished (BACKLOG release checks).
- **At most 8 Lua processes at once on the workstation**, counted across all
  agents, lanes and reviews (8 physical cores, user ruling). Parallel runs are
  preferred: do not serialize independent seeds or partitions for
  convenience, and do not parallelize jobs that share mutable output or whose
  correctness depends on execution order. Fleets run under
  `chrt --idle 0` and `ionice -c3`, each process with its own output and a
  deterministic merge step. The host is the user's workstation: wall time is
  **never** a kill criterion (abort only on an intrinsic projection or lost
  liveness), timings under unintended contention are invalid, and the same work
  never runs twice. A round's queue script enforces the cap.
- The reference checkout is **Luanti 5.17.0-dev**, a read-only source; a newer
  engine never unlocks newer Lua syntax. **Read the engine's Lua, never guess:**
  `reference_projects/luanti/builtin/`, `lib/lua/src/`,
  `src/script/lua_api/l_*.cpp`.
- **Engine workarounds** live in
  [docs/technical/upstream-workarounds.md](docs/technical/upstream-workarounds.md);
  check it at every engine version change and at the start of each round; a new
  workaround gets an entry there.
- **`core.*`**, never `minetest.*`. **All game logic runs server-side**; no
  SSCSM. The sandbox disables `require`, `os.execute` and most of
  `io`/`os`/`debug`; we never request the insecure environment. `strict.lua`
  warns on undeclared globals — treat each warning as a bug.

## Game/mod anatomy

- Every mod: `mod.conf` (`name`, `depends`, `optional_depends`) + `init.lua`;
  media in `textures/ sounds/ models/ locale/` (names `a-zA-Z0-9_.-`, models
  `.b3d/.obj/.gltf/.glb`, sounds `.ogg`). Registered names are
  `modname:name`; `:foo:bar` overrides a foreign registration (needs a
  dependency). `game.conf` pins `allowed_mapgens = v7`.
- Six modpacks: `BASE/` (vendored), `CORE/`, `PLAYER/`, `ENTITIES/` (with the
  vendored mobs fork), `ITEMS/`, `MAPGEN/`; HUD elements live in their owning
  mod. Owners, seams and traps (`mod.conf` understates the coupling): [mod
  map](docs/technical/mod-map.md).

## Project conventions

- **Namespace `grug_`** for our mods; exactly one global table per mod, named
  after it, sub-files via
  `dofile(core.get_modpath(core.get_current_modname()).."/foo.lua")`. Two
  documented exceptions: `grug_quality` publishes `grug_items`, `grug_core` also
  publishes the zone façade `grug_zones`.
- Custom definition fields use the `_grug_` prefix; dispatch behaviour via
  **groups**, not name lists.
- Persistence: player data → `player:get_meta()` (structures via
  `core.serialize`); mod-wide data → `core.get_mod_storage()` (fetched at load);
  node data → `core.get_meta(pos)`.
- **Terrain-damage guard (user, 2026-09-19):** towns, starts, capitals and POIs
  are never damaged. Anything that writes or removes nodes from mobs, combat,
  fire, explosions or lava asks `grug_core.world_alterable(pos)`; the two
  recorded exceptions are the rift's crack and settlement NPCs opening and
  closing doors (`grug_mobs/npc_doors.lua`, Round 42 ruling 15).
- **Performance basics:** throttle every `register_globalstep` with a dtime
  accumulator; node timers for stations; LBMs only for current-version
  activation; ABMs only for ambient events (`chance`/`interval`, `catch_up =
  false`); `core.get_node_raw`, content ids and VoxelManip in hot loops.

The topic rules below name the one path to use; the
[module guide](docs/technical/module-guide.md) holds the seams behind them.

### Zone content

- **Mobs, loot, quests and enchant inputs are data**, per zone where per-zone
  (`grug_mobs/data/zones/<zone>.spawns.json`,
  `grug_quests/data/zones/<zone>.quests.json` and `.front.quests.json`,
  `grug_mobs/data/{subtypes,items,drops,tints}.json`,
  `grug_professions/data/enchants.json`). Tune data, not code.
- **Zone data holds rules, never coordinates** (maps differ per seed): surface
  spawns come from the recipe's regions on the seed's own terrain
  ([spawn_regions.md](docs/design/spawn_regions.md)). A zone's level band is its
  mapgen record (`grug_mapgen/wp40/source/simple_map.lua`) and changes only in a
  mapgen round; a mob's surface level is `grug_core.mob_level_at` (the
  spawn-region overlay), not `grug_zones.mob_level_at`.
- **After a recipe change:** `tools/r28_regions/run.sh <zones>` and
  `tools/r28_world/run.sh` (border rule `tools/r28_world/border_rule.py`); show
  the images when the user decides a distribution. Design files:
  `python3 tools/r28_design/validate.py`.
- **Names are data per slot** (zone, source, level band) in
  `grug_mobs/data/names.json`, built by `tools/r38_b1/gen_names.py
  --proposals` (`--check`); code-built names (kings, dragons, whelps …) read
  it, no second copy in code (PvP captains: `pvp_names.json`). **A kill counts by the name
  the mob shows**, so a quest's name is its exact target
  (`tools/r38_names/guarantee.py --check`); item objectives name items, the
  mobs they mention are guidance. The rules — normal mobs at most two words,
  named, elite and boss at most three, no signal words, Piglet only for the
  start pigs, one level stretch within one drop tier — are owned by
  [biomes_mobs.md "Names"](docs/design/biomes_mobs.md#round-28-sub-types-and-loot-by-band);
  the gate is `tools/r38_names/check_rules.py --shipped` (the Round 28
  `build_review.py` is retired). **Quest texts** name items,
  never tooltip texts; seed-dependent directions and places are placeholders
  ([spawn_regions.md](docs/design/spawn_regions.md#directions)), never a fixed
  compass word. Quest files that require each other change together.

### Economy and travel

- **One price module pays every vendor** (`grug_traders/prices.lua`, pure
  `price_rules.lua`): no price fields, no `set_price`; today's payouts are a
  first pass that stays unchanged, and a second pass in milli-copper prices
  the rest (bulk goods in lots, crafted goods at half their material value,
  pack blocks at nine times their item, Round 48); a new loot or gathered item
  still needs a class and a tier, a crafted good is priced by its recipe; a
  new recipe passes the load audit (output ≤ inputs) ([economy.md
  §2](docs/design/economy.md)).
- **Money check:** `tools/r29_e4/income.py --check` (mount, boat and respec
  prices, the crown fee) after any change to loot, repair or quest copper.
  Quests pay copper from their weight unless `rewards.copper` is set. Quest
  checks: `quest_targets.py` (region stats of three seeds, refreshed by
  `tools/r28_regions/run.sh` in Round 59), `validate.py --game`,
  `ledger.py --track <race>`, `quest_kinds.py --check`, and for the
  reworked bands and the capitals the Round 59, 60 and 61
  `build_structure.py --check` ("Quests, main line, rift and decor"); `luajit
  tools/r56_questmap/questmap.lua --out FILE` writes the quest overview
  page for the user (`--data DIR` reads a draft's `DIR/data/zones`).
- **All travel** (home return, respawn, waystones) goes through
  `grug_home/travel.lua`; boats are water mounts in `grug_mounts`. Gems are
  depth-tiered: each in its own tier rock, one tier deeper at half and two
  tiers deeper at a quarter of its density (Round 46), always with its own
  tier's harvest tier; there are no gem grades and no apex sockets.
- **The Miner's Guild** (Round 58, [miners_guild.md](docs/design/miners_guild.md)):
  `grug_guild` holds the catalogue (`catalog.lua`: every rank, rate, price,
  effect and loot number; code reads them from there), reputation
  (`store.lua`, the lifetime and balance per faction), the trade-in
  (`exchange.lua`, the vendor window's Trade-in mode for a vendor with
  `guild = true`), the mining effect and its items (`effect.lua`,
  `items.lua`, status `mining_sense`), the vendor page (`vendor.lua`) and the
  lift's right-click (`lift.lua`, trips through `grug_home.travel`); its
  world nodes are `grug_mapgen`'s ("World generation"). No copper route into
  reputation: the exchange takes only items no vendor sells
  (`tools/r58_guildspec` checks it on the real game). Topic checks after a
  number or the spec changes: `luajit tools/r58_guildspec/write_doc.lua .
  --check` (the spec's generated tables); after the shipped guild art
  changes: `python3 tools/r58_consume/art/ship.py --check` (drop 01's
  icons, status icons and Remains overlay) and `python3
  tools/r58_lift/art/ship.py --check` (drop 02's lift faces, reputation
  icon and map markers).

### Performance

- **Numbers are comparisons, never targets:** before and after on the same
  seed, area and probe (method: the
  [performance review](docs/research/perf-review-2026-10.md)). **No wall-clock
  budgets in code**: nothing decides its output by elapsed time.
- **Particles** are welcome, but the total at once stays in the **hundreds,
  never thousands** (the web build); every spawner has a bounded amount and
  lifetime. Effect briefs name the budget; reviews check it.
- **World-folder caches** (world layouts, region maps) share the key
  `grug_mapgen.wp40.world_key` plus a digest of their builders' files; a new
  input joins the key; any failure rebuilds, never stops the load.
- **Mob per-step code:** A* only inside the per-step budget, no
  `get_properties()` (`self._grug_cbox`), spawn rows only through the three
  merged spawn ABMs. **Quest state** is cached decoded: never write into a table
  `load` returns; marker consumers read `grug_quests.marker_states`.
- **No pass handles every player or zone in one step:** periodic passes spread
  work over slots or a per-pass budget, measured with stand-ins before and
  after.

### PvP, factions and looks

- **PvP is one flag per player** (`grug_pvp`, [pvp.md](docs/design/pvp.md)):
  combat asks `grug_pvp.can_harm`/`can_support` and never changes PvP state;
  `grug_core` reaches PvP only through the seams `grug_pvp` installs; the
  location is sampled once a second, never on the combat path. A combat-path
  change reports the PvE micro run before and after (`tools/r31_pvp/run.sh`).
- **A position's territory** comes from `grug_pvp.territory_at`, never the
  player's flag. **An NPC's faction decides whom it serves and its map marker**
  (`grug_factions.serves`/`refuse`), never the place.
- **Looks** are stored once per player (`grug_visuals.set_look`) and rolled once
  per NPC; look art comes from `tools/wp13/gen_character_visuals.py`, the
  enchant masks of weapons, bows and the old shared spellbook image from
  `tools/r31_b/gen_enchant_masks.py --check`, the armor's and the offhand's
  from their `bake.py` (below). PvP POIs are rules in
  `grug_mapgen/wp40/r31_pvp_catalog.lua`.
- **Armor is boxes and polygon parts in the model with one atlas** (Round
  54; polygon parts since Round 56, [armor
  format](docs/technical/armor-format.md) §1a: convex faces, low poly, such
  as the hood of the head slot, whose schema file is
  `tools/r56_hood/hood.json`): the contract
  (`tools/r54_armor/catalog.py`, `data/catalog.json`, `data/atlas.json`,
  the polygon parts' schema files) changes only through a round's
  coordinator; the worn layers, the armor
  icons and all their masks are baked by `tools/r54_armor/bake.py` from the
  picked art in `tools/r54_art/`, never edited by hand. A change to the art,
  the catalog or the models runs the topic checks: `tools/r54_armor/`
  `export.py --check` (it also validates every polygon part's schema file,
  the hood's `hood.json`), `atlas.py --check`, `zfight.py`, `check.py --art
  tools/r54_art/art` and `bake.py --icons-out mods/ITEMS/grug_gear/textures
  --check`; `tools/r54_art/assemble.py --check` and `ghosts.py --check`;
  `tools/r33_c3/gen_cloak_model.py --check` (the player and NPC models),
  `tools/r40_an/make_poses.py --check` and the hood's fixture
  `tools/r56_hood` (the hood in both models and the tiers that name it).
  The chin strip (the helm front's bottom row) is open on every cloth head
  piece and leather T1–T5, and so is the underside under the chin (the helm
  bottom face's front rows, Round 57; `check.py` refuses both elsewhere);
  every cloth and leather tier wears the picked hood (0.56.1), metal never
  does.
- **The offhand look is parts of the model with one atlas** (Round 55,
  [offhand format](docs/technical/offhand-format.md)): the shield and the
  open spellbook on the bones `Offhand_Shield` and `Offhand_Book`, the
  Scout's back cards and the cloak wings, behind the setting
  `grug_offhand_visuals` (on by default). The contract
  (`tools/r55_offhand/params.json`, `offhand.py`, `data/atlas.json`,
  `test_art/`) changes only through a round's coordinator; the worn layers,
  the shield and spellbook icons and their masks are baked by
  `tools/r55_offhand/bake.py` from the picked art in `tools/r55_art/`, never
  edited by hand. A change to the art, the params or the models runs the
  topic checks: `python3 tools/r55_offhand/offhand.py --check`,
  `bake.py --icons-out mods/ITEMS/grug_gear/textures --check`,
  `test_bake.py` and `test_render.py` there,
  `python3 tools/r55_art/assemble.py --check`,
  `tools/r33_c3/gen_cloak_model.py --check` (the bones, parts and z-fight
  groups), `tools/r55_model/test_frames.py`, the web `.glb` checks below,
  and on a dev machine `tools/r55_offhand/templates.py --check` (the
  painter's templates; it depends on Pillow's default font).
- **Realm websites read player meta** (the contract in the
  [module guide](docs/technical/module-guide.md#player-meta-read-by-external-tools)):
  those keys and the appearance format are not renamed without notice; a
  format change raises `APPEARANCE_VERSION`. A change to items, factions,
  classes, races or textures regenerates `tools/web_data/web_data.json`
  (`export.lua --check`); a change to the player model or its animations
  reruns `tools/web_data/model/build_glb.py --check` and `check_glb.py`.

### Combat, input and notices

- **Every server aiming ray goes through `grug_core.aim_raycast`**, never
  `core.raycast` with objects (the engine misreads rotated selection boxes,
  [upstream-workarounds.md](docs/technical/upstream-workarounds.md) §1);
  node-only rays keep the engine's raycast; aiming rays skip objects the player
  cannot see.
- **The LMB hold is one state machine** (`grug_abilities/input.lua`,
  [classes.md](docs/design/classes.md#left-click-and-held-input) §2b): a new
  hold rule changes that machine and its fixture, never adds a second lock.
- **Talent values are level-proof** (a share of the class's damage unit, of
  the base pool or of `K(L)`, the last listed in `graph.LEVEL_SCALED_KEYS`;
  [skill_trees.md](docs/design/skill_trees.md) §2.10); a flat "+N" is a
  design error. Every area, cone, group and splash filter goes through
  `grug_abilities.target_filter` (`valid_target`, the PvP flag). Support amounts multiply by
  `grug_classes.get_support_factor`; spells floor once after the level scalar
  ([combat_stats.md](docs/design/combat_stats.md) §2).
- **Personal notices go to the message feed** (`grug_core.feed`), never chat;
  chat keeps deaths, rare sightings, boss and dragon warnings. Quest kill labels
  use the zone's mob name (`validate.py`).
- **Character creation** stores nothing before "Create character"
  (`grug_classes/selection.lua`). Night region mobs leave at dawn
  (`grug_mobs/dawn.lua`).

### Items, professions and achievements

- **One source per item number:** [item_tiers.md](docs/design/item_tiers.md);
  its tables are generated by `tools/r33_ds/` (`build_doc.py --check`): change
  data or script, never a generated table. Drop rates are data in
  `grug_quality/init.lua`.
- **An enchant's value is never stored free:** each enchant carries stat,
  channel and tier, and `grug_items.enchant_value(stat, ilvl, tier)` derives it
  through grug_quality's one store path on every level or tier change. Station
  work is a `grug_jobs.register_station_operation` kind. Crafts, enchants and
  upgrades share one job queue of at most five (the running job under
  `grug_jobs:job` in its old format, the waiting ones under
  `grug_jobs:queue`; inputs taken when queued, outputs that do not fit into
  the growing overflow; [professions.md](docs/design/professions.md)); a new
  craft box registers through `grug_jobs.register_craft_box`, so the job
  strip stays under it. Recipe chains: `tools/r57_chains/run.sh OUT_DIR`
  (one boot through the queue) reports the depth per recipe after a recipe
  change.
- **Profession progress** comes only from recipes with the `progress` flag,
  through `grug_jobs.award_progress`.
- **A bag's size** is its `bagslots` group (`grug_inventory/bags.lua`; 8 /
  12 / 16 / 20 since Round 62): each join sizes an equipped bag's content
  list to it and only grows it, so a larger size needs no step and a
  smaller one does (the 0.48.0 step). The pins: `tools/r48_bags` (it runs
  the 0.48.0 step under that step's own sizes), `tools/r44_ih`,
  `tools/r33_c1`; `tools/r62_bags/capture.sh` shows the Inventory page with
  four 20-slot bags (one boot).
- **The Alchemy herbs follow the level bands** (Round 60,
  `grug_gathering/catalog.lua`; [world_zones.md
  §11](docs/design/world_zones.md#11-resource-loot-and-poi-budgets)): each
  tier's herbs grow in its own band, for levels 1–20 in every race's zones
  (Gravemoss and Sunleaf in the start zones, Dragonweed in the 11–20
  zones), for 21–40 on each faction's own half, for 41–60 in the fronts;
  gated herbs stay gated. `tools/r60_herbs` checks every recipe's herb and
  cooking inputs per race and tier (`--table` prints the reach and the
  mob-loot gaps); a catalogue change moves its digest pin in
  `wp40/r7_manifest.lua` and is mapgen content (a map reset).
- **Achievements** are catalog data on existing counters fed by hooks
  (`grug_mobs.register_on_boss_kill`, `grug_pvp.register_on_stat`,
  `grug_jobs.register_on_award_progress`), never a second kill, craft or boss
  path; stored per character. The cloak model comes from
  `tools/r33_c3/gen_cloak_model.py --check`.
- **Capital services** take over a gate resident
  (`grug_core.assign_service_socket`), no blueprint change.

### Sound

- **Approval gate (user, 2026-10-04):** no sound file ships unless the user
  picked that exact file on a listening page, recorded in an `approved.txt` the
  fixture checks every `.ogg` against. An event without an approved file stays
  silent, never a placeholder; a changed cut needs a new pick. Every file has a
  `LICENSE-media.md` row; attribution licences also go into
  [CREDITS.md](CREDITS.md). Rules: [sound.md](docs/design/sound.md).
- **One play path:** `grug_sounds.play(event, target)` with the spec in `EVENTS`
  and the event in `HOOKS`; no new `core.sound_play` for game events. Mob voices,
  ability cues, beds, loops and music are data (`_grug_voice`,
  `grug_abilities.CAST_SOUNDS`, `grug_ambience/data.lua`); music tracks live in
  `grug_ambience/music/` and are pushed on demand.
- **Downloads:** reuse downloaded material first, access Freesound serially
  with HQ previews only, never delete or move downloaded source material.
- **Ambience** (Round 52): beds follow the biome group and play in three
  layers by the depth below `grug_core.depth_below_surface`'s reference;
  the model (groups, layer curves, the cave probe, the atmosphere's
  underground band, calls, `/ambience debug`) is in the
  [module guide](docs/technical/module-guide.md#sound), the rules in
  [sound.md §4](docs/design/sound.md#4-ambience-beds-grug_ambience).

### Quests, main line, rift and decor

- **The main line** follows the approved
  [story bible](docs/planning/round36/story-bible.md); the final turn-in ids
  `accord_main_final` / `throng_main_final` are fixed and chapter gates come
  from `requires` ([quests.md](docs/design/quests.md) "The main line").
- **The quest foundation** (Round 57, [quests.md](docs/design/quests.md)
  "Shared quests" to "The rework flag"): a task given in several places is
  one quest with one variant per giver zone (several givers or a role,
  texts per giver or race); only story quests (`story`) chain, a free quest
  needs only a level and has at most one follow-up; since Round 65 every
  quest is accepted from its quest level − 2 (`grug_quests.acceptance_level`,
  at least 1; quest data names no `min_level`, both validators refuse one,
  [quests.md](docs/design/quests.md)); rewards may be a
  `choices` list (equipment with author-fixed enchants at the reward
  level); every quest is done once (`repeatable` is gone). The new rules
  apply to files marked `"reworked": true`, since Round 62 all 48 quest
  files (a `.front` file carries the flag beside its `zone` and `quests`);
  a free quest's one follow-up counts per faction (Round 59). The reward
  budget (`E-reward-budget`) counts per zone and level band, the band
  `(level − 1) // 10` of the quest's reward `level` (Round 62, both
  validators; [quests.md](docs/design/quests.md#the-rework-flag-round-57)).
- **The quest rework** (Rounds 59–62, one level band per round) is
  complete for levels 11–60: the bands 11–20 (Round 59), 21–30 and the
  six capitals (Round 60), 31–40 (Round 61) and the front 41–60 (Round
  62) are reworked on the Round 57 system; chapter 1 of the story
  arc runs in the capitals at 19–20, chapter 2 at 24–29 in Frostbarrow
  Shelf, Ossuary Reach, Dur Brannoc and Nhal Veyr, chapter 3 at 34–40 in
  Ashenward March, Bannerbreak Mesa and the band's mining camps, and the
  mine leaders speak for their Miner's Guild
  ([quests.md](docs/design/quests.md) "The band 11–20", "The band
  21–30", "The band 31–40", "Chapter 1 in the capitals", "The
  capitals"). From 41 the **main line is the story path**: the r36
  spine (17 Accord, 14 Throng steps, pinned by `tools/r36_qa` and
  `tools/r36_qt`, the four front climaxes among them) is `story` and
  each step requires only spine steps; every other front quest is free
  play ([quests.md](docs/design/quests.md) "The front 41–60"). The hosts
  of 31–60 share the line `border` for their shared quests (beside
  `front` or their local line). **Elite group quests below level 51 are always optional** (the
  user, 2026-10-25): free, standalone, never on the story path, never a
  zone's key reward; from 51 they may stand on the story path
  ([quests.md](docs/design/quests.md#group-quests-round-61)). A quest place can
  be a **town place**, a settlement socket of role `quest_place` written
  `socket:<settlement key>/<socket id>` ([quests.md](docs/design/quests.md)
  "Town places"; fixtures `tools/r59_qsys3`, `tools/r59_bandquests`,
  `tools/r59_storyquests`, `tools/r60_bandquests`, `tools/r60_capitals`,
  `tools/r61_bandquests`, `tools/r62_frontquests`).
  A **quest-only item** (`items.json` kind `quest`) is soulbound
  (`grug_soulbound`: only the carried inventory, never a chest, station,
  mail, trade or the trash; dropping destroys it) and is not rolled while
  it would not fit ([quests.md](docs/design/quests.md) "Quest-only
  drops"). Only `capital_precision` may ask for a profession's product
  (the `tools/r45_st` exception). The quest JSON files are the source;
  `tools/r59_bandquests/build_structure.py --check`,
  `tools/r59_storyquests/build_structure.py --check`,
  `tools/r60_bandquests/build_structure.py --check`,
  `tools/r60_capitals/build_structure.py --check`,
  `tools/r61_bandquests/build_structure.py --check` and
  `tools/r62_frontquests/build_structure.py --check` compare their
  structure (everything but the texts), and a rerun without `--check`
  would write the placeholder texts back. After the shipped quest art
  changes: `python3 tools/r59_storyart/paint_art.py --check` (the four
  Round 59 objects), `python3 tools/r60_storyart/paint_art.py --check`
  (the four Round 60 objects and three quest item icons) and `python3
  tools/r61_storyart/paint_art.py --check` (the storm vessel and the
  Runner's Packet icon), byte for byte.
- **The guild quests** (Round 58, [miners_guild.md](docs/design/miners_guild.md)
  §11): the gather quests live in the guild files
  (`charter_of_stone.quests.json`, `oathdelvers.quests.json`, zones named
  by the guilds' ids) and are given through the foremen's tier roles
  (`foreman_t<k>`, [quests.md](docs/design/quests.md#the-miners-guild-givers-round-58));
  the camp files carry the foreman hubs. A foreman the story names carries
  that name instead of "Foreman" (Round 60: Brodd Deeppeg in Frostbarrow
  Shelf, Rellis Shalemark in Ossuary Reach; Round 61: Audra Wainholt in
  Ashenward March, Greda Stonehaul in Bannerbreak Mesa; `grug_quests/npcs.lua`
  `FOREMAN_TITLES`, read by `tools/r28_design/r28common.py`; the ids stay).
  Since the texts landed the JSON
  files are the source: `tools/r58_guildquests/build_structure.py` would
  write the placeholders back and is not a gate; its `--check --ids`
  (Round 59) compares only the guild and camp quest ids and hubs each file
  carries.
- **"Use at a place"** is an objective, never a node (`grug_quests/use.lua`).
  Other mods hear turn-ins through `grug_quests.register_on_turn_in`, never a
  second completion path; `grug_quests.quest_held` is the cheap "has or did"
  query.
- **The rift is runtime content** (`grug_mobs/rift_core.lua`), its crack one of
  the two recorded exceptions to POI protection, besides NPC door use
  ([world.md](docs/design/world.md) §4b).
- **Decor is a kit** (`grug_mapgen/wp13/decor_kit.lua`): authored rows placed
  whole or failing the build; it never changes a composition's bounds, sockets
  or protection box, never blocks a window or a way; `tools/r36_w` holds every
  composition to `baseline.tsv` ([settlements.md](docs/design/settlements.md)
  "Decor pass");
  the start towns' and capitals' house touches are template content since
  0.56.0, Hearthpine's excepted.

### World generation

- **Town buildings are building templates** (Round 56, since 0.56.0): every
  building of the six start towns and the six capitals is a text file under
  `mods/MAPGEN/grug_mapgen/building_templates/` (`templates/*.tpl`, one
  `layouts/<town>.layout` per start town, one `layouts/<capital>.roster`
  per capital), read at load by `wp13/templates.lua`. The templates are the
  source of truth; the building generators are gone, and materials still
  come from the race palettes (`wp13/palette.lua`). Streets, plazas, walls,
  the city edge, terrain fitting, podiums, capital plot placement and the
  trees (planted at load at a template's stems) stay algorithmic. Format
  and validation rules:
  [building-template-format.md](docs/technical/building-template-format.md).
  Edit them with the local editor (`python3
  tools/building_templates/editor/serve.py`, localhost only, saving only
  through the validator). **A template, layout, roster or palette change
  changes what new worlds build and needs a declared map reset**;
  `tools/check_upgrade.py` enforces it (it compares what the towns build
  with the pushed commit). Topic checks when templates, layouts, rosters,
  palettes or the loader change: `python3
  tools/building_templates/check.py` (the hard gate, ruling 33: structure
  always, the editor palette and reachability for edited cells; it also
  runs the game's loader and builds every town and capital) and `check.py
  --self-test`; `tools/building_templates/viewer/test_templates.py` (the
  viewer's reader) and `tools/r56_editor/test_editor.py` (the editor;
  LuaJIT inside, about 1.5 minutes, so through the Lua queue). The
  known-defects list is empty since 0.62.0; `check.py` still warns about
  11 unreachable points, all checker false positives that
  `tools/r62_templatefix` walks in the built towns (Round 62).
  `export.py --check` is retired (Round 58 HALLS made the first
  deliberate template edits: it prints RETIRED and passes, and the export
  itself refuses to run without `--overwrite-edits`), so `check.py` is the
  gate. The Miner's Guild houses are generated:
  `python3 tools/r58_halls/make_halls.py --check` (edit the script, never
  the six `<capital>_miners_guild.tpl` files).
- **The Miner's Guild's world** (Round 58,
  [miners_guild.md](docs/design/miners_guild.md) §3): the camps are POI
  rows (`wp40/r58_camp_catalog.lua`, the blueprints) and one pure,
  deterministic camp module (`wp40/r58_camps.lua`, `camps(layout[, seams])`, read in
  both environments from `placement_layout`); the lift rooms are their own
  step after `refine_or_degrade` with their own degrade
  (`wp40/guild_room_writer.lua`) and a y-bounded protection wrapper beside
  the zone overlay (`guild_room_protection.lua`). The lift, room and banner
  nodes are `grug_mapgen`'s (`world_nodes.lua`, `guild_room_nodes.lua`); a
  change to the fields the settlement digest reads (`world_nodes.lua`'s
  comment at the lift) belongs there in a map-reset round, never in an
  override. The seed fleet checks every seed's 42 camps and 148 rooms.
- The WP40 R7 pipeline in `grug_mapgen` is the only mapgen owner (seams and the
  boundaries tests must cross:
  [module guide](docs/technical/module-guide.md#mapgen-and-biomes)). Test mapgen
  work on a **fresh world**.
- **Engine-run budget** (user, 2026-09-28): portable fixtures are the main
  proof; a few engine runs of at most about 5 minutes; one final run of about 15
  minutes over a chosen small region (ocean, coast, mountain, one start),
  bounded by region and ended by a normal shutdown. Never a full world or a
  repeated long run; reviewers read the receipts. Derive bounds from parameters
  instead of scanning; more goes to the user first.
- The **seed fleet** gates world-generation changes
  ([round workflow](docs/process/round-workflow.md#3-gates)); a change that only
  places, swaps or turns nodes needs no run. Since Round 60 it also builds
  every zone's spawn regions offline and fails a seed on which a recipe
  quest place is not placed (`tools/seed_fleet/seed.lua` `quest_places`;
  about +11 % per seed, kept in `quick` by the user).
- **One layout assembly** (Round 37): `wp40/world_assembly.lua` is the world's
  layout wiring; `r7_runtime.lua`, every portable tool and the seed fleet build
  on it, never on a copy. The seed fleet (`tools/seed_fleet/runtime.lua`)
  builds the real runtime and plans and writes five chunks per seed through
  `plan_slice` and the writer against a fake VoxelManip, about 25 s per seed
  (`quick` about 6 minutes at 6–8 parallel, `full` about 17 minutes). A
  `fail()` on the per-chunk path fails the fleet and the fixtures, so it must
  pass `quick`; on a live server it no longer stops the server: the chunk
  keeps the engine's terrain and is reported through `grug_core.severe`
  (`wp40/degrade.lua`, Round 41).
- **Decorations are owner-only:** tall trees are lost in height bands
  (emergent jungle trees: no ground at y ≡ 15..50 mod 80) and on 2–4-node
  lines along chunk borders
  ([R6 contract](docs/research/wp40-simple-map-r6-contract.md) §8.2,
  "Treeless bands"); the fix is a BACKLOG item.

## Licenses

- **Code: GPL-3.0-or-later** (`LICENSE.txt`; [licensing
  research](docs/research/licensing.md)). Compatible inputs: MIT, Apache-2.0,
  LGPL-2.1/3.0, GPL-2.0-or-later, GPL-3.0. **Never GPL-2.0-only.**
- **Media keep their original license** (CC0, CC BY, CC BY-SA, GPL), one
  `LICENSE-media.md` row per file (author, source URL, exact license and
  version, modifications); attribution authors also in [CREDITS.md](CREDITS.md).
  **Never NC or ND media.**
- Verify a license **in the source repo** before importing; ContentDB metadata
  can be wrong. Asset lists: [docs/research/assets/](docs/research/assets/).
- **Never copy assets or names 1:1 from existing commercial games**; own assets
  and names, "inspired by", not "copied" (and see "Naming").

## Testing & development

- **Fixtures:** `tools/run_fixtures.sh` runs every portable fixture under
  LuaJIT; a new one takes the repository path as `arg[1]` and exits non-zero on
  failure. Fixture and probe folders per round:
  [tools/README.md](tools/README.md).
- **Run only the fixtures you need** (the user, 2026-10-08/09): while
  developing, your own fixture plus the fixtures that actually test the
  behaviour you are changing — never every fixture that merely loads a file
  you changed; the full `tools/run_fixtures.sh` once, right before your
  final report. Details: [round workflow §3](docs/process/round-workflow.md#3-gates).
- **Seed fleet:** `tools/seed_fleet/run.sh quick|full`; when each is required:
  [round workflow](docs/process/round-workflow.md#3-gates).
- **The user's GUI install** is a Flatpak (`org.luanti.luanti`, no access to
  `~/projects`): `tools/sync_to_luanti.sh` copies the game to
  `~/.var/app/org.luanti.luanti/.minetest/games/grudgelands`; the coordinator
  syncs from main after merges, never from a branch unless the user asks. The
  user's runtime errors are diagnosed from `debug.txt` in that folder.
- **Agent engine runs never touch that personal folder** (2026-09-14: the user's
  client may be running, and two instances on one folder can crash). Boot only
  through `tools/luanti_headless.sh` or with the same guarantees: a fresh temp
  directory as `LUANTI_USER_PATH` **and** all XDG dirs, the log inside it, a
  `timeout --kill-after`, cleanup, `LC_ALL=C` (the launcher exports it), and at
  the end `pgrep -f '^luanti.bin'` showing no server of yours. Kill only your
  own run. A launcher that falls back to the personal folder when
  `LUANTI_USER_PATH` is empty is a defect; the WP40 profiler
  (`tools/wp40/profile/run.sh`) needs a launcher that forwards its path.
- Read the relevant [module guide](docs/technical/module-guide.md) section
  before touching a module; never infer current behaviour from an old report.
- Server log via `core.log("action"|"warning"|"error", msg)`. An error the
  server survives but an administrator must see goes through the one
  severe-error helper `grug_core.severe.report(source, summary, details, key)`
  (`grug_core/severe.lua`): an error line with the literal prefix
  `[GRUG-SEVERE]` and a red chat message to every player once per key; the
  mapgen environment loads the same file by `dofile` and its chat part
  reaches the main thread through gen_notify.
- The game's performance numbers go to the server log as `[GRUG-PERF]`
  lines (action level, one JSON object; `grug_perf`, 0.66.1): a `minute`
  line, `spike` lines and, with the engine profiler on, `profile_saved`.
  The hosting platform parses them: the line format is a fixed contract
  (fields may be added, never renamed, removed or reinterpreted), owned by
  the [module guide](docs/technical/module-guide.md#performance-log-lines);
  the monitor's per-step work stays constant (nothing per player or object).
