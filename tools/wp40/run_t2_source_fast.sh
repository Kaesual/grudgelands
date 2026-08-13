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

# LuaJIT with 5.2 compatibility reports successful os.execute as
# true,"exit",0. The shared PUC-5.1 harness intentionally expects numeric 0,
# so normalize only that successful result while preserving all failures.
/usr/bin/env luajit -e '
local execute = os.execute
os.execute = function(...)
	local result, reason, status = execute(...)
	if result == true and reason == "exit" and status == 0 then
		return 0
	end
	return result, reason, status
end
' "$script_dir/t2_source_test.lua" "$repo" "$scratch"
