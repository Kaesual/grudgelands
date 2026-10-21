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
`character.b3d`: players wear it with a cloak, the armour boxes and a weapon
card appended (§3, §5b), armoured NPCs with the armour boxes (§3), everybody
else as it is. A humanoid of a race is **composed** from layers on the one
64×32 skin, in this order (decided 2026-10-03, Round 31; the helmet became a
box in Round 54):

1. **skin** — the skin tone, then the race's body: face, shading and the race's
   one dress;
2. **eyes**;
3. **hairstyle** in a hair colour — left out entirely under a helmet;
4. **attire** — a royal tabard (kings and royal guards only);
5. **body armor** — the inner paint of the chest (with sleeves), legs and
   feet pieces, under their boxes (§3);
6. **headwear** — a king's crown;
7. the race's **lower-face feature** (beard, tusks, ears, …), last.

A worn helmet is a box over the head: the hair is left out under it, and
the face stays the race's.

A humanoid that is nobody's race (the mirefolk) keeps its own skin with its
armor's inner paint over it.

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

**Character creation** chooses the look in the same window as faction, race
and class ([world.md](world.md) §7): previous/next per category, a random
button and a full-body preview the player turns with the mouse (no
auto-rotation, no weapon). A race choice rolls a random look; the look is
stored only by "Create character", together with the rest, once in player
meta, and never changes — there is no command and no wardrobe. A character
without a stored look is drawn with the first option in every category.

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
crown, in his people's royal colours. A PvP fortress's General (Round 31)
has one fixed look of his fortress's seat race with that race's royal tabard
and no crown; his bodyguards are a mixed garrison in guard armour. Since
Round 54 kings, royal guards and Generals wear the **royal armour** (§3).

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
Fall damage follows [combat_stats.md](combat_stats.md), the same for every
race (absorb does not cover fall damage).

Humanoid **mobs keep the size their own definition sets** (the mirefolk are
deliberately short, an elite guard is deliberately large). Their scale belongs
to the mob engine, which owns it across tier promotions and world reloads.

## 3. Visible armor

Three armor lines ship — **cloth**, **leather** and **metal** — in six
material tiers per slot: head, chest, legs and feet. Since Round 54 armour is
**low-poly boxes baked into the character model** (one catalog of boxes for
every armoured character, [armor format](../technical/armor-format.md)), with
one **atlas texture**: a worn piece paints its slot's boxes on the atlas, and
the boxes it does not use stay transparent, so the model never changes with
the gear. Chest, legs and feet also paint the body under their boxes (the
**inner paint**, a skin layer: sleeves, trousers, the lower legs); the helmet
is boxes only. Each tier's colours are baked into its art (its palette);
no tier is tinted at runtime. Inventory art and worn art are separate assets
made for their respective layouts. A character therefore shows the same
armor line, slot and material tier that its equipped item names.

- **Shapes** (the user's rulings, 2026-10-20): one catalog of 17 shapes,
  28 boxes with the mirrored copies (helm, visor, chest, belt, sleeves,
  bracers, shoulder core, reinforcement, flare and spike, front and back
  panels, tassets, thighs, knee cops, boot shells, toe caps). Every box is
  available on every tier of every line; the art chooses per tier by
  design goals: metal bulkier with each tier, leather layered, cloth smooth
  and noble through ornament, and at the same tier metal more than leather
  more than cloth. Tier = the boxes worn, the paint and the palette.
- **Armor is opaque** (the user, 2026-10-20: transparent texels showed
  holes, one looked into the hollow box): every face of a worn box is
  fully painted. The only opening is the helm's **face window**, so the
  face shows under a helmet; the metal T5 and T6 helmets are closed (the
  window painted over, a visor in front).
- **The art** is original, painted by GPT-6 Astra in the armor contract's
  reference palette and picked by the user per line and tier from two
  proposals each (2026-10-20): metal T1–T5 "Bastion" and T6
  "Processional guard", leather "Trail coat" and cloth "Cantor" on every
  tier (`tools/r54_art/`, baked by `tools/r54_armor/bake.py`).
- **Tints over armor:** an elite's gold and a rare's violet
  ([combat_stats.md](combat_stats.md) §3) colour every texture of the
  character, the armor and the empty weapon card included, so they show
  over the armor; kings, royal guards and Generals carry none (below). A
  sub-type's zone tint (the ember tint of two bandit kin, the Coal-Purse
  Factor and the Ash-Writ Bowman) colours only the skin, so it shows on the
  face and the inner paint, not on the boxes (a coordinator decision, left
  as it is).
