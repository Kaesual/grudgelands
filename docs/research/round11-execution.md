# Round 11 execution checkpoint

Date: 2026-09-20. Status: **IMPLEMENTATION / INDEPENDENT PACKAGE REVIEWS IN PROGRESS**.
Runtime baseline: `ac232ec2`. Integration branch: `wp11-r11-integration`. GAME, WORLD-CAP, GEAR, COMBAT and ART are accepted and integrated; FARM, REPAIR, SCOUT and final SPEC reconciliation remain open. No personal-world mutation is authorized.

The [independent plan review](round11-plan/review/report.md) is CLEAN on v3:
0 Critical / 0 High / 0 Medium / 0 Low open. Two initial Medium contradictions
were fixed; report and v1/v2/v3 input manifests are retained under
`round11-plan/review/`. Implementing/planning models: root Astra and three Sol
planners; independent reviewer: native Astra, no plan authorship. Two correction
rounds, observed elapsed wall time unknown. This is planning evidence only.

## Resume authority

Read [the plan](round11-plan/README.md), its three annexes and
[the user-ruling record](round11-planning-decisions.md). The user's last
clarifications are binding: use all armor rating before the 70% reduction cap;
near-cap protection against L70 dragons requires top tank gear PLUS deep
Protection/Bulwark. DPS Warrior with the identical gear must remain below that
result. Do not restore the rejected effective-rating ceiling or one-handed
staff proposal from earlier discussion.

Native Sol workers are the normal route. Astra may own difficult world or
performance work. No Claude in this session. Never call own-provider workers
through CLI. Three worker slots plus root; assignments are recorded below.
Planning agents and the independent reviewer are finished after their final
reports. Their task handles may be reused now within review-independence
rules; planning a contract does not authorize reviewing contested rules one
has authored.

## Current execution sequence

1. SPEC: fold the approved plan into living design and reconcile all source
   conflicts; exact item/price catalogs follow the plan's fixed rules. Update
   BACKLOG/ROADMAP/README only as actual statuses change. Remove the Round 11 TODO.
2. Create isolated branches/worktrees and record ownership. First lanes GAME,
   WORLD-CAP and AFF-GEAR. Publish shared interfaces before their consumers.
3. Follow the plan's dependency order, independent reviews, targeted engine
   checks under the latest user override: **no PUC runtime tests at all this round**;
   retain luac51 syntax, SETGLOBAL and all five static sweeps. No broad census/PERF rerun or reference
   repin. No dedicated gate-stair test, per explicit user instruction.
4. Merge/sync/push only after completed acceptance, then deliver the next
   fresh-world GUI checklist. Existing GitHub authorization remains valid.

Keep this checkpoint current with exact heads, active assignments, completed
packages, open findings, evidence and the next concrete action. Do not resume
Round 10 work or select unrelated backlog packages after compaction.

## Latest authority amendment

The user gave Go on 2026-09-20, recommended native Astra for the difficult beach
fix, and explicitly rejected long LuaJIT runs and PUC runtime testing for this
fix round. This overrides the prior final parity requirement in the reviewed
plan and annexes; no fallback runtime proof is claimed. Ordinary tasks use Sol.

## Ownership

Root owns orchestration/checkpoint, integration, BACKLOG/ROADMAP/README and
remaining cross-package spec reconciliation. Worker branches are recorded when
created. No CLI delegation and no Claude in this session.

### Active initial lanes (all based on 45fbc477)

- `r9_perf` — native Astra, `wp40-r11-world-cap`, worktree
  `.claude/worktrees/r11-world`: WORLD-CAP and its world_zones/settlements/mounts
  living-spec fold. SPEC commit `7e63e965`; beach diagnosis and CAP in progress.
- `playtest_professions` — native Sol, `wp14-r11-aff-gear`, worktree
  `.claude/worktrees/r11-gear`: AFF-GEAR, item/price catalog and
  items_crafting/inventory_equipment/professions/scout equipment spec.
- `playtest_creatures_camera` — native Sol, `wp23-r11-game`, worktree
  `.claude/worktrees/r11-game`: GAME runtime and combat_stats/classes/skill_trees/
  biomes_mobs spec fold. COMBAT runtime follows GEAR, not concurrent ownership.
- Root: farming/durability living specs, economy/world R4/visual amendments,
  indexes and round status. No runtime code owned by root yet.

Each worker writes its own package evidence. No worker may sync, push or merge
main. Reviews will use a different author from implementation.

### Mid-round checkpoint

