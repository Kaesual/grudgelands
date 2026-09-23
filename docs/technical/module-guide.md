# Module implementation guide

Extracted from AGENTS.md during the 2026-09-23 documentation consolidation.
Read only the relevant module section. This guide describes implementation seams
and engine pitfalls; [living design](../design/README.md) owns game rules and
[BACKLOG](../../BACKLOG.md) owns remaining work. Historical WP names identify
origins, not permission to restore superseded behavior. Source paths in code
spans are repository-relative. This is not a fresh certification of every API.

Related technical references: [Lua/engine constraints](../research/luanti-lua.md),
[reference projects](../reference_projects.md), [vendor patches](../../VENDOR.md).

- **Factions**: pattern from Lord of the Test `lottclasses` — faction as a
  **privilege** + ally matrix + predicates (`*_same_race_or_ally`),
  selection formspec on join (re-prompt on abort), starter-kit dispatch.
  LotT has NO per-faction spawns and no player-PvP gating — we build those
  ourselves (`core.register_on_punchplayer` /
  `register_on_player_hpchange`).
- **XP/levels**: template VoxeLibre `mods/HUD/mcl_experience/init.lua` — XP
  as an int in player meta, `level_to_xp` curve, `register_on_add_xp`
  pipeline, HUD bar. Round 18: no death XP loss; cumulative XP caps at level 60,
  and real upward level changes fill living HP/mana with one gold burst.
- **Professions**: `grug_jobs` owns the exact seven primaries — Weaponsmith,
  Armorsmith, Alchemist, Tailor, Leatherworker, Woodcarver and Goldsmith — plus Cooking,
  two primary slots, player-meta progression and the UI-only recipe books.
  Content mods first call `register_ingredient_tier(item, tier)`, then
  `register_recipe{profession, tier, station, inputs, output, hint}`; every
  gear recipe must contain a declared ingredient of its own tier. For an
  intermediate-material conversion, the output tier is the recipe tier; it
  does not invent a same-tier input solely to satisfy the gear rule. **Basics** is the
  exclusive profession-free category; every recipe route appears in exactly
  one book. Weaponsmith and Armorsmith have separate authorization/progression
  but share station id `forge` and node `grug_jobs:forge`; there is no
  `blacksmith` alias. Supported station names are `grid`, `furnace`,
  `dual_furnace`, `brewing_stand` and the registered profession stations.
  `register_station(name, {register_recipe=..., can_use=...})` lets a later
  station install its engine adapter and optional per-player gate; registrations
  made before that adapter are replayed. Player APIs are `learn`, `unlearn`,
  `has`, `profession_level`, `crafts_in_tier`, `character_tier`,
  `record_craft` and `can_craft_recipe`. `profession_level` returns 0 when
  unlearned and effective T1–T6 when learned. Grid output is vetoed before the
  engine craft. Authored workspaces have persistent per-player/per-station data;
  player-placed stations share inputs with individually qualified output views.
  Automatic furnace/dual/brewing processing is universal and grants no progress;
  the protected preparation step grants current-tier progress instead.
  One output may have one route per station when every route agrees on
  profession and tier; `recipe_for_output(output, station)` resolves the
  station-specific route. This is how a Cooking grid dish and its raw-assembly
  furnace path meet at the same edible item.
  Grid and selected enchant commits revalidate qualification and inputs before
  consuming anything and record progress once after settlement. Alchemists make
  mixtures in their inventory grid; Brewing Stands finish them universally.
  Basics declares each exact engine route as starter or with one main material;
  the complete runtime catalog is audited against `basics_routes.lua` at startup.
  Discovery changes visibility only. Bread, Cooked Meat and Cooked Fish are
  universal Basics roasting; protected Cooking dishes keep their book provenance.
  `docs/design/crafting_equipment_revision.md` governs current stations, named
  fixed-tier enchantments (including trinkets), equipment separation and wear.
  Station icons appear below the recipe arrow, outside ingredient slots.
  `grug_jobs.open_trainer(player, profession, pos)` serves the seven primaries
  and Cooking. Capital-only Riding uses `grug_mounts.open_trainer(player, entity)`
  with an authenticated Riding socket, never the generic profession hook.
- **Crop registration**: `grug_nodes` registers complete `grug_farming:soil` and
  `soil_wet` definitions before synchronous mapgen compilation, and exports
  `crop_visual(key, stage, sounds)` and `bind_crop_soil_callbacks`. FARM binds
  its real callbacks once and owns the 17 crop families, timers and current-world
  activation. Mapgen has no FARM dependency; do not defer world authority.
  Tall crops keep state, timers and drops on the root; hidden helpers never own
  rewards. Multi-position growth/harvest preflights loaded, protected and exact
  matching nodes before mutation. Mature regrowers use right-click; annuals are
  replanted, while harvested Cane/Bamboo retain and reset the base.
- **Skills catalogue**: `grug_skills` lists unlocked active class/talent
  abilities and every purchased mount tier. Entitlement is authoritative;
  inventory stacks are disposable bound representations. Drop/catalog return
  deletes only the stack, with no world entity. Manual recovery requires no
  copy in main, craft or owned bag contents; external inventories, equipment
  and trading refuse bound stacks. Base-kit insertion happens once at character
  creation; later talent unlocks and mount purchases announce Skills availability
  without insertion. `grug_abilities.is_unlocked` is shared by catalogue,
  recovery, normalization and actual cast/swing execution. `normalize_kit`
  removes stale copies without re-granting missing ones. Purchased mount tiers
  remain individually available at their original speeds.
  Do not compare InvRef userdata for inventory ownership: engine callbacks can
  create a fresh wrapper for the same underlying inventory. Authenticate
  `inventory:get_location()` (type and player name), then the allowed list and
  current entitlement. Cross-inventory tests must include both callback sides
  in engine order, not only direct catalogue callbacks.
- **Mount runtime**: ownership is player meta; the summoned controller and its
  visible child are ephemeral. The child is hidden only from its local rider in
  first person. `grug_mounts.dismount` is the shared cleanup path for manual,
  damage, death, leave, shutdown and external-detach exits and clears the
  runtime-only untimed `mount` status. Mounted players cannot attack. Land
  controllers use nominal one-node step height; T1 is 6.4 nodes/s (+60%).
- **R7 audit boundary**: the 157-file R7 source-audit roster is frozen
  historical evidence and is not a current-source gate. WP49 will replace it
  with a fixed WP40/direct-neighbour roster; never refresh or cite the old
  baseline-derived list as current certification.
