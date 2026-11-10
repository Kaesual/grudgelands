# Independent review: installed guild tables

2026-11-10, reviewer `throne_study`; read-only review of the table lane.

**Verdict: MERGE / PASS. No blocking findings.** Classification **map reset** is
correct for changed generated building templates. The coordinator's combined
global template and upgrade gates remain the integration requirement.

Reviewed `tools/r58_halls/make_halls.py`, its six shipped `*_miners_guild.tpl`
outputs, the table study's recorded accepted cell positions, implementation
verification/render adapter, evidence records and actual-output PNG.

Independent checks performed:

- `python3 tools/r58_halls/make_halls.py --check` passed for all six outputs.
  The authoring source declares these as generated outputs; the change lives in
  that generator, so regeneration does not restore the old furniture.
- Parsed all six originals directly from `HEAD` and all six working-tree outputs.
  Compared cell meanings rather than legend letters: exactly 11 furniture cells
  change per building, matching the previously accepted coordinates. Ten become
  `grug_decor:xdecor_table` and the clerk's old upper slab becomes air.
- All points and their attributes, bounds, origin and pivot remain unchanged.
  Every current output hash matches the lane's verification record.
- The existing table node has a 1/8-node top from y=0.375 to0.5 and a supporting
  leg ending exactly at0.375; a placed node at y=1 stands on the floor surface
  y=0.5. There is no gap between the support and top or an extra slab above it.
- Source diff is confined to table emission and its explanatory comments.
  No new node, extra service socket, NPC movement or renderer approximation.
- The Human actual-output PNG was visually inspected: lower supported tables,
  continuous adjoining desk tops and visible reference figures. Its capture
  input and output hashes match `scenes.html` and the PNG.
- The lane's recorded focused fixture result is 2195 checks passed. It was
  inspected, not rerun, because no new discrepancy warranted repeated execution.

No global validators, expensive runtime, new render or native-client acceptance
was performed by this review. No production files were modified by the reviewer.
