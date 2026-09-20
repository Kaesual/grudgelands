AUDIT COMPLETE

Baseline: `2a308891` — Playtest 12 baseline
Scope: Lane A — professions, crafting, item economy, gathering, Cooking/Alchemy, and farming. Read-only static audit; no Lua, engine, test-suite, migration, or network execution.

No Critical issue was found. Confirmed inventory: **3 class A, 0 class B, 1 class D**. Additional class C/E items are separated below.

## Coverage matrix

| Area | Governing authority | Responsible implementation | Check and result |
|---|---|---|---|
| Profession ownership and progression | `docs/design/professions.md:13` | `mods/PLAYER/grug_jobs/state.lua:1`, registry/station adapters | Two primary slots, unlimited secondary Cooking, learn/unlearn reset, character-band cap and 10/15/20/25/30 progression match. Smith split is new E work. |
| Universal base gear | `docs/design/items_crafting.md:518`, ruling 48 | `grug_gear`, `grug_materials`, `grug_artisans`, `grug_professions` | Most universal gear recipes remain absent; current caster-base routes are Woodcarver-gated. This is tracked open work, class E, not B. No duplicate gear identities found. |
| Shaped recipes | Ruling 48, `audit-input/session-rulings.md:690` | Material curation, farming hoe, current profession catalogs | Existing bronze tools and farming hoe use familiar shapes. The new exact Minecraft quantities and same-tier sword-rod option postdate this baseline: E/C, not A. |
| Books, provenance and discovery | R8.5, R9 UI ruling, ruling 47 | `mods/PLAYER/grug_jobs/ui.lua:136`, `mods/PLAYER/grug_jobs/discovery.lua:1` | Search, tier/discovery filtering, persistent seen set and exact layout largely match. Group-input profession routes can leak into General/Basics: A. |
| Refinement | `docs/design/items_crafting.md:2076`, ruling 49 | `grug_professions`, `grug_artisans`, terminal jobs callback, `grug_quality` | Woodcarver retains refinement state. Blacksmith/Tailor weapon and armor refinements are reset by the terminal callback: A. |
| Quality and affixes | `docs/design/items_crafting.md:1880` | `mods/ITEMS/grug_quality/init.lua:34` | Pools, windows, no-duplicate selection, prefix/suffix ordering and actual Str/Int/Dex/pool/Crit/Dodge/armor/attack-speed consumers match. Later-slot application, kits and masterwork workflow remain E. |
| Ingredients and gathering | `docs/design/professions.md:33` | `grug_gathering`, `grug_materials`, profession catalogs | Food plants are universal; the four healing herbs delegate to Alchemist membership. Mining/smelting remains universal. Leatherworker ×5 remains tracked open E work. |
| Cooking | `docs/design/items_crafting.md:1119` | `mods/ITEMS/grug_cooking/init.lua:97`, `grug_food`, jobs station seams | 18 grid dishes, six raw-assembly/furnace routes and three universal furnace transformations match. Authorization remains profession-gated despite the book leak. |
| Alchemy and brewing | `docs/design/items_crafting.md:972` | `mods/ITEMS/grug_alchemy/recipes.lua:67`, `mods/ITEMS/grug_brewing/node.lua:281` | Twenty-one consumables, two reagents plus vial, take-time authorization, post-take progression, item-level gates and shared potion clock match. Apothecary gear remains E. |
| Farming | R9 farming ruling, ruling 51 | `mods/ITEMS/grug_farming/init.lua:6` | All 15 Cooking plants plus potato/corn have seeds, four stages, wet-soil growth, pause/resume and harvest loops. Placeholder art is a newly approved replacement, E. |
| Economy and vendors | `docs/design/economy.md:8`, `items_crafting.md` §§3.8/8 | `grug_money`, `grug_traders`, `grug_gear` | Ledger-only currency, catalog bands, drop-price audit and deterministic hourly shelves match their shipped baseline. Caster rotation is wrong: A. Vendor-quality authority remains contradictory: D. WP44 prices/buy-back/audit gaps are E. |

## Confirmed A findings

### P12-A-REF-01 — High — terminal callback cancels Blacksmith/Tailor refinement

