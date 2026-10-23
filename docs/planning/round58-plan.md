# Round 58 — the Miner's Guild and the town fixes (0.58.0, map reset)

Coordinator: Claude, 2026-10-23. Status: **planned**, waiting for the user's go (after a compaction). The plan
review (a fresh Opus, 2026-10-23, `r58/reports/plan-review.md`) is folded in; its blocker is decided (§2a).

Round 58 is the **one map reset** of this stretch. Its rulings were decided with the user on 2026-10-22 and
2026-10-23 and stand in [Round 57 plan §8](round57-plan.md#8-decided-for-round-58); this plan turns them into lanes.
The user accepts Rounds 57 and 58 together in one GUI test after this round (2026-10-23). Start state: main
`69481ed1` (0.57.0), pushed.

Inputs beside §8:
- the picked guild art (`~/projects/grudgelands-orchestration/guild-art/pick/picks.md`): the cloaks of drop 01 P1,
  the consumable icons and status icons of P2, the Miner's Remains overlay of P1;
- the story-arc decision (Round 57, private draft `r57/reports/storyarc2-report.md`): the guilds are **The Charter
  of Stone** (The Accord) and **The Oathdelvers** (The Throng), loyal allies of their faction's military; the user
  interface says "Miner's Guild"; three equal leaders per guild, one per capital; foremen carry the role title
  "Foreman", only story-relevant ones are named; the foremen's follow-up quests carry one small seed per tier (§5
  of the draft);
- ruling 28 of Round 57: no vendor sells leather, cloth, ores or bars, so reputation cannot be bought with copper.

## 1. Lanes and waves

| Wave | Lane | Who | Goal (one line) | Waits for |
|---|---|---|---|---|
| 0 | GUILDSPEC | Opus | The guild's design doc and every number (ranks, exchange rates, prices, effect parameters, Remains loot), with a tuning page for the user | the user's go |
| 0 | CAMPS | Opus | The 20 new mining camps, the 16 war camps as mining camps, the 6 enemy camps under construction: anchors, blueprints, protection, map icons | the user's go |
| 0 | ROOMS | Opus | The 148 lift rooms at the tier depths: their own generation step, liquid-safe, protected, no spawns | the user's go |
| 0 | HALLS | Opus | The Miner's Guild house in the six capitals (a building template) | the user's go |
| 0 | TOWNFIX | Opus | The Round 56 town fixes (bough platforms, gatehouses, royal guards, gate patrols, terrace stair, start-town waystone) | the user's go |
| 0 | LIFTART | Astra | Art the picks do not cover yet: the lift, the two guild emblems/banners, a reputation icon | the user's go |
| 1 | REP | Opus | Reputation (lifetime rank and balance), trade-in at camps and halls, the achievement series with the picked cloaks | GUILDSPEC's contract; HALLS' socket names |
| 1 | LIFT | Opus | The teleport lift between a camp's surface and its rooms, faction-only | CAMPS + ROOMS merged |
| 1 | CAMPNPC | Opus | The 36 foremen (one role per tier), the guild leaders and the hall's exchange counter, the camp vendor (buys, rep trade, repair, the rank-gated page) | GUILDSPEC's contract, CAMPS and HALLS merged |
| 1 | CONSUME | Opus | Ore Sense and Treasure Hunt (12 items), their own status slot that survives logout and death, the Miner's Remains block | GUILDSPEC's contract |
| 2 | GUILDQUESTS | Opus | Gather quests per depth tier, the one follow-up per tier, camp kill quests, the raid on camps under construction; placeholder texts | CAMPNPC, REP and HALLS merged |
| 3 | GUILDTEXT | Astra | The texts of the guild and camp quests | the user's QUESTMAP verdict |
| 3 | TEXTREVIEW | Opus | Text review with a suggestion page; the user picks | GUILDTEXT |
| 4 | D | Opus | Docs, CHANGELOG, version 0.58.0 with the map-reset declaration, STATUS, the joint GUI checklist of 0.57 and 0.58, a full seed fleet | everything else |

