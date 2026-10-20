# Class redesign P4: final talent node list (input for the art lane and the class lanes)

Compiled 2026-10-19 from `docs/planning/class-redesign/skill-inventory.md`
(authoritative), `continuation.md` §4a, the candidates `warrior.md`,
`priest.md`, `scout.md`, `mage.md` and the handoff §5 (Mage tables), in
this folder. Documentation only.

Applied rulings:

- the inventory's adaptations, i.e. every prepared skill becomes instant with occupied time, and every area triggers once;
- the cuts: Shelter is removed and folded into Warding Faith; Afterglow becomes a Fireball damage rank; the Ice Armor reactive slow is gone; retired shipped talents are not listed;
- the ten cross-class decisions and the smaller class decisions: Hard Faith gives paid-spell damage, Ruination is a +15 % multiplier, Broadstroke secondaries may crit, Recover is a flat heal, Flame Lance is kept, True Draw does 2.2 R, Steady Word and Sharpened Word share one max-combined key, and Word of Ruin has the pool cap only;
- the renames **Aimed Shot → True Draw** and **Ice Armor → Rime Mantle**, both provisional;
- Mage R3 keeps its mage.md name **Keen Cold** (handoff: Lingering Chill).

Every other candidate name is kept.

Notation:

- D is the Mage's untalented Spark hit. S is the Warrior's Strike. R and M are the Scout's bow and blade units. W+I is the Priest's spell unit. B is the Priest's baseline melee term. P is the neutral pool, K the armor constant, Q and F the support factors.
- Numbers are paper values that the P2 calculator freezes.
- **Node ids:** candidate codes, except that Reckoning is written **RK1–RK14** so it no longer collides with Rime R1–R14 (continuation §5 item 4). Mercy keeps a gap at M12 (Shelter, cut).
- Gate N means N points already spent in that tree. A prerequisite needs rank 1. Gates 0/2/6/10/12/16/20 mean earliest levels 2/6/14/22/26/34/42.

Node types:

- **modifier:** a number or conditional effect on an existing skill.
- **unlock:** grants a skill into the catalogue and places nothing on a hotbar.
- **transform:** replaces a skill in place on hotbars A and B, sharing its cooldown key.
- **window:** the node opens a readiness window with a status icon.
- **ultimate:** the unlock at gate 20.

## 1. Summary

| Tree | Class | Nodes | Ranks | Unlocks (excl. ultimate) | Transforms | Windows | Modifiers | Ultimate |
|---|---|---:|---:|---|---|---:|---:|---|
| Ember | Mage | 13 | 32 | 3: Fireball, Flame Lance, Meteor | 0 | 0 | 9 | Fire Rain |
| Rime | Mage | 14 | 33 | 2: Blink, Rime Mantle | 2: Cold Spark, Ice Nova | 1 | 8 | Winter Field |
| Bulwark | Warrior | 14 | 33 | 2: Hold Ground, Taunt | 2: Retort, Bellow | 0 | 9 | Unbroken |
| Ruin | Warrior | 14 | 33 | 2: Mighty Blow, Hamstring | 1: Broadstroke | 0 | 10 | Ruination |
| Mercy | Priest | 13 | 31 | 3: Shield, Mend, Hearten | 0 | 1 | 8 | Haven |
| Reckoning | Priest | 14 | 34 | 3: Rebuke, Word of Ruin, Censure | 0 | 0 | 10 | Final Word |
| Quarry | Scout | 13 | 32 | 3: True Draw, Snare Shot, Split Shot | 0 | 1 | 8 | Arrowfall |
| Veil | Scout | 14 | 33 | 3: Opening, Parry, Flourish | 1: Bladecraft | 0 | 9 | Close Dance |
| **Total** | | **109** | **261** | **21** | **6** | **3** | **71** | **8** |

Art volume:

- **Talent icons.** 74 nodes need their own icon: the 71 modifier nodes plus the 3 window nodes. The other 35 nodes use a skill icon: 21 unlocks, 6 transforms and 8 ultimates.
- **Skill icons.** There are 44 active skills (section 3). The repository ships 19 of these icons, so **25 skill icons are new**. That rises to 44 if the art lane redraws everything as one consistent set.
- **Backgrounds.** 8 tree backgrounds.

## 2. Nodes per tree

### Ember (Mage, fire)

Background idea: a charcoal-and-ember field, cracked basalt, rising sparks at the edges, and a warm glow towards the ultimate. Icon language: orange and red flame shapes on dark charcoal, with one small symbol per modifier.

