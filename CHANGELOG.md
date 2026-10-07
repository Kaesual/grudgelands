# Changelog

What changed in the game, newest first, one entry per development round.
The game shows its version on Help → About; versions count
`0.<round>.<patch>` and start with Round 37 (earlier rounds had none). An
entry that says **new world** needs a world created on that round or later:
some of its changes are part of world generation. From 0.41.0 on, worlds
are kept across versions: an entry that says **map reset** regenerates an
existing world's map from its seed while the characters stay
([upgrade contract](docs/technical/upgrade-contract.md)).

The development record behind each round (reviews, tests, acceptance) is in
the [project status](docs/STATUS.md) and the round plans.

## 0.41.0 — Round 41 (2026-10-07)

Fixes from the Round 40 playtest, the end of a crash that kept stopping
the hosted server, and worlds that are kept across updates from now on.
**Map reset** needed: an existing world's map is generated anew;
characters keep everything but their position and home claim.

- Worlds are kept across updates from this version on. Each new version
  says whether an existing world simply plays on, needs a map reset or
  needs a new server. In a map reset the map is generated again from the
  same seed; each existing character waits a moment when joining, then
  arrives at its race's start town and keeps its level, equipment,
  inventory, money, quests, achievements, professions, mounts and
  waypoints. A home claim goes with the old map: the Housing Steward hands
  out a new Claim Stone.
- The server stopped every time a player came near one stretch of
  ungenerated ground: water flowing in a cave nearby had left a hidden
  blocker the world generator refused. That ground now generates
  normally. If generating a piece of land ever fails again, the server
  keeps running: that piece gets plain terrain without the game's
  finishing touches, and every player sees a red chat message so the
  server owner can report it.
- Creatures that set off walking (guards back to their post, villagers,
  camp creatures) move their legs at once instead of gliding; royal
  guards and bodyguards following their leader do too, also right after
  being hit.
- The kings and both Generals stay at their seat, facing the hall door or
  the keep entrance, and walk back to it after a fight.
- The recipe book's Close returns to the station you opened it from (a
  furnace, a bench) instead of the inventory, and so does Close on the
  station's Repair equipment form. If you walked away or the station is
  gone, Close opens the inventory's crafting page; Esc still closes
  everything.
- A recipe slot that takes one of several ingredients (any wood, any
  stone, Corn or Potato) shows them as small icons: up to four, or three
  and "+N" for more. Click an icon whose recipe you know to open it; every
  icon's tooltip lists all ingredients the slot takes. The waterweed bed
  no longer shows up as sand in the glass recipe.
- Bow: pressing right-click again while an arrow is drawn fires that
  arrow at once, and holding on draws the next one; a very quick tap fires
  only the drawn arrow. This fixes a bow that stayed drawn after a quick
  release and re-press.
- The quiver slot shows the true number of arrows above 100 (for example
  181); taking from it still takes at most 100.
- After a change of the map quality setting, the world-map pictures of
  the old quality are deleted from the world folder, and a server stopped
  while drawing the map draws it again at its next start.

## 0.40.1 — Round 40 fix, "Ore where you dig" (2026-10-07)

Ore, coal and gems now lie everywhere you may dig. **New world** needed:
the change is part of world generation.

- The ground right around towns, villages, camps and points of interest
  used to hold no ore, coal or gems down to about 40 below sea level, and
  the squares round villages, camps and points of interest even to 100
  below their buildings. Now only the protected towns themselves (start
  towns and capitals, which nobody may dig) keep ore out; everywhere else
  it is as common as in the open land.
- The shallow sea floor along the coasts holds ore too.
- Wild gatherable plants (potatoes, corn, carrots, onions, berries and the
  like) grow round villages, camps and points of interest like trees
  already did, and regrow there.

## 0.40.0 — Round 40, "Combat feel" (2026-10-06)

Combat reads better: cooldowns on the hotbar, poses for the characters,
Charge as a real dash and particle effects for skills, bosses and
creatures. No new world is needed.

- A skill on cooldown is shaded on the hotbar; the shade clears clockwise
  like a clock hand, and the time left sits in the middle of the icon (in
  minutes above one minute, then in seconds). Skills no longer show their
  cooldown or charge as a bar under the icon (the bow's draw bar while
  drawing stays); a skill an older character already carries may still
  show a leftover bar.
- Characters strike poses: a hand thrust forward or both arms raised for a
  spell, a diagonal cut for Mighty Blow, the drawn bow, a raised shield
  arm for Hold Ground, shoulder first in a Charge and a short flinch when
  hit. Poses work while walking and blend in smoothly, and heads follow
  where their player looks, up and down.
