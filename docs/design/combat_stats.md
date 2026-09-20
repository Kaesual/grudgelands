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
  [skill_trees.md](skill_trees.md) (PROPOSAL, revision 2), which also carries
  the open decision (§6.5) about whether a capstone may exceed one of this
  file's caps for a bounded time.
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
| Strength | melee damage |
| Intelligence | spell damage; percentage bonus to healing/absorbs |
| Dexterity | crit chance, dodge chance |

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
- **Melee damage** = weapon damage + floor(Str/10). Since 2026-08-08,
  **"weapon damage" has a source: the item in the WEAPON SLOT**
  (`inventory_equipment.md` §2) — the single, fixed source for every
  sword-type skill, with **no fallback to the wielded item**. An empty slot
  swings for the **bare-handed baseline**: the hand's own damage and its
  own interval, read from the registered hand item rather than assumed.
- **Spell power** = floor(Int/10). It is a flat term for damaging spells and
  a percentage bonus for pool-derived healing and absorbs.
- **Timed spell damage** is a separate percentage multiplier on the fully
  assembled hostile spell formula. It never enters spell power and therefore
  never raises healing or absorbs.
- **Damage level scalar** = `P(L) / (8 × B(L))`, where
  `B(L) = round(4 + 0.35L) + floor((10 + 3(L−1))/10)` is the own-level
  baseline sword plus Warrior melee bonus. Damage assembles weapon/ability,
  attribute and flat talent terms before this scalar and floors once at
  settlement; a positive authored damage value settles to at least 1.
- **Support values are already level-derived and are never level-scaled a
  second time.** Flash Heal and Shield are each 25% of `P(L)`; each Renew tick
  is 8%. Multiply that pool share by `1 + spell power/100`, then pass the
  resulting absolute amount unchanged through `scale_player_value` and the
  existing `heal_player`/`set_absorb` seams. Percentage consumables likewise
  derive once from the relevant final pool and bypass the damage scalar.
- **Mana costs** are rounded percentages of the unmodified `P(L)`, minimum 1.
  HP/mana enchants and pool talents therefore change capacity, not spell cost.
- **Weapon item level has exactly one damage axis:** the authored weapon curve
  `round(4 + 0.35 × ilvl)` (then the weapon-family factor). Combat applies no
  second ilvl multiplier. Character level still supplies the shared damage fit.
- **Endgame headroom**: own-level quest/craft gear is the baseline. Level-60
  dungeon, raid and final-boss rewards use ilvl **65 / 70 / 75**. At L60 the
  1H weapon values are 25 / 27 / 29 / 30 damage for ilvl 60 / 65 / 70 / 75.
  Eight equipped slots budget approximately +5% each in damage-equivalent
  enchant value. A fully offensive +40% allocation yields effective hits
  **515 / 526** with ilvl 70 / 75 against the baseline's **337**: +52.8% /
  +56.1%, the intended +50–60% ceiling. Pool-focused allocation may instead
  spend that budget on about +40% HP/mana. These are itemization ceilings, not
  extra level-curve terms.
- **Higher-mob-level damage malus**: against a mob more than five levels above
  the player, multiply player damage by `max(0.10, 1 − 0.10×(mob level −
  player level − 5))`. It is part of the same final damage multiplication and
  is floored only once with the level scalar
  (`mods/CORE/grug_core/combat.lua:29-65`).
- **Crit** = 5% + 0.1%×Dex, **cap 30%**; a crit deals ×1.5 damage
- **Dodge** = 0.1%×Dex, **cap 30%**; a dodge avoids the hit entirely
- Player armor is a numerical **rating** evaluated against the attacker's
  level. It is not itself a percentage; endgame plate and shields remain useful
  against enemies above level 60.
