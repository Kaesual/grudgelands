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
  and protected start town follow [world_zones.md](world_zones.md) §12 and
  [world.md](world.md) §2 R1. The start town (Round 22 D78) is the envelope
  plus a 12-node band round it with rounded corners. Existing depth and
  indirect-mutation rules apply.
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
  materials, except where the town's own ground reaches into the protected
  band ("The start town's surroundings" below). Authored roads and other functional surfaces retain precedence.
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
- No mob that can attack players spawns inside a start town — the 128-node
  build envelope plus its 12-node band with rounded corners, the
  hard-protected footprint of [world.md](world.md) §2 R1. Passive critters and prey animals keep
  spawning there, and the undead night truce is unchanged.

## Start surroundings

Decided 2026-09-14 after the round-B playtest. These are terrain rules; the
blueprints are unchanged by them.

- The road reaches a start **on its gate axis**. A short last stretch before
  the gate, roughly 16–32 nodes, runs along the blueprint's `main_street`
  axis, centred on it, at the gate street's width, and meets the gate passage
  on the gate's own ground; outside that stretch the road follows its routed
  course (Round 22 Phase 4). Which side the gate faces follows the blueprint's
  own `main_street` landmark, never an assumed sign. That stretch is ordinary
  road, so it keeps the road protection, the clear corridor and every other
  rule an ordinary road carries ([world.md](world.md) §2 R1b).
- **The start town's surroundings (Round 22 D78, 2026-09-27).** Replaces the
  blend-ring and apron rules of 2026-09-14/15. The protected band round the
  pad (12 nodes, rounded corners) grows no trees and no ground cover, so
  players see where the protection ends; right beyond it the biome's trees,
  plants and ground cover grow normally, and resources and caves follow the
  zone's ordinary rules (starting zones hold no claims). The band carries the
  town's own ground (the pad's ground node of its race palette) 2–10 nodes out from the
  pad along a smooth noise outline with a dithered edge, then the biome's
  surface, so no straight edge or corner of the pad shows. The same world
  seed always produces the same outline.
- **Grading.** The flat pad grows by a seed-deterministic 0–6 nodes along a
  noise outline, then a 24-node collar (noisy edge, rounded corners) blends
  it into the terrain; it starts in the band and runs out just beyond it.
  The terrain round a start is calm only through the band; natural relief
  returns over a fade of about 60 nodes on level land and up to about 200
  where the town sits in a hollow or on a rise ([world_zones.md](world_zones.md)
  §7.6), so the ground rises or falls back as a hill. The pad stays flat
  and every blueprint cell is unaffected; the pad's reference height (and
  with it the spawn height and road pins) follows the same sampling rule on
  the new terrain, so it can differ by a few nodes from a pre-D78 world of
  the same seed. No authored water (a start's pond) floods, cuts or raises
  the pad or the band.

## Settlement NPCs and guard targeting

Decided 2026-09-14.

- Guards attack enemy-faction players everywhere, in starts as at outposts
  and capitals; the faction veto stays the one rule. They ignore own-faction
  and factionless players and fight hostile mobs.
- **The NPC's faction decides whom it serves, not the place** (Round 31,
  PvP ruling 13). An NPC's faction is that of its race (a quest giver added
  by a zone quest file may name its own race; a profession vendor takes its
  settlement's race). Quest givers, vendors, profession and Riding trainers,
  the Shipwright, innkeepers, Housing Stewards, Crownbinders and waystones serve only
  their own faction; the other faction, and a character without a faction
  yet, get one line, "<NPC> I serve only The Accord." (the Throng's
  likewise), at most once every two seconds. Plain residents are no service
  and still answer anyone with their flavour line. Every settlement NPC has
  a faction, so no NPC serves both. Guards, royal guards, kings and the PvP
  POIs' captains and Generals give no quests: quest givers stand only on
  `quest` sockets.
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

