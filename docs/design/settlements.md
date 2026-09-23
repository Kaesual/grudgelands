# Settlements

## Hearthpine Vale: first start settlement

Decided 2026-09-13. The first WP13 structure increment is the **dwarf start
in Hearthpine Vale** (`elandor_hearthpine_vale`, `anchor_001`). Its identity is
an **inhabited craft settlement with a small guardpost**. Hearthpine Vale is
the zone name; this increment introduces no separate town name.

- Stone foundations, pine timber, pitched roofs and warm lighting establish
  a sheltered, working settlement. A prominent workshop, smaller homes and
  a timber workyard surround a compact arrival space. Furniture, stacked
  materials and usable interiors convey habitation.
- The guardpost marks the road out without turning the settlement into a
  fortress. Entrances, the arrival space and the road remain easy to read
  and walk through. The existing dwarf spawn is inside that arrival space.
- Buildings occupy distinct plots with open ground between them. Paving is
  limited to the arrival space and connecting paths. The first increment
  uses WP40's terrain-fitted start pad; broader terracing and varied civic
  terrain are later structure work.
- The existing start identity, road connection, 128 × 128 build envelope
  and ten-node protection apron follow [world_zones.md](world_zones.md) §12
  and [world.md](world.md) §2 R1. The apron makes the protected horizontal
  footprint 148 × 148. Existing depth and indirect-mutation rules apply.
- This increment supplies architecture and environmental dressing. Furniture
  does not introduce profession, storage, quest, innkeeper or travel services.
  The functional systems and their NPCs retain their own work packages.

The first settlement received focused visual and walkability playtests before
its architecture was extended to other places. That extension has since
happened: the other five starts landed on 2026-09-14 and all six capitals by
2026-09-16 ("Capitals in the world" below). The remaining village, outpost and
camp roster is tracked in BACKLOG WP13. The six kings and their
royal guards are already delivered; their encounter rules live in `world.md`
and `world_zones.md`.

## Hearthpine expansion and ground integration

Decided 2026-09-14 after the first native playtest.

- Hearthpine has nine buildings: the forge, four homes, timber workyard,
  storage building, community hall and small gate watchpost. The storage
  building and community hall are scenery with walkable interiors, not new
  services. Building orientations, proportions and porches vary.
- Pine litter dominates the open ground, with modest dirt and grass patches,
  a few pine trees and undergrowth. Paving serves the arrival plaza, paths and
  work areas. Benches, timber stacks and small masonry details occupy the
  spaces between plots. Warm exterior lights mark the main route and entries.
- The watchpost roof sits on continuous masonry bearings; thin slabs serve
  the projecting eaves without leaving a gap above the walls.
- All six start pads derive their shared surface/spawn/road-pin height from
  81 deterministic natural-terrain samples in a 9 × 9 grid spanning the
  128-node build envelope. The lower median minimizes sampled absolute
  earthwork. Clamp it to the common eight-node cut/fill interval when that
  interval exists, and keep the surface above water. If those constraints
  cannot all hold, use the dry median and report the actual sample excess.
  This is a sampled fitting rule, not a universal bound on every terrain node.
- Dry start-fitting ground and blending slopes retain their biome surface
  materials. Authored roads and other functional surfaces retain precedence.
  Individual building terraces and varied civic ground remain later work.

## Start preparation and start-area safety

Decided 2026-09-14 after the round-A playtest.

- Preparation follows [world_preparation.md](world_preparation.md): the fresh
  world selects one persistent starts-only or full-world mode, with one aligned
  mapchunk request in flight and resumable successful-prefix progress.
- In starts-only mode, all six required start envelopes must be ready; full
  mode satisfies the same readiness seam when its surface plan completes.
  Preparation precedes faction/race/class creation. The waiting UI, stasis and
  shutdown/resume behavior follow the same shared preparation contract.
- No mob that can attack players spawns inside a start footprint — the
  128-node build envelope plus its 10-node apron, the 148 × 148 hard-protected
  square of [world.md](world.md) §2 R1. Passive critters and prey animals keep
  spawning there, and the undead night truce is unchanged.

## Start surroundings

