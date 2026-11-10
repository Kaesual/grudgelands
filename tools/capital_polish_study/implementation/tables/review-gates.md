# Independent gate review — 2026-11-10

Reviewer: `tables_study`, independent of `gates_roof_study` implementation.
Verdict: **MERGE**. No blocking findings. Classification **map reset** is correct
because shipped authored world-generation templates change.

Scope: the final five `*_gate_south.tpl` files named by
`../gates/checks.json`, plus the editor-save adapter and supporting evidence.
No other lane or global release gate is certified by this review.

## Independently checked

- Read each template's pre-change version directly from `git show HEAD:<path>`;
  confirmed the implementer's preserved `before/` files match it exactly.
- Resolved both versions using the real roster bindings, through one LuaJIT
  palette read and the shared template reader. Each template has the same cell
  keys and exactly **14 changed cells**: x=4/8, y=5, z=0…6. Every change retains
  the same node and changes only param2: 1→21 at x=4, 3→23 at x=8.
- All **1,533 other resolved cells per template** remain identical, including the
  watch-room ascending stairs sharing the original H legend entry. Separate V/W
  entries avoid accidentally flipping that staircase. Removing unused I is safe.
- All points (source-line metadata excluded), races, origins, pivots and sizes
  remain identical. No Kezamba gate change is present; its geometry differs.
- Read pinned Luanti `reference_projects/luanti/src/client/mesh.cpp:267–283` in
  the main checkout: facedir1/3 first turns XZ −90/+90; facedir21/23 then turns
  XY −180. The shared renderer's `facedirPoint` uses the same transforms (two
  −90-degree XY turns equal the engine's single −180 turn).
- Inspected all actual resolved stair node boxes: the standard lower full half
  plus upper back half. An independent occupied-octant calculation confirms the
  new notch opens **downward and into the passage** on both sides. The full
  upper half joins the lintel and the lower outer half joins its wall. This is
  the intended arch, not merely a param2-number change.
- Read the real `serve.Editor.save` invocation and save evidence; the installer
  uses shared validation/canonical serialization and stale-source hashes.
  The documented old guard-socket warnings are unrelated to these y=5 changes.
- Visually inspected `../gates/renders/gate-installed.png`. Its SHA-256 equals
  the approved proposal capture exactly:
  `abb9319f5d9607c659cf9b5aa25b8d72497cbf63cf7734c4b1899cadb0f8de82`.
  Highlight boxes are review overlays, not shipped nodes.

No global gates were repeated, no production file was edited by the reviewer,
and no native-client runtime acceptance is claimed.
