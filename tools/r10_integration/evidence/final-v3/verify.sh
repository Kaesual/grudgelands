#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$root"
sha256sum -c archived.sha256
while read -r expected path; do
	if [[ -f "$path" ]]; then
		actual="$(sha256sum "$path" | cut -d ' ' -f 1)"
	elif [[ -f "$path.gz" ]]; then
		actual="$(gzip -cd -- "$path.gz" | sha256sum | cut -d ' ' -f 1)"
	else
		echo "missing logical payload: $path" >&2
		exit 1
	fi
	[[ "$actual" == "$expected" ]] || {
		echo "uncompressed checksum differs: $path" >&2
		exit 1
	}
done < uncompressed.sha256
echo "final-v3 archive verification PASS"
