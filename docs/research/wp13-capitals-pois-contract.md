# WP13: capitals and POI structures — contract draft

Status: draft, 2026-09-14, written by the coordinator (Claude Fable) while the
six start settlements were being built. Implementation starts after the
user's first acceptance of the starts. Facts below come from a read-only
inventory of WP40 (file:line in the inventory report, summarised here); the
decisions are the coordinator's and are open to the user's correction.

## 1. What WP40 already provides

- **Six capital anchors** are fixed: Dur Brannoc (-1800, -1500), Highcourt
  (0, -1500), Lethariel (1800, -1500), Nhal Veyr (-1800, 1500), Gor Drazhak
  (0, 1500), Kezamba (1800, 1500); anchors 7–12, slot `capital`.
- **Terrain is already shaped.** The 96 × 96 civic core is flat at the fitted
  reference height (`height.lua` capital reference rule), the next 32 nodes
  blend to race terraces (step dwarf/orc 4, human 2, elf/undead/troll 3), the
  rest of the 512 envelope is terraced within cut 24 / fill 16, and a 96-node
  collar returns to natural terrain. The fitted height is published as
  `anchor.y` exactly like a start.
- **Four gate stations** per capital sit at ±256 on each axis with fixed
  neighbour bindings; the 32-node gate corridor width is a dead constant, no
  avenue is authored inside the envelope. WP13 owns the avenues (§12).
- **Protection** is complete: 532 × 532 hard footprint from y = -700 upward
  per capital, plus the two 128-wide ingress corridors. Nothing to add.
- **Written today:** one `grug_nodes:guard_banner` at (x, y + 1, z). No
  platform, no legacy WP18 code remains. Vendors are placed by `grug_traders`
  at fixed offsets (-5, 3) and (5, 3) from the anchor at y + 1.
- **POI roster (100 anchors):** 12 villages (fitting 96, core 24), 24
  outposts (64/16), 12 bandit camps (64/16–24), 6 mining camps (80/20), 4
  mirefolk camps (64/16), 16 clash anchors (64/16), 2 dragon arenas (96/32),
  2 apex camps (96/32), 10 rare-route pads (32/12). Outposts and bandits get
  their spawner node written; everything else gets nothing. Candidate
  anchors resolve per seed to one of three positions; `session.anchor(zone,
  slot)` returns the resolved one.
- **Seam limits:** blueprint bounds ±63 / y -2..24 are literals in three
  places; the writer itself is unbounded. The roster resolves slot `"start"`
  only; `FIELD_ORDER`/`SETTLEMENT_ORDER` in the manifest are closed literal
  lists. Blueprints are built at load in the main environment; no timing is
  recorded, but a 66k-cell start builds in well under a second.

## 2. Decisions

### 2.1 A capital is one core blueprint plus terrain-relative district plots and avenues

- **Core blueprint** (bounds ±49, y -2..40; radius-48 precinct ring): king's hall on a
  podium, throne approach, waypoint plaza reserved by WP17's pending row,
  civic court and four gate openings at the core edge. The capital terrain
  fitting remains unchanged. Ring and gatehouses moved two nodes outward in
  Round 10; the seven-deep gates require south/west origins -49 and north/east
  origins 43, with emitted bounds ±49. The wider projection prevents clipping;
  outer route gate pins remain unchanged. Profession services occupy the
  terrain-relative outer plots (`professions.md` §1), not the civic court.
- **District plots** outside the core cannot be anchor-relative: the
  terraces put them on different heights. Each plot (≤ 32 × 32, bounds
  ±15, y -6..24) carries a **reference column**; at settle time the
  settlement config queries the pure final height at that column once per
  session (the same function the capital reference scan uses), caches it,
  and projects the plot's cells from that height. The plot generator writes
  a foundation skirt down to -6 and clears up to its roof, so a plot that
  straddles a terrace edge (max step 4) still stands.
