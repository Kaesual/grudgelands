#!/usr/bin/env bash
# Round 56 lane MOUNT: the engine proof. One boot of a fresh world (seed 42)
# through tools/luanti_headless.sh with the disposable probe
# grug_probe_r56_mount staged and mob spawns off (a one-line patch to the
# staged minetest.conf); one protocol client (tools/r43_it/client.py) joins
# as the rider. The probe drops a horse with its rider from 11 and 20 nodes,
# jumps it in place and at a 2-node step, and hits the rider; it shuts the
# server down when done.
#
# Usage: tools/r56_mount/run.sh OUT_DIR   (through the shared Lua queue, one boot)
# Writes OUT_DIR/probe.txt (the probe's lines), server.log, headless.txt and
# client.txt. The run directory is removed afterwards.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
root="$(mktemp -d /tmp/grudgelands-headless.r56mount-XXXXXX)"
patchdir="$(mktemp -d /tmp/grudgelands-r56mount-patch-XXXXXX)"
port=""
for _ in $(seq 1 50); do
	port=$((30000 + (RANDOM * 32768 + RANDOM) % 10000))
	ss -Hlun "sport = :$port" 2>/dev/null | grep -q . || break
done
server_pid=""; client_pid=""
cleanup() {
	[[ -n "$client_pid" ]] && kill "$client_pid" 2>/dev/null || true
	[[ -n "$server_pid" ]] && wait "$server_pid" 2>/dev/null || true
	cp "$root/server.log" "$out/server.log" 2>/dev/null || true
	grep -a '\[r56mount\]' "$root/server.log" >"$out/probe.txt" 2>/dev/null || true
	rm -rf "$root" "$patchdir"
}
trap cleanup EXIT

mkdir -p "$patchdir/a" "$patchdir/b"
cp "$repo/minetest.conf" "$patchdir/a/minetest.conf"
cp "$repo/minetest.conf" "$patchdir/b/minetest.conf"
printf '\n# Round 56 MOUNT probe\nmobs_spawn = false\n' >>"$patchdir/b/minetest.conf"
(cd "$patchdir" && diff -u a/minetest.conf b/minetest.conf >"$patchdir/probe.patch") || true

ROOT="$root" PORT="$port" SEED=42 PROBE="$here/grug_probe_r56_mount" \
	GAME_PATCH="$patchdir/probe.patch" \
	bash "$repo/tools/luanti_headless.sh" 280 >"$out/headless.txt" 2>&1 &
server_pid=$!
for _ in $(seq 1 240); do
	grep -q 'listening on' "$root/server.log" 2>/dev/null && break
	kill -0 "$server_pid" 2>/dev/null || break
	sleep 0.5
done
python3 "$repo/tools/r43_it/client.py" "$port" grugmount 270 >"$out/client.txt" 2>&1 &
client_pid=$!
status=0
wait "$server_pid" || status=$?
server_pid=""
cat "$out/headless.txt"
exit $status
