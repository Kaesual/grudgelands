# Professions

Decided 2026-08-06, roster **re-cut 2026-08-07** (crafting rework),
material identities integrated 2026-08-12 and profession progression revised
2026-09-18, and the smith split adopted 2026-09-20.
Crafting mechanics: `inventory_equipment.md` §4 (3×3 + profession-level
recipe permission + station hints). Recipe/material details: `items_crafting.md` —
the material ladder is its §3.0, the per-profession catalogs are
§3.3–§3.6b, and what a profession actually *does* to an item is §6b.

## 1. Structure

- **Exactly 2 primary profession slots per character, freely filled at
  profession trainers**
  (never class-bound — interdependence drives the server economy).
  Switching later is allowed at a trainer, but unlearning immediately wipes
  the dropped profession's level and current-tier craft count. The seven
  primaries are Weaponsmith, Armorsmith, Alchemist, Tailor, Leatherworker,
  Woodcarver and Goldsmith.
- **Secondary professions have no slot limit.** Cooking is the only secondary
  profession in the framework today. Every player may learn it in addition to
  both primaries. **First Aid remains universal but is not a profession in
  this framework and has no book.** Both systems remain the no-healer valve
  from `classes.md`.
  - Cooking has the same visible T1–T6 book groups and profession-level gate
    as every primary profession (`items_crafting.md` §2.2, §3.7).
  - **Riding is likewise universal**, but is taught only by the dedicated
    Riding Trainer in each capital's outer stable, in four steps at levels
    15/30/45/60 (`mounts.md` §1). It costs no main profession slot, is not a
    framework profession and is absent from all profession trainer interfaces.
- **Cooking in every start, all eight in every capital.** The eight capital
  trainers are the seven primaries plus Cooking.
  Capital trainers and their public stations occupy themed outer-district
  premises, reusing suitable shops; vendors remain separate NPCs. Weaponsmith
  and Armorsmith share one forge house with separate trainers and one Forge.
  The other premises are an Alchemist's herb court and brewing stand, Tailor's
  cloth hall and loom, Leatherworker's drying racks and tubs, Woodcarver's timber
  and carving shop, Goldsmith's display cases and workbench, and Cooking kitchen
  with hearth and counter. Stations and trainers have safe, unobstructed access.
  Forge dressing includes an anvil, quench basin, decorative lava and visible
  weapon/armor displays. Authored display gear has no collectible inventory;
  interaction, digging, damage, explosions and indirect node transformations
  cannot release items. This guarantee is intrinsic to the display definitions,
  independent of the unfinished general protection system.
- **Gathering split**: food-grade plants (potatoes, berries, cooking
  ingredients) are gatherable by EVERYONE; **alchemy herbs
  ("dragonweed") require the Alchemist main profession** — for everyone
  else those plants are scenery. (Revised 2026-08-07: this used to name
  Herbalism, which no longer exists — see §2.)
- Mining and smelting are open to everyone (unchanged), and so is
  **crafting the base item of every material tier** (`items_crafting.md`
  §3.0.3). A profession is not what lets you make a sword; it is what
  lets you make a *better* sword.
- Learning any framework profession opens profession tier 1. A fixed number
  of successful crafts at the current profession tier opens the next tier:
  **10 / 15 / 20 / 25 / 30** crafts for T1→T2 through T5→T6. Lower-tier
  crafts do not count and above-tier crafts are refused. The effective
  profession tier is capped by the character band: T1 L1–10, T2 L11–20,
  T3 L21–30, T4 L31–40, T5 L41–50, T6 L51–60. Reaching a craft threshold
  while character-capped leaves the stored profession tier unchanged and
  saturates the current-tier counter at its threshold. Entering the next
  character band does not advance the profession automatically: the next
  successful craft of the previous tier opens the new tier and clears the
  counter. Further crafts while still character-capped count nothing.
- Profession level gates crafting only. Item consumption and equipment remain
  independently gated by `_grug_ilvl`; neither consuming an item nor checking
  its use requirement consults profession state.

## 2. MVP roster — seven professions, cut by material

Two free main professions per player, unchanged. The roster is organised
**by material, never by class**.

| Profession | Material chain T1–T6 | Owns exclusively |
|---|---|---|
| **Weaponsmith** | Bronze → Iron → Steel → Silversteel → Embersteel → Abyssal Steel | Physical weapons and mining tools |
| **Armorsmith** | Bronze → Iron → Steel → Silversteel → Embersteel → Abyssal Steel | Metal armor and shield refinement/affixes; plain shields are Basics |
| **Leatherworker** | light → cured → heavy → scaled → sleek → nightscale leather | Leather armor, leather bags and the quiver |
| **Tailor** | patch → woven → heavy → silkweave → silk → stormweave bolts | Cloth armor and cloth bags |
| **Woodcarver** | any `group:wood`, graded Seasoned → Polished → Hardened → Inlaid → Lacquered → Heartwood | Staff, wand and bow refinement/affixes; plain items are Basics |
| **Goldsmith** | Gold + Quartz + the six regional G1/G2 gems | Both trinket slots, spellbooks, gem refinement, Settings and jewelry components |
| **Alchemist** | healing herbs + spices | Potions, elixirs, apothecary gear — **gathers its own herbs** |

### 2.1 The coverage is complete and overlap-free

That is the property the re-cut was made for, and it is checkable:

