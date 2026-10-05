#!/usr/bin/env bash
# Round 35 lane F smoke boot with the probe grug_probe_r35_f (staged into a
# throwaway game copy, never shipped): the dig sound of every grug_resource
# and grug_loose node names an existing file, default:flint is gone and gravel
# drops itself, and the resolved quest titles (for the dialog width).
# Usage (worktree root): tools/r35_f/engine.sh OUT_DIR
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: engine.sh OUT_DIR}"
mkdir -p "$out"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r35_f" "$probe/"
KEEP=1 PROBE="$probe/grug_probe_r35_f" chrt --idle 0 "$repo/tools/luanti_headless.sh" 120 \
	>"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r35f\]' "$out/server.log" >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
cat "$out/launcher.txt"
grep -q 'RESULT DONE titles=[0-9]* dig_failures=0 flint=false' "$out/probe.txt" && exit "$rc"
exit 1
