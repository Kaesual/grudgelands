# Round 54 — armor redesign in the game (0.54.0)

Coordinator: Claude, 2026-10-20. Status: **running** since the user's go (2026-10-20); CONTRACT committed with
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
