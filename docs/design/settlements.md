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
  storage or profession services.
- Race appearance (skin, visual-only stature) and visible armor and weapons
  are composed by one function for players and humanoid mobs, see
  [wp13-character-visuals-contract.md](../research/wp13-character-visuals-contract.md).
