# D5 — Items, crafting, professions and economy design documents vs code

**Scope.** `docs/design/items_crafting.md`, `item_tiers.md`,
`crafting_equipment_revision.md`, `durability_repair.md`, `economy.md`,
`professions.md`, `inventory_equipment.md`, `farming.md` (see limits),
`TODO-design-crafting-rework.md`; `docs/planning/economy-vendor-plan.md` and
`docs/research/items-professions-analysis-2026-10.md` read only for intended
state. Code: `mods/ITEMS/*` (grug_gear, grug_quality, grug_professions,
grug_artisans, grug_alchemy, grug_smelting, grug_materials, grug_repair,
grug_gathering, grug_cooking, grug_brewing, grug_farming hoes),
`mods/PLAYER/grug_jobs`, `grug_inventory`, `grug_money`,
`mods/ENTITIES/grug_traders`.

**Baseline:** `0f169898` (main). **Method:** read every document section that
states a number or an implementation fact and compared it with the code that
implements it (`path:line`). Before writing "absent" I grepped the whole
`mods/` tree. Known gaps in `docs/maintenance/findings.md` (D2, D3, WP44) and
BACKLOG are referenced, not re-reported. Two of them are themselves stale
(DI-01).

**Limits.** Two read-only sub-checks did part of the comparison:
`farming.md` and the food, cooking and fishing parts of `items_crafting.md`
§3.7, and `professions.md` against `grug_jobs`. I re-checked their main
claims myself before including them: the station recipe owners, the seed
recipe, the Salt Crust crop and D2. I did not re-check every low-severity
detail they reported, such as the eating sound and the bucket refusal; the
detail sections say so for each one. The display-gear "no collectible
inventory" guarantee (professions.md:41-45) was not verified.

## Verdict

| Document | Verdict |
|---|---|
| `item_tiers.md` | **current**. Every generated table I spot-checked matches the code: enchant curves, upgrade inputs, enchant loot, alchemy, sale values, crown fee. |
| `economy.md` | **current**. Price axis, 5 % buy-back, class values, tier factors, quality ×3/×6, culture shelf, crown fee, respec prices, mount and boat prices and the money clamp all match. |
| `durability_repair.md` | **current**. Lifetimes, factor 1.00, eligibility, providers, claim stations and the wear-target rule match. |
| `inventory_equipment.md` | **current** (one numbering nit). Slots, hand rules, armor ranks, bag sizes, quiver 500/100 and Help pages match. |
| `professions.md` | **mostly current**. Roster, slots, thresholds 10/15/20/25/30 and the band cap match `grug_jobs/state.lua`. The side text is wrong in places: claim-station repair, the herb gate, the vendor "enchant input" wording and the four mastery tiers (D3). Station ownership and the `alchemist` id are not documented. |
| `items_crafting.md` | **mostly current, with stale islands**. The numbers in §3.0, §3.6, §5.1, §6 and §8 are right. A large superseded block in §3.8, a material-ownership framing that contradicts code and `professions.md`, and several phantom items (flux, mace, warhammer, 2H bow) remain. |
| `crafting_equipment_revision.md` | **mostly current**. Its preamble still calls WP44 future work, and it contradicts the no-depth-penalty rule. |
| `TODO-design-crafting-rework.md` | **stale / misplaced**. Its only open item (D18) is an ocean-survival question, not crafting. |
| `farming.md` | **mostly current**. All numbers match: 17 families, 4 stages, 200 s per stage, water radius 3, hoe uses and the renewal constants. Missing: the seed recipe. It contradicts itself on Salt Crust "never renewing", and some guard and bucket wording is loose. |

Summary:

- The money system is the best-documented area. Every price in `economy.md`
  and in `item_tiers.md` §4–§6 matches `grug_gear.BRACKETS`,
  `price_rules.lua`, `stock.lua`, `crown.lua`, `RESPEC_PRICES` and
  `grug_mounts.PRICES`.
- The `findings.md` entries the brief names as known gaps are out of date.
  D2 (greyed recipes) was fixed in Round 28, and WP44 (25 % vs 5 %) was cut
  over in Round 29 (DI-01).
- `items_crafting.md` §3.8 still carries about 100 lines of the retired
  moving-floor and hourly-rotation design. Only one sentence marks it
  superseded (DI-02).
- `items_crafting.md` §3 says each profession's material chain is "its
  progression and trade good". In code, every leather grade, cloth bolt,
  wood grade and metal rod is a universal Basics grid recipe;
  `professions.md` §3 already says so (DI-03).
- Phantom content in `items_crafting.md`: a "flux" vendor supply (DI-04);
  mace, 1H axe and warhammer families, and a "physical 2H" bow (DI-05).
- `crafting_equipment_revision.md` still calls WP44 future work (DI-06) and
  mentions "existing deeper-mining penalties", which were retired in Round 24
  (DI-07).
- `TODO-design-crafting-rework.md` should be dissolved (DI-12).
- Overlap: `items_crafting.md` §3.6 and `item_tiers.md` §5 carry the same
  40-row alchemy table. Both are correct today, but the copy will drift.
  `item_tiers.md` also says it replaces that section.

