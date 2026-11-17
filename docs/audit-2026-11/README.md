# Audit 2026-11: code and documentation review

A read-only review of the code the game server runs, made on 2026-11-17 at
commit `4cb49044e` (0.80.1). Nothing in the game was changed. Every finding
is a proposal until the user rules on it. Plan:
[review-2026-11-plan.md](../planning/review-2026-11-plan.md).

**Result in one paragraph.** 35 packages, 387 findings after verification: 0 Critical, 2 High, 96 Medium, 289 Low. The verifiers confirmed 267, corrected 47 (place, severity or proposal) and refuted 1; 73 Low findings were left unverified by design. No finding is
Critical. Two are High and both are small fixes: a privilege lookup that
runs for every player on every server step, and a form field any player can
use to stall the server. The rest is about 100 Medium findings, mostly
avoidable per-tick and per-chunk work, duplicated code in the capital
generator, a handful of real bugs players can hit, and documents that fell
behind the code. Persistence, the upgrade machinery, the value flows
(trade, mail, quests, inventory) and the two hosting-platform contracts came
out clean.

## How to read this folder

| Path | Content |
|---|---|
| [by-topic/all.md](by-topic/all.md) | Every finding in one table, most severe first |
| [by-topic/](by-topic/) | One table per topic: [performance](by-topic/performance.md), [duplication](by-topic/duplication.md), [dead code and simplification](by-topic/dead-code-and-simplification.md), [bugs and edge cases](by-topic/bugs-and-edge-cases.md), [persistence and upgrade](by-topic/persistence-and-upgrade.md), [security and exploits](by-topic/security-and-exploits.md), [determinism](by-topic/determinism.md), [documentation drift](by-topic/docs-drift.md) |
| [by-topic/coverage.md](by-topic/coverage.md) | Counts and verdicts per package |
| `findings/<id>.md` | **The authority:** the verified findings of one package, each with place, evidence, proposal, effort, risk, upgrade class and the verifier's verdict |
| `raw/<id>.md` | The finder's output before verification (audit trail; do not act on it) |
| `packages/` | The package cut (`make_packages.py`, file lists) and the `tools/` inventory table |
| `build_index.py` | Rebuilds `by-topic/` after a findings file is edited: `python3 build_index.py` |

A finding id is stable (`X4-01`); cite it in plans and commits. Verdicts:
**CONFIRMED** (holds as written), **CORRECTED** (a real problem, but the
verifier rewrote place, severity or proposal: read the verified text),
**REFUTED** (left out of the tables, kept at the end of its file),
**UNVERIFIED** (not checked: by design almost only Low findings).

## Method and limits

- **Find, then verify.** One finder per package read its files and wrote
  findings with file:line evidence. A second agent in a fresh context then
  tried to refute each Critical, High and Medium finding at the cited place.
  The coordinator re-read the code of the High findings itself.
- **Static only.** No LuaJIT, engine, fixture or benchmark ran. Every
  performance finding is **unmeasured**; its `Measure` line names the
  before/after measurement to run on a larger machine. The ranking below is
  by call frequency and what the engine source says a call costs, not by a
  profile.
- **Engine claims** were checked in `reference_projects/luanti` (5.18.0) by
  the verifiers. The submodule was not checked out when the first finders
  ran, so a raw file may say "engine behaviour not checked" where the
  verified file settles it.
- **Not looked at:** the content of `tools/` (inventory only), vendored code
  outside its `GRUG PATCH` sites, art and sound files, and what each
  package file lists under "not reached" or "skimmed".

## The two High findings

| Id | What | Fix |
|---|---|---|
| [X6-01](findings/X6.md) | The Withdraw coins dialog (`grug_money/coins.lua:66`) and the Claim Stone's player-name field (`grug_housing/stone_form.lua:650`) call `:trim()` on the raw form field. The engine's trim pattern is quadratic on a long run of spaces followed by a character, and the engine accepts 640 KiB of fields per submit. Any player can stall the server for seconds, repeatedly. [X6-V1](findings/X6.md) is the same cost in the Claim Stone's player list (claim owners only). | Cut the field to a sane length before trimming, as `grug_jobs/ui.lua` and `grug_inventory/help.lua` already do. Small. |
| [X4-01](findings/X4.md) | The contextual-input pass (`grug_abilities/input.lua:69`, reached at `:588`) calls `core.check_player_privs` for every living player on every server step. The engine has no privilege cache: each call goes through the auth handler to the auth database. [C1-07](findings/C1.md) (environment damage) and the crosshair do the same less often. | Cache the `interact` answer per player and refresh it on grant, revoke and join; `mobs.has_priv` already caches for mobs. Small. |

