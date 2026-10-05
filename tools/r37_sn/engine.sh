#!/usr/bin/env bash
# Round 37 lane SN smoke boot with the probe grug_probe_r37_sn (staged into a
# throwaway game copy, never shipped): every grug_sounds spec names a shipped
# sound file and the Rift Spawn's fuse is the rift_fuse event.
# Usage (worktree root): tools/r37_sn/engine.sh OUT_DIR
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r37_sn" "$probe/"
KEEP=1 PROBE="$probe/grug_probe_r37_sn" chrt --idle 0 "$repo/tools/luanti_headless.sh" 120 \
	>"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r37sn\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
grep -q 'RESULT DONE events=[0-9]* missing=0 fuse=rift_fuse explode=nil' "$out/probe.txt" && exit "$rc"
exit 1
