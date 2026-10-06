# Round 39 — Web data for the realm website

Coordinator: Claude (Opus 5.5), drafted 2026-10-06 from the requests of the
kaesual.com website, which hosts managed Grudgelands realms, and the user's
answers. Status: **approved and started on the user's "go" (2026-10-06)**.

The website shows each player's characters (faction, race, class, level)
and a 3D preview of the character in its current equipment. It reads
`player_metadata` from the realm's PostgreSQL world database through a
narrow read-only lookup and never runs game code on stored data. Mod storage
is not in PostgreSQL; player meta is. This round gives the website what it
needs without coupling it to game logic: two stored player-meta keys, a
documented contract for every key it reads, a data exporter, and the player
model as glTF.

No gameplay change. A player sees nothing new.

## 1. Lanes and waves

| Lane | What | Wave | Kind |
|---|---|---|---|
| WM | Player meta: `grug_xp:level`, `grug_visuals:appearance`, the contract section in the module guide | 1 | code (game) |
| WE | Exporter in `tools/web_data/` with its committed output and test | 1 (final wiring after WM) | code (tool) |
| WG | Player model as glTF (`.glb`) with a test against the `.b3d` | 1 | code (tool) |
| D | Round documentation | 2 | docs |

WM, WE and WG start together; they share no files. WE reads two values WM
defines (the appearance version and the texture length cap, §3); it builds
against the names fixed in §3 and merges main after WM for its final check.
Merge order: WG, then WM and WE together (§7), then D. Estimate: WM about 2 hours, WE 2–3 hours,
WG 3–4 hours, each plus its review.

## 2. Rulings

The user (2026-10-06) and the website's answers, which the user accepted:

1. **Level key** `grug_xp:level` as requested: decimal integer string
   1..`MAX_LEVEL`, written with `set_int` on every XP change and on every
   join, derived only from XP with the current curve. XP stays the
   authority. A missing row means level 1 to the website.
2. **Curve change:** moving a realm across the Round 28 curve change (and in
   general across rounds) needs a fresh realm; no XP conversion
   (fresh-server development mode, AGENTS.md).
3. **Contract documentation:** a section "Player meta read by external
   tools" in `docs/technical/module-guide.md`, one row per key the website
   reads (type, values, owning mod), stating that these keys are an external
   contract and are not renamed without notice.
4. **Appearance shows slot items only:** head, chest, legs, feet, mainhand
   (the Weapon slot) and offhand. The wielded / last selected item is never
   stored. For a Scout, mainhand is the bow ("Ranged") and the melee weapon
   is in the offhand ("Melee"); that is accepted. The offhand is stored now
   although the game does not draw it yet: the user wants it on the
   character in game later, and the format must not need to change then.
   Trinkets have no visual and are not stored. In game the hand may show
   something else (a pickaxe, a skill's slot item); that difference is
   intended.
5. **Stored composed textures:** the appearance carries the final body and
   cloak texture strings the game applies, so the website never ports the
   composition. The website renders only actual current equipment.
6. **Reduced exporter:** no appearance catalogue (look options, item →
   overlay mapping, enchant colours) and no golden "spec → texture" pairs.
7. **Website additions (accepted):** a closed set of texture modifiers and
   PNG file names the strings may contain; a documented maximum length; the
   cloak texture and the race's visual size in the appearance; an initial
   write on join when the key is missing or older; the model file and its
   frame ranges; wield image and scale for hand items; optionally display
   name and inventory image for every equippable item; the model as glTF
   with a test and attribution.
8. **Untrusted data:** the website treats every stored value as untrusted
   and parses the texture string with an allow-listed, bounded parser. The
   game side guarantees the closed sets and the length cap by test.

## 3. Shared conventions (the contract)

- **`grug_xp:level`:** see §2.1.
- **`grug_visuals:appearance`:** compact JSON, written with `set_string`
  whenever the character's appearance key changes (`grug_visuals.apply`
  already compares one), which includes the first apply after every join,
  so a missing or older entry is replaced without changing the look:

  ```json
  {"v": 1, "race": "<race id>",
   "look": {"tone": 1, "hair": 1, "style": 1, "eyes": 1, "feature": 1},
   "cloak": "<cloak id or none>",
   "visual_size": {"x": 1, "y": 1, "z": 1},
   "textures": {"body": "<composed texture string>", "cloak": "<texture or none>"},
   "slots": {"head": S, "chest": S, "legs": S, "feet": S,
             "mainhand": H, "offhand": H}}
  ```

  `S = {"item": "<itemname>", "broken": bool, "enchant": ["<channel>", …]}`,
  `H` = `S` plus `"pose": "<pose id>"` (`grug_visuals.POSE`: tool,
  edge_down, bow, upright, forward) and `"image": "<texture string>"`, the
  hand item's image as the game would draw it (enchant colour and broken
  look included, `grug_visuals.wield_appearance`), so the website ports
  neither the enchant colours nor the broken tint. An empty slot is absent.
  Field names are final once WM merges; WM may refine a field's spelling in
  its report before merge, and WE follows. Any later change to the format
  raises `v` and is documented in the contract section.
