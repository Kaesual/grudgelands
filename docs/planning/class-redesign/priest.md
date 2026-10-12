# Priest redesign candidate — Mercy and Reckoning

Discussion proposal, 2026-10-12. No acceptance, implementation or gameplay
validation is claimed. This document-only contribution is **compatible**.
The [future targeting contract](../../design/ability_targeting.md) is approved
and governs this candidate; numerical values and graph details remain proposals.
See the [implementation design](implementation-design.md) for the planning handoff.
Replacing saved talents and retired skill items in a future implementation
would need a separately planned migration/refund assessment.

## 1. Intended feel and boundaries

The Priest alternates deliberate support with decisive attacks. Mercy keeps
people alive through preparation and choosing the right moment to stop
attacking. Reckoning spends that same time and mana to finish enemies sooner.
Neither path needs an investment in the other tree to function alone.

**User direction (2026-10-12): even an offensive Priest must remain slightly
below the Fire Mage in damage, rather than offering a Mage's offense plus
healing.** Compare meaningful damage windows at matched level, gear and
investment, including hybrids, ultimates and expected crits. Frost pays for
slows and roots through lower damage; its comparison does not authorize
Priest damage equal to Fire. No fixed percentage gap is imposed.

Comparable ordinary solo usefulness across all four classes is a soft design
guide, not identical damage or a numerical gate. Mercy can accept somewhat
longer fights in return for recovery; it must not become tedious, invulnerable,
or a support character that first needs a damage-tree tax. Reckoning's smaller
recovery budget should remain visible when a kill window fails.

This proposal changes the Priest substantially: only two starting skills,
a useful free spell, early Shield or paid offense, earned support breadth,
and deliberate ultimates replacing the old passive capstones. Names of the
two trees stay **Mercy** and **Reckoning**.

The [revised Mage candidate](mage.md) remains a proposal; its separate
Fireball now proposes 6% P and a 5 s cooldown. Its local D unit is not a
Priest comparison unit. Nothing here settles the shared hotbar, area or control questions.

## 2. Shared formula and timing contract

Use the existing definitions in `docs/design/combat_stats.md` §2:

- P = round(20 + 5L + 0.66L²), the unmodified class-neutral pool.
- W = round(4 + 0.35L), the spell's level-baseline weapon term.
- B = W + (10 + 3(L−1))/10, the shared baseline melee total.
- I = the Priest's current Intelligence / 10, including gear; natural
  Intelligence is 10 + 2(L−1), not the Mage's growth.
- S = P/(8B), the damage level scalar; Q = 1 + gear Int/(10B), the support
  factor from `grug_classes.get_support_factor`.
- K is the existing attacker-level armor constant, not flat mitigation.

Damage tables below give **raw pre-scalar formulas**. Multiply by S once,
then settle using the ordinary damage pipeline, crit eligibility, armor,
dodge and PvP authorization. Keep fractions until the one final floor.
Pool-derived support amounts are P shares multiplied by Q exactly once,
never by S; Word of Ruin additionally obeys its actual-HP-loss cap.
Support talents modify the listed P share before Q; a heal never causes
another heal, damage, mana refund or crit-triggered support event.

Proposed Priest support spells and Word of Ruin's recovery do not crit.
This intentionally replaces the current heal-crit behavior for this kit;
retain ordinary crits for direct hostile casts. Area/periodic damage does
not crit. Global Dexterity rules remain otherwise unchanged. This is a
proposed spell eligibility choice, not an already shipped rule.

All skills share a proposed occupied action of **max(1 s, preparation)**,
including the free attack. Instant casts release at the start and occupy
1 s; prepared casts release at the end of their preparation, with no extra
recovery beyond that total. No free attacks occur during occupied time and
no queued cast bypasses it. Costs and cooldowns start on valid release. A skill must be off cooldown
before preparation begins; preparation adds to its minimum release-to-release
period (Heal: 7.5 s; Word of Ruin: 16.75 s; Final Word: 61.5 s).
An interrupted preparation retains its already reserved action time;
switching cannot reset it or bank free attacks. Moving cancels preparation;
ordinary damage alone does not. Stun, death, leaving, equipment/layout changes
or a new skill request cancel preparation. Cancellation before commitment
pays nothing and produces nothing; no refund after commitment.

