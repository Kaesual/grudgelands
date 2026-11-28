# Combat, classes and characters

Part of the [module implementation guide](../module-guide.md), which indexes every
area. Character creation, factions, PvP, XP, the skills catalogue and the combat pipeline with the class kits. Implementation seams and engine pitfalls only; the
[design docs](../../design/README.md) own the game rules. Source paths in code
spans are repository-relative.

Sections: [Factions and character creation](#factions-and-character-creation), [PvP](#pvp), [XP and levels](#xp-and-levels), [Skills catalogue](#skills-catalogue), [Combat and classes](#combat-and-classes).

## Factions and character creation

- **Factions**: a character's faction is a player-meta id
  (`grug_factions:faction`) validated against `grug_core.factions`; there is
  no faction privilege and no ally matrix. The creation flow (Round 35):
  `grug_classes/selection.lua` owns one window
  (`grug_classes:create`: race, whose faction follows, class and the look
  panel grug_visuals registers; the races are listed under their two
  faction headings) and the waiting screen (`grug_classes:loading`).
  The choices are a session-only draft (`session.draft`, checked again at
  Create); "Create character" calls `set_faction`, `set_race`, the panel's
  `store` and `set_class` at once and sets `grug_classes:arriving`, which
  keeps the character in stasis until the arrival teleport clears it. A
  session whose wait ends in a teleport (arrival or map-reset relocation)
  starts at the waiting point (0, 31000, 0)
  ([world preparation](../../design/world_preparation.md#the-waiting-point);
  fixture `tools/r46_wt`). Esc
  closes a form for good (Round 24 ruling 32); the current window is always
  the player's inventory formspec, while sfinv is suspended through the
  vendored `sfinv.inventory_suspended` hook (VENDOR.md), and "" submissions
  route to the same handlers; a HUD hint at
  `hud_layout.anchors.creation_hint` shows while no dialog is open; release
  re-runs sfinv for the player. Fixture and engine probe: `tools/r35_c`.
  `grug_classes.register_on_arrival(func)` runs once per character, after
  the arrival teleport and the release; `grug_inventory/welcome.lua` uses it
  for the welcome window (`grug_inventory:welcome`), whose links are
  Help → About's `grug_inventory.LINKS` plus the credits. Fixture:
  `tools/r38_wc`.
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

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- Combat asks `grug_pvp.can_harm`/`can_support` and never changes PvP state.
- A change to the combat path reports the PvE micro run (`tools/r31_pvp/run.sh`) before
  and after.

- **PvP (Round 31, WP41):** `mods/PLAYER/grug_pvp` owns the flag. `rules.lua`
  is pure (the record, the timers 60/60/10/15 s, `credited`); `init.lua`
  keeps one record per online player, samples the location once a second
  (`pvp_rule_at`, `faction_at`; never on the combat path; since Round 85 a
  hall of the arena Breach Road answers first, `R.zone_answers` with the
  halls' interior boxes from `grug_mapgen.breach`) and exposes the
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
  credited at leave, applied at the next join (`grug_pvp:logout_death`, `1`
  or, without an enemy's hit in the 30 s of `R.pvp_death`, `wear`; the set_hp
  reason's `pvp_death` carries it to the death);
  a shutdown sets no mark. `register_on_death(fn(player, pvp))` runs after every
  death; `grug_repair`'s init.lua calls `wear_death` on a non-PvP one. NPC kills count through `_grug_pvp_kind` on the
  garrison prototypes and grug_mobs' eligible-kill hook. `page.lua` (sfinv
  page after Party; texts in the pure `view.lua`) and `hud.lua` (one status
  source) are P2's; the zone banner's territory line and colour ask
  `territory_at` (Round 32: the position's territory by the flag's own
  rule, never the flag) in `grug_map/location.lua`, the target frame
  `can_harm`. Fixtures
  `tools/r31_pvp` (flag core; `run.sh` the engine probe: PvE micro run,
  zone checks, tick cost), `tools/r31_p2`, `tools/r31_p1b`, `tools/r32_f1`
  (the territory line). Rules:
  [pvp.md](../../design/pvp.md).

## XP and levels

- **XP/levels**: template VoxeLibre `mods/HUD/mcl_experience/init.lua` — XP
  as an int in player meta, `level_to_xp` curve, `register_on_add_xp`
  pipeline, HUD bar. Round 18: no death XP loss; cumulative XP caps at level 60,
  and real upward level changes fill living HP/mana with one gold burst.
  Round 28 ([progression.md](../../design/progression.md)): `grug_xp.mob_xp(L)`
  is the kill-equivalent unit `M(L) = 25 + 5L`, `level_xp(L)` the XP from L
  to L + 1, `xp_for_level(L)` the cumulative start of L, and
  `quest_reward(level, weight)` turns a quest weight into XP; kill XP is
  `grug_xp.kill_xp(mob_level, player_level, tier)` (the level-difference
  share of `mob_xp` × tier, Round 46), which `grug_mobs.kill_xp` calls. Positive grants feed
  `grug_core.feed_xp` unless the caller passes `quiet`. Since Round 36 the
  level-up banner's second line counts the talent points the jump earned
  through `grug_classes.talent_points_at(level)`, the one point rule (read
  at runtime: grug_classes loads after grug_xp).

## Skills catalogue

- **Skills catalogue**: `grug_skills` lists unlocked active class/talent
  abilities as one row of the Talents & Skills tab (`grug_classes.skill_catalog_row`,
  drawn by `talents_ui.lua`); mounts are no longer listed (Round 44).
  Entitlement is authoritative; inventory stacks are disposable bound
  representations. Drop or a drag back onto the catalog icon deletes only the
  stack, with no world entity. Skills live on the hotbar only:
  `bound_items.lua` lets a move or a put land an ability only on `main[1..8]`
  and a catalog put only while no copy is carried in main, craft or owned bag
  contents; external inventories, equipment and trading refuse bound stacks.
  The kit grant (`grant_initial_kit`) uses a free slot of the shown hotbar
  layout or leaves the skill in the catalog, never `main[9..]`, a bag or the
  inactive layout; a talent unlock places nothing (Round 50 D1, the feed
  points to the catalog). `grug_abilities.is_unlocked` is shared by catalogue,
  recovery, normalization and actual cast/swing execution. `normalize_kit`
  removes stale copies without re-granting missing ones, counting copies per
  hotbar layout (the shown side: `main` and the bags; the inactive layout's
  list `grug_hotbar_store`), so one skill may lie on A and on B; it still
  keeps copies in `main[9..]` and bags (removing those is the 0.44.0
  migration step). A future step that removes retired skills offline treats
  `grug_hotbar_store` as a hotbar too (unlike `v0_44_0.py`, which keeps
  only `main[0..7]`).
  Do not compare InvRef userdata for inventory ownership: engine callbacks can
  create a fresh wrapper for the same underlying inventory. Authenticate
  `inventory:get_location()` (type and player name), then the allowed list and
  current entitlement. Cross-inventory tests must include both callback sides
  in engine order, not only direct catalogue callbacks.

## Combat and classes

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- The LMB hold is one state machine (`grug_abilities/input.lua`): a new hold rule changes
  that machine and its fixture, never adds a second lock.
- Code that blocks something in combat asks `grug_core.in_combat`, never its own test;
  code that writes a walkable, climbable or liquid node with its own `set_node` asks
  `grug_core.placement_refused` first.

### The damage pipeline and combat state

- **Combat/classes**: damage = damage_groups × armor_groups (÷100) ×
  punch-interval factor. **Damage pipeline lives in `grug_core/combat.lua`**
  (WP4): `deal_ability_damage` (crit ×`CRIT_MULTIPLIER` = 2 since Round 33,
  also for melee and heals; applied via `object:punch` with
  full punch interval so armor/XP keep working; knockback requires an explicit
  `damage_groups.knockback` override), `heal_player`,
  central dodge roll (hp-change modifier), `in_combat` (mob engagement via
  `engage_mob`/`disengage_mob`, a timer via `mark_in_combat(player, seconds)`:
  5 s for PvP hits and untracked sources, 10 s for PvP contact; combat_stats
  §5; since Round 72 a mob engages its target when it takes it, through the
  `do_attack` wrapper in `grug_mobs.register_mob`, `holds_target`).

### Placement in combat and around bodies

  **Placement** (Round 72, `grug_core/placement.lua`, combat_stats.md
  "Placement in combat and around bodies"): one wrapper round
  `core.item_place_node` and one round the falling node's `try_place`; code that
  writes a node with its own `set_node` (doors, beds, the bucket, the notice
  board, the Claim Stone) asks `grug_core.placement_refused(placer, node_name,
  cells)` itself, and `grug_core.body_in_cells` is the one area query. The PvP seam `grug_core.pvp_can_harm`/`pvp_hit_landed` is installed by
  `grug_pvp` (impact re-check, crosshair ray, landed-hit contact), threat stubs `add_threat`/`add_heal_threat` (WP6 fills
  them). Crit/dodge accessors are grug_core stubs overridden by
  grug_classes (`get_crit_chance_raw`: 5 % + 0.05 % per Dexterity point
  since Round 33; dodge 0.1 % per point). Attributes enter damage with their
  fraction (`Str/10`, floored once at the end); the damage-fit reference
  `grug_core.baseline_melee_total(level)` keeps it unfloored too (Round 34
  F2) and is public since Round 35: it is the base hit `B(L)` of the
  level-proof talents. **Talent values (Round 35, skill_trees.md §2.10;
  the graph talents since Round 53, §3.12):**
  `grug_classes.get_talent_bonus(player, key)` sums a key over the
  character's graph ranks and returns, for a key in
  `graph.LEVEL_SCALED_KEYS` (`armor_percent_add`), the stored percentage
  times `grug_core.armor_k(L)` at the player's level (`graph.level_amount`,
  which the node tooltip uses per rank), so every consumer adds the amount
  where it once added a flat value; the talent cache holds only the sums
  (the old `TALENT_LEVEL_SCALED_KEYS` and `talent_level_amount` went with
  the old registry in Round 53). Two helpers of Round 35 stay:
  `grug_abilities.clear_cooldown(player, id)` (no caller since Round 53)
  and `grug_core.is_rooted(player)` (Charge's dash). **`opts.no_crit`**
  (Round 53) on `deal_ability_damage` skips the crit roll (the dodge roll
  still runs): every area and splash hit passes it, the same flag on
  `heal_player` keeps support from critting. **Support factor (Round 36):**
  `grug_classes.get_support_factor(player)` (`stats.lua`) is `1 + gear Int /
  10 / B(L)`, gear Int being the Intelligence above the class's own level
  growth; `kits.lua` `support_value` multiplies every pool-derived heal and
  absorb by it (spell power stays the flat damage term), and
  `spell_damage_value` and the kits return unrounded amounts that
  `deal_ability_damage` floors once after the level scalar (fixture
  `tools/r36_k`). Abilities = hotbar tools in `grug_abilities` (item `range` =
  targeting range; cooldowns and charges show as the hotbar overlay of
  `cooldown_hud.lua` since Round 40: `arm_cooldown` and `reset_charge` hand
  it their `{expiry, duration}` records, `cooldown_math.lua` is its pure
  arithmetic, fixture `tools/r40_cd`; since Round 74 `occupy_casts` and
  `arm_cast_interval` report each block of the action clock with
  `cooldown_hud.block`, the overlay reads a slot's block end through its
  read-only `cast_block` seam and the waiting cast through
  `grug_abilities.input.waiting`, fixture `tools/r74_hud`); kits/numbers:
  `docs/design/classes.md`. WP19 added the 8 s target-memory store (separate
  enemy/ally slots via `grug_abilities.get_target(player, ally)`). **WP39's
  decided rule supersedes its hostile fallback:** enemy memory is Target-Frame/
  UI state only and no melee, hostile cast or projectile may read it as aim;
  friendly skills always resolve through valid pointed ally → valid ally
  memory → self. WP19 also added **absorb
  shields** (`grug_core.add_absorb`, soaked in the central
  hp modifier after dodge/fall mitigation; since Round 80 a contribution is
  stored in whole points, and the modifier hands its change on as the integer
  the engine stores, truncated toward zero, so the hp loggers such as the
  nametag never see a fraction; fixture `tools/r80_fixes`), **race passives** as a perk
  table in the grug_classes race registry (`grug_classes.get_race_perk`,
  stub-mirrored as `grug_core.get_race_perk`; elf range via per-stack
  meta `range` override) and mob slows (`grug_mobs.slow`, staticdata-safe
  countdown shared with root). NB a lethal ability punch removes
  animation-less mobs synchronously — capture mob pos/luaentity BEFORE
  `deal_ability_damage`. **mobs_redo `do_punch` gotcha**: any truthy
  return cancels the punch (api.lua comment claims the opposite) — hook
  wrappers must return nil; player-hit hook:
  `grug_core.register_on_player_hit_mob` (fired by grug_mobs).

### The weapon slot and the equipment seam

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
  Since Round 37 it is pure wear only, its own cheap event: the use that
  breaks an item notifies a full change (reason nil). Since Round 81 grug_gear
  also uses it when it rewrites only a hand's "Effective at level" line (a
  level-up, a Str/Dex equip), so neither reruns every consumer nor restarts
  the swing clock; a changed look (image) stays a full change. On the reason the
  armour and affix caches stay (only the named slot's cached copy is
  dropped), and the stats, look, Character page and ability mana/HUD/
  description/skin consumers return at once; grug_repair writes only the
  tooltip's "Durability: N / M" line (`grug_repair.refresh_durability`).
  The HUD's durability hints (`grug_repair/hints.lua`) read the worn slot on
  that reason and every equipment slot on any other change.
  Held swings refresh their usable same-item snapshot without restarting
  cadence; actual swaps and broken/unbroken transitions still reset.

### Swing skills and the held clock

  **Swing skills use native interaction plus an authoritative held clock**
  (`classes.md` §2b; WP38 base, WP39 target-authority revision decided
  2026-08-10): Strike and the swing skills (Retort, Mighty Blow,
  Broadstroke, Hamstring, Bladecraft, Opening) have `kind = "swing"`
  and **no `on_use`**, keeping the fast first-person held animation. Their
  native enemy packets are input only and return before damage/rage/threat/
  wear/proc. The no-dig pointabilities can mask a ground-level drop, so each
  fresh LMB press retains the bounded first-visible 4 m builtin-item pickup ray;
  nodes/other objects block it and held repeats do not become auto-loot.
  Since 0.49.1 a fresh press that arrives as the native punch on a drop
  (`M.press(player, entity)`) picks up that drop when the ray misses it and
  the press is no combat press, within `HAND_RANGE + 2.6` of its server
  position (upstream-workarounds §7).

### Aim rays and the held attack

  **WP39 shipped the current-ray authority on 2026-08-10.**
  `grug_core.combat_eye_pos(player)` and
  `grug_core.combat_ray(player, range, opts)` are the shared server-side
  acquisition seam: the latter returns one physically ordered structured ray
  result for combat and diagnostics, so callers do not raycast again for logs.
  Its `friendly` option (Round 78, set by `aimed_target` for friendly skills)
  passes every object but a living friendly player (the tank behind the boss).
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
  ([upstream workarounds](../upstream-workarounds.md) §1).
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
  interval. Native tool/fist packets deal nothing and do not move the clock
  (Round 37 removed WP38's proportional tool/fist path).
  Swing ItemStacks continue to mirror equipped-slot FPI compare-first with
  `fleshy = 0`, empty `groupcaps`, `max_drop_level = 0`,
  `punch_attack_uses = 0` and blocking hand/dig_immediate node pointabilities.
  The ability stack never wears. Round 11's REPAIR hook spends wear on the
  acting hand slot (the melee weapon, or the captured bow for a shot) once on a qualifying settled
  action. The accepted transaction stays
  exact attacker+ray-target and claim-once; the mobs_redo/PvP finish seam pays
  cost, resets charge, grants rage and applies post-effects only on its existing
  accepted/HP-loss conditions. Since Round 53 Mighty Blow (and Broadstroke's
  primary) is 1.45 x (weapon + melee bonus) plus Heavy Hand and Finisher,
  Hamstring a 35% slow, and the Warrior's windows (Retort, Ruination) reach
  every swing through `grug_abilities.register_on_swing` (`kits_warrior.lua`).
  WP39's binary small gold crosshair ring is shown once while a selected
  swing is weapon-ready, hidden on a valid attempt, absent for non-swings, no
  smooth progress and no inventory writes; a weapon swap follows the new
  clock's readiness and lifecycle cleanup removes it. Target validity is a
  separate overlay (`grug_abilities/crosshair.lua`, `classes.md` §2b "Crosshair
  feedback"): it reads `grug_abilities.aimed_target` (the side-effect-free aim
  authority the hostile/friendly casts wrap) and `input.aims_at_interactive`,
  and owns the progress ring of eating (`input.lua`, hidden in
  `end_food_hold`): `set_ring(player, fraction, owner)` with owner `"food"`
  (the bow draw's `"bow"` owner and its full frame went with the draw in
  Round 53); the first owner to show it keeps it until it hides it. The
  game's `crosshair.png`/`object_crosshair.png` are byte-identical on purpose;
  regenerate them with `tools/pt_fixes/lane_b/gen_crosshair_textures.py`.
  Since Round 30 the state overlay refreshes every 0.15 s (input and the
  ready ring stay on the 0.05 s pass), an unchanged skill ray that hit no
  object is reused for up to 0.25 s, and the Target Frame
  (`grug_mobs/target_frame.lua`) reads
  `grug_abilities.crosshair.recent_aim` before casting its own 20 m ray.

### The LMB hold state machine

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
  Since 0.45.1 the tap (`s.pending`, a self or friendly skill pressed at a
  hand-diggable or protected node) is decided by `TAP_US` (0.35 s, the
  server-seen release; derivation at the constant) and ignores where the
  crosshair moves meanwhile; `can_dig` still refuses a completion only
  before `HOLD_US` (0.2 s), and the `on_dig` wrapper clears `s.pending`
  when it accepts one, so a completed dig makes the press a hold. The food
  RMB click/hold (`food_hold`) uses the same `TAP_US`, and a self skill
  fires on the fresh press at any actor that is no target of its own (an
  ally for Ice Nova, an NPC, a forbidden ally). Fixture `tools/r451_sc`.
  It also ships permanent
  admin-only per-player `/combatdebug`; disabled sites do no ray/log
  formatting/globalstep work beyond the enabled check.

### Hostile casts and projectiles

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

### Shared per-player reads and passes

  Round 81 (lane HOT; audit X4-01, C1-05, X4-05) put three small helpers
  into grug_core for the per-step and per-hit paths:

  - **The privilege cache** (`grug_core/privs.lua`):
    `grug_core.has_priv(name, priv)` answers as `core.check_player_privs`
    does, kept per player name and privilege; the grant and revoke callbacks
    (behind `/grant`, `/revoke` and `core.set_player_privs`), leaving and
    `core.auth_reload` drop the answers. The engine has none: every uncached
    check is an auth-database read. The contextual input's `interact` test,
    environment damage's `noclip` (asked only for a head node that would
    suffocate) and `mobs.has_priv` go through it.
  - **The player body** (`combat_ray.lua`): `grug_core.player_body(player)`
    is `{eye_height, collisionbox}` read once with `get_properties()` and
    kept (weakly, by ObjectRef) until `grug_core.player_body_changed(player)`.
    The writers of either property for players are closed: player_api's
    `set_animation` on a new animation class and `set_model`'s fallback
    (GRUG PATCH, [VENDOR.md](../../../VENDOR.md) "Round 81 HOT") and
    `grug_mounts.apply_camera`; a new writer must call
    `player_body_changed`. `combat_eye_pos`, environment damage's head point
    and the homing aim at a player read it; the homing aim at a mob reads
    its `_grug_cbox`.
  - **Join slots** (`grug_core/player_slots.lua`):
    `grug_core.register_player_pass(period, fn)` (at load time) calls
    `fn(player, elapsed)` for every connected player once per `period`,
    one of eight slots per `period / 8`, so no step handles every player.
    A player joins the slot with the fewest players and keeps it;
    `elapsed` is the game time since this pass last visited the player
    (since the join at first), so a pass that adds up over time keeps its
    sums. A server step serves up to two ticks, so a period down to
    0.36 s keeps its cadence at 0.09 s steps, and a stall collapses to two
    ticks, which the next `elapsed` covers.
    `grug_core.player_pass_slot(name)` names a player's slot. On it since
    Round 81 (lane PASSES): the status row (0.5 s), the regeneration and
    HUD-bar pass of grug_abilities (0.5 s), the target frame (0.5 s), the
    PvP location sample and the PvP page refresh, the Character page's 1 s
    refresh, the day-night ratio, environment damage (each visit's `elapsed`
    rounded to whole ticks) and the wield poll (1 s each). The vegetation renewal
    already services its players round-robin and is not on it.

  The input pass reads the wielded item once per player and pass and hands
  the name to the step, the ready ring and the crosshair (Round 81).

  **The identity cache** (Round 81, lane PASSES; audit C3-02): the stored
  XP and level (`grug_xp.get_xp`, `get_level`, so
  `grug_core.get_player_level`), class and race (`grug_classes.get_class`,
  `get_race`) and faction (`grug_factions.get_faction`) are read from player
  meta once and kept per ObjectRef (weak), so a rejoin reads afresh. Each
  key's one writer rewrites its entry: `grug_xp.set_xp` (every XP grant goes
  through `add_xp`), `grug_classes.set_class` and `set_race`,
  `grug_factions.set_faction`. Meta stays the authority; the registry check
  and the race's faction test still run on every call. A new writer of one
  of these keys must go through its setter; a fixture that writes the meta
  directly must do so before the first read of that player. The same
  pattern keeps `grug_classes.applied_max_hp(player)` (the hp_max
  `apply_stats` last set; the life bar and the nametag read it) and the
  potion cooldown's expiry (`grug_traders`).

### Pools, environment damage, statuses and food

  Round 6 centralizes player scaling in `grug_core.base_pool`: max HP and mana,
  percentage mana costs, pool-derived heals/absorbs and the damage-only
  `level_scale` fit follow `combat_stats.md` §2; Strength and Intelligence are
  damage secondaries only. The Character page displays maximum pools and its
  Help page explains the model. An ability definition may expose
  `def.description_for(player, def)` (often reading a kit helper such as
  `def.values`, whose signature the kit chooses);
  `grug_abilities.update_stack_description(stack, def, player)` writes that
  text with the effective current-level values to the player's stack on kit
  sync, level change and talent change. Every cost text (the tooltip head, the talent tree's nodes and
  strip) comes from `grug_abilities.cost_text(player, def)` (Round 80): "N% base
  mana (M mana)" with M the cast's whole charge (`effective_cost`), "N mana",
  "N rage" or "free"; skill and node descriptions name no cost of their own.
  Instant heals with no heal-over-time part (Heal, Hearten) refuse a target at
  full health from `cast` (`false, msg`: no mana, no cooldown; Hearten only when
  no one it would heal is hurt). Suffocation is 5% maximum HP/s (minimum 1), with stasis and
  `noclip` exempt; lava is 20% and drowning 10% of maximum HP/s
  (`environment_damage.lua`, Round 24), and absorb does not cover fall,
  lava or drowning. `grug_core/status.lua` (`set_status`, `clear_status`,
  `get_status`, `status_modifier_sum`) is the runtime timed-effect registry and, since
  Round 26, the bottom-centre status icon row (at most 10 icons, 0.5 s pass;
  pictures and frame kinds in `grug_core/status_icons.lua`) that also feeds
  the Character page's Effects tab; the combat state is not a status but
  the icon `grug_core/combat_hud.lua` draws right of the health bar. Status definitions may carry only
  `hp_pool_percent`, `mana_pool_percent`, `crit_percent`, `armor` and
  `spell_damage_percent`; `grug_core.status_modifier_sum` adds active statuses,
  and the modifier-change callback drives the same HP/mana clamp and HUD/page
  refresh path as talents. `grug_food.TIERS` owns fixed instant HP, minimum
  level and the Hearty/Caster/Hunter/Plain dish data; raw foods, including Wild
  Cocoa, always regenerate 2% HP per 5 s. Food lasts 300 s. Eating during
  combat is refused before consumption; accepted food heals instantly, and its
  regeneration pauses during later combat while secondary modifiers persist. The
  latest food replaces the previous one. `grug_core.can_use_item_level` is the
  shared level gate (`_grug_req_level`, else `_grug_ilvl`) for every
  equipment slot (Round 33) and all consumables; `grug_quality` wraps it so
  a stack's own `grug_req_level` (drops, upgrades, the crown) wins. Potions
  retain their instant channel and shared persistent cooldown.
  `grug_cooking` owns the mapgen-free plant items, the 18 dish recipes, the six
  raw assembled dishes (Cooking recipes since Round 45) and their engine
  furnace routes. `grug_fishing.band_at(pos)`
  selects one of six catch tables through `grug_core.mob_level_at(pos)`; water
  salinity never gates fishing.

### Alchemy and potions

  **Alchemy** is split between low-level `grug_brewing` (the inactive/active
  stand nodes, a proximity station since Round 45) and `grug_alchemy` (items,
  profession recipes and effects). Every product is an Alchemy recipe at the
  stand (2 s) that makes the finished potion or elixir and gives progress; the
  automatic brewing and its adapter are gone. The 40 `grug_alchemy:mixture_*`
  ids are aliases of `vessels:glass_bottle` since Round 88 (inert items with
  the group `grug_potion_mixture` before; the engine resolves an alias when a
  stack is read, `src/inventory.cpp`). Each product's inventory image is its
  family's bottle (`recipes.lua` `image`, Round 88; `register_consumable`
  refuses a definition without one, so no tinted fallback is left). Capital
  personal workspaces derive from terrain-resolved,
  rotated `public_station` sockets in the themed outer premises.
  `grug_jobs.register_public_position(station, pos)` owns the shared registry
  (the brewing stand included).
  No fixed capital-core position is authoritative. Potions share
  `grug_traders`' persistent clock (`grug_traders.POTION_COOLDOWN` = 30 s in
  `potion.lua` since Round 78, shown in the status row as `potion_cooldown`, which also owns the vendor's Weak Healing Potion; every
  potion and draught); Healing and Mana Potions I–VI are fixed amounts
  (`grug_alchemy/recipes.lua`, item_tiers §5);
  elixirs replace status id `elixir`, stack with status id `food`, and never
  touch that clock.
  `grug_gathering`'s herb authorizer delegates to
  `grug_jobs.has(player, "alchemist")`; Cave Cap remains universal food.
  The former real-code Lua 5.1 regressions under `tools/wp39/` were retired in
  Round 22 (D22); git history keeps them.

