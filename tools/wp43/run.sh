#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$script_dir/../.." && pwd)"

"$repo/tools/bin/lua51" "$script_dir/materials_test.lua" "$repo"
"$script_dir/source_audit.sh" "$repo"
