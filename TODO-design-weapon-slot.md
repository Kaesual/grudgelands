# TODO — Weapon slot, ability items that wear its skin, and auto-attack as a skill

Opened 2026-08-08, from the owner's request: the character gets **exactly
one weapon slot** (next to the existing offhand), and **every ability item
shows the equipped item's skin** instead of today's colored orb — while
keeping its **colored glow** in the hotbar so the abilities stay tellable
apart. A Warrior with a sword equipped holds *his sword* in hand no matter
which ability is selected; swapping the weapon swaps every ability's look
at once. Shield abilities (WP14) do the same with the offhand item.

The owner settled the load-bearing rule on the same day (B1): **the slot
item is the single, fixed source of damage and appearance for every skill
of its type** — no fallback to whatever is in the hand. Empty slot = no
item attached: the skills look and hit as they do bare-handed today. And
**auto-attack becomes an ordinary skill** that takes the slot item's
properties like every other one.

**Everything in this file is open unless its *Decision* line says
otherwise.** Once a question is settled it moves into `docs/design/` and
keeps only a stub here (AGENTS.md "Documentation layers"). The plan in §4
is the plan for a future work package; the BACKLOG row is written when the
WP is scheduled.

Groups: **A** engine feasibility (answered) · **B** the weapon slot as a
game rule · **C** the ability-item skin · **E** auto-attack as a skill ·
**D** implementation plan, effort and risks.

---

## 1. Where the game stands today

- **There is no weapon slot.** `grug_inventory.equipment_slots`
  (`mods/PLAYER/grug_inventory/equipment.lua:6-14`) has head, chest,
  legs, feet, offhand and two trinkets. Weapons are *hotbar* items and
  carry **no** `grug_equip_*` group on purpose —
  `mods/ITEMS/grug_gear/init.lua:204-208` says so in a comment.
- **Auto-attack is a held mouse button on a wielded weapon.** The engine
  hands the wielded stack's `tool_capabilities` to the punch
  (`src/network/serverpackethandler.cpp:1032-1070`); our cadence patch
  (`mods/ENTITIES/mobs/api.lua:2682-2725`) turns the client's 0.2 s punch
  spam into one full-damage swing per `full_punch_interval`.
- **Ability items are tinted orbs**: one `core.register_tool` per
  ability with `inventory_image`/`wield_image` =
  `grug_abilities_orb.png^[multiply:<def.color>`
  (`mods/PLAYER/grug_abilities/init.lua:196-212`). `classes.md` §6 files
  "own ability icons" under Phase 3 polish — this request is a better
  answer to the same problem and retires that line.
- **Mighty Blow already fakes the weapon slot**: it scans hotbar slots
  1–8 for the strongest `damage_groups.fleshy` because "the wielded item
  is this ability" (`mods/PLAYER/grug_abilities/kits.lua:232-243`).
- Nothing carries `grug_equip_offhand` yet — shields are WP14.

---

## 2. Group A — Engine feasibility (verified, not open)

Checked against the engine checkout (Luanti 5.17.0-dev) before any design
was written.

### A1 — Per-stack skin override exists and covers both views

`lua_api.md:2929-2949` lists **item metadata keys that override the item
definition per stack**: `inventory_image`, `inventory_overlay`,
`wield_image`, `wield_overlay`, `wield_scale`, `color`, `range`,
`description`. Implementation: `src/inventory.cpp:258-295`
(`ItemStack::getInventoryImage/Overlay/WieldImage/WieldOverlay` — meta
wins over the definition), consumed by
`src/client/item_visuals_manager.cpp:48-57` for the **inventory/hotbar
icon** and by `src/client/wieldmesh.cpp:450-493` for the **extruded
first-person wield mesh**.

Three consequences that make the idea cheap:

1. The values are **texture names**, so the full texture-modifier syntax
   works (`^[multiply:`, `^[opacity:`, nested `^( … )`) — they go through
   `tsrc->getTexture(name)` like any other texture.
2. The client's mesh/texture cache key is **item name + image name**
   (`item_visuals_manager.cpp:50-56`), so N abilities × M skins cache
   correctly at one small mesh each.
3. **No new item registrations, no client-side mod, no engine patch.** We
   write meta into stacks we already own and rewrite them on join, class
   change and equipment change.

We already use the mechanism for the elf range passive
(`grug_abilities/init.lua:344-358` writes meta `range`), so the pattern is
established here.

