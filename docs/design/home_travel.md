# Innkeeper home travel

Decided 2026-09-22, Round 17. Uses the standard unmodified Luanti client.

- Exactly twelve home locations: six racial starting towns and six capitals.
  Each has one innkeeper in an existing suitable building and an authored safe
  arrival position. A common registry owns stable ID, name, faction and resolved
  positions for NPC interaction, respawn, atlas and return travel.
- A new character is bound to its own racial starting town. Visiting an
  innkeeper permits binding any home of the character's own faction, never an
  enemy home. The UI offers **Set home here** or **This is your home**.
- Persist the location ID per character, not player-selected coordinates.
  Binding is authenticated by the nearby innkeeper interaction.
- The Map tab offers **Return home**, destination and remaining cooldown;
  innkeeper markers label the locations and identify the current home.
- Return is immediate, without a cast time, and allowed only alive and outside
  combat. It dismounts the player before arrival. There is no inventory item or
  skill. Initial range/interaction checks apply to binding, not return travel.
- The personal cooldown is **30 minutes of real time**, including offline time
  and server restarts. It begins only on successful return. Rebinding, death,
  reconnecting and restarting do not reset it.
- Death respawns the player at the bound home regardless of the return cooldown,
  without consuming or changing that cooldown. Other death rules are unchanged.
- **Respawn is one teleport** (Round 28 ruling 16): straight to the bound
  innkeeper's arrival, or the starting-town innkeeper when none is bound; there
  is no intermediate stop. The player is held there through the
  `grug_core` movement aggregator (exclusive hold: no movement, no gravity,
  other speed effects untouched) until the destination area is emerged and the
  arrival validated, then released. Only if that preparation fails or times out
  does the player land in the starting town's saved start pocket, with a message.
- No teleport (respawn, return travel, mount dismount, character creation)
  adds a velocity derived from the server-side `get_velocity()`. After a
  lethal fall the server still holds the pre-impact speed (it ignores a dead
  client's position packets) while the client is already at rest, so
  subtracting it launched the player upward by about the fall speed and the
  second fall killed them again.
- Load/prepare the destination before final placement. A failed preparation
  charges nothing. Revalidate character session, alive/combat state and binding
  before a delayed return completion; stale or duplicate requests cannot move a
  reconnected, dead or differently bound character.
- This is the current V1 return/respawn mechanism. The waypoint network
  (WP17, Round 29, [world.md](world.md) §6) is a separate travel feature and
  adds no home points. It shares the one travel path of
  `grug_home/travel.lua` (dismount, emerge, deferred re-validation, safe
  arrival) through `grug_home.travel`, but never starts or reads the home
  cooldown, and only one trip per player is prepared at a time.

## Claim Stone as travel home (Round 25)

Full rules: [housing.md](housing.md) §8.

- The owner makes the own Claim Stone the travel-home target with the stone
  form's "Set as home" button (`grug_home.set_home_claim`). Binding an
  innkeeper later replaces the claim home.
- Return uses the Map tab's **Return home** and the same 30-minute
  cooldown. Arrival is the stone's arrival cube. If the cube is blocked, that
  one trip goes to the bound innkeeper instead, with a message, and the
  cooldown is charged. An expired (unfuelled) claim still works as a target.
- When the stone is picked up or destroyed, the target falls back to the
  player's bound innkeeper (the starting-town innkeeper when none is bound),
  with a message; an offline player gets the message at the next login.
- The Map tab marks a claim home with an "H" marker.
- Death always respawns at the bound innkeeper, never at the Claim Stone.
