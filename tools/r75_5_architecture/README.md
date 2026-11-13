# Round 75.5 architecture integration

The accepted browser study is frozen at `48d69ef0`. This tool bakes its approved
cell deltas into the existing template legend and culture-palette format. It is
an offline authoring tool; the game performs no new facade inference. Design is
owned by [Settlements](../../docs/design/settlements.md#ordinary-town-facades-0755),
scope and delivery by [the round plan](../../docs/planning/round75.5-plan.md).

```sh
python3 tools/r75_5_architecture/integrate.py --runtime
luajit tools/r75_5_architecture/portable_test.lua .
bash tools/r75_city/run.sh
```

The integration proof reconstructs original templates from the frozen commit,
verifies the study/layout hashes and checks all 299 placement contexts against
283 implemented scenes (145 original, one shrine, 50 guild/service and 87
special contexts) plus 16 unchanged contexts. It also verifies protected
metadata and points. The real Lua loader builds the 283 implemented contexts,
stamps all four rotations and compares 4,030,468 cells, including real planting
and late-cell ordering for the two treehouses. Flat panes are compared
modulo their geometrically identical 180-degree orientation; no other direction
is relaxed. Actual dumped reed geometry and texture are checked against the
shape/texture used by the approved preview. `proof.json` records the cells'
digests and the exact source study hash.

`integrate.py --write` is an explicit authoring command: it replaces the 254
covered templates and the palette facade section from the frozen source and
reviewed assignments. It is deliberately **not** a generic maintenance command;
future template/palette edits must not be overwritten by rerunning it. Existing
legend keys and roof channels are retained where possible. The original twelve
reference designs and all still-excluded uses remain protected by the same proof.

`refresh_supports.py` loads finished city blueprints and updates only support
node names in the fixed decoration catalog. The 71 changes are recorded in
`support_changes.json`; target coordinates, nodes, orientations, expected cells
and row metadata are unchanged. Two supports are on the Sunscar armoury's flat
roof; the rest are wall mounts. The existing strict city audit verifies all 770
placements in 24 builders, including deferred places.

The Lua fixture protects the reported long-facade, high dwarf wall, actual
gable, raised troll house and elf accent regressions, plus roof orientation
contracts. The existing freeze fixtures pin the intentional new map identities.
Their point digests also include node lists; raw authored points remain exact.
The template validator keeps its existing BASELINE and reports zero new errors.

Classification: **map reset**, no migration, no new server. Native desktop/web
acceptance belongs to the user; no local installed game is changed by these tools.

The user's moon-shrine extension is stored separately in `shrine.json` and
reproduced by `python3 tools/r75_5_architecture/shrine.py` (check only by default).
Its explicit `--write` authoring mode updates just that template and supplement.
The original study remains unchanged. The [special-structure overview](../city_architecture_specials/README.md)
records scope, proposals and follow-up checks.

The guild/service supplement is authored by `services.py` and stored in
`services.json`. Check reproducibility with `python3 tools/r75_5_architecture/services.py`
and the 98 structural regression checks with `services_test.py`. The old
`r58_halls/make_halls.py` generator applies the same hall transformation after
creating its geometry, so its normal write and `--check` paths retain this
style. The original study and shrine supplement remain immutable.

Five semantic public-roof roles provide human red tiles with existing shapes;
all bindings are real registered nodes and are offered in the template editor.
Thirteen additional decor support-name changes are recorded separately in
`service_support_changes.json`; the previous 71-change record stays intact.
Use `refresh_supports.py --report service_support_changes.json` only for this
explicit support-pin authoring step. No furnishing is added or moved.

The remaining approved special structures use `specials.py` / `specials.json`
(87 contexts, 72 templates, frozen pending scope at `cbc67f1f`). The tool checks
reproducibility by default; `--write` is explicit authoring. `special_materials.py`
adds semantic monumental/open-building palette roles. Run `specials_test.py` for
135 physical/typology regressions. The real engine dump covers the twelve hidden
material pillar variants. `special_support_changes.json` records 33 additional
support-name changes; earlier receipts remain immutable. `integrate.py` verifies
all authored late flags and uses the real loader's frozen-source planting when
comparing final runtime output. The overview uses that same actual-before export.