## Mismatch table

| ID | Sev | Category | Direction | Doc location | Short description |
|---|---|---|---|---|---|
| DI-01 | Medium | Outdated | doc stale → fix doc | docs/maintenance/findings.md:13, :17-18 | D2 greyed recipes fixed in Round 28; WP44 "25 % vs 5 %" cut over in Round 29 |
| DI-02 | Medium | Unclear/Agent-trap, Bloat | doc stale → fix doc | items_crafting.md:1204-1301 | Superseded bracket tabs, 13-item floor, hourly rotation and 1-in-5 Uncommon still written as binding rules |
| DI-03 | Medium | Contradiction | doc stale → fix doc | items_crafting.md:809-823, 853-856, 876-878, 1004-1011 | Material chains framed as profession progression; code and professions.md:192-193 make them universal Basics |
| DI-04 | Medium | Outdated | doc stale → fix doc | items_crafting.md:829 | "Vendor supply: flux" — no flux item exists |
| DI-05 | Medium | Wrong / Contradiction | doc stale → fix doc | items_crafting.md:777-782, 468 | Weapon table lists mace, 1H axe and warhammer and a "physical 2H" bow; code has none of those and a 1H bow |
| DI-06 | Medium | Outdated | doc stale → fix doc | crafting_equipment_revision.md:19-20 | "WP44 target price table is future behavior until its cutover" — delivered in Round 29 |
| DI-07 | Medium | Contradiction | doc stale → fix doc | crafting_equipment_revision.md:210-211 | "existing deeper-mining penalties … remain" vs no depth penalty (durability_repair.md:256-258, mining.lua:9) |
| DI-08 | Low | Outdated | doc stale → fix doc | professions.md:147-148 | "Housing craft stations gain the same universal service later" — claim-station repair shipped |
| DI-09 | Low | Unclear | doc stale → fix doc | crafting_equipment_revision.md:214-215 | Incoming-wear rule omits "never a weapon carried in the offhand" (code and durability_repair.md have it) |
| DI-10 | Low | Outdated | unclear → Jan decides | items_crafting.md:1443-1444 | "WP5 still owes the loot/economy audit" — WP5 delivered in Round 33 |
| DI-11 | Low | Outdated | doc stale → fix doc | items_crafting.md:13-17, 110-115, 377-379 | Retired ring vocabulary, a pending WP40 translation, and a "dragon refill" in the gem audit |
| DI-12 | Low | Bloat | doc stale → fix doc | TODO-design-crafting-rework.md:1-48 | Crafting TODO holds only the ocean question D18; should be dissolved |
| DI-13 | Low | Contradiction (duplicate) | doc stale → fix doc | items_crafting.md:910-991 vs item_tiers.md:645-723 | Alchemy table duplicated; item_tiers.md:24-27 claims it replaces §3.6 |
| DI-14 | Low | Unclear | unclear → Jan decides | item_tiers.md:583-601, tailor.lua:97 | Spellbooks need Journeyman mastery (level 16+) at every tier, so the T1 spellbook never counts as T1 progress |
| DI-15 | Low | Wrong (wording) | doc stale → fix doc | items_crafting.md:395-396; economy.md:47-48 | "Gold Ingots" — the item is "Gold Bar" (`grug_materials:gold_bar`) |
| DI-16 | Low | Unclear (structure) | doc stale → fix doc | inventory_equipment.md:313, 433 | Two different sections are both numbered "## 5." |
| DI-17 | Medium | Missing | unclear → Jan decides | professions.md:66-71, 229-231 | Station recipes are T3 and owned by one profession each; the Forge belongs to the Weaponsmith only, so an Armorsmith cannot craft one |
| DI-18 | Medium | Missing | doc stale → fix doc | items_crafting.md:207-209 | Third craft gate (`mastery_required`, i.e. character-level band) not in the rule |
| DI-19 | Medium | Outdated / Agent-trap | doc stale → fix doc | professions.md:47-48, 155-156 | Herb gate described as "Alchemy's own book group"; code authorizes all four gated herbs with one learned profession |
| DI-20 | Medium | Unclear/Agent-trap | doc stale → fix doc | professions.md:197-198 vs :182-183 | "Never sell an enchant input" reads as including own materials; shelves sell bronze bars and light leather |
| DI-21 | Medium | Contradiction | doc stale → fix doc | item_tiers.md:569-578 | Column "Makes, enchants and upgrades" — plain weapons and armour are Basics; professions make only spellbooks, trinkets and bags |
| DI-22 | Medium | Missing | doc stale → fix doc | farming.md:8-21; items_crafting.md:694-696 | Seed recipe (1 harvest item → 2 seeds, Basics) documented nowhere |
| DI-23 | Medium | Contradiction | doc stale → fix doc | farming.md:6, :28, :80 | Salt Crust "never renews" but is a cultivable regrowing crop |
| DI-24 | Low | Wrong / Missing | doc stale → fix doc | items_crafting.md:1091-1092, 1103-1104, 1114, 1117, 1123, 1126-1129 | Food/cooking details: eat-sound timing, mana-food refusal, source bands (Salt Crust 44–50), meat blocks |
| DI-25 | Low | Unclear | doc stale → fix doc | farming.md:34-36, 107-111, 166-167, 174-176 | Cane/bamboo harvest wording, renewal guard name, bucket refusals, "claimed positions" water guard |
| DI-26 | Low | Agent-trap / format | doc stale → fix doc | professions.md:83-92, 125, 90 | Alchemy id is `alchemist`; broken table row, no Cooking row; "Consumables are Alchemy's alone"; Goldsmith chain simplified |
| DI-27 | Low | Unclear | unclear → Jan decides | items_crafting.md:914-916 | Cultivated Ember Moss (seed recipe, crop) is not Alchemy-gated, only the wild source is |

