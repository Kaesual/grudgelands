# Round 81 — Fixes from the 2026-11 audit

Planned with the user on 2026-11-17. Source: the read-only audit
[docs/audit-2026-11/](../audit-2026-11/README.md) (plan:
[review-2026-11-plan.md](review-2026-11-plan.md)); its `findings/<id>.md` files are the
authority for every finding id this plan cites. Routing (user, 2026-11-17): the coordinator runs
on Opus 5.5, Opus implements and reviews; every lane with game logic gets an independent review.
Version **0.81.0**, expected **compatible**: no map reset, no migration, no new server, no change
to world generation.

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A finding is a proposal until a ruling or a lane's
  re-check confirms it; a coordinator default is marked as such.
- Name functions rather than line numbers.

## Why

The audit found no Critical defect and two small High ones, about a hundred Medium findings
(mostly per-step work that grows with the 100-player target, a handful of player-visible bugs,
duplicated guards, stale documents) and many Low ones. This round fixes what is cheap and safe
now, leaves world generation alone (its speed work is the next round, §7) and leaves the large
optional refactors (capital plot engine, mob species boilerplate) as carry-overs.

## 1. Lanes and order

Start state: main at `895feb55` (0.80.1 plus the audit folder) plus this plan. Integration branch
`round81` in `.claude/worktrees/round81`; every lane branches from it, a wave-2 lane from the
round branch after wave 1's merges, a wave-3 lane after wave 2's.

| Lane | Goal (§4) | Wave | Merge order | Review |
|---|---|---|---|---|
| SAFE | Server safety: field cuts before trims, the mail UTF-8 cleaner, ability-punch errors reported, water kept out of roads and POI cores | 1 | 1 | independent |
| HOT | Per-step and per-hit hot spots in grug_core and grug_abilities; the privilege cache; the slot helper; cooldowns survive a relog | 1 | 2 | independent |
| BUGS | Player-visible bugs: flyer set-down after `/home`, Registrar texts, silent crop growth refusal, swing clock on level-up, weapon hint | 1 | 3 | independent |
| MOBRUN | Mob runtime: line of sight, elite wind-up, whelp death grace, frozen definition fields, dragon glow, rift particles | 1 | 4 | independent |
| TOOLS | `tools/` hygiene (study captures, stale copies, `.ignore`) and the full-preparation gate in `check_upgrade.py` | 1 | 5 | independent |
| PASSES | The all-players-in-one-step passes onto join slots; identity cache (level, class, faction, race) | 2 | 6 | independent |
| SOCIAL | Tag carriers, quest markers, parties, Claim Stone pass, waystone discovery | 2 | 7 | independent |
| SPAWN | Spawning: the retired palette layer and surface rows, Elder and Silverback rolls, spawn costs, camps, Lava Seep speed | 2 | 8 | independent |
| UI | Window and inventory rebuild costs, compose cache, public furnace records | 2 | 9 | independent |
| GUARDS | One NPC-window permission check; one bound-item guard | 2 | 10 | independent |
| DEAD | Dead code, stale `mod.conf` depends, undeclared settings, stale code comments outside the mapgen | 3 | 11 | independent |
| DOCS | Documentation drift, the upgrade contract, the process rules (tags, paths), BACKLOG ids | 3 | 12 | independent, against the code |
| D | Release 0.81.0 and the round's end records | after every merge | — | coordinator |

Waves exist because lanes of different waves share files (§3.3); inside a wave the files are
disjoint apart from the named exceptions.

## 2. User rulings

From the conversation of 2026-11-17 (the user accepted every recommendation of the coordinator's
audit summary):

1. **Scope.** All lanes above in one round; world generation speed (audit lane 5) is the next
   round, the capital plot duplication (audit lane 6, W2-01..W2-05) and the species boilerplate
   (MOB3-05) are carry-overs. No file under `mods/MAPGEN` changes in this round.
