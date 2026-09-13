#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
output="${1:?absent absolute output directory required}"
puc="${WP40_PUC_BIN:-$repo/tools/bin/lua51}"
[[ "$output" == /* && ! -e "$output" && -x "$puc" ]] || exit 2
mkdir -p "$output"
(cd "$repo" && rg --files mods tools/wp40 tools/wp43 | sort -u) > "$output/input-paths.txt"
mapfile -t inputs < "$output/input-paths.txt"
(cd "$repo" && sha256sum "${inputs[@]}") > "$output/inputs.sha256"
sha256sum "$puc" "$(command -v luajit)" > "$output/interpreters.sha256"
chrt --idle 0 ionice -c3 "$puc" "$repo/tools/wp40/resource_sampling/run.lua" "$repo" > "$output/puc.tsv" 2> "$output/puc.log" &
puc_pid=$!
chrt --idle 0 ionice -c3 luajit "$repo/tools/wp40/resource_sampling/run.lua" "$repo" > "$output/luajit.tsv" 2> "$output/luajit.log" &
lj_pid=$!
puc_status=0; wait "$puc_pid" || puc_status=$?
lj_status=0; wait "$lj_pid" || lj_status=$?
[[ "$puc_status" == 0 && "$lj_status" == 0 ]]
cmp "$output/puc.tsv" "$output/luajit.tsv"
(cd "$repo" && sha256sum -c "$output/inputs.sha256") > "$output/inputs-check.txt"
sha256sum "$output/puc.tsv" "$output/luajit.tsv" > "$output/output.sha256"
printf 'Resource sampling final compact pair PASS: %s\n' "$output"