### A2 — An ability item can never punch

`src/client/game.cpp:2785-2789`: if the selected item's definition is
`usable` (has `on_use`) and the dig key goes down, the client sends
`INTERACT_USE` **regardless of what is pointed at** — the
`POINTEDTHING_OBJECT` branch is never reached. Every ability item has
`on_use`, so holding one has always disabled auto-attack. This is the
reason auto-attack has to become a skill (group E) rather than something
the weapon slot feeds.

### A3 — `INTERACT_USE` fires on the key-press EDGE, not while held

Same site, `wasKeyPressed(KeyType::DIG)`: an ability fires **once per
click**. Holding the button does not repeat it — unlike punching, which
the client repeats every 0.2 s. This is what makes E3 (auto-repeat) a real
question rather than a nicety.

### A4 — What the glow can be, at zero asset cost

`grug_abilities_orb.png` is a 16×16 radial gradient; every `grug_gear`
weapon art is 16×16 as well (`tools/gen_mob_item_textures.py`, list
`GEAR_ICONS`, all CC0). So the hotbar icon can be composed as **glow
behind, weapon on top**:

```
grug_abilities_orb.png^[multiply:<ability color>^[opacity:150^(grug_gear_item_sword.png^[multiply:<bracket tint>)
```

No new PNG, and the color the eye already learned stays what it is. See C3
for the alternative.

### A5 — Ability punches wear the ability item (existing bug, blocks E)

`grug_core.deal_ability_damage` punches with a synthetic
`{full_punch_interval = 1.4, damage_groups = …}` table
(`mods/CORE/grug_core/combat.lua:472-475`). mobs_redo's `on_punch` then
runs its **unguarded** wear block (`mods/ENTITIES/mobs/api.lua:2829-2850`):
`wear = floor(1.4/75*9000) = 168` is added to the **wielded** stack — which
during a cast is the ability tool itself — and written back with
`set_wielded_item`.

Abilities *with* a cooldown hide it by accident (the cooldown ticker
overwrites the wear each step and zeroes it at the end). **Mighty Blow has
cooldown 0**, so its wear accumulates ~168 per landed hit: a visible wear
bar that grows, and after ~390 casts the tool breaks and vanishes from the
hotbar until a relog re-grants it via `sync_kit`.

**Fix is one field**: pass `punch_attack_uses = 0` in that
`tool_capabilities` table — mobs_redo reads exactly that as "no wear"
(`api.lua:2836-2838`). It must land with this work regardless of scope,
because E's auto-attack skill punches continuously and would hit the same
path every swing.

---

## 3. The open questions

### B. The weapon slot as a game rule

#### B1 — The slot item is the only source

**Decision: decided 2026-08-08 by the owner** → lands in
`inventory_equipment.md` §2 and `combat_stats.md` §2.

- The character gets **one weapon slot** next to the existing offhand.
- The item in the slot is the **single, fixed source** of damage *and*
  appearance for every skill of its type — **sword-type skills read the
  weapon slot, shield-type skills read the offhand slot**.
- **No fallback to the wielded item.** An empty slot is an empty slot:
  the connected skills carry no item, look exactly as they do today
  (tinted orb) and hit for the bare-handed baseline.
- Equipping or swapping the slot item changes **all** connected skills
  **immediately**, without reopening the inventory.

What this buys technically: the vendored `mobs/api.lua` punch path does
**not** have to learn about the weapon slot at all. That patch site was
the biggest risk in the first draft of this plan and is now out of scope
(see E5 for what remains of it).

#### B2 — Weapon wear

**Recommendation: weapons do not wear in this work package.** The one wear
path that actually fires today is the accidental one of A5, which gets
switched off. Real gear durability has an owner already — WP22, with
`items_crafting.md` §6b's "+100 % durability" refinement as its number.

Side finding for WP22: `grug_gear` weapons *do* wear today (~550 swings at
fpi 1.0) although nothing in their definition asks for it and no design
text says weapons break.

#### B3 — Which items may go into the slot?

**Recommendation: all `grug_gear` weapon families** — add
`grug_equip_weapon = 1` to the generated weapon groups
(`grug_gear/init.lua:204-208`, one line; its comment is retired).
**No class gate**: `items_crafting.md` §8.2 already decided weapon
families are class *flavor*, not a power ladder, so a Mage may equip a
greataxe and simply gains nothing from it. The only gate is WP5's
`grug_req_level` in the same `allow_put` (`inventory_equipment.md` §2).

