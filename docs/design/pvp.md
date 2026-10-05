# PvP

Geographic PvP (WP41) and the V1 PvP points of interest (the PvP part of
WP42), as built in Round 31. Decided by the user on 2026-10-03
([pvp-plan.md](../planning/pvp-plan.md) rulings 1–24 and its coordinator
defaults, changed during the round by
[round31-plan.md](../planning/round31-plan.md) §6 items 8–16). This file
replaces the PvP transaction of the former `world_zones.md` §4 and §15.

Guiding rule (user): a server where 50 players play smoothly with simple PvP
rules beats one that lags at 10 with perfect ones, and PvE combat must not
notice PvP at all. Code: `mods/PLAYER/grug_pvp` (pure rules in
`rules.lua`); seams in [combat_stats.md](combat_stats.md) §2 "PvP
eligibility and flag".

## 1. Geography

| Ground | `pvp_rule_at` | Effect on the location flag |
|---|---|---|
| A faction's level-1–30 zones and its three capitals (its territory) | peaceful | own faction: clears it; the other faction: flags it ("Enemy Territory") |
| Every level-31–60 zone (the six contested approaches, the four Battlegrounds zones, Ashenward March and Bannerbreak Mesa included) and both dragon islands | contested | flags it ("Contested Territory") |
| Every non-ocean land column at **y = −501 and below** (depth tier T4 and deeper), under any surface zone | contested | flags it |
| Deep ocean and the dragon channels | neither | keeps the last value |

- **Depth (round31-plan §6 item 15):** under peaceful land the tiers T1–T3
  (down to y = −500) behave like the surface above: the owners stay
  unflagged, a visitor of the other faction is flagged by enemy territory,
  and the other faction may not dig or build. From T4
  (`CONTESTED_DEPTH_Y = −501`, `grug_mapgen/wp40/zones.lua`) every player is
  flagged by location and every player may dig and place blocks
  ([world.md](world.md) §4c).
- Enemy territory is the other faction's start, home and capital zones
  (`grug_zones.faction_at`).

## 2. The flag

- **PvP happens only between two flagged enemy players.** If either is
  unflagged, neither can harm the other.
- A player is **flagged** while any of these holds:
  - **location:** standing on contested ground or in enemy territory (§1);
  - **the button** "Flag me for PvP" (PvP tab): 60 s from the press; a
    second press restarts the 60 s;
  - **PvP contact** (§3): 60 s after the last contact.
- **Only own peaceful territory clears the location flag**, and the player
  is safe there once the button and contact timers have run out. Deep ocean
  and the dragon channels keep the last value (sail out unflagged → stay
  unflagged; sail home from an island → flagged until own land).
- No flag modes: no flag by attacking, healing or area effects, no "always
  on", no manual unflag.
- **Death clears** the button timer, the contact time and the location flag
  (respawn is always in own peaceful land).
- The location is sampled **once a second** per player (never on the combat
  path); at join it is recomputed from the position (ocean keeps the stored
  value). Timers are absolute times (`os.time()`), so offline time counts.
  Stored in player meta: the location flag, the button and contact times,
  a pending logout death and the counters (§5).

## 3. Combat

- **An unflagged enemy is no valid hostile target:** the crosshair shows
  neutral (reason `protected`) and the enemy blocks the ray like a friendly
  player; no swing, no cast and no cost; area effects skip them; casts and
  projectiles re-check at impact.
- **Support is one-way:** an unflagged helper cannot Heal, Shield or Mend a
  flagged ally (Heal's splash included); such a cast is refused with "You
  must be flagged for PvP to support a flagged ally." and costs nothing (no
  self-cast). A flagged helper may support anyone of the own faction; aiming
  at no ally still casts on oneself.
- **PvP contact** is (a) hostile damage that lands between two enemy players
  (HP lost or absorb consumed), for both dealer and receiver, and (b) an
  effective Heal, Shield or Mend cast on an own-faction player who is in PvP
  combat, for the helper. Effects over time count only at application (Mend
  ticks never do). Fighting guards, kings, Generals, captains or any other
  NPC is **never** PvP contact, nor are environmental, arena hazard or
  dragon's-wrath damage.
- **PvP combat** = PvP contact within the last **10 s**. It sets the shared
  combat state for 10 s (`PVP_COMBAT_TIMEOUT`; mob combat keeps its rules),
  which blocks mounting and boats, food, travel home and waystones.