Decided 2026-09-14 after the round-B playtest. These are terrain rules; the
blueprints are unchanged by them.

- The road reaches a start **on its gate axis**. The last stretch before the
  gate runs straight along the blueprint's `main_street` axis, centred on it,
  at the gate street's width, and meets the gate passage exactly; the bend back
  to the route's ordinary course happens outside the build envelope. Which side
  the gate faces follows the blueprint's own `main_street` landmark and the
  authored gate station, never an assumed sign. That stretch is part of the
  route's authored geometry, so it keeps the claim exclusion, the clear corridor
  and every other rule an ordinary road carries ([world.md](world.md) §2 R1).
- **Biome decorations grow in the blend ring.** Trees, plants and ground cover
  are generated normally in the 256-node blend ring outside the 148-node
  protected footprint, so a start does not sit in a cleared square. The build
  envelope, the road surfaces and every authored volume stay clear, and the
  blend ring's cover matches the surrounding biome.
- **Vegetation also grows in the protection apron, behind a jagged edge.**
  Decided 2026-09-15 after the first GUI playtest: hard protection restricts
  building, not growing, so the ten-node apron carries the same biome cover as
  the ring outside it, starting at a seed-deterministic jittered boundary a few
  nodes out from the build envelope rather than on a straight line. The
  128-node build envelope, the road surfaces and every authored volume stay
  host-free, and the same world seed always produces the same outline. That
  cover stands on hard-protected ground, so a player cannot fell it.
- The transition from the fitted pad to the natural terrain carries a
  **seed-deterministic outward jitter of a few nodes**, so its outline is not an
  exact square. The same world seed always produces the same outline. The
  128-node envelope's surface height, the spawn height, the road pins and every
  blueprint cell are unaffected by it.

## Settlement NPCs and guard targeting

Decided 2026-09-14.

- Guards attack enemy-faction players everywhere, in starts as at outposts
  and capitals; the faction veto stays the one rule. They ignore own-faction
  and factionless players and fight hostile mobs.
- Blueprints export named sockets (guard post, patrol loop, vendor, idle,
  work, quest, king, waypoint) that runtime mods read through one registry,
  see [wp13-npc-sockets-contract.md](../research/wp13-npc-sockets-contract.md).
- Every start receives a first NPC roster: two gate guards and one patrol,
  the race's own vendor, residents at doors, benches, work areas and
  **workplaces**, and a quest giver following `quests.md`. A start also
  publishes three **spare** standing spots that nobody lives on (below).
- Quest services follow `quests.md`. A settlement offers no general storage
  services; trade shops follow the vendor contract. Since playtest round 3 a settlement may hold a
  PROFESSION vendor -- butcher, smith, fishmonger, baker, tailor, and since
  the wave-2 capitals also mason, brewer, bowyer, herbalist, armourer, tanner
  and embalmer -- but that is a shop with its own shelf, not the
  crafting-profession system of [professions.md](professions.md). Dedicated
  capital trainers and public stations provide that separate system; a trade
  shop alone teaches or unlocks nothing.
- Race appearance (skin, visual-only stature) and visible armor and weapons
  are composed by one function for players and humanoid mobs, see
  [wp13-character-visuals-contract.md](../research/wp13-character-visuals-contract.md).

## Capitals in the world

Decided 2026-09-15 with the pilot capital, Highcourt.

A capital is not one blueprint but a civic core, a list of district plots and
the avenues between them, and the three reach the world in three different ways.
The **core** is anchor-relative like a start, flat on the fitted capital height,
and the guard banner the map already writes at the anchor stays where it is: the
core leaves that one cell alone. A **district plot** stands on terraced ground
and cannot be anchor-relative, so each plot names one reference column, the
server asks the final height of that column once per world session and projects
the whole plot from it; a foundation skirt carries the plot's perimeter six
nodes down and the plot clears its own airspace, and a plot whose ground falls
further than the skirt reaches is moved rather than propped. The **avenues** and
the ring street have no fixed cells at all: they are computed per mapchunk from
the ground the map actually has, climbing terraces half a node at a time and
crossing water as a bridge, with a lamp line every eight nodes that survives
the mapchunk borders. Where an avenue crosses the ring street the avenue runs
through and the side street yields, and no lamp stands in the crossing road.