**As built: the capital planner (Round 22, plan D60, D69–D72, 2026-09-27;
Round 26 Lane W, 2026-09-29).**
Every capital's city is laid out once per world (on its first start; later
boots reuse the layout from the world folder, `world_zones.md` §13.4), after
height, water and roads, in its own landscape (`world_zones.md` §12 has the rules): an
organic outline of about 100 k m² inside the reserved 512 square, four gates
toward the incoming roads with connector roads to the road ends, avenues,
two terrain-bent ring lanes loosened by cross-lanes, open arcs and small
squares, the district plots turned to face their streets, the race's edge
(stone curtain or palisade, each in its race's style) on the outline and,
in Highcourt, a one-level quay canal. Since Round 26 the outline is more
irregular (still star-shaped, still inside the 512 square at about the same
area) and each capital has its own character: Highcourt a royal city on its
river, Dur Brannoc an angular mountain hold with a tower on every corner, Nhal
Veyr a walled necropolis with one round ring, Gor Drazhak a jagged war camp
with a pinwheel of avenues, Lethariel a lakeside city with few towers,
Kezamba a jungle city round its cenote (`world_zones.md` §12 has the
details). The civic core stays exactly as authored; start towns are
untouched. The layout is a pure function of the
seed and the code, so a world always rebuilds the same city.

Decided 2026-09-15 with the pilot capital, Highcourt.

A capital is not one blueprint but a civic core, the placed district plots and
its edge, and they reach the world in three ways. The **core** is
anchor-relative like a start, flat on the fitted capital height, and the guard
banner the map already writes at the anchor stays where it is: the core leaves
that one cell alone. A **district plot** stands where the planner put it,
turned in quarter turns so its door faces its street, on the ground height the
planner sampled at its centre; a foundation skirt carries its perimeter six
nodes down, it clears its own airspace, the ground round it eases to its height
within eight nodes, and a short path joins its entry to the street. The
**edge** (walls or palisades, turrets, gatehouses)
has no fixed cells: it is computed per mapchunk from the outline and the ground
the map has. The **streets** are roads of the road network (`world_zones.md`
§9), so they climb in half steps, cut and fill like any road and cross water as
bridges; the avenues run straight through their gatehouses.

**The civic-core boundary is protected.** Decided 2026-09-18 after playtest
round 10. Its wall, parapet, bank or palisade is written after all structural
core content and later dressing may use only free cells: a house, orchard,
green, lore piece, martial piece or prop may meet the boundary but may not cut
it. Only the four authored thirteen-column gate or threshold bands stay open.
The boundary and its gates stand at radius 48, two nodes outside the earlier
radius 46. Each capital retains the actual asymmetric extent of its gatehouses;
projection bounds include every authored cell, and no ring column intersects a
building. Nhal Veyr's bars align with their wall on both axes. The 5 x 5
corner drums and towers of Dur Brannoc, Gor Drazhak and Nhal Veyr own the ring
columns from ±45 outward; the ring stops against their walls.
A fitting attached to content displaced by the boundary is removed, and an
edge building faces inward so its door remains usable. The six forms of the
same rule are:

| Capital | Protected civic-core boundary |
| --- | --- |
| Highcourt | One-node castle-stonewall wall, four courses: two of stonewall, the crown's marble band at the height of the gatehouse piers' band, and a stonewall merlon on every other column. |
| Dur Brannoc | Three-course masonry parapet with a capped merlon every fourth column; the four closed corner drums replace its corner columns. |
| Gor Drazhak | Three-course earth bank (two of dug earth, a beaten crest) with an acacia stake and point every other column; closed timber corner towers replace its corner columns. |
| Nhal Veyr | Two-course dungeon-stone parapet with a capped merlon every fourth column and flat iron bars filling the three columns between two merlons; the four closed corner drums replace its corner columns. |
| Lethariel | Light wall on every dry edge: two courses of silver sandstone brick, a marble coping at the height of the pale gatehouses' marble band, and a low merlon (one brick under a marble slab) on every other column; the authored mere is the boundary where it reaches the north edge. |
| Kezamba | Three-course junglewood palisade on every dry edge; the authored cenote is the boundary where it reaches the north-east edge. |

**Streets are roads.** Since Round 22 every capital street, lane and connector
follows the road rule of `world_zones.md` §9: at most half a node between
neighbouring columns with a slab on each half step, cut slopes and
embankments like any road, bridges over water, flat mouths where a lane meets
its street; a small square at a crossing or a lane end is paved flat at its
street's level and shrinks until every street through it stays within half a
node of it.

**Capital service presentation (2026-09-20).** Each profession premise has
at least one readable protected exterior product frame/sign and one interior
fixed product stand/rack. Weaponsmith and Armorsmith retain separate identities
inside their shared forge; Alchemy, Tailor, Leatherworker, Woodcarver,
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
skinned by each capital's architectural palette. The stable publishes one
`shipwright` socket beside the Riding Trainer (plot-local x = 8, the Trainer's
row; Round 29), so all six capitals have the shipwright's spot; the plot's
residents stand along the west fence (x = −8), clear of the mount displays'
lanes. The role handler is `grug_mounts`' (boats); a socket without a handler
places nobody.

The shared gatehouse upper-floor stair opening removes exactly one additional
obstructing block in the ascent direction. Treads, rise, passage, deck and room
dimensions are unchanged; there is no stair redesign or bespoke clearance test.

A capital has **four districts**: market and professions, martial and
garrison, lore and spiritual, residential and cultural. They stay recognisable
groups: the planner gives each the quarter between two avenues with the most
room for its buildings, places buildings nearer the core and field dressings
toward the edge, and lets a plot that finds no room overflow into a
neighbouring quarter. Required plots (the inn, the eight service plots with the
cook and the stable) always stand; on cramped ground only field and fill
dressings may be left out (plan D70). The planner places in three tiers —
required plots, then the other named buildings, then fill — and each tier runs
all its passes (own quarter, the two neighbouring quarters, the opposite
quarter, then relaxed legality anywhere; fill stops after the neighbours)
before the next tier places anything (Round 25 Lane H, 2026-09-29), so a
building that misses its quarter is never squeezed out by lower tiers. A named
building is left out only when no legal spot remains anywhere (a capacity
limit, rare). Guard posts belong to the garrison district, the two
traders to the core, and every district keeps two spare standing spots its
people may walk to.

Capital blueprint construction is lazy when map generation first touches its
envelope; mapchunk traversal may release cached construction data. The main
environment builds and hashes every blueprint once at load; the map generator
takes main's preparations of the lazy blueprints instead of building them all
again and checks every lazy rebuild against main's identity and landmarks. A
divergence between the two environments therefore stops generation when the
blueprint is first touched, mid-generation, instead of at map generator start. Full-world
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

**Walled capitals.** The user's ruling of 2026-09-17 fixed **four walled
capitals** — Highcourt, Dur Brannoc, Gor Drazhak and Nhal Veyr — and **two
open capitals**, Lethariel and Kezamba; the Round 23 ruling (2026-09-28)
walls the two open ones as well, so **all six capitals are walled**. The wall
follows the planner's outline as a polyline, with a gatehouse at each of the
four gates, and the avenue runs through its gate passage. Since Round 26 each
capital sets its own tower rhythm on long stretches (every 64 to 96 nodes),
adds towers at sharp bends (every corner of Dur Brannoc's angular wall; none
in Nhal Veyr's steady curtain) and, in Highcourt, Dur Brannoc and Nhal Veyr,
towers beside the gatehouses. Its masonry
starts under each column's own ground, so a wall on a slope has no gap, and
its walk rises and falls at most half a node per node (a slab on each half
step), so it can be walked. Where the outline crosses a river the wall is an
arcade: the walk on an arch, piers down to the bed, the river passing below.
However long the crossing, the walk stays out of the water. A capital's
**civic lake is its edge** (user rulings 2026-09-28, the second after a
playtest): where the outline crosses Lethariel's crown lake or Kezamba's
cenote, the wall is continuous on land up to the water and runs on over the
first one to three water points of the crossing (points after the first only
within three nodes of the shore), on a solid footing down to the bed in the
race's masonry or stakes, and ends there in a closed head reaching a node and
a half past its last point -- a parapet across the walk, or the stockade --
so no beach is left to walk round its end; beyond that the lake is open. A gatehouse beside the water is followed by the same short run into
it when the first water point lies within three nodes of the shore; where the
water is deeper there, the gatehouse itself closes the end. A stretch of shore
between two crossings carries no wall when it is short (under 12 points, about
24 nodes) or when the land on either side of it is closed off by the lake --
outside, land reached only over the water; inside, a spit the lake cuts off
from the city; any other dry stretch is walled, so the city is never open over
land. No turret stands within six points
of the open water. The wall carries no
NPCs of its own; a capital's garrison is the four gatehouses of its civic
core.

**Between the plots.** Decided 2026-09-15 with the round-3 playtest: a quarter
of nine buildings in a 512 envelope is empty, so each quarter carries four more
pieces of open ground beside its nine plots — a field, a pasture, a yard and a
green, at four deliberately different sizes. They are plots like any other,
with their own foundation skirt, and the planner places them toward the edge of
their district's quarter (on cramped ground they are what may be left out).
What stands on them is the
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
on the granite ground round the flat civic core. The four quarters are the forge and its professions, the garrison, the
halls of record with the carvers' yard and the barrow terrace, and the terrace
houses with their alehouse and brewhouse. Its open ground is what a dwarf city
keeps: an ore court with a mine mouth cut into a rock face, charcoal clamps, a
slag yard, mushroom beds grown in the lee of the wall, goat pens and brewing
courts. Its trades are a smith, a mason, an armourer, an embalmer, a butcher, a
brewer and a baker, beside the two travelling traders every capital's core has.
**The capital that stands on a lake.** Decided 2026-09-15 with the third
capital, Lethariel, which was open until Round 23 (a planted belt with a
threshold at each gate point). Since the Round 23 ruling of 2026-09-28 its
edge is the **stone curtain in the elves' own light style**: pale silver
sandstone brick over a silver sandstone core, a green serpentine string
course, a marble coping on every parapet, low merlons of one brick under a
marble slab (the playtest's ruling: the first version's pillar colonnettes
stood too tall), a marble-tiled walk, slim turrets about
every 48 nodes each carrying an emberglass lamp, and gatehouses with a marble
lintel over the passage. It stands on the footprint the belt was planned with
(wall half 2, gate boxes 3 by 5), so the city inside is laid out exactly as
before, and where the crown lake crosses the outline the wall runs a few
nodes into the water on both sides and ends there in a closed head.

Lethariel also shows what happens when the map does not give a capital four
usable quarters. Its crown lake reaches into the civic core itself, so the
**lore and spiritual district is the mere precinct** and the planner keeps it
beside the lake, where it has room for three plots and two dressings; the
other three districts take the quarters with room. The civic core stops at the
water's edge and meets it with a marble quay, and an avenue that crosses the
lake does so as a bridge.

**Not every wall is masonry.** Added 2026-09-15 with the third capital, Gor
Drazhak. What a walled capital has on its envelope edge is decided by the race
that built it: the dwarves, the humans and the undead raise a stone curtain,
and the orcs raise a **stake palisade on an earth rampart** -- a dug bank
thrown up along the city's outline with a stockade of acacia stakes on its outer
crest, a fighting walk along the top and a timber tower about every fifty-six
nodes. It follows the ground and lets the avenue through its gates exactly as
a curtain does, and it is the same thing to walk on; it simply is not made of
stone. Gor Drazhak's own civic
precinct repeats the section at a reduced height -- three courses of beaten
earth with a stake every other node -- so the city wall and the citadel wall
read as one piece of engineering. Kezamba raises the same palisade (Round 23)
in its own civic palisade's material: jungle-log stakes with a junglewood
point on every stake, turned by column, and a junglewood walk; where the
cenote reaches the outline it ends on both shores in a closed timber tower.

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

**The capital with a lake in it.** How a capital with a lake in its core is
laid out is the third capital's own lane, 2026-09-15/16, and is open to the
user's correction like any other design. (Kezamba was open until Round 23;
its city edge is now the troll palisade described above.)

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

Where the water takes most of a quarter — Kezamba's cenote in every world —
the district that belongs by the water keeps its place there: the **shore
market** is pinned beside the cenote and what does not fit overflows into the
neighbouring quarters (plan D72) — in every world. Since Round 25 Lane H its
required shore plots overflow ahead of the other districts' buildings, which
keeps them placed; its other named shore plots overflow with the named tier. Kezamba's districts carry nine, nine, eleven
and seven building plots, thirty-six in all, with the same sixteen fill
dressings every capital has.

**Nhal Veyr, the raised necropolis.** Shipped 2026-09-15, the last of the wave-2
capitals to land and one of the four walled ones. It is the first capital whose FILL is not fields and
gardens: where Highcourt has crop fields, an orchard belt and a pond, the undead
capital has grave fields, bone yards, ruin closes and candle courts, and the
turf between its civic quarters is a burial ground with gravewood stands in it.
Its civic buildings are dungeon stone under a pale stone roof and everything a
citizen built is gravewood board; its own two parts, which no other capital has,
are a walk-in mausoleum on a stepped plinth and a candle court with an altar at
its centre. Its curtain wall and its four districts are laid out by the capital
planner like every capital's.

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
- **A patrolling guard turns and walks together** (Round 28 ruling 11): each
  route step faces the new heading at once and walks along it, and a guard
  with a patrol loop makes no random turns of its own. Post guards keep their
  idle glances.

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
  armourer, tanner and embalmer. Each has a shelf of its trade's supplies and
  T1 basics (the vendor supply rule of [professions.md](professions.md) §4;
  shelves in the [economy plan](../planning/economy-vendor-plan.md) §2.3) and
  serves its settlement's faction (no race restriction, and therefore no
  kinship discount); only the smith and the armourer also sell the T1 gear
  (since Round 33 the T1 catalog only), the bowyer and the tanner its bows
  and leather armour.
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
respawn follow [home_travel.md](home_travel.md). No other V1 home points exist;
a player's Claim Stone can be an additional travel-home target
([housing.md](housing.md) §8).

