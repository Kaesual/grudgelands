# Round 55 — offhand, back weapon and cloak wings in the model (0.55.0)

Coordinator: Claude, 2026-10-21. Status: **running** (the user's go 2026-10-21; CONTRACT committed with this plan).

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
