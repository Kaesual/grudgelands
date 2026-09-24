# Class Kits — Resources & Abilities (MVP)

Decided spec (last revised 2026-09-17; established 2026-08-06).
Implementation: WP4 (`grug_abilities`, resource HUD, damage pipeline hooks in
`grug_core`), WP19 (kit tuning, GCD, target memory), WP35 (§2b's universal
ability and §2c's ability-item skins), WP38 (§2b's proc model, which retires
WP19's GCD), and WP39 (crosshair-authoritative hostile combat, weapon-ready
reticle and projectile Fireball, shipped 2026-08-10); skill trees extend these
kits in WP11.
Attribute/derived-stat formulas: `combat_stats.md` §1/§2; threat values:
`combat_stats.md` §4.

**The WP11 skill-tree design is decided.**
[skill_trees.md](skill_trees.md) carries
two trees per class derived from the kits below, the talents that improve
their numbers, and the keystones and capstones that add new main skills —
Renew among them, as §5 already decided. A **fourth class, the Scout**
([scout.md](scout.md)): leather armour, a bow and a blade. A melee Scout uses
the equipped main hand as the sole weapon-damage source; an offhand never adds
a second strike, damage roll or talent axis. The numbers in the
§3-§5 tables become the **untalented base** values; and by the user's ruling
of 2026-09-16 the **Warrior's base kit drops to three abilities** (Charge,
Mighty Blow, Taunt), so that every class starts with Strike plus three:
**Hamstring leaves §3's table and returns as a talent**, the keystone of the
Warrior's Ruin tree. The same ruling removes **class changing** from the game
entirely, admins included.

Core principles:

- **Instant abilities + cooldowns, no cast times in the MVP.** Cast bars
  (and pushback) may come later for selected spells; the Home Stone's 10 s
  cast ([housing.md](housing.md) §4) is its own mechanic and stays.
- **Abilities use indestructible, bound inventory representations.** The base
  kit, including Strike, is inserted once at character creation. Representations
  may be carried in main inventory or owned bags; dropping or returning one to
  Skills deletes only that copy, without a world drop or lost entitlement.
  The Skills catalogue restores an unlocked ability only when no carried copy
  exists. External storage, equipment slots and trading refuse these items.
  Reconnect and talent changes normalize existing copies without re-granting
  discarded ones. Left click attacks or casts; the wear bar shows the skill's
  charge or cooldown. Appearance follows §2c.
- **Skills pick up drops within hand reach.** A fresh physical LMB press
  attempts pickup of the first visible dropped item within 4 m exactly once.
  Combat range never extends pickup reach; pickup does not also cast.
- **No global cooldown** (removed 2026-08-09 with the proc model of §2b;
  it was 1.0 s from 2026-08-06 to WP35). A GCD existed to stop instant
  chaining, and the two limiters that replaced it do that job better and
  visibly: each skill has its **own** charge timer, and every effect costs
  a **resource**. A flat second on top of both only added an invisible
  delay — and against §2b's swing skills it would have capped attack speed,
  which is the defect that already made the Strike an exception.
- **Target memory is not action aim authority** (healing revision decided
  2026-09-24). Enemy and
  ally use separate 8 s slots. The enemy slot feeds only the Target Frame and
  other UI context: no melee hit, hostile cast or projectile may fall back to
  it. Hostile damage always follows the current crosshair ray. The ally slot
  must not redirect heals or shields; those use a currently pointed valid ally
  or the caster. Owner death, respawn, disconnect or class sync
  clears both slots, and a dead/unloaded/left target is invalidated.
- **Every ability declares one target kind.** `hostile` requires a current
  living hostile player or combat-capable mob; a client label or remembered
  target cannot override the server's faction check. Civilian non-combatants
  are never hostile targets: direct casts refuse them, projectiles pass through
  them and hostile area effects skip them. `friendly` accepts another living
  same-faction player. Friendly skills resolve to a currently pointed valid
  ally within the skill's range and line of sight, otherwise the caster.
  There is no remembered-ally fallback; looking into empty space always selects
  self (user ruling 2026-09-24).
  Service NPCs, guards and mobs are not player party
  members and cannot receive player heals or shields. `self`
  ignores all pointed and remembered objects and anchors the
  cast on its user. Strike, Charge, Mighty Blow, Hamstring, Taunt, Fireball and
  Smite are hostile; Frost Nova and Blink are self; Flash Heal, Power Word:
  Shield and Renew are friendly. A friendly skill's documented self fallback
  remains part of that skill, not a fourth target kind.
