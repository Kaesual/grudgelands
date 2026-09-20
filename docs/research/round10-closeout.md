# Round 9/10 decision reconciliation

Final integrated status and exact gate identities: [Round 10 final completion](round10-final-completion.md).
Final technical gates PASS. The reviewed changes are delivered on main, synchronized
and pushed; GUI acceptance remains pending.

Engine verification snapshot: `8dd1c8e4`; the central completion record binds
the delivered source and final interpreter inputs. EQUIP, GAME, WORLD,
ART, CAP, FARM and MAP-B are integrated and independently clean. Six-capital and
six-start engine witnesses, static checks and the full combined LuaJIT gate pass.
Final interpreter parity passes; overlay attribution is independently CLEAN. Authority order is user ruling,
decided design, then implementation evidence. Delivered subpackages do not complete their parent WPs or constitute GUI
acceptance.

## Confirmed unhandled or not-yet-closable requirements

1. MAP-B `02f37ec0` is independently clean, including its bounded engine and current-save evidence. Engine witness tooling is source-reviewed. The final interpreter pair and integrated engine fleets pass; main delivery, synchronization and push are complete.
2. WORLD reports a retained decided/source discrepancy: `world_zones.md` V1e
   assigns width 24 to village and both bandit profiles, while
   `bandit_frontier` still has `building_core_width = 16`. This belongs to the
   remaining WP13 POI work; design must not be rewritten to 16.
3. EQUIP, GAME, WORLD, ART, CAP, FARM and MAP-B are integrated and independently clean. CAP emits eight profession trainers, seven stations, four mount displays and three gear displays per capital (48/42/24/18 across six); GUI acceptance remains pending.
4. The full first-public-release WP40 gates, WP49 fixed source-audit refreeze,
   WP22 durability, WP24 Housing, Scout, WP46 and WP47 remain open by explicit
   scope. R7's 157-file audit is historical evidence, not current certification.

## Ruling-to-owner-to-evidence matrix

