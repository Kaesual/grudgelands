# WP26 Task Card — Two-Slot Furnace and the Universal Alloy Chain

Status: **Executable task card, authored 2026-08-13 (WP40-independent
design round). WP26 is buildable today: WP43 ✅ shipped every item, node
and API this card consumes.** Nothing here reopens a decided rule; the
recipe table is [`items_crafting.md`](../design/items_crafting.md)
§3.0.2 verbatim, resolved to exact itemstrings.

## 1. Scope and non-goals

- Deliver the two smelting nodes' recipe families: port the LotT dual
  furnace (code only, §1.1 of `items_crafting.md`) and register the
  universal smelting, alloy and storage recipes of §3.0.1/§3.0.2.
- WP26 owns **processed universal bars only** (BACKLOG row). Non-goals,
  all binding:
  - no G1/G2 gem processing and no cut-gem storage blocks (WP10; Rough
    gems cannot pack, §3.0.1);
  - no cultural finishes, no PvP specials, no trinkets (WP5/WP10);
  - no gear, tool or pick recipes (WP29 owns the final catalog, WP27
    owns armor); the surviving `default:pick_steel` verification tool
    stays untouched (`grug_materials/migration.lua:16-19`);
  - no claim, king or dragon content;
  - **no new items or nodes beyond the dual furnace pair** — every bar
    and storage block already exists
    (`grug_materials/registry.lua:206-246`,
    `grug_materials/ores.lua:105-130`).
- **No number freezing.** Cook durations and fuel budgets are runtime
  calibration inside WP26's own testing, and B22's tool `times`/`uses`
  remain WP26/WP29 runtime work — this card fixes recipe identities and
  gates, never those literals.
- **No prices.** Reference values belong to WP44's ledger methodology.
  WP26 adds or changes no `_grug_sell_price` and no trader override;
  the audit gate below runs against shipped values only.

## 2. Shipped baseline this card builds on

- All 12 processed materials exist with registered bar craftitems and
  storage block nodes (`registry.lua:206-246`, registered at
  `ores.lua:105-130`).
- WP43 cleared every legacy furnace/pack/tool recipe
  (`migration.lua:12-60`); **today no bar has any recipe**, and WP26 is
  the declared sole owner (`registry.lua:202-205`, `ores.lua:85-86`).
- The normal furnace is `default:furnace` with its upstream craft
  recipe (`mods/BASE/default/furnace.lua:452`).
- Dual furnace source, verified at the pinned LotT v1.2.7 submodule:
  `lottblocks/crafting.lua` — node pair `:201`, either-order
  `check_craft` `:54-71`, `add_craft` `:30-33`, slot layout
  `on_construct` `:230-236` (input 2 / output 2 / fuel 1), node-timer
  driven (`:84`, `:220` — already the AGENTS workstation pattern).
  Code is LGPL 2.1 (GPL-3.0-or-later compatible, `items_crafting.md`
  §1.1 licence note); `lottblocks` **media is CC BY-SA 3.0 and is not
  taken** — the port ships its own textures.
- `grug_traders`' three startup audits (incl. the §3.8 anti-loop rule)
  are live and silent; Iron Lump 3c → Iron Bar 3c is the documented
  audited smelting pair (`grug_traders/init.lua:81-91,100ff`).

## 3. Recipe inventory (the complete WP26 recipe surface)

### 3.1 Input-form rule

§3.0.2 names materials, not itemstrings. Binding resolution: **an alloy
input is the material's bar where a bar exists; mined Coal, Emberglass
and Abyssal Crystal enter as their mined items** (no bar form exists).
Evidence: the Steel row is explicit ("1 Iron Bar + 1 mined Coal",
§3.0.2), and WP43 registered Copper/Tin/Silver bars whose only consumer
is this chain (`registry.lua:207-224`). Every alloy consumes one of
each input and emits one output.

### 3.2 Normal furnace (cooking recipes)

| Output | Input |
|---|---|
| `grug_materials:copper_bar` | `default:copper_lump` |
| `grug_materials:tin_bar` | `default:tin_lump` |
| `grug_materials:iron_bar` | `default:iron_lump` |
| `grug_materials:silver_bar` | `grug_materials:silver_lump` |
| `grug_materials:gold_bar` | `default:gold_lump` |

This is the complete family. Quartz and every gem are never smelted
(WP10 owns gem processing); Emberglass and Abyssal Crystal are mined
items, never cooked.

### 3.3 Dual furnace (`dualfurn` recipes, either slot order)

| Output | Material slot A | Material slot B |
|---|---|---|
| `grug_materials:bronze_bar` | `grug_materials:copper_bar` | `grug_materials:tin_bar` |
| `grug_materials:steel_bar` | `grug_materials:iron_bar` | `default:coal_lump` |
| `grug_materials:silversteel_bar` | `grug_materials:steel_bar` | `grug_materials:silver_bar` |
| `grug_materials:embersteel_bar` | `grug_materials:silversteel_bar` | `grug_materials:emberglass` |
| `grug_materials:abyssal_steel_bar` | `grug_materials:embersteel_bar` | `grug_materials:abyssal_crystal` |

