#!/usr/bin/env bash
# Round 43 lane GS engine check: the start guard refuses a newer world, and
# what the engine writes after that mod-load error. Two boots of one isolated
# world through tools/luanti_headless.sh (no probe, nothing patched):
#   boot 1  a fresh world: the smoke boot; its first server step records the
#           game's version in grug_core's storage (world_version);
#   then    with the server stopped, the record is raised above game.conf's
#           version (the launcher's world keeps mod storage in the files
#           backend: world/mod_storage/grug_core, JSON) and the world
#           directory is listed with sizes, times and hashes;
#   boot 2  the same world must refuse with the newer message; the world
#           directory is listed again.
# Writes both logs, the refusal lines and both listings with their diff to
# OUT_DIR, removes the run directory and exits 0 only when boot 1 passed,
# boot 2 refused with the contract's message and grug_core's storage is
# unchanged by boot 2.
#
# Usage: tools/r43_gs/refusal_boot.sh OUT_DIR [TIMEOUT_SECONDS]
#   SEED=<unsigned decimal> pins the seed (default 42).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: refusal_boot.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-150}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
newer="9.0.0"
root=""
cleanup() {
	if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
		rm -rf "$root"
		# The launcher keeps a failed boot's small files here; boot 2 fails on purpose.
		rm -rf "/tmp/grudgelands-headless-failed/$(basename "$root")"
	fi
}
trap cleanup EXIT

listing() {
	(cd "$1" && find . -type f -printf '%P %s %TY-%Tm-%Td %TT\n' | sort &&
		echo "--- sha256" && find . -type f -print0 | sort -z | xargs -0 sha256sum)
}

set +e
SEED="${SEED:-42}" KEEP=1 "$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/boot1.txt" 2>&1
boot1=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/boot1.txt" | tail -n 1)"
[[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root/world" ]] || {
	cat "$out/boot1.txt"; echo "r43 gs refusal boot: no kept run directory"; exit 1; }
cp "$root/server.log" "$out/boot1.log"
store="$root/world/mod_storage/grug_core"
[[ -f "$store" ]] || { echo "r43 gs refusal boot: no files-backend grug_core storage"; exit 1; }
recorded="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("world_version", ""))' "$store")"

# The newer record, written with the server stopped.
python3 - "$store" "$newer" <<'EOF'
import json, sys
path, newer = sys.argv[1], sys.argv[2]
data = json.load(open(path))
data["world_version"] = newer
json.dump(data, open(path, "w"))
EOF
listing "$root/world" >"$out/world_before_boot2.txt"
store_before="$(sha256sum "$store" | cut -d' ' -f1)"

set +e
ROOT="$root" "$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/boot2.txt" 2>&1
boot2=$?
set -e
cp "$root/server.2.log" "$out/boot2.log"
listing "$root/world" >"$out/world_after_boot2.txt"
diff -u "$out/world_before_boot2.txt" "$out/world_after_boot2.txt" >"$out/world_diff.txt" || true
store_after="$(sha256sum "$store" | cut -d' ' -f1)"
grep -n 'ModError\|downgrade to\|\[grug_core\] world version' "$out/boot1.log" "$out/boot2.log" \
	>"$out/guard_lines.txt" || true

cat "$out/boot1.txt" "$out/boot2.txt"
echo "boot 1 recorded world_version: $recorded"
cat "$out/guard_lines.txt"
echo "world directory changes during boot 2:"
cat "$out/world_diff.txt"
if [[ $boot1 -eq 0 && $boot2 -ne 0 && "$store_before" == "$store_after" ]] &&
		grep -q "downgrade to $newer to continue" "$out/boot2.log" &&
		! grep -q 'listening on' "$out/boot2.log"; then
	echo "r43 gs refusal boot: PASS"
else
	echo "r43 gs refusal boot: FAIL (boot statuses $boot1 $boot2)"
	exit 1
fi
