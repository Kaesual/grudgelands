# Round 17 — Fresh-world playtest

Status: implementation, independent reviews and technical gates PASS.
See the completion record for delivery status. GUI acceptance is pending.
Restart the server after installing the completed round. Use a fresh world.
Two same-faction players plus an enemy-faction character cover the group/PvP
checks. Technical fixture evidence is not a substitute for these GUI checks.

## First pass (about five minutes)

1. Find your start-town innkeeper. The dialog already identifies this as home.
   The Map tab shows the destination, return button and innkeeper marker.
2. Travel away, press Return home outside combat: immediate return without an
   inventory skill, then a 30-minute cooldown. Reopen/reconnect: cooldown stays.
3. Fight a moving Boar with Scout/Mage while a friend tanks it: release while
   aiming correctly; the arrow/fireball follows and damage arrives at impact.
   Look into empty space: no shot, mana payment or arrow consumption.
4. Check red hostile names, yellow neutral names, white critters/player names,
   violet guards and lavender services on subtle dark backgrounds. Ordinary
   Boars ignore you until provoked; fightable Rats initiate combat.
5. Injure a combat mob/guard: a small green bar appears and follows its health;
   at full health or death it disappears. View from different directions and
   distances. No extra bar on a peaceful service NPC or critter.
6. In Group, switch All green -> By class: Warrior brown, Mage blue, Priest
   white, Scout olive. The preference affects only your HUD and survives relog.

## Home and travel edges

- Bind at your capital's innkeeper, or another town/capital of your faction.
  Exactly six starts plus six capitals are eligible worldwide.
- Enemy innkeeper cannot bind your home. Existing NPC interactions still work.
- Die while return is on cooldown: respawn at the new home; cooldown unchanged.
- Try return while fighting: refusal. Let combat expire: permitted if ready.
- Return while mounted: safely dismounted on arrival, no orphan mount.
- Inspect the innkeeper and arrival placement at every race start/capital when
  convenient; no roofs, walls, furniture or water should trap the player.
- A server restart preserves binding and remaining real-time cooldown.

## Combat and world pressure

- Launch at an in-range visible target, then have it move out of original
  range or behind cover: shot arrives. Cover before release blocks the shot.
- Another actor crossing the flight path never steals the shot.
- Kill the target before impact: no second hit, retarget or late damage to a
  respawned/reconnected player. Smite still deals direct damage.
- Scout full/partial draw and Twin Shot preserve ammunition and action wear.
- Test a ranged ordinary mob and a dragon: targeted missiles now pursue you;
  existing area/ground attacks retain their behavior. Armor/dodge/absorb remain.
- All non-player combat damage defaults to 1.5 times the previous base before
  ordinary mitigation/rounding. This includes neutral retaliation, guards,
  adds, kings/dragons and their damage-over-time/ground effects. Player attacks,
  falling and ordinary environmental damage must not gain the multiplier.
- Report whether starter combat and later groups feel too punishing or still
  too easy. No additional density or range increase belongs to this round.

## Presentation and configuration

- Quest symbols and names remain legible alongside injured bars; no duplicate
  tag, stale bar or screen-filling bar from large models.
- Existing visibility hysteresis remains: show inside 25 m, hide beyond 30 m.
- Verify the Group dropdown does not overlap invitation controls and offline
  party members remain clearly offline.
- Optional server test: use the documented setting names in settingtypes.txt;
  restart after edits. Damage scale 1.0 restores prior unscaled damage. Set tag
  backgrounds transparent or disable injured bars to compare the presentation.

Record world seed, position, class/level and relevant settings with a defect.
No full-world generation or performance benchmark is required for this pass.
