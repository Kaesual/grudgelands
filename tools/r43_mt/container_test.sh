#!/usr/bin/env bash
# Round 43 lane MT: the migration tool's tests where the platform's runner
# runs it: a debian:trixie container (Podman) with Debian's python3 (3.13),
# python3-psycopg and python3-zstandard, on a `git archive` export of a
# commit (default HEAD): every tracked file, so no reference_projects/
# (submodules) and no gitignored tools/bin. Prints the tested versions.
#
# Usage: tools/r43_mt/container_test.sh [COMMIT]
#   Start it through the round's process queue (one slot).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
commit="${1:-HEAD}"
export_dir="$(mktemp -d /tmp/r43-mt-export.XXXXXX)"
trap 'rm -rf "$export_dir"' EXIT
git -C "$repo" archive --format=tar "$commit" | tar -x -C "$export_dir"
echo "export of $(git -C "$repo" rev-parse --short "$commit"): $export_dir"
podman run --rm --pull=missing -v "$export_dir:/src:Z" -w /src \
	docker.io/library/debian:trixie sh -euc '
		export DEBIAN_FRONTEND=noninteractive
		apt-get update -qq
		apt-get install -y -qq --no-install-recommends \
			python3 python3-psycopg python3-zstandard >/dev/null
		. /etc/os-release; echo "$PRETTY_NAME"
		python3 --version
		dpkg-query -W -f "\${Package} \${Version}\n" \
			python3 python3-psycopg python3-zstandard libpq5 libsqlite3-0
		python3 -c "import sqlite3, psycopg, zstandard; print(\"sqlite\", sqlite3.sqlite_version, \"psycopg\", psycopg.__version__, \"libpq\", psycopg.pq.version(), \"zstandard\", zstandard.__version__)"
		test ! -e reference_projects/luanti/src || { echo "reference_projects in the export"; exit 1; }
		test ! -e tools/bin || { echo "tools/bin in the export"; exit 1; }
		python3 -m unittest discover -s tools/r43_mt -p "test_*.py" -v
		python3 tools/migrate.py --world tools/r43_mt/world --check
	'
