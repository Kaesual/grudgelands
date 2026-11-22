# Housing: Claim Stones

Decided 2026-09-29 (Round 25, rulings 1–29 of the
[Round 25 housing plan](../planning/round25-housing-plan.md); draft,
activation, pick-up lock, the Housing Steward and the admin command from
rulings 8–12 of the [Round 26 plan](../planning/round26-capitals-housing-cleanup-plan.md)). This is the
single authoritative housing spec; it replaces the former tiered design
completely (no tiers, unlocks, upgrades, housing masks, faction pools or
decay; git history keeps the old text). Implementation: WP24, mod
`grug_housing` plus home travel in `grug_home`
([module guide](../technical/module-guide.md)).

A player places one fuelled **Claim Stone** and owns the map chunk it stands
in for as long as the stone burns. There are no private islands, royal land grants
or guild land.

Household furnishings, functional displays and their reset packing are specified
in [decorations.md](decorations.md).

## 1. The claim

- A claim is exactly **one map chunk** in x/z: **80 × 80 nodes** (Round 85
  ruling 6). Chunk column `cx = floor((x + 32) / 80)` for a node coordinate
  x (the engine's chunksize 5), nodes `80 cx − 32 … 80 cx + 47`, the same in
  z; the claim is the chunk that holds the Claim Stone.
- It is a pure 2D column: it covers every y from **−100 upward without an
  upper limit**, whatever the stone's own height. Below y = −100 the ordinary
  rules of the column apply.
- One claim per player: each player owns at most one Claim Stone (§3).
- Each claim is one record in the claim registry (mod storage) with its id,
  owner, the stone's position, placement time, activation time and "paid
  until" timestamp (§4), and two fields a later round fills (the owner's
  kind, the home's name; empty since Round 85). The storage format is
  version 3 (Round 85); the game reads no other version: the 0.85.0 map
  reset clears the version 2 records of the old square (§3).
- **One claim per chunk.** A chunk that holds a claim record, a draft (§2a)
  or a claim whose fuel ran out included, takes no second stone until that
  stone is picked up, crumbles or is destroyed (§5). Claims in neighbouring
  chunks touch edge to edge; there is no extra spacing (ruling 5).
- **Seeing a claim** (fix 0.50.2 lane HOME, rulings H1–H4): inside a claim,
  exactly where §1 places it (to the node, from y −100 upwards), the
  location line under the minimap, the entry banner and the map window name
  it: "Your Home" for its owner, "<owner>'s Home" for everybody else, in
  every state (draft, active, expired); the territory line stays
  ([world_map.md](world_map.md) "Zone and town names"). Without the Claim
  Stone in hand the minimap frames the player's own claim in green and every
  other claim in yellow, one minimap pixel wide (about 7 nodes, rounded
  outward like the preview's red), no fill; with the stone in hand the
  placement preview (§2) shows instead. The map window draws no claims; it
  shows only the activated stone's waypoint (§8).

## 2. Placement

- **Height** (ruling 2): the stone may stand at any y ≥ −100 (the T1 rock
  band), never in T2 rock or deeper.
- **Where: claim ground** ([Round 85 plan](../planning/round85-plan.md)
  rulings 6 and 14; the user's
  [housing rework concept](../planning/housing-rework-concept.md) §2.1): the
  claim's chunk must be **claim ground** for the claimant's faction, as a
  whole; a chunk that is not wholly claim ground is no claim ground (no
  slivers). The game decides it per chunk once per world plan, as the
  **claim mask** (`grug_housing/claim_mask.lua`; its stored copy:
  [claim-mask-format.md](../technical/claim-mask-format.md)). A chunk is
  claim ground for a faction when all of these hold; a refusal names the
  first rule that fails, in this order:
  1. **Own ground** (a lattice of 25 columns first, every column in rule 5):
     every column lies in the faction's own home territory, in its seven
     level 11–30 zones (`world_zones.md` §8) or its three capital zones, on
     land, lake, river or bay water; not on the coastal belt (it belongs to a
     zone all the same), the sea or protected deep water (bay water 24 nodes
     or more off the coast, Round 51), and not on a town or landmark column.

     | Faction | Level 11–20 | Level 21–30 | Capital zones |
     |---|---|---|---|
     | Accord | Copperfell Foothills, Goldmead Vale, Starbough Vale | Frostbarrow Shelf, Whitebridge Shire, Lorindor, Moonfall Wood | Dur Brannoc, Highcourt, Lethariel |
     | Throng | Mournfen, Redtusk Savanna, Raincall Basin | Ossuary Reach, Speargrass Reach, Whispering Reedlands, Totemwater Reach | Nhal Veyr, Gor Drazhak, Kezamba |

     A chunk may span several such zones, for example across an 11–20 /
     21–30 border.
  2. **No settlement within 16 nodes** (ruling 27): the protected core box
     of a POI, village or camp (§9) or the hard footprint of a capital, start
     town or landmark (`world.md` §2 R1), counted in x and in z. The wide
     blend envelopes around settlements are no barrier.
  3. **No road:** no column of a road's protected corridor (§9: the half
     width and 1 node beside it, in x/z).
  4. **No authored spawn content:** no 32 × 32 cell of a camp's spawn
     region, and no zone leader's spot, quest place or named rare's route
     point within 16 nodes (in x and in z).
  5. Rule 1 on every column of the chunk.
  6. **The capital ring:** a chunk with ground in a capital zone keeps one
     whole chunk of distance to the capital's protected city (inside the wall
     line, the wall with its gatehouses and the 21-node band,
     `wp40/capital_protection.lua`): no chunk that holds a column of it may be
     among its eight neighbours.

  Steep ground is neither filtered nor marked (Round 85 ruling 15). On the
  production seed the mask holds 366 chunks for The Accord and 373 for The
  Throng (the capacity study's counts). **Which mask:** a placement follows
  the mask of the running version (Round 85 ruling 20); between map resets a
  changed mask clears no standing claim.
- **The quota** (Round 85 ruling 16): for every mob kind a quest names (a
  recipe kind with `quest_target`) in a zone that can hold claim ground, the
  kind's ground is the 32 × 32 spawn cells of all its regions in its zone,
  counted in node columns; a claim takes the columns of those cells inside
  its chunk. A placement is refused when the columns taken by all placed claims
  (drafts and expired ones included) would exceed half of the kind's ground.
  Ground that can never be claimed counts as free. A cell on a zone border
  that both zones' region maps hold counts for the kinds of both. Nothing is
  reserved in advance: players choose which half.
- **Exact.** The mask judges every column of a chunk; nothing is sampled.
- **No housing masks** (ruling 4). The former authored housing masks and the
  four coastal housing areas are removed; mapgen generates no housing-specific
  ground. Eligibility is the rule above only.
- **Other claims**: the chunk may hold no other claim, active, expired or a
  draft (§1).
- **Arrival cube** (ruling 6): the 3 × 3 × 3 cube directly above the stone
  (x and z ± 1 around it, y + 1 to y + 3) must be air when the stone is
  placed. The stone stands at least one node inside its chunk's edge, so the
  cube lies in the claim. While the stone stands, nothing can be placed into that cube, by
  anyone, and liquids cannot flow into it. A `buildable_to` node that lands
  in the cube later (snow, for example) can be dug under the ordinary claim
  rules (Round 26 ruling 12); placing into the cube stays refused.
- **Refusals** name the rule that refused, in one line each, in this order:
  below y = −100; no faction; the player's stone already placed; no claim
  mask (its build failed: every placement is refused, never allowed); the
  chunk is no claim ground (the first rule of the mask that fails, its own
  line per rule); the chunk already holds a claim; the quota ("This claim
  square (80 x 80) would put more than half of <area> under claims; …", the
  quest kind's spawn area by its name: the chunk's own share of the kind's
  ground would take the claimed part above half);
  the stone on the chunk's edge; the arrival cube not empty.
- Placing makes a **draft** (§2a). There is no placing limit.
- **Placement preview** (fix 0.50.2; **known to be wrong since 0.85.0**,
  [Round 85 plan](../planning/round85-plan.md) ruling 23): while a player
  with a faction holds the Claim Stone, the minimap shows in
  semi-transparent red the ground the mask's column rule (rules 1 and 5)
  refuses for that faction (the other faction, level 1–10 and 31+ zones,
  land that is not the faction's home, the coastal belt, protected water and
  the sea, town and landmark columns) and the settlement cores and hard
  footprints widened by the 16 nodes (rule 2), the column part judged per
  minimap pixel (about 6.7 nodes) and widened by one pixel, the settlements
  rounded outward; every claim (drafts, active and expired) as its whole
  chunk in the same red; and an
  80 × 80 green square **centred on the player** on the arrow; a switched-off
  minimap appears meanwhile ([world_map.md](world_map.md) "Minimap", claim
  mode). **It does not follow the chunk rule:** roads (rule 3), camps,
  leaders' spots, quest places and rares' route points (rule 4), the
  capital ring (rule 6) and the quota do not show, and the green square is
  not the chunk the stone would claim: it moves with the player, while the
  claim is the grid's chunk that holds the stone. So ground without red can
  still be refused. The placement check above alone
  decides, with its messages. Round 86 replaces the preview with one by
  whole chunks ([Round 85 plan](../planning/round85-plan.md#carry-overs)).

## 2a. Draft and activation

- **The draft** (Round 26 ruling 8): a placed stone first stands as the
  half-transparent node `grug_housing:claim_stone_draft`. It holds its
  chunk: no other stone may be placed there, and it counts for the quota
  until it crumbles or is picked up (§2). It protects nothing: no claim
  protection, no interaction guard, no spawn guard, and natural renewal runs.
  It keeps the arrival-cube guard, though: no placing, liquid flow or renewal
  into the cube. Nobody can dig or blow it up; the owner
  can pick it up at any time through its form, with no lock.
- **Crumbling:** a draft that is not activated within **300 s (5 min)** of
  placing crumbles, whether the owner is online or not. The owner then needs
  a new stone and gets it from the Housing Steward at once.
- **Activation** (ruling 9): the draft form's Activate button pays exactly
  **5 lumps** at once from the main inventory and the bags (charcoal
  first, then coal lumps, then Anthracite, which counts one lump here, Round
  78 ruling 9) and starts fuel and protection. Further fuel goes through the fuel
  slot (§4); the draft's slot refuses fuel.
- A draft cannot be the travel-home target (§8).

## 3. The Claim Stone item

- Item `grug_housing:claim_stone`. It is not craftable and has no price.
- **One stone per player** (ruling 7). The **Housing Steward** in every
  capital hands it out free from level 20, only while the player has none,
  neither carried nor placed.
- **Soulbound** (ruling 8): it lies anywhere an ordinary item may lie in
  the carried inventory, the hotbar, `main` and every bag (Round 49 ruling
  3), and nowhere else: not in chests, stations, equipment slots, trades,
  the trash or mail. The give helper and the sort treat it like any other
  item. It stays in the inventory on death. Dropping it destroys it; a new
  one comes from the Housing Steward.
- **Map reset** (Round 41 ruling 9, the
  [upgrade contract](../technical/upgrade-contract.md) §3): every claim goes
  with the old map. A placed stone does not come back into the inventory; its
  owner gets a new one from the Housing Steward, as after losing it, and the
  travel home falls back to the innkeeper (§8). A carried stone stays. The
  claim's containers come back packed in the Claim Stone inventory (§3a).
  The 0.85.0 map reset (Round 85 ruling 4), which makes a claim one map
  chunk (§1), ends the old 101 × 101 claims the same way: none is
  converted or moved, their containers are packed from the old square, and
  every owner places the new stone under the new rules.
- It is placed like any block from a hotbar slot.
- **One lock only** (Round 26 ruling 10): for **12 hours (43 200 s)** after
  activation the stone cannot be picked up. There is no placing lock and no
  daily limit: after a pick-up or destruction the player may place and
  activate again at once. The former once-a-day limits are gone.

## 3a. Packed containers and the Claim Stone inventory

Round 50 (rulings 4–8 and 13–15, D5–D8 of the [Round 50 plan](../planning/round50-plan.md)).

- **Packing:** before a map reset empties the map, the migration tool packs
  every container (chests, locked chests, furnaces, bookshelves, vessels
  shelves, every node that holds items, empty ones too) in every claim's
  area from y −100 upward (§1; a claim placed before 0.85.0 in its old
  101 × 101 square) with its contents and fuel. Every container
  belongs to the claim's owner, whoever placed it. The stone's unburnt fuel comes back as
  charcoal of the same burn time, rounded up.
- **The Claim Stone inventory:** one per player, holding what was packed
  for that player. It shows as the **Belongings (N)** tab of the owner's
  stone form (§7.1) once the stone is activated, never while it is a draft.
  It is take-only (nothing goes in, nothing moves inside it), scrollable,
  and waits indefinitely. Picking the stone up or losing it keeps it; a
  later map reset adds to it.
- **Packed container:** one item, `grug_housing:packed_container`. Its
  tooltip names the container and its stack count ("Packed Chest, 14
  stacks"), up to eight of its stacks and how many more; it shows the
  container's own look. It is **soulbound** like the stone (§3), but
  dropping it is refused and it stays. Packed containers come only from
  the Claim Stone inventory, so containers never nest. The item carries
  only a reference to its contents, which wait in the housing storage
  (ruling 14), so inventories stay small, written books included.
- **Empty containers** come back as their nodes' plain items (an open
  chest as a chest, a lit furnace as a furnace), equal ones stacked
  (ruling 13).
- **Placing** one restores a normal container as any placement would
  (protection, the facing of a new placement) and fills it with exactly
  the packed contents, item data such as a written book's text included;
  the stored contents are then deleted. A placement that fails keeps the
  item and its contents. Whoever holds a packed container may place it
  (ruling 15); if its contents are gone, it is placed empty and the server
  logs a warning. A locked chest belongs to whoever places it. A furnace comes back unlit, its fuel and input in their
  slots, and starts when it is next used.
- **First start after the reset** (before anybody joins): items this
  version no longer has are removed from the packed containers. A
  container this version cannot restore, and the stacks beyond a list that
  became smaller, are moved into additional packed chests (D6), so nothing
  is lost; such a container that still exists (a station such as the Dual
  Furnace) also comes back as its plain item, like an empty one. A charcoal stack above its stack size is split.
- **Notices:** a player with waiting belongings is told at every join:
  "Belongings from the old map wait in your Claim Stone." The Housing
  Steward says the same (§7.2).

## 4. Fuel and upkeep

The stone burns fuel whether anybody is near it or not (ruling 10).

- **Accepted fuel:** coal lumps (`default:coal_lump`), charcoal
  (`grug_smelting:charcoal`) and Anthracite (`grug_materials:anthracite`,
  Round 47 ruling 12) only; coal lumps and charcoal burn equally long,
  Anthracite counts **1.5 lumps**. Coal blocks and every other fuel are
  refused.
- **Burn time:** one lump = **7 h 16 min = 26 160 s**, one Anthracite
  = **10 h 54 min = 39 240 s**. The cap is counted in time: **99 lumps'
  worth**, 99 × 26 160 s = 2 589 840 s ≈ 30 days of real time.
- **Paid until.** Inserted fuel is converted at once into a "paid until"
  timestamp in the claim registry (`os.time()` seconds):
  `paid_until = max(paid_until, now) + pieces × seconds per piece`. Protection only
  compares that timestamp with the wall clock: no mapblock has to be loaded
  and nothing is replayed. Offline time and server downtime count.
- `remaining = max(0, paid_until − now)`. The claim is **active** while
  `remaining > 0`.
- **Fuel-slot arithmetic** (the implementation's one source of truth):
  - the displayed stack is `ceil(remaining / 26 160)` lumps, so a partly
    burnt lump still shows as one;
  - new fuel is accepted while its whole time fits under the cap: pieces
    `= floor((99 × 26 160 − remaining) / seconds per piece)`; for lumps that
    is `99 − displayed stack`, as before Round 47. A piece that does not fit
    whole is refused with the room left ("Not enough room for one
    Anthracite …"), the rest of a stack comes back;
  - inserted fuel can never be taken out again;
  - on pick-up the owner gets `floor(remaining / 26 160)` whole lumps back
    as charcoal (coal lumps when `grug_smelting` is absent), whatever fuel
    paid the time; the partly burnt lump is lost. When the inventory is full, the returned lumps drop on the
    ground.
- Activation (§2a) pays its 5 lumps into the same timestamp. A draft's fuel
  slot refuses fuel.

## 5. Empty fuel and destruction

- **Empty fuel** (ruling 11): all claim protection ends at once. Anyone the
  ordinary world rules allow may dig, build and open doors and chests there
  (the enemy faction still may not build in home territory; roads stay
  protected, §9). The claim still blocks other claims until the stone is
  picked up or destroyed. The owner keeps the stone's settings, may still
  pick it up and may refuel it; refuelling makes the claim active again
  (ruling 20).
- **While fuelled** (ruling 12) only the owner can use the stone, and nobody
  can destroy it.
- **Without fuel** anyone may destroy it with a pick. The dig time depends on
  the pick tier:

  | Pick | T1 | T2 | T3 | T4 | T5 | T6 |
  |---|---:|---:|---:|---:|---:|---:|
  | Time to destroy | 60 s | 50 s | 40 s | 30 s | 20 s | 10 s |

  The hand and the skill hand cannot destroy it. A destroyed stone drops
  nothing (ruling 21); the claim ends and the player may fetch a new stone
  from the Housing Steward. A draft cannot be destroyed (§2a).
- **Pick-up** is owner-only and only through the stone's own interface (§7);
  it ends the claim and returns the stone and the whole unburnt lumps (§4). A
  draft can be picked up at any time; an activated stone not within 12 hours
  of its activation (§3).
- **Admin removal** (Round 26 ruling 12): `/claim_remove <player>`,
  `/claim_remove here` (the claim the admin stands in) or
  `/claim_remove orphans` (stone nodes within 16 nodes of the admin that have
  no registry row; registered claim centres are skipped), with the `server`
  privilege. An online owner gets the chat message "Your Claim Stone was
  removed by an admin…"; an offline owner sees it on the Character page and
  gets the travel-home fallback message at the next login (§8). The travel
  home falls back to the innkeeper, and nothing is refunded.

## 6. Permissions and protection

### 6.1 Permission levels

The owner keeps a permission list of player names on the stone (ruling 13).
Each name has one of two levels:

| Level | Allows |
|---|---|
| **Interact** | doors, trapdoors, gates, chests, furnaces and stations; sorting a chest |
| **Everything** | Interact plus building and digging; harvesting counts as digging; a chest's label and every container's upgrade |

The owner has every right. Everyone else has none inside an active claim.
Enemy-faction players still cannot build in home territory, whatever their
level. World protection wins over every permission, the owner's included
(§9).

### 6.2 Digging and placing

Inside an active claim the protection check refuses digging and placing for
anyone without the owner or Everything level. The engine asks for protection
only when digging and placing; §6.3 covers the rest.

### 6.3 Interaction protection

- Inside an active claim, every node with a right-click action or a node
  inventory gets one generic check, installed once at
  `register_on_mods_loaded` (ruling 18). Without permission the right-click is
  refused, and so are inventory put, take and move.
- Nodes whose form opens on the client (furnaces, some stations) may still
  show their form; taking and putting are refused.
- A short exception list exists, for example reading signs. Its exact content
  is an implementation detail.
- A chest's label and a container's upgrade (Round 67,
  [inventory](inventory_equipment.md) "Storage containers") ask the
  building check, as writing a sign does: the owner and Everything may, a
  draft or inactive claim protects nothing. A locked chest answers only its
  owner, inside a claim or not.
- The protection hint shows the claim reason: **"Home of <owner> –
  protected"**.
- Claim protection covers digging, placing and interaction only. Protection
  against explosions and fire, liquid inflow beyond the arrival cube and
  boundary outlines are not part of V1.

### 6.4 Renewal, spawns and falling nodes

- No natural renewal (wild plants, trees) inside an active claim (ruling 14);
  planted crops grow as usual. A draft protects nothing, so renewal and
  spawns run in it as on open ground.
- An expired claim renews under the normal rules, so an abandoned home
  overgrows (ruling 19; `farming.md`).
- No hostile mob spawns inside an active claim; mobs may still walk in.
  Expired claims spawn normally (ruling 24). Claims that cover every route
  point of one named rare suppress its spawn (`grug_mobs/rares.lua` picks a
  route point again each pass); accepted by the user (WP audit E12,
  2026-09-29). Since Round 85 no claim can be placed within 16 nodes of a
  route point, a leader's spot or a quest place, nor over a camp's cells
  (§2 rule 4).
- An idle, free-roaming aggressive mob walks away from an active claim, as it
  does from roads and villages (Round 69; the stone is also the respawn point
  now, §8): a tendency, not a wall. A mob in a fight is not pushed, a draft or
  an unfuelled claim pushes nobody, and a claim adds no spawn band around it. A
  mob whose spawn point lies on an active claim is pushed by no claim: it roams
  as before until the game removes it once no player stays near
  ([combat_stats.md](combat_stats.md), the push).
- Falling nodes follow the normal engine rules, except that one never lands
  in a live body's cell
  ([combat_stats.md](combat_stats.md#placement-in-combat-and-around-bodies)).
  Because the claim is unbounded upward, only permitted players can place
  anything above a home.
- Flying: there is no claim-specific flight rule. Home territory already
  restricts flying to the own faction (`mounts.md` §4.3).

## 7. Interfaces

### 7.1 The stone interface (owner only)

- **Draft form:** a live countdown to crumbling (redrawn every second), the
  Activate button (§2a), Pick up and Close. No permission list and no fuel
  until activated.

Once activated:

- The fuel slot (§4).
- The remaining time to the minute, counting the current fuel stack.
- The permission list (§6.1).
- "Set as home": makes the claim the travel-home target (§8).
- Pick-up (§5).
- A second tab, **Waypoints** (Round 45 PT9): the owner's discovered
  waystones, each with Travel (§8).
- A tab **Expeditions** (Round 72): the Expedition the owner may enter, with
  Enter from the stone (within the same reach), as on every waystone
  ([expeditions.md](expeditions.md) §4); with none, one line saying why. Below
  it, since Round 72.1, the owner's Expedition with its state and its leader's
  Finish or Cancel (§5 there). With four tabs they share the width.
- While belongings from an old map wait, a tab **Belongings (N)** (Round
  50): the Claim Stone inventory (§3a), four rows visible and scrollable,
  above the player's combined bag; shift-click takes into the inventory.

### 7.2 Housing Steward

A service NPC in every capital (rulings 7, 14; renamed from Housing Manager in
Round 26 ruling 11, internal role id `housing_manager`): the gate resident of
the capital's tailor service plot (`settlements.md`). It serves only its
capital's faction, hands out the stone (§3), and its dialog briefly explains
the upkeep, the 5-minute activation with 5 lumps and the 12-hour lock. The
map shows it with the Steward icon ([world_map.md](world_map.md)).

The dialog shows **Receive Claim Stone** only when the player can receive
one (Round 49 ruling 4); otherwise the reason stands in its place: "You
need level 20 to receive a Claim Stone.", "Your Claim Stone is already
placed." or "You already carry a Claim Stone." (in any list, a bag
included). A full inventory keeps the button: the click then refuses with
"Make room in your inventory for the Claim Stone." in red. After a
hand-out the dialog shows the green line and "You already carry a Claim
Stone." in place of the button. While belongings from an old map wait
(§3a), the dialog adds the line "Belongings from the old map wait in your
Claim Stone."

### 7.3 Character page status

Shown only once a player has received a stone for the first time, wherever
the player is. Times are whole minutes ("4 min", "< 1 min" in the last
minute); only the draft form (§7.1) counts seconds.

- draft: "Your Claim Stone is not active yet: activate it within 4 min or it
  crumbles" (example), in red;
- placed and fuelled: "Claim Stone fuel: 12 d 4 h 31 min" (example), in red
  when less than 24 h remain;
- placed, fuel empty: "Your Claim Stone needs fuel, anyone can access your
  home right now";
- destroyed: "Your Claim Stone has been destroyed";
- removed by an admin: "Your Claim Stone was removed by an admin";
- carried: "Your Claim Stone is in your inventory, not placed yet";
- none (dropped, or the draft crumbled): "You have no Claim Stone; ask a
  Housing Steward for a new one".

## 8. Home-stone travel

- The player's own Claim Stone can be the "travel home" target of
  [innkeeper home travel](home_travel.md), with the usual 30-minute cooldown
  (ruling 14). The owner sets it with "Set as home" in the stone interface;
  the map marks a claim home with the home icon at the stone ([home_travel.md](home_travel.md)). An expired claim still works as a
  target; a draft does not ("Activate your Claim Stone first").
- The arrival is the arrival cube (§2). If the cube is blocked, that one trip
  goes to the bound innkeeper instead, with a message, and the cooldown is
  charged.
- When the stone is picked up, destroyed or removed by an admin, the target
  falls back to the
  player's bound innkeeper (the starting-town innkeeper when none is bound),
  with a message; an offline player gets it at the next login (ruling 26).
  Binding an innkeeper also replaces a claim home.
- Death respawns at the same home, the Claim Stone included, with or without
  fuel (Round 69, retiring ruling 25). A respawn has no cooldown and no combat
  rule. If the cube is blocked or the area cannot be prepared, it ends at the
  innkeeper, then in the start pocket; the player is held until standing
  somewhere valid.
- Independently of the travel home, the activated stone is a waypoint, "Your
  Claim Stone", in every waystone's list, and its owner travels from it to
  the discovered waystones through the form's Waypoints tab (Round 45 PT9,
  [world.md](world.md) §6).

## 9. Relation to world protection

World protection (`world.md` §2) is evaluated independently of claims and
wins everywhere, for the claim owner too (ruling 17).

- **Roads** (ruling 15) are protected, their bridges and future waypoints
  included: sideways the road's half width plus 1 node on each side (Round
  28 ruling 1; primary 7 wide → 9 protected, secondary 5 → 7, trail 3 → 5),
  vertically ±5 nodes around the road surface. A claim's chunk holds no
  road column (Round 85, §2 rule 3).
- **POIs, villages and camps** (ruling 16) are protected in a box: their
  building core horizontally, and from 10 below the placement height to 10
  above the template's highest node vertically. A claim keeps 16 nodes
  from these boxes (§2, ruling 27).
- Hard-protected capitals, start towns and landmarks can never lie inside a
  claim; a claim keeps 16 nodes from their footprints too (§2).
- Protection hints name the protecting layer: "Road – protected", "Village –
  protected" and similar for world content, "Home of <owner> – protected" for
  a claim (`items_crafting.md` §3.0.4).
