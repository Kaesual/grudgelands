#!/usr/bin/env bash
set -euo pipefail

# Negative proofs for the census launcher's four gates (plan section 6.6.2-4
# and 6.6.7).  A happy-path run is not evidence that a gate works: this branch
# already shipped a verification run that reported success with zero workers
# started, and a ripgrep gate that passed vacuously, and neither would have
# been caught by a test that only asserted the good case.
#
# The module-level negatives live in t2_census_gate_test.lua.  What this script
# adds is the launcher itself: each gate is driven end to end, in a throwaway
# git export of HEAD, so the real tree is never written and the two gates that
# need running workers really start eight of them and really kill them again.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"
scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-census-gates.XXXXXXXX)"
lua_scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-census.XXXXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2-census-gates.* ]]; then
		rm -rf -- "$scratch"
	fi
	if [[ "$lua_scratch" == /tmp/grudgelands-wp40-t2-census.* ]]; then
		rm -rf -- "$lua_scratch"
	fi
}
trap cleanup EXIT

checks=0
fail() {
	echo "WP40 T2 census gate proof failed: $1" >&2
	exit 1
}

# A negative proof counts only when the run aborts *for the stated reason*: an
# abort on an unrelated typo would otherwise read as the gate working.
expect_failure() {
	local label="$1" fragment="$2"
	shift 2
	local output status=0
	output="$("$@" 2>&1)" || status=$?
	checks=$((checks + 1))
	if (( status == 0 )); then fail "$label did not abort"; fi
	if ! grep -qF -- "$fragment" <<<"$output"; then
		printf '%s\n' "$output" >&2
		fail "$label aborted on the wrong reason (wanted: $fragment)"
	fi
	printf '%s' "$output" >"$scratch/last-failure.log"
	echo "gate proof: $label aborted as required (status $status)"
}

expect_in_last() {
	local fragment="$1" label="$2"
	checks=$((checks + 1))
	grep -qF -- "$fragment" "$scratch/last-failure.log" ||
		fail "$label: the aborted run never printed \"$fragment\""
}

# An export of HEAD, committed so the launcher's clean-authority requirement is
# satisfiable, with the built interpreters copied in because tools/bin is a
# per-checkout build artefact and never tracked.
make_export() {
	local name="$1"
	local target="$scratch/$name"
	mkdir -p "$target"
	git -C "$repo" archive HEAD | tar -x -C "$target"
	cp -r "$repo/tools/bin" "$target/tools/bin"
	git -C "$target" init -q
	git -C "$target" add -A
	git -C "$target" -c user.email=census@gate -c user.name=census \
		commit -qm "census gate export"
	printf '%s' "$target"
}

commit_export() {
	git -C "$1" add -A
	git -C "$1" -c user.email=census@gate -c user.name=census \
		commit -qm "census gate export" --amend
}

token_of() {
	"$1/tools/wp40/run_t2_census.sh" --plan |
		sed -n 's/^WP40 T2 census GO token: \([0-9a-f]\{64\}\)$/\1/p'
}

shard_one() {
	printf '%s' "$1/tools/wp40/results/t2_census/census-scan1-v1-0000-0515.tsv"
}

echo "== module-level gate decisions =="
"${WP40_LUA_BIN:-/usr/bin/luajit}" "$script_dir/t2_census_gate_test.lua" "$repo" \
	"$lua_scratch"
checks=$((checks + 1))

echo "== GO gate (plan section 6.6.7) =="
export_dir="$(make_export go-gate)"
token="$(token_of "$export_dir")"
[[ "$token" =~ ^[0-9a-f]{64}$ ]] || fail "the plan step printed no GO token"
expect_failure "a full-W run without the GO token" "needs the explicit GO token" \
	env -u WP40_CENSUS_GO "$export_dir/tools/wp40/run_t2_census.sh" --full-w
expect_failure "a full-W run with a foreign GO token" \
	"the supplied token does not match this W" \
	env WP40_CENSUS_GO="$(printf 'a%.0s' {1..64})" \
	"$export_dir/tools/wp40/run_t2_census.sh" --full-w
if compgen -G "$export_dir/tools/wp40/results/t2_census/*" >/dev/null; then
	fail "a refused full-W run created shard files"
