# Round 20 execution state

User Go: 2026-09-24. Root: GPT-6 Astra. Status: **active**.
Contracts: [round plan](round20-pois-quests-fixes.md),
[input contract](round20-input-contract-proposal.md).

## Resume instructions

Continue autonomously to a reviewed, synchronized next-playtest candidate.
Escalate unexpected material complexity to the user and pause only that lane.
No remote push is authorized by this Go. Native agents only; no Claude credits.
Four agent slots total including root; queue work without CLI workarounds.

Baseline main: `e346ec482c34d1a494ebcdf32be61eb152653e83`.
Integration branch: `wp20-round20`, primary checkout.
All pre-Go documentation changes belong to this round and must be preserved.
Planning was independently reviewed by Sol; game implementation still needs
fresh independent reviews. Do not confuse design approval with game validation.

## Lane ledger

| Lane | Model | State | Owned scope / workspace |
|---|---|---|---|
| P1/Q2 creative cards and NPC/content contract | Astra | integrated `e32e9d2d` | `/root/r20_creative`, `/tmp/grug-r20-creative`; cards/NPC contract |
| F1/F2 suffocation, minimap, party level, focus | Astra (thread availability) | integrated `0cfb377d`; root source review clean, runtime pending | `/root/poi_quest_round_preflight`, `/tmp/grug-r20-ux`; `c785d2b3` |
| F3 equipment, enchants, durability and broken art | Astra | integrated `f327f8e7`; root source review clean, boundary fixture pending | `/root/r20_input_state_review`, `/tmp/grug-r20-gear`; cosmetic slot interface |
| F4 mobs, recovery, stacking, stun | root Astra | implemented `d19a3882`; independent review pending | stun stars/crab; no speculative aggro/crowd-AI change |
| F5 contextual input and heal targeting | Astra | implementation active | `/root/poi_quest_round_preflight`, same UX worktree; F3 only changes slot_source cosmetic getters |
| Q1 quest framework | root Astra | integrated `dc3cc60f`; independent Astra source review clean, runtime pending | integration checkout; registry/state/dialog/UI/HUD and compact fixture |
| P2/P3 authored POI implementation | Astra | active | `/root/r20_creative`, creative worktree; geometry, sockets, start_npcs only |
| Q3 quest content | Astra (thread availability) | active | `/root/r20_input_state_review`, gear worktree; 102 rewrites + 138 new entries |
| Independent lane reviews | fresh Sol/Astra | queued | read-only before integration |
| Final integration/docs/gates | root Astra | active | design reconciliation, branch ledger, bounded final validation |

Agents must report owned files, commits/diffs, exact checks, unresolved issues
and concise receipts. They do not sync or merge main. Preserve unrelated work.

## Test budget

Mandatory cheap Lua-5.1 parser/SETGLOBAL/five static sweeps on changed Lua.
Build relevant compact fixtures; consolidate executable tests at round end.
Intermediate JIT runtime only for a concrete defect reproduction, not habit.
One compact final PUC/JIT digest pair; JIT-only representative real POI
manifest/planner construction and catalog checks. No full world, seed fleet,
old exhaustive suites or broad PERF. At most one isolated headless smoke
if needed, with a five-minute ceiling. GUI testing belongs to the user.

## Scope reminders

- All 70 art acceptance slots, not 70 new towns; retain existing actors/content.
- Approximately 240 quests is editorial budget, no filler quota. Bundle starter
  tasks, hidden unfinished prerequisites, visible level locks, destination talk
  handoffs, separate cooks. No player-kill quests/Nether/Housing/new PvP rules.
- Input: dynamic held LMB combat/hand-dig, narrow initial click arbitration,
  literal melee Strike fallback, one drop attempt per press, Blink/Sprint once,
  Loose LMB Strike/RMB draw; no remembered ally heal fallback.
- Common class-readable tooltips; no viewer-specific shared stack recoloring.
- Equipment cosmetic source includes broken items; combat eligibility stays off.

## Current evidence / next action

Approved planning baseline committed as `32c03a4d`. Implementation branches
`wp20-creative`, `wp20-ux` and `wp20-gear` start there. All worktrees are under
`/tmp/grug-r20-*`; shared references and parser binaries remain read-only in
the primary checkout. No runtime tests executed yet.

New native Sol thread creation and revival both hit the session thread limit.
Reuse the three existing Astra threads; no provider CLI workaround. Preserve
independent review by assigning each lane to a non-authoring agent later.

Frozen seams: new regional `r20_anchor_NNN` settlement / `quest_host` socket /
`r20_anchor_NNN_host` NPC; talk objective `{type="talk", npc=destination,
count=1}` with `turnin_npc=destination`. Existing capital quest shells become
envoys rather than duplicate NPCs. Creative cards provide exact new cook sockets.
F3 exposes cosmetic equipment separately from combat getters; F5 leaves
`slot_source` untouched until integration. Q1 independent source review by
`r20_input_state_review`: no confirmed findings. Root independently source-reviewed
F1/F2 and F3: no confirmed production findings; F3 fixture extension requested
for actual equipment callbacks and wear/repair boundaries. No runtime executed.

Latest accepted input limits: native GUI opening can look like release; very
short air clicks may be missed between control reports. Both explicitly accepted
by the user; see the input contract receipt. Food: one serving after 1.5 s RMB,
sound gain 0.5. F4 audit found no reproducible early recovery/collision defect;
its receipt distinguishes observations from fixed behavior.

Next: finish F5, POIs and Q3; review each independently, including root F4.
Root is reconciling living design docs. Freeze final bytes, execute compact
portable pair plus real POI manifest/planner samples, inspect visual artifacts,
close any findings, then merge main and sync. No remote push.