| Node | Name | Ranks | Gate | Prereq | Type | Effect under the rulings | Icon motif |
|---|---|---:|---:|---|---|---|---|
| F1 | Fire Mastery | 4 | 0 | — | modifier | All fire damage +5/10/15/20 % (additive, applied once) | flame crowned inside a ring |
| F2 | Measured Fuel | 3 | 0 | — | modifier | Paid fire spell costs −4/8/12 % | flame above a small measured oil drop |
| F3 | Far Cast | 3 | 0 | — | modifier | Spark / Cold Spark range +1/2/3 m | flame with a long dotted trajectory |
| F4 | Fireball | 1 | 2 | F1 | unlock | Fireball: 1.60D + 0.15D splash 2 m, 5 s cd, 6 % P, 1 s occupied | uses the skill icon |
| F5 | Flame Lance | 1 | 6 | — | unlock | Flame Lance: instant heavy projectile 2.20D, 8 s cd, 10 % P, 1.5 s occupied | uses the skill icon |
| F6 | Heat Focus | 3 | 6 | F5 | modifier | Flame Lance +5/10/15 % of its untalented damage | lens focusing a flame into a beam |
| F7 | Afterglow | 3 | 6 | F4 | modifier | Fireball primary hit +0.05/0.10/0.15D (former burn, folded; no DoT) | fireball trailing a fading glow |
| F8 | Meteor | 1 | 12 | F4 | unlock | Meteor: ground anchor ≤20 m, 1.5 s delay with warning particles, 1.4D r 3 m, 18 s cd, 14 % P | uses the skill icon |
| F9 | Wide Ember | 3 | 12 | F4 | modifier | Fireball splash 0.20/0.25/0.30D | burst of sparks fanning outward |
| F10 | Broad Impact | 3 | 12 | F8 | modifier | Meteor radius +0.25/0.50/0.75 m | crater with a widening ring |
| F11 | Controlled Burn | 3 | 16 | F8 | modifier | Meteor and Fire Rain costs −5/10/15 % (additive with F2) | flame held inside a closed ring |
| F12 | Fire Rain | 1 | 20 | F8 | ultimate | Fire Rain: ground anchor ≤20 m, 1.5 s delay, one shower hit ~2.5D r 5 m, 60 s cd, 22 % P, 1.5 s occupied | uses the skill icon |
| F13 | Spreading Rain | 3 | 20 | F12 | modifier | Fire Rain radius +0.25/0.50/0.75 m | falling fire drops spreading wide |

### Rime (Mage, frost)

Background idea: a frozen lake under a night sky, frost ferns on the edges, and a pale aurora towards the ultimate. Icon language: pale blue and white ice crystals on deep navy.

| Node | Name | Ranks | Gate | Prereq | Type | Effect under the rulings | Icon motif |
|---|---|---:|---:|---|---|---|---|
| R1 | Cold Spark | 1 | 0 | — | transform | Fiery Spark → Cold Spark: free frost projectile D, 12 % slow 1.5 s (refresh only), no fire bonuses | uses the skill icon (Cold Spark) |
| R2 | Mana Reserve | 4 | 0 | — | modifier | Max mana +5/10/15/20 % P | full frost-blue crystal flask |
| R3 | Keen Cold | 3 | 0 | R1 | modifier | Cold Spark +0.03/0.06/0.09D (slow stays 12 %) | needle-sharp icicle tip |
| R4 | Blink | 1 | 2 | — | unlock | Blink: 10 m teleport, 20 s cd, 8 % P | uses the skill icon |
| R5 | Clear Thought | 3 | 2 | — | modifier | Paid frost/utility spell costs −4/8/12 % | snowflake over a calm eye |
| R6 | Quick Step | 3 | 6 | R4 | modifier | Blink cd −1/2/3 s | frosted footprint with motion lines |
| R7 | Rime Mantle | 1 | 6 | — | unlock | Rime Mantle: self armor +0.20K for 6 s, 24 s cd, 10 % P (armor only) | uses the skill icon |
| R8 | Thick Ice | 3 | 10 | R7 | modifier | Rime Mantle armor +0.04/0.08/0.12K | thick layered ice slab |
| R9 | Ice Nova | 1 | 12 | — | transform | Ice Wave → Ice Nova: 0.65D r 5 m + fixed 1.75 s root, 18 s cd, 10 % P; shared cd key | uses the skill icon (Ice Nova) |
| R10 | Cold Shock | 3 | 12 | R9 + R1 | window | Nova hitting an enemy readies the next Cold Spark within 4 s: +0.25/0.50/0.75D, one charge | jagged frost spark cracking |
| R11 | Returning Cold | 3 | 12 | — | modifier | Ice Wave/Ice Nova cd −1/2/3 s (shared key) | circular arrow of frost |
| R12 | Far Frost | 3 | 16 | R9 | modifier | Nova radius +0.25/0.50/0.75 m | expanding ring of frost |
| R13 | Winter Field | 1 | 20 | R9 | ultimate | Winter Field: ground anchor ≤15 m, 1 s delay, one hit ~1.0D + 40 % slow 5 s, r 4 m, 60 s cd, 18 % P | uses the skill icon |
| R14 | Lasting Armor | 3 | 16 | R7 | modifier | Rime Mantle duration +0.5/1.0/1.5 s | frost mantle with a small hourglass |