| Ruling(s) | Decided outcome | Design owner | Code/evidence state | Remaining CLOSE action |
|---|---|---|---|---|
| R9 1, 4, 24 | PROF-A/B, FARM and ENCH lane cut; crafted/drop quality share stack metadata | `items_crafting.md`, `professions.md` | Round-9 catalogs, farming and `grug_quality`; their KATs/completion records | Preserve as historical delivery, remove lane-planning authority from TODO |
| R9 2, 17, 19, 47, 51 | Familiar recipe UI/stations; exclusive **Basics** vs owning profession; readable group alternatives; Cooking grid/furnace; brewing has two reagents | `professions.md`, `inventory_equipment.md`, `items_crafting.md` | Integrated EQUIP fixes provenance/display; existing Cooking/brewing adapters | Integrated CAP supplies public stations; final GUI playtest |
| R9 3, 24, 51 | All 17 crop families farmable and used; crop art from licensed pinned sources | `items_crafting.md`, farming design in current item/world docs | Integrated FARM mechanics, ART visuals and reviewed MAP-B acquisition/soil/world lifecycle | Final interpreter parity PASS; GUI acceptance remains |
| R9 5, 25–26, 32, 37, 42; R10 mount rulings | Mount tiers replace, warning probes classification, hard boundary dismount, invulnerable/no drops, combat/takeoff/ceiling rules, prices 200/1500/24000/100000, no attacks mounted; owner-only first-person hide, untimed status, one-node step, T1 6.4 | `mounts.md`, `combat_stats.md`, `economy.md` | Existing R9 mount package plus clean GAME `b887124d`; lifecycle, PvP and signed cliff-boundary evidence close prior drift | Integrated CAP trainers and ART icons; GUI camera/step/boundary acceptance |
| R9 6–8 | V1 boundary and mapgen sequencing/performance sensitivity | ROADMAP, BACKLOG, `world_zones.md` | PERF shipped; execution graph supersedes old sequence | Keep Housing/release gates open; reflect final package graph without claiming whole Round 10 shipped |
| R9 9–12, 21, 30, 34–36, 40–41, 46, 56; R10 4–5 | Retired plateau/writer proposals withdrawn; current cave rule uses functional footprints and natural openings; coast enabled; preserve three Rock Salt endpoints; perf evidence limits remain | `world_zones.md`, `world.md`, WP40 research | MAP-C/PERF historical evidence; integrated WORLD implements current cave/material decisions | Retain measurement history and keep final and first-release gates honest |
| R9 13–15, 27, 52–53 | Boss package: two 18k dragons, tier-normal Kraken, two uncrowned guards; particles hundreds; ambient one-node idle descent; visible dragon rest travel, target-only skills, peaceful excluded | `biomes_mobs.md`, `combat_stats.md` | MOB2/BOSS on main; independently clean GAME `b887124d` corrects idle/cliff/dragon/scorch paths and signed rounding | Integrated; GUI behavior checklist remains; do not claim broad pathfinding |
| R9 16 | Capital ring/gates two nodes outward; Undead z-wall bar rotation | `settlements.md` / WP13 design | Integrated CAP carries the fixes into new layouts with clean source/geometry review | Six-capital engine witness PASS; attribution is CLEAN; GUI acceptance remains |
| R9 18, 22 | Discovery: unlocked tier + seen ingredients; learning marks T1 inputs seen | `professions.md`, `items_crafting.md` | `grug_jobs/discovery.lua` and PROF evidence | Docs/API summary reconciled; retain real-route GUI check |
| R9 23 | Combat mana floor `max(¼ OOC, 0.25% max mana/s)` | `combat_stats.md` | R9-MANA implementation/evidence | Status reconciled; retain runtime limitation |
| R9 28, 38–39, 44 | Caster 1H and 36 tiered trinket IDs; six special consumers; placeholder Setting counts; Last Light 120 s | `items_crafting.md`, `inventory_equipment.md` | `grug_trinkets` plus `tools/r9_trinkets`: Manawell, Mercy Seal, Last Light, Battlebeat, Reclaimer, Apothecary; event-driven equipment cache and per-character identity handling | Stale prose corrected; preserve Setting-count follow-up and exact caps/cooldowns |
| R9 29, 31; R10 8 | In-place refinement; +15% stat; durability stays WP22; direct Add Affix appends one legal slot; imbue/temper remain separate | `items_crafting.md` §6b, `inventory_equipment.md` | EQUIP station transaction and quality KAT preserve concrete stack, wear/meta, deny-before-roll | Integrated and independently reviewed; keep durability explicitly open |
| R9 33 | Intermediate conversion recipe tier follows output; gear keeps own-tier ingredient rule | `items_crafting.md` §2.3 | Profession registries/KATs | Exact rule folded; no design question remains |
| R9 43 | R7 roster remains frozen at 157; WP49 replaces it with fixed mapgen roster | AGENTS, BACKLOG WP49, WP40 research | Historical final micro only | State limitation exactly; never label current source audit green |
| R9 45 | Authorized orchestration/push history | process/execution research only | Superseded operational history | Preserve concise research history, omit from living game design |
| R9 48; R10 6–7 | Universal plain feedstocks and familiar base gear; exact 5/8/7/4 armor grids; sword 2 bars + wood stick or same-tier rod; no G2 surcharge | `items_crafting.md`, `inventory_equipment.md` | EQUIP exact independent 2D/yield oracle covers 140 outputs | Integrated and independently reviewed; GUI crafting smoke remains |
| R9 49–50; R10 8 | Seven primaries, two slots; Weaponsmith/Armorsmith split, shared Forge; mastery and profession tiers remain independent | `professions.md`, `items_crafting.md` | Integrated EQUIP: IDs, catalogs, operation gates; mastery bands 1/16/31/46 and profession crafts 10/15/20/25/30 remain separate | Integrated CAP replaced vocabulary atomically; GUI service smoke remains |
| R10 1 | Three of four conceptual vendor extras; deterministic caster subchoice; one-in-five expensive Uncommon is sole exception | `economy.md`, `items_crafting.md` | Integrated EQUIP vendor and GAME weak-potion Apothecary bridge | Integrated and independently reviewed; GUI vendor smoke remains |
| R10 2–3 | Licensed nonweapon visual refresh; weapons unchanged; 12 actual mount renders with documented generic fallback only per failure | visual/media design and license ledgers | ART integrated and independently clean | Evidence landed and was independently reviewed; GUI inspection remains |
| R10 capital rulings | Capital-only Riding Trainers; no start trainer; outer themed profession premises; shared smith forge; 24 static mount displays; protected atmosphere items | `settlements.md`, `professions.md`, `mounts.md` | CAP integrated and independently clean | Independent source/geometry evidence complete; integrated engine and GUI gates remain |
| R10 9 | Fall = `ceil(maxHP*native/20)`, uncapped; native zero; Dwarf then absorb; no armor/dodge | `combat_stats.md` | Integrated, independently clean GAME and expanded KAT | Integrated; run fresh GUI fall samples |

The remaining older R9 rules not individually repeated above are implementation
protocol or superseded sequencing/model-routing history. They belong in the
Round-9/10 research completion narrative, not in living game design.

## Seven Playtest-12 deviations

