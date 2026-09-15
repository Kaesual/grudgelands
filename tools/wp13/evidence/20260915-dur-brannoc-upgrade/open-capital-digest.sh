#!/usr/bin/env bash
# DOES `run_capital.sh full` SURVIVE AN OPEN CAPITAL?
#
# Lanes E (Lethariel) and T (Kezamba) build capitals with NO curtain wall. The
# probe adds the `rampart` and `gate` dump regions only when the composition
# authors one, so on an open capital the runner's read-back digest loop finds no
# `rampart_road_digest=` and no `gate_road_digest=` in the log. Until this
# package it then died: under `set -euo pipefail`, `digest="$(grep -o … | tail
# -1 | cut -d= -f2)"` takes the pipeline's status from the failed `grep`, the
# assignment inherits it, and `set -e` kills the script -- after a completely
# clean boot and before PASS was ever printed.
#
# There is no open capital on this branch to boot, so the fix is proved at the
# shell level instead, and against the SHIPPED BYTES rather than a copy of them:
# the loop is cut out of `tools/wp13/run_capital.sh` with `sed`, wrapped in the
# same `set -euo pipefail` the runner uses, and run against two synthetic logs --
# one with all three regions (a walled capital) and one with the avenue alone
# (an open one). The old form is reconstructed from the same lines with the
# guards removed, so the test also shows the defect it fixes.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
work="$(mktemp -d /tmp/grug-wp13-opencap.XXXXXX)"
trap 'rm -rf -- "$work"' EXIT
cd "$repo"

# Two synthetic logs, in the probe's own line format.
cat >"$work/walled.log" <<'LOG'
ACTION[Server]: GRUG_WP13_CAPITAL event=complete mode=full avenue_road_cells=6048 avenue_road_digest=1299e97e94c2263ffd70a38c5dad27215526c60a9bef213d8fd26e966ea00252 rampart_road_cells=9020 rampart_road_digest=ccd26551d2a729d2d519df197399d013f784410eb401f2a01581a123d29c1ce2 gate_road_cells=2420 gate_road_digest=9988e318244a3f8c5e65dfbbad1ae2a7a144e5d85c3c40b75b642baddd2ce10f
LOG
cat >"$work/open.log" <<'LOG'
ACTION[Server]: GRUG_WP13_CAPITAL event=complete mode=full avenue_road_cells=4111 avenue_road_digest=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
LOG

# The shipped loop, cut out of the runner between the `for label` line and the
# `done` that closes it.
sed -n '/^\tfor label in avenue rampart gate; do$/,/^\tdone$/p' \
	tools/wp13/run_capital.sh >"$work/loop.sh"
grep -q 'for label in avenue rampart gate' "$work/loop.sh" ||
	{ echo "could not cut the digest loop out of run_capital.sh" >&2; exit 2; }

# The same loop with the two guards removed -- what the runner used to be.
sed -e 's/{ grep -o \(.*\) || true; } |/grep -o \1 |/' \
	-e '/if \[\[ -z "\$digest" \]\]; then/,/fi$/d' \
	"$work/loop.sh" >"$work/loop-old.sh"

harness() {                       # $1 = loop body, $2 = log, $3 = label
	local body="$1" log="$2"
	cat >"$work/run.sh" <<EOF
set -euo pipefail
export LC_ALL=C
log="$log"
output="$work/out"
key=lethariel
repo="$repo"
mkdir -p "\$output"
: >"\$output/overlay-digests.txt"
status_digest=0
seed=531802985935182545
$(cat "$body")
echo "LOOP COMPLETED status_digest=\$status_digest"
EOF
	bash "$work/run.sh" >"$work/run.out" 2>"$work/run.err"
	printf '%s' "$?"
}

check() {                         # $1 = body, $2 = log, $3 = want rc, $4 = label
	local rc
	rc="$(harness "$1" "$2")"
	if [[ "$rc" == "$3" ]]; then
		printf '%-52s rc=%s as expected\n' "$4" "$rc"
		sed 's/^/    /' "$work/run.out"
		return 0
	fi
	printf '%-52s rc=%s BUT %s WAS EXPECTED\n' "$4" "$rc" "$3"
	sed 's/^/    /' "$work/run.out" "$work/run.err"
	return 1
}

failures=0
echo "== the shipped loop =="
check "$work/loop.sh" "$work/walled.log" 0 \
	"walled capital, three regions" || failures=$((failures + 1))
check "$work/loop.sh" "$work/open.log" 0 \
	"OPEN capital, avenue only" || failures=$((failures + 1))

echo
echo "== the same loop with this package's two guards removed =="
check "$work/loop-old.sh" "$work/walled.log" 0 \
	"walled capital, three regions" || failures=$((failures + 1))
if check "$work/loop-old.sh" "$work/open.log" 0 \
		"OPEN capital, avenue only" >/dev/null 2>&1; then
	echo "    OPEN capital, avenue only                    rc=0 -- the defect is NOT reproduced"
	failures=$((failures + 1))
else
	echo "    OPEN capital, avenue only                    ABORTS, which is the defect"
fi

echo
if [[ "$failures" -eq 0 ]]; then
	echo "OPEN-CAPITAL DIGEST TEST PASS"
	exit 0
fi
echo "OPEN-CAPITAL DIGEST TEST FAIL: $failures case(s)"
exit 1
