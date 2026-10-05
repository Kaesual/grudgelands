# Module implementation guide

Extracted from AGENTS.md during the 2026-09-23 documentation consolidation.
Read only the relevant module section. This guide describes implementation seams
and engine pitfalls; [living design](../design/README.md) owns game rules and
[BACKLOG](../../BACKLOG.md) owns remaining work. Historical WP names identify
origins, not permission to restore superseded behavior. Source paths in code
spans are repository-relative. This is not a fresh certification of every API.

Which mod owns what: the [mod ownership map](mod-map.md). Related technical
references: [Lua/engine constraints](luanti-lua.md),
[reference projects](../reference_projects.md), [vendor patches](../../VENDOR.md),
[upstream workarounds](upstream-workarounds.md).

Sections: [Factions and character creation](#factions-and-character-creation),
[PvP](#pvp), [XP and levels](#xp-and-levels), [Professions](#professions),
[Crop registration](#crop-registration), [Skills
catalogue](#skills-catalogue), [Mount runtime](#mount-runtime), [R7 audit
boundary](#r7-audit-boundary), [Trinkets](#trinkets), [Combat and
classes](#combat-and-classes), [Mobs](#mobs), [Mob sub-types, loot and spawn
regions](#mob-sub-types-loot-and-spawn-regions), [PvP garrisons and dragon
arenas](#pvp-garrisons-and-dragon-arenas), [The rift](#the-rift), [Mob
voices](#mob-voices), [Dawn departure](#dawn-departure), [Mobs in
water](#mobs-in-water), [Enchantments](#enchantments), [Materials and
tier-rock gating](#materials-and-tier-rock-gating), [Traders and
money](#traders-and-money), [Quests](#quests), [Parties](#parties),
[Housing](#housing), [Travel](#travel), [Atlas](#atlas),
[Preparation](#preparation), [Fishing](#fishing), [Mapgen and
biomes](#mapgen-and-biomes), [World atlas rules](#world-atlas-rules),
[Sound](#sound), [UI and formspecs](#ui-and-formspecs), [Player model and
skins](#player-model-and-skins), [Looks and enchant
colours](#looks-and-enchant-colours), [Cloaks and
achievements](#cloaks-and-achievements).

## Factions and character creation

- **Factions**: pattern from Lord of the Test `lottclasses` — faction as a
  **privilege** + ally matrix + predicates (`*_same_race_or_ally`),
  selection formspec on join, starter-kit dispatch. Our creation flow differs
  (Round 35): `grug_classes/selection.lua` owns one window
  (`grug_classes:create`: faction, race, class and the look panel
  grug_visuals registers) and the waiting screen (`grug_classes:loading`).
  The choices are a session-only draft (`session.draft`, checked again at
  Create); "Create character" calls `set_faction`, `set_race`, the panel's
  `store` and `set_class` at once and sets `grug_classes:arriving`, which
  keeps the character in stasis until the arrival teleport clears it. Esc
  closes a form for good (Round 24 ruling 32); the current window is always
  the player's inventory formspec, while sfinv is suspended through the
  vendored `sfinv.inventory_suspended` hook (VENDOR.md), and "" submissions
  route to the same handlers; a HUD hint at
  `hud_layout.anchors.creation_hint` shows while no dialog is open; release
  re-runs sfinv for the player. Fixture and engine probe: `tools/r35_c`.
  LotT has NO per-faction spawns and no player-PvP gating — we build those
  ourselves (`core.register_on_punchplayer` /
  `register_on_player_hpchange`).
  **Service rule (Round 31):** `grug_factions/service.lua` —
  `grug_factions.serves(npc_faction, player)`, `refusal` and `refuse` (one
  line, at most every 2 s per player). Every quest giver, vendor (a
  profession vendor takes its settlement's faction), trainer, innkeeper,
  steward, Shipwright and waystone asks it with the NPC's faction, never
  the place; fixtures load it on a fake faction table (`tools/r31_n`).

## PvP

- **PvP (Round 31, WP41):** `mods/PLAYER/grug_pvp` owns the flag. `rules.lua`
  is pure (the record, the timers 60/60/10/15 s, `credited`); `init.lua`
  keeps one record per online player, samples the location once a second
  (`pvp_rule_at`, `faction_at`; never on the combat path) and exposes the
  API in its header (`flagged`, `can_harm`, `can_support`, `contact`,
  `support_contact`, `flag_now`, `state`, `territory_at`, `stats`,
  `register_on_change`, which also fires once at join, before any HUD
  exists, `register_on_stat(fn(player, key, value))` after a `stats` counter
  went up (Round 33, grug_achievements' Honored), and `count_npc_kill`). `grug_core` must not depend on it: `grug_pvp` installs
  `grug_core.pvp_can_harm` (the impact re-check in `deal_ability_damage`
  and the crosshair's `protected` class) and `grug_core.pvp_hit_landed`
  (contact from the hp-change modifier, so absorbed hits count);
  `grug_abilities` gates `valid_target`, the swing handler and support
  (`support_refused`: a refusal costs nothing). PvP contact arms
  `mark_in_combat(player, grug_core.PVP_COMBAT_TIMEOUT)`. Logout death:
  credited at leave, applied at the next join (`grug_pvp:logout_death`);
  a shutdown sets no mark. NPC kills count through `_grug_pvp_kind` on the
  garrison prototypes and grug_mobs' eligible-kill hook. `page.lua` (sfinv
  page after Group; texts in the pure `view.lua`) and `hud.lua` (one status
  source) are P2's; the zone banner's territory line and colour ask
  `territory_at` (Round 32: the position's territory by the flag's own
  rule, never the flag) in `grug_map/location.lua`, the target frame
  `can_harm`. Fixtures
  `tools/r31_pvp` (flag core; `run.sh` the engine probe: PvE micro run,
  zone checks, tick cost), `tools/r31_p2`, `tools/r31_p1b`, `tools/r32_f1`
  (the territory line). Rules:
  [pvp.md](../design/pvp.md).

## XP and levels

- **XP/levels**: template VoxeLibre `mods/HUD/mcl_experience/init.lua` — XP
  as an int in player meta, `level_to_xp` curve, `register_on_add_xp`
  pipeline, HUD bar. Round 18: no death XP loss; cumulative XP caps at level 60,
  and real upward level changes fill living HP/mana with one gold burst.
  Round 28 ([progression.md](../design/progression.md)): `grug_xp.mob_xp(L)`
  is the kill-equivalent unit `M(L) = 25 + 5L`, `level_xp(L)` the XP from L
  to L + 1, `xp_for_level(L)` the cumulative start of L, and
  `quest_reward(level, weight)` turns a quest weight into XP; kill XP
  (`mob_xp × tier`) lives in `grug_mobs/levels.lua`. Positive grants feed
  `grug_core.feed_xp` unless the caller passes `quiet`. Since Round 36 the
  level-up banner's second line counts the talent points the jump earned
  through `grug_classes.talent_points_at(level)`, the one point rule (read
  at runtime: grug_classes loads after grug_xp).

## Professions

- **Professions**: `grug_jobs` owns the exact six primaries — Weaponsmith,
  Armorsmith, Tailor, Leatherworker, Woodcarver and Goldsmith — plus the
  secondaries Cooking and Alchemy (`alchemist`; Round 33), two primary slots,
  one fixed book slot per secondary, player-meta progression and the UI-only
  recipe books.
  Content mods first call `register_ingredient_tier(item, tier)`, then
  `register_recipe{profession, tier, station, inputs, output, hint}`; every
  gear recipe must contain a declared ingredient of its own tier. A recipe's
  `progress` flag (Round 33) says whether it awards profession progress: end
  products do; `material = true`, `progress = false` (stations,
  intermediates) and automatic finishes do not. For an
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
  `record_craft`, `award_progress` and `can_craft_recipe`; every craft path and
  station operation (enchants, profession upgrades) awards progress through
  `award_progress(player, recipe)`, which checks the recipe's flag;
  `register_on_award_progress(fn(player, recipe))` (Round 33) runs after each
  counted award (grug_achievements counts dishes and potions there, i.e. at
  their preparation; fixture `tools/r33_c2`: roster, book slots, progress
  flags of the shipped recipe corpus). `profession_level` returns 0 when
  unlearned and effective T1–T6 when learned. Grid output is vetoed before the
  engine craft. Authored workspaces have persistent per-player/per-station data;
  player-placed stations share inputs with individually qualified output views.
  Automatic furnace/dual/brewing processing is universal and grants no progress;
  the protected preparation step grants current-tier progress instead.
  One output may have one route per station when every route agrees on
  profession and tier; `recipe_for_output(output, station)` resolves the
  station-specific route. This is how a Cooking grid dish and its raw-assembly
  furnace path meet at the same edible item. A grid craft finds its recipe
  through an index built at registration (Round 30, `registry.lua`
  `recipe_for_craft`: station and shape, then trimmed size and cell mask or
  ingredient count); a new matcher rule must keep the index and the former
  linear scan equal (`tools/r30_p4` replays the shipped recipe corpus).
  Grid and selected enchant commits revalidate qualification and inputs before
  consuming anything and record progress once after settlement. Alchemists make
  mixtures in their inventory grid; Brewing Stands finish them universally.
  Basics declares each exact engine route as starter or with one main material;
  the complete runtime catalog is audited against `basics_routes.lua` at startup.
  Discovery changes visibility only. Bread, Cooked Meat and Cooked Fish are
  universal Basics roasting; protected Cooking dishes keep their book provenance.
  `docs/design/crafting_equipment_revision.md` governs current stations, named
  tiered enchantments (including trinkets), equipment separation and wear.
  Station icons appear below the recipe arrow, outside ingredient slots.
  `grug_jobs.open_trainer(player, profession, pos)` serves the six primaries,
  Cooking and Alchemy. The Character page's Professions tab (Round 28 ruling 23) is
  built by `grug_jobs/character_tab.lua`; `grug_inventory` owns the tab row
  and asks for the body, because `grug_jobs` depends on `grug_inventory`. Capital-only Riding uses `grug_mounts.open_trainer(player, entity)`
  with an authenticated Riding socket, never the generic profession hook.

## Crop registration

- **Crop registration**: `grug_nodes` registers complete `grug_farming:soil` and
  `soil_wet` definitions before synchronous mapgen compilation, and exports
  `crop_visual(key, stage, sounds)` and `bind_crop_soil_callbacks`. FARM binds
  its real callbacks once and owns the 17 crop families, timers and current-world
  activation. Mapgen has no FARM dependency; do not defer world authority.
  Tall crops keep state, timers and drops on the root; hidden helpers never own
  rewards. Multi-position growth/harvest preflights loaded, protected and exact
  matching nodes before mutation. Mature regrowers use right-click; annuals are
  replanted, while harvested Cane/Bamboo retain and reset the base.
  Since Round 30 soil without a growing crop checks its water once a minute
  (15 s under a growing crop; planting and regrowth re-arm 15 s), and the
  crop geometry LBM leaves a plant whose helpers already stand untouched.

## Skills catalogue

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

## Mount runtime

- **Mount runtime**: ownership is player meta; the summoned controller and its
  visible child are ephemeral. The child is hidden only from its local rider in
  first person. `grug_mounts.dismount` is the shared cleanup path for manual,
  damage, death, leave, shutdown and external-detach exits and clears the
  runtime-only untimed `mount` status. Mounted players cannot attack. Land
  controllers use nominal one-node step height; T1 is 6.4 nodes/s (+60%).
  Since Round 29 boats are the third mode, **water** (`grug_mounts.TIERS`
  5 and 6, `BOAT_TIERS`): the same owner-bound item, ownership meta and
  dismount path, a surface controller, a once-per-second water-contact
  check, landing within 2 nodes; using another tier's item replaces the
  active mount or boat. The Riding Trainer dialogue is one service format
  (`grug_mounts.SERVICES`); `shipwright.lua` serves the `shipwright` socket
  role of the capital stable. Prices: `grug_mounts.PRICES` (E4,
  `tools/r29_e4/income.py --check`). Fixture `tools/r29_b` (boats, and since
  Round 30 section H the riding-tier purchases at the shipped prices). The
  flight-border sweep reads the faction once and each column's zone id
  (`grug_zones.id_at`), never a copied zone record per sample (Round 30).

## R7 audit boundary

- **R7 audit boundary**: the 157-file R7 source-audit roster is frozen
  historical evidence and is not a current-source gate. Its audit script was
  retired in Round 22 and WP49, the planned replacement, is canceled
  (2026-09-29); never refresh or cite the old baseline-derived list as current
  certification.

## Trinkets

- **Trinkets**: `grug_trinkets` owns the six special consumers and rebuilds an
  event-driven per-character equipment cache through the equipment-change seam;
  hot mana/heal/hit/kill/potion paths read that cache and never rescan slots.
  The same trinket identity cannot occupy both slots. Last Light uses one
  shared 120-second cooldown and maximum shield lifetime.

## Combat and classes

- **Combat/classes**: damage = damage_groups × armor_groups (÷100) ×
  punch-interval factor. **Damage pipeline lives in `grug_core/combat.lua`**
  (WP4): `deal_ability_damage` (crit ×`CRIT_MULTIPLIER` = 2 since Round 33,
  also for melee and heals; applied via `object:punch` with
  full punch interval so armor/XP keep working; knockback requires an explicit
  `damage_groups.knockback` override), `heal_player`,
  central dodge roll (hp-change modifier), `in_combat` (mob engagement via
  `engage_mob`/`disengage_mob`, a timer via `mark_in_combat(player, seconds)`:
  5 s for PvP hits and untracked sources, 10 s for PvP contact; combat_stats
  §5). The PvP seam `grug_core.pvp_can_harm`/`pvp_hit_landed` is installed by
  `grug_pvp` (impact re-check, crosshair ray, landed-hit contact), threat stubs `add_threat`/`add_heal_threat` (WP6 fills
  them). Crit/dodge accessors are grug_core stubs overridden by
  grug_classes (`get_crit_chance_raw`: 5 % + 0.05 % per Dexterity point
  since Round 33; dodge 0.1 % per point). Attributes enter damage with their
  fraction (`Str/10`, floored once at the end); the damage-fit reference
  `grug_core.baseline_melee_total(level)` keeps it unfloored too (Round 34
  F2) and is public since Round 35: it is the base hit `B(L)` of the
  level-proof talents. **Talent values (Round 35, skill_trees.md §2.10):**
  `grug_classes.get_talent_bonus(player, key)` returns, for a key in
  `grug_classes.TALENT_LEVEL_SCALED_KEYS`, the stored percentage times
  `B(L)` (damage) or `grug_core.armor_k(L)` (armour) at the player's level
  (`talent_level_amount`, which the talent tooltip uses per rank), so every
  consumer adds the amount where it once added a flat value, before the one
  damage scalar; the talent cache holds only the percentage sums. Helpers of
  that round: `grug_abilities.clear_cooldown(player, id)` (Last Word resets
  Word of Ruin a step after the cast) and `grug_core.is_rooted(player)`
  (Opening's held target). **Support factor (Round 36):**
  `grug_classes.get_support_factor(player)` (`stats.lua`) is `1 + gear Int /
  10 / B(L)`, gear Int being the Intelligence above the class's own level
  growth; `kits.lua` `support_value` multiplies every pool-derived heal and
  absorb by it (spell power stays the flat damage term), and
  `spell_damage_value` and Smite return unrounded amounts that
  `deal_ability_damage` floors once after the level scalar (fixture
  `tools/r36_k`). Abilities = hotbar tools in `grug_abilities` (item `range` =
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
  baseline; `inventory_equipment.md` §2 (eligibility, per-class hand rules, the
  `_grug_hands` two-handed rule) and `combat_stats.md` §2. Its
  **equipment seam** lives in `grug_core/combat.lua`:
  `get_equipped_weapon`/`get_equipped_offhand`, and since Round 28
  `get_melee_weapon` — the item Strike and every melee skill swing: the
  Scout's Melee offhand, everyone else's Weapon slot
  (`grug_inventory.HAND_RULES`, `melee_list`, `hand_list` for an ability's
  `slot` of "weapon"/"offhand"/"melee") — (stub-override pattern like
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
  The combat ray passes dropped items and, since Round 36, any object whose
  observer set leaves the player out (a quest object, `grug_quests/use.lua`):
  nobody is blocked by what they cannot see. The same test,
  `grug_core.unseen_by(ref, player)`, filters the hand ray of contextual
  input (hand clicks and the crosshair's interact colour) and the skill
  item's right-click ray (`ability_on_secondary_use`), so a door behind
  another player's quest object still opens.
  Every server-side aiming ray (the combat ray, the hold ray, right-click
  interaction, the Target Frame) iterates `grug_core.aim_raycast` instead of
  `core.raycast`: it tests `rotate = true` selection boxes in Lua because the
  server's raycast misreads them since Luanti 5.12
  ([upstream workarounds](upstream-workarounds.md) §1).
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
  acting hand slot (the melee weapon, or the captured bow for a shot) once on a qualifying settled
  action. The accepted transaction stays
  exact attacker+ray-target and claim-once; the mobs_redo/PvP finish seam pays
  cost, resets charge, grants rage and applies post-effects only on its existing
  accepted/HP-loss conditions. Mighty Blow remains
  `floor(weapon*1.5)+melee bonus`; Hamstring remains a 50% slow.
  WP39's binary small gold crosshair ring is shown once while a selected
  swing is weapon-ready, hidden on a valid attempt, absent for non-swings, no
  smooth progress and no inventory writes; a weapon swap follows the new
  clock's readiness and lifecycle cleanup removes it. Target validity is a
  separate overlay (`grug_abilities/crosshair.lua`, `classes.md` §2b "Crosshair
  feedback"): it reads `grug_abilities.aimed_target` (the side-effect-free aim
  authority the hostile/friendly casts wrap) and `input.aims_at_interactive`,
  and owns the progress ring shared by the bow draw (`scout.lua`, hidden in
  `reset_draw_stack`) and eating (`input.lua`, hidden in `end_food_hold`):
  `set_ring(player, fraction, owner)` with owner `"bow"` or `"food"`; the
  first owner to show it keeps it until it hides it. The
  game's `crosshair.png`/`object_crosshair.png` are byte-identical on purpose;
  regenerate them with `tools/pt_fixes/lane_b/gen_crosshair_textures.py`.
  Since Round 30 the state overlay refreshes every 0.15 s (input and the
  ready ring stay on the 0.05 s pass), an unchanged skill ray that hit no
  object is reused for up to 0.25 s, and the Target Frame
  (`grug_mobs/target_frame.lua`) reads
  `grug_abilities.crosshair.recent_aim` before casting its own 20 m ray.
  Since Round 32 a held LMB is one state machine in `input.lua` (`step`):
  `s.mode` is `"gather"` or `"combat"` with its foe `s.foe` (the support
  ally of a fresh press in `s.ally`); a key-down on a valid hostile starts
  in combat, every other press in gather; a held gather switches only when
  `hostile_ahead` finds a target `fightable` accepts (combat's validity
  test, so `grug_pvp.can_harm` for players) while the selected skill
  attacks hostiles, and casts the extra combat ray only when the hand ray
  hits a non-walkable node, loot or an actor; `foe_gone` (dead, invalid,
  evading, or beyond `FLEE_REACH` × the reach) returns it to gather.
  `end_mode` clears mode, foe and ally on release, cancel, slot change,
  death and leave (a held slot change decides again, below). Fixture `tools/r32_f2`; rules `classes.md` §2b.
  Since Round 36 `fightable` is `grug_abilities.valid_target` itself, which
  refuses a mob evading home, so the crosshair, the hold, swings and casts
  share one predicate; `grug_abilities.evading_target` names the evader a
  fresh press answers with `grug_mobs.evade_notice` ("Evading", rate-limited
  per player, also from the do_punch cancel), the hand ray's object goes
  through `grug_core.combat_actor` (a mount's rider, as in the combat ray),
  and the crosshair shows no skill state while `input.allowed` refuses
  (mounted, stunned). Fixture `tools/r36_f`.
  Also since Round 36 (lane F2) a slot change with LMB held is no cancel:
  `step` settles the old item (`reset`), keeps a combat foe that is not
  `foe_gone` for the new skill's reach and records `s.settle`; once the new
  item has stayed `SETTLE_US` (0.2 s; a further switch restarts it) `s.down`
  is cleared, so the new item takes the key-down decision (digging never
  waits: `can_dig` does not read `s.settle`); `activate`'s `carried` flag
  keeps that decision quiet (`cast`'s `quiet`) and without a tap window
  (`s.pending`).
  A carried RMB press still cancels. Fixture and engine probe `tools/r36_f2`.
  It also ships permanent
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
  `noclip` exempt; lava is 20% and drowning 10% of maximum HP/s
  (`environment_damage.lua`, Round 24), and absorb does not cover fall,
  lava or drowning. `grug_core.status` is the runtime timed-effect registry and, since
  Round 26, the bottom-centre status icon row (at most 10 icons, 0.5 s pass;
  pictures and frame kinds in `grug_core/status_icons.lua`) that also feeds
  the Character page's Effects tab; the combat state is not a status but
  the icon `grug_core/combat_hud.lua` draws right of the health bar. Status definitions may carry only
  `hp_pool_percent`, `mana_pool_percent`, `crit_percent`, `armor` and
  `spell_damage_percent`; `grug_core.status_modifier_sum` adds active statuses,
  and the modifier-change callback drives the same HP/mana clamp and HUD/page
  refresh path as talents. `grug_food.TIERS` owns fixed instant HP, minimum
  level and the Hearty/Caster/Hunter dish data; raw foods, including Wild
  Cocoa, always regenerate 2% HP per 5 s. Food lasts 300 s. Eating during
  combat is refused before consumption; accepted food heals instantly, and its
  regeneration pauses during later combat while secondary modifiers persist. The
  latest food replaces the previous one. `grug_core.can_use_item_level` is the
  shared level gate (`_grug_req_level`, else `_grug_ilvl`) for every
  equipment slot (Round 33) and all consumables; `grug_quality` wraps it so
  a stack's own `grug_req_level` (drops, upgrades, the crown) wins. Potions
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
  `grug_traders`' persistent clock (`grug_traders.POTION_COOLDOWN` = 60 s in
  `potion.lua`, which also owns the vendor's Weak Healing Potion; every
  potion and draught); Healing and Mana Potions I–VI are fixed amounts
  (`grug_alchemy/recipes.lua`, item_tiers §5);
  elixirs replace status id `elixir`, stack with status id `food`, and never
  touch that clock.
  `grug_gathering`'s herb authorizer delegates to
  `grug_jobs.has(player, "alchemist")`; Cave Cap remains universal food.
  The former real-code Lua 5.1 regressions under `tools/wp39/` were retired in
  Round 22 (D22); git history keeps them.
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

## Mobs

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
    Kraken L70 (elite), the island dragons L70, the capital kings L65 and their royal
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
    sets plus orphan cleanup to that module's one central 1 Hz pass (since
    Round 30 spread over eight slots of each second; visibility callbacks run
    only for observed carriers or on an observer-set change). Carriers
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
  - **`core.add_entity` stores the staticdata of that moment**
    (`ServerEnvironment::addActiveObjectRaw`): fields written after the
    call reach the mapblock only at the entity's next deactivation. A block
    saved and unloaded in between keeps that first snapshot, and the
    deactivation then stores a second copy, so the entity comes back twice.
    Pass what identifies the entity in `add_entity`'s staticdata
    (`start_npcs.lua` `place`: `_grug_unplaced`, Round 30).
  - **Per-step mob code allocates nothing it can avoid (Round 30 P2):** read
    a mob's collision box from `self._grug_cbox` (written wherever the box is
    set; `grug_obstacle.mob_cbox` / `object_cbox`), never `get_properties()`
    in a step; privilege checks go through the cached `mobs.has_priv`. A*
    runs inside a per-step time budget (about 3 ms) with a negative path
    cache and the give-up rule of `combat_stats.md` ("Unreachable targets are
    given up"): `grug_obstacle.no_path_gate` / `note_search_result`,
    `grug_mobs.give_up_target` (`aggro.lua`). A new chase or patrol search
    asks that budget (`claim_path_budget` / `spare_path_budget`), reports its
    cost (`note_path_cost`) and result, as `patrol.lua` `path_nudge` does;
    never an unbudgeted `core.find_path`. Fixture `tools/r30_p2` (also the
    merged spawn ABMs and the eye height).
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
  - **`GRUG PATCH` sites in `mods/ENTITIES/mobs/api.lua`** (122 counted
    2026-10-04 after Round 34) — the inventory and rationale live in
    VENDOR.md; re-apply them on any mobs_redo update. Round 34 F1's four
    water sites (`grug_may_wade` in the support probe, `grug_bank_ahead` and
    `GRUG_CLIMB_RISE` in `falling()`) and S1b's two sound call-outs
    (`mob_sound` routes a `grug_sounds` event through `grug_sounds.play`;
    `on_punch` plays `grug_core.melee_hit_sound`) are the newest. The 41st to 43rd (mob pressure, 2026-09-16) are the
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

## Mob sub-types, loot and spawn regions

- **Mob sub-types, loot and spawn regions (Round 28):** all in `grug_mobs`,
  data under `data/` (JSON; a missing file means "no data", a broken one
  fails the load).
  - `subtypes.lua` registers each sub-type `grug_mobs:<role>` as a copy of
    its already registered base (loaded after every mob file), from
    `data/subtypes.json` and `tints.json`; loot items from `items.json`;
    drops by level band from `drops.json`. Quest-only drops go through
    `grug_mobs.register_participant_drop_hook` (`aggro.lua`), rolled per
    eligible participant.
  - `spawn_regions.lua` (`grug_mobs.spawn_regions`) reads
    `data/zones/<zone>.spawns.json`: a `recipe` (every shipped zone) or a
    `palette` (the old ABM path, kept for a zone without recipe). It builds
    every recipe zone's region map at server start (mods loaded) through the
    lazy `SR.map` and the pure
    `spawn_regions_core.lua`, which `tools/r28_regions` runs unchanged, so
    the review images are what spawns. Since Round 30 (P3)
    `spawn_regions_cache.lua` (pure, plain Lua 5.1) keeps only the compact
    form of each map (`SR.map`; `SR.full_map` builds the full one for tools)
    and `SR.start_maps` reads every current zone from
    `<world>/grug_region_maps.txt` and builds the rest. Its key is the
    world-layout key (`grug_mapgen.wp40.world_key`) plus a digest of the
    builder's files: **a new file the build reads must join that key**, or
    `tools/r30_p3` (input coverage) fails. API: `region_at`, `level_at`,
    `describe` (direction phrases for quest texts), `area_roles`,
    `leader_pos`; every spawned mob carries `_grug_area` for area kill
    credit. Its one throttled globalstep runs one ambient attempt per
    player per second in four player slices and, since Round 32 (perf
    review R3), the camp slots (`grug_mobs.region_camp_tick`, `camps.lua`)
    and leaders (`SR.leader_tick`) in `SR.SLOW_SLICES` (20) zone slices of
    0.25 s, so each zone is still served once per `SR.SLOW_PERIOD` (5 s)
    but no step weighs every camp against every player (fixture
    `tools/r28_s1`, section "Round 32 F4"). Rules: [spawn_regions.md](../design/spawn_regions.md),
    [biomes_mobs.md](../design/biomes_mobs.md) §4.2.
  - Since Round 36 a relevel recomposes a humanoid's skin and
    `grug_mobs.refresh_visual` puts the zone tint (the corrupted sub-types'
    ember) back on top through `grug_mobs.reapply_zone_variant`
    (`subtypes.lua`; fixture `tools/r36_q0`).
  - `env_damage.lua` (percent environmental damage, read by the
    `grug_env_damage` GRUG PATCH), `roam_avoid.lua` (idle aggressive mobs
    walk away from roads and towns), `separation.lua` (separation and melee
    knockback as position displacement).
  - Zone level bands live only in the mapgen source
    (`wp40/source/simple_map.lua`), served by `grug_zones.get`/`at`.
  - Tools after a recipe change: `tools/r28_regions/run.sh` (images and
    stats per seed, then `quest_targets.py`), `tools/r28_world/run.sh`
    (world view, border fit; `border_rule.py`), the catalogue checks
    `tools/r28_design/validate.py` and `tools/r28_names/build_review.py
    --check`.

## PvP garrisons and dragon arenas

- **PvP garrisons and dragon arenas (Round 31):** `grug_mobs/pvp_garrison.lua`
  (pure; built in `init.lua` before `guard.lua` from the mapgen catalogue
  `r31_pvp_catalog.lua` and `data/pvp_names.json`) answers per socket which
  NPC stands there (`G.slot`: entity, levels, tier, respawn, royal, leader,
  name, mixed, area), the quest area `"<zone>/<settlement key>"` and its
  roles (`G.area_roles`, read by `grug_quests` and `tools/r28_design`).
  Round 36: the war commander of the two camps `pvp_names.json`'s
  `commanders` names (`G.commander`, the role `commander` in `G.slot`); he
  has no blueprint socket, so `start_npcs.lua` appends the post
  `M.commander_socket` derives from the captain and the west yard post.
  `guard.lua` registers the camp captains and the commanders (the guard
  chassis, `grug_mobs.LEADER` factors from `levels.lua` in the definition),
  `bosses.lua` the Generals from `king_def` (the seat race from
  `catalog.SEAT_RACE`) and their bodyguards; `start_npcs.lua` serves a PvP
  POI as its own settlement kind and books the respawn slots (the General's
  group on the royal path). `dragon_arena.lua` holds the pure arena rules
  (radius from the mapgen profile, inside band, 250/350/500 per second,
  the reset test; since Round 34 the thin ice: `ice_step` marks every thin-ice
  node of the 3×3×3 cube around a sampled player's feet as one break event
  due `ICE_BREAK_DELAY` (1 s) later, keyed server-wide by node position, a
  pending node never reset or postponed; `ice_due` pops the events that are
  due; since Round 36 `push`, the velocity of the wing gust and the dive's
  slam, weakened by the player's live braking so that he stays within
  radius − 4; `boss_dragons.lua` turns the engine's punch knockback off for
  the slam's hit through a `core.calculate_knockback` wrapper);
  `boss_dragons.lua` applies them (one `ice_break` sound per event):
  `_grug_target_veto` (a hook in the `init.lua` acquisition veto, honoured by
  `grug_core`'s `valid_target`, `add_threat` and `taunt`), the once-a-second
  arena tick (threat prune, reset and flight home, hazards and the wrath
  through `set_hp`; `grug_core.bypasses_absorb` covers the wrath), the
  participants table per dragon. Fixtures `tools/r31_g`, `tools/r31_da2`,
  `tools/r36_g` (the wider hazards, the refreeze, the gust; `engine.sh` the
  hazard counts and a push on a stand-in).

## The rift

- **The rift (Round 36):** `grug_mobs/rift_core.lua` (pure: the site
  constant `SITE`, each candidate's crack waypoints and `crack_cells`, the
  respawn and particle numbers) and `rift.lua` (the void node, the one-time
  crack behind the storage key `rift_crack:<site>`, the particles, the rift
  boss and its once-a-second pass; `grug_mobs.rift_players` is the probe's
  seam for stand-in players). The boss settles through `bosses.lua`'s ledger
  (`grug_mobs.boss_settle`); a boss reward hook is `fn(self, boss_id, player,
  locked)`, `locked` for a kill inside the character's lockout (grug_quality
  rolls `BOSS_DROPS.locked`'s tier, the rift boss's elite row, else nothing).
  The void's player damage is the node group `grug_pool_damage` (a percent
  of the pool per second), applied in grug_core's central hp modifier through
  `grug_core.node_pool_damage` (`environment_damage.lua`), lava's pattern.
  The boss rises only for an eligible player near (`rift_core.FINALE_QUESTS`
  through `grug_quests.quest_held`, `state.lua`: "active", "completed" or
  nil from the cached state, cheap enough for a once-a-second pass; with
  grug_quests absent everyone is eligible).
  Fixtures `tools/r36_r` (with `numbers.py` and `engine.sh`), `tools/r33_c1`.

## Mob voices

- **Mob voices (Round 34 S1b):** `grug_mobs/voices.lua` holds `VOICES`, the
  families (humanoid, goblin, undead, mummy, skeleton, spirit, giant,
  elemental, canine, feline, boar, beast, grazer, bird, crow, critter,
  insect, slime, reptile, aquatic, dragon, kraken), each mapping
  `war_cry`/`damage`/`death`/`telegraph` to `grug_sounds` events.
  `grug_mobs.register_mob` calls `apply_voice`, which turns the definition's
  `_grug_voice` into the mobs_redo `sounds` table with only the events that
  have a spec (explicit `def.sounds` entries win); a definition without
  `_grug_voice` is a load error, `false` means no voice, and a sub-type
  copies its base's field. No family has a `random` call; felines have no
  `war_cry`. `telegraph.lua` plays the family's `telegraph` cue at a
  wind-up (only the humanoids have one); the dragons play `telegraph` from
  `boss_dragons.lua`. Fixture `tools/r34_s1b`.

## Dawn departure

- **Dawn departure (Round 35 E):** `grug_mobs/dawn.lua`
  (`grug_mobs.dawn_tick`, called from the shared `do_custom` wrapper right
  after `leash_tick`; a `false` return ends the step of a mob that left)
  removes a free region mob whose `_grug_spawn_clock` is `"night"` by day
  (`SR.clock_now`) with mobs_redo's smoke puff — no drops, XP or kill
  credit — unless it is in combat or a player is within
  `grug_mobs.DAWN_NEAR` (32) nodes; one field test per step, a check every
  `DAWN_INTERVAL` (1 s) per night mob. Camp members (their tag's unit is a
  camp) and every mob without the clock stay. Fixture and engine probe
  `tools/r35_e`.

## Mobs in water

- **Mobs in water (Round 34 F1):** the wading rule lives in the vendored
  probe (`grug_may_wade`, see the `GRUG PATCH` list); the way back to land is
  `grug_mobs/aggro.lua` `shore_check` in the 1 Hz leash tick (an idle
  floating mob in water swims toward its home). `floats` is a boolean in
  every definition. Fixture and engine probe `tools/r34_f1`.

## Enchantments

- **Enchantments**: every enchant stores its stat, channel and tier (1–7) in
  `grug_ench`; its value is `grug_items.enchant_value(stat, ilvl, tier)`
  (`docs/design/item_tiers.md` §1.1), derived on write by grug_quality's one
  store path (rolls, enchants, upgrades, the crown; nothing else writes an
  item level), never rolled. `grug_items.operation_plan` handles both station
  operation kinds (`grug_jobs.register_station_operation`: "enchant" and
  "upgrade"); a plan's `warning` names a replaced higher-tier enchant.
  `grug_items.crown_item(stack, player)` / `crown_preview(stack)` apply the
  Fallen Crown (the crown NPC owns the fee and the crown item). Gear drops
  (Round 33) are data in `grug_quality/init.lua`: `grug_items.DROP_CHANCES`
  (normal, elite and rare rows; zone leaders and war-camp captains roll the
  elite row), `BOSS_DROPS` (two items at 65/70), `BAG_DROPS` (0.1 % by mob
  level) and `grug_items.enchant_tier(ilvl)` (T7 above 60); the pool is
  `grug_gear.drop_pool` (every equippable item of the tier). Every stack
  with an item level carries `grug_req_level` = min(ilvl, 60), written by
  `write_item_level_meta` (a first-bracket item keeps level 1 up to its own
  item level). Fixtures `tools/r33_c1` (drop rates, bosses, bags, pool,
  requirement, sale value; `drop_income.py` the income per band),
  `tools/r33_c4` (values, tiers, upgrades, crown, families),
  `tools/r33_c5` (crit, attributes, vendors, repair, potions, Crownbinder,
  culture shelf); the value rule and its data in `tools/r33_ds`. Family
  eligibility and replacement rules belong to the gear design. Per-stack appearance keys (`inventory_image`, `inventory_overlay`,
  `wield_image`, `wield_overlay`, `wield_scale`, `color`, `range`, `description`)
  override item definitions. Build texture modifier strings in one helper:
  malformed modifiers produce client-side image errors that may not appear in
  server logs. Equipment changes must notify the shared equipment seam.
  Since Round 28 the inputs are data: `grug_professions/data/enchants.json`
  (own material + the channel's loot + a mined or gathered family input per
  tier) and, since Round 33, `upgrades.json`, checked by the pure
  `enchant_data.lua` (`grug_professions/data/README.md`); the family owners
  are `grug_professions.FAMILY_OWNERS`.

## Materials and tier-rock gating

- **Materials & tier-rock gating** (`items_crafting.md` §3.0,
  `world.md` §2 R6):
  - **Contract (WP43, Round 24):** Bronze, Iron, Steel, Silversteel,
    Embersteel and Abyssal Steel are the six universal tiers. Their tier rocks
    (`default:stone`, `grug_materials:t2_stone`..`t6_stone`) lie in the bands
    y ≥ -100, -101..-300, -301..-500, -501..-700, -701..-1000 and below; the
    rock's tier, not y, gates the pick. `grug_materials` is the sole owner of
    `TIERS`, `TIER_BY_KEY`, `tier_at(y)`, `stratum_node_for(y)`,
    `level_for_tier(tier)`, `required_pick_tier(node)` and `DECORATIVE_ROCKS`.
    Consumers never copy a band boundary, harvest tier, rock name or
    race-region assignment.
  - Registry consumers use `RESOURCES`, `RESOURCE_BY_KEY`,
    `RESOURCE_BY_NODE`, `PROCESSED_MATERIALS`,
    `SIGNATURE_WOODS`, `RACE_REGIONS` and `DENSITY`,
    with the `resource`, `resource_for_node`, `resource_node` and `processed`
    accessors. `CURRENT_SCATTER_RESOURCES` is only the pre-WP40 placement
    roster. WP40 replaces its geometry with race-region columns; it does not
    replace or duplicate this taxonomy.
  - The natural-node contract is explicit. Picks carry
    `grug_pick_tier = 1..6`; generated ground carries `grug_natural = 1`;
    resources additionally carry `grug_resource = 1..6` (gems carry
    `gem = true` in `RESOURCES`; Diamond is the only T6 resource). Mapgen owners must
    add every new generated ground node to `NATURAL_GROUND_NODES` and apply
    `natural_groups(groups)` when registering their own nodes. Never infer
    natural ground from `is_ground_content`: the engine defaults that field
    to true even for saplings and decorations. `NATURAL_GROUND_SET` is the
    audited lookup, not a second extension point.
  - The engine gates tiers: tier rock and resources carry node `level =
    tier - 1`, every Grudgelands pick carries `maxlevel = tier - 1` on
    `cracky` and `grug_resource`, so the client predicts a too-weak pick as
    unable to dig (no cracks). No other node may carry a `level`; the startup
    audit checks this and an engine dig matrix. Loose generated ground carries
    `grug_loose` (= its `crumbly` rating) and no level; shovels and axes carry
    `grug_shovel_tier`/`grug_axe_tier`. The engine's default dig sound is
    `default_dig_<group>` and these two groups have no such file, so a node
    of either without its own `dig` sound gets one after all mods load
    (`dig_sounds.lua`, Round 35: resources the stone dig, loose ground the
    crumbly one). The `core.node_dig` wrapper re-checks
    protection and the engine rule for natural nodes (`mining_decision`
    returns `protected`/`too_low_level`/`too_hard`/`allowed`; `too_low_level`
    applies on any node a pick/axe/shovel above the player's level would dig,
    `TOOL_LEVEL_REQUIREMENTS`), and settles `register_on_harvest` after a
    successful resource dig; its own harvest callback awards gathering XP
    through `grug_xp.award_gathering`. There is no
    depth limit per pick and no dig-without-drop path. A
    `register_on_punchnode` handler and a `register_on_protection_violation`
    handler (online players only) show one rate-limited hint in the shared
    screen flash line (`grug_core.flash(player, message, color)`, which
    `grug_abilities.flash` forwards to in error red): the protection reason
    (`grug_core.protection_hint`) for any wield, "Requires a T<N> pick" or the
    broken-pick line (never with a selected skill). Code that refuses an edit
    on protected ground calls `core.record_protection_violation` so the player
    sees the reason. `max_drop_level` is a separate ordinary drop
    property and may remain non-zero. `build_pick_capabilities` and the
    six `PICK_PROFILES` are the verification/consumer seam and the dig-time
    authority: dig speed stays as in the game, with no separate calibration
    (2026-09-29 WP audit D8; WP22 and WP29 are closed). Canonical storage blocks, Iron Sign/Ladder
    and the 20 canonical metal stair/slab nodes are storage/building
    derivatives, not natural ground and never harvest-gated.
  - Emberglass and Abyssal Steel are the canonical names. Fresh-server mode
    forbids earlier-version material aliases and migration readers. WP26 owns
    furnace/alloy/storage recipes in `mods/ITEMS/grug_smelting`; its
    `grug_smelting.RECIPES` surface is consumed by the trader anti-loop audit
    because engine craft inspection cannot see dual-furnace recipes. Recipe
    ownership and remaining economy work are tracked in BACKLOG.

## Traders and money

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
  - **The Bag of Coins** (`grug_money/coins.lua`, Round 34) is the only
    money item: `withdraw` goes through `take_with_inventory`, the deposit
    slot is a per-player detached list that destroys the bag in `on_put`;
    the amount is item meta (`bag_amount`), never a price class.
  - **One price module owns every payout** (`grug_traders/prices.lua`,
    pure rules in `price_rules.lua`; Round 29): loot and gathered goods by
    class × tier factor, processed goods by their cheapest recipe, sold
    goods by 5% ceiling buy-back capped by their recipe. It reads each
    item's tier from its own registration and resolves once when every mod
    has loaded; items carry **no** price field. `grug_traders.sell_price`
    returns the payout, and **0 means "not sellable"**. A new loot or
    gathered item gets a class there, not a number in its def.
  - **`grug_gear` is a GENERATED catalog, never a hand-written list**:
    the six bracket catalogs come out of the §3.1/§3.2 curves at load
    time. Public surface for anything that sells gear:
    `grug_gear.BRACKETS` (the Common slot table of `economy.md` §2),
    `bracket_for_level`, `get_price`, `catalog[b].fixed/.extras/.all`.
  - **Armor pipeline**: item `_grug_armor` values and every additive source
    aggregate as uncapped raw rating `A`. The deep Bulwark Unbroken capstone
    multiplies that aggregate by 1.65 and its emergency window then adds
    33 % of `K` at the Warrior's own level (Round 35; about 15 at level 50).
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
    and `armourer` reach the full T1 gear tab (Bowyer and Tanner filtered
    views). Since Round 33 the gear shelf is the T1 catalog only, with no
    rotation; the buy-back of unsold gear comes from its reference price
    (`prices.lua` `reference_prices`).
  - **Capital services on gate residents** (Round 33): the Crownbinder
    (`grug_traders:crownbinder`, `crown.lua`) and the Decor Merchant
    (`grug_traders:vendor_culture`, shelf `culture`) take over the gate
    resident of each capital's goldsmith and woodcarver service plot through
    `grug_core.assign_service_socket` (roles `crownbinder`,
    `culture_vendor`), as the Housing Steward does. The crown operation is
    one call, `grug_traders.crown_operation` → `grug_items.crown_item`
    (the window shows `grug_items.crown_preview`; a worn item the wearer
    could no longer wear afterwards is not offered); the payment is one
    `grug_money.take_with_inventory` with the fee `grug_traders.CROWN_FEE`
    (14 700c, checked by `income.py --check`), one Fallen Crown and the
    crowned item. The Decor Merchant's shelf is `grug_decor`'s harvested kit
    (`stock.lua` `culture`, four price bands); vendors sell blue ×3 and gold
    ×6 of the Common payout (`grug_traders.stack_sell_price`,
    `price_rules.QUALITY_FACTOR`).
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

## Quests

- **Quests (Round 14):** `grug_quests` owns a strict registry, 20-slot player-meta
  journal, kill/item/talk/use objectives and claim-once turn-in with main/owned-bag
  inventory preflight. The per-mob eligible damage/effective-heal participant
  set grants credit independently of party membership and gray-XP suppression.
  `npc_by_socket` keys actual settlement identity plus socket id, never terrain
  anchor ids. Marker children partition observers through the existing tag
  carrier's one-second 25/30 hysteresis pass; no independent player scan.
  Quest UI tracks up to ten selected quests (`grug_quests.MAX_TRACKED`, one objective line each) and stores its HUD preference.
  Since Round 28 the content is data: `data/zones/<zone>.quests.json` and
  `<zone>.front.quests.json`, read by `loader.lua`, checked by `validate.lua`
  (structure at load, roles/areas/levels/items once every mod loaded; every
  finding names file and quest); quest NPCs bound to sockets are in
  `npcs.lua`, new givers at free quest sockets come from the files. Area kill
  credit reads the mob's `_grug_area` tag (`<zone>/<kind or camp>` of the
  zone's spawn recipe, `grug_mobs/spawn_regions.lua`,
  [spawn_regions.md](../design/spawn_regions.md)); quest-only drops use
  `grug_mobs.register_participant_drop_hook`; weight rewards
  `grug_xp.quest_reward`. `labels.lua` words an objective for the dialogue,
  log, tracker and feed (item names only, never tooltip text) and carries
  each objective's target level range, computed once at load by
  `validate.lua` (Lane Q0); since Round 32 a kill target is named by its
  sub-type's zone display name (`display_by_zone`), the zone resolved once
  at load by `Q.target_zones` (a leader's zone, else the area's, else the
  quest's) and kept as the objective's `zones` (fixture `tools/r32_f2`;
  `tools/r28_design/validate.py` `E-label-name`, `E-item-source-drop`). It
  also fills the quest text placeholders (Round 29
  Q1): titles (`{name:...}` only) at load, texts on first display through
  `grug_mobs.spawn_regions.describe`, cached per quest (`Q.quest_text`);
  `registry.lua` computes the copper of a quest without `rewards.copper`
  (`quest_copper`). Since Round 36 `use.lua` owns the "use at a place"
  objective's runtime: the object kinds (`data/use_objects.json`, loaded
  before the quest files), one quest object per use point (`Q.use_key`:
  place, object, label) while a player who still needs it is within
  `LEADER_RANGE`, its observers set per player, the per-player pass once a
  second in five slots and the hold pass every 0.1 s only while a hold runs;
  `state.lua` keeps the needed points per raw state (`Q.use_needs`) and
  credits a finished hold (`Q.credit_use`); places resolve through
  `labels.lua` `Q.use_place` (a clash site `grug_mobs.spawn_regions
  .clash_site`, a recipe quest place `zone_place`/`place_spot`).
  `Q.register_on_turn_in(fn(player, id, def))` fires once per completed
  turn-in, after the state and rewards are stored (grug_achievements'
  `quest:` and `quest_tag:` counters); fixture `tools/r36_e`. Since Round 30 `state.lua` caches each player's decoded
  state keyed by the raw meta string: readers share that table and must
  never write into it, mutating paths take a copy (`editable`) and `save`
  re-caches. Marker consumers ask `Q.marker_states(player)` once for every
  giver (memoized until the raw state changes, `Q.markers_changed` resets it
  or the earliest running repeatable cooldown ends, Round 37): the
  minimap, the only consumer that registers
  `Q.register_on_markers_changed`; the Map tab, which compares the
  `marker_states` version in its signature; the NPC tags, read on the 1 Hz
  carrier pass. `Q.markers_changed` fires on a
  quest change, a held objective-item change (the tracker's `Q.journal_key`
  poll, `hud.lua`, five 0.1 s slots; counts capped at what one quest takes,
  Round 31; without an active item objective the poll reads no inventory,
  Round 37) and a level change (fixtures `tools/r30_p1`, `tools/r31_c`,
  `tools/r37_po`).
  Unknown quest fields stop the load (`E-unknown-key`, Round 30). Round 31:
  quest NPCs get their faction at load and serve only it; a kill objective's
  area may be a PvP garrison (`pvp_garrison.area_roles`, guard and captain
  roles, since Round 36 the war commander where a camp has one, the giver of
  the other faction: `E-garrison-faction`); kill
  credit needs nothing new (the `_grug_area` tag). Placeholders may name a
  PvP POI by its settlement key. The design tools mirror it
  (`tools/r28_design`: `r28common.pvp_pois` reads the tiers from
  `G.slot`); fixture `tools/r31_q`. The
  catalog requires only V1 overworld content; the Nether is reserved for the
  first expansion. Quest item labels use concise names rather
  than stat/durability lines; worn matching stacks remain valid turn-ins.

## Parties

- **Parties (Round 14):** `grug_parties` persists groups of 2–10 same-faction
  members and their leader in mod storage. Offline membership/leadership lasts
  indefinitely. Invitations are ephemeral inviter-bound records; a second
  member creates the group, one remaining member dissolves it. No party XP,
  loot or quest-credit rules. UI actions resolve rendered stable identities,
  then core APIs revalidate current authority. HUD HP writes are compare-first.
  The saved color preference defaults to By class; an explicit All green choice
  persists. Since Round 32 (perf review R2) `hud.lua` polls each player every
  0.5 s in one of five 0.1 s slots (`slot_of`, assigned at join), skips a
  player without a party through `grug_parties.in_party` (membership only,
  no view built) and recomputes the row layout only on a window change
  (fixture `tools/r32_f4`). Current geometry and offline presentation:
  [parties.md](../design/parties.md).

## Housing

- **Housing (Round 25, Round 26 drafts):** `mods/PLAYER/grug_housing` implements
  [housing.md](../design/housing.md). One global `grug_housing`; each file has
  one owner lane so the lanes work in parallel:
  - `registry.lua` + `api.lua` (Lane A): the pure claim model and the
    interface contract — registry in mod storage (format v2) plus a claim grid
    index, placement validation, the protection check with permissions, fuel
    as `paid_until`, the soulbound `grug_housing.STONE_ITEM`
    (`grug_housing:claim_stone`) and the draft node
    `grug_housing.DRAFT_STONE` (`grug_housing:claim_stone_draft`), drafts
    (`DRAFT_SECONDS = 300`), activation (`ACTIVATION_LUMPS = 5`, charcoal
    first), the pick-up lock (`PICKUP_LOCK_SECONDS = 43200`), destruction
    times, the arrival cube and no renewal in active claims.
    Contract: `claim_at(pos)` (claim `{id, owner, center, placed_at,
    activated_at, paid_until}` or nil; `activated_at` 0 is a draft),
    `is_active`, `is_draft`, `draft_remaining`, `pickup_wait`,
    `remaining_seconds`, `permission(claim, name)` →
    `"owner"`/`"everything"`/`"interact"`/nil, `player_claim(name)` → claim
    plus state `never`/`carried`/`placed`/`destroyed`/`removed`/`needs_stone`,
    `issue_stone`, `activate`, `add_fuel`, `pick_up`, `set_permission`,
    `arrival_pos`, `register_on_claim_changed(fn)` with events `placed`,
    `activated`, `fuel`, `permission`, `picked_up`, `destroyed`, `removed`,
    `draft_expired`, `expired`. Constants `RADIUS = 50`, `MIN_Y = −100`.
  - `stone.lua`, `stone_form.lua`, `protection.lua`, `soulbound.lua`: the
    stone and draft nodes with draft and fuel expiry, the stone forms, the
    `is_protected` wrapper with the arrival cube, the soulbound items.
  - `admin.lua` (Round 26): `/claim_remove <player> | here | orphans`
    (`server` privilege).
  - `interaction.lua` (Lane B): the generic right-click and node-inventory
    guard installed at `register_on_mods_loaded`, and the "Home of <owner> –
    protected" reason for `grug_core.protection_hint`.
  - `interface.lua`, `manager.lua` (Lane C): the stone formspec (set as
    `grug_housing.open_stone_interface`), the Housing Steward (internal socket
    role id `housing_manager`) and the character-page status.
  - Home-stone travel (Lane D) lives in `grug_home`, which reads the claim
    through the contract above.

## Travel

- **Travel (Round 29, WP17):** `grug_home/travel.lua` owns one travel path
  (dismount, emerge, deferred re-validation, safe arrival) used by home
  return, respawn and waystone travel (`grug_home.travel(player, trip)`).
  `waypoints.lua` builds the registry from the mapgen's `travel_waypoint`
  sockets (six capitals, six start pads and, since Round 31, the two PvP
  fortresses' sockets, registered after the twelve home locations; seven
  stones per faction), discovers a stone by proximity
  (once a second) or right-click, keeps the per-character list in player
  meta (`grug_home.known_waypoints`) and opens the travel form
  (`grug_home.use_waystone`); the refusals are pure rules in
  `waypoints_core.lua`. The node `grug_mapgen:waystone` is registered in
  `grug_mapgen/world_nodes.lua` before the settlement content resolves.
  Fixture `tools/r29_w/portable_test.lua`, engine probe `tools/r29_w/probe.sh`.
  Rules: [world.md](../design/world.md) §6,
  [home_travel.md](../design/home_travel.md).

  Fuel arithmetic is fixed in housing.md §4 (26 160 s per lump; displayed
  stack `ceil`, pick-up return `floor`). Road and POI protection (Lane E)
  lives in the zone authority and `grug_core`, not in `grug_housing`.

## Atlas

- **Atlas**: `grug_map` owns one whole-world cartographic atlas with 1x/2x/4x/8x
  zoom, native scrollbars and an independent marker layer. Formspec v4 wraps
  the shared legacy inventory window; only Map content switches to real
  coordinates. Keep center-preserving zoom, fixed-size markers, clipping and
  hit bounds in the same transform. A new tab visit resets zoom/scroll; live
  updates preserve them. Stable byte-encoded IDs own marker identity. Only open
  Map sessions refresh, at most every 2 s since Round 30 (`page.lua`): a cheap
  signature (zoom, selection, location, minimap switch, arrows on a 0.02-unit
  grid, the quest markers' version, the home, the waystones) is compared and
  the form is built and sent only when it changed; clicks rebuild at once.
  Anything a marker draws must be in that signature, or it goes stale.
  Since Round 32 (perf review R1) the poll runs every 0.1 s and reads at
  most `CHECKS_PER_PASS` (8) signatures and builds at most
  `BUILDS_PER_PASS` (2) forms per pass, the longest-waiting viewers first,
  so open tabs keep their own phase and never rebuild together (beyond
  about 40 viewers whose maps change at once the 2 s interval stretches;
  fixture `tools/r32_f4`).
  Scrolling defers rebuilds until a 0.5 s quiet interval. Closing resets to
  Character; leave/death clean up. Return home lives on the Character page
  since Round 30 (`grug_inventory/pages.lua`, its 1 s pass re-sends that page
  only while the button text changes).
  Since Round 27 `base.lua` renders the base per `grug_map_quality` and sends
  it as 512 px tiles; `minimap.lua` (HUD state, marker slots, change-only
  `hud_change` per whole screen pixel; every server step only a cheap test,
  and the map, markers or party arrows placed again only when what they
  show changed, Round 37) and the pure
  `minimap_view.lua` (window, snap grid and per-cell disc texture, the
  seam-free scale and map corner under the centred arrow, bezel frame,
  placement, rim arrows) draw the gliding minimap in
  `grug_core.hud_layout.minimap_box`. Keep the texture and position change
  in the same step and the scale a whole multiple of 1/grid, or cell swaps
  jump. Round 32 halved the window (`V.WINDOW_NODES` 440) and the cell grid
  (`V.GRID` 2 base pixels at normal, 8 at high) so the bezel still covers
  the overhang (geometry in `tools/r27_minimap`); `tools/r32_f1/engine.sh`
  measures the traffic and the location sample on a player stand-in. Since Round 30 the window size, the frame-only elements and the
  location line are handled every 0.5 s or on a window change, and the
  static markers are re-asked on `grug_quests.register_on_markers_changed`
  and, when their key (quest version, home, waystones, faction) changed, at
  a 5 s check. The minimap asks only the quest, service, home and (since Round 29)
  waypoint marker providers (`atlas.collect_markers(player, only)`); the
  `waypoint` provider shows the player's discovered waystones on both maps.
  Fixture:
  `tools/r27_minimap/portable_test.lua`; traffic comparison:
  `tools/r27_minimap/bench_glide.lua`.
  Zone and town names (Round 28 M1): `location.lua` samples each player's
  location every second, writes the line under the minimap and the entry
  banner and places one zone marker per zone at startup (since Round 30 a
  later start reads the sampled zone grid from `<world>/grug_map_zone_grid.txt`,
  keyed like the region maps); the pure
  `location_view.lua` holds the rules (fixture `tools/r28_m1`). Since
  Round 32 each sample also takes the territory status
  (`grug_pvp.territory_at`, the PvP flag's own rule, never the flag): it
  colours the minimap line and the banner, the banner's second line
  ("Friendly Territory", …) replaces the PvP subtitle, and a status change
  shows the banner like a zone change (fixture `tools/r32_f1`). Since
  Round 34 the sample also records whether the player stands in a start
  town or capital (`location.in_town(name)`, by x/z only), which
  `grug_ambience` reads for the quieter bed; since Round 35 also the capital
  (`location.capital_of(name)`, the settlement key of a town row whose anchor
  slot is `capital`, kept while the city is within `L.CAPITAL_MARGIN` nodes:
  `location_view.lua` `capital_at`, up to eight footprint queries per sample
  only while leaving), which decides where music plays.
  Round 31: NPC markers carry their NPC's faction and the service and
  quest-giver lists are split per viewer faction once at load (the kings and
  dragons stay for everyone); `settlement_icons.lua` (pure, `HIDDEN`) decides
  which settlement icons a viewer faction sees from the anchor slot in the
  settlement registry, and the Map tab builds one list per faction; since
  Round 32 it also names the hostile camps (`HOSTILE`: slots `bandit_N`
  and `mirefolk`), which draw a red "X" instead of the "!". The
  Map tab's signature includes the faction, and the minimap re-asks its
  static markers on `register_on_faction_chosen`. Fixtures `tools/r31_n`,
  `tools/r31_m`.
  Current marker/travel/minimap rules: [world_map.md](../design/world_map.md).

## Preparation

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
  request. Waiting may be dismissed without releasing safety gates; nothing
  reopens it (a failure updates the hint and the inventory formspec, which
  keeps the retry form). Both creation and reconnect use
  the shared waiting/stasis gate. Native tests
  use isolated tiny bounds; never run production full generation as a test.

## Fishing

- **Fishing (Round 14):** transient bobber, manual reel in a 1.5-second bite
  window, missed bites rearm; only successful catches wear the returned rod.
  `grug_abilities.notify` shares the neutral latest-message HUD token, no catch
  chat spam. Death, leave, shutdown, invalid water/rod and distance clean up.

## Mapgen and biomes

- **Mapgen/biomes.** The **WP40 R7 pipeline is the only mapgen owner** since
  the production cutover: `mods/MAPGEN/grug_mapgen/init.lua` registers the protected POI display
  palette, then loads `wp40/r7_loader.lua`, whose header says it plainly — "Legacy
  biome/ore/decoration/ocean/structure loaders are deliberately absent".
  `grug_mapgen/biomes.lua`, `ores.lua`, `decorations.lua`, `geometry.lua`,
  `ocean_mask.lua`, `ocean_mask_mapgen.lua` and `structures.lua` **no longer
  exist**, and neither do `register_mirrored`, `column_cap`, `clean_shell`,
  `_grug_spawn_zones` or the `grug_core.*camp_platform*` family. Do not write
  code or a brief against them; `docs/design/world_zones.md` §§8–14 (with
  §§7, 9 and 14 describing the Round 22 target, not yet the code) and
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
  `wp40/r7_native.lua` (the tier rocks `grug_materials:t2_stone` … `t6_stone` under
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
  **Near-water materials (Round 22 D27):** the R8-MAP-A coast runs and
  profiles are retired. `height.lua` derives `coast_material_at` (sand,
  gravel, stone or nil) from the final terrain and exposes the same rule as
  `bank_material_at(x, z, water_y, distance)` for Phase 5 banks.
  `r6_content.lua` maps it to surface rows and is the only source of dry
  near-water sand; ordinary wet-bed sand remains unchanged. The one exception
  is the four dragon-island landing beaches (Round 30, `boats.md` §7.1):
  `height.lua` grades them (`landing_graded_at` decides which columns, also
  for the sand override) and `road_writer.lua` builds the pier from the same
  shore point (fixture `tools/r30_l/portable_test.lua`, engine probe
  `tools/r30_l/engine.sh`).
  **Round 31 mapgen:** the PvP POIs are anchors 101–118 of
  `source/simple_map.lua` (fitting profiles `pvp_fortress`, `pvp_camp_low`,
  `pvp_camp_high`); `r31_pvp_catalog.lua` names them as rules (zone, slot,
  kind, faction, band; `camp_levels`, `camp_race` through the blueprint
  options' `raw_sha256` seam, the same in main and emerge, `SEAT_RACE`),
  `r7_settlement.lua` binds every row to its anchor (all or none) and the
  gate turn, and `r31_pvp_poi_blueprint.lua` is the pure cell builder
  (sockets as landmarks; `landmarks.race`/`faction` name what the
  settlement registers as). `road_layout.lua` routes a fortress's gate trail
  (`GATE_STRETCH`) and every road round the PvP POIs' reserves; the
  fortress spots lie clear of the middle road's course, which keeps it,
  while other secondary roads and trails may change (0–6 per seed). `world_protection.lua` grows a PvP
  slot's box by `PVP_MARGIN` (10), kinds `fortress` and `war_camp`. The
  dragon arenas: the `dragon` profile carries `arena_radius` 40 and
  `bowl_core_width` 32; `height.lua` grades the round floor;
  `arena_layout.lua` (pure, shared with `grug_mobs`) and `arena_writer.lua`
  (the last pass of the R7 successor settle) place the hazards, registered
  in `world_nodes.lua`. Contested depth is one constant,
  `CONTESTED_DEPTH_Y = −501` in `zones.lua` (PvP and territory). Fixtures
  `tools/r31_s`, `tools/r31_m` (incl. `spacing_check.lua` over six seeds,
  `engine.sh`), `tools/r31_da2`, `tools/r24_protection_depth`.
  **Round 36 mapgen (decor pass):** `wp13/decor_kit.lua` (pure) owns the
  pieces (`M.piece` in the race's palette), the whole-or-error placement of
  an authored row (`M.place`: open ground only, never a path, built cell,
  socket or the cell before it, a door's approach, the central actor
  clearance or before a window) and the house touches (`M.dress_house`,
  `M.houses_from`, `decor_kit.dress_rooms` in the start-town and capital
  plot builders). The Round 20 catalogue's `props` rows and the Round 14
  builder's `DECOR` table are kit pieces; the four rift candidates keep
  their four `props` positions (`rift_core.lua` reads them) and carry the
  rest as `decor`. Fixture `tools/r36_w` (every composition's bounds,
  airspace and sockets against `baseline.tsv`, windows, headroom, ways,
  benches); `tools/r36_w2` (which way every bench of every composition
  looks: a seat looks away from its stair's raised half, along facedir
  param2 + 2, never at a wall it could have its back to; `engine.sh`
  measures the raised half of Highcourt's seats in the engine); renders
  `tools/r36_w/render.py`, the whole roster `tools/r36_p`.
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
  a new surface row. Since Round 30 (P2) a surface row no zone keeps
  registers no ABM at all (`spawn_policy.lua` `spawn_row_kept`; the spawn
  regions own every zone's surface), and every remaining row goes through
  `mobs.register_spawn_abm` into one of three merged ABMs
  (`grug_mobs/spawn_abms.lua`: underground, water, surface). A merged ABM
  picks at most one row per triggered node with the probability that keeps
  that row's chance × interval rate, then runs the row's own unchanged
  `spawn_action`; a new row needs nothing beyond `mobs:spawn`. The Round 24
  per-point palette budget is gone; the zone budget of `grug_mobs/density.lua`
  is what the region spawner shares out.
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
  pass and `grug_zones` API are §13; acceptance is §14 (Round 22 minimal
  policy).
  Race region, territory and PvP rule are independent fields. Every ordinary
  level-31–60 land zone is contested and editable by both factions. Roads
  (corridor segments) and POI, village and camp building cores (boxes) are
  world-protected in the 128-node candidate grid (`world.md` §2 R1b, Round
  25); bounded functional anchors keep their hard protection; the remaining camp shells, tents, fences and battlefield
  dressing are mutable.
  Material design owns the complete `race_region` mapping of
  signature wood (gems are depth-tiered, not
  regional); map code stores only the
  region identity and placement data needed to consume that mapping. Each
  endpoint apex camp has no renewable sockets (renewable ores are removed,
  2026-09-29); its small functional anchor and building-core box are
  protected, while the rest of the camp shell remains mutable.
- **Mapgen boundaries that tests must cross** (moved from AGENTS.md,
  2026-10-05): a change to the R7 content projection or the planner column
  tuple is tested through the real consumers, `r7_manifest.new` and the
  planner's `plan_slice` (`wp40/r7_manifest.lua`, `wp40/planner.lua`); a
  self-built receipt passed to `validate`, or a fixture of the source tuple
  alone, does not prove them. Resource roots: `docs/design/world_zones.md`
  §11 (demand-driven sampling, adopted by the user on 2026-09-13) is the
  root-selection rule of both the VM writer and the resource census; the
  per-host root SHA ranking in the frozen R6 contract and artifacts is
  historical evidence, not an output oracle, and is not restored.

## World atlas rules

- **World atlas**: `docs/design/world_map.md` governs the cartographic Map tab,
  with no fog of war and independent future-interactive markers. It needs no
  generated-terrain bitmap and never unlocks waypoint travel.

## Sound

- **Sound (Round 34; rules [sound.md](../design/sound.md)):**
  - **`grug_sounds`** (`mods/CORE/grug_sounds/init.lua`) is the one play
    path for effects: `grug_sounds.play(event, target)` with a player, an
    object or a position; `EVENTS` maps an event to its spec (name, gain,
    pitch, distance, `personal`, `interval`) and an event without a spec is
    a silent no-op (the approval gate: no spec until the user picked a
    file). The rate limit is checked before anything is allocated (per
    event and target: a player name, an ObjectRef with weak keys, or
    `"pos"`). `HOOKS` lists every event a call site may name; a new call
    site adds its event there and its mod depends on `grug_sounds`.
    `item_sound(event)` gives an item definition's sound table (the swing
    skills' `punch_use_air`). `CLICK_STYLE` extends the formspec prepend on
    join (after `default`'s) and is pasted into the two `no_prepend[]`
    formspecs. Call sites by kind: crafts through `grug_jobs.award_progress`
    (`CRAFT_SOUNDS` by operation or profession; `automatic_take_sound` for a
    furnace or brewing-stand take), abilities through
    `grug_abilities.CAST_SOUNDS` in `try_cast` (every registered ability
    must be listed: a cue, `"weapon"`, `"projectile"` or `"silent"`),
    projectiles through `sound_launch`/`sound_hit` on
    `grug_projectiles.register`, melee hits through
    `grug_core.melee_hit_sound(player)` (by `_grug_weapon_family`), voices
    through `voices.lua`, gear breaking through `grug_repair/runtime.lua`
    `announce_break` (Round 35: in the gear, tool and hoe wear paths, once
    when a stack wears into broken; the broken look is
    `grug_gear.BROKEN_MODIFIER` in `broken_image`). Fixtures
    `tools/r34_s1a`, `tools/r34_s1b`, `tools/r35_f` (they check call sites,
    specs, files and the approval lists); fixtures that load a hooked file
    get a silent stub.
  - **`grug_ambience`** (`mods/CORE/grug_ambience`): `rules.lua` is pure
    (bed choice and hysteresis, the either-music-or-bed rule, calls, the
    capital music scheduler, the emitter choice, settings words; the fixtures
    load the real file), `data.lua` is data (bed, loop and call names, gains,
    one track rotation per capital, track lengths, timings),
    `init.lua` the runtime: an eight-slot pass of 0.25 s per player
    (`states[name].slot`, assigned on join), one `get_node_raw` probe for
    under water (33 reads while a sea or stream bed exists), one
    `find_nodes_in_area` above ground for the forge, fire and flowing-water
    loops (node names from `D.emitter_nodes` plus every flowing liquid whose
    source is default or river water, filled on `register_on_mods_loaded`).
    Only names with a shipped file play (`available` from the `sounds/`
    listing, the capital rotations filtered by `music/`), so data may name a file that does
    not ship. Music files live in `music/` (never `sounds/`) and are pushed
    per player with `core.dynamic_add_media` (`to_player`, not ephemeral,
    `client_cache`), playing in the callback through `music_delivered`; music
    plays only in a capital (`grug_map.location.capital_of`) and ends with a
    fade on leaving. Settings are player meta
    (`grug_ambience:music_off`, `…_volume`, `ambience_off`, `…_volume`);
    `grug_ambience.set/get` is the one entry for the Help page's Sound
    sub-page (`settings_formspec`, `handle_settings_fields`, called from
    `grug_inventory/help.lua`) and `/music`, `/ambience`. A personal
    positional sound ignores `max_hear_distance`, so the emitter choice
    drops far nodes itself. `grug_ambience.stats` holds comparison figures
    for the engine probes `tools/r34_s2/engine.sh` and `tools/r35_m/engine.sh`;
    fixtures `tools/r34_s2` (beds, calls, loops, files) and `tools/r35_m`
    (capital music, either music or the bed, settings).

## UI and formspecs

- **UI**: formspecs (`core.show_formspec` +
  `register_on_player_receive_fields`), set `formspec_version` +
  coordinate mode deliberately. Map retains the shared legacy outer window and
  uses real coordinates only inside its content. 3D preview: `model[]` element.
  Skill tree = formspec with an `image_button` grid.
  Gains (XP, loot, quest progress, catches), combat notices and personal
  notices (item-use refusals, mount notices, talent points) go to the message
  feed above the bars, never to chat: `grug_core.feed(player, kind, text, key)`,
  `feed_xp`, `feed_item` (`grug_core/feed.lua`, Round 28 ruling 20). Since
  Round 32 the kind `combat` (grey) carries "You dodge!" and "Dismount
  before attacking.", and each personal notice group keeps one keyed line a
  repeat refreshes (`potion`, `food`, `equip:<reason>`, `class_change:*`,
  `starter:<slot>`, `weapon_hint`, `mount`, `talents`, `boss_loot`); a new
  personal notice goes there too. Chat keeps deaths, rare sightings, boss
  and dragon warnings and the one-time no-weapon hint
  ([inventory_equipment.md](../design/inventory_equipment.md) "Message feed").

## Player model and skins

- **Player model/skins**: `player:set_properties{visual="mesh", mesh=...,
  textures={...}}`; texture layering (skin/armor/wielditem) following
  LotT `lottarmor/multiskin.lua`.

## Looks and enchant colours

- **Looks and enchant colours (Round 31):** `grug_visuals/looks.lua` (pure)
  holds the option tables per race, `normalize_look`, `roll_look`,
  `look_from_seed`, `npc_look` and `look_texture` (layer order, the helmet
  face window `HELMET_WINDOW`); the art comes from
  `tools/wp13/gen_character_visuals.py`. `apply.lua` stores a player's look
  once in meta `grug_visuals:look` (`set_look` refuses a second write) and
  builds `player_spec`; `compose.lua` puts every armour piece in its own
  parentheses and keys its cache on every normalized input. NPCs keep
  `_grug_look_seed` in their staticdata; `npc_race(entity, faction, opts)`
  gives the settlement's race, or with `{mixed = true}` /
  `_grug_mixed_race` a race of the faction (fortress garrisons).
  `creation.lua` is the look panel of the creation window
  (`roll`, `formspec`, `act`, `store`), registered with
  `grug_classes.register_look_panel`.
  Enchant colours: `grug_gear/enchant_colors.lua` (`ENCHANT_COLORS`,
  `ENCHANT_OPACITY` 128, `enchant_image`, `enchant_layers`,
  `strip_enchant`; masks `<texture>_ench.png` from
  `tools/r31_b/gen_enchant_masks.py`, `--check` rebuilds and compares);
  `grug_items.regenerate_description` (`grug_quality/init.lua`) writes the
  stack's `inventory_image`
  (removed for a plain stack), which the wield entity and dropped items
  use; `grug_visuals/enchant.lua` turns worn affixes into compose's
  `armor_layers`; NPC specs may carry `weapon_colors` (kings, Generals).
  Fixtures `tools/r31_a` (incl. the equal hitbox), `tools/r31_b`; rules
  [character_visuals.md](../design/character_visuals.md).

## Cloaks and achievements

- **Cloaks and achievements (Round 33):** players wear
  `grug_visuals/models/grug_visuals_character.b3d`, `character.b3d` with a
  cloak box on a keyed `Cloak` bone and its own mesh buffer appended
  (`tools/r33_c3/gen_cloak_model.py`, `--check` rebuilds and compares and the
  build proves the legs never cross the cloak); NPCs keep `character.b3d`.
  The player texture list is `{skin, cloak}`: `grug_visuals.apply` writes it
  with the cloak from the one `register_cloak_source(fn)` (no cloak:
  builtin `blank.png`), the cloak part of the redraw key. `mods/PLAYER/
  grug_achievements` owns the rest: `core.lua` (pure: counters, tiers,
  unlocked cloaks and the selected cloak in player meta, i.e. per
  character), `catalog.lua` (data: 20 achievements, tier N of `<id>`
  unlocks cloak `<id>_N` (the three of Round 36 a cloak of its own name),
  an optional `faction` hides and withholds a row from the other faction
  (the faction from `grug_core.get_player_faction`), defaults `none` and
  `plain_grey`), `creatures.lua`
  (pure: wild animals, zombies, families, named leaders by role, rares by
  registry id; a load audit logs any unclassified mob) and `init.lua` (the
  hooks, the Achievements tab body and the cloak dropdown that
  `grug_inventory/pages.lua` reads at build time). Counters come from
  grug_mobs' eligible-kill hook (cached per entity name),
  `grug_mobs.register_on_boss_kill(fn(player, boss_id))` (every player the
  boss ledger credits, independent of the loot lockout; `bosses.lua`
  `settle_boss`), `grug_pvp.register_on_stat`,
  `grug_jobs.register_on_award_progress`, `register_on_dieplayer` and, since
  Round 36, `grug_quests.register_on_turn_in` (an optional dependency:
  `quest:<id>`, `quest_tag:<tag>`); each is O(1) per event. Cloak textures are 32×32 (outer face left, lining
  right). Fixture `tools/r33_c3`; rules
  [character_visuals.md](../design/character_visuals.md) §5b.