### Bulwark (Warrior, guard)

Background idea: a weathered stone rampart with iron-banded gates, a banner, and steel rivets at the edges. Icon language: steel grey and bronze, with shields, plates and planted stances.

| Node | Name | Ranks | Gate | Prereq | Type | Effect under the rulings | Icon motif |
|---|---|---:|---:|---|---|---|---|
| B1 | Retort | 1 | 0 | — | transform | Strike → Retort: a hostile hit that removed HP readies the next swing +0.25S within 4 s; 6 s ICD; status icon | uses the skill icon (Retort) |
| B2 | Ironbound | 4 | 0 | — | modifier | Armor +0.04/0.08/0.12/0.16K | riveted iron bands on a plate |
| B3 | Weathered | 3 | 0 | — | modifier | Max HP +3/6/9 % of class pool | scarred, weathered chestplate |
| B4 | Hold Ground | 1 | 2 | — | unlock | Hold Ground: 25 rage, 24 s cd, absorb 0.12P for 5 s; no immunity | uses the skill icon |
| B5 | Measured Answer | 3 | 6 | B1 | modifier | Retort bonus 0.30/0.35/0.40S | sword with a returning counter-arrow |
| B6 | Turn the Edge | 3 | 6 | — | modifier | Dodge +2/4/6 pp (normal cap) | blade glancing off a slanted plate |
| B7 | Taunt | 1 | 6 | — | unlock | Taunt: single mob, 8 m, free, 8 s cd, 3 s attention | uses the skill icon |
| B8 | Recover | 3 | 10 | B1 | modifier | Landed Retort heals a flat 0.007/0.013/0.02P × F, no crit | red drop returning into a gauntlet |
| B9 | Bellow | 1 | 12 | B7 | transform | Taunt → Bellow: 6 m self-centred area taunt, same cd | uses the skill icon (Bellow) |
| B10 | Layered Guard | 3 | 12 | B4 | modifier | Hold Ground absorb +0.03/0.06/0.09P | overlapping stacked shield plates |
| B11 | Halt | 3 | 12 | — | modifier | Charge arrival also slows 20/25/30 % for stun + 2 s | raised gauntlet palm, dust stopping |
| B12 | Unbroken | 1 | 20 | B4 | ultimate | Unbroken: 25 rage, 60 s cd, +0.50K armor + 0.15P absorb for 8 s; no immunity | uses the skill icon |
| B13 | Enduring Stand | 3 | 20 | B12 | modifier | Unbroken duration +0.5/1.0/1.5 s | planted boots beside an hourglass |
| B14 | Gather Yourself | 3 | 16 | B4 | modifier | Hold Ground cd −1/2/3 s | shield with a drawn-breath swirl |

### Ruin (Warrior, rage)

Background idea: a scorched battlefield with cracked iron, red smoke and broken weapons at the edges. Icon language: crimson and black, with heavy blows, cracked metal and rage glow.

| Node | Name | Ranks | Gate | Prereq | Type | Effect under the rulings | Icon motif |
|---|---|---:|---:|---|---|---|---|
| U1 | Mighty Blow | 1 | 0 | — | unlock | Mighty Blow: 25 rage swing proc, 1.45S, no own cd; plain swing when unaffordable | uses the skill icon |
| U2 | Heavy Hand | 4 | 0 | U1 | modifier | Mighty Blow/Broadstroke primary +0.05/0.10/0.15/0.20S | heavy armored fist |
| U3 | Stoke | 3 | 0 | — | modifier | Rage per full swing +1/2/3 | bellows stoking red embers |
| U4 | Hamstring | 1 | 2 | — | unlock | Hamstring: 10 rage swing proc, S, 8 s proc cd, 35 % slow 3 s | uses the skill icon |
| U5 | Keen Edge | 3 | 6 | — | modifier | Crit +2/4/6 pp | glint running along an edge |
| U6 | Onset | 3 | 6 | — | modifier | Charge cd −0.5/1.0/1.5 s | boot driving forward with speed lines |
| U7 | Broadstroke | 1 | 6 | U1 | transform | Mighty Blow → Broadstroke: same primary + ≤2 others in a 100° 3 m arc take 0.35S (LOS, may crit) | uses the skill icon (Broadstroke) |
| U8 | Follow Through | 3 | 10 | U7 | modifier | Broadstroke secondaries 0.40/0.45/0.50S | wide sweeping arc trail |
| U9 | Clean Cut | 3 | 10 | U4 | modifier | Hamstring slow +0.5/1.0/1.5 s, no root | cord cut cleanly in two |
| U10 | Finisher | 3 | 12 | U1 | modifier | Mighty Blow/Broadstroke primary +0.08/0.16/0.24S vs target below 30 % HP | cracked helmet under a falling blade |
| U11 | Relentless | 3 | 16 | U1 | modifier | Mighty Blow/Broadstroke cost −1/2/3 rage | chain of three red strikes |
| U12 | Ruination | 1 | 20 | U1 | ultimate | Ruination: 20 rage, 60 s cd, 8 s window: swing damage +15 % (multiplier), +2 rage per landed swing | uses the skill icon |
| U13 | Long Fury | 3 | 20 | U12 | modifier | Ruination +0.5/1.0/1.5 s | burning red hourglass |
| U14 | Reach the Fight | 1 | 12 | — | modifier | Charge arrival +5 rage | charging figure with a rage drop |

