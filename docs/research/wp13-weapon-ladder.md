# WP13 increment: one weapon ladder

Lane: playtest round 2, lane 1. Design records:
[items_crafting.md](../design/items_crafting.md) §3.0.3 (binding),
[character_visuals.md](../design/character_visuals.md) §2/§4,
[inventory_equipment.md](../design/inventory_equipment.md) §2.
Evidence: `tools/wp13/evidence/20260915-weapon-ladder/`.

Base: `main` at `9e22b0d`.

> **Status, 2026-09-16 — superseded in one place.** This is the record of
> playtest round 2 and stays as written. Playtest round 5 turned the **two**
> poses this note describes into **three** and changed the shape of the call
> that selects them, so the paragraph beginning *"There are two poses"* below
> no longer describes the shipped code:
>
> * there is a third pose, `POSE.edge_down` — the tool transform rolled half a
>   turn about the blade, for the axe family, so the cutting edge leads the
>   swing;
> * `wield_transform(stature, true)` **no longer means upright**. The second
>   argument is now one of `grug_visuals.POSE` (`"tool"` / `"edge_down"` /
>   `"upright"`, `nil` = tool) and an unrecognised value raises;
> * the group list gained `fishing_rod`, and `axe` is matched **first**, into
>   the rolled pose.
>
> Current record: [wp13-fishing.md](wp13-fishing.md) §1; current numbers:
> `mods/PLAYER/grug_visuals/wield_geometry.lua` section 10.

## Why

Three findings from the user's GUI playtest on 2026-09-15.

1. **Two sword families existed.** `default` registered wood/stone/bronze/steel
   swords with minetest_game's diagonal sprites; `grug_gear` registered four
   weapon families × six *adjective* brackets (Crude … Grand) with vertical
   sprites of its own. §3.0.3 had already decided against that in 2026-08-07 —
   one catalogue, material-named — and the merge had never been implemented.
2. **The weapon looked different on a player than on a guard**: smaller, hilt
   further up the arm, blade tipped down.
3. **The hand did not always show the right thing**, and once showed nothing.

## What shipped

### 1. One catalogue, material-named

`grug_gear` now generates its 72 items off `grug_gear.MATERIALS`, six rows of
three ladders. The generator, the bracket table, the ilvl anchors, the damage
curve, the armor curve and every price are **unchanged** — this was a rename and
a merge, not a rebalance.

| Line | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---|---|---|---|---|---|
| Metal — weapons and metal armor | Bronze | Iron | Steel | Silversteel | Embersteel | Abyssal Steel |
| Cloth — the §3.5 bolt grades | Patch | Woven | Heavy | Silkweave | Silk | Stormweave |
| Leather — the §3.4 grades, named only | Light | Cured | Heavy | Scaled | Sleek | Nightscale |

Nouns are unchanged (Sword / Dagger / Greataxe / Staff; Helm / Chestplate /
Greaves / Sabatons; Cowl / Robe / Leggings / Slippers; Hood / Jerkin / Pants /
Boots), so the catalogue reads *Bronze Sword*, *Silkweave Cowl*, *Abyssal Steel
Greataxe*. Itemstrings follow (`grug_gear:sword_bronze`,
`grug_gear:head_cloth_silkweave`); `grug_gear.weapon_item(family, bracket)` and
`grug_gear.armor_item(slot, line, bracket)` are the single place a name is
built, and `grug_visuals`' `weapon_family` shorthand goes through the first.

**Leather is named but still not registered** — its only wearer, the Rogue, is
Phase 2. Naming it now is what stops the next lane inventing a second ladder.

**Retired**: `default:sword_bronze` and `default:sword_steel`, through
`grug_materials/content_curation.lua`'s existing removal list, next to the mese
and diamond tiers. `default:sword_wood` and `default:sword_stone` stay as
below-ladder starters with no level requirement, so
`grug_gear/init.lua`'s `VENDORED_WEAPONS` list is six entries, not eight.

### 2. The tool ladder, completed

The question the brief asked — how `default`'s bronze and steel tools map onto
the ladder — was **already answered in shipped code**:
`grug_materials/overrides.lua` gives `default:pick_bronze`
`grug_pick_tier = 1` and `default:pick_steel` `grug_pick_tier = 3`, i.e. exactly
§3.0.1's T1 Bronze and T3 Steel. Nothing about those two changes.

What was missing was T2, T4, T5 and T6. `grug_materials/tools.lua` registers
twelve tools — pick, axe and shovel in Iron, Silversteel, Embersteel and Abyssal
Steel. Decisions, and why:

