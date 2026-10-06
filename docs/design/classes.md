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
their numbers, and the keystones that add new main skills (at most one per
tree) — Mend among them, as §5 already decided. A **fourth class, the Scout**
([scout.md](scout.md)): leather armour, a bow and a blade. The Scout carries
its bow in the Weapon slot, shown as "Ranged", and its sword or dagger in the
offhand, shown as "Melee" (Round 28 ruling 25): bow skills read Ranged,
Strike and every melee skill read Melee. Each skill swings exactly one slot's
item; no class gets a second strike, damage roll or talent axis from the
other hand. Every class's offhand is class-specific — Warrior a shield, Mage
and Priest a spellbook ("Caster offhand"), Scout the Melee blade — and both
hand items always count toward stats (`inventory_equipment.md` §2). The numbers in the
§3-§5 tables become the **untalented base** values; and by the user's ruling
of 2026-09-16 the **Warrior's base kit drops to three abilities** (Charge,
Mighty Blow, Taunt), so that every class starts with Strike plus three:
**Hamstring leaves §3's table and returns as a talent**, the keystone of the
Warrior's Ruin tree. The same ruling removes **class changing** from the game
entirely, admins included.

Core principles:

- **Instant abilities + cooldowns, no cast times in the MVP.** Cast bars
  (and pushback) may come later for selected spells. Travel home, including
  to a Claim Stone ([housing.md](housing.md) §8), is immediate and uses no
  cast.
- **Abilities use indestructible, bound inventory representations.** The base
  kit, including Strike, is inserted once at character creation. Representations
  may be carried in main inventory or owned bags; dropping or returning one to
  Skills deletes only that copy, without a world drop or lost entitlement.
  The Skills catalogue restores an unlocked ability only when no carried copy
  exists. External storage, equipment slots and trading refuse these items.
  Reconnect and talent changes normalize existing copies without re-granting
  discarded ones. Left click attacks or casts; a running charge or cooldown
  shows as the overlay on the skill's hotbar slot (§2b "The cooldown
  overlay"). Appearance follows §2c.
- **Skills pick up drops within hand reach.** A fresh physical LMB press
  attempts pickup of the first visible dropped item within 4 m exactly once,
  unless a hostile stands behind it (loot never hides a hostile; the press is
  then a combat press). Combat range never extends pickup reach; pickup does
  not also cast.
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
  self (user ruling 2026-09-24). An aimed ally the PvP flag rules out (an
  unflagged helper, a flagged ally) is a refusal at no cost, never a self-cast
  (Round 31 ruling 9).
  Service NPCs, guards and mobs are not player party
  members and cannot receive player heals or shields. `self`
  ignores all pointed and remembered objects and anchors the
  cast on its user. Strike, Charge, Mighty Blow, Hamstring, Taunt, Fireball and
  Smite are hostile; Ice Nova and Blink are self; Heal, Shield and Mend
  are friendly. A friendly skill's documented self fallback
  remains part of that skill, not a fourth target kind.
- Three to four abilities per class in the MVP; **new active "main
  skills" come only from talent keystones**, at most one per tree
  ([skill_trees.md](skill_trees.md) §2) — talents otherwise improve or
  replace existing buttons rather than adding many new ones.
- **Balance constraints** (decided 2026-08-06): party content is sized
  for **2–3 players**, and every encounter must be **beatable without a
  healer** (food/potions as the substitute) — the Priest makes parties
  comfortable, never mandatory.
- **Numeric ability tooltips are player-specific.** Damage, healing and absorb
  numbers show the effective current-level value before Crit and target-level
  malus. Absorb settlement retains fractional points; its tooltip displays
  that seam's value rounded down. Smite shows its unshielded damage and, when
  Warded Wrath is ranked, a separately scaled `(+N while shielded)` suffix;
  changing only the current shield state does not change its tooltip. The
  registered item definition keeps a number-free fallback; the player's
  ability ItemStack carries the effective description and refreshes on kit
  sync, level change and talent change. Its timing line shows the player's
  effective cooldown (a talent that shortens it, such as Grudge or Swift
  Word, shows in it) and a swing skill's effective charge. Strike's
  player-specific rage sentence is additionally resource-gated as decided on
  2026-09-18: only a rage-resource class receives it; mana-resource and
  class-less characters retain the class-neutral swing text (§2b).

## 1. Resources

