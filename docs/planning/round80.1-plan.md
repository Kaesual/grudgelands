# Round 80.1 — Character-creation pictures for the website (0.80.1)

Planned with the user on 2026-11-16. Source: the kaesual coordinator's task of 2026-11-16
(`~/projects/kaesual-stack/.local/grudgelands-site-design-export-task.md`, copied to
`~/projects/grudgelands-orchestration/r801/website-task.md` at the start). grudgelands.com gets a
new look; its Play page stands the player's character in front of its race's character-creation
backdrop, full window. This round exports the creation pictures in `tools/web_data/web_data.json`
and adds wide versions of the backdrops for the website. Version **0.80.1**, expected
**compatible**: nothing changes for players or worlds; the game's own creation pictures stay
byte-identical.

Routing (the user, 2026-11-16): this session coordinates; EXPORT runs as an Opus subagent with an
independent Opus review; the art runs as two GPT-6 Astra lanes
([Astra lanes](../process/cross-cli-orchestration.md)).

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A **proposal** or **finding** is not a ruling until
  the user says so; a coordinator default is marked as such.

## Why

The website must not copy game files by hand: it reads a realm's pictures at the realm's commit,
so a new race, a repainted backdrop or a new faction reaches it with a pin move, and a realm on an
older commit keeps its own pictures. The game's backdrops are 1540 × 1400 for the creation
window's scene box; a 16:9 browser window would crop them to about two thirds of their height and
scale them up by two thirds, so the website gets wide renders of the same scenes.

**Correction to the task's premise:** the backdrops are not client screenshots. They are browser
renders (Three.js, the shared building-template renderer) of bounded block scenes built from the
game's own blocks, trees and building templates (`tools/character_creation_preview/`, scenes in
`scenes/<race>.json`, refreshed in `architecture-refresh/`; the opening in `intro/`). The wide
pictures come from the same pipeline with a 2560 × 1440 camera; at 16:9 the view sees well over
half again as much to the sides, so each scene needs lateral extension and a new composition.

## 1. Lanes and order

Start state: main at `2be9d970` (0.80.0, this plan). Integration branch `round80.1` in
`.claude/worktrees/round80.1`; every lane branches from it. Orchestration folder
`~/projects/grudgelands-orchestration/r801/`.

| Lane | Goal (§4) | Who | Wave | Merge order | Review |
|---|---|---|---|---|---|
| SCENES | Six wide race backdrops, 2560 × 1440, from the existing scenes, extended sideways | Astra | 1 | 1 | the user's look go on a preview page; Opus review of the pipeline changes |
| INTRO | One wide opening picture (the two keeps), 2560 × 1440 | Astra | 1 | 2 | the user's look go on the same page; Opus review of the pipeline changes |
| EXPORT | The `creation` key in `web_data.json` (parts 1, 3, 4 of the task), README, fixture | Opus | 1 | 3 | independent Opus review |
| D | Release 0.80.1, the round's end records, the answer to the website | coordinator | after every merge | — | coordinator |

All three lanes start together. EXPORT develops against local stand-in copies of the wide files
(never committed) and merges last: after SCENES and INTRO are merged it merges the round branch,
regenerates `web_data.json` against the real pictures and goes to its review.

## 2. User rulings

From the conversation of 2026-11-16:

1. **0.80.1, one round, one squash commit** carrying parts 1–4 of the task: the export first, the
   wide pictures on a preview page for the user's go, then one commit.
2. **The art runs as Astra lanes.**
3. **The export carries the race and class descriptions** as the creation screen shows them,
   their line breaks included (task part 4).
4. **Part 3 (a look per race) is built** unless it turns out to be real work; then it is left out
   and the website is told.
5. **Nothing changes in the game** (confirmed with the user, 2026-11-16): apart from the version
   number, no game file changes, and the character-creation screen's views stay exactly as they
   are. The scenes grow sideways only for the wide renders: the additions live in a separate
   wide layer per scene, the game's scene recipes stay unchanged, and a re-render of a game
   backdrop gives the shipped picture again (§6).
6. **The pixel check measures, it does not stop** (the user, 2026-11-16, refining ruling 5): the
   art lanes render each game view with and without their wide layer and report the difference;
   lighting may depend on the scene's extent, so a difference is a finding the user looks at, not a
   stop. (Measured: zero in all seven views.)
7. **Repo weight** (the user, 2026-11-16): commit only the website pictures plus small proofs
   (receipts, proof JSON, diff images); renders, comparison renders and preview screenshots are
   ignored build output.
8. **Look** (the user, 2026-11-16): the six race pictures approved after one pass that added trees
   to their sides and back hills; the opening approved in its third version (closer camera,
   fuller camp, the bottom-left corner filled quietly).

