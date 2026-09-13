#!/usr/bin/env bash
set -euo pipefail
exec flatpak run --filesystem=/tmp --env="LUANTI_USER_PATH=${LUANTI_USER_PATH:?}" --command=luanti org.luanti.luanti "$@"