**Decided 2026-08-08 by the owner: the vendored `default:` swords and axes
become slot-eligible too.** With B1's no-fallback rule, a fresh character
holding only a `default:sword` would otherwise have *no* melee damage at
all until the first vendor visit. Costs one `core.override_item` per tool,
each restating the **full** `groups` table — `core.override_item` replaces
a named field wholesale, it does not merge (AGENTS.md, learned in WP25).

Scope note: WP28 deletes the mese and diamond tool tiers and WP29 renames
the rest onto material names, so this override list is **temporary by
construction** — it shrinks as the base ladder absorbs those items. Write
it as a loop over a name list, not as hand-copied blocks.

Second sub-question: **should a pickaxe be equippable as a weapon?**
Recommendation **no** — mining tools stay mining tools; that is the
cleanest reading of "one weapon slot", and E5 leaves punching with a pick
working anyway.

The slot itself is **family-agnostic**: it holds whatever carries the
group. That matters for the **bow family** (`items_crafting.md` §3.2,
§8.2 — one bow per material tier, attack speed as charge speed), which
does not exist yet: when it lands, "ranged auto-attack" is a second
universal skill reading the same slot, not a second slot.

#### B4 — The two-handed rule

`combat_stats.md` §7 already decided "**two-handed weapons require an
empty offhand**", but no item declares its hand count, and the weapon slot
is the first place the rule can be enforced.

**Recommendation:** give the weapon families a `_grug_hands` field —
**greataxe 2, staff 2, sword/dagger/caster-1H 1** — and enforce "2H needs
an empty offhand" plus "offhand needs a 1H weapon" in the same
group-filtered `allow_put`, with the throttled chat refusal the armor-rank
check already uses. Whether it lands here or with WP14 is scheduling, not
design; the field costs nothing now.

Consequence worth naming, because it is a gameplay rule and not a
technicality: with the 2H rule live, **carrying a torch costs you the
two-handed weapon** (`combat_stats.md` §7 puts the moving light radius in
the offhand). Greataxe and staff users choose between light and their
weapon — the kind of trade the offhand exists for, but it should be a
decision, not a surprise.

#### B5 — Character-screen layout

The equipment column is hand-placed
(`mods/PLAYER/grug_inventory/pages.lua:89-96`). The weapon slot needs a
position and a label. **Recommendation:** weapon directly next to the
offhand so the pair reads as "hands"; armor keeps its own column.
Cosmetic — decide while implementing.

#### B6 — Migration