## Waypoint pads

Round 29 (WP17; rules in [world.md](world.md) §6). Every start, every
capital and (Round 31) each PvP fortress has one waypoint pad with a **waystone** (`grug_mapgen:waystone`,
registered in `grug_mapgen/world_nodes.lua` so the settlement content resolves
it) at its centre, in the cell of the settlement's `travel_waypoint` socket
(role `waypoint`; no NPC stands there). Players arrive beside the stone.

- **Capitals:** the existing kerbed plaza with the stone cross and diamond
  (reach 6, Lethariel 5, Kezamba a cross only) gets the waystone at the cross's
  centre; nothing else stands on the plaza.
- **PvP fortresses:** the capitals' stone cross and diamond at reach 3 in
  the fortress's south-east yard (`r31_pvp_poi_blueprint.lua`); the socket
  has no arrival side, so a traveller arrives on the stone's +x side first.
- **Starts:** a pad in the capitals' style at reach 3, drawn into the ground
  course (`dressing.waypoint_pad`): a cross and the diamond round it in the
  start palette's signature stone, the diamond's inside paved with the lane
  material, the waystone in the middle. It is laid on open ground after the
  buildings and lights and before the trees and flora, inside the start's
  footprint, near the innkeeper and reachable from a lane (pad centre in
  start-local x/z):

  | Start | Centre | Where |
  |---|---|---|
  | Hearthpine | (−9, 12) | litter west of the street, 11 nodes from the inn door |
  | Dawnmere | (14, −6) | turf between the green's east kerb and the east lane, 15 nodes from the inn door |
  | Silverleaf | (−44, −23) | the west end of the south lane, 9 nodes from the guest house door |
  | Stillgrave | (−14, 22) | blight beside the west lane, 10 nodes from the warden's door |
  | Sunscar | (−11, −16) | flats north of the south lane, 6 nodes from the tusk house door |
  | Kapok Cradle | (−12, 5) | litter west of the boardwalk road between the cross lanes |

