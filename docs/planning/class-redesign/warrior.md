# Warrior redesign candidate

Prepared 2026-10-12. Discussion proposal, not approved design or implementation.
Documentation only: **compatible**. Eventual talent/skill replacement likely
needs the declared migration and free point refund discussed in the handoff.
No map or engine change is proposed here.

The [future targeting contract](../../design/ability_targeting.md) is approved
and applies to this candidate. See the [implementation design](implementation-design.md)
for the complete interaction map and remaining planning choices.

## 1. Identity and common rules

The Warrior stays in contact. **Bulwark** survives an imperfect pull, answers
pressure with measured counterstrikes, and levels somewhat more slowly.
**Ruin** converts earned rage into forceful swings and short attack windows;
it gives up the deep defensive layers and must choose when to spend.
The distinction should be felt well before either ultimate.

This follows the complete class-redesign handoff, current Warrior kit in
`docs/design/classes.md` §3, talent identities in `skill_trees.md` §2.1–2.2,
formulas in `combat_stats.md` §2 and the combat/module-guide seams. Current
numbers quoted below are baselines, not claims that this proposal is live.
The user's latest parallel-design request supersedes the older sequential
continuation instruction.

- Retain 30 points, one at every even level; gate N means N already spent in
  that tree. A direct prerequisite means rank 1 unless specified otherwise.
- Gate 0/2/6/10/12/16/20 first purchases occur at level
  2/6/14/22/26/34/42 when focusing on that tree.
- Bulwark has **33 ranks**, Ruin **33 ranks**. Each ultimate costs one point
  after gate 20; two require at least 42 points and cannot coexist.
- No node requires a shield. Weapon/equipment rules stay current; a shield
  remains useful equipment, not an unannounced mandatory new class mechanic.
- Skill ownership is unrestricted. Four to six equipped combat skills must
  suffice, counting the basic attack and equipped ultimate. No rotation below
  depends on switching layouts to execute the unequipped repertoire.

**Scaling notation:** S is this Warrior's ordinary full Strike before crit,
dodge, armor and rounding, but after the single current level scalar.
With weapon damage W and Strength A, `S=(W+A/10)*P/(8*B)`.
`P=round(20+5L+0.66L²)`; `B=round(4+0.35L)+(10+3(L−1))/10`.
S is a local comparison unit, **not Mage D**. Implementation assembles the
corresponding raw formula first and floors once through existing damage.
Armor increments use the Warrior's level-dependent K; reduction still uses
the attacker's K and the universal 70% cap. Dodge retains its 30% cap.
Warrior baseline HP stays 1.20P before pool bonuses.
Pool absorbs multiply the existing support factor once and receive no
second damage scalar. Recovery is explicitly no-crit and applies the existing
support factor F exactly once after its damage-derived amount is capped:
`heal=min(rank_fraction*actual_primary_HP_removed, 0.02P)*F`.
It does not apply the damage level scalar again. F is
`1 + gear_Int/10/B(L)`; comparisons below use F=1 unless stated otherwise.

## 2. Minimal starter kit and action timing

Start with **Strike and Charge**. Moving Mighty Blow out of creation gives
the first Ruin point a visible new capability. Taunt is earned in Bulwark.
Charge remains essential baseline engagement so pure Bulwark is not stranded
without a way to contact ordinary ranged enemies.

| Starter | Proposed action |
|---|---|
| Strike | Free 3 m melee attack, S damage at the equipped weapon's existing full swing interval T. It remains available at zero rage. |
| Charge | Existing safe 12 m dash and path rules; accepted arrival deals 0.12 of the level-scaled baseline hit, grants 15 rage; 10 s cooldown. Proposed stun is 0.75 s, down from 1.5 s, for a short contact window rather than a free burst sequence. Current stun-immune enemies remain immune. |

Charge's existing cannot-start/committed-miss distinction stays. No valid
initial path means no commitment; a committed dash that misses spends its
cooldown but gives no damage, rage or control. Successful Charge does not
also count as a rage-generating weapon swing.

