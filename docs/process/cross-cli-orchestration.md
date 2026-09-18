# Cross-CLI orchestration: Claude and Codex driving each other

Decided 2026-09-17. This note records only execution mechanics: how one CLI
launches, controls, monitors and cleans up after the other, in both
directions. Model choice and authorization stay with
[agent-model-policy.md](agent-model-policy.md) (the user routes per session),
the package flow and review checklist stay with
[wp-workflow.md](wp-workflow.md), and read-only Claude reviews launched from
Codex keep their own procedure in
[claude-cli-review.md](claude-cli-review.md). An orchestrator reads this file
when it is about to delegate across CLIs; AGENTS.md carries only the pointer
to this procedure.

Verified against `codex-cli 0.147.0` and the Claude Code CLI on 2026-09-17;
re-check the `--help` output when a version changes.

## 1. Roles and invariants

- **One orchestrator per session**, whichever CLI the user is talking to. The
  other CLI is a **worker**: one OS process per lane, its own worktree, port
  block, output directory and brief. A worker never delegates further and
  never becomes a second orchestrator unless its brief says so explicitly.
- Every worker launch has, before the call: a written brief file, an existing
  worktree on its own branch (`git worktree add <dir> -b <branch> main`), an
  output directory under the orchestrator's scratchpad or a unique `/tmp`
  directory, and a port block that no other lane uses.
