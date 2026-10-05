# Combat, Attributes & Progression Mechanics

Decided spec (last revised 2026-09-18; established 2026-08-06).
Implementation: WP3 (classes/stats pipeline),
WP4 (abilities/threat tools), WP6 (mob tiers/speed), WP5+WP7 (item/
consumable values), WP35 (weapon slot and the two-handed rule), WP38
(native swing/proc timing) and WP39 (current-ray hostile authority, reticle,
diagnostics and swept projectiles; shipped 2026-08-10). Damage pipeline and
threat live in `grug_core`.

Core principles:

- We think in **skills + items**: skills are acquired and improved through
  the class skill tree (**1 talent point every 2 levels, the first at level 2
  — 30 points at level 60**, user ruling 2026-09-16); items carry
  stats/enchantments. The former "1 skill point per level" in this line was
  superseded by that ruling, together with `progression.md` §2's earlier "1
  point every 3 levels"; the trees the points are spent in are
  [skill_trees.md](skill_trees.md) (decided revision 2). Named, bounded
  rule-breakers may exceed a stat cap only where that design explicitly says
  so; Round 11 has delivered Unbroken's armor-rating multiplier and emergency
  window under the unchanged universal 70% reduction cap.
- **One readable level curve**: player pools and normal-mob HP share the
  rounded `20 + 5L + 0.66L²` base. Class factors, percentages and gear form
  visible secondary axes; level itself does not hide inside attributes.
- Simplify known mechanisms, keep the recognizability.

## 1. Attributes

Three attributes, **automatic per-class growth** (no manual point
allocation in the MVP; can be added on top later without breaking
anything). Item enchants (+Str etc.) are the player-driven part.

| Attribute | Effects |
|-----------|---------|
| Strength | non-Scout melee damage |
| Intelligence | spell damage; from gear also healing/absorbs |
| Dexterity | crit chance, dodge chance, Scout melee/ranged damage |

- Base at level 1: **10 / 10 / 10** (Str/Int/Dex), all classes.
- Growth per level (4 points): **Warrior +3 Str / +1 Dex · Mage +3 Int /
  +1 Dex · Priest +1 Str / +2 Int / +1 Dex.**

## 2. Player formulas

- **Class-neutral base pool** `P(L)` =
  `round(20 + 5×L + 0.66×L²)`, with `L` clamped to 1–60.
- **Max HP** = `round(P(L) × class factor × (1 + gear% + talent%))`.
  Class factors are Warrior **1.20**, Priest **1.00**, Mage **0.90**.
- **Mana** = `round(P(L) × (1 + gear% + talent%))` for Mage/Priest.
  The Warrior uses flat Rage 0–100. Strength never adds HP and Intelligence
  never adds mana.
- **Melee damage** = weapon damage + melee attribute/10 (fractions included
  since Round 33; the assembled damage is floored once at settlement), where the
  attribute is Dexterity for Scout and Strength for other classes. Since 2026-08-08,
  **"weapon damage" has a source: the melee weapon** — the item in the
  WEAPON SLOT, or for the Scout the Melee offhand (Round 28 ruling 25;
  `inventory_equipment.md` §2) — the single, fixed source for every
  sword-type skill, with **no fallback to the wielded item**. An empty slot
  swings for the **bare-handed baseline**: the hand's own damage and its
  own interval, read from the registered hand item rather than assumed.
- **Spell power** = Int/10, fractions included (Round 33). It is the flat
  term of damaging spells; like every damage it is floored once after the
  level scalar (Round 36: spells no longer round before it).
- **Support factor** (Round 36) = `1 + gear Int / 10 / B(L)` on
  pool-derived healing and absorbs, where gear Int is the Intelligence above
  the class's own level growth (`grug_classes.get_support_factor`). Gear
  Intelligence counts as it counts for a Mage's Fireball; without it a
  character heals or absorbs exactly the listed pool share.
- **Timed spell damage** is a separate percentage multiplier on the fully
  assembled hostile spell formula. It never enters spell power and therefore
  never raises healing or absorbs.
- **Damage level scalar** = `P(L) / (8 × B(L))`, where
  `B(L) = round(4 + 0.35L) + (10 + 3(L−1))/10` is the own-level
  baseline sword plus Warrior melee bonus (the Strength term keeps its
  fraction like live damage, Round 34, so same-level damage meets the fit
  exactly). Damage assembles weapon/ability,
  attribute and talent terms before this scalar and floors once at
  settlement; a positive authored damage value settles to at least 1.
  `B(L)` is also "a base hit": talent damage terms (and Charge's 12 %) are
  percentages of it, so they keep their share at every level
  ([skill_trees.md](skill_trees.md) §2.10, Round 35).
- **Support values are already level-derived and are never level-scaled a
  second time.** Heal and Shield are each 25% of `P(L)`; each Mend tick
  is 8%. Multiply that pool share by the support factor, then pass the
  resulting absolute amount unchanged through `scale_player_value` and the
  existing `heal_player`/`add_absorb` seams. Percentage consumables likewise
  derive once from the relevant final pool and bypass the damage scalar.
- **Mana costs** are rounded percentages of the unmodified `P(L)`, minimum 1.
  HP/mana enchants and pool talents therefore change capacity, not spell cost.
- **Weapon item level has exactly one damage axis:** the authored weapon curve
  `round(4 + 0.35 × ilvl)` (then the weapon-family factor). Combat applies no
  second ilvl multiplier. Character level still supplies the shared damage fit.
- **Endgame headroom**: own-level quest/craft gear is the baseline. Boss
  drops and crowned items reach item level **65 / 70** (Kings and the
  General 65, dragons 70, a crowned T6 item 65; round33-plan.md §2.1, §2.5).
  At L60 the 1H weapon values are 25 / 27 / 29 damage for ilvl 60 / 65 / 70.
  Enchant values grow with item level ([item_tiers.md](item_tiers.md) §1.1):
  a fully damage-enchanted level-60 Warrior gains about **+47 % / +57 % /
  +69 %** at item level 60 / 65 / 70, the order of the intended +50–60 %
  ceiling; the Scout's set +49 / +59 / +69 % (Round 36's Dexterity curve)
  and the Priest's heal set match it (item_tiers §1.3). These
  are itemization ceilings, not extra level-curve terms.
- **Higher-mob-level damage malus**: against a mob more than five levels above
  the player, multiply player damage by `max(0.10, 1 − 0.10×(mob level −
  player level − 5))`. It is part of the same final damage multiplication and
  is floored only once with the level scalar
  (`mods/CORE/grug_core/combat.lua:29-65`).
- **Crit** = 5% + 0.05%×Dex, **cap 30%**; a crit deals **×2** damage, and a
  healing crit heals ×2 (Round 33, [item_tiers.md](item_tiers.md) §1.0)
- **Dodge** = 0.1%×Dex, **cap 30%**; a dodge avoids the hit entirely
- Player armor is a numerical **rating** evaluated against the attacker's
  level. It is not itself a percentage; endgame plate and shields remain useful
  against enemies above level 60.
- **How armor resolves** (rating model adopted 2026-09-20): armor rating sums
  over head/chest/legs/feet, an equipped shield, affixes, statuses and
  talents. Which armor a
  character may wear at all is the class rank of
  `inventory_equipment.md` §2.
  - For attacker level `L >= 1`, `K(L) = 20 + 0.5×min(L,60) +
    8.5×max(L−60,0)`. Reduction is
    `min(0.70, rating / (rating + K(L)))`. All raw rating enters that formula;
    only the resulting reduction is capped. Overcap rating against an
    equal-level enemy therefore remains useful against a stronger enemy.
  - The attacker level is the live Grudgelands mob/NPC level, the attacking
    player's character level in PvP, or the immutable attacker level stamped
    onto a projectile. Unattributed and environmental damage has no attacker
    level and bypasses armor.
  - **Bulwark specialization:** learning the mutually exclusive 21-point
    Unbroken capstone multiplies the final aggregated rating by **1.65**. Its
    existing low-HP trigger then adds **33 % of `K(L)` at the Warrior's own
    level as rating after that multiplier** (about 15 at level 50) for 8
    seconds, at most once per 180 seconds. It never raises the 70% cap, so it
    counts most against stronger foes.
  - It applies **only to `reason.type == "punch"`**. There is no
    damage-type system, so that IS the whole definition of "physical":
    fall damage has its own race perk (world.md §7) and drowning, lava
    and starvation are never reduced by a breastplate.
  - **Resolution order** for an ordinary punch in the central hp-change
    modifier: **dodge (cancels the hit entirely) → Grudgelands-mob pressure
    fit → armor → absorb shield.**
    Foreign entities without a Grudgelands level bypass the pressure fit.
    Authoritative swing abilities assemble gear, the class melee attribute and a selected proc,
    then apply the level scalar and mob-level malus once before crit and armor.
    Raw native tool/fist punches cannot initiate player combat against mobs or
    players. Authoritative attacks enter the modifier for dodge and absorb
    using a namespaced `custom_type` that skips
    only the already-performed armor step. Fall damage is separate: a native
    negative fall change of `r` settles as `ceil(max_hp × r / 20)`. Native zero
    stays zero and there is no 100%-of-pool cap. This preserves the engine's
    impact-derived input rather than reconstructing block distance. The Dwarf
    multiplier of 0.8 then rounds up; armor, dodge and the absorb shield never
    apply (see "Environmental damage" below). For hits, a shield therefore always soaks *post*-mitigation
    damage, i.e. shield points are worth full damage rather than pre-armor
    damage.
  - **Rounding: the reduced damage rounds up**, so armor alone can never
    turn a landed hit into 0 — however much of it a tank stacks, the hit
    still costs at least 1 HP.
- **Every equipment slot enforces the item's level requirement**
  min(item level, 60) (Round 33, round33-plan.md §2.2): weapons, the
  Scout's Melee offhand, armour, shields, spellbooks and trinkets alike; T1
  bases require level 1, boss drops at item level 65/70 level 60. The
  definition carries `_grug_req_level`, a dropped, upgraded or crowned stack
  its own `grug_req_level` (`grug_inventory/equipment.lua`, the allow
  callback; `grug_quality`);
  weapon base damage ≈ 4 + 0.35×level (level-60 weapon ≈ 25; itemization
  details → items/crafting design).