- **How armor resolves** (rating model adopted 2026-09-20): armor rating sums
  over head/chest/legs/feet, an equipped shield, refinement, affixes, cultural
  finish, statuses and talents. Which armor a
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
    Unbroken capstone multiplies the final aggregated rating by **1.40**. Its
    existing low-HP trigger then adds **15 rating after that multiplier** for
    8 seconds, at most once per 180 seconds. It never raises the 70% cap.
  - It applies **only to `reason.type == "punch"`**. There is no
    damage-type system, so that IS the whole definition of "physical":
    fall damage has its own race perk (world.md §7) and drowning, lava
    and starvation are never reduced by a breastplate.
  - **Resolution order** for an ordinary punch in the central hp-change
    modifier: **dodge (cancels the hit entirely) → Grudgelands-mob pressure
    fit → armor → applicable target-race Warding Draught → absorb shield.**
    Foreign entities without a Grudgelands level bypass the pressure fit.
    Authoritative swing abilities assemble gear, Strength and a selected proc,
    then apply the level scalar and mob-level malus once before crit and armor.
    Ordinary native tools/fists against hostile players apply the level scalar
    to their full-swing equivalent before crit, armor, proportional scaling and
    accumulation. Raw tool/fist punches against Grudgelands mobs are vetoed:
    all player damage to those mobs comes through the once-scaled authoritative
    swing or ability seams.
    Both then enter the modifier for dodge and absorb and use a namespaced
    `custom_type` that skips
    only the already-performed armor step. Fall damage is separate: a native
    negative fall change of `r` settles as `ceil(max_hp × r / 20)`. Native zero
    stays zero and there is no 100%-of-pool cap. This preserves the engine's
    impact-derived input rather than reconstructing block distance. The Dwarf
    multiplier of 0.8 then rounds up, followed by absorb; armor and dodge never
    apply. A shield therefore always soaks *post*-mitigation
    damage, i.e. shield points are worth full damage rather than pre-armor
    damage.
  - **Rounding: the reduced damage rounds up**, so armor alone can never
    turn a landed hit into 0 — however much of it a tank stacks, the hit
    still costs at least 1 HP.
- **The Weapon slot enforces the current generated catalog's `_grug_ilvl`
  directly as its minimum character level.** The documented future ilvl
  65/70/75 endgame items instead carry a level-60 requirement when created.
  Items without a positive `_grug_ilvl`
  remain unrestricted, and no other equipment slot has this level gate
  (`grug_inventory/equipment.lua:173-185,330-338`);
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

Equipment sources, ordinary affixes and cultural finishes add before final
consumer caps. Crit and Dodge remain capped at 30%; armor reduction is capped
at 70% after the attacker-level formula. Raw armor rating is never discarded.
The Character/Talents UI exposes raw rating, the active Bulwark multiplier,
the resulting rating and current reduction against the relevant attacker.
Unbroken does not override the reduction cap.

The Character page contains only two live maximum-pool derivations: HP and
mana, or HP and fixed Rage. Each compact line carries final value, base pool,
HP class factor where applicable, and separate gear/talent/status percentages;
the HUD bars are the sole display of current pool values. The Help page owns
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

Two optional target-race systems use the central pipeline:

- A permanent T4/T5/T6 weapon-counter special adds **+1/+2/+3 flat damage**
  against the selected race. Only the equipped weapon contributes. Add it
  after ordinary crit has resolved and before armor/absorb, so armor mitigates
  it and Crit never multiplies it. It applies to hostile players and
  combat-capable NPCs/mobs with that race identity; passive invulnerable
  service NPCs are never valid targets. No percentage target-race damage ships
  in the MVP.
- A five-minute T4/T5/T6 Warding Draught reduces incoming damage from the
  selected race by **5%/7.5%/10%** after armor and before absorb. Only one
  target-race ward may be active; a new one replaces the old one. It affects
  hostile players and combat-capable NPCs/mobs carrying that race identity,
  shares the 60-second potion-use cooldown and is not modified by Apothecary
  Loop. The ward has its own PvP-buff category and may coexist with one
  ordinary elixir and the food restore buff.

### Environmental damage, deaths and shore movement

- A player whose head point is inside a walkable, non-liquid node takes
  **floor(5% of maximum HP) per second, minimum 1 HP**. Non-walkable nodes,
  including plants, do not suffocate; neither do liquid nodes. The
  character-creation stasis state and players holding the `noclip` privilege
  are exempt.