| Resource | Classes | Pool | Regeneration |
|----------|---------|------|--------------|
| Mana | Mage, Priest | `round(20 + 5L + 0.66L²)`, before mana-percent gear/talents (combat_stats §2) | `1 + 0.15 × level` mana/s out of combat, a lower in-combat rate (combat_stats §5) |
| Rage | Warrior | 0–100, starts at 0 | **+8** per landed §2b authoritative swing (native tool and fist packets deal nothing and earn none, combat_stats §2); **+3** per hit taken, +15 from Charge; decays **5/s** out of combat. Ruling 25 of 2026-09-16 lowered the income and raised the decay — the ledger and what it buys are in §3 |

- **Rage is granted on damage that actually landed**, not on a swing
  attempted: a target that cancels the punch (a vendor NPC, an evading
  mob), an `immune_to` mob or a player with PvP off yields **0 rage**.
  PvP refusal, dodge and full absorb likewise pay 0 (`combat_stats.md` §2).
- **In combat** = engaged with a live mob, or a PvP/other hit within the last
  5 s; death clears it (`combat_stats.md` §5 "Combat state" owns the rule).
  The definition lives in `grug_core` (`in_combat`) and is shared with
  recovery (combat_stats §5).
- Resources are runtime state, not persisted: mana is full on join and
  respawn, rage is 0.
- Mana costs are rounded percentages of the caster's unmodified base pool,
  minimum 1. Full-pool cast counts at L1/L60 are: 5% = **26/19**, 6% =
  **13/16**, 8% = **13/12**, and 10% = **8/9**. Pool enchants and talents do
  not increase costs. Heal therefore supplies at least 12 casts at
  either endpoint; four untalented 25% casts equal one neutral health pool
  before the support factor, leaving capacity for a normal fight and another.
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
  (attacker's chance, ×2 since Round 33, for damage and heals) and — for player targets — **dodge**
  (combat_stats §2), then apply via `object:punch` so armor groups and mob
  death handling (XP, loot) keep working. Ability (cast) punches carry no
  knockback; only Strike and the melee swing skills push a normal mob back
  (combat_stats §3, Round 28 ruling 7). A future knockback skill displaces
  the mob through `grug_mobs.displace_mob`; the `damage_groups.knockback`
  velocity override no longer survives a player hit.
- Mob→player punches roll the player's dodge centrally (hp change
  modifier in `grug_core`).
- **Melee carries the melee bonus and rolls crit** (combat_stats §2). Swing
  ability stacks mirror the equipped weapon's interval for native
  animation/interaction but publish zero damage; their combat packets are
  input only, and the authoritative held loop builds a full slot-fed swing
  against the current server ray. Ordinary tools and fists do not initiate player combat; only selected
  skills may attack.
- **Threat** goes through `grug_core.add_threat` and `add_heal_threat`
  into each mob's threat table (combat_stats §4: tank abilities ×3, healing
  ×0.5); Taunt (`grug_core.taunt`) sets top×1.1 and forces the target
  through mobs_redo `do_attack(player, force)`.

## 2b. Contextual skill input

