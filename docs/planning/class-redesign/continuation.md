# Class redesign: status, decisions and continuation plan

Recorded 2026-10-12 after two independent read-only reviews of this package.
**Start here when the class, skill and talent rework resumes.** This file
records the package's status, the user's decisions on the review findings, the
adopted simplifications and the preparatory planning round that must come
before any implementation. The candidate files keep their numbers; where this
file decides against a candidate, this file wins until the candidates are
corrected.

## 1. Status: parked future work package

- **Not part of the next round.** The user moved the next round's focus to
  world generation (seed-dependent POI placement, ore/gem/coal distribution)
  and player-feedback fixes. Player feedback (2026-10-12) ranks other
  problems above classes, skills and talents.
- **No implementation before the planning is complete.** The rework is very
  large (the engineering review estimates about two rounds of implementation).
  It starts only after a dedicated preparatory planning round (section 5) has
  closed every open point thoroughly and without gaps.
- The preparation itself is good and stays the basis: the four candidates,
  the balance review, the implementation design and the approved targeting
  contract (with the reservation in section 3, M8).
- **2026-10-19:** the user's "maximally simple" rulings (section 4a)
  override the candidates and parts of sections 4–6 where they conflict.
- One item is pulled forward into the next round independently of the
  redesign: **Warrior rage per hit scales with weapon speed** (section 3, M2).

## 2. Review records

| Review | Scope | Verdict |
|---|---|---|
| [Design review](reviews/design-review-2026-10-12.md) | Consistency, logic and balancing; numbers recomputed | Ready for implementation planning after fixes; Priest support and the cross-class damage order need decisions |
| [Engineering review](reviews/implementation-review-2026-10-12.md) | Reuse, cost drivers, simplifications, migration and test risks | Large; ten shared primitives drive the cost; build them once before any class work |

The reviews are records of the 2026-10-12 state. Their findings are
hypotheses checked by the coordinator where cited below; re-check line
numbers before acting on them.

## 3. User decisions on the review findings (2026-10-12)

| Finding | Decision |
|---|---|
| **H1** Priest support output falls 50–90 % below the shipped kit | **Unintended.** The intent was only that the Priest must not be a "better Mage" (equal damage plus healing). Solve that through the talent split, not by cutting healing: a **healing Priest** deals less damage than a Mage, roughly somewhat below a Frost Mage but without Frost's slow; a **damage Priest** deals somewhat less than a Fire Mage because it keeps Heal and Shield. Priest healing must not be reduced this far; restore support output close to the shipped level and balance it. The planning adds a shipped-versus-candidate support table and a group-pressure check (a tank under 1–3 mobs, one elite, the Round 36 boss model). |
| **M1** Standing rulings changed without being listed | To be discussed in the preparatory planning round (section 5, item 1). |
| **M2** Fire is not the damage leader once crit and daggers count; fixed +8 rage per swing makes daggers dominate | **Rage per hit must scale with weapon speed:** a slower weapon gives more rage per hit, so rage per second does not favour fast weapons. This is a fix to the shipped Warrior and is **planned for the next round**, ahead of the redesign. The redesign's comparisons are then redone with crit and with dagger rows. The intended cross-class damage order (must Fire lead every class, or only Frost and Priest?) is still open. |
| **M3** Mercy's Smite talent (M1, +0.15B) beats Reckoning's own (R1, +0.12B), so pure Reckoning is a trap | Fix in the planning, for example R1 at least as strong as M1 and the two bonuses not stacking (the higher applies). |
| **M4** The four classes define incompatible action clocks | Resolved in direction by simplification 2 (one shared action clock and one preparation mechanism, set per ability). Still to settle: whether a defensive skill (Blink, Ice Armor, Shield) may start during the recovery of the free attack, and with which penalty. |
| **M5** Keen Cold lets a Frost Mage kite endlessly | **Acceptable as Frost's advantage.** Kiting carries its own risk (running into and pulling other mobs). Endless kiting must not be too easy and must need a reasonably good rotation. The candidate's stated aim "prevent open-ground kiting" (mage.md) and the 4.6 > 4.0 pursuit rule in `combat_stats.md` need an explicit Frost exception in the planning. |
| **M6** Haven, the Mercy ultimate, has no solo value | Replace it with a better ultimate, for example an area heal that ticks several times and is useful solo as well. |
| **M7** Aimed Shot barely beats the Loose shots it displaces | It must give clearly more (the design review suggests about 2.1–2.3R base). |
| **M8** Whether a prepared hostile cast keeps its target | **The target at the moment of starting counts.** More generally, fixed prepared casts fit the crosshair model poorly. The planning re-examines every prepared skill and either replaces it or moves it to the Scout bow model: **holding the button slows movement and charges the skill; only releasing triggers it.** This reservation also applies to the prepared-cast parts of the approved [targeting contract](../../design/ability_targeting.md). |

