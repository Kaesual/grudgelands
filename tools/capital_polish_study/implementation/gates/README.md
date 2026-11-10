# Capital arch implementation

User-approved 2026-11-10. Classification: **map reset** (building templates).
Worktree `character-creation`; no writes to main, version metadata or baselines.

Installed in the five capital `*_gate_south.tpl` templates (Highcourt,
Dur Brannoc, Lethariel, Gor Drazhak, Nhal Veyr). Exactly 14 cells per template:
local x=4/8, y=5, z=0…6 now use facedir 21/23 instead of 1/3. Each matches the
approved study's node geometry. Kezamba has a different gatehouse and is unchanged.

Separate legend keys V/W are necessary: H is also used by the watch room's
ascending stairs. Those remain unchanged. The editor prunes unused old key I;
all points, bounds, materials and other cells remain unchanged.

## Save and evidence

- `install.py` uses the actual `serve.Editor.save` path, including the shared
  validator, canonical serializer, stale-source protection and atomic writes.
  It does not bypass validation or write templates directly.
- `before/` preserves source files. The earlier study remains unchanged.
- `save-audit.json` records saves and source/output hashes. The initial Highcourt
  save succeeded but a post-save assertion compared source line numbers in point
  metadata. Its semantic comparison was corrected without repeating the validator
  or touching that template again. Remaining four save receipts are complete.
- Editor warnings concern the existing two guard post sockets (4,1,1)/(8,1,1).
  Their geometry, entrance geometry and every node below y=5 are unchanged.
  These coarse reachability warnings are not a new navigation claim.
- `evidence.py` resolves all five installed templates through their actual roster
  palettes and proves exactly 70 orientation changes, unchanged sockets/other cells,
  and exact equality to the approved Human proposal's displayed geometry.
- `scenes.html` is the self-contained interactive rendering of the installed
  Human gate. `renders/gate-installed.png` and its receipt are the real shared
  web renderer's capture at the approved camera. It is byte-identical to the
  approved proposal PNG. This is not a native-client runtime test.

The extra castle gable diagnosis was handed to the castle owner: 36 inverted roof
slabs per castle, at z=8/32, odd x=5…39 and
`y=18+floor(min(x-4,40-x)/2)`, leave 0.5-node gaps above the wall blocks. Replacing
these gable-edge slabs with a full block of the same roof palette closes their
lower halves without changing the upper roof profile. Castle files are not owned
by this lane.

Global template/upgrade gates and independent review are coordinated by the parent.
No Lua source files changed; no separate broad fixture run performed.

Independent review: `tables_study`, 2026-11-10, **MERGE**, no findings. It separately
resolved HEAD and the final templates through their actual palettes, checked all
70 exact orientation edits and unchanged remaining cells, checked engine rotation
and actual nodebox octants, and visually inspected the capture. Full report:
`../tables/review-gates.md`.