## Housing Stewards (Round 25)

Each capital's Housing Steward ([housing.md](housing.md) §7.2) is the gate
resident of that capital's tailor service plot:

| Capital | Plot |
|---|---|
| Highcourt | `market_counting_house` |
| Dur Brannoc | `forge_guild_house` |
| Lethariel | `market_weaver` |
| Nhal Veyr | `market_shroud_house` |
| Gor Drazhak | `warren_weaver` |
| Kezamba | `shore_tailor` |

It serves only its capital's faction and shows a "+" marker on that
faction's map.

## Crownbinders and Decor Merchants (Round 33)

In every capital the **Crownbinder** ([economy.md](economy.md) §4,
[item_tiers.md](item_tiers.md) §4) is the gate resident of the goldsmith
service plot and the **Decor Merchant** (the culture vendor) the gate resident
of the woodcarver service plot, taken over like the Housing Steward's; no
blueprint or mapgen output changes. Both serve only their capital's faction
and have a map marker on that faction's Map tab and minimap (Round 34).

| Capital | Crownbinder (goldsmith plot) | Decor Merchant (woodcarver plot) |
|---|---|---|
| Highcourt | `lore_archive` | `martial_wain_shed` |
| Dur Brannoc | `forge_ore_yard` | `deep_carvers` |
| Lethariel | `mere_lore_hall` | `market_bowyer` |
| Nhal Veyr | `market_bone_store` | `vigil_candle_works` |
| Gor Drazhak | `bazaar_armourer` | `bazaar_carver` |
| Kezamba | `totem_scriptorium` | `shore_carvers` |