- **Iron gets tools.** `grug_materials:iron_bar` is a real registered item (it
  is what upstream's "steel ingot" migrated to, because §3.0.1 reads smelted
  iron as Iron), Iron owns a depth band (−101…−300), a `PICK_PROFILES` entry and
  a tier row. Skipping it would leave §3.0.4's T2 row without a pick.
- **Namespace `grug_materials:`, while Bronze and Steel stay `default:`.**
  Registering into a foreign namespace needs the `:` escape, and
  re-registering the two live rungs here would either duplicate them or force
  this lane to re-author their WP25-calibrated capabilities. Consumers read
  `grug_pick_tier`, not the namespace. WP29 owns the final unified catalog.
- **No craft recipes.** `default:pick_steel` is already a non-craftable
  verification tool and none of the four bars has a furnace recipe (WP26 owns
  those). Giving the deep picks a recipe would move the progression gate, which
  is not this lane's business. The picks take their capabilities straight from
  the published `PICK_PROFILES`; the axe and shovel rows continue `default`'s
  own bronze → steel steps and are provisional in the same sense (WP22
  calibrates).
- The new hatchets carry `grug_equip_weapon` and `_grug_hands = 1`, the same
  ruling `grug_gear` already applies to `default`'s four axes.

**One caster starter is new**: `grug_gear:staff_wood` — Wooden Staff, two-handed,
5 damage at 1.4 s, no ilvl, sold at 15 c like the stone sword. `default` ships
no staff, and without it a Priest or Mage had no starter weapon of their family.

### 3. One sprite convention, and the art

Every weapon and tool in the game is now drawn the same way: **16×16, long axis
on the image's anti-diagonal, grip bottom-left, business end top-right** —
minetest_game's own tool convention, which `default`'s picks, axes, shovels and
swords already used and which the user asked for. (Everything else a character
can hold — a torch, an apple, a bag — keeps its own upright icon and is held in
the second pose, §5.)

`tools/wp13/gen_weapon_ladder.py` generates all 37 new sprites deterministically:

- **sword** is `default_tool_steelsword.png` with its six grey steps mapped
  through a per-material lookup and its wooden handle copied unchanged;
- **dagger, greataxe and staff** are authored in the generator as ASCII maps in
  the same convention and the same palette;
- **pick, axe and shovel** for the four new metals are the matching steel
  sprites through the same lookup;
- the **starter staff** is the staff map through a wood ramp.

The recolouring is not an invention: **minetest_game's own bronze sword IS its
steel sword with exactly such a table applied**, verified pixel by pixel, and
the generator's self-check reproduces `default_tool_bronzesword.png` byte for
byte and fails if it ever stops doing so. That makes the whole output a
derivative of CC BY-SA 3.0 art, which is how both `LICENSE-media.md` tables
record it. (The armor icons stay this project's own CC0 art; the four retired
weapon maps are deleted from `tools/gen_mob_item_textures.py`.)

Review sheet, all seven families × six materials plus the below-ladder column:
**`tools/wp13/evidence/20260915-weapon-ladder/weapon-ladder-sheet.png`**.

One more consequence of "one convention": `default`'s four shovels declared
`wield_image = "…^[transformR90"`, and the engine prefers that image for the
extruded in-hand mesh. The shovels are *in* the tool ladder, so they are held by
the grip pixel the diagonal convention fixes — and the rotated image moves that
pixel out from under the fist and lays the shovel across the hand at 90° to
every sword, axe and pick. `overrides.lua` clears the key so the engine falls
back to the inventory image. (Plenty of other vendored items declare a
`wield_image` — the torch, the saplings, the doors, the xpanes, the grasses —
and none of them matters, because none is a diagonal tool sprite and they are
held in the upright pose below, which assumes nothing about the image.)

### 4. The hand transform, re-derived

`mods/PLAYER/grug_visuals/wield_geometry.lua` carries the whole derivation; the
short version, for the two things that changed.

**The rotation.** The sprite's long axis is now the image diagonal, i.e. the
entity-local direction (1, 1, 0)/√2 rather than +y. Asking for blade = forward
tilted `t` above level and the flat's normal = sideways gives the unique Euler
triple

```
x = 90,  y = -(45 + t),  z = 90
```

— the 45 is the sprite's own built-in diagonal, and the previous vertical
sprites were the same formula with it absent. With the ruling's `t = 0` the
blade points straight forward, at a right angle to the hanging arm.