Wave 1 starts on GUILDSPEC's accepted **contract** (format, API, saved keys); the numbers live in the catalogue and
drop in when the user accepts them. GUILDSPEC's branch carries the `grug_guild` **skeleton** (mod folder, catalogue
file, stub API in one file per owning lane), merged with the contract, so the parallel lanes never each create the
mod. *Changed at brief time (coordinator, 2026-10-23):* the lift and room nodes are grug_mapgen nodes, because the
world writer needs them in wave 0: CAMPS registers `grug_mapgen:guild_lift` (a placeholder; LIFT overrides it from
`grug_guild`), ROOMS the room fill, floor, lamp and the mantles `grug_mapgen:room_mantle_t1` … `_t6`. CAMPS' brief fixes the camp
socket ids, roles and kinds (the foreman's quest socket, the camp vendor kind, the lift socket) as the contract
CAMPNPC reads; HALLS' brief fixes the hall's sockets the same way. The lift, emblem and banner nodes ship with
placeholders until the LIFTART pick; LIFT swaps in the picked textures (texture-only).

Every non-trivial code lane gets an independent Opus review and a delta review for every logic fix. Art and sound
ship only after the user's pick (LIFTART ends on a pick page; the picked GUILDART files ship with REP, CONSUME and
CAMPS). Mapgen lanes keep to the mapgen test budget (a few engine runs, ≤ ~5 min each, a closing run over a chosen
region; never the whole world).

## 2. The rulings

The rulings are those of Round 57 §8, unchanged. In short:
- **One guild per faction**, an essential political actor, a Miner's Guild house with NPCs in each of the six
  capitals.
- **Camps:**
  - 20 new camps, one in every T2, T3 and T4 zone outside the capital zones (6 T2, 8 T3, 6 T4), placed per seed in
    the part of the zone whose level fits;
  - a T4 camp in a contested zone belongs to the faction whose half of the continent it lies on;
  - the 16 Battlegrounds war camps become mining camps too (zones 35/36 are T5, 34/37 T6), guarded by faction guards and still the target of the
    enemy's raid quests;
  - one enemy "camp under construction" in each own contested T4 zone: guards and a captain, no lift, nothing of
    use to the enemy; the foreman of the own T4 camp gives the quest against it;
  - each camp has a foreman (quest giver) and a vendor who buys like every vendor, trades mining materials for
    reputation, repairs, and sells only reputation goods (one page, all consumables in 6 rows, each row "Reach
    Reputation Rank N" until reached; no torches or ladders).
- **Lifts and rooms:**
  - one lift point per tier depth from T1 down to the camp's zone tier (a T2 camp has two, a T6 war camp six; 148
    rooms over 36 camps);
  - a teleport lift with no shaft, for members of the camp's faction only; it connects the surface with every
    level of its camp (coordinator default);
  - rooms at the tier's lowest y + 50: −50, −250, −450, −650, −950; T6 at −1050 (coordinator default);
  - written by the world generator, never stamped at first use;
  - protected, without guards and without mob spawns; enemy players may enter but not use the lift;
  - safe from water and lava: a mantle with its liquids replaced, exits ending blind in rock, an invisible fill
    that players walk through and liquids cannot enter (`walkable = false`, `floodable = false`,
    `buildable_to = false`, `is_ground_content = false`); the planned lava-lake pass spares the rooms.
