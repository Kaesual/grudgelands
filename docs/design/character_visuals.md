# Character visuals

What a humanoid looks like in Grudgelands: race and look, stature, visible
armor and the weapon in hand. One rule set for players and for the humanoid NPCs on
the same model, so the two can never disagree.

Decided 2026-09-14 (WP13). The implementation seam is
[wp13-character-visuals-contract.md](../research/wp13-character-visuals-contract.md);
the settlement side that populates the starts with those NPCs is
[settlements.md](settlements.md).

## 1. One model, six peoples

Every humanoid — player, guard, bandit, vendor, mirefolk — uses the engine's
`character.b3d`. A humanoid of a race is **composed** from layers on the one
64×32 skin, in this order (decided 2026-10-03, Round 31):

1. **skin** — the skin tone, then the race's body: face, shading and the race's
   one dress;
2. **eyes**;
3. **hairstyle** in a hair colour — left out entirely under a helmet;
4. **attire** — a royal tabard (kings and royal guards only);
5. **body armor** — chest (with shoulders and sleeves), legs, feet;
6. **helmet**, with one shared **face window** cut out of every helmet, so the
   eyes and the lower face stay visible and the hair is hidden;
7. **headwear** — a king's crown;
8. the race's **lower-face feature** (beard, tusks, ears, …), last, so it shows
   over the helmet.

A humanoid that is nobody's race (the mirefolk) keeps its own skin with its
armor over it.

The six dresses keep a people readable at a distance before anything else
about the character is:

| Race | Dress |
| --- | --- |
| Human | blue-grey tunic |
| Dwarf | green tunic, brass belt |
| Elf | silver-green dress |
| Undead | torn violet wrap, ribs showing through |
| Orc | bare chest under a leather harness |
| Troll | ochre wraps over a bare chest |

### 1.1 Looks