**The position** is then forced, not tuned. The fist is at bone-local
y = 4.2 (measured off `character.b3d`); the grip is image pixel **(3.4, 12.6)**,
the centroid of the eleven wooden handle pixels of the real steel-sword sprite,
and the generator asserts every sprite it writes has an opaque pixel there.
Because (3.4, 12.6) lies on the image's anti-diagonal — i.e. on the weapon's own
long axis — the offset collapses to a pure shift along the blade:

```
pos = {x = 0, y = 4.200, z = 2.602}   rot = {x = 90, y = -45, z = 90}
size = {x = 0.32, y = 0.32}
```

**The stature, and why the race scales are now uniform.** `set_attach` parents
the entity's matrix node to the parent's joint node (content_cao.cpp:1462-1470)
and the parent's `visual_size` sits on the animated mesh node above it (:705), so
the absolute transform is `S_parent · T(pos) · R(rot) · S_child`. The position
half is harmless: `S_parent` is linear, so `S_parent(HAND − R·GRIP)` still lands
on the scaled fist. The geometry half is not. With a non-uniform `S_parent` the
sprite is stretched along one model axis and squashed along another, and because
this sprite's weapon runs along a *diagonal* of its own quad, that stretch both
lengthens and **tilts** the blade — the reported defect, and exactly why the
1:1-scaled guards looked right.

It cannot be cancelled by the child's `visual_size`: cancelling needs
`S_child = SIZE · R⁻¹ · S_parent⁻¹ · R` to be diagonal, which with this `R`
holds only when the parent's vertical scale equals its horizontal one. The
former race statures were all of the form (k, m, k) with k ≠ m, so none of them
qualified. **So the anisotropy went**: stature is one scalar per race
(human 1.00, dwarf 0.90, elf 1.06, undead 0.94, orc 1.08, troll 1.12), the
compensation is the exact `size = SIZE / k`, and the "broader and lower" reading
moves to the skin art, which the engine cannot shear.
`grug_visuals.wield_transform(stature)` returns the whole attachment for a given
wielder; players pass their race scale, **mobs pass nil** — a mob's scale is its
real size and an elite guard's sword should grow with him.

Measured, by `tools/wp13/wield_transform_kat.lua`, relative to the fist:

```
hanging          hilt 0,0,-1.923   grip 0,0,0   tip 0,0,7.128   blade 0,0,1   flat -1,0,0
raised 90        hilt 0,-1.923,0   grip 0,0,0   tip 0,7.128,0   blade 0,1,0   flat -1,0,0
stature 0.90     identical to `hanging` to three decimals
stature 1.12     identical to `hanging` to three decimals
upright          hilt 0,-3.200,0   grip 0,0,0   tip 0,3.200,0   up   0,1,0   flat -1,0,0
upright 0.90     identical to `upright` to three decimals
```

One inert sign was fixed under review while this was being re-derived:
`e2_z` was `-blade_y` where E2 = N × B gives `+blade_y`. It cancels at
`TILT_UP = 0` and with the grip on the anti-diagonal — i.e. for everything this
lane ships — and would have been wrong at any other tilt or grip point.

Palettes were retuned after the review looked at the sheet: **Iron** is now a
distinctly darker, duller grey than Steel (the two were near-identical at 16 px)
and **Embersteel** is a near-black red body with a bright ember core rather than
an even warm orange, which sat on top of Bronze's ramp. Bronze is untouched, so
the byte-for-byte upstream check still anchors the machinery.

### 5. The display rule

`grug_visuals` decides what a player is shown holding from the **hotbar**, not
from the weapon slot: a skill item in hand shows the equipped weapon (the skill
already wears its art and takes its damage from the slot), any other registered
item shows itself, an empty hand shows nothing.

Triggers are the existing equipment-change callback plus **one throttled poll,
once a second across all connected players** — the hotbar index is client state
with no server-side change hook. The poll costs one `get_wielded_item`, one
group lookup and one string compare per player; every expensive write is behind
`sync_wield`'s unchanged-item compare. It is also the **retry** for an
attachment the engine refused (no loaded block, an entity budget): a failed
spawn leaves the entry empty instead of recording a state, so the next pass
tries again. That is the most likely explanation for the one-off "the sword was
not shown at all" the playtest could not reproduce.