**The civic-core boundary is protected.** Decided 2026-09-18 after playtest
round 10. Its hedge, parapet, bank or palisade is written after all structural
core content and later dressing may use only free cells: a house, orchard,
green, lore piece, martial piece or prop may meet the boundary but may not cut
it. Only the four authored thirteen-column gate or threshold bands stay open.
The boundary and its gates stand at radius 48, two nodes outside the earlier
radius 46. Each capital retains the actual asymmetric extent of its gatehouses;
projection bounds include every authored cell, and no ring column intersects a
building. Nhal Veyr's bars align with their wall on both axes.
A fitting attached to content displaced by the boundary is removed, and an
edge building faces inward so its door remains usable. The six forms of the
same rule are:

| Capital | Protected civic-core boundary |
| --- | --- |
| Highcourt | Three-course clipped hedge. |
| Dur Brannoc | Two-course masonry parapet; the four closed corner drums replace its corner columns. |
| Gor Drazhak | Two-course earth bank with alternating acacia stakes; closed timber corner towers replace its corner columns. |
| Nhal Veyr | Two-course dungeon-stone parapet with alternating bars; the four closed corner drums replace its corner columns. |
| Lethariel | Three-course silverwood hedge on every dry edge; the authored mere is the boundary where it reaches the north edge. |
| Kezamba | Three-course junglewood palisade on every dry edge; the authored cenote is the boundary where it reaches the north-east edge. |

**One street rule, for every street of every capital.** Decided 2026-09-16 with
playtest round 5 and shipped the same day
([wp13-street-geometry.md](../research/wp13-street-geometry.md)); it holds for
avenues, ring streets, district lanes, fill lanes and gate approaches alike.
A street's **cross profile is flat** — every lane of a run walks at one level,
and the run climbs at most one node per column. Where two streets cross, the
junction is a **square plateau on a single y**, computed identically by both
runs, so the approaches ramp up to it instead of meeting at a step. A street
column raised **three nodes or more** above its own ground carries the deck
course and **open air beneath it**, on pillars every eight columns under the
verges — a raised street is a viaduct, never a solid earth bank. And a street
that stands over water is a **bridge**: the deck one node clear of the surface,
nothing at or below the water line, piers on the verges and a planked, railed
walk over them, in the race's own palette. Lamps foot at the street's own
level, not at the ground of the column beside it.

**Capital service presentation (2026-09-20).** Each profession premise has
at least one readable protected exterior product frame/sign and one interior
fixed product stand/rack. Weaponsmith and Armorsmith retain separate identities
inside their shared forge; Alchemist, Tailor, Leatherworker, Woodcarver,
Goldsmith and Cooking each have their own representative products. Displays
have fixed identities, no mutable inventory, no collectible item entity and no
punch/take/drop path; current-version activation restores them deterministically.
Public stations, trainer access and street approaches remain clear.
The Leatherworker's exterior sign shows both leather and leather armor; the
interior display retains the armor. Capital service placement remains eligible
after the core unloads: loading any authored capital socket block establishes
current-world readiness, while each NPC waits for its own block to be loaded.

The shared outer stable is an open shelter with an earth floor, a one-node
fence and a flat roof supported by exactly six posts. It has no perimeter
walls. Four full-size racial mount displays stand behind the Riding Trainer;
authored bounded movement/rest regions preserve clearance from posts, roof,
fence, other displays and public access. Ground displays walk briefly and pause;
flying appearances remain grounded (`mounts.md` §1). Geometry is shared and
skinned by each capital's architectural palette.

The shared gatehouse upper-floor stair opening removes exactly one additional
obstructing block in the ascent direction. Treads, rise, passage, deck and room
dimensions are unchanged; there is no stair redesign or bespoke clearance test.

