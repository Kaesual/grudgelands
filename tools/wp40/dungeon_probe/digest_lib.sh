#!/usr/bin/env bash

wp40_sha256_file_content() {
	if [[ "$#" -ne 1 ]]; then
		echo "usage: wp40_sha256_file_content FILE" >&2
		return 2
	fi
	sha256sum -- "$1" | awk '{print $1}'
}

wp40_sha256_text() {
	if [[ "$#" -ne 1 ]]; then
		echo "usage: wp40_sha256_text TEXT" >&2
		return 2
	fi
	printf '%s' "$1" | sha256sum | awk '{print $1}'
}

wp40_probe_payload_digest() {
	if [[ "$#" -ne 1 ]]; then
		echo "usage: wp40_probe_payload_digest DIRECTORY" >&2
		return 2
	fi
	local directory="$1"
	local name
	local content_digest
	{
		printf 'schema=wp40-dungeon-probe-payload-v1\n'
		for name in mod.conf init.lua mapgen.lua; do
			content_digest="$(wp40_sha256_file_content "$directory/$name")"
			printf 'file_name=%s\n' "$name"
			printf 'file_content_sha256=%s\n' "$content_digest"
		done
	} | sha256sum | awk '{print $1}'
}

wp40_manifest_digest() {
	if [[ "$#" -ne 4 ]]; then
		echo "usage: wp40_manifest_digest GAME_COMMIT PROBE_DIGEST ENGINE_REGEX CONFIG" >&2
		return 2
	fi
	local game_archive_commit="$1"
	local probe_payload_digest="$2"
	local engine_version_regex="$3"
	local config_path="$4"
	local engine_regex_digest
	local config_content_digest
	engine_regex_digest="$(wp40_sha256_text "$engine_version_regex")"
	config_content_digest="$(wp40_sha256_file_content "$config_path")"
	{
		printf 'schema=wp40-dungeon-probe-manifest-v3\n'
		printf 'game_archive_commit_sha1=%s\n' "$game_archive_commit"
		printf 'probe_payload_sha256=%s\n' "$probe_payload_digest"
		printf 'engine_version_regex_sha256=%s\n' "$engine_regex_digest"
		printf 'config_content_sha256=%s\n' "$config_content_digest"
	} | sha256sum | awk '{print $1}'
}
