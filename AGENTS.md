# AGENTS.md — Project Guide

WoW-inspired Luanti game, titled "Grudgelands". Goals and scope:
**[ROADMAP.md](ROADMAP.md)**. Work packages and status:
**[BACKLOG.md](BACKLOG.md)**. Detailed research notes on the reference
projects: **[docs/research/](docs/research/)**.

## Language rules

- **All Markdown documentation in this repo is written in English.**
  Exception: `docs/research/` contains older German reference notes; they
  may stay German until substantially rewritten.
- Chat with the user is in **German**; code identifiers and code comments
  are in English.

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

All project state lives in the repo, not in the chat history. Three layers,
strictly separated:

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
    quest state, map exploration) → `player:get_meta()` (PlayerMetaRef,
    auto-persisted). Complex structures via `core.serialize` as string.
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

## Key APIs for our features (quick reference)

Details + line numbers in [docs/research/](docs/research/).

- **Factions**: pattern from Lord of the Test `lottclasses` — faction as a
  **privilege** + ally matrix + predicates (`*_same_race_or_ally`),
  selection formspec on join (re-prompt on abort), starter-kit dispatch.
  LotT has NO per-faction spawns and no player-PvP gating — we build those
  ourselves (`core.register_on_punchplayer` /
  `register_on_player_hpchange`).
- **XP/levels**: template VoxeLibre `mods/HUD/mcl_experience/init.lua` — XP
  as an int in player meta, `level_to_xp` curve, `register_on_add_xp`
  pipeline, HUD bar. XP loss on death via `core.register_on_dieplayer`.
