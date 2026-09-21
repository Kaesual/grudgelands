# Round 14 playtest checklist

Status: draft while implementation and independent reviews continue. This is
not a delivery announcement; use after the coordinator's final sync confirmation.
Start with a fresh world and preferably two same-faction characters.

## First pass

1. Speak to the start elder: a yellow 3D exclamation mark should appear nearby.
   Accept the first quest, defeat five local boars and return. Check objective
   counts, yellow question mark, reward and the next quest. The second player
   should see markers appropriate to their own progress.
2. Open Quest: inspect details, toggle the HUD, abandon/reaccept an unfinished
   quest and choose tracked quests. Item objectives reflect items in owned bags
   as well as the main inventory. Reconnect and verify the journal persists.
3. Open Group: invite the second character, accept, inspect names/HP and toggle
   the HUD. Disconnect one member: the row becomes offline and membership stays.
   Opt out of invitations; enemy-faction invitations must never be accepted.
4. Open Map: find the start, capital and nearby village/outpost, inspect marker
   text and the player marker, and switch region views. No terrain exploration
   or complete-world generation is required to see the atlas.
5. Fish: cast, watch the float dip and right-click promptly. One catch appears
   with short HUD text and rod wear. Miss a bite and wait for the next; early
   reeling gives no catch. Walk away and verify float cleanup.

## Focused multiplayer and world checks

- Kill participation: both attackers and an effective healer receive matching
  quest credit when eligible, including across different groups or no group.
  Simply standing in the party nearby grants no credit.
- With three characters: A invites B/C; B joins, then leaves; C accepts the old
  invite and forms a new party with A. Restart with an offline leader and check
  that leadership remains unchanged. Voluntary leader departure differs from
  disconnecting.
- Visit the culture's home village, outpost and bandit camp. Inspect architecture,
  passive quest-giver placement, protected furnishings and roads. Continue the
  local quest chain when the stated level gate is met. No Nether access or
  Nether-specific objective belongs to V1.
- Flight: both factions may fly in contested mainland/Battlegrounds; own safe
  lands allow flight, enemy safe lands and both dragon islands forbid it.
- Cooking report remains unresolved until reproduced with evidence. On two new
  characters, only A learns Cooking; B must still see Learn Cooking. If not,
  collect the matching `[grug_jobs] trainer_` lines from the server log.

## Optional operator test

For a separate fresh world, choose `grug_prepare_full_world = true` before its
first boot. Inspect waiting progress/ETA, request normal shutdown, restart and
verify resume. Changing the boolean later must not change the chosen mode.
Default false prepares starts only. Full generation is potentially many hours;
finishing it is not necessary for the short playtest. Existing characters
reconnecting while preparation is incomplete remain protected and later resume
at their prior position. Cold engine initialization can delay shutdown by the
current bounded generation unit.