No High-severity item was found: nothing described as present is absent, and
no live number an agent would copy is wrong.

## Details

### DI-01 `findings.md` lists two resolved gaps as open

**Doc says** docs/maintenance/findings.md:13: "D2 | Profession books should
show higher-tier recipes greyed, but runtime omits them … later code fix or
explicit redesign required." Lines 17-18: "WP44 economy (current 25% versus
target 5% buy-back)".

**Code does** mods/PLAYER/grug_jobs/ui.lua:292-299 (`recipe_listed`: "A
profession book lists its whole T1-T6 catalogue, locked recipes included
(greyed)"), ui.lua:315-319 (`book_locked_counts`) and ui.lua:606-615 ("Locked:
needs %s tier %d (character level %d+).", exactly the text of
items_crafting.md:155-156). This landed in commit `01700592` (Round 28 A6,
"full recipe books"). Buy-back is `math.ceil(price / 20)` in
mods/ENTITIES/grug_traders/price_rules.lua:31-37 (5 %), and BACKLOG.md:206
records WP44 as delivered in Round 29.

**Impact.** Auditors and agents take both as open work. This brief did too.

**Suggested fix.** Mark D2 "Closed (Round 28 A6)" and replace the WP44 clause
in line 17-18 with "WP44 delivered in Round 29 (5 % buy-back, one price
module)".
- **Verification (phase 2):** Confirmed (combined note for the D2/D3/D5 lanes' findings.md reports, all four checked against code) — (1) D2 greyed recipes: fixed, `recipe_listed` returns true for profession books (mods/PLAYER/grug_jobs/ui.lua:291-299) and locked rows render grey with "Locked: needs %s tier %d …" (ui.lua:604-615). (2) D4 Kraken (findings.md:15 "view_range is 20 … pursuit not built"): fixed in Round 29 `38d9764a`, `view_range = 40` (mods/ENTITIES/grug_mobs/kraken.lua:78) and position-dependent speed, 10 in deep ocean and 5 elsewhere, switched in `do_custom` (kraken.lua:14-15, 138-148). (3) WP44 buy-back: 5 %, `math.ceil(price / 20)` (mods/ENTITIES/grug_traders/price_rules.lua:31-37), BACKLOG.md:206 delivered Round 29. (4) Level 41–60 story (findings.md:19): shipped in Round 36 (docs/design/story.md:4, §2a at :68; quest data merged in `966c557a` r36-qa and lane Q-T), so findings.md:17-19 is stale on three of its listed items, not two.

### DI-02 Superseded vendor-rotation design in `items_crafting.md` §3.8

**Doc says** items_crafting.md:1195-1202 says Round 33 sells the T1 catalog
only and that the historical reading "is superseded where it says vendors
sell a bracket". The next ~100 lines are still worded as rules: 1204-1206
"the floor moves with the player"; 1233-1236 "A player sees their own bracket
and every bracket below (tabs …)"; 1239 "**Binding strength rule**";
1265-1301 hourly rotation, "**13 items**" fixed floor, five rotating
families, a deterministic re-roll and a 1-in-5 Uncommon "per vendor and per
bracket".

**Code does** mods/ENTITIES/grug_traders/stock.lua:74-95 (`GEAR_BRACKET = 1`;
`bracket_stock` returns `{}` for any other bracket) and stock.lua:134-137
(`max_bracket` is 1). The shelf is all 18 weapons and armour of tier 1
(mods/ITEMS/grug_gear/init.lua:619-627). No rotation code exists.
economy.md:50-53 and professions.md:211-214 state the current rule correctly.

**Impact.** Agent trap: "Binding" and "Implemented reading" labels on retired
rules. The research note items-professions-analysis-2026-10.md:17-19 shows
readers took the 13 + 4 rotating model as live before Round 33.

**Suggested fix.** Keep three facts in §3.8: T1 shelf only, the six
catalogs as craft ladder / drop pool / reference prices, and the
ilvl/damage table (1244-1248). Move lines 1204-1301 to
`docs/archive/design/items-history.md`.

### DI-03 Who owns the material chains

**Doc says** items_crafting.md:812-815: each section lists "the **material
chain** the profession refines through (unchanged; it is still the
profession's progression and its trade good)". The §3.4 heading (853-856) is
"Leatherworker (tanning rack) — leather"; §3.5 (876-878) gives the bolt
chain; §3.6a (1004-1011) gives the wood grades.

**Code does** Every grade is a universal grid recipe with `owner="general"`
in mods/PLAYER/grug_jobs/basics_routes.lua:488-505 (light, cured, heavy,
scaled, sleek and nightscale leather; all six bolts; metal rods; thread) and
basics_routes.lua:247-248 (seasoned and polished wood). They are registered
as plain `core.register_craft` in grug_professions/leatherworker.lua:37 and
tailor.lua:43. They award no progress (items_crafting.md:218-224 lists only
"real recipes"). professions.md:192-193 says it plainly: "Materials everyone
can make on the crafting grid (leather grades, cloth bolts, graded wood) are
not profession products."

Code note: the `recipe_tier` and `material` fields in leatherworker.lua:5-21
are dead data left over from an earlier profession-recipe registration.

**Impact.** An agent reading §3 would gate grade crafting behind the
profession, or count it as progress.

**Suggested fix.** Replace items_crafting.md:814-815 with "the material
chain the profession enchants and upgrades with (universal Basics grid
recipes, no progress; professions.md §3)". Rename the §3.4/§3.5 headings to
"leather armour, bows and leather bags" and "cloth armour, spellbooks and
cloth bags".

### DI-04 Flux

**Doc says** items_crafting.md:829: "Vendor supply: flux."

**Code does** `grep -rni flux mods --include=*.lua` finds nothing. The core
supplies are thread 1c and parchment 5c (grug_professions/init.lua:52-63)
and the glass bottle 3c (grug_alchemy/recipes.lua:264).

**Suggested fix.** Delete the sentence.

### DI-05 Weapon families and bow handedness in §3.2

**Doc says** items_crafting.md:777 "1H sword / mace / axe", :780 "2H greataxe
/ warhammer", :782 "Bow (physical 2H)". The noun list at :468 omits Wand and
Bow.

**Code does** mods/ITEMS/grug_gear/init.lua:240-248 `WEAPONS` has sword,
dagger, greataxe ("Battle Axe"), staff, wand and bow, with `hands = 1` for
the bow. inventory_equipment.md:153-155 says "bow 1 (the bow is one-handed
since Round 28)". Woodcutting axes are not weapons (tool_lifetimes.lua:7).

**Impact.** Two docs disagree on bow handedness. Phantom families invite
new registrations.

**Suggested fix.** Use the rows "Sword", "Wand", "Dagger", "Battle Axe",
"Staff" and "Bow (1H, charged)", and add Wand and Bow to the noun list at
:468.

### DI-06 WP44 still called future work

**Doc says** crafting_equipment_revision.md:19-20: "The WP44 target price
table is future behavior until its coordinated economy cutover."

**Code does** WP44 is live (price_rules.lua; BACKLOG.md:206). economy.md:8-11
says "live since the WP44 cutover (Round 29 …)".

**Suggested fix.** Delete the sentence.

### DI-07 Depth mining penalty

**Doc says** crafting_equipment_revision.md:210-211: "Tool budgets describe
successful ordinary uses; existing deeper-mining penalties and tier access
remain."

**Code does** mods/ITEMS/grug_materials/mining.lua:9: "There is no depth limit
per pick and no …". durability_repair.md:256-258: "There is no mining depth
penalty: a pick too weak for a tier rock cannot dig it at all (Round 24
ruling 3)". items_crafting.md:530-532 retires per-pick depth limits.

**Suggested fix.** Change the sentence to "…; tier access follows the rock's
tier (items_crafting.md §3.0.4); there is no depth penalty."

### DI-08 Claim-station repair called future work

**Doc says** professions.md:147-148: "Housing craft stations gain the same
universal service later."

**Code does** mods/ITEMS/grug_repair/providers.lua:52-80 registers the
`station` provider for player-placed stations inside an active claim.
durability_repair.md:274-281 documents it (user decision D7).

**Suggested fix.** Replace the sentence with "Player-placed stations inside an
active Claim Stone claim offer the same service (durability_repair.md)."

### DI-09 Incoming-wear target

**Doc says** crafting_equipment_revision.md:214-215: incoming damage "selects
one intact repairable equipped piece uniformly from four armor slots and
offhand."

**Code does** mods/ITEMS/grug_repair/runtime.lua:151-160 skips a weapon in
the offhand (the Scout's Melee blade). durability_repair.md:250-252 states
this.

**Suggested fix.** Append "(a shield or spellbook, never a weapon carried in
the offhand)", or replace the paragraph with a link to durability_repair.md.

### DI-10 "WP5 still owes the loot/economy audit"

**Doc says** items_crafting.md:1443-1444.

**Code / BACKLOG** BACKLOG.md:164 marks WP5 delivered in Round 33. No
loot-vs-crafting demand audit is listed as an open item.

**Suggested fix.** Jan decides: delete the sentence, or open a BACKLOG item
if the audit is still wanted.

### DI-11 Retired vocabulary in `items_crafting.md`

- :13-17 "WP40 must translate placement to the named-zone catalog" — WP40 is
  delivered (BACKLOG.md:202).
- :110-115 the mastery table's "Ring that feeds it" column uses the retired
  radial rings.
- :377-379 "dragon refill/yield including the Goldsmith bonus" — the dragon
  hoard and renewable sockets are removed (items_crafting.md:1462-1463;
  findings.md:20-22).

**Suggested fix.** Drop the WP40 sentence and the Ring column, and drop
"dragon refill" from the acceptance-audit sentence.

### DI-12 `TODO-design-crafting-rework.md` has no crafting content left

**Doc says** TODO-design-crafting-rework.md:15-23 says everything in it is
open and the file should be deleted when nothing is open. Its only item is
D18 (lines 34-48), "Exhausted" for unmounted swimmers, an ocean-survival
question. mounts.md:350 already retires the mounted rule.

**Suggested fix.** Move D18 to BACKLOG (or `boats.md`, open questions) and
delete the file. Leave the many research files that cite old line numbers as
historical.

### DI-13 Duplicate alchemy table

**Doc says** items_crafting.md:947-988 and item_tiers.md:669-711 carry the
same 40 rows. item_tiers.md:24-27 says it "replaces … the alchemy table of
items_crafting.md §3.6", yet §3.6 kept a full copy. It is correct today and
matches mods/ITEMS/grug_alchemy/recipes.lua:24-112.

**Impact.** Only the item_tiers copy is generated and checked
(`tools/r33_ds/build_doc.py --check`). The other one will drift.

**Suggested fix.** Replace the §3.6 table with a link to item_tiers.md §5.
Keep the rules prose (vial, stand recipe, gating).

### DI-14 Spellbook mastery gate vs. "counting recipe at every tier"

**Doc says** item_tiers.md:583-586: "Journeyman mastery as today". The
progression table at :599 lists "spellbook" as a counting recipe at every
Tailor tier, T1 and T2 included.

**Code does** mods/ITEMS/grug_professions/tailor.lua:93-98 sets
`mastery_required = 2` for all six spellbooks. The mastery band is
character level ≥ 16 (grug_quality/init.lua:804-810), but profession T1 is
capped at levels 1–10. So the T1 spellbook can only be crafted after the
player has left T1, and it then counts nothing (items_crafting.md:215-217).
The same pattern applies to the T5 32-slot bags (mastery 4 = level 46+,
T5 band 41–50).

**Impact.** No doc/code mismatch in the rule itself. The table overstates
what a T1 or T2 Tailor can count, and it is tied to D3 (four mastery bands
vs six tiers).

**Suggested fix.** Jan decides whether spellbooks keep the Journeyman gate.
If yes, drop "spellbook" from the T1 cell (and note T2 starts at level 16).

### DI-15 Gold "Ingots"

items_crafting.md:395-396 ("9 Gold Ingots") and economy.md:48 ("ingots")
name an item that is registered as "Gold Bar" (`grug_materials:gold_bar`;
registry.lua:255-257, ores.lua:109). Use "Gold Bars".

### DI-16 Duplicate section number

inventory_equipment.md:313 "## 5. Buff/debuff display" and :433 "## 5.
Skills page and bound representations". Renumber the second to §6, or drop
the numbers from the later round sections.

### DI-17 Station recipes and the Forge

**Doc says** professions.md:66-71 and :229-231 ("one shared physical Forge")
do not say who can craft a station.

**Code does** mods/PLAYER/grug_jobs/station_nodes.lua:160-186. Each of the
five stations is a grid recipe with Steel Bars, owned by one profession:
Forge = `weaponsmith`, Tanning Rack = `leatherworker`, Tailor Bench =
`tailor`, Carving Bench = `woodcarver`, Jeweller's Bench = `goldsmith`. The
sub-check reports them as T3 with `progress = false` (station_nodes.lua:226-233;
I verified the owners only). An Armorsmith without the Weaponsmith slot can
never build a Forge in a claim.

**Suggested fix.** Document "Stations: T3 grid recipe of the owning
profession; the Forge is the Weaponsmith's". Jan decides whether the
Armorsmith should also be able to craft the Forge.

### DI-18 The mastery gate is missing from the craft rule

**Doc says** items_crafting.md:207-209: "craftable only when the player has
learned the profession and its profession level is at least the recipe
tier."

**Code does** mods/PLAYER/grug_jobs/state.lua:223-226 also refuses when
`mastery_required` exceeds `mastery_band` ("Journeyman mastery required.").
The band comes from character level 16 / 31 / 46
(grug_quality/init.lua:804-810), not from the crafter. It applies to bags
and spellbooks only. This is the concrete form of findings.md D3: no
enchant, gem, setting, trinket or mixture is mastery-gated, so the "Retained
specialist products" table at items_crafting.md:135-143 overstates it.

**Suggested fix.** Add the third gate to :207-209. Reduce the §2.1 mastery
table to "bags and spellbooks; character level 1/16/31/46". Replace
professions.md:167-168 "four mastery tiers each" with "six profession tiers
each". See also DI-14.

### DI-19 Herb gate wording

**Doc says** professions.md:155-156: "the old gathering gate becomes
Alchemy's own book group". professions.md:47-48 names only "dragonweed".

**Code does** mods/ITEMS/grug_gathering/harvest.lua:12-17 gates Gravemoss,
Dragonweed, Crimson Lotus and Ember Moss (wild). grug_alchemy/recipes.lua:256-262
authorizes all of them once Alchemy is learned. The `book_group_locked`
denial is never returned (dead path). Sunleaf, Stormkelp and Wild Cocoa are
ungated reagents (catalog.lua:189-212). items_crafting.md:914-916 is correct.

**Suggested fix.** "Learning Alchemy authorizes all four Alchemy herbs; there
is no per-tier herb gate."

### DI-20 "Enchant input" in the vendor rule

**Doc says** professions.md:197-198: vendors "never sell an enchant input".
Lines 182-183 define an enchant's inputs to include the profession's own
material.

**Code does** The shelf audit only counts enchants.json loot and family
inputs (mods/ENTITIES/grug_traders/stock.lua:347-357). The smith and
armourer sell `grug_materials:bronze_bar` (7c) and the tanner sells
`grug_mobs:light_leather` (6c) (stock.lua:246-297).
economy-vendor-plan.md:14 means "(signature loot, family input)".

**Impact.** Someone tightening the audit to the doc would remove bronze bars
from the smith.

**Suggested fix.** "never an enchant input (signature loot or family input
of enchants.json); T1 own materials may be sold". Make the same change in
economy.md:71-73 and items_crafting.md:69-71.