Hostile single-target casts validate current aim, range and visibility again
at release through `grug_core.aim_raycast`, never stored enemy memory.
Friendly casts capture their recipient at activation and revalidate that
same recipient at release; looking elsewhere does not retarget Heal. Group
support selects automatically at release, and Censure retains a fixed area
anchor from accepted activation. Exact selection and refusal rules are owned
by [ability targeting](../../design/ability_targeting.md). Refused casts have
no cost, cooldown or support token. This future behavior needs input-path
integration; it is not claimed to exist already.

## 3. Starter kit and learned abilities

Start with **Smite and Heal**. Smite replaces Strike as the Priest's ordinary
attack from creation in this candidate. There is no paid-attack fallback
that silently becomes melee when mana is empty. All learned skills become
available through the Skills catalogue; no automatic slot insertion is
proposed. Initial starter placement remains the handoff's open question.

Costs are percentages of P, rounded with the existing minimum of 1; 0 is
explicitly free. Every listed cooldown is shared by representations in both
layouts. All single-target support ranges are 15 m unless stated otherwise.

| Skill | Access | Cost | Cooldown / preparation | Complete base effect |
|---|---|---:|---|---|
| Smite | Starter | 0 | 1 s action interval; instant | 20 m current-aim single-target hit, raw W + I. No splash, drain, shield or mana return. |
| Heal | Starter | 10% P | 6 s; stationary 1.5 s preparation | Capture aimed ally or self at activation; restore 20% P × Q to that same living player on valid release. Looking away does not retarget; an invalid recipient cancels without payment, never falls back to self. Overheal is lost. |
| Shield | Mercy M3 | 9% P | 14 s; instant | Aimed ally or self at activation: absorb 18% P × Q for 6 s. Same caster's recast replaces its remaining Shield, never adds it; independent sources keep the existing absorb contract. |
| Mend | Mercy M6 | 8% P | 12 s; instant | Aimed ally or self at activation: four ticks at +3/+6/+9/+12 s, each 4% P × Q, on that recipient. Same caster refresh replaces remaining ticks; no immediate tick. |
| Hearten | Mercy M10 | 14% P | 20 s; stationary 1.5 s preparation | Automatically heal self and up to three eligible party members within 6 m, each 10% P × Q; prioritize injured allies. Uses current position and cover at release; no target is counted twice. |
| Haven | Mercy M13, ultimate | 22% P | 60 s; stationary 1.5 s preparation | Automatically affect self and up to three eligible party members within 6 m at release; each receives 10% P × Q absorb for 6 s and immediately 10% P × Q healing. Healthy allies may receive protection. No immunity, resurrection, mana restoration or damage. |
| Rebuke | Reckoning R3 | 6% P | 6 s; instant | 20 m single-target raw 1.8(W + I). Damage only: no silence or stun. |
| Word of Ruin | Reckoning R6 | 10% P | 16 s; stationary 0.75 s preparation | 20 m single-target raw 1.6(W + I); if actual hostile HP is lost, restore min(6% P × Q, 50% of actual HP removed) to self once. Absorbed/dodged/forbidden hits grant no recovery. |
| Censure | Reckoning R9 | 12% P | 18 s; stationary 0.75 s preparation, then 0.75 s fixed warning | Previewed crosshair area anchor within 16 m, captured at preparation start and revalidated at release; horizontal radius 3 m, vertical allowance 2 m; one raw 1.2(W + I) hit to each eligible hostile, maximum four. No DoT or control. |
| Final Word | Reckoning R13, ultimate | 20% P | 60 s; stationary 1.5 s preparation | 20 m single-target raw 2.8(W + I). A clear preparation cue, no execute threshold, reset, heal or invulnerability. |