- Three to four abilities per class in the MVP; **new active "main
  skills" come from talent capstones** (WP11, progression.md) — talents
  otherwise improve existing buttons rather than adding many new ones.
- **Balance constraints** (decided 2026-08-06): group content is sized
  for **2–3 players**, and every encounter must be **beatable without a
  healer** (food/potions as the substitute) — the Priest makes groups
  comfortable, never mandatory.
- **Numeric ability tooltips are player-specific.** Damage, healing and absorb
  numbers show the effective current-level value before Crit and target-level
  malus. Absorb settlement retains fractional points; its tooltip displays
  that seam's value rounded down. Smite shows its unshielded damage and, when
  Warded Wrath is ranked, a separately scaled `(+N while shielded)` suffix;
  changing only the current shield state does not change its tooltip. The
  registered item definition keeps a number-free fallback; the player's
  ability ItemStack carries the effective description and refreshes on kit
  sync, level change and talent change. Strike's player-specific rage sentence
  is additionally resource-gated as decided on 2026-09-18: only a rage-resource
  class receives it; mana-resource and class-less characters retain the
  class-neutral swing text (§2b).

## 1. Resources

| Resource | Classes | Pool | Regeneration |
|----------|---------|------|--------------|
| Mana | Mage, Priest | `round(20 + 5L + 0.66L²)`, before mana-percent gear/talents (combat_stats §2) | 2%/s out of combat, 0.5%/s in combat (combat_stats §5) |
| Rage | Warrior | 0–100, starts at 0 | **+8** per landed §2b authoritative swing; ordinary tools/fists retain proportional native credit (combat_stats §2); **+3** per hit taken, +15 from Charge; decays **5/s** out of combat. Ruling 25 of 2026-09-16 lowered the income and raised the decay — the ledger and what it buys are in §3 |

- **Rage is granted on damage that actually landed**, not on a swing
  attempted: a target that cancels the punch (a vendor NPC, an evading
  mob), an `immune_to` mob or a player with PvP off yields **0 rage**.
  PvP refusal, dodge and full absorb likewise pay 0 (`combat_stats.md` §2).
- **In combat** = dealt or received damage within the last 5 s. The
  definition lives in `grug_core` (`mark_in_combat`/`in_combat`) and is
  shared with recovery (combat_stats §5) and mob leashing (WP6).
- Resources are runtime state, not persisted: mana is full on join and
  respawn, rage is 0.
- Mana costs are rounded percentages of the caster's unmodified base pool,
  minimum 1. Full-pool cast counts at L1/L60 are: 5% = **26/19**, 6% =
  **13/16**, 8% = **13/12**, and 10% = **8/9**. Pool enchants and talents do
  not increase costs. Flash Heal therefore supplies at least 12 casts at
  either endpoint; four untalented 25% casts equal one neutral health pool
  before spell power, leaving capacity for a normal fight and another.
- **HUD: one thin bar per resource, directly above the hotbar slots**
  (user ruling 2026-09-16, shipped in round 4; it replaces the colored
  resource *line* this bullet used to describe). Every class has exactly one
  secondary bar — rage **or** mana, never both — in the same two colors
  (mana `0x4a9bd8`, rage `0xc41e3a`), with the exact numbers written inside
  the bar. The life bar sits directly above it in the same style, and the
  builtin half-heart statbars are off: half hearts were rejected as "an ugly
  approximation", and at 3235 HP one of the engine's ten hearts is 323.5 HP
  (161.75 HP per half heart, which is the step it actually draws). A
  character who has not picked a class yet keeps the secondary row reserved
  and empty, so nothing moves when the class arrives. The column the bars
  belong to is owned by `grug_core/hud_layout.lua`; no mod carries an offset
  of its own **into that column**. Details and what is still open:
  `docs/research/hud-bars.md`.

## 2. Damage pipeline (grug_core)

