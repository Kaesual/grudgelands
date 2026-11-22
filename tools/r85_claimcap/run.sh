#!/usr/bin/env bash
# Round 85 CLAIMCAP: the whole study in one command.
#   tools/r85_claimcap/run.sh [outdir] [parallel]
# Runs claimcap.lua on the production seed and the ten other seeds of the
# Round 84 site study (tools/r84_site), each one Lua process through the
# shared queue (about 4 min and 2 GB each; a seed whose meta.tsv exists is
# skipped), then analyze.py (tables, report numbers, pictures) and quota.py
# (follow-up 2, the placement quota).
# Default outdir: ~/projects/grudgelands-orchestration/r85/claimcap
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
out="${1:-$HOME/projects/grudgelands-orchestration/r85/claimcap}"
par="${2:-4}"
queue="$HOME/projects/grudgelands-orchestration/r45/lua_run.sh"
SEEDS="3684797457838814663 17713522922938657774 5575844014311305038 6410640627505506314
9512886083845910081 4282870288782723 2996858566870034 12345 6866842473207
75731352233772710 52857145422941"
mkdir -p "$out/runs"
run() {
	if [[ -x "$queue" ]]; then "$queue" "$@"; else shift 2; LC_ALL=C chrt --idle 0 ionice -c3 "$@"; fi
}
export -f run
for seed in $SEEDS; do
	[[ -f "$out/runs/$seed/meta.tsv" ]] && grep -q '^regions_s' "$out/runs/$seed/meta.tsv" && continue
	echo "$seed"
done | out="$out" queue="$queue" repo="$repo" xargs -P "$par" -L 1 bash -c '
	mkdir -p "$out/runs/$1"
	run r85-claimcap 1 luajit "$repo/tools/r85_claimcap/claimcap.lua" "$repo" "$1" "$out/runs/$1" \
		>"$out/runs/$1.log" 2>&1 || echo "FAIL $1: $(tail -n 3 "$out/runs/$1.log")"
	tail -n 1 "$out/runs/$1.log"' _
# shellcheck disable=SC2086
python3 "$repo/tools/r85_claimcap/analyze.py" "$out" $SEEDS
# shellcheck disable=SC2086
python3 "$repo/tools/r85_claimcap/quota.py" "$out" $SEEDS