Haven and Hearten use the [automatic party selection contract](../../design/ability_targeting.md#3-automatic-party-support).
Their maximum totals are four times the per-recipient amount, not multiplied
by all nearby allies. No player selects multiple recipients with a cursor.

Censure's four targets are nearest the center, ties by stable actor id. Its
footprint must follow the handoff's proposed one-cell-per-column model once
that shared model is decided; no through-floor or through-wall hits. Missing
cells remain empty. Geometry is a shared prerequisite to implementation,
not a claim that a spherical radius scan suffices.

Word of Ruin has a pool-derived recovery ceiling and an actual-damage cap.
The existing `deal_ability_damage` return is pre-player-mitigation in the
current contract (`skill_trees.md` §2.6); it cannot prove actual HP loss.
An implementation must provide a confirmed settlement result at the existing
seam or revise this trigger before building it, never infer success from the
old numeric return. The recovery ceiling is not multiplied by damage talents. Its second cap is
50% of actual HP removed, clamped to pre-hit remaining HP; overkill never
funds healing. Thus a 1 HP victim funds at most 0.5 HP before rounding. Q
applies only to the pool-derived ceiling, never again to the actual-loss cap.
Crit may increase actual loss up to that fixed ceiling, but cannot trigger
another recovery, healing crit, damage event or resource refund. This keeps
a bounded offensive recovery while preventing trivial-target healing farms.

## 4. Talent arithmetic and genuine prerequisites

One point at every even level gives 30 points at level 60. Gate N requires
N points **already spent in that tree**, excluding the new purchase. Each
rank costs one point. Every listed prerequisite requires rank 1; empty means
none. A prerequisite is required even if the point gate is already met.
Ultimate gate 20 means earliest level 42. Both ultimates need at least 42
points and cannot coexist. Pure builds still leave attractive ranks unbought.

| Gate | 0 | 2 | 6 | 10 | 12 | 16 | 20 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Earliest first purchase | 2 | 6 | 14 | 22 | 26 | 34 | 42 |

### Mercy — 34 purchasable ranks

Mercy's attack investment stays inside Mercy. Its core damage upgrade is
available immediately; its later payoff makes room for an attack after
support without converting support output into more damage.

| Code | Node | Gate | Ranks | Parent | Effect by rank |
|---|---|---:|---:|---|---|
| M1 | Steady Word | 0 | 3 | — | Smite raw damage gains 0.05/0.10/0.15B. |
| M2 | Measured Care | 0 | 3 | — | Heal, Shield, Mend, Hearten and Haven costs −4/8/12%; additive with any other cost reduction. |
| M3 | Shield | 2 | 1 | — | Unlock Shield. |
| M4 | Gentle Hand | 2 | 3 | — | Heal share becomes 22/24/26% P before Q. |
| M5 | Warding Faith | 6 | 3 | M3 | Shield share becomes 20/22/24% P before Q. |
| M6 | Mend | 6 | 1 | — | Unlock Mend. |
| M7 | Patient Care | 10 | 3 | M6 | Mend ticks become 4.5/5/5.5% P before Q; same four ticks. |
| M8 | Clear Conscience | 10 | 3 | — | After committing Heal, Shield or Mend, next Smite within 5 s gains 0.10/0.20/0.30B raw; once per 8 s, one non-stacking charge. No requirement to heal missing HP; no effect from periodic ticks or other support skills. |
| M9 | Deep Reserve | 12 | 3 | — | Maximum mana +4/8/12% P; costs still use P. |
| M10 | Hearten | 12 | 1 | — | Unlock Hearten. |
| M11 | Quiet Care | 12 | 3 | — | Effective-healing threat factor 0.50 → 0.45/0.40/0.35; no PvP damage reduction. |
| M12 | Shelter | 16 | 3 | M3 | While own Shield survives, recipient gains 0.03/0.06/0.09K armor rating at caster level; ends when Shield expires or is consumed. Same named modifier uses strongest value across casters. |
| M13 | Haven | 20 | 1 | M10 | Unlock Haven; Hearten teaches its bounded group selection. |
| M14 | Lasting Haven | 20 | 3 | M13 | Haven absorb duration 7/8/9 s; healing and amount unchanged. |

Steady Word is always useful solo. Clear Conscience recovers only a fraction
of a foregone attack: even maximum 0.30B is substantially below Smite's whole
W + I + 0.15B hit. Spending mana on an unnecessary heal to fish for this
charge is a damage loss, not an optimal offensive loop.

### Reckoning — 34 purchasable ranks

| Code | Node | Gate | Ranks | Parent | Effect by rank |
|---|---|---:|---:|---|---|
| R1 | Sharpened Word | 0 | 3 | — | Smite raw damage gains 0.04/0.08/0.12B. |
| R2 | Measured Judgment | 0 | 3 | — | Rebuke, Word of Ruin, Censure and Final Word costs −4/8/12%; no support discount. |
| R3 | Rebuke | 2 | 1 | — | Unlock Rebuke. |
| R4 | Firm Rebuke | 2 | 3 | R3 | Rebuke raw damage gains 0.10/0.20/0.30B. |
| R5 | Long Reach | 6 | 3 | — | Smite, Rebuke, Word of Ruin and Final Word range +1/2/3 m; no area-size increase. |
| R6 | Word of Ruin | 6 | 1 | — | Unlock Word of Ruin. |
| R7 | Resolute Word | 10 | 3 | R6 | Word of Ruin recovery ceiling becomes 7/8/9% P before Q; the 50%-of-actual-HP-loss cap remains; damage unchanged. |
| R8 | Hard Faith | 10 | 3 | — | Paid direct hostile Priest spell crit chance +2/4/6 percentage points, within the existing 30% cap; Smite retains only ordinary crit, and support cannot crit. |
| R9 | Censure | 12 | 1 | — | Unlock Censure. |
| R10 | Broad Judgment | 12 | 3 | R9 | Censure radius 3.25/3.50/3.75 m; four-target cap and vertical allowance unchanged. |
| R11 | Deep Resolve | 12 | 3 | — | Maximum mana +4/8/12% P. |
| R12 | Press the Verdict | 16 | 3 | R3 | Rebuke cooldown 5.5/5.0/4.5 s; cost unchanged. |
| R13 | Final Word | 20 | 1 | R3 | Unlock Final Word, the deliberate culmination of Rebuke's direct-hit branch. |
| R14 | Unfinished Sentence | 20 | 3 | R13 | Final Word raw damage gains 0.10/0.20/0.30B; no execute multiplier. |

The real edges are M3→M5/M12, M6→M7, M10→M13→M14;
R3→R4/R12/R13→R14, R6→R7 and R9→R10. Other nodes use tree
spend gates. Neither ultimate requires a fully ranked filler chain.

## 5. Worked purchases and equipped loadouts

Each sequence is ordered, legal and totals 30. A repeated node means adding
ranks, not repurchasing existing ones. Tree-local totals matter when mixing.

| Build | Valid purchase sequence | Point total |
|---|---|---:|
| Pure Mercy | M1×3, M3, M2×2, M6, M4×3, M5×3, M10, M8×3, M9×3, M13, M7×3, M12×3, M2×1, M14×2 | 30 Mercy |
| Pure Reckoning | R1×3, R3, R2×2, R6, R4×3, R8×3, R9, R7×3, R11×3, R13, R12×3, R14×3, R2×1, R5×2 | 30 Reckoning |
| Mercy with paid attack | M1×3, M3, M2×2, M6, M4×3, M5×3, M10, M8×3, M9×3, M13; then R1×3, R3, R2×2, R6, R4×2 | 21 Mercy / 9 Reckoning |
| Reckoning with protection | R1×3, R3, R2×2, R6, R4×3, R8×3, R9, R7×3, R11×3, R13; then M1×3, M3, M2×2, M6, M4×2 | 9 Mercy / 21 Reckoning |
| Broad mixed support/offense | M1×3, M3, M2×2, M6, M4×3, M5×3, M10, M8; then R1×3, R3, R2×2, R6, R4×3, R8×3, R9, R7 | 15 / 15; no ultimate |

| Build/situation | Ordinary equipped skills, including basic and ultimate | Available but unequipped |
|---|---|---|
| Pure Mercy solo, five | Smite, Heal, Shield, Mend, Haven | Hearten; six total available |
| Pure Mercy party, six | Smite, Heal, Shield, Mend, Hearten, Haven | None |
| Pure Reckoning solo, five | Smite, Heal, Rebuke, Word of Ruin, Final Word | Censure; six total available |
| Pure Reckoning packs, six | Same five plus Censure | None |
| 21 Mercy / 9 Reckoning solo, six | Smite, Heal, Shield, Mend, Rebuke, Haven | Hearten, Word of Ruin; eight available |
| 9 Mercy / 21 Reckoning solo, six | Smite, Heal, Shield, Rebuke, Word of Ruin, Final Word | Mend, Censure; eight available |
| 15 / 15 solo, five | Smite, Heal, Shield, Rebuke, Word of Ruin | Mend, Hearten, Censure; eight available |
| Simple ordinary questing, four | Smite, Heal, Shield, Mend (Mercy), or Smite, Heal, Rebuke, Word of Ruin (Reckoning) | Ultimate and group/area options may remain unequipped |

Mercy can trade Mend for Hearten when several allies take bursts; it need
not hotbar-swap to cast both every cooldown. A hybrid's extra repertoire is
permitted, but ordinary performance must not rely on a seven-button cycle.
Test the incentive to swap for each extra support cooldown when the shared
combat-switching policy is decided. The 15/15 build gives up both ultimates;
the 21/9 builds give up deep efficiency, duration or damage improvements.

## 6. Solo pace, mana and opportunity costs

At L60 without attribute enchants, P=2696, W=25, B=43.7, I=12.8
and the damage scalar S≈7.71167. Here S is a multiplier, **not** a
class-local hit. Mage D=P/8=337, while the Priest's ordinary spell is
`(W+I)S=291.501`. Convert class-local notation to actual damage before
comparing classes.

Maximum Mercy Steady Word makes free Smite 342.051; Reckoning's revised
Sharpened Word makes it 331.941. Both together give 382.491. The small
Reckoning-only reduction preserves Mercy solo damage while containing the
hybrid; paid attacks remain Reckoning's advantage. Ordinary crit remains on
Smite, but Hard Faith now improves only paid direct attacks. Otherwise the
extra six crit points would conceal a hybrid free-attack advantage over Fire.

Fully improved Rebuke is `[1.8(37.8)+0.30(43.7)]S=625.802` in 1 s,
costing 6% P every 6 s, or 4.5 s with Press the Verdict. Mage Fireball
with Fire Mastery is 1.92D=647.040 plus 0.18D=60.660 completed burn
with Afterglow, costing 6% P every 5 s. Rebuke's cooldown improvement
buys repeated pressure; it does not add a free attack during its action.

Final Word is reduced to `[2.8(37.8)+0.30(43.7)]S=917.303` at full
investment, occupying 1.5 s and costing 20% P, with minimum release period
61.5 s. Mage Lance is 2.97D=1000.890 in 1.25 s, costing 10% P,
minimum release period 9.25 s. Final Word still buys roughly 419 damage
above 1.5 pure Reckoning free attacks, or 344 above hybrid free attacks.
It no longer overtakes Lance's individual noncrit hit. This is a modest
coefficient correction, not a new execute rule, resource or damage type.

### Offense audit including criticals, hybrids and ultimates

At these inputs natural Dexterity is 69 for both casters: ordinary crit is
8.45%, and Hard Faith makes paid Priest direct crit 14.45%. With double
crit damage the expected multipliers are 1.0845 and 1.1445. Burning and
area damage do not crit. All figures below precede target defenses and
rounding. Use average expectations, not a guarantee about each random hit.

| Offense selection | Expected damage/s, continuous opportunity estimate |
|---|---:|
| Pure Mercy free Smite | 370.95 |
| Pure Reckoning free Smite | 359.99 |
| Both Smite investments, free attacks | 414.81 |
| Pure Reckoning, Smite + best Rebuke + Word of Ruin + Final Word | 457.82 |
| Offensive 27 Reckoning / 3 Mercy hybrid, same paid skills | 495.85 |
| Fire, Spark + full Fireball/Afterglow | 503.33 |
| Fire, additionally full Lance and Fire Rain with all pulses landing | 572.64 |

The aggressive hybrid is a feasible 30-point check, not a sum of unavailable
maxima: R1×3, R3, R2×2, R6, R4×3, R8×3, R9, R11×3,
R12×3, R13, R14×3, R2×1, R7×2, then M1×3. Its equipped five are
Smite, Heal, Rebuke, Word of Ruin and Final Word; Censure remains optional.
The existing 21/9 protection build has stronger support but lacks the deep
Rebuke cooldown and Final Word ranks; it is below this damage envelope.
The 15/15 mixed build lacks both ultimates and deep Rebuke reduction.
Mercy's follow-up still loses more attack time than its bonus repays.

For the hybrid row, with A=382.491×1.0845, use
`A + (625.802×1.1445−A)/4.5 + (466.402×1.1445−A)/16.75
+ (917.303×1.1445−1.5A)/61.5`. For Fire, add Lance's occupied-time
increment over 9.25 s and `(3.30D−1.20D×1.0845)/60` for Fire Rain.
These are long averaged opportunity estimates: scheduling collisions can
reduce them; they neither permit fractional attacks in a short window nor
claim finite mana sustains every cooldown indefinitely. The hybrid spends
about 2.26% P/s before discounts on these three paid attacks; all three Fire
options spend about 2.65% P/s. Base regen is only 0.25% maximum mana/s.

A separate ready-cooldown six-second opening illustrates burst. Priest:
Rebuke at 0, prepare Final Word from 1 to 2.5, Word of Ruin from 2.5 to
3.25 (occupied until 3.5), Smite at 3.5, a second Rebuke at 4.5 after
its improved cooldown, and Smite at 5.5. Expected total is about 3846
for the offensive hybrid, or 3736 for pure Reckoning.
Fire: Fire Rain at 0, Lance prepared 1–2.25, Fireball at 2.25, Sparks
at 3.25/4.25/5.25; five rain pulses at 1/2/3/4/5 and the complete
burn yield about 4276. Both openings include their ultimate and five
skills available in an ordinary loadout; Fire's total assumes staying in
Rain and all committed projectiles settling inside the observation window.
It costs 38% P before discounts versus the Priest's 42% P. It is a stated
stationary-target, negligible-flight-time case, not proof of an advantage
against moving targets.

At levels 12–16, the former combined +0.30B could even overtake fully
improved Fire's free attack before crit; +0.27B removes that inversion at
the first level all six ranks are affordable. At level 1 their native free
spell baselines coincide; specialization has not started. Equal gear-Int
adds to each class's numerator, never a second damage multiplier. With the
same crit inputs, the revised paid-hit coefficients also stay below the
corresponding Fire hits as gear Int grows. Different itemization, several
targets, travel/cover, finite discrete windows and high-crit builds still
need explicit comparisons. Censure's four-target cap is unchanged; it must
not become an unmeasured area loophole. The user direction is binding;
these illustrative checks are not gameplay acceptance or a fixed parity band.

The one-hit values and expected-crit schedules are illustrations, not
simulated kills. A Mercy Heal at maximum Gentle Hand restores 701×Q
before final rounding but loses
its 1.5 s occupied preparation: roughly 1.5 ordinary attacks in a
long-run opportunity estimate, with discrete timing checked separately.
Maximum Clear Conscience restores only about 101 raw-settled damage once per
8 s. Shield or Mend occupies one attack interval. Healing, protection and
attacking therefore compete for both time and mana; throughput is not the
sum of every button's tooltip divided by cooldown.

Unenchanted L60 combat mana regeneration is max(2.5, 0.0025×2696)=6.74/s,
exactly 0.25% P/s. Full Deep Reserve/Resolve increases capacity to 1.12P
and the pool-based regen term to 0.28% P/s. There is no new regen multiplier,
critical refund, heal-to-mana effect or damage-to-free-shield cycle.

For a conservative 30 s interval, excluding casts at its endpoint:

- Pure Mercy: three Heals, two Shields and two Mends cost 64% P before
  Measured Care, or 56.32% at rank 3, minus about 8.4% P regeneration
  with full reserve. One Haven adds 19.36% P net cost before its share of
  regeneration. These casts occupy 8.5 s, or 10 s with Haven, leaving
  fewer free attacks. Initial full mana permits a recovery burst, not permanence.
- Pure Reckoning: five Rebukes, two Words of Ruin and one Heal cost 60% P
  before discounts; with rank-3 Measured Judgment the offensive half costs
  44% P, Heal still 10%, so 54% P total minus roughly 8.4% regeneration.
  One Final Word adds 17.6% P and 1.5 s occupied time; the listed
  other casts occupy 8.5 s. Faster Rebuke ranks increase expenditure.
- At zero mana both still have full ordinary Smite. At L60 baseline regen
  needs about 40 s to fund an undiscounted Heal from empty; its cooldown
  does not imply sustainable six-second healing. Low-level rounding and
  the flat regen floor require separate L1/L6/L14 checks.

These schedules are resource illustrations, not fixed rotations. Actual
spending falls when enemies die or no healing is needed. Pure Mercy spends
nothing on offense; Reckoning buys faster kills with a pool Mercy can use
for protection. Neither receives infinite effective healing under sustained
pressure. Food and consumables retain existing combat restrictions.

## 7. Progression, group balance and counterplay

At creation, attack versus stationary healing teaches the basic trade.
Level 6 can add instant prevention (Shield) or a paid damage spike (Rebuke).
Level 14 introduces planned recovery (Mend) or offensive self-repair (Word
of Ruin). Around level 22, Clear Conscience or direct-spell crit improves
flow. Level 26 brings bounded party recovery or area damage. Level 42 adds
a prepared ultimate; remaining points deepen the chosen strengths.

Mercy must finish ordinary solo encounters with its own six-skill repertoire
and zero Reckoning points. Measure fights and repeated pulls using identical
level, equipment quality, enemies and consumable assumptions across classes:
L1, L6, L14, L26, L42 and L60, melee and ranged pressure, single and small
packs. Include time healing between pulls, mana exhaustion, cover, mistakes,
and support gear. Existing Priest 12–16 s normal TTK documentation describes
the shipped kit; it is evidence, not a new mandatory acceptance band.

Group healing is deliberately bounded to four recipients and costs attack
time. Haven's primary-target value is only 20% P×Q split between immediate
repair and expiring prevention; it is a rescue window, not a full refill.
There is no damage buff that makes a Priest obligatory in every party.
Measure two Priests rotating group skills and stacking independent shields;
per-caster limits alone do not establish group balance. Use existing threat
for effective healing; do not invent a second combat ledger.

In PvP, opponents can interrupt preparation with existing control, break
release line of sight, pressure the Priest during its action interval, force
Shield early, or switch targets after a support commitment. Smite remains
free but cannot heal, slow, root or generate protection. Rebuke has no hidden
silence. Word of Ruin cannot recover on an absorbed hit or turn overkill into healing. Censure's fixed
warning and four-target cap permit dispersal; Final Word is visibly prepared.
Mercy has no emergency teleport, hard control or damage immunity. Healing
cannot become a parallel stream of unbroken free attacks.

Validate armor, support-factor gear, 30% crit cap, multiple attackers and
several healers together. Strongest-only slows and repeated-control handling
remain shared open decisions; this kit introduces no new root or slow and
cannot silently settle those decisions. Prebuffing must respect short expiry,
same-source replacement and normal costs, including after layout switching.

## 8. Review limits and implementation handoff

Review especially Mercy's potentially safe sustained ranged solo damage,
hybrid additive Smite scaling, low-level free-cast tempo, two-healer shield
coverage and support gear. Tune coefficients, costs and action occupation
before adding another resource or extra mandatory active button. A proposal
with roughly comparable solo usefulness still needs gameplay evidence.

Keep server-side authority, current PvP seams, death/reconnect cleanup and
one input state machine. Every damage/support amount must enter its existing
owner once. The proposed action interval and Word of Ruin settlement receipt
are concrete implementation dependencies, not casual tooltip edits.

No environmental edits, icons, art, sounds or asset generation are included.
For future effects, propose at most 12 particles for ordinary casts, 24 for
support/group releases, 32 for an ultimate, each lifetime ≤1 s; warnings
use a bounded marker instead of a continuous stream. Repeated visible effects
still need a many-player budget check on desktop and web, with total active
particles in hundreds. Those checks and GUI acceptance belong to later work.

After user decisions, move accepted mechanics to their existing design owners,
plan the saved-talent migration and independent implementation review, and
update the open-question tracker. Nothing in this candidate authorizes play
changes, a release round, deployment or push.
