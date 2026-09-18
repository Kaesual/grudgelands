#!/usr/bin/env bash
# Food v2 superseded the Round 6 production contract and mutation set.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
exec "$root/tools/r7_food/mutations.sh" "$@"
