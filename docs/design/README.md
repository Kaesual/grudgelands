# Game Design Docs

The **decided** game design — the living specification. Rules here (see
also AGENTS.md "Documentation layers"):

- Only settled decisions: rules, numbers, formulas, lists. No open
  questions, no option discussions — those live in `TODO-<topic>.md` files
  in the repo root until decided, then get folded in here.
- BACKLOG WPs implement what is written here; when a doc changes,
  check ROADMAP/BACKLOG for impact.
- Keep documents short and factual; "why" belongs in a brief *Rationale*
  line where a decision is surprising.
- A design change that breaks saved state follows the
  [release mode](../../AGENTS.md#release-mode) and the
  [upgrade contract](../technical/upgrade-contract.md).

## Documents

Status: **implemented** means shipped; the rounds are a rough span (the
first implementing round where known, → where not, and a later round that
changed the topic), not a full history. What each round shipped:
[CHANGELOG](../../CHANGELOG.md).

| File | Scope | Status |
|------|-------|--------|
| [`world.md`](world.md) | Canonical names, named-zone geography, destructibility and road/POI protection, tier rock and harvesting, ocean classes, capitals and kings, structures, dragons, the rift (§4b), travel, races and character creation (§7). | **implemented**, → R51 |
| [`world_zones.md`](world_zones.md) | The 38-zone macro-map: ids, race regions and territories, adjacency, relief and POI budgets, starts and capitals, contested zones, Battlegrounds, offshore dragons, the coast and water classes, the placed PvP fortresses and camps (§16); the PvP rules are in `pvp.md`. | **implemented**, R22–R51 |
| [`settlements.md`](settlements.md) | What a settlement is on the ground: the race starts and their envelopes, start safety, surroundings, the NPC roster and guard targeting, the capitals' layout, work sockets and shop vendors, the decor pass. | **implemented**, WP13–R75 |
| [`spawn_regions.md`](spawn_regions.md) | Rule-based spawn regions from a zone's recipe on its own terrain, quest places and directions, one level truth, zone borders, the compact maps and their cache. | **implemented**, R28–R36 |
| [`biomes_mobs.md`](biomes_mobs.md) | The biome and gathering inventory, the mob family specs and behavior classes, spawn budgets and the ABM rows that still run, sub-types and loot by band, signature woods and the supply map. | **implemented**, WP40–R51 |
| [`zone_mobs.md`](zone_mobs.md) | Every zone's mob families by day and night, camps, leaders and critters. | **generated**, by `tools/r37_dd/zone_mobs.lua`; its fixture fails when stale |
| [`world_preparation.md`](world_preparation.md) | Per-world full/starts mode, bounded chunk scheduling, shutdown/resume and the waiting UI. | **implemented**, R14 |
| [`world_map.md`](world_map.md) | The atlas without fog, markers, map quality and relief, the round minimap, zone and town names, the map window on Z with the quest log. | **implemented**, R14–R67 |
| [`combat_stats.md`](combat_stats.md) | HP and mana pools, secondary attributes, weapon damage, crosshair-authoritative attacks, armor, the PvP seam, mob tiers and depth levels, threat, recovery, offhand and carried light; shipped portions are labeled. | **implemented in parts**, R31–R72 |
| [`ability_targeting.md`](ability_targeting.md) | How the class kits pick targets and places: crosshair, friendly casts, groups, ground anchors, circles and cones. | **implemented**, R53 |
| [`classes.md`](classes.md) | Resources, input and the action clock, Strike and the basic attacks, the Warrior, Mage and Priest kits, the weapon overlay, deferred class work. | **implemented**, R52–R74 |
| [`scout.md`](scout.md) | The Scout: mana, leather, weapon routes, the kit, homing arrows, Sprint; stealth deferred (§8). | **implemented**, R11–R53 |
| [`skill_trees.md`](skill_trees.md) | The talents: two graph trees per class, every node with its id and values, unlocks, the page, persistence and the respec. | **implemented**, R11–R53 |
| [`progression.md`](progression.md) | Leveling pace and the XP curve, reward cadence, PvE death, quest gates, kill and gathering XP. | **implemented**, R28–R46 |
| [`quests.md`](quests.md) | The quest journal, objectives, participation, rewards, markers and tracker; per-zone quest data and validation; shared quests, story, completion texts and choice rewards; the quest content per band. | **implemented**, R14–R72 |
| [`story.md`](story.md) | The premise, faction questlines, the main line 41–60 and its finale at the rift (§2a), naming and environmental storytelling. | **implemented**, R20–R36 |
| [`items_crafting.md`](items_crafting.md) | The item rules: materials and tier rock, gems, alloys, the catalogs and curves, food, the vendor shelf, loot sources, quality and enchant model, bows. Numbers: `item_tiers.md`. | **implemented**, WP5–R45 |
| [`item_tiers.md`](item_tiers.md) | Every item number: enchant values and the class check, enchant loot, profession upgrades, the crown, potions and elixirs, sale values, repair, culture vendor prices, income. | **implemented**, R33–R78 |
| [`inventory_equipment.md`](inventory_equipment.md) | The inventory layout, Skills catalogue, Help, the Character screen, weapon, offhand and trinket slots, enchant channels, bags, the recipe list and station rules. | **implemented**, R11–R70 |
| [`professions.md`](professions.md) | The six primary professions and Cooking and Alchemy, progression from real recipes, the profession tier, recipe areas, stations and progress, gathering ownership and supply. | **implemented**, R28–R45 |
| [`economy.md`](economy.md) | Ledger currency, the price axis, 5 % buy-back, income measurement, repairs and services, the sinks, mount earning-time targets. | **implemented**, R29–R78 |
| [`durability_repair.md`](durability_repair.md) | Combat and tool wear, broken effects, death wear, town repair service, quotes and the repair price. | **implemented**, WP22–R78 |
| [`farming.md`](farming.md) | Cultivation families and crop shapes, the light rule, seeds and spores, the salt pan, hoes, wild-plant density and renewal near players, buckets. | **implemented**, R11–R51 |
| [`decorations.md`](decorations.md) | Furnishings, functional displays, original paintings, Expedition art rewards and city dressing. | **implemented**, R75 |
| [`character_visuals.md`](character_visuals.md) | Race looks and stature, armor art by slot and tier, the held weapon, the composition rule for players and NPCs, achievements and cloaks (§5b). | **implemented**, R11–R36 |
| [`sound.md`](sound.md) | The approval gate, conventions, event effects, mob voices, ambience by biome group and height, towns, caves and sea, music in the capitals, settings. | **implemented**, R34–R52 |
| [`mounts.md`](mounts.md) | Riding at levels 15/30/45/60, speeds and prices, the quickbar, dismount, flight permissions and restrictions. | **implemented**, → R74 |
| [`boats.md`](boats.md) | Boats as water mounts, the Shipwright, summoning and speeds, ejection, the island landings. | **implemented**, R29–R30 |
| [`home_travel.md`](home_travel.md) | Innkeeper homes, return home, its cooldown and death respawn, the Claim Stone as home. | **implemented**, R17–R76 |
| [`housing.md`](housing.md) | Claim Stones: the stone, the claim column, upkeep, permissions and protection, the stone interface and home-stone travel. | **implemented**, R25 |
| [`pvp.md`](pvp.md) | Geographic PvP: peaceful and contested ground, the flag, kill credit, the NPC faction filter, the Social tab's PvP section, fortresses and camps, PvP quests from 40. | **implemented**, R31–R36 |
| [`miners_guild.md`](miners_guild.md) | The Miner's Guild of each faction: camps, lifts and rooms, reputation, the exchange and vendor, Ore Sense and Treasure Hunt, the Miner's Remains, guild quests, every number with its model. | **implemented**, R58–R70 |
| [`expeditions.md`](expeditions.md) | Repeatable group content beyond the map: the three Expeditions, levels and entry, ownership, slots, the rules inside, packs, bosses, chests, rooms, traps, the Expeditions tab. | **implemented**, R71–R74 |
| [`parties.md`](parties.md) | Same-faction parties, invitations, the health HUD, the Social tab and `/p`. | **implemented**, R14–R76 |
| [`clans.md`](clans.md) | Clans: ranks and rights, succession, invitations, `/c` and the clan card. | **implemented**, R76 |
| [`mail.md`](mail.md) | Mailboxes, letters and postage, admin and NPC letters, tickets, announcements, the Admin Mail tab. | **implemented**, R48 |
| [`accounts.md`](accounts.md) | Website accounts, phase 1: linking, the Account page, account rewards, notices; the protocol is in [web-accounts.md](../technical/web-accounts.md). | **implemented**, R79 |

## Decision routing and evidence

Open work lives in [BACKLOG](../../BACKLOG.md), the current state in
[project status](../STATUS.md).
The [2026-09 documentation audit](../archive/maintenance/documentation-round.md)
records that round's review coverage and discrepancies. Approved future systems remain labeled;
“decided” alone never means “implemented”.

### Round 6 supporting records

These research notes are evidence and implementation records, not design
authority:

- [balance before](../research/balance-r6-before.md) and
  [balance after](../research/balance-r6-after.md) record the measured pool,
  damage, TTK/TTD and endgame-headroom rebase.
- [start-level verification](../research/balance-r6-start-levels.md) and the
  [spawn-variance audit](../research/spawn-variance-audit.md) record the start
  bands and surrounding population checks.
- [reference-media candidates](../research/reference-media-candidates.md) is
  the provenance/suitability basis for later user decisions. It authorizes no
  import; every candidate remains individually decision-gated.
