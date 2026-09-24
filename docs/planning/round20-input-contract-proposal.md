# Round 20 input contract — agreed design

Updated 2026-09-24. Owner: root GPT-6 Astra. **Design and implementation approved by explicit round Go, 2026-09-24.**
Parent: [round plan](round20-pois-quests-fixes.md), F5.

## Latest user intent

Only skill representations can initiate player combat. Other held tools/items
retain their noncombat purpose. Every selected skill can dig with empty-hand
capabilities; equipped weapons do not grant mining or woodcutting abilities.

LMB is contextual and can change behavior while held without a new press:
enemy -> combat, block -> digging, empty space -> no targeted action.
The earlier policy preventing digging after an enemy dies is explicitly
superseded. RMB digging was an unapproved suggestion and is withdrawn.

Against a valid hostile, immediately execute the selected usable skill. During
its cooldown, repeat Strike while LMB remains held. When ready, use the skill
again, then return to Strike. Separate a successful skill from the next Strike
by an ordinary weapon swing interval. A released button stops repetition.

At a reachable diggable node, only a competing usable self/friendly skill
requires click/hold arbitration. Short release uses that skill; holding digs.
If the skill cannot apply, start digging immediately. Apples, plants and
torches must have positive dig time rather than instant removal.

Ground drops are different: pick up immediately on press. Held input may then
dig/attack what becomes visible, without automatically consuming a pile of
additional drops. There is exactly one pickup attempt per physical press, at its beginning.

Without an actionable target, execute an applicable self/friendly skill;
otherwise do nothing mechanically. Later retargeting may enter combat/digging.

RMB clicks interact; held RMB consumes food or draws a bow, release fires.
Context-first NPC/container/door interaction is agreed: it owns that
RMB press until release, so holding an interaction cannot also eat/fire.

## Verified current behavior, not new rules

- `grug_abilities/kits.lua:242`: Strike is universal, free and melee, range 3.
  It is not Fireball, Smite or an arrow attack selected by class.
- `grug_abilities/init.lua:1619`: no global cooldown. Skills have individual
  cooldowns and some have cast intervals; swings have an authoritative clock.
- `kits.lua:68`: healing chooses pointed eligible ally, then valid retained
  friendly target, then self. Looking at an enemy/air does not necessarily
  select self. This is the defect the user explicitly rejects; replace it with
  currently pointed valid in-range visible ally, otherwise self. No old target
  memory may participate. This applies to heals and shields, including Renew.
- `scout.lua:409`: Loose is a special draw/release skill; instant bow skills
  have separate casts. Do not accidentally trigger draw via generic LMB cast.
- Cast item `on_use` suppresses native client digging; swing pointability
  currently blocks diggable nodes. Enabling all-skill digging is not one flag.
- Native RMB may invoke both item and entity callbacks; some node forms open
  client-side. Server-only global short/long arbitration cannot reliably
  postpone every ordinary interaction.

## Agreed decision model

Three input states suffice: released, initial ambiguous-block pending, held.
Keep the current dig target/progress and existing action clocks separately.
Do not store a permanent combat-versus-dig mode for the whole LMB press.

### Initial press

1. Check player/action eligibility (alive, not stunned, applicable mount/UI
   restrictions). Do not create delayed actions that fire after stun/death/UI.
2. Resolve the current first visible target and applicable action-specific
   ranges. Solid unbreakable terrain still blocks targets behind it.
3. Reachable dropped item: perform the existing pickup action once; do not also
   cast or attack in that same decision. A full inventory still consumes this
   pickup attempt rather than falling through to a spell behind the item.
4. Hostile: selected applicable skill first, otherwise valid Strike. Never
   heal the enemy. An otherwise usable heal resolves to self in this context;
   only if unavailable/inapplicable does it fall back to Strike. No remembered
   friendly target participates.
5. Eligible friendly player: selected heal/support first, never Strike. An
   offensive selection does not attack through the ally to a hostile behind it.
