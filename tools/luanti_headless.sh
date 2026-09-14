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
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
timeout_s="${1:-90}"; shift || true
port="${PORT:-$((32800 + RANDOM % 200))}"
seed="${SEED:-}"
[[ -z "$seed" || "$seed" =~ ^(0|[1-9][0-9]*)$ ]] || {
	echo "SEED must be canonical unsigned decimal" >&2
	exit 2
}
supplied_root="${ROOT:-}"
if [[ -n "$supplied_root" ]]; then
	[[ "$supplied_root" = /tmp/grudgelands-headless.* && -d "$supplied_root" ]] || {
		echo "ROOT must be an existing /tmp/grudgelands-headless.* directory" >&2
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
printf 'gameid = grudgelands\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\n' >"$world/world.mt"
printf 'port = %s\nbind_address = 127.0.0.1\nserver_announce = false\n' "$port" >"$root/server.conf"
if [[ -n "$seed" ]]; then
	printf 'fixed_map_seed = %s\n' "$seed" >>"$root/server.conf"
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
