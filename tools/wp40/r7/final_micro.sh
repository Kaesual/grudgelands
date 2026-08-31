#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

repo="${1:?repository root required}"
receipt="${2:?durable receipt path required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
lua_jit="${WP40_LUA_BIN:-/usr/bin/luajit}"
lua_puc="${WP40_PUC51_BIN:-$repo/tools/bin/lua51}"
roster="$script_dir/micro_inputs.txt"
changed_roster="$script_dir/changed_production_lua.txt"
cli="$script_dir/micro_kat_cli.lua"
durable_dir="$(dirname -- "$receipt")"
canonical_output="$durable_dir/wp40-r7-micro-kat-output.tsv"
luajit_log="$durable_dir/wp40-r7-micro-kat-luajit.log"
puc51_log="$durable_dir/wp40-r7-micro-kat-puc51.log"

[[ -x "$lua_jit" && -x "$lua_puc" && -f "$roster" &&
	-f "$changed_roster" && -f "$cli" && -d "$durable_dir" &&
	-w "$durable_dir" ]] || {
	echo "WP40 R7 final micro: interpreter/input/durable directory differs" >&2
	exit 1
}
for durable in "$receipt" "$canonical_output" "$luajit_log" "$puc51_log"; do
	[[ ! -e "$durable" ]] || {
		echo "WP40 R7 final micro: durable target already exists: $durable" >&2
		exit 1
	}
done
LC_ALL=C sort -c -u "$roster" && LC_ALL=C sort -c -u "$changed_roster" || {
	echo "WP40 R7 final micro: input roster is not uniquely ordered" >&2
	exit 1
}
scratch="$(mktemp -d /tmp/grudgelands-wp40-r7-micro.XXXXXXXX)"
partial=""
cleanup() {
	local status=$?
	case "$scratch" in /tmp/grudgelands-wp40-r7-micro.*) rm -rf -- "$scratch" ;; esac
	case "$partial" in "$durable_dir"/.wp40-r7-micro-receipt.partial.*)
		rm -f -- "$partial" ;;
	esac
	return "$status"
}
trap cleanup EXIT

