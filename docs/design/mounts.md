# Mounts — Riding, Speed Tiers & No-Mount Zones

Decided 2026-08-07; revised 2026-08-11 for open-world housing and the authored
front, 2026-09-18 for the Round-9 entity, border and safety rules, and
2026-09-20 for capital trainers and mounted usability.

Neighbouring rules: the named-zone faction front `world_zones.md`, travel plus
ocean/dragon-island integration in `world.md`, the complete open-world Claim
Stone contract in `housing.md`, boats as the water mode in
`boats.md`, the four mastery names in `professions.md` §1.1,
universal skills `professions.md` §1, the mob speed pillar
`combat_stats.md` §3 and the pursuit rules of `combat_stats.md` §4 and its
"Ambient pursuit policy" (free-roaming mobs: incoming-damage clock, no chase
leash; bound actors: leash and give-up distance).

## 1. Riding is a universal skill

- **Riding does not cost a main profession slot.** Like the secondaries
  **Cooking** and **Alchemy** (`professions.md` §1) it is universal — every
  character can learn it, and the two main profession slots stay free for the
  six crafting professions.
- Riding is learned **from a dedicated Riding Trainer in every race capital**, in four
  steps at character levels 15, 30, 45 and 60 (D20 decided 2026-08-13:
  the earlier job-trainer rule is superseded). There is no Riding Trainer in a
  race start, so the first tier requires a trip to a capital. A learned step is
  **player state, permanent and per character**,
  and purchase records it; it hands out no item. Owned mounts and boats are
  used from the quickbar (E, §3); the Riding Trainer and the Shipwright say
  so in their dialogue ("Press E to open your mounts.").
- Every capital has one outer-district stable using the same shared building
  design, with the local architectural palette: earth floor, one-node fence,
  clear entrance and a flat roof on exactly six posts, without perimeter walls.
  All six stable floors use `grug_farming:soil`, the same non-grassing earth as
  the Human starting fields, so nearby grass cannot spread across the enclosure.
  Its dedicated Riding Trainer stands in front of four protected displays of the existing mount appearances
  available to that race, one for each tier in §1.1: 24 displays across six cities.
  CAP authors separate bounded movement/rest regions for all four sockets.
  Ground mounts take short slow walks and pauses inside their safe region;
  flying appearances stay grounded with verified idle animation. Full-size
  posed meshes, the trainer approach and neighboring displays remain clear
  throughout the allowed movement. GAME owns throttled movement and persistence;
  CAP owns the roof, enclosure and socket geometry. These displays have no
  combat AI, attacks, loot, flight or visible teleport resets and cannot be
  ridden or yield items.
  Trainer, stable and displays use the authored settlement activation identities;
  saving, reload and partial activation must not duplicate them. Riding is absent
  from every profession trainer.
- **Mounts are not a reward and not a drop** — they are bought (§2), and
  buying them is the point (§2 is a gold sink).
- **Trainer dialogue (Round 28 ruling 19):** all four tiers are always
  listed, each with its state: **Owned**, a **Buy <price>** button,
  greyed **Requires level N** or greyed **Learn <previous tier> first**
  (only Buy is a button). A purchase result shows in the flash line and in
  the reopened dialogue, never in chat.

### 1.1 The four tiers

Riding reuses the **names and order** of the four crafting mastery tiers
(`professions.md` §1.1), but its purchase levels are the exact travel
milestones 15/30/45/60. Riding and profession mastery remain independent
character state:

| Mastery | Learn at character level | Mount | Speed | Mount speed |
|---|---|---|---|---|
| Apprentice | 15 | slow land mount | +60 % | 6.4 nodes/s |
| Journeyman | 30 | fast land mount | +100 % | 8 nodes/s |
| Expert | 45 | slow flying mount | +100 % | 8 nodes/s |
| Master | 60 | fast flying mount | +200 % | 12 nodes/s |

