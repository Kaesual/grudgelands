# Independent bed repair review

2026-11-10 · reviewer `gates_roof_study` · **MERGE**, no findings.
Classification: **map reset**, correctly required by the template change.

Read the installer, validated editor-save receipt and verification/render adapter.
Independently parsed the preserved original, installed `dawnmere_harvest_inn.tpl`
and rendered `after` snapshot. The installed file equals the rendered snapshot.
Exactly six cells differ: x=1/3, y=1, z=12/13/14. The two complete directed bed
pairs move one node inward; both are still `beds:bed_bottom` followed by
`beds:bed_top` with facedir 0. Bounds, pivot, origin, and all socket/point semantics
remain unchanged.

The restored wall matches its actual neighbours: x=1 uses `window_frame` from
the frame directly above; x=3 uses the `wall_accent` of the adjacent low wall
course. Both bed feet remain reachable from the interior entrance under a
conservative two-node-high occupancy flood fill. This is static geometry
verification, not a native pathfinding or gameplay claim.

Independently checked reciprocal directed halves throughout the current template
set: 230 complete beds in 96 templates, with neither orphan feet nor orphan heads.
All four PNG output hashes and scene-input receipts match; the inside and outside
before/after cameras match. Visually inspected both interior views and the final
exterior view: beds lie inside the room, and the rear wall is restored.

No rerender, full fixture suite, production edit or baseline rewrite was performed
as part of this read-only review. Evidence: `../beds/install.py`, `before/`,
`after/`, `save-report.json`, `verification.json`, `scenes.html`, `renders/`.
