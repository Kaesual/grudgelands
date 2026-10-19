# Four-class redesign review package

**Parked future work package (2026-10-12).** Not part of the next round and
not to be implemented before a dedicated preparatory planning round has
closed every open point. Status, the user's decisions on the two reviews and
the adopted simplifications: **[continuation plan](continuation.md)** — start
there when the rework resumes. Review records: [design](reviews/design-review-2026-10-12.md),
[engineering](reviews/implementation-review-2026-10-12.md).
**2026-10-19:** the user's "maximally simple" rulings (continuation §4a) and
the [skill inventory](skill-inventory.md) that applies them to every skill
override the candidates where they conflict.

Prepared 2026-10-12 for round planning. The user supports the overall direction
and approved the [first-person targeting contract](../../design/ability_targeting.md).
Talent graphs, numbers and the remaining choices are still candidates; this
is not full design acceptance. Classification: **compatible, documentation
only**. No gameplay implementation, icons or artwork were made.

After the continuation plan, **read the [implementation design](implementation-design.md)** for the
class roles, complete skill targeting map, cast/resource lifecycle, technical
seams, proposed planning sequence and acceptance cases. It links the detailed
class tables instead of creating a competing numerical specification.

Reader overview in German: [Grudgelands Klassenredesign Entwurf](https://chatgpt.com/space/page_46c66c627a4881919e4dfe25dc1b193d).
It presents the four classes, eight trees, example loadouts and a short balance
section. It is a derived review aid; the detailed proposals below retain the
numbers and assumptions. The initial wide overview tables have been replaced
with interactive talent diagrams: switch between each class's two trees and
select a node for effects, ranks and prerequisites.

HTML previews, their template and generator are external review artifacts,
stored at `~/artefakte/grudgelands-klassenredesign/` on the user's workstation,
not in this repository. Open `talent-trees.html` there for all eight trees.
Regenerate from the repository root with
`python3 ~/artefakte/grudgelands-klassenredesign/build.py --repo "$PWD"`.
The generator reads the candidate tables and Mage amendments; HTML is never
an independently editable rules owner.

The initial diagram review checked 110 nodes and 57 prerequisite edges, all
eight trees at widths 320/600/960, 330 detail openings and optional host-state
persistence. The authenticated Page viewer was not observed. Follow-up targeting
changes preserve the graph; source values and uploaded descriptions are
refreshed from the current candidates. Validation of future gameplay is separate.

The user requested three parallel Astra class drafts and coordinator review
against the existing Mage, followed by a balancing correction round. This
supersedes the older handoff's request to discuss the remaining classes one
at a time. The rough direction is comparable solo usefulness, with distinct
identities; Bulwark may level somewhat more slowly in exchange for noticeably
greater robustness. No fixed parity band was introduced.

## Candidates

| Class | Trees | Detailed proposal |
|---|---|---|
| Mage | Ember / Rime | [Reviewed Mage amendments](mage.md), applied over [the original handoff](../class-redesign-handoff.md#5-mage-design-proposal). |
| Warrior | Bulwark / Ruin | [Full Warrior candidate](warrior.md): early counterattack, bounded recovery, rage spending and active defense. |
| Priest | Mercy / Reckoning | [Full Priest candidate](priest.md): free attack, deliberate support time and paid hostile bursts. |
| Scout | Quarry / Veil | [Full Scout candidate](scout.md): quick click-to-fire bow and blade openings through active defense. |

Each new candidate includes complete talent tables, prerequisites, active
skill timing/costs, progression, legal 30-point purchases, four-to-six-skill
loadouts, resource failure and PvP counterplay. Owning more than six skills
remains allowed. The Mage's existing tables/allocations stay in the handoff;
`mage.md` explicitly owns this review candidate's amendments rather than
duplicating those tables as a second editable specification.

[Cross-class balance review](balance.md) records assumptions, comparisons,
corrections and remaining limits. [Open decisions](../../../TODO-design-classes.md)
remain open until the user has inspected the overview and selected the design.

## Review and verification receipt

- The coordinator read the handoff completely and independently reviewed all
  three class drafts against it, current combat formulas and the user’s request.
- Each of the three drafts received a correction round. The Mage also received
  amendments and an independent review by an agent that did not author them.
- An additional independent arithmetic review of the coordinator's synthesis
  found and corrected omitted Parry occupation and release-based cooldown
  recurrence. No preparation during an existing cooldown is assumed.
- Arithmetic verification parsed all **21 worked 30-point purchase sequences**:
  five Mage, five Warrior, five Priest and six Scout. Rank limits, same-tree
  gates, prerequisites and totals passed. Prerequisite graphs have no cycles;
  each talent has a legal purchase path within 30 points.
- The follow-up Priest/Fire audit adds a verified 27/3 offensive Priest
  allocation (**22 checked sequences in total**) and includes expected crits,
  paid attacks and ultimates. The user clarified the damage-role direction;
  its authority is recorded in the handoff, with tuning in the candidates.
- Purchasable ranks: Mage 32/33, Warrior 33/33, Priest 34/34, Scout 32/33.
  Every ultimate is a one-point purchase after 20 points in its tree, so two
  ultimates require at least 42 points.
- Mathematical examples are paper estimates. They do not establish practical
  kill times, engine feasibility, PvP balance or desktop/web acceptance.
  No gameplay fixtures or engine runs were needed for this proposal-only task.

The [handoff](../class-redesign-handoff.md) remains the earlier conversation
record; the new ability-targeting owner explicitly labels approved future behavior.
The other topic owners continue to describe shipped gameplay.