### DI-21 `item_tiers.md` §3.3 "Makes"

**Doc says** item_tiers.md:571-578: column "Makes, enchants and upgrades",
which lists swords, metal armour, staves, bows and so on.

**Code does** All plain weapons, armour, shields, bows, staves and wands are
Basics (`owner="general"` in grug_jobs/basics_routes.lua; e.g. :419-438 for
staves and wands). Professions make only spellbooks, trinkets and bags.
professions.md:85-89 is correct.

**Suggested fix.** Rename the column to "Enchants and upgrades (makes:
spellbooks, trinkets, bags)". It is generated, so fix it in
`tools/r33_ds/build_doc.py`.

### DI-22 Seeds

**Doc says** Nothing. farming.md:8-21 does not say where seeds come from.
items_crafting.md:694-696 claims to own the farming Basics recipes but
lists none.

**Code does** mods/ITEMS/grug_farming/init.lua:410-414 registers a
shapeless craft of 1 harvest item → 2 seeds for every family (Basics routes
in basics_routes.lua:285-301).

**Suggested fix.** Add to farming.md "Cultivation and tools": "Seeds: any
player crafts one harvest item into two seeds (shapeless, Basics)". Pick one
owner for the farming recipes (hoe grid, bucket, seeds); farming.md already
holds the hoe and bucket shapes. Rename "Farmer's Hoes"
(items_crafting.md:482) to "hoes"; no such item name exists.

