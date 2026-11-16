# AGENTS.md — Project Guide

MMO-inspired Luanti game, titled "Grudgelands". This file holds the working
rules every agent needs, whatever its task; every fact has one owner and the
others link to it
([owners](docs/process/documentation.md#one-owner-per-fact)): the version,
production and push state in [docs/STATUS.md](docs/STATUS.md); goals in
[ROADMAP.md](ROADMAP.md); open work in [BACKLOG.md](BACKLOG.md); how a round
runs, its gates and the review checklist in the [round
workflow](docs/process/round-workflow.md); which check to run after which
change in [checks.md](docs/process/checks.md); model routing in the [agent model
policy](docs/process/agent-model-policy.md); which mod owns what in the [mod
map](docs/technical/mod-map.md); Lua and engine rules in
[luanti-lua.md](docs/technical/luanti-lua.md); a topic's rules in the
documents its row in [Topic routing](#topic-routing) names; everything else
from [docs/README.md](docs/README.md). **Current state:** STATUS is the one
snapshot; check the live state with `git status -sb`, `git log --oneline -5`
and `git tag -l`.

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
- **The word is Expedition,** for players, in docs, briefs and code. Never the
  old word.
- **The web build is a target system** next to desktop: both are tested, and
  effects keep the particle budget ("Performance").
- **Model routing:** the user decides per session which model coordinates,
  implements and reviews; the policy's roles are defaults. Independent review of
  every non-trivial change stays mandatory. Native subagents within a provider,
  CLI delegation only across providers; the channel changes mechanics, not
  authorization or review duties ([execution
  channel](docs/process/agent-model-policy.md)).
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
  map-bound (or world generation changed; the one exception is a composition
  rewritten inside its unchanged box, upgrade contract §5.9), otherwise a migration (a removed
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
3. **[BACKLOG.md](BACKLOG.md)** — open work by topic (work packages, and a
   one-line item per carry-over that is still wanted, linking to its round
   plan's "Carry-overs"); items reference `docs/design/` instead of inventing
   design.
4. **`docs/technical/`** — how the implementation works: the
   [module guide](docs/technical/module-guide.md) holds the seams per area,
   each area's section starting with its **Rules** where it has any.

**[README.md](README.md)** is the player-facing entry point, **derived, never
authoritative**. The round log is the player changelog
[CHANGELOG.md](CHANGELOG.md), one entry per round. A round's end writes three
things (the CHANGELOG entry, the plan's "Completion" and "Carry-overs", the
STATUS row) and appends nothing to AGENTS.md
([round workflow](docs/process/round-workflow.md#4-lane-d-and-the-post-merge-status-step));
AGENTS.md changes only when a working rule changes.

## Working method

- **Session start:** read [STATUS](docs/STATUS.md), then the current round plan
  (`docs/planning/round<NN>-plan.md`) or the task the user names; check for
  `TODO-*.md` files that block it. Before touching a topic, read the documents
  its row in [Topic routing](#topic-routing) names; never infer current
  behaviour from an old report.
- **Rounds and lanes:** work runs in rounds planned with the user, as lanes on
  `r<NN>-<lane>` branches in `.claude/worktrees/`, each independently reviewed
  and merged by the coordinator. Flow, gates, review checklist, brief rules and
  templates: [round workflow](docs/process/round-workflow.md).
- **One commit per round on main (user, 2026-11-09):** every round, and every
  follow-up release such as a fix round after a human test, is built on its
  own local round branch `round<NN>`; lanes branch from it and merge into it,
  never into main. The coordinator lands it on main as **one squash commit**
  and tags the branch tip `round-<NN>` before deleting the branch
  ([round workflow §2](docs/process/round-workflow.md#2-a-round-step-by-step)).
  The tag is pushed with main, on the user's word.
- **Findings are hypotheses:** check a review finding, report claim or error
  message at the cited place before acting on it.
- **Rough targets, not hard gates:** new rules are guide values; checks only
  where gameplay would otherwise break; in doubt, ask the user.
- **Escalate** a fix that makes the design clearly more complex or world
  generation noticeably slower; do not solve or accept it alone.
- **Optional features and complexity (user, 2026-10-24):** ask before adding
  a complex interaction or workaround for an optional feature; offer omission
  or simplification as an alternative. Do not build the mechanism first.
- **Human tests on demand** (user, 2026-11-16): the user and the community
  test in the game (Flatpak Luanti GUI, desktop and web build); a round does
  not end with a GUI checklist. An agent proposes a short human test when it
  is unsure whether something works as planned or a human test is otherwise
  sensible ([round workflow](docs/process/round-workflow.md)).

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
  texture or generator change run its check
  ([checks.md](docs/process/checks.md); [presentation
  contract](docs/technical/ui-presentation.md)).
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
  never runs twice. The one shared queue
  (`~/projects/grudgelands-orchestration/r45/lua_run.sh`) enforces the cap.
- The reference checkout is **Luanti 5.18.0**, a read-only source; a newer
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
- Many topics have one path every caller uses (the price module, the travel
  path, the sound play helper, the Expedition spawn, grug_quality's store
  path); the topic's Rules in the module guide name it ([Topic
  routing](#topic-routing)).
- Persistence: player data → `player:get_meta()` (structures via
  `core.serialize`); mod-wide data → `core.get_mod_storage()` (fetched at load);
  node data → `core.get_meta(pos)`.
- **Terrain-damage guard (user, 2026-09-19):** towns, starts, capitals and POIs
  are never damaged. Anything that writes or removes nodes from mobs, combat,
  fire, explosions or lava asks `grug_core.world_alterable(pos)`; the two
  recorded exceptions are the rift's crack and settlement NPCs opening and
  closing doors (`grug_mobs/npc_doors.lua`, Round 42 ruling 15).
- **Personal notices go to the message feed** (`grug_core.feed`), never chat;
  chat keeps deaths, rare sightings, boss and dragon warnings.
- **Performance basics:** throttle every `register_globalstep` with a dtime
  accumulator; node timers for stations; LBMs only for current-version
  activation; ABMs only for ambient events (`chance`/`interval`, `catch_up =
  false`); `core.get_node_raw`, content ids and VoxelManip in hot loops.

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

### Sound

- **Approval gate (user, 2026-10-04):** no sound file ships unless the user
  picked that exact file on a listening page, recorded in an `approved.txt` the
  fixture checks every `.ogg` against. An event without an approved file stays
  silent, never a placeholder; a changed cut needs a new pick. Every file has a
  `LICENSE-media.md` row; attribution licences also go into
  [CREDITS.md](CREDITS.md). Rules: [sound.md](docs/design/sound.md).
- **Downloads:** reuse downloaded material first, access Freesound serially
  with HQ previews only, never delete or move downloaded source material.

### Topic routing

Before touching a topic, read its module guide section (its **Rules** block
first) and its design files; after the change, run what
[checks.md](docs/process/checks.md) names for it. The rows keep the names of
the topic sections this file had until 2026-11, which code comments still cite.

| Topic | [Module guide](docs/technical/module-guide.md) sections | Design and format files |
|---|---|---|
| Zone content: mobs, spawns, loot, names | ["Mob sub-types, loot and spawn regions"](docs/technical/modules/mobs.md#mob-sub-types-loot-and-spawn-regions), ["Mobs"](docs/technical/modules/mobs.md#mobs), ["Traders and money"](docs/technical/modules/items-professions.md#traders-and-money) (loot prices) | [spawn_regions.md](docs/design/spawn_regions.md), [economy.md](docs/design/economy.md), [biomes_mobs.md](docs/design/biomes_mobs.md), [zone_mobs.md](docs/design/zone_mobs.md) |
| Economy and travel: prices, vendors, travel, gems | ["Traders and money"](docs/technical/modules/items-professions.md#traders-and-money), ["Travel"](docs/technical/modules/player-systems.md#travel), ["Materials and tier-rock gating"](docs/technical/modules/items-professions.md#materials-and-tier-rock-gating) | [economy.md](docs/design/economy.md), [home_travel.md](docs/design/home_travel.md), [items_crafting.md](docs/design/items_crafting.md) |
| The Miner's Guild | ["Miner's Guild"](docs/technical/modules/items-professions.md#miners-guild) | [miners_guild.md](docs/design/miners_guild.md) |
| Expeditions | ["Expeditions"](docs/technical/modules/expeditions.md#expeditions) | [expeditions.md](docs/design/expeditions.md), [expedition-template-format.md](docs/technical/expedition-template-format.md) |
| PvP, factions and looks | ["PvP"](docs/technical/modules/combat-classes.md#pvp), ["Factions and character creation"](docs/technical/modules/combat-classes.md#factions-and-character-creation), ["Looks and enchant colours"](docs/technical/modules/ui-looks.md#looks-and-enchant-colours), ["Player meta read by external tools"](docs/technical/modules/platform.md#player-meta-read-by-external-tools) | [pvp.md](docs/design/pvp.md), [character_visuals.md](docs/design/character_visuals.md), [armor-format.md](docs/technical/armor-format.md), [offhand-format.md](docs/technical/offhand-format.md) |
| Combat, input and notices | ["Combat and classes"](docs/technical/modules/combat-classes.md#combat-and-classes), ["Mobs"](docs/technical/modules/mobs.md#mobs) | [combat_stats.md](docs/design/combat_stats.md), [classes.md](docs/design/classes.md), [skill_trees.md](docs/design/skill_trees.md), [ability_targeting.md](docs/design/ability_targeting.md), [upstream-workarounds.md](docs/technical/upstream-workarounds.md) §1 |
| Items, professions and achievements | ["Professions"](docs/technical/modules/items-professions.md#professions), ["Enchantments"](docs/technical/modules/items-professions.md#enchantments), ["Crop registration"](docs/technical/modules/items-professions.md#crop-registration), ["Cloaks and achievements"](docs/technical/modules/ui-looks.md#cloaks-and-achievements), ["World version and migrations"](docs/technical/modules/platform.md#world-version-and-migrations) (bag sizes) | [item_tiers.md](docs/design/item_tiers.md), [professions.md](docs/design/professions.md), [items_crafting.md](docs/design/items_crafting.md), [inventory_equipment.md](docs/design/inventory_equipment.md), [farming.md](docs/design/farming.md) |
| Sound and ambience | ["Sound"](docs/technical/modules/ui-looks.md#sound) | [sound.md](docs/design/sound.md) |
| Quests, main line, rift and decor | ["Quests"](docs/technical/modules/player-systems.md#quests), ["The rift"](docs/technical/modules/mobs.md#the-rift), ["Mapgen and biomes"](docs/technical/modules/mapgen.md#mapgen-and-biomes) (the decor pass) | [quests.md](docs/design/quests.md), [story.md](docs/design/story.md), [world.md](docs/design/world.md) §4b, [settlements.md](docs/design/settlements.md) |
| World generation and town buildings | ["Mapgen and biomes"](docs/technical/modules/mapgen.md#mapgen-and-biomes), ["Preparation"](docs/technical/modules/mapgen.md#preparation) | [world.md](docs/design/world.md), [world_zones.md](docs/design/world_zones.md), [settlements.md](docs/design/settlements.md), [building-template-format.md](docs/technical/building-template-format.md) |
| Upgrades, migrations, saved state | ["World version and migrations"](docs/technical/modules/platform.md#world-version-and-migrations) | [upgrade-contract.md](docs/technical/upgrade-contract.md) |
| Mounts and boats | ["Mount runtime"](docs/technical/modules/player-systems.md#mount-runtime) | [mounts.md](docs/design/mounts.md), [boats.md](docs/design/boats.md) |
| Housing, parties, clans, mail | ["Housing"](docs/technical/modules/player-systems.md#housing), ["Parties"](docs/technical/modules/player-systems.md#parties), ["Mail"](docs/technical/modules/player-systems.md#mail) | [housing.md](docs/design/housing.md), [parties.md](docs/design/parties.md), [clans.md](docs/design/clans.md), [mail.md](docs/design/mail.md) |
| The website: web bridge, accounts, performance lines | ["Web bridge"](docs/technical/modules/platform.md#web-bridge), ["Website accounts"](docs/technical/modules/platform.md#website-accounts), ["Performance log lines"](docs/technical/modules/platform.md#performance-log-lines), ["Player meta read by external tools"](docs/technical/modules/platform.md#player-meta-read-by-external-tools) | [web-bridge.md](docs/technical/web-bridge.md), [web-accounts.md](docs/technical/web-accounts.md), [accounts.md](docs/design/accounts.md) |
| UI, windows, map and text in the world | ["UI and formspecs"](docs/technical/modules/ui-looks.md#ui-and-formspecs), ["Atlas"](docs/technical/modules/player-systems.md#atlas), ["World atlas rules"](docs/technical/modules/player-systems.md#world-atlas-rules), ["Text in the world"](docs/technical/modules/ui-looks.md#text-in-the-world) | [ui-presentation.md](docs/technical/ui-presentation.md), [world_map.md](docs/design/world_map.md) |

A topic not in the table: find its owning mod in the [mod
map](docs/technical/mod-map.md) and its section in the [module
guide](docs/technical/module-guide.md).

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

- **Checks:** which check after which change is in
  [checks.md](docs/process/checks.md); which fixtures run when (lanes,
  reviewers, the coordinator, follow-up rounds) and when the seed fleet
  (`tools/seed_fleet/run.sh quick|full`) is required, in [round workflow
  §3](docs/process/round-workflow.md#3-gates), the rule's one owner.
- **Fixtures:** `tools/run_fixtures.sh` runs every portable fixture under
  LuaJIT; a new one takes the repository path as `arg[1]` and exits non-zero on
  failure. Fixture and probe folders per round:
  [tools/README.md](tools/README.md).
- **Engine-run budget** (user, 2026-09-28): portable fixtures are the main
  proof; a few engine runs of at most about 5 minutes; one final run of about 15
  minutes over a chosen small region (ocean, coast, mountain, one start),
  bounded by region and ended by a normal shutdown. Never a full world or a
  repeated long run; reviewers read the receipts. Derive bounds from parameters
  instead of scanning; more goes to the user first.
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
- Server log via `core.log("action"|"warning"|"error", msg)`. An error the
  server survives but an administrator must see goes through the one
  severe-error helper `grug_core.severe.report(source, summary, details, key)`
  (`grug_core/severe.lua`): an error line with the literal prefix
  `[GRUG-SEVERE]` and a red chat message to every player once per key; the
  mapgen environment loads the same file by `dofile` and its chat part
  reaches the main thread through gen_notify.
- The `[GRUG-PERF]` server-log lines (`grug_perf`) are a fixed contract with
  the hosting platform: fields may be added, never renamed, removed or
  reinterpreted, and the monitor's per-step work stays constant ([module
  guide](docs/technical/modules/platform.md#performance-log-lines)).