- **Logout in PvP combat while flagged is death.** The enemy players who
  landed damage in the last 15 s and are online get the kill at once, with
  the death message "… fled the fight and fell."; the character starts dead
  at the next login and respawns at the bound innkeeper. A disconnect counts
  the same; a server shutdown does not.
- **Kill credit:** every online enemy player who landed damage on the victim
  in the last 15 s gets a player kill; the owner of the lethal hit also gets
  the killing blow (a logout death has none).
- **Flight is unchanged** ([mounts.md](mounts.md) §4): own peaceful land to
  contested ground and back is seamless; enemy peaceful land and the islands
  dismount with the existing warning band. Riding and boats work everywhere.

## 4. NPCs and the map

- **Guards, royal guards, kings, the Generals, their bodyguards and the camp
  captains need no zone check:** they attack enemy players everywhere and are
  attackable everywhere, whatever the player's flag. Design keeps them out
  of enemy peaceful land; a kited guard is accepted. They give no quests.
- **The NPC's faction decides service, not the place:** quest givers,
  vendors, profession and riding trainers, the Shipwright, innkeepers,
  Housing Stewards, Crownbinders and waystones serve only their own faction; everyone else
  hears "<NPC> I serve only The Accord." (or The Throng), at most once every
  two seconds ([settlements.md](settlements.md)).
- **Map and minimap** show only the own faction's NPC markers, plus every
  king and both dragons. Settlement icons: the enemy's starts, capitals,
  villages, outposts and fortress are hidden; the Battlegrounds war camps
  (quest targets) and neutral places stay visible to everyone; the terrain
  map itself is the same for both factions ([world_map.md](world_map.md)).
- Enemy guards drop War Trophies and heavy cloth only to an enemy player's
  kill (`grug_mobs/guard.lua`).

## 5. Interface

- **PvP tab** (Character UI, right after Group): the "Flag me for PvP"
  button; the state — "Safe", "Flagged: Contested Territory", "Flagged:
  Enemy Territory" or "Flagged for N s" (button or contact) — with one
  explanatory line; "In PvP combat: no mount, food or travel." while it
  runs; and **statistics only** (no rank, title or reward):

  | Counter | Counts |
  |---|---|
  | Player kills | participation (§3 kill credit) |
  | Killing blows | the lethal hit |
  | Deaths to players | a death that credited at least one enemy player, logout deaths included |
  | Enemy guards killed | faction guards, royal guards, the Generals' bodyguards |
  | Enemy captains killed | Battlegrounds camp captains and the two war commanders |
  | Enemy generals killed | the two fortress Generals |
  | Enemy kings killed | the six kings |

  The open tab is re-sent once a second only while its text changes.
- **Status icons** ([inventory_equipment.md](inventory_equipment.md)):
  `pvp_contested` ("Contested Territory" or "Enemy Territory", untimed)
  while the location flags the player; `pvp_tagged` ("PvP flagged") with
  the countdown while the button or contact does.
