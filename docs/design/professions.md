# Professions

Decided 2026-08-06 (design discussion). Crafting mechanics:
`inventory_equipment.md` §4 (3×3 + recipe unlock + workbench proximity).
Recipe/material details: `items_crafting.md`.

## 1. Structure

- **2 main professions per character, freely chosen at job trainers**
  (never class-bound — interdependence drives the server economy).
  Switching later: allowed, but learned progression of the dropped
  profession is lost (details with WP10).
- **Universal secondary skills — everyone can learn all of them:**
  **Cooking** and **First Aid** (bandages, simple heal items). They are
  the no-healer valve (classes.md balance constraints).
- **Gathering split**: food-grade plants (potatoes, berries, cooking
  ingredients) are gatherable by EVERYONE; **alchemy/craft herbs
  ("dragonweed") require the Herbalism main profession** — for everyone
  else those plants are scenery.
- Mining and smelting are open to everyone (unchanged).

## 2. MVP roster (main professions)

| Profession | Makes / gathers | Notes |
|---|---|---|
| Blacksmith | metal weapons + metal armor | splits into Weapon-/Armorsmith in Phase 2 |
| Leatherworker | leather/dex gear | see §3; splits off Bowyer once ranged weapons exist |
| Tailor | cloth armor, **bags** | cloth from humanoids (bandit camps) |
| Alchemist | potions | strong potions; weak heal potions are vendor goods |
| Herbalism | alchemy/craft herbs | gathering profession; food plants excluded (universal) |
| Gem Hunter | bonus gem drops while mining | as decided for WP10 |

## 3. Leatherworker supply mechanic

Leather supply scales with participation, via the loot table (decided
2026-08-06): **if a Leatherworker damaged a leather-dropping mob, the
mob drops ×5 leather** (rides on the WP6 player-tag flag — the tag
records the profession). Cross-profession demand is intended: Tailors
need small amounts of leather for some recipes, Alchemists a bit for
their alchemist gear — trade, not self-sufficiency.

## 4. Vendor floor rule

**Vendors sell only the lowest tier of each item category** (smallest
bag, weak heal potion, basic tools); everything above is
player-crafted. The harder the tier, the more social the supply chain.
(Also anchored in economy.md §2/§3.)

## 5. Phase 2+

- **Splits** (when population supports specialization): Blacksmith →
  Weaponsmith + Armorsmith; Tailor + Enchanter (enchanting as a
  profession ties into the items/enchant design, items TODO); 
  Leatherworker → Leatherworker + Bowyer.
- **Bowyer prerequisite — OPEN**: there is no ranged-weapon system and
  no Hunter-like class in the current plan (MVP: Warrior/Mage/Priest;
  Phase 2 adds Paladin/Rogue/Warlock/Shaman). Whether a bow system + a
  ranged class come is a Phase 2 decision to make explicitly.
- Race-exclusive recipes stay the planned race-perk hook (world.md §7,
  Phase 2).
