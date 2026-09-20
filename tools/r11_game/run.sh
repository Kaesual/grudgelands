#!/usr/bin/env bash
set -euo pipefail
root="${1:?repository root required}"
luajit "$root/tools/spawn_probe/despawn_kat.lua" "$root"
luajit "$root/tools/r11_game/boss_runner.lua" "$root"
luajit "$root/tools/r11_game/mount_runner.lua" "$root"
luajit "$root/tools/r11_game/display_kat.lua" "$root"