mapfile -t inputs < <(cat "$roster" "$changed_roster" | awk 'NF' | sort -u)
[[ "${#inputs[@]}" -gt 65 ]] || {
	echo "WP40 R7 final micro: input population is incomplete" >&2
	exit 1
}
write_input_rows() {
	local target="$1" relative sha
	for relative in "${inputs[@]}"; do
		[[ "$relative" != /* && "$relative" != *'..'* &&
			-f "$repo/$relative" ]] || {
			echo "WP40 R7 final micro: unsafe or absent input: $relative" >&2
			return 1
		}
		sha="$(sha256sum "$repo/$relative" | awk '{print $1}')"
		printf '%s\t%s\n' "$relative" "$sha"
	done >"$target"
}
input_rows="$scratch/input-rows-pre.tsv"
write_input_rows "$input_rows"
input_set_sha="$(sha256sum "$input_rows" | awk '{print $1}')"
changed_roster_sha="$(sha256sum "$changed_roster" | awk '{print $1}')"
luajit_binary_sha="$(sha256sum "$lua_jit" | awk '{print $1}')"
puc51_binary_sha="$(sha256sum "$lua_puc" | awk '{print $1}')"

visible_lua="$(ps -eo comm= | awk '$1 == "luajit" || $1 == "lua51" {count++}
	END {print count + 0}')"
[[ "$visible_lua" -le 5 ]] || {
	echo "WP40 R7 final micro: workstation-wide seven-process cap is exhausted" >&2
	exit 1
}
chrt --idle 0 ionice -c3 "$lua_jit" "$cli" "$repo" "$scratch/luajit.tsv" \
	luajit >"$scratch/luajit.log" 2>&1 &
lj_pid=$!
chrt --idle 0 ionice -c3 "$lua_puc" "$cli" "$repo" "$scratch/puc51.tsv" \
	puc51 >"$scratch/puc51.log" 2>&1 &
puc_pid=$!
lj_status=0 puc_status=0
wait "$lj_pid" || lj_status=$?
wait "$puc_pid" || puc_status=$?
[[ "$lj_status" -eq 0 && "$puc_status" -eq 0 ]] || {
	cat "$scratch/luajit.log" "$scratch/puc51.log" >&2
	exit 1
}
post_input_rows="$scratch/input-rows-post.tsv"
write_input_rows "$post_input_rows"
cmp -s "$input_rows" "$post_input_rows" &&
	[[ "$(sha256sum "$lua_jit" | awk '{print $1}')" == "$luajit_binary_sha" &&
	"$(sha256sum "$lua_puc" | awk '{print $1}')" == "$puc51_binary_sha" ]] || {
	echo "WP40 R7 final micro: input or interpreter bytes changed during run" >&2
	exit 1
}
cmp -s "$scratch/luajit.tsv" "$scratch/puc51.tsv" || {
	echo "WP40 R7 final micro: LuaJIT/PUC canonical bytes differ" >&2
	exit 1
}
internal_sha="$(awk -F '\t' '$1 == "output_sha256" && NF == 2 {
	count++; value=$2} END {if (count == 1) print value}' "$scratch/luajit.tsv")"
[[ "$internal_sha" =~ ^[0-9a-f]{64}$ ]] || {
	echo "WP40 R7 final micro: canonical internal digest row differs" >&2
	exit 1
}
printf 'WP40 R7 final micro PASS interpreter=luajit output_sha256=%s\n' \
	"$internal_sha" >"$scratch/expected-luajit.log"
printf 'WP40 R7 final micro PASS interpreter=puc51 output_sha256=%s\n' \
	"$internal_sha" >"$scratch/expected-puc51.log"
cmp -s "$scratch/expected-luajit.log" "$scratch/luajit.log" &&
	cmp -s "$scratch/expected-puc51.log" "$scratch/puc51.log" || {
	echo "WP40 R7 final micro: interpreter PASS log differs" >&2
	exit 1
}

executed_rows="$scratch/executed-modules.txt"
awk -F '\t' '$1 == "executed_module" && NF == 2 {print $2}' \
	"$scratch/luajit.tsv" | sort >"$executed_rows"
[[ "$(awk -F '\t' '$1 == "source/executed_module_count" && $2 == "65" {
	count++} END {print count + 0}' "$scratch/luajit.tsv")" -eq 1 &&
	"$(awk -F '\t' -v sha="$changed_roster_sha" '$1 == "source/executed_module_roster_sha256" && $2 == sha {count++}
	END {print count + 0}' "$scratch/luajit.tsv")" -eq 1 ]] &&
	cmp -s "$executed_rows" "$changed_roster" || {
	echo "WP40 R7 final micro: executed-module roster differs" >&2
	exit 1
}

output_sha="$(sha256sum "$scratch/luajit.tsv" | awk '{print $1}')"
output_bytes="$(wc -c <"$scratch/luajit.tsv" | tr -d '[:space:]')"
luajit_log_sha="$(sha256sum "$scratch/luajit.log" | awk '{print $1}')"
luajit_log_bytes="$(wc -c <"$scratch/luajit.log" | tr -d '[:space:]')"
puc51_log_sha="$(sha256sum "$scratch/puc51.log" | awk '{print $1}')"
puc51_log_bytes="$(wc -c <"$scratch/puc51.log" | tr -d '[:space:]')"
partial="$(mktemp "$durable_dir/.wp40-r7-micro-receipt.partial.XXXXXXXX")"
{
	printf 'schema\tgrug_wp40_r7_micro_kat_receipt_v1\n'
	printf 'input_set_sha256\t%s\n' "$input_set_sha"
	printf 'input_population\t%s\n' "${#inputs[@]}"
	printf 'executed_module_population\t65\n'
	printf 'executed_module_roster_sha256\t%s\n' "$changed_roster_sha"
	printf 'luajit_binary_sha256\t%s\n' "$luajit_binary_sha"
	printf 'puc51_binary_sha256\t%s\n' "$puc51_binary_sha"
	printf 'luajit_output_sha256\t%s\n' "$output_sha"
	printf 'puc51_output_sha256\t%s\n' "$output_sha"
	printf 'canonical_output_filename\twp40-r7-micro-kat-output.tsv\n'
	printf 'canonical_output_sha256\t%s\n' "$output_sha"
	printf 'canonical_output_bytes\t%s\n' "$output_bytes"
	printf 'luajit_log_filename\twp40-r7-micro-kat-luajit.log\n'
	printf 'luajit_log_sha256\t%s\n' "$luajit_log_sha"
	printf 'luajit_log_bytes\t%s\n' "$luajit_log_bytes"
	printf 'luajit_exit_status\t0\n'
	printf 'puc51_log_filename\twp40-r7-micro-kat-puc51.log\n'
	printf 'puc51_log_sha256\t%s\n' "$puc51_log_sha"
	printf 'puc51_log_bytes\t%s\n' "$puc51_log_bytes"
	printf 'puc51_exit_status\t0\n'
	printf 'byte_identical\ttrue\n'
	awk -F '\t' '{print "input\t" $1 "\t" $2}' "$input_rows"
} >"$partial"

promote_no_overwrite() {
	local source="$1" target="$2" label="$3" staged
	staged="$(mktemp "$durable_dir/.wp40-r7-micro-$label.partial.XXXXXXXX")"
	cp -- "$source" "$staged"
	ln -- "$staged" "$target" || {
		rm -f -- "$staged"
		echo "WP40 R7 final micro: durable target appeared: $target" >&2
		return 1
	}
	rm -f -- "$staged"
}
promote_no_overwrite "$scratch/luajit.tsv" "$canonical_output" output
promote_no_overwrite "$scratch/luajit.log" "$luajit_log" luajit-log
promote_no_overwrite "$scratch/puc51.log" "$puc51_log" puc51-log
ln -- "$partial" "$receipt" || {
	echo "WP40 R7 final micro: durable receipt target appeared: $receipt" >&2
	exit 1
}
rm -f -- "$partial"
printf 'WP40 R7 final micro PASS receipt_sha256=%s output_sha256=%s\n' \
	"$(sha256sum "$receipt" | awk '{print $1}')" "$output_sha"
