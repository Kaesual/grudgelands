# Round 21 discussion: mining progression, density and furnaces

Date: 2026-09-24. Status: **approved and active, including corrected Gold
and Bronze-only basic arrows; user Go received**. See [state](round21-state.md).
Extends [Round 21](round21-mapgen-and-playtest-fixes.md), replacing its initial
blanket shallow doubling and starter-log quest recommendations.

## User direction received

- Copper and tin should have equal density. Consider one ore per 96 eligible
  hosts in T1, or 128; lower-tier materials should become less common deeper.
- Prefer a material's main tier to have its peak, but the previous accessible
  tier must supply inputs for the next pick. This bootstrapping applies to ores,
  not regional gems. Coal should remain useful and common at every depth.
- Do not replace starter coal quests with log delivery. Mining is a useful
  introduction if finding the required material is reasonable.
- Include charcoal production and restrict both furnace types to logs, coal and
  charcoal. Adopt VoxeLibre-style fuel/cooking progress images and seamless
  burning. Proposed numbers and the ignition clarification below still await
  discussion. This is authorization to plan, not to implement the whole round.

## Actual progression, before any density changes

Sources: `grug_materials/registry.lua:7–33,117–179`,
`grug_professions/base_recipes.lua:8–29,82–83`,
`grug_smelting/recipes.lua:28–78`.

All six metal picks cost three matching bars and two sticks. Alloy recipes
currently use one unit of each listed input and produce one bar.

| Pick to obtain | Newly required raw material(s) / recipe | Earliest existing host tier |
|---|---|---|
| T1 Bronze | Copper bar + tin bar | T1, accessible to wood/stone picks |
| T2 Iron | Smelt iron lump | T1 |
| T3 Steel | Iron bar + mined coal | Both already T1; also present in T2 |
| T4 Silversteel | Steel bar + silver bar | Silver starts T3 |
| T5 Embersteel | Silversteel bar + Emberglass | Emberglass starts T4 |
| T6 Abyssal Steel | Embersteel bar + Abyssal Crystal | Crystal starts T5 |

Thus the next-pick input is already available before entering its new depth
band. “Equipment tier” and “earliest harvest/host tier” are distinct. There is
no separate Bronze, Steel, Silversteel, Embersteel or Abyssal Steel ore. Emberglass
and Abyssal Crystal are universal progression inputs despite their names; they
are not regional gem restrictions. No gem or cultural trophy gates the picks.

The existing recipes also allow obtaining a Steel pick without first spending
bars on an Iron pick, because iron and coal are both available in T1. This is
not a deadlock, and this round does not add a previous-pick crafting requirement
or an extra ore merely to force every intermediate tool purchase.

## Current production densities

Every number below is **N in one target ore node per N eligible host nodes**;
smaller means more common. Dashes mean absent. Tiers refer to absolute Y:
T1 >= -100; T2 -300…-101; T3 -500…-301; T4 -700…-501;
T5 -1000…-701; T6 <= -1001.

| Natural resource | T1 | T2 | T3 | T4 | T5 | T6 | Vein cap |
|---|---:|---:|---:|---:|---:|---:|---:|
| Coal | 128 | 128 | 128 | 128 | 128 | 128 | 8 |
| Copper | 256 | 256 | 256 | 256 | 256 | 256 | 8 |
| Tin | 384 | 384 | 384 | 384 | 384 | 384 | 8 |
| Iron | 128 | 128 | 128 | 128 | 128 | 128 | 8 |
| Quartz | 256 | 256 | 256 | 256 | 256 | 256 | 8 |
| Gold | — | 1024 | 1024 | 1024 | 1024 | 1024 | 4 |
| Silver | — | — | 1024 | 1024 | 1024 | 1024 | 4 |
| Emberglass | — | — | — | 2048 | 2048 | 2048 | 4 |
| Abyssal Crystal | — | — | — | — | 2048 | 2048 | 2 |
| G1: Citrine / Garnet / Jade | — | 12000 | 6000 | 3000 | 3000 | 3000 | 3 |
| G2: Diamond / Sapphire / Ruby | — | — | — | 12000 | 6000 | 3000 | 2 |

Production source: `wp40/r7_r6_manifest.lua:67–83`, checked by
`r6_content.lua:113–129,295–320`. Placement groups into capped balanced veins
and applies deterministic remainder rounding (`r6_settlement.lua:2502–2612`).
The table is configured density, not a measured search-time estimate.
Only one G1 and one G2 species belongs to each race region; the grouped rows
do not mean all three gems coexist locally. Scope is geographic, not dependent
on the mining player's race. Ordinary exclusions and exact host eligibility
remain in force.