## 3. Shared conventions

### 3.1 Rules not covered by a ruling (coordinator defaults, the user may overrule)

- **The game's creation pictures do not change.** The six backdrops, the opening, the crest, the
  banners and the race icons stay byte-identical; the round adds files, it replaces none.
- **Where the wide pictures live:** `tools/web_data/media/`, outside every mod, so they cost the
  game client no media download and are not synced into the game. Names:
  `grug_creation_<race>_wide.png`, `grug_creation_intro_wide.png`. Their licence file
  `tools/web_data/media/LICENSE-media.md` carries the same notice as the creation backdrops in
  `mods/PLAYER/grug_classes/LICENSE-media.md` (CC BY-SA 3.0 arrangement, incorporated components
  keep their licences), with the provenance and SHA-256 of each file. Expected size: about 2 MB
  per picture, about 15 MB in all (unmeasured; extrapolated from today's 0.7–1.7 MB at 1540 × 1400).
- **Every exported picture names its licence file** (`license`, a repository path): the website's
  rule "publish the `LICENSE-media.md` of the mod a file comes from" does not reach
  `tools/web_data/media/`, so the export says it per picture. The answer to the website explains
  this (§3.3).
- **The wide composition follows the website's layout** (the task, part 2): horizon at about 30 %
  of the height; the figure's ground passing through 30–55 % of the width and 70–90 % of the
  height; nothing important in the right quarter (the list panel) or the bottom-left corner (the
  name); no character in the picture; no text, HUD or watermark; the same place, light and mood
  as the race's game backdrop. These are rough targets, not checks.
- **Each wide race picture carries its figure anchor** `figure = {x, y, node}` (refined by the
  coordinator, 2026-11-16): `x`, `y` the projected standing point (`portrait.feet` in the scene
  JSON) as fractions of the picture's width and height (0,0 top left), `node` the projected
  screen height of one node standing upright at that point, as a fraction of the picture's
  height. The website scales its figure by its model's height in nodes times the race's
  `visual_size`. SCENES writes the six anchors into `tools/web_data/media/wide.json`
  (`{"<race>":{"figure":{"x","y","node"}}}`, plain ASCII JSON, no other keys); EXPORT reads them
  from there.
- **Everything new goes under one new top-level key `creation`**; no existing key changes shape,
  not even by an added field (the website validates strictly). `schema` stays 1: the key is
  either absent (every commit before 0.80.1) or complete. The README says so.
- **The look per race (part 3):** there is no starter gear to show (the starter kit is apples and
  torches), so the value is the race with option 1 in every look category and nothing worn, in
  the stored format of the current `appearance_version`, built through the game's own
  `grug_visuals.appearance` path (the same body `races[].bare_body` describes, as a whole value).
  One per race, not per class.

### 3.2 The export's shape (EXPORT owns it; a proposal the lane may refine and must document)

```
creation = {
  camera   = {height_fraction, aspect, pitch, scene_aspect, fov = 30},   -- creation_camera.lua; fov vertical, degrees
  intro    = {path, width, height, license, wide = {path, width, height, license}},
  crest    = {path, width, height, license},
  factions = {<faction id> = {banner = {path, width, height, license}}},
  races    = {<race id> = {
                backdrop = {path, width, height, license,
                            wide = {path, width, height, license, figure = {x, y, node}}},
                icon = {path, width, height, license},
                description = "...",
                appearance = {...}}},                                    -- the stored-format value
  classes  = {<class id> = {description = "..."}},
}
```

Keys of `races`, `factions` and `classes` are the ids of `races[]`, `factions[]` and `classes[]`.
Paths are repository paths, as `classes[].icon` and `texture_files` give them. Sizes are read from
the PNG files. None of these files enter `texture_files`.

### 3.3 The answer to the website (lane D drafts it, the user forwards it)

The commit and version (0.80.1, compatible), the `creation` key and its README section, the
`license` path per picture (`tools/web_data/media/LICENSE-media.md` is new beside the mods'
files), the figure anchor, that the backdrops are renders rather than client captures, and that
the look per race is the race's bare default look (no starter gear exists).

### 3.4 Shared files

| File or folder | Owner |
|---|---|
| `tools/character_creation_preview/scenes/wide/` (new; `scenes/<race>.json` stay unchanged), `scenery.py`, `render-scenes.mjs`, a new wide-render folder beside `architecture-refresh/` | SCENES |
| `tools/character_creation_preview/intro/` (a wide layer and a wide render; `scene.json` stays unchanged) | INTRO |
| `tools/web_data/media/grug_creation_<race>_wide.png` and their receipts | SCENES |
| `tools/web_data/media/grug_creation_intro_wide.png` and its receipt | INTRO |
| `tools/web_data/media/LICENSE-media.md` | SCENES creates it with the shared notice; INTRO appends its own section (an append-only conflict, kept on both sides) |
| `tools/web_data/build.lua`, `export.lua`, `portable_test.lua`, `README.md`, `web_data.json` | EXPORT |
| `docs/technical/module-guide.md` (player meta read by external tools), when a sentence there changes | EXPORT |
| `CHANGELOG.md`, `game.conf`, `tools/web_data/upgrade.json`, `docs/STATUS.md`, this plan's Completion | D |

A change one lane needs in another's file goes to its report, not into the file.

## 4. Lane goals

### SCENES (Astra)

Six wide pictures, 2560 × 1440 PNG, one per race, of the same scene as the race's game backdrop:
the same scene JSON, buildings, trees, light, fog and tint; a wide camera; the scenery extended
sideways where the wider view would show the scene's edge (ground, trees and props in the
scene's own style, trees from the shipped generator as today). The extension is a separate wide
layer per race (for example `scenes/wide/<race>.json`) that the builder adds on top of the
unchanged `scenes/<race>.json` only for the wide render (ruling 5). The game's backdrops are not
re-rendered or touched. Composition by §3.1. Each render writes a receipt (camera, input digest,
size, output hash, the figure anchor of §3.1); a `--check` (or the existing receipt check)
confirms the shipped wide files match their receipts. A preview page shows each picture at
2560 × 1440 and 1366 × 768, with and without a translucent overlay of the website's layout (feet
zone, list panel, name corner) and with the race's bare figure standing at the anchor. The
licence file per §3.1. The lane changes no Lua and nothing under `mods/`.

