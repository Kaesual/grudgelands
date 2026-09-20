# Round 11 GAME evidence

Date: 2026-09-20  
Implementation model: native GPT-5.6 Sol  
Base: `45fbc477`  
Design commit: `a898c30c0c962f3da931581d3329f9ed5b582a1d`  
Runtime commits: `45d63092f9ba4b1e33d960b519d9d2e8d5d891fe`, followed by
the pinned-engine yaw-convention correction
`bdaf87204c25a368c60b54b37d0139f2bc651213`

## Scope

- Authored dragons opt out of ordinary distance culling while retaining their
  encounter-owned death and respawn ledger.
- A mounted player's attachment rotation follows look yaw even while stationary;
  the visible mesh remains a non-forced child of that player for native
  first-person hiding.
- T1/T2 capital display mounts walk and pause between two authored spare socket
  endpoints. T3/T4 flying displays remain grounded and loop their stand clip.
  Missing endpoints fail closed to an animated stationary display.

The two endpoint sockets per ground display are a CAP integration dependency:
`<mount socket id>_walk_a` and `_walk_b`, role `idle`, `spawn=false`. GAME does
not derive a lane from building geometry. The focused fixture supplies the same
public `grug_core.settlement_sockets_at` contract. Full integrated geometry and
visual clearance remain an engine/user-playtest gate.

## Static checks

All changed Lua production and fixture files passed the repository's pinned
plain-Lua-5.1 parser at `/home/jan/projects/grudgelands/tools/bin/luac51`.
`SETGLOBAL` inspection found only expected fixture-owned engine globals; the
changed production modules introduced none. The five repository grep sweeps
were run. Existing repository-wide comment/string hits remain, while the three
changed first-party production files had no prohibited construct hit.

Per the user's Round 11 instruction, **no PUC runtime was run**.

## Targeted LuaJIT evidence

Command:

```sh
tools/r11_game/run.sh "$PWD"
```

Output SHA-256:
`66fd035af1c9708ba77ad4a499fbca57ba9941fdbe2710e566738a94154e3f00`

The four focused rows passed:

- real mobs_redo serialization: ordinary far culling remains and authored boss
  save/unload data remains nonterminal;
- real boss definitions and encounter lifecycle: two dragons carry the
  exemption, death/respawn and alive-gate cases remain covered;
- real mount entity/catalog path in compact mode: stationary 60-degree look
  becomes the engine-correct −60-degree relative attachment rotation
  (`content_cao.cpp:978-979` negates free CAO rotation while `:1467-1471`
  applies attachment rotation directly), controller translation stays neutral,
  and the visible child remains attached with `forced_visible=false`;
- real capital-display registration: a ground display advances to, pauses at
  and reverses between authored endpoints; a flying display loops its stand
  range without moving.

## Honest runtime boundary

Standalone fixtures establish server-side state and engine API contracts. They
cannot prove the local client's rendered player/mesh yaw, first-person camera
result, animation quality or stable clearance. The next GUI playtest must view
land and flying mounts while stationary and moving in first and third person,
and from a second client if available; leave and return to a dragon lair after
at least one save/unload cycle; and watch every capital's ground lanes and
grounded flyers through a reload.