All melee variants consume the same swing cadence; an empowered strike
replaces that swing, never adds an extra independent attack. Costs must be
affordable before the attack; the +8 rage earned by landing it cannot fund
that same attack. If a swing skill is unaffordable, it still makes an ordinary
Strike at the same cadence. A combat miss consumes cadence but gives no rage,
proc or recovery. No extra attack is queued while Charge is moving.

Proposed self casts have a **0.35 s action recovery** with no melee release
inside it; they preserve rather than reset the existing swing timer. Opening
a second layout cannot cancel that recovery, duplicate a swing or refresh a
cooldown. This intentionally gives Warrior protection a short reactive action
compared with a longer spell commitment. A 0.35 s recovery can fit between
1 s swings: it does **not necessarily sacrifice an entire attack**. Rage is
the primary opportunity cost; only an overlapping release is delayed.
This is a proposed action rule, not an assertion about current code.

## 3. Bulwark: protect, answer, keep going

The signature is an empowered basic attack after contact, not an additional
reaction button. Defensive spending competes with damage spending in hybrids.
Early survival comes from rating and Hold Ground; bounded recovery arrives
in the middle of leveling. Random dodge is supplementary, never its sole defense.

| Code | Talent | Gate | Ranks | Parent | Effect at each rank |
|---|---|---:|---:|---|---|
| B1 | Retort | 0 | 1 | — | A legal direct hostile combat hit or dodge against you, melee or projectile, readies the next Strike for +0.25S within 4 s; one charge, at most one preparation every 6 s. Replaces Strike with Retort, same slot and free fallback. |
| B2 | Ironbound | 0 | 4 | — | Armor rating +0.04/0.08/0.12/0.16K. |
| B3 | Weathered | 0 | 3 | — | Maximum HP +3/6/9% of the class baseline pool, through the existing pool formula. |
| B4 | Hold Ground | 2 | 1 | — | Unlock the short defensive absorb below. |
| B5 | Measured Answer | 6 | 3 | B1 | Empowered Retort bonus becomes +0.30/0.35/0.40S; base Strike is unchanged. |
| B6 | Turn the Edge | 6 | 3 | — | Dodge +2/4/6 percentage points, normal cap. |
| B7 | Taunt | 6 | 1 | — | Unlock current single-target mob Taunt, 8 m, free, 8 s cooldown, 3 s attention; no effect on player input. |
| B8 | Recover | 10 | 3 | B1 | Empowered Retort heals 10/20/30% of its actual primary-target HP removed, capped at 2% P before applying the support factor once per proc. No healing from overkill, absorb removal, misses or secondary targets. |
| B9 | Bellow | 12 | 1 | B7 | Replace Taunt with 6 m hostile-mob area Taunt, same cooldown and 3 s attention. |
| B10 | Layered Guard | 12 | 3 | B4 | Hold Ground absorb increases by 0.03/0.06/0.09P before the support factor. |
| B11 | Halt | 12 | 3 | — | Accepted Charge arrival adds a 20/25/30% slow for 2 s after its stun ends; no root. |
| B12 | Unbroken | 20 | 1 | B4 | Unlock the defensive ultimate below. Replaces the old passive capstone specification. |
| B13 | Enduring Stand | 20 | 3 | B12 | Unbroken duration +0.5/1.0/1.5 s; absorb amount unchanged. |
| B14 | Gather Yourself | 16 | 3 | B4 | Hold Ground cooldown −1/2/3 s. |

| Additional active | Proposed timing, cost and effect |
|---|---|
| Hold Ground | Instant self cast plus 0.35 s recovery; 25 rage; 24 s cooldown; absorb 0.12P for 5 s. No root break, slow immunity, heal, or damage. Recasting the same effect never stacks its remainder. |
| Taunt / Bellow | Instant cast plus 0.35 s recovery; free; current attention/threat rules. PvE utility that can replace an ultimate in the equipped group kit. |
| Unbroken | Instant self cast plus 0.35 s recovery; 25 rage; 60 s cooldown; +0.50K armor rating for 8 s and a 0.15P absorb expiring with it. No immunity or cooldown resets. Its named absorb does not stack with a second cast of itself. |