**Recommendation: none.** Weapons stay valid `main` items and the slot is
empty until the player fills it. With B1 that means an existing character
deals bare-hand damage until they equip their sword, so the WP ships a
**one-time chat hint on join** ("you have no weapon equipped — open the
character screen") rather than silently moving items around.

### C. The ability-item skin

#### C1 — Which skin does an ability use?

**Decision (follows from B1):** ability definitions gain
`slot = "weapon"` (default) or `slot = "offhand"`. Every shipped ability
is `weapon`; the `offhand` value exists for WP14's shield abilities and is
**untestable until a shield item exists** — it still has to be built now,
or WP14 pays for the same plumbing twice.

**Decided 2026-08-08 by the owner: there is no exception list.** The
abilities that do no weapon damage at all — **Blink, Renew, Power Word:
Shield**, and every future utility spell — take the weapon skin exactly
like the rest. "All skills use the weapon skin" is the rule; an exception
list would put the orb back on precisely the abilities whose color is
hardest to remember.

#### C2 — Empty slot

**Decision (B1):** the item definition's own tinted orb, i.e. today's
look, reached by simply *not writing* the meta keys. A character without a
weapon is visually identical to the game as it ships now.

**Decided 2026-08-08 by the owner: an empty slot makes skills weak, never
uncastable.** Mighty Blow without a weapon swings for the bare-hand
baseline (1 damage + melee bonus — exactly what its hotbar scan produces
today), the Strike punches with a fist, and spell abilities are unaffected
because they scale on spell power, not on the weapon. Blocking the cast
would strand a weaponless character with no offense at all.

#### C3 — What the glow looks like

**Decision: decided 2026-08-08 by the owner — (a), the orb backdrop.**

| | Composition | Cost | Look |
|---|---|---|---|
| **(a) orb backdrop** *(chosen)* | `inventory_image` = orb tinted + dimmed, weapon composited on top (A4) | **no new asset** | a colored disc behind the weapon; the learned color stays a large area |
| (b) frame overlay *(not taken)* | `inventory_image` = weapon art, `inventory_overlay` = a new border/halo ring tinted per ability | one new 16×16 PNG in `tools/gen_mob_item_textures.py` (+ `LICENSE-media.md` row) | crisper silhouette, thinner color cue |

So the hotbar icon is one meta string per ability, built in one helper
(D2/5), and `grug_abilities_orb.png` keeps its job instead of being
retired — it becomes the backdrop and the no-weapon fallback in one. (b)
stays on the table as a later polish pass; it needs art, not a redesign.

**The wield (in-hand) image gets the weapon art alone, no glow** — a
glowing disc extruded into a slab in the player's hand is exactly the
"round thing" problem we are removing.

#### C4 — When is the skin rewritten?

On join, on class pick (both already call `sync_kit`), and on **every
equipment change**. The last one needs a seam: `grug_inventory` sees the
change, `grug_abilities` must react, and the two mods do not depend on
each other.

**Recommendation:** a small surface in `grug_core`, next to the existing
`register_on_player_hit_mob`:

- `grug_core.get_equipped_weapon(player)` / `get_equipped_offhand(player)`
  — **stubs returning nil**, overridden by `grug_inventory`, exactly the
  pattern `grug_core.get_armor_percent` uses
  (`mods/CORE/grug_core/combat.lua:22-27`). Cached per player like the
  armor total, invalidated at the same three call sites.
- `grug_core.register_on_equipment_change(fn)` + an internal
  `notify_equipment_change(player)` fired by `grug_inventory` from **both**
  the inventory-action callback and every server-side list write (the
  class-change unequip already needs this and solves the cache half of it
  with `invalidate_armor` — same sites).

Writes must be **idempotent and cheap**: store a short skin token in the
stack meta and rewrite a stack only when the token differs, the way
`sync_kit` already compares the `range` override before writing
(`grug_abilities/init.lua:344-358`). Inventory writes re-send the list to
the client, and the cooldown-wear path is deliberately stingy about it
(`init.lua:215-249`) — the skin sync must not undo that discipline.

#### C5 — Does the weapon show on the player model in third person?

**No, and not in scope.** Luanti renders the wield item in first person;
putting it on the character model needs the multiskin/wieldview layering
that `inventory_equipment.md` §1 already parks in Phase 3. Worth saying
out loud so nobody expects other players to see the sword.

### E. Auto-attack as a skill

**Decision: decided 2026-08-08 by the owner** → lands in `classes.md` (a
new universal-ability section) and `combat_stats.md` §2.

Auto-attack becomes an **ordinary ability item** ("Strike", working
title): a simple melee hit that draws its damage, its swing speed and its
look from the weapon slot like every other skill. That is what makes B1
consistent — with A2 in the way, a slot-fed auto-attack was otherwise
unreachable — and it removes the last reason to keep a weapon in the
hotbar.

Everything below is the detail that decision opens up.

#### E1 — Who gets it, and what does it cost?

**Recommendation:** a **universal** ability, granted to every class
(`grug_abilities.by_class` is keyed by class today, so the registry needs
a "granted to all" flag), **no resource cost**, and **first in the
hotbar** so it lands on key 1 for everyone.

**It must generate rage** (+12 per landed hit, `classes.md` §1). Today
that comes from `grug_core.register_on_player_hit_mob` which explicitly
skips ability punches (`in_ability_punch`,
`grug_abilities/init.lua:394-401`) — the Strike therefore has to grant it
itself, or the Warrior's whole resource economy stops the day auto-attack
becomes an ability.

Two traps in the existing kit code that a universal ability walks into:

- **`sync_kit` purges by class.** Anything whose `def.class` does not
  match the player's class is deleted from every list
  (`grug_abilities/init.lua:329-365`) — a universal ability must be
  exempt from that purge, or it is granted and destroyed in the same
  pass.
- **A character without a class gets no kit at all**: `sync_kit` iterates
  `by_class[class]`, and class selection happens after the faction/race
  flow. **Recommendation: grant the Strike on join regardless of class**,
  so a fresh character is never standing in the world with no way to
  fight back.

#### E2 — Swing speed, GCD and the cooldown display

**Decision: decided 2026-08-08 by the owner** (all three points below).

- **Cooldown = the equipped weapon's `full_punch_interval`**, read per
  cast. The ability registry only knows fixed `def.cooldown` today
  (`init.lua:280-306`, and the wear ticker divides by
  `registered[id].cooldown` at `:488`), so it needs to support a
  per-cast cooldown value.
- **Off the global cooldown**, and it must not *start* one: a 1 s GCD
  would cap a 0.7 s dagger and make attack speed a dead stat. Add
  `def.off_gcd`.
- **No wear-bar cooldown display for this one ability.**
  The wear ticker writes up to 2 inventory updates per second per player
  while a cooldown runs (`init.lua:475-498`); a permanently cycling
  auto-attack would make that continuous for every player in combat, and
  the swing timer is exactly the kind of information the GCD comment
  already argues is not worth an inventory re-send
  (`init.lua:20-25`). Same rationale, same answer.

#### E3 — One click per swing, or a toggle?

A2/A3: `on_use` fires **once per click**, never while the button is held.
So a literal port of today's feel does not exist — the player would click
once per swing (every 0.7–1.4 s).

**Decision: decided 2026-08-08 by the owner — option (a), the toggle.**

- **(a) toggle auto-repeat** *(chosen)*: the first cast starts
  swinging at the locked target and keeps swinging every
  `full_punch_interval` until the target dies, leaves range/LOS, or the
  player casts Strike again to switch it off. This is the WoW model, it
  makes attack speed feel like a stat, and it fits the soft target lock
  that already exists (`grug_abilities.get_target`, 8 s,
  `init.lua:96-120`). Cost: a per-player swing loop with re-validation —
  and per AGENTS' throttle rule it belongs in the existing 0.5 s
  globalstep with its own finer accumulator, since 0.5 s granularity
  would quantise a 0.7 s dagger to 1.0 s.
- (b) click per swing: nothing extra to build, but a dagger user clicks
  ~85 times a minute and the swing-speed stat becomes a click-rate stat.

If (a) ships, the loop's stop conditions are part of the design, not an
afterthought: **target dead, out of range, out of LOS, second cast,
player death, disconnect** — and the ability-item purge/re-grant paths
(class change, respawn) must not leave a loop running against a stale
player name. The loop **re-reads the weapon every swing**, so unequipping
mid-fight drops to fist damage rather than stopping the attack, and
swapping a greataxe for a dagger changes the cadence from the next swing
on.

#### E4 — Damage

**Recommendation:** identical to the numbers `combat_stats.md` §2 already
defines — **weapon damage + floor(Str/10)**, crit ×1.5 — routed through
`grug_core.deal_ability_damage`, which already rolls crit, marks combat
and reports threat. Empty slot: bare-hand baseline (C2). Threat multiplier
1 (Taunt keeps its ×3).

Nice side effect: auto-attacks currently get their crit from a *separate*
path bolted into the vendored `api.lua` (`grug_core.melee_crit`,
`api.lua:2781`). Once auto-attack is an ability, both crit paths are the
same code again.

#### E5 — What happens to the old punch path?

**Recommendation: leave it exactly as it is.** Punching a mob with a
wielded pick or a bare hand keeps working through the existing cadence
patch, and the patch stays byte-identical (VENDOR.md unchanged).

It is *not* a bypass of B1 worth defending against: a hotbar weapon
swung that way has no crit, no rage, no threat bonus and no target lock,
so it is strictly worse than the skill. If it ever proves confusing, WP29
— where vendor weapons merge into the base tool ladder — is the natural
place to revisit, not this WP.

#### E6 — PvP: the skill closes an open carry-over for free

`combat_stats.md` §2 records that **player-vs-player melee still runs the
engine's raw `tflp` scaling** and therefore keeps the old
held-button-deals-0 defect that WP6's cadence patch fixed for mobs — a
carry-over noted in BACKLOG and waiting for the PvP work package.

If the Strike accepts player targets (hostile faction, same target-lock
and range checks the other kits use), that path disappears: it routes
through `grug_core.deal_ability_damage`, which already does the
friendly-fire check, the dodge pre-roll and the threat report for players
(`grug_core/combat.lua:441-463`). **Recommendation: build it that way and
close the carry-over in this WP** — it is a smaller change here than a
second port of the cadence model later.

#### E7 — The elf range passive must not reach the auto-attack

`grug_abilities.get_range` adds the elf's `ability_range_bonus` (+5 m,
`world.md` §7) to **every** ability, and `sync_kit` mirrors it into the
stack's `range` meta (`grug_abilities/init.lua:125-128`, `:344-358`). A
melee auto-attack inheriting that would give elves a **9 m sword**.

