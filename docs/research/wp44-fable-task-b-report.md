All required reading and code inspection is complete. Everything needed is in the final report below.

---

# VERSIONED BASELINE GO

WP44's published rules (Common price axis, 5% ceiling buy-back, service tables, claim/mount time targets, denomination rounding) are fully decided and implementable now against WP43's shipped material identities. The Income Ledger is implementable **only as an explicitly versioned baseline**, because three income/sink behaviors the measurement references — quest rewards (WP8), NPC repair (WP22), and the WP10 consumable/recipe catalog — do not exist in the snapshot and must enter as versioned model inputs, never as claimed behavior. No user design decision is required for the versioned baseline; every remaining choice is a measurement-calibration constant the backlog explicitly assigns to WP44 (`source-main/BACKLOG.md:47` — "ledger copper values remain measured outputs owned with WP44, not open design").

Snapshot note: the required source set names `docs/process/agent-model-policy.md`; that file does not exist in this snapshot (only `docs/process/wp-workflow.md` is present). All findings below are against snapshot commit `7b6c876…`.

---

## 1. Canonical unit and observation window (Q1)

**Unit.** Reliable net solo income per tier is `R_T`, an **exact rational number of ledger copper per hour**, for tiers T1–T6, published alongside its integer floor. Copper is the only monetary unit (one integer in player meta, 100c = 1s, 100s = 1g, display-only conversion — `docs/design/economy.md:10-17`, `mods/PLAYER/grug_money/init.lua:3-13`). Physical Gold is never money (`economy.md:25-27`).

**Tier binding.** "Tier-appropriate" binds through the shipped 1-based bracket function `ceil(level/10)` clamped to 1..6 (`mods/ITEMS/grug_gear/init.lua:53-58`; bands confirmed at `docs/design/items_crafting.md:1053-1059`). Therefore:

| Target | Authority | Tier rate consumed | Duration |
|---|---|---|---|
| Claim I→II (level 35) | housing.md:112 | T4 | 30 min |
| Claim II→III (level 50) | housing.md:113 | T5 | 90 min |
| Claim III→IV (level 60) | housing.md:114 | T6 | 3 h |
| Second / third stone (level 60) | housing.md:167-170 | T6 | 5 h / 10 h |
| Mount level 15 / 30 / 45 / 60 | mounts.md:82-87, items_crafting.md:2020-2023 | T2 / T3 / T5 / T6 | 15 m / 45 m / 2 h / 5 h |

The T4/T5/T6 rows are stated outright in housing.md; the mount rows follow from the canonical bracket function (level 45 → bracket 5). This binding is part of the contract, not an open question.

**Observation window.** No authority document fixes a window; WP44 must author it as a **versioned constant**. Contract: `W = 3600 s` of continuous solo at-tier play, chosen because it equals the deterministic vendor-rotation period (`mods/ENTITIES/grug_traders/stock.lua:128-132`), so hourly-shelf effects average out exactly. `W` is a normalization constant of an analytic expectation (below), not a sampled play session; targets are `X_raw = R_T × minutes/60` computed in exact rational arithmetic, rounded half-up to integer copper, then passed to the denomination rule (§7).

## 2. Stream classification (Q2)

**Observed-current** (measurable from the snapshot registry; ledger reads them, never re-authors them in place):

| Stream | Evidence |
|---|---|
| Vendor payout of mob drops (trash + materials, 1–7c) | `mods/ENTITIES/grug_mobs/items.lua:4-141`; static `drops` tables, e.g. `boar.lua:70-74`, `bear.lua:61-65`, `golem.lua:143-147`; bandit function drops enumerated in `FUNCTION_DROPS` (`grug_traders/init.lua:110-116`), stolen purse 5c (`items.lua:23-28`) |
| Gathered natural resources with payouts: quartz 2c, rough G1 3c, silver 4c, emberglass 5c, rough G2 3c, abyssal crystal 6c, iron lump 3c, emberglass shard 1c, iron bar 3c | `grug_materials/ores.lua:16-27,55-59,132-136`; `registry.lua:218`; override `default:iron_lump` 3c (`grug_traders/init.lua:89-91`) |
| Payout resolution semantics: override → def `_grug_sell_price` → 0; 0 = unsellable | `grug_traders/init.lua:51-66` |
| Buy-back of vendor gear (currently legacy 25% floor; migrates to 5% ceil) | `grug_gear/init.lua:196-198` (legacy), target `economy.md:49-52` |
| Consumable cost: weak healing potion 8c (sell 2c), torch 1c, core tool stock | `grug_traders/stock.lua:52-64`, `potion.lua:73-85` |
| Same-race 10% discount, buy side only, `max(1, floor(p×0.9))` | `stock.lua:11-17`, `vendors.lua:120-145` |

