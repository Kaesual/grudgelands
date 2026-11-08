# Round 72 — fights, placement, travel and two Expeditions

Collected from several planning sessions on 2026-11-07 and planned with the user on
2026-11-08, after their acceptance of Rounds 70 and 71. **Started** on the user's go,
2026-11-08, on branch `round72`. **Complete** on `round72` on 2026-11-08 as 0.72.0
(compatible): not yet on main, not pushed; the [GUI checklist](#gui-checklist-desktop-and-web)
is open ([completion](#completion-2026-11-08)).
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
  > Your name has come up at the Miner's Guild, {player}.
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

Written by lane D from the plan's list, the lanes' excerpts and the reviewers' notes. Each
item on the desktop client and on the web client. *Look* asks for the user's verdict on a
default; **Question** names one of the user's two open questions.

**Only the user can prove these.** No lane ran the web client, a second real player or a
real fight. So:

- **Web:** the whole list. The lanes' clients were desktop builds on Xvfb.
- **[2+]** needs two or more real players; parties, foes and friends ran on stand-ins and
  in fixtures.
- **[fight]** needs a real fight: the probes teleport and kill by script, and every run
  length and boss fight is a model.

**Combat starts at targeting (FIGHT)**

1. Let a wolf or bandit spot you without hitting it: you are in combat as it charges, and a
   mount summon, eating, Return Home and a waystone are refused. Kill it, or run past 45 m:
   out of combat at once.
2. Stand on a ledge in a King's sight: in combat while he targets you, out after his reset.
3. As an Undead character near zombies outside an Expedition: no combat unless you provoke
   one. Near your own faction's guards: never.
4. *Look:* a wild animal that chases you without your hit keeps you from mounting for up to
   about 15 s.
5. *Look:* a guard that sees an enemy it cannot reach refuses that player's Return Home in
   short spells (about 1 s every 16 s).

**Placement (PLACE)**

6. Out of combat a block, a ladder, a door, a bed and water place. Targeted by a wolf, a
   block, a ladder, a door and water are refused with the grey line "Cannot place that in
   combat."; a torch places, a chest opens, digging works.
7. A block into a guard's feet or head cell, a half-covered cell, or **[2+]** another
   player's cell is refused ("Cannot place a block where someone stands.").
8. Sand dropped on a mob, or sand whose support you dig away above a player, drops as an
   item. Town ground still shows the protection line.

**Kings and bosses (RANGED, BOSSRESET)**

9. At 15 m from the Elf, Undead and Troll King: a shot about every 3 s, and after about 10 s
   he runs at you for about 3 s. Behind a pillar he walks round it and shoots; on a ledge he
   cannot reach, in sight, he shoots. The shoot animation plays, and no arrow passes a wall.
   The other Kings and the Generals fight as before.
10. Hit a King from a pillar or a ledge: he resets within about a second, heals and walks
    home untouchable; further hits gain nothing.
11. *Look:* lead a King about 30 m from his seat, or stand outside his castle walls more than
    about 3 nodes from the gate: he resets at once, and walking back saves nothing. His
    floor is his castle (measured): does that read right?
12. **[2+]** The King's target steps out of range and the tank taunts within 3 s: the fight
    goes on. Without the taunt the King resets after 3 s.
13. **[fight]** A King kited for more than 15 s without landing an attack resets.
14. The Stilled Seam: Flintback resets when his only target steps into the passage; with a
    party, the tank leaving the room resets him after 3 s unless someone taunts.

**Guards out of reach (GUARDNAV)**

15. Hit a Stakeguard or a captain from a pillar or a ladder top: about a second later it heals
    and runs home, your hits show "Evading". Hit it again at home: it comes, resets again and
    never dies to this. Its evade ends standing at its post, not past it.
16. At a ladder top in a guard's sight you are out of combat right after its reset, and
    Return Home works.
17. On open ground, or behind a wall with a gap, the guard reaches you and does not reset.
    *Look:* four guards on one reachable player in a narrow spot or a gate do not reset.
18. A zone leader or a rare hit from a pillar resets the same way.
19. *Look* **[2+]:** two enemy players on two ladder tops near one gate guard: how often each
    is in combat while the guard turns between them.
20. *Look:* a post guard that drops off a ledge it cannot climb is untouchable for up to
    40 s, then appears at its post.

**Bladecraft's hand (BLADECRAFT)**

21. Bladecraft with a mob in reach: right click shows the bow in hand without a drop and
    raise, left click the blade. Alternate the two quickly and watch for **flicker**, in
    first person and in third person (F7). On web, a 0.25 s drop and raise at each switch
    means the web client is older than protocol 52.
22. The back card shows the other weapon at once. A right click with no target or no arrow
    keeps the blade; a left click at the air or while digging keeps the bow.
23. A hotbar slot switch and back, and a layout A/B switch, keep the bow; a relog shows the
    blade. Take the bow off while it is shown: the blade; put it back on: the bow.
24. True Draw with no arrows, left click at a mob: Strike swings, and Bladecraft keeps its
    weapon.

**No mounts in enemy towns (MOUNTS)**

25. As an Accord character, ride a horse (both land tiers) from the land outside into a
    Throng start town: dismounted at the edge with one feed line and no warning band; the
    land just outside stays rideable.
26. In that town and in a Throng capital, the quickbar's mount button and a tier switch are
    refused with the feed line. A boat on water inside is refused; a boat sailed in from
    outside is dismounted and its rider swims.
27. Your own start town and capital: nothing happens; the same for a Throng character the
    other way round. A flyer at an enemy home border sees the band and the dismount as
    before.
28. **Question:** the rule holds at every height, so a rider in a tunnel or cave below an
    enemy town is dismounted too. Default: keep.

**Friend and foe nametags (TAGS)**

29. *Look:* from 25 m, **red against light red** (an enemy guard next to an enemy vendor)
    and **green against light green** (your own guard next to your own vendor): easy to tell
    apart, also on web?
30. **[2+]** Two characters of different factions see each other's tag red; a friend of the
    same faction sees it green.
31. A new character at the start position, before picking a faction, sees guards green.
32. **[2+]** An enemy walking up to a guard sees its red tag appear at 25 m and go past
    30 m; a friend beside them keeps seeing green.
33. A wounded guard's HP bar shows to both sides; quest markers still show for their own
    faction.
34. No NPC or guard shows violet or lavender, also right after it comes into view; the
    Bedrock Sentinel is red; a capital's mount displays are light green or light red.

**The Expeditions tab and the letter (WAYTAB)**

35. Capital and start-town waystones open on Waystones, with an Expeditions tab; on web the
    tab is readable and its one line not clipped.
36. The Claim Stone's third tab is Expeditions; with Belongings (N) the four tabs fit.
37. **[2+]** A party of two: the leader creates at the Registrar, the member enters from a
    waystone's tab; both go out by an inner stone to different waystones and both come back
    in by the tab; the run goes on and the places are kept.
38. In combat the Enter click shows "Cannot travel in combat." in the window; an inner
    stone's Travel refuses too.
39. The letter "A line in the guild's ledger" at level 20, and at the next join for a
    character already past 20.

**The Expeditions (EXPMOBS, TRAPS, SHIFT, MINT, STYLE, PROOF)**

40. **The user's walk through every room of the three Expeditions** (STYLE): shapes,
    ceilings, palettes, the rooms that are cuboid on purpose. Screenshots per room at eye
    height in `r72/shots/proof/{stilled_seam,second_shift,last_mint}/`, the geometry
    previews in `r72/shots/style/` (orchestration folder). On The Second Shift step into the
    desk's rail siding (z 36): it is unhooded since `7dab5a56`, after the desk shot.
41. **[fight]** **[2+]** The run from the Registrar to the chest in **The Second Shift at
    level 40** and **The Last Mint at level 60**: length (modelled about 10 minutes each) and
    difficulty; at 69 both are meant to be hard. Nemm's 20 × and Duewarden's 14 × an elite's
    HP are tuned here.
42. In every pack room of all three, nobody gets past the pack unnoticed. The Second Shift:
    leave room 3's bypass until bay c is dead.
43. An Undead character in an Expedition is attacked by its mobs on sight (The Second
    Shift's miners); outside, zombies still leave them alone. A level 60 character in a
    20–29 Stilled Seam is pulled from the far side of a room.
44. Floor trap: the red ring reads apart from Meteor's orange, also on web; the red mark
    after its first hit is visible but quiet. **Question:** a jump over a floor trap does not
    set it off. Default: keep.
45. Wall trap: the fireball's head and tail show from about 20 nodes; it bursts on a player
    and stops at stone (The Second Shift's passage from room 1 to 2, The Last Mint's lake).
46. Nemm: a red ring at your feet about every 12 s; stepping out avoids it. *Look:* a player
    entering the passage between rooms 3 and 4 is pulled and dropped once (he sees two
    columns of it). The shift board's text is readable.
47. The Last Mint's lake: the six jumps both ways at walking speed; wait on a top, a shot
    passes, jump; a burst hits a neighbour within 2.
48. A fall into the lava: dead in about 5 s, "Cannot return home from the lava."; logout and
    login unchanged.
49. The Last Mint: each pack pulls from anywhere in its room; Wisps reachable under the
    seven-node ceilings. *Look:* the Wisps of packs b and c can follow a player over the
    lake's air.
50. The lake and the pillar tops read clearly; the press's brand is visible; the floor rings
    in rooms 2, 4 and 5.

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
- **Compaction checkpoints (user, 2026-11-08), to save tokens.** At each checkpoint the
  coordinator pauses: no new launch and no merge. It brings `r72/HANDOVER.md` up to date and
  gives the user a compaction prompt. The user compacts, then the round goes on with the next
  step. Lanes that are still running keep running; the prompt names each with its branch,
  worktree and brief.
  - **C0** before the start (this planning).
  - **C1** in wave 1, once about half of its eight lanes are merged, between two merges.
  - **C2** at the end of wave 1: all eight merged, before PLACE and BOSSRESET start.
  - **C3** at the end of wave 2, before GUARDNAV, SHIFT and MINT start.
  - **C4** at the end of wave 3, before STYLE starts.
  - **C5** after STYLE and PROOF are merged, before the round-end full run and D.
  - **C6** after the round-end full run and D, before the merge to main and the user's GUI test.

  An extra checkpoint between these only when a long fix round has filled the context.
- **Parallel work outside this round (user, 2026-11-08):** another Opus session works on
  the character creation screen on its own branch from main, merged after Round 72. It
  shares the Lua queue and syncs to the user's Luanti folder only on the user's request
  (a sync from its branch and the coordinator's next sync overwrite each other). Expected
  overlap: `grug_factions` (TAGS) and the visuals (BLADECRAFT).
- **Touch points in Round 71:** `aggro.lua` (`give_up_target`, `leash_tick`,
  `evade_home`), `init.lua` (the `do_attack` wrapper), `bosses.lua`, `protection.lua`.
  FIGHT and BOSSRESET sit on the same lines, so they start from its merge.
- **No hotfix:** nothing goes to the live 0.69.0 first (user, 2026-11-07).

## Completion (2026-11-08)

Every planned lane is merged into the integration branch `round72` at `7b37aef0`, with two
coordinator changes for the user's rulings during the round; this lane D follows on it.
**Nothing is on main and nothing is pushed:** `round72` merges to main as 0.72.0 after the
round's last checkpoint (C6) and the user's word. Every lane had an independent Opus review
(table below).

**0.72.0 is compatible:** no step, no map reset. Every lane report says compatible, and lane
D's reading agrees: nothing touches world generation, and `check_upgrade.py --base
5a8909a0` passes (the towns build as in 0.71.0; lane D). Saved state, all additive: player
meta `grug_mail:letter_registrar` (set once; a character past 20 gets the letter at the next
join); `grug_expeditions:origin` keeps its format and may now name any waystone; rares save a
plain `_grug_reach_reset`; the entity `grug_mobs:auditor_nemm` and `grug_mobs:duewarden`,
the quests `capital_second_shift` and `capital_last_mint`, and five name slots are new ids.
Runs, traps, boss floors, the friend and foe carriers and the enemy-town table live in memory
only. Nothing new is map-bound, so no reset clear.

### Lanes

`round72`'s first-parent merges from the start `f4325384` (lane tip in brackets), in order:

| Lane | Commit | What | Review |
|---|---|---|---|
| EXPMOBS | `cf9fcd07` (`ccd7346e`) | Expedition mobs ignore the Undead truce and keep their full view range, through the existing mark `_grug_expedition` | MERGE |
| MOUNTS | `bf71fcba` (`69dfe622`) | `grug_mounts.enemy_town_at`: summon refused and a per-column dismount in enemy start towns and capitals, every tier and boats | MERGE (`boats.md` by the coordinator, `19ca32b2`) |
| TAGS | `40384c5b` (`bc8a5556`) | Friend and foe carriers, a foe carrier only on demand, four new colour settings pairs | MERGE AFTER FIXES (`r37_dc` pin, `81153450`) |
| FIGHT | `03695b09` (`d145ad51`) | Engagement at targeting, one seam in the `do_attack` wrapper | MERGE AFTER FIXES (README line, `e603cf03`) |
| BLADECRAFT | `d5b507b4` (`f5f47ee3`) | One display state: the bow after a flown shot, the blade after a swing, the blade with the Ranged slot empty | MERGE AFTER FIXES, delta MERGE |
| RANGED | `28f3e436` (`55effdb1`) | The ranged kings get the archers' phase (10 s ranged, 3 s melee), shoot their arrows and seek sight | MERGE |
| WAYTAB | `2177fcc5` (`354d25d1`) | The Expeditions tab on the waystones and the Claim Stone, the ordinary window inside, the Registrar's letter | MERGE AFTER FIXES (spelling, `a1a6b398`) |
| TRAPS | `2c56006d` (`d11cb693`), `0a413460` (`52951196`) | `traps.lua`: floor trap, wall projectile, `strike`; the template's `trap` lines; the `test_vault` gallery | MERGE AFTER FIXES twice, delta MERGE (two harness fixes, `24f6d664`, `ba394f03`) |
| PLACE | `dcd83a29` (`3e2a442d`) | `grug_core/placement.lua`: the seam, doors, beds, bucket, notice board, Claim Stone, falling nodes | MERGE AFTER FIXES (`r48_farm` stub, `415c5564`) |
| BOSSRESET | `fbee9eda` (`e7a149bd`) | `boss_floor.lua`, `reset_home`, the one-way window, the 15 s rule, the Seam's room envelope | MERGE AFTER FIXES (tank swap and respawn), delta MERGE |
| GUARDNAV | `a738063d` (`2d672de9`) | The probe, then `nav.strict` and `reach_reset` for guards, captains, commanders, the rift boss, leaders and rares; evades stop on arrival | MERGE (four Low notes, backlog) |
| SHIFT | `0e09d43b` (`68dc985e`) | The Second Shift: template, Auditor Nemm, his marked spot, loot, names, quest, wall signs | MERGE (`grug_text` dependency `9fa4aa54`; roster stub `8f4f7eae`) |
| MINT | `82d643c6` (`8340a989`) | The Last Mint: template, the lake, `lava_guard.lua`, Return Home refused in and over lava, Duewarden, loot, names, quest | MERGE AFTER FIXES (sliding down a pillar's face), delta MERGE (roster stub `74cd3f29`) |
| Sentinel (added) | `5851dd71` | The user's ruling: the Bedrock Sentinel leaves the guard lists (aggressive, red, an "other" kill) | MERGE |
| Friend or foe (added) | `b7012ec2`, `18c7900b` | The user's ruling: a faction set on activation, a capital's mount displays take its faction | MERGE |
| STYLE | `e9a36ab8` (`b55eda78`) | GPT-6 Astra shaped and dressed all three templates; the Seam cut into smaller chambers | MERGE (two Low, fixed by the coordinator in `b55eda78`) |
| PROOF | `7b37aef0` (`051ac041`) | `tools/expedition_templates/proofs.lua`: free height, perches, coverage and walk-round on all three; probes and engine runs | MERGE (Shift rail siding unhooded `7dab5a56`, a non-vacuous walk-round guard `051ac041`, both by the coordinator) |
| D | this section | Design owners, completion, GUI checklist, backlog, release files, the Undead text | independent review |

`mods/` against the start (measured, `git diff f4325384 7b37aef0 -- mods`): 52 files, +2929
−242, 45 of them Lua. Twelve new portable fixtures (`r72_fight`, `r72_ranged`,
`r72_bladecraft`, `r72_mounts`, `r72_tags`, `r72_traps`, `r72_waytab`, `r72_place`,
`r72_bossreset`, `r72_guardnav`, `r72_shift`, `r72_mint`): 332 in all.

### Decisions during the round

**The user** (2026-11-08, after the planning rulings of §2):

- **The Bedrock Sentinel is no guard:** an aggressive mob with a red tag (`5851dd71`).
- **Every NPC and guard is friend or foe:** no violet or lavender in normal play; fighting
  units green and red, non-combat NPCs light green and light red, the red tag only while an
  enemy is near, a viewer without a faction sees green (`b7012ec2`).
- **Claims reach only T1 depth,** so the Sentinel's road and claim push does nothing below
  −1000.
- **The raider band names** Shift Raider (40–49), Tallied Raider (50–59) and Overdue Raider
  (60–69).
- C1 skipped; C2 after all eight wave-1 lanes.

**The coordinator's defaults, standing until the user says otherwise:**

- TAGS: the carrier callers hold stays eager, only the foe carrier is made on demand; a quest
  giver follows its settlement's faction. (Its third default, lavender capital displays, is
  replaced by the user's friend-or-foe ruling.)
- RANGED: the archers' 10 s / 3 s rhythm, not a purely ranged King.
- BLADECRAFT: an empty Ranged slot while the bow is shown shows the blade.
- WAYTAB: the way back after entering from the Claim Stone is the innkeeper home's waystone;
  the letter writes "Miner's Guild", the game's spelling.
- TRAPS: rearm counted from the hit; a one-node mark; a trap hit can be dodged and marks
  combat for 5 s; a fireball launches only with a run player within 32 of its line; a
  cancelled strike's ring stays.
- PLACE: NPCs count as bodies.
- BOSSRESET: the room envelope as two template places; a whole, healthy retinue stays on a
  reset; the sight veto after a floor reset.
- GUARDNAV: no camp has elite mobs, so the 12 elite leaders stand for them; war commanders
  on; the patroller heals without immunity; about 1 s of combat every 16 s for a player who
  stays in sight.
- SHIFT: one raider more per pack, Nemm 20 × an elite's HP, the chest's coins at factor 10.
- MINT: Return Home refused also while falling towards lava; rooms smaller than the plan's
  envelopes, members spread; Duewarden 14 × an elite's HP.
- STYLE: the Seam's fighting chambers and its cuts (approaches, exits, the cart bay's blind
  ore cut) are separate floor; PROOF proved the cuts reachable only through noticed cells.
- D: the Undead race text ends "(not in Expeditions)".

### Deviations from the plan

- **Two changes added** for the user's rulings (Sentinel, friend or foe), each with its own
  delta review.
- **§3.3's hypotheses:** GUARDNAV's probe refuted the first for the probed cases (the guard
  stuck within 16 nodes and gave up after 6.7–7.6 s) and found the second plausible; there
  was no immunity at all. §3.3's proposal was built as planned.
- **The boss floor** cost 1.6–2.8 ms per seat, not the estimated 10–20 ms; a King's floor is
  his castle, so a target outside the walls resets him at once (reviewer's measurement).
- **Re-checks that changed the build:** settlement NPCs carry no faction field (TAGS reads
  the settlement's); a guard's faction came only on its first tick (fixed by the friend or
  foe change); the waystone trip has no ritual (WAYTAB used the travel path); Nemm's mark
  did not count for the 15 s rule (SHIFT gave `strike` its `opts`); the Skeleton Raider had
  no world name slot (SHIFT added three).
- **The Stilled Seam's boss envelope moved** to (54, 94)–(79, 119) and its walk to 254 steps;
  its model runs 8.6 minutes at 20 (was 8.7).
- **The Shift's rail siding** had two nodes of air (PROOF); the coordinator unhooded it.
- **Integration fixes on `round72`:** two `roster.lua` stubs for `r38_b2` (GUARDNAV's
  `grug_nav`, MINT's `table.copy`), the `r48_farm` stub, the `r37_dc` pin, the `r72_waytab`
  harness and the `r71_frame` probe after TRAPS.
- **Engine runs:** PROOF ran a fourth (The Stilled Seam, after a probe fix), approved by the
  coordinator. GUARDNAV booted once more than planned.

### Numbers worth keeping

From the lanes' reports, measured unless marked; comparisons, not targets.

- **Guards out of reach:** first hit to reset 6.7–7.6 s before, 1.18 s after; health lost
  23–30 % before, 5.6–6 % after; largest search 1.0–1.2 ms before, 1.4–1.6 ms after; a failing
  search at padding 16, 1.1–1.5 ms.
- **Boss floor:** Kings 1073–1084 cells in 3 steps, 1.55–1.74 ms; Generals 1314 cells in 4
  steps, 2.3–2.8 ms; largest step ≤ 714 µs; the once-a-second test under 1 µs. Nemm's 796
  cells, 1.4–2.3 ms.
- **Ranged kings:** 4 searches in 4 lanes over 14 s, the largest 380 µs; damage at 70,
  elite, 107 a second in the ranged phase, 83 over the rhythm (estimated).
- **Nametags:** 30 carriers near a square, 42 with one foe at its edge; the central pass for
  1000 units and 100 players 0.596 → 0.751 ms with half on each side; about 1 ms a second of
  faction reads at 100 players (estimated).
- **Enemy towns:** 0.16–0.24 µs per question; one per column a rider enters.
- **Placement:** one area query, 0.41 µs with nobody near, 3.06 µs among ten bodies.
- **Traps:** before armour 173 at level 20, 1213 at 60; ring to hit 1.54 s; rearm 10.15 s;
  16 particles per warning, 8 per hit.
- **The Second Shift** (modelled, `tools/r72_shift/balance.py`): a run about 10.2 minutes at
  40–60 and 17.0 at 69; Nemm 231 s at 40, 546 s at 69; HP 76,560 at 40 and 210,440 at 69
  (measured); chest coins 640c at 40 against 622c of a quarter hour's income; preparation
  15.9–16.6 s (measured).
- **The Last Mint** (modelled, `tools/r72_mint/balance.py`): about 10.1 minutes at 60, 15.2 at
  69; Duewarden 2.5 and 5.8 minutes, 113,232 and 147,308 HP; chest 4,000c against 2,737c of
  income in the run's time; ore 9 %, gem 10 % of the same time's mining; preparation 18.8 and
  19.4 s, 12 of 12 jumps at 60 and 6 of 6 at 69, death in the lava after 5 ticks (measured).
- **Rooms:** the Seam's floor 5743 → 4216 cells (−26.6 %); the Shift's 4943 and the Mint's
  5300 unchanged by STYLE; every template has at least 3 nodes of air over each floor cell.
- **The Stilled Seam** (modelled): 8.6 minutes at 20, 13.5 at 69.

### Checks

- **Round-end full run** on `7b37aef0` by the coordinator (JOBS=4, through the queue; log in
  the orchestration folder, `r72/reports/integration/`): **326 passed, 6 failed** (`r37_mp`,
  `r41_mob`, `r46_xp`, `r62_frontquests`, `r69_questmap`, `r71_mobs`), fixtures no lane ran:
  the retinue cut and leash pin after BOSSRESET (`r37_mp`, `r41_mob`), the quest count and
  quest data after the two new quests (`r46_xp`: 393 against 391; `r62_frontquests`,
  `r69_questmap`), the wall-sign hook in `encounters.lua` on `r71_mobs`' stub. All six were
  pins, no game logic: the coordinator updated them (`d55094fb`) and the six pass, so the
  round ends at 332 passed, 0 failed. `check_fresh_server.py` PASS and `build.py --check` OK on `7b37aef0`.
- **Engine, real client on Xvfb:** The Second Shift 164 PASS, The Last Mint 185 PASS, The
  Stilled Seam 142 PASS, each 0 FAIL, after STYLE (PROOF); every lane's probe and smoke boot is
  in its report.
- **Lane D:** docs, release files and one string; no fixture beyond `r37_dc` (it pins the
  version and CHANGELOG lane D changes), no boot. `check_upgrade.py --base 5a8909a0` PASS,
  `check_fresh_server.py` PASS, `check_lua.sh` on `grug_classes/init.lua` PASS.

### Open notes

- **For the user:** the two questions (checklist 28 and 44), the *look* items, and the
  numbers only a real run gives: run lengths, Nemm's and Duewarden's HP, the coins, the
  mining share. The free wipe stays noted, not closed (§2.9).
- **Carry-overs** are in [BACKLOG](../../BACKLOG.md#round-72--fights-placement-travel-and-two-expeditions-gui-acceptance-pending).
