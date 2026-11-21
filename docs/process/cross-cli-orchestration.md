# Astra lanes through the Codex CLI

Decided 2026-09-17, cut to the one direction in use on 2026-11-16: a Claude
coordinator runs a GPT-6.2 Astra lane as a Codex CLI worker. Model choice:
[agent model policy](agent-model-policy.md); round flow, gates and the review
checklist: [round workflow](round-workflow.md). The Codex-to-Claude direction
(not used since Round 24) and the Claude CLI review procedure are archived:
[full cross-CLI note](../archive/process/cross-cli-orchestration-2026-09.md),
[Claude CLI review](../archive/process/claude-cli-review.md).

Verified with `codex-cli` 0.147.0 (2026-09-17), 0.155.1 and 0.159.3
(2026-10-01) and 0.171.0 (2026-11-21); re-check `codex --help` when the
version changes.

## 1. Invariants

- **Cross-provider only:** Claude runs Codex as a CLI worker; Claude's own
  models run as native subagents, never through the Claude CLI.
- **One OS process per lane:** its own worktree and branch (from
  `round<NN>`, [round workflow](round-workflow.md#2-a-round-step-by-step)
  step 3), its brief file and output folder
  `~/projects/grudgelands-orchestration/r<NN>/astra-<lane>/`. The worker
  never delegates further: reasoning effort `xhigh`, **never `ultra`** (it
  means automatic task delegation).
- **The worker never** pushes, merges, runs `tools/sync_to_luanti.sh`,
  touches the main checkout, another lane or the user's Luanti folder, or
  launches Codex, Claude or any agent (measured 2026-09-18: a worker ran its
  own review and reported "MERGE"). Engine runs only through
  `tools/luanti_headless.sh` and the shared queue. The brief says all of this,
  plus the launch sentence and that the report goes only to the `-o` path.
- **The report is a hypothesis.** The coordinator reads the commits
  (`git -C "$wt" log --oneline round<NN>..HEAD`) and requires
  `git -C "$wt" status --porcelain` to be empty; the independent review is a
  native Opus reviewer with the round's review brief, which reads the lane's
  receipts and does not rerun its long runs.
- Ignored coordinator state (`.claude/`, `.codex/`, `.kilo/`,
  `tools/wp40/results/`) is not project authority.

## 2. Preflight and sandboxes

```bash
codex --version                       # >= 0.171: gpt-6.2-astra is refused by 0.160 ("not supported")
grep -E '^(model|model_reasoning_effort)' ~/.codex/config.toml
```

The slug is `gpt-6.2-astra` (from `~/.codex/models_cache.json`); pass `-m` and
`-c model_reasoning_effort=xhigh` explicitly anyway. Two sandboxes nest:

- **Claude's command runner** around `codex`: if a launch fails with a
  network or stream error, rerun the identical command through the runner's
  unsandboxed capability (a runner setting, not a Codex flag).
- **Codex's sandbox:** `-s workspace-write` for a lane. It needs as writable
  roots both git directories of the worktree: the shared `.git` **and** the
  lane's own metadata folder, which git names after the worktree folder's
  basename, not the branch. Query both, never build or `mkdir` them:
  `git -C "$wt" rev-parse --path-format=absolute --git-common-dir --git-dir`.
  A lane that boots a headless server also needs
  `-c sandbox_workspace_write.network_access=true` (`workspace-write` denies
  every socket) and `$XDG_RUNTIME_DIR/.flatpak` as a writable root. Every
  other writable root must exist before the launch (`mkdir -p`). Never
  `--dangerously-bypass-approvals-and-sandbox`.

## 3. Launch

[templates/run_astra.sh](templates/run_astra.sh) is the practised launcher
(`run_astra.sh <NN> <lane>`, brief at `r<NN>/astra-<lane>/brief.md`). Its
core:

```bash
git_common="$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir)"
git_dir="$(git -C "$wt" rev-parse --path-format=absolute --git-dir)"
roots="[\"$git_common\",\"$git_dir\"]"   # plus the Flatpak root for a booting lane
codex exec -C "$wt" -s workspace-write \
  -c "sandbox_workspace_write.writable_roots=$roots" \
  -m gpt-6.2-astra -c model_reasoning_effort=xhigh \
  --json -o "$out/last.md" - \
  < "$out/brief.md" > "$out/events.jsonl" 2> "$out/stderr.log"
```

- The prompt is `-`, read from the brief file. Without a prompt and with
  stdin open, `codex exec` waits forever ("Reading additional input from
  stdin..."); with a prompt on the command line add `< /dev/null`.
- No `--ephemeral`: the fix round resumes the session. Save the `thread_id`
  from the first JSONL event (`thread.started`) beside the brief at once.
- Launch in the runner's background mode, never with a trailing `&` in a
  short-lived shell. **Never `cd` into the worktree in the coordinator's own
  shell:** Claude Code moves its working directory there at once, later
  relative commands run in the lane, and removing the worktree leaves a dead
  directory. Use `-C`, `git -C` or a subshell `( cd "$wt" && … )`; if it
  happened, `cd /home/jan/projects/grudgelands` at once and check `pwd`.

## 4. Monitoring and completion

Watch the PID, the growth of `events.jsonl` (each `item.completed` carries
`agent_message`, `command_execution` or `file_change`) and `stderr.log`
(authentication, rate limit, network). A stream that has not grown for ten
minutes while the process uses no CPU is stuck: kill that PID only, confirm
no `luanti.bin --server` of the lane survives, relaunch. Wall time alone is
never a kill criterion. The run is complete when the process exited 0, the
stream ends with `turn.completed` and `last.md` is non-empty. A run that ends
with `turn.failed: Selected model is at capacity` produced no report: relaunch
it.

## 5. Fix round

The fix round resumes the implementer's session so it keeps its context.
`resume` accepts neither `-C` nor `-s` and runs wherever the shell is, so it
starts from a subshell in the worktree (resumed from the main checkout it
edits the main checkout):

```bash
(cd "$wt" && codex exec resume --all "$thread_id" \
  -c sandbox_mode=workspace-write \
  -c "sandbox_workspace_write.writable_roots=$roots" \
  --json -o "$out/fix.md" - < "$out/fix-brief.md" > "$out/fix.jsonl" 2>> "$out/stderr.log")
```

Recompute `$roots` before the resume (shell variables do not survive between
runner calls). `resume --last` is only safe when one lane runs.

## 6. Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `codex exec` prints "Reading additional input from stdin..." and never starts | stdin left open | `< brief.md` with prompt `-`, or `< /dev/null` |
| `PermissionError: Operation not permitted` on any socket | `workspace-write` blocks sockets | `-c sandbox_workspace_write.network_access=true` |
| Network or stream error on launch | Claude's command-runner sandbox | rerun through the unsandboxed runner capability |
| `git commit` in the lane: `index.lock: Read-only file system` | the worktree's git metadata lives under the main checkout's `.git` | both git roots from `rev-parse` (§2) |
| `bwrap: Can't write data to file …: Bad file descriptor`, every command fails | a writable root does not exist (a git root built by hand as `.git/worktrees/<branch>`, or a missing scratch folder) | git roots from `rev-parse`; `mkdir -p` every other root before the launch |
| Headless boot: `Unable to allocate instance id` | Flatpak cannot write `$XDG_RUNTIME_DIR/.flatpak` | add it as a writable root |
| Relative commands suddenly run in a lane; `getcwd` fails after cleanup | the coordinator `cd`-ed into a worktree | never `cd` there (§3) |
| `codex exec resume`: "unexpected argument '-C'"; or the resumed worker edits the main checkout | `resume` has no `-C`/`-s` and uses the shell's directory | `( cd "$wt" && codex exec resume --all <id> -c sandbox_mode=… )` |
| `resume` with an empty id: "direct app-server input is not allowed for multi-agent v2 sub-agents" | the `thread_id` was not saved | save it right after the launch |
| `resume --last` picks the wrong lane | several lanes ran | resume by the saved `thread_id` |
| The coordinator's shell dies with exit 144 when stopping a worker | a `pkill -f`/`pgrep -f` pattern matched its own command line | bracket a character (`"codex exec resum[e]"`) or kill by saved PID |
| stderr: `failed to renew cache TTL: missing field supports_parallel_tool_calls` | models-cache format of this CLI build | harmless noise |
| Orphaned `luanti.bin --server` after a lane | worker killed mid-run | kill by PID, then `pgrep -af '^luanti.bin'` |
| A fresh worktree has no `tools/bin/lua51`/`luac51` | `tools/bin/` is gitignored | copy them from the main checkout after `git worktree add` |
| The lane's last commit adds its report to the repository root | the worker wrote its `-o` report a second time | the brief says reports go to the `-o` path only; remove the file before the merge |
| Review started on a lane with an unfinished merge | the round branch was merged into the lane and a conflict stayed | after `git -C "$wt" merge round<NN>` require `git -C "$wt" diff --name-only --diff-filter=U` to be empty |
| `git worktree remove` refuses because the worktree holds submodule directories | the read-only reference submodules under `reference_projects/` ([reference projects](../reference_projects.md)) | `git worktree remove --force --force <dir>` after `git -C <dir> status --porcelain` is empty and the branch is merged |
