# Class Kits — Resources & Abilities (MVP)

Decided spec (last revised 2026-08-12; established 2026-08-06).
Implementation: WP4 (`grug_abilities`, resource HUD, damage pipeline hooks in
`grug_core`), WP19 (kit tuning, GCD, target memory), WP35 (§2b's universal
ability and §2c's ability-item skins), WP38 (§2b's proc model, which retires
WP19's GCD), and WP39 (crosshair-authoritative hostile combat, weapon-ready
reticle and directional Fireball, shipped 2026-08-10); skill trees extend these
kits in WP11.
Attribute/derived-stat formulas: `combat_stats.md` §1/§2; threat values:
`combat_stats.md` §4.

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
  have no `on_use`, but their no-dig pointabilities can mask a ground-level
  item's native selection box. A fresh LMB press therefore checks the first
  visible object on the same 4 m eye ray server-side and calls the builtin
  pickup path only when it is a dropped item. Cast skills retain the WP38
  `on_use` pickup bridge; clicking loot does **not** cast.
- **No global cooldown** (removed 2026-08-09 with the proc model of §2b;
  it was 1.0 s from 2026-08-06 to WP35). A GCD existed to stop instant
  chaining, and the two limiters that replaced it do that job better and
  visibly: each skill has its **own** charge timer, and every effect costs
  a **resource**. A flat second on top of both only added an invisible
  delay — and against §2b's swing skills it would have capped attack speed,
  which is the defect that already made the Strike an exception.
- **Target memory is not hostile aim authority** (shipped with WP39). Enemy and
  ally use separate 8 s slots. The enemy slot feeds only the Target Frame and
  other UI context: no melee hit, hostile cast or projectile may fall back to
  it. Hostile damage always follows the current crosshair ray. The ally slot
  remains an actual heal/shield fallback because tracking a moving party member
  is a different interaction. Owner death, respawn, disconnect or class sync
  clears both slots, and a dead/unloaded/left target is invalidated.
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
| Rage | Warrior | 0–100, starts at 0 | +12 per landed §2b authoritative swing; ordinary tools/fists retain proportional native credit (combat_stats §2); +4 per hit taken, +15 from Charge; decays 2/s out of combat |

- **Rage is granted on damage that actually landed**, not on a swing
  attempted: a target that cancels the punch (a vendor NPC, an evading
  mob), an `immune_to` mob or a player with PvP off yields **0 rage**.
  PvP refusal, dodge and full absorb likewise pay 0 (`combat_stats.md` §2).
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
- **Target-race equipment effects use the same central transaction.** A
  weapon's T4/T5/T6 counter finish adds +1/+2/+3 flat damage to an accepted
  attack sourced from that equipped weapon, after the one ordinary Crit result
  and before armor/absorb; Crit never multiplies it. It does not ride on a
  spell merely because ability icons inherit the weapon's appearance. An
  active Warding Draught applies its 5/7.5/10% target-race reduction after
  armor and before absorb. Both require matching race identity on a hostile
  player or combat-capable NPC/mob and ignore passive invulnerable service
  NPCs. Stacking and recipe rules: `items_crafting.md` §4.3.
- **Melee carries the melee bonus and rolls crit** (combat_stats §2). Swing
  ability stacks mirror the equipped weapon's interval for native
  animation/interaction but publish zero damage; their combat packets are
  input only, and the authoritative held loop builds a full slot-fed swing
  against the current server ray. Tools and fists keep their own native
  proportional pipeline while moving the next full ability swing out on the
  shared cadence bound.
- **Threat hooks are stubs in WP4** (`grug_core.add_threat`,
  `add_heal_threat`): abilities already report their threat values
  (combat_stats §4: tank abilities ×3, healing ×0.5); WP6 replaces the
  stubs with the real threat table. Taunt's forced-target effect works
  already via mobs_redo `do_attack(player, force)`.

## 2b. How a skill fires — swing skills and cast skills

Shipped with **WP39 on 2026-08-10**. It retains WP38's proven separation of native
animation from authoritative full-swing damage, but replaces WP38's implicit
enemy-lock targeting with current crosshair authority. It also replaces both
the model of
2026-08-08, in which every skill owned the melee clock while its own
cooldown ran, and WP38's short-lived server-side toggle loop. Rationale and
the melee side of it: `combat_stats.md` §2.