- Ability damage/heals go through `grug_core` helpers that roll **crit**
  (attacker's chance, ×1.5) and — for player targets — **dodge**
  (combat_stats §2), then apply via `object:punch` so armor groups and mob
  death handling (XP, loot) keep working. Implicit ordinary knockback is zero;
  only an explicit `damage_groups.knockback` override displaces the mob
  (`mobs/api.lua:3455-3481`).
- Mob→player punches roll the player's dodge centrally (hp change
  modifier in `grug_core`).
- **Target-race equipment effects use the same central transaction.** A
  weapon's T4/T5/T6 counter finish adds +1/+2/+3 flat damage to an accepted
  attack sourced from that equipped weapon, after the one ordinary Crit result
  and before armor/absorb; Crit never multiplies it. It does not ride on a
  spell merely because the held skill uses the weapon's appearance. An
  active Warding Draught applies its 5/7.5/10% target-race reduction after
  armor and before absorb. Both require matching race identity on a hostile
  player or combat-capable NPC/mob and ignore passive invulnerable service
  NPCs. Stacking and recipe rules: `items_crafting.md` §4.3.
- **Melee carries the melee bonus and rolls crit** (combat_stats §2). Swing
  ability stacks mirror the equipped weapon's interval for native
  animation/interaction but publish zero damage; their combat packets are
  input only, and the authoritative held loop builds a full slot-fed swing
  against the current server ray. Ordinary tools and fists do not initiate player combat; only selected
  skills may attack.
- **Threat hooks are stubs in WP4** (`grug_core.add_threat`,
  `add_heal_threat`): abilities already report their threat values
  (combat_stats §4: tank abilities ×3, healing ×0.5); WP6 replaces the
  stubs with the real threat table. Taunt's forced-target effect works
  already via mobs_redo `do_attack(player, force)`.

## 2b. Contextual skill input

All selected skills support native empty-hand digging and zero native combat
damage. Swing versus cast describes the effect, not a different mouse binding.
Only skills initiate player combat; ordinary tools retain their gathering role.
The equipped Weapon slot is the combat source, never a weapon in the hotbar.

### Left click and held input

The current first visible crosshair target determines the action. Held LMB may
move between combat, hand digging and empty space without releasing. Every
operation checks its own reach: 4 m interaction/digging, 3 m Strike, and the
selected spell's authored range. Solid terrain and intervening objects matter.

- **Hostile:** use the selected applicable ready skill immediately. If it is
  unavailable (including cooldown, resources or applicability), use ordinary
  melee Strike when in range. Holding repeats at the appropriate clocks;
  once the selected skill is ready it takes precedence again. An applicable
  heal here targets self, never the hostile or a remembered ally.
- **Friendly player:** use an applicable heal/support action on the currently
  aimed eligible ally. No Strike fallback or attack through that ally.
- **Hand-diggable node:** dig with hand capabilities, never equipped-weapon
  mining power. On the initial press only, a competing usable self/support
  skill waits approximately 200 ms: short release casts; continued hold digs.
  Without such a competing action, digging begins immediately. Leaving the
  initial node discards its pending release-cast. Later held retargeting enters
  digging directly; a cooldown becoming ready cannot interrupt the dig.
- **Dropped item:** one pickup attempt at the beginning of each physical press,
  including when inventory is full. That decision does not also cast. Holding
  may subsequently dig or attack, but another drop requires another press.
- **Empty or otherwise inapplicable context:** one applicable self/support
  activation per press, otherwise no mechanical effect. Retargeting while held
  may enter combat or digging.

Block progress belongs to the current node and is lost on retargeting. Apples,
plants and torches require positive digging time; the initial torch timing is
0.3 s. Actual removal preserves normal node callbacks, protection, `can_dig`,
drops and empty-hand tool restrictions. A skill's charge wear is never mining
wear. Crack feedback may begin during click arbitration, but removal may not.

### Scheduling and effect boundaries

Selected skill and fallback Strike are mutually exclusive in one decision.
After a successful skill, Strike must wait at least the actual weapon interval,
without shortening a later existing deadline. Skill cooldowns/cast intervals
still apply; no global cooldown is added. Early clicks, release/repress,
retargeting and skill swaps cannot reset the weapon clock. Concrete equipped
weapon changes start a full interval; lag never replays missed attacks.