**Requirement.** Profession refinement must leave the same item Common but refined, with +15% damage or armor. This was decided on 2026-08-07 in `docs/design/items_crafting.md:2082` and reaffirmed by ruling 49 on 2026-09-20.

**Implementation chain.**

- `grug_professions.register_refinement` creates an in-place recipe but does not retain `quality_mode = "refinement"`: `mods/ITEMS/grug_professions/init.lua:49`.
- Its craft callback copies the input and sets the refined marker/stat: `mods/ITEMS/grug_professions/init.lua:144`.
- `grug_jobs` deliberately moves its callback to the terminal position: `mods/PLAYER/grug_jobs/stations.lua:165`.
- That callback calls `crafted_output`: `mods/PLAYER/grug_jobs/stations.lua:94`.
- With no mode, `grug_quality` selects `"base"`, writes `grug_refined = 0`, removes affixes and restores base capabilities: `mods/ITEMS/grug_quality/init.lua:555` and `mods/ITEMS/grug_quality/init.lua:588`.
- Luanti threads each callback’s returned stack into the next callback: `reference_projects/luanti/builtin/game/register.lua:368`.
- Woodcarver is the positive comparator: it explicitly retains the refinement mode at `mods/ITEMS/grug_artisans/init.lua:45`.

**Player outcome.** A Blacksmith weapon/metal-armor refinement or Tailor cloth-armor refinement consumes the input material and grants profession progress, but returns an unrefined base item. Pick refinements are not reset because picks have no `grug_quality` family.

**Confidence/reproduction.** High-confidence deterministic call-chain finding. Not executed under the read-only mandate. The immutable Woodcarver KAT checks its retained mode, but no equivalent integrated PROF-A terminal-chain assertion exists.

**Tracking.** The likely callback issue is already noted in `audit-input/planning-draft.md:45`.

**Recommended correction scope.** Give PROF-A refinement recipes an authoritative refinement mode or consolidate the two refinement writers. Verify the final post-chain ItemStack, preservation of wear/meta, and exactly one +15% armor contribution—the existing manual armor override and quality aggregate must not double-apply the bonus once the marker survives.

---

### P12-A-BOOK-01 — Medium — group recipes appear in both profession and General/Basics books

**Requirement.** Since R8.5, General contains only recipes not bound to a profession: `TODO-round8.md:60`. The R9 UI ruling likewise excludes general engine recipes from profession books, and ruling 47 now makes the one-book-per-route rule explicit: `audit-input/session-rulings.md:683`.

**Implementation chain.**

- The General index includes each engine recipe unless `recipe_for_craft` recognizes it as a profession recipe: `mods/PLAYER/grug_jobs/ui.lua:136`.
- Registry matching treats a declared `group:*` token as matching only a concrete registered item carrying that group: `mods/PLAYER/grug_jobs/registry.lua:103`.
- Luanti’s recipe-introspection path returns the registered recipe input names; group tokens therefore remain strings such as `group:grug_cooking_root`: `reference_projects/luanti/src/craftdef.cpp:422` and `reference_projects/luanti/src/script/lua_api/l_craft.cpp:454`.
- Calling `core.get_item_group("group:…", group)` fails, so the professional route is not recognized.
- Sweetroot Mash is a concrete witness: its recipe uses root/staple group tokens at `mods/ITEMS/grug_cooking/init.lua:114`.

**Player outcome.** After discovery, Sweetroot Mash and other affected group-input grid routes can appear in both Cooking and General. General remains always accessible, so it misrepresents profession provenance.

This is **not a craft authorization bypass**: the actual grid contains concrete items, and the terminal grid permission path correctly resolves and enforces Cooking membership.

**Confidence/reproduction.** High-confidence static finding against engine and consumer sources; not runtime-reproduced. The existing UI KAT checks ordinary General recipes and group discovery independently, but does not pass a profession group recipe through the real engine-introspection exclusion path.

**Tracking.** Ruling 47 now tracks the visible outcome, but the concrete group-token cause was not otherwise identified.

**Recommended correction scope.** Canonicalize declared and engine-returned group tokens before provenance comparison, or exclude by a canonical registered-recipe signature. Add a real group-input profession route to the General-index test; retain the existing concrete-grid authorization test.

---

