# Round 69 — trash slot, respawn at home, camp sites, exact tooltips, quest-drop markers

Planned with the user on 2026-11-04 from player reports and the user's notes;
started on the user's "go" the same day. Claude coordinates, Opus implements
and reviews, GPT-6 Astra draws the camp site. Version: **0.69.0**.
Classification: **migrate** (lane CAMP's camp rewrite, online part only);
every other lane is compatible. No map reset. Delivery state:
[STATUS](../STATUS.md).

## Why

The coordinator's reading of `3cee37b3`, re-checked by the lanes (round
workflow §2.4):

- **Trash:** players throw unwanted items on the ground. The Inventory tab's
  Money box has about four units of empty space under the deposit slot.
- **Respawn:** a bound innkeeper already is the respawn point; only a Claim
  Stone home differs, because `grug_home/travel.lua` `request` resolves
  respawn through `grug_home.innkeeper` and travel through `grug_home.get`.
  That was Round 25 ruling 25. Help already says "You respawn at your home."
- **Camps under construction** (six, `r58_camp_blueprint.lua`) still use wool
  tents and the old post palisade, and read as half a broken camp: the
  palisade simply stops. Every other camp moved to the Round 63 templates.
- **Berufe order:** the Crafting tab ends in Alchemy (`grug_jobs/ui.lua`
  `AREA_SLOTS`).