All resources get the current shared deep multiplier: 1.25 at -1500…-1999 and
1.5 at <=-2000. Listed T6 values are before that multiplier.

## Approved density table (implementation pending)

The user accepted this matrix and the subsequent Gold-only amendment on
2026-09-24. The table below includes the final approved Gold row. Living owner: `docs/design/world_zones.md`
section 11. The current-code table above remains factual baseline evidence.

Use peak, half-peak nearby, quarter-peak farther away as a simple floor rather
than indefinite exponential decay. Coal is the explicit exception. Preserve
bootstrap appearances and regional gem availability. No new sampler or vein
shape algorithm. Existing caps remain unchanged in this first iteration.

| Natural resource | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Coal | **64** | 128 | 128 | 128 | 128 | 128 |
| Copper | **96** | 192 | 384 | 384 | 384 | 384 |
| Tin | **96** | 192 | 384 | 384 | 384 | 384 |
| Iron | 128 | **96** | 192 | 384 | 384 | 384 |
| Quartz | **128** | 256 | 512 | 512 | 512 | 512 |
| Gold | — | 512 | 256 | **128** | 256 | 256 |
| Silver | — | — | 256 | **128** | 256 | 512 |
| Emberglass | — | — | — | 256 | **128** | 256 |
| Abyssal Crystal | — | — | — | — | 512 | **256** |
| G1: Citrine / Garnet / Jade | — | 2048 | 1024 | **512** | 512 | 512 |
| G2: Diamond / Sapphire / Ruby | — | — | — | 2048 | 1024 | **512** |

Bold denotes the first peak tier. Main tiers here are explicit proposed design,
not a previously existing registry attribute: copper/tin/quartz T1, iron T2,
gold/silver T4, Emberglass T5, crystal T6. T3 Steel has no new mineral and consumes
iron/coal. Gem families keep their established rising-then-flat progression
shape instead of assigning an arbitrary per-species equipment tier.

This increases upper-tier progression ingredients substantially: silver's first
appearance becomes four times current density, Emberglass eight times, crystal
four times. Peak crystal becomes eight times current density. G1/G2 become
approximately six times more common along their existing curves. These are
playtest starting values, not promises about exact acquisition time.

Iron keeps **1/128 in T1** as a bootstrap exception, while peaking at 1/96 in
T2. A rigid half-peak rule would reduce T1 iron to 1/192, making the first iron
pick harder to obtain than today. The table deliberately avoids that outcome.

Tradeoffs:

- Recursive alloys keep iron and coal relevant through T6: an Abyssal Steel
  bar needs iron, coal, silver, Emberglass and crystal. Do not make early
  ingredients virtually absent at depth. Copper/tin are not part of that
  recursive high-tier chain; they mainly serve Bronze and station setup.
- A quarter-density floor reduces incidental old-material yield, but cannot
  guarantee market value: advanced pick speed and player time still matter.
  Existing deep multipliers also lift the floor to 31.25%/37.5% of peak. A
  strictly declining deep yield would require a separate decision about those
  multipliers, not an unnoticed sampler change.
- Peak availability one tier AFTER first discovery preserves the desired
  bootstrap. Increasing the rarity of the precursor layer too far would make
  the upgrade feel blocked even when formally possible.
- Vein caps and spatial clustering mean “1/96” is not a guarantee of finding
  ore after digging 96 blocks. More frequent small veins usually help discovery
  more than one huge rare vein. This first proposal increases budgets and keeps
  caps; adjust after playtest if necessary.
- Rare gems depend on region as well as depth; recipe/tooltip guidance should
  not imply a local Sapphire source in a Ruby region.

## Furnace package F4 — Sol implementation, Astra review

Read-only findings:

- Both furnace kinds currently use `grug_jobs/automatic.lua`; the dual node is
  chiefly active/inactive visuals (`grug_smelting/node.lua`).
- The old vendored normal furnace already has flame/arrow images, but
  Grudgelands replaces its UI with `grug_jobs/workspaces.lua:123–168,345–435`,
  which currently omits those images. Fix the actually displayed common UI,
  not the unused upstream form.
- State tracks remaining fuel but needs the current piece's total burn duration
  to display an accurate percentage. Recipe progress/time already exists.
- VoxeLibre starts a new fuel unit only with a valid recipe and output room;
  once lit, the unit burns to completion even if cooking becomes impossible
  (`mcl_furnaces/init.lua:388–428`). Our evaluator follows the same general rule.
