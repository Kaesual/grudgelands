# DD3 — Design documents, items and economy, against the code

- Finder model: claude-opus-5-5
- Files read in full: 8 of 9 (items_crafting.md, item_tiers.md prose and every table it owns outside the combat-model blocks, economy.md, professions.md, farming.md, durability_repair.md, decorations.md, miners_guild.md); skimmed: inventory_equipment.md (§2, §3 and §4 read in full; §1 only skimmed, because P3-11/P3-12 cover it; §5 onward not reached: buffs, feed, skill catalog, quickbar and navigation are UI, not items/economy); in item_tiers.md the generated combat-model blocks (§1.2 class check, §1.4 Dexterity split, "A full set at level 60", Appendix A) were not checked (DD2 territory) and the generated sale, upgrade-cost and income tables were only spot-checked.
- Summary: The numbers in this package are in very good shape. I compared about 1,100 values row by row against the data files: the price module, the repair module, the guild catalogue, the culture shelf, the alchemy, cooking and food tables, the enchant curves and pools, the trinket specials, the gear and Basic recipes, the bag and container catalog, the crop profiles and renewal constants. None of these values differs from the code. The findings are text-level. The most valuable one: items_crafting.md still states twice, once as a "binding" anchor, that everyone crafts the base gear of every tier, which Round 45 replaced with gear from professions only (DD3-01). There is also one internal contradiction about wearing the same trinket identity twice (DD3-02), an open question left in a design file (DD3-03), a vendor good that no shelf sells any more (DD3-04), and several dead section references to the retired §1/§2 (DD3-05). Values checked per document: items_crafting ~330, item_tiers ~210, miners_guild ~140, decorations ~100, economy ~75, inventory_equipment (§2–§4) ~45, farming ~45, professions ~40, durability_repair ~22. Relative links: all present; all 14 anchors resolve.

## Findings

### DD3-01 | Medium | docs | items_crafting.md says everyone crafts the base gear of every tier; since Round 45 gear comes only from professions

- **Where:** `docs/design/items_crafting.md:66-69` (§0 "Decided anchors (… binding)": "Everyone crafts the base items of every material tier; professions enchant and upgrade them and hold a few exclusive recipes"), `:369-373` (§3.0.3: "Everyone can craft the base items of every material tier — tools, weapons, armor. This is the deliberate block-crafting feel…"); against `docs/design/professions.md:85-87` ("Gear comes only from professions (Round 45 …)") and the same file's own `:411-412` and `:756-759`; code `mods/ITEMS/grug_professions/base_recipes.lua:1-8`, `:40-49`
- **What:** Two passages of items_crafting.md, one of them in the binding anchors, still describe the pre-Round-45 rule: every player crafts swords, armour and the rest as universal recipes. In the code every weapon, armour piece and offhand is a recipe of its family's owner profession at the item's tier with the station nearby (`gear()` → `grug_professions.register_recipe(profession, …)`). Only tools, arrows, sticks and hoes stay Basic. The doc contradicts itself and professions.md §1 and §1.2.
- **Evidence:** `base_recipes.lua:40-49` (`grug_professions.family_owner(family)`, error when there is none), `:54-85` (every weapon, shield and armour piece goes through `gear`); professions.md:85-87, :164-168.
- **Proposal:** The code is right (Round 45 ruling). Rewrite the §0 bullet to "Professions craft the base items of their families at every tier (Round 45); everyone crafts tools", and change the §3.0.3 bullet to tools only. Keep the "block-crafting feel" sentence only for tools, or drop it.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD3-02 | Low | docs | items_crafting.md §6.2 both allows and forbids the same trinket identity twice

