# Round 68 — readable text in the world: signs, wayposts, notice boards, chest labels

Planned with the user on 2026-10-31 from their wish after Round 67's GUI
acceptance; started on the user's "go" the same day. Claude coordinates.
Version: **0.68.0**. Expected classification: **compatible** (new nodes; the
text of existing signs and chest labels is already in node metadata).

## Why

The user's notes, checked against the code at `ecd035c0` while planning (the
lanes re-check them, round workflow §2.4):

- **Text is hover-only today.** The wall signs (`default:sign_wall_wood`,
  `grug_materials:iron_sign_wall`, a clone of the vendored steel sign) keep
  their text in meta `text` and show it only as `infotext`
  (`mods/BASE/default/nodes.lua` ~2618–2700). Round 67's chest labels
  (`default/containers.lua`, meta `grug_label`, 40 characters) are hover
  text too. Nothing renders text on a node face; there is no standing sign,
  no waypost and no notice board.
- **The engine cannot draw text on nodes.** The reference approach is
  VoxeLibre's `mcl_signs` (`reference_projects/VoxeLibre/mods/ITEMS/mcl_signs`,
  code MIT, font CC0, models GPLv3):
  - one PNG per glyph (`_a_.png` …, about 440, mapped in `characters.tsv`
    with their widths);
  - the text becomes one `[combine:WxH:x,y=glyph.png:…^[multiply:<colour>`
    string, built by the client and cached by name;
  - one non-pointable `upright_sprite` entity per sign in front of the
    board, yawed with it, restored by an LBM (`run_at_every_load`);
  - 4 lines × 15 characters on a sign, with word wrap;
  - standing signs rotate through `degrotate` (param2 × 1.5°).
- **Signs are exempt from the claim interaction guard for reading**
  (`grug_housing/interaction.lua` ~21–26); writing checks
  `core.is_protected` (`nodes.lua` ~2643).

## 1. Lanes and order

| Wave | Lane | Worktree / branch | Result | Depends on |
|---|---|---|---|---|
| 1 | TEXT — the text system, wall signs, chest labels | `r68-text` | A shared module that turns text into a texture and keeps one text entity per surface; wall signs and chest labels readable in the world | — |
| 1 | ART — standing sign, waypost, notice board (GPT-6 Astra) | `r68-art` | Models and textures for the three new sign kinds, with a preview page | — |
| 2 | SIGNS — standing sign, waypost, notice board | `r68-signs` | Three new placeable nodes with rotation and readable text, on TEXT's module | TEXT merged; ART's pick (placeholders until then) |
| 3 | D — delivery documentation | coordinator | Completion, version, status owners, GUI checklist | all merged |

Merge order: **TEXT, ART, SIGNS**, then D. SIGNS may start on TEXT's branch
state once TEXT's API is settled (the coordinator decides); it merges main
before its review.

## 2. The user's rulings (2026-10-31)

1. **Text is readable in the world** without aiming at it: wall signs, the
   new standing sign, wayposts, the notice board and chest labels. The
   hover text stays.
2. **Technique as VoxeLibre:** glyph textures combined into one texture per
   text, one text entity per surface.
3. **Font:** VoxeLibre's CC0 pixel font for this version (credited); a
   fantasy font of our own may come later.
4. **Wrapping everywhere:** break at spaces; a word longer than a line is
   broken inside the word; whatever does not fit is cut off.
5. **Chest labels** on the front's lower part (the part that does not move
   when the lid opens), **two or three lines**.
6. **Standing sign** on a post (new).
7. **Wayposts:** an arrow-shaped board on a post, placed by players at
   roads; readable without aiming. **Player-placed only**; mapgen wayposts
   come with the next change that needs a map reset anyway (BACKLOG,
   Round 67).
8. **A large standing sign** (notice board) for more text.

**Coordinator defaults** (the user may overrule them; look and feel is tuned
after the first in-game look):

- **Text sizes** (lines × characters, at one glyph scale so all surfaces
  look alike):
  - chest label 3 × ~13 (the label field keeps 40 characters; the face
    shows what fits);
  - wall sign and standing sign 4 × 15;
  - waypost 1 × ~14, on both sides (the back reads correctly, not
    mirrored);
  - notice board about 7 × 30.
