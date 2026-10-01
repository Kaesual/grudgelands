# grug_professions data

Enchant and universal-reagent catalogs (Round 28 ruling 28, formats in
[the design frame §4.4/§4.5](../../../../docs/planning/round28-design-frame.md#44-enchants-catalogenchantsjson)).
Read once at load by `enchants.lua` and `reagents.lua`; the checks live in
`enchant_data.lua`.

## Source

Both files are copies of the reviewed Round 28 catalogue
(`docs/planning/round28/design/catalog/enchants.json` and `reagents.json`,
ported by Lane E1); the catalogue README explains the stat loot per tier.
Edit the catalogue and this copy together and rerun
`python3 tools/r28_design/validate.py --design docs/planning/round28/design --atlas docs/planning/round28/zones`.
`reagents.json` is an empty list: the catalogue defines no universal reagent.

Until the zone spawn areas land (Round 28 lanes E2/E3), only existing mobs
named after a drop family drop catalogue loot (Boar tusks, Zombie flesh and
teeth), so only Strength, Critical chance and Maximum HP enchants can be made,
none at T5: 245 of the 588 operations
([crafting_equipment_revision.md](../../../../docs/design/crafting_equipment_revision.md)).

## Format

`enchants.json`: one entry per tier 1–6,
`{"tier", "stat_loot": {stat: item}, "family_input": {family: item}}`. An
enchant of tier T for family F and stat S costs the family's own material of
tier T (metal bar, leather grade, cloth bolt, graded wood or setting) plus
`stat_loot[S]` plus `family_input[F]`. Load fails when a tier is missing, a
stat of any family pool has no `stat_loot`, a family has no `family_input`,
an item is not registered, or an input is another profession's product.

`reagents.json`: a list of `{"id", "name", "tier", "method": "grid" |
"furnace", "inputs", "output_count", "uses"?, "notes"?}`. Grid recipes are
shapeless; furnace recipes cook one input. The id must be a new item in
grug_professions or a mod it depends on; every input must be a registered
item and not any profession's product. No enchant input may have a declared
ingredient tier above the enchant tier. The icon is `<mod>_<name>.png` from the item's own mod
when that file exists, otherwise a placeholder.