- Mined Coal occupies a **material** slot; Coal or Charcoal burning in
  the fuel slot never substitutes for it (§3.0.2).
- No universal bar consumes a regional gem, cultural material or trophy
  (§3.0.2 last line) — gate 5 greps for it.

### 3.4 Storage pack/unpack (crafting grid, both directions)

9× item ↔ 1 block for **all 12** `PROCESSED_MATERIALS` rows: copper,
tin, bronze, iron, steel, silver, silversteel, emberglass, embersteel,
abyssal_crystal, abyssal_steel, gold (§3.0.1 storage-block rules incl.
the Gold Block sentence). No gem-block recipe (WP10).
`grug_materials:emberglass_shard` is a WP43 migration target only
(`registry.lua:346,385`) and gets **no** recipe.

### 3.5 The dual furnace node itself

- New mod **`mods/ITEMS/grug_smelting`** (one global `grug_smelting`;
  `mod.conf` depends `grug_materials`, `default`), so `grug_materials`
  stays the recipe-free registry WP43 froze. It owns the ported node
  pair, the `dualfurn` recipe registrar and every §3.2–§3.4
  registration.
- The dual furnace's own craft recipe must be **T1-accessible**
  (ordinary stone/T1 outputs only — Bronze is the first alloy, and a
  deeper gate would deadlock the ladder). Exact shape is implementer
  latitude inside that constraint, audited like every recipe.
- Own front textures (re-skin); a VENDOR.md row (upstream repo, commit
  pin, LGPL 2.1, patch list) and LICENSE-media.md rows for the new
  textures land with the port.

## 4. Tasks

1. **T1 — port**: `grug_smelting` with the node pair, formspec, node
   timer, either-order matcher and fuel handling; protection-aware
   `allow_metadata_inventory_*` callbacks and dig-only-when-empty (the
   `default:furnace` pattern); VENDOR.md + LICENSE-media.md rows.
2. **T2 — smelting family** (§3.2).
3. **T3 — alloy family** (§3.3).
4. **T4 — storage family** (§3.4).
5. **T5 — regression + audits**: gates 1–7 below; real-code Lua 5.1
   tests under `tools/wp26/` for the matcher (either-order,
   coal-not-fuel, one-of-each consumption) where headless-testable
   (WP39 pattern).
6. **T6 — docs**: BACKLOG WP26 → ✅ with a one-liner; ROADMAP tick;
   README "Current State" in the same commit (AGENTS.md rule); AGENTS
   delta only if a new binding pattern emerged.

Sequencing: T1 → (T2, T3, T4 parallel) → T5 → T6. Review per
`wp-workflow.md` (mandatory Opus review, reviewer ≠ implementer).

## 5. Acceptance gates

1. **Recipe-surface exactness**: the recipe set registered by
   `grug_smelting` equals §3 exactly — no extra output, none missing
   (startup self-audit or headless test).
2. **Steel/coal contract**: iron bar + coal only in the fuel slot cooks
   nothing; coal in a material slot + any fuel produces steel.
3. **Either-order**: every §3.3 row crafts with swapped slots; exactly
   one of each input is consumed per output.
4. **WP7 audits**: all three startup audits stay silent with the new
   recipes; zero price fields added or changed (diff shows no
   `_grug_sell_price` change).
5. **Scope grep**: no `grug_smelting` recipe references rough/cut gem,
   cultural, trinket, gear or pick ids.
6. **Lua/engine**: `tools/bin/luac51 -p` on every touched file; the
   five `luanti-lua.md` sweeps clean; no new globalstep (node timers
   only); no detached inventories.
7. **Licences**: VENDOR.md and LICENSE-media.md rows land with T1; no
   CC BY-SA `lottblocks` media in the tree.
8. **Runtime test plan** (user, ~10 min, existing world OK — no mapgen
   change): craft and place both furnaces; smelt the five §3.2 bars;
   alloy the five §3.3 bars in both slot orders; verify the steel
   fuel-slot refusal; pack/unpack a metal block, a resource block and
   the Gold Block; confirm `debug.txt` shows no audit lines.

## 6. Composition

- **Unblocks**: WP27 (armor), WP29 (gear/pick ladder) and WP10
  (professions) all depend on WP26 (BACKLOG). Nothing else consumes
  `dualfurn` recipes yet.
- **WP44**: bars beyond Iron stay unpriced; when the ledger later
  prices them, the §3.8 audit re-proves the chain at every start by
  construction.
- **WP40-independent**: no mapgen, zone or spawn interaction; existing
  worlds gain the recipes on update.