- GAME `56148dec`: runtime complete, independent native Sol review initially
  found same-level preview wording (fixed) and then missing vendor patch ledger
  (fix in progress). CAP supplied measured move-minimum floor offsets to be
  integrated before final review. Review `/tmp/grudgelands-r11-game-review.md`;
  preserve it in repo on acceptance. No GAME merge yet.
- WORLD-CAP `0ff61733`: SPEC + capital geometry committed. Beach actual cause is
  fallback coast orientation/run aliasing on diagonal shore lattice sampling,
  not the initially suspected generic exclusion. Two65×65 witness experiments
  remove narrow peaks7→0 and9→0; targeted real-planner proof pending.
- AFF-GEAR SPEC `79d5f304`; runtime/catalog in progress. Owns additionally
  grug_artisans/{woodcarver,goldsmith,init}.lua and trader stock retired-family
  consumers. Armor affix totals API `.armor_rating`, shield base `_grug_armor`;
  COMBAT owns final conversion after GEAR.
- Root FARM water/hoe slice `e3469484`, worktree `.claude/worktrees/r11-farm`,
  branch `wp33-r11-farm`: protected ordinary/river bucket and seven repairable
  hoes, bounded water guard, neutral system mutation API. Real-module LuaJIT
  water/hoes17crop tests pass under1s each, parser/SETGLOBAL/sweeps pass.
  Awaiting independent review, ecology/density and integrated engine checks.
- Root SPEC `16b7449c` introduced farming.md and durability_repair.md, revised
  world R4/economy/visual rules and derived status/indexes. Other live-spec folds
  remain on worker branches pending acceptance. Round TODO deletes on integration.

Next: finish GAME findings and independent rereview, release its implementation
worker to FARM ecology while GEAR continues. WORLD then independent review; ART
media via new files/patches, not simultaneous registration writes. Later COMBAT,
REPAIR and SCOUT still required. No partial-package final answer or playtest-ready
claim; no sync/main/push has occurred in this round.

### Accepted GAME / current worker rotation

GAME independently CLEAN at `43c09f39` and merged into integration (not main).
Final report archived at `round11-plan/review/game-final.md`. Implementer native
Sol with root Astra integration fixes; independent reviewer native Sol. Initial
findings0C/0H/3M, four correction iterations including vendor crossreferences,
final0open; elapsedunknown. Actual floor seam regression caught andfixed.

`r11_game_review` now owns FARM ecology in `.claude/worktrees/r11-farm`, starting
at rootwater/hoe e3469484; it must not independently review its own FARM work.
`playtest_creatures_camera` is inactive. Native thread slots may require reuse
of an existing idle handle instead of resurrecting a retired one; never useCLI
as a workaround. WORLD supplied exact existing geometry bridge locations for
FARM: zones.lua planner_source -> originalhorizontal/height queries, publish via
r7_loader built.planner_source; no duplicatedgeometry/constructor.

ART worktree `.claude/worktrees/r11-art`, branch `wp29-r11-art`, basef0173d85.
Root prepared sourcecontactsheet `/tmp/grudgelands-r11-reference-contact.png`
and detailed boundedhandoff `/tmp/grudgelands-r11-art-handoff.md` (archive upon
ARTassignment). One imagegen quiver fills an identified referencegap; original
`/home/jan/.codex/generated_images/01a0bb7c-607d-7420-9795-366d4be0d06a/exec-49912ac9-fe32-40b7-a0eb-3e0ca8aac5bf.png`
copied into ART `mods/PLAYER/grug_inventory/textures/grug_inventory_quiver.png`.
Actual1254x1254transparentRGBA, visuallyacceptedroot, notyetcommitted/consumed.
RemainingART uses licensedreferenceassets. Read imagegen skill only if needed;
no CLI/APIfallback was used.

### Review checkpoint after worker rotation

- GAME accepted/integrated at43c09f39; final report committed445e04c9.
- GEAR frozen d0190d4a; fresh native Sol `r11_gear_review` independently reviews.
- WORLD-CAP frozen6270c80d; fresh native Sol `r11_world_review` independently reviews.
  Actual8450columns show peaks7→0/9→0, actual planner6columns and48serviceplots
  pass; source/output hashes recorded in round11-world-evidence.md.
- FARM ecology now native Sol `r11_game_review/farm_ecology_impl2`; coordinator
  parent ended its turn to free a slot. Concrete geometry bridge resolved;
  parent/child both ineligible for independent FARM acceptance.
