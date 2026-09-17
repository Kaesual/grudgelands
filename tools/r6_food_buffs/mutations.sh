#!/usr/bin/env bash
# One focused mutation proof for FU6's public mana-restoration path. The source
# file is restored from a byte copy, so running this against uncommitted work
# cannot discard the caller's changes.
set -uo pipefail
export LC_ALL=C

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$repo"

kat='io.write(dofile("tools/r6_food_buffs/kat.lua").run("."))'
run_kat() {
	luajit -e "$kat" 2>&1 |
		grep -E 'r6_(food_mapping|mana_restore|food_buffs_result)|^(PASS|FAIL)'
}

echo "== BASELINE =="
run_kat
echo

file="mods/PLAYER/grug_abilities/init.lua"
backup="$(mktemp /tmp/grug-r6-mana-mutation.XXXXXX)"
cp -- "$file" "$backup"
restore_source() {
	cp -- "$backup" "$file"
	rm -f -- "$backup"
}
trap restore_source EXIT

python3 - "$file" <<'PYTHON'
import sys

path = sys.argv[1]
old = "\tlocal after = math.min(maximum,\n\t\tbefore + math.max(0, tonumber(amount) or 0))"
new = "\tlocal after = before -- mutation: restoration is disabled"
with open(path) as source:
    text = source.read()
assert text.count(old) == 1, "mana mutation anchor hit %d times" % text.count(old)
with open(path, "w") as target:
    target.write(text.replace(old, new))
PYTHON

echo "== MUTATION: restore_mana no longer restores =="
run_kat

restore_source
trap - EXIT