Only body features are chosen — no clothing, capes or headwear. Five
categories, options per race (skin tones stay within the race's look):

| Race | Skin tones | Hair colours | Hairstyles | Eyes | Lower-face feature |
| --- | --- | --- | --- | --- | --- |
| Human | 4 | 6 | short crop, side parting, long, ponytail | 3 | stubble, short beard, moustache |
| Dwarf | 3 | 5 | full, bald crown, braid | 3 | full, braided, forked or short beard (hair colour) |
| Elf | 3 | 5 | long, high tail, crown braid, short | 3 | pointed ears, long ears, ears and face marking (skin tone) |
| Orc | 3 greens | 4 | topknot, mohawk, shaved, braids | 3 | small, large or broken tusks, war paint |
| Troll | 3 blue-greys | 5 | mane, crest, swept back, twin tails | 3 | small, large or huge tusks |
| Undead | 3 | 4 | patchy, stringy, bald | 3 glow colours | exposed jaw, stitches, sunken nose |

Colours are not separate art: a coloured layer is a white mask coloured by the
engine (`^[multiply`) with a detail layer of shading and fixed colours over it.
A dwarf beard reaches onto the chest and lies over the armor there.

**Character creation** ends with the look, after the class and before the
arrival: one page with previous/next per category, a random button and a
rotating full-body preview, and one "Confirm — cannot be changed later". The
look is stored once in player meta and never changes — there is no command
and no wardrobe. A character without a stored look is drawn with the first
option in every category.

**NPCs** roll their look once, the first time they are drawn, and keep it with
the entity. Town and capital NPCs and their guards are of their settlement's
race; any other faction NPC (an outpost or fortress guard, a Quartermaster
outside a settlement) rolls one race of its faction and keeps it. A
garrison that is mixed by design — a PvP fortress's guards, registered under
their side's seat race — rolls a race of its faction even inside that
settlement: its placer marks it (`grug_visuals.npc_race` with
`{mixed = true}`, or the entity field `_grug_mixed_race`). Every option
may be rolled. Royal guards are of their king's race with their own rolled
look and the royal tabard; a king has one fixed look with the tabard and a
crown, in his people's royal colours.

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

**The collision box, the selection box and the eye height never change**: they
are the same for every race (fairness, Round 31), and only the visual size
differs. Visual stature keeps all races within the same two-node door and
boat-seat geometry. It does not
change the fall calculation or other combat, building or movement rules.
Fall damage follows [combat_stats.md](combat_stats.md), including the Dwarf's
20% reduction after maximum-HP scaling (absorb does not cover fall damage).

Humanoid **mobs keep the size their own definition sets** (the mirefolk are
deliberately short, an elite guard is deliberately large). Their scale belongs
to the mob engine, which owns it across tier promotions and world reloads.

## 3. Visible armor

Three armor lines ship — **cloth**, **leather** and **metal** — and each has one
overlay per slot and material tier: head, chest, legs and feet. Inventory art
and worn art are separate assets made for their respective layouts. Every tier
has a baked material treatment and silhouette details from one coherent source
family; runtime tinting is not the tier ladder. A character therefore shows the
same armor line, slot and material tier that its equipped item names.

NPCs that have no inventory wear a **whole line at one tier** instead:

| NPC | Wears |
| --- | --- |
| Faction guard | metal line at the tier its own level buys — the elite city watch (60+) is the sixth, Abyssal Steel tier by construction |
| Bandit | cloth line at the tier its camp's level buys |
| Vendor | no armor: its race's dress, so a shopkeeper never reads as a guard |
| Royal guard | no armor: the royal tabard over the race's dress |
| King | no armor: the royal tabard and a crown |
| Mirefolk | its own fish-folk skin, no armor |

## 4. The weapon in hand

A character with a weapon **holds it**: one attached entity on the right-hand
bone, showing the item's own art, updated when what it holds changes and removed
when the hands are empty. Guards carry a sword and bandits a dagger.

**What a player is shown holding** (decided 2026-09-15, playtest round 2) is
read off the hotbar, in three cases:

1. a **skill** in hand shows the **item of that skill's slot** — a skill is an
   orb wearing that item's art and takes its damage from that slot, so the
   hand shows the weapon. Since Round 28 the slot is per skill and class: a
   Scout's bow skills show the bow from its Ranged slot, its Strike and
   Opening the sword or dagger from its Melee slot; every other class's
   skills show the Weapon slot;
2. **any other item** in hand shows that item — a pickaxe is a pickaxe, a torch
   is a torch;
3. an **empty hand** shows nothing.

So the skill's slot is the single source of *damage*, but it is not
automatically what the character is carrying: a player who selects a shovel
sees a shovel.

It is held the way a weapon is held: **the grip in the fist, the blade straight
forward at a right angle to the arm, its flat vertical** so the silhouette reads
from the side. The pose is not tuned by eye — it is derived from the character
mesh's own bone tree and the engine's wielditem extrusion, and the derivation
lives with the numbers in `mods/PLAYER/grug_visuals/wield_geometry.lua`.

That derivation is possible because **every weapon and tool in the game is drawn
in one sprite convention**: 16×16, long axis on the image's diagonal, grip at the
bottom left — minetest_game's own tool convention. Two conventions would need
two transforms, and one of them would be wrong.

**Unprofiled items use a centred forward pose** (Round 12): rotate the previous
upright fallback 90 degrees forward around its centre grip. Torches, apples,
saplings and bags receive this fallback unless their definition supplies an
explicit `_grug_wield_pose`. An explicit valid pose wins, followed by existing
bow/axe/tool family dispatch; the forward pose is last. The upright pose remains
available explicitly. This changes third-person/world character attachments,
including humanoid NPCs, not the engine's separate first-person wieldmesh.

**An axe is held edge-down** (decided 2026-09-16, playtest round 5: "the axe
blades of the Dur Brannoc residents point the wrong way"). The convention above
fixes a sprite's long axis and leaves the *roll* about it free, and an axe is
the one family whose art cannot sit on that axis: its bit is a wide edge across
the end of the haft, drawn to one side. Held in the plain tool pose that side
points at the sky and the axe chops with its back. The axe pose is the same
transform rolled half a turn about the blade, so that the **cutting edge leads
the swing** — nothing else about the weapon moves, and a sword, dagger, pick,
shovel or rod cannot tell the two rolls apart at all (their art is symmetric
about the axis, measured).

Existing diagonal-tool, edge-down axe and bow poses retain their exact grip,
rotation and stature compensation. Generic items use the forward fallback;
upright is an explicit opt-in. Family selection uses sword / axe / pickaxe /
shovel / staff / fishing rod and weapon/bow groups, with bow then axe priority.
Invalid explicit pose values fail the startup audit rather than silently changing
appearance.

**The weapon is the same weapon in every hand.** The attachment inherits the
wielder's stature (§2), so the entity's size divides it out; a dwarf's sword and
a troll's sword are the same object. A humanoid *mob* is deliberately not
compensated: its scale is its real size, and a giant's weapon should be a
giant's weapon.

One entity per character, never more. The **offhand is not drawn beside the
weapon**; only a Scout's Melee skill puts the offhand blade into the hand
(case 1 above).

## 5. Rules that hold everywhere

- Appearance is composed by **one function** for players and NPCs. Two mods
  writing the model's texture list independently is the failure this replaces.
- Composition uses **texture modifiers only**. Nothing is generated per frame,
  no image is built at runtime, and the web build needs no exception. Every
  armor piece sits in its own parentheses, so a piece's own modifier (the
  Silversteel correction, a crack, its enchant colours) never reaches
  the layers under it; a helmet's own layers are cut by the face window with
  it.
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

## 5a. Enchant colours (Round 31)

Decided 2026-10-03 (round31-plan.md §2.2 and §6 item 7, approved variant N).
Enchantments show on gear as small **accents**, never as a repaint of the base
item:

- Every weapon, offhand and armour texture, and every worn armour overlay, has
  two non-overlapping pixel groups: **group A** (a highlight or edge stripe of
  the main material) takes the **prefix** stat's colour, **group B** (a fitting:
  grip wrap, guard, strap, hem, rim) the **suffix** stat's colour. Each group is
  a thin connected stripe of about 7 % of an inventory icon and 4 % of a worn
  overlay; lone pixels are never coloured.
