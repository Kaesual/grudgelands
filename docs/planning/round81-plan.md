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
16. **Quiver total** (user, 2026-11-17, UI's question): the open Character page's quiver total
    may lag by up to 1 s during steady fire; the first and the last change of a burst show at
    once.
17. **Elder Bear and Silverback** (user, 2026-11-17, SPAWN's question): the rolls stay as built,
    restored in the base definitions but dormant, because every ambient bear and ape is an
    authored-tier sub-type; letting normal-tier sub-types roll is a later follow-up. The item
    leaves the human test.
18. **Registrar socket check** (user, 2026-11-17, GUARDS' question): the Expedition Registrar's
    window gets the same socket check as the other NPC windows (the NPC within 2 nodes of its
    socket).

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
then among bears. Refined in the [Completion](#human-test-proposal) (the Elder Bear item is
dropped, ruling 17).

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

## Completion (2026-11-17)

All twelve planned lanes and two unplanned fixture-only lanes (FLAKY; FIX after the full run, below) and one unplanned fix lane (WP, after the user's in-game test, below) are merged into `round81`, wave by
wave (inside wave 1 as the reviews finished); this lane D runs on it. Nothing is on main and nothing is pushed: `round81` lands on
main as one squash commit (0.81.0), tagged `round-81` on that commit (ruling 14), after the
round-end gates. Every lane had an independent review; SAFE, HOT, PASSES, SOCIAL and GUARDS had
a fix round with a delta review (all MERGE); UI's, SPAWN's and DOCS' fixes touched no game logic
and were checked by the coordinator. The lanes' reports and reviews are in the coordinator's
orchestration folder (`r81/reports/`); per the round workflow §2 this record names lanes and
finding ids, not lane commits.

Round-end gates (coordinator, §6): the one full fixture run on the code-final round branch,
364 of 369 passed; the 5 failures were fixtures that this round's changes outdated (two stubs
without the slot helper, one without the text helper, the rift mote's move, the swamp mobs'
retired spawn rows), fixed fixture-side in a small FIX lane and passing on re-run; no game code
changed. After D's merge: `check_upgrade.py` PASS (0.81.0 against `origin/main`, the
full-preparation files unchanged), `check_fresh_server.py` PASS, the fixtures that read D's
files (r37_dc, r41_up, r43_gs) PASS, and a 150 s smoke boot of the merged head PASS.

The user's in-game test of the synced round branch then crashed the server: SOCIAL's per-faction
waystone network cache (P4-03) took a nil key for a player without a faction (before character
creation), from the minimap's update every second; the smoke boot has no player and the fixture
faked the faction as an empty string. A small WP lane returns an empty network for such a player,
as before the cache, with a fixture case that fails without the fix (r29_w); its delta review
(MERGE) found no other per-player path in this round that raises for a player on the
character-creation screen.

**0.81.0 is compatible:** no step, no map reset, no new world, and no file under `mods/MAPGEN`
changed (the new full-preparation gate in `check_upgrade.py` finds the 27 preparation files as
at `origin/main`). Every lane report says compatible and every review agrees. No saved key is
added; what changes in saved state:

- mob staticdata no longer copies definition values (speeds, aggro fields); copies equal to the
  definition are dropped at activation, a differing copy is kept (MOBRUN, MOB1-03);
- empty per-player workspace records are deleted when a station opens (UI, P2-03);
- the achievement counters `boss:dragon` and `boss:king:<race>` are no longer written; old
  values stay unread (DEAD, P2-10);
- camp fires no longer write `_grug_camp_type`; an older fire's timer fires once and stops
  (SPAWN, MOB2-05);
- the six retired mount items are aliased to nothing, so a stack in a station grid clears when
  it loads (DEAD, ruling 10).

Ability cooldowns, charges and mana kept over a relog (ruling 2) and every new cache live in
memory only.

### Lanes

| Lane | Wave | What | Review |
|---|---|---|---|
| SAFE | 1 | `grug_core.text` (field cut, UTF-8 rule) for coins, Claim Stone form, jobs and help windows, mail, accounts and the bridge; ability-punch errors through `severe.report`; the water guard on roads and cores (ruling 3) | MERGE AFTER FIXES (a drain on a road looped; the severe key); fix round; delta MERGE |
| HOT | 1 | `grug_core.has_priv` cache, `register_player_pass` join slots, `player_body` eye and box cache, one wield read per pass, minimap throttle, `status_modifier_sum` without sorting, `engage_mob` early return, ruling 2 | MERGE AFTER FIXES (the slot helper stretched periods under 0.72 s; the departed-player table); fix round; delta MERGE |
| BUGS | 1 | P4-01, DD4-01, I1-01, I2-01, P3-06 | MERGE |
| MOBRUN | 1 | X4-04, MOB1-02 (ruling 7), MOB3-01, MOB1-03/04, MOB3-02/03, MOB1-06, X4-12 | MERGE |
| TOOLS | 1 | T1-01..T1-03 (ruling 12), T1-05, T1-07, DP1-06, the M5-01 gate (ruling 13) | MERGE |
| PASSES | 2 | Nine per-player passes on the join slots, the identity cache, C1-02, X4-14, C2-03, C3-01, MOB1-01, E1-09, P1-02, P1-03, HOT's C1-03 and part of C2-02 | MERGE AFTER FIXES (two fixtures, environment damage double ticks, the wield poll); fix round; delta MERGE |
| SOCIAL | 2 | C1-04, X4-03, P3-05, P5-03, P5-04, part of P5-05, P4-02, X4-11, P4-10, P4-03 | MERGE AFTER FIXES (the claim probe's expiry); fix round; delta MERGE |
| SPAWN | 2 | MOB2-04 and MOB3-04 (ruling 6), MOB2-01, X4-06, MOB2-02, MOB2-03, MOB2-05, MOB3-09, DD2-01 (ruling 5) | MERGE (the dormant rolls went to the user, ruling 17); comment, docs and tools fix |
| UI | 2 | P3-02, P2-01, P3-03, P2-04, P5-02, P1-01, P2-03, part of P2-07, I2-09, part of P3-04 | MERGE AFTER FIXES (two fixtures read the removed cache); fixture fix |
| GUARDS | 2 | `grug_core.npc_window_permitted` for six NPC windows (the Crownbinder keeps its own check), the `grug_inventory` bound-item seam (X2-02, X6-03, E1-04, X2-01, C3-03), the registrar socket check (ruling 18) | MERGE (one Low); fix round; delta MERGE |
| FLAKY | 2½ | `r81_social`'s steady-scene allocation check made exact (LuaJIT stack regrowth after a full collect) | coordinator (fixture only) |
| DEAD | 3 | The dead-code ids of §4, stale `mod.conf` depends, `settingtypes.txt` declarations, about 110 `api.lua` line citations named by function | MERGE |
| DOCS | 3 | DD1–DD4, DT1, DT2, DP1 (02, 05, 07, 09–11), the docs halves of §4, rulings 4, 8, 9 and 14, the October ids into BACKLOG | MERGE AFTER FIXES (two Low text fixes, by the coordinator) |
| D | after | Release 0.81.0, CHANGELOG (with DP1-08), this Completion, STATUS row, README (DP1-03), BACKLOG | coordinator |

### What shipped, with numbers

Every number is a fixture count on the fixtures' fake engines, one run on the base and one on
the branch; they are comparisons, not targets. Nine new fixtures (`r81_safe`, `r81_hot`,
`r81_bugs`, `r81_mobrun`, `r81_passes`, `r81_social`, `r81_spawn`, `r81_ui`, `r81_guards`)
bring the portable set to 369.

- **SAFE:** the old trim on an 8 KiB blank run took 82 ms (quadratic; a 640 KiB field would take
  minutes); the cut and clean on 640 KiB take 0.001 and 0.006 ms. Valid UTF-8 gives
  byte-identical output in mail, accounts and the bridge. On the world-protection layer only a
  flood is set back (to the barrier); drains and level changes stand, so water left there
  before can leave (fix round). Arrival-cube guard calls per refused flow 2 → 1.
- **HOT** (100 players): input pass wield copies per second 3900 → 1100, privilege lookups
  1100 → 100; environment damage over 10 s `get_properties` 900 → 145, privilege lookups
  900 → 10 (the same 5 players hurt); `combat_eye_pos` 670 → 1 property reads; homing 44 → 1;
  `status_modifier_sum` × 100k sorts 100000 → 25000, 16420 → 2158 KB allocated, the same sum
  to the last bit; `engage_mob` on an engaged mob 6000 → 0 engine reads. The slot helper serves
  up to two slots a step, so a pass keeps its period exactly while the period is at least four
  server steps (0.36 s at 0.09 s steps).
- **BUGS:** a level-up runs one narrow pass and one inventory walk instead of one full pass and
  two walks, a Str/Dex equip one full and one narrow pass instead of two full; the swing clock is
  kept in both. `r81_bugs` fails exactly its 29 bug checks on the base.
- **MOBRUN:** sight rays in 110 attack steps 110 → 37 (a ground-melee strike still casts its
  own ray); ambusher and aura over 10 s with 100 players none near 20 player lists and 2000
  `get_pos` → 0; ten `unwatched` calls 10 object queries → 0. The rift's four effects go
  through the particle catalogue (about 50 motes alive per viewer, as before).
- **TOOLS:** 1,102 files and 269,721,906 bytes left the tracked tree (`tools/` 690 → 420 MB);
  the M5-01 gate replays the real 0.56.1 → 0.57.0 history correctly (fails at the bump, passes
  with the CHANGELOG note).
- **PASSES** (100 players): the most status rows handled in one step 100 → 26, environment
  damage 100 → 13, regeneration 100 → 26; max mana computed per visit 3 → 1; identity meta reads
  45,000 → 500; nametag property reads over 2,000 HP changes 2,000 → 0. Environment damage rounds
  each visit's elapsed time to whole ticks (fix round), exact at steady steps up to 0.25 s.
- **SOCIAL:** tags with 100 players and 1,600 carriers: faction reads per second 900 → 100,
  allocation 198.8 → 0 KB/s; party HUD (100 players, 10 parties) `get_properties` per second
  2000 → 200, meta reads 400 → 0; one level-up 100 → 10 change callbacks; 1,000 claims, most
  `get_node` in one step 2000 → 250; waystones 1 → 0 meta decodes per player-second.
- **SPAWN:** 56 retired surface rows removed (89 → 33 registered); the merged spawn table is
  byte-identical (33 rows: surface 20/248, underground 20/135, water 30/1629). A day row at night
  runs 0 policy, count and repellent checks (was 1/1/0); 600 objects, mobs first: 600 → 12
  `get_luaentity` calls (mobs last: 600 → 581); heartbeat with 60 rows, most served in one step
  60 → 3.
- **UI:** stacks copied per dug stone (miner, 4 bags) 112.0 → 32.8; a Scout's 20 s of fire,
  Character page re-sends 66 → 21; 100 dug held stones, scans 100 → 5 and held-string reads
  100 → 0; 30 boar kills with other counters shown, tab re-sends 58 → 0; an unread-letter click
  8 → 3 decodes; the compose cache stays at most 4,096 entries. The give and Basic-unlock case
  tables (1,500 and 480 cases) give the same digests on base and branch.
- **GUARDS:** a scratch matrix of 408,430 NPC-window cases gives 0 differences against the base;
  4,890 bound-item cases differ only where intended (a detached inventory made after the last
  walk now refuses skills and mount items; stations refuse soulbound items). Per join 1,327 node
  visits → 0; two wrapper layers per node callback → one.
- **DEAD:** load order simulated over 67 mods identical before and after; eight textures (six
  UI icons, two anthracite torch strips), the mobs fork's `settingtypes.txt` and about 60
  exports removed; `mobs/api.lua` keeps its 156 `GRUG PATCH` markers.
- **DOCS:** 51 files; about 60 rules and numbers spot-checked against the code by the review;
  the link check found no new broken link (183 before and after).
- **FLAKY:** the allocation check failed 26 of 200 idle runs before and 0 of 300 after.

### The user's decisions during the round

Rulings 16–18 (§2), all 2026-11-17: the quiver total may lag by up to 1 s; the Elder Bear and
Silverback rolls stay dormant; the registrar gets the socket check. The coordinator also kept
`tools/r70_art/previews` and `tools/r49_nav/evidence` (TOOLS' question) and accepted the files
outside the lists that the reports name (MOBRUN's particle catalogue and `rift_core.lua`, HOT's
line in `grug_mounts/entity.lua`, PASSES' `scale_player_damage`).

### Deviations

- **SAFE:** C1-12 (one guard file for water and lava) is left; only the double alteration-guard
  call is gone. The layer reverts floods only, not drains, after the review found a restore
  loop for water left on a road before 0.81.0.
- **HOT:** C2-02's second `is_unlocked` evaluation stays (now a cache read); `/auth_reload` is
  wrapped so it drops cached privileges; one line outside the list in `grug_mounts/entity.lua`.
- **BUGS:** the weapon hint also checks the level, beyond the proposal (the design comment's
  rule).
- **MOBRUN:** the rift crack plays one public 1 s spawner per stretch every second (about five
  times the packets of the old private 5 s spawners for a near player, about 100 bytes each);
  every 2 s is the user's look call (Carry-overs).
- **PASSES:** farming stays as it was (it already serves its players round-robin); MOB1-01 is
  met by the identity cache, not a 1 Hz move; C3-04's leave part and C1-02's window-information
  gate are left.
- **SOCIAL:** the minimap still builds the party view (P5-03's rest) and the roster rows keep
  their invitation reads (P5-05's rest); a faction change shows on nametags within about 2 s
  (was about 1 s).
- **SPAWN:** 56 surface rows were retired, not the 37 of MOB3-04 (9 start-zone, 7 night and 3
  zero-asset rows besides); X4-06 is an exact early exit, not a spatial index; the camp-fire LBM
  stays for the infotext. Ruling 6's rolls are built but no mob reaches them (ruling 17).
- **UI:** P2-04 uses a new `grug_inventory.register_on_give` seam instead of the drop-table
  test; items that arrive without `give` (`/give`, mobs' `add_item`) wait for the 10 s sweep as
  before. P2-07 and P3-04 are partial.
- **GUARDS:** stations now refuse soulbound items (beyond the findings, matching the documented
  rule); the Crownbinder keeps its own check (it holds no entity).
- **DEAD:** kept as live with evidence: the fixture-only seams (X3-03: move immunity,
  `get_target`, `clear_cooldown`, `test_vault`), the cooldown glyph source, `I1-03 (c)` (MAPGEN
  reads it), I1-05; `grug_gear → default` and `grug_mounts → grug_jobs` stay, `grug_housing`
  gains no depends (it would flip the load order the soulbound rule uses).
- **DOCS:** DD3-09 (generated tables) and DT2-04's measurement are left; PLY-07 and PLY-09 got
  no BACKLOG line because GUARDS delivered them.
- **FLAKY** was not planned: the targeted overlap run after wave 2 found `r81_social` failing
  about one run in eight.

### Human-test proposal

An offer; nothing waits on it.

1. Log out and back in while Sprint is on cooldown: the cooldown still runs on the hotbar and
   the mana bar is unchanged.
2. Level up in the middle of a fight: the next swing comes without an extra delay.
3. Pour water beside a road in contested land: it stops at the road's edge, and no block keeps
   flickering.
4. Optional: open the Expedition Registrar once in a capital (ruling 18's socket check).

### Open notes

- **DP1-04** (ROADMAP's version-numbered accounts line) is a judgement, not a factual error;
  left for the coordinator (D's report has a proposed wording).
- **The r25 claim engine probe** fails 13 of 42 checks plus 1 of 4 on its second boot, all from
  Round 26's drafts (stale since then; the expiry check SOCIAL's fix needed passes).
- `tools/r81_social/measure.lua` keeps the one-second pattern FLAKY fixed in the check; its
  numbers can show about 1 KB of stack noise.

## Carry-overs

Each line names where it came from; the ones that are still wanted work have a BACKLOG line.

- **World generation speed** (audit lane 5): the next round, §7 (BACKLOG, Performance).
- **The capital plot engine's duplication** (W2-01..W2-05) and **the mob species boilerplate**
  (MOB3-05): optional refactors, ruling 1 (BACKLOG, Code hygiene).
- **Elder Bear and Silverback** never appear: every ambient bear and ape is an authored-tier
  sub-type and no recipe spawns a base name; a follow-up would let the normal-tier sub-types
  roll (ruling 17; BACKLOG, Mobs).
- **The minimap's party names** still come from `grug_parties.view` every 5 s per party player
  (about 200 `get_properties` a second at 100); `grug_parties.member_names` waits for it, and
  about 15 map fixtures need a stub line (SOCIAL; BACKLOG, Performance).
- **Invitation switches in the Social roster rows** are still read per build (P5-05's rest,
  SOCIAL; BACKLOG, Performance).
- **Completed quests in their own player-meta key** (P3-04's full fix) needs a migration step
  (UI; BACKLOG, Performance).
- **Environment damage on a lagging server:** at steady steps above 0.25 s the rounding is off
  by up to a third (0.36 s steps: 208 ticks in 300 s); a carry reset at the join and after a
  stall would fix it (PASSES delta review; BACKLOG, Performance).
- **Mail body trim** is still quadratic up to the 10,000-character draft (about 0.1 s for a
  crafted all-blank body, an estimate) (SAFE; BACKLOG, Performance).
- **Tag carriers:** the faction could come from PASSES' identity cache (a change would show at
  once), and `nearest_tag_player_d2` still walks the whole snapshot (SOCIAL; BACKLOG,
  Performance).
- **Engine probes:** `tools/r25_claim_core`'s probe is stale since Round 26's drafts (activate
  both claims, expect the draft variant); about 20 `grug_probe_*` write identity meta directly
  and would read stale values after a read (SOCIAL, PASSES; BACKLOG, Code hygiene).
- **The skills re-walk** in mods-loaded works only because grug_skills runs after grug_jobs; a
  later mod replacing node allow callbacks there would pass the guard (`core.after(0)` would be
  order-proof) (GUARDS review; BACKLOG, Code hygiene).
- **Fixture-only seams** kept under X3-03 (move immunity, `get_target` and its store,
  `clear_cooldown`, `test_vault`): delete them with their fixtures later? (DEAD; BACKLOG, Code
  hygiene).
- **`mob_nospawn_range`** defaults to 12 in `spawn_policy.lua` and `mobs/api.lua` but 24 in
  `spawn_regions.lua`; `minetest.conf` sets 24 (DEAD; BACKLOG, Mobs).
- **I1-05:** the two `drop_hover_text` LBMs (grug_text, grug_signs) stay as an accepted
  exception to the release rule; the upgrade contract does not name it yet (DEAD; BACKLOG, Code
  hygiene).
- **DD3-09:** `item_tiers.md`'s crown option table and two income tables are generated and
  dated; one crown row and the factor 0.50 in `tools/r33_ds/money.py`, then regenerate (DOCS;
  BACKLOG, Items).
- **The mod map's coupling list** omits the vendored `vessels` calling
  `grug_inventory.station_formspec` (DOCS review; BACKLOG, Code hygiene).
- **`grug_bridge.token` in `settingtypes.txt`:** the local main menu's settings show the secret
  in plain text (DEAD review; BACKLOG, Accounts).
- **DT2-04:** whether 5.18.0's default send distance 13 with generate distance 10 stalls loading
  is unmeasured; a short engine probe could settle it (DOCS; BACKLOG, Performance).
- **The rift crack's spawner** every 1 s or every 2 s: a look call (MOBRUN; BACKLOG, Open
  questions).
- **Cactus and papyrus** may still grow into POI cores; ruling 3 covers water only (SAFE;
  BACKLOG, WP46).
- Noted, no BACKLOG line:
  - C1-12, the water and lava guards as one file (SAFE).
  - Mana is kept over a relog without offline regeneration; claim mode shows within 0.5 s of a
    change inside the held slot; for one pass after a kill that swaps a skill in place, the
    ready ring and crosshair use the old name (HOT).
  - Lava with no safe column next to it leaves a set-down player held until the 30 s last
    resort; a push over one node releases a held rider; the weapon hint ignores the two-handed
    rule; the trinkets consumer rebuilds on the narrow pass (BUGS).
  - A whelp alive after its dragon settles could recreate the dragon's ledger if hit; the boss
    wind-up's second piece plays after a death mid-wind-up; `r36_r`'s log line keeps its "per
    player" wording (MOBRUN).
  - The preparation gate does not cover the seed, the WP43 projection digest, the layout texts
    or a POI-only template-reach change; any line naming `grug_prepare_full_world` counts as
    the note; the specials study's `index.html` links a viewer that is in history only (TOOLS).
  - grug_map's location line could reuse grug_pvp's zone answer (PASSES).
  - A party's HUD refreshes land in one 0.1 s step; the probe's `expired:1` passes on a faked
    draft until the probe is fixed (SOCIAL).
  - A Lava Seep saved mid-slow keeps 3.4 through `_grug_speed_base`; a long catch-up step can
    serve a row twice; the comment at `grug_mobs/init.lua` "(palettes, spawn recipes)", the
    empty "0 surface spawn rows retired" boot line, `verbs.lua`'s unread `def.physical = false`
    and `free_spot_near`'s levels reached only by `r78_small` (SPAWN).
  - `workspaces.lua`'s `empty_record` would read a list with a hole as empty (no writer makes
    one); a mail cache hit may store keys in another order; `held_back` would stay set if
    `add_counters` raised; P2-07's build skip (UI).
  - A registrar more than 2 nodes from its socket refuses without a word; `soulbound.lua` calls
    `grug_inventory` without a declared depends (GUARDS).
  - `grug_quests` still `dofile`s `capital_services.lua` twice (P3-08); `station_contents`'
    comment speaks of pre-Round-45 lists (DEAD).
  - DP1-02 is partly covered: literal workstation paths remain in a few process documents and
    templates (DOCS review).
  - The slot helper's `MAX_TICKS = 4` would keep the cadence down to two steps at the price of
    a larger burst after a stall (HOT delta review).
