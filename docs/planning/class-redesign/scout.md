# Scout redesign candidate — fast bow, deliberate blade

Proposal for discussion, 2026-10-12. No gameplay implementation is claimed.
**Upgrade classification: compatible, documentation only.** Implementing new
entitlements/talent saves would need a separately reviewed migration/refund.
Names, numerical tuning, exact timing and graphs remain candidates; approved
interaction rules are identified separately below.
The handoff's fixed A/B rules and 30-point progression are respected.

The [future targeting contract](../../design/ability_targeting.md) is approved
and applies to this candidate. See the [implementation design](implementation-design.md)
for the complete interaction map and remaining planning choices.

## 1. What should change

A new Scout should shoot promptly and feel effective before buying a talent.
Quarry becomes the archer who alternates quick arrows with deliberate strong
shots; Veil becomes a visible blade fighter who creates and exploits openings.
The distinction is how the player fights, not an invisible damage multiplier.
No poison, invisibility, trap entity, companion or third resource is proposed.

Start with **Loose and Sidestep**, two skill representations. The existing
bow, Melee blade, leather, Dexterity, mana pool, arrows and quiver remain.
Strike remains an entitlement for players who prefer its separate button,
but ordinary builds need not equip it: Loose provides the same melee attack.
Snare Shot and Sprint cease being starters in this candidate. Snare is earned;
Sprint is omitted from the proposed combat repertoire, a change to the old
explicit starter decision that must be approved rather than silently applied.
No new skill is automatically placed on either hotbar; creation placement
remains the handoff's open common decision.

## 2. Units, equipment and cross-class restraint

Let `S(L) = P(L)/(8*B(L))` be the existing damage level scalar.
`R = (usable Ranged bow damage + Dexterity/10) * S(L)`.
`M = (usable Melee blade damage + Dexterity/10) * S(L)`.
`P` is the unmodified class-neutral pool and `K` the armor-rating constant.
R and M are pre-crit, pre-mitigation illustration units. Implementation would
assemble terms before the one existing level scalar and floor only once.
Neither unit is the Mage's Spark damage D; they must never be equated.

Bow skills read only Ranged weapon damage; blade skills only Melee damage.
Both equipment slots retain their normal stat contributions. No dual strike,
second damage roll from the other hand, or stronger-of-two weapon selection.
An unusable blade uses the existing bare-hand source and interval. An unusable
bow cannot shoot. Weapon progression therefore still matters to each identity.
Mana costs use P, minimum 1 after rounding; regeneration stays the shared rule.
No extra resource regeneration or healing is assumed in the candidate.

For orientation, equal-ilvl equal-level bow/Mage damage numerators differ:
Scout has +2 Dex/level; Mage +3 Int/level. At level 60 with item level 60 weapon damage 25,
R has numerator 37.8 while the proposed untalented Spark has 43.7: R/D ≈ 0.865.
At level 12 with item level 12 damage 8, those numerators are 11.2 and 12.3: R/D ≈ 0.911.
These omit gear attribute bonuses, crit and mitigation; the actual starter
items need their own comparison. They establish no guaranteed clear-time ratio.

## 3. One click fires; no hold-to-draw obligation

**Loose:** LMB starts one fixed 0.18 s visible preparation, then releases one
0.95 R arrow. Total occupied time is 0.85 s from accepted start, comprising
preparation and recovery. A tap completes the shot without continued holding;
holding may repeat completed ordinary shots at that interval, never charge.
The first shot requires no 2.5 s wait, and no talent repairs a slow starter.

Range 25 m; nominal flight speed 50 m/s; one arrow; no mana. Movement during
preparation is normal. Preparation does not stack or preserve charge.
The old quadratic partial-draw damage and permanent half-speed draw stance
are removed in this proposal. No separate quick/full-draw firing modes.

Only the bow's own attack-speed affix divides the 0.85 s interval, floor 0.65 s;
it does not shorten preparation below 0.18 s or paid-skill windups/cooldowns.
The blade's attack-speed affix affects only its existing melee interval.
Fletching's old draw-time talent is replaced, not added to this new cadence.
Throughput illustrations exclude affix speed and critical hits unless stated.