- Each of the nine affix stats has one fixed colour (`grug_gear.ENCHANT_COLORS`):
  Strength deep red, Dexterity mint green, Intelligence indigo, maximum HP
  rose, maximum Mana sky blue, Crit yellow, attack speed orange, Dodge
  lavender, armour rating white. They stay apart for normal vision and for
  red-green colour blindness. The colour lies over the material at **50 %**.
- The colour shows on the **inventory icon**, the item **in hand** (first and
  third person) and a **dropped** item, through the stack's own
  `inventory_image`, and on the **armour worn on the body** (each piece's
  layers inside that piece's parentheses; a helmet's are cut by the face
  window with it; a broken piece cracks with its colours). A plain item has no
  image of its own and looks exactly as before.
- **Kings** hold their weapon in fixed colours of their weapon's pool; this is
  visual only, their rewards are rolled as before. A future named NPC with gear
  uses the same visual spec field (`weapon_colors`). Ordinary guards, royal
  guards, bandits and the named rares (beasts without gear) stay plain.
- Trinkets have no texture masks and stay uncoloured; a Scout's bow shows plain
  while it is being drawn (the draw stages are other shapes).
- Every enchanting station shows a **legend** of the nine colours.

The masks are generated (`tools/r31_b/gen_enchant_masks.py`, one two-frame
`<texture>_ench.png` per texture, each under its source texture's licence).

## 6. Round 11 item and station presentation

Decided 2026-09-20. Silversteel reads as bright neutral silver with subtle cold
shadows across inventory icons, worn armor and the metal parts of weapons and
tools; keep the accepted weapon silhouettes. New bows use an explicit bow pose
consistent with their real sprite geometry: the hand grips the middle of the
arc/string crossing and the long arc stands upright facing forward, rather than
using the diagonal tool convention's lower-left grip.

Use individually licensed and visually inspected pinned-reference media for
seed silhouettes, hoes, the Tailor loom and the shared smith anvil. The
Goldsmith uses a muted gold anvil head on a dark base; Woodcarver uses an upright
bench. Cloth/leather bag variants may share a readable shape with a material
color distinction. Shields, books and bows have representative inventory art
(the quiver art is the Scout quiver slot's ghost image); never use an
unwrapped 3D-model texture as an item icon.

Protected exterior product frames and interior stands identify all capital
professions, following [settlements.md](settlements.md). Fixed display items
are scenery, with no removable inventory or collectible drop. The open stable
and its living mount displays follow [mounts.md](mounts.md).

### Round 12 inventory-art families

Cooking results use recipe-specific silhouettes at native 16x16 scale rather
than role-colourized ingredient placeholders. Bowls, pots, platters, jars,
mugs, whole fish and tied raw preparations may share a family vocabulary, but
each result remains distinguishable beside the Cooking catalog. Jungle Cocoa
is a steaming brown drink, never a fruit silhouette. Raw ingredient icons
remain unchanged.

Wands have a short grip and shaft with a faceted magical focus, distinct from
a loose crystal, dagger or staff. Greataxes have a broad opposing double-bit
head and must not read as a spear or halberd. Both families keep one silhouette
across all six tier palettes and the established diagonal convention: grip at
approximately `(3.4, 12.6)` in 16x16 sprite coordinates, business end toward
the upper right. Accepted swords, one-handed axes and armor are unchanged.

### Frost Nova feedback

While a target remains under Nova's actual root, emit a few small pale-blue
crystal particles around its lower body, scaled simply to the live collision
box. Stop on root expiry, immunity, death or removal; particles may fade for
less than one second. No fitted shell or persistent decorative entity is used.

## Broken equipment

Cosmetic hand attachments retain broken equipped items with a crack overlay;
combat eligibility remains disabled. Worn armor cracks affect only the broken
slot's texture layer, not skin or intact equipment. Repair removes the overlay
and preserves the item's current enchantment appearance (its enchant colours,
§5a).
