# Housing: Claim Stones

Decided 2026-09-29 (Round 25, rulings 1–29 of the
[Round 25 housing plan](../planning/round25-housing-plan.md)). This is the
single authoritative housing spec; it replaces the former tiered design
completely (no tiers, unlocks, upgrades, housing masks, faction pools or
decay; git history keeps the old text). Implementation: WP24, mod
`grug_housing` plus home travel in `grug_home`
([module guide](../technical/module-guide.md)).

A player places one fuelled **Claim Stone** and owns the land around it for
as long as the stone burns. There are no private islands, royal land grants
or guild land.

## 1. The claim

- A claim is exactly **101 × 101 nodes** in x/z, ±50 around the Claim Stone
  (ruling 1).
- It is a pure 2D column: it covers every y from **−100 upward without an
  upper limit**, whatever the stone's own height. Below y = −100 the ordinary
  rules of the column apply.
- One claim per player: each player owns at most one Claim Stone (§3).
- Each claim is one record in the claim registry (mod storage) with its id,
  owner, centre, placement time and "paid until" timestamp (§4).
- Claims never overlap. Two claims may touch edge to edge; there is no extra
  spacing (ruling 5). A claim whose fuel ran out still blocks other claims
  until its stone is picked up or destroyed (§5).

## 2. Placement

- **Height** (ruling 2): the stone may stand at any y ≥ −100 (the T1 rock
  band), never in T2 rock or deeper.
- **Where** (ruling 3): the whole 101 × 101 square must lie in the
  claimant's **own faction home territory, in its level-11–30 zones**. These
  are seven zones per faction (`world_zones.md` §8); capital zones are not
  eligible (ruling 22):

  | Faction | Level 11–20 | Level 21–30 |
  |---|---|---|
  | Accord | Copperfell Foothills, Goldmead Vale, Starbough Vale | Frostbarrow Shelf, Whitebridge Shire, Lorindor, Moonfall Wood |
  | Throng | Mournfen, Redtusk Savanna, Raincall Basin | Ossuary Reach, Speargrass Reach, Whispering Reedlands, Totemwater Reach |

  The square may span two such zones, for example across an 11–20 / 21–30
  border. It may not touch:
  - a level-1–10 or level-31+ zone, a capital zone or the other faction's
    territory;
  - **within 16 nodes** (ruling 27), the protected core box of a POI,
    village or camp (§9) or the hard footprint of a capital, start town or
    landmark (`world.md` §2 R1). The 16 nodes count in x and in z. The wide
    blend envelopes around settlements are no claim barrier.

  **Water** (ruling 23): lakes, rivers and bay water inside an eligible zone
  may lie in a claim. The coastal shelf may not, although it belongs to a
  zone; the ocean has no zone and may not either (`world.md` §2b).
- **Conservative check.** The placement check may sample coarsely and refuse
  a few legal columns near an edge. It must never let a claim reach into a
  forbidden area. The sampling step is an implementation detail; any tiny
  permitted overlap needs the user's approval first.
- **No housing masks** (ruling 4). The former authored housing masks and the
  four coastal housing areas are removed; mapgen generates no housing-specific
  ground. Eligibility is the rule above only.
- **Other claims**: the square may not overlap another claim, active or
  expired (§1).
- **Arrival cube** (ruling 6): the 3 × 3 × 3 cube directly above the stone
  (x and z ± 1 around it, y + 1 to y + 3) must be air when the stone is
  placed. While the stone stands, nothing can be placed into that cube, by
  anyone, and liquids cannot flow into it.
- Placing also needs the daily placement allowance (§3).

## 3. The Claim Stone item

- Item `grug_housing:claim_stone`. It is not craftable and has no price.
- **One stone per player** (ruling 7). The **Housing Manager** in every
  capital hands it out free from level 20, only while the player has none,
  neither carried nor placed.
- **Soulbound** (ruling 8): it cannot go into chests, bags, trades or mail,
  and it stays in the inventory on death. Dropping it destroys it; a new one
  comes from the Housing Manager.
- It is placed like any block from a hotbar slot.
- **Once a day** (ruling 9): each player may place a stone once per 24 hours
  and pick one up once per 24 hours, real time. The two limits are counted
  separately.

## 4. Fuel and upkeep

The stone burns fuel whether anybody is near it or not (ruling 10).

- **Accepted fuel:** coal lumps (`default:coal_lump`) and charcoal
  (`grug_smelting:charcoal`) only; both burn equally long. Coal blocks and
  every other fuel are refused.
- **Burn time:** one lump = **7 h 16 min = 26 160 s**. The stone has one fuel
  slot of at most 99 items; a full slot lasts 99 × 26 160 s = 2 589 840 s
  ≈ 30 days of real time.
- **Paid until.** Inserted fuel is converted at once into a "paid until"
  timestamp in the claim registry (`os.time()` seconds):
  `paid_until = max(paid_until, now) + lumps × 26 160`. Protection only
  compares that timestamp with the wall clock: no mapblock has to be loaded
  and nothing is replayed. Offline time and server downtime count.
