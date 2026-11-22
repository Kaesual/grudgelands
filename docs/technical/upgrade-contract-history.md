# Upgrade contract: the declared releases

The per-release case history of the [upgrade contract](upgrade-contract.md) §2 (the
declaration): why each release from 0.41.0 to 0.86.1 declared its map reset, step or
neither. Section numbers (§) refer to the upgrade contract. The rules are in the
contract; this file only records the cases.

- The first declaration (0.41.0) covers the one migration that is due: the
  user's production server moves from 0.40.0 to 0.41.0 with a map reset
  (it crosses 0.40.1, which changed world generation; Round 41's own mapgen
  fix is covered by the same reset). No history before 0.40.0 is audited.
- 0.43.0 ships the migration foundation alone, with an empty `migrate` list
  (Round 43 ruling 2); 0.44.0 declares the first real step, 0.45.0 the
  second (§5.8). The
  platform adopts a version with a real step only once its runner is in
  production (Round 44 ruling 3).
- 0.46.0 (Round 46) declares the second map reset: seed-dependent POI
  placement and the new ore, gem and coal table change world generation.
  It declares no step; the production world is not moved now but later in
  one combined update ([round 46 plan](../planning/round46-plan.md#5-rules)).
- 0.47.0 (Round 47) needs the third map reset (world generation changes
  again) and the third step, 0.47.0 (§5.8): the pick level scale moved, and
  the copies of tool capabilities that crafted and broken tools keep in
  item meta are rebuilt at each character's next join. The production
  server moves from 0.45.1 to 0.47.0 in one step, crossing both.
- 0.48.0 (Round 48) needs the fourth map reset (the mailboxes are placed
  by world generation) and the fourth step, 0.48.0 (§5.8): every bag holds
  half as much, so at each character's next join the inventory is sorted
  into the new sizes and what no longer fits is mailed.
- 0.49.0 (Round 49) needs the fifth map reset: ores, gems and cave plants
  come from the engine's own map generator and world generation got faster,
  so an existing world's map is generated anew. It declares no step: the
  new version reads every character as it is.
- 0.50.0 (Round 50) moves to schema 3 with `"map_reset_pass": "0.50.0"`:
  its tool packs the claims' containers before a map reset (§3.5). It is
  compatible and declares no step; the production world moves from 0.48.1
  to 0.50.0 across 0.49.0's map reset, and that reset packs its claims.
- 0.51.0 (Round 51) needs the sixth map reset (the larger sea, the land
  zones' surfaces and kit, the seabed and the wrecks change world
  generation) and declares no step. `map_reset_pass` stays 0.50.0, so the
  pass packs the claims' containers before the map is emptied; the
  production world moves from 0.50.x to 0.51.0 across this one reset.
- 0.53.0 (Round 53, the new classes) declares the fifth step, 0.53.0
  (§5.8): the talent engine changes (the same meta key holds the talent
  graph's ids) and three skills are retired, so the stored talents, the
  stored talent windows and the retired skill items go offline, and each
  character with a class gets one chat line at its next join. No map
  reset: the production world moves from 0.52.1 to 0.53.0 with the tool.
- 0.58.0 (Round 58, the Miner's Guild) needs the seventh map reset: the
  mining camps, the camps under construction and the extended war camps,
  the 148 lift rooms (their own generation step), the guild houses on a
  district plot in the six capitals and the town fixes (gatehouses, bough
  platforms, throne-guard posts, the terrace stair, the start towns'
  waystones) change what world generation and the towns build. It
  declares no step: the guild's new player meta (reputation, the mining
  effect) holds no position and starts empty. `map_reset_pass` stays
  0.50.0, so the pass packs the claims' containers; the production world
  moves to 0.58.0 across this one reset.
- 0.59.0 (Round 59, the quest rework of levels 11–20 and chapter 1 of the
  story) needs the eighth map reset: new `quest_place` sockets in a service
  plot of each of the six capitals and in four of the band's bandit camps,
  and new quest places in the Starbough Vale and Mournfen spawn files,
  change what world generation and the towns build. It declares no step:
  the reworked quests have new ids (an active quest whose id vanished is
  dropped, §4), and nothing new holds a position. `map_reset_pass` stays
  0.50.0. Unpushed 0.58.0's entry already covers these changes against
  pushed 0.57.0; the production world moves from 0.57.0 to 0.59.0 across
  one reset.
- 0.60.0 (Round 60, the quest rework of levels 21–30, the six capitals and
  chapter 2 of the story) needs the ninth map reset: the Alchemy herbs
  (Sunleaf, Gravemoss, Dragonweed, Crimson Lotus) and two cooking crops
  (Pumpkin, Frost Melon) grow by level band in new zones and on new hosts;
  new `quest_place` sockets in two of the band's R20 POIs (Rimebell Watch,
  Market Close), in every mining camp (`held_load`) and on Nhal Veyr's
  guild plot (`miners_guild_public_register`); seven new quest places in
  the band's spawn files and changed `quest_target` flags in the band's
  and four capitals' spawn files change what world generation and the
  towns build. It declares no step: the reworked quests have new ids
  (an active quest whose id vanished is dropped, §4), the soulbound group
  on quest items needs no stored change, and nothing new holds a
  position. `map_reset_pass` stays 0.50.0. Unpushed 0.58.0's entry already
  covers these changes against pushed 0.57.0; the production world moves
  from 0.57.0 to 0.60.0 across one reset.
- 0.60.1 (the UI modernization) is compatible: presentation only, no saved
  state, no map reset, no step.
- 0.61.0 (Round 61, the quest rework of levels 31–40 and chapter 3 of the
  story) needs the tenth map reset: six new quest places in the band's
  spawn files (the Stormvault Survey Stand, the Ashenward Broken Load, the
  Glassroot Carrier Path, the Blackwind Recovery Rest, the Bannerbreak
  Scattered Load, the Thunderroot Storm Store), four leaders removed from
  their spawn files (Bolt-Chewer, Basket-Biter, Grave-Broker Mute,
  Bottle-Keeper Zek), Provisioner Rattle's level 37 → 35, and changed
  `quest_target` flags in the band's spawn files change the spawn recipes
  and the region maps world generation builds from them. It declares no
  step: the reworked quests have new ids (an active quest whose id
  vanished is dropped, §4), the Runner's Packet is a new soulbound quest
  item, the foremen's titles are text, and nothing new holds a position.
  One kept id changed its objectives (the plan's cross-lane slot): an
  active `bannerbreak_ramp_03` saved before 0.61.0 keeps its
  per-objective progress, so a character who had counted the old Sappers
  and Slingers may find it ready without Rattle's kill; accepted for the
  one production world (Round 61 completion). `map_reset_pass` stays
  0.50.0. Unpushed 0.58.0's entry already covers these changes against
  pushed 0.57.0; the production world moves from 0.57.0 to 0.61.0 across
  one reset.
- 0.61.1 (the refreshed service dialogs) is compatible: presentation only,
  no saved state, no map reset, no step.
- 0.62.0 (Round 62, the quest rework of the front 41–60 and the main
  line's story layer) needs the eleventh map reset: eight new quest places
  in the four Battlegrounds spawn files (the Causeway Return Stand and
  Crossing Stand, the Shattered Relief Rest, the Gravesalt Shoring Check,
  Work Laydown and Recovery Post, the Skyglass Carrier Clearing and
  Receiving Stand) and changed `quest_target` flags (eleven kinds of the
  Broken Causeway, the Shattered Line and Gravesalt Escarpment lose theirs,
  the Stormscale Scorchlands gain one) change the spawn recipes and the
  region maps world generation builds from them, and two template fixes
  change what the capitals build (Kezamba's moot-house door gets its upper
  cell, the Lethariel mere shrines' inside point stands on the floor). It
  declares no step: 45 quest ids went (an active quest whose id vanished
  is dropped, §4), the kept ids keep their objectives (`nv_front_01`
  changes only its minimum level and its reward), the bags' new sizes 8 / 12 / 16 /
  20 need none (each join grows an equipped bag's content list, its items
  kept in their cells), and nothing new holds a position.
  `map_reset_pass` stays 0.50.0. Unpushed 0.58.0's entry already covers
  these changes against pushed 0.57.0; the production world moves from
  0.57.0 to 0.62.0 across one reset.
- 0.63.0 (Round 63, fortified mining outposts and faction banners) needs
  the twelfth map reset: all 36 completed mining camps use new templates
  and relocated lift columns, and their underground rooms follow the lift.
  It declares no step; `map_reset_pass` stays 0.50.0.
- 0.67.0 (Round 67, the playtest's notes) declares the sixth step, 0.67.0
  (§5.8): the metal rods are removed items, so every rod a world holds
  outside the map is refunded as bars offline. No map reset.
- 0.69.0 (Round 69, the camps under construction get a new design) declares
  the seventh step, 0.69.0 (§5.8), and no map reset: the step only leaves a
  world marker and the game rewrites each camp's protected box online
  (§5.9).
- 0.70.0 (Round 70, the spawns, Stonewright, castles and start towns) needs
  the thirteenth map reset: the gathering catalogue and the world content
  rules change what world generation places (Rock Salt, Stormkelp, Wild
  Cocoa, Frost Melon, Bamboo Shoot, Sugar Cane) and their digests move with
  them. It declares no step and adds no map-bound state: a source node holds
  no record, and wild renewal keeps none. The later lanes join the same
  reset: the Stonewright's desk and machines in the six guild houses, the
  six start towns with their waystones, wayposts at road junctions (the
  only new generated state: a stack's `text` in node meta, written by main
  at generation), and the six capitals with civic radius 56 (rivers keep
  farther off, so they change worldwide), the castle and the moved lakes of
  Lethariel and Kezamba. Item, node and socket ids stay. `map_reset_pass`
  stays 0.50.0. The production world moves from 0.65.0 to 0.70.0 across one
  reset and runs the steps 0.67.0 and 0.69.0.
- 0.71.0 to 0.73.0, 0.74.0, 0.75.4, 0.76.0 to 0.76.2, 0.78.0 to 0.83.0, 0.84.0
  and 0.84.1 are compatible: no map reset, no step. The stores they add are not
  map-bound and stay at a map reset: the clans (0.76.0) and the website
  accounts (0.79.0), §3.2. 0.82.0 (Round 82, faster world generation with
  byte-identical output) changes 16 files of the preparation digest, so a
  world in full preparation mode stops at its next start (its CHANGELOG
  names `grug_prepare_full_world`; §5.9), and the world-folder layout cache
  moves to format 3 and rebuilds once with the same content.
- 0.73.1 (Round 73.1, character creation and capital polish) needs the
  fourteenth map reset: the capitals' halls, gates and furniture, the start
  towns' tables and the Expedition Registrar's place change what world
  generation builds. No step.
- 0.75.0, 0.75.1, 0.75.2, 0.75.3 and 0.75.5 (Round 75 and its follow-ups,
  the homes' and cities' details) need the fifteenth to nineteenth map
  resets, each joining the one before: city furnishings in the buildings
  (0.75.0, more in 0.75.2), tidier workshops and windows (0.75.1), the
  Registrar outside the great hall's door (0.75.3) and the towns' new
  structural frames (0.75.5) change what world generation builds. Item and
  node ids stay; no step. `map_reset_pass` stays 0.50.0.
- 0.85.0 (Round 85, the arena and grid claims) needs the twentieth map
  reset: the arena joins world generation and a claim becomes one map chunk
  (record v3). Nothing converts a v2 claim: the pass packs its containers
  from its 101 × 101 square and the reset clears it. No step;
  `map_reset_pass` stays 0.50.0.
- 0.86.0 (Round 86, the account Claim Stone, home names, the claim
  preview, the Account page, road cuts) needs the twenty-first map reset:
  a road's cut into a hill now fades to the ground at the side zone's edge,
  which changes generated terrain beside roads. The housing and account
  changes alone would be compatible: the claim record stays v3 (its `kind`
  and `name` now in use), a member of an account claim is a new state of
  the player record (`v2|member|<owner text>`, kept at a map reset), an
  account claim's belongings take keys of their own
  (`recovered:account:…`, `packed:account:…`) and the stored website list
  gains `default_rewards`. The pre-reset pass also packs an account claim's
  containers for its account and faction. No step; `map_reset_pass` stays
  0.50.0. The production world moves from 0.83.0 to 0.86.0 across one
  reset, which covers 0.85.0's.
- 0.86.1 (Round 86.1, the Account page's step 2 names the website's labels)
  is compatible: a text change, no saved state, no world generation; no
  step. The production world takes it in the same move from 0.83.0, across
  0.86.0's reset.
