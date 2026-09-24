# AGENTS.md — Project Guide

WoW-inspired Luanti game, titled "Grudgelands". Goals and scope:
**[ROADMAP.md](ROADMAP.md)**. Work packages and status:
**[BACKLOG.md](BACKLOG.md)**. Documentation entry point and source roles: **[docs/README.md](docs/README.md)**.
Research and historical evidence: **[docs/research/README.md](docs/research/README.md)**.

## Language rules

- **All Markdown documentation in this repo is written in English.**
  Exception: `docs/research/` contains older German reference notes; they
  may stay German until substantially rewritten.
- Chat with the user is in **German**; code identifiers and code comments
  are in English.

## Agent execution channel

- **Standing user instruction, decided 2026-09-20:** use native subagents for
  models from the coordinator's own provider. CLI delegation is exclusively
  for another provider: Claude may invoke Codex CLI, and Codex may invoke
  Claude CLI when that provider/model is authorized. Codex must never launch
  Codex CLI for its own implementation or review agents; Claude likewise uses
  native Claude agents rather than Claude CLI for its own models.
- This changes execution mechanics, not model authorization or independent
  review requirements. Read `docs/process/agent-model-policy.md` and
  `docs/process/cross-cli-orchestration.md` for those rules.
- **Current development session:** Claude credits are exhausted. No Claude CLI,
  Claude agent, Opus or Fable task is authorized in this session. Root is Astra;
  ordinary implementation/review uses native Sol, with native Astra allowed for
  hard/performance-critical work. This session restriction can change only by
  a later explicit user instruction. Durable active work state:
  `docs/planning/round20-state.md` (Round 20 delivered; await playtest).

## Fresh-server development mode

- **Standing user instruction, decided 2026-09-13:** the first release is
  still under development. Assume the server and world are **always fresh**.
  There are no old servers, worlds or player records to migrate.
- Do not add backward-compatibility branches, saved-world/data migrations,
  legacy-name aliases, old-format readers, compatibility placeholders or
  cleanup LBMs/timers for earlier development versions. Remove existing code
  whose sole purpose is supporting or cleaning up those earlier versions.
- Current-version persistence (saving/reloading the same world, reconnects,
  inventories and normal entity activation) remains required. Current engine
  APIs, Lua 5.1 support and integrations with currently shipped dependencies
  are not old-world migration mechanisms.
- This instruction supersedes older migration/legacy-support requirements in
  project documents. Do not infer a release transition from a commit, merge,
  deployment or WP completion: **only the user's explicit announcement changes
  this mode**.

## Anthropic repository sharing authorization

- **Standing user authorization, decided 2026-08-30:** every file in this
  repository, including its read-only reference submodules and prepared WP
  snapshots, may be transmitted to Anthropic when an authorized Claude Opus or
  Claude Fable task needs it. No separate confirmation is required for the
  repository-content transfer itself.
- Keep each transmitted snapshot bounded to the reviewed or delegated package.
  This standing authorization does not permit unrelated publication,
  repository writes by a read-only reviewer or any other external side effect.
- Model/task authorization remains separate: Opus and Fable routing still
  follows `docs/process/agent-model-policy.md`. In particular, each new Fable
  review or delegated task still needs the task-specific approval required by
  that policy; the standing rule above only removes repeated data-sharing
  confirmation.

## Active work and game status

**Round 21 is active (user Go 2026-09-24).** Read
[the execution ledger](docs/planning/round21-state.md) before starting or resuming.
Root Astra coordinates native Astra/Sol lanes. Minimal mapgen tests, maximum
six CPU workers for this round, no full-world/census fleets. No remote push.


**Round 20 delivered locally, 2026-09-24:** POI/quest expansion and playtest
fixes, including contextual input. Independent reviews and final static,
portable-interpreter, real POI and isolated engine gates passed. Merged to main
and synchronized; no remote push. Read [receipt](docs/research/round20-completion.md)
and [playtest checklist](docs/research/round20-playtest.md). No implementation
agent is still running; await user GUI feedback. No Claude tasks.


