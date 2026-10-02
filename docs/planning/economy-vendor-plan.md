# Economy, vendors, loot prices and gem tiers — plan

Design session with the user on 2026-10-02 (Claude Opus 5.5). Plan only:
nothing here is implemented yet. Implementation runs later as lanes
coordinated by the Round 28 coordinator (§8). This plan absorbs **WP44**
(economy, lighter pass) and adds the new vendor model, the loot price
formula and the depth-tiered gems.

## 1. Rulings (user, 2026-10-02)

| # | Ruling |
|---|---|
| 1 | Vendors sell **supplies, consumables, tools, the Common gear floor and a few T1 basics**. Every crafting ingredient from T2 up and every enchant input (signature loot, family input) comes **only** from loot, mining or gathering. |
| 2 | The moving **Common gear floor stays**: plain gear of all six brackets at the race vendor, the faction quartermaster, the smith and the armourer (tanner and bowyer keep their filtered views). |
| 3 | Non-crafting **flavour shelves stay** (mason's building blocks, candles, food to eat). |
| 4 | The **5% buy-back** applies only to items a vendor also sells (gear, supplies). Loot and gathered materials get their payout **directly from one formula** (§3); there is no separate invented "reference price" for them. |
| 5 | The craft anti-loop rule becomes **"output payout ≤ summed input payout"** (break-even allowed, profit forbidden). |
| 6 | Calibration target: **one band of the main route (quest copper + selling loot) pays for roughly two to three complete Common vendor sets of that tier.** Rough target, not a gate. |
| 7 | **Gems are depth-tiered, not regional.** Each of the six gem species has one tier and occurs only in the tier rock of that tier, everywhere on the map; it can be mined only with a pick of that tier. |
| 8 | Gem tiers: **T1 Citrine, T2 Jade, T3 Garnet, T4 Sapphire, T5 Ruby, T6 Diamond.** |
| 9 | **Quartz stays** the common T1 mineral at all depths, as today. |
| 10 | **Cultural materials and signature woods stay regional** (cultural finishing is bound to the crafter's culture on purpose). |
| 11 | Loot price formula with classes, tuned once against the median kill value (§3). |
| 12 | Quest copper keeps the Round 28 rule `0.08 × P(T) × weight` with the new price column (§4). |
| 13 | The shelf table of §2.3 is adopted, including arrows in the core stock and an almost empty herbalist. |

## 2. Vendor model

### 2.1 The rule

> Vendors sell supplies, consumables, tools, the Common gear floor and a few
> T1 basics. They never sell an enchant input, and never a crafting
> ingredient above T1.

**Why.** The user wants ingredients to come from the world: hunting,
mining and gathering are the game, and Round 28 built loot tables per tier
band precisely so that every enchant needs one creature part and one mined
or gathered item. A vendor that sells those parts makes the hunt optional.
T1 basics stay buyable because T1 is the tutorial band: a new player can
try a recipe before knowing where tin is. The gear floor stays because it
is not an ingredient (gear cannot be taken apart) and because the Round 28
solo promise ("main route solo with quest-reward and vendor-level
equipment", frame §2.4) depends on it.

### 2.2 What the "old rule" actually was

The user remembered a rule like "everything must also be buyable". No such
sentence exists in docs, git history or memory. What exists:

1. **Moving vendor floor** (`professions.md` §4, `items_crafting.md` §0,
   §3.7, §3.8, `economy.md` §1): vendors sell the lowest tier of each
   category, but the floor moves with the player, so Common gear of all six
   tiers is buyable ("guaranteed, but expensive"). This is about **gear**
   and stays (ruling 2).
2. **Profession shop shelves** (`settlements.md` "Profession vendors", WP13
   playtest round 3): "a shelf of its own trade" — a flavour rule. Agents
   filled the shelves in `grug_traders/stock.lua` with bars up to steel,
   leathers up to sleek pelt, cloth up to spider silk, the Alchemist-only
   herbs, T4–T6 cooking inputs, rock salt and stormkelp (T5/T6 enchant
   family inputs) and boar tusk (a T1 enchant stat input). **This is what
   ruling 1 replaces.**
3. `items_crafting.md` §0 "vendor supplies (thread/vials) as small gold
   sink" — already in line with ruling 1 and kept.

### 2.3 Shelves after the change

| Vendor | Keeps | Removed |
|---|---|---|
| Core stock (race vendor, faction quartermaster; every start and capital) | small bag, weak healing potion, torch, wood/stone tools, bronze pick, thread, parchment, vial, **player arrows (new)**, the six gear brackets | — |
| Butcher | raw and cooked meat, `mobs:leather`, light leather | heavy leather, boar tusk |
| Fishmonger | raw fish | scaled hide, crocodile tooth, stormkelp |
| Baker | corn, potato, melon, bread | mushroom (T3) |
| Tailor | linen scrap, wool | linen cloth, heavy cloth, spider silk |
| Smith | bronze bar, bronze tools, gear brackets | iron bar, steel bar |
| Armourer | bronze bar, gear brackets | steel bar, heavy leather, heavy cloth, shiny scale |
| Tanner | `mobs:leather`, light leather, leather gear view | heavy leather, sleek pelt, ape hair |
| Bowyer | player arrows, stick, feather, bow gear view | sharp feather |
| Brewer | weak healing potion, apple | wild cocoa, marshbloom, rock salt |
| Herbalist | vial, parchment, weak healing potion | all herbs, venom gland, slime gel |
| Embalmer | candle, linen scrap, bone, rotting flesh | gravesalt |
| Mason | unchanged | — |

Arrows go into the core stock because a start town has only its race
vendor and a Scout must be able to restock there. The herbalist sells no
herbs because herb gathering is gated to the Alchemist (`professions.md`
§1); selling them to everyone undid that gate. Gravesalt is a cultural
material and stays a gathered regional good (ruling 10). Exact item ids
follow `stock.lua`; anything not listed and not a T1 basic is removed.

### 2.4 Enforcement

Extend the existing shelf audit in `grug_traders` (one load check, no new
framework): a shelf entry fails when the item is an enchant input
(`enchants.json` stat loot or family input), an own material above T1, or
any ingredient whose tier is above T1. *Why:* the rule is cheap to break
by a later shelf edit and cheap to check at load.

## 3. Price formula for loot and gathered materials

### 3.1 Formula

`payout = max(1, round(class value × tier factor))`

The **tier factor** is the Common weapon axis divided by 25c:
**1 / 2.6 / 6.4 / 16 / 40 / 100** for T1–T6.

| Class | T1 value | Members |
|---|---:|---|
| Trash / food | 1c | meat, bone, feather, linen scrap, stolen purse, raw fish, sticks, apples, rotting flesh |
| Raw material | 1c | ore lumps, coal, quartz, gold, silver, emberglass, abyssal crystal, herbs, gathered plants, band fish |
| Generic material | 2c | leathers, cloth, teeth, hides, silk and other `generic` catalogue loot |
| Signature loot | 3c | every `signature` item in `grug_mobs/data/items.json` |
| Gem | 4c | rough gem; a cut gem pays the same as its rough gem |
| Processed | sum of inputs | bars, leather grades, cloth bolts, settings, wood grades (ruling 5) |

**Item tier**: the `tier` field for catalogue items; the harvest tier for
mined resources (coal, copper, tin, iron, quartz T1; gold T2; silver T3;
emberglass T4; abyssal crystal T5; gems by ruling 8); the raw tier of
`items_crafting.md` §3.7 for plants; the band for band fish.

Processed payouts follow the metal chain, e.g. bronze 2c, steel 2c,
silversteel ≈ 8c, embersteel ≈ 24c, abyssal steel ≈ 64c (exact values
follow from the tuned class values). Supplies a vendor sells at 1–2c
(thread) stay unsellable and count 0 in a sum.

**Why.** One formula replaces ~150 hand-set prices and the placeholder
"tier = copper" for signature loot (`grug_mobs/subtypes.lua`). It puts
loot on the same ×2.5 axis as gear and quest money (`economy.md` §3), so
time-to-buy stays constant across tiers. Deriving the payout from the
existing `kind` and `tier` fields means **no edit to `items.json`** is
needed while Round 28 lanes work in it.

### 3.2 Calibration (measured once)

Computed from `drops.json` with the class values above (2026-10-02):

| Band | Target ≈ 3c × factor | Median kill | Range over families |
|---|---:|---:|---|
| 1 | 3c | 2.7c | 1–5c |
| 2 | 8c | 5.7c | 3–14c |
| 3 | 19c | 9.7c | 4–107c |
| 4 | 48c | 22.7c | 16–117c |
| 5 | 120c | 108c | 42–212c |
| 6 | 300c | 110c | 69–482c |

Today the same tables pay a flat ~3c (T1) to 4–16c (T6) per kill. The
price lane tunes **only the five class values** once so the per-band
median lands near the target; the formula stays. Outliers (scavenger and
stone families in bands 3–4, outlaws in 5–6) are left alone unless they
exceed roughly four times the target. *Why:* the user prefers rough
targets over per-item tuning.

Rough band check for band 1: about 45 route kills plus free play at ~3c
≈ 150c, quest copper ≈ 70c, total ≈ two T1 vendor sets of 105c (ruling 6).
Later bands are longer, so they tend toward the upper end; mounts and
respec absorb that because they are priced from measured income (§5).

### 3.3 Every mob drop and every gathered item is sellable

Copper and tin lumps, coal, all gathered plants and herbs become sellable
under the formula. *Why:* `economy.md` §3 already promises that gathered
materials enter the sell-price system; today they pay 0.

### 3.4 Gear, supplies and buy-back (WP44 cutover)

- Gear moves to the target axis of `economy.md` §2 (weapon 25c, 65c, 1s60c,
  4s, 10s, 25s; chest and other rows as tabled) and the **5% ceiling
  buy-back** (`ceil(price / 20)`).
- The same-race 10% discount stays buy-side only.
- Repair reads the new reference purchase price (`grug_gear`), so the
  20% repair quote moves with the cutover (`durability_repair.md`).
- The audit fixes WP44 already lists: recipes with `group:` inputs are
  judged with the cheapest priced group member instead of being skipped,
  and the comparison becomes ruling 5's `≤`.

## 4. Quest copper

Keep the Round 28 calibration rule (`round28/design/catalog/calibration.md`
"Copper rule"): `copper = round_half_up(0.08 × P(T) × weight)`, minimum 1c,
with **P = 25 / 65 / 160 / 400 / 1,000 / 2,500** (the cutover column).
A T1 3-KE hunt pays 6c, a T6 one 6s.

**Recommendation to the coordinator:** since the cutover is now decided,
the Round 28 quest lanes write `rewards.copper` with the cutover column
right away. Otherwise lane E3 (§8) recomputes all `rewards.copper` values
mechanically from `weight` and `level` after the quest lanes merge.
Island bounty amounts use the same column.

## 5. Safety net and sinks

- **No vendor fallback and no new mechanism.** The supply guarantee is:
  the Round 28 rule that every stat loot item of a tier drops from an
  ordinary, solo-accessible mob in every race track of that band; ores and
  (after §6) gems occurring everywhere by depth; Leatherworker ×5 leather;
  player trade as an optional extra. The enchant validator already fails
  on an input above its enchant tier.
- **No new money sinks.** Fewer vendor purchases leave more money with the
  player. Mount prices (15 min / 45 min / 2 h / 5 h) and respec (5 min) are
  derived from measured income, so they absorb it. Repair, consumables,
  bags, supplies and the gear floor stay as planned.
- Mount and respec prices replace the placeholders
  `grug_mounts.COORDINATOR_PLACEHOLDER_PRICES` and
  `grug_classes.COORDINATOR_PLACEHOLDER_RESPEC_PRICES` after a **simple
  income estimate**: quest copper plus expected loot payout per hour on a
  selected route per band, minus routine repair and potions. A short
  script or table over `drops.json`, the quest files and the price
  formula; no checksummed ledger (WP44 lighter pass, D1). Rounding as in
  `economy.md` §4.1.

## 6. Gem tiers (rulings 7–10)

### 6.1 The rule

| Tier | Tier rock | Gem | Harvest tier |
|---|---|---|---|
| T1 | `default:stone`, y ≥ −100 | Citrine | T1 |
| T2 | `t2_stone`, −101…−300 | Jade | T2 |
| T3 | `t3_stone`, −301…−500 | Garnet | T3 |
| T4 | `t4_stone`, −501…−700 | Sapphire | T4 |
| T5 | `t5_stone`, −701…−1000 | Ruby | T5 |
| T6 | `t6_stone`, below −1000 | Diamond | T6 |

- Each gem occurs **only in its own tier rock**, identically in every race
  region, every zone and both factions.
- Its harvest tier equals its tier, so an exposed gem in a cave wall is
  also gated by the engine-native pick level (Round 24 rule).
- Density: one rough target for all six, about **one gem per 512 eligible
  host nodes in its band**; the existing deep multipliers (+25% below
  −1500, +50% below −2000) keep applying to Diamond. The mapgen lane checks
  this with one short run.
- Rough → Cut, the 9-gem storage blocks and the Goldsmith bonus yield
  (10%/20%) are unchanged. Quartz is unchanged.

**Why.** The regional G1/G2 split made mining "where" on top of "how deep",
and it silently blocked enchants: a Human needs Rough Garnet at T2 (found
only in Dwarf and Orc regions) and Accord daggers and bows need Rough Ruby
at T4 (Throng only). Mining is already demanding enough; one depth ladder
for ores and gems is easier to learn and needs no contested route. Gems
need only one band because no pick is made from them.

### 6.2 Consequences

- **Retired:** grades G1/G2, the per-race gem assignment (gem columns of
  the race-region table), the faction-exclusive G2 and its required T4
  contested route, the gem share of the natural-resource parity rule, and
  the G1/G2 rows of the density table.
- **Enchant inputs** (`grug_professions/data/enchants.json`): every
  family that uses a gem today keeps a gem, now chosen by tier — the gem
  of the enchant tier, or a lower-tier gem where variety wants it. The
  load check (input tier ≤ enchant tier) enforces it.
- **Goldsmith** (`grug_artisans/goldsmith.lua`): gem rows get the new
  tiers; trinket and spellbook recipes pick gems by recipe tier instead of
  a `g1`/`g4` pair; the bonus-yield check drops its `grade` test.
- **Woodcarver** (`grug_artisans/woodcarver.lua`): main/offhand gems by
  tier.
- **Help text** (`grug_inventory/help.lua`): one depth list for ores and
  gems, no "the region's gem".
- **Mapgen**: a mapgen change, so it runs **after Round 28** (no mapgen
  during Round 28) and needs a freshly prepared world (fresh-server mode,
  no migration).

## 7. Rules to retire or rewrite

| Where | Change |
|---|---|
| `professions.md` §4 "Vendor floor rule" | Rewrite as the vendor supply rule of §2.1; keep the moving gear floor. |
| `professions.md` §2 table, §2.3 | Goldsmith "six regional G1/G2 gems" → six depth-tiered gems. |
| `items_crafting.md` §0 bullets "Vendor floor rule", "Regional materials and contested routes …" | Vendor rule as §2.1; gems are no longer regional (cultural materials still are). |
| `items_crafting.md` §3.0.1 | Gem rows of the harvest table, race-region gem columns, G1/G2 density bullets, "practical T4 contested route", and the "vendor/drop substitution pressure" audit item. |
| `items_crafting.md` §3.6b | Gem species by tier. |
| `items_crafting.md` §3.7 "Vendor stock", §3.8 | Core stock list per §2.3; §3.8's gear catalogs unchanged. Anti-loop sentence → `≤`. |
| `items_crafting.md` §8.1–§8.2 | Payout formula of §3; reference prices only for vendor-sold goods; anti-loop `≤`; delivery boundary paragraph removed after the cutover. |
| `economy.md` top paragraph, §2, §3 | Remove the legacy-curve boundary after the cutover; §2 bullet on reference prices for never-sold items → the formula; anti-loop `≤`. |
| `settlements.md` "Profession vendors" | "A shelf of its trade's supplies and T1 basics" with a pointer to the rule. |
| `world_zones.md` §1, §11 (race-region table, G1/G2 bullets, density table, parity rule, contested G2 route) | Gems by depth everywhere. |
| `durability_repair.md` | Price source = the cutover axis. |
| `grug_traders` comments citing "1–6c band" and 25% buy-back | Update with the code. |

The `docs/design/` updates land with the lanes that ship the behaviour
(lane E5 or in-lane), never before; ROADMAP/BACKLOG mark WP44 delivered
with E1 and E4; README "Current state" follows the documentation rule.

## 8. Implementation lanes

Order: **E1** after Round 28's lanes in `grug_mobs` settle (coordinator's
call); **E2** after Round 28 (mapgen); **E3** after the quest lanes;
**E4** after E1 (and E3); **E5** last or inside each lane.

### E1 Traders, prices and the WP44 cutover

Goal: every rule of §2–§3 live; vendors and payouts follow the formula.

- `grug_traders/stock.lua`: shelves per §2.3, arrows in the core stock,
  shelf audit per §2.4.
- `grug_traders/init.lua`, `audit_alloys.lua`: payout formula (one price
  module with the class table and tier factors), sellable gathered items,
  `set_price` for foreign items, audit fixes (group inputs, `≤`), no
  stale band comments.
- `grug_mobs/subtypes.lua` (~l. 213–274): signature payout from the
  formula instead of `row.tier`; `grug_mobs/items.lua` prices via classes.
- `grug_materials/ores.lua` (`BAR_SELL_PRICES`, item visuals' price
  column), `registry.lua` (iron `sell_price`): processed = sum of inputs.
  Prices stay **out of** `PROCESSED_MATERIALS` (frozen WP43 projection).
- `grug_gear/init.lua`: `BRACKETS` prices to the target axis, buy-back
  `ceil(p/20)`, reference purchase price for repair.
- `grug_traders/potion.lua`, `grug_fishing/init.lua`,
  `grug_professions/init.lua`, `grug_alchemy/recipes.lua`: consistent
  with the formula and the shelves.
- Check: the load audits are clean; a small tool prints the per-band
  median kill payout (§3.2) for the record; `tools/check_lua.sh` on every
  changed file.

### E2 Gem tiers (mapgen)

Goal: §6 in the world and in every recipe.

- `grug_materials/registry.lua`: gem rows with tier 1–6, harvest tier =
  tier, no `scope = "regional"`/`grade`, no per-race `g1`/`g2`, no
  `GEM_GRADES`.
- Mapgen: `grug_mapgen/wp40/r7_content.lua`, `r6_content.lua` (density
  guards), `wp43_handoff.lua` (projection of grades/densities), sampler
  tables in `world_zones.md` §11's implementation; one density row per gem
  in its own band. Respect the mapgen test budget (few engine runs of at
  most about five minutes over a chosen region, never a full world) and
  the Round 22 PUC ruling (no PUC during mapgen work).
- `grug_professions/data/enchants.json` gem inputs, `grug_artisans/
  goldsmith.lua`, `woodcarver.lua`, `grug_inventory/help.lua`.
- Docs listed in §7 for gems.
- Check: load validators clean; one short engine run shows each gem only
  in its band and roughly at the target rate; the user prepares a fresh
  world.

### E3 Quest copper

Only needed if the quest lanes did not already use the cutover column
(§4): recompute `rewards.copper` in `grug_quests/data/zones/*.quests.json`
from `weight` and `level`. Mechanical; one commit.

### E4 Income estimate, mount and respec prices

Goal: replace the two placeholder price tables with values from a simple
per-band income estimate (§5), rounded per `economy.md` §4.1. Record the
estimate (inputs, per-band income, resulting prices) in this plan's
completion section.

### E5 Documentation

The design-doc rewrites of §7, BACKLOG/ROADMAP (WP44 delivered, gem
change recorded), README "Current state", the module guide where it
describes trader prices.

### Review and test

Each lane gets the independent review the agent model policy requires.
Runtime tests are the user's (GUI): buy and sell at a start vendor and a
profession shop, check that removed goods are gone, sell a stack of T1
and T4 loot and compare with the gear prices, enchant at T2 and T4 with a
depth-mined gem, repair one item, and — after E2 — mine each gem in its
band with the right and the wrong pick.

## 9. Boundaries

- Round 28 lanes own spawn code, `subtypes.json`, display names in
  `items.json`, zone spawn recipes and quest files while they run. This
  plan needs none of those edits; E1 touches only the price line in
  `subtypes.lua` and is scheduled by the coordinator.
- No mapgen change before Round 28 ends; E2 is the only mapgen lane.
- Fresh-server mode: no migrations, no compatibility aliases for the old
  gem grades.
- Agents never push; the user pushes.

## 10. Proposal for Round 29: "Economy and travel"

Agreed with the user on 2026-10-02 as the input for planning the next
round once Round 28 is complete. The coordinator turns it into the round
plan; nothing here is scheduled yet.

### 10.1 Content

1. **Economy lanes E1–E5** of §8, plus two small additions that belong to
   them:
   - **Claim-station repair** at the trader price (Round 25 carry-over D7,
     `durability_repair.md`): its price source switches with the WP44
     cutover, so it ships with E1.
   - **Loot text pass**: identical item descriptions across tiers and the
     "Spider Silk" dropped by T5/T6 outlaws (Round 28 handover notes); same
     items as E1.
   - **WP5 loot/demand audit**: covered by E1's per-band median calibration
     (§3.2); mark it done with E1.
2. **Mapgen bundle**: lane E2 (gem tiers) plus the removal of
   `apex_sockets` from mapgen (WP24/Round 25 carry-over E5: 24
   hard-protected columns the design no longer has,
   `wp40/source/simple_map.lua`, `r6_settlement.lua`). *Why together:*
   both need a mapgen change and a freshly prepared world; one bundle
   means one world preparation for the user.
3. **WP17 boats and waypoints** (V1, `boats.md`, `world.md` §6, scope card
   in `work-package-scopes.md`). *Why now:* boats are the only designed
   access to the two dragon islands, and Round 28's front lane writes
   island quests and bounties; without boats that content is unreachable.
   Waypoints fit the same "travel" theme.

### 10.2 Order

- **E1 and WP17 in parallel** (no shared files).
- **Then the mapgen bundle** (E2 + `apex_sockets`) and one fresh world.
- **E3** if the Round 28 quest lanes did not already write cutover copper
  (§4).
- **E4 last**: mount and respec prices need the finished prices and quests.
- **E5** inside the lanes or at the end.

### 10.3 Deliberately later

- **Round 30 candidate: WP41 geographic PvP**, after WP17 makes the
  islands (PvP tag) reachable; small PvP POIs (WP42 part) may join it.
- **WP5/WP10 remainder** (cultural finishing, helper services,
  Grudgeforged item-level-70 upgrade): its own round; it needs design
  work for the Grudgeforged inputs and the cultural masters.
- **WP9** (story 41–60 and finale): reassess after Round 28, which already
  writes front-zone and island quests; probably only the main storyline
  and the finale remain.
- Outpost seed (Round 28 item 46): after the playtest. WP34, WP46, WP48
  and the small Round 26/27 carry-overs: only when a playtest asks for
  them.

## E4 completion (2026-10-02)

Round 29 lane E4 replaced the two placeholder tables with prices from a
simple income estimate (§5). `python3 tools/r29_e4/income.py` prints the
whole record below; `--check` fails when the shipped tables
(`grug_mounts.PRICES` in `grug_mounts/catalog.lua`,
`grug_classes.RESPEC_PRICES` in `grug_classes/talents_ui.lua`) differ from
it. The placeholder names and the trainer's "Price pending" state are gone.

### Inputs and assumptions

- **Routes:** one per faction, the ledger's track routes
  (`r28common.track_route`) for **Dwarf** (Accord) and **Orc** (Throng) over
  the shipped quest files: one-time quests, no repeatables, no race perk.
  Per band the two routes are averaged.
- **Quest copper:** the game's rule (`grug_quests.quest_copper`, §4) per
  quest, counted in the band of its reward level, as the ledger counts XP.
- **Kills:** the band's kill equivalents (`progression.md`) times the share
  of the band's XP that quests do not pay as rewards or gathering, i.e. quest
  kills, drop kills and free play, all at band level.
- **Loot per kill:** E1's band medians from `tools/r29_e1/band_payout.sh`
  (re-run in this lane, unchanged): 4.3 / 9.0 / 16.7 / 39.0 / 147.6 /
  239.3c. Leader bonus rows and rare jackpots are left out.
- **Time:** `progression.md` §1, level 60 in about 10–20 played hours; the
  midpoint **15 h** split over the bands by their kill equivalents. That is
  about 38–47 kills per hour including quest walking and talking.
- **Repair:** per kill 4 weapon uses and 3 armour hits on band-tier Uncommon
  gear (quality ×3), 20 % of the Common slot price per lost lifetime
  (`durability_repair.md`): 0.09c per kill at T1, 2.1c at T6.
- **Potions:** 4 Weak Healing Potions per hour at 8c.
- Left out: food (cooked or bought for a few copper), the human quest-XP
  perk, a player market. The level-60 price uses the 51–60 leveling rate;
  farming at the cap has no new quests but walks less.

### Per-band income

| Band | Minutes | Kills (Dwarf / Orc) | Quest copper (Dwarf / Orc) | Loot | Repair | Potions | Net | Net per hour |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 → 10 | 77 | 47 / 48 | 66 / 64 | 206c | 4c | 41c | 226c | 1s77c |
| 10 → 20 | 111 | 73 / 68 | 229 / 250 | 633c | 11c | 59c | 803c | 4s35c |
| 20 → 30 | 138 | 86 / 91 | 751 / 705 | 1,476c | 24c | 73c | 2,107c | 9s18c |
| 30 → 40 | 165 | 104 / 108 | 2,228 / 2,224 | 4,126c | 58c | 88c | 6,207c | 22s61c |
| 40 → 50 | 192 | 147 / 149 | 4,592 / 4,408 | 21,867c | 168c | 102c | 26,096c | 81s70c |
| 50 → 60 | 219 | 166 / 177 | 14,360 / 11,380 | 41,056c | 365c | 117c | 53,444c | 1g46s68c |

Loot is 65–85 % of gross income in every band. Band 5 rises ×3.6 over band 4
(the ×2.5 axis expects ×2.5) because E1's band-5 median lands above its
target and band 4's below. Ruling 6 for comparison: band 1 nets about two
T1 Common vendor sets (105c each), band 6 about five and a half.

### Prices

A price uses the income of the bracket of the level it unlocks at
(`ceil(level / 10)`, the same rule as respec), rounded by `economy.md`
§4.1.

| Price | Level | Income time | Target | Price |
|---|---:|---|---:|---:|
| Apprentice Riding | 15 | 15 min | 109c | 1s10c |
| Journeyman Riding | 30 | 45 min | 689c | 7s |
| Expert Riding | 45 | 2 h | 16,339c | 1g63s |
| Master Riding | 60 | 5 h | 73,342c | 7g33s |
| Boat | 15 | as Apprentice | 109c | 1s10c |
| Improved Boat | 30 | as Journeyman | 689c | 7s |
| Respec 1–10 / 11–20 / 21–30 | — | 5 min | 15 / 36 / 77c | 15c / 35c / 75c |
| Respec 31–40 / 41–50 / 51–60 | — | 5 min | 188 / 681 / 1,222c | 1s90c / 7s / 12s |

The Boat and the Improved Boat cost exactly as much as their references
(travel plan ruling 3). The first respec stays free.
