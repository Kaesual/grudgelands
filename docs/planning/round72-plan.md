# Round 72 — fights, placement, travel and two Expeditions

**Planned, not started.** Collected from several planning sessions on 2026-11-07 and
planned with the user on 2026-11-08, after their acceptance of Rounds 70 and 71. The
round starts on the user's "go", after a compaction of the coordinator's context.
Routing (user, 2026-11-08): one coordinator (Opus 5.5) for every lane; Opus 5.5
implements and reviews; GPT-6 Astra shapes and dresses the three Expedition templates
(lane STYLE). Version **0.72.0**, classification decided at the merge (expected
compatible: no map reset is planned).

## How to add to this document

- Add a topic as its own `### 2.N` (rulings), its findings to §3, its lane goal
  to §4 and its open questions to §5. Add a row to the lane table in §1.
- Change only your own topic. A conflict with another topic goes to §5.
- Mark what is what: a **ruling** is the user's, with its date. A **proposal** or
  **finding** is not a ruling until the user says so.
- Name functions rather than line numbers: Rounds 70 and 71 still move the code.

## Why

Players reported on 2026-11-07 that a Mage kills a King alone from a safe spot,
that the same works at a level 40 outpost, and that guards get built into blocks.
Round 71 built the Expedition framework and one Expedition; two more were designed
for this round, and the user's test of the first asked for smaller, shaped rooms and an
easier way back in.

## 1. Lanes and order

Start state: main `5a8909a0` (0.71.0, Rounds 70 and 71 accepted by the user on
2026-11-08). Integration branch `round72`; lanes branch from it.

| Wave | Lane | Goal | Waits for |
|---|---|---|---|
| 1 | FIGHT | Combat starts at targeting (§2.1) | start |
| 1 | RANGED | Ranged kings navigate and shoot, sight is sought (§2.4) | start |
| 1 | BLADECRAFT | The hand shows the weapon of the last real attack (§2.6) | start |
| 1 | MOUNTS | No mounts or boats in enemy towns (§2.7) | start |
| 1 | TAGS | Friend and foe nametags (§2.8) | start |
| 1 | TRAPS | The two Expedition trap types, one shared module (§2.9) | start |
| 1 | EXPMOBS | One Expedition-mob flag: no truce, no shrinking aggro radius (§2.9) | start |
| 1 | WAYTAB | The Expeditions tab on waystones, normal waystones inside, the Registrar's letter (§2.10) | start |
| 2 | PLACE | Placement rules (§2.2) | FIGHT |
| 2 | BOSSRESET | Target-lost reset of kings and bosses, boss floor, 15 s rule (§2.3) | RANGED |
| 3 | GUARDNAV | Probe, then the reset of §2.5 (§3.3) | BOSSRESET |
| 3 | SHIFT | The Second Shift, levels 40–69 (§2.9) | TRAPS, EXPMOBS, BOSSRESET |
| 3 | MINT | The Last Mint, levels 60–69, the lava lake (§2.9) | TRAPS, EXPMOBS, WAYTAB, BOSSRESET |
| 4 | STYLE | GPT-6 Astra shapes and dresses all three templates (§2.9) | SHIFT, MINT |
| 4 | PROOF | The template proofs and balance models after STYLE (§2.9) | STYLE |
| — | D | Docs, completion, GUI checklist | every merge |

The full fixture run happens **once, at the round's end**, by the coordinator; lanes and
waves run only the fixtures that are strictly needed (§7).

## 2. The user's rulings

Everything in §2.1–§2.4 is ruled by the user on 2026-11-07 unless marked.

### 2.1 Combat starts at targeting

A player is in combat as soon as a guard, mob or boss attacks them or has them as
its target, not only from the first threat or hit. This includes kings.

### 2.2 Placement

- **In combat nothing that restricts movement may be placed.** Ladders and
  liquids count (user, same day). Torches stay allowed because they do not block.
- **Nobody may place a blocking node into a cell where a mob, guard, boss or
  player stands,** in or out of combat.
- **Falling nodes are tested where they land, not where they are placed** (user,
  2026-11-07): wrap `try_place` of `__builtin:falling_node`; a landing cell that
  overlaps a live body returns false, and builtin drops the node as an item. One area
  query per landing, no depth to choose, and it also catches sand whose support was dug.
- Ladders the world already has stay: outposts have them built in. Climbing one to
  get away counts as the player's escape and must not be exploitable (§2.5).
- **Cages are accepted** (user, 2026-11-08): a bystander nobody targets can still wall
  a guard in; the guard gives up and heals.
- **Digging stays allowed in combat** (user, 2026-11-08).

