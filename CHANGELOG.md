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

## 0.63.0 — fortified mining outposts and faction banners (2026-10-26)

**Map reset** needed: all 36 completed mining camps use new templates and
relocated lift columns. Underground rooms follow their camp's lift. This
joins the already planned production map reset; no migration step.

- Canvas tents in muted faction colours, timber walls on stone plinths,
  a framed entrance and the capital guild houses' tall mining headframe.
- Attached banners for The Accord and The Throng, with matching heraldry
  in the inventory header. The larger war camps keep their watchtowers.
- Camp captains, guards, foremen, vendors and quest places keep their roles.
- UI follow-up (2026-10-27): clearer inventory, talents, help, Party and
  service layouts, flat buttons and text tabs; larger character preview and
  equally spaced character sub-tabs.
- Quest-giver, map quest and mailbox lists use taller selectable rows with
  status information. Windows stop growing beyond their equivalent Full-HD
  size when rebuilt; container and station sections share the inventory frame.
- Traders keep Repair in their navigation and offer quantity shortcuts;
  the double furnace has four output slots, preserving existing contents.
  These UI changes are compatible and add no migration or map reset.

## 0.62.0 — the front 41–60, the main line's story and bigger bags (2026-10-25)

**Map reset** needed: new quest places on the Battlegrounds, changed quest
targets there and two fixed capital buildings change what world
generation builds, so an existing world's map is generated anew from its
seed. Characters keep their level, gear, inventory, money, quests,
professions, mounts and waypoints, as in every map reset; a front quest
that no longer exists simply leaves the quest log. No migration step: your
bags simply grow at your next login, with every item where it was.

- **The front 41–60 reworked:** the hosts' and the capitals' envoys'
  quests for the Battlegrounds are offered from their level, with no
  chain to follow outside the story, and far fewer of them are hunts: light a lantern at the Causeway Return Stand, count who came
  back at the Shattered Relief Rest, check the shoring in Gravesalt, loosen
  the carriers' snares in the Skyglass Canopy, and bring Potatoes, Salt
  Crust, Stormkelp, Paper, Melons, Wild Cocoa and Torches where they are
  needed. Engine Nine and War Construct Last-Toll are optional "Party:"
  quests both factions share.
- **The main line is the story:** from the Warmaster's first order at 41
  to the finale at 60, every step is a story quest with a closing text
  that hands you on; it opens at 41 even if you skipped the earlier
  chapters, and The Throng now meets Paymaster Chirr after Watch-Captain
  Huskell.
- **New departures:** the hosts send you on to Dorrin Gateledger in Dur
  Brannoc, Thorga Roadspeaker in Gor Drazhak, Borin Splitbolt, Nalo
  Pathdrum, Eriath Boughwarden, Vaska Ashlistener and Ossa Quietregister,
  each with work waiting. The Throng gets its own island bounty: Kraits on
  Stormscale Summit, then a party against Last-Offering.
- **Quest rewards at 41–60:** a choice of Healing or Mana Potion V and
  VI, armor with an enchant, weapons with two, trinkets on the group
  quests, and a weapon choice at the end of the main line.
- **Bigger bags:** every bag holds four more slots (8, 12, 16 and 20) at
  the same price and recipe.
- **Two capital buildings fixed:** both leaves of Kezamba's moot-house
  door open properly, and visitors to Lethariel's mere shrines stand on
  the floor.

## 0.61.1 — refreshed vendor, quest and service windows (2026-10-25)

**Compatible:** no map reset and no migration step.

- **Vendors:** the offers are compact cards in two columns, each with a
  small icon, its name, its price and its own Buy button; a long shelf
  scrolls inside its pane and keeps its place after a purchase, so you
  can buy from the bottom of the list twice in a row. Reputation shops
  use the same smaller icons.
- **Quest givers:** the list of quests stands beside the quest's text
  and objectives, with the rewards in their own pane below them; a chosen
  reward still shows its full details.
- **The other service windows:** mail, trainers, mount trainers,
  innkeepers, waystones, mining lifts, the Housing Steward, repair (with
  durability and the total cost), character creation and the welcome
  window (its tips in two columns) share the new look; what each window
  does stays the same.
- **Crafting:** the recipe details use the same text sizes as the list,
  and the tier status reads more clearly; gathering sources show each
  zone's own level band.
- **Map & Quests:** the map and the quest column each take half the
  window. Zone names stay on one line, a little smaller at 1× and larger
  from 2×; choosing the Zones layer from the overview zooms in to 2×.

## 0.61.0 — the quests of levels 31–40 and the story's third chapter (2026-10-25)

**Map reset** needed: new quest places in the wilds of levels 31–40, a
few leaders gone and Provisioner Rattle at a new level change what world
generation builds, so an existing world's map is generated anew from its
seed. Characters keep their level, gear, inventory, money, quests,
professions, mounts and waypoints, as in every map reset; a quest of
levels 31–40 that no longer exists simply leaves the quest log. No
migration step. One known edge: if "Rattle's Bad Arithmetic" was in your
log before, it may already read ready without Rattle's kill.

- **Levels 31–40 reworked:** Stormvault Heights, Ashenward March and
  Glassroot Wilds (The Accord), Blackwind Rise, Bannerbreak Mesa and
  Thunderroot Wilds (The Throng) offer their quests at once from level
  30, each from its level, with no chain to follow outside the story.
  Far fewer of them are hunts: set a sighting frame at the Stormvault
  Survey Stand, loosen a snare on the Glassroot Carrier Path, secure a
  shroud bundle at the Blackwind Recovery Rest, seal a stolen storm
  vessel in Thunderroot, ready the reserve load, trim a signal lantern or
  secure a reading cord at the mining camps' loading grounds, and bring
  Corn, Melons, Chests, Iron Buckets, Wooden Ladders, Mushrooms and
  Frostfin to the outposts. Four zones end with a departure to the front;
  in Ashenward March and Bannerbreak Mesa the hosts give their front quests themselves.
  Rewards: a choice of Healing or Mana Potion IV, armor choices with an
  enchant and a weapon choice with two.
- **The story's third chapter:** at level 34 Toren Waterbarrel sends The
  Accord to a raided transport at the Ashenward Broken Load and on to
  Audra Wainholt, the Ashenward mining camp's foreman; at 35 Drek
  Rampbinder sends The Throng to the Bannerbreak Scattered Load and on to
  Greda Stonehaul of the Bannerbreak camp. After the camp raid, at 39 and
  40, the band's foremen send you to Nella Hedgeward or Yarra
  Standardmender, who point you to the Warmaster.
- **Optional group quests:** each zone's elite leader is one "Party:"
  quest at 38 with a choice of trinkets; nothing else needs it, so the
  band plays well alone.
- **A new quest item and object:** the Runner's Packet, which the bandit
  archers of the band's camps drop for "Words Worth Bringing Back", stays
  in your bags like every quest item; the storm vessel has its own look.

## 0.60.1 — a new look for every window (2026-10-25)

**Compatible:** no map reset and no migration step.

- **Every window looks new:** translucent dark panels with small rounded
  corners, clear buttons that light up under the mouse, tabs with their
  own icons and a gold line under the open one, and your faction and level
  in the header. Inventory, character, talents, crafting, furnaces,
  chests, vendors, trainers, mail, quests and the other windows all share
  this look; what each window does stays the same.
- **The map opens directly:** Z and the Map & Quests tab open the larger
  map at once, with the same tabs on top to move on to another page.
- **Readable in small windows:** the windows and their text stay readable
  in small game windows, at higher GUI scales and on high-density
  displays.
- **The Scout's quiver** shows its full arrow count beside the slot.

## 0.60.0 — the quests of levels 21–30, the capitals and the story's second chapter (2026-10-24)

**Map reset** needed: herbs and crops in new places, new quest places in
two band villages, every mining camp, Nhal Veyr and the wilds of levels
21–30 change what world generation builds, so an existing world's map is
generated anew from its seed. Characters keep their level, gear,
inventory, money, quests, professions, mounts and waypoints, as in every
map reset; a quest of levels 19–30 that no longer exists simply leaves
the quest log. No migration step.

- **Levels 21–30 reworked:** Frostbarrow Shelf, Whitebridge Shire,
  Lorindor and Moonfall Wood (The Accord), Ossuary Reach, Speargrass
  Reach, Whispering Reedlands and Totemwater Reach (The Throng) offer
  their quests at once, each from its level, with no chain to follow
  outside the story. Far fewer of them are hunts, and each zone's hunts
  ask for about three kinds of creature: trim a signal lantern at Rimebell
  Watch, check pickup records at Whitebridge's Market Close, cut snares,
  set up a sighting frame in Moonfall Wood, bring stolen banners home in
  Speargrass, free seized stores in the Reedlands, secure a reading cord
  in Totemwater, and bring Steel Bars to the six mines, whose leaders now
  work for their Miner's Guild. Each zone ends at its named troublemaker.
  Rewards: a choice of Healing or Mana Potion III early, two armor choices
  with an enchant and a weapon choice with two.
- **The six capitals reworked:** fewer, freer quests (47 instead of 64):
  torches for every envoy, the debtbound dead after dark and meat for the
  cooks in four of them, each capital's named culprit, and the cooks' and
  envoys' errands into the zones around, all open from their level.
