#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

root="$(realpath -e -- "${1:?usage: run_evidence.sh /absolute/repository/root}")"
[[ "$root" = /* && -f "$root/tools/r8_tags/final_kat.lua" ]] || {
	echo "argument must be the absolute R8-TAGS repository root" >&2
	exit 2
}
out="$root/tools/r8_tags/evidence/final"
mkdir -p "$out"

inputs=(
	tools/r8_tags/final_kat.lua
	tools/r8_tags/kat.lua
	tools/r8_tags/run_evidence.sh
	tools/r5_multiplayer_feel/kat.lua
	tools/r5_progression/progression_kat.lua
	tools/wp13/start_npcs_kat.lua
	tools/wp40/quality/vendor_fixture.lua
	tools/wp45/character_creation_test.lua
)
while IFS= read -r file; do inputs+=("${file#$root/}"); done < <(
	find "$root/mods" -name '*.lua' -type f | sort
)
for file in "$root"/tools/wp11/*_kat.lua; do inputs+=("${file#$root/}"); done
(
	cd "$root"
	sha256sum "${inputs[@]}"
) > "$out/input-manifest.sha256"

code='local root=assert(os.getenv("KAT_ROOT")); io.write(dofile(root .. "/tools/r8_tags/final_kat.lua")(root))'
printf '%s\n' \
	'ROOT=/absolute/path/to/repository' \
	'KAT_ROOT="$ROOT" chrt --idle 0 ionice -c3 "$ROOT/tools/bin/lua51" -e '\''local root=assert(os.getenv("KAT_ROOT")); io.write(dofile(root .. "/tools/r8_tags/final_kat.lua")(root))'\'' > puc.txt' \
	'KAT_ROOT="$ROOT" chrt --idle 0 ionice -c3 luajit -e '\''local root=assert(os.getenv("KAT_ROOT")); io.write(dofile(root .. "/tools/r8_tags/final_kat.lua")(root))'\'' > luajit.txt' \
	'cmp puc.txt luajit.txt && sha256sum puc.txt luajit.txt' \
	> "$out/command.txt"

KAT_ROOT="$root" chrt --idle 0 ionice -c3 "$root/tools/bin/lua51" \
	-e "$code" > "$out/puc.txt" &
puc_pid=$!
KAT_ROOT="$root" chrt --idle 0 ionice -c3 luajit \
	-e "$code" > "$out/luajit.txt" &
jit_pid=$!
wait "$puc_pid"
wait "$jit_pid"
cmp "$out/puc.txt" "$out/luajit.txt"
(
	cd "$out"
	sha256sum puc.txt luajit.txt
) > "$out/output.sha256"
cat "$out/output.sha256"
