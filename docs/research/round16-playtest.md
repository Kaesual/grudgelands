# Round 16 playtest

Use a fresh world after restarting Luanti/server. Technical delivery does not
claim GUI or two-client acceptance. The following checks cover the changed
behaviors; a full historical regression pass is not requested.

## First pass

1. Open Map: your gold heading triangle is visible above the raster; with a
   group, online peers have cyan triangles. Check overview and a regional view,
   movement/turning, then close/reopen through Character. Quest givers, profession
   and Riding trainers, kings and dragons have individual static markers and
   names-only tooltips. Close markers may overlap by design in this first pass.
2. Inspect Cloth, Leather and Metal armor, including enchanted items. Open a
   furnace and another station: the recipe-book button clears input/fuel slots.
   The XP label to the right of the bar shows level and interval progress.
   An administrator can use `/xp give <player> <amount>`; `/xp` still queries XP.
3. Eat outside combat: sound is quiet, instant healing is unchanged, regular
   recovery is stronger and the buff lasts five minutes. Enter combat and try
   another food: no item or existing buff is lost. Combat shows a small label;
   recovery resumes after combat. Drink a potion and check its audio as well.
4. Ride a land mount, log out, reconnect; repeat with a flying mount and with
   server shutdown. No crash, orphan mount or stale mounted status should remain.
   Normal dismount still restores appearance and camera.

## Combat with two players

- Attack the same normal mob. Taunt, have the other player overtake threat during
  the three-second forced window, then stop hitting. The mob should reconsider
  the target after expiry; Taunt must not pull an evading mob out of reset.
- Charge a moving normal enemy and, in allowed PvP, a moving player: 1.5-second
  stun stops voluntary movement and pending attacks. Test an already drawn bow
  and held melee input. Kings and dragons remain immune; falling still works.
- Frost Nova: small damage, complete root and pale ice crystals, then the
  existing slow and normal recovery. Check a moving player and movement immunity.
- Aim at an Ibex torso/head from several directions, including its side. Its
  movement collision should feel unchanged.

## Progression and atmosphere

- Follow an early quest chain: minimum level and prerequisite names are visible,
  and the sixth starter quest sends you to the regional village for hand-in.
  The next quest comes from that giver. Rewards are fixed by authored quest level;
  kill XP is 50% higher, with the existing shared participation rules.
- Observe a normal day/night cycle: about 15 minutes day and five night, with
  moderate outdoor night visibility. Caves remain dark; Night Vision still helps
  and ends cleanly. Compare ordinary huntable/hostile world populations; city
  residents, guards, critters and bosses have not received the density increase.

## Optional server preparation test

For a fresh world enable `grug_prepare_full_world = true`. The waiting screen
counts completed horizontal surface tiles; a mountainous tile can take longer.
Stop normally partway through and restart. Progress resumes within the current
tile, and changing the setting does not change the mode of this begun world.
Initial ETA can be pessimistic and settle downward; that behavior is accepted.

After completion, visit coast/cliff transitions, wooded hills, a capital and
start areas. Surface preparation includes conservative nearby soil/air and
shallow water; deep mining/diving and arbitrary high flight still generate on
demand. On a separate fresh world, the default starts-only mode still prepares
the six starts rather than the full surface. Do not reuse an older development
world to assess this changed preparation plan.