6. Reachable hand-diggable node: if a competing self/friendly action is usable,
   enter pending; otherwise start ordinary timed digging immediately.
7. Other context: one applicable self/friendly activation; otherwise no effect.

NPCs/guards without an authorized healing path do not become friendly heal
targets. NPC interaction remains RMB. Neutral attackable wildlife follows
existing combat eligibility, not nametag color alone.

Friendly target selection runs at each new activation, including automatic
repeats. A previously applied Renew or shield stays on its original recipient;
moving the crosshair does not transfer existing effects or their later ticks.

### Pending block (initial threshold: approximately 200 ms)

- Wait only at the initial ambiguous block, not at every retarget.
- Release before threshold: revalidate and cast the selected action once.
- Reach threshold: choose digging; no release-cast afterward. The decision
  delay counts toward elapsed digging time, but no node can be removed before
  arbitration completes. Digging still takes at least its real required time.
- If the aimed block, item or action context changes while pending, discard
  the old release-cast intent and use the current context. No queued spell
  firing later on an unrelated target.
- Once digging is selected, a skill becoming ready does not interrupt it.
- Once the press is already held, enemy -> block enters digging directly and
  block -> enemy enters combat subject to the existing clocks.
- Dig progress belongs to one block and is lost when leaving that block.

Initial torch timing: a short positive 0.3-second dig time, no material tier
requirement. Review other `dig_immediate` harvestable nodes for the same
positive-time requirement without changing ores/tool-tier rules. These are the accepted initial tuning values and may be adjusted after playtest.

### Combat scheduling

"Usable" includes unlocked/equipped eligibility, correct target, resources,
range, line of sight, cooldown, cast interval and current actor restrictions.
An unavailable skill can fall back to Strike for those ordinary
failures, not only cooldown. A global prohibition (stun, death, blocked attack)
must not be bypassed by fallback. No error spam every held-input tick.

Selected skill and fallback Strike are mutually exclusive in one decision.
A successful skill moves the next allowed fallback Strike to at least
`now + actual swing interval`, while preserving any later existing deadline.
Use the current equipment/talent interval, not a fixed extra cooldown. Never
reset attack eligibility by releasing, retargeting or swapping hotbar slots.
Every selected skill still obeys its own cast interval/cooldown. No global
cooldown is introduced by this input work. No replay of missed attacks after
server lag; delayed projectiles still deal damage at their existing impact.

Each concrete action checks its own reach: a visible caster target at 20 nodes
does not allow a 20-node Strike, pickup or dig. Self-skill `range` values are
not a generic hostile-context limit (some are zero). Beyond Strike reach,
wait for the selected ranged skill rather than manufacture ranged melee.

### Repeat policy (agreed)

Use two explicit policies in the small skill registry:
- Combat/healing skills: repeat while appropriate target context remains,
  following cooldown/resources; hostile cooldown gaps may use Strike.
- Movement/utility (e.g. Blink/Sprint): once per physical press, then only
  Strike in hostile context; no automatic second movement on cooldown expiry.
  Once used for this press, that utility skill is no longer applicable to it.

Frost Nova is an offensive combat skill despite being self-targeted, so do not
derive repeat policy solely from `target_kind`. Friendly healing can repeat
against an explicitly aimed ally; no fallback attack on that ally. In empty
space, self/friendly skills activate once per press, not repeated
heals/buffs while searching for a block. Self in this rule is the caster,
never a stored friendly target.

### Drop pickup (agreed)

At most one pickup attempt per physical press, at its beginning. Held input
can transition to attack/dig afterward; another drop requires release/press.
This intentionally simplifies the user's suggested rearm on target change,
avoiding a distinction between mouse-driven changes and automatic exposure
of the next object when a drop disappears. The user accepted this simplification.

### Bow and simultaneous buttons