- Charge is a dash: the warrior runs at the target at high speed, hopping
  over steps, low obstacles and holes up to four nodes wide, and hits, stuns
  and gains rage when he arrives. A dash that ends short of the target (at
  a wall, at the rim of a wider hole, or because the target moved) misses
  but still uses the cooldown.
- Player skills show particle effects: Ice Nova's frost ring, Fireball's
  splash of embers, Smite's holy light falling onto its target, Mighty
  Blow's red slash, trails behind skill arrows, and effects for almost
  every other skill and talent proc. Strike has none.
- Bosses and creatures show what they do: the kings' signature moves, an
  elite's heavy blow, the dragons' breath, lightning, gust, dive and rage,
  the Kraken's drag, webs, poison, pounces, ambushes, auras, blinks and
  projectile hits.
- Server owners can scale the number of particles with the new setting
  *Particle amount scale* (1.0 by default).

## 0.39.0 — Round 39, "Web data for the realm website" (2026-10-06)

Nothing changes in play. The game now keeps each character's level and
current look where a realm's website can read them, so a website hosting
a realm can show its players' characters with a 3D preview in their
current equipment.

## 0.38.0 — Round 38, "Mob names" (2026-10-06)

New names for the creatures of every zone, and kill quests that count
every creature of the name they ask for. **New world:** guards and named
creatures that an older world has already placed may show a wrong name,
so their quests might not count them.

- Creatures carry short names that suit their zone, such as the Barrow
  Piglet of Stillgrave Hollow or the Coconut Crab of Kapok Cradle, instead
  of names with "Small", "Large" or "Braindead": size and the colour of
  the name show how dangerous a creature is. Each starting area's first
  pigs are its Piglets.
- A kill quest counts every creature that bears the name it asks for,
  wherever that creature came from, and nothing else: the name in the
  quest is the name over the creature's head. Before, some creatures of
  the right name did not count because they had spawned in the next field
  over.
- Quests against a war camp name the camp's guards and its captain by
  name, and both count.
- Quest texts use the new names; a few jokes that rested on an old name
  are new.
- The two whelps a dragon calls when it rages are level 60 like their
  island, no longer level 20, and much tougher.
- Underground you meet Pit Rats, Crevice Spiders, Buried Miners, Goblin
  Pelters, Fire Hurlers, Lava Seeps and Bedrock Sentinels;
  the deep ocean's Kraken Guard is now simply the Kraken.
- Twelve loot items have shorter names: Cat Claw, Notched Cat Claw,
  Gleaming Cat Claw, Blighted Bear Claw, Pitted Crab Shell, Silver Mane,
  Glass Silk, Guttering Wisp Mote, Lichen Resin, Drilled Bone, Ivory
  Chitin and Layered Chitin.
- "Group" is now "Party" wherever you read it: the Party tab, the invite
  notice, the help, the Priest's description and the "Party: …" quests.
- New characters are greeted once by a short welcome window, right after
  they arrive in their start town, with links to Discord, bug reports, the
  source, the credits and support.

## 0.37.0 — Round 37, "Audit fixes" (2026-10-06)

Fixes for what an October 2026 review of the code and the documentation
found, and a few wishes from playtests. No new world is needed: a world
made with Round 36 and its last fixes keeps working.

- In a group fight a creature stays on the player who holds its attention
  instead of turning to whoever hit it last; a taunt holds. A creature
  that is not fighting yet still turns on its first attacker.
- Creatures show their whole attack swing. An elite winding up a heavy
  blow no longer turns after you and does not strike during the wind-up,
  so stepping aside dodges it.
- A food or Vigor buff running out no longer throws you off your mount
  (also in flight), interrupts a quest action or empties your shield.
- Only melee between two players flagged for PvP and the attacks of
  creatures push you back; spells, player arrows and an ally's punch do
  not.
- A dragon's breath and a King's volley: only the middle shot follows you,
  the side shots fly straight and can hit whoever stands in their way, and
  the breath leaves frost or embers on the ground again without replacing
  snow, plants or water.
- The Undead King calls at most four raiders, who vanish when the fight
  resets; royal guards killed outside a King fight return after about
  15 minutes.
- Creatures are still there after a server restart, and a named rare
  never stands twice.
- With seeds, a bucket or the fishing rod in hand, right-click opens
  doors, chests and stations and harvests regrowing crops; sneak to use
  the item instead. Tall crops no longer leave floating tops, the furnace
  no longer pops back over the recipe book, and a slab that cannot be
  placed stays in your hand.
