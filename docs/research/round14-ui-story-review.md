# Round 14 UI and story independent review

Date: 2026-09-21  
Scope: quest and party UI/HUD, the empty-journal holdings optimization, shared
HUD anchors, and the staged 66-quest starter-story catalog  
Reviewer: GPT-5.6 Sol (independent; no production authorship)  
Implementation author: GPT-5.6 Sol  
Coordinator/integration judge: GPT-6 Astra  
Verdict: **PASS after corrections; 0 open Critical, High, or Medium findings**

## Review boundary

The UI review covered `grug_quests/ui.lua`, `grug_quests/hud.lua`,
`grug_parties/ui.lua`, `grug_parties/hud.lua`, their `dofile` integration,
the two additions to `grug_core/hud_layout.lua`, and the one-line lazy holdings
change in `grug_quests/state.lua`. The story review covered every generated
definition in `tools/r14_story/content.lua` (six cultures, 24 NPCs, 54 linear
quests and 12 optional lessons) against the quest, party, and story design
documents and the actual item, recipe, mob-spawn, zone-palette, camp, and POI
socket authorities.

Production activation of the staged story catalog and the integrated POI boot
and parity gate remain later integration work. Their absence is not a finding
against this staged package.

## Findings and resolution

### High — rendered party row could authorize an action on another member

The original callback resolved a text-list index against a new party view in
`mods/PLAYER/grug_parties/ui.lua`. A membership change between rendering and
submission could therefore make Kick or Make leader target a different valid
member. The correction stores the rendered index-to-name mapping in the sfinv
context and resolves the event only through that mapping. Quest rows received
the equivalent stable index-to-id mapping, preventing stale journal order from
changing selection or tracking intent. The focused fixture now reorders both
collections between render and event and passes.

### Medium — level-8 handoff directed players into a level-11--20 area too early

Quest 06 is available at level 8 and awards 3,000 XP. A player at the exact
level-8 threshold (4,900 XP under `100 * (level - 1)^2`) reaches 7,900 XP,
still below level 10 at 8,100 XP, while quest 07 requires level 10. The original
text directed immediate travel to the village. All six quest-06 descriptions
now keep the objective on the local road approach and explicitly tell the
player to reach level 10 before travelling. Levels and rewards remain intact.

### Medium — consecutive mandatory night-only objectives

Orc quests 05 and 06 originally required Scorpions and Sun-Dried Husks; both
have `clock = "night"` in the actual spawn definitions. Elf quests 06 and 07
similarly used only night-spawned Poachers. Orc quest 06 now also accepts the
daytime Plains Runner, and Elf quest 06 also accepts the daytime Fox. Their
descriptions name both alternatives. The targets are enabled in the respective
start-zone palettes and use compatible surface nodes and level gates.

### Pre-review integration correction — NPC settlement identity

The staged catalog initially used terrain anchor ids such as `anchor_013` as
NPC settlement keys. The socket registry publishes semantic keys such as
`copperfell_village`, so activation would have failed registry validation.
The coordinator corrected all 18 village/outpost/camp values to the actual POI
roster keys before the final review. No aliases or coordinate fallbacks were
added.

## Conformance evidence

- The quest and group forms stay above the standard inventory boundary; all
  dynamic labels, text areas, list rows, item descriptions, NPC titles,
  notices, and player-derived strings use formspec escaping. Server mutations
  still receive the authenticated `PlayerRef` and core revalidates authority.
- The HUD reserves at most nine quest lines (one title plus two objective lines
  for each of three tracked quests). Party rows begin at y=260, use 30-pixel
  spacing, and cover all ten members without entering the quest reservation.
  Party health uses image track/fill elements; offline rows state `Offline`.
- Quest and party HUD writes compare displayed state before `hud_change`.
  Health and item-readiness sampling is throttled to 0.5 seconds. An empty
  journal no longer scans main/bag holdings, and an absent/hidden party removes
  its rows.
- All 66 staged quests have stable ids, faction/race restrictions, positive
  counts, explicit prerequisites, min levels, and XP/copper rewards. Item
  objectives intentionally match id/count only. Main chains are linear;
  optional tool lessons branch after quest 01 and never gate story progress.
- Every mandatory mob id is registered and is available through its stated
  start/home-zone palette and surface policy. Bandit and Bandit Archer are
  supplied by the six authored `bandit_home` camp anchors rather than ABMs.
  `mobs:meat_raw` is a guaranteed boar-variant drop. No objective, item, mob,
  reward, text, or destination requires the Nether.
- `default:axe_wood`, `default:pick_wood`, and `default:pick_stone` are
  registered tools. The two lesson descriptions agree with the starter Basics
  routes: the axe uses three wood-group inputs and two sticks, and the stone
  pick follows the wood-pick step and uses three stone-group inputs and two
  sticks. Traded copies remain valid by design.

## Focused execution

`chrt --idle 0 ionice -c3 luajit tools/r14_ui/ui_kat.lua .` passed with
`r14_ui checks=19 quest_lines=6 party_members=10`. The fixture covers the full
20-quest form, explicit target labels, ready state, authenticated invite,
offline and ten-member party rendering, graphical HP changes, unchanged-packet
suppression, invite reconciliation, stable rendered-row identity across
reordering, and HUD cleanup. `git diff --check` passed for the reviewed files.
No PUC runtime, native engine run, or heavy suite was performed, as required by
the review budget.

Calibration: author Sol; coordinator/root Astra; independent reviewer Sol;
one correction round for reviewer findings; final blocking findings 0; review
elapsed time not recorded.