**There are two poses, because there are two kinds of held art** (added in the
review round). The transform above is derived from the diagonal tool
convention — the weapon on the image's anti-diagonal, the grip at pixel
(3.4, 12.6) — and is right only for art drawn that way. The rest of the starter
kit is not: a torch and an apple are node items rendered as their own upright
icon, with no diagonal and no grip pixel, and through the tool transform they
float about a quarter of a node in front of the fist, rolled 45° about an axis
their art does not have. `wield_transform(stature, true)` is the second pose —
`pos = HAND` (the centre is the anchor, because an anonymous icon has no better
point) and `rot = {90, -90, 90}`, i.e. the same x and z with the sprite's own
built-in angle taken out, so the icon stands up with its face vertical like a
blade's.

Which pose an item gets is read off a **group**, not off the item type:
`sword`, `axe`, `pickaxe`, `shovel`, `staff` or `grug_equip_weapon`. Those are
exactly the families the diagonal convention covers, every `default` tool and
every grug weapon carries one, and every tool that is *not* drawn that way —
`mobs:lasso`, `mobs:net`, the ability orbs — carries none and gets the upright
pose with no exception list. A future weapon family joins by declaring its
group, the same way it joins the weapon slot.

A changed stature **or a changed pose** re-attaches rather than re-textures
(position, rotation and size all move together); a sword-for-torch swap is
therefore one `remove` plus one `add_entity`, not a texture write. The
book-keeping is written as an explicit branch rather than `obj and value or nil`
— `upright` is a real boolean and that idiom turns a legitimate `false` into
nil, which the compare would read as a changed pose and re-attach on every poll
for every tool in the game.

### 6. The starter weapon

Moved off the faction kit and onto the class, because a character picks its
faction **before** its class and the kit therefore could not know whether it was
arming a Warrior or a Mage. `grug_inventory/equipment.lua` now grants, once per
character, at the moment the class is chosen:

| Class | Weapon |
|---|---|
| Warrior | `default:sword_stone` |
| Priest | `grug_gear:staff_wood` |
| Mage | `grug_gear:staff_wood` |

It goes **into the `grug_weapon` list**, not into the bag — with the no-fallback
rule a weapon in `main` drives no damage, no ability skin and nothing in the
character's hand — and the write goes through `grug_inventory.equipment_changed`,
the same notification a manual equip fires, so the ability skins and the visible
weapon follow. It obeys the two-handed rule rather than bypassing it and falls
back to `main` (with a chat line) if the slot cannot take it; the meta flag is
spent only when something was actually received. The faction kit keeps the
torches and apples, and the **torch stays in `main`** — in the offhand it would
silently cost every caster their two-handed staff.

`grug_inventory.STARTER_WEAPON` is published, and a startup audit
(`register_on_mods_loaded`, the grug_traders pattern) prints one action line and
errors loudly if a registered class has no starter weapon, names an item that is
not registered, or names one the weapon slot would refuse.

The B6 join hint is untouched and still re-arms rather than firing blind; a
fresh character no longer reaches it, because its slot is full.

### 7. What the review caught

The first pass deleted `grug_gear_item_sword.png` (weapons went from one sprite
per family to one per family and material) and missed that
`grug_inventory/pages.lua` names it for the **empty weapon slot's ghost icon**.
That is the worst-behaved class of defect in this engine: the client reports
`generateImagePart` and draws nothing, and the server log says nothing at all.
The row now names the Steel sword — grey, so it dims cleanly under the ghost's
`^[multiply:#666666`.