The design review's Low findings are accepted as planning work (section 5,
item 4).

## 4. Adopted simplifications

The user accepted all eight simplifications of the engineering review. They
are part of the future plan:

1. **Area footprint:** horizontal radius + vertical band ±H + line of sight
   from a point just above the anchor, for damage and preview alike, instead
   of the per-column surface/air footprint. The preview becomes a ring of
   about 12–16 points plus a centre mark.
2. **One action clock and one preparation mechanism** for all four classes,
   parametrised per ability (preparation, occupied time, releases, stance,
   movement cancel). Sub-step preparations (Loose and Snare 0.18 s, Flourish
   0.25 s) become instant with their occupied time.
3. **Scout controls:** today's dual mapping becomes Bladecraft (LMB melee,
   RMB bow); Loose becomes a plain LMB bow skill whose held button repeats.
   "RMB = melee" on Loose is dropped.
4. **Hit classification by exception:** every hostile hit counts as direct
   unless its source is tagged area or periodic; about eight known sources
   are tagged.
5. **Modifier talents as data:** parametrised effect keys
   (`damage_pct:<tag>`, `cost_pct:<tag>`, `cooldown_sub:<id>`,
   `radius_add:<id>`, `duration_add:<id>`, `range_add:<tag>`) read by one
   ability-parameter pipeline from per-ability base tables.
6. **Readiness cues as status icons** (Retort, Cold Shock, Clear
   Conscience, Follow the Line, Parry guard, Opening, Close Dance,
   Ruination).
7. **Cut or defer:** Afterglow's burn becomes a Fireball damage rank (no mob
   damage-over-time system); Shelter folds into Warding Faith; Winter Field
   re-applies its slow per 1 s pulse; repeated-root diminishing returns and
   the talent line-art image are deferred.
8. **Arrowfall scheduling:** at most one release per input pass, never a
   catch-up burst; under lag the volley stretches. *(Superseded by §4a:
   Arrowfall becomes a one-shot effect.)*

## 4a. User rulings of 2026-10-19: a maximally simple rework

The user's goal: as few new mechanics as possible, still a noticeable change
and new class progression, and a round of manageable size. The combat system
must stay simple and performant, especially on the server. Where these
rulings contradict the candidates or sections 3–6, this section wins. The
[skill inventory](skill-inventory.md) applies them skill by skill.

1. **No cast or preparation times, no hold-to-charge and no global
   cooldown.** A skill may instead occupy a longer time *after* the cast.
   Work mostly with cooldowns. This resolves M8: every prepared skill
   becomes instant; single-target support resolves its recipient once, at
   the cast.
2. **Every area effect triggers exactly once.** No channels, pulses or
   persistent ground areas. Example: Fire Rain becomes a larger, more
   impressive-looking meteor shower that hits once.
