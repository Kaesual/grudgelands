# Class Kits — Resources & Abilities (MVP)

Decided spec (last revised 2026-08-10; established 2026-08-06).
Implementation: WP4 (`grug_abilities`, resource
HUD, damage pipeline hooks in `grug_core`), WP19 (kit tuning, GCD, target
lock), WP35 (§2b's universal ability and §2c's ability-item skins), WP38
(§2b's proc model, which retires WP19's GCD); skill trees extend these
kits in WP11. Attribute/derived-stat formulas: `combat_stats.md` §1/§2; threat
values: `combat_stats.md` §4.

Core principles:

- **Instant abilities + cooldowns, no cast times in the MVP.** Cast bars
  (and pushback) may come later for selected spells; the Home Stone's
  10 s cast (world.md §6) is its own mechanic and stays.
- **Abilities are hotbar items** (indestructible, not droppable/tradeable,
  locked to the main inventory; granted at class pick, except §2b's
  universal Strike, which is granted on join). Left click = attack or cast
  at the pointed target; the item's wear bar displays the skill's **charge
  bar** (§2b). What the item *looks* like is §2c.
- **An ability item picks up dropped items like a weapon does.** Swing skills
  have no `on_use`, so their native punch reaches the builtin item entity
  directly. Cast skills retain the WP38 pickup bridge because their `on_use`
  makes the client send `INTERACT_USE`; clicking loot calls the entity's
  pickup path and does **not** cast.
- **No global cooldown** (removed 2026-08-09 with the proc model of §2b;
  it was 1.0 s from 2026-08-06 to WP35). A GCD existed to stop instant
  chaining, and the two limiters that replaced it do that job better and
  visibly: each skill has its **own** charge timer, and every effect costs
  a **resource**. A flat second on top of both only added an invisible
  delay — and against §2b's swing skills it would have capped attack speed,
  which is the defect that already made the Strike an exception.
- **Soft target lock** (WP19): the last punched/pointed enemy or ally
  stays the implicit target for ~8 s; abilities default to it (makes
  healing moving allies possible).
- Three to four abilities per class in the MVP; **new active "main
  skills" come from talent capstones** (WP11, progression.md) — talents
  otherwise improve existing buttons rather than adding many new ones.
- **Balance constraints** (decided 2026-08-06): group content is sized
  for **2–3 players**, and every encounter must be **beatable without a
  healer** (food/potions as the substitute) — the Priest makes groups
  comfortable, never mandatory.

## 1. Resources

| Resource | Classes | Pool | Regeneration |
|----------|---------|------|--------------|
| Mana | Mage, Priest | 10 + 2×Int (combat_stats §2) | 2%/s out of combat, 0.5%/s in combat (combat_stats §5) |
| Rage | Warrior | 0–100, starts at 0 | +12 per landed native melee swing (all §2b swing skills, plus tools and fists — combat_stats §2), +4 per hit taken, +15 from Charge; decays 2/s out of combat |

- **Rage is granted on damage that actually landed**, not on a swing
  attempted: a target that cancels the punch (a vendor NPC, an evading
  mob), an `immune_to` mob or a player with PvP off yields **0 rage**.
  Held-button PvP banks partial-swing credit until an integer damage commit;
  a commit that loses HP pays the whole pending credit, while a dodge or full
  absorb pays 0 and discards it (`combat_stats.md` §2).
- **In combat** = dealt or received damage within the last 5 s. The
  definition lives in `grug_core` (`mark_in_combat`/`in_combat`) and is
  shared with recovery (combat_stats §5) and mob leashing (WP6).
- Resources are runtime state, not persisted: mana is full on join and
  respawn, rage is 0.
- HUD: a colored resource line (mana blue, rage red) above the XP line.

## 2. Damage pipeline (grug_core)

- Ability damage/heals go through `grug_core` helpers that roll **crit**
  (attacker's chance, ×1.5) and — for player targets — **dodge**
  (combat_stats §2), then apply via `object:punch` so armor groups,
  knockback and mob death handling (XP, loot) keep working.
- Mob→player punches roll the player's dodge centrally (hp change
  modifier in `grug_core`).
- **Native melee carries the melee bonus and rolls crit** (combat_stats §2).
  Swing ability stacks mirror the equipped weapon's damage and interval in a
  per-stack `tool_capabilities` override; tools and fists use their own
  capabilities. Both then enter the same proportional mob/PvP pipeline.
- **Threat hooks are stubs in WP4** (`grug_core.add_threat`,
  `add_heal_threat`): abilities already report their threat values
  (combat_stats §4: tank abilities ×3, healing ×0.5); WP6 replaces the
  stubs with the real threat table. Taunt's forced-target effect works
  already via mobs_redo `do_attack(player, force)`.