Use literal melee Strike as the LMB fallback for every class, including
bow users; do not add free automatic ranged attacks or a second bow firing
path. Loose itself is RMB draw/release only. Instant bow skills remain selected
LMB actions; they use ammunition/cooldowns as before. This explicit Loose
exception prevents the generic "selected ready skill" branch starting draw.

Loose tooltip must explicitly explain: "LMB: melee Strike or hand digging.
Hold RMB to draw the bow; release RMB to shoot." Existing range/ammunition
requirements remain visible. Strike is only the fallback when the selected
LMB skill is unavailable/inapplicable; Loose is explicitly an RMB action.

Food requires 1.5 seconds of uninterrupted RMB hold for exactly one serving;
release rearms the next serving. Keep the eating sound at gain 0.5.

RMB food/draw owns the item action until released. No simultaneous
LMB digging/attack while that hold is active; do not allow double-use of the
weapon/ammunition. Define this as a single input-action priority, not a new
combat cooldown. Item swap/death/stun/GUI interruptions cancel pending holds.

RMB is not globally empty for other items: block/seed placement, hoe/bucket,
fishing and mount use retain their appropriate contextual actions. Correct
interaction first, rather than swallowing ordinary node/actor callbacks.

## Implementation scope and stop conditions

Astra owns this lane, with independent Sol/Astra review. No engine/client fork.
Prefer existing normal digging/event paths where they support the contract;
do not assume changing pointability repairs cast tools. Preserve node `on_dig`,
`can_dig`, protection, hand-equivalent drops and materials wrappers. Direct
`core.node_dig` skips custom `on_dig` and uses the real wielded item for wear;
skill cooldown wear must not be consumed by digging. No temporary inventory
emptying or fake PlayerRef. If native digging feedback requires a substantial
combat input rewrite or a parallel digging engine, report the concrete tradeoff
before implementation; do not quietly substitute RMB digging.

Bounded final cases: enemy/block/air transitions; timed ambiguous block;
enemy ready/unready/unaffordable; ally heal; action-specific ranges; one-drop
behavior; no clock reset exploit; positive torch time; bow versus LMB; cancellation
and protected/custom nodes. These extend the round's compact final checks,
not a new large test fleet. Execution is tracked in round20-state.md.

Planning evidence: root source inspection plus independent native Astra
`r20_input_state_review` read-only preflight. No runtime tests or game edits.

## Decision receipt

User confirmed the proposed simplifications and timing on 2026-09-24, including
literal melee Strike fallback, one pickup per press, once-per-press Blink/Sprint
and Loose LMB Strike/RMB draw, with explicit tooltip instructions. The user
rejected remembered friendly targeting: current eligible crosshair ally only,
otherwise self. Living class/combat docs now record that change as decided but
not yet implemented. Explicit round execution Go followed on 2026-09-24.

Independent final documentation review: GPT-5.6 Sol PASS, 0 High/Medium
findings. No game changes or executable tests were part of this approval.

## Accepted native-client limits (user follow-up during execution)

The user accepted both limits explicitly on 2026-09-24:

- Opening the native inventory, pause menu, chat or losing focus releases the
  client's controls without a distinct server-visible GUI-open event. Treat
  this as ordinary release: a drawn bow may fire or a pending short-click
  skill may activate. Known server-side NPC/node interactions cancel first.
  The earlier universal GUI-cancellation requirement is narrowed accordingly.
- With native digging enabled, a very short air click can fall between control
  reports (about 90 ms at the default server step) and be missed. Native
  node/object interaction packets provide additional press events; pure air
  input uses the observed control edges. The user accepted this for playtest;
  do not claim guaranteed capture of all short air clicks or add a client mod.

Native crack feedback may start before the approximately 200 ms decision;
actual node removal must still wait for arbitration and its normal dig time.
The skill-only guard delegates the real node callbacks and never reproduces
node digging, drop, protection or wear rules in a second engine.
