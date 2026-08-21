#!/usr/bin/env bash
# WP40 T5-0 engine-seam probe -- digest helpers (contract 13.2).
#
# Canonicalization is the in-tree template of
# tools/wp40/dungeon_probe/digest_lib.sh:27-34 (payload) and :50-56 (manifest),
# reused rather than reinvented: labelled `key=value` lines with a versioned
# `schema=` first line, piped through `sha256sum | awk '{print $1}'`.
#
# A `sha256sum` OUTPUT line is never digested.  Such a line embeds the path it
# was computed from, so the digest would change when identical bytes move; that
# is the named anti-pattern at tools/wp40/capture_t0_baseline.sh:63-68 and this
# package does not copy it.  Every file contributes only its content digest,
# under a fixed logical label that is independent of where the file lives.
#
# Every function takes all of its inputs as arguments and reads no global, so
# selftest.sh can call them directly against a throwaway fixture.
#
# Sourced, never executed: no `set -euo pipefail` here, exactly as the dungeon
# probe's library does it -- the sourcing runner owns the shell options.

# sha256 over a file's CONTENT only (never its name or path).
wp40_t5_sha256_file_content() {
	if [[ "$#" -ne 1 ]]; then
		echo "usage: wp40_t5_sha256_file_content FILE" >&2
		return 2
	fi
	sha256sum -- "$1" | awk '{print $1}'
}

# sha256 over a literal string, with no trailing newline appended.
wp40_t5_sha256_text() {
	if [[ "$#" -ne 1 ]]; then
		echo "usage: wp40_t5_sha256_text TEXT" >&2
		return 2
	fi
	printf '%s' "$1" | sha256sum | awk '{print $1}'
}

# Payload digest over the four injected files, in the fixed order of the
# coordinator's interface pin: mod.conf, init.lua, mapgen.lua, vm_proxy.lua.
#
# The four paths are passed explicitly because the working tree keeps them in
# driver/ and payload/ while the injected mod directory is flat; the labels are
# the INJECTED names in both cases, which is what makes the digest identical
# across the two layouts and therefore usable as the injection proof of 13.1.
wp40_t5_probe_payload_digest() {
	if [[ "$#" -ne 4 ]]; then
		echo "usage: wp40_t5_probe_payload_digest MOD_CONF INIT_LUA MAPGEN_LUA VM_PROXY_LUA" >&2
		return 2
	fi
	local paths=("$1" "$2" "$3" "$4")
	local names=(mod.conf init.lua mapgen.lua vm_proxy.lua)
	local index
	local content_digest
	{
		printf 'schema=wp40-t5-probe-payload-v1\n'
		for index in 0 1 2 3; do
			content_digest="$(wp40_t5_sha256_file_content "${paths[$index]}")"
			printf 'file_name=%s\n' "${names[$index]}"
			printf 'file_content_sha256=%s\n' "$content_digest"
		done
	} | sha256sum | awk '{print $1}'
}

# Same digest over a flattened directory -- the injected
# <archive>/mods/grug_wp40_t5_probe/ layout.
wp40_t5_probe_payload_digest_dir() {
	if [[ "$#" -ne 1 ]]; then
		echo "usage: wp40_t5_probe_payload_digest_dir DIRECTORY" >&2
		return 2
	fi
	local directory="$1"
	wp40_t5_probe_payload_digest \
		"$directory/mod.conf" \
		"$directory/init.lua" \
		"$directory/mapgen.lua" \
		"$directory/vm_proxy.lua"
}

# The T5-0 manifest digest (13.2).  It binds, in this order:
#   * the archive commit SHA,
#   * the payload digest,
#   * the engine-version-regex digest,
#   * the stage-1 log-shape-regex digest,
#   * the configuration bytes of ALL FOUR runs, each labelled with its run id,
#   * the coordinate-set literal,
#   * the case write-extent literals.
#
# The log-shape regex is bound because 12.5 stage 1 requires it: the non-marker
# garbage gate is "an explicit committed regex whose bytes are bound into the
# manifest digest".  Widening that regex would silently re-admit ungated log
# content, so a run set produced under a widened regex must not share a digest
# -- and therefore not a result directory -- with one produced under the
# committed one.  It is the LAST positional parameter, appended rather than
# inserted, so parameters 1..9 keep the meaning they already had.
#
# The four configurations are passed in the 10.7 matrix order
# (A1-O1, A1-O2, B-O1, B-O2), which is deliberately NOT the execution order --
# 14.3 makes B/O1 the first capture, but the digest names the experiment, not
# the schedule, so it must not change when the schedule does.
#
# The two literal blocks are bound through their own text digests rather than
# inline so the manifest text stays short and each literal stays independently
# auditable; they are still bound, so a changed coordinate changes the digest.
wp40_t5_probe_manifest_digest() {
	if [[ "$#" -ne 10 ]]; then
		echo "usage: wp40_t5_probe_manifest_digest ARCHIVE_SHA PAYLOAD_DIGEST ENGINE_REGEX COORDINATE_SET_TEXT CASE_WRITE_EXTENT_TEXT CONFIG_A1_O1 CONFIG_A1_O2 CONFIG_B_O1 CONFIG_B_O2 LOG_SHAPE_REGEX" >&2
		echo "wp40_t5_probe_manifest_digest: LOG_SHAPE_REGEX is the tenth and last parameter (contract 12.5 stage 1); obtain its bytes from verify_log.sh --print-log-shape-regex" >&2
		return 2
	fi
	local game_archive_commit="$1"
	local probe_payload_digest="$2"
	local engine_version_regex="$3"
	local coordinate_set_text="$4"
	local case_write_extent_text="$5"
	local configs=("$6" "$7" "$8" "$9")
	local log_shape_regex="${10}"
	local run_ids=(A1-O1 A1-O2 B-O1 B-O2)
	local engine_regex_digest
	local log_shape_regex_digest
	local coordinate_set_digest
	local case_write_extent_digest
	local config_content_digest
	local index
	engine_regex_digest="$(wp40_t5_sha256_text "$engine_version_regex")"
	log_shape_regex_digest="$(wp40_t5_sha256_text "$log_shape_regex")"
	coordinate_set_digest="$(wp40_t5_sha256_text "$coordinate_set_text")"
	case_write_extent_digest="$(wp40_t5_sha256_text "$case_write_extent_text")"
	{
		printf 'schema=wp40-t5-probe-manifest-v1\n'
		printf 'game_archive_commit_sha1=%s\n' "$game_archive_commit"
		printf 'probe_payload_sha256=%s\n' "$probe_payload_digest"
		printf 'engine_version_regex_sha256=%s\n' "$engine_regex_digest"
		printf 'log_shape_regex_sha256=%s\n' "$log_shape_regex_digest"
		for index in 0 1 2 3; do
			config_content_digest="$(wp40_t5_sha256_file_content "${configs[$index]}")"
			printf 'run_id=%s\n' "${run_ids[$index]}"
			printf 'config_content_sha256=%s\n' "$config_content_digest"
		done
		printf 'coordinate_set_sha256=%s\n' "$coordinate_set_digest"
		printf 'case_write_extent_sha256=%s\n' "$case_write_extent_digest"
	} | sha256sum | awk '{print $1}'
}