- **In the inventory** the Character tab's model is the player model with
  the character's skin, cloak, armor atlas and the main hand's weapon on
  the weapon card; it stands still in the first stand frame and turns with
  the mouse from a three-quarter view from the weapon side (camera rotation
  0,130; a first version for the user to tune). Character creation keeps
  `character.b3d` with the race look alone, since nothing is worn there.

A player's model carries seven textures: the skin, the cloak, the armour
atlas, the weapon card (empty in the world, where the hand entity shows the
weapon, §4; the inventory's view shows the main hand's weapon on it) and,
since Round 55, the offhand (a shield or spellbook), the back card (a
Scout's second weapon) and the cloak's wings
([offhand format](../technical/offhand-format.md); what they show: §4,
"The offhand and the back"); the last three stay empty while the setting
`grug_offhand_visuals` is off (on by default since 0.55.0). An armoured NPC
wears the **NPC model** — the same
body and boxes without the cloak, textures skin, armour atlas, weapon card,
offhand and back (the last two empty for now); humanoids without armour
keep `character.b3d`.

NPCs that have no inventory wear a **whole line at one tier** instead:

| NPC | Wears |
| --- | --- |
| Faction guard | metal line at the tier its own level buys — the elite city watch (60+) is the sixth, Abyssal Steel tier by construction |
| War Commander | the guard's armour in his faction's colours: cloth parts in his tabard's colour, fittings in its trim |
| Bandit | cloth line at the tier its camp's level buys |
| Vendor | no armor: its race's dress, so a shopkeeper never reads as a guard |
| Royal guard, General | the royal armour (below) with its helmet, over the royal tabard |
| King | the royal armour without a helmet, so his face and crown show, over the royal tabard |
| Mirefolk | its own fish-folk skin, no armor |

The **royal armour** (the user, 2026-10-20: "kings and royal guards need the
new model"; a first version, tuned by the user) is the guards' metal line at
the tier its wearer's level buys (the sixth for every king, royal guard and
General), with every piece's cloth parts (zone A: tabard panels, padding) in
the people's royal cloth colour and its fittings (zone B) in gold, drawn at
full strength through the same zone masks the enchant colours use (§5a).
Kings, royal guards and Generals carry no elite tint over it (the user,
2026-10-20): their size, the crown and the royal colours mark them.

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
   skills show the Weapon slot. With nothing in that slot the character holds
   nothing, and the first-person view shows the bare hand, not the skill's orb
   (Round 35);
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

**A held block is smaller** (Round 49): a node item the engine draws as a 3D
block in the hand (a cube, nodebox or mesh node without a wield image: dirt,
stone, slabs, stairs) is held at **70 %** of the hand size, centred in the
fist as before. Flat-drawn items (plantlike, torchlike and signlike nodes,
nodes with a wield image, tools, craftitems) keep the full size. The rule
mirrors the engine's own wielditem choice (`wield_geometry.lua`) and holds for
NPCs too; the first-person hand is the engine's and is unchanged.

One entity per character, never more. The **offhand is not a second hand
entity**: a shield or spellbook is part of the model (below), and only a
Scout's Melee skill puts the offhand blade into the hand (case 1 above).

**The offhand and the back** (Round 55, 0.55.0; the user's rulings and
poses of 2026-10-21, the picked art of GPT-6 Astra; numbers in
`tools/r55_offhand/params.json`, the rules in the
[offhand format](../technical/offhand-format.md)). The setting
`grug_offhand_visuals` turns the look on (the default) or off (characters
as in 0.54.1, the new item icons kept):

- a **Warrior's shield** in the offhand slot is held on the left arm:
  one heater shape with a ridge and a boss that grows with the tier in
  **three sizes**, 85 % at T1–T2, 92 % at T3–T4 and the full 10.5 × 13
  skin pixels at T5–T6, painted per tier. In the **Block** pose (standing
  and walking) it stands upright in front of the chest;
- a **Mage's or Priest's spellbook** lies open (136°) in the left hand,
  spine on the palm and pages tilted towards the head, one model for every
  tier with its tier's paint; **Cast 2** (standing and walking) lifts it;
- both show their **enchant colours** and the **broken** crack as worn
  armour does (§5a);
- a **Scout** carries its equipped weapon that the hand does not show as a
  flat **card on the back** with the item's image: the melee blade while
  the hand shows the bow (a bow skill, the bow itself), otherwise the bow.
  The card hangs on the cloak when one is worn, else on the body; a Scout
  without a bow equipped shows none. It follows the hotbar through the
  one-second poll (§5) and is never stored. Other classes carry no back
  weapon;
- a cloak with **wings** (§5b) shows them;
- the **Character tab** shows the shield or the book and the wings, and a
  Scout's bow on the weapon card with the blade on the back;
- **first person** shows neither shield nor book (the engine's own hand is
  unchanged);
- **NPCs** carry the offhand and the body card in their model, empty for
  now.

## 5. Rules that hold everywhere

- Appearance is composed by **one function** for players and NPCs. Two mods
  writing the model's texture list independently is the failure this replaces.
- Composition uses **texture modifiers only**. Nothing is generated per frame,
  no image is built at runtime, and the web build needs no exception. Every
  armor piece sits in its own parentheses, on the atlas and on the skin, so
  a piece's own modifier (a crack, its enchant or royal colours) never
  reaches the layers under it.
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

- Every weapon, offhand and armour texture, and every worn armour file (each
  atlas and skin layer, Round 54: zone A and zone B of the armour art), has
  two non-overlapping pixel groups: **group A** (a highlight or edge stripe of
  the main material) takes the **prefix** stat's colour, **group B** (a fitting:
  grip wrap, guard, strap, hem, rim) the **suffix** stat's colour. Each group is
  a thin connected stripe of about 7 % of an inventory icon; lone pixels are
  never coloured. On worn armour the groups are the art's zones A and B
  ([armor format](../technical/armor-format.md) §6).
