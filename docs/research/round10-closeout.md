# Round 9/10 decision reconciliation preflight

Read-only snapshot: main `1831ec68`; candidate inputs EQUIP `b8dc0db3`, GAME
`d4138bf0`, WORLD `7f009e87`; CAP active; ART and MAP-B incomplete. Authority
order used here is user ruling, decided design, then implementation evidence.
No candidate is called shipped by this preflight.

## Confirmed unhandled or not-yet-closable requirements

1. GAME is independently clean at `b887124d` after two Medium fix rounds; its final signed-rounding oracle proves the one-node/two-node boundary.
2. WORLD reports a retained decided/source discrepancy: `world_zones.md` V1e
   assigns width 24 to village and both bandit profiles, while
   `bandit_frontier` still has `building_core_width = 16`. This belongs to the
   remaining WP13 POI work; design must not be rewritten to 16.
3. CAP, ART and MAP-B are not frozen. Capital services/atmosphere, final visual
   imports and all 17 complete crop lifecycles cannot be marked delivered yet.
4. The full first-public-release WP40 gates, WP49 fixed source-audit refreeze,
   WP22 durability, WP24 Housing, Scout, WP46 and WP47 remain open by explicit
   scope. R7's 157-file audit is historical evidence, not current certification.

## Ruling-to-owner-to-evidence matrix

| Ruling(s) | Decided outcome | Design owner | Code/evidence state | Remaining CLOSE action |
|---|---|---|---|---|
| R9 1, 4, 24 | PROF-A/B, FARM and ENCH lane cut; crafted/drop quality share stack metadata | `items_crafting.md`, `professions.md` | Round-9 catalogs, farming and `grug_quality`; their KATs/completion records | Preserve as historical delivery, remove lane-planning authority from TODO |
| R9 2, 17, 19, 47, 51 | Familiar recipe UI/stations; exclusive **Basics** vs owning profession; readable group alternatives; Cooking grid/furnace; brewing has two reagents | `professions.md`, `inventory_equipment.md`, `items_crafting.md` | EQUIP candidate fixes provenance/display; existing Cooking/brewing adapters | CAP supplies public stations; final GUI playtest |
| R9 3, 24, 51 | All 17 crop families farmable and used; crop art from licensed pinned sources | `items_crafting.md`, farming design in current item/world docs | Mechanics exist on main; ART/MAP-B incomplete | ART bindings + MAP-B acquisition/soil/world lifecycle and GUI proof |
| R9 5, 25–26, 32, 37, 42; R10 mount rulings | Mount tiers replace, warning probes classification, hard boundary dismount, invulnerable/no drops, combat/takeoff/ceiling rules, prices 200/1500/24000/100000, no attacks mounted; owner-only first-person hide, untimed status, one-node step, T1 6.4 | `mounts.md`, `combat_stats.md`, `economy.md` | Existing R9 mount package plus clean GAME `b887124d`; lifecycle, PvP and signed cliff-boundary evidence close prior drift | CAP capital-only trainers; ART 12 icons; GUI camera/step/boundary acceptance |
| R9 6–8 | V1 boundary and mapgen sequencing/performance sensitivity | ROADMAP, BACKLOG, `world_zones.md` | PERF shipped; execution graph supersedes old sequence | Keep Housing/release gates open; reflect final package graph without claiming whole Round 10 shipped |
| R9 9–12, 21, 30, 34–36, 40–41, 46, 56; R10 4–5 | Retired plateau/writer proposals withdrawn; current cave rule uses functional footprints and natural openings; coast enabled; preserve three Rock Salt endpoints; perf evidence limits remain | `world_zones.md`, `world.md`, WP40 research | MAP-C/PERF historical evidence; WORLD candidate implements current cave/material decisions | Remove living plateau language, retain measurement history; integrate WORLD only after review; keep first-release gates honest |
| R9 13–15, 27, 52–53 | Boss package: two 18k dragons, tier-normal Kraken, two uncrowned guards; particles hundreds; ambient one-node idle descent; visible dragon rest travel, target-only skills, peaceful excluded | `biomes_mobs.md`, `combat_stats.md` | MOB2/BOSS on main; independently clean GAME `b887124d` corrects idle/cliff/dragon/scorch paths and signed rounding | Integration then GUI behavior checklist; do not claim broad pathfinding |
| R9 16 | Capital ring/gates two nodes outward; Undead z-wall bar rotation | `settlements.md` / WP13 design | Earlier capital fixes exist; CAP carries them into new layouts | Verify six integrated layouts and preserve prior fixes |
| R9 18, 22 | Discovery: unlocked tier + seen ingredients; learning marks T1 inputs seen | `professions.md`, `items_crafting.md` | `grug_jobs/discovery.lua` and PROF evidence | Reconcile docs/API summary; retain real-route GUI check |
| R9 23 | Combat mana floor `max(¼ OOC, 0.25% max mana/s)` | `combat_stats.md` | R9-MANA implementation/evidence | Mark delivered accurately, retain runtime limitation |
| R9 28, 38–39, 44 | Caster 1H and 36 tiered trinket IDs; six special consumers; placeholder Setting counts; Last Light 120 s | `items_crafting.md`, `inventory_equipment.md` | `grug_trinkets` plus `tools/r9_trinkets`: Manawell, Mercy Seal, Last Light, Battlebeat, Reclaimer, Apothecary; event-driven equipment cache and per-character identity handling | Correct stale “inert/not in game” prose; preserve Setting-count follow-up and exact caps/cooldowns |
| R9 29, 31; R10 8 | In-place refinement; +15% stat; durability stays WP22; direct Add Affix appends one legal slot; imbue/temper remain separate | `items_crafting.md` §6b, `inventory_equipment.md` | EQUIP station transaction and quality KAT preserve concrete stack, wear/meta, deny-before-roll | Independent review/integration; keep durability explicitly open |
| R9 33 | Intermediate conversion recipe tier follows output; gear keeps own-tier ingredient rule | `items_crafting.md` §2.3 | Profession registries/KATs | Fold exact rule; remove stale TODO wording |
| R9 43 | R7 roster remains frozen at 157; WP49 replaces it with fixed mapgen roster | AGENTS, BACKLOG WP49, WP40 research | Historical final micro only | State limitation exactly; never label current source audit green |
| R9 45 | Authorized orchestration/push history | process/execution research only | Superseded operational history | Preserve concise research history, omit from living game design |
| R9 48; R10 6–7 | Universal plain feedstocks and familiar base gear; exact 5/8/7/4 armor grids; sword 2 bars + wood stick or same-tier rod; no G2 surcharge | `items_crafting.md`, `inventory_equipment.md` | EQUIP exact independent 2D/yield oracle covers 140 outputs | Independent review/integration and GUI crafting smoke |
| R9 49–50; R10 8 | Seven primaries, two slots; Weaponsmith/Armorsmith split, shared Forge; mastery and profession tiers remain independent | `professions.md`, `items_crafting.md` | EQUIP candidate: IDs, catalogs, operation gates; mastery bands 1/16/31/46 and profession crafts 10/15/20/25/30 remain separate | CAP replaces old trainer/socket vocabulary atomically; update AGENTS API |
| R10 1 | Three of four conceptual vendor extras; deterministic caster subchoice; one-in-five expensive Uncommon is sole exception | `economy.md`, `items_crafting.md` | EQUIP vendor candidate; GAME weak potion Apothecary bridge | Resolve absolute Common-only prose in all design owners; independent review |
| R10 2–3 | Licensed nonweapon visual refresh; weapons unchanged; 12 actual mount renders with documented generic fallback only per failure | visual/media design and license ledgers | ART paused/WIP | Cannot close TODO or claim delivery until normal-size icon, worn mesh, model-render and license evidence lands |
| R10 capital rulings | Capital-only Riding Trainers; no start trainer; outer themed profession premises; shared smith forge; 24 static mount displays; protected atmosphere items | `settlements.md`, `professions.md`, `mounts.md` | CAP active | Six-capital geometry, access and no-drop/reload evidence required |
| R10 9 | Fall = `ceil(maxHP*native/20)`, uncapped; native zero; Dwarf then absorb; no armor/dodge | `combat_stats.md` | Clean GAME candidate and expanded KAT | Integrate; then run fresh GUI fall samples |