- `remaining = max(0, paid_until − now)`. The claim is **active** while
  `remaining > 0`.
- **Fuel-slot arithmetic** (the implementation's one source of truth):
  - the displayed stack is `ceil(remaining / 26 160)` lumps, so a partly
    burnt lump still shows as one;
  - new fuel is accepted up to `99 − displayed stack`; topping up always
    works up to the full stack;
  - inserted fuel can never be taken out again;
  - on pick-up the owner gets `floor(remaining / 26 160)` whole lumps back;
    the partly burnt lump is lost. When the inventory is full, the returned
    lumps drop on the ground.
- Which fuel item the slot shows and returns is an implementation detail.

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
  from the Housing Manager.
- **Pick-up** is owner-only and only through the stone's own interface (§7);
  it ends the claim and returns the stone and the whole unburnt lumps (§4).

## 6. Permissions and protection

### 6.1 Permission levels

The owner keeps a permission list of player names on the stone (ruling 13).
Each name has one of two levels:

| Level | Allows |
|---|---|
| **Interact** | doors, trapdoors, gates, chests, furnaces and stations |
| **Everything** | Interact plus building and digging; harvesting counts as digging |

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
- The protection hint shows the claim reason: **"Home of <owner> –
  protected"**.
- Claim protection covers digging, placing and interaction only. Protection
  against explosions and fire, liquid inflow beyond the arrival cube and
  boundary outlines are not part of V1.

### 6.4 Renewal, spawns and falling nodes

- No natural renewal (wild plants, trees) inside an active claim (ruling 14);
  planted crops grow as usual.
- An expired claim renews under the normal rules, so an abandoned home
  overgrows (ruling 19; `farming.md`).
- No hostile mob spawns inside an active claim; mobs may still walk in.
  Expired claims spawn normally (ruling 24).
- Falling nodes follow the normal engine rules. Because the claim is unbounded
  upward, only permitted players can place anything above a home.
- Flying: there is no claim-specific flight rule. Home territory already
  restricts flying to the own faction (`mounts.md` §4.3).

## 7. Interfaces

### 7.1 The stone interface (owner only)

- The fuel slot (§4).
- The remaining time to the minute, counting the current fuel stack.
- The permission list (§6.1).
- "Set as home": makes the claim the travel-home target (§8).
- Pick-up (§5).

### 7.2 Housing Manager

A service NPC in every capital (rulings 7, 14): the gate resident of the
capital's tailor service plot (`settlements.md`). It serves only its
capital's faction, hands out the stone (§3), and its dialog briefly explains
the upkeep and the once-a-day rule. The map shows it with a "+" marker.

### 7.3 Character page status

Shown only once a player has received a stone for the first time, wherever
the player is:

- placed and fuelled: "Claim Stone fuel: 12 d 4 h 31 min" (example), in red
  when less than 24 h remain;
- placed, fuel empty: "Your Claim Stone needs fuel, anyone can access your
  home right now";
- destroyed: "Your Claim Stone has been destroyed";
- carried: "Your Claim Stone is in your inventory, not placed yet";
- none (dropped): "You have no Claim Stone; ask a Housing Manager for a new
  one".

## 8. Home-stone travel

- The player's own Claim Stone can be the "travel home" target of
  [innkeeper home travel](home_travel.md), with the usual 30-minute cooldown
  (ruling 14). The owner sets it with "Set as home" in the stone interface;
  the map marks a claim home with "H". An expired claim still works as a
  target.
- The arrival is the arrival cube (§2). If the cube is blocked, that one trip
  goes to the bound innkeeper instead, with a message, and the cooldown is
  charged.
- When the stone is picked up or destroyed, the target falls back to the
  player's bound innkeeper (the starting-town innkeeper when none is bound),
  with a message; an offline player gets it at the next login (ruling 26).
  Binding an innkeeper also replaces a claim home.
- Death always respawns at the bound innkeeper, even when the Claim Stone is
  the travel home (ruling 25).

## 9. Relation to world protection

World protection (`world.md` §2) is evaluated independently of claims and
wins everywhere, for the claim owner too (ruling 17).

- **Roads** (ruling 15) are protected, their bridges and future waypoints
  included: sideways the road's half width plus 3 nodes on each side
  (primary 7 wide → 13 protected, secondary 5 → 11, trail 3 → 9), vertically
  ±5 nodes around the road surface. Roads may run through a claim; the road
  corridor stays protected for everyone there.
- **POIs, villages and camps** (ruling 16) are protected in a box: their
  building core horizontally, and from 10 below the placement height to 10
  above the template's highest node vertically. A claim keeps 16 nodes
  from these boxes (§2, ruling 27).
- Hard-protected capitals, start towns and landmarks can never lie inside a
  claim; a claim keeps 16 nodes from their footprints too (§2).
- Protection hints name the protecting layer: "Road – protected", "Village –
  protected" and similar for world content, "Home of <owner> – protected" for
  a claim (`items_crafting.md` §3.0.4).
