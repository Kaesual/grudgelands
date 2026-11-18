#!/usr/bin/env bash
# Seed fleet (Round 34 F3, per-chunk sample since Round 37): the real mapgen
# runtime as main builds it plus five chunks planned and written against a
# fake VoxelManip (tools/seed_fleet/seed.lua, ~20-25 s per seed under LuaJIT)
# over a fixed list of seeds, so a change to world generation shows every seed
# that no longer builds, with its error.
#   tools/seed_fleet/run.sh [quick|full] [EXTRA]
#     quick   the first 100 seeds of seeds.txt (default)
#     full    every seed of seeds.txt (about 300)
#     EXTRA   that many random seeds on top (printed, so a failure repeats)
#   JOBS=<n> parallel seeds (default 8), each under `chrt --idle 0` and
#   `ionice -c3`. There is no wall-clock limit: a slow seed is waited for.
#   RESULTS=<file> also writes every seed's result line there (OK seed seconds
#   roster_sha256 chunks chunk_seconds trees), e.g. to compare rosters with a
#   baseline run.
#   SEEDS=<file> reads the seeds from that file instead of seeds.txt (Round
#   82). DIGEST=<dir> writes every seed's digest file to <dir>/<seed>.txt
#   (seed.lua's digest mode, tools/r82_gen); DENSE=1 adds its digest chunks.
# Prints one line per failed seed and a summary; the log of every seed is in
# the printed directory (kept on a failure). Exits 1 on any failure.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo"
command -v luajit >/dev/null || { echo "luajit not found" >&2; exit 2; }
size="${1:-quick}"; extra="${2:-0}"; jobs="${JOBS:-8}"
case "$size" in
	quick) count=100 ;;
	full) count=100000 ;;
	*) echo "usage: $0 [quick|full] [EXTRA]" >&2; exit 2 ;;
esac
[[ "$extra" =~ ^[0-9]+$ ]] || { echo "EXTRA must be a count" >&2; exit 2; }
idle=()
command -v chrt >/dev/null && idle+=(chrt --idle 0)
command -v ionice >/dev/null && idle+=(ionice -c3)

out="$(mktemp -d /tmp/grug_seed_fleet.XXXXXX)"
grep -v '^#' "${SEEDS:-tools/seed_fleet/seeds.txt}" | grep . | head -n "$count" >"$out/seeds"
digest=()
if [[ -n "${DIGEST:-}" ]]; then
	mkdir -p "$DIGEST"
	digest=("$(cd "$DIGEST" && pwd -P)")
	[[ "${DENSE:-0}" == 1 ]] && digest+=(dense)
fi
if [[ "$extra" -gt 0 ]]; then
	python3 -c 'import random, sys
r = random.SystemRandom()
for _ in range(int(sys.argv[1])): print(r.randrange(1, 2**64))' "$extra" >"$out/extra"
	echo "extra seeds: $(tr '\n' ' ' <"$out/extra")"
	cat "$out/extra" >>"$out/seeds"
fi
total=$(wc -l <"$out/seeds")
echo "seed fleet: $size, $total seeds, $jobs parallel, logs in $out"
started=$SECONDS
export repo out
if [[ ${#digest[@]} -gt 0 ]]; then
	xargs -a "$out/seeds" -P "$jobs" -I{} "${idle[@]}" sh -c \
		'luajit "$repo/tools/seed_fleet/seed.lua" "$repo" "$1" "$2/$1.txt" $3 >"$out/$1.log" 2>&1' \
		_ {} "${digest[@]}"
else
	xargs -a "$out/seeds" -P "$jobs" -I{} "${idle[@]}" sh -c \
		'luajit "$repo/tools/seed_fleet/seed.lua" "$repo" "$1" >"$out/$1.log" 2>&1' _ {}
fi
failed=0
while read -r seed; do
	line="$(grep -E '^(OK|FAIL)' "$out/$seed.log" | tail -n 1)"
	[[ -n "${RESULTS:-}" ]] && printf '%s\n' "${line:-FAIL	$seed}" >>"$RESULTS"
	if [[ "$line" != OK* ]]; then
		failed=$((failed + 1))
		echo "FAIL $seed: ${line:-$(tail -n 3 "$out/$seed.log" | tr '\n' ' ')}"
	fi
done <"$out/seeds"
minutes=$(( (SECONDS - started) / 60 )); secs=$(( (SECONDS - started) % 60 ))
echo "seed fleet: $((total - failed)) of $total seeds build, $failed failed (${minutes} min ${secs} s)"
if [[ $failed -gt 0 ]]; then
	echo "logs kept in $out"
	exit 1
fi
rm -rf "$out"