- Grass and moss no longer creep over towns, capitals, roads and other
  built places.
- Creatures in the six starting areas fight alone: hitting one no longer
  calls its neighbours. From level 11 on nothing changes.
- The Salt Reef Lurker, an elite, now walks the beaches of the level 51–60
  coasts by day.
- The minimap always shows normal quality and uses less memory on servers
  set to high map quality; the Map tab stays sharp.
- New sounds: a gong when a dragon returns, and the Rift Spawn's hissing
  fuse and explosion.
- Less server work per hit, per player and for the minimap and quest
  markers, which helps on busy servers.
- The New World dialog no longer offers the map generator checkboxes the
  game cannot use (a changed box stopped the world from loading); the
  README explains the settings to leave alone.
- The game has a version, shown on Help → About.
- This changelog, and a README written for players.

## Round 36 — "The main questline" (2026-10-05, new world)

- Each faction's main story from level 41 to 60: three chapters from its
  fortress's Warmaster that follow branded pay through the front's worst
  villains, an errand behind enemy lines and a traitor in its own ranks,
  and a finale for two or three players against Isquarre the Tithe-Eater
  at a burning crack in the ground. Each faction's story and the finale
  give an achievement and a cloak.
- Some quest steps ask you to do something at a place, such as breaking a
  seal or taking a rubbing; their objects appear only to players on that
  quest.
- Corrupted creatures with an ember glow roam the front, and two war camps
  on the front, one of each faction, have a war commander.
- Every village, outpost, camp, mine, battlefield and lair got fitting
  decoration, and every house in the towns and capitals small touches such
  as a torch by the door or flowers under a window. Benches face away from
  the wall behind them.
- Creatures running home can no longer be mistaken for targets; priests
  heal more with Intelligence gear; the dragons have larger hazards and a
  wing gust that pushes players away after a warning.
- Holding the left button across a hotbar switch goes on with the new
  skill; the treeless strip round towns and capitals grows grass and low
  plants; roads no longer follow every small bump of the ground.

## Round 35 — "Fixes and character creation" (2026-10-05)

- Held spells and attacks no longer miss zombies, crocodiles and other
  creatures that have turned away.
- Gear that breaks makes a sound and looks clearly broken; ores, gems and
  sand sound when you dig them; quest lists show each quest's state by
  colour.
- Music plays only in the six capitals, each with its own pieces, in place
  of the town ambience.
- You create your character in a single window, and nothing is kept until
  you confirm it.
- Creatures of the night leave at dawn, a few creatures drop less valuable
  loot, and talents keep their strength at every level, with several
  talents rebalanced.

## Round 34 — "Sound" (2026-10-04)

- The game has sound: clicks and cues when you talk to people, trade,
  craft and level up, hits that sound like the weapon you swing, spells,
  creature voices and roaring dragons.
- A quiet ambience for every region by day and night, the sea and the
  caves, forges, hearths and running water, and calm music that is only
  downloaded while music is on. Help → Sound, `/music` and `/ambience` set
  the volumes.
- Creatures follow you across streams, a Bag of Coins lets you hand money
  to another player, and the Crownbinder and Decor Merchant show on the map.

## Round 33 — "Items, professions and achievements" (2026-10-04, new world)

- Gear drops in white, blue and gold; named creatures and elites drop more,
  and every boss gives two blue or gold pieces. You can wear gear only once
  you reach its level.
- Enchantments grow with the item's level and show their tier; each
  profession can upgrade the items it makes; a Crownbinder in every capital
  crowns one item beyond its tier for a Fallen Crown and a fee.
- Vendors sell only first-tier gear, repairs cost more, potions heal a
  fixed amount per tier, critical hits deal double damage, and a Decor
  Merchant sells blocks and lights for your home.
- Alchemy is learned next to Cooking, and achievements unlock cloaks that
  swing on your character.

## Round 32 — "Fixes, preparation and research" (2026-10-03)

- The minimap zooms in twice as far, and hostile camps get their own red
  mark on the world map.
- Zone names show in green, yellow or red for friendly, contested or enemy
  territory, with a line saying which.
- Holding the left button while mining fights a creature that walks into
  your aim and goes back to mining once it is gone.
- Quest objectives name creatures as you meet them in that zone, and short
  notices such as "You dodge!" appear above your bars instead of in chat.
- The server handles many players at once more evenly.

## Round 31 — "PvP, appearance and clean-up" (2026-10-03, new world)

