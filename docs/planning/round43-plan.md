# Round 43 — World migrations: the foundation

Coordinator: Claude (Opus 5.5), drafted 2026-10-08 from the hosting
platform's migration contract (revision 2) and the user's sequencing. The
contract lives outside this repository:
`~/projects/kaesual-stack/.local/grudgelands-migration-contract-task.md`
("the contract" below; requirement numbers R1–R9 refer to it). Revision 2
already adopts this project's feedback on the first draft: the lock wording,
conservative new-world recognition, online work per world and per
character, the map-block API deferred, the baseline rule, and the foundation
as its own release.
Status: **complete** (2026-10-08, version 0.43.0, pushed 2026-10-09;
[completion](#completion-2026-10-08) with the platform summary).
Ran **in parallel with Round 44's wave 1** (§7).

Why now: the UI rework and the crafting rework
([ui-crafting-rework-plan.md](ui-crafting-rework-plan.md)) change saved
character state. Today that means "new server". The contract adds a fourth
upgrade outcome, **migrate**: an offline tool converts a stopped world, and
the game finishes online work per world at load and per character at join.
This round builds that foundation and ships it **alone**, as 0.43.0 with an
empty `migrate` list. The platform builds and accepts its runner on that
release. The first real step comes with the UI rework in a later version,
and the platform adopts it only once its runner is in production.

Routing default (agent model policy; the user decides per session): Claude
coordinates, Opus implements and reviews; no Astra lane.

## 1. Lanes and waves

| Lane | What | Wave | Kind | Waits for |
|---|---|---|---|---|
| GS | Game side: world version record, start guard, new-world recognition, online-work markers and their runner, the guard's `migrate` list; schema 2 declaration and `check_upgrade.py` | 1 | code (Lua + Python) | Round 42 complete |
| MT | The migration tool: `tools/migrate.py`, world opening (SQLite and PostgreSQL), check mode, exit codes and output events, the data API (characters, auth, mod storage) and the codecs | 1 | code (Python) | Round 42 complete |
| IT | Integration tests: test-only steps end to end (world at the previous version → tool → headless boot → online work at load and at a join), the guard tests, one PostgreSQL run | 2 | tests | GS and MT merged |
| D | Docs and release: AGENTS.md "Release mode", the upgrade contract doc, the round workflow, the self-hosting section, version 0.43.0, CHANGELOG, the final summary for the platform (R9) | 3 | docs | IT merged |

GS and MT run in parallel against the shared conventions of §3; they share
no files. Estimates (unmeasured, for planning only): GS 6–8 h, MT 8–12 h,
IT 4–6 h, D 2–3 h, each plus its review.

## 2. Rulings

The user (2026-10-08):

1. **The contract is binding** (revision 2). Points marked "Grudgelands
   decides" are ours. Anything else that is ambiguous or conflicts with the
   code stops the lane and goes to the coordinator, who asks the user (and,
   through the user, the platform) before choosing.
2. **The foundation ships alone** as 0.43.0. `migrate` stays empty; the tool
   is proven with test-only steps that live in the tests and are never
   declared. The first real step comes with the UI rework (Round 44 in the
   current order), in a later version.
3. **Order of rounds:** 43 the migration foundation, 44 the UI rework
   (Round A of the rework plan), 45 the crafting rework (Round B).
4. **Map blocks are deferred** (contract R5): no block parsing or writing in
   this round. The round that first needs them adds block format v29, both
   SQLite `blocks` layouts and the round-trip test.
5. **Keep it minimal** (contract and AGENTS.md): no mechanism for a case
   that does not occur. A test-only hook in the tool is fine; nothing in the
   shipped command line exposes it.

## 3. Shared conventions (coordinator defaults, the lanes may refine them in their report)

These fix the interface between GS and MT so both can work in parallel.

- **Tool path:** `python3 tools/migrate.py --world <dir>` and
  `python3 tools/migrate.py --world <dir> --check`, run from the repository
  root. The package next to it is `tools/migration/` (not `tools/migrate/`,
  which would shadow the script on import): helpers, the data API and
  `steps/`, one file per declared version (`v0_44_0.py` style).
- **World record:** mod storage of `grug_core`, key `world_version`, a
  `major.minor.patch` string (contract R6).
- **Online-work markers** (contract R6; the map reset's two-level pattern,
  `grug_core/map_reset.lua:4-21`):
  - world part: `grug_core` mod storage, key `migrate_world:<version>`;
  - character part: player meta `grug_core:migrate:<version>`;
  - a step that leaves online work writes its markers in the step's
    per-backend transactions; the game finishes the world part at the next load and each
    character's part at that character's next join, in step order, and
    then deletes the marker.
- **The game's step registry:** `grug_core.migrations` in a runtime-tree
  file under `mods/CORE/grug_core/` holds the list of `migrate` versions the
  guard compares against (contract R7) and the online handlers per version
  (`world` and `character` functions). `tools/check_upgrade.py` proves the
  list equal to the declaration's `migrate` list.
- **Declaration:** `tools/web_data/upgrade.json` at schema 2. GS converts
  it with `version` still equal to `game.conf`'s (the check requires it);
  lane D bumps both to 0.43.0, ending at
  `{"schema": 2, "version": "0.43.0", "map_reset": ["0.40.1"],
  "new_server": [], "migrate": []}`.
- **Test-only steps:** GS provides one hook, read before the guard, through
  which a test registers undeclared step versions (their guard entries and
  online handlers); it is inert in a shipped game (for example enabled only
  by a setting no shipped config sets). MT provides the matching tool hook.
  Test step versions are at most the branch's `game.conf` version.
- **Test environment:** the tool's tests run in a `debian:trixie` container
  (Podman) with Debian's `python3` 3.13, `python3-psycopg` and
  `python3-zstandard`, exactly the platform's runner; the PostgreSQL test
  against a throwaway `postgres` container. The workstation's own Python is
  3.14 and is not the test target.

## 4. Lanes (goals; the briefs add file facts)

Every lane classifies its change (R1: compatible, map reset, migrate or new
server). This round is expected to be **compatible**: a 0.42 world boots
under 0.43, its missing record counts as 0.41.0, no `migrate` entry lies
between, and the game stamps 0.43.0.

### 4.1 Wave 1 — GS, the game side

- The **start guard** (R7): at load, before any mod reads or writes saved
  state (map-reset clears included), compare `world_version` with the
  game's version. A newer world, or a `migrate` entry between them, refuses
  to start with the contract's messages (both versions and "downgrade to
  <record> to continue"; the step, "back up the world and run the tool" and
  the command line).
  - Verify that no mod loading before the guard writes saved state at load;
    add a tiny first-loading guard mod if needed. Verify, in the engine
    sources and with one boot, whether the engine writes anything after a
    mod-load error. Report both (the platform asked for it).
- The **record** (R6): written by the game at load when no `migrate` entry
  lies between, once the load succeeded; a missing record on an existing
  world counts as 0.41.0 (a 0.40.0 world arrives only with the 0.40.1 map
  reset and is treated the same).
- **New-world recognition** (R6), conservative: a world is new only when it
  has no characters and no saved game state; in doubt, existing. The lane
  chooses the method and lists exactly what "saved game state" it looks at.
  "Characters" are rows of the player backend, never auth entries (a platform
  may create auth entries before the first boot).
- **Online work** (R6, §3): the runner that finishes pending world markers
  at load and character markers at join, in step order, and deletes each
  marker after its handler succeeded. A failing handler stops the load (world
  part) or holds the character with a clear error, like the map reset does;
  it never deletes the marker. When a join also carries a map-reset
  relocation, the lane fixes and reports the order (migration work first is
  the default: it repairs saved data the relocation may read).
- The world part of online work runs after every map-reset clear (R1:
  a step never relies on map-bound storage).
- `tools/check_fresh_server.py` and its docstring follow the new rule
  ("migrations only through the tool").
- The guard runs before the map-reset clears; a move that combines a map
  reset with a step (the platform empties the map, runs the tool, raises
  `grug_reset_world`) passes the guard and then resets.
- **Declaration and check** (R2): schema 2 in `upgrade.json`;
  `tools/check_upgrade.py` checks the new list with the same rules as the
  other two (ascending, never edited or removed, at most `version`, new
  entries only with a version bump, the crossing rule), that each declared
  step file exists and is unchanged against `origin/main`, and that the
  game's `grug_core.migrations` list equals the declaration. Its self-test
  covers the new rules (the "schema 1 only" case flips); `compare()` accepts
  a pushed schema-1 declaration without a `migrate` key; `outcome()` learns
  the fourth outcome (new server wins; map reset and migrate combine).
- Fixtures (`tools/r43_gs/portable_test.lua`) for the guard decision, the
  record rules, new-world recognition and the marker order.

### 4.2 Wave 1 — MT, the migration tool

- **Invocation, check mode, exit codes and output** exactly as R3: due steps
  in ascending order up to `game.conf`'s version; `--check` reports the world
  version and the due steps and proves write access on every backend it uses
  with a real write rolled back (SQLite under `BEGIN IMMEDIATE`); a lock it
  cannot acquire is exit 2; exit 2 only before anything was written, exit 1
  after; one JSON object per line on stdout (start, refusal with reason, step
  start, step done with counts, done), human text on stderr. The tool cannot
  detect a running server and says so in `--help`.
- **Opening a world** (R4): `world.mt` only; `player_backend`,
  `auth_backend`, `mod_storage_backend` (`sqlite3` or `postgresql`) and the
  matching `pgsql_*_connection` strings passed to libpq unchanged; anything
  else is exit 2. No password in `world.mt` or on the command line required
  (`PGPASSFILE`). The engine's standard table layouts from
  `reference_projects/luanti/src/database/` (5.17). Never writes `world.mt`,
  never creates, alters or drops a table.
- **The data API** (R5, now): list all characters (offline ones too); read
  and write player meta, inventories (lists, sizes, items with meta) and
  position; read auth and write privileges; read, write and delete mod-storage
  keys per mod; the escape hatch: a step may use the raw SQLite or
  PostgreSQL connection of a backend. One transaction per backend per step;
  the world version write sits in the step's mod-storage transaction. A step
  can never create, rename or delete a character or an auth entry, nor
  change a table layout.
- The tool reads the record like the game: missing on an existing world =
  0.41.0. It never creates a database file (SQLite opened read-write without
  create, `mode=rw`); a world whose databases do not exist is refused with
  exit 2.
- **Codecs:** `core.serialize` / `core.deserialize` for the subset the game
  writes, verified against `builtin/common/serialize.lua`;
  `core.write_json` / `core.parse_json` as the game uses them; item strings
  with count, wear and meta (the engine's escaping), verified against
  `src/inventory.cpp` / `src/itemstackmetadata.cpp`.
- Dependencies: the standard library plus `psycopg` 3, imported lazily for
  PostgreSQL worlds only. No `zstandard` yet (the map part is deferred). A
  `requirements.txt` with exact versions for self-hosters.
- Unit tests for the codecs (round trips against strings the engine wrote),
  world opening and refusals, check mode and exit codes, on SQLite; the
  PostgreSQL paths get their real run in IT. The container run works from a
  `git archive` export of the branch (no `reference_projects/`, no
  gitignored `tools/bin`), which proves the tool needs nothing outside what
  the platform's runner gets.

### 4.3 Wave 2 — IT, integration tests

- **Steps end to end** (R8), with test-only steps that are never declared:
  build a minimal world with the current code, mark it as the previous
  version, run the tool with the test step, boot the game headless on the
  result, then check. One step writes offline data only; one leaves online
  work at load; one leaves per-character online work, checked at a join of
  an affected character and an unaffected one; two pending character
  markers finish in step order.
- **The guard** (R8): a newer world is refused; a world crossing a step is
  refused (with the expected message); a compatible move bumps the record;
  a new world is stamped; an existing world without characters but with
  saved state is not taken for new.
- **Map reset combined with a step** (R1): one run in the platform's order
  (empty the map, run the tool with a test step, raise `grug_reset_world`,
  boot) ends with the step applied, the map reset done and the record at the
  new version.
- **PostgreSQL:** one run against a throwaway PostgreSQL covers every
  PostgreSQL code path of the tool. Whether the local Luanti build can run a
  world on PostgreSQL is unverified; if it cannot, the test seeds the
  PostgreSQL tables from an engine-written SQLite world using the engine's
  own PostgreSQL schema, and says so.
- Engine runs only through `tools/luanti_headless.sh` (minimal worlds, the
  mapgen run budget, at most two measuring engine runs at once); the Round 41
  map-reset engine test (`tools/r41_up/engine.sh`) is the pattern.

### 4.4 Wave 3 — D, docs and release

- AGENTS.md "Release mode": "No data migrations" becomes "migrations only
  through the tool, with a test"; the four outcomes; the baseline rule.
- `docs/technical/upgrade-contract.md`: the fourth outcome, the declaration
  at schema 2, the tool, the record, the markers, the guard; the change table
  gains "migrate" rows (removed items, restructured character state).
- The round workflow: §3 and §5 item 6 name four outcomes; the gates add
  "each declared step has its test" and, whenever `tools/migrate.py` or
  `tools/migration/` changes, the container run of **every** declared step's
  test (old steps run on the shared helpers), and the online-work fixtures
  of every declared step stay in `tools/run_fixtures.sh` for good (old
  handlers run against new game code; the user, 2026-10-08); the templates
  `common-brief.md` and `review-common.md` follow.
- AGENTS.md also records that `origin/main` history is never rewritten
  (contract R8: the platform fetches released commits); the module guide
  names the new `grug_core` parts, a guard mod if any, and the tool.
- A short **self-hosting** section (README's hosting paragraph or its own
  page): stop the server, back it up, run the tool, then start.
- `game.conf` 0.43.0, the declaration's `version`, the CHANGELOG entry;
  `tools/r37_dc` is run (it reads `game.conf`); the status owners (STATUS,
  the AGENTS pointer, ROADMAP, BACKLOG, README) as every lane D.
- The plan's completion with the **final summary for the platform** (R9):
  command line, exit codes and output events, tested Python and dependency
  versions, the data API and codecs, the record, the markers, the guard's
  placement and messages, new-world recognition, the version (0.43.0) and
  its declaration, and every "Grudgelands decides" choice. The platform needs
  the release version for its schema-2 producer.

## 5. Rules

- Stock clients only; the game side is plain Lua 5.1 (AGENTS.md).
- The tool runs on Python 3.13 with Debian trixie's packages only; nothing
  from PyPI is required on the platform.
- No world-generation change: no seed fleet.
- The tool never touches anything outside the world's tables and its world
  directory. No test ever touches the user's own Luanti folder or worlds
  (`tools/luanti_headless.sh` isolation).
- Classification: compatible (§4). A lane that finds otherwise stops and
  reports.

## 6. Verification

Per lane the gates of the [round workflow](../process/round-workflow.md#3-gates);
for the Python lanes the container test run replaces the Lua gates; the
declaration check at the round end.

GUI checklist (desktop and web), short because nothing visible changes:

- A world from 0.42.0 boots under 0.43.0 and plays on; Help → About shows
  0.43.0.
- A fresh world boots and plays.
- Optional, on a copy of a local world with the server stopped:
  `python3 tools/migrate.py --world <copy> --check` reports the world's
  version (0.41.0 before its first start under 0.43.0, else 0.43.0), the
  target 0.43.0 and no due steps.

## 7. Orchestration notes

- Start state: main after Round 42's lane D (the user's go).
- **Parallel with Round 44** (the user, 2026-10-08): Round 44's wave 1
  (IH, FR, AR, MB) starts together with this round in its own worktrees.
  The two rounds share no files except the status owners lane D edits
  (STATUS, CHANGELOG, AGENTS, `game.conf`, the declaration); Round 44's MS
  later edits `grug_core.migrations` and `tools/migration/steps/`, strictly
  after this round has merged. This round
  merges first; Round 44 merges nothing to main before 0.43.0 is complete
  and pushed, so the user's push of 0.43.0 carries no Round 44 work. The
  process budget is shared (8 Lua processes, two measuring engine runs;
  containers count).
- Process budget: at most 8 Lua processes at once (AGENTS.md); engine runs
  only through `tools/luanti_headless.sh`; containers count as processes.
- Files per lane:
  - GS: `mods/CORE/grug_core/` (the guard, the record, the migrations
    registry, the marker runner; possibly a tiny first-loading guard mod),
    `tools/web_data/upgrade.json`, `tools/check_upgrade.py`, `tools/r43_gs/`.
  - MT: `tools/migrate.py`, `tools/migration/`, `tools/r43_mt/` (tests and
    the container script), `requirements.txt` under `tools/migration/`.
  - IT: `tools/r43_it/` (engine script, probe mod, test-only steps).
  - D: the docs above, `game.conf`, `CHANGELOG.md`, `tools/r37_dc`.
- Merge order GS, MT, then IT, then D.
- Decided during the round: the new-world method (GS), the guard placement
  (GS), the test hooks for undeclared steps (GS in the game, MT in the
  tool).

## 8. Open questions for the user

None blocking. The model routing (§ intro) is the default; say if this
round should run differently.

## Completion (2026-10-08)

Every lane is merged on main; lane D (this section, the rule documents and
the status owners) follows. Main's first-parent line from the start
(`332c5e79`, 0.42.0, origin/main): GS (`422d4879`), MT (`e2b749bb`), IT
(`328010b5`) and the coordinator's HUD fix (`d10018a7`). Push: origin/main
is `332c5e79` (0.42.0, pushed by the user on 2026-10-08); **0.43.0 is not
pushed**. Nothing of Round 44 is on main or part of this release.

Reviews, each by an independent Opus, every fix made by the lane itself
before its merge:

- **GS** MERGE AFTER FIXES; one Medium (the join-order move asserted the
  raw callback and failed with the engine profiler on) and one Low (a fresh
  world whose first load failed later read as an existing 0.41.0 world),
  fixed by the lane (`be7420e3`): the registered entry is moved as it
  stands, and a new world is stamped at the guard.
- **MT** MERGE AFTER FIXES; two Lows (the `failed` event was lost when the
  error text held undecodable bytes; the tool's new-world rule was not the
  game's), fixed by the lane (`3fec857a`): events keep undecodable bytes
  escaped, and the tool's rule includes the game's; the interface went into
  `tools/README.md` (`f34802fb`).
- **IT** MERGE AFTER FIXES; one Medium (the "newer world" record was pinned
  to 0.43.0 and would have failed after this lane's bump) and a Low (no
  `tools/README.md` line), fixed by the lane (`e51f4012`): the newer record
  is derived from `game.conf`, the hook's steps are given out of order with a
  check that the guard sorts them, and the README line.

Round end on main `d10018a7` (the coordinator): `run_fixtures.sh` 130/130
(new: `r43_gs`), `check_fresh_server.py` PASS, `check_upgrade.py` PASS
(0.42.0 against origin/main), smoke boot PASS; lane IT's suite 59/59
(`tools/r43_it/run.sh`, on `e51f4012`). After this lane's bump:
`check_upgrade.py` PASS for 0.43.0 against origin/main, `tools/r37_dc`
PASS. No seed fleet: no world generation changed.

### Shipped, by lane

- **GS, the game side** (`422d4879`;
  [upgrade contract §5](../technical/upgrade-contract.md#5-migrations)):
  `grug_core/migrations.lua` (the registry: `versions`, empty, and the
  online handlers) and `grug_core/world_version.lua` (271 lines, loaded
  first in `grug_core`): the record, the start guard with the contract's
  two messages, new-world recognition, the test hook, the world-marker
  runner after every map-reset clear and the character-marker runner as the
  first join callback; the declaration at schema 2; `check_upgrade.py`'s
  `migrate` rules (the same list rules, the registry equal to the
  declaration, each step file present and unchanged once pushed, a pushed
  schema-1 base accepted, the fourth outcome); `check_fresh_server.py`
  refuses marker keys outside the runner. Fixture `r43_gs` 99 checks;
  `tools/r43_gs/refusal_boot.sh` with a smoke boot (seed 42, the record
  written) and a refused boot whose world files kept their hashes. `mods/`
  +312 −3 lines this round (with the HUD fix).
- **MT, the migration tool** (`e2b749bb`;
  [tools/README.md](../../tools/README.md#the-migration-tool)):
  `tools/migrate.py` and `tools/migration/` (`cli.py`, `world.py`,
  `data.py`, `codec.py`, `steps/`, `requirements.txt`; 1,696 lines of
  Python), an engine-written test world (`tools/r43_mt/world`, 76 KB, built
  by `make_world.sh`) and the unit tests: 38 OK, 2 skipped in the
  `debian:trixie` container (`container_test.sh`), including the check that
  the engine's `core.deserialize` reads the tool's output.
- **IT, integration tests** (`328010b5`; `tools/r43_it/`): two
  engine-written worlds, characters created by real joins through a
  minimal protocol client (`client.py`, SRP), every tool run in the
  container, five real boots and four refusal boots per run: test steps
  0.41.1–0.41.5 (offline meta, an item with meta, a privilege, mod-storage
  writes; a world marker at load; two character markers in step order on
  one character, a second character untouched), the guard (a crossing world
  refused with the command line and nothing written; a compatible move
  bumps the record; a new world stamped; an existing world without
  characters not taken for new; a newer and a malformed record refused by
  game and tool), a map reset combined with a step in the platform's order,
  and PostgreSQL. **59 checks, all PASS.** No bug found in GS's or MT's
  code.
- **Found on main and fixed:** `tools/r41_up/portable_test.lua` part F
  pinned the 0.41.0 declaration and failed on main after the 0.42.0 bump
  (Round 42's 129/129 ran before the bump); GS made it check the 0.40.1
  reset at `game.conf`'s version.
- **Coordinator fix** (`d10018a7`): the HUD text elements in
  `grug_core/feed.lua` and `grug_map/location.lua` pass `size = {x = n,
  y = 0}`, ending the engine's "Invalid vector coordinate y" deprecation
  warning on every join (found by IT; the engine plans to make it an
  error). Not visible to players.
- **D, this lane:** version 0.43.0 and the declaration, AGENTS.md "Release
  mode", the upgrade contract (§1 four outcomes, §2, the new §5), the round
  workflow's gates and review item 6 with both templates, the module guide
  and mod map, the README's hosting steps, the status owners.

### Upgrade classification and the declaration

| Lane | Outcome | Reason |
|---|---|---|
| GS | compatible | a 0.42 world has no record (0.41.0) and no `migrate` entry lies between: it passes the guard and is stamped 0.43.0; nothing else saved changes |
| MT | compatible | only `tools/` |
| IT | compatible | only `tools/r43_it/` |
| HUD fix | compatible | HUD sizes only |
| D | compatible | docs, `game.conf`'s version and the declaration |

The round's declaration:
`{"schema": 2, "version": "0.43.0", "map_reset": ["0.40.1"], "new_server": [], "migrate": []}`
(no new entry): a 0.42.0 world plays on.

### Decisions during the round

The user (2026-10-08), on the lanes' questions:

- **Keep the separate `failed` event** for exit 1 (MT's choice; the
  alternative was a `refusal` with code 1), and **exit 1 as soon as the
  first step has begun** (conservative: its transactions are open). Both
  go beyond the contract's event list and wording and need the platform's
  acknowledgement (summary below).
- **A missing `players.sqlite` or `auth.sqlite` counts as empty** (a
  never-joined world, which the game would otherwise refuse while the tool
  refused it too); **a missing `mod_storage.sqlite` stays exit 2**.
- **Lane IT builds its worlds with SQLite mod storage in its own world
  folder**: the headless launcher keeps files-backed mod storage, which the
  tool refuses.
- **The online-work fixtures of every declared step stay in
  `tools/run_fixtures.sh` for good** (now in the round workflow §3).

### Deviations from the plan

- **§4.2 "a world whose databases do not exist is refused":** only a
  missing `mod_storage.sqlite` is; missing player and auth databases count
  as empty (the user's decision above).
- **§4.1 guard mod:** none; the guard sits at the top of `grug_core`. A
  separate mod could not read `grug_core`'s storage (mod storage is bound to
  the loading mod), and the 21 mods that can load first write no saved
  state at load.
- **§4.1 record "once the load succeeded":** holds for existing worlds; a
  recognised new world is stamped at the guard (GS review fix), as R6
  allows.
- **§4.3 PostgreSQL:** the local Flatpak engine has no PostgreSQL backend,
  so IT seeded PostgreSQL from an engine-written SQLite world with the
  engine's own DDL (the route the plan named).
- **Not in §1's table:** the coordinator's HUD fix and GS's repair of
  `tools/r41_up` part F.
- **Estimates** (§1, unmeasured) were not tracked.

### Open notes

The reviews' and reports' backlog notes are in the
[BACKLOG](../../BACKLOG.md#round-43-carry-overs) (theoretical, no
severity). The first real step (with the UI rework, a later version) adds
map blocks only if it needs them (ruling 4) and adapts IT's suite, which
assumes an empty `migrate` list.

### GUI checklist

Plan §6; desktop and the web build. Nothing visible changes.

1. A world from 0.42.0 boots under 0.43.0 and plays on; Help → About shows
   0.43.0.
2. A fresh world boots and plays.
3. Optional, on a copy of a local world with the server stopped:
   `python3 tools/migrate.py --world <copy> --check` reports the world's
   version (0.41.0 before its first start under 0.43.0, else 0.43.0), the
   target 0.43.0 and no due steps.

### Final summary for the platform (contract R9)

From the code at main `d10018a7` plus this lane's version bump; the tool's
full interface is owned by
[tools/README.md "The migration tool"](../../tools/README.md#the-migration-tool).

**1. Command line.** From the repository root of a full export of the
target commit (every tracked file except `reference_projects/`):

```
python3 tools/migrate.py --world <dir>           # migrate
python3 tools/migrate.py --world <dir> --check   # report, change nothing
```

The tool migrates to the checkout's `game.conf` version and runs every due
step (declared `migrate` entries above the world's version, at most the
target) in ascending order. It cannot detect a running server (`--help`
says so). `--check` reports the world version and the due steps and proves
write access with a real write on every present backend, rolled back:
SQLite under `BEGIN IMMEDIATE` (busy timeout 5 s), PostgreSQL `BEGIN` with
`SET LOCAL lock_timeout = '5s'`; the write is the record in `grug_core`'s
mod storage, a probe row in `player` and in `auth` (an explicit id, so
PostgreSQL's sequence stays untouched).

**2. Exit codes.**

- `0`: migrated, nothing to do, or checked.
- `2`: refused or failed before anything was written: the world is newer
  than the tool, a backend or table layout is unsupported, `world.mt` is
  invalid, a database connection failed, a lock could not be acquired,
  a database file is missing (`mod_storage.sqlite`), the record is
  malformed, or the checkout is broken.
- `1`: failed after the first step began; the world is undefined, restore
  the backup. **Addition for the platform to acknowledge:** exit 1 applies
  as soon as the first step's transactions are open, even if that step had
  not written yet (conservative); only a lock that the first step could not
  take is still exit 2 `lock`.

**3. Output events** (stdout, one JSON object per line, non-ASCII escaped,
the last line is the result; stderr carries the same as text):

| Event | Fields | When |
|---|---|---|
| `start` | `mode` (`migrate` or `check`), `world` (absolute directory) | first (a usage refusal comes alone) |
| `step_start` | `step`, `from` | a step begins |
| `step_done` | `step`, `counts` (`characters`, `player_meta`, `inventories`, `positions`, `privileges`, `mod_storage`, `markers`) | a step committed |
| `done` | `mode`, `world_version` (before the run, `null` for a new world), `record`, `new_world`, `target`, `due`, `backends` (`sqlite3`, `postgresql` or `absent` per kind), `applied` or `write_checked` | exit 0 |
| `refusal` | `reason`, `message` | exit 2 |
| `failed` | `step` (or `null`), `reason`, `message` | exit 1 |

Refusal reasons: `usage`, `checkout`, `world_mt`, `backend`,
`database_missing`, `connection`, `layout`, `lock`, `write_access`,
`record`, `world_newer`, `internal`. Failure reasons: `lock`, `step`,
`rule`, `commit`. **Addition for the platform to acknowledge:** the
`failed` event (exit 1) is not in the contract's event list (start,
refusal, step start, step done, done).

**4. Tested versions.** The tool's unit tests and every tool run of the
integration suite ran in a `debian:trixie` container (Debian 13) with
Debian's packages: Python 3.13.5, psycopg 3.2.6 (`python3-psycopg`), libpq
17.11, SQLite 3.46.1; `python3-zstandard` 0.23.0 installed but unused (no
map part yet). PostgreSQL server 17.11 (Debian 17.11-0+deb13u1) for the
PostgreSQL run. `tools/migration/requirements.txt` pins `psycopg==3.2.6`
for self-hosters.

**5. Opening a world.** `world.mt` only: `player_backend`,
`auth_backend`, `mod_storage_backend` (`sqlite3` or `postgresql`; a missing
key means `files` and is refused like leveldb) and
`pgsql_player_connection`, `pgsql_auth_connection`,
`pgsql_mod_storage_connection`, passed to libpq (psycopg rebuilds the
conninfo with equivalent parameters: `service=`, URIs, multi-host,
`passfile` and environment defaults kept). No password is needed in
`world.mt` or on the command line (`PGPASSFILE`). The engine's 5.17 table
layouts are checked (`world.py` `LAYOUTS`); SQLite files are opened with
`mode=rw`, never created. A missing `players.sqlite` / `auth.sqlite` counts
as empty; a missing `mod_storage.sqlite` is exit 2 `database_missing`.

**6. The data API and codecs** (`tools/migration/data.py`, `codec.py`). A
step is `tools/migration/steps/v<major>_<minor>_<patch>.py` with
`migrate(world)`; one transaction per backend per step, committed player,
auth, then mod storage with the record; any exception rolls all back.

- characters: `characters()` (rows of the player backend, offline ones
  included), `get_meta`/`set_meta`, `get_inventory`/`set_inventory` (lists
  with size, width and `ItemStack`s with count, wear and meta),
  `get_position`/`set_position` (in nodes);
- auth: `auth_names()`, `get_auth(name)`, `set_privileges(name, privs)`;
- mod storage: `mods()`, `storage(mod).get/set/delete/items/keys`;
- markers: `mark_world(value)`, `mark_character(name, value)`;
- escape hatch: `raw(kind)` (the sqlite3 or psycopg connection inside the
  step's transaction), `engine(kind)`;
- limits, checked after the step and before any commit, raw writes
  included: no character or auth entry created, renamed or deleted, no
  schema change, no write of the record (exit 1 `rule`, every backend
  rolled back);
- codecs: `serialize`/`deserialize` (`builtin/common/serialize.lua`,
  references and cycles read, LuaJIT's `%q` mirrored), `parse_json`/
  `write_json`, `ItemStack.parse`/`to_string` (`inventory.cpp`,
  `itemstackmetadata.cpp`); every engine string without references round-
  trips byte for byte. Map blocks are deferred (ruling 4).

**7. The record.** `grug_core` mod storage `world_version`,
`major.minor.patch`. Missing on an existing world = 0.41.0; a 0.40.0 world
counts the same. The tool writes it after each step in that step's
mod-storage transaction and writes nothing when nothing is due. The game
writes its version when no step lies between: a new world at the guard, an
existing world at the first server step after a successful load.

**8. The markers.** World part: `grug_core` mod storage
`migrate_world:<version>`, run once every mod has loaded (after every
map-reset clear). Character part: player meta `grug_core:migrate:<version>`,
run in the first join callback of all, before the map reset's relocation.
Values default to `"1"` and reach the handler. Several pending markers run
in step order; each is deleted only after its handler succeeded. A failing
world handler stops the load; a failing character handler reports
`[GRUG-SEVERE]`, disconnects the player and keeps the marker.

**9. The guard: placement and messages.** At the top of `grug_core`'s
`init.lua`, before anything of the game reads or writes saved state (the
map-reset clears included); no separate guard mod (a mod's storage is bound
to that mod). The mods that can load before `grug_core` (21, everything not
depending on it) write no saved state at load. After a mod-load error the
engine skips the environment's saves but still commits the mod-storage
transaction (`server.cpp`, `~Server`); the guard writes nothing before it
refuses, and a refused boot left every world file's hash unchanged (GS
evidence). Its step list is `grug_core.migrations.versions` in the runtime
tree, proven equal to the declaration by `check_upgrade.py`. Messages:

- `[grug_core] This world is at version <record>, newer than this game's
  version <game>; the server does not start: downgrade to <record> to
  continue.`
- `[grug_core] This world is at version <record> and needs the migration
  step <v> before this game's version <game> can start it; the server does
  not start: back up the world and run the tool from the game's repository
  root: python3 tools/migrate.py --world <world path>` ("steps v1, v2" for
  several).
- A malformed record: `[grug_core] the world's version record "<x>" is no
  major.minor.patch version; the server does not start: restore the world
  from its backup`.

**10. New-world recognition.** The game: no key in `grug_core`'s mod
storage, no `env_meta.txt`, no `players.sqlite` and no `players/` in the
world directory; auth entries are never looked at. The tool: the game's
rule plus no mod-storage entry of any mod and no row of the player backend,
so a world new to the tool is new to the game; then nothing is due and
nothing is written (`done` with `new_world: true`), and the game stamps
the world at its first start.

**11. Test hooks** (never reachable from a shipped game or the command
line). The game: the setting `grug_test_migrations = true` (set by no
shipped configuration, not in `settingtypes.txt`) loads
`<world>/grug_test_migrations.lua` before the guard; it returns
`{ {version =, world =, character =}, ... }`. The tool:
`migration.cli.main(argv, test_steps={version: module})`.

**12. Version and declaration.** 0.43.0:
`{"schema": 2, "version": "0.43.0", "map_reset": ["0.40.1"], "new_server": [], "migrate": []}`.
A move from 0.42.0 is compatible; from 0.40.x it crosses the 0.40.1 map
reset.

**13. "Grudgelands decides" choices.**

- Tool path `tools/migrate.py`, package `tools/migration/`, step files
  `steps/v<major>_<minor>_<patch>.py` with `migrate(world)`.
- Event names and fields as above; refusal and failure reason codes.
- The data API's shape (6.), positions in nodes, the commit order player,
  auth, mod storage.
- The record keys and the marker keys (plan §3); marker values reach the
  handlers.
- The record write: a new world at the guard, an existing world at the
  first server step after a successful load; none by the tool when nothing
  is due.
- The new-world methods (10.).
- The guard in `grug_core`, no guard mod; a malformed record refuses to
  start (game) and is exit 2 `record` (tool).
- On a character handler's failure: a severe report, a disconnect, the
  marker kept; handlers must be safe to rerun. Character work runs before
  the map reset's relocation.
- Markers of unregistered versions are ignored (the tool writes only
  declared steps, `check_upgrade.py` proves the lists equal).
- The test hooks (11.).
- Check-mode locks: SQLite busy timeout and PostgreSQL `lock_timeout`
  5 s.

**14. Notes for the platform.**

- The engine splits log lines at 256 characters (`src/log.h`
  `BUFFER_LENGTH`), so the refusal arrives as two `ERROR[Main]:` lines
  (where the cut falls depends on the world path), after `ModError: Failed
  to load and run script from …/grug_core/init.lua:` and before the stack
  traceback.
- The tool's lock refusal carries psycopg's multi-line database message;
  its newlines are escaped inside the one JSON event, so one event per line
  holds.
- The local Flatpak engine has no PostgreSQL backend, so lane IT seeded
  PostgreSQL from an engine-written SQLite world with the engine's own DDL
  (`database-postgresql.cpp`); the platform's layout (player and auth on
  PostgreSQL, mod storage in SQLite) ran too, with rows equal to the SQLite
  result the engine loaded.

