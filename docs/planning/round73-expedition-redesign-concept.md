# Round 73 concept: the Expedition redesign

Status: concept, written 2026-11-10 from the user's rulings of 2026-11-09 and 2026-11-10.
The round plan (`round73-plan.md`) follows from it; this file holds the design rules and
the reasons, the plan holds lanes, briefs, gates and the GUI checklist.

## 1. Why

The user's test of the three Expeditions (The Stilled Seam, The Second Shift, The Last
Mint): they work, but read as monotonous and forced. The same lanterns hang everywhere;
straight passages with evenly spaced torches feel linear; rooms are flat and offer few
dangers beyond the packs and traps.

The causes are built in, not a lane's taste:

- **Light on a grid.** All three sources hang lanterns on a staggered 6-node grid
  (`stilled_seam.py` `light()`, `last_mint.py` `lanterns()`, `second_shift.py`) and put a
  torch every 3 nodes on every wall (`shaping.py` `wall_lights`, `last_mint.py`
  `wall_torches`).
- **The light proof demands it.** Light 4 or more at eye height on every floor cell and
  6 or more on 90 % of them (`LIGHT_MIN, LIGHT_USUAL, USUAL_SHARE = 4, 6, 0.9` in
  `tools/r71_l20`, `tools/r72_shift`, `tools/r72_mint`). A dark stretch fails it.
- **Passages are axis-aligned rectangles** (`PASSAGES` in every source).
- **Floors are flat** by the Round 72 ruling (round72-plan.md §2.9: no step, no dais).
  This concept replaces that ruling with the stairs rule of §2.

So the redesign changes the shared helpers and the proofs first, then the templates.
New rules alone would reproduce the grid.

## 2. The user's rulings

2026-11-09:

- **More variety** in rooms, passages and light placement, across all three Expeditions.
- **Darker passage stretches** are wanted; they make the place eerie.
- **Lava from the walls** in a few places, as an added danger.
- **A few critters** for immersion; **mossy cobblestone** in passages; **a few underground
  plants** here and there.
- **Floor relief by stairs only.** Rooms and passages may change height, and every
  height change is made by stairs: normal, inner and outer. All height changes are
  smooth, and navigation stays a question of x and z only. This replaces Round 72's
  "floors stay flat"; Round 72's "walls and ceilings irregular in y" stays.
- **Process:** this concept first, then one implementing agent per Expedition.

2026-11-10:

- **Boss rooms may have relief too.** This replaces Round 72's "no dais".
- **Dark stretches may be fully black (light 0),** but only where the next light is in
  line of sight: no dark labyrinths. A player in the dark always sees where to go.
- **The ambush stretch** (§4.5): a longer, fully dark passage stretch with the next
  light in sight at its end. In its middle lies an invisible floor trap that fires once
  per run, never rearms and never becomes visible. It spawns a small pack, about half a
  room pack, from alcoves in the passage walls beside it. It spans the passage's full
  width, so it cannot be walked round, and lies in the fully dark part. "A little unfair,
  but exactly that makes the game exciting."
- **Critters are real mob entities;** in addition, **particle effects** that fit each
  Expedition's setting, here and there.
- **Models:** Opus implements and reviews every lane of this round; no Astra lane.
- **Coordinator defaults the user accepted** (2026-11-10): after a wipe the ambush pack
  behaves like every pack (healed, back to its alcoves, waiting there); ambush mobs are
  melee only; an Expedition has two dark ambush candidates and a run arms one of them; the
  only cue at the trigger is a faint dust burst from the alcoves.

2026-11-10, after the first draft:

- **Lava falls may be a danger in a fight.** They need no distance from the fighting
  areas: players have to plan for the packs' knockback and manage a pack so that it does
  not push them into the lava. **Mobs walk round lava:** a mob never walks into it by
  itself.
- **Every mob and boss of an Expedition is immune to lava.** A mob pushed into lava by a
  player loses nothing; the danger is the players' alone. (It still never walks in by
  itself.)