**Modeled-future** (versioned model inputs; each row carries `status="modeled"`, owning WP, and a rerun trigger; the ledger never claims the game implements them):

| Stream | Owner | Model input in ledger v1 |
|---|---|---|
| Quest reward baseline (`economy.md:66,74-78`) | WP8 | contribution **0** in v1; rerun trigger at WP8 ship |
| Routine repair deduction (`items_crafting.md:1977-1981`: ~3000/6000 combat-event wear budget) | behavior WP22; **prices WP44-owned** (WP22 depends on WP44, `BACKLOG.md:45`) | deduction = authored repair-price schedule derived from the fixed Common axis (see §4) |
| WP10 consumables/food buffs/bandages/job supplies/draughts; cultural-master and Alchemist-helper services (`economy.md:94-106`) | WP10 | consumption rate constants; fee tables encoded verbatim, consumed by nothing until WP10 |
| Common-gear drop sale income (mobs dropping gear) | WP5 | 0 in v1 |
| Kill-rate / route pacing (kills·h⁻¹ per tier, gather events·h⁻¹) | WP44 constant set | derived deterministically from shipped mob HP scaling and Common weapon curve plus authored overhead constants |

**Excluded** (categorical, by authority — never part of `R_T`):

- Rare jackpots and named-rare trophies (`economy.md:79-83`, `items_crafting.md:1463-1473`).
- World/apex boss and king/Fallen Crown rewards (`items_crafting.md:1474-1513`; housing.md:116-117 "world-boss rewards").
- Player trade / player market (`economy.md:81-83`).
- PvP-only loot: guard war trophies and heavy cloth (NPC drops only in PvP — `BACKLOG.md:29` player-tag rule; `grug_mobs/guard.lua:178-181`) — not *solo PvE* income.
- Direct coin drops (none exist by design, `economy.md:21-24`); physical Gold as money; XP.
- Elite/rare-tier mobs in the v1 route model (versioned modeling choice; elites "improve item/source budgets", `items_crafting.md:1933-1935`).
- The rotating Uncommon shelf (WP5-gated, `items_crafting.md:1150-1155`).

## 3. Reliability statistic and determinism (Q3)

**Statistic:** the **exact expected value (arithmetic mean) of vendor-payout income per window**, computed in exact rational arithmetic from the registered drop tables — `economy.md:74-78` fixes "expected vendor value" as the loot-income measure — **made reliable by two structural gates rather than by trimming**:

1. **Categorical exclusion** of jackpot classes (§2 above).
2. **Concentration gates** on every included stream: expected event count in `W` must be ≥ `N_min` (versioned, v1: 10), and no single event's payout may exceed `c_max` (versioned, v1: 5%) of the tier's gross window income. A stream failing either gate is reclassified `excluded/jackpot` and the run records it. KAT: a synthetic table whose mean is dominated by a 1-in-500 drop must fail this gate.

Under those gates the mean and median of the per-window distribution converge, which is what "reliable rather than jackpot-dependent" means operationally.

**Determinism/reproducibility:** the ledger is a **pure function** of (snapshot commit, ledger schema version, versioned constant set). Expected values are computed analytically from mobs_redo's integer drop model (`chance` = 1-in-n, expected count `(min+max)/2` as a rational) — no runtime sampling. `math.random` is forbidden; any optional Monte Carlo *validation* uses `PcgRandom` with fixed recorded seeds (project precedent: `grug_traders/stock.lua:115,228`; AGENTS.md determinism rule). All arithmetic stays in Lua-5.1-safe integer range (±2^53, `docs/research/luanti-lua.md`); rationals are integer numerator/denominator pairs. Two runs on the same inputs must produce byte-identical artifacts (§6).

## 4. Repairs and consumables without circularity (Q4)

The dependency graph is acyclic **because the Common price axis is fixed a priori, not measured**:

```
fixed Common axis (25c/65c/1s60c/4s/10s/25s, economy.md §2)
   → authored repair-price schedule + consumable prices     (WP44 authors; WP22/WP10 implement later)
      → deduction D_T per window
         → R_T = (G_T − D_T)/W   (measured)
            → claim/mount/derived sink targets              (the ONLY values derived from measurement)
```

