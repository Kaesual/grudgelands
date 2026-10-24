# Round 58 — the Miner's Guild and the town fixes (0.58.0, map reset)

Coordinator: Claude, 2026-10-23. Status: **complete** ([completion](#completion-2026-10-24)); 0.58.0 not pushed, it
waits for the user's joint GUI test of 0.57.0 and 0.58.0; the user's go 2026-10-23. The plan review (a fresh Opus,
2026-10-23, `r58/reports/plan-review.md`) is folded in; its blocker is decided (§2a).

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

## Completion (2026-10-24)

Every lane is merged on main, every code lane independently reviewed (Opus) and every logic fix delta-reviewed; this
lane D (the version, the declaration, this section, AGENTS, the status owners, the joint GUI checklist) follows on
main `c85f6624`. **0.58.0 is a map reset:** no migration step; characters keep their items, levels, quests and money;
item, achievement and waypoint ids unchanged; no new position in player meta. **Push:** not pushed; 0.57.0 was pushed
on 2026-10-23 without its GUI test, and 0.58.0 waits for the user's joint GUI test of both. **Sync:** by the
coordinator after the round.

### Lanes

Worktrees and branches `r58-<lane>`. Main's first-parent commits, in order (lane tip in brackets):

| Lane | Commit | What | Review |
|---|---|---|---|
| plan | `616112ab`, `a9191497` | this plan with the plan review folded in (B1 decided as §2a); then §1's note that the skeleton came with GUILDSPEC and the lift and room nodes are grug_mapgen's | fresh Opus plan review (one blocker, ten important findings) |
| GUILDSPEC | `734a914e` (`36cd21e1`) | `docs/design/miners_guild.md` (the rulings, the proposals, the yield model's tables, the `grug_guild` contract §10); the `grug_guild` skeleton (`catalog.lua` with every number, a stub file per owning lane, the load audit); `tools/r58_guildspec` (`model.lua`, `write_doc.lua`, the tuning page, `apply_tuning.py`, the §2a fixture on the real game) | MERGE AFTER FIXES (the fixture pinned stubs; the node ids; page and fixture disagreed; the status-clear order), fixed, delta MERGE |
| CAMPS | `5d2444cd` (`38a088dc`) | anchors 119–144: 20 mining camps in their zones' lowest level third, 6 camps under construction in the highest third of the contested T4 zones; the 16 war camps with a headframe, a foreman and a camp vendor; `wp40/r58_camp_catalog.lua`, `r58_camp_blueprint.lua`, the pure camp module `r58_camps.lua`; `grug_mapgen:guild_lift`; protection kind `mining_camp`, map icons, spawn refusal, the garrison; the fleet's camp check | MERGE AFTER FIXES (36 boot errors until the camp vendor existed; the lift's `paramtype2`), fixed (a placeholder camp vendor, `4dir`), delta MERGE |
| CONSUME | `a2b8386a` (`5b9f8f9a`), `0edc5faa` (`b09c77ab`), `a42f91b6` | the 12 consumables, the `mining_sense` slot with the picked icons, persistence across leave, death and a crash, Ore Sense (one grouped search, HUD waypoint markers), Treasure Hunt (node-timer removal, a token per placement), the six Miner's Remains with the picked overlay; `tools/r58_consume` with the drop's painter (`art/paint.py`, `ship.py --check`); then the user's ruling (a random ore or gem) and the coordinator's comment and spec line | MERGE AFTER FIXES (a relog skipped Treasure Hunt's pause; the search was a cube), fixed, delta MERGE; the ruling's follow-up delta MERGE |
| REP | `e8159d96` (`96b7cf5b`) | `store.lua` (lifetime and balance per faction, the rank callbacks, `/guild_rep`), `exchange.lua` and the vendor window's Trade-in mode (`guild = true`), the mason's shelf without Cobblestone and Gravel, the consumables' payout in `prices.lua`, the Character page's two lines, the achievement `miners_guild` with the three picked cloaks | MERGE (the brief had asked for the guild's proper name in the window; the coordinator followed the ruling), small fix round (names out of the window, buttons by catalogue index, non-finite amounts refused), delta MERGE |
| HALLS | `0713d49a` (`4471bbf4`) | six Miner's Guild houses replacing a core building each (`tools/r58_halls/make_halls.py`), the hall socket contract `capital_services.GUILD_HALL`; `export.py --check` retired | MERGE (three minor notes); merged after the user's look at the pages |
| TOWNFIX | `63210975` (`827569a9`) | Lethariel's bough beams (decks 6 and 7) and rails; the five core gatehouses (stair with a landing, doors and posts, the 4-wide deck opening, closed walls); throne-guard posts beside the king in all six capitals; `wp13/gate_watch.lua` (two counter-rotating loops, the tower post on the deck) and `patrol.lua` `loop_reach`; the terrace stair; the six start towns' waystone pads | MERGE, then the coordinator's ask for the royal guards' hysteresis (`518ca24c`, release 4 m, re-follow 5 m, the post only near the king), delta MERGE; main merged in-lane |
| ROOMS | `1816247e` (`19aefc48`) | phase 1 against stub camps (`ad4f7599`): `wp40/guild_rooms.lua`, the room step `guild_room_writer.lua` after `refine_or_degrade` with its own degrade, `guild_room_protection.lua`, the room nodes and `grug_mapgen:room_lamp`; phase 2 (`74218d53`): CAMPS' module wired, the lift written at every lift cell, the hint line, the fleet's room check; then the exit plugs | MERGE (the exits ended at the box face, not blind in rock: the coordinator's ruling call), the plugs `room_plug_t1` … `_t6`, delta MERGE |
| CAMPNPC | `c25fbd58` (`c62b7757`) | the 36 foremen (`r58_foreman_<camp>`, role `foreman_t<tier>`), the six named guild leaders, the Miner's Guild Exchange (`grug_traders:guild_exchange`, service role `guild_exchange`), the camp vendor's trade-in, repair (provider `camp_vendor`) and rank-locked page (`vendor.lua`) | MERGE |
| HALLS2 | `1edcd33c` (`558fea92`) | added during the round (below): the house on a required district plot `miners_guild` (17 × 17) in each capital's trades district with a headframe and an ore yard, the six core buildings restored, the picked banners (drop 02 P2) and emblems (P1) and the rail and cart as grug_mapgen nodes, `GUILD_HALL` with plot-prefixed ids, Kezamba's lot `shore_10` | MERGE (the reviewer's full run 267/267) |
| LIFT | `2a610b86` (`562091eb`) | `grug_guild/lift.lua` (the level list, own faction only, trips through `grug_home.travel` with the waystones' rules, no saved position), the picked drop 02 P1 art (the lift's node box and faces, the reputation icon, the map-window markers), `tools/r58_lift/art/ship.py --check` | MERGE AFTER FIXES (merge-time only: the `r58_campnpc` price pin with the icon, the settlements.md lift row), two merge rounds checked by the coordinator |
| GUILDQUESTS | `ab5846c9` (`4facf389`) | 30 quests with 130 variants (10 gather, 10 story follow-ups, 9 camp hunts, 1 raid with six variants) written by `tools/r58_guildquests/build_structure.py` with placeholder texts; the guild files as pseudo-zones; `Q.turnin_for` preferring the giver; the camp-site guards' name slots; QUESTMAP | MERGE AFTER FIXES (the validator's leader pattern after HALLS2; the hunts copied the zones' own quests; the hand-in marker), fixed with the user's two decisions, delta MERGE |
| GUILDTEXT | `c85f6624` (`1f9a2fdb`) | GPT-6 Astra wrote the 276 text fields (`dfcff660`: 30 titles, 160 texts, 86 completions); the user's picks of the Opus text review applied by the coordinator's script (65 of 65) with three captain names | TEXTREVIEW (Opus): 0 must-fix, 65 proposals, all picked; 8 name verdicts |
| D | this section | the version 0.58.0 and the `map_reset` entry, AGENTS (the current state, World generation without `export.py --check`, the Miner's Guild, the guild quests, the topic checks), upgrade contract §2, the format doc's §6.3 example, STATUS, CHANGELOG, BACKLOG, ROADMAP, README, the joint GUI checklist | independent review |

**LIFTART** (GPT-6 Astra, outside the repository): guild art drop 02 with two proposals, 26 assets (the lift's faces,
the two guilds' emblems and banners, the reputation icon, the two map icons), reproducible; the user's picks are below.
Nothing unpicked ships.

Main has 269 portable fixtures (10 new: `r58_guildspec`, `r58_camps`, `r58_consume`, `r58_rep`, `r58_halls`,
`r58_townfix`, `r58_rooms`, `r58_campnpc`, `r58_lift`, `r58_guildquests`). `mods/` against 0.57.0 (measured, `git diff
69481ed1 c85f6624 -- mods`): 166 files, +10,594 −349 lines; the new mod `grug_guild` (8 Lua files, 2,344 lines with
`catalog.lua`), the room and camp files in `wp40`, the six guild-house templates and the 30 quests' data in 26 quest
files, the picked textures of drops 01 and 02.

### Lanes added during the round

- **HALLS2:** the user found HALLS' houses fine for a first version but not "Miner's Guild" enough and asked whether
  they could stand outside the civic core; on the coordinator's answer (the cost of a district plot) the user chose to
  move them into a district. HALLS2 put each house on a required district plot with a headframe and an ore yard,
  restored the six core buildings HALLS had replaced and shipped the picked banners and emblems as nodes.

### Decisions during the round

**The user** (HANDOVER):

- **§2a (plan review B1):** option (a): the mason stops selling Cobblestone and Gravel; the exchange takes only items
  no vendor sells.
- **LIFTART:** the banners from drop 02 **P2** (lamp arch, split ore); everything else from **P1**: the timber
  rope-drum lift, the 16 px emblems (keystone, crossed picks), the pewter reputation token, the two map icons.
- **The numbers:** accepted as a first version; the tuning page's store stayed empty, so the catalogue's proposals
  stand (§9 of [miners_guild.md](../design/miners_guild.md)).
- **Ore Sense:** a mark goes to a **random ore or gem** in range (not the gem first); the first mark comes one
  interval (1–2 min) after the use, and only in the item's depth, as built.
- **No reputation from guild quests:** reputation comes only from the exchange.
- **The halls:** Kezamba's house in basalt; then the houses moved into a district (HALLS2); HALLS2's houses accepted
  ("sehen top aus"), the banners one node big for now, a house near the city wall is fine.
- **The raid:** four guards and the captain (the camp-site guards get name slots); **the hunts** reward a choice of
  materials.
- **QUESTMAP:** the guild quests' structure accepted.
- **The texts:** all 65 proposals of the text review; the captain names Kembala (troll), **Torva Stonewright**
  (dwarf, the review's idea, replacing Hulda Stonewright) and Eshara (elf), the other captains and both Stakeguard
  titles as they were.

**The coordinator** (answers to lane questions; each built as stated):

- **The nodes in grug_mapgen** (brief time): CAMPS registers `grug_mapgen:guild_lift`, ROOMS the room nodes, because
  the world writer needs them in wave 0; `grug_guild` overrides only the lift's right-click.
- **GUILDSPEC built the skeleton** (mod, catalogue, a stub file per lane), so merging GUILDSPEC put it on main; its
  Q1–Q7 as recommended, except Q1 and Q4 (the user's).
- **The camp module contract** in CAMPS' brief; CAMPS' `camps(layout, seams)` (a war camp's race needs the world's
  seams) accepted; two gate guards per own camp (four in a contested T4 camp), the lowest third for mining camps and
  the highest for camps under construction; the captains' names to GUILDTEXT.
- **ROOMS in two phases** (stub camps, then CAMPS' module); its answers: the room step writes CAMPS' lift node at the
  lift cell, the hint line `guild_room = "Miner's Guild – protected"` in `grug_core/protection.lua`, its own
  `room_lamp` (the Mese Lamp is curated out), mobs walking in through a cave past an exit accepted; then **the exit
  plugs**, because the ruling says the exits end blind in rock.
- **The user interface says "Miner's Guild" only:** REP's Trade-in label and Character tooltip drop the proper names
  (the coordinator's brief had asked for them; the ruling wins); `grug_guild.summary` keeps the name for texts.
- **One painter for the guild art:** CONSUME's `tools/r58_consume/art/paint.py`; REP copies the cloak PNGs byte for
  byte, and LIFT's `ship.py` copies drop 02's files by hash.
- **Option (A), prefixed hall sockets:** HALLS2's plot sockets carry the plot prefix (`miners_guild/…`), read through
  `capital_services.GUILD_HALL`; its `required_of` line in `r7_capitals.lua` approved; Kezamba on the shore.
  CAMPNPC binds through `GUILD_HALL`.
- **TOWNFIX:** the throne-guard posts in all six capitals (shared code), the deck-7 beam removed too, the watch as one
  rectangle walked both ways, the tower post on the deck, Kezamba's gate posts unchanged; then the follow hysteresis.
- **CAMPNPC:** own faction only at the camp vendor and the exchange counter (the existing rule; CAMPS' note that the
  camp vendor served everybody was refuted), the camp vendor opens on Trade-in, the exchange counter keeps its Buy
  mode with a pointer to the camps; the leaders' guild touch and the one named foreman wait (backlog).
- **LIFT:** `grug_home` looked up at run time (no new dependency), the minimap's 6 px icons kept, the lift's light
  level 3.
- **GUILDQUESTS:** follow-ups per faction (10 ids), a follow-up at every own camp of tier ≥ k, Battlegrounds camps
  reporting across the front, the guild files as pseudo-zones, the camp and Battlegrounds files unflagged.

### Deviations from the plan

- **One lane added** (HALLS2, above), so 15 lanes.
- **CAMPS needed no second phase**; it registered the placeholder camp vendor in its fix round so that boots stay
  free of errors until CAMPNPC.
- **The room lamp** is `grug_mapgen:room_lamp` (the plan's "shipped light node" `default:meselamp` is curated out),
  and each exit ends in a plug of the tier's rock one node past the box, outside its protection.
- **The lift saves no return point:** the list offers every level, so the plan's "room's return point" was not
  needed and nothing goes into player meta (no `register_on_relocate` clear; `tools/r41_up` untouched).
- **Ore Sense's marker** is a per-player HUD image waypoint, not particles or an entity (both are depth-tested and the
  rock hides them), and its search is one grouped `find_nodes_in_area` instead of a `find_node_near` per target.
- **The royal guards** stand on posts in all six capitals, not only Lethariel (all six wandered).
- **The quests:** 30 instead of 28 (two night hunts where a camp's zone already hunts every day role); Lorindor's hunt
  repeats the stag, the one role there; the raid's four guards needed name slots (`pvp_garrison.lua`, `names.json`).
- **The camp files are not flagged reworked** (the brief's lead was refuted: flagging them fails their old chains).
- **`build_structure.py --check`** holds only until the texts land: since GUILDTEXT the JSON files are the source (10
  of 26 files differ from its placeholders); it is not a gate, as in Round 57.
- **The minimap** keeps the mine and war-camp 6 px icons: the picks have no 6 × 6 version; the picked icons show in
  the map window.

### Numbers worth keeping

Measured unless marked "report" (taken from the lane's report) or "model".

- **Reputation (model, GUILDSPEC):** 416 / 483 / 903 / 2,047 / 3,535 / 5,165 points per hour of mining at T1–T6;
  hours to ranks 1–6 in total 0.5 / 1.9 / 3.9 / 7.0 / 11.0 / 16.2, to rank 10 74 h; an hour at a tier buys about one
  consumable; Ore Sense's extra finds worth 10–26 % of its price; one Treasure Hunt about half an hour of the band's
  income (82–105 %). No measured mining yield exists.
- **The room step (report, engine, seeds 12345 and 42):** 148 of 148 rooms correct per seed; 1.07 ms per room chunk on
  average (max 1.8 ms, 343 chunks), against about 159 ms of R7 refinement in a −50 chunk (under 1 % there) and
  0.04–0.09 ms in a deep early-out chunk; the −650 room of `pvp_camp_skyglass_canopy_throng_low` on seed 42 has 588
  lava sources within its ring, the nearest one node from the box, and stays clean.
- **Placement (report, CAMPS, three seeds):** 0.6–0.7 s; a camp's nearest POI centre 138–163 nodes away; one fleet
  seed 29.5–30.7 s before and 30.8–32.4 s after (noise under contention).
- **Fleet times (report):** `seed_fleet quick` 100 of 100 in every mapgen lane: CAMPS 6 min 41 s and 6 min 39 s,
  HALLS 6 min 10 s, TOWNFIX 6 min 12 s, ROOMS 6 min 22 s, HALLS2 6 min 27 s. Lane D's **full fleet on main**: see
  [Round-end gates](#round-end-gates).
- **Quests:** 30 guild quests with 130 variants (20 gather, 76 follow-up, 28 hunt, 6 raid), shipped quests 423 → **453**
  (measured over the quest files). Rewards (report): gather 360 XP / 21c (T2) … 1,160 XP / 8s (T6); follow-ups 135 XP
  / 8c … 435 XP / 3s; hunts 298 XP / 18c … 1,120 XP / 7s; the raid 900 XP / 1s 28c; the night hunts 338 XP / 32c (T3)
  and 463 XP / 80c (T4). Per camp against the zone's own quests (report): T2 4 quests 1,153 XP vs about 14 quests and
  4,500 XP; T3 7 quests 2,658 XP vs 8–12 and 3,100–5,050; T4 11 quests 5,313 XP vs 8–19 and 5,300–13,500.
- **The ledger (report):** the solo questing share, human, levels 10–20 82 → 92 %, 30–40 78 → 85 % (the other races
  6–10 points more; the ledger also counts the other faction's Battlegrounds follow-ups, so slightly high).
- **Ore Sense and Treasure Hunt (report, engine, range 16, 40-run averages):** one Ore Sense search 181–299 µs at T1
  (about 1,800 deposits of six targets in the box), 84 µs at T5, 48 µs with no target; the spec's `find_node_near` per
  target would cost up to 323 µs per call with nothing in range, about 1.9 ms for T1's six; a Treasure Hunt spot test
  9.9–11.4 µs, at most about 0.16 ms per 5 s check. No globalstep was added; a user with Ore Sense costs one search
  per mark every 60–120 s.
- **The lift (report, engine, seed 42):** 11 trips at `mining_camp_ashenward_march` (T4), each at most 0.5 s.
- **Throne guards (report, engine):** 3.0 m from the king; before the hysteresis an idle king about 8 m from the post
  started the follow 7 times in 30 s (`r41_mob`).

### Classification

**Map reset**, no step:
`{"schema": 3, "version": "0.58.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0", "0.58.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0", "0.53.0"], "map_reset_pass": "0.50.0"}`.
The reason ([upgrade contract §2](../technical/upgrade-contract.md#2-the-declaration)): the camps (new anchors and
blueprints, the extended war camps), the 148 rooms of their own generation step, the guild houses on their district
plots and the town fixes change what world generation and the towns build (`check_upgrade.py` sees the town builds;
the camps and rooms it does not see, so the entry covers them too). A world on 0.57.0 (or 0.56.1) moves on across the
reset with the pre-reset pass (`map_reset_pass` 0.50.0): characters keep everything but their position and home claim
(contract §3.2), reputation starts at 0 for everybody.

What needs the reset and what alone would be compatible (the lanes' reports): CAMPS, ROOMS, HALLS/HALLS2 and TOWNFIX
are world generation and templates; CAMPNPC's NPCs and GUILDQUESTS' quests stand on the new sockets, so they ride on
the reset; GUILDSPEC's skeleton, REP, CONSUME, LIFT's code and art and the new nodes alone would be compatible.
Saved state, all without a position:

- player meta `grug_guild:lifetime_<accord|throng>` and `grug_guild:balance_<accord|throng>` (integers, created on
  first use; REP); `grug_guild:effect` (`core.serialize({kind, tier, remaining})`, every 30 s, at leave and at start;
  CONSUME);
- existing keys written anew: `grug_achievements:t:miners_guild` and the cloak list (three ids more), and
  `grug_quests:state` for the 30 new quests (new ids, no format change);
- map-bound, going with the map: the Miner's Remains' node meta (`owner`, `token`) and timer; TOWNFIX's socket
  markers in `grug_mobs`' mod storage (existing `startnpc:` keys, cleared by `map_reset.lua`);
- nothing new in mod storage, nothing in player meta that holds a position, so no `register_on_relocate` clear.

### Open notes

- **For the user:** the joint GUI test below, with these to judge: the camps' places and their bands, the headframe
  partly hiding the lift and the lift's light, the guard and watch rounds, the waystone pads' places, the banner size,
  the Ore Sense and Remains markers' size and contrast (also on the web build), and the **names never picked yet**:
  the cloaks Lamp Badge Workcloth, Lamp and Pick Workcloth and Lamplight Mantle, the achievement "Miner's Guild" I–III
  and its line "The foremen know your lamp before they see your face." (REP's proposals); from Round 57 the violet
  story colour (now on the guild follow-ups) and the headland edge.
- **Round 59** builds the story arc from the picked draft and reworks the quests of levels 11–60 (§9); the guild's
  follow-ups carry its first seeds.
- The reviews' and reports' notes are in the [Round 58 carry-overs](../../BACKLOG.md#round-58-carry-overs).

### GUI checklist (Rounds 57 and 58)

One test for both rounds (plan §6, review I9), desktop and the web build (the lanes' web shots were taken at
1024 × 600; Round 57's at 1280 × 720 and 1035 × 696), on the synced game.

**Resetting a local world** (what the hosting platform does, contract §3.5; first make a copy of the world folder):

1. Quit the world (stop the server).
2. Optional, to test the claims' containers: from the repository checkout,
   `python3 tools/migrate.py --world <world folder> --map-reset` (Python 3.13 or newer; it packs the containers in
   every housing claim and must end with exit 0).
3. Delete `map.sqlite` in the world folder; keep `map_meta.txt` (the seed), `world.mt`, `players.sqlite`,
   `auth.sqlite` and `mod_storage.sqlite`.
4. In Luanti's settings, *Content: Games → Grudgelands → Hosting platform*, raise **Map reset counter**
   (`grug_reset_world`) above the world's record: 1 for a world never reset before, else one more than last time (the
   game reads it at the start; only a value above the record resets).
5. Start the world. Its map is generated anew from the seed; each existing character is held on the waiting screen
   and moved to its race's start town at its next join, without the welcome.
6. Afterwards set the counter back to **0**: it is one setting for every local world, and another world whose record
   is lower would clear its claims and NPC records at its next start (without its map being emptied).

**Order:** (A) the existing world, reset as above, first join with its old characters; (B) everything else on that
world and with new characters; (C) a new world (or the "test" world) for the bays. *Re-checked (D):* no Round 57 item
needs the old **map**; items 3 (its last sentence), 5 (its last sentence) and 15 test an old character's **first join
on the new code**, which the reset keeps (player meta stays), so they run in (A) at that first join, the path the
production world takes. Do not join the existing world on the new game before the reset, or that first join is spent.
Items 1, 2 and 4 need no old state.

**(A) The existing world, at the first join after the reset** (a character above level 10 with old start quests done
or active, a crafting job running when it last logged out, enchanted items, a housing claim if you have one):

1. **The reset:** the character arrives at its race's start town without the welcome and keeps its level, inventory,
   equipment, money, quests, professions, mounts and waypoints; its home claim is gone (Return home falls back to the
   innkeeper), the Housing Steward hands out a new Claim Stone, and (after step 2) the claim's containers wait in its
   Belongings tab. The Character page shows "Miner's Guild: Rank 0".
2. **Round 57 item 3, last sentence:** a job of the old version that was running finishes as before (its output in the
   inventory or the Overflow).
3. **Round 57 item 5, last sentence:** the existing character has its Basic recipes after this login.
4. **Round 57 item 15:** the new start quests are offered (one whose old finale was done keeps it done); its old start
   quests are gone from the log without an error; its level-11 zone's quests are still offered.

**(B) Round 57** (its [checklist](round57-plan.md#gui-checklist-round-57) items, unchanged unless noted):

1. Layout C. 2. The queue. 3. Offline and the overflow (its last sentence in A). 4. Favourites. 5. The Basic unlock
(its last sentence in A). 6. Recipe details. 7. Alloys and woods. 8. Dyes. 9. Vendors (and Round 58's mason below).
10. A new character's start (the waystone and mailbox now stand at the town's centre: Round 58 below). 11. Shared
quests. 12. Choice rewards (Round 58's hunts
add a choice of materials, below). 13. Completion text. 14. Story marking: **changed by Round 58**: the guild's ten
follow-ups are the first shipped story quests, so judge the violet "!", the "Story" heading and the map icons on one
of them (B, guild quests) instead of the capture probe. 15. An existing character above level 10 (in A). 16. Bays
(in C). 17. The chin underside. 18. Help. 19. The pages for the user.

**(B) Round 58:**

20. **Mining camps** (CAMPS): find a mining camp in a T2 (levels 11–20), a T3 and a T4 zone: in the zone's lowest
    level third, a trail from the road, a tent, a stall, the headframe with the lift, two gate guards (four in a
    contested T4 camp, which belongs to the faction of its half of the continent), the Foreman and the Camp Vendor with their nametags. A Battlegrounds
    war camp shows the headframe east of the command tent and the foreman west of it; its guards and raid role are
    unchanged. Nothing in a camp can be dug.
21. **Camps under construction:** in a contested T4 zone, in its highest third, the enemy's camp of scaffolding with
    four Stakeguards and a named captain; no lift, no vendor, nothing to use.
22. **The map:** mining camps on the POI layer ("Mining camp: …", the rope-drum icon), camps under construction on
    the PvP layer (the tent-frame icon); the minimap keeps the old 6 px mine and war-camp icons.
23. **The lift** (LIFT): right-click an own T4 camp's lift: "Surface" and Levels 1–4 (−50 … −650), the surface "You
    are here", Travel on the others; ride to every level and back, arriving in front of the lift in the room and on
    the deck; in combat "Cannot travel in combat."; as the other faction, in a room too, the refusal line ("I serve
    only The Accord.") and no list. **Judge:** the headframe partly hides the lift from the side; the lift's own light.
24. **The rooms** (ROOMS): each level lit, three exits, each ending in a plug of the tier's rock that you dig (it
    drops Cobblestone) and dig on from; inside the room you cannot dig or build ("Miner's Guild – protected"); no
    monster spawns in a room; water and lava next to it stay out (the −650 rooms often border lava); below −501 the
    room is contested ground.
25. **Reputation** (REP): `/guild_rep <you> 2734`: the Character page shows "Miner's Guild: Rank 3" and "Reputation
    2,734" with the pewter token, the feed the new rank, the rank-3 cloak in the picker. At a Camp Vendor and at the
    Miner's Guild Exchange in your capital the window opens on **Trade-in** and says "Miner's Guild" only (no guild
    name): rank, reputation and the lifetime to the next rank; trading 143 Cobblestone gives "Traded 100 … 43 left.",
    49 Sand is greyed; buying something (below) keeps the rank; the Sell tab still pays copper for the same goods. The
    mason no longer sells Cobblestone or Gravel. Web: a Claim Stone status of four lines fits between the guild lines
    and the cloak picker.
26. **The cloaks:** `/guild_rep <you> 350000`: ranks 6 and 10, the winged cloak; **judge the names** (above).
27. **The camp vendor's page** (CAMPNPC): Buy at rank 0: all six rows locked, "Reach Reputation Rank N" with their
    prices; at rank 3 rows 1–3 open with "Use from level N"; buy Ore Sense I: the balance drops by 400, the lifetime
    stays; with a full bag the purchase is refused and nothing spent. Repair: the Repair button opens the repair form
    and mends a worn tool. An enemy is refused. The Exchange: Trade-in and Sell; Buy shows only "The Miner's Guild
    sells its goods at the mining camps."; no repair. At the web size the page fits.
28. **Ore Sense** (CONSUME): a T2 item is refused below level 11; outside its depth the use is refused with the band
    (for example "… works only between y −301 and −500."). Use Ore Sense I above y −100: the status icon appears;
    within 1–2 minutes a small ore tile marks a random ore or gem deposit through the rock for 5 s; a second item is
    refused with the time left and nothing is taken.
29. **Treasure Hunt:** Treasure Hunt V between y −701 and −1000: a skull-tile marker; dig to it: coins, a bar,
    sometimes a cut gem; walk more than 48 away: it is gone, and about 90 s later a new one appears. Log out and in,
    and die: the icon and the time continue, and a relog does not skip the pause. A second player sees no marker but
    can dig the block. **Web:** the markers (HUD waypoints) show on the web client too; judge their size and contrast.
30. **Guild houses** (HALLS2): in each capital's trades district the headframe marks the house; inside, the named
    leader behind a low desk (Highcourt Alis Cartwright, Dur Brannoc Hadrin Beamset, Lethariel Caelir Veinward, Nhal
    Veyr Iven Lastshift, Gor Drazhak Drava Flintshoulder, Kezamba Ombali Ropekeeper) and the Exchange behind a low
    counter; the banners, the emblem sign, the frieze of the six tier stones, the ore yard; the civic core has its old
    building back. A house may stand near the city wall (accepted).
31. **Guild quests** (GUILDQUESTS, GUILDTEXT): a level-15 Accord character at a T2 camp is offered the Iron, the Jade
    and the camp's hunt at once; a T3 camp also offers the T2 gathers (its own open at 21); the quest log shows a
    gather quest as "Level 13" without a zone; a Throng character is refused at an Accord foreman. Both T2 gathers
    done: the violet follow-up, "Travel to <leader>", turned in only at that leader, with its closing lines. A gather
    quest's "Return to" and the map's hand-in marker point at the foreman you took it from (a role quest has every
    foreman of its tier as a turn-in; GUILDQUESTS changed `Q.turnin_for`). A hunt's
    choice of leather, cloth or bars; the night hunts (Totemwater Reach, Blackwind Rise, Thunderroot Wilds) after dark;
    from a T4 foreman the raid on the camp under construction (four Stakeguards and the captain by name). Read the
    texts.
32. **Town fixes** (TOWNFIX): a capital gatehouse (all five but Kezamba): the east door, the stair with a landing, the
    first floor, the deck through the 4-wide opening, no jump; two guards circling the city side in opposite
    directions, the third standing on the deck (**judge** the rounds). Lethariel: both bough stairs walkable, the hall
    door reachable. In every capital the throne guards stand beside the king, follow him into a fight and return
    afterwards, without starting over and over while he stands away from his seat. Silverleaf's terrace stair without
    a jump. Each start town: the waystone and the mailbox at the centre by the Quartermaster ("Mailbox in <town>"),
    travel works (**judge** the places).
33. **Help:** Help names the Camp Vendor among those who repair.
34. **The pages for the user** (outside the game, private claude.ai pages): the guild houses'
    [gallery](https://claude.ai/artifact/RUtD5TW5vNYVXykBCBcUxG) and
    [districts](https://claude.ai/artifact/2T7ZhQhDcaHffMVWYdu7DF), the town fixes'
    [gallery](https://claude.ai/artifact/TRn7fM8vcmpqycVBQFDcXn),
    [start towns](https://claude.ai/artifact/GPLY4kRSKoHJyqaePJBKKD) and
    [Lethariel core](https://claude.ai/artifact/45fkkM4dXyWv7WrY9BwR3v), the guild quests'
    [QUESTMAP](https://claude.ai/artifact/3RDdAyMBV8bQxoe873qDdp) and the
    [tuning page](https://claude.ai/artifact/2oekLZggJaBnSsYCv2eRoG).

**(C) Round 57 item 16, the bays:** in a new world with the "test" seed (or the reset "test" world).

### Round-end gates