3. **No area preview while aiming.** An area with a short fixed delay shows a
   warning of a few particles at the impact point (for example floating fire
   particles before the meteor lands). Particle size has no engine cap, so a
   few large falling "meteor" particles are allowed within the particle
   budget (hundreds in total, never thousands).
4. **Heal-over-time is a status effect** cast once on the target that then
   runs there as an ordinary effect (`grug_core.set_status` already supports
   ticks). An area heal is a one-shot area that places that status on every
   friendly player hit; it keeps running when they leave the area.
   Damage-over-time, if a skill needs it at all, is likewise an effect on the
   target.
5. **Cut expensive one-off mechanics.** No incoming-hit classification, no
   dodge-triggered effects, no multi-release volleys, no projectiles at
   explicitly chosen secondary targets. A skill that needs one is redesigned.
6. **The new talent trees stay** as the core of the rework: the candidate
   graphs, **one inner tab per tree** (not both trees side by side), a
   background image per tree with its connection lines and a few fitting
   graphic elements, and **one icon per talent**. This reverses the deferral
   of the talent line-art image in §4 item 7.
7. **HP class factors:** Mage **0.8**, Priest **0.8**, Scout **1.0**,
   Warrior **1.2** (shipped: 0.90 / 1.00 / 1.00 / 1.20).
8. **Weapon effect per skill:** the selected skill shows an animated
   `wield_overlay` on the first-person weapon, one overlay per element (fire,
   frost, holy, …). Skill items only appear in first person, so third person
   is unaffected. Independent of the rework; the web client is 5.17.