### 2.3 Kings and bosses

This replaces the King give-up ruling of 2026-10-03
([Round 30](round30-plan.md)): kings no longer only drop an unreachable target.

- Kings and bosses always search a way to their target.
- A king resets when he finds no way to his target or when his current target leaves
  the leash range. Both triggers run the same one-way window:
  - The target's threat goes to zero at once, and walking back saves nothing.
  - With no other player engaged, the reset comes at once.
  - Otherwise only a Taunt by another player within 3 s (`TAUNT_FORCE_TIME`) keeps the
    fight.
  - A logout or teleport counts as leaving; a death does not.
  - Two Warriors swapping this way is accepted as a tank swap.
  - Zero threat alone is not enough: the king would turn to the next player, and two
    players could take turns running out to recover.
  - The window must not be `grug_evading`: `grug_core.taunt` refuses an evader and
    every punch on it is cancelled.
- A boss who has made no attack for 15 s resets: kings, Generals, the rift boss and
  Expedition bosses. Not elites and not normal mobs: kiting is part of the game
  there. Dragons keep their arena edge.
- **The boss floor (the user's idea, proposal shaped with them):** kings, Generals
  and Expedition bosses get a reachable floor, computed once at initialisation. It
  decides §2.3's "no way" and "left the range". Dragons do not need it: players
  cannot leave their radius alive.

### 2.4 Ranged mobs

Every ranged mob, guard and boss without sight of its target tries to get sight.

### 2.5 Guards and captains out of reach

A player may hit a guard who cannot reach them again and again. The guard must then
notice it cannot reach them, reset and refill its health at once. It is immune while
it resets: a fleeing guard's flight ends only when it is back at full health, and it
takes no damage until then. This replaces the damage block proposed earlier. A ladder
stays a real escape: the guard goes home healed.

This covers guards, captains, the rift boss, rares, camp leaders and elite camp mobs,
switched on per definition. Kings, Generals and Expedition bosses do not need it, the
boss floor decides for them. Wildlife stays out for cost.

No further facts from the reporter are needed (user, 2026-11-08): this round's
mechanisms are expected to solve most of it, and GUARDNAV's own probe stands in.

### 2.6 What Bladecraft shows in the hand

Ruled by the user on 2026-11-07:

- Bladecraft shows the weapon of the last real attack: the bow after a shot, the
  blade after a swing. Today it always shows the blade.
- Only real attacks switch: a shot that flew and a swing at a foe. A left click at
  the air, digging and a refused shot switch nothing.
- Only Bladecraft switches: that is the skill's perk. Every other skill keeps showing
  its main weapon, also while the held fallback swings Strike: Loose and True Draw
  swing the bow they show.
- The shown weapon lasts until the next real attack, with no timeout and across
  hotbar switches. After a relog Bladecraft shows the blade.
- Bladecraft's swing does not get stronger: it stays equal to Strike at the specified
  1.00 M. The perk is both attacks on one slot, the visible switch and the way into
  Veil.

### 2.7 No mounts in enemy towns

Ruled by the user on 2026-11-07:

- No mount of any kind in an enemy start town or capital: no riding and no boats.
  Today a player rides past the guards to the King on a fast mount.
- A mount cannot be summoned there, and a rider who crosses into one is dismounted
  with a message. There is no warning band.
- This replaces "Riding and boats work everywhere" (`pvp.md`) and the land tiers'
  permission on enemy land (`mounts.md` §4.3) for these towns only. The land round
  them stays open to riding; the flight ban is unchanged.

### 2.8 Friend and foe nametags

Ruled by the user on 2026-11-07:

- Every faction unit (players, guards, NPCs) has a green nametag for friends and a
  red one for foes. Each viewer sees only the one for their side. Today guards and
  NPCs are violet or lavender for everyone.
- Non-combat NPCs are lighter: light green for friends, light red for foes, so a
  player sees that they will not attack.
- A character without a faction sees green. Such characters exist only at the start
  position.
- Mobs without a faction keep their colours (aggressive red, neutral yellow).
- **The foe tag is made only when needed** (the user agreed to the proposal): a
  side's tag object exists only while a viewer of that side is within tag range.

### 2.9 Expeditions: The Second Shift, The Last Mint, traps, room character

Ruled by the user on 2026-11-07 and 2026-11-08 (Round 71's
[concept §9](round71-expeditions-concept.md#9-after-the-build-three-expeditions-user-2026-11-07)):

- **Three Expeditions:** The Stilled Seam (20–69, 3 players, shipped in 0.71.0), **The Second
  Shift (40–69, 4 players)** and **The Last Mint (60–69, 4 players)**. Tier, ore, gem and reward
  follow the level every ten levels (T4 40–49, T5 50–59, T6 60–69; T6 ore Abyssal Crystal, gem
  Diamond). Expeditions support mining and never replace it.
- **The approved build plans:** [The Second Shift](round72-second-shift.md) and
  [The Last Mint](round72-last-mint.md), with floor plans, encounters, traps, bosses, loot and
  the quest texts the user picked. They are the source for SHIFT and MINT.
- **Two trap types only**, never noticing or hurting mobs, spots random per creation:
  1. **Floor trap:** invisible trigger, a muted red particle ring for 1.5 s (like the Mage's
     Meteor warning, distinct from player effects), then strong damage inside it; rearms 10 s
     after firing; visible for the rest of the run after its first firing.
  2. **Wall projectile:** fires on a fixed period, always; a clearly visible fireball with area
     damage where it hits a player.
- **The Last Mint's lake:** lava pillars in a lava lake, a fall is death, no way out. **Return
  Home is refused while a player stands in lava inside an Expedition.**
- **Undead truce:** Expedition mobs ignore it.
- **Layouts:** The Second Shift is The Stilled Seam's envelope mirrored on x, The Last Mint
  mirrored on z, both reshaped.
- **Room character (user, 2026-11-08):** Expeditions must not read as a row of rectangular
  rooms; they need shapes and fitting decoration. The Second Shift and The Last Mint follow
  their plans' "Character and decoration" sections; **The Stilled Seam is reshaped and
  dressed too** (its rooms are plain cuboids today).
- **Shape in height too (user, 2026-11-08):** walls and ceilings are irregular in y as well
  as in the floor plan: overhangs, sloped or stepped ceilings, niches above head height,
  ribs. **Floors stay flat**, in every room and at the bosses: no one-node steps and no
  dais. This replaces the plans' one-node steps and the daises of Nemm and Duewarden; a
  boss stands out by ceiling, pillars and light. The Last Mint's lava pillars stay: they
  are the mechanic, not floor decoration. **Not every room is irregular:** now and then a
  cuboid room reads as meant; only all-cuboid is dull.
- **Packs cannot be walked round (user, 2026-11-08):** in the user's test of The Stilled
  Seam some rooms were large enough to pass a pack without pulling it. Rooms get smaller.
  The checkable form (coordinator): from every walkable floor cell of a pack room, at least
  one mob of that room's pack would notice the player (within its view range and in sight).
  It holds for all three Expeditions and is proved on each template.
- **No shrinking aggro radius in Expeditions (user, 2026-11-08):** the Round 56 rule that a
  monster notices a player far above its level only within a shorter radius does not apply
  to Expedition mobs. A level 60 player in a 20–29 run is noticed at full view range.
- **The standing defaults stay** (user, 2026-11-08): the boss drops nothing on the ground,
  chest contents are lost at the end, one roll, every mob authored, bars stay, sight is a
  pull, a pack's list holds only who engaged. Leaving the party and re-entering as a free
  wipe stays noted, not closed.

### 2.10 Getting into an Expedition

Ruled by the user on 2026-11-08:

- **An Expeditions tab on every waystone outside the Expeditions and on the Claim Stone.**
  It lists the running Expeditions this player may enter (the run's owner, a player or
  members of the owning party, with the entry rules of `can_enter`) and enters one. Today
  the Expedition's waystones lead to the capital's waystone, and a way back in means a walk
  to the Registrar. This is the user's main quality-of-life point of the round.
- **Creating and starting** stay at the Expedition Registrar alone. **Entering** there stays
  too, so a party leader enters right after creating.
- **The two waystones inside an Expedition** (start and end) show the normal waystone window:
  the player picks any of their waystones as usual. The Expeditions tab is not shown on
  them.
- Coordinator defaults, unless the user says otherwise: entering from the tab is a waystone
  trip by the normal rules (refused in combat, the same ritual) and arrives at the run's
  arrival; with nothing to enter, the tab says so in one line and points to the Registrar;
  the Expedition waystones are never offered as a destination; a trip out by the normal
  window does not end the run, and the Expedition's own leaving bookkeeping runs first.
- **The Registrar's letter:** every character gets a letter from the Expedition Registrar at
  level 20, always (no condition), like the Housing Steward's. Text (user, 2026-11-08: the
  coordinator writes it):

  > **A line in the guild's ledger**
  >
  > Your name has come up at the Miners' Guild, {player}.
  >
  > The old workings under our lands were sealed for good reasons, and the guild sends small
  > parties to open them again. Come to the guild house in {capital} and ask for me; I will
  > tell you which Expeditions your party may take on. Bring companions you trust. The deep
  > pays better than the surface, but it does not forgive a lone miner.
  >
  > Expedition Registrar

## 3. Findings

From reading the code on 2026-11-07. **Nothing was reproduced in the game.**

### 3.1 Kings

- `give_up_target` (`aggro.lua`) only drops the target of a king or General.
- The leash cannot fire at a safe spot: each hit renews the 15 s contact clock
  (`run_player_hit_mob`), a king who cannot walk never leaves his 30 m drag range,
  and after a give-up `leash_check` clears clock and anchor. The only heal left
  is `idle_health` after 30 s without damage.
- The leash measures how far the mob was dragged from the chase anchor. It does
  not measure the target's distance from the seat. §2.3 needs a new measure.
- Melee kits reach 6 nodes (Shatter, Cleave). A Mage reaches 20.
- **The "ranged" kings do not shoot.** They have no `dogshoot_switch`, so
  `dogswitch` returns 0 and neither branch of `do_states` runs inside their shot
  range. They stand still. Beyond it they walk straight, without navigation. Only
  the Elf deals ranged damage, through the Volley cast every 10 s or so. The Undead
  King summons and the Troll King only heals himself. Their `arrow` field is
  unused (`combat_stats.md` "keeps upstream's branches", Round 56 plan).
- Kings are stun-immune but `grug_mobs.root` and slows have no such check, so Ice
  Nova roots them for 2.5 s. With Blink and range 20, a Mage can kite a king
  inside the radius with a walkable way. Only the 15 s rule covers that.
- **What counts as an attack for the 15 s rule:** a melee swing at a target in reach,
  a shot with sight, a signature that had a player in its area. `king_tick` casts
  Shatter and Cleave whenever he has a target, in reach or not, so a cast alone must
  not count, or a safe spot keeps the clock at zero. A dodged attack counts.
- **A king's height is no problem.** A mob taller than 2 nodes moves with a physics
  box of 1.95 (`obstacle.physics_box`, Round 42 ruling 20), and `nav.body` reads that
  live box. A king is 2.72 tall to look at and walks through a 2-high door, 0.96 wide.
  The engine's `find_path` tests one open cell above a walkable node; `nav.check_path`
  adds head room and width in Lua.

### 3.2 Placement

- Placement asks only `core.is_protected`. `core.item_place_node` in builtin does
  not look at objects.
- Enemy players can build on contested land, so around ordinary outposts and
  patrols. A war camp's box reaches 10 nodes past its blueprint (`PVP_MARGIN`), and
  its guards can be dragged 30.
- Suffocation costs 5 % of `hp_max` per second, 2.5 % for elites, nothing for kings
  and Generals (`env_damage.lua`). It tests the feet cell only.
- A guard killed that way drops no loot (`player_drop_tagger` needs a puncher), but
  `award_kill_xp` pays its participants XP, quest credit and the PvP counter on any
  cause of death.
- **Combat today:** `engage_mob` runs on a hit, a threat gain or a threat switch.
  The seam for §2.1 is the `do_attack` wrapper in `grug_mobs.register_mob`: engage
  when the call left the player as `self.attack`, because `do_attack` returns early
  for a mob already attacking.
- **Consumers of `in_combat`:** food, mana regen, rage, HUD, travel, waystones, the
  lift, mounting. All of them now begin at targeting.
- **Falling nodes** (6 registrations): `falling.lua` lands without looking at
  objects, so sand placed above a mob ends in its cell and passes the cell check.
- Doors, beds and `grug_farming/bucket.lua` place with their own `set_node`, outside
  `core.item_place_node`.
- Ladders are `walkable = false` and `climbable`: they block nobody but reach a
  safe spot.
- [classes.md](../design/classes.md) ("a click in combat still places or interacts")
  needs the new rule.

### 3.3 The level 40 outpost

Most likely a camp under construction ([pvp.md](../design/pvp.md) §6.3: Stakeguards
38–40, captain 40, on the guard chassis, 1276 and 1914 HP). These do reset on a
give-up, about 3.5 s after sticking. Two hypotheses, neither tested:

1. **The give-up never comes.** Beyond `nav.CLOSE` (16 nodes) the mob searches
   intermediate points. A Mage hits from 20. Each path's end counts as progress and
   clears the failure count, so three failures in a row may never add up.
2. **The mob dies first.** A level 60 Mage kills a level 40 guard in roughly 4 s
   without gear, by the pools alone.

Needed from the reporter: the place, the Mage's level, the distance.

The guards already have "no way, reset", so §2.3's rule alone does not fix this. The
fault lies in noticing it and in what follows:

- Neither the engine's pathfinder nor `grug_nav` knows ladders, so a ladder top is
  simply "no way", and no mob climbs.
- `find_path` lowers a hovering destination to the ground below it. A player on a
  ladder gets a found path that ends under them, which counts as progress.
- Today a hit from the given-up player starts a new chase at once, so a Mage at a
  ladder top keeps hitting between resets.

**How §2.5 works (proposal, the user's rule):** a pull runs its search at once, not after the mob got
stuck, or a guard running 20 nodes to a wall gives over 4 s of free damage. Search
the target directly up to `nav.MAX_LEG`, without intermediate points, at padding 16.
Only an attack clears the failure count, not a path's end. A found path counts only
if it ends within reach of the target. Two failures mean "no way" (about 1 s). The
reset heals at once as `leash_reset` does and always runs home (`evade_home`), so the
existing evade gives the immunity. A guard already at home is attackable again at
full health, which §2.5 allows.

### 3.4 Cost of a path search

`core.find_path` on the workstation, flat field, median of 5, in µs (Round 42
`nv0-calibration.md`):

| Distance | Found | Found diagonal | No path, padding 6 | Padding 8 | Padding 24 |
|---|---|---|---|---|---|
| 16 | 9 | 48 | 232 | 380 | 3043 |
| 24 | 15 | 103 | 332 | 543 | 3537 |
| 32 | 21 | 183 | 422 | 650 | 4200 |

- Natural ground at 24 nodes: found p50 189 µs; the largest over all distances
  680 µs (at 32).
- Padding 12 and 16 at 24 nodes on open ground were **not measured**. The largest
  failing search at padding 16 in Round 49 was 429 µs, in a natural grove.
- Limits today: 20 searches a second server-wide, 3 ms per step, 1 s lockout per
  mob, negative cache 1/2/4/8 s.
- The calibration says 16 was chosen for the padding's reach, not for cost: "24
  would also be affordable".

### 3.5 Bladecraft's hand

- **Why it always shows the blade:** Bladecraft is `melee = true`, so its `def.slot`
  is `melee`. The skin pass (`skin_source_cache`, first person) and `shown_item`
  (`apply.lua`, third person) read only that slot, and the right-click shot changes
  no visual. This is `character_visuals.md`'s general rule ("a skill shows the item
  of its slot"); no document decides Bladecraft's look.
- **Bladecraft replaces Loose, not Strike** (`transforms = "loose"`). Strike stays a
  skill of its own, and Loose is gone from the kit once Bladecraft is taken.
- **The held fallback is not Loose's alone:** `fallback` (`input.lua`) swings Strike
  for any selected skill that is refused for a reason other than the clock, so True
  Draw without arrows or a held Sidestep also swing while the hand shows the bow.
- **Damage:** Bladecraft's swing and Strike are the same number. Both go through
  `plain_swing_raw` with the `blade` tag and no proc: the Melee slot's weapon plus
  Dexterity / 10, plus Fine Edge. No talent names `damage_pct:bladecraft`. The fallback
  reads the Melee slot too (`attempt_swing`, `get_melee_weapon`), never the bow, and
  the bare hand (1 damage, 0.9 s) without a usable blade. The class specification
  sets Bladecraft's swing to an ordinary 1.00 M, so this is as designed.
- One hand entity per character stays. The back card follows by itself: `back_image`
  shows the equipped weapon the hand does not show.
- `grug_abilities_fx_veil_bow.png` ships, so the shot's bow has its Veil overlay
  without new art.
- **Engine:** a changed stack meta makes the client re-raise the first-person weapon
  over 0.125 s (`Camera::wield`). `player:set_wielded_item(stack, true)` skips that
  (protocol 52, 5.16 and later); `inv:set_stack`, which `sync_skins` uses, does not.
- The third-person poll runs once a second, too slow for this.
- Bow and blade hold different poses, so `sync_wield` re-attaches the hand entity on
  every switch.

### 3.6 Mounts in enemy towns

- Land mounts run 6.4 and 8 nodes/s, guards 4.6 (`run_velocity`), a player on foot
  about 4 (the engine's default, not measured here). On foot the guards catch up.
- Any damage already dismounts, and combat blocks a summon (`summon_position`). A
  rider outruns the guards before they land a hit.
- The flight ban has the two places this needs: the refusal in `summon_position` and
  the per-step check in the mount entity's `on_step`. A boat's rider who is dismounted
  stays in the water.
- Start towns and capitals are the hard `town` footprints
  (`grug_zones.hard_footprint_in`); villages, outposts and camps have none.
  `grug_map/location.lua` (`build_resolver`) already finds a town's footprint from
  its anchor. Which faction owns a town was not traced: the lane decides it from the
  settlement or the home zone (`territory_rule`, as `flight_rule` does).
- Sprint, Charge and Blink still help a player on foot; they cost cooldowns.

### 3.7 Nametags

- Nametag properties are the same for every viewer, so per-viewer colours need one
  object per colour. `tag_carrier.lua` already gives every tagged unit an invisible
  child entity whose managed observer set holds the viewers within 25/30 m.
- `category_for` picks one of six colours per unit for all viewers (`guard` violet
  `#b76cff`, `npc` lavender `#d8c5ff`); `combat_stats.md` "Nametag categories"
  says so, and its "nametags cannot be colored per viewer" needs the new rule.
- `category_for` names guards by entity name (guards, royal guards, captains,
  commanders, bodyguards). Kings (`grug_mobs:king_*`) are not on that list, and
  neither are the Generals as far as it reads.
- Guards and other faction mobs carry `_grug_faction`; every settlement NPC has a
  faction (`settlements.md`).
- Consumers of the carrier: `create_tag_carrier` and `set_tag_carrier_text` in
  `grug_mobs` (`init.lua`, `levels.lua`, `capital_displays.lua`) and `grug_factions`
  (players); `register_tag_visibility` in `grug_quests/npc.lua`. The injured HP bar
  reuses the carrier's observers.

### 3.8 Expeditions

- Round 71 left the backlog notes in `BACKLOG.md` (Round 71 section); for this topic: the ore
  and gem swap goes by node name in every template, so a new template places the T2 template
  nodes (Anthracite, Jade) only as ore and gem; a lava guard for the lake (`water_guard.lua`
  guards water); `tools/building_templates/nodes.json` lacks `grug_expeditions:waystone`.
- The Seam's template is proved cell by cell by `tools/r71_l20` (grid, player and mob routes,
  sight between packs, light): reshaping it changes those expectations with it.
- Expedition bosses rely on BOSSRESET's 15 s rule and boss floor (§2.3); a boss room is its
  range.
- **Aggro by level gap** is `grug_mobs.player_aggro_radius` (`aggro.lua`), read by the
  `general_attack` patch in mobs_redo's api.lua; it already skips faction mobs. The undead
  truce is `truce_active` (`grug_mobs`). Expedition pack mobs carry `_grug_pack`
  (`packs.lua`); one flag read at both places covers §2.9's two rules.
- **The "no walking round" check** needs sight and view range per floor cell; `tools/r71_l20`
  already proves sight between packs and routes cell by cell, so the check is one more proof
  there. Smaller rooms change the Seam's balance model (`tools/r71_l20/balance.py`, run
  modelled at 8.7 minutes) and its proofs.

### 3.9 Waystones and the letter

From reading the code on 2026-11-08.

- The capital waystone's window is `form` / `grug_home.use_waystone` in
  `grug_home/waypoints.lua`; it has no tabs. The Claim Stone's window (`grug_housing/stone_form.lua`)
  already has tabs, Waypoints among them, travelling through `grug_home.travel_from_claim`.
- The Expedition waystones are the node `grug_expeditions:waystone` (`init.lua`), whose
  right-click runs `grug_expeditions.use_waystone`; leaving is `grug_expeditions.leave`, and
  player meta `grug_expeditions:origin` holds where a player came from.
- `runs.lua` has `can_enter(player, run)` and the eligible rows the Registrar shows.
- The level letters are `LEVEL_LETTERS` in `grug_mail/letters.lua` (riding at 15, housing at
  20, each with a `useful` test), texts in `grug_mail/texts.lua`, sent on
  `grug_xp.register_on_level_change` and late for a character already past the level.
- The Return Home refusal in lava (MINT) also sits in `grug_home/travel.lua`; WAYTAB goes first.

## 4. Lane goals

### FIGHT

A mob's target is in combat from the moment it is targeted, through one seam, and
leaves it as before (`stop_attack`, `prune_engagement`).

### PLACE

One seam round `core.item_place_node`, with the same check in doors, beds and
buckets. In combat every `walkable` or `climbable` node and every liquid is refused
with a grey feed line; a `walkable` node is never placed into a cell overlapping the
box of a live mob or player (a body spans several cells). A falling node that
would land in such a cell drops as an item (§2.2).

### RANGED

The ranged kings become ordinary ground ranged mobs: a ranged phase, the shared
navigation, sight sought, shots from their existing arrows. Their damage needs a
balance look. Every other ground ranged mob already seeks sight through
`dogshoot_switch`; fliers fly at the target and never search.

### BOSSRESET

Kings and Generals: no way to the target, or the target out of range measured from
the seat, is one rule with one outcome: heal, threat cleared, ledger cleared,
retinue restored, an evade to the seat from any distance. Round 71's `evade_home`
does that last part. The test is the boss floor: one flood fill from the seat with
the mob's own `stands` and step rules, bounded by the leash range, computed once at
initialisation, about 10–20 ms at the worst (an estimate from 1–2 µs per cell test,
not measured) and spreadable over steps. Once a second: is the target's ground in the
set, or within reach of it? That replaces the radius test and the search for §2.3's
triggers, needs no stuck mob and has no false "no way" from a padded box. It decides
only: walking stays with `grug_nav`. Steps, a dais and floors above each other are
why it is a fill and not a 2D search. Doors count as passable; a king stuck at a shut
door falls to the 15 s rule. It needs ground that cannot change, so the rift boss and
outposts stay on the search. An Expedition boss's room is its range.

### GUARDNAV

A probe at 17–20 nodes and at a ladder top on the merged FIGHT, PLACE and BOSSRESET
confirms what is left of §3.3, then §2.5 through §3.3's proposal for every actor §2.5
names.

### BLADECRAFT

A display state only: `def.slot` stays `melee`, so damage, the swing clock and the
action clock do not change. One per-player state, read for Bladecraft alone by the
skin pass and `shown_item`, is set by a flown shot (`bladecraft_shot.cast`) and by a
due swing of Bladecraft (`register_on_swing`, `swing.def`, so a fallback of another
skill sets nothing). A switch writes the held stack through
`set_wielded_item(stack, true)`, brings the copy on the other hotbar layout in line
and calls `grug_visuals.apply` at once. `character_visuals.md` names the exception.

### MOUNTS

One rule, "is this column an enemy town for this faction", asked by the summon
refusal and the per-step dismount for every tier, boats included. A dismount at the
line gives one feed line. `pvp.md` and `mounts.md` name the new rule.

### TAGS

A tagged faction unit has up to two carriers, one per side, each with the observers
of its side within the 25/30 m rule; the central pass reads each viewer's faction
once per snapshot. A side's carrier is made when its first viewer comes in range and
removed when the last one leaves. Callers keep one handle per unit, the text reaches
both carriers, and the HP bar and `register_tag_visibility` get both sides'
observers together. Combat units (guards, captains, kings, Generals) take green and
red, non-combat NPCs light green and light red, as startup settings like today's
colours. `combat_stats.md` names the new categories.

### TRAPS

One shared module in `grug_expeditions` for both trap types: candidate spots from the
template, chosen at random per creation, floor trigger with ring, damage and rearm, the
wall projectile on its period; players only, silent, particles in the hundreds; reset with
the run. Tuning per run level. A fixture, one engine run.

### EXPMOBS

One flag marks a mob as an Expedition's (set by the encounter). `truce_active` ignores the
undead truce for it, and `player_aggro_radius` returns the full view range for it. Small;
The Stilled Seam gets both at once.

### WAYTAB

§2.10: the Expeditions tab on the capital waystones' window (which gets tabs) and on the
Claim Stone, listing and entering the runs `can_enter` allows; the two Expedition waystones
open the normal waystone window without that tab, with the Expedition's leaving
bookkeeping before the trip. The Registrar's letter as a third `LEVEL_LETTERS` row with
the text of §2.10 and no condition. Fixtures for an owner, a party member, a stranger, a
level refusal, combat, and a trip out and back in.

### SHIFT and MINT

Each builds its Expedition from its plan: template source with the floor plan's shapes,
catalogue row (level range, 4 players), packs and boss, the tier loot, names through 69
(world slots for Skeleton Raiders), the optional quest with the picked texts, and the
balance model at 4 players setting the counts. Floors flat (§2.9, no steps, no dais); rooms
sized so the "no walking round" proof holds; walls and ceilings may stay plain, STYLE shapes
them. SHIFT adds Nemm's remembered blow through the trap helper; MINT the lake, a lava guard
for it (`water_guard.lua` guards water only), the Return Home refusal in lava and the static
press. Both reuse EXPMOBS's flag. Engine runs as few as Round 71's L20.

### STYLE and PROOF

GPT-6 Astra shapes and dresses all three templates from existing nodes: walls and ceilings
irregular in y as well as in plan, floors flat, some rooms cuboid on purpose, a palette per
room (the plans' "Character and decoration" sections; the Seam's in the same voice). For
The Second Shift and The Last Mint the floor footprint, route, pack places, traps and ore
places stay as SHIFT and MINT built them. **The Stilled Seam** also gets smaller rooms and
shaped floor plans, keeping its route, packs and ore places. Then an Opus lane (PROOF)
updates `tools/r71_l20`'s proofs and the Seam's balance model, adds the "no walking round"
proof for all three, re-checks mob reach (ceiling clearance over every floor cell) and runs
one engine check per template.

### D

Docs, `combat_stats.md` (give-up, combat state), `classes.md`, GUI checklist.

## 5. Open questions

- **Expeditions:** trap damage and the share of mining are tuned in the build from the
  models; the user's next test gives the real numbers (mining share, run length, the pack's
  shove).
- **Free wipe** by leaving the party and re-entering: noted, not closed (§2.9).

## 6. Verification

Fixtures: a melee and a ranged king against a target on a ledge and out of range; a
guard at 17–20 nodes and at a ladder top; a step over the leash line and back; a
safe spot while signatures fire; placement in and out of combat, into a mob's and a
player's cell, by a sand block from above. Search counts and the largest search are reported as a comparison.

BLADECRAFT: a flown shot shows the bow and a swing at a foe the blade, in both person
views and on the back card; a refused shot, an air click and digging switch nothing;
damage and both clocks are unchanged.

MOUNTS: a summon refused in an enemy start town and capital, for a land mount and a
boat; a rider and a boat crossing the line dismounted with the message; own towns
and the land outside unchanged.

TAGS: one guard and one NPC seen by a friend, a foe and both at once; a foe's carrier
made on approach and removed when they leave; a viewer without a faction sees green.
The carrier count with and without foes nearby is reported as a comparison.

Expeditions: every trap type fires at a player and never at a mob, rearms, and stays visible;
the lake kills a fall and refuses Return Home; both new Expeditions run from registrar to
chest at their first and last level; the Seam's reshaped rooms keep the r71_l20 proofs; the
"no walking round" proof and ceiling clearance hold on all three templates; a player 40
levels above an Expedition mob is noticed at full view range, and an undead player is
attacked.

WAYTAB: the tab lists exactly the runs the player may enter, on a capital waystone and the
Claim Stone; entering from it, leaving by an inner waystone to another waystone, and coming
back by the tab; no tab inside; the letter at level 20 and late for a character above it.

### GUI checklist (desktop and web)

To be written with the lanes. BLADECRAFT needs a look at flicker when left and right
click alternate, in first and third person. TAGS needs a look at red against light red
and green against light green at 25 m. WAYTAB needs the tab on desktop and web, and the
way out and back in with a party of two. STYLE needs the user's look at every room of the
three Expeditions.

## 7. Orchestration notes

- **Start state:** main `5a8909a0`, Rounds 70 (0.70.0) and 71 (0.71.0) merged, pushed and
  accepted by the user on 2026-11-08.
- **CPU: LuaJIT runs sparingly and minimal (user, 2026-11-08).** In Rounds 70 and 71 the
  lanes spent a lot of CPU time on LuaJIT runs and everyone waited. So in this round:
  - a lane runs a fixture only when it is strictly needed: its own fixture, and a fixture
    that really tests the behaviour it changed; not after every edit, not "to be safe",
    never the whole set;
  - **no full run by lanes, reviewers or per wave: the full fixture run happens once, at the
    round's end**, by the coordinator (and once more only if a fix changes logic after it);
  - after a merge the coordinator runs only the merged lanes' fixtures and those of a
    conflict's files;
  - engine runs few, each with a clear question; reviewers never repeat runs a lane reported;
  - shared queue `r45/lua_run.sh`, at most 8 Lua processes in total, also for work outside
    this round.

  Launch prompts carry this sentence instead of the older one: "Fixtures: run only the
  fixtures that are strictly needed, your own and those that really test the behaviour you
  change, as few times as possible; no full run (the coordinator runs it once at the round's
  end); name what you ran and why."
- **Parallel work outside this round (user, 2026-11-08):** another Opus session works on
  the character creation screen on its own branch from main, merged after Round 72. It
  shares the Lua queue and syncs to the user's Luanti folder only on the user's request
  (a sync from its branch and the coordinator's next sync overwrite each other). Expected
  overlap: `grug_factions` (TAGS) and the visuals (BLADECRAFT).
- **Touch points in Round 71:** `aggro.lua` (`give_up_target`, `leash_tick`,
  `evade_home`), `init.lua` (the `do_attack` wrapper), `bosses.lua`, `protection.lua`.
  FIGHT and BOSSRESET sit on the same lines, so they start from its merge.
- **No hotfix:** nothing goes to the live 0.69.0 first (user, 2026-11-07).