- **Combat/classes**: damage = damage_groups × armor_groups (÷100) ×
  punch-interval factor. **Damage pipeline lives in `grug_core/combat.lua`**
  (WP4): `deal_ability_damage` (crit ×1.5, applied via `object:punch` with
  full punch interval so armor/XP keep working; knockback requires an explicit
  `damage_groups.knockback` override), `heal_player`,
  central dodge roll (hp-change modifier), `mark_in_combat/in_combat`
  (5 s window), threat stubs `add_threat`/`add_heal_threat` (WP6 fills
  them). Crit/dodge accessors are grug_core stubs overridden by
  grug_classes. Abilities = hotbar tools in `grug_abilities` (item `range` =
  targeting range, wear bar = cooldown display for cast skills, charge
  bar for swing skills since WP38); kits/numbers:
  `docs/design/classes.md`. WP19 added the 8 s target-memory store (separate
  enemy/ally slots via `grug_abilities.get_target(player, ally)`). **WP39's
  decided rule supersedes its hostile fallback:** enemy memory is Target-Frame/
  UI state only and no melee, hostile cast or projectile may read it as aim;
  ally memory remains the heal/shield fallback. WP19 also added **absorb
  shields** (`grug_core.set_absorb`, soaked in the central
  hp modifier after dodge/fall mitigation), **race passives** as a perk
  table in the grug_classes race registry (`grug_classes.get_race_perk`,
  stub-mirrored as `grug_core.get_race_perk`; elf range via per-stack
  meta `range` override) and mob slows (`grug_mobs.slow`, staticdata-safe
  countdown shared with root). NB a lethal ability punch removes
  animation-less mobs synchronously — capture mob pos/luaentity BEFORE
  `deal_ability_damage`. **mobs_redo `do_punch` gotcha**: any truthy
  return cancels the punch (api.lua comment claims the opposite) — hook
  wrappers must return nil; player-hit hook:
  `grug_core.register_on_player_hit_mob` (fired by grug_mobs).
  WP35 added: a **weapon slot** (group `grug_equip_weapon`) whose item is
  the single fixed source of damage AND appearance for every skill of its
  type — **no fallback to the wielded item**, empty slot = bare-handed
  baseline; `inventory_equipment.md` §2 (eligibility, no class gate, the
  `_grug_hands` two-handed rule) and `combat_stats.md` §2. Its
  **equipment seam** lives in `grug_core/combat.lua`:
  `get_equipped_weapon`/`get_equipped_offhand` (stub-override pattern like
  `get_armor_percent`; **the returned ItemStack is the caller's OWN
  COPY** — a modified copy is not equipped until it is written back AND
  `grug_inventory.equipment_changed` is called) plus
  `register_on_equipment_change(func(player, listname))`, where `listname`
  is the one list that changed or **nil** for "assume everything moved".
  Consumers must be idempotent and cheap (every inventory write re-sends
  the list to the client), **may be called twice for one change** (the
  notifier coalesces a nested equipment write into a second pass) and run
  **unwrapped**, so an error in one is loud. Never write an equipment list
  without going through `grug_inventory.equipment_changed`. That notifier is
  the sole equipment-driven stats/page refresh source:
  `grug_classes.apply_stats` is the deliberately first consumer (through a
  wrapper so `listname` is not mistaken for its `heal_gain` argument), then
  exactly one Character-page refresh consumer; normal equip, class change
  and join add no direct duplicate refresh (a genuine nested write may still
  earn the second pass).
  **Swing skills use native interaction plus an authoritative held clock**
  (`classes.md` §2b; WP38 base, WP39 target-authority revision decided
  2026-08-10): exactly Strike, Mighty Blow and Hamstring have `kind = "swing"`
  and **no `on_use`**, keeping the fast first-person held animation. Their
  native enemy packets are input only and return before damage/rage/threat/
  wear/proc. The no-dig pointabilities can mask a ground-level drop, so each
  fresh LMB press retains the bounded first-visible 4 m builtin-item pickup ray;
  nodes/other objects block it and held repeats do not become auto-loot.
  **WP39 shipped the current-ray authority on 2026-08-10.**
  `grug_core.combat_eye_pos(player)` and
  `grug_core.combat_ray(player, range, opts)` are the shared server-side
  acquisition seam: the latter returns one physically ordered structured ray
  result for combat and diagnostics, so callers do not raycast again for logs.
  The held clock attacks only a live hostile returned by that current server
  eye/look ray while `get_player_control().dig` is true. When due, no
  target/friendly/blocker/out-of-range aim is an **aim miss** and leaves the
  attack ready; the first valid ray target consumes the interval before its
  punch. Later evade/immunity/PvP refusal/dodge/full absorb/do_punch/CMI cancel
  is a **combat miss** that consumes cadence but keeps no proc/rage/cost/charge/
  effect. Moving the crosshair changes/stops damage immediately; enemy memory
  can refresh the Target Frame but is never read back as aim. A 0.05 s
  throttled pass still executes only on the next actual engine step, carries at
  most 0.1 s and half an FPI of ordinary lateness, and never replays a backlog.
  Swing-to-swing selection reads the proc live; non-swing/cast boundaries keep
  the due time; lifecycle clears it; a concrete weapon swap starts one full new
  interval. Every hostile ordinary tool/fist packet pushes the full ability
  swing to at least `now + equipped FPI`, with one-time bank cleanup at path
  transitions.
  Swing ItemStacks continue to mirror equipped-slot FPI compare-first with
  `fleshy = 0`, empty `groupcaps`, `max_drop_level = 0`,
  `punch_attack_uses = 0` and blocking hand/dig_immediate node pointabilities.
  Neither ability stack nor slot weapon wears. The accepted transaction stays
  exact attacker+ray-target and claim-once; the mobs_redo/PvP finish seam pays
  cost, resets charge, grants rage and applies post-effects only on its existing
  accepted/HP-loss conditions. Mighty Blow remains
  `floor(weapon*1.5)+melee bonus`; Hamstring remains a 50% slow.
  WP39's binary small gold crosshair ring is shown once while a selected
  swing is weapon-ready, hidden on a valid attempt, absent for non-swings, no
  smooth progress and no inventory writes; a weapon swap follows the new
  clock's readiness and lifecycle cleanup removes it. It also ships permanent
  admin-only per-player `/combatdebug`; disabled sites do no ray/log
  formatting/globalstep work beyond the enabled check.
  Hostile casts no longer use enemy memory: Charge/Taunt/Smite need current
  pointed/server-validated aim. Fireball is a straight 20 m/s swept
  projectile, max 20 m, no gravity/homing/splash, 8 mana even on a miss,
  `6 + spell power` once; nodes/attackable targets stop it, while allies and
  dropped items are ignored. The public
  `grug_projectiles.register(id, def)` and
  `grug_projectiles.spawn(id, params)` foundation owns swept collision,
  ownership, exact-once settlement and terminal cleanup for later ballistic,
  draw-impulse arrows; bows themselves remain later work. Fireball uses
  `active_limit = 8` per owner/session: failure happens before entity creation,
  every terminal/failure path releases its opaque token idempotently, and a
  reconnect/respawn creates a fresh session that old shots cannot charge.
  Real-code Lua 5.1 regressions live under `tools/wp39/` and must stay green
  when changing the ray, clock, settlement, reticle, casts or projectiles.
  **Ordinary tool WEAR is spent per swing, not per punch**
  (`grug_core.melee_wear_due`, keyed per player AND per persistent opaque
  `_grug_melee_wear_id` on the concrete ItemStack): A→B cannot transfer A's
  partial wear to B, returning to A resumes it, and empty/non-tool,
  creative/use-0 punches neither assign an id nor consume state. The wear
  block in api.lua now runs on all ~5 packets/s, and
  paying a full swing's wear each time both wears the tool `1/fraction`
  times faster and fires `set_wielded_item` — a full inventory
  serialization plus packet — per punch, ~500/s at the 100-player target.
  **PvP melee runs through the same pipeline** (the on_punchplayer
  handler in grug_abilities): an authoritative ability swing builds the
  slot-fed full swing, adds Strength/proc, rolls crit once, applies
  `grug_core.apply_player_armor` (0..60%, ceil only when pct > 0), then enters
  dodge/absorb once. A native swing-item packet is suppressed and never
  authorizes the final target. Ordinary tools/fists still scale their wielded-stack full
  equivalent by `fraction` and accumulate. Their integer commit uses `set_hp`
  with `type="punch"`/`object` and
  `custom_type="grug_core:player_armor_applied"`; the central modifier skips
  only the already-run armor step while dodge and absorb still run once.
  `return true` always suppresses handled hostile engine damage. Tool/fist PvP fractions bank
  with the damage remainder and pay `12 × committed_pending_fraction` only
  when a commit actually lowers HP; bank-only packets pay nothing, target
  switches discard both banks, and dodge/full absorb consume the credit for
  0 rage (partial absorb with HP loss still lands). Thus unmitigated fractions
  totalling 1 pay +8 independent of weapon damage, without the old 60 rage/s
  packet firehose. Base mob threat still takes raw fractional damage.
  Same-faction pairs stay with grug_factions' handler
  (RUN_CALLBACKS_MODE_OR, s_player.cpp:63 — neither vetoes the other);
  knockback on players keeps coming from builtin off the engine's damage
  argument (deferred, MVP): acquisition caps are zero, while the one
  authoritative punch supplies the real full caps. Tools/fists keep their wielded source and wear;
  swing ability items use the slot source, do not wear and can carry the
  selected proc's threat multiplier. The current server ray is the sole
  authoritative hostile ability target while LMB is held; enemy memory is
  UI-only.
