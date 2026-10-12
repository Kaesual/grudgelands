# Cross-class balance review

Review candidate, 2026-10-12. This is an arithmetic and design review of the
four proposed kits, not a combat simulation or a gameplay acceptance result.
All revisions remain proposals. The user's guide is roughly comparable solo
usefulness, with noticeably different strengths; there is no required damage
parity band. Documentation-only classification: **compatible**.

The user's [subsequent damage-role ruling](../class-redesign-handoff.md#31-class-development-and-the-mage)
is binding: even an offensive Priest stays slightly below Fire Mage damage;
healing is its separate advantage. Frost instead exchanges damage for slows
and roots. Compare matched levels, gear and meaningful damage windows, not
every isolated hit. This adds no fixed percentage gap.

## Targeting follow-up

The [approved first-person targeting rules](../../design/ability_targeting.md)
improve practical reliability without changing talent ranks or listed damage.
Arrowfall now retains its initial target with a forgiving facing check and
pays resources per released arrow. Full-volley arithmetic below is unchanged;
interrupted volleys, resource savings and real hit completion need fresh
comparison. Retained Heal recipients, automatic group support, fixed-point
previews and explicit Parry readiness likewise need practical checks. The
[implementation design](implementation-design.md#8-balancing-consequences-of-the-targeting-decisions)
records these consequences; earlier ideal-output estimates do not validate them.

## What the comparison means

Compare the time and difficulty of completing ordinary solo content, including
contact, kills, healing, mana, arrows and recovery. Highest damage on a passive
target is one component. Defense that makes mistakes recoverable is valuable;
defense that merely pays for a much longer encounter may offer little benefit.
All four classes must still have a useful normal attack when mana/rage runs out.
The Scout keeps a melee fallback when arrows run out, without an extra required
hotbar slot.

The reference formulas are [combat_stats](../../design/combat_stats.md#2-player-formulas)
and the current ability/equipment definitions. At level 60, no attribute
enchants, an item-level-60 one-handed sword/bow, and before crit/defenses:

| Comparison unit | Formula at level 60 | Approximate unrounded hit |
|---|---|---:|
| Neutral pool P | 20 + 5×60 + 0.66×60² | 2696 HP |
| Baseline B | 25 + 18.7 | 43.7 raw damage |
| Mage D | B × P/(8B) | 337 |
| Warrior S with that sword | B × P/(8B) | 337 |
| Priest ordinary spell before talents | (25 + 12.8) × P/(8B) | 291.5 |
| Scout R and sword M | (25 + 12.8) × P/(8B) | 291.5 |

Equality of two rows holds only under these stated inputs. Do not assume equal
class-local units with enchants, different gear, different weapons or at other
levels. The Priest and Scout use different talents, timing and secondary stats
even where these particular numerators match. Actual damage is floored once;
these unrounded values make the opportunity estimates readable.

## Findings and corrections

| Candidate | Review finding | Correction in the current candidate |
|---|---|---|
| Mage Ember | A 1.10D paid Fireball barely improves on the free attack occupying its time. | 1.60D primary, 6% P, 5 s cooldown, one occupied second. Flame Lance rises to 2.20D; paid attacks displace free attacks. |
| Mage Rime | An 18% repeatedly applied slow takes an ordinary 4.6 m/s pursuer below the player's 4 m/s. | Retain 12% slow; replace its talent's stronger slow with additive +0.03/0.06/0.09D basic damage. Strengthen Nova's hit and its next-Spark payoff. |
| Warrior Bulwark | More time in melee can consume the benefit of modest passive defenses. | Early usable Hold Ground, capped Retort recovery, +6 percentage points dodge and rating; explicit longer-exposure example. Retort also readies from direct arrows, but still needs a melee reply. |
| Warrior Ruin | Free extra swings or counting spender-generated rage before payment would inflate damage. | Every spender replaces a swing and must be affordable before its hit; secondary hits generate no extra rage. Defensive weaving is short and primarily pays rage. |
| Priest Mercy | Healing plus uninterrupted attacking would make support output misleadingly free. | Support occupies action time; its offensive follow-up repays only part of a sacrificed attack. Mercy has an in-tree solo attack investment. |
| Priest Reckoning | Cheap cross-tree additions and bonus crit could make the Priest's free hybrid attack stronger than a Fire specialist's, alongside broad healing. | Mercy adds at most 0.15B, Reckoning 0.12B. Hard Faith improves only paid direct attacks. Final Word becomes 2.8(W+I), with at most +0.30B from its talent. Word recovery remains capped by actual enemy HP removed. |
| Scout Quarry | Fast arrows must not repeat the old full-draw hit at three times the speed; a fixed slow ultimate may become worse than geared normal shots. | A 0.95R normal arrow in 0.85 s; revised Arrowfall reserves its whole channel and retains a premium at high attack speed/crit. |
| Scout Veil | A blade build needs a reason to accept melee exposure and cannot depend on getting behind a solo opponent. | A reliable frontal Opening, stronger setup through Parry, a blade damage investment and a short offensive/defensive ultimate; no invisibility requirement. |

Preparation starts only after a skill cooldown ends. A cooldown beginning
at release therefore needs its preparation added to the minimum repeat
period: 9.25 s for Lance, 6.75 s for Aimed Shot. The Scout’s reactive
defense also occupies 0.25 s of its next-attack timeline. These details
were corrected in the final independent arithmetic review.

The Mage's revised projectile counterplay corrects a factual handoff issue:
current targeted homing shots ignore cover reached after launch. Preparation
and release visibility supply counterplay. Area damage still requires its own
cover and vertical-footprint rules. This proposal does not silently replace
the shared projectile system.

## Representative offense and resource opportunity

Use a stationary, always legal, unarmored target and no crits. Estimates below
describe long averaged sequences, not discrete kill timers or full resource
sustain. No row gets free basic attacks during another occupied action.
The skill selection and purchased ranks are part of each estimate. These
are selected components, not rankings of complete builds; support use can
lower offense and crit talents can raise it.

| Example | Approximate output before crit and defenses | Main price |
|---|---|---|
| Ember, F1/F7 max, Fireball plus Sparks | 1.38D/s, about 465 damage/s | Fireball spends 1.2% P/s before cost discounts. Other cooldowns cost actions and mana too. |
| Rime, Keen Cold/Cold Shock/Returning Cold max, Nova plus Sparks | 1.111D/s, about 374 damage/s | Nova spends 10% P every 15 s before discounts; extra protection/ultimate costs attack time. |
| Ruin, Heavy Hand/Stoke/Relentless max, 1 s sword, no incoming rage | 1.325S/s, about 447 damage/s | Continuous landed melee contact; critical talents, finishers, incoming rage and ultimate omitted. |
| Bulwark, Measured Answer max, prepared Retort every 6 s | 1.067S/s, about 359 damage/s | Needs incoming direct contact and a timely melee reply; protection spends rage. |
| Quarry, full Bowcraft/Firm Aim/Follow the Line, Aimed Shot plus Loose | About 1.482R/s, or 432 damage/s | Long averaged opportunity estimate; one paid shot per 6.75 s, no arrow/mana refunds assumed. |
| Veil, full Fine Edge and Turn the Blade, sword basic plus Parry-assisted Opening every 12 s | About 1.4055M/s, or 410 damage/s | Includes 0.25 s for each Parry; assumes a successful setup and melee contact. |
| Priest free Smite, max investment in one tree | About 342 damage/s for Mercy, 332 for Reckoning | Free offense; healing, protection or preparation replaces it. |
| Priest free Smite with both trees' three-rank investments | About 382 damage/s | Six points in these two investments, plus actual gates/opportunity costs of the broader build. |

The Priest's fully improved Rebuke adds approximately 626 damage in one action,
compared with Fireball's 647 primary damage plus its completed burn. Rebuke's
deep cooldown reduction and crit talents matter, as do healing interruptions.
Mercy's greater mana availability for defense can compensate for less damage.
These are useful cross-checks, not a claim that the free-attack rows describe
their entire builds. The Scout's bow/blade, sword/dagger and high-speed
comparison is kept with its [candidate](scout.md#8-cadence-resource-and-ammunition-sanity-checks).

At unenchanted level 60, mana regeneration is only **0.25% maximum mana/s**
in combat. The shared pool does not pay for every skill on cooldown forever.
Priest support schedules and Scout mana/arrow budgets are explicit in their
candidates. The Warrior's rage grows with accepted primary swings and incoming
hits; dodging is protection, not a second rage source.

### Follow-up: Priest damage below Fire

The [Priest audit](priest.md#offense-audit-including-criticals-hybrids-and-ultimates)
now compares actual damage with expected criticals, paid attacks, ultimates
and a legal aggressive 27 Reckoning / 3 Mercy allocation. At unenchanted L60,
ordinary crit is 8.45% for both casters; Priest paid direct attacks gain six
percentage points at full Hard Faith. No crit is assigned to area damage
or burning. All actions displace basic attacks.

The continuous opportunity estimates are **458 damage/s for pure Reckoning**
and **496 for the aggressive hybrid**, versus **503 for Fireball/Spark** and
**573 when Fire also uses Lance and all Fire Rain pulses land**. These are
different selections shown explicitly, not an equal-button ranking. Both
complete offensive selections fit five equipped skills, including the basic
attack and ultimate; the Priest still reserves one of those slots for Heal.
The added 27/3 purchase sequence passes rank, gate and prerequisite checks.

This corrects the hybrid's early free-hit inversion and prevents extra crit
from silently restoring it. It does not reduce Mercy's independent solo
attack or its healing. The Priest audit also checks a six-second opening and
documents the finite mana, positioning and timing assumptions. Moving
targets, high-crit gear, low levels and several targets remain practical
checks; the directional rule does not become a damage clamp or a fixed
percentage threshold. Rime remains a control tradeoff, not the ceiling used
to justify Priest offense.

## Why protection can still feel better while leveling more slowly

The Warrior candidate works through an **assumed** eight-second Ruin fight
versus a ten-second Bulwark fight on identical illustrative armor. It uses
the current default 1.5 mob-damage multiplier, rating curve, native dodge and
class HP factors. With passive defenses alone, the two builds lose roughly
the same fraction of their health over those different exposure times.

A correctly timed five-second Hold Ground changes that result. Only damage
arriving during those seconds consumes the shield; unused capacity expires.
With zero to two useful Retort recoveries, the example loses about **6.6–9.7%
of Bulwark's HP**, versus **19.7% for Ruin**. The ultimate is excluded from
this ordinary-fight example. That illustrates the intended feeling without
inventing measured kill times. See the [full assumptions](warrior.md#6-resource-and-solo-balance-review).

This is not proof against endless survival at every gear level. Evaluate
actual shield expiry, healing after damage rather than overheal, extended
fights, ranged opponents, several attackers, support gear and shared potion
cooldowns. Never subtract nominal shield capacity divided by cooldown as if
every point were guaranteed healing.

## Distinct strengths without a universal winner

| Specialization | Desired advantage | Deliberate limitation |
|---|---|---|
| Ember | Immediate danger, strong paid fire hits and area pressure | Low HP, no self-healing; positioning and finite mana matter. |
| Rime | Space, recovery windows and a visible control-to-hit payoff | Lower direct pressure; ranged foes and confined terrain challenge control. |
| Bulwark | Forgiving melee contact, repeated modest protection | Longer kills; recovery still requires landing a melee reply. |
| Ruin | Rage-funded contact damage and small-group cleave | Loses output when denied contact; defense competes for rage. |
| Mercy | Prevention, recovery and usable independent solo damage | Supporting displaces attacks and drains mana; no escape/control kit. |
| Reckoning | Deliberate hostile bursts with limited self-repair | Damage stays slightly below Fire; healing time costs offense and support depth is lower than Mercy. |
| Quarry | Responsive ranged rhythm and aimed commitment | Arrows, aiming, finite defensive windows and channel interruption. |
| Veil | Active defense creates strong close-range openings | Must stay in contact in leather; no passive life drain or stealth escape. |

Do not force identical solo completion rates or pretend every encounter favors
every build equally. A ranged open-field advantage cannot stand in for cave,
ranged-enemy or multi-attacker comparisons. Group usefulness is a strength,
but it must not be the excuse for making a specialization miserable alone.

## What remains for the user's design review and later validation

The user is reviewing identities, starters, talent structure, transforms,
ultimate roles and costs. Shared unresolved choices remain in
[TODO-design-classes](../../../TODO-design-classes.md): strongest-only slows,
coordinated roots/stuns, hotbar switching, initial placement, area geometry,
Ice Cage and migration/refund policy. In particular, the Scout's proposed
Sprint removal, click/RMB controls, faster-arrow economy and the Priest's
support-crit change need explicit consideration rather than being hidden in
implementation.

Once the user selects the design, compare creation, first unlock, midgame,
first ultimate and level 60 (including levels 1/6/14/26/42/60). Use matched
gear assumptions, melee and ranged opponents, a small pack, a long encounter,
low mana/ammo, and four-to-six-skill loadouts without routine layout swapping.
Include actual crit/dodge, startup versus steady cadence, first-hit travel,
healing pauses, arrow copper and repeated pulls. The two 21/9 directions and
15/15 hybrids require checks alongside pure builds. No test result is claimed
for those future scenarios. Desktop and web runtime acceptance stays with
the user; icons, artwork and implementation are outside this proposal.
