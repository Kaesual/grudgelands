#!/usr/bin/env bash
# Run the Flatpak Luanti headless server on THIS checkout, fully isolated
# from the user's personal Luanti folder (~/.var/app/org.luanti.luanti).
#
# Rule (user, 2026-09-14): agents never share the personal folder — the GUI
# client may be open at the same time. This launcher stages the game into a
# fresh temp directory, points LUANTI_USER_PATH and the XDG dirs at it, logs
# there, kills the server after the timeout and deletes everything unless
# KEEP=1. Nothing under $HOME is read or written by the engine.
#
# Usage: tools/luanti_headless.sh [TIMEOUT_SECONDS] [extra luanti args...]
#   TIMEOUT default 90. Prints the log path summary and exits 0 when the
#   server reached "listening" without ERROR/ModError lines, 1 otherwise.
#   KEEP=1 keeps the temp dir (path printed). PORT selects the bind port
#   (default 32800+RANDOM%200).
#   SEED=<unsigned decimal> pins `fixed_map_seed`, so a run can be repeated on
#   the world seed a work package names.
#   ROOT=<dir> re-uses an existing run directory (one a previous KEEP=1 run
#   printed) instead of a fresh temp one, which is how a SECOND boot on the
#   SAME world is taken: the map, the player and the mod storage of the first
#   boot are all inside it. A supplied ROOT is never deleted.
#   PROBE=<dir> stages ONE extra mod directory into the throwaway game copy, for
#   a disposable engine probe that is never shipped (the pattern
#   tools/wp13/run_highcourt.sh uses for the capital). It is re-staged on every
#   boot, a ROOT re-use included, and lands inside the scratch tree like
#   everything else -- no directory of the repo is written.
#   GAME_PATCH=<file> applies one disposable patch to the staged game only.
#   R8_CAVE_WRITER_DISABLED=1 disables only the R8 cave-mouth transaction for
#   the revision-bound native-baseline probe; every other mapgen pass remains.
#   R8_NATIVE_BASELINE=1 disables the complete authored writer so a probe can
#   inspect the unchanged native-v7 VM input.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
timeout_s="${1:-90}"; shift || true
port="${PORT:-$((32800 + RANDOM % 200))}"
seed="${SEED:-}"

