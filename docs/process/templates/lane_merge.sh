#!/bin/bash
# Template (docs/process/round-workflow.md "Templates"), from the practised
# Round 79 script: copy to ~/projects/grudgelands-orchestration/r<NN>/ and set
# NN (or pass ROUND=<NN>).
#
# usage: lane_merge.sh <lane> "<subject>": merge r<NN>-<lane> into round<NN>
# with --no-ff in the round branch's worktree. Line conflicts in the
# append-only lists named in APPEND_ONLY keep both sides; any other conflict
# stops with the merge open for the coordinator to resolve.
NN="${ROUND:-<NN>}"
APPEND_ONLY="tools/README.md"
COAUTHOR="${COAUTHOR:-Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>}"
cd "$HOME/projects/grudgelands/.claude/worktrees/round$NN" || exit 1
l=$1; msg="$2"
[ -n "$l" ] && [ -n "$msg" ] || { echo "usage: lane_merge.sh <lane> \"<subject>\"" >&2; exit 2; }
if git merge --no-ff -q "r$NN-$l" -m "$msg

$COAUTHOR"; then git log --oneline -1; exit 0; fi
for f in $APPEND_ONLY; do
  if git diff --name-only --diff-filter=U | grep -qx "$f"; then sed -i '/^<<<<<<< /d;/^=======$/d;/^>>>>>>> /d' "$f"; git add "$f"; fi
done
others=$(git diff --name-only --diff-filter=U)
if [ -n "$others" ]; then echo "CONFLICT in: $others"; exit 1; fi
git commit -q --no-edit; git log --oneline -1