- **Quests:**
  - guild gather quests are bound to the depth, not the camp: one quest id per tier (T2–T6) for both factions with a
    text per guild, taken and turned in only at own-faction camps; every own camp whose deepest lift reaches the
    tier offers it until done (a missed T2 quest is offered in a T3 camp too); 1–2 gather quests per tier;
  - when both gather quests of a tier are done, the foreman may give one follow-up ("tell the guild in the
    capital"), carrying the guild's small storyline (one seed per tier, story-arc draft §5);
  - no T1 mining quest;
  - each camp has 1–2 kill quests on mobs near the camp (day or night spawns; "at night" may be literal);
  - all of a camp's quests can be taken at once; no chains beyond the one follow-up; no kill objectives in the
    depth; no repeatable quests.
- **Reputation:**
  - a currency the player does not carry, one value per player at every guild NPC of their faction;
  - materials are traded for it at the guild houses and the camp vendors (a mechanism, not a repeatable quest);
  - two numbers: the lifetime total (the rank) and the spendable balance; spending never lowers the rank;
  - ranks 0–10, the last ones hard to reach; ranks 1–6 unlock buying the T1–T6 consumables;
  - an achievement series "Reach Reputation Rank 3/6/10 with the Miner's Guild" with three cloaks (rank 10
    winged; the picked art);
  - exchange rates by material, stone and sand very low; selling to vendors for copper stays possible.
- **Consumables:**
  - Ore Sense: every 60–120 s it marks one ore deposit of its tier in range for 5 s, visible to the user only;
  - Treasure Hunt: it places one hidden block in solid rock (no air within 1, never in a protected area), marked
    for the user while in range; the block removes itself when the user goes too far (so nothing stays after a
    crash or logout); others may mine it, without a marker;
  - each has a fixed tier and works only in its depth: 12 items; expensive;
  - rank gates buying; level gates use (1 for T1, 11 for T2, …, 51 for T6); tradeable and storable;
  - their own effect slot (not the elixir's), only one of the two active at a time;
  - the effect continues across logout and death (it saves its remaining time);
  - Miner's Remains give copper and materials, worth more deeper; a material obtainable only this way waits for the
    unique items (Round 57 §9).
- **Towns** (Round 56 §8): the Lethariel bough platforms and the five core gatehouses (templates); Lethariel's
  royal guards on posts by the king; the gate guards' two patrols and the tower post; the terrace stair's
  off-by-one; the waystone and mailbox at each start town's centre.

## 2a. Decided after the plan review: no copper route into reputation (the user, 2026-10-23)

The review found that copper still bought reputation through stone: the exchange takes stone at a very low rate,
every tier stone mines as cobble, and the mason sold cobble (2c) and gravel (1c) (`grug_traders/stock.lua:257-264`).
The user chose option (a):
- **the mason stops selling cobble and gravel** (an extension of Round 57 ruling 28; REP removes them from the
  shelf, buy-back unchanged);
- **the exchange takes only items that no vendor sells**; bricks, blocks and other made goods are not exchanged.

GUILDSPEC adds the fixture: no exchange item has a vendor source (Round 57's source index `grug_jobs/sources.lua`
lists vendor sources).

## 3. Shared conventions

- **Upgrade classification: map reset** (one `map_reset` entry for 0.58.0 in `tools/web_data/upgrade.json`, made by
  D; `check_upgrade.py` must then pass). Every lane says in its report what of its change needs the reset and what
  would also be compatible.
  - Saved state carried over a map reset: characters keep their items, levels, quests and money (the contract's
    map-reset row). Reputation starts at 0 for everybody; the new keys are created on first use.
  - Any new **position in player meta** (a lift return point, a Treasure Hunt block) is map-bound: it gets a
    `register_on_relocate` clear, tested in `tools/r41_up` (upgrade contract §3.4).
- **A new mod `grug_guild`** holds the guild's own state and logic (reputation, the catalogue of consumables and
  exchange rates, the effect); GUILDSPEC fixes its data format and public functions as the contract for REP,
  CAMPNPC and CONSUME. Mapgen stays in `grug_mapgen`, NPC spawning in `grug_mobs`, the vendor window in
  `grug_traders`, quests in `grug_quests`.
- **Numbers are proposals until the user accepts them** on GUILDSPEC's tuning page; they are rough targets, not
  hard gates (the user's rule). Code reads them from the catalogue, never from literals in several places.
- **One camp-and-room module, owned by CAMPS:** a pure, deterministic module loaded in the main env and in the
  mapgen env. Per camp it returns the id, faction, race, zone tier, anchor, lift socket and the room boxes (floor y,
  arrival point, the room's lift cell). Camp positions come from the placement search, which is serialized into
  `placement_layout` and already reaches the mapgen env (`r7_mapgen.lua:72-75`, `r7_loader.lua:346-354`), so the
  rooms need no new IPC field. ROOMS writes from it; LIFT, CAMPNPC and the map read from it; LIFT finds its camp
  from the clicked position (the surface socket or a room box). No saved camp state.
- **Faction and territory:** below y −501 every column is contested land today; the rooms are protected by their own
  y-bounded boxes regardless.
- **Quest texts** follow the Round 57 rules (placeholders for places and directions, items by name, no tooltip
  text, no existing game, The Accord and The Throng); the guild's proper names appear in texts and on buildings.
- **Fixtures:** `tools/r58_<lane>/portable_test.lua`; mapgen lanes add their check to the seed fleet where the
  fleet already checks POIs.

## 4. Lane goals (briefs add file facts)

**GUILDSPEC.** `docs/design/miners_guild.md`: the system as one spec (guilds, camps, lifts, rooms, reputation,
vendor, consumables, Remains, quests), with the numbers:
- the rank thresholds 1–10 (the last ones hard), the exchange rate per material (stone and sand very low; by tier
  and rarity), the consumable prices in reputation (expensive), Ore Sense's range and timing, Treasure Hunt's range
  and the distance that removes the block, the Remains' loot per tier;
- derived from data that exists (the ore densities, `world_zones.md` and the Round 49 ore census; the vendors'
  copper values and income per band, `economy.md`, `income.py`), and a **model** of mining yield per hour built
  from tool dig times with stated assumptions (no measured yield exists), each number with its reason;
- the `grug_guild` data format and public functions (the contract), the reputation's saved keys;
- a **tuning page** for the user (an artifact with the numbers, their effect in hours of mining per rank, and a
  place to change them); the accepted numbers go into the catalogue.

**CAMPS** (mapgen, map reset).
- Anchor rows and placement rules for the 20 camps (zone list: T2 Accord 2, 7, 12, Throng 18, 23, 28; T3 Accord 4,
  9, 14, 15, Throng 20, 25, 30, 31; T4 contested Elandor 5, 10, 16 and Kragmar 21, 26, 32 by continent half), in the
  level-fitting part of the zone (the zone-thirds level rule), spaced from towns, POIs and the war camps.
- The 6 enemy camps under construction (one per own contested T4 zone: the Accord-side T4 zones get a Throng camp,
  the Throng-side ones an Accord camp), with guards and a captain from the PvP garrison machinery, no lift, no
  vendor.
- Blueprints: a mining camp (foreman and vendor sockets, the lift point, a mining look), the camp under
  construction (scaffolding, guard and captain sockets), and the 16 war camps extended with a foreman, a vendor
  and a lift point without changing their raid role.
- Everything that counts or classifies settlements: protection kinds (`world_protection.lua`), map icons
  (`settlement_icons.lua`), spawn refusals (`spawn_policy.lua`). Camps get **no activation node** (no banner or
  fire), garrisoned on sockets like the war camps, so the overlay's roster (42 rows, 36 columns,
  `r7_zone_overlay.lua:13,30`) stays unchanged.
- **The camp-and-room module** (§3) and the camp socket contract (the foreman's quest socket, the vendor kind, the
  lift socket).
- If it grows too big, the six camps under construction (catalogue rows, garrison, raid target) become a second
  CAMPS phase.
- The fleet check that every seed places all 42 camps.

**ROOMS** (mapgen, map reset).
- A room per lift point (148), at the depths of §2, from CAMPS' camp-and-room module, written by its **own step
  after the writer and outside `refine_or_degrade`** (`r7_mapgen.lua:109-117`), with its own degrade, so a writer
  veto never drops a room; each chunk writes the part of a room inside its minp..maxp. The −50 room is safe with
  the writer (its runs start at `AUTHORED_FLOOR` −37; a veto applies only to cells the writer touches).
- The mantle, floor and fill are **non-ground-content, mandatory** (neighbouring chunks' caves and dungeons reach
  about 14–16 nodes past a chunk edge, also sideways, and spare only non-ground-content nodes; the −50 and −450
  rooms sit inside that reach of their chunk top).
- `calc_lighting` on the room box and light sources in the room (early-out chunks never run the writer); a defined
  floor y. Rooms at −650 and below are PvP ground (contested below −501): an enemy tunnelling in flags both, as
  anywhere there.
- The fill node (walkable false, floodable false, buildable_to false, is_ground_content false, light passing),
  liquids in the mantle replaced, exits ending blind.
- A y-bounded protection box per room answering `hard_protection_kind_at`, as a separate wrapper beside the zone
  overlay (or a schema bump of the overlay together with `r7_manifest.lua:609-615,687-690` and
  `tools/r24_protection_depth/fixture.lua:654`); the depth pulse and the **ambient underground spawns** (which have
  no protection check today) refuse the rooms.
- The fill node on `grug_mobs:rift_void`'s model minus its liquid physics, damage and tint (airlike,
  `pointable = false`, `diggable = false`), so the travel path's `passable()` accepts it and players dig past the
  exits.
- A fixture over room positions per seed and an engine run that generates a few rooms with water and lava nearby.

**HALLS** (template, map reset).
- A Miner's Guild house in each of the six capitals as a building template (format §1–§4), placed by a district
  plot row or the civic core; a leader socket (the story's leader of that capital), an exchange counter socket (the
  guild's vendor) and room for a few residents.
- Each guild's look follows its faction's capital palette; the user sees the six houses in the town viewer before
  the lane merges.
- Capital plans vary per seed, so HALLS runs `seed_fleet quick` (TOWNFIX too where a footprint changes). The first
  deliberate template edit retires `tools/building_templates/export.py --check` (AGENTS "World generation"): HALLS
  retires it and says so; D updates AGENTS.

**TOWNFIX** (templates and code, map reset).
- Lethariel's bough platforms: the beam over the stair (deck 6) and the rail in front of the hall door (both
  platforms) go.
- The five core gatehouses (all but Kezamba): the inner stair in the right chamber with a landing, the doors one node
  towards the passage with their idle posts, the deck opening from 3 to 4 nodes, the two first-floor wall openings
  closed.
- Lethariel's royal guards: posts beside the king, at most 5 m away, no free wander (in code: the post fields and
  `_grug_no_wander`).
