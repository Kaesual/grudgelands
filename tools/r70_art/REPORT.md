# Round 70 lane ART — delivery

**Complete proposal set, awaiting the user's choices.** Base `55aa7708`, branch
`r70-art`. Every added file is under `tools/r70_art/`.

**Upgrade classification: compatible, tooling and proposal media only.** No
game code, registered nodes/items, saved state, version, upgrade declaration or
hall templates change. Installing the selected machines into the houses is
lane GUILD's separate work, joining Round 70's map reset.

## Delivered

[Self-contained pick page](page.html) · [Overview](previews/overview.png) ·
[Reproduction and construction](README.md) · [Media inventory](LICENSE-media.md)

- **Thread:** A wooden spool, B yarn ball, C tied skein. Each appears at
  16, 32 and 64 px between the shipped Stick and Iron Bar, with today's tinted
  paper shown for comparison.
- **Grinder:** A hand quern, B twin rollers, C stamp mill. All have a front
  elevation and a hall-corner view of the same box geometry. Stone, timber,
  iron straps and static gravel/sand samples explain the work.
- **Smelting furnace:** A banded shaft, B crucible hearth, C vaulted hearth
  with an attached mould bench. All are cold, with soot, slag and castings;
  they need no light, fire, particles or functional mechanism.
- **Five ornamented stones in three families:** A running inlay, B quarry
  seal, C metal sprig. Iron, Steel, Silversteel, Embersteel and Abyssal Steel
  each have a single-block view, flat face and 5 × 5 wall. Each family also
  has the five faces together beside existing plain stone. The shipped bar
  is beside each block for a direct metal comparison.

There are **24 proposals / eight independent choices**, **28 original
16 × 16 textures**, six complete node-box geometry JSON files and 43 software
preview images. The page is about 0.97 MB and embeds 125 PNG instances. All
CSS, JavaScript, images and the comparison-media notice are inline. It has
system/light/dark themes, responsive layouts, local optional pick storage and
a copyable summary. There are no external files or network requests.

The generator produces and checks **96 files**, including its hashes, source
hashes, HTML audit and per-file licence table. The code, README and report
are authored sources outside that generated count.

## Recommendations

| Item | Recommendation | Reason |
|---|---|---|
| Thread | **A** | The flanges, winding and loose end remain distinct at native size. |
| Grinder | **A** | Visible millstones explain grinding; its low form leaves the NPC visible. |
| Smelting furnace | **A** | A shaft, grate, pouring lip and mould read as a compact smelting installation. |
| Iron stone | **A** | Restrained dark metal and an unframed diagonal line. |
| Steel stone | **A** | The brighter metal keeps that same quiet architectural route. |
| Silversteel stone | **A** | Pale blue metal stands apart from Steel; small returns add richness. |
| Embersteel stone | **A** | The bar's red body and warm glints work without glow or a loud tile outline. |
| Abyssal Steel stone | **A** | Violet returns give the highest tier more detail while retaining the shared open ground. |

B's seals suit isolated accents and formal piers; C's sprigs suit more floral
decoration. Their stronger repeated motifs are shown honestly in identical-tile
walls. The recommendations are marked on the page, but **no radio is selected
by default** and each stone tier can be chosen independently.

## Rechecked input claims

- **Confirmed:** Thread is `default_paper.png^[colorize:#d8d1bd:115`
  (`mods/ITEMS/grug_professions/init.lua`, SUPPLIES). The comparison reconstructs
  that tint, and the candidate is separate original pixel art.
- **Confirmed:** `default_stone.png`, `default_stone_brick.png`, the current
  paper source and all five shipped bar files are **16 × 16**. Candidates
  keep that resolution. Icons have binary alpha; all block faces are opaque.
- **Confirmed:** shipped metal bars use the Round 68 A ramps from
  `tools/r68_icons/art.py`, METAL. Every opaque shipped bar pixel is checked
  against the corresponding five-colour ramp on each build.
- **Confirmed, with a placement consequence:** the six houses share a 17 × 17
  footprint and the same socket layout in `tools/r58_halls/make_halls.py`.
  The sorter is at `(1, 1, 10)`, facing east; its table is at x=2 and the west
  wall x=0. A 2-deep machine cannot be placed directly behind that unchanged
  socket. The installation must revise that work bay or use the ore yard.
  The generic corner studies make no clearance claim about the existing halls.
- The open depth/nether TODO files do not block this art package. The new
  Round 70 rules govern the Stonewright; the older guild reputation rule has
  no bearing on these proposal assets and is not edited here.

## Validation completed

- `python3 tools/r70_art/build.py --check`: **PASS**, all **96 generated files
  reproduce byte for byte**, with no unexpected generated files.
- Candidate validation: 28 native-size RGBA images, transparent icons with
  binary alpha, opaque node faces, palette verification against shipped bars.
- Six geometry files: every box has positive extent and stays within the
  declared footprint; occupied cells are derived from the geometry; every
  texture reference resolves. The page and renders use those same boxes.
- HTML audit: **125 embedded PNG instances decode**, every local anchor
  resolves, all resources are inline, eight radio groups each offer A/B/C,
  and none is preselected. CSP forbids network connections and external
  resources. No image, style, script or font depends on publication location.
- Python source compiled in memory; `node --check tools/r70_art/picks.js`
  passed.
- Ad-hoc Node execution of the actual page script with a mock DOM passed:
  all eight independent choices, no defaults, restored choices/theme,
  unavailable storage, malformed and invalid stored values, copied summary,
  Clipboard API fallback and clearing choices. This was **not** a browser
  interaction test; no test fixture was added.
- The overview, machine front/hall PNGs and stone repetition were inspected
  directly. A mirrored camera basis in the first software render was corrected
  before delivery; final front views use +x to the right.
- Local Markdown links and generated geometry paths were checked, along with
  `git diff --check` and the final changed-file scope.

**Browser limit:** cached Chromium 151 failed before page load with
`setsockopt: Operation not permitted` (exit 133). No real browser screenshot,
phone interaction or desktop/web game acceptance is claimed. CSS provides
phone layouts down to 320 px, both colour themes, visible focus and reduced
motion support; actual browser appearance remains to be checked when the page
is published or opened outside this sandbox.

No Lua, fixtures, server boots, main-checkout changes, other worktree changes,
other agents, merges or pushes were used. The coordinator's independent review
is still required before integration.

## Blockers / questions

None for delivery. The user chooses on the page. Lane GUILD then owns selected
asset installation, cell splitting, node registrations, final UVs/collision,
the work-bay placement and its desktop/web checklist. The existing sorter
position must not be assumed to have room behind it.
