# UI and looks

Part of the [module implementation guide](../module-guide.md), which indexes every
area. Windows and formspecs, key presses, text in the world, item displays, the player model, looks, cloaks and sound. Implementation seams and engine pitfalls only; the
[design docs](../../design/README.md) own the game rules. Source paths in code
spans are repository-relative.

Sections: [UI and formspecs](#ui-and-formspecs), [Key presses](#key-presses), [Text in the world](#text-in-the-world), [Item displays](#item-displays), [Player model and skins](#player-model-and-skins), [Looks and enchant colours](#looks-and-enchant-colours), [Cloaks and achievements](#cloaks-and-achievements), [Sound](#sound).

## UI and formspecs

- **UI**: formspecs (`core.show_formspec` +
  `register_on_player_receive_fields`), set `formspec_version` +
  coordinate mode deliberately. The UI modernization (0.60.1) uses the
  [presentation toolkit](../ui-presentation.md) for shared frames and navigation;
  live inventory pages and the map use real coordinates throughout their
  bodies; standalone legacy forms retain their own explicit coordinate contract. 3D preview: `model[]` element.
  Skill tree = formspec with an `image_button` grid.
  Gains (XP, loot, quest progress, catches), combat notices and personal
  notices (item-use refusals, mount notices, talent points) go to the message
  feed above the bars, never to chat: `grug_core.feed(player, kind, text, key)`,
  `feed_xp`, `feed_item` (`grug_core/feed.lua`, Round 28 ruling 20). Since
  Round 32 the kind `combat` (grey) carries "You dodge!" and "Dismount
  before attacking.", and each personal notice group keeps one keyed line a
  repeat refreshes (`potion`, `food`, `equip:<reason>`, `class_change:*`,
  `starter:<slot>`, `weapon_hint`, `mount`, `talents`, `boss_loot`); a new
  personal notice goes there too. Chat keeps deaths, rare sightings, boss
  and dragon warnings and the one-time no-weapon hint
  ([inventory_equipment.md](../../design/inventory_equipment.md) "Message feed").
- **Raw form fields are cut first (Round 81, audit X6-01):** the engine
  accepts up to 640 KiB of field data in one submit, and `string:trim()`
  (also inside `core.explode_textlist_event` and its kin) takes time that
  grows with the square of a run of blanks. A handler cuts a raw field with
  `grug_core.text` (`grug_core/text.lua`) before any trim or event parse:
  `cut(value, bytes)`, `cut_trim(value, bytes)`, or `clean_field(value, limit)`
  for a text box (control characters out, trimmed, at most `limit` bytes).
  Anchored `match("^(%u+):(%-?%d+)$")` parses need no cut.
- **The hotbar switch (Round 50, `grug_inventory/hotbars.lua`,
  [inventory_equipment.md](../../design/inventory_equipment.md) §1):**
  `grug_inventory.inventory_view` draws the A/B buttons
  (`grug_inventory.hotbar_switch(player, x, y, w, h, dx, dy)`, fields
  `grug_inventory.HOTBAR_FIELDS`), so a form showing a view shows them; the
  quickbar draws the same element. Whoever receives such a form's fields
  calls `grug_inventory.hotbar_switch_fields(player, fields)` after
  `keep_scroll` and re-shows its form when it answers true (the inventory
  pages through `sfinv.handle_scroll`, chained in `hotbars.lua`;
  `default/node_formspec.lua`, `default/chests.lua`, the workspaces, the
  Claim Stone form, the mail's Write tab, the quickbar). The switch itself
  is `grug_inventory.switch_hotbar(player, "A"|"B")`; consumers read
  `grug_inventory.consume_lists(inv)` (carried lists, the inactive layout
  last), and `register_on_hotbar_switch(fn)` runs before a switch's swap
  (grug_abilities cancels input there). The hidden list's guard is the
  first allow callback of `grug_inventory` (init.lua loads `hotbars.lua`
  first).
- **Inventory and item flow** (`grug_inventory`; the player-facing rules
  are [inventory_equipment.md](../../design/inventory_equipment.md) §1 and §3):
  `storage.lua` holds the give order, pickups and dug drops, the sort and the
  potion belt; `bags.lua` the bag slots and content lists; `inbox.lua` the
  one-slot shift-click inbox; `trash.lua` the Trash box; `bound.lua` the
  bound-item seam. Rules for other mods: every item source goes through
  `grug_inventory.give(player, stack)` (the quiver and the belt first, then
  `main[9..]`, the bags, the hotbar last; it returns the leftover for the
  caller to drop, refuse or keep); an all-or-nothing reward asks
  `grug_inventory.fits(player, stacks)` first; a consumer counts and takes
  through `consume_lists` (below); `register_on_give(fn)` hears what `give`
  placed; a soulbound or skill-like item registers with
  `register_bound_rule`. Do not resize `grug_shift` or `grug_inbox`: the
  shift-click routing relies on their one slot. Fixtures `tools/r44_ih`
  (the give order and pickups), `tools/r45_pt5` (the inbox),
  `tools/r48_bags`, `tools/r50_hotbar`, `tools/r69_ui` (the Trash box).
- **Initial focus (0.45.1):** the inventory key closes a window unless the
  focused element eats the key. When a window is built and nothing named in
  `set_focus[]` exists, the engine focuses the first empty edit box, else the
  first edit box, else the first table (a `textlist[]` is one), else the
  last button (`guiFormSpecMenu.cpp` `setInitialFocus`); edit boxes include
  every `textarea[]`, a read-only one too, and an edit box or a table eats
  letter keys. So a window with an edit box or a table names a harmless button in
  `set_focus[<name>;true]`, placed before that button (Talents & Skills,
  Inventory, Social and the mailbox window: an invisible zero-size button
  with no action; Character: the selected mode's button, never Return home; Help: the
  open sub-page's button; Claim Stone and Crownbinder: Close; the creation
  window: the chosen faction). Forced, because an unforced `set_focus` only
  applies when the window shows a new form name, and the inventory key opens
  the inventory under the name "" a fresh window already has; and because a
  tab click re-runs the engine's choice. A
  dialog with fields the player types in again after a refusal uses the
  unforced form (the withdraw dialog: Cancel), so the field keeps its focus.
  Model and checks: `tools/r451_kf` (`focus.lua`); the book's read view
  (vendored `default`) focuses its ">" button.

## Key presses

- **`grug_keys`** (Round 44, `mods/PLAYER/grug_keys/init.lua`; rules
  [world_map.md](../../design/world_map.md#map-window)): the rising edge of the zoom key
  (Z, the map window) and of aux1 (E, the quickbar). The server sees only the movement
  keys, aux1, sneak, dig, place and zoom; the input belongs to neither the map nor the
  quickbar, so both register here: `grug_keys.register_on_press(key, callback)` with
  `key` `"zoom"` or `"aux1"` (`grug_map/window.lua` opens the map window,
  `grug_quickbar` the quickbar). The callback runs on the step the key goes down, never
  while it is held; a player's first step after joining only records the keys. One
  globalstep, not throttled (an edge is one step long), reads
  `get_player_control_bits()` once per online player and does nothing more unless a
  watched key rose; no "menu open" check is needed, because the client releases every
  key while a menu or the chat is open. `grug_keys.rising(before, now)` is the pure
  edge test. At join every player gets `zoom_fov` `grug_keys.ZOOM_FOV` (72, the
  client's default field of view): with 0 the client refuses Z ("Zoom currently
  disabled"), and at 72 a held Z changes nothing visibly and sends no farther.
  Fixtures `tools/r44_mq` and `tools/r44_qb` load the real mod.

## Text in the world

- **Round 68** (`grug_text`, a CORE mod; [round68-plan.md](../../planning/round68-plan.md)
  rulings 1-5): the engine draws no text on nodes, so a written surface gets
  **one text entity**, a non-pointable `upright_sprite` just in front of it,
  whose texture is the text: one `[combine` of the imported CC0 glyphs
  (`grug_text_*.png`, 5-6 × 12 px, `characters.tsv`;
  `tools/r68_text/import_font.py --check`) tinted with `[multiply:<ink>`.
  One glyph pixel is 1/128 node on every surface; cells are 6 × 12 px
  (monospaced, so "N characters" is exact); the canvas is rounded up to
  powers of two and the text block centred on it. Characters without a
  glyph show the placeholder `grug_text_rc`.
- **Wrapping** (`layout.lua`, pure): rows break at spaces (a run of spaces is
  one break), a word longer than a row starts its own row and breaks
  inside, newlines start rows, what does not fit is cut off; control
  characters are dropped, malformed UTF-8 shows the placeholder.
- **Lifecycle:** the entities are **not saved** (`static_save = false`);
  the engine deletes them with their unloaded mapblock and the LBM
  `grug_text:restore` (`group:grug_text`, `run_at_every_load`) recreates
  them when the node's block is activated (a node without text costs no
  object search there). The node's own update paths call
  `grug_text.refresh(pos)`, which finds the node's entities by the node
  position they carry, keeps one per surface, updates only what changed
  (position, rotation, texture) and removes extras; `register` wraps the
  node's `after_destruct` to remove them. Empty text: no entity. Limit: a
  chest label's entity lies in the node in front of the chest; for a chest
  on a mapblock's edge it can be unloaded with the next block alone while
  the chest's block stays active, and returns only when the chest's block
  is activated again.
- **Orientation:** the sprite's front (`textures[1]`) is seen from its local
  +z side, so the entity's rotation is `vector.dir_to_rotation(-look, up)`
  for the reader's look direction `look` and the text's `up` (per
  `paramtype2`: `wallmounted`, `facedir`/`4dir`, `degrotate` at 1.5° per
  step as the engine turns the mesh, `client/mesh.cpp` `rotateMeshXZby`).
  A second face (`faces = 2`) shows the same text on the quad's back, read
  correctly from behind (`client/content_cao.cpp`: the back quad swaps its
  corners and keeps its UVs).
- **API** (for lane SIGNS): `grug_text.register(name, surface or list)` at
  load time after the node, a surface being `{lines, chars, ink, offset
  (x reader's right, y up, z into the surface), frame, faces, align,
  valign, text = fn(pos, node, meta)}`; `refresh(pos)`, `remove(pos)`,
  `surfaces(name)`, `layout`, `charmap`, `INK`. The full contract is the
  header of `grug_text/init.lua`.
- **Shipped surfaces** (`surfaces.lua`): the wall signs
  (`default:sign_wall_wood`, `grug_materials:iron_sign_wall`) 4 × 15 at
  7/16 − 1/64 towards the wall, through an override of their form handler;
  every chest tier, normal and locked, closed and
  `_open`, 3 × 13 of the 40-character label, centred at y = −5/16 just in
  front of the front (below the lock, on the part the lid does not move),
  refreshed by `default.containers.update_infotext` (GRUG PATCH: label
  save, clear, upgrade). Inks per surface in one table each.
- **No hover text** (the user, 2026-10-31, after the round): a written
  surface's text shows only on the surface. The wall signs' handler
  (GRUG PATCH in `default/nodes.lua`) and `grug_signs.write` store only the
  meta `text`; a chest's `infotext` is its name (a locked chest's with its
  owner), never the label. Signs and labels written before kept the text in
  their `infotext`; two one-time LBMs (`run_at_every_load = false`) drop
  it on the first load of their block: `grug_text:drop_hover_text`
  (`surfaces.lua`: the wall signs and every chest node; a labelled chest
  gets `update_infotext`) and `grug_signs:drop_hover_text` (its four
  nodes). Blocks saved later never carry it, so nothing runs on them again;
  only player-written text had it, and a block a player wrote in was
  active, so it carries the timestamp the engine compares.
- **The new signs** (`grug_signs`, an ITEMS mod; lane SIGNS, rulings 6-8):
  the standing sign (4 × 15) and the waypost (1 × 14 on each side of its
  arrow, two one-faced surfaces) turn freely (`degrotate`), the two-node
  notice board (7 × 30, its text on the right-hand node `notice_board`)
  in four steps (`4dir`); each of its two nodes draws its own half of the
  model (ART's pass-4 split, so the digging cracks show on the half being
  dug): `notice_board` ART's left half, `notice_board_part` ART's right
  half, which the mirror below puts on the part's side. Lane ART's models
  and wood set B textures are copied byte for byte; the OBJ loader
  negates x (`irr/src/COBJMeshFileLoader.cpp:314`), so in the game each
  model is ART's spec mirrored in x, and the surfaces' offsets are written
  in the game's coordinates. The engine never turns `fixed` boxes of a
  degrotate node (`mapnode.cpp` `getFaceDir`), so the standing sign and the
  waypost have unrotated selection boxes around what their board or arrow
  sweeps. The board is placed and dug as one (the bed's pattern: the
  partner removed by `swap_node` + `remove_node`, so `grug_signs` removes
  the board's text entity itself when the part is dug; the partner's
  neighbours are checked for falling from `after_destruct`, because from
  `on_destruct` builtin's attached-node walk would find the destructed
  half still standing without its ground and drop a second board). Writing goes
  through `grug_signs.write` (the wall sign's rules); every node is in the
  claim reading exemption. Fixture `tools/r68_signs/portable_test.lua`
  checks the text positions against ART's spec under the engine's mesh
  turn.

## Item displays

- **`grug_displays`** (Round 75, `mods/PLAYER/grug_displays`; rules
  [decorations.md](../../design/decorations.md#functional-displays)): the item frames
  (`grug_decor:xdecor_itemframe`, overridden, and the iron, carved and brass frames),
  the armor stands (wooden, iron, carved) and the weapon holder. The node inventory is
  the only durable owner. What shows is one unsaved entity per node
  (`grug_displays:projection`, `static_save = false`, not pointable), recreated by the
  LBM `grug_displays:restore` at every load (`run_at_every_load`, group
  `grug_functional_display`) and by `grug_displays.refresh(pos)` after every put, take
  and placement; `remove(pos)` runs after destruction. A frame shows its stack as a
  wielditem in front of its face, a weapon holder its weapon or shield, a stand its
  armor on the NPC model through `grug_visuals.compose` (`stand_spec`,
  `stand_textures`; nothing shows without armor). The pure checks are
  `slot_accepts(slot, stack)` (one item of the slot's `grug_equip_*` group) and
  `weapon_accepts(stack)` (one item of `grug_equip_weapon` or `grug_shield`). Every
  put, take and move asks `grug_core.interaction_protected` (moves between the lists
  are refused); a display must be empty to be dug, and a wall frame or holder that
  loses its support drops its stored stack too (`preserve_metadata`). The window is the
  station form (`grug_inventory.station_formspec` through `default.node_formspec`).
  Fixture `tools/r75_displays`.

## Player model and skins

- **Player model/skins**: players go through `player_api.set_textures` on
  the seven-slot `grug_visuals_character.b3d` (`grug_visuals/apply.lua`);
  `compose.lua` builds the layers (look, armour, cloak; below).
- **Emotes** (Rounds 78 and 80, rules in
  [character_visuals.md](../../design/character_visuals.md) "Emotes"): clips baked
  after the poses (`tools/r40_an/poses.json`, `tools/r33_c3/gen_cloak_model.py`, whose
  `--check` holds `grug_visuals.EMOTE_CLIPS` in `apply.lua` to the model; new clips are
  appended after the last frame). `grug_visuals.play_emote(player, id)` returns true or
  false plus `unknown`, `not_owned`, `dead`, `busy`, `playing` or `seated`. Ownership
  lives in `grug_quickbar.owns_emote(player, id)` (Wave and Dance always; a row of
  `grug_quickbar.EMOTES` with `reward` while `grug_accounts.has_reward` holds it), handed
  to `grug_visuals.set_emote_gate` at load, because `grug_visuals` must not depend on
  `grug_accounts`; without a gate (fixtures) every emote is owned.
  `grug_quickbar.emotes(player)` lists the owned ones in grid order. The quickbar
  registers the reward `emote:cheer`. Icons `grug_quickbar_emote_<id>.png` and
  `_off.png` (64 px, renders of the model) come from `tools/r80_emote/icons.py`
  (`--check`). Fixtures `tools/r78_emote`, `tools/r80_emote`.

## Looks and enchant colours

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- The worn armor and offhand layers, their icons and masks are baked by
  `tools/r54_armor/bake.py` and `tools/r55_offhand/bake.py` from the picked art in
  `tools/r54_art/` and `tools/r55_art/`, never edited by hand; the contracts change only
  through a round's coordinator ([armor format](../armor-format.md),
  [offhand format](../offhand-format.md)).

- **Looks and enchant colours (Round 31):** `grug_visuals/looks.lua` (pure)
  holds the option tables per race, `normalize_look`, `roll_look`,
  `look_from_seed`, `npc_look` and `look_texture` (layer order; a worn
  helmet drops the hair); the art comes from
  `tools/wp13/gen_character_visuals.py`. `apply.lua` stores a player's look
  once in meta `grug_visuals:look` (`set_look` refuses a second write) and
  builds `player_spec`; `compose.lua` puts every armour piece in its own
  parentheses and keys its cache on every normalized input (two generations
  of 2,048 entries since Round 81: a full one becomes the old one, an old
  hit moves to the new one; callers compare results by `key` and `digest`,
  never by table identity). Since Round 54
  armour is boxes in the model with one atlas
  ([armor format](../armor-format.md)): `compose` returns `skin` (the look with
  each worn chest, legs and feet piece's skin layer
  `grug_armor_<line>_<grade>_<slot>_skin.png`) and `armor` (the worn pieces'
  atlas layers `grug_armor_<line>_<grade>_<slot>.png` overlaid, `ARMOR_NONE`
  = `blank.png` without any; file names in `grug_visuals.ARMOR_ART`), and
  `textures`, an entity's whole list: `{skin, armor, WEAPON_NONE,
  OFFHAND_NONE, BACK_NONE}` for a spec with `armor_line` (the last two since
  Round 55, blank; the NPC model `grug_visuals.NPC_MODEL` =
  `grug_visuals_npc.b3d`, set as the mesh of the guard, bandit and boss
  definitions), `{skin}` otherwise (`character.b3d`). A `royal` spec with
  armour gets the royal variant (zones A and B in `ROYAL[race].cloth` and
  `ROYAL_GOLD` through the zone masks; a king no helmet); `armor_colors =
  {a, b}` sets the zone colours of any spec (the War Commander's faction
  colours). `apply_entity` writes the list when compose's `digest` (a
  content digest of the list, not its input key, so a retuned colour reaches
  saved NPCs) differs from the entity's `_grug_visual_key` (saved in
  staticdata). `grug_visuals.preview(player)`
  returns `{mesh = PLAYER_MODEL, textures = {skin, cloak, armor, weapon,
  offhand, back, wings}}` for the inventory view, the weapon the main hand's
  cosmetic item's image (`hand_image`) or `blank.png`. **The offhand look**
  (Round 55, [offhand format](../offhand-format.md)) sits behind the setting
  `grug_offhand_visuals` (default true since 0.55.0, the off switch;
  `grug_visuals.OFFHAND_VISUALS`,
  read once in `init.lua`, part of compose's key): off, the offhand, back
  and wings slots are `blank.png` (`OFFHAND_NONE`, `BACK_NONE`,
  `WINGS_NONE`). On, compose's `offhand_item`, `offhand_broken` and
  `offhand_enchant` (from `player_spec`; `enchant.lua`'s
  `offhand_enchant`) draw a shield's or spellbook's layer
  `grug_offhand_<shield|book>_<grade>.png` (`offhand_appearance`, indexed
  with the armour) into `result.offhand`, coloured and cracked as an armour
  layer; a Scout's back card is the inventory image of the equipped weapon
  the hand does not show (the Melee blade when the hand shows the bow -- a
  bow skill, the bow item, the Character tab's weapon card -- else the bow;
  `apply.lua`, rewritten by the wield poll when it changes, never stored),
  drawn by `back_card(image, on_cloak)` into the 32 × 16 back slot's left
  half (the cloak's card) when a cloak is worn, else the right half (the
  body's card), escaped for `[combine`;
  the wings come from the cloak source. NPCs keep
  `_grug_look_seed` in their staticdata; `npc_race(entity, faction, opts)`
  gives the settlement's race, or with `{mixed = true}` /
  `_grug_mixed_race` a race of the faction (fortress garrisons).
  `creation.lua` is the look panel of the creation window
  (`roll`, `formspec`, `act`, `store`), registered with
  `grug_classes.register_look_panel`.
  Enchant colours: `grug_gear/enchant_colors.lua` (`ENCHANT_COLORS`,
  `ENCHANT_OPACITY` 128, `enchant_image`, `enchant_layers`,
  `strip_enchant`; masks `<texture>_ench.png` from
  `tools/r31_b/gen_enchant_masks.py` (weapons, bows, the shared
  spellbook image), `tools/r54_armor/bake.py` (the armour) and
  `tools/r55_offhand/bake.py` (shields and spellbooks, Round 55), each
  `--check` rebuilds and compares);
  `grug_items.regenerate_description` (`grug_quality/init.lua`) writes the
  stack's `inventory_image`
  (removed for a plain stack), which the wield entity and dropped items
  use; `grug_visuals/enchant.lua` turns worn affixes into compose's
  `armor_enchant` (`{slot = {prefix, suffix}}`; compose lays each piece's
  colours over its atlas and skin layer with that file's own mask);
  `armor_layers[slot]` is an extra skin-space layer inside a piece's skin
  layer (the War Commander's tabard); NPC specs may carry `weapon_colors`
  (kings, Generals).
  Fixtures `tools/r31_a` (incl. the equal hitbox), `tools/r31_b`,
  `tools/r54_game`, `tools/r55_game`; rules
  [character_visuals.md](../../design/character_visuals.md).

## Cloaks and achievements

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- Achievements are catalog data on existing counters fed by hooks
  (`grug_mobs.register_on_boss_kill`, `grug_pvp.register_on_stat`,
  `grug_jobs.register_on_award_progress`), never a second kill, craft or boss path; stored
  per character.

- **Cloaks and achievements (Round 33):** players wear
  `grug_visuals/models/grug_visuals_character.b3d`, `character.b3d` with a
  cloak box on a keyed `Cloak` bone and its own mesh buffer appended
  (`tools/r33_c3/gen_cloak_model.py`, `--check` rebuilds and compares and the
  build proves the legs never cross the cloak). Since Round 54 the same
  generator appends the armor buffer, the swing bones
  `Panel_Front`/`Panel_Back` and the weapon card on `Arm_Right` (texture
  slots skin, cloak, armor, weapon) and writes the armored NPC model
  `grug_visuals_npc.b3d` (skin, armor, weapon); the build also proves the
  panels clear the legs and checks the rest pose for z-fighting
  ([armor format](../armor-format.md); fixture `tools/r54_model`). Since
  Round 55 it also appends, from `tools/r55_offhand/params.json`, the bones
  `Offhand_Shield` and `Offhand_Book` under `Arm_Left` with three shield
  copies and the open book (the `offhand` buffer), the two back cards (on
  `Cloak` and on `Body`; the NPC model the body card only) and the cloak
  wings (player only) ([offhand format](../offhand-format.md); fixture
  `tools/r55_model`). Armored NPCs wear the NPC model, the others
  `character.b3d`.
  The player texture list is `{skin, cloak, armor, weapon, offhand, back,
  wings}` (the weapon card `blank.png` in the world, the last three Round
  55's offhand look): `grug_visuals.apply` writes it
  with the cloak from the one `register_cloak_source(fn)`, `fn(player) ->
  texture, selected id, wing texture` (no cloak: builtin `blank.png`; a
  catalogue row's optional `wings`, the Supporter Cloak's), the textures part
  of the redraw key, the id part of the stored appearance. `mods/PLAYER/
  grug_achievements` owns the rest: `core.lua` (pure: counters, tiers,
  unlocked cloaks and the selected cloak in player meta, i.e. per
  character), `catalog.lua` (data: 22 achievements, tier N of `<id>`
  unlocks cloak `<id>_N` (the three of Round 36 a cloak of its own name),
  an optional `faction` hides and withholds a row from the other faction
  (the faction from `grug_core.get_player_faction`), `manual = true`
  marks a row granted by `/achievement` instead of a counter (Round 55,
  `supporter`), defaults `none` and `plain_grey`), `creatures.lua`
  (pure: wild animals, zombies, families, named leaders by role, rares by
  registry id; a load audit logs any unclassified mob) and `init.lua` (the
  hooks, the Achievements mode body and the cloak dropdown that
  `grug_inventory/pages.lua` reads at build time). Counters come from
  grug_mobs' eligible-kill hook (cached per entity name),
  `grug_mobs.register_on_boss_kill(fn(player, boss_id))` (every player the
  boss ledger credits, independent of the loot lockout; `bosses.lua`
  `settle_boss`), `grug_pvp.register_on_stat`,
  `grug_jobs.register_on_award_progress`, `register_on_dieplayer` and, since
  Round 36, `grug_quests.register_on_turn_in` (an optional dependency:
  `quest:<id>`, `quest_tag:<tag>`); each is O(1) per event. A manual row's
  counter is `manual:<id>`: `/achievement grant|revoke <player> <id>`
  (`server`) sets it to 1 and settles (`R.grant`) or clears counter, tier,
  cloak and a worn selection (`R.revoke`); for a player who is offline the
  action waits in the mod storage key `queue:<player>`
  (`<id>=grant,<id>=revoke`) and the join hook applies it once, before the
  join's settle pass. The tab lists rows through `R.shown_list` (the
  faction rule, and a manual row only once granted). Cloak textures are 32×32 (outer face left, lining
  right). Fixtures `tools/r33_c3`, `tools/r55_supporter`; rules
  [character_visuals.md](../../design/character_visuals.md) §5b.
- **Account cloaks (Rounds 79 and 80):** a catalogue cloak with `account = true`
  (`supporter` and the six donor cloaks `emberwake`, `veilstream`, `pearlwing`,
  `moonfall`, `wintercourt`, `frost_regent`, which have no achievement and no tier) is
  also the website-account reward `cloak:<id>`: `init.lua` registers it
  with `grug_accounts.register_reward` (kind `cloak`, the outer face as the Account
  page's icon). `account_cloaks(player)` builds the set of the ones the character's
  account gives (`grug_accounts.has_reward`, read live at every check, never stored),
  and the pure `core.lua` functions take it as an optional last argument: `R.has_cloak`,
  `R.unlocked` (the picker, `cloak_dropdown`, `choose_cloak_by_name`), `R.selected`,
  `R.select`, `R.cloak_texture` and `R.revoke` (revoking the manual Supporter row keeps
  a worn cloak the account still gives; the earned cloaks are never touched). Without
  the set the rules are unchanged. The stored choice `grug_achievements:cloak` stays
  when the account loses the cloak, which then reads as none, so a re-grant wears it
  again (the user, 2026-11-15). On `grug_accounts.register_on_change` an online
  character is redrawn (`grug_visuals.apply`: look and stored appearance) and its
  Character page re-sent; an offline one follows at its next join, so its stored
  appearance names a revoked account cloak until then. The donor cloaks' textures
  (`grug_achievements_cloak_<id>.png` and `_wings.png`) are made by
  `tools/r80_art/assemble.py` from the delivered painters (`--check`). Fixtures
  `tools/r79_page`, `tools/r80_rewards` (the rows, the grant and loss, the Account page
  with up to 18 rewards in two columns at both text sizes).

## Sound

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- One play path, `grug_sounds.play(event, target)`; no new `core.sound_play` for a game
  event. The approval gate is in AGENTS.md "Sound".

- **Sound (Round 34; rules [sound.md](../../design/sound.md)):**

### grug_sounds, the one play path

  - **`grug_sounds`** (`mods/CORE/grug_sounds/init.lua`) is the one play
    path for effects: `grug_sounds.play(event, target)` with a player, an
    object or a position; `EVENTS` maps an event to its spec (name, gain,
    pitch, distance, `personal`, `interval`, `stoppable`) and an event
    without a spec is a silent no-op (the approval gate: no spec until the
    user picked a file). A `stoppable` event (the gallop and wing beats)
    keeps the handle of its last play per target, and
    `grug_sounds.stop(event, target)` fades it out in 0.1 s and lifts the
    interval, so the next play sounds at once. The rate limit is checked before anything is allocated (per
    event and target: a player name, an ObjectRef with weak keys, or
    `"pos"`). `HOOKS` lists every event a call site may name; a new call
    site adds its event there and its mod depends on `grug_sounds`.
    `item_sound(event)` gives an item definition's sound table (the swing
    skills' `punch_use_air`). `CLICK_STYLE` ends `grug_core.ui.prepend`,
    the whole prepend grug_core sets on join, and is pasted into the two
    `no_prepend[]` formspecs. Call sites by kind: crafts through `grug_jobs.award_progress`
    (`CRAFT_SOUNDS` by operation or profession;
    `grug_jobs.furnace_take_sound` for a cooked dish taken from a furnace,
    smelting and the plain refinements stay silent), abilities through
    `grug_abilities.CAST_SOUNDS` in `try_cast` (every registered ability
    must be listed: a cue, `"weapon"`, `"projectile"` or `"silent"`),
    projectiles through `sound_launch`/`sound_hit` on
    `grug_projectiles.register` (a spawn's own `params.sound_launch`
    replaces the launch cue for that launch, Round 53), the round-K impacts
    (`meteor_impact` ...) from the class kits, melee hits through
    `grug_core.melee_hit_sound(player)` (by `_grug_weapon_family`), voices
    through `voices.lua`, gear breaking through `grug_repair/runtime.lua`
    `announce_break` (Round 35: in the gear, tool and hoe wear paths, once
    when a stack wears into broken; the broken look is
    `grug_gear.BROKEN_MODIFIER` in `broken_image`). Fixtures
    `tools/r34_s1a`, `tools/r34_s1b`, `tools/r35_f` (they check call sites,
    specs, files and the approval lists); fixtures that load a hooked file
    get a silent stub.

### grug_ambience

  - **`grug_ambience`** (`mods/CORE/grug_ambience`): `rules.lua` is pure
    (the sound key, bed choice and hysteresis, the layer levels and steps,
    the cave verdict, the either-music-or-bed rule, calls, the
    capital music scheduler, the emitter choice, settings words; the fixtures
    load the real file), `data.lua` is data (biome groups, bed, loop and
    call names, layer curves, the cave probe's grid, gains, one track
    rotation per capital, track lengths, timings),
    `init.lua` the runtime: an eight-slot pass of 0.25 s per player
    (`states[name].slot`, assigned on join); since Round 52 three layers
    (surface, cave, wind; 0.52.1 adds the sea) by
    `grug_core.depth_below_surface` (defined in
    `grug_core/atmosphere_zones.lua` with its per-player column memo) and
    the cave probe (75 `get_node_raw` reads, only deeper than 4 nodes),
    `/ambience debug`; one `get_node_raw` probe for
    under water (33 reads while a stream bed exists), the sea share
    (`grug_ambience.sea_share`, below), one
    `find_nodes_in_area` out of water for the fire and flowing-water
    loops (none at forges and anvils since Round 45 PT8) (node names from `D.emitter_nodes` plus every flowing liquid whose
    source is default or river water, filled on `register_on_mods_loaded`).
    Round 47: both burning furnaces are the `furnace` kind (the fire loop at
    `D.gains.furnace`); a kind with `stop_on_destruct` gets an `on_destruct`
    on its nodes (wrapping the node's own, installed in the same
    `register_on_mods_loaded`) that calls `grug_ambience.stop_emitters_at`:
    the loop at that position fades out over `D.stop_fade` for every
    listener, a lookup per online player on that event only; fixture
    `tools/r47_fs`, engine probe `tools/r47_fs/engine.sh`.
    Only names with a shipped file play (`available` from the `sounds/`
    listing, the capital rotations filtered by `music/`), so data may name a file that does
    not ship. Music files live in `music/` (never `sounds/`) and are pushed
    per player with `core.dynamic_add_media` (`to_player`, not ephemeral,
    `client_cache`), playing in the callback through `music_delivered`; music
    plays only in a capital (`grug_map.location.capital_of`) and ends with a
    fade on leaving. Settings are player meta
    (`grug_ambience:music_off`, `…_volume`, `ambience_off`, `…_volume`);
    `grug_ambience.set/get` is the one entry for the Help page's Sound
    sub-page (`settings_formspec`, `handle_settings_fields`, called from
    `grug_inventory/help.lua`) and `/music`, `/ambience`. A personal
    positional sound ignores `max_hear_distance`, so the emitter choice
    drops far nodes itself. `grug_ambience.stats` holds comparison figures
    for the engine probes `tools/r34_s2/engine.sh`, `tools/r35_m/engine.sh`
    and `tools/r52_amb/engine.sh` (Round 52: a scripted walk, the cave
    calibration, the peak heights; `grug_core.depth_stats` beside it);
    fixtures `tools/r52_amb` (groups, curves, layer steps, cave verdict,
    depth helper and the atmosphere's underground band, the sea rules),
    `tools/r34_s2` (beds, layers, the coast and diving, calls, loops,
    files) and `tools/r35_m`
    (capital music, either music or the bed, settings). The "Now playing"
    box (0.45.1): `R.now_playing(m)` is the track in phase "play";
    `sync_now_playing` compares it with `states[name].shown_track` after each
    scheduler pass, a delivery and a music switch and calls
    `grug_map.minimap.set_now_playing(name, D.tracks[id] or nil)` only on a
    change; the minimap draws the box (`minimap_view.lua`
    `now_playing_box`, three side elements that stay with the minimap hidden
    or unavailable and then stand in the corner, `now_playing_corner`, since
    Round 48). Fixtures `tools/r451_mu` and `tools/r27_minimap` block P.

### The ambience model

  - **The ambience model (Round 52,
    [ambience plan](../../planning/round52-ambience-plan.md); rules
    [sound.md §4](../../design/sound.md#4-ambience-beds-grug_ambience)).** One
    pass per player every 2 s in the existing slot scheduler; no new
    globalstep.
    - **Depth reference:** `grug_core.depth_below_surface(pos[, name])`
      (`grug_core/atmosphere_zones.lua`) returns `depth, column`: the
      depth is `ref + 0.5 - pos.y` (0 standing on the ground, positive
      below it, negative above it), nil while no zone authority exists.
      `ref` is `terrain_height_at`, or terrain plus the water depth from
      `water_query_at` where that is above 0, so a swimmer, a boat or the
      flying mount over a lake, a river, the coastal belt or a dragon
      channel counts from the water surface; over the sea it is sea level
      (y 1). Buildings and towers never count. The column record `{x, z,
      ref, zone_id, biome}` is a memo per player, keyed by the node
      column (`floor(x + 0.5)`, `floor(z + 0.5)`) and cleared on leave:
      a player who stays in one column costs no zone query, and the
      atmosphere driver and the ambience asking in the same column cost
      one (`grug_core.depth_stats`: calls, memo hits, columns, µs).
    - **The atmosphere's underground band:** `mood_key_at` turns
      "underground" at a depth above 20 and back only below 16
      (`UNDERGROUND_IN`, `UNDERGROUND_OUT`; before Round 52 the absolute
      y < −20), so a level tunnel under rolling ground does not flip sky
      and fog every pass. A column without a zone id (the ownerless
      ocean) keeps the ocean mood at every depth. The mobs' "underground"
      (`spawn_policy.lua`) is a separate, absolute rule.
    - **Sound key:** `R.sound_key(D, mood, known, biome)`: a mood in
      `D.overrides` (Battlegrounds, dragon island, ocean) first, then
      `D.groups[biome]` by the full `grug_` biome id (15 biomes in 8
      groups: temperate, savanna, jungle, badlands, swamp, crags,
      crags_snowy, blight); an ownerless column is the ocean; the
      underground mood keeps the last key; inside a start town (0.52.1:
      `location.in_town` and no `capital_of`) the biome is the town's look,
      `R.start_town_look` with the nearest start anchor of
      `grug_core.settlement_socket_settlements` within `D.town_reach` 103 (the footprint's farthest corner)
      and `D.town_looks[race]` (the anchors read once); a biome in `D.neutral` (the
      beach, 0.52.1) keeps the last group key, but an override key
      (`current`, the fifth argument) turns false there. `D.region[key]` names the day
      and night beds (`night = false`: silence at night, the crags; no
      night row: the day bed at night too).
    - **Four layers** (`st.layers`: surface, sea, cave, wind), each its
      own handle. `R.layer_levels(D, depth, y, cave)` gives their levels from
      `D.layers`, linear, as shares of the bed gain (`R.bed_gain`: the
      player's volume, halved in towns): the surface 1 from 0 to +10
      above the reference, 0 at 15 below and at 60 above; the wind 0 at
      +30, 0.5 from +100; the peak wind, only within 4 nodes of the
      surface or above it, 0 at y 215 and 0.25 from y 230 (`peak.ramp`
      15), the wind layer taking the higher of the two; the cave, only
      with a cave verdict, 0 at depth 4 and 0.4 from depth 16, the deep
      bed (`cave_deep`) below y −502 until above y −498 (`R.deep_cave`,
      `D.deep_y`, `D.deep_band`). `R.layer_step` turns a level into
      start, switch (a crossfade), fade or stop: a layer starts at
      `LEVEL_STEP` 0.03, fades only when its level moved by 0.03 (the
      dead band), falls to `LEVEL_FLOOR` 0.01 and keeps its handle, and
      is stopped (a fade to 0, which deletes the sound) only after
      `FLOOR_PASSES` 3 passes at 0. Where music plays every layer is
      silent; under water only the surface layer plays its `underwater`
      bed (a pool of two, 0.52.1) at level 1 (`R.surface_levels`).
    - **The sea layer (0.52.1):** `grug_ambience.sea_share(pos)` returns
      the share of sea columns among `R.sea_points(D)` (49 columns on a
      4-node grid within 16 nodes of the player's grid point) and whether
      the player's own column is sea, from `grug_zones.water_query_at`
      (`R.SEA_CLASSES`: bay, belt, channel, open sea; never a lake, a
      swamp pool or a river). Two memos shared by every player (column ->
      sea, grid point -> share; emptied together at 65,536 entries) make
      a known spot two lookups. `R.surf_mode` reads `D.region[key].surf`
      ("only" for the ocean, "none" for the dragon islands, else blend),
      `R.sea_blend` gives the surf's share of the surface level (share /
      `D.sea.full_share` 0.5, 1 on a sea column) and `R.surface_levels`
      splits it between the region bed and the surf. The share is asked
      only while the surface level is above 0, out of water and without
      music. `R.bed_should_change`'s fifth argument (the layer plays
      nothing) takes a new region key at once. `stats.seas`, `sea_us`,
      `sea_queries` (memo misses) are the comparison figures
      (`tools/r52_amb/engine.sh coast`).
    - **Cave probe:** `grug_ambience.cave_share(pos)` reads 75 nodes with
      `get_node_raw` on the grid `D.cave.grid_xz` × `grid_y` (5 × 5 × 3,
      a 2-node stride) round the feet; open air is a node that is neither
      walkable nor a liquid, an unloaded node counts as rock. It runs only
      deeper than `D.cave.min_depth` 4, and `R.probe_due` probes again
      only after a move of 2 nodes or on the third pass; `R.cave_step`
      needs two passes in a row for a new verdict. `D.cave.threshold`
      0.20 comes from the engine calibration (`tools/r52_amb/engine.sh
      calib`, seed 12345: natural caves 0.23 at the 5th percentile, dug
      tunnels and corridors at most 0.11, a large dug hall counts as a
      cave).
    - **Calls:** `R.eligible_calls` matches a `D.calls` row by sound key
      (`keys`) or biome (`biomes`, the wolves' pine hills), time of day
      and the region bed's level (`surface`, 0.5 for the animals; the
      surface level minus the surf since 0.52.1);
      none under water or in the underground mood. Animals 24–40 nodes
      away, thunder 40–56, one call per 90–240 s (`D.call_gap`).
    - **Loops underground:** the fire and flowing-water search runs on
      every pass out of water, underground too (Round 52; before, it
      stopped underground).
    - **`/ambience debug`:** `R.parse_command` accepts `debug`; the
      command toggles one HUD text line for the player who typed it (no
      privilege; left edge, 30 % down) with biome, sound key, depth, cave
      share and verdict, the sea share, the surface layer's file and the four levels, sent only when its text
      changed, "ambience: off" while the ambience is off or at 0.