### DI-23 Salt Crust renewal

**Doc says** farming.md:6 "never authorize renewable natural minerals" and
:80 "Rock Salt and Salt Crust are minerals and never renew". But :28 lists
Salt Crust as a crop class ("scrape one crust; basin returns to stage 1").

**Code does** mods/ITEMS/grug_farming/crop_profiles.lua:19
`salt_crust = {kind = "regrow_special", regrow_stage = 1}`. It has a seed
recipe like every family. It is excluded only from wild renewal.

**Suggested fix.** At :80 write "never renew in the wild; the cultivated Salt
Crust basin (above) is the deliberate farm exception", and align :6.

### DI-24 Food and cooking details in `items_crafting.md` §3.7

Reported by the sub-check; I did not re-verify these line by line:

- **Eat sound.** :1091-1092 says "rejected attempts play no sound". Since
  the 1.5 s hold, a looping eat sound starts with the hold
  (grug_food/init.lua:357-359), so level and mana-pool refusals at the end
  of the hold have already played it. Only the combat refusal is silent.
- **Mana food.** Caster dishes are refused for a player without a mana pool
  (grug_food/init.lua:256-258). This is undocumented at :1103-1104.
- **Source bands.** Salt Crust is level 44–50, not 41–50
  (wp40/world_content_catalog.lua:43). Wild Grain grows in six starts and
  six homes at levels 4–20, not "start-zone clearings". Pumpkin grows in the
  homes at 11–20 with no margin rule (:41, :48).