## 2b. How a skill fires — swing skills and cast skills

Revised **2026-08-10**, ships as the WP38 native-input correction. It replaces
both the model of
2026-08-08, in which every skill owned the melee clock while its own
cooldown ran, and WP38's short-lived server-side toggle loop. Rationale and
the melee side of it: `combat_stats.md` §2.

Every ability is one of **two kinds**, and the kind is a property of the
ability, declared where it is registered:

1. **Swing skills** — LMB **is Luanti's native object punch**. The skill item
   has no `on_use`; holding LMB repeats and animates natively, while clicks
   use the same `time_from_last_punch` damage fraction. The skill's own effect
   rides along on a completed landed swing, but only when charged. Today
   exactly the three melee abilities: Strike, Mighty Blow, Hamstring.
2. **Cast skills** — a discrete action that is not a weapon swing: heals,
   shields, Blink, Frost Nova, Smite, Charge, Taunt. A gap closer is
   wanted *now*, from 10 m, and a heal must not require punching the
   patient. These keep the familiar shape: a cost, a cooldown, a target.

The whole Mage and Priest kit is cast skills, and stays that way until
ranged auto-attacks exist (`combat_stats.md` §2) — a bow or a wand is what
turns Fireball into the same kind of proc that Mighty Blow is.

### Rules for swing skills

- **A skill never makes you slower or weaker than the bare weapon.** Every
  granted swing ItemStack mirrors `fleshy` damage and
  `full_punch_interval` from the equipped weapon slot, with no digging
  groupcaps and no item wear. Its item definition also marks the hand digging
  groups (`crumbly`, `snappy`, `oddly_breakable_by_hand`) and the engine's
  independent `dig_immediate` path as `pointabilities.nodes = "blocking"`:
  objects remain natively punchable, but killing a mob while holding LMB
  cannot roll straight into digging the ground or leaves. An empty slot
  mirrors the registered hand.
  Holding and click-spamming therefore integrate to identical damage; only
  clicking slower than the interval loses DPS (`combat_stats.md` §2).
- **Every skill charges on its own timer, and the timer runs always** —
  including while the skill is *not* selected. That is what makes the
  hotbar a rotation: several skills come up during a fight and are spent in
  consecutive swings.
- **Charges do not stack.** One charge maximum, and a full charge never
  decays. Stacking would bring back burst hoarding; decay would punish a
  player for looking at the map.
- **One bounded proc-progress accumulator tracks native punch fractions.** It
  carries overflow, completes at 1, and can complete at most once per packet.
  It resets on target or concrete equipped-weapon change, death, respawn,
  class sync and disconnect — **not** on a switch between swing skills.
- **A completed landed swing with a charged skill selected fires the effect
  and resets that skill's charge.** Only the *selected* skill is read at the
  completion, so only one effect can ride on one swing. Evade, immunity, PvP
  refusal, dodge and full absorb pay no cost, consume no charge and fire no
  effect.
- **A bank-only PvP completion waits for an HP outcome.** If its fractional
  damage has not yet reached an integer, the exact selected proc is frozen
  beside the damage remainder and its cost is reserved but not paid. The
  reservation cannot be spent by another skill or out-of-combat decay. The
  later integer commit fires and pays it exactly once only if HP falls; dodge
  or full absorb releases the reservation and leaves the charge armed. The
  already accepted swing progress remains consumed in that case. Target or
  concrete-weapon change discards damage remainder, rage credit and pending
  proc together; a switch among swing skills never changes the frozen proc's
  identity.
  Target leave and death invalidate every attacker's Core damage/rage/pending
  bank synchronously. Death clears the remaining ability-only swing progress
  on the next engine step, after the killing punch settles; a committed proc is
  already held in that punch's local preview before HP changes. The shared 0.5 s
  wield watcher is a fallback for an invalid pending PvP ObjectRef. Ordinary
  mob progress has no pending reservation and resets by target identity on the
  next swing. A new concrete player ObjectRef never inherits the same name's
  old transaction.
  Wielding a non-swing item is likewise a reset boundary; switching among
  swing skills is not. Entering any cast clears synchronously before its
  affordability check, so a cast-and-switch-back inside one watcher interval
  cannot preserve or spend a frozen proc. The cast item's `on_use` clears
  before even its dropped-loot early return; direct `try_cast` callers repeat
  the operation idempotently.
- **The resource cost is paid at the proc, and an unaffordable proc does
  not consume the charge.** This is the decision layer: Mighty Blow's rage
  is the reason to keep swinging with it rather than to spend the rage
  elsewhere. Silently not firing is correct — a warning on every swing
  would be noise.