| Tier | Character identity | Mount family |
|---|---|---|
| T1 | Accord / Throng | faction-coloured horse |
| T2 | Human / Dwarf / Elf | horse / ibex / stag |
| T2 | Orc / Undead / Troll | boar / grave wolf / tiger |
| T3 | Accord / Throng | eagle / cave bat |
| T4 | Accord / Throng | Steller's sea eagle / giant blood bat |

- Percentages are relative to a player's **default walking speed of 4
  nodes/s** (engine default `movement_speed_walk = 4`,
  `reference_projects/luanti/src/defaultsettings.cpp:520`; the game
  does not override it).
- **Every tier is faster than ordinary aggressive mobs** — they run 4.6
  (`combat_stats.md` §3), while the slowest mount runs 6.4. Bespoke encounters
  such as the Kraken keep their separate speed rules.
  **Incoming damage dismounts the rider** (§3.1): the travel speed is
  permanent, the immunity to the mob game is not.
- The two flying tiers are the late-game milestones. Expert matches the
  level-30 fast land mount at +100% and adds direct aerial routes and terrain
  access. Master reaches +200% travel speed (user playtest ruling 2026-09-20).
- **Flight buys terrain at home and over the shared Battlegrounds, not in enemy
  territory or across ocean.** The two land tiers remain legal in enemy
  territory; §4 owns the complete geographic rule.
- Each exact character-level anchor is the purchase gate; below it the tier
  is listed greyed ("Requires level N", Round 28 ruling 19 above).
  Price is calibrated by reliable net earning time rather than preserving the
  obsolete 1s/8s/30s/60s table.
- **One quickbar button per bought tier** (Round 44; no inventory item).
  Buying a higher tier retains every preceding tier, and each button summons
  its original tier at its original speed. Persistent highest-tier metadata
  is the ownership authority.
- T1 is a faction-coloured horse. T2 is a Human horse, Dwarf ibex, Elf stag,
  Orc boar, Undead grave wolf and Troll tiger. Accord flight uses an eagle at
  T3 and the larger, nobler-coloured Steller's sea eagle at T4; Throng flight
  uses a cave bat at T3 and a larger, nobler-coloured giant blood bat at T4.
  Dragons are never mounts.

*Rationale for reusing the names*: the four names already carry a meaning for
every player. A fifth vocabulary for four sequential purchases would be pure
terminology tax; the exact mount levels are nevertheless authored independently
so the travel unlocks land cleanly at 15/30/45/60.

### 1.2 Map-scale consequence

Mount speeds do not define a target journey duration. The three capital x
anchors are fixed at −1,800, 0 and +1,800 by `world_zones.md`; authored roads,
terrain and the geographic restrictions in §4 determine how long a particular
journey actually takes. Mount balance is therefore expressed only by the
movement speeds and unlock levels in §1.1, not by promised capital-to-capital
minutes.

## 2. Prices — the riding gold sink

Each tier is bought once and remains permanent character state. Prices come
from the per-bracket net-income estimate (`economy.md` §3, §4.2; Round 29 lane
E4) and are rounded by `economy.md` §4.1; the old 1s/8s/30s/60s table is
superseded.

| Tier | Level | Target reliable net solo earning time | Price |
|---|---:|---:|---:|
| Apprentice — slow land mount | 15 | about 15 minutes | 1s5c |
| Journeyman — fast land mount | 30 | about 45 minutes | 7s |
| Expert — slow flying mount | 45 | about 2 hours | 1g29s |
| Master — fast flying mount | 60 | about 5 hours | 7g38s |

The measurement is after routine repairs and consumables and excludes rare
jackpots or an assumed player market. The first mount is readily achievable;
the fast level-60 flyer is an aspirational farming goal without becoming an
arbitrary fixed-price wall.

## 3. What a mount is, mechanically

