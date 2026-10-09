# grug_professions data

Enchant and upgrade catalogs (Round 28 ruling 28; Round 33,
[item_tiers.md](../../../../docs/design/item_tiers.md) §2, §3). Read once at
load by `enchants.lua`; the checks live in `enchant_data.lua`.

## Source

`enchants.json` and `upgrades.json` are copies of the Round 33 data design
(`tools/r33_ds/enchants_r33.json`, `tools/r33_ds/upgrades_r33.json`, printed by
`python3 tools/r33_ds/allocation.py --json`; the inputs are explained in
item_tiers.md §2.1–2.4). Edit the source and these copies together; the
fixture `tools/r33_c4/portable_test.lua` compares them. There are no
universal reagents (removed in Round 33).

## Format

`enchants.json`: one entry per tier 1–6,
`{"tier", "prefix_loot": {stat: item}, "suffix_loot": {stat: item},
"family_input": {family: item}}`. An enchant of tier T for family F, stat S
and channel K costs the family's own material of tier T (metal bar, leather
grade, cloth bolt, graded wood or setting) plus `K_loot[S]` plus
`family_input[F]`. Its value follows the item's level up to 10 × T
(grug_quality).

`upgrades.json` (Round 45): the cost of one upgrade level and the families
each profession upgrades, `{"own_material_per_level": 1,
"weapon_extra_per_level": [{"item", "n"}], "professions": [{"profession",
"families"}]}`. One level costs the own material of the item's tier, a
weapon also the weapon extra (one Stick); an item rises one item level per
level up to 10 × its material tier, 1 s per level, without profession XP.

Load fails when a tier is missing, a stat of any family pool has no loot in
either channel, a family has no `family_input`, a profession's upgrade entry
is missing or names other families than it owns, an item is not registered,
an input is another profession's product, or an input has a declared
ingredient tier above the operation tier.
