#!/usr/bin/env bash
# Round 71 lane UI: one boot of the probe grug_probe_r71_ui_world on a kept
# world. The first run makes the world on the checkout it is called from, the
# second takes its ROOT and re-uses it on the code under test:
#   KEEP=1 tools/r71_ui/old_world.sh                 (prints "kept: <root>")
#   ROOT=<root> tools/r71_ui/old_world.sh
# Run it through the shared Lua queue (one boot).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SEED="${SEED:-42}" PROBE="$here/grug_probe_r71_ui_world" \
	exec "$here/../luanti_headless.sh" 280