### Mercy (Priest, support)

Background idea: a quiet sanctuary with soft gold light through arches, lilies and warm stone. Icon language: warm gold and white, with open hands, soft light and vessels.

| Node | Name | Ranks | Gate | Prereq | Type | Effect under the rulings | Icon motif |
|---|---|---:|---:|---|---|---|---|
| M1 | Steady Word | 3 | 0 | — | modifier | Smite +0.05/0.10/0.15B; shares one max-combined key with RK1 (no stacking) | open book with a steady light |
| M2 | Measured Care | 3 | 0 | — | modifier | Heal, Shield, Mend, Hearten, Haven costs −4/8/12 % | jug pouring a measured stream |
| M3 | Shield | 1 | 2 | — | unlock | Shield: crosshair ally or self, absorb ~22–25 % P × Q for ~10 s, cd ~12 s; any recast replaces | uses the skill icon |
| M4 | Gentle Hand | 3 | 2 | — | modifier | Heal amount +2/4/6 pp of P (candidate 22/24/26 % on a 20 % base; rebased on the H1 base) | open palm with a soft glow |
| M5 | Warding Faith | 3 | 6 | M3 | modifier | Shield absorb +2/4/6 pp of P, raised to include Shelter's folded value (P2 sets it) | shield crowned by a halo |
| M6 | Mend | 1 | 6 | — | unlock | Mend: status on the target, 4 ticks × ~6–8 % P × Q every 3 s; newest cast replaces | uses the skill icon |
| M7 | Patient Care | 3 | 10 | M6 | modifier | Mend tick +0.5/1.0/1.5 pp of P (rebased on H1) | hourglass dripping golden drops |
| M8 | Clear Conscience | 3 | 10 | — | window | After Heal/Shield/Mend, the next Smite within 5 s +0.10/0.20/0.30B; ICD 8 s; status icon | clear bell with a light ray |
| M9 | Deep Reserve | 3 | 12 | — | modifier | Max mana +4/8/12 % P | deep chalice brimming with light |
| M10 | Hearten | 1 | 12 | — | unlock | Hearten: instant self + friendly players within 6 m, cap 4, lowest HP first, ~15 % P × Q each, 1.5 s occupied | uses the skill icon |
| M11 | Quiet Care | 3 | 12 | — | modifier | Healing threat factor 0.50 → 0.45/0.40/0.35 | muted bell / finger at the lips |
| M13 | Haven | 1 | 20 | M10 | ultimate | Haven: self-centred 8 m circle, cap 5 incl. self, HoT status 6 ticks × ~7 % P × Q every 2 s, 60 s cd, 1.5 s occupied | uses the skill icon |
| M14 | Lasting Haven | 3 | 20 | M13 | modifier | Haven HoT +1/2/3 ticks | sheltering arch with extra light chimes |

*(M12 Shelter is cut; its value moves into M5.)*

### Reckoning (Priest, judgment)

Background idea: a stern tribunal hall with a harsh sunburst, stone columns, and golden scales at the edges. Icon language: hard gold-white with crimson accents, with scales, seals, quills and a severe sun.

