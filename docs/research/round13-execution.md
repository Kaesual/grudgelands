# Round 13 execution

User Go: 2026-09-21, with preference for native Astra subagents. No Claude or
same-provider CLI execution. All work is fresh-world development. Approved
contract: [current design](../design/crafting_equipment_revision.md).

## Ownership and state

- STATIONS: native Astra `/root/r13_stations`, branch `r13-stations`, worktree
  `/tmp/grug-r13-stations`. Owns job registry/station runtime, automatic stations,
  Cooking/Alchemy preparation and authored placement seams. Implementing.
- ENCHANTS: native Astra reused `/root/station_rule_audit`, branch `r13-enchants`,
  worktree `/tmp/grug-r13-enchants`. Owns quality/professions/artisans, operation
  catalog and pure metadata-preserving enchant application. Implementing.
- EQUIPMENT and integration: root Astra, branch `r13-integration`. Owns gear,
  material tools, hoes, starter kits, wear, root UI/catalog integration and docs.
  The reserved `/tmp/grug-r13-equipment` worktree is unused. Native thread ceiling
  prevented another Astra spawn; no CLI workaround is permitted.

Agents agree the operation schema before dependent edits. Root owns jobs UI and
Basics route catalog. Each implementation receives independent non-author review
before main integration. Historical branch base is `5d850163`.

## Verification budget

No PUC runtime; retain the user's bounded-test direction. Every changed Lua file
gets plain-5.1 parsing, SETGLOBAL inspection and all five compatibility sweeps,
including files under tools. Relevant deterministic LuaJIT KATs and bounded
disposable native probes (normally 35–45 seconds) cover new transactions and
registration. No broad mapgen/PERF suites, seed fleets or user-world mutation.
Use idle priority for runtime tests and stay under the shared seven-process cap.

Review focuses on shared-viewer races, output authority and persistence,
fixed-tier enchant strength/cost/eligibility, removed registrations/references,
tool separation, exact lifetimes and existing combat semantics. Final integration
must reconcile the Basics catalog and all loaded station/enchant APIs, check the
Protection top-equipment target, update living docs/README/BACKLOG, then sync
from reviewed main and push under standing authorization. GUI playtest is user-owned.

## Next actions

Implement the three scopes; retain exact changed-byte gate evidence and review
receipts here. No completion or GUI acceptance is claimed yet.

## Implementation checkpoint

- ENCHANTS candidate `dc91d65a`: 420 operation/application KATs passed; independently
  reviewed by native Astra STATIONS author. Review found a pre-existing repair
  consumer bug (High in its report; Medium in equipment review): partially worn
  attack-speed gear lost its capability override on repair. Root fixed restoration
  to use only an existing broken-item snapshot; dedicated real service/Money KAT
  covers partial and broken cases. Re-review pending.
- STATIONS candidate `28ef4d85`: 45 native callback/inventory assertions and five
  same-world restart assertions passed. Independent Astra review running; shared
  result-to-input dragging has a confirmed ingredient-consumption finding to fix.
- EQUIPMENT frozen root diff independently reviewed by Astra ENCHANTS author;
  only confirmed finding was the same repair issue. A suspected tool-damage
  finding was withdrawn after checking the existing early native-punch veto.
- User corrected crafted trinkets during implementation: their enchants must also
  be chosen and fixed. Base trinkets keep authored specials, with separate
  prefix/suffix application. ENCHANTS extends to 456 operations. The proposed
  random-trinket station workaround was stopped before any edits.
- User explicitly requested a final native Astra docs/code drift audit after
  integration. This is a required delivery step, additional to code review.
