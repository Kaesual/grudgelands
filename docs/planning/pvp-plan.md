# Round 31 — Geographic PvP plan (WP41, WP42 PvP POIs)

Status: **delivered in Round 31** (2026-10-03, local main
`699a2002`; [completion](round31-plan.md#completion-2026-10-03)). The rules
as built are [pvp.md](../design/pvp.md); the user changed some rulings during
the round ([round31-plan.md](round31-plan.md) §6 items 8–16: a refused
support cast costs nothing, equal mount boxes, the fortress spots and their
gate trails, enemy settlement icons hidden, the General's drops, PvP in the
depths from T4, camp captains as leaders and solo camp raids). Written
2026-10-03 from the design session with the user. Implementation is Round 31, orchestrated by the coordinator
session; this file is its PvP part. Other Round 31 items (the
[clean-up lane](../../BACKLOG.md#round-30-carry-overs), the dragon arena
iteration, the NPC appearance package of §6) are coordinated alongside.

The rulings below **replace** the PvP transaction of `world_zones.md` §4 and
§15 (the four-row table, automatic tagging by attacks, blocked-swing costs,
AoE snapshots) and the WP41 engineering brief
(`docs/research/wp41-engineering-brief.md`), which becomes historical. The
user's guiding rule: a server where 50 players play smoothly with simple PvP
rules beats a server that lags at 10 with perfect ones, and PvE combat must
not notice PvP at all.

## 1. Code facts this plan builds on (main `273bb8eb`)

- PvP is gated only by faction, everywhere. `grug_zones.pvp_rule_at` exists
  (`peaceful` / `contested` / nil for deep ocean and dragon channels;
  `contested` at y ≤ −701) but no combat code calls it. The six 31–40 zones,
  the four Battlegrounds zones and both islands have `faction = nil`;
  peaceful home zones and capitals carry `accord` or `throng`.
- Only skills deal damage: tokenless native punches are suppressed
  (`grug_abilities/init.lua` punchplayer handler). Every player-to-player hit
  goes through `valid_target` (`grug_abilities/init.lua`) and either the
  authoritative swing punch or `grug_core.deal_ability_damage`
  (`grug_core/combat.lua`), which also serves casts, AoE and projectiles.
- Support on other players is Heal (with splash), Shield
  and Mend (`grug_abilities/kits.lua`), gated by `valid_target("friendly")`.
  No player DoTs, pets, cleanses or buffs on others exist.
- The combat timer is 5 s (`COMBAT_TIMEOUT`, `grug_core/combat.lua`); PvP
  hits arm it. It gates food, mounting/boats, travel home and waystones.
- Guards, royal guards and kings attack enemy players everywhere and are
  attackable everywhere; guards never fight guards (`attack_npcs = false`).
  Enemy guards drop `war_trophy`/`heavy_cloth` only when an enemy player
  kills them.
- Enemy vendors, innkeepers, waystones, the Housing Steward, Claim Stones,
  riding trainer and Shipwright already refuse the other faction. Quest NPCs
  do not check faction; map and minimap show every NPC marker to everyone.
- The `pvp_tagged` / `pvp_contested` status icons are registered but unused;
  the target frame is one coloured text line; the zone banner shows only the
  zone name.

## 2. Rulings (user, 2026-10-03)

### Flag model

1. **PvP happens only between two flagged enemy players.** If either is
   unflagged, neither can harm the other. *Reason:* one boolean per player
   and one comparison per hit; no attack ever changes PvP state, so the
   combat code stays a pure check.
2. **What flags a player:**
   - **location:** standing in contested ground (`pvp_rule_at = contested`:
     the 31–60 zones, both islands, every land column at y ≤ −501 — moved
     from −701 to depth tier T4 by the user in Round 31) or in
     **enemy territory** (`faction_at` = the other faction: its start, home
     and capital zones);
   - **the button** "Flag me for PvP" in the PvP tab: flagged for 60 s from
     the press (pressing again restarts the 60 s);
   - **PvP contact** (ruling 7) keeps the flag for 60 s after the last
     contact.
   *Reason:* the only automatism is the location; everything else is a
   deliberate act.
3. **Only own peaceful territory removes the flag** (`faction_at` = own
   faction and `pvp_rule_at = peaceful`), and only once the button and
   contact timers have run out. A player who left contested ground without
   PvP contact is safe the moment they enter own peaceful land. Deep ocean
   and dragon channels change nothing: the location flag keeps its last
   value (sail out unflagged → stay unflagged; sail home from an island →
   flagged until own land). *Reason:* fleeing home does not save a real
   fighter, but nobody is punished for merely passing through.
4. **No flag modes.** No automatic flagging by attacking, healing or AoE, no
   "always on". The button is the only manual control; there is no manual
   unflag. *Reason:* the automatic mode carries the griefing (walking into a
   Ice Nova) and most of the combat-code cost; "always on" is a further
   setting for little gain.
5. **An unflagged enemy is not a valid hostile target.** The crosshair ray,
   swings, targeted casts and projectile launch treat them like no target
   (no swing, no cost); AoE skips them; casts and projectiles re-check at
   impact. *Reason:* no "blocked but paid" semantics, no knockback wrapper,
   no AoE ordering rule.
6. **Support is one-way:** an unflagged helper cannot heal, shield or Mend
   a flagged player of the own faction (including Heal's splash); a
   flagged helper may support anyone of the own faction. *Reason:* an
   unflagged player never joins a fight by accident.
7. **PvP contact** is (a) hostile damage that lands (HP lost or absorb
   consumed) between two enemy players, for **both** the dealer and the
   receiver, and (b) heal, shield or Mend cast on an own-faction player who
   is in PvP combat (ruling 8), for the helper. Effects over time count only
   at application, never per tick. Fighting guards, kings, generals or any
   NPC is **never** PvP contact. *Reason:* only real player-versus-player
   counts; one timestamp per player holds it.
8. **PvP combat = PvP contact within the last 10 s.** It sets the shared
   combat state (`grug_core.in_combat`) for 10 s; mob combat keeps its 5 s.
   *Reason:* Ice Nova plus Blink should not escape to a mount in 5 s.
9. **Logout in PvP combat while flagged is death.** The enemy players who
   dealt damage in the last 15 s get the kill immediately (statistics, death
   message "… fled the fight and fell" or similar); the character is marked
   and starts dead at the next login, respawning at the bound innkeeper.
   Disconnects count the same; a server shutdown does not. *Reason:* no
   body-in-the-world system; the engine's leave callback is no place to kill.
10. **Death clears** the button timer, the contact stamp and the location
    flag (respawn is always in own peaceful land).
11. **Flight is unchanged** (`mounts.md` §4): flying from own peaceful land
    into contested ground and back is seamless; enemy peaceful land and the
    islands dismount, with the existing warning band. Riding and boats work
    everywhere.

### NPCs, quests, map

12. **Guards, royal guards, kings and the new generals need no zone check.**
    They attack enemy players everywhere and are attackable everywhere,
    whatever the player's flag. Design keeps them out of enemy peaceful land;
    a kited guard is accepted. They give no quests (they can die).
13. **The NPC's faction decides interaction and visibility, not the place.**
    Quest givers, vendors, trainers, innkeepers, stewards and waystones serve
    only their own faction. World map and minimap show only own-faction NPC
    markers, plus the enemy kings and both dragons. Both factions can
    therefore have their own markers in the same zone (for example a spy in
    an enemy contested zone). The terrain map itself stays complete.
14. **Player kills are never quest objectives** (players may not be online).
    PvP quests target NPCs: enemy guards, captains, generals, or talk to a
    spy.
15. **PvP quests start at level 40** (`progression.md` §4 said 31).

### PvP tab

16. A **PvP tab** in the character UI holds the "Flag me for PvP" button,
    the current state (safe / flagged with the reason and remaining time)
    and **statistics only** (no rank, no titles, no rewards): player kills
    (participation), killing blows, deaths to players, enemy guards, enemy
    captains, enemy generals and enemy kings killed. Kill credit goes to
    every enemy player who landed damage on the victim in the last 15 s; the
    lethal hit's owner also gets the killing blow.

### PvP POIs (the V1 part of WP42)

17. **One fortress per faction**, in the middle 31–40 zone next to the
    middle road (Highcourt–Gor Drazhak): **Ashenward March** for the Accord,
    **Bannerbreak Mesa** for the Throng. A stone curtain wall (military
    look), exactly one gate held by 2 level-60 elite guards, at least 8 more
    level-60 elites inside, a **General** (level-65 elite, the king chassis
    without crown, with 2 level-60 elite bodyguards), a few protected quest
    givers and vendors. No flight ban over it. It is the faction's hub for
    PvP quests and a few ordinary quests (a "mini capital").
18. **Each fortress gets a waystone:** 7 waypoints per faction instead of 6.
19. **Battlegrounds camps:** 2 per faction in each of the four Battlegrounds
    zones (8 per faction, 16 total), like bandit camps but with faction
    guards and a named captain. Per zone and faction one lower and one
    higher camp (The Broken Causeway, for example: levels 41–43 and 48–50;
    51–60 zones: 51–53 and 58–60). Own-faction players find shelter there;
    the guards treat them as friends.
20. **Two camp layouts**, shared by both factions. Each camp picks one race
    of its faction (deterministically from world seed and anchor) and builds
    the layout in that race's signature materials. The fortresses always
    have stone walls.
21. **Spacing:** no two PvP POIs (fortresses and camps, either faction)
    closer than about 100–150 m; this is a minimum, not "as far apart as
    possible", so a player raiding an enemy camp may well be near one of
    their own. Kiting enemy guards to an own camp is accepted.
22. **Protection:** fortresses and camps are protected POIs with an extra
    margin of about 10 m.
23. **Quests for the POIs** ship in Round 31b (or as a small parallel lane):
    from each fortress one quest per enemy camp (kill its guards and its
    captain, area-limited to that camp) plus a few ordinary quests. Texts
    by GPT-6 Astra through the coordinator; places only as placeholders.
24. **Testing:** the user tests with two clients (one Accord, one Throng);
    headless covers the pure flag logic and one engine boot (§8).

### Coordinator defaults (veto welcome)

- **No innkeeper in the fortress:** respawn stays in peaceful land; the
  waystone is the fast way to the front.
- **Fortress vendors:** one Quartermaster (supplies and consumables shelf).
- **Camp garrison:** lower camp 4 guards + captain, higher camp 5 guards +
  captain; camp guards use the camp's race; the captain is an elite at the
  camp's top level (changed: a normal-tier leader with 1.15 × size and
  1.5 × HP, round31-plan §6 item 16). Respawn about 2 min for guards and 5 min for captains
  (place-bound slots, `world.md` §4a). Rough values, tuned in the playtest.
- **Generals** respawn like kings.
- Each PvP-POI quest counts in the front ledger (`ledger.py`); the lane
  reports before/after, no target.

## 3. What is dropped from the old design

The four-row table and tagging by attack; "blocked swing consumes cadence";
the AoE snapshot batch; synchronous zone re-evaluation per hit; the HP-pipeline
claim-token backstop; the attributable-effect registry; the NPC PvP seam; the
event bus; the knockback wrapper; the micro-bench budget and the 20-case
matrix; the forced 60 s tail on every exit from contested ground; voluntary
flagging by attack; the "Contested Territory" HUD rule for safe enemy
visitors in peaceful land (enemy land now forces the flag).

## 4. Technical shape

### `grug_pvp` (new, `mods/PLAYER/grug_pvp`)

One global table, depends on `grug_core` (with `grug_zones`) and
`grug_factions`. Per online player one small record:

| Field | Meaning | Persisted (player meta) |
|---|---|---|
| `loc` | location flag (ruling 2/3), sticky over ocean | on change and leave |
| `button_until` | absolute time, button | on press |
| `contact_at` | absolute time of the last PvP contact | on leave |
| `logout_death` | dies at next join | on leave |
| `stats` | the ruling-16 counters | on kill/death |

`flagged(p) = loc or now < button_until or now < contact_at + 60`;
`pvp_combat(p) = now < contact_at + 10`. Absolute times use `os.time()` so
offline time counts.

**Location update:** one throttled tick (about every 0.5–1 s; reuse the
`grug_map/location.lua` sampler's cadence) reads `pvp_rule_at` and
`faction_at` once per player, sets or clears `loc` and fires the HUD and
banner on changes. No zone query on the combat path. At join `loc` is
recomputed from the position (ocean keeps the stored value). A tick of lag
at a border is harmless: for that moment the player can neither hit nor be
hit.

**Public API (contract for the lanes):**

```lua
grug_pvp.flagged(player)                 -- bool
grug_pvp.can_harm(attacker, target)      -- enemy player pair: both flagged
grug_pvp.can_support(helper, target)     -- not (target flagged and helper not)
grug_pvp.contact(dealer, receiver)       -- after hostile damage landed
grug_pvp.support_contact(helper, target) -- after effective support
grug_pvp.flag_now(player)                -- the button
grug_pvp.state(player)                   -- {flagged, reason, seconds_left, pvp_combat}
grug_pvp.stats(player)                   -- read-only copy of the counters
```

`can_harm`/`can_support` are called only for player–player pairs of
opposing / equal faction; every PvE path returns before them.

### Combat wiring (two choke points)

- `valid_target` (`grug_abilities/init.lua`): hostile player targets pass
  only if `can_harm`; friendly player targets only if `can_support`. The
  crosshair ray (`grug_core/combat_ray.lua`) classifies an unflagged enemy
  as no target (neutral tint), so swings, casts, AoE loops and projectile
  launches follow automatically.
- Impact re-check: `grug_core.deal_ability_damage` asks a gate that
  `grug_pvp` installs at load (`grug_core` must not depend on `grug_pvp`);
  the swing punch handler checks `can_harm` before its damage. After landed
  damage both call `contact`.
- Support kits (Heal and splash, Shield, Mend cast) call
  `support_contact` after an effective result. Mend ticks do not.
- Combat state: PvP contact arms `grug_core`'s combat timer for 10 s
  (a per-call duration or a separate PvP constant in `combat.lua`).
- Leave handler: logout death (ruling 9); join handler: apply the pending
  death, then respawn through the existing path.

Report a before/after comparison of a PvE combat micro run and of the
location tick with many players (numbers are comparisons, no budget).

## 5. Lanes

Model routing: Claude coordinates, Opus implements and reviews (independent
review per lane), GPT-6 Astra writes quest texts and names. Agents never
push.

### Round 31a — rules, UI, faction filter

| Lane | Scope | Main files |
|---|---|---|
| **P1 core** | `grug_pvp` state, location tick, button timer, contact, 10 s PvP combat, logout death, death clear, kill credit and stats storage, combat wiring (§4) | new `mods/PLAYER/grug_pvp/`; `grug_abilities/init.lua`, `kits.lua`, `scout.lua`; `grug_core/combat.lua`, `combat_ray.lua`, `death_messages.lua`; `grug_projectiles/init.lua` (only if the ray status is not enough) |
| **P2 UI** | PvP sfinv tab (button, state, stats); status icons (`pvp_tagged` with countdown for button/contact, `pvp_contested` for location); banner subtitle on entering a flagging area ("Contested Territory — PvP enabled" / "Enemy Territory — PvP enabled"); target-frame marker for enemy players (flagged / protected) | `grug_pvp/page.lua`, `grug_pvp/hud.lua`; `grug_core/status_icons.lua`; `grug_map/location.lua`; `grug_mobs/target_frame.lua` |
| **N faction filter** | quest givers and every service NPC refuse the other faction; map and minimap markers filtered by NPC faction, exceptions enemy kings and dragons; markers carry a faction | `grug_quests/npc.lua`; `grug_mobs/start_villagers.lua`, `start_npcs.lua`; trainer/steward NPC files (audit); `grug_map/providers.lua`, `minimap.lua`, `page.lua` |

P2 works against the §4 API from the start; N is independent.

### Round 31b — PvP POIs and their quests

| Lane | Scope | Main files |
|---|---|---|
| **S structures** | fortress layout (stone walls, one gate, sockets for gate guards, inner guards, General, bodyguards, quest givers, Quartermaster, waystone pad) and two camp layouts with race-material palettes for all six races | new blueprints in `grug_mapgen/wp40/` beside the bandit-camp blueprints; `r20_poi_catalog.lua` |
| **M placement** | anchor rows for 2 fortresses and 16 camps in `simple_map.lua` (fortress beside the middle road; camps by zone and level band where the zone's level fits); a spacing check over all PvP POIs (~120 m); deterministic race pick per camp; POI protection + 10 m; the fortress `travel_waypoint` socket; 7 waypoints per faction | `grug_mapgen/wp40/source/simple_map.lua`, `world_protection.lua`, settlement/socket code; `grug_home/waypoints_core.lua`, `waypoints.lua`; map waypoint markers |
| **G garrisons** | fortress elites, General chassis (king without crown) with bodyguards, camp guards and named captains (unique names, Astra), levels per camp band, place-bound respawn slots, camp area tags for quest credit, protected fortress NPCs | `grug_mobs/guard.lua`, `bosses.lua`, `camps.lua`, `levels.lua`, mob data; `tools/r28_names` |
| **Q quests** | per faction one quest per enemy camp plus a few ordinary fortress quests, level 40+; kill objectives on enemy guard/captain roles with the camp area (validator accepts guard roles; enemy-faction check); ledger report; texts by Astra | `grug_quests/data/zones/elandor_ashenward_march*.json`, `kragmar_bannerbreak_mesa*.json`; `grug_quests/validate.lua`, `state.lua` (credit for guard kills); `tools/r28_design/validate.py`, `quest_targets.py`, `ledger.py` |

Order: S first (footprints and sockets), then M and G in parallel, Q once
G's role and camp ids are fixed (Astra texts can start from the quest
skeletons). Mapgen runs follow the test-run budget (a few engine runs of at
most ~5 min, one ~15 min region check, never the whole world).

### Docs lane (end of the round)

New `docs/design/pvp.md` with the rulings (rules, numbers, lists only);
`world_zones.md` §4/§15 shrink to geography plus a pointer, §16 notes the V1
PvP POIs; `world.md` §2c, §4 (fortress, camps), §6 (7 waypoints);
`combat_stats.md` (PvP section, 10 s PvP combat); `progression.md` §4 (PvP
quests from 40); `quests.md` (guard objectives, no player kills);
`settlements.md`, `world_map.md` (faction filter); the research brief marked
historical; BACKLOG (WP41 delivered, WP42 PvP-POI part delivered),
ROADMAP, README Current State.

### Overlap with Round 30

Round 30 (performance) touched mobs (`grug_mobs`), quest state
(`grug_quests/state.lua`), map UI (`grug_map`), spawn regions, the crafting
lookup and the crosshair (`combat_ray.lua` reuse, throttle). Lanes branch
from main after Round 30 and the Round 31 clean-up lane; P1 (crosshair/ray),
N (map, quests), G (mobs) and Q (quest state) must rebase on those changes
and keep their throttles.

## 6. NPC appearance (design package for this round)

Guards and town NPCs look identical today (one guard model per faction, all
dwarves with red hair and beard). **The coordinator agent of this round
proposes a randomization of guard and NPC appearance** to the user before a
lane starts. Constraints from the user: fortress guards each pick a random
race of their faction; guards and NPCs in race towns and capitals vary only
within that race.

## 7. Engine and data checks for the lanes

- Verify no tokenless path damages players or own-faction guards (the user
  believes the fist punch on own guards is fixed).
- Verify `faction_at`/`pvp_rule_at` values on shelf, planned water, POI
  boxes and below −701 under a capital, so the location flag follows ruling
  2/3 there.
- Keep `enable_pvp` at the engine default (true); the gate is ours.

## 8. Tests

- **Headless (minimal):** a pure-Lua test of the flag state
  (location/ocean stickiness, button, contact 60 s / 10 s, death clear,
  logout death, `can_harm`/`can_support` table) under `tools/r31_pvp/`; the
  existing combat fixtures stay green; one engine boot through
  `tools/luanti_headless.sh`; spacing check of the PvP POI anchors.
- **Admin help for the GUI test:** a privileged command to set level and
  position (or reuse `/xp give` and `/teleport`), and `/pvpstate`.

## 9. GUI test list for the user

Two Flatpak clients on one local server, one Accord and one Throng
character at level 40+ (and a low-level one for ruling 3/12 checks).

1. Own peaceful zone, both unflagged: enemy is no target (neutral
   crosshair, "protected" in the target frame); Ice Nova next to the enemy
   does nothing to them.
2. Press "Flag me for PvP": icon with countdown; still no hits until the
   other is flagged too; both flagged → hits land.
3. Walk into a contested zone: banner and contested icon; fight; walk back
   into own peaceful land right after → stays flagged for 60 s after the
   last hit. Walk out without fighting → safe at once.
4. Enter the enemy start zone or capital: flagged; enemy guards attack;
   their unflagged low-level players cannot be hit and cannot hit you.
5. Healer: unflagged priest cannot heal a flagged friend; after pressing
   the button they can, and get flagged by the contact.
6. After a PvP hit: no mount, no eating, no waystone for 10 s.
7. Log out during a fight: the other sees the kill and death message; the
   logged-out character starts dead and respawns at the innkeeper.
8. Boat from own coast stays unflagged at sea; arriving at an island flags;
   sailing home keeps the flag until own land.
9. Flight from own land into contested ground and back without dismount;
   warning and dismount at enemy peaceful land.
10. Enemy quest giver, vendor, trainer: refused; map and minimap show no
    enemy NPC markers except the enemy kings and the dragons.
11. PvP tab statistics after kills, killing blows, deaths and guard kills.
12. Fortress (31b): one gate, elites, General with bodyguards, waystone in
    the list (7 entries), flying over the wall works; enemy waystone inert.
13. Camps (31b): both factions' camps in each Battlegrounds zone, race
    materials, own guards friendly, enemy guards hostile, spacing feels
    right; captains respawn; quest credit for guards and captain.
