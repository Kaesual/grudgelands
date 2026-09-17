#!/usr/bin/env bash
# Run the round-5 tree-trunk probe against the pre-lane and current trees.
#
# Both boots use the same seed and arena probe. The before mirror is a clean
# archive of BEFORE_REF, so reach, mob definitions and vendored code all come
# from the same revision; the after mirror is the current worktree. The repo is
# never rewritten. Each launcher boot is capped at 120 seconds and its isolated
# server logs are copied into OUTPUT_DIR before the scratch roots are removed.
#
# Usage: run_trunk_probe.sh OUTPUT_DIR BEFORE_REF [SEED]
#   PORT must be one port from this lane's 31000-31099 block.
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="${1:?usage: run_trunk_probe.sh OUTPUT_DIR BEFORE_REF [SEED]}"
before_ref="${2:?usage: run_trunk_probe.sh OUTPUT_DIR BEFORE_REF [SEED]}"
seed="${3:-15912857179583385436}"
port="${PORT:?PORT must be set to a port in the lane port block}"
timeout_s="${TIMEOUT:-120}"

[[ "$port" =~ ^310[0-9][0-9]$ ]] || {
	echo "run_trunk_probe: PORT must be in 31000-31099" >&2
	exit 2
}
[[ "$timeout_s" =~ ^[0-9]+$ && "$timeout_s" -le 120 ]] || {
	echo "run_trunk_probe: TIMEOUT must be at most 120 seconds" >&2
	exit 2
}
[[ "$output" = /* && ! -e "$output" ]] || {
	echo "run_trunk_probe: OUTPUT_DIR must be an absent absolute path" >&2
	exit 2
}
before_commit="$(git -C "$repo" rev-parse --verify "$before_ref^{commit}" 2>/dev/null || true)"
[[ -n "$before_commit" ]] || {
	echo "run_trunk_probe: BEFORE_REF is not a commit: $before_ref" >&2
	exit 2
}
mkdir -p "$output"

mirror_root="$(mktemp -d /tmp/grug-r5-C-trunk-mirror.XXXXXX)"
cleanup() { rm -rf "$mirror_root"; }
trap cleanup EXIT

build_mirror() {
	local name="$1"
	local dir="$mirror_root/$name"
	mkdir -p "$dir/tools"
	cp -a "$repo/game.conf" "$repo/mods" "$dir/"
	for file in minetest.conf settingtypes.txt menu textures; do
		if [[ -e "$repo/$file" ]]; then cp -a "$repo/$file" "$dir/"; fi
	done
	cp -a "$repo/tools/luanti_headless.sh" "$dir/tools/"
	echo "$dir"
}

build_before_mirror() {
	local dir="$mirror_root/before"
	mkdir -p "$dir"
	git -C "$repo" archive "$before_commit" game.conf mods minetest.conf \
		settingtypes.txt menu tools/luanti_headless.sh | tar -xf - -C "$dir"
	echo "$dir"
}

boot() {
	local label="$1" mirror="$2" run_out="$3"
	mkdir -p "$run_out"
	echo "== boot $label (port $port, seed $seed)"
	echo "   api.lua sha256 $(sha256sum "$mirror/mods/ENTITIES/mobs/api.lua" | cut -d' ' -f1)"
	PORT="$port" SEED="$seed" KEEP=1 \
		PROBE="$repo/tools/wp11/trunk_probe" \
		nice -n 19 "$mirror/tools/luanti_headless.sh" "$timeout_s" \
		>"$run_out/boot.log" 2>&1 ||
		echo "   (launcher exit $? -- the probe shuts the server down itself)"
	local kept
	kept="$(grep -o 'kept: .*' "$run_out/boot.log" | tail -1 | cut -d' ' -f2)"
	if [[ -n "$kept" && -d "$kept" ]]; then
		cp -a "$kept"/server*.log "$run_out/" 2>/dev/null || true
		cp -a "$kept"/server*.console.log "$run_out/" 2>/dev/null || true
		rm -rf "$kept"
	fi
	grep -h "\[trunk_probe\]" "$run_out"/server.log 2>/dev/null |
		sed 's/.*\[trunk_probe\] //' >"$run_out/probe.txt" || true
	grep -h 'ERROR\|ModError' "$run_out"/server*.log 2>/dev/null |
		head -20 >"$run_out/errors.txt" || true
	echo "-- $label --"
	cat "$run_out/probe.txt"
}

after_mirror="$(build_mirror after)"
before_mirror="$(build_before_mirror)"

boot before "$before_mirror" "$output/before"
boot after "$after_mirror" "$output/after"

echo
echo "== punches per 10 s =="
for phase in before after; do
	while read -r line; do
		printf '%-7s %s\n' "$phase" "$line"
	done < <(grep '^result punches=' "$output/$phase/probe.txt" 2>/dev/null || true)
done
echo
pgrep -af '^luanti.bin --server' || echo "no luanti server process left"