- The reported brief extinguishing must be traced at the shared evaluator and
  active-node/UI boundary. Source shows a concrete candidate: `automatic.lua`
  returns on zero remaining elapsed time before refueling, and the workspace
  chooses the lit node solely from `state.fuel > 0`. A tick ending exactly at
  fuel exhaustion can therefore leave a dark interval until the next tick.
  Verify that boundary with a tiny evaluator fixture, not a long engine run.

Recommended user-visible rules for BOTH normal and dual furnaces:

1. Only logs, mined coal and charcoal are allowed in the fuel slot. One common
   classifier supplies admission AND processing durations for shared and
   personal stations. Do not delete dozens of unrelated global fuel recipes.
   The evaluator also serves brewing: limit this new fuel policy to the two
   furnace kinds; do not silently change brewing fuel or processing.
2. Faithful VoxeLibre times: **log 15 seconds, coal 80 seconds, charcoal 80
   seconds**. Coal and charcoal are equally effective fuel in VoxeLibre; only
   wood differs. All accepted tree species use the same log duration.
3. One log in a normal furnace's material slot produces one charcoal after
   **10 seconds**. Use a distinct Grudgelands item and licensed VoxeLibre icon;
   record pinned provenance before importing. No charcoal block or extra fuel
   families in this package.
4. Fuel alone does not ignite. A valid recipe plus output space consumes one
   fuel item and lights the furnace; the current piece burns out even if inputs
   are removed/output blocks. Only take the next piece if work can continue.
   Seamless refueling while processing must never toggle the node dark for an
   intermediate tick. Immediate inventory-event start must not consume twice
   when the timer next runs.
5. Flame shrinks with remaining fuel; arrow fills with current recipe progress.
   Visible cooking and remaining fire are distinct: a blocked output can stop
   the arrow while the flame still burns. Both UI variants show both values.
6. **User approved 10-second normal metal smelting**: copper, tin, iron,
   silver and gold each take 10 seconds instead of 3. One 80-second coal thus
   supports eight uninterrupted normal metal smelts. Charcoal cooking also
   takes 10 seconds. The separate alloy recipes retain 4/6/8/10/12 seconds;
   food/brewing durations are not changed by this decision.
7. Preserve personal vs shared inventories, permission checks, elapsed-time
   processing and persistence. World-node illumination at a personal workspace
   represents active work at that station; individual progress belongs to the
   viewer's personal inventory. Do not make one player's flame meter report
   another player's fuel.
   Personal work currently settles lazily and does not use the shared node
   timer; do not scan every stored player's inventory each second merely for
   world illumination. Freeze a bounded cosmetic burn-deadline approach, or
   escalate that presentation seam separately if it needs a new scheduler.
8. Coal quests continue to require mined coal; charcoal is not an alias or
   automatic replacement for coal in Steel's material slot. Charcoal is a
   renewable fuel source, not a new universal ore substitute.

The charcoal=coal fuel duration matches the requested reference. Making all
three different would be a balance deviation; no reason to add it unless the
user wants mined coal to be the superior fuel.

### UI refresh complexity gate

Our station form uses named detached inventories; it is not the reference's
node-metadata form. Current 1Hz processing does not refresh open forms
(`workspaces.lua:315–322`). Adding images alone will not animate them.

First inspect native same-form refresh/drag behavior. Prefer one-second visual
updates without rebuilding inventory ownership. If refreshing interferes with
held stacks, scrolling or input, pause this narrow UI branch and report an
alternative. Do not silently ship periodically canceled dragging, build a
general HUD-over-formspec positioning layer, or modify the client. No subsecond
or frame-perfect animation requirement. Flame texture/arrow can reuse our
existing assets if they deliver the same clear visual semantics.

### Ownership, checks and independence

F4 owns common automatic processing, fuel policy, workspace presentation and
charcoal recipe/media. It can run independently of mapgen, after food work in
the Sol slot or another free worker slot. F3 atlas/socket work has no shared
automatic-processing ownership. Route complex processing/persistence findings
to Astra; do not rewrite the station architecture by default.

Use a small real-evaluator fixture: fuel-only idle, illegal fuel rejection,
single-unit ignition, remaining fire without input, blocked output, same-tick
refuel, different fuel durations, normal/dual recipes, elapsed unload/reload,
and personal-player isolation. Test charcoal cannot become Steel input by
accidental coal identity. A small native UI probe is conditional on an
unresolved engine interaction question; GUI visual acceptance remains user-run.
Use the round's existing parser/static/final micro-KAT budget, not a second
suite or mapgen run. No tests were executed during this planning update.

## Follow-up: Goldsmith demand and later density tuning

