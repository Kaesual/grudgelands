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
  quest, king, waypoint) that runtime mods read through one registry, see
  [wp13-npc-sockets-contract.md](../research/wp13-npc-sockets-contract.md).
- Every start receives a first NPC roster: two gate guards and one patrol,
  the race's own vendor, a few flair NPCs at doors, benches and work areas,
  and a quest-giver shell with a placeholder line. None of this adds quest,
  storage or profession services. Since 2026-09-15 a start also publishes
  three **spare** standing spots that nobody lives on (below).
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
two traders stand on the blueprint's own vendor sockets; the five capitals whose
cores have not been built yet keep their fixed vendor offsets until they are.

Shipped behaviour of that first roster: each start's nine NPCs are placed once
its area is prepared at server start, from the sockets alone, and stay for the
life of the world. Two faction guards hold their authored gate posts, returning
to them and facing their authored direction whenever they are not fighting, and
one more guard walks the authored five-waypoint loop; they take their level from
the guard field and their targeting is unchanged, so the faction veto above is
still the single rule. Four flair villagers occupy the idle spots, amble between
them at walking pace, stand facing each spot and answer a right-click with one
short race-flavoured line; the race's own vendor stands on the vendor socket and
trades exactly as at a capital; the quest shell carries a nametag and one
placeholder answer. Only guards are mortal: a killed one leaves its post empty
and the settlement fills that one slot again after three to six minutes, the
same respawn-slot rhythm outposts use.

Decided 2026-09-15 after the first NPC playtest, and part of that behaviour:

- **A settlement holds exactly its roster.** A slot is occupied by the NPC that
  is booked on it, wherever in the settlement that NPC currently stands, and a
  second one on the same slot is removed. An NPC away from its post is never a
  reason to place another.
- **People are named after their settlement**, not after their race: a
  capital's flair NPCs are its own citizens and elders, the six starts keep
  their authored names.
- **A villager at a doorstep faces the street**, and villagers walk — they do
  not jump. One dwells 20 to 60 seconds at a spot, then walks to another spot of
  the same composition; a spot it cannot reach is given up for another.
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