- **Trinkets**: `grug_trinkets` owns the six special consumers and rebuilds an
  event-driven per-character equipment cache through the equipment-change seam;
  hot mana/heal/hit/kill/potion paths read that cache and never rescan slots.
  The same trinket identity cannot occupy both slots. Last Light uses one
  shared 120-second cooldown and maximum shield lifetime.
- **Combat/classes**: damage = damage_groups × armor_groups (÷100) ×
  punch-interval factor. **Damage pipeline lives in `grug_core/combat.lua`**
  (WP4): `deal_ability_damage` (crit ×1.5, applied via `object:punch` with
  full punch interval so armor/XP keep working; knockback requires an explicit
  `damage_groups.knockback` override), `heal_player`,
  central dodge roll (hp-change modifier), `mark_in_combat/in_combat`
  (5 s window), threat stubs `add_threat`/`add_heal_threat` (WP6 fills
  them). Crit/dodge accessors are grug_core stubs overridden by
  grug_classes. Abilities = hotbar tools in `grug_abilities` (item `range` =
  targeting range, wear bar = cooldown display for cast skills, charge
  bar for swing skills since WP38); kits/numbers:
  `docs/design/classes.md`. WP19 added the 8 s target-memory store (separate
  enemy/ally slots via `grug_abilities.get_target(player, ally)`). **WP39's
  decided rule supersedes its hostile fallback:** enemy memory is Target-Frame/
  UI state only and no melee, hostile cast or projectile may read it as aim;
  friendly skills always resolve through valid pointed ally → valid ally
  memory → self. WP19 also added **absorb
  shields** (`grug_core.add_absorb`, soaked in the central
  hp modifier after dodge/fall mitigation), **race passives** as a perk
  table in the grug_classes race registry (`grug_classes.get_race_perk`,
  stub-mirrored as `grug_core.get_race_perk`; elf range via per-stack
  meta `range` override) and mob slows (`grug_mobs.slow`, staticdata-safe
  countdown shared with root). NB a lethal ability punch removes
  animation-less mobs synchronously — capture mob pos/luaentity BEFORE
  `deal_ability_damage`. **mobs_redo `do_punch` gotcha**: any truthy
  return cancels the punch (api.lua comment claims the opposite) — hook
  wrappers must return nil; player-hit hook:
  `grug_core.register_on_player_hit_mob` (fired by grug_mobs).
  WP35 added: a **weapon slot** (group `grug_equip_weapon`) whose item is
  the single fixed source of damage AND appearance for every skill of its
  type — **no fallback to the wielded item**, empty slot = bare-handed
  baseline; `inventory_equipment.md` §2 (eligibility, no class gate, the
  `_grug_hands` two-handed rule) and `combat_stats.md` §2. Its
  **equipment seam** lives in `grug_core/combat.lua`:
  `get_equipped_weapon`/`get_equipped_offhand` (stub-override pattern like
  `get_armor_rating`; **the returned ItemStack is the caller's OWN
  COPY** — a modified copy is not equipped until it is written back AND
  `grug_inventory.equipment_changed` is called) plus
  `register_on_equipment_change(func(player, listname, reason))`, where `listname`
  is the one list that changed or **nil** for "assume everything moved".
  Consumers must be idempotent and cheap (every inventory write re-sends
  the list to the client), **may be called twice for one change** (the
  notifier coalesces a nested equipment write into a second pass) and run
  **unwrapped**, so an error in one is loud. Never write an equipment list
  without going through `grug_inventory.equipment_changed`. That notifier is
  the sole equipment-driven stats/page refresh source:
  `grug_classes.apply_stats` is the deliberately first consumer (through a
  wrapper so `listname` is not mistaken for its `fill_hp` argument), then
  exactly one Character-page refresh consumer; normal equip, class change
  and join add no direct duplicate refresh (a genuine nested write may still
  earn the second pass).
  Round 11 adds the optional `reason = "durability_metadata"` for same-item
  wear/remainder/capability bookkeeping and first persistent action identity.
  Forward that third argument through every wrapper (including quality).
  Held swings and bow draws refresh their usable same-item snapshot without
  restarting cadence; actual swaps and broken/unbroken transitions still reset.
  **Swing skills use native interaction plus an authoritative held clock**
  (`classes.md` §2b; WP38 base, WP39 target-authority revision decided
  2026-08-10): Strike, Mighty Blow, Hamstring and Round 11's Opening have `kind = "swing"`
  and **no `on_use`**, keeping the fast first-person held animation. Their
  native enemy packets are input only and return before damage/rage/threat/
  wear/proc. The no-dig pointabilities can mask a ground-level drop, so each
  fresh LMB press retains the bounded first-visible 4 m builtin-item pickup ray;
  nodes/other objects block it and held repeats do not become auto-loot.
  **WP39 shipped the current-ray authority on 2026-08-10.**
  `grug_core.combat_eye_pos(player)` and
  `grug_core.combat_ray(player, range, opts)` are the shared server-side
  acquisition seam: the latter returns one physically ordered structured ray
  result for combat and diagnostics, so callers do not raycast again for logs.
  The held clock attacks only a live hostile returned by that current server
  eye/look ray while `get_player_control().dig` is true. When due, no
  target/friendly/blocker/out-of-range aim is an **aim miss** and leaves the
  attack ready; the first valid ray target consumes the interval before its
  punch. Later evade/immunity/PvP refusal/dodge/full absorb/do_punch/CMI cancel
  is a **combat miss** that consumes cadence but keeps no proc/rage/cost/charge/
  effect. Moving the crosshair changes/stops damage immediately; enemy memory
  can refresh the Target Frame but is never read back as aim. A 0.05 s
  throttled pass still executes only on the next actual engine step, carries at
  most 0.1 s and half an FPI of ordinary lateness, and never replays a backlog.
  Swing-to-swing selection reads the proc live; non-swing/cast boundaries keep
  the due time; lifecycle clears it; a concrete weapon swap starts one full new
  interval. Every hostile ordinary tool/fist packet pushes the full ability
  swing to at least `now + equipped FPI`, with one-time bank cleanup at path
  transitions.
  Swing ItemStacks continue to mirror equipped-slot FPI compare-first with
  `fleshy = 0`, empty `groupcaps`, `max_drop_level = 0`,
  `punch_attack_uses = 0` and blocking hand/dig_immediate node pointabilities.
  The ability stack never wears. Round 11's REPAIR hook spends wear on the
  concrete main hand once on a qualifying settled
  action. The accepted transaction stays
  exact attacker+ray-target and claim-once; the mobs_redo/PvP finish seam pays
  cost, resets charge, grants rage and applies post-effects only on its existing
  accepted/HP-loss conditions. Mighty Blow remains
  `floor(weapon*1.5)+melee bonus`; Hamstring remains a 50% slow.
  WP39's binary small gold crosshair ring is shown once while a selected
  swing is weapon-ready, hidden on a valid attempt, absent for non-swings, no
  smooth progress and no inventory writes; a weapon swap follows the new
  clock's readiness and lifecycle cleanup removes it. It also ships permanent
  admin-only per-player `/combatdebug`; disabled sites do no ray/log
  formatting/globalstep work beyond the enabled check.
  Hostile casts never use enemy memory. Round 17's targeted projectile contract
  supersedes WP39/Scout ballistic flight: validate current target/range/LOS at
  actual release, then home for a bounded launch-time duration with no later
  range/terrain/body interception. Impact goes through ordinary mitigation and
  settlement once; no valid release target costs no mana/ammo. Smite is still
  direct, area spells unchanged. Projectile and target lifecycle prevents stale
  hits across death, reconnect and teleport. `grug_projectiles.spawn_batch`
  reserves all Scout siblings before ammo payment and shares one wear receipt.
  `grug_mob_damage_scale` defaults to 1.5 for all non-player actors and their
  melee/projectile/aura/DoT/ground attack paths exactly once; environment/fall
  and player damage remain unchanged. See `round17-plan.md` and living specs.
  Round 6 centralizes player scaling in `grug_core.base_pool`: max HP and mana,
  percentage mana costs, pool-derived heals/absorbs and the damage-only
  `level_scale` fit follow `combat_stats.md` §2; Strength and Intelligence are
  damage secondaries only. The Character page displays maximum pools and its
  Help page explains the model. Ability registrations may expose
  `def.values(user)`; `grug_abilities.description_for` writes the effective
  current-level values to that player's stack on kit sync, level change and
  talent change. Suffocation is 5% maximum HP/s (minimum 1), with stasis and
  `noclip` exempt. `grug_core.status` is the runtime timed-effect registry and
  top-center eight-line buff/debuff text list (Round 19). Status definitions may carry only
  `hp_pool_percent`, `mana_pool_percent`, `crit_percent`, `armor` and
  `spell_damage_percent`; `grug_core.status_modifier_sum` adds active statuses,
  and the modifier-change callback drives the same HP/mana clamp and HUD/page
  refresh path as talents. `grug_food.TIERS` owns fixed instant HP, minimum
  level and the Hearty/Caster/Hunter dish data; raw foods, including Wild
  Cocoa, always regenerate 2% HP per 5 s. Food lasts 300 s. Eating during
  combat is refused before consumption; accepted food heals instantly, and its
  regeneration pauses during later combat while secondary modifiers persist. The
  latest food replaces the previous one. `grug_core.can_use_item_level` is the
  shared `_grug_ilvl` gate for the Weapon slot and all consumables. Potions
  retain their instant channel and shared persistent cooldown.
  `grug_cooking` owns the mapgen-free plant items, the 18 grid dishes, the six
  raw assembled dishes and their furnace routes. `grug_fishing.table_for(pos)`
  selects one of six catch tables through `grug_core.mob_level_at(pos)`; water
  salinity never gates fishing.
  **Alchemy** is split between low-level `grug_brewing` (the inactive/active
  stand nodes, timer and recipe adapter) and `grug_alchemy` (items, profession
  recipes and effects). The stand has two reagent slots plus vial, fuel and
  output. Automatic completion is universal and grants no profession progress;
  the qualified inventory-grid mixture preparation owns progression. Capital
  personal workspaces derive from terrain-resolved,
  rotated `public_station` sockets in the themed outer premises.
  `grug_jobs.register_public_position(station, pos)` owns the shared registry;
  `grug_brewing.register_public_position(pos)` delegates the brewing stand.
  No fixed capital-core position is authoritative. Potions share
  `grug_traders`' persistent clock (60 s, or 45 s for the Greater pair);
  elixirs replace status id `elixir`, stack with status id `food`, and never
  touch that clock. Apothecary gear extends timed potions and elixirs by 10%
  per piece (maximum two), but does not change instant potions.
  `grug_gathering`'s herb authorizer delegates to
  `grug_jobs.has(player, "alchemist")`; Cave Cap remains universal food.
  Real-code Lua 5.1 regressions live under `tools/wp39/` and must stay green
  when changing the ray, clock, settlement, reticle, casts or projectiles.
  **Ordinary tool WEAR is spent per swing, not per punch**
  (`grug_core.melee_wear_due`, keyed per player AND per persistent opaque
  `_grug_melee_wear_id` on the concrete ItemStack): A→B cannot transfer A's
  partial wear to B, returning to A resumes it, and empty/non-tool,
  creative/use-0 punches neither assign an id nor consume state. The wear
  block in api.lua now runs on all ~5 packets/s, and
  paying a full swing's wear each time both wears the tool `1/fraction`
  times faster and fires `set_wielded_item` — a full inventory
  serialization plus packet — per punch, ~500/s at the 100-player target.
  **PvP melee runs through the same pipeline** (the on_punchplayer
  handler in grug_abilities): an authoritative ability swing builds the
  slot-fed full swing, adds Strength/proc, rolls crit once, applies
  `grug_core.apply_player_armor` with attacker-level provenance and the
  rating formula capped at 70% reduction, then enters
  dodge/absorb once. A native swing-item packet is suppressed and never
  authorizes the final target. Ordinary tools/fists still scale their wielded-stack full
  equivalent by `fraction` and accumulate. Their integer commit uses `set_hp`
  with `type="punch"`/`object` and
  `custom_type="grug_core:player_armor_applied"`; the central modifier skips
  only the already-run armor step while dodge and absorb still run once.
  `return true` always suppresses handled hostile engine damage. Tool/fist PvP fractions bank
  with the damage remainder and pay `12 × committed_pending_fraction` only
  when a commit actually lowers HP; bank-only packets pay nothing, target
  switches discard both banks, and dodge/full absorb consume the credit for
  0 rage (partial absorb with HP loss still lands). Thus unmitigated fractions
  totalling 1 pay +8 independent of weapon damage, without the old 60 rage/s
  packet firehose. Base mob threat still takes raw fractional damage.
  Same-faction pairs stay with grug_factions' handler
  (RUN_CALLBACKS_MODE_OR, s_player.cpp:63 — neither vetoes the other);
  knockback on players keeps coming from builtin off the engine's damage
  argument (deferred, MVP): acquisition caps are zero, while the one
  authoritative punch supplies the real full caps. Tools/fists keep their wielded source and wear;
  swing ability items use the slot source, do not wear and can carry the
  selected proc's threat multiplier. The current server ray is the sole
  authoritative hostile ability target while LMB is held; enemy memory is
  UI-only.
