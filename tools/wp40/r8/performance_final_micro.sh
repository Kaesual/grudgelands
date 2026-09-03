#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
receipt="${1:?durable receipt path required}"
export WP40_MICRO_ROSTER="$repo/tools/wp40/r8/performance_micro_inputs.txt"
export WP40_MICRO_CHANGED_ROSTER="$repo/tools/wp40/r8/performance_changed_production_lua.txt"
export WP40_MICRO_CLI="$repo/tools/wp40/r8/performance_micro_kat_cli.lua"
export WP40_MICRO_INPUT_POPULATION=111
export WP40_MICRO_CHANGED_POPULATION=15
export WP40_MICRO_ARTIFACT_STEM=wp40-r8-performance
export WP40_MICRO_RECEIPT_SCHEMA=grug_wp40_r8_performance_micro_kat_receipt_v1
export WP40_MICRO_PASS_LABEL="WP40 R8 performance final micro"
exec bash "$repo/tools/wp40/r7/final_micro.sh" "$repo" "$receipt"