| Node | Name | Ranks | Gate | Prereq | Type | Effect under the rulings | Icon motif |
|---|---|---:|---:|---|---|---|---|
| RK1 | Sharpened Word | 3 | 0 | — | modifier | Smite +0.05/0.10/0.15B; same max-combined key as M1 | quill sharpened into a blade |
| RK2 | Measured Judgment | 3 | 0 | — | modifier | Rebuke, Word of Ruin, Censure, Final Word costs −4/8/12 % | balanced golden scales |
| RK3 | Rebuke | 1 | 2 | — | unlock | Rebuke: instant 20 m hit 1.8(W+I), 6 % P, 6 s cd | uses the skill icon |
| RK4 | Firm Rebuke | 3 | 2 | RK3 | modifier | Rebuke +0.10/0.20/0.30B | clenched fist wreathed in radiance |
| RK5 | Long Reach | 3 | 6 | — | modifier | Smite, Rebuke, Word of Ruin, Final Word range +1/2/3 m | pointing hand casting a long ray |
| RK6 | Word of Ruin | 1 | 6 | — | unlock | Word of Ruin: instant 1.6(W+I), 16 s cd, 10 % P; self-heal 50 % of damage dealt, capped at 6 % P × Q (pool cap only, no HP receipt) | uses the skill icon |
| RK7 | Resolute Word | 3 | 10 | RK6 | modifier | Word of Ruin heal cap 7/8/9 % P | book clasped by a gold seal |
| RK8 | Hard Faith | 3 | 10 | — | modifier | Paid Priest attack spell damage +3/6/9 % (`damage_pct:paid`); Smite untouched | iron sun / hardened halo |
| RK9 | Censure | 1 | 12 | — | unlock | Censure: ground anchor ≤16 m, ~0.75 s delay with warning, one hit 1.2(W+I) r 3 m ±3 band, 4 nearest, 12 % P, 18 s cd | uses the skill icon |
| RK10 | Broad Judgment | 3 | 12 | RK9 | modifier | Censure radius 3.25/3.50/3.75 m | sunburst ring widening on the ground |
| RK11 | Deep Resolve | 3 | 12 | — | modifier | Max mana +4/8/12 % P | deep well with gold at the bottom |
| RK12 | Press the Verdict | 3 | 16 | RK3 | modifier | Rebuke cd 5.5/5.0/4.5 s | seal stamp pressing down |
| RK13 | Final Word | 1 | 20 | RK3 | ultimate | Final Word: instant 20 m hit 2.8(W+I), 20 % P, 60 s cd, 1.5 s occupied | uses the skill icon |
| RK14 | Unfinished Sentence | 3 | 20 | RK13 | modifier | Final Word +0.10/0.20/0.30B | torn scroll with trailing script |

### Quarry (Scout, bow)

Background idea: a forest edge at dawn, with tall grass, antlers and feathers, and a distant ridge. Icon language: green and earth brown, with arrows, feathers, bows and the hunter's eye.

| Node | Name | Ranks | Gate | Prereq | Type | Effect under the rulings | Icon motif |
|---|---|---:|---:|---|---|---|---|
| Q1 | Bowcraft | 4 | 0 | — | modifier | Bow attacks +5/10/15/20 % of untalented damage (incl. Arrowfall) | bow crossed with a carving knife |
| Q2 | Quiver | 3 | 0 | — | modifier | Loose 10/20/30 % chance to save its arrow | quiver with an arrow curving back in |
| Q3 | Measured Breath | 3 | 0 | — | modifier | Paid bow mana costs −5/10/15 % | breath mist above a nocked arrow |
| Q4 | True Draw | 1 | 2 | — | unlock | True Draw: instant 2.2 R, 6 s cd, 6 % P + 1 arrow, 1.35 s occupied | uses the skill icon |
| Q5 | Firm Aim | 3 | 6 | Q4 | modifier | True Draw +0.10/0.20/0.30 R | steady crosshair on a taut string |
| Q6 | Snare Shot | 1 | 6 | — | unlock | Snare Shot: instant 0.45 R + 35 % slow 3 s, 14 s cd, 5 % P + 1 arrow, 0.85 s occupied | uses the skill icon |
| Q7 | Long View | 3 | 10 | — | modifier | Bow ranges +1/2/3 m | eye over a far horizon |
| Q8 | Split Shot | 1 | 12 | — | unlock | Split Shot: one arrow 0.90 R; on impact ≤2 nearest others within 3 m take 0.55 R (no own arrows); 8 % P + 1 arrow, 10 s cd | uses the skill icon |
| Q9 | Broad Shot | 3 | 12 | Q8 | modifier | Split Shot secondary hits +0.05/0.10/0.15 R | arrowhead bursting into a fan |
| Q10 | Light Recovery | 3 | 16 | — | modifier | Sidestep mana cost −10/20/30 % | feather resting on a leaf |
| Q11 | Follow the Line | 3 | 16 | Q4 | window | A landed True Draw opens 3 s: next Loose (any target) +0.10/0.20/0.30 R | two arrows on one dashed line |
| Q12 | Arrowfall | 1 | 20 | Q4 | ultimate | Arrowfall: 4 arrows together at the crosshair target, 4 × 1.4 R, crits allowed, 16 % P + 4 arrows, 2.5 s occupied, 60 s cd | uses the skill icon |
| Q13 | Iron Hail | 3 | 20 | Q12 | modifier | Each Arrowfall arrow +0.04/0.08/0.12 R | heavy arrowheads plunging down |

### Veil (Scout, blade)

Background idea: moonlit alleys and mist, with a crescent moon and drifting smoke. Icon language: indigo and violet with silver steel, using smoke, crescents and short blades.

