# Round 75 — Decorations for homes and cities

Status: implemented, independently reviewed and merged into main as one squash
commit, 2026-11-10; not pushed, desktop/web GUI acceptance remains open. The
reviewed round history is preserved by `round-75`. Work began from 0.73.1
(`9cdb4328`), then incorporated completed Round 74 (`59da1e93`) before the final
integration checks. The user authorized landing on main after review.

## 1. Lanes and waves

| Lane | Owner | Scope | Order |
|---|---|---|---|
| FURNISH | implementation agent | New static everyday objects, light/textile/plant variants and static city displays | First |
| DISPLAYS | implementation agent | Functional frames, armor stands, weapon holders; persistence and claim reset packing | First |
| ART / SHOP | coordinator | Original paintings and gallery, existing kit access, prices/recipes, expedition art drops | Alongside first wave |
| CITY | implementation agent | Explicit restrained dressing of the 515 surveyed buildings/spaces | After node IDs are frozen; integrate after FURNISH / ART |
| REVIEW / DOCS | independent reviewer / coordinator | Independent review, integration, design documentation and release checks | Last |

Agents use separate lane worktrees and non-overlapping ownership. Authoritative
scope: [the discussion inventory](../../tools/decoration_study/inventory.json)
and [family descriptions](../../tools/decoration_study/content.py), E01–E20,
N01–N32 and A01–A05. New art remains subject to the promised local motif gallery.

## 2. User rulings

1. Implement the entire proposed list; both player availability and our cities.
2. Simple item frame: four wooden planks. Simple armor stand: six wooden planks.
   Special frames/stands may be sold. Existing craftable objects stay craftable.
3. Wagon wheel: two silver. Other proposed price bands accepted; coordinator
   chooses concrete prices. Existing paintings remain one gold.
4. Original painted motifs, limited palettes, clear silhouettes suited to the
   existing game. City/landscape paintings atmospheric; small still lifes simpler.
5. Expedition paintings are **not sold**. Each expedition's Reward Chest has
   a **2% chance** of its corresponding painting. Follow the existing personal
   reward roll: once per eligible player per run, not every chest opening.
6. Ordinary frames, armor stands and weapon holders are functional displays.
   Food, crates and other household groups are static decorations, not new
   crafting/storage/consumption systems.
7. Dress all surveyed city types modestly, including the twelve peaceful
   regional villages. Camps, mines, outposts and expedition rooms are excluded.
   Gates, passageways, royal combat areas and deliberately quiet spaces stay clear.
8. Production already needs a map reset. Author dressing for regenerated
   buildings and include this release in that reset. No live city retrofit.
9. Implementation ran in an isolated worktree while another agent owned main.
   After the completed reviews, the user authorized merging into main. Only the
   user pushes. This task does not authorize running a production reset.

## 3. Shared conventions

Classification: **map reset**, because authored world generation changes. New
items/display inventories are additive; no migration step is presently needed.
Display contents must survive normal save/reload and the existing claim-container
packing path during later resets. Stable existing item IDs remain unchanged.

`grug_decor` owns static forms and original art. A late `grug_displays` mod owns
functional display behavior and uses the existing appearance/claim APIs. The
old `grug_decor:xdecor_itemframe` ID gains its promised behavior without renaming.
All city-only variants are static, no inventory/entities/timers, diggable but
drop nothing: town protection guards capitals/starts; regional shells remain
removable. City art and displays must not create free rare loot.

Decorations keep small, clear silhouettes. Floor props have sensible collision;
tabletop/wall/ceiling details are non-walkable. Do not add per-flame timers,
continuous particle emitters, new workstation mechanics or poses editors.
Reuse existing textures for code-native small meshes/nodeboxes; original painted
art is generated with the imagegen skill and stored with prompts/provenance.

## 4. Lane goals and ownership

FURNISH owns new `grug_decor/furnishings*.lua`, any authored furniture models,
`tools/r75_furnish/` and its fixture. It supplies a pure catalog of new static
node IDs/family IDs/prices. Root owns `grug_decor/init.lua`, `mod.conf`, media
license index and shared integration files. No existing capital service nodes
are repurposed into purchasable inventory-bearing nodes.

DISPLAYS owns new `mods/PLAYER/grug_displays/`, minimal additions to
`grug_housing/packed.lua`, `tools/r75_displays/`, and its technical mod-map row.
It keeps the canonical armor renderer, item metadata, claim rights, soulbound
restrictions and empty-before-dig behavior. Root owns recipes and merchant stock.

CITY owns the explicit city dressing catalog/applicator and minimal hook in
`wp40/r7_settlement.lua`, with `tools/r75_city/` authoring/audit tools. All 515
survey IDs are accounted for, including intentional zero-addition entries.
No heuristic guessing of room purpose during world generation. Placement data
is authored offline against finished blueprints and checked before/after for
support, occupied cells, doors, service access and socket routes. No world-size,
settlement-layout, terrain or recipe changes.

ART / SHOP owns artwork registrations/media/prompts/gallery, static city variant
registration, vendor stock, basic recipe edit source and generated catalog,
expedition loot rows, their focused fixture and later release documentation.

## 5. Rules and orchestration

