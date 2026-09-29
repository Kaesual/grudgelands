# Round 25 — Claim Stone Housing (WP24)

Decided with the user on 2026-09-29. This replaces the tiered design in
[housing.md](../design/housing.md). The spec and design documents are
rewritten to this contract before implementation starts. **Status: rulings
1–29 fixed (2026-09-29); all lanes merged on local `main`, playtest pending
([completion](#completion-2026-09-29)).**

## Rulings

### Claim and placement

1. **One claim size.** A claim is exactly 101 × 101 nodes in x/z, ±50 around
   the Claim Stone. It is a pure 2D column: it protects from y = −100 upward
   without an upper limit, whatever the stone's own height. There are no
   tiers and no later unlocks.
2. **Placement height.** The stone may stand anywhere from y = −100 (the T1
   layer) upward, so it can never sit in T2 rock or deeper.
3. **Where.** The whole 101 × 101 square must lie in the claimant's own
   faction home territory, in zones of level 11–30 (seven zones per faction).
   Overlapping two such zones is fine, e.g. at an 11–20 / 21–30 border. The
   square may not touch:
   - a level 1–10 or level 31+ zone, or the other faction's territory;
   - a hard-protected area (capitals, start towns, landmarks);
   - a POI, village or camp area.

   The check may be conservative: coarse sampling that sometimes refuses a
   few columns near an edge is fine; reaching into a forbidden area is not
   (a tiny overlap only after checking with the user).
4. **Housing masks are removed.** The authored housing masks and coastal
   housing areas are deleted; eligibility follows ruling 3 only.
5. **Claims never overlap.** Two claims may touch edge to edge; there is no
   extra spacing.
6. **Arrival cube.** A placed stone keeps the 3 × 3 × 3 air cube directly
   above it free: the cube must be air when the stone is placed, nothing can
   be placed into it while the stone stands, and liquids cannot flow into it.

### The stone item

7. **One stone per player**, handed out free by the Housing Manager in every
   capital from level 20, only while the player has none (neither carried
   nor placed).
8. **Soulbound.** The stone cannot go into chests, bags, trades or mail, and
   it stays in the inventory on death. Dropping it destroys it; a new one
   comes from the Housing Manager. It is placed like any block from a hotbar
   slot.
9. **Once a day.** Each player may place a stone once per 24 hours and pick
   one up once per 24 hours (real time, counted separately).

### Upkeep

10. **Fuel.**
    - Only coal lumps and charcoal are accepted; they burn equally long.
      Coal blocks are refused.
    - There is one fuel slot of at most 99 items. A full slot lasts about one
      month of real time (one lump ≈ 7 h 16 min).
    - Inserted fuel cannot be taken out again. Topping up always works up to
      the full stack.
    - The stone keeps burning while nobody is near it. Inserted fuel becomes
      a "paid until" timestamp in the claim registry. Protection only compares
      that timestamp with the wall clock, so no mapblock has to be loaded and
      nothing is replayed. Server downtime counts.
    - When the owner picks the stone up, the unburnt whole lumps are returned.
      If the inventory is full, they drop on the ground.
11. **Empty fuel.**
    - All protection ends at once: anyone may dig, build and open doors and
      chests.
    - The claim still blocks other claims until the stone is picked up or
      destroyed.
    - The owner keeps the stone's settings and may still pick it up.
12. **Destruction.**
    - While fuelled, only the owner can use the stone, and nobody can destroy
      it.
    - Without fuel, anyone may destroy it with a pick: T1 60 s, T2 50 s,
      T3 40 s, T4 30 s, T5 20 s, T6 10 s. Hand and skill hand cannot.
    - Only the owner can pick it up, and only through the stone's own
      interface.

### Interfaces and travel

13. **Stone interface (owner only).**
    - A fuel slot.
    - The remaining time to the minute, counting the current fuel stack.
    - A permission list of player names, each with one of two levels:
      "Interact" (doors, trapdoors, gates, chests, furnaces, stations) or
      "Everything" (also building and digging; harvesting counts as digging).
    - Enemy-faction players still cannot build in the home territory,
      whatever their level.
14. **Other interfaces and travel.**
    - **Housing Manager:** its dialog briefly explains the upkeep and the
      once-a-day rule.
    - **Character page status,** shown only once a player has received a
      stone for the first time, wherever the player is:
      - the remaining time;
      - in red when less than 24 h remain;
      - "Your Claim Stone needs fuel, anyone can access your home right now"
        when the fuel is empty;
      - "Your Claim Stone has been destroyed" after destruction.
    - **Home stone:** the player's own Claim Stone can be the "travel home"
      target, with the usual 30-minute cooldown. The arrival is the arrival
      cube. When the stone is picked up or destroyed, the target falls back
      to the faction's default innkeeper, with a message.
    - **Flight:** there is no claim-specific flight rule. Home territory
      already restricts flying to the own faction.
    - **Natural renewal:** nothing regrows inside an active claim.

### World protection for roads and POIs

15. **Roads are protected.** This covers roads, their bridges and future
    waypoints.
    - Sideways: the road's own half width plus 3 nodes of terrain on each
      side. The open-world classes are `primary` (7 wide, so 13 protected),
      `secondary` (5 wide, 11) and `trail` (3 wide, 9).
    - Vertically: ±5 nodes around the road surface.
    - The check is analytic: distance to the planned centreline segment. Each
      segment is registered in the existing 128-node candidate grid. There is
      no rasterisation.
16. **POIs, villages and camps are protected.**
    - Horizontally: their building core.
    - Vertically: from 10 below the placement height up to 10 above the
      highest node the POI template places.
    - These are boxes in the same grid.
17. **Roads inside claims** are allowed, but the road corridor stays protected
    for everyone, the owner included. World protection wins. POI, village and
    camp areas stay excluded from claims (ruling 3).
18. **Interaction protection.**
    - The engine only checks protection for digging and placing. Inside an
      active claim, every node with a right-click action or a node inventory
      gets one generic check, installed once at `register_on_mods_loaded`:
      without permission the right-click is refused, and so are inventory put,
      take and move.
    - Nodes whose form opens on the client (furnaces, some stations) may still
      show their form; taking and putting are refused.
    - A short exception list exists, for example reading signs.
    - The protection hint shows the claim reason, e.g. "Home of <owner> –
      protected".
19. **Renewal in expired claims** follows the normal rules, so an abandoned
    home overgrows. Falling nodes use the normal engine rules. The upward
    unbounded claim already means only permitted players can place anything
    above a home.

### Follow-up rulings (2026-09-29, after Lanes D and F)

20. **Refuelling** an empty stone makes the claim active again.
21. **A destroyed stone drops nothing.**
22. **Capital zones are not eligible** for claims; only the seven L11–30
    zones per faction are.
23. **Water in claims.** Lakes, rivers and bay water inside an eligible zone
    may lie in a claim; the shelf and the ocean (no zone) may not.
24. **No hostile mob spawns inside an active claim.** Mobs may still walk
    in. Expired claims spawn normally.
25. **Respawn stays at the innkeeper.** Death respawns at the bound innkeeper
    even when the Claim Stone is the travel home.
26. **Travel fallback goes to the bound innkeeper.** After pick-up or
    destruction the travel home falls back to the player's bound innkeeper
    (the starting-town innkeeper when none is bound). Binding an innkeeper
    also replaces a claim home.

27. **Claim distance to settlements.** A claim may not touch the protected
    core box of a POI, village or camp (ruling 16) or the hard footprint of a
    town, capital or landmark, each widened by about 16 nodes. The wide blend
    envelopes around them are not a claim barrier.
28. **Engine growth continues in claims.** Only the natural renewal system is
    off in active claims; grass spread, saplings, cactus, papyrus and moss
    grow normally.
29. **Bridges keep ±5.** Pillars and cuts more than 5 nodes below a road
    surface stay unprotected.

The old spec's claim protection against explosions and fire, liquid inflow
beyond the arrival cube, and boundary outlines are not part of V1.

## Follow-up rulings after the first playtest (2026-09-29, for Round 26)

The user could pick the stone up right after placing it and was then locked
out of placing for 24 h; a destroyed stone would lock its owner out the same
way, and a fresh, empty stone was destroyable at once. These rulings replace
ruling 9 and refine rulings 10–12:

30. **Placing is a draft.** A placed, not yet activated stone reserves its
    square against other claims (so its activation is never blocked) but
    protects nothing. Only the owner can pick it up, at any time and without a
    lock; others cannot destroy it. It looks unfinished (half-transparent,
    like water). A draft that is not activated within **5 minutes** disappears
    and the owner may take a new stone from the Steward at once.
31. **Activation costs at least 5 lumps** (coal or charcoal, ≈ 36 h), paid at
    once through a button in the stone form. Activation starts protection;
    with fuel the stone cannot be destroyed.
32. **One lock only: 12 hours after activation the stone cannot be picked
    up.** There is no placing lock: after a pick-up, or after the stone was
    destroyed, the player may place and activate again at once (a destroyed
    stone needs a new one from the Steward).
33. **The Housing Manager is renamed Housing Steward** (display names, texts,
    docs).

## Lanes

**Interface contract** (`grug_housing`, owned by Lane A; B, C and D code
against it from the start):

- `grug_housing.claim_at(pos)` → claim or nil. The claim holds `id`,
  `owner`, `center`, `placed_at` and `paid_until`.
- `grug_housing.is_active(claim)`.
- `grug_housing.remaining_seconds(claim)`.
- `grug_housing.permission(claim, name)` → `"owner"`, `"everything"`,
  `"interact"` or nil.
- `grug_housing.player_claim(name)` → the player's claim or nil, plus a state:
  `never`, `carried`, `placed`, `destroyed` or `needs_stone`.
- `grug_housing.add_fuel(claim, count)`, `grug_housing.pick_up(player)`,
  `grug_housing.set_permission(claim, name, level)`.
- `grug_housing.register_on_claim_changed(fn)`.

| Lane | Scope | Depends on |
|---|---|---|
| **F — Spec and docs** | Rewrite `housing.md` to rulings 1–19. Update `items_crafting.md` (the stone item and fuel), `world_zones.md` and the mapgen docs (housing masks removed), the `world.md` protection section (roads, POIs), the WP24 and WP17 scopes in `work-package-scopes.md`, and `combat_stats.md`/`classes.md` if they mention claims. | — (first; short) |
| **A — Claim core** | The new `grug_housing` mod: registry (mod storage) and a claim grid index; placement validation (faction home zones L11–30 by conservative sampling, hard protection, POI areas, other claims, arrival cube free, y ≥ −100); `is_protected` with permissions; fuel as "paid until"; the soulbound stone item; the daily limits; destruction times; the arrival cube (no placing, no liquid inflow); no renewal in active claims; housing masks removed from the zone data | interface first |
| **B — Interaction protection** | Generic right-click and node-inventory guard for claims (ruling 18), the claim protection reason for the hint | A's interface |
| **C — Interfaces** | The stone formspec (fuel slot, remaining time, permission list, pick up); the Housing Manager in the six capitals (issuing, explanation text; check whether a capital service socket exists or one must be added); the character page status | A's interface |
| **D — Home stone** | The claim as the `grug_home` target, the 30-minute cooldown, arrival in the cube, fallback to the faction innkeeper | A's interface |
| **G — Claim spawn guard** | Ruling 24: hostile spawns refused inside active claims | A's interface |
| **A2 — Claim distance** | Ruling 27 on top of A and E; merged end-to-end smoke | A, E merged |
| **H — Capital required plots** | Required and named capital plots run all fallback passes before fill (load failure on ~1.3 % of seeds; D70) | — |
| **E — Road and POI protection** | Rulings 15–17: the segment corridor and POI boxes in the zone authority, hint reasons ("Road – protected", "Village – protected" and so on) | — (independent of housing) |

**Parallelisation.**
- F, A and E start together. B, C and D start as soon as A has committed the
  interface; they may work against a stub until then.
- Merge order: F, A, then B/C/D in any order, each merged onto current main.
  E merges whenever it is ready.
- Every lane gets an independent review. Engine runs are short (≤5 min).
  Mapgen-touching work (A's mask removal, E's data export) runs no PUC.

## Completion (2026-09-29)

All lanes are merged on local `main` (head `7270feb3`); no push (the user
pushes). Coordinator: Claude Opus 5.5.

| Lane | Merge | Evidence |
|---|---|---|
| F — spec and docs | `d6122c96` | [housing.md](../design/housing.md), [world.md](../design/world.md) §2 R1b |
| A — claim core | `78f828a8` | `tools/r25_claim_core/evidence` |
| B — interaction protection | `d9774cc9` | `tools/r25_interaction/evidence` |
| D — home stone | `86d60b29` | `tools/r25_home_stone/evidence` |
| C — interfaces | `fb24a08e` | `tools/r25_interfaces/evidence` |
| G — claim spawn guard | `2b760593` | `tools/r25_spawn_guard/evidence` |
| E — road and POI protection | `c79827e4` | `tools/r25_road_poi/evidence` |
| A2 — claim distance | `280888ec` | `tools/r25_claim_distance/evidence` |
| H — capital required plots | `9949e5b9` (wording `7270feb3`) | `tools/r25_capital_plots/results` |

Every lane was independently reviewed (Opus). B, D, G and A2 passed without
fixes (B's Iron Sign exception was a one-line coordinator fix, `b7b24546`);
A, C, E, F and H had review fix rounds, and E's fix round plus the B/E merge
resolution got a second review. Final gate on merged main: all thirteen R24/R25
fixtures and pins pass, and the claim-core (42 + 4 checks, two boots) and
end-to-end interface (44 checks) engine probes pass. Synchronized to Luanti on
2026-09-29.

**What the player gets:** [housing.md](../design/housing.md) is the spec. In
short: one free, soulbound Claim Stone from the Housing Manager in each
capital from level 20; a 101 × 101 claim column in the own L11–30 home zones,
fuelled with coal or charcoal; Interact/Everything permissions; right-click
and inventory protection; the stone as travel home; no hostile spawns in
active claims. Roads, bridges and POI, village and camp cores are now
protected for everyone ([world.md](../design/world.md) §2 R1b). The housing
masks are gone. The capital planner places every required and named building
before fill ([settlements.md](../design/settlements.md)).

### Measured comparisons

- **`is_protected` with housing** (LuaJIT fixture, 2000 positions): +26 ns
  with 0 claims and +84 ns with 50 claims
  (`tools/r25_claim_core/evidence` at Lane A; the lane report gives +22–29
  and +72–84 ns over repeated runs). The fixture re-run after Lane A2 records
  +54 and +84 ns on a different set of 50 claims
  (`tools/r25_claim_core/evidence/fixture.txt`).
- **World-protection check with roads and POIs** (seed 4242424242, four
  point sets): 0.85–1.16 µs without the road/POI layer, 1.05–1.69 µs in the
  first Lane E version (`a648066c`), 1.21–1.36 µs after the early-outs.
  Against the first version, points on roads are +29 % and the random, far
  and deep (far above or below a road) sets are −10 %, −12 % and −28 %
  (`tools/r25_road_poi/evidence/bench*.txt`).
- **Placement validation:** about 10 ms (census mean 9.4–9.9 ms; engine
  probe 9.4 ms).
- **Eligible home spots** (1574 home-faction lattice centres, seed
  4242424242): 443 → 550 with the ruling-27 distance instead of the blend
  envelopes (`tools/r25_claim_distance/evidence/census.txt`).
- **Capitals:** load failures 4 of 300 seeds on main (1.3 %) → 0 of 200;
  named-building drops 110 → 2 on the same 200 seeds. The layout changes on
  52–80 % of 120 seeds per capital and on all of them for Kezamba; a capital
  whose buildings all fit their own quarter in pass 1 stays byte-identical.
  CPU time per seed is unchanged (`tools/r25_capital_plots/results`).

### Known limits and notes

- Engine growth ABMs (grass spread, saplings, cactus, papyrus, moss) run in
  active claims; only the natural renewal system is off there (ruling 28).
- Bridge pillars and cuts more than 5 nodes below the road surface are not
  protected (ruling 29).
- Housing Managers appear only in a fresh world.
- Existing worlds rebuild the layout cache and the preparation identity
  (capital layouts changed).
- Rare named-building drops remain where a capital quarter runs out of
  capacity (2 in 200 seeds). The lever is the organic wall line in the
  [BACKLOG](../../BACKLOG.md#round-25-carry-overs).
- Further carry-overs (admin removal of claims, snow in the arrival cube,
  touching claims and rare routes, dyadic road profiles) are in
  [BACKLOG](../../BACKLOG.md#round-25-carry-overs).

### Playtest checklist (fresh world)

1. **Level 20 and the Housing Manager:** reach level 20 (play, or
   `/xp give <name> <amount>` with the server privilege). In your capital,
   find the Housing Manager: the gate resident of the tailor plot, marked "+"
   on the map. Its dialog explains fuel and the once-a-day rule.
2. **Receive the stone:** "Receive Claim Stone" gives exactly one. It cannot go
   into a chest or bag, stays on death, and dropping it destroys it (a new
   one comes from the Manager). The Character page shows "Your Claim Stone is
   in your inventory, not placed yet".
3. **Refused placement:** try to place it near a village, a start town or in
   an L1–10 zone. It is refused with a reason.
4. **Accepted placement:** place it in an L11–30 zone of your faction, clear
   of settlements and with 3 × 3 × 3 air above it. Open it and add coal or
   charcoal; the form shows the remaining time to the minute, and inserted
   fuel cannot be taken back.
5. **Character page:** the fuel time shows there from anywhere, in red below
   24 h.
6. **Permissions** (second player, if available): without permission the
   guest cannot dig, build or open anything. With "Interact" doors, chests,
   furnaces and stations work, digging does not. With "Everything" the guest
   can dig and build too.
7. **Stranger hint:** as a stranger, a chest, a door and a furnace are
   refused with "Home of <owner> – protected" (a furnace form may still
   open, but taking and putting are refused). Signs can still be read.
8. **Roads:** where a road runs through the claim, digging on the road or
   within 3 nodes beside it is refused for the owner too: "Road – protected".
   Building next to that corridor works.
9. **Travel home:** "Set as home" in the stone form, walk away, then use
   **Return home** on the Map tab (30-minute cooldown). You arrive in the
   arrival cube above the stone; the map marks the claim home with "H".
10. **Pick up:** "Pick up stone" returns the unburnt whole lumps (on the
    ground when the inventory is full). The travel home falls back to your
    innkeeper with a message. A second pick-up or placement within 24 h is
    refused.
11. **No spawns:** at night, no hostile mobs appear inside an active claim,
    although mobs from outside may walk in.
12. **Settlement cores:** digging in a village, camp or POI core is refused
    with "Village – protected" (or "Camp", "Point of interest").
13. **Capitals:** Kezamba and the other capitals look sane; their layouts
    changed this round.
14. **Dragons** (optional, late game): dragon breath patches (scorch, rime)
    still appear in the dragon arenas.
