# Round 10 execution and resumption record

Date: 2026-09-20. Baseline: `38ae136d`. Status: authorized, in progress.

## User authority and final decisions

Jan explicitly accepted **all nine recommendations** and authorized autonomous
implementation, independent review, integration and delivery up to the next
consolidated playtest. Preserve this scope through compaction. No further routine
approval is needed. Gameplay corrections previously held for discussion are now
authorized. Git push to `github.com/Kaesual/grudgelands` remains authorized.

1. Vendors retain the rare, expensive one-in-five Uncommon exception; ordinary
   fixed stock and other rotations remain Common. Restore the decided three of
   four conceptual extra families, with deterministic caster-one-hand selection.
2. Autonomously select/adapt coherent nonweapon icon and worn-armor families
   using the approved gallery direction and appropriate licensed references.
   Cover armor, animal loot, profession materials, food/crops and other poor
   nonweapon placeholders. Preserve good existing icons. Weapon art is unchanged.
   No new gameplay meaning is assigned to trim colors by this graphics task.
3. Render the twelve existing mount appearances once into actual model icons.
   A fitting generic riding/flying symbol is permitted only as a documented
   fallback when a specific model cannot yield a clean usable render.
4. Cave skin filling and natural openings use a purpose-specific functional
   footprint, protecting actual authored build/apron areas, foundations, needed
   routes and POIs. The broad terrain-fitting/blend envelope is not itself a
   cave exclusion. Other protection/claim geometry stays unchanged.
5. Preserve all three Rock Salt endpoints; the two mountain-island sources accept
   appropriate stone/gravel support while retaining their shore/zone constraints.
6. Plain cloth, leather and processed-wood preparation is universal, in Basics,
   without profession XP. Professional fittings/grips remain trade components
   but cannot be required for universal base equipment.
7. Base sword/tool/armor quantities and grid shapes follow pinned VoxeLibre
   exactly, translated to Grudgelands materials. There is no additional high-tier
   regional-gem surcharge on base equipment. A sword is two tier bars plus wood
   stick or same-tier metal rod. Existing other gem uses remain intact.
8. Professional refinement and direct affix application use the owning station
   with clear input/result presentation. One Add Affix operation consumes one
   same-tier profession material and one existing appropriate reagent, appends
   exactly the next legal positional affix, and preserves existing rolls, wear
   and unrelated metadata. Root may author the bounded ingredient mapping and
   non-Minecraft shapes. Keep existing mastery, quality windows and separate
   imbue/temper-kit semantics. Shared Forge, separate Weaponsmith/Armorsmith
   authorization/trainers; Weaponsmith owns fittings and weapon/tool improvement,
   Armorsmith owns armor/shield improvement. Armor refinement uses one tier bar;
   weapon/tool refinement uses one tier fitting. Other owned families retain
   suitable tier materials. No invented new progression system.
9. Native fall damage scales to `ceil(max_hp * native_damage / 20)`, with no
   100% cap. Preserve native zero/safe threshold and landing modifiers. Armor and
   dodge do not apply. Apply the existing Dwarf 20% reduction after scaling,
   then absorb shields. Preserve integer rounding and a damaging hit's minimum.

Earlier accepted Playtest 12 decisions remain binding: exclusive Basics and
profession books with readable ingredient alternatives; seven primaries/two
slots; universal base metal/cloth/leather/caster equipment; +15% refinement and
existing prefix/suffix names and budgets; Cooking grid/furnace familiarity;
licensed plant assets; idle one-node descent limit; dragons walk between rest
spots and use abilities only with a valid hostile target; mount owner-only
first-person hiding, untimed top-right status, nominal one-node automatic land
steps and T1 6.4 nodes/s (+60%).

Riding Trainers exist only in capitals, in outer-district shared-design stables
with the four existing appearances available to that race. Move profession
trainers/public stations into themed outer premises. Two smith trainers share
a forge house. Use existing district/building primitives, stationary non-AI
mount displays, decorative lava and item displays that cannot release items.
Preserve the older CAP wall/gate/battlement fixes and finish MAP-B placement,
second soils, field soil, sea-only coral/kelp and the existing farming loop.

## Resumption procedure and evidence

Read this file, the archived `round10-decisions.md`, current git/worktree state, then each active
lane's brief and terminal/live evidence in `/tmp/grudgelands-r10/`. A mirrored
durable orchestration directory lives at
`/home/jan/projects/grudgelands-orchestration/w9/round10-execution/`.
Read worker source/diffs and fresh process/tool status; never infer completion
from a report, elapsed time or a stale state file. All user decisions above are
accepted; do not ask them again after compaction.

Source planning reports are retained in the adjacent `round10-planning/`
handover directory. They are proposals superseded by the decisions above,
especially the removed base-equipment G2 surcharge. Existing code is evidence,
not authority. Read scoped design sources directly rather than relying on the
truncated automatic AGENTS injection.

## Package graph and status