- **Consumables use the same `_grug_ilvl` decision helper.** Food, potions and
  elixirs are refused on use below that character level with `Requires level
  N.`, consume nothing, and may not duplicate the comparison or level source.

Anchors (computed):

| Level | Base pool | Warrior HP | Priest HP | Mage HP | Caster mana | Warrior Str |
|------:|----------:|-----------:|----------:|--------:|------------:|------------:|
| 1 | 26 | 31 | 26 | 23 | 26 | 10 |
| 10 | 136 | 163 | 136 | 122 | 136 | 37 |
| 30 | 764 | 917 | 764 | 688 | 764 | 97 |
| 60 | 2696 | 3235 | 2696 | 2426 | 2696 | 187 |

Crit/dodge are server-side rolls in our own damage pipeline (`grug_core`,
mcl_damage-style, unified damage reasons). Flat caps, no
diminishing-returns curves.

Equipment sources and ordinary affixes add before final
consumer caps. Crit and Dodge remain capped at 30%; armor reduction is capped
at 70% after the attacker-level formula. Raw armor rating is never discarded.
The Character UI exposes effective Crit/Dodge, resulting armor rating and
reduction evaluated against the player's own character level. General formulas,
cap rules and multiplier explanations belong to Help, not the Talents header.
This same-level display does not change with the selected target or the
last attacker.
Unbroken does not override the reduction cap.

The Character page shows concise maximum HP and mana, or HP and fixed Rage,
without a pool/armor derivation panel. The HUD bars display current pool values. The Help page owns
the formula prose for pools, Strength, Intelligence, Dexterity and the three
capped stats. Melee bonus, spell power and attributes are formulas there, not
extra Character-page rows.

Active timed statuses are an additional stat source. `grug_core.set_status`
accepts only `hp_pool_percent`, `mana_pool_percent`, `crit_percent`, `armor`
and `spell_damage_percent`; unknown keys reject the whole status. Values sum
across active status ids before the ordinary caps. `armor` means rating, not a
percentage. Replacing the `food` status
therefore replaces its contribution, while a future `elixir` status stacks
with it even on the same key. HP/mana pool percentages use the same base,
class factor and final rounding as talent percentages. Every modifier change,
expiry and clear runs the normal stat refresh: maximum HP is updated and
current HP clamped, the private mana ledger is clamped, and the resource HUD
and open Character page refresh. `spell_damage_percent` is consumed only by
hostile spell damage formulas; unlike Intelligence spell power, it has no
effect on support formulas.

There are no target-race systems: the PvP weapon counter and the Warding
Draught were removed in Round 33.

### Environmental damage, deaths and shore movement

Environmental damage to players scales with the **actual** pool
(`player:get_properties().hp_max`, maximum HP below). Mobs follow the same
idea (Round 28 ruling 6), see "Mobs" at the end of this list.

- A player whose head point is inside an opaque, walkable, non-liquid full
  regular cube takes **floor(5% of maximum HP) per second, minimum 1 HP**.
  Thin doors, panes, shutters, meshes, non-walkable plants, liquids and nodes
  explicitly opting out do not suffocate. The
  character-creation stasis state and players holding the `noclip` privilege
  are exempt.
- **Lava** (Round 24 ruling 24): **ceil(20% of maximum HP) per second**. The
  engine's once-per-second node-damage tick keeps its cadence, but its flat
  `damage_per_second` (8) is replaced, not added to. The engine picks the
  strongest damaging node among the player's body points, so standing in
  several lava nodes is still one hit per second. A full pool therefore lasts
  at most five ticks.
- **Pool-damage nodes** (Round 36): a node in the group `grug_pool_damage`
  hurts by that percent of the maximum HP per second, rounded up, the same
  replacement of the engine's flat tick as lava (`grug_core.node_pool_damage`).
  The rift's void is **11 %**, about nine ticks from a full pool at any level;
  armour never reduces it, the absorb shield soaks it.
- **Drowning** (ruling 24): once the engine has run the breath out (it removes
  one breath every 2 s while the head is in a `drowning` node), the player
  takes **ceil(10% of maximum HP) per second** — at most ten ticks from a full
  pool. The engine's own flat drown hit (every 2 s) is cancelled; Grudgelands
  deals the per-second tick instead, under the engine's own conditions (head
  node with `drowning > 0`, zero breath, not immortal, the `drowning` player
  flag on). Lava also has `drowning`, so a submerged head in lava takes both.
- **Dragon arena hazards** (Round 31, `world.md` §4b): ice water **250** and
  ember fissures **350** damage per second, a fixed amount (not a pool
  share) dealt as node damage once a second; ice water also slows. Armor
  never reduces it and it is never PvP contact; the absorb shield soaks it
  like dragon scorch. The dragon's wrath (500 per second to a fight
  participant outside the arena, `world.md` §4b) takes the same path, but
  the absorb shield never soaks it (`grug_core.bypasses_absorb`).
- Fall damage is the pool conversion in §2 above
  (`ceil(max_hp × r / 20)`, then the Dwarf multiplier).
- **Armor never reduces** fall, lava, drowning or suffocation (armor is
  punch-only, §2). **The absorb shield never absorbs fall, lava or drowning
  damage** (nor the dragon's wrath); other sources (hits, suffocation, authored ground effects such as
  dragon scorch) still consume it. Both shares round up and deal at least 1 HP
  for any positive pool.
