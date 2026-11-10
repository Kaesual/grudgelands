#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
luajit "$root/tools/r75_displays/portable_test.lua" "$root"
python3 "$root/tools/r75_displays/test_pack.py" "$root"