All selected skills support native empty-hand digging and zero native combat
damage. Swing versus cast describes the effect, not a different mouse binding.
Only skills initiate player combat; ordinary tools retain their gathering role.
The equipped hand slots are the combat source, never a weapon in the hotbar:
Strike and every melee skill swing the melee slot (the Scout's Melee offhand,
everyone else's Weapon slot), the Scout's bow skills read its Ranged slot. A
held skill shows the item of its own slot in first and third person.

### Left click and held input

**Hold modes** (Round 28 ruling 14; one state machine since Round 32). A
held LMB is either **gather** or **combat locked on a foe**; only the start
differs:

- **Start.** At key-down the hold is combat when the combat ray
  (non-walkable plants and dropped items never hide a mob) finds a valid
  hostile within the larger of hand reach (4 m) and the selected skill's
  range (Loose: hand reach only, its LMB is Strike or digging); that hostile,
  a neutral mob too, is its foe. Every other press starts as gather: a node,
  a protected node, a dropped item with no hostile behind it, air, an NPC or
  an ally.
- **Gather** digs and picks up, never attacks. On a protected node the hand
  may not dig (town ground, walls, undiggable dressing), the client keeps
  pointing, so the refused dig keeps the protection hint and, where
  diggable, the client's cracks; a short tap there still casts a selected
  self/support skill (Blink in a town, the same 200 ms window as below), a
  hold only earns the hint. A self or support skill fires once per fresh
  press at its target (air or a hostile for a self skill, an ally for a
  heal) and never from a hold on its own. The only repeat while held: a
  support cast a fresh press began on an ally repeats on that same ally,
  never on another one that walks into the crosshair, and never after that
  press ends.
- **Gather becomes combat** as soon as a hostile combat accepts is in the
  crosshair and within that reach: any mob it may attack, a neutral mob or
  critter too (the user, 2026-10-03), and a player only where
  `grug_pvp.can_harm` allows. It happens only while the selected skill
  attacks hostiles; with a self or support skill selected the hold stays
  gather (a mob walking in never makes a miner cast Ward or Blink). A
  protected player, an NPC, an ally or a hostile out of reach never
  switches it.
- **Combat** never digs: the held skill item's pointing range drops to zero
  (the client points at nothing, so it neither digs nor shows cracks) and
  the server refuses any dig, so a miss beside a living foe digs nothing.
  Each hit goes to the valid hostile now in the crosshair and reach; the
  last one aimed at is the foe (switching enemies is free, and the new one
  is the foe to wait for).
- **Combat becomes gather** when the foe is gone: dead, despawned or
  unloaded, no longer a valid target for this player (its PvP flag dropped,
  so `grug_pvp.can_harm` refuses; a mob evading home after a leash reset,
  which also never switches a gather hold), or fled farther than twice the
  reach above (`FLEE_REACH` in
  `input.lua`; a foe briefly stepping out of reach keeps the lock). A
  hostile in the crosshair at that moment becomes the new foe instead. Then
  the gather rules apply again, including the switch back to combat, also
  for the same foe once it is back in the crosshair and reach.
- **A mob evading home** after a leash reset takes no hit and is no target
  (one predicate, `grug_abilities.valid_target`, for the crosshair, the hold,
  swings and casts; Round 36 §2.14.1): a fresh press at it shows "Evading" in
  the flash line, at most once per 1.5 s, a held press stays quiet; a selected
  self or support skill still fires on the fresh press as it would at a
  hostile. A ray at a mount means its rider, for the press as for the
  crosshair.
- **A hotbar switch while held** (Round 36, the user's playtest finding of
  2026-10-05): an LMB held across a switch to another item is the same
  press, decided again for the new item as if it had been pressed with it,
  once the new item has stayed wielded 0.2 s (real time; a further
  switch restarts the wait, a release inside it acts for nothing). So a
  slot the scroll wheel only passes never fires its skill (Blink mid-fight).
  While it waits the hold acts on nothing (no Strike either), but digging
  does not wait, and a combat lock waits with its zero range. Then
  the start rule above decides gather or combat, except that a combat lock
  keeps its foe while that foe is not gone for the new skill's reach (a
  miss beside it still digs nothing). The new skill then acts as on a fresh
  press: an attacking skill casts or swings (Strike if it is not
  ready), a self or support skill fires once where a fresh press would (at
  a hostile, an ally or air; while a combat lock is kept, also at a node
  beside the foe), Loose strikes. Besides the
  wait, two things differ from a real press: it reports nothing (refusals and "Evading"; a
  held press stays quiet), and it has no tap window, so a gather hold digs
  on at once and a quick release casts nothing. Cooldowns, resources and the
  weapon clock are untouched (back to a skill on cooldown only strikes). A
  switch to an ordinary tool or an empty slot ends the skill mode (both
  stacks point again, the tool or hand digs natively); a switch back is
  decided again. Digging goes on in both directions: the client keeps its
  crack time across a wield change and the server accepts that dig, also
  during the wait and across a fast scroll. A held RMB across a switch stays
  cancelled until both buttons are released (its native place or
  interaction belongs to the old item), as does a hold a stun or death
  cancelled.

The check costs a held gather step nothing on a solid node or air, one
combat ray behind a plant, loot or an actor, and nothing at all with a self
or support skill selected.

The mode ends on release, cancel, death and leave and on a switch to an item
that is no skill; the pointing range returns then. A switch to another skill
decides it again (above) and moves the zero range to the new stack. A
release seen within 0.15 s of the decision keeps the mode (a native punch
can report a press before the control report does). The zero range reaches the client one round trip after the server
sees the press: a press on a mob within 4 m reports itself at once and the
client does not dig for 0.15 s after a punch anyway, but a press on a mob
beyond 4 m is seen with the next control report, and a switch from gather
reaches the client one round trip late, so cracks may flash briefly if the
crosshair is on a diggable node within that window (accepted by the user,
2026-10-01). The node is never removed.

Within its mode, the current first visible crosshair target determines the
action. Every operation checks its own reach: 4 m interaction/digging, 3 m
Strike, and the selected spell's authored range. Solid terrain and
intervening objects (dropped items excepted) matter.