- **Avenues** from the core edge to the four gates follow the plan's own
  column surface: pavement at surface, one stair node at each terrace rise,
  lamp posts every 8 nodes, no height queries. They are a surface overlay
  written by the same successor, after the plots.
- **Districts** are the four fixed roles of §12 (market/professions,
  martial/garrison, lore/spiritual, residential/cultural), assigned to
  quadrants by a deterministic permutation from the world seed through the
  existing R6 hash, with a per-race building-variant choice from the same
  hash. Each district is a list of plots along its avenue and the ring
  street; the library's generators scale up (hall, longhouse, workshop,
  cottage, shed, watchpost) plus new capital parts: curtain-wall segment
  with walkway and towers on the envelope edge where the race wants one
  (dwarf, undead, orc — and, since the round-3 plan, human: §4), colonnade,
  market square, barracks, temple/shrine,
  library, granary, stable, well, statue plinth, gatehouse.

### 2.1.1 Routes and gates

Playtest round 4, 2026-09-15. In Dur Brannoc the incoming WP40 route is cut by
the curtain wall at (-1847,-1756) while the gate stands at (-1801,-1756) --
anchor (-1800,-1500), so the south gate is at `z = anchor.z - 256` on the
avenue's centre line. The star-shaped anchor-bound routes predate the cities.
**The user's ruling: every incoming route ends at a planned point of the city
boundary (a gate) and no longer runs into the interior; inside, the WP13 streets
take over.** The consequence the user drew and the coordinator confirmed: no
WP40 bridge decks inside the 512 envelope any more (decks come from routes), so
the wave-1 lane-crossing rule ([wp13-lane-routes.md](wp13-lane-routes.md),
`wp13/avenue.lua`'s `spec.overhead`) becomes a safeguard, not a feature, inside
capitals.

What that means for a capital blueprint, and what a capital lane may rely on:

- **The four gate points, and WHICH TABLE A WP13 BLUEPRINT READS.** WP40 has two
  authored sources and both carry the same twenty-four coordinates:
  - `mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua`, `source.capital_gates`
    — twenty-four rows, `(ax +- 256, az)` and `(ax, az +- 256)` derived from
    `capital_core` (512 square), each also a ROUTE STATION of its own,
    `station:<zone id>:gate_<side>`, kind `gate`. **This is the live mapgen's
    source** (`grug_mapgen/init.lua` loads it) and it is what a capital route
    now ends at, so **this is the one a WP13 blueprint reads.**
  - `mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua` — the retired
    exact-topology catalog the T2 compiler reads, which has carried the same
    twenty-four points since before wave 2 as stations
    `station:<zone id>:capital_<side>`, kind `capital_gate`, gate ref
    `capital:<side>`. `wp13/highcourt.lua`'s "the gate stations sit at +-256 on
    each axis (WP40)" refers to these.

  Neither is derived from the other — the catalog is frozen input to a different
  pipeline — so `tools/wp13/route_gates_kat.lua` asserts the two agree point for
  point (`route_gate_catalog_agreement`). If one ever moves, that is where it
  says so. A capital's own avenue geometry stays where it is:
  `wp13/highcourt.lua` and `wp13/dur_brannoc.lua` author the same numbers, a run
  out to 261 so the road crosses the whole seven-node curtain, and the gate
  passage is 13 nodes wide, centred on the anchor's own axis.
- **Exactly four routes reach a capital, one per side**, so no gate is shared
  and no tie-break is needed. Each of them ends AT its gate point and enters it
  dead straight along the axis for the last 144 nodes, which is the whole leg
  from the gate to that route's own authored via pin.
- **A route grades nothing inside the envelope** except the 15 columns of its
  own seven-wide end cap, which reach three nodes in, lie inside the curtain's
  thickness under the gate passage, and are paved over by the avenue. So a gate
  passage must stay at least 7 nodes wide and centred on the anchor's axis, or
  route pavement shows inside the curtain.
- **The first ten columns inside each gate are the capital's to terrace.** The
  route's flat end cap gives the anchor fitting fewer columns to meet a hillside
  in, and the raw ground step over the eight columns inside a gate went from a
  worst of 3 to a worst of 9 across six capitals and nine seeds (Kezamba's south
  gate; 5 on the user's world). The paved avenue itself is unaffected -- its
  one-Lipschitz envelope ramps over it -- but a plot, a rampart footing or a
  lamp standard set there is not.
- **A capital's own fitting must reach its four gates.** The avenue's envelope
  will not rescue a plateau that stops short: Nhal Veyr's stops twelve nodes
  inside its north envelope edge and leaves a step of up to 6 and a walk break
  of up to 7 at that gate on five of the nine fixture seeds.
  `tools/wp13/route_gates.lua <repo> <seed> --strict` is the acceptance check
  (gate step <= 1, entry breaks = 0, on all nine seeds).
- **The road arrives at the gate's own ground.** A capital's hub station used to
  carry the anchor's platform height because the hub IS the anchor column; a
  gate station is a free-terrain junction instead, so the route meets the height
  the avenue will pave at that same column.

### 2.2 Seam generalisation (mechanical, one package before any capital)

1. Roster entries carry `slot` (start, capital, village_1, outpost_1…) and
   `bounds` per blueprint; the literal ±63 / -2..24 becomes the start
   profile's value, capital core and plots carry their own.
2. Manifest `FIELD_ORDER`/`SETTLEMENT_ORDER` and the successor's key checks
   are derived from the roster in a fixed order (roster order), not typed
   per settlement. Hearthpine's field names stay for digest continuity.
3. A settlement config may own **several blueprints** (core + plots +
   avenue overlay), each with its own identity SHA; the manifest lists them.
4. **Lazy construction**: a capital's blueprints are built on the first
   `bind_plan` that touches its envelope and released when no mapchunk has
   touched it for a while, so six capitals do not sit in memory at once.
   Starts stay eager (they are small and the spawn depends on them).
5. Buffers use packed integer keys, not string keys, for anything above the
   start size.

### 2.3 Budgets

- Core ≤ 150,000 cells; each plot ≤ 12,000; avenue overlay computed per
  chunk, not stored. A whole capital stays under 400,000 cells and builds in
  a few seconds under LuaJIT when first touched. Measure, do not assume:
  the first capital package records build time under both interpreters.
- Per-mapchunk cost is the clip loop plus at most a handful of height
  queries; the Dawnmere evidence shows ~0.5 s per settlement chunk today,
  which capitals must not exceed by more than 2×.

### 2.4 Race identity of the six capitals (first-version intent)

| Capital | Race | Terrain (WP40) | Look |
|---|---|---|---|
| Dur Brannoc | dwarf | granite terrace, step 4 | stone-block citadel walls with pillars and arrowslits, pine-and-slate halls, forge court, stair streets between terraces |
| Highcourt | human | river plateau, step 2 | brick-and-white-stone city, half-timbered lanes, market square, chapel with belfry, orchards inside the wall ring |
| Lethariel | elf | terraced grove, step 3 | silverwood and marble, tall narrow halls, colonnades, lantern-lit walks, groves between plots, no curtain wall |
| Nhal Veyr | undead | raised necropolis, step 3 | dungeon stone and obsidian brick, mausoleum core, stepped terraces with ruins mixed among kept houses, candles and iron bars |
| Gor Drazhak | orc | mesa shelf, step 4 | adobe flat roofs with parapets, ors-stone base courses, palisade and earthworks, warlord hall with fighting platform |
| Kezamba | troll | stilted cenote terrace, step 3 | stilt halls on basalt platforms, junglewood walkways, totem posts, cauldron courts, emergent trees kept |

The start palettes are the base; each capital adds the castle kit
(`grug_decor:castle_*`) for walls, pillars, slits, paving and rubble, and
one signature material per race (marble, brick, adobe, basalt, obsidian,
stone block).

### 2.5 POIs after the capitals

- **Villages** (12): the library at 96 envelope (bounds ±47), six to ten
  buildings, race palette, one composition per race with seeded variation.
  The two shipwright villages get a shipwright plot and a display boat as
  scenery (`boats.md` §2); the NPC itself is WP17.
- **Outposts and bandit camps** (36): small compositions at 64; the
  spawner column at (0, 1, 0) stays untouched (the anchor writer owns it),
  so the composition leaves that cell and its headroom clear. Outposts:
  palisade, watchtower, barracks hut; bandit camps: tents from `cottages`
  wool tent, cook fire dressing without the spawner node, loot crates.
- **Mining camps** (6) and **apex camps** (2): shed, ore crates, rails as
  dressing; the twelve protected renewable sockets stay WP34's.
- **Mirefolk camps** (4), **clash anchors** (16), **dragon arenas** (2):
  dressing only in WP13; encounter logic is WP42/WP23.

## 3. Increment order

1. Seam generalisation (§2.2) with Hearthpine and Dawnmere byte-identical.
   **Shipped 2026-09-15**, [wp13-seam-generalisation.md](wp13-seam-generalisation.md).
2. Highcourt core + one district + its four avenues as the pilot capital;
   measure build time and per-chunk cost; user playtest.
   **Shipped 2026-09-14/15**, [wp13-highcourt.md](wp13-highcourt.md).
3. The other five capitals, one lane each, after the pilot's fix round.
   **Dur Brannoc shipped 2026-09-15** — the first WALLED capital, so it also
   owns the curtain wall's representation in the seam:
   [wp13-dur-brannoc.md](wp13-dur-brannoc.md). Its answer, which the four
   remaining capitals inherit, is that a curtain wall is an **overlay** and
   shares its capital's one overlay blueprint with the avenues, because the
   cross-run arbitration that lets a road through a gate only exists inside one
   overlay. Nhal Veyr and Gor Drazhak are the other two walled ones of the
   2026-09-14 decision; Highcourt joined them through the round-3 plan (§4) and
   uses the same overlay unchanged.
4. Villages (12), then outposts/camps, then mining/apex/mirefolk dressing.

## 4. User rulings

- **King's hall**: decided 2026-09-14, the core blueprint builds the throne
  room layout the king encounter will use, so the NPC package places
  entities into finished architecture.
- **Sockets**: capital cores export `landmarks.sockets` (king, vendor ×2,
  guard posts, patrol loop, idle, waypoint) per
  [wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md); the fixed
  vendor offsets in `vendors.lua` migrate when the first core lands.
- **Curtain walls** (a city wall along the 512 × 512 envelope with towers
  and gatehouses at the four ±256 gates): proposal is walls for Dur
  Brannoc, Nhal Veyr and Gor Drazhak, open edges (hedges/orchards, groves,
  stilts and water) for Highcourt, Lethariel and Kezamba. **Decided
  2026-09-14 as proposed**: three walled (dwarf, undead, orc), three open
  (human, elf, troll), for variation.

  **Changed 2026-09-15, and the record of how matters.** The user's decision of
  2026-09-14 put Highcourt among the OPEN capitals and nothing in this contract
  said otherwise: the phrase "orchards inside the wall ring" in §2.4's Look
  column is prose describing an orchard belt, not a wall decision, and it should
  not be read as one. What happened on 2026-09-15 is that the **coordinator's
  playtest-round-3 plan proposed a wall ring for Highcourt**, with the
  coordinator's reason that an open capital reads as a field with houses in it,
  and **the user approved that plan**. So the split is now four walled and two
  open (Lethariel and Kezamba stay open), the wall is `wp13/wall.lua`'s overlay
  in Highcourt's palette — the mechanism Dur Brannoc landed, unchanged — and the
  orchards stand inside it.

  This is a plan the user approved, not a ruling the user gave, and the
  2026-09-14 decision it departs from IS a user ruling. **The user may reverse
  it**, in which case Highcourt loses four overlay runs and their plan and
  keeps everything else this package built; the fill, the pond and the trades do
  not depend on the wall.
