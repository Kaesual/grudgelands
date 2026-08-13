# Mounts — Riding, Speed Tiers & No-Mount Zones

Decided 2026-08-07; revised 2026-08-11 for open-world housing, the authored
front and the level-15/30/45/60 travel ladder. **Nothing here is built yet**:
this file is the spec a later work package implements, not a description of
shipped behaviour. It exists so that the WP can be cut without re-opening the
design.

Neighbouring rules: the named-zone faction front `world_zones.md`, travel plus
ocean/dragon-island integration in `world.md`, the complete open-world Claim
Stone contract in `housing.md`, playable-boat behavior tracked in
`TODO-design-boats.md`, the four mastery names in `items_crafting.md` §2.1,
universal skills `professions.md` §1, the mob speed pillar
`combat_stats.md` §3 and the chase/leash model `combat_stats.md` §4.

## 1. Riding is a universal skill

- **Riding does not cost a main profession slot.** Like **Cooking** and
  **First Aid** (`professions.md` §1) it is universal — every character
  can learn it, and the two main profession slots stay free for the six
  crafting professions.
- Riding is learned **from the job trainer in every race capital**, in four
  steps at character levels 15, 30, 45 and 60 (D20 decided 2026-08-13:
  riding is a role on the existing job trainer, exactly like Cooking and
  First Aid — no dedicated stable master and no Quartermaster involvement in
  the MVP). A learned step is **player state, permanent and per character**,
  and it hands over the owner-bound mount item of that step.
- WP13 reserves only a **cosmetic stable/hitching-post dressing slot** near
  the job trainer's court in the Market/Professions capital quadrant. It is
  ordinary mutable, claim-excluded dressing, never a functional anchor; a
  later dedicated stable master (Phase 2+, e.g. with D19 variants) can attach
  there without moving NPCs or roads.
- **Mounts are not a reward and not a drop** — they are bought (§2), and
  buying them is the point (§2 is a gold sink).

### 1.1 The four tiers

Riding reuses the **names and order** of the four crafting mastery tiers
(`items_crafting.md` §2.1), but its purchase levels are the exact travel
milestones 15/30/45/60. Riding and profession mastery remain independent
character state:

| Mastery | Learn at character level | Mount | Speed | Mount speed |
|---|---|---|---|---|
| Apprentice | 15 | slow land mount | +50 % | 6 nodes/s |
| Journeyman | 30 | fast land mount | +100 % | 8 nodes/s |
| Expert | 45 | slow flying mount | +75 % | 7 nodes/s |
| Master | 60 | fast flying mount | +150 % | 10 nodes/s |

- Percentages are relative to a player's **default walking speed of 4
  nodes/s** (engine default `movement_speed_walk = 4`,
  `reference_projects/luanti/src/defaultsettings.cpp:520`; the game
  does not override it).
- **Every tier is faster than every mob** — aggressive mobs run 4.4
  (`combat_stats.md` §3). That is deliberate, and it is exactly why
  **incoming damage dismounts the rider** (§3.1): the speed is
  permanent, the immunity to the mob game is not.
- The two flying tiers are the late-game milestones. Expert is deliberately
  slower than the level-30 fast land mount: its +75% buys direct aerial routes
  and terrain access, not the next linear speed step. Master buys both flight
  and the top +150% travel speed.
- **Flight buys terrain at home and over the shared Holy Grounds, not in enemy
  territory or across ocean.** The two land tiers remain legal in enemy
  territory; §4 owns the complete geographic rule.
- Each exact character-level anchor is both the visibility and purchase gate.
  Price is calibrated by reliable net earning time rather than preserving the
  obsolete 1s/8s/30s/60s table.

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

Each tier is bought once and remains permanent character state. Exact Gold
prices are derived only after the revised per-tier net-income calibration; the
old 1s/8s/30s/60s table is superseded.

