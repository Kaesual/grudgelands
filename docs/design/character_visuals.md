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

Each race carries a **visual scale** between 0.85 and 1.12 — dwarves and orcs
broader and lower, elves and trolls taller, humans the 1.0 reference:

| Race | x / y / z |
| --- | --- |
| Human | 1.00 / 1.00 / 1.00 |
| Dwarf | 1.10 / 0.88 / 1.10 |
| Elf | 0.94 / 1.06 / 0.94 |
| Undead | 0.90 / 1.00 / 0.90 |
| Orc | 1.12 / 0.98 / 1.12 |
| Troll | 1.10 / 1.12 / 1.10 |

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

An overlay is drawn once, in the **highest bracket's** colour, and the six
brackets are one tint apart: the same six colours the vendor item icons use, so
a Crude helm looks Crude on the icon and on the head. A character therefore
shows exactly what it is wearing, per slot, at the bracket it bought.

NPCs that have no inventory wear a **whole line at one bracket** instead:

| NPC | Wears |
| --- | --- |
| Faction guard | metal line at the bracket its own level buys — the elite city watch (60+) is the sixth, "Grand" bracket by construction |
| Bandit | cloth line at the bracket its camp's level buys |
| Vendor | no armor: race dress, so a shopkeeper never reads as a guard |
| Mirefolk | its own fish-folk skin, no armor |

## 4. The weapon in hand

A character with a weapon **holds it**: one attached entity on the right-hand
bone, showing the weapon's own item art, updated when the weapon changes and
removed when the hands are empty. Guards carry a sword, bandits a dagger, and a
player carries whatever is in the weapon slot — the same item that is the single
source of melee damage.

It is held the way a weapon is held: **the grip in the fist, the blade pointing
forward and slightly up, its flat vertical** so the silhouette reads from the
side (decided 2026-09-15, playtest round 1). The pose is not tuned by eye — it
is derived from the character mesh's own bone tree and the engine's wielditem
extrusion, and the derivation lives with the numbers in
`mods/PLAYER/grug_visuals/wield_geometry.lua`.

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

The state of the implementation — what is already tuned and what still needs a
look in the client — lives in the increment record,
[wp13-character-visuals.md](../research/wp13-character-visuals.md).