Boats are the third movement mode, **water**, next to land and flight
(`boats.md`, 2026-10-02): two boat tiers with the same quickbar button,
ephemeral entity, eject and teardown rules as this section,
sold by the Shipwright instead of the Riding Trainer and summoned only in
water. Flight and its geography (§3.2, §4) do not apply to them.

- **Mounts are bought, never tamed.** Taming was considered and
  **rejected**: there is no taming design, and the vendored mobs_redo's
  taming items (`mobs:saddle`, `mobs:lasso`, `mobs:net`) and its other
  utility items were removed in Round 26 (WP28). A mount is a purchase, exactly like a tome or
  a permanent character upgrade.
- **The quickbar is the only place for mounts** (Round 44,
  `inventory_equipment.md` "Quickbar"): E opens it, and each purchased tier
  has one button there, the summon/dismount action; a click acts and closes
  the window. Nothing hands out a mount item. The six items of earlier
  versions (`grug_mounts:apprentice_mount` … `grug_mounts:improved_boat`)
  stay registered as inert items (no use; still kept to `main` and the own
  bags, a drop deletes them) until the 0.44.0 migration step removes them.
- A click on foot creates one ephemeral mount entity at the player's
  exact position and rotation. The entity takes over that position as the
  movement and collision authority, and the player's visible character is
  attached on top. While mounted, movement controls drive only the mount entity;
  the player's independent movement is disabled.
- A/D strafe relative to the camera on both ground and flying mounts. Forward
  and sideways movement use full tier speed; reverse alone retains 35%.
  Horizontal diagonals are normalized to prevent a speed bonus. Flight ascent
  and descent retain their existing controls and speed.
- **A mount is therefore an entity the player is attached to.** The player calls
  `player:set_attach(mount_entity, ...)`
  (`reference_projects/luanti/doc/lua_api.md:8948`); while attached the
  player's `get_pos`/`get_rotation` return the parent entity's values
  and their own setters are ignored (`lua_api.md:8864-8870`).
- The physical mount controller is invisible. Its visible mesh is attached as
  a child of the rider. For riding and flying mounts the attachment sets
  `forced_visible` (Round 45 playtest): the rider sees the mount's head and
  front half ahead of and below the camera in first person, so it feels like
  riding or flying; without the flag the engine hides a child of the local
  player in first person. A boat's hull keeps the engine default and stays
  hidden from its own rider in first person. Third-person views and other
  clients show the complete rider-and-mount silhouette. Dismount and every
  lifecycle exit remove both ephemeral objects.
- Land mounts automatically step over slabs and nominal one-node rises while
  moving forward, without jump input. Their controller uses a **1.01-node**
  step height to clear the engine's strict collision comparison; taller
  obstacles and low ceilings continue to block them. Flying movement is
  unchanged.
- Within each riding tier every race and faction has the same collision and
  selection box (Round 31 ruling 8, fairness); look, size and seat stay per
  race and faction. Tiers 1 and 2 use the Courser's box (1.4 wide, 1.6
  high); the Expert and Master flyers share one flyer body (1.8 wide, 1.65
  high), so every riding mount passes openings two nodes wide and high. Each
  tier's selection box is sized for its highest seat.
- While mounted, the status icon row (`inventory_equipment.md` §5) shows a
  land, flight or boat icon with an empty caption (no countdown); the tier
  name and speed bonus (for example "+60% speed") appear on the Character
  page's Effects tab. This is
  runtime-only UI state, supplies no movement modifier and is cleared by the
  shared dismount path.
- Only one active mount entity (mount or boat) may exist per player. The
  active tier's button dismounts (the quickbar frames it). Another owned
  tier's button replaces the active mount when that tier may be summoned
  there; otherwise the active mount stays and the refusal is shown. Every
  dismount removes the ephemeral entity; no horse or flying creature remains
  parked in the world.