| Tier | Level | Target reliable net solo earning time |
|---|---:|---:|
| Apprentice — slow land mount | 15 | about 15 minutes |
| Journeyman — fast land mount | 30 | about 45 minutes |
| Expert — slow flying mount | 45 | about 2 hours |
| Master — fast flying mount | 60 | about 5 hours |

The measurement is after routine repairs and consumables and excludes rare
jackpots or an assumed player market. The first mount is readily achievable;
the fast level-60 flyer is an aspirational farming goal without becoming an
arbitrary fixed-price wall.

## 3. What a mount is, mechanically

- **Mounts are bought, never tamed.** Taming was considered and
  **rejected**: there is no taming design, and the vendored mobs_redo's
  taming items — `mobs:saddle`, `mobs:lasso`, `mobs:net`
  (`mods/ENTITIES/mobs/crafts.lua:119`, `:138`, `:231`) — are removed with the
  vendored-recipe cleanup. A mount is a purchase, exactly like a tome or
  a permanent character upgrade.
- **Each purchased tier is an owner-bound inventory/hotbar item.** The item is
  the summon/dismount action; it is never consumed, removed from the inventory
  or dropped into the world while mounting or dismounting. Permanent player
  state is the authority for ownership, so the trainer can restore a missing
  representation without permitting duplicates or trading.
- Using the item on foot creates one ephemeral mount entity at the player's
  exact position and rotation. The entity takes over that position as the
  movement and collision authority, and the player's visible character is
  attached on top. While mounted, movement controls drive only the mount entity;
  the player's independent movement is disabled.
- **A mount is therefore an entity the player is attached to.** The player calls
  `player:set_attach(mount_entity, ...)`
  (`reference_projects/luanti/doc/lua_api.md:8948`); while attached the
  player's `get_pos`/`get_rotation` return the parent entity's values
  and their own setters are ignored (`lua_api.md:8864-8870`).
- Only one active mount entity may exist per player. Using the active mount item
  again dismounts. Every dismount removes the ephemeral entity; no horse or
  flying creature remains parked in the world, and the unchanged item was in
  the inventory throughout.
- **Mount speed is the entity's velocity, never
  `physics_override.speed`.** That follows from the attachment above and
  it matters: `physics_override.speed` already has two declared owners
  (mob webs in `mods/ENTITIES/grug_mobs/verbs.lua:100-118` and the PvP
  snare chain in `mods/PLAYER/grug_abilities/kits.lua`). Riding adds no
  third owner and can never collide with a slow.
- **A mount carries no level, no XP, no threat and no aggro.** It is not
  registered through `grug_mobs.register_mob` — that wrapper *is* the
  level/XP engine (AGENTS.md, WP6 patterns) and would give a horse a
  level, a health bar and a con colour.
- **Dismounting** detaches the player, removes the ephemeral mount and places
  the player on a free neighbouring node where geography permits — the
  `mobs.detach` / `find_free_pos` pattern of the vendored
  `mods/ENTITIES/mobs/mount.lua:183-198` and `:107-120`.
- **Death, logout and server shutdown dismount automatically.** The
  vendored mount API already registers `on_dieplayer`, `on_leaveplayer`
  and `on_shutdown` force-detach handlers
  (`mods/ENTITIES/mobs/mount.lua:47-97`), so no separate rule is needed:
  you always come back on foot.
- **Entering a no-mount zone dismounts you** (§4) — via the same detach and
  entity-removal transaction.
- **Taking damage dismounts you** (§3.1) — the same detach path again.

### 3.1 Incoming damage dismounts the rider (decided 2026-08-08)

- **Any incoming damage dismounts the rider, immediately.** Damage from
  any source counts — a mob's melee swing, a ranged attack, an enemy
  player in PvP, the environment. There is **no threshold and no grace
  period**: geographic warnings exist because a player cannot see an exact
  rules boundary, while a hit is unambiguous and the whole point of this rule
  is that it lands at the moment of the hit.
