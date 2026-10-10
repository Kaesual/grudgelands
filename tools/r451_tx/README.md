# Release 0.45.1 TX — Trainer greetings and music-note proposals

Original text and pixel art by GPT-6 Astra, 2026-10-10. These are candidates
for the user's selection; none is selected or installed. Open
[review.html](review.html) directly in a browser, choose one greeting per
trainer and one icon, then download the selections for the coordinator.
The page also lets the user select a whole text voice before making
individual adjustments. It works offline with no server or dependencies;
choices last until the tab is reloaded or closed.

**Upgrade classification: compatible.** This package only adds proposals,
their generator and a local review page under `tools/r451_tx/`. It changes
no game code, files under `mods/`, saved state or release declaration.

## Text voices

| Variant | Voice |
|---|---|
| A — Warm and proud | A welcoming craftsperson invites the player to share the quiet satisfaction of making useful things. |
| B — Brisk and practical | A friendly working teacher names the products and station and gets straight to learning. |
| C — Playful | Each craft gets a small, affectionate joke about its work or equipment, never at the player's expense. |

[greetings.json](greetings.json) is the one editable text source: exactly
the eight requested keys, each with A, B and C. The 24 greetings are
114–153 ASCII characters, one or two sentences, without line breaks.
Every craft's variants name its station. Alchemy uses its display name;
the repair greetings all mention payment in coin. Cooking has no entry.
All greetings are neutral across peoples and capitals.

Facts checked against current code:

- [Registry](../../mods/PLAYER/grug_jobs/registry.lua): the seven taught
  professions, Alchemy's display name and the profession/station mapping.
- [Family owners](../../mods/ITEMS/grug_professions/enchants.lua) and
  [gear recipes](../../mods/ITEMS/grug_professions/base_recipes.lua):
  Weaponsmith makes swords, daggers and greataxes; Armorsmith makes metal
  armour and shields; Leatherworker makes bows and leather armour;
  Woodcarver makes wands and staves; Tailor makes cloth armour and
  spellbooks; Goldsmith makes trinkets.
- [Tailor](../../mods/ITEMS/grug_professions/tailor.lua) and
  [Leatherworker](../../mods/ITEMS/grug_professions/leatherworker.lua):
  both also make bags; the Tailor's spellbooks are complete equipment.
- [Alchemy recipes](../../mods/ITEMS/grug_alchemy/recipes.lua) and
  [trinkets](../../mods/ITEMS/grug_gear/trinkets.lua): finished potions and
  elixirs; rings, amulets/pendants and medallions.
- [Trainer title and teaching](../../mods/PLAYER/grug_jobs/trainers.lua),
  [repair service](../../mods/ITEMS/grug_repair/service.lua) and
  [providers](../../mods/ITEMS/grug_repair/providers.lua):
  `grug_jobs.MENDER_TITLE` is "Grudge-Free Repairs"; the former Cooking
  trainer repairs equipment for money and teaches nothing. The greetings
  promise no free repairs, learning, remote service or new ability.
- [Inventory and equipment design](../../docs/design/inventory_equipment.md):
  the stations and current Crafting presentation.

## Icon choices and HUD preview

| Variant | Take | Preview |
|---|---|---|
| [A](note/A/grug_ambience_note.png) | A single gold eighth note with a curled flag, a broad head and pale highlights. | [Sheet A](note/A/preview.png) |
| [B](note/B/grug_ambience_note.png) | Two ivory-silver notes joined by a rising beam, with cool shaded edges. | [Sheet B](note/B/preview.png) |
| [C](note/C/grug_ambience_note.png) | A honey-wood lute with a pear-shaped body, angled neck and strings, beside a small gold note. | [Sheet C](note/C/preview.png) |

All three icons are **24 × 24 RGBA**, drawn at that native resolution and
shown at 24 × 24 in the HUD study. Their alpha is binary (0 or 255), with
clear outer margins and no matte or smoothing. One-pixel dark contours,
gold/ivory highlights and compact material shading follow the existing
16 × 16 [map icons](../../mods/PLAYER/grug_map/textures/) and
[equipment icons](../../mods/ITEMS/grug_gear/textures/); no source pixels
were copied. The extra eight pixels keep the beamed pair and lute legible
beside two lines of text, without requiring fractional scaling.