The user approved maximum-throughput world preparation on 2026-09-23, retaining
bounded shutdown and unchanged later on-demand cave generation. Current contract:
[full-speed follow-up](docs/research/pregen-fullspeed-plan.md). Root Astra
coordinates native Astra implementation/measurement and independent Sol review.
Delivered on local main and synchronized; receipt:
[full-speed preparation](docs/research/pregen-fullspeed.md).
No Claude task is authorized. The previous documentation-only round
is complete: [receipt](docs/maintenance/documentation-round.md).

Game delivery and pending acceptance: [project status](docs/STATUS.md).
Round 20 and earlier follow-ups are locally delivered; GUI acceptance remains user-run.
The current local-development Go does not authorize a remote push or bypass a recorded
automatic approval-review rejection. Current local tracking evidence is in STATUS;
older round receipts are historical delivery observations.
Standard unmodified Luanti clients are required: no client/engine fork,
upstream-PR dependency or required client mod.

## Current resource-root authority

- The user adopted demand-driven resource-root sampling on 2026-09-13.
  `docs/design/world_zones.md` §11 is the current root-selection rule in both
  the VM writer and resource census. The per-host root SHA ranking in the
  frozen R6 contract/artifacts is historical evidence; it is not a current
  output oracle. Do not restore it or add a compatibility path.
- Current resource integration checks live in `tools/wp40/resource_sampling/`
  and run through `tools/wp40/quality/final_micro.lua`. Historical 32-seed
  supply/access evidence has not been regenerated for the adopted sampler.

## Documentation layers

All durable project state belongs in the repo. See [documentation maintenance](docs/process/documentation.md)
for authority, archival and conflict rules. Three core layers are kept separate:

1. **`docs/design/`** — the *decided* game design (living spec: rules,
   numbers, lists only — no open questions, no discussion).
2. **`TODO-<topic>.md`** (repo root) — *open* design questions: context,
   options, recommendation, decision state. When every question in a file
   is decided, fold the results into `docs/design/` (and update
   ROADMAP/BACKLOG where affected), then **delete the TODO file**.
3. **[BACKLOG.md](BACKLOG.md)** — implementation work packages (WPs). WPs
   reference `docs/design/` instead of inventing design on the fly.

On top of those three sits **[README.md](README.md)** — the human-facing
entry point (story, design tour with links to every `docs/design/` file,
current state). It is **derived, never authoritative**:

- **Rule: whenever a WP is completed (or its status in BACKLOG.md
  changes), update the README's "Current State" section in the same
  commit** — shipped count, the shipped/not-yet/ready-next lists, the
  caveats, and the *Last updated* date. Keep it short: three to five
  sentences per list, no WP-by-WP retelling (BACKLOG.md is that).
- When a `docs/design/` file is added, removed or substantially changed,
  check the README's design tour for the same edit (it links and
  summarizes every design doc).
- Never put design decisions or WP detail in the README that does not
  already live in `docs/design/`, ROADMAP or BACKLOG.

## Working method (sessions & context)

1. **Session start**: read BACKLOG.md, pick the next open WP (or the one
   the user names). Check for `TODO-*.md` files that block it. Skim the
   relevant docs/research/ briefings.
2. **One WP per session** is the norm — coherent, testable, committed.
   Offload large explorations to subagents, keep the main context lean.