### INTRO (Astra)

One wide opening picture, 2560 × 1440 PNG: the two keeps of `grug_creation_intro.png`, the same
scene, light and mood, composed for the website (§3.1; additions in a separate wide layer, ruling 5; no figure, so no anchor, but the right
quarter and the bottom-left corner stay calm because the website's panels sit there). Receipt and
check as SCENES; its section in the licence file; the same preview page (SCENES hosts it, or the
coordinator joins the two pages). No Lua, nothing under `mods/`.

### EXPORT (Opus)

1. **The `creation` key** (§3.2) built from the game's registries and files: races and factions
   from the registries the export already reads, the pictures by the game's naming, sizes from the
   PNG headers, the camera from `creation_camera.lua`, the descriptions from the race and class
   registrations, the figure anchors from the wide renders' receipts. A missing picture fails the
   export, it is never silently skipped.
2. **The look per race** (§3.1): a value that passes the game's own appearance checks for every
   race. If building it through the export's engine stub turns out to be real work, stop that
   part and report (ruling 4).
3. **README:** a "Character creation" section (fields, the absent-or-complete rule, the licence
   per picture, how a website places the figure on a wide backdrop with the anchor, and on a game
   backdrop with the camera), and the regenerate list gains "the creation pictures, the creation
   camera, race or class descriptions".
4. **Fixture:** `tools/web_data/portable_test.lua` checks the new key's shape, that every
   race and faction id has its entries, that every path exists with the stated size and a licence
   file, and that no `creation` path appears in `texture_files`; `--check` stays green.
5. Develop against stand-ins of the wide files (copies of the game backdrops renamed, never
   committed); after the art lanes merge, merge `round80.1`, regenerate, rerun the fixture.

### D (coordinator)

`game.conf` 0.80.1 and `tools/web_data/upgrade.json` (compatible); a short CHANGELOG entry (no
player-facing change: the website export); the round's STATUS row widened to 0.80.0–0.80.1; this
plan's Completion and Carry-overs; the answer to the website (§3.3) in
`~/projects/grudgelands-orchestration/r801/`.

## 5. Rules

- The launch sentence of the [round workflow](../process/round-workflow.md#6-writing-briefs) in
  every brief; the Astra briefs add the no-Lua sentence.
- The Astra lanes never push, merge, sync, touch the main checkout or another lane, or launch
  agents; Chromium runs are theirs, engine runs are not needed.
- **The art lanes merge only after the user's explicit go** on the preview page; look fixes go
  back to the lane first. A review verdict alone is not enough.
- A decision the plan reserves, or a blocker outside a lane, ends in `## Blockers / questions`.

## 6. Verification

- **EXPORT:** `luajit tools/web_data/export.lua --check`, `tools/run_fixtures.sh web_data`,
  `bash tools/check_lua.sh` on the changed Lua, `python3 tools/check_fresh_server.py`.
- **SCENES / INTRO:** the receipt checks; size, colour space and absence of a character, text or
  HUD in each picture; the preview page. **Ruling 5's proof:** no file under `mods/` changes, and
  the game's scene recipes (`scenes/<race>.json`, `intro/scene.json`, their builders' output for
  the game camera) are unchanged. One re-render of each game view with the base recipe plus the
  wide layer, game camera and game size (1540 × 1400; the opening at 1920 × 1080), compared with
  the same re-render without the wide layer: the number of differing pixels, reported (ruling 6;
  measured: zero in all seven views). (Compared with each other, not with the shipped PNGs: the browser has moved from Chromium 151 to 156 since those
  renders.) Renders go to the lane's output folder, never over a game file. Fixtures only those
  that read a changed document (found by grep).
- **Round end** (a small follow-up round, one area): the targeted fixture selection
  (`web_data` plus whatever a grep finds reading the changed files), `check_fresh_server.py`,
  `check_upgrade.py`, one smoke boot of the final branch.
- **Human test:** none needed in the game (nothing changes there). The website's own check of the
  Play page is the real acceptance and happens on its side.

## 7. Orchestration notes

- Process budget: two Astra lanes render with headless Chromium, EXPORT runs LuaJIT through the
  shared queue (`~/projects/grudgelands-orchestration/r45/lua_run.sh`).
- Merge order: SCENES, INTRO (after the user's go), then EXPORT (after it has merged the round
  branch and passed review), then D.
- **Compaction checkpoints:** (1) when the preview page is published and the round waits for the
  user's look go; (2) after lane D, before the round-end gates.
- Decided during the round: the user's look fixes and go on the wide pictures; whether part 3
  stays in (ruling 4).

## Completion (2026-11-16)

All three lanes are merged into `round80.1`; lane D runs on it. Nothing is on main and nothing is
pushed: `round80.1` lands on main as one squash commit (0.80.1) after the round-end gates. Both
art lanes merged after the user's look go (ruling 8) and an Opus review of their pipeline
changes; EXPORT had an Opus review before the art arrived, then merged the round branch,
regenerated `web_data.json` against the real pictures and passed `web_data`, `r54_web` and
`r55_web`.

**0.80.1 is compatible:** no file under `mods/` changes, no saved key is read or written; the
version number is the only game change.

Measured: the six race pictures 0.89–1.62 MB (7.1 MB), the opening 1.99 MB, all 2560 × 1440 RGB
sRGB; the game-view comparison (ruling 6) zero differing pixels in all seven views; all six race
anchors are `x 0.43, y 0.811757, node 0.24151` (every wide camera stands at the same offset from
the standing point). `web_data.json` only gains the `creation` key (183 added lines, none
changed).

### Lanes

| Lane | What | Review |
|---|---|---|
| SCENES | `scenes/wide/<race>.json` layers, `tools/character_creation_preview/wide/` (build, render, `--check`, proof, review page), opt-in wide paths in `scenery.py` and `render-scenes.mjs`, six media PNGs, `wide.json`, `LICENSE-media.md`; one tree pass after the user's look | MERGE (no Critical/High/Medium); the user's go |
| INTRO | `intro/wide.json` layer, `intro/wide-build.py` (`--check`), `wide-capture.mjs`, the opening PNG and its licence section; two look passes | MERGE (two Low doc items fixed by the coordinator); the user's go |
| EXPORT | The `creation` key (camera, intro, crest, factions, races with backdrop, wide picture and anchor, icon, description and look, classes with description), the PNG header reader, the strict `wide.json` reader, the licence check per picture, README section, fixture checks | MERGE (one Low bound fixed by the coordinator) |

## Carry-overs

- **Shared pipeline scripts in the game scenes' digest:** `scenery.py` hashes itself and
  `render-scenes.mjs` into every game scene's `render_input`, so after this round an
  `architecture-refresh` rebuild recaptures all six game backdrops (with today's Chromium). The
  game's files change only through an explicit `native.py --install`.
- **The wide `render.py --check` pins its sources:** 386 source hashes, 344 of them under
  `mods/` (textures, templates, tree generation); a later texture or template change turns the
  check red although the pictures still match their receipts. Either report stale sources as a
  warning (exit 1 only for picture, receipt, licence or anchor mismatches) or re-render the wide
  pictures with that change. No fixture runs it.
- **Small tooling notes:** `intro/wide-build.py --check` uses `assert` (passes under
  `python3 -O`); `wide-capture.mjs` has no overall timeout; Chromium started detached by
  `render-scenes.mjs` and `check-page.mjs` may outlive a Ctrl-C.
- **The pictures follow the game only by hand:** a new race or a repainted game backdrop needs
  its wide render too; `export.lua` fails while one is missing.