- **Three armor classes, three professions.** Metal → Armorsmith,
  leather → Leatherworker, cloth → Tailor. No class of armor has two
  makers and none has none. The Alchemist's **apothecary gear**
  (`items_crafting.md` §3.6) is not an exception: it carries cloth-class
  armor *values* but it is a separate, three-piece identity line with
  potion effects on it, and the Alchemist cannot make the Tailor's cloth
  armor — which is why it cross-buys bolts.
- **Every weapon family of `items_crafting.md` §3.2 is assigned.** 1H,
  dagger and 2H to the Weaponsmith; wand, staff and bow quality to the
  Woodcarver. Scepters and orbs are absent from V1.
- **Both trinket slots finally have an owner** — the Goldsmith. In the
  old roster they had none at all. **The items ship in the MVP**
  (decided 2026-08-08): the slots are no longer reserved
  (`inventory_equipment.md` §2). Each trinket has exactly one primary-
  attribute prefix, one HP/Mana/Crit suffix and one authored special
  (`items_crafting.md` §6.2); cultural finishes never apply to trinkets.
- **Offhands have distinct roles**: plain shields are Basics and Armorsmith
  improves them; Goldsmith makes spellbooks; Leatherworker makes the no-stat
  four-stack quiver. A bow permits only the quiver beside it.
- **Consumables** are the Alchemist's alone. Tailor owns cloth bags and
  Leatherworker owns equal-capacity leather bags.

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
Woodcarver buys metal fittings from the Weaponsmith (`items_crafting.md`
§3.6a) the same way Tailors and Alchemists buy leather from the
Leatherworker (§3 below).

### 2.3 Two professions were merged away

- **Herbalism merges into the Alchemist.** The Alchemist gathers its own
  herbs; the old gathering gate becomes the Alchemist's own book group
  (`items_crafting.md` §3.6).
- **Gem Hunter merges into the Goldsmith.** Its useful gathering identity
  survives as bonus yield from a successfully harvested natural or renewable
  gem node (`items_crafting.md` §3.6b): **10% base chance at Apprentice, 20%
  from Journeyman onward**, rolled once after a valid harvest and granting one
  additional raw gem item of the harvested species. The old Gem Detector was
  tied to deleted private-island treasure clusters and is retired rather than
  given a continental radar role.

Both disappear as separate professions. They were the two asymmetric
stubs in the old roster — three tiers and two tiers against everyone
else's four — and burning one of a player's two main slots on a pure
gathering skill was never a real choice. **All seven professions are now
symmetric: four mastery tiers each, six material groups each.**

### 2.4 The Woodcarver closes a real hole

The active caster roster is two-handed staff or one-handed wand plus a
Goldsmith spellbook. Plain staff/wand recipes are Basics; Woodcarver owns their
refinement and affixes. Scepters and orbs are absent from fresh V1 worlds.

## 3. Cross-profession supply loops

Leather supply scales with participation, via the loot table (decided
2026-08-06): **if a Leatherworker damaged a leather-dropping mob, the
mob drops ×5 leather** (rides on the WP6 player-tag flag — the tag
records the profession). Cross-profession demand is intended: Tailors
need small amounts of leather for some recipes, Alchemists a bit for
their alchemist gear — trade, not self-sufficiency.

Added 2026-08-07, the same pattern in the other direction: **the
Woodcarver buys metal fittings from the Weaponsmith.** Professional refinement of every caster weapon
from T2 up needs a Weaponsmith-made fitting of its own tier
(`items_crafting.md` §3.6a) — the §3.2 family is literally called
"metal-shod staff".

Added 2026-08-13 with the A1 signature table, the third relationship:
**the Woodcarver buys weapon grips from the Leatherworker** — the
Leatherworker's Apprentice signature component, 2 leather of the item's
tier (`items_crafting.md` §2.1/§3.4). A profession that cannot finish
its own top item alone is the mechanism this section exists for; it is
now used three times.

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

The former Blacksmith is split in the current roster. Weaponsmith and Armorsmith
use one shared physical Forge but have separate trainers, books, progression and
recipe ownership. The seven primaries still compete for two slots; a metal user
who wants both specialties spends both slots, matching the two-profession cost
of cloth or leather users who also want a professionally improved weapon.

- **The Bowyer split is dropped entirely** (2026-08-07). Plain bows are Basics,
  while Woodcarver owns their quality operations; the quiver stays
  Leatherworker, so there is nothing left for a Bowyer to own. The
  Leatherworker is not split.
  *A settlement shop called a bowyer is not this.* Since 2026-09-15 a
  settlement may hold one of twelve **profession shop vendors** — butcher,
  smith, fishmonger, baker, tailor, mason, brewer, bowyer, herbalist,
  armourer, tanner, embalmer (`settlements.md`, "Settlement NPCs and guard
  targeting"). Those are shopkeepers with a shelf of their trade; nothing is
  taught, levelled or unlocked at one, and the six crafting professions of §2
  are unaffected by which shops a city has.
- **Enchanter as a separate profession is dropped too**: enchanting is
  what every profession does to its own refined items
  (`items_crafting.md` §6b), not a seventh profession that would take a
  cut of all six.
- **The bow foundation now has the Scout consumer.** Six tier bows and the
  wooden starter are active V1 equipment. Woodcarver improves bows;
  Leatherworker makes the optional four-stack quiver.
- Cultural finishing is the scalable race/profession hook
  (`items_crafting.md` §4): a crafter applies only their own culture's fixed
  effects to families their profession owns, while finished stacks remain
  tradeable and wearable by anyone. The retired one-recipe-per-race model does
  not return in Phase 2.
