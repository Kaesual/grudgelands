# Ability targeting for the class redesign

**Approved future behavior, 2026-10-12; not implemented.** The user accepted
the first-person targeting changes after reviewing the four class candidates.
This file owns those interaction rules. It does not approve the candidates'
damage values, talent graphs, release scope or migration policy. Current
shipped targeting remains documented in [classes](classes.md) and
[combat stats](combat_stats.md).

**Reservation, 2026-10-12:** the user questioned fixed-duration prepared
casts, which fit the crosshair model poorly. A hostile target is the one at
the moment of starting. The preparatory planning round re-examines every
prepared skill: instant, hold-to-charge with release trigger (the Scout bow
model, slowed movement while held) or replacement
([continuation plan, M8](../planning/class-redesign/continuation.md#3-user-decisions-on-the-review-findings-2026-10-12)).

The [implementation design](../planning/class-redesign/implementation-design.md)
maps these rules to every proposed active skill and to the existing modules.
Unresolved tuning and implementation choices belong in
[the class redesign TODO](../../TODO-design-classes.md).

## 1. First-person interaction

Combat is designed for first person, mouse-controlled looking and a central
crosshair. No ability requires a free mouse cursor, clicking a party frame,
manually marking multiple targets or opening a combat selection dialog.
Keeping this design basis does not force-lock the client's camera or remove
an existing optional third-person view. A third-person camera conversion is
not part of the redesign.

Every active ability declares one of four player-facing target modes:

| Mode | What the player does |
|---|---|
| Crosshair target | Aim at one actor and activate. The skill identifies whether it accepts an enemy or a friendly player. |
| Fixed area point | Aim at an enemy or terrain; a preview shows the proposed area. Activate to fix its position. |
| Self | Activate for an effect on yourself; no aimed actor is required. |
| Automatic surroundings | Activate for eligible recipients in a defined radius or forward area. Facing matters for a cone; individual recipients are not clicked. |

An ability may attach automatic secondary effects to one crosshair target.
That does not create another manual selection step. Passive talents inherit
the targeting of the action they modify unless explicitly stated otherwise.

Server validation remains authoritative. Visible selection feedback never
grants permission to damage or support an actor. Existing PvP, faction,
range, visibility and impact checks continue to apply. A remembered target
frame is not a general combat target lock.

## 2. Friendly single-target casts

Heal, Shield and Mend use the same selection rule:

1. On an accepted activation, resolve the friendly player under the current
   crosshair using the existing friendly targeting/permission rules.
2. If there is no eligible friendly target, select the caster. An explicitly
   aimed ally whom PvP rules forbid supporting remains a refusal, as in the
   current game; it must not silently become a self-cast.
3. Show the selected recipient. For a prepared Heal, retain that recipient
   for this cast only. Looking elsewhere does not change or cancel it.
4. At release, check that the same recipient is alive, present, in range,
   supportable and visible from the caster. Self does not need an external
   line-of-sight ray. A failed check cancels the release without mana cost
   or cooldown. It never transfers the heal to the caster or another ally.
5. A valid release commits the normal cost and cooldown once. Shield and
   Mend are instant, so their selection and release form one transaction.

This is limited recipient retention during preparation, not persistent
party targeting. A self-cast stays a self-cast even if an ally crosses the
crosshair. The preparation's movement/cancellation and occupied-action rules
still apply: permission to look around does not permit walking during a
stationary Heal. A cancellation cannot reset time already occupied by a
cast. Refused and cancelled casts produce no support-triggered talent proc.

Mend's later ticks belong to the successfully applied effect and do not
reselect a recipient from the crosshair. Its ordinary effect validity and
PvP rules still apply. No new self-cast key or mouse gesture is introduced.

Example: start healing an ally, then look toward an approaching enemy.
The heal still goes to that ally if release checks pass. If the ally moves
behind a wall, the cast fails; it does not unexpectedly heal you instead.

## 3. Automatic party support

Hearten and Haven are caster-centered automatic group effects. The caster
is one recipient; up to the skill's declared number of additional party
members are chosen automatically. Aiming at an ally does not move the center
or choose a preferred recipient.

Selection occurs once at release using the caster's current position and
current party membership. Candidates must be living, online, within the
skill's radius, supportable under current PvP rules and visible from the
caster. Do not include neutral NPCs, unrelated nearby players, or duplicates.

Hearten prioritizes injured party members by lowest current HP fraction,
then shortest distance, then stable player id. Healthy members may fill
remaining places; they do not displace injured eligible members. Haven uses
the same deterministic order but can meaningfully protect healthy members
through its absorb component. The caster retains its own place even at
full health. The effect is valid solo, with the normal full skill cost;
the recipient limit is a maximum, not a minimum party size.

Apply the group selection as one release, not a chain of manual heals or a
fresh selection for every effect component. Haven's healing and absorption
use the same recipients. Ordinary overheal is lost and protection expires
under the skill's rules. Tooltips say "automatically affects you and up to
... nearby party members", never instruct the player to select several people.

## 4. Fixed area points and previews

> **Superseded in part (user, 2026-10-19):** there is no preview while
> aiming and no prepared cast; the anchor is always ground found below the
> enemy or terrain point, and a cast without ground is refused. See the
> [class-redesign skill inventory §3a](../planning/class-redesign/skill-inventory.md#3a-area-anchor-always-ground-user-2026-10-19).
> This section is updated when the rework is implemented.

Meteor, Fire Rain, Winter Field and Censure share one interaction contract:

- A legal enemy under the crosshair provides its position/footpoint as the
  proposed area anchor.
- Otherwise an eligible terrain hit provides the proposed anchor at the
  hit location. An actor hit does not authorize a ray through a wall or an
  otherwise blocking object to search for a more convenient target.
- A miss, unloaded location or invalid area anchor refuses activation.
  Do not manufacture a point at maximum range or spend resources on failure.
- While the skill is selected and the player is able to aim in the world,
  show a restrained preview of the candidate center and extent. Invalid
  placement must be distinguishable without relying only on color.
- Accepted activation fixes the point for that cast. For a prepared cast,
  the point is captured when preparation starts; looking away or movement
  of the previously aimed enemy cannot drag it. At release, revalidate the
  fixed point's range, visibility and placement validity before commitment.
- After release, the warning and subsequent effect stay at that same point.
  Recipients are resolved under the spell's impact/pulse rules; they are
  not the set of actors that happened to be there during preview.

Center selection does not itself establish the damage footprint. A preview
must use the same approved geometry and cover rules as the actual effect.
It must not promise damage across floors or through walls. This contract
introduces no node placement, removal or destruction.

A targeting preview is player guidance before commitment. An opponent's
warning is the committed spell's telegraph. They have separate lifecycles:
preview changes while aiming, but the telegraph does not follow later aim.
No mouse-unlock or second confirmation click is required.

## 5. Arrowfall

Arrowfall acquires one legal hostile through the crosshair at its first
release. Later arrows keep that same target without demanding a fresh exact
crosshair intersection. At each release it must still be alive, support a
legal hostile hit, remain in range and line of sight, and remain broadly in
front of the caster. Turning away ends the remaining volley. There is no
retargeting to a different enemy and no reacquisition after cancellation.

The broad facing check is deliberately more forgiving than exact aim; it
does not grant attacks behind the caster or through cover. The first arrow
still requires deliberate aiming. Previously released arrows retain their
ordinary projectile lifecycle and impact permission checks.

Consume one arrow and the corresponding share of the total mana cost at
each successful release. The cooldown starts once, with the first arrow.
If the next arrow cannot be released because the target is invalid or its
resource share is unavailable, end the sequence. A deliberate other action
also ends remaining releases. Unfired arrows and unspent mana stay with the
player; already released shots are not refunded. A complete volley retains
the full skill's listed damage, timing and total cost.

Partial payment is not partial cooldown. Cancellation must not reset the
committed action recovery or enable free basic attacks between the volley's
releases. This replaces the former all-upfront payment and repeated exact
aim requirement in the Scout candidate.

## 6. Split Shot

The player aims at one primary hostile. On release, automatically choose
up to two other legal hostiles nearest that primary, within the skill's
secondary radius. Check every secondary's range from the caster, visibility
from the caster and PvP eligibility independently. Exclude the primary
and duplicate actors; break equal-distance ties deterministically.

No secondary needs to lie under the crosshair. Do not seek additional actors
through cover. Consume one arrow per actual recipient, so a lone primary
uses one arrow. The skill's mana cost remains its declared cast cost, not
a cost multiplied by recipient count. Finalize recipients and ammunition
as one release transaction; a later projectile miss does not refund an arrow.

## 7. Parry and Opening

Parry is self-targeted; activating it does not require aiming at the
attacker. Its next eligible incoming hit creates the temporary empowered
Opening opportunity under the Scout's existing proposed effect rules.
Show that opportunity clearly, including its expiry, without opening a
window or capturing the mouse. Clear the cue on consumption or expiry.

Opening remains an aimed melee attack. Successful Parry is the reliable
solo route to its stronger hit; attacking from behind is an additional
opportunity, never required for the ordinary solo rotation. The positional
and Parry conditions do not stack into two bonuses. This does not introduce
teleporting behind an enemy, automatic facing or an extra required skill.

## 8. Presentation and delivery boundary

Recipient cues, area previews and the Opening-ready cue are functional
feedback. They must remain legible during first-person movement without a
menu, free cursor, extra target-marking step or mandatory artwork. Personal
failure explanations use the existing message feed; transient readiness
belongs in combat HUD feedback rather than repeated feed messages.

All preview/effect work remains server-authorized, bounded and compatible
with unmodified desktop and web clients. Area previews must clear when the
skill is deselected, preparation ends, the player dies/leaves or a layout
change cancels the action. Actual implementation, visual assets and gameplay
acceptance are separate work; this file defines future behavior only.
