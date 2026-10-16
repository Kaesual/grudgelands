#!/usr/bin/env bash
# Round 50 lane PACCEPT: the checks of reset_like_platform.sh on copies of
# tools/r50_ptool/world (a world the engine wrote, its mod storage keys and
# values BLOBs as database-sqlite3.cpp stores them). No engine run, a few
# seconds: the refusals (the personal folder, a non-SQLite world, a config
# that cannot be written, a running server named by an absolute or a relative
# --world; a world under a path containing "luanti" is accepted), a world reset before (grug_core reset_world = 3 stored the
# engine's way: the counter becomes 4), a rerun refused before any write
# (pack_pending, its backup removed), and a world without a record and no
# config (the line printed: 1).
#
# Usage: tools/r50_paccept/test_reset_like_platform.sh   (exit 0 when every check passed)
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
script="$here/reset_like_platform.sh"
tmp="$(mktemp -d /tmp/r50-paccept-reset.XXXXXX)"
fake=""
cleanup() {
	[[ -n "$fake" ]] && kill "$fake" 2>/dev/null
	[[ "$tmp" == /tmp/r50-paccept-reset.?* ]] && rm -rf -- "$tmp"
}
trap cleanup EXIT
fails=0
check() {  # check <name> <condition...>
	local name="$1"; shift
	if "$@"; then echo "PASS $name"; else echo "FAIL $name"; fails=$((fails + 1)); fi
}
world() {  # a fresh copy of the engine-written world at $tmp/$1
	rm -rf -- "${tmp:?}/$1"
	cp -a "$repo/tools/r50_ptool/world" "$tmp/$1"
	gzip -dc "$tmp/$1/r50_ptool_probe.json.gz" >/dev/null
	rm -f "$tmp/$1/r50_ptool_probe.json.gz"
}
set_record() {  # set_record <world> <value>: grug_core reset_world, BLOB key and value
	python3 - "$1" "$2" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1] + "/mod_storage.sqlite")
with db:
    db.execute("REPLACE INTO entries VALUES (?, ?, ?)",
               ("grug_core", b"reset_world", sys.argv[2].encode()))
PY
}
blocks() { python3 -c "import sqlite3,sys; print(sqlite3.connect(sys.argv[1]).execute('SELECT COUNT(*) FROM blocks').fetchone()[0])" "$1/map.sqlite"; }
backups() { ls -d "$tmp/$1".backup-* 2>/dev/null | wc -l; }

out="$("$script" "$HOME/.var/app/org.luanti.luanti/worlds/any" 2>&1)"; rc=$?
check "the personal Luanti folder is refused (exit 2)" test $rc -eq 2 -a -n "$(grep -F 'personal Luanti folder' <<<"$out")"

world pg
printf 'gameid = grudgelands\nbackend = postgresql\n' >"$tmp/pg/world.mt"
out="$("$script" "$tmp/pg" 2>&1)"; rc=$?
check "a PostgreSQL world is refused (exit 2)" test $rc -eq 2 -a -n "$(grep -F 'SQLite worlds only' <<<"$out")"

world ro
mkdir "$tmp/ro_conf" && chmod 555 "$tmp/ro_conf"
out="$("$script" "$tmp/ro" "$tmp/ro_conf/server.conf" 2>&1)"; rc=$?
chmod 755 "$tmp/ro_conf"
check "a config that cannot be written is refused before anything (no backup, map kept)" \
	test $rc -eq 2 -a "$(backups ro)" -eq 0 -a "$(blocks "$tmp/ro")" -gt 0

# A fake server: a process whose argv[0] is "luanti" with a --world argument.
fake_server() {  # fake_server <dir> <args...>: started in <dir>, sleeps 30 s
	local dir="$1"; shift
	(cd "$dir" && exec python3 -c 'import os, sys
os.execv(sys.executable, ["luanti", "-c", "import time; time.sleep(30)"] + sys.argv[1:])' "$@") &
	fake=$!
}
world running
fake_server "$tmp" --server --gameid grudgelands --world running
sleep 0.5
out="$("$script" "$tmp/running" 2>&1)"; rc=$?
check "a server on the world named by a relative --world is refused" \
	test $rc -eq 2 -a -n "$(grep -F 'seems to run' <<<"$out")"
kill "$fake" 2>/dev/null; wait "$fake" 2>/dev/null
fake_server / --server "--world=$tmp/running"
sleep 0.5
out="$("$script" "$tmp/running" 2>&1)"; rc=$?
check "a server on the world named by an absolute --world is refused" \
	test $rc -eq 2 -a -n "$(grep -F 'seems to run' <<<"$out")"
kill "$fake" 2>/dev/null; wait "$fake" 2>/dev/null
fake=""
check "neither refusal changed anything" test "$(backups running)" -eq 0 -a "$(blocks "$tmp/running")" -gt 0
fake_server "$tmp" --server --world elsewhere
mkdir -p "$tmp/luanti-test"
world luanti-test/w
out="$("$script" "$tmp/luanti-test/w" 2>&1)"; rc=$?
check "a world under a path containing 'luanti' is accepted (a server on another world runs)" \
	test $rc -eq 0 -a -z "$(grep -F 'seems to run' <<<"$out")"
kill "$fake" 2>/dev/null; wait "$fake" 2>/dev/null
fake=""

world reset3
set_record "$tmp/reset3" 3
printf 'port = 30001\ngrug_reset_world = 2\n' >"$tmp/reset3.conf"
out="$("$script" "$tmp/reset3" "$tmp/reset3.conf" 2>&1)"; rc=$?
echo "$out" | grep '^reset_like_platform:'
check "a world reset before (record 3): exit 0, the config says 4 once, the rest kept" \
	test $rc -eq 0 -a "$(grep -c '^grug_reset_world' "$tmp/reset3.conf")" -eq 1 \
	-a -n "$(grep -Fx 'grug_reset_world = 4' "$tmp/reset3.conf")" \
	-a -n "$(grep -Fx 'port = 30001' "$tmp/reset3.conf")"
check "... and it prints 4 with the record 3" \
	test -n "$(grep -F 'grug_reset_world = 4 (the world'"'"'s record was 3)' <<<"$out")"
check "... the map is empty, one backup taken" test "$(blocks "$tmp/reset3")" -eq 0 -a "$(backups reset3)" -eq 1

out="$("$script" "$tmp/reset3" "$tmp/reset3.conf" 2>&1)"; rc=$?
check "a rerun before the game loaded is refused (pack_pending), its backup removed, the config kept" \
	test $rc -eq 2 -a -n "$(grep -F pack_pending <<<"$out")" -a "$(backups reset3)" -eq 1 \
	-a -n "$(grep -Fx 'grug_reset_world = 4' "$tmp/reset3.conf")"

world plain
out="$("$script" "$tmp/plain" 2>&1)"; rc=$?
check "no record, no config: exit 0, the line to add printed (1)" \
	test $rc -eq 0 -a -n "$(grep -F 'put  grug_reset_world = 1  into' <<<"$out")"

echo "reset_like_platform checks: $fails failed"
exit $((fails > 0))