- **Mount speed is the entity's velocity, never
  `physics_override.speed`.** That follows from the attachment above and
  it matters: since the movement aggregator landed (ruling 11, 2026-09-16,
  `skill_trees.md` §3.9) `physics_override` has exactly **one** owner,
  `mods/CORE/grug_core/movement.lua` — mob webs, the PvP snare chain and the
  character-creation freeze all register named modifiers there. Riding adds
  no writer: **mounts stay outside the aggregator**.
- **A mount carries no level, no XP, no threat and no aggro.** It is not
  registered through `grug_mobs.register_mob` — that wrapper *is* the
  level/XP engine (AGENTS.md, WP6 patterns) and would give a horse a
  level, a health bar and a con colour.
- **Dismounting** detaches the player, removes the ephemeral mount and places
  the player on a free neighbouring node where geography permits — the
  `mobs.detach` / `find_free_pos` pattern of the vendored
  `mods/ENTITIES/mobs/mount.lua`.
- **Death, logout and server shutdown dismount automatically.** The shared
  mount cleanup removes controller, visible child, warning and runtime status
  exactly once, even when vendored attachment cleanup runs first. Logout and
  shutdown skip animation/appearance restoration because player display records
  may already be gone; ordinary dismount and death retain that restoration.
  No deferred movement callback is scheduled during teardown. Mount ownership
  remains in player metadata; every reconnect starts on foot.
- **Entering a no-mount zone dismounts you** (§4) — via the same detach and
  entity-removal transaction.
- **A stun dismounts you**: `grug_core.set_stun` dismounts a mounted player
  (`grug_core/movement.lua`).
- **Taking damage dismounts you** (§3.1) — the same detach path again.
- Mounting is refused while `grug_core.in_combat(player)` reports the active
  five-second combat window.
- A mounted player cannot use abilities, casts or combat swings. They must
  dismount before attacking; the refusal is a grey message-feed line
  ("Dismount before attacking."), not a chat line.
- The entity is invulnerable, carries no drops and never persists in static
  data. A punch aimed at the attached entity is transferred to the rider and
  then dismounts them; direct player damage dismounts through a player
  HP-change observer.

### 3.1 Incoming damage dismounts the rider (decided 2026-08-08)

- **Any incoming damage dismounts the rider, immediately.** Damage from
  any source counts — a mob's melee swing, a ranged attack, an enemy
  player in PvP, the environment. There is **no threshold and no grace
  period**: geographic warnings exist because a player cannot see an exact
  rules boundary, while a hit is unambiguous and the whole point of this rule
  is that it lands at the moment of the hit.
- **A lower maximum HP is not damage** (Round 37): when an HP buff (food,
  the Elixir of Vigor) runs out or gear with +HP % comes off, the engine
  lowers HP to the new maximum; the rider stays mounted, also in flight
  (`grug_core.is_max_hp_clamp`).
- The dismount uses the **same detach path** as every other one (§3), so
  the rider is set down on a free neighbouring node rather than inside
  the mount's model. The hard geographic mid-air dismount is the exception:
  it keeps the rider at the boundary position, and the rider leaves the mount
  with no residual velocity (the engine holds an attached player's velocity at
  zero), so gravity begins a straight fall. No velocity derived from the
  server-side `get_velocity()` is added: for an attached player that value is
  the stale speed from before mounting (Round 28 ruling 16).
- **Implementation note (engine fact, recorded 2026-08-13):** mobs_redo
  punches *what the player is attached to* —
  `local target = self.attack:get_attach() or self.attack`
  (in the melee attack branch of `mods/ENTITIES/mobs/api.lua`) — so a mob's melee swing lands on
  the mount entity and the rider loses no HP from it. That swallowed swing is
  transferred to the rider and triggers the dismount; damage aimed at the
  player directly (our own PvP pipeline, projectiles, drowning, environment)
  reaches the rider normally. The rule therefore uses **two** hooks: the mount
  entity's `on_punch` and a player HP-change observer.

### 3.2 Flight start and ceiling