- **Rotation:** standing sign, waypost and notice board turn freely like
  VoxeLibre (`degrotate`, or 16 steps if simpler; the lane reports which).
  Wayposts stack: one arrow per node, several nodes on top of each other
  form a post with several arrows.
- **Notice board** is two nodes wide, placed and dug as one (the bed's
  two-node pattern), refused where the second node does not fit.
- **Text colour:** dark ink on wood; light ink on the iron sign and on the
  Steel-Reinforced and Abyssal chests.
- **Rights:** writing as today's signs and Round 67's chest labels
  (`core.is_protected`; locked chests: the owner); reading is free.
- **Text entities are not saved** (`static_save = false`): an LBM and the
  node's construct/update paths recreate them, so no orphan entities stay
  behind; digging or swapping the node removes or moves its entity (chest
  open/close, chest upgrade).
- **Recipes** (Basic, through the generator; the price audit checks them):
  standing sign = 1 wall sign + 1 stick; waypost = 1 wall sign + 1 stick;
  notice board = 2 wall signs + 2 sticks.
- **Characters:** the font's set (Latin-1/2/3/4, Cyrillic, Greek);
  unsupported characters show a placeholder glyph.

## 3. Shared conventions

- English UI strings; Help's building/housing section names the new signs.
- No new sound.
- Performance: one entity per written surface only (empty signs and
  unlabelled chests have none); no per-step work; text textures are built
  only when the text changes or the entity is created.
- Vendored files change only with GRUG PATCH markers and a `VENDOR.md`
  entry; the font's and the reference code's credits go into the licence
  records.

## 4. Lane goals

### TEXT — the text system, wall signs, chest labels

A small shared module (a grug mod or `grug_core`): wrap text to N lines ×
M characters (ruling 4, UTF-8 aware), build the `[combine` texture from the
glyph set, create/update/remove one text entity per surface at a given
offset and yaw. Import the CC0 glyphs and the character table (credited).
Wall signs (both materials) show their text on the board, in every
wallmounted orientation (on walls, and lying on floors and under ceilings); chest labels on the front's lower part for every tier, normal
and locked, following open/close and upgrade. Fixtures: wrapping and
truncation, the texture string, entity offsets and yaw per orientation,
lifecycle (write, rewrite, clear, dig, swap). Report entity counts and the
texture string length for a full notice-board text.

### ART — standing sign, waypost, notice board (GPT-6 Astra)

Models (B3D or nodebox where enough) and textures for the standing sign
(board on a post), the waypost (arrow board on a post, stackable) and the
two-node notice board, in the vendored wooden-sign style; the text areas
marked so SIGNS can place the text entity. A preview page for the user's
pick.

### SIGNS — standing sign, waypost, notice board

The three nodes with placement, rotation, the two-node board, recipes,
writing forms (sized to each surface's lines), readable text through TEXT's
module, and drops. Placeholder art until ART's pick.

## 5. Rules

As Round 67 (round workflow, re-check first, sized fixture runs, headless
only through `tools/luanti_headless.sh`, stop and report).

## 6. Verification

Per lane: `check_lua.sh`, `check_fresh_server.py`, the lane fixture
`tools/r68_<lane>/portable_test.lua`, the full fixture run once, one smoke
boot, the upgrade classification, an independent review. One headless
capture per lane that renders text (wall sign, chest label, waypost, notice
board). The web build cannot run headless here: TEXT reports what could
differ there (texture string length, `[combine` support, the entity
visual), and the coordinator asks the user for an early look at a written
wall sign on the web client once TEXT has one.

### GUI checklist (desktop and web)

Written by lane D from the merged lanes.

## 7. Orchestration notes

- **Start state:** main `ecd035c0` (0.67.0 GUI-accepted; origin at
  `b73086ec`, the heraldry follow-up and status commits local until the
  user pushes).
- **Routing:** Claude coordinates, Opus implements and reviews, GPT-6 Astra
  the art lane (user's latest routing).
- **Shared files:** `mods/BASE/default/nodes.lua` (wall signs, TEXT),
  `default/containers.lua` (chest labels, TEXT), `grug_materials/registry.lua`
  (the iron sign clone), the recipe catalog (`tools/r45_rg/edits.lua`,
  SIGNS), `grug_housing/interaction.lua` (reading exemption for the new
  signs, SIGNS).
- **Open before the go:** none known; the defaults of §2 stand unless the
  user overrules them.