The real fix is the gate. `static.sh` now scans **every `.png` literal under
`mods/*/grug_*`** against the real media pool (every `textures/` and `models/`
directory in the tree, because Luanti's media pool is flat), pulling file names
out of quoted spans so a literal carrying texture modifiers is checked too.
271 literals; three string-concatenation fragments and doc examples
(`_side.png`, `a.png`, `b.png`) are whitelisted by name rather than by pattern,
so a real miss cannot hide behind one. Negative control taken by hand: putting
the old name back makes the gate print
`MISSING grug_gear_item_sword.png at mods/PLAYER/grug_inventory/pages.lua:89`.

## Verification

| Gate | Result |
| --- | --- |
| `tools/wp13/gear_catalogue_kat.lua` (new) | `wp13_gear_result PASS 0` |
| `tools/wp13/wield_transform_kat.lua` | `wp13_wield_result PASS 0` |
| `tools/wp13/character_visuals_kat.lua` | `wp13_cv_result PASS 0` (composition digest `0760993141`, byte-identical to the 2026-09-14 evidence — the armor art and tints did not move) |
| `tools/wp13/visuals_order_kat.lua` | `wp13_order_result PASS 0` |
| `tools/wp13/ability_rightclick_kat.lua` | `wp13_rmb_result PASS 0` |
| all five, LuaJIT vs `tools/bin/lua51` | byte-identical, `sha256 310c88e1…6f9f5115` |
| `tools/wp13/final_micro.lua` pair | `PASS`, both `output_sha256=4f2d2b76…41cbdf5` |
| `tools/wp43/materials_test.lua` under both interpreters | passed |
| `luac51 -p` + `SETGLOBAL` per changed file and tree-wide | pass; one `SETGLOBAL` per mod table, none in the new non-init files |
| the five plain-5.1 sweeps, scoped and tree-wide | zero hits outside prose (sweep 1's two hits are `core::Transform::buildMatrix` C++ references in comments; the `os.exit` hits under `tools/` are pre-existing and appear in the 2026-09-14 evidence too) |
| `python3 tools/check_fresh_server.py` | `PASS` |
| every media file has a `LICENSE-media.md` row; the ladder regenerates byte-identically; the mob/trader icons are unmoved | pass |
| every `.png` literal under `mods/*/grug_*` resolves to a real file | 271 checked, 3 fragments whitelisted, none missing |
| one headless boot, `tools/luanti_headless.sh 180` with the probe (port 31023) | `PASS`, 0 ERROR/ModError, 59 WARNING |

The 59 warnings are 57 pre-existing ones (mod-storage backend advice and the
vendored `stairs` metal-block fuel rows) plus **two new ones of exactly the same
pre-existing class**: `No craft recipe matches input (type: fuel, items:
['default:sword_bronze'/'_steel'])`, emitted by the curation list's
`clear_craft` for the two newly retired swords, next to the eight identical
lines the mese and diamond tiers already produce.

The boot staged `tools/wp13/weapon_probe/` (disposable, never shipped) and the
log carries the ladder as the engine actually holds it — all 24 weapons with
their sprite names, the starter staff, all 18 pick/axe/shovel rungs with the
pick tier each claims, the retired swords gone and the starters kept, the per
class starter weapons, and the compensated wield size for three races. Its
`PROBE PASS` line means no registered item names a texture that is not on disk
and no held item declares a second wield image.

## Taste values, and where to change them

Both live in `mods/PLAYER/grug_visuals/wield_geometry.lua` and nowhere else.

- **`SIZE = 0.32`** — how big the weapon is, as a fraction of a node. It is a
  *length* as much as a size: the position is computed from it, so raising it
  moves the pommel correctly instead of pushing the sprite out of the hand.
- **`TILT_UP = 0`** — degrees the blade rides above level. 0 is the ruling
  ("straight forward, 90° to the arm"); 15 was round 1's value. It feeds
  `rot.y = -(45 + TILT_UP)` and the position together, so changing the one
  constant keeps the grip in the fist.

`GRIP_U, GRIP_V = 3.4, 12.6` is measurement, not taste: it moves only if the
sprite convention moves, and the generator asserts every sprite honours it.

## Open points

- **Nobody in this lane can open a client.** Everything above is geometry,
  fixtures and one headless boot. The user's look is the gate.
- **The staff head reads as a knob rather than a faceted gem** at 16 px. The
  greataxe and dagger read; the staff is the weakest of the three authored
  shapes and is an ASCII-map edit in `tools/wp13/gen_weapon_ladder.py`.
- **The four new tool tiers are unobtainable** outside creative until WP26 ships
  the bar recipes and WP29 the tool catalog. That is deliberate (above), but it
  means the six-pick × six-strata matrix §3.0.4 asks for still cannot be walked
  in-game.
- **Leather armor is named, not registered.** One `register = true` away.
- **`grug_visuals.LINE_ART` still maps leather onto the cloth overlay** —
  unchanged by this lane, listed because the leather names now exist.
- **The tool ladder spans two namespaces** (`default:` T1/T3,
  `grug_materials:` T2/T4/T5/T6). WP29 unifies it; until then
  `grug_pick_tier` is the thing to read.
- **A tool drawn outside the diagonal convention would be held wrong.** The
  pose is chosen by group, so `mobs:lasso`, `mobs:net` and `mobs:shears` fall
  into the upright pose, which is right for the first two and arguable for the
  shears. Nothing in the tool ladder is affected; a future weapon family must
  either use the convention or stay out of the five groups.
- **`_grug_bracket` is still a number.** The armor overlay tint and
  `grug_visuals.index_armor` key off it, which is correct — the tier index is
  not the tier's name — but it means "bracket" survives as a word in the code
  while the player-facing vocabulary is material names.