Hold Ground and Unbroken may overlap; that uses 50 rage and two recoveries,
leaving fewer resources for a Ruin damage spender. Separate-source absorbs
follow the existing support rules. Unbroken does not retain the old permanent
×1.65 armor multiplier or low-HP proc in addition to this active design.

Retort's preparation can come from a fully absorbed legal direct hit.
**Correction proposal:** melee and direct projectile contact both prepare it;
damage-over-time ticks, environmental damage and passive ground effects do
not. This keeps enemy archers from disabling the entire sustain identity.
The later Retort remains a melee attack: being shot does not create ranged
retaliation or heal before the Warrior closes. Recovery still needs actual
hostile HP damage from that later swing. Taking
many hits cannot grant more than one preparation per six seconds. It has no
stored second charge and no stacking damage; a wasted/expired charge is lost.
Retort bonus and healing belong only to its basic-attack button: Mighty Blow,
Hamstring and Broadstroke neither consume nor cash out the Retort charge.
This makes a hybrid choose its next attack rather than multiply all bonuses.

Recovery is deliberately modest: at most 2% P × F every six seconds, only while
landing prepared attacks. It does not heal from passive retaliation, apply
against multiple cleave targets, generate rage or trigger another Retort.
There is no passive out-of-combat heal loop. Very weak enemies can still be
out-sustained; the aim is that equal-level meaningful pressure cannot fund
its own permanent survival. Actual target damage and interrupted contact
matter more than the theoretical cap.

## 4. Ruin: build pressure and commit it

Mighty Blow is an immediate new button; later Broadstroke transforms it.
The skill still works while held with ordinary free swings between spenders.
Hamstring supplies deliberate contact control. Its attack shares cadence with
the spender, so it is not a free second damage source.

| Code | Talent | Gate | Ranks | Parent | Effect at each rank |
|---|---|---:|---:|---|---|
| U1 | Mighty Blow | 0 | 1 | — | Unlock the rage-spending swing below. |
| U2 | Heavy Hand | 0 | 4 | U1 | Mighty Blow primary damage +0.05/0.10/0.15/0.20S above its 1.45S base. |
| U3 | Stoke | 0 | 3 | — | Accepted full weapon swing rage +1/2/3, including free fallback swings; no bonus on secondary hits. |
| U4 | Hamstring | 2 | 1 | — | Unlock the control swing below. |
| U5 | Keen Edge | 6 | 3 | — | Crit +2/4/6 percentage points, normal cap. |
| U6 | Onset | 6 | 3 | — | Charge cooldown −0.5/1.0/1.5 s. |
| U7 | Broadstroke | 6 | 1 | U1 | Replace Mighty Blow with Broadstroke: same primary hit; up to two other valid enemies in a forward 100-degree, 3 m arc take 0.35S each. Same cost. |
| U8 | Follow Through | 10 | 3 | U7 | Broadstroke secondary hits become 0.40/0.45/0.50S; primary unchanged. |
| U9 | Clean Cut | 10 | 3 | U4 | Hamstring slow lasts +0.5/1.0/1.5 s, no root. |
| U10 | Finisher | 12 | 3 | U1 | Mighty Blow/Broadstroke primary damage +0.08/0.16/0.24S against a target below 30% HP before the swing. |
| U11 | Relentless | 16 | 3 | U1 | Mighty Blow/Broadstroke cost −1/2/3 rage. |
| U12 | Ruination | 20 | 1 | U1 | Unlock the offensive ultimate below; replaces the old crit-cap window. |
| U13 | Long Fury | 20 | 3 | U12 | Ruination lasts +0.5/1.0/1.5 s; no added rage grant. |
| U14 | Reach the Fight | 12 | 1 | — | Charge grants +5 rage on accepted arrival; no bonus on miss and no extra stun. |

| Additional active | Proposed timing, cost and effect |
|---|---|
| Mighty Blow / Broadstroke | 25 rage before landing; no independent cooldown; one full weapon swing T; 1.45S primary, modified by Heavy Hand/Finisher. At insufficient rage, ordinary S swing without cleave. |
| Hamstring | 10 rage; one normal S swing; 8 s proc cooldown; 35% slow for 3 s. When unready or unaffordable, ordinary Strike without slow. No six-second hold/charge requirement. |
| Ruination | Self cast plus 0.35 s recovery; 20 rage; 60 s cooldown; 8 s window: weapon-swing damage +15% of its corresponding untalented damage, additively with other damage bonuses; +2 rage per landed primary swing. No attack-speed boost, free attack, crit-cap exception or control immunity. |