Loose RMB against a current hostile within existing melee reach performs
one ordinary mana-free Melee attack. It does not also fire an arrow.
With no usable arrow/bow, LMB on Loose also performs that melee attack if
in reach, otherwise gives a short feed notice and spends nothing. No free
ranged substitute appears when the quiver is empty. The tooltip always
advertises the blade action, before the player actually runs out of arrows.
RMB on a nonhostile keeps contextual interaction; pickup arbitration remains.
This exact RMB integration is a proposed input change, not claimed to exist.

**Bladecraft**, bought for one Veil point, replaces the basic representation:
LMB is ordinary Melee; RMB is the same Loose shot, only at a valid hostile.
Bladecraft's empty-ammo RMB does not repeatedly attempt a shot or auto-switch
weapons. The melee LMB remains usable. Both variants have exactly one normal
bow action and one normal melee action, with the same shared action clock.
The conversion updates both layouts in place, preserving slot and cooldown.
Ranged skills, including Aimed Shot, remain usable after this conversion.

## 4. Offensive actions really replace one another

This proposal adds a **Scout offensive recovery clock**, revising the current
no-global-cooldown design only where needed to prevent two weapon streams.
Every bow release, melee attack and damaging special occupies that clock.
A bow shot reserves 0.85 s; a blade attack reserves its equipment interval;
paid attacks reserve the times below. Switching skill, weapon or layout never
clears an existing reservation. One accepted action cannot also be Strike.
Projectiles may remain in flight after recovery, but their firing time was paid.

There is no queue of extra attacks and no catch-up after lag. Holding an
input across a mode/layout change must not fire the newly selected skill.
Two copies of a skill share entitlement, cooldown and this clock.
Sidestep, Parry and the Veil ultimate each occupy 0.25 s when accepted; they
may cancel preparation, but never shorten recovery of a committed attack.
They add no hidden damaging attack. A defensive effect may activate during
committed offensive recovery, but adds its 0.25 s to the next offensive-ready
time; it does not receive a free overlap. It requires a fresh deliberate
action, not a held-input repeat. The Quarry ultimate is itself offensive.