- ART root authored station assets c76e6bba and merged frozen GEAR into ART only.
  Final gear images/seed maps/Silversteel/bow pose remain in progress.
- COMBAT, REPAIR and SCOUT remain required, not started. Integration has not
  merged GEAR/WORLD/FARM/ART, main remains R10, no sync or push yet.

### Accepted WORLD / active second wave

WORLD6270c80d independently CLEAN by fresh nativeSol, merged into integration.
Report archivedround11-plan/review/world-final.md; authorAstra, zero findings,
zero correction rounds, elapsedunknown. Five textured views remain GUIlimited.
GEARreview found1Medium+2Low, correctedbyrootAstra18bbeacb: sharedmasterybook
gate, throttledfullquiverrefusal, actualfilledtransfer/unchangedrefusal fixture.
Focused independent rereview awaitsfree worker slot; reportgear-initial.md.
ART now nativeSol `r11_world_review` in r11-art withrootassets+GEARmerged;
rootno longeredits ART. Durablebriefround11-art-brief.md.
COMBAT nativeSol `r11_combat`, isolatedwp4-r11-combat worktree r11-combat based
integration445e04c9+GEARd0190d4a, formula/provenance/talents/bossconsumers.
AgreedneutralREPAIRseams: register_on_settled_outgoing_action /
run_settled_outgoing_action(player,action_id,kind), register_on_settled_incoming_hit.
Root preparesREPAIR independentfiles whileCOMBATpublishes finaleventowners.
FARM childcontinuesecology. NoPUCruntime, no broadcensus, no main/sync/pushyet.

### Accepted GEAR and COMBAT / REPAIR handoff

GEAR18bbeacb nowindependently CLEAN, mergedintegration. Initialreview1M2L,
rootAstra correctedall, freshnativeSol focusedrereview clean; reportgear-final.md.
COMBAT3a9f0ce0 independently CLEAN (authorSol, reviewerfreshSol, zero findings),
mergedintegration; reportcombat-final.md. Sourcebaseafa8d883/code4dbb65be.
ARTfirstreview1Medium incorrectIron/EmberShieldsourcecolors; authorfixed28ef659a
withruntimegrades+actualtreatedpreview; sameindependentreviewer focusedpending.
REPAIR rootservice4054776c addsgrug_repair service/providers+atomicmoneytransaction
+trainerUI. Realservicefixture coversquotes/metadata/funds/provider/stalefroms/
writefailure rollback. COMBAT dependencymergedinrepair, nowsoleworker nativeSol
`r11_combat_review` ownsallremainingwear/broken-state/actionhooks. Rootnoedits.
REPAIRhandoff includes projectileconcreteweapon identity and cadence/no-doublewear
risks; fullpackage includingrootservice needsfreshreviewafterfreeze.
FARM scheduling correction: nestedchild remainedpending_init withoutsourceedits;
rootinterruptedand replacedwithdirectnativeSol `r11_farm_direct`. It nowsoleowns
farmworktree; no furthernesteddelegation. Allthreeactiveworkersdirect.
SCOUT implementationfollowsREPAIRsharedfilefreeze; stillrequired.
NoPUC/no main/sync/push. Currentmain remainsac232ec2.

### ART accepted / authority reconciliation

ART28ef659a independently CLEAN after1Mmaterialcolorfinding andonefixround.
Merged intointegration; allstationmedia/gearassets/seed_visuals nowavailable.
GEARandCOMBAT alsoacceptedandintegration, reportsarchived.
FARMdirectworker reported inherited14cb3a14 fromnestedworker (priornoeditstatus
wastransient); its aggregatebridge duplicatedhabitatlogic, nowbeingcorrectedto
exactexistingquerydelegates. DirectworkerownsallFARMsuccessorwork.
Round11TODOdeleted: userGoand living-specfoldcomplete; runtimepackagesstillopen.
Rootnoticed staleD2four-affix textinitems_crafting despiteR11topsections; final
active-doc authorityaudit required beforedelivery.


### FARM and REPAIR first reviews / SPEC reconciliation

FARM frozen `e5486a85`, then evidence-only correction `a6889da2`: independent
native Sol found one Medium stale input-hash manifest and one Low trailing
blank line; no material product-code defect. Both corrected by root, focused
rereview active (`r11_farm_review`). Reviewer reran only targeted LuaJIT gates
and parser; no PUC runtime. Initial report `/tmp/grudgelands-r11-farm-review.md`.

