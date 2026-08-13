# Boats — Water Travel, Ocean Danger and the Dragon Islands

Decided 2026-08-13. **Nothing here is built yet**: this file is the spec a
later work package implements, not a description of shipped behaviour. It
replaces `TODO-design-boats.md`, which is deleted.

Neighbouring rules: ocean classes and deep-sea danger in `world.md` §2b, the
authored channel geometry and both offshore islands in `world_zones.md` §7 and
§9.3, waypoints and the Home Stone in `world.md` §6, riding in `mounts.md`, the
two recipes in `items_crafting.md` §3.0.5 and the Kraken Guard in
`biomes_mobs.md` §3.

## 1. Two boats, and who may build them

- **The base boat is a universal base recipe** (`items_crafting.md` §3.0.3):
  five `group:wood`, craftable by every character from level 1. No trainer,
  vendor, quest, level or profession is involved. Water travel is not a
  reward and the sea is not a gated resource.
- **The improved boat** is built from one base boat plus universal T4
  materials. Only its *recipe* is gated: a character learns it once from a
  **shipwright** (§2), from character level 30.
- **Boat building belongs to no profession.** It consumes neither of the two
  main profession slots (`professions.md` §1), and it is not a universal
  skill with a trainer ladder like Cooking, First Aid or Riding. The
  improved-boat unlock is a single permanent per-character flag in player
  meta, in the same spirit as the riding steps of `mounts.md` §1.
- Player-facing, that flag is one entry named **Improved Boat**, and it
  covers **crafting and driving** the improved boat. It never affects the
  base boat.

*Rationale*: the two dragon islands are reachable only by boat
(`world_zones.md` §6), and both apex camps are one of the three decided
routes to the opposing faction's exclusive G2 gem (`world_zones.md` §11). A
purchase price, profession or high level gate in front of a boat would put a
paywall in front of a content pillar and in front of a resource-parity
guarantee. The gate that remains is geography: the mainland ends of both
channels lie in level-51–59 contested zones.

## 2. The shipwright

- **Exactly one shipwright per continent.** Each lives in the mandatory
  village (**V**) of a peaceful level-21–30 zone with authored inland water:
  **Whitebridge Shire** (`elandor_whitebridge_shire`) for the Accord and
  **Whispering Reedlands** (`kragmar_whispering_reedlands`) for the Throng.
  Both sit on the lateral capital axis of their continent and are reachable
  from all three of that faction's races over peaceful primary road
  (`world_zones.md` §9.4), so the two faction routes stay equivalent.
- The shipwright is an ordinary **passive, invulnerable service NPC**, not a
  trainer role and not a vendor: he sells nothing and buys nothing.
- **The teaching transaction** is one exchange, repeatable never: a character
  of level 30 or higher hands over exactly the ingredients of one improved
  boat (§4). They are consumed, the character permanently gains the Improved
  Boat unlock, and the shipwright hands back **one finished improved boat** —
  he demonstrates the build rather than selling a lesson. A character below
  level 30, or without the full ingredients, is refused and loses nothing.
- His plot carries **one improved boat floating in the adjacent water as
  scenery**. It cannot be entered, driven or collected, and it is not a
  spawned boat entity that decays under §3. The shipwright, his plot and that
  display water form one **bounded functional anchor** and are hard-protected
  under the ordinary anchor rule of `world_zones.md` §11; the surrounding
  village shell stays mutable and claim-excluded like every other village.

## 3. What a boat is, mechanically

- **A boat is an inventory item that becomes a world entity when placed on a
  water surface, and an item again when picked up.** It has no owner: the
  item carries no player binding, and boats are freely tradeable and
  droppable like any other item.
- **Placing and picking up a boat is free for everyone**, independent of
  level and of the Improved Boat unlock. A character who cannot drive an
  improved boat may still carry, place, hand over and pick up one.
- **Exactly one player per boat, and only players.** A boat carries no
  passenger, no second seat and **no mob or NPC**. Storing a creature in a
  boat — the VoxeLibre pattern, where anything with a Lua entity may be
  seated (`reference_projects/VoxeLibre/mods/ENTITIES/mcl_boats/init.lua`) —
  does not exist in this game and must not be ported.
- **A boat with a driver may be picked up only by that driver.** An empty
  boat may be picked up by anyone. There is no theft protection beyond that,
  and none is intended: a base boat costs five wood.