- **Where:** `docs/design/items_crafting.md:1565-1567` ("The same registered identity may occupy both slots (0.53.1 …)") against `:1616-1617` ("It enforces the same-identity-per-character exclusion and every cap/cooldown above"); also `docs/design/inventory_equipment.md:546-548` (allowed)
- **What:** The last paragraph of the trinket section still names the exclusion that 0.53.1 removed. The code has no such exclusion: a search for an identity check in the trinket and equipment code finds none, and the specials table and `PAIR_SHARE` handle two copies (`grug_gear/trinkets.lua:44-55`, `:73`).
- **Evidence:** `rg -n "identit" mods/PLAYER/grug_inventory/equipment.lua mods/ITEMS/grug_gear/trinkets.lua` finds no exclusion; `trinkets.lua:13-34` gives the caps and the `highest` stacking that the "Worn twice" line describes.
- **Proposal:** Change `:1617` to "It enforces every cap, cooldown and two-slot rule above." The code is right.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD3-03 | Low | docs | An open question is left in items_crafting.md §5.1

- **Where:** `docs/design/items_crafting.md:1369-1370` ("Whether a found-gear versus crafted-demand audit is still wanted after WP5 is open ([BACKLOG](…#audit-2026-10-open-questions), DI-10).")
- **What:** AGENTS.md "Documentation layers" item 1 forbids open questions in `docs/design/`. This sentence is one, and it points at the backlog where the question already lives.
- **Evidence:** AGENTS.md:126-127; the cited lines.
- **Proposal:** Delete the sentence. BACKLOG DI-10 keeps the question.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD3-04 | Low | docs | items_crafting.md §3.5 names the tailor shop's 3c linen scrap; no shelf sells cloth since Round 57

- **Where:** `docs/design/items_crafting.md:833-835` ("T1 linen scrap → patch bolt (start-zone zombies …, the start camps' outlaws and the tailor shop's 3c scrap …)"); code `mods/ENTITIES/grug_traders/stock.lua:240-246` (tailor shelf: `wool:white` and `wool:brown` only)
- **What:** The tailor shelf sells only the two wools. The doc's own §3.7 (`:1154-1160`), professions.md §4 and economy.md §2 all say that no shelf sells cloth since Round 57 ruling 28. The §3.5 source list is the one place left over.
- **Evidence:** `rg -n "linen_scrap" mods/ENTITIES/grug_traders/stock.lua` finds no hit.
- **Proposal:** Drop "and the tailor shop's 3c scrap" from §3.5. The code is right.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD3-05 | Low | docs | items_crafting.md points to retired sections (§1, §2) and to a "marked line" that is gone

- **Where:** `docs/design/items_crafting.md:302` ("ported from LotT, §1.1"), `:714` ("`default` ships no armor (§1.2)"), `:1831` ("port ≈ 1000 lines incl. `vl_projectile`, §1.2"), `:1422` ("The Crown is the Crownbinder's input for crowning one item (§2, …)"), `:385-386` ("This supersedes §3.3's 'vendor floor sells up to the bronze pick …' (see the marked line there)")
- **What:** The file's header (`:3-7`) says §1 (reference research) and §2 (profession progression) are retired to the archive, so the four section references lead nowhere in this file. §3.3 (`:771-801`) no longer contains the quoted vendor-floor line, so the supersession note at `:385-386` refers to text that is gone.
- **Evidence:** `rg -n "^#" docs/design/items_crafting.md`: no §1 or §2; `rg -n "vendor floor sells" docs/design/items_crafting.md` finds only `:385`.
- **Proposal:** Point the §1.x references at the archive (`../archive/design/items-history.md`) or drop them. Change `:1422` to "(item_tiers.md §4)". Delete the sentence at `:385-386`.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD3-06 | Low | docs | decorations.md calls the culture vendor "Decoration Merchant"; the game and economy.md say "Decor Merchant"

- **Where:** `docs/design/decorations.md:9` ("The Decoration Merchant in every capital"); `docs/design/economy.md:316` ("the Decor Merchant"); code `mods/ENTITIES/grug_traders/vendors.lua:445` (`nametag = "Decor Merchant"`), `mods/PLAYER/grug_map/providers.lua:90`, `mods/PLAYER/grug_inventory/help.lua:154`
- **What:** The design owner of the vendor uses a name that the nametag, the map label and Help do not show, and that the other design file does not use.
- **Evidence:** `rg -n "Decor(ation)? Merchant" mods` finds only "Decor Merchant".
- **Proposal:** Change decorations.md:9 to "Decor Merchant". The code is right. Every price row of decorations.md matches `stock.lua:310-438` (checked: 95 shelf rows, the display crafts at `grug_jobs/basic_recipes.lua:108-109`, the 2 % painting rolls at `grug_expeditions/loot.lua:34,53,71`).
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD3-07 | Low | docs | farming.md says the hoes' "grid shape … follow pinned VoxeLibre"; there is no grid since Round 45

