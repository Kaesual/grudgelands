#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"

if ! command -v luajit >/dev/null 2>&1; then
	echo "WP40 T2 fast runner requires luajit in PATH" >&2
	exit 127
fi

scratch="$(mktemp -d -p /tmp grudgelands-wp40-t2.XXXXXX)"
cleanup() {
	if [[ "$scratch" == /tmp/grudgelands-wp40-t2.* ]]; then
		rm -rf -- "$scratch"
	fi
}
trap cleanup EXIT

/usr/bin/env luajit "$script_dir/t2_source_test.lua" "$repo" "$scratch"
