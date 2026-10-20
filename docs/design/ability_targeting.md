# Ability targeting of the new class kits

**Decided and implemented in Round 53 (0.53.0, round K of the class
rework).** The user approved the first-person targeting direction on
2026-10-12 after reviewing the four class candidates; the "maximally
simple" rulings of 2026-10-19
([continuation §4a](../planning/class-redesign/continuation.md#4a-user-rulings-of-2026-10-19-a-maximally-simple-rework),
[skill inventory §3a](../planning/class-redesign/skill-inventory.md#3a-area-anchor-always-ground-user-2026-10-19))
then removed prepared casts, previews, pulses and channels. This file owns
how the kits' skills pick their targets and places. The kits and numbers
are [classes](classes.md) §3–§5 and [scout.md](scout.md) §2; the input
machine (presses, holds, the held fallback) is [classes](classes.md) §2b;
the damage, projectile and PvP rules are [combat stats](combat_stats.md).
The 2026-10-12 version of this contract (retained heal recipients during
preparation, area previews, Arrowfall installments) is in the git history
of this file and in the
[implementation design](../planning/class-redesign/implementation-design.md)
§5, §6 and §10, which are superseded.

## 1. First-person interaction

Combat is designed for first person, mouse-controlled looking and a central
crosshair. No ability requires a free mouse cursor, clicking a party frame,
manually marking multiple targets or opening a combat selection dialog.
Keeping this design basis does not force-lock the client's camera or remove
an existing optional third-person view.

Every active ability uses one of four player-facing target modes:

| Mode | What the player does | Skills |
|---|---|---|
| Crosshair target | Aim at one actor and press. The skill takes an enemy, or a friendly player with a self fallback. | the swings, Charge, Taunt, the Mage's bolts, Smite, Rebuke, Word of Ruin, Final Word, the bow shots; Heal, Shield, Mend |
| Ground area | Aim at an enemy or at the ground and press; the area lands there once after a short fixed delay with a warning. | Meteor, Fire Rain, Winter Field, Censure |
| Self | Press for an effect on yourself. | Blink, Rime Mantle, Hold Ground, Unbroken, Ruination, Sidestep, Sprint, Parry, Close Dance |
| Around you | Press; the effect hits or helps the eligible actors in a circle or a cone around you, once. Facing matters for a cone. | Ice Nova, Bellow (circle); Ice Wave, Flourish (cone); Hearten, Haven (group) |

Every effect is instant and triggers exactly once: there are no cast times,
no channels, no pulses and no persistent ground areas. A heavy skill may
occupy the next action for a while after it (the action clock,
[classes](classes.md) §2b). An ability may attach automatic secondary
effects to one crosshair target (Fireball's splash, Split Shot's
splinters, Broadstroke's arc); that never creates another manual selection
step.

Server validation remains authoritative. Visible feedback never grants
permission to damage or support an actor. **Every area, cone, group and
splash filter is the abilities' `valid_target`** (`grug_abilities.target_filter`),
which carries the PvP flag's rules: an unflagged player, an ally the flag
forbids and a mob evading home are never area targets. A remembered target
frame is not a combat target lock.

## 2. Friendly single-target casts

Heal, Shield and Mend use one selection rule, on the press:

1. The friendly player under the current crosshair within the skill's range
   and in sight, if the friendly rules allow supporting them, is the
   recipient.
2. With no eligible friendly player under the crosshair the caster is the
   recipient. An explicitly aimed ally whom the PvP flag forbids supporting
   is a refusal at no cost, never a self-cast.
3. The cast commits at once: cost, cooldown and effect in one transaction.

Mend's later ticks belong to its status on the recipient and never
reselect from the crosshair; a recast renews it. A tap at the ground (the
self/support tap window of [classes](classes.md) §2b) goes to the ally under
the crosshair at the release, else to the caster.

## 3. Groups around the caster

Hearten and Haven are caster-centred group effects (`grug_core.area.group`):

- The caster is always one recipient and keeps its place at full health.
- The others are players within the radius (a sphere: Hearten 6 m, Haven
  8 m) that the friendly target check accepts and the caster can see
  (walkable nodes block, body to body). Aiming does not move the centre or
  choose a recipient, and party membership plays no role: any player the
  caster may support counts.
- At most the cap, the caster counted (Hearten 4, Haven 5), **lowest health
  share first**, ties by distance and then by name.
- Selection happens once at the cast. Hearten heals once; Haven places its
  heal-over-time status `haven` on each recipient, which keeps ticking when
  they leave the circle and stacks with Mend.

The effect is valid solo, at its full cost; the cap is a maximum, not a
minimum party size.

## 4. Ground areas: the ground anchor

Meteor, Fire Rain, Winter Field and Censure share one contract
(`grug_core.area.anchor`, the skill inventory §3a; the user, 2026-10-19):

- **The anchor:** a legal enemy under the crosshair within the skill's range
  gives its position at the cast; otherwise the first terrain point of the
  crosshair ray does (walkable, unknown or liquid nodes stop it, plants and
  other objects do not). The ground below that point is searched straight
  down, at most **3 m** (`area.H`): the top of the first walkable node
  with a non-walkable node above it, through liquids and plants. Deep
  water finds no ground.
- **No ground found:** a cast at the sky, past the range or over deep water
  is refused with "No ground found." **before** cost and cooldown.
- **No preview while aiming.** The cast fixes the anchor; a warning of a
  few particles at the impact point lives exactly the delay (Meteor and
  Fire Rain 1.5 s, Winter Field 1 s, Censure 0.75 s), and falling visuals
  start below the lowest ceiling over the anchor and four points at 0.6 ×
  the radius (at most 12 m up), so an area works in caves.
- **One impact** after the delay (`area.delayed`, at most 3 s, an engine
  timer, no per-step work): every target the filter accepts within the
  horizontal radius and **±3 m** of the anchor's height, **in sight of a
  point 0.5 m above the anchor** (walkable nodes block, grass and water do
  not), nearest first, at most the skill's cap (Censure 4). The damage is
  the cast's snapshot; the impact cue plays once at the anchor. The caster
  leaving cancels the impact; a caster who died still lands it.
- **Cover:** an area never reaches through floors or walls. On stairs a
  target behind a riser above the anchor can stay out of sight of it and
  is not hit (a GUI check).
- **Input:** the ground areas are offensive self casts, so a press at open
  ground casts; the crosshair shows no skill colour for them. Aimed at
  ground within hand reach, a tap casts and a hold digs (the self-skill tap
  rule of [classes](classes.md) §2b).

This contract places, removes or destroys no node.

## 5. Circles and cones around the caster

- **Circles:** Ice Nova (5 m) and Bellow (6 m) use the ground query around
  the caster's feet: the horizontal radius, ±3 m of height, in sight of the
  point 0.5 m above the feet, nearest first.
- **Cones** (`grug_core.area.cone`): the targets within the horizontal
  radius and ±3 m of the caster's feet and within the cone's whole opening
  around the caster's horizontal facing, in sight of the caster's body,
  nearest first, at most the cap; the caster is never a target. Ice Wave
  70° and 5 m (every target), Flourish 90° and 3 m (the 3 nearest),
  Broadstroke 100° and 3 m (at most 2 besides its primary target, which the
  swing itself hits).

## 6. Arrowfall

Arrowfall looses **four arrows at once** at the crosshair target, a legal
hostile within the bow's range (25 m plus Long View) at the cast. Each
arrow homes on that target and settles on its own; the volley trails once
and sounds its cast cue once, and every arrow that hits plays the impact
cue (at most four). The full cost (16 % base mana and four arrows) is paid
once, the arrows taken atomically with the spawn; with fewer than four
arrows the cast is refused ("Arrowfall needs 4 arrows.") and nothing is
paid. Its arrows may crit. There are no installments, no follow-up aim and
no partial volley.

## 7. Split Shot

The player aims at one hostile and looses one arrow (one arrow paid). On
impact up to **two other hostiles within 3 m of the struck target**, nearest
first, in sight of it and accepted by the shared target check, take Split
Shot's smaller hit (splinter particles from the target to each); they need
no arrows of their own and are never under the crosshair. Their hits never
crit. The splinters also fly when the primary hit is dodged.

## 8. Parry and Opening

Parry is a self cast; it needs no aimed attacker and detects no hit. At the
cast it raises a short shield and opens Opening's window `parry` (3 s,
Held Guard longer), shown as a status icon until it is spent or runs out.

Opening is an aimed melee swing with a charge. It hits harder **from
behind** (the Scout stands in the target's rear half-plane) **or in Parry's
window**, which it spends: one empowered value, never two stacked bonuses.
Turn the Blade adds only in the window. No teleport behind the enemy, no
automatic facing and no extra required skill.

## 9. Presentation

Readiness windows (Cold Shock, Retort, Clear Conscience, Follow the Line,
Parry, Ruination, Close Dance) show a status icon with their expiry and,
where a node opens them, a short proc flash; they clear on consumption,
expiry, death, leave and respec. Refusals ("No ground found.", "No hostile
target in your crosshair.", "Arrowfall needs 4 arrows.") use the red flash
line on a fresh press. Every effect is server-authorized, bounded and
compatible with unmodified desktop and web clients; particles stay in the
hundreds ([combat stats](combat_stats.md), "Skill particle effects").