- The dismount uses the **same detach path** as every other one (§3), so
  the rider is set down on a free neighbouring node rather than inside
  the mount's model.

**Why this rule exists: it is what keeps the speed pillar intact.**
`combat_stats.md` §3 gives aggressive mobs `run_velocity` **4.4** against
a player's **4.0** — "evading must never be trivially easy" — and the
whole mob game is built on top of that one inequality: the **25 m soft
de-aggro** (`combat_stats.md` §3 — a chasing mob drops to walk speed, so
fleeing is hard but not impossible) and the **45 m chase give-up** and
**40 m leash** of `combat_stats.md` §4 all assume the mob can close the
distance. A mount does **6–10 nodes/s
permanently** (§1.1) and is therefore faster than every mob in the game.
Without this rule a mounted player is simply immune to the mob game: no
chase can ever be won, the soft de-aggro and the leash become
unreachable by design, and the one number the design leans on hardest
stops being true.

The same pillar is why the **Swiftness Draught** is capped where it is:
`items_crafting.md` §3.6 gives it **+8 % for 15 s** and §10 P4 states the
arithmetic outright — 4.0 × 1.08 = 4.32 < 4.4, so even the alchemist's
best sprint keeps mobs faster, and the 15 seconds are deliberately short.
A mount breaks that ceiling permanently and by design; **the dismount is
what pays for it.** Riding buys travel between fights, never an exit from
one.

**And it stops being a formality once ranged attackers exist.** Today a
rider mostly has to walk into a melee swing to lose the mount, but
skeleton archers already fight at range (`dogshoot`, `combat_stats.md`
§3), bows are fully catalogued as a Phase-2 enabler
(`items_crafting.md` §9) and the Rogue/Hunter direction is deferred
Phase-2 work (`classes.md` §6). From that point on a rider crossing
hostile or enemy ground can be **brought down at range**, which is
exactly the counterplay a permanent speed buff needs — and in PvP it is
the counterplay to mounts, since a player's damage dismounts like any
other.

## 4. Where riding is forbidden

Mount legality is derived from the authored territory and ocean-column lookup,
never from literal coordinates. Horizontal classification applies at every y:
climbing above a boundary never changes its rule. Land riding, flight, ocean
warning and forced dismount are separate states returned by one central lookup
owned by WP40.

### 4.1 Ocean: warned edge, then forced flight dismount

- Flying is forbidden over every authored ocean column: the coastal-water
  shelf, deep ocean and the channels around both dragon islands. The rule is
  independent of altitude. Planned bays, lakes, rivers, marsh channels and
  other water inside a mainland footprint remain part of their named zone,
  inherit its flight rule and do not become ocean merely because they contain
  water nodes or connect to the outer sea.
- A flying mount cannot be summoned in an ocean column. A flyer leaving legal
  land first enters a visible warning band exactly **48 horizontal nodes**
  wide. The HUD warns that continuing will force a dismount; returning to legal
  land clears the warning immediately.
- Width is spatial, not a timer, so the +75% and +150% flyers receive the same
  geographic boundary. At the far edge, entry into the hard no-flight column
  dismounts immediately with no second grace period, at every y.
- WP40 derives flight from the exact channel geometry in `world_zones.md` §7.
  Both shore-side warning bands leave a certified hard no-flight strip at least
  **104 nodes** wide, so neither island is reachable by flying mount from a
  continent. The hard strip and dismount behavior must also prevent
  high-altitude post-dismount drift from carrying a player onto the island.
- The two dragon islands remain boat destinations. Their complete water
  channels are immutable at every depth, and the flight classification may not
  accidentally create a bridge, tunnel or aerial-access exception.
- The obsolete ten-second mounted `Exhausted` rule and the rectangular
  legacy open-sea geometry do not govern flight in the target map.
  Swimming, boats and any later deep-ocean damage effect remain ocean-system
  concerns rather than mount movement rules.

### 4.2 Holy Grounds and housing claims

