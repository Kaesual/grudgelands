# Round 18 execution ledger

Date: 2026-09-23. **Approved and active — user Go 2026-09-23.**
Baseline inspected: `7460c49d227a3f66673ad1bf4b7ed429e4b62321` (main).
Contract: [round18-plan.md](round18-plan.md).
User source: [round18-playtest-input.txt](round18-playtest-input.txt).
All decisions closed: [living revision](../design/playtest_quality_revision.md).

Root Astra coordinates; native Sol default, Astra for complex lanes. No CLI
agents or Claude. Integration branch: `wp18-playtest-quality`. Production work starts in isolated lane worktrees.
Round 17 remains delivered; do not rerun its gates.

## Planning evidence

- `r18_world_planning` / Astra: spawn bands/variants, preparation and waiting
  read-only findings. Confirmed Lynx minimum-level clamp and scheduler scan gaps;
  runtime causes remain to be verified. No tests or code edits.
- `r18_engine_planning` / Sol: native minimap constraints, tool capabilities and
  held-light reference analysis. No tests or code edits.
- `r18_combat_planning` / Sol: evade, guard-healing complexity and XP seams.
  No tests or code edits.
- Root: trainer success path, atlas bounds, UI/skill-image composition, tags and
  quest description leakage. Drafted packages A–J and explicit optional deferral.

## User decisions received in this planning turn

1. Ordinary mobs: 15 seconds without incoming damage, no distance-anchor rule;
   bosses and location-bound guards retain bounds.
2. Species require an appropriate local difficulty band; fix affected startquests.
   Per-zone lookalike cleanup concerns wildlife; NPC/guard model reuse is allowed.
3. Native minimap: terrain + own arrow; no other object/player dots. Detailed
   markers stay on the full atlas.

## Planning review

Independent Astra review of the assembled root plan: no blockers or missing
feedback. Incorporated actor-policy classification and one-time error-form
reopening. All three direct user answers are recorded. This planning checkpoint preceded the explicit Go below; the former TODO is
now resolved/deleted.

## Approval and resume

User approved all remaining simplifications: defer guard heals; preserve camp/rare
bounds; 2x pick loose-material timing; global XP cap and single multi-level burst;
main-hand torch only; short pregen investigation. Torch lane MUST first inspect
VoxeLibre and stop before implementation if complexity is disproportionate.

Continue autonomously to reviewed delivery. No new Go needed for approved scope.
Do not rerun Round 17 gates. Native Sol default; Astra complex lanes and art.

## Lane queue

| Lane | Model | State | Ownership |
|---|---|---|---|
| G preparation | Astra | running | starts_preload / preparation helpers |
| D evade | Astra | running | aggro / combat hooks |
| C populations/quests | Sol | running | spawn_policy / species / quest content |
| A inventory/trainer UX | Sol | queued | inventory/jobs/skills UI |
| E XP/level-up | Sol | queued | XP/stats/resource callback |
| B atlas/minimap | Sol | queued | map module/media |
| F waiting/creation | Sol | queued | selection/faction gates |
| H1 icon art | Astra | queued | icon assets/manifest/gallery |
| H2 icons/tags integration | Sol | queued after E/H1 | ability image seam/displays |
| I light preflight | root Astra | deferred before implementation | round18-light-preflight.md |
| J tools | Sol | queued | materials tool/mining capabilities |

Root owns docs and integration. Independent reviews required, final portable
micro-KAT pair only after frozen integrated bytes. Current four total native slots
mean root + three workers; queue as available. No provider CLI.

## Later user steering

Held light is entirely optional/lowest priority; other-player light visibility
may be omitted. Root read the exact newer VoxeLibre algorithm and deferred the
lane before coding because it owns light-bank removal/spread and multiplayer
restoration. [Preflight](round18-light-preflight.md). No approval needed to omit
under the explicit simplicity condition; all other lanes continue.