## Round 20 authored regional places

The 100-anchor roster retains its six starts, six capitals and eighteen earlier
regional compositions. The remaining 70 art slots receive individually authored
building placement, entrances and cultural palettes: six villages, eighteen
outposts, six frontier bandit camps, six mines, four mirefolk camps, sixteen
clash sites, two dragon arenas, two apex camps and ten rare-route pads. Inhabited
sites have multiple structures; encounter clearings and rare pads have no
buildings and keep their centres open (their dressing: "Decor pass" below). Villages include four to six buildings. Shared building components
are allowed; an identical rotated town layout is not the design.

Art uses the existing settlement projection, actor-root priority and reserved
footprints. It neither adds duplicate bosses/guards/resources nor expands
terrain reservations. The frontier bandit camp's building core is 16 nodes
(user decision 2026-09-29, WP audit E1: the art and code stay, the former
24-node design value is corrected). Whitebridge and Whispering
Reedlands keep their display hulls as plain scenery; the Shipwright who sells
boats stands at every capital stable (above; [boats.md](boats.md) §2).

Thirty peaceful regional sites (villages, outposts and mines) each provide one
quest host. Hostile new camps do not gain friendly residents. Each starting
town and capital has a separate cook questgiver near its oven, distinct from
the Cooking profession trainer. Capitals reuse existing quest shells for their
envoy. Quest identities and journey structure belong to `quests.md`.