REPAIR frozen `2ad85b15`: fresh independent Sol found four High defects (last
combat-wear event rounding; broken hoe operation; persistent projectile item-ID
collision after restart; per-target heal/absorb wear), one Medium missing actual
wear-runtime proof and one Low stale vendor ledger. Direct native Sol
`r11_repair_fix` owns corrections in r11-repair; no acceptance or merge yet.
Initial report `/tmp/grudgelands-r11-repair-review.md`. SCOUT waits for corrected
shared-file/interface freeze; do not build on the rejected event semantics.

SPEC reconciliation is native Sol `r11_art_review`, isolated `r11-spec` branch
`wp11-r11-spec-audit` from `bc112522`. Owns active design-doc contradictions and
AGENTS technical primer only; root owns status files/checkpoint. It must retain
historical evidence and separate still-open Scout consumers from shipped gear.
A fresh independent reviewer must check its final contract changes.

Root prepared `round11-next-playtest.md` as a draft, not a readiness claim.
Main/runtime remain `ac232ec2`; no Round11 sync or push yet. User's no-PUC and
minimal-test budget remain binding. Continue all packages through delivery.


### FARM accepted / SCOUT preparation

FARM `a6889da2` independently CLEAN (Sol reviewer, root water/hoe base plus Sol
ecology implementation, initial 1M/1L evidence-only findings, one correction
round, elapsed unknown). Integrated as `b5c4238d`; the only merge conflict was
two additive media-license sections, both retained. Seed presentation hooks
now resolve against accepted ART's 17-family map. The focused crop fixture was
rerun successfully at the integration seam. Reviews archived as farm-initial.md
and farm-final.md.

SCOUT native Sol `r11_scout`, isolated `.claude/worktrees/r11-scout` branch
`wp11-r11-scout` from `b5c4238d`. It may draft independent new modules now;
shared files wait for corrected REPAIR freeze and dependency merge. All16
Quarry/Veil consumers, four base abilities, arrows/draw/transactions, starter,
Bowyer bracket and Tanner shelf remain mandatory. No independent review yet.

SPEC first review of `da3a4958` requested4Medium corrections: Scout greataxe,
stale leather/Rogue/poison clauses, old talent/Unbroken status and an overstrong
audit conclusion. Original author `r11_art_review` owns the corrections;
independent reviewer `r11_farm_review` remains separate. Report spec-initial.md.

Root is preparing `tools/r11_integration/engine_probe` for one bounded final
LuaJIT engine boot: complete registrations and native water callbacks in one
scratch block, with automatic six-capital preload disabled in the disposable
probe only. No mapgen census or user-world writes; no engine result claimed yet.


### SPEC accepted / REPAIR cadence correction

SPEC `ee6c3f6a` independently CLEAN and integrated (Sol author, root final one-row
correction; independent Sol reviewer; initial4M then1L, two correction rounds,
elapsedunknown). Report spec-final.md. All reviewed active-doc authority
contradictions are closed; the Scout trader consumers remain explicit work.

REPAIR correction `c53a512d` fixes exact lifetime arithmetic, generic broken
on_use, persistent concrete item receipts, shared heal/absorb action identities,
real runtime KAT coverage and all current vendor66-marker crossreferences.
Second independent review confirmed one High integration defect: metadata-only
wear/identity writes trigger the full ItemStack weapon-change comparator and
restart held-swing cadence/late carry. A separate alleged table-ID rejection
was retracted after direct LuaJIT expression and first-debit checks; preserve
that correction in repair-second.md rather than counting it as a product bug.

Native Sol `r11_repair_fix` owns the narrow cadence/notifier correction in
r11-repair. Scout merged the frozen dependency as `760a3d23` after its isolated
new-module checkpoint `b495e2a8`, but pauses shared abilities/init.lua and
inventory/equipment.lua until the corrective handoff. Other Scout implementation
continues. Final acceptance still requires independent REPAIR and SCOUT reviews.

Root's bounded engine probe is committed `bb166bf5`; read-only fixture review
is active before execution. Flatpak `luanti --version` confirms Luanti5.17.0
with LuaJIT2.1.1784272936 (OpenResty); no PUC runtime is planned or executed.
Main/runtime stay `ac232ec2`; no Round11 sync or push yet.


### Scout trader parallel split

The bounded engine fixture independently passed static/native-contract review
at `bb166bf5`; report engine-probe-static.md. Execution still waits for final
SCOUT/REPAIR bytes. This is not an engine-runtime pass.

Scout class/projectile work now includes frozen checkpoints `ad85d7fc` (batch
spawn rollback/token accounting) and `fd7b9cca` (public ammunition refund).
Its two paused shared files remain under the REPAIR cadence correction.

