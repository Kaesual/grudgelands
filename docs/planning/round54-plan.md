# Round 54 — armor redesign in the game (0.54.0)

Coordinator: Claude, 2026-10-20. Status: **complete** (2026-10-21, [completion](#completion-2026-10-21)), started
on the user's go (2026-10-20); CONTRACT committed with
this plan ([`tools/r54_armor/`](../../tools/r54_armor/README.md), [armor format](../technical/armor-format.md)).
Background, rulings so far and the design system: [armor redesign plan](armor-redesign-plan.md) (phases 1–3 done
or running outside the repo). The user (2026-10-20): "Lass uns das bitte als saubere Runde planen, mit parallelen
Lanes … du kannst schon anfangen, die neuen Rüstungen und den Viewer im Spiel umzusetzen, während Astra das Design
macht."

Start state: main `d18840a6` (0.53.1, not pushed; the user's GUI test of 0.53.0/0.53.1 is still open; 0.53.x is
pushed before or together with this round, on the user's word only).

## 1. Lanes and waves

| Wave | Lane | Who | Goal (one line) | Waits for |
|---|---|---|---|---|
| 0 | CONTRACT | coordinator | Commit the frozen contract to main: catalog, atlas layout, texture format doc, render/check tool, test art | the user's go |
| 1 | ART | GPT-6 Astra (outside the repo) | Paint the three lines: box sheets, inner paint, icons, two proposals per piece | CONTRACT |
| 1 | MODEL | Opus | Generate the player and NPC models with the armor buffer (UVs from the atlas), swing bones and the weapon card | CONTRACT |
| 1 | BAKE | Opus | Turn painted art (reference palette) into game textures per line, tier and slot, with enchant masks and icons | CONTRACT |
| 1 | GAME | Opus | Compose, apply and store the new armor; NPCs; leather T4 name | CONTRACT; merges after MODEL and BAKE |
| 1 | VIEW | Opus | The 3D view in the inventory's Character tab (and character creation) shows the new armor and the equipped weapon | CONTRACT; merges after GAME |
| 2 | WEB | Opus | Appearance version 2, the new `.glb`, the web export, the kaesual-stack handoff | MODEL, GAME merged |
| 2 | PICK | coordinator + user | Pick page on the 3D try-on from ART's proposals; ART pass 2 for whatever the user wants redone | ART pass 1 |
| 3 | INTEG | Opus | Bake the picked art into the game, remove the old armor media, licence rows | PICK final, BAKE, GAME |
| 3 | D | Opus | Design and technical docs, CHANGELOG, version 0.54.0, STATUS | everything else |

Every non-trivial lane gets an independent Opus review (§5). ART is reviewed by the user on the pick page and by the
tool's checks.

## 2. The user's rulings (2026-10-20)

Recorded in the [armor redesign plan](armor-redesign-plan.md) §2 and its phase results; the ones the lanes need:

1. Real low-poly shapes: one catalog of **28 boxes** (17 shapes, mirrored copies counted), hidden by texture alpha,
   all in one armor buffer with one atlas texture. Budget: player model ≤ 45 boxes.
2. **Every box is available on every tier**; the painter chooses per tier by design goals (metal bulkier with each
   tier, leather layered, cloth smooth and noble through ornament; metal > leather > cloth at the same tier).
3. Tier = box selection + paint variants + palette. Prefix colours zone A (cloth), suffix zone B (fittings).
4. Icons need only show the same intended piece; icon style rule (readable at 32/16 px).
5. The 3D view in the inventory's Character tab shows the new armor and preferably the equipped weapon (own lane
   VIEW).
6. The web export for kaesual-stack is updated, and the user passes our handoff to the kaesual agent.
7. Guards, kings and other armored NPCs use the same generated model, filtered to the boxes NPCs wear (no second
   model to maintain); unarmored humanoids keep `character.b3d`.
8. Leather T4 is renamed (scales belong to the top tier): display name **Hardened** (`Hardened Jerkin`, …); the
   item ids `…_leather_scaled` stay (compatibility), only the description changes (confirmed, §7).
9. **0.54.0, compatible**; ART starts with **metal as a pilot** (confirmed, §7).

## 3. Shared conventions (the contract, committed by CONTRACT before wave 1)

- **`tools/r54_armor/`** in the repo: `catalog.py` (the boxes, bones, rotations, mirror, texel sizes, slots;
  from the prototype), `atlas.py` (one deterministic packing of every box sheet into the armor atlas; MODEL, BAKE
  and GAME all read it), the render/check tool (`render.py` with a sandbox-safe software engine, `check.py`,
  templates), `test_art/` (synthetic art in the reference palette so every lane can work before ART delivers).
- **`docs/technical/armor-format.md`**: the texture contract (from `armor/spec/texture-format.md`): box sheets in
  the skin unwrap, the 13-colour reference palette, slot regions on the skin, zones, `tiers.json`.
- **Texture slots of a character** (in this order): `skin` (64×32, race look plus inner armor paint, as today),
  `cloak` (32×32, as today), `armor` (the atlas), `weapon` (the weapon card; transparent in the world).
- **Baked file names** (BAKE writes, GAME reads): per line, tier and slot an atlas layer
  `grug_armor_<line>_<grade>_<slot>.png` (full atlas size, only that slot's boxes painted, the rest transparent; a
  character's atlas is the four slot layers overlaid, like today's skin layers) and a skin layer
  `grug_armor_<line>_<grade>_<slot>_skin.png`, each with its `_ench.png` mask (zone A frame, zone B frame, as
  today's masks); icons
  `grug_gear_item_<slot>_<line>_<grade>.png` keep their names. Grades keep today's ids.
- **Preview seam** (GAME provides, VIEW consumes): `grug_visuals.preview(player)` returns `{mesh = ..., textures =
  {skin, cloak, armor, weapon}}` for `model[]`; VIEW develops against this signature before GAME merges.
- **Classification: compatible.** Item ids stay; the stored appearance gets version 2 and is rebuilt at login;
  no migration step.

## 4. Lane goals (briefs add file facts)

**CONTRACT (coordinator).** Move the frozen pieces from the orchestration folder into `tools/r54_armor/` (the
single copy of the tool from then on; ART runs it read-only from the main checkout), write
`docs/technical/armor-format.md`, add the atlas packing with a check and a `--palettes` option to the tool (so ART
can propose palettes in its drop), commit on main. No game code.

**ART (GPT-6 Astra).** Paint per line: box sheets, inner paint per slot, 16 px icons, the painter's `tiers.json`;
**two proposals per piece**, different in idea, not only colour. Own art (old sets may be looked at, never
copied). Self-check loop with `check.py` (0 violations) and the soft renderer (looks at its own contact sheets).
Works in `~/projects/grudgelands-orchestration/armor/art/`, never in the repo. Order: metal first (a pilot the
coordinator shows the user), then leather and cloth (§2 item 9).

**MODEL.** Extend `tools/r33_c3/gen_cloak_model.py` (or a successor in `tools/r54_armor/`) to append the armor
buffer from the catalog (every box rigid on its bone; the two panels on swing bones keyed from the legs: front 1.2×,
back 1.1× the leg angle + 0.06 rad, in every animation including the Round 40 pose clips; the cloak never swings
less than the back panel), and the weapon card (a two-sided quad on `Arm_Right` in the wield geometry of
`wield_geometry.lua`). Outputs: the player model (skin, cloak, armor, weapon), the NPC model (skin, armor, weapon;
boxes filtered by a list), `--check`, the clearance checks, and a z-fight check over all bones in the rest pose.
Frames up to 220 and the pose clip ranges stay unchanged.

**BAKE.** `tools/r54_armor/bake.py`: art (reference palette) + palettes + `tiers.json` + atlas → the baked files of
§3 for all 18 tiers, the enchant masks derived from zones A/B, the item icons (+ masks), `--check` (stale output
fails). Replaces `tools/r10_art/build_armor_assets.sh` and, for armor, `tools/r31_b/gen_enchant_masks.py`. Runs on
`test_art/` until INTEG.

**GAME.** `grug_visuals` composes the four textures from the worn pieces (skin layers onto the race look, the
slot atlas layers overlaid into the armor texture, enchant and broken layers on both), `apply.lua` sets the new model and
texture list for players and NPCs (guards, bandits, royal guards and kings, any `armor_line` spec), the stored
appearance becomes version 2 (armor and weapon texture added; byte caps re-measured), the leather T4 description
rename. Provides the preview seam of §3 (VIEW uses it). Works on BAKE's test
output; fixtures for compose and appearance.

**VIEW.** The 3D view in the inventory's Character tab (`grug_inventory/pages.lua`, `model[]`) and the character
creation preview (`grug_visuals/creation.lua`) show the new model with the armor atlas and the **equipped weapon**
on the weapon card (the main hand's image; an off-hand shield or spellbook only if it fits the card cleanly, else
reported). `model[]` has no bone overrides, so nothing may rely on them. Refreshes when gear changes, as today.
Checked in a real client screenshot (headless capture) for at least metal T6 with a sword and cloth T1 bare-handed.

**WEB.** `tools/web_data/`: export and `build_glb.py`/`check_glb.py` for the new model, the appearance version 2
in the module guide's contract section, how a stored version 1 appearance (a character that has not logged in
since the update) is exported and shown, and a handoff document for the kaesual-stack agent
(`~/projects/grudgelands-orchestration/r54/kaesual-armor-handoff.md`): what changed in the JSON, the new model, how
atlas and texture strings work, the weapon card, a test character JSON with a reference render.

**PICK (coordinator).** The try-on page loads ART's drops (3D, rotate, walk, races, mixed tiers, prefix/suffix);
per piece the user picks proposal 1 or 2 or asks for a redo; ART pass 2 on the redo list.

**INTEG.** Bake the picked art, ship it, remove the old armor media (`grug_visuals_<line>_<slot>_<grade>*.png`,
the old icons are replaced in place), licence rows (own art, CC0 like the other grug_gear icons), fixtures green.

**D.** `docs/design/character_visuals.md` (armor shapes, NPC model), `docs/design/items_crafting.md` (armor art,
the T4 name), `docs/technical/armor-format.md` links, CHANGELOG, version 0.54.0, STATUS, BACKLOG.

## 5. Rules

- The round common brief and review brief follow the [round workflow](../process/round-workflow.md) templates;
  every launch prompt carries the fixture sentence.
- Lanes MODEL, BAKE, GAME, VIEW, WEB, INTEG edit only their files; `tools/r54_armor/catalog.py` and `atlas.py` change
  only through the coordinator (they are the contract).
- Nothing unpicked ships: MODEL, BAKE and GAME may merge to main on test art, but the round is not finished (no
  GUI test, no push) before INTEG has replaced the test art with the picked art.
- Performance is reported as a comparison (vertex count, a headless boot), never as a target.

## 6. Verification

- Gates per lane and at the round end as in the workflow (§3 there), plus `gen_*_model.py --check`,
  `bake.py --check`, `check_glb.py`, the render tool's `check.py` on the shipped art.
- **GUI checklist** (written when the round is built): every line and tier worn by several races, walking and in
  poses; mixed tiers; prefix and suffix colours on every slot; broken pieces; the inventory preview with armor and
  weapon; guards, bandits and kings in a town; the cloak with back plates; the web character on kaesual (the user,
  after the kaesual agent's update).

## 7. Orchestration notes and answered questions

Start state, worktrees `r54-<lane>` from main after CONTRACT. Shared files and their owners:
`grug_visuals/compose.lua`, `apply.lua`, `appearance.lua` (GAME); `grug_inventory/pages.lua`,
`grug_visuals/creation.lua` (VIEW); `gen_cloak_model.py` (MODEL); `tools/web_data/` (WEB). Astra's brief and
drops live in `~/projects/grudgelands-orchestration/armor/` (`astra/`, `art/`).
Merge order: CONTRACT → MODEL → BAKE → GAME → VIEW → WEB → INTEG → D.

Answered by the user (2026-10-20):

1. **0.54.0, compatible.** Item ids stay; the stored appearance is rebuilt at a player's next login. Characters that
   do not log in keep their version 1 appearance in player meta, whose old armor textures no longer exist: WEB
   covers that case (the exporter and the kaesual handoff say how a version 1 appearance is shown, e.g. without
   armor until the next login).
2. **ART: metal first as a pilot** that the user reviews, then leather and cloth with what was learned.
3. **Leather T4 "Hardened"** with the item ids `…_leather_scaled` kept (the id then no longer matches the name; a
   comment at the grade table says why).
4. **0.53.x** stays unpushed until the user's GUI test; this round builds on 0.53.1 and does not depend on that
   test.

## Completion (2026-10-21)

All code lanes are merged on main and independently reviewed (Opus); the art came from GPT-6 Astra in three drops and
the user's picks; this lane D (this section, the design docs and the status owners) follows on main `8fbf9c09`.
**0.54.0 is compatible:** no migration step, item ids unchanged, the stored appearance becomes version 2 at a
player's next login. Nothing in world generation changes. **Push:** not pushed; origin/main stays at `e4d5c9d5`
(0.52.1); 0.53.0, 0.53.1 and 0.54.0 wait for the user's GUI test. **Sync:** on the user's word only after the round
is complete (no sync during the round).

### Lanes

Worktrees and branches `r54-<lane>`, from main `1733fbad` (wave 1) and `a278cc34` (WEB, INTEG). Main's
first-parent commits, in order:

| Lane | Commit (lane tip) | What | Review |
|---|---|---|---|
| CONTRACT | `8bc91967`, addenda `1733fbad`, `762186a2`, `9d4f4a1a`, `b3fa6eb2` | this plan, `tools/r54_armor/` (catalog, atlas, render/check tool with a pure-Python renderer, test art), [armor-format.md](../technical/armor-format.md); addenda: b3d handedness, `blank.png` for empty slots, the NPC model, the baked directory and mask format; armor opaque (only the helm's face window open); a tier names its palette, no example fallback; royal NPCs on the NPC model | coordinator (the contract) |
| BAKE | `62100720` (`e63514db`) | `tools/r54_armor/bake.py` (art + palettes + `tiers.json` + atlas → 72 atlas layers, 54 skin layers, their masks, with `--icons-out` the 72 icons and masks; `--check` compares mode, size and pixels) and `test_bake.py`; the test art baked in | MERGE (2 Low: licence wording, a palette per tier in the test; fixed) |
| MODEL | `6a8b4028` (`238ea9c9`) | `tools/r33_c3/gen_cloak_model.py`: the armor buffer (28 boxes), the swing bones `Panel_Front` and `Panel_Back`, the weapon card on `Arm_Right`, the NPC model `grug_visuals_npc.b3d`, clearance and z-fight checks; the cloak's rest 3° → 8.5°; `tools/r40_an/make_poses.py` bakes only the posed skeleton | MERGE AFTER FIXES (M1 `make_poses.py --check`; L1 main merge; L3 a cloak/back-panel gap gate), re-review MERGE |
| GAME | `a278cc34` (`5e8138af`); shots `5722b8fd` (`5fad3ab4`); no tint `7ed8ffce` (`816717c3`) | `grug_visuals`: compose returns skin, armor atlas and the texture list, every piece in its own parentheses with its enchant and broken layers; players `{skin, cloak, armor, weapon}`, armored NPCs the NPC model with `{skin, armor, weapon}`; the preview seam `grug_visuals.preview`; the NPC write guard by a content digest; appearance version 2; the royal armour (kings without a helmet), `armor_colors` (the War Commander's faction colours); leather T4 Hardened; no elite or rare tint on kings, royal guards and Generals (`_grug_no_tint`) | MERGE AFTER FIXES (Medium: the NPC guard compared inputs, not output; Low: stale comments; fixed), delta re-review MERGE; the no-tint delta reviewed MERGE |
| VIEW | `0a4fb774` (`89a6c673`) | the Character tab's `model[]` from the seam (skin, cloak, armor, the main hand's image on the card), the view `0,130`; character creation stays on `character.b3d` | MERGE (Low: a silent skip in fixture section E, fixed by the coordinator in the merge) |
| WEB | `a14d4420` (`da2b2f03`) | `tools/web_data/`: the four-primitive `.glb` and its docs, `appearance_v1` and `races[].bare_body` in the export (a version 1 body loses its armor parts and is shown without armor), `tools/r54_web/` (v1 samples from the old game, the fixture, the test character), the kaesual handoff outside the repo | MERGE (Low 1 and 2 → the follow-up WEB2) |
| INTEG | `8fbf9c09` (`610a97f7`) | `tools/r54_art/` (the picked art, the painters, `picks.json`, `assemble.py`, `ghosts.py`); baked into `grug_visuals` and `grug_gear`; 153 old worn files, 8 unsuffixed icons and `tools/r10_art/build_armor_assets.sh` removed; `gen_enchant_masks.py` without armour; the silversteel `^[hsl` gone; licence rows; `web_data.json` regenerated in the merge | MERGE (Low 1 and 2 → lane D) |
| D | this section | the version 0.54.0, the design docs, AGENTS (the armor checks, the Looks line), the `grug_gear` texture-source comment, STATUS, CHANGELOG, BACKLOG, ROADMAP, README | independent docs review |

**ART** (GPT-6 Astra, outside the repo): drop-01, the metal pilot (p1 "Bastion", p2 "Processional
guard"); drop-02, both redone opaque after the user's ruling; drop-03-leather (p1 "Trail coat", p2 "Toggle jerkin")
and drop-03-cloth (p1 "Cantor", p2 "Lamplighter"). Every proposal passed `check.py` with 0 violations and 0
warnings. **PICK:** the try-on page https://claude.ai/artifact/YFyg5Y1Q28xtomjXNaDL3G (3D, rotate, walk, races,
mixed tiers, prefix and suffix colours; four versions, the last one with all three lines); no piece was sent back,
so there was no ART pass 2.

Main has 233 portable fixtures (4 new: `r54_model`, `r54_game`, `r54_view`, `r54_web`) and the Python test
`tools/r54_armor/test_bake.py`. `mods/` against 0.53.1: +480 −220 lines in 18 text files (no new Lua file), 252
PNGs added, 161 removed, 148 replaced, the player model replaced and the NPC model added.

### Decisions during the round

**The user** (HANDOVER):

- **Armor is opaque**: transparent texels showed holes (one looks into the hollow box); only the helm's face window
  may stay open (the user's pick). Contract `762186a2`.
- **Kings, royal guards and Generals** use the NPC model and wear a royal variant of the guards' metal armour: zone A
  in the people's royal cloth colour, zone B gold (`ROYAL_GOLD` `#d8a838`), at the tier their level buys (T6 for all,
  levels 60 and 65); kings wear no helm, so crown and face show. They carry **no elite tint** (the user,
  2026-10-20, after GAME's shots: the gold muddied the royal colours).
- **The cloak** rests at 8.5° (was 3°), so the back panel never cuts it: accepted (shot K1).
- **The picks** (2026-10-20): metal T1–T5 "Bastion" (drop-02 p1), T6 "Processional guard" (drop-02 p2); leather
  all "Trail coat" (drop-03 p1); cloth all "Cantor" (drop-03 p1); no notes, no redo.
- **Sync** to the user's Luanti only after the round is complete.

**The coordinator** (answers to lane questions; each built as stated):

- The NPC model carries **every catalog box** (NPCs wear every tier); the baked files live in
  `grug_visuals/textures`.
- **War Commander:** royal-style zone colours from his faction's tabard (Accord zone A `#253d58`, zone B `#b99451`;
  Throng `#58262d`, `#cf9844`); his tabard stays as the skin layer under the chest box.
- **The ember zone tint** of two bandit kin (Coal-Purse Factor, Ash-Writ Bowman) colours the skin only, not the
  armour: left as it is.
- **Version 1 appearances** (characters that have not logged in since the update) are shown on the web without
  armour; a helmeted one shows bald until the next login (WEB Q1, accepted).
- **The Character tab** keeps today's model area with the view `0,130` (the user judges size and angle in the GUI
  test); **character creation** goes back to `character.b3d` with the race look alone (nothing is worn there, and the
  player model's wider bounding box would shrink the figure).
- **The slot ghosts** stay copies of the metal T3 (steel) icons (`ghosts.py`).
- **`bake.py`'s icons stay opt-in** (`--icons-out`): the gate for the shipped files is
  `bake.py --icons-out mods/ITEMS/grug_gear/textures --check` (AGENTS.md).
- MODEL's z-fight notes (`KNOWN_ZFIGHT`: the chest shell 0.13 px from the hat layer over a 0.88 px strip at the
  neck; the tasset's top corner against the arm) and the panel overlaps while sitting and in twisting walk poses are
  accepted.

### Deviations from the plan

- **BAKE merged before MODEL** (independent files; the plan's order was MODEL → BAKE).
- **MODEL and GAME merged back to back**, without a sync between: the four-buffer model with apply's old two
  textures makes the engine copy the cloak texture onto the armour and the card (`content_cao.cpp:817-833`).
- **ART took three drops** (pilot, opaque redo, leather and cloth), not two passes; the redo came from the opaque
  ruling, not from picks.
- **The contract changed four times during the round** (above), each by the coordinator.
- **Character creation** stays on `character.b3d` (plan §4 VIEW: the new model); the off-hand is not drawn on the
  card (it would need a second card).
- **The appearance stores no weapon texture**; the web reads `slots.mainhand.image`. The JSON cap went 10,240 →
  12,288 bytes (five strings).
- **WEB** proved the `.glb` with `tools/r54_model/capture.sh MODELS=` (the r39_wg probe is a GUI mod) and lists the
  version 1 armour files explicitly; INTEG found `gen_character_visuals.py` has no `--check` (gate: rerun, clean
  `git status`).
- A follow-up **WEB2** (Low 1 and 2 of the WEB review, a path note, the handoff shots re-rendered with the final art,
  `web_data.json` regenerated) runs after this lane; it touches only `tools/web_data/README.md`, `tools/r54_web/` and
  the handoff, and its merge triggers the post-merge status step.

### Numbers worth keeping

All measured unless marked.

| | before (0.53.1) | after (0.54.0) |
|---|---|---|
| Player model `grug_visuals_character.b3d` | 192 vertices / 96 triangles (skin 168, cloak 24); 165,659 B | 872 / 436 (+ armour 672, weapon card 8); 239,802 B |
| Armoured NPC | `character.b3d`, 168 vertices; 73,433 B | `grug_visuals_npc.b3d`, 848 vertices / 424 triangles; 124,344 B |
| Web `.glb` | 41,388 B | 88,900 B (4 primitives: 168, 24, 672, 8 vertices) |
| `tools/web_data/web_data.json` | 122,259 B | 145,084 B |
| Worn armour files (`grug_visuals`) | 153 files, 56,433 B (overlays, masks, helmet window) | 252 files, 70,882 B (72 atlas layers, 54 skin layers, a mask each) |
| Armour icons (`grug_gear`) | 156 files, 35,377 B | 148 files, 28,170 B (72 icons, 72 masks, 4 ghosts) |
| `mods/` (git-tracked bytes) | 67,459,300 B | 67,679,440 B |

- **Texture bytes per character** (all textures, GAME's fixture on compose's output): a bare player 324 → 342; a
  player in metal T3 417 → 496; the worst case 1,426 → 2,186 (skin 1,071, armour 1,062, cloak 44, weapon 9); an
  armoured NPC at T6 483; a royal guard 1,816; a king 1,720. INTEG changed no texture name, so these stand.
- **Stored appearance** worst case: body 1,164, armour 1,062, JSON 3,819 bytes (was 2,964); caps 2,048 per string
  and 12,288 for the JSON.
- **Character page** formspec 4,843–4,904 → 4,958–5,000 bytes (VIEW probe); the figure draws about 210 px tall in
  the tab (was about 340: the armour boxes and the card widen the bounding box `model[]` frames).
- **Swings** (MODEL `--report`, degrees): standing front 3.4, back 3.4–4.8, cloak 8.5–11.5; the walk cycle front up
  to 57.4, back and cloak up to 52.9 (the cloak walked to about 30 before); seated both panels 3.4, the cloak 35.
  Closest leg gaps (model units) standing 0.30 / 0.43 / 0.90, walking 0.14 / 0.14 / 0.90; tolerated overlaps in
  twisting walk poses: `swing_walk` −0.11, `bow_walk` −0.10, `charge_walk` −0.44 (about 0.8 px, the front panel's top
  corner in the thigh).
- **Art in the repo:** `tools/r54_art/art` 120,321 B (264 PNGs and 2 JSON), the painters 108,542 B. `bake.py` runs in
  well under a second, `assemble.py --check` in about 0.3 s.
- **Vertex skinning:** on Luanti ≥ 5.16 with OpenGL3 the GPU skins; older drivers skin every vertex on the CPU,
  hidden boxes included (872 instead of 192 per player; a comparison, not a target).

### Classification

**Compatible**, no step:
`{"schema": 3, "version": "0.54.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0", "0.53.0"], "map_reset_pass": "0.50.0"}`.
A world on 0.53.1 moves on without a step; one on 0.52.1 runs the 0.53.0 step first. Saved state read or written
differently:

- player meta `grug_visuals:appearance` becomes version 2 (the armour texture added), rewritten by the existing
  apply at a player's next join; a character who does not log in keeps version 1, which the web shows without
  armour;
- NPC staticdata: `_grug_visual_key` (the output digest) replaces `_grug_visual_skin`, so every saved armoured NPC
  (royals included) redraws once at its first activation;
- stack meta `grug_base_name` "Scaled X" becomes "Hardened X" at the stack's next rebuild (an equipment or level
  change);
- an enchanted silversteel metal armour stack keeps `…^[hsl:0:-90:5` in its `inventory_image` meta until its next
  refresh and shows slightly greyer until then (no error).

### Open notes

- **For the user:** the Character tab's figure size and angle, the cloak's new angle and the look of every line in
  the GUI test (below); the kaesual site after the kaesual agent's update.
- **WEB2** is still running (see Deviations); its merge after lane D gets the post-merge status step.
- The reviews' and reports' notes are in the [Round 54 carry-overs](../../BACKLOG.md#round-54-carry-overs).

### GUI checklist (Round 54)

Desktop and the web build, on the synced game, after the 0.53.0 migration and the
[Round 53](round53-plan.md#gui-checklist-round-53) and [0.53.1](round53-fix-plan.md#gui-checklist-0531)
checklists (one test). An existing character first, so its old appearance and stacks meet the new code.

1. **Every line and tier** (metal, leather, cloth, T1–T6) worn by several races, standing, walking and in the pose
   clips (cast, swing, block, charge, flinch): the shapes grow with the tier, metal bulkier than leather bulkier
   than cloth; the inner paint (sleeves, trousers, lower legs) shows under the boxes; no holes in the boxes.
2. **Helmets:** the hair is hidden under every helmet and the face shows through the face window; metal T1–T4 open,
   T5 and T6 closed (window painted over, visor in front).
3. **Mixed tiers and lines** (a metal chest with cloth legs, T1 boots with a T6 chest) and **prefix and suffix
   colours** on every slot: zone A (cloth) and zone B (fittings) of each enchanted piece, on its boxes and its inner
   paint, the neighbours untouched.
4. **A broken piece** darkened and cracked on its boxes and its inner paint only; repaired, its enchant colours
   return.
5. **Panels and cloak:** walking, the front and back panels swing away from the legs, never through them; the cloak
   hangs behind the back panel standing (about 8.5°, more than before, also without armour) and walking (out to about
   53–58°). Sitting: the panels hang down, the cloak lies over the seat. Known: a slight overlap of the front panel's
   top corner with the thigh in Charge on the move and in seated poses; pauldron, reinforcement and helm rim may touch
   the cloak's top, bracers and sleeves the panels.
6. **Character tab:** armour, cloak and the main hand's weapon on the card; the view updates on equip and unequip;
   the mouse turns the model. Judge the size (about 210 px, smaller than before) and the angle `0,130`; a sword at
   that angle reads shorter than in the hand; the Scout's bow shows; a shield or spellbook in the off-hand does not.
   Character creation: the race look on the plain model, unchanged.
7. **Icons:** hotbar and inventory at 16 px and 32 px for all 72 pieces; silversteel reads as bright neutral silver;
   enchanted and broken icons; an **old enchanted silversteel piece** refreshes its icon after an equipment change;
   the Character page's empty-slot ghosts (the metal steel icons, darkened); the Armorsmith, Tailor and
   Leatherworker plaques in a capital.
8. **Hardened:** a leather T4 item reads "Hardened …"; an old stack named "Scaled …" renames after the next equip
   or level-up.
9. **NPCs in a town and a camp:** guards in metal by level, bandits in cloth, vendors without armour; a king (crown
   and face, no helmet), royal guards and a fortress General in their people's royal colours and gold, **untinted**;
   the War Commanders in their faction's colours (Accord blue with brass, Throng red with gold-brown).
10. **Tints over armour:** an elite guard's gold and a rare's violet over the whole figure, armour included; the ember
    sub-types (Coal-Purse Factor, Ash-Writ Bowman) tinted on skin only.
11. **Web:** `/glb_probe` in a test world shows the `.glb` like the `.b3d` with armour and panels; after the kaesual
    agent's update, the site shows the test character like the handoff's renders and a not-yet-relogged character
    without armour.

### Round-end gates

Lane D on its branch from `8fbf9c09`: `r37_dc` PASS, `check_upgrade.py` PASS (against origin/main `e4d5c9d5`, 0.52.1,
and against `d18840a6`, 0.53.1), `check_fresh_server.py` PASS, `export.lua --check` current, the armour topic checks
PASS, the docs link check (the lane report), the full `run_fixtures.sh` 233/0 (once). Each code lane ran the full `run_fixtures.sh` once (BAKE 229/0, MODEL
230/0, GAME 231/0, VIEW 232/0, WEB 232/0, INTEG 231/0). The round end on main (full fixtures, `check_upgrade.py`,
`check_fresh_server.py`, one boot, the sync) is the coordinator's.
