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
  owner, centre, placement time, activation time and "paid until" timestamp
  (§4). The storage format is version 2; fresh worlds only, there is no
  reader for Round 25 saves.
- Claims never overlap. Two claims may touch edge to edge; there is no extra
  spacing (ruling 5). A draft (§2a) and a claim whose fuel ran out still block
  other claims until the stone is picked up, crumbles or is destroyed (§5).

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
  anyone, and liquids cannot flow into it. A `buildable_to` node that lands
  in the cube later (snow, for example) can be dug under the ordinary claim
  rules (Round 26 ruling 12); placing into the cube stays refused.
- Placing makes a **draft** (§2a). There is no placing limit.

## 2a. Draft and activation

- **The draft** (Round 26 ruling 8): a placed stone first stands as the
  half-transparent node `grug_housing:claim_stone_draft`. It reserves its
  square: the overlap check of other placements counts it (the 16-node
  margin applies to settlements only, §2). It protects nothing: no claim
  protection, no interaction guard, no spawn guard, and natural renewal runs.
  It keeps the arrival-cube guard, though: no placing, liquid flow or renewal
  into the cube. Nobody can dig or blow it up; the owner
  can pick it up at any time through its form, with no lock.
- **Crumbling:** a draft that is not activated within **300 s (5 min)** of
  placing crumbles, whether the owner is online or not. The owner then needs
  a new stone and gets it from the Housing Steward at once.
- **Activation** (ruling 9): the draft form's Activate button pays exactly
  **5 lumps** at once from the main inventory (charcoal first, then coal
  lumps) and starts fuel and protection. Further fuel goes through the fuel
  slot (§4); the draft's slot refuses fuel.
- A draft cannot be the travel-home target (§8).

## 3. The Claim Stone item

- Item `grug_housing:claim_stone`. It is not craftable and has no price.
- **One stone per player** (ruling 7). The **Housing Steward** in every
  capital hands it out free from level 20, only while the player has none,
  neither carried nor placed.
- **Soulbound** (ruling 8): it cannot go into chests, bags, trades or mail,
  and it stays in the inventory on death. Dropping it destroys it; a new one
  comes from the Housing Steward.
- It is placed like any block from a hotbar slot.
- **One lock only** (Round 26 ruling 10): for **12 hours (43 200 s)** after
  activation the stone cannot be picked up. There is no placing lock and no
  daily limit: after a pick-up or destruction the player may place and
  activate again at once. The former once-a-day limits are gone.

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
  - on pick-up the owner gets `floor(remaining / 26 160)` whole lumps back
    as charcoal (coal lumps when `grug_smelting` is absent); the partly burnt
    lump is lost. When the inventory is full, the returned lumps drop on the
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
  planted crops grow as usual. A draft protects nothing, so renewal and
  spawns run in it as on open ground.
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

- **Draft form:** a live countdown to crumbling (redrawn every second), the
  Activate button (§2a), Pick up and Close. No permission list and no fuel
  until activated.

Once activated:

- The fuel slot (§4).
- The remaining time to the minute, counting the current fuel stack.
- The permission list (§6.1).
- "Set as home": makes the claim the travel-home target (§8).
- Pick-up (§5).

### 7.2 Housing Steward

A service NPC in every capital (rulings 7, 14; renamed from Housing Manager in
Round 26 ruling 11, internal role id `housing_manager`): the gate resident of
the capital's tailor service plot (`settlements.md`). It serves only its
capital's faction, hands out the stone (§3), and its dialog briefly explains
the upkeep, the 5-minute activation with 5 lumps and the 12-hour lock. The
map shows it with a "+" marker.

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
  the map marks a claim home with "H". An expired claim still works as a
  target; a draft does not ("Activate your Claim Stone first").
- The arrival is the arrival cube (§2). If the cube is blocked, that one trip
  goes to the bound innkeeper instead, with a message, and the cooldown is
  charged.
- When the stone is picked up, destroyed or removed by an admin, the target
  falls back to the
  player's bound innkeeper (the starting-town innkeeper when none is bound),
  with a message; an offline player gets it at the next login (ruling 26).
  Binding an innkeeper also replaces a claim home.
- Death always respawns at the bound innkeeper, even when the Claim Stone is
  the travel home (ruling 25).

## 9. Relation to world protection

World protection (`world.md` §2) is evaluated independently of claims and
wins everywhere, for the claim owner too (ruling 17).

- **Roads** (ruling 15) are protected, their bridges and future waypoints
  included: sideways the road's half width plus 1 node on each side (Round
  28 ruling 1; primary 7 wide → 9 protected, secondary 5 → 7, trail 3 → 5),
  vertically ±5 nodes around the road surface. Roads may run through a
  claim; the road corridor stays protected for everyone there.
- **POIs, villages and camps** (ruling 16) are protected in a box: their
  building core horizontally, and from 10 below the placement height to 10
  above the template's highest node vertically. A claim keeps 16 nodes
  from these boxes (§2, ruling 27).
- Hard-protected capitals, start towns and landmarks can never lie inside a
  claim; a claim keeps 16 nodes from their footprints too (§2).
- Protection hints name the protecting layer: "Road – protected", "Village –
  protected" and similar for world content, "Home of <owner> – protected" for
  a claim (`items_crafting.md` §3.0.4).