A capital has **four districts**, one in each of the quarters the four avenues
cut the envelope into: market and professions, martial and garrison, lore and
spiritual, residential and cultural. Each is nine plots on nine lots, and
**which district stands in which quarter is decided by the world seed**, so two
worlds put the same capital's garrison in different corners while one world is
always the same. The lots belong to the quarter, not to the district: any
district's plot fits any lot, because every lot is ground that has been checked
to be dry, level enough for the plot's foundation skirt and clear enough under
the plot's own roof. Each quarter carries one or two **lanes** between its rows
of plots, running back to the avenue the district is reached from; a lane is a
street like any other and is paved on whatever ground it finds. Guard posts
belong to the garrison district, the two traders to the core, and every district
keeps two spare standing spots its people may walk to.

Capital blueprint construction is lazy when map generation first touches its
envelope; mapchunk traversal may release cached construction data. Full-world
preparation can generate capitals before a player visits them. Starts-only
preparation covers the six start readiness envelopes instead.

**NPCs arrive when their authored blocks are loaded.** Current-world readiness
and per-socket loading govern roster placement, including outlying district
plots; preparation does not authorize an NPC in an unloaded block. A capital
carries several patrol loops — a city ring, one per gate tower and one per district — and each loop
gets its own guard,
walking that loop and no other; its flair villagers keep to the composition they
belong to, the core or their own plot, instead of wandering the whole city. Its
two traders stand on the blueprint's own vendor sockets; all six capitals
export those sockets.

**Walled capitals.** The user's ruling of 2026-09-17 fixes **four walled
capitals** — Highcourt, Dur Brannoc, Gor Drazhak and Nhal Veyr — and **two
open capitals**, Lethariel and Kezamba (the implementation provenance is
below, and in
[wp13-capitals-pois-contract.md](../research/wp13-capitals-pois-contract.md)
section 4). A curtain wall runs along all four edges of the capital's 512 envelope,
with a turret every 64 nodes, a turret at each corner and a gatehouse on each of
the four gate axes, and the avenue runs through its gate passage. It has no
fixed cells either: like the avenues, it is computed per mapchunk from the
ground the map actually has, so it follows the terraces instead of cutting
through them — its walk steps down half a node at a time and its masonry starts
under each column's own ground, which is what makes a wall on stepped terrain
have no gap in it. Where two sides meet at a corner turret the two runs
would each compute the walk from their own axis and land at different heights, so
each side is told where its corners are and both clamp them to the same datum:
the walk round the circuit has no step at a corner at all, on any world. The wall carries no NPCs of its own; a walled capital's
garrison is the four gatehouses of its civic core, exactly as an open one's is.
Where a capital's avenue has to leave the ground — the blend from the flat civic
core to the terraces can fall faster than a road may descend — the raised
stretch carries a masonry rail on both kerbs. And an avenue ARRIVES AT ITS GATE
at the height of the ground there, whatever the ground between does: it descends
inside the envelope as a stair of at most one node a column, cutting into the
hillside where it has to, so the long-distance road outside and the city street
inside meet level. A gate you have to jump into is not a gate.