Secondary cleave hits cannot crit, grant rage, trigger trinket on-hit events
or duplicate primary-only procs. They need their own legal target and cover
checks and do not pass through walls. They do not duplicate the primary
victim. The forward arc gives opponents room to separate and the player a
reason to aim. Geometry is a proposal to verify in implementation planning.

For Ruination, "untalented damage" means S for Strike/Hamstring, 1.45S for
Mighty Blow's primary, and 0.35S for each Broadstroke secondary. Heavy Hand,
Finisher and Follow Through add their listed S increments; Ruination adds
0.15 times that untalented term rather than multiplying the already-talented
result. The attack speed and single settlement path remain unchanged.

## 5. Worked spending and loadouts

Each row is a valid ordered purchase sequence; repeated entries add ranks.
Within a mixed row the first listed tree is purchased first, then the other.
This is a feasibility example, not a recommended mandatory leveling order.

| Build | Purchase sequence | Repertoire at 60 |
|---|---|---|
| Pure Bulwark 30/0 | B1×1, B2×2, B4×1, B2×2, B5×3, B3×3, B8×3, B6×3, B10×2, B12×1, B10×1, B14×3, B7×1, B9×1, B13×3 | Retort, Charge, Hold Ground, Bellow, Unbroken: 5. |
| Pure Ruin 0/30 | U1×1, U2×4, U3×1, U7×1, U5×3, U8×3, U10×3, U11×3, U4×1, U12×1, U3×2, U6×3, U9×3, U14×1 | Strike, Charge, Broadstroke, Hamstring, Ruination: 5. |
| Protected attacker 21/9 | Bulwark: B1×1, B2×2, B4×1, B2×2, B5×3, B3×3, B8×3, B6×3, B10×2, B12×1. Ruin: U1×1, U2×4, U3×1, U7×1, U4×1, U3×1. | Retort, Charge, Hold Ground, Unbroken, Broadstroke, Hamstring: 6. |
| Offensive survivor 9/21 | Ruin: U1×1, U2×4, U3×1, U7×1, U5×3, U8×3, U10×3, U11×3, U4×1, U12×1. Bulwark: B1×1, B2×2, B4×1, B2×2, B5×3. | Retort, Charge, Hold Ground, Broadstroke, Hamstring, Ruination: 6. |
| Mobile mixed 15/15 | Bulwark: B1×1, B2×2, B4×1, B2×2, B5×3, B3×1, B8×3, B6×2. Ruin: U1×1, U2×4, U3×1, U7×1, U4×1, U5×3, U6×3, U14×1. | Retort, Charge, Hold Ground, Broadstroke, Hamstring: 5, no ultimate. |

| Situation | Equipped useful subset | Deliberately omitted |
|---|---|---|
| Pure Bulwark ordinary solo | Retort, Charge, Hold Ground, Unbroken: 4 | Bellow is group utility, no solo rotation tax. |
| Bulwark group | Retort, Charge, Hold Ground, Bellow, Unbroken: 5 | Nothing else required. |
| Protected attacker | Retort, Charge, Broadstroke, Hold Ground, Unbroken: 5 | Hamstring, optional sixth for mobile opponents. |
| Ruin solo | Strike, Charge, Broadstroke, Hamstring, Ruination: 5 | Nothing else unlocked in pure build. |
| Offensive survivor | Retort, Charge, Broadstroke, Hold Ground, Ruination: 5 | Hamstring can be sixth. |
| Mobile mixed | Retort, Charge, Broadstroke, Hold Ground, Hamstring: 5 | No ultimate bought. |

## 6. Resource and solo-balance review