### P12-A-ROT-01 — Medium — vendor rotation still exposes two slots after the caster-family expansion

**Requirement.** The 2026-08-07 rotation rule says the extra pool has four conceptual families—dagger, greataxe, staff and caster 1H—and therefore exposes three slots while withholding one family: `docs/design/items_crafting.md:1319`.

**Implementation.**

- `grug_gear` adds wand, scepter and orb as three physical entries beside dagger, greataxe and staff: `mods/ITEMS/grug_gear/init.lua:183`.
- All six enter `cat.extras`: `mods/ITEMS/grug_gear/init.lua:375`.
- Trader stock still fixes `ROTATING_SLOTS = 2`: `mods/ENTITIES/grug_traders/stock.lua:124`, then samples two entries from the flat six-entry pool at `mods/ENTITIES/grug_traders/stock.lua:220`.

**Player outcome.** Each bracket shows two of six physical extras rather than three of four conceptual families. Four items—and potentially the whole caster-1H concept—can be absent in an hour instead of exactly one family being withheld.

**Confidence/reproduction.** Direct constant/data-flow mismatch; no runtime execution needed.

**Tracking.** WP30 broadly owns the later trader-catalog retrofit, but its row does not identify this already-live two-slot integration error.

**Recommended correction scope.** Model caster 1H as one rotation family with an explicit wand/scepter/orb sub-selection, expose three conceptual slots, and test “exactly one of four families withheld” rather than only asserting six entries in `cat.extras`.

## D finding

### P12-D-VENDOR-QUALITY-01 — High authority conflict — may vendors sell refined/enchanted gear?

Current decided documentation contains mutually exclusive requirements:

- Vendors “never sell refined or enchanted gear”: `docs/design/economy.md:28`, `docs/design/professions.md:181`, and `docs/design/items_crafting.md:1246`.
- The rotation explicitly sells a one-in-five world-window Uncommon: `docs/design/items_crafting.md:1319`.
- Later 2026-08-13 wording explicitly calls vendor stock a crafterless affix source: `docs/design/items_crafting.md:1850`.

The 2026-08-12 commit `17c7074e6` added both the Common-only statement and retained the Uncommon luxury-source statement, so ordinary chronology does not establish an unambiguous supersession.

**Actual implementation.** Once `grug_items.roll_enchants` exists, one rotation in five replaces a slot with an Uncommon: `mods/ENTITIES/grug_traders/stock.lua:188` and `mods/ENTITIES/grug_traders/stock.lua:249`. The world-source roller marks ordinary gear refined before adding affixes: `mods/ITEMS/grug_quality/init.lua:472`.

**Player outcome.** The current trader can sell refined, enchanted gear, contrary to every Common-only absolute, but consistent with the specific Uncommon-rotation clauses.

**Confidence/reproduction.** Actual behavior is statically confirmed; which behavior is authoritative cannot be resolved from the frozen decisions.

**Tracking/recommendation.** No explicit resolution found. Decide either:

1. Vendors are strictly Common-only and the Uncommon machinery must remain disabled/removed; or
2. The rotating Uncommon is the sole explicit exception, and the absolute Common-only statements must say so.

## Class C — superseded documentation

| Stale text | Superseding decision |
|---|---|
| General book name and catch-all wording in `docs/design/items_crafting.md:291` | Ruling 47: exclusive **Basics**, 2026-09-20. |
| Complete T1–T6 books with above-tier rows greyed at `docs/design/items_crafting.md:284` | Later R9 UI ruling: list only unlocked and discovered recipes, `audit-input/session-rulings.md:335`. Current code follows the later ruling. |
| Blacksmith explicitly not split in `docs/design/professions.md:198` | Ruling 50: Weaponsmith/Armorsmith split enters current work. |
| Armor costs 3/5/4/2 at `docs/design/items_crafting.md:813` | Ruling 48 adopts exact familiar 5/8/7/4 shapes/quantities. |
| Six trinket IDs rather than 36 at `docs/design/items_crafting.md:1915` | Applicable R9 rulings 28/38 adopted six identities × six tier IDs for the current registry. |

## Class E — known open work or 2026-09-20 changes

