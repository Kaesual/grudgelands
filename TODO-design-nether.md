# TODO — The Nether (Phase 2; spec in progress)

Direction decided 2026-08-06 (waypoints/currency were decided alongside
and already live in `docs/design/world.md` §6 / `economy.md`):

- The Nether is a **deadly place** where "the magic of the world created
  connections between places" — story layer + travel layer in one.
- **Island crossings**: portals in own territory (first in the midlands,
  lvl 10+) lead to a Nether island surrounded by lava with two exit
  portals — one per faction, far apart; Nether mobs at the level of the
  connected areas. **Mirror pairing (x, z) ↔ (x, −z)** links both ends:
  same difficulty ring and mirrored race regions automatically
  (rings are |z|-based) — gameplay symmetry for free.
- Portals are two-way → a crossed island is a persistent raid route;
  exit camping is PvP content, kept fair by multiple islands across the
  x-width and exit scatter.
- **The Nether is a farmable, active game zone with its own rules** (not
  pure transit): own materials (tie into the material tier system),
  own mobs, and later **world bosses gated behind challenges**.
- Technical route: own layer in a deep y-band via our mapgen
  (`on_generated` pass like wall/camps); portal pairing deterministic
  from coordinates; portal frames protected. No external mod needed.
- **The overworld:nether distance ratio is entirely ours** — Luanti has
  no built-in Nether; Minecraft's 1:8 is that game's convention, not an
  engine rule. With the island model no global ratio is needed at all:
  islands live on their own internal grid, indexed by portal pair. A
  freely walkable 1:8 shortcut dimension is deliberately NOT planned —
  it would undercut waypoints and mounts.

## Decided 2026-08-06 (design review)

- **Shared-world zone, NOT an instancing mechanism**: Nether lairs are
  shared with respawn timers. A generic per-party instance service
  (sealed y-band slots + `delete_area`, feasibility researched and
  confirmed) is a **Phase 3 option** only if boss contention ever
  becomes real — until then, author all lair content portable
  ("schematic + spawn set + entry portal") so the upgrade is a hosting
  change, not a redesign.
- **Portals are world-placed only** — never craftable by players; the
  Nether y-band is not reachable by digging. There are no "normal"
  free-crossing portals: every crossing is one of the designed island
  pairs.
- Zone rules: **no waypoints inside; Home Stone works** (its 60 min
  cooldown is the escape valve); **no building at all** (R3-style);
  **heat damage only in specific lava fields**, never globally.
- **Portal activation**: first portal quest-unlocked (story beat), the
  rest always on.
- **Gating hole + fix**: two-way mirror portals bypass the war-coast
  funnel (world.md §1). Either land exits inside the enemy's war-coast
  band, or arrivals carry a visible "Rift-Touched" marker (~10 min) so
  defenders can hunt them (leaning: marker — keeps the mirror pairing
  intact and manufactures PvP events). Pick in Phase 2 planning.

## Open (to spec before the Phase 2 WP)

- Nether materials in the tier table (items TODO §5) + what world
  bosses drop (ties into boss loot, items TODO §3); the **Nether dragon
  lord** is the Phase 3 capstone boss (world.md §4b).
- Challenge design for reaching world bosses (jump/lava puzzles? kill
  gates? key items?).
- ~~Story framing~~ — decided, see `docs/design/story.md`: a demonic
  evil opened the connections from the other side; Nether world bosses
  are its lords.

**Decision:** _pending (Phase 2 planning)_
