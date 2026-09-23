# Round 18 execution ledger

Date: 2026-09-23. **Locally delivered; remote push awaits renewed approval.**
Baseline inspected: `7460c49d227a3f66673ad1bf4b7ed429e4b62321` (main).
Contract: [round18-plan.md](round18-plan.md).
User source: [round18-playtest-input.txt](round18-playtest-input.txt).
All decisions closed: [living revision](../design/playtest_quality_revision.md).

Root Astra coordinates; native Sol default, Astra for complex lanes. No CLI
agents or Claude. Integration branch: `wp18-playtest-quality`. Production work used isolated lane worktrees.
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
| G preparation | r18_preparation / Astra | integrated d4b38594; independent review PASS | starts_preload |
| D evade | r18_evade / Astra | integrated fbca258a; independent review PASS | aggro / combat hooks |
| C populations/quests | r18_populations / Sol | integrated c86621c4; independent review PASS | spawn_policy / species / quest content |
| A inventory/trainer UX | r18_ux / Sol | integrated 0e67a78b; independent review PASS | inventory/jobs/skills UI |
| E XP/level-up | r18_xp / Sol | integrated 486878ab; independent review PASS | XP/stats/resource callback |
| B atlas/minimap | r18_map / Sol | integrated 386f6216; independent review PASS | map module/media |
| F waiting/creation | r18_waiting / Sol | integrated 503948c6; independent review PASS | selection/faction gates |
| H1 icon art | r18_art / Astra | integrated d20c1423; visual independent review PASS | icon assets/manifest/gallery |
| H2 icons/tags integration | r18_icons_tags / Sol | integrated 8681af11; independent review PASS | ability image seam/displays |
| I light preflight | root Astra | deferred before implementation | round18-light-preflight.md |
| J tools | r18_tools / Sol | integrated 27d8bae3; independent review PASS | materials tool/mining capabilities |

Root owns docs and integration. Independent reviews required, final portable
micro-KAT pair only after frozen integrated bytes. Current four total native slots
mean root + three workers; queue as available. No provider CLI.

## Later user steering

Held light is entirely optional/lowest priority; other-player light visibility
may be omitted. Root read the exact newer VoxeLibre algorithm and deferred the
lane before coding because it owns light-bank removal/spread and multiplayer
restoration. [Preflight](round18-light-preflight.md). No approval needed to omit
under the explicit simplicity condition; all other lanes continue.

## Interface / test coordination

G preserves world_preparation_status and listeners unchanged, so F can start.
A exports `grug_inventory.selected_button_style(fieldname, selected)` returning
formspec markup; B owns atlas selection edits and consumes that style. E writes
the resource callback in abilities/init before H2 changes image composition.
Root owns tools/r18_final runner scaffold; final fixture roster contains 11 isolated checks.

G report/evidence: round18-preparation-report.md. Author commit 7b3dec12,
integrated d4b38594. Tiny synthetic test isolates scan wait, not real-world FPS;
native stop/resume used existing bounded two-boot r16 runner once. No ETA run.
Portable final component tools/r18_preparation/fixture.lua returns function(repo).

Root added an 18-point real-authority/final-registration population probe to the
final isolated native gate. The population author fixture uses mocked authority;
it is not, by itself, evidence of actual six-culture level-field behavior.

Initial independent Astra C/D/G review used frozen fbdaac67 in
/tmp/grug-r18-review-world; J and H2 were then integrated before their own review.

C/D/G first review: 0 Critical, 1 High, 2 Medium. Root restores Whitebridge
Boar selection, prevents Evade re-acquisition from restarting its fallback, and
repairs the native population probe to use actual registration inputs. Targeted
fix re-review PASS; all three findings closed. H2 keeps the old neutral empty-slot wield placeholder.

Independent Sol A/B/E/F/H2/J review: 0 Critical / 1 High (cultural shovel
source group mismatch); author J owns the focused correction. Independent Astra
visual review PASS for all 22 icons and six atlas views; doc drift 0 Critical /
0 High / 1 Medium / 2 Low, root corrected stale pursuit/icon/torch references.
Native registration/population gate passes at /tmp/grug-r18-integration-946xbnpq
with real role capture, final ABM hosts, species predicates and actual day/night
clock at 18 points. A prior probe attempt could not set time during init; moved
checks to first server callback and rejected that earlier clock evidence.

## Final checkpoint

All nondeferred lanes and their independent implementation reviews PASS.
C/D/G fixed one High and two Medium findings; A/B/E/F/H2/J fixed one High;
visual/living-doc review fixed one Medium and two Low. All findings are closed.
Final source identity: `4d7adb555494e130feffdde2f83da3d6be4dd05a`.
Cultural source correction: author `8a1a8fca`, root integration `44a1a9a0`.

Final static gate: 55 changed Lua files, plain-5.1 parser, inspected global
writes and five sweeps PASS. One compact final PUC process (0.067794 s) and
one LuaJIT process (0.026646 s) cover 11 isolated fixtures; byte-identical SHA256
`d82a6c14aae29608178f351fc99822a417d0f414082809e34f40414785e8c2e8`.
Final native gate `/tmp/grug-r18-integration-2l0_sxn1` PASS, including actual
engine digging capabilities for eight tool materials. All 2083 production
snapshot files match final checkout; archived in `tools/r18_final/evidence/`.
No full-world generation, ETA campaign or intermediate PUC runtime.

Main merge `92d63113` and local game sync are complete; installed hashes match.
Remaining delivery action: push main. Automatic approval review rejected the
push twice, including a retry quoting the earlier explicit permission; it could
not verify that prior transcript. Root requested renewed confirmation and did
not bypass the rejection. User GUI acceptance stays separate. See
[completion](round18-completion.md) and [playtest](round18-playtest.md).
