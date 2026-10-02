# Remaining work-package scopes

Detailed scope subordinate to [BACKLOG](../../BACKLOG.md) and current
[design](../design/README.md). Extracted during the documentation consolidation
from the pending package rows, retaining unique acceptance requirements.
Completed implementation narratives remain in the
[historical backlog](../archive/planning/backlog-before-consolidation.md).

The 2026-09-29 [work-package audit](wp-audit-2026-09-29.md) and its
[user decisions](wp-audit-2026-09-29.md#user-decisions-2026-09-29) (cited below
by letter and number, for example E5) closed, merged and rewrote the cards
below. Closed cards keep a short record of where their remainder went.

These are approved broader goals with partial deliveries, not fresh implementation
briefs. Before execution subtract the delivered slices listed here and in BACKLOG,
check current topic rules and refresh stale source-line references. Earlier
migration/alias language is not authorization under fresh-server mode. A target
not yet implemented remains a target; this document does not certify the code.

## WP5

**Dependencies:** WP1 ✅, WP3 ✅, WP43 ✅.

**Status:** open, partly delivered. Found-item loot (one-prefix/one-suffix family pools, level/quality metadata, tier-correct drops, boss reward hook), the vendor Uncommon and the named fixed-tier enchanting of Round 13 are delivered. Round 28 adds loot by level band; the found-loot versus crafted-demand audit is done with Round 29's per-band payout calibration (economy plan §3.2 and §10.1). The task card `docs/research/wp5-task-card.md` is from the refinement era and is stale; do not execute it. Specs: `items_crafting.md` §§4–7, `crafting_equipment_revision.md`.

Remaining: one per-stack cultural-finish channel and one separate target-race PvP-special channel (including the Warding Draught) with their fixed caps and overwrite rules, universal affixes staying independent; **masterwork** as the Grudgeforged upgrade of an existing equipment item to item level 70 (D3; this WP settles its inputs, the Fallen Crown being the candidate). Named rares drop **no** trophies (D4). WP41 only consumes the PvP-special hooks, so it does not wait for this WP

## WP9

**Dependencies:** WP6 ✅, WP8 ✅, WP40 ✅; WP41 only for quests that need the PvP tag.

