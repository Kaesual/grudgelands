#!/usr/bin/env bash
# Round 53 lane MAGE engine probe (plan K13): stages the disposable probe
# grug_probe_r53_mage (never shipped) through tools/luanti_headless.sh, copies
# the server log and the probe's lines to OUT_DIR and removes the run root.
#
# Usage (worktree root): tools/r53_mage/probe.sh OUT_DIR [TIMEOUT_SECONDS]
#   LAUNCHER replaces ./tools/luanti_headless.sh (same arguments), e.g. the
#   shared measuring queue: LAUNCHER="<orchestration>/r45/engine_run.sh mage_probe"
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
out="${1:?usage: probe.sh OUT_DIR [TIMEOUT_SECONDS]}"
mkdir -p "$out"
out="$(cd "$out" && pwd -P)"
probe="$(mktemp -d)"
cp -a "$here/grug_probe_r53_mage" "$probe/"
# shellcheck disable=SC2086 # LAUNCHER may carry its own arguments
KEEP=1 PROBE="$probe/grug_probe_r53_mage" ${LAUNCHER:-./tools/luanti_headless.sh} \
	"${2:-300}" >"$out/launcher.txt" 2>&1
rc=$?
root=$(grep -o '/tmp/grudgelands-headless\.[A-Za-z0-9]*' "$out/launcher.txt" | head -1)
if [[ -n "$root" && "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
	cp "$root/server.log" "$out/server.log" 2>/dev/null
	rm -rf "$root"
fi
rm -rf "$probe"
grep -a '\[r53_mage\]' "$out/server.log" | sed 's/^.*\[r53_mage\] //' >"$out/probe.txt" 2>/dev/null
echo "rc=$rc root=$root" >>"$out/launcher.txt"
grep -q 'RESULT DONE' "$out/probe.txt"