- **Height maps must not look even.** Deeper pits and higher rises are allowed and
  wanted, as long as neighbouring cells differ by one at most (§4.1).

## 3. What stays

The redesign changes shape, relief, light, dressing and hazards. These are contracts and
stay as they are unless a lane reports a reason and the coordinator agrees:

- The catalogue rows, box size, slot grid and template format version (§6.2 adds lines,
  it keeps version 1 readable).
- Per Expedition: the room order and route, every pack (room, mobs, counts, tiers), the
  boss and its envelope's meaning, the ore and gem places, the reward door, the chest,
  the waystones and arrival, the Round 72 traps (groups, picks, periods), The Last Mint's
  lake, lava pillars and press, The Second Shift's sign.
- Positions may move where the new shape needs it, inside their room, with every proof
  still holding.
- Round 72's room rules: rooms are not a row of rectangles; not every room is irregular
  (a cuboid room now and then reads as meant); packs cannot be walked round; free height
  over every floor cell; no perches off the floor (`proofs.lua`), with §4.1's stairs as
  floor, not as perches.

## 4. Design rules

Each rule is written so a proof can check it (§7). Numbers are rough targets where they
say "about"; the proofs check the hard ones only.

### 4.1 Floor relief: stairs only

The floor is a **height map**: every walkable column (x, z) has one floor height h(x, z),
the y of its first air cell. On top of that:

1. **One walking surface per column.** No bridge, gallery, ledge or floor above a floor.
2. **Neighbours differ by at most 1**, and where they differ, the higher cell holds a
   stair facing the lower one (`stairs:stair_*`); at an outer corner of a raised area an
   outer stair, at an inner corner an inner stair. Larger differences are made of several
   rings. Diagonal neighbours follow from the same rule; a full block never stands as a
   one-node step.
3. **No ridge or trench one node wide:** every region of one height is at least two nodes
   wide in both directions, so the stair shapes always fit.
4. **Free height** is measured from the local floor: at least the Round 72 free height,
   and at least the tallest mob of the Expedition plus one node, over every walking cell
   and every stair.