2. **Relog keeps cooldowns (CMB-10; X5-02, C2-01).** Ability cooldowns, swing charges and the
   mana value survive a leave and rejoin within one server run, kept in memory by name (the
   talent windows' pattern). A server restart may reset them. Death behaviour is unchanged.
3. **Water stays out of roads and POI, village and camp cores (C1-01, M5-02).** The water guard
   refuses where the world-protection layer is set, with the barrier revert on those positions
   (not a plain air revert); planned canal and river flow, claims, towns and capitals behave as
   before.
4. **TTD band (DD2-03):** documentation only: the band and its table are stated at
   `grug_mob_damage_scale` 1.0, with the default 1.5 value beside them. No balance change.
5. **Lava Seep (DD2-01):** `run_velocity` 4.6 like every aggressive melee family.
6. **Palette spawn layer (MOB2-04, MOB3-04):** the retired palette layer and the 37 retired
   surface rows go; the Elder Bear and Silverback 1-in-10 rolls come back through the base
   definition's activation path, independent of an ABM row.
7. **Elite wind-up (MOB1-02):** a wind-up starts only against a player target; fights against
   mobs use plain swings.
8. **Public furnace items at a map reset (P2-02):** named in the upgrade contract §3.5 "Not
   packed" and in `inventory_equipment.md`; the pack pass is not extended.
9. **Leather (DD3-08):** the chain is intended; `items_crafting.md` §3.4 documents it.
10. **Retired mount items (X3-08):** replaced by `register_alias(<old>, "")` for the six names.
11. **Ability-punch errors (C1-09):** reported through `grug_core.severe.report`, after the
    flag restore.
12. **`tools/` (T1-01..T1-03):** the study captures, contact sheets, iteration renders and the
    whole `tools/capital_polish_study` leave the tracked tree (git history keeps them), with the
    exceptions the verified T1 file lists; a root `.ignore` hides what stays and only misleads
    searches.
13. **Full-preparation gate (M5-01):** `tools/check_upgrade.py` gets the proposed byte check.
14. **Round tags (DP1-01).** From now on the round tag sits on the squash commit on main; plans
    and reports no longer cite lane hashes as a lasting reference; the local tags `round-72.1` to
    `round-76.2` stay local. The process documents say so.
15. **Fixture runs** (user, 2026-11-17, restating the standing rule): LuaJIT and fixture runs only
    for what really changed, as few as possible; **one full run, at the very end**, by the
    coordinator.

## 3. Shared conventions

### 3.1 Coordinator defaults (the user may overrule)

- **Low findings.** A lane fixes the Low findings this plan lists for it; other Lows in its own
  files only when the fix is a few lines and the verified finding is CONFIRMED or CORRECTED.
  An UNVERIFIED Low is re-checked first like any other finding. Lows nobody takes stay in the
  audit folder; they are not copied into BACKLOG.
- **Performance numbers.** Every performance finding is unmeasured. A lane proves the cost change
  with call counts or a pure-Lua micro measurement inside its own fixture (before on the base,
  after on the branch, one run each), never with an engine measuring run or a 100-player run.
  The numbers are reports, not targets.
- **No behaviour change by accident.** A performance fix keeps every answer identical unless this
  plan names the change; where a cache could serve a stale answer (privileges, identity, eye
  height), the lane names the invalidation events and tests them.
- **Shared helpers live in grug_core** as small new files with their own `dofile` line (HOT: the
  privilege cache and the slot helper; SAFE: the field-cut and UTF-8 helpers). Wave 2 uses
  HOT's slot helper instead of writing the join-slot pattern again.
- **API stability across lanes.** HOT keeps the signatures of `status_modifier_sum`,
  `homing_step`, `combat_eye_pos` and `mobs.has_priv`; PASSES and SOCIAL keep the signatures of
  `grug_parties.view` and the identity accessors (`grug_core.get_player_level`,
  `grug_classes.get_class`, `grug_factions` getters). Callers in other lanes' files stay
  untouched.

### 3.2 Release

Compatible. Lane reports classify their change and list every saved key read or written; a
change that would need a migration, a map reset or a new server is reported before it is built.
D sets 0.81.0 in `game.conf` and `tools/web_data/upgrade.json`.

### 3.3 Shared files

| File or folder | Owner |
|---|---|
| `mods/PLAYER/grug_money/coins.lua`, `grug_housing/stone_form.lua`, `grug_mail/model.lua`, `grug_accounts/model.lua`, `grug_bridge/commands.lua` (cleaner only), `grug_jobs/ui.lua` and `grug_inventory/help.lua` (switch to the shared field cut), `grug_core/water_guard.lua`, `protection.lua`, `lava_guard.lua`, `combat.lua` (the ability-punch pcall only), new `grug_core` text helper | SAFE |
| `mods/CORE/grug_core/` `environment_damage.lua`, `status.lua` (modifier sum only), `combat_ray.lua`, `homing.lua`, `combat.lua` (`engage_mob` only), new privilege cache and slot helper; `mods/PLAYER/grug_abilities/` (input, init, crosshair); `mods/PLAYER/grug_map/minimap.lua`; `mods/ENTITIES/grug_projectiles/`; `mods/ENTITIES/mobs/api.lua` (`has_priv` only) | HOT |
| `grug_mounts/restore.lua`, `grug_expeditions/entry.lua`, `grug_mail/texts.lua`, `grug_core/settlement_sockets.lua` (comment), `grug_farming/init.lua`, `grug_gear/`, `grug_inventory/equipment.lua` (weapon hint) | BUGS |
| `mods/ENTITIES/grug_mobs/` runtime files (`init.lua`, `aggro.lua`, `telegraph.lua`, `bosses.lua`, `boss_dragons.lua`, `rift.lua`, `patrol.lua`, `verbs.lua`), `mods/ENTITIES/mobs/api.lua` (attack-state line of sight only), `grug_obstacle.lua` | MOBRUN |
| `tools/` study folders, `tools/README.md`, `tools/check_upgrade.py`, root `.ignore`, the archive link of T1-02 | TOOLS |
| `grug_core/status.lua` (pass), `atmosphere.lua`, `grug_abilities/init.lua` (regen pass), `grug_pvp/`, `grug_xp/`, `grug_classes/`, `grug_factions/`, `grug_inventory/pages.lua` (the 1 s pass), `grug_visuals/apply.lua`, `grug_farming` (pass), target frame, `grug_traders/potion.lua`, `grug_mobs/init.lua` (truce and faction sweep) | PASSES |
| `grug_core/tag_carrier.lua`, `grug_quests/npc.lua`, `grug_parties/`, `grug_clans/` (online list only), `grug_housing/stone.lua`, `registry.lua`, `grug_home/waypoints*.lua` | SOCIAL |
| `grug_mobs/` spawn files (`spawn_policy.lua`, `spawn_regions.lua`, `spawn_abms.lua`, `density.lua`, `camps.lua`, `start_npcs.lua`, `start_zone_families.lua`, `night_families.lua`, `subtypes.lua`, species files), `mobs/api.lua` (spawn action only), `tools/r28_b1`, `tools/r28_s1` | SPAWN |
| `grug_inventory/bags.lua`, `storage.lua`, `pages.lua` (event rebuilds only), `grug_achievements/`, `grug_jobs/basic_unlock.lua`, `workspaces.lua`, `grug_mail/window.lua`, `api.lua`, `store.lua`, `grug_visuals/compose.lua`, `grug_repair/runtime.lua`, `grug_quests/state.lua` | UI |
| NPC window checks (`grug_mounts/trainer.lua`, `grug_housing/manager.lua`, innkeeper, `grug_repair/providers.lua`, registrar, `grug_traders/crown.lua`, `grug_jobs/trainers.lua`), the new shared check, `grug_housing/soulbound.lua`, `grug_skills/bound_items.lua`, `page.lua`, a new `grug_inventory` bound-item file | GUARDS |
| Every remaining `mods/` file outside `mods/MAPGEN` for dead code and comments | DEAD |
| `docs/design/`, `docs/technical/`, `docs/process/`, `AGENTS.md` (process rules only), `VENDOR.md` counts, `BACKLOG.md` (DP1-07 ids) | DOCS |
| `CHANGELOG.md`, `game.conf`, `tools/web_data/upgrade.json`, `docs/STATUS.md`, `README.md`, this plan's Completion | D |

`VENDOR.md`: HOT, MOBRUN and SPAWN each add their `GRUG PATCH` rows; the coordinator resolves the
table at merge. `grug_core/init.lua`: each lane adds its own `dofile` lines.

## 4. Lane goals

Every lane: the verified text in `docs/audit-2026-11/findings/<package>.md` is the starting point;
re-check each finding at the base commit before building on it (round workflow §2 step 4).

### SAFE

X6-01 and X6-V1: cut every raw form field before any trim or event parse, through one shared
grug_core helper that `grug_jobs` and `grug_inventory/help.lua` then use too; accepted inputs
stay identical. P5-01: the mail cleaner drops a match whose byte count does not fit its lead
byte, through one shared byte-length rule used by mail, the bridge's `C.plain` and the accounts
cleaner (valid UTF-8 gives byte-identical output). C1-09 (ruling 11). C1-01 (ruling 3), with
C1-12 (the lava guard's duplicate wrappers) if the water change makes the duplication obvious.

### HOT

X4-01, C1-07, X4-09: a privilege cache in grug_core with the grant, revoke and leave
invalidation (`mobs.has_priv` delegates to it); environment damage asks for `noclip` only when
it needs it. X4-02, C2-02: one wielded-item read per player per pass. X4-07: the minimap update
throttled or slotted. C1-03: `status_modifier_sum` without per-call allocation and sorting.
C1-05, C1-06, E1-01: no `get_properties()` in the aim eye and the homing step (cache eye height
and collision box; refresh where the vendored player_api changes `eye_height`). C1-13. CMB-10
(ruling 2). The slot helper for wave 2 (§3.1), used here where HOT's own passes need it.

### BUGS

P4-01 (release the set-down when the player moved or died; drop `pending` on death). DD4-01
(both texts and the stale comment). I1-01 (growth refusal silent; harvest and dig keep their
messages). I2-01 (description-only weapon rewrite notifies with the narrow reason; no swing clock
restart on a level-up or a Str/Dex equip). P3-06.

### MOBRUN

X4-04 (line of sight not on every server step of every attacking mob, same answers on the
cadence a melee decision needs). MOB1-02 (ruling 7). MOB3-01 (whelps give death grace; whelp
damage enters the loot ledger as the royal guards' does). MOB1-03 (speeds restored by removing
instance fields, aggro fields on the prototype, the one-line activation cleanup for saved
NPCs). MOB3-02, MOB3-03 (rift particles through the one particle path), MOB1-06, X4-12,
MOB1-04.

### TOOLS

T1-01, T1-02, T1-03 (ruling 12) exactly as the verified T1 file's proposal and keep list say,
with every link and `--check` that a removal touches updated in the same change; T1-05 and
T1-07 (tools/README rows, the two unnamed folders); DP1-06. M5-01 (ruling 13): the byte gate in
`tools/check_upgrade.py` with the 0.57.0 CHANGELOG practice as the acknowledgement form.

### PASSES

X4-05: the per-player passes it lists (status, abilities regen, target frame, pvp sample and
page, the inventory pages pass, atmosphere, environment damage, visuals wield poll, farming)
onto join slots with HOT's helper; per-player periods unchanged. C1-02, X4-14, C2-03 (the
status list and max mana computed once per player per pass). C3-01. C3-02, C3-04 (a per-player
identity cache with its single writers as invalidation; update the four tool fixtures that write
the keys directly). MOB1-01 (the truce and faction sweeps read the cache). E1-09. P1-02, P1-03.

### SOCIAL

C1-04, X4-03 (tag carriers not carriers × players in one step, no fresh table per carrier,
no player-meta reads at eight per second). P3-05. P5-03, P5-04, P5-05. P4-02, X4-11, P4-10
(the Claim Stone pass slotted, no copy and sort of every claim every 5 s; placement overlap
through the claim grid). P4-03.

### SPAWN

MOB2-04 and MOB3-04 (ruling 6), keeping a registration that fills `mobs.spawning_mobs` where
`add_mob` needs it, the kept rows byte-identical and the spawn design documents updated.
MOB2-01 (cheap checks before the repellent scan, the scan skipped for an unregistered
repellent; `GRUG PATCH`). X4-06. MOB2-02 (the heartbeat slotted). MOB2-03. DD2-01 (ruling 5).
MOB2-05, MOB3-09. Not MOB2-09 (its output is cached and shared with the offline renderer).

### UI

P3-02, P2-01 (no Character page rebuild per shot, pickup or kill beyond what the visible page
needs; the engine fact in P2-01's verdict holds: "skip while closed" is not valid). P3-03,
P2-04 (`give` and the Basic-unlock scan without copying every list per dug node; value flows
byte-identical in outcome). P5-02. P1-01. P2-03 (empty workspace records deleted; existing ones
pruned when touched). P2-07, I2-09, P3-04 if cheap.

### GUARDS

X2-02 with X6-03 and E1-04: one helper for "may this player still use this NPC's window"; each
window keeps its role and faction source; whether the registrar and crown gain the socket check
is reported, not decided (default: they keep today's checks). X2-01 with C3-03: one bound-item
seam in grug_inventory that soulbound and skills register with; allow and deny answers
identical, including the catalog swap undo and the skills exemption; the per-render and per-join
walks go.

### DEAD

The dead-code findings outside `mods/MAPGEN`: C1-10, C1-15, C2-04, C2-05, C2-06, C2-12,
C2-13, C3-06, DD2-14, DD2-15, E1-02, E1-05, E1-06, E1-07, I1-03, I1-05, I2-06, I2-11, I2-12,
MOB1-05, P1-04, P1-06, P2-05, P2-06, P2-10, P3-07, P3-08, P4-06, P5-07, X1-03, X1-04, X1-05,
X3-02, X3-04, X3-05, X3-06, X3-08 (ruling 10), X3-09, X3-11, X5-07; stale code comments
(MOB1-08, MOB2-10, X3-12, the header parts of C1-14). Functions alive only for fixtures (X3-03)
stay. Each removal re-checked with a whole-tree search, `tools/` included.

### DOCS

The documentation findings in `docs/` (DD1, DD2, DD3, DD4, DT1, DT2, DP1, and the docs halves of
M1-02, M1-03, M3-12, M4-11, M4-12, M5-03, W1-10, X1-02, X1-06, X1-07, P1-07, P2-11, P3-11,
P3-12, P4-09, P5-08, MOB1-09, MOB3-12, I1-06, I2-10, E1-03, E1-08, C3-05, X5-01, X5-06);
rulings 4, 8, 9 and 14; DP1-02; DP1-07 (the October ids into BACKLOG, one line each); the
open questions left in design files are resolved by moving them to BACKLOG. Every rule and
number written is checked against the code at the round branch after wave 2.

### D

Release 0.81.0 and the round's three end records ([round workflow §4](../process/round-workflow.md#4-lane-d-and-the-post-merge-status-step)):
the CHANGELOG entry, this plan's Completion and Carry-overs, the STATUS row. BACKLOG in place:
CMB-10 deleted (ruling 2); carry-overs (mapgen speed round, audit lane 6, MOB3-05) as one-line
items.

## 5. Rules

[Round workflow](../process/round-workflow.md), [AGENTS.md](../../AGENTS.md), Lua 5.1. **Fixtures
(ruling 15):** a lane runs only its own fixture and the fixtures that really test the behaviour
it changes, as few times as possible; no lane and no reviewer runs the full set; the coordinator
runs it once, at the very end. One smoke boot per code lane on its final branch; no other engine
run unless the lane brief names it. No seed fleet (nothing under `mods/MAPGEN` changes). At most
eight Lua processes through the shared queue. Headless runs only through
`tools/luanti_headless.sh` with `LC_ALL=C`. No sync and no push by any lane.

## 6. Verification and human tests

**Code:** changed-file Lua check, `check_fresh_server.py`, the lanes' own fixtures and the
fixtures that test what they change, one smoke boot per lane, `validate.py --game` for SPAWN,
`check_upgrade.py` and the full fixture suite once at the round end, one smoke boot of main.

**Human-test proposal** (an offer; D refines it from the reports): log out and back in during a
Sprint cooldown (the cooldown is still running); a level-up mid-fight (no swing delay); pour
water beside a road in contested land (it stops at the road band); an Elder Bear appears now and
then among bears.

## 7. Orchestration notes

- **Start:** 2026-11-17 on the user's go. Wave 1: SAFE, HOT, BUGS, MOBRUN, TOOLS.
- **Compaction checkpoints:** (1) all wave-1 reports in and their reviews launched; (2) wave 1
  merged and wave 2 launched; (3) wave 2 merged and wave 3 launched; (4) D merged and the
  round-end gates run, before the squash.
- **Next round:** world generation speed (audit lane 5: M1-01, M2-01, M2-02, M3-02..M3-07,
  M4-01..M4-03, W1-01..W1-05 and the mapgen Lows), byte-identical output only, with the
  CHANGELOG admin note for worlds in full preparation mode; M3-01 as the one deliberate output
  change if the user wants it. The mapgen dead code (M1-04..M1-08, M3-08, M3-11, M4-13, M5-04..)
  goes with it.
- **Handover:** `~/projects/grudgelands-orchestration/r81/HANDOVER.md`.