**Recommendation:** the perk applies to ranged/spell abilities only —
either an explicit `def.melee = true` opt-out on the Strike (and on Mighty
Blow/Hamstring, which have the same 4 m melee range and the same problem
today), or the perk keys off a range threshold. The first is explicit and
cheap; the second silently re-tunes if a range ever changes. This is a
**pre-existing** bug for the melee kit abilities, not something the weapon
slot introduces — but the Strike makes it impossible to ignore.

#### E8 — Icon and skin of the Strike

It takes the weapon skin like everything else (C1). Its glow color should
be **deliberately neutral** (bone white / steel gray) so the four colored
class abilities keep their identity; with an empty slot it falls back to a
neutral orb, which reads correctly as "you are punching with your fists".

---

## 4. Group D — Implementation plan

### D1 — Task cut (one work package)

| # | Task | Files | Size |
|---|------|-------|------|
| T0 | **`punch_attack_uses = 0` in `deal_ability_damage`** (A5) — one field, fixes Mighty Blow eating itself and unblocks E | `grug_core/combat.lua` | XS |
| T1 | **Weapon slot**: slot entry + group, cached `get_equipped_weapon`/`get_equipped_offhand` (armor-cache pattern), `grug_core` stubs + equipment-change hook, character-page layout, `grug_equip_weapon` on the four weapon families + the vendored swords/axes (B3) | `grug_inventory/equipment.lua`, `pages.lua`, `grug_core/combat.lua`, `grug_gear/init.lua` | M |
| T2 | **Ability skins**: `slot` field on ability defs, skin-token meta sync in `sync_kit` and on the equipment hook, orb fallback | `grug_abilities/init.lua`, `kits.lua` | M |
| T3 | **Auto-attack skill** (group E): universal grant, per-cast cooldown from the weapon's fpi, off-GCD, own rage grant, damage via `deal_ability_damage`, toggle auto-repeat loop, no wear display, hostile-player targets (E6) | `grug_abilities/init.lua` (registry: universal + dynamic cooldown + off-GCD), `kits.lua` | **L, highest risk** |
| T4 | **Weapon-scaled abilities read the slot**: Mighty Blow drops its hotbar scan; descriptions reworded ("your equipped weapon"); the elf range perk stops reaching melee abilities (E7) | `grug_abilities/kits.lua`, `init.lua` | S |
| T5 | **Two-handed rule** (B4, optional here — could go to WP14): `_grug_hands`, offhand cross-check in `allow_put` | `grug_gear/init.lua`, `grug_inventory/equipment.lua` | S |
| T6 | **Docs + review + runtime test plan**: fold the decided questions into `inventory_equipment.md` §2, `combat_stats.md` §2/§7, `classes.md` (universal ability + §6's orb-icon deferral dies), BACKLOG WP row, README current state | docs only | S |

Estimated shape: **one full WP session**, upper end — implementer plus the
mandatory Opus review. T1/T2 are mechanical once C4's seams exist; **T3 is
the package**, because it adds three genuinely new mechanics to the
ability registry (universal grant, per-cast cooldown, off-GCD) plus a
repeat loop. If the WP has to be cut, T5 goes to WP14 and E3 falls back to
option (b) — but T3 itself cannot be split off without leaving the game
with no auto-attack at all.

### D2 — Risks

1. **T3 changes the combat loop everyone is balanced against.** Attack
   speed, rage generation and threat all run through auto-attack; a
   mistake here is felt in every fight. The runtime test plan below
   deliberately checks rage and swing cadence separately.
2. **Inventory re-sends.** A naive "rewrite all kit stacks on every
   inventory action" would re-send the player inventory on every drag,
   and a wear-animated swing timer would do it continuously. C4's token
   compare and E2's no-wear-display are both load-bearing, not polish.
3. **Cache staleness.** `get_equipped_weapon` is read per swing, so it is
   cached — and every server-side write to the weapon list must
   invalidate it. The armor cache documents the three sites that matter;
   the weapon cache has the same three.
4. **`core.override_item` replaces fields wholesale** (AGENTS.md, learned
   in WP25). Adding `grug_equip_weapon` to vendored tools means restating
   their full `groups` table.
5. **Texture-modifier strings in meta** are parsed client-side; a
   malformed one yields a `generateImagePart` client error and an
   untextured icon rather than a server error. Build the string in one
   helper, not at three call sites.
6. **A weaponless character has no offense** under B1. B6's join hint is
   the mitigation, and the first vendor visit is the fix.

### D3 — Runtime test plan (for the owner, after the WP)

1. Character screen shows a **Weapon** slot; a sword drops in, armor and
   trinkets still refuse the wrong items.
2. With the sword equipped, **every ability icon in the hotbar shows a
   sword with its ability color**, and the sword is in hand in first
   person on every ability.
3. Swap sword → greataxe in the slot: **all icons change at once**,
   without reopening the inventory.
4. Empty the slot: icons fall back to the colored orbs, and the abilities
   are still castable (C2) for bare-hand damage.
5. **Strike** sits in the hotbar for all three classes, hits for the
   equipped weapon's damage + Str bonus, crits, and swings at the
   weapon's speed — a dagger visibly faster than a greataxe.
6. Strike **does not block** the class abilities (off-GCD) and casting a
   class ability does not block the next swing.
7. Warrior rage rises ~12 per landed Strike; rage decay out of combat
   unchanged.
8. Auto-repeat (if E3a ships): one cast keeps swinging until the mob dies
   or you walk out of range; a second cast stops it.
9. Mighty Blow with the sword equipped and **no weapon anywhere in the
   hotbar** still deals 150 % weapon damage — and its icon shows **no
   creeping wear bar** after 50 casts (A5).
10. Punching a mob with a pick still works exactly as before (E5), and
    the pick's own durability behaves as it always did.
11. A **brand-new character** (faction/race picked, class not yet chosen)
    has the Strike and can defend itself (E1) — and a vendored
    `default:sword` goes into the slot and drives its damage (B3).
12. As an **elf**, the Strike and Mighty Blow still reach only 4 m, while
    Fireball/Smite keep their +5 m (E7).
13. If E6 ships: Strike on an **enemy player** deals the weapon's damage
    and rolls dodge/crit, and a same-faction player still takes nothing.
14. No chat/log spam while dragging items across the character screen, and
    no inventory flicker while auto-attacking.

---

## 5. Design-doc statements this file will change

1. **`inventory_equipment.md` §2** — the slot list gains **Weapon**, and
   the "weapons are hotbar items" assumption behind
   `grug_gear/init.lua:206` goes with it.
2. **`combat_stats.md` §2** — "weapon damage" gains a source (the equipped
   weapon, no fallback), and the whole "holding the attack key is an
   auto-attack at the weapon's speed" paragraph is replaced: auto-attack
   is a skill, the held-button path stays only for tools and fists (E5).
   The PvP carry-over noted there is unaffected.
3. **`combat_stats.md` §7** — the already-decided 2H rule finally gets a
   mechanism (B4).
4. **`classes.md`** — gains a **universal ability** (auto-attack) that is
   not part of any class kit, and §6's "own ability icons (MVP: tinted orb
   icons) → Phase 3 polish" is answered differently: the icon *is* the
   equipped weapon plus the color, with the orb as the no-weapon fallback.
5. **`combat_stats.md` §2, the PvP carry-over** — closed rather than
   changed, if E6 ships with this WP.

## 6. Scheduling

- This is a **new work package** (WP34 by today's numbering), and it is
  **not blocked**: every mod it touches is shipped, and it needs neither
  a fresh world nor a mapgen change.
- **WP14 (offhand & carried light) shrinks.** The offhand *slot* already
  exists and this WP adds the equip rules around it (B4) plus the
  offhand-skin plumbing (C1); WP14 keeps the shield items, their armor
  contribution, and the torch light radius.
- **WP22 (gear wear) inherits** the durability question of B2 and the
  side finding that `grug_gear` weapons wear today for no designed
  reason.
- **WP5 composes cleanly**: `grug_req_level` lands in the same
  group-filtered `allow_put` the weapon slot uses, so the two do not have
  to be ordered.
- Nothing here depends on the material-ladder chain (WP26 → WP29), and
  **WP29 will rename the weapon items but not touch their groups**, so
  the slot survives that rename untouched. The opposite direction does
  apply: **WP28/WP29 shrink this WP's `core.override_item` list** for the
  vendored swords and axes (B3) as those items are deleted or absorbed
  into the base ladder — one more reason to write it as a loop over a
  name list.
