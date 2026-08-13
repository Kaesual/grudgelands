# WP44 Economy Rebase — Engineering Brief

Status: **Implementation-ready engineering contract, authored 2026-08-13
(post-WP40 planning pass); not an implementation or shipped-WP claim.**

The design is closed and is not reopened here: the Common price axis
(25c/65c/1s60c/4s/10s/25s and the derived slot tables), the
ceiling-rounded 5% buy-back, the ledger-only money rule, the
denomination/rounding algorithm, the claim material+time targets and the
four mount time targets are decided in
[`economy.md`](../design/economy.md) §§2–4 and
[`items_crafting.md`](../design/items_crafting.md) §8;
[`housing.md`](../design/housing.md) §2 owns the claim tables. This brief
freezes how WP44 implements and **measures** — its methodology decision
(2026-08-13): the Income Ledger is a **deterministic derivation from
shipped data tables plus a one-time instrumented sanity validation**, never
a hand-typed "measured" number and never an unreproducible play log.

Explicitly out of scope: catalog renames (WP29), trader-catalog
retrofit (WP30), recipes (WP26/WP27/WP10), any WP7 Completion Record edit.

## 1. Cutover scope

WP44 changes the running WP7 legacy economy to the target rules:

1. **Catalog prices**: the `grug_gear` generator's price parameters move to
   the `economy.md` §2 slot table **verbatim** (weapon 25c…25s; chest
   20c…20s; offhand/head/legs/feet 15c…12s50c). The generator, bracket
   structure, rotation and ilvl anchors are untouched; only the price
   function changes.
2. **Buy-back**: `grug_traders` replaces the legacy 25% with the decided
   cap — **5% of the applicable purchase or authoritative reference price,
   rounded up to the next copper**. The same-race discount never raises
   buy-back (`economy.md` §2). `_grug_sell_price` stores the resulting
   payout; `grug_traders.set_price` covers foreign defs; 0 stays
   "not sellable", while every mob drop keeps a positive payout.
