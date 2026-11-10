# Decorations discussion study

Open [the offline overview](dist/index.html) directly in a browser. Its German
interface is a discussion artifact, not authoritative game design. No server,
network access, generated artwork or game installation is needed.

The entire proposal was subsequently approved and implemented in Round 75.
For current access, prices and behavior see [the design](../../docs/design/decorations.md);
for original art see [the local gallery](../r75_art/index.html). The measurements
and evidence below deliberately retain the original 0.73.1 baseline.

## Scope and baseline

Prepared on branch `decorations`, based on local main
`9cdb4328a351685b8162743b1e2a809e398e9832` (0.73.1). Another agent works on main;
this study remains isolated in its worktree. Classification: **compatible,
tools-only**; it changes no game code, templates, recipes, stock or saved world.
A future world-generation change must receive its own upgrade classification.

The catalog contains 57 discussion families and 515 building/space entries:
51 start-town buildings, 416 capital building/plot entries, and 48 structures
in 12 peaceful regional villages. Capitals include all authored district
alternatives, not just the subset selected in one world seed. A coupled ruin
plot is one entry with both templates. Camps, mines, outposts and expeditions
are excluded; urban stores and granaries are included. Outer walls/gates and
Kezamba's gate totems are explicitly excluded from additional decoration.

The user's decisions: make decorations available to players and use them in
our cities; keep ordinary item frames and armor stands cheap to craft from
wooden planks; allow special versions to be sold; reduce the wheel price;
one gold can be reasonable for paintings; preserve restraint and clear gates.
All exact new prices, recipes, item families, motifs and placements here remain
proposals. There is no authorization here to implement the proposed game changes.

User clarification, 2026-11-10: production will receive a map reset anyway.
The proposed city dressing can therefore be authored directly for regenerated
buildings and join that deployment's reset; no retrofit of existing city
buildings is needed. This does not waive persistence requirements for player
items or displays, and does not authorize executing a production reset.

## Evidence and interpretation

`export.lua` observes the actual read-only template loader in its own LuaJIT
process, then runs each selected builder. Capital cores and all district plots
are built, including service additions; start layouts are built as authored.
Village structure identities and bounds come from the builders' landmarks.
`evidence/` caches those outputs so page edits do not repeat the fleet.

Measurements count node cells, not complete furniture. Core/start detail cards
measure templates before exterior additions; district cards measure whole built
plots; village cards measure horizontal structure bounds. Totals measure each
whole blueprint once. The two complete table node types are the only tables
used for the clear-above metric; construction from slabs/blocks is not counted.
This metric identifies empty cells, not whether every room needs decoration.
Schematic floorplans omit procedural and later service additions. They are not
engine screenshots or validated placement designs.

`content.py` holds the proposals. `build.py` assigns functional profiles using
actual services, named exceptions and building names; similarly used buildings
share an editorial recommendation. Regional style and measured inventory are
shown alongside it. This is a source-based study, not a visual GUI acceptance
of 515 individual spaces. The eventual design pass must inspect real sightlines,
collisions, light and NPC access in desktop and web clients.

`inventory.json` includes the full building inventory and SHA-256 hashes of
the wp13/wp40 source modules, study generators, cached evidence, page template
and all 266 used building templates.

## Source provenance

Existing purchasable content: `mods/ENTITIES/grug_traders/stock.lua`.
Existing furniture and its intentionally reduced functionality:
`mods/ITEMS/grug_decor/xdecor.lua`, `cottages.lua`, `capital.lua`.
Existing recipes: `mods/PLAYER/grug_jobs/basic_recipes.lua`.

Reference-source observations carry forward the earlier research; no external
art or code was imported. In the pinned read-only `VoxeLibre` checkout,
`mods/ITEMS/mcl_itemframes/register.lua` and `init.lua` demonstrate item-bearing
frames and variants; `mods/ITEMS/mcl_armor_stand/init.lua` demonstrates an
equipment display; `mods/ENTITIES/mcl_paintings/paintings.lua` catalogs multiple
painting sizes. These are technical provenance, not art direction. References
were read from the existing main checkout; this worktree has no initialized
reference submodules. See [the reference registry](../../docs/reference_projects.md)
and [vendored provenance](../../VENDOR.md). Per-file license clearance would be
required before any future import; the proposed new motifs are our own.

## Rebuild and validation

From this worktree root:

```sh
python3 -B tools/decoration_study/build.py
bash tools/check_lua.sh tools/decoration_study/export.lua
node tools/decoration_study/browser-check.mjs
```

The Lua check requires the repository's plain Lua 5.1 parser; an existing build
can be selected with `GRUG_LUA51_PARSER`. Browser validation uses an installed
Chrome executable, optionally selected by `CHROME_BIN`. It checks the offline
page and writes results/screenshots under `dist/`; it does not run Luanti.

Validation on 2026-11-10: Lua 5.1 parser and applicable sweeps passed; 22 browser
checks passed, including every detail card, city filters, catalog filters,
deep links and layouts at 1600, 760 and 390 pixels. Source paths and recorded
hashes were checked. Independent read-only review by `study_review` approved
the corrected artifact. No Luanti GUI acceptance is claimed.

Only when deliberately refreshing evidence against another source baseline,
run `luajit tools/decoration_study/export.lua "$PWD" CITY_KEY` and capture its
JSON for each existing `evidence/` key. Respect the shared eight-Lua-process
cap and idle scheduling; do not regenerate the same snapshot unnecessarily.
Rebuild the page after refreshing sources and evidence together.