- **Tooltips:** the hotbar and catalog stacks show exact numbers through
  `description_for`, Ice Nova included (also in production's 0.65.0), but
  Ice Nova's wording hides it ("for 30", no "damage"). Strike, Hamstring and
  Retort's plain swing show no number. The talent tree shows only static
  shares ("65 % of a Spark hit") for every skill.
- **Words Worth Bringing Back:** a disposable engine probe on seeds 42 and
  2026 found all six camps on the quest-target index with free spawn spots;
  on seed 42 real spawns carried the names the drop counts. The Packet is a
  1-in-3 quest drop, not a world object, and the Bannerbreak text suggests an
  object. The missing marker is by design: item objectives mark nothing
  (`grug_map/targets.lua`). 97 of 390 quests have item objectives, 93 have
  nothing else. 14 of the 97 name their source in data the loader drops or
  the map ignores.

## 1. Lanes and order

| Wave | Lane | Who | Goal | Waits for |
|---|---|---|---|---|
| 1 | UI | Opus | Trash box in the Inventory tab; the professions' order | go |
| 1 | HOME | Opus | Respawn goes where the home teleport goes | go |
| 1 | SKILLS | Opus | Exact numbers on every damage skill and in the talent tree | go |
| 1 | QUESTMAP | Opus | Rings for the 14 quests, source in the objective line, one text fix | go |
| 1 | CAMPART | Astra | Camp site designs as ordinary templates on a pick page | go |
| 1, then 2 | CAMP | Opus | Phase 1: the box rewrite and migration, proved with a placeholder. Phase 2: the picked composition | phase 2: the user's pick |
| 3 | D | Opus | Docs, completion, GUI checklist | every merge |

## 2. The user's rulings (2026-11-04)

1. **Trash, variant A:** an own box "TRASH" at the bottom of the Inventory
   tab's right column; the Money box gets shorter. Only in the Inventory tab,
   no other view and no container form. Mockup: the
   [Trash-Slot Mockup](https://claude.ai/artifact/77CRcgYF6e3LCmZie226Mc)
   (board A and its four states).
2. **Undo:** a dropped item is destroyed at once; the last one can be taken
   back until the next discard or logout. No shift-click route into the slot.
   Soulbound and bound items are refused with a hint.
3. **Respawn is home, Claim Stone included**, also without fuel (travel works
   there too). Round 25 ruling 25 is retired.
4. **Camp sites get a new design** from an Astra round, picked by the user,
   that clearly reads as "being built" in the Round 63 materials.
5. **No map reset for it:** the migration rewrites each existing camp's fixed
   box with the new blueprint. This is a deliberate, documented exception to
   the rule "world generation needs a map reset".
6. **Fallback:** if the two-boot proof fails, existing camps stay in the old
   design until the next map reset, new ones generate in the new design. The
   lane reports this before falling back.
7. **Professions order:** Basic, Cooking, Alchemy, Primary 1, Primary 2.
8. **Markers only for the 14 quests** whose source the data names; the 83
   gathering, crafting and fishing quests stay unmarked.
9. **Exact tooltips:** every damaging skill shows its exact number with the
   player's level, weapon, gear and talents, as the range already does; the
   talent tree shows the numbers too, also for skills not learned yet.
   Target-dependent values (level malus, armor, crits) stay out.

**Coordinator defaults** (the user may overrule them):

- The professions overview and the help text follow ruling 7.
- The objective line of a quest with a known source names it, for example
  "Bring Runner's Packet: 0/1 (from Trench Archer)".
- The camp's five sockets keep their ids and their cells, so existing guards
  and the captain stay right; the gate stays on the same side.
- CAMP owns `game.conf`'s version and the declaration.

## 3. Shared conventions

- English in the repository, code names English, no references to existing
  games, factions The Accord and The Throng.
- No new sound (sound approval gate); the trash uses what exists or stays
  silent.
- The trash icon is `creative_trash_icon.png` with a texture modifier; no new
  art for it.
- `grug_inventory/help.lua`: UI edits the professions' lines, HOME the home
  and death lines; nobody else touches it.

## 4. Lane goals

### UI — trash box and professions' order

The box of rulings 1–2 at the mockup's place and wording, in the shared UI
toolkit, working on desktop and web, with text growth. Ruling 7 in the tabs,
the overview and the help. Compatible; undo state is runtime only.

### HOME — respawn at home

Respawn and the home teleport resolve the same home. A blocked or unavailable
Claim Stone falls back to the innkeeper, then the start, and the respawn hold
stays on until the player stands somewhere valid. No cooldown, no combat rule
on respawn. Design docs and comments that state ruling 25 follow. Compatible.

### SKILLS — exact numbers

Rulings 9: the number appears in the same form on every damage skill ("N
damage"), Strike, Hamstring and Retort's plain swing gain theirs, and each
number matches what a hit computes before target-dependent factors. The
talent tree's skill nodes (unlock, transform, ultimate and the like) append
the skill's current text through the same `description_for`, so tree and
hotbar never differ; heals and shields follow by that. Compatible.

### QUESTMAP — quest-drop markers

An item objective with a named source (its own `roles`/`area`, or a quest drop
of that item) marks the map the way a kill objective of that source does:
rings for an area, a crosshair for a leader or garrison, only while open. The
objective line names the source (coordinator default). The Bannerbreak variant
of `border_packets` stops suggesting a world object, keeping its voice. The
objectives themselves do not change, so no quest takes a new id. Compatible.

### CAMPART — the camp site (GPT-6 Astra)

Two or three designs of a camp under construction that read at a glance as
being built rather than broken, in the Round 63 materials, as ordinary building
templates for all six race palettes and both factions, inside the fixed box,
with an interactive 3D comparison page. Nothing under `mods/`.

### CAMP — the new blueprint and the box rewrite

The camp site composition becomes templates (as the mining camps are). A
`migrate` step 0.69.0 with an online part rewrites each of the six boxes once,
whatever is generated, surviving restarts and safe to repeat. Phase 1 proves
the mechanism on a real 0.68 world (two boots) with a placeholder composition;
phase 2 installs the user's pick. The upgrade contract documents the
exception.

### D — docs

The usual: completion, GUI checklist, status owners.

## 5. Rules

Round workflow §3 gates; release mode; the Lua-process cap and the engine-run
budget of AGENTS.md; no map reset; no push.

## 6. Verification

Portable fixtures per lane (`tools/r69_<lane>/`), one smoke boot per code
lane, CAMP's two-boot proof on a 0.68 world, a quick seed fleet for CAMP (the
camp blueprint's path changes, the footprint does not), the migration's test
including the container run, GUI checklist by lane D.

## 7. Orchestration notes

- Start state: main `3cee37b3` plus this plan; all lanes branch from it.
- Merge order: UI, HOME, SKILLS, QUESTMAP in the order they pass review; CAMP
  last, because it owns the version; then D.
- Shared files: `grug_inventory/help.lua` (§3). `grug_quests/*` and
  `grug_map/*` are QUESTMAP's; `grug_classes/talent_graph_ui.lua` SKILLS';
  `mods/CORE/grug_core/migrations.lua`, `game.conf`,
  `tools/web_data/upgrade.json`, `docs/technical/upgrade-contract.md` CAMP's.
- Decided during the round: the user's camp pick.
