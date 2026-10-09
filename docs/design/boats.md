# Boats — Water Travel, Ocean Danger and the Dragon Islands

Decided 2026-08-13; revised 2026-10-02 by the WP17 travel plan
([travel-boats-waypoints-plan.md](../planning/travel-boats-waypoints-plan.md),
rulings 1–8 and the confirmed defaults of §1.1), which retired the placed,
craftable and decaying boat. Implemented in Round 29 (lane B) in
`mods/PLAYER/grug_mounts`.

Neighbouring rules: ocean classes and the Kraken's pursuit in `world.md`
§2b, the authored channel geometry and both offshore islands in
`world_zones.md` §7 and §9.4, waypoints and home travel in `world.md` §6, the
mount contract this file reuses in `mounts.md` §3, and the Kraken's
values in `biomes_mobs.md` §3.1.

## 1. A boat is a water mount

- **Boats work exactly like mounts** (ruling 1). `grug_mounts` has three
  movement modes — land, flight and **water** — and two water tiers: the
  **Boat** (tier 5) and the **Improved Boat** (tier 6). One active mount *or*
  boat per player.
- Each bought boat is **one button in the quickbar** (E; Round 44), like a
  riding tier (`mounts.md` §3); no item is handed out. Ownership is the
  per-character metadata `grug_mounts:water_tier` (highest owned boat).
  Buying the Improved Boat keeps the Boat.
- **An empty boat never exists in the world.** The button creates an
  ephemeral boat entity with the player seated in it; clicking it again
  removes it. There is no placing, pickup, decay timer, theft, ownership window or
  boat persistence. A boat has no inventory, no passenger seat and no mob or
  NPC seat.
- Another tier's button while mounted or boating **replaces** the active
  mount or boat when that tier may be summoned at that spot; otherwise the
  current one stays and the refusal is shown. The active tier's button
  dismounts or disembarks.
- A boating player cannot use abilities, casts or combat swings (the mount
  block, `mounts.md` §3).

*Rationale:* one lifecycle instead of two; no litter, no decay timer, no
theft or pickup rules and no item/entity persistence.

## 2. The Shipwright

- **One Shipwright in every capital** (ruling 4), at the shared capital stable
  beside the Riding Trainer (socket role `shipwright` in the stable design).
  He is a passive, invulnerable service NPC; he sells the two boats and
  nothing else, and buys nothing.
- **Boat from character level 15, Improved Boat from level 30 (requires the
  Boat)** (ruling 3). The Boat costs as much as Apprentice Riding (**1s5c**),
  the Improved Boat as much as Journeyman Riding (**7s**) (`economy.md` §4.2,
  Round 29 lane E4). No materials, no recipe, nothing at character
  creation.
- His dialogue uses the Riding Trainer format (`mounts.md` §1): two rows,
  each **Owned**, a **Buy <price>** button, greyed **Requires level N** or
  greyed **Learn Boat first**. A purchase result shows in the flash line and
  in the reopened dialogue. Only characters of the capital's own faction are
  served (the same check as the Riding Trainer).
- The former one-per-continent shipwright in a level-21–30 village is retired;
  the two village display hulls (Whitebridge Market Close, Whisperreed
  Landing) stay as plain scenery.

*Rationale:* players come to the capital for riding at 15 anyway, so both
travel unlocks arrive on the same trip, and no race has to cross into another
race's region for a boat. Players stay in their starting region at first and
are not nudged into travelling by owning a boat.

## 3. Summoning and leaving the water

- **Only a boat can be summoned in water, and only in water** (ruling 5;
  riding and flying mounts are refused in water and end where they enter
  it, `mounts.md` §3): the player's feet are
  in a `group:water` node — normal or river water, source or flowing. Every
  water body works: rivers, lakes, bays, shelf, deep ocean, channels. There
  are no docks; the only piers are the four island landings' (§7.1), and a
  boat needs none.
- The boat appears on the surface of that water column, centred on its water
  node, with the player seated in it. A column whose surface lies more than 16
  nodes above the player, or whose surface is closed (ice, a roof), refuses
  with a message.
- Summoning is also refused in combat (`grug_core.in_combat`) and while dead.
- **A boat that loses contact with water disappears** (ruling 8). Once per
  second each active boat checks its own node and the node below for
  `group:water`; if neither is water, the boat is removed and the rider
  disembarks where the boat was. This covers waterfalls, dug-out water and
  every other way off the water.
- **Disembarking** removes the boat and places the player on the nearest free
  land cell within 2 nodes (a dry, solid floor and two open cells above it),
  otherwise in the water at the boat's position.
- **Death, logout and server shutdown** disembark exactly as mounts dismount;
  every reconnect starts in the water or on foot, never in a boat.
- A boat is an entity, not a node: it modifies no terrain, so it is legal on
  every water surface the player can reach, including immutable deep ocean,
  the dragon channels and Battlegrounds water. Terrain protection never blocks
  a boat, and a boat never makes protected water editable.

## 4. Status display

While boating, the status icon row shows the boat icon (`mount` status,
variant `water`) with an empty caption; the Character page's Effects tab
shows the tier name and its speed ("4 nodes/s on water").

## 5. Movement