- **A boat has no inventory.** Nothing is stored in it and nothing can be
  lost with it.
- **An unused boat disappears after 24 hours.** The timer is persistent
  wall-clock time, it restarts whenever a player drives the boat, and expiry
  deletes the entity without dropping an item. This is the whole anti-litter
  rule; boats are cheap enough that recovery is a rebuild.
- **Death, logout and server shutdown detach the player.** The boat stays
  where it is and starts its 24-hour timer; the player always returns to
  land on foot.
- **A boat is an entity, not a node.** Placing one modifies no terrain, so it
  is legal on every water surface the player can reach — including immutable
  deep ocean, the dragon channels and Holy-Grounds water. Terrain protection
  never blocks a boat, and a boat never makes protected water editable.

## 4. Recipes

Both recipes are ordinary 3×3 grid recipes and live in `items_crafting.md`
§3.0.5. The base boat is a universal base recipe; the improved boat is
craftable only with the Improved Boat unlock.

## 5. Movement

- **Base boat 4 nodes/s, improved boat 8 nodes/s** on the water surface.
  Both numbers are the decided anchors of the land ladder read onto water:
  4 is the player's own walking speed
  (`reference_projects/luanti/src/defaultsettings.cpp:520`), and 8 is the
  fast land mount of `mounts.md` §1.1 — which unlocks at the same character
  level 30. Rowing therefore never beats walking and the improved boat
  matches, but never exceeds, its land contemporary.
- **Speed is the boat entity's velocity, never `physics_override.speed`** —
  the same rule and the same reason as `mounts.md` §3: that field already has
  two owners (mob webs and the PvP snare) and must not gain a third.
- The player attaches to the boat, steers with the ordinary movement
  controls, and accelerates and brakes rather than snapping to top speed.
- Boats move on water only. They have no currents to fight, no fuel and no
  docking rules: a landing is simply the player leaving the boat.

## 6. Damage: any hit ejects the rider

- **Any incoming damage ejects the player from the boat, immediately, in PvE
  and PvP alike** — the same rule as `mounts.md` §3.1 and for the same
  reason: escaping must not become free. The boat is not destroyed. It stays
  floating where it was, and the player may re-enter it if they survive long
  enough to reach it.
- **Boats have no hit points and are never destroyed by damage.** No player,
  mob or environmental effect can sink one; the only way a boat leaves the
  world is a pickup or the 24-hour decay.
- **Implementation seam, and the one engine fact this rule depends on:**
  mobs_redo punches *what the player is attached to*
  (`mods/ENTITIES/mobs/api.lua:2525-2526`,
  `local target = self.attack:get_attach() or self.attack`), so a mob's melee
  swing lands on the boat entity and the player loses no HP from it. That one
  swallowed swing is what ejects them; every later swing hits the player
  normally. Damage that targets the player directly — our own PvP pipeline,
  projectiles, drowning, environment — never touches the boat. The eject
  therefore needs **two** hooks: the boat entity's `on_punch` and the central
  HP-change hook in `grug_core`.
- **Consequence, accepted:** one hit from an enemy player separates a driver
  from their boat, and the now-empty boat may be picked up by anyone. On the
  open sea that can be fatal. PvP on water is voluntary — deep-ocean and
  channel columns never force the tag (`world_zones.md` §15.1) — and a
  replacement boat is five wood, so no grace period, ownership window or
  recovery mechanism is introduced for this case.

## 7. Ocean danger

The water classes, the Kraken Guard's pursuit rules and the dragon channels
are owned by `world.md` §2b. What matters for a boat:

- **The coastal shelf is safe passage.** No Kraken Guard spawns there, and a
  pursuit that reaches shelf water ends under the ordinary leash/evade model
  of `combat_stats.md` §4.
- **Deep ocean is not survivable in a boat.** The Kraken Guard is faster than
  the improved boat and does not give up while both stay in deep ocean.
  Crossing open sea is a deliberate death, not a shortcut.
- **The dragon channels are required boat routes and carry no Kraken.** Both
  96-node approaches to either island (`world_zones.md` §7) are ordinary safe
  water for a boat at any level; the level-60 island itself is the gate.
- Because the shelf follows the entire mainland perimeter, a low-level
  character may legally coast all the way to a channel mouth and visit an
  island. That is accepted: the islands are contested level-60 zones, their
  apex gems need a T4 pick, and sightseeing is not progression.