- A flying mount cannot take off while the player is below
  `grug_zones.terrain_height_at(x,z)`. This is the underground rule; it is
  independent of node names and cave shape.
- The flight ceiling is exactly **y = 600** in every zone. Upward input stops
  there and any integration overshoot is clamped back to y = 600.
- Geographic hard dismounts in mid-air have no glide, slow descent or grace:
  the rider's complete velocity is cleared and ordinary gravity takes over.

Ordinary aggressive mobs run at **4.6 nodes/s** against a player's **4.0**.
Ordinary pursuit follows `combat_stats.md`'s Round 19 rule: initial aggro
starts a 15-second grace clock and effective incoming player/guard HP damage
refreshes it. For a live current target, expiry triggers return only when the
target moves at least 0.25 nodes horizontally between the existing one-second
samples; standing still does not reset the clock. Outgoing attacks do not
refresh it. Bosses and location-bound encounters retain their own limits.
Mounts run **6.4–12 nodes/s** and could otherwise bypass ordinary chase danger
indefinitely. Damage therefore dismounts a rider; mounted attacks remain blocked.

The same pillar is why the **Swiftness Draught** is capped where it is:
`items_crafting.md` §3.6 gives it **+10 % for 5 s** and §10 P4 states the
arithmetic outright — 4.0 × 1.10 = 4.4 < 4.6, so even the alchemist's brief
sprint keeps mobs faster.
A mount breaks that ceiling permanently and by design; **the dismount is
what pays for it.** Riding buys travel between fights, never an exit from
one.

Named, long-cooldown skills may temporarily exceed the ordinary speed
inequality (`skill_trees.md` §5). The Scout's Sprint gives **+50% for 10 s on
a 300 s cooldown** (`scout.md` §2): 6.0 nodes/s against ordinary aggressive
mobs' 4.6. That temporary advantage does not replace permanent mount travel.
The exception is deliberately narrow: it covers named, time-limited,
long-cooldown abilities and nothing permanent or cheap. The
**Swiftness Draught's +10 % for 5 s stays below the mob band** (4.0 × 1.10 =
4.4 < 4.6), and a mount keeps paying for its permanent 6.4–12 nodes/s with the
dismount rule above.

**And it stops being a formality once ranged attackers exist.** Today a
rider mostly has to walk into a melee swing to lose the mount, but
skeleton archers already fight at range (`dogshoot`, `combat_stats.md`
§3), bows are fully catalogued as a Phase-2 enabler
(`items_crafting.md` §9) and a ranged/stealth class direction is deferred
Phase-2 work (`classes.md` §6). From that point on a rider crossing
hostile or enemy ground can be **brought down at range**, which is
exactly the counterplay a permanent speed buff needs — and in PvP it is
the counterplay to mounts, since a player's damage dismounts like any
other.

## 4. Where riding is forbidden

Mount legality is derived from the authored territory and ocean-column lookup,
never from literal coordinates. Horizontal classification applies at every y:
climbing above a boundary never changes its rule. Land riding, flight, ocean
warning and forced dismount are separate consumer states derived from
`grug_zones.water_class_at(x,z)` and the horizontal
`grug_zones.at(pos).territory_rule` record.

### 4.1 Ocean: warned edge, then forced flight dismount

- Flying is forbidden over every authored ocean column: the coastal-water
  shelf, deep ocean and the channels around both dragon islands. The rule is
  independent of altitude. The landward planned parts of bays, lakes, rivers,
  marsh channels and other water inside a mainland footprint remain part of
  their named zone, inherit its flight rule and do not become ocean merely
  because they contain water nodes or connect to the outer sea. The four
  declared outer bay-mouth caps are deep ocean and use this section's warning
  and forced-dismount rule.