- Players of the two factions can fight each other only when both are
  flagged: contested lands and enemy territory flag you, and a button flags
  you for a minute anywhere. A PvP tab shows your state and statistics.
- Each faction has a fortress near the Battlegrounds with a General, a
  waystone and quests to raid the enemy's war camps.
- You choose your character's face, hair and features at creation;
  townsfolk and guards look different from each other; enchantments show
  as coloured accents on your gear.
- Both dragons fight in round arenas with ice or ember hazards.
- People of the other faction no longer serve you.

## Round 30 — "Performance and clean-up" (2026-10-02)

- Quest markers, the world map, the minimap, crafting and the crosshair
  cost the server much less, and a second start of a world takes about
  half as long.
- Creatures give up a player they cannot reach and walk home.
- Return home sits on the Character page.
- Each dragon island has a small beach and a wooden pier at its boat
  landings.

## Round 29 — "Economy and travel" (2026-10-02, new world)

- New quests take every people from its starting town to the war front,
  with directions that fit each world and repeatable bounties at the front
  and on the dragon islands.
- Vendors buy loot and materials at prices set by tier; mounts, boats and
  talent resets cost what a player earns in a set time.
- Boats, sold by a Shipwright in every capital, are the way to the dragon
  islands; waystones in every starting town and capital connect your
  faction's homes.
- Gems lie at their own depth, and the Battlegrounds are wider with a road
  across the middle.

## Round 28 — "Questing and leveling" (2026-10-02)

- Every zone's creatures live where the world's own terrain suits them,
  with levels that rise toward the next zone, loot that matches their level
  and named leaders at their camps.
- Leveling follows a gentler curve; the quest log shows each objective's
  level range, and the minimap names the zone or town you are in.
- A message feed above your bars, a class offhand slot (shield, spellbook,
  or the Scout's melee weapon) and the Scout's quiver.

## Round 27 — "Minimap" (2026-09-30)

- A round minimap of our own replaces the built-in one: north up, drawn
  from the world map, with quest givers and their state, trainers,
  innkeepers, the Housing Steward, your home and your party, with arrows on
  the rim for members out of view. It can be switched off on the Map tab.
- The world map shows height more clearly, and a server can choose a
  sharper map.

## Round 26 — "Capitals, housing and clean-up" (2026-09-29)

- A placed Claim Stone starts as a draft that you activate with five lumps
  of coal within five minutes; the Housing Steward hands it out.
- Buffs and debuffs show as icons above the skill bar, combat as an icon
  next to the health bar, with an Effects tab on the Character page and
  class icons in the party display.
- The six capitals get more irregular walls and each its own character: a
  royal river city, an angular mountain hold, a necropolis, a war camp, a
  lakeside city and a jungle city round its cenote.

## Round 25 — "Housing" (2026-09-29)

- From level 20 a Housing Steward in your capital hands out a Claim Stone.
  Placed in your faction's level 11–30 lands and fuelled with coal or
  charcoal, it protects a 101 × 101 home, lets you grant friends access and
  can be your travel home.
- Roads and the cores of villages, camps and points of interest are
  protected for everyone.

## Round 24 — "Mining, underground and creatures" (2026-09-29)

- Stone gets harder with depth: a pick that is too weak cannot dig it,
  loose ground digs by hand or shovel, and better tools need a minimum
  level.
- Shallow tunnels find coal and other ores, and mountains and cliffs show
  rock layers.
- Start zones get a gentle level gradient and more creatures, which roam
  calmly near where they spawned.
- Mining ores and gems and catching fish give XP, up to ten quests can be
  tracked, lava and drowning scale with health, and character creation can
  be paused.

## Round 23 — "World life" (2026-09-28)

- Full-world preparation covers everything players can see from the
  surface, underwater or in flight.
- Wild plants, ground cover and trees regrow around players up to their
  natural density.
- Mountains get a tree line with shrubs, alpine meadows and snow caps, and
  forests alternate with clearings. All six capitals get walls.

## Earlier rounds (up to 2026-09-28)

The rounds before built the game's foundation: the world of two continents
with its zones, towns, capitals, villages, camps and points of interest;
the four classes with their skills and talents; the six peoples;
professions, crafting, smelting and enchanting; the first quests; mounts,
fishing and farming; creatures and their behaviour; and world preparation
before the first entry. Their last steps (Rounds 20 and 21 and the
playtest fixes of 2026-09-28) brought contextual combat and digging
controls, better terrain round points of interest and capitals, furnace
and fuel rules, bronze arrows, lakes and coasts with aquatic plants and
fish, a timed bow draw and the eating animation.
