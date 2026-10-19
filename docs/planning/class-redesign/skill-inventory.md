# Class redesign: skill inventory under the 2026-10-19 rulings

Planning record, 2026-10-19. Every active skill and every talent with a
mechanic of the four candidates, mapped onto a small set of building blocks
under the user's "maximally simple" rulings
([continuation §4a](continuation.md#4a-user-rulings-of-2026-10-19-a-maximally-simple-rework)).
The candidates keep their direction and numbers where nothing here changes
them; this file wins where it adapts them. Numbers below are paper values,
not tuning. Documentation only: nothing in the game changes.

Prepared by four read-only class agents and consolidated by the coordinator.
Code claims that decide a building block were spot-checked (root timers,
shipped rage scaling, the status modifier keys).

## 1. Result in one table

| Class | Active skills | Kept | Adapted | Redesigned | Cut | New building blocks |
|---|---:|---:|---:|---:|---:|---|
| Mage | 11 | 5 | 4 | 2 (both ultimates) | 0 | none |
| Warrior | 11 | 8 | 3 | 0 | 0 | none |
| Priest | 10 | 3 | 6 | 1 (Haven, M6) | 0 | none |
| Scout | 11 + Sprint | 4 | 5 | 2 (Arrowfall, Parry) | 0 (Sprint open) | none |

No class needs a mechanic outside the list in section 2. Of roughly 110
talents, about 60 are plain number modifiers; the rest unlock a skill,
transform one or open a readiness window.

## 2. Building blocks

| Id | Block | State in the code | Used by |
|---|---|---|---|
| B1 | Instant cast + cost + cooldown | exists | all |
| B2 | Per-skill occupied time after the cast | one-way shared action boundary exists (`strike_delay.lua`: casts delay melee); per-skill value and the reverse direction are new, small | all; see question 7 |
| B3 | Projectile at the crosshair target, optional impact splash | exists (Fireball splash loop) | Mage, Scout, Priest's free attack |
| B4 | Instant self-centred circle or facing cone | exists as plain spheres (Nova) and a cone with LOS (mob telegraph) | all |
| B5 | One-shot area at the crosshair point, fixed delay, particle warning | anchor from the ray exists (Cinderfall); the delayed impact exists only inside the dragon AI, so a small scheduled callback is new | Meteor, Fire Rain, Winter Field, Censure |
| — | Shared area query: radius + vertical band + line of sight from the anchor | extension of B4/B5 (today's spheres have no LOS); continuation §4 item 1 | B4, B5 |
| B6 | Player status: modifiers, optional tick (HoT), absorb | exists (`grug_core.set_status`, `add_absorb`); no `dodge_percent` key (stats already read it; one line if ever needed) | Mend, Haven, Ice Armor, Unbroken, Parry, Close Dance |
| B7 | Mob control: slow, root, stun | exists; **roots are plain timers and do not break on damage** (the engineering review's pointer was wrong); the inventory uses fixed roots | Mage, Warrior, Scout |
| B8 | Readiness window "next attack empowered" with status icon | exists for talents; a few new window keys | Cold Shock, Retort, Ruination, Clear Conscience, Opening |
| B9 | Transformation in place on A and B, shared cooldown key | rule decided (Round 50 ruling 12); per-class basic attack replacing the universal Strike is new, small | Cold Spark, Nova, Retort, Bellow, Broadstroke, Bladecraft |
| B10 | Numeric modifier talents | vocabulary exists | all |
| B11 | Actual-HP-removed receipt | new, small | Word of Ruin only (Warrior avoids it with a flat Recover) |
| — | Automatic group recipients (filter, cap, lowest HP first) | new, small helper; `grug_parties.view` has no range/LOS filter | Hearten, Haven |
| B12 | Damage over time on mobs | does not exist | **not needed by any class** |

**Removed from the foundation** compared with the engineering review: the
preparation/charge owner, pulsed areas, the area preview, incoming-hit
classification, projectiles at explicit secondary targets, the fake clock for
preparations and mob DoT. **Savings:** today's Scout bow draw (about 300
lines in `scout.lua` plus the Loose special cases in `input.lua`) is deleted.

**Kept large item:** the graph talent registry, its validator and the new
Talents page (one inner tab per tree, background image with connection lines
and graphic elements, one icon per talent). Art volume: about 8 tree
backgrounds, about 80 unique talent icons (unlock nodes can show their
skill's icon), about 30 new skill icons and the element overlays for the
weapon effect.

## 3. Cross-class questions — decided

**The user accepted all ten recommendations on 2026-10-19.** They are binding
for the plan; the "Recommended" marks below are the decisions.

1. **Meteor and Fire Rain** are now the same mechanic. Keep both and separate
   them by scale (Meteor 1.4D / 3 m / 18 s; Fire Rain about 2.5D / 5 m /
   60 s, showier)? *Recommended.*
2. **Arrowfall:** one volley of 4 arrows together at the crosshair target, or
   an arrow rain on a point (B5)? *Recommended: the volley; the rain overlaps
   Split Shot.*
3. **Group heals** (Hearten, Haven): any friendly player in range, or party
   only? *Recommended: any valid friendly player as shipped Hearten does, self
   always included, cap 4/5, lowest HP first.*
4. **Retort** readies on a hostile hit that actually removed HP (no dodge, no
   fully absorbed hit); **Recover** becomes a flat heal per landed Retort.
   *Recommended: both.*
5. **Parry** opens its Opening window at the cast, plus a short absorb shield,
   without detecting hits. *Recommended.*
6. **Sprint:** keep unchanged (no work) or remove as the candidate proposed.
   *Recommended: keep.*
7. **One action-clock rule for everyone:** every swing and cast respects the
   current occupied time in both directions, with per-skill values
   (casters about 1 s, heavy hits and ultimates 1.5–2.5 s, self buffs about
   0.25–0.35 s). *Recommended; it also stops Bladecraft weaving two damage
   streams.*
8. **Word of Ruin** recovery: build B11 for it alone, or cap it by pool only.
   *Recommended: pool cap only, unless a second user appears.*
9. **Winter Field over Ice Cage** as the Rime ultimate. *Recommended.*
10. **Retired shipped talents** without a candidate equivalent (Spite,
    Affront, Grudge, Tendon Cut, Pinning Shot, Fletching and others) and the
    Shelter node: drop them in the migration. *Recommended.*

Smaller class questions (Broadstroke side targets may crit, Ruination as a
plain +15 % multiplier, Hard Faith as paid-spell damage instead of crit,
Flame Lance kept as the heavy single hit, Ice Armor armor-only and renamed,
Aimed Shot at 2.2R) are listed per class below.

## 3a. Area anchor: always ground (user, 2026-10-19)

Applies to every crosshair area skill (B5: Meteor, Fire Rain, Winter Field,
Censure). It replaces the preview parts of
[ability targeting §4](../../design/ability_targeting.md#4-fixed-area-points-and-previews)
and fixes the open geometry questions of the handoff §5.9.

1. **Two ways to aim, one result.** A legal enemy under the crosshair gives
   its position *at the moment of the cast*; otherwise the terrain hit gives
   the point. The enemy is not followed afterwards.
2. **The anchor is always ground.** From that point the skill searches
   straight down for ground: the top of a walkable node with a non-walkable
   node above it, at most **H = 3** nodes below the point. The first such
   surface is the anchor.
3. **No ground, no cast.** If nothing is found within H (a flying mob high
   above the ground, deep water, aiming at a tall cave ceiling, a ray miss),
   the cast is refused **before** cost and cooldown, with the message
   "No ground found." Nothing is invented at maximum range.
4. **Damage volume:** horizontal radius R around the anchor, vertical band
   **±3** around the anchor's height, and a line of sight from a point just
   above the anchor to each target (continuation §4 item 1). Same H for the
   search and the band, so one number explains both. A flying mob inside the
   band and in sight is hit like any other target.
5. **Caves work.** The search and the band are local; nothing needs open sky.
   Falling visuals (meteor particles) start below the first solid node above
   the anchor (capped, for example 12 nodes), so they never fall through rock.
6. **Ground eligibility default:** walkable full or partial nodes count;
   liquids and non-walkable plants do not stop the search (it looks through
   them for walkable ground below, within H).

*H = 3 instead of Censure's candidate 2 m:* a mob standing on a one-node
step or jumping still finds its ground, and the band covers mobs up to about
two nodes tall standing one step above or below the anchor. Censure's 2 m
becomes 3 with the shared rule.

## 4. Classes

### 4.1 Mage (Ember / Rime)

Sources: handoff §5 amended by `mage.md` (mage.md wins), continuation §3/§4, rulings of 2026-10-19. D = untalented Fiery Spark hit, P = neutral pool, K = armor constant. "Occupied" = B2 time after the cast during which no other attack/cast starts; cooldowns start at the cast. No preparation, no pulses, no previews anywhere below.

#### Active skills
| Skill | Tree / unlock | Candidate mechanic (short) | Simplified version | Blocks | Change vs candidate |
|---|---|---|---|---|---|
| Fiery Spark | Starter (replaces Strike) | Free fire projectile, D, single target, 1 s interval, 20 m | Same; today's `fireball` def minus cost/splash (`cast_interval = 1` exists); occupied 1 s | B1, B2, B3 | kept |
| Ice Wave | Starter | 70° 5 m cone, 0.25D, 35% slow 3 s, 12 s cd, 8% P | Same, one-shot cone with LOS; slow via `grug_mobs.slow` / `set_move_modifier` | B1, B2, B4, B7 | kept |
| Fireball | Ember F4, gate 2 | Paid projectile 1.60D + 0.15D splash 2 m, 5 s cd, 6% P, 1 s occupied; Afterglow burn | Same; Afterglow already folded into a Fireball damage rank (no burn) | B1, B2, B3 (splash) | kept |
| Flame Lance | Ember F5, gate 6 | 2.20D, 1.25 s stationary prep, movement cancels, 8 s cd, 10% P | Instant heavy projectile 2.20D, 8 s cd, 10% P, then 1.5 s occupied (replaces the prep) | B1, B2, B3 | adapted |
| Meteor | Ember F8, gate 12 | Raycast anchor ≤20 m, live preview, 1.5 s warning, 1.4D r 3 m, 18 s cd, 14% P | One-shot at crosshair point ≤20 m, fixed 1.5 s delay with a few warning particles, 1.4D r 3 m; no preview | B1, B2, B5 | adapted |
| Fire Rain (ultimate) | Ember F12, gate 20 | 1 s warning, then 5 pulses × 0.55D, r 4 m, 60 s cd, 22% P | One big meteor shower at crosshair point ≤20 m: 1.5 s delay + warning, single hit ~2.5D, r 5 m, 60 s cd, 22% P, 1.5 s occupied | B1, B2, B5 | redesigned |
| Cold Spark | Rime R1, gate 0 | Transforms Fiery Spark: free frost projectile D, 12% slow 1.5 s refresh-only | Same; replaces Spark in place on A/B, shared interval key; slow on settled hit | B3, B7, B9 | kept |
| Blink | Rime R4, gate 2 | 10 m teleport, 20 s cd, 8% P | Same (shipped `blink`, cooldown 15 → 20 s) | B1 | kept |
| Ice Armor (rename pending) | Rime R7, gate 6 | +0.20K armor 6 s; landed hostile melee hit slows attacker 20% 2 s; 24 s cd, 10% P | Armor status only (+0.20K, 6 s, 24 s cd); reactive melee slow cut (needs hit classification, ruling 4) | B1, B6 | adapted |
| Ice Nova | Rime R9, gate 12 | Transforms Ice Wave: 0.65D r 5 m, 1.75 s root that breaks on later damage, 18 s cd, 10% P | Same hit; plain fixed 1.75 s root (no break-on-damage, see Q3); shared cooldown key with Ice Wave | B1, B2, B4, B7, B9 | adapted |
| Winter Field (ultimate) | Rime R13, gate 20 | Anchor ≤15 m, 0.75 s warning, 6 pulses × 0.15D, 35% slow while inside, r 4 m, 60 s cd, 18% P | One-shot at crosshair point ≤15 m: 1 s delay + warning, ~1.0D + 40% slow 5 s on each target hit, r 4 m, 60 s cd, 18% P | B1, B2, B5, B7 | redesigned |

#### Talents with mechanics
| Talent | Tree | Candidate effect | Simplified version | Blocks |
|---|---|---|---|---|
| Unlocks F4, F5, F8, F12, R4, R7, R13 | Both | Grant Fireball, Flame Lance, Meteor, Fire Rain, Blink, Ice Armor, Winter Field | Grant the skill into the catalogue; nothing auto-placed (round 50 ruling 12) | B1 |
| R1 Cold Spark | Rime | Replaces Fiery Spark on all hotbar representations | In-place replacement on A and B, shared interval key | B9 |
| R9 Ice Nova | Rime | Replaces Ice Wave, same button | In-place replacement, shared cooldown key (no reset when bought mid-cooldown) | B9 |
| R10 Cold Shock | Rime | Nova that hits an enemy empowers next Cold Spark within 4 s by +0.25/0.50/0.75D; one charge | Same: readiness window with status icon, consumed by next Cold Spark | B8, B10 |
| F7 Afterglow | Ember | Fireball target burns 0.05/0.10/0.15D over 3 s (mob DoT) | Already folded: Fireball primary damage +0.05/0.10/0.15D (no B12) | B10 |
| R8 Thick Ice / R14 Lasting Armor | Rime | +0.04/0.08/0.12K armor / +0.5/1.0/1.5 s on Ice Armor | Unchanged numbers on the B6 status; reactive part gone, so they scale armor only | B6, B10 |

14 further talents are plain B10 modifiers: F1 Fire Mastery, F2 Measured Fuel, F3 Far Cast, F6 Heat Focus, F9 Wide Ember, F10 Broad Impact, F11 Controlled Burn, F13 Spreading Rain (now radius only, no pulses), R2 Mana Reserve, R3 Keen Cold (Cold Spark +0.03/0.06/0.09D, slow stays 12%), R5 Clear Thought, R6 Quick Step, R11 Returning Cold (shared Wave/Nova cooldown key), R12 Far Frost. Rank counts and graph (32 Ember / 33 Rime ranks, 27 nodes) need no change.

#### Open questions for the user
1. **Meteor vs Fire Rain now share one mechanic** (delayed one-shot circle). Recommendation: keep both, separated by scale only: Meteor 1.4D / r 3 m / 18 s as the repeatable group tool, Fire Rain ~2.5D / r 5 m / 60 s as the large, showy shower.
2. **Flame Lance without preparation is "a bigger Fireball without splash".** Recommendation: keep it (cheap: one projectile def) as the heavy single-target hit, priced by 8 s cd + 1.5 s occupied and a faster projectile; cut it only if Ember needs fewer buttons.
3. **Breakable root does not exist in code.** Mob root (`grug_mobs.root`) and player root (`set_root`) are plain timers; nothing clears a root on damage (the engineering review's pointer is wrong). Recommendation: use a plain fixed 1.75 s Nova root (already far milder than the shipped 4 s unbreakable root) and add no new block.
4. **Winter Field vs Ice Cage** (still open, continuation §3). Recommendation: Winter Field as the one-shot above; drop Ice Cage, since node placement, push-out and destructible blocks are exactly the expensive one-off mechanics ruling 4 cuts. If Winter Field feels weak as an ultimate, add a short stun (~1 s, B7) rather than a root.
5. **Ice Armor's reactive slow is cut** (needs melee hit classification). Recommendation: armor-only status and rename it (continuation §5.4, e.g. "Rime Mantle"). Do not compensate with a cast-time chill circle because it would overlap Ice Wave/Nova.
6. **Occupied-time rule for Blink and Ice Armor (M4).** Recommendation: one uniform rule. Every Mage skill respects the current occupied time, and Blink/Ice Armor add no occupied time themselves. The worst wait is then ≤1.5 s after a Lance or ultimate, and no exemption flag is needed.

#### New building blocks needed
None. Notes: (a) B4/B5 should share one area helper (radius + vertical band + node LOS from the anchor, continuation §4.1). Today Nova and Cinderfall use plain spheres without LOS, so this extends existing blocks. (b) B5's delayed impact exists only inside the dragon AI (`boss_dragons.lua:593-609, 716-720, 831`); the player version is a small scheduled callback that rechecks the target at impact. (c) B12 (mob DoT) is not needed because Afterglow is folded. (d) B11 is not needed. (e) A break-on-damage root would be NEW; avoided by Q3.

### 4.2 Warrior (Bulwark / Ruin)

Basis: `docs/planning/class-redesign/warrior.md` (candidate), adapted to the 2026-10-19 rulings. S = the Warrior's ordinary full Strike, P = level pool. M2 (rage per hit scales with weapon speed) has **already shipped** (Round 46 ruling 9: `grug_abilities/init.lua:93-114`, `swing_rage` = (8 + Stoke) × base swing interval / 1.0 s), so the candidate's rage ledger stays valid per second for every weapon. Every self cast below uses 0.35 s occupied time (B2) instead of today's rule, where a cast pushes the next swing by the full weapon interval (`strike_delay.lua`).

#### Active skills
| Skill | Tree / unlock | Candidate mechanic (short) | Simplified version | Blocks | Change vs candidate |
|---|---|---|---|---|---|
| Strike | Starter | Free 3 m swing at weapon cadence, S damage, +8 rage × interval | Unchanged shipped swing (`kits.lua` strike_def) | existing swing | kept |
| Charge | Starter | 12 m dash, 0.12 base hit, +15 rage, 0.75 s stun, 10 s cd | Shipped dash (`charge.lua`); stun 1.5 → 0.75 s is a number change | B1, B7 (stun) | kept |
| Retort | Bulwark B1 (gate 0), replaces Strike | Hit or dodge (melee/projectile, not DoT/ground) readies next Strike +0.25S within 4 s; 1 charge, 6 s ICD | Readied by `register_on_settled_incoming_hit` (a non-lethal hostile hit that removed HP); no dodge trigger, no fully absorbed trigger, no hit classes; status icon; consumed by next landed Retort swing | B9, B8, B10 | adapted |
| Hold Ground | Bulwark B4 (gate 2) | Self cast, 25 rage, 24 s cd, absorb 0.12P for 5 s, no immunity | As candidate: `add_absorb` once, drop shipped root/slow immunity | B1, B2, B6 (absorb) | kept |
| Taunt | Bulwark B7 (gate 6), leaves base kit | Single-target mob taunt, 8 m, free, 8 s cd, 3 s attention | Shipped Taunt (`grug_core.taunt`), now talent-gated | B1, B2 | kept |
| Bellow | Bulwark B9 (gate 12), replaces Taunt | 6 m self-centred area taunt, same cd | One-shot self-centred circle (shipped `taunt_radius` loop) | B9, B4 | kept |
| Unbroken (ultimate) | Bulwark B12 (gate 20) | Self cast, 25 rage, 60 s cd: +0.50K armor 8 s + 0.15P absorb expiring with it | One `set_status` armor modifier + one `add_absorb`, both 8 s; delete shipped passive ×1.65 and low-HP proc (`talents.lua` unbroken) | B1, B2, B6 | kept |
| Mighty Blow | Ruin U1 (gate 0), leaves base kit | 25 rage swing proc, 1.45S, no own cd; plain swing when unaffordable | Shipped swing-kind proc (`kits.lua` mighty_blow), coefficient change | existing swing proc, B10 | kept |
| Broadstroke | Ruin U7 (gate 6), replaces Mighty Blow | Same primary; ≤2 others in forward 100° 3 m arc take 0.35S; LOS; secondaries no crit/rage/procs | Shipped cleave loop narrowed to facing arc, 2 nearest, LOS (telegraph cone helper); no-rage/no-proc are free (ability damage grants neither); secondaries may crit | B9, B4 | adapted |
| Hamstring | Ruin U4 (gate 2) | 10 rage swing proc, normal S, 8 s proc cd, 35% slow 3 s | Shipped proc (`kits.lua` hamstring), charge 6 → 8 s, slow numbers; Tendon Cut root gone | existing swing proc, B7 | kept |
| Ruination (ultimate) | Ruin U12 (gate 20) | Self cast, 20 rage, 60 s cd, 8 s: swing damage +15% of untalented term, +2 rage per landed primary swing | Self cast starts the talent window (as Hold Ground does today); windowed keys: swing damage +15% (multiplier, no "untalented" bookkeeping), +2 rage per landed swing | B1, B2, B8, B10 | adapted |

#### Talents with mechanics
| Talent | Tree | Candidate effect | Simplified version | Blocks |
|---|---|---|---|---|
| Retort (B1) | Bulwark | Transform Strike; readiness from hit or dodge, 6 s ICD | Transform in place; readiness only from HP-removing hostile hits (settled-hit hook); ICD via `talent_trigger_ready` (1 s resolution is fine at 6 s) | B9, B8 |
| Recover (B8) | Bulwark | Landed Retort heals 10/20/30% of actual HP removed, cap 0.02P × F | Landed Retort heals a flat 0.007/0.013/0.02P × F, no crit (`heal_player` no_crit); no damage receipt, which also fixes the dead ranks 2–3 | B8, B10 |
| Bellow (B9) | Bulwark | Taunt becomes 6 m area taunt | Transform in place, one-shot circle | B9, B4 |
| Halt (B11) | Bulwark | Charge arrival adds 20/25/30% slow for 2 s after the stun | Apply the slow on arrival for stun + 2 s (mob slow clock already runs during stun) | B7 |
| Broadstroke (U7) | Ruin | Transform Mighty Blow; arc cleave of 2 | See actives; shared cooldown key not needed (no cd) | B9, B4 |
| Finisher (U10) | Ruin | MB/Broadstroke primary +0.08/0.16/0.24S vs target below 30% HP | Read target HP before the proc; conditional damage add | B10 (conditional) |

16 further talents are plain B10 modifiers: Ironbound, Weathered, Measured Answer, Turn the Edge, Layered Guard, Gather Yourself, Enduring Stand, Heavy Hand, Stoke (existing `rage_per_swing_add`), Keen Edge, Onset, Follow Through, Clean Cut, Relentless, Long Fury, Reach the Fight; the 6 unlock talents (Hold Ground, Taunt, Unbroken, Mighty Blow, Hamstring, Ruination) are covered under Active skills.

#### Open questions for the user
1. **Retort trigger:** a hostile hit that actually removed HP readies it. Dodged hits and hits fully absorbed by Hold Ground/Unbroken do not; ranged and mob area hits do. *Recommend: yes. This is the settled-hit hook with no classification, and the 6 s ICD caps it anyway.*
2. **Recover:** a flat heal per landed Retort (≈0.7/1.3/2% P) instead of a percentage of the actual HP removed. *Recommend: flat. The 2% cap binds almost always anyway, it removes the need for B11 for the Warrior, and it fixes the dead ranks.*
3. **Ruination form:** a plain +15% swing-damage multiplier plus +2 rage per swing for 8 s, instead of "+15% of the untalented term". *Recommend: the multiplier. Fallback with zero new keys: a `crit_percent` status modifier, but the candidate deliberately moved away from crit.*
4. **Broadstroke secondaries:** let them crit, because `deal_ability_damage` has no no-crit option today. *Recommend: allow crit. Keep the 2-target cap and LOS, which use existing helpers.*
5. **Self-cast occupied time:** use 0.35 s (B2) for Hold Ground, Taunt/Bellow, Unbroken and Ruination, or keep today's "a cast costs one weapon interval". *Recommend: 0.35 s if B2 is built for the casters anyway. Otherwise today's rule is zero work for the Warrior.*
6. **Retired shipped talents with no candidate equivalent:** Spite (rage per hit taken), Affront (threat ×), Grudge (Taunt cd) and Tendon Cut (Hamstring root). *Recommend: drop them as the candidate does; Spite stays out because it turns extra attackers into a rage battery.*

#### New building blocks needed
none. Small items inside the existing blocks:
- Retort is a warrior-class def that substitutes the universal Strike (B9; `register_ability` asserts class XOR universal).
- One windowed swing-damage key and one windowed rage key for Ruination (B8/B10).
- Broadstroke's arc filter reuses the telegraph cone helper (B4).
- B11 and B12 are not needed for the Warrior.

### 4.3 Priest (Mercy / Reckoning)

Basis: `priest.md` candidate, adapted to the 2026-10-19 rulings. P = class-neutral base pool,
Q = support factor, W + I = spell term. Default occupied time after any cast is 1 s (the
candidate's action interval); only deviations are listed. "H1" marks support values pulled
back toward the shipped kit (shipped: Heal 25% P / 4 s, Shield 25% P for 15 s / 10 s,
Mend 4 x 8% P / 8 s; `kits.lua:853-1019`, `classes.md` §5).

#### Active skills
| Skill | Tree / unlock | Candidate mechanic (short) | Simplified version | Blocks | Change vs candidate |
|---|---|---|---|---|---|
| Smite | Starter (replaces Strike for Priests) | Free 20 m current-aim hit W+I, 1 s action interval | Same: free instant crosshair hit, `cast_interval` 1 s (exists); per-class basic instead of universal Strike is the shared A12 rule | B1 | kept |
| Heal | Starter | 1.5 s stationary prep, retained recipient, 20% P x Q, 6 s cd | Instant; crosshair ally else self (`resolve_friendly_target`, exists); H1: ~25% P x Q, cd ~5 s, occupied 1.5 s; no crit (`no_crit`, exists) | B1, B2 | adapted |
| Shield | Mercy M3 | Instant absorb 18% P x Q for 6 s, cd 14 s, same-caster replace | Instant absorb on crosshair ally/self; H1: ~22-25% P x Q for ~10 s, cd ~12 s; absorb id is per target, so any recast replaces (simpler than per caster) | B1, B6 | kept (numbers H1) |
| Mend | Mercy M6 | 4 ticks at +3..+12 s, 4% P x Q each, same-caster refresh | One cast puts a `mend` status with on_tick on the target (replaces the `mends` globalstep table); H1: 4 ticks x 6-8% P x Q every 3 s; newest cast replaces; cleared on death/leave by status.lua | B1, B6 | adapted |
| Hearten | Mercy M10 | 1.5 s prep, self + up to 3 party within 6 m, 10% P x Q each, injured first | Instant self-centred heal: self + friendly players within ~6 m, cap 4, lowest HP fraction first; H1: ~15% P x Q each; occupied 1.5 s | B1, B2, B4, PS | adapted |
| Haven (new Mercy ultimate) | Mercy M13, ultimate | 1.5 s prep, 10% absorb + 10% heal to self + 3 party (no solo value, M6) | One-shot self-centred circle (~8 m) puts a `haven` HoT status on every friendly player hit (cap 5 incl. self); e.g. 6 ticks x ~7% P x Q every 2 s, keeps ticking outside the circle; separate status id, so it stacks with Mend; cd 60 s, occupied 1.5 s | B1, B2, B4, B6, PS | redesigned (M6, ruling 3) |
| Rebuke | Reckoning R3 | Instant 20 m hit 1.8(W+I), 6% P, cd 6 s | Unchanged | B1 | kept |
| Word of Ruin | Reckoning R6 | 0.75 s prep, 1.6(W+I), self-heal min(6% P x Q, 50% actual HP removed) | Instant crosshair hit, same damage; self-heal on the actual-HP receipt, cap unchanged; cd 16 s | B1, B11 | adapted |
| Censure | Reckoning R9 | 0.75 s prep + live preview + 0.75 s warning, r 3 m, max 4 hostiles, 1.2(W+I) | Instant; anchor = crosshair point at cast (Cinderfall ray, exists); fixed ~0.75 s delay with a few warning particles, then one hit: r 3 m, +-2 m band, LOS from anchor (§4.1), 4 nearest; no preview | B1, B5 | adapted |
| Final Word | Reckoning R13, ultimate | 1.5 s visible prep, 2.8(W+I), cd 60 s | Instant crosshair hit, same damage; occupied 1.5 s instead of the prep (PvP loses the visible wind-up tell) | B1, B2 | adapted |

#### Talents with mechanics
| Talent | Tree | Candidate effect | Simplified version | Blocks |
|---|---|---|---|---|
| M1 Steady Word + R1 Sharpened Word | Mercy / Reckoning | Smite +0.15B / +0.12B, additive (M3: pure Reckoning is a trap) | Same value per rank on both (e.g. +0.05/0.10/0.15B) on one shared effect key read as max, not sum, so a hybrid gains nothing from the second | B10 (max-combine on one key) |
| M8 Clear Conscience | Mercy | After Heal/Shield/Mend, next Smite within 5 s +0.10/0.20/0.30B; ICD 8 s | Unchanged: talent window started on cast, consumed by Smite, status icon (`try_trigger_talent_window`, exists) | B8 |
| M12 Shelter | Mercy | Armor on Shield recipient while own Shield holds | Cut: folded into M5 Warding Faith's absorb share (continuation §4.7); node removed from the graph | -- |
| M14 Lasting Haven | Mercy | Haven absorb lasts 7/8/9 s | Retargeted to the new Haven: +1/2/3 HoT ticks (`duration_add:haven`) | B10 |
| R7 Resolute Word | Reckoning | Recovery ceiling 7/8/9% P, actual-HP cap stays | Unchanged; only meaningful with the B11 receipt | B10, B11 |
| R8 Hard Faith | Reckoning | +2/4/6 crit on paid direct Priest spells only (needs per-call crit add, not existing) | Redesigned as paid-spell damage +3/6/9% (`damage_pct:paid`), no crit plumbing; Smite untouched as intended | B10 |

13 further talents are plain B10 modifiers: M2 Measured Care, M4 Gentle Hand, M5 Warding Faith (absorbs Shelter's value), M7 Patient Care, M9 Deep Reserve, M11 Quiet Care, R2 Measured Judgment, R4 Firm Rebuke, R5 Long Reach, R10 Broad Judgment, R11 Deep Resolve, R12 Press the Verdict, R14 Unfinished Sentence. The eight unlock nodes (M3, M6, M10, M13, R3, R6, R9, R13) have no logic of their own and are covered in the skills table; M13's "Hearten teaches group selection" is dropped.

#### Open questions for the user
1. **Who do group heals reach?** Party only, or any friendly player in range (shipped Hearten splash uses `valid_target` friendly, faction-wide)? Recommendation: any valid friendly player (existing check, no party lookup; `grug_parties.view` has no range/LOS filter), self always included, cap 4 (Hearten) / 5 (Haven), lowest HP fraction first, engine `core.line_of_sight` for cover.
2. **Haven shape:** self-centred instant circle or a crosshair area with delay (B5)? Recommendation: self-centred (B4); always hits the caster, so it has solo value (M6), and Mercy needs no B5.
3. **Word of Ruin recovery cap:** build B11 (actual HP removed, shared with Warrior Recover) or keep the shipped rule (50% of pre-mitigation damage, now capped at 6% P x Q per cast)? Recommendation: B11 if Warrior builds it anyway; otherwise the pool cap alone already bounds farming at 16 s cooldown.
4. **Censure without B5:** if B5 is not built for the Mage, should Censure become a Fireball-like projectile with impact splash (B3, no delay)? Recommendation: keep B5 (shared with Mage areas); B3 splash is the fallback, not the plan.
5. **Priest HP factor 0.8 (was 1.0):** the candidate assumed 1.0 HP with no escape, control or immunity, and Mercy accepting longer fights. At 0.8 the Priest has Mage HP, so melee packs end Mercy fights sooner and Reckoning's 6% P recovery per 16 s covers less. Pool-based heals now restore 25% more of the Priest's own max HP, which partly compensates. Recommendation: no new mechanic; set H1 support values with self-cast in mind and check solo survival in the planned L14/L26/L60 runs before adding anything.
6. **Hearten vs Haven overlap:** both are now one-shot group heals (burst vs HoT). Keep Hearten as its own skill (candidate), or make it a Heal transformation as shipped (B9, Heal also heals nearby allies)? Recommendation: keep it separate as the candidate has it; it uses only existing blocks and stays clearly distinct from the HoT ultimate.

#### New building blocks needed
None. The Priest uses B1, B2 (per-skill occupied time: 1.5 s for Heal, Hearten, Haven, Final Word), B4, B5 (Censure only), B6 (Mend and Haven as periodic statuses; Haven needs its own status id and icon), B8, B10, B11 (Word of Ruin only) and a small automatic-recipient helper for group heals (filter, cap, sort). It does not need B3, B7, B9 or B12 (no mob DoT).

### 4.4 Scout (Quarry / Veil)

Basis: candidate `docs/planning/class-redesign/scout.md` plus continuation §3/§4/§4a. R = bow unit, M = blade unit, P = class-neutral mana pool (candidate §2). "Occupied" = B2 time after the cast in which the Scout cannot attack or cast. HP factor 1.0 equals the shipped value, so the Scout's HP does not change.

#### Active skills
| Skill | Tree / unlock | Candidate mechanic (short) | Simplified version | Blocks | Change vs candidate |
|---|---|---|---|---|---|
| Loose | Starter | LMB: 0.18 s preparation, then a 0.95 R arrow; occupied 0.85 s; held repeats; RMB is melee | Plain LMB bow cast, instant 0.95 R, 1 arrow, occupied 0.85 s, held LMB repeats like Fireball (`cast_interval`). No RMB melee. Empty quiver or refused cast: the existing Strike fallback at a hostile in reach (`input.lua:416-418`). Today's bow draw is deleted | B1, B2, B3 | adapted |
| Bladecraft | Veil V1, transforms Loose | LMB ordinary melee, RMB the same Loose shot; same shared clock | As candidate: LMB melee swing; RMB fires one instant Loose shot at a valid hostile (today's RMB bow branch, `input.lua:296-299`, minus the draw). Replaces Loose in place on A and B with a shared cooldown | B9, B2, B3 | kept |
| Sidestep | Starter | +15 pp dodge for 3 s, 30% cap; 18 s cooldown; 6% P; 0.25 s action | Same numbers. Reuses the shipped Sidestep window (`grug_classes/scout.lua:20-47`, fixed +15, duration 4 s becomes 3 s); occupied 0.25 s or 0 | B1, B6 (own window), B2 | kept |
| Aimed Shot (rename pending, §5.4) | Quarry Q4 | 0.75 s preparation with half-speed stance, 1.80 R, 1.35 s total, 6 s cooldown, 6% P + 1 arrow | Instant 2.2 R (M7: 2.1-2.3 R), occupied 1.35 s, 6 s cooldown, 6% P + 1 arrow. No stance or preparation tell; the long occupied time is the price | B1, B2, B3 | adapted |
| Snare Shot | Quarry Q6 | 0.45 R + 35% slow for 3 s; 0.18 s preparation; 14 s cooldown; 5% P + 1 arrow | Instant (simplification 2): 0.45 R, 35% slow for 3 s on a landed hit (existing `pending_control` slow); occupied 0.85 s | B1, B2, B3, B7 | kept |
| Split Shot | Quarry Q8 | Primary 0.90 R; up to 2 nearest other targets within 3 m get their own 0.55 R arrows; 1 arrow per recipient | One arrow at the primary; on impact, up to 2 nearest other hostiles within 3 m take 0.55 R direct damage, with no projectiles of their own (the Fireball splash loop, `kits.lua:576-583`, capped at 2). Costs 1 arrow + 8% P; 10 s cooldown; occupied 1.0 s | B1, B2, B3 (splash) | adapted |
| Arrowfall (Quarry ult.) | Quarry Q12 | 4 releases over 2.6 s at one retained target, paid per release, facing check, half speed, no crit | One-shot volley: 4 arrows fired together at the crosshair target (the existing `launch(count)` batch with atomic ammo, `scout.lua:194-262`), 4 x 1.4 R, crits allowed (no new no-crit flag). Costs 16% P + 4 arrows; refused with fewer than 4 arrows. Occupied 2.5 s; 60 s cooldown | B1, B2, B3 | redesigned |
| Opening | Veil V4 | 1.35 M; 1.80 M from the rear 120° or with Parry permission; 8 s cooldown; 5% P | Existing swing-kind charge skill (`scout.lua:646-669`), recharge 8 s: 1.35 M from the front, 1.80 M from behind (shipped 180° `behind_target`) or while Parry's window is active (consumes it). The shipped rooted/stunned bonus is dropped | B1 (swing charge), B8 | kept |
| Parry | Veil V6 | Next direct hit within 2 s takes 40% less; a landed or dodged hit grants an Opening permission for 3 s | Guard without hit detection: an absorb shield (about 10% max HP) for 2 s plus an Opening window opened immediately for 3 s. 12 s cooldown; 4% P; occupied 0.5 s | B1, B2, B6 (absorb), B8 | redesigned |
| Flourish | Veil V8 | 0.25 s preparation; frontal 90° cone, up to 3 hostiles, 0.80 M each; 12 s cooldown; 8% P | Instant facing cone, 3 m, 90°, the 3 nearest hostiles at 0.80 M each; occupied max(1.0 s, blade interval) | B1, B2, B4 | adapted |
| Close Dance (Veil ult.) | Veil V12 | 5 s: the next 3 landed blade attacks +0.35 M each (charges spent on real HP damage); first direct incoming hit -30% | A 6 s timed window: blade swings +0.35 M each (no charges, so no B11), plus an absorb shield (about 15% max HP) for 6 s. 60 s cooldown; 14% P; occupied 0.25 s | B1, B6, B8, B10 | adapted |
| Sprint (shipped starter) | Innate today | Removed from the repertoire | Recommended: keep it unchanged (+50% speed for 10 s, 300 s cooldown) as an innate catalogue skill; see below | B1 (exists) | candidate cut; open (Q3) |

Not listed as rows: Strike stays the universal entitlement and is unchanged. The shipped Pinning Shot (talent root) is retired, as the candidate proposes; this needs the migration's retired-id step.

#### Talents with mechanics
| Talent | Tree | Candidate effect | Simplified version | Blocks |
|---|---|---|---|---|
| V1 Bladecraft | Veil | Transforms Loose's input priority (LMB melee, RMB bow) | Transformation Loose to Bladecraft in place on A and B, with a shared cooldown key | B9 |
| Q11 Follow the Line | Quarry | A landed Aimed Shot empowers the next Loose on the same target within 3 s (+0.10/0.20/0.30 R) | A landed Aimed Shot opens a 3 s window; the next Loose (any target) gains +0.10/0.20/0.30 R and spends the window. No target memory | B8, B10 |
| V10 Turn the Blade | Veil | An Opening that uses Parry permission gains +0.10/0.20/0.30 M | The same conditional add, read while Parry's window is active | B8, B10 |
| V11 Shake Loose | Veil | Sidestep clears the current slow; cooldown 17/16/15 s; no root break or immunity | Sidestep calls the existing `clear_negative_move_modifiers` (it also clears roots; accept this, or filter to slows), no immunity; cooldown -1/2/3 s | B10 (existing call) |

15 further talents are plain B10 modifiers: Q1 Bowcraft, Q2 Quiver (existing `arrow_refund_chance`), Q3 Measured Breath, Q5 Firm Aim, Q7 Long View (`loose_range_add` pattern), Q9 Broad Shot (secondary splash damage), Q10 Light Recovery, Q13 Heavy Rain (per volley arrow), V2 Fine Edge, V3 Light Step (`dodge_chance_add`), V5 Deep Focus, V7 Held Guard (Parry window/shield duration +0.25/0.5/0.75 s), V9 Wide Edge, V13 Cutting Rhythm (Close Dance window damage), V14 Travel Worn.
8 further nodes only unlock a skill: Q4, Q6, Q8, Q12, V4, V6, V8, V12. Retired shipped talents include Fletching (`draw_time_sub`, which has no draw left to shorten), Twin Shot, Longshot, Untouchable, Pinning Shot and Shifting Weight.

#### Controls and Sprint
**Control remap.** Today, Loose means LMB melee and hold RMB to draw, with damage scaling by draw length. The candidate wanted Loose as an LMB quick shot with RMB melee, plus a Bladecraft talent that swaps the two buttons. Simplification 3, already accepted, drops the risky "RMB = melee". Loose becomes a plain LMB bow cast whose held button repeats; it uses the Fireball `cast_interval` pattern. Bladecraft is today's mapping, with an instant RMB shot instead of the draw.
- **Cost:** deleting the draw is pure savings: about 300 lines in `scout.lua` (draw table, stance, wear stages, renew) and the `loose` special cases in `input.lua:179-181, 228-229, 711-730`.
- **New work:** Bladecraft's RMB keeps the existing RMB bow branch with its food and interaction arbitration, but fires an instant shot. If a held RMB repeats, that reuses the draw's held-state polling. The bow's attack-speed affix needs a new consumer: it divides Loose's 0.85 s, floor 0.65 s.
- **Need:** ruling 1 forces the Loose part, because the draw is a hold-to-charge. Bladecraft is optional for melee: any swing skill selected (for example Opening) already swings Strike on LMB when it is not charged (`input.lua:410-413`).
- **Recommendation:** do Loose as above, and keep Bladecraft for the Veil identity, since its RMB path already exists.

**Sprint removal.** Sprint is a shipped Scout starter: +50% speed for 10 s, 300 s cooldown, 15% mana (`scout.lua:582-606`). The candidate drops it, which reverses rulings 9/29 of `skill_trees.md`.
- **Cost:** removing it is not a mechanic. It is cleanup: retire the `sprint` id in the migration (the step exists anyway for Pinning Shot), fix the roughly 20 tool files that mention sprint, and amend the rulings.
- **Recommendation:** the rework does not need the removal. Keeping Sprint unchanged costs nothing, and at 300 s it barely touches combat. Keep it as an innate catalogue skill unless Jan wants the tighter kit.

#### Open questions for the user
1. **Arrowfall shape:** a single-target volley of 4 arrows together at the crosshair target (keeps the candidate's single-target ultimate), or an arrow rain on a point: a B5 area with about 0.8 s delay and falling-arrow particle warning, which overlaps with Split Shot. Recommendation: the volley, at 4 x 1.4 R with crits allowed, occupied 2.5 s.
2. **Parry:** open the Opening window at the cast (unconditional), or only once a hit lands during the guard? The landed-hit option would use the existing settled-incoming-hit hook, so dodged and fully absorbed hits would not count. Recommendation: unconditional plus an absorb shield. It is simpler, and the shield is the defensive half.
3. **Sprint:** keep it unchanged (recommended, zero work) or remove it as the candidate proposes.
4. **Bladecraft:** keep it with the RMB instant shot (recommended), or cut it and let the Veil fight with Strike or swing skills and switch to Loose on the hotbar. Cutting saves the RMB rework and the V1 transformation; V4/V8 would then hang on a gate instead.
5. **Shared action clock (B2 scope):** should a melee swing also block bow shots and casts for its interval, as well as casts delaying melee (today `strike_delay` only works one way)? Recommendation: yes for the Scout, otherwise Bladecraft weaves two damage streams.
6. **Aimed Shot numbers:** instant 2.2 R, 6 s cooldown, occupied 1.35 s. That gives +0.7 R per cycle over the Loose shots it displaces. Is this the intended "clearly more" from M7? The rename is still pending (§5 item 4).

#### New building blocks needed
None: the Scout needs nothing beyond B1-B11 and does not use B12 (no mob DoT). Small Scout-specific items that are not new primitives:
- Bladecraft's RMB instant shot inside the existing RMB bow branch.
- The bow attack-speed affix consumer for Loose's interval, replacing the draw-speed use.
- A cap of 2 nearest on the reused splash loop for Split Shot.
- A Sidestep duration parameter.

Two code checks:
- A generic `dodge_percent` status modifier is **not** an existing B6 key. `status.lua` MODIFIER_KEYS rejects it, although `stats.lua:153` already reads it. Adding it would be a one-line change, but the Scout does not need it, because Sidestep keeps its own window.
- The Arrowfall volley allows crits, so the redesign needs no no-crit flag.
