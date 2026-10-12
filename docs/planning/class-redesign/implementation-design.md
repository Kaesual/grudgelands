# Class redesign implementation design

Planning foundation, 2026-10-12. This document explains how the four class
candidates fit together, how their abilities work with first-person input,
and what a coordinator must settle before assigning implementation lanes.
It is not a round plan or permission to change the running game.

**Status:** the user supports the redesign direction and approved the
first-person targeting changes. Exact talent graphs, numerical balance and
the remaining choices have not received blanket final acceptance. This
documentation change is **compatible**; eventual talent and skill replacement
needs its own saved-state/migration assessment.

## 1. Authority and reading order

Read this document first, then the relevant class specification and the
approved [ability targeting contract](../../design/ability_targeting.md).
The latter owns future interaction behavior and supersedes older targeting
wording in the handoff. Do not implement a historical paragraph instead of
the current rule.

| Subject | Authoritative location for this planning package |
|---|---|
| Approved first-person targeting behavior | [Ability targeting](../../design/ability_targeting.md) |
| Mage talent graph and initial kit | [Handoff, Mage section](../class-redesign-handoff.md#5-mage-design-proposal), amended by [Mage candidate](mage.md) |
| Warrior graph, skills, formulas and builds | [Warrior candidate](warrior.md) |
| Priest graph, skills, formulas and builds | [Priest candidate](priest.md) |
| Scout graph, skills, formulas and builds | [Scout candidate](scout.md) |
| Cross-class comparisons and their assumptions | [Balance review](balance.md) |
| Approved hotbar direction and earlier discussion | [Handoff](../class-redesign-handoff.md#3-user-decisions) |
| Decisions still needed | [Class redesign TODO](../../../TODO-design-classes.md) |
| Currently shipped mechanics | [Classes](../../design/classes.md), [talents](../../design/skill_trees.md), [combat stats](../../design/combat_stats.md) |

Do not copy numerical talent tables into lane briefs as a separately editable
specification. Link the owner and identify the selected revision. The
[visual overview](README.md) is derived from the candidates, not a second
balance authority. Descriptions here summarize class roles; the linked
tables retain exact coefficients, durations, gates and costs.

## 2. Shared character progression

The intended experience starts with a small usable kit and earns defining
tools early. A normal combat loadout uses four to six equipped abilities,
including its basic attack and any ultimate. Owning more skills is allowed;
standard rotations must not depend on continuous hotbar switching.

The candidates retain one point at each even level, reaching 30 at level 60.
A tree gate counts points already spent in that tree, excluding the purchase
being made. Each listed predecessor requires at least one rank, not a full
chain. An ultimate costs one point after 20 in its tree: earliest level 42,
and two ultimates cannot coexist. A mixed build may take neither.

The retained graph shapes offer early identity, intermediate active skills
and later improvement of tools the player already knows. Transformations
replace the old skill representation in both hotbar layouts. They do not
give a second independently usable copy or reset a cooldown. Candidate graph
and purchase details remain in their class owners.

## 3. Class roles and ordinary play

### Mage: Ember and Rime

The starter candidate is Fiery Spark plus Ice Wave. Spark is a free magical
basic attack replacing Strike from creation. Ember develops separately
learned Fireball, prepared Flame Lance, Meteor and Fire Rain. The player
chooses which paid attacks suit the encounter rather than equipping every
one to make the class work.

Rime turns the basic attack into Cold Spark, earns Blink and Ice Armor, then
turns Ice Wave into Nova. Cold Shock rewards a successful Nova through the
next existing basic attack. Winter Field is the current ultimate candidate;
Ice Cage remains an alternative requiring a separate decision.

Ember earns greater damage with less safety. Rime trades damage for slow,
root and protection. Neither Spark has splash; Fireball remains separate
and can coexist with Cold Spark. Fixed area attacks use the new preview
and placement contract. Ordinary examples: Ember's Spark, Fireball, Ice
Wave, Meteor, Fire Rain; Rime's Cold Spark, Nova, Blink, Ice Armor, Winter
Field. These are loadout examples, not an obligation to use every cooldown.

### Warrior: Bulwark and Ruin

Strike and Charge establish contact and rage. Bulwark turns the basic attack
into Retort, earns Hold Ground and later bounded counterattack recovery.
Rage still competes with offensive spending. Taunt becomes Bellow for group
control; neither requires clicking a group or manipulating player input.
Unbroken is an active protection window, not immunity.

Ruin spends rage through Mighty Blow and later its Broadstroke transformation.
Hamstring retains contact; Ruination strengthens a short attack window.
All offensive swings occupy their ordinary attack time. Cleave secondaries
are automatic within the forward area and do not create extra primary-hit
resources or procs.

Bulwark may level somewhat more slowly, but its active protection and bounded
recovery must make mistakes visibly more survivable despite longer exposure.
An ordinary solo loadout needs only Retort, Charge, Hold Ground and Unbroken;
Ruin uses Strike, Charge, Broadstroke, Hamstring and Ruination.

### Priest: Mercy and Reckoning

Smite and Heal provide a free ranged attack and deliberate support from the
start. Mercy earns Shield, Mend, Hearten and Haven; it has its own attack
investment so solo play needs no Reckoning tax. Reckoning buys Rebuke, Word
of Ruin, Censure and Final Word. Its limited offensive recovery is bounded
by actual hostile HP removed, not merely nominal damage or absorb removal.

Single-target support captures its recipient at activation. Group support
selects automatically at release. Neither opens a party-selection interface.
The player chooses when to spend an attack opportunity on support; healing
must not run alongside an uninterrupted free attack stream.

The user's damage-role direction applies to offensive Priest builds too:
damage remains slightly below a comparably equipped Fire Mage, with healing
as a separate advantage. No fixed percentage gap or engine damage clamp is
introduced. Mercy's ordinary five are Smite, Heal, Shield, Mend and Haven;
Reckoning's are Smite, Heal, Rebuke, Word of Ruin and Final Word.

### Scout: Quarry and Veil

Loose and Sidestep give an immediately responsive bow and an active defense.
The normal shot uses a short fixed preparation rather than the old mandatory
long draw. Quarry mixes quick arrows with Aimed Shot, Snare Shot, Split Shot
and the committed Arrowfall volley. The bow remains useful without talents.

Veil's Bladecraft changes the basic LMB/RMB representation while preserving
access to both blade and bow. Parry creates an empowered Opening without
requiring the player to get behind an enemy. The rear bonus remains an
opportunity. Flourish covers a frontal group; Close Dance provides a short
offensive/defensive window. Veil does not require invisibility or a positional
teleport. Typical five-skill sets are Loose, Sidestep, Aimed Shot, Snare Shot,
Arrowfall, or Bladecraft, Opening, Parry, Sidestep, Close Dance.

## 4. Complete active-skill targeting map

These modes describe player interaction, not a proposed Lua enum. The same
ability may have an automatic secondary component. Numbers and exact effect
shapes stay in the class specifications.

| Class and abilities | Primary mode and selection behavior |
|---|---|
| Mage Fiery Spark, Cold Spark, Fireball, Flame Lance | Crosshair enemy; Fireball adds automatic impact-centered splash. Prepared hostile casts retain their candidate release-aim validation; Heal's recipient retention is not a global lock-on rule. |
| Mage Ice Wave | Automatic surroundings in the facing cone. |
| Mage Ice Nova | Automatic surroundings centered on caster. |
| Mage Meteor, Fire Rain, Winter Field | Fixed area point, shared preview and anchor rules. |
| Mage Ice Armor | Self; its reactive slow affects the eligible attacker automatically. |
| Mage Blink | Self with look-directed movement and existing safe-destination checks; no mouse-selected ground destination. |
| Warrior Strike, Retort, Mighty Blow, Hamstring, Charge, Taunt | Crosshair enemy; retaliation readiness does not automatically choose a victim. |
| Warrior Broadstroke | Crosshair primary with automatic legal forward cleave secondaries. |
| Warrior Bellow | Automatic surroundings centered on caster, hostile mobs only. |
| Warrior Hold Ground, Unbroken, Ruination | Self. |
| Priest Smite, Rebuke, Word of Ruin, Final Word | Crosshair enemy; Word's recovery is automatically applied to self. |
| Priest Heal, Shield, Mend | Crosshair friendly, or self fallback at activation; retain the chosen recipient during any preparation. |
| Priest Hearten, Haven | Automatic surroundings: self plus eligible party members at release. |
| Priest Censure | Fixed area point. |
| Scout Loose, Bladecraft, Aimed Shot, Snare Shot, Opening | Crosshair enemy; bow/blade gestures and rear checks follow the Scout specification. |
| Scout Split Shot | Crosshair primary, automatic nearest eligible secondaries. |
| Scout Arrowfall | Crosshair enemy at first release, then that same target subject to broad facing/range/visibility checks. |
| Scout Flourish | Automatic surroundings in the facing cone. |
| Scout Sidestep, Parry, Close Dance | Self; no aimed attacker needed. |

All passive damage, range, cost, proc, recovery, duration, armor and resource
talents inherit these modes. Follow the Line remembers the qualifying enemy
for its bonus, but does not select or hit it automatically. Cold Shock and
Retort ready a bonus; the player still aims the consuming attack. Neither
class needs a cursor-controlled target list.

## 5. Cast lifecycle and resource transactions

The targeting contract and class timing tables are complementary. A skill
must have an explicit activation, preparation if any, release/commit,
recovery and cancellation lifecycle. Integrate these into the existing
held-input state machine rather than adding independently ticking locks.

For a normal prepared skill, costs and cooldown commit on a valid release;
failed preparation does not pay them. Time already occupied by preparation
is not erased. Cooldown begins at release, and preparation cannot begin
before a previous cooldown ends. A visual warning or projectile flight is
not automatically another occupied attack interval.

Keep three target states separate:

- **Live aim feedback:** current crosshair result, advisory and changing.
- **Cast state:** a retained Heal recipient or fixed area anchor, owned by
  one in-progress cast and discarded with it.
- **Released effect:** projectile, warning, area pulses or applied support;
  it follows its effect lifecycle after the caster looks elsewhere.

Heal's retained recipient is a new cast-specific state; it must not read the
existing presentation-only target memory as authority. A held support press
also has input bookkeeping, which must not become a second recipient owner.
Death, leaving, respec and relevant equipment/layout changes clear pending
casts according to their class rules. Released effects are not all deleted
merely because the player selects another hotbar item.

### Arrowfall settlement proposal for the implementation brief

The user approved per-release payment and forgiving follow-up targeting.
The following is the proposed concrete settlement algorithm; its final
rounding and facing parameters must be frozen in planning:

1. Accept preparation only when at least the first shot's resources are
   available. No full-volley resource reservation is needed.
2. At the first release, validate exact aim, target, resources and permissions;
   calculate and retain the complete-volley integer mana cost C using the
   existing cost calculation, including relevant reductions exactly once.
3. For shot k of four, charge `ceil(k*C/4) - ceil((k-1)*C/4)` mana plus
   one arrow. Four shots total exactly C. Do not apply a minimum-one rule
   again to every installment; a low-level installment can be zero.
4. Validate and pay immediately before that shot is created. If the check
   fails, end the remaining volley without paying for it. Cooldown starts
   with shot one and is not restarted by later shots.
5. Already spent resources and fired projectiles are not refunded. Remaining
   resources stay in inventory/pool; no refund mechanism is needed.

For a test example with C=17, the four installments are 5/4/4/4. Stopping
after two uses two arrows and 9 mana. This is an arithmetic example, not a
new skill cost. Inventory changes between releases must be respected; a
stored ammunition count is not permission to create a free arrow.

A proposed facing starting point is a 90-degree full horizontal cone centered
on the caster's look yaw, with range and full 3D line of sight checked
separately. This numeric tolerance is a planning candidate, not an approved
user value. It should permit ordinary tracking mistakes without firing at
enemies behind the caster. Do not add another target, an offscreen reacquire
or a new homing rule after release.

Keep the candidate's reserved three-second attack interval after a committed
first shot, even if the remaining volley ends early; restore the movement
stance on termination. Otherwise repeatedly taking only the first powerful
arrow could evade its action cost. A cancelling defense retains its own
action-time addition. Cancellation before any release follows the ordinary
preparation rule and does not start cooldown. Freeze these timing details in
the input brief, together with behavior when a server step spans more than
one nominal release time; never emit a catch-up burst without review.

### Split Shot release proposal

At release, acquire the primary through current aim. Filter the bounded
secondary candidate set, order by distance from primary and a deterministic
tie-break, and finalize recipients before consuming ammunition. A proposed
short-ammo policy is to preserve the primary and then as many nearest
secondaries as available arrows permit. Zero arrows refuses the cast.
That policy and the entity tie-break need planning confirmation; the approved
rule already forbids charging arrows for nonexistent recipients. Mana remains
the single cast cost. No free shots from ammo-saving talents are assumed
unless their final wording explicitly applies to this paid skill.

## 6. Feedback and area geometry

Friendly support needs a visible selected-recipient cue; a pending Heal
keeps that name through the cast and shows a clear failure if release is
refused. Do not repeatedly post recipient changes to the message feed.

Area skills need one shared preview builder and one effect-footprint model.
While aiming, the preview follows live aim. At accepted activation, retain
the anchor; during preparation/telegraphing display that fixed location.
An enemy moving away is not a reason for the area to follow it. A new
obstruction before release can invalidate the cast; after commitment,
effect legality and cover are checked at the appropriate impacts/pulses.

The handoff's per-column nearest eligible surface/air proposal remains the
geometry starting point. Freeze its hit-to-footpoint conversion, eligible
terrain, vertical allowances and cover rules before implementing placement.
An actor in the air must not trigger an unbounded search for distant ground.
Preview and damage cannot select different floors. No location at range
limit is fabricated when the ray misses. A first-person preview must convey
meaningful extent and gaps even if only part of the area is visible.

Use bounded, caster-visible preview feedback where supported; committed
warnings remain visible to affected opponents. A provisional budget for the
brief is at most 24 live preview particles per caster with lifetime at most
0.3 s and refresh no faster than needed, initially 5 Hz. This is a proposal,
not a performance acceptance claim. Prefer fewer reusable markers if a
prototype achieves the same clarity. Count previews together with combat
effects; a many-player scene must stay within the project's total of hundreds
of particles. Do not scan full areas or all players every globalstep.

For Parry distinguish "guard active" from "empowered Opening ready". Their
timers and consumption are different. Readiness must remain visible while
switching from Parry to Opening; it clears on consumption, expiry, death or
loss of the talent. The cue reads the same gameplay state as the bonus. A
successful eligible dodge can produce readiness without HP damage. Do not
borrow the bow/food progress display by pretending Parry is one of its owners.

No icons, artwork or sound are commissioned here. The functional prototype
may use restrained existing primitives and text; sound still needs its normal
exact-file approval before shipping.

## 7. Existing module boundaries to preserve

Verified against the current source; this identifies seams, not permission
to bypass their contracts. Read the relevant [module guide](../../technical/module-guide.md)
and [upstream workarounds](../../technical/upstream-workarounds.md) before coding.

| Owner | Integration responsibility |
|---|---|
| `grug_core/combat_ray.lua` | Current server eye/look ray, range and visibility; use `grug_core.aim_raycast` for object rays. Current combat eye is based on first-person interaction, so this plan does not replace it with a camera-control project. |
| `grug_abilities/kits.lua` | Current hostile/friendly resolution and ability effects. `resolve_friendly_target` does current aim plus self fallback; the new prepared Heal must capture that result only once. |
| `grug_abilities/input.lua` | One held-input machine, click ownership and suppression across changes; integrate preparation, channel and occupied-action handling here or through one explicit owner it drives. |
| `grug_abilities/init.lua` | Cast dispatch, cost/cooldown and target-frame state. Current synchronous `try_cast` must not fully charge Arrowfall as well as its later release transactions. Target-frame memory remains presentation-only. |
| `grug_abilities/crosshair.lua` | Aim feedback and progress presentation; expand explicitly for area/recipient/readiness states, with bounded updates and cleanup. Its existing progress owner set is not an arbitrary-status API. |
| `grug_parties` | Current membership; filter online/living candidates for combat rather than reusing an unfiltered UI list. |
| `grug_pvp` and `grug_core` combat settlement | Existing harm/support permissions and actual damage/support settlement. Word of Ruin and Retort recovery need confirmed actual HP removal, never an estimated pre-mitigation return. |
| `grug_classes`, talent/skill catalogue and hotbar owners | Talent graph, grants/revokes, transformations and both layouts. Avoid duplicated entitlements and cooldowns when representations change. |

All logic remains server-side and plain Lua 5.1 compatible. Retain one damage
scaling path, one support factor application and one final spell rounding.
Every hypothetical balance calculation must convert class-local units before
comparing actual damage. No gameplay code is changed by this document.

## 8. Balancing consequences of the targeting decisions

The [balance review](balance.md) remains the arithmetic record. These control
changes increase practical reliability without increasing listed damage:

- Retained Heal recipients reduce unintended self-heals; this must not allow
  support through walls or beyond range.
- Automatic party selection reduces manual targeting effort, but does not
  increase the declared recipient cap or remove attack-time/mana costs.
- Fixed-point previews make area damage easier to place, but enemies can
  still leave a committed area.
- Arrowfall loses fewer releases to small aim errors and wastes fewer
  resources on cancellation. Its complete-volley stationary calculation is
  unchanged; partial volleys and repeated pulls need new comparisons.
- Split Shot's automatic choice improves reliability, not its target maximum.
- A clear Parry cue improves access to existing Opening damage without
  multiplying the rear and Parry bonuses.

Compare normal kills, damage received, mistakes and recovery, not only a
stationary damage total. Bulwark's slower kills must still feel safer.
Priest offensive hybrids, including the checked 27/3 build, remain below
Fire as a damage role; Rime's lower output buys control. Test low levels,
matched gear, ranged foes, restricted terrain and several targets. No paper
estimate constitutes desktop/web or PvP acceptance.

## 9. Planning sequence and unresolved choices

The coordinator should prepare the delivery rounds in this order (refined by
the [continuation plan](continuation.md#6-implementation-outline-for-the-later-delivery-rounds)), without assigning
a round number or replacing existing carry-overs here:

1. Freeze the [remaining decisions](../../../TODO-design-classes.md): final
   class tables, geometry, Arrowfall tolerance/payment/timing details,
   Split Shot ammo shortage/ties, shared control and input choices.
2. Define the shared target/cast/settlement interfaces before parallel class
   implementations. Prototype the area preview and Heal recipient feedback
   with standard clients; do not split four conflicting input implementations.
3. Separate common input/targeting work from class effect and talent-data work,
   with ownership of shared files agreed in the lane briefs.
4. Plan both-layout entitlement cleanup and the talent/skill migration before
   replacing stored IDs. Do not silently discard existing character progress.
5. Integrate feedback, localized skill descriptions and the talent display;
   then compare practical solo builds and perform independent review.

This document-only work needs no world migration. The eventual round must
classify its own changes and follow the upgrade contract; this package does
not choose refunds, migration version, reset or new-server behavior. No push,
runtime sync or release is authorized by the design handoff.

## 10. Acceptance cases for later implementation

Portable fixtures should exercise the real shared state transitions and
settlement paths, not a second simplified implementation of the rules.

| Case | Expected result |
|---|---|
| Heal starts on ally, then caster looks elsewhere | Original ally receives it if release checks pass. |
| Heal starts on self, ally crosses aim during preparation | Still self; no retarget. |
| Captured ally dies, leaves, becomes forbidden or moves behind cover | No release, payment, cooldown or proc; no self fallback. |
| Full-health caster with more eligible party members than the cap | Caster keeps its place; injured eligible members are prioritized deterministically. |
| Party member is offline, behind a wall or not supportable | Excluded before selecting the limited group. |
| Area preview on an enemy, enemy moves during preparation | Captured area point stays fixed; revalidate the point, not the old enemy. |
| Ray miss, unloaded anchor, new obstruction before release | No invented point and no paid release. |
| Stairs, stacked floors and gaps | Preview and affected footprint agree; no damage leaks through floors/walls. |
| Arrowfall aim drifts off the target but it stays broadly in front and visible | Follow-up shots continue on that target. |
| Arrowfall turns away, loses LOS/permission/resources or is cancelled | Stop unfired shots; keep existing cooldown/recovery; no refund of released shots. |
| Arrowfall full and partial low-level costs, with discounts | Installments follow the frozen rounding contract; full sum equals one full cost. |
| Split Shot with one primary and zero/one/two valid secondaries | No duplicate target, correct arrows consumed, one mana cost. |
| Secondary is closer but forbidden or occluded | Skip it before ordering the eligible candidates. |
| Parry readies Opening, player switches to Opening | Cue remains and one qualifying attack consumes the single bonus. |
| Rear angle and Parry readiness both hold | One empowered value, not two stacked bonuses. |
| Hotbar switch, death, leave or respec during pending work | No stale cue, new unintended attack, duplicated grant or banked release. |

GUI checks on desktop and web must cover target-name clarity, area visibility
in first person, hotbar access to reactive defense, fast turning during Heal,
Arrowfall tracking and interruption, several nearby players, and total effect
load. The user's runtime acceptance remains separate. Before the round's final
report, run only the appropriate development checks and then the required
round-end gates from the [workflow](../../process/round-workflow.md#3-gates).
