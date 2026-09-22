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
- Load/prepare the destination before final placement. A failed preparation
  charges nothing. Revalidate character session, alive/combat state and binding
  before a delayed return completion; stale or duplicate requests cannot move a
  reconnected, dead or differently bound character.
- This is the current V1 return/respawn mechanism. The separately planned
  housing-bound Home Stone and waypoint network remain deferred. Neither adds
  home points to these twelve or changes the current innkeeper cooldown.