- **Mobs**: embed and patch mobs_redo (MIT). Faction targeting: condition
  in `general_attack()` (api.lua:1699ff) following the LotT pattern
  (`race` field in the mob def + ally check); territory/tier gating via
  `mobs:spawn_abm_check()`. Tiers via `hp_max`/`armor` (lower = tougher)/
  `damage`/`view_range`/`group_attack`. Dynamic loot: `drops` can be a
  function. Quest kill credit: `on_death(self, killer)`.
  Quest/trader NPCs: `type="npc"`, `passive`, `on_rightclick` → formspec;
  placement via `mobs:add_mob(pos, def)`.
  **Pathfinding is a quality criterion** (user requirement: dangerous mobs
  must not fail at terrain, otherwise they are not dangerous): mobs_redo
  has `pathfinding = 1|2` (uses `core.find_path`, 2 = can break/build
  nodes) plus `stepheight`/`jump_height`/`fear_height` — always enable and
  test these when tuning mobs. VoxeLibre `mcl_mobs` has its own, more
  advanced `pathfinding.lua` (+ the villagers' `gopath`) — if mobs_redo
  pathfinding is not good enough, adapt from there (GPL ok, see below).
  Fallback design: additionally make heartland mobs fast (`run_velocity`)
  and give them ranged attacks (`attack_type = "dogshoot"`) so terrain
  exploits are not trivial.
  **WP6 patterns (binding for every new mob):**
  - **Level/tier engine contract** (`grug_mobs/levels.lua`): a mob def
    NEVER hand-sets `hp_min`/`hp_max`/`damage`/XP/`armor` — they are
    derived from `grug_core.mob_level_at`/`guard_level_at` plus the tier
    multipliers on the first active tick. `_grug_fixed_level` is the sole
    explicit fixed-entity mechanism: it bypasses positional/role fields only
    for deliberately designed fixed entities. Its current implemented use is
    the Kraken L100; future WP13 uses the same mechanism for the still-
    unimplemented king L65. There is no second king-specific level path.
    Everything else (speeds, view_range, drops, visuals) stays def-owned.
    **Four tiers since WP36**: `critter` (added for the small animals —
    fixed L1, 1 HP, 0 XP, no fall damage, never promotable; the second
    documented exception to "stats derived") plus `normal`/`elite`/`rare`,
    whose arithmetic is unchanged. The **telegraph gate is a POSITIVE
    elite/rare test** (`grug_mobs.tier_telegraphs`, one predicate for both
    call sites) — a `tier ~= "normal"` test hands a rabbit a 2 s wind-up
    and a ×3 cone hit the day a fourth tier appears.
  - **Three behaviour classes, and a new mob picks one**
    (`biomes_mobs.md` §3.0): **critter** (small, scenery with a use —
    food-only drops, `passive` + `runaway`), **passive prey** (the large
    grazers — `grug_mobs.passive_prey` in `verbs.lua`: `passive = false`
    is what buys retaliation, `attack_players`/`attack_npcs = false` is
    what removes aggro on sight, `runaway` must be OFF because on_punch
    sets it a dozen lines before the retaliation block resets it, and
    **`attack_type` must be set** — `do_states`' attack branch dispatches
    on three values with no `else`, so a retaliating mob without one holds
    a target and does nothing at all) and **enemy** (§3.1's verbs).
    Ground mobs that can end up in the attack state carry
    `pathfinding = 1`; fliers never do (`core.find_path` is a ground
    search).
  - **Runtime field installation**: mobs_redo's `register_mob` copies an
    EXPLICIT def-field whitelist into the entity table (api.lua:3196ff)
    and staticdata drops function fields — so every `_grug_*` field an
    api.lua patch reads off `self`, and every callable, must be
    (re-)installed from the `do_custom`/`do_punch` wrappers on each
    activation, not written in the def.
  - **Countdowns tick in `do_custom`, never `core.after`**: a mob can
    die, be unloaded or leash-reset inside the window, and mobs_redo
    persists plain fields — a lost timer would save the mob permanently
    rooted. (`core.after` is fine for PLAYER-side effects, re-fetching
    the player by name.)
  - **Chase model** (combat_stats §3/§4): give up at **45 m** (an
    api.lua patch — vanilla uses `view_range`, ≤ 16 m, which made every
    other rule dead code), walk speed beyond **25 m** (soft de-aggro),
    leash at **40 m dragged from the chase anchor** (not from home) or
    15 s without contact, then the **evade run-home** if the mob stands
    beyond its own radius from its post.
  - **`aoc` is per entity NAME**, counted in a 128-node sphere — two
    rows of one name share a budget, per-biome tints do not. Spawn
    calibration reference: **`docs/research/wp6_spawn_budget.md`**.
  - **62 `GRUG PATCH` sites in `mods/ENTITIES/mobs/api.lua`** — the
    inventory and rationale live in VENDOR.md; re-apply them on any
    mobs_redo update. The 41st to 43rd (mob pressure, 2026-09-16) are the
    attack-cadence patch of `combat_stats.md` §4 and user ruling 1: the
    cadence advances during the CHASE with the backlog capped at one, the
    in-reach branch runs to a contact distance of `reach × 0.6` instead of
    freezing the mob, and the punch sits outside both branches with the
    in-reach and line-of-sight tests where it lands. The 44th to 59th
    (round-5 combat AI, 2026-09-17) raise ordinary reach to 3 m, navigate
    blocked close cover, remove implicit ordinary-hit knockback and disable
    object-to-object collision; `mobs/grug_obstacle.lua` holds the bounded
    production state decisions used by that attack path.
    The 40th (WP13 playtest round 2, 2026-09-15) is the
    per-TARGET non-combatant veto in `general_attack`'s candidate filter:
    hostiles and guards MAY fight each other, but nothing in the world may
    acquire an entity carrying `_grug_noncombatant` (villagers, elders,
    vendors — they cancel every punch, so such a fight never ends). The flag
    is installed at activation by `grug_mobs.noncombatant`; do NOT narrow an
    attacker's `attack_npcs` on a civilian's behalf.
    WP35's 21st: the `set_wielded_item` write-back at
    the end of the wear block runs only when wear/toolranks changed the stack
    or WP38's per-stack wear id was newly assigned (on a player that call is a
    full inventory serialization plus packet; the skipped no-op ability writes
    were ~140/s at the 100-player target). WP38
    reshaped the melee patches: the 2026-08-07 cadence gate is deleted;
    the player-melee flag is `grug_melee`, the damage loop keeps
    vanilla's `tflp/fpi` factor (that IS the proportional model) and
    adds the Strength bonus before armor scaling, the crit roll is
    unfloored (the accumulator floors at application), knockback fires
    when the accumulated hit lands (`subtract >= 1`), and the
    feedback/subtraction split moves hit sound/blood/flash in front of
    the `damage >= 1` gate while the health subtraction and
    `check_for_death` run on the accumulated integer (passed directly to the
    post-cancellation accepted-hit hook for its lethal check).
    The WP38 review added two more: `grug_fraction` (the punch's
    clamp(tflp/fpi, 0, 1), computed once from the normalized `tflp`) and
    the wear gate that spends a swing's wear only when
    `grug_core.melee_wear_due` says that concrete stack's fractions add up
    to a whole swing — placed AFTER the item-type, creative and
    `punch_attack_uses` adjustments, so a wear-free punch never gets an id or
    consumes the accumulator. A newly assigned id is written back once even before wear is
    due; a broken stack's runtime entry and every leaving player's table are
    cleared. The 2026-08-10 native-input correction added two sites: full
    authoritative proc preparation folds the selected skill's replacement
    delta into the same punch before crit, and accepted finish after
    `do_punch`/CMI is the only place that pays/resets/applies it. The review
    added the 31st site: `grug_mobs.accepted_player_punch` runs provocation, loot
    tag, threat/rage and lethal rare/XP work only after both `do_punch` and CMI
    accept, before health subtraction; the melee-crit visual is deferred to the
    same boundary, so neither cancel path has irreversible hit side effects.
    The held-soft-target correction adds the 32nd marker: a native swing-item
    combat packet calls the Core input/acquisition seam and returns before all
    mobs_redo combat side effects; only the exact-target, claim-once token of a
    server-owned full punch may continue.
- **Loot/enchantments**: class items (wand, mage/warlock robe, iron
  armor/sword, dagger, …) drop with **random roll ranges** (e.g. strength
  +1..+3, attack speed +5..+20%). Implementation like VoxeLibre
  `mcl_enchanting`: store the rolls in **item meta** (`stack:get_meta()`),
  generate the description via meta key `description` with the rolled
  values (pattern `_mcl_generate_description`). Effect: attack speed via
  `tool_capabilities.full_punch_interval` in the stack meta override;
  **the APPEARANCE keys are per-stack meta overrides too** —
  `inventory_image`, `inventory_overlay`, `wield_image`, `wield_overlay`,
  `wield_scale`, `color`, `range`, `description` beat the item definition
  for that one stack (`lua_api.md:2929-2949`), they are texture *names* so
  the full modifier syntax works, and the client caches per item+image
  name. That is how WP35 puts the equipped weapon on every ability icon
  and how WP19 gives the elf +5 m — no new registrations, no engine patch.
  Build such a string in ONE helper: a malformed modifier is a
  client-side `generateImagePart` error and an untextured icon, with
  nothing at all in the server log;
  apply stats to player stats on equip/swap. Drop source: a `drops`
  function in the mob def rolls on kill (base variant everywhere, improved
  variant with better ranges only on elite/heartland mobs).
- **Materials & depth gating** (`items_crafting.md` §3.0,
  `world.md` §2 R6):
  - **Shipped WP43 contract:** Bronze, Iron, Steel, Silversteel, Embersteel
    and Abyssal Steel are the six universal tiers, with inclusive natural
    depth limits y = -100/-300/-500/-700/-1000/-31000. `grug_materials` is
    the sole owner of `TIERS`, `TIER_BY_KEY`, `tier_at(y)`,
    `stratum_node_for(y)`, `max_depth_for_pick_tier(tier)` and
    `can_mine_natural_at(pick_tier, y)`. Consumers never copy a depth
    boundary, harvest tier, stratum name or race-region assignment.
  - Registry consumers use `RESOURCES`, `RESOURCE_BY_KEY`,
    `RESOURCE_BY_NODE`, `PROCESSED_MATERIALS`, `GEM_GRADES`,
    `CULTURAL_MATERIALS`, `SIGNATURE_WOODS`, `RACE_REGIONS` and `DENSITY`,
    with the `resource`, `resource_for_node`, `resource_node` and `processed`
    accessors. `CURRENT_SCATTER_RESOURCES` is only the pre-WP40 placement
    roster. WP40 replaces its geometry with race-region columns; it does not
    replace or duplicate this taxonomy.
  - The natural-node contract is explicit. Picks carry
    `grug_pick_tier = 1..6`; generated ground carries `grug_natural = 1`;
    resources additionally carry `grug_resource = 1..5`. Mapgen owners must
    add every new generated ground node to `NATURAL_GROUND_NODES` and apply
    `natural_groups(groups)` when registering their own nodes. Never infer
    natural ground from `is_ground_content`: the engine defaults that field
    to true even for saplings and decorations. `NATURAL_GROUND_SET` is the
    audited lookup, not a second extension point.
  - The server-authoritative `core.node_dig` wrapper evaluates protection,
    exact target y and then the separate harvest tier. `mining_decision`
    returns structured `protected`/`no_pick`/`depth`/`shatter`/`allowed`
    state; `emit_mining_failure` owns the throttled player feedback. A depth
    refusal happens before node damage, wear, drops or settlement. A
    completed under-tier resource dig takes ×4/×6/×8/×10 time, spends exactly
    one ordinary pick use, suppresses drops and every harvest callback, emits
    shatter feedback and still lets a renewable socket enter its depleted
    state. Successful sufficient-tier settlement uses `register_on_harvest`;
    socket consumers distinguish the no-drop transaction with
    `is_shattering`.
  - All material-system nodes have no engine `level`, and every Grudgelands
    pick groupcap has `maxlevel = 0`; `max_drop_level` is a separate ordinary
    drop property and may remain non-zero. `build_pick_capabilities` and the
    six `PICK_PROFILES` are the verification/consumer seam. WP29 owns the
    final playable pick catalog and recipes, while WP22 owns runtime
    speed/durability calibration. Canonical storage blocks, Iron Sign/Ladder
    and the 20 canonical metal stair/slab nodes are storage/building
    derivatives, not natural ground and never harvest-gated.
  - Emberglass and Abyssal Steel are the only target names.
    `LEGACY_ALIASES`/`canonical_name` migrate saved WP25, Mese, Diamond and
    upstream processed/storage derivatives in one hop; retired material,
    furnace, pack, light and tool recipes are cleared before force aliases
    are installed, while reachable sign/ladder/stair recipes migrate through
    their canonical derivative aliases. Upstream
    `default:steel_ingot` means smelted iron and therefore migrates to
    `grug_materials:iron_bar`, not the canonical Steel Bar. WP26 owns all
    furnace/alloy/storage recipes — **shipped 2026-09-16** as
    `mods/ITEMS/grug_smelting`: the `grug_smelting:dual_furnace` node pair
    with two material slots plus fuel, the five single-input smelts, the five
    alloys and the twelve storage pack/unpack pairs derived from
    `PROCESSED_MATERIALS`, with `grug_smelting.RECIPES` as the public read
    surface (the engine cannot see a `dualfurn` recipe, so `grug_traders`'
    anti-loop audit walks that table instead). WP10 owns gem processing, and
    WP29 owns the final gear catalog; WP43 deliberately registers none of
    those recipe families.
- **Traders/gold** (shipped with WP7; `docs/design/economy.md`,
  `items_crafting.md` §3.8/§8.2, `world.md` §7). **WP7 patterns
  (binding):**
  - **`grug_money` is the ONLY money API.** One integer in copper units
    in player meta (100c = 1s, 100s = 1g, conversion display-only);
    `get/set/add/take` (take is atomic and never goes negative) plus
    `register_on_change`. **Never read or write the meta key directly** —
    the clamp, the HUD refresh and the change callbacks all live in
    those functions. `PlayerMetaRef:set_int` is a real 32-bit signed
    store, hence the hard ceiling `grug_money.MAX`.
  - **`_grug_sell_price` (copper) is the universal buy-back field** in
    an item def — that is how "traders buy EVERY mob drop" is
    guaranteed. For **foreign items we must not touch** (vendored
    `default:` / `mobs:`) use `grug_traders.set_price(name, copper)`
    instead of overriding someone else's def; `grug_traders.sell_price`
    resolves override → def field → 0, and **0 means "not sellable"**.
  - **`grug_gear` is a GENERATED catalog, never a hand-written list**:
    the six bracket catalogs come out of the §3.1/§3.2 curves at load
    time. Public surface for anything that sells gear:
    `grug_gear.BRACKETS`, `bracket_for_level`, `get_price`,
    `get_sell_price`, `catalog[b].fixed/.extras/.all`. **Running WP7 legacy
    still buys back at 25%** and still uses its old generated price curve.
    The authoritative target is the Common-price axis plus ceiling-rounded
    **5%** buy-back in `economy.md`; WP44 migrates the catalog and payout
    tables without bypassing these APIs.
  - **Armor pipeline** (armor was inert before WP7): item def
    `_grug_armor` → `grug_inventory.get_equipped_armor` (sums the four
    armor slots, **cached per player**, invalidated from the equipment
    inventory action, `grug_inventory.invalidate_armor` for server-side
    list writes, and on join) → `grug_core.get_armor_percent`
    (stub-override pattern, like crit/dodge) → one branch in the central
    hp-change modifier: **punch damage only**, after the dodge roll,
    before the absorb shield, `math.ceil` so armor alone never makes a
    hit free. **Capped at 60 in the consumer AS WELL AS the overrider** —
    that modifier is registered with `true` (may raise HP), so a pct >
    100 would turn a punch into a heal.
  - **Armor-rank gate**: items carry `grug_armor_class` (cloth 1 <
    leather 2 < metal 3), classes carry `armor_rank`
    (`grug_classes.get_armor_rank`, no class = 1); the check sits in the
    existing group-filtered `allow_put` with a **throttled** chat
    refusal (the allow callback fires repeatedly while dragging), and a
    class change unequips what the new rank may not wear.
  - **Vendor NPCs use plain `mobs:register_mob`, NOT
    `grug_mobs.register_mob`** — that wrapper IS the level/XP engine and
    would give a shopkeeper a level, a health bar and aggro wrappers.
    `type = "npc"` is what makes them permanent (it exempts them from
    all three mobs_redo removal paths); a **truthy `do_punch` return**
    is what makes them invulnerable (the api.lua precedence gotcha
    above). WP7's placement was a throttled globalstep against fixed capital
    offsets, whose presence gate must stay inside the object-activation
    radius or duplicates spawn forever. **Since WP13 that is only the
    fallback**: a settlement's vendors stand on the `vendor` sockets its
    blueprint exports (`grug_core/settlement_sockets.lua`, placed by
    `grug_mobs/start_npcs.lua`), and the offsets serve only a capital whose
    core has not been built — an empty set since all six cores landed.
    `grug_traders/vendors.lua` reads which capitals are socketed from the
    registry, never from a hard-coded list. The twelve **profession shop**
    vendors (butcher, smith, fishmonger, baker, tailor, mason, brewer,
    bowyer, herbalist, armourer, tanner, embalmer) are socket-only, carry no
    race of their own — the settlement key answers that — and only `smith`
    and `armourer` reach the gear-bracket tabs.
  - **Rotation is deterministic**: seed = `floor(os.time()/3600)` +
    per-vendor salt + bracket, fed into **`PcgRandom`** — never
    `math.random`/`table.shuffle`, whose sequence depends on what else
    called them since startup. Two players at one vendor in one hour
    must see the same shelf, and a restart must not re-roll it.
  - **No detached inventories in trade UIs.** The reference
    implementations (VoxeLibre `mobs_mc/villager.lua`, LotT
    `lottmobs/trader.lua`) move items through detached
    `wanted/input/offered/output` lists — that loses whatever sits in
    the input list when a player disconnects mid-trade. Every transfer
    goes directly against the player's own `main` list, the vendor's
    "stock" is a computed list of names and prices, and **every formspec
    action re-validates from scratch** (session, distance to the stored
    POSITION not an ObjectRef, access rule, and prices/counts recomputed
    server-side against the snapshot the player was shown).
  - **Three startup audits** in `grug_traders/init.lua`
    (`register_on_mods_loaded`; no warning/error finding when clean —
    one informational action line, the function-drop audit count,
    always prints): every mob drop has a
    price; no vendor buy/sell spread that prints money (discount
    included); no craft/cook recipe whose output is worth more than its
    priced inputs (the §3.8 anti-loop rule — the real case was smelting
    a 3c iron lump into a 5c steel ingot). Add prices, don't disable
    them.
- **Quests**: no ready-made framework in the references. Building blocks:
  trigger/counter patterns from `lottachievements` (awards fork), event
  stages from VoxeLibre `mcl_events` (`cond_start/on_step/cond_complete`),
  quest log as a formspec, state in player meta, quest givers via NPC
  `on_rightclick`, HUD `waypoint` elements for quest targets.
- **Mapgen/biomes.** The **WP40 R7 pipeline is the only mapgen owner** since
  the production cutover: `mods/MAPGEN/grug_mapgen/init.lua` is nine lines and
  loads `wp40/r7_loader.lua`, whose header says it plainly — "Legacy
  biome/ore/decoration/ocean/structure loaders are deliberately absent".
  `grug_mapgen/biomes.lua`, `ores.lua`, `decorations.lua`, `geometry.lua`,
  `ocean_mask.lua`, `ocean_mask_mapgen.lua` and `structures.lua` **no longer
  exist**, and neither do `register_mirrored`, `column_cap`, `clean_shell`,
  `_grug_spawn_zones` or the `grug_core.*camp_platform*` family. Do not write
  code or a brief against them; `docs/design/world_zones.md` §§8–14 and
  `docs/research/wp40-completion.md` are the current contract, and
  `docs/design/biomes_mobs.md` §1/§4 keep the retired WP18/WP36 tables as a
  labelled historical record only.
  What R7 registers, and what that costs you: **zero Lua biomes and zero Lua
  decorations**. One mapgen script (`core.register_mapgen_script`,
  `wp40/r7_mapgen.lua`), one `register_on_generated` VM transaction, and a
  six-record native ore allowlist in `wp40/r7_native.lua`. `game.conf` pins
  `allowed_mapgens = v7`; `default`'s own `register_biomes/ores/decorations`
  stay uncalled (GRUG PATCH at the tail of `mods/BASE/default/mapgen.lua`),
  because an ore or decoration whose `biomes` names do not resolve is silently
  unrestricted world-wide. The v7 terrain and climate noise params are
  overridden from `r7_native.lua` (`core.set_mapgen_setting_noiseparams`) —
  **test mapgen work on a FRESH world**, an existing one gets seams.
  **Registration order is still a tool, not trivia**: in mgv7 a mapchunk runs
  caves (`mapgen_v7.cpp:335`) → ores (`:355`) → dungeons (`:359`), and inside
  the ore stage the ores run in **registration order**, each converting only
  nodes that still match its `wherein`. That is the whole mechanism behind the
  rock strata, which now live as five native `ore_type = "stratum"` records in
  `wp40/r7_native.lua` (slate/basalt/granite/emberrock/abyssal_rock under
  `default:stone`'s own band): registered last against `default:stone`, they
  take exactly the nodes no other ore claimed, and — running after the caves —
  they convert the already-carved cave walls too, so those inherit their
  stratum for free. (Dungeons run after the ores, so dungeon walls are *not*
  stratum rock — accepted.)
  **Landmine since WP25: `default:stone` no longer exists below −100.**
  Every node whitelist, every `wherein`/`place_on` and every mob spawn
  `nodes` list that means "underground rock" has to carry
  `group:grug_stratum` as well, or it silently narrows to the −40…−100
  sliver. WP25 repaired exactly that on four cave spawn rows (zombie,
  giant spider, stone + mesa golem); `default:stone` itself carries
  `grug_stratum = 1`, so the group alone is the complete predicate.
  **Two Lua environments, and the split is the rule, not a detail**: a pass
  that only needs the chunk belongs in the **mapgen env**
  (`core.register_mapgen_script`), a pass that needs `grug_core`, mod storage
  or the settlement/socket registries cannot go there at all and stays in
  `register_on_generated` in the main env. Constants cross via `core.ipc_set`;
  never copy them. **One lesson from the retired ocean mask is worth keeping
  for the next VM pass:** a pass that writes near the top of a mapchunk must
  reach **`emax.y`**, not `maxp.y`, because the engine places decorations up to
  the emerged top edge (`mg_decoration.cpp:424`) — clamping to `maxp.y` is what
  once left floating tree crowns over the water.
  **Current zone/level queries** (published by `grug_core/zone_authority.lua`,
  which is also the sole publisher of the `grug_zones` global — it refuses to
  install if something else already published it) — this is the whole
  `grug_core` surface, not a sample: `territory_at`, `zone_at`, `mob_level_at`,
  `guard_level_at`, `open_sea_at`, `surface_level_at`, `start_position`,
  `start_anchor`, `start_identities`, `capital_anchor`, `outpost_at`,
  `outpost_patrol_target`, `outpost_position`, `rare_route` and
  `world_protected_for_faction`. `grug_core.difficulty_at` is **gone** — the
  difficulty field survives only inside WP40's own compatibility layer.
  Gameplay consumers read the richer surface off `grug_zones` directly
  (`biome_at`, `id_at`, `faction_at`, `race_region_at`, `pvp_rule_at`,
  `water_class_at`, `territory_rule_at`, `surface_mob_level_at`) and **never**
  the engine biomemap, because the authored surface pass — not climate
  competition — owns logical biome identity.
  LotT trick: biome signature nodes drive mob spawns via a node whitelist —
  those tops live in `grug_nodes` (blight_dirt, bone/forest/silver litter,
  mesa_clay, mud) and exist FOR the trick; the generic `_grug_spawn_check`
  and `grug_mobs/spawn_policy.lua` do the gating on top, against `grug_zones`.
  **The WP40 world contract is SHIPPED** (decided 2026-08-11, delivered
  2026-09-13): exactly **38** land zones in
  `docs/design/world_zones.md` §§8–9, each with one `race_region`; six
  start/home/capital chains, every ordinary level-31–60 zone contested, and
  two level-60 dragon endpoints. The hybrid-v7
  pass and `grug_zones` API are §13; the 32-seed acceptance gate is §14.
  Race region, territory and PvP rule are independent fields. Every ordinary
  level-31–60 land zone is contested and editable by both factions. Roads,
  camp shells, tents, fences and battlefield dressing remain mutable but
  claim-excluded; only bounded functional anchors, irreplaceable route pieces
  and renewable-resource sockets receive hard protection.
  Material design owns the complete `race_region` mapping of
  G1, G2, cultural material and signature wood; map code stores only the
  region identity and placement data needed to consume that mapping. Each
  endpoint apex camp has exactly 12 renewable sockets, two per gem. Both
  factions may mine them; the small functional anchor and sockets are
  protected, while the surrounding camp shell remains mutable and
  claim-excluded.
- **Map/fog of war**: VoxeLibre `mcl_maps` renders explored chunks as PNG
  (`colors.json`, height shading) and pushes them via
  `core.dynamic_add_media` — the best base for our global map. Minimap
  gating: `hud_set_flags{minimap=...}` (pattern: minetest_game `map`).
- **UI**: formspecs (`core.show_formspec` +
  `register_on_player_receive_fields`), set `formspec_version` +
  `real_coordinates[true]`. 3D character preview: `model[]` element.
  Skill tree = formspec with an `image_button` grid.
- **Player model/skins**: `player:set_properties{visual="mesh", mesh=...,
  textures={...}}`; texture layering (skin/armor/wielditem) following
  LotT `lottarmor/multiskin.lua`.

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