| Item | Why it is E, not A/B |
|---|---|
| Missing universal base gear recipes, including current Woodcarver-gated caster bases | WP27/WP29 and the WP10 content remainder remain open: `BACKLOG.md:53`. Ruling 48 newly fixes exact shapes and quantities. |
| Basics rename and readable group labels | Newly approved by ruling 47. The duplicate-provenance mechanism itself is separately A. |
| Refinement before/after presentation | Newly made explicit by ruling 49. The actual lost refinement state is separately A. |
| Upgrade-kit use, later-slot affix application, full Fine/Masterwork workflow, cultural/PvP finishing | WP5 and the WP10 remainder remain open. `grug_upgrades` is only reserved metadata today. |
| Refinement durability doubling | Explicitly deferred to WP22 by ruling 29 and preserved by ruling 49. |
| Weaponsmith/Armorsmith split | New ruling 50; not a historical baseline defect. |
| Leather armor, shields, spell tomes, Huge Bag, apothecary armor and Leatherworker ×5 drop hook | Explicitly recorded follow-up or WP10/WP29 work. The mob drop-hook seam exists but has no registered consumer. |
| Goldsmith identity-specific Setting counts | Explicit R9 placeholder under ruling 39. |
| Crop/food/hoe placeholder art | Replacement newly approved by ruling 51. Current runtime compositions are documented at `mods/ITEMS/grug_farming/LICENSE-media.md:1`. |
| Current ×1.4 prices, 25% buy-back and the two anti-loop coverage gaps | Explicit WP44 legacy boundary, `BACKLOG.md:70`. |

## Positive matches

- The two-primary-slot model, secondary Cooking, progression counters and profession-level craft gate follow the decided rules.
- Grid, furnace, dual-furnace, custom profession stations and brewing stand all gate at an acting-player seam; brewing authorizes before output removal and records progression afterward.
- Sweetroot’s duplicate display does not authorize non-Cooks to craft it.
- Cooking’s 18 dishes, six raw furnace routes and three universal furnace refinements match the current catalog.
- Alchemy’s 21 consumables, shared potion cooldown, Greater cooldown, elixir replacement, food stacking, item-level gates and herb authorization match.
- Affix legality, value bands, prefix/suffix ordering and all currently supported equipment-stat consumers are wired into gameplay rather than tooltip-only.
- Farming implements the claimed 17-crop population and full wet-soil lifecycle.
- Currency remains ledger-only; physical Gold is separate, and the trader startup scan covers registered static mob-drop tables. No evidence of a direct coin-drop path was found.

## Evidence and limits

I inspected the existing immutable R9 KAT sources but did not execute them. Their coverage explains the three misses:

- Woodcarver tests assert retained refinement mode, but the PROF-A terminal chain is not equivalently covered.
- The UI test covers engine recipes and group discovery separately, but not a group-input profession recipe being excluded from General.
- Gear tests assert six physical extras, not the three-of-four conceptual-family shelf rule.

Not examined:

- Map placement, station/trainer geography and protection envelopes—assigned to Lane B.
- Full combat behavior beyond equipment stat consumers.
- Visual quality in a running client.
- Every vendored generic recipe outside the economy/provenance call chains.
- PERF-branch changes, as required.
- Runtime persistence or GUI behavior; execution was prohibited.

This is a bounded discrepancy inventory, not a claim of full-game conformance. No files were changed.

## Prioritized discussion questions

1. Should the vendor’s one-in-five Uncommon be the sole exception to the Common-only vendor rule, or should vendors never sell refined/enchanted gear?
2. Confirm correction priority: refinement state loss first, recipe-book provenance second, vendor rotation third?
3. For universal cloth/leather bases, must material preparation itself become universal, or may non-profession players rely on trade for Tailor/Leatherworker feedstocks?
4. Does the four-band character-level mastery model remain authoritative for later affix slots, or should Round 10 map those operations onto T1–T6 profession progression?
5. Should the open universal base-recipe, split-smith, affix-workflow and art replacement work ship as one coordinated Round 10 economy pass or remain separate packages?

---
Archived from the independent audit; local source links and whitespace were normalized to
portable path citations. Baseline line numbers refer to `2a308891`.
Coordinator dispositions in [README.md](README.md) govern the combined inventory.
