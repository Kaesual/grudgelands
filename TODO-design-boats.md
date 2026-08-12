# TODO — Playable boats and dragon-island travel

The two offshore dragon islands require playable boat access, but the vehicle
contract has not been designed. This file owns only those open questions; it
does not change the decided map geometry in `docs/design/world_zones.md` or the
ocean/flight rules in `docs/design/world.md` and `docs/design/mounts.md`.

## Decided constraints

- The Wyrmglass Crown and Stormscale Summit have no land, tunnel or flying-
  mount route. Their complete channels are immutable full-height columns.
- Each channel retains separate 96-node approaches centred at z = −125 and
  z = +125, and both approaches are usable by both factions.
- The two faction-oriented routes to an island remain within 10% travel-length
  parity. Mapgen, terrain protection and flight use the same channel geometry.
- A playable boat path must work through those approaches. This requirement
  does not decide how a player obtains, owns, controls, loses or recovers a
  boat.

## Open questions

1. **Acquisition:** what grants or sells the first usable boat, what level or
   progression gate applies, and whether later replacements use the same path.
2. **Ownership and representation:** whether a boat is owner-bound or
   tradeable, inventory state or a persistent world entity, and how multiple
   riders or abandoned boats are handled.
3. **Movement:** base speed, handling, passenger capacity and interaction with
   currents, landings and player controls.
4. **Damage and destruction:** whether players, NPCs, deep-sea creatures or the
   environment can damage a boat; what destruction means; and whether cargo or
   riders can be lost.
5. **Return and respawn:** cooldowns, replacement/repair cost, logout/server-
   restart behavior and recovery of an unloaded, stranded or destroyed boat.
6. **Ocean threat boundary:** the exact difference between ordinary immutable
   deep ocean and the mandatory dragon channels for boat danger, warnings and
   failure behavior.

These questions must be resolved before the dragon-island encounter loop can
ship. No implementation work package may infer defaults from the mount entity
contract: mounts and boats solve different travel problems.