- Each of the nine affix stats has one fixed colour (`grug_gear.ENCHANT_COLORS`):
  Strength deep red, Dexterity mint green, Intelligence indigo, maximum HP
  rose, maximum Mana sky blue, Crit yellow, attack speed orange, Dodge
  lavender, armour rating white. They stay apart for normal vision and for
  red-green colour blindness. The colour lies over the material at **50 %**.
- The colour shows on the **inventory icon**, the item **in hand** (first and
  third person) and a **dropped** item, through the stack's own
  `inventory_image`, and on the **armour worn on the body** (each piece's
  layers inside that piece's parentheses, on its boxes and its inner paint;
  a broken piece cracks with its colours). A plain item has no
  image of its own and looks exactly as before.
- **Kings** hold their weapon in fixed colours of their weapon's pool; this is
  visual only, their rewards are rolled as before. A future named NPC with gear
  uses the same visual spec field (`weapon_colors`). Ordinary guards, bandits
  and the named rares (beasts without gear) stay plain; the royal armour's
  colours (§3) are not enchant colours.
- Trinkets have no texture masks and stay uncoloured.
- Every enchanting station shows a **legend** of the nine colours.

The masks are generated, one two-frame `<texture>_ench.png` per texture, each
under its source texture's licence: the weapons' and bows' by
`tools/r31_b/gen_enchant_masks.py`, the armour's (worn layers and item icons)
by the armour bake `tools/r54_armor/bake.py` and the shields' and spellbooks'
(offhand layers and item icons, Round 55) by the offhand bake
`tools/r55_offhand/bake.py`, both from the art's zone pixels.