Keep the current base rage ledger: +8 per landed full swing, +3 per actual
hit taken, +15 per accepted Charge, −5/s outside combat, cap 100. Race and
trinket bonuses are extra existing sources and need comparison as well.
Avoidance grants no hit-taken rage; Retort readiness from a dodge is not rage.
There is no Spite multiplier that makes extra attackers an unlimited battery.

At T=1 s, eight landed swings and four incoming landed hits in eight seconds
produce 76 rage before Charge. Three untalented Mighty Blows cost 75;
resource affordability and starting rage still constrain their timing.
At zero rage an accepted Charge gives 15: one ordinary hit reaches 23; a
second reaches 31; only the third swing can pay the first 25-rage spender.
With Stoke 3, eight swings earn 88 before hits; with max Relentless each
spender costs 22, and swing income alone funds one spender per two swings.
Ruination adds only 2 per hit for its limited window and itself costs 20.
A full bar is finite; misses, armor, dodge and lost contact do not grant more.

Pure Bulwark uses those resources for 25-rage protection windows. Retort is
free and its recovery is not rage-dependent: survival does not collapse at
zero resource. The protected attacker must choose those windows over roughly
one additional Mighty Blow per 25 rage; it cannot recover through Broadstroke.
Do not nerf dodge because it reduces incoming rage: compare the whole survivor.

For own-level baseline 1H equipment, the existing fit gives ordinary
S approximately P/8. At T=1 and no incoming rage, a base spender frequency
of 8/25 adds roughly 14.4% sustained damage over Strike; with max Stoke and
Relentless, max Heavy Hand adds roughly 32.5%, before crit/execute windows.
These are continuous-budget approximations, not measured rotations. A fully
improved Retort adds at most 0.40S/6 s, roughly 6.7% at T=1; its recovery cap
is 0.02P × F/6 s, about 0.33% P/s at F=1. This leaves pure Bulwark visibly slower while
retaining a real response to pressure. Faster weapons and actual misses
change both estimates; do not assume every weapon has T=1.

Compare total solo burden: time to kill, HP remaining, food/recovery time,
failed pulls and button comfort. Modestly slower kills are acceptable for
Bulwark if sustained exposure is noticeably safer. Avoid compensating by
making Bulwark damage equal to Ruin; then the defensive build dominates.
Strong recovery with plate and dodge remains its chief risk. Mage Fire's
ranged uptime, free D and mana expenditure must be converted through its own
formula; comparing S and D coefficients directly proves nothing.

### Illustrative exposure comparison, not a balance gate

Use the same level-60 1H weapon, armor rating and no Intelligence gear for
both pure trees; **assume** shared gear rating is 0.75K (37.5 at L60), no
gear dodge, and hypothetical kills take Ruin 8 s and Bulwark 10 s. These
kill durations and gear rating are chosen examples, not measured outcomes
or prescribed target bands. The old 27-second pressure fit must include the
current default non-player damage setting **1.5** (`combat_stats.md`,
"Global non-player damage scale"). Normal melee pressure at one hit/s is
approximately `1.5P/27 = 0.05556P/s` before dodge/armor. Current integer
settlement slightly changes these continuous estimates, especially early on.

At L60, Warrior Dexterity is 69, hence base dodge 6.9%. Bulwark's B6 adds
6 percentage points, B2 adds 0.16K, and Weathered 3 gives HP 1.20P×1.09.
Use the real armor formula `reduction=A/(A+K)`, below the universal cap.
No extra physical resistance, hidden old Unbroken multiplier or crit
assumption is included.

| Quantity | Pure Ruin | Pure Bulwark |
|---|---:|---:|
| HP capacity | 1.20P | 1.308P |
| Armor rating / same-level reduction | 0.75K / 42.86% | 0.91K / 47.64% |
| Dodge | 6.9% | 12.9% |
| Expected damage rate after dodge/armor | 0.02956P/s | 0.02533P/s |
| Assumed exposure | 8 s | 10 s |
| Damage over exposure, without timed protection/healing | 0.2364P | 0.2533P |
| Share of own HP lost | 19.70% | 19.37% |

