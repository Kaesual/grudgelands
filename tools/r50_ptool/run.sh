#!/usr/bin/env bash
# Round 50 lane PTOOL: the tests of the pre-reset pass.
#   1. the unit tests (test_pack.py) and the PostgreSQL test (pg_test.py) in
#      the platform runner's environment: the image of tools/r43_it
#      (Containerfile: Debian trixie's python3 3.13, python3-psycopg,
#      python3-zstandard, PostgreSQL), built once, no network;
#   2. the engine reads the entries back: the tool packs a copy of
#      tools/r50_ptool/world, the recovered entries are copied into the
#      probe's own mod storage, and a boot of this checkout's game with the
#      probe (verify phase) reads each one with ItemStack(s):get_meta() and
#      core.deserialize and compares it stack by stack with what the probe
#      placed (r50_ptool_verify.txt).
# The unit tests also run locally (Python 3.14, compression.zstd):
#   python3 -m unittest discover -s tools/r50_ptool -p 'test_*.py'
#
# Usage: tools/r50_ptool/run.sh [EVIDENCE_DIR]   (default tools/r50_ptool/evidence)
#   Start it through the round's process queue (one slot): the container
#   and the boot run one after the other. Exit 0 only when every part passed.
set -euo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
evidence="${1:-$here/evidence}"
image=localhost/grudgelands-r43-it:trixie
work="$(mktemp -d /tmp/r50-ptool.XXXXXX)"
root="$(mktemp -d /tmp/grudgelands-headless.XXXXXX)"
cleanup() {
	[[ "$work" == /tmp/r50-ptool.?* ]] && rm -rf "$work"
	[[ "$root" == /tmp/grudgelands-headless.?* ]] && rm -rf "$root"
}
trap cleanup EXIT
mkdir -p "$evidence"
if ! podman image exists "$image"; then
	podman build -q -t "$image" -f "$repo/tools/r43_it/Containerfile" "$repo/tools/r43_it"
fi

echo "== 1. container: unit tests and PostgreSQL"
podman run --rm --network=none --security-opt label=disable -e PYTHONDONTWRITEBYTECODE=1 \
	-v "$repo:$repo:ro" -v "$work:$work" -w "$repo" "$image" sh -euc '
		python3 --version
		python3 -c "import sys, zstandard, psycopg; print(\"zstandard\", zstandard.__version__, \"psycopg\", psycopg.__version__); assert sys.version_info < (3, 14)"
		python3 -m unittest discover -s tools/r50_ptool -p "test_*.py" -v
		python3 tools/r50_ptool/pg_test.py "$1"' sh "$work" 2>&1 | tee "$evidence/container.txt"

echo "== 2. the engine reads the entries back"
world="$root/w50"
cp -r "$here/world" "$world"
gzip -dc "$here/world/r50_ptool_probe.json.gz" >"$world/r50_ptool_probe.json"
rm "$world/r50_ptool_probe.json.gz"
python3 "$repo/tools/migrate.py" --world "$world" --map-reset >"$evidence/tool.jsonl"
python3 - "$world" <<'PY'
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1] + "/mod_storage.sqlite")
with conn:
    rows = conn.execute("SELECT key, value FROM entries WHERE modname = 'grug_housing' "
                        "AND key LIKE 'recovered:%'").fetchall()
    probe = "grug_probe_r50_ptool"
    conn.executemany("REPLACE INTO entries VALUES (?, ?, ?)",
                     [(probe, b"entry:" + bytes(k), bytes(v)) for k, v in rows])
    conn.execute("REPLACE INTO entries VALUES (?, ?, ?)", (probe, b"verify", b"1"))
print("copied %d entries" % len(rows))
PY
set +e
ROOT="$root" PROBE="$here/grug_probe_r50_ptool" SEED=42 \
	"$repo/tools/luanti_headless.sh" 240 --world "$world" >"$root/boot.txt" 2>&1
set -e
cat "$root/boot.txt"
cp "$world/r50_ptool_verify.txt" "$evidence/verify.txt" 2>/dev/null || true
grep -h 'ERROR\|r50_ptool_probe' "$root"/server*.log | head -20 || true
cat "$evidence/verify.txt" 2>/dev/null | grep -v '^PASS' || true
# The container part passed (pipefail would have stopped here otherwise).
grep -q '^RESULT PASS' "$evidence/verify.txt" \
	&& python3 -c "import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r and all(x['ok'] for x in r) else 1)" "$work/pg_results.json" \
	&& cp "$work/pg_results.json" "$evidence/pg_results.json" && echo "r50_ptool run: PASS" && exit 0
cp "$work/pg_results.json" "$evidence/" 2>/dev/null || true
echo "r50_ptool run: FAIL"
exit 1
