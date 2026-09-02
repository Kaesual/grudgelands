#!/usr/bin/env bash
set -euo pipefail

# Channel-aware PCC worker-pair gate. The worker's record and stdout are
# canonical bytes; stderr is runtime telemetry and is retained raw, validated
# exactly, then normalized only by removing its anchored wall/cpu suffix.

fail() {
	echo "WP40 PCC worker gate: $1" >&2
	return 1
}

file_sha() {
	sha256sum "$1" | awk '{print $1}'
}

validate_record() {
	local path="$1" label="$2" prefix="$3"
	[[ -s "$path" ]] || { fail "$label record is empty"; return 1; }
	local trailer expected actual trailer_pattern
	trailer="$(tail -n 1 "$path")"
	trailer_pattern=$'^digest\tsha256=([0-9a-f]{64})$'
	if [[ ! "$trailer" =~ $trailer_pattern ]]; then
		fail "$label record has no canonical trailing digest"
		return 1
	fi
	expected="${BASH_REMATCH[1]}"
	sed '$d' "$path" >"$prefix"
	actual="$(file_sha "$prefix")"
	if [[ "$actual" != "$expected" ]]; then
		fail "$label record internal digest differs: expected $expected actual $actual"
		return 1
	fi
	printf '%s' "$expected"
}

