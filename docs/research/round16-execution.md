# Round 16 execution ledger

User Go: 2026-09-22. Root: native Astra. Contract: [approved plan](round16-plan.md).
Baseline main: `3e714e7e5b14375306748a7acd55507283298fe3`.
Both final simplifications are approved and folded into the plan; resolved TODO
deleted. Claude prohibited this session; same-provider CLI prohibited.

## Scope and routing

| Lane | Owner | Worktree | State |
| --- | --- | --- | --- |
| A Mount lifecycle | Astra | `/tmp/grug-r16-mounts` | implemented `9f178c27`; review pending |
| B Combat audit/control/Ibex | Astra | `/tmp/grug-r16-combat` | targeted JIT fixtures pass; finalizing |
| G Surface preparation | Astra | `/tmp/grug-r16-surface` | bounded native stop/resume gate |
| C Atlas | root Astra | root branch | `bddd1edf`; independent review pending |
| D Quest progression/kill XP + XP UI/admin | Sol | `/tmp/grug-r16-progression` | implementing |
| E UI/food | root Astra | root branch | `1b2f0458`; independent review pending |
| F Atmosphere/audio/density | Sol | `/tmp/grug-r16-atmosphere` | prepared; awaiting worker slot |

Use at most three worker agents concurrently with root. Each lane owns its
files and updates its design sections before implementation. Root owns this
ledger, overview docs, shared-file arbitration and integration. Agents do not
edit root's checkout or overview status files. Independent review comes from a
different author; reviewers inspect evidence rather than repeat final tests.

## Important boundaries

- Taunt/aggro audit first; no numerical retune on an unconfirmed report.
- G uses tile/inner-chunk progress, no global height prepass or selected list.
  Current estimate behavior is accepted. Optional final ETA sample exactly
  once, 60–120 seconds, then normal shutdown. No exact savings requirement.
- B uses a few ice particle sprites, no fitted models/decorative entities.
- No migrations, no icon collision handling, no animated Charge, no PERF fleet.
- LuaJIT development plus parser/SETGLOBAL/five sweeps. Root coordinates one
  compact final PUC/LuaJIT pair; agents must not run intermediate PUC runtime.
- GUI is user-run. Unanticipated major complexity pauses its lane for discussion.

## Integration and evidence

Root implements C/E alongside the first worker wave. C real-form fixture and E
24-route food/HUD fixture pass LuaJIT and static gates. A has twelve lifecycle
cases; review pending. No GUI acceptance is claimed. Final PUC/JIT pair pending.
Per-lane handoff includes commit hash, owned files, source/fixture hashes,
LuaJIT evidence, remaining risks and callable compact final fixture entry point.
Root records reviews, final gates, merge, sync and push here before completion.
