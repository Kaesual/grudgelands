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

# The same proof where the claim is about a *field* of a line rather than a
# line: which shard cast a verdict, and on how many completions.
expect_matches_last() {
	local pattern="$1" label="$2"
	checks=$((checks + 1))
	grep -qE -- "$pattern" "$scratch/last-failure.log" ||
		fail "$label: the aborted run printed no line matching /$pattern/"
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
	printf '%s' "$1/tools/wp40/results/t2_census/census-scan-v3-0000-0515.tsv"
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
printf 'schema\tgrug_wp40_census_scan_v3\nvocabulary\tx\n' \
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
# Section 6.6.3 since 2026-08-16: the shard whose rate casts the verdict must
# have completed at least two seeds.  The first full-W start aborted on eight
# single cold completions, at a rate solo re-measurement of the same three slow
# seeds put 40 s per seed lower -- so an abort line here that names one
# completion is the regression, not the gate.
expect_matches_last \
	'WP40 T2 census cost projection .*completions=([2-9]|[1-9][0-9]+) .*verdict=aborted' \
	"the cost-gate run"
if pgrep -f "$export_dir/tools/wp40/t2_census_worker.lua" >/dev/null; then
	sleep 2
	if pgrep -f "$export_dir/tools/wp40/t2_census_worker.lua" >/dev/null; then
		fail "the aborted cost-gate run left workers running"
	fi
fi
checks=$((checks + 1))
# The aborted run must clean up after itself.  Its workers were killed mid
# record, so their claim files are known incomplete, and leaving them at
# canonical paths would make the resume gate refuse the next run outright.
expect_in_last "reaped shards removed_partial=8" "the cost-gate run"
if compgen -G "$export_dir/tools/wp40/results/t2_census/*.tsv" >/dev/null; then
	fail "the aborted cost-gate run left partial shards behind"
fi
checks=$((checks + 1))

echo "== resume actually resumes, across an unrelated commit =="
# The negatives above prove a bad shard aborts.  A gate that refused everything
# would pass all of them, so the positive belongs here: a well-formed shard for
# the first range must be verified, skipped, and cost exactly one worker.  The
# records are structurally faithful and semantically synthetic, which is all
# the resume verifier reads.
cat >"$scratch/synthesize.lua" <<'LUA'
local repo, scratch, target, first, last, commit = arg[1], arg[2], arg[3],
	tonumber(arg[4]), tonumber(arg[5]), arg[6]
local hasher = dofile(repo .. "/tools/wp40/t2_census_hasher.lua")({
	repo = repo, scratch = scratch})
local authority = dofile(repo .. "/tools/wp40/t2_census_authority.lua")({
	raw_sha256 = hasher.raw_sha256})
local corpus = dofile(repo .. "/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua")
local candidates = assert(io.open(repo .. "/" .. authority.candidates_path, "rb"))
local w = authority.derive_w(corpus, assert(candidates:read("*a")), hasher.raw_sha256)
assert(candidates:close())
local parts = authority.shard_header_lines({schema = authority.schema,
	vocabulary = authority.vocabulary_path, shard_schema = authority.shard_schema,
	first = first, last = last, shard_seeds = last - first + 1,
	w_digest = w.digest, w_total = w.total, census_commit = commit,
	census_tree = string.rep("0", 40),
	module_digest = authority.module_digest(function(path)
		local file = assert(io.open(repo .. "/" .. path, "rb"))
		local bytes = assert(file:read("*a"))
		assert(file:close())
		return bytes
	end),
	interpreter_id = "luajit", interpreter_path = "/usr/bin/luajit",
	interpreter_version = "synthetic"})
for index = 1, authority.prefilter_edge_count do
	parts[#parts + 1] = "prefilter\tedge_" .. index .. "\tscanned\tsynthetic"
end
-- The record shape is derived from the authority's declared roster rather
-- than a shadow copy: occupancy-driven kinds (count nil) emit two synthetic
-- rows, and every class/kind cell takes the first declared vocabulary value.
for index = first, last do
	local seed = assert(w.seeds[index + 1])
	parts[#parts + 1] = "seed_begin\t" .. seed
	for row = 1, #authority.record_rows do
		local layout = authority.record_rows[row]
		for repeated = 1, layout.count or 2 do
			local cells = {layout.tag, seed}
			for field = 3, layout.fields do
				cells[field] = layout.tag .. repeated .. "_" .. field
			end
			if layout.class_field then
				cells[layout.class_field] = authority.classes[layout.class_set][1]
			end
			if layout.extra_field then
				cells[layout.extra_field] = authority.classes[layout.extra_set][1]
			end
			if layout.extra2_field then
				cells[layout.extra2_field] = authority.classes[layout.extra2_set][1]
			end
			parts[#parts + 1] = table.concat(cells, "\t")
		end
	end
	parts[#parts + 1] = "seed_end\t" .. seed
end
local body = table.concat(parts, "\n") .. "\n"
local digest = (hasher.raw_sha256(body):gsub(".", function(byte)
	return ("%02x"):format(string.byte(byte)) end))
local file = assert(io.open(target, "wb"))
assert(file:write(body, "digest\tsha256=", digest, "\n"))
assert(file:close())
hasher.close()
print("synthetic shard written " .. target)
LUA
resume_scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-census.XXXXXXXX)"
"${WP40_LUA_BIN:-/usr/bin/luajit}" "$scratch/synthesize.lua" "$export_dir" \
	"$resume_scratch" "$(shard_one "$export_dir")" 0 515 \
	"$(git -C "$export_dir" rev-parse --verify HEAD)"
rm -rf -- "$resume_scratch"
# Resume is keyed on the module bytes, not on HEAD.  A docs commit landing
# while a multi-hour run is interrupted must not throw away finished shards,
# which is what keying on the commit SHA would have done.
echo "census gate proof marker" >"$export_dir/CENSUS_GATE_MARKER"
commit_export "$export_dir"
expect_failure "a run resuming one verified shard" "exceeds the" \
	env WP40_CENSUS_GO="$token" WP40_CENSUS_WALL_CAP_SECONDS=1 \
	"$export_dir/tools/wp40/run_t2_census.sh" --full-w
expect_in_last "shard verified range=0000..0515 seeds=516" "the resume run"
expect_in_last "workers_started=7 resumed_shards=1" "the resume run"
# The resumed shard survives the abort; only the seven partial ones go.
expect_in_last "reaped shards removed_partial=7" "the resume run"
if [[ ! -e "$(shard_one "$export_dir")" ]]; then
	fail "the abort discarded a shard it had just verified"
fi
checks=$((checks + 1))
# Kept for the merge gate below, which has to prove that a provenance-bearing
# shard is refused where a free record set is expected.
cp "$(shard_one "$export_dir")" "$scratch/gate-shard-for-merge.tsv"
rm -f "$export_dir"/tools/wp40/results/t2_census/*.tsv

echo "== a free small range needs no token =="
WP40_CENSUS_OUTPUT="$scratch/free-range.tsv" \
	"$export_dir/tools/wp40/run_t2_census.sh" --range 0 1
checks=$((checks + 1))
tail -n 1 "$scratch/free-range.tsv" |
	grep -qE '^digest[[:space:]]sha256=[0-9a-f]{64}$' ||
	fail "the free range wrote no digest line"
if grep -q '^shard_schema' "$scratch/free-range.tsv"; then
	fail "a free range emitted shard framing and would resume as a shard"
fi
checks=$((checks + 1))

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

echo "== merge gate (plan sections 6.3, 6.4 and 6.6.5) =="
# The expensive positive -- a four-seed worker KAT merged twice and compared
# byte for byte -- is `run_t2_census.sh --merge-kat` and costs about two and a
# half minutes of scanning.  What belongs here is the refusals, which are all
# sub-second and are the ones a wrong invocation would hit.
merge_scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-census.XXXXXXXX)"
mkdir -p "$scratch/merge-out"
expect_failure "a merge KAT digest that does not match the pinned one" \
	"the KAT fixture pins" \
	"${WP40_LUA_BIN:-/usr/bin/luajit}" \
	"$export_dir/tools/wp40/t2_census_gate.lua" "$export_dir" "$merge_scratch" \
	merge_kat "$(printf 'f%.0s' {1..64})"
# Section 6.6.5: only the vendored PUC may write the committed artifacts, so
# the LuaJIT half of the comparison can never be the half that publishes.
expect_failure "a LuaJIT merge publishing into the committed fixtures" \
	"requires the vendored PUC Lua 5.1" \
	"${WP40_LUA_BIN:-/usr/bin/luajit}" \
	"$export_dir/tools/wp40/t2_census_merge.lua" "$export_dir" "$merge_scratch" \
	"$export_dir/tools/wp40/fixtures/t2_census" --full-w
expect_failure "a KAT record set publishing into the committed fixtures" \
	"only a full-W merge may publish" \
	"$export_dir/tools/bin/lua51" \
	"$export_dir/tools/wp40/t2_census_merge.lua" "$export_dir" "$merge_scratch" \
	"$export_dir/tools/wp40/fixtures/t2_census" --records "$scratch/free-range.tsv"
# A shard is provenance-bearing and a free record set is not; reading either as
# the other would let a KAT artifact claim a commit it never had.
expect_failure "a shard merged as a free record set" \
	"must be verified as a shard" \
	"${WP40_LUA_BIN:-/usr/bin/luajit}" \
	"$export_dir/tools/wp40/t2_census_merge.lua" "$export_dir" "$merge_scratch" \
	"$scratch/merge-out" --records "$scratch/gate-shard-for-merge.tsv"
expect_failure "a full-W merge with no shards on disk" "missing file" \
	"${WP40_LUA_BIN:-/usr/bin/luajit}" \
	"$export_dir/tools/wp40/t2_census_merge.lua" "$export_dir" "$merge_scratch" \
	"$scratch/merge-out" --full-w
# The positive that stops the refusals above from passing vacuously: the same
# free record set the range gate just produced merges cleanly, and its five
# artifacts and manifest appear.
"${WP40_LUA_BIN:-/usr/bin/luajit}" \
	"$export_dir/tools/wp40/t2_census_merge.lua" "$export_dir" "$merge_scratch" \
	"$scratch/merge-out" --records "$scratch/free-range.tsv" >/dev/null
checks=$((checks + 1))
for artifact in census-occupied-classes-v1.tsv census-vacuous-branches-v1.tsv \
		census-scan4-seed-set-v1.tsv census-prefilter-discharge-v1.tsv \
		census-histograms-v1.tsv census-manifest-v1.tsv; do
	[[ -s "$scratch/merge-out/$artifact" ]] ||
		fail "the merge wrote no $artifact"
	checks=$((checks + 1))
done
grep -q '^summary	declared=' "$scratch/merge-out/census-vacuous-branches-v1.tsv" ||
	fail "the vacuous-branch artifact carries no coverage summary"
grep -q 'sites_covered=137 of 153' "$scratch/merge-out/census-manifest-v1.tsv" ||
	fail "the manifest does not report the open Scan-3b sites"
grep -q 'pairs_order_probe_unsorted=true' \
	"$scratch/merge-out/census-manifest-v1.tsv" ||
	fail "the pairs() divergence probe reported a sorted iteration order, which \
would make the invariance half of the section 5 test vacuous"
checks=$((checks + 3))
expect_failure "a merge over an output directory it already wrote" \
	"already exists" \
	"${WP40_LUA_BIN:-/usr/bin/luajit}" \
	"$export_dir/tools/wp40/t2_census_merge.lua" "$export_dir" "$merge_scratch" \
	"$scratch/merge-out" --records "$scratch/free-range.tsv"
rm -rf -- "$merge_scratch"

echo "WP40 T2 census gate proofs passed: $checks launcher-level checks"
