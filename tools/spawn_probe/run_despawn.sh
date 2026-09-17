#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
label="${1:?usage: run_despawn.sh LABEL PORT EXPECTED_ALIVE}"
port="${2:?usage: run_despawn.sh LABEL PORT EXPECTED_ALIVE}"
expected_alive="${3:?usage: run_despawn.sh LABEL PORT EXPECTED_ALIVE}"
seed=15912857179583385436
evidence="$repo/tools/spawn_probe/evidence/$label"
probe="$repo/tools/spawn_probe/grug_despawn_probe"

[[ "$port" =~ ^311[0-9][0-9]$ ]] || exit 2
[[ "$expected_alive" == true || "$expected_alive" == false ]] || exit 2
[[ ! -e "$evidence" ]] || exit 2
mkdir -p "$evidence"

KEEP=1 PORT="$port" SEED="$seed" PROBE="$probe" \
	nice -n 19 "$repo/tools/luanti_headless.sh" 90 \
	>"$evidence/launch.log" 2>&1
server_log="$(sed -n 's/^log: //p' "$evidence/launch.log" | tail -1)"
cp "$server_log" "$evidence/server.log"
rg 'GRUG_R5_DESPAWN' "$server_log" >"$evidence/lifetime.log"
rg -q "GRUG_R5_DESPAWN event=finish seconds=40 alive=$expected_alive" \
	"$evidence/lifetime.log"
printf 'despawn evidence: %s\n' "$evidence"
