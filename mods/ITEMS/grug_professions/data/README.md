# grug_professions data

Enchant catalog (Round 28 ruling 28, format in
[the design frame §4.4](../../../../docs/planning/round28-design-frame.md#44-enchants-catalogenchantsjson)).
Read once at load by `enchants.lua`; the checks live in `enchant_data.lua`.

## Source

`enchants.json` is a copy of the reviewed Round 28 catalogue
(`docs/planning/round28/design/catalog/enchants.json`, ported by Lane E1);
the catalogue README explains the stat loot per tier. Edit the catalogue and
this copy together and rerun
`python3 tools/r28_design/validate.py --design docs/planning/round28/design --atlas docs/planning/round28/zones`.
There are no universal reagents (removed in Round 33).

Since every zone has a spawn recipe (Round 28 S2, W1), every stat loot item
of T1–T6 drops from at least one sub-type a recipe places, so none of the 588
operations lacks its stat loot
([crafting_equipment_revision.md](../../../../docs/design/crafting_equipment_revision.md)).

## Format

`enchants.json`: one entry per tier 1–6,
`{"tier", "stat_loot": {stat: item}, "family_input": {family: item}}`. An
enchant of tier T for family F and stat S costs the family's own material of
tier T (metal bar, leather grade, cloth bolt, graded wood or setting) plus
`stat_loot[S]` plus `family_input[F]`. Load fails when a tier is missing, a
stat of any family pool has no `stat_loot`, a family has no `family_input`,
an item is not registered, an input is another profession's product, or an
enchant input has a declared ingredient tier above the enchant tier.