- **Where:** `docs/design/farming.md:83-84`; code `mods/PLAYER/grug_jobs/basic_recipes.lua:111-117` (hoes as ingredient lists: 2 material + 2 sticks), `mods/ITEMS/grug_farming/hoes.lua:57-63`
- **What:** The player's craft grid is gone (`grug_jobs/craft_list.lua:1`; durability_repair.md:89-90). A hoe is a Basic ingredient-list recipe. The bucket paragraph of the same file already says "(the pinned VoxeLibre V layout until Round 45)"; the hoe paragraph was not updated. The material count (2 + 2 sticks) matches.
- **Evidence:** The cited lines.
- **Proposal:** Change it to "Their Basic recipe takes two units of the material and two sticks (the pinned VoxeLibre shape's count)". `hoes.lua`'s `core.register_craft` stays, because `prices.lua:280` and `grug_jobs/sources.lua:443` read the engine recipes.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

### DD3-08 | Low | docs | items_crafting.md §3.4 describes leather as "hide + thread → leather, 1:1 per grade"; the code builds T2–T4 from the grade below

- **Where:** `docs/design/items_crafting.md:805-807`; code `mods/PLAYER/grug_jobs/basic_recipes.lua:201-212`, `mods/ITEMS/grug_professions/leatherworker.lua:4-5`
- **What:** The Basic recipes are Light ← `mobs:leather` + Thread, Cured ← Light + Thread, Heavy ← Cured + Thread, Scaled Hide ← Heavy + Thread, Sleek ← Sleek Pelt + Thread, and Nightscale ← Scaled Hide + Sleek Pelt. So one T1 hide plus three Threads (1c vendor supply) becomes a T4 Scaled Hide. Heavy Leather and Scaled Hide are also mob loot (`grug_mobs/data/drops.json:179`, `:705`). The doc reads as one hide per grade and never says that the grades climb. The Woodcarver grades and the alloys are explicitly "flat, never the grade below" (`:927-930`, `:315-320`), so the leather ladder is the one ladder that chains.
- **Evidence:** The cited recipe rows.
- **Proposal:** Ask the user which is intended. If the chain is intended, write it into §3.4 ("each grade from the grade below plus a Thread; Heavy Leather and Scaled Hide also drop"). If not, make the T3/T4 recipes take their own loot. Note that the chain lets a T1 drop reach a T4 armour material, which professions.md §4 ("every ingredient from T2 up … comes from loot, mining, smelting or gathering") arguably still allows, since T1 leather is loot.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a (docs) / compatible (recipe change)
- **Confidence:** medium

### DD3-09 | Low | docs | Stale tables that the text itself declares outdated: the crown "options" and two income tables at repair factor 1.00

- **Where:** `docs/design/item_tiers.md:667-673` (generated "crown" block: "option 1 / option 2, proposed / option 3", 80s / 1g 61s / 3g 21s, while the shipped fee is 1g 48s, `grug_traders/crown.lua:12`); `item_tiers.md:818-838` (§6.5: "new" is factor 1.00, not the current 0.50); `docs/design/economy.md:268-279` ("the table above is still the 1.00 estimate")
- **What:** A decided-design file shows a proposal table with three options and a "proposed" label, and two income tables computed at a repair factor that Round 78 replaced (`grug_repair/service.lua:20`: 0.50). Each table carries a sentence saying it is outdated, so nothing is wrong yet, but these are discussion and record rather than decided numbers (AGENTS.md "Documentation layers": no discussion).
- **Evidence:** The cited lines.
- **Proposal:** Regenerate with `tools/r33_ds/money.py --factor 0.5` and `build_doc.py`, and reduce the crown block to the one shipped rule (1 h of band-6 income, 1g 48s), or move the option table to the round33 plan.
- **Effort:** S · **Risk:** low · **Upgrade class (guess):** n/a
- **Confidence:** high

