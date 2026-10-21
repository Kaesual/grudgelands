#!/usr/bin/env bash
# Round 55 lane MODEL: screenshots of the offhand parts in a real client.
# Writes the stand-in offhand textures (stand_in.py: the art directory's
# sheets pasted into the offhand atlas, never the bake) into a temp folder
# and runs Round 54's capture (tools/r54_model/capture.sh: the probe
# grug_probe_r54_model, tools/luanti_headless.sh, one Flatpak client on a
# private Xvfb, the personal Luanti folder never touched) with this
# folder's scene.lua. The textures travel in MODELS: Luanti serves every
# media file of a mod's models/ folder too (src/server/mods.cpp).
#
# Usage: XVFB=/path/to/Xvfb tools/r55_model/capture.sh OUT_DIR
#   ART=<offhand art dir> (default tools/r55_offhand/test_art), SETTLE
#   (default 4) and every other variable of tools/r54_model/capture.sh.
#   Run it through the shared Lua queue (one boot).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: capture.sh OUT_DIR}"
media="$(mktemp -d /tmp/grudgelands-capture.r55model-media-XXXXXX)"
trap 'rm -rf "$media"' EXIT
python3 "$here/stand_in.py" --out "$media" ${ART:+--art "$ART"}
env SCENE="$here/scene.lua" MODELS="$media" SETTLE="${SETTLE:-4}" \
	bash "$repo/tools/r54_model/capture.sh" "$out"
