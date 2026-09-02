#!/usr/bin/env bash
set -euo pipefail

# WP40 T2 D1 keys-4/5 firing-set projection runner (plan 7.1, contracts 11.6,
# 12.5).  Static-gates t2_r19_order_projection.lua, globs the committed census
# shards, VERIFIES each shard against its own recorded sha256 trailer, runs the
# projection under LuaJIT and the vendored PUC 5.1 and byte-compares the two
# outputs -- the projection's output is the evidence, so an interpreter split
# is itself a failure.
#
#   run_t2_r19_order_projection.sh [ARTIFACTS_DIR] [VERSION...]
#
# ARTIFACTS_DIR defaults to the census shard directory of this checkout.
# VERSION defaults to "4 5 6": v5 and v6 carry the D1 selection and get the
# deep analysis, v4 predates the amendment and is consumed for the plan-7.1
# reconciliation head count only.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"

artifacts_dir="${1:-$repo/tools/wp40/results/t2_census}"
shift || true
versions=("$@")
if (( ${#versions[@]} == 0 )); then versions=(4 5 6); fi

projection="$script_dir/t2_r19_order_projection.lua"
"$repo/tools/bin/luac51" -p "$projection"
if "$repo/tools/bin/luac51" -l -p "$projection" | grep -q 'SETGLOBAL'; then
	echo "WP40 T2 R19 order projection: global write in $projection" >&2
	exit 1
fi

# The five plain-5.1 conformance sweeps of docs/research/luanti-lua.md.
patterns=(
	'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::'
	'\\u\{|\\x[0-9A-Fa-f]|\\z'
	'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.'
	'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]'
	'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.'
)
for pattern in "${patterns[@]}"; do
	if grep -nE "$pattern" "$projection"; then
		echo "WP40 T2 R19 order projection uses a forbidden Lua construct" >&2
		exit 1
	fi
done
bash -n "$script_dir/run_t2_r19_order_projection.sh"

if [[ ! -d "$artifacts_dir" ]]; then
	echo "WP40 T2 R19 order projection: no such artifacts directory:" \
		"$artifacts_dir" >&2
	exit 2
fi

shards=()
for version in "${versions[@]}"; do
	if [[ ! "$version" =~ ^[0-9]+$ ]]; then
		echo "WP40 T2 R19 order projection: version must be a number:" \
			"$version" >&2
		exit 2
	fi
	found=0
	for path in "$artifacts_dir"/census-scan-v"$version"-*.tsv; do
		[[ -f "$path" ]] || continue
		shards+=("$(basename "$path")")
		found=$((found + 1))
	done
	if (( found == 0 )); then
		echo "WP40 T2 R19 order projection: no v$version census shards in" \
			"$artifacts_dir" >&2
		exit 2
	fi
done

# ------------------------------------------------------------------
# The recorded-population gate.
#
# Every census shard's last row is `digest<TAB>sha256=<hex>`, where <hex> is
# the SHA-256 of everything the worker had written before appending it
# (tools/wp40/t2_census_worker.lua: it hashes the closed output file, then
# reopens it and writes the trailer).  So `head -n -1 SHARD | sha256sum`
# reproduces <hex> exactly for an untouched shard.
#
# The projection checks that the trailer EXISTS, is the last row and is well
# shaped -- but it never compares it to the rows, because comparing means
# hashing the file and sweep 5 above forbids the Lua tool a subprocess.  And
# every completeness check the projection does have is structural: the range
# tiling, the declared shard_seeds and the seed-block counts are all counted
# over BLOCKS, never over row content.  Deleting whole records from inside an
# otherwise intact seed block therefore passes all of them, and the verdict
# sentence goes on speaking about "the retained population" while measuring a
# strictly smaller one.
#
# So the digests are verified here, and BEFORE either interpreter starts: a
# mutated shard has to read as "this is not the recorded population", never as
# a measurement over it.  Exit status 3 is reserved for that refusal.
# ------------------------------------------------------------------
if ! command -v sha256sum >/dev/null 2>&1; then
	echo "WP40 T2 R19 order projection: sha256sum is not on PATH, so the" \
		"shard digests cannot be verified" >&2
	exit 3
fi

# `head -n -1` -- everything but the last line -- is a GNU extension, like the
# mktemp -p and grep -nE this repo already relies on.  Probe it rather than
# assume it: a head that ignored the negative count would hash the trailer too
# and turn every shard into a mismatch, and a head that printed nothing would
# hash the empty string.  Either way the digest comparison below would stop
# meaning what it says, so make that loud here instead of silent there.
head_probe="$(printf 'one\ntwo\nthree\n' | head -n -1 | tr '\n' ',')"
if [[ "$head_probe" != "one,two," ]]; then
	echo "WP40 T2 R19 order projection: 'head -n -1' does not drop the last" \
		"line here (got '$head_probe'); GNU coreutils are required to verify" \
		"the shard digests" >&2
	exit 3
fi
empty_digest="$(printf '' | sha256sum | cut -d ' ' -f 1)"

digest_prefix=$'digest\tsha256='
for name in "${shards[@]}"; do
	path="$artifacts_dir/$name"
	trailer="$(tail -n 1 "$path")"
	recorded="${trailer#"$digest_prefix"}"
	if [[ "$recorded" == "$trailer" ]] || [[ ! "$recorded" =~ ^[0-9a-f]{64}$ ]]; then
		echo "WP40 T2 R19 order projection: $name does not end with a" \
			"well-formed digest trailer; its last row is:" >&2
		printf '%s\n' "$trailer" >&2
		echo "WP40 T2 R19 order projection: this is not a recorded census" \
			"shard" >&2
		exit 3
	fi
	computed="$(head -n -1 "$path" | sha256sum | cut -d ' ' -f 1)"
	if [[ "$computed" == "$empty_digest" ]]; then
		echo "WP40 T2 R19 order projection: $name hashed as an EMPTY body," \
			"so no rows were read from it; refusing rather than reporting a" \
			"digest comparison over no bytes" >&2
		exit 3
	fi
	if [[ "$computed" != "$recorded" ]]; then
		echo "WP40 T2 R19 order projection: $name does not match its own" \
			"recorded digest, so this population is not the recorded one" >&2
		echo "  recorded sha256=$recorded" >&2
		echo "  computed sha256=$computed" >&2
		exit 3
	fi
done
echo "WP40 T2 R19 order projection: ${#shards[@]} shard bodies match their" \
	"recorded sha256 trailers"

# The projection is told which versions it must measure, so that a version
# with no shard is its abort rather than a silently narrower population.
version_list="$(printf '%s,' "${versions[@]}")"
version_list="${version_list%,}"

luajit_bin="${WP40_LUA_BIN:-/usr/bin/luajit}"
puc_bin="$repo/tools/bin/lua51"

scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-r19-order.XXXXXXXX)"
trap 'rm -rf "$scratch"' EXIT

luajit_status=0
puc_status=0
"$luajit_bin" "$projection" "$artifacts_dir" "$version_list" "${shards[@]}" \
	>"$scratch/luajit.txt" 2>&1 || luajit_status=$?
"$puc_bin" "$projection" "$artifacts_dir" "$version_list" "${shards[@]}" \
	>"$scratch/puc.txt" 2>&1 || puc_status=$?

if (( luajit_status != puc_status )); then
	echo "WP40 T2 R19 order projection: exit codes differ" \
		"(luajit $luajit_status, puc $puc_status)" >&2
	diff "$scratch/luajit.txt" "$scratch/puc.txt" >&2 || true
	exit 1
fi

# An abort carries the interpreter's own name and traceback into stderr, so
# the two texts differ by construction and the byte-compare below would report
# the interpreter split instead of the refusal that actually happened.  The
# refusal is surfaced first, on its own exit status.
if (( luajit_status != 0 )); then
	echo "WP40 T2 R19 order projection: the projection refused this population" \
		"(exit $luajit_status)" >&2
	cat "$scratch/luajit.txt" >&2
	exit "$luajit_status"
fi

if ! cmp -s "$scratch/luajit.txt" "$scratch/puc.txt"; then
	echo "WP40 T2 R19 order projection: LuaJIT and PUC outputs differ" >&2
	diff "$scratch/luajit.txt" "$scratch/puc.txt" >&2 || true
	exit 1
fi

cat "$scratch/luajit.txt"

# The verdict is the evidence, so a FAIL line in it is this runner's failure
# too (contracts 13.5 STOP).  Without this gate the script exits 0 on a STOP
# and reads as green in any && chain.
if grep -nE '(^|[[:space:]])FAIL([[:space:]]|$)' "$scratch/luajit.txt" >&2; then
	echo "WP40 T2 R19 order projection: the verdict carries a FAIL line;" \
		"contracts 13.5 says STOP and report" >&2
	exit 1
fi

echo "WP40 T2 R19 order projection: LuaJIT/PUC byte-identical"
exit 0