Each **1072 × 1216 RGBA** preview sheet shows all three original backdrop
studies: bright sky, grassland and dark cave. Each scene appears once at
HUD size and once as an exact **4× nearest-neighbour** enlargement. A
small uncovered margin makes the box's transparency visible against the
same backdrop. The two example lines are "Katabasis I" and "Scott Buckley"
as supplied in the brief; no music or other downloaded content is included.

The **232 × 44** box uses **`#3434344D`** (RGB 52/52/52, alpha 77/255 =
30.20%). The actual inventory window's flat colour is `#343434`, sampled
from [gui_formbg.png](../../mods/BASE/default/textures/gui_formbg.png) and
corroborated by the cover-colour comment in
[pages.lua](../../mods/PLAYER/grug_inventory/pages.lua).
[default/init.lua](../../mods/BASE/default/init.lua) adds that texture with
`background9`. The `#080808BB` there is the fullscreen dimmer;
[ui.lua](../../mods/PLAYER/grug_inventory/ui.lua)'s `BOX_COLOR` is the black
translucent fill of inner inventory areas. Neither is the window's flat
colour used for this HUD.

The zone-name line is a client-sized text HUD element in
[minimap.lua](../../mods/PLAYER/grug_map/minimap.lua). Final integration
should use that same client text sizing for both music lines. These
previews use original bitmap lettering: 14-pixel glyphs on an 18-pixel
line pitch, with a one-pixel shadow; the 24-pixel icon is centred beside
their 32-pixel combined height. This is an illustrative size study, not a
new shipped font or an engine screenshot. The user's desktop and web GUI
checks confirm the final client-dependent scale after integration.

## Provenance and reproduction

The icons are **original work, AI-assisted, offered under CC0 1.0
Universal**. The original preview backdrops and bitmap lettering are
offered under the same dedication. GPT-6 Astra authored every shape at
integer pixel coordinates using Python 3 and Pillow in
[paint_art.py](paint_art.py). No downloads, source artwork, external fonts,
image-generation service or random input were used. The generator code
and review-page code follow the repository's GPL-3.0-or-later licence.

Run from the repository root (Python 3 with Pillow installed):

```sh
python3 tools/r451_tx/paint_art.py
python3 tools/r451_tx/paint_art.py --check
```

The first command builds the six PNGs and the offline review page. The
second compares their bytes with freshly generated output without writing
and validates the eight text keys, three variants each, character lengths,
icon sizes, RGBA mode, binary alpha, clear margins and inventory colour.
The review page embeds the current JSON at generation time, so regenerate
it whenever the greetings change. The generator writes only this folder.

## File inventory

| Files | Purpose |
|---|---|
| `greetings.json` | All 24 editable greeting candidates. |
| `note/A/grug_ambience_note.png`, `note/B/grug_ambience_note.png`, `note/C/grug_ambience_note.png` | The three 24 × 24 transparent RGBA icon candidates. |
| `note/A/preview.png`, `note/B/preview.png`, `note/C/preview.png` | The three 1072 × 1216 opaque RGBA review sheets. |
| `paint_art.py` | Original art, preview and review-page generator, with `--check`. |
| `review.html` | Generated offline selection page, with summary and JSON download. |
| `README.md` | This handover, source checks and provenance. |

## Validation and handover

Format and reproducibility checks passed; the icon silhouettes and all
three preview sheets were inspected. All local handover/page links were
checked. The review page's script passed JavaScript syntax validation.
A Node DOM stand-in exercised the page's initially empty selection, whole
voice selection, individual override, icon choice, exact JSON export and
reset; all passed. Headless Firefox crashed at startup, so this is not a
browser-rendering acceptance. No Lua files changed and no engine boot was
run. The required single full portable-fixture run on 2026-10-10 passed:
`JOBS=4 ionice -c3 bash tools/run_fixtures.sh` — **152 passed, 0 failed**
(LuaJIT; the runner applies idle CPU scheduling).

The coordinator receives the user's eight greeting choices and one icon
choice, wires them into the game, and adds a media licence row only for
the selected icon. Independent review belongs to the coordinator; no
agents were launched by this lane. The user's selection and the desktop
and web GUI checks remain open. No blockers or design questions.
