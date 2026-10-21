# Round 55 — offhand, back weapon and cloak wings in the model (0.55.0)

Coordinator: Claude, 2026-10-21. Status: **complete** ([completion](#completion-2026-10-21)); the user's go 2026-10-21, CONTRACT committed with this plan.

The user (2026-10-21): "Wäre es möglich, in einer kleinen Runde schon mal alles einzubauen und vorzubereiten, so dass
alles fertig ist, sobald Design und Posen-Positionen ausgearbeitet sind?" This round builds the whole pipeline with
placeholder shapes, parameters and test art. The look is still being designed on the preview page
([Offhand-Werkstatt](https://claude.ai/artifact/C4vmLYnNR5Mm5HG4LFv9Db); its generator is in the orchestration
folder `offhand/`). A short **finish step** (§7) then brings in the user's final parameters, pose angles and Astra's
textures. That step is the parameter file, the art run through this round's bake tool, and one setting, with no new
code.

Start state: main `abfb30ce` (0.54.1, pushed 2026-10-21).

## 1. Lanes and waves

| Wave | Lane | Who | Goal (one line) | Waits for |
|---|---|---|---|---|
| 0 | CONTRACT | coordinator | Commit the parameter file schema and values, the offhand atlas layout, baked file names, the format doc and the test art | the user's go |
| 1 | MODEL | Opus | Generate the player and NPC models with the two offhand bones, shield (3 sizes), book, back card and cloak wings from the parameter file; the `.glb` and its builder | CONTRACT |
| 1 | BAKE | Opus | `tools/r55_offhand/bake.py`: art → offhand atlas layers per tier, enchant masks and icons, `--check` | CONTRACT |
| 1 | GAME | Opus | Compose the new texture slots, the Scout's back weapon, appearance version 3, the setting, NPC lists, the wing source | CONTRACT; merges right after MODEL |
| 1 | PAGE | coordinator | Preview page: back card, export in the parameter file's format, a "from the model" view | CONTRACT (the model view after MODEL) |
| 2 | WEB | Opus | Appearance version 3 in the web export, version 2 rule, the kaesual handoff addendum | MODEL, GAME merged |
| 2 | D | Opus | Docs, CHANGELOG, version 0.55.0, STATUS, GUI checklist | everything else |

Every non-trivial lane gets an independent Opus review (§5).

## 2. The user's rulings (2026-10-21)

1. **Shield:** one shape, form B ("geschwungen": a heater shield with a vertical ridge and a two-step curve down to
   the point, 28 triangles), with the boss (4 triangles). It grows with the tier in small steps of one or two tiers,
   not six separate shapes.
2. **Spellbook:** one model, no scaling, **opened**. It lies in the left hand with its spine on the palm, pages tilted
   about 45° towards the head so that the character could read it. Its turn about the vertical axis is still being
   tuned.
3. **Two offhand bones**, `Offhand_Shield` and `Offhand_Book`, both children of `Arm_Left`. Each turns per pose clip
   and is rigid on the arm without a key. Example: Block −90° about x stands the shield upright in front of the chest.
   Two bones rather than one shared bone (decided after the plan review): six clips play for every class, and each
   item gets its own keys in all of them.
4. **Scout:** the weapon that is **not** in the hand hangs on the back as a flat 2D card showing the item's image.
   Added 2026-10-21 during the round: the card is in the model **twice**, on the cloak (shown when a cloak is worn)
   and on the back (shown otherwise); one 32 × 16 `back` texture picks the card by its half (format doc §3.3, §5).
5. **Cloak wings:** two optional triangular pieces on the cloak's sides, angled slightly towards the body (the cloak
   then reads as a trapezoid). They are meant for future premium cloaks. Normal cloaks stay exactly as they are.
6. Low poly with a little detail. Parameters and positions are tuned on the preview page. Textures and icons come later
   from Astra.
7. Three shield copies instead of a runtime bone scale (§3).
8. The answers to the first decisions, all as recommended:
   - **merge dark**, push with the finish;
   - a Scout holding anything else (a pickaxe, a torch) carries the **bow** on the back;
   - other classes: no back weapon now (backlog);
   - the NPC model carries the parts, and using them is a later choice;
   - **WEB in this round**.

## 3. Shared conventions (the contract, committed by CONTRACT before wave 1)

**The parameter file** `tools/r55_offhand/params.json` holds every number of the look, in the preview page's units
(skin pixels, degrees). The page exports exactly this format, and the finish step replaces the file and regenerates.

**Coordinate frames are fixed in the schema**, so tuning never has to be re-coded:
- every position and rotation is given in the **armor catalog frame at rest** (skin pixels, right-handed, x = the
  character's left, y up, z forward; [armor-format.md](../technical/armor-format.md) §1): one fixed frame for
  every bone, neither the page's glTF frame nor the B3D's left-handed bone frames (`Arm_Left`'s bind turns 180°
  about z). The format doc gives both conversions; the generator already maps the catalog frame with `to_model`;
- each rotation carries its Euler order.
- **Pivot:** the bone's pivot is an xyz point.
- **Each item** (shield, book, back card) has its own placement `{pos[3], rot[3], order}`, independent of the pivot.
- **Shield size:** stored as `{sizes[3], tier → step}`. The page's free six-entry map becomes three sizes and a tier
  table.

**The offhand bone's degrees of freedom** are fixed now, because they are the expensive part. Values on them are
cheap: a parameter file and a regeneration.
- **Per clip, per bone:**
  - a rotation about all three axes and a translation, either as one static key or as a short list of keyframes
    (frame → rotation, translation);
  - a **steadiness factor**: the generator cancels that fraction of `Arm_Left`'s swing **relative to the clip's
    mean frame**, not to the bind pose, so Block's raised arm stays raised while Walk's swing can be damped.
- **No scale keys:** the glb builder refuses them, and the three shield copies make them unnecessary.
- **Two bones** (§2 item 3), so the shared clips (Stand, Walk, Sit, Lay, Mine, Flinch) take separate keys for the
  shield and the book.

**Shield sizes without bone overrides:** the model carries the shield **three times**, at the size steps (draft
T1–T2 0.85, T3–T4 0.92, T5–T6 1.0), each in its own region of the offhand atlas. A shield's texture fills only the
region of its size, so the other two copies stay transparent: the same trick as the armor atlas. It also works where
bone overrides cannot reach: the Character tab's 3D view, NPCs and the website. The cost is about 190 vertices, a
number for comparison.

**Mesh buffers and texture slots**, one buffer per slot:

| Model | Slots, in order |
|---|---|
| Player | skin, cloak, armor atlas, weapon card, `offhand` (three shields and the book in one atlas), `back` (the back card, the item image), `wings` |
| NPC | skin, armor, weapon, `offhand`, `back` (no cloak bone, so no wings) |

An empty slot is `blank.png`; GAME measures the bytes of the texture string.

**Exclusive groups:** the three shield copies and the book never show together. The z-fight check skips pairs inside
such a group instead of failing on them (`gen_cloak_model.py` `zfight`, `KNOWN_ZFIGHT`).

**The format doc** `docs/technical/offhand-format.md`, the sister of
[armor-format.md](../technical/armor-format.md), covers:
- the atlas layout and the UV unwrap of shield and book;
- faces, orientation, zones A and B;
- the opaque rule (the book's pages and covers are solid, no cut-outs);
- the art directory Astra paints into;
- the **baked file names** (per tier and item, each with its `_ench.png` mask);
- the icons and their names.

The book's icon becomes one file per tier, not one image tinted per bracket. The registration in `grug_gear` then
names files, which GAME changes now (the files stay the old image until the finish).

**Test art:** flat region colours with zones A and B marked, in `tools/r55_offhand/test_art/`. BAKE's tests and the
shots bake it into a **test-only mod** in the shot world, never into `mods/`, so nothing of it ships.

**The setting:** `grug_offhand_visuals` (bool, default false, read at load).
- **Off:** compose writes `blank.png` into the new slots, and the setting is part of compose's cache key.
- **On:** used in the shot world and, after the finish, by default.
- Expected with it off:
  - players, NPCs and the web look like 0.54.1;
  - every armored NPC is redrawn once, because its digest changes;
  - after the sync the user's world stores version 3 appearances;
  - the Character tab's figure may shift or shrink, because hidden geometry counts in the engine's camera fit. MODEL
    reports the stand-frame bounding box before and after, and the user judges it.

## 4. Lane goals (briefs add file facts)

**CONTRACT (coordinator).** Commit the following:
- `tools/r55_offhand/` with `params.json`, taken from the user's current page values (shield form B with boss, the
  open book, the Block key);
- the schema above, the atlas layout and the baked file names;
- the test art;
- `docs/technical/offhand-format.md`.

The layout leaves room for an off-hand weapon card later (backlog). A reviewer checks it together with MODEL.

**MODEL.** Extend `tools/r33_c3/gen_cloak_model.py`, the player and the NPC model:
- **the bones `Offhand_Shield` and `Offhand_Book`** under `Arm_Left`. The generator keys every frame of every clip from the parameter file:
  identity where a clip has no entry, plus the steadiness. `make_poses` skips the new bone by itself; the Round 54
  lesson is that the generator keys its own bones.
- **shield ×3, book, back card on `Body`, wings on `Cloak`** (player only), in the buffers and with the UVs of the
  contract, and the exclusive groups for the z-fight check.
- **a `--check`** that the committed models equal the parameter file.
- **the `.glb`:** MODEL owns `tools/web_data/model/*`, which means `build_glb.py` (primitive list, materials that are
  **transparent by default** for the new primitives), `check_glb.py`, the regenerated `.glb` and its README table.
  AGENTS.md requires `build_glb.py --check` after any model change.

Reported numbers, not gated:
- vertices before and after;
- the stand-frame bounding box (for the Character tab);
- clearance per clip:
  - shield and book against the body and the 28 armor boxes;
  - the back card against the back armor and the cloak swing;
  - the wings against the arms and pauldrons.

Fixtures that pin the old counts: `r54_model` (872/848 vertices, buffer order).

**BAKE.** `tools/r55_offhand/bake.py`, modelled on `tools/r54_armor/bake.py`, takes an art directory in the contract's
layout and produces:
- per tier, the shield's layer in its size region of the offhand atlas, and the book's layer;
- each with its `_ench.png` mask (zone A = prefix, zone B = suffix, two frames as on armor);
- the shield and book icons per tier with their masks;
- a `--check` that the committed files equal what the art produces.

The lane runs on the test art and commits nothing to `mods/`; the finish step runs it on the picked art.
`gen_enchant_masks.py` stops covering the shield icons once `bake.py` produces them (at the finish).

**GAME.** In `grug_visuals`, plus the files named here:
- **Offhand slot:** the item in the offhand slot: a Warrior's shield into its size region, a Mage's or Priest's book.
  Enchant zones and the broken modifier work as on armor.
- **Scout:** the back card shows the weapon that is not in the hand:
  - a bow skill holds the bow, so the sword goes on the back;
  - Strike holds the sword, so the bow goes on the back;
  - for anything else the bow goes on the back.

  The hotbar poll must be able to write textures: today it only calls `sync_wield` (`apply.lua`), and the texture
  list is written only when `entry.key` changes, so the back image joins that key. The back card is **not** stored
  in the appearance (it would change the meta on every hotbar swap). Readers derive it from the stored slots: bow on
  the back unless a sword skill is held. The Character tab shows the bow on the back.
- **Wings:** an optional wing texture on a cloak. `grug_achievements`' cloak source returns it (today it returns only
  texture and id), and no cloak has one yet.
- **Appearance version 3:**
  - `textures.offhand` and `textures.wings`, added to the grammar;
  - the JSON size cap grows (`appearance.lua`, today 5×2048+2048);
  - the appearance's key and JSON compare are extended.
- **NPCs:** their texture lists get the two new slots, `blank.png` for now: `compose.lua`, `guard.lua`, `bandit.lua`
  and `bosses.lua` in grug_mobs, wherever a list is hard-coded. Their content digest includes them.
- **The setting** from §3. `register_model`'s texture list in `apply.lua` gets the new slots. `pages.lua` needs no
  change.

Fixtures:
- composition for every class and slot combination;
- the Scout's swap via the poll;
- the setting off, identical to 0.54.1 except for the new blank slots;
- the version 2 to version 3 upgrade.

Existing fixtures that pin the old counts: `r54_game` (4 textures, NPC 3, version 2), `r54_view` (4 textures) and
`r39_wm` (grammar, caps).

**PAGE (coordinator, outside the repo).** On the Offhand-Werkstatt:
- the back card (position, angle, the bow and sword images);
- the export in the parameter file's schema (game frame, Euler orders, three sizes);
- after MODEL's merge, a view that loads the generated `.glb`, so the user tunes on the page and checks the real
  model on the same page.

**WEB.**
- `web_data.json`: appearance version 3, the new texture files and the baked offhand file names.
- **Rule for version 2:** the same as version 3 with `offhand` and `wings` set to `none` (`tools/web_data/README.md`
  today leaves every other `v` undescribed).
- **The back card** derived from the slots, as in GAME.
- **An addendum** to `r54/kaesual-armor-handoff.md`: the new primitives (hidden or transparent until the site uses
  them), the slots, version 3, and that only Stand and Walk reach the `.glb`.

**D.** Docs and release:
- [character_visuals.md](../design/character_visuals.md) §4 and §5b (the offhand and back rules, the wings, first
  person shows neither shield nor book);
- the module guide (appearance version 3);
- the format doc linked from AGENTS.md's topic checks (`bake.py --check`, the model `--check`);
- CHANGELOG 0.55.0 (player-facing: nothing visible yet, so one line or none, the user decides), STATUS, BACKLOG;
- this plan's completion and the GUI checklist.

## 5. Rules

The usual ones:
- each lane works in its own worktree and branch;
- every non-trivial lane gets an independent Opus review, and a delta review for logic changes in a fix;
- the Lua queue `r45/lua_run.sh` runs at most 8 at once;
- nothing unpicked ships (the setting is off, and the test art stays in the test-only mod);
- the sync to the user's Luanti happens only after the round, via `tools/sync_to_luanti.sh`.

Fixtures: each lane runs only its own fixture plus the fixtures that test the behaviour it changes, and the full run
once before its report.

## 6. Verification

- **Gates:**
  - the full fixtures;
  - `check_fresh_server.py`;
  - `check_upgrade.py`;
  - the model `--check`s, `build_glb.py --check`, `check_glb.py` and `bake.py --check`;
  - one boot.
- **Headless shots** with the setting **on** and the test-only mod in a test world, saved to the orchestration folder
  (`r55/shots/`):
  - Warrior with a shield at T1, T3 and T6;
  - Mage with a book;
  - Scout with the bow in hand and with the sword in hand;
  - a test cloak with wings;
  - in Stand, Walk, Block, Cast and Sit;
  - plus the Character tab with the setting off and on.
- **GUI checklist** (D):
  - with the setting off, nothing has changed (an existing character, NPCs, the web); judge the Character tab's
    figure size;
  - with the setting on in a test world: the same shots as above. Clearance is judged by eye, and the numbers from
    MODEL's report are noted. First person shows neither shield nor book; that is expected.

## 7. Orchestration notes and open decisions

**One bone or two** (answered 2026-10-21: two). The plan review found that six clips play for every class (Stand,
Walk, Sit, Lay, Mine, Flinch); with one shared bone, a book steadied in Walk would have meant a steadied shield too.
Two bones cost the generator only.

**Merge order:** CONTRACT → MODEL and GAME **back to back** (between them, missing textures show as white shapes in
the Character tab and as repeated textures in the world) → BAKE (anytime after CONTRACT) → PAGE's model view → WEB →
D.

**The plan review** (fresh Opus, read-only, 2026-10-21) was applied:
- the blocker: no bake tool, which became lane BAKE and the contract's file names;
- 13 should-fixes, folded into §3 and §4: the Scout via the poll and not stored, merge back to back, the setting
  instead of a constant, the camera fit, transparent `.glb` primitives, NPC slots and files, steadiness relative to
  the clip, fixed frames in the schema, the z-fight groups, `.glb` ownership with MODEL, the version 2 rule, the
  fixture list, the wing source.

**The finish step** comes after the user's design work, as 0.55.1 or inside this round if the design is ready in
time:
1. The user's final values from the page go into `params.json`, and the models are regenerated. A reviewer checks the
   clearance report.
2. **ART (Astra):**
   - shield and book art per tier in the contract's layout, with zones A and B;
   - the icons;
   - optionally a first premium cloak with wings, if the user wants one;
   - a pick page as in Round 54.
3. `bake.py` runs on the picked art into `mods/`, licence rows are added, the setting's default turns on, and D writes
   the release.

## Completion (2026-10-21)

All code lanes are merged on main and independently reviewed (Opus); the art came from GPT-6 Astra in one drop
and the user's picks; this lane D (the setting on, this section, the docs and the status owners) follows on main
`47e1c98f`. **0.55.0 is compatible:** no migration step, item ids unchanged. Nothing in world generation changes.
**Push:** after the user's GUI test (accepted), 0.55.0 and 0.55.1 pushed together on 2026-10-21 (origin/main
`52996c44`); 0.55.1 deployed to production by the user. **Sync:** by the user after the round.

The finish step (§7) ran **inside this round** instead of as 0.55.1: the user's final params, Astra's picked art,
the Supporter Cloak and the setting's default (lane D) all ship in 0.55.0 (the user, option b: "release everything
together").

### Lanes

Worktrees and branches `r55-<lane>`. Main's first-parent commits, in order (lane tip in brackets):

| Lane | Commit | What | Review |
|---|---|---|---|
| CONTRACT | `cf7c6ce3`; fixes `57551665`, `bcfc243c`, `7e2df348`, `23ff2174`, `990fc9a5`, `8ef99b14`, `42ddeeab`, `1d4b930f`, `c6af0e14`, `dbd05bd3` | this plan, `tools/r55_offhand/` (`params.json`, `offhand.py`, `data/atlas.json`, test art), [offhand-format.md](../technical/offhand-format.md); fixes: the ribbon required; crossed shield texels opaque, zone faces, `wings_<id>.png`; two back cards; the wing hinge inset; `pages_b` the right page, 6 wing triangles; half-texel edge UVs; `cloak_<id>.png`; the open book closed at the spine; `icon_palette`; §7 the baked spellbook icons | coordinator (reviewed with MODEL) |
| BAKE | `8568017d` (`a2281f6d`), `b99c0b3a` (`7d708271`) | `tools/r55_offhand/bake.py` (art → offhand atlas layers, icons and masks per tier, `--check`), `test_bake.py`, `make_broken_art.py` and the broken set; then `test_bake.py` independent of `params.json` and `cloak_<id>.png` | MERGE AFTER FIXES (a blank sheet passed), delta reviews MERGE |
| MODEL | `283e8a43` (`d92f801c`) | `tools/r33_c3/gen_cloak_model.py` with `offhand_model.py`: the bones `Offhand_Shield` and `Offhand_Book` under `Arm_Left` keyed in every frame (player 485, NPC 221) with steadiness, three shield copies with boss, the open book, two back cards, wings; exclusive z-fight groups; `--check`; the 7-primitive `.glb`; `tools/r55_model` | MERGE (Low: the body card's z-fight, moved in the params commit; `entry_at` backlog) |
| params | `b88245aa`, `4fa0ab2e`, `93e6aad8` | the user's tuning from the Offhand-Werkstatt: shapes and Stand (body card z −3.55); the shield pivot and Block, the book in Cast 2; the book's placement and Block with a shift | coordinator (data only) |
| GAME | `6532a1c7` (`265bd4e5`) | `grug_visuals`: the offhand layer through `piece_layer`, the back card (the equipped weapon the hand does not show, 32 × 16 `[combine`, rewritten by the wield poll), the wings from the cloak source, the setting in compose's key, appearance version 3, 7 player and 5 NPC slots; `grug_mobs` lists; `tools/r55_game` (fixture, capture, 21 shots) | MERGE (README conflict and a comment fixed in the merge) |
| SUPPORTER | `a0b77cf9` (`1a05bfaf`) | `grug_achievements`: `manual = true` rows, `/achievement grant|revoke <player> <id>` (privilege `server`), the offline queue in mod storage, hidden until granted; `tools/r55_supporter` | MERGE, no findings |
| WEB | `cd218892` (`31671930`), wording `935179d0` | `offhand_look` in `web_data.json`, the version 2 rule, the back card rule for the site, the `.glb` docs, `tools/r55_web`; the kaesual addendum (outside the repo) | MERGE (wording fixed by the coordinator) |
| VIEWER | `78547e04` (`692bd483`) | `tools/r55_offhand/render.py` (the real b3d with the art, contact/detail/cloak sheets), `templates.py` and `templates/`, `test_render.py`; the book spine prototype behind `1d4b930f` | MERGE AFTER FIXES (partial `tiers.json`, README sizes, rim texels), delta MERGE |
| FINISH | `c23d8ceb` (`9172fe05`) | `tools/r55_art/` (the picked art, `assemble.py --check`); 24 offhand layers and 24 icons with masks baked into `grug_visuals` and `grug_gear` (untinted registration), the Supporter rows, cloak and wings, licences; `book_icons.py` retired; the Caster-offhand ghost the steel book | MERGE (old enchanted/broken stacks → STACKS) |
| STACKS | `47e1c98f` (`497c716b`) | `grug_gear`'s `initialize_weapon_tooltip` counts an image change, so old enchanted or broken shields and spellbooks take the current art at the next refresh; `tools/r55_stacks` | MERGE, no findings |
| D | this section | the setting on by default, the version 0.55.0, the design docs, AGENTS, STATUS, CHANGELOG, BACKLOG, ROADMAP, README; the stale templates regenerated | independent review (the setting as a logic delta) |

**PAGE** (coordinator, outside the repo): the
[Offhand-Werkstatt](https://claude.ai/artifact/C4vmLYnNR5Mm5HG4LFv9Db), the user's tuning page: the back card, the
export in `params.json`'s format (from v10 only the diff against the repo), the real model's primitives from the
`.glb`, per-pose shift sliders. **ART** (GPT-6 Astra, drop-01, outside the repo): two proposals, P1 "Standard &
Ledger" and P2 "Brace & Seal", 112 own CC0 PNGs including the icons (drawn freely, not adapted from the old
third-party icons), 0 bake violations. **PICK:** the [pick page](https://claude.ai/artifact/RmCbkJp9QJpjn5abBv2HS3).

**ICONS** (Opus, after lane D; branch `r55-icons`, art and bake `eb19cd65`): the user found the Round 54 armor
icons too detailed for pixel art and had all 72 redrawn simpler by GPT-6 Astra (outside the repo,
`armor-icons/`), with the new shield and spellbook icons as the model. Drop 01 drew all 72 in two proposals;
the user kept metal chest, metal legs and leather chest from its P1 and asked for the rest again: helmets must
read as helmets, boots as boots, and trousers need a trouser shape. Drop 02 redrew those nine rows in two
proposals, and the user picked whole rows (2026-10-21): metal head P1, metal feet P2, leather head P1, leather
legs P1, leather feet P2, cloth head P2, cloth chest P1, cloth legs P1, cloth feet P2. `tools/r54_art/` gained
both icon painters (`src/icons-*`), an `icons` section in `picks.json` and the icon step in `assemble.py`; only
the 72 icons in `art/` changed, the 144 baked icons and masks and the four slot ghosts follow (148 files,
28,170 → 26,827 B, measured), every baked file equal to Astra's own check bake. All CC0.

Main has 239 portable fixtures (5 new: `r55_model`, `r55_game`, `r55_supporter`, `r55_web`, `r55_stacks`) and the
Python tests `tools/r55_offhand/test_bake.py`, `test_render.py` and `tools/r55_model/test_frames.py`. `mods/`
against 0.54.1 (at lane D's last commit): +663 −128 lines in 16 text files (no new Lua file), 38 PNGs added
(11,364 B), 12 replaced (the shield icons and masks, 4,528 → 2,718 B), none removed, both models replaced
(measured, `git diff abfb30ce`).

### Decisions during the round

**The user** (HANDOVER):

- **Two back cards** (2026-10-21): on the cloak when one is worn, else on the back; one 32 × 16 `back` texture picks
  the card by its half (contract `7e2df348`).
- **The cloak/wing gap:** the wing's hinge sits inside the cloak by e = thick / 2 · sin(angle) + 0.05 px, thick at
  most 0.65 px (contract `23ff2174`).
- **A first premium cloak with wings**, granted by an admin: the name **Supporter Cloak** (not "Mantle of the First
  Road"); grant and revoke **only for manual achievements**, kept simple (no counter command, no revoke of earned
  ones).
- **The picks** (2026-10-21, `offhand-art/pick/picks-2026-10-21.json`): shields T1–T3 P2, T4–T6 P1; book paint P1
  except T3 P2, every book icon P2 (with its palette, `icon_palette`); the Supporter Cloak P1. The icons are
  simple pixel art, drawn freely (CC0).
- **The poses** (Offhand-Werkstatt exports): the shield pivot at y 14.5; Block and Block walking [84, −51, −8]
  (order XYZ) with the shift [−1, −2.25, 0]; the book in Cast 2 and Cast 2 walking [50, 0, 0]; the book's placement;
  "nothing more to tune".
- **Old enchanted or broken shields and spellbooks** (the FINISH review's finding): fixed (option b, lane STACKS).
- **Release everything together** as 0.55.0 with the finish (option b), no push before art, picks and poses.

**The coordinator** (answers to lane questions; each built as stated): the back card shows the equipped weapon the
hand does not show, also on the Character tab (the blade there, the bow on the weapon card) and on the website (the
site draws `slots.mainhand`); a Scout holding a bow item shows the blade; the body card at z −3.55 (no z-fight with
the bracers); the wing hem coplanar with the cloak hem accepted; `gen_enchant_masks.py` keeps the old shared
spellbook image (version 2 values name it); the Caster-offhand ghost is the steel spellbook icon; manual rows with a
faction refused; the revoke feed line "Achievement removed: X"; the offline queue keyed on the name.

### Deviations from the plan

- **The book spine** (VIEWER Q1): the contract's spine was the closed book's, which left a wedge open in the gutter;
  the spine became a plate behind the open halves and the page blocks keep their gutter faces (contract
  `1d4b930f`, 66 triangles).
- **The finish inside the round** (§7 allowed it), so the CHANGELOG describes the visible look, not "nothing
  visible yet".
- **Lanes the plan did not list:** VIEWER (the painter's render tool and templates, asked for by the user), SUPPORTER
  (the manual achievements), FINISH (the art into the game), STACKS (added after the FINISH review) and ICONS (the user's redrawn armor
  icons, two Astra drops).
- **The icons** were drawn freely by Astra (CC0) instead of adapting the old CC BY-SA shield and book icons; the old
  rows left the licence files and CREDITS credits Lord of the Test for bows only.
- **Lane D regenerated `tools/r55_offhand/templates/`**: `templates.py --check` had failed on main since `93e6aad8`
  moved the book (the hatching of `book_cover_f` and `book_pages_f`, 87 and 71 pixels).

### Numbers worth keeping

All measured unless marked.

| | before (0.54.1) | after (0.55.0) |
|---|---|---|
| Player model `grug_visuals_character.b3d` | 872 vertices / 436 triangles; 239,802 B | 1,240 / 618 (+ offhand 162 triangles, back 8, wings 12); 299,586 B |
| NPC model `grug_visuals_npc.b3d` | 848 / 424; 124,344 B | 1,180 / 590 (+ offhand 162, body card 4); 159,252 B |
| Web `.glb` | 88,900 B, 4 primitives | 120,440 B, 7 primitives (offhand, back and wings alpha 0 by default) |
| `tools/web_data/web_data.json` | 145,084 B | 151,196 B |
| Offhand files in `mods/` | — | 24 layers and masks in `grug_visuals` (8,401 B), 12 spellbook icons and masks (2,552 B), the Supporter cloak and wings (411 B) |
| Shield icons and masks (`grug_gear`) | 12 files, 4,528 B | 12 files, 2,718 B |

- **Texture bytes per player** (`r55_game` section M on compose's output, all seven slots; 0.54.1 → look off → look
  on): bare 342 → 369 → 369; Warrior metal T3 with a T3 shield 496 → 523 → 545 (offhand 31); Warrior T6 fully
  enchanted 1,977 → 2,004 → 2,224 (offhand 229); Warrior T6 enchanted and broken 2,180 → 2,207 → 2,456 (offhand 258,
  the worst offhand); Scout T5 with an enchanted bow 510 → 537 → 773 (back 245); the Scout worst case (a broken
  enchanted bow, a cloak) 2,159 → 2,186 → 2,457 (back 280). The Supporter wings 43 B. An armoured NPC 483 → 501.
- **Stored appearance** (version 3): the worst case 4,145 B (`r39_wm`, 1,037 outside the texture strings); caps
  2,048 per string and 7 × 2,048 + 2,048 = 16,384 for the JSON (12,288 before). The web test Warrior with an
  enchanted T6 shield 1,785 B, the Scout 1,328 B.
- **Runtime:** no new globalstep; the one-second wield poll costs one boolean test for everyone but a Scout with the
  look on, who adds one or two cosmetic hand reads and one string compare per second; a card change re-sends the
  seven-texture list at most once per second. An old shield or spellbook stack's refresh reads 4 more meta strings.
- **Clearance** (MODEL, skin px, negative = overlap, SAT lower bounds; first params): shields against the left bracer
  −0.97 / −0.87 / −0.76 standing; the final Block keys −0.36 to −0.57 against the bracer (as standing; `93e6aad8`); the
  book's worst −2.37 (a tasset in walk); the cloak card +0.37 from the cloak in every frame.
- **Stand-frame bounding box** (MODEL): x and y unchanged (±6.657, −0.262..17.194), z min −2.740 → −3.027 (the body
  card); the Character tab's figure size is the user's to judge.
- **Art in the repo:** `tools/r55_art/art` 58 files (56 PNG, 2 JSON), 20,144 B tracked; the painter templates 20 PNGs
  (VIEWER: about 505 KB). `bake.py` runs in about 0.05 s, `render.py` on the whole art directory in about 1.6 s.

### Classification

**Compatible**, no step:
`{"schema": 3, "version": "0.55.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0", "0.53.0"], "map_reset_pass": "0.50.0"}`.
A world on 0.54.1 moves on without a step. The setting turned on changes no format: every character is recomposed
once (the setting is in compose's key) and the version 3 appearance, already written with the setting off, now
names the offhand and wing files. Saved state read or written differently:

- player meta `grug_visuals:appearance` becomes version 3 (`textures.offhand`, `textures.wings`) at a player's next
  join; a version 2 value reads as version 3 with both `none`;
- armoured NPC staticdata: five textures and a new `_grug_visual_key` digest, so each saved NPC redraws once;
- stack meta of old enchanted or broken shields and spellbooks (`inventory_image`, `wield_image`,
  `_grug_broken_base_*`, `_grug_broken_drawn_*`) is rewritten to the current art at the next refresh (join,
  equipment or level change, `give`);
- new: player meta `grug_achievements:n:manual:<id>` and the existing tier, cloak and selection keys on a grant; mod
  storage `queue:<player>` for offline grants and revokes, removed at the join.

### Open notes

- **For the user:** the look with the setting on (below), the Character tab's figure size, the wings' size from
  behind, the shield's slight overlap with the bracer; the kaesual site after its update (the addendum
  `r55/kaesual-offhand-addendum.md` to pass on, `offhand_look.enabled` is now true).
- The contract doc's §1 still says only what "off" does; the coordinator may add "(on by default since 0.55.0)".
- The reviews' and reports' notes are in the [Round 55 carry-overs](../../BACKLOG.md#round-55-carry-overs).

### GUI checklist (Round 55)

Desktop and the web build, on the synced game. An existing 0.54.1 character first (with old enchanted and broken
shields and spellbooks), so its old appearance and stacks meet the new code.

1. **The look on (the default):** every character is redrawn once at its join; nothing else changes for a class
   without an offhand item.
2. **Shields T1, T3 and T6** on a Warrior, several races: the three sizes (T1–T2 small, T3–T4 middle, T5–T6 full),
   the face outwards, standing, walking, sitting; **Block** (Hold Ground, Unbroken) standing and walking: the
   shield upright in front of the chest, judged by eye against the armour (a slight overlap with the left bracer is
   known); enchanted (zone A and B colours) and broken.
3. **Spellbooks T1, T3 and T6** on a Mage and a Priest: open in the left hand, pages towards the head; **Cast 2**
   (frost and healing spells) standing and walking lifts it; enchanted and broken.
4. **The Scout's back card**, with and without a cloak (the card on the cloak, else on the body): a bow skill or the
   bow in hand puts the blade on the back; Strike, a pickaxe or a torch puts the bow there; the card follows the
   hotbar within about a second; a Scout without a bow shows no card; an **enchanted and a broken bow** on the back.
5. **The Supporter Cloak:** `/achievement grant <you> supporter` (privilege `server`): a feed line, the row in the
   Achievements tab, the cloak in the dropdown; worn, its **wings** standing and walking (judge their size from
   behind and at three-quarter); `/achievement revoke <you> supporter`: the row and the cloak go, a worn cloak falls
   back to No cloak; a grant to an **offline** character, then join as it: applied once; `/achievement grant <you>
   hunter`: refused; `/achievement grant <you> nope`: "Unknown achievement".
6. **Old stacks after the update:** an enchanted Iron and Embersteel shield, an enchanted spellbook and a broken
   enchanted shield from 0.54.1, in the bags and in the offhand slot: after the join they show the new icon with
   their enchant colours (no grey or red cast, no old book), the broken one cracked; also in the hand and on the
   Character tab.
7. **Icons:** the new shield and spellbook icons at 16 and 32 px in the inventory, shop and loot, plain, enchanted
   and broken; the Caster-offhand slot ghost (the darkened steel book).
8. **Character tab:** the shield or book on the figure, the wings, a Scout's bow on the weapon card with the blade
   on the back; judge the figure's size (hidden parts count in the engine's camera fit); the weapon card's image
   mirrored across its long axis (the user's fix of 2026-10-21: the bow's string and a staff's head point up, the
   grip stays in the fist).
9. **First person** shows neither shield nor book (expected).
10. **NPCs:** guards, bandits and kings look as in 0.54.1 (their offhand and back slots are empty), each redrawn once.
11. **The setting off** (`grug_offhand_visuals = false`, a restart): players, NPCs and the web look as in 0.54.1,
    apart from the new item icons; the Supporter Cloak without wings.
12. **Web:** before the kaesual update the site looks as in 0.54.x (the three new primitives are transparent); after
    it, the test characters of the addendum, a Warrior's shield, a caster's book, a Scout's card (the blade, as the
    site draws the bow in the hand) and the Supporter wings; a character not logged in since 0.54.x (version 2) shows
    no offhand; an old character's stored appearance shows the new offhand images after its join and the next
   export. `/glb_probe` still shows the `.glb` like the `.b3d`.
13. **Armor icons** (ICONS): the 72 new armor icons at 16 and 32 px in the inventory, shop and loot, plain,
    enchanted and broken; the Character tab's four empty-slot ghosts (the darkened metal T3 icons); the capital's
    product displays (Armorsmith, Tailor, Leatherworker) show the new chest icons.

### Round-end gates

Lane D on its branch from `47e1c98f`: `r37_dc` PASS, `check_upgrade.py` PASS (against origin/main `abfb30ce`,
0.54.1), `check_fresh_server.py` PASS, `export.lua --check` current, the offhand and armour topic checks PASS
(`templates.py --check` after the regeneration), the full `run_fixtures.sh` and one boot with the setting at its new
default (the lane report). Each code lane ran the full `run_fixtures.sh` once (BAKE 234/0, MODEL 235/0, GAME 236/0,
VIEWER 237/0, SUPPORTER 237/0, WEB 237/0, FINISH 238/0, STACKS 239/0). The round end on main (full fixtures,
`check_upgrade.py`, `check_fresh_server.py`, one boot, the sync) is the coordinator's.
