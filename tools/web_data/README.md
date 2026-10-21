# Web data for realm websites

`web_data.json` in this folder is what a website needs to show a realm's
characters — faction, race, class, level and a 3D preview in the current
equipment — without running game code. It is generated from the game's own
registration files and committed; a website reads it at the realm's commit
and never runs the exporter.

The player meta keys the website reads (`grug_factions:faction`,
`grug_classes:race`, `grug_classes:class`, `grug_xp:level`,
`grug_visuals:appearance`) are an external contract owned by the game:
[module guide, "Player meta read by external tools"](../../docs/technical/module-guide.md#player-meta-read-by-external-tools).
That section owns the appearance format, the texture grammar and the
guarantees behind the two byte caps; this file describes the export. The
player model as glTF lives in [`model/`](model/).

**Support rule:** a commit supports the level and the preview exactly when
`tools/web_data/web_data.json` exists at that commit. On an older commit a
missing `grug_xp:level` row means "no level", not level 1.

## Regenerate and check

From the repository root (LuaJIT, no engine, well under a second):

```sh
luajit tools/web_data/export.lua            # rewrite web_data.json
luajit tools/web_data/export.lua --check    # exit 1 when it is stale
tools/run_fixtures.sh web_data              # the fixture: current + shape
```

Regenerate after any change to factions, races, classes, the XP curve, the
player model's frames, the wield geometry, equippable items, the appearance
constants, the texture directories, or the offhand look's setting default
or back card (a turned-on setting changes both); the fixture
(`tools/web_data/portable_test.lua`, part of `tools/run_fixtures.sh`) fails
while the committed file is stale.

How it is built: `build.lua` runs the real registration files (`player_api`,
`grug_xp`, `grug_factions`, `grug_classes`, `grug_gear`, `grug_visuals`, the
faction table and equipment slot table cut out of `grug_core` and
`grug_inventory`) against a permissive engine stub and reads the registries
they fill. Every equippable item is registered by `grug_gear`; a headless
engine probe listed the same 156 items with the same names and images
(2026-10-06). A mod that starts registering equippable items is added to
`build.lua`.

## Format

One JSON object. Keys are sorted, lists keep the game's order, so the file
changes only when the game does. Integers are exact; other numbers are
rounded to ten significant digits.

### Versions

| Field | Meaning |
|---|---|
| `schema` | Version of this file's format (1). Raised on any incompatible change to `web_data.json`. |
| `appearance_version` | The `v` of the `grug_visuals:appearance` values this export describes (`grug_visuals.APPEARANCE_VERSION`; 3 since Round 55). A stored value with `v` 2 is shown as [below](#version-2-appearances), one with `v` 1 as [further below](#version-1-appearances); any other `v` is not described by this file. |

### Appearance limits and textures

| Field | Meaning |
|---|---|
| `appearance_limits.texture_max_bytes` | Maximum length in bytes of every texture string in a stored appearance (body, cloak, armor, offhand, wings, hand images). |
| `appearance_limits.json_max_bytes` | Maximum length in bytes of the whole stored `grug_visuals:appearance` value. |
| `texture_grammar` | The closed grammar every stored texture string parses under, `grug_visuals.APPEARANCE_TEXTURE` verbatim (the contract section explains it): `max_depth` (parenthesis nesting; 3 since version 2), `escaped` (false: nothing is escaped), `file` (`charset` and `suffix` of a file name), `dirs` (the repository directories the files come from), `engine_files` (modifier → the engine texture it draws without naming it), `args` (argument kind → its definition: `int` {`pattern`, `signed`, `min_digits`, `max_digits`, `min`, `max`}, `color` {`pattern`, `form`}, `file` {`pattern`, `max_length`}, each with a prose `description`; `pattern` is a Lua pattern of the whole argument, and the explicit limits beside it define each kind fully, so a website implements them without translating Lua patterns), `modifiers` (modifier name → its argument kinds in order). |
| `texture_files` | Every PNG a stored texture string may name or a modifier may draw, sorted by `name`. `engine: false` entries are the files of `texture_grammar.dirs`, at `path` (repository path); `engine: true` entries are textures the engine itself provides (`texture_grammar.engine_files`, no `path`; the website supplies an equivalent). |

A website parses a stored string with an allow-listed, bounded parser
against `texture_grammar` and `texture_files` and rejects anything else.

### Version 2 appearances

Round 55 (0.55.0) raised the appearance to version 3, which adds
`textures.offhand` and `textures.wings` ([below](#the-offhand-look)) and
changes nothing else: the grammar, the per-string cap and every other field
are the same, and the JSON cap grew to make room (12,288 bytes in version
2). A character who has not joined since keeps the version 2 value 0.54.x
wrote, until the next join rebuilds it. **Read a version 2 value as a
version 3 value whose `textures.offhand` and `textures.wings` are `none`**
(a missing key already means an empty slot, so a reader that treats both
keys that way needs no version check). Everything else is read and
validated as in version 3, under the current limits and grammar; the back
card does not depend on the version. Every string a version 2 value holds
still validates: the one image Round 55 stopped using, the spellbook's shared
`grug_gear_spellbook.png` (a version 2 spellbook's hand image is
`grug_gear_spellbook.png^[colorize:#rrggbb:48`, with its masks when
enchanted), stays in the game and in `texture_files`.

`tools/r55_web` checks the rule against the value 0.54.1 wrote for the
Round 54 test character: read this way, it is exactly the version 3 value
the current game writes for that character.

### Version 1 appearances

Round 54 (0.54.0) raised the appearance to version 2: armor is a set of
boxes in the model with its own texture (`textures.armor`), and the body is
the skin under it. A character who has not joined since keeps the version 1
value the old game wrote, until the next join rebuilds it. Its
`textures.body` carries the old armor overlays (`grug_visuals_<line>_<slot>_<grade>.png`
and their masks), whose files are gone, under an older, wider grammar
(4 levels of parentheses, a `[mask:file` modifier for the helmet). Such a
character is shown **without armor** until the next join:

| Field | Meaning |
|---|---|
| `appearance_v1.version` | 1 |
| `appearance_v1.texture_max_bytes`, `.json_max_bytes` | The byte caps of version 1 (2,048 and 10,240). |
| `appearance_v1.max_depth` | Parenthesis nesting of version 1 (4). |
| `appearance_v1.armor_files` | Every file a version 1 body named for a worn piece: the overlays of every line, slot and grade, their `_ench.png` masks and `grug_visuals_helmet_window.png`. Sorted. |

1. **Body.** Reject a body longer than `texture_max_bytes`. Split it at
   every `^` outside parentheses (count `(` and `)`; reject a body that
   nests deeper than `max_depth` or does not balance). Drop every part that
   names a file of `armor_files` (a part names the `[a-z0-9_]+\.png` tokens
   in it), join the rest with `^`, and validate the result like any
   version 2 string (`texture_grammar`, `texture_files`). What remains is the
   race look the game composes for the stored `race` and `look`, except that
   a character who wore a helmet shows no hair (the old body dropped it
   under the helmet). A rejected body, and a result that does not
   validate, draws the race's `bare_body` instead (the stored `race`; an
   unknown race draws `human`'s).
2. **Armor.** There is no `textures.armor`: hide the armor primitive.
3. **The rest** keeps its meaning: `race`, `look`, `cloak`, `visual_size`,
   `textures.cloak` and `slots` (hand images included) are read as in
   version 2, each texture string validated under the current grammar
   (a hand image that fails falls back to `hand_items.<item>.wield_image`).
   As in version 2, there is no offhand and no wings.

`tools/r54_web` holds bodies and whole values the old game composed
(`v1_samples.lua`) and a fixture that checks this rule against them.

### Levels

| Field | Meaning |
|---|---|
| `levels.max_level` | The level cap. |
| `levels.start_xp` | Cumulative XP at which each level starts: index 0 is level 1 (0 XP), index `max_level - 1` the cap. |

`grug_xp:level` holds the level itself; this table is for progress displays.

### Factions, races, classes

| Field | Meaning |
|---|---|
| `factions[]` | `id` (the value of `grug_factions:faction`), `name` (display form, "The Accord"), `color` (`#rrggbb`). |
| `races[]` | `id` (`grug_classes:race`), `name`, `faction` (a faction `id`), `visual_size` (`{x, y, z}`, the race's visual scale of the model; collision and eye height do not change), `bare_body` (the race's skin with option 1 in every look category and nothing worn, as the game composes it: what a website draws when a stored body cannot be used). Grouped by faction in registration order. |
| `classes[]` | `id` (`grug_classes:class`), `name`, `icon` (repository path of the class icon PNG). |

### Model

| Field | Meaning |
|---|---|
| `model.b3d` | Repository path of the player model the game uses. |
| `model.gltf` | Repository path of the same model as glTF binary ([`model/`](model/)). |
| `model.textures` | The model's texture slots in order, one per glTF primitive: `body` (the appearance's `textures.body`, the skin under the armor), `cloak` (`textures.cloak`), `armor` (`textures.armor`, the armor atlas), `weapon` (the weapon card: not stored; a website hides it and draws the weapon by `wield`, [model README](model/README.md)), `offhand` (`textures.offhand`, a shield's or spellbook's offhand atlas layer), `back` (the Scout's back card: not stored, the website derives it) and `wings` (`textures.wings`, a cloak's wings); the last three only as [the offhand look](#the-offhand-look) says. `none`, and a key a stored value does not have, means an empty slot (hide that primitive, or draw it fully transparent). |
| `model.fps` | Animation frames per second. |
| `model.animations.stand`, `.walk` | Frame ranges (`start`, `end`, inclusive) in model frames, looped. In the glTF clip of the same name, frame `f` is at `(f − start) / fps` seconds. |

### Hand attachment

The game draws the mainhand item as a separate entity attached to the
model's bone `wield.bone` (`Arm_Right`). Its placement depends on the item's
pose (the appearance slot's `pose`) and the wielder's race:

| Field | Meaning |
|---|---|
| `wield.bone` | The bone the item hangs off. |
| `wield.poses` | Every pose id. |
| `wield.races.<race>.<pose>` | `pos` (`{x, y, z}`), `rot` (`{x, y, z}`) and `size` (`{x, y}`) of the attachment for that race and pose. |

Frames and units, as the engine applies them (derivation:
`mods/PLAYER/grug_visuals/wield_geometry.lua`, sections 1–9):

- `pos` is in the bone's local frame, in model units (10 units = 1 node, the
  units of the `.b3d`).
- `rot` is Euler degrees about the bone's axes, applied as
  Rz(z) · Ry(y) · Rx(x).
- `size` is the item entity's visual size. Only `x` and `y` are exported;
  the engine sets the missing `z` to `x`
  (`src/script/common/c_content.cpp`, `visual_size`), which scales the
  item's extrusion thickness the same way. The item is drawn as an extruded
  square of its image (image right along the entity's +x, image up along +y,
  centred on the entity's origin) whose edge is 20 × `size` × `wield_scale`
  model units (the engine's extrusion factor 40, halved by the entity's
  visual size).
- In the glTF model ([`model/`](model/README.md)) z is mirrored: an engine
  position `(x, y, z)`, `pos` included, is `(x, y, −z)` there, and the
  rotation matrix R built from `rot` becomes S·R·S with S = diag(1, 1, −1);
  units (10 = 1 node) and bone names are the same.
- The model's own `visual_size` (the race's) scales the attachment as well:
  item transform = S(race) · B(bone, frame) · T(pos) · R(rot) · S(size),
  with B the `Arm_Right` bone's animated transform at the current frame. The
  per-race values already contain the compensation that makes the item equally large in every
  hand (`size` = 0.32 / stature).

The offhand item has no attachment: the game draws a shield or spellbook
as part of the model, while the offhand look is on
([below](#the-offhand-look)).

### The offhand look

Round 55 built three parts into the model
([offhand format](../../docs/technical/offhand-format.md)):

- a shield or an open spellbook in the left hand;
- the Scout's second weapon on a flat card on the back;
- wings on a cloak.

The game draws them while the setting `grug_offhand_visuals` is on, its
default since 0.55.0. A server that turns it off draws every character as
in 0.54.x, apart from the new shield and spellbook item icons.

| Field | Meaning |
|---|---|
| `offhand_look.setting` | The setting's name, `grug_offhand_visuals`. |
| `offhand_look.enabled` | The setting's default at this commit (`true` since 0.55.0). While it is false, a website draws **no** offhand, back card or wings: hide the three primitives. The stored `textures.offhand` and `textures.wings` are `none` then anyway; the back card, which no value stores, is what needs this field. A realm whose operator sets the setting otherwise departs from this default, which the export cannot see. |
| `offhand_look.layers.shield`, `.book` | The baked offhand atlas layer of each bracket, index 0 = bracket 1 to index 5 = bracket 6 (the item `grug_gear:shield_<grade>` or `grug_gear:spellbook_<grade>` of that bracket's metal grade), the files a stored `textures.offhand` names. Each has its enchant mask `<stem>_ench.png` beside it. The files ship since 0.55.0 and `texture_files` lists them with their paths like any other file; no stored value names them while the setting is off. |
| `offhand_look.back_card` | The Scout's back card: `class` (the `grug_classes:class` that carries one), `width` × `height` (the back texture, 32 × 16), `cloak_x` and `body_x` (the column where the 16 × 16 image goes: the left half is the card on the cloak, the right half the card on the body), `rotate` (degrees counter-clockwise the image is turned before it goes in: 180 since 0.55.0, so the grip points up over the right shoulder). |

While `enabled` is true:

- **`textures.offhand`** (`none` = empty) is drawn on the `offhand`
  primitive. It is an atlas string of the same kind as `textures.armor`:
  64 × 64, the same grammar, the layer in its own parentheses with the same
  enchant colours and broken wrapper. The model carries the shield three
  times, once per size step, and the layer paints only the copy of its
  tier's size; the rest of the atlas is transparent.
- **`textures.wings`** (`none` = empty) is a cloak's wing file (16 × 32),
  drawn on the `wings` primitive. The Supporter Cloak is the first cloak
  with wings (`grug_achievements_cloak_supporter_wings.png`).
- **The back card** is never stored; derive it. Only a character whose
  `grug_classes:class` is `back_card.class` has one. The card shows the
  Scout's equipped weapon that the hand does **not** show. A Scout's bow
  is `slots.mainhand` and the melee blade `slots.offhand`.
  - A website that draws `slots.mainhand` in the hand (the hand attachment,
    `wield`) shows `slots.offhand` on the card. This is the game's
    Character tab. There is no card unless both slots are stored.
  - A website that draws no hand item shows `slots.mainhand` on the card,
    and no card without it.

  The texture is a transparent `width` × `height` image. Draw the slot's
  `image` (16 × 16; validated like any hand image, falling back to
  `hand_items.<item>.wield_image`) at column `cloak_x` when the stored
  `textures.cloak` is not `none` (the game decides by the cloak's texture,
  not its id), else at `body_x`, row 0. The other half stays
  transparent, so only the card on the cloak or only the one on the body
  shows. Turn the image by `rotate` degrees first (180: the grip up). Put it
  on the `back` primitive. The game builds the same texture
  as `[combine:32x16:<x>,0=<image>^[transformR180` (the image escaped); `[combine` is outside the grammar,
  so a website composes it itself. In the world the game's card follows
  what the player holds at that moment (a bow skill puts the blade on the
  back, anything else the bow); a website shows one fixed view.

### Items

| Field | Meaning |
|---|---|
| `hand_items.<item>` | Every item that can sit in one of the two hand slots (the appearance's `mainhand` and `offhand`, whatever the class calls them): `wield_image` (texture string the hand entity draws for a plain stack: the item's world wield image, else its wield image, else its inventory image) and `wield_scale` (`{x, y, z}`, multiplies the extruded square). |
| `equippable_items.<item>` | Every item that fits an equipment slot (armour, hand items, trinkets): `name` (English display name, the first line of the description) and `inventory_image` (texture string). |

A stored hand slot carries its own `image` (with enchant colours and the
broken look); prefer it over `hand_items.<item>.wield_image`. Inventory
images are item definitions, not stored strings: they may use modifiers
outside `texture_grammar` (for example `^[colorize`) and PNGs outside
`texture_files`.