Every ability is one of **two kinds**, and the kind is a property of the
ability, declared where it is registered:

1. **Swing skills** — the item has no `on_use`, so Luanti keeps native
   first-person held-LMB animation. A bounded server ray restores dropped-item
   pickup where the no-dig pointabilities mask it. Against enemies native punch
   packets are input only: one server-authoritative weapon clock produces a
   full attack only when the current eye ray contains a valid hostile. The
   selected skill's effect rides on that attempted swing when its own commit
   conditions succeed. Today exactly the three melee abilities: Strike, Mighty
   Blow, Hamstring.
2. **Cast skills** — a discrete action that is not a weapon swing: heals,
   shields, Blink, Frost Nova, Smite, Charge, Taunt. A gap closer is
   wanted *now*, from 10 m, and a heal must not require punching the
   patient. These keep the familiar shape: a cost, a cooldown, a target.

The whole Mage and Priest kit consists of cast skills; WP39 did not change
that. Future ranged auto-attacks may arm their own ranged procs, but equipping a
bow or wand does not replace Fireball's decided directional-projectile
behavior.

### Rules for swing skills

- **A skill never makes you slower or weaker than the bare weapon.** Every
  granted swing ItemStack mirrors `full_punch_interval` from the equipped
  weapon slot, but advertises `fleshy = 0`, with no digging groupcaps and no
  item wear. Zero native damage prevents the acquisition packet from producing
  builtin PvP knockback before the server callback suppresses it; the
  authoritative swing rebuilds real damage from the slot. Its item definition
  also marks the hand digging
  groups (`crumbly`, `snappy`, `oddly_breakable_by_hand`) and the engine's
  independent `dig_immediate` path as `pointabilities.nodes = "blocking"`:
  objects remain natively punchable when their ray wins; the fresh-press loot
  bridge covers ground-level drops without making nodes transparent. Killing a
  mob while holding LMB cannot roll straight into digging the ground or leaves. An empty slot
  mirrors the registered hand.
  The capabilities are interaction metadata, not a second damage stream.
- **Every skill charges on its own timer, and the timer runs always** —
  including while the skill is *not* selected. That is what makes the
  hotbar a rotation: several skills come up during a fight and are spent in
  consecutive swings.
- **Charges do not stack.** One charge maximum, and a full charge never
  decays. Stacking would bring back burst hoarding; decay would punish a
  player for looking at the map.
- **Hold, click-spam and ordinary hostile tool/fist input share one per-player
  ability cadence bound.** LMB may keep the client's fast cosmetic attack
  animation running, but it creates no proportional or fast-attack ability
  damage. Early clicks neither attack nor move the due time. Every actual
  hostile tool/fist combat packet pushes the next full ability swing at least
  one equipped-weapon interval out, preventing a second damage stream;
  consecutive tool packets retain their own proportional accumulator. Cast use
  alone keeps the due time unchanged. A real attack carries at most 0.1 s, and
  never more than half an interval, of server-step lateness into the next due
  time. At most one swing runs per throttled pass, so lag never replays missed
  swings.
- **Readiness waits for aim.** When the weapon interval expires, the full swing
  remains ready. While a swing skill is selected and LMB is held, each
  throttled combat pass raycasts from the player's eye through the current
  crosshair to the skill range (4 m today). A hostile living mob/player must be
  the first valid visible combat object; walkable nodes block. No target, a
  friendly target, a blocking node or out-of-range aim is an **aim miss**: it
  deals nothing and does not advance the weapon clock. As soon as the server
  observes a valid target on that ray, it starts one full attack and advances
  the clock. A subsequent evade, immunity, PvP refusal, dodge, full absorb or
  callback cancellation is a **combat miss** and still consumes the interval,
  while its existing no-rage/no-cost/no-charge/no-effect result remains.