Ordinary targeted attacks validate current aim/permission at start and again at release.
Invalid aim before release cancels without mana/ammo/cooldown payment; elapsed
preparation is lost. Death, stun, equipment/layout change or another deliberate
action cancels preparation. No movement cancellation except where specified.
At a normal release, reserve its projectiles and atomically spend arrows/mana,
start cooldown and settle the action receipt. Allocation failure spends nothing.
Arrowfall is the per-shot exception: later releases retain its first target
with the approved forgiving facing check and pay only their own resources.
See [ability targeting](../../design/ability_targeting.md#5-arrowfall) and the
[settlement proposal](implementation-design.md#arrowfall-settlement-proposal-for-the-implementation-brief).
An interrupted committed action never refunds costs or resets recovery.
Melee skills commit through the existing accepted melee-action boundary;
Opening's special conditions are checked at that boundary, not on an old aim.
A dodge/absorb or later lost projectile target never refunds a fired action.

## 5. Complete active repertoire

All direct hits can crit under the ordinary cap; the Quarry ultimate's repeated
hits cannot crit. Damage bonuses below add as coefficients of original R/M;
never multiply a previously boosted hit again. Slow combination below is a
proposal for strongest-hostile-slow-wins, requiring the shared class decision.
No new root or stun is used, so this kit needs no private control-immunity rule.
Cooldowns begin at committed release/activation. Preparation may begin only
after the skill is off cooldown: Aimed Shot therefore releases no sooner
than every 6.75 s (6 s cooldown plus 0.75 s preparation). One arrow means one consumed
arrow before Quiver savings; specials other than Loose receive no savings.

| Skill | Damage/effect | Timing and cost | Range/limits |
|---|---|---|---|
| Loose / Bladecraft | Ordinary bow 0.95 R or ordinary blade 1.00 M | Bow 0.18 s prepare, 0.85 s action; blade existing full interval; bow 1 arrow, blade free | Bow 25 m; blade existing 3 m reach; single target |
| Sidestep, starter | +15 percentage points dodge for 3 s, ordinary 30% cap | 18 s cooldown; 6% P; 0.25 s action | Self; no displacement, root break or immunity |
| Aimed Shot | 1.80 R | 0.75 s preparation, 1.35 s total action; 6 s cooldown; 6% P + 1 arrow | 25 m; during preparation movement stance × 0.5; no root or knockback |
| Snare Shot | 0.45 R; 35% slow 3 s | 0.18 s preparation, 0.85 s total; 14 s cooldown; 5% P + 1 arrow | 25 m; clear projectile cue; slow refreshes, never stacks |
| Split Shot | Primary 0.90 R; up to 2 other targets 0.55 R each | 0.35 s preparation, 1.00 s total; 10 s cooldown; 8% P once; 1 arrow per actual recipient | Aim at primary within 25 m; automatically choose nearest eligible secondaries within 3 m of primary, each visible/in range from caster; max 3 targets |
| Arrowfall, Quarry ultimate | Up to four arrows on one initially aimed target, each 1.60 R, no crit | Releases at 0.80/1.40/2.00/2.60 s; occupied through 3.00 s; 60 s cooldown from first shot; complete volley 16% P + 4 arrows, paid per release | Target 25 m; later shots require same target broadly in front, visible, legal and in range, not exact crosshair aim. Caster speed × 0.5 until final release or termination |
| Opening | 1.35 M; 1.80 M from behind or with a Parry opening | Melee full interval; 8 s cooldown; 5% P; no preparation beyond ordinary swing | 3 m; rear means caster inside target's rear 120° at settlement; no bonus simply because target is rooted |
| Parry | Next direct single-target hostile hit within 2 s reduced 40%; grants one Opening permission for 3 s | 12 s cooldown; 4% P; 0.25 s action | Self; a dodged eligible hit also consumes Parry and grants permission; area/periodic damage does neither |
| Flourish | Up to 3 hostiles in a frontal 90° cone, each 0.80 M | 0.25 s visible preparation; total max(1.0 s, blade interval); 12 s cooldown; 8% P | 3 m; per-target current permission/cover; no displacement |
| Close Dance, Veil ultimate | For 5 s, next 3 landed basic blade attacks gain +0.35 M each; first eligible direct incoming hit reduced 30% | 60 s cooldown; 14% P; 0.25 s action | No haste; no slow immunity; reduction does not add to Parry, strongest consumes both if simultaneous |

Arrowfall follows the approved [single-acquisition volley contract](../../design/ability_targeting.md#5-arrowfall).
The Scout cannot retarget remaining arrows, perform melee or fire Loose during
the occupied action. Moving is allowed at the stated stance; deliberate other
actions cancel remaining releases without resetting committed recovery.
Unfired arrows and unpaid mana stay with the player; fired shots are never
refunded. Exact rounding and facing tolerance are planning parameters in the
implementation design, not hidden engine defaults.

Parry's reduction occurs after crit/armor/dodge and before absorbs/HP. A dodge
can create an opening without HP damage, but it consumes the one permission
source. An absorbed non-dodged eligible hit likewise consumes the guard.
Only one Opening permission exists; refresh never stacks; a committed Opening
consumes it even if dodged. PvP legality gates the triggering hostile hit.
Parry requires no aimed attacker. Its active-guard cue and the resulting
Opening-ready cue are distinct; readiness remains visible when switching to
Opening. The stronger frontal hit after Parry is the ordinary solo route;
the rear bonus is an extra opportunity, not a required rotation step.
Close Dance's outgoing charges consume only on actual HP damage; expire after 5 s.
Neither ult can be combined with the other under the 30-point budget.

## 6. Talent arithmetic and graphs

One point at each even level: 30 at 60. Gate N means N **already spent in that
tree** before purchase. Parent means at least one rank unless stated otherwise.
Gate 0/2/6/10/12/16/20 first buys occur at level 2/6/14/22/26/34/42.
Every rank costs 1. No rank raises a listed prerequisite gate for later ranks.
Q and V are discussion codes, not an approved saved-id replacement scheme.

### Quarry — 32 purchasable ranks

| Code | Talent | Gate | Ranks | Parent | Effect by rank |
|---|---|---:|---:|---|---|
| Q1 | Bowcraft | 0 | 4 | — | Bow attacks add 5/10/15/20% of their untalented damage, including Arrowfall; excludes blade |
| Q2 | Quiver | 0 | 3 | — | Loose has 10/20/30% chance to save its arrow at atomic consumption; arrow must exist to fire |
| Q3 | Measured Breath | 0 | 3 | — | Paid bow mana costs −5/10/15%; no ammo reduction |
| Q4 | Aimed Shot | 2 | 1 | — | Unlock Aimed Shot |
| Q5 | Firm Aim | 6 | 3 | Q4 | Aimed Shot gains +0.10/0.20/0.30 R |
| Q6 | Snare Shot | 6 | 1 | — | Unlock Snare Shot |
| Q7 | Long View | 10 | 3 | — | All bow acquisition ranges +1/2/3 m; no post-release flight chase extension |
| Q8 | Split Shot | 12 | 1 | — | Unlock Split Shot |
| Q9 | Broad Shot | 12 | 3 | Q8 | Each secondary arrow gains +0.05/0.10/0.15 R; still max 3 targets |
| Q10 | Light Recovery | 16 | 3 | — | Sidestep mana cost −10/20/30%; no cooldown or immunity gain |
| Q11 | Follow the Line | 16 | 3 | Q4 | A landed Aimed Shot empowers next Loose on that same target within 3 s by +0.10/0.20/0.30 R; one charge, refresh only |
| Q12 | Arrowfall | 20 | 1 | Q4 | Unlock Arrowfall; aim once, then maintain broad facing and line of sight for the volley |
| Q13 | Heavy Rain | 20 | 3 | Q12 | Each Arrowfall hit gains +0.04/0.08/0.12 R |

Edges: Q4 → Q5, Q11, Q12; Q8 → Q9; Q12 → Q13. Other nodes use tree gates.
Sidestep is innate, so Q10 requires no artificial predecessor.
Q1 applies once to untalented coefficients; Q5/Q9/Q11/Q13 add separately.
Quarry chooses ammo economy, sustained single-target, spread damage or range.
It cannot take all 32 ranks; high damage does not demand every utility unlock.

### Veil — 33 purchasable ranks

| Code | Talent | Gate | Ranks | Parent | Effect by rank |
|---|---|---:|---:|---|---|
| V1 | Bladecraft | 0 | 1 | — | Transform the basic representation's input priority as above |
| V2 | Fine Edge | 0 | 4 | — | Blade attacks add 8/16/24/32% of untalented damage, excludes bow |
| V3 | Light Step | 0 | 3 | — | Dodge +1/2/3 percentage points; ordinary cap stays 30% |
| V4 | Opening | 2 | 1 | V1 | Unlock Opening |
| V5 | Deep Focus | 2 | 3 | — | Paid blade skills, Parry and Close Dance mana costs −5/10/15%; excludes Sidestep/bow |
| V6 | Parry | 6 | 1 | — | Unlock Parry |
| V7 | Held Guard | 6 | 3 | V6 | Parry waiting window 2.25/2.50/2.75 s; consumes once, reduction unchanged |
| V8 | Flourish | 12 | 1 | V1 | Unlock Flourish |
| V9 | Wide Edge | 12 | 3 | V8 | Flourish damage +0.05/0.10/0.15 M to each eligible target |
| V10 | Turn the Blade | 12 | 3 | V4, V6 | Opening using Parry permission gains +0.10/0.20/0.30 M; rear-only Opening gains no extra |
| V11 | Shake Loose | 16 | 3 | — | Sidestep clears current slow on activation; cooldown 17/16/15 s; no root break or slow immunity |
| V12 | Close Dance | 20 | 1 | V4, V6 | Unlock the offense-and-defense ultimate |
| V13 | Cutting Rhythm | 20 | 3 | V12 | Close Dance empowered basics gain another +0.05/0.10/0.15 M each |
| V14 | Travel Worn | 6 | 3 | — | Maximum HP +3/6/9% of class-neutral P; no heal on activation |

Edges: V1 → V4, V8; V6 → V7; V4 + V6 → V10, V12; V8 → V9; V12 → V13.
V2 uses the currently equipped blade regardless of basic input preference.
V1 prerequisites make the intended blade controls explicit; they are an input
transformation dependency, not a demand to buy all preceding numeric ranks.
Pure Veil still decides between damage, mana comfort and passive health.
No chance roll is required to make Opening useful: front-facing 1.35 M works.

## 7. Worked purchase orders, not just final point counts

Numbers after × are ranks bought at that point. A later occurrence adds ranks.
Each order below meets its gate before buying; omitted nodes stay unranked.

| Build | Exact order; tree subtotals | Class repertoire, including starter; Strike counted below |
|---|---|---|
| Pure Quarry 30/0 | Q1 × 4, Q4, Q2 × 3, Q5 × 3, Q6, Q8, Q9 × 3, Q7 × 3, Q11, Q12, Q3 × 3, Q10 × 3, Q13 × 3 | Loose, Sidestep, Aimed Shot, Snare Shot, Split Shot, Arrowfall: 6 |
| Pure Quarry follow-up 30/0 | Q1 × 4, Q4, Q2 × 3, Q5 × 3, Q6, Q8, Q9 × 3, Q7 × 3, Q11, Q12, Q11 × 2, Q3 × 3, Q10, Q13 × 3 | Loose, Sidestep, Aimed Shot, Snare Shot, Split Shot, Arrowfall: 6 |
| Quarry 21/Veil 9 | Same Quarry order through Q12 (21); V1, V2 × 4, V4, V6, V3 × 2 (9) | Bladecraft, Sidestep, Aimed Shot, Snare Shot, Split Shot, Arrowfall, Opening, Parry: 8 |
| Pure Veil 0/30 | V1, V2 × 4, V4, V6, V7 × 3, V3 × 2, V8, V9 × 3, V10 × 3, V3, V12, V5 × 3, V11 × 3, V13 × 3 | Bladecraft, Sidestep, Opening, Parry, Flourish, Close Dance: 6 |
| Veil 21/Quarry 9 | Same Veil order through V12 (21); Q1 × 4, Q4, Q2 × 3, Q3 (9) | Bladecraft, Sidestep, Opening, Parry, Flourish, Close Dance, Aimed Shot: 7 |
| Mixed 15/15 | Q1 × 4, Q4, Q2 × 3, Q5 × 3, Q6, Q8, Q9 × 2 (15); V1, V2 × 4, V4, V6, V7 × 3, V3 × 2, V8, V9 × 2 (15) | Bladecraft, Sidestep, Aimed Shot, Snare Shot, Split Shot, Opening, Parry, Flourish: 8; neither ultimate |

The optional universal Strike remains available in every row, adding one to
the listed class-repertoire count: total catalogue sizes are 7, 7, 9, 7, 8
and 9 respectively. It supplies no additional damage stream or required slot.

The first pure Quarry sample keeps Q11 at rank 1 to maximize Q10 utility.
The follow-up sample instead buys Q11 rank 3 and Q10 rank 1: more reward
for the Aimed Shot → Loose sequence, less Sidestep mana economy. Both use
exactly 30 points and unlock the same six skills.

Cross-tree purchase orders may be interleaved without changing their within-tree
order. A hybrid choosing 9 utility points before a 21-point core gets its ultimate
at 60, not 42. Two ultimates require at least 42 points and cannot coexist.

| Use | Equipped loadout, counting basic and ultimate | Deliberate omission |
|---|---|---|
| Pure Quarry ordinary solo | Loose, Sidestep, Aimed Shot, Snare Shot, Arrowfall: 5 | Split Shot for groups |
| Pure Quarry group pressure | Loose, Sidestep, Aimed Shot, Split Shot, Arrowfall: 5 | Snare; optional sixth |
| Quarry compact | Loose, Sidestep, Aimed Shot, Arrowfall: 4 | Both spread/control skills; still blade fallback |
| Pure Veil solo | Bladecraft, Opening, Parry, Sidestep, Close Dance: 5 | Flourish; optional sixth for groups |
| Veil compact duel | Bladecraft, Opening, Parry, Close Dance: 4 | Sidestep; less recovery from errors |
| Mixed generalist | Bladecraft, Aimed Shot, Snare Shot, Opening, Parry, Flourish: 6 | Sidestep/Split Shot remain catalogue options |

The basic's alternate action is explicit, not another hotbar slot or damage
stream. Ordinary viability never assumes casting everything in the catalogue
or rotating A/B to add off-bar cooldowns. Combat switching remains a shared
open decision; inspect that incentive before approving implementation.

## 8. Cadence, resource and ammunition sanity checks

Old untalented full draw produces 2.25 R/2.5 s = 0.90 R/s before movement losses.
New Loose gives 0.95 R/0.85 s ≈ 1.118 R/s: about 24% higher raw throughput and a
much faster first response. It is not the old full-draw hit fired three times
as often. At the equal-ilvl level 60 comparison above this is ≈ 0.967 Mage Spark D/s;
at level 12 ≈ 1.018 D/s, before talents, differences in mitigation and starter equipment.
That is an initial soft comparison, not a mandatory equality or fitted target.

For a paired bow/blade comparison, the actual catalog defines a 1H sword
interval of 1.0 s and a dagger interval of 0.7 s; the dagger weapon-damage
factor is 0.7, rounded after the common weapon curve
(`mods/ITEMS/grug_gear/init.lua:242–260`). At level 60 and item level 60,
the sword/bow weapon damage is 25 and the dagger damage is 18. With natural
Dexterity 128 and no attribute gear, their numerators are 37.8 and 30.8.
The following ordinary sustained attacks assume uninterrupted melee contact,
no affix speed, no crit and no specials; the same scalar S applies to all.

| Stream | Untalented pre-mitigation damage per second | With its four-rank damage talent |
|---|---|---|
| Loose bow | 0.95 × 37.8 / 0.85 = 42.25 S, or 1.118 R/s | 50.70 S, or 1.341 R/s |
| 1H sword | 37.8 / 1.0 = 37.80 S, or 1.000 R/s | 49.90 S, or 1.320 R/s |
| Dagger | 30.8 / 0.7 = 44.00 S, or 1.164 R/s | 58.08 S, or 1.537 R/s |

Here sword M equals R; dagger M is only about 0.815 R. Dexterity adds once
per landed hit, so the faster dagger can lead sustained melee despite its
smaller weapon hit. Opening and Flourish use that smaller M, and approaching
a target, defending and losing contact reduce actual melee uptime. Bow has
range and ammunition cost. These are useful differences, not a mandate for
identical throughput. Compare complete encounters and mana expenditure before
changing weapon-family curves or assuming the blade identity is underpowered.

Fine Edge deliberately reaches 32%, while Bowcraft reaches 20%. A blade
specialist must be rewarded for maintaining contact in leather without healing,
not merely perform adequately as a ranged fallback. At full V2, an Opening
prepared by Parry with V10 rank 3 deals 1.80 × 1.32 + 0.30 = 2.676 M;
a front Opening without that preparation deals 1.35 × 1.32 = 1.782 M.
The corresponding dagger hits remain only about 0.815 of the sword's at
this item level. Daggers lead ordinary contact throughput; swords have larger
cooldown-limited hits. V9, V10 and V13 additions remain additive, not amplified
by V2. A 21/9 Quarry hybrid can buy this blade bonus but pays nine points
that cannot also deepen its bow talents; shared recovery forbids free weaving.
This is an intentional proposal, not proven parity with Ruin or another class.
Compare sword and dagger solo clears, incoming damage and downtime separately
at starter, middle and final levels; adjust if Veil is both slower and less safe.

An untalented 6.75 s ideal cycle using one Aimed Shot spends 1.35 s on 1.80 R,
leaving 5.40 s for about 6.35 ordinary arrows in a long averaged sequence:
roughly 7.84 R/6.75 s ≈ 1.16 R/s. The real discrete trace must include first release,
recovery and cooldown start; adding Aimed Shot on top of all Loose shots is
wrong. Bowcraft rank 4 adds 20% to those original hits, not a second damage stream.
Arrowfall now deals 4 × 1.60 R over 3 s: about 2.13 R/s before talents.
With Q1 rank 4 and Q13 rank 3, each arrow deals 1.60 × 1.20 + 0.12 =
2.04 R, or 2.72 R/s over the occupied 3 s. Even at the 0.65 s bow cadence
floor and 30% crit, talented Loose averages 1.14 / 0.65 × 1.30 ≈ 2.28 R/s.
The complete volley retains a damage premium there, with 4 arrows, 16% P
paid per shot, a 60 s cooldown and a vulnerable commitment. More forgiving
tracking and partial payment need new comparisons for interrupted volleys;
the complete-volley arithmetic is unchanged. Burst balance still needs future
GUI playtesting; these arithmetic examples do not establish PvP fairness.

A pure Veil may land Opening every 8 s for 5% P; Parry every 12 s costs 4% P;
Sidestep every 18 s costs 6% P. Together ≈ 1.29% P/s before costs reductions.
Combat mana recovery at level 60 is ordinarily 0.25% maximum mana/s. Repeating every
cooldown therefore exhausts mana; no claim of permanent sustain is made.
Aimed Shot every 6.75 s alone costs about 0.89% P/s. Bow/basic blade remain available at zero
mana; defense becomes a deliberate expense. Potions/food keep their existing
rules, and no mandatory mana-recovery skill is added.

A 0.95 R arrow needs about 2.37 times the ammunition of a 2.25 R full draw for the
same raw target HP. Faster tempo materially changes the economy even though
recipes stay unchanged. Keep 200 starter arrows, 500 quiver capacity and existing
100-arrow recipes/stock in this first proposal; Quiver is optional relief,
not a required tax. Before approval, compare arrows and copper per ordinary
kill at levels 1/6/14/26/42/60 against income and actual starter weapon damage.
If buying ammunition becomes oppressive, propose an explicit batch/price
adjustment for approval; do not silently grant free arrows or hide a refund.

## 9. Growth, PvP and boundaries

At creation: immediate bow feedback, basic blade fallback and one dodge window.
At level 2: Veil can change its basic action identity; Quarry improves its shot.
At level 6: Aimed Shot or Opening adds a meaningful attack choice.
At level 14: Snare or Parry changes how the player survives a closing enemy.
At level 26: spread arrows or close cone damage adds a new encounter capability.
At level 34: follow-up payoff or slow-clearing choice deepens the chosen style.
At level 42 earliest: a visibly bounded ultimate; 30 final points leave omissions.
These are earliest available purchases, not a promise that every sample order
buys every milestone immediately. Mixed builds exchange earlier specialization
for broader responses. Test lower-level return visits and equal-level fights.

Quarry pays for range with ammunition and deliberate aiming; it has no heal,
root, permanent speed buff or invulnerability. Snare lasts 3 of 14 seconds and
cannot make a melee opponent permanently slow by itself. Sidestep adds no
movement. An enemy that reaches the Scout forces a real blade/defense choice.
Veil stays visible, in leather and mostly at 3 m. Parry invites an opponent to
wait 2–2.75 s, use area/periodic damage, turn to deny rear Opening, or force the
guard before committing. A guaranteed front Opening is weaker than its setup.
Close Dance grants no chase speed; opponents can disengage or use control.
Neither spec gains an automatic behind-target teleport or repeated gap closer.

**Cover discrepancy to resolve explicitly:** combat_stats.md's “Hostile casts
and projectiles” says current homing shots ignore intervening terrain after
launch; cover protects before launch only. The handoff's Mage “projectile
cover” wording must not be read as an implemented interception contract.
This Scout candidate retains that actual baseline: Aimed Shot is answerable
before release, Arrowfall between releases, but an already fired arrow is not
sidestepped or blocked by newly reached terrain. Snare has only 0.18 s warning,
so its counterplay primarily means pre-existing cover/range and its long gap.
Post-launch cover would be a separately approved shared projectile revision.

All acquired targets and impacts pass current PvP permission; no skill changes
a player's flag. Multiple Scouts' slow follows the proposed common strongest
rule; coordinated uptime still requires group PvP assessment. No wall/floor
piercing on Split Shot/Flourish: each acquisition uses the shared aim/cover
seam. No world nodes change; terrain remains intact. No offscreen target memory.

## 10. Questions before implementation, not claimed engine facts

- Can the authoritative input machine expose the basic's RMB attack while
 preserving interaction, pickup and eating consistently on desktop and web?
- How should native melee readiness compose with the proposed cross-weapon
 reservation, including affix changes, broken gear, cancellation and latency?
- Can existing action receipts reserve a four-release channel atomically and
 retire unpaid/unreleased projectile reservations without leaks or duplication?
- Can one Parry trigger be placed consistently after dodge but before absorb
 for melee, direct spells and arrows, including a hit that kills its source?
- How will a stationary monster face its target during rear-cone evaluation?
 Parry must remain the ordinary solo setup if circling is not reliably useful.
- Is Arrowfall sufficiently distinct against crit-heavy normal shooting, and are faster
 arrows affordable? These are numerical/feel risks, not implementation facts.
- Use at most 8 brief particles per ordinary shot, 24 per special, 32 concurrent
 per ultimate instance; lifetime ≤0.4 s. Repeated arrows are bounded entities.
 Measure simultaneous Scouts against the shared web budget, not per-caster
 budgets alone. Reuse existing art/sounds only where already approved.
- Eventual proof needs action/ammo traces, damage and cost comparisons, PvP
 adversarial cases and desktop/web GUI playtests; none was run for this proposal.
