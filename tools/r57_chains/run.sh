#!/usr/bin/env bash
# Round 57 lane CHAINDEPTH: the chain depth report in one go.
#   tools/r57_chains/run.sh OUT_DIR
# Boots the game once (dump.sh: the probe dumps every registered recipe) and
# writes OUT_DIR/dump.lua, OUT_DIR/report.txt and OUT_DIR/index.html.
# DUMP=<file> skips the boot and reads that dump instead. One engine boot:
# run it through the shared Lua queue.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
out_dir="${1:?usage: run.sh OUT_DIR}"
mkdir -p "$out_dir"
if [[ -n "${DUMP:-}" ]]; then
	[[ "$(realpath "$DUMP")" == "$(realpath -m "$out_dir/dump.lua")" ]] || cp "$DUMP" "$out_dir/dump.lua"
else
	"$here/dump.sh" "$out_dir/dump.lua"
fi
luajit "$here/generate.lua" "$out_dir/dump.lua" "$out_dir"
