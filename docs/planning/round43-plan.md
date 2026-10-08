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
Status: **draft**, waits for the user's go after Round 42 is complete.
Runs **in parallel with Round 44's wave 1** (§7).

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
  root. Steps live in `tools/migrate/steps/`, one file per declared version
  (`v0_44_0.py` style); helpers and the data API in `tools/migrate/`.
- **World record:** mod storage of `grug_core`, key `world_version`, a
  `major.minor.patch` string (contract R6).
- **Online-work markers** (contract R6; the map reset's two-level pattern,
  `grug_core/map_reset.lua:4-21`):
  - world part: `grug_core` mod storage, key `migrate_world:<version>`;
  - character part: player meta `grug_core:migrate:<version>`;
  - a step that leaves online work writes its markers in its own
    transactions; the game finishes the world part at the next load and each
    character's part at that character's next join, in step order, and
    then deletes the marker.
- **The game's step registry:** `grug_core.migrations` in a runtime-tree
  file under `mods/CORE/grug_core/` holds the list of `migrate` versions the
  guard compares against (contract R7) and the online handlers per version
  (`world` and `character` functions). `tools/check_upgrade.py` proves the
  list equal to the declaration's `migrate` list.
- **Declaration:** `tools/web_data/upgrade.json` at schema 2,
  `{"schema": 2, "version": "0.43.0", "map_reset": ["0.40.1"],
  "new_server": [], "migrate": []}`.
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
- **Online work** (R6, §3): the runner that finishes pending world markers
  at load and character markers at join, in step order, and deletes each
  marker after its handler succeeded. A failing handler stops the load (world
  part) or holds the character with a clear error, like the map reset does;
  it never deletes the marker. When a join also carries a map-reset
  relocation, the lane fixes and reports the order (migration work first is
  the default: it repairs saved data the relocation may read).
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
  covers the new rules; `outcome()` learns the fourth outcome (new server
  wins; map reset and migrate combine).
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
  keys per mod. One transaction per backend per step; the world version
  write sits in the step's mod-storage transaction. A step can never create,
  rename or delete a character or an auth entry, nor change a table layout.
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
  PostgreSQL paths get their real run in IT.

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
- The round workflow §3: the classification names four outcomes; the gates
  add "each declared step has its test" and the tool's container test run
  when `tools/migrate/` changed.
- A short **self-hosting** section (README's hosting paragraph or its own
  page): stop the server, back it up, run the tool, then start.
- `game.conf` 0.43.0, the declaration's `version`, the CHANGELOG entry,
  `tools/r37_dc` for the new version.
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
  `python3 tools/migrate.py --world <copy> --check` reports 0.43.0 and no
  due steps.

## 7. Orchestration notes

- Start state: main after Round 42's lane D (the user's go).
- **Parallel with Round 44** (the user, 2026-10-08): Round 44's wave 1
  (IH, FR, AR, MB) starts together with this round in its own worktrees.
  The two rounds share no files except the status owners lane D edits
  (STATUS, CHANGELOG, AGENTS, `game.conf`, the declaration). This round
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
  - MT: `tools/migrate.py`, `tools/migrate/`, `tools/r43_mt/` (tests and the
    container script), `requirements.txt` under `tools/migrate/`.
  - IT: `tools/r43_it/` (engine script, probe mod, test-only steps).
  - D: the docs above, `game.conf`, `CHANGELOG.md`, `tools/r37_dc`.
- Merge order GS, MT, then IT, then D.
- Decided during the round: the new-world method (GS), the guard placement
  (GS), the test hook for undeclared steps (MT).

## 8. Open questions for the user

None blocking. The model routing (§ intro) is the default; say if this
round should run differently.
