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
constants or the texture directories; the fixture
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
| `appearance_version` | The `v` of the `grug_visuals:appearance` values this export describes (`grug_visuals.APPEARANCE_VERSION`). A stored value with another `v` is not described by this file. |

### Appearance limits and textures

| Field | Meaning |
|---|---|
| `appearance_limits.texture_max_bytes` | Maximum length in bytes of every texture string in a stored appearance (body, cloak, hand images). |
| `appearance_limits.json_max_bytes` | Maximum length in bytes of the whole stored `grug_visuals:appearance` value. |
| `texture_grammar` | The closed grammar every stored texture string parses under, `grug_visuals.APPEARANCE_TEXTURE` verbatim (the contract section explains it): `max_depth` (parenthesis nesting), `escaped` (false: nothing is escaped), `file` (`charset` and `suffix` of a file name), `dirs` (the repository directories the files come from), `engine_files` (modifier → the engine texture it draws without naming it), `args` (argument kind → its definition: `int` {`pattern`, `signed`, `min_digits`, `max_digits`, `min`, `max`}, `color` {`pattern`, `form`}, `file` {`pattern`, `max_length`}, each with a prose `description`; `pattern` is a Lua pattern of the whole argument, and the explicit limits beside it define each kind fully, so a website implements them without translating Lua patterns), `modifiers` (modifier name → its argument kinds in order). |
| `texture_files` | Every PNG a stored texture string may name or a modifier may draw, sorted by `name`. `engine: false` entries are the files of `texture_grammar.dirs`, at `path` (repository path); `engine: true` entries are textures the engine itself provides (`texture_grammar.engine_files`, no `path`; the website supplies an equivalent). |

A website parses a stored string with an allow-listed, bounded parser
against `texture_grammar` and `texture_files` and rejects anything else.

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
| `races[]` | `id` (`grug_classes:race`), `name`, `faction` (a faction `id`), `visual_size` (`{x, y, z}`, the race's visual scale of the model; collision and eye height do not change). Grouped by faction in registration order. |
| `classes[]` | `id` (`grug_classes:class`), `name`, `icon` (repository path of the class icon PNG). |

### Model

| Field | Meaning |
|---|---|
| `model.b3d` | Repository path of the player model the game uses. |
| `model.gltf` | Repository path of the same model as glTF binary ([`model/`](model/)). |
| `model.textures` | The model's texture slots in order: `body` (the appearance's `textures.body`), `cloak` (`textures.cloak`). |
| `model.fps` | Animation frames per second. |
| `model.animations.stand`, `.walk` | Frame ranges (`start`, `end`, inclusive) in model frames, looped. |

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
- `size` is the item entity's visual size. The item is drawn as an extruded
  square of its image (image right along the entity's +x, image up along +y,
  centred on the entity's origin) whose edge is 20 × `size` × `wield_scale`
  model units (the engine's extrusion factor 40, halved by the entity's
  visual size).
- The model's own `visual_size` (the race's) scales the attachment as well:
  item transform = S(race) · T(pos) · R(rot) · S(size). The per-race values
  already contain the compensation that makes the item equally large in every
  hand (`size` = 0.32 / stature).

The offhand is stored in the appearance but not drawn by the game yet; there
is no offhand attachment.

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