**Status:** open; **V1 scope** (B7): story levels 41–60 and the finale are part of V1. Round 14 ships the starter story (nine quests per culture ending at the Cinder Mark clue) and Round 20 extends the catalog to 240 starter/capital/regional quests up to level 40, including the frontier guard-kill quests in the contested zones. Round 29 replaces those 240 quests with 491 on the Round 28 framework ([completion](round29-plan.md#completion-2026-10-02)): one track per race to level 30, the contested 31–40 zones and front quests 41–60 from the 31–40 outposts and capitals, with repeatable and island bounties; the new format has no enemy-guard objective. All deaths cost no XP (`progression.md` §3), so no PvP XP exemption remains.

Remaining: the level-41–60 faction main questline on top of Round 29's front quests (corruption chapters, The Broken Causeway and Battlegrounds beats, elite and hostile-territory kills, level gates), the non-loot quest-interaction slot per contested zone (`world_zones.md` §16) and a finale. The finale is V1; its form is not decided yet. The Nether payoff stays V2 (`story.md`)

## WP10

**Dependencies:** WP5, WP26 ✅, WP33 ✅, WP43 ✅, WP44.

**Status:** open, partly delivered. Seven primaries plus Cooking, books, universal base recipes, enchant catalogs, gem cutting, the herb authorizer and money-only trainer repair are delivered (Rounds 10–13).

Remaining, after WP5's cultural channel: cultural-finish workstation operations and the cultural-master, weapon-counter and Alchemist helper NPC services (`economy.md` §4, `world.md` §7). The cultural-master NPCs come later, with this WP (D11), and need capital sockets; their fees come from the WP44 tables. Optional: recipes for the cut-gem storage blocks. The buff/debuff icon framework formerly listed here is the separate status-icon package (D10), delivered in Round 26 Lane I.

Professions: seven primaries plus secondary Cooking; two primary slots; exclusive Basics and owning-profession books; independent T1–T6 recipe progression and four mastery bands; universal plain feedstocks/base gear; specialist catalogs and named fixed-tier enchantment operations. Weaponsmith and Armorsmith are separate professions sharing the Forge; no Blacksmith alias.

## WP11

**Dependencies:** WP3 ✅, WP4 ✅, WP-Speed ✅.

**Status:** **closed as delivered 2026-09-29** (C2); the respec price moves to WP44. X1/X2/X4 and Scout's complete trees are implemented. Round 11 delivers Ironbound/Unbroken; Round 12 completes the original three classes' X3 consumers. X4 ships the sfinv page, read-only `/talents`, removes `/talent` and `/respec`, and implements free-first/paid respec through `grug_money.take`; its six copper values come from WP44's income estimate since Round 29 (15c / 35c / 75c / 2s / 6s / 12s, `economy.md` §4; spec: `docs/design/skill_trees.md` rev 2 + `progression.md` §2; user rulings 2026-09-16)

Skill trees: 2 trees × 2 chains × 8 talents = **28 ranks per tree** (56 per class), 1 point per 2 levels (30 at level 60). Per tree at most ONE keystone adds a new skill; the other keystone and the **one-rank capstone** improve or REPLACE an existing button, so no build exceeds base kit + 2 keys and **the original three classes start with Strike + 3; Scout starts with Strike + 4** (Hamstring leaves the Warrior's base kit and becomes Ruin's keystone). **A character reaches exactly one capstone**: 21 of 30 points in one tree, level 42. **4 new ability registrations** (Hold Ground, Cinderfall, Glacial Ward, Word of Ruin); Renew and Hamstring are gated instead. Nine talents deliberately break a cap or a control rule, each with a stated limit. Respec = full reset in the talent UI, priced at 5 minutes of measured net solo income, first one free; **class change is removed from the game**. **Prerequisites: the shipped `grug_core` movement aggregator** (WP-Speed) for one talent, and an absorb-stacking aggregator inside this WP

## WP13

**Dependencies:** WP40 and WP43 delivered. Encounter/resource consumers remain
owned by WP23/WP34/WP42; shipwright teaching belongs to WP17.

**Delivered:** six starts, six capitals with services/kings/royal guards, and the
R14/R15 eighteen regional compositions (six villages, six outposts, six inner
bandit camps). Current preparation and settlement behavior belong to
[settlements](../design/settlements.md) and
[world preparation](../design/world_preparation.md). Historical construction
increments and old performance numbers stay in the archived backlog.

**Round 20 art coverage:** the 100-anchor world roster includes the
12 starts/capitals and 88 other slots. Subtract the eighteen documented regional
compositions from the latter to identify the 70 Round 20 art slots:

| Kind | Total non-civic slots | R14/R15 delivered | Round 20 art slots |
|---|---:|---:|---:|
| Villages | 12 | 6 | 6 |
| Outposts | 24 | 6 | 18 |
| Bandit camps | 12 | 6 | 6 |
| Mining camps | 6 | 0 in that increment | 6 |
| Mirefolk camps | 4 | 0 in that increment | 4 |
| Clash anchors | 16 | 0 in that increment | 16 |
| Dragon arenas | 2 | 0 in that increment | 2 |
| Apex camps | 2 | 0 in that increment | 2 |
| Rare-route pads | 10 | 0 in that increment | 10 |

These 70 slots now have authored compositions in the Round 20 local delivery; technical gates passed and GUI acceptance remains
open as recorded in STATUS. Existing banners, mobs, bosses
and functional anchors are preserved. Do not schedule these as 70 empty sites. The earlier phrase
“100 POIs” conflated the whole anchor roster with the 88 non-civic slots.

- The two shipwright plots/display hulls are present in Whitebridge Shire and
  Whispering Reedlands village slots; their level-30 teaching transaction remains WP17.
- Camps have no renewable sockets (E5). Encounter behavior belongs to WP42
  and the dragons, structure dressing to WP13.
- **The `bandit_frontier` building core is 16 nodes** (E1): the Round 20 art
  and the code stay; the design was corrected. The core also sets the camp's
  protected POI box and the Claim Stone keep-out.
- **Separate POI walk** (E2): the user wants to walk the Round 20 POI art
  apart from ordinary playtests; that walk is its GUI acceptance.
- The Round 22 D72 follow-up ("capitals look too alike", infill houses) is
  done: Round 26 Lane W gave every capital a more irregular outline and its
  own character, with fields and houses between the outer ring and the wall
  ([plan](round26-capitals-housing-cleanup-plan.md), `world_zones.md` §12).
- Preserve complete civic protection (capital cities and start towns with
  their bare bands, Round 22 D76/D78). Roads and POI, village and camp
  building cores are world-protected (Round 25 rulings 15–16, `world.md` §2
  R1b); bounded functional anchors stay hard-protected; the rest of a
  village/outpost/camp shell stays mutable.
- Preserve king/reset/participation/Crown reward acceptance; do not respawn the
  already-delivered king/guard roster as though missing.
- User GUI acceptance remains open where no explicit acceptance is recorded.

Roster provenance: [WP13 contract](../research/wp13-capitals-pois-contract.md),
[R14 anchor identities](../research/round14-poi-work.md),
[R15 recomposition](../research/round15-poi-work.md), current `world_zones.md`.

## WP14

**Dependencies:** WP3 ✅.

**Status:** **closed as delivered 2026-09-29** (C5). Round 11 delivers the ordinary offhand catalog (shields, Goldsmith spellbooks, the zero-hand Leatherworker quiver), stats and the two-hand pairing checks. Carried light is canceled: torches are not offhand items and nothing gives a moving light radius (`combat_stats.md` §7).

## WP17

**Dependencies:** WP40 ✅; WP13 for the shipwright NPC and socket.

**Status:** **delivered in Round 29** (2026-10-02, [travel plan](travel-boats-waypoints-plan.md) and its [completion](travel-boats-waypoints-plan.md#completion-2026-10-02), lanes B, W, M-geo, A, E4); V1 scope (B1, B2). GUI acceptance is part of the [Round 29 checklist](round29-plan.md#playtest-checklist). Current rules: [boats.md](../design/boats.md), [world.md](../design/world.md) §2b and §6.

**Boats** are water mounts in `grug_mounts`: the Boat (L15, 4 nodes/s, 1s10c) and the Improved Boat (L30, 8 nodes/s, 7s) from the Shipwright beside every capital's Riding Trainer, owner-bound skill items recovered from the Skills page, summoned only with the feet in water, removed when off the water, ejected by any damage; no recipe, placement, pickup, decay or theft. They are the only access to the two dragon islands (flight is forbidden over every ocean column).

**Waypoints:** the mapgen places the waystone node `grug_mapgen:waystone` in all six capitals and on a pad in all six starts (no zone hubs, B2). Discovery by proximity or right-click, per character; instant free travel between the own faction's discovered stones through the shared travel path of `grug_home/travel.lua`; refused in combat and at enemy stones; a `waypoint` marker on the Map tab and the minimap. There is **no `/unstuck`** (B3).

**Ocean danger:** the Kraken Guard swims 10 nodes/s inside deep-ocean columns and 5 elsewhere, view range 40, with the simple leash (it drops the target outside deep ocean); the residual-allowance pursuit model is dropped (travel plan ruling 7).

## WP21

**Dependencies:** WP1.

**Status:** closed 2026-09-29 (user decision, [WP audit](wp-audit-2026-09-29.md#user-decisions-2026-09-29)): food-based recovery is the final recovery system; there is no separate out-of-combat regeneration and no rested XP.

Former scope: recovery & rest (out-of-combat regen, food recovery, innkeeper rest service). Innkeeper home binding/return/death respawn is already delivered by [home_travel.md](../design/home_travel.md); do not reimplement it. The Claim Stone as travel-home target belongs to WP24 (`docs/design/housing.md` §8)

## WP22

**Dependencies:** WP43 ✅.

**Status:** **closed as delivered 2026-09-29** (C2, D7, D8). Delivered: slow wear, retained broken items, explicit reference prices and money-only repair at every city profession trainer (Round 11); tool lifetimes; Round 24 shovel and axe tiers and tool level requirements. Dig speed stays as in the game (D8): the authored pick profiles are the authority, with no six-pick speed calibration. Too weak a pick cannot dig at all (Round 24 ruling 3); there are no under-tier destruction penalties. The repair price-source switch belongs to WP44. Repair at crafting stations inside a claim, at the trader price, is decided (D7) and tracked as a Housing follow-up in BACKLOG. Specs: `durability_repair.md`, `items_crafting.md`, `economy.md`

## WP23

**Dependencies:** —

**Status:** **closed as delivered 2026-09-29** (C1). The encounter runtime shipped in Rounds 8–10: two dragons with regional variants, three perches, telegraphed breath/dive/lightning, 30-minute persistent respawn with the 60-second warning (late-loaded lairs included), 24-hour per-dragon loot lockouts, the 60-node ledger with 60-second death grace, the pending-loot queue and the dragon/apex-camp POI art. The remainder is folded in: the boat route to both islands → WP17; the PvP tag and HUD on the islands → WP41. The apex gem sockets are gone (renewable ores removed, E5) and there is no hoard chest (E11), so nothing moves to WP34. GUI acceptance of the encounters happens in ordinary playtests

## WP24

**Dependencies:** WP40.

**Status:** delivered in Round 25 (rulings 1–29, 2026-09-29), user playtest pending; plan, lanes and completion in [round25-housing-plan.md](round25-housing-plan.md#completion-2026-09-29)

**Claim Stone housing** exactly as `docs/design/housing.md`: the `grug_housing` mod with a mod-storage claim registry and grid index; one 101 × 101 claim column from y = −100 up per player; placement in the own faction's level-11–30 home zones by conservative sampling, clear of hard protection, POI/village/camp areas and other claims, with a free 3 × 3 × 3 arrival cube; the soulbound `grug_housing:claim_stone` from the Housing Steward in every capital at level 20; once-a-day place and pick-up limits (replaced in Round 26 by the draft, activation and a 12 h pick-up lock after activation, `housing.md` §§2a, 3); coal lump/charcoal fuel as a `paid_until` timestamp (26 160 s per lump, 99 slots, the housing.md §4 slot arithmetic); empty-fuel expiry and pick destruction times; Interact/Everything permissions; the generic right-click and node-inventory guard; the stone formspec and character-page status; no natural renewal and no hostile spawns in active claims; the claim as `grug_home` travel-home target with fallback to the bound innkeeper and respawn unchanged at the innkeeper; removal of the housing masks and coastal housing areas from the zone data. Road and POI world protection (Round 25 Lane E, `docs/design/world.md` §2 R1b) ships alongside but is independent of housing

## WP27

**Dependencies:** WP26 ✅, WP43 ✅.

**Status:** **closed as delivered 2026-09-29** (C1). The twelve metal/cloth/leather shapes on the shared equipment ladder are registered, universally craftable and have their visuals (Round 10 EQUIP/ART). The former "T4–T6 G2 material rotation" clause was wrong: Round 10 ruling 7 removed the regional-gem surcharge on base equipment (`items_crafting.md` §3.8). The cultural-visual metadata seam belongs to WP5's finish channel

## WP28

**Dependencies:** —

**Status:** **delivered in Round 26 Lane R** (2026-09-29, [plan](round26-capitals-housing-cleanup-plan.md) rulings 13–16). The Mese/Diamond tools, gems, lights and vendored swords were already unregistered.

Delivered:
- The mobs_redo utility items are removed — nametag, net, lasso, shears, protector, protector2, mob repellent and saddle (D5) — with their textures, recipes and recipe-book routes.
- The silver-sandstone recipes are removed (D6; silver sand has no natural source); the silver sand and sandstone nodes stay, because authored builds place them.
- One tool namespace (D9): all 24 tier tools are `grug_materials:{pick,axe,shovel}_{wood,stone,bronze,steel,…}`. Twelve engine aliases from the former `default:` names (`grug_materials.TOOL_ALIASES` in `grug_materials/tools.lua`) keep repo references working; this is the ruling-14 exception to the fresh-server "no legacy aliases" rule, not an old-world migration. The Steel pick is craftable from steel bars. A startup audit (`grug_materials/audit.lua`) enforces the namespace.
- Bone Weevil (both rows) and Bog Fowl `chance` 2200 → 2933, that is 0.75 × density (C6, from the closed WP37).
- The clay clause is dropped: clay is generated again (swamp and wetland pockets).

Left over: `tools/wp13/node_tiles.json`, a generated file, still lists `mobs:mob_repellent` until it is regenerated

## WP29

**Dependencies:** WP26 ✅, WP43 ✅.

**Status:** **closed as delivered 2026-09-29** (C1). The material-named six-tier ladder (Bronze, Iron, Steel, Silversteel, Embersteel, Abyssal Steel, plus cloth/leather/wood grades) is merged (WP13 Round 2, Round 10, Round 24); pick, axe and shovel exist at all six tiers with exact `grug_pick_tier`/`grug_axe_tier`/`grug_shovel_tier` groups and the `grug_materials.tool_tier_for_stack` resolver; Grudgesteel is removed; the authored pick profiles are the dig-time authority (D8). The tool-namespace unification moves to WP28 in Round 26 (D9); cultural/PvP seams belong to WP5

## WP30

**Dependencies:** —

**Status:** **closed 2026-09-29, merged into WP44** (C2). Material-named catalogs, the fixed items, the hourly rotation with one withheld family and the one-in-five Uncommon at ×3 are delivered. The switch to WP44's Common price axis and 5% buy-back is WP44's; the "high-tier Common does not erase demand" check is part of WP5's loot/demand audit

## WP31

**Dependencies:** WP40 ✅.

**Status:** **delivered 2026-09-29** (C3: earlier mount playtests count as acceptance). Four riding tiers, persistent ownership and ephemeral controller/visual, damage dismount, geographic flight rules, capital-only trainers, first-person owner hiding, untimed status, nominal one-node land steps, mounted-attack refusal and Skills recovery. The four mount prices come from WP44's income estimate since Round 29 (1s10c / 7s / 1g37s / 7g33s, `mounts.md`); boats are the water mode since Round 29 (WP17); the removal of the taming items is WP28

## WP32

**Dependencies:** WP24 ✅, WP33 ✅.

**Status:** **delivered 2026-09-29, GUI acceptance pending** (C4). All seventeen crop lifecycles, legal-ground farming and world acquisition; Round 11 seed icons, seven hoes, water buckets and halved wild-source density; Round 23 habitat-driven renewal; the Claim Stone integration shipped with WP24 (harvesting counts as digging, no wild renewal in active claims, engine growth continues).

Farming: all 17 crop families have seed, wet-soil growth, pause/resume and harvest/replant mechanics; MAP-B supplies world acquisition, secondary/field soils and sea/cave placement.

## WP34

**Dependencies:** WP6 ✅, WP40 ✅.

**Status:** **the depth pulse only; kept, for later** (E5). Renewable camp resources are removed entirely (E5). Already delivered: the three-levels-per-50-node depth curve (`wp40/zones.lua` `depth_level`, `combat_stats.md` §3), contested deep from y = −701 and the deep T6 density multipliers (+25 %/+50 %).

Implement the player-centric deep spawn pulse of `biomes_mobs.md` §4.1. The Land Guard and the Rift Spawn's deep row, today ordinary ABM rows below −1000, join it (E4); the Rift Spawn's surface row stays. Its placement geometry and the servant roster below −1000 stay open in `TODO-design-depth.md`. The T6 lava lakes of `world.md` §4c stay planned (E3); they are terrain work outside the pulse and have no scheduled owner yet

## WP37

**Dependencies:** WP6 ✅.

**Status:** **closed 2026-09-29** (C1, C6). The old task — cut surface density to 0.75 (`biomes_mobs.md` §4, decided 2026-08-08; its wording "multiply `chance` by 0.75" was inverted, since mobs_redo's `chance` is one spawn per N tries) — is superseded by the Round 16 fightable-only increase and the Round 24 ruling 27 per-zone density budget (about 1.5×, `grug_mobs/density.lua`). Only the two surface critters keep the cut: Bone Weevil (both rows) and Bog Fowl go from `chance` 2200 to 2933, `aoc` unchanged, delivered with WP28 in Round 26 Lane R. `biomes_mobs.md` §4 records the closure

## WP41

**Dependencies:** WP39 ✅, WP40 ✅. WP5 is not a prerequisite: WP41 only reserves the finish and Warding Draught hook points.

**Status:** open; **V1 scope** (B4). Today hostile PvP is gated only by faction, everywhere, including peaceful home zones. The geography seam is delivered (`grug_zones.pvp_rule_at` with the y = −701 override, 12 contested zones), and so are the enemy-vendor and innkeeper refusals. No `grug_pvp` mod, tag or HUD exists.

PvP tag and geographic eligibility: implement exactly `world_zones.md` §15 through one `grug_pvp` seam across melee, authoritative swings, casts, AoE, projectiles, support and protected faction combatants; preserve the four-row peaceful transaction, contested forcing, y = −701 override, support/damage refresh rules, boundary snapshots, death/reconnect and UI states (tag, HUD, Target Frame icons), the dragon islands from the closed WP23 included. Coverage also includes what postdates the brief: mounts and flight, the Round 20 input contract, the 2026-09-28 combat-state model (`combat_stats.md` §5), the Scout and boats. The engineering brief `docs/research/wp41-engineering-brief.md` (2026-08-13) is stale in two places: its 25 % death-XP rule with a PvP exemption is gone (all deaths cost no XP, `progression.md` §3), and so is its Home Stone channel interruption (Round 25: the Claim Stone travel home replaced the channel, `world.md` §6)

## WP42

**Dependencies:** WP13 ✅ (clash art, Round 20), WP40 ✅; WP41 optional.

**Status:** open; **after V1** (B5): scripted NPC battles are post-V1 content, while small PvP POIs (forts and camps with NPCs) may come in V1. WP42 may ship before WP41 (B6), with war units treating enemy-faction players as hostile until the `grug_pvp` seam exists. All 16 clash anchors and their POI art exist; no war-unit runtime exists.

Bounded war-front life: implement `world_zones.md` §16's sixteen clash anchors across eight activity zones, one matched four-vs-four clash per zone, deterministic 8–14-minute windows, activation/withdrawal caps, no catch-up/refill, exact targeting and player-involvement loot, with no capture or persistent border changes

## WP44

**Dependencies:** WP7 ✅, WP43 ✅.

**Status:** **delivered in Round 29** (2026-10-02, [economy plan](economy-vendor-plan.md) and its [lane status](economy-vendor-plan.md#lane-status-round-29-2026-10-02), lanes E1, M-res (E2) and E4; E3 dropped); a lighter pass (D1). It absorbed WP7's rebase, WP11's respec price, WP30's price switch and the price parts of WP22 and WP31 (C2). Current rules: [economy.md](../design/economy.md).

**As built:** one price module (`grug_traders/prices.lua`, pure rules in `price_rules.lua`) pays every vendor payout: loot and gathered goods by class value × tier factor, processed goods by their cheapest recipe's inputs, free world materials 0, vendor goods at the ceiling-rounded 5% buy-back capped by their recipe; items carry no price field. The Common gear axis 25c … 25s, shelves by the vendor rule (supplies, consumables, tools, the gear floor and a few T1 basics), the anti-loop audit `output ≤ inputs` including group inputs. Quest copper from weight on the cutover column (Round 29 Q1). Repair at crafting stations inside an active claim at the trainer price (D7). Mount, boat and respec prices from a simple per-band income estimate (`tools/r29_e4/income.py`, `economy.md` §4.1 rounding). Gems are depth-tiered (T1 Citrine … T6 Diamond). The engineering brief `docs/research/wp44-engineering-brief.md` (2026-08-13) is superseded.

## WP50

**Dependencies:** WP40 ✅ (world authority for the map base), WP24 ✅ (Housing Steward marker).

**Status:** **delivered in Round 27** (2026-09-30, [plan and completion](round27-minimap-plan.md#completion-2026-09-30), rulings 1–12), created 2026-09-29 after the Round 26 playtest; short playtest pending. Current rules: [world_map.md](../design/world_map.md).

**Own minimap and map quality:** replace Luanti's native minimap with our own round, north-up HUD minimap (top right, one zoom level of about 900 nodes, rotating player arrow) drawn from the pre-generated world map, showing party members (with rim arrows when out of range), quest givers with their state, the Housing Steward, trainers, innkeepers and the player's home; the native minimap is switched off. A `minetest.conf` setting chooses the base map quality — normal (today's 1080×960, default) or high (about 2 nodes per pixel, no edge above 4096 px) — and the Map tab uses the same image. Both qualities get readable relief (stronger hillshading, contour lines, elevation tint). The map window snaps to a coarse grid so the client texture cache stays bounded; a per-player toggle lives on the Map tab.

Delivered as built: normal 1080×960 and high 3600×3200 (relief grid 8 / 4 nodes), sent as 512 px tiles (6 / 56); Lambert hillshade, 16-node contours with 64-node index lines, stone tint above y 60; the minimap in the native minimap's box (25 % of the window height), a window of about 900 nodes snapped to 16 / 64 base pixels (since the [glide follow-up](round27-minimap-plan.md#follow-up-gliding-minimap-2026-09-30) about 880 nodes gliding under a centred arrow, one texture per 6 / 16 base-pixel cell), 24 marker slots with quest givers first, nine party slots with rim arrows, change-only HUD updates, the "Show minimap" switch (or "No minimap available"); the region-label scrollbar fix. Left over: the [Round 27 carry-overs](../../BACKLOG.md#round-27-carry-overs)