## Decor pass (Round 36)

Every settlement composition carries dressing that fits its style (user
review of 2026-10-05 on the POI review page; WP13 rework, plan §2.11). The
pieces and rules live in one module, `grug_mapgen/wp13/decor_kit.lua`; every
node comes from the race's settlement palette (`wp13/palette.lua`), so a dwarf
well looks dwarf. Footprints, positions, paths, protection boxes, sockets
and the world plan are unchanged; only cells inside each composition's own
volume change.

**A theme per kind.** The Round 20 and Round 14/15 compositions name their
pieces as authored rows (`r20_poi_catalog.lua` `props`, the Round 14
builder's `DECOR` table); the old block formations (walls, ruins, menhirs,
cairns, bare log stacks) are gone.

| Kind | Theme | Pieces |
|---|---|---|
| Village | a lived-in hamlet | well with its lamp, crafting corner (workbench, wood pile, barrel, table), flower bed, stores, kitchen garden, lantern post, bench |
| Outpost | a watch post | banner pole with a torch, weapon rack, stores, lantern post, bench |
| Frontier bandit camp | a robbers' hideout | loot stores, lean-to with sleeping mats, weapon rack, broken palisade, drying rack (the camp fire stays the centre) |
| Mine | a working dig | ore heap and ore cart before the adit, pit timber, crafting corner, tool rack, stores, lantern post |
| Mirefolk camp | a fen camp | drying racks, baskets on mud, totem, cold hearth, lantern post |
| Clash site | the remains of a battle | broken palisade, banner pole, thrown-down banner, weapon rack, fresh graves (one with a candle), burnt cart on ash, fallen masonry |
| Rare pad | the beast's lair | stone den, nest, bones, claw scrapes, a traveller's remains; per beast webs (spider), a nest (bird), churned earth (boar), ash (fire), a toll barricade (the captain) |
| Apex camp | the gem prospectors' camp | shelters, hearth with a bench, sorting table, ore heaps and cart, crafting corner, stores, lamps along the way; the sample wall stays |
| Start-zone village / outpost / camp (Round 14/15) | as their kind | well, flower bed, crafting corner, lamp, wood pile / banner pole, weapon rack, stores / palisade, rack, lean-to, cold hearth |

