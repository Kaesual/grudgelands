# The alchemist’s bottles

The owner approved the upright bottles and chose glasswork and stoppers together. Each family has two proposals. The body and emblem identify what the brew does. The wall material and the closure show its strength. Every outline is centred on its neck, with highlights and small inlays free to break the symmetry. [Pick page](pick/index.html) · [Second concept sheet](concept_sheet_2.png) · [First concept sheet](concept_sheet.png)

## Reading the six tiers

| Tier | Body | Stopper | Detail to look for at 16 px |
| --- | --- | --- | --- |
| 1 | Earthenware | Cork | A short brown plug above the clay rim. |
| 2 | Earthenware | Wax seal | Red wax spreads wide and folds down over the lip. |
| 3 | Blown glass | Silver disc | A pale horizontal bar, eight pixels across, caps the smooth glass. |
| 4 | Blown glass | Gem point | The stopper rises to a two-pixel tip above the same belly. |
| 5 | Cut crystal | Winged clasp | A notch of sky separates two gold wings above the bevelled glass. |
| 6 | Cut crystal | Amber sun | A solid, round amber cap closes the notch. |

The first two tiers carry the brew’s colour as a fired glaze on warm clay. The middle pair has a thin, cool wall. At the last two tiers the lower corners catch the light in broad cuts. Across the shelf, the cork, wax, disc, point, wings and sun occupy the same five rows on every ranked bottle. The shapes stay visible against both the dark inventory slot and pale stone.

## The two choices in each family

| Family | A | B |
| --- | --- | --- |
| Healing | Round red flask with an ivory cross. | Flat-bottomed field canteen with the cross cut into an ivory seal. |
| Vigor | Ruby chalice tapering from a gold heart to a small foot. | Full-bellied urn with a gold heart outlined in dark red. |
| Mana | Blue pear with a pale crescent low in the belly. | Wide blue tide flask with a curling wave. |
| Focus | Diamond decanter with a bright four-point star. | Upright pillar with a hollow star on its blue face. |
| Precision | Round amber lens with a sight ring and central dot. | Broad rangefinder bottle with two pairs of ivory sight brackets. |
| Stoneskin | Square slate bottle split by a dark seam. | Tapering shield bottle with a ridge down its face. |
| Antivenom | Green dispensing bottle with one hooked fang. | Rounder adder flask with two short ivory fangs. |
| Swiftness | Honey-gold barrel with rising streaks. | Flat-sided travel bottle with a feathered wing. |
| Cave | Low violet bottle with a wide mouth and a horizontal eye. | Taller inkwell with an upright eye. |
| Deepwater | Teal bell on a foot with bubbles rising through the glass. | Sea-green globe with bubbles above a breaking wave. |
| Merchant’s Healing Potion | Squat, unmarked brick-red salve pot. | Slim slipware bottle with a pale stripe at the heel. |

Healing and Mana present the instant brew on a broad face. The elixirs stand on feet and echo the motifs of their active effects. The draughts have broad travelling bases. Antivenom clears poison immediately. Swiftness and Cave leave effects, and their status icons sit beside the bottles on the page. The three draughts, Deepwater and the merchant’s potion each have one strength. [Brew catalogue](../../mods/ITEMS/grug_alchemy/recipes.lua) · [Potion tiers](../../docs/design/item_tiers.md#5-potions-and-elixirs)

## Scale and reproduction

The source is transparent **16 × 16 px** pixel art, the same size as the merchant’s current flask. The pick page doubles the native pixels with nearest-neighbour to **32 × 32 px**. Each sample appears on inventory blue-grey (`#111a24`) and pale stone. The red and blue family pairs sit together, with a compact side-by-side comparison on smaller screens. [Merchant’s flask](../../mods/ENTITIES/grug_traders/textures/grug_traders_item_potion_healing_weak.png)

Run these commands from the repository root with Python and Pillow. The second command embeds the proposal PNGs and the seven existing buff icons in the standalone HTML file. [Drawings](draw_proposals.py) · [Page builder](build_pick.py) · [Page template](pick.template.html) · [Media provenance](LICENSE-media.md)

```sh
python3 tools/r88_icons/draw_proposals.py
python3 tools/r88_icons/build_pick.py
```
