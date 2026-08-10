# Backlog — Work Packages

High-level goals: [ROADMAP.md](ROADMAP.md). This document breaks them down
into **work packages (WPs)**, each doable in a fresh session/context
window. Rules:

- One WP = one coherent, testable increment with commit(s).
- Before starting: read AGENTS.md; check for blocking `TODO-*.md` design
  files; skim the relevant briefings in [docs/research/](docs/research/).
- Design questions are settled in `TODO-<topic>.md` files first and then
  folded into [docs/design/](docs/design/) — WPs implement the design,
  they don't invent it (see AGENTS.md "Documentation layers").
- After finishing: update the status here (✅ + one-liner of what was
  built), keep the ROADMAP checkboxes and the README's "Current State"
  section in sync, run `tools/sync_to_luanti.sh`, commit.
- Insights that future sessions need belong in AGENTS.md (conventions) or
  docs/ (details) — not just in the chat.

## Phase 1 (MVP)

| WP | Title | Status | Depends on |
|----|-------|--------|------------|
| WP0 | Foundation: skeleton, BASE, mobs_redo, grug_core, grug_factions, grug_xp | ✅ | — |
| WP1 | Starter-zone mobs: boar + zombie, XP on kill, loot drops | ✅ (runtime tested 2026-08-07) | WP0 |
| WP2 | Territory mapgen: north/south, race regions per faction, difficulty gradient, capitals | ✅ engine biomes (v7 + min_pos/max_pos) in `grug_mapgen`; zone/difficulty API + is_protected in `grug_core` (runtime tested 2026-08-07) | WP0 |
| WP3 | Classes: Warrior/Mage/Priest, selection dialog, stats via level pipeline | ✅ `grug_classes`: class+race registry, creation flow faction→race→class, attribute/HP formulas via level pipeline, /char /class /race commands (runtime tested 2026-08-07) | WP0 |
| WP4 | Abilities: 2–4 per class, cooldowns, mana/resource HUD (text line per classes.md §1) | ✅ `grug_abilities`: 3 abilities/class as hotbar items (wear = cooldown), mana/rage + HUD, damage pipeline (crit/dodge) in `grug_core` (runtime tested 2026-08-07; spec: `docs/design/classes.md`; kit tuning → WP19) | WP3 |
| WP5 | Loot & affixes (re-cut 2026-08-07): owns the whole **refinement + prefix/suffix system** (`items_crafting.md` §6b) — the refined state (+15 % damage, +100 % durability) as the prerequisite for every affix, **max 2 prefixes + 2 suffixes = 4 slots**, **mastery tier = fillable slots** (Apprentice 1 → Master 4), affix words mapped onto §6.2's per-family stat pools — **six rows since 2026-08-08, the new one being trinkets** (+Str, +Int, +Dex, +HP, +mana, +crit%; the §6.3 cap check was re-run for **8** enchantable slots and crit now clamps at 30 % instead of landing on it) —, quality straight from the affix count (0 Common / 1–2 Uncommon / 3–4 Rare, §6b.6), values rolled from §6.3's four ilvl bands × source window, and the refinement word dropping out of the name as soon as an affix appears (§6b.4). Plus: class items with roll ranges and elite variants; `grug_req_level` on **everything equippable**, derived from the published `_grug_ilvl` and enforced in the slot `allow_put` (`inventory_equipment.md` §2); **found items arrive pre-enchanted** — "only professions can enchant" restricts who may *apply* an affix, not what a mob drops (§6b.3, §5.1) — and **a dropped item's material tier must match the mob's tier** (§5: a T3 Steel item drops from level 21–30 mobs and nowhere else, so the drop table is not a side door around the depth gate). Lights up WP7's ×3 Uncommon rotation slot. **Finding handed over from WP25's review (2026-08-08), loot-table work, not material-ladder work**: `mods/ENTITIES/grug_mobs/golem.lua` drops `default:diamond` at 1-in-8. Since the crafting rework the diamond is the **T6 gem**, but golems spawn in the Outer Ring (L25–45) and in every cave, so the T6 gem is farmable completely past the depth gate — while §5's loot table names "garnet/diamond" only in the Coast 45–60 row. Fix belongs in this WP's drop tables (re-tier the golem drop, or split the gem by mob tier per §5), not in WP25. **Second finding from the same review (2026-08-08), also drop-table work**: §5 sets a dropped item's ilvl to the mob's level *and* binds its material tier to the mob's tier, but the depth axis puts level-54 mobs at −900 — inside Emberrock, which a **T5** pick opens. T6 *gear* is therefore reachable one full tier before T6 *material* is. `TODO-design-depth.md` D10 decided the deep band gets no drop layer of its own, which does not close this: the leak is in the generic depth-axis drop rule, and it belongs in this WP's tables | open (spec: `docs/design/items_crafting.md` §5/§6/§6b, `inventory_equipment.md` §2; **blocked on `TODO-design-crafting-rework.md` A2** — the affix word list — and A6 for the description line) | WP1, WP3 |
| WP6 | Faction mobs & mob feel: guards, outposts, mob tiers by distance + DEPTH, elite mobs (scale/tint + 2 s telegraph), one behavior verb per family, named rares with faction broadcast, boar/zombie retune incl. speed-to-spec + soft de-aggro (25 m), taunt force duration, R4 ore respawn, nametags (level+HP), con-color target frame, gray = no XP; **player-tag drop rule** (loot only with player involvement, 60 s expiry, NPC drops only in PvP; carries the Leatherworker loot hook); nature-mob on-sight aggro vs players AND NPCs; **pathfinding quality pass is a blocker of this WP, not polish** (also carries the high-density target, world.md §8) | ✅ the full `docs/design/biomes_mobs.md` roster in `grug_mobs` — **38 registered mobs in 40 spawn rows**, 10 named rares (§3.3's 9 rows, Bonerattle ×2), guards, camps. Architecture: **level/tier engine** (`levels.lua` — HP/dmg/XP/armor derived from `mob_level_at`/`guard_level_at` + tier multipliers, defs never hand-set them; elite ×1.6 gold, rare ×2 violet, global nametags, con-color target frame at 20 m, gray = no XP); **threat table** in `grug_core/combat.lua` (damage-as-threat, 120 % hysteresis, 40 m validity, heal threat, real taunt) + **leash/evade** (40 m drag from the chase anchor, 15 s contact, untouchable run-home at 1.5× run speed with a 40 s teleport backstop, 45 m give-up, 25 m soft de-aggro); **verb library** (`verbs.lua`: pack, stalker/rush, ambush, webs, poison, damage aura, camp swarm, arrows); **elite/rare telegraph** (4 s first engagement, 10 s cadence, 90° cone at reach + 1.5 m, LOS required); **named-rare spawner** (2–4 h respawn, patrol routes, faction broadcast); **faction guards + 24 deterministic outposts + hourly patrol legs**, POI protection registry (`grug_core.add_poi`), guard banners on the capital platforms; **12 deterministic bandit camps** + mirefolk camps on node timers; **player-tag drop rule** via an api.lua patch; **R4 ore respawn** (depleted-vein placeholder, 15–30 min); **pathfinding/density/perf pass** (four api.lua fixes + the budget audit in `docs/research/wp6_spawn_budget.md`) and a 4-reviewer gate. Runtime tested 2026-08-07 (findings F1–F6, below) | WP1, WP2 |
| WP7 | Money & traders: copper/silver/gold currency (one integer in copper, `docs/design/economy.md`), trader NPCs that buy EVERY mob drop, **six vendor bracket catalogs** (10 levels each, Common at bracket ilvl, hourly rotation with an occasional world-window Uncommon, price ladder ×1.4 per bracket — `items_crafting.md` §3.8/§8.2), trade formspec, race-exclusive vendors + same-race discount, WP6 carry-overs (bandit coin drops, guard PvP loot) | ✅ three mods. **`grug_money`**: ONE copper integer in player meta (economy.md §1), atomic get/set/add/take clamped to 0..2³¹−1, `register_on_change`, HUD line, `/money` (+ admin `/money give`), display rule "leading zero units omitted, copper always shown". **`grug_gear`**: six bracket catalogs GENERATED from the §3.1/§3.2 curves, never hand-listed — **72 items** (4 weapon families × 6 brackets + metal/cloth armor × 4 slots × 6 brackets; leather's curve ships unregistered, nothing can wear it), §8.2 prices VERBATIM, **25 % buy-back** (economy.md §2), and `_grug_ilvl`/`_grug_bracket`/`_grug_quality` as the WP5 seam. **Armor pipeline** — armor was *inert* before this WP: `_grug_armor` → `grug_inventory.get_equipped_armor` (cached per player) → `grug_core.get_armor_percent` (stub-override) → a % reduction in the central hp modifier, punch-only, after dodge, before the absorb shield, capped at 60 % in both consumer and overrider; plus the **armor-rank binding** (cloth 1 < leather 2 < metal 3 vs. Warrior 3 / Mage 1 / Priest 1, group `grug_armor_class`, enforced in the existing equip filter, unequipped on class change). **`grug_traders`**: **8 vendor NPCs** (2 faction Quartermasters + 6 race-exclusive) placed deterministically at the six race capitals **without a mapgen change**, registered through plain `mobs:register_mob` (NOT `grug_mobs.register_mob` — that wrapper is the level engine; `type = "npc"` makes them permanent, a truthy `do_punch` makes them invulnerable); trade formspec with **no detached inventories** (a sell slot loses items on disconnect) and per-action server-side re-validation of session/range/access/prices; **hourly rotation** from a PcgRandom seeded on `floor(os.time()/3600)` + vendor + bracket (9-item fixed floor, 2 of 3 extra weapon families, 1-in-5 Uncommon ×3 gated on WP5's roller); race exclusivity + **10 % same-race discount** on buy prices only (world.md §7); weak healing potion (8c, flat 15 % max HP) on the **shared 60 s** instant-potion cooldown in player meta; three **startup audits** (every mob drop priced, no buy/sell spread that prints money, no craft/cook recipe worth more than its priced inputs). Plus the WP6 loot carry-overs (bandit stolen purse 1/3, guard PvP war trophies + heavy cloth). 3-reviewer gate (correctness/exploits · Lua+perf · design adherence). Runtime tested 2026-08-07, no findings | WP1 |
| WP8 | Quest framework: quest log, kill/gather goals, quest-giver NPCs, min_level per quest | open (story frame: `docs/design/story.md`) | WP1, WP7 |
| WP9 | Mandatory questlines: PvP quests (border guards), elite quests, level gates | open | WP6, WP8 |
| WP10 | Professions (roster re-cut 2026-08-07): 2 free mains out of **six material-cut professions** — Blacksmith, Leatherworker, Tailor, **Woodcarver** (staves/wands/scepters/orbs — casters had no craftable weapon at all), **Goldsmith** (both trinket slots, gem refinement, Gem Detector) — **its trinket family is MVP scope since 2026-08-08** (`inventory_equipment.md` §2, `items_crafting.md` §3.6b: the slots are no longer reserved, so this WP ships the profession's headline product rather than a promise; the slots and their `allow_put` already exist from WP15, and the enchant pool is §6.2's trinket row), Alchemist; **Herbalism is merged into the Alchemist and Gem Hunter into the Goldsmith**, so all six are symmetric (`professions.md` §2). **One recipe book per profession**, six T1–T6 groups in one list (`items_crafting.md` §2.2): **level controls visibility, the keystone controls the unlock** (§2.3 — a visible group shows greyed with its keystone spelled out; redemption is a one-off at the workbench, state in player meta `grug_prof:<prof>`, never in the item), quest/boss/race-signature recipes unlock **inside the same book**, and the LotT-style tome chain is gone. Craft permission = the universal base ladder (§3.0.3) **plus** the two books' contents; a profession adds refinement/affixes/special variants (WP5), never a parallel item. **Cooking gets a book too** — same six groups and level gates, **no keystones** (the regional ingredient is the gate, T6 needs level-50+ ground) — but **costs no main slot**, and First Aid keeps no book at all. Gathering split: food and **spices** universal, **healing herbs Alchemist-only**. Recipe-unlock system (craft_predict veto + workbench proximity), book UI, Leatherworker ×5-leather loot hook (needs the `mobs:leather` special case, WP6 carry-over), and the §8.2 job supplies + profession books whose `grug_traders.register_stock` calls are pre-written as comments | open (spec: `professions.md`, `items_crafting.md` §2/§3.3–§3.7, `inventory_equipment.md` §4; **blocked on `TODO-design-crafting-rework.md` A1/A4/A5/E21** — signature recipes, T5/T6 + Woodcarver/Goldsmith keystones, the missing material grades, the cooking recipe lists) | WP7, WP25, WP26, WP33 |
| WP11 | Skill trees: 2 trees × 5 talents × 3 ranks per class, 1 point per 3 levels (20/30 fillable), 9 numeric talents + 1 capstone per tree = NEW active main skill (e.g. Priest: Renew), respec for gold at the class trainer | open (spec: `docs/design/progression.md` §2) | WP3, WP4 |
| WP12 | Global map with fog of war (adapt the mcl_maps approach), shows discovered waypoints | open | WP2, WP17 |
| WP13 | Starter/world content: 3 race capitals per continent (center = faction seat; schematics, per-race build sets, elven treehouses), patch villages/settlements, flavor camps, spawn immunity — **plus the mining camps as a real structure** (added 2026-08-08): `world.md` §4 had named them only as a *role* an outpost can carry, and since §2 R4 they are the **only place in the world where anything regrows at all**, so someone has to build them — schematic, garrison and the protection footprint they register with `grug_core.add_poi`. The renewable nodes that then live inside them (10–15 per camp, region tier, 2–4 h) are **WP34**'s mechanic, not this one's | open (spec: world.md §2 protection zones, §2 R4, §3/§4/§9, `docs/design/biomes_mobs.md`) | WP2, WP18 |
| WP14 | Offhand & carried light: grug_offhand (mcl_offhand pattern), shields, 2H rule, torch light radius (profiled). **Shrunk by WP35** (2026-08-08): the offhand *slot* and its group-filtered `allow_put` already exist, the ability-skin plumbing reads `slot = "offhand"` already, and the **2H rule is built and tested — but ships DORMANT**: nothing in the tree carries `grug_equip_offhand`, so *neither* branch of the pair check can execute, the refusal texts are unreachable and `_grug_hands` is read by nothing that can act on it (§7's torch is a plain node today). This WP is where all three go live, and its runtime test is the **first** one that can demonstrate the offhand direction at all — the refusal texts promise a torch's light, so re-read them against what actually ships | open (spec: `docs/design/combat_stats.md` §7, `inventory_equipment.md` §2 for the hand count) | WP3 |
| WP15 | Character screen & bags: sfinv pages (Character/Bags), equipment slots + stat recompute, bag system | ✅ `grug_inventory`: Character homepage (stats, model, **7 slots incl. the two trinket slots** — they shipped empty because no trinket item existed yet, **not** because trinkets were post-MVP: that was decided away on 2026-08-08, `inventory_equipment.md` §2, so the slots need no further WP15 work and simply fill up when WP10's Goldsmith family lands), 4-slot bag system (runtime tested 2026-08-07) | WP3 |
| WP16 | Guilds (re-cut 2026-08-07): registry, manager NPC, three fixed roles, guild bank (ONE detached inventory per guild — 6×32 tabs, 3 member / 3 officer, two purses, transaction log; terminals are inventory-less nodes on housing isles), /g chat, 5g founding fee. **Continental mining claims are removed** — a guild is social + chat + the bank account and owns **no ground at all**, so this WP has no claim registry, no 2g/5g land purchase, no claim protection layer and no ore-respawn exception to wire (`guilds.md` §3.2, `economy.md` §4, `items_crafting.md` §8.4) | open (spec: `docs/design/guilds.md` §2/§3) | WP7 |
| WP17 | Travel: waypoint nodes, visit-unlock, travel formspec (map UI docks on with WP12), Home Stone + /unstuck | open (spec: `docs/design/world.md` §6) | WP2 |
| WP18 | Continent mapgen rework: two ocean-separated continents (soft coasts, 3000×1600 default via grug_core constants), remove mountain wall, per-race spawn points at the 3 race capitals (safe-core belt), radial mob-level field with war-coast cap (+ `guard_level_at` inverse field for WP6), civilization-gradient biome layer (settled race biomes core/inner, shared nature biomes outward), coastal-ocean guarantee, R3 ocean build lock, deep-sea guard mobs | ✅ two-continent geometry + radial level/guard fields in `grug_core` (wall and z-rings gone), continent ocean mask + 6 race-capital platforms in `grug_mapgen/structures.lua`, 13 mirrored biome bands per biomes_mobs.md §1.3 with new `grug_nodes`/`grug_trees` content (20 registrations after the 2026-08-08 capital-biome carve and WP36's `grug_badlands_east`), Kraken Guard in the open sea (**needs a fresh world**; runtime tested 2026-08-07) | WP2 |
| WP19 | Combat feel & kit tuning: global cooldown (1 s), soft target lock (~8 s), Mighty Blow as rage dump, Hamstring, Fireball mana-limited, Frost Nova pivot (12 s + slow), Power Word: Shield (absorb via hp modifier), visible race passives | ✅ GCD 1 s (silent gate, no wear churn) + soft target lock (8 s, separate enemy/ally slots, range+LOS re-checks) in `grug_abilities`; kits per classes.md tables (Mighty Blow 25 rage dump, NEW Hamstring w/ mob slow via `grug_mobs.slow` halving speeds, Fireball 8 mana GCD-only, Frost Nova 12 s root→slow, PW:S absorb via `grug_core.set_absorb` in the central hp modifier; Renew `talent_gated` for WP11); race passives via `grug_classes` perk registry (dwarf fall −20%, troll OOC regen — mana today, WP21 reuses perk; undead zombie night truce via `_grug_ignore_player` veto patch in mobs api.lua; orc +1 rage/hit taken, elf +5 m item-meta range, human quest-XP hook latent until WP8). Runtime tested 2026-08-07 | WP4 |
| WP20 | Party system: /party (content sized for 2–3), tap rules (first damager's party tags), shared XP/kill/quest credit within 60 m, member HP frames HUD, group loot basics | open (spec: classes.md balance constraints) | WP4 |
| WP21 | Recovery & rest: out-of-combat HP regen (0.5%/s), food recovery, innkeeper NPC (rested XP + Home Stone rebind), NPC anchor/respawn insurance | open (spec: `docs/design/combat_stats.md` §5, progression.md §1) | WP1 |
| WP22 | Durability & repair: effect-loss at 0 durability (items never destroyed — weapons deal no damage, armor stops protecting, bonuses turn off), NPC repair for gold, tier-scaled costs. **Wear budget: 3000 combat events base, 6000 refined** — refinement's +100 % durability (`items_crafting.md` §6b.2) doubles the §8.3 budget cleanly, with no second constant; on a mining pick that doubling is the single best reason to buy a refinement at all. **Finding handed over from WP25 (2026-08-08)**: the engine multiplies a tool's `uses` by `3^leveldiff`, so a pick is at its most fragile in the rock of its own tier — the steel pick gets 180 digs out of surface stone, 60 out of slate and only its bare **20** out of basalt, and the next tier's pick makes that same basalt cheap again. That shape is intended (`items_crafting.md` §3.0.4), but whether the six picks' *base* `uses` are high enough for deep mining to feel fair is this WP's call, and the runtime test of WP25 is the first place the number can be judged. **Second finding, handed over from WP35 (2026-08-08)**: `grug_gear` weapons **wear today** (~550 swings at fpi 1.0) although nothing in their definition asks for it and **no design text says weapons break at all** — so the durability model this WP writes has to say explicitly whether weapons are in it, and either way that accidental wear is this WP's to keep or remove. (The *other* accidental wear path, ability punches wearing the ability item, was switched off by WP35's T0 and is not this WP's problem.) Note the seam rule while implementing: `grug_core.get_equipped_weapon` hands out a **copy**, so a worn stack is not equipped until it is written back **and** `grug_inventory.equipment_changed` is called | open (spec: `docs/design/economy.md` §4, `items_crafting.md` §8.3/§6b.2) | WP5, WP7 |
| WP23 | Apex world bosses: one dragon POI per continent (stationary arena fight, telegraphs, hoard + respawn timer); enemy-dragon raid trophy and per-region apex kits follow (Phase 2) | open (spec: `docs/design/world.md` §4b) | WP6 |
| WP24 | Housing isles: housing band (flat seabed −30, safe 150 m ring suppressing open-sea spawns), deterministic 1000er allocation grid + isle generation (100×100 box, ~50 skirt, 4 styles), indestructible teleport pad as waypoint, free digging to −30, then **six purchased depth steps — 50c / 2s / 6s / 20s / 60s / 1g ≈ 1.9g** with boundaries **−100 / −300 / −500 / −700 / −1000 / bedrock** (re-cut 2026-08-07 from ten 50-node steps to −530; the identical table is in `world.md` §5.3, `economy.md` §4.1 and `items_crafting.md` §8.4 and the three must not drift), deterministic treasure clusters per step (no respawn). **The isle uses the same six rock strata as the continent** (`world.md` §2 R6, §5.3) — obtained from **`grug_materials.stratum_node_for(y)`** (WP25), because the isle's VoxelManip pass does not get them from the mapgen ore stage the way the continent does — so both gates apply and neither substitutes for the other: a bought step is worthless without a tool of that tier, and a T6 pick digs nothing on an isle whose step 6 is unpaid. **Re-scoped 2026-08-08 by `TODO-design-depth.md` C8/C9**: the treasure clusters stay deterministic and stay *not* an ore field (an isle is ~9.7 M nodes of protected, mob-free, PvP-free ground — continental density there would retire the continent as a mine), but they become **markedly more generous and are filled in the step's own rock tier**, so a bought step reads as a payday; and every step additionally carries **one of six isle-exclusive materials** that exist nowhere else. **All six are named, textured and placed, only the Amplifier is live in the MVP** (once per item, +10 % on all prefix/suffix values, `items_crafting.md` §6b.8) — placing the inert five now is what keeps every later material addition out of mapgen. Two obligations ride along: **§6.3's cap arithmetic is re-run against the Amplifier's multiplier** before it ships, and its **once-per-item marker in item meta is WP5's** description/roller territory. The six names, textures and scarcities are the last open item (`TODO-design-depth.md` C9). Plus Dowsing Rod, visitor/trusted access lists, guild-bank terminal slot | open (spec: `docs/design/world.md` §5, `guilds.md` §3.1; open tuning: `TODO-design-housing.md`, `TODO-design-depth.md` C9; **needs the `grug_core.open_sea_at` fix** — `TODO-design-crafting-rework.md` B9) | WP7, WP17, WP25 |
| WP25 | Material ladder — ore nodes & rock strata: three **new ore nodes** (Silver T4, **Quartz** T2, **Garnet** T4) alongside the vendored copper/tin/iron/coal/diamond, **mese repurposed as Emberstone** (T5 — the glowing yellow crystal, existing texture fits; its *tool* tier dies in WP28), **Abyssal Crystal** as the T6 depth resource (§5.5), and the **six rock strata** of `items_crafting.md` §3.0.4 / `world.md` §2 R6: one stratum per tier at −100 / −300 / −500 / −700 / −1000 / bedrock — but only **five new nodes**, since `default:stone` *is* the T1 stratum — each carrying a `level` group that the tool's `groupcaps.<group>.maxlevel` must meet. The engine makes that a **hard refusal**, not a slow dig (`lua_api.md:2715-2731`), and `default` already uses the mechanism in both directions — this is a re-parameterisation, not new engine work. Strata drop ordinary cobble (the gate is *access*, not building material) and the same six layers are what WP24's isle generator uses, through `grug_materials.stratum_node_for(y)` | ✅ new mod **`grug_materials`** owning everything the ladder is made of. **Six strata, only five new nodes** — `default:stone` *is* T1 (and now carries `grug_stratum = 1`, so `group:grug_stratum` is the complete "is this depth-gated rock" predicate); below it `:slate` / `:basalt` / `:granite` / `:emberrock` / `:abyssal_rock` at −100 / −300 / −500 / −700 / −1000, `[colorize`-tinted (no new media), all dropping plain `default:cobble`, all `cracky = 3` — the gate is the engine's hard refusal via `level` vs. the pick's `maxlevel`, never a slower dig. **Placement is `ore_type = "stratum"` registered LAST** (`wherein = "default:stone"`, `clust_scarcity = 1`, no noise params): in mgv7 a mapchunk runs caves (`mapgen_v7.cpp:335`) → ores (`:355`) → dungeons (`:359`) and ores run in *registration order*, so every vein is already placed and survives untouched (**not one `wherein` had to change**) and **cave walls, carved before the ore stage, inherit their stratum for free** — a deep cave is no longer a free bypass of the gate (dungeon walls are not stratum rock; accepted, they are loot and not a mine). **Ore bands re-cut onto the six tiers** under two binding rules: *a lead metal lies one band ABOVE its own tier, a gem inside its own band* (otherwise you need a tier-n tool to reach the material a tier-n tool is made of — iron gained a −1…−100 band, which is what unblocks T2 at all: vendored iron started at −128, i.e. below the rock that demands an iron pick, and the ladder was locked shut), and *an ore node carries the `level` of the band it sits in, not of its own material tier* (silver is a T4 metal in the T3 band and therefore a level-2 node) — the second rule is what closes the cave leak from the other side. Ships the three new ore nodes + raw items (quartz 2c, garnet 3c, silver 4c inside §8.1's 1–6c band) and **Abyssal Crystal** (6c) as a registered node that **nobody places**: §3.0.2 binds Grudgesteel to the isle depth step, so WP24/WP23 own its placement. Mese → **Emberstone** and the whole `default` re-parameterisation (ore levels, the pick `maxlevel` ladder) via `core.override_item`, so `mods/BASE/default` stays byte-for-byte upstream (11 interventions, inventoried in VENDOR.md); the `default:mese` **block** scatter ore is deleted — a level-2 node inside the level-5 band worth nine Emberstone crystals, i.e. the T5 material handed to a steel pick through any deep cave. **Public contract: `grug_materials.TIERS` / `tier_at(y)` / `stratum_node_for(y)` / `level_for_tier(tier)`** — nothing outside the mod hardcodes a depth boundary or a stratum node name; **WP24's isle generator is the first consumer** (a VoxelManip pass does not get the strata from the mapgen ore stage), and `grug_nodes`' ore-respawn fallback already asks it instead of punching `default:stone` into a granite wall. Four cave spawn rows (zombie, giant spider, stone + mesa golem) gained `group:grug_stratum`; without it they would silently have confined themselves to −41…−100 and killed the depth axis of `combat_stats.md` §3. 2-reviewer gate (engine correctness · design adherence/economy), both converging on the same High: `maxlevel` is not only the gate — `tool.cpp:394-414` feeds `leveldiff` into diggability, `time /= leveldiff` and `real_uses = uses·3^leveldiff` at once, so every lowered pick now carries compensated `uses`/`times` and keeps its pre-WP25 effective durability and dig speed. **Walkable to −500 with today's item set** (the steel pick's maxlevel 2 covers T2+T3, and the iron that becomes it sits in the T1 band); **T4–T6 open only when WP26/WP29 land the silversteel/embersteel/grudgesteel picks** — until then the mese and diamond picks (maxlevel 4/5) are deliberate, unreachable test bridges, and WP28 must not delete them first. **Needs a FRESH world** (mapgen change) and is **NOT runtime tested yet** — the first shipped WP without a runtime pass (spec: `items_crafting.md` §3.0.1/§3.0.4, `world.md` §2 R6) | WP2, WP18 |
| WP26 | Two-slot furnace & the alloy chain: port `lottblocks:dual_furnace_*` from Lord of the Test (`lottblocks/crafting.lua:201`; LGPL 2.1 → GPL-3.0 compatible, `items_crafting.md` §1.1) as the second smelting node next to `default`'s single-input furnace, then register the six-tier bar chain of §3.0.2 — Bronze (copper+tin, dual), Iron (lump, normal), Steel (iron bar + coal fuel, normal), Silversteel (steel+silver, dual), Embersteel (silversteel+emberstone, dual), **Grudgesteel (embersteel + Abyssal Crystal + 1 `group:grug_rare_trophy`, dual)**. **Known port conflict**: LotT's `check_craft` matches **exactly two** inputs, and the T6 bar is the only three-input recipe in the game — the port has to widen it without making the two-input recipes ambiguous. VENDOR.md gets the upstream commit + patch entry. **Carried over from WP25 (2026-08-08): `default:mese_crystal` (the Emberstone Crystal) still has no vendor sell price**, while every other ladder material got one. Left unset on purpose — `grug_traders`' audit 3 ("no recipe whose output is worth more than its priced inputs") can only judge it once the smelting recipes of this WP exist, so the whole Emberstone chain (crystal, shard, block, Embersteel bar) wants to be priced in one pass here, inside §8.1's 1–6c material band | open (spec: `items_crafting.md` §3.0.2, §1.1) | WP25 |
| WP27 | Armor base recipes: `default` ships **no armor at all**, so all twelve base shapes (metal / cloth / leather × head, chest, legs, feet) have to be adapted — **Lord of the Test `lottarmor`** (LGPL 2.1; the owner considers it the closer fit for our ore/crafting model) or VoxeLibre `mcl_armor` (GPLv3+); sources and licences in `items_crafting.md` §1.2. Costs from the profession sections: metal chest 5 / legs 4 / head 3 / feet 2 bars (§3.3), leather jerkin 6 / pants 5 / hood 4 / boots 3 (§3.4), cloth robe 6 / leggings 5 / cowl 4 / slippers 3 bolts (§3.5). **Everyone can craft them** (§3.0.3), and they carry `_grug_armor` + `grug_armor_class` so WP7's armor pipeline and its rank filter pick them up with no change. Whether the leather line registers at all is `TODO-design-crafting-rework.md` C10 | open (spec: `items_crafting.md` §3.0.3/§3.1/§1.2, `inventory_equipment.md` §2) | WP26 |
| WP28 | Vendored-recipe cleanup — the owner asked for a **conflict-free sweep, not a delete list**. Remove the **mese and diamond tool tiers** from `mods/BASE/default/tools.lua` (pick/shovel/axe/sword × 2 = 12 registrations plus their craft recipes, §3.0.3) once the six-tier ladder replaces them; remove **`mobs:protector` / `mobs:protector2`** (a second protection system competing with `grug_core.is_protected` and the POI registry); remove **`mobs:nametag`** (WP6 owns nametags); remove **`mobs:saddle` / `mobs:lasso` / `mobs:net` / `mobs:mob_repellent`** (taming was explicitly rejected — mounts are bought, `mounts.md` §3). Each removal has live consumers that must go with it: `mobs:mob_repellent`'s recipe takes `mobs:protector` as an ingredient and `protector2` takes a mese crystal, the fuel recipes at `mobs/crafts.lua:288-292` reference the deleted items, and `api.lua` branches on `mobs:nametag` around `:4509` for the naming formspec. Done when a **fresh world boots with no unknown-item, missing-ingredient or duplicate-recipe line in `debug.txt`**; VENDOR.md gets the patch entries. **Ordering constraint discovered in WP25**: the mese and diamond picks are currently the ONLY tools that can break the T5 and T6 strata (WP25 gave them `maxlevel` 4/5 as a deliberate test bridge, `items_crafting.md` §3.0.4). Deleting them before the Silversteel/Embersteel/Grudgesteel picks exist would make everything below −700 undiggable for everyone. So either the replacement picks land with WP26/WP29 first, or WP28 keeps the two pick registrations until they do — the other ten tool registrations are unaffected. **Second constraint, from WP35 (2026-08-08)**: `grug_gear/init.lua` makes the twelve vendored `default:` swords and axes weapon-slot eligible through a loop over a **name list** (`VENDORED_WEAPONS`). Deleting `sword_mese`/`sword_diamond`/`axe_mese`/`axe_diamond` is safe — a missing name warns and is skipped, it does not crash — but the stale entries must come out of that list in the same pass, and whatever the surviving swords and axes are renamed to has to stay in it, or the base-tier player loses the only weapon they can equip | open (spec: `items_crafting.md` §3.0.3, `mounts.md` §3) | WP26, WP27 |
| WP29 | `grug_gear` rename & merge into the base ladder: the 72 shipped items drop their bracket adjectives (*Crude / Plain / Tempered / Reinforced / Superior / Grand*) for **material names** — Bronze Sword, Iron Helm, Steel Chestplate, Silversteel Greaves, Embersteel Sabatons, Grudgesteel Greataxe; cloth items take their bolt grade and leather items their leather grade (Linen Robe, Silkweave Cowl) — and the catalog **merges with the base tool ladder**, because one concept may have only one item (§3.0.3). Slot nouns, **prices, ilvl anchors, bracket boundaries and the generator itself are untouched** (§3.8/§8.2). The mod header's claim that the catalog is "10–15 % behind crafted gear of the same era by construction" (`grug_gear/init.lua:8`) is **false since 2026-08-07** and must go: vendor gear and base crafted gear are now the same item, and the crafter's entire edge is refinement + affixes (§6b), not a base number | open (spec: `items_crafting.md` §3.0.3/§3.8) | WP26, WP27, WP28 |
| WP30 | Trader rotating slots 2 → 3: `items_crafting.md` §3.2 gained the **caster 1H family** (wand / scepter / orb, the Woodcarver's, §3.6a) on the existing 1H row — same fpi 1.0, same ×1.0 factor — so `grug_gear` registers a fourth extra family and the extras pool grows from 3 to **4**. `ROTATING_SLOTS` in `mods/ENTITIES/grug_traders/stock.lua:123` rises from 2 to **3**, keeping the shipped invariant "slot count **strictly below** pool size" (§3.8): one family is still withheld every hour, so the re-roll stays a rotation rather than a permutation. Casters can finally buy a floor weapon, which the old three-family pool never allowed | open (spec: `items_crafting.md` §3.2/§3.8) | WP7 |
| WP31 | Mounts: the four riding tiers as a **universal skill** (no main-profession slot) bought at a trainer for 1s / 8s / 30s / 60s ≈ 1g — Apprentice slow land, Journeyman fast land, Expert slow flying, Master fast flying, +50 % / +100 % over the engine's 4 nodes/s walk. A mount is an **entity the player is attached to** (`mobs.attach` / `detach` / `drive` / `fly` from the already-vendored MIT `mobs_redo/mount.lua`, which needs `player_api` — we have it), speed is the **entity's velocity and never `physics_override.speed`** (that field already has two declared owners: mob webs and the PvP snare chain), and a mount carries no level, no XP, no threat and is never registered through `grug_mobs.register_mob`. Zone rules: the open-sea **"Exhausted"** debuff dismounts a rider after 10 s, with the boundary read from `grug_core.open_sea_at(pos)` and from **no hand-picked coordinate**; **housing isles forbid riding and flying outright** at every tier, and the two rules meet exactly at the isle's 150-node safe ring; and (2026-08-08, `mounts.md` §4.3) **enemy territory allows land mounts but bans flying** — no summon there, and a rider who crosses the border while flying is dismounted after the **same 10 s warned grace** as "Exhausted", tested with `grug_core.territory_at(pos)` (`mods/CORE/grug_core/init.lua:586-596`) against the rider's faction and never against a coordinate. That ban is what keeps the war-coast funnel of `world.md` §1 real: `open_sea_at` never fires over the strait (it lies *between* the two continent rectangles), so a Master flyer would otherwise cross the 200 nodes in ~25 s and land anywhere on the enemy continent. **Also decided 2026-08-08 (`mounts.md` §3.1): any incoming damage dismounts the rider** — mob, player or environment, no threshold and no grace period, through the same detach path. That rule is what keeps `combat_stats.md` §3's speed pillar (mobs 4.4 vs players 4.0) and WP6's 25 m soft de-aggro / 40 m leash alive next to a permanent 6–8 nodes/s mount, and it also settles the PvP-flag switch without a zone rule | open (spec: `docs/design/mounts.md`; **blocked on the `open_sea_at` fix (B9, WP24 owns it) and on the rest of `TODO-design-crafting-rework.md` D12–D20** — saddle item and assets, world persistence, damage/kill rules for the mount entity, whether **mounting** is refused while in combat, the *own*-side war coast, underground, the flight ceiling, what "Exhausted" does on foot, skins, and whether the trainer is a new NPC) | WP24, WP28 |
| WP32 | **Farming — explicitly post-MVP** (Phase 2, its own package): a Minecraft-like farming layer, adapted rather than invented — both VoxeLibre and Lord of the Test ship a working one, and the plant selection is large enough that content is never the constraint. It must fit the herb/spice split of `biomes_mobs.md` §2 exactly: **spices are farmable, healing herbs never are** (they grow on stone, gravel, mesa clay, dead wood and jungle floor — ground no plough touches — which is what keeps every healing herb bound to a journey into its own biome), and the **found-only** cooking ingredients (mushrooms, wild cocoa, rock salt) never become crops either, so the top of the cooking ladder stays a reason to travel. **The place is decided too** (2026-08-08, `world.md` §5.7): a player farms on their **own housing isle** — protected ground (§2 R5) inside their own build box — and **only cooking ingredients grow there**, i.e. the `[food]` and `[spice Tn]` lines of `biomes_mobs.md` §2 and nothing else. The package therefore ships the crop layer *and* the isle plant-set restriction, not just the crops | open, **Phase 2** (spec: `world.md` §5.7, `biomes_mobs.md` §2/§6, `professions.md` §1) | WP10, WP33 |
| WP33 | Herb & food nodes (the MVP gathering set): **no gathering node exists in code today** — `mods/MAPGEN/grug_mapgen/decorations.lua:10-11` carries only a comment deferring them. Register and place the **six herbs** — healing gravemoss (T1), dragonweed (T2), crimson lotus (T3), Alchemist-only; spices sunleaf (T1), marshbloom (T2), stormkelp (T3), gathered by everyone and used by both the Alchemist and Cooking — plus the MVP cooking ingredients including the **found-only** three (mushrooms, wild cocoa, rock salt), each in the biomes the marker table of `biomes_mobs.md` §2 assigns it, mirrored so **both continents reach every tier** (§6). Punching an alchemy herb without the Alchemist profession yields nothing plus a hint message (the gate is the book group, `items_crafting.md` §3.6); food and spices are universal | open (spec: `biomes_mobs.md` §2/§6, `professions.md` §1) | WP18 |
| WP34 | **Depth economy** — the mechanics half of `TODO-design-depth.md`, all of it decided on 2026-08-08. Six pieces: **(1) the depth phase-in pulse** (`biomes_mobs.md` §4.1) — a player-centric arrival pulse in a **throttled `register_globalstep`, never an ABM**, because `mobs:spawn` registers a static ABM whose `chance`/`aoc` are fixed at registration time and whose `aoc` counts per entity NAME in a 128-node sphere, so a depth-continuous rate is not expressible there at all; curve `min(R_MAX, max(0, (−y − Y0)·R_MAX/SPAN))` with Y0 300 / R_MAX 6 per min / SPAN 1700, **concurrent cap 6 per player** (the 100-player safety valve and the first thing the runtime test checks), light-independent, allowed to place an arrival inside a sealed self-dug room behind a **~2 s telegraph** on WP6's elite wind-up pattern, roster staged (existing cave families above −1000, the deep servants below). **(2) The depth curve in code**: `grug_core.mob_level_at` still computes `1 + floor(−y/20)` (`mods/CORE/grug_core/init.lua:696`) while `combat_stats.md` §3 has said **3 levels per 50 nodes** since 2026-08-08 — the anchors −500 = L30 and −1000 = L60 are wrong today. **(3) Surface `chance` × 0.75** across the surface spawn rows (`biomes_mobs.md` §4 carries the multiplied values), `aoc` untouched, every `underground`-reaching row and the Kraken Guard excluded — that is Giant Spider, Stone/Mesa Golem, **and the two `underground`-only critter rows Cave Bat / Cave Crawler** (WP36) — then **re-run the budget audit** (`docs/research/wp6_spawn_budget.md`). **Moved out of this WP: it is now WP37**, filed on its own on 2026-08-08 because the roster work is independent of everything else here; leave it there rather than doing it twice. **(4) Re-scope the ore respawn**: `mods/ITEMS/grug_nodes/ore_respawn.lua` still runs the removed world-wide 15–30 min rule; it becomes **10–15 nodes per mining camp, in the camp's own region tier, 2–4 h** (`world.md` §2 R4) — the depleted-vein node and the `register_on_dignode` hook are re-scoped, not deleted. **(5) The lava-lake pass**: a `register_on_generated` VoxelManip pass in `grug_mapgen/structures.lua` next to the ocean mask and the camp platforms, with a **chunk-box fast path so it costs nothing above −1000**, plus cheap `ore_type = "blob"` lava pockets in `group:grug_stratum` (`world.md` §4c). **(6) The continental Abyssal Crystal ore**: `clust_scarcity = 20³`, `clust_num_ores = 2`, `clust_size = 2`, band **−701 … −1000** (`items_crafting.md` §3.0.1 — the T5 rock, because a lead metal lies one band above its own tier; below −1000 the T6 pick would be needed to mine what the T6 pick is made of) — WP25 registered the node and placed it nowhere. **Not in scope, deliberately**: the servant roster below −1000 (content, `TODO-design-depth.md` D10), a deep apex boss (a later `world.md` §4b stage by decision) and the six isle-exclusive materials (WP24). **Honest dependencies**: piece 4 needs **WP13** to have built a mining camp before it has anywhere to run — it can ship against the existing POI registry and stay dormant until then, or wait; the isle half of the same design pass (C8/C9) is **WP24**'s, not this one's. The one design detail still open is A2's **placement geometry** (distance band, line-of-sight, what to do when no legal position exists) — in-WP tuning, like `TODO-design-housing.md`'s list, not a blocker | open (spec: `biomes_mobs.md` §4/§4.1, `world.md` §2 R4/§4/§4c, `items_crafting.md` §3.0.1, `combat_stats.md` §3) | WP6, WP18, WP25 (WP13 for the camps as a structure) |
| WP35 | **Weapon slot, ability-item skins, auto-attack as a skill** — the whole weapon-slot design pass, decided 2026-08-08 and folded into `inventory_equipment.md` §2, `combat_stats.md` §2/§7 and `classes.md` §2b/§2c (the `TODO-design-weapon-slot.md` it came from is deleted). **One weapon slot** next to the existing offhand; the slot item is the **single, fixed source** of damage and appearance for every skill of its type (**no fallback to the wielded item**; empty slot = bare-handed baseline, never uncastable). **Every ability item wears the equipped item's skin** (per-stack `inventory_image`/`wield_image` meta — engine-verified, no new registrations, no engine patch) while keeping its colored glow as an orb backdrop, so a Warrior holds *his* sword whichever ability is selected and swapping the weapon reskins all of them at once. **Auto-attack becomes an ordinary universal ability** ("Strike") — forced by the engine: an item with `on_use` sends `INTERACT_USE` and can never punch, so a slot-fed auto-attack is otherwise unreachable. It reads the weapon's `full_punch_interval` as a per-cast cooldown, is off-GCD, grants its own rage, and toggles auto-repeat against the soft target lock. Ships **T0 first**: `punch_attack_uses = 0` in `deal_ability_damage` — a live bug where Mighty Blow (cooldown 0) accumulates ~168 wear per landed hit on the ability item and destroys itself after ~390 casts. Also closes **E7**, a pre-existing bug where the elf +5 m range perk reaches the melee abilities (a 9 m sword), and — if E6 ships — the **PvP melee carry-over** of `combat_stats.md` §2 (player-vs-player melee still runs the engine's raw tflp scaling, i.e. the held-button-deals-0 defect WP6 fixed for mobs). **Shrinks WP14** (the offhand slot exists; this adds the equip rules and the offhand skin plumbing) and **hands WP22** the durability question (B2: `grug_gear` weapons wear today for no designed reason). Not blocked, no fresh world, no mapgen. | ✅ six tasks in `grug_core`, `grug_inventory`, `grug_gear`, `grug_abilities` and one more vendored patch. **T0**: `punch_attack_uses = 0` in `deal_ability_damage` — the spec's own arithmetic was off (`1.4/75*9000` is 167.99999999999997 in doubles), so it was **167 wear per landed hit and a broken tool at cast 393**, not 168/~390. **T1 — the slot and the seam**: `grug_weapon` as a player-inventory list with `grug_equip_weapon` on the four `grug_gear` families and, through a **loop over a name list** (it shrinks with WP28/WP29), the twelve vendored `default:` swords and axes; the equipment seam in `grug_core/combat.lua` (`get_equipped_weapon`/`get_equipped_offhand` as stub-overrides, `register_on_equipment_change(player, listname)`, `grug_inventory.equipment_changed` dropping caches AND notifying in one call at all three invalidation sites); the character column generated from `equipment_slots` with a load-time error if a slot has no position (an invisible slot is an item sink); no migration, a re-arming join hint instead. Review fixes: the hint **burned its once-ever flag during character creation**, when a fresh character owns no weapon at all; the notifier had no **re-entrancy guard** (it now coalesces a nested equipment write into one second pass, keyed per player, consumers unwrapped); and the cache handed out the ItemStack **by reference** — every read is now a fresh copy, because WP22 doing `get_equipped_weapon():add_wear()` would otherwise put the cache ahead of the list. **T2 — ability skins**: `slot = "weapon"` or `"offhand"` on ability defs, the orb backdrop composed in **one** helper (a malformed texture modifier is a client-side `generateImagePart` error and an untextured icon, with nothing in the server log), wield image = the weapon art alone, empty slot writes **no** meta at all. Acceptance was the **write count**, not the visual: equip 4, the coalescer's second pass 0, an armor or trinket drag 0. Review fixes: the documented fail-open did not exist (an unknown list name returned early); `def.color` was missing from the skin token; the composed string is now validated against a port of the engine's splitter (21/21 against a Lua oracle). **T5 — the two-handed rule**: `_grug_hands` (greataxe 2, staff 2, sword/dagger 1, all twelve vendored weapons 1 — a `default:` axe is a hatchet, strictly worse in combat than the sword of its tier, and it is the woodcutting tool everyone carries), enforced as a **refusal on the pair** in the existing `allow_put`, never by clearing the other slot; one shared throttled refusal channel for armor rank and hands. **T3 — the Strike** (the package): universal grant (four separate edits — `register_ability`, the class purge, the grant loop, `try_cast`'s class gate), per-cast cooldown from the weapon's `full_punch_interval`, `off_gcd`, `no_cooldown_display`, the toggle loop in the existing 0.5 s globalstep, and E7 closed in `get_range` (an elf Strike reaches 4 m, not 9). It also found **two contract bugs in the spec itself**: E2 makes the swing timer the ability's own cooldown while E3 makes a second cast the off switch — an off switch behind that cooldown is unreachable, so `try_cast` runs `stop_repeat` before every gate; and E5's "a hotbar weapon swung that way is strictly worse than the skill" is **wrong twice over** (re-traced at the WP35 integration gate): the WP6 cadence patch already hands that path the Strength bonus and the crit roll, and through `grug_mobs`' `do_punch` wrapper it also gets rage, base threat and the target lock — the real difference is the damage **source**, the wielded stack instead of the slot (`combat_stats.md` §2 corrected to match); and it is **false of the two running at once** (measured 1.57× against mobs), so both paths now consume **one melee clock per player**. T3's review also caught rage being granted **per swing attempted** — a Warrior went 0 → 100 rage in 10 s on an invulnerable vendor NPC, and vendors stand in every capital — now sampled from the target's hit points before and after; and a cadence that quantised upward at the shipped `dedicated_server_step = 0.09` (the sword lost 7.4 % DPS), now carried from the previous due time and within 0.2 % for every weapon. **T4 + the T3 residuals** (commit `2f32a81`): **Mighty Blow drops its hotbar scan** and reads the equipment slot through the same `swing_stats` the Strike uses — a greataxe in the slot with a sword in the hotbar now deals the **slot's** 13, a dagger in the slot with a greataxe in the pack deals **7** where the old scan gave 13, and an empty slot gives 2 and stays castable (C2: weak, never uncastable); both Warrior descriptions reworded to *"your equipped weapon"*. **`melee = true` on Mighty Blow and Hamstring** — the rest of **E7**: `get_range` honours the flag but only the Strike carried it, so an elf's two melee class abilities still had **9 m** reach, a pre-existing bug the weapon slot did not introduce (all 12 abilities checked, exactly three carry the flag, no ranged ability lost the perk). The winner-takes-all clock got **mitigation, not a fix**: `note_starved` raises one flash-HUD warning per 10 s once a refusal streak passes twice the weapon's swing time, so the loss is no longer silent — the defect itself is untouched and stays **WP38**'s. And the auto-repeat loop's two `assert`s became **log-and-stop**, because a `LuaError` raised from a registered globalstep does not stay local: it reaches ServerThread's `catch (LuaError)` → `setAsyncFatalError` (`reference_projects/luanti/src/server.cpp:128-132`, `:163-167`) and **shuts the server down** — and the `repeating` record was not cleared, so every following step would have raised it again. Not anticipated by this row: the **21st `GRUG PATCH`** in `mods/ENTITIES/mobs/api.lua` (VENDOR.md updated) — the `set_wielded_item` write-back now runs only when wear actually changed, worth 43 → 0 inventory writes over 30 s of auto-attack (~140 packets/s at the 100-player target). **NOT runtime tested.** Three things it did **not** close, all with rows of their own: WP38 (the PvP path is still ungated and the shared clock is winner-takes-all), WP14 (the two-handed rule ships dormant) and WP22 (`grug_gear` weapons wear for no designed reason). **Reading the code**: comments in `grug_core`, `grug_inventory`, `grug_gear` and `grug_abilities` still cite the deleted design file's question labels — **B1** the slot item as the single fixed source, **B3** eligibility and the no-class-gate rule, **B4** the hand count, **B6** the join hint, **C1–C5** the ability-item skins, **E1–E8** the Strike. All of them now resolve to `inventory_equipment.md` §2, `combat_stats.md` §2/§7 and `classes.md` §2b/§2c; reword the labels away the next time those files are touched | WP3, WP4, WP15 (all ✅) |
| WP36 | **Runtime-test fix round (2026-08-08)** — six items: one repo-hygiene task that must go FIRST, then five verified defects from the fresh-world test, all diagnosed down to the mechanism, none of them design-open. **(0) Reference projects as submodules — do this before anything else**, because the critter assets of item (4) and any future media import depend on it: `animalworld`, `animalia` and `mobs_monster` were cloned ad-hoc during WP6, their licences were verified and their commits are cited in `LICENSE-media.md` — and the clones are **gone**, because `.gitignore` ignores `reference_projects/`. Convert all eight sources (the five already listed in AGENTS.md plus these three) into **git submodules** pinned at the commits the licence rows quote where possible, drop `reference_projects/` from `.gitignore` (keep ignoring build artefacts inside it if any appear), and make `git submodule update --init --recursive --depth 1` the documented setup step. Submodules are correct here and do NOT contradict "third-party code is vendored, never a submodule" — that rule is about code we SHIP in `mods/` and patch in-tree; these are read-only references, and a submodule pins the commit our citations depend on. The rule and the list already exist (`docs/reference_projects.md`, AGENTS.md "Project structure"); **WP36 folds the actual submodule behaviour into the docs** — the setup command in README, the update discipline (never update a reference as a side effect: a moved commit invalidates every `file:line` citation in the design docs), and the fact that the game builds and runs without them. Then **fix the unanimated meshes**: a mesh without `ANIM`/`BONE`/`KEYS` chunks slides instead of moving — the Lord-of-the-Test rat is the known case, and with `animalia` back on disk its animated rat/bat/frog roster is available (MIT, licence already cleared in `LICENSE-media.md` §4). Audit every vendored `.b3d` for animation chunks while you are there. **(1) Level 1 at every capital**: `mob_level_at` is radial around the CONTINENT CENTRE, so only the two central races spawn at L1 — the four side capitals (x = ±550) sit at n = 0.217 → **L8**, and the first mob a fresh elf meets is a 55 HP / 5.2 dmg boar against a 30 HP player. `zone_at` says `core` while the field says 8; `guard_level_at` already carries exactly this correction (`grug_core/init.lua:712`, hard floor 60 for zone `core`) — the mob half is missing. **Decided: option (b), a per-capital level bubble** (L1 inside ~40 nodes, fading to the ambient field over ~200) so `radial_n`, `zone_at`, `guard_level_at`, `difficulty_at`, the 24 outposts, the 12 bandit camps and the whole `wp6_spawn_budget.md` cell inventory stay bit-identical; the gradient must stay ≥150 nodes wide to keep §1.5's no-jumps-over-5 rule. **(2) Floating trees over water**: the ocean mask clamps its carve to `maxp.y`, but the engine may place decorations up to **`emax.y = maxp.y + 16`** (`mg_decoration.cpp:424`), so with `chunksize = 5` every tree rooted at y 35..47 loses its trunk below 48 and leaves its crown hanging — 192 crowns measured in one coast band, 116 of 117 cuts at exactly y = 48. Whether the chunk above heals it depends on emerge-thread order, so the owner's "competing and incomplete" impression is literally true. Fix: carve to `emax.y`, provably sufficient because the engine cannot place above it; plus an **idempotent LBM sweep** (`run_at_every_load = true`) to heal existing worlds — safe because `column_cap` is a pure function of x/z. Also **move the mask + shell clean into the mapgen env** (`register_mapgen_script`): it currently runs in the main env after `blitBackAll`, which `lua_api.md` discourages, blocks the server step and double-writes every coastal chunk (the camp/outpost/bandit passes cannot follow — they need mod storage and the POI registry). **(3) Biome monopoly**: 41 % of Throng land has only ONE eligible visual because `grug_jungle_edge` (x 201..1250) and `grug_deep_jungle` (x 801..1500) share `default:dirt_with_rainforest_litter` and nothing else reaches that span — the Accord's mirror position has `grug_deep_forest_east` with a different top. Fix: give **`grug_deep_jungle` its own `node_top`**, add the **missing Throng `_east` wild slab** (x 801..1250, full z), and move `grug_deep_jungle`'s point off 90/90 (+2.2σ from the field mean — unwinnable anywhere it is contested). Verify with `tools/biomecheck`. **(4) Critters** (`biomes_mobs.md` §3.0, decided): a `critter` tier in `levels.lua` — L1, 1 HP, 10 XP, food-only drops, `fall_damage = 0`, and the telegraph gate inverted to a positive elite/rare test (today `tier ~= "normal"` would give a rabbit a ×3 cone hit); the large grazers become **passive prey** (no aggro, retaliate, keep levels and leather); plain feather moves to the bird-of-prey table; **new small critters, all zero-download** (asset survey 2026-08-08): **Cave Bat** (`mobs_mc_bat.b3d`, fully animated flier, no retint) and a **cave crawler** + **Bone Weevil** (`mobs_mc_silverfish.b3d`, bone-pale and blight tints) and **Bog Fowl** (`mobs_mc_chicken.b3d`, marsh tint) — all `type="animal"`, passive, runaway, `fall_damage = 0`, run 3.4, meat-only drops, interval 20 / chance 2200 / aoc 2. **NB the `critter` tier does not exist in `levels.lua` yet — that is the code prerequisite for all of them.** The **Carrion Crow becomes passive prey, not a critter** (it is the last feather source and the war coast's whole daytime population; `visual_size` 10 → ~14, box to 0.6, punch aliased onto the fly clip — zero asset and zero budget cost). **Budget**: the underground cell is 9/9 today, so two cave critters at aoc 2 each make 13/13 — one over the night peak of 12; ship the second at aoc 1 for 12/12. A meadows/savanna critter is impossible (those cells are already at the day peak of 16). **Asset warning**: only VoxeLibre and Lord-of-the-Test are still on disk — the `animalworld`, `animalia` and `mobs_monster` clones are gone (`reference_projects/` is git-ignored), so anything from them needs a re-clone even though the licences are cleared in `LICENSE-media.md` §3–5. **(5) Troll platform y = 8 vs y = 36** in two sessions of the same world — the generation-order class WP18 fixed once for `get_camp_platform_y`; needs its own diagnosis (`TODO-design-capitals.md` §4). | ✅ all six items, each through its own Opus review round (item 2 needed two, items 4 and 5 one each with fixes). **(0) Reference projects are eight git submodules**, pinned at the commits `LICENSE-media.md` quotes — `animalworld`, `animalia` and `mobs_monster` were re-fetched by SHA, the five still on disk kept their commits; `reference_projects/` left `.gitignore`, and `git submodule update --init --recursive --depth 1` is a documented setup step in README/AGENTS/`docs/reference_projects.md`, together with the **update discipline** (a moved pointer silently invalidates every `file:line` citation and every provenance row written against it) and the fact that the game builds and runs with the directory empty. **(0b) Mesh audit**: all **22 vendored `.b3d` carry ANIM + BONE + KEYS** — nothing had to be replaced, no media imported, no licence row changed, and the Lord-of-the-Test rat that motivated the rule turned out never to have shipped. One real defect found: the **Kraken drove all four clips at 1..60 on a mesh whose nine joints hold 41 keys**, so the tentacles froze for the tail third of every loop (inherited verbatim from VoxeLibre's squid). Engine finding that makes the method reusable: **the ANIM chunk is not authoritative** — `readChunkANIM` discards the frame count (`irr/src/CB3DMeshFileLoader.cpp:615-641`) and `getMaxFrameNumber` answers from the last keyframe (`irr/src/SkinnedMesh.cpp:43-46`), so an ANIM-only audit would have condemned five healthy meshes. With the submodules back, all 21 "Modifications: none" claims were re-verified byte-for-byte by `cmp`; audit table and reproduce-it recipe in `grug_mobs/LICENSE-media.md` §8. **(1) Level-1 bubble at every capital**: `mob_level_at` gains an L1 bubble inside 40 nodes of a capital anchor, blending into the ambient field over the next 200 (≥150 keeps §1.5's no-jumps-over-5 rule; the steepest real walk climbs 1 → 18 at ≤2 per 10 nodes). Applied to the **radial term only**, so the war-coast/strait caps and the depth floor still run after it (y −200 is still L11 at all six capitals) and `radial_n`, `zone_at`, `guard_level_at`, the 24 outposts, the 12 bandit camps and the whole `wp6_spawn_budget.md` cell inventory stay bit-identical — verified numerically, 0 `guard_level_at` diffs over 53.6 M samples and 0 `zone_at` diffs. `rares.lua`'s comments now describe the bubbled field (every rare route point sits 268–422 nodes out, i.e. outside every bubble, so no quoted level moved). **(2) Floating trees over water**: the ocean mask now carves to **`emax.y`** (the engine cannot place a decoration above it — `mg_decoration.cpp:424`), and mask + shell clean **moved into the mapgen environment** via `register_mapgen_script`, which also makes mask-before-camps an engine guarantee (`emerge.cpp:745` vs `:619`) instead of file order; the camp/outpost/bandit passes stay in the main env because they need `grug_core`, mod storage and the POI registry. Geometry has **one source of truth**, `grug_mapgen/geometry.lua`, `dofile`d by both environments with the continent rectangle passed in from `grug_core` via `core.ipc_set` — no constant duplicated. An **idempotent `run_at_every_load` LBM** heals existing worlds. Three review rounds hardened it well past the original defect: the sweep needs a **map-derived carved-column discriminator** (`column_cap` is (x, z)-pure, but the mapgen carve is conditional on `h > cap`, so the naive sweep was cutting 5-node stumps out of legal coastal trees at every load) and the same discriminator now gates `clean_shell`, so the residuals are not LBM-only; `grug_core.protected_zone_in_box` (the box form of the existing capital/POI rule) stops it deleting outpost posts; `vm:set_data` writes content only, so the carved volume is now explicitly stamped with `set_lighting{day = 15}` — without it whole chunk bodies went black, at any carve range, because every candidate sunlight seed row lies inside the carve; and the chunk-top `cap == maxp.y` case gets a **dress** branch instead of a provably dead carve branch, which had been leaving bare stone along the coastline that the LBM then read as uncarved forever. The **four residual classes are enumerated honestly** in `ocean_mask.lua`'s header — including the two where legal terrain *is* cut — and AGENTS.md carries the matching qualifier. **(3) Throng biome monopoly broken**: `grug_deep_jungle` got its own top `grug_nodes:dirt_with_canopy_litter` (retint of default's coniferous litter, recipe + licence row recorded), the missing Throng wild slab `grug_badlands_east` was added (**20 biome registrations**), and the deep jungle's climate point moved 90/90 → **80/88** (90/90 sat +2.2 σ from the field mean and took 0.0 % of the contested strip; 80/88 keeps exactly the documented 18.0-unit floor from `grug_jungle_edge`). Measured with `tools/biomecheck` (seed s32 1580377614): Throng eligible-visual monopoly **60.85 % → 42.83 %**, rainforest-litter monopoly **41.06 % → 18.77 %**, columns with three eligible visuals **4.26 % → 22.28 %**; cross-seed over 30 seeds the largest single visible top falls from a mean 35.0 % to 27.4 %, below the Accord's 29.7 %. §1.5 re-derived mechanically (peaks unchanged at 16 day / 12 night) and **two pre-existing dead cells repaired on the way** — meadows × coast and savanna × coast had had no mob at all since the D4 rollback. All five `tools/biomecheck` scripts had an absolute `sys.path` into a dead scratchpad and are now resolved against `__file__`. **(4) Critters, passive prey and four new mobs**: a **`critter` tier** in `levels.lua` that opts out of the multiplier model with flat overrides (L1, 1 HP, 10 XP, food-only, never promotable) while `normal`/`elite`/`rare` arithmetic stays bit-identical; the telegraph gate is now **one positive predicate** (`grug_mobs.tier_telegraphs`) instead of two spellings of `tier ~= "normal"`, which would have given a rabbit a 2 s wind-up and a ×3 cone hit. **Spec bug found and corrected in both design docs**: `fall_damage = 0` is a silent no-op (mobs_redo tests `if self.fall_damage` and every number is truthy) — the tier writes `false`. **Passive prey** (stag, gaunt stag, zebra, mountain ram, Carrion Crow) through four engine fields and no new aggro system, plus a fifth the review round added: `attack_type = "dogfight"`, without which a punched grazer entered the attack state and did *nothing* — no damage ever, no punch clip, no `set_velocity`, coasting on the knockback until the leash dropped it, i.e. strictly easier to kill than before the change. Verified against the real `api.lua` on a mock engine: 0 → 100 `set_velocity` calls, 0 → 9 punches, 0 → 90 damage in 10 s, and the §3/§4 chase model (run 3.40 → walk 1.50 past 25 m → `stop_attack` at 46 m) applies at all only now. Threat-driven target switches and Taunt were silent no-ops on prey for the same reason and work now. The **guaranteed-empty acquisition scan** on prey is closed with a wrapper, not a 21st GRUG PATCH: `register_mob` **derives** `no_acquire` from the four `attack_*` def fields, so it cannot drift from the filter it summarises, and `apply_aggro_fields` shadows the instance method with one shared no-op. **Four new critters, zero download**, all out of the pinned VoxeLibre submodule with frame ranges *measured* from the `.b3d` rather than copied: **Cave Bat** and **Cave Crawler** (underground — the caves had no critter at all), **Bone Weevil** (bone forest + blight; **one entity name, two spawn rows**, because `aoc` counts per name and two names would have meant two budgets, with an `on_spawn` stamp giving each biome its tint) and **Bog Fowl** (swamp). Budget: underground was 9/9, the Cave Bat at `aoc` 2 makes 11/11, and the Crawler ships at **1** for exactly 12/12 — tying the night peak instead of exceeding it. Feather moves off the critters onto the bird-of-prey table so arrow fletching stays behind a real fight; the Carrion Crow stays **prey, not a critter** (last feather source, the war coast's whole daytime population) at `visual_size` 14, box 0.6, punch aliased onto the fly clip. The four **ground** prey mobs also gained `pathfinding = 1` (the crow is a flier and must not) — see §3.0. **(5) Capital platform y = 8 vs y = 36**: `get_spawn_pos` used to substitute `CAMP_PLATFORM_Y = 8` whenever `get_camp_platform_y` answered nil and persist nothing, and that nil is *permanent* — `MapgenV7::getSpawnLevelAtPoint` refuses anything above y 17 (`mapgen_v7.cpp:248-292`) — so one session reported 8 silently and the next measured 36 and persisted it. A **second, pre-existing defect** in the same code was found: with the footprint's surface exactly on a mapchunk y edge neither chunk can report it, so the platform stayed undecided for the life of the world — the WP18 deadlock, never actually closed. Fix: **one decider**, and a caller that finds the platform undecided **forces** the decision instead of inventing a height — `grug_core.request_camp_platform` emerges the capital footprint (idempotent, ≤3 emerges per capital per session) and its completion callback falls back to a main-env VoxelManip **probe** over the whole footprint and the whole legal y band, so the y-edge case is decidable and legacy worlds heal. `get_spawn_pos` now returns `pos, decided`; a provisional position lasts one emerge and is **never persisted**. The review round hardened it twice more: an **uncertain probe must persist nothing** — `EMERGE_CANCELLED` decrements the refcount too, so a *graceful* shutdown mid-emerge drove the probe over a half-generated footprint and persisted the result forever (two independent gates now: any CANCELLED/ERRORED block, and any `CONTENT_IGNORE` above a column's ground) — and **a decided height must get a platform**, so `grug_core.ensure_camp_platform_built` (stub in `grug_core`, implemented in `grug_mapgen/structures.lua`) runs on every path that ends with a height, because on a *fresh* world the y-edge case generates the footprint chunks while both deciders still answer nil and those chunks never regenerate. A staggered startup sweep requests all six. Verified headless, 14 checks. **Not runtime tested yet**, and items 2/3/5 change mapgen: **a fresh world is required**. **Spun off**: **WP37** (the 0.75 surface-density multiplier, decided in §4 and never implemented across the roster — found here, documentation fixed, roster deliberately left alone). **Two things left open on purpose**: `TODO-design-jungle-fringe.md` — whether §8.4 binds `grug_jungle_fringe` to the deep jungle's new `node_top` or to `grug_jungle_edge`'s is **not decided**; shipped behaviour (fringe keeps rainforest litter) stands and the swap is measured as a no-op for every mapgen number. And **`grug_badlands_east` is the one design change here the owner may want to reverse**: it was added on a reading that contradicts §1.2/§2's older "band-specific / Orc area only" wording for the badlands, and the rejected alternative (`grug_bone_forest_east`, which measured 62.4 % of the contested strip and would have flipped the whole Troll east into a grey dead forest) is recorded with its measurements in `biomes_mobs.md` §1.3 and in `grug_mapgen/biomes.lua`. It is **cheaply revertible** — one `register_mirrored` half plus the §1.2/§1.3 rows — and it is not what carries the monopoly result (that is the deep jungle's own `node_top`), but it does deliver the three-eligible-visual gain in x 801..1250 and it **adds a live `war_coast` cell** (2 day / 7 night), so a revert has to re-derive §1.5 there | WP6 ✅, WP18 ✅ |
| WP37 | **Apply the 0.75 surface-density multiplier** (`biomes_mobs.md` §4, decided 2026-08-08, never implemented). §4's table already prints the decided post-multiplication `chance` for every surface row, but `grug_mobs` still passes the pre-multiplication WP6 numbers to `mobs:spawn` — **every shipped surface `chance` is exactly the table value ÷ 0.75** (Boar 1500/1125, Rabbit-Hare 1800/1350, Zombie 1600/1200, Wolf-Blightfang 1500/1125, Hyena 1500/1125, Jungle Lynx 1500/1125, Bear-Plaguehide 2800/2100, Jungle Ape 2800/2100, Stag-Gaunt Stag-Zebra 1800/1350, Skeleton Archer + Raider 2000/1500, Crag Eagle-Vulture 2000/1500, Ram 2200/1650, Panther 1800/1350, Serpent 1800/1350, Crocodile 1800/1350, Bog Ooze 2000/1500, Parrot + Carrion Crow + Gull 2500/1875, and the **two SURFACE critters of §3.0** — Bone Weevil 2200/1650 and Bog Fowl 2200/1650). The **five** documented exclusions (Giant Spider 1800, Stone/Mesa Golem 9000, Kraken Guard 12000, **Cave Bat 2200 and Cave Crawler 2200**) already match code and must stay untouched. The two cave critters were briefly listed here as multipliable and are not: they are `underground`-ONLY rows (`nodes = {"default:stone", "group:grug_stratum"}`, `max 5` light, y −31000…−40), so they have no surface half at all, and §4's exclusion — cave pressure belongs to §4.1's depth pulse, which is WP34's — covers them a fortiori (WP34 piece (3) scopes it the same way). Multiplying them would refill the underground cell WP36 calibrated to exactly the night peak (9/9 → 12/12) a third faster. Work: multiply the `chance` of every non-excluded `mobs:spawn` row in `mods/ENTITIES/grug_mobs/*.lua` by 0.75, **re-sync the `-- §4 row ...` quotations in those same files** (they quote the shipped number, so they read as false citations of §4 today — flagged in §4's own header), drop that header's "DECIDED, NOT YET IMPLEMENTED" caveat, and re-run the budget audit (`wp6_spawn_budget.md`) against the new values as §4 promises. `aoc` must NOT move — it is the per-name ceiling the 100-player calibration rests on. Found by the WP36 item-4 review (LOW 3), which fixed the documentation and deliberately left the roster alone. | open (spec: `biomes_mobs.md` §4 header + table, `docs/research/wp6_spawn_budget.md`) | WP6 ✅ |
| WP38 | **Split melee timing from skill timing: the proc model** — a design revision (decided 2026-08-09, folded into `combat_stats.md` §2 "Melee timing", `classes.md` core principles + §2b/§2c and `inventory_equipment.md` §1), not a bug fix, though it closes two measured WP35 defects **by construction**. Diagnosis: both defects are symptoms of one coupling — skills own the melee clock. **(1) The held-button path is ungated against PLAYERS.** `grug_core.accept_melee_swing` has exactly two callers, the cadence gate in `mods/ENTITIES/mobs/api.lua:2712` (a mobs_redo `on_punch`, so mob targets only) and the Strike's own swing; a punch on a **player** goes through `PlayerSAO::punch` → `on_punchplayer` and never touches the clock. Measured over 30 s at `dtime 0.09`: Strike alone 180 damage, Strike plus a held dig with a fleshy-25 hotbar weapon **930 (5.17×)**. **(2) The shared clock is winner-takes-all by requested interval** (`grug_core/combat.lua:521-530` stores a timestamp and nothing else, so the threshold is whatever the *current* caller asks): greataxe Strike alone 198 damage, the same greataxe plus a held **bare-hand** dig **69 (0.35×)**. **(3) New, found while verifying — the PvP rage firehose**: `grug_abilities/init.lua:1174` grants +12 rage per punch **event** on a hostile player, ungated and regardless of damage; the client sends 5 punch packets/s, so that is **60 rage/s**, 0 → 100 in under two seconds. It is the same defect fixed for mobs on 2026-08-08 (vendor NPC 0 → 100 in 10 s), still open for players. **(4) New — the `damage >= 1` cliff**: `mobs/api.lua:2880` gates hit sound, blood, damage flash, the health subtraction (`floor`!) **and** `check_for_death` behind one threshold, so a sub-1 swing is not merely weak, it is invisible. **The model.** Swing timing belongs to the engine and the weapon, skill timing to each skill's own charge timer; neither gates the other. No punch is discarded — damage is `weapon damage × clamp(tflp/fpi, 0, 1)`, which is DPS-exact at any click rate because the server resets `time_from_last_punch` per packet — and the rounding hole is closed by a **per-player remainder accumulator** (one field: target id + remainder < 1, reset to 0 on a different target), explicitly **not** by rounding every punch up to 1, which would make spam strictly better and worst where the numbers are smallest (a 3-damage weapon at 1 s: 5 DPS instead of 3, +67 %; a 25-damage weapon gains nothing). Every skill is then the ordinary weapon attack **plus** an effect that fires only when that skill is charged; charges tick always, do not stack, do not decay, and an unaffordable proc does not consume the charge — resources become the decision layer and the **GCD is removed**. Rotation is the hotbar (keys 1–8), and the auto-repeat loop **follows the selected ability item**, which is the whole stacking defence: two melee streams become structurally impossible and the shared clock, `note_starved` and the cadence gate are **deleted** rather than fixed. **Tasks, in build order** (each one shrinks the next): **T1** remainder accumulator + hit feedback moved in front of `damage >= 1` (vendored patch #22); **T2** delete `accept_melee_swing` and the cadence gate, proportional damage restored → defect (2) gone; **T3** auto-repeat follows the wielded ability item → the stacking defence, no clock; **T4** PvP through the same pipeline (`register_on_punchplayer` returning true, `doc/lua_api.md:6589`) with dodge/armor/threat, and rage on damage **landed** → defects (1) and (3); **T5** the proc model itself — two ability kinds (swing skills: the three melee ones, Strike, Mighty Blow, Hamstring; cast skills: everything else, i.e. the whole Mage and Priest kit plus Charge and Taunt, until ranged auto-attacks exist), charge timers, proc-on-landed-swing, GCD removed; **T6** the charge bar on the item wear bar (`wear = (1 − charge) × 65535`, `set_wear_bar_params` with `blend = "linear"`, red→yellow→green, no bar when full), driven by the **existing shared 0.5 s ticker** — never a per-skill loop: the engine coalesces a player's inventory send to once per environment step and skips untouched lists, so the whole feature costs **≤ 2 packets/s per player regardless of how many skills charge**, and the bar's resolution is `charge_time / 0.5 s` steps — **the ticker stays at 0.5 s** (speeding it up is the only change that costs packets) and `WEAR_STEPS` goes to 32 so the quantizer is never the binding constraint, with charge times of ≥ 2 s recommended and 3–4 s preferred; **T7** ability items pick up dropped loot (an `on_use` item sends `INTERACT_USE`, so the builtin item entity's `on_punch` never runs); **T8** equipment-slot identification on the character page (ghost icons for **empty** slots drawn after the `list[]` — `listcolors[]` is per formspec and would strip the main inventory's cells — with a runtime check that the image does not swallow the click, else one/two-character labels). Damage tables are **not** recomputed here: the DPS baseline is unchanged by construction and the procs add burst on top, so tuning is a pass of its own after the model has been played. Deferred with a decided shape: **ranged weapons** (draw-to-charge like VoxeLibre's `mcl_bows`, draw state from `player:get_player_control().dig`) — when they land, caster skills become procs on a ranged auto-attack the same way melee skills are; and **signature icons** replacing the tinted orb backdrop after the MVP (writing the name into a 16 px icon is impossible — Luanti has **no** `[text` texture modifier, verified against the full list in `doc/lua_api.md`; WP38 puts the skill name on the HUD on wield change instead). | ✅ all eight tasks. **T1**: the per-player remainder accumulator (`grug_core.apply_accumulated_melee`, target keyed by `get_guid()`, reset on switch) plus api.lua patch #22 splitting hit feedback (raw damage > 0) from the health subtraction and death check (the accumulated integer; the do_punch wrapper's lethal check uses the same number via `self.temp.grug_applied`). **T2**: cadence gate and shared melee clock DELETED (`accept_melee_swing` gone), the melee flag renamed `grug_melee`, vanilla's `tflp/fpi` factor kept as the proportional model with the Strength bonus before armor scaling, unfloored crit, knockback on landed hits, held-path rage now 12 × fraction and only when the accumulator committed ≥ 1. **T3**: the per-step wield watcher (`get_wield_index` + inventory-action dirty flag) — a non-ability item stops the loop within one step; an ability item shows its name 1.5 s on a neutral white HUD line. **T4**: PvP melee through the same pipeline (on_punchplayer returning true; proportional wielded-stack damage, accumulator, `set_hp({type="punch"})` so dodge/armor/absorb run exactly once; rage only on landed damage — the 60 rage/s firehose is dead; builtin knockback untouched, deliberately not fed our number, MVP). **T5**: the proc model — `kind = "swing"\|"cast"` asserted at registration; charge timers (timestamps, tick always, one max, no decay, charged at join/grant, reset only on proc); the generic melee loop reading the selected skill live every swing (click while running = re-arm/target-refresh only, second click on the same slot stops); the GCD deleted (Fireball mana-limited only); Mighty Blow = rage-dump proc (floor(weapon × 1.5) + melee bonus, no charge); Hamstring = 6 s charge slow proc (normal hit + 50 % slow, landed only). **T6**: the charge bar on the wear bar (`set_wear_bar_params` linear red→yellow→green, compare-first via meta token, the existing 0.5 s ticker, `WEAR_STEPS` 32, immediate empty-bar write on proc). **T7**: ability items pick up dropped loot via the item entity's own `on_punch`. **T8**: ghost icons for empty equipment slots (reused dimmed grug_gear art + two new CC0 silhouettes, drawn after the `list[]`, Character page re-renders on equipment change). Orchestrator integration fixes: two forward-declaration/shadowing bugs (the watcher would have read `repeating` as an undeclared global and never stopped the loop; `strike_def` was shadowed, so `melee_swing` would have targeted with a nil def) and a mangled wear-ticker indentation. VENDOR.md's patch inventory moved with T1/T2. **Post-merge review round (2026-08-09, three findings, all fixed on main):** (1) **the click toggle bypassed the swing cadence entirely** — `stop_repeat` cleared `repeat_due`, and `try_cast` swings immediately on a start, so click-stop-click delivered a FULL-damage swing per click pair at whatever rate the player can click (~4× DPS for a 1.0 s weapon, with the rage and the procs riding along). The deleted shared clock was the only thing that had gated it. `repeat_due` now OUTLIVES the loop and is reset only on respawn/class change/disconnect; a restart inside the interval arms the loop for the remainder instead of swinging. (2) **rage income scaled with the weapon's damage instead of its speed** — `landed` was tested as `applied >= 1`, i.e. "this packet pushed the accumulator over an integer", so the packets whose fraction was *banked* paid nothing: measured −40 % for a 3-damage weapon and −78 % bare-handed against the +12/interval the design specifies. "Landed" is the design's word for "the punch was not cancelled" (`classes.md` §1), so both hooks now pay `12 × fraction` on any punch with raw damage > 0, minus the cancels (refused punch, `immune_to`, PvP off, dodge, full absorb). Base threat never had the bug — it takes the raw fraction. (3) **weapon wear and its inventory packet were charged per punch PACKET** — with the cadence gate gone the wear block runs ~5×/s, which wears a tool `1/fraction` times faster than before WP38 *and* fires `set_wielded_item` (a full inventory serialization plus packet) on every punch, ~500/s at the 100-player target — exactly the cost WP35's patch #21 exists to avoid. `grug_core.melee_wear_due` accumulates the swing fractions and the wear is spent whole, once per completed swing. Two more `GRUG PATCH` sites (28 now). Design deltas folded into `combat_stats.md` §2 and `classes.md` §2b. **Second post-merge review round (2026-08-10, four findings, all fixed):** (1) PvP had applied `math.ceil` armor to each accumulated integer packet instead of to the full-swing equivalent, so five partial swings did not equal one armored full swing; one central `grug_core.apply_player_armor` formula now caps 0..60%, rounds only with armor present, and PvP resolves full swing + crit + armor before fractional scaling. A namespaced `PlayerHPChangeReason.custom_type` skips only that already-run armor step in the central modifier, leaving dodge and absorb exactly once. (2) Paying rage on bank-only PvP packets could not know whether their later commit would dodge or fully absorb; the damage accumulator can now bank pending swing fraction, returns and clears it only on an integer commit, resets it with damage remainder on target switch, and pays `12 × committed fraction` only when that commit lowers HP. (3) Wear remainder was per player, so swapping A at 0.8 to B at 0.2 charged B; every wear-capable concrete stack now receives one persistent opaque ItemMeta id, runtime wear is keyed by player plus id, the first id write is persisted once, empty/non-tool and creative/use-0 punches remain untouched, and broken/leave state is cleared. Patch count stays **28** because this reshapes the existing wear sites. (4) Equipment actions and class changes directly repeated stats/page updates after `equipment_changed`; stats are now the deliberately first equipment-change consumer, one page consumer owns refresh, class changes notify once even when no armor moved, and the redundant join rebuild is replaced by the dependency-ordered equipment join hook. **NOT runtime tested.** | WP35 ✅ |

**WP38 native-input correction (2026-08-10; still not runtime tested).**
The generic server auto-repeat/toggle was the cause of both live symptoms:
one click kept applying ordinary full swings while the client animated only
the original `INTERACT_USE`. Strike, Mighty Blow and Hamstring now omit
`on_use`; Luanti's native object-punch path owns held repeat, release and
first-person animation, while cast skills keep `on_use` and the loot-pickup
bridge. Kit/equipment sync mirrors the equipped slot's damage and interval
into each swing ItemStack (no groupcaps, no wear, empty slot = registered
hand), compare-first. A bounded fractional proc-progress accumulator replaces
all `repeating`/`repeat_due` state, survives selection among swing skills and
resets on target/concrete weapon/lifecycle changes. A two-phase `grug_core`
damage preview/commit plus two new vendored seam sites folds Mighty Blow's
exact replacement delta into the same crit/mitigation/dodge path and commits
cost, charge and effect only after acceptance; mob and hostile-PvP punches
share this handler. The wield watcher is now part of the existing throttled
0.5 s ticker. The correction review added a damage-remainder-coupled pending
PvP proc transaction with resource reservation, moved all mob hit side effects
behind both `do_punch`/CMI acceptance gates, and blocks the three hand groupcaps
plus the independent `dig_immediate` path through swing-item pointabilities.
The same accepted boundary now owns the prepared melee-crit visual; player
target leave invalidates every attacker's pending transaction immediately,
death does so after the killing callback settles, and the shared watcher
catches invalid mobs and non-swing wield boundaries.
Vendored `api.lua` still has **31** patch markers.

### Readiness (2026-08-08)

**Re-checked after the 2026-08-07 crafting rework** (`d5baf03`), which
moved WP5 and WP10 out of "ready" and added the material-ladder chain,
and again after **WP25 shipped on 2026-08-08** — the root of that chain
is built, so WP26 is now the front of it. Re-checked once more when
`TODO-design-depth.md` was decided end to end on 2026-08-08: it cut
**WP34** and it changed the scope of **WP13** (mining camps become a real
structure) and **WP24** (generous tier-filled clusters plus six
isle-exclusive materials).

**WP36 ✅ shipped 2026-08-08** (the runtime-test fix round). It spun off
**WP37** (the 0.75 surface-density multiplier, decided in `biomes_mobs.md`
§4 and never rolled out) and left one design question open in
`TODO-design-jungle-fringe.md`. It is **not runtime tested** and its
mapgen changes need a fresh world.

**WP35 ✅ shipped 2026-08-08** (weapon slot, ability-item skins,
auto-attack as a skill). It folded `TODO-design-weapon-slot.md` into
`inventory_equipment.md` §2, `combat_stats.md` §2/§7 and `classes.md`
§2b/§2c and deleted the file, and it spun off **WP38** (the melee path:
the PvP punch is still ungated and stacks with the skill, and the shared
swing clock is winner-takes-all). WP38 has since been **re-scoped into a
design revision** (2026-08-09): both defects are symptoms of skills owning
the melee clock, so the clock goes away instead of being repaired — see
its row. It also left the two-handed rule
**dormant** until WP14 and handed the weapon-durability question to WP22.
It is **not runtime tested**.

**Ready now** (no design blockers, deps done): **WP34** (depth economy —
the whole of `TODO-design-depth.md` is folded into `docs/design/`, and
its dependencies WP6/WP18/WP25 all shipped; only its mining-camp piece
waits for WP13 to have built a camp to put nodes in, which is a piece
that can ship dormant), **WP26** (two-slot furnace
& the alloy chain — §3.0.2/§1.1 decided and WP25 ✅ shipped the ores,
strata and raw items it smelts), **WP16** (guilds — WP7 ✅
shipped the money API the bank account needs, and the claim removal made
the WP *smaller*), **WP30** (trader rotation 2 → 3 — §3.2/§3.8 decided,
WP7 ✅, the only new WP with nothing in front of it), **WP38** (the melee
path — the two measured defects are now the *evidence* for a design
revision decided 2026-08-09: swing timing and skill timing become
independent systems, which deletes the shared clock rather than fixing
it),
**WP33** (herb &
food nodes — `biomes_mobs.md` §2/§6 decided down to the biome, WP18 ✅),
WP11 (talents — spec progression.md §2), WP13 (structures — mapgen/
biomes ship, WP6's outpost/camp anchors + POI registry are waiting for
real structures, and since 2026-08-08 the **mining camps** of
`world.md` §4 are part of the package), WP14 (offhand), WP17 (travel),
WP20 (party),
WP21 (recovery/innkeeper), **WP23** (apex bosses — WP6 ✅ shipped the
elite/rare tier, the telegraph mechanic the boss scales up, and the POI
protection registry a lair needs).

**Blocked, by what**:
- **WP5 ← `TODO-design-crafting-rework.md` A2** (the affix word list and
  its stat mapping). It was "ready now" before the rework; the design
  half it plugs into is otherwise decided (§6b is complete, WP7
  published the `_grug_ilvl` / `_grug_quality` seam), but a roller
  cannot build a display name out of words that do not exist yet. A6
  (the refined marker) should be decided in the same pass, because WP5
  writes the description builder
- **WP10 ← `TODO-design-crafting-rework.md` A1/A4/A5/E21** (signature
  recipes per mastery tier, the T5/T6 and Woodcarver/Goldsmith
  keystones, the missing leather/bolt/wood grades, the cooking recipe
  lists) **and ← WP26** (WP25 ✅ shipped the ore ladder, but a profession
  with no alloys still has nothing to refine) **and ← WP33** (the
  Alchemist has no herbs to gather). The structure is fully decided;
  the content lists are not
- **WP25 ✅ shipped 2026-08-08** (design decided the same day as B7/B8,
  folded into `items_crafting.md` §3.0.1/§3.0.4 and `world.md` §2 R6).
  It was the root of the whole material chain — WP26 → WP27 → WP28 →
  WP29 all hang off it, and so does WP24's isle rock — so what it
  unblocks is now open. **Not runtime tested yet**, and it changes
  mapgen: any test needs a fresh world
- WP27 ← WP26 · WP28 ← WP26, WP27 (the vendored tool tiers
  can only be deleted once the ladder that replaces them exists — and
  WP25's two test-bridge picks are the only keys to T5/T6 until then) ·
  WP29 ← WP26, WP27, WP28
- WP22 ← WP5 (needs gear to wear out); its WP7 half is done. The wear
  budget is now 3000 base / 6000 refined
- WP8 ← `progression.md` §4 (quest structure/level gates); **WP9** is
  free of its WP6 dependency (guards, outposts and the war-coast roster
  ship) and now waits only on WP8 + that same §4
- WP12 ← WP17
- **WP24 (housing)** is design-unblocked since 2026-08-07 (world.md §5
  decided; `TODO-design-housing.md` and, since 2026-08-08,
  `TODO-design-depth.md` C9 hold only in-WP content — the six
  isle-exclusive material names, textures and scarcities) and,
  with WP7's gold shipped, waits only on **WP17** (the pad is a
  waypoint) — its **WP25 dependency is discharged since 2026-08-08**:
  the isle's rock is the same six strata as the continent's
  (world.md §5.3) and `grug_materials.stratum_node_for(y)` now exists to
  place them. It still needs the **fix in
  `grug_core.open_sea_at`**: today open sea starts at |z| = 3200, which
  would spawn Kraken Guards on housing beaches (world.md §2b) — and
  since the mount rework that fix is a precondition for **WP31** too
  (`TODO-design-crafting-rework.md` B9)
- **WP31 (mounts) ← WP24, WP28 and the still-open half of D12–D20.**
  The spec in `mounts.md` fixes the tiers, the prices, the attachment
  model and now **three** zone rules — open sea (§4.1), housing isles
  (§4.2) and, since 2026-08-08, **enemy territory: land mounts allowed,
  flying banned** (§4.3, `grug_core.territory_at` + the same 10 s warned
  grace as §4.1; it is what stops a Master flyer from crossing the
  200-node strait in ~25 s and bypassing the war-coast funnel). Still
  open before the WP can be cut: the mount item and its assets (D12),
  persistence after dismount (D13), whether mounts take damage (D14),
  **the combat dismount (D15 — the load-bearing one)**, the leftovers
  of D16/D17 (own-side war coast, the PvP flag, underground, a flight
  ceiling), "Exhausted" for un-mounted players (D18), skins (D19) and
  the trainer NPC (D20)
- **WP32 (farming) is Phase 2 by decision**, not by blocking — it waits
  on WP10 and WP33 and belongs to the later expansion package together
  with the extra herbs and cooking recipes

Notes from the decided world design (`docs/design/world.md`):
- Race choice at character creation: ✅ shipped with WP3 (race dialog
  between faction and class); the visible race passives shipped with
  WP19 and the race-exclusive vendor + 10 % discount with WP7 — only
  race-exclusive professions/recipes are left (WP10/Phase 2).
- Build/dig restrictions (destructibility rules §2) land in `grug_core`
  alongside WP2.
- Housing is **WP24** since 2026-08-07 (the King's isles, per character
  rather than per guild — world.md §5). The Home Stone is covered by
  WP17.
- **Two known deviations, design vs. code (2026-08-08)** — both now owned
  by **WP34**, and the docs are the spec, so the code is what is behind:
  - `world.md` §2 R4 says *nothing regrows* except inside indestructible
    structures — mining camps only, 10–15 nodes at the region's tier on a
    2–4 h respawn — while the shipped `grug_nodes/ore_respawn.lua` still
    runs the old world-wide 15–30 min depleted-vein respawn.
  - `combat_stats.md` §3's depth axis has read **3 levels per 50 nodes**
    since 2026-08-08, while `grug_core.mob_level_at` still computes
    `1 + floor(−y/20)` (`mods/CORE/grug_core/init.lua:696`). Every depth
    anchor in the docs — −500 = L30, −1000 = L60, the crossover table —
    is therefore wrong in the running game.

### WP details (acceptance criteria)

**WP1 — Starter-zone mobs**: Boar (day, meadow) and zombie (night) spawn
and attack; kills grant XP depending on the mob; drops (meat/leather and
zombie trash loot as future vendor goods). Models/textures from VoxeLibre
`mobs_mc` (GPL, attribution). Helper `grug_mobs.register_mob` extends
mobs_redo with `_grug_faction`, `_grug_xp_reward` and XP awarding via
`on_death` (basis for faction targeting via `do_custom`).

**WP2 — Territory mapgen** (✅ 2026-08-06): Engine biomes on mapgen v7,
each confined to its territory/race region via the biome definition's
`min_pos`/`max_pos` cuboids (decision: C++-fast, ores/decorations/dungeons
keep working; a custom `on_generated` pass would have had to reimplement
all of that). `grug_mapgen` registers 3 race biomes per faction (+ ocean
variants, borderland, underground), its own ores/decorations, and a small
`register_on_generated` pass for the spawn camp platforms (cobble, at
z=±200) and the mountain wall at x=±2000. `grug_core` gained
`territory_at/zone_at/difficulty_at/mob_level_at` (ring anchors per
combat_stats.md §3) and the central `core.is_protected` override (R1–R3;
faction resolved via `grug_core.get_player_faction`, overridden by
grug_factions). Deferred: R4 ore respawn → **shipped with WP6**
(`grug_nodes/ore_respawn.lua`). *Corrected 2026-08-07*: the old note
"→ with outposts/mining zones (WP6/WP13)" is void — continental mining
zones were never built, and guild mining claims were **removed** with
the crafting rework (`guilds.md` §3.2), so there is no zone layer left
for R4 to wait on. Housing frontier is fully locked until housing plots
ship (WP24). *Superseded 2026-08-08*: R4 was **rewritten** — nothing
regrows outside indestructible structures (`world.md` §2 R4,
`TODO-design-depth.md` B5/B6), which gives the mechanic a zone layer to
wait on again; see the deviation note in "Readiness".

**WP18 — Continent mapgen rework** (✅ 2026-08-06): the world is now two
mirrored continent rectangles (`grug_core.CONTINENT_X_HALF` 1500,
`CONTINENT_Z_MIN` 100, `CONTINENT_Z_MAX` 1700 — 3000×1600 each, strait
along z=0). **Continent mask decision**: keep engine biomes on v7 and cut
the coastline afterwards — a post-generation VoxelManip pass in
`grug_mapgen/structures.lua` caps and floods every column outside the
rectangle ("the terrain generates, but it MUST be water", world.md §2b),
so all of v7's biomes/ores/decorations/dungeons keep working (a custom
terrain generator would have had to reimplement them, the WP2 argument
again). The coast noise insets the rectangle by 0..150 nodes INWARD only,
which guarantees the 200-node strait by construction; 60-node quadratic
taper, seaward shelf W−6..W−16, carved tops re-sanded near water level,
and a chunk-box fast path so inland and deep chunks cost nothing. The
mountain wall (`|x| = 2000`) and the z-ring model are deleted.
`grug_core` fields: `territory_at` → accord/throng/ocean; `zone_at` →
underground/ocean/strait/war_coast/coast/core/inner/outer (the
`_grug_spawn_zones` vocabulary); `mob_level_at` = radial elliptical field
around the faction seat (anchors n 0/0.30/0.55/0.90/1.0 → level
1/10/25/45/60) with the war-coast cap 20–30, strait cap 5, depth axis
(combat_stats.md §3) and nil on the open/coastal sea surface; NEW
`guard_level_at` (inverse field, 20..70, ≥ local mob level +5 — WP6
consumes it) and `open_sea_at` (beyond `OCEAN_COASTAL_WIDTH` 1500). Six
race capitals (`grug_core.capitals`, x = −550/0/550 at z = ±900, the
central one is the faction seat) get the terrain-adaptive camp platform
(median height, persisted per race) and are the per-race spawn/respawn
points via `get_spawn_pos(faction, race)`; the race dialog now teleports,
because faction join happens before the race is known. Protection: **R3
is the whole ocean** (replaces WP2's borderland and housing-frontier
rules), camp zones are the six capitals. Biome layer per biomes_mobs.md
§1.3: 20 registrations (17 before the 2026-08-08 capital-biome carve, 19
after it, 20 with WP36's `grug_badlands_east`) —
the 13 band biomes are authored once in Throng
coordinates and registered mirrored at z=0, swamp/beach/ocean/underground
are shared (a biome name exists only once) — wide cuboid overlaps as the
patch mosaic, climate noise (`mg_biome_np_heat`/`np_humidity` offset 50,
scale 35) so the extreme points are reachable; decorations are trees + ground cover only (herbs/food →
WP10). New **ITEMS modpack**: `grug_nodes` (signature tops blight_dirt /
bone-, forest-, silver-litter, mesa_clay, mud, bone_pile — they exist for
the spawn-whitelist trick) and `grug_trees` (silverwood, gravewood).
Deep sea got its deterrent: **Kraken Guard** L100 (no drops, no XP),
gated by the new generic `_grug_spawn_check` hook in grug_mobs, assets
vendored from VoxeLibre. Deferred: mud walk slow-down (marker group
`mud = 1` only), the §4 spawn-parameter retune and the full mob roster →
WP6; real capital structures and the §2 war-coast battlefield overlay
(broken carts, bone piles, burnt patches) → WP13. **Existing worlds are
incompatible — the mask, the biomes and the platform anchors all changed:
test on a FRESH world.** The user's runtime test produced two follow-up
fix commits: floating tree canopies over the ocean (decoration overflow in
the emerged shell, `a7ef34c`) and the spawn platforms — the platform height
now comes from `core.get_spawn_level` at the anchor (−2 for the engine's
dust allowance), resolved lazily in `grug_core.get_camp_platform_y` and
persisted, with a footprint heightmap median in `grug_mapgen` only as the
fallback for the many positions mgv7 calls "unsuitable"; a heightmap-only
decision is chunk-order-dependent and could deadlock. The POI protection
was reshaped to "footprint only, from 30 nodes below the platform upward"
per world.md §2 (`grug_core.POI_PROTECT_DEPTH` replaces
`CAMP_PROTECT_RADIUS`). The remaining spawn-safety questions (liquid
sabotage next to the platform, enclosed-pit detection, own-faction
griefing) moved to `TODO-design-spawn-safety.md`.

**WP6 — Faction mobs & mob feel** (✅ 2026-08-07): the whole
`docs/design/biomes_mobs.md` roster plus the combat-feel layer, in
`grug_mobs` (38 registered mobs in 40 spawn rows as WP6 shipped it; **42
in 45** since WP36's four critters) with the
threat half in `grug_core/combat.lua`, R4 in `grug_nodes/ore_respawn.lua`
and the outpost/camp anchors in `grug_core` + `grug_mapgen/structures.lua`.

*Architecture worth remembering* (the pattern-level rules moved to
AGENTS.md "Mobs"): a **level/tier engine** owns HP/damage/XP/armor — a
def that hand-sets them is overridden, `_grug_fixed_level` is the one
exception; **runtime field installation** because mobs_redo copies only
an explicit def-field whitelist onto the entity; **countdowns tick in
`do_custom`**, never `core.after`; the **chase model** (45 m give-up /
25 m soft de-aggro / 40 m drag from the chase anchor / 15 s contact /
evade run-home at 1.5x run speed, untouchable, teleport only as the
40 s backstop); `aoc` is **per entity NAME** in a 128-node sphere.
Vendored `mobs_redo` carries **16 `GRUG PATCH` sites in `api.lua`**
(inventory in VENDOR.md). Spawn calibration audit:
`docs/research/wp6_spawn_budget.md` — measured peaks Σaoc **16 day /
12 night** against the ~14 the rows were sized for, the target density
is met at the hotspots and not in the median cell.

*Deviations from the catalog* (all folded back into the design docs):
- **Jungle Lynx instead of Raptor** — the §8.2 fallback was executed
  (paleotest media unverifiable per file); same verb, same drops,
  `raptor_claw` item id kept.
- **Shore Crab + Reef Lurker still deferred** (§8.3, no licensed model);
  the beach cells run on the Gull alone.
- **Crocodile: one speed 4.4**, no 5.0-in-water bonus (mobs_redo rewrites
  velocities from `standing_in` and would fight our speed-restore
  bookkeeping) and **mud-only spawns** — "water at mud" is not
  expressible, the ABM `neighbors` list is an OR set; `floats` delivers
  the lurking instead.
- **Ram substitutes heavy leather 1/4** for the critter light-leather
  slot; the **Dust Hare** rides the settled hare row, so no badlands
  critter shipped.
- **Bog Ooze aura is a flat 2** — the one hand-written damage number in
  the roster (its melee is level-scaled as usual).
- **`visual_size` corrections** per the T5 mesh-scale rule (rendered mesh
  must match its own collisionbox) touched most vendored models —
  **flagged for the runtime test: this is the thing most likely to look
  wrong in-world.**
- **Sounds deferred WP-wide**: no audio was imported in T4, so no mob has
  a `sounds` table and the telegraph growl is a TODO — one future pass
  for the whole roster.

*Carry-overs*:
- **WP13**: the settlement pass owns the patch-driven camps/villages, the
  real outpost STRUCTURES (WP6 ships anchors, a banner node and the
  guards standing on them) and the war-coast battlefield decorations.
- **WP10**: the Leatherworker ×5 hook is wired (`register_drop_hook`,
  `grug_leather` group) but needs a special case for **`mobs:leather`** —
  the vendored item cannot carry our group.
- **WP20**: tap rules must fix XP attribution (today the LETHAL hit gets
  the kill XP, not the first damager's party) and replace the MVP heal
  threat group (healer + heal target) with real party membership.
- **WP24** (was WP16, re-assigned 2026-08-07): the ore-respawn
  **claim exception** reserved in the dig hook
  (`grug_nodes/ore_respawn.lua:108-120`) has lost its original owner —
  **guild mining claims were removed** with the crafting rework
  (`guilds.md` §3.2), so there is no `grug_claims` to call and the code
  comment naming one is stale. The reserved slot is still needed, for a
  different rule: on a **housing isle a mined-out treasure cluster must
  never regrow** (`world.md` §5.4, "no respawn (R4)"), so WP24 fills the
  slot with an isle test instead of a claim test.
- **PvP work package** (with the war-coast PvP quests, WP9-adjacent):
  port the 2026-08-07 melee auto-attack pipeline (cadence gate, Str,
  crit — combat_stats §2) to **player-vs-player punches**. PvP melee
  still runs the engine's raw tflp scaling, i.e. a held button deals a
  permanent 0 with weapons below bronze — the exact defect the mob
  pipeline fixed. **This carry-over now has a row of its own, WP38**,
  which added the second half of the problem: since WP35 the ungated PvP
  path also *stacks* with the auto-attack skill (measured 5.17×).

*Accepted caveats* (known, deliberately not fixed in WP6):
- **Dual `physics_override` ownership**: `grug_mobs/verbs.lua` (webs) and
  `grug_abilities/kits.lua` (Hamstring/Frost Nova in PvP) each keep their
  own player-speed record and each restore to 1 — overlapping effects can
  end early. Both windows ≤ 7 s; the fix is one shared owner in
  `grug_core`, out of scope here.
- **The telegraph only fires in melee** — a ranged elite kept at distance
  never winds up (deliberate: it must not slam empty air).
- **Camp head-count blind spots**: a camp counts members within
  `radius + 16`, so a member dragged further out reads as dead and the
  camp refills behind it. The evade run-home closes the common case (its
  40 s teleport backstop bounds how long a returning member can stay
  uncounted); a determined puller can still inflate a camp temporarily.
- **No floating combat text**: damage numbers, crits and the "Evade!"
  banner WoW shows over an evading mob have nowhere to go — the evade
  ships silent (the mob simply takes no damage) and crits announce
  themselves only through a particle burst. A combat-text system (HUD or
  short-lived text entities over the target) is a future WP idea; the
  call site for the evade banner is marked with a TODO in the `do_punch`
  wrapper (`grug_mobs/init.lua`).

**WP7 — Money & traders** (✅ 2026-08-07): `grug_money` (currency),
`grug_gear` (the six generated bracket catalogs) and `grug_traders`
(vendor NPCs, trade UI, rotation, the weak healing potion), plus the
armor half of `grug_inventory`/`grug_core` and the WP6 loot carry-overs.
The pattern-level rules moved to AGENTS.md "Traders/gold"; the design
decisions this WP settled are folded into `economy.md` §1/§2,
`items_crafting.md` §3.1/§3.2/§3.8/§6.1/§8.1/§8.2, `world.md` §7,
`inventory_equipment.md` §2 and `combat_stats.md` §2.

*Carry-overs*:
- **WP5**: the ×3 **Uncommon is built but never offered** until
  `grug_items.roll_enchants` exists (without rolls it is a blue-named
  Common at triple price) — the machinery ships, WP5 needs no edit in
  `grug_traders`; **`grug_req_level` derivation** from the published
  `_grug_ilvl` (WP7 enforces no level requirement anywhere); the
  **leather armor line** (curve is in the generator, `register = false`,
  no *intended* wearer before the Rogue — but the shipped rank filter
  refuses only `rank > max`, so a Warrior could wear it today if it were
  registered: `TODO-design-crafting-rework.md` C10 decides whether it
  ships in the MVP); and **quality/wear are ignored by buy-back
  prices** — a worn or Uncommon item sells for the same 25 %.
- **WP14**: **shields/offhand contribute no armor** —
  `grug_inventory.get_equipped_armor` covers the four armor slots only,
  and the §3.1 shield column has no consumer yet.
- **WP10**: **job supplies** and the **profession recipe book** — the
  four tome rows of §8.2 collapsed into **one book at 25c** on
  2026-08-07 when the tome chain was retired (`items_crafting.md` §2.2;
  the 1s/3s/10s rows are gone, and a re-bought book immediately shows
  every group the player's meta says is open) — and the **Alchemist's
  30 % potion** are unregistered; the
  `grug_traders.register_stock` calls are pre-written as comments in
  `stock.lua` and an unknown item name would render as a buyable
  "unknown item". WP10's instant potions **must reuse**
  `grug_traders.potion_cooldown_left` / `start_potion_cooldown` instead
  of opening a second timer (§3.6: one shared 60 s cooldown).
- **WP13**: vendors **reuse the guard model and skins**, so a
  Quartermaster looks exactly like a faction guard, and the six race
  vendors have **no race-specific skin**.
- **WP11**: the **respec price** (§8.3, 5c × level, min 25c) has no
  consumer yet — `grug_money.take` is the API it will call.
- **Known balance deviation**: a bandit's expected vendor yield runs
  ≈ 2–3× above its ring's §8.1 trash-loot band (dominant term: WP6's
  guaranteed cloth drop, not the new purse) — recorded in
  `items_crafting.md` §8.1 and flagged for a balance pass.

**WP3 — Classes** (✅ 2026-08-06): `grug_classes` with class AND race
registry (races per world.md §7, race perks hook for WP7/WP10). Creation
flow: faction → race → class, chained via
`grug_factions.register_on_faction_chosen`, every step mandatory/final,
stored in player meta. Stats per combat_stats.md §1/§2:
`get_attributes/get_max_hp/get_max_mana/get_melee_bonus/
get_spell_power_bonus/get_crit_chance/get_dodge_chance` as the single
source of truth for WP4's damage pipeline; hp_max applied via the level
pipeline (heal-on-levelup only for real level-ups — join deltas must not
heal, properties reset every session). Commands: `/char`, `/class`,
`/race`.

**WP15 — Character screen & bags** (✅ 2026-08-06): `grug_inventory`.
Equipment and bags are player-inventory lists (auto-persisted).
Character sfinv page = homepage (nav reordered Character/Bags/Crafting):
stat sheet, 3D model preview, slots Head/Chest/Legs/Feet/Offhand +
2 trinket slots — items declare their slot via group
(`grug_equip_head` etc., accepted once WP5/WP10/WP14 items exist; the
trinket slots shipped empty for want of an item, and trinkets are **in
the MVP** since 2026-08-08 — `inventory_equipment.md` §2). Bags:
4 slots, `bagslots` group (8/16/24) sizes the content list; a bag only
leaves its slot when empty (a shrinking list would destroy items); no
bags inside bags; no recipes yet (Tailor WP10 / vendor WP7, test via
`/give`). **Engine gotcha documented in code**: multiple
`register_allow_player_inventory_action` callbacks combine as
OR-with-short-circuit — return nil when unconcerned, a number swallows
all later callbacks.

**WP4 — Abilities** (✅ 2026-08-06): Design decided in
`docs/design/classes.md` (kits, costs, cooldowns — numbers live THERE).
`grug_abilities`: abilities are indestructible hotbar tools (item `range` =
targeting range, wear bar = running cooldown, tinted-orb icons via
`^[multiply` on one CC0 texture); kit auto-granted/purged on join and via
the new `grug_classes.register_on_class_chosen`. Resources are runtime-only
(mana full on join/respawn, rage 0); regen/decay + cooldown display run in
one 0.5 s globalstep. `grug_core/combat.lua` = damage pipeline:
`deal_ability_damage` (crit ×1.5, applies via `object:punch` so armor/
knockback/XP-on-death keep working), `heal_player`, central dodge roll as
hp-change modifier, `mark_in_combat/in_combat` (5 s window, reused by
WP6 leash + recovery), threat **stubs** (`add_threat`/`add_heal_threat` —
WP6 fills them; Taunt already forces targets via mobs_redo
`do_attack(player, force)`). Crit/dodge stubs in grug_core are overridden
by grug_classes (get_player_faction pattern). **mobs_redo gotcha
(documented in grug_mobs)**: a truthy return from a mob's `do_punch`
CANCELS the punch (the "return false to cancel" comment in api.lua is
wrong — precedence); wrappers must return nil. Deferred: melee bonus/crit
on auto-attacks ride on WP5's stack-meta tool-caps override; ability
sounds/icons → Phase 3. *(Both deferrals are spent: the 2026-08-07
cadence patch gave auto-attacks the melee bonus and the crit roll, and
WP35 replaced the tinted orbs with the equipped weapon — only ability
sounds are still Phase 3.)*

**Playtest fixes (2026-08-06,** after the first WP1/WP2/WP15 runtime
tests): **(a)** Mob spawn coverage — the WP1 whitelists only knew
`dirt_with_grass`, so the whole Throng side (savanna/blight/jungle tops)
and the dwarf hills had NO spawns; now all race-region surfaces spawn
boar/zombie, rates raised (boar chance 6000→2000/aoc 4, zombie 3000/aoc 3)
and ring-gated (borderland/starter/midlands) via the new
`_grug_spawn_zones` + `mobs:spawn_abm_check` override in grug_mobs (WP6
extends this to level tiers). **(b)** Camp platforms are terrain-adaptive:
first generated mapchunk near a camp takes the max mapgen heightmap within
40 nodes, persists the platform y in grug_core mod storage (fixed y=8 had
buried camps inside hills → players spawned in an inescapable pit); spawn/
respawn go through `grug_core.get_spawn_pos()` and re-read after emerge.
**(c)** v7 terrain offsets raised (`mgv7_np_terrain_base` 4→14,
`terrain_alt` 4→10, override_meta=true) → contiguous landmasses with lakes
instead of starter archipelagos; **existing worlds get chunk seams — test
on a fresh world**. **(d)** WP15 character preview fed `""` to `model[]`
when rendered before player_api set the model (client "Mesh not found"
spam) — empty properties now fall back to character.b3d/png. **(e)**
Vendoring policy decided → VENDOR.md (upstream commits + patch inventory,
`-- GRUG PATCH` markers), AGENTS.md section.

**Runtime test (2026-08-07, fresh world)**: the user's test pass closed
the "runtime test pending" state for **WP1–WP4, WP6, WP15, WP18 and
WP19** — the fresh world exercised mapgen, spawns, combat and the
character screen together. Six findings, all fixed on main:

- **F1** — guard and camp spawners were simply dead: LBM semantics
  (`run_at_every_load`), banner-type authority and anchor retry
  (`6ca817e`).
- **F2** — melee auto-attacks ran the engine's raw tflp scaling, so a
  held button dealt a permanent **0 damage** with weak weapons and
  ignored Str and crit entirely. Replaced by a weapon-cadence pipeline
  (`d3f562d`). **PvP punches still carry the old defect** — see the PvP
  carry-over above.
- **F3** — nametags of every active object rendered out to the ~128 m
  object-send range (clutter + a free PvP tell): proximity cap for mobs,
  player nametags hidden entirely, target frame extended to players
  (`0fd3008`, design in combat_stats.md §6). The first values 20/24 m
  proved too tight in the retest → **25/30 m** (`ce3b3ce`).
- **F4** — character preview fed a broken model string (comma escape,
  race resolution) (`04de736`).
- **F5** — dead camp and post NPCs never came back: respawn slots with
  dormant catch-up plus an idle roam cap (`c458050`, design folded into
  world.md §4a).
- **F6** — unfilled b3d material slots (client warnings) and the zombie
  skin sitting on the armor overlay (`5bf89c0`); the model notes' "single
  slot" claim was wrong, per-mesh slot counts are now measured.

**Runtime test WP7 (2026-08-07)**: money HUD and `/money`, vendor
spawning and invulnerability at a race capital, buying with the 10 %
race discount, the armor-rank refusal for casters, selling mob drops,
race exclusivity, and the potion cooldown were all exercised in-game.
**No findings** — nothing was changed after the test. The three startup
audits stayed silent in `debug.txt`.

Two feel changes came out of watching it run rather than from a defect:
**evade is a visible walk-back** instead of a teleport (`fe37d5f`,
combat_stats.md §4) and a review cleanup pass (`1ef6ac7`: swing-gate
client-tick rounding, meta write guards, `ROAM_RADIUS` 20, crit rolled
after `immune_to`).

(Further WP details are added once the respective WP comes up.)
