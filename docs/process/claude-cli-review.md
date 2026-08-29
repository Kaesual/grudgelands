# Claude CLI review procedure

Decided 2026-08-26.

This note records the repository-specific execution procedure for Claude CLI
reviews. Model selection, authorization, and the independent-review gate remain
governed solely by [agent-model-policy.md](agent-model-policy.md).

## Authorization

- Before launch, apply the authorization and routing rules in
  [agent-model-policy.md](agent-model-policy.md); this execution note does not
  grant or restate model authorization.
- A review prompt may transmit the relevant Grudgelands repository content to
  Anthropic. Keep the transmitted scope bounded to the reviewed package.

## Invocation

Claude CLI must run outside the filesystem/network sandbox; sandboxed calls can
incorrectly report that the API is offline. Launch it through the command
runner's escalated/unsandboxed capability (currently exposed by the runner
schema as `sandbox_permissions="require_escalated"`); this is a runner setting,
not a Claude flag. Use the model and effort selected by the model policy.

Create a unique `/tmp` directory and a non-empty `prompt.txt` there before
launch. For an Opus xhigh review, run the following shell block through the
escalated command runner. The standard read-only profile deliberately excludes
`Bash`; `--permission-mode dontAsk` therefore cannot turn a shell command into
a repository write.

The prompt must also state that ignored coordinator/tool state — including
`/.claude/`, `/.kilo/` and `/tools/wp40/results/` — is not project authority
and must not be searched or cited as repository content.

```bash
repo_dir=/absolute/path/to/reviewed/worktree
review_dir=/tmp/grudgelands-claude-review.UNIQUE
claude_denied_tools=Bash,Write,Edit,MultiEdit,NotebookEdit,Task
claude_denied_tools=$claude_denied_tools,WebFetch,WebSearch,SlashCommand
claude_denied_tools=$claude_denied_tools,BashOutput,KillShell
cd "$repo_dir" || exit 1
test -s "$review_dir/prompt.txt" || exit 1

claude --version > "$review_dir/cli-version.txt" || exit 1
claude --help > "$review_dir/cli-help.txt" || exit 1

(
  claude --print --model opus --effort xhigh --verbose \
    --output-format stream-json --include-partial-messages \
    --permission-mode dontAsk --no-session-persistence \
    --tools Read,Grep,Glob \
    --allowedTools Read,Grep,Glob \
    --disallowedTools "$claude_denied_tools" \
    --strict-mcp-config --disable-slash-commands --no-chrome \
    < "$review_dir/prompt.txt" \
    > "$review_dir/review.jsonl" \
    2> "$review_dir/stderr.log" &
  claude_pid=$!
  printf '%s\n' "$claude_pid" > "$review_dir/claude.pid"
  wait "$claude_pid"
  review_status=$?
  printf '%s\n' "$review_status" > "$review_dir/exit.status"
  exit "$review_status"
)
```

Set `repo_dir` to the exact reviewed checkout or worktree. Never substitute a
different main checkout merely because it shares the repository object store;
the worktree bytes and uncommitted reviewed state are the review target.

`--tools` bounds the available built-in tool set; `--allowedTools` only
pre-approves listed tools and is not itself a restriction. The deny list is a
second barrier against repository writes, delegation, and network or shell
exfiltration. `--strict-mcp-config` prevents user or project MCP configuration
from adding another tool path.

Use print mode (`-p`), never Plan mode. Plan mode may attempt to persist a plan
even for a read-only review. The prompt must state that the repository is
read-only. Under the standard profile no diagnostic file can be written. If a
scoped `Bash(...)` diagnostic profile is used, the prompt additionally limits
all disposable diagnostic writes to that review's unique `/tmp` directory.

If a review genuinely needs shell diagnostics, do not add bare `Bash`. Define
the smallest command-specific read-only `Bash(...)` patterns in that review's
brief, reject shell control operators and repository-targeted redirections,
and allow diagnostic output only below its unique `/tmp` directory. Prefer
running immutable checks separately and giving their outputs and hashes to the
read-only reviewer.

## Non-blocking monitoring

The external CLI process is the exception to the synchronous in-session
subagent rule in [wp-workflow.md](wp-workflow.md): it has its own OS process,
JSONL stream, and explicit result parsing, so it must not block the coordinator
context. In-session review and research subagents remain synchronous.

Do not double-background Claude from a short-lived command-runner shell. The
command-runner call itself must retain and expose the live foreground session;
monitor that session until Claude exits. A JSONL stream without both a final
`type="result"` record and an integer `exit.status` is incomplete and cannot be
recovered as a review verdict; rerun the review instead of inferring one from
partial output.

Before any long acceptance runner that will eventually promote a file into a
repository or sibling worktree, use the **same command-runner sandbox and
permission profile as the real run** to create, close and remove a real
`mktemp` file in the exact target directory. This probe must happen before the
long LuaJIT work and before a final-only PUC process. Writability of the main
repository, `/tmp` or another worktree does not prove that the target worktree
is writable; a failed probe stops the run immediately.

Retain the OS process id (PID) written to `claude.pid`. It is the Claude
process PID, not a persisted Claude conversation or command-runner session id;
`--no-session-persistence` intentionally prevents the former. Monitor all
three signals:

1. poll the OS PID and require the integer exit status in `exit.status` after
   the process ends;
2. verify that the JSONL file continues to grow and inspect recent tool calls;
3. inspect stderr for authentication, network, permission or CLI failures.

After exit, require a successful process status and parse the final
`type="result"` record from the JSONL file. Read the complete verdict and every
finding before changing reviewed files. In the package's durable review record,
preserve the review date, reviewed commit SHA, `git status --porcelain` state,
SHA-256 of an uncommitted reviewed diff or immutable artifact when applicable,
prompt SHA-256, JSONL SHA-256, Claude CLI version, SHA-256 of the captured
`cli-help.txt`, exact model and effort, independence statement, verdict, and
counts for every severity. Capturing the version and help is a coordinator
preflight and does not require the read-only reviewer to have shell access. The
calibration fields required by
[agent-model-policy.md](agent-model-policy.md) live in the package record or
its documented commit-message fallback. Then remove only the exact temporary
directories created for the review.