Combat and healing actions repeat against appropriate aimed targets. Movement
utilities such as Blink and Sprint activate once per physical press, even if
cooldown expires during the hold; Frost Nova remains a combat action. In empty
space self/support actions fire only once per press.

A melee attempt uses a single-use authoritative transaction for the current
ray-selected hostile. Native skill punch packets are acquisition/input only,
not another damage stream. Aim misses do not spend the weapon interval;
a valid attempted attack does, including a later dodge, immunity or rejection.
Existing damage, resource/proc acceptance, PvP, absorb and wear boundaries remain.
Enemy target-frame memory is presentation only and never authorizes an attack.
Friendly spells choose the current eligible visible in-range ally, otherwise
self; already-applied periodic effects retain their original recipient.

### Right click

A short RMB interaction opens the aimed NPC, door, container or other normal
interactive target. An interaction owns that press until release and cancels
pending item actions; it cannot also consume food or launch a bow. Interaction
reach remains 4 m even with a long-range spell selected.

Loose is the explicit exception to LMB casting: **LMB uses melee Strike or hand
digging; hold RMB to draw, release RMB to shoot.** Its tooltip states both.
Other instant bow skills retain their LMB casts and authored ammo/cooldowns.
Food requires 1.5 s uninterrupted RMB hold for one serving and eating sound at
half gain; release rearms consumption. Active RMB food/draw suppresses LMB
combat/digging. Seeds, buckets, hoes, fishing, mounts and ordinary placed items
retain their own context-appropriate actions.

### Cancellation and native-client limits

Stun, death and item swap cancel pending actions. Our own NPC/node interactions
cancel before opening. Native inventory, pause, chat and focus loss are observed
as ordinary release: they may launch a drawn bow or resolve a pending short
skill click. Very fast air clicks (under roughly 90 ms at the default server
step) can fall between control reports; node/object events supply additional
press evidence. Both limitations are explicitly accepted for the playtest;
no client changes are required or promised.

### The weapon-ready reticle

- Weapon readiness is **binary** and separate from every skill's charge. With a
  swing skill selected, a small gold ring overlays the ordinary crosshair only
  while the weapon clock is ready; it is absent while the weapon interval is
  running and when no swing skill is selected. It does not indicate that a
  target is valid.
- An aim miss leaves the ring visible. Starting one valid attack hides it
  immediately; it returns once the equipped weapon interval expires. A dodge,
  immunity or other post-aim rejection therefore still hides it for the normal
  interval.
- This is a HUD state transition, not an ItemStack wear bar. It sends only the
  not-ready and ready changes of the selected weapon clock; it never rewrites
  inventory on a progress tick and has no smooth intermediate frames.

### Rules for hostile casts and projectiles

- Charge, Taunt and Smite require a currently pointed valid hostile within
  their own range and server-validated line of sight. They never fall back to
  enemy target memory. No valid target means no effect, resource payment or
  cooldown.
- Fireball and Scout arrows lock a current in-range visible hostile at actual
  release, then home for a bounded launch-time flight duration. No target means
  no shot/resource payment. After launch, terrain/characters do not intercept
  and range is not rechecked. Damage resolves once at impact through existing
  defenses; invalid lifecycle/target cancels. See `combat_stats.md` for the
  shared Round 17 contract, also used by non-player projectiles.
- Fireball retains 6% base mana, 20 m initial range, 20 m/s nominal speed and
  baseline weapon damage + spell power, with existing talent modifiers.
- Friendly heals and shields resolve through currently pointed valid in-range
  visible ally → self, with no ally-memory fallback (user ruling 2026-09-24). A hostile, NPC, guard, item or dead player
  is not an eligible ally target. Input routing may consume a drop click for
  pickup before a spell is invoked; that does not alter spell target resolution.

### The charge bar

- A **charging** skill shows a bar under its hotbar icon that grows from
  left to right and runs **red → yellow → green** as a continuous ramp, no
  fixed intermediate states. A **fully charged** skill shows **no bar** —
  being ready is the default, and the absence of a bar is the signal.