## Rulings the user has to make

These findings are confirmed in the code, but whether the behaviour is wanted
is a design decision, so no fix is proposed without a ruling.

| Id | Question |
|---|---|
| [X5-02](findings/X5.md), [C2-01](findings/C2.md) | A relog clears every ability cooldown and swing charge and refills mana (Sprint's 300 s and the 60 s abilities come back at once). Intended, or should cooldowns be saved as absolute times, as the PvP flag timers already are? BACKLOG has this as the open question CMB-10. |
| [C1-01](findings/C1.md), [M5-02](findings/M5.md) | The terrain-damage guard does not know the road, village, camp and POI-core layer. Today only water gets through: a bucket poured just outside such a core floods it for good. Towns and capitals are safe. Two code comments disagree on whether that layer is meant for player digging and placing only. |
| [DD2-03](findings/DD2.md) | The mandatory 25–30 s time-to-die band in combat_stats.md holds only at `grug_mob_damage_scale` 1.0; the default is 1.5, which gives about 18 s. Change the default, the band, or say which scale the band assumes? |
| [DD2-01](findings/DD2.md) | The Lava Seep is an aggressive melee mob at run speed 3.4, under the decided minimum of 4.6. Speed it up or list it as an exception? |
| [M5-01](findings/M5.md) | Worlds made with `grug_prepare_full_world` stop for good when any byte of 27 mapgen files changes. That is the decided rule, and no release so far broke one without a map reset or a CHANGELOG note, but no gate checks it. Add the proposed check to `tools/check_upgrade.py`? |
| [MOB2-04](findings/MOB2.md), [MOB3-04](findings/MOB3.md) | Every zone now has a spawn recipe, so the palette spawn layer and 37 surface spawn rows never run, and with them the 1-in-10 Elder Bear and Silverback rolls that biomes_mobs.md still describes. Remove the layer (it is documented as deliberately kept) and the rolls from the design, or bring the rolls back? |
| [P2-02](findings/P2.md) | Items left in the public furnaces' personal workspaces are not packed by the pre-reset pass and are lost at a map reset. Extend the pass or name the loss in the upgrade contract? |
| [DD3-08](findings/DD3.md) | The leather grades form a chain (hide → Cured → Heavy → Scaled, one Thread each) that items_crafting.md does not describe, while alloys and wood grades are flat. Intended? |
| [T1-01](findings/T1.md), [T1-02](findings/T1.md) | About 240 MB of study captures under `tools/` have no gate or shipped file depending on them; some are still read by their own study scripts or named by planning documents and one archive link. Keep as evidence, move out of git, or delete (the verified T1 file lists what each removal would break)? |

## Proposed lanes

Grouped so that each lane touches one area and can be reviewed on its own.
Effort is the sum of the findings' own estimates; "compatible" means no
saved state or generation output changes.

### 1. Server safety and the per-step hot spots (small, do first)

- [X6-01](findings/X6.md), [X6-V1](findings/X6.md): cut form fields before
  trimming. [P5-01](findings/P5.md): the mail text cleaner counts a
  malformed UTF-8 run as one character, so a modified client stores 40 KB
  against the 4,000-character limit; `grug_accounts` already has the correct
  cleaner.
- [X4-01](findings/X4.md), [C1-07](findings/C1.md): the privilege cache.
- [X4-02](findings/X4.md), [C2-02](findings/C2.md): one wielded-item read
  per player per step instead of about 50 copies a second from five pollers.
- [X4-07](findings/X4.md): the minimap update runs for every player on
  every step.
- [C1-05](findings/C1.md), [C1-06](findings/C1.md),
  [E1-01](findings/E1.md): `get_properties()` builds a table of about 55
  fields on each call and sits in the aim ray, the homing step and the
  environment tick; cache the eye height and collision box (the vendored
  player_api writes `eye_height` on animation changes, so hook that).
- [C1-09](findings/C1.md): a Lua error inside an ability punch is caught and
  logged as a warning; it should go through `grug_core.severe.report`.

### 2. The all-players-in-one-step passes (medium)

AGENTS.md says no pass handles every player or zone in one step. The tick
inventory in [X4](findings/X4.md) lists 20 sites that do, and about ten of
them fire on the same step once a second ([X4-05](findings/X4.md)).

- Status and regeneration: [C1-02](findings/C1.md),
  [C2-03](findings/C2.md) (the status list is built three times per player,
  max mana up to three times).
- [C1-03](findings/C1.md): `status_modifier_sum` allocates and sorts on
  every crit, armour and spell-damage read.
- Nametag carriers: [C1-04](findings/C1.md), [X4-03](findings/X4.md)
  (carriers × players each second).
- [C3-01](findings/C3.md) PvP location, [P4-03](findings/P4.md) waystone
  discovery, [P4-02](findings/P4.md) Claim Stone check,
  [MOB2-02](findings/MOB2.md) settlement NPC heartbeat,
  [P5-03](findings/P5.md) party view.
- [C3-02](findings/C3.md): level, class, faction and race are read from
  player meta on every call; each meta read looks the player up by name
  against every connected player, so it costs more as the server fills.
  Each value has one writer, so a per-player cache is safe (four tool
  fixtures write the keys directly and need an update).

### 3. Mobs (medium)

- Per step: [MOB1-01](findings/MOB1.md) (truce and faction checks read
  player meta on every step of every attacking mob),
  [X4-04](findings/X4.md) (a line-of-sight ray per attacking mob per step).
- Spawning: [MOB2-01](findings/MOB2.md) (every ABM spawn attempt scans
  35,937 nodes for a repellent node the game never registers; a
  `GRUG PATCH` in the vendored spawn action), [X4-06](findings/X4.md).
- Bugs: [MOB1-02](findings/MOB1.md) (an elite's wind-up roots it for 2 s
  against a mob target, but the cone only hits players: elite guards lose
  about a fifth of their damage against monsters),
  [MOB3-01](findings/MOB3.md) (a kill by a dragon whelp gives no death
  grace and whelp hits never enter the loot ledger),
  [MOB2-03](findings/MOB2.md) (region camps overfill).
- [MOB1-03](findings/MOB1.md): definition values are written onto the mob
  and saved with it, so guards and other NPCs that never despawn keep old
  values after a retune.
- [MOB3-05](findings/MOB3.md): the 51 species files are about a quarter
  default-valued boilerplate; a family helper would remove about 1,000
  lines. Large, optional.

### 4. Player-visible bugs and UI cost (small to medium)

- [P4-01](findings/P4.md): after a login with a refused flying-mount
  restore, `/home` (or a death and respawn) is undone a second later: the
  player is set down at the logout place and the 30-minute cooldown is
  spent.
- [DD4-01](findings/DD4.md): two texts players read still send them to the
  Registrar at the "waystone plaza"; it stands at the great hall door since
  0.75.3.
- [I1-01](findings/I1.md): a crop whose planter lost the right to its cell
  never grows, and each retry every 15 s flashes "protected" to the planter
  wherever they are.
- [I2-01](findings/I2.md): a level-up or equipping a Strength or Dexterity
  item restarts the melee swing timer; the tooltip refresh behind it re-runs
  the equipment chain.
- Character page rebuilds: [P3-02](findings/P3.md) (every Scout shot),
  [P2-01](findings/P2.md) (every kill); [P3-03](findings/P3.md) and
  [P2-04](findings/P2.md) (work after every dug node);
  [P5-02](findings/P5.md) (one mailbox click decodes the mailbox five
  times).
- [P1-01](findings/P1.md): the look-compose cache is never trimmed.

### 5. World generation speed (medium; mind the upgrade class)

All claims here are "output stays byte-identical"; the verifiers checked
each by reading the maths and corrected three proposals that would have
changed output. **Upgrade note:** 27 mapgen files are in the
full-preparation digest (list in [M5](findings/M5.md), "Good to know"). A
byte change to one of them is compatible for normal worlds, but stops a
world made with `grug_prepare_full_world` until a map reset. Each finding
says whether it touches a digested file.

- Per chunk, undigested files: [M4-01](findings/M4.md) (a palette, closures
  and a ledger for all 144 settlements on every chunk transaction),
  [M4-02](findings/M4.md), [M3-02](findings/M3.md) to
  [M3-07](findings/M3.md) (about five full passes over the emerged volume
  that carry no information, repeated surface selection, discarded planner
  answers).
- Per column, digested files: [M1-01](findings/M1.md),
  [M2-01](findings/M2.md), [M2-02](findings/M2.md).
- At boot: [W1-01](findings/W1.md) (four capitals parse their templates
  five times per Lua state, ten times per server process),
  [M4-03](findings/M4.md) (every blueprint is rebuilt although the layout
  cache hit), [W1-02](findings/W1.md) to [W1-05](findings/W1.md).
- [M3-01](findings/M3.md) (determinism): the surface-skin opening reads
  shell blocks whose content depends on whether the neighbour chunk exists,
  so border columns depend on emerge order. Fixing it changes new chunks
  only.

### 6. Capital generator duplication (large, optional)

- [W2-01](findings/W2.md), [X2-05](findings/X2.md): the six capital plot
  modules are one engine copied six times (78–95 % identical, about 1,250
  redundant lines); [W2-04](findings/W2.md): the composition skeleton
  repeats in 18 files.
- The copies have already drifted: [W2-02](findings/W2.md) (Kezamba sets a
  garden flag its builder never reads), [W2-03](findings/W2.md) (six
  versions of the prop guard; Hearthpine drops props silently).
- None of these files is in the preparation digest, so an output-identical
  refactor is compatible and costs one rebuild of the cached layouts.

### 7. Duplicated guards and helpers across mods (medium)

- [X2-02](findings/X2.md): "may this player still use this NPC's window"
  is written six times with different checks; the jobs trainer checks
  distance only ([X6-03](findings/X6.md)).
- [X2-01](findings/X2.md), [C3-03](findings/C3.md): two bound-item guards
  with different coverage; a detached inventory opened later accepts a
  skill or mount item.
- [X2-03](findings/X2.md) (clans copy the parties' invitation code),
  [X2-04](findings/X2.md) (the player's item lists rebuilt in six places),
  [I1-02](findings/I1.md) (tool values in four places, three of them
  overwritten at load), [I2-02](findings/I2.md) (the gear tooltip built in
  three layers).
- Not every builtin is a drop-in replacement
  ([X2-13](findings/X2.md), corrected): `math.round`, `table.copy` and
  `core.hash_node_position` differ from several of the local helpers.

### 8. Dead code (small to medium, low risk)

- [X3-01](findings/X3.md), [M3-08](findings/M3.md): the evidence, capture
  and replay construction modes (about 900 lines in `r6_settlement.lua`
  alone) have no caller in `mods/` or `tools/`.
- [X3-02](findings/X3.md): 12 public functions dead everywhere;
  [X3-03](findings/X3.md): 29 alive only for tools;
  [X3-06](findings/X3.md): 37 unused constants. The verifier checked every
  entry.
- [M1](findings/M1.md) Low findings: about 550 of 887 lines of
  `index128.lua` and most of `deterministic.lua` have no caller.
- [MOB2-04](findings/MOB2.md), [MOB3-04](findings/MOB3.md): the retired
  spawn layer (see the rulings above); [C2-04](findings/C2.md): the target
  memory nothing reads.
- [X3-08](findings/X3.md): the retired mount items must not simply be
  unregistered, since station grids may still hold them; alias them to an
  empty stack.
- The load graph reaches 627 of 628 of the game's own Lua files; there are
  no `minetest.` leftovers and no commented-out code.

### 9. Documentation (small, one docs lane)

In every confirmed documentation finding the document is the stale side.
The large tables match the code: all 109 talent nodes, the 180-cell XP
table, 38 zones with levels and biome weights, about 1,100 item and price
values, the two hosting-platform contracts.

- Stale rules: [DD3-01](findings/DD3.md) (who crafts base gear),
  [DD2-02](findings/DD2.md) (Charge stun 1.5 s, really 0.75 s),
  [M1-02](findings/M1.md), [M1-03](findings/M1.md) and
  [DT1-01](findings/DT1.md) (the removed difficulty seam),
  [DD1-01](findings/DD1.md) to [DD1-03](findings/DD1.md) (fixed anchors,
  gems below −1000, a crystal density).
- Open questions left in design files, which AGENTS.md forbids: scout.md,
  world.md, story.md, items_crafting.md (see DD1, DD2, DD3).
- The upgrade contract: [X5-01](findings/X5.md) (two player-bound item
  stores missing from the removed-item list), [X5-06](findings/X5.md) and
  [DT2-01](findings/DT2.md) (tables and history behind).
- Process: [DP1-01](findings/DP1.md) (the round tags 72.1–76.2 exist only
  on the workstation, and the pushed tags 79 to 80.1 sit on the squash
  commits rather than the round branch tips, so most lane hashes the Round
  73–80 plans cite do not resolve from a clone), [DP1-02](findings/DP1.md) (rules hard-code the
  workstation's paths and the private queue).
- [DP1](findings/DP1.md) "Good to know" holds the table of October-audit
  findings that are still open.
- [E1-03](findings/E1.md): VENDOR.md gives four different totals for the
  mobs_redo patch markers; the real count is 191.

### 10. Repository hygiene (`tools/`, a decision more than a lane)

`tools/` is 690 MB, 82 % of the tracked bytes. See [T1](findings/T1.md) and
`packages/T1-tools-status.tsv` (one row per folder). Stale copies of shipped
templates and of two wp13 runtime files under `tools/capital_polish_study`
answer every search beside the real files ([T1-03](findings/T1.md)); a
`.ignore` file would hide them without deleting anything.

## What came out clean

- **Value flows.** No duplication or loss path in trade, buy-back, repair,
  mail attachments, quest turn-in, the inventory moves or money; the allow
  callbacks keep the OR-combine contract; prices are recomputed on the
  server at every click.
- **Persistence.** World version, migrations and map reset match the upgrade
  contract at every point checked; the shutdown save order the game relies
  on is what the engine does; unknown ids in saved state are dropped.
- **Lifecycle.** No stranded player or leaked instance in Expeditions
  (end, expel, logout, restart, death, slot reuse); boss resets and loot
  credit hold; ObjectRefs are re-validated after `core.after`.
- **Determinism.** Apart from M3-01, the generator has no `x ^ 2`, no
  unseeded randomness and no unsorted `pairs` in output.
- **Rules.** The `do_punch` contract, `self.temp`, the terrain-damage guard
  with its two exceptions, the particle budgets (one exception:
  [MOB3-03](findings/MOB3.md), Low), no load-order luck between mods, one
  global per mod.

## Engine facts the verifiers established

Worth keeping, because several findings rest on them (file:line in the
verified files):

- `core.check_player_privs` and `get_player_privs` are not cached by the
  engine; each call reaches the auth database (C2-02, X4-01, C1-07).
- `ObjectRef:get_properties()` builds a fresh table of about 55 fields and 8
  nested tables per call (E1-01).
- Every player-meta read looks the player up by name against all connected
  players (C3-02).
- `string:trim()` is quadratic on some inputs, and a formspec submit may
  carry 640 KiB; `core.explode_textlist_event` and
  `explode_scrollbar_event` trim too (X6-01, X6-V1, X2-06).
- The inventory formspec is only sent when its text changed, and the client
  opens the inventory from its stored copy, so "skip the refresh while the
  window is closed" is not a valid optimisation (P2-01).
- `find_nodes_in_area` with an unregistered node name still walks the whole
  box (MOB2-01).
- A mapgen VoxelManip's shell blocks are `CONTENT_IGNORE` until the
  neighbour chunk is generated (M3-01).

## Run record

- **When:** 2026-11-17, 01:53 to 02:40 CET, on a 4-core, 16 GB machine; the
  user's deadline was 06:45. Base commit `4cb49044e` (main, 0.80.1).
- **Agents:** 35 finders (31 Opus, 4 Fable: C1, X5, M3, M4) and 16 verifiers
  (Opus, two or three packages each), 51 runs, at most 20 at once. The
  coordinator (Fable) re-read the code of both High findings.
- **Coverage:** all 35 planned packages were found and verified; see
  [by-topic/coverage.md](by-topic/coverage.md). No package was cut.
- **Runs:** no LuaJIT, engine, fixture or benchmark run. The engine
  reference submodule `reference_projects/luanti` was checked out at its
  pinned commit during the run (`git submodule update --init --depth 1`, in
  the main checkout).
- **Open ends:** 73 Low findings are unverified. The gaps each finder names
  under "not reached" or "skimmed" were not revisited: mainly generated data
  files, the per-seed checks in `zone_mobs.md`, the UI half of
  `inventory_equipment.md`, parts of `settlements.md` and `story.md`, the
  bespoke actors' per-step ticks, and 32 of 46 texture families whose names
  are built from a prefix.
- **Branch:** `audit-2026-11` (local, not pushed), worktree
  `.claude/worktrees/audit-2026-11`. The commits carry the user's name as
  author because this machine has no git identity configured.
