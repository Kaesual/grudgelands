#!/usr/bin/env bash
# The review loop for the capital parts: every generator rendered for the
# human (Highcourt pilot), dwarf (walled citadel) and troll (stilts) palettes,
# plus an interior cutaway for every part that has a room and a turned view of
# the two chained pieces, so a rotation defect is visible and not only
# asserted.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260914-capital-parts/renders"
tmp="$out/tsv"
cd "$repo"
mkdir -p "$out" "$tmp"

dump() { # <race> <generator> <tag> [spec...]
	local race="$1" gen="$2" tag="$3"
	shift 3
	luajit tools/wp13/dump_capital_part.lua "$repo" "$race" "$gen" \
		"$@" >"$tmp/$tag.tsv"
	luajit tools/wp13/dump_capital_part.lua "$repo" "$race" "$gen" \
		--sockets "$@" 2>/dev/null | grep '^#socket' >"$tmp/$tag.sockets" || true
}

shot() { # <tag> <name> [render options...]
	local tag="$1" name="$2"
	shift 2
	python3 tools/wp13/render_blueprint.py "$tmp/$tag.tsv" \
		-o "$out/$name.png" "$@"
}

PARTS=(
	king_hall wall_segment wall_tower gatehouse colonnade market_square
	well_court statue_plinth barracks temple scriptorium granary stable
	orchard_edge grove stilt_platform water_channel
)

for race in human dwarf troll; do
	for part in "${PARTS[@]}"; do
		dump "$race" "$part" "$race-$part"
		shot "$race-$part" "$race-$part" --scale 14
	done
	# The chained wall piece with its stair chamber, and the same segment
	# turned a quarter, which is how a chained run meets a corner tower.
	dump "$race" wall_segment "$race-wall_stair" len=12 phase=2 stair=true
	shot "$race-wall_stair" "$race-wall_segment-stair" --scale 18
done

# Interior cutaways. `--ymax` drops everything above the course named, which
# for a building is the course under its eave.
cut() { shot "$1" "$2" --scale 16 --ymax "$3"; }
cut human-king_hall human-king_hall-cutaway 8
cut dwarf-king_hall dwarf-king_hall-cutaway 8
cut troll-king_hall troll-king_hall-cutaway 8
cut dwarf-wall_tower dwarf-wall_tower-cutaway 5
cut dwarf-gatehouse dwarf-gatehouse-cutaway 5
cut human-barracks human-barracks-cutaway 4
cut human-temple human-temple-cutaway 5
cut human-scriptorium human-scriptorium-cutaway 4
cut human-granary human-granary-cutaway 4
cut human-stable human-stable-cutaway 4
cut dwarf-wall_stair dwarf-wall_segment-stair-cutaway 7
cut troll-stilt_platform troll-stilt_platform-cutaway 4

# Two turned views, so a rotation defect shows up in a picture.
shot dwarf-wall_tower dwarf-wall_tower-sw --scale 18 --view sw
shot human-market_square human-market_square-nw --scale 14 --view nw

# A night view of the pilot's core and its market, for the lighting.
shot human-king_hall human-king_hall-night --scale 14 --light
shot human-market_square human-market_square-night --scale 14 --light

ls "$out" | wc -l
