#!/usr/bin/env bash
# The engine gate for the WP13 start-NPC increment: two headless boots on ONE
# world, plus a census of what the first boot actually left on disk.
#
#   boot 1  fresh world, seed 531802985935182545, 240 s. The startup preload
#           reports all six starts ready after ~38 s and the placement pass
#           runs per start immediately afterwards, because THAT is the moment
#           the 128 x 128 envelope is loaded and no player is anywhere near it.
#   boot 2  the SAME world again (ROOT=), 200 s. Every start must report
#           "new 0 pending 0": nothing is placed a second time.
#   census  the kept world's map.sqlite is decompressed block by block and the
#           static objects are counted by entity name. This is the half the log
#           cannot prove -- a static object in a loaded but INACTIVE mapblock is
#           invisible to every Lua query -- so 54 objects in the map after boot
#           2 is what says the first boot's roster survived the restart and was
#           not doubled.
#
# Isolation: tools/luanti_headless.sh stages the game into its own temp
# directory and pins LUANTI_USER_PATH and every XDG dir inside it, so no
# headless server can touch the personal Flatpak folder the user's GUI client
# uses; each boot is bounded by `timeout --kill-after`; and the process check
# at the end is SCOPED TO THIS RUN'S directory, because a blanket
# `pkill luanti.bin` would also hit the user's own client and another lane's
# server.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260914-start-npcs"
seed=531802985935182545

SEED="$seed" KEEP=1 PORT="${PORT1:-32956}" bash tools/luanti_headless.sh 240 \
	| tee "/tmp/wp13-start-npcs-boot1.txt"
root="$(awk '/^kept: /{print $2}' /tmp/wp13-start-npcs-boot1.txt)"
[[ -n "$root" && -d "$root" ]] || { echo "boot 1 kept no world" >&2; exit 1; }

SEED="$seed" ROOT="$root" PORT="${PORT2:-32957}" bash tools/luanti_headless.sh 200 \
	| tee "/tmp/wp13-start-npcs-boot2.txt"

mkdir -p "$here"
grep -E '\[grug_(mobs|core)\] (start npcs|start preload|start area ready|all 6)' \
	"$root/server.log" >"$here/engine-boot1.log"
grep -E '\[grug_(mobs|core)\] (start npcs|start preload|start area ready|all 6)' \
	"$root/server.2.log" >"$here/engine-boot2.log"
{
	echo "== boot 1 (fresh world, seed $seed) =="
	printf 'ERROR+ModError lines: %s\n' \
		"$(grep -cE 'ERROR|ModError' "$root/server.log" || true)"
	echo "== boot 2 (same world) =="
	printf 'ERROR+ModError lines: %s\n' \
		"$(grep -cE 'ERROR|ModError' "$root/server.2.log" || true)"
} >"$here/engine-errors.txt"

python3 - "$root" >"$here/engine-census.txt" <<'PY'
import re
import sqlite3
import sys
from collections import Counter

import zstandard

root = sys.argv[1]
con = sqlite3.connect(root + "/world/map.sqlite")
rows = con.execute("select x,y,z,data from blocks").fetchall()
# Entity names AND the composed race skins: a villager that never reached the
# visuals seam would still be counted as an entity but would carry the
# placeholder guard texture, so both are counted from the same blobs.
pattern = re.compile(
    rb"grug_mobs:(?:villager|elder|guard)_[a-z]+"
    rb"|grug_traders:vendor_race_[a-z]+"
    rb"|grug_visuals_skin_[a-z]+\.png")
found, undecodable = Counter(), 0
for x, y, z, blob in rows:
    if not blob:
        continue
    try:
        # MapBlock serialisation >= 29: one zstd stream after the version byte.
        raw = zstandard.ZstdDecompressor().decompressobj().decompress(blob[1:])
    except Exception:
        undecodable += 1
        continue
    for name in pattern.findall(raw):
        found[name.decode()] += 1
print("mapblocks", len(rows), "undecodable", undecodable)
for name in sorted(found):
    print(name, found[name])
print("total", sum(found.values()))
PY

stragglers="$(pgrep -af 'luanti.bin --server' | grep -F -- "$root" || true)"
[[ -z "$stragglers" ]] || {
	printf 'a headless server of this run was left behind:\n%s\n' "$stragglers" >&2
	exit 4
}
echo "no server of this run remains; world kept at $root"
