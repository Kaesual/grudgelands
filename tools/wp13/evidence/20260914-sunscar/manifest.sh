#!/usr/bin/env bash
# Hash every file of this evidence directory except the manifest itself.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
dir=tools/wp13/evidence/20260914-sunscar
find "$dir" -type f ! -name files.sha256 -print0 |
	sort -z | xargs -0 sha256sum >"$dir/files.sha256"
wc -l <"$dir/files.sha256"