3. **Reference-value catalog**: one data module (inside `grug_traders` or a
   new `grug_economy` data file — implementation's choice, single owner)
   assigns every unsold-but-sellable concept an authoritative reference
   price: raw resources, Rough/Cut gems, Gold, Emberglass, Abyssal
   Crystal, processed bars, cultural materials, trophies and Fallen-Crown
   provenance items. The exact copper values are **WP44 implementation
   outputs constrained, not chosen freely**: they must (i) satisfy every
   anti-profit-loop inequality in §4, (ii) scale monotonically on the
   approximate ×2.5 tier index (`economy.md` §2/§3), (iii) keep the WP43
   raw-value band ordering (Quartz < Garnet < Silver < … within their
   tiers) unless an audit forces a documented revision, and (iv) never pay
   more than the 5%-ceiling rule at any vendor.
4. **Service fees**: the decided cultural-master/weapon-helper/Alchemist
   50% fee tables (`items_crafting.md` §8.4) enter the same data module.
   The NPCs arrive with WP10/WP13; WP44 ships the data and the audit that
   the tables match the decided values.
5. **Derived sink prices**: claim upgrades, additional stones and the four
   mounts receive their ledger copper values from §3's derivation with the
   published rounding rule. They are stored as data with full provenance
   (§5), not hardcoded magic numbers.

## 2. Income Ledger — data schema

One canonical, versioned record set. All values integer copper or exact
rationals rendered to fixed decimals; every table is keyed and sorted
canonically so the report serializes deterministically.

```
ledger_manifest:
  schema_version, game_commit, data_checksums[ (file, sha256) … ],
  constants{ pacing_minutes_per_level_band[], potion_use_per_min[],
             repair_fraction, validation_band = 0.30 },
  world_label (WP18/WP36 or WP40 map), date

per_tier[T1..T6]:
  level_band, reference_roster[ (mob, level, weight) … ],
  kills_per_active_minute,             -- derived, §3.1
  expected_gross_copper_per_kill,      -- derived, §3.2
  gross_income_per_minute,
  repair_cost_per_minute,              -- §3.3
  consumable_cost_per_minute,          -- §3.3
  net_income_per_minute,               -- gross − deductions
  exclusions_applied[ … ],             -- §3.4 audit trail
  sensitivity{ mining_income_note, quest_income_note }

derived_prices:
  claim_upgrade[I_II, II_III, III_IV]{ minutes, tier, raw_copper,
                                       rounded_copper, denomination },
  additional_stone[2nd, 3rd]{ hours, raw_copper, rounded_copper, … },
  mount[apprentice, journeyman, expert, master]{ minutes, tier_band,
                                       raw_copper, rounded_copper, … }

baseline_vs_candidate:
  per-tier gross/net income under the legacy WP7 economy (25% buy-back,
  old curve) and under the candidate rebased economy, same roster and
  constants — the migration's income effect, recorded once.
```

## 3. Income Ledger — deterministic derivation

### 3.1 Kill throughput (the one design-derived constant set)

Kill throughput is **derived from already-decided pacing**, not invented:

- minutes per level come from the decided 10–20 h to level 60 envelope
  (`items_crafting.md` §2.4: ~10–20 min per level). The ledger uses the
  midpoint 15 min/level as the frozen constant, recorded per band in the
  manifest;
- kills per level follow mechanically from the shipped `grug_xp`
  level-curve (`level_to_xp`) divided by the at-level kill XP
  (`XP = 10·L`, `biomes_mobs.md` §0), read from the real code tables in
  the harness — never re-typed;
- `kills_per_active_minute = kills_per_level / minutes_per_level`,
  computed per level and averaged over the band with equal level weights.

Quest XP share is deliberately **not** subtracted in v1: WP8 has not
shipped, so all leveling XP is kill XP today and the derivation matches
the running game. When WP8 lands, the reviewed rerun (§7) splits the
envelope and the constants change under version control, not silently.

### 3.2 Expected gross income per kill

Exact expectation over the band's reference roster: for each mob, the sum
over its drop table of `chance × count_expectation × payout`, where payout
is the candidate `_grug_sell_price`/reference value. The reference roster
per band is the §4 spawn-table families whose level range intersects the
band, weighted by their spawn budget share (`wp6_spawn_budget.md` cell
Σaoc weights) — a deterministic, checksummed input, not a modeled hunt
route. Elite/rare **windows** and named-rare/boss tables are excluded
(§3.4); the ordinary 1-in-10 elite spawn roll of the two elite-variant
families stays included at its authored probability because it is ordinary
ambient income, not a jackpot.

### 3.3 Deductions

- **Repair**: cost per combat event = `repair_fraction ×
  Common_reference_price(slot, tier) / wear_budget`, with the decided wear
  budgets (≈3,000 events ordinary, 6,000 refined —
  `items_crafting.md` §8.3) and a full Common kit (weapon + 4 armor +
  offhand) at the band's tier. `repair_fraction` — the fraction of an
  item's Common price a full wear cycle costs — is a WP44 implementation
  input frozen in the manifest before calibration, bounded to 10%–40%,
  and it is also the repair-price table the game ships (§1). Combat
  events per minute derive from the same §3.1 throughput (events ≈ swings:
  weapon FPI over active fighting time, recorded formula in the tool).
- **Consumables**: potion/bandage usage per active minute is a frozen
  manifest constant per band (starting proposal: one weak/standard healing
  potion per 3 active minutes, adjusted only through the reviewed-change
  path), priced from the candidate catalog.

### 3.4 Exclusions (decided; the ledger enforces and logs them)

Excluded from income: named-rare and boss/king loot windows and trophies,
Fallen Crowns, world-boss rewards, dragon-socket yields, player trade,
vendor arbitrage, jackpot-window Uncommon/Rare drops. Gathering/mining
income is excluded from the **calibration axis** and reported once in the
sensitivity annex (combat farming is the reference activity; mining pays
in materials whose value the same catalog prices, so a mining-heavy player
out-earning the axis is expected and acceptable). Quest income: see §3.1.

### 3.5 Sanity validation (the only runtime step)

One instrumented GUI session per band (user, ~10–15 active minutes): a
small logging aid records kills/min and gross loot copper/min. The
derived constants must fall within **±30%** of the session values. A miss
is a finding: the constant (or the roster weighting) is revised through a
reviewed change and the full ledger reruns. Session logs are archived as
evidence; they never become the published axis. Bands the user cannot yet
reach at test time (T5/T6 before content exists) record
`validation = deferred` explicitly — the derived value stands, labeled,
and the deferred validation is a listed follow-up, not a silent pass.

## 4. Audits (rerun and extended)

All three WP7 startup audits stay and run against the candidate values:
every mob drop priced; no vendor buy/sell spread that prints money
(discounts included); no craft/cook recipe whose output value exceeds its
priced inputs. Extended for WP44:

- **Pack/unpack budget**: every nine-unit storage cycle is value-neutral
  in both directions (one shared reference budget, `economy.md` §2).
- **Service-fee audit**: shipped fee data equals the decided §8.4 tables.
- **Buy-back cap audit**: for every sellable item,
  `_grug_sell_price ≤ ceil(0.05 × reference)` with the exact two decided
  anchor checks (T1 Common weapon → 2c, T6 → 1s25c).
- **Trader-substitution audit**: for each tier, compare the vendor Common
  path against the crafted G2-bearing path (T4–T6 base gear consumes its
  specific Cut G2, `items_crafting.md` §3.8): report the copper-and-time
  cost of "just buy Common" versus "craft" and assert the decided
  structure survives — vendor gear stays a floor (available, expensive,
  never refined/enchanted) and cannot erase crafted G2 demand. This is the
  audit WP30 later re-consumes; WP44 owns its first run on target prices.
- **Anti-loop under fees**: helper services (50% tables) plus supplied
  materials must never yield an output whose reference value exceeds
  inputs plus fee (no service-powered money pump).

Failures block the WP; they are fixed by revising the constrained
reference values (§1.3) and rerunning, never by weakening an audit.

## 5. Reproducibility contract

- The ledger and every audit run headless as **real-code Lua 5.1**
  harnesses under `tools/wp44/` (WP39/WP43 pattern): they load the shipped
  data tables (`grug_gear` generator, drop tables, price/reference module,
  `grug_xp` curve) in the stub environment via `tools/bin/lua51` — no
  number is re-typed into the tool.
- One documented command reproduces everything, e.g.
  `tools/bin/lua51 tools/wp44/ledger.lua > report/wp44-ledger.json` plus a
  checksum step; the canonical JSON report is byte-identical across reruns
  on the same commit (sorted keys, fixed decimal rendering, no
  timestamps inside the canonical body — run metadata lives in a sidecar).
- The report embeds the manifest (§2) including SHA-256 checksums of every
  input file and of the report body itself; raw sanity-session logs are
  archived beside it. Repository evidence: the frozen report and manifest
  land under `docs/research/` (summary) with raw JSON in the tool's
  `report/` directory; no invented value can enter — every published
  copper output must be recomputable from the command above.

## 6. Handling missing WP40/WP24 inputs

- The ledger is executable on the shipped WP18/WP36 world **now** (its
  BACKLOG dependencies WP7/WP43 are ✅): drop tables, sell values, XP
  curves and wear budgets are map-independent. `world_label` records which
  map the roster weights came from; after WP40's spawn-cell migration the
  same command reruns cheaply and the label flips. Differences beyond
  roster-weight noise are findings, not silent updates.
- WP24 needs WP44's claim copper values; WP44 needs **nothing** from WP24
  — capacity limits are not price inputs. The derived claim/mount prices
  are published as data with provenance so WP24/WP31 consume them by
  reference.
- Mount purchase levels map to income bands mechanically: level 15 → T2
  band, 30 → T3, 45 → T5, 60 → T6 (bracket arithmetic, 1-based bands).
- Rounding is exactly the published rule: coarsest denomination in
  `1s / 25c / 5c / 1c` whose nearest multiple stays within 5% of the raw
  target; exact midpoints round upward (`economy.md` §4.1, `housing.md`
  §2). The tool implements it once; claims and mounts both call it.

## 7. Change discipline

Constants (pacing midpoint, repair fraction, potion rate, roster weights)
change only through a reviewed commit that states old value, new value,
evidence and consequence, followed by a full ledger + audit rerun — the
WP40 brief's reality-check rule applies by analogy. After WP44 ships, a
later WP that changes drop tables, prices or pacing must rerun the ledger
command and update the derived sink prices in the same change or record
why not.

## 8. Task DAG

| Task | Owned result | Requires | Completion gate |
| --- | --- | --- | --- |
| T0 — harness + manifest | `tools/wp44/` stub-env loader for gear/drops/xp/price tables; manifest with input checksums | merged WP43 `main` | tables load byte-identically; checksums stable |
| T1 — reference-value catalog | one owner module with every §1.3 value under the four constraints; constraint checker | T0 | checker green; no unsold sellable concept missing |
| T2 — price migration | §8.2 catalog prices verbatim; 5%-ceil buy-back; discount interplay | T0 | anchor checks (2c/1s25c); generated catalog diff reviewed |
| T3 — ledger derivation | §3 computation, baseline-vs-candidate run, canonical report + checksums | T1, T2 | byte-identical rerun; every §3.4 exclusion logged |
| T4 — sanity validation | instrumented session aid; per-band validation records; constant freeze | T3 | each reachable band within ±30% or reviewed revision + rerun; unreachable bands labeled deferred |
| T5 — sink derivation | claim I→II/II→III/III→IV, 2nd/3rd stone, four mounts through the rounding rule; provenance data | T3 (T4 for freeze) | recomputable from the command; denominations legal; housing/economy tables' material halves untouched |
| T6 — audits | §4 suite green on candidate values | T1–T3 | zero failures; substitution report archived |
| T7 — docs + gates | BACKLOG ✅ row, ROADMAP/README sync (WP7 legacy boundary lifted), evidence summary in `docs/research/`, mandatory review per `wp-workflow.md` | T0–T6 | clean review; runtime test plan (buy/sell/price spot checks) delivered |

T1/T2 are parallel after T0. The WP7 Completion Record is never edited;
the README "Current State" caveat about the legacy price curve is removed
in T7's same commit that flips the BACKLOG row.

## 9. Acceptance gates

1. Shipped catalog prices equal `economy.md` §2 verbatim; buy-back is
   exactly ceiling-5% everywhere; discount never raises it.
2. Every sellable concept has a positive constrained reference value; all
   §4 audits green.
3. The ledger report is reproducible byte-for-byte from one documented
   command on a clean checkout; all input checksums match.
4. Every published claim/mount copper value is recomputable, correctly
   rounded, and carries provenance (tier, minutes, raw value,
   denomination).
5. No "measured" number exists without a derivation or an archived
   validation record; deferred validations are explicitly labeled.
6. Baseline-vs-candidate income table archived; WP7 Completion Record
   untouched; BACKLOG/ROADMAP/README synchronized.
7. `tools/bin/luac51 -p` and the five Lua 5.1 grep sweeps clean on every
   touched file; WP39/WP43 regression suites unaffected.