- **Rotation is the hotbar.** Keys 1–8 pick which effect is armed; no cast
  click is needed to switch. Switching between swing skills preserves proc
  progress, so the newly selected charged skill rides on the next completed
  swing. Switching away stops attacks naturally because there is no
  server-generated stream.
- **There is no auto-repeat toggle and no server swing loop.** Pressing LMB
  attacks; holding it uses the client's native repeat and animation; releasing
  it means no later attacks. Swing skills hit only the object currently under
  the crosshair. The soft target lock remains for cast targeting, not for an
  invisible auto-swing.

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
| Strike | free | none — it is the plain attack | Native melee (4 m) with the item in the weapon slot: weapon damage + floor(Str/10), crit ×1.5, threat ×1. Grants the Warrior 12 rage per landed swing (§1). Hold or click LMB. |

- **Granted to every class and to a classless character**, and placed
  **first in the hotbar** so it lands on key 1 for everyone — a fresh
  character is never standing in the world with no way to fight back.
- **Free**, because it is what *generates* the Warrior's resource.
- It is the **"no effect" slot**: the baseline every other swing skill is
  measured against, and the slot to sit on while the others charge.
- **An empty weapon slot makes it weak, never uncastable**: it swings for
  the bare-hand baseline. The same holds for every weapon-scaled class
  ability.
- It is **melee**, so the elf's +5 m ability-range passive (`world.md` §7)
  does **not** apply to it — that perk is a **ranged/spell** bonus, or an
  elf would carry a 9 m sword. The melee class abilities (Mighty Blow,
  Hamstring) keep their 4 m for the same reason.
- **Hostile players are valid targets**, through the same friendly-fire
  check, dodge pre-roll and threat report as every other ability.

## 2c. What an ability item looks like

Decided 2026-08-08, shipped with WP35. This **answers** §6's old deferral
of "own ability icons": the icon *is* the equipped weapon plus the ability
color, and the tinted orb becomes the no-weapon fallback.

