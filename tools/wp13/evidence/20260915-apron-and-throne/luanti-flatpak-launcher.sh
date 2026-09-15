#!/usr/bin/env bash
# Launcher for the WP40 profiler: forwards its engine arguments to the
# Flatpak Luanti 5.17 the workstation has installed.
#
# The workstation runs the user's own GUI client at the same time, so this
# launcher must never let a headless server touch the personal Flatpak folder
# (~/.var/app/org.luanti.luanti/.minetest). It therefore REFUSES to run with
# an empty LUANTI_USER_PATH -- the variable the profiler sets to its own
# scratch directory -- instead of silently falling back to the personal one,
# and it pins every XDG directory into that same scratch tree so no cache,
# data or config file is written outside it either.
set -euo pipefail

user_path="${LUANTI_USER_PATH:-}"
[[ -n "$user_path" && "$user_path" = /* ]] || {
	echo "WP13 launcher: LUANTI_USER_PATH must be an absolute scratch path" >&2
	exit 2
}
case "$user_path" in
	"$HOME"/.var/*|"$HOME"/.minetest*)
		echo "WP13 launcher: refusing to run inside the personal Luanti folder" >&2
		exit 2
		;;
esac
mkdir -p "$user_path/xdg-cache" "$user_path/xdg-data" "$user_path/xdg-config"

# The repository is derived from this script's own location instead of being
# written down: round B hard-coded the main checkout's path, which is silently
# wrong when the same evidence is reproduced from an agent worktree.
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"

exec flatpak run \
	--filesystem=/tmp \
	--filesystem="$repo:ro" \
	--env=LUANTI_USER_PATH="$user_path" \
	--env=XDG_CACHE_HOME="$user_path/xdg-cache" \
	--env=XDG_DATA_HOME="$user_path/xdg-data" \
	--env=XDG_CONFIG_HOME="$user_path/xdg-config" \
	--command=luanti org.luanti.luanti "$@"
