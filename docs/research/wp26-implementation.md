# WP26 implementation — the two-slot furnace and the universal alloy chain

**Shipped 2026-09-16** (WP13 wave 3, lane C, branch `wp13-w3-wp26-furnace`)
against the executable card
[`wp26-task-card.md`](wp26-task-card.md) (2026-08-13). Evidence:
`tools/wp26/evidence/20260916/`.

The card's non-goals were binding and none was touched: no gear, tool or pick
recipe; no gem processing or cut-gem block; no cultural finish, PvP special or
trinket; no price field added or changed; **no new item or node beyond the dual
furnace pair**.

## 1. What shipped

### The mod

New mod **`mods/ITEMS/grug_smelting`** (one global, `depends = default,
grug_materials`), so `grug_materials` stays the recipe-free canonical registry
WP43 froze.

- `alloys.lua` — the `dualfurn` registry. `grug_smelting.RECIPES` is the
  public, iterable read surface the card makes binding: one entry per output,
  `{output, inputs = {a, b}, time}`, stable by `register_on_mods_loaded` time.
  `grug_smelting.match(a, b)` is the either-order matcher, an O(1) lookup on
  the *unordered* input pair. Nothing in this file calls the engine, which is
  what lets the KAT load the shipped bytes.
- `node.lua` — the ported node pair `grug_smelting:dual_furnace` /
  `:dual_furnace_active`: two material slots, two output slots, one fuel slot,
  node-timer driven, protection-aware `allow_metadata_inventory_*`,
  dig-only-when-empty, `on_blast` drops all three lists.
- `recipes.lua` — the five §3.2 cooking recipes, the five §3.3 alloys, the
  twelve §3.4 storage pack/unpack pairs, the §3.5 station recipe, and a startup
  self-audit that re-proves the whole surface against the engine's own craft
  system at every start.
- `textures/` — two re-skinned front faces plus `LICENSE-media.md`.

### The audit extension

`mods/ENTITIES/grug_traders/audit_alloys.lua` (new file, one appended `dofile`
line in `init.lua`, `grug_smelting` added to `optional_depends`). The §3.8
anti-loop walk in `init.lua` judges only `normal` and `cooking` *engine*
recipes, so the whole alloy chain was invisible to it. The new file walks
`grug_smelting.RECIPES` with the same `grug_traders.sell_price` resolution, the
same "an unpriced input is an unknown, not a free lunch" limit and the same
error-level report.

The judgement is the pure function `grug_traders.alloy_loop_findings(recipes)`
on purpose: an audit nobody has ever seen fire is not evidence, and both the
headless KAT and the in-engine probe make it fire on a deliberately overpriced
synthetic recipe.

## 2. The recipe surface (what a reviewer should compare against §3)

| Family | Count | Rows |
|---|---:|---|
| §3.2 cooking | 5 | copper/tin/iron/silver/gold lump → bar, 3 s each |
| §3.3 `dualfurn` | 5 | Copper+Tin→Bronze 4 s; Iron+**mined Coal**→Steel 6 s; Steel+Silver→Silversteel 8 s; Silversteel+Emberglass→Embersteel 10 s; Embersteel+Abyssal Crystal→Abyssal Steel 12 s |
| §3.4 storage | 12 pairs | all twelve `PROCESSED_MATERIALS` rows, 9 ↔ 1, both directions, derived from the registry (so the two `kind = "resource"` rows use the mined item, and the Gold Block sentence is covered) |
| §3.5 station | 1 | `{"", copper_bar, ""} / {copper_bar, default:furnace, tin_bar}` |

Input-form rule as the card fixes it: an alloy input is the material's **bar**
where a bar exists; mined Coal, Emberglass and Abyssal Crystal enter as their
mined items. `grug_materials:emberglass_shard` and every gem deliberately have
no recipe.

## 3. Cook times are calibration, not contract

The card's §1 "No number freezing" is binding, so these literals are WP26's own
first calibration and nothing else reads them:

- the normal furnace keeps the engine's 3 s, spelled out rather than inherited;
- the alloy ladder rises 4 / 6 / 8 / 10 / 12 s with the tier, starting one
  second above the normal furnace so the first station upgrade never feels
  slower than the station it replaces.

Measured in a running server (`logs/probe.31401.log`): the first Bronze Bar
appeared after **4 s** wall clock and the first Steel Bar after **6 s**, each
having consumed exactly one of each input, with the node swapped to
`dual_furnace_active`. WP22/WP44 may re-calibrate these freely.

