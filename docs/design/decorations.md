# Decorations for homes and cities

Decided 2026-11-10, [Round 75](../planning/round75-plan.md). This is the
design owner for decorative access, display behavior, original paintings and
city dressing. Prices use copper: 100 copper = 1 silver, 100 silver = 1 gold.

## Access and prices

The Decoration Merchant in every capital offers the same fixed-price catalog,
independent of level. Ordinary vendor buy-back remains 5%. Household details
are affordable; paintings and elaborate fixtures are the expensive pieces.
The implementation's complete ordered shelf is
`mods/ENTITIES/grug_traders/stock.lua` (`culture`).

| Existing kit | Price |
|---|---:|
| Twelve masonry/glass accents | 25c |
| Wooden tables, chairs, benches and empty shelves | 60c–1s 20c |
| Barrels, open/lying barrels | 75c |
| Tub / washing place | 60c / 1s |
| Cushion / cushion block | 25c / 35c |
| Curtains, open or closed | 50c |
| Eight potted flowers | 30c |
| Ivy / garden stone path | 15c / 10c |
| Straw mat / bale | 15c / 30c |
| Shutters, open or closed | 35c |
| Decorative workbench / cauldron | 1s 50c |
| Candle / lantern / hanging lantern | 4c / 1s / 10s |
| Wagon wheel | **2s** |
| Four existing paintings, now named with their actual inventory previews | 1g |

Existing craftable beds, bookshelves, vessels and signs keep their crafting
routes. Existing collected plants remain collectable. Neither category is
replaced with a compulsory purchase.

| New family | Variants and access |
|---|---|
| Simple displays | Item Frame: **4 wood planks**; Wooden Armor Stand: **6 wood planks**, one output each, Basic crafting with no profession gate |
| Special frames | Iron 5s; carved 8s; brass 15s |
| Special armor stands | Iron 10s; carved 15s |
| Weapon holder | 1s, functional wall display |
| Place settings | Wooden/ceramic plates and bowls, 12c–20c |
| Drinkware | Wooden mug 12c; clay jug 28c |
| Prepared food decorations | Bread board 24c; meal platter 32c |
| Produce | Fruit/vegetable baskets 38c |
| Sacks | Closed 35c; grain 42c |
| Crates | Vegetables, fish, meat 48c; ore 55c |
| Wicker | Floor basket 30c; tabletop tray 22c |
| Books | Stack 35c; open book 30c; lectern 1s 80c |
| Writing | Writing set 45c; scroll 18c; scroll bundle 32c; map sheet 28c |
| Alchemy and herbs | Static vessel set 50c; hanging herb bundle 24c |
| Workshop | Tool board 75c; sample ore 35c, metal 42c, gems 50c |
| Textiles and leather | Cloth rolls 45c; yarn 22c; leather 45c; fur 48c |
| Rope and boatwork | Rope coil 35c; oar 65c |
| Candlemaking | Candle bundle 24c; wax bowl 20c |
| Lights | Candle group 1s 10c; wooden sconce 2s 40c; iron sconce 3s 20c; chandelier 15s |
| Fireplaces | Fire basket 5s 50c; hearth 9s |
| Rugs | Red/green/blue bordered rugs 1s 20c; red/blue runners 1s 60c |
| Wall shelves | Empty 85c; filled 1s 25c |
| Plants | Planter 1s 10c; hanging plant 1s 80c |
| Heraldry | The Accord / The Throng tapestries 25s |

Food, materials, sacks, crates and books are **static decorations**. They do not
provide food, crafting inputs, storage, recipes or another workstation system.
Lights have constant node light, without flame timers or particle emitters.
Furniture uses explicit mounting surfaces and stays upright; tabletop and wall
details do not block walking. Rugs have quiet geometric borders; faction
tapestries retain the full hart/boar designs and their original proportions.

## Functional displays

Frames hold one item stack; weapon holders accept a weapon. Armor stands have
head, chest, legs and feet slots and use the same armor appearance system as
characters, including mixed equipment. Special frames and stands change the
appearance, not storage capacity or statistics.

The node inventory is authoritative. Visible items/armor are unsaved derived
entities, rebuilt on loading and refreshed after changes. Opening uses the
ordinary inventory/station UI and the player's combined bags. Existing claim
interaction rights and bound-item rules apply. Displays must be empty before
normal digging. If a wall support is removed, a frame/holder drops both itself
and the complete stored stack, preserving its metadata. Claim-container
packing also preserves display nodes and their contents across a later reset.

## Original wall art

Six city impressions, three landscapes and a still life, three expedition
paintings, a guild agreement, a humorous tavern scene and a decorative trade
map form the first original collection: **16 motifs**. The palette is restrained,
with broad painted shapes readable at the shipped 256×256 texture resolution.
The [local gallery](../../tools/r75_art/index.html) shows actual game textures
and links to the original generated sources. Prompts and reproducible mesh/asset
baking remain alongside it. These are painted interpretations, not screenshots;
the trade map is not a navigation map for the generated world.

Small landscapes, still life and tavern scene occupy one wall cell and cost
50s. City views, the agreement and the map use a two-by-two wall area and cost
1g. Existing paintings remain 1g. Every painting needs a solid wall; large art
checks all four cells for support, free space and protection when placed. The
lower corner is its node anchor; the mesh extends across its stated wall area.

| Expedition | Exclusive painting | Source |
|---|---|---|
| The Stilled Seam | The Quiet Seam | Corresponding personal Reward Chest, **2%** |
| The Second Shift | The Ledger Left Open | Corresponding personal Reward Chest, **2%** |
| The Last Mint | The Last Mint | Corresponding personal Reward Chest, **2%** |

These are two-by-two paintings. The independent cosmetic roll happens once
per eligible player per run as part of the existing cached chest contents.
Reopening does not reroll. There is no merchant purchase, recipe or city-loot
route to an expedition painting. The paintings grant no combat benefit.

## City dressing

Dress existing city structures modestly, including starts, all capital cores
and district types and the twelve peaceful regional villages. Camps, mines,
outposts and expedition rooms are outside this pass. The survey's 515 rows are
an **authoring catalog**, not the number of buildings generated in one world;
world generation selects district plots from it.

Use the building's actual role: food and drink in inns, materials/tools in
workshops, writing and maps in guild rooms, display equipment in armories and
barracks. A royal hall has one deliberate painting and at most two equipment
displays. Wells may receive a missing bench, gardens a basket (the low tabletop
basket can also stand upright on a complete ground face), shelters a
small everyday prop. Gates, statues, ruins, greens, colonnades and drill spaces
remain quiet. No generic painting on every wall or mug on every table.

Explicit offline-authored placement rows are checked against their exact source
blueprints. Doors, beds, NPC positions, service access, routes and royal combat
space stay clear. A meaningful zero-addition decision is valid. The current
placement counts and per-building reasons belong to
`tools/r75_city/report.json` and the city catalog, not to a second hand-maintained
census. Decoration is applied identically during preparation and lazy rebuilding.

City variants are static nodes without inventories, entities or timers. They
drop nothing, including art and equipment silhouettes. They remain diggable
where the existing world permits it; town protection continues to guard starts
and capitals. City paintings use the smaller one-cell format. No newly placed
decoration creates a free item or rare-reward source.

The city blueprint changes require a **map reset**, joining the already planned
production reset. There is no online retrofit. New item/display state is
additive and needs no separate migration step.