- Every player death sends exactly **one** short English line to all players.
  The selected template distinguishes fall, drowning, lava/fire node damage,
  suffocation, a mob punch (using the mob's display name), a player punch
  (using the player name) and an unattributed fallback.
- **Shore-height ruling (2026-09-17):** shore exits have zero vertical rise:
  the first cardinal dry-land surface beside exposed surface water is exactly
  level with the water surface. Authored bridges, causeways, fords, route decks
  and culverts are functional-edge exceptions and retain their existing grade
  constraints. The zero-rise rule is required because Luanti forces a swimming,
  non-grounded player to **0.2** effective stepheight regardless of the property
  (`reference_projects/luanti/src/client/localplayer.cpp:322`).

### Melee timing and aim authority (shipped 2026-08-10, WP39)

Swing ability timing, aim and skill charge timing are separate. The equipped
weapon supplies damage and `full_punch_interval`; the current crosshair ray
supplies the target; each selected swing skill supplies only its optional
charged effect. Enemy target memory is UI state and never supplies aim.

- **Swing items keep native interaction, not native combat damage.** Strike,
  Mighty Blow and Hamstring have no `on_use`, so the client keeps its fast
  first-person held-LMB animation. Their no-dig pointabilities can mask a drop
  resting against blocked ground, so a fresh server-visible LMB press also
  raycasts the unchanged 4 m range and invokes builtin pickup only when the
  first visible object is a dropped item. A native enemy punch packet is
  suppressed before damage, rage, threat, wear or proc. The engine's object
  packet repeat is not the held-damage chassis: runtime testing showed its
  client ray could change to `nothing` after one punch while server control
  `dig` remained true. The source split is in
  `reference_projects/luanti/src/client/game.cpp:3218-3247` and
  `reference_projects/luanti/src/script/lua_api/l_object.cpp:1816-1832`.
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
  items. It shows weapon readiness only, not target validity or proc charge. A
  valid attack hides it immediately and expiry shows it once; an aim miss
  leaves it visible. There is no smooth progress animation and no periodic
  inventory rewrite.
- **The weapon slot is the sole swing source.** On kit/equipment sync every
  swing ItemStack mirrors slot `full_punch_interval`, but carries
  `damage_groups.fleshy = 0`, empty `groupcaps`, `max_drop_level = 0` and
  `punch_attack_uses = 0`; an empty slot uses the registered hand interval.
  Zero native damage preserves client animation while preventing builtin PvP
  knockback before suppression. The authoritative swing rebuilds real full
  capabilities from the slot, never from a wielded tool. The ability stack and
  equipped weapon take no wear. Swing definitions keep `crumbly`, `snappy`,
  `oddly_breakable_by_hand` and `dig_immediate` node pointabilities blocking.
- **Skill selection is live at the attempted swing.** Switching Strike ↔
  Mighty Blow ↔ Hamstring preserves the weapon clock and reads the new skill.
  A non-swing/cast boundary stops attempts and discards ordinary tool remainder
  but preserves due time; lifecycle/class reset clears it. A concrete equipped
  weapon change starts the new weapon at one full interval, preventing swap
  spam.
- **Ordinary hostile tools/fists cannot form a second stream.** Against a
  Grudgelands mob their raw punch is input only and deals **0 damage**; only a
  current-ray authoritative swing or an ability punch can damage it. Against a
  hostile player the native proportional path remains and moves the next full
  ability swing to at least `now + equipped FPI`. Its transition clears an old
  bank once; consecutive ordinary PvP packets retain their fractions, and
  returning to a swing clears the remainder once. Cast use alone preserves
  ability due time (`mods/ENTITIES/mobs/api.lua:2969-2974`,
  `mods/PLAYER/grug_abilities/init.lua:1271-1310`, `:2322-2489`).
- **One accepted full swing resolves once.** Against players the order is
  **slot weapon + Strength → selected proc replacement → level scalar (plus
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
- **Ordinary tools and fists remain proportional native melee.** They use the
  wielded source and `clamp(tflp / fpi, 0, 1)`, plus Strength/crit/armor. Their
  per-player accumulator stores its own target GUID and forfeits damage
  remainder below 1 plus pending rage credit when an actual damage contribution
  switches target; it does not use target memory. Target death/leave invalidates
  Core banks. Wear remains per concrete ItemStack id and is spent once per
  completed native tool swing; empty/non-tool, creative and use-0 hits consume
  no wear state. Swing ability items never enter this proportional path.

### Hostile casts and projectiles (shipped with WP39)

- **Hostile direct casts require current aim.** Charge, Taunt and Smite accept
  only a currently pointed valid hostile within their individual range and a
  server line-of-sight check. Enemy target memory is never a fallback. Failure
  to acquire a target spends no resource and arms no cooldown. Friendly
  heal/shield casts always resolve through pointed valid ally → valid in-range
  ally memory → self; any pointed invalid object enters that fallback chain
  (user ruling 2026-09-17).
- **Fireball is directional, not targeted.** On successful input it spends
  6% of the caster's base mana and starts a server-authoritative **1.0 s cast
  interval**, then snapshots the cast-time eye direction and spawns one straight
  projectile at **20 m/s**. It has no homing, gravity or splash, deals
  **baseline weapon damage + spell power**, multiplied by active timed spell
  damage percentages, through the damage fit, and disappears on its first
  attackable target, a blocking node or **20 m** travelled. A shot into empty
  space is still a cast and still spends mana. Friendly players/allied entities
  and dropped items are ignored instead of body-blocking it. Input inside the
  cast interval is refused without spending mana; the interval is a cadence,
  not a cooldown,
  has no wear bar and cannot be shortened by cooldown talents.
- **Active Fireballs are bounded per owner session.** At most eight may exist
  for one owner/session; the ninth spawn fails before entity creation and does
  not spend mana. Hit, range, lifetime, node collision, deactivation, invalid
  activation and spawn/velocity failure release the slot exactly once. A
  reconnect or respawn starts a fresh session, and an old projectile cannot
  consume its new limit.
- **Fast projectiles use swept collision.** Each step raycasts the whole segment
  from the previous position to the new one so walls and thin/moving targets
  cannot be skipped by a large `dtime`. Owner/faction validation, one-hit
  settlement, unloaded-object cleanup and max-distance cleanup are shared
  projectile infrastructure, not Fireball-only branches.
- **Bows reuse the infrastructure later, not in WP39.** A bow is drawn up to a
  maximum and releases a ballistic arrow whose initial impulse comes from draw
  time; gravity supplies the trajectory and a lifetime/distance guard still
  cleans the entity. The item/ammo numbers stay in `items_crafting.md` §9.

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
tool/fist accumulation remains proportional and target-keyed. WP39 changed
target authority and Fireball travel, not the melee damage tables.

### PvP eligibility and tag

All player-damage paths call the central geographic/tag rule from
`world_zones.md` §4. Contested-zone entry tags automatically; peaceful-zone
players remain immune to unprovoked enemy-player damage. A voluntary hostile
action tags its user before eligibility/damage resolution. Safe→safe blocks
that first effect while tagging the attacker; safe→tagged may land after
tagging; tagged→safe blocks; tagged→tagged may land. Outside contested zones
the tag clears 60 seconds after the last qualifying effective HP/absorb damage
or support contact; misses and zero effects do not refresh it. Contested entry
forces the tag, leaving starts a full 60-second tail, and death clears it
immediately. Melee, casts, area effects, projectiles and support may not diverge
from `world_zones.md` §15. This is target design for WP41; the shipped callbacks
currently gate only by faction and global `enable_pvp`.

Every non-ocean land position at **y = −701 and below** is contested even when
its surface zone is peaceful. Crossing down forces the tag; returning above
the boundary starts the same full 60-second peaceful-zone tail as leaving any
other contested area. Deep ocean and immutable dragon channels remain outside
the editable land rule.

## 3. Mobs

Normal tier at level L:

- **HP** = `20 + 5×L + 0.66×L²` · **Damage/hit** =
  `2 + 0.3×L + 0.005×L²`, rounded to one decimal · **XP** = `10×L`
- mobs_redo armor: normal 100, **elite 80 (×3 HP, ×1.8 dmg, ×4 XP)**,
  **rare patrol 70 (×5 HP, ×2.2 dmg, ×6 XP)**, and the registered
  **boss tier (×20 HP only; normal damage, XP and armor; no telegraph)**.
  No mob uses the boss tier before
  the round-6 king/dragon content. The single implementation table and formula
  are `mods/ENTITIES/grug_mobs/levels.lua:70-118`.
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
  deep-sea Kraken Guard's shipped value is **5.0**. The ordinary 4.6 band keeps
  the Swiftness Draught below it (4.0 × 1.10 = 4.4), and continues to feed the
  25 m soft de-aggro and 45 m / 40 m chase rules of §4. Current definition
  sites for the changed families: `grug_mobs/stag.lua:21`, `ram.lua:26`, `zebra.lua:20`,
  `carrion_crow.lua:54`, `zombie.lua:29` and `golem.lua:87`; the exceptions
  are `bandit_archer.lua:78`, `skeleton_archer.lua:81`,
  `skeleton_raider.lua:52`, `bog_ooze.lua:38` and `kraken.lua:54`.
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
- **Ordinary hits have zero knockback.** Damage never becomes an implicit
  displacement magnitude. `damage_groups.knockback` remains the explicit
  override seam for a future limited/cooldown skill
  (`mobs/api.lua:3455-3481`).
- **Actors do not collide with other objects.** Mobs, NPCs and players use
  `collide_with_objects = false`; terrain collision is unchanged. This removes
  actor-on-actor climbing and deliberately permits visual overlap, which the
  runtime playtest must judge (`mobs/api.lua:3967-3975`;
  `grug_core/init.lua:70`).
- **The 4.6 > 4.0 inequality holds except for named, long-cooldown skills**
  (`skill_trees.md` §5, ruling 10 of 2026-09-16): "skills may explicitly
  **break the base inequalities** (mob 4.4 > player 4.0, stat caps, roots)…
  The rule: **the bigger the break, the stronger the limit**, usually cooldown
  or duration." *(The ruling is quoted verbatim and says 4.4 because the band
  moved to 4.6 on the same day, in ruling 2 above; the numbers derived from it
  below are stated against the shipped 4.6.)* The first one is the Scout's
  **Sprint** — **+25 % for 10 s on a 300 s cooldown** (ruling 29,
  `scout.md` §2) — which puts a sprinting player at **5.0** against 4.6 for
  ten seconds in every five minutes. Nothing permanent or cheap is covered:
  the Swiftness Draught stays at **+10 % for 5 s**
  (4.0 × 1.10 = 4.4 < 4.6, `items_crafting.md` §3.6/§10 P4) and a
  mount pays for its permanent 6–10 nodes/s with the damage dismount
  (`mounts.md` §3.1).
- **View range follows the attack type** (decided 2026-09-16, user ruling 3):
  a **`dogshoot` family sees 16 m**, a **melee family 10–14 m by habitat**.
  The full per-mob table and the habitat reasons are `biomes_mobs.md` §3.1;
  **16 is the ceiling for a land mob**, because §4's 45 m chase give-up and
  40 m leash both depend on a mob keeping a target it can no longer see. The
  same ruling asks for more ranged families: the first is the **Bandit
  Archer**, one slot in three of the existing bandit camp, which takes the
  registered ranged roster from **4 of 43 to 5 of 44** and is the first ranged
  enemy a player meets in the inner ring.
- Pacing property: ~**20 same-level mob kills per level** (XP=10L vs.
  quadratic level curve); quests supply the rest.
- **Gray kills award no XP**: a mob at level ≤ killer level − 10 gives 0
  XP (kills trivial-mob farming).
- **XP level cap**: calculate each recipient's formula with effective mob
  level `min(actual mob level, player level + 5)`. The gray test still reads
  the actual mob level (`mods/ENTITIES/grug_mobs/levels.lua:643-656`).
- **XP participation and split**: a participant dealt accepted damage to the
  mob or delivered effective healing to an existing participant. At death,
  only participants who are online and within 40 m count; divide the award by
  that eligible count after calculating the cap and gray rule per recipient. A
  player receives no XP from a mob of their own faction
  (`mods/ENTITIES/grug_mobs/init.lua:87-215`). Settlement occurs once at the
  shared mobs_redo death boundary regardless of whether a player, NPC, mob or
  the environment dealt the final damage, without replacing the mob's death
  callback, animation or smoke fallback (`mods/ENTITIES/mobs/api.lua:887-975`).
- **PvE death loss** is 25% of the whole current-level XP span, clamped at the
  current level start; it never de-levels. Level 60 has no following span and
  therefore no PvE XP loss (`mods/PLAYER/grug_xp/init.lua:86-104`).
- **Player-tag drop rule** (decided 2026-08-06, WP6): a mob drops loot
  only if a player damaged it (`do_punch` sets a tag; the tag stores
  the attacker's professions for loot-table hooks like the
  Leatherworker ×5, professions.md §3) — **the tag expires after ~60 s
  without further player contact** (no "seeding" a wolf and letting
  guards farm it). Faction NPCs drop only when killed by ENEMY players
  (PvP); NPC-vs-mob kills never drop. Kills LotT's armor-litter
  problem.
- **Soft de-aggro** (with the speed rule, decided 2026-08-06): beyond
  ~25 m from its target a chasing mob drops to walk speed — fleeing is
  hard, not impossible (mobs are otherwise faster than players).
- **Readability rules for mobs** (decided 2026-08-06, shipped with WP6):
  elites/rares signal via **scale + tint** — elite `visual_size` ×1.6,
  gold `^[colorize:#ffa800:80`, nametag prefix `Elite `; rare ×2,
  violet `#a64dff:90`, nametag prefix `★ ` — plus the `!! ` prefix while
  a wind-up runs. **Elites AND rares telegraph** (both tiers, no def
  opt-in): 2 s wind-up (stop, `!!` nametag, particle burst; the growl is
  deferred to the one WP-wide sound pass) then a ×3 damage hit into a
  **90° frontal cone** of **reach + 1.5 m** (normally **4.5 m**) that requires **line of
  sight** — stepping aside, out of range or behind cover is a clean miss.
  Cadence: the first wind-up needs **4 s of MELEE engagement** (a fight
  always opens with normal swings, and a ranged elite at distance never
  winds up into empty air), afterwards one every **10 s**. The same
  mechanic later scales up to bosses. **One behavior
  verb per mob family** (boars charge, wolves hunt in packs and flee
  low to return with friends, zombies never leash, skeleton archers
  `dogshoot`). **Named rares broadcast** their spawn faction-wide
  ("Grimtusk has been sighted…") — a meeting point for a low-population
  server.
- WP1 retune (**done with WP6**): boar = L1 (HP 26, dmg 2.3, XP 10),
  zombie = L3 (HP 41, dmg 2.9, XP 30), and both now use the 4.6 melee band
  (`run_velocity` was 3.4/2.6 at WP6, raised to 4.4/4.2 with the soft
  de-aggro, then to the band's 4.6 in rounds 4 and 5).
- **Level floors** (`_grug_min_level`): a mob whose family belongs to a
  later zone keeps its floor even where the field reads lower — zombie 3,
  wolf/hyena/jungle lynx 10, guard 20. The floor is also the fallback
  where the level field has no value.
- **Guard levels** come from the separate `grug_core.guard_level_at`
  field (world.md §1) with its own cap of **70** (the mob axis stays
  1–60), and a guard at level **≥ 60 is promoted to elite
  automatically**. Its T3 positional base is `nil` in every exterior class,
  including shelf. Inside the exact capital build-plus-10 hard-protection x/z
  mask it is exactly 60 only at normalized y >= -700; at y <= -701 and all
  other non-exterior positions it is
  `min(70, max(20, surface_level_at(pos)))`. It does not apply the mob depth
  floor. WP13 may later raise that non-nil generic base outside the shallow
  capital hard volume, capped at 70, but may never lower it; exterior nil
  remains nil and permits no guard post. Ordinary and royal guards inside
  remain exactly 60. `_grug_fixed_level` is the sole explicit fixed-entity
  mechanism and bypasses positional and post-role fields only for a deliberately
  designed fixed entity. Its implemented uses are the Kraken Guard at L100 and
  every WP13 king at L65. No second king-specific fixed-level path exists.

| Mob level | HP | Dmg/hit | XP |
|-----------|----|---------|----|
| 1 | 26 | 2.3 | 10 |
| 10 | 136 | 5.5 | 100 |
| 30 | 764 | 15.5 | 300 |
| 60 | 2696 | 38.0 | 600 |

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
surface geometry (`world_zones.md` §2): the named zone and its authored local
progression supply levels 1–60 through three rational z-axis bands, rising
from outer race starts toward the faction front. Accord profiles run toward
+z and Throng profiles toward -z; the Battlegrounds profiles run from their
faction-facing edge toward z = 0, while both level-60 summits stay flat. Each
zone range is split into three consecutive integer sub-ranges and each band is
an evenly placed integer staircase as specified in `world_zones.md` §2.
Within 100 horizontal nodes of every authored start anchor the surface level
is 1, from 101 through 150 nodes it is 2, and beyond 150 nodes the axial field
applies. Capital city zones contain no ambient hostile mobs. Guards use
the separate positional `guard_level_at` contract above; the depth formula
does not affect that guard base. Every exterior class has no surface level.
Shelf `mob_level_at` is nil at normalized y >= 0 and uses the depth term alone
at normalized y < 0; deep ocean and immutable channels have no ordinary mob-
level result. The fixed level-100 Kraken is the explicit deep-ocean exception
and bypasses the resolver. **Depth axis**
(decided 2026-08-06,
WP6, rate recalibrated 2026-08-08): overworld caves scale with depth —
`mob_level_at = max(surface_level(x,z), depth_level(y))`, **3 levels per
50 nodes** below y=0, capped at 60; ore tiers follow the same depth
axis, so mining deep is the alternative progression path to travelling
out. The visual-stratum starts are exact: Basalt at **−301**, Granite at
**−501**, Emberrock at **−701** and Abyssal Rock at **−1001**
(`items_crafting.md` §3.0.4). The level anchors therefore fall on the last node
before two transitions: **−500 = level 30** is the last Basalt node before
Granite, and **−1000 = level 60** is the last Emberrock node before Abyssal
Rock and the cap. What the rate really says is where depth **overtakes** the surface
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

The political/tool boundary is independent of the level formula: y = −700 is
the last shallow T4 node, y = −701 begins contested T5 and y = −1001 begins T6.
The surface column's race region continues to select deep regional resources,
but never changes the universal PvP/terrain rule below −700.

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
  within the **threat validity radius of 40 m** (= the leash radius): a
  stale entry from someone who left the fight can never pull the mob.
- **Leash/reset**: **40 m of DRAG measured from where THAT chase began**
  (the anti-kiting rule — not distance from home, or a mob that merely
  wandered would reset itself forever) or 15 s without player contact →
  threat table cleared, target dropped, drop tag cleared, mob heals to
  full. A reset mob then **evades home** (decided 2026-08-07, WoW
  model): if it stands further from its own post/spawn than its own
  leash radius, it **runs back visibly at 1.5× its run speed**, and
  while evading it is **untouchable** — every attack is cancelled
  outright (no damage, no weapon wear, no feedback) and it acquires no
  targets — until it arrives (~4 nodes from home), where it instantly
  becomes a normal mob again. Safety net: a mob whose straight walk
  home is blocked by terrain falls back to the old **teleport snap
  after ~40 s** — broken mobs self-heal, and in the normal case the
  player sees the mob recognizably run away instead of vanishing.
  A floating "Evade!" combat text is deferred until a combat-text
  system exists (future WP idea). Designated patrollers are exempt —
  being far from the post is their job. Mob-vs-NPC fights are not
  leashed.
- **Chase persistence**: a mob gives up a chase at **45 m**, not at its
  `view_range` (mobs_redo's default, ≤ 16 m for ground mobs — with it,
  neither the 25 m soft de-aggro nor the 40 m leash could ever fire). The
  45 m sits deliberately above the leash so the LEASH is what ends a
  chase, with a little hysteresis.
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
- **Close cover triggers navigation** (decided 2026-09-17). If a ground melee
  mob has spent about **1 s** inside reach without line of sight, it starts the
  existing bounded A* search despite already being close. It does not abandon
  that path merely because `dist < reach` while LOS remains blocked. If A*
  returns nil, it sidesteps perpendicular to the target for about **0.5 s**,
  alternating sides on consecutive failures, then tests LOS again. Immediately
  before moving, the actual selected side is checked for a cliff or dangerous
  ground; the other side is tried once, and if both are unsafe the mob stands.
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
  Across the server at most **2** A* searches start per server step. Mobs that
  miss that budget wait in FIFO order; each request has one generation-token
  entry. Cancellation invalidates only that generation, releases its strong
  entity-state reference immediately and puts any later request from the same
  mob at the tail. Death and unload cancel pending entries. At the standard
  **0.09 s** step, even **100** simultaneous live waiters each receive a start
  in at most **4.5 s**, before the **18 s** attack patience expires. The
  **0.25 s** per-mob backoff applies after an exhausted path, not to budget
  waiting. The contact run retains its existing `at_cliff` guard
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

## 5. Recovery (solo path)

- Natural regen: **0.5% max HP/s out of combat, 0 in combat** — in-combat
  healing is the healer's/potion's job.
- **Food v2 restore buff** (R7.1/R7.2, decided 2026-09-18; supersedes R9 from
  2026-09-17; `items_crafting.md` §3.7 owns the tier table). Eating grants a
  runtime-only **180 s** buff with one tick every **5 s**. Only one food status
  may run; the latest replaces it. Every food has fixed instant HP by tier.
  Out of combat that heal applies immediately. In combat the serving may be
  eaten, but the heal waits exactly once for the first out-of-combat moment,
  checked every second, and regeneration ticks do nothing. The unpaid instant
  heal survives the buff's 180-second expiry; regeneration and secondary
  modifiers still end on time.
  A newer serving replaces, rather than adds to, an unpaid instant heal. Death
  or leaving clears it. Combat never cancels or pauses the duration, and
  secondary status modifiers remain active in combat.
  - Raw/unprocessed food regenerates **1%** of maximum HP per tick at every
    tier. Wild Cocoa follows that HP rule and has no mana-pool requirement.
    Food restores mana only through the Caster dishes.
  - Dishes read their HP, mana or split regeneration plus secondary modifiers
    from tier data. Current cooked fish and meat are T1 HP dishes.
  - The natural replacement cadence is about **20 servings per hour**.
- **Healing potion**: instant **30% max HP, 60 s cooldown** (Alchemist
  craft; weak 15% variant sold by vendors). The potion holds the
  in-combat monopoly and is paid for in cooldown; a dish may restore
  more in total, but only out of combat and over seconds. Each food tick
  due during combat is skipped while the 180-second buff keeps running.
- **Alchemy v1** (2026-09-18): Healing and Mana Potions restore 30% of their
  current maximum pool and share one persistent 60-second clock. Their Greater
  T3 pair retains the 30% amount but starts that same clock for 45 seconds;
  the mana half may be consumed at full mana. Antivenom clears poison,
  Swiftness grants +10% speed for 5 seconds, and Cave Draught grants night
  vision for 10 minutes. One elixir status is active at a time and stacks with
  food: Vigor grants +5/10/15/20% maximum HP at T3–T6, Focus the same maximum
  mana, and Precision +1/2/3/4 percentage points crit. Stoneskin is +4% armor
  for 30 minutes and Deepwater grants water breathing for 10 minutes. Ordinary
  stat elixirs last 15 minutes. None of the elixirs touches the potion clock.
  Each worn Apothecary piece adds 10% duration to timed potions and elixirs
  and one percentage point to a stat elixir, with at most two pieces counted;
  instant potions are unchanged.
- Mana regeneration is **`1 + 0.15 × level` mana/s** out of combat (1.15 at
  L1, 2.5 at L10, 5.5 at L30, 10 at L60), multiplied by the Troll
  `ooc_regen_mult` perk. In combat the untalented base rate is
  **`max(0.25 × (1 + 0.15 × level), 0.0025 × maximum mana)`**; the Troll
  perk does not apply. Cold Focus multiplies whichever in-combat term wins by
  **`1 + 2 × bonus`**, preserving its old +20% per-rank relative effect (rank
  5 doubles the combat rate).
- Food regeneration and pool bonuses are percent-based, but consumables now
  have tier minimum levels through `_grug_ilvl`. The neutral base pool spans
  26 at level 1 to 2696 at level 60, while class factors and pool percentages
  remain independent.
  Plain-looking HP and Mana enchants are internally percentages of the base
  pool and show both that percentage and its current-level absolute value.
- Every timed effect on the player is shown through the **buff/debuff text
  list** (`inventory_equipment.md` §5, decided 2026-09-17). WP10 later
  replaces that first-pass presentation with icons.

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
  observer set for the per-viewer rule above. One central pass snapshots player
  positions and manages every carrier once per second; unchanged observer sets
  are not written. Carriers have no per-entity `on_step`: the central pass also
  removes an orphan, while explicit parent lifecycle hooks remove the ordinary
  cases immediately.
- **Con colors are per viewer** and live in a **HUD target frame** (the
  mob you look at/punch; nametags cannot be colored per viewer). The
  frame's **reach is 20 m** — our choice, not an engine constant: far
  enough past the 16 m view_range of our longest-sighted ground mobs to
  size up what is about to notice you, and inside the ability targeting
  ranges so what you can frame is roughly what you can hit. The frame
  also works on **players** (name + faction, faction-colored).
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

## 7. Offhand & carried light

- The engine has **no native offhand**; we build `grug_offhand` after
  VoxeLibre's `mcl_offhand` pattern (inventory list `"offhand"` + HUD
  slot).
- Equip rules (enforced centrally): **two-handed weapons require an empty
  offhand**; shields = Warrior; Mage focus item (tome/orb) as stat
  offhand; **dual wield reserved for the Rogue (Phase 2)**.
- **The mechanism of the two-handed rule** (decided 2026-08-08, shipped
  with WP35 — the weapon slot is the first place it can be enforced):
  items declare a hand count in `_grug_hands` (**greataxe 2, staff 2,
  sword/dagger 1**, the vendored `default:` swords and axes 1 — twelve when
  WP35 wrote this, **eight since WP25/WP43 deleted the mese and diamond tool
  tiers** (`grug_gear/init.lua`'s `VENDORED_WEAPONS` is the live list) —, no
  field = one-handed), and the weapon/offhand `allow_put` refuses any pair
  whose **two occupied hands add up to more than two**, in both
  directions, with a chat message that names the trade. Numbers, the
  eligibility list and why the vendored axes are one-handed:
  `inventory_equipment.md` §2. It is a **refusal**, never an automatic
  unequip of the other slot.
- Consequence, and it is a gameplay rule rather than a technicality:
  **carrying a torch costs you the two-handed weapon.** Greataxe and staff
  users choose between the light and their weapon; the refusal text says so
  rather than failing silently.
- **Torch in the offhand gives a moving light radius** (wielded-light
  technique: invisible light node at head height, moved only on
  node-position change, skipped when ambient light is bright; profile
  before relying on it for crowded servers).
- Synergy with destructibility R2: torches cannot be *placed* in enemy
  land but can be *carried* — at the cost of the offhand slot and of
  being visible at night.
- Endgame hook: rare items with a built-in light radius (no offhand
  cost).
- MVP scope: torch + shield first; class-specific offhands once the
  items exist.
