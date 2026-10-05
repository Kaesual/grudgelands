#!/bin/bash
# Template (docs/process/round-workflow.md "Templates"): copy to
# ~/projects/grudgelands-orchestration/run_astra.sh.
#
# Launch GPT-6 Astra (Codex CLI) on one lane worktree.
# usage: run_astra.sh <round> <lane>
#   worktree: <repo>/.claude/worktrees/r<round>-<lane>
#   brief:    ~/projects/grudgelands-orchestration/r<round>/astra-<lane>/brief.md
#   output:   last.md, events.jsonl, stderr.log in that astra-<lane> folder
# Reasoning effort xhigh (never "ultra", user rule). The two git roots come
# from rev-parse, never built by hand (docs/process/cross-cli-orchestration.md
# 2.2). Add -c sandbox_workspace_write.network_access=true for a lane that
# boots a headless server.
r=$1; l=$2
M="${GRUG_REPO:-$HOME/projects/grudgelands}"
S="$HOME/projects/grudgelands-orchestration/r$r"
W=$M/.claude/worktrees/r$r-$l
[ -n "$r" ] && [ -n "$l" ] && [ -f "$S/astra-$l/brief.md" ] || { echo "usage: run_astra.sh <round> <lane> (needs $S/astra-$l/brief.md)" >&2; exit 2; }
cd "$W" || exit 1
git_common="$(git -C "$W" rev-parse --path-format=absolute --git-common-dir)"
git_dir="$(git -C "$W" rev-parse --path-format=absolute --git-dir)"
codex exec -C "$W" -s workspace-write -c "sandbox_workspace_write.writable_roots=[\"$git_common\",\"$git_dir\"]" -m gpt-6-astra -c model_reasoning_effort=xhigh --json -o "$S/astra-$l/last.md" - < "$S/astra-$l/brief.md" > "$S/astra-$l/events.jsonl" 2> "$S/astra-$l/stderr.log"
echo "exit=$?"