| Node | Name | Ranks | Gate | Prereq | Type | Effect under the rulings | Icon motif |
|---|---|---:|---:|---|---|---|---|
| V1 | Bladecraft | 1 | 0 | — | transform | Loose → Bladecraft: LMB blade melee, RMB an instant Loose shot at a hostile; shared clock | uses the skill icon (Bladecraft) |
| V2 | Fine Edge | 4 | 0 | — | modifier | Blade attacks +8/16/24/32 % of untalented damage | thin blade with a fine silver glint |
| V3 | Light Step | 3 | 0 | — | modifier | Dodge +1/2/3 pp | soft footprint trailing smoke |
| V4 | Opening | 1 | 2 | V1 | unlock | Opening: swing charge 1.35 M; 1.80 M from behind or during the Parry window; 8 s cd, 5 % P | uses the skill icon |
| V5 | Deep Focus | 3 | 2 | — | modifier | Paid blade skills, Parry, Close Dance costs −5/10/15 % | half-closed eye in smoke |
| V6 | Parry | 1 | 6 | — | unlock | Parry: absorb ~10 % max HP for 2 s + Opening window 3 s at the cast; 12 s cd, 4 % P, 0.5 s occupied | uses the skill icon |
| V7 | Held Guard | 3 | 6 | V6 | modifier | Parry window and shield +0.25/0.50/0.75 s | crossed daggers held against an hourglass |
| V8 | Flourish | 1 | 12 | V1 | unlock | Flourish: instant 3 m 90° cone, 3 nearest × 0.80 M, 12 s cd, 8 % P | uses the skill icon |
| V9 | Wide Edge | 3 | 12 | V8 | modifier | Flourish +0.05/0.10/0.15 M per target | wide crescent slash |
| V10 | Turn the Blade | 3 | 12 | V4 + V6 | modifier | Opening during the Parry window +0.10/0.20/0.30 M | blade turning along a curved arrow |
| V11 | Shake Loose | 3 | 16 | — | modifier | Sidestep clears current slows; Sidestep cd −1/2/3 s | chain shaken apart into smoke |
| V12 | Close Dance | 1 | 20 | V4 + V6 | ultimate | Close Dance: 6 s window, blade swings +0.35 M + absorb ~15 % max HP; 60 s cd, 14 % P, 0.25 s occupied | uses the skill icon |
| V13 | Cutting Rhythm | 3 | 20 | V12 | modifier | Close Dance swing bonus +0.05/0.10/0.15 M | three rhythmic slash marks |
| V14 | Travel Worn | 3 | 6 | — | modifier | Max HP +3/6/9 % P | worn hooded cloak on a road |

## 3. Active skills needing an icon

"Shipped" means a `grug_abilities_skill_*.png` already exists in `mods/PLAYER/grug_abilities/textures/`. It can be reused or redrawn for a consistent set.