| ID | Deliverable | Dependencies | Status |
| --- | --- | --- | --- |
| EQUIP | Basics/profession provenance, universal materials/base recipes, leather armor, smith split, refinement/affix workflow, kits and vendor corrections | Accepted decisions above | Running: native Sol, `wp10-r10-equipment` |
| GAME | Mount usability/PvP refusal, percentage falls, idle cliff behavior, dragon rest/target/combat fixes, vendor potion bonus | Accepted decisions above | Running: native Sol, `wp23-r10-gameplay` |
| ART | Nonweapon icon/worn/crop families and twelve mount model icons | Stable semantic IDs; registration handoffs | Prepared; queued for next free Sol slot, `wp29-r10-art` |
| WORLD | Purpose-specific cave boundary/witness and mountain/high-water/Rock Salt corrections | Accepted decisions above | Running: native Astra, `wp40-r10-world` |
| CAP | Old core fixes plus outer service premises, dedicated Riding and protected atmosphere | EQUIP trainer/station contract, GAME mount API, WORLD | Queued |
| MAP-B | Wild plants, secondary soils, field soils, cave-air plants, coral/kelp, FARM integration | CAP; ART crop bindings | Queued |
| CLOSE | Cross-package gates, final docs, sync/push and next-playtest checklist | All packages independently reviewed | Queued |

At most three native workers run beside root. Queue work and review slots as
dependencies permit; world mutation packages run serially. Jan clarified that
the old terminal-Codex launch instructions were for Claude. Use native subagents
for implementation AND fresh independent reviews; no `codex exec` workers.
Review capacity is scheduled within the available native slots.

Jan's additional clarification is now a standing process rule: CLI delegation
is exclusively cross-provider (Claude -> Codex CLI; Codex -> Claude CLI).
Same-provider models always use native subagents, for implementation and review.
For THIS session Claude credits are exhausted: no Claude CLI, Opus or Fable task
may be launched. Do not reinterpret the general cross-provider permission as
current Claude authorization. These rules also live near the top of AGENTS.md
and in both model-policy and cross-CLI process documents.

The native service currently rejects additional threads at its thread limit,
including while the old threads are completed. Reuse the three existing workers
and schedule independent cross-package reviews in contexts that did not author
or work on the candidate being reviewed. Never label an author's self-review
independent, and do not work around the user's native-only instruction with CLI
agents. Root's initial authority transcription received a native Sol read-only
review: CLEAN, zero material findings; no runtime tests for that documentation.

Frozen CAP interface from EQUIP: profession IDs `weaponsmith`, `armorsmith`,
`alchemist`, `tailor`, `leatherworker`, `woodcarver`, `goldsmith`; Cooking remains
secondary. Shared station `forge` / node `grug_jobs:forge`; separate smith NPCs
call `grug_jobs.open_trainer(player, profession_id, position)`. Recipes own exact
authorization/progression; station display may expose both smith owners. No
`blacksmith` compatibility alias. CAP owns the closed socket vocabulary update.

Each lane has its own branch/worktree, immutable brief, file ownership, ports,
evidence and report. Root owns integration and shared BACKLOG/ROADMAP/README
updates. Workers fold their accepted rules into owned design docs before code.
Conflicting shared files are handed off explicitly, not concurrently rewritten.

## Completion contract

All seven audit defects in `playtest12-audit/README.md` must have concrete
correction evidence. Every package supplies requirement -> design -> code ->
test links; universal recipe shapes use independently transcribed reference
oracles, and improvement tests examine the terminal concrete ItemStack.
Actual world consumers, six capital layouts and farming lifecycle are exercised.
Visual proof includes normal inventory size and actual worn-model compatibility,
not only attractive source UV sheets. Correct licenses and unchanged reference
pins are mandatory. No weapon asset changes.

Each nontrivial candidate gets fresh independent Sol review under
`docs/process/wp-workflow.md`. Root verifies findings and gates. The current
autonomous mandate permits root-managed technical fix/review iterations; stop
only for a material unresolved user decision or an actual external blocker.
Do not weaken an acceptance rule to make tests pass.

Plain Lua 5.1 remains mandatory: parser, SETGLOBAL and all five static sweeps;
LuaJIT development/exhaustive runs; one bounded frozen-final PUC/LuaJIT pair per
relevant candidate, replaced only after relevant changes. Seven interpreter
processes machine-wide maximum, independent fleets at idle CPU/I/O priority.
No intermediate PUC suites, full resource census, reference repins, R7 roster
refreeze, saved-world migrations or personal-world engine access. Isolated
lightweight correctness tests may run during GUI testing; defer heavy fleets
and comparative timings until they do not compete with the user's test.

No new Housing, Scout/playable bows, global durability rework or full WP46 is
implied. Preserve their honest open status. Newly authored displays must still
be safe on all actual interaction/drop paths. Final delivery includes clean main,
reviewed commits pushed to the authorized origin, synchronized game files and
one concise fresh-world playtest checklist. GUI acceptance remains user-run.
