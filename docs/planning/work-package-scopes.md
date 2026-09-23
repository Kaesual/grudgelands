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

**Status:** open; Rounds 14–15 deliver 66 starter + 36 local quests, not the full progression story; the death/XP consequence is revised (all deaths cost no XP, `progression.md` §3, 2026-09-23); geography and quest-interaction slots are fixed in `world_zones.md` §§8/16

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

**Dependencies:** WP40 ✅, WP43 ✅.

**Status:** in progress (2026-09-14 … 2026-09-19): first two Hearthpine increments accepted/reviewed; the user's nine-building playtest found the houses plainer than VoxeLibre villages. Third increment (same day): reusable building library `grug_mapgen/wp13/` (palette roles, rotation, stair roofs, generators, interiors, dressing, layout) rebuilds Hearthpine as a dense pine-wood clearing with doors, pane windows, stair roofs, furnished interiors and dressing; plus the atmosphere layer, seven vendored minetest_game building mods, the curated 333-node `grug_decor` kit and the textured blueprint renderer. Increments 4-8 (2026-09-14) built the remaining five starts on that library: Dawnmere Fields (human), then Silverleaf Glade (elf), Stillgrave Hollow (undead), Sunscar Camp (orc) and Kapok Cradle (troll) in four parallel lanes, merged onto one branch and given one combined review-fix round. **All six starts are built and byte-frozen; none is accepted until the user has walked it.** Contract: `docs/research/wp13-settlement-pipeline.md`; record: `docs/research/wp13-hearthpine-library.md` (per-start notes `wp13-dawnmere-fields.md`, `wp13-silverleaf.md`, `wp13-stillgrave.md`, `wp13-sunscar-camp.md`, `wp13-kapok.md`); earlier briefs: `docs/research/wp13-hearthpine-brief.md`, `docs/research/wp13-hearthpine-polish.md`. Round-A playtest rulings of 2026-09-14, shipped alongside the six starts: the server preloads all six start envelopes at startup and character creation waits for 6/6, and no hostile spawn is accepted inside the six 148 x 148 start footprints (`docs/research/wp13-start-preload.md`). Focused GUI playtest of all six remains pending; all six capitals, their kings and royal guards now stand, while villages, outposts and camps remain in this WP. Increment 9 (2026-09-14) adds the CAPITAL PARTS library `grug_mapgen/wp13/capitals.lua`: eighteen generators a later composition lane assembles into the six capital cores and districts -- a basilica king's hall with a throne room, curtain wall, corner tower and gatehouse for the three walled races, colonnade, market square, well court and statue plinth, barracks, temple, scriptorium, granary and stable, and hedge, grove, stilt and water edge pieces for the three open ones. It also ships the capital palette vocabulary (the castle kit plus one signature material per race) and the NPC socket seam of `docs/research/wp13-npc-sockets-contract.md`. Record: `docs/research/wp13-capital-library.md`. Nothing is wired into a settlement yet and the six start blueprints are byte-identical. Increment 10 (2026-09-14, review-fixed 2026-09-15) composes the PILOT CAPITAL out of them: `grug_mapgen/wp13/highcourt.lua` is Highcourt's 96 x 96 civic core (king's hall and throne approach, four gatehouses, market square, two colonnades, chapel with belfry, service court with the contract's two vendor sockets, a waypoint plaza reserved for WP17, five half-timbered houses, orchard-and-hedge edge instead of a curtain wall), `highcourt_district.lua` the market and professions district as nine self-contained plot compositions with their own reference column, foundation skirt to -6 and cleared airspace, and `avenue.lua` the gate avenue as a pure function of a column-surface callback that a successor can run per mapchunk. Core 101,831 cells of the 150,000 budget, a whole capital 159,592 of 400,000, 113 ms under LuaJIT and 350 ms under PUC 5.1. Nothing is wired into the WP40 seam: that generalisation (per-blueprint bounds, several blueprints per settlement, lazy construction) is the next package. Record: `docs/research/wp13-highcourt.md`. Increment 11 (2026-09-15) GENERALISES THE SEAM and puts Highcourt in the world: a roster profile now carries its anchor slot and its own build envelope (start ±63/y -2..24, capital core ±47/y -2..40, district plot ±15/y -6..24, the literal that used to be typed in three places), a settlement may own several blueprints of three kinds (anchor-relative core, terrain-relative plot projected from the pure final height of its own reference column, and the avenue overlay computed per mapchunk), the manifest field order and the successor's key checks are derived from the roster, and a capital's cells are built on the first mapchunk that touches its envelope and released when the map moves away. Measured: core 112 ms / 350 ms and the whole seam's first touch 239 ms / 627 ms under LuaJIT and PUC 5.1, per-mapchunk steady mean 0.452 s against an empty open-land mapchunk's 0.42 s on the same boot, and the real surface under all nine district plots on both gate seeds -- which moved four plots: two whose footprint fell further than the foundation skirt reaches, and then two more when a first sweep for FLAT ground put them in the river that runs through this capital's envelope -- the river bed being the flattest ground a terraced envelope has. `tools/wp13/highcourt_plots.lua` is the predicate that asks both questions at once, and every one of the nine plots is dry, inside the skirt and under its own roof on both seeds. Highcourt registers 95 NPC sockets under its own key and 71 of them carry an NPC, placed when its area is first emerged rather than at server start; its two royal traders moved from the fixed `vendors.lua` offsets onto the core's vendor sockets, and the five capitals without a core keep the offsets. The six start blueprint identities and all twelve six-start engine digests are unchanged on both gate seeds. Record: `docs/research/wp13-seam-generalisation.md`. **ALL SIX CAPITALS STAND (2026-09-16).** Playtest round 3 (2026-09-15) added the capital terrace step bands and per-race capital ground (`wp13-capital-terrain.md`), the smooth-lane/crossing-plateau street rules (`wp13-lane-routes.md`), the decoration anchor fix behind the floating bushes (`wp13-floating-bushes.md`), Highcourt's other three districts and the seeded quadrant permutation (`wp13-highcourt-districts.md`), its wall ring, its fill and its trades (`wp13-highcourt-fill.md`), and the work sockets, 80/20 walker split and first five profession shop vendors (`wp13-npc-work.md`). Wave 2 (2026-09-15/16) built the remaining five capitals, one lane each -- Dur Brannoc (dwarf, `wp13-dur-brannoc.md`), Gor Drazhak (orc, `wp13-gor_drazhak.md`), Lethariel (elf, `wp13-lethariel.md`), Kezamba (troll, `wp13-kezamba.md`) and Nhal Veyr (undead, `wp13-nhal_veyr.md`) -- each with a civic core, four districts of nine plots plus four pieces of open fill ground, its own envelope edge (masonry curtains for Highcourt, Dur Brannoc and Nhal Veyr; a stake palisade on an earth rampart for Gor Drazhak; open planted edges for Lethariel and Kezamba), and its own trades; beside them the six wave-2 work activities and seven further shop kinds (`wp13-npc-vocabulary.md`, twelve kinds total in `grug_traders/vendors.lua`) and the user's routes-end-at-the-gate ruling of playtest round 4 (`wp13-route-gates.md`, contract §2.1.1). Highcourt's socket count moved with the districts and the fill: 256 sockets today (`luajit -e 'io.write(dofile("tools/wp13/highcourt_kat.lua")("."))'` prints guard_patrol 56, guard_post 19, idle 134, king 1, quest 2, spare 26, vendor 7, waypoint 1, work 36), not the 95 of increment 11. Wave 3 (2026-09-16) answered playtest 5: **one street rule for all six capitals** in `wp13/avenue.lua` -- flat cross profile, junction plateaus computed identically by both runs, deck-on-pillars above `MIN_CLEAR` 3 and a railed bridge wherever a street stands over water, measured on nine seeds (worst cross-profile spread 5..8 -> 0, worst spread over a junction square 4..22 -> 0, lamps footing off the street 1089..1244 -> 0, `wp13-street-geometry.md`); **Kezamba**'s pad edge terraced down to the cenote instead of walled and its fields given a crop and a planted bed (`wp13-kezamba.md`); thirteen Highcourt lots moved onto ground nine worlds accept, the basalt roof corners and the troll palette's castle roles (`wp13-polish-wave3.md`); and **fishing** as the new mod `mods/ITEMS/grug_fishing` -- a rod of 64 catches crafted from 3 sticks and 2 Spider Silk, a furnace-cooked fish and six zone-level catch tables selected through `grug_fishing.table_for(pos)` (`wp13-fishing.md`, rows in `items_crafting.md` §2.3). **ROUND 14 INCREMENT:** six home villages, six outposts and six bandit camps now stand at existing anchors with 18 quest sockets and protected displays; the remaining roster is still open. **STILL OPEN IN WP13:** the user's GUI playtest of the six capitals; the remaining portion of the contract's 100-anchor POI roster (`wp13-capitals-pois-contract.md` §2.5, the counts at `:28-31`) -- 12 villages, two of them carrying the shipwright plot and display boat, 24 outposts, 12 bandit camps, 6 mining camps, 4 mirefolk camps, 16 clash anchors, 2 dragon arenas, 2 apex camps and 10 rare-route pads, of which the mirefolk camps, clash anchors and dragon arenas are dressing only here (WP42/WP23 own the encounters) and the apex camps' twelve renewable sockets stay WP34's. Round 8 populated every authored king socket with a level-65 king and four level-60 royal guards, and its final boundary pass closes every capital ring outside the four gate bands. Final scope and anchors: `world_zones.md` §§8/11/12