### PvP melee

  **PvP melee runs through the same pipeline** (the on_punchplayer
  handler in grug_abilities): an authoritative ability swing builds the
  slot-fed full swing, adds Strength/proc, rolls crit once, applies
  `grug_core.apply_player_armor` with attacker-level provenance and the
  rating formula capped at 70% reduction, then enters
  dodge/absorb once. Every native packet (swing item, tool, fist) is
  suppressed and never authorizes the final target; the claimed token alone
  makes a swing authoritative, so the Strike fallback with Loose or a cast
  skill wielded is the same transaction (Round 37, CMB-01). The hit uses
  `set_hp` with `type="punch"`/`object` and
  `custom_type="grug_core:player_armor_applied"`; the central modifier skips
  only the already-run armor step while dodge and absorb still run once.
  `return true` always suppresses handled hostile engine damage.
  Same-faction pairs stay with grug_factions' handler
  (RUN_CALLBACKS_MODE_OR, s_player.cpp:63 — neither vetoes the other);
  knockback on players never comes from the engine's damage argument: the one
  `core.calculate_knockback` override (`grug_core/knockback.lua`, Round 88)
  hands builtin no push and pushes itself by the attack's weight class
  (PvP melee a fixed push, a mob its family's class through the seam
  `grug_core.mob_knockback` that `grug_mobs/knockback.lua` installs),
  horizontally with one fixed lift, in a per-player window where only the
  stronger push counts (`grug_core.push_player`); who pushes stays
  `grug_core.knockback_pushes` (Round 37: PvP melee swings and a mob's own
  hits; projectiles, refused punches and a player's casts, arrows and ability
  damage push nothing): acquisition
  caps are zero, while the one authoritative punch supplies the real full
  caps. Swing ability items use the slot source, do not wear (the equipped
  weapon wears through REPAIR's settled action) and can carry the selected
  proc's threat multiplier. The current server ray is the sole
  authoritative hostile ability target while LMB is held; enemy memory is
  UI-only.

### Particle effects

- **Particle effects** (Round 40): every effect is a named emitter list in
  `grug_core/particle_effects.lua`, played by
  `grug_core.particles.play(id, frame)` (`particles.lua`, whose header
  documents the emitter fields; since the look pass after Round 54 also
  `mote`, the white mote `grug_core_mote.png` under the tint, `blend =
  "add"` and `after`, an emitter deferred through `core.after`, which
  Meteor's and Censure's falls use): every skill and proc effect, crits,
  absorb soaks, the level-up burst and the boss and mob-special effects
  (Round 40 PM: `grug_mobs` plays them from the kings' signature, the
  elite telegraph, the dragons, the Kraken, the mob verbs and families;
  mob projectiles name their impact tint as `impact` in
  `register_simple_arrow`). Still direct engine calls: the stun cross and
  root crystals (`movement.lua`, sized from the object's box), the food
  crumbs (a texture pool), the rift's per-player stretches and pulse
  (`rift.lua`), the mob arrow tail (`verbs.lua`) and the mob engine's own
  blood and smoke.
  `frame` names the anchors (`caster`, `target`), the facing `dir`
  (`grug_core.particles.facing(player)`), and per call `from`/`to`/`time`
  (a line over a flight), `reach` (a radius a ring lands on) and `color`.
  The helper never attaches a spawner and clamps its time to (0, 1], so
  only players near the effect receive it (`server.cpp:1739`), places exact
  rings as single particles, and applies `grug_particle_scale` (read once at
  load; spawner amounts and single counts, a floor of one per emitter, 0 =
  off). `particles.register` checks each list's budget at load. Skill arrows
  opt in per launch (`params.trail` in `grug_projectiles.spawn` and
  `spawn_batch`, played after the batch commits); the shared proc flash is
  `grug_core.proc_flash(player, proc)` with `grug_core.PROC_COLORS`;
  Charge's dash (`grug_abilities/charge.lua`) calls
  `grug_abilities.charge_dust(from, to, duration)` per run segment and plays
  `charge_ring` on arrival. Fixture: `tools/r40_px/portable_test.lua`.

### Charge's dash

- **Charge's dash** (Round 40, [classes.md](../../design/classes.md) §3):
  `kits_warrior.lua` keeps the cast's target, destination and refusals and
  calls `grug_abilities.charge_dash(user, target, dest, def)`. The planner
  `charge_path.lua` is pure (map through `boxes`/`liquid`, like `blink.lua`);
  `charge.lua` owns the carrier entity `grug_abilities:charge_carrier` (blank
  visible sprite, not pointable, not saved, removes itself without its
  rider, never `_grug_rider` or `player_attached`), the arrival and miss
  rule in the carrier's own `on_step` (no globalstep), punch forwarding and
  the cancellations. Travel cancels through the seam `grug_core.cancel_dash`
  (declared nil in `grug_core/combat.lua`, installed by `charge.lua`).
  Every player carries a `Body` bone-override epsilon from joining on
  ([upstream-workarounds.md](../upstream-workarounds.md) §3). Fixtures
  `tools/r40_ch/portable_test.lua` and `tools/r451_ch/portable_test.lua`
  (stairs and slopes down and up, the straight drop); headless bench
  `tools/r40_ch/bench`.

### The class rework's building blocks

- **The class rework's building blocks** (Round 52, round F of the
  [delivery plan](../../planning/class-redesign/delivery-plan.md);
  [class plan](../../planning/round52-class-plan.md) C1–C13, D1–D9), used by
  the new kits since Round 53 (round K, `kits_mage.lua`, `kits_warrior.lua`,
  `kits_priest.lua`, `scout.lua`; [classes.md](../../design/classes.md)
  §3–§5, [scout.md](../../design/scout.md) §2).

#### The action clock

  - **The action clock** (D2, `grug_abilities/init.lua`): every ability
    definition gets `occupied_cast` (seconds ≥ 0; a cast's default 0, a
    swing's default `"weapon"`, one interval of the current melee weapon,
    Round 53 K9) and every cast `occupied_swing` (seconds ≥ 0, or
    `"weapon"`, the default; a swing may not set it, its own clock is that
    interval). Each of them and `cast_interval` may instead be a
    `function(player, def)` returning the value (Round 53, Loose's affix
    cadence); called without a player it returns the base, which the
    timing line shows and the registration checks. Three directions: **cast → swing**
    is `grug_abilities.delay_strike(player[, def])` (`strike_delay.lua`,
    called by `input.lua` after a cast, Bladecraft's right-click shot
    included), which pushes the melee clock's `next_due` and never
    shortens it; **cast → cast** and **swing → cast** are `occupy_casts`
    after a successful `try_cast` and when a swing finds its valid target
    and consumes its interval (the selected skill's value, Strike's in the
    fallback), a per-player time
    on `core.get_us_time` that never shortens a running lock and is
    cleared on death, respawn and leave. A cast with a `cast_interval`
    (the held basic attacks) carries the lateness behind its previous
    due time, at most 0.1 s (`CLOCK_CATCHUP`) and half the clock, into
    its interval and its own occupied time, so a held cast keeps its
    cadence on 0.09 s passes; a later cast (an idle gap) and a cast
    without an interval carry nothing (Round 53 INTEG). `cast_refusal`, shared by the
    input gate and `try_cast`, refuses with "You are still busy." while
    it runs (after the cooldown and cast-interval checks, before the
    cost); a held repeat stays quiet like every other refusal. Its second
    result names the reason (`class`, `locked`, `cooldown`, `interval`,
    `busy`, `cost`). The defaults: a cast pushes the next swing by one
    weapon interval and blocks no other cast, a swing holds casts back for
    one weapon interval (Round 53 K9). A per-skill lock is no global
    cooldown (C2). **The held fallback** (Round 53 K8, `input.lua`): a
    skill that cannot act on the hostile a press aims at fires the
    player's current basic attack (`current_form` of Strike) once,
    silently, a swing through the swing, a cast through `try_cast`; none
    when the skill is that basic attack or the refusal is `busy` or
    `interval`. **The waiting cast** (Round 74 CAST, `input.lua`): a fresh
    or carried press of a self or support skill refused only `busy` or
    `interval` is kept as `s.waiting` (one at a time, a new key-down
    replaces it); `wait_step` runs once per pass before the press acts and
    fires it at the first pass its clocks allow; `fallback` does nothing
    meanwhile; it expires after `max(weapon interval, api.cast_wait) +
    WAIT_GRACE_US` (`init.lua`'s `cast_wait`: what the action clock and the
    skill's own interval still hold back), and `reset`, `cancel` and an RMB
    interaction drop it; `grug_abilities.input.waiting(player)` is the
    overlay's accessor (fixture `tools/r74_cast`). PvE bench
    `tools/r52_bench` (per-action records of each class, main against a
    branch).

#### The transformation

  - **The transformation** (D8): `transforms = "<base id>"` on the ability
    definition names an ability registered before it, of its own class or
    a universal one. With `talent_gated` it replaces the base while its
    talent (`def.talent` or its own id) has a rank; without a talent it
    may only replace a universal ability, which makes it its class's
    basic attack in place of Strike (register it first in its class
    file: the initial kit follows `by_class` order; `register_ability`
    asserts that such a transform never also sets `basic_attack`). A class's own basic
    attack that replaces nothing sets `basic_attack = true` (the Scout's
    Loose): the initial kit then puts it on key 1, the class's other
    starters after it and the universal abilities last (Round 53 K7). `cooldown_key` is
    derived, never declared: the base's key, else the own id; cooldowns,
    cast intervals, charges and the cooldown overlay all key on it, so a
    form and its base share one cooldown. `is_unlocked` is false for a
    replaced base; `grug_abilities.current_form(player, def)` names the
    unlocked member of a family. `normalize_kit` swaps a locked family
    stack in place for that member, on `main` and the inactive layout
    first and then in bags, after its pass, so a copy the player already
    holds wins (Round 50 ruling 12, class plan C8). Since Round 53:
    Fiery Spark and Smite (of Strike, without a talent), Retort (Strike),
    Cold Spark (Fiery Spark), Ice Nova (Ice Wave), Bellow (Taunt),
    Broadstroke (Mighty Blow) and Bladecraft (Loose). **`secondary_cast`**
    (Round 53, `input.lua`): a selected, unlocked definition that carries
    one owns an RMB press that is neither food nor an interaction; the
    press casts it through the same cast gate as a left-click cast, and,
    held, again whenever its own clock allows (a refusal reports on a fresh
    press only). Bladecraft's is the Loose shot (`scout.lua`
    `bladecraft_shot`, never registered: Loose's interval through
    `cooldown_key = "loose"`, `occupied_swing = "weapon"`, its id
    Bladecraft's for the unlock check). **`shot_slot`** (Round 72,
    Bladecraft's alone, `"weapon"`): the slot the skill shows after its
    last real attack was a shot. `grug_abilities.show_last_attack(player,
    shot)` is called by the shot when it flew and by Bladecraft's swing
    callback; it records the state in `grug_visuals.show_shot` (memory
    only, cleared on leave), re-skins the skill's stacks on both hotbar
    layouts (the held one through `set_wielded_item(stack, true)`, no
    re-raise) and calls `grug_visuals.apply`. The skin pass and
    `shown_item` ask `grug_visuals.hand_slot`; `slot`, damage and both
    clocks stay the Melee blade's. Fixture `tools/r72_bladecraft`.

#### Readiness windows

  - **Readiness windows** (B8, `grug_classes/talent_windows.lua`): keyed
    by any string id. `grug_classes.open_window(player, id, {duration,
    icd, value, label})` returns true when it opened (false while its ICD
    runs; reopening renews it); `get_window(player, id)` returns
    `{expiry_us, value}` or nil without spending it; `consume_window`
    returns that record once and closes the window with its status icon
    (the qualifying attack, or an early end); `window_icd_ready`. The ICD
    runs on `core.get_us_time` in memory and outlives death, respec and a
    relog within one server run; `clear_talent_windows` (leave, death,
    respec) ends the open windows and drops run-out ICDs. Icons come from
    `grug_core.status_icons.WINDOWS` (Round 53: `cold_shock`, `retort`,
    `clear_conscience`, `follow_the_line`, `parry`, `ruination` and
    `close_dance`, each showing the status of its own id). The old
    talent windows and their trigger cooldowns (`talent_trigger_ready`,
    `os.time` in `grug_classes:talent_ready:<id>`) went with the old
    talents in Round 53; the 0.53.0 migration step deleted the keys.

#### Area helpers

  - **Area helpers** (`grug_core/area.lua`, `grug_core.area`; C3, C4,
    D9; the ground anchor of
    [skill inventory §3a](../../planning/class-redesign/skill-inventory.md)).
    `area.anchor(player, range, opts)` returns `anchor, target` or `nil,
    "No ground found."`: a legal enemy on the combat ray
    (`opts.is_enemy`, the abilities' `valid_target`) gives its position,
    else the terrain point of a node-only ray (walkable, unknown or
    liquid nodes stop it, plants pass); `area.ground_below(point,
    start)` then searches straight down for the top of a walkable node
    under a non-walkable one, at most `area.H` (3) below the point,
    through liquids and plants. A `def.cast` returns the refusal as it is,
    so nothing is paid and no cooldown is armed. `area.query(anchor,
    {radius, band, filter, cap})` returns the objects within the
    horizontal radius and ±`band` (default 3) of the anchor, nearest
    first (ties by y, x, z, then name), at most the cap; no line of
    sight (0.53.1: walls and step edges inside the band hide no one, for
    every area, cone and group). `area.cone(caster,
    {radius, angle, band, dir, filter, cap})` (Round 53) returns the
    objects within the horizontal radius and ±`band` of the caster's
    feet and within `angle` (the whole opening, degrees) of its
    horizontal facing (`dir`, default the look), accepted by `filter`
    (the abilities' `valid_target` through
    `grug_abilities.target_filter(player, kind)`), nearest first, at
    most `cap`; the caster never.
    `area.fall_height(anchor, radius)` is the room for falling visuals:
    half a node below the lowest ceiling over the anchor's column and,
    with a radius, the four columns at 0.6 × the radius around it (a
    slope rising into a column and rock beside the area lower nothing),
    at most 12; `area.delayed` passes its radius. `area.delayed(caster,
    {anchor, delay, impact, radius, color, warning, fall, burst})` plays
    the warning ring (single particles that live exactly the delay) and
    the falling particles at once and runs `impact(caster, anchor)` after
    `delay` (at most 3 s) through `core.after`, no globalstep: the caster
    leaving cancels it, a caster who died still lands it, the caster is
    fetched again by name and the impact queries its targets itself. The
    particle effects are `area_warning`, `area_fall` and `area_impact` in
    `particle_effects.lua` (96 particles per cast at scale 1); no sound.
  - **The group helper:** `area.group(caster, {radius, band, cap,
    eligible})` returns the caster and the players within the horizontal
    radius and ±`band` (default 3) of the caster's feet that `eligible`
    accepts, at most `cap` with the caster counted, lowest HP share
    first, ties by distance and name.
  - Fixture `tools/r52_core` (the pure functions, the window API, the
    group order, a heal-over-time status that runs on after its target
    left the area) and the engine probe `tools/r52_core/probe.sh` (stairs,
    stacked floors, a cave, shallow and deep water, a flying mob, a dead
    caster, the group heal; its test ability lives only in the probe
    mod).

#### Round 53 seams for the class kits

  - **Round 53 seams for the class kits** (`grug_abilities/init.lua`,
    round53-plan.md §4 HOOKS). *Talent keys:* the graph's
    `graph.LEVEL_SCALED_KEYS` (only `armor_percent_add`) and the class
    vocabularies (`graph.register_class_vocabulary`) are
    [skill_trees.md §3.2](../../design/skill_trees.md#32-the-one-hook)'s.
    *Family keys:*
    `grug_abilities.family_bonus(player, def, family)` sums the graph
    talents' `<family>:<param>` keys over the definition's id and its
    `tags` (a transformation by its own); the cast path applies
    `cost_pct` (`effective_cost`, through `cost_for`'s percentage, then
    the definition's `cost_adjust(player, def, cost)`), `cooldown_sub`
    (`effective_cooldown`) and `range_add` (`get_range`), the tooltip
    shows them; the swing path charges a proc the same `effective_cost`
    and adds the plain swing's `damage_pct` as a share of its untalented
    damage (Strike is tagged `blade`); a kit reads `damage_pct`,
    `radius_add` and `duration_add` through the same helper (`K.family_bonus`).
    *The swing callback:* `grug_abilities.register_on_swing(func)`, from a
    class file; `func(player, {def, proc, target, weapon_damage, fpi})`
    returns nil or `{damage_mult, damage_add, rage_add, on_landed}`: raw
    damage × every multiplier + every add before the one scaling pass,
    the rage and `on_landed(player, swing)` only when the swing lands.
    Users: `kits_warrior.lua` (Ruination's ×1.15 and rage, a readied
    Retort's bonus and Recover) and `scout.lua` (Close Dance's add on a
    plain blade swing). *Launch seam* (`grug_projectiles/init.lua`): a
    spawn's own `params.sound_launch` replaces the projectile's launch cue
    for that launch (Arrowfall's volley uses it; Cold Spark and Flame Lance
    register their own projectiles with their own cue). *Clock seams:*
    `cast_interval`, `occupied_cast` and `occupied_swing` as functions
    (Loose's affix cadence, Flourish's blade interval) and the K8 fallback
    and K9 default, above. *The held cast's catch-up:* `CLOCK_CATCHUP`
    (0.1 s), above.
    *Tables before the kits (K6):* `WEAPON_FX`, `SKILL_POSES` and
    `CAST_SOUNDS` rows of the 25 new skills, their icons, the 34 new
    particle effects and 7 retints of the picked cards
    (`tools/r52_pfx`), the window proc colours and the status and window
    rows. Fixture `tools/r53_hooks`.

#### Mend on the status system

  - **Mend on the status system** (D1, `kits_priest.lua`): a
    `grug_core.set_status` with `interval = 3`, `duration = 12` and an
    `on_tick`, so its four ticks come 3, 6, 9 and 12 s after the cast
    (the status pass runs every 0.5 s and fires a tick due at expiry);
    the amount is the cast's snapshot, an offline healer's ticks heal as
    the target, a recast renews duration, phase and amount, and the
    status ends on death and leave. Its own globalstep and die handler
    are gone ([classes.md §5](../../design/classes.md#5-priest-mana)).

#### The weapon overlay

  - **The weapon overlay** (C7, `grug_abilities/init.lua`):
    `grug_abilities.WEAPON_FX` maps every ability id to its tree's
    family (ember, rime, bulwark, ruin, mercy, reckoning, quarry, veil;
    Strike `"none"`), `WEAPON_FX_ANIMATION[family]` holds the family's
    `{frames, frame_length}`, and an animated family's skill item
    definition carries `wield_overlay = {name = NO_OVERLAY, animation =
    16 × 16 vertical frames}`. The skin pass (`apply_skin`,
    `skin_overlay(def, weapon)`) writes the strip
    `grug_abilities_fx_<family>_<weapon>.png` for the held weapon type
    into the stack meta: the engine's meta overrides
    only the overlay's name and keeps the definition's animation
    (`ItemStack::getWieldOverlay`, `src/inventory.cpp`). An empty slot,
    Strike, a weapon without a strip and a strip that does not ship get
    `NO_OVERLAY` (`"[combine:16x16"`, transparent; an empty meta string
    would not override the definition). `SKIN_VERSION` 5 (token
    `5|<src>|<overlay>`) rewrites each skill stack once. The strips use
    opaque pixels only: the wield mesh (`object_shader`,
    `TILE_MATERIAL_BASIC`) discards a pixel below alpha 0.5 and draws
    the rest opaque (`src/client/shader.cpp`,
    `client/shaders/object_shader/opengl_fragment.glsl`). **Third
    person** shows no overlay: the holder copies only the cosmetic
    weapon (`grug_visuals/apply.lua` `shown_item`), and the engine
    advances a wield-item entity's overlay animation only when the light
    at it changes (`GenericCAO::setNodeLight`,
    `src/client/content_cao.cpp`), so an animated overlay would freeze
    there in 5.17 (a still frame was built in Round 52 and reverted at
    the user's word). Fixture `tools/r52_wfx`.