Longer exposure nearly consumes Bulwark's passive advantage in this example.
This is why its recovery and **usable short protection window** matter.
Suppose Bulwark uses fully improved Hold Ground once, with enough rage,
and all five seconds overlap incoming contact. Its 0.21P capacity encounters
only about `5*0.02533P=0.1267P` expected post-mitigation pressure; around
0.0833P of capacity expires unused. It prevents about 0.1267P here, **not**
the full 0.21P. Expected remaining damage is then about 0.1267P.
Two prepared Retorts can recover up to 0.04P at F=1, but actual HP damage,
misses, healing already at full health and precise timing may reduce that.
This illustrative Bulwark therefore loses around **6.6–9.7% of its own HP**,
versus Ruin's 19.7%, despite spending 25% longer in contact. This is a
meaningful safety advantage, not equal kill speed.

Unbroken is intentionally **unused** in that ordinary-pull comparison.
During its eight seconds, the same Bulwark's armor becomes 1.41K, or 58.51%
reduction, and expected damage rate falls to about 0.02008P/s. Its 0.15P
absorb could prevent most of those eight seconds' roughly 0.1606P pressure;
its 60 s cooldown and 25-rage cost mean that cannot describe every pull.
Overlapping Hold Ground mainly leaves more absorb unused against one enemy.
Against several attackers, consume each shield from the actual damage
stream before counting recovery; neither dodge nor armor percentages add
linearly and readiness/healing do not multiply with the number of enemies.

Do not subtract `shield capacity / cooldown` as guaranteed permanent
healing. A shield may expire, be unavailable or be mistimed; disconnected
contact may also waste Retort. Conversely, this example is not proof against
immortality at all gear levels: plate, support-factor gear and weak enemies
can make sustained pressure very small. Test a prolonged equal-level fight
with real windows, single and multiple sources, and no kill/food resets.
The proposed bounds stop the self-amplifying leech/extra-target loop; actual
survivability still needs combat evidence. Against ranged opponents Retort
can become ready, but the Warrior must reach melee within its 4 s window
to receive damage or recovery value.

## 7. Milestones, counterplay and remaining evidence

| Milestone | Bulwark | Ruin |
|---|---|---|
| Creation | Learn contact and free cadence with Charge/Strike. | Same two skills; no large initial toolbar. |
| Level 2 | Retort visibly changes the basic attack after contact. | Mighty Blow unlocks a genuine rage spender. |
| Level 6 earliest | Hold Ground can rescue a poor pull. | Hamstring can hold contact; it is a choice beside damage ranks. |
| Level 14 earliest | Choose counterstrike output, dodge or group Taunt. | Broadstroke changes one-target spending into aimed small-group damage. |
| Level 22 onward | Recover adds bounded sustain; rating and timed absorbs now work together. | Critical hits, cleave strength and short finishing windows differentiate damage builds. |
| Level 42 earliest | Unbroken answers dangerous incoming pressure; no immunity. | Ruination creates a deliberate burst commitment; no hidden extra button. |
| Level 60 | Deep endurance versus hybrid spender/utility choices. | Deep offense versus earlier Bulwark tools; recovery is beyond a 9-point splash. |

PvP response is contact denial and making the Warrior spend defensively.
Charge has a short stun, a visible dash and current destination constraints.
Ruin cannot root its target; Hamstring's slow is bounded and uses an attack
that could have been the stronger spender. Bulwark lacks Ruin's sustained
slow but can buy it by sacrificing deep ranks. Unbroken has no root break:
opponents can control or disengage during its visible defensive window.
Taunt/Bellow never seize player control. Two Warriors must not bypass the
shared repeated-control policy; strongest-only hostile slows and a common
short hard-control response remain cross-class proposals awaiting settlement.

Before adoption compare starter, first unlock, midgame, ultimate and level 60
at matched level/gear against melee, ranged pressure and a small multi-enemy
pull, with ordinary and defensive/offensive loadouts. Include two-handed
weapons, shield gear, crit/dodge caps, support gear and relevant rage trinkets.
Record damage actually removed for recovery, never pre-mitigation estimates.
No new engine behavior is asserted and no runtime validation is claimed.
Visual cues need a bounded later brief; no artwork or sound file is requested.
A simple weapon flash and short status indication should carry these effects
without continuous particle emitters or world alteration.
