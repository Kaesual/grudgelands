# Remaining work-package scopes

Detailed scope subordinate to [BACKLOG](../../BACKLOG.md) and current
[design](../design/README.md). Extracted during the documentation consolidation
from the pending package rows, retaining unique acceptance requirements.
Completed implementation narratives remain in the
[historical backlog](../archive/planning/backlog-before-consolidation.md).

These are approved broader goals with partial deliveries, not fresh implementation
briefs. Before execution subtract the delivered slices listed here and in BACKLOG,
check current topic rules and refresh stale source-line references. Earlier
migration/alias language is not authorization under fresh-server mode. A target
not yet implemented remains a target; this document does not certify the code.

## WP5

**Dependencies:** WP1 ✅, WP3 ✅, WP43 ✅.

**Status:** open; ready — the named fixed-tier enchant contract is decided in `docs/design/crafting_equipment_revision.md` (2026-09-21), no design blocker remains and every dependency is shipped; task card: `docs/research/wp5-task-card.md`; specs: `items_crafting.md` §§5–7 and `inventory_equipment.md` Round 13 replaces refinement with selected fixed-tier enchantments; the broader loot, cultural/PvP-finish and masterwork scope remains open.

Loot and enchantments: implement the one-prefix/one-suffix family-filtered system, level/quality metadata and tier-correct found-item drops. (The former "remove the retired Amplifier path" clause is **already satisfied and dropped**: the only design mention is the tombstone in `items_crafting.md:25` listing it among the things absent from the target, and no Lua file under `mods/` contains the word, so there is nothing to retire — verified 2026-08-13.) Add one per-stack cultural-finish channel and one separate target-race PvP-special channel with their fixed caps/overwrite rules, while keeping universal affixes independent. Implement the revised Fallen Crown masterwork conversion and retune elite/high-tier gear drops against G2 and trophy demand

## WP9

**Dependencies:** WP6, WP8, WP40, WP41.

**Status:** open; Round 20 expands the 102 earlier quests to 240 starter/capital/regional quests, not the full progression story; the death/XP consequence is revised (all deaths cost no XP, `progression.md` §3, 2026-09-23); geography and quest-interaction slots are fixed in `world_zones.md` §§8/16

Mandatory questlines: named-zone progression, first PvP quests through Ashenward March / Bannerbreak Mesa and The Broken Causeway, war-front guards, elite quests and level gates; all deaths now cost no XP under Round 18, so no PvP-only XP exemption wiring remains

## WP10

**Dependencies:** WP26 ✅, WP33 ✅, WP43 ✅, WP44.

**Status:** in progress: framework, Cooking and Alchemy are on main. Independently clean Round-10 EQUIP and CAP are delivered on main: seven-primary catalogs, Basics provenance, universal base recipes, improvement operations and owning public stations. Final technical gates pass; main delivery, synchronization and push are complete. Round 11 additionally delivers family-filtered improvements, ordinary offhands/bags and money-only trainer repair. Cultural services and the WP44-priced remainder stay open.

Professions: seven primaries plus secondary Cooking; two primary slots; exclusive Basics and owning-profession books; independent T1–T6 recipe progression and four mastery bands; universal plain feedstocks/base gear; specialist catalogs and named fixed-tier enchantment operations. Weaponsmith and Armorsmith are separate professions sharing the Forge; no Blacksmith alias.

## WP11

**Dependencies:** WP3 ✅, WP4 ✅, WP-Speed ✅.

**Status:** in progress: X1/X2/X4 and Scout's complete trees are implemented. Round 11 delivers Ironbound/Unbroken; Round 12 completes the original three classes' X3 consumers; only WP44 respec-price calibration remains. X4 ships the sfinv page, read-only `/talents`, removes `/talent` and `/respec`, and implements free-first/paid respec through `grug_money.take`; its six copper values are an explicit coordinator placeholder until WP44 publishes measured ledger outputs (spec: `docs/design/skill_trees.md` rev 2 + `progression.md` §2; user rulings 2026-09-16)

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

These 70 slots now have authored compositions in the Round 20 candidate; final
gates and GUI acceptance are recorded in STATUS. Existing banners, mobs, bosses
and functional anchors are preserved. Do not schedule these as 70 empty sites. The earlier phrase
“100 POIs” conflated the whole anchor roster with the 88 non-civic slots.

- The two shipwright plots/display hulls are present in Whitebridge Shire and
  Whispering Reedlands village slots; their level-30 teaching transaction remains WP17.