- This is the item **wear bar**, driven by the charge instead of by a
  cooldown: `wear = (1 − charge) × 65534` (the game's wear cap is 65534,
  not the engine's 65535 — a fully worn item reads as broken). The engine
  defines durability as
  `1 − wear / 65535` and derives both bar length and color from it, and it
  draws nothing at `wear = 0`. The color ramp is `set_wear_bar_params` with
  `blend = "linear"` and stops at 0.0 red / 0.5 yellow / 1.0 green.
- **The bar's resolution is set by the TICKER, not by `WEAR_STEPS`, and the
  packet cost is 2/s per player at worst** (measured against the engine
  source 2026-08-09, correcting a first draft of this bullet that claimed
  a per-skill cost):
  - Wear writes are driven by the **one shared 0.5 s globalstep** that
    already serves every ability of every player. There is no per-skill
    loop and there must never be one.
  - The engine **coalesces**: `ServerEnvironment::step` sends a player's
    inventory at most once per environment step, and only if it was
    modified (`src/serverenvironment.cpp`). Ten skills charging at once
    therefore cost exactly what one costs — **one packet per tick, so ≤ 2
    per second per player**, and none at all while nothing is charging.
  - The packet is **incremental at list granularity** (`Inventory::serialize`
    writes `KeepList` for untouched lists), so a wear write on `main`
    leaves the eight equipment lists, the bag lists and `craft`
    unserialized. Per-*slot* incremental is an unimplemented TODO in the
    engine (`src/inventory.cpp`), so the `main` list itself goes out whole.
  - Consequence for the look: a bar can only move `charge_time / 0.5 s`
    times. **Rule: the ticker stays at 0.5 s** — speeding it up is the one
    change that actually costs packets, and it is not worth a smoother
    bar. **Recommendation, not a gate: charge times of at least 2 s, and
    3–4 s reads better** (4 visible steps already say "charging, nearly
    there"; 6–8 look continuous). A skill may still have no charge at all
    and be limited by its resource alone — Mighty Blow is exactly that.
    Set `WEAR_STEPS` to 32 so the quantizer is never the binding
    constraint; the ticker is the only knob.
  - The Strike's old `no_cooldown_display` exception disappears with the
    model: it has no charge, so it has no bar.

### Strike

Strike is the **universal** ability — no class owns it, every character has
it, including one that has not picked a class yet.

| Ability | Cost | Charge | Effect |
|---------|------|--------|--------|
| Strike | free | none — it is the plain attack | Native melee (3 m) with the item in the weapon slot: weapon damage + floor(melee attribute/10) (Scout Dex, otherwise Str), crit ×1.5, threat ×1. Grants the Warrior 8 rage per landed swing (§1, §3). Hold or click LMB. |

- **Granted to every class and to a classless character**, and placed
  **first in the hotbar** so it lands on key 1 for everyone — a fresh
  character is never standing in the world with no way to fight back.
- **Free**, because it is what *generates* the Warrior's resource.
- **Tooltip resource gate** (decided 2026-09-18): the sentence
  `Generates <8 + Stoke bonus> rage when it lands.` is rendered only for a
  character whose class resource is rage. Mana-resource classes and class-less
  characters see the swing text alone.
- It is the **"no effect" slot**: the baseline every other swing skill is
  measured against, and the slot to sit on while the others charge.
- **An empty weapon slot makes it weak, never uncastable**: it swings for
  the bare-hand baseline. The same holds for every weapon-scaled class
  ability.
- It is **melee**, so the elf's +5 m ability-range passive (`world.md` §7)
  does **not** apply to it — that perk is a **ranged/spell** bonus, or an
  elf would carry an 8 m sword. The melee class abilities (Mighty Blow,
  Hamstring) keep their 3 m for the same reason.
- **Hostile players are valid targets**, through the same friendly-fire
  check, dodge pre-roll and threat report as every other ability.

## 2d. Ability entitlement and the Skills catalogue

A character permanently sees every currently unlocked active ability in the
Inventory > Skills catalogue. Initial class creation grants the universal and
base-class starter kit once. Later talent unlocks are acquired manually from
Skills; talent changes, joins and equipment changes never recreate a deleted
representation. Losing a talent removes its representation.

At initial character creation, the base abilities occupy the first inventory
slots in kit order: Strike on key 1, then the remaining class abilities, then
starter supplies. Existing carried items are preserved. This startup arrangement
does not reorder the player's inventory on joins or talent changes.

Ability items may live in `main` or the character's four owned bag-content
lists. `craft`, equipment, quivers, bag slots, nodes, detached inventories and
other characters refuse them. Dropping one deletes the representation without
changing entitlement or combat state; dragging it back to its matching Skills
entry does the same. Recovery is available only when no copy exists in `main`,
`craft` or any owned bag, and snapshots current skin, description, range and
cooldown/charge display. Server ledgers remain authoritative.

## 2c. What an ability item looks like

Revised 2026-09-23, Round 18:

- Every active class/talent ability has a recognizable action icon in inventory,
  hotbar and Skills catalogue. It does not composite the equipped weapon into
  that icon. The skill name still appears briefly on selection.
- First-person wield and third-person held presentation still use the equipped
  weapon (or the ability's declared equipment source); utilities follow the same
  rule. Swapping equipment refreshes presentation without changing the action icon.
- Preserve bow draw stages, cooldown/charge wear, material-tier weapon appearance
  and honest empty-slot presentation. Icons grant no entitlement or combat power.
- Existing accepted weapon and armor media are unchanged. The round delivers a
  reviewed active-skill contact sheet and provenance for imported/generated icons.

## 3. Warrior (Rage)

Tank/melee. All Warrior abilities count as tank abilities: **×3 threat**.

Kit tuning decided 2026-08-06 (implementation: WP19): Mighty Blow became
the rage DUMP (no cooldown — at the income of the day a cooldown left the
Warrior permanently rage-capped), Hamstring added as the control tool (in
an engine where mobs outrun players, the snare is the Warrior's identity).

**The numbers below are the UNTALENTED baseline.** Eighteen WP11 talents
re-tune exactly these values (`skill_trees.md` §2.10), and a talented Taunt or
Mighty Blow is the design working, not a bug.

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Charge | — (generates 15 rage) | cast, 10 s | Dash to the currently pointed enemy up to 12 m away, 3 damage and, on an accepted hit, a 1.5 s stun. Kings and dragons are stun-immune. Teleport movement is retained; no enemy-memory fallback. |
| Mighty Blow | 25 rage | **swing**, no charge | On a completed landed swing with enough rage, the total is exactly floor(weapon damage × 1.5) + melee bonus instead of the plain hit. Its delta is folded into that native punch before its one crit/mitigation/dodge path — never a second punch. The rage dump. |
| Hamstring | 10 rage | **swing**, 6 s charge | The swing lands as usual; on a charged proc it also applies a 50% slow for 5 s. **Not in the base kit since ruling 19** (2026-09-16): every class starts with Strike plus three, and Hamstring returns as the Ruin tree's keystone (`skill_trees.md` §2.2). It stays registered and talent-gated, exactly as Renew has been since WP19. |
| Taunt | free | cast, 8 s | Currently pointed mob (8 m) is forced onto the Warrior for 3 s; no enemy-memory fallback; threat set to top×1.1 (combat_stats §4; threat part + force duration land with WP6). |

### The rage ledger (ruling 25, 2026-09-16)

The user's finding of 2026-09-16 was that **rage fills too fast** — "in combat
the resource is effectively unlimited". Ruling 25 answers it with **option
(b): lower the income and add decay**. These are the current numbers.

| Source | Rage | Note |
|--------|------|------|
| a landed full swing | **+8** | was +12. Paid proportionally by an ordinary tool or fist: a native packet worth fraction *f* of a swing pays 8·*f*, so the accumulator still integrates to one swing's grant per whole swing. |
| a hit taken | **+3** | was +4. The orc race passive adds +1 (`world.md` §7). |
| Charge | +15 | unchanged; it is an engage tool, not income. |
| out of combat | **−5 per second** | was −2 per second, on the same 5 s `grug_core.in_combat` window. |
| cap | 100 | unchanged. |

What that buys, from an empty bar: **13 landed swings to full** instead of 9,
**4 swings per Mighty Blow** instead of 3, and a full bar bleeds out in
**20 seconds** of peace instead of 50. A swing skill with no charge timer is
still limited by its resource alone — which is what Mighty Blow was built to
be — but the limit is now something the player feels.

Two WP11 talents lean on this ledger and are calibrated against it: **Stoke**
(Ruin, +1 rage per landed swing per rank, so 4/4 restores the old +12) and
**Spite** (Bulwark, +1 rage per hit taken per rank, so 5/5 reaches +8).

## 4. Mage (Mana)

Ranged damage; fragile, keeps enemies away.

Kit tuning decided 2026-08-06 (implementation: WP19): Fireball pays with
mana plus a 1 s cadence instead of a talent-visible cooldown (the former fixed
5 mana against a 240+ pool was free), Frost
Nova became the rotation pivot — kiting IS the Mage fantasy here.

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Fireball | 6% base mana | **1 s cast interval** (server cadence, no cooldown bar) | Targeted homing projectile, nominal 20 m/s and initial range 20 m; current aim/LOS required at release. Baseline weapon + spell power through the damage fit at impact. No target or input inside the interval costs nothing; at most eight shots per owner/session may be active. |
| Frost Nova | 10% base mana | 12 s | Deals one quarter of (level-baseline weapon damage + spell power), then roots accepted hostile hits within 5 m for 4 s, followed by 50% slow for 3 s. Spell damage scaling applies once. Players use the hard-root movement flag; rooted targets may still attack. Small crystal particles persist only while the Nova root is active. |
| Blink | 8% base mana | 15 s | Teleport up to 10 m in look direction (blocked by walls). Escape valve. |

## 5. Priest (Mana)

Healer/support with a solo damage tool.

Kit tuning decided 2026-08-06 (implementation: WP19): **Power Word:
Shield replaces Renew** in the base kit (an absorb plays differently
from a second heal and makes the Priest useful BEFORE damage lands; our
central hp-change modifier makes absorbs nearly free to build). Renew
moves into the talent tree.

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Smite | 5% base mana | 2 s | Current-crosshair 20 m hit with no enemy-memory fallback: 1.5 × (baseline weapon + spell power), then the damage fit. Solo viability. |
| Flash Heal | 8% base mana | 4 s | Heals 25% of the class-neutral base pool, with spell power as a percentage bonus. Resolves currently pointed valid ally (15 m) → self. Threat: 0.5× effective healing (WP6). |
| Power Word: Shield | 8% base mana | 10 s | Resolves currently pointed valid ally → self; soaks 25% of the class-neutral base pool plus the spell-power percentage for 15 s or until consumed. |
| Renew *(talent)* | 6% base mana | 8 s | Resolves currently pointed valid ally → self; heals 8% of the class-neutral base pool plus the spell-power percentage every 3 s for 12 s. Unlocked via the Mercy tree (WP11). |

## 6. Explicitly deferred

- Cast times / cast-bar spells, ability sounds → Phase 3 polish.
  (**Ability icons are no longer deferred**: Round 18 separates action icons from held weapon art; historically an ability
  item shows the equipped weapon plus its own color — §2c.)
- Warrior shield abilities → after WP14 (offhand/shields).
- Buffs/auras (e.g. Battle Shout) → with skill trees
  (WP11) or later. (Power Word: Shield moved into the base kit with the
  WP19 kit tuning, §5.) Party frames are implemented under the separate
  [party contract](parties.md).
- The Scout has no player poison mechanic and no player poison stat. Its Veil
  tree uses existing dodge, crit, slow and escape mechanics. Mob poison and
  Alchemist Antivenom remain separate world mechanics. Stealth is deferred in
  [scout.md](scout.md) §8; the current Veil capstone is Untouchable.
- PvP tuning of roots/taunt (diminishing returns etc.) → balancing pass.

### Round 16 control execution

Stun prevents voluntary movement and all new or pending skills, native melee,
held swings and bow release. Pending input is discarded without catch-up bursts;
already launched projectiles continue. Gravity is unchanged. Stun and root have
independent lifetimes; root/slow immunity does not grant stun immunity. Death
and disconnect clear player control. Nova respects accepted damage/PvP gates
and movement immunity. Its baseline excludes Fireball-specific talents; Rimebite
adds its existing flat damage and half spell power once before spell scaling.