- **Boat 4 nodes/s, Improved Boat 8 nodes/s** on the water surface. Both
  numbers are the anchors of the land ladder read onto water: 4 is the
  player's own walking speed
  (`reference_projects/luanti/src/defaultsettings.cpp:520`), and 8 is the
  fast land mount of `mounts.md` §1.1, which unlocks at the same character
  level 30.
- **Speed is the boat entity's velocity, never `physics_override.speed`** —
  the same rule and the same reason as `mounts.md` §3: that field has exactly
  one owner, the `grug_core` movement aggregator.
- Steering uses the mount controls: forward and A/D strafe relative to the
  camera at full speed, reverse at 35%. The boat accelerates and brakes
  toward the requested velocity at 1.5 × its speed per second instead of
  snapping to it.
- The boat floats with its origin on the water surface and rises when it is
  below the surface. It has step height 0 and a hull box that reaches above a
  one-node bank, so it cannot drive onto land; the box is narrower than one
  node, so it fits every channel.
- Boats have no currents, fuel or docking rules.

## 6. Damage: any hit ejects the rider

- **Any incoming damage ejects the player from the boat, immediately, in PvE
  and PvP alike** — the same rule and reason as `mounts.md` §3.1: escaping
  must not become free. The boat vanishes; the player is in the water where
  the boat was. Re-summoning then waits for the five-second combat window.
- Boats have no hit points and are never sunk by damage; a hit only ejects.
- **Implementation seam:** mobs_redo punches what the player is attached to
  (`local target = self.attack:get_attach() or self.attack`), so a mob's melee
  swing lands on the boat entity. The eject therefore uses **two** hooks, the
  mount pattern: the boat entity's `on_punch` forwards the punch to the rider,
  and the player HP-change observer ejects on any HP loss.
- Deep-ocean and channel columns neither flag nor clear PvP: a player keeps
  the location flag they had (sail out unflagged, stay unflagged;
  [pvp.md](pvp.md) §2).

## 7. Ocean danger and the dragon islands

The water classes, the Kraken's pursuit rules and the dragon channels
are owned by `world.md` §2b. What matters for a boat:

- **The dragon islands are reachable by boat only** (ruling 2). Flying mounts
  stay forbidden over every ocean column, including the dragon channels, and
  on both islands (`mounts.md` §4.1/§4.2).
- **Deep ocean is not survivable in a boat.** The Kraken swims 10
  nodes/s inside deep-ocean columns, above the Improved Boat's 8, with a view
  range of 40 (ruling 7); one hit ejects the rider into deep water.
- **The coastal shelf and the dragon channels are safe boat water.** No
  Kraken spawns there, and a Kraken outside deep ocean drops its target
  and holds position, so it never pursues a boat beyond the deep-ocean edge.
- Both approaches to either island (`world_zones.md` §7.4) are required boat
  routes; a crossing is about 390–420 nodes, roughly 100 s by Boat and 50 s by
  Improved Boat. Because the shelf follows the entire mainland perimeter, a
  low-level character may coast to a channel mouth and visit an island; the
  level-60 island itself is the gate.

### 7.1 Island landings: pier and beach

Decided by the user 2026-10-02 (Round 30 plan §3, first version by feel);
built by the mapgen (`height.lua` the beach, `road_writer.lua` the pier).
Each of the four boat landings (`source/simple_map.lua`
`source.island_landings`) gets a wooden pier and a small sand beach, so a
player can step ashore from a boat. No waystone, shipwright or NPC.

- **Shore point:** the last land column on the boat line, walking from the
  landing's fixed point toward the mainland until the first sea column. The
  beach and the pier both start there, so they meet on every seed.
- **Beach:** a sand crescent cut into the shore, 12 nodes either side of the
  boat line along the coast and 11 nodes inland (measured as the distance to
  the sea, so it follows the coast), its edge moved by noise. Its ground
  rises from the water line (y 1) to y 3; an 8-node collar blends it into the
  natural terrain. It is sand up to y 3 although the islands are mountain
  land (the one exception to the near-water material rule,
  `world_zones.md` §7.4). Natural river or lake columns and their banks keep
  their ground.
- **Pier:** plain planks of the island zone's wood (Wyrmglass pine,
  Stormscale jungle wood; default planks for a zone without a race), 2 nodes
  wide, the deck at y 2 (one node above the water), 10 nodes out over the
  water toward the mainland and 2 back onto the beach's water line. At 10,
  7, 4 and 1 nodes out a row of trunk posts stands on the floor: under the
  deck up to the water surface, beside it up to the deck with a fence post
  on top. A boat disembarks its rider onto the deck (§3).
- The pier head stands in the shore water the terrain gives (2–4 nodes deep
  on the checked seeds); the boat water of §7 and its nine-node floor
  further out are unchanged, as are the channels and the boat paths.
- Behind the beach the island rises as its natural terrain does (on most
  seeds a steep mountain flank, 150–450 nodes high). **The dragon islands
  get no mapgen paths or roads, by design** (user 2026-10-02): they are
  untamed land, and the climb is part of reaching the dragon. The pier and
  the beach are the only authored structures. (The road router could not
  have laid a trail anyway: from the beaches to the island POIs its trails
  lost their beach end or failed on the checked seeds.)
