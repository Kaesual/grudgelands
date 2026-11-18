#!/usr/bin/env bash
# Round 82 lane COLUMN: the sampler sample (tools/r82_column/sample.lua) of a
# base commit against the current tree, seed by seed. The base tree is
# exported with `git archive` into a scratch folder; both are sampled with
# this tree's sample.lua, JOBS (default 6) at a time through the shared Lua
# queue, and every non-info line must be equal.
#
#   tools/r82_column/compare.sh [BASE_REV]   (default 3112817e, the lane's base)
#
# Seeds: SEEDS="..." (default the first five reference seeds and 12345).
# Prints each seed's result and the timings of both trees; exit 0 only when
# every seed is identical. The scratch folder is kept on a difference.
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
base_rev="${1:-3112817e}"
seeds="${SEEDS:-17713522922938657774 5575844014311305038 6410640627505506314 9512886083845910081 4282870288782723 12345}"
jobs="${JOBS:-6}"
queue="${QUEUE:-$HOME/projects/grudgelands-orchestration/r45/lua_run.sh}"
run=()
[[ -x "$queue" ]] && run=("$queue" r82-column "$jobs")
out="$(mktemp -d /tmp/r82_column.XXXXXX)"
mkdir -p "$out/base" "$out/samples"
git -C "$repo" archive "$base_rev" | tar -x -C "$out/base" || { echo "base export failed" >&2; exit 2; }
jobs_file="$out/jobs.txt"
for seed in $seeds; do
	echo "$out/base base $seed" >>"$jobs_file"
	echo "$repo branch $seed" >>"$jobs_file"
done
"${run[@]}" bash -c '
	jobs="$1" sample="$2" out="$3" list="$4"
	xargs -P "$jobs" -L 1 bash -c "luajit \"$sample\" \"\$0\" \"\$2\" \"$out/samples/\$1_\$2.txt\" >\"$out/samples/\$1_\$2.log\" 2>&1 || echo \"FAIL \$1 \$2\" >>\"$out/failed.txt\"" <"$list"
' _ "$jobs" "$here/sample.lua" "$out" "$jobs_file"
status=0
[[ -s "$out/failed.txt" ]] && { cat "$out/failed.txt"; status=1; }
for seed in $seeds; do
	a="$out/samples/base_$seed.txt" b="$out/samples/branch_$seed.txt"
	if [[ ! -s "$a" || ! -s "$b" ]]; then
		echo "seed $seed: missing sample"; status=1; continue
	fi
	if diff <(grep -v '^info' "$a") <(grep -v '^info' "$b") >"$out/diff_$seed.txt"; then
		echo "seed $seed: identical ($(grep -vc '^info' "$a") lines)"
	else
		echo "seed $seed: DIFFERS"; head -n 20 "$out/diff_$seed.txt"; status=1
	fi
	grep '^info timing\|^info sampler' "$a" | sed 's/^/  base   /'
	grep '^info timing\|^info sampler' "$b" | sed 's/^/  branch /'
done
if [[ $status -ne 0 || "${KEEP:-0}" == 1 ]]; then echo "kept: $out"; else rm -rf "$out"; fi
exit $status
