# Audit 2026-11: finder brief

You are one finder in a read-only audit of the Grudgelands game code (a
standalone Luanti game, Lua 5.1, server-side). Your launch prompt names your
**package id**, its scope and any special focus. Plan:
`docs/planning/review-2026-11-plan.md` in the audit worktree.

## Paths

- **Read code and docs** in `/home/jan/grudgelands` (branch `main`, commit
  `4cb49044e`). Cite paths relative to that root.
- **Write exactly one file:**
  `/home/jan/grudgelands/.claude/worktrees/audit-2026-11/docs/audit-2026-11/raw/<PKG>.md`.
  Change nothing else anywhere: no code, no other docs, no git commands that
  write, no pushes.
- A code package's file list is
  `/home/jan/grudgelands/.claude/worktrees/audit-2026-11/docs/audit-2026-11/packages/<PKG>.txt`
  (lines, path; largest first).

## Hard rules

- **Read-only, static analysis only.** Run no `luajit`, no `lua`, no engine,
  no fixture, no test script, no benchmark, no build. Allowed shell: `rg`,
  `wc`, `ls`, `git log/show/grep/blame` (read-only), `sed -n` for ranges.
  The machine is small (4 slow cores); keep searches targeted.
- **Scope is the code that runs on the game server:** `mods/`, `game.conf`,
  `minetest.conf`, `settingtypes.txt`, `menu/`. `tools/` is not shipped; read
  it only to answer "is this function used only by a fixture?".
- Vendored code (`mods/BASE/*`, `mods/ENTITIES/mobs`) is reviewed only at its
  `GRUG PATCH` sites unless your package says otherwise.
- **Write early, append often.** Create your file as soon as you have the
  first findings (the header plus those findings) and extend it as you go, so
  an interruption loses little. You may be stopped without warning.
- Project rules you must know: `AGENTS.md` ("Lua & Luanti environment",
  "Project conventions", "Performance", "Release mode"), the do-not-write
  list in `docs/technical/luanti-lua.md`, and the review checklist in
  `docs/process/round-workflow.md` §5 (engine callback contracts, Lua rules,
  performance at the 100-player target, protection and exploits, upgrade
  classification, "scope with judgement"). Engine behaviour is read in
  `reference_projects/luanti` (`builtin/`, `src/script/lua_api/`) and cited,
  never guessed; if the submodule is not checked out, mark the claim
  "engine behaviour not checked".
- Never name an existing commercial game as a reference (AGENTS.md "Naming").
- Write in English.

## What to look for

Read your package's code properly (large data tables may be skimmed; say
which files you skimmed). For each file ask:

1. **perf** — work per tick, per player, per mob or per generated chunk that
   can be avoided without changing behaviour: unthrottled globalsteps,
   repeated `get_objects_inside_radius` / `get_connected_players` /
   `get_meta` / `get_properties` / mod-storage / `core.serialize` in hot
   paths, per-tick inventory or HUD writes, table and string allocation in
   inner loops, repeated registry lookups, O(n²) passes, a pass that handles
   every player or zone in one step, uncached recomputation, unbounded
   particles. Say why the path is hot (who calls it, how often).
2. **dup** — the same function or block written more than once (inside the
   package or against another mod you can name), near-copies that drifted.
3. **dead** — unused functions, files never `dofile`d, unreachable branches,
   stale flags, leftovers of removed features, commented-out code, compat
   shims for versions the project no longer supports, fields written and
   never read. Prove "unused" with an `rg` over `mods/` (note when the only
   users are under `tools/`).
4. **simplify** — a small restructuring that removes real complexity or
   cost; module boundaries that are wrong (`mod.conf` depends vs real use,
   reaching into another mod's internals).
5. **bug** / **edge** — real defects and unpleasant edge cases on the happy
   path: nil ObjectRefs after `core.after` or emerge callbacks, a player
   leaving mid-flow, relog resets, unloaded areas, death during an action,
   full inventories, ItemStack copy semantics, off-by-one, wrong callback
   return contracts, `pairs` order where order matters, vector `==`.
6. **persist** — saved state (player meta, mod storage, node meta,
   staticdata): format changes without a declared migration, unknown ids
   that would crash, unbounded growth, lost writes, state not cleared by the
   map reset.
7. **security** — formspec fields, chat commands and web-bridge input
   trusted without validation, missing privilege or protection checks,
   duplication or resource exploits, PvP flag bypasses.
8. **determinism** (mapgen and anything that must agree across processes) —
   `pairs` over string keys in output, `x ^ 2`, `math.random` without the
   seeded source, float accumulation order, time- or load-dependent output.
9. **docs** — where a design or technical document states something the code
   does not do (number, formula, rule, name, file, seam). The docs are the
   spec: say which side looks wrong if you can tell.

**Scope with judgement** (project ruling): report real problems in our code
on realistic paths. Purely theoretical issues (only a foreign mod could
trigger it, impossible states, constructed collisions) go into the
"Backlog notes" section without severity. No speculative findings: every
finding cites the lines that prove it. Fewer, proven findings beat many
guesses; but do not stop early, cover every file in the package.

## Output format (exact; an index script parses the headings)

```markdown
# <PKG> — <package title>

- Finder model: <model id>
- Files read in full: <n> of <n>; skimmed: <list or "none">; not reached: <list or "none">
- Summary: <3-6 sentences: the package's state and the most valuable items>

## Findings

### <PKG>-01 | <Critical|High|Medium|Low> | <perf|dup|dead|simplify|bug|edge|persist|security|determinism|docs|structure> | <short title>

- **Where:** `path/file.lua:120-140` (and further places)
- **What:** <the defect or waste, one to four sentences>
- **Evidence:** <the lines or the rg result that prove it; for perf: who calls it and how often; for dead: the rg that found no user>
- **Proposal:** <the concrete change; say what must stay identical>
- **Effort:** <S|M|L> · **Risk:** <low|medium|high> · **Upgrade class (guess):** <compatible|map reset|migrate|new server|n/a>
- **Measure:** <perf only: "unmeasured" plus the before/after measurement to run on a larger machine: seed, area, probe; otherwise omit>
- **Confidence:** <high|medium|low>

## Backlog notes

- <theoretical or taste-level items, one line each, with file:line>

## Good to know

- <anything a later lane should know: traps, areas that are in good shape>
```

Severity: **Critical** = data loss, crash loop, exploit that breaks the
economy or other players; **High** = a real bug players hit, or a large
measurable-looking server cost; **Medium** = a clear improvement or a bug on
a rarer path; **Low** = small cleanup. Number findings in order of severity.

## Your final reply

At most six lines: the path of your file, findings per severity, the three
most important finding ids with titles, and what you could not cover.