- A flying mount cannot be summoned in an ocean column. Once per second, the
  visible warning probes the same flight-legality rule as the hard dismount in
  16 horizontal directions at 1, 2, 4, 8, 16, 32 and 48 nodes. This samples at
  most 112 columns per rider per second, detects adjacent illegality exactly
  and resolves the 48-node warning reach to within plus or minus 4 nodes at
  range. HUD text and one message-feed line warn that crossing will force a dismount;
  moving clear of every sampled illegal column removes the warning.
- Width is spatial, not a timer, so the +100% and +200% flyers receive the same
  boundary. The **first ocean node** is already illegal and dismounts
  immediately at every y, with no grace, slow descent or maximum-trip rule.
- The public zone queries supply the channel geometry. Each channel is
  roughly 200 water nodes wide, and the world's construction self-check
  requires at least **104 nodes** (`world_zones.md` §7.4), so neither island is
  reachable by flying mount from a continent. Clearing residual velocity on
  the hard dismount prevents high-altitude drift onto the island.
- The two dragon islands remain boat destinations. Their complete water
  channels are immutable at every depth, and the flight classification may not
  accidentally create a bridge, tunnel or aerial-access exception.
- The obsolete ten-second mounted `Exhausted` rule and the rectangular
  legacy open-sea geometry do not govern flight in the target map.
  Swimming, boats and any later deep-ocean damage effect remain ocean-system
  concerns rather than mount movement rules.

### 4.2 Contested mainland, dragon islands and housing claims

- **Both factions may summon and use either flying tier throughout the
  contested mainland, including ordinary contested regions and the Battlegrounds.**
  The shared-front territory is an intentional aerial PvP space,
  not enemy territory. Its planned water inherits this permission because it
  is not an ocean column.
- PvP and NPC combat remain active there. Any incoming damage still dismounts
  immediately under §3.1, so permission to fly is not safety or immunity.
- Both dragon islands forbid flight for both factions; ground riding remains
  allowed. Villages and other POIs inherit their surrounding zone, never an
  independent faction ownership rule.
- Open-world housing claims add no special mount ban. They inherit the ordinary
  mount rule of their peaceful home-faction zone; a claim boundary itself never
  summons or dismounts a mount (`housing.md`; `world.md` §5).

### 4.3 Enemy safe territory: land tiers yes, flying tiers no

- **The two land tiers are allowed on enemy land.** A
  rider on a horse still walks the ground, still meets whatever
  `guard_level_at` has put on it (`world.md` §1), and still has to use an
  authored land connection or another physical route. Nothing about a land
  mount bypasses terrain, so nothing about it needs a rule.
- **Flying mounts are banned in enemy safe home territory, including capitals.** Two halves, both
  binding:
  - **A flying mount cannot be summoned there.** The mount action is
    refused outright with a message because a deliberate action needs no grace
    period.
  - The same **48-node legal-side warning band** as the ocean boundary applies.
    The first node beyond the line is illegal and hard-dismounts immediately.
    There is no ten-second grace and no 100-node maximum-trip allowance.
- The two **land** tiers are untouched by this rule, and the two flying
  tiers (Expert, Master — §1.1) are untouched by it at home and throughout the
  Battlegrounds (§4.2).

**Why the ban exists.** `world_zones.md` makes the authored land connections
the places where faction contact, defenders and PvP objectives meet. A flying
mount is the first travel system that could ignore the roads, passes, walls and
approach terrain that make those fronts work. Without the border rule a Master
rider could cross a coast or mountain boundary and land beyond the intended
defence instead of engaging with it. `world.md` §6's ban on enemy-territory
waypoints closes the same bypass for teleportation.

**The mechanism is the central territory/zone lookup, never a hand-picked
coordinate.** `grug_zones.water_class_at(x,z)` separates authored ocean from
land and planned inland water; the horizontal
`grug_zones.at(pos).territory_rule` record allows the rider's own
`accord_home`/`throng_home` and `contested_land` (which the four
Battlegrounds zones also use).
The two dragon-island identities override contested permission and are always
flight-restricted; ocean is checked independently. Depth-sensitive civic protection does not alter this
horizontal flight decision. The rider's identity comes from
`grug_factions.get_faction(player)`. Literal coordinates are invalid once the
authored zone layout replaces WP18. A character without a faction cannot have
bought a mount, so the nil case needs no rule of its own.