- The gate guards: two counter-rotating rectangle patrols on the city side, the tower guard a post.
- The terrace stair's missing tread (`dressing.lua`, Silverleaf's two terrace houses).
- The waystone and mailbox at each start town's centre next to the Quartermaster (the pad, the travel waypoint
  socket, the mailbox naming and the home waypoint follow).

**LIFTART (Astra).** Design goals and every element: the lift point (a winch or platform the player clicks, readable
at camp distance, one look per faction or one shared), the two guild emblems for banners and signs (The Charter of
Stone, The Oathdelvers), and a small reputation icon for the vendor page and the HUD. Two proposals each, a pick
page; the icon rules hold (simple, readable at 32 and 16 px).

**REP.** The mason's cobble and gravel leave the shelf (§2a). The reputation store (lifetime and balance per player and guild), the rank by thresholds, the trade-in
(materials for reputation) at the guild houses and the camp vendors with the catalogue's rates, the achievement
counter and series with the three picked cloaks, a display of rank and balance (the vendor page and the character
sheet). Selling the same materials for copper stays possible.

**LIFT.** The lift point's interaction: a list of the camp's levels, own faction only (enemies may stand in a room
but cannot use the lift), teleport through `grug_home`'s travel path (emerge, safe arrival), cooldown and combat
rules as the waystones have them, and the room's return point.

