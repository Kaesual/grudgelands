#!/usr/bin/env bash
# Round 28 Lane S2b engine probe: Mortuary-Clerk Hush, the zombie leader of
# the shipped Nhal Veyr recipe, spawned by the leader tick on blight dirt,
# survives noon (sunproof on blight), while a control zombie burns.
#
# Boots one isolated headless server through tools/luanti_headless.sh with the
# disposable probe mod staged (never shipped) and the Round 24 probe-player
# shim (tools/r24_density_xp/probe_player_shim.patch). The portable proof is
# the blight block of tools/r28_s1/portable_test.lua (LuaJIT).
#
# Usage: tools/r28_s2b/run.sh OUT_DIR [TIMEOUT_SECONDS]   (SEED default 42)
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: run.sh OUT_DIR [TIMEOUT_SECONDS]}"
timeout_s="${2:-200}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
set +e
SEED="${SEED:-42}" PROBE="$here/grug_probe_r28_s2b" \
	GAME_PATCH="$repo/tools/r24_density_xp/probe_player_shim.patch" KEEP=1 \
	"$repo/tools/luanti_headless.sh" "$timeout_s" >"$out/headless.txt" 2>&1
boot=$?
set -e
root="$(sed -n 's/^kept: //p' "$out/headless.txt" | tail -n 1)"
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root"/server*.log "$out/" 2>/dev/null || true
	rm -rf "$root"
fi
cat "$out/headless.txt"
grep -h '\[r28_s2b_probe\]' "$out/server.log" 2>/dev/null >"$out/probe.txt" || true
cat "$out/probe.txt"
if grep -q 'RESULT PASS' "$out/probe.txt"; then
	echo "r28 s2b probe: PASS (boot status $boot)"
	exit 0
fi
echo "r28 s2b probe: FAIL (boot status $boot)"
exit 1