## 5b. Cloaks and achievements (Round 33)

Decided 2026-10-04 (round33-plan.md §2.10). A cloak is a **cosmetic badge**,
never an item: each character owns a list of cloaks and wears one of them or
none. A new character owns **No cloak** and the **Plain grey cloak** and wears
No cloak. Every other cloak is unlocked only by an **achievement**. Both lists
are kept per character, and so is the choice.

- **Achievements** count something the character did; each tier is earned
  once, never taken back (a manual one excepted, below), and unlocks its own cloak (tier N of achievement
  `<id>` unlocks cloak `<id>_N`; the three Round 36 achievements unlock a
  cloak named after itself). The set (user's picks, 2026-10-04; names,
  flavour and cloak names by GPT-6 Astra; the Round 36 three from the main
  line's story bible §6):

  | Achievement | Condition | Tiers |
  | --- | --- | --- |
  | Hunter | kill wild animals | 50 / 150 / 500 |
  | Kingslayer | kill enemy Kings (any of the three) | 1 / 5 / 20 |
  | Wyvernslayer | kill the Stormscale Jungle Wyvern | 1 / 5 / 20 |
  | Dragonslayer | kill the Wyrmglass Ice Dragon | 1 / 5 / 20 |
  | Honored | kill guards of the enemy faction (the PvP counter) | 50 / 150 / 500 |
  | Zombie Slayer | kill zombies (zombie family, husks included) | 50 / 150 / 500 |
  | Boaring Work | kill boars (regional boars included) | 10 / 50 / 200 |
  | Supper's Ready | cook dishes (counted at preparation, by output) | 50 / 150 / 500 |
  | Bottle Service | brew potions or elixirs (counted at preparation) | 50 / 150 / 500 |
  | Rat Race | kill rats | 25 / 100 |
  | Loose Bones | kill skeletons (bog witches included) | 50 / 150 / 500 |
  | Stone Deaf | kill golems | 5 / 50 |
  | Final Notice | kill one of the six level-29 leaders near the capitals | 1 |
  | Rust in Peace | kill war constructs | 5 / 50 |
  | No More Orders | kill the rare Captain Bonerattle (either one) | 1 |
  | Last Word | kill Watch-Captain Huskell or Paymaster Chirr | 1 |
  | Grounded | die from a fall | 1 |
  | Every Name Accounted For | complete The Accord's main questline (`quest:accord_main_final`); cloak Mantle of the Unburnt Roll | 1 |
  | Our Oaths Are Ours | complete The Throng's main questline (`quest:throng_main_final`); cloak The Unbought Banner | 1 |
  | The Last Claim Denied | defeat the rift boss, Isquarre the Tithe-Eater (`boss:rift`); cloak Mantle of the Broken Due | 1 |
  | Supporter | granted by an admin (manual, below); cloak Supporter Cloak, with wings | 1 |

  "Wild animals" are every animal mob, critters and hostile beasts included,
  but no humanoid, construct, spirit or slime, and not the dragons or their
  whelps (bosses and boss adds); the Kraken counts (user ruling
  2026-10-04). A sub-type counts as its base mob. A kill counts for every
  character the kill credits (the XP rule's participants). A King or a dragon
  counts for every character the boss ledger credits, whatever the loot
  lockout says; so does the rift boss (Round 36, counters `boss:rift` and
  `boss:rift:<site>`). Since Round 36 an achievement can also count quest
  turn-ins (grug_quests' turn-in hook, [quests.md](quests.md)): one quest's
  (`quest:<id>`, "completed" at 1) or every quest carrying a tag
  (`quest_tag:<tag>`, e.g. a questline). An achievement may belong to one
  faction (user, 2026-10-05): a character of the other faction never sees
  it on the tab and never earns it, and a character without a faction yet
  (in creation) sees and earns only the shared ones. Every Name Accounted
  For is The Accord's, Our Oaths Are Ours The Throng's; The Last Claim
  Denied is shared.
- **Manual achievements** (the user, 2026-10-21, Round 55): a catalogue row
  with `manual = true` is never earned by playing; an admin grants it, e.g.
  a premium cloak for players who played early and kept giving feedback.
  It has no counter of its own (internally `manual:<id>`, 1 while granted),
  one tier at 1, no faction, and its cloak is unlocked by no other tier.
  `/achievement grant <player> <id>` and `/achievement revoke <player> <id>`
  (privilege `server`) accept only manual rows and refuse every other
  ("Hunter is earned by playing, not granted"); there is no command for
  counters. A grant settles as any earning (the feed line, the cloak); a
  revoke takes the tier and the cloak back, and a character wearing that
  cloak falls back to No cloak. For a player who is offline the action is
  queued in mod storage and applied once at the next join (a later action
  on the same achievement replaces the earlier); the command says so, and
  every grant and revoke is logged. A manual achievement is **hidden until
  granted**: the tab never lists it as an open goal, nor counts it in its
  pages. One manual row ships (Round 55): **Supporter** ("Helped shape
  Grudgelands early on."), whose **Supporter Cloak** (GPT-6 Astra's, picked
  by the user 2026-10-21) is the first cloak with **wings**, a 16 × 32
  texture for the cloak's two wing pieces ([offhand
  format](../technical/offhand-format.md) §3.4, §6), shown while the
  setting `grug_offhand_visuals` is on (the default).
- The Character page has an **Achievements** mode: each achievement with its
  next cloak (dimmed until earned), its condition and its progress, a
  tooltip with the flavour line, one column of seven per page (Round 44).
  Beside the model in the Stats mode (the 3D mode until the Round 45
  playtest merged the two), a **dropdown** lists the owned cloaks.
  Earning a tier posts a line to the message feed.
- **On the model:** a cloak hangs from the shoulders to just above the knee.
  It is a thin box behind the body on its own bone, keyed per animation
  frame, the technique of VoxeLibre's capes. It stands a little off the back
  and sways standing (8.5 to 11.5 degrees), swings out with the legs while
  walking (and never through them) and lies back over the seat when
  sitting. Since Round 54 it hangs **behind the armor's back panel** and
  never swings less than it, so walking takes it out to the back panel's
  53 to 58 degrees (30 before). It costs nothing per step, every player sees
  it, and it scales with the race's stature. Players wear
  `grug_visuals_character.b3d`, which is `character.b3d` with the cloak
  appended (`tools/r33_c3/gen_cloak_model.py`, which also checks the leg
  clearance). The cloak is the model's **second texture**, so the skin
  composition is unchanged. Round 54 appends the armor boxes (the third
  texture, the armor atlas), the front and back panels on their own swing
  bones and the weapon card in the right hand (the fourth texture), and
  writes the NPC model `grug_visuals_npc.b3d`, the same without the cloak
  and the pose clips ([armor format](../technical/armor-format.md) §2).
  Round 55 appends the offhand look from `tools/r55_offhand/params.json`
  ([offhand format](../technical/offhand-format.md)): the shield three times
  (one copy per size step) and an open spellbook on the bones
  `Offhand_Shield` and `Offhand_Book` under the left arm, keyed per pose
  clip (the fifth texture, the offhand atlas), two back cards, one riding
  the cloak and one on the body (the sixth texture, an item image in the
  half of the card that shows), and two optional wings on the cloak's sides
  (the seventh, player model only); the NPC model carries the offhand and
  the body card. Every part is always in the model and shows only when its slot
  has a texture.
  Unarmored NPCs keep `character.b3d`.
- **Armor panels and weapon card (Round 54):** the front and back panels
  (skirt, tabard, robe) hang from the belt and swing away from the legs:
  front 0.06 rad plus 1.2 times the forward leg's angle, back 0.06 rad
  plus 1.1 times the backward leg's, plus a fifth of the torso's twist in a
  pose. Sitting, both hang straight down (the seated thighs pass through
  the belt line, so the front panel hides inside them). The weapon card is
  a two-sided square where the hand's wield entity holds a diagonal tool at
  stature 1; the world shows it transparent and the inventory view shows
  the held item on it.
- **Texture format:** 32×32. Columns 0–15 are the outer face seen from
  behind (the image's left is the character's left), shoulder at the top.
  Columns 16–31 are the lining seen from the front. The cloak's thin edges
  take the outer face's border pixels. No cloak is the transparent
  `blank.png`.

## 5c. Poses (Round 40)

The user's picks on the animation preview page (round40-plan.md §2.14,
`tools/r40_an/poses.json`) are clips of the player model, so they cost
nothing per step on the server and every client plays them. NPCs have
none (`character.b3d` and, since Round 54, the NPC model carry only the base
frames 0–220).

