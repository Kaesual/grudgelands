# Partial plan — plant art design round (GPT-6 Astra)

> **Scheduled in Round 48** ([round48-plan.md](round48-plan.md)). Its §2
> rulings and §3 interfaces override this file where they differ.

Status: **partial plan for the next round**, not yet scheduled; companion
of [plant-growth-plan.md](plant-growth-plan.md), which owns the game logic.
The item list comes from the user's plant review of 2026-10-14 (the review
page's stored feedback, 11 marked plants, and the chat of the same day). A
coordinator folds this file into the round plan.

## 1. Goal

A design round in which GPT-6 Astra prepares **three drafts per item**
from the user's feedback. The user picks one per item on a pick page (or
asks for a redo); the picks become the game's textures. It covers the
redesigns the user asked for and the new art that the growth plan needs
(Melon and Mushroom as crops, the Salt Pan).

## 2. Rulings (user, 2026-10-14)

1. Three drafts per item; the user picks one.
2. Trees and grass are out of scope.
3. The user's comments below are the brief for each item.
4. Wild Potato and wild Corn get no new art: they switch to their
   existing stage-4 crop look, which is code in the growth plan's FARM lane
   (its §2.20).
5. Salt Crust is no crop any more; its seed icon goes away (growth plan
   §2.15). The basin stages stay; the new Salt Pan needs an item icon.

## 3. Items

"Wild look" is what the plant looks like where it grows in the world.
For a crop it is its stage 4 at 1.15× scale (`grug_mapgen/world_nodes.lua:5`),
so a new stage 4 also changes the crop's wild look. The gather-only plants
(Sunleaf, Gravemoss, Wild Cocoa) use one image today for both the world
plant and the item; a draft may split it into a world sprite and an item
icon where that reads better.

| # | Item | Deliver per draft | The user's feedback (translated) | Notes for the drafts |
|---|---|---|---|---|
| 1 | **Cassava** (crop) | stages 1–4, seed | "Looks exactly like potatoes. The resemblance may stay, but the items must differ." Marked: growth stages, seed. | Both are root crops, so a family resemblance is fine; at a glance they must differ. Today the seed is the potato seed slightly tinted (`seed_visuals.lua`). Real cassava is a tall woody shrub with hand-shaped leaves and is planted from stem cuttings, which suits the `tall_bush` shape (`crop_visual.lua`). |
| 2 | **Wild Onion** (crop) | stages 1–4 (stage 4 is the problem) | "Stage 4 is too red; it should match the onion's colour. Now it looks like beetroot, not like an onion." Marked: growth stages. | Keep stages 1–3 consistent with the new stage 4. The harvest icon (`grug_cooking_wild_onion.png`) is the colour reference. |
| 3 | **Pumpkin** (crop) | stage 4 | "Stage 4 looks like a flower, not like a pumpkin. Stages 1–3 are fine." | Stage 4 must read as a pumpkin fruit on its vine and match stages 1–3. |
| 4 | **Melon** (new crop) | stages 1–4, seed, harvest icon | "Looks too similar to an apple." Marked: plant / item. | Today a tinted apple (`default_apple.png^[colorize:#61a94e:95`). Must differ from **Frost Melon** (a watermelon slice icon, `grug_cooking_frost_melon.png`), from **Pumpkin** and from the apple. Ground-fruit crop like Pumpkin (`ground_fruit` shape); stage 4 is also its wild look in the jungle (growth plan §3.14), so no separate wild sprite. |
| 5 | **Mushroom** (new crop) | stages 1–4, spore icon, harvest icon | "Does not look like a mushroom, but like scrub. The icon should look like a mushroom." Marked: plant / item. | Today a tinted pine bush sapling. Must differ from **Cave Cap** (brown capped clusters, `grug_cooking_cave_cap.png`, `grug_farming_cave_cap_*`). Grows in forests and swamps, also in the dark when farmed. `mushroom` shape; the seed item is called "Mushroom Spores". Stage 4 is also its wild look (growth plan §3.14), so no separate wild sprite. |
| 6 | **Sunleaf** (gather-only spice T1) | world sprite and item icon (or one shared image) | "Maybe a bit too similar to normal grass?" | Today the meadow grass texture tinted yellow (`default_grass_3.png`). Grows in meadows, savanna, elf forest and jungle edge, so it stands next to real grass. |
| 7 | **Gravemoss** (gather-only healing herb T1) | world sprite and item icon (or one shared image) | "Looks more like a head of lettuce than like 'grave moss'. Could be done better stylistically." | Today a tinted fern. Grows in the pine hills and the blight; an Alchemy herb. |
| 8 | **Wild Cocoa** (gather-only, T6) | world sprite and item icon (or one shared image) | "Looks (like the Mushroom) like scrub, not like cocoa." | Today a tinted pine bush sapling. Grows only in the level-51–60 jungle zones; the item should read as a cocoa pod or beans. |
| 9 | **Salt Pan** (new item) | item icon | — (new; growth plan §2.16) | A shallow metal pan (Embersteel) with salt; the placed pan keeps the existing basin look (`grug_farming_salt_crust_*`), so the icon should match it. |