- **An Alchemy lesson at your first capital visit:** at level 19 every
  envoy asks for an Elixir of Precision I. The capital's Alchemy trainer
  teaches the craft for free; Sunleaf and a Boar Tusk are found where you
  started (your start town's waystone takes you there), and the capital
  has a Brewing Stand.
- **The story's second chapter:** at level 24 the foreman of the
  Frostbarrow mining camp, Brodd Deeppeg, or of the Ossuary camp, Rellis
  Shalemark, sends you after the false papers; at 29 The Accord seals its
  finding at the Miner's Guild in Dur Brannoc, and The Throng posts a
  notice at the public register before Nhal Veyr's guild house.
- **Herbs for every level band:** Gravemoss and Sunleaf grow in every
  start zone, Dragonweed in every level-11 to 20 zone, Crimson Lotus at
  levels 21–40 on each faction's own half; Pumpkin grows in all six home
  zones and Frost Melon on The Throng's half too.
- **Quest items stay in your bags:** the Dispatch Folio and the Captain's
  Orders never go into a chest, the mail, a trade or the trash; dropping
  one destroys it, and it drops again while your quest needs it. With full
  bags nothing drops and a notice says so.
- **New quest objects and icons:** a signal lantern, a sighting frame,
  reading knots and a claim notice; the Dispatch Folio and both Captain's
  Orders show their own icons.

## 0.59.0 — the quests of levels 11–20 and the story's first chapter (2026-10-24)

**Map reset** needed: new quest places in the six capitals and in four
bandit camps change what world generation builds, so an existing world's
map is generated anew from its seed. Characters keep their level, gear,
inventory, money, quests, professions, mounts and waypoints, as in every
map reset; a quest of levels 11–20 that no longer exists simply leaves the
quest log. No migration step.

- **Levels 11–20 reworked:** Copperfell Foothills, Goldmead Vale and
  Starbough Vale (The Accord), Mournfen, Redtusk Savanna and Raincall
  Basin (The Throng) now offer 13 quests each, every one open from its
  level on, with no chain to follow (apart from the guild reports) and no need to arrive by the start
  zone's last quest. Far fewer of them are hunts: repairs, crafts and gathering
  for the villagers, a witness to find, records and supplies to recover
  in the bandit camp, snares to cut in the Lower Boughs and names to copy
  from the grave markers in Mournfen; each zone's hunts ask for three
  kinds of creature instead of eight to ten. Rewards: a potion choice
  early, two armor choices with an enchant and a weapon choice with two at
  the zone's end.
- **The story's first chapter:** at level 19 the envoy of every capital
  sends you to the Miner's Guild leader there; at 20 the leader sends you
  to a spot in the town (a yard, a landing, a court) to secure a record
  and decides the case when you return.
- **The quest log** names the zone of the place you took a quest in,
  also for a quest that several zones offer.
- **New quest objects:** a dispatch record, a witness record, held supplies
  and a snare bundle.

## 0.58.0 — the Miner's Guild and the town fixes (2026-10-24)

**Map reset** needed: new camps, rooms, lifts, guild houses and town fixes
change what world generation builds, so an existing world's map is
generated anew from its seed. Characters keep their level, gear,
inventory, money, quests, professions, mounts and waypoints, as in every
map reset; their position and home claim go with the old map, and the
containers in a housing claim come back through the Claim Stone's
Belongings tab. No migration step. Everybody's reputation starts at 0.

- **The Miner's Guild:** each faction has one, The Charter of Stone for
  The Accord and The Oathdelvers for The Throng; the game calls both
  "Miner's Guild". It serves only its own faction.
- **Mining camps:** 20 new camps, one in every level-11 to level-40 zone
  outside the capitals' zones, plus the 16 Battlegrounds war camps, each
  with a Foreman, a Camp Vendor and a lift. Camps show on the map's POI
  layer.
- **Lifts and rooms:** a camp's lift (a rope-drum hoist) takes you to a
  room at each ore tier's depth down to the camp's own tier: Level 1 at
  y −50, then −250, −450, −650, −950 and −1050. Right-click it and pick a
  level: free, no cooldown, not in combat. Rooms are lit and protected, no
  monster spawns in them, and water and lava stay out; three exits end in
  a plug of rock you dig through to start mining.
- **Reputation:** trade ores, gems, stone and sand (stone and sand at 1
  point per 50) at a Camp Vendor or at the Miner's Guild Exchange in your
  capital. Ranks 0 to 10 follow everything you have ever earned, so
  spending never lowers your rank; the Character page shows rank and
  reputation. Selling the same goods for copper still works. The mason no
  longer sells Cobblestone or Gravel.
- **The Camp Vendor** buys like every vendor, repairs your gear and sells
  the guild's goods for reputation, one row per tier, each opening at
  Reputation Rank 1 to 6.
- **Ore Sense and Treasure Hunt** (I to VI, one per tier, usable from
  levels 1, 11, 21, 31, 41 and 51, each only in its own depth, 30 minutes):
  Ore Sense marks a random ore or gem deposit within 16 nodes every 1–2
  minutes for 5 seconds, through the rock and for you alone. Treasure Hunt
  hides a Miner's Remains in solid rock 12–24 nodes away and marks it
  while you are near: dig it for coins, the tier's bar and sometimes a cut
  gem; it vanishes when you go more than 48 nodes away or log out, and the
  next appears about 90 seconds later. Both use their own slot, one at a
  time; the time left pauses while you are offline and goes on when you
  log back in, and a death does not end them.
- **Cloaks:** reach Reputation Rank 3, 6 and 10 for the three cloaks of
  the Miner's Guild achievement; the last one has wings.
- **Guild houses:** every capital has a Miner's Guild house in its trades
  district, with a headframe and an ore yard, the guild's leader and the
  Exchange counter.
- **Guild quests** (30): two gather quests for each depth from level 11
  on, offered at every own camp whose lift reaches that depth; with both
  done, a report to the guild's leader in the capital, which carries the
  guild's own story; a hunt near every camp with a choice of leather,
  cloth or bars; and in each contested level-31 to level-40 zone a raid
  on the enemy's camp under construction, with four guards and a named
  captain.
- **Town fixes:** Lethariel's bough stairs and the hall doors on its
  platforms are free to walk; the gatehouses of the five capitals with one
  have an inner stair with a landing and a wider opening to the deck; two
  gate guards walk opposite rounds on the city side while the third stands
  on the deck; every king's royal guards stand beside him and return there
  after a fight; Silverleaf's terrace stair has its missing step; every
  start town's waystone and mailbox stand at its centre by the
  Quartermaster.
- **Server admins:** stop the server, back the world up, run
  `python3 tools/migrate.py --world <world directory> --map-reset` from
  the new version's checkout (it packs the claims' containers), empty the
  map, raise `grug_reset_world` and start it
  ([updating a hosted world](README.md#your-own-world-or-server),
  [upgrade contract](docs/technical/upgrade-contract.md#35-the-pre-reset-pass)).

## 0.57.0 — the crafting window and the new start zones (2026-10-23)

**Compatible:** no map reset and no migration step.

- **A crafting queue:** while a job runs, the big button reads "Queue ×N"
  instead of "Craft ×N" and adds the next job: up to 5 jobs in all,
  crafts, enchants and upgrades alike, one after the other, while you are
  offline too. Their ingredients (and an enchant's item) are taken when
  you queue them; View Queue lists the waiting jobs, ✕ cancels one and
  gives everything back, and the small ■ beside the bar stops the running
  one. What does not fit into your inventory waits in the Overflow, which
  grows as needed, so a finished job is never dropped at your feet.
- **A wider crafting window:** one wide recipe box, the button beside Max,
  and under every box the bar, the stop button, one line naming the job
  and View Queue.
- **Recipe details:** "Recipe details" (and "Details" in the enchant and
  upgrade boxes) opens a page that names where each ingredient comes from:
  recipes, vendors with their price, creatures by level, the zones where it
  grows, the mining depth, trees, fishing and farming. "Open ▶" walks down
  the chain and "◀ Back" returns; an ingredient of several kinds opens a
  page of its kinds; "Select this recipe" chooses a recipe you know.
- **Favorites:** the star on a recipe marks it, and "Favorites only"
  beside "Craftable only" lists them.
- **Basic recipes come with your profession:** learning a profession or
  reaching a new tier also unlocks every Basic recipe its recipes need,
  such as Thread and the Patch Bolt; existing characters get them at their
  next login.
- **New start zones:** the six start towns offer fewer, broader quests
  (30 instead of 92), all of them at once: the boar and rat hunts from the
  first minute, three rats in one night. A task that is the same in every
  town is one quest: done in one town, it is done everywhere. A character
  above level 10 can take the new ones too; its level-11 quests stay.
- **Reward choices:** some quests let you pick your reward: two healing or
  mana potions, an armor piece of item level 5 and one of level 7 or 8
  with an enchant (cloth, leather or metal), and at each zone's last quest
  a weapon with a prefix and a suffix. The offer and the turn-in show the
  choices with their enchants; Complete waits until you pick one.
- **Story quests and closing words:** story quests get violet symbols and
  their own "Story" heading in the quest log (the start zones are free
  play; the story comes later), and a quest can end with a few closing
  lines at the turn-in, as each start zone's last quest does.
- **Simpler alloys and woods:** Embersteel is Steel + Emberglass and
  Abyssal Steel is Steel + Abyssal Crystal (no longer the alloy of the tier
  below); each graded wood is 2 planks plus its tier's ingredient (Iron
  Bar, Anthracite, Silver Bar, Emberglass, Abyssal Crystal). Embersteel and
  Abyssal Steel bars and the goods made from them sell for less (the
  Abyssal Steel Sword 125c → 88c), and the graded woods above Seasoned
  sell for 1c to 40c.
  Steel Bars, the iron bars of the bar door and trapdoor, are craftable: 6 Steel Bars (the metal) make 16.
- **Every dye can be made:** White from Bone, Yellow from Sunleaf, Red
  from Apple and Cyan from Marshbloom; the other colours and every wool
  follow from the mixes.
- **Vendors no longer sell leather, cloth or bars:** Leather, Light
  Leather, Linen Scrap and the Bronze Bar left the shelves; creatures drop
  them, and Bronze is Copper + Tin in the Dual Furnace. Thread and the
  tailor's wool stay. Selling a Bronze Bar now pays 2c instead of 1c, and
  the goods made from it a little more.
- **Flying over bays:** a bay's water near its shore now follows its
  zone's flight rule, so you no longer drop off your mount there; the open
  sea and the bay mouths stay no-fly.
- **Open chin, underneath too:** the cloth and leather head pieces with the
  open chin strip are see-through under the chin as well.
- **Server admins:** a world created with `grug_prepare_full_world = true`
  refuses to start after this update until its map is reset
  (`grug_reset_world`): its preparation fingerprint covers the changed
  water rules. Worlds in the default start-town preparation mode, which
  the hosting platform uses, are not affected.

## 0.56.1 — the hood (2026-10-22)

**Compatible:** no map reset and no migration step.

- **Cloth and leather head pieces have a hood:** it sits over the top and
  the back of the head in the piece's own colour, with a lining and small
  stitching or fasteners at its edge that grow finer with each tier, and an
  enchanted head piece colours that edge too. Bandits wear it as well.
  Metal helmets stay as they are.

## 0.56.0 — fixes from the big playtest (2026-10-22)

Fixes and wishes from the playtest with many players on 2026-10-21.
**Compatible:** no map reset and no migration step.

- **Monsters far below your level leave you alone:** from six levels below
  you, a monster's notice range shrinks by a fifth per level, and one ten
  or more levels below attacks only when you walk right into it or hit it.
  A monster you hit still fights back.
- **Calling for help:** a monster you hit calls the kin around itself, not
  around you, and the ones it calls don't call any others.
- **Archers come closer:** a ranged monster that cannot reach you walks
  (or flies) closer and then shoots, instead of standing still and firing
  arrows that never arrive. The Bandit Archer now moves its arm when it
  shoots.
- **Mounts fall and jump like you do:** a land mount falls as fast as you
  on foot and jumps just over two blocks. Riding, a fall hurts only when it
  is five blocks deeper than one that would hurt on foot, and a fall never
  throws you off; a hit from a monster or a player still does.
- **Sell from your second hotbar:** the vendor's Sell tab lists the items
  on the hotbar you are not showing too.
- **Quartermasters serve the whole faction:** every Quartermaster trades
  with all players of its faction; your own race's Quartermaster still
  gives you 10 % off.
- **Mana food for everyone:** a Warrior can eat a caster's dish and gets
  its health part.
- **Items float:** a dropped item or loot that lands in water rises to the
  surface and stays there.
- **Clearer enchants:** item tooltips mark the enchant lines `Prefix:` and
  `Suffix:`, and the enchanting station shows what a new enchant replaces
  ("Replaces prefix: …"); the line is orange, with a warning when you point
  at it, if the new enchant is a lower tier. Enchanted items in chests show
  the new lines after your next login, equipment change or level-up.
- **Open chin:** the bottom row of the helmet's front is see-through on
  every cloth head piece and on leather ones up to tier 5, so the chin
  shows.
- The town buildings are now stored as building templates that can be
  edited with a developer tool; towns and capitals look exactly as before.

## 0.55.1 — the profession debug command (2026-10-21)

For server admins. **Compatible:** no map reset and no migration step.

- **`/prof`** shows and sets an online player's professions, for testing:
  `/prof show <player>`, `/prof set <player> 1 weaponsmith T6` (or
  `/prof set <player> cooking 3` for Cooking and Alchemy), `/prof learn`,
  `/prof unlearn` and `/prof clear <player> <slot>`. The tier never goes
  above what the character's level allows: a level 12 character asked for
  T6 gets T2, and the answer says so. A profession it replaces loses its
  progress, as at a trainer. The player gets one chat line about it.

## 0.55.0 — shields, spellbooks and the Supporter Cloak (2026-10-21)

Your character now carries its offhand gear where everyone can see it.
**Compatible:** no map reset and no migration step; your character takes
the new look at its next login.

- **Shields and spellbooks in the hand:** a Warrior holds the shield on
  the left arm and raises it in front of the chest for Hold Ground and
  Unbroken; it grows a little with the tier. Mages and Priests hold their
  spellbook open in the left hand and lift it for frost and healing spells.
  Enchant colours and cracks show on both, as on armor.
- **The Scout's second weapon** hangs on the back as a flat image: the
  bow while you fight with the blade, the blade while you shoot, on your
  cloak when you wear one.
- **New shield and spellbook art:** every tier has its own shield and
  spellbook, in the hand and as a new icon; shields and spellbooks you
  already own take the new look too.
- **Simpler armor icons:** all 72 armor icons are redrawn with one bold,
  clear shape each, so helmets, chest pieces, leg armor and boots are easy
  to tell apart even in the small inventory slots.
- **The Supporter Cloak**, the first cloak with wings, for players who
  helped shape the game early on. It is not earned by playing: a server
  admin grants it with `/achievement grant <player> supporter` (and takes
  it back with `revoke`), even while the player is offline.
- The server setting **"Show shields, spellbooks and back weapons on
  characters"** turns the new look off again.

## 0.54.1 — glowing particle effects (2026-10-21)

The particle effects get stronger colours and shine in the dark.
**Compatible:** no map reset and no migration step.

- **Glowing and vivid:** every skill and proc effect shows its colour as
  intended instead of a greyish brown: holy gold, fire orange, frost blue.
  Lights, sparks, magic and fire shine at night and in caves without
  lighting up their surroundings; dust, smoke, mist and blood don't glow.
  Boss and monster effects, critical hits, absorbed hits and the level-up
  burst glow the same way.
- **Smite** now looks like a small Final Word: a short beam of light
  strikes the target and a small golden ring springs from its feet.
- **Meteor and Censure** fall faster: the burning rock and the seal of light
  appear later and drop quickly, still landing exactly with the impact.

## 0.54.0 — new armor (2026-10-21)

All armor is redrawn and gets real shapes. **Compatible:** no map reset and
no migration step; your character takes the new look at its next login.

- **Real shapes:** helmets, shoulder plates, bracers, skirts and boots stand
  out from the body. Each tier looks bigger and richer than the one below;
  metal is the bulkiest, leather layered, cloth smooth with ornaments.
- **New art for all three lines**, every tier in its own colours and with a
  new icon. Enchant colours sit on the cloth parts (prefix) and the
  fittings (suffix); a broken piece shows cracked.
- **Skirts and robes swing** with your legs when you walk, and your cloak
  hangs a little further back so it never cuts through them.
- **Helmets** hide the hair; the face shows through the opening, except
  for the closed metal helmets of the top two tiers.
- **Character page:** the model wears your armor and holds your weapon.
- **Guards, bandits and their kin** wear the new armor. Kings, royal guards
  and the fortress Generals wear royal armor in their people's colours and
  gold, without the gold elite glow; kings show their crown. The War
  Commanders wear their faction's colours.
- **Leather tier 4 is now "Hardened"** (Hardened Hood, Jerkin, Pants,
  Boots); your items keep working and take the new name after your next
  equipment change.

## 0.53.1 — fixes to the new classes (2026-10-20)

Fixes and wishes from the first look at 0.53.0. **Compatible:** no map
reset and no migration step of its own; a world still on 0.52 runs the
0.53.0 step once, as described there.

- **Area skills, cones and group heals** reach everything in their circle
  and up to 3 m above or below, through walls, step edges and corners; a
  floor 4 m or more away still stops them.
- **Tooltips show "Range: N m"** for every aimed skill, your talents and
  race included.
- **Flying:** the border warning starts 40 nodes out (was 48) and stays
  while you are near; on a flying mount the minimap shows where you may
  not fly in red.
- **Shields and spellbooks** name the classes that can really use them
  (shield: Warrior; spellbook: Mage, Priest).
- **The same trinket twice:** you may wear two copies. Bonuses add up to
  their cap; Last Light and Reclaimer's Mark fire once, and the second
  copy strengthens the effect by 5–30 % by its tier.
- **Races:** zombies and husks leave Undead alone by day and by night
  unless attacked; Elves get +3 m ability range (was +5); Dwarves' Thick
  Skin gives +5 % armor rating instead of less fall damage.
- **Skeleton archers** hold a bow.
- **Right-click** a ripe blueberry bush or an apple to pick it; left-click
  still works. Where you may not dig (towns, villages), you may not pick
  either.
- **36 skill and talent icons** replaced by simpler ones, readable at small
  size, weapons in their natural colours; eight of them return to their
  earlier look.

## 0.53.0 — the new classes (2026-10-20)

Every class plays anew: new skills, new talent trees and a new Talents
page. **Migration** needed: the server's host runs the migration tool once
on the stopped world (last point). No map reset, no new world. Your talent
points are reset: spend them again; your next respec is free.

- **Your own starting skills:** Warriors start with Strike and Charge,
  Mages with Fiery Spark and Ice Wave, Priests with Smite and Heal, Scouts
  with Loose, Sidestep and Sprint. Everything else comes from your
  talents.
- **New talent trees,** two per class, drawn as a map on the Talents &
  Skills page: a click buys a rank, a locked talent says what it needs.
  They unlock new skills (Flame Lance, Meteor, Rime Mantle, Bellow,
  Broadstroke, Hearten, Rebuke, Censure, True Draw, Split Shot, Parry,
  Flourish and more), turn some skills into others in place (Fiery Spark
  into Cold Spark, Strike into Retort, Loose into Bladecraft …) and end in
  one ultimate per tree from level 42: Fire Rain, Winter Field, Unbroken,
  Ruination, Haven, Final Word, Arrowfall or Close Dance. A new skill waits
  in the skill row until you drag it onto a hotbar.
- **A free basic attack for everyone,** first on a new character's
  hotbar; hold the button to keep attacking. If the selected skill cannot
  act, your basic attack fires once instead.
- **Every skill is instant.** A heavy one keeps you busy for a moment
  afterwards, and a weapon swing holds your next skill back by one swing.
- **Area skills** land on the ground under your crosshair after a short
  warning (also in caves); aimed at the sky they say "No ground found."
  and cost nothing. Area hits never crit.
- **Scouts no longer draw the bow:** Loose shoots at once and keeps
  shooting while held; with Bladecraft, left click swings your blade and
  right click shoots.
- **Health by class:** Warriors have more, Mages and Priests less (×1.2,
  ×0.8 and ×0.8; Scouts unchanged).
- **Gone:** Cinderfall, Glacial Ward and Pinning Shot, and every old
  talent.
- **New look and sound:** 25 new skill icons, new skill effects in each
  tree's colours and 20 new skill sounds (Blink has one now).
- **For the server's host:** stop the server, back the world up, run
  `python3 tools/migrate.py --world <world directory>` from the new
  version's checkout and start it
  ([updating a hosted world](README.md#your-own-world-or-server),
  [upgrade contract](docs/technical/upgrade-contract.md#1-four-outcomes)).
  The tool resets every character's talents (all points back), clears the
  old talent timers and removes the three retired skills from both
  hotbars and the bags; at the next join each character with a class sees
  one line, "Your talent points have been reset.". An older world moves
  to 0.53.0 in one update, crossing every map reset and step in between.

## 0.52.1 — surf at the coast, a sound under water, towns that sound like they look (2026-10-20)

Three ambience wishes from the 0.52.0 check. **Compatible:** no map reset
and no migration step; characters keep everything.

- **Surf at the coast:** within about 16 nodes of the sea the landscape's
  bed blends into the sea surf, full at the water line; on the water and
  over the open sea only the surf plays. Whether water is sea now comes
  from the map, so lakes, ponds, swamp pools and rivers inland never play
  the surf, and a cliff top above the sea still hears it. Beaches no
  longer play the surf by themselves (many lie far inland); they keep the
  bed of the land around them. No owls or other calls over the sea.
- **Under water:** diving plays a calm underwater bed (two recordings the
  user picked, one at random per dive) and nothing else.
- **Start towns:** a start town sounds like its own ground, whatever
  landscape lies under it: the human, elf and dwarf towns the temperate
  meadow and forest bed, the orc town the savanna, the troll town the
  jungle, the undead town the blight.
- `/ambience debug` shows the sea share, both levels and the playing file.

## 0.52.0 — ambience by landscape and height, the class rework's groundwork (2026-10-20)

The background sounds follow the landscape under you and your height above
or below the ground, real caves sound different from tunnels you dig, and
animals call now and then. The first step of the class rework is in: your
classes and talents play as before (only Mend's timing changes), the skill
row scrolls, most skill icons are redrawn and the selected skill shows a
small glow on your weapon. **Compatible:** no map reset and no migration
step; characters keep everything.

- **Sounds by landscape:** the background bed follows the landscape you
  stand in instead of the people's region. All temperate forests and
  meadows share one bed (the elves' and the dwarves' forests too), the
  savanna has the orcs' bed and the jungle the trolls'. New beds: quiet
  desert birds and crickets in the badlands, frogs in the swamp, mountain
  air and birds in the crags (silent at night), a snowy afternoon in the
  snowy crags (day and night), and "Abandoned Fields" on the
  Battlegrounds. New nights: owls and insects in the temperate lands, four
  night choruses in the jungle, frogs and a late evening in the swamp,
  crickets in the badlands. Walking from one forest into another no longer
  changes the bed.
- **Sounds by height:** digging down, the bed fades out by 15 nodes below
  the ground; building or flying up, it fades between 10 and 60 nodes
  above it, and a soft wind rises from 30 nodes up. On the highest peaks
  a quiet wind plays under the bed. Swimming and boats count from the
  water surface, so the bed stays there. Towers count as up, the ground
  around them decides.
- **Caves:** a real cave fades in a quiet cave bed (deep below, the
  crystal-cave bed); a tunnel you dig stays silent. A large dug hall counts
  as a cave.
- **Animal calls,** now and then and far off: crows by day on the
  Battlegrounds and in the blighted lands, hawks by day in the crags and
  the badlands, owls at night in the temperate lands, wolves at night in
  the crags and the pine hills. None underground or high on a tower.
- **Fires and water underground:** a burning furnace or flowing water near
  you is now heard in a mine as well.
- **The underground sky and fog** switch by the depth below the ground
  (more than 20 nodes down, back above 16) instead of at a fixed height,
  so a tunnel inside a mountain looks like underground too, and a level
  tunnel under hills does not flicker.
- **Dropped sounds:** the elves' blackbirds, the graveyard wind, the
  orcs' wind, the dwarves' storm and two dark cave beds.
- **`/ambience debug`** shows a line with the landscape, its sound group,
  your depth, the cave reading and the beds' levels.
- **Mend** heals 3 s after the cast and then every 3 s, four times, each
  heal counting from your own cast (before, all Mends ticked on one shared
  beat).
- **The skill row** in Talents & Skills scrolls sideways once you own more
  skills than fit; the talent text above it is a little shorter.
- **Redrawn skill icons:** 19 of the 22 skills have new icons in one
  painted style; Cinderfall, Glacial Ward and Pinning Shot keep theirs for
  now.
- **A glow on your weapon:** the selected skill shows a small animated
  accent of its talent tree on the weapon in your hand, in first person:
  embers, rime, steel, rage, warm healing light, judgment gold, wild green
  and shadow, drawn for each weapon type (the bow follows its draw). Strike
  and an empty hand show none; other players do not see it.
- **Groundwork for the new classes** (not playable yet): the new talent
  trees exist with their backgrounds and talent icons, and admins can look
  at them read-only (`/talent_preview`). Your talents stay as they are
  until the class update, which will reset every character's talents with
  all points refunded.

## 0.51.0 — land zones and the sea (2026-10-19)

A larger sea with a wide coastal belt, natural bays and channels, seabed
meadows, shipwrecks and creatures of their own, the sea coloured by depth
on the map, and a few characteristic changes in every land zone: calm
ground textures, new plants, ruins, graveyards, cairns, statues and
varied bones. **Map reset** needed: world generation changed, so an
existing world's map is generated anew from its seed. Characters keep
their level, gear, inventory, money, quests, professions, mounts and
waypoints, as in every map reset; their position and home claim go with
the old map, and the containers in a housing claim come back through the
Claim Stone's Belongings tab (since 0.50.0). No migration step: the new
version reads every character as it is.

- **A larger world:** the sea reaches 450 nodes farther east and west and
  400 farther north and south. The land stays exactly where it was.
- **Bays:** no more specks of open sea at a bay's rim, and a bay opens into
  the sea through a natural mouth instead of a straight cut.
- **The coastal belt:** the open sea now begins about 250–350 nodes off
  the coast (was 80). The belt belongs to the zone on the land beside it:
  its level, faction and PvP rule. It deepens gently, about 3 nodes deep
  25 nodes out, 11 at 150 and 18 at 300.
- **Dragon channels:** the straits to the two dragon islands are shallow
  natural channels, 9–11 nodes deep, with their island's level 60; a boat
  passes everywhere. They still have no PvP rule.
- **Protected water:** bay, belt and channel water 24 nodes or more off the
  coast cannot be built on, dug (the seabed included) or claimed, like the
  open sea; a refused try says "Deep water – protected". The shore nearer
  than 24 nodes stays as editable as its zone, and lakes and rivers are
  never protected. A Claim Stone may reach bay water only within 24 nodes
  of the coast.
- **Seabed growth:** coral patches down to about 10 nodes, kelp meadows
  down to about 20 (never reaching the surface) and seagrass meadows in
  three kinds down to about 14, in the belt, the bays and the channels.
  The open sea stays bare. Meadows thin out toward their edges, with
  single tufts beyond, and coral patches have ragged rims. Seagrass, kelp
  (now a kelp of our own) and the lakes' waterweed sway gently for every
  player, with or without the "Waving plants" setting. Seagrass and kelp
  you dig leave sand and grow back near players; coral does not.
- **Shipwrecks:** four kinds (a hull, a bow, a stern and a debris field)
  lie on the protected seabed of the belt and the bays, up to 14 nodes deep
  (mostly 7–11),
  at most four per zone and about 55 per world, with kelp growing round
  them. A hull's broken mast reaches near the surface.
- **Water creatures:** five new families, all silent:
  - the **tortoise** (Pond Terrapin to Stoneback Tortoise) in the coastal
    shallows and at lakes, neutral, following you ashore when struck;
  - the **frog** (Marsh Frog to Blackwater Toad) at lakes, rivers and swamp
    pools, hostile, following you ashore;
  - the **stingray** (Sand Ray to Thornback Ray) in deeper belt, bay and
    channel water at least 16 nodes from land, and the level-60 Wyrmwake
    Ray in the dragon channels;
  - the **Bay Shark** (level 30) in the deep middle of the bays and the
    rare elite **Abyssal Shark** (level 70) in the open sea beside the
    Kraken;
  - the **Tide Goby**, a small fish in any sea water (no XP).

  The tortoise, the frog and the stingray take the level of the zone around
  them (the sharks have fixed levels); the level 1–2 home belts
  have no frogs and no stingrays. Each drops its band's fish (the tortoise
  and the frog sometimes meat too; the Abyssal Shark 3–6 Storm Tuna), and
  quests can name the tortoise, frog and stingray like any zone creature.
- **Amphibians swim:** the tortoise, the frog, the crocodile and the crabs
  swim at one height just under the surface instead of bobbing up and
  down, and water never hurts them; the frog swims with a stroke. Other
  creatures still keep their heads above water as before.
- **Fish in lakes:** Reed Angelfish swim in wild lakes and in the lakes of
  Kezamba and Lethariel; no fighting creature lives in a capital's lake.
- **Swimmers let go at the shore:** a stingray or shark whose target
  leaves the water onto a beach, bank or pier gives up, heals, ignores
  that player for a moment and swims back. In the water or in a boat you
  stay in reach.
- **The map:** the sea is coloured by depth: light at the coast, a middle
  blue over the belt, the bays and the channels, dark over the open sea,
  blending softly into each other. Bay shores get the coast line. The map
  covers the larger world, at 1215 × 1080 (normal) or 3600 × 3200 (high);
  at 1x, names and icons look a little smaller. It is rendered anew at the
  first start (about 14 seconds at normal quality, about a minute at high).
- **Calm grounds:** many ground textures are larger and calmer, one
  picture over 2 × 2 nodes with no visible grid: the swamp's wet grass and
  mud, dry mud, both moss soils, the undead bone litter and blight dirt,
  the jungle's canopy litter, the elves' silver litter, mesa clay and sand,
  above and under water.
- **The swamp:** its own muted Swamp Moss ground (digging gives mud), and
  the elf forest's moss soil is muted too. Hanging moss hangs as one
  continuous strand with a tapered tip; digging the lowest piece moves the
  tip up, digging a middle piece drops the pieces below it. The papyrus
  on dirt pedestals is gone (see the shores below).
- **The jungle:** lianas hang from the leaves of jungle and kapok trees
  (Kezamba's too), with Ruby Fan, Ember Star and Violet Fan flowers, ferns,
  jungle bushes and fallen kapok logs.
- **The undead lands:** small graveyards with steles and crosses, fallen
  and sunken gravestones and a fence here and there; ruined arches,
  columns and wall corners, a collapsed crypt now and then, kneeling
  mourner statues, obelisks, fallen gravewood logs and stumps, grave
  mounds. Bones are rarer and varied: skulls, ribcages, spines, scattered
  long bones and fragments instead of one bone pile.
- **The dwarves' crags:** boulders, two kinds of cairns, sparse lichen
  patches on gravel and stone, Alpine Cushion and Alpine Windshrub, dead
  pines on the snow, and small ice patches in the snowy crags.
- **The orc badlands:** steep slopes and mountains show ochre, sienna,
  chalk and umber clay bands by height; flat ground stays mesa clay. Bones
  and withered bushes lie about.
- **The elves' forests:** ruins, statues, fallen logs and the pastel
  flowers Blush Star, Lilac Bells and Cream Cups.
- **Beaches and shores:** small gravel patches in dry sand (on lake and
  river banks too); papyrus grows 2–4 tall right on the sand by the water
  in the warm zones, no longer on a pedestal; marram grass on dry sand and
  driftwood on the beaches.
- **Lakes:** wild lakes have lily pads near the shore and waterweed on the
  bed, and both grow back near players; Kezamba's and Lethariel's lakes
  have lily pads and waterweed too, as do the start towns' ponds.
- **Towns:** the start towns have about half as many trees; Stillgrave
  keeps its graveyards and has only scattered bones elsewhere; the
  capitals' cores have much less and patchier ground cover (Nhal Veyr far
  fewer bones), and the rest of each capital's ground has sparse plants of
  its zone (a few bones at Nhal Veyr).
- **Town graveyards:** every town's graves are the new gravestones
  (Stillgrave, Nhal Veyr, Kezamba, Highcourt, Gor Drazhak, Dur Brannoc and
  Lethariel), and the bones in Stillgrave and Nhal Veyr are the varied
  pieces.
- **Drops:** a decorative block gives an ordinary block (cobblestone,
  stone, silver sandstone, wood, a stick; a clay band gives mesa clay, the
  swamp moss mud). Decorative plants and bones give nothing; that now
  includes ferns and marram grass everywhere.
- **Plants that come back:** the new flowers, alpine plants, lichen,
  papyrus and marram grow back near players like the other wild plants.
  Lianas and hanging moss come only with their tree, bushes and coral not
  at all.
- **Server admins:** a server on 0.50.x (the production world) moves to
  0.51.0 with this one map reset and no migration step; a world on 0.48.x
  also crosses 0.49.0's reset, and one reset covers both. Before
  the map is emptied, the migration tool's pre-reset pass packs every
  claim's containers (declaration `map_reset_pass` 0.50.0). The first
  start renders the larger map; a full preparation covers about a quarter
  more tiles, all of them sea.

## 0.50.2 — where a Claim Stone may go, and where claims are (2026-10-17)

Existing worlds play on: no migration step, no map reset, no new world. The
world map re-renders once at the first start (about 10 seconds longer).

- **Claim Stone preview:** while you hold your Claim Stone, the minimap
  shows where it may go. Ground a claim may not cover is red: the other
  faction's land, level 1–10 and 31+ zones, capital zones, land that is not
  your faction's home, the coastal shelf and the sea, and towns, villages,
  camps, points of interest and landmarks with their 16-node distance.
  Every other claim is red too, drafts included; a draft another player
  places nearby shows at once and goes when it is picked up or crumbles.
  Your own 101 × 101 square is green on your arrow: where it touches no
  red, the claim fits (the stone itself still needs room above it and must
  stand at y −100 or higher). The red is drawn a little generously, so a
  square that only touches red may still fit.
- With the minimap switched off, it appears while you hold the stone and
  goes again afterwards. Any other item in your hand shows the normal
  minimap.
- The placement rules and their messages are unchanged.
- **Your home by name:** inside a claim the line under the minimap, the
  zone banner and the map window say "Your Home" in your own claim and
  "<name>'s Home" in anyone else's, right to its edge and from y −100
  upwards, so you can see where its protection ends. The territory line
  stays.
- **Claims on the minimap:** without the stone in hand, the minimap frames
  your own claim in green and every other claim in yellow. With the stone
  in hand, the preview above shows instead.
- **Zone banner:** a new place or territory now replaces a banner that is
  still showing at once, and the last one stays its full 4 seconds; until
  now a showing banner held the next one back.

## 0.50.1 — a complete dry run before a map reset (2026-10-17)

Existing worlds play on: no migration step, no map reset, no new world.
Nothing changes in the game.

- **Server admins:** `tools/migrate.py --check --map-reset` is now a
  complete dry run of the pre-reset pass. It reads every map block of every
  housing claim, refuses for the same reasons as the pass, reports what
  the pass would pack and writes nothing. A check that passes means the
  pass will not refuse on the same unchanged world.
- **Server admins:** the pass also accepts a world recorded as 0.48.0 (a
  world moved to 0.48.1 and not started since); 0.48.1 changed nothing the
  pass reads.

## 0.50.0 — two hotbars and belongings kept across a map reset (2026-10-16)

Existing worlds play on: no migration step, no map reset, no new world.

- **Hotbar A and B:** two buttons, "A" and "B", switch between two hotbar
  layouts. They sit next to the hotbar on every inventory page, at every
  station (furnace, workspaces, chests, bookshelf, vessels shelf, Claim
  Stone), in the mail's Write tab and in the quick menu (E). Your current
  hotbar is A; B starts empty. A skill may lie on both. Switching works in
  a fight too: it cancels a cast, a draw or eating in progress, at most
  about four times a second. Crafting, arrows, quest turn-ins and the
  Claim Stone's fuel take from the hidden layout last; the merchant does
  not offer to buy what lies there, and the repair quote includes it.
- **Talent unlocks** no longer put the new skill on your hotbar: drag it
  from Talents & Skills to the layout you want. The class kit still lands
  on the hotbar you see.
- **Belongings across a map reset:** when the server regenerates its map,
  everything in your housing claim that holds items comes back: chests,
  locked chests, furnaces, bookshelves and vessels shelves with their
  contents, other stations as plain items with their contents in a packed
  chest, and the Claim Stone's remaining fuel as charcoal. They wait in a new **Belongings** tab of your Claim Stone
  once you place a new one and activate it with coal; you are told at
  login, and the Housing Steward says so too. A packed container is
  bound to you (it cannot be dropped, stored, mailed or sold) and becomes
  the container with its exact contents when you place it. Empty
  containers come back as plain items. Nothing waiting is lost when the
  stone is picked up or destroyed. **Server admins:** this happens at
  every map reset from this version on, run by the migration tool before
  the map is emptied (upgrade declaration schema 3, `map_reset_pass`).

## 0.49.1 — fix after the first 0.49.0 feedback (2026-10-16)

Existing worlds play on: no migration step, no map reset, no new world.

- **Mail:** letters, replies and messages to the admin hold up to 4,000
  characters (was 1,500), and a hint under the message field says so. A
  longer text is not sent: the status line names its length and the
  limit, and the text, the attachments and your money stay. A reply quotes
  at most 500 characters of the original, ending in " [...]".
- **Stations:** the furnace, chests, the bookshelf, the vessels shelf,
  the Claim Stone and the profession workspaces show your whole bag: the
  hotbar below, the rest of your inventory and your bags scrolling in three
  rows above it. Shift-click moves items between the station and your bags.
- **Furnace:** the fire and the arrow run smoothly over the burn and
  cooking time, and the window is no longer sent again every second (about
  a tenth of the traffic while a furnace is open), so scrolling the bag is
  no longer interrupted.
- **Doors before people:** a right-click on a closed door opens it, also
  when a villager, quest giver or vendor stands right behind it.
- **Drops:** a drop that kept sliding slowly over the ground and could not
  be picked up now settles where it really lies, and a click on a drop in
  reach picks it up. It happened when a network packet was lost, more
  often in busy places.
- **Walking legs:** guards, leaders, bandits, mirefolk, villagers and
  goblins move their legs at a pace that fits their walking speed.
- **PvP fortresses:** the floating wagon wheel is gone from fortresses
  generated from now on. A world coming from 0.48.x or earlier passes
  0.49.0's map reset on this update, so its fortresses are built anew
  without the wheel. **Server admins:** only a world that already runs
  0.49.0 keeps its wheels; dig them by hand in both fortresses (Ashenward
  Bastion and Bannerbreak Warhold).

## 0.49.0 — faster world generation and gameplay polish (2026-10-16)

The world generates much faster, above all underground, with ores, gems
and cave plants now placed by the engine's own map generator, and a round
of gameplay polish: postage at Send, item tooltips when selling, the Claim
Stone in your bags, the starter kit on the hotbar, kill XP and the rare
tier, creatures that find their way round bushes and trees, smaller
blocks in the hand and a half-buried onion. **Map reset** needed: world
generation changed, so an existing world's map is generated anew from its
seed. Characters keep their level, gear, inventory, money, quests,
professions, mounts and waypoints, as in every map reset; their position
and home claim go with the old map. No migration step: the new version
reads every character as it is.

- **Ores, gems and cave plants** come from the engine's own map generator.
  Every depth layer holds them about as often as before (counted within a
  few percent of the table); gems lie as single nodes or pairs, coal and
  ores in clumps. Ores and gems now also lie under towns and deep water.
  Mountains and raised land the game builds above the engine's ground
  hold ores at the same rate. Cave Cap and Ember Moss grow on cave floors
  in their depth bands, about one in every 1,500 to 2,000 floors as
  before, under towns too.
- **Faster world generation:** going deep now generates almost
  instantly: a chunk below about y −113 costs the game no work of its own
  (about 40 chunks per second instead of about 2 on one core). New land at
  the surface generates about twice as fast, the next chunk of a column
  about two and a half times as fast. The engine's own v7 mountains are
  switched off; the land you see is the game's and stays as it was, but
  fewer caves open in the top tens of blocks under hills and highlands.
- **Trees and decorations are placed anew:** every tree, plant and
  gathering node is drawn by a faster rule, as many as before at other
  spots; tree shapes and rotations still vary.
- **Town protection:** the protected ground under a town now ends 80
  blocks below the town (was 100). Digging beside and under a town works
  from there; the town's own ground still cannot be dug through.
- **Mail and selling:** the Write tab shows the postage rule ("Postage:
  5c per letter + 30c per filled slot", paid when you send); Send charges the
  attachments as they are at the click, once, and the line names the
  amount ("Letter sent to X. Postage paid: 65c."); the text you typed
  stays. On the merchant's Sell tab, hovering an item shows its tooltip
  with its quality, stats and enchants.
- **The Claim Stone** may lie in any of your bags as well as the main
  inventory and the hotbar, and sorting leaves it where it is; chests,
  stations, equipment slots, trades and mail still refuse it, and
  dropping it still destroys it. The Housing Steward shows "Receive Claim
  Stone" only when you can receive one; otherwise the reason stands in
  its place (below level 20, a stone already placed, a stone already
  carried). With a full inventory the button stays and the click asks you
  to make room.
- **Starter kit and skills:** a new character finds its apples on hotbar
  slot 7 and its torches on 8. When a skill a talent unlocks finds the
  hotbar full, the rightmost item that is not a skill moves into your
  inventory and the skill takes its slot; with no room there either, the
  skill waits in the skill row as before.
- **Kill XP and the rare tier:** a kill pays 10 % less per level below
  yours (was 15 %): 3 below 70 %, 9 below 10 %; from 10 below it pays
  nothing and the name line shows gray with (no XP) (was 7 below). Above
  your level nothing changed. A rare (★, violet, twice the size) now sits
  between a normal and an elite: 2.5 times a normal's health, 1.4 times its
  damage and twice its XP (was 5, 2.2 and 6 times), with its size, tint,
  warning and loot as before.
- **Creatures that chase you:** zombies, giant rats and other creatures
  reach you behind bushes and tree trunks, also one or two blocks above
  them: their route steps round low leaves and, for wide creatures,
  round trunks, and a creature that gets stuck looks further round each
  time. Archers and other creatures with a ranged attack that lose sight
  of you walk round the cover until they see you again, then stop and
  shoot; they never shoot into cover. Flyers and the kings behave as
  before.
- **Looks:** a block held in the hand (dirt, stone, slabs, stairs) shows
  at 70 % of its old size in third-person view and to other players, NPCs
  included; tools, torches, plants and the first-person view are
  unchanged. The wild onion and the grown field onion sit half in the
  ground; the onion item is unchanged.
- **This release needs a map reset** (for the server's host): stop the
  server, back the world up, empty the map, raise `grug_reset_world` and
  start it ([updating a hosted world](README.md#your-own-world-or-server),
  [upgrade contract](docs/technical/upgrade-contract.md#1-four-outcomes)).
  No migration step for 0.49.0; a world older than 0.48.0 still runs
  `python3 tools/migrate.py --world <world directory>` for the steps it
  crosses. The game now sets the v7 flag `nomountains` itself and writes
  it over the world's `map_meta.txt` at every start, so a world created
  with the old flags needs nothing beyond the map reset. The first start
  after the reset, like a new world's, is ready about 13 s sooner (66
  instead of 79 s on the measuring PC). The server uses about 30–40 MiB
  more memory for the map generator's larger column cache.

## 0.48.1 — fix after the first 0.48.0 playtest (2026-10-14)

Existing worlds play on: no migration step, no map reset, no new world.

- **Inventory:** the bags' slots flow on in rows of eight. A bag starts
  right after the last slot of the one before, so three Small Bags fill
  one and a half rows instead of three half-empty ones.

## 0.48.0 — mail, plants and light, selling, smaller bags (2026-10-14)

Mailboxes beside every waystone of the capitals and starting villages,
letters with attachments between players and to the admin, plants that
need light (and some that do not), Melon and Mushroom as crops, a salt
pan, a vendor that buys almost everything, leaves and cactus as fuel, a
daytime band beside the minimap and bags at half size. **Map reset**
needed: the mailboxes are placed by world generation, so an existing
world's map is generated anew from its seed. Characters keep their level,
gear, inventory, money, quests, professions, mounts and waypoints; their
position and home claim go with the old map. **Plus a migration step:**
the bags shrink at each character's next join, and what no longer fits
arrives by mail (the "Bags" point below).

- **Mail and mailboxes:** every capital and every starting village has a
  mailbox on its waystone's pad, two blocks east and one north of the
  stone. It opens a window with Letters, Announcements, Write and To the
  admin. Write to any character of your own faction, online or not, once
  it has joined since the update: postage is 5c a letter plus 30c for
  each attached stack, up to four stacks ("Send (65c)"; if you change
  the attachments after the window was drawn, the first Send shows the
  new postage and the second pays it). Soulbound items, skills and mount items cannot be sent. A mailbox
  holds 50 player letters; every letter is deleted 30 days after it
  arrived, its attachments too. Take all moves every attachment into your
  bags or none. Reply quotes the letter; Report sends a player letter to
  the admin. An envelope beside the minimap counts unread letters (1–9,
  then 9+).
- **The starter quest and letters:** every character gets the quest "Use
  a mailbox in one of the cities" (30 XP and 25c) and a welcome letter;
  existing characters get both at their first join. At level 15 the
  Riding Trainer writes (only while you own no riding tier), at level 20
  the Housing Steward (only if you never had a Claim Stone).
- **Writing to the admin** is free: pick a topic (Feedback, Bug report,
  Question, Player report, Other); the game version and the mailbox are
  attached. Up to five open messages; each shows Open, Answered or Closed,
  and an answer arrives as a letter from "Server Admin". The admin can
  also send letters to one player or announcements to all.
- **Plants and light:** a growing crop needs daylight or torchlight (light
  8, measured as at noon, so outdoor fields still grow at night and a
  torchlit field grows indoors); in the dark it pauses and keeps its
  progress. Cave Cap, Mushroom and Ember Moss grow in the dark. Papyrus
  grows on any soil or sand near water, cactus on sand or mesa clay, both
  indoors by torchlight; digging a piece takes every piece above it, so
  leaving the bottom piece keeps the plant. Saplings grow only in
  daylight (a glass roof lets it through; torches do not help).
- **New crops, spores and salt:** Melon and Mushroom are crops (Melon
  Seeds, Mushroom Spores); the seeds of Cave Cap, Mushroom and Ember Moss
  are called Spores. Salt Crust is no longer a crop: the **Salt Pan** (3
  Embersteel Bars, a Water Bucket and a Salt Crust) placed near water
  fills with Salt Crust, also in the dark; right-click scrapes it. Salt
  Crust Seeds you still hold become Salt Crust. Rock Salt and Salt Crust
  now regrow in the wild. A bucket of river water is a "River Water
  Bucket" and goes into no recipe; a Water Bucket filled in 0.47 must be
  poured and refilled once before the Salt Pan recipe takes it. Every
  plant item has a line on how it grows or where it is found, and the
  wild crops (Potato and Corn in the meadows, Melon in the jungle) look
  like grown plants.
- **Selling almost everything:** vendors buy potions, dishes, seeds,
  tools, crafted bags, stations, blocks and building materials. Cheap goods
  sell in lots: "Cobblestone x143 · 1c per 50 · All (2c)" sells 100 and
  leaves 43; below one lot the row is greyed ("Need 50 to sell"). Stone,
  sand, gravel, leaves and saplings sell at 1c per 50, logs and cactus at
  1c per 20, planks at 1c per 99; the Mason's cobblestone, gravel and
  bricks now sell in these lots too. Crafted goods pay half the value of
  their materials, storage blocks nine times their item. **Everything that
  sold in 0.47 sells for exactly the same price**; only the Small Bag's
  buy-back follows its new price (1c). The Bag of Coins, the Fallen Crown,
  the Captain's Orders, soulbound items, dirt and the like stay unsellable,
  and so does the Salt Pan for now. All takes from your main inventory
  and the hotbar before the bags.
- **Fuel:** cactus burns 15 s in a furnace (about one and a half bars),
  leaves 2 s (five per bar).
- **The daytime band:** a small band shows where the day stands, without
  numbers: the long day with the sun, the short night with the moon, the
  coming phase entering from the right. It stands in one row with the mail
  icon, the same height, left of the minimap along its top edge; with the
  minimap hidden the row moves into the top-right corner with "Now
  playing" right below it, and the quest tracker keeps its place.
- **Bags:** every bag holds half as much: 4, 8, 12 and 16 slots (were 8,
  16, 24 and 32). The Small Bag costs 20c (was 80c). At each existing
  character's first join after the update, the inventory and bags are
  sorted once into the new sizes (the hotbar and equipped gear stay as
  they are); what no longer fits arrives as "Lost and Found" letters of
  four stacks each, with one line in the feed. Make room, then Take all.
- **New art:** the mailbox, the envelope icon, the daytime band with sun
  and moon, the admin shield and the NPC seal; Cassava, Wild Onion,
  Pumpkin, Melon, Mushroom, Sunleaf, Gravemoss, Wild Cocoa and the Salt
  Pan.
- **This release needs a map reset and a migration step** (for the
  server's host): stop the server, back the world up, empty the map, run
  `python3 tools/migrate.py --world <world directory>` from the new
  version's checkout, raise `grug_reset_world` and start it
  ([updating a hosted world](README.md#your-own-world-or-server),
  [upgrade contract](docs/technical/upgrade-contract.md#1-four-outcomes)).
  The tool only marks each character; at its next join the game sorts its
  bags into the new sizes and mails the rest. Mail lives in the world's
  mod storage, not in the map, so letters survive this and later map
  resets. The new privilege `mail_admin` opens the Admin Mail tab
  (messages to the admin, answers, admin letters and announcements); the
  server's admin has it, anyone else needs `/grant <name> mail_admin`. A
  world on 0.45.1 (or 0.47.0) moves to 0.48.0 in one update, crossing
  every map reset and step in between (0.46.0, 0.47.0 and 0.48.0).

## 0.47.0 — trees, mining progression and crafting feedback (2026-10-14)

New trees grown from each world's seed, a swamp worth walking through, a
mining ladder with Anthracite and Steel, quieter furnaces, crafts that land
in your bags and recipes you discover by holding their ingredients.
**Map reset** needed: world generation changed, so an existing world's map
is generated anew from its seed. Characters keep their level, gear,
inventory, money, quests, professions, mounts and waypoints; their
position and home claim go with the old map. **Plus a migration step:**
the copies of tool capabilities that crafted and broken tools keep are
rebuilt at each character's next join (last point below).

- **Trees and forests:** every tree species grows from a generator with a
  stem, limbs, twigs and round, uneven crowns, and every world has its own
  trees: 32 shapes per species (16 for the kapok) made from the world's
  seed at each start. Thick trunks have slanted, eight-sided sides,
  limbs join the trunk, twigs reach into the leaves, and apple, jungle and
  kapok trees put roots on the ground around them. A partly felled thick
  trunk shows cut wood. Jungle trees have a new deep red-brown bark. Every
  trunk piece drops its log; the pieces cannot be placed. Leaves decay
  once no wood of their tree is within 3 blocks. Wild forests are about
  as dense as before, with crowns that sometimes interleave, and a
  planted sapling grows a tree of the same kind (apples on it regrow).
- **Towns and capitals:** town trees come from the same generator. Town
  groves are denser and never empty, start towns gain trees on free
  ground, and the six capitals get trees on the open grass between their
  districts and in their yards (about 1,560 on a world, different on
  every world), never on streets, squares, doors or near an NPC. The
  stone kerb round each capital plot is gone.
- **The swamp:** the ground mixes mud, lighter and mottled mud, wet grass
  and moss soil. Small pools one or two blocks deep with waterlilies and
  reeds lie on flat ground and never spill; reeds, cattails, ferns, tall
  grass and moss carpets grow round them. Swamp trees stand low and
  crooked on short stilts, with sparse olive leaves and hanging moss.
  Crocodiles, bog oozes and bog fowl spawn on all the new grounds.
- **Mining and ores:** an ore that belongs to the next layer lies only in
  the lower half of the layer above it: no Iron above y −50, Silver
  below −400, Emberglass below −600, Abyssal Crystal below −850. Iron now
  needs a Bronze pick ("Requires a Bronze pick"); Wood and Stone picks no
  longer dig it, and every other dig time stays the same. **Anthracite**
  is a new ore from y −200 (with an Iron pick) that replaces Coal from
  y −300 down; below −300 there is no Coal. Anthracite burns 120 s in a
  furnace (Coal 80 s), and 1 Anthracite and 1 Stick make 10 Anthracite
  Torches, which light wider (14) and keep cave creatures about 6 blocks
  away (a Coal torch 4).
- **Steel and furnaces:** Steel is Iron Bar + Anthracite in the Dual
  Furnace, and only that. Every alloy takes 10 s, like a bar. The Dual
  Furnace now plays the furnace's fire sound, both furnaces play it at
  60 % of the old volume (camp fires are unchanged), and a dug furnace
  falls silent within a quarter second.
- **Claim Stone:** its fuel limit is time, about 30 days (99 lumps'
  worth); Anthracite counts as one and a half lumps. A piece goes in only
  if all of its time fits, otherwise the stone says how much more it
  takes. Picking the stone up still refunds the rest in Charcoal, and
  activation still takes 5 Coal or Charcoal. T2 armour enchants take any
  coal (Charcoal too), T3 sword and armour enchants take Anthracite.
- **Crafting:** finished items go straight into your inventory, one by
  one as each craft finishes. A craft starts only if its result fits once
  the ingredients are taken ("Not enough room in inventory"; Max counts
  the room). If your bags fill up meanwhile, the rest waits in an
  **Overflow** area that shows only then and empties itself as soon as
  there is room; Take all is gone. Enchants and upgrades also deliver into
  the inventory. **Basic recipes unlock** once you have held every
  ingredient at least once (any kind counts for "any wood" and the like):
  "New recipe: …" tells you. Sticks and the wooden tools are known from
  the start; an existing character's bags are scanned silently at its
  first login.
- **NPCs and zones:** town, village, camp and capital NPCs no longer stand
  facing a wall. The zone banner stays 4 s. The first time a character
  enters a zone it gains about a quarter of a quest's XP at the zone's
  level (or its own, if lower) with the level-up chime; towns, capital
  zones and the open sea do not count. After the map reset every
  character starts in its start zone, so the zones it knew before pay
  once more.
- **The map window:** buttons under the map pick one layer at a time:
  Quests, Bosses, Trainers, Towns, POIs, PvP, Zones or None; every marker
  has a tooltip with its name. Selecting a quest shows only its targets,
  each with its objective lines, and its hand-in NPC. Party members'
  arrows carry their names and move every 2 s. The world map image no
  longer has icons baked in (the minimap keeps them); zone names show on
  one line with their level band ("Dawnmere Fields 1–10").
- **This release needs a map reset and a migration step** (for the
  server's host): stop the server, back the world up, empty the map, run
  `python3 tools/migrate.py --world <world directory>` from the new
  version's checkout, raise `grug_reset_world` and start it
  ([updating a hosted world](README.md#your-own-world-or-server),
  [upgrade contract](docs/technical/upgrade-contract.md#1-four-outcomes)).
  The tool only marks each character; at its next join the game rebuilds
  its picks, axes, shovels and hoes from their current definition, so an
  Iron pick crafted before keeps digging T2 rock (a broken tool stays
  broken). 0.46.0
  was never deployed on its own: a world on 0.45.1 crosses both map
  resets and the 0.47.0 step in this one update, and gets every 0.46.0
  change below with it (0.47.0's ore rows replace 0.46.0's extra Coal in
  the Steel layer: no Coal below −300).

## 0.46.0 — world generation and player feedback (2026-10-13)

Villages, camps, mines and the PvP places are placed anew on every world,
the ore and gem table is revised, and the players' feedback of 2026-10-12
is answered: XP, caves, rage, loot, cooking, repairs. **Map reset**
needed: world generation changed, so an existing world's map is generated
anew from its seed. Characters keep their level, gear, inventory, money,
quests, professions, mounts and waypoints, as in every map reset; their
position and home claim go with the old map. No migration step: the new
version reads every character as it is. The production server stays on
0.45.1 for now and moves later, with one update that combines several
releases.

- **World and map:** villages, outposts, bandit and Mirefolk camps, mines,
  clash sites, rare creature dens, the sixteen PvP war camps and the two
  fortresses no longer stand at fixed spots: every world places them by
  rules for each kind, on dry, fitting ground in their own zone and level
  band, away from towns, rivers and the coast. Two worlds with different
  seeds look different. Start towns, capitals, the dragon arenas, the apex
  mines and the four rift sites stay where they were, and each fortress
  keeps its side of the middle road. Roads lead to the new places and
  quest markers point to them. Seeds that failed to load (a river covering
  a camp) now load. A new world's first start takes about a second longer.
- **Mining and gathering:** every gem is also found one layer deeper (at
  half its usual rate) and two layers deeper (at a quarter), and it still
  needs its own layer's pick. The Steel layer (y −301 to −500) holds more
  Coal and Iron. Ore and gems give half the XP they did (a gem still twice
  an ore), and ore, gems and fish above your level pay as at your level.
  One Coal Lump or Charcoal and one Stick make 10 torches instead of 4, in
  one recipe; Charcoal also makes black dye.
- **XP and quests:** a kill pays XP by the level difference: 15 % less per
  level below yours, none from 7 levels below; 10 % more per level above,
  up to one and a half times at 5 above. Elites still pay four times,
  rares six times; in a party everyone still counts. The name line over
  what you look at shades from green through yellow at your level to red
  at 5 above, and every creature that gives you no XP (7 below, small
  animals, your own faction's guards) shows grey with (no XP). The 55
  repeatable bounty quests are gone; a bounty in your quest log simply
  disappears. Apprentice Riding and the Boat cost 1s 10c, the bracket-5
  respec 5s 50c.
- **Combat:** a Warrior's rage per hit follows the weapon's speed: a dagger
  gives less per hit, a battle axe more, every weapon the same rage per
  second (the Strike tooltip shows the value). A Mage's or Priest's spells
  take half their base damage from the equipped staff or wand: with
  own-level gear nothing changes, an old staff hits a little weaker, no
  staff or wand hits at half the base. Their damage talents follow the
  same base; staff, wand and talent tooltips say so.
- **Loot, money and crafting:** creatures no longer drop the 23 items that
  were only good for selling. Instead about one kill in eight drops a Bag
  of Coins of the area's worth; with the new Auto box beside the coin slot
  ticked (the default), a picked-up bag goes straight to your money.
  Creatures that drop cloth (zombies, outlaws and the like) now drop it on
  every looted kill, one or two at a time, and spiders roam the level
  41–50 zones again by night, so silk has a source there. In the crafting
  box, an ingredient that several kinds you carry can fill has a dropdown:
  Automatic, or the kind to use.
- **Cooking:** a new kind of dish, **plain**: tier healing and a little
  regeneration, no extra stat, always weaker than the other dishes. Six
  plain dishes, one per tier, from few local ingredients (Spiced Skewer,
  Pan-Fried Trout, Mire Carp Stew, Frostfin Fillet, Smoked Ember Eel,
  Kelp-Steamed Tuna); Cooked Meat, the Meat Block, Cooked Fish and Bread
  are plain now. Carrot and Cassava count as staples, so every start zone
  and every level 11–20 zone can cook with what grows there. The fish
  dishes that needed Raw Fish take any raw fish, and five recipes changed
  an ingredient (Mushroom Skewer, Raw Forager's Pot, Salt-Crusted Fish and
  Stormkelp Broth, Cocoa-Rubbed Game).
- **The underground and the depth pulse:** cave creatures appear from just
  below y 0 down, in shallow caves too, and in more of the dark: within 4
  blocks of a torch none appear, from the fifth they can. They notice you
  from about 26 blocks, and about one in 25 from level 5 on is an elite
  with the usual warning. Below y −300 the **depth pulse** sends flying
  servants after miners: after a silent two-second violet glow a Blood
  Bat, Glowwing, Ember Wisp or, below −1000, the new Riftwing, a Rift
  Spawn or a Bedrock Sentinel appears 6 to 14 blocks away in sight. One
  comes about every two minutes at −300, every minute at −1000 and every
  30 seconds from −2000, never more than a few at once, never in claims or
  towns; it fades when it loses you and pays full XP and its family's
  loot, but no Bag of Coins.
- **Towns and repair:** gear is repaired only in towns, by the profession
  trainers and the mender of Grudge-Free Repairs; claim furnaces no longer
  repair. The mender has a hammer-and-anvil icon on the map and the
  minimap.
- **Joining a server:** a new character, one still being created, and every
  character after a map reset wait at a quiet spot high above the world,
  where nothing loads around them, until their start town is ready; then
  they arrive there.

## 0.45.1 — fix round after the 0.45.0 playtest (2026-10-10)

Fixes from the 0.45.0 playtest. Existing worlds play on: no migration
step, no map reset, no new world. Town NPCs that had sunk into the floor
are put back on their feet the next time their area loads.

- **Riding:** every mount has its own camera, first and third person: you
  look out from the rider's seat with the mount's neck and head low in
  the view. The stag, the wolf, the bats and the rowboat are larger, the
  sailboat a little smaller; you sit on the backs of the stag and the
  tiger, an eagle is centred under you, and a ridden ibex or bat no
  longer bobs its head or body. While you ride, the quickbar (`E`) has a
  Dismount button under the mounts, on a boat too. After you buy your
  first riding mount, a note says "Press E to summon your mount". Flying
  mounts beat their wings only in the air, hovering included; on the
  ground they rest still and silent. A boat comes only at the water's
  surface; deeper down you are asked to swim up.
- **Combat:** Charge runs down (and up) stairs and gentle slopes all the
  way to its target instead of stopping at the first step, without the
  camera dipping on a landing. Self and support skills (Ice Nova, Blink,
  Glacial Ward, Hold Ground, Sidestep, Sprint, Heal, Shield, Mend) cast
  on every normal click, also when the crosshair moves during the click;
  holding the button still digs. Self skills also cast when you point at
  an ally, an NPC, a trader, a tamed creature or a player you may not
  fight, and a Heal, Shield or Mend tapped at the ground goes to the ally
  under the crosshair when you let go. Food now tells a quick
  right-click (plant, open) from a hold (eat) reliably too; the eating
  ring appears a moment later.
- **Crafting:** an ingredient that several items can fill names them
  ("Carrot or Cassava") or its kind ("Any wool"), and its icon shows the
  one you carry most of. The amount has − and + beside it (− on an amount
  above the maximum jumps to the maximum); × beside the search clears it
  and shows the whole list at once. The Map tab is now called Map &
  Quests and comes before Help: the tabs end Party & PvP · Map & Quests
  · Help.
- **Quests and towns:** a quest giver opens on the first quest you can
  hand in, else the first you can take, and moves on to the next after
  Complete or Accept. Town NPCs wait for their floor instead of sinking
  into it. Trainers greet you with a line of their own and have all their
  buttons in one row at the bottom; the mender's window is called
  Grudge-Free Repairs and greets you too.
- **Map and windows:** zooming the map keeps you in the middle until you
  scroll it yourself; from then on it keeps the place you scrolled to,
  and back at 1x it follows you again. The inventory key (`I`) now also
  closes Talents & Skills, Party & PvP, Crafting, Help, the map, quest
  givers, trainers, the Crownbinder, the character creation, the Claim
  Stone, the withdraw dialog and a written book (not while you type in a
  field). Space and
  Enter no longer send you home from the Character tab or sort your
  bags on the Inventory tab.
- **Music:** in a capital, a small "Now playing" box under the minimap
  shows the title and artist of the track that is playing.

## 0.45.0 — Round 45, "Crafting rework" (2026-10-09)

Crafting without the grid and the recipe books, gear only from the
professions, and the fixes from the playtest. **Migration** needed: the
server's host runs the migration tool once on the stopped world (last
point below). No map reset, no new world.

- **Recipe lists instead of the grid and the books:** the Crafting tab
  has an area for Basic, Cooking, your two primary professions and
  Alchemy, each with its tier progress. A list of ten recipes a page with
  a search and "Craftable only"; ×N shows how many you can make. Pick a
  recipe to see the item with its description (crafted gear exactly as it
  will come out), what it needs against what you carry, the most you can
  make and an amount field with Max. Basic lists every recipe; a
  profession area lists its recipes up to your tier. The 3×3 grid, the
  recipe books and the discovery are gone.
- **Crafting takes time:** Craft now starts a job: 1 s per Basic item,
  dish or material, 2 s per potion, 3 s per piece of gear or bag. A bar
  shows its progress (reopening the window shows it from its last update
  until your next click). One job at a time; it goes on while the window
  is closed or you are offline, and a line tells you "… is ready". The
  results wait in a four-slot output area on the tab; Take all moves them
  into your inventory. Stop gives everything back when there is room.
  Ingredients come from your bags first and the hotbar last.
- **Professions make all gear:** weapons, armour, shields, spellbooks,
  bags and jewellery come from their profession at the tier of the item;
  Basic makes tools, blocks, arrows and the like. Spellbooks and bags no
  longer need a character level beyond the profession tier.
- **Profession stations work nearby:** a profession recipe needs its
  station within 4 blocks (the forge for weapon- and armorsmiths, the
  four benches, the brewing stand); stations open no window any more.
  Furnaces and dual furnaces still do. Five stations got a new look: the
  tanning rack, the tailor bench, the carving bench, the jeweller's bench
  and the brewing stand. The forge and the brewing stand play their sound
  when someone starts a job there; the forge no longer hammers with nobody
  at work.
- **A new item level ladder:** new gear starts at item level 1, 11, 21,
  31, 41 or 51 by tier, and its level requirement is its item level
  (tier-1 gear has none). New tier-1 gear is a little weaker than before
  (a bronze sword deals 4 instead of 5). Every piece of jewellery has its
  own icon per tier.
- **Enchants and upgrades are jobs:** in a primary profession's area,
  "Enchant an item" and "Upgrade an item" take the item into a target
  slot. Enchanting lists the enchants that fit it up to your tier with
  their values, shows the result before you start and takes 5 s.
  Upgrading adds item levels one at a time (1 s and one material of the
  item's own kind each, plus a stick for weapons) up to ten times the
  item's tier, with a warning when the result needs a higher level than
  yours; upgrades give no profession XP. Cancel gives the item back, and
  an item left in the slot returns to your inventory at login. Three
  signatures (Campaign Purse, Scarred and Blighted Bear Claw) have no use
  left.
- **Cooking from the start:** every character knows Cooking; there are no
  Cooking trainers. Simple dishes are made directly, good dishes as a raw
  dish finished in a furnace.
- **Finished potions:** Alchemy makes potions and elixirs directly at the
  brewing stand; mixtures and the stand's automatic brewing are gone (an
  old mixture says "No longer used").
- **Grudge-Free Repairs:** in every start town and capital, where the
  Cooking trainer stood, an NPC repairs your gear and does nothing else.
  Inside your claim only furnaces and dual furnaces repair now.
- **Inventory:** seven rows in the same window size, each area in its own
  box; your money, Withdraw, the coin slot and Sort in one row above the
  hotbar; the hotbar stays in place on every tab. The Character tab has
  three views: Stats (your character beside the stats), Effects and
  Achievements; the professions overview moved to the Crafting tab.
  Shift-click from a chest, a furnace, the creative inventory or the
  crafting slots fills your inventory, then your bags, then the hotbar,
  also when the rows above the hotbar are full; the creative inventory no
  longer deletes a shift-clicked stack.
- **Mounts:** you see your mount (and your boat) in first person. The
  riding sound stops in the air, when you stand still and when you get
  off. A rider of a ground mount takes fall damage as on foot and is
  thrown off. Water and lava end a ride, and no mount comes in water,
  from a boat or in lava; a ground mount only comes when you stand on
  solid ground.
- **Creatures:** birds and other fliers beat their wings while in the
  air, crabs climb one-block steps, and at dawn night creatures stay while
  a player is within 64 blocks.
- **Your Claim Stone is a waypoint:** once activated, "Your Claim Stone"
  is the last entry of every waystone's list, free like any waystone, and
  the stone's new Waypoints tab takes you to your waystones; the map shows
  the stone.
- **This release has a migration step** (for the server's host): stop the
  server, back the world up, run
  `python3 tools/migrate.py --world <world directory>` from the new
  version's checkout, then start it
  ([updating a hosted world](README.md#play-with-luanti)). The step
  removes alchemy mixtures, empties the old crafting grid into the
  inventory (what does not fit comes at the next login: into the
  inventory, else the output area, else at the character's feet), and
  keeps every unchanged piece of gear at its old item level and
  requirement; old tier-1 weapons keep their damage, and tooltips are
  refreshed when the character next joins.
  From 0.41.0 or 0.43.0 the same run also applies the 0.44.0 step. No map
  reset.

## 0.44.0 — Round 44, "Inventory, map and quickbar" (2026-10-09)

A new inventory window, a map window with the quest log on Z and a
quickbar on E. **Migration** needed: the server's host runs the migration
tool once on the stopped world (last point below). No map reset, no new
world.

- **One window with fixed tabs:** Inventory, Character, Talents & Skills,
  Crafting, Party & PvP, Help and Map. Inventory is the first page; the
  tab you last used stays selected when you reopen it. The Bags, Skills, Quests and PvP tabs are
  gone; what they held moved as below.
- **One inventory:** the Inventory tab shows four bag slots, the potion
  belt, the coin deposit and a Sort button above one scrolling grid of
  everything you carry, every bag included, with the hotbar below. A bag
  can go inside another bag. Swapping a bag for a larger one keeps its
  contents; taking a full bag out or swapping it for a smaller one moves
  the contents into free slots, or is refused when there is no room. Sort
  puts weapons, trinkets, armour, then arrows, food and potions, then the
  rest in order and merges stacks; it never touches the hotbar.
- **New items fill your bags before the hotbar:** pickups, loot, quest
  rewards, dug blocks and purchases go into the rows above the hotbar and
  the bags first, so a slot you keep free for a skill stays free; a stack
  already on the hotbar still grows. A Scout shoots arrows from any bag.
- **The potion belt** holds four potions or elixirs to drink from the
  quickbar.
- **The Character tab** has a box with five views: your character in 3D
  with the cloak picker (the default), Stats with your money and Withdraw,
  Effects, Achievements and Professions. Beside it every equipment slot is
  named for your class, a Scout's quiver sits with them, and Return home is
  there in every view. Shift-click puts gear into its slot (or swaps it)
  and back into your bags, and arrows into the quiver and out.
- **Talents & Skills:** both talent trees side by side with their chain
  names and lines between the talents; click a talent to learn a rank or to
  see why it is locked. Your skills sit in one row below. Skills now live
  only on the hotbar: drag one onto it, drag it back onto its icon to put
  it away. A skill a new talent unlocks goes onto a free hotbar slot, or
  waits in the row when the hotbar is full.
- **Party & PvP** is one tab: the party above, the PvP flag button and your
  PvP record below. Help and the welcome window name the new tabs and
  keys, with notes for players who changed the Aux1 key.
- **The map window** opens with `Z` or the Map tab and fills most of the
  screen, with your quest log beside the map: Quest HUD, Track on HUD and
  Abandon. Pick a quest to see its targets: a red crosshair on a leader or
  a place, rings on the nearest areas where its creatures live, also in
  the other faction's land. The map shows you and your party, your home,
  waystones, your faction's trainers with their profession icons and
  services, and a `?` where you hand in the quests you have; the minimap
  keeps `!` and `?`. The minimap switch moved here. The map no longer
  refreshes every two seconds, only when something changes. `Z` no longer
  zooms the view.
- **A pixel-art map:** settlements, fortresses, camps, mines, dens, kings
  and dragons are drawn into the map as small pixel icons, the other
  faction's places included, and region names in a pixel font; the
  minimap shows small versions of the icons. The zone markers are gone.
  The map's download at normal quality grows by about 0.9 MB.
- **The quickbar on `E`:** your mounts and boats (a button for every tier
  you own; click the one you ride to get off), the potion belt (click to
  drink, with the shared cooldown) and Return home. A click acts and
  closes it. Mounts are no longer items: the riding trainer and the
  Shipwright tell you "Press E to open your mounts."
- **This release has a migration step** (for the server's host): stop the
  server, back the world up, run
  `python3 tools/migrate.py --world <world directory>` from the new
  version's checkout, then start it
  ([updating a hosted world](README.md#play-with-luanti)). The step removes
  the old mount items and every skill outside the hotbar from all
  characters, offline ones included; owned mounts stay and are in the
  quickbar, and a removed skill can be dragged from Talents & Skills again.
  A 0.43 world started without the tool is refused with a message naming
  the command. No map reset: the map image is drawn anew once at the first
  start.

## 0.43.1 — Round 43 hotfix, "Villager routes" (2026-10-09)

Existing worlds play on: no map reset, no new world.

- Villagers no longer crash the server on certain routes: a walk that
  starts and ends on the same standing place (two plots of Nhal Veyr have
  two such places on one spot) is now simply walked.

## 0.43.0 — Round 43, "World migrations" (2026-10-08)

Groundwork so that later versions can change how characters are saved
without asking for a new world. Nothing changes in play. Existing worlds
play on: no map reset, no new world.

- An update can now need a fourth thing besides "plays on", "map reset"
  and "new server": a **migration**. Then the server's host stops the
  server, backs the world up and runs a tool that ships with the game; it
  brings the world, offline characters included, to the new version, and
  the game finishes the rest when the world starts and when each character
  next joins. No version needs it yet.
- Hosts get that tool, `tools/migrate.py`, for worlds on SQLite or
  PostgreSQL; `--check` shows a world's version and what is due without
  changing anything ([hosting a server](README.md#play-with-luanti)).
- A server refuses to start a world saved by a newer version of the game,
  or one that needs the tool first, with a message that says which
  version to use or which command to run. Each world now remembers the
  version that last started it.

## 0.42.0 — Round 42, "Mob navigation" (2026-10-08)

Creatures, guards and townsfolk find their way instead of getting stuck.
Existing worlds play on: no map reset, no new world.

- Creatures in a fight come round a tree, a row of trees, a pillar or a
  wall corner and find the doorway in a wall. Large ones such as bears get
  round a single tree, a pillar or a corner and give up where only a
  narrow way leads on. A fleeing player is no longer chased along an old detour.
- A creature that cannot reach you, for example behind a fence, gives up
  after a few seconds even when it can see you, heals and goes back. It
  leaves you alone until you have moved about eight blocks or 15 seconds
  have passed, so it no longer comes back and heals again every few
  seconds.
- Tall creatures (elites, royal guards and the like) fit through doorways
  two blocks high.
- Guards walk back to their posts and along their patrols round trees and
  walls, and kings and Generals back to their seat. Royal guards and
  bodyguards follow their leader round obstacles and run after him in a
  fight to keep up. A creature pulled to the edge of its area walks home
  round what stands in its way.
- Villagers and patrols in start towns, villages and capitals walk their
  rounds without walking into trunks or walls; capital patrols follow the
  streets, and no villager stands frozen on one spot any more.
- Villagers, town patrols and guards on their rounds open a door, walk
  through and close it behind them. They never open a locked door and
  walk round fence gates.
- Creatures on their way somewhere no longer stop at random, and a wall
  torch or a sign no longer stops them; wild creatures still pause now
  and then while they wander.

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
  ungenerated ground: most likely water flowing in a cave nearby had left
  a hidden blocker the world generator refused, and the generator now
  accepts it. If generating a piece of land ever fails again, the server
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
