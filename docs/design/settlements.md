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

The other five starts, all capitals and the rest of WP13 remain separate
increments. The first settlement receives focused visual and walkability
playtests before its architecture is extended to other places.

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

- The server prepares all six start areas at startup: it emerges each start's
  128 × 128 build envelope (not its blend ring) once, at most two at a time,
  and reports one log line per completed start plus one summary line.
- Character creation's final teleport waits until every one of the six starts
  is ready, not only the player's own, and shows the waiting player the
  prepared-count progress while it waits.
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
  **workplaces**, and a quest-giver shell with a placeholder line. Since
  2026-09-15 a start also publishes three **spare** standing spots that nobody
  lives on (below).
- **A settlement offers no quest and no storage services**, and a vendor is
  the only trade there is. Since playtest round 3 a settlement may hold a
  PROFESSION vendor -- butcher, smith, fishmonger, baker, tailor, and since
  the wave-2 capitals also mason, brewer, bowyer, herbalist, armourer, tanner
  and embalmer -- but that is a shop with its own shelf, not the
  crafting-profession system of [professions.md](professions.md): nothing
  there is taught, levelled or unlocked in a settlement.
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
crossing water as a causeway, with a lamp line every eight nodes that survives
the mapchunk borders. Where an avenue crosses the ring street the avenue runs
through and the side street yields, and no lamp stands in the crossing road.

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

A capital's buildings are **not built until somebody goes there**: they are
constructed the first time a mapchunk touches the capital's envelope and
released again once the map has moved away, so six capitals never sit in memory
at once. The six starts stay built from the start, because the spawn depends on
them.

**NPCs arrive with the place, not with the server.** The six starts are prepared
and populated at startup; a capital is not preloaded, so its roster is placed
the first time its area is actually emerged or loaded, and its outlying district
plots fill in as a player walks up to them. A capital carries several patrol
loops — a city ring, one per gate tower and one per district — and each loop
gets its own guard,
walking that loop and no other; its flair villagers keep to the composition they
belong to, the core or their own plot, instead of wandering the whole city. Its
two traders stand on the blueprint's own vendor sockets; the capitals whose
cores have not been built yet keep their fixed vendor offsets until they are.

**Walled capitals.** Decided 2026-09-15 with the second capital, Dur Brannoc.
Three of the six are walled (Dur Brannoc, Nhal Veyr, Gor Drazhak) and three are
open. A curtain wall runs along all four edges of the capital's 512 envelope,
with a turret every 64 nodes, a turret at each corner and a gatehouse on each of
the four gate axes, and the avenue runs through its gate passage. It has no
fixed cells either: like the avenues, it is computed per mapchunk from the
ground the map actually has, so it follows the terraces instead of cutting
through them — its walk steps down half a node at a time and its masonry starts
under each column's own ground, which is what makes a wall on stepped terrain
have no gap in it. The wall carries no NPCs of its own; a walled capital's
garrison is the four gatehouses of its civic core, exactly as an open one's is.
Where a capital's avenue has to leave the ground — the blend from the flat civic
core to the terraces can fall faster than a road may descend — the raised
stretch carries a masonry rail on both kerbs.

**Between the plots.** Decided 2026-09-15 with the round-3 playtest: a quarter
of nine buildings in a 512 envelope is empty, so each quarter carries four more
pieces of open ground beside its nine plots — a field, a pasture, a yard and a
green, at four deliberately different sizes. They are plots like any other, with
their own reference column and their own foundation skirt, because ground laid
at the core's height across a terrace is ground with a step through it, and they
travel with their district when the seed moves it. What stands on them is the
district's trade: a garrison musters and chops wood on its ground, a residential
quarter grows and grazes on its.

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

**Open capitals, and the one with a lake in it.** Decided 2026-09-15 with the
third capital, Kezamba. Two of the six have no wall at all — Lethariel and
Kezamba — and what an open capital has where a walled one has a gatehouse is a
**threshold** at each of its four gate points: two carved posts with a beam
across the road and a light on each of them, so a traveller arriving on the
long-distance route can see that they have arrived somewhere. Like the wall and
the avenues it has no fixed cells and is computed from the ground the map has.

Kezamba is also the one capital whose **civic core is not flat**, and that is
the map's doing rather than the city's: a deep cenote fills its north-eastern
quarter and reaches into the core itself, and one narrow gorge cuts into the pad
from the south-west. The city is built round both. Its two great avenues leave
the crossing and become **timber boardwalks on basalt piers** the moment they
reach the water; its moot house stands on stilts half on the bank and half over
the lake, with a flight up to it from the shore; a quay follows the waterline,
its anglers fish the cenote itself and the fishmonger keeps a counter behind
them; and the gorge is railed along its rim and crossed by one plank bridge. The
lake is never filled in and never floored over: the ground the city lays stops
at the waterline.

Where a capital's four districts cannot be four quarters — because the water
takes one of them in every world — the districts are **pinned to the ground that
exists** instead of being shuffled between the quarters by the world seed, and
the count per district follows the ground: Kezamba's are nine, nine, eleven and
seven plots, thirty-six in all, with the same sixteen fill dressings every
capital has.

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
- **A peaceful NPC's nametag is culled like a guard's.** Villagers, elders and
  vendors used to render their name out to the engine's whole object-send
  range, which made a busy district a wall of floating text; they now use the
  25/30 m proximity gate the combat families already had.