**CAMPNPC.**
- **The 36 foremen registered in code** (the Battlegrounds zones 34–37 have no quest files; fortress givers are the
  precedent, `npcs.lua:88-101`), each with a role per tier depth it reaches (`foreman_t2` … `foreman_t6`) and its
  faction: a tier quest lists the role rows for its tier and every deeper one, per faction variant, so the role
  binding needs no tier filter and the one-variant assert (`registry.lua:203`) holds.
- The guild leaders in the halls (the story's named leader per capital) and the **hall's exchange counter** NPC.
- The camp vendor (a new vendor kind): buys like every vendor; the trade-in; repair (a new repair provider beside
  the trainer's); the reputation page with 6 rows, locked until the rank is reached (the mount trainer's locked
  rows are the precedent); the rank check also at the purchase.

**CONSUME.**
- The 12 items with the picked icons, the status slot `mining_sense` (or the spec's name) with the picked status
  icons, one of the two active at a time, level-gated use, tier-bound effect (works only in its depth).
- **Persistence:** statuses are runtime-only and cleared at leave and death today; this one saves its remaining
  time on a timer (a crash skips `on_leaveplayer`) and at leave, and re-applies it at login and after
  `on_dieplayer` clears it; one status id with two variants gives "one of the two at a time" for free.
- Ore Sense: a tier-filtered search for ore nodes in range (`group:grug_resource`, tier by y) on its interval, a
  marker for 5 s visible to the user only (a per-player entity with observers, or per-player particles).
- Treasure Hunt: the hidden block placed in solid rock (no air within 1, never protected), a marker for the user,
  removal by itself when the user is out of range (a node timer that checks, so nothing stays after a crash or
  logout).
- The Miner's Remains block with the picked overlay on each tier's host stone, its loot from the catalogue.

**GUILDQUESTS** (data on the Round 57 quest system).
- The gather quests per tier (1–2 per tier, T2–T6, one id each, texts per guild) given by the foremen through the
  per-tier roles; the brief names the file that holds them and how the per-zone budget counts a quest given in 36
  camps.
- The one follow-up per tier at the capital's guild house, with the story seeds: it requires both gather quests of
  its tier, so it is a **story** quest (a free quest may require only one, `E-free-requires`); a talk objective
  names one NPC, so it has one variant per giver zone, each talking to its race region's capital leader.
- The camp kill quests (1–2 per camp; as few as possible: one shared quest with a variant per zone where the task is
  the same); the raid on the enemy camp under construction from the own T4 foreman; the existing war-camp raid
  quests stay.
- The reward budget per zone and the free-play rules (the camp files carry the rework flag); the structure goes to
  the user as a QUESTMAP page before GUILDTEXT.

**GUILDTEXT (Astra) and TEXTREVIEW (Opus).** As in Round 57.

**D.** Version 0.58.0 with the map-reset entry; CHANGELOG (0.57 and 0.58 for the joint test); STATUS, ROADMAP,
BACKLOG, AGENTS; the completion section; **one joint GUI checklist for 0.57 and 0.58** (Round 57's 19 items plus
this round's): it says how to reset a local world (`grug_reset_world`) and in which order, and which 0.57 items (the
"existing world" ones) run before or after the reset; a full seed fleet on main.

## 5. Rules

The usual ones ([round workflow](../process/round-workflow.md)): one worktree and branch per lane; an independent
Opus review per non-trivial lane and a delta review for logic fixes; the Lua queue at most 8 at once; no pushes,
merges or syncs by lanes; the sync to the user's Luanti after the round; nothing unpicked ships. Fixtures: each lane
runs only its own fixture plus the fixtures that test the behaviour it changes, and the full run once before its
report.

## 6. Verification

- **Gates:** the full fixtures, `check_fresh_server.py`, `check_upgrade.py` (with the map-reset entry),
  `validate.py --game`, `tools/building_templates/check.py`, one boot per lane, a **full seed fleet** on main at the
  round's end (mapgen changed).
- **Headless shots:** a mining camp, a war camp with its lift, a camp under construction, a room from inside, the
  lift list, the vendor's locked page, an Ore Sense marker, a Treasure Hunt block, a guild house in each capital,
  the fixed gatehouse and bough platform.
- **GUI checklist** (D, draft for 0.58; joint with 0.57's):
  - find a mining camp in a T2, T3 and T4 zone; a war camp offers a foreman, a vendor and its lift;
  - take the lift down to every level of a T4 camp and back; an enemy cannot use it; no mobs spawn in a room;
    water and lava stay out;
  - trade ore for reputation at a camp and at a guild house; rank and balance shown; spending keeps the rank;
  - the vendor page: rows locked by rank; buy a T1 Ore Sense at rank 1; a T2 item refused for use below level 11;
  - use Ore Sense in its depth (a marker every 60–120 s), Treasure Hunt (a marked block; walk away and it is
    gone); log out and in: the effect continues; die: it continues;
  - the gather quests by tier at two camps; a missed T2 quest offered at a T3 camp; the follow-up to the guild
    house; the raid on a camp under construction;
  - reach rank 3: the cloak; the winged cloak at rank 10 (admin-set);
  - the town fixes: Lethariel's platforms and royal guards, a gatehouse stair, the patrols, Silverleaf's terrace
    stair, the start towns' waystone and mailbox.

## 7. Orchestration notes

- **Merge order:**
  - GUILDSPEC first (its contract), then REP, CONSUME, CAMPNPC;
  - CAMPS and ROOMS before LIFT and CAMPNPC;
  - HALLS and TOWNFIX any time (both touch templates: HALLS the six capital rosters, TOWNFIX the gate and bough
    templates and five capital codes; they share the capital `.lua` files, so they merge one after the other);
  - CAMPNPC and REP before GUILDQUESTS → GUILDTEXT → TEXTREVIEW; D last.
- **Shared files:**
  - CAMPS and ROOMS both touch `r7_mapgen.lua`, the loader payload and the zone overlay: ROOMS integrates after CAMPS
    merged, or they split the files in their briefs;
  - CAMPNPC and REP share the vendor window (REP the trade-in, CAMPNPC the page and repair): REP first;
  - `grug_quests`: GUILDQUESTS data only, plus CAMPNPC's tier filter in the role binding.
- **Size:** 14 lanes; the coordinator staggers the starts within the process budget.
- **Decided during the round:** the numbers (GUILDSPEC tuning page), the LIFTART picks, the halls' look (viewer), the
  quest structure (QUESTMAP), the text picks.

## 8. Engine and code facts (from Round 57's plan review and the Round 58 code survey; re-check in the briefs)

- Mapgen runs in the async mapgen env; `r7_mapgen.lua` owns the sole on_generated (`:112-117`), with the rock-below
  early-out (`:100`) and the untouched early-out (`:101`); chunks from y −113 down are skipped by the writer
  (`air_chunks.lua:73-75`). The −50 room shares the chunk −112..−33 with the writer, which treats unknown nodes as
  foreign content and vetoes its transaction where it touches one (`r7_content.lua:355-395`, `map_adapter.lua:7,78`).
  The IPC payload has a strict allowlist (`r7_mapgen.lua:35-52`, `r7_loader.lua:346-354`).
- A neighbouring chunk's caves, flooded caves and dungeons reach about 14–16 nodes past its edge and spare only
  `is_ground_content = false` nodes; −50 and −450 sit 17 below a chunk top, −950 37 below, −250/−650/−1050 57 below.
- Liquids flow only into floodable, non-liquid nodes; `grug_mobs:rift_void` is the model for the fill (walkable,
  floodable and buildable_to false, is_ground_content false); `grug_core:water_barrier` is the opposite.
- The zone overlay's protection is per column upward without limit (`r7_zone_overlay.lua:41-57`) and asserts 42
  roster rows and 36 columns (`:13, :30`); the depth pulse refuses only `hard_protection_kind_at` (`depth_pulse.lua:305`);
  the ambient underground ABM spawns have no protection check (`spawn_policy.lua:836-847`).
- War camps: catalogue `r31_pvp_catalog.lua:24-48`, anchors `source/simple_map.lua:393-408` (103–118), placement
  `placement.lua:331-358`, blueprint `r31_pvp_poi_blueprint.lua:294-393`, garrison `pvp_garrison.lua`, protection
  `world_protection.lua:84-99`; a new POI kind needs `placement_rules.lua`, a fitting profile, `settlement_icons.lua`,
  `spawn_policy.lua` and `world_protection.settlement_kind`.
- Ores are native `register_ore` rows with the same node names in every tier; the tier is the y (`registry.lua`
  `tier_at`); a runtime search over `group:grug_resource` is feasible.
- Statuses are runtime-only and cleared at leave and death (`status.lua:341-355, 455-461`); the elixir uses the
  status id `elixir`, so a new id is its own slot; level-gated use via `grug_core.can_use_item_level`.
- Role givers bind by role and faction only (`registry.lua:188-226`) and give a quest in one variant only.
- Repair has one provider ("trainer", `grug_repair/providers.lua:17-44`); `register_provider` is the seam. The mount
  trainer's locked rows (`grug_mounts/trainer.lua:55-101`) are the precedent for rank-locked rows.
- Teleport: `grug_home/travel.lua` (`teleport`, `prepare` with emerge, `safe_arrival`); waystones are own-faction
  only.
- A template change in a capital or start town changes its build digest and needs the map-reset entry
  (`check_upgrade.py:22-27, 285-294`).

## 9. Later

Round 59 and later: the story arc built (the picked draft), the quest rework of levels 11–60 on the Round 57
foundation; then unique items (Round 57 §9). The armor redesign with polygon groups lands after this round.