- **Meat blocks.** `mobs:meatblock_raw` and `mobs:meatblock` (both T1) are
  missing from the raw-food list at :1126-1129.

### DI-25 `farming.md` wording

Reported by the sub-check; I did not re-verify these line by line:

- **:34-36** Digging any Sugar Cane or Bamboo segment removes the whole
  plant. The root-preserving harvest is the right-click action
  (grug_farming/init.lua:340-378).
- **:107-111** The renewal hook is `grug_core.natural_renewal_allowed`
  (grug_farming/init.lua:505), not `natural_ground_alterable`.
- **:166-167** Buckets are refused wherever `grug_core.world_alterable` is
  false, which includes deep ocean and the dragon channel, and never
  replace an existing liquid (bucket.lua:20, 55-58).
- **:174-176** The water guard's "claimed positions" means Claim Stone
  arrival cubes only (water_guard.lua:24-32; protection.lua:27-29).

### DI-26 `professions.md` small items

- **Profession id.** The internal id is `alchemist`
  (grug_jobs/registry.lua:8), so `grug_jobs.has(p, "alchemy")` is false.
  List the ids.
- **Broken table.** :91-92: the Alchemy row sits after a blank line and
  renders broken. Cooking has no row.
- **Consumables.** :125 "Consumables are Alchemy's alone" — dishes are
  consumables, and vendors sell the Weak Healing Potion. Say "Potions and
  elixirs".