**Ocean is a separate classification with the same border transaction.** The
enemy-territory rule does not legalize flight over neutral water: §4.1 warns on
the legal side and dismounts at the first ocean node at every altitude. Read
along a legal invasion path, the system is therefore own land → flyable
Battlegrounds → warned enemy border → forced ground travel; the dragon islands
instead require a boat because their ocean channel reaches the hard no-flight
state first.

## 5. Reference implementations & licences

Three vendored reference projects carry a ride/attach pattern worth
adapting. Licence verdicts per AGENTS.md "Licenses" (project code is
GPL-3.0-or-later):

| Source | What to take | Code licence | Verdict |
|---|---|---|---|
| **mobs_redo** (already vendored as `mods/ENTITIES/mobs`) | the complete ride API | MIT (`reference_projects/mobs_redo/license.txt:1`) | ✓ compatible |
| **Lord-of-the-Test** `lottmobs/horse.lua` | mount-as-purchasable-item pattern | LGPL 2.1 (`Lord-of-the-Test/LICENSE.txt:1`; per-file heritage in `mods/lottmobs/license.txt`: PilzAdam WTFPL, TenPlus1 MIT, LGPL 2.1 contributions) | ✓ compatible |
| **VoxeLibre** `mcl_mobs/mount.lua`, `mobs_mc/horse.lua` | a maintained fork of the same API | GPL-3.0-or-later (`VoxeLibre/LEGAL.md`); `mobs_mc/README.md` names GPLv3 for that mod, and LEGAL.md's dual-licence clause lets us take the game's GPL-3.0-or-later terms instead | ✓ compatible |

- **mobs_redo is the base**: `mount.lua` is already vendored and loaded
  (`mods/ENTITIES/mobs/init.lua`). Its four public helpers are
  `mobs.attach(entity, player)`, `mobs.detach(player)`,
  `mobs.drive(entity, moving_anim, stand_anim, can_fly, dtime)` and
  `mobs.fly(entity, dtime, speed, moving_anim, stand_anim)`; the local
  `force_detach` and the leave/shutdown/die handlers sit at the top of
  `mount.lua`. `drive`'s `can_fly` flag and `fly` are exactly the land /
  flying split of §1.1, and the speed cap is the entity's own
  `max_speed_forward` (read in `mobs.drive`). It **requires the
  `player_api` mod** (the head of `mount.lua` stubs the whole API out
  otherwise) — we vendor it as `mods/BASE/player_api`, so the
  precondition holds.
- **Lord of the Test** shows the acquisition half we need and mobs_redo
  does not have: `lottmobs:register_horse(name, craftitem, horse)`
  (`Lord-of-the-Test/mods/lottmobs/horse.lua:26`) registers a
  **craftitem whose `on_place` spawns the mount entity** (`:31-41`) next
  to a plain `core.register_entity` mount (`:305`) with attach/detach on
  right-click (`:200-222`). Reuse only the item-to-entity registration shape:
  Grudgelands uses the persistent, non-consuming toggle lifecycle of §3 and
  removes the ephemeral entity on every dismount. It must not copy a placed,
  parked or consumed-horse lifecycle.
- **VoxeLibre**'s `mcl_mobs/mount.lua` (`mcl_mobs.attach` at `:52`,
  `detach` `:82`, `drive` `:89`, `fly` `:222`) is the same lib_mount
  ancestry, better maintained; `mobs_mc/horse.lua:226` is the reference
  call site. Use it to cross-check fixes, not as a second base — mixing
  GPL-3.0 code into the MIT-licensed vendored copy would relicense it
  for no gain.
