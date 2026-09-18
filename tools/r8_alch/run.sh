#!/usr/bin/env bash
set -euo pipefail

ROOT=${1:?absolute repository root required}
case "$ROOT" in /*) ;; *) echo "absolute repository root required" >&2; exit 2;; esac

for lua in "$ROOT/tools/bin/lua51" "$(command -v luajit)"; do
	for kat in alchemy_kat poison_kat stand_kat capital_kat; do
		"$lua" -e "io.write(dofile('$ROOT/tools/r8_alch/$kat.lua')('$ROOT'))"
	done
done