- **Goldsmith chain.** :90 "Gold + the six gems" — settings T1–T3 use
  tin, iron and copper/steel (grug_artisans/goldsmith.lua:46-57).
- **Faction.** Trainers and repair serve only their own faction
  (grug_repair/providers.lua:27-32). Add "of your faction" at :146-147.
- **Learning cost.** Learning is free (help.lua:65); state it.

### DI-27 Cultivated Ember Moss

**Doc says** items_crafting.md:914-916: Ember Moss is "fail-closed scenery
for everyone who has not learned Alchemy".

**Code does** The gate applies to the wild source only
(grug_mapgen/world_nodes.lua:14-17; grug_gathering/harvest.lua:12-17). The
farm crop (crop_profiles.lua:20) and its seed recipe are ungated, so a
non-Alchemist holding one Ember Moss can farm it.

**Suggested fix.** Jan decides whether this is intended, then state it.

## Comparison tables

### Common price axis (copper)

| Slot | Doc (economy.md:61-65, items_crafting.md:1846-1850) | Code (grug_gear/init.lua:45-52) |
|---|---|---|
| Weapon | 25 / 65 / 160 / 400 / 1000 / 2500 | identical |
| Chest | 20 / 50 / 130 / 320 / 800 / 2000 | identical |
| Other | 15 / 35 / 80 / 200 / 500 / 1250 | identical |

### Buy-back and payouts

| Rule | Doc | Code | Match |
|---|---|---|---|
| Buy-back | 5 %, rounded up; 0 if ≥ discounted price | price_rules.lua:31-37 | yes |
| Race discount | never raises buy-back | stock.lua:12-18 (10 %) | yes |
| Quality | blue ×3, gold ×6 | price_rules.lua:41-45 | yes |
| Tier factors | 1 / 2.6 / 6.4 / 16 / 40 / 100 | price_rules.lua:10 | yes |
| Class values | trash 1, raw 1, generic 2, signature 7, gem 4 | price_rules.lua:15 | yes |
| Free materials | wood, stone, sand … worth 0 | prices.lua:62-72 | yes |

### Sinks

| Sink | Doc | Code | Match |
|---|---|---|---|
| Repair factor | 1.00 | grug_repair/service.lua:19 | yes |
| Repair quality multiplier | 1 / 3 / 6 | grug_gear/init.lua:452-454 | yes |
| Crown fee | 1g 48s | crown.lua:11 (14800) | yes |
| Respec | 15c / 35c / 75c / 2s / 5s25c / 12s | grug_classes/talents_ui.lua:11 | yes |
| Mounts and boats | 1s5c / 7s / 1g29s / 7g38s / 1s5c / 7s | grug_mounts/catalog.lua:11 | yes |
| Weak Healing Potion | 35 HP, 8c, 60 s shared cooldown | potion.lua:7, :37; stock.lua:56 | yes |
| Culture shelf | 12 × 25c, 1s, 10s, 5 × 1g | stock.lua:313-333 | yes |

### Durability

| Item | Doc (durability_repair.md:245-256, crafting_equipment_revision.md:199-208) | Code |
|---|---|---|
| Combat T1–T6 | 1000 / 1500 / 2000 / 2500 / 3000 / 4000 | grug_repair/presentation.lua:8 |
| Tools: wood, stone, T1–T6 | 30 / 60 / 300 / 600 / 1000 / 1500 / 2000 / 3000 | tool_lifetimes.lua:3, :24-27 |
| Hoes | same as tools | grug_farming/hoes.lua:3, :64-71 |
| Eligible items | weapons, shields, spellbooks, 4 armour slots, tools, hoes | service.lua:6-15 |

### Drops and quality

| Item | Doc (items_crafting.md §5.1) | Code (grug_quality/init.lua:79-104) |
|---|---|---|
| Normal mob | 5 / 2 / 1 % | `normal = {5,2,1}` |
| Elite or named | 10 / 10 / 5 % | `ELITE_DROPS` |
| Bosses | 2 items, 50 % gold; ilvl 65 (King, General, rift) / 70 (dragon) | `BOSS_DROPS` |
| Bag drop | 0.1 %; 8 / 16 / 24 / 32 at ≤15 / ≤30 / ≤45 / 46+ | `BAG_DROPS` |
| Enchant pools, names, curves | §6.2, §6b.4, item_tiers.md §1.1 | init.lua:26-75, 120-131 |
| Trinket specials | items_crafting.md:1645-1653 | grug_gear/trinkets.lua:10-36 |
| Operation count | 552 + 36 | 46 stat slots × 2 channels × 6 tiers = 552; trinkets 3 × 2 × 6 = 36 |

### Profession data