World structures: six starts, six terrain-fitted capitals, villages/outposts/bandit camps, ordinary peaceful regional mining camps, and two offshore all-six-gem apex mining camps with exactly twelve protected renewable sockets each. Place the **two continental shipwrights** in the mandatory village slots of Whitebridge Shire and Whispering Reedlands with their hard-protected plots and scenery display boats (`docs/design/boats.md` §2 — passive, invulnerable, sells and buys nothing; the level-30 teaching transaction itself is WP17 code). Build six killable kings plus four royal guards per capital, separate invulnerable civic services, fixed reset/participation/24-hour Crown rules and the revised king/guard material reward budgets. Ordinary village/outpost/camp shells remain mutable and claim-excluded; capitals and starting settlements are hard-protected as complete build envelopes plus 10-node aprons with fail-closed indirect-mutation protection (`world.md` §2 R1, decided 2026-08-13); otherwise only bounded functional anchors and irreplaceable route pieces are hard-protected

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

Recovery & rest: out-of-combat HP regen (0.5%/s), food recovery, innkeeper rested-XP/recovery service and NPC anchor/respawn insurance. Innkeepers never bind or rebind the Home Stone; that destination belongs only to WP17's active-claim flow

## WP22

**Dependencies:** WP5, WP7, WP43, WP44.

**Status:** in progress: Round 11 delivers slow wear, retained broken items, explicit reference prices and money-only repair at every city profession trainer; the future Housing station provider seam is available. Six-pick runtime calibration and deferred material/profession repair redesign remain. Specs: `durability_repair.md`, `items_crafting.md` and `economy.md`

Durability and repair: effect loss at zero durability, NPC repair for ledger money and tier-scaled costs; preserve the 3000/6000 combat-event budgets where applicable. Runtime-calibrate the WP29-authored dig-time/durability table (the B22 frame, `items_crafting.md` §3.0.4) and the usable-block targets for all six picks, including the fixed ×4/×6/×8/×10 under-tier destruction penalties. Do not derive speed or wear from the retired engine `leveldiff` coupling

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

Depth/resource economy retrofit: implement the player-centric deep spawn pulse and corrected depth-level curve; re-scope renewable mining to protected regional and apex camp sockets with the fixed 2–4 h refill; add bounded T6 lava terrain; apply revised continental Abyssal/G1/G2 density multipliers and contested-deep access. Keep ordinary depth spawns and the unresolved pulse placement geometry/servant roster in `TODO-design-depth.md`. This is not an independent next WP: it requires final map geometry, replacement materials, built structures and the rebased economy/resource audit

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