## 4. Deltas between the card and today's code

The card is from 2026-08-13; the code has moved since. Where they disagree the
code is the fact and the card's intent governs. Each delta, and what was done:

1. **`grug_materials/migration.lua` no longer exists.** The card cites
   `migration.lua:12-60` for WP43's cleared recipes and `:16-19` for the
   surviving `default:pick_steel` verification tool. That file is today
   `mods/ITEMS/grug_materials/content_curation.lua`; the Steel-pick
   `clear_craft` is at `content_curation.lua:61` and is untouched, as the card
   requires.
2. **"Today no bar has any recipe" is still true, and `grug_traders`' comment
   about it was stale.** `init.lua` said the Iron Bar "is not worth more than
   the Iron Lump consumed by *the temporary upstream furnace recipe*" — but
   WP43 cleared `default:steel_ingot` and with it that cooking recipe, so no
   iron recipe existed at all when this lane started. WP26 restores exactly
   that pair (Iron Lump 3c → Iron Bar 3c, no profit), and the comment now names
   `grug_smelting` instead. One-line comment correction, in the audit commit.
3. **Node names.** The card calls the pair "dual furnace active/inactive" after
   LotT's `lottblocks:dual_furnace_active` / `_inactive`. Shipped as
   `grug_smelting:dual_furnace` (the placeable, crafted, dropped one) and
   `grug_smelting:dual_furnace_active`, mirroring `default:furnace` /
   `default:furnace_active` exactly — the pattern the rest of this game and
   this port already follow, and it keeps an `_inactive` suffix out of the
   creative inventory and the craft output. Same two nodes, different spelling.
4. **A third informational `action` line at startup.** The card's §8 runtime
   test plan names the two informational lines a clean `debug.txt` shows (the
   drop-audit count and `[grug_materials] registry audit passed`). WP26 adds a
   third, `[grug_smelting] recipe audit passed: 5 cooking, 5 dualfurn, 12
   storage pairs, 1 station`, following `grug_materials`' house pattern. It is
   informational, so card gate 4 ("no error/warning finding") is unaffected —
   but the user's runtime test should expect **three** such lines, not two.
5. **`BACKLOG.md` and `README.md`.** The card's T6 asks for the BACKLOG row and
   the README "Current State" in the same commit as the ROADMAP tick. This
   lane's brief does not list either file as its own, so both were changed in
   one small separate commit that the coordinator can drop if the docs-
   alignment lane collides with it.

## 5. The port, and what was deliberately not ported

Source: `reference_projects/Lord-of-the-Test/mods/lottblocks/crafting.lua` at
the pinned submodule commit `f164140` — **LGPL 2.1 code only**. `lottblocks`
media is CC BY-SA 3.0 and none of it is in the tree. Row in
[`VENDOR.md`](../../VENDOR.md) plus a "curated code port" note beside the
`grug_decor` one.

Ported: the station — node pair, slot layout, node-timer drive, either-order
matcher, `add_craft` registrar, fuel-slot filter. Dropped: LotT's own four
`dualfurn` recipes, its per-recipe `func` hook (no WP26 recipe uses one) and
its steel-tier furnace craft recipe (`crafting.lua:271-277`), which would
deadlock this ladder — Steel is T3 here and needs the station to exist.

Three deliberate departures, each documented at the site in `node.lua` and in
the VENDOR row:

1. **Time is `elapsed`, not one tick.** LotT adds exactly 1 to `fuel_time` and
   `src_time` per timer call (`crafting.lua:103,107`), so a late timer or a
   mapblock stepped forward in one call silently loses the difference. This
   port consumes the `elapsed` the engine hands it, like `default`'s furnace.
2. **Protection.** LotT's `allow_metadata_inventory_*` never ask
   `core.is_protected` (`crafting.lua:239-268`). Ours do.
3. **Recipes are a list, not an output-keyed table.** LotT keys every recipe by
   its output (`crafting.lua:30-34`), so a second recipe for the same output
   silently overwrites the first, and its matcher walks every entry of every
   recipe type on every timer tick (`:55-73`). Ours rejects a duplicate output
   or a duplicate input pair at registration and matches in O(1).

## 6. Verification, and what each layer is for

