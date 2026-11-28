# Alchemy icon concept for approval

- I recommend a distinct bottle silhouette for each family. Healing has a loop handle, Vigor a foot and a gold heart.
- Broad flasks mark instant potions, footed bottles mark elixirs, and narrow vials mark draughts.
- Buff items borrow a motif from their status icon, such as Stoneskin’s fractured grey facets or Swiftness’s gold streaks.
- One brass stud per tier fills two rows of three on the neckband. Single-strength brews and the merchant’s small red pot have plain closures.
- Draw at **16 × 16 px** and double to **32 × 32 px** with nearest-neighbour, keeping each stud and the hole in Healing’s handle visible.

The [concept sheet](concept_sheet.png) shows four families and all six Healing tiers beside their current tints. The [design concept](CONCEPT.md) covers all ten families and the merchant’s potion. After approval, the pick page would show two or three choices per family. [Pillow generator](draw_sheet.py) · [Media provenance](LICENSE-media.md)

I rendered the sheet and verified all 20 size pairs pixel for pixel. Each successive Healing tier adds exactly one stud. A search found no fixture that reads the lane documents, so the fixture count was zero.

Upgrade classification is **compatible**. The changes are confined to `tools/r88_icons/`. Final commit on `r88-icons` is `edea0`. `git status --porcelain` is empty.

## Revised concept

- Healing has a centred cork, a broad red belly and an ivory cross.
- Mana has a cobalt pear-shaped body and a pale crescent low in the glass.
- Vigor keeps its foot and gold heart. Stoneskin keeps its square shoulders and fractured slate face.
- Every draught is an upright bottle. Swiftness carries two rising strokes across a honey-gold barrel belly.
- The inventory art starts at **16 × 16 px** and doubles to **32 × 32 px** with nearest-neighbour.

**I recommend Glasswork.** The bottle progresses from earthenware through glass to cut and gilt crystal. Tier 3 has a smooth, rounded heel. Tier 4 has straight ribs and a wide, squared heel you can pick out at 16 px.

**Stoppers** keeps the family body fixed. Six closures run from a plain cork to an amber sun. Tier 3 has a flat silver disc and tier 4 a pointed gem.

The revised sheet shows five families and all four six-tier strips beside today’s tints. [Revised sheet](concept_sheet_2.png) · [First sheet](concept_sheet.png) · [Concept](CONCEPT.md) · [Generator](draw_sheet_2.py) · [Media provenance](LICENSE-media.md) · [Report](REPORT.md)

I checked all 58 inventory-size pairs against the source pixels. No fixture reads the changed documents, so none ran. Upgrade classification is **compatible**.

Final commit on `r88-icons` is `45348`. `git status --porcelain` is empty.

## Bottle proposals

[Open the bottle pick page](pick/index.html). Choose A or B for each of the 11 families, then copy the reply with any changes you’d like.

There are **two proposals per family** for Healing, Vigor, Mana, Focus, Precision, Stoneskin, Antivenom, Swiftness, Cave, Deepwater and the merchant’s Healing Potion. That gives 22 choices and 82 transparent PNGs. Each ranked choice includes all six tiers.

| Material | Lower tier | Higher tier |
| --- | --- | --- |
| Earthenware | 1 · Cork | 2 · Wax seal |
| Blown glass | 3 · Silver disc | 4 · Gem point |
| Cut crystal | 5 · Winged clasp | 6 · Amber sun |

At 16 px, tier 3 has a flat, eight-pixel-wide top. Tier 4 rises to a two-pixel point. The page shows every bottle at 16 and 32 px on both slot colours, with the seven active-effect icons beside their families.

[Source PNGs](proposals/) · [Drawing script](draw_proposals.py) · [Page builder](build_pick.py) · [HTML template](pick.template.html) · [Concept](CONCEPT.md) · [Media provenance](LICENSE-media.md) · [Report](REPORT.md)

Verified all 328 slot samples against the PNGs, symmetric outlines for all 82 sources, and distinct stopper silhouettes between neighbouring tiers. Both generators reproduced their outputs byte for byte. Firefox checks passed at 320, 390 and 1440 px, including changing a pick and composing the reply. No fixture reads the changed documents, so the fixture count was zero.

Upgrade classification is **compatible**. Final commit on `r88-icons` is `5c8e3`. `git status --porcelain` is empty.

## Selected game textures

Added **41 bottle textures** from the approved proposals under CC0 1.0. The 36 tiered bottles, four single-strength alchemy bottles and one merchant bottle are byte-identical to their sources.

`tools/r88_icons/game_textures.json` is an array of 41 rows with `family`, `tier`, `item_id` and `texture`. Each row gives the full registered item ID and the PNG filename. Single-strength alchemy bottles carry their recipe tier. The merchant’s potion uses `null`.

Ran `python3 -B tools/r88_icons/check_game_textures.py` once. **All 41 passed** the 16 × 16 RGBA format, pixel comparison and Lua registration checks. No existing fixture reads the changed files.

Upgrade classification is **compatible**. Final commit on `r88-icons` is `57fcb`. `git status --porcelain` is empty.