| Audit ID | Disposition |
|---|---|
| P12-A-REF-01 | Corrected by integrated, independently clean EQUIP terminal operation; final-stack and metadata evidence present. |
| PT12-C-A01 | Corrected by GAME mounted ordinary-PvP refusal; reviewed fix closed. |
| P12-A-BOOK-01 | Corrected by integrated, independently clean EQUIP; Sweetroot remains Cooking-only. |
| P12-A-ROT-01 | Corrected by integrated, independently clean EQUIP four-concept/three-slot rotation. |
| PT12-C-B01 | Corrected by GAME weak-potion Apothecary bridge; reviewed fix closed. |
| PT12-C-A02 | Corrected by GAME scorch combat refresh; reviewed fix closed. |
| LB-A-01 | Corrected by integrated WORLD; independent source review is clean and final gates remain. |

The four former audit decisions are resolved by Round-10 authority: retain the
Uncommon exception, preserve rocky Rock Salt endpoints, use functional cave
footprints, and use the exact percentage-fall formula/order above.

## TODO disposition

- `round9-decisions.md`: all 56 rulings are resolved. Archived after its current outcomes were folded; it is historical evidence, not living authority. Preserve lane/performance
  history in research rather than design.
- `round10-decisions.md`: its seven “Open choices” were all resolved by the nine
  accepted recommendations. Archived as an implementation-planning record; CAP/ART/MAP-B status lives in the execution and closeout records.
- `round8-decisions.md`: explicitly says no open decisions remain. It is archived for delivered/deferred history; current rules live in design/BACKLOG.
- `round7-decisions.md`: its former questions were answered by later design and
  deliveries. It is archived for historical context; unresolved work remains in BACKLOG and its lane/model instructions are not authority.

## Concrete CLOSE documentation edit inventory

1. Reconcile `docs/design/items_crafting.md`, `professions.md`,
   `inventory_equipment.md`, `economy.md`, `mounts.md`, `combat_stats.md`,
   `biomes_mobs.md`, `world.md`, `world_zones.md` and `settlements.md` to the
   matrix. Remove Blacksmith, General-book, profession-gated plain feedstock,
   absolute Common-only, old base-cost and retired plateau contradictions.
2. Update `docs/research/round9-design-drift.md` and Playtest-12 audit overview
   with explicit dispositions and candidate/review evidence while preserving
   their historical baseline and limitations.
3. Update AGENTS' jobs API to seven primaries plus secondary Cooking, shared
   Forge and terminal operation semantics; add actual mount untimed-status,
   boss/UI seams and R7 audit limitation. Preserve native-provider and current
   no-Claude process rules verbatim.
4. Update BACKLOG/ROADMAP only at honest whole-WP granularity. Keep WP22, WP24,
   WP46, WP47, WP49 and public-release obligations open. Reconcile WP5/WP10/
   WP13/WP23/WP27–32 statements with delivered subpackages without declaring a
   partial WP complete.
5. Rewrite README Current State to concise derived shipped/in-progress/not-yet
   sections, current date/counts, design-tour links and GUI/evidence caveats.
6. Delete resolved Round 7–10 TODOs only after their surviving decisions and
   incomplete work are represented in design/BACKLOG/research.
7. Add a fresh-world playtest checklist with a short smoke route and optional
   race/tier coverage: Basics/Cooking/refinement, six capitals/services,
   mount cameras/steps/boundaries, falls, ambient mobs/dragons, farming/wild
   plants, Dawnmere cave witness, mountain materials and final art. Use verified
   item IDs/commands from the integrated tree; GUI acceptance remains user-run.

## Truly open after reconciliation

No Round-9/10 gameplay choice in these TODOs remains open. Open work is
acceptance or later implementation: the integrated GUI playtest, the bandit-frontier WP13
width mismatch, and the explicitly excluded backlog/release work listed above.

## CLOSE package calibration

- Implementing model: GPT-5.6 Sol, native agent.
- Classification: non-trivial documentation reconciliation; no gameplay or
  runtime execution owned by this package.
- Engine verification base: `8dd1c8e4`; final delivery identities are in the
  central completion record.
- Earlier CLOSE candidate `93cc` received an independent review and one focused
  correction round; the final dynamic prose is independently reviewed.
- Final parity, main delivery, synchronization and push are complete. GUI
  acceptance remains pending.

The post-integration display-placement correction `561a9c2b` and outer-cadence
correction `ccd10d96` are independently source-reviewed. Their successful v3
engine witnesses supersede the failed/intermediate attempts, which remain
preserved. [Overlay attribution](../../tools/r10_capital_phase/ATTRIBUTION.md)
accounts for all 18 old/new regions; its independent review is CLEAN, as is the current-baseline review.
