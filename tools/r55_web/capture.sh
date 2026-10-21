#!/usr/bin/env bash
# Round 55 lane WEB: reference renders of the kaesual offhand addendum's test
# characters in a real client: the exported .glb beside the game's .b3d with
# the seven textures a website draws, and the game's look of the Warrior
# (scene.lua, written by gen_test_characters.lua).
#
# Bakes the offhand test art (tools/r55_offhand/bake.py on
# tools/r55_offhand/test_art; never into mods/) and the test wings into a
# temp folder together with the .glb and runs Round 54's capture
# (tools/r54_model/capture.sh: the probe grug_probe_r54_model,
# tools/luanti_headless.sh, one Flatpak client on a private Xvfb, the
# personal Luanti folder never touched) with this folder's scene.lua. The
# textures travel in MODELS: Luanti serves every media file of a mod's
# models/ folder too (src/server/mods.cpp:82-85).
#
# Usage: XVFB=/path/to/Xvfb tools/r55_web/capture.sh OUT_DIR
#   ART=<offhand art dir> (default tools/r55_offhand/test_art), SETTLE
#   (default 4) and every other variable of tools/r54_model/capture.sh.
#   Run it through the shared Lua queue (one boot).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: capture.sh OUT_DIR}"
art="${ART:-$repo/tools/r55_offhand/test_art}"
media="$(mktemp -d /tmp/grudgelands-capture.r55web-media-XXXXXX)"
trap 'rm -rf "$media"' EXIT
python3 "$repo/tools/r55_offhand/bake.py" --art "$art" --out "$media"
cp "$art/wings_test.png" "$media/r55web_wings_test.png"
cp "$repo/tools/web_data/model/grug_visuals_character.glb" "$media/"
env SCENE="$here/scene.lua" MODELS="$media" SETTLE="${SETTLE:-4}" \
	bash "$repo/tools/r54_model/capture.sh" "$out"
