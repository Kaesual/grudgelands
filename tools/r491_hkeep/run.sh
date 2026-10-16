#!/usr/bin/env bash
# 0.49.1 study HKEEP: one engine experiment, three boots on throw-away worlds.
#   boot 1  fresh world (seed 12345): the probe (grug_probe_hkeep, staged
#           only) emerges 3 x 3 chunk columns x 3 layers around the kept
#           column K (minp 368,-2352), places markers in K and snapshots
#           every chunk; the world is then copied once.
#   reset   on both copies, with the server stopped: keep_columns.py deletes
#           every map block outside K's column; grug_reset_world = 1 is raised
#           through a disposable patch of the staged minetest.conf (as
#           tools/r41_up/engine.sh does).
#   boot 2  same seed and code: the neighbours regenerate with the old layout.
#   boot 3  the copy with its map_meta.txt seed changed to 4242: the
#           neighbours regenerate with a different terrain and layout (a
#           stand-in for a reset whose world generation changed).
# Every boot goes through the shared Lua queue (1 slot) and ends with the
# probe's shutdown; logs and probe lines go to OUT. Run directories are removed
# at the end unless KEEP_ROOTS=1.
#
# Usage: tools/r491_hkeep/run.sh OUT
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT}"
mkdir -p "$out"; out="$(cd "$out" && pwd -P)"
queue="$HOME/projects/grudgelands-orchestration/r45/lua_run.sh"
timeout_s="${TIMEOUT:-300}"
stage="$(mktemp -d)"
root1=""; root2=""
cleanup() {
	rm -rf "$stage"
	if [[ "${KEEP_ROOTS:-0}" != 1 ]]; then
		for r in "$root1" "$root2"; do
			[[ -n "$r" && "$r" == /tmp/grudgelands-headless.?* && -d "$r" ]] && rm -rf "$r"
		done
	fi
}
trap cleanup EXIT

probe_with() { # mode tag -> staged probe dir
	local dir="$stage/$1-$2"
	mkdir -p "$dir"; cp -a "$here/grug_probe_hkeep" "$dir/"
	printf 'return {mode = "%s", tag = "%s"}\n' "$1" "$2" >"$dir/grug_probe_hkeep/config.lua"
	echo "$dir/grug_probe_hkeep"
}
boot() { # label probe_dir [ROOT] [GAME_PATCH]
	local label="$1" probe="$2" root="${3:-}" patch="${4:-}"
	set +e
	env PROBE="$probe" KEEP=1 SEED=12345 ${root:+ROOT="$root"} ${patch:+GAME_PATCH="$patch"} \
		"$queue" "hkeep-$label" 1 "$repo/tools/luanti_headless.sh" "$timeout_s" \
		>"$out/$label.txt" 2>&1
	local rc=$?
	set -e
	echo "$label rc=$rc" >>"$out/summary.txt"
}

: >"$out/summary.txt"
start=$(date +%s)
boot boot1 "$(probe_with build original)"
root1="$(sed -n 's/^kept: //p' "$out/boot1.txt" | tail -n 1)"
[[ -n "$root1" && -d "$root1/world" ]] || { cat "$out/boot1.txt"; exit 1; }
cp "$root1/server.log" "$out/boot1.log"
echo "boot1 wall_s=$(( $(date +%s) - start ))" >>"$out/summary.txt"

root2="$(mktemp -d /tmp/grudgelands-headless.XXXXXX)"
cp -a "$root1/world" "$root2/world"
{ cat "$repo/minetest.conf"; printf '\n# The platform raises this for a map reset.\ngrug_reset_world = 1\n'; } \
	>"$stage/minetest.conf.reset"
diff -u --label a/minetest.conf --label b/minetest.conf \
	"$repo/minetest.conf" "$stage/minetest.conf.reset" >"$stage/reset.patch" || true
for r in "$root1" "$root2"; do
	python3 "$here/keep_columns.py" "$r" 368,-2352 | tee -a "$out/summary.txt"
done
sed -i 's/^seed = .*/seed = 4242/' "$root2/world/map_meta.txt"
grep -h '^seed' "$root1/world/map_meta.txt" "$root2/world/map_meta.txt" >>"$out/summary.txt"

start=$(date +%s)
boot boot2 "$(probe_with check same-seed)" "$root1" "$stage/reset.patch"
cp "$root1/server.2.log" "$out/boot2.log"
echo "boot2 wall_s=$(( $(date +%s) - start ))" >>"$out/summary.txt"
start=$(date +%s)
boot boot3 "$(probe_with check new-seed)" "$root2" "$stage/reset.patch"
cp "$root2/server.log" "$out/boot3.log"
echo "boot3 wall_s=$(( $(date +%s) - start ))" >>"$out/summary.txt"
for n in 1 2 3; do
	grep -h '\[hkeep_probe\]\|\[grug_core\] map reset\|GRUG-SEVERE' "$out/boot$n.log" \
		>"$out/probe$n.txt" || true
done
cat "$out/summary.txt"
