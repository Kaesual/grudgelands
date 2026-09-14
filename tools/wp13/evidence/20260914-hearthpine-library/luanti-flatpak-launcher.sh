#!/usr/bin/env bash
# Launcher for the WP40 profiler: forwards its engine arguments to the
# Flatpak Luanti 5.17 the workstation has installed, with the host /tmp and
# the runner's LUANTI_USER_PATH visible inside the sandbox.
set -euo pipefail
exec flatpak run \
	--filesystem=/tmp \
	--filesystem=/home/jan/projects/grudgelands:ro \
	--env=LUANTI_USER_PATH="${LUANTI_USER_PATH:-}" \
	--command=luanti org.luanti.luanti "$@"