**Placement rules.** An authored piece lands whole or the composition fails
to build (`decor_kit.place`): it stands only on the composition's open
ground, never on a path, a built cell, a socket or the cell in front of it,
the two cells before a doorway, or the central actor clearance (the 5 × 5
round the anchor where actors, the quest host, the anchor's camp fire or
banner and a clash site's quest objects stand). Nothing solid (a barrel,
a crate, a log, a post, a bench) stands directly before or behind a
window at the window's height; plants, pots, mats and lights may. The
four rift-site
candidates keep their four `props` rows at the positions the crack plan
avoids and carry their other pieces as `decor` rows off the crack;
Tombroad Ambush's crack cells and the two nodes below them are untouched.

**House touches.** Every closed building of a POI, a start town and a
capital district plot gets small touches from its own door, walls and
windows (`decor_kit.dress_house`): a torch beside a door without one, a
barrel, two stacked or a pot plant by the door, pot plants under a window,
a short wood pile or a barrel against a side wall. They stand on open
ground or on the paving round the house: its apron and, in a start town
or a capital plot, the edge of the lane along its wall. A solid touch is
placed only where the lane past it stays open (the cells outward of it and
of both its wall-side neighbours are free ground two nodes high), never
before a window, on a socket or the cell before it.

**Light.** A few lights per POI: the door torches and one to three lantern
posts or banner torches. The settlement writer relights every chunk it
writes from the light sources (`r6_settlement.lua` `calc_lighting`), so a
mapgen-placed torch lights at once.

**Rooms and ways.** Every closed room keeps at least two nodes of air
over its walkable floor (Redtusk Village's low annex, the one two-course
Round 14 house, has three since Round 36), and every place a player can
walk to from a composition's arrival without its dressing stays reachable
with it, within a detour of a few steps.

**Benches.** A bench of stair seats runs along its axis and every seat
looks across it; temple pews look at the altar. A seat looks away from its
raised half, the backrest (the stair's upper half lies along the facedir
of its param2, so the sitter looks along param2 + 2). A bench keeps its
back to the house or wall beside it and its seat toward the lane: the
bench before a capital plot's door, the benches against a POI house and a
fortress barracks wall (Round 36 playtest: they faced the houses). A
bench beside a well, a fire or a table looks at it, and a resident who
sits on a bench faces where it looks. `tools/r36_w/portable_test.lua`
checks every start and capital for a seat that looks along its own bench,
holds every composition's bounds, airspace and sockets to main's record
from before the pass, and checks the windows, the headroom and the ways
above over every composition; `tools/r36_w2/portable_test.lua` holds every
bench of every composition to the rule (no wall ahead it could have its
back to, no fire or well behind it without something to look at ahead).

## Round 21 ground and access correction

Approved 2026-09-24. Preserve anchor/reservation extents
while separating natural terrain fitting from visible masonry. POI collars
retain biome/cultural ground. Street junctions have complete shared footprints
and a single landing surface, with incident runs ending at their ports. Core,
gate and entrance approaches share consistent endpoint heights and headroom.
Plot collars may cut/fill natural terrain before final paths; each entrance must
connect to a nearby street within 24 nodes, or to natural terrain within its
eight-node collar when no street is nearby. Such natural connections retain
the same slope and headroom requirements. Retaining walls elsewhere are allowed. These rules
replace the prior no-outside-apron policy where it prevents access.

## Round 31 PvP fortresses and war camps

Anchors 101–118 add the two faction fortresses (49 × 49, stone curtain wall,
one gate, keep, barracks, the Quartermaster's store, armoury, drill yard and
waystone pad) and the 16 Battlegrounds camps (23 × 23 pickets and 27 × 27
war camps: palisade, faction-cloth tents, a command tent and a shelter,
watchtowers at the war camps), built by `wp40/r31_pvp_poi_blueprint.lua`. A
fortress registers as its faction's seat race (human, orc); a camp rolls one
race of its faction per world and builds in that race's materials. Their
sockets hold the garrison (guard posts tagged gate, inner or camp; the
General and his bodyguards; a camp's captain), three protected quest givers
and a Quartermaster in a fortress, and the fortress waystone. Garrisons,
levels and quests: [pvp.md](pvp.md) §6–§7; positions and protection:
[world_zones.md](world_zones.md) §16.
