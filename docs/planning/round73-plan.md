# Round 73 — the Expedition redesign

Planned with the user on 2026-11-09 and 2026-11-10 after their test of the three
Expeditions. **Done** on branch `round73` (2026-11-10): what shipped, the numbers and the
round's decisions are in [Completion](#completion-2026-11-10), the GUI checklist in §6.
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
| after C2 | HPCAP | Mobs keep health above 65,535 (added after C2, the user's yes: §2) | wave 2 |
| after HPCAP | BOSSHP | Dragons 100,000 HP, Kings and Generals ×3, Auditor Nemm ×14 (the user's picks: §2) | HPCAP |
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
- 2026-11-10, during wave 1: **the ambush is never the first fight**: it lies after the
  first real pack room on the route (concept §4.5, "Placement"; proof item 8 checks it).
- 2026-11-10, during wave 2: **pack rooms may be darker in patches**: light 6 on 75 % of
  the fighting floor instead of 90 % (concept §4.4; `USUAL_SHARE` in `proofs.lua`).
- 2026-11-10, after wave 1 (TOOLS's questions, accepted as recommended): **lights at the
  feet plus the tallest mob plus one or higher, or in wall cells**; the ambush alcoves'
  floor within two steps of a cell that sees a light needs no light in sight itself; the
  test vault's lava foot stays as the probe.
- 2026-11-10, the user's look at the wave 2 previews: The Stilled Seam and The Last Mint as
  shown, the Seam's ambush stays at two spiders; The Second Shift as shown, but its light
  "may be somewhat more uneven" (two light rounds followed).
- 2026-11-10, after C2: **fix the boss HP cap in Round 73** (lane HPCAP): mobs above 65,535
  health lost the rest on the first hit.
- 2026-11-10, after the boss comparison (lane BOSSHP): **dragons 100,000 HP** (was 30,000),
  **Kings ×3** an elite's HP (10,812 → 32,436 at 70; the Generals share the factor, 9,401 →
  28,203 at 65; guards and bodyguards stay), **Auditor Nemm ×14** (was ×20). **Group sizes:**
  a King is a fight for **four** players, a dragon for **five**. Nothing else changes.

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

Drafted here, completed by D from the lanes' excerpts. Every item on the desktop and in the
web client. *Look* asks for the user's verdict. **[2+]** needs two or more real players;
**[fight]** a real fight; **[web]** is mostly a web client question; *(not proven)* marks
what the engine runs did not prove (a probe's own bug, fixed by reading and not run again),
so only the user's test shows it.

**Every Expedition**

1. *Look:* no lantern grid and no torch row; light sits where something is (a desk, a
   door, the ore, a lava fall).
2. *Look:* passages bend, change width, have niches; no passage reads as a straight tube
   except the dark stretches.
3. *Look:* rooms have relief by stairs, uneven: pits and rises of several levels, no
   single square dais, some rooms flat on purpose.
4. Walk every stair run, up and down, also across inner and outer corners: no jump
   needed, no stuck spot. *(Not proven for a player: mobs climbed the test vault's stairs.)*
5. A pack follows you over stairs into a pit and out of it; it does not get stuck.
6. **[fight]** A boss fight on the boss room's relief: the boss walks it and resets as
   before when you leave its room.
7. A dark stretch: the light at its end is visible from every point in it.
8. The ambush: crossing the zone in the dark spawns the pack from the alcoves with a
   faint dust burst, nothing before; *look:* the dust is visible but faint (keep or tune). It happens once: after a wipe the pack waits in its
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
15. Critters: a few bats, crawlers, weevils; they flee; hitting or killing one starts no
    fight, pulls no pack and gives no drop and no XP. *(Not proven.)*
16. *Look:* the particles fit the place (drips and dust, ash and paper, embers), not a
    fog. **[web]** the web client stays smooth.
17. A full run from registrar to chest on each Expedition at its first level.

**Per Expedition** (filled in by D from the lanes)

18. The Stilled Seam:
    - Both drifts (the haulage drift, the drift down to the sorting floor) are dark with the
      end light in sight; the armed one springs 2 spiders once, and the run then goes on to
      Flintback and the chest. *(Not proven: the probe's packs trailed it.)*
    - Climb the prop room's rubble ramp; the lava burns beside pack b and in the court.
    - Pack c follows you into bay c's pit and back out.
    - **[fight]** Flintback walks his uneven arena and resets when you leave his court.
    - *Look:* lantern density, moss, cobwebs, drips.
19. The Second Shift:
    - Both drifts (grain, pay) are dark with the light at the far end visible; a run arms
      one: 3 Buried Miners from 2 alcoves, once.
    - Bay d's sunken pay floor: pack d follows you down and back up. *(Not proven.)*
    - **[fight]** Nemm on his sunken floor: leave north through the pay drift (z ≤ 84, beyond
      his 3-node reach of the court floor) and he resets; the reward door stays shut while he
      lives. *(Not proven.)*
    - The lava falls in the marking floor and the court, beside the fight.
    - The office: square, cobwebs, candles; paper drifts over the desks and pay tables, ash
      at the falls.
    - Critters: two bats (arrival, store), two weevils, a crawler in the pay drift's niche.
      *(Not proven: the probe saw only the near ones.)*
    - *Look:* the pack rooms' light uneven enough (6 on 86 %), the lanterns no longer the bulk.
20. The Last Mint:
    - *Look:* no room type next to its own: terraces, the sorting pit, the hearth with its
      lava fall, the slag heap, the coffer terraces, the sunken arena, the flat strongroom.
    - Lure pack a into the sorting pit and back out over its stairs. *(Not proven.)*
    - **[fight]** Duewarden climbs his arena's rings, and leaving the hall resets him; fight
      beside the east wall's lava basin.
    - The flue run is dark with the lava glow visible from end to end; the drift is dark
      with a lamp at each end. Either ambush: 3 Seeps out of the alcoves, the dust, once.
    - *Look:* emberglass in the low vaults: too many? Embers at the falls and over the lake,
      sparks at the furnace mouths and the press.
21. **[fight]** Boss health (lane HPCAP): a boss above 65,535 health, e.g. Auditor Nemm at
    69 (147,308) or a dragon (100,000): after the first hit its bar and nametag show the
    design health minus the hit, not 65,535; after a reset it is back to the full design
    health.
22. **[2+] [fight]** Boss health and group size (lane BOSSHP): a King with **4 players**
    (32,436 health, modelled about 85 s) and a dragon with **5 players** (100,000, modelled
    about 160 s, enraged at 50,000): *look:* the fight length feels right. A General
    (28,203) with 4. Auditor Nemm at 40 (53,592, modelled about 2.7 min) not too long or too
    short.

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

None blocking. What the round left for the user's look is in
[Completion](#open-for-the-user).

## Completion (2026-11-10)

Every planned lane is merged into `round73` at `f33c4a53`, lane HPCAP (after C2) at
`ca5bc2cb`, lane BOSSHP follows; this lane D runs on `f33c4a53`. **Nothing is on main and nothing is pushed:** `round73`
lands on main as one squash commit (0.73.0, tag `round-73`) after C3 and the user's word.
Every lane had an independent Opus review.

**0.73.0 is compatible:** no step, no map reset. Every lane report says compatible (GAME,
TOOLS, SEAM, SHIFT, MINT, HPCAP, BOSSHP), and lane D's reading agrees: the templates are
written anew at every preparation, a restart ends every run, and nothing touches world
generation; `check_upgrade.py --base 2a0cfca8` (0.72.2) passes (the towns build as in
0.72.2). Saved state: none new. Two staticdata fields, `lava_damage` and
`_grug_scenery`, live only on mobs inside Expedition boxes, which every preparation wipes.

### Lanes

`round73`'s first-parent merges from the start `b2d3bc94` (lane tip in brackets):

| Lane | Commit | What | Review |
|---|---|---|---|
| GAME | `47122e06` (`7a9ffcb3`), `23b3c71d` (`23b709cb`) | The `ambush`, `critter` and `particles` lines (§3.1), the ambush in `traps.lua` and `encounters.lua`, critters, `particles.lua`, lava immunity, the test vault | MERGE (three Low; the writers' integer check as a follow-up) |
| ruling | `ada1527c` | The ambush is never the first fight (concept §4.5, proof item 8) | coordinator |
| TOOLS | `6884adf6` (`13fdd614`) | `relief.py`, `passages.py`, `light.py`, `dressing.py`, `hazards.py`, `registry.py`; the shared proof `proofs.lua` (14 rules); `preview.py` | MERGE AFTER FIXES (2 medium, 5 low), delta MERGE |
| fixture | `584f8523` | `r73_game` lets the real templates carry the new lines | coordinator |
| ruling | `4c772108` | Light 6 on 75 % of the fighting floor (`USUAL_SHARE`) | coordinator |
| SEAM | `98db644d` (`d8cd8b87`) | The Stilled Seam redesigned | MERGE |
| SHIFT | `9da7895e` (`5108d23c`) | The Second Shift redesigned, two light rounds after the user's look | MERGE (two stale numbers fixed by the coordinator) |
| MINT | `942d3ee4` (`8f5e178a`) | The Last Mint redesigned | MERGE AFTER FIXES (a fall at a passage mouth), delta MERGE |
| cleanup | `f33c4a53` | `shaping.wall_lights` dropped, its last use gone | coordinator |
| D | `2bd9e171` (`17ccbc70`) | Docs, release 0.73.0, this completion, the GUI checklist, BACKLOG | coordinator read |
| HPCAP | `ca5bc2cb` (`6f7cd68d`) | Mobs keep health above 65,535 | MERGE |
| BOSSHP | `92ab6434` (`ac9bfbb0`) | Dragons 100,000 HP, Kings and Generals ×3, Nemm ×14 | MERGE |

### What shipped, with numbers

All numbers measured on the written templates unless marked modelled.

- **GAME:** the three §3.1 lines in `template.lua` and `template.py` (readers, writers,
  refusals; one refusal more than planned: one ambush per room); the ambush trigger, a
  segment from each player's last position against the zone (feet −0.5 to +3, moves up
  to 16 nodes), 0.11 µs per player per 0.2 s pass (PUC 5.1, measured), none once fired;
  critters outside the packs (no drop, no credit, no fight, no XP: the critter tier pays
  none anyway); `particles.lua`, six styles, 300 live particles per template at most; lava
  immunity at spawn and activation, two open paths into lava closed (a spread spawn spot
  without floor, a pack's jump onto a player in lava). `r73_game`: 2,216 checks.
- **TOOLS:** the helpers above, each with a usage note; the shared proof's 14 rules
  (surface, relief, free height, head room, perches, dressing, route, packs, light, sight,
  ambush, lava, traps, particles), 0.1–0.4 s per template; `preview.py` for all four
  Expeditions in about 2 s. The three Expedition fixtures run on it with every rule on.
- **The Stilled Seam:** 17 stair runs, floor y 3–8; light from 59 lanterns at the feet + 4
  or higher, 22 anthracite lamps in rock niches, 12 candles and the lava, fighting floor 96 %
  at 6 or more; two ambush candidates of 2 spiders (modelled: 50 % of pack a's time, 30 % of
  its damage; 34 % and 20 % of a mean room pack); 2 lava falls; 5 critters; 4 drip and 3 dust
  boxes, 122 live; walk 254 → 260 steps.
- **The Second Shift:** 389 stairs, floor y 5–10; lights 45 hanging lanterns, 27 lamps, 41
  torches, 8 candles (was 115 lanterns and 327 torches), fighting floor 86 % at 6 or more, 31 %
  of the passages at 0, head room short nowhere (was 440 cells); two ambush candidates of 3
  Buried Miners (modelled: 48 % of a room pack's time, 35 % of its damage); 2 falls, 30 lava
  nodes; 5 critters; 6 particle boxes, 170 live; walk 254 → 284 steps.
- **The Last Mint:** 611 stairs, floor y 29–35, 5 nodes of air everywhere (was 394 cells
  short); about 292 lights (146 emberglass in walls and vaults, 78 lanterns at the feet + 5 or
  higher, 8 candles, 9 forge-coal niches, the lake's 48 torches; was 355 torches and 87
  lanterns), fighting floor 2,762 cells at 94 % at 6 or more, 529 dark cells each with a light
  in sight; two ambush candidates of 3 Seeps (modelled: 0.44 of a room pack's time, 0.32 of its
  damage); 3 falls, 41 lava cells; 4 critters; 8 particle boxes, 200 live; a run 10.8 minutes
  at 60 and 16.1 at 69 (modelled, was 10.1 and 15.0).
- **HPCAP:** the engine keeps `hp_max` as u16; `levels.lua` writes the property as at most
  65,535 and keeps the game's max in `self.hp_max`; five `mobs/api.lua` readers (the
  clamp, the infotext, the spawn roll, feeding, the staticdata loop) and the Warrior's
  below-30 % test ask the field first. Before the fix, at the 0.72 numbers, the first hit
  left Nemm 86 % (40) to 31 % (69), Duewarden 58–44 %, Flintback at 69 78 %; now 100 %.
  Above the limit after BOSSHP: the dragons (100,000), Duewarden at every level (113,232 at
  60, 147,308 at 69), Nemm from level 45 (66,430; 147,308 at 69), Flintback from 61.
  `r73_hpcap`: 85 checks with BOSSHP's dragon section.
- **BOSSHP:** the boss tier's flat HP (the dragons only) 30,000 → 100,000; `king_def`
  `_grug_hp_scale = 3` (Kings 10,812 → 32,436, Generals 9,401 → 28,203; royal guards and
  bodyguards 8,088 as before); Nemm 76,560 → 53,592 at 40 and 210,440 → 147,308 at 69.
  Modelled (`tools/r72_shift/balance.py`): Nemm 231 → 162 s at 40 and 546 → 383 s at 69,
  the run 10.3 → 9.1 min at 40 and 17.2 → 14.4 at 69; a dragon with 5 players about 48 →
  161 s, a King with 4 about 28 → 85 s (the BOSSCMP model). Enrage, whelps, Regrowth and
  Rally, the 15 s rule, the idle heal and the resets are fractions of `self.hp_max` or
  time, so they scale with it.

Engine runs: one per lane for GAME, SEAM, SHIFT and MINT (each about 5 minutes, through the
queue). Proven: the ambush springs once from every way across it (a walk, Blink, knockback,
Charge, sprint, jump) and never on a respawn or a trip; written lava stays as written; a
mob in a basin takes no damage and climbs out; the particles reach only the run's player;
in each Expedition the armed ambush once (the unarmed one quiet in the Seam and the Mint), the kill and the door;
Flintback's and Duewarden's reset; the chest in The Second Shift and The Last Mint. What
the probes did not prove went to the GUI checklist (§6, *not proven*). No round-end engine
run.

Round-end full run on `92ab6434`: 336 passed, 0 failed (queue, `JOBS=2`; log in the orchestration
folder `r73/reports/integration/full-92ab6434.log`); `check_fresh_server` PASS, `build.py --check`
OK, `check_upgrade --base 2a0cfca8` PASS.

### Coordinator defaults the lanes built

- One ambush per room (GAME's extra refusal, accepted at the review).
- No second engine run for GAME's critter hit and player stairs: the GUI test covers them.
- The test vault's ambush stays in its first drift (a probe, reported, not failed).
- The Stilled Seam's ambushes are spiders only: its golem counts as ranged.
- The Last Mint's furnace mouths are forge-coal niches (`grug_decor:capital_lava`), not
  `dual_furnace_active`, whose fire loop the sound gate rules out.
- The Second Shift's light build aims at 80 % at 6 or more (the proof asks 75 %).
- No round-end engine run; unproven probe items are GUI checklist items.

### Deviations

- SEAM touched two shared fixtures: `r71_pack` (room-pack rows only) and `r73_game` (taken
  as `round73`'s version at the merge). TOOLS added the missing `grug_home` stub to
  `r72_shift` and `r72_mint` (GAME's `traps.lua` needs it).
- The Stilled Seam's ambush is a third of its mean room pack, not a half (the user kept it).
- The Seam's alcoves are 2 deep, not `hazards.alcove`'s 3: only that depth passes the proof's
  two-step alcove sight exemption (the spider sticks about 0.55 into the passage).
- The Last Mint moved places inside their rooms for the relief: 11 of 12 floor traps (up to
  6.1 nodes), 15 of 19 mob spots (up to 5.8), the start waystone (10.2) and the arrival (8.5).
- Lane HPCAP was added after C2 for a bug found in the SHIFT review, live since Round 72.
- Lane BOSSHP was added after HPCAP for the user's boss health picks (§2); The Second
  Shift's run at 40 is now about 9 minutes, below the 10–20 of `expeditions.md` (modelled).

### Open for the user

- The [GUI checklist](#gui-checklist-desktop-and-web), 22 items (18–20 with their points).
- *Look* questions from the lanes: the ambush dust is faint (glow 2, alpha 0.55; tune after
  the look); The Last Mint's emberglass in the low vaults, too many?; The Second Shift's
  lanterns still the bulk of its light?
- Backlog: [BACKLOG](../../BACKLOG.md#round-73--the-expedition-redesign-gui-acceptance-pending).
