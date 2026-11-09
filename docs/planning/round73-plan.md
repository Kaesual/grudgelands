# Round 73 — the Expedition redesign

Planned with the user on 2026-11-09 and 2026-11-10 after their test of the three
Expeditions. **Not started:** it starts on the user's go, on branch `round73`.
Routing (user, 2026-11-10): one coordinator (Opus 5.5); Opus 5.5 implements and reviews
every lane; no Astra lane. Version **0.73.0**, classification decided at the merge
(expected compatible: no map reset is planned).

The design is [round73-expedition-redesign-concept.md](round73-expedition-redesign-concept.md)
(the concept). This plan holds lanes, conventions, rules, checks and orchestration; it
does not repeat the concept's rules, it points to them by section.

## How to add to this document

- A new ruling goes to §2 with its date and, when it changes a design rule, into the
  concept too. A lane goal changes in §4, a row in §1.
- Mark what is what: a **ruling** is the user's, with its date. A **proposal** or
  **finding** is not a ruling until the user says so; a coordinator default is marked as
  such.
- Name functions rather than line numbers.

## Why

The user's test (2026-11-09): the Expeditions work, but read as monotonous and forced:
the same lanterns everywhere, straight passages with evenly spaced torches, flat rooms
with few dangers. The causes are in the shared helpers and the proofs (concept §1), so
the round changes those first and then reshapes each Expedition.

## 1. Lanes and order

Start state: main at this plan's commit (0.72.2 plus the concept). Integration branch
`round73`; lanes branch from it.

| Wave | Lane | Goal | Waits for |
|---|---|---|---|
| 1 | GAME | Format lines, the ambush, critters, particles, lava immunity in the game; the test vault as the probe (§4) | start |
| 1 | TOOLS | Authoring helpers, the shared proof, previews (§4) | start; merges after GAME |
| 2 | SEAM | The Stilled Seam redesigned (concept §4, §5) | GAME, TOOLS |
| 2 | SHIFT | The Second Shift redesigned | GAME, TOOLS |
| 2 | MINT | The Last Mint redesigned | GAME, TOOLS |
| — | D | Docs, completion, GUI checklist | every merge |

GAME and TOOLS run in parallel against the format fixed in §3.1. TOOLS merges second: it
merges `round73` into its branch after GAME's merge, writes the new lines through GAME's
`template.py` writers, and proves the test vault with them before its review.

**The user's look (2026-11-10, the user's iteration style):** each wave 2 lane delivers
previews of every room and passage. The coordinator shows them to the user before the
lane's merge; the user's fixes go back to the lane's context.

The full fixture run happens **once, at the round's end**, by the coordinator (§7).

## 2. The user's rulings

All recorded in the concept §2, with dates:

- 2026-11-09: more variety in rooms, passages and light; darker passage stretches; lava
  from the walls in a few places; a few critters; mossy cobblestone; a few plants;
  **floor relief by stairs only** (normal, inner, outer), navigation stays x and z
  (replaces Round 72's "floors stay flat"); concept first, then one agent per Expedition.
- 2026-11-10: boss rooms may have relief (replaces Round 72's "no dais"); light 0 is
  allowed where the next light is in sight; **the ambush stretch** (concept §4.5);
  critters are real mobs, plus particles fitting the setting; Opus for every lane.
- 2026-11-10, coordinator defaults the user accepted: after a wipe the ambush pack is a
  normal pack; ambush mobs melee only; two candidates, one armed per run; a dust burst
  is the only cue.
- 2026-11-10: **lava may be a danger in a fight** (no distance from fighting areas);
  **mobs walk round lava**; **every Expedition mob and boss is immune to lava**;
  **height maps must not look even**: deeper pits and higher rises wanted, the
  one-node neighbour rule the only limit.

## 3. Shared conventions

### 3.1 Template lines (GAME implements, TOOLS and wave 2 write them)

Version 1 stays; a reader of this round reads every Round 71 and 72 file. Coordinates are
box-relative node positions, as every other line.

- `ambush <group> <pick> <room> <x0> <y> <z0> <x1> <z1>`: one ambush candidate. The zone
  is every cell from (x0, y, z0) to (x1, y, z1), both corners included, `y` the first air
  row (the feet). `<room>` names its markers: the `encounter` lines with that room. A
  group's lines agree on `pick`, as trap groups do; a run arms `pick` of them at
  readiness. Ambush groups and trap groups share one name space.
- `encounter <room> <mob> <count> <tier> <x> <y> <z>` gains the tier **`critter`**. A
  room named by an ambush line holds only `normal` markers and is never placed by
  proximity. A critter marker's room is any other name, never a pack's.
- `particles <style> <x0> <y0> <z0> <x1> <y1> <z1> <amount>`: a spawner in that box,
  both corners included; `<amount>` is the most live particles it keeps. Styles, a fixed
  list GAME defines and draws: `drip`, `dust`, `ash`, `paper`, `ember`, `spark`. GAME may
  add a style and names it in its report.

`template.lua` refuses a malformed line at load; `template.py` refuses it at build.

### 3.2 Floors and stairs

- The floor of a template is a **height map**: `h(x, z)`, the first air row of each
  walkable column. Proofs derive it from the written file, never from a source.
- Stairs are `stairs:stair_<m>`, `stairs:stair_inner_<m>`, `stairs:stair_outer_<m>` of an
  existing material (concept §4.1.8), upright (`param2` 0–3). Only the TOOLS helper
  writes floor stairs; a wave 2 lane that needs another shape asks the coordinator.
- Rules: concept §4.1 (one surface per column, neighbours within 1 with a stair, no
  one-node ridge, free height from the local floor, traps on flat cells, uneven on
  purpose).

### 3.3 Mobs

- An Expedition mob is the one `packs.lua` spawn makes and `_grug_expedition` marks
  (Round 71). Lava immunity, critter behaviour and the ambush hang on that mark.
- Ambush markers: the Expedition's own roster, `normal` tier, melee only (no
  `dogshoot`). Critters: `grug_mobs:cave_bat`, `grug_mobs:cave_crawler`,
  `grug_mobs:bone_weevil`.

## 4. Lane goals

### GAME

The game side of the concept, and the test vault as its probe.

- **Format:** §3.1 in `template.lua` and `template.py` (readers, writers, checks) and in
  `docs/technical/expedition-template-format.md`.
- **Ambush** (concept §4.5) in `traps.lua` and `encounters.lua`: chosen with the trap
  groups at readiness; triggered by a living player of the run entering or crossing the
  zone at any height and by any movement, never by respawn, Return Home, waystone
  travel or the entry teleport; fires once, no ring, no mark, no rearm, no wipe rearm;
  spawns its room's markers at that moment, which engage at once; the dust burst. After
  that its room is a pack like every other.
- **Critters** (concept §4.8): the `critter` tier, placed outside the pack logic; no
  drops, no credit, no pull, no combat start inside an Expedition; no XP inside an
  Expedition (coordinator default; GAME reports if that is more than a line).
- **Particles** (concept §4.8): spawners per run from the template's lines, sent only to
  the run's players inside, running only while one is inside, removed at the run's end.
- **Lava immunity** (concept §4.6): `lava_damage` 0 for every Expedition mob, at spawn and
  on every activation. Confirm that mobs still never walk into lava (`grug_nav`, the
  walk-edge probe, the direct chase, the home return, a spawn spot) and close any path
  that does. A boss in a basin inside its envelope does not trigger the boss reset's
  "no way".
- **The test vault** (`tools/expedition_templates/sources/test_vault.py`, hidden): GAME owns
  it in this round. A few stairs (normal, inner, outer, written by hand), a lava fall
  with a basin beside the floor, one ambush with alcoves, two critters, one particle box.
- **One engine run**, its questions: players and mobs walk the stairs, inner and outer
  included; written flowing lava stays as written under the lava hold; a pack chasing a
  player at a basin's edge does not step in; a mob pushed into the basin takes no damage
  and walks out; the ambush fires once from every way across its zone and not on
  respawn or travel; critters stay out of combat and drop nothing; the particles reach
  only the run's players.
- `docs/design/expeditions.md` §7, §8 and "Traps" for the ambush, critters, particles and
  lava immunity.

### TOOLS

The authoring side and the one shared proof (concept §6.1, §7).

- **Helpers** in `tools/expedition_templates/shaping.py` (or new modules beside it):
  relief from a height map with the right stairs and `param2` and refusal of a broken
  map; passages as polylines with a width profile, relief and niches; light at authored
  points and a seeded irregular spread with no coordinate modulo; dressing scatter by a
  density map with the walkability rule; the lava fall (niche, column with its flowing
  levels, basin); the ambush stretch (zone, alcoves, light-0 margin, markers). A short
  usage note at the top of each helper, written for the wave 2 lanes. `wall_lights` and
  the grid lantern code stay until wave 2 removes their last use; TOOLS removes nothing
  a template still calls.
- **Height-map variety:** the relief helper offers irregular shapes out of the box
  (seeded uneven outlines, uneven slopes, several features), so an even room takes
  effort, not the other way round (concept §4.1.10).
- **The shared proof** `tools/expedition_templates/proofs.lua`: concept §7, items 1–11,
  with the floor as a height map. The three fixtures (`tools/r71_l20`, `tools/r72_shift`,
  `tools/r72_mint`) call it and drop their own copies of the light and sight checks; they
  keep what is specific to their Expedition. On the current three templates the new
  rules that they do not meet yet are reported per rule and per template, not failed
  (a switch the wave 2 lanes turn off for their template).
- **Previews:** `preview.py` draws relief (height shading), light zones (0, below 4, 4+),
  ambush zones, lava and critter markers, and a section through each stair run.
- No change to a real template, no game code.

### SEAM, SHIFT, MINT

One lane per Expedition: its source in `tools/expedition_templates/sources/`, its written
template, its fixture, its balance model and its section of `docs/design/expeditions.md`
(§13, §14, §15). Goals: concept §4 in full and §5's direction for its Expedition, within
concept §3 (what stays). In particular:

- every room and passage reshaped: relief by stairs with uneven height maps, bent
  passages with niches and features, room types not repeated next to each other, some
  rooms flat or cuboid on purpose;
- light from things that belong there, no grid; dark stretches with a light in sight;
- two ambush candidates, pick 1 (The Stilled Seam may have one, reported with the
  reason); strength about half a room pack by its balance model;
- one to three lava falls (The Last Mint: at most three besides its lake and pillars),
  also beside fighting areas, never at a passage mouth, a stair foot or in the dark;
- moss, plants and litter in clusters; three to six critters; particles of its setting;
- its fixture on the shared proof with every rule on; previews of every room and
  passage for the user (§1).

A lane changes no shared helper and no game code. A helper that is missing or wrong goes
to the coordinator, who has TOOLS (resumed) or the lane fix it; a lane may keep a local
helper in its own source.

### D

Docs: `docs/design/expeditions.md` overview, `docs/STATUS.md`, `CHANGELOG.md`, the
completion section of this plan, the GUI checklist (§6) from the lanes' excerpts.

## 5. Rules

- Concept §3 is binding: route, packs, boss, ore, door, chest, waystones, Round 72 traps,
  the lake, pillars, press and sign stay; positions move only inside their room with
  every proof holding.
- "Expedition", never "instance", in code, docs, briefs and reports.
- No new sound: nothing plays without the user's pick on a listening page.
- Particles within the web budget: a few hundred live at most per Expedition.
- No new node and no new stair set without the coordinator's and the user's yes.
- No gathering source, crop or walkable decoration on a walking cell (concept §4.7).
- Balance: the ambush's numbers come from each Expedition's balance model; packs and
  bosses keep theirs.
- The Round 72 proofs keep holding in their Round 73 form (packs cannot be walked round,
  coverage, free height, no perches, traps).

## 6. Verification

Fixtures: GAME's own (format lines, ambush trigger by walk, sprint, jump and a skill
across the zone, not by respawn or travel, once only, the wipe; critter tier;
particles to run players only; lava immunity at spawn and activation); TOOLS's own (the
relief helper on hand-made height maps, every refusal; the proof on broken
templates, each rule failing once); each wave 2 fixture with every rule on.

