# Character visuals

What a humanoid looks like in Grudgelands: race skin, stature, visible armor
and the weapon in hand. One rule set for players and for the humanoid NPCs on
the same model, so the two can never disagree.

Decided 2026-09-14 (WP13). The implementation seam is
[wp13-character-visuals-contract.md](../research/wp13-character-visuals-contract.md);
the settlement side that populates the starts with those NPCs is
[settlements.md](settlements.md).

## 1. One model, six peoples

Every humanoid — player, guard, bandit, vendor, mirefolk — uses the engine's
`character.b3d`. A character's appearance is **composed** from at most four
layers, in this order:

1. the **race skin** (or, for a humanoid that is nobody's race, its own skin);
2. the **head** overlay;
3. the **chest** overlay (it also carries the shoulders and sleeves);
4. the **legs** overlay, then the **feet** overlay.

The six race skins differ in skin tone, hair mass and dress, so a people is
readable at a distance before anything else about the character is:

| Race | Reads as |
| --- | --- |
| Human | tan skin, brown crop, blue-grey tunic |
| Dwarf | ruddy skin, full ginger beard, green tunic, brass belt |
| Elf | ivory skin, long pale hair, pointed ears, silver-green dress |
| Undead | grey-green pallor, sunken glowing sockets, ribs through a torn violet wrap |
| Orc | green skin, tusks, black topknot, bare chest under a leather harness |
| Troll | blue-grey hide, tusks, dark blue mane, ochre wraps |

## 2. Stature is visual only

Each race carries **one visual scale** between 0.85 and 1.12 — the same number
in all three axes — with trolls and orcs the largest and dwarves the smallest:

| Race | scale |
| --- | --- |
| Human | 1.00 |
| Dwarf | 0.90 |
| Elf | 1.06 |
| Undead | 0.94 |
| Orc | 1.08 |
| Troll | 1.12 |

**It is one scalar, not an (x, y, z) triple** (decided 2026-09-15, playtest
round 2). The first version made dwarves and orcs *broader and lower*
(1.10 / 0.88 and 1.12 / 0.98), which reads better on a body — but a
non-uniform scale is inherited by whatever is attached to the character, in
model axes and after that attachment's own rotation. On the weapon in the hand
(§4) that is a shear: the blade comes out longer, thinner and tilted, and no
size on the weapon can cancel it while a race's vertical and horizontal scales
differ. So the anisotropy went and the **body shape belongs to the skin art**,
which the engine cannot shear. The derivation is in
`mods/PLAYER/grug_visuals/wield_geometry.lua`.

**The collision box and the eye height never change.** Stature is a look, not a
rule: every race walks through the two-node doors of its own houses, takes the
same damage from the same fall and fits the same boat seat. Nothing in combat,
building or movement may be derived from it.

Humanoid **mobs keep the size their own definition sets** (the mirefolk are
deliberately short, an elite guard is deliberately large). Their scale belongs
to the mob engine, which owns it across tier promotions and world reloads.

## 3. Visible armor

Two armor lines ship — **cloth** and **metal**, the two `grug_gear` registers —
and each has one overlay per slot: head, chest, legs, feet. Leather borrows the
cloth cut until its own art exists, because it has no wearer before the Rogue.

An overlay is drawn once in its tier's colour, and the six tiers are one tint
apart: the same six colours the armor item icons use, so a Bronze helm looks
bronze on the icon and on the head. A character therefore shows exactly what it
is wearing, per slot, at the tier it bought.

NPCs that have no inventory wear a **whole line at one tier** instead:

| NPC | Wears |
| --- | --- |
| Faction guard | metal line at the tier its own level buys — the elite city watch (60+) is the sixth, Abyssal Steel tier by construction |
| Bandit | cloth line at the tier its camp's level buys |
| Vendor | no armor: race dress, so a shopkeeper never reads as a guard |
| Mirefolk | its own fish-folk skin, no armor |

## 4. The weapon in hand

A character with a weapon **holds it**: one attached entity on the right-hand
bone, showing the item's own art, updated when what it holds changes and removed
when the hands are empty. Guards carry a sword and bandits a dagger.

**What a player is shown holding** (decided 2026-09-15, playtest round 2) is
read off the hotbar, in three cases:

1. a **skill** in hand shows the **equipped weapon** — a skill is an orb wearing
   that weapon's art and takes its damage from the weapon slot, so the hand
   shows the weapon;
2. **any other item** in hand shows that item — a pickaxe is a pickaxe, a torch
   is a torch;
3. an **empty hand** shows nothing.

So the weapon slot is the single source of *damage*, but it is not automatically
what the character is carrying: a player who selects a shovel sees a shovel.

It is held the way a weapon is held: **the grip in the fist, the blade straight
forward at a right angle to the arm, its flat vertical** so the silhouette reads
from the side. The pose is not tuned by eye — it is derived from the character
mesh's own bone tree and the engine's wielditem extrusion, and the derivation
lives with the numbers in `mods/PLAYER/grug_visuals/wield_geometry.lua`.

That derivation is possible because **every weapon and tool in the game is drawn
in one sprite convention**: 16×16, long axis on the image's diagonal, grip at the
bottom left — minetest_game's own tool convention. Two conventions would need
two transforms, and one of them would be wrong.

**An item that is not a weapon or a tool is held upright instead**: a torch, an
apple, a sapling or a bag is an ordinary icon with no diagonal and no grip, so
it is held by its centre, standing up, its face vertical like a blade's. The two
poses are the two kinds of art, and nothing else; which one an item gets is read
off the sword / axe / pickaxe / shovel / staff families it declares.

**The weapon is the same weapon in every hand.** The attachment inherits the
wielder's stature (§2), so the entity's size divides it out; a dwarf's sword and
a troll's sword are the same object. A humanoid *mob* is deliberately not
compensated: its scale is its real size, and a giant's weapon should be a
giant's weapon.

One entity per character, never more. The **offhand is not drawn yet**; shields
arrive with the offhand work.

## 5. Rules that hold everywhere

- Appearance is composed by **one function** for players and NPCs. Two mods
  writing the model's texture list independently is the failure this replaces.
- Composition uses **texture modifiers only**. Nothing is generated per frame,
  no image is built at runtime, and the web build needs no exception.
- A character whose look has not changed **writes no texture**: equipping a
  trinket, opening the inventory or taking a hit costs no update. The stature
  is re-asserted every time instead, because the scale is not this system's
  alone to own — a dismount resets it.
- An unknown race falls back to Human, once, loudly in the log — a missing skin
  is a content bug, never a crash or an invisible character.
- **The composed look is written before anything reads it back.** The Character
  page draws the character's live appearance, so appearance is composed first
  and the page refreshed second; there is exactly one page refresh.
- The hotbar selection has no server-side change hook, so §4's display rule is
  driven by **one throttled poll, once a second per player**, on top of the
  equipment-change callback. That poll is also the retry for an attachment the
  engine refused (no loaded block yet, an entity budget) — a weapon that failed
  to appear reappears on the next pass instead of staying invisible.

The state of the implementation — what is already tuned and what still needs a
look in the client — lives in the increment record,
[wp13-character-visuals.md](../research/wp13-character-visuals.md).