| Class | Skill | Starter / unlocked by | Family | Shipped icon | Icon motif |
|---|---|---|---|---|---|
| Mage | Fiery Spark | starter (replaces Strike) | fire | no | small bright flame dart with a spark tail |
| Mage | Ice Wave | starter | frost | no | fan-shaped wave of ice shards |
| Mage | Fireball | Ember F4 | fire | yes (`fireball`) | roaring fire orb |
| Mage | Flame Lance | Ember F5 | fire | no | long narrow spear of white-hot flame |
| Mage | Meteor | Ember F8 | fire | no (could reuse `cinderfall`) | single flaming rock falling at an angle |
| Mage | Fire Rain | Ember F12, ultimate | fire | no | many meteors falling onto a burning circle |
| Mage | Cold Spark | Rime R1, transforms Fiery Spark | frost | no | blue crystal dart with a frost tail (same silhouette as Fiery Spark) |
| Mage | Blink | Rime R4 | frost | yes (`blink`) | figure dissolving into frost motes and reappearing |
| Mage | Rime Mantle | Rime R7 | frost | no (could reuse `glacial_ward`) | hooded mantle crusted with rime |
| Mage | Ice Nova | Rime R9, transforms Ice Wave | frost | yes (`ice_nova`) | ring of ice spikes bursting outward |
| Mage | Winter Field | Rime R13, ultimate | frost | no | frozen ground circle with a falling snowstorm |
| Warrior | Strike | starter (universal) | none | yes (`strike`) | plain sword swing |
| Warrior | Charge | starter | rage | yes (`charge`) | shoulder rush with dust trail |
| Warrior | Retort | Bulwark B1, transforms Strike | rage | no | sword striking back off a raised shield |
| Warrior | Hold Ground | Bulwark B4 | rage | yes (`hold_ground`) | planted boots behind a braced shield |
| Warrior | Taunt | Bulwark B7 | rage | yes (`taunt`) | beckoning gauntlet |
| Warrior | Bellow | Bulwark B9, transforms Taunt | rage | no | roaring helmeted head with sound rings |
| Warrior | Unbroken | Bulwark B12, ultimate | rage | no | cracked shield still standing, glowing seams |
| Warrior | Mighty Blow | Ruin U1 | rage | yes (`mighty_blow`) | overhead two-handed smash |
| Warrior | Hamstring | Ruin U4 | rage | yes (`hamstring`) | low slash at a leg |
| Warrior | Broadstroke | Ruin U7, transforms Mighty Blow | rage | no | wide horizontal arc hitting three silhouettes |
| Warrior | Ruination | Ruin U12, ultimate | rage | no | blade wreathed in red fury, cracked ground |
| Priest | Smite | starter (replaces Strike) | holy | yes (`smite`) | short downward bolt of light |
| Priest | Heal | starter | holy | yes (`heal`) | glowing hand over a heart |
| Priest | Shield | Mercy M3 | holy | yes (`shield_spell`) | translucent golden dome |
| Priest | Mend | Mercy M6 | holy | yes (`mend`) | stitched heart with slow light drops |
| Priest | Hearten | Mercy M10 | holy | no | small ring of light around four figures |
| Priest | Haven | Mercy M13, ultimate | holy | no | radiant sanctuary arch over a circle |
| Priest | Rebuke | Reckoning RK3 | holy | no | pointing finger hurling a gold shard |
| Priest | Word of Ruin | Reckoning RK6 | holy | yes (`word_of_ruin`) | spoken rune cracking, light flowing back |
| Priest | Censure | Reckoning RK9 | holy | no | glowing seal slamming onto the ground |
| Priest | Final Word | Reckoning RK13, ultimate | holy | no | huge pillar of light from a closed book |
| Scout | Loose | starter | wild | yes (`loose`) | arrow leaving a bowstring |
| Scout | Sidestep | starter | wild | yes (`sidestep`) | figure stepping aside with an afterimage |
| Scout | Sprint | starter (innate, kept) | wild | yes (`sprint`) | running boot with wind streaks |
| Scout | True Draw | Quarry Q4 | wild | no | fully drawn longbow, arrow glinting |
| Scout | Snare Shot | Quarry Q6 | wild | yes (`snare_shot`) | arrow trailing a looped cord |
| Scout | Split Shot | Quarry Q8 | wild | no | arrow hitting, two side splinters branching |
| Scout | Arrowfall | Quarry Q12, ultimate | wild | no | four arrows converging on one target |
| Scout | Bladecraft | Veil V1, transforms Loose | shadow | no | short blade crossed over a bow |
| Scout | Opening | Veil V4 | shadow | yes (`opening`) | dagger through a gap in armor |
| Scout | Parry | Veil V6 | shadow | no | two blades meeting with a spark |
| Scout | Flourish | Veil V8 | shadow | no | spinning fan of three blade arcs |
| Scout | Close Dance | Veil V12, ultimate | shadow | no | twin blades circling a figure in smoke |

The count is 44 skills, of which 19 have a shipped icon and **25 need new icons**. Strike is counted once; it is universal and the Scout may also use it. The shipped icons `cinderfall`, `glacial_ward` and `pinning_shot` have no new skill of their own. Cinderfall and Glacial Ward are reuse candidates; Pinning Shot is retired.

## 4. Weapon-overlay element families (6, plus none)

> **Superseded 2026-10-19 (the user, Round 52 C7 amendment):** one family per tree (8): Ember fire, Rime frost,
> Bulwark steel, Ruin rage, Mercy warm healing light, Reckoning hard judgment gold, Quarry wild, Veil shadow; each
> drawn per weapon type the class can wield. A skill takes its tree's family; starters take their thematic tree
> (Charge, Mighty Blow, Hamstring → Ruin; Taunt, Hold Ground → Bulwark; Heal, Shield, Mend → Mercy; Smite, Word of
> Ruin → Reckoning; Loose, Snare Shot, Sidestep, Sprint → Quarry; Opening → Veil; Fiery Spark, Fireball,
> Cinderfall → Ember; Ice Wave, Ice Nova, Blink, Glacial Ward → Rime). Strike none. The table below is the first
> draft.

| Family | Look (short vertical-frame strip) | Skills |
|---|---|---|
| **fire** | orange-red licking flames, rising sparks | Fiery Spark, Fireball, Flame Lance, Meteor, Fire Rain |
| **frost** | pale blue rime creeping, glittering ice motes | Cold Spark, Ice Wave, Ice Nova, Blink, Rime Mantle, Winter Field |
| **holy** | warm gold-white light motes, soft pulse | Smite, Heal, Shield, Mend, Hearten, Haven, Rebuke, Word of Ruin, Censure, Final Word |
| **rage** | crimson pulsing glow, red embers along the edge | Charge, Retort, Hold Ground, Taunt, Bellow, Unbroken, Mighty Blow, Hamstring, Broadstroke, Ruination |
| **wild** (nature/wind) | green-teal wind streaks, drifting leaves | Loose, True Draw, Snare Shot, Split Shot, Arrowfall, Sidestep, Sprint |
| **shadow** | violet-black smoke curling, faint silver glint | Bladecraft, Opening, Parry, Flourish, Close Dance |
| *none* | plain weapon | Strike (the universal basic attack) |