validate_telemetry() {
	local path="$1" label="$2" normalized="$3"
	local -a lines=()
	mapfile -t lines <"$path"
	if (( ${#lines[@]} != 2 )); then
		fail "$label telemetry has ${#lines[@]} lines, expected exactly 2"
		return 1
	fi
	local suffix=' wall=[0-9]+s cpu=[0-9]+\.[0-9]s$'
	if [[ ! "${lines[0]}" =~ ^census\ seed\ 2147483648\ done\ 1/2${suffix} ]]; then
		fail "$label telemetry line 1 is malformed or reordered"
		return 1
	fi
	if [[ ! "${lines[1]}" =~ ^census\ seed\ 16178445837170081103\ done\ 2/2${suffix} ]]; then
		fail "$label telemetry line 2 is malformed or reordered"
		return 1
	fi
	sed -E 's/ wall=[0-9]+s cpu=[0-9]+\.[0-9]s$//' "$path" >"$normalized"
}

gate_pair() (
	local jit_stdout="$1" jit_stderr="$2" jit_status="$3" jit_record="$4"
	local puc_stdout="$5" puc_stderr="$6" puc_status="$7" puc_record="$8"
	local out_dir="$9"
	[[ "$jit_status" =~ ^[0-9]+$ && "$puc_status" =~ ^[0-9]+$ ]] || {
		fail "exit status is not an unsigned integer"; return 1;
	}
	if (( jit_status != puc_status )); then
		fail "exit statuses differ (LuaJIT $jit_status, PUC $puc_status)"
		return 1
	fi
	if (( jit_status != 0 )); then
		fail "both interpreters failed with status $jit_status"
		return 1
	fi
	if ! cmp -s -- "$jit_stdout" "$puc_stdout"; then
		fail "canonical stdout differs"
		return 1
	fi
	if ! cmp -s -- "$jit_record" "$puc_record"; then
		fail "complete record bytes differ"
		return 1
	fi
	local scratch
	scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-puc-worker-gate.XXXXXXXX)"
	trap 'rm -rf "$scratch"' EXIT
	local jit_internal puc_internal jit_external puc_external
	jit_internal="$(validate_record "$jit_record" LuaJIT "$scratch/jit-prefix.tsv")" || return 1
	puc_internal="$(validate_record "$puc_record" PUC "$scratch/puc-prefix.tsv")" || return 1
	jit_external="$(file_sha "$jit_record")"
	puc_external="$(file_sha "$puc_record")"
	if [[ "$jit_internal" != "$puc_internal" || "$jit_external" != "$puc_external" ]]; then
		fail "record digest identity differs"
		return 1
	fi
	local -a stdout_lines=()
	local stdout_digest
	mapfile -t stdout_lines <"$jit_stdout"
	if (( ${#stdout_lines[@]} != 1 )) ||
			[[ ! "${stdout_lines[0]}" =~ ^census\ scan\ rows\ [0-9]+\ digest\ ([0-9a-f]{64})$ ]] ||
			[[ "${BASH_REMATCH[1]}" != "$jit_internal" ]]; then
		fail "canonical stdout does not bind the record's internal digest"
		return 1
	fi
	stdout_digest="$(file_sha "$jit_stdout")"
	validate_telemetry "$jit_stderr" LuaJIT "$scratch/jit-normalized.log" || return 1
	validate_telemetry "$puc_stderr" PUC "$scratch/puc-normalized.log" || return 1
	if ! cmp -s -- "$scratch/jit-normalized.log" "$scratch/puc-normalized.log"; then
		fail "normalized telemetry differs"
		return 1
	fi
	[[ ! -e "$out_dir" ]] || { fail "output directory already exists"; return 1; }
	mkdir -p "$out_dir"
	cp -- "$scratch/jit-normalized.log" "$out_dir/worker-pair-telemetry-v1.txt"
	printf 'worker_stdout_sha256\t%s\nworker_record_sha256\t%s\nworker_internal_digest\t%s\nworker_telemetry_normalized_sha256\t%s\n' \
		"$stdout_digest" "$jit_external" "$jit_internal" \
		"$(file_sha "$scratch/jit-normalized.log")" \
		>"$out_dir/worker-pair-gate-v1.tsv"
	rm -rf -- "$scratch"
)

self_test() (
	local scratch
	scratch="$(mktemp -d /tmp/grudgelands-wp40-t2-puc-worker-selftest.XXXXXXXX)"
	trap 'rm -rf "$scratch"' EXIT
	local prefix='schema\tselftest\nrow\tvalue\n' digest
	printf '%b' "$prefix" >"$scratch/jit-prefix.tsv"
	digest="$(file_sha "$scratch/jit-prefix.tsv")"
	printf '%b' "$prefix" >"$scratch/jit.tsv"
	printf 'digest\tsha256=%s\n' "$digest" >>"$scratch/jit.tsv"
	cp -- "$scratch/jit.tsv" "$scratch/puc.tsv"
	printf 'census scan rows 2 digest %s\n' "$digest" >"$scratch/jit.stdout"
	cp -- "$scratch/jit.stdout" "$scratch/puc.stdout"
	printf 'census seed 2147483648 done 1/2 wall=55s cpu=55.1s\ncensus seed 16178445837170081103 done 2/2 wall=59s cpu=59.0s\n' >"$scratch/jit.stderr"
	printf 'census seed 2147483648 done 1/2 wall=1169s cpu=1167.8s\ncensus seed 16178445837170081103 done 2/2 wall=1167s cpu=1164.5s\n' >"$scratch/puc.stderr"
	gate_pair "$scratch/jit.stdout" "$scratch/jit.stderr" 0 "$scratch/jit.tsv" \
		"$scratch/puc.stdout" "$scratch/puc.stderr" 0 "$scratch/puc.tsv" \
		"$scratch/positive" || { fail "positive self-test failed"; return 1; }

	local tests=0
	expect_reject() {
		local label="$1" jit_status="$2" puc_status="$3"
		if gate_pair "$scratch/jit.stdout" "$scratch/jit.stderr" "$jit_status" \
				"$scratch/jit.tsv" "$scratch/puc.stdout" "$scratch/puc.stderr" \
				"$puc_status" "$scratch/puc.tsv" "$scratch/reject-$label" \
				>/dev/null 2>&1; then
			fail "$label negative self-test passed"
			return 1
		fi
		tests=$((tests + 1))
	}
	expect_reject equal-nonzero 7 7
	expect_reject mismatched-exit 0 9

	printf 'drift\n' >>"$scratch/puc.stdout"
	expect_reject stdout-drift 0 0
	cp -- "$scratch/jit.stdout" "$scratch/puc.stdout"
	printf 'row\tdrift\n' >>"$scratch/puc.tsv"
	expect_reject record-drift 0 0
	cp -- "$scratch/jit.tsv" "$scratch/puc.tsv"

	local good_puc_stderr="$scratch/puc-good.stderr"
	cp -- "$scratch/puc.stderr" "$good_puc_stderr"
	printf 'extra\n' >>"$scratch/puc.stderr"
	expect_reject telemetry-extra 0 0
	cp -- "$good_puc_stderr" "$scratch/puc.stderr"
	printf 'census seed 2147483648 done 1/2 wall=bad cpu=1.0s\ncensus seed 16178445837170081103 done 2/2 wall=1s cpu=1.0s\n' >"$scratch/puc.stderr"
	expect_reject telemetry-malformed 0 0
	tac "$good_puc_stderr" >"$scratch/puc.stderr"
	expect_reject telemetry-reordered 0 0
	cp -- "$good_puc_stderr" "$scratch/puc.stderr"

	# The record bytes are equal here, so corrupt both together: the independent
	# internal digest gate must still reject them.
	printf 'digest\tsha256=%064d\n' 0 >"$scratch/bad-trailer"
	sed '$d' "$scratch/jit.tsv" >"$scratch/both-bad.tsv"
	cat "$scratch/bad-trailer" >>"$scratch/both-bad.tsv"
	if gate_pair "$scratch/jit.stdout" "$scratch/jit.stderr" 0 \
			"$scratch/both-bad.tsv" "$scratch/puc.stdout" "$scratch/puc.stderr" 0 \
			"$scratch/both-bad.tsv" "$scratch/reject-internal" >/dev/null 2>&1; then
		fail "internal-digest negative self-test passed"
		return 1
	fi
	tests=$((tests + 1))
	printf 'WP40 PCC worker gate self-test passed: positive=1 negative=%d\n' "$tests"
	rm -rf -- "$scratch"
)

if [[ "${1:-}" == --self-test ]]; then
	[[ $# -eq 1 ]] || { echo "usage: $0 --self-test" >&2; exit 2; }
	self_test
	exit 0
fi
if (( $# != 9 )); then
	echo "usage: $0 JIT_STDOUT JIT_STDERR JIT_STATUS JIT_RECORD PUC_STDOUT PUC_STDERR PUC_STATUS PUC_RECORD NEW_OUTPUT_DIR" >&2
	exit 2
fi
gate_pair "$@"
