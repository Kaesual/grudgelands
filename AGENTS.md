# AGENTS.md — Project Guide

MMO-inspired Luanti game, titled "Grudgelands". Goals and scope:
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

## Fresh-server development mode

- **Standing user instruction, decided 2026-09-13:** the first release is
  still under development. Assume the server and world are **always fresh**.
  There are no old servers, worlds or player records to migrate.
- Do not add backward-compatibility branches, saved-world/data migrations,
  legacy-name aliases, old-format readers, compatibility placeholders or
  cleanup LBMs/timers for earlier development versions. One deliberate
  exception (Round 26 ruling 14): the twelve tool aliases from the former
  `default:` tool names to `grug_materials:` (`grug_materials.TOOL_ALIASES`)
  keep repository references working; they are not an old-world migration. Remove existing code
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

**Round 35 complete locally, 2026-10-05 (not pushed).** "Fixes and
character creation" from the user's Round 34 GUI test: the server's aiming
rays test rotated selection boxes in Lua (`grug_core.aim_raycast`, an
engine bug since Luanti 5.12; the
[upstream-workaround list](docs/technical/upstream-workarounds.md));
music only in the six capitals, one rotation each, either music or the bed,
35 % by default; the break sound, a clearer broken look, the bare hand for
a skill without a weapon, dig sounds for ores and sand, flint removed,
quest lists coloured by status with read-only text; character creation in
one window with nothing stored before "Create character"; night mobs leave
at dawn and a drop audit against the income targets; level-proof talents
and the user's picks from a review of all 64. Next: the GUI test (desktop
and web build), then WP9.
[Plan, completion and GUI checklist](docs/planning/round35-plan.md#completion-2026-10-05).

**Round 34 complete, 2026-10-04 (pushed 2026-10-05).** "Sound", V1's
sound: every file picked by the user on a listening page (the approval
gate); `grug_sounds` (one-line play helper, formspec click, cues at the
game's events, many silent by choice), hits by weapon kind, one cue per
ability theme, mob voices in 22 families, dragon and King cues;
`grug_ambience` (beds per region, night, cave, deep and sea, dragon-island
thunder, forge, hearth and flowing-water loops, four music pools pushed on
demand, the menu theme, Help → Sound, `/music`, `/ambience`); fix lanes for
mobs in water and the Round 33 findings (Bag of Coins, service markers,
cooking costs, thin ice). Rules: [sound.md](docs/design/sound.md), credits:
[CREDITS.md](CREDITS.md). Late fix: the seed failures (about 1 % of
random seeds) and the seed fleet. The user's GUI test fed Round 35.
[Plan, completion and GUI checklist](docs/planning/round34-plan.md#completion-2026-10-04).

**Round 33 complete, 2026-10-04 (pushed with Rounds 30–32).** "Items,
professions and achievements", the items design session's rulings: drops by
quality (normal 5/2/1 %, named, elite, leaders and captains 10/10/5 %,
bosses two blue or gold items at item level 65/70), the level requirement on
all gear; enchant values by item level up to the tier's cap with the tier
shown and T7, profession upgrades and the crown (the Crownbinder); bows to
the Leatherworker, spellbooks to the Tailor; Alchemy a secondary, progress
from real recipes, the cultural materials and finishes, grips, reagents and
the Warding Draught removed; crit ×2 with 0.05 % per Dexterity point;
T1-only vendor gear, repair ×1.00, potions I–VI with one cooldown, the Decor
Merchant; per-character achievements that unlock cloaks. Numbers:
[item_tiers.md](docs/design/item_tiers.md). Needs a fresh world. Next: the
GUI test; its findings fed Round 34.
[Plan, completion and GUI checklist](docs/planning/round33-plan.md#completion-2026-10-04).

**Round 32 complete, 2026-10-03 (pushed 2026-10-04).** "Fixes,
preparation and research": the minimap zoomed ×2, hostile camps marked on
the Map tab, zone names coloured by the territory at the position with a
territory line (`grug_pvp.territory_at`); one LMB hold state machine (gather
may become combat and back); quest kill labels with the zone's mob names
and two validator rules; combat and personal notices in the message feed,
the quest log in one text field; the Map tab, party HUD and camp/leader
tick spread over server steps; three read-only studies
([performance](docs/research/perf-review-2026-10-r32.md),
[sound](docs/research/sound-research-2026-10.md),
[items and professions](docs/research/items-professions-analysis-2026-10.md)).
Sound is V1; WP9 moved to a later round; the items design session became
Round 33.
[Plan, completion and GUI checklist](docs/planning/round32-plan.md#completion-2026-10-03).

**Round 31 complete, 2026-10-03 (pushed 2026-10-04).** "PvP, appearance and
clean-up": geographic PvP (WP41: `grug_pvp`'s per-player flag, the PvP tab,
icons, banner and target frame, PvP from depth T4), the NPC faction filter
for services and map markers, WP42's PvP-POI part (a fortress per faction
with a General and the seventh waystone, 16 Battlegrounds war camps with
named captains, 24 fortress quests from level 40), character looks at
creation and NPC look rolls, enchant colours on gear, the dragon arenas
redesigned (round leash arenas with hazards and the dragon's wrath), the
Round 30 clean-up items and a fixture runner. Rules: [pvp.md](docs/design/pvp.md).
Next: fresh world and the two-client GUI test (Round 30's is still open);
seed-dependent POI placement was set aside.
[Plan, completion and playtest checklist](docs/planning/round31-plan.md#completion-2026-10-03).

**Round 30 complete, 2026-10-02 (pushed 2026-10-04).** "Performance and
clean-up" from the [performance review](docs/research/perf-review-2026-10.md):
the quest-state cache and the Map tab at most every 2 s (P1, with Return home
moved to the Character page and quest markers that follow held items and
levels), the region-map file cache and boot memory (P3, a later start about
7 s instead of about 16 s), mob pathing with a per-step A* budget and the
give-up of unreachable targets, three merged spawn ABMs instead of 88 (P2),
per-player ticks (P4: crafting index, crosshair, tag-carrier slots); a pier
and a beach at the four dragon-island landings (L); the legacy quest fields
removed, fixtures repaired and the Dawnmere NPC duplication fixed (C);
band-4/5 loot smoothing with recomputed prices (E). Next: fresh world and
GUI test (still open).
[Plan, completion and playtest checklist](docs/planning/round30-plan.md#completion-2026-10-02).

**Round 29 complete and pushed, 2026-10-02** (tested by the user). "Economy
and travel": 491 new quests on the Round 28 framework (one track per race,
the contested 31–40 zones, the 41–60 front with repeatable and island
bounties) replace the 240 legacy quests; WP44 (one price module, 5% buy-back,
income-derived mount, boat and respec prices); WP17 (boats as water mounts
with the Shipwright, waystones at every start and capital, the Kraken
retune); a mapgen bundle (gems by depth, `apex_sockets` removed, mapgen band
data, the Battlegrounds 50 % wider with a middle road); the read-only
performance review that became Round 30.
[Plan, completion and playtest checklist](docs/planning/round29-plan.md#completion-2026-10-02).

**Round 28 complete and pushed, 2026-10-02.** The 2026-09-30 playtest fixes (Track A),
the questing and leveling framework (Track B: sub-types and loot by band,
kill XP `25 + 5L` with its curve, per-zone quest data, self-contained
professions), the catalogue with 89 icons and the naming rule, rule-based
spawn regions for all 38 zones with the border rule, quest-log level ranges
and zone names. Quest content per race track, the front and the islands
moved to Round 29 ([quests plan](docs/planning/round29-quests-plan.md), with
the [economy lanes](docs/planning/economy-vendor-plan.md),
[WP17](docs/planning/travel-boats-waypoints-plan.md) and a mapgen bundle).
[Plan, completion and playtest checklist](docs/planning/round28-questing-leveling-plan.md#completion-2026-10-02).

**Round 27 delivered, 2026-09-30.** WP50: our own round minimap
(`grug_map`) with quest-giver, service, home and party markers in place of
the native minimap, the `grug_map_quality` setting (normal/high) for the Map
tab and the minimap, readable relief and a tiled map base (Lane M), and the
documentation (Lane D), then the gliding minimap with a pewter bezel after the
user's playtest. Fully pushed (in `9dd85b6e`).
Next: short playtest.
[Plan, completion and playtest checklist](docs/planning/round27-minimap-plan.md#completion-2026-09-30).

**Round 26 delivered, 2026-09-29.** Claim Stone draft/activation and
the Housing Steward (Lane S), registration cleanup WP28 with the tool
namespace (Lane R), the status-icon package (Lane I), organic capitals with a
character per capital (Lane W) and the documentation cleanup (Lane D). All
lanes merged on main and pushed. Playtested 2026-09-29.
[Plan, completion and playtest checklist](docs/planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29).
The [work-package audit](docs/planning/wp-audit-2026-09-29.md) and its user
decisions (2026-09-29) set the current BACKLOG and V1 scope (ROADMAP).

**Round 25 delivered, 2026-09-29.** Claim Stone housing (WP24,
`grug_housing`, [housing.md](docs/design/housing.md)): claims, fuel,
permissions, interaction guard, Housing Stewards, Character status and the
stone as travel home; road and POI world protection; capital planner places
required and named buildings before fill. Coordinated by Claude Opus 5.5.
[Plan, completion and playtest checklist](docs/planning/round25-housing-plan.md#completion-2026-09-29).
Merged on main as `7270feb3` and pushed.

**Round 24 delivered, 2026-09-29.** Mining tiers (tier rock with
engine-native pick gating, loose ground, tool levels), ores and layers in the
underground fill, start-zone mob levels and density, gathering XP, quest
tracker, lava/drowning damage, protection depth, housing areas as ordinary
terrain and pausable character creation; coordinated by Claude with native
Opus implementation and independent reviews.
[Plan, completion and playtest checklist](docs/planning/round24-mining-underground-mobs-plan.md#completion-2026-09-29).
Merged on main as `1e338503` and synchronized to Luanti; pushed as
`d4eaffff` and accepted by the user.

**Round 23 delivered locally, 2026-09-28.** Full-column world preparation,
habitat-driven vegetation renewal and capital walls; coordinated by Claude with
native Opus implementation and independent Opus reviews (user routing for that
session). [Plan](docs/planning/round23-world-life-plan.md),
[completion and GUI checklist](docs/research/round23-completion.md). Merged and
synchronized; no remote push. Phase 2 (tree line, shrub band, snow, forests and
clearings) and the lake-wall playtest fix are merged as `f54c299d`. Next: user
preparation of a fresh production world and playtest.

**Round 21 delivered locally, 2026-09-24.** Reviewed terrain/access, mining,
furnaces, aquatic detail and playtest fixes merged as `96c40fa3` and synchronized
from main. [Receipt](docs/research/round21-completion.md),
[playtest checklist](docs/research/round21-playtest.md),
[startup correction](docs/research/round21-startup-fix.md) (fish disposition and
native arrow catalog binding; real engine registration verified),
[execution ledger](docs/planning/round21-state.md). All native implementation
agents finished. Recorded larger mapgen checks cost about 95 CPU seconds; no
full-world/census fleets. No remote push. Await user GUI acceptance.


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
(Historical: that round ran without Claude tasks; the restriction ended with
the documentation round, [receipt](docs/maintenance/documentation-round.md).
Current routing: [agent model policy](docs/process/agent-model-policy.md).)

Game delivery and pending acceptance: [project status](docs/STATUS.md).
Round 21 and earlier follow-ups are locally delivered; GUI acceptance remains user-run.
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
- The former resource integration checks (`tools/wp40/resource_sampling/`,
  run through `tools/wp40/quality/final_micro.lua`) were retired in Round 22
  (D22); git history keeps them. Historical 32-seed
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
  - **Write `x * x`, never `x ^ 2`, in mapgen and other deterministic code:**
    LuaJIT's JIT turns `x ^ 2` into `x * x`, its interpreter calls `pow()`,
    and the last bits differ, so results depend on what ran compiled.
    `tools/check_lua.sh` fails on it under `mods/MAPGEN` (sweep 6); details in
    docs/research/luanti-lua.md "Floating point: LuaJIT interpreter vs
    compiled code".
  - Vector `==` only works if BOTH operands carry the vector metatable —
    compare positions with `vector.equals`, never `==`.
  - Backported from 5.4 (engine-injected, both builds):
    `string.pack`/`unpack`/`packsize`.
- **Interpreter/test layers are binding:** on every Lua change run
  `bash tools/check_lua.sh <files>` — it runs the `tools/bin/luac51 -p`
  parser, the `SETGLOBAL` check and all six sweeps of
  `docs/research/luanti-lua.md` (sweeps 1–5 grep; sweep 6, `x ^ 2` /
  `math.pow`, only on `mods/MAPGEN` files). Two things about those sweeps are
  easy to get wrong. They are scoped to `mods/*/grug_*`, so Lua under `tools/`
  is **not** covered by them and needs the check run explicitly. And the
  harness scripts that run them require **ripgrep** (`dnf install ripgrep`):
  until 2026-08-15 a missing `rg` made nine of them report success without
  running, because exit status 127 inside an `if` condition reads exactly
  like "no match found". Use LuaJIT for development and exhaustive runs
  where supported. **Mapgen work is exempt (Round 22 D1, 2026-09-25):** no
  PUC runs, parity tests or gates during mapgen development; at most one
  optional PUC crash smoke test once the mapgen is finished. For all other
  work: do not run PUC runtime at intermediate milestones. On
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
- **Engine workarounds are listed in
  [docs/technical/upstream-workarounds.md](docs/technical/upstream-workarounds.md)**
  (Round 35 ruling §2.10): each with the upstream problem, our workaround
  and where it lives, how to tell upstream fixed it and what to remove.
  Check it at every engine version change and at the start of each round;
  a new workaround for an engine bug gets an entry there.
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

### Zone content (since Round 28)

- **Mobs, loot, quests and enchant inputs are data**, one file per zone where
  per-zone: `grug_mobs/data/zones/<zone>.spawns.json` (spawn recipe),
  `grug_quests/data/zones/<zone>.quests.json` (and `.front.quests.json`),
  `grug_mobs/data/{subtypes,items,drops,tints}.json`,
  `grug_professions/data/enchants.json`. Tune by editing data, not code.
- **Zone data holds rules, never coordinates:** maps differ per seed. Surface
  spawns come from the recipe's regions built on the seed's own terrain
  ([spawn_regions.md](docs/design/spawn_regions.md)); no hand-placed areas.
  A zone's level band is its mapgen zone record
  (`grug_mapgen/wp40/source/simple_map.lua`, served by `grug_zones`); it
  changes only in a mapgen round.
- **After a recipe change** run `tools/r28_regions/run.sh <zones>` (region
  images and stats on several seeds, then `quest_targets.py`) and
  `tools/r28_world/run.sh` (world view, level fit across borders; the border
  rule is `tools/r28_world/border_rule.py`), and show the images when the
  user decides on a distribution. Catalogue or quest design files:
  `python3 tools/r28_design/validate.py`.
- **Names:** signal words (Small, Large, Braindead …) only on start-zone
  roles; every other sub-type has its own unique name; kill quests name the
  exact sub-type and place (design frame §5,
  `tools/r28_names/build_review.py --check`).
- **Quest texts** name items, never their tooltip texts. Directions and
  places that depend on the seed (regions, leader spots) appear only as
  placeholders the code fills per seed
  ([spawn_regions.md](docs/design/spawn_regions.md#directions)); never a
  fixed compass word. Quest files that require each other change together.

### Economy and travel (since Round 29)

- **Every vendor payout comes from one price module**
  (`grug_traders/prices.lua`, pure rules in `price_rules.lua`): items carry
  no price field and there is no `set_price`; a new sellable needs a class
  and a tier, a new recipe must pass the load audit (output ≤ inputs).
  Mount, boat and respec prices come from `tools/r29_e4/income.py`
  (`--check` compares the shipped tables). Rules:
  [economy.md](docs/design/economy.md).
- **Quests pay copper from their weight** unless `rewards.copper` is set
  ([quests.md](docs/design/quests.md)); the front budget counts two repeats
  per bounty. Quest checks: `quest_targets.py` (every target on the region
  stats of three seeds; the coordinator also used six), `validate.py
  --game`, `ledger.py --track <race>`.
- **Boats are water mounts** in `grug_mounts` (tiers 5 and 6 next to the
  four riding tiers); **waystones** are a mapgen node at every start,
  capital and (since Round 31) PvP fortress, travel goes through `grug_home/travel.lua` (one shared path with
  home return and respawn; `waypoints.lua`, pure rules in
  `waypoints_core.lua`). Rules: [boats.md](docs/design/boats.md),
  [world.md](docs/design/world.md) §6.
- **Gems are depth-tiered** (T1 Citrine … T6 Diamond, each only in its own
  tier rock); there are no G1/G2 grades and no apex sockets.
- Round 29 fixtures and probes live in `tools/r29_<lane>/` (`b` boats,
  `w` waystones, `e1` prices and `band_payout.sh`, `e4` income, `mres`
  gems, `mgeo` bands and middle road, `q1` placeholders, `t`
  `quest_targets.py`, `p` playtest fixes).

### Performance (since Round 30)

- **Numbers are comparisons, never targets**; a lane re-runs its own probe
  before and after on the same seed and area. The
  [performance review](docs/research/perf-review-2026-10.md) holds the
  probes' method; module seams are in the
  [module guide](docs/technical/module-guide.md).
- **World-folder caches** (the world layouts, D71; the region maps
  `grug_region_maps.txt`; the Map tab's zone grid `grug_map_zone_grid.txt`)
  share the key `grug_mapgen.wp40.world_key` plus a digest of their builders'
  files. A new file a cached build reads must join its key; any failure
  rebuilds, never stops the load.
- **Mobs:** A* only inside the per-step budget (`mobs/grug_obstacle.lua`);
  no `get_properties()` in per-step code (`self._grug_cbox`); spawn rows go
  through the three merged spawn ABMs (`grug_mobs/spawn_abms.lua`), and a
  surface row no zone keeps registers nothing.
- **Quest state** is cached decoded per player: never write into a table
  `load` returns; marker consumers read `grug_quests.marker_states` (the
  Map tab compares its version, the NPC tags read it on the 1 Hz carrier
  pass); only the minimap registers `register_on_markers_changed`.
- Round 30 fixtures and probes live in `tools/r30_<lane>/` (`p1` quest state,
  tracker, Map tab, minimap and Character page; `p2` pathing, give-up,
  collision boxes, merged spawn ABMs; `p3` region-map cache incl. input
  coverage and corruption cases, `run.sh`; `p4` crafting index with the
  shipped recipe corpus, crosshair, carriers, flight sweep, farming; `l`
  island landings, `engine.sh`; `c` start-NPC duplication).

### PvP, looks and fixtures (since Round 31)

- **PvP is one flag per player** (`mods/PLAYER/grug_pvp`, rules in
  [pvp.md](docs/design/pvp.md)): combat code asks `grug_pvp.can_harm` /
  `can_support` and never changes PvP state; `grug_core` reaches it only
  through the seams `grug_pvp` installs (`pvp_can_harm`, `pvp_hit_landed`).
  The location is sampled once a second, never on the combat path. PvE
  combat must not notice PvP: a change on the combat path reports the PvE
  micro run before and after (`tools/r31_pvp/run.sh`).
- **An NPC's faction decides whom it serves** (`grug_factions.serves` /
  `refuse` in `grug_factions/service.lua`), never the place; map markers
  carry the NPC's faction and settlement icons follow
  `grug_map/settlement_icons.lua`.
- **Looks:** a player's look is stored once (`grug_visuals.set_look`) and
  never changes; NPCs roll theirs once (`_grug_look_seed`); a garrison
  mixed by design asks `grug_visuals.npc_race` with `{mixed = true}`. New
  look or enchant art comes from the generators
  (`tools/wp13/gen_character_visuals.py`, `tools/r31_b/gen_enchant_masks.py
  --check`).
- **PvP POIs** are rules in `grug_mapgen/wp40/r31_pvp_catalog.lua` with
  fixed anchors 101–118; garrisons come from
  `grug_mobs/pvp_garrison.lua`. Whether POIs move to per-seed placement is
  an open decision (BACKLOG).
- **Fixtures:** `tools/run_fixtures.sh` runs every portable fixture
  (`tools/*/portable_test.lua`, `tools/*/fixture.lua` with the repository
  path) under LuaJIT and exits 1 on a failure; a new fixture takes the
  repository path as `arg[1]` and exits non-zero on failure
  ([tools/README.md](tools/README.md)). Round 31 fixtures and probes live in
  `tools/r31_<lane>/` (`pvp` flag core and engine probe, `p2` PvP UI, `p1b`
  support refusal and mount boxes, `n` faction filter, `c` clean-up, `a`
  looks and `engine.sh`, `b` enchant colours, masks and `engine.sh`, `s`
  PvP blueprints, `m` placement, `spacing_check.lua` and `engine.sh`, `g`
  garrisons, `q` fortress quests and `run.sh`, `da2` dragon arenas).

### Input, notices and per-player passes (since Round 32)

- **The LMB hold is one state machine** (`grug_abilities/input.lua`,
  rules [classes.md](docs/design/classes.md#left-click-and-held-input)
  §2b): gather or combat locked on a foe; a new hold rule changes that
  machine and its fixture (`tools/r32_f2`), never adds a second lock.
  Self and support skills fire only on a fresh press.
- **The territory a position belongs to** comes from
  `grug_pvp.territory_at` (the flag's own rule), never from the player's
  flag; the zone banner and minimap line use it.
- **Personal notices go to the message feed** (`grug_core.feed` with a key
  per notice group, so a repeat refreshes its line), never to chat; chat
  keeps deaths, rare sightings, boss and dragon warnings and text too long
  for the feed's 2.5 s.
- **Quest kill labels** use the zone's mob name; `validate.py`
  (`E-label-name`, `E-item-source-drop`) keeps quest data so.
- **No pass handles every player or zone in one step:** a periodic
  per-player or per-zone pass spreads its work over slots or a per-pass
  budget (the quest tracker and party HUD's five slots, the Map tab's 2
  builds per 0.1 s pass, the spawner's zone slices); measure it with
  stand-ins before and after (the performance review's probe).
- Round 32 fixtures and probes live in `tools/r32_<lane>/` (`f1` territory
  line and hostile camps, `engine.sh` the minimap traffic and location
  probe; `f2` the hold machine and the quest labels; `f4` the Map tab poll
  budget and party HUD slots); the zoom geometry is checked in
  `tools/r27_minimap`, the spawner's zone slices in `tools/r28_s1`.

### Items, professions and achievements (since Round 33)

- **One source per item number:** enchant values, upgrade and enchant
  inputs, the crown, potions and elixirs, drop sale values, repair and the
  culture prices live in [item_tiers.md](docs/design/item_tiers.md); its
  generated tables come from `tools/r33_ds/` (`build_doc.py --check` fails
  when the file is stale). Change the data or the script, never a generated
  table by hand; drop rates are data in `grug_quality/init.lua`
  (`DROP_CHANCES`, `BOSS_DROPS`, `BAG_DROPS`).
- **An enchant's value is never stored as a free number:** every enchant
  carries stat, channel and tier, and `grug_items.enchant_value(stat, ilvl,
  tier)` derives the value through grug_quality's one store path whenever
  the item level or tier changes (rolls, enchants, upgrades, the crown).
  Station work is a `grug_jobs.register_station_operation` kind
  ("enchant", "upgrade"); the crown is `grug_items.crown_item` /
  `crown_preview`, called by the Crownbinder (`grug_traders/crown.lua`).
- **Professions:** two professions dress each class
  (`grug_professions.FAMILY_OWNERS`); progress comes only from recipes whose
  `progress` flag is set, through `grug_jobs.award_progress`; Alchemy and
  Cooking are secondaries with their own book slots.
- **Money:** `tools/r29_e4/income.py --check` passes again and covers the
  mount, boat and respec prices and the crown fee
  (`grug_traders.CROWN_FEE`); a change to loot, repair or quest copper
  re-runs it. Vendors sell T1 gear only; blue sells ×3, gold ×6
  (`price_rules.QUALITY_FACTOR`).
- **Achievements and cloaks** (`mods/PLAYER/grug_achievements`, rules
  [character_visuals.md](docs/design/character_visuals.md) §5b): an
  achievement is catalog data on an existing counter; tier N of `<id>`
  unlocks cloak `<id>_N`; everything is stored per character. Counters
  come from hooks, never a second kill, craft or boss path
  (`grug_mobs.register_on_boss_kill`, `grug_pvp.register_on_stat`,
  `grug_jobs.register_on_award_progress`). Cloak textures are 32×32 (outer
  face left, lining right), each with a `LICENSE-media.md` row; the player
  model comes from `tools/r33_c3/gen_cloak_model.py --check`.
- **Capital services** take over an existing gate resident through
  `grug_core.assign_service_socket` (closed roles: innkeeper,
  housing_manager, crownbinder, culture_vendor); no blueprint or mapgen
  change.
- Round 33 fixtures live in `tools/r33_<lane>/` (`ds` the value rule against
  the doc, `c1` drops, bosses, bags, requirement and `drop_income.py`, `c2`
  professions and progress, `c3` achievements, cloaks and the cloak model,
  `c4` enchant tiers, upgrades, crown and families, `c5` crit, vendors,
  repair, potions and the capital services).

### Sound (since Round 34)

- **Approval gate (user ruling):** no sound file ships unless the user
  picked that exact file on a listening page; the pick is recorded in
  `tools/r34_<lane>/approved.txt` (or a later round's list) and the
  fixture fails on an unlisted `.ogg`. An event without an approved file
  stays silent (no spec or no call site), never a placeholder. A changed cut
  is a new file and needs a new pick. Every file has a `LICENSE-media.md`
  row; CC BY and CC BY-SA authors also go into [CREDITS.md](CREDITS.md).
  Rules and conventions: [sound.md](docs/design/sound.md).
- **One play path:** effects go through `grug_sounds.play(event, target)`
  with a spec in `grug_sounds/init.lua` `EVENTS` and the event in `HOOKS`;
  no new `core.sound_play` for game events. Mob voices are a family in
  `_grug_voice` (every mob names one, or `false`); ability cues are
  `grug_abilities.CAST_SOUNDS`. Beds, loops, calls and music are data in
  `grug_ambience/data.lua`; a new zone bed is a name there plus a pick.
- **Music stays out of `sounds/`:** tracks live in `grug_ambience/music/` and
  are pushed per player on demand, so the first join does not grow with
  them.
- **Freesound and downloads:** sound research reuses what is downloaded
  first, accesses Freesound serially (rate-limited) and uses the public HQ
  previews only; downloaded source material is never deleted or moved.
- Round 34 fixtures and probes live in `tools/r34_<lane>/` (`s1a` events,
  specs, call sites and the approval list; `s1b` voices, ability cues and
  its approval list; `s2` ambience and music rules, the approval list and
  `engine.sh`, the pass cost and flowing-water census; `f1` the wading rule
  and `engine.sh`, a mob at real water crossings; `f2` the Bag of Coins, the
  sell refusal, the damage fit, the cooking order and `render_icons.py`).

### Fixes and character creation (since Round 35)

- **Every server-side aiming ray goes through `grug_core.aim_raycast`**
  (`grug_core/combat_ray.lua`), never `core.raycast` with objects: the
  engine misreads `rotate = true` selection boxes since 5.12
  ([upstream-workarounds.md](docs/technical/upstream-workarounds.md) §1).
  Rays that point only at nodes (blink, homing, mob line of sight) keep the
  engine's raycast.
- **Talent values are level-proof:** a damage or armour value that adds
  before the level scalar is stored as a percentage of the base hit
  (`grug_core.baseline_melee_total`) or the armour constant `K(L)`, listed
  in `grug_classes` `LEVEL_SCALED_KEYS`; `get_talent_bonus` returns the
  amount at the player's level and the tooltip shows it
  ([skill_trees.md](docs/design/skill_trees.md) §2.10). A new flat "+N"
  talent value is a design error.
- **Music plays only in the capitals** (`grug_ambience` `D.rotations`,
  `grug_map.location.capital_of`): either music or the bed; a rotation
  change is a data edit, a new track still needs the user's pick.
- **Character creation** is one window (`grug_classes/selection.lua`) with
  a session-only draft; nothing is stored before "Create character", and
  the look comes from `grug_classes.register_look_panel`.
- **Night region mobs leave at dawn** (`grug_mobs/dawn.lua`): a mob spawned
  under the night clock leaves by day unless it fights or a player is
  within 32 nodes; mobs without the clock are never touched.
- Round 35 fixtures and probes live in `tools/r35_<lane>/` (`t` the rotated
  boxes, `engine.sh` the turning-mob sweep and ray cost,
  `upstream_check.sh` the engine bug, FIXED or BUG PRESENT; `f` the break
  hook, broken look, empty hand, dig sounds, flint and quest lists, its
  approval list `approved.txt` and `engine.sh`; `m` the capital scheduler
  and either/or rule, `engine.sh` the location and ambience passes; `c` the
  creation draft and window geometry, `engine.sh` a creation through the
  real receive-fields chain; `e` the dawn rule, `engine.sh` rats across a
  dawn; `b` the level-proof talents and the picks, `numbers.py` the
  conversion, review and decided tables).

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
  a CC BY-NC sound hidden inside the ambience mod, which on a closer look
  also carries Pixabay-licensed and unmapped files).
- Asset shopping lists with verified licenses:
  [docs/research/assets/](docs/research/assets/).
- **Never copy assets or names 1:1 from existing commercial games** (their
  IP). Own assets, own names with a recognizable character ("inspired by",
  not "copied").

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
  empty is a defect. The WP40 profiler (`tools/wp40/profile/run.sh`) sets
  its own scratch user path; pass it a launcher that forwards it.
- **Seed fleet (user decision 2026-10-04: POIs stay at fixed anchors, so
  robustness across seeds comes from testing):** `tools/seed_fleet/run.sh`
  builds the portable world (`tools/r28_zone_atlas/world.lua`, the load
  path up to the R7 anchor roster) for a fixed list of seeds
  (`tools/seed_fleet/seeds.txt`: the seeds that once failed, then seeds below
  and above 2^53), 8 in parallel under idle scheduling, never with a
  wall-clock kill; it prints every failed seed with its error and exits 1.
  `quick` (100 seeds, about 4 minutes on this workstation) is required
  before merge for every lane that touches world generation (`mods/MAPGEN`,
  the anchors, water, roads, capitals, zones); `full` (about 300 seeds,
  about 13 minutes) once at the end of every round that changed world
  generation. An optional count of random extra seeds follows the size.
  The reviewer checks the run's summary line (all seeds build) and that a
  changed seed list is explained.
- Take `strict.lua` warnings (undeclared global) seriously — usually typos.
- Server log via `core.log("action"|"warning"|"error", msg)`.
