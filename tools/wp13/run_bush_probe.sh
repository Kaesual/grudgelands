#!/usr/bin/env bash
# The floating-decoration census of WP13 playtest round 3, lane 2: ONE boot of
# `tools/luanti_headless.sh` with the disposable probe of `tools/wp13/bush_probe`
# staged into the throwaway game copy. The probe emerges a square around each
# requested start, counts every decoration ROOT node whose node below is not
# solid, and shuts the server down when it is done.
#
# Isolation is the launcher's (user rule, 2026-09-14): a fresh scratch directory
# as LUANTI_USER_PATH and as every XDG directory, the log inside it, a
# `timeout --kill-after`, only this run's own server killed and nothing under the
# personal Flatpak folder touched.
#
# PORT: pass one in the band your lane owns (`PORT=31101 run_bush_probe.sh ...`).
#
# Usage: run_bush_probe.sh OUTPUT_DIR [SEED] [RADIUS] [STARTS] [TIMEOUT]
#   OUTPUT_DIR  absolute, must not exist; receives the log and the probe lines.
#   SEED        world seed, default the user's gate seed.
#   RADIUS      half-width of the censused square per start, default 128 (the
#               blend envelope). 190 reaches into untouched wild terrain.
#   STARTS      comma-separated 1-based indices into the start roster,
#               default all six.
#   TIMEOUT     wall seconds for the boot, default 1800.
#
# DUMP="<start>,<dx>,<dz>,<half>" switches the probe to render mode instead:
# one box of real generated world around that start's anchor, written to
# OUTPUT_DIR/cells.tsv in the `x y z name param2` form
# `tools/wp13/render_blueprint.py` draws. That is how the before/after pictures
# of the dwarf ring are taken.
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
output="${1:?usage: run_bush_probe.sh OUTPUT_DIR [SEED] [RADIUS] [STARTS] [TIMEOUT]}"
seed="${2:-531802985935182545}"
radius="${3:-128}"
starts="${4:-1,2,3,4,5,6}"
timeout_s="${5:-1800}"
[[ "$output" = /* && ! -e "$output" ]] || {
	echo "run_bush_probe: OUTPUT_DIR must be an absent absolute path" >&2
	exit 2
}
[[ "$seed" =~ ^(0|[1-9][0-9]*)$ ]] || {
	echo "run_bush_probe: SEED must be canonical unsigned decimal" >&2
	exit 2
}
[[ "$radius" =~ ^[1-9][0-9]{0,3}$ ]] || {
	echo "run_bush_probe: RADIUS must be a small positive integer" >&2
	exit 2
}
[[ "$starts" =~ ^[1-6](,[1-6])*$ ]] || {
	echo "run_bush_probe: STARTS must be comma-separated roster indices" >&2
	exit 2
}
mkdir -p "$output"

# The probe's two constants are rewritten into a scratch copy instead of being
# read from a setting: `luanti_headless.sh` owns the server config it writes.
probe="$output/probe"
cp -a "$repo/tools/wp13/bush_probe" "$probe"
sed -i "s/^local RADIUS = .*/local RADIUS = $radius/" "$probe/init.lua"
sed -i "s/^local STARTS = .*/local STARTS = \"$starts\"/" "$probe/init.lua"
if [[ -n "${DUMP:-}" ]]; then
	[[ "$DUMP" =~ ^[1-6],-?[0-9]+,-?[0-9]+,[0-9]+$ ]] || {
		echo "run_bush_probe: DUMP must be start,dx,dz,half" >&2
		exit 2
	}
	sed -i "s/^local DUMP = .*/local DUMP = \"$DUMP\"/" "$probe/init.lua"
fi
( cd "$repo" && find tools/wp13/bush_probe tools/wp13/run_bush_probe.sh \
	-type f -print0 | sort -z | xargs -0 sha256sum ) >"$output/harness.sha256"

root=""
cleanup() {
	[[ -n "$root" && -d "$root" ]] && rm -rf -- "$root"
	return 0
}
trap cleanup EXIT

KEEP=1 SEED="$seed" PROBE="$probe" "$repo/tools/luanti_headless.sh" "$timeout_s" \
	>"$output/boot.txt" 2>&1 || true
root="$(awk '/^kept: /{print $2}' "$output/boot.txt" | tail -1)"
[[ -n "$root" && -d "$root" ]] || {
	echo "run_bush_probe: the boot kept no run directory" >&2
	cat "$output/boot.txt" >&2
	exit 1
}
cp "$root/server.log" "$output/server.log"
grep -h 'GRUG_WP13_BUSH ' "$output/server.log" >"$output/probe.txt" || true
if [[ -n "${DUMP:-}" ]]; then
	sed -n 's/^ACTION\[[^]]*\]: GRUG_WP13_BUSHCELL\t//p' "$output/server.log" \
		>"$output/cells.tsv" || true
	printf 'render cells: %s (%s rows)\n' "$output/cells.tsv" \
		"$(wc -l <"$output/cells.tsv")"
fi
grep -h 'ERROR\|ModError' "$output/server.log" >"$output/errors.txt" || true

errors="$(wc -l <"$output/errors.txt")"
complete="$(grep -c 'event=complete' "$output/probe.txt" || true)"
floating="$(sed -n 's/.*event=complete.*floating_total=\([0-9]*\).*/\1/p' \
	"$output/probe.txt" | tail -1)"
printf 'errors=%s complete=%s floating_total=%s probe=%s\n' \
	"$errors" "$complete" "${floating:-?}" "$output/probe.txt"
[[ "$errors" -eq 0 && "$complete" -eq 1 ]] || {
	echo "WP13 bush probe FAILED; inspect $output" >&2
	exit 1
}
# The acceptance of round 3 lane 2. `BASELINE=1` records a run that is EXPECTED
# to be non-zero (the measurement before the fix) without failing the script.
if [[ "${BASELINE:-0}" != "1" && "${floating:-1}" != "0" ]]; then
	echo "WP13 bush probe FAILED: ${floating} floating decoration roots" >&2
	grep 'event=census' "$output/probe.txt" >&2
	exit 1
fi
echo "WP13 bush probe PASS: $output"