- **A due landed swing with a charged skill selected fires the effect
  and resets that skill's charge.** Only the *selected* skill is read at the
  due instant, so only one effect can ride on one swing. Evade, immunity, PvP
  refusal, dodge and full absorb pay no cost, consume no charge and fire no
  effect.
- **The crosshair target is live.** No stored enemy ObjectRef authorizes a
  swing. Moving the crosshair to another hostile changes the next possible
  target immediately; looking away stops damage immediately without clearing
  readiness. An attempted or accepted hostile hit may still refresh the enemy
  Target Frame's 8 s memory, but that memory cannot be read back as combat aim.
- **Clock boundaries are explicit.** Switching among swing skills preserves
  the clock and reads the new selection live. Wielding a non-swing item or
  entering a cast stops loop input and discards ordinary tool/fist remainder,
  but preserves the weapon due time: swing → tool/cast → swing cannot grant an
  instant hit. Death, respawn, class sync and disconnect clear clock state. A
  concrete equipped-weapon change starts the new weapon at one full interval,
  so A→B→A cannot manufacture immediate hits. Owner lifecycle also clears both
  target slots; player target death/leave clears all locks that reference that
  ObjectRef.
- **The authoritative entry is exact and single-use.** Its opaque transaction
  token names the expected attacker and concrete target and can be claimed
  once. A synchronous callback-triggered second punch by that attacker, on the
  same or another target, is suppressed before damage or proc preparation.
- **The resource cost is paid at the proc, and an unaffordable proc does
  not consume the charge.** This is the decision layer: Mighty Blow's rage
  is the reason to keep swinging with it rather than to spend the rage
  elsewhere. Silently not firing is correct — a warning on every swing
  would be noise.
- **Rotation is the hotbar.** Keys 1–8 pick which effect is armed; no cast
  click is needed to switch. Switching between swing skills preserves proc
  cadence, so the newly selected charged skill rides on the next due swing.
- **There is no toggle.** Native no-`on_use` interaction supplies the fast
  animation; the bounded fresh-press ray supplies loot pickup; the server loop
  supplies the one crosshair-authoritative damage stream only while LMB is
  held. Native swing-item combat packets themselves deal no
  damage/rage/threat/wear/proc.

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
- Fireball is the first true directional projectile. A successful input spends
  8 mana and snapshots the player's current eye position and look direction
  even when no object is pointed. It travels straight at **20 m/s**, has no
  gravity, homing or splash, deals **6 + spell power**, and disappears after
  **20 m**, on a blocking node or on its first attackable target. Missing still
  spends mana. Friendly players/allied entities and dropped items are ignored
  rather than consuming the projectile.
- Projectile collision is swept over every travelled segment, not sampled only
  at the entity's new position. The same ownership/collision foundation must
  support later arrows, but WP39 does not implement bows: arrows add gravity
  and take their initial impulse from bounded bow draw time.
- Friendly heals and shields retain the separate 8 s ally-memory fallback and
  self fallback defined by their individual skill.

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
| Charge | — (generates 15 rage) | cast, 10 s | Dash to the currently pointed enemy up to 12 m away, 3 damage. No enemy-memory fallback. Engage tool. |
| Mighty Blow | 25 rage | **swing**, no charge | On a completed landed swing with enough rage, the total is exactly floor(weapon damage × 1.5) + melee bonus instead of the plain hit. Its delta is folded into that native punch before its one crit/mitigation/dodge path — never a second punch. The rage dump. |
| Hamstring | 10 rage | **swing**, 6 s charge | The swing lands as usual; on a charged proc it also applies a 50% slow for 5 s. |
| Taunt | free | cast, 8 s | Currently pointed mob (8 m) is forced onto the Warrior for 3 s; no enemy-memory fallback; threat set to top×1.1 (combat_stats §4; threat part + force duration land with WP6). |

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
| Fireball | 8 | none (mana-limited) | Straight 20 m/s projectile along the cast-time crosshair, maximum 20 m, no homing/gravity/splash: 6 + spell power damage on first attackable target. A miss still spends mana; at most eight shots per owner/session may be active. |
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
| Smite | 4 | 2 s | Current-crosshair 20 m hit with no enemy-memory fallback: 4 + spell power damage. Solo viability. |
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
