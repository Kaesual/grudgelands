#!/usr/bin/env bash
# Round 50 lane PACCEPT: a map reset of a local test world, done the way the
# hosting platform does it (docs/technical/upgrade-contract.md §1 and §3.5):
#   1. a backup copy of the world folder (the platform's automatic backup);
#   2. this checkout's tool: --check --map-reset, then --world <dir>
#      --map-reset (packs the claims' containers, then the due steps);
#   3. only after its exit 0 with "map_reset": true in the done line: the map
#      emptied (the rows of map.sqlite's blocks table, nothing else: mod
#      storage, players and auth stay);
#   4. grug_reset_world raised above the world's record, in SERVER_CONF.
# Then start the server on the world with that config and join: the packed
# belongings wait in the Claim Stone (plan GUI checklist item 6).
#
# Usage: tools/r50_paccept/reset_like_platform.sh <world dir> [SERVER_CONF]
#   The world must be SQLite throughout (world.mt: the map, players, auth
#   and mod storage) and its server stopped. A world or config inside the
#   personal Luanti folder (~/.var/app/org.luanti.luanti) is refused: copy
#   the world out first. Without SERVER_CONF the script prints the line to
#   put into the server's config instead.
#   Start the server afterwards with, for example:
#     flatpak run --filesystem=<dir> --command=luanti org.luanti.luanti \
#       --server --gameid grudgelands --world <world dir> --config SERVER_CONF
# Exit 0 done; 2 refused, nothing changed; 1 the tool failed after writing
# began: restore the backup (printed) over the world folder.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
say() { printf 'reset_like_platform: %s\n' "$*"; }
refuse() { say "refused: $*" >&2; exit 2; }