- **Repairs.** `items_crafting.md:1977-1981` fixes the wear budget (~3000 combat events ordinary, 6000 refined) and that cost scales on the tiered money axis. Ledger v1 models the routine repair deduction as `repair_cost_per_combat_event(T) = f_repair × (tier-T Common kit reference value) / 3000`, with `f_repair` a WP44 versioned constant and combat-events-per-window from the pacing model. This is a **model row** (WP22 has shipped nothing; the only current repair path is the vendored free grid `toolrepair`, `mods/BASE/default/crafting.lua:399-403`, which the ledger must *not* treat as the designed sink). The forbidden direction — deriving repair prices from measured `R_T` — is a stop condition.
- **Consumables.** Observed: potion 8c at an authored uses-per-window constant. WP10 items enter as zero-rate modeled rows until they ship. No consumable price is derived from `R_T`.

## 5. Versioning of absent behaviors and reruns (Q5)

Every stream row in the artifact carries `status ∈ {observed, modeled, excluded}`, `authority` (doc §), `owner_wp`, and `rerun_trigger`. The ledger identity is the triple **(schema_version, model_constants_version, snapshot_commit)**; changing any produces a new ledger version. Mandatory rerun triggers: WP5 (gear drops/quality roller), WP8 (quests), WP10 (consumables/recipes/services), WP22 (repair implementation — replaces the modeled deduction with observed behavior and must validate the v1 constant), WP26/WP29/WP30 (bars, gear catalog, trader retrofit), WP34 (density/socket economy), WP37 (the pending ×0.75 surface spawn-density multiplier changes kills-per-hour, `BACKLOG.md:60`), WP40 (map/zones/route times), WP41 (PvP eligibility). Published copper values in docs/design always cite the ledger version they came from; adopting a rerun's revised targets is a deliberate docs change, never an implicit drift — exactly the "not a stale global copper ratio" rule (`economy.md:81-83`).

## 6. Reproducible artifact: inputs, schema, provenance, encoding, digest (Q6)

- **Immutable inputs:** snapshot commit id; the versioned constants file (window, gates, pacing, `f_repair`, consumption rates); the extracted observable tables (drop tables, payout resolution results, price axis, discount rule) pulled headlessly from the registry (pattern: `tools/wp43/run.sh` + `materials_test.lua`).
- **Schema (top-level keys):** `schema_version`, `ledger_model_version`, `snapshot_commit`, `constants` (with own digest), `streams[]` (id, class, status, authority, owner_wp, per-window expected events, expected copper as `num/den`), per-tier `gross`, `deductions`, `net_rational`, `net_c_per_h_floor`, `targets[]` (consumer id, tier, minutes, `raw_rational`, `raw_rounded_c`, `denomination_chosen`, `published_c`), `audits[]` (id, pass/fail, evidence), `kats[]` (id, input, expected, got).
- **Canonical encoding:** a purpose-built stable serializer — sorted keys, integers and `num/den` strings only, no floats, fixed newline/UTF-8 — because neither `core.write_json` nor `core.serialize` guarantees key order.
- **Digest:** `core.sha256` over the canonical bytes is the artifact id (engine hashing precedent: `docs/research/wp40-engineering-brief.md:147,1859-1860,1926`), recorded in the WP44 completion record together with the snapshot commit.

## 7. Published rounding rules — exact integer formulas and KATs (Q7)

**Buy-back (5%, ceiling, per `economy.md:49-52` / `items_crafting.md:1963-1969`).** For integer reference price `p ≥ 0` copper:

```
buyback_cap(p) = floor((p + 19) / 20)        -- = ceil(p * 5 / 100)
payout(item)   = min(authored_payout, buyback_cap(reference_price))
```

KATs (full Common table): 25→**2** (doc anchor), 65→4, 160→8, 400→20, 1000→50, 2500→**125** = 1s25c (doc anchor); chest 20→1, 50→3, 130→7, 320→16, 800→40, 2000→100 = 1s; other 15→1, 35→2, 80→4, 200→10, 500→25, 1250→63.

**Discount/ordering.** Buy price = `max(1, floor(p × 0.9))` for same-race buyers only (`stock.lua:15-17`); buy-back always computed from the **undiscounted** reference (`economy.md:51-52` — the discount never raises buy-back). Anti-spread comparison (strict, shipped semantics `grug_traders/init.lua:180-187`): for every vendor-sold item, `payout < max(1, floor(0.9 × p))`. **Derived corollary (must be encoded):** any vendor-sold good with `p ≤ 2` must carry payout 0 — `buyback_cap(1)=buyback_cap(2)=1 ≥ discounted price 1`, so a positive payout fails the audit. Today only the 1c torch is affected and it is already unsellable (no def field, no override). Boundary KATs: p=2 → payout must be 0; p=3 → cap 1 < discounted 2, legal.