- Keep mining/apex socket ownership in WP34 (twelve renewable sockets per apex
  camp), encounter behavior in WP23/WP42 and structure dressing in WP13.
- **Known correction:** `bandit_frontier` building core is decided at **24 nodes**
  but implemented at **16** in the recorded deviation; design stays 24. This
  remains an explicit correction/verification task, preserved from the
  [earlier backlog readiness record](../archive/planning/backlog-before-consolidation.md#readiness-updated-2026-09-20).
- Preserve complete civic-envelope plus ten-node apron protection; ordinary
  village/outpost/camp shells stay mutable and claim-excluded, with only bounded
  functional anchors and irreplaceable routes hard-protected.
- Preserve king/reset/participation/Crown reward acceptance; do not respawn the
  already-delivered king/guard roster as though missing.
- User GUI acceptance remains open where no explicit acceptance is recorded.

Roster provenance: [WP13 contract](../research/wp13-capitals-pois-contract.md),
[R14 anchor identities](../research/round14-poi-work.md),
[R15 recomposition](../research/round15-poi-work.md), current `world_zones.md`.

## WP14

**Dependencies:** WP3.

**Status:** in progress: Round 11 delivers the ordinary offhand catalog, stats and active equipment checks. Carried light remains open; specs: `combat_stats.md` §7 and `inventory_equipment.md` §2.

Offhand and carried light: live shields, caster books, the bow-only zero-hand quiver exception and authoritative two-hand pairing; later profiled torch light radius.

## WP17

**Dependencies:** WP24, WP40.

**Status:** open; design-complete — the playable-boat contract is decided (2026-08-13, `docs/design/boats.md`)

Travel: waypoint nodes at starts, capitals and authored zone hubs; visit-unlock and travel formspec; `/unstuck`; and the claim-bound Home Stone from `docs/design/housing.md` §4. Home stores a stable claim id, has no capital fallback and is rebound only by interacting with an active owned Claim Stone. It also **implements `docs/design/boats.md`**: the always-craftable five-wood base boat, the improved boat plus the permanent Improved Boat unlock the shipwright teaches from level 30, item↔entity lifecycle, exactly one player per boat with no mob or NPC passenger, free pickup/placement with the driver-only exception, the 24-hour decay of an unused boat, 4/8 nodes per second as entity velocity, and eject-on-damage through both seams (the boat entity's `on_punch` and the central `grug_core` HP-change hook). It also ships the three ocean-danger prerequisites that contract depends on: the mobs_redo attack-cadence patch of `combat_stats.md` §4, the Kraken Guard retune of `biomes_mobs.md` §3 (`run_velocity` 5 (owner ruling 2026-09-17), `view_range` 40) and the **position-dependent pursuit state** of `world.md` §2b — relentless while the guard itself stands in a deep-ocean column, the complete §4 leash/evade model in shelf water, planned water and dragon channels, switched at the guard's own position and never reversed once it evades. That third piece **replaces shipped behaviour**, and it is three fields, not one: `_grug_no_leash = true`, the mob's own 200-node coastal `LEASH_SLACK`/`strayed()` special case and `_grug_soft_deaggro = false` (`mods/ENTITIES/grug_mobs/kraken.lua:10`, `:37`, `:38`) all retire as blanket exceptions and come back position-dependent — suspended inside a deep-ocean column, ordinary outside it. Missing the soft-de-aggro half breaks the contract in both directions: left global, the guard keeps its running speed on the shelf instead of dropping to walking speed at 25 m; removed globally, an 8 nodes/s boat outruns a walking guard on the open sea. Deep-ocean-only spawning needs no new mechanism — `_grug_spawn_check` is already `grug_core.open_sea_at` (`kraken.lua:31`), which WP40 narrows to `deep_ocean`. The cadence foundation has later shipped; verify current shared seams rather than reimplementing its original patch. The boat/deep-ocean acceptance remains outstanding; speed 5 alone does not establish danger against an 8-nodes/s improved boat. The shipwright NPC itself is WP13 village content; until it stands, the improved boat is unobtainable while the base boat is not

## WP21

**Dependencies:** WP1.

**Status:** open (spec: `docs/design/combat_stats.md` §5, `docs/design/progression.md` §1, `docs/design/housing.md` §4)

Recovery & rest: out-of-combat HP regen (0.5%/s), food recovery, innkeeper rested-XP/recovery service and any remaining rest integration. Innkeeper home binding/return/death respawn is already delivered by [home_travel.md](../design/home_travel.md); do not reimplement it. The separate future claim-bound Home Stone remains WP17 and is bound through the active owned claim, not an innkeeper

## WP22

**Dependencies:** WP5, WP7, WP43, WP44.

**Status:** in progress: Round 11 delivers slow wear, retained broken items, explicit reference prices and money-only repair at every city profession trainer; the future Housing station provider seam is available. Six-pick speed calibration and future Housing station integration remain. Material/profession repair is only a possible future discussion, not approved implementation scope. Specs: `durability_repair.md`, `items_crafting.md` and `economy.md`

Durability and repair: effect loss at zero durability, NPC repair for ledger money and tier-scaled costs; preserve the current T1–T6 combat budgets 1000/1500/2000/2500/3000/4000 from [durability_repair.md](../design/durability_repair.md). Refinement and doubled lifetime are removed. Calibrate the still-open six pick dig-time values; retain the already-decided tier lifetimes in the WP29-authored table (the B22 frame, `items_crafting.md` §3.0.4) and the usable-block targets for all six picks, including the fixed ×4/×6/×8/×10 under-tier destruction penalties. Do not derive speed or wear from the retired engine `leveldiff` coupling

## WP23

**Dependencies:** WP13, WP17, WP34, WP40, WP41, WP43.

**Status:** open; design-ready encounter rules, no design blocker left — the boat contract was decided 2026-08-13 (`docs/design/boats.md`); waits only on the listed implementation foundations Reviewed Round-9/10 dragon runtime and behavior corrections are present; complete encounter infrastructure and boat/PvP/apex dependencies remain open.

Apex world bosses: populate the two offshore level-60 dragon islands, The Wyrmglass Crown and Stormscale Summit, with equivalent authored arenas, telegraphs, hoards, regional variants, reset/participation cleanup, separate 24-hour loot lockouts and persistent 30-minute respawn plus 60-second warning. Both islands stay contested; each requires WP17's playable boats and their authored route, a WP40 island/map foundation, WP13 structures, WP34 renewable apex resources and WP41 PvP. The base boat alone reaches either island, so no part of this WP waits for the shipwright or the improved boat

## WP24

**Dependencies:** WP40, WP43, WP44.

**Status:** open; design-ready, waits for WP40's final housing masks/capacity and WP43/WP44 material/economy APIs

**Open-world Claim Stone housing:** implement `grug_housing` from `docs/design/housing.md`: ten peaceful level-11–30 eligibility masks; four active cube tiers (radii 20/30/40/50); immediate 101×101 future reservation; exact one-sided expanded-AABB ten-node inter-owner spacing; owner plus ten same-faction trusted characters; indirect-mutation and natural-spawn protection; claim-excluded roads/POIs versus bounded hard-protected anchors; Steward issuance and pool UI; atomic upgrades/additional-stone purchases; reserved arrival column; and AreaStore-backed point/reservation/exclusion indexes over canonical mod-storage records. Implement the stable-id generation-safe state machine across placed, inventory, recovery escrow, transient and dormant locations, with live-slot accounting, on-demand inactivity decay, voluntary/forced dormancy, forced recovery, stale-copy rejection, recovery notices, reissue and administration. Expose the active-claim/home hooks consumed by WP17. The accepted fixed-layout packing portfolio informs the per-faction live limits; WP24 itself selects and configures the defaults below demonstrated capacity (`housing.md` §10). Varying-seed height/content conformance is separate, and ledger copper values remain measured outputs owned with WP44, not open design

## WP27

**Dependencies:** WP26, WP43.

**Status:** open; specs: `items_crafting.md` armor tables and `inventory_equipment.md` Round-10 EQUIP supplies universal base armor and ART its visuals; retain whole-WP acceptance and remaining dependencies separately.

Armor base recipes: register the twelve metal/cloth/leather shapes on the one shared equipment ladder; apply the decided T4–T6 G2 material rotation and cultural-visual metadata seams without creating parallel cultural catalogs. Every base recipe remains universally craftable; professions add enchantments or special finishing

## WP28

**Dependencies:** WP29, WP40 R7.

**Status:** open

Vendored-recipe cleanup: remove superseded Mese/Diamond tool registrations and their live consumers only after WP29 supplies every replacement pick/tool; remove the conflicting mobs_redo protector, naming and taming utility items and all recipes/branches that reference them. R7 deliberately removes the last world sources of clay and silver sand: remove their clay-lump/brick and silver-sandstone recipe families unless another authoritative design supplies a replacement source before this WP; do not invent one here. Update VENDOR patch inventory and boot a fresh world without unknown items, duplicate recipes, missing ingredients or permanently unreachable recipes

## WP29

**Dependencies:** WP26, WP27, WP43.

**Status:** open; specs: `items_crafting.md` and `inventory_equipment.md` Round-10 EQUIP/ART supply the current gear/tool catalogs, base recipes and visuals; the broader replacement/deletion/economy chain remains open.

Merge `grug_gear` with the six-tier base ladder and migrate names to Bronze, Iron, Steel, Silversteel, Embersteel and Abyssal Steel (plus the decided cloth/leather/wood grades, `items_crafting.md` §§3.4/3.5/3.6a). The leather line is Scout's primary armor and remains the Warrior's legal light set (§3.8). Implement the iron metal-pick gate (`grug_metal_pick` flag on Bronze+ picks, `metal_only` iron row in the central `mining_decision` — §3.0.1, decided 2026-08-13) and author the B22 pick `times`/`uses` table for WP22's runtime calibration (§3.0.4 frame). Implement complete per-stack pick depth and separate natural-resource harvest-tier metadata; assign exact integer `grug_pick_tier`, `grug_axe_tier` and `grug_shovel_tier` groups in 1..6 to the final tools and make `grug_materials.tool_tier_for_stack(stack, family)` their sole fail-closed family/tier resolver for WP33's concentrated sources. Preserve cultural/PvP-special seams and remove Grudgesteel terminology without changing slot identity

## WP30

**Dependencies:** WP5, WP29, WP44.

**Status:** open

Trader catalog retrofit: audit generated catalog names and rotations after WP29, retain an intentional hourly withheld-family rotation, and verify high-tier Common availability does not erase G2/cultural/masterwork demand. Consume WP44's Common price axis and 5% buy-back rather than the shipped legacy price curve

## WP31

**Dependencies:** WP28, WP40, WP44.

**Status:** in progress: reviewed Round 10 foundations plus Round 11 shared rider/mount orientation, open stables and animated grounded displays are delivered. GUI acceptance and the WP44 economy calibration remain; this is not whole-WP completion.

Mounts: four riding tiers, persistent ownership and ephemeral controller/visual, damage dismount, geographic flight rules, capital-only trainers, first-person owner hiding, untimed status, nominal one-node land steps and mounted-attack refusal. WP44 later recalibrates the accepted interim prices.

## WP32

**Dependencies:** WP10, WP24, WP33.

**Status:** in progress: all seventeen crop lifecycles, legal-ground farming and world acquisition are delivered. Round 11 adds distinct seed icons, seven hoes, water buckets, halved wild-source density and bounded depletion renewal. GUI acceptance remains; future Claim Stone integration belongs to WP24.

Farming: all 17 crop families have seed, wet-soil growth, pause/resume and harvest/replant mechanics; MAP-B supplies world acquisition, secondary/field soils and sea/cave placement. Later active-claim integration retains the exhaustive ten-node growth audit.

## WP34

**Dependencies:** WP6, WP13, WP40, WP43, WP44.

**Status:** open

Depth/resource economy retrofit: implement the player-centric deep spawn pulse; retain the already-delivered three-levels-per-50-node depth curve (`wp40/zones.lua` depth_level, specified in combat_stats.md §3); re-scope renewable mining to protected regional and apex camp sockets with the fixed 2–4 h refill; add bounded T6 lava terrain; apply revised continental Abyssal/G1/G2 density multipliers and contested-deep access. Keep ordinary depth spawns and the unresolved pulse placement geometry/servant roster in `TODO-design-depth.md`. This is not an independent next WP: it requires final map geometry, replacement materials, built structures and the rebased economy/resource audit

## WP37

**Dependencies:** WP6 ✅.

**Status:** Paused for explicit reconciliation with R16 fightable-only +30%; no density change authorized by documentation cleanup.

**Apply the 0.75 surface-density multiplier** (`biomes_mobs.md` §4, decided 2026-08-08, never implemented). §4's table already prints the decided post-multiplication `chance` for every surface row, but `grug_mobs` still passes the pre-multiplication WP6 numbers to `mobs:spawn` — **every shipped surface `chance` is exactly the table value ÷ 0.75** (Boar 1500/1125, Rabbit-Hare 1800/1350, Zombie 1600/1200, Wolf-Blightfang 1500/1125, Hyena 1500/1125, Jungle Lynx 1500/1125, Bear-Plaguehide 2800/2100, Jungle Ape 2800/2100, Stag-Gaunt Stag-Zebra 1800/1350, Skeleton Archer + Raider 2000/1500, Crag Eagle-Vulture 2000/1500, Ram 2200/1650, Panther 1800/1350, Serpent 1800/1350, Crocodile 1800/1350, Bog Ooze 2000/1500, Parrot + Carrion Crow + Gull 2500/1875, and the **two SURFACE critters of §3.0** — Bone Weevil 2200/1650 and Bog Fowl 2200/1650). The **five** documented exclusions (Giant Spider 1800, Stone/Mesa Golem 9000, Kraken Guard 12000, **Cave Bat 2200 and Cave Crawler 2200**) already match code and must stay untouched. The two cave critters were briefly listed here as multipliable and are not: they are `underground`-ONLY rows (`nodes = {"default:stone", "group:grug_stratum"}`, `max 5` light, y −31000…−40), so they have no surface half at all, and §4's exclusion — cave pressure belongs to §4.1's depth pulse, which is WP34's — covers them a fortiori (WP34 piece (3) scopes it the same way). Multiplying them would refill the underground cell WP36 calibrated to exactly the night peak (9/9 → 12/12) a third faster. Work: multiply the `chance` of every non-excluded `mobs:spawn` row in `mods/ENTITIES/grug_mobs/*.lua` by 0.75, **re-sync the `-- §4 row ...` quotations in those same files** (they quote the shipped number, so they read as false citations of §4 today — flagged in §4's own header), drop that header's "DECIDED, NOT YET IMPLEMENTED" caveat, and re-run the budget audit (`wp6_spawn_budget.md`) against the new values as §4 promises. `aoc` must NOT move — it is the per-name ceiling the 100-player calibration rests on. Found by the WP36 item-4 review (LOW 3), which fixed the documentation and deliberately left the roster alone.

## WP41

**Dependencies:** WP5, WP39, WP40.

**Status:** open; design-ready after WP40 zone authority; engineering brief: `docs/research/wp41-engineering-brief.md`

PvP tag and geographic eligibility: implement exactly `world_zones.md` §15 through one `grug_pvp` seam across melee, authoritative swings, casts, AoE, projectiles, support and protected faction combatants; preserve the four-row peaceful transaction, contested forcing, y = −701 override, support/damage refresh rules, boundary snapshots, death/reconnect and UI states. Consume the per-stack target-race weapon finish and Warding Draught effects through this seam

## WP42

**Dependencies:** WP13, WP40, WP41.

**Status:** open; design-ready, behind map and PvP

Bounded war-front life: implement `world_zones.md` §16's sixteen clash anchors across eight activity zones, one matched four-vs-four clash per zone, deterministic 8–14-minute windows, activation/withdrawal caps, no catch-up/refill, exact targeting and player-involvement loot, with no capture or persistent border changes. Anchor to the final Battlegrounds/offshore-front map; WP13 owns surrounding structure art

## WP44

**Dependencies:** WP7 ✅, WP43.

**Status:** open; design-ready against WP43's shipped final material ids; engineering brief: `docs/research/wp44-engineering-brief.md`

**Economy Rebase:** migrate the shipped WP7 legacy economy without rewriting its Completion Record. Implement the fixed Common-weapon axis 25c/65c/1s60c/4s/10s/25s and derived slot tables, ceiling-rounded 5% buy-back, revised material/gem/Gold/Abyssal/trophy values and the 50%-of-Common cultural-master service fees. Add a reproducible Income Ledger that measures reliable tier-appropriate net solo income after repairs/consumables and excludes rare jackpots, world bosses and player trade; use it to calibrate Claim Stone upgrade/additional-stone costs and the four mount targets (15m/45m/2h/5h) with the published rounding rules. Keep money ledger-only and rerun every anti-profit-loop/trader-substitution audit — including the **two coverage gaps in the shipped third audit** that the 2026-08-13 boat round surfaced: a recipe with any unpriced input is skipped whole, which silently exempts every `group:`-input recipe (`mods/ENTITIES/grug_traders/init.lua:257-261`), and the comparison is `output > inputs` while `items_crafting.md` §3.8 requires strictly below, so a break-even craft passes (`:269`)