3. **WPs run autonomously on their own branch** (`wp<NN>-<slug>`) per
   the workflow contract in
   **[docs/process/wp-workflow.md](docs/process/wp-workflow.md)**. Model
   routing defaults live in
   **[docs/process/agent-model-policy.md](docs/process/agent-model-policy.md)**;
   the user overrides them per session (its "Day-to-day routing rule").
   Its **Independent review** trigger and independence rules are binding;
   every required review uses the checklist and the
   `docs/research/luanti-lua.md` rules in the workflow document. Merge to main
   only after a clean review; every completion message ends with a runtime test
   plan for the user.
   Claude CLI review execution details (sandbox, streaming and monitoring):
   **[docs/process/claude-cli-review.md](docs/process/claude-cli-review.md)**.
   Cross-CLI implementation and review orchestration in either direction:
   **[docs/process/cross-cli-orchestration.md](docs/process/cross-cli-orchestration.md)**.
4. **WP completion**: Lua syntax check with `tools/bin/luac51 -p` (plain
   5.1 — build once via `tools/build_lua51.sh`; **not** `luajit`, which
   accepts syntax the engine's fallback build rejects),
   `tools/sync_to_luanti.sh` (from main, after merge), commit, update
   BACKLOG status + ROADMAP checkboxes + the README "Current State"
   section (see "Documentation layers"). The durable completion record for an
   independently reviewed package also carries the calibration fields required
   by `agent-model-policy.md`. Anything future sessions need to know goes into
   AGENTS.md/docs — not just the chat.
5. **Runtime tests are done by the user** (Flatpak Luanti, GUI); diagnose
   errors via `~/.var/app/org.luanti.luanti/.minetest/debug.txt`.

## Project structure

- We are building a **standalone game** (not a mod pack, not a fork of
  minetest_game/VoxeLibre). The game will eventually live in a layout like
  `games/<gameid>/` with `game.conf`, `menu/`, `mods/`, `settingtypes.txt`.
- **Third-party code is vendored, never a submodule** (decided 2026-08-06):
  every embedded foreign mod is documented in **[VENDOR.md](VENDOR.md)**
  (upstream repo + commit + license + patch list); in-place changes carry a
  `-- GRUG PATCH:` marker at the change site; prefer wrapper mods
  (`grug_mobs` pattern) over in-place edits. Details/update procedure:
  VENDOR.md.
- `reference_projects/` contains **references only — never change anything
  in there**. The reference sources are **git submodules** (converted 2026-08-08,
  WP36) — not part of the build (the game runs with the directory empty), but
  required to develop this codebase: every engine-behaviour claim, licence
  verification and `file:line` citation in the design docs points into them.
  Get them with `git submodule update --init --recursive --depth 1`.
  - **Never move a pinned commit as a side effect of other work** — it
    invalidates every citation written against it and every
    `LICENSE-media.md` row quoting it. `git submodule status` must show no
    `+`/`-`/`U` marker. Deliberate updates and the re-verification they
    require: [docs/reference_projects.md](docs/reference_projects.md).
  - **A reference project needed beyond one session MUST live here and be
    listed in [docs/reference_projects.md](docs/reference_projects.md)** —
    with upstream URL, why we need it and its licence. Ad-hoc clones into a
    scratchpad die with the session, and then a *cleared* licence silently
    costs a re-download (this happened on 2026-08-08 with animalworld,
    animalia and mobs_monster, whose commits `LICENSE-media.md` still cited).
    This is **not** in conflict with the vendoring rule above: *vendored*
    means code we **ship** in `mods/` and patch in-tree; these are sources we
    **read** and never touch, and a submodule pins exactly the commit our
    licence rows quote.
  - **Imported meshes must be animated.** A mesh without `ANIM`/`BONE`/`KEYS`
    chunks slides instead of moving; choose another source rather than
    shipping it.
  - The sources and what each is for: see
    [docs/reference_projects.md](docs/reference_projects.md).

## Lua & Luanti environment (IMPORTANT)

- **Lua 5.1 — and plain-5.1 compatibility is a HARD requirement** (decided
  2026-08-06): the engine prefers **LuaJIT** but silently falls back to
  bundled Lua 5.1.5, and our code must run on both. Full reference incl.
  do-not-write checklist:
  **[docs/research/luanti-lua.md](docs/research/luanti-lua.md)**. Key rules:
  - **No `goto`**, no `\u{...}`/`\x..`/`\z` string escapes (LuaJIT-only),
    no integer division `//`, no bitwise operator syntax (`&`, `|`) —
    use `bit.*` (engine-injected, both builds, 32-bit).
  - `unpack` (not `table.unpack`); `table.pack`/`rawlen`/`__len`/`__pairs`
    are unsafe even on LuaJIT (need a distro compat flag) — avoid.
  - Numbers are C doubles, no integer type; safe integer range ±(2^53−1).
  - Vector `==` only works if BOTH operands carry the vector metatable —
    compare positions with `vector.equals`, never `==`.
  - Backported from 5.4 (engine-injected, both builds):
    `string.pack`/`unpack`/`packsize`.
- **Interpreter/test layers are binding:** on every Lua change run
  `tools/bin/luac51 -p`, the `SETGLOBAL` check and all five sweeps in
  `docs/research/luanti-lua.md`. Two things about those sweeps are easy to
  get wrong. They are scoped to `mods/*/grug_*`, so Lua under `tools/`
  is **not** covered by them and needs the check run explicitly. And the
  harness scripts that run them require **ripgrep** (`dnf install ripgrep`):
  until 2026-08-15 a missing `rg` made nine of them report success without
  running, because exit status 127 inside an `if` condition reads exactly
  like "no match found". Use LuaJIT for development and exhaustive runs
  where supported. Do not run PUC runtime at intermediate milestones. On
  frozen final bytes, run one compact PUC-5.1 micro-KAT process
  and the same fixture once under LuaJIT, requiring a byte-identical canonical
  digest. WP40 R1-R4 retain their historical targeted-PUC evidence; R5-R8 use
  this single-final-micro-KAT rule. Fixed-layout, seed and full VM populations
  run only under LuaJIT. A relevant final-byte change replaces the final
  micro-KAT pair (one PUC and one LuaJIT run); any additional PUC runtime needs
  a concrete interpreter-specific finding or identified uncovered plain-5.1
  risk. **Parallel execution is preferred:** at most seven independent LuaJIT
  or PUC 5.1 processes may run concurrently on the workstation, counted
  across all agents, work packages and execution lanes. Their inputs remain
  immutable for the duration, each process writes to its own scratch/output
  path, and a deterministic final step canonically orders, combines and checks
  every result. Concurrent worker fleets use idle scheduling priority
  (`chrt --idle 0` and `ionice -c3`). Do not serialize independent seeds or
  partitions merely for convenience; do not parallelize jobs that share
  mutable output or whose correctness depends on execution order. Historical
  records of eight-worker WP40 measurements describe how that evidence was
  obtained; they do not authorize an eighth process now. A rerun obeys the
  current seven-process cap and records the changed width before comparing
  timing evidence. The retired exact-T2 full-W/PCC/F1/F2 suites remain
  historical evidence and are not executed against the simple schema.
  Reviewers verify immutable artifacts, logs and hashes plus the final PUC
  micro-KAT evidence instead of duplicating it. The real
  fallback-engine runtime test is still a separate user-run gate.
  **Planning agents:** if you write a brief, work package, contract or cost
  projection that schedules Lua execution, read the "Interpreter and test
  strategy" section of docs/research/luanti-lua.md and the parallel-execution
  rule above **before** writing it.
  Interpreter selection is a planning-time decision, not an implementation
  detail: LuaJIT owns development and exhaustive runs; PUC 5.1 owns the parser,
  static gates and one bounded final runtime micro-KAT compared by digest. A
  plan that schedules an intermediate PUC suite, PUC seed fleet or exhaustive
  PUC population without a concrete plain-5.1 interpreter finding is a planning
  defect.
- Engine version of the reference checkout: **Luanti 5.17.0-dev** (git
  checkout after 5.16). That pin is the *engine* version of a read-only
  source reference — **the language version is decoupled and stays Lua
  5.1**; a newer engine never unlocks newer syntax.
- **The engine's own Lua is checked out in this repo — read it, never
  guess.** `reference_projects/luanti/builtin/` (what runs before any
  mod), `lib/lua/src/` (the bundled 5.1.5 interpreter),
  `src/script/lua_api/l_*.cpp` (the C++ truth when `doc/lua_api.md` is
  silent). Full map: "Where the real code lives" in
  docs/research/luanti-lua.md.
- **Use the `core.*` namespace** — `minetest.*` is only a deprecated alias.
- **Mapgen integration boundaries:** changes to the R7 content projection or
  planner column tuple must exercise the actual `r7_manifest.new` and
  `planner.plan_slice` consumers. A self-built receipt passed to `validate`,
  or a source-tuple-only fixture, does not prove those boundaries work. The
  quality final runner keeps real MTS/roster construction under LuaJIT and
  the small planner regression in the portable final micro-KAT.
- **All game logic runs server-side.** Mods run on the server only;
  definitions/media are transferred to clients automatically. SSCSM
  (server-sent client-side mods) is still a stub in the engine — do not use.
- **Sandbox** (with `secure.enable_security`): fully available are
  `coroutine`, `string`, `table`, `math`, `bit`; `io`/`os`/`debug` are
  heavily restricted (no `os.execute`/`os.exit`); **`require` is disabled
  outright**; `dofile`/`loadfile` may READ the game dir and all mod dirs
  (write access is world dir/mod-data only — details in
  docs/research/luanti-lua.md). `core.request_insecure_environment()`
  only via `secure.trusted_mods` — we don't need it.
- **Globally injected helpers** (builtin): `dump()`, `string.split`,
  `string:trim()`, `table.copy/indexof/insert_all/shuffle`,
  `math.round/sign/hypot`, `vector.*` (metatable-based, overloaded
  operators: `vector.new/add/distance/direction/normalize/...`),
  `core.after(sec, fn)`, `core.serialize/deserialize`,
  `core.parse_json/write_json`.
- The engine's `strict.lua` warns about undeclared globals — declare mod
  globals explicitly (one global table per mod, see conventions).

## Game/mod anatomy

- `game.conf`: `title` (required), `description`, `first_mod`/`last_mod`,
  `allowed_mapgens`/`default_mapgen`, `disabled_settings` (e.g.
  `!enable_damage` forces PvE damage), `author`, `textdomain`.
- Every mod: `mod.conf` (`name`, `depends`, `optional_depends`) +
  `init.lua`. Media in `textures/ sounds/ models/ locale/` (names:
  `a-zA-Z0-9_.-`; models `.b3d/.obj/.gltf/.glb`, sounds `.ogg`).
- Registered names are always `modname:name`; `:foo:bar` overrides a
  foreign registration (requires a dependency).
- We use modpacks (folders with `modpack.conf`) for grouping like
  VoxeLibre. The six that exist are `BASE/` (vendored upstream mods),
  `CORE/`, `PLAYER/`, `ENTITIES/`, `ITEMS/` and `MAPGEN/`; there is no
  `HUD/` modpack — the XP bar and the other HUD elements live in their
  owning mod.

## Project conventions

- **Namespace prefix `grug_`** for all our mods (e.g. `grug_xp`,
  `grug_factions`, `grug_quests`, `grug_jobs`, `grug_mobs`, `grug_map`) —
  derived from the game title Grudgelands. Vendored code carries
  `-- GRUG PATCH` markers for the same reason (see VENDOR.md).
- Exactly one global table per mod (`grug_xp = {}`), sub-files via
  `dofile(core.get_modpath(core.get_current_modname()).."/foo.lua")`.
- Custom fields in item/node/entity definitions use the `_grug_` prefix
  (pattern from VoxeLibre's `_mcl_*`).
- Dispatch behavior via **groups** instead of name lists (VoxeLibre
  pattern).
- Persistence:
  - Player data (race, class, faction, XP, level, talents, jobs, gold,
    quest state, HUD preferences) → `player:get_meta()`
    (PlayerMetaRef, auto-persisted). Complex structures via `core.serialize`
    as string.
  - Mod-wide data → `core.get_mod_storage()` (fetch at load time).
  - Node data (workstations) → `core.get_meta(pos)`.
- Performance rules (distilled from VoxeLibre):
  - **Always** throttle `register_globalstep` with a dtime accumulator.
  - Node timers for machines/workstations (forge, alchemy).
  - LBMs for required current-version activation only; no old-world migrations in fresh-server mode.
  - ABMs only for ambient random events, throttled via `chance`/`interval`,
    `catch_up = false` where possible.
  - In hot loops use `core.get_node_raw`/content IDs + VoxelManip instead
    of `get_node`.

## Task-specific implementation references

Read the relevant section of [Module implementation guide](docs/technical/module-guide.md)
when touching a module. It preserves equipment/callback/persistence seams and
engine pitfalls formerly embedded here; it is not a second game-design spec.
Current rules live in [docs/design](docs/design/README.md). Do not infer current
behavior from an old completion report or source-line citation.

## Licenses

- **Code: GPL-3.0-or-later** (decided 2026-07-03 as "GPL", made precise
  2026-08 — full text in `LICENSE.txt`; rationale and compatibility
  matrix in [docs/research/licensing.md](docs/research/licensing.md)).
  Compatible code inputs: MIT, Apache-2.0, LGPL-2.1/3.0 (also "-only"),
  GPL-2.0-or-later, GPL-3.0. **Hard exclusion: GPL-2.0-only code.**
- **Media: keep each file's original license** (CC0 / CC BY / CC BY-SA /
  GPL), documented per mod in a `LICENSE-media.md` table: file, author,
  source URL, exact license + version, modifications made. **Never NC or
  ND media.** When we accumulate more sources, add a top-level
  `CREDITS.md` (Mineclonia model).
- Before importing anything, verify the license **in the source repo**
  (LICENSE/README files) — ContentDB metadata can be wrong (real case:
  a CC BY-NC sound hidden inside the otherwise-clean ambience mod).
- Asset shopping lists with verified licenses:
  [docs/research/assets/](docs/research/assets/).
- **Never copy WoW assets/names 1:1** — Blizzard IP. Own assets, own names
  with a recognizable character ("inspired by", not "copied").

## Testing & development

- Local testing: Luanti is installed as a **Flatpak** (`org.luanti.luanti`,
  sandboxed without access to `~/projects`!). Therefore run
  `tools/sync_to_luanti.sh` — it copies the game to
  `~/.var/app/org.luanti.luanti/.minetest/games/grudgelands`.
  Re-sync after every code change. Engine logs:
  `~/.var/app/org.luanti.luanti/.minetest/debug.txt`.
- **Agent engine runs never touch that personal folder** (decided
  2026-09-14: the user runs the GUI client on the same machine at the same
  time, and two instances on one folder can crash it). Boot a headless
  server only through `tools/luanti_headless.sh` or with the same
  guarantees: a fresh temp directory as `LUANTI_USER_PATH` **and** as all
  XDG dirs, `--logfile` inside it, a `timeout --kill-after`, cleanup of the
  directory, and `pgrep -f '^luanti.bin'` empty when the task ends. A
  launcher that falls back to the personal folder when `LUANTI_USER_PATH` is
  empty is a defect. The WP40 profiler and `tools/wp13/run_engine.sh` set
  their own scratch user path; pass them a launcher that forwards it.
- Take `strict.lua` warnings (undeclared global) seriously — usually typos.
- Server log via `core.log("action"|"warning"|"error", msg)`.