- **Mobs** (Round 28 ruling 6): environmental damage to a Grudgelands mob is a
  share of its `hp_max` per environment tick (mobs_redo ticks once per
  second), rounded up and at least 1 HP: **sun 5 %** (every mob with
  `light_damage > 0`, inside its light window), **lava 20 %**, **fire 10 %**,
  **water 10 %** (only mobs that water hurts) and **suffocation 5 %**. Fall
  damage has the player's shape, **`ceil(hp_max × (d − 6) / 20)`** for a fall
  of `d` nodes (after the floor's `fall_damage_add_percent`). The per-mob
  definition values (`light_damage`, `lava_damage`, `fire_damage`,
  `water_damage`, `suffocation`, `fall_damage`) are only on/off switches.
  **Elite and rare** tiers take **half**; the **boss tier (dragons), the
  kings and the PvP fortress Generals are immune**. Other `damage_per_second` nodes and `air_damage` keep
  mobs_redo's flat amounts. *Why:* flat amounts made high-level mobs nearly
  immortal (an L30 zombie, 764 HP, needed 6.4 minutes in the sun; now 20 s).
  Implementation: `grug_mobs/env_damage.lua`, called from `mobs/api.lua`
  `do_env_damage()` and `falling()`.
- Every player death sends exactly **one** short English line to all players.
  The selected template distinguishes fall, drowning, lava/fire node damage,
  suffocation, a mob punch (using the mob's display name), a player punch
  (using the player name) and an unattributed fallback.
  A projectile (arrow, fireball, the bog witch's hex bottle, dragon breath)
  names its shooter; when the shooter is gone it uses the projectile's own
  readable label ("an arrow", "a fireball"). No entity's technical name ever
  appears; an entity without a readable name is "a hostile creature". Boss
  encounters credit a projectile death to its shooter the same way
  (Round 28 ruling 17).
- **Shore-height ruling (2026-09-17):** shore exits have zero vertical rise:
  the first cardinal dry-land surface beside exposed surface water is exactly
  level with the water surface. Road bridges, decks and fords are
  functional-edge exceptions and keep their own road grade. The zero-rise rule
  is required because Luanti forces a swimming, non-grounded player to **0.2**
  effective stepheight regardless of the property
  (`reference_projects/luanti/src/client/localplayer.cpp:322`).

### Melee timing and aim authority (shipped 2026-08-10, WP39)

Swing ability timing, aim and skill charge timing are separate. The equipped
weapon supplies damage and `full_punch_interval`; the current crosshair ray
supplies the target; each selected swing skill supplies only its optional
charged effect. Enemy target memory is UI state and never supplies aim.

- **Skill items keep native interaction, not native combat damage.** All
  skills preserve native empty-hand digging and first-person LMB animation.
  Node/object press events supplement sampled controls; a fresh press may
  pick up one visible drop within 4 m. Native enemy punch packets are input
  only and cannot create damage, rage, threat, wear or procs by themselves.
  Dropped items never block the combat ray: a hostile behind loot is aimed
  at, struck and shown red as if the loot were not there.
  `classes.md` §2b owns current input arbitration and accepted engine limits.
- **One server-authoritative clock owns all swing-ability damage.** LMB held
  with a swing selected allows attempts; it never creates partial or fast
  ability damage. The combat pass has a 0.05 s accumulator threshold but runs
  only on an actual engine step (currently often 0.09 s), so it is not a
  frame-perfect client callback. Early clicks do not move the due time, and
  hold/click-spam have identical maximum DPS. At most one attack starts per
  pass. Normal server-step lateness is carried phase-faithfully into the next
  interval, capped at 0.1 s and half the FPI; lag never replays a backlog.
- **Readiness waits for the current ray.** Once the interval expires, the
  weapon remains ready. While LMB stays held, a due pass raycasts from the
  current server eye position along the current look direction to the selected
  swing range (**3 m**). The first visible combat result must be a live
  hostile mob/player; walkable nodes block it. No object, a friendly object, a
  blocker or out-of-range aim is an **aim miss**: no damage/rage/threat/cost/
  charge/effect and, crucially, no clock advance. The ready attack fires on the
  first pass that observes a valid hostile under the crosshair.
- **A valid attack consumes the interval before outcome resolution.** Once the
  server has a valid ray target, it advances the clock and starts one full
  claim-once punch. A later evade, immunity, PvP refusal, dodge, full absorb,
  `do_punch` or CMI rejection is a **combat miss**: it still consumes the weapon
  interval, but keeps the existing no-resource/no-charge/no-effect/no-rage
  result. This prevents a dodging or invulnerable target from being retried on
  every server step.
- **Enemy target memory is presentation only.** A pointed/attempted/accepted
  hostile may refresh the 8 s Target Frame slot. No melee or hostile cast reads
  it back as a target. Moving the crosshair changes the next possible hostile
  immediately; looking away stops damage immediately. Owner lifecycle clears
  enemy and ally memory, but neither memory participates in the weapon clock.
- **The ready signal is a reticle transition, not item wear.** With a swing
  selected, one small gold ring overlays the normal crosshair exactly while the
  weapon is ready. It is absent while the interval runs and for non-swing
  items. It shows weapon readiness only, not target validity or proc charge;
  target validity is the separate crosshair state overlay (`classes.md` §2b). A
  valid attack hides it immediately and expiry shows it once; an aim miss
  leaves it visible. There is no smooth progress animation and no periodic
  inventory rewrite.
- **The melee slot is the sole swing source**: the Weapon slot, or the
  Scout's Melee offhand (Round 28 ruling 25; `grug_core.get_melee_weapon`).
  Ability stacks expose zero
  native combat damage while retaining native hand digging and animation. Their
  charge wear is not equipment wear. The server builds actual attacks from the
  equipped usable melee weapon; cosmetic getters separately retain broken equipment.
  Selected-skill/fallback scheduling and click arbitration are defined in
  `classes.md` §2b. Native tools/fists are not a second combat stream.
- **One accepted full swing resolves once.** Against players the order is
  **slot weapon + melee attribute (Scout Dexterity, otherwise Strength) → selected proc replacement → level scalar (plus
  mob-level malus when the target is a mob) → one crit → armor → integer
  damage → one dodge → one absorb →
  HP**. mobs_redo commits the proc
  only after `do_punch` and CMI accept. Mighty Blow remains exactly
  `floor(weapon × 1.5) + melee bonus` before crit; Hamstring is the ordinary
  full swing plus its 50% slow, paid/applied only after HP damage lands.
- **Authoritative entry is claim-once.** One opaque token identifies the exact
  attacker and ray-selected target. The matching mob/PvP entry claims it once;
  callback-triggered reentrant punches on the same or another target are
  suppressed before damage/proc work.
- **Accepted mob side effects share the same boundary.** Provocation, loot tag,
  combat/threat/rage callbacks, crit visual and lethal rare/XP credit run only
  after `do_punch` and CMI accept, immediately before health subtraction.
### Hostile casts and projectiles (shipped with WP39)

- **Hostile direct casts require current aim.** Charge, Taunt and Smite accept
  only a currently pointed valid hostile within their individual range and a
  server line-of-sight check. Enemy target memory is never a fallback. Failure
  to acquire a target spends no resource and arms no cooldown. Friendly
  heal/shield casts resolve through currently pointed valid in-range visible
  ally → self, never ally memory. Looking into empty space selects self
  (user ruling 2026-09-24).
- **All targeted projectiles lock at actual release (Round 17).** The current
  server-validated crosshair hostile must be in range and initially visible;
  no stale enemy memory and no valid target means no shot or mana/ammo payment.
  Mob/boss/guard missiles lock their valid attack target under the same initial
  range/line-of-sight rule. Smite stays immediate; area skills stay area skills.
- Fireball keeps **6% base mana**, **1.0 s server cast cadence**, **20 m initial
  range**, **20 m/s nominal speed**, baseline weapon damage + spell power and
  its existing talent effects. Scout arrows retain bounded draw and ammo rules:
  a full draw takes the bow's 2.5 s, shortened only by Fletching and the
  bow's own attack-speed affix (not the rest of the equipment), and Loose deals
  (bow damage + Dexterity ranged bonus + Strong Draw) × (0.2 + 2.05 f²) for
  draw fraction f — ×0.2 on a tap, ×0.7125 at half, ×2.25 at full draw (user
  ruling 2026-09-28, follow-up) — before Twin
  Shot's second-arrow percentage and Longshot's +11 % of a base hit, all
  floored once after the level scalar (Round 35). Loose's nominal arrow
  speed is linear in f, 40 m/s on a tap to 55 m/s at full draw. Snare Shot and
  Pinning Shot fire at ×1 and 40 m/s.
- **Flight is homing with a launch-time duration** derived from initial
  distance/speed. The visual converges on the moving target. Later movement out
  of range, intervening actors or terrain do not intercept it. Cover protects
  before launch only. No ballistic obstacle navigation or endless pursuit.
- **Damage settles once at impact**, through existing armor, dodge, absorb,
  immunity, PvP/evade, attribution, threat and action/wear rules. Geometric
  arrival does not guarantee HP loss. Lost/dead/unloaded/teleported targets
  cancel rather than retarget; respawned/replacement identities cannot be hit.
- Active shots remain bounded and nonpersistent. Every terminal/failure path
  releases its reservation exactly once. Reconnect/respawn cannot inherit old
  session shots. Scout batch creation reserves all siblings before atomic ammo
  payment and shares one action receipt for equipment wear.

### Combat diagnostics (shipped with WP39)

- `/combatdebug on|off` is a permanent, server/admin-only, per-player runtime
  diagnostic. It automatically clears on leave and never persists.
- Disabled means no extra raycast, globalstep, log formatting or particle work;
  existing combat sites perform only the enabled-state branch. Enabled output
  is rate-limited and records input/readiness, ray result and blocker, target/
  range/hostility, attack outcome, proc settlement, and projectile spawn/hit/
  expiry. It is suitable for `debug.txt`, not a player-facing combat meter.

Balance note: the swing-ability DPS baseline remains one full slot-fed swing
per weapon interval while a continuously tracked hostile stays in the current
ray. Aim gaps may delay a ready swing but never bank more than one. Ordinary
tools and fists provide no parallel player-damage path. Contextual input does
not alter the melee damage tables.

### PvP eligibility and flag

Geographic PvP (Round 31, `grug_pvp`; all PvP rules in [pvp.md](pvp.md),
the combat seams here). Two enemy players can harm each
other only while **both are flagged**; no attack, heal or area effect changes
anyone's flag. A player is flagged while standing in contested ground (the
31–60 zones, both islands, every land column at **y = −501 and below**,
depth tier T4 and deeper) or in
enemy territory, for **60 s** after pressing "Flag me for PvP", and for
**60 s** after the last PvP contact. Only the own faction's peaceful territory
clears the location flag, once those timers have run out; deep ocean and the
dragon channels keep the last value. Death clears all three.

- The gate sits in `valid_target` (swings, casts, area effects, projectile
  launch), in the crosshair ray (an unflagged enemy is a blocker with a
  neutral crosshair, reason `protected`) and at impact (`deal_ability_damage`
  and the swing punch). Nothing is paid for a refused target.
- Support is one-way: an unflagged helper cannot cast Heal, Shield or Mend
  on a flagged ally (Heal's splash included); the cast is refused with a
  line and costs nothing (no fallback to the caster). A flagged helper may
  support anyone of the own faction.
- **PvP contact** is hostile player damage that lands (HP lost or absorb
  consumed) for dealer and receiver, and effective support cast on an ally in
  PvP combat for the helper (effects over time count at application only).
  Fighting NPCs is never PvP contact.
- Leaving the game in PvP combat (contact within 10 s) is death: the enemy
  players who landed damage in the last 15 s get the kill at once, and the
  character starts dead at the next join. A server shutdown is not a logout.

## 3. Mobs

Normal tier at level L:

- **HP** = `20 + 5×L + 0.66×L²` · **Damage/hit** =
  `2 + 0.3×L + 0.005×L²`, rounded to one decimal · **XP** = one kill
  equivalent `M(L) = 25 + 5×L` (Round 28 ruling 30, `grug_xp.mob_xp`;
  `progression.md` "Kill XP"). There is no other kill multiplier (the Round
  16 ×1.5 is gone) and no race bonus on kill XP.
- mobs_redo armor: normal 100, **elite 80 (×3 HP, ×1.8 dmg, ×4 XP)**,
  **rare patrol 70 (×5 HP, ×2.2 dmg, ×6 XP)**, and the registered
  **boss tier (18,000 HP flat; normal damage, XP and armor; no telegraph)**.
  No mob uses the boss tier before
  the round-6 king/dragon content. The single implementation table and formula
  are the `TIERS` table and `grug_mobs.stats_for` in
  `mods/ENTITIES/grug_mobs/levels.lua`.
- **Three mob classes** (decided 2026-08-08, full rule in
  `biomes_mobs.md` §3.0): **critters** (small animals — always level 1,
  always **1 HP**, **0 XP**, **food-only drops**, **no fall damage**,
  never elite/rare; a `critter` tier in the level engine, the second
  documented exception to "stats derived, never hand-rolled" after the
  Kraken), **passive prey** (large grazers — ordinary levels, HP, XP and
  leather drops, but they never attack on sight and only fight back when
  attacked) and **enemies** (everything else). Note the class is defined by
  size and loot role, NOT by speed — the speed bullet below is a
  consequence, not the definition. The tier is what owns all four critter
  properties; a mob def never hand-writes any of them (§3.0 for the field
  name and the one engine trap).
- **Speed**: every melee attacker has `run_velocity` **at least 4.6** against
  the player's 4.0, including retaliating passive prey, the Zombie and the
  Stone/Mesa Golem. The Bandit Archer and two Skeleton ranged families remain
  **4.0**; harmless critters that never attack remain **3.4**. The Bog Ooze
  remains **2.6** because its roster role is explicitly the one slow tank. The
  deep-sea Kraken Guard runs **10** inside a deep-ocean column and **5**
  elsewhere (`world.md` §2b). The ordinary 4.6 band keeps
  the Swiftness Draught below it (4.0 × 1.10 = 4.4), and continues to feed the
  pursuit policy of §4. Current definition
  sites for the changed families: `grug_mobs/stag.lua:21`, `ram.lua:26`, `zebra.lua:20`,
  `carrion_crow.lua:54`, `zombie.lua:29` and `golem.lua:87`; the exceptions
  are `bandit_archer.lua:81`, `skeleton_archer.lua:88`,
  `skeleton_raider.lua:52`, `bog_ooze.lua:38` and `kraken.lua`.
- **Roaming pace (Round 24):** every mob roams at a calm walk and uses its
  full speed only in combat. mobs_redo moves an idle mob at `walk_velocity`
  and a fighting one at `run_velocity`, so `walk_velocity` is at most
  **2.5** (`grug_mobs.CALM_WALK_MAX`, checked at registration; hand-set
  encounter actors such as the Kraken, the dragons and the royals keep their
  bespoke tuning). The ranged families (Bandit Archer, Poacher, Skeleton
  Archer, Skeleton Raider, Frost Stray) roam at **1** and keep **4.0** for the
  whole fight: they opt out of the bound-actor soft de-aggro, the one combat
  reader of `walk_velocity` besides the wedged-path crawl that `dogshoot`
  never enters. Flying mobs also climb and dive toward a target at
  `walk_velocity`, so the Glowwing (walk 2) changes height at 2 m/s in
  combat (accepted).
- **Reach**: player swing abilities (Strike, Mighty Blow and Hamstring) use
  **3 m**, and every ordinary explicit mob reach is **3 m**. The Kraken keeps
  its model-specific **4 m** and non-combatant villagers keep 0. The mobs_redo
  contact run remains `reach × 0.6`, hence **1.8 m** for an ordinary attacker.
  Telegraphs continue to derive their geometry from the live reach; the
  ordinary elite/rare cone therefore reaches **4.5 m**
  (`grug_abilities/kits.lua:308,379,417`; `mobs/api.lua:2709-2838`;
  `grug_mobs/telegraph.lua:93,181`). The explicit ordinary reach sites are
  `grug_mobs/bandit.lua:61`, `bear.lua:23`, `boar.lua:10`,
  `boar_variants.lua:22`, `bog_ooze.lua:23`, `crocodile.lua:43`,
  `eagle.lua:39`, `golem.lua:56`, `guard.lua:180`, `hyena.lua:21`,
  `jungle_ape.lua:27`, `jungle_lynx.lua:30`, `mirefolk.lua:28`,
  `panther.lua:25`, `serpent.lua:23`, `skeleton_archer.lua:55`,
  `skeleton_raider.lua:27`, `spider.lua:19`, `wolf.lua:19` and
  `zombie.lua:21`; the exceptions are `kraken.lua:34` and
  `start_villagers.lua:936`.
- **Knockback: player melee swings only** (Round 28 ruling 7). Strike and the
  melee swing skills (Mighty Blow, Hamstring, Opening: every authoritative
  swing) push a normal mob back by **`c × swing interval`** with
  **c = 0.25 m per second** (`grug_mobs.KNOCKBACK_PER_SECOND`, one constant to
  tune by feel): dagger 0.7 s → 0.175 m, sword 1.0 s → 0.25 m, battle axe
  1.4 s → 0.35 m. The interval is the weapon's actual interval after the
  attack-speed affix, so knockback per second is the same for every weapon
  and weapon tier does not matter. It is a horizontal **position
  displacement** along attacker → mob (a velocity would be overwritten by the
  next AI step), applied only when the mob's collision box fits at the
  destination (no unknown or damaging node, and no walkable node reaching
  above its feet: snow dust or the slab it stands on are ground, a slab or
  stair beside a mob on full blocks is an obstacle) and the mob is pushed
  only when the node under its feet there is walkable (at most half a node
  lower, e.g. off a slab); otherwise there is no knockback. Mobs are
  therefore never pushed into walls or over ledges. A swimmer on the sea bed
  or a flier just above the ground can be pushed; one in open water or air
  (nothing walkable under its feet) cannot. Only the
  **normal and critter** tiers are pushed: no knockback for elite, rare, boss
  or king, nor for a `knock_back = false` mob (the Kraken). Casts, Charge,
  arrows, mob hits and every other punch carry no implicit knockback; several
  players' knockback adds up (accepted). The backpedal abuse stays
  impossible: mobs close at 0.6 m/s (4.6 vs 4.0), well above 0.25 m/s.
  A future limited/cooldown knockback skill displaces through
  `grug_mobs.displace_mob` (the same fit test); the old
  `damage_groups.knockback` velocity override no longer survives a player
  hit, because without the hit pause the next AI step overwrites the
  velocity. Implementation: `grug_mobs/separation.lua`, called from
  `mobs/api.lua` `on_punch`.
- **Actors do not collide with other objects.** Mobs, NPCs and players use
  `collide_with_objects = false`; terrain collision is unchanged. This removes
  actor-on-actor climbing (`grug_core/init.lua:70`). The visible overlap is
  limited by **separation** (Round 28 ruling 5, kept deliberately simple): an
  engaged ground melee mob does not enter its target's own column — the
  contact run stops while a visible target is within the two collision radii
  plus 0.5 m horizontally, and once a second a mob found inside that column
  (radii sum) is moved out of it — and engaged mobs whose bodies overlap
  drift apart sideways (perpendicular to the line to their own target), at
  most 0.5 m per second. The same fit test as knockback applies; no
  pathfinding. Implementation: `grug_mobs/separation.lua`, called from the
  dogfight branch of `mobs/api.lua` `do_states()`.
- **The 4.6 > 4.0 inequality holds except for named, long-cooldown skills**
  (`skill_trees.md` §5, ruling 10 of 2026-09-16): "skills may explicitly
  **break the base inequalities** (mob 4.4 > player 4.0, stat caps, roots)…
  The rule: **the bigger the break, the stronger the limit**, usually cooldown
  or duration." *(The ruling is quoted verbatim and says 4.4 because the band
  moved to 4.6 on the same day, in ruling 2 above; the numbers derived from it
  below are stated against the shipped 4.6.)* The first one is the Scout's
  **Sprint** — **+50 % for 10 s on a 300 s cooldown** (user amendment 2026-09-20,
  `scout.md` §2) — which puts a sprinting player at **6.0** against 4.6 for
  ten seconds in every five minutes. Nothing permanent or cheap is covered:
  the Swiftness Draught stays at **+10 % for 5 s**
  (4.0 × 1.10 = 4.4 < 4.6, `items_crafting.md` §3.6/§10 P4) and a
  mount pays for its permanent 6.4–12 nodes/s with the damage dismount
  (`mounts.md` §3.1).
- **View range follows the attack type** (decided 2026-09-16, user ruling 3):
  a **`dogshoot` family sees 16 m**, a **melee family 10–14 m by habitat**.
  The full per-mob table and the habitat reasons are `biomes_mobs.md` §3.1;
  **16 is the ceiling for a land mob**. Acquisition range remains separate
  from Round 18 damage-sustained chase persistence. The
  same ruling asks for more ranged families: the first is the **Bandit
  Archer**, one slot in three of the existing bandit camp, which takes the
  registered ranged roster from **4 of 43 to 5 of 44** and is the first ranged
  enemy a player meets in the inner ring.
- Pacing (Round 28 ruling 31): a level needs `k(L) = 8 + 0.29·(L − 1)`
  same-level normal kills' worth of XP (8 at level 1, about 25 at level 59;
  82 kill equivalents to level 10, 968 to level 60); quest rewards and
  gathering XP (ore, gem and fish) carry part of it (`progression.md` "XP
  units and level curve", "Gathering XP").
- **Gray kills award no XP**: a mob at level ≤ killer level − 10 gives 0
  XP (kills trivial-mob farming).
- **XP level cap**: calculate each recipient's formula with effective mob
  level `min(actual mob level, player level + 5)`. The gray test still reads
  the actual mob level (`grug_mobs.kill_xp` in
  `mods/ENTITIES/grug_mobs/levels.lua`, settlement `grug_mobs.award_kill_xp`
  in `init.lua`).
- **XP participation and split**: a participant dealt accepted damage to the
  mob or delivered effective healing to an existing participant. At death,
  only participants who are online and within 40 m count; divide the award by
  that eligible count after calculating the cap and gray rule per recipient. A
  player receives no XP from a mob of their own faction
  (`mods/ENTITIES/grug_mobs/init.lua:87-215`). Settlement occurs once at the
  shared mobs_redo death boundary regardless of whether a player, NPC, mob or
  the environment dealt the final damage, without replacing the mob's death
  callback, animation or smoke fallback (`mods/ENTITIES/mobs/api.lua:887-975`).
- **Death never removes XP** (Round 18), regardless of level or cause.
- **Player-tag drop rule** (decided 2026-08-06, WP6): a mob drops loot
  only if a player damaged it (`do_punch` sets a tag) — **the tag expires after ~60 s
  without further player contact** (no "seeding" a wolf and letting
  guards farm it). Faction NPCs drop only when killed by ENEMY players
  (PvP); NPC-vs-mob kills never drop. Kills LotT's armor-litter
  problem. What drops is the mob's family table for its level band where
  one exists, else its static list (Round 28 ruling 36, `biomes_mobs.md`
  "Round 28 sub-types and loot by band").
- **Bounded-actor soft de-aggro:** where the retained encounter policy enables
  it, beyond ~25 m a chasing actor drops to walk speed. Round 18 ordinary
  damage-sustained world mobs do not use this slowdown or distance give-up;
  their incoming-damage clock plus current-target horizontal movement govern
  disengagement (Round 19 follow-up).
- **Readability rules for mobs** (decided 2026-08-06, shipped with WP6):
  elites/rares signal via **scale + tint** — elite `visual_size` ×1.4
  (Round 28 ruling 9; model, collision and selection box scale together),
  gold `^[colorize:#ffa800:80`, nametag prefix `Elite `; rare ×2,
  violet `#a64dff:90`, nametag prefix `★ ` — plus the `!! ` prefix while
  a wind-up runs. **Elites AND rares telegraph** (both tiers, no def
  opt-in): 2 s wind-up (stop, `!!` nametag, particle burst; a sound only
  where the mob's voice family names one — the user keeps it to humanoid
  specials, and the dragons growl at their own wind-ups) then a ×3 damage hit into a
  **90° frontal cone** of **reach + 1.5 m** (normally **4.5 m**) that requires **line of
  sight** — stepping aside, out of range or behind cover is a clean miss.
  Cadence: the first wind-up needs **4 s of MELEE engagement** (a fight
  always opens with normal swings, and a ranged elite at distance never
  winds up into empty air), afterwards one every **10 s**. The same
  mechanic later scales up to bosses. **One behavior
  verb per mob family** (boars charge, wolves hunt in packs and flee
  low to return with friends, zombies pursue while damage sustains the fight, skeleton archers
  `dogshoot`). **Named rares broadcast** their spawn faction-wide
  ("Grimtusk has been sighted…") — a meeting point for a low-population
  server.
- WP1 retune (**done with WP6**): boar = L1 (HP 26, dmg 2.3, XP 10 then,
  30 since Round 28), zombie = L3 (HP 41, dmg 2.9, XP 30 then, 40 since
  Round 28), and both now use the 4.6 melee band
  (`run_velocity` was 3.4/2.6 at WP6, raised to 4.4/4.2 with the soft
  de-aggro, then to the band's 4.6 in rounds 4 and 5).
- **Level floors** (`_grug_min_level`): a mob whose family belongs to a
  later zone keeps its floor even where the field reads lower — zombie 3,
  jungle lynx 4 (band 2 of Kapok, Round 24), wolf/hyena 10, guard 20. The floor is also the fallback
  where the level field has no value. An area or leader level (Round 28)
  replaces floor and field.
- **Guard levels** come from the separate `grug_core.guard_level_at`
  field (world.md §1) with its own cap of **70** (the mob axis stays
  1–60), and a guard at level **≥ 60 is promoted to elite
  automatically**. Its T3 positional base is `nil` in every exterior class,
  including shelf. Inside a capital's protected city (its hard-protection x/z
  mask, `world_zones.md` §12) it is exactly 60 only inside the capital's
  protected volume (from the capital anchor's placement height − 100 upward,
  Round 24 ruling 30); below that floor and at all other non-exterior
  positions it is
  `min(70, max(20, surface_level_at(pos)))`. It does not apply the mob depth
  floor. WP13 may later raise that non-nil generic base outside the shallow
  capital hard volume, capped at 70, but may never lower it; exterior nil
  remains nil and permits no guard post. Ordinary and royal guards inside
  remain exactly 60. `_grug_fixed_level` is the sole explicit fixed-entity
  mechanism and bypasses positional and post-role fields only for a deliberately
  designed fixed entity. Its implemented uses are the Kraken Guard (an elite)
  at L70 and every WP13 king at L65. No second king-specific fixed-level path exists.

| Mob level | HP | Dmg/hit | Kill XP (normal, solo) | Elite / rare XP |
|-----------|----|---------|-----------------------:|----------------:|
| 1 | 26 | 2.3 | 30 | 120 / 180 |
| 10 | 136 | 5.5 | 75 | 300 / 450 |
| 30 | 764 | 15.5 | 175 | 700 / 1050 |
| 60 | 2696 | 38.0 | 325 | 1300 / 1950 |

### Same-level TTK check

Deterministic non-crit benchmark: the Warrior uses that level's ladder sword
at a normalized 1.0 s interval, Fireball uses its authoritative 1.0 s cast
interval, and Smite uses its 2.0 s cooldown. Elite armor 80 is included. Incoming normal
mob pressure uses one integer-settled hit per second before dodge, armor,
absorb or healing. `mob_pressure_scale` targets
`max(1, floor(P(L)/27))` damage for that hit; mob HP and raw damage curves do
not change.

The mandatory baseline bands are normal TTK **8–12 s** (Priest **12–16 s**),
elite TTK **3–4 times** its normal row, and raw normal-mob TTD **25–30 s**.
The KAT allows ±10% around those bands to absorb whole-hit rounding.

| L | Class | Effective hit | Normal TTK | Elite TTK | Raw TTD |
|---:|---|---:|---:|---:|---:|
| 1 | Warrior / Mage / Priest | 3 / 3 / 5 | 9 / 9 / 12 | 39 / 39 / 40 | 31 / 23 / 26 |
| 10 | Warrior / Mage / Priest | 17 / 17 / 23 | 8 / 8 / 12 | 32 / 32 / 46 | 33 / 25 / 28 |
| 20 | Warrior / Mage / Priest | 48 / 48 / 64 | 8 / 8 / 12 | 31 / 31 / 46 | 33 / 25 / 28 |
| 40 | Warrior / Mage / Priest | 159 / 159 / 207 | 9 / 9 / 14 | 31 / 31 / 48 | 33 / 25 / 28 |
| 60 | Warrior / Mage / Priest | 337 / 337 / 438 | 8 / 8 / 14 | 31 / 31 / 48 | 33 / 25 / 28 |

All rows are inside the KAT bands. Warrior TTD uses the allowed upper edge;
Mage L1 uses the allowed lower region. This is deliberate class durability,
not level drift: the L20 and L60 baseline feel remains the same.

### Position → mob level

`grug_zones.surface_mob_level_at(x, z)` supplies the authored surface level;
`grug_core.mob_level_at(pos)` applies that surface result together with the
depth and exterior-class rules and returns the final level directly. Target
surface geometry (`world_zones.md` §2, Round 22): the owning zone supplies
the level. Inside each zone its published range rises in three sub-ranges
from the home-facing side toward the faction front; Battlegrounds zones rise
from both sides toward the middle of the band, and both level-60 summits stay
flat.
Within 100 horizontal nodes of every authored start anchor the surface level
is 1, from 101 through 150 nodes it is 2, and beyond 150 nodes the zone's
level field applies; in the six starting zones the start-zone gradient
applies instead (band 1 behind the start, rising toward the front, band 3
only shortly before the front border; `world_zones.md` §2, Round 24). It is
the same surface level for spawns and for the mapgen's level-banded
content, except in a zone with a spawn recipe (Round 28 ruling 34, Lane
S1, [spawn_regions.md](spawn_regions.md)): there a surface mob takes a level
rolled in its role's range of its spawn region and a named leader the top of
its region, and the gameplay surface level (`grug_core.mob_level_at`: mob
levels, the fishing band, bandit loot) is the region's level. The field
itself keeps serving every zone without a recipe, the depth axis, guards and
the mapgen. Capital city zones contain no ambient hostile mobs while they
have no recipe; with one they spawn outside the protected city only
(ruling 3). Guards use
the separate positional `guard_level_at` contract above; the depth formula
does not affect that guard base. Every exterior class has no surface level.
Shelf `mob_level_at` is nil at normalized y >= 0 and uses the depth term alone
at normalized y < 0; deep ocean and immutable channels have no ordinary mob-
level result. The fixed level-70 elite Kraken is the explicit deep-ocean exception
and bypasses the resolver. **Depth axis**
(decided 2026-08-06,
WP6, rate recalibrated 2026-08-08): overworld caves scale with depth —
`mob_level_at = max(surface_level(x,z), depth_level(y))`, **3 levels per
50 nodes** below y=0, capped at 60; ore tiers follow the same depth
axis, so mining deep is the alternative progression path to travelling
out. The tier-rock starts are exact: T3 rock at **−301**, T4 at **−501**,
T5 at **−701** and T6 at **−1001** (`items_crafting.md` §3.0.4). The level
anchors therefore fall on the last node before two transitions: **−500 = level
30** is the last T3 node before T4, and **−1000 = level 60** is the last T5
node before T6 and the cap. What the rate really says is where depth **overtakes** the surface
field: at `y = −surface_level / 0.06`, e.g. **−83** in a level-5 start
area, **−417** in a level-25 heartland area and **−750** in a level-45 front
area — in the beginner zone depth takes over almost immediately, and a
level-60 surface zone meets the depth cap exactly at −1000.
(For normalized `y < 0`, the exact standard term is
`depth_level(y) = min(60, max(1, round_half_away_from_zero(-3*y/50)))`.)
**R7.6 underground verification (2026-09-18):** this existing term already is
the required integer three-step pattern, so no underground arithmetic changes.
After the clamped first interval, every complete uncapped 50-node window has
exactly three integer threshold crossings; the first 50 nodes occupy levels
1, 2 and 3, and the level-60 cap truncates only depths past the endpoint. The
R7.6 KAT pins every y from -1 through -1000 and the three crossings in each
complete 50-node window from depth 50 onward. There is no smooth depth ramp.
(The Nether is NOT part of this axis — its y-band is unreachable by digging,
portals only.) The retired WP18 radial field is historical and has no current
level authority.

The political boundary follows the tool tiers, not the level formula: y = −500
is the last T3 node, y = −501 begins contested T4 (Round 31; it was T5 from
−701), y = −701 begins T5 and y = −1001 begins T6. The surface column's race
region continues to select deep regional resources, but never changes the
universal PvP/terrain rule below −500.

**Depth buys frequency, not stats.** Past the level-60 cap the axis
keeps going as *spawn pressure*: a player-centric arrival pulse whose
rate grows with depth, so deep mining happens under permanent
interruption rather than against bigger numbers. That is a spawn rule
and it lives in `biomes_mobs.md` §4.1 — curve, cap and roster in one
place.

## 4. Threat (aggro) system

A core combat pillar — mobs choose targets by **threat**, not proximity:

- threat += damage dealt.
- Healing adds **0.5×healing** as threat to all mobs in combat with the
  group (within 30 m) — the healer pulls aggro if the tank sleeps. Until
  WP20 ships real parties, "the group" is the MVP pair **healer + heal
  target**: the threat lands on every mob within 30 m that is currently
  fighting one of those two.
- Tank abilities generate **×3 threat**; **taunt** sets threat to
  top×1.1 and forces the mob onto the tank for 3 s (8 s cooldown).
- A mob switches targets only when a rival exceeds **120%** of the
  current target's threat (hysteresis against ping-pong). A threat entry
  is only a switch candidate while its player is connected, alive and
  within the ordinary **threat candidate radius of 40 m**; active ambient
  pursuit follows the Round 18 exception below. A
  stale entry from someone who left the fight can never pull the mob.
- **Ambient pursuit (Round 18):** ordinary free-roaming combat mobs, including
  Zombies and their ambient variants, use a 15-second clock since incoming
  effective player/guard damage. Initial aggro seeds the clock. Outgoing hits,
  taunt and threat-only updates do not refresh it. The Round 19 follow-up
  requires noticeable horizontal movement of the current live target before
  an expired clock triggers return. Standing still never refreshes the clock.
  No chase-origin distance or
  ordinary LOS-patience timeout ends a damage-sustained fight; a valid available
  target remains required. No distant terrain is loaded to keep a target alive.
- **Encounter-owned exceptions:** bosses/retinue, fixed guards, camp-owned mobs,
  location-bound rares and the bespoke ocean Kraken retain their previous
  home/post/encounter bounds and lifecycle. The old 40 m chase-origin drag,
  15-second contact and 45 m give-up rules apply only where these actors already
  used them; explicit encounter overrides remain authoritative.
- **Evade:** reset clears threat, target and drop tag and heals the mob.
  Ambient (free, damage-pursuit) mobs reset **inside their 32-node wander
  radius** (`grug_mobs.WANDER_RADIUS`, below) only do that: no run, no
  untouchable state, they may idle there anyway (Round 36 §2.14.2). Reset
  **outside** it they run back visibly at 1.5× run speed, untouchable and
  without reacquiring targets, and are a normal mob again as soon as they are
  back inside the wander radius. A blocked return teleports home after about
  40 seconds. Bound actors (camp members, guards, rares, bosses, royals) keep
  their prior return threshold, their leash radius (25 for a camp member, 30
  for a guard, 40 by default), and end the run within about four nodes of
  home; patrollers and dragons never evade.
  Incoming NPC damage does not create player reward credit.
- **Evading feedback:** an evading mob is no target. The crosshair stays
  neutral on it, a press does not lock or hit it, and a fresh press, or a
  player's projectile or cast that still reaches it, shows a short
  "Evading" in the flash line, at most once per 1.5 s per player (Round 36
  §2.14.1, `grug_mobs.evade_notice`; classes.md §2b).
- **Mobs in water** (Round 34): every mob that floats and does not fly swims.
  Idle roaming on land keeps treating water as a drop; in combat (attacking,
  fleeing, the evade run home) a mob follows its target into harmless water
  and crosses it, straight at the target (no route search). Lava and every
  damaging liquid stay a boundary, also for an immune mob; water that hurts a
  mob stays one for it. A swimming mob climbs onto a bank up to one node
  above the water; a higher wall stays a wall (the evade keeps its 40-second
  teleport). A mob idle in water (a fight that ended mid-lake, a reset close
  to home) swims toward its home once a second until it stands on land.
  Leashes, contact timeouts and arena edges are unchanged. Fliers,
  the water swimmers (Kraken, Reed Angelfish) and the dragons and their
  whelps keep their own movement (`mobs/api.lua` `grug_may_wade`,
  `grug_mobs/aggro.lua` `shore_check`).
- **Catching up must be enough to hit** (decided 2026-08-13): a mob that has
  closed to within its `reach` lands its attacks on a target fleeing at full
  speed. The **attack cadence therefore runs during the chase**, not only
  while the target is inside reach; the only condition an attack still
  carries is being in reach at the moment the cadence is due. Fleeing costs
  HP — it is not a free escape from a fight already lost.
  **Shipped 2026-09-16** as the vendored mob-pressure cadence patch; the
  2026-09-17 close-obstacle pass completes it. `punch_timer` advances at the
  top of the dogfight branch and caps the backlog at one; the in-reach branch
  runs to `reach × 0.6` while retaining the cliff guard; the final punch
  claims the timer only after line of sight succeeds. A blocked ready swing
  therefore stays banked (`mobs/api.lua:2491-2819`;
  `mobs/grug_obstacle.lua:4-237`).
- **Hits never stall a mob's attack clock** (Round 28 ruling 8). No player
  hit — melee swing, arrow or ability, with or without knockback — pauses the
  mob. mobs_redo set a 0.25 s pause on every landed hit, which skipped the
  attack state and therefore the punch timer; several players hitting one mob
  stretched its attack interval a lot. Mob-vs-mob hits keep that pause.
- **Close cover triggers navigation** (decided 2026-09-17). If a ground melee
  mob has spent about **1 s** inside reach without line of sight, it starts the
  existing bounded A* search despite already being close. It does not abandon
  that path merely because `dist < reach` while LOS remains blocked. If A*
  returns nil, it sidesteps perpendicular to the target for about **0.5 s**,
  alternating sides on consecutive failures, then tests LOS again. Immediately
  before moving, the actual selected side is checked for a cliff or dangerous
  ground; the other side is tried once, and if both are unsafe the mob stands.
  Support probes skip harmless non-walkable vegetation to inspect the actual
  ground below it. Vegetation must not halt a chase or sidestep on solid ground,
  or make a real drop, dangerous ground or unknown/unloaded terrain traversable.
  The `reach × 0.6` contact stop applies only while the target is visible; a
  blocked melee mob keeps following its path regardless of contact distance.
  Reaching the last waypoint with LOS still blocked drops that exhausted path,
  starts the same sidestep fallback and makes A* due again after the 0.25 s
  per-mob backoff.
  A ground melee attack computes one collision-box eye-height target-LOS ray
  per mob per server step and reuses it for path retention, A*, the custom
  attack hook and the punch gate. A blocked target invokes neither the custom
  hook nor the punch. Shoot and explode attacks retain their fixed `+0.5` LOS
  endpoints. Dogshoot melee and flying/swimming dogfight require both that
  common ray and their previous collision-box eye-height strike ray before
  calling the custom hook or punching.
  Across the server A* gets about **3 ms per server step** (Round 30, perf
  review 2026-10 #4; each search is timed). A request starts while the step
  has time left and nobody waits; otherwise it waits in FIFO order and the
  next step grants waiters by the running cost estimate of one search, so a
  step starts one or two no-path searches (2–3 ms each) or many cheap ones
  (a found path costs 14–211 µs). Each request has one generation-token
  entry. Cancellation invalidates only that generation, releases its strong
  entity-state reference immediately and puts any later request from the same
  mob at the tail. Death and unload cancel pending entries. The **0.25 s**
  per-mob backoff applies after an exhausted path, not to budget waiting.
  The close-cover search looks within **8 nodes** of the mob and the target
  (searchdistance 8 instead of the chase's 24, about a tenth of the search
  box).
- **Unreachable targets are given up** (Round 30, the user's ruling on perf
  review 2026-10 #4). A mob searches for a path only while it has no line of
  sight to its target; a player it can see but not reach (across a fence
  or water) is not searched for and never given up. After an A* search finds no
  path, the mob does not repeat the search for the same two nodes for
  **1 s**, then **2 s**, then **4 s** (a mob or target that changes node
  lifts the wait). After **3 failed searches in a row** against a target
  whose node has not changed — a player hidden in a closed house, in a
  walled-in hole, in a boat behind cover — the mob gives the target up at its
  next search instead: it drops the target and goes home through the
  ordinary reset (Evade above: threat, target and tags cleared, healed, a run
  home when it stands beyond its radius). A target that moves to another node
  restarts the count; about 7 s of trying covers a player stepping round a
  corner. Afterwards target acquisition ignores that player while they stay
  on the same node; once they move, or hit the mob, or a group alert calls
  it, the mob fights as usual. A target standing in a walkable node (a bottom
  slab, a lower stair step, snow dust) is searched for from the node above
  it, since the engine refuses a walkable destination; a search whose ends
  are still walkable is not run and never counts. Guards and rares follow the
  rule; the kings, like the bespoke no-leash actors (Kraken, royal guards),
  only drop the target (no heal, no royal encounter reset); the dragons and
  their whelps never give up and only wait: their arena edge ends the fight
  instead (`world.md` §4b, Round 31). The patrol path nudge shares the budget and
  the waits (1, 2, 4, 8 s, then 8 s) but never gives anything up
  (`mobs/grug_obstacle.lua`, `mobs/api.lua` `smart_mobs`,
  `grug_mobs/aggro.lua` `give_up_target`). The contact run retains its existing `at_cliff` guard
  (`mobs/grug_obstacle.lua:4-15,26-196,209-235`;
  `mobs/api.lua:157-218,887-975,2176-2864,2491-2819,2927-3538`).
  *Rationale, because the defect was invisible on paper*: the following
  pre-patch coordinates refer to commit `77261837` (2026-09-15). Vendored mobs_redo
  zeroed the mob's velocity as soon as the target was inside `reach`
  (`api.lua:2524` before the patch — the number this file carried,
  `:2493`, had drifted) while `punch_timer` accumulated **only in that same
  branch** (`:2500-2502` before the patch, printed here as `:2495-2497`;
  default interval 1 s at `:3771`, printed as `:3768`). A receding target
  left reach after one server step, so the timer gained one step while the mob
  lost the ground the target covered in it. Worked at the
  **dedicated-server default** `dedicated_server_step = 0.09`
  (`reference_projects/luanti/src/defaultsettings.cpp:498`; the setting is
  configurable and a singleplayer session does not use it, so this was the
  shape of the defect rather than a measurement): the timer gained 0.09 s while
  the mob lost ~0.36 m that it needed ~0.9 s to re-close at its
  0.4 nodes/s margin — roughly **one landed hit per ten seconds** instead of
  one per second. Raising `reach` could not repair that cadence defect (a
  stopped mob always leaves its own radius, whatever the radius). The later
  2 → 3 reach ruling instead narrows the player/mob cover mismatch and moves
  the derived telegraph and `dogshoot` melee switch with it intentionally.
  Because it changes every mob's feel, the patch shipped with the runtime test
  this paragraph demanded — a headless probe counting landed punches per 10 s
  against a receding and a standing target, before and after
  (`docs/research/mob-pressure.md`).

Group trinity: a good group = **tank + healer + 1–2 damage dealers**;
class kits must support this (Warrior: threat/taunt tools, Priest:
in-combat heals). Pulling several same-level mobs solo is dangerous by
design (`group_attack` stays on).

**Group alert** (Round 28 ruling 35): a mob that is hit calls mobs within its
view range that have `group_attack` and are not fighting yet: the same entity
name (as before) and mobs of the same family when the hit mob has
`group_attack` too. The pack call (a fleeing pack hunter) and the camp swarm
use the same rule. A neutral mob never answers or calls anyone, not even a
mob of its own name (the disposition also switches `group_attack` off), so it
is always a single pull. Families
and sub-types: `biomes_mobs.md` "Round 28 sub-types and loot by band".

## 5. Recovery (solo path)

### Combat state

"In combat" gates food ticks, eating, rage decay, the mana regeneration rate,
mounting and travel home. Decided 2026-09-28 (user
playtest rulings); owned by `grug_core` (`in_combat`).

- A player is **in combat** while at least one live mob is **engaged** with
  them, or while the timer runs (**5 s**, `COMBAT_TIMEOUT`; **10 s** after
  PvP contact).
- **Engagement (mob combat).** A mob is engaged with a player from the first
  hit between them in either direction (a landed or dodged hit of the mob or
  its projectile, or an accepted player hit on it) and whenever the player
  gains threat on it (§4: damage, healing threat, tank bonus, taunt). A mob
  that attacks a player who never touched it therefore engages too.
- Merely being targeted (sight aggro, a pack's group alert) is not
  engagement: combat starts with the first hit or threat gain, so a chased
  player who was never hit may still mount or eat.
- **Engagement ends immediately**, with no grace period, when the mob dies,
  resets (leash/evade: its threat table is cleared) or leaves the active world
  (removal or unload) -- for every engaged player -- and, for that one player,
  when the mob gives them up as its target (lost, dead, out of range). Once
  the last engaged mob is gone the player is out of combat in that same server
  step, so eating works right after the final kill. A poison applied by a mob
  does not hold combat on its own.
- In a group fight the other engaged players stay engaged while the mob picks
  its next target. A mob that stays **without a target** (or stranded, e.g. a
  fish flopping on land) on two consecutive once-a-second leash ticks drops
  every engagement; only a mob fleeing in mobs_redo's time-limited runaway
  state is exempt.
- A mob that keeps fighting someone else **forgets** an engaged player who is
  disconnected, dead or more than **40 m** away (the §4 threat candidate
  radius, here also for ambient pursuit mobs); its current target stays
  engaged, and a later threat switch onto a forgotten player engages them
  again. This check runs with the leash tick, so leaving such a fight ends
  combat within about a second.
- **The timer (fallback)** covers every hit that involves no tracked mob:
  PvP hits (dealt, received or dodged) and damage from other sources such as
  scorched ground. Such a hit keeps the player in combat for 5 s even with no
  mob engaged. **PvP contact** (§2 "PvP eligibility and flag") keeps both
  sides in combat for **10 s** (`PVP_COMBAT_TIMEOUT`); a later 5 s mark never
  shortens a running timer. Mob hits never arm the timer.
- **Death** clears both engagement and the timer at once. A dead player cannot
  be put back into combat by the killing blow's own bookkeeping, and the
  respawned player starts out of combat. Mobs keep their old threat entries,
  so besides a new hit or threat gain, a threat-driven target switch onto the
  respawned player (only possible within 40 m of such a mob) engages them
  again.
- Engagement is event-driven: it is recorded and dropped only on the hits,
  threat changes and mob lifecycle events above, never by scanning the world.

### Recovery

- **No natural HP regeneration** (user decision 2026-09-29,
  [WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29);
  WP21 closed): food is the recovery system out of combat; in-combat healing
  is the healer's/potion's job.
- **Food v2 restore buff** (R7.1/R7.2, decided 2026-09-18; supersedes R9 from
  2026-09-17; `items_crafting.md` §3.7 owns the tier table). Eating grants a
  runtime-only **300 s** buff with one tick every **5 s**. Only one food status
  may run; the latest replaces it. Every food has fixed instant HP by tier.
  Eating in combat is rejected before consuming the item or replacing a buff,
  with a short HUD notice. Accepted eating heals immediately; there is no
  deferred instant-heal queue. A successful serving plays the shared eating
  sound at **0.5 gain**; every refusal is silent. Existing regeneration pauses during combat;
  the status duration and secondary modifiers continue normally.
  - Raw/unprocessed food regenerates **2%** of maximum HP per tick at every
    tier. Wild Cocoa follows that HP rule and has no mana-pool requirement.
    Food restores mana only through the Caster dishes.
  - Dishes read their HP, mana or split regeneration plus secondary modifiers
    from tier data. Current cooked fish and meat are T1 HP dishes.
  - The natural replacement cadence is about **12 servings per hour**.
- **Healing potion**: instant fixed amount, **60 s shared cooldown**
  (Alchemy craft, 70 to 1350 HP by tier; the vendors' Weak Healing Potion
  heals 35 HP). The potion holds the
  in-combat monopoly and is paid for in cooldown; a dish may restore
  more in total, but only out of combat and over seconds. Each food tick
  due during combat is skipped while the 300-second buff keeps running.
- **Alchemy** (2026-09-18, tiers since Round 33, [item_tiers.md](item_tiers.md)
  §5): Healing and Mana Potions I–VI restore **70 / 200 / 400 / 650 / 1000 /
  1350** and every potion and draught shares one persistent 60-second clock;
  the mana half may be consumed at full mana. Every successfully consumed
  potion, draught or elixir plays the shared drinking sound; a refused use is
  silent. Antivenom clears poison,
  Swiftness grants +10% speed for 5 seconds, and Cave Draught grants night
  vision for 10 minutes. One elixir status is active at a time and stacks with
  food: at T1–T6 Vigor grants +4.0/4.8/5.6/6.4/7.2/8.0% maximum HP, Focus
  +5.0/5.6/6.2/6.8/7.4/8.0% maximum mana, Precision +4.2/5.2/6.0/7.0/7.8/8.6
  percentage points crit, Stoneskin +0.8/1.6/2.4/3.2/4.0/4.8 armor rating for
  30 minutes; Deepwater grants water breathing for 10 minutes. Ordinary
  stat elixirs last 15 minutes. None of the elixirs touches the potion clock.
- Mana regeneration is **`1 + 0.15 × level` mana/s** out of combat (1.15 at
  L1, 2.5 at L10, 5.5 at L30, 10 at L60), multiplied by the Troll
  `ooc_regen_mult` perk. In combat the untalented base rate is
  **`max(0.25 × (1 + 0.15 × level), 0.0025 × maximum mana)`**; the Troll
  perk does not apply. Cold Focus multiplies whichever in-combat term wins by
  **`1 + 2 × bonus`**: +40 % per rank since Round 35 (rank 5 triples the
  combat rate).
- The Troll perk (`ooc_regen_mult`, ×1.5) also multiplies food healing,
  instant and per tick (`grug_food.heal_multiplier`, Round 26).
- Food regeneration and pool bonuses are percent-based, but consumables now
  have tier minimum levels through `_grug_ilvl`. The neutral base pool spans
  26 at level 1 to 2696 at level 60, while class factors and pool percentages
  remain independent.
  Plain-looking HP and Mana enchants are internally percentages of the base
  pool and show both that percentage and its current-level absolute value.
- Every timed effect on the player is shown in the **status icon row**
  (`inventory_equipment.md` §5; Round 26, the status-icon package of WP
  audit D10), which replaced the first-pass text list. The combat state is
  not a status: a 32 px gold-framed crossed-swords icon right of the health
  bar replaces the former "Combat" text there (`grug_core/combat_hud.lua`).

## 6. Player and mob nameplates & con colors

- Every mob carries a nametag: `<Name> [Lv X] HP/maxHP`, updated on damage.
  The exact level is readable to each viewer independently within nametag
  range.
- Nametag and Target Frame HP use one compact formatter: values below 1000 are
  full integers, 1000–9999 use one truncated decimal (`2300 → 2.3k`), and
  values from 10000 round to whole thousands (`51234 → 51k`;
  `mods/CORE/grug_core/combat.lua:109-123`,
  `mods/ENTITIES/grug_mobs/levels.lua`).
- **Nametag visibility is proximity-capped per viewer** (25/30 m decided
  2026-08-07; per-viewer carrier mechanism decided 2026-09-18). A tag becomes
  visible when that viewer moves inside **25 m** of its parent, becomes hidden
  beyond **30 m**, and retains that viewer's prior state in the hysteresis
  band. One player's movement never changes another player's view. The radius
  sits just past the 20 m target-frame reach: everything a player can frame
  has a readable tag, plus a margin.
- Every player carries the nametag
  **`<Name> [Lv X] HP/maxHP`**, for example
  **`Thomas [Lv 5] 35/60`**. It updates immediately when HP or level changes
  and writes no property when the text is unchanged. The numbers remain plain
  integers. A player never sees their own tag carrier.
- Implementation: every tagged mob, peaceful NPC, vendor and player owns one
  invisible, non-pointable, non-physical, unsaved child entity. The parent's
  nametag stays empty (non-players) or alpha-zero (players). The child carries
  the text, inherits the parent's nametag height, and uses the engine's managed
  observer set for the per-viewer rule above. One central pass, spread over
  eight steps of each second, snapshots player positions and manages every
  carrier once per second; unchanged observer sets are not written. Carriers have no per-entity `on_step`: the central pass also
  removes an orphan, while explicit parent lifecycle hooks remove the ordinary
  cases immediately.
- **Con colors are per viewer** and live in a **HUD target frame** (the
  mob you look at/punch; nametags cannot be colored per viewer). The
  frame's **reach is 20 m** — our choice, not an engine constant: far
  enough past the 16 m view_range of our longest-sighted ground mobs to
  size up what is about to notice you, and inside the ability targeting
  ranges so what you can frame is roughly what you can hit. The frame
  also works on **players** (name + faction, faction-colored); an enemy
  player also shows "(flagged)" or "(protected)" from their own PvP flag
  (Round 31), red only while both are flagged and can fight, else gray. It refreshes
  twice a second from the crosshair's own skill ray when that ray reaches
  20 m and settles the question (nothing in reach, a wall, or a framable
  target first), otherwise from a 20 m ray of its own.
  Relative to the viewer's level L (mobs):

| Relation | Color | XP |
|----------|-------|----|
| mob ≤ L−10 | gray | none |
| L−10 < mob ≤ L | green | normal |
| mob > L | red | normal |

- **No skull tier** and no extra damage modifier for high-level mobs —
  mob damage already scales via the level formulas; the nametag carries
  the exact level anyway.
- Implementation: shared carrier in `grug_core`, mob text and gray-XP rule in
  `grug_mobs`, player text in `grug_factions`, target frame HUD alongside WP6.

## 7. Offhand

- The engine has **no native offhand**; we build `grug_offhand` after
  VoxeLibre's `mcl_offhand` pattern (inventory list `"offhand"` + HUD
  slot).
- **The offhand is per class** (Round 28 ruling 25): **Warrior** — a shield
  (only Warriors equip shields); **Mage and Priest** — the "Caster offhand",
  a Tailor spellbook; **Scout** — its **melee weapon** (sword or dagger),
  shown as "Melee", while its Weapon slot is shown as "Ranged" and takes the
  bow. **Both hand items always count toward stats for every class.** Strike,
  Opening and every melee skill swing the Scout's Melee item (bare hand when
  empty); its bow skills read Ranged. There is no dual-wield: no class
  swings two weapons at once, and no Rogue path in V1.
- Equip rules (enforced centrally): occupied hands total at most two.
  Shields, spellbooks, the bow and every one-hand weapon count one hand;
  staff and greataxe require an empty offhand.
- **The mechanism of the two-handed rule** (decided 2026-08-08, shipped
  with WP35 — the weapon slot is the first place it can be enforced):
  items declare a hand count in `_grug_hands` (**greataxe/staff 2,
  sword/dagger/wand/bow 1**; a missing field means one-handed). Gathering tools,
  including Woodcutting Axes, are ineligible for Weapon. The weapon/offhand
  `allow_put` refuses pairs whose occupied hands exceed two, in both directions,
  with a message explaining the trade. Eligibility: `inventory_equipment.md` §2.
  It is a **refusal**, never an automatic
  unequip of the other slot.
- Consequence, and it is a gameplay rule rather than a technicality:
  **carrying a shield or spellbook costs you the two-handed weapon.**
  Greataxe and staff users choose between the offhand and their weapon. The
  refusal text says so rather than failing silently.
- **No carried light** (user decision 2026-09-29,
  [WP audit](../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29) C5):
  torches are not offhand items and nothing carried gives a moving light
  radius.

### Round 16 control and threat expiry

Taunt retains three seconds of forced targeting and top threat times 1.1. Threat
accumulates without time decay; valid rivals need more than 120% of a valid
current target's threat. Taunt and player threat refuse evading mobs before
forcing a target or changing the ledger. A suppressed switch remains pending through the forced
window and is reconsidered after expiry even without a new hit. Invalid current
targets do not impose hysteresis on valid rivals. Charge stun lasts 1.5 seconds
on accepted hits, excluding kings and dragons; it cancels pending attacks and
blocks movement and attack execution, preserving gravity.

## Global non-player damage scale

The startup setting `grug_mob_damage_scale` (main menu section *Combat*)
defaults to **1.5**; **1.0** retains the prior unscaled damage. Valid values are 0–10; invalid/nonfinite values
fall back to 1.5. Apply it exactly once to damage from all non-player
combat actors: ordinary/neutral mobs, guards, adds, elites/rares and bosses.
It covers melee, projectiles, auras, DoTs and authored attack ground effects,
including fixed-damage consumers as well as level-derived damage. Player
attacks, fall damage and ordinary environmental damage are unaffected.
Derived arrow/boss damage must not be multiplied again. This setting does not
change HP, density, aggression range, armor, rewards or ability cadence.

## Nametag categories and injured health sprites

All viewers see the same category colors; existing 25/30 m observer hysteresis
still controls visibility independently. Six categories have configurable
foreground/background RGBA settings loaded once at server start: aggressive,
neutral, guard, npc, player, critter. Defaults are red/yellow/violet/light
lavender/white/white respectively, with black background alpha 64/255 (about
25%). Bosses, elites and adds reuse their behavior or faction-role category;
mounts get no additional tags. A neutral animal stays yellow when provoked.

A startup boolean (default on) enables a small green camera-facing sprite bar
for living injured combat mobs, bosses and guards. Hide at full HP or death;
no bars for players, critters or peaceful NPCs. Keep existing HP text. Reuse the
nametag visibility pass and observers; update fill only when visible integer
percentage changes. Bars are ephemeral/nonphysical/nonpointable and removed
with their parent. No individual-player copies or additional proximity scans.

Startup presentation settings:

| Category | Foreground setting/default | Background setting/default |
|---|---|---|
| Aggressive | `grug_nametag_aggressive_foreground` / `#ff4b4b` | `grug_nametag_aggressive_background` / `#00000040` |
| Neutral | `grug_nametag_neutral_foreground` / `#ffd447` | `grug_nametag_neutral_background` / `#00000040` |
| Guard | `grug_nametag_guard_foreground` / `#b76cff` | `grug_nametag_guard_background` / `#00000040` |
| NPC | `grug_nametag_npc_foreground` / `#d8c5ff` | `grug_nametag_npc_background` / `#00000040` |
| Player | `grug_nametag_player_foreground` / `#ffffff` | `grug_nametag_player_background` / `#00000040` |
| Critter | `grug_nametag_critter_foreground` / `#ffffff` | `grug_nametag_critter_background` / `#00000040` |

`grug_injured_mob_hp_bars` defaults to `true`. Invalid colors fall back to the
category default. **Every bar is world-sized** (Round 28 ruling 10): an
ordinary bar is 0.8 by 0.1 nodes whatever the mob's `visual_size` (a fox drawn
at 10 and a serpent drawn at 0.3 get the same bar) and hangs 0.12 nodes above
the mob's selection-box top, just under the nametag, which the engine draws
0.3 nodes above that top. The two dragons keep explicit world-space profiles
of 3 by 0.25 nodes, anchored just under their nametag: Wyrmglass at 2.77 nodes
above origin, Stormscale at 2.97. Billboard width and height are world
dimensions and are never divided by the parent's scale; only the attachment
position compensates it. A tier rescale after the bar exists re-attaches the
bar at the new box top, and the nametag carrier copies the rescaled box.

**Selection boxes match the model** (Round 28 ruling 10). Every mob whose
rendered mesh clearly exceeds its box (more than a quarter node) has a
rotated selection box (`rotate = true`, it turns with the mob's yaw) built
from the measured mesh bounds of its stand animation, horizontally never
narrower than its collision footprint, rounded out to 0.05 node
(`tools/r28_a3/mesh_bounds.py`). The collision box stays the movement
footprint. The boar family and the Ibex had such boxes already.
The server's aim hits a rotated box exactly where the client draws it at
every facing (Round 35; the engine's server raycast gets these boxes wrong,
[upstream workarounds](../technical/upstream-workarounds.md) §1).
There is no screen-space boss HUD. The sprite remains perspective-scaled. Flight visuals use a duration bounded to
0.05–2 seconds, so near-zero partial bow draws never cause long pursuit.

## Ambient pursuit policy

This revision supersedes ordinary ambient chase-anchor and contact rules in §4.
Free-roaming combat mobs have a 15-second incoming-damage grace clock starting
on initial aggro. Effective player/guard HP damage, including DoT ticks, resets
it; outgoing hits, taunt and threat-only changes do not. There is no distance
from a damage-origin anchor. For a live current target, expiry only triggers
return when that target has moved at least 0.25 nodes horizontally since the
previous existing roughly one-second leash sample (squared X/Z displacement,
no direction or mob-distance comparison). Initial samples and target changes
establish a new baseline and never imply movement. Stationary targets keep the
fight active without resetting the damage clock: moving later can immediately
trigger return, and sideways/circular movement counts. Vertical motion alone
and smaller per-sample jitter do not count. This applies to melee and ranged
pursuit; outgoing mob attacks never sustain or end the clock.

Dead/unavailable targets and abandoned no-target encounters retain existing
cleanup; temporary pack flight without a target must not pin an expired fight.
Sampling state is runtime-only and cleared with the encounter. A reset heals
the mob; it runs home (invulnerable, with the 40-second teleport fallback) only
when the reset finds it outside its wander radius below, and only until it is
back inside that radius (Round 36 §2.14.2, §4 Evade). The 15-second clock
still starts at the first aggro.
Bosses/retinue, fixed guards, camp-owned mobs and location-bound rares keep their
existing encounter/post lifecycle and bounds. No additional terrain is loaded
to preserve a distant target.

**Wander leash (Round 24):** outside combat a free-roaming mob idles within
**32 nodes** (`grug_mobs.WANDER_RADIUS`) of its spawn point: once it has
wandered further it walks back with the camp roam cap's one-second nudge.
It applies to idle standing and walking only, so pursuit keeps the policy
above and there is no chase leash. Camp members keep their 20-node roam cap;
patrollers, named rares, bosses and summons, royals, bespoke no-leash actors,
NPCs and water-bound swimmers keep their own movement rules. Player participation/credit rules remain separate.
Friendly guard healing stays deferred; current healing targets remain players.
Round 28 ruling 4 keeps the leash anchored at the spawn point with radius 32;
spawn regions (about 100–200 m across, `spawn_regions.md`) keep mobs near
the region they spawned in. Members of a recipe camp (ruling 37) roam free
under this leash; only the camp fires keep the 20-node roam cap.

**Road and town push (Round 28 ruling 2):** roads and towns should feel safe
to travel and rest in without becoming a combat refuge. An idle (standing or
walking: no target, not following, not evading) free-roaming mob with the
**aggressive** disposition probes every 4–5 seconds of the leash slot (the
period picked per mob and probe, the first probe of an activation at a random
slot) eight points on a horizontal ring of radius equal to its `view_range`,
at its own height. A point hits on a road, bridge, village or (Round 31) PvP
fortress or war camp with its protection margin
(`grug_core.world_feature_at`) or in a start town or capital city
(`grug_zones.hard_protection_kind_at` "town"). Other POIs (including
outposts and hostile camps) do not push. With any hit the mob walks along a free ring
direction, never toward a hit: the free direction closest to the opposite of
the hits' mean direction (when the hits cancel, as for a mob standing on a
straight road or a crossroads, the free direction with the most free
neighbours; ties go to the direction nearer its spawn point, then to ring
order). When all eight points hit it walks straight toward its spawn point
(no push without one). It uses the wander leash's nudge. Inside the
wander radius the push steers; outside it the leash walks the mob home and the
push is not asked, so the two never fight. Neutral mobs, critters, NPCs, camp
members, patrollers, rares, bosses and the other bound actors are never
pushed, and pursuit is unchanged: a fighting mob follows its target across any
road. It is a tendency, not a guarantee (the random walk may carry a mob back
for a while). Code: `grug_mobs/roam_avoid.lua`, called from `aggro.lua`
roam_check.

## Out-of-combat mob recovery

Living registered world mobs, guards and bosses recover to full HP after 30
continuous seconds of genuine idle time, rather than incremental regeneration.
This supplements the existing immediate full heal on a confirmed leash reset.
It never revives dead entities or changes damage, resistance or pursuit rules.

Use the existing one-second mob maintenance cadence. Observe actual entity HP:
any decrease, regardless of source, restarts quiet time. An attack target,
attack state, flight/flop, evade, or pending boss attack blocks idle recovery.
Only calm standing/walking qualifies; temporary target gaps cannot immediately
heal. Initialize a fresh quiet period on activation; clocks remain runtime-only.

Members of one boss encounter share recent activity, including king/retinue and
boss summons. A fighting or newly damaged member blocks the others' idle heal,
even when a following guard temporarily has no target. Use runtime activity
timestamps, not the reward-participation ledger (which can remain after combat).
No additional proximity scan or pathfinding is required. The full-heal operation
uses the existing reset transaction, retaining health bookkeeping, tag cleanup,
boss action cancellation and encounter ownership rules.

## Stun presentation

An accepted stun emits one small, bounded golden particle burst above its
target. Rejected, immune and dead targets emit none. This is feedback for the
existing stun result, not a separate control effect or damage source.