- **Zone banner territory line** (Round 32, replacing the Round 31
  subtitle): the territory at the player's position, from §1's rule and
  never from the flag ([world_map.md](world_map.md), "Zone and town
  names"): "Friendly Territory" in green, "Contested Territory (PvP)" in
  yellow (contested zones and every land column from y −501), "Enemy
  Territory (PvP)" in red, under the zone name in the same colour; the
  minimap's location line takes the colour too. A player flagged by the
  button in own land still reads "Friendly Territory".
- **Target frame:** an enemy player's line shows "(flagged)" or
  "(protected)" from their own flag; it is red only while both can fight,
  else grey.
- Admin: `/pvpstate [<player>]` (privilege `server`) shows the flag, timers
  and counters.

## 6. PvP points of interest

One fortress per faction and 16 Battlegrounds camps, fixed anchors 101–118
on every seed (positions, placement priorities, spacing and protection:
[world_zones.md](world_zones.md) §16; garrison and respawn rules:
[world.md](world.md) §4). All are protected POIs with a 10-node margin,
refuse ambient hostile spawns and nudge idle roaming mobs away (a mob in
combat may follow its target in).

### 6.1 Fortresses

| | Accord | Throng |
|---|---|---|
| Name | Ashenward Bastion | Bannerbreak Warhold |
| Zone, position | Ashenward March, (136, −488) | Bannerbreak Mesa, (−80, 632) |
| General | General Haldren Ashward | General Grask Oathscar |
| Seat race (registry, General's look) | human | orc |

- **Layout** (49 × 49): a two-node stone curtain wall six high with towers,
  **exactly one gate**, a keep, barracks, the Quartermaster's store, an
  armoury, a drill yard and the waystone pad; faction stone, the seat race's
  timber inside. A 3-wide trail leaves through the gate to the middle road.
  No flight ban over it.
- **Garrison:** 2 gate and 10 inner guards, level-60 elites, each rolling a
  race of the faction (a mixed garrison); the **General** (level-65 elite,
  the seat race's king chassis and kit without the crown, a fixed look in
  the royal tabard, his weapon in the seat king's enchant colours) with
  **2 bodyguards** (level-60 elites, royal-guard rules). Guards respawn after
  3–6 min; the General's group returns like a king's (15 min of wall-clock
  time after the General's death).
- **Services:** three protected quest givers (Warmaster, Drillmaster,
  Outrider), one Quartermaster (the faction's general vendor), the
  **waystone** — the faction's seventh ([world.md](world.md) §6). No
  innkeeper: respawn stays in peaceful land. An enemy fortress's waystone is
  inert.
- **The General's drops:** his War Trophies and, on an enemy player's kill,
  a boss's two gear items at item level 65, each blue or gold at even odds
  (Round 33, [items_crafting.md](items_crafting.md) §5.1).
  His bodyguards drop no gear.

### 6.2 Battlegrounds camps

- **Per Battlegrounds zone and faction** one lower camp ("<zone> <Faction>
  Picket", 23 × 23) and one higher camp ("… War Camp", 27 × 27, with
  watchtowers): palisade, faction-cloth tents, a command tent and a shelter,
  gate toward the own continent. 8 camps per faction, 16 in total.
- **Race:** each camp rolls one race of its faction per world (SHA-256 of
  the world seed and the anchor number) and builds in that race's signature
  materials; its garrison is of that race.
- **Levels** from the zone's range: lower camp the bottom three levels,
  higher camp the top three (the 41–50 zones, The Broken Causeway and The
  Shattered Line: 41–43 and 48–50; the 51–60 zones, Gravesalt Escarpment
  and The Skyglass Canopy: 51–53 and 58–60).
- **Garrison:** 4 (lower) or 5 (higher) faction guards at the camp's levels,
  never elite, respawning after 100–140 s; one **named captain** at the
  band's top level, a normal-tier leader with the start-zone leaders'
  factors (1.15 × size, 1.5 × HP), respawning after 270–330 s. 48 captain
  names (one per camp and possible race) and the two Generals are by GPT-6
  Astra (`grug_mobs/data/pvp_names.json`).
- **War commanders** (Round 36, round36-plan.md §2.3): the Throng War Camp of
  Gravesalt Escarpment and the Accord War Camp of The Skyglass Canopy, and
  only these two, also hold a **named war commander**: a level-60 elite with
  the leaders' factors (1.15 × size, 1.5 × HP on top of the elite's), the
  guard chassis, respawning after 270–330 s like a captain and counted as a
  captain on the PvP tab. He has no authored socket: he stands five nodes
  beside the captain, across from the camp's west yard post. He is the main
  line's optional group fight in that camp; the captain stays its solo
  target. His name lives in `pvp_names.json` (`commanders`; working names
  until the story bible names them).
- Own-faction players find shelter: the guards treat them as friends; enemy
  guards are hostile. Kiting enemy guards to an own camp is accepted.

## 7. Quests

- **Player kills are never quest objectives** (players may be offline); PvP
  quests target enemy garrisons: guards, captains and the two war
  commanders within a camp's area.
- **PvP quests start at level 40** ([progression.md](progression.md) §4).
- Per faction 12 fortress quests: one **solo** raid per enemy camp (8: the
  camp's guards and captain), three ordinary fortress quests and one entry
  quest from an outpost of the fortress's zone
  ([quests.md](quests.md#pvp-fortress-quests-round-31)).

## 8. Not built

Dropped with the Round 31 rules (pvp-plan §3): the four-row peaceful
transaction and tagging by attack, the blocked-swing cadence cost, the AoE
snapshot, synchronous zone checks per hit, the forced 60 s tail on leaving
contested ground and the "Contested Territory" rule for safe enemy visitors.
The scripted war-front battles of [world_zones.md](world_zones.md) §16 stay
after V1 (WP42).
