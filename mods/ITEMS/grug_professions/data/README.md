# grug_professions data

Enchant and universal-reagent catalogs (Round 28 ruling 28, formats in
[the design frame §4.4/§4.5](../../../../docs/planning/round28-design-frame.md#44-enchants-catalogenchantsjson)).
Read once at load by `enchants.lua` and `reagents.lua`; the checks live in
`enchant_data.lua`.

## INTERIM DATA — replaced by Lane E1

`enchants.json` is **interim**: it converts the pre-Round-28 scheme so that
enchanting keeps working until the C1 catalogue lands.

- `stat_loot`: every stat of a tier uses that tier's old single reagent
  (Coal Lump, Venom Gland, Slime Gel, Croc Tooth, Stormkelp, Stone Core).
- `family_input`: every family of a tier uses one cheap mined item (Tin Lump,
  Gold Lump, Silver, Emberglass, Abyssal Crystal at T5 and T6).

`reagents.json` is an empty list: no universal reagent exists yet.

Lane E1 replaces both files with the C1 catalogue
(`docs/planning/round28/design/catalog/enchants.json` and `reagents.json`)
and deletes this section.

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