To shorten the critical path, native Sol `r11_farm_review` now implements only
Scout trader stock/UI in isolated `.claude/worktrees/r11-scout-traders`, branch
`wp11-r11-scout-traders` from `6bd8a6b8`. It did not author Scout runtime and
will not review its own trader slice. Scout worker confirmed no trader edits.
Trader acceptance remains the approved Bowyer bow bracket/player-arrow supply
and Tanner leather grades using existing price/rotation machinery; no economy
rebase. Root integrates only after an independent review.


### REPAIR accepted / final Scout implementation

REPAIR `20ab7b50` independently CLEAN and integrated after two correction rounds.
Implementers: root Astra service/transactions, native Sol runtime and corrective
Sol; reviewer separate native Sol. Initial4H1M1L, then1confirmedHigh cadence;
one alleged ordinary-table bug was explicitly retracted, not a product finding.
Final0open, elapsedunknown; report repair-final.md. Fresh runtime/service/armor/
WP39 swing/projectile evidence covers the changed seams; no PUC runtime.

`equipment_changed(player,listname,reason)` and the core notifier now forward
optional `durability_metadata`. Wear/remainder/capability bookkeeping and first
persistent projectile identity update the clock snapshot without resetting a
usable same-name weapon's cadence. Actual swaps and broken/unbroken transitions
keep the conservative full-interval reset. Nested notifications coalesce safely.
SCOUT shared-file ownership is released and the worker must merge20ab7b50,
including respect for this reason in its draw-cache consumer.

Remaining: SCOUT runtime+traders, independent reviews, one bounded native engine
witness, final targeted static/integration gates, status reconciliation, main
merge/sync/push and next-playtest delivery. Root has not declared delivery yet.


### Scout traders accepted / frozen Scout source review

TRADERS `9730af25` independently CLEAN and integrated: native Sol author,
root final comment correction, different native Sol reviewer; initial2M1L
(rotation authority and inactive quality fixture branch), then one additional
stale-comment Low, two correction rounds, elapsedunknown. The final shelf has
13 fixed +4 rotating items, exactly one of five extra families withheld, as
already required by items_crafting §3.8. Bowyer and Tanner are filtered views;
actual trade render, buy recomputation and stale-hour rejection are tested.
Quality roller is a clearly disclosed synthetic seam in the focused fixture.
Reports scout-traders-initial.md and scout-traders-final.md.

SCOUT source checkpoint `08f6f8b2` is frozen after clean REPAIR20ab7b50 merge;
no known production gap reported. Native Sol author finishes focused
`tools/r11_scout` gameplay KAT/static/evidence. Fresh native Astra
`r11_scout_review` independently audits the frozen combat/projectile/talent/
ammunition integration while tests finish; final acceptance waits final bytes
and evidence. This is an authorized hard-task model choice, no external CLI.

Root additionally found stale skill_trees §3.4 Scout button arithmetic: the
approved four class skills plus universal Strike mean5base/7maximum, not the
old Strike+3/6 table row. The approved plan/scout §2 govern implementation;
root will reconcile that status/table with final delivery docs. No new design
choice is required. Main/runtime still R10ac232ec2; no Round11 sync/push yet.


### Scout independent integration findings

Astra's preliminary source review of `08f6f8b2` plus gameplay fixture
`d4ace47e` found1High4Medium, all being corrected by the native Sol Scout
owner before final acceptance. Initial report scout-initial.md.

- Opening's mana_percent cost is not resolved on the held-swing path; snapshot
  the effective cost for eligibility and accepted settlement.
- Snare/Pinning mistake published damage for accepted HP-loss settlement.
- Delayed Loose release does not recheck mounted state.
- Existing grug_quality equipment_changed wrapper drops REPAIR's third reason,
  defeating the independently tested direct notifier seam in the full game.
- Shake Loose suppresses existing slows for4seconds but does not dispel them;
  a longer pre-existing slow returns, contrary to the accepted talent rule.

The worker owns narrow corrective core/movement/quality hooks as needed; other
agents remain read-only on these files. Actual combined-consumer regression
fixtures must cover every finding (cost/settlement, quality wrapper+clock/draw,
real movement aggregator), not substitute success stubs for the tested boundary.
The quality finding is a cross-package REPAIR integration defect; retain this
record rather than treating its prior isolated acceptance as whole-game proof.
Final Astra review and the bounded native engine witness still remain required.