- **Hostile:** use the selected applicable ready skill immediately. If it is
  unavailable (including cooldown, resources or applicability), use ordinary
  melee Strike when in range. Holding repeats at the appropriate clocks;
  once the selected skill is ready it takes precedence again. A selected
  self or support skill fires only on the fresh press (an applicable heal
  here targets self, never the hostile or a remembered ally); held, the
  hold strikes.
- **Friendly player:** use an applicable heal/support action on the eligible
  ally a fresh press aims at, repeated while held on that ally. No Strike
  fallback or attack through that ally.
- **Hand-diggable node:** dig with hand capabilities, never equipped-weapon
  mining power. On the initial press only, a selected self/support skill
  waits approximately 200 ms, whether it is ready or not: short release
  casts (an unready skill reports its refusal at that tap); continued hold
  digs. Without a selected self/support skill, digging begins immediately.
  Leaving the initial node discards its pending release-cast. Later held
  retargeting within the gather hold digs the new node directly; a cooldown
  becoming ready cannot interrupt the dig.
- **Dropped item:** one pickup attempt at the beginning of each physical press,
  including when inventory is full. That decision does not also cast. The
  hold is a gather hold: it may subsequently dig, attack only once a threat
  switches it to combat (above), and another drop requires another
  press. A hostile behind the drop makes it a combat
  press instead: no pickup, the attack goes through the loot.
- **Empty or otherwise inapplicable context** (air, out of reach, a node
  bare hands cannot dig): one applicable self/support activation on the
  fresh press, otherwise no mechanical effect. A hold that later aims at
  air casts nothing.

Block progress belongs to the current node and is lost on retargeting. Apples,
plants and torches require positive digging time; the initial torch timing is
0.3 s. Actual removal preserves normal node callbacks, protection, `can_dig`,
drops and empty-hand tool restrictions. Digging never wears a skill item.
Crack feedback may begin during click arbitration, but removal may not.

### Scheduling and effect boundaries

Selected skill and fallback Strike are mutually exclusive in one decision.
After a successful skill, Strike must wait at least the actual weapon interval,
without shortening a later existing deadline. Skill cooldowns/cast intervals
still apply; no global cooldown is added. Early clicks, release/repress,
retargeting and skill swaps cannot reset the weapon clock. Concrete equipped
weapon changes start a full interval; lag never replays missed attacks.

Combat and healing actions repeat against appropriate aimed targets. Movement
utilities such as Blink and Sprint activate once per physical press, even if
cooldown expires during the hold; Ice Nova remains a combat action. In empty
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
pending item actions; it cannot also launch a bow. Food is the exception
described below: a food press decides click versus hold first. Interaction
reach remains 4 m even with a long-range spell selected.

Loose is the explicit exception to LMB casting: **LMB uses melee Strike or hand
digging; hold RMB to draw, release RMB to shoot.** Its tooltip states both.
While the bow is drawn or held drawn, walk speed is ×0.5 and the Loose item's
pointing range is zero (the same zero range an LMB combat hold uses;
whichever ends first leaves it to the other), so held RMB shows no repeated
place swing (one swing on the very press may remain). A full draw takes the
bow's 2.5 s (Fletching and the draw-speed affix shorten it); a ring around the
crosshair fills in sixteenths while drawing, turns gold at full draw and
disappears on every end of the draw (release, cancel, stun, item or weapon
change, death, leave). Other instant bow skills retain their LMB casts and
authored ammo/cooldowns.

Food owns its whole RMB press, whatever it points at (ruling 2026-09-28). A
release within 200 ms is a **click**: on release it performs the ordinary
right-click at the target the press began on — placing a placeable food
(apple, meat blocks), planting, or opening the pointed door, container, NPC or
trader. Holding 200 ms or longer is a **hold**: it eats one serving 1.5 s after
the press and never interacts with the pointed node or entity; engine place
repeats during the hold do nothing, and placeable foods show no client
placement preview. Pointing at nothing, a hold eats as well. In combat the
hold is refused at the 200 ms mark with "Cannot eat while in combat." (no
visual, no slowdown); a click in combat still places or interacts. While
eating, the wielded item hides, the food's image shows large at the bottom
centre behind the HUD and bobs, crumbs fly from the head every 0.2 s, the
eating sound loops at half gain and walk speed is ×0.35. The crosshair
progress ring (the bow draw ring's frames, tinted green, never the gold full
frame) appears when the hold is confirmed at 200 ms and fills with held time
/ 1.5 s; it disappears on every end of eating (release, portion eaten,
cancel, stun, item or slot change, death, leave) and never appears on a
combat refusal. Release before 1.5 s
eats nothing; one press eats at most one serving. Active RMB food/draw
suppresses LMB combat/digging. Seeds, buckets, hoes, fishing, mounts and
ordinary placed items retain their own context-appropriate actions.