| Item | Doc | Code | Match |
|---|---|---|---|
| Upgrade inputs | item_tiers.md:537-544 | grug_professions/data/upgrades.json | all 36 rows |
| Enchant loot, T1 | item_tiers.md:383-391 | data/enchants.json tier 1 | yes |
| Bag recipes | items_crafting.md:899-901 | tailor.lua:65-88, leatherworker.lua:40-53 | yes |
| Bag profession tiers | T1 / T2 / T4 / T5 | same | yes |
| Spellbook | 2 bolts + Parchment, Journeyman | tailor.lua:93-98 | yes (see DI-14) |
| Goldsmith bonus | 10 % / 20 % from Journeyman | grug_artisans/goldsmith.lua:118-138 | yes |
| Gem tiers | Citrine T1 … Diamond T6; harvest tiers | grug_materials/registry.lua:129-189 | yes |
| Tier-rock bands | items_crafting.md:545-552 | registry.lua:12-35 | yes |
| Tool level requirements | 5 / 15 / 25 / 35 / 45 | mining.lua:152-153 | yes |
| Gathering XP ratio | 0.10 / 0.20 / 0.33 | grug_xp/init.lua:173 | yes |
| Alloys and times | items_crafting.md §3.0.2 | grug_smelting/recipes.lua:28-80, 113-120 | yes |
| Unbroken multiplier | 1.65 | grug_core/combat.lua:2 | yes |

### Inventory and equipment

| Item | Doc (inventory_equipment.md) | Code | Match |
|---|---|---|---|
| Equipment slots | 8 | grug_inventory/equipment.lua:6-15 | yes |
| Hand rules | per class | equipment.lua HAND_RULES; grug_gear/permissions.lua:2-7 | yes |
| Armor rank | Warrior 3, Scout 2, Mage 1, Priest 1 | permissions.lua:41 | yes |
| Bag slots | 4 | bags.lua:9 | yes |
| Bag sizes | 8 / 16 / 24 / 32, cloth and leather | bags.lua:36-67 | yes |
| Quiver | 5 × 100 | bags.lua:89-101 | yes |
| Help sub-pages | six | help.lua:35-145 | yes |

## Proposed structure changes

Ownership today is spread across five files that restate each other. My
proposal:

- **`item_tiers.md`**: owns every number of items. That means enchant
  curves, enchant and upgrade inputs, the crown, potion and elixir tables,
  sale values and repair math. It is generated and checked, and should stay
  the single numeric source. Retitle it "Item numbers". Its preface (lines
  24-31) should become a "this file owns" list.
- **`items_crafting.md`**: owns structure and rules. That means the ladders,
  material taxonomy and tier rocks (§3.0), one-item-per-concept, curves
  (§3.1/§3.2), loot sources (§5), the meta model and pools (§6), and the bow
  foundation (§9).
  - Remove its copies of numbers owned elsewhere: the alchemy table (DI-13),
    the §8.2 price table (link to economy.md §2), §8.3/§8.4 sink prices (link
    to economy.md §4) and §6b.2 (already a link).
  - Archive the §3.8 rotation history (DI-02) and the §1/§10 stubs.
  - That would cut roughly 300 lines.
- **`professions.md`**: owns roster, slots, progression thresholds, families
  (move item_tiers.md §3.3's family table here, or link it), the vendor rule
  and trainers. It should also absorb items_crafting.md §2.1–§2.3
  (ladders, recipe books, progression rules). Today that content is split
  between the two files and phrased twice.
- **`crafting_equipment_revision.md`**: its preamble already calls itself a
  "topic index". Workspaces → `inventory_equipment.md` §4 (already
  duplicated there). Enchant operations → items_crafting.md §6b plus
  item_tiers.md §2. Plain caster/bow recipes and lifetimes →
  items_crafting.md §3.0.3 and `durability_repair.md`. Protection
  calibration → `combat_stats.md`. Then turn the file into a five-line
  redirect, or archive it.
- **`inventory_equipment.md`**: keep slots, bags, UI and the message feed.
  §4 "Crafting model" overlaps professions.md and crafting_equipment_revision;
  keep it as the single owner of station and workspace behaviour.
- **`TODO-design-crafting-rework.md`**: dissolve it (DI-12).
- **`durability_repair.md`** and **`economy.md`**: keep as they are. Both are
  tight and current.

## Open questions for Jan

1. DI-10: is a "found gear vs crafted demand" audit still wanted after WP5,
   or can the sentence go?
2. DI-14: should spellbooks (and the T5 32-slot bags) keep a mastery gate
   that makes the low-tier recipe unreachable while its tier is current?
3. DI-12: where should D18 (unmounted swimmer exhaustion) live: BACKLOG or
   `boats.md`?
4. Proposed structure: may `crafting_equipment_revision.md` become a
   redirect, and may items_crafting.md §2.1–§2.3 move into `professions.md`?
5. DI-17: should the Armorsmith be able to craft a Forge? Today only the
   Weaponsmith can.
6. DI-27: is ungated farming of Ember Moss (an Alchemy herb) intended?
7. D3: should the mastery bands (character level 16 / 31 / 46, bags and
   spellbooks only) stay, or should they become profession tiers?