Source: `grug_artisans/goldsmith.lua:36–47,72–129`, `grug_artisans/enchants.lua`,
`grug_professions/enchants.lua:3–29`.

| Setting tier | Materials per one setting |
|---|---|
| T1 | 2 Tin Bars |
| T2 | 2 Iron Bars |
| T3 | 1 Steel Bar + 1 Copper Bar |
| T4 | 2 Gold Bars |
| T5 | 1 Embersteel Bar + 1 Gold Bar |
| T6 | 1 Abyssal Steel Bar + 1 Gold Bar |

Spellbooks use one setting plus parchment. Trinkets use 1–6 settings depending
on identity, plus gems: T1 quartz; T2/T3 one identity-specific G1; T4 one G2;
T5 sapphire+ruby; T6 diamond+sapphire+ruby. A Goldsmith enchant uses one setting
and its tier reagent, so gold remains consumed through high-tier enchants.
Ornaments at T3–T6 add another gold bar to a setting and reagent.

Consequently the proposed Gold peak at T2 does not match its main crafting
demand. **Approved amendment:** Gold denominators
`— / 512 / 256 / 128 / 256 / 256` for T1…T6. It remains discoverable at T2,
peaks at T4 and stays moderately common at T5/T6. All other approved rows remain unchanged.

Density numbers can later be tuned with a bounded configuration/strict-consumer
change and compact checks. A full mapgen development campaign or world census
is not intrinsically required for each tuning. Existing generated ore nodes
will not change: fresh worlds/newly generated areas are necessary to observe
new placement. Do not promise retroactive editing of pregenerated worlds.

The accepted T6 G1/G2 baseline is eight target nodes of each locally assigned
gem family per 4,096 fully eligible host nodes; deep multipliers and the
Goldsmith's existing extra-drop chance can raise actual collectible yield.
Only 1–3 gems go into an individual trinket, and generic Goldsmith enchants
consume settings/reagents rather than gems. Thus the curve is intentionally
comfortable and may need later reduction; no measured economy certification
is claimed. Recommendation: playtest the accepted curve rather than change it
again without evidence.

## Approved F5 — Affordable basic arrows (Sol, independent Astra review)

Current recipe: **1 Iron Bar + 4 Sticks + 4 Sharp Feathers -> 20 arrows**
(`grug_professions/base_recipes.lua:135–140`). Ammo stacks and Scout starter
quantity are already 200. The real sharp-feather source is the Crag Eagle/
Vulture table, guaranteed 1–2 per kill (`grug_mobs/eagle.lua:94–104`). Current
named-zone mountain eligibility first appears in level-21–30 Frostbarrow Shelf
and Speargrass Reach; these are hostile birds, not guaranteed beginner critters.
Gulls and parrots currently provide meat, not feathers. This makes basic
ammunition depend on the wrong progression stage.

Approved for this round:

- One **Bronze Bar + two Sticks -> 200 existing basic arrows**, no feathers.
- Diagonal shaped recipe below, shown immediately in Basics. Mirror the
  diagonal if desired using an explicit equivalent registration, not a broad
  shapeless matcher. The vertical one-bar/two-stick layout is already the
  shovel recipe and must not be reused.
- Retain one ammo item, stack 200, starter 200, current damage and quiver logic.
- Keep sharp feathers and their drops for the existing later gear/alchemy uses.
- No arrowheads, new intermediary crafts, bird population expansion or ammo
  damage tiers in this fix. Output quantity is already one easy balance knob.

```text
--M
-S-
S--
```

M = Bronze Bar; S = Stick. **Bronze only**: no Iron or other metal alternatives.

Tiered bonus arrows are a possible later package. It must specify ammo
selection in mixed stacks/quivers, exact ammo identity on refund, what Twin
Shot consumes, and damage stamping before flight. The current consume/refund
path assumes a single basic arrow type (`grug_inventory/bags.lua:101–175`);
adding damage icons alone would be incomplete. Critter feather access can be
designed with that later package if still useful.

Ownership: `grug_professions/base_recipes.lua` and derived/mirrored Basics
routes (`grug_jobs/basics_routes.lua:287`). Verify recipe conflict and real output
count/capacity with a compact fixture. No mapgen tests or projectile changes.

## Final approval record

User approved the full round, corrected Gold row, Bronze-only cost fix and
10-second normal metal smelting. Existing 15/80/80 fuel, work-triggered ignition,
no charcoal substitution for mined-coal recipes/quests, and the bounded visual
choices are accepted with that Go. Higher-damage arrows and intermediates remain
out of scope. Latest test instruction: minimal CPU work, at most six CPU workers,
report estimated test cost once implementation agents are running.
