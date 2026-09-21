#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
exec "${R14_UI_LUA_BIN:-luajit}" tools/r14_ui/ui_kat.lua "$PWD"
