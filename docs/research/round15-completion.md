# Round 15 completion record

Status: technical gates and independent reviews PASS; merge/sync/push pending.
Date: 2026-09-21. Current game rules remain in `docs/design/`.

## Scope

- All 18 existing regional villages, outposts and camps have distinct building
  arrangements, silhouettes, working interiors and cultural details. Existing
  fitted cores, anchors, roads, functional roots and protection rules remain.
  Each village adds one local quest giver. No new world anchors or waypoints.
- 36 optional local quests supplement the 66 starter quests: 102 definitions,
  30 giver identities, 17 quests per race. The additions contain 12 item-hand-in
  and 24 kill objectives. Each race's six local quests award 4,700 fixed XP
  before racial bonuses. Existing main-chain rewards remain unchanged after
  checking their already generous later rewards against level thresholds and
  overlapping combat objectives. Nether content remains expansion one.
- Quest symbols are five times larger with the upper extent held fixed. Quest
  tracking is middle-right, party names/HP middle-left. Text widths and party
  rows account for independent GUI-font and HUD-geometry scaling. A thin gold
  360×6 XP bar replaces the numeric XP line; a small level label and `/xp`
  preserve level/exact-value access.
- The atlas shows gold self and cyan online-party directional markers, plus
  quest-giver status markers and name/status tooltips. Givers in the same authored settlement share one
  highest-priority marker; every relevant giver remains in its tooltip. Stable click identities survive refreshes. Live updates
  run only while Map is open, at most twice per second and only resend changed
  forms. Closing Map resets inventory to Character; clicking Map resumes it.
  No remote quest actions, fog of war, generated-terrain rendering or travel.
- The repeated cross-player Cooking report received an additional Astra source
  investigation of real NPC, formspec/peer and PlayerMeta paths. There is no
  confirmed cause or production fix. The available local log contains no
  instrumented trainer interactions; the focused two-client reproduction remains
  in the playtest checklist. A passing mock is not treated as disproof.

WP9's broader progression/PvP story and WP13's remaining POI roster remain
open. This increment does not change the 27-of-53 shipped identity count.

## Independent review and calibration

| Scope | Implementer | Independent reviewer | Initial C/H/M | Correction rounds | Final status |
| --- | --- | --- | --- | --- | --- |
| POI composition | Astra | Sol | 0/0/2 follow-up | 1 landing correction; two earlier visual passes | Clean |
| Local quest content | Sol | Astra | 0/0/0 | 0 after freeze | Clean |
| HUD presentation | Astra | separate Astra | 0/0/1 | 1 | Clean |
| Atlas markers/lifecycle | root Astra | Astra providers; Sol lifecycle | 0/0/1 | 1 (plus Low coverage wording) | Clean |

Observed elapsed review times were not recorded. No Claude or same-provider CLI
agents were used. Root never independently approved its own implementation.
The bounded [documentation drift review](round15-docs-review.md) closed three
Low wording findings in one correction pass; it does not certify its author's
HUD code. Reports: [POIs](round15-poi-review.md), [quests](round15-quests-review.md),
[HUD](round15-hud-review.md), [atlas](round15-map-review.md), and
[Cooking investigation](round15-cooking-investigation.md).

## Verification and limits

All 17 changed/new Lua files passed the plain-5.1 parser. Production global
writes are the owning `grug_map` and `grug_xp` tables; tool writes are declared
engine stubs. All five source sweeps have no hits. One compact final PUC process
(0.522 s) and the same LuaJIT fixture process (0.164 s) produced identical output:
SHA-256 `8de2aaf7c4080ad0d423f36177318a338c66cae5f72f8992cbc3bc14ab509f46`.
Four bounded fixtures cover atlas, quest catalog, POI geometry and HUD consumers.
Evidence and final Lua hashes are in `tools/r15_final/evidence/`.

The [isolated native gate](round15-integration.md) passed with exactly three
POI mapchunks, actual manifest/planner consumers, 12,670 checked authored cells,
preserved functional roots and five live NPCs, including both village givers.
All 2,045 production snapshot files match the final root payload. No full world,
historical population suite or user world was used. Final Lua bytes remained
unchanged throughout both gates; reviewers inspected rather than duplicating
these executions.

All 18 compositions have source geometry/registered-node checks and rendered
views. Walkability evidence covers internal-core approaches and entrances;
unchanged external road spurs/collars, final terrain blending and in-client
climbing remain GUI checks. Layout figures are schematics rather than engine
screenshots. Marker readability and live formspec pointer behavior also need
the user's client test. Existing central combat labels can overlap at extreme
unequal GUI/HUD scales; that separate legacy limitation is documented in the
HUD report and was not claimed fixed by the party/quest presentation work.

Next user action after delivery: [fresh-world playtest](round15-playtest.md).