9. **Area anchor is always ground** (details in the
   [skill inventory §3a](skill-inventory.md#3a-area-anchor-always-ground-user-2026-10-19)):
   a targeted enemy gives its position at the cast, otherwise the terrain
   hit; the skill searches ground up to 3 nodes below that point and damages
   within ±3 of it, with line of sight from the anchor. No ground found
   refuses the cast before cost and cooldown ("No ground found."). Areas
   work in caves.
10. **The ten cross-class questions** of the skill inventory (§3) are decided
   as recommended there (user, 2026-10-19).
11. **Out of the class rework:** Hotbar A/B shipped in 0.50.0 (Round 50).
   The food-on-the-belt interaction and the tool consolidation of the
   [handoff](../class-redesign-handoff.md#72-consumables-belt-and-eating)
   §7.2/§7.3 are separate proposals, not part of this rework.

## 5. Preparatory planning round (before any implementation)

A design-only round that closes the package. Its result is a complete,
reviewed plan; only then are implementation lanes briefed.

1. **Rulings.** Discuss and explicitly retire or keep every ruling the
   redesign changes: `skill_trees.md` §5 rulings 2, 3, 12, 13, 26 (slows)
   and 9/29 (Sprint); `progression.md` §2 "no build carries more than two
   extra hotbar keys" and "the base kit granted at class choice stays"; the
   Priest's 12–16 s TTK band in `combat_stats.md`; the 4.6 > 4.0 pursuit rule
   for Frost (M5). Record the result as a "rulings superseded or changed"
   table in the implementation design. Already decided (user, 2026-10-16,
   [round 50 plan](../round50-plan.md) ruling 12): talent unlocks place
   nothing on a hotbar, and a talent that turns a skill into a variant
   that is a different skill (for example Retort replacing Strike)
   replaces the old skill in place on every hotbar layout, A and B, that
   holds it.
2. **Prepared skills (M8).** *Decided by §4a item 1: every prepared skill
   becomes instant with a longer occupied time after the cast.* Remaining
   work: set each skill's occupied time and update the targeting contract
   (no retained recipient, no charge, no preview).
3. **Balance corrections:** H1 (Priest support back near shipped, damage
   split per section 3), the intended cross-class damage order with crit and
   dagger rows after the rage fix (M2), M3, M5 with its Frost exception, M6
   (new Mercy ultimate), M7 (Aimed Shot), and the "slightly below" question
   (pure Reckoning is 20 % and the 27/3 hybrid 13 % below full-loadout Fire).
4. **Document fixes (design review, Low):**
   - phrase the targeting contract by mode, with skills as examples;
   - give `mage.md` one complete node table instead of an overlay;
   - fix Recover's dead ranks 2–3;
   - define the absorb key ((skill) or (caster, skill));
   - remove the notation collisions (S, R, R1–R14);
   - ~~give the preview particle budget one owner~~ (no previews, §4a);
   - remove the chatgpt.com link and the `~/artefakte` generator
     instructions from `README.md`, or move the generator into `tools/`;
   - rename "Aimed Shot" and "Ice Armor" (exact ability names from a
     well-known commercial game);
   - mark the handoff's "one class at a time" rules (3.1.1, §8) as
     superseded;
   - mark Censure's 2 m vertical allowance as a candidate value.
5. **Engineering ambiguities A1–A12** of the engineering review (gesture,
   movement cancel, anchor point of airborne or mounted actors, preview
   representation and web-client support, "visible from the caster",
   hit taxonomy, Arrowfall timing, Split Shot tie-break and the production
   engine version for `get_guid()`, action clock versus swing clock,
   cancelled preparation, hotbar scrolling, per-class Strike).
6. **Open choices already in the [TODO](../../../TODO-design-classes.md):**
   starters and initial placement, absorbed-hit triggers, repeated roots, Ice
   Cage, Sprint removal, migration and refund. Combat hotbar switching
   shipped with Hotbar A/B (0.50.0); the Arrowfall cone and Split Shot
   ammunition questions fall away with §4a; food belt and tools are out of
   this rework (§4a item 11).
7. **Delivery plan:** drafted in the [delivery plan](delivery-plan.md)
   (2026-10-19). Originally: the engineering review's sequence (section 6), the
   migration step and the test retire/rewrite list, then an independent
   review of the finished plan.

## 6. Implementation outline (for the later delivery rounds)

From the engineering review; to be confirmed by the preparatory round.
**§4a removes several primitives below** (preparation/charge owner,
pulsed areas, incoming-hit classification, projectiles at an explicit
target, the area preview, the fake clock for preparations); the
[skill inventory](skill-inventory.md) lists the remaining building blocks.

1. **Mechanical pre-split** (compatible): `grug_abilities/kits.lua` (all four
   classes, 1115 lines) and `grug_classes/talents.lua` (all trees, 1370
   lines) into per-class files, so that parallel lanes do not collide.
2. **One serial foundation lane** for the shared primitives: action clock,
   preparation/charge owner, area query, delayed/pulsed area at a fixed
   anchor, readiness windows, incoming-hit classification, transformation
   with a shared cooldown key, the graph talent registry and validator,
   projectiles at an explicit target, actual-HP damage receipts, the
   caster-only area preview.
3. **Four class lanes in parallel**, then UI, tooltips and web data, then the
   migration.
4. ~~Hotbar A/B is its own lane~~ — shipped in 0.50.0 (Round 50); see
   `docs/design/inventory_equipment.md`.
5. **Migration:** about 22 old talent ids are reused with new meanings
   (`hold_ground`, `broadstroke`, `mend`, `word_of_ruin` and others) and
   would be silently reinterpreted. A declared step clears talents, stored
   talent-ready timers and retired skill items, with an end-to-end test.
   Existing Mages and Priests who lose Strike need their new basic attack
   placed (or a ruling). Retired ability ids need removal.
6. **Tests:** a retire/rewrite list for the roughly 40 tool files that pin
   current kits, a fake monotonic clock for preparations, new particle budget
   rows, about 30 placeholder skill icons, the web data export, the PvE
   before/after run for combat-path changes, and GUI checks for preview
   legibility and mouse behaviour on desktop and web.

Realistically two delivery rounds: the foundation plus two classes, then the
other two classes plus UI and migration.