## Backlog notes

- `mods/ENTITIES/grug_traders/stock.lua:69-71`: the code comment says "From T2 the bases come from Basics crafting or drops"; since Round 45 they come from profession crafting (stale comment, same drift as DD3-01).
- `mods/ITEMS/grug_alchemy/recipes.lua:51-52`: "two grid recipes cannot share inputs" explains Precision II's input; there are no grid recipes since Round 45, and a named-recipe registry has no such limit (the reason is gone; the recipe can stay).
- `mods/PLAYER/grug_guild/catalog.lua:106-107`: "a mark … on the nearest target deposit" contradicts the same file's `:227-229`, miners_guild.md §7 ("a random deposit") and the user's ruling of 2026-10-23; the comment is stale.
- `mods/ITEMS/grug_repair/service.lua:26`: the repair cost uses `stack:get_wear() / 65535`, ignoring the `_grug_wear_remainder` sub-unit that the tooltip counts (`presentation.lua:15-16`). The difference is below one wear unit's price, so this is harmless.
- `docs/design/miners_guild.md:394-396`: "`economy.md` §1 … gets that exception from lane CONSUME" is a work note; economy.md:32-40 already carries the exception.
- `docs/design/miners_guild.md:400-401` cites the tuning page at `~/projects/grudgelands-orchestration/…`, a path outside the repository (not a link, so it is not dead in the link check).
- `docs/design/inventory_equipment.md:150` (Trash box: "the Money box above it") and `:96` ("The money row has no box") contradict each other inside §1. This is part of P3-11's drift; the code draws a box.

## Good to know

- Checked and matching, row by row: the repair formula, factor 0.50, quality ×1/3/6, wear budgets 1000…4000 and 30/60/300…3000, death wear 10 %, the PvP window of 30 s and the 15 % hint (`grug_repair/*`, `tool_lifetimes.lua`, `hoes.lua`, `grug_pvp/rules.lua:15`). The price module: tier factors, class values, the bulk table with lots, buy-back ceil 5 %, ×3/×6, the never-sell list (`price_rules.lua:10-46`, `prices.lua:52-126`). Coin bags (`grug_mobs/aggro.lua:1279-1282`), respec, mount and crown prices, postage 5c + 30c, the money clamp, and claim fuel of 26,160 s and 5 lumps.
- miners_guild.md matches `grug_guild/catalog.lua` exactly: ranks, all 25 exchange rows, consumable prices and payouts, Ore Sense and Treasure Hunt parameters, the Remains table, the Stonewright table, the cloak names and the counter (`grug_achievements/catalog.lua:151-157`, `:293-298`). The room count of 148 over 36 camps adds up.
- item_tiers.md: the enchant curves (`grug_quality/init.lua:122-131`), the T1 and T6 enchant-loot rows (`grug_professions/data/enchants.json`), all 40 alchemy rows with amounts, elixir values and durations (`grug_alchemy/recipes.lua:24-110`), the 30 s potion cooldown and the Weak Healing Potion (35 HP, 8c), and the crown rule `min(10T+10, 70)` (`grug_quality/init.lua:827`).
- items_crafting.md: the tier and band table (`grug_materials/registry.lua:18-46`), harvest tiers, tool level requirements, gathering XP ratios, fuels, torches, the dual-furnace recipe, every gear recipe and armour count (`base_recipes.lua`), the occult components, wood grades, settings and trinket gems (`grug_artisans/goldsmith.lua`), bags, the food table (`grug_food/init.lua:15-55`), all 18 dishes, 6 raw assemblies and ingredient tiers (`grug_cooking/init.lua`), drop chances, boss drops, bag drops and the 26-item pool, the eleven enchant pools, the 552 + 36 operation count, the affix words, the trinket specials and caps, and the arrow and rod recipes.
- farming.md: the 18 crop families and classes (`crop_profiles.lua`), stage 200 ± 40 s, soil checks 15/60 s, water radius 3, the salt pan recipe, the 18 seed recipes, and every renewal constant (`renewal.lua:29-75`).