fi
checks=$((checks + 1))
# The worker refuses the same slice on its own, so the gate does not depend on
# the launcher being the only caller (section 6.6.7).
expect_failure "a direct worker call taking a full-W slice without the token" \
	"needs the explicit GO token" \
	env -u WP40_CENSUS_GO WP40_CENSUS_OUTPUT="$scratch/direct.tsv" \
	"$export_dir/tools/wp40/run_t2_census.sh" --range 0 515
expect_failure "a direct worker call taking a full-W slice with a foreign token" \
	"does not match this W" \
	env WP40_CENSUS_GO="$(printf 'b%.0s' {1..64})" \
	WP40_CENSUS_OUTPUT="$scratch/direct.tsv" \
	"$export_dir/tools/wp40/run_t2_census.sh" --range 0 515

echo "== resume gate (plan section 6.6.4) =="
mkdir -p "$export_dir/tools/wp40/results/t2_census"
: >"$(shard_one "$export_dir")"
expect_failure "the empty claim file of a crashed worker" "shard file is empty" \
	env WP40_CENSUS_GO="$token" "$export_dir/tools/wp40/run_t2_census.sh" --full-w
printf 'schema\tgrug_wp40_census_scan1_v1\nvocabulary\tx\n' \
	>"$(shard_one "$export_dir")"
expect_failure "a shard that stops before its digest line" \
	"no trailing digest line" \
	env WP40_CENSUS_GO="$token" "$export_dir/tools/wp40/run_t2_census.sh" --full-w
head -c 4096 /dev/urandom | base64 >"$(shard_one "$export_dir")"
expect_failure "a shard holding unrelated bytes" "no trailing digest line" \
	env WP40_CENSUS_GO="$token" "$export_dir/tools/wp40/run_t2_census.sh" --full-w
rm -f "$(shard_one "$export_dir")"

echo "== cost gate (plan section 6.6.3), eight workers really start =="
expect_failure "a projection past a one-second wall cap" "exceeds the" \
	env WP40_CENSUS_GO="$token" WP40_CENSUS_WALL_CAP_SECONDS=1 \
	"$export_dir/tools/wp40/run_t2_census.sh" --full-w
expect_in_last "workers_started=8" "the cost-gate run"
expect_in_last "ready=1" "the cost-gate run"
# The gate must have reached its verdict, not merely have failed on the way to
# it: the launcher's own abort line names a cap overrun either way, so without
# these two the proof would accept a crashed check as a working gate -- which
# is exactly what it caught on its first run.
expect_in_last "WP40 T2 census cost projection" "the cost-gate run"
expect_in_last "(plan section 6.5)" "the cost-gate run"
if pgrep -f "$export_dir/tools/wp40/t2_census_worker.lua" >/dev/null; then
	sleep 2
	if pgrep -f "$export_dir/tools/wp40/t2_census_worker.lua" >/dev/null; then
		fail "the aborted cost-gate run left workers running"
	fi
fi
checks=$((checks + 1))
rm -f "$export_dir"/tools/wp40/results/t2_census/*.tsv

echo "== first-record gate (plan section 6.6.2), against a live worker record =="
# The class vocabulary is declared in exactly one place, so narrowing it there
# is all it takes to make a genuine worker record violate the contract.  The
# worker never reads that list, which is what makes this a launcher-side proof
# rather than a self-fulfilling one.
broken_export="$(make_export first-record)"
python3 - "$broken_export/tools/wp40/t2_census_authority.lua" <<'PY'
import sys
path = sys.argv[1]
text = open(path).read()
needle = '\t\tedge_class = {"ordinary_interval_select", '
if needle not in text:
    raise SystemExit("census gate proof: the edge class list moved")
open(path, "w").write(text.replace(needle, '\t\tedge_class = {', 1))
PY
commit_export "$broken_export"
broken_token="$(token_of "$broken_export")"
expect_failure "a first record holding a class the contract does not declare" \
	"undeclared class" \
	env WP40_CENSUS_GO="$broken_token" \
	"$broken_export/tools/wp40/run_t2_census.sh" --full-w
expect_in_last "workers_started=8" "the first-record run"
expect_in_last "violates the artifact contract" "the first-record run"
expect_in_last "WP40 T2 census authority:" "the first-record run"
if pgrep -f "$broken_export/tools/wp40/t2_census_worker.lua" >/dev/null; then
	sleep 2
	if pgrep -f "$broken_export/tools/wp40/t2_census_worker.lua" >/dev/null; then
		fail "the aborted first-record run left workers running"
	fi
fi
checks=$((checks + 1))

echo "WP40 T2 census gate proofs passed: $checks launcher-level checks"