The remaining older R9 rules not individually repeated above are implementation
protocol or superseded sequencing/model-routing history. They belong in the
Round-9/10 research completion narrative, not in living game design.

## Seven Playtest-12 deviations

| Audit ID | Disposition |
|---|---|
| P12-A-REF-01 | Corrected by EQUIP terminal operation; final-stack and metadata evidence present; independent review pending. |
| PT12-C-A01 | Corrected by GAME mounted ordinary-PvP refusal; reviewed fix closed. |
| P12-A-BOOK-01 | Corrected by EQUIP canonical provenance; Sweetroot remains Cooking-only; review pending. |
| P12-A-ROT-01 | Corrected by EQUIP four-concept/three-slot rotation; review pending. |
| PT12-C-B01 | Corrected by GAME weak-potion Apothecary bridge; reviewed fix closed. |
| PT12-C-A02 | Corrected by GAME scorch combat refresh; reviewed fix closed. |
| LB-A-01 | Corrected by WORLD mountain/freshwater materials candidate; review/integration pending. |

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
implementation or acceptance: ART, CAP, MAP-B, independent package reviews, integrated GUI playtest, the bandit-frontier WP13
width mismatch, and the explicitly excluded backlog/release work listed above.

## CLOSE package calibration

- Implementing model: GPT-5.6 Sol, native agent.
- Classification: non-trivial documentation reconciliation; no gameplay or
  runtime execution owned by this package.
- Source base: `6a6378d9` with staged reviewed EQUIP `b8dc0db3`, GAME final
  `b887124d`, WORLD source `7f009e87` and CAP design `ddcf6bd3` considered as
  candidate evidence rather than main delivery.
- Independent reviewer: pending coordinator assignment.
- Finding counts and fix rounds: pending independent review.
- Final dynamic status sweep: required after CAP, ART, MAP-B and integration
  settle; this record deliberately does not claim playtest readiness.