Basic attacks: Fiery Spark is fire, Cold Spark frost, Smite holy, Loose wild, Bladecraft shadow, Retort rage, and Strike has no overlay. Optional 7th family if Bulwark should read differently from Ruin: **steel** (cold silver-blue shimmer) for Retort, Hold Ground, Taunt, Bellow and Unbroken.

## 5. Open points

**Decided (the user, 2026-10-20: "alles wie empfohlen"), for round K:**

- **Numbers:** the balance calculator's defaults plus its one stored change (`tuning/mage_rime`: Ice Armor absorb 12 % of P, Ice Nova root 2.5 s, Ice Wave slow 50 %) are frozen; fine tuning follows the user's first play test of the new kits.
- **Point 1:** Warding Faith (M5) gets 5 ranks instead of 3, so Mercy has 33; the folded Shelter value is part of its increments, set with the calculator.
- **Point 2:** M4, M5 and M7 become increments that keep each old end value (neither stronger nor weaker).
- **Point 3:** code talent ids are descriptive (`<tree>_<name>`, e.g. `mercy_warding_faith`); letter codes (RK1, M5) stay in the docs only.
- **Point 5:** True Draw, Rime Mantle, Iron Hail and Lasting Armor are final.
- **Point 6:** Shake Loose clears roots as well (the existing helper, unfiltered).
- **Point 7:** Bladecraft stays.
- **Point 10:** Winter Field without a stun (only if it plays weak); Sprint stays innate; Hearten 20 s cd, 14 % P; starter hotbar: the basic attack in slot 1, then the skills in unlock order.
- **Migration** (first login after the update): talent reset with a full refund; retired skill items leave both hotbars; Mage and Priest get their class basic attack in place of Strike; one short chat message, "Your talent points have been reset.", and nothing more (the user explains the rework in an admin newsletter).
- **The review notes for round K** (BACKLOG, Round 52 carry-overs) are resolved by the coordinator along the backlog's suggestions.

The points below keep their original wording for the record.

1. **Mercy has 31 ranks after the Shelter cut.** Pure Mercy at 30 points then leaves only 1 rank unbought, where the candidate meant pure builds to leave real omissions. The candidate's pure-Mercy order also spent 3 points on M12, and those need a new home. Options: accept, or give Warding Faith more ranks. Its folded Shelter value is not yet a number either (P2).
2. **Mercy support modifiers M4, M5 and M7** were written as absolute shares on the old bases (Heal 20 %, Shield 18 %, Mend 4 %). Under H1 they are re-expressed here as increments, which P2 must freeze.
3. **Node-id scheme.** Reckoning is written RK1–RK14 to end the clash with Rime R1–R14, and Mercy keeps the M12 gap. The class lanes need the final scheme and the code talent ids. Old ids are reused with new meanings, and the migration resets them anyway.
4. **Name collisions: decided** (the user, 2026-10-19). Generic genre words stay (Hamstring, Smite, Rebuke, Blink, Fireball, Taunt, Split Shot, Ice Nova, Fire Mastery, Censure). Only Q13, formerly "Heavy Rain" (a well-known game title), is renamed, provisionally Iron Hail.
5. **True Draw and Rime Mantle are provisional.** "Lasting Armor" (R14) and "Thick Ice" (R8) stay. "Lasting Mantle" would be the consistent alternative for R14. "Iron Hail" (Q13, formerly Heavy Rain) fits the 4-arrow volley.
6. **Shake Loose (V11).** The existing `clear_negative_move_modifiers` also clears roots, while the candidate said "no root break". The choice is to accept that or filter to slows.
7. **Bladecraft is kept** per the Scout inventory's recommendation (its Q4). It was not one of the ten cross-class decisions. If it is cut, V4 and V8 lose their parent.
8. **Overlay edge cases.** Blink is folded into frost instead of its own arcane family. Strike carries no overlay. Bulwark and Ruin share rage unless the optional steel family is wanted.
9. **Icon reuse.** Should the 19 shipped skill icons be redrawn for one consistent style? That would make 44 skill icons instead of 25. Should Meteor take Cinderfall's icon and Rime Mantle take Glacial Ward's?
10. **Kept values that remain soft.** Winter Field has an optional ~1 s stun if it feels weak. Sprint stays innate. Starter placement on the hotbars is still open. Hearten's cd and cost (20 s, 14 % P) are carried over from the candidate unchanged, because the inventory gives no new value.
