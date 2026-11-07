# Round 71 — Expeditions: the framework and the level 20 Expedition

Planned with the user on 2026-11-07. **Started** on the user's go, 2026-11-07, on
branch `round71`. Routing (user, 2026-11-07): Opus 5.5 coordinates, implements and
reviews in its own context; GPT-6 Astra writes the storyline and quest text and
draws the art proposals. Version **0.71.0**, classification decided at its merge; no map reset is planned.

## Why

Groups have no repeatable group content, and the Miner's Guild has a story to give
it. This round proves the idea with one Expedition before four more are built.

## 1. Lanes and order

| Wave | Lane | Who | Goal | Waits for |
|---|---|---|---|---|
| 0 | SPIKE | Opus | Measure clearing and writing a full box in the engine; fix slot size, grid and step size | go |
| 1a | FRAME | Opus | Slots, preparation queue, template format and box writer, ownership, release, login rule, both waystones; publishes its interface first | SPIKE |
| 1b | GUARD | Opus | No riding, respawn inside, ore digging, proof that spawns stay out | FRAME's interface |
| 1b | MOBS | Opus | Room spawns, per-entity levels, no respawn, item levels above 60, boss credit, chest, reward door | FRAME's interface, Round 70 LEVELS |
| 1b | UI | Opus | Registrar NPC, level dropdown, eligibility dialog, invitation warning, preparing and ready notices, map | FRAME's interface |
| 0 | L20DOC | Astra, Opus review | Storyline, a short description and a 2D floor plan of the level 20 instance | go |
| 2 | L20 | Opus | The level 20 Expedition: template, roster, boss, loot table, quest | every wave 1 merge, **the user's approval of L20DOC** |
| 3 | D | Opus | Docs, completion, GUI checklist | every merge |

The other four Expeditions are a later round, on the proven format.

## 2. The user's rulings

The [concept](round71-expeditions-concept.md) holds them, with its proposals marked.
[Round 70 §2.10](round70-plan.md#210-boss-levels-and-item-levels-user-2026-11-07-no-reset-needed)
changes the item level rules this round builds on.

## 3. Shared conventions

- One new mod owns Expeditions (`grug_expeditions`); other mods get hooks, not
  Expedition logic.
- The word is "Expedition" everywhere: players, docs, briefs and code (user, 2026-11-07).
- The 100 slot positions, box size and step size live in one catalogue the lanes read.
- A template is a repository file written by a tool, like the building templates.
  The format stays 3D, so later Expeditions can use several y levels and height.

## 4. Lane goals

### SPIKE — measure first

In the engine, with a player online: emerge, clear and write a box of the largest
expected size in slots beyond the map, at about x 8000 and more. Report the time per
step, the effect on the running game and a sensible step size, and test whether more
than one preparation at once makes sense. Confirm the off-map behaviour the concept
reads from the code. Report numbers and a recommendation; the user decides on slot
position if it differs.

### FRAME — slots and binding

The pool, the low-priority preparation, the template format, its tool and the box
writer, ownership (player or party) with every change of owner, the entry gate, all
release rules of the concept including login and server restart, and both waystones.
Anyone who does not belong is teleported out at once. The interface for the other
lanes comes first.

### GUARD — the rules inside

No riding, respawn at the start waystone, the exception from the open sea's
immutability for what is meant to be dug. Building and flying are already refused
off the map; prove this and that natural spawns stay out of the box, and build only
what the proof shows is missing.

### MOBS — encounters

Spawn by encounter room through `_grug_spawn_level`, no respawn. Lift the item level
cap in `roll_mob_gear` for Expedition mobs only. Boss credit through `bosses.lua`,
without its 24-hour lockout and direct rewards. The per-player chest and the reward
door belong here.

### UI — the registrar

The NPC on the clerk's socket in the six guild houses, the dropdown with only the
levels the creator may enter, the eligibility dialog with its warning, the warning in
the invitation box, "Your expedition is being prepared...", the ready notice, the
minimap's ocean and party arrows off the map.

### L20DOC — for the user to read

A short description with a 2D floor plan of the level 20 Expedition: story, place in the guild's story, route,
encounters, boss, ore and rewards. One main floor; several y levels stay out for now.
Astra drafts the storyline and quest text, an Opus review round follows
the quest text rules. The user approves it before L20 starts.

### L20 — the first Expedition

Build what the approved L20DOC describes: T2 ore only, rare on the way and only after the first
mob pack, a richer reward room, its loot table, its optional quest. Balance for 3
players at every level from +0 to +9, and check XP against the level pace.

### D — docs

A design owner for Expeditions, `world.md` R4's exception, the completion section, GUI
checklist, STATUS, BACKLOG and CHANGELOG.

## 5. Rules

- Round workflow and `AGENTS.md` apply; every non-trivial lane gets an independent
  review.
- The running game comes first: preparation never competes with players.
- No lane pushes. Only the user pushes.
- A case the rulings do not decide stops that path and goes to the coordinator.
- Every launch prompt carries the fixture sentence of the lane start checklist.

## 6. Verification

Round workflow §3. `tools/r29_e4/income.py --check` for L20. Before and after
numbers for preparation with players online. Round end: one smoke boot of the
branch, then the user's test.

### GUI checklist (desktop and web)

Lane D expands this list.

- The leader activates an Expedition, sees the eligibility warning, waits, gets the
  ready notice; nobody enters before that. The dropdown shows only levels the leader
  may enter.
- Members enter up to the limit; the next member is refused, and so is a member below
  the entry level.
- A solo player creates one; inviting someone makes it the party's; joining a foreign
  party ends it and teleports out, after the warning.
- A party falling to one member leaves that member as owner.
- Leaving the party teleports out; a stranger cannot stay.
- 10 minutes with nobody inside releases the slot; a late login goes home.
- Both waystones lead to the capital; Return Home works inside.
- Mobs have the chosen level; their drops and the chest match it.
- Death respawns at the start waystone; building and mounts are refused.
- The boss opens the reward room; each player sees their own chest.
- The end waystone returns to the capital. A new run finds the planned layout.
- The minimap shows ocean and party arrows.
- The running game does not stutter during preparation.

## 7. Orchestration notes

- **Own coordinator context:** this round runs beside
  [Round 70](round70-plan.md) in its own session and private folder `r71`.
- **Branch:** an integration branch `round71` from main at the go; its lanes branch
  from it. Main is merged into it after each Round 70 wave.
- **Release order:** Round 70 ships as 0.70.0, then `round71` merges as 0.71.0.
- **Shared files:** Round 70 owns `game.conf`, STATUS, BACKLOG, CHANGELOG and the
  upgrade declaration until it is released; this round changes them only at its
  merge.
- **Touch points:** `bosses.lua`, `grug_quality/init.lua` and the guild hall socket
  list are Round 70's first; this round merges them in from main.
- **Limits:** the 8 Lua runs are shared. The user's GUI test takes one round at a
  time. `tools/sync_to_luanti.sh` syncs from main unless the user asks, so a test
  before the merge needs the user's request for a branch sync.
- **Lua queue:** the shared `~/projects/grudgelands-orchestration/r45/lua_run.sh`.
- **Decided during the round:** slot position if SPIKE differs, the user's approval
  of L20DOC.