- **Shared constants in `grug_visuals`:** `APPEARANCE_VERSION = 1` and
  `APPEARANCE_TEXTURE_MAX` (bytes per texture string; WM measures the worst
  case — every slot filled and enchanted, the longest look — and sets a cap
  with headroom). A test fails when any stored texture string (body, cloak,
  hand images) exceeds it.
- **Closed sets:** every stored texture string uses only the modifiers the
  composition uses today (`^` overlay, `^[hsl`, `^[mask`, `^[multiply`, and
  whatever WM's check finds in addition) and PNGs from a known set of
  texture directories (body and armour layers, cloaks, hand items). WE
  exports both sets; WM's test asserts that the stored strings stay inside
  them.
- **Exporter output:** one JSON document, committed as
  `tools/web_data/web_data.json` with a `--check` mode. The committed file
  is the contract: the website reads it at a realm's commit and never needs
  to run the exporter. The JSON carries a `schema` version and the
  appearance version it describes.
- **Tools are free (the user, 2026-10-06):** the exporter and the model
  converter may use whatever tool is simplest and most robust — LuaJIT
  with stubs, a headless Luanti dump (`tools/luanti_headless.sh`), Python,
  `assimp`, Blender, or an own script. When a route turns out to be very
  laborious, the lane stops, checks the alternatives and asks the user.
- **Model:** `tools/web_data/model/grug_visuals_character.glb`, committed,
  with its attribution next to it.
- **Tool and fixture folders:** `tools/web_data/` (exporter, output, model,
  README); lane fixtures in `tools/r39_<lane>/portable_test.lua`.

## 4. Lanes (goals; the briefs add file facts)

### 4.1 WM Player meta (wave 1)

- `grug_xp:level` per §2.1, in `grug_xp/init.lua` (`set_xp`, the join
  handler). Nothing else in `grug_xp` changes.
- `grug_visuals:appearance` per §3, built from `player_spec` and the apply
  result, written in `grug_visuals.apply` only when the key changes. The
  cloak texture comes from the registered cloak source and the cloak id
  from `grug_achievements`' selection; the enchant channels from the worn
  pieces' affixes. Mainhand and offhand read the slot items
  (`get_cosmetic_weapon`, `get_cosmetic_offhand`), never the wielded item,
  and carry the pose `pose_for` gives and their drawn image. A change of
  either hand slot (item, broken state, enchant) must update the entry,
  although the offhand is not part of the in-game appearance key today.
- `APPEARANCE_VERSION`, `APPEARANCE_TEXTURE_MAX` (§3).
- The module-guide section (§2.3) with all five keys: `grug_factions:faction`,
  `grug_classes:race`, `grug_classes:class`, `grug_xp:level`,
  `grug_visuals:appearance` — their values checked against the code. It
  owns the appearance format (§3) and links `tools/web_data/README.md` for
  the export.
- Fixture: the level key on XP changes, on join and at the level-60 cap;
  the appearance JSON for empty, full, broken, enchanted, Scout and
  shield/spellbook loadouts; no write when nothing changed; the wielded item
  never appears; every composed string within the cap and the closed sets.

### 4.2 WE Exporter (wave 1, final wiring after WM)

The exporter prints: the schema and appearance versions; the level start
table; class, race and faction ids with display names, faction colours and
class icon paths; the race visual sizes; the model file name and its
animation frame ranges (stand, walk, from `player_api`); the pose → wield
transform table (`wield_geometry.lua`); for every item that can sit in a
hand slot its wield image (falling back to the inventory image) and wield
scale; the closed modifier set, the PNG directories and file names, and
`APPEARANCE_TEXTURE_MAX`. Optional: display name and inventory image of
every equippable item.

The item data (hand items, the optional full list) needs the item
registrations of `grug_gear` and its dependencies. Pick the route first:
LuaJIT with stubs if it loads cleanly, otherwise a probe mod run in a
headless Luanti (§3, tools are free) that dumps the registered items. Only
if neither works does the lane stop with `## Blockers / questions`; the
optional full list is dropped before anything else.

A test regenerates the export, validates the JSON's shape and checks that
the committed `web_data.json` is current. `tools/web_data/README.md` explains
the output for the website (English).

### 4.3 WG Player model as glTF (wave 1)

Convert `mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d` to
`grug_visuals_character.glb`: mesh with both buffers (body and cloak, two
materials in the model's texture order), the skeleton including the `Cloak`
bone, skinning, and the stand animation; walk too if cheap. First route:
`assimp` (installed; B3D in, glb out) — its B3D animation import must be
proven by the test, not assumed. If it gets the skeleton or the animation
wrong, the fallbacks are a script on the B3D reader in
`tools/r33_c3/gen_cloak_model.py` or Blender 5.2 with a B3D import add-on;
if the fallback becomes very laborious, the lane asks the user (§3). One
option the user named for that case: a static glb first (mesh, skeleton,
cloak, rest pose, no animation), with the animation left to the website's
own JavaScript — the user decides; the lane does not pick it alone. The
conversion command lives in `tools/web_data/model/` so it can be rerun. A
stock glTF loader must be able to load the result.

The test compares the `.glb` with the `.b3d`: bone names and hierarchy,
frame ranges, vertex and triangle counts, the UVs, and the skinned bounding
box per frame of every exported animation within a small tolerance.
Attribution: CC BY-SA 3.0, as in `grug_visuals/LICENSE-media.md` (Round 33
section), recorded next to the file.

Loading in Luanti: a headless server does not decode meshes, so this is a
GUI check. The lane adds a tiny probe mod under `tools/web_data/model/`
(not in `mods/`) that the user can enable once in a test world: one chat
command spawns an entity with the `.glb`, the composed skin of the caller,
and plays stand and walk (Luanti loads glTF since 5.10).

### 4.4 D Round documentation (wave 2)

Completion section here (what shipped, numbers, deviations, the GUI
checklist), STATUS, CHANGELOG 0.39.0 (one line: data for realm websites, no
gameplay change), `game.conf` 0.39.0, `tools/README.md` (`tools/web_data/`),
AGENTS.md status pointer. The commit that introduces the level key goes in
the completion; the coordinator reports it to the website.

## 5. Rules

- AGENTS.md and the [round workflow](../process/round-workflow.md) apply:
  own worktrees under `.claude/worktrees/`, Lua runs through the queue
  (8 processes at most), never the user's personal Luanti folder, an
  independent review per lane.
- No gameplay change. Appearance, wield and HUD behaviour stay as they are;
  WM only adds writes.
- Player-meta writes stay cheap: the appearance is written only on a real
  change, never per poll.
- The contract keys are not renamed; anything the website reads is
  documented in its owner (§2.3).

## 6. Verification

Per lane: the gates of the round workflow §3 (`check_lua.sh` on changed
Lua, `validate.py --game`, `check_fresh_server.py`, the lane fixture,
`run_fixtures.sh`, one smoke boot). Round end on main: all fixtures, the
exporter's `--check`, the model test, a boot, sync.

GUI checklist (the user; an existing test world is enough):

1. The character looks unchanged after join, after equipping and removing
   armour, a broken piece, an enchanted piece, and a cloak change.
2. The glTF probe: enable the probe mod, spawn the model, see the body,
   the cloak and the stand and walk animations.

## 7. Orchestration notes (for the coordinator)

- Start state: main `acdf0dea` (Round 38 complete, not pushed).
- Round folder `~/projects/grudgelands-orchestration/r39/`: common brief,
  lane briefs, the queue.
- Process budget: WM and WE need a few LuaJIT runs and one boot each; WG
  is Python and LuaJIT only. Well inside 8.
- Shared files: none between WM, WE and WG. WE reads WM's constants: it
  resumes on top of the reviewed WM branch, and WM and WE land on main
  together, so no commit carries `grug_xp:level` without
  `tools/web_data/web_data.json` (the website's support rule: a commit
  supports level and preview exactly when that file exists).
- After merge: report the level-key commit and the round's state to the
  website (the coordinator drafts the message; the user sends it). The
  website builds against §3 meanwhile and fetches the result after the
  user's push.
- Format deviations found during the round (a renamed field, a cap value,
  a dropped optional part, the model route) are collected for that
  message.
