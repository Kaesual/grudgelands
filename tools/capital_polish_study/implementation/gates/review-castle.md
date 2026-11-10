# Independent castle implementation review

2026-11-10 · reviewer: `gates_roof_study` · author: `throne_study`.

**Verdict: MERGE. No blocking findings.** Classification: **map reset**, correctly
required for the six shipped building-template changes. This records the completed
review; no additional tests or renders were run to write this report.

Reviewed the six installed king-hall templates against their preserved originals,
the approved throne variants, and the approved pillar study's `variants.json`.
Read the editor-save implementation, verification code and saved receipts. Direct,
independent parsing and palette resolution established:

- Exactly 502 intended semantic template-cell changes per castle: 42 throne,
  374 pillar/side-wall, 50 ridge and 36 gable-edge cells. No other semantic cell
  changes. Kezamba resolves ten changed wall-role cells to the same basalt,
  explaining its 492 resolved-node differences without weakening the scope check.
- All 16 points per template retain their coordinates, faces, groups and attributes;
  only source-line offsets change. Template bounds and placement stay intact.
- The 42 throne changes match the approved variants in all six cultures. The seat
  is one node above the dais, arm tops one node above the seat; crown and ornaments
  descend with the chair.
- The Human pillar changes match every approved resolved value. The selected piers
  join the outer buttresses, bays open into the hall, lamps follow their supports,
  and the projecting bench seats are removed as approved.
- Every castle's 25 ridge pairs use the correct full-block/lower-slab replacement,
  lowering the same 1.5-node group by exactly half a node.
- All 36 gable-edge gaps per castle use full blocks from that castle's roof palette.
  Their upper surface stays unchanged while the lower half closes the gap to the
  wall. The supporting wall cells remain unchanged. This diagnosis was also
  independently established before implementation.

All five rendered PNGs match their output hashes and scene-input receipts. The
roof before/after cameras match. Visually inspected `roof-before.png`,
`roof-final.png` and `pillars.png`: the periodic half-node openings and floating
ridge are closed, and the bays/pillars agree with the intended geometry.

The author used the actual template editor's validated Save path; the six save
receipts report no errors or warnings. No production/main files outside the
worktree were touched by this review. No native pathfinding or gameplay acceptance
is claimed; broad integration gates and the user's desktop/web acceptance remain
the coordinator's responsibilities.

Evidence reviewed: `../castle/install.py`, `verify_render.py`, `before/`,
`proposed/`, `save-report.json`, `verification.json`, `scenes.html`, `renders/`;
approved sources: `../../throne/variants/` and `../../castle/variants.json`.
