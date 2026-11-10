#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
SNAPSHOTS=$(mktemp -d /tmp/grug-r75-city.XXXXXX)
trap 'rm -rf "$SNAPSHOTS"' EXIT HUP INT TERM
for city in dawnmere hearthpine silverleaf stillgrave sunscar kapok \
		highcourt dur_brannoc lethariel nhal_veyr gor_drazhak kezamba \
		copperfell_village goldmead_village starbough_village mournfen_village \
		redtusk_village raincall_village r20_anchor_014 r20_anchor_016 \
		r20_anchor_018 r20_anchor_020 r20_anchor_022 r20_anchor_024; do
	chrt --idle 0 ionice -c3 luajit "$ROOT/tools/r75_city/export.lua" "$ROOT" "$city" \
		> "$SNAPSHOTS/$city.json"
done
python3 -B "$ROOT/tools/r75_city/author.py" "$SNAPSHOTS"