Follow [round workflow](../process/round-workflow.md), Lua 5.1 rules, media
provenance, [mod map](../technical/mod-map.md), and upgrade contract. The two
open TODO design files concern other systems and do not block this scope.
Upstream workarounds were read; no workaround is removed by this round.
Maximum eight Lua processes across all agents, idle scheduling for fleets.
Develop with focused fixtures; run the complete fixture suite at the integration
gate, avoiding duplicate fleets. Root owns `game.conf`, upgrade declaration,
release docs and all integration decisions. No merges or sync into occupied main.

## 6. Verification and GUI checklist

Code: changed-file Lua check; registration/media/catalog checks; display
interaction, metadata, reload/dedup, protection and reset packing; exact 2% loot
boundary and no merchant route for expedition art; all 515 placement decisions,
unchanged routes and excluded camps; affected settlement/template checks;
full portable fixtures, fresh-server/upgrade/economy/design checks, final
headless smoke boot. A pure node placement pass needs no seed fleet under the
project's standing exception; any broader generator change reopens that gate.

User GUI acceptance (desktop and web):

- Buy existing/new furniture, see correct icons/names/prices; craft both basics.
- Place, rotate, dig and rejoin around small props, rugs, shelves and lights.
- Check frame item/node/enchanted-item visuals and stand mixed armor slots.
- Check owner/friend/stranger permissions, no loss/duplication, empty-before-dig.
- Check new paintings at actual scale and the local art selection.
- Inspect each race's start, capital core/district and regional village; verify
  table contact, wall mounting, beds, doors, NPC/service access and royal fights.
- Expedition reward art remains personal, rare, and cannot be rerolled by reopening.
- Check visual cost with several furnished player houses in the web client.

## 7. Completion — 2026-11-10

Implemented the entire approved 57-family list. The Decoration Merchant now
has 128 offers, with the two ordinary displays in Basic crafting instead.
Sixteen original paintings ship with a [local offline gallery](../../tools/r75_art/index.html),
preserved source images and prompts; the three expedition paintings remain
exclusive 2% personal Reward Chest drops. Static city copies cannot grant rare
loot. The city ledger covers all 515 surveyed entries: 649 placements in 332
entries, and 183 explicitly quiet entries. These are authored blueprint counts,
not counts for an entire generated world.

Integrated into `round75`, including main's finished Round 74 (`59da1e93`),
then landed on main as one squash commit with the user's authorization. Main
was clean and already an ancestor of the tested round tip, so no new code
integration or conflict resolution was needed. Tag `round-75` preserves the
reviewed history. No push, local game sync, production deployment or reset was done.
Classification: **map reset**, no migration step. The user's desktop/web GUI
checklist above and final art selection remain open.

### Independent reviews

| Package | Final implementation tip | Verdict |
|---|---|---|
| DISPLAYS | `c165fb8e` | MERGE, including UI, permissions, serialized visuals and full-stack recovery when support breaks |
| FURNISH | `4a3327a4` | MERGE, including exact mounting, material/UV orientation, engine OBJ handedness and small static flames |
| CITY | `46d5a289` | MERGE, including full support and rotation of all 112 city-only node types |
| ART / SHOP | `7c410d61` | MERGE, including original media, 2% reward exclusivity, prices, recipes and placement |
| Integration and documentation | final worktree delta | MERGE; legacy fixture updates independently reviewed after the full suite |

Review corrections are in the lane history. Original study approval alone was
not treated as game-code approval. Visual inspection additionally used the
engine-exported node definitions and actual textures for all 56 new merchant
furnishings and 16 paintings. This is an authoring preview, not GUI acceptance.

### Integration evidence

- Complete portable suite: **344 fixtures covered**. Initial run: 336 passed;
  eight legacy expectations failed after the intentional stock/recipe/reward
  expansion. All eight passed their targeted rerun after reviewed fixture
  updates. No unresolved failure; the complete suite was not needlessly rerun.
- Changed Lua: **37 files**, plain Lua 5.1 parser, global listing and all six
  applicable sweeps passed; executable fixtures used LuaJIT.
- Focused ART / SHOP: 1,008 checks; FURNISH: 12,728 checks; DISPLAYS: 46 checks;
  claim-packing Python tests: 22 passed. Recipe and mesh outputs are current.
- CITY: all 24 builders passed the strict placement audit (515 rows / 649
  placements). Actual lazy settlement writes 5,184 cells; non-zero district
  rotations preserve toolboard/painting support. All 112 city rotation types
  match the real engine dump. Existing access, PvP, town and capital fixtures
  passed. Round 56 identity goldens changed for the declared map reset;
  original blueprint point/build digests did not.
- Template audit: 284 templates, six layouts and six rosters, zero errors
  (59 existing warnings). Editor tests: 656; reader tests: 56. The refreshed
  real engine node dump contains 1,309 nodes and 49 aliases.
- Final headless engine boot passed on the integrated code. No desktop/web
  runtime acceptance is claimed.
- Art gallery: 13 browser checks; updated study: 22 browser checks, including
  narrow and wide viewports. Both remain local; no website was published.
- Fresh-server source audit, upgrade declaration/self-test, income check,
  generated design tables and design audit passed (18 existing design warnings).
  `git diff --check` passed.

The dressing pass adds no timers, entities or per-frame work to cities. A local
one-pass authoring measurement over all 334 blueprint alternatives took 4.224 s
CPU for the original builders and 0.537 s for dressing. This is a small local
cost check, not a full-world or web-client performance claim. A pure node
placement change uses the standing seed-fleet exception.
