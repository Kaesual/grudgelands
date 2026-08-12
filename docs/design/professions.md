# Professions

Decided 2026-08-06, roster **re-cut 2026-08-07** (crafting rework) and
material identities integrated 2026-08-12.
Crafting mechanics: `inventory_equipment.md` §4 (3×3 + recipe unlock +
workbench proximity). Recipe/material details: `items_crafting.md` —
the material ladder is its §3.0, the per-profession catalogs are
§3.3–§3.6b, and what a profession actually *does* to an item is §6b.

## 1. Structure

- **2 main professions per character, freely chosen at job trainers**
  (never class-bound — interdependence drives the server economy).
  Switching later: allowed, but learned progression of the dropped
  profession is lost (details with WP10).
- **Universal secondary skills — everyone can learn all of them:**
  **Cooking** and **First Aid** (bandages, simple heal items). They are
  the no-healer valve (classes.md balance constraints). **Neither costs
  a main profession slot** — restated 2026-08-07, because Cooking now has
  a recipe book and could otherwise be mistaken for a third profession.
  - **Cooking has a recipe book** with the same six T1–T6 groups and
    level gates as a profession book (`items_crafting.md` §2.2, §3.7),
    but **no keystones**: a cooking tier opens on its **ingredients**,
    which are regional, so **T6 cooking needs ingredients that only exist
    in level-50+ areas**. Tier unlocks are wanted as quest goals ("find
    cocoa in the jungle"). Free, universal *and* gated — the book is what
    makes all three true at once.
  - **First Aid keeps no book**: all recipes at once, materials are the
    only gate.
- **Gathering split**: food-grade plants (potatoes, berries, cooking
  ingredients) are gatherable by EVERYONE; **alchemy herbs
  ("dragonweed") require the Alchemist main profession** — for everyone
  else those plants are scenery. (Revised 2026-08-07: this used to name
  Herbalism, which no longer exists — see §2.)
- Mining and smelting are open to everyone (unchanged), and so is
  **crafting the base item of every material tier** (`items_crafting.md`
  §3.0.3). A profession is not what lets you make a sword; it is what
  lets you make a *better* sword.

## 2. MVP roster — six professions, cut by material (re-cut 2026-08-07)

Two free main professions per player, unchanged. The roster is organised
**by material, never by class**.

| Profession | Material chain T1–T6 | Owns exclusively |
|---|---|---|
| **Blacksmith** | Bronze → Iron → Steel → Silversteel → Embersteel → Abyssal Steel | Metal armor (4 slots), 1H weapons, daggers, 2H weapons, **shields** |
| **Leatherworker** | light → cured → heavy → scaled leather | Leather armor (4 slots), later **quivers** |
| **Tailor** | linen → woven → heavy → silkweave | Cloth armor (4 slots), **bags**, **spell tome** (offhand) |
| **Woodcarver** | wood incl. silverwood/gravewood; **buys metal fittings from the Blacksmith** | Staves, wands, scepters, orbs — later bows |
| **Goldsmith** | Gold + Quartz + the six regional G1/G2 gems | **Both trinket slots**, Rough → Cut gem refinement, Settings, jewelry components, and natural-gem bonus yield |
| **Alchemist** | healing herbs + spices | Potions, elixirs, apothecary gear — **gathers its own herbs** |

**One MVP caveat, on the Leatherworker.** The **Warrior can wear
leather** — a class wears its own rank and everything below
(`inventory_equipment.md` §2), so rank-2 armor is legal for rank-3
characters. But at equal tier leather is strictly less armor than metal,
so a Warrior has no *reason* to choose it, and the Rogue who would is
Phase 2. Whether the leather line registers in the MVP and what would
make it attractive is open in `TODO-design-crafting-rework.md` (C10).
The chain, the curve and the recipes are authored either way, and the
profession also ships on its armor kits, its quiver and its cross-supply
to Tailors and Alchemists (§3).

### 2.1 The coverage is complete and overlap-free

That is the property the re-cut was made for, and it is checkable:

- **Three armor classes, three professions.** Metal → Blacksmith,
  leather → Leatherworker, cloth → Tailor. No class of armor has two
  makers and none has none. The Alchemist's **apothecary gear**
  (`items_crafting.md` §3.6) is not an exception: it carries cloth-class
  armor *values* but it is a separate, three-piece identity line with
  potion effects on it, and the Alchemist cannot make the Tailor's cloth
  armor — which is why it cross-buys bolts.
- **Every weapon family of `items_crafting.md` §3.2 is assigned.** 1H,
  dagger and 2H to the Blacksmith; the caster 1H (wand / scepter / orb)
  and the 2H staff to the Woodcarver. Bows join the Woodcarver in
  Phase 2 (§5).
- **Both trinket slots finally have an owner** — the Goldsmith. In the
  old roster they had none at all. **The items ship in the MVP**
  (decided 2026-08-08): the slots are no longer reserved
  (`inventory_equipment.md` §2). Each trinket has exactly one primary-
  attribute prefix, one HP/Mana/Crit suffix and one authored special
  (`items_crafting.md` §6.2); cultural finishes never apply to trinkets.
- **The offhand is split, not shared**: the Tailor makes the **spell
  tome**, the Blacksmith makes the **shield**. Different items, different
  armor classes, different users — one item per concept holds
  (`items_crafting.md` §3.0.3).
- **Consumables** are the Alchemist's alone; **bags** are the Tailor's
  alone.

### 2.2 Why material-cut and not class-cut

A class-cut roster ("Warrior smith", "Mage outfitter") looks tidy with
three classes and **breaks the moment Phase 2 adds four more** — every
new class needs either a new profession or an awkward second home in an
old one, and the roster grows with the class list forever.

A material cut does not move when the class list does: Phase 2's Rogue
wants leather, which already has a maker; the Warlock wants cloth and a
wand, which already have makers.

It is also the only cut that keeps **§4's social supply chain** alive. A
profession that serves exactly one class serves exactly one customer per
group; a material profession serves several classes at once, which is
what makes a crafter worth finding on a server with a handful of players
online. The cross-buys are deliberate and already load-bearing: the
Woodcarver buys metal fittings from the Blacksmith (`items_crafting.md`
§3.6a) the same way Tailors and Alchemists buy leather from the
Leatherworker (§3 below).

### 2.3 Two professions were merged away

- **Herbalism merges into the Alchemist.** The Alchemist gathers its own
  herbs; the old gathering gate becomes the Alchemist's own book group
  (`items_crafting.md` §3.6).
- **Gem Hunter merges into the Goldsmith.** Its useful gathering identity
  survives as bonus yield from a successfully harvested natural or renewable
  gem node (`items_crafting.md` §3.6b). The old Gem Detector was tied to
  deleted private-island treasure clusters and is retired rather than given a
  continental radar role.

Both disappear as separate professions. They were the two asymmetric
stubs in the old roster — three tiers and two tiers against everyone
else's four — and burning one of a player's two main slots on a pure
gathering skill was never a real choice. **All six professions are now
symmetric: four mastery tiers each, six material groups each.**

### 2.4 The Woodcarver closes a real hole

`items_crafting.md` §3.2 used to leave wands and orbs **drop-only**,
which meant a Mage or a Priest had **no craftable weapon at all** — the
one outright gap in the old catalog, and one no re-balancing could fix
because the items did not exist. The Woodcarver makes the whole caster
weapon family craftable, refinable and enchantable like every other
weapon.

## 3. Cross-profession supply loops

Leather supply scales with participation, via the loot table (decided
2026-08-06): **if a Leatherworker damaged a leather-dropping mob, the
mob drops ×5 leather** (rides on the WP6 player-tag flag — the tag
records the profession). Cross-profession demand is intended: Tailors
need small amounts of leather for some recipes, Alchemists a bit for
their alchemist gear — trade, not self-sufficiency.

Added 2026-08-07, the same pattern in the other direction: **the
Woodcarver buys metal fittings from the Blacksmith.** Every caster weapon
from T2 up needs a Blacksmith-made fitting of its own tier
(`items_crafting.md` §3.6a) — the §3.2 family is literally called
"metal-shod staff". A profession that cannot finish its own top item
alone is the mechanism this section exists for; it is now used twice.

## 4. Vendor floor rule

**Vendors sell only the lowest tier of each item category** (smallest
bag, weak heal potion, basic tools). The harder the tier, the more social
the supply chain. (Also anchored in economy.md §2/§3.)

Revised 2026-08-07 twice over:

- The floor is not frozen at the starter set — it **moves with the
  player** through six bracket catalogs, one per material tier
  (`items_crafting.md` §3.8). Bands are 1-based: bracket 1 is levels
  1–10.
- **"Everything above is player-crafted" is now "everything above the
  base tier is player-*refined*".** Under the one-item-per-concept rule
  (`items_crafting.md` §3.0.3) the vendor's gear and the base craft
  ladder are the same items, so the old sentence would have read as
  "vendors sell what crafters make", which is true and useless. The
  correct line is sharper: **a vendor can never sell a refined or an
  enchanted item.** Refinement is profession-only, enchanting requires
  refinement (`items_crafting.md` §6b.1/§6b.3), and no vendor stocks
  either.

This does not weaken the crafting economy, it defines its lower edge: a
player without access to a Tailor is clothed but wearing plain cloth with
half the durability and no affixes, and every refined or enchanted piece
in the game still comes from a crafter or a boss.

## 5. Phase 2+

- **The Blacksmith is NOT split in the MVP** (decided 2026-08-07). With
  only two main slots, a self-equipping warrior who took Weaponsmith and
  Armorsmith would have burned both on one armor class and one weapon
  family — the split makes the profession *less* social, which is the
  opposite of §4's purpose. It stays a **Phase 2** note, for when the
  population supports specialization: Blacksmith → Weaponsmith +
  Armorsmith.
- **The Bowyer split is dropped entirely** (2026-08-07). Bows are a
  Woodcarver product (`items_crafting.md` §3.6a, §9) and the quiver stays
  Leatherworker, so there is nothing left for a Bowyer to own. The
  Leatherworker is not split.
- **Enchanter as a separate profession is dropped too**: enchanting is
  what every profession does to its own refined items
  (`items_crafting.md` §6b), not a seventh profession that would take a
  cut of all six.
- **Ranged-weapon prerequisite — still open**: there is no ranged-weapon
  system and no Hunter-like class in the current plan (MVP:
  Warrior/Mage/Priest; Phase 2 adds Paladin/Rogue/Warlock/Shaman).
  Whether a bow system + a ranged class come is a Phase 2 decision to
  make explicitly. The item path is specced and has an owner
  (`items_crafting.md` §9); only the class decision is missing.
- Cultural finishing is the scalable race/profession hook
  (`items_crafting.md` §4): a crafter applies only their own culture's fixed
  effects to families their profession owns, while finished stacks remain
  tradeable and wearable by anyone. The retired one-recipe-per-race model does
  not return in Phase 2.