[[ $# -ge 1 && $# -le 2 ]] || { echo "usage: $0 <world dir> [SERVER_CONF]" >&2; exit 2; }
personal="$(realpath -m -- "$HOME/.var/app/org.luanti.luanti")"
world="$(realpath -m -- "$1")"
case "$world/" in "$personal"/*) refuse "$world is inside the personal Luanti folder; copy the world out first" ;; esac
[[ -d "$world" ]] || refuse "no such world folder: $1"
conf="${2:-}"
if [[ -n "$conf" ]]; then
	conf="$(realpath -m -- "$conf")"
	case "$conf" in "$personal"/*) refuse "the config $conf is inside the personal Luanti folder" ;; esac
fi
[[ -f "$world/world.mt" ]] || refuse "$world has no world.mt"
[[ -f "$world/map.sqlite" && -f "$world/mod_storage.sqlite" ]] ||
	refuse "$world needs map.sqlite and mod_storage.sqlite"
backend() {  # the world.mt value of $1, $2 when missing
	local value
	value="$(sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\([^[:space:]]*\).*/\1/p" "$world/world.mt" | tail -1)"
	printf '%s' "${value:-$2}"
}
for key in backend player_backend auth_backend mod_storage_backend; do
	value="$(backend "$key" sqlite3)"
	[[ "$value" == sqlite3 ]] || refuse "world.mt $key = $value: this script handles SQLite worlds only"
done
# A running server on this world: its --world argument, absolute or
# relative (compared by the folder's name), on any luanti command line.
set +e
procs="$(pgrep -af luanti)"
pgrep_status=$?
set -e
[[ $pgrep_status -le 1 ]] || refuse "cannot tell whether a Luanti server runs (pgrep exit $pgrep_status)"
name="$(basename -- "$world")"
while IFS= read -r line; do
	[[ -n "$line" ]] || continue
	arg="$(sed -n 's/.*--world[= ]\([^ ]*\).*/\1/p' <<<"$line")"
	if printf '%s\n' "$line" | grep -qF -- "$world" ||
			[[ -n "$arg" && "$(basename -- "$arg")" == "$name" ]]; then
		refuse "a Luanti server seems to run on $world ($line); stop it first"
	fi
done <<<"$procs"
# The config must take the counter after the map is emptied.
if [[ -n "$conf" ]]; then
	if [[ -e "$conf" ]]; then
		[[ -f "$conf" && -w "$conf" ]] || refuse "the config $conf is not a writable file"
	else
		[[ -d "$(dirname -- "$conf")" && -w "$(dirname -- "$conf")" ]] ||
			refuse "cannot create the config $conf"
	fi
fi

# 1. The backup.
# A folder of its own (mktemp): two runs in the same second never share one.
backup="$(mktemp -d -- "$world.backup-$(date +%Y%m%d-%H%M%S)-XXXX")"
chmod --reference="$world" -- "$backup"
cp -a -- "$world/." "$backup/"
say "backup: $backup"

# 2. The tool, from this checkout's root.
cd "$repo"
say "python3 tools/migrate.py --world $world --check --map-reset"
python3 tools/migrate.py --world "$world" --check --map-reset || {
	status=$?
	rm -rf -- "$backup"
	say "the check failed (exit $status); nothing was changed, the backup removed"
	exit 2
}
say "python3 tools/migrate.py --world $world --map-reset"
out="$(mktemp)"
trap 'rm -f "$out"' EXIT
set +e
python3 tools/migrate.py --world "$world" --map-reset | tee "$out"
status=${PIPESTATUS[0]}
set -e
if [[ $status -eq 2 ]]; then
	rm -rf -- "$backup"
	say "the tool refused (exit 2): nothing was written, the map is kept, the backup removed"
	exit 2
elif [[ $status -ne 0 ]]; then
	say "the tool failed after writing began (exit $status): restore the backup:"
	say "  rm -rf '$world' && mv '$backup' '$world'"
	exit 1
fi
if ! python3 - "$out" <<'PY'
import json, sys
lines = [l for l in open(sys.argv[1]) if l.strip()]
done = json.loads(lines[-1]) if lines else {}
sys.exit(0 if done.get("event") == "done" and done.get("map_reset") is True else 1)
PY
then
	say "exit 0 but no done line with \"map_reset\": true: the map is kept; the tool may"
	say "have written its entries, so restore the backup:"
	say "  rm -rf '$world' && mv '$backup' '$world'"
	exit 1
fi

# 3. The emptying (the platform: TRUNCATE public.blocks), 4. the counter.
python3 - "$world" "$conf" <<'PY'
import re, sqlite3, sys
from pathlib import Path
world, conf = sys.argv[1], sys.argv[2]
db = sqlite3.connect(world + "/map.sqlite")
with db:
    removed = db.execute("DELETE FROM blocks").rowcount
db.execute("VACUUM")
db.close()
print("reset_like_platform: map emptied: %d map blocks removed (mod storage, players and "
      "auth kept)" % removed)
# The engine stores mod storage keys and values as BLOBs
# (database-sqlite3.cpp): the key is bound as bytes, a TEXT literal never
# equals a BLOB.
store = sqlite3.connect(Path(world, "mod_storage.sqlite").as_uri() + "?mode=ro", uri=True)
row = store.execute("SELECT value FROM entries WHERE modname = ? AND key = ?",
                    ("grug_core", b"reset_world")).fetchone()
store.close()
text = bytes(row[0]).decode() if row else ""
record = int(text) if text.isdigit() else 0
current, lines = 0, []
if conf:
    try:
        lines = open(conf).read().splitlines()
    except FileNotFoundError:
        lines = []
    for line in lines:
        m = re.match(r"\s*grug_reset_world\s*=\s*(\d+)", line)
        if m:
            current = int(m.group(1))
value = max(record, current) + 1
if conf:
    lines = [l for l in lines if not re.match(r"\s*grug_reset_world\s*=", l)]
    lines.append("grug_reset_world = %d" % value)
    with open(conf, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("reset_like_platform: %s: grug_reset_world = %d (the world's record was %d)"
          % (conf, value, record))
else:
    print("reset_like_platform: put  grug_reset_world = %d  into the server's config before "
          "the next start (the world's record is %d)" % (value, record))
PY
say "done. Backup: $backup"
