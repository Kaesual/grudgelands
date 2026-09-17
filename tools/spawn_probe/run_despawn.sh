#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
label="${1:?usage: run_despawn.sh LABEL PORT EXPECTED_NEAR EXPECTED_FAR}"
port="${2:?usage: run_despawn.sh LABEL PORT EXPECTED_NEAR EXPECTED_FAR}"
expected_near="${3:?usage: run_despawn.sh LABEL PORT EXPECTED_NEAR EXPECTED_FAR}"
expected_far="${4:?usage: run_despawn.sh LABEL PORT EXPECTED_NEAR EXPECTED_FAR}"
seed=15912857179583385436
evidence="$repo/tools/spawn_probe/evidence/$label"
probe="$repo/tools/spawn_probe/grug_despawn_probe"

[[ "$port" =~ ^311[0-9][0-9]$ ]] || exit 2
[[ "$expected_near" =~ ^[0-9]+$ && "$expected_far" =~ ^[0-9]+$ ]] || exit 2
[[ ! -e "$evidence" ]] || exit 2
mkdir -p "$evidence"

KEEP=1 PORT="$port" SEED="$seed" PROBE="$probe" \
	nice -n 19 "$repo/tools/luanti_headless.sh" 120 \
	>"$evidence/launch.log" 2>&1
server_log="$(sed -n 's/^log: //p' "$evidence/launch.log" | tail -1)"
cp "$server_log" "$evidence/server.log"
rg 'GRUG_R5_DESPAWN' "$server_log" >"$evidence/lifetime.log"
finish_line="$(rg "GRUG_R5_DESPAWN event=finish seconds=63 near=$expected_near far=$expected_far" \
	"$evidence/lifetime.log")"
active_count="$(sed -n 's/.* active=\([0-9][0-9]*\).*/\1/p' <<<"$finish_line")"
mob_objects="$(sed -n 's/.* mob_objects=\([0-9][0-9]*\).*/\1/p' <<<"$finish_line")"
[[ -n "$active_count" && "$active_count" == "$mob_objects" ]]
printf 'despawn evidence: %s\n' "$evidence"