[[ "${R8_CAVE_WRITER_DISABLED:-0}" == "0" ||
	"${R8_CAVE_WRITER_DISABLED:-0}" == "1" ]] || {
	echo "R8_CAVE_WRITER_DISABLED must be 0 or 1" >&2
	exit 2
}
[[ "${R8_NATIVE_BASELINE:-0}" == "0" ||
	"${R8_NATIVE_BASELINE:-0}" == "1" ]] || {
	echo "R8_NATIVE_BASELINE must be 0 or 1" >&2
	exit 2
}
[[ -z "$seed" || "$seed" =~ ^(0|[1-9][0-9]*)$ ]] || {
	echo "SEED must be canonical unsigned decimal" >&2
	exit 2
}
supplied_root="${ROOT:-}"
if [[ -n "$supplied_root" ]]; then
	# RESOLVED, not glob-matched: this directory is about to have its staged
	# game tree removed and rewritten, and a prefix test alone accepts
	# /tmp/grudgelands-headless.x/../../home/... -- the pattern matches the
	# literal string while the path is somewhere else entirely.
	supplied_root="$(realpath -e -- "$supplied_root" 2>/dev/null || true)"
	[[ -n "$supplied_root" && -d "$supplied_root" &&
		"$supplied_root" == /tmp/grudgelands-headless.?* &&
		"$supplied_root" != */../* ]] || {
		echo "ROOT must resolve to an existing /tmp/grudgelands-headless.* directory" >&2
		exit 2
	}
	root="$supplied_root"
else
	root="$(mktemp -d /tmp/grudgelands-headless.XXXXXX)"
fi
cleanup() {
	pkill -TERM -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	sleep 1
	pkill -KILL -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	if [[ "${KEEP:-0}" != "1" && -z "$supplied_root" ]]; then rm -rf "$root"; fi
}
trap cleanup EXIT
user_path="$root/user"; game="$user_path/games/grudgelands"; world="$root/world"
# Staged fresh every run: `cp -a mods "$game/"` into an EXISTING "$game/mods"
# would nest a second copy inside it, which is exactly what a re-used ROOT has.
rm -rf "$game"
mkdir -p "$game" "$world" "$root/xdg/cache" "$root/xdg/data" "$root/xdg/config"
cp -a "$repo/game.conf" "$repo/mods" "$game/"
for f in minetest.conf settingtypes.txt menu textures; do
	[[ -e "$repo/$f" ]] && cp -a "$repo/$f" "$game/"
done
if [[ -n "${GAME_PATCH:-}" ]]; then
	game_patch="$(realpath -e -- "$GAME_PATCH" 2>/dev/null || true)"
	[[ -n "$game_patch" && -f "$game_patch" ]] || {
		echo "GAME_PATCH must resolve to an existing file" >&2
		exit 2
	}
	patch --silent --forward -p1 -d "$game" <"$game_patch"
	echo "staged patch: $(basename "$game_patch")"
fi
# The optional disposable probe. RESOLVED before use, like ROOT above, and it
# must be a mod directory: a copy without a mod.conf would be a silent no-op.
if [[ -n "${PROBE:-}" ]]; then
	probe="$(realpath -e -- "$PROBE" 2>/dev/null || true)"
	[[ -n "$probe" && -d "$probe" && -f "$probe/mod.conf" ]] || {
		echo "PROBE must be a directory containing mod.conf" >&2
		exit 2
	}
	cp -a "$probe" "$game/mods/$(basename "$probe")"
	echo "staged probe: $(basename "$probe")"
fi
printf 'gameid = grudgelands\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\n' >"$world/world.mt"
printf 'port = %s\nbind_address = 127.0.0.1\nserver_announce = false\n' "$port" >"$root/server.conf"
if [[ -n "$seed" ]]; then
	printf 'fixed_map_seed = %s\n' "$seed" >>"$root/server.conf"
fi
if [[ "${R8_CAVE_WRITER_DISABLED:-0}" == "1" ]]; then
	printf 'grug_mapgen_r8_cave_writer_disabled = true\n' >>"$root/server.conf"
fi
if [[ "${R8_NATIVE_BASELINE:-0}" == "1" ]]; then
	printf 'grug_mapgen_r8_native_baseline = true\n' >>"$root/server.conf"
fi
# One log per boot: a re-used ROOT keeps the previous boot's log instead of
# appending to it, so the two can be read apart.
log="$root/server.log"; index=2
while [[ -e "$log" ]]; do log="$root/server.$index.log"; index=$((index + 1)); done
console="${log%.log}.console.log"
set +e
timeout --foreground --kill-after=5 "$timeout_s" \
	flatpak run --command=luanti \
		--filesystem="$root" \
		--env=LUANTI_USER_PATH="$user_path" \
		--env=XDG_CACHE_HOME="$root/xdg/cache" \
		--env=XDG_DATA_HOME="$root/xdg/data" \
		--env=XDG_CONFIG_HOME="$root/xdg/config" \
		--env=LC_ALL=C \
		org.luanti.luanti --server --gameid grudgelands --world "$world" \
		--config "$root/server.conf" --logfile "$log" \
		--log-timestamp none --color never "$@" >"$console" 2>&1
set -e
status=1
if [[ -f "$log" ]] && grep -q 'listening on' "$log" && \
		! grep -q 'ERROR\|ModError' "$log"; then
	status=0
fi
echo "headless boot: $([[ $status -eq 0 ]] && echo PASS || echo FAIL) (port $port, $timeout_s s)"
echo "log: $log"
grep -n 'ERROR\|ModError\|listening on' "$log" 2>/dev/null | head -10 || true
[[ "${KEEP:-0}" == "1" || -n "$supplied_root" ]] && echo "kept: $root"
exit $status