Engine runs: GAME's one run (§4); one run per wave 2 Expedition from registrar to chest at
its first level, as few as Round 72's.

Release check at the round's end: compatible if no saved format changed (templates are
written at each preparation, a restart ends every run).

### GUI checklist (desktop and web)

Drafted here, completed by D from the lanes' excerpts. *Look* asks for the user's
verdict. **[2+]** needs two or more real players; **[fight]** a real fight.

**Every Expedition**

1. *Look:* no lantern grid and no torch row; light sits where something is (a desk, a
   door, the ore, a lava fall).
2. *Look:* passages bend, change width, have niches; no passage reads as a straight tube
   except the dark stretches.
3. *Look:* rooms have relief by stairs, uneven: pits and rises of several levels, no
   single square dais, some rooms flat on purpose.
4. Walk every stair run, up and down, also across inner and outer corners: no jump
   needed, no stuck spot.
5. A pack follows you over stairs into a pit and out of it; it does not get stuck.
6. **[fight]** A boss fight on the boss room's relief: the boss walks it and resets as
   before when you leave its room.
7. A dark stretch: the light at its end is visible from every point in it.
8. The ambush: crossing the zone in the dark spawns the pack from the alcoves with a
   faint dust burst, nothing before. It happens once: after a wipe the pack waits in its
   alcoves, visible, and crossing again spawns nothing new.