- **Both factions may summon and use either flying tier throughout the Holy
  Grounds.** The shared-front territory is an intentional aerial PvP space,
  not enemy territory. Its planned water inherits this permission because it
  is not an ocean column.
- PvP and NPC combat remain active there. Any incoming damage still dismounts
  immediately under §3.1, so permission to fly is not safety or immunity.
- Open-world housing claims add no special mount ban. They inherit the ordinary
  mount rule of their peaceful home-faction zone; a claim boundary itself never
  summons or dismounts a mount (`housing.md`; `world.md` §5).

### 4.3 Enemy territory: land tiers yes, flying tiers no

- **The two land tiers are allowed on enemy land.** A
  rider on a horse still walks the ground, still meets whatever
  `guard_level_at` has put on it (`world.md` §1), and still has to use an
  authored land connection or another physical route. Nothing about a land
  mount bypasses terrain, so nothing about it needs a rule.
- **Flying mounts are banned in enemy territory.** Two halves, both
  binding:
  - **A flying mount cannot be summoned there.** The mount action is
    refused outright with a message because a deliberate action needs no grace
    period.
  - **A rider who crosses the border while flying is dismounted after
    the existing 10-second warned grace.** Turning back cancels it; letting it
    run out sets the rider
    down where they are — on enemy ground, inside the enemy's guard
    field, on foot. WP40 must validate the Master tier's 100-node maximum
    grace travel against
    every authored border approach; no narrow zone or boundary may turn the
    grace period into delivery past the intended defenders.
- The two **land** tiers are untouched by this rule, and the two flying
  tiers (Expert, Master — §1.1) are untouched by it at home and throughout the
  Holy Grounds (§4.2).

**Why the ban exists.** `world_zones.md` makes the authored land connections
the places where faction contact, defenders and PvP objectives meet. A flying
mount is the first travel system that could ignore the roads, passes, walls and
approach terrain that make those fronts work. Without the border rule a Master
rider could cross a coast or mountain boundary and land beyond the intended
defence instead of engaging with it. `world.md` §6's ban on enemy-territory
waypoints closes the same bypass for teleportation.

**The mechanism is the central territory/zone lookup, never a hand-picked
coordinate.** The target `grug_zones.faction_at(pos)` returns `"accord"`,
`"throng"` or nil independently from `race_region`; its companion mount/ocean
classification supplies the warning and hard-flight states. Flight is refused
wherever faction lookup equals the **opposing** id of the rider's own faction
(`grug_factions.get_faction(player)`,
`mods/PLAYER/grug_factions/init.lua:20-26`; the opposing id from
`grug_core.opposing_faction`, `grug_core/init.lua:576-578`). Literal coordinates
are invalid once the authored zone graph replaces WP18. A character without a
faction cannot have bought a mount, so the nil case needs no rule of its own.

**Ocean is a separate and stricter classification.** The enemy-territory rule
does not legalize flight over neutral water: §4.1 warns and then dismounts at
every altitude. Read along a legal invasion path, the system is therefore own
land → flyable Holy Grounds → warned enemy border → forced ground travel; the
dragon islands instead require a boat because their ocean channel reaches the
hard no-flight state first.

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
  (`mods/ENTITIES/mobs/init.lua:26`). Its four public helpers are
  `mobs.attach(entity, player)` (`mount.lua:133-179`),
  `mobs.detach(player)` (`:183-198`),
  `mobs.drive(entity, moving_anim, stand_anim, can_fly, dtime)`
  (`:202-334`) and `mobs.fly(entity, dtime, speed, shoots, arrow, ...)`
  (`:338-410`); `force_detach` plus the leave/shutdown/die handlers sit
  at `:47-97`. `drive`'s `can_fly` flag and `fly` are exactly the land /
  flying split of §1.1, and the speed cap is the entity's own
  `max_speed_forward` (`mount.lua:313-316`). It **requires the
  `player_api` mod** (`mount.lua:8-16` stubs the whole API out
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