- **Clips.** Each pose exists twice: over the standing frame (its name) and
  over the walk cycle (`<pose>_walk`), so a pose taken on the move keeps the
  legs walking. They are appended after the base frames of
  `grug_visuals_character.b3d` by `tools/r33_c3/gen_cloak_model.py` and
  registered in `grug_visuals/apply.lua` (`POSE_CLIPS`, which the
  generator's `--check` holds to the model):

  | Pose | Picked | Plays on | Standing | Walking |
  | --- | --- | --- | --- | --- |
  | `cast1` | A, palm forward | Fireball, Smite, Word of Ruin; round K's Fiery Spark, Flame Lance, Meteor, Fire Rain, Rebuke, Censure, Final Word | 221–240 | 241–260 |
  | `cast2` | B, arms raised | Ice Nova, Heal, Mend, Shield; round K's Cold Spark, Ice Wave, Rime Mantle, Winter Field, Hearten, Haven | 261–280 | 281–300 |
  | `swing` | B, diagonal cut | a landed Mighty Blow or Broadstroke (round K), once | 301–314 | 315–334 |
  | `bow` | A, drawn and held | nothing since Round 53 deleted the Scout's bow draw (the clip stays in the model) | 335–354 | 355–374 |
  | `block` | B, shield arm raised | Hold Ground; Unbroken (round K) | 375–394 | 395–414 |
  | `charge` | B, shoulder first | the Charge dash (`charge.lua` starts it and stops it at the stop) | 415–434 | 435–454 |
  | `flinch` | A, light flinch | a hit taken, once | 455–464 | 465–484 |

  Held clips loop over 19 frames (the 20th repeats the first); `swing` and
  `flinch` play once. A walking one-shot runs to the end of the walk cycle.
- **When.** A pose plays only when its skill really fires: a cast when it
  succeeds, Mighty Blow when its swing lands (a refused cast, a dodged swing
  and the Strike fallback play none). Casts are instant, so `cast1` and
  `cast2` hold **0.6 s** (a second cast extends it); Hold Ground's guard
  holds **1.0 s**, not the whole 8 s buff, because the Warrior fights on
  under it and a held guard would hide every swing. Charge's pose lasts as
  long as the dash. The newest pose replaces a
  running one; a second Mighty Blow restarts `swing`. `swing` starts at
  its frame 4, the top of the swing, because the hit has already landed
  when the pose fires; the blend raises the arm.
- **The flinch** plays on a hit that does not kill, at most once per
  **1.5 s**, and only over the plain stand, walk and punch animations: never
  over another pose, a seat or death.
- **Blend and stride.** Every animation switch of a player blends over
  **0.12 s**, so the arms move into a pose instead of jumping. Switching
  between walking clips (walk, walk-and-punch, a pose's walking twin) keeps
  the walk cycle's position, so taking or dropping a pose on the move does
  not reset the legs; a one-shot switching between its standing and walking
  twin keeps its progress. Sneaking halves the speed as for every animation.
- **Cloak rule.** In a pose clip the cloak swings as in the clip it was
  baked over (the standing frame, or the walk frame whose legs the clip
  carries); where the torso leans back it hangs out by that lean too, so it
  stays plumb instead of following the back into the legs; a torso twisting
  on upright legs (bow, Charge, the diagonal cut) swings it out by a fifth of
  the twist so its lower corner clears the leg. The clearance check covers
  every pose frame: the closest leg gap of the pose clips is 0.43 model
  units, the base clips' 0.40.
- **Who sees them.** Every player sees every pose, the posing player in
  third person too (in first person the engine draws no own body). A 5.17
  client plays its own stand, walk and punch animations itself and ignores
  a server animation with one of those four frame ranges, so the end of a
  pose (its time running out, the dash or the draw ending) plays a
  `<base>_resume` animation for one step: the base animation with its end
  1/64 frame short, a range the client does not ignore that still loops
  without a hitch. Without it the player's own
  view would keep the pose until the movement changed.

## 5d. Head look (Round 40)

A player's head follows the look up and down (the user's pick H1,
round40-plan.md §2.14). The engine already turns the whole player with the
camera, so there is no head yaw and no lagging body; NPCs have no head look.

- **What it is.** One relative rotation override on the model's `Head`
  bone (`grug_visuals/head_look.lua`), on top of whatever clip plays: the
  small head moves of the pose clips (§5c) stay and the look adds to them.
  It turns the head about its own sideways axis at the neck.
- **Steps and clamp.** The look pitch is rounded to **5° steps** and
  clamped from **50° down to 60° up** (the angles accepted on the animation
  page): at 50° down the chin's lower edge still stands in front of the
  chest, at 60° up the back of the head reaches the back's plane. A new step
  blends over **0.15 s**.
- **When it is written.** Only when the step changes, so a steady look sends
  nothing. A pass looks at each player about every **0.25 s** (a round robin
  spread over the server steps, never all players in one step), so a player
  looking around is written at most about **four times a second**.
- **Charge.** While the Charge pose runs and for 0.2 s after it (the `Body`
  lead blending back, `grug_visuals.hold_head`) the head is not written: a
  write re-sends every bone override of the player and would cut the lead's
  blend short. The look catches up on the next visit after.
- **Level, never rest.** A level head is a tilt of 0.001 rad, written
  unblended when the player joins, never the plain rest pose: the client
  snaps an override it does not hold yet and drops one that returns to rest
  ([upstream-workarounds.md](../technical/upstream-workarounds.md) §3).
- **Death.** The pass levels a dead player's head, which stays level until
  respawn; the look resumes after it.
- **Who sees it.** Every player near the looking one, and the player itself
  in third person (first person draws no own body). Each write sends about
  60 bytes to each of them, plus the player's other bone overrides if any
  (the engine re-sends all of an object's overrides on any change).
- **The realm website** rotates the glb's `Head` node itself for a head that
  follows the mouse (axis and clamp: `tools/web_data/model/README.md`);
  nothing is stored for it.

## 6. Round 11 item and station presentation

Decided 2026-09-20. Silversteel reads as bright neutral silver with subtle cold
shadows across inventory icons, worn armor and the metal parts of weapons and
tools; keep the accepted weapon silhouettes. New bows use an explicit bow pose
consistent with their real sprite geometry: the hand grips the middle of the
arc/string crossing and the long arc stands upright facing forward, rather than
using the diagonal tool convention's lower-left grip.

Use individually licensed and visually inspected pinned-reference media for
seed silhouettes, hoes and the shared smith anvil. Since Round 45 the tanning
rack, tailor bench, carving bench, jeweller's bench and brewing stand are
original one-node designs the user picked from three proposals each
(`tools/r45_a2/README.md`), and each trinket identity has its own jewellery
icon per tier (`tools/r45_a1/README.md`). Cloth/leather bag variants may share a readable shape with a material
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

### Ice Nova feedback

While a target remains under Nova's actual root, emit a few small pale-blue
crystal particles around its lower body, scaled simply to the live collision
box. Stop on root expiry, immunity, death or removal; particles may fade for
less than one second. No fitted shell or persistent decorative entity is used.

## Broken equipment

Cosmetic hand attachments retain broken equipped items, drawn drained of
colour, darkened and cracked (Round 35); combat eligibility remains disabled.
The broken look of worn armor affects only the broken piece's layers (its boxes and its inner paint), not skin or intact equipment. Repair removes the overlay
and preserves the item's current enchantment appearance (its enchant colours,
§5a).