9. The ambush cannot be passed without firing it: try a jump, a sprint and a movement
   skill.
10. Respawn and waystone travel past the zone do not fire it.
11. **[2+]** The other ambush candidate stays quiet in that run; a new run may arm the
    other one.
12. A lava fall: lava runs down in its recess into a basin and stays there.
13. **[fight]** Fighting beside a basin: a pack's hits can push you in; the mobs never
    walk in by themselves; a mob you push in takes no damage and comes back out.
14. *Look:* moss and mossy cobble in patches, a few plants, bones, cobwebs; nothing
    blocks a step.
15. Critters: a few bats, crawlers, weevils; they flee; hitting one pulls no pack and
    drops nothing.
16. *Look:* the particles fit the place (drips and dust, ash and paper, embers), not a
    fog; the web client stays smooth.
17. A full run from registrar to chest on each Expedition at its first level.

**Per Expedition** (filled in by D from the lanes)

18. The Stilled Seam: ...
19. The Second Shift: ...
20. The Last Mint: ...

## 7. Orchestration notes

- **Start state:** main at this plan's commit: 0.72.2 (Rounds 72, 72.1 and 72.2) and the
  concept.
- **Worktrees:** `.claude/worktrees/round73` for the integration branch, one per lane
  (`r73-<lane>`). The `character-creation` worktree and branch belong to another session
  and are not touched.
- **CPU: LuaJIT runs sparingly** (user, 2026-11-08). Launch prompts carry: "Fixtures: run
  only the fixtures that are strictly needed, your own and those that really test the
  behaviour you change, as few times as possible; no full run (the coordinator runs it
  once at the round's end); name what you ran and why." Shared queue `r45/lua_run.sh`,
  at most 8 Lua processes. After a merge the coordinator runs only the merged lane's
  fixtures and those of a conflict's files. Engine runs few, each with a question;
  reviewers repeat no run a lane reported.
- **Building templates** is Python and cheap; `build.py --check` belongs in every lane's
  report.
- **Shared files and merge order:** GAME, then TOOLS (TOOLS merges `round73` in first).
  Wave 2 lanes share `docs/design/expeditions.md` (each only its own section) and
  `build.py`'s output folder (each only its own file); merge order SEAM, SHIFT, MINT,
  each merging `round73` in before its review when an earlier one landed.
- **Compaction checkpoints** (user, 2026-11-08): the coordinator pauses (no launch, no
  merge), updates `r73/HANDOVER.md` and gives the user a compaction prompt.
  - **C0** before the start (this planning).
  - **C1** after GAME and TOOLS are merged, before wave 2 starts.
  - **C2** after the user's look at the wave 2 previews and the three merges, before the
    round-end full run and D.
  - **C3** after the full run and D, before the squash merge to main and the GUI test.
- **Landing:** one squash commit on main, tag `round-73` on the round branch's tip, the
  branch and its worktrees removed (round workflow §2.7).
- **Decided during the round:** each ambush's mob count (balance models, checked by the
  coordinator against "about half a room pack"); the particle styles' look (GAME, seen in
  the GUI test); a new stair set or node (the user).

## 8. Open questions

None blocking. The user may still change a coordinator default in §2 before the go.