## 4. Rules for the drafts

- **Format:** 16 × 16 PNG with transparency, CC0, made by a generator the
  lane commits (as in Round 47's lane ART). Records go to the media ledger
  (`grug_farming/LICENSE-media.md`, `grug_gathering/LICENSE-media.md`).
- **Style:** fit the existing crop and item textures (the `x_farming`-based
  stage art and the `grug_cooking_*` icons). Plants are drawn
  `plantlike`, i.e. as two crossed quads: a sprite must read from the side,
  with a transparent background and a clear silhouette.
- **Three real alternatives:** the three drafts of an item differ in shape
  or concept, not only in colour.
- **Readable next to its neighbours:** each draft is checked next to the
  plants the user named (cassava next to potato; melon next to Frost
  Melon, Pumpkin and the apple; mushroom next to Cave Cap; sunleaf next to
  meadow grass).
- **Stages read as one plant growing:** a stage set keeps colours and
  forms consistent from 1 to 4.
- No changes under `mods/` in the draft step.

## 5. Process

1. **Drafts.** Astra delivers the 9 items × 3 drafts (A, B, C) with the
   generator. Drafts, generator output and a manifest (item, draft, file,
   one line describing the idea) go to the round's orchestration folder.
2. **Pick page.** The coordinator publishes a pick page in the style of
   the review page (https://claude.ai/artifact/V9rcnhupn22X5mr1xMKNZf; it
   stores the choices so the coordinator reads them directly): per item the
   current art, drafts A–C at 4× on selectable grounds (light, dark, soil),
   the comparison neighbours from §4, and per item a choice of A, B, C or
   "redo", plus an optional comment.
3. **Fix round.** The user's iteration style: picks may come with change
   requests; Astra applies them to the picked draft (and redoes "redo"
   items with three new drafts); a second pick only for those.
4. **Final files.** Astra writes the picked art under the target names
   (§6) into the mods' texture folders and the ledger entries. FARM has
   already wired these names (§7), so the art merge changes no Lua.

## 6. Target file names

| Item | Files |
|---|---|
| Cassava | `grug_farming_cassava_{1..4}.png` (replace), `grug_farming_seed_cassava.png` (new) |
| Wild Onion | `grug_farming_wild_onion_{1..4}.png` (replace) |
| Pumpkin | `grug_farming_pumpkin_4.png` (replace) |
| Melon | `grug_farming_melon_{1..4}.png`, `grug_farming_melon_seeds.png`, `grug_gathering_melon.png` |
| Mushroom | `grug_farming_mushroom_{1..4}.png`, `grug_farming_mushroom_spores.png`, `grug_gathering_mushroom.png` |
| Sunleaf | `grug_gathering_sunleaf.png` (item) and, if split, `grug_gathering_sunleaf_plant.png` |
| Gravemoss | `grug_gathering_gravemoss.png`, optional `grug_gathering_gravemoss_plant.png` |
| Wild Cocoa | `grug_gathering_wild_cocoa.png`, optional `grug_gathering_wild_cocoa_plant.png` |
| Salt Pan | `grug_farming_salt_pan.png` |

`grug_farming_seed_melon.png` already exists (the `x_farming` melon seed,
tinted for Frost Melon in `seed_visuals.lua`); the new Melon seed uses a
different name so Frost Melon keeps its icon.

## 7. Interfaces to the growth plan

- **FARM wires the final names** (seed visuals for Cassava, Melon and
  Mushroom; the Melon and Mushroom item icons; the source-node and item
  overrides for Sunleaf, Gravemoss and Wild Cocoa; the Salt Pan icon; the
  Melon and Mushroom source nodes take their stage-4 crop look, growth
  plan §3.14) and ships placeholder PNGs under those
  names: copies or renders of today's images (the tinted composites), or
  Pumpkin/Cave Cap copies for the new stages. ART then only replaces PNGs.
- **P9G images stay out of the WP33 catalog:** its `image` fields are
  hashed into the mapgen manifest (growth plan §3.10); the new looks are
  runtime overrides from a separate presentation file.
- When a draft splits world sprite and item icon, the override sets the
  source node's tile and the item's `inventory_image` separately.

## 8. Orchestration notes

- **Lane:** ART (GPT-6 Astra, `run_astra.sh <round> art`); one lane for all
  9 items. The draft step can start in the first wave; the final-files step
  waits for the user's picks and merges after FARM.
- **Review:** the usual art review (format, licence ledger, file names,
  no stray changes); the user's pick is the acceptance.
- **Decided during the round:** the picks and fix requests (the user).
