#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
for city in dawnmere hearthpine silverleaf stillgrave sunscar kapok \
		highcourt dur_brannoc lethariel nhal_veyr gor_drazhak kezamba \
		copperfell_village goldmead_village starbough_village mournfen_village \
		redtusk_village raincall_village r20_anchor_014 r20_anchor_016 \
		r20_anchor_018 r20_anchor_020 r20_anchor_022 r20_anchor_024; do
	chrt --idle 0 ionice -c3 luajit "$ROOT/tools/r75_city/audit.lua" "$ROOT" "$city"
done
luajit "$ROOT/tools/r75_city/lazy_test.lua" "$ROOT"
