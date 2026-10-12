> Review record, 2026-10-12: independent read-only review of the class redesign
> package as it stood that day. Findings are hypotheses; the user's decisions on
> them are in [the continuation plan](../continuation.md#3-user-decisions-on-the-review-findings-2026-10-12).

# Class redesign package: design review (consistency, logic, balance)

**Verdict: ready for implementation planning after fixes.** Two areas need the user's decision before planning: the Priest's support output, and the cross-class damage order (who is the damage leader). The arithmetic is internally sound. Every receipt I recomputed reproduces, all 22 purchase sequences are legal, the rank totals are right (110 nodes, 57 edges), and every relative link and anchor resolves. The problems are in what the numbers are compared against and in a few rules that two implementers would build differently.

Scope: a read-only review of the uncommitted diff plus the handoff (HEAD), checked against classes.md, skill_trees.md, combat_stats.md, scout.md, pvp.md, progression.md and the cited code (`grug_abilities/kits.lua:543`, `grug_gear/init.lua:242-260`; both citations are accurate). No fixtures or engine runs: the change is documentation only.

---

## High

**H1. The Priest's support output drops 50–90% against the shipped kit, and nothing says so or analyses it.**
- **Where:** priest.md:105-109 (Heal 10% P, 6 s cooldown, 1.5 s stationary preparation, 20% P; Shield 9%/14 s/18% P for 6 s; Mend 8%/12 s, 4×4% P; Hearten 14% P, 20 s cooldown + 1.5 s, 10% P to at most 4 recipients). Support no longer crits (priest.md:61-63).
- **Shipped kit:** Heal is instant, 8%, 4 s, 25% P (classes.md:812). Shield is 8%/10 s/25% P for 15 s (:813). Mend is 6%/8 s, 4×8% P (:814). The shipped Hearten capstone adds a 65% splash to *every* ally within 8 m every 4 s (skill_trees.md:325). Heals currently crit ×2 (combat_stats.md:111-112).
- **Untalented throughput, recomputed:**

  | Spell | Shipped | Candidate | Change |
  |---|---|---|---|
  | Heal | 6.25% P/s | 2.67% P/s | −57% |
  | Shield | 2.5% P/s | 1.29% P/s | −49% |
  | Mend | 4% P/s | 1.33% P/s | −67% |
  | Group healing per extra ally | ≈4% P/s | 0.47% P/s | about −88% |

- **Mana efficiency** also falls: untalented Heal goes from 3.1 to 2.0 HP of P per mana point.
- **Why it matters:** elites (3–4× TTK), bosses, dragons and fortress PvP were all tuned with the shipped healer. Neither balance.md nor priest.md compares against shipped support, or against group or boss damage.
- **Misleading line:** balance.md:133 ("It does not reduce Mercy's … healing") is true only relative to the previous candidate.
- **Fix:** add a shipped-versus-candidate support table and a group-pressure check (a tank under 1–3 mobs, one elite, and the r36 boss model's incoming damage). Then either restore the support coefficients or state the cut as a deliberate role change for the user to approve.

## Medium

**M1. The package changes standing user rulings and "decided" rules but never lists them.** The TODO only says to "consolidate approved rules into their topic owners" (TODO:65-67). The following would have to be retired explicitly:
- **skill_trees.md §5 rulings:**
  - 2: chains, hard chains, 3–5 ranks, about 28 per tree.
  - 3: two keystones plus a capstone per tree.
  - 12: the Scout's base kit of four.
  - 13: one new skill per tree.
  - 9/29: Sprint, which *is* flagged.
  - 26: additive slows per axis. The strongest-only proposal changes this ruling, but the ruling is never named.
- **progression.md:107-121:** "no build carries more than two extra hotbar keys"; "the base kit granted at class choice stays, and talents improve its numbers".
- **combat_stats.md:713:** "mandatory baseline bands … Priest 12–16 s". The new free Smite (291.5/s untalented at L60) gives a 9.25 s TTK, outside the band even with the ±10% KAT allowance. priest.md:377-378 declares the band "evidence, not a new mandatory acceptance band"; a candidate cannot overrule that on its own. The same 219/s Smite benchmark also feeds `tools/r36_r/numbers.py`.
- Handoff decisions 3.1.2–3.1.4 already cover rulings 4, 13 and 19 in the user's own words. The rest need the user's explicit retirement.
- **Fix:** add a "rulings superseded or changed" table to implementation-design §1.

**M2. "Fire deals the most damage" does not hold once class crit and weapon choice are counted.** balance.md:90-99 compares everything pre-crit and picks a 1 s sword for Ruin (:94) and Veil (:97). scout.md:297 itself says the dagger leads, and Warriors may equip daggers (inventory_equipment.md:268). Recomputed at L60, unenchanted, expected crit (Warrior plus Keen Edge 14.45%, Scout 11.4%, casters 8.45%):

| Selection | Expected dmg/s |
|---|---:|
| Ruin, dagger (0.7 s, 11 rage/swing, 22-rage spender every other swing) | ≈613 |
| Ruin, sword | ≈511 |
| Veil, dagger, Parry-Opening every 12 s | ≈518 |
| Quarry (Loose, Aimed Shot, Follow the Line, Arrowfall; 25–28 m range) | ≈499 |
| Fire, Spark + Fireball | 503 |
| Fire, Spark + Fireball + Lance + Fire Rain | 573 |
| Priest, Reckoning 27/3 hybrid | 496 |

- Plate Ruin out-damages the glass cannon outright.
- Quarry matches Fire's two-button selection with more HP, dodge and range, and far less mana (0.9 vs 1.2–2.65% P/s).
- Handoff 3.1.6 only orders Fire against Frost, so this is a decision for the user, not a contradiction.
- **Fix:** add crit-inclusive rows, dagger rows for Ruin and Veil, and a short "intended cross-class damage order" statement for the user to confirm. The rage-per-swing model (+8/swing regardless of speed) is what makes daggers dominate Ruin.

**M3. In the 27/3 Priest hybrid, Mercy's attack talent beats Reckoning's own.**
- **Where:** M1 Steady Word is +0.15B (priest.md:159); R1 Sharpened Word is +0.12B (:183), both at gate 0.
- **Effect:** 27/3 (adding M1×3) outdamages pure Reckoning: 496 vs 458 expected dmg/s. It gives up only R5×2 (range) and one R7 rank (see the priest.md:281-282 sequence). Every offensive Priest therefore pays a 3-point Mercy tax, and "pure Reckoning" is a trap.
- **Conflict:** this contradicts handoff §4: "Mixed builds … give up identifiable strengths".
- **Fix:** give R1 at least M1's value and cap the combined bonus some other way, for example "Smite bonuses from both trees do not stack; the higher applies". The priest.md:313-316 low-level inversion check would then be unnecessary.

**M4. The four classes define incompatible action clocks. Mage and Priest defensives may be blocked by their own free attack.**
- **Where:**
  - **Mage (mage.md:68-71):** every skill, Blink and Ice Armor included, "reserve[s] 1 s before another attack/support action may start".
  - **Priest (priest.md:67-71):** occupied max(1 s, preparation) for every skill, "no queued cast bypasses it".
  - **Warrior (warrior.md:79-86):** self-casts take 0.35 s that "preserve rather than reset the existing swing timer".
  - **Scout (scout.md:106-111):** defensives may start during committed recovery and add 0.25 s.
- **The gap:** it is unclear whether Blink, Ice Armor or Shield can start inside the 1 s recovery of the Spark or Smite that is fired continuously. If not, the Mage's escape lags by up to 1 s in PvP.
- **Why it matters:** implementation-design §5 asks for one held-input state machine but provides no shared clock model.
- **Fix:** define one shared model in implementation-design §5 (an offensive-recovery clock plus a defensive overlap rule with a per-skill penalty) and give each class its parameters.

**M5. The Keen Cold correction does not achieve its stated aim (prevent open-ground kiting).**
- **The claim:** mage.md:169-170 says "A standard 4.6 m/s pursuer still closes at 4.048 m/s".
- **The problem:** against a 4.0 m/s player that is 0.048 m/s, about 0.5 m per 10 s, which is practically uncatchable.
- **With the starter Ice Wave** (35% for 3 s every 12 s), the pursuer's average speed drops below the player's:
  - additive slows (ruling 26): 3.65 m/s;
  - strongest-only: 3.78 m/s.
- **With Nova:** a 1.75 s root every 15 s averages ≈3.58 m/s.
- **Conflicts:** Rime's own identity (mage.md:17-18, "should not win … by running in circles"), handoff §4 ("without … endless low-damage kiting"), and the combat_stats.md:583 rule that the 4.6 > 4.0 inequality may break only for named, long-cooldown skills.
- **Fix:** keep the free slow at ≤5–7% (anything up to 7.6% keeps a ≥0.25 m/s close), or stop Cold Spark refreshing its slow while a stronger own slow or root is active. Also re-check this together with Ice Wave and Nova, not in isolation.

**M6. Haven, the Mercy ultimate, is worthless solo but is listed in the solo loadout.**
- **Where:** priest.md:217 lists Haven in the solo five.
- **Numbers:** solo, Haven gives the caster 10% P heal plus 10% P absorb for 22% P, 1.5 s stationary preparation and a 60 s cooldown. Heal gives 26% P for 8.8% P; Shield gives 24% P for 7.9%. Hearten is equally poor solo.
- **Comparison:** every other ultimate (Fire Rain, Winter Field, Unbroken, Ruination, Final Word, Arrowfall, Close Dance) has solo value.
- **Fix:** either give Haven a solo payoff (for example a larger self share, or damage reduction while its absorb holds) or describe Mercy's solo five without it and accept a group-only ultimate deliberately.

**M7. Aimed Shot, the first Quarry unlock, barely beats the free Loose it displaces.**
- **Where:** scout.md:144, scout.md:318-321.
- **Numbers (recomputed):** 1.80R in 1.35 s against 1.35 × 1.118R = 1.51R of Loose. That is +0.29R (+19%, +3.8% sustained) for 6% P, an arrow and half movement speed. The shared standard elsewhere is +45–80% per displaced action (Fireball 1.60 vs 1.00, Rebuke 1.8, Mighty Blow 1.45, Lance 2.20 in 1.25 s).
- **Inconsistency:** balance.md:60 rejected the 1.10D Fireball for exactly this reason.
- **Fix:** about 2.1–2.3R base, with Firm Aim kept smaller. Otherwise level 6 to 14 depends on a talent to repair the starter, which scout.md:63 itself rules out.

**M8. Whether a prepared hostile cast keeps its target is ambiguous.** This covers Flame Lance, Word of Ruin, Final Word and Aimed Shot.
- **Where:** priest.md:80-81 says "validate current aim, range and visibility again at release … never stored enemy memory"; scout.md:113 says "validate current aim/permission at start and again at release"; implementation-design.md:142 says "retain their candidate release-aim validation".
- **The gap:** none says whether a *different* hostile under the crosshair at release is accepted (retarget) or refused (same-target requirement). Two implementers would differ.
- **Fix:** state one rule in ability_targeting or implementation-design §5.

## Low

1. **The approved targeting owner names unapproved skills.** ability_targeting.md:44, 77, 103, §5-§7 bind rules to Heal, Shield, Mend, Hearten, Haven, Meteor, Fire Rain, Winter Field, Censure, Arrowfall, Split Shot and Parry/Opening. These are candidates (README:5-6). A "decided" docs/design file (AGENTS layer 1) then goes stale on any rename or cut. **Fix:** phrase each rule by mode (prepared friendly single target, automatic group support, fixed-area point, multi-release volley, auto-secondary multi-shot, reactive guard to empowered attack) and keep the skills as current examples.
2. **The Mage spec is an overlay with stale base values.**
   - **Stale base:** implementation-design.md:25 makes the handoff tables authoritative "amended by mage.md". Those tables still read F4 1.10D, Lance 1.8D, Fire Rain 0.45D, Nova 0.35D, R3 "Lingering Chill 14/16/18%" and R10 +0.10/0.20/0.30D.
   - **Internal contradiction:** mage.md:54 says "Everything else in the handoff's two talent tables remains the candidate". The R3 change to Keen Cold appears only later (mage.md:166-169), and the correction table at :43-52 omits it, yet balance.md:61 treats it as current.
   - **Fix:** give mage.md one complete node table, as the other three classes have.
3. **B8 Recover ranks 2–3 are dead.** Retort at Measured Answer 3 = 1.40S ≈ 0.175P. Rank 2's 20% = 0.035P is already over the 0.02P cap (warrior.md:104), even against elites (80% armor group) and even untalented (1.25S). Only rank 1 is below the cap. Pure Bulwark buys 3 ranks (warrior.md:194). **Fix:** let ranks scale the cap (for example 1/1.5/2% P) or make it a single rank. R7 Resolute Word (priest.md:189) is mostly capped by "50% of actual HP" against armored or elite targets.
4. **Absorb identity is ambiguous.**
   - **Shipped:** absorb contributions are keyed per skill name, so recasting "shield_spell" refreshes it (skill_trees.md:858-873).
   - **Candidate:** priest.md:106 says "Same caster's recast replaces", and :384 says "stacking independent shields" for two Priests. That is a per-caster key, which the shipped contract does not have. Hold Ground and Unbroken (warrior.md:114-116) have the same question.
   - **Fix:** state the key, (skill) or (caster, skill).
5. **Notation collisions.** S is the Warrior's Strike unit (warrior.md:39-41) but the level scalar in priest.md:49 and scout.md:34. "R1–R14" means Rime in the handoff and Reckoning in priest.md; R is also the Scout's ranged unit. Implementation-design §7 warns about unit conversion, so prefix the codes (MR/PK, for example) and rename the Warrior unit.
6. **Three different particle budgets:**
   - implementation-design.md:272: 24 preview particles, ≤0.3 s;
   - priest.md:417-419: 12/24/32, ≤1 s;
   - scout.md:403-404: 8/24/32, ≤0.4 s.
   One owner should hold the shared budget, in implementation-design §6.
7. **External and workstation references in a repo doc** (README.md:14, 21-26):
   - a chatgpt.com "space" page with German link text, which other agents and computers cannot reach (the handoff's purpose is resuming on another computer);
   - a `~/artefakte/…/build.py` generator that reads repo tables but is not versioned.
   **Fix:** drop the link (or mark it non-authoritative in English), and either move the generator into `tools/` or delete the regeneration instructions.
8. **Name audit (skill_trees.md §2.11, Round 31 precedent).** "Aimed Shot" and "Ice Armor" are exact two-word ability names from a well-known commercial MMO. Ruling 21 protects only single common words. Run the audit before freezing names.
9. **The handoff keeps stale rules inline.**
   - 3.1.1 still says "one at a time" (handoff:74-75).
   - §8 says "discuss Warrior, Priest and Scout one at a time … Do not invent their kits" (handoff:658-662).
   - Only the preamble (handoff:8-13) says they are superseded.

   **Fix:** add a one-line "superseded 2026-10-12" marker at both places.
10. **Censure fixes a vertical allowance of 2 m** (priest.md:112) while the TODO keeps vertical allowance open for all area spells. Mark it as a candidate value.

## Notes (not escalated)

- implementation-design.md:207-209 ("a low-level installment can be zero") and acceptance row :377 are moot: Arrowfall unlocks at L42 at the earliest, where 16% P ≥ 223.
- balance.md:101 "Rebuke **adds** approximately 626": 626 is the hit, and the increment over Smite is ≈294.
- PvP contact (pvp.md:69-73) lists only Heal, Shield and Mend. Hearten and Haven need adding when consolidating.
- Afterglow burn ticks break the hybrid's own Nova root (handoff:357). This is an anti-synergy in 15/15 builds; it may be intended.
- Several nodes appear in no worked build: B11, U13, M11, R10, V14. That is fine under "more attractive investments than points" and worth watching.
- Shipped names are reused with new semantics: Hearten (was a Heal-replacing capstone), Unbroken (was a passive capstone), Gentle Hand, Warding Faith. Note this for the migration's id mapping.
- ability_targeting §2 self-casts when the aimed ally is merely out of range. That is shipped behaviour, but implementation-design §8 claims fewer unintended self-heals. Decide whether out of range should refuse the cast.
- The root README.md links the unimplemented targeting file in the player-facing design tour. It is labelled "future", which is acceptable.

---

## Balancing: recomputed numbers

All at L60, P = 2696, B = 43.7, scalar 7.71167. Mage D = 337; Priest W+I = 291.5; Scout R = sword M = 291.5; dagger M = 237.5.

**Reproduced exactly:**
- Mage: 1.38D/s (465); Lance 2.97D and +1.47D per 9.25 s; Rime 1.027 and 1.111D/s (374); Fire 24% above Rime.
- Ruin 1.325S/s (447); Bulwark 1.067S/s (359); spender increments +14.4% and +32.5%.
- Exposure table: 0.02956P/s and 0.02533P/s; 19.70% and 19.37%; 6.6–9.7% with Hold Ground; Unbroken 58.51%.
- Priest: Smite 342.05 / 331.94 / 382.49; Rebuke 625.80; Word 466.40; Final Word 917.30.
- Expected-crit table: 370.95, 359.99, 414.81, 457.82, 495.85, 503.33, 572.64.
- 6 s openings: 3846 / 3736 vs 4276.
- Mana: Priest 2.26% vs Fire 2.65% P/s; Priest 30 s schedules 64 / 56.32 / 19.36 / 60 / 54 / 17.6% P.
- Scout: Loose 1.118 / 1.341R/s; Quarry 1.4818R/s (432); Veil 1.4055M/s (410); cycle 1.16R/s; Arrowfall 2.13 / 2.72R/s against 2.28R/s at the cadence floor; Veil mana 1.29% P/s; ammunition ×2.37.
- Arrowfall installments: 5/4/4/4.
- Low-level Priest/Fire inversion: at L12, 0.30B gives 14.89 against Fire's 14.76 (inversion); 0.27B gives 14.52 (none).

**Where the documents differ or understate:**
- Crit-inclusive values with the dagger option (see M2): Ruin dagger ≈613, Ruin sword ≈511, Veil dagger ≈518, Quarry ≈499. The balance table's pre-crit sword rows understate melee and Scout by 13–35%.
- The stated Priest/Fire relationship holds on the documents' own selections.
- Like-for-like, with every offensive button including the ultimate: pure Reckoning is 20% below Fire (458 vs 573) and the 27/3 hybrid 13% below. Whether that is still "slightly below" is the user's call.
- Aimed Shot: +3.8% sustained untalented (M7).
- Rime kiting averages: 3.65 / 3.78 / 3.58 m/s against the player's 4.0 (M5).
- Priest support: −49% to −88% against shipped (H1).

---

## Open decisions for the user (separate from the fixable errors above)

1. **Priest role:** is the large cut to single-target and group healing (H1) intended, in exchange for the free 1 s Smite (+33% untalented damage over shipped)?
2. **Cross-class damage order:** must Fire lead all classes, or only Frost and Priest? Is dagger Ruin above Fire, and Quarry at Fire's level with more safety, acceptable (M2)?
3. **Superseded rulings to retire explicitly (M1):** 2, 3, 12, 26 (slows), 9/29 (Sprint), the Priest 12–16 s TTK band, and progression §2's "two extra keys" and "base kit stays".
4. **Whether "slightly below" covers** the 13–20% gap in full-loadout Priest-vs-Fire damage.
5. **The size of Rime's free slow,** given the 4.6 > 4.0 invariant (M5); the strongest-only versus additive slow rule is already in the TODO.
6. **Whether Haven/Mercy may have a group-only ultimate** (M6).
7. Already listed in the TODO and still open: starters and initial placement, combat hotbar switching, area geometry, Arrowfall cone and timing, Split Shot ammunition shortage and ties, absorbed-hit triggers, repeated roots, Ice Cage, Scout controls and Sprint removal, migration and refund.