**Target denomination rounding (`economy.md:128-130`, `items_crafting.md:2013-2015`, `housing.md:118-120`).** For integer measured target `X ≥ 1` copper, try denominations `d` in order **100, 25, 5, 1**:

```
M(d)   = floor((2*X + d) / (2*d)) * d        -- nearest multiple, exact midpoint UP
accept d  iff  20 * |M(d) - X| <= X          -- within 5% (integer comparison)
publish M(d*) for the first (coarsest) accepted d
```

`d = 1` always accepts, so the procedure terminates with deviation 0 at worst. Provable property worth encoding as a comment/KAT: for integer `X` and this denomination set, `|M−X|/X = 5%` **exactly** is unreachable, so the inclusive `≤` boundary never actually decides; and an exact midpoint exists only for `d = 100` (`X ≡ 50 mod 100`), where the formula rounds up as required.

Boundary KATs:

| X (raw copper) | Result | Why |
|---:|---|---|
| 104 | 100 (1s) | dev 4/104 ≈ 3.85% ≤ 5% |
| 105 | 100 (1s) | nearest 100, dev 5/105 ≈ 4.76% |
| 110 | 110 | d=100 dev 10 (9.1%) ✗, d=25 dev 10 ✗, d=5 exact |
| 150 | 150 | d=100 midpoint→up→200, dev 33% ✗; d=25 exact |
| 950 | 950 | d=100 midpoint→up→1000, dev 50/950 ≈ 5.26% ✗; d=25 exact |
| 1050 | 1100 (11s) | d=100 midpoint→**up**→1100, dev 50/1050 ≈ 4.76% ✓ — the canonical midpoint-up acceptance |
| 1250 | 1300 (13s) | d=100 midpoint→up→1300, dev 4% ✓ — coarseness beats the raw value being an exact 25c multiple |
| 38 | 38 | d=5 gives 40, dev 2/38 ≈ 5.26% ✗ → d=1 |
| 21 | 20 | d=5 gives 20, dev 1/21 ≈ 4.76% ✓ |
| 0 or negative | **validation failure** | a non-positive target is a broken income model, never published |

## 8. Required audits and exact ordering (Q8)

All run at `register_on_mods_loaded`, silent when clean, extending the three shipped audits (`grug_traders/init.lua:100-299`):