- **Mobs**: embed and patch mobs_redo (MIT). Faction targeting: condition
  in `general_attack()` (api.lua:1853-2017) following the LotT pattern
  (`race` field in the mob def + ally check); territory/tier gating via
  `mobs:spawn_abm_check()`. Tiers via `hp_max`/`armor` (lower = tougher)/
  `damage`/`view_range`/`group_attack`. Dynamic loot: `drops` can be a
  function. Quest kill credit subscribes to the shared eligible participant event
  from `grug_mobs.award_kill_xp`; it must not use only the death killer.
  Quest/trader NPCs: `type="npc"`, `passive`, `on_rightclick` → formspec;
  placement via `mobs:add_mob(pos, def)`.
  **Pathfinding is a quality criterion** (user requirement: dangerous mobs
  must not fail at terrain, otherwise they are not dangerous): mobs_redo
  has `pathfinding = 1|2` (uses `core.find_path`, 2 = can break/build
  nodes) plus `stepheight`/`jump_height`/`fear_height` — always enable and
  test these when tuning mobs. VoxeLibre `mcl_mobs` has its own, more
  advanced `pathfinding.lua` (+ the villagers' `gopath`) — if mobs_redo
  pathfinding is not good enough, adapt from there (GPL ok, see below).
  Fallback design: additionally make heartland mobs fast (`run_velocity`)
  and give them ranged attacks (`attack_type = "dogshoot"`) so terrain
  exploits are not trivial.
  **WP6 patterns (binding for every new mob):**
  - **Level/tier engine contract** (`grug_mobs/levels.lua`): a mob def
    NEVER hand-sets `hp_min`/`hp_max`/`damage`/XP/`armor` — they are
    derived from `grug_core.mob_level_at`/`guard_level_at` plus the tier
    multipliers on the first active tick. `_grug_fixed_level` is the sole
    explicit fixed-entity mechanism: it bypasses positional/role fields only
    for deliberately designed fixed entities. Its implemented uses are the
    Kraken L100, the island dragons L70, the capital kings L65 and their royal
    guards L60. There is no second king-specific level path.
    Everything else (speeds, view_range, drops, visuals) stays def-owned.
    **Four tiers since WP36**: `critter` (added for the small animals —
    fixed L1, 1 HP, 0 XP, no fall damage, never promotable; the second
    documented exception to "stats derived") plus `normal`/`elite`/`rare`,
    whose arithmetic is unchanged. The **telegraph gate is a POSITIVE
    elite/rare test** (`grug_mobs.tier_telegraphs`, one predicate for both
    call sites) — a `tier ~= "normal"` test hands a rabbit a 2 s wind-up
    and a ×3 cone hit the day a fourth tier appears.
  - **Per-viewer nametags since 2026-09-18**: every tagged mob, peaceful NPC,
    vendor and player owns one invisible `grug_core:tag_carrier` child. Parent
    tags stay empty/alpha-zero; the child text is observer-managed at 25 m show
    / 30 m hide independently per viewer, with a player's owner excluded.
    Create/remove carriers through the shared `grug_core/tag_carrier.lua` seam,
    update text there (including telegraph/tier/HP changes), and leave observer
    sets plus orphan cleanup to that module's one central 1 Hz pass. Carriers
    are non-pointable, non-physical and unsaved. Unsaved Lua entities never
    enter the engine's static-object count used by mobs_redo `aoc`; do not
    compensate or otherwise modify that spawn-budget comparison for carriers.
  - **Three behaviour classes, and a new mob picks one**
    (`biomes_mobs.md` §3.0): **critter** (small, scenery with a use —
    food-only drops, `passive` + `runaway`), **passive prey** (the large
    grazers — `grug_mobs.passive_prey` in `verbs.lua`: `passive = false`
    is what buys retaliation, `attack_players`/`attack_npcs = false` is
    what removes aggro on sight, `runaway` must be OFF because on_punch
    sets it a dozen lines before the retaliation block resets it, and
    **`attack_type` must be set** — `do_states`' attack branch dispatches
    on three values with no `else`, so a retaliating mob without one holds
    a target and does nothing at all) and **enemy** (§3.1's verbs).
    Ground mobs that can end up in the attack state carry
    `pathfinding = 1`; fliers never do (`core.find_path` is a ground
    search).
  - **Runtime field installation**: mobs_redo's `register_mob` copies an
    EXPLICIT def-field whitelist into the entity table (api.lua:3956-4112)
    and staticdata drops function fields — so every `_grug_*` field an
    api.lua patch reads off `self`, and every callable, must be
    (re-)installed from the `do_custom`/`do_punch` wrappers on each
    activation, not written in the def.
  - **Countdowns tick in `do_custom`, never `core.after`**: a mob can
    die, be unloaded or leash-reset inside the window, and mobs_redo
    persists plain fields — a lost timer would save the mob permanently
    rooted. (`core.after` is fine for PLAYER-side effects, re-fetching
    the player by name.)
  - **Chase model** (combat_stats §3/§4, Round 19 follow-up): ordinary
    ambient mobs have no distance give-up/slowdown. After 15 s without effective
    incoming damage from any player/eligible guard, a live current target must
    move at least 0.25 nodes horizontally since the previous 1 Hz sample before
    return starts. Standing still does not reset that clock; outgoing mob hits
    do not refresh it. Sample only target X/Z in runtime temp, reseed on target
    switch, and preserve dead/missing-target cleanup. Bosses/guards/camps/rares
    retain their authored limits, including 45 m give-up, 25 m slowdown and
    40 m chase-origin drag/contact timeout where applicable. Return-home and
    the 40 s teleport fallback remain unchanged.
  - **Idle recovery** (Round 19 follow-up): registered living mobs/guards/bosses
    fully reset after 30 s calm without observed HP loss. Actual targets/actions,
    runaway/flop, evade and shared recent boss-group activity block recovery.
    Sample HP at the existing 1 Hz maintenance tick, all sources included;
    reward ledgers are not combat state. Never refresh pursuit from outgoing
    hits, never resurrect, never heal a retinue member mid-encounter.
  - **`aoc` is per entity NAME**, counted in a 128-node sphere — two
    rows of one name share a budget, per-biome tints do not. Spawn
    calibration reference: **`docs/research/wp6_spawn_budget.md`**.
  - **62 `GRUG PATCH` sites in `mods/ENTITIES/mobs/api.lua`** — the
    inventory and rationale live in VENDOR.md; re-apply them on any
    mobs_redo update. The 41st to 43rd (mob pressure, 2026-09-16) are the
    attack-cadence patch of `combat_stats.md` §4 and user ruling 1: the
    cadence advances during the CHASE with the backlog capped at one, the
    in-reach branch runs to a contact distance of `reach × 0.6` instead of
    freezing the mob, and the punch sits outside both branches with the
    in-reach and line-of-sight tests where it lands. The 44th to 59th
    (round-5 combat AI, 2026-09-17) raise ordinary reach to 3 m, navigate
    blocked close cover, remove implicit ordinary-hit knockback and disable
    object-to-object collision; `mobs/grug_obstacle.lua` holds the bounded
    production state decisions used by that attack path.
    The 40th (WP13 playtest round 2, 2026-09-15) is the
    per-TARGET non-combatant veto in `general_attack`'s candidate filter:
    hostiles and guards MAY fight each other, but nothing in the world may
    acquire an entity carrying `_grug_noncombatant` (villagers, elders,
    vendors — they cancel every punch, so such a fight never ends). The flag
    is installed at activation by `grug_mobs.noncombatant`; do NOT narrow an
    attacker's `attack_npcs` on a civilian's behalf.
    WP35's 21st: the `set_wielded_item` write-back at
    the end of the wear block runs only when wear/toolranks changed the stack
    or WP38's per-stack wear id was newly assigned (on a player that call is a
    full inventory serialization plus packet; the skipped no-op ability writes
    were ~140/s at the 100-player target). WP38
    reshaped the melee patches: the 2026-08-07 cadence gate is deleted;
    the player-melee flag is `grug_melee`, the damage loop keeps
    vanilla's `tflp/fpi` factor (that IS the proportional model) and
    adds the Strength bonus before armor scaling, the crit roll is
    unfloored (the accumulator floors at application), knockback fires
    when the accumulated hit lands (`subtract >= 1`), and the
    feedback/subtraction split moves hit sound/blood/flash in front of
    the `damage >= 1` gate while the health subtraction and
    `check_for_death` run on the accumulated integer (passed directly to the
    post-cancellation accepted-hit hook for its lethal check).
    The WP38 review added two more: `grug_fraction` (the punch's
    clamp(tflp/fpi, 0, 1), computed once from the normalized `tflp`) and
    the wear gate that spends a swing's wear only when
    `grug_core.melee_wear_due` says that concrete stack's fractions add up
    to a whole swing — placed AFTER the item-type, creative and
    `punch_attack_uses` adjustments, so a wear-free punch never gets an id or
    consumes the accumulator. A newly assigned id is written back once even before wear is
    due; a broken stack's runtime entry and every leaving player's table are
    cleared. The 2026-08-10 native-input correction added two sites: full
    authoritative proc preparation folds the selected skill's replacement
    delta into the same punch before crit, and accepted finish after
    `do_punch`/CMI is the only place that pays/resets/applies it. The review
    added the 31st site: `grug_mobs.accepted_player_punch` runs provocation, loot
    tag, threat/rage and lethal rare/XP work only after both `do_punch` and CMI
    accept, before health subtraction; the melee-crit visual is deferred to the
    same boundary, so neither cancel path has irreversible hit side effects.
    The held-soft-target correction adds the 32nd marker: a native swing-item
    combat packet calls the Core input/acquisition seam and returns before all
    mobs_redo combat side effects; only the exact-target, claim-once token of a
    server-owned full punch may continue.
- **Enchantments**: chosen named prefix/suffix recipes use fixed bonuses by
  enchantment tier, including jewelry; there is no refinement step or random
  crafted bonus. Family eligibility and replacement rules belong to the gear
  design. Per-stack appearance keys (`inventory_image`, `inventory_overlay`,
  `wield_image`, `wield_overlay`, `wield_scale`, `color`, `range`, `description`)
  override item definitions. Build texture modifier strings in one helper:
  malformed modifiers produce client-side image errors that may not appear in
  server logs. Equipment changes must notify the shared equipment seam.
- **Materials & depth gating** (`items_crafting.md` §3.0,
  `world.md` §2 R6):
  - **Shipped WP43 contract:** Bronze, Iron, Steel, Silversteel, Embersteel
    and Abyssal Steel are the six universal tiers, with inclusive natural
    depth limits y = -100/-300/-500/-700/-1000/-31000. `grug_materials` is
    the sole owner of `TIERS`, `TIER_BY_KEY`, `tier_at(y)`,
    `stratum_node_for(y)`, `max_depth_for_pick_tier(tier)` and
    `can_mine_natural_at(pick_tier, y)`. Consumers never copy a depth
    boundary, harvest tier, stratum name or race-region assignment.
  - Registry consumers use `RESOURCES`, `RESOURCE_BY_KEY`,
    `RESOURCE_BY_NODE`, `PROCESSED_MATERIALS`, `GEM_GRADES`,
    `CULTURAL_MATERIALS`, `SIGNATURE_WOODS`, `RACE_REGIONS` and `DENSITY`,
    with the `resource`, `resource_for_node`, `resource_node` and `processed`
    accessors. `CURRENT_SCATTER_RESOURCES` is only the pre-WP40 placement
    roster. WP40 replaces its geometry with race-region columns; it does not
    replace or duplicate this taxonomy.
  - The natural-node contract is explicit. Picks carry
    `grug_pick_tier = 1..6`; generated ground carries `grug_natural = 1`;
    resources additionally carry `grug_resource = 1..5`. Mapgen owners must
    add every new generated ground node to `NATURAL_GROUND_NODES` and apply
    `natural_groups(groups)` when registering their own nodes. Never infer
    natural ground from `is_ground_content`: the engine defaults that field
    to true even for saplings and decorations. `NATURAL_GROUND_SET` is the
    audited lookup, not a second extension point.
  - The server-authoritative `core.node_dig` wrapper evaluates protection,
    exact target y and then the separate harvest tier. `mining_decision`
    returns structured `protected`/`no_pick`/`depth`/`shatter`/`allowed`
    state; `emit_mining_failure` owns the throttled player feedback. A depth
    refusal happens before node damage, wear, drops or settlement. A
    completed under-tier resource dig takes ×4/×6/×8/×10 time, spends exactly
    one ordinary pick use, suppresses drops and every harvest callback, emits
    shatter feedback and still lets a renewable socket enter its depleted
    state. Successful sufficient-tier settlement uses `register_on_harvest`;
    socket consumers distinguish the no-drop transaction with
    `is_shattering`.
  - All material-system nodes have no engine `level`, and every Grudgelands
    pick groupcap has `maxlevel = 0`; `max_drop_level` is a separate ordinary
    drop property and may remain non-zero. `build_pick_capabilities` and the
    six `PICK_PROFILES` are the verification/consumer seam. WP29 owns the
    final playable pick catalog and recipes, while WP22 owns runtime
    speed/durability calibration. Canonical storage blocks, Iron Sign/Ladder
    and the 20 canonical metal stair/slab nodes are storage/building
    derivatives, not natural ground and never harvest-gated.
  - Emberglass and Abyssal Steel are the canonical names. Fresh-server mode
    forbids earlier-version material aliases and migration readers. WP26 owns
    furnace/alloy/storage recipes in `mods/ITEMS/grug_smelting`; its
    `grug_smelting.RECIPES` surface is consumed by the trader anti-loop audit
    because engine craft inspection cannot see dual-furnace recipes. Recipe
    ownership and remaining economy work are tracked in BACKLOG.
- **Traders/gold** (shipped with WP7; `docs/design/economy.md`,
  `items_crafting.md` §3.8/§8.2, `world.md` §7). **WP7 patterns
  (binding):**
  - **`grug_money` is the ONLY money API.** One integer in copper units
    in player meta (100c = 1s, 100s = 1g, conversion display-only);
    `get/set/add/take` (take is atomic and never goes negative) plus
    `register_on_change`. **Never read or write the meta key directly** —
    the clamp, the HUD refresh and the change callbacks all live in
    those functions. `PlayerMetaRef:set_int` is a real 32-bit signed
    store, hence the hard ceiling `grug_money.MAX`.
  - **`_grug_sell_price` (copper) is the universal buy-back field** in
    an item def — that is how "traders buy EVERY mob drop" is
    guaranteed. For **foreign items we must not touch** (vendored
    `default:` / `mobs:`) use `grug_traders.set_price(name, copper)`
    instead of overriding someone else's def; `grug_traders.sell_price`
    resolves override → def field → 0, and **0 means "not sellable"**.
  - **`grug_gear` is a GENERATED catalog, never a hand-written list**:
    the six bracket catalogs come out of the §3.1/§3.2 curves at load
    time. Public surface for anything that sells gear:
    `grug_gear.BRACKETS`, `bracket_for_level`, `get_price`,
    `get_sell_price`, `catalog[b].fixed/.extras/.all`. **Running WP7 legacy
    still buys back at 25%** and still uses its old generated price curve.
    The authoritative target is the Common-price axis plus ceiling-rounded
    **5%** buy-back in `economy.md`; WP44 migrates the catalog and payout
    tables without bypassing these APIs.
  - **Armor pipeline**: item `_grug_armor` values and every additive source
    aggregate as uncapped raw rating `A`. The deep Bulwark Unbroken capstone
    multiplies that aggregate by 1.65 and its emergency window then adds 15.
    For authoritative attacker level `L >= 1`, `K = 20 + 0.5*min(L,60) +
    8.5*max(L-60,0)` and reduction is `min(0.70, A/(A+K))`. Apply once to
    player combat damage before absorb, with the existing final `math.ceil`;
    environmental/fall damage has no attacker provenance and bypasses armor.
  - **Armor-rank gate**: items carry `grug_armor_class` (cloth 1 <
    leather 2 < metal 3), classes carry `armor_rank`
    (`grug_classes.get_armor_rank`, no class = 1); the check sits in the
    existing group-filtered `allow_put` with a **throttled** chat
    refusal (the allow callback fires repeatedly while dragging), and a
    class change unequips what the new rank may not wear.
  - **Vendor NPCs use plain `mobs:register_mob`, NOT
    `grug_mobs.register_mob`** — that wrapper IS the level/XP engine and
    would give a shopkeeper a level, a health bar and aggro wrappers.
    `type = "npc"` is what makes them permanent (it exempts them from
    all three mobs_redo removal paths); a **truthy `do_punch` return**
    is what makes them invulnerable (the api.lua precedence gotcha
    above). WP7's placement was a throttled globalstep against fixed capital
    offsets, whose presence gate must stay inside the object-activation
    radius or duplicates spawn forever. **Since WP13 that is only the
    fallback**: a settlement's vendors stand on the `vendor` sockets its
    blueprint exports (`grug_core/settlement_sockets.lua`, placed by
    `grug_mobs/start_npcs.lua`), and the offsets serve only a capital whose
    core has not been built — an empty set since all six cores landed.
    `grug_traders/vendors.lua` reads which capitals are socketed from the
    registry, never from a hard-coded list. The twelve **profession shop**
    vendors (butcher, smith, fishmonger, baker, tailor, mason, brewer,
    bowyer, herbalist, armourer, tanner, embalmer) are socket-only, carry no
    race of their own — the settlement key answers that — and only `smith`
    and `armourer` reach the gear-bracket tabs.
  - **Rotation is deterministic**: seed = `floor(os.time()/3600)` +
    per-vendor salt + bracket, fed into **`PcgRandom`** — never
    `math.random`/`table.shuffle`, whose sequence depends on what else
    called them since startup. Two players at one vendor in one hour
    must see the same shelf, and a restart must not re-roll it.
  - **No detached inventories in trade UIs.** The reference
    implementations (VoxeLibre `mobs_mc/villager.lua`, LotT
    `lottmobs/trader.lua`) move items through detached
    `wanted/input/offered/output` lists — that loses whatever sits in
    the input list when a player disconnects mid-trade. Every transfer
    goes directly against the player's own `main` list, the vendor's
    "stock" is a computed list of names and prices, and **every formspec
    action re-validates from scratch** (session, distance to the stored
    POSITION not an ObjectRef, access rule, and prices/counts recomputed
    server-side against the snapshot the player was shown).
  - **Three startup audits** in `grug_traders/init.lua`
    (`register_on_mods_loaded`; no warning/error finding when clean —
    one informational action line, the function-drop audit count,
    always prints): every mob drop has a
    price; no vendor buy/sell spread that prints money (discount
    included); no craft/cook recipe whose output is worth more than its
    priced inputs (the §3.8 anti-loop rule — the real case was smelting
    a 3c iron lump into a 5c steel ingot). Add prices, don't disable
    them.
- **Quests (Round 14):** `grug_quests` owns a strict registry, 20-slot player-meta
  journal, kill/item objectives and claim-once turn-in with main/owned-bag
  inventory preflight. The per-mob eligible damage/effective-heal participant
  set grants credit independently of party membership and gray-XP suppression.
  `npc_by_socket` keys actual settlement identity plus socket id, never terrain
  anchor ids. Marker children partition observers through the existing tag
  carrier's one-second 25/30 hysteresis pass; no independent player scan.
  Quest UI tracks three selected quests and stores its HUD preference. The
  102-quest catalog (66 starter + 36 local) requires only V1 overworld content; the Nether is
  reserved for the first expansion. Quest item labels use concise names rather
  than stat/durability lines; worn matching stacks remain valid turn-ins.
- **Parties (Round 14):** `grug_parties` persists groups of 2–10 same-faction
  members and their leader in mod storage. Offline membership/leadership lasts
  indefinitely. Invitations are ephemeral inviter-bound records; a second
  member creates the group, one remaining member dissolves it. No party XP,
  loot or quest-credit rules. UI actions resolve rendered stable identities,
  then core APIs revalidate current authority. HUD HP writes are compare-first.
  The saved color preference defaults to By class; an explicit All green choice
  persists. Current geometry and offline presentation: [parties.md](../design/parties.md).
- **Atlas**: `grug_map` owns one whole-world cartographic atlas with 1x/2x/4x
  zoom, native scrollbars and an independent marker layer. Formspec v4 wraps
  the shared legacy inventory window; only Map content switches to real
  coordinates. Keep center-preserving zoom, fixed-size markers, clipping and
  hit bounds in the same transform. A new tab visit resets zoom/scroll; live
  updates preserve them. Stable byte-encoded IDs own marker identity. Only open
  Map sessions poll at 0.5 s and write changed formspecs; scrolling defers rebuilds
  until a 0.5 s quiet interval. Closing resets to Character; leave/death clean up.
  Current marker/travel/minimap rules: [world_map.md](../design/world_map.md).
- **Preparation (Round 14):** `grug_core` freezes starts/full mode in world
  storage on first boot. A stable aligned plan has one in-flight chunk and a
  success-only cursor; dispatch occurs in throttled globalstep, not callbacks.
  Full mode includes a 320-node ocean margin and replaces starts preparation.
  Round 16 resolves one conservative surface envelope at a time, counts completed
  horizontal tiles and persists the inner Y-chunk cursor. Its authority identity
  binds stable seed/content and bounded terrain-source bytes, never runtime CIDs.
  No full-world height prepass, exact savings run or ETA retuning.
  Preparation precedes character selection. Bounded scan-time/small-batch
  selection dispatches available work immediately while retaining one in-flight
  request. Waiting may be dismissed without releasing safety gates; only a new
  failure transition reopens the retry form. Both creation and reconnect use
  the shared waiting/stasis gate. Native tests
  use isolated tiny bounds; never run production full generation as a test.
- **Fishing (Round 14):** transient bobber, manual reel in a 1.5-second bite
  window, missed bites rearm; only successful catches wear the returned rod.
  `grug_abilities.notify` shares the neutral latest-message HUD token, no catch
  chat spam. Death, leave, shutdown, invalid water/rod and distance clean up.
- **Mapgen/biomes.** The **WP40 R7 pipeline is the only mapgen owner** since
  the production cutover: `mods/MAPGEN/grug_mapgen/init.lua` registers the protected POI display
  palette, then loads `wp40/r7_loader.lua`, whose header says it plainly — "Legacy
  biome/ore/decoration/ocean/structure loaders are deliberately absent".
  `grug_mapgen/biomes.lua`, `ores.lua`, `decorations.lua`, `geometry.lua`,
  `ocean_mask.lua`, `ocean_mask_mapgen.lua` and `structures.lua` **no longer
  exist**, and neither do `register_mirrored`, `column_cap`, `clean_shell`,
  `_grug_spawn_zones` or the `grug_core.*camp_platform*` family. Do not write
  code or a brief against them; `docs/design/world_zones.md` §§8–14 and
  `docs/research/wp40-completion.md` are the current contract, and
  `docs/design/biomes_mobs.md` §1/§4 keep the retired WP18/WP36 tables as a
  labelled historical record only.
  What R7 registers, and what that costs you: **zero Lua biomes and zero Lua
  decorations**. One mapgen script (`core.register_mapgen_script`,
  `wp40/r7_mapgen.lua`), one `register_on_generated` VM transaction, and a
  six-record native ore allowlist in `wp40/r7_native.lua`. `game.conf` pins
  `allowed_mapgens = v7`; `default`'s own `register_biomes/ores/decorations`
  stay uncalled (GRUG PATCH at the tail of `mods/BASE/default/mapgen.lua`),
  because an ore or decoration whose `biomes` names do not resolve is silently
  unrestricted world-wide. The v7 terrain and climate noise params are
  overridden from `r7_native.lua` (`core.set_mapgen_setting_noiseparams`) —
  **test mapgen work on a FRESH world**, an existing one gets seams.
  **Registration order is still a tool, not trivia**: in mgv7 a mapchunk runs
  caves (`mapgen_v7.cpp:335`) → ores (`:355`) → dungeons (`:359`), and inside
  the ore stage the ores run in **registration order**, each converting only
  nodes that still match its `wherein`. That is the whole mechanism behind the
  rock strata, which now live as five native `ore_type = "stratum"` records in
  `wp40/r7_native.lua` (slate/basalt/granite/emberrock/abyssal_rock under
  `default:stone`'s own band): registered last against `default:stone`, they
  take exactly the nodes no other ore claimed, and — running after the caves —
  they convert the already-carved cave walls too, so those inherit their
  stratum for free. (Dungeons run after the ores, so dungeon walls are *not*
  stratum rock — accepted.)
  **Landmine since WP25: `default:stone` no longer exists below −100.**
  Every node whitelist, every `wherein`/`place_on` and every mob spawn
  `nodes` list that means "underground rock" has to carry
  `group:grug_stratum` as well, or it silently narrows to the −40…−100
  sliver. WP25 repaired exactly that on four cave spawn rows (zombie,
  giant spider, stone + mesa golem); `default:stone` itself carries
  `grug_stratum = 1`, so the group alone is the complete predicate.
  **Two Lua environments, and the split is the rule, not a detail**: a pass
  that only needs the chunk belongs in the **mapgen env**
  (`core.register_mapgen_script`), a pass that needs `grug_core`, mod storage
  or the settlement/socket registries cannot go there at all and stays in
  `register_on_generated` in the main env. Constants cross via `core.ipc_set`;
  never copy them. **One lesson from the retired ocean mask is worth keeping
  for the next VM pass:** a pass that writes near the top of a mapchunk must
  reach **`emax.y`**, not `maxp.y`, because the engine places decorations up to
  the emerged top edge (`mg_decoration.cpp:424`) — clamping to `maxp.y` is what
  once left floating tree crowns over the water.
  **Current zone/level queries** (published by `grug_core/zone_authority.lua`,
  which is also the sole publisher of the `grug_zones` global — it refuses to
  install if something else already published it) — this is the whole
  `grug_core` surface, not a sample: `territory_at`, `zone_at`, `mob_level_at`,
  `guard_level_at`, `open_sea_at`, `surface_level_at`, `start_position`,
  `start_anchor`, `start_identities`, `capital_anchor`, `outpost_at`,
  `outpost_patrol_target`, `outpost_position`, `rare_route` and
  `world_protected_for_faction`. `grug_core.difficulty_at` is **gone** — the
  difficulty field survives only inside WP40's own compatibility layer.
  Gameplay consumers read the richer surface off `grug_zones` directly
  (`biome_at`, `id_at`, `faction_at`, `race_region_at`, `pvp_rule_at`,
  `water_class_at`, `territory_rule_at`, `surface_mob_level_at`) and **never**
  the engine biomemap, because the authored surface pass — not climate
  competition — owns logical biome identity.
  **R7.6 difficulty seam (2026-09-18):** `simple_map.lua` derives straight
  z-axis progression extents from authored hub rows and the fixed
  Battlegrounds edges, splits each published zone range into three rational
  thirds, and serves an integer staircase through
  `difficulty_for_macro_at`; `zones.lua` applies the 100/150-node start safety
  override afterward. Accord runs toward +z, Throng toward -z, front zones
  toward z=0 and the two summits are flat 60. The compatibility method
  `difficulty_lattice_digest()` authenticates the profiles, raw-x midpoint
  selector results and complete integer staircases despite its historical
  name; there is no difficulty lattice or hub-target smoothing. Difficulty
  lateral selection is warp- and bias-free even though political ownership is
  not.
  The unchanged underground term already supplies three integer threshold
  steps per uncapped 50-node window, and `mob_level_at` remains
  `max(surface, depth)`.
  **R8-MAP-A terrain seams (2026-09-18):** `height.lua` owns 48-node coast-run
  identity split by stable water/relief class, one seeded profile per identity
  and bounded height blending behind the exact first dry bank. `r6_content.lua`
  owns the corresponding beach/bluff/cliff surface rows and is the only new
  source of dry near-water sand; ordinary wet-bed sand remains unchanged.
  `r6_settlement.lua` owns shallow filler/stone-only strata and the final cave
  transaction. `zones.lua` publishes 80-node owner-local cave candidates but
  never an offline cut; the writer carves only after immutable native-v7 air
  beneath a three-node roof is witnessed within 24 vertical and (for a
  sinkhole) 24 horizontal nodes in the same mapchunk, then validates the exact
  path against natural input and every surface exclusion. A commit additionally
  requires at least 24 unchanged native-air nodes outside the lumen, continuation
  to the boundary of a radius-12 proof box and no native-surface/sky contact in
  that bounded component. Closed and isolated pockets are rejected. Do not move cave
  connection decisions into the planner or infer them from emerge order.
  LotT trick: biome signature nodes drive mob spawns via a node whitelist —
  those tops live in `grug_nodes` (blight_dirt, bone/forest/silver litter,
  mesa_clay, mud) and exist FOR the trick; the generic `_grug_spawn_check`
  and `grug_mobs/spawn_policy.lua` do the gating on top, against `grug_zones`.
  `register_spawn_role` also owns each family's `clock`; its spawn wrapper
  stamps the mobs_redo light/day convention and the night `aoc`, while rows
  wholly below y = -40 remain light-only. Never hand-maintain those fields on
  a new surface row.
  Fixed bosses do not register ambient rows: `grug_mobs/bosses.lua` owns the
  two authenticated island `dragon` anchors, while the six kings and their
  four-guard groups consume the capital `king`/royal `guard_post` sockets via
  `start_npcs.lua`. Their respawn timestamps are absolute `os.time()` values;
  never route them through the ambient spawn clock or gametime respawn path.
  **The WP40 world contract is SHIPPED** (decided 2026-08-11, delivered
  2026-09-13): exactly **38** land zones in
  `docs/design/world_zones.md` §§8–9, each with one `race_region`; six
  start/home/capital chains, every ordinary level-31–60 zone contested, and
  two level-60 dragon endpoints. The hybrid-v7
  pass and `grug_zones` API are §13; the 32-seed acceptance gate is §14.
  Race region, territory and PvP rule are independent fields. Every ordinary
  level-31–60 land zone is contested and editable by both factions. Roads,
  camp shells, tents, fences and battlefield dressing remain mutable but
  claim-excluded; only bounded functional anchors, irreplaceable route pieces
  and renewable-resource sockets receive hard protection.
  Material design owns the complete `race_region` mapping of
  G1, G2, cultural material and signature wood; map code stores only the
  region identity and placement data needed to consume that mapping. Each
  endpoint apex camp has exactly 12 renewable sockets, two per gem. Both
  factions may mine them; the small functional anchor and sockets are
  protected, while the surrounding camp shell remains mutable and
  claim-excluded.
- **World atlas**: `docs/design/world_map.md` governs the cartographic Map tab,
  with no fog of war and independent future-interactive markers. It needs no
  generated-terrain bitmap and never unlocks waypoint travel.
- **UI**: formspecs (`core.show_formspec` +
  `register_on_player_receive_fields`), set `formspec_version` +
  coordinate mode deliberately. Map retains the shared legacy outer window and
  uses real coordinates only inside its content. 3D preview: `model[]` element.
  Skill tree = formspec with an `image_button` grid.
- **Player model/skins**: `player:set_properties{visual="mesh", mesh=...,
  textures={...}}`; texture layering (skin/armor/wielditem) following
  LotT `lottarmor/multiskin.lua`.

