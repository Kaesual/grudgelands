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
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
timeout_s="${1:-90}"; shift || true
port="${PORT:-$((32800 + RANDOM % 200))}"
root="$(mktemp -d /tmp/grudgelands-headless.XXXXXX)"
cleanup() {
	pkill -TERM -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	sleep 1
	pkill -KILL -f "^luanti.bin --server --gameid grudgelands --world $root/" 2>/dev/null || true
	if [[ "${KEEP:-0}" != "1" ]]; then rm -rf "$root"; fi
}
trap cleanup EXIT
user_path="$root/user"; game="$user_path/games/grudgelands"; world="$root/world"
mkdir -p "$game" "$world" "$root/xdg/cache" "$root/xdg/data" "$root/xdg/config"
cp -a "$repo/game.conf" "$repo/mods" "$game/"
for f in minetest.conf settingtypes.txt menu textures; do
	[[ -e "$repo/$f" ]] && cp -a "$repo/$f" "$game/"
done
printf 'gameid = grudgelands\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\n' >"$world/world.mt"
printf 'port = %s\nbind_address = 127.0.0.1\nserver_announce = false\n' "$port" >"$root/server.conf"
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
		--config "$root/server.conf" --logfile "$root/server.log" \
		--log-timestamp none --color never "$@" >"$root/console.log" 2>&1
set -e
status=1
if [[ -f "$root/server.log" ]] && grep -q 'listening on' "$root/server.log" && \
		! grep -q 'ERROR\|ModError' "$root/server.log"; then
	status=0
fi
echo "headless boot: $([[ $status -eq 0 ]] && echo PASS || echo FAIL) (port $port, $timeout_s s)"
grep -n 'ERROR\|ModError\|listening on' "$root/server.log" 2>/dev/null | head -10 || true
[[ "${KEEP:-0}" == "1" ]] && echo "kept: $root"
exit $status