**Between the plots.** Decided 2026-09-15 with the round-3 playtest: a quarter
of nine buildings in a 512 envelope is empty, so each quarter carries four more
pieces of open ground beside its nine plots — a field, a pasture, a yard and a
green, at four deliberately different sizes. They are plots like any other, with
their own reference column and their own foundation skirt, because ground laid
at the core's height across a terrace is ground with a step through it, and they
travel with their district when the seed moves it. What stands on them is the
district's trade: a garrison musters and chops wood on its ground, a residential
quarter grows and grazes on its. **And a field grows something of that race's
own** — decided 2026-09-16, playtest round 5 ("Fields in Kezamba grow 'Mossy
Stone'? That cannot be right"): where a race binds no crop of its own the fill
fell back to its plain ground node and a field was a rectangle of bare mud, so
the palette now carries a tilled crop and a planted bed, and a planter is cut
deep enough to have soil between its two kerbs rather than being all kerb
([wp13-kezamba.md](../research/wp13-kezamba.md)).

**The dwarf capital.** Decided 2026-09-15 with Dur Brannoc's four quarters. Its
citadel is stone block, its halls are pine under slate, and its city stands
ABOVE AND BELOW the ring of hillside the map blends from the flat civic core
down to the granite terraces — that band falls as much as forty-four nodes and
carries no building at all, so the four quarters begin further out than a
human capital's and the lanes that reach them are stair streets the whole way
down. The four quarters are the forge and its professions, the garrison, the
halls of record with the carvers' yard and the barrow terrace, and the terrace
houses with their alehouse and brewhouse. Its open ground is what a dwarf city
keeps: an ore court with a mine mouth cut into a rock face, charcoal clamps, a
slag yard, mushroom beds grown in the lee of the wall, goat pens and brewing
courts. Its trades are a smith, a mason, an armourer, an embalmer, a butcher, a
brewer and a baker, beside the two travelling traders every capital's core has.
**Open capitals, and the one that stands on a lake.** Decided 2026-09-15 with
the third capital, Lethariel. An open capital has no curtain: its envelope edge
is a planted belt — two clipped rows of its own wood with kept turf between
them, a standard every dozen nodes, a lantern every thirty-two and a thicker
grove at each corner — and each of its four gate points is a **threshold**:
three pairs of marble pillars carrying a lintel over the road, so you walk
through a way in rather than being let through a gate. The lintel is set from
the height the ROAD is walked at and not from the ground beside it, so it
always leaves a walker headroom. Like a wall it has no fixed cells and is
computed per mapchunk from the ground the map has, and where the belt reaches
water it simply stops, because the water already is an edge.

Lethariel also shows what happens when the map does not give a capital four
usable quarters. A lake lies inside its 512 envelope — it fills more than half
the north-east quarter and reaches into the civic core itself — so that quarter
carries three plots where the other three carry nine. The city is built round
it: the **lore and spiritual district is the mere precinct** and stands in that
quarter and nowhere else, the other three districts are still dealt out by the
world seed, the civic core stops at the water's edge and meets it with a marble
quay, and the north avenue crosses the lake as a causeway to a threshold on the
far shore.

**Not every wall is masonry.** Added 2026-09-15 with the third capital, Gor
Drazhak. What a walled capital has on its envelope edge is decided by the race
that built it: the dwarves, the humans and the undead raise a stone curtain,
and the orcs raise a **stake palisade on an earth rampart** -- a dug bank
thrown up round the whole city with a stockade of sharpened acacia on its outer
crest, a timber
fighting walk along the top, a log breastwork on the city side and a timber
tower every sixty-four nodes with a stake crown on it. It follows the terraces
and lets the avenue through its gates exactly as a curtain does, and it is the
same thing to walk on; it simply is not made of stone. Gor Drazhak's own civic
precinct repeats the section at a quarter of the height -- two courses of beaten
earth with a stake every other node -- so the city wall and the citadel wall
read as one piece of engineering.

**The orc capital's own shape.** Its roofs are flat decks behind crenellated
breastworks rather than ridges, which is what its skyline is recognised by from
a hundred nodes away; its civic buildings are banded red sandstone where its
dwellings are adobe; and its four quarters are a bazaar of five trades (a
butcher, a tanner, a brewer, an armourer and a smith, each standing at the work
he sells), a war yard round a sunken fighting arena, a quarter of bone halls
with a totem court, a burial barrow and a quarry face cut into the mesa, and a
warren of clan lodges round a cook court and a story fire. In front of the
warlord's hall stands a raised **fighting platform** with its own breastwork,
its own stair and two guard posts on it.

**Open capitals, and the one with a lake in it.** The split is the user's
ruling of 2026-09-17: Highcourt, Dur Brannoc, Gor Drazhak and Nhal Veyr are
walled; Lethariel and Kezamba are open. Everything below it — what an open
capital puts at its gate points, and how a capital with a lake in its core is
laid out — is the third capital's own lane, 2026-09-15/16, and is open to the
user's correction like any other design.

Two of the six have no wall at all — Lethariel and Kezamba — and what an open
capital has where a walled one has a gatehouse is a
**threshold** at each of its four gate points: two carved posts with a beam
across the road and a light on each of them, so a traveller arriving on the
long-distance route can see that they have arrived somewhere. Like the wall and
the avenues it has no fixed cells and is computed from the ground the map has.

Kezamba is also the one capital whose **civic core is not flat**, and that is
the map's doing rather than the city's: a deep cenote fills its north-eastern
quarter and reaches into the core itself. The city is built round it. Its two
great avenues leave the crossing and become **timber boardwalks on basalt piers**
the moment they reach the water; its moot house stands on stilts half on the bank
and half over the lake, with a flight up to it from the shore; a quay follows the
waterline, its anglers fish the cenote itself and the fishmonger keeps a counter
behind them. The lake is never filled in and never floored over: the ground the
city lays stops at the waterline.

For a while there was a second hole in that pad — a narrow gorge cutting in from
the south-west, which the city railed along the rim and crossed with one plank
bridge. It was a ROAD: a long-distance route grading its way across the civic
pad. Now that routes stop at a capital's gate points, the pad is whole, and the
bridge and the rail are gone with the gorge. The measurement that found it is
kept as a gate, because the next terrain change that cuts a capital's pad should
turn a light red rather than become part of the architecture.

Where a capital's four districts cannot be four quarters — because the water
takes one of them in every world — the districts are **pinned to the ground that
exists** instead of being shuffled between the quarters by the world seed, and
the count per district follows the ground: Kezamba's are nine, nine, eleven and
seven plots, thirty-six in all, with the same sixteen fill dressings every
capital has.

**Nhal Veyr, the raised necropolis.** Shipped 2026-09-15, the last of the wave-2
capitals to land and one of the four walled ones. It is the first capital whose FILL is not fields and
gardens: where Highcourt has crop fields, an orchard belt and a pond, the undead
capital has grave fields, bone yards, ruin closes and candle courts, and the
turf between its civic quarters is a burial ground with gravewood stands in it.
Its civic buildings are dungeon stone under a pale stone roof and everything a
citizen built is gravewood board; its own two parts, which no other capital has,
are a walk-in mausoleum on a stepped plinth and a candle court with an altar at
its centre. Its curtain wall, its four districts, its lot grids and its seeded
quadrant permutation are the mechanisms Dur Brannoc and Highcourt landed,
unchanged.

It is also the first capital to place the WAVE-2 activities of the NPC socket
contract: its residents mourn at grave markers, pray at candles, tend the
blight that grows over the graves, carve bone, brew wax, mine a quarry face,
spar in the drill yards and forage the vines on a yard wall. All six of its
profession vendors stand and trade: the embalmer and the herbalist, which the
first draft of this section recorded as having no entity, were registered with
the other five wave-2 kinds (`grug_traders/vendors.lua`, `stock.lua`), and the
embalmer's shelf is the undead capital's own trade.

Shipped behaviour of that first roster: each start's eleven NPCs are placed once
its area is prepared at server start, from the sockets alone, and stay for the
life of the world. Two faction guards hold their authored gate posts, returning
to them and facing their authored direction whenever they are not fighting, and
one more guard walks the authored five-waypoint loop; they take their level from
the guard field and their targeting is unchanged, so the faction veto above is
still the single rule. Six residents occupy the idle and work sockets (see the
80/20 rule below); the race's own vendor stands on the vendor socket and trades
exactly as at a capital; the quest shell carries a nametag and one placeholder
answer. Only guards are mortal: a killed one leaves its post empty and the
settlement fills that one slot again after three to six minutes, the same
respawn-slot rhythm outposts use.

Decided 2026-09-15 after the first NPC playtest, and part of that behaviour:

- **A settlement holds exactly its roster.** A slot is occupied by the NPC that
  is booked on it, wherever in the settlement that NPC currently stands, and a
  second one on the same slot is removed. An NPC away from its post is never a
  reason to place another.
- **People are named after their settlement**, not after their race: a
  capital's flair NPCs are its own citizens and elders, the six starts keep
  their authored names.
- **A villager at a doorstep faces the street**, and villagers walk — they do
  not jump. A walker dwells 20 to 60 seconds at a spot, then walks to another
  spot of the same composition; a spot it cannot reach is given up for another.
- **A guard that cannot reach its waypoint keeps patrolling anyway**: it paths
  around the obstacle, then takes the next waypoint, and only if it is still
  stuck and no player is within 48 nodes is it moved there outright.

Decided 2026-09-15 after the second NPC playtest (the first one's "hostile
creatures ignore settlement NPCs" is replaced by the first point here):

- **Hostiles and guards fight each other; non-combatants are never a target.**
  The watch and the world's monsters may each start a fight with the other, and
  a guard can lose one. What no mob in the world may ever acquire is a
  **non-combatant** — a villager, an elder or a vendor. They cancel every punch,
  so a fight with one can never end, which is exactly what the playtest saw: a
  boar standing in front of a village woman hitting her for as long as anyone
  watched. Guard versus guard stays off, across factions included.
- **An NPC standing at a door faces the street, whatever its role is.** The rule
  used to reach only the flair villagers, so every Village Elder and the
  Highcourt Elder stood with its back to the street.
- **A settlement offers more places to stand than it has people.** Besides the
  spots its NPCs live on, every settlement publishes a few **spare** ones —
  three per start, ten in Highcourt's core — that nobody is ever placed on and
  every villager of that composition may wander to. Without them a settlement's
  spots and its villagers are the same list, every destination is permanently
  occupied, and the amble is people trading doorsteps.

Decided 2026-09-15 after the third NPC playtest ("nobody does anything, and I
want lived-in settlements without paying for it in server load"):

- **Four residents in five work; one in five walks.** A resident on a **work**
  socket never leaves it: it faces the feature the socket names, plays that
  activity's animation and holds its tool — a smith at an anvil, a farmer in a
  field, a woodcutter at a tree, somebody sitting on a bench. Since the wave-2
  capitals the vocabulary also covers a miner at a rock face, a brewer at a
  cauldron, a carver at a totem, a mourner at a grave (still, head bowed), a
  pair sparring with the tier-1 sword and a forager at a bush. The split is
  decided by the placement engine and nothing about it is authored: among a
  settlement's resident sockets in authored order, every fifth `idle` one hosts
  a walker and everybody else stands still. A static resident keeps at most a
  rare short hop to a spare spot near it.
- **A walker's route is short.** Twenty nodes around its own socket, which is
  two to four destinations in a start rather than a march across the
  settlement. Where a settlement's spots are further apart than that, the
  walker takes the nearest ones anyway: a walker with one destination is a
  walker that never moves.
- **The load is the point.** Path-finding and animated meshes are what a
  settlement costs, not the head count. A static resident asks the pathfinder
  nothing at all, writes its animation once per change, and does nothing
  whatsoever while no player is within 24 nodes.
- **Profession vendors.** A district reads as lived in when the butcher's house
  has a butcher in it, so a `vendor` socket may name one of twelve professions —
  butcher, smith, fishmonger, baker, tailor, mason, brewer, bowyer, herbalist,
  armourer, tanner and embalmer. Each has a shelf of its own trade and serves
  everybody (no faction and no race restriction, and therefore no kinship
  discount); only the smith and the armourer also sell the equipment ladder.
  The six starts keep their single race vendor.
- **A peaceful NPC's nametag is culled like a guard's** (per-viewer mechanism
  adopted 2026-09-18). Villagers, elders and vendors use the same independent
  25 m show / 30 m hide carrier gate as combat families. A nearby player no
  longer exposes settlement names to a different, distant player.

## Round 15 regional POI composition

The existing six villages, six outposts and six bandit camps receive distinct
authored compositions, not just palette swaps of shared symmetric layouts.
Each has a dominant building, differently sized secondary forms, a readable
arrival, usable circulation, functional interiors and activity-specific scenery.
The guaranteed fitted cores remain 24×24 for villages/camps and 16×16 for
outposts; all buildings, roof overhangs and supports fit those cores. Existing
anchors, roads, protection rules and functional roots remain authoritative.
Each village gains one quest-giver socket `quest_local`; existing quest socket
identities remain stable. No new world anchors are part of this increment.

## Innkeepers (Round 17)

Each of the six start towns and six capitals contains one innkeeper using a
suitable existing building/socket. The twelve-entry shared registry supplies
terrain-resolved NPC and safe arrival positions. Binding, home return and death
respawn follow [home_travel.md](home_travel.md). No other V1 home points exist.