### Failure messages

A skill that cannot act says why in the red flash line ("Fireball is not
ready.", "Not enough mana.", "No room to blink.", "Not enough room at
target.", "You need an arrow.", ...) — on a fresh press only: the key-down
decision, the single empty-space or tap cast of a press, or the RMB press that
starts a bow draw. Held repeats never report, nor does the decision of a press
carried across a hotbar switch. The same message shows at most
once per second per player; a different message shows at once (Round 28
ruling 13). A refused skill on a hostile still falls back to Strike, as
before.

### Cancellation and native-client limits

Stun and death cancel pending actions. An item swap drops the old item's
pending actions (a tap, a bow draw, eating); an LMB held across it goes on
with the new item (hold modes above). Our own NPC/node interactions
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

### Crosshair feedback

The game ships its own `crosshair.png` and a byte-identical
`object_crosshair.png`, so the engine's native "pointing at an object" switch
is invisible (skill items keep a 4-node native range for hand digging and
would mark only targets within 4 m). All target feedback is a server HUD
overlay: the same crosshair image tinted, drawn over the engine crosshair
(user ruling 2026-09-28).

- **Hostile (red):** the selected skill targets hostiles and its own aim
  authority finds a valid hostile within the skill's effective range: the
  current server ray to `get_range` (swing skills 3 m, Taunt 8, Charge 12,
  Fireball/Smite 20, Loose 25 or 33 with Longshot, plus the race bonus where
  it applies) and the skill's target rule, the same predicate a press uses
  (a mob evading home is no target). The overlay reads that authority
  without its side effects: no Target Frame memory, no cast diagnostics.
- **Red or green only where a press would act:** no skill state while the
  player cannot act (mounted, stunned, in character creation); the ray still
  feeds the Target Frame.
- **Friendly (green):** the selected skill is a friendly heal/buff and a valid
  visible ally is pointed within its range (the ally rule of the friendly
  casts, without their side effects).
- **Interact (light blue):** the first thing within hand reach (4 m) is
  something a press would interact with: an entity with `on_rightclick` (NPC,
  trader, villager, mount), a dropped item, or a node with `on_rightclick`.
  This applies with any wielded item, and uses contextual input's own
  classification.
- A skill state takes precedence over interact. Self-target skills (Blink,
  Ice Nova, Sprint, ...) have no skill state. Otherwise the plain crosshair
  shows.
- The state is refreshed every 0.15 s from the shared 0.05 s input pass,
  whose input handling and weapon-ready ring stay on every pass (one
  hand-reach ray per player, plus one skill ray while a targeted skill is
  selected; the skill ray is skipped when the hand ray's first hit is a
  walkable node, because a combat ray along the same line would end there
  without a target, and for up to 0.25 s while the same skill looks from the
  same eye position along the same direction and its last ray hit no object)
  and sends a HUD packet only when it changes. Its server-driven latency is
  accepted.
- Layering, bottom to top: engine crosshair, state overlay (z 1), weapon-ready
  ring (z 2), progress ring (z 3). The progress ring is one element shared by
  the bow draw and eating: whichever shows it first owns it until it hides it,
  and neither can show or hide it over the other.
- The engine draws the crosshair at integer scale `floor(hud_scaling x
  display density)`; a Lua image element uses the unrounded factor. The
  overlay and draw ring therefore scale by `floor(f) / f` of the client's
  reported `real_hud_scaling` when it is fractional, so they land on the
  crosshair's own pixels. All sprites have odd sizes, centred like the
  crosshair; on an odd window width the two can still differ by one pixel.

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

### The cooldown overlay

Round 40 (the user's rulings and picks, round plan §2.1, §2.9, §2.13); it
replaces the item wear bar, which no longer shows cooldowns or charges.

- A skill with a running **cooldown** (cast skills) or **charge** (swing
  skills: Hamstring, Opening) that sits in a **hotbar** slot is covered with
  **50 % black over the whole icon square**; the cover clears **clockwise
  from twelve o'clock** like a clock hand. It is drawn from 72 pre-rendered
  frames, one per 5°; a frame shows the elapsed share, so the frame count
  never depends on the duration (2 s and 300 s use the same frames).
- The **remaining time** sits in the middle of the icon as **image digits**
  that scale with the icon (white, black outline), without decimals or unit:
  above 60 s the minutes rounded up (`5m` from 5:00 down to 4:01, `2m` at
  1:01), from 60 s down the seconds rounded up (`60`, `59` … `1`).
- **No ready signal:** cover and number vanish when the skill is ready; a
  fully charged swing skill shows nothing, which is the default state.
- **Hotbar only:** a skill in a bag or in the main inventory past the hotbar
  shows nothing. The overlay follows a skill moved between slots or into
  and out of the hotbar, the hotbar's item count and the engine's two-row
  split in a narrow window.
- **Cost:** per shown slot two HUD image elements (the cover and the whole
  number as one image). One pass every 0.1 s visits only players with a
  running cooldown or charge, at most 100 per pass (up to 100 such players
  keep the 0.1 s cadence; beyond that they take turns, round robin), and
  writes only a visible change: a new frame, a new number, an element added
  or removed (a 300 s cooldown: 134 changes; a pass with nothing new sends
  nothing). The hotbar is read again after an
  inventory action, a new timer and every 0.5 s. The overlay never writes
  the inventory (the wear bar re-sent the whole `main` list on every
  visible step).
- **Layout:** the elements sit on the engine's own slot rectangles,
  computed from the window size and the `real_hud_scaling` and
  `real_gui_scaling` the client reports (about 0.2 s after a resize, polled
  every 0.5 s). The server cannot tell the display density from
  `gui_scaling`: it assumes `gui_scaling` 1 (which matters only where 48 ×
  density is not a whole number) and `hud_hotbar_max_width` at its default
  1.0. A client that reports no window information gets fixed HUD units for
  one row at density 1.
- Code: `grug_abilities/cooldown_hud.lua` (the elements and the pass),
  `cooldown_math.lua` (number, frame and slot arithmetic, the digit size
  `DIGIT_SHARE`); textures from `tools/r40_cd/gen_cooldown_textures.py`
  (`--check`).

### Strike

Strike is the **universal** ability — no class owns it, every character has
it, including one that has not picked a class yet.

| Ability | Cost | Charge | Effect |
|---------|------|--------|--------|
| Strike | free | none — it is the plain attack | Native melee (3 m) with the item in the melee slot (the Scout's Melee offhand, otherwise the Weapon slot): weapon damage + melee attribute/10 (Scout Dex, otherwise Str; fractions count), crit ×2, threat ×1. Grants the Warrior 8 rage per landed swing (§1, §3). Hold or click LMB. |

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
- **An empty melee slot makes it weak, never uncastable**: it swings for
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
lists. `craft`, equipment, the quiver, bag slots, nodes, detached inventories and
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
- Preserve bow draw stages, the cooldown overlay, material-tier weapon appearance
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
| Charge | — (generates 15 rage) | cast, 10 s | Dash to the currently pointed enemy up to 12 m away; on arrival within reach 12 % of a base hit (`combat_stats.md` §2; the former flat 3 at level 30), the 15 rage and, on an accepted hit, a 1.5 s stun. A dash that ends out of reach is a miss: the cooldown is spent, nothing else. Kings and dragons are stun-immune. No enemy-memory fallback. Destination, dash and arrival below. |
| Mighty Blow | 25 rage | **swing**, no charge | On a completed landed swing with enough rage, the total is exactly floor(weapon damage × 1.5) + melee bonus instead of the plain hit. Its delta is folded into that native punch before its one crit/mitigation/dodge path — never a second punch. The rage dump. |
| Hamstring | 10 rage | **swing**, 6 s charge | The swing lands as usual; on a charged proc it also applies a 50% slow for 5 s. **Not in the base kit since ruling 19** (2026-09-16): every class starts with Strike plus three, and Hamstring returns as the Ruin tree's keystone (`skill_trees.md` §2.2). It stays registered and talent-gated, exactly as Mend has been since WP19. |
| Taunt | free | cast, 8 s | Currently pointed mob (8 m) is forced onto the Warrior for 3 s; no enemy-memory fallback; threat set to top×1.1 (combat_stats §4). |

**Charge destination** (Round 28 ruling 12). The preferred spot is 1.3 m in
front of the target on the line toward the caster, at the target's feet
height; it is always tried, even when the caster stands closer. Room is
checked with Blink's rules: the player's real collision box against the
nodes' collision boxes, one node of step-up allowed, and a clear ray from the
caster's eye to the destination eye. A spot without room is searched back
toward the caster in 0.5 m steps; the back-search never passes the caster and
stays at most 3 m (melee reach) horizontally from the target's centre. With
no room the cast fails with "Not enough room at target." and costs neither
rage nor cooldown. While LMB stays held on the target, a failed Charge is
retried at most every 0.25 s; Strike swings in between.

**Charge is a dash** (Round 40, rulings 3, 10, 11 and 16 of the
[round plan](../planning/round40-plan.md)). The warrior rides an invisible
carrier from the cast position to the destination at a constant **24 m/s**
and cannot steer; the path is planned once at the cast from the ground along
the line (`grug_abilities/charge_path.lua`): level ground is a straight run,
every step, slope, low obstacle (at most 1.6 m) or drop (at most 4 m) is a
ballistic hop, so uphill the dash reads as leaps.

- **Holes:** where the ground drops away (no ground, a liquid, or ground
  lower than the rim) and comes back within **4 nodes** (rim to far rim) at
  most **one node above the rim**, the hole is crossed in **one hop**,
  whatever its depth; shallow dips are jumped too. Liquids count as air: a
  hop crosses them, but the dash never lands or stands in a liquid. A hole
  that does not come back that way stops the dash **at its rim**; ground
  within reach below is followed down (a ledge, a wide dip), and a dash that
  then cannot climb out again stops at the rim of that drop.
- **Arrival:** when the dash ends, the hit lands if the warrior's feet are
  within **3 m** (`CHARGE_REACH`, the Strike range) of the target's
  collision box and the target is still a valid hostile (re-fetched; the PvP
  flags asked again): damage, the stun, the 15 rage and the dust ring at the
  target. Otherwise it is a **miss** — a wall, a rim, a target that moved —
  and only the cooldown is spent. A cast that cannot start (no target, no
  room) still costs nothing.
- **Cancelled:** a stun or root on the warrior, death, logout and every
  travel (`grug_home/travel.lua`, before its teleport) end the dash at once
  as a miss. A warrior rooted at the cast does not move.
- **During the dash** hits reach the warrior (no immunity); knockback and
  pulls do not change where the dash ends. He keeps the charge pose; in third person and for
  others the model runs 0.5 m ahead of the camera on dashes of 3 m or more;
  first person gets a short FOV kick (×1.1). Dust rises along the level
  stretches.
- **The stop:** the warrior is held on the stop for about 0.34 s (three of
  the client's smoothing time constants at the default 0.09 s server step)
  and then put exactly on it, so the client's trailing drawn position
  cannot leave him short (on a stair, the stair below).

### The rage ledger (ruling 25, 2026-09-16)

The user's finding of 2026-09-16 was that **rage fills too fast** — "in combat
the resource is effectively unlimited". Ruling 25 answers it with **option
(b): lower the income and add decay**. These are the current numbers.

| Source | Rage | Note |
|--------|------|------|
| a landed full swing | **+8** | was +12. Only an authoritative swing (Strike or a swing skill) lands; native tool and fist packets deal nothing and pay nothing. |
| a hit taken | **+3** | was +4. The orc race passive adds +1 (`world.md` §7). |
| Charge | +15 | unchanged; it is an engage tool, not income. |
| out of combat | **−5 per second** | was −2 per second, on the shared `grug_core.in_combat` state (combat_stats §5). |
| cap | 100 | unchanged. |

Trinket specials add to this ledger: the Battlebeat Band's rage per accepted
weapon hit and the Reclaimer's Mark's rage on an XP-eligible kill
(`items_crafting.md` §6.2,
[trinket exception](items_crafting.md#trinket-exception-one-prefix-one-suffix-one-special)).

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
5 mana against a 240+ pool was free), Ice
Nova became the rotation pivot — kiting IS the Mage fantasy here.

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Fireball | 6% base mana | **1 s cast interval** (server cadence, no cooldown bar) | Targeted homing projectile, nominal 20 m/s and initial range 20 m; current aim/LOS required at release. Baseline weapon + spell power through the damage fit at impact. No target or input inside the interval costs nothing; at most eight shots per owner/session may be active. |
| Ice Nova | 10% base mana | 12 s | Deals one quarter of (level-baseline weapon damage + spell power), then roots accepted hostile hits within 5 m for 4 s, followed by 50% slow for 3 s. Spell damage scaling applies once. Players use the hard-root movement flag; rooted targets may still attack. Small crystal particles persist only while the Nova root is active. |
| Blink | 8% base mana | 15 s | Teleport up to 10 m in look direction, never through walls. Escape valve. Targeting below. |

**Blink targeting** (playtest ruling, 2026-09-28). The look ray runs from the
eye for the full distance; walkable nodes stop it, non-walkable nodes (plants,
torches, liquids) do not.

- **Top face aimed at** (ground, a roof, a pillar top): the player stands on it
  at the aimed point.
- **Side face aimed at** (a wall): eye level in front of the face, standing on
  the ground there if the feet would be inside it, otherwise in the air as
  aimed. If the aimed node's top is at most one node above that spot and has
  room, the player steps up onto it instead; a two-node wall is not climbed.
- **Ceiling aimed at**: head just below it (the player then falls).
- **Nothing hit**: the eye moves the full distance, also straight up or over a
  hole; falling afterwards is intended, there is no fall protection. When the
  ray ends less than eye height above the ground, the feet would be inside
  it: the player is lifted to stand on the ground there (at most eye height).
- Room is checked with the player's real collision box against the nodes'
  collision boxes. A box that clips a block beside the chosen spot is first
  moved to the centre of its node column rather than lifted onto the block.
  A spot without room is searched back horizontally toward the caster in
  0.5 m steps, allowing up to one node of step-up (eye height when nothing
  was hit). Every destination must be in line of sight: a clear ray from the
  caster's eye to the destination eye.
- A move shorter than 1.5 m fails with "No room to blink." and costs neither
  mana nor cooldown. On flat ground this means aiming steeper than about 45°
  down fails.

## 5. Priest (Mana)

Healer/support with a solo damage tool.

Kit tuning decided 2026-08-06 (implementation: WP19): **Shield replaces
Mend** in the base kit (an absorb plays differently from a second heal and
makes the Priest useful BEFORE damage lands; our central hp-change modifier
makes absorbs nearly free to build). Mend moves into the talent tree.

Skill names (Round 31 user ruling): skills that carried another game's exact
names were renamed — the Priest's Heal, Shield and Mend and the Mage's Ice
Nova (§4). Generic words such as Smite, Blink or Sprint stay. The Shield
spell is an absorb on a player; its tooltip says so, which keeps it apart from
the offhand shield items. Mend's display name lives on its Mercy keystone
(`grug_classes/talents.lua`), which the ability reads.

| Ability | Cost | Cooldown | Effect |
|---------|------|----------|--------|
| Smite | 5% base mana | 2 s | Current-crosshair 20 m hit with no enemy-memory fallback: 1.5 × (baseline weapon + spell power), then the damage fit. Solo viability. |
| Heal | 8% base mana | 4 s | Heals 25% of the class-neutral base pool times the support factor (gear Intelligence, `combat_stats.md` §2; exactly 25% without Intelligence gear). Resolves currently pointed valid ally (15 m) → self. Threat: 0.5× effective healing (WP6). |
| Shield | 8% base mana | 10 s | Resolves currently pointed valid ally → self; soaks 25% of the class-neutral base pool times the support factor for 15 s or until consumed. |
| Mend *(talent)* | 6% base mana | 8 s | Resolves currently pointed valid ally → self; heals 8% of the class-neutral base pool times the support factor every 3 s for 12 s. Unlocked via the Mercy tree (WP11). |

## 6. Explicitly deferred

- Cast times / cast-bar spells → Phase 3 polish. (Ability sounds landed in
  Round 34: one cue per ability theme, `grug_abilities.CAST_SOUNDS`.)
  (**Ability icons are no longer deferred**: Round 18 separates action icons from held weapon art; historically an ability
  item shows the equipped weapon plus its own color — §2c.)
- Warrior shield abilities: none exist and none is scheduled; WP14
  delivered the offhand shields without one (BACKLOG "Audit 2026-10 open
  questions", DP-10).
- Party buffs and auras (e.g. a party-wide war cry) → later; the skill
  trees added none. (Shield moved into the base kit with the
  WP19 kit tuning, §5.) Party frames are implemented under the separate
  [party contract](parties.md).
- The Scout has no player poison mechanic and no player poison stat. Its Veil
  tree uses existing dodge, crit, slow and escape mechanics. Mob poison and
  Alchemy's Antivenom remain separate world mechanics. Stealth is deferred in
  [scout.md](scout.md) §8; the current Veil capstone is Untouchable.
- PvP tuning of roots/taunt (diminishing returns etc.) → balancing pass.

### Round 16 control execution

Stun prevents voluntary movement and all new or pending skills, native melee,
held swings and bow release. Pending input is discarded without catch-up bursts;
already launched projectiles continue. Gravity is unchanged. Stun and root have
independent lifetimes; root/slow immunity does not grant stun immunity. Death
and disconnect clear player control. Nova respects accepted damage/PvP gates
and movement immunity. Its baseline excludes Fireball-specific talents; Rimebite
adds 25 % of a base hit and half spell power once before spell scaling.
