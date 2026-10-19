# Class redesign: delivery plan

Planning draft, 2026-10-19. **The user confirmed the sequence (sections 2–5)
and the rulings table (section 6) on 2026-10-19.** It turns the
[continuation plan](continuation.md) §5 item 7 and §6 into a concrete
sequence under the user's "maximally simple" rulings
([§4a](continuation.md#4a-user-rulings-of-2026-10-19-a-maximally-simple-rework))
and the [skill inventory](skill-inventory.md). No round numbers are assigned
here; the user schedules the rounds. Documentation only.

## 1. What the rulings changed about the size

The engineering review rated the rework "large" because it reversed two
shipped principles of `classes.md`: "instant abilities + cooldowns, no cast
times" and "no global cooldown". **Under §4a both principles stay.** The
rework is now new kits, new talent graphs and a new Talents page on top of
the existing combat pipeline (damage, crit, dodge, armor, absorb, statuses,
projectiles). Of the review's ten shared primitives, five are gone
(preparation owner, pulsed areas, hit classification, projectiles at
explicit targets, area preview) and the rest are small, except the talent
graph, which the user keeps on purpose.

Realistic scope: **two delivery rounds** plus an art lane that runs ahead.

## 2. Closing the planning (before the first delivery round)

| Step | Content | Owner |
|---|---|---|
| P1 | ~~Confirm the rulings table in section 6~~ — confirmed 2026-10-19 | user |
| P2 | **Balance calculator page** (artifact, outside the repository): class, tree, level, gear → hits to kill a normal and an elite mob, HP lost per fight, fights per mana pool, today versus new, from the inventory's numbers. The user tunes by feel; the result freezes the numbers per class | coordinator builds, user tunes |
| P3 | Names for the two skills that carry exact names from a well-known commercial game ("Aimed Shot", "Ice Armor") and any other name the user wants changed | user picks from proposals |
| P4 | Final node list per tree (inventory minus cut nodes such as Shelter, plus the decided renames): the input for the art lane and for the class lanes | coordinator |
| P5 | Independent review of the finished plan against the code (continuation §5 item 7) | reviewer agent |

## 3. Art lane (runs ahead, parallel to other rounds)

Starts after P4. Astra drafts, the user picks on a review page, nothing
ships without the pick.

- 8 tree backgrounds (one per tree) with room for the node grid; the
  connection lines are drawn by the page, not baked into the image, so a
  later graph change does not need new art.
- About 80 talent icons (an unlock node shows its skill's icon) and about
  30 new skill icons.
- Element overlay strips for the weapon effect (fire, frost, holy, …), as
  short vertical-frame animations.

The **weapon overlay code** (animated `wield_overlay` per skill item) is a
small independent lane that can join any round once the strips are picked;
it also works for today's skills.

## 4. Round F: foundation (compatible)

Goal: every building block exists and the new Talents page runs, while the
shipped classes play exactly as before.

| Lane | Content | Files it owns |
|---|---|---|
| SPLIT | Mechanical pre-split: `kits.lua` (1166 lines) and `talents.lua` (1410 lines) into per-class files. No behaviour change. Merges first; the other lanes branch from it | `grug_abilities/kits*.lua`, `grug_classes/talents*.lua` |
| CORE | B2 per-skill occupied time in both directions (swing ↔ cast) with today's values reproduced; the shared area query (radius, ±3 band, LOS from the anchor); the ground anchor and its refusal; the delayed one-shot area with particle warning; per-class basic attack with in-place transformation (B9); window keys for readiness (B8); the group-recipient helper; Mend moved onto `set_status`. PvE before/after run on the combat path: unchanged numbers | `grug_abilities/init.lua`, `input.lua`, `strike_delay.lua`, `grug_core` combat/status helpers |
| GRAPH | Graph talent registry and validator (per-node gate, multi-parent prerequisites, data-driven modifiers); the Talents page with **one inner tab per tree**, background image slot and drawn connection lines; **today's trees converted 1:1 into the new format**, so the engine ships with known content and no migration | `grug_classes/talents*.lua` registry part, `talents_ui.lua` |
| D | Docs and status | docs |

Classification: **compatible** (no saved state changes; today's talent ids
keep their meaning). The user's GUI check covers the new Talents page and a
normal fight per class.

## 5. Round K: the new classes (migrate)

Goal: the four new kits and talent graphs, one migration, then the user's
playtest.

| Lane | Content |
|---|---|
| MAGE, WARRIOR, PRIEST, SCOUT (parallel) | Each owns its per-class kit and talent files: skills, talent data, tooltips and its own fixture, built only from the foundation's blocks. **A lane that needs a new mechanic stops and reports** instead of building it. The Scout lane deletes the bow draw |
| INTEG (after the class lanes, or parallel with strict file ownership) | The migration step: reset every character's talents with all points refunded, clear stored talent windows, remove retired skill items from hotbars A and B and the bags, replace Strike in place with the new basic attack for Mage and Priest; HP class factors 0.8/0.8/1.0/1.2; retired ability ids; web data export; Help texts; art integration; the retire/rewrite list of the about 42 tool files that pin today's kits |
| D | Docs: `classes.md`, `skill_trees.md`, `combat_stats.md`, `ability_targeting.md` consolidated from the planning package; the planning TODO deleted |

Classification: **migrate** (talent ids are reused with new meanings; a
declared step clears them). Only the user's production world exists, so a
talent reset with full refund is enough; no per-talent conversion.

After the merge: the user's playtest per class, then a short balance fix
round in the user's iteration style (first version by feel, the user names
the fixes).

## 6. Rulings superseded or changed (for P1)

| Ruling today | Where | Proposal |
|---|---|---|
| Instant abilities + cooldowns, no cast times | `classes.md` (opening principles) | **kept** (§4a) |
| No global cooldown | `classes.md` (opening principles) | **kept** (§4a) |
| Tree shape: two chains, keystones and one capstone per tree; at most one keystone adds a skill; no build carries more than two extra hotbar keys | `skill_trees.md` §5 rulings 2, 3, 13; `progression.md` §2 | **replaced** by the candidate graphs with one ultimate per tree; a normal loadout uses 4–6 skills, owning more is allowed |
| New skills only from the tree; the base kit granted at class choice stays | `progression.md` §2 | **changed:** new starters per class (Mage Spark + Ice Wave, Priest Smite + Heal, Scout Loose + Sidestep + Sprint, Warrior Strike + Charge); Mighty Blow and Taunt move into the trees |
| Sprint +50 % for 10 s, 300 s cooldown | `skill_trees.md` §5 rulings 9, 29 | **kept** (inventory question 6) |
| The Scout as simple as possible | `skill_trees.md` §5 ruling 12 | **kept** |
| Movement aggregator, additive per axis with one clamp | `skill_trees.md` §5 ruling 26 | **kept**; new slows use it |
| Priest TTK band 12–16 s (normal 8–12 s) | `combat_stats.md` | **orientation only**, re-measured in the playtest after the HP change; no hard gate |
| Ordinary pursuit speed 4.6 above the player's 4.0 | `combat_stats.md` | **kept**, with the Frost exception of M5 (kiting with slows is Frost's advantage) |
| HP class factors 1.20 / 1.00 / 1.00 / 0.90 | `combat_stats.md` §2, `grug_classes/stats.lua` | **changed** to Warrior 1.2, Scout 1.0, Priest 0.8, Mage 0.8 |
| Area points with preview and prepared capture | `ability_targeting.md` §4 | **changed** to the ground anchor of the inventory §3a, no preview |
| Talent unlocks place nothing; transformations replace in place on A and B | Round 50 ruling 12 | **kept** |

## 7. Risks and how the plan contains them

- **Shared files.** `grug_abilities/init.lua` (2543 lines) and `input.lua`
  (853) belong to CORE alone in round F. In round K the class lanes touch
  only their per-class files; INTEG owns the rest.
- **Scope creep.** The building-block list is closed. A new mechanic needs
  the user's ruling first.
- **Feel.** Numbers are frozen through the calculator page before round K
  and corrected after the playtest, not argued on paper.
- **Old tests.** About 42 tool files reference today's kits or talents; INTEG
  owns the retire/rewrite list, so class lanes do not fight over them.