- **`tools/wp26/smelting_kat.lua`** — engine-free, loads the shipped
  `grug_smelting` and `audit_alloys.lua` against a stub engine (including a
  stub inventory the **real** node timer is driven through) and checks: surface
  exactness against an independently written expectation; forward-closure
  reachability of all six tier bars from mined items; every named itemstring
  registered; no regional, cultural or trophy input; twelve storage
  round-trips; either-order alloying; exactly one of each input consumed per
  output; Iron Bar + Coal-in-the-fuel-slot cooks nothing while Coal in a
  material slot makes Steel; the fuel slot refuses a non-fuel and the output
  slot refuses a put; no fuel, no smelt; and the anti-loop walk on both the
  shipped recipes (silent) and an overpriced synthetic one (caught).
  Byte-identical under LuaJIT and PUC 5.1: sha256
  `8e4ca28afdaf3d2194490542775fe55ece206f594201c178c5ac9440d1ebd7b9`.
- **The mutation gate** (`evidence/20260916/mutations.txt`) breaks five of
  those rules on purpose and shows the KAT goes red on each, then green again.
- **`tools/wp26/smelt_probe`** — a disposable probe staged with `PROBE=`. It
  forceloads one mapblock, places three dual furnaces, feeds them and polls
  once a second, because a node timer only runs inside an active mapblock and
  a headless server has no player to make one. It is what proves the station
  works as a *node*: `set_node` builds its inventory, the timer is stepped, the
  engine's fuel resolution burns Coal, and the bar appears.
- **`grug_smelting`'s startup self-audit** — the layer the KAT cannot reach: it
  asks the real `core.get_craft_result` whether the engine answers each of the
  23 registrations, and hard-fails the server start if not.
- **Static gates** — `tools/wp26/evidence/20260916/static.sh`: parser and
  SETGLOBAL per file and tree-wide, the five plain-5.1 sweeps scoped and
  tree-wide, `check_fresh_server.py`, the scope grep (run over the *registered
  surface* the KAT prints, because grepping the source would hit the audit
  code that has to name the stems it forbids), the no-globalstep /
  no-detached-inventory check, the no-price check, the LICENSE-media row check,
  the "no `lottblocks` media in the tree" check and the texture generator's own
  reproducibility check.

Nothing frozen elsewhere moved: the six start identities, Highcourt's blueprint
digests, the WP13 final micro pair and `tools/wp40/r7/run.sh unit` all produce
their pre-change values (digests in `evidence/20260916/README.md`).

## 7. What a review should look at

1. **The timer loop in `node.lua`.** It is `default/furnace.lua`'s structure
   with a two-slot matcher instead of `get_craft_result`. The loop's
   termination argument and the `fuel_totaltime - fuel_time` step are inherited
   from upstream; check the two places where this port differs (the explicit
   `take_item(1)` per slot, and `src_time = 0` when no recipe matches).
2. **Where the audit extension lives.** The walk is in `grug_traders` (the card
   says so), but the *judgement* is a pure function and the file is separate so
   the KAT can load it. If the reviewer prefers the whole thing inside
   `init.lua`'s existing callback, that is a one-file move — but then the
   negative test can only run in the engine.
3. **The chosen cook times** (§3 above), which are explicitly open for
   re-calibration.
4. **The node-name spelling** (delta 3) — the one place this lane deliberately
   chose the `default:furnace` convention over the card's wording.

## 8. What is open

- **The user's runtime test plan** (card §8, ~10 min, existing world is fine —
  no mapgen change): craft and place both furnaces, smelt the five bars, alloy
  the five in both slot orders, check the Steel fuel-slot refusal, pack/unpack
  a metal block, a resource block and the Gold Block, and confirm `debug.txt`
  shows no error/warning audit finding. Expect **three** informational `action`
  lines now, not two (delta 4).
- **Prices stay WP44's.** Every bar beyond Iron is unpriced, so the extended
  anti-loop walk is silent by construction today; the negative test is what
  proves it can speak. When WP44 prices the chain, this audited path re-proves
  it at every start with no further work.
- **`xpanes`' Steel Bar Door / Trapdoor** are still unreachable: they consume
  `xpanes:bar_flat`, whose recipe was removed with `default:steel_ingot`
  (VENDOR.md, review 2026-09-14). WP26 ships the Iron Bar's *smelting* recipe
  but no `bar_flat` recipe — that is WP29's catalog, not this card's surface.
- **No `grug_smelting` recipe is discoverable through a recipe book yet**; the
  craft_predict unlock gate and the per-profession book are WP10's.
