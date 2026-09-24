# Round 20 quest framework receipt

**Current gate:** implementation, independent review and technical validation
passed. Delivery: [Round 20 integration receipt](round20-completion.md).
Earlier implementation-milestone notes below describe their original evidence;
the final integration section supersedes their pending-gate wording.

Status: implementation prepared, independent review and final runtime gate pending.
Author: root GPT-6 Astra. Date: 2026-09-24.

## Behavior

Successors appear only after all prerequisites are turned in. Race/faction
visibility stays shared by dialog, floating symbol and atlas. Eligible but
under-level quests still show their required level.

Conversation handoffs have exactly one `talk` objective, count one, at the
registered destination/turn-in NPC. Only an in-reach live-NPC dialog credits
conversation. The player then uses the ordinary Complete button there; marker
queries and journal views do not complete objectives. Existing atomic inventory
preflight, one-time rewards, cap, abandon and same-world persistence are retained.

## Scope and verification

Changed registry, state, NPC dialog, journal and HUD only. Content authoring and
world sockets are separate lanes. Living quest/progression documents record the
approved rule; no content-completion claim is implied.

Lua-5.1 parser, SETGLOBAL review and five static sweeps pass for all changed
production Lua and `tools/r20/quests_micro.lua`. Fixture globals are intentional
engine test doubles. No runtime was executed at this milestone.

The compact final fixture covers simultaneous independent quests, prerequisites
hidden through objective completion, visible level locks, destination credit,
live distance validation, normal turn-in, replay refusal, reconnect persistence,
player isolation and malformed travel definitions. Final interpreter evidence
and independent review calibration will be appended at integration.

GUI acceptance: accept parallel starter tasks; complete but do not turn in one
and verify its successor stays hidden. Turn it in and inspect the follow-up's
level lock. Accept a travel lead, open the named destination NPC, then complete
there without a return trip. Check log/HUD and map marker agree.

## Final integration gate

Independent source reviewer: Astra `r20_input_state_review`, 0 Critical/High, no fixes, elapsed unknown. Actual transaction fixture passed in the final portable pair.

Final evidence and delivery state: [Round 20 receipt](round20-completion.md).
