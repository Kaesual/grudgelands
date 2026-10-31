# Round 68 — readable text in the world: signs, wayposts, notice boards, chest labels

Planned with the user on 2026-10-31 from their wish after Round 67's GUI
acceptance; started on the user's "go" the same day. Claude coordinates.
**Complete on 2026-10-31:** all three lanes merged (TEXT and SIGNS each
reviewed MERGE without a fix round; the art study ART checked by the
coordinator); after the merges the user dropped the hover text
([follow-up](#follow-up-after-the-merges-2026-10-31)) and picked wood set B
with the notice board in two halves
([follow-up](#follow-up-wood-set-b-and-the-board-in-two-halves-2026-10-31)),
then new icons for bars, settings, gems and their blocks, with the metal
stairs and slabs following
([follow-up](#follow-up-the-picked-bar-setting-gem-and-block-icons-2026-10-31)).
GUI-accepted by the user on 2026-10-31 (the whole checklist) and pushed
([completion](#completion-2026-10-31)).
Version: **0.68.0**. Classification: **compatible** (new nodes; the text
of existing signs and chest labels is already in node metadata; the text
entities are not saved). Delivery state: [STATUS](../STATUS.md).

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
   hover text stays. *(Superseded by the user on 2026-10-31: no hover
   text; see the [follow-up](#follow-up-after-the-merges-2026-10-31).)*
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

Written by lane D from the lanes' excerpts and the reviewers' notes. Each
item on the desktop client and on the web client. Items marked *look* ask
for the user's verdict on a first-look default.

**Wall signs and chest labels (TEXT)**

1. **Wall signs on a wall,** the Wooden Sign and the iron sign: write,
   rewrite, clear and dig. The text stands on the board in dark ink, 4
   lines of 15 characters, wrapped at spaces, a word longer than a line
   broken inside, what does not fit cut off; pointing at the sign shows
   no hover text (the user, 2026-10-31). Digging leaves no text behind. *Look:* the calm boards (ART pass 2; the
   wooden one in wood set B, [follow-up](#follow-up-wood-set-b-and-the-board-in-two-halves-2026-10-31)) and the
   glyph size.
2. **Wall signs on the floor and the ceiling:** the text lies on the
   board; it reads upright only for a reader facing +z (north), from the
   other sides it is turned (the vendored sign has no vertical wallmounted
   rotation). On the ceiling it reads looking up. *Look:* acceptable?
3. **Characters:** umlauts, accents, Cyrillic and Greek show; a character
   the font lacks (also ï, Ï, ű, Ű and љ, missing upstream) shows the
   placeholder glyph.
4. **Chest labels,** every tier (Chest, Steel-Reinforced, Abyssal), normal
   and locked: the label shows on the front below the lock, 3 lines of 13
   characters; opening and closing the lid keeps it in place; Upgrade
   keeps it (the ink turns light on the metal tiers); clearing or digging
   removes it. Pointing at the chest shows only its name (a locked chest's
   with its owner), never the label. The user ruled the labels stay as they are (three lines, no
   label plate), so this checks only that they work.

**The new signs (SIGNS)**

5. **Recipes** (Basic, known from the start): Standing Sign and Waypost
   from 1 Wooden Sign and 1 stick, Notice Board from 2 and 2. The icons at
   16 and 32 px. Help → "Bags, food and repair" names the signs.
6. **Standing Sign:** placed at several angles it faces you (any angle,
   1.5° steps); 4 lines of 15 characters; the selection box covers the
   board at every angle.
7. **Waypost:** the arrow points the way you look (so you first see it
   edge-on); 14 characters, on both sides, the back not mirrored; three
   wayposts stacked by clicking the top one (no sneak needed), at
   different angles: the pole joins, the arrow clearance, each text on its
   arrow. *Look:* the direction rule and the walkable post.
8. **Notice Board:** the left half goes where you point, the board to
   your right; it turns in four steps; 7 lines of 30 characters. Pointing
   at either half shows no hover text. Selection and
   collision on both halves; it is walkable. Digging either half shows the
   cracks on that half; the two halves join without a seam, front, back
   and at an angle, at all four turns. *Look:* four steps instead of
   free rotation; the warm wood (set B) beside a wooden chest and planks.
9. **Refused board:** next to a block, under a low ceiling (the two nodes
   above must be free) or over a gap (solid ground under both halves): a
   notice says why; reaching into someone else's claim: the claim's
   refusal. Nothing is placed and the item stays in the hand.
10. **Digging and support:** digging either half of the board removes both,
    drops one Notice Board and leaves no text; dig the node under a
    standing sign, a waypost or either half of a board: it drops as an item
    (one Notice Board, no half left standing) and its text goes.
11. **Writing:** each form is sized to its sign (a text box, a single field
    on the waypost); write, rewrite, newlines, clear; a text over 512
    bytes is refused with a notice.

**Everywhere**

12. **Claims:** in someone else's claim every sign's text and every chest
    label is readable; Save on a sign is refused, a chest label needs the
    Everything right, a locked chest only its owner.
13. **Rejoin and distance:** leave and rejoin, or walk far away and come
    back: every text returns (the LBM), none doubled; digging a sign after
    the rejoin still removes its text. A sign or chest label written before
    this follow-up (0.67.0, or an earlier 0.68.0 build) shows its text but
    no hover text once its area has loaded.
14. **Crisp text** *(look)*: nearby and from a few metres, in daylight and
    indoors, the same glyph size on every surface.
15. **Web:** the texts are visible and crisp; time the join with the 431
    new glyph files (compare with 0.67.0).

**Icons (follow-up INSTALL)**

16. **Bars, settings and gems in the inventory,** at 16 and 32 px (a bag
    slot and the hotbar; GUI scale 1 and 2): each of the ten bars, the six
    settings, the six rough and six cut gems, Quartz and Abyssal Crystal
    reads as itself; Garnet and Ruby apart, rough and cut apart, Quartz and
    Diamond apart; no setting looks like a gold bar. *Look:* the picked
    family beside the tools and gear.
17. **The block walls:** place the ten metal blocks and the seven gem and
    crystal blocks side by side and a 3 x 3 patch of one: the faces tile
    without seams, each block reads as its material; the Emberglass block
    keeps its old look. Beside each of the five metal blocks (Iron, Tin,
    Copper, Bronze, Gold) its stair, inner and outer stair and slab show
    the same face, lined up with the block.

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

## Completion (2026-10-31)

All three lanes are merged on main. TEXT and SIGNS were each reviewed
independently (Opus): both **MERGE**, no fix round. The art study ART
(GPT-6 Astra; tools only) was checked by the coordinator
(`generate.py --check`); its picked files were copied into TEXT (the wall
sign boards) and SIGNS (models, textures and icons), whose reviews checked
them byte for byte. This lane D (the completion, the GUI checklist, the
status owners) follows on main `0fb2ab7f`. **0.68.0 is compatible:** TEXT
reads the existing node meta `text` (wall signs) and `grug_label` (chest
labels) and writes no new state; its text entities are not saved and an
LBM recreates them (proved with two boots on one world: a sign and a label
written as meta only got their 2 entities, the hover text intact); ART adds
tools only; SIGNS adds new nodes with the meta `text` (their `infotext`
was dropped by the [follow-up](#follow-up-after-the-merges-2026-10-31)). No
map reset, no step. **Push:** pushed on 2026-10-31 after the GUI acceptance; production
runs 0.65.0, so its update still runs only the 0.67.0 step. **GUI test:**
the user accepted the whole [checklist](#gui-checklist-desktop-and-web)
on 2026-10-31.
**Sync:** by the coordinator after each merge.

### Lanes

Main's first-parent commits from the plan `b649e707` (lane tip in
brackets), in merge order:

| Lane | Commit | What | Review |
|---|---|---|---|
| TEXT | `5c482606` (`67e3239c`; `7029207f` … `67e3239c`) | New CORE mod `grug_text`: `layout.lua` (wrapping at spaces, a long word broken inside, newlines, cut-off; the `[combine` texture tinted by `[multiply:<ink>`; 1 glyph pixel = 1/128 node, 6 × 12 px cells, canvases in powers of two), `init.lua` (`register`, `refresh`, `remove`; one unsaved `upright_sprite` per written surface, the LBM `grug_text:restore`), `surfaces.lua` (both wall signs 4 × 15 in every wallmounted orientation through an override of their form handler; every chest tier, normal, locked, closed and open, 3 × 13 below the lock). The CC0 font imported by `tools/r68_text/import_font.py` (431 files, 506 characters). One GRUG PATCH in `default/containers.lua` `update_infotext`. ART's calm wall sign boards swapped in, ink `#2B1E14` on both; light ink `#ECE4CC` on the two metal chest tiers. 0.68.0 in `game.conf` and `upgrade.json`. Module guide "Text in the world", mod map, `inventory_equipment.md`, VENDOR, licences, CREDITS; fixture `tools/r68_text` (132 checks), capture and LBM probes | MERGE (notes only: floor and ceiling signs read upright from +z only, checklist item 2; `register` wraps `after_destruct` at call time, SIGNS told; chest label readability, to the user) |
| ART | `48a23459` (`2f55d57e`; `c421b445` … `2f55d57e`) | GPT-6 Astra's study in `tools/r68_art/`: standing sign, waypost and notice board in two variants each (OBJ, 64 × 64 atlas, 16 px icon, text-area JSON), offline preview, the user's pick A/B/B; pass 2 the calm wall sign boards (wood `#B68357`, iron `#AAAAAA`, both with ink `#2B1E14`); generator, licence rows, `REPORT.md` | coordinator check (`generate.py --check`, 72 outputs) |
| SIGNS | `0fb2ab7f` (`9b4a88ec`; `b010da60` … `9b4a88ec`, started from TEXT's branch, main merged in) | New ITEMS mod `grug_signs`: `standing_sign` (degrotate, faces the placer, 4 × 15), `waypost` (degrotate, the arrow along the placer's look, 1 × 14 as two one-faced surfaces, walkable post so wayposts stack, stacking by clicking the top), `notice_board` + `notice_board_part` (4dir, two nodes placed and dug as one, refused unless both nodes and the two above are free and unprotected over walkable ground, 7 × 30 on the board node); every node `attached_node = 3`; forms sized to the grid with the wall sign's rules (`grug_signs.write`); ART's picks byte for byte. Recipes through `tools/r45_rg/edits.lua` (240 catalog rows), the four nodes in the claim reading exemption (`interaction.lua`), the Help line. Module guide, mod map; fixture `tools/r68_signs` (266 checks), capture and probe; pins in `r35_f` and `r57_dyes` | MERGE (backlog notes only; agrees with the 4 steps and the walkable waypost) |
| D | this section | the completion, the GUI checklist, STATUS, AGENTS, BACKLOG, README, CHANGELOG, the no-step line of the upgrade contract (the version and declaration were set by TEXT) | independent review |

Main has **299** portable fixtures (2 new: `r68_text`, `r68_signs`).
`mods/` against the plan commit (measured, `git diff b649e707 0fb2ab7f --
mods`): 456 files, +2722 −2 lines: 8 Lua files (one vendored,
`default/containers.lua`), 439 PNGs (431 glyphs, two wall sign boards,
three sign textures and three icons), 3 OBJ models, the character table,
two `mod.conf` and three media ledgers.

### Decisions during the round

**The user:**

- **Art pick:** standing sign **A** (plain plank on a slim post), waypost
  **B** (carved arrow), notice board **B** (with a roof).
- **Wall sign boards:** the text was hard to read on the old boards (their
  painted fake writing); ART's pass 2 drew calm boards for wood and iron,
  approved by the user and swapped in by TEXT.
- **Chest labels** stay as they are: three lines, no label plate, no
  change (TEXT's question about the busy metal fronts).
- **Glyph files:** keep the 431 files (no atlas: an atlas would roughly
  triple the texture string); the web join time goes into the GUI
  checklist (item 15).

**The coordinator** (answers to lane questions; each built as stated):

- SIGNS started from TEXT's branch before TEXT's merge, then merged main
  before its review; its callbacks are defined before `grug_text.register`
  (which wraps `after_destruct` at call time).
- Dark ink `#2B1E14` on both wall signs (the iron board is light grey).
- Light ink stays on the Steel-Reinforced and Abyssal chests.
- The notice board turns in 4 steps; the waypost's arrow follows the
  placer's look; the waypost's post is walkable so wayposts stack (the
  user informed).

### Deviations from the plan

- **Ink on iron:** §2 planned light ink on the iron sign; ART's board is
  light grey, so both wall signs use the dark ink `#2B1E14`.
- **Board rotation:** 4 steps (`4dir`) instead of free rotation: a
  two-node board stays on the grid. The standing sign and the waypost turn
  freely (`degrotate`, 1.5°).
- **VoxeLibre's facing convention** (the sprite's forward into the wall)
  is refuted for one-faced sprites: it works there only because one
  texture covers both faces. A one-faced sprite needs forward = −look
  (TEXT; found by the first capture, pinned by the fixture). The waypost
  therefore uses two one-faced surfaces, not one two-faced sprite.
- **The engine's OBJ loader mirrors x** (`irr/src/COBJMeshFileLoader.cpp:314`):
  in the game each model is ART's spec mirrored in x; SIGNS writes its
  offsets in game coordinates and the fixture checks them against ART's
  JSON. The engine also never turns `fixed` boxes of a degrotate node, so
  the standing sign's and the waypost's selection boxes cover their sweep.
- **Five glyphs missing upstream:** the table rows for ï, Ï, ű, Ű and љ
  name files VoxeLibre does not ship; they show the placeholder glyph.
- **Help:** §3 asked for the building/housing section; Help has none, so
  the signs' line sits under "Bags, food and repair" beside the chests.

### Numbers worth keeping

From the lanes' reports (measured there).

- **Texture string length** (bytes; the engine caps a texture at 65,535):

  | Text | All cells filled | Prose | Upper bound |
  |---|---|---|---|
  | Wall sign 4 × 15 | 1,402 | 994 | 2,182 |
  | Chest label 3 × 13 | 930 | 628 | 1,437 |
  | Notice board 7 × 30 | 4,997 | 3,758 | 7,727 |

  The notice board with 7 full lines of real text in SIGNS' capture:
  **3,457 bytes** (fixture and engine agree).
- **Entities:** one per written surface, none for an empty sign or an
  unlabelled chest: TEXT's capture scene 22 entities for 22 written
  surfaces, SIGNS' 18 for 18; the LBM proof 2 for 2.
- **Font:** 431 glyph files, 38,302 bytes; 506 characters mapped
  (Latin-1 to Latin-4, Cyrillic, Greek).
- **Recipes:** the catalog has 240 rows (237 → 240).
- No new globalstep; text textures are built only when the text changes
  or the entity is created.

### Checks

- TEXT: `check_lua`, `check_fresh_server`, `check_upgrade`,
  `import_font.py --check`, `export.lua --check` PASS; fixtures `r68_text`
  and `r67_containers`; full run 297/298 (only `r37_dc`, waiting for this
  CHANGELOG entry); smoke boot and the two-boot LBM probe PASS; captures
  T1–T9. Review: `r68_text`, `r67_containers` PASS, captures inspected.
- ART: `generate.py --check` (72 outputs).
- SIGNS: `check_lua`, `check_fresh_server`, `check_upgrade`,
  `gen_basic_recipes --check`, `export.lua --check` PASS; fixtures
  `r68_signs` and `r45_rg`; full run 296 + 3 (`r35_f` and `r57_dyes` pins
  updated and passing, `r37_dc` waiting for this lane); smoke boot PASS;
  captures S1–S9. Review: `r68_signs`, `r45_rg`, `r35_f`, `r57_dyes` PASS.
- Main: `check_fresh_server.py` PASS after each merge. This lane:
  `check_upgrade.py`, `check_fresh_server.py`; `r37_dc` (the CHANGELOG's
  newest entry, the Help version line, README and CHANGELOG links),
  `r41_up`, `r42_dr` and `r43_gs` (the declaration, the README and
  CHANGELOG links); the link and anchor check of the touched documents.
  The round-end full run on main is the coordinator's.

### Follow-up after the merges (2026-10-31)

The user, after a first look: "When I aim the crosshair at a chest, its
text shows in the HUD at the top left. Same with the notice boards,
wayposts and signs. That is unnecessary, the text is on the chest now.
Remove this HUD text." This overrides ruling 1's "The hover text stays".

- **Signs:** the wall signs (GRUG PATCH in `default/nodes.lua`
  `register_sign`, the Iron Sign clone with it) and `grug_signs.write`
  (standing sign, waypost, notice board and its part) store only the meta
  `text`, no `infotext`.
- **Chests:** `default.containers.update_infotext` writes the chest's
  name (a locked chest's with its owner) without the label; it still
  refreshes the label on the front.
- **Old worlds:** two one-time LBMs (`run_at_every_load = false`) drop the
  stored hover text on the first load of each block saved before them:
  `grug_text:drop_hover_text` (`surfaces.lua`: both wall signs and every
  chest node; a labelled chest gets `update_infotext`) and
  `grug_signs:drop_hover_text` (its four nodes). Chosen over the
  every-load restore LBM: no per-load cost afterwards and no per-node
  hover rule in `grug_text`. Only player-written text carried hover text,
  and a block a player wrote in was active, so it has the timestamp the
  engine compares. **Still compatible**, folded into 0.68.0: no step, no
  version change; the engine records the two LBMs' introduction times in
  the world's `env_meta.txt`.
- **Fixtures:** `r68_text` (H: the vendored handler writes no
  `infotext`, a chest's hover text without its label, the LBM on old signs
  and chests), `r68_signs` (no hover text, the LBM on a sign and the
  board's part), `r67_containers` (its label checks).
- GUI checklist items 1, 4, 8 and 13 changed accordingly.

### Follow-up: wood set B and the board in two halves (2026-10-31)

The user picked ART's wood set B (warm heartwood) for every sign, its icon
and the wooden wall sign (copied byte for byte), and each notice board node
now draws its own half of the model (ART pass 4), so digging either half
shows cracks; the halves rejoin into the one-piece model at all four turns
(fixture `r68_signs`, headless front/angle capture). Losing the ground under
either half no longer drops two boards (the partner's neighbours are checked
from `after_destruct`). Still compatible: the part keeps its name, only its
drawtype changes. GUI checklist items 1, 8 and 10 changed accordingly.

### Follow-up: the picked bar, setting, gem and block icons (2026-10-31)

The 47 icons the user picked from lane ICONS (bars and metal blocks A,
settings B, gems D with the larger rough gems; `tools/r68_icons/`) are
installed byte for byte under the owning mods' prefixes
(`grug_materials_*.png`, `grug_artisans_setting_*.png`). Bars, metal
blocks, rough and cut gems, Quartz, Abyssal Crystal and the gem blocks
draw stored images named after their ids; a cut gem no longer brightens
its raw image, a gem block no longer tiles it. Silver lump, Emberglass and
its block, Anthracite, ore tiles, tools and gear keep their images.
`tools/r68_icons/generate.py` reads a pre-install snapshot of the two Lua
files (`tools/r68_icons/pre_install/`), so its comparison page and
INSTALL.md stay as picked. Fixture `r68_install` (the 47 ids, the byte
copies, nothing derived from the old vendored images, what keeps its
look); headless capture of the inventory slots and the block walls. Still
compatible: ids, recipes, drops, prices and saved state unchanged. GUI
checklist items 16 and 17 added.
Follow-up STAIRS: the 20 Iron, Tin, Copper, Bronze and Gold stairs, inner
and outer stairs and slabs take their faces from their canonical block
(`tiles_from` in `STORAGE_DERIVATIVES`), keeping the vendored tile settings;
fixture `r68_install` section S, capture scene `stairs`; compatible.
