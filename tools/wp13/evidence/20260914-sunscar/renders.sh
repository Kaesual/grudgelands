#!/usr/bin/env bash
# The review renders of the Sunscar increment, from the frozen blueprint.
# Run from the repository root. TSV is the dumped cell list; TEX points at a
# populated minetest_game checkout, because in a git worktree the submodule
# under reference_projects/ is usually empty (README-render.md).
set -euo pipefail
export LC_ALL=C
tsv="${1:?usage: renders.sh CELLS.tsv [TEXTURE_ROOT]}"
tex="${2:-reference_projects/minetest_game/mods}"
out="tools/wp13/evidence/20260914-sunscar/renders"
mkdir -p "$out"
p() { python3 tools/wp13/render_blueprint.py "$tsv" --texture-root "$tex" "$@"; }

p --view ne --scale 12 -o "$out/overview-ne.png"
p --view sw --scale 12 -o "$out/overview-sw.png"
p --view ne --ymax 6 --scale 12 -o "$out/cutaway-ymax6.png"
p --view ne --scale 12 --light -o "$out/night.png"
p --view ne --region -18 -14 18 16 --scale 20 -o "$out/muster-yard.png"
p --view ne --region -12 9 13 35 --scale 20 -o "$out/gen-hall-warlord-hall.png"
p --view sw --region -12 9 13 35 --scale 20 -o "$out/gen-hall-warlord-platform.png"
p --view ne --region 17 -12 42 10 --scale 20 -o "$out/gen-workshop-armoury.png"
p --view ne --region -45 -24 -18 6 --scale 20 -o "$out/gen-shed-beast-pen.png"
p --view ne --region -40 11 -24 28 --scale 22 -o "$out/gen-round-chief-lodge.png"
p --view ne --region -38 -39 -22 -21 --scale 22 -o "$out/gen-cottage-spear-lodge.png"
p --view ne --region -21 -39 -1 -21 --scale 22 -o "$out/gen-cottage-tusk-lodge.png"
p --view ne --region 5 -39 23 -19 --scale 22 -o "$out/gen-cottage-bone-lodge.png"
p --view ne --region -20 -63 20 -45 --scale 18 -o "$out/gen-watchpost-gate-towers.png"
p --view sw --region 30 14 63 63 --scale 14 -o "$out/mesa-edge.png"
echo "renders written to $out"