- Every ability item **wears the equipped item's skin**. An ability reads
  either the weapon slot (the default — every shipped ability) or the
  offhand (for WP14's shield abilities). A Warrior with a sword equipped
  holds *his* sword whichever ability is selected, and swapping the weapon
  reskins every ability at once, without reopening the character screen.
- **No exception list.** The abilities that do no weapon damage at all —
  Blink, Renew, Power Word: Shield and every future utility spell — take
  the weapon skin like the rest. An exception list would put the orb back
  on exactly the abilities whose color is hardest to remember.
- **Hotbar icon = the shared orb texture, tinted in the ability's color
  and dimmed, with the weapon art composited on top.** The color the eye
  already learned stays a large area, so the abilities stay tellable apart.
  No new asset is needed for it.
- **The in-hand (wield) image is the weapon art alone, no glow** — a
  glowing disc extruded into a slab in the player's hand is exactly the
  "round thing" this replaces.
- **Empty slot = the plain tinted orb**, i.e. the look the game shipped
  with before the weapon slot existed.
- **Which skill is this? — the name goes on the HUD, not on the icon**
  (decided 2026-08-09, WP38). Color alone was judged not enough to tell
  eight ability items apart. Writing the name into the icon is **not
  possible**: Luanti has no text texture modifier — the complete list is
  `doc/lua_api.md` "Texture modifiers" (`[combine`, `[resize`, `[opacity`,
  `[invert`, `[brighten`, `[noalpha`, `[makealpha`, `[transform`,
  `[inventorycube`, `[fill`, `[lowpart`, `[verticalframe`, `[mask`,
  `[sheet`, `[colorize`, `[colorizehsl`, `[multiply`, `[screen`, `[hsl`,
  `[contrast`, `[overlay`, `[hardlight`, `[png`) and there is no `[text`.
  Baking labels into PNGs would mean one authored texture per ability for
  about four legible characters at 16 px. Instead: **when the wielded
  ability item changes, the HUD shows that skill's name** — no asset, fully
  legible, and it answers the question at the moment the player asks it.
- **Signature icons, after the MVP.** The long-term answer is one
  **recognizable symbol per ability** replacing the tinted orb backdrop,
  with the weapon art still composited on top — recognition beats color
  coding. Layering is already how the icon is built (a `^` overlay chain in
  one composition site), so this costs **art and no machinery**: the same
  helper, a different backdrop texture per ability, and the color coding
  becomes redundant. Not in WP38.
- Still deferred: the alternative composition (weapon art plus a tinted
  border/halo overlay) — it needs art, not a redesign. And the weapon is
  **not** shown on the character model in third person; the engine draws
  the wield item in first person only, and putting it on the model needs
  the multiskin layering `inventory_equipment.md` §1 parks in Phase 3.

## 3. Warrior (Rage)

Tank/melee. All Warrior abilities count as tank abilities: **×3 threat**.

Kit tuning decided 2026-08-06 (implementation: WP19): Mighty Blow became
the rage DUMP (no cooldown — at +12 rage per auto-hit a cooldown left the
Warrior permanently rage-capped), Hamstring added as the control tool (in
an engine where mobs outrun players, the snare is the Warrior's identity).

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Charge | — (generates 15 rage) | cast, 10 s | Dash to an enemy up to 12 m away, 3 damage. Engage tool. |
| Mighty Blow | 25 rage | **swing**, no charge | On a completed landed swing with enough rage, the total is exactly floor(weapon damage × 1.5) + melee bonus instead of the plain hit. Its delta is folded into that native punch before its one crit/mitigation/dodge path — never a second punch. The rage dump. |
| Hamstring | 10 rage | **swing**, 6 s charge | The swing lands as usual; on a charged proc it also applies a 50% slow for 5 s. |
| Taunt | free | cast, 8 s | Target mob (8 m) is forced onto the Warrior for 3 s; threat set to top×1.1 (combat_stats §4; threat part + force duration land with WP6). |

A **swing skill with no charge timer is limited by its resource alone**,
which is exactly what Mighty Blow was built to be: at +12 rage per landed
hit it procs about every other swing and the Warrior is never rage-capped.
That is why removing the GCD costs it nothing — "GCD only" was never the
real limiter.

## 4. Mage (Mana)

Ranged damage; fragile, keeps enemies away.

Kit tuning decided 2026-08-06 (implementation: WP19): Fireball pays with
mana instead of a cooldown (5 mana against a 240+ pool was free), Frost
Nova became the rotation pivot — kiting IS the Mage fantasy here.

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Fireball | 8 | none (mana-limited) | 20 m ranged hit: 6 + spell power damage. Bread-and-butter nuke, limited by the mana pool. |
| Frost Nova | 10 | 12 s | Roots all enemies within 5 m for 4 s, then 50% slow for 3 s (no damage — pure control; rooted mobs keep attacking in melee range). |
| Blink | 8 | 15 s | Teleport up to 10 m in look direction (blocked by walls). Escape valve. |

## 5. Priest (Mana)

Healer/support with a solo damage tool.

Kit tuning decided 2026-08-06 (implementation: WP19): **Power Word:
Shield replaces Renew** in the base kit (an absorb plays differently
from a second heal and makes the Priest useful BEFORE damage lands; our
central hp-change modifier makes absorbs nearly free to build). Renew
moves into the talent tree.

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Smite | 4 | 2 s | 20 m ranged hit: 4 + spell power damage. Solo viability. |
| Flash Heal | 8 | 4 s | Heals 8 + 2×spell power. Targets the pointed ally (15 m), otherwise self. Threat: 0.5× effective healing (WP6). |
| Power Word: Shield | 8 | 10 s | Absorb shield on ally/self: soaks 8 + 2×spell power damage, lasts 15 s or until consumed. |
| Renew *(talent)* | 6 | 8 s | Heal over time: 3 + spell power every 3 s for 12 s. Unlocked via the Holy tree (WP11). |

## 6. Explicitly deferred

- Cast times / cast-bar spells, ability sounds → Phase 3 polish.
  (**Ability icons are no longer deferred**: since 2026-08-08 an ability
  item shows the equipped weapon plus its own color — §2c.)
- Warrior shield abilities → after WP14 (offhand/shields).
- Buffs/auras (e.g. Battle Shout) and party frames → with skill trees
  (WP11) or later. (Power Word: Shield moved into the base kit with the
  WP19 kit tuning, §5.)
- **Poison → arrives with the Rogue in Phase 2** (noted 2026-08-08).
  Poison is intended as the **Rogue's signature damage type** — the
  damage-over-time channel §2's pipeline does not have yet — and the
  Rogue is the Phase 2 class (ROADMAP; `professions.md` §2 already
  builds the leather line for it). **Until then there is no poison
  stat**: it appears in no `combat_stats.md` §2 formula, in no
  `items_crafting.md` §6.2 enchant pool and in no §6.3 roll range, so
  nothing may carry "+poison" — not an affix word, not a trinket, not a
  drop. What exists today is poison as a **mob** effect only (the
  serpent's flat damage-over-time on hit, `biomes_mobs.md` §3.1, and the
  Alchemist's Antivenom that cures it, `items_crafting.md` §3.6); that
  is a mob verb, not a player stat, and the Rogue work is what turns it
  into one.
- PvP tuning of roots/taunt (diminishing returns etc.) → balancing pass.