5. **Floor traps** (Round 72's and the ambush) lie on flat cells: every cell of the trap
   and its neighbours at one height. **Wall traps** take their muzzle height from the
   local floor.
6. **Relief and the packs.** A pit or a raised area can hide a player from a pack. The
   "cannot be walked round" proof uses the real eye height of each cell (floor plus
   eye offset) and the real sight through stairs. In pack rooms relief belongs mostly at
   the edges, or where a pack still sees across it.
7. **Boss rooms** may have relief (a sunken arena with a stair ring, terraces). The boss
   floor fill (`grug_mobs/boss_floor.lua`) already walks steps; the envelope places stay.
8. **Materials:** only existing stair sets (31 materials, among them stone, cobble,
   mossycobble, stonebrick, stone_block, obsidianbrick, wood, pine_wood). A room whose
   floor material has no stair set uses a fitting one at its edges (The Last Mint's basalt
   and slate floors, for example, with obsidianbrick or stonebrick). A new stair set is a
   question to the coordinator, not a lane's own decision.
9. **Depth:** the hull stays closed; a pit leaves at least two solid layers above the
   template's bottom (The Stilled Seam's first air is at y 5, The Second Shift's at 8,
   The Last Mint's at 32 over its lake). A rise lowers the free height above it, so the
   ceiling follows the floor where it climbs.
10. **Uneven on purpose (user, 2026-11-10).** A room's height map must not look even:
    no single raised square in the middle, no concentric rings of equal width, no
    repeated pattern. Deeper pits and higher rises are wanted, several levels where the
    box and the ceiling allow, with irregular outlines, uneven slopes (a long gentle run
    on one side, a short steep one on the other) and more than one feature in a larger
    room. Rule 2 is the only limit on steepness. Some rooms stay flat or nearly flat on
    purpose, in the same way some rooms stay cuboid.

Mobs step a full node (stepheight 1.1, `grug_nav` sees a stair as a one-node step);
players walk stairs without jumping (stepheight 0.6). No navigation change is expected;
the foundation lane confirms it in one engine run (§8).

### 4.2 Passages

- **No straight rectangle as the rule.** Passages follow polylines with bends and
  changing width (at least the Round 72 widths: six nodes clear in The Stilled Seam's
  connecting tunnels), with relief by §4.1.
- **Along the way:** a few side niches or short dead ends with dressing, a widening
  without a pack, a stair run, a lower ceiling stretch. About one feature per 15–20 nodes
  of passage, none of them on a grid.
- **Straight is a choice:** the dark ambush candidates (§4.5) are long and nearly
  straight, which is what makes their end light visible. The contrast with the bent
  passages is intended.
- A passage niche never forms a second route around a pack room, a trap or an ambush
  zone.

### 4.3 Rooms

Each Expedition gets its own small set of **room types**, and its rooms do not repeat a
type next to each other. Starting points, adapted to each setting:

- a sunken floor with a stair ring (also an arena for a boss);
- terraces: two or three levels across the room;
- a collapse: a rubble ramp of stairs, a broken ceiling, fallen beams;
- a pillared hall with relief between the pillars;
- a deliberately square work room (Round 72's "cuboid on purpose");
- a lava fall as a room's centrepiece and main light (§4.6).

Dressing follows what happened in the room (a table where people worked, a cart where
ore was moved, bones where something died), not an even spread.

### 4.4 Light

Light comes from **things that belong there**: work places, doors, the ore, a lava fall,
candles on crates, a single lantern over a desk, a group of torches at a junction.
**No grid:** no light placed by a modulo of its coordinates, and no "every n nodes on every
wall" pass. The shared helper places light at authored points and by a seeded
irregular spread where a lane wants filler (§6.1).

Zones, checked at eye height (floor plus one):

| Zone | Rule |
|---|---|
| Pack rooms (every cell a pack fights on), boss room, Round 72 trap cells and their radius | at least 4 everywhere, at least 6 on about 90 % (today's numbers) |
| Arrival, store, waystones, the chest, the door | at least 6 |
| Everything else (passages, niches, rooms without a pack) | any light, also 0, as long as the line-of-sight rule holds |
| Ambush zone and its alcoves | exactly 0 |

**Line of sight:** from every floor cell below light 4, at least one light source node
is in sight from eye height, within about 32 nodes. A dark stretch is therefore a
nearly straight passage with a light at its end, never a maze.

A torch gives light 12 and loses one per node, so a stretch of light 0 between two
torches needs about 25 nodes of passage plus the dark part itself. A dimmer light at the
end (a candle cluster behind a corner, ember moss, a lava glow further off) makes it
shorter.

### 4.5 The ambush stretch

Per Expedition **two candidates**, each a long, nearly straight passage stretch; a run
arms one of them at random when it is ready (the Round 72 `pick` mechanism, pick 1 of
2). The Stilled Seam may have one candidate if its route has no room for two; its lane
reports that.

- **Darkness:** the zone, its alcoves and a few nodes on either side are at light 0;
  the next light at the far end is in sight from the zone (§4.4).
- **The zone** spans the passage's full width, wall to wall, and is about 2–3 nodes deep
  along the passage. Every walk from the start to the end of the Expedition crosses it:
  with its cells removed, the floor falls apart into the part before and the part after.
  Its floor is flat (§4.1.5).
- **The trigger:** a living player of the run who enters or crosses the zone, at any
  height, walking, sprinting, jumping or with a movement skill. A respawn, Return Home,
  waystone travel and the entry teleport never trigger it.
- **Once per run:** it fires once and is gone. No warning ring, no mark node, no
  rearm, no damage of its own. A wipe does not rearm it.
- **The cue:** a faint dust burst from the alcoves as the mobs appear (particles with a
  low glow, so they show in the dark). No sound unless the user picks one on a listening
  page.
- **Alcoves:** recesses in the passage walls beside the zone, on one or both sides. Each
  alcove fits the collision box of the largest mob it spawns, with its head room, on a
  flat floor that is part of the floor height map and joins the passage floor directly.
  Alcoves are dark (light 0) and form no way around the zone.
- **The pack:** spawned at the moment of the trigger, never earlier, so no name tag or
  health bar can give it away in the dark. It engages at once. About half a room pack of
  that Expedition by its balance model: normal tier only, no elite, **melee only**
  (no `dogshoot` mobs: shots from the black would be invisible damage). Its mobs come from
  the Expedition's own roster. Its markers are authored like every encounter.
- **After a wipe** it is a pack like any other: healed, back to its alcoves, waiting
  there, and from then on it shows. What the party killed stays dead.
- **Placement:** outside every room pack's notice range, so it never pulls a room pack
  in; no Round 72 trap in the same dark stretch; not in a pack room or the boss room.
- **Rewards and gates:** none of their own. The door and the chest still open on the
  boss alone.

### 4.6 Lava falls

- **One to three per Expedition** (The Last Mint, with its lake, at most three more).
- **Shape:** a source in a wall niche above head height, a falling column in a recess of
  the wall, a small basin at its foot below the local floor. The lava stays inside the
  recess and the basin; no lava cell is a walking cell.
- **Static:** every slot's box is held by `grug_core.register_lava_hold`
  (`lava_guard.lua`): nothing flows in or out. The template writes the whole fall, the
  flowing cells with their levels included. Whether written flowing lava stays exactly as
  written under the hold is checked once in the engine by the foundation lane (§8).
- **The danger** is stepping in, or being pushed in: the basin lies beside the floor,
  also in a pack room's fighting area and in a boss room (user, 2026-11-10). A pack's
  hits push level (`packs.lua` `calculate_knockback`); players have to plan for that and
  keep a pack from driving them into the lava. That is the point, not a defect.
- **Mobs walk round lava, always.** No mob of an Expedition steps into a lava cell by
  itself: not on a path, not in the close chase where it walks straight at its target,
  not when it wanders or returns home. `grug_nav` already treats damaging cells as
  neither open nor ground (`grug_nav.lua` `cell`), and the walk-edge probe of mobs_redo
  keeps lava a boundary even for a mob immune to it (the Round 34 F1 patch in
  `mobs/api.lua`). The foundation lane confirms that the paths outside `grug_nav` (the
  direct chase, the pack's home return, a spawn spot) hold this with lava immunity on,
  and closes any that do not.
- **Lava immunity (user, 2026-11-10):** every mob of an Expedition, bosses, critters and
  ambush packs included, takes no lava damage (`lava_damage` 0), wherever it ends up.
  Only Expedition mobs (`_grug_expedition`); the open world is unchanged. It is set where
  every Expedition mob is made or activated (`packs.lua` spawn, and again on activation,
  since `lava_damage` comes from the definition), not per mob definition. A mob that
  ends up in lava walks out as it chases; a boss in a basin stays inside its room's
  rules (the lane checks that a basin cell inside the envelope does not count as "no
  way" for the boss reset).
- **Fairness:** a basin is visible and lit by its own glow; it is never hidden in the
  dark, never in an ambush stretch, and never directly at the mouth of a passage or the
  foot of a stair run, where a player arrives without looking.
- **Light:** a lava fall is a light source (13) and replaces lanterns near it; its glow
  counts for the zone rules.
- No fire spreads: the game has no fire mod. Wood near lava is fine.

### 4.7 Surface dressing

- **Mossy cobblestone** in passages and older rooms, in patches, also as stairs
  (`stairs:stair_*_mossycobble`). Damp places: near lava falls none, near old water
  stains and low ceilings more.
- **Plants and litter:** `grug_nodes:moss_carpet`, `lichen_carpet`, `lichen_carpet_b`,
  hanging moss, cobwebs in high corners, bones, skulls. **On walking cells only
  non-walkable nodes**: a walkable decoration raises the floor by one node for
  navigation and breaks §4.1.
- **No gathering sources** (`grug_mapgen:*_source`, `grug_gathering:*`) and no crops:
  they can be harvested, which would be loot outside the chest.
- Cobwebs not on walking cells.
- A few, in clusters, not spread evenly.

### 4.8 Critters and particles

**Critters** are real mobs of the existing critter tier (`levels.lua`, level 1, 1 HP):
`grug_mobs:cave_bat` (flies: high rooms), `grug_mobs:cave_crawler`, `grug_mobs:bone_weevil`
(niches, side rooms). About 3–6 per Expedition.

- Authored markers with a new encounter tier `critter`, placed when the run is ready (or
  when a player comes near, like a room), never part of a pack, never a gate, never in
  the pack or sight proofs.
- Inside an Expedition they drop nothing, give no credit, and attacking one does not
  pull a pack or start a fight with one.
- They are not rearmed after a wipe, and none spawn naturally.

**Particles** fit the setting: dripping water and dust motes in The Stilled Seam; ash and
paper scraps in The Second Shift; embers and sparks at The Last Mint's lava. Rules:

- Spawners per run, sent only to that run's players inside, running only while one of
  them is inside.
- The whole Expedition stays at a few hundred live particles at most (the web budget:
  hundreds, never thousands).
- Placed at authored points (a crack, a lava fall, a desk), not as an even fog.

## 5. Each Expedition's direction

The lanes design within §4; these are starting points, not plans.

- **The Stilled Seam (20–69, three players):** an abandoned mine, oldest and roughest.
  Most moss and lichen, timber supports, collapses with rubble stairs, dripping water,
  bats. Its ambush in a disused haulage drift. Flintback's court may become a sunken
  arena.
- **The Second Shift (40–69, four players):** a working mine still keeping its books.
  Order gone sour: tidy desks, rails, boarded cuts, ledgers' paper in the air. Terraced
  marking floors, a stepped wage hall. Little moss, cobwebs on the office side. Its
  ambush with the miners (zombies), not the archers.
- **The Last Mint (60–69, four players):** a forge-mint over a lava lake. Masonry vaults,
  basalt, metal. The lava falls belong here most; embers and heat. Terraces in the
  workshops, Duewarden's hall with a raised ring or a sunken floor. Its ambush with Lava
  Seeps (melee), not the Ember Wisps (they shoot).

## 6. Technical changes

### 6.1 Shared helpers (`tools/expedition_templates/`)

- **Relief:** from a height map per room or passage, write the floor and stair nodes
  with the right `param2`, normal, inner and outer, in a chosen stair material, and
  refuse a height map that breaks §4.1 (difference above 1, a one-node ridge, a column
  with two surfaces). One helper for all three sources, so no lane derives stair
  orientations itself.
- **Passages:** carve a polyline with a width profile and relief; niches.
- **Light:** place sources at authored points; an optional seeded irregular spread
  (minimum spacing, no coordinate modulo). `wall_lights` and the lantern grids go.
- **Dressing:** seeded scatter of moss, carpets and litter by a density map and the
  walkability rule of §4.7.
- **Lava fall:** a niche, a column and a basin, written whole.
- **Ambush:** the zone, its alcoves and the markers, with the light-0 margin.
- `preview.py` draws relief (height shading), light zones and ambush zones.

### 6.2 Template format (`docs/technical/expedition-template-format.md`)

Version 1 stays; new lines (exact syntax is the foundation lane's, this is the content):

- an **ambush** line: group, pick, the room name of its markers, the zone's corners and
  floor y; `encounter` lines with that room name are its markers and are never placed by
  proximity;
- encounter tier **`critter`**;
- a **particles** line: a point or small box, a style name from a fixed list, a density.

`template.lua` and `template.py` read and check them; a malformed line still stops the
server at load.

### 6.3 Game code (`mods/PLAYER/grug_expeditions/`)

- `traps.lua`: the ambush kind (§4.5): chosen with the other groups at readiness,
  trigger by zone entry or crossing, once, no mark, no ring; it hands its room to the
  encounters.
- `encounters.lua`: rooms that wait for a trigger instead of proximity; the `critter`
  tier outside the pack logic; the pack engages the triggering player at once.
- A small particles module (or a part of an existing one): spawners per run from the
  template's lines, only to the run's players, removed at the run's end.
- `docs/design/expeditions.md` §7, §8 and "Traps", and §13–§15 per Expedition, follow the
  new rules.

## 7. Proofs

`tools/expedition_templates/proofs.lua` becomes the one shared proof for every template,
with the floor as a height map instead of one `F`. It checks, on the written file:

1. **Height map:** one surface per column, neighbours within 1, stairs at every change
   facing the right way (inner and outer at corners), no one-node ridge, the hull
   closed.
2. **Free height** over every walking cell from its local floor (§4.1.4).
3. **No perches:** Round 72's rule, with stairs as floor.
4. **Walkable dressing:** no walkable node on a walking cell except the floor and the
   stairs; no gathering source or crop anywhere.
5. **Route:** every room reachable from arrival over the height map; the door closes the
   way to the chest as today.
6. **Packs cannot be walked round** and **coverage**, with real eye heights over relief.
7. **Light zones** (§4.4) and **line of sight** to a light from every cell below 4.
8. **Ambush:** zone at light 0 with its alcoves; the zone cuts the route (removing its
   cells separates start and end); flat floor; alcoves fit their mobs and join the
   floor; outside every room pack's notice range; markers only melee, normal tier;
   no Round 72 trap in its dark stretch.
9. **Lava falls:** no lava on a walking cell; none in an ambush stretch or at a passage
   mouth or a stair foot; the fall closed except to its own recess and basin.
   **Height maps** (§4.1.10) are not checked by a proof; the previews and the review
   judge them.
10. **Traps:** Round 72's checks with the local floor; floor traps on flat cells.
11. **Particles:** total configured density within the budget.

The three fixtures (`tools/r71_l20`, `tools/r72_shift`, `tools/r72_mint`) keep what is
specific to their Expedition and call the shared proof for the rest; their own copies of
the light and sight checks go.

## 8. Lanes and order

Every lane is Opus (user, 2026-11-10); every lane gets an independent Opus review.

1. **FOUNDATION**, alone, first: §6.1 helpers, §6.2 format, §6.3 game code, §7 shared
   proof, the test vault as the format's smallest example (an ambush, a critter, a
   lava fall, a few stairs), and one engine run that confirms: mobs and players walk the
   stairs, inner and outer included; written flowing lava stays as written under the
   hold; a pack chasing a player who stands at a basin's edge never steps into the lava,
   with lava immunity on; a mob pushed into a basin takes no damage and walks out; the ambush fires once, from every way across its zone, and not on respawn or
   travel; critters stay out of combat and drop nothing. The three real templates stay
   as they are in this lane, and its proof must pass on them where the new rules do not
   apply yet (or report which rules they fail, which is expected).
2. **SEAM, SHIFT, MINT**, in parallel after FOUNDATION merges: one lane per Expedition,
   only its source, its fixture and its section of `docs/design/expeditions.md`. Each
   delivers previews (`preview.py`) of every room and passage, and its balance model's
   ambush numbers.
3. **Round end:** the full fixture run once (coordinator), the engine runs for the
   three Expeditions as few as Round 72's, the status step, the GUI checklist.

**Release classification, expected:** compatible, no map reset. Templates are written
anew at each preparation, and a restart ends every run. The coordinator confirms it at
the round's end.

**The user's look:** previews of each Expedition before the round end, so the user can
correct look and feel (the user's iteration style: a first version by feel, the user
proposes fixes).

## 9. Open points for the plan

- The exact ambush strength per Expedition comes from the balance models (lanes), the
  coordinator checks it against "about half a room pack".
- The particle styles per Expedition are proposed by the lanes with a short description;
  the user sees them in the GUI test.
- Whether a critter's 10 XP inside an Expedition is worth stripping (they die in one hit
  anyway) is the foundation lane's call to report, default: no XP inside an Expedition.