1. **Coverage:** every mob drop (static tables + `FUNCTION_DROPS`) resolves to payout > 0 (`economy.md:57-59`). A miss is a ledger **stop condition**, not a warning to skip.
2. **Buy-back cap:** for every item with a payout, `payout ≤ buyback_cap(reference)`; for the Common catalog, payout equals the §7 table exactly.
3. **No buy/sell spread (discount included):** strict `payout < max(1, floor(0.9 × price))` for every vendor-sold item, including the ≤2c corollary above. Order: resolve reference → apply buy-side discount (floor, min 1) → compare against undiscounted-derived payout.
4. **Craft/cook anti-loop (strict):** output payout **strictly below** summed priced-input payouts (`economy.md:60-63`); judged only when all inputs price; keep the shipped nil-hole/`group:` handling (`init.lua:239-278`). Note the shipped comparison is `>` (equality passes) — WP44 must tighten to the doc's strict rule and re-price the one existing equality (iron lump 3c → iron bar 3c, gap G1 below).
5. **Storage-conversion (reversible-pair exception):** 9-unit pack/unpack pairs are exempt from audit 4's strict inequality and instead must satisfy **equality of the shared value budget**: `reference(block) = 9 × reference(unit)` and `payout(block) ≤ buyback_cap(reference(block))` (`economy.md:62-63`, `items_crafting.md:487-498`). Applies to gem blocks, Gold, metal blocks when WP26/WP10 register the recipes; the audit registers now and covers them the day they exist.
6. **Service fees:** the two §8.4 tables (`items_crafting.md:1988-1999`, `economy.md:102-106`) are encoded **verbatim as authored tables** — note the "50%" is motivation, not a formula (50% of the 25c weapon is 12.5c; the table says 15c). Audit: fee table equality, no same-race discount applied, and no service may increase an item's payout by more than fee + consumed-input payouts.
7. **Trader-substitution (WP44's share):** (a) time-to-buy invariance — tier-T Common kit price ÷ `R_T` must land in one authored band across all six tiers (`economy.md:74-78`); (b) NPC payouts for gems/cultural materials/bars stay floors: strictly below their value as crafted-recipe inputs so NPC selling never substitutes for player trade (`economy.md:72-73`, `items_crafting.md:1099-1102`). The catalog-side demand audit remains WP30's, consuming WP44's axis (`BACKLOG.md:53`).

**Validation failures / stop conditions:** unpriced mob drop; non-positive `R_T`; tier ratio `R_{T+1}/R_T` outside the authored ×2.5 band; concentration-gate breach; any modeled stream contributing more than an authored cap (v1: 25%) of a tier's net; derived targets non-monotonic across tiers/levels; rounding input ≤ 0; artifact digest mismatch on re-run; any repair/consumable price derived from measured income.

## 9. Verified gaps (severity-ranked; expected dependency work is *not* listed as defect)

- **G1 — Medium (contract drift, code weaker than decided design):** `economy.md:60-63` requires output vendor value **strictly below** summed input value, but the shipped craft-loop audit flags only `out_price > input_total` (`grug_traders/init.lua:267`), and the shipped data contains an exact equality: iron bar 3c (`grug_materials/registry.lua:218`) from iron lump 3c (`grug_traders/init.lua:89-91`, comment at `:83-84`). Failure scenario: under WP44's re-pricing, the audit as written silently accepts value-neutral conversion chains the design forbids; any future input-price nudge downward becomes an undetected printer. Resolution is inside WP44's calibration ownership (tighten the comparison, re-price the pair); no user decision.
- **G2 — Low (stale citation in code):** `grug_traders/init.lua:69-75` quotes "§8.1: 1–6c band"; the 2026-08-12 rewrite of `items_crafting.md` §8.1 (`:1930-1946`) no longer contains that band, and shipped prices already exceed it (stone_core 7c, sleek_pelt 7c — `grug_mobs/items.lua:91,114`). Comment cleanup lands with WP44's re-pricing pass.
- **G3 — Low (task-input discrepancy):** required source `docs/process/agent-model-policy.md` is absent from the snapshot; `docs/process/` contains only `wp-workflow.md`.
- **Expected, explicitly not defects:** the legacy WP7 price curve and 25% floor buy-back (`grug_gear/init.lua:41-48,196-198`) versus the decided axis — the migration *is* WP44 (`BACKLOG.md:67`, AGENTS.md traders section); missing reference values for cut gems (`ores.lua:61-66` registers them priceless), Gold, most processed bars, cultural materials and trophies — §8.1 (`items_crafting.md:1939-1943`) makes authoring them a WP44 output; absent repair NPC, quests, mounts, food buffs, bandages — owned by WP22/WP8/WP31/WP10 and modeled per §5.

## 10. Later implementation ownership and review gate (no files touched now)

WP44 would own: `mods/ITEMS/grug_gear/init.lua` (Common-axis `BRACKETS`, `buyback()` → §7 formula, API surface preserved for WP30); `mods/ENTITIES/grug_traders/{init,stock,potion}.lua` (audit extensions §8, re-priced core stock/payouts); `mods/ENTITIES/grug_mobs/items.lua` (revised material/trophy values); reference-value additions in `mods/ITEMS/grug_materials/{registry,ores}.lua` (gems/Gold/bars/cultural/Abyssal — respecting grug_materials' taxonomy ownership); a new single-owner reference-price catalog module (the "economy catalog" of `economy.md:53-56`) rather than scattering literals; `tools/wp44/` (headless Lua 5.1 ledger generator, KATs, audit regressions — `tools/wp43` pattern, `luac51 -p` checked); and the docs fold-in (economy.md §4.1/§4.2, items_crafting.md §8, housing.md §2/§10, mounts.md §2 calibrated copper values citing the ledger version) plus BACKLOG/README per AGENTS.md.

**Independent-review/evidence gate** (per `docs/process/wp-workflow.md:49-99`, tightened for WP44): a different reviewer than the implementer must (1) re-execute the ledger generator headlessly and confirm a **byte-identical artifact digest**; (2) verify every §7 KAT including the two doc anchors (25c→2c, 25s→1s25c) and the 1050/950 midpoint pair; (3) re-run the audit suite on a fresh registry load and confirm silence; (4) verify the §8.4 service tables verbatim against the docs, not recomputed; (5) grep-verify no consumer bypasses `grug_money`/`grug_traders`/`grug_gear` APIs or hardcodes a copper boundary; (6) confirm every modeled row cites its owner WP and rerun trigger and that no code path pretends WP8/WP10/WP22/WP31 behavior exists. User runtime test plan: buy/sell spot checks at a race vendor (discount, buy-back, refusal of unsellable), `/money` accounting, and one full loot-sell loop.

**User decisions required: none** for the versioned baseline. All open items in the neighboring TODO files — WP10 recipes (A1/A4/A5/E21), WP22 pick `times`/`uses` (B22), mount assets/behavior (D12/D14–D20), depth-pulse geometry — are deliberately *not* decided by WP44 and are untouched by this contract.
