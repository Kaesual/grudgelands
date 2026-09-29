# Round 25 — Claim Stone Housing (WP24), draft

Decided with the user on 2026-09-29. This replaces the tiered design in
[housing.md](../design/housing.md). The spec and design documents are
rewritten to this contract before implementation starts. **Status: rulings
1–14 fixed; the items under "Open for discussion" are not decided yet.
No implementation before the user's go-ahead.**

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
    - The stone keeps burning while nobody is near it.
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

## Open for discussion

- **Road, POI and camp protection:** a small protected band around roads
  (about ±5 nodes sideways and ±5 vertically) and around POIs, villages and
  camps, and how to represent it cheaply.
- **Interaction protection:** the implications of ruling 13 and possible
  simplifications.
- **Natural renewal in expired claims:** normal (overgrowth) or none.
- **Picking up a stone:** do unburnt whole lumps return to the owner?

## Lanes

To be cut after the open points are settled.
