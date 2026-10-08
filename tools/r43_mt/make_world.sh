#!/usr/bin/env bash
# Round 43 lane MT: builds the engine-written test world of the migration
# tool's tests (tools/r43_mt/world/). Two runs of tools/luanti_headless.sh on
# one isolated run directory, both pointed at a world folder of their own
# (`--world`, the engine's last one wins) whose world.mt this script writes:
# SQLite map, auth and mod storage and the legacy `files` player backend.
# (The launcher's own world.mt names no mod_storage_backend, which the engine
# reads as `files`, a backend the tool refuses.)
#   run 1  boots the game with the probe tools/r43_mt/grug_probe_r43_mt: the
#          game's mods and the probe write mod storage, the probe creates auth
#          entries and writes two player files, then shuts the server down;
#   run 2  `--migrate-players sqlite3`: the engine reads the player files and
#          writes players.sqlite (and sets player_backend in world.mt).
# Copies world.mt and the three SQLite databases (not the map) to OUT_DIR and
# removes the run directory.
#
# Usage: tools/r43_mt/make_world.sh OUT_DIR
#   Start it through the round's process queue (one slot).
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
out="${1:?usage: make_world.sh OUT_DIR}"
root="$(mktemp -d /tmp/grudgelands-headless.XXXXXX)"
cleanup() {
	if [[ "$root" == /tmp/grudgelands-headless.?* && -d "$root" ]]; then
		rm -rf "$root"
	fi
}
trap cleanup EXIT
world="$root/w43"
mkdir -p "$world"
printf '%s\n' 'gameid = grudgelands' 'world_name = r43_mt' 'backend = sqlite3' \
	'player_backend = files' 'auth_backend = sqlite3' 'mod_storage_backend = sqlite3' \
	>"$world/world.mt"

set +e
ROOT="$root" PROBE="$here/grug_probe_r43_mt" SEED=42 \
	"$repo/tools/luanti_headless.sh" 240 --world "$world" >"$root/run1.txt" 2>&1
run1=$?
set -e
cat "$root/run1.txt"
grep -q 'RESULT PASS' "$world/r43_mt_probe.txt" 2>/dev/null || {
	echo "make_world: the probe did not finish (run 1 status $run1)"
	grep -h 'ERROR\|r43_mt_probe' "$root"/server*.log | head -20 || true
	exit 1
}

# No "listening" line in a migration run: the launcher reports FAIL; the
# engine's own lines decide.
set +e
ROOT="$root" "$repo/tools/luanti_headless.sh" 60 --world "$world" \
	--migrate-players sqlite3 >"$root/run2.txt" 2>&1
set -e
grep -h 'Successfully migrated\|world.mt updated\|ERROR' "$root"/server*.log "$root"/server*.console.log || true
grep -q 'Successfully migrated 2 players' "$root"/server*.log "$root"/server*.console.log || {
	echo "make_world: the player migration failed"; cat "$root/run2.txt"; exit 1; }

mkdir -p "$out"
cp "$world/world.mt" "$world/players.sqlite" "$world/auth.sqlite" \
	"$world/mod_storage.sqlite" "$out/"
ls -l "$out"
echo "make_world: PASS"