- A worker never: pushes, runs `tools/sync_to_luanti.sh`, touches the main
  checkout or another lane's worktree, or reads/writes
  `~/.var/app/org.luanti.luanti/.minetest` (the user's live client). Engine
  runs go through `tools/luanti_headless.sh`, `tools/wp13/run_capital.sh` or
  `run_highcourt.sh` with an explicit port, under `nice -n 19`, and end with
  `pgrep -f '^luanti.bin'` showing only the user's client.
- The worker's final report is a **hypothesis**. The orchestrator reruns the
  static PUC gates and the LuaJIT suites itself and checks the lane's final
  micro-KAT pair (one PUC run, one LuaJIT run, byte-identical digest). It
  regenerates that one pair only when the bytes changed after the lane's run
  or the evidence is missing. This follows the
  [interpreter strategy](../research/luanti-lua.md#interpreter-and-test-strategy).
- Ignored coordinator state (`.claude/`, `.codex/`, `.kilo/`,
  `tools/wp40/results/`) is not project authority for either CLI and must not
  be searched or cited as repository content.

## 2. Claude orchestrating Codex workers

### 2.1 Preflight

```bash
codex --version                       # record in the lane's output dir
grep -E '^(model|model_reasoning_effort)' ~/.codex/config.toml
```

The user config sets `model = "gpt-5.6-sol"` and
`model_reasoning_effort = "high"`; pass `-m`/`-c` explicitly anyway so the
record does not depend on the config file. The repository is a trusted
project in `~/.codex/config.toml`.

**Sandboxes.** Two sandboxes nest here: Claude's command-runner sandbox
around the `codex` process, and Codex's own sandbox around the commands the
worker runs.

- Claude's sandbox: on 2026-09-17 `codex exec` ran successfully inside it
  (API traffic, file writes, git). If a launch fails with a network or stream
  error, rerun the identical command through the runner's unsandboxed
  capability; that is a runner setting, not a Codex flag. Earlier sessions
  needed this every time.
- Codex's sandbox: `-s read-only` for reviews, `-s workspace-write` for
  implementation. **`workspace-write` denies `socket()` outright** (measured:
  `PermissionError: Operation not permitted` on a local UDP bind), so any lane
  that starts a headless Luanti server needs
  `-c sandbox_workspace_write.network_access=true`. `/tmp` is writable under
  `workspace-write`; other directories need `--add-dir` (or, on `resume`,
  which has no `--add-dir`, the config form
  `-c 'sandbox_workspace_write.writable_roots=["<dir>", ...]'`). Two roots
  are needed for every lane that runs in a **git worktree** or boots the
  Flatpak engine, both measured on 2026-09-17: the worktree's git metadata
  lives under the main checkout's `.git`, so `git commit` fails with
  `index.lock: Read-only file system` unless
  both `/home/jan/projects/grudgelands/.git` (object store and refs are
  shared) **and** the lane's own `.git/worktrees/<branch>` directory are
  writable roots (measured: with `.git` alone the worktree directory stays
  read-only and `index.lock` fails; with `.git/worktrees` alone it fails
  too);
  and `flatpak run` fails with `Unable to allocate instance id` unless
  `$XDG_RUNTIME_DIR/.flatpak` is writable. Never use
  `--dangerously-bypass-approvals-and-sandbox` for a lane; the worktree plus
  `network_access=true` is enough.

### 2.2 Implementation lane

```bash
wt=/home/jan/projects/grudgelands/.claude/worktrees/<lane>   # own branch
out=<scratchpad>/<round>/<lane>                               # brief.md lives here
codex exec -C "$wt" -s workspace-write \
  -c sandbox_workspace_write.network_access=true \
  -c 'sandbox_workspace_write.writable_roots=["/run/user/1000/.flatpak","/home/jan/projects/grudgelands/.git","/home/jan/projects/grudgelands/.git/worktrees/<branch>"]' \
  -m gpt-5.6-sol -c model_reasoning_effort=high \
  --json -o "$out/last.md" - \
  < "$out/brief.md" > "$out/events.jsonl" 2> "$out/stderr.log"
```

- The prompt is passed as `-` and read from the brief file. Never launch
  without a prompt argument and without redirected stdin: `codex exec`
  prints "Reading additional input from stdin..." and blocks forever. When a
  prompt is given on the command line, still add `< /dev/null`.
- Do **not** pass `--ephemeral` for an implementation lane: the fix round
  resumes the same session (2.4). The `thread_id` is the first JSONL event
  (`{"type":"thread.started","thread_id":"..."}`); save it next to the brief.
- Launch from the orchestrator's command runner **in background mode** (the
  harness reports the exit) and never with a trailing `&` inside a
  short-lived shell. Never `cd` into the worktree in the orchestrator's own
  shell; use `-C` for Codex and `git -C` for inspection, otherwise removing
  the worktree later leaves the orchestrator with a dead working directory.
- Up to eight lanes may run in parallel (host rule); each lane's Luanti
  server runs under `nice -n 19` on the lane's own port block.

### 2.3 Monitoring and stuck detection

Watch three signals while the process lives:

1. the OS PID (the harness's background task, or `pgrep -f 'codex exec'`),
2. `events.jsonl` growing; each `item.completed` carries the type
   `agent_message`, `command_execution` or `file_change`, so the last few
   lines show what the worker is doing,
3. `stderr.log` for authentication, rate-limit or network failures.

A stream that has not grown for ten minutes while the process uses no CPU is
stuck (seen 2026-08 on a blocked stdin); kill that PID only, confirm no
`luanti.bin --server` of that lane survives, and relaunch. Wall time alone is
never a kill criterion for a lane that is still producing events.

The run is complete when the process has exited with status 0, the JSONL
ends with `{"type":"turn.completed",...}` and `last.md` is non-empty. Then
read `git -C "$wt" log --oneline main..HEAD` and require
`git -C "$wt" status --porcelain` to be empty; the report in `last.md` is
what the worker claims, the commits are what it did.

### 2.4 Review and fix round

Reviews use a fresh Codex context with a review brief that names the lenses
from the wp-workflow checklist and the required verdict (`MERGE`,
`FIX FIRST`, `REJECT`) with findings as severity + `file:line` + defect +
failure scenario + correction. Independence is the separate context and a
brief the implementer never saw; the same model on both sides is allowed when
the user routes it that way.

```bash
codex exec --ephemeral -C "$wt" -s read-only \
  -m gpt-5.6-sol -c model_reasoning_effort=xhigh \
  --json -o "$out/review.md" - \
  < "$out/review-brief.md" > "$out/review.jsonl" 2> "$out/review-stderr.log"
```

`codex exec review --base main` is the quick built-in diff review; it does
not know the project's lenses, so use it only as an extra pass, never as the
independent review of record.

The fix round goes back to the implementer's session so it keeps its
context:

```bash
(cd "$wt" && codex exec resume --all "$thread_id" \
  -c sandbox_mode=workspace-write \
  -c sandbox_workspace_write.network_access=true \
  -c 'sandbox_workspace_write.writable_roots=["/run/user/1000/.flatpak","/home/jan/projects/grudgelands/.git","/home/jan/projects/grudgelands/.git/worktrees/<branch>"]' \
  --json -o "$out/fix.md" - < "$out/fix-brief.md" > "$out/fix.jsonl" 2>> "$out/stderr.log")
```

`resume` accepts neither `-C` nor `-s` (measured 2026-09-17: "unexpected
argument '-C'", exit 2 with an empty stream) and it does **not** restore
the session's working directory: the resumed worker runs, and its
`workspace-write` root is, wherever the orchestrator's shell is. Resumed
from the main checkout, a worktree lane starts editing the main checkout
through relative paths (measured; killed within a minute, no damage). So
the resume is launched from a subshell that `cd`s into the worktree, which
leaves the orchestrator's own shell where it was. The sandbox is set
through `-c sandbox_mode=...`; `--all` disables the cwd filter on the
session list.

`codex exec resume --last` picks the most recent session and is only safe
when one lane runs at a time.

### 2.5 Record and cleanup

The durable package record (research note or commit message fallback) keeps:
date, reviewed SHA, `git status --porcelain` state, Codex CLI version, exact
model and effort, verdict and severity counts, fix-round count, and the
independence statement. Raw JSONL streams are not committed.

After the merge: `git worktree remove <dir>` (clean tree only), delete the
branch after `git branch --contains` shows it in main, remove the lane's
temporary directories, and confirm `pgrep -f '^luanti.bin'` shows only the
user's client.

### 2.6 Round-end engine validation (orchestrator, main checkout)

After the last merge of a round, before the sync (measured 2026-09-17/18):

- the six capitals: `tools/wp13/run_capital.sh <absent output dir> <key> full <seed>`
  with `WP13_CAPITAL_PORT` from a free block, `nice -n 19`, at most three at
  a time (`xargs -P 3`), each about ten minutes; PASS lines plus
  `grep -c ERROR <output>/server.log` = 0. `run_capital.sh` is for capitals
  only: on a start village its probe fails at load (`attempt to index field
  'core'`, the start has no capital core), which is a misuse, not a defect;
- the six starts: `tools/wp13/run_engine.sh <absent output dir> <launcher>`
  is the six-start digest gate (forward/reverse, cold/disk, four identical
  digests). The launcher must forward the caller's scratch
  `LUANTI_USER_PATH` and XDG directories into the Flatpak
  (`flatpak run --command=luanti --filesystem=<scratch root> --env=LUANTI_USER_PATH=... org.luanti.luanti "$@"`);
  a launcher that ignores them would touch the user's personal folder;
- `tools/wp40/quality/final_micro.sh <absent output dir>` on the merge HEAD
  (exit 0, byte-identical PUC/LuaJIT TSVs).

## 3. Codex orchestrating Claude workers

Read-only reviews: follow [claude-cli-review.md](claude-cli-review.md)
unchanged (escalated runner, `--tools Read,Grep,Glob`, deny list, JSONL
`result` record, PID file). Claude's own sandbox can misreport the API as
offline, so Codex launches `claude` through the escalated command runner.

Implementation by a Claude worker follows the same lane discipline as 2.2:

```bash
cd "$wt" || exit 1
session_id="$(uuidgen)"                  # save beside the lane brief
claude --print --model opus --effort high --verbose \
  --output-format stream-json --session-id "$session_id" \
  --permission-mode acceptEdits \
  --allowedTools "Read,Grep,Glob,Edit,Write,Bash(git *),Bash(tools/*),Bash(luajit *),Bash(python3 *)" \
  --add-dir "$out" \
  < "$out/brief.md" > "$out/events.jsonl" 2> "$out/stderr.log"
```

- `acceptEdits` approves file edits; shell commands need the `Bash(...)`
  patterns listed in `--allowedTools`, so the patterns are the lane's
  capability envelope. `--permission-mode bypassPermissions` is allowed only
  inside a disposable worktree and must be stated in the brief.
- Model aliases: `opus`, `sonnet`, `fable` (Fable only with the user's
  explicit authorization for that task, per the model policy).
- The final answer is the JSONL record with `"type":"result"`; a stream
  without it is incomplete and the lane is rerun, not inferred.
  `--json-schema` yields a structured verdict when the brief needs one.
- Fix rounds: the implementation launch above keeps session persistence on
  and uses a caller-generated UUID; resume it with
  `claude --print --resume <uuid> < fix-brief.md`.

### 3.x Questions and blockers from a worker (both directions)

Codex workers have no live channel into the orchestrator. Claude workers
launched exactly as shown above, without `--brief`, likewise have no configured
live channel. Claude Code's `--brief` flag exists, but is untested in this
setup and is neither documented nor enabled here. A worker that hits a
decision the brief reserves for the orchestrator, or a blocker it cannot
resolve inside its scope, **stops and reports** instead of guessing: the final
message ends with a `## Blockers / questions` section listing each item with
what it tried and which option it would pick. The orchestrator answers by
resuming the same thread (2.4 / 3) with a brief that quotes the item and the
ruling. Every brief states this rule explicitly, together with the
non-negotiable invariants of §1, so a worker never "asks" by silently
narrowing the scope. Progress is visible before the end through the JSONL
stream; the orchestrator can kill a lane that goes off scope and resume it
with a correction.

## 4. Control loop (both directions)

1. Brief file written; worktree, branch, ports, output dir created.
2. Launch in background with redirected stdin/stdout/stderr; save PID and
   session/thread id.
3. Monitor PID, stream growth and stderr; kill only the lane's own PID.
4. Collect: exit status, final message, `git log main..HEAD`, clean tree.
5. Orchestrator reruns every gate itself.
6. Independent review in a fresh context; fix round by resuming the
   implementer's session; re-review when the fix is non-trivial.
7. `git merge --no-ff`, gates again on main (all suites, not only the
   lane's), engine validation where digests moved, then sync and the user's
   playtest.
8. Cleanup: worktree, branch, temp dirs, no orphaned servers.

## 5. Measured pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `codex exec` prints "Reading additional input from stdin..." and never starts | stdin left open | `< brief.md` with prompt `-`, or `< /dev/null` |
| `PermissionError: Operation not permitted` on any socket in a Codex lane | `workspace-write` blocks sockets | `-c sandbox_workspace_write.network_access=true` |
| Network or stream error on launch from Claude | command-runner sandbox | rerun through the unsandboxed runner capability |
| Claude reports the API as offline when launched from Codex | Claude sandbox | escalated runner (claude-cli-review.md) |
| Orchestrator shell reports `getcwd` failure after cleanup | it had `cd`-ed into a removed worktree | never `cd` into worktrees; `-C` / `git -C` |
| `resume --last` picks the wrong lane | several lanes ran | resume by saved `thread_id` / `--session-id` |
| `codex exec resume`: "unexpected argument '-C'" | `resume` has no `-C`/`-s` | `--all <thread_id>` plus `-c sandbox_mode=...` (2.4) |
| Resumed worker edits the main checkout | `resume` runs in the orchestrator's cwd | `(cd "$wt" && codex exec resume ...)` (2.4) |
| Orchestrator shell dies with exit 144 when stopping a worker | `pkill -f`/`pgrep -f` pattern also matches the orchestrator's own command line | match with a bracketed character (`"codex exec resum[e] --all <id>"`) or kill by a saved PID |
| Review launched on a worktree with an unfinished merge | orchestrator merged `main` into the lane and did not check for conflicts first | after `git -C "$wt" merge main` require `git -C "$wt" diff --name-only --diff-filter=U` to be empty before any launch |
| Codex stderr: `failed to renew cache TTL: missing field supports_parallel_tool_calls` | models-cache format of this CLI build | harmless noise; the lane keeps producing events |
| Orphaned `luanti.bin --server` after a lane | worker killed mid-run | kill by PID, then `pgrep -f '^luanti.bin'` |
| `git commit` in a worktree: `index.lock: Read-only file system` | worktree metadata lives under the main checkout's `.git` | writable roots `<repo>/.git` AND `<repo>/.git/worktrees/<branch>` (2.1) |
| Headless boot: `Unable to allocate instance id` | Flatpak cannot write `$XDG_RUNTIME_DIR/.flatpak` | writable root `$XDG_RUNTIME_DIR/.flatpak` (2.1) |
| Fresh worktree has no `tools/bin/lua51` or `tools/bin/luac51` | `tools/bin/` is gitignored | immediately after `git worktree add`, copy both binaries from the main checkout into the lane's `tools/bin/` |
| `resume` with an empty id reports "direct app-server input is not allowed for multi-agent v2 sub-agents" and does nothing | the first JSONL record's `thread_id` was not saved | extract and persist `thread_id` immediately after launch; never construct a resume before it is non-empty |
| WP40 KATs or `quality_geometry_micro_kat.lua` fail to locate repository files | their repository-root argument was relative | orchestrator gate scripts pass the absolute root `$(pwd -P)`, never `.` |
| WP40 final micro fails after an unrelated mod-load change | its load-time `core.*` registration fixture is stale | run the final LuaJIT/PUC micro pair on every merge HEAD; any lane that touches mod load paths reruns and refreshes the fixture in scope |
| Shore and start-band KATs cannot run under PUC 5.1 in a read-only review sandbox | `tools/wp40/r6/common.lua:29` falls back to SHA files under `/tmp`, which that sandbox cannot write | reviewers verify the recorded byte-identical PUC/LuaJIT pair instead; an injectable in-memory hasher is a possible later improvement, not an implemented path |
| Historical R7 static runner flags `core::Transform` in `mods/PLAYER/grug_visuals/wield_geometry.lua` | its C++-token regex also scans Lua comments | known false positive: leave the production comment unchanged and read this hit manually until the historical runner's pattern is narrowed |
| Orchestrator shell dies with exit 144 while `tools/wp13/run_engine.sh` runs, although its log ends with `WP13 engine PASS` | the gate's EXIT trap kills every process whose command line names its output directory, and the orchestrator's own `bash -c` wrapper named that path | start the gate from a script file or a command line that does not repeat the output path; on exit 144 read the gate's log and `digests.txt` before treating the run as failed |
| `run_capital.sh` on a start village: `grug_wp13_capital_probe/init.lua: attempt to index field 'core'` | the capital probe expects a capital core blueprint; starts have none | starts are validated by `tools/wp13/run_engine.sh` (2.6), capitals by `run_capital.sh` |
| `git worktree remove` refuses: "Arbeitsverzeichnisse, die Submodule enthalten, können nicht ... entfernt werden" | the worktree carries the reference_projects submodule directories | `git worktree remove --force --force <dir>` after confirming `git -C <dir> status --porcelain` is empty and the branch is merged |
| Every command in a Codex lane fails before it runs: `bwrap: Can't write data to file /tmp/<dir>: Bad file descriptor`; the worker reports a broken environment and stops | a `sandbox_workspace_write.writable_roots` entry names a directory that does not exist yet | create every writable root (`mkdir -p`) before the launch; the sandbox does not create them (measured 2026-09-18, five lanes lost their first run) |
| A lane's final commit adds its report (`last.md`) to the repository root | the worker wrote its `-o` report a second time into the worktree and committed it | the brief says explicitly that reports go to the `-o` path only; on review, remove the file from the branch (measured 2026-09-18: two of three implementation lanes did this) |
| A worker reports "independent review … verdict MERGE" for its own lane | the worker launched a Codex review and fix round itself | the brief says explicitly "never launch Codex, Claude or any agent yourself; the orchestrator reviews"; the orchestrator's review still runs and is the review of record (measured 2026-09-18) |
| Orchestrator gate run on one worktree fails its headless boot with `Failed to bind socket` while another gate run is alive | two `gates.sh` runs shared one `PORT` | give every concurrent gate run its own port; rerun only the boot on a free port to confirm |
